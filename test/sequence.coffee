Action = require '../Action.coffee'
{assertData, monadicActionFoo, monadicActionBar, monadicActionFail} = require './fixture.coffee'

module.exports =
    new Action (cb) ->
        testSequence = Action.sequence (['data1', 'data2'].map monadicActionFoo)
        testSequence
        .next (data) ->
            assertData data[0], 'data1foo'
            assertData data[1], 'data2foo'
        .go ->
            console.log 'Action.sequence without error ok'
            cb()

    .next ->

        new Action (cb) ->
            testSequence = Action.sequence [(monadicActionFail ''), (monadicActionFoo 'data1')]
            testSequence
            .next (data) ->
                assertData data[0].message, 'testError'
                assertData data[1], 'data1foo'
            .go ->
                console.log 'Action.sequence with error ok'
                cb()

    .next ->

        new Action (cb) ->
            testSequence = Action.sequence [(monadicActionFail ''), (monadicActionFoo 'data1')], true
            testSequence
            .next (data) ->
                console.log 'this wont fire'
            .guard (data) ->
                assertData data.message, 'testError'
            .go ->
                console.log 'Action.sequence with error ok'
                cb()
