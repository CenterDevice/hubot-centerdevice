# Description
#   DevOps for CenterDevice via Hubot
#
# Configuration:
#   HUBOT_CENTERDEVICE_ROLE -- Auth role required, e.g., "centerdevice"
#   HUBOT_DEPLOYMENT_SILENCE_DURATION -- Duration of deployment silence, default is 15m
#   HUBOT_CENTERDEVICE_LOG_LEVEL -- Log level, default is "info"
#   HUBOT_CENTERDEVICE_BOSUN_TIMEOUT -- Timeout to wait for Bosun to react, default is 30000 ms
#   HUBOT_CENTERDEVICE_SILENCE_CHECK_INTERVAL -- Interval to check, if Bosun silence is still active
#
# Commands:
#   start(ing) centerdevice deployment -- automatically sets Bosun silence for `HUBOT_DEPLOYMENT_SILENCE_DURATION`
#   finish(ed) centerdevice deployment -- automatically clears previously created Bosun silence
#
# Notes:
#
# Author:
#   lukas.pustina@centerdevice.de
#
# Todos:

Log = require 'log'
moment = require 'moment'
module_name = "hubot-centerdevice"

config =
  deployment_silence_duration: process.env.HUBOT_DEPLOYMENT_SILENCE_DURATION or "15m"
  log_level: process.env.HUBOT_CENTERDEVICE_LOG_LEVEL or "info"
  role: process.env.HUBOT_CENTERDEVICE_ROLE
  silence_check_interval: if process.env.HUBOT_CENTERDEVICE_SILENCE_CHECK_INTERVAL then parseInt process.env.HUBOT_CENTERDEVICE_SILENCE_CHECK_INTERVAL else 60000
  timeout: if process.env.HUBOT_CENTERDEVICE_BOSUN_TIMEOUT then parseInt process.env.HUBOT_CENTERDEVICE_BOSUN_TIMEOUT else 30000

logger = new Log config.log_level
logger.notice "#{module_name}: Started."

Timers = {}


module.exports = (robot) ->

  robot.respond /start.* centerdevice deployment/i, (res) ->
    if is_authorized robot, res
      user_name = res.envelope.user.name
      logger.info "#{module_name}: starting deployment requested by #{user_name}."

      event_name = "bosun.set_silence"
      if silence_id = robot.brain.get "centerdevice.#{event_name}.silence_id"
        res.reply "Ouuch, there's already a deployment silence with id #{silence_id} pending. Finish that deployment and ask Bosun for active silences."
      else
        res.reply "Ok, let me silence Bosun for your deployment ..."

        prepare_timeout event_name, robot.brain
        logger.debug "#{module_name}: emitting request for Bosun silence."
        robot.emit event_name,
          user: res.envelope.user
          room: res.envelope.room
          duration: config.deployment_silence_duration
          # TODO: Set these from variables
          alert: "lukas.test"
          tags: "host=muffin,service=lukas"
          message: "I need some rest"

        set_timeout event_name, robot.brain, res


  robot.respond /finish.* centerdevice deployment/i, (res) ->
    if is_authorized robot, res
      user_name = res.envelope.user.name
      logger.info "#{module_name}: finished deployment requested by #{user_name}."

      event_name = "bosun.clear_silence"
      unless (robot.brain.get "centerdevice.bosun.set_silence.silence_id")?
        res.reply "Hm, there's no active Bosun silence. You're sure there's a deployment going on?"
      else
        res.reply "Ok, let me clear the Bosun silence for your deployment ..."

        prepare_timeout event_name, robot.brain
        logger.debug "#{module_name}: emitting request for Bosun to clear silence."
        robot.emit event_name,
          user: res.envelope.user
          room: res.envelope.room
          silence_id: robot.brain.set "centerdevice.#{event_name}.silence_id"

        set_timeout event_name, robot.brain, res


  robot.on 'bosun.result.set_silence.successful', (event) ->
    logger.debug "#{module_name}: Received event bosun.result.set_silence.successful."
    event_name = "bosun.set_silence"
    if robot.brain.get "centerdevice.#{event_name}.pending"
      logger.debug "#{module_name}: Set Bosun silence successful for #{event.duration} with id #{event.silence_id}."
      clear_timeout event_name, robot.brain

      robot.brain.set "centerdevice.#{event_name}.silence_id", event.silence_id
      robot.reply {room: event.room, user: event.user}, "Set Bosun silence successfully for #{event.duration} with id #{event.silence_id}."

      set_silence_checker {room: event.room, user: event.user, silence_id: event.silence_id}, robot


  robot.on 'bosun.result.set_silence.failed', (event) ->
    logger.debug "#{module_name}: Received event bosun.result.set_silence.failed."
    event_name = "bosun.set_silence"
    if robot.brain.get "centerdevice.#{event_name}.pending"
      logger.debug "#{module_name}: Oouch: Failed to set Bosun silence because #{event.message}"
      clear_timeout event_name, robot.brain

      robot.reply {room: event.room, user: event.user}, "Oouch: Failed to set Bosun silence because #{event.message}"


  robot.on 'bosun.result.clear_silence.successful', (event) ->
    logger.debug "#{module_name}: Received event bosun.result.clear_silence.successful."
    event_name = "bosun.clear_silence"
    if robot.brain.get "centerdevice.#{event_name}.pending"
      logger.debug "#{module_name}: Cleared Bosun silence successfully with id #{event.silence_id}."
      clear_timeout event_name, robot.brain

      robot.brain.remove "centerdevice.bosun.set_silence.silence_id"
      robot.reply {room: event.room, user: event.user}, "Cleared Bosun silence successfully with id #{event.silence_id}."


  robot.on 'bosun.result.clear_silence.failed', (event) ->
    logger.debug "#{module_name}: Received event bosun.result.clear_silence.failed."
    event_name = "bosun.clear_silence"
    if robot.brain.get "centerdevice.#{event_name}.pending"
      logger.debug "#{module_name}: Oouch: Failed to clear Bosun with id #{event.silence_id} silence because #{event.message}"
      clear_timeout event_name, robot.brain

      robot.brain.remove "centerdevice.bosun.set_silence.silence_id"
      robot.reply {room: event.room, user: event.user}, "Oouch: Failed to clear Bosun silence with id #{event.silence_id}, because #{event.message} Please talk directly to Bosun to clear the silence."


  robot.on 'bosun.result.check_silence.successful', (event) ->
    logger.debug "#{module_name}: Received event bosun.result.check_silence.successful."
    if event.active
      logger.debug "#{module_name}: currently set silence is still active."
      set_silence_checker event, robot
    else
      logger.debug "#{module_name}: currently set silence became inactive."
      clear_silence_checker
      robot.brain.remove "centerdevice.set_silence.checker.failed_retries"
      robot.brain.remove "centerdevice.bosun.set_silence.silence_id"
      robot.reply {room: event.room, user: event.user}, "Hey, your Bosun silence with id #{event.silence_id} expired, but it seems you're stil deploying?! Are you okay?"

  robot.on 'bosun.result.check_silence.failed', (event) ->
    logger.debug "#{module_name}: Received event bosun.result.check_silence.failed."
    retries = robot.brain.get "centerdevice.set_silence.checker.failed_retries" or 0
    if retries < 3
      logger.info "#{module_name}: Reactivating silence checker."
      retries = robot.brain.set "centerdevice.set_silence.checker.failed_retries", (retries + 1)
      set_silence_checker event, robot
    else
      logger.info "#{module_name}: Giving up on silence checker."
      robot.brain.remove "centerdevice.set_silence.checker.failed_retries"
      clear_silence_checker


  robot.error (err, res) ->
    robot.logger.error "#{module_name}: DOES NOT COMPUTE"

    if res?
      res.reply "DOES NOT COMPUTE: #{err}"


