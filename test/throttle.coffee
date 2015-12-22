Action = require '../Action.coffee'
{assertData, monadicActionFoo, monadicActionBar, monadicActionFail} = require './fixture.coffee'

module.exports =
    new Action (cb) ->
        testSequence = Action.throttle (['data1', 'data2'].map monadicActionFoo), 1
        testSequence
        .next (data) ->
            assertData data[0], 'data1foo'
            assertData data[1], 'data2foo'
        .go ->
            console.log 'Action.throttle without error ok'
            cb()

    .next ->

        new Action (cb) ->
            testSequence = Action.throttle [(monadicActionFail ''), (monadicActionFoo 'data1')], 1
            testSequence
            .next (data) ->
                assertData data[0].message, 'testError'
                assertData data[1], 'data1foo'
            .go ->
                console.log 'Action.throttle with error ok'
                cb()

    .next ->

        new Action (cb) ->
            testSequence = Action.throttle [(monadicActionFail ''), (monadicActionFoo 'data1')], 1 , true
            testSequence
            .next (data) ->
                console.log 'this wont fire'
            .guard (data) ->
                assertData data.message, 'testError'
            .go ->
                console.log 'Action.throttle with error ok'
                cb()

    .next ->

        new Action (cb) ->
            testSequence = Action.throttle(
                ([0..10].map (d) ->
                    new Action (cb) ->
                        console.log 'throttled by number of 2'
                        setTimeout(
                            -> cb d
                        ,   300
                        )
                )
            ,   2
            )
            testSequence
            .next (data) ->
                assertData data[0], 0
                assertData data[1], 1
                assertData data[2], 2
                assertData data[3], 3
                assertData data[10], 10

            .go ->
                console.log 'Action.throttle without error ok'
                cb()

    .next ->
        new Action (cb) ->
            testSequence = Action.throttle(
                ([0..10].map (d) ->
                    new Action (cb) ->
                        console.log 'throttled by number of 3'
                        setTimeout(
                            -> cb d
                        ,   300
                        )
                )
            ,   3
            )
            testSequence
            .next (data) ->
                assertData data[0], 0
                assertData data[1], 1
                assertData data[2], 2
                assertData data[3], 3
                assertData data[10], 10

            .go ->
                console.log 'Action.throttle without error ok'
                cb()
