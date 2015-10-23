Action = require '../Action.coffee'
{assertData, monadicActionFoo, monadicActionBar, monadicActionFail} = require './fixture.coffee'

module.exports =
    new Action (cb) ->
        testParallel = Action.parallel [monadicActionFoo('data1'), monadicActionBar('data2')]
        testParallel
        .next (datas) ->
            assertData datas[0], 'data1foo'
            assertData datas[1], 'data2bar'
        .go ->
            console.log 'Action.parallel without error ok'
            cb()
    .next ->
        new Action (cb) ->
            testParallelWithError = Action.parallel [monadicActionFoo('data1'), monadicActionFail('data2')], true
            testParallelWithError
            .next (datas) ->
                assertData datas[0], 'this wont fire'
            .guard (e) ->
                assertData e.message, 'testError'
            .go ->
                console.log 'Action.parallel with error ok'
                cb()

    .next ->
        new Action (cb) ->
            testParallelSuccess = Action.parallel [monadicActionFoo('data1'), monadicActionBar('data2')]
            testParallelSuccess
            .next (datas) ->
                assertData datas[0], 'data1foo'
                assertData datas[1], 'data2bar'
            .go ->
                console.log 'Action.parallel without error ok'
                cb()

    .next ->
        new Action (cb) ->
            testParallelSuccessWithError = Action.parallel [monadicActionFoo('data1'), monadicActionFail('data2')]
            testParallelSuccessWithError
            .next (datas) ->
                assertData datas[0], 'data1foo'
                assertData datas[1].message, 'testError'
            .go ->
                console.log 'Action.parallel with error ok'
                cb()

    .next ->
        new Action (cb) ->
            testParallelEmpty= Action.parallel []
            testParallelEmpty
            .next (datas) ->
                assertData datas.length, 0
            .go ->
                console.log 'Action.parallel with empty Array ok'
                cb()