prepare_timeout = (name, brain) ->
  logger.debug "#{module_name}: Preparing timeout for #{name}."
  brain.set "centerdevice.#{name}.pending", true

set_timeout = (name, brain, res) ->
  logger.debug "#{module_name}: Setting timeout for #{name}."
  if brain.get "centerdevice.#{name}.pending"
    logger.debug "#{module_name}: Setting timeout for Bosun silence for #{config.timeout} ms."
    Timers["#{name}_timeout"] = setTimeout () ->
      logger.debug "#{module_name}: Ouuch, request for #{name} timed out ... sorry."

      brain.remove "centerdevice.#{name}.pending"
      delete Timers["#{name}_timeout"]

      res.reply "Ouuch, request for #{name} timed out ... sorry."
    , config.timeout

clear_timeout = (name, brain) ->
  logger.debug "#{module_name}: Clearing timeout for #{name}."
  brain.remove "centerdevice.#{name}.pending"
  clearTimeout Timers["#{name}_timeout"]
  delete Timers["#{name}_timeout"]
  brain.remove "centerdevice.#{name}.timeout"

set_silence_checker = (context, robot) ->
  logger.debug "#{module_name}: Setting silence checker for #{context}."
  active_silence_id = robot.brain.get "centerdevice.bosun.set_silence.silence_id"
  if active_silence_id is context.silence_id
    logger.debug "#{module_name}: setting timeout for Bosun silence checker #{config.silence_check_interval} ms."
    Timers["set_silence_checker_timeout"] = setTimeout () ->
      logger.debug "#{module_name}: Emitting request to Bosun to check if silence with id #{context.silence_id} is still active."
      robot.emit 'bosun.check_silence', context
    , config.silence_check_interval

clear_silence_checker = (brain) ->
  logger.debug "#{module_name}: Clearing silence checker."
  clearTimeout Timers["set_silence_checker_timeout"]
  delete Timers["set_silence_checker_timeout"]

is_authorized = (robot, res) ->
  user = res.envelope.user
  unless robot.auth.hasRole(user, config.role)
    warn_unauthorized res
    false
  else
    true

warn_unauthorized = (res) ->
  user = res.envelope.user.name
  message = res.message.text
  logger.warning "#{module_name}: #{user} tried to run '#{message}' but was not authorized."
  res.reply "Sorry, you're not allowed to do that. You need the '#{config.role}' role."

format_date_str = (date_str) ->
  if config.relative_time
    moment(date_str).fromNow()
  else
    date_str.replace(/T/, ' ').replace(/\..+/, ' UTC')
