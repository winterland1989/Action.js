Action = require '../Action.coffee'
{assertData, monadicActionFoo, monadicActionBar, monadicActionFail} = require './fixture.coffee'

module.exports =
    new Action (cb) ->
        testSeq = Action.chain [monadicActionFoo, monadicActionBar]
        testSeq('data')
        .next (data) ->
            assertData data, 'datafoobar'
        .next ->
            console.log 'Action.chain ok'
        .next ->
            testSeqWithError = Action.chain [monadicActionFoo, monadicActionFail, monadicActionBar]
            testSeqWithError('data')
        .next (data) ->
            assertData data, 'this wont fire'
        .guard (e) ->
            assertData e.message, 'testError'
        .go ->
            console.log 'Action.chain with error ok'
            cb()
