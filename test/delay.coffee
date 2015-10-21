Action = require '../Action.coffee'
{assertData, actionFoo, monadicActionFoo, monadicActionFail} = require './fixture.coffee'

module.exports =
    new Action (cb) ->
        testDelay = Action.delay 1000, monadicActionFoo('data1')
        testDelay
        .next (data) ->
            assertData data, 'data1foo'
        .go ->
            console.log 'Action.delay without error ok'
            cb()
