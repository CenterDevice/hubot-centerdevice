Helper = require('hubot-test-helper')
chai = require 'chai'
Promise = require('bluebird')
co = require('co')

expect = chai.expect

process.env.EXPRESS_PORT = 18080
api_call_delay = 20
customMessages = []



describe 'centerdevice', ->
  beforeEach ->
    @room = setup_test_env {}

  afterEach ->
    tear_down_test_env @room

  context "deployment", ->

    context "authorized user", ->

      context "start deployment", ->

        context "start deployment successfully", ->
          beforeEach ->
            robot = @room.robot
            @room.robot.on 'bosun.set_silence', (event) ->
              robot.emit 'bosun.result.set_silence.successful',
                user: event.user
                room: event.room
                duration: "10m"
                silence_id: "6e89533c74c3f9b74417b37e7cce75c384d29dc7"
            co =>
              yield @room.user.say 'alice', '@hubot starting centerdevice deployment'
              yield new Promise.delay 50

          it "start deployment", ->
            expect(@room.messages).to.eql [
              ['alice', '@hubot starting centerdevice deployment']
              ['hubot', '@alice Set Bosun silence successfully for 10m with id 6e89533c74c3f9b74417b37e7cce75c384d29dc7.']
              ['hubot', '@alice Ok, let me silence Bosun for your deployment ...']
            ]
            expect(@room.robot.brain.get "centerdevice.bosun.set_silence.silence_id" ).to.eql "6e89533c74c3f9b74417b37e7cce75c384d29dc7"
            expect(@room.robot.brain.get "centerdevice.bosun.set_silence.timeout" ).to.eql null
            expect(@room.robot.brain.get "centerdevice.bosun.set_silence.pending" ).to.eql null

        context "start deployment successfully and silence expires", ->
          beforeEach ->
            robot = @room.robot
            @room.robot.on 'bosun.set_silence', (event) ->
              robot.emit 'bosun.result.set_silence.successful',
                user: event.user
                room: event.room
                duration: "1s"
                silence_id: "6e89533c74c3f9b74417b37e7cce75c384d29dc7"
            @room.robot.on 'bosun.check_silence', (event) ->
              robot.emit 'bosun.result.check_silence.successful',
                user: event.user
                room: event.room
                silence_id: "6e89533c74c3f9b74417b37e7cce75c384d29dc7"
                active: false
            co =>
              yield @room.user.say 'alice', '@hubot starting centerdevice deployment'
              yield new Promise.delay 1100

          it "start deployment", ->
            expect(@room.messages).to.eql [
              ['alice', '@hubot starting centerdevice deployment']
              ['hubot', '@alice Set Bosun silence successfully for 1s with id 6e89533c74c3f9b74417b37e7cce75c384d29dc7.']
              ['hubot', '@alice Ok, let me silence Bosun for your deployment ...']
              ['hubot', "@alice Hey, your Bosun silence with id 6e89533c74c3f9b74417b37e7cce75c384d29dc7 expired, but it seems you're stil deploying?! Are you okay?"]
            ]
            expect(@room.robot.brain.get "centerdevice.bosun.set_silence.silence_id" ).to.eql null
            expect(@room.robot.brain.get "centerdevice.bosun.set_silence.timeout" ).to.eql null
            expect(@room.robot.brain.get "centerdevice.bosun.set_silence.pending" ).to.eql null


        context "start deployment failed", ->
          beforeEach ->
            robot = @room.robot
            @room.robot.on 'bosun.set_silence', (event) ->
              robot.emit 'bosun.result.set_silence.failed',
                user: event.user
                room: event.room
                message: "Bosun failed."
            co =>
              yield @room.user.say 'alice', '@hubot starting centerdevice deployment'
              yield new Promise.delay 50

          it "start deployment", ->
            expect(@room.messages).to.eql [
              ['alice', '@hubot starting centerdevice deployment']
              ['hubot', '@alice Oouch: Failed to set Bosun silence because Bosun failed.']
              ['hubot', '@alice Ok, let me silence Bosun for your deployment ...']
            ]
            expect(@room.robot.brain.get "centerdevice.bosun.set_silence.silence_id" ).to.eql null
            expect(@room.robot.brain.get "centerdevice.bosun.set_silence.timeout" ).to.eql null
            expect(@room.robot.brain.get "centerdevice.bosun.set_silence.pending" ).to.eql null

        context "try to start deployment with pending silence", ->
          beforeEach ->
            @room.robot.brain.set "centerdevice.bosun.set_silence.silence_id", "dd406bdce72df2e8c69b5ee396126a7ed8f3bf44"
            @room.user.say 'alice', '@hubot starting centerdevice deployment'

          it "start deployment", ->
            expect(@room.messages).to.eql [
              ['alice', '@hubot starting centerdevice deployment']
              ['hubot', "@alice Ouuch, there's already a deployment silence with id dd406bdce72df2e8c69b5ee396126a7ed8f3bf44 pending. Finish that deployment and ask Bosun for active silences."]
            ]

        context "start deployment timed out", ->
          beforeEach ->
            co =>
              yield @room.user.say 'alice', '@hubot starting centerdevice deployment'
              yield new Promise.delay 200

          it "start deployment", ->
            expect(@room.messages).to.eql [
              ['alice', '@hubot starting centerdevice deployment']
              ['hubot', '@alice Ok, let me silence Bosun for your deployment ...']
              ['hubot', '@alice Ouuch, request for bosun.set_silence timed out ... sorry.']
            ]
            expect(@room.robot.brain.get "centerdevice.bosun.set_silence.silence_id" ).to.eql null
            expect(@room.robot.brain.get "centerdevice.bosun.set_silence.timeout" ).to.eql null
            expect(@room.robot.brain.get "centerdevice.bosun.set_silence.pending" ).to.eql null

      context "finish deployment", ->

        context "finish deployment successfully", ->
          beforeEach ->
            @room.robot.brain.set "centerdevice.bosun.set_silence.silence_id", "6e89533c74c3f9b74417b37e7cce75c384d29dc7"
            robot = @room.robot
            @room.robot.on 'bosun.clear_silence', (event) ->
              robot.emit 'bosun.result.clear_silence.successful',
                user: event.user
                room: event.room
                silence_id: event.silence_id
            co =>
              yield @room.user.say 'alice', '@hubot finished centerdevice deployment'
              yield new Promise.delay 50

          it "finish deployment", ->
            expect(@room.messages).to.eql [
              ['alice', '@hubot finished centerdevice deployment']
              ['hubot', '@alice Cleared Bosun silence successfully with id 6e89533c74c3f9b74417b37e7cce75c384d29dc7.']
              ['hubot', '@alice Ok, let me clear the Bosun silence for your deployment ...']
            ]
            expect(@room.robot.brain.get "centerdevice.bosun.set_silence.silence_id" ).to.eql null
            expect(@room.robot.brain.get "centerdevice.bosun.clear_silence.timeout" ).to.eql null
            expect(@room.robot.brain.get "centerdevice.bosun.clear_silence.pending" ).to.eql null

        context "finish deployment failed", ->
          beforeEach ->
            @room.robot.brain.set "centerdevice.bosun.set_silence.silence_id", "6e89533c74c3f9b74417b37e7cce75c384d29dc7"
            robot = @room.robot
            @room.robot.on 'bosun.clear_silence', (event) ->
              robot.emit 'bosun.result.clear_silence.failed',
                user: event.user
                room: event.room
                silence_id: event.silence_id
                message: "Bosun failed."
            co =>
              yield @room.user.say 'alice', '@hubot finished centerdevice deployment'
              yield new Promise.delay 50

          it "finish deployment", ->
            expect(@room.messages).to.eql [
              ['alice', '@hubot finished centerdevice deployment']
              ['hubot', '@alice Oouch: Failed to clear Bosun silence with id 6e89533c74c3f9b74417b37e7cce75c384d29dc7, because Bosun failed. Please talk directly to Bosun to clear the silence.']
              ['hubot', '@alice Ok, let me clear the Bosun silence for your deployment ...']
            ]
            expect(@room.robot.brain.get "centerdevice.bosun.set_silence.silence_id" ).to.eql null
            expect(@room.robot.brain.get "centerdevice.bosun.clear_silence.timeout" ).to.eql null
            expect(@room.robot.brain.get "centerdevice.bosun.clear_silence.pending" ).to.eql null

        context "try to finish deployment with no pending silence", ->
          beforeEach ->
            @room.robot.brain.remove "centerdevice.bosun.set_silence.silence_id"
            @room.user.say 'alice', '@hubot finished centerdevice deployment'

          it "finish deployment", ->
            expect(@room.messages).to.eql [
              ['alice', '@hubot finished centerdevice deployment']
              ['hubot', "@alice Hm, there's no active Bosun silence. You're sure there's a deployment going on?"]
            ]

        context "finish deployment timed out", ->
          beforeEach ->
            @room.robot.brain.set "centerdevice.bosun.set_silence.silence_id", "6e89533c74c3f9b74417b37e7cce75c384d29dc7"
            co =>
              yield @room.user.say 'alice', '@hubot finished centerdevice deployment'
              yield new Promise.delay 200

          it "finish deployment", ->
            expect(@room.messages).to.eql [
              ['alice', '@hubot finished centerdevice deployment']
              ['hubot', '@alice Ok, let me clear the Bosun silence for your deployment ...']
              ['hubot', '@alice Ouuch, request for bosun.clear_silence timed out ... sorry.']
            ]
            expect(@room.robot.brain.get "centerdevice.bosun.set_silence.silence_id" ).to.eql "6e89533c74c3f9b74417b37e7cce75c384d29dc7"
            expect(@room.robot.brain.get "centerdevice.bosun.clear_silence.timeout" ).to.eql null
            expect(@room.robot.brain.get "centerdevice.bosun.clear_silence.pending" ).to.eql null

    context "unauthorized user", ->

      it "fail to start deployment for unauthorized user", ->
        @room.user.say('bob', '@hubot starting centerdevice deployment').then =>
          expect(@room.messages).to.eql [
            ['bob', '@hubot starting centerdevice deployment']
            ['hubot', "@bob Sorry, you're not allowed to do that. You need the 'centerdevice' role."]
          ]

      it "fail to finish deployment for unauthorized user", ->
        @room.user.say('bob', '@hubot finished centerdevice deployment').then =>
          expect(@room.messages).to.eql [
            ['bob', '@hubot finished centerdevice deployment']
            ['hubot', "@bob Sorry, you're not allowed to do that. You need the 'centerdevice' role."]
          ]



setup_test_env = (env) ->
  process.env.HUBOT_CENTERDEVICE_ROLE = "centerdevice"
  process.env.HUBOT_DEPLOYMENT_SILENCE_DURATION = "10m"
  process.env.HUBOT_CENTERDEVICE_LOG_LEVEL = "error"
  process.env.HUBOT_CENTERDEVICE_BOSUN_TIMEOUT = 100
  process.env.HUBOT_CENTERDEVICE_SILENCE_CHECK_INTERVAL = 200

  helper = new Helper('../src/centerdevice.coffee')
  room = helper.createRoom()
  room.robot.auth = new MockAuth

  room

tear_down_test_env = (room) ->
  room.destroy()
  # Force reload of module under test
  delete require.cache[require.resolve('../src/centerdevice')]


class MockAuth
  hasRole: (user, role) ->
    if user.name is 'alice' and role is 'centerdevice' then true else false

