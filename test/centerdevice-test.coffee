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

      context "start deployment successfully", ->
        beforeEach ->
          robot = @room.robot
          @room.robot.on 'bosun.set_silence', (event) ->
            robot.emit 'bosun.set_silence.successful',
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
            ['hubot', '@alice Set Bosun silence successful for 10m with id 6e89533c74c3f9b74417b37e7cce75c384d29dc7.']
            ['hubot', '@alice Ok, let me silence Bosun for your deployment ...']
          ]
          expect(@room.robot.brain.get "centerdevice.bosun.set_silence.silence_id" ).to.eql "6e89533c74c3f9b74417b37e7cce75c384d29dc7"
          expect(@room.robot.brain.get "centerdevice.bosun.set_silence.timeout" ).to.eql null
          expect(@room.robot.brain.get "centerdevice.bosun.set_silence.pending" ).to.eql null

      context "start deployment failed", ->
        beforeEach ->
          robot = @room.robot
          @room.robot.on 'bosun.set_silence', (event) ->
            robot.emit 'bosun.set_silence.failed',
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

        it "finish deployment successfully"
          #robot.brain.set "centerdevice.bosun.silence.id", 6e89533c74c3f9b74417b37e7cce75c384d29dc7
          #@room.user.say('alice', '@hubot finished centerdevice deployment').then =>
            #expect(@room.messages).to.eql [
              #['alice', '@hubot starting centerdevice deployment']
              #['hubot', 'Ok, I clear the Bosun silence ...']
            #]
            #expect(@room.robot.brain.get "centerdevice.bosun.silence.id" ).to.eql null

        it "finish deployment failed"

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
  process.env.HUBOT_CENTERDEVICE_LOG_LEVEL = "debug"
  process.env.HUBOT_BOSUN_TIMEOUT = 100

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

