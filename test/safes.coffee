Action = require '../Action.coffee'
{assertData, monadicActionFoo, monadicActionBar, monadicActionFail} = require './fixture.coffee'

module.exports =
    new Action (cb) ->
        testSafe = Action.safe (new Error 'testError'), -> throw new Error ''
        assertData testSafe().message, 'testError'
        console.log 'Action.safe ok'
        cb()

    .next ->
        new Action (cb) ->
            testSafeRaw = Action.safeRaw -> throw new Error 'testError'
            assertData testSafeRaw().message, 'testError'
            console.log 'Action.safeRaw ok'
            cb()
