Action = require '../Action.coffee'
{assertData, monadicActionFoo, monadicActionBar, monadicActionFail} = require './fixture.coffee'

module.exports =
    new Action (cb) ->

        testAny = Action.race [monadicActionFoo('data1'), monadicActionBar('data2')]
        testAny
        .next (data) ->
            assertData data, 'data1foo'
        .go ->
            console.log 'Action.race without error ok'
            cb()

    .next ->
        new Action (cb) ->

            testAnySuccessWhenALLError = Action.race [monadicActionFail('data1'), monadicActionFail('data2')]
            testAnySuccessWhenALLError
            .next (data) ->
                assertData data, 'this wont fire'
            .guard (e) ->
                assertData e.message, 'RACE_ERROR: All actions failed'
            .go ->
                console.log 'Action.race with all error ok'
                cb()

    .next ->
        new Action (cb) ->

            testAnyWhenError = Action.race [monadicActionBar('data1'), monadicActionFail('data2')], true
            testAnyWhenError
            .next (data) ->
                assertData data, 'this wont fire'
            .guard (e) ->
                assertData e.message, 'testError'
            .go ->
                console.log 'Action.race with error ok'
                cb()

    .next ->
        new Action (cb) ->

            testAnySuccess = Action.race [monadicActionFoo('data1'), monadicActionFail('data2')], true
            testAnySuccess
            .next (data) ->
                assertData data, 'data1foo'
            .go ->
                console.log 'Action.race with error ok'
                cb()
