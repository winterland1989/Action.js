Action = require '../Action.coffee'
{assertData, monadicActionFoo, monadicActionBar, monadicActionFail} = require './fixture.coffee'

module.exports =
    new Action (cb) ->
        testAll = Action.parallel [monadicActionFoo('data1'), monadicActionBar('data2')]
        testAll
        .next (datas) ->
            assertData datas[0], 'data1foo'
            assertData datas[1], 'data2bar'
        .go ->
            console.log 'Action.parallel without error ok'
            cb()
    .next ->
        new Action (cb) ->
            testAllWithError = Action.parallel [monadicActionFoo('data1'), monadicActionFail('data2')], true
            testAllWithError
            .next (datas) ->
                assertData datas[0], 'this wont fire'
            .guard (e) ->
                assertData e.message, 'testError'
            .go ->
                console.log 'Action.parallel with error ok'
                cb()

    .next ->
        new Action (cb) ->
            testAllSuccess = Action.parallel [monadicActionFoo('data1'), monadicActionBar('data2')]
            testAllSuccess
            .next (datas) ->
                assertData datas[0], 'data1foo'
                assertData datas[1], 'data2bar'
            .go ->
                console.log 'Action.parallel without error ok'
                cb()

    .next ->
        new Action (cb) ->
            testAllSuccessWithError = Action.parallel [monadicActionFoo('data1'), monadicActionFail('data2')]
            testAllSuccessWithError
            .next (datas) ->
                assertData datas[0], 'data1foo'
                assertData datas[1].message, 'testError'
            .go ->
                console.log 'Action.parallel with error ok'
                cb()


