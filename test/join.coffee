Action = require '../Action.coffee'
{assertData, monadicActionFoo, monadicActionBar, monadicActionFail} = require './fixture.coffee'

module.exports =
    new Action (cb) ->
        testJoin = Action.join monadicActionFoo('data1'), monadicActionBar('data2'), (data1, data2) ->
            assertData data1, 'data1foo'
            assertData data2, 'data2bar'

        testJoin
        .go ->
            console.log 'Action.join without error ok'
            cb()
    .next ->
        new Action (cb) ->
            testJoin = Action.join monadicActionFoo('data1'), monadicActionFail('data2'), (data1, data2) ->
                assertData data1, 'data1foo'
                assertData data2.message, 'testError'

            testJoin
            .go ->
                console.log 'Action.join with error ok'
                cb()

    .next ->
        new Action (cb) ->
            testJoin = Action.join(
                monadicActionFoo('data1')
            ,   monadicActionFail('data2')
            ,   (data1, data2) ->
                    assertData data1, 'this won\'t fired'
            ,   true
            )

            testJoin
            .guard (err) -> assertData err.message, 'testError'
            .go ->
                console.log 'Action.join with error ok'
                cb()
