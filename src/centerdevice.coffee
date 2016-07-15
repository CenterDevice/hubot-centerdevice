# Description
#   DevOps for CenterDevice via Hubot
#
# Configuration:
#
# Commands:
#
# Notes:
#
# Author:
#   lukas.pustina@centerdevice.de
#
# Todos:
# - Use Cases:
#   - starting centerdevice deployment
#     - carl: Okay, let me silence Bosun -> emit silence, save silence id, user in brain
#   - finished centerdevice deployment
#     - carl: Okay, I clear the silence -> emit clear silence with saved id
#   - Silence expired
#     - if deployment, check every <interval> if silence expired and if true, send message to user
#   - Deployment expired
#     - Expire an active deployment after <interval> — in case somebody forgot to finish a deployment

Log = require 'log'
moment = require 'moment'
module_name = "hubot-centerdevice"

config =
  deployment_silence_duration: process.env.HUBOT_DEPLOYMENT_SILENCE_DURATION or "15m"
  log_level: process.env.HUBOT_CENTERDEVICE_LOG_LEVEL or "info"
  timeout: if process.env.HUBOT_BOSUN_TIMEOUT then parseInt process.env.HUBOT_BOSUN_TIMEOUT else 10000
  role: process.env.HUBOT_CENTERDEVICE_ROLE or ""

logger = new Log config.log_level
logger.notice "#{module_name}: Started."



module.exports = (robot) ->

  robot.respond /starting centerdevice deployment/i, (res) ->
    if is_authorized robot, res
      user_name = res.envelope.user.name
      logger.info "#{module_name}: starting deployment requested by #{user_name}."

      res.reply "Ok, let me silence Bosun for your deployment ..."

      event_name = "bosun.set_silence"
      prepare_timeout event_name, robot.brain
      logger.debug "#{module_name}: emitting request for Bosun silence."
      robot.emit event_name,
        user: res.envelope.user
        room: res.envelope.room
        duration: config.deployment_silence_duration
        alert: ""
        tags: ""
        message: ""

      set_timeout event_name, robot.brain, res

  robot.respond /finished centerdevice deployment/i, (res) ->
    if is_authorized robot, res
      user_name = res.envelope.user.name
      logger.info "#{module_name}: finished deployment requested by #{user_name}."


  robot.on 'bosun.set_silence.successful', (event) ->
    event_name = "bosun.set_silence"
    if robot.brain.get "centerdevice.#{event_name}.pending"
      logger.debug "#{module_name}: Set Bosun silence successful for #{event.duration} with id #{event.silence_id}."
      clear_timeout event_name, robot.brain

      robot.brain.set "centerdevice.#{event_name}.silence_id", event.silence_id
      robot.reply {room: event.room, user: event.user}, "Set Bosun silence successful for #{event.duration} with id #{event.silence_id}."


  robot.on 'bosun.set_silence.failed', (event) ->
    event_name = "bosun.set_silence"
    if robot.brain.get "centerdevice.#{event_name}.pending"
      logger.debug "#{module_name}: Oouch: Failed to set Bosun silence because #{event.message}"
      clear_timeout event_name, robot.brain

      robot.reply {room: event.room, user: event.user}, "Oouch: Failed to set Bosun silence because #{event.message}"


  robot.error (err, res) ->
    robot.logger.error "#{module_name}: DOES NOT COMPUTE"

    if res?
      res.reply "DOES NOT COMPUTE: #{err}"


prepare_timeout = (name, brain) ->
  brain.set "centerdevice.#{name}.pending", true

set_timeout = (name, brain, res) ->
  if brain.get "centerdevice.#{name}.pending"
    logger.debug "#{module_name}: setting timeout for Bosun silence for #{config.timeout} ms."
    brain.set "centerdevice.#{name}.timeout", setTimeout () ->
      logger.debug "#{module_name}: Ouuch, request for #{name} timed out ... sorry."

      brain.remove "centerdevice.#{name}.pending"
      brain.remove "centerdevice.#{name}.timeout"

      res.reply "Ouuch, request for #{name} timed out ... sorry."
    , config.timeout

clear_timeout = (name, brain) ->
  brain.remove "centerdevice.#{name}.pending"
  clearTimeout brain.get "centerdevice.#{name}.timeout"
  brain.remove "centerdevice.#{name}.timeout"

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
