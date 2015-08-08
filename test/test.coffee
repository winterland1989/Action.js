Action = require '../src/Action'

assertData = (data, target, label) ->
    if data != target
        console.log data, ' not equal to ',target
        throw new Error 'Assert failed.'

actionFoo = new Action (cb) ->
    setTimeout ( -> cb 'foo'), 100


monadicActionFoo = (data) ->
    new Action (cb) ->
        setTimeout ( -> cb data + 'foo'), 100

monadicActionBar = (data) ->
    new Action (cb) ->
        setTimeout ( -> cb data + 'bar'), 200

monadicActionFail = (data) ->
    new Action (cb) ->
        setTimeout ( -> cb new Error 'testError'), 150

testAction = new Action (cb) -> cb()
testAction
.next ->
    new Action (cb) ->
        actionFoo
        .next (data) ->
            assertData data, 'foo'
            data + 'bar'
        .next (data) ->
            assertData data, 'foobar'
            new Action (cb) ->
                cb 'syncAction'
        .next (data) ->
            assertData data, 'syncAction'
            new Action (cb) ->
                setTimeout ( -> cb 'asyncAction', 100)

        .next (data) ->
            assertData data, 'asyncAction'
            return new Error 'testError'
        .next (data) ->
            assertData data, 'this assert won\'t run'
        .guard (e) ->
            assertData e.message, 'testError'
            'errorHandled'
        .next (data) ->
            assertData data, 'errorHandled'
        .go ->
            console.log 'Core function ok'
            cb()

.next ->
    new Action (cb) ->
        testSeq = Action.sequence [monadicActionFoo, monadicActionBar]
        testSeq('data')
        .next (data) ->
            assertData data, 'datafoobar'
        .go ->
            console.log 'Action.sequence ok'
            cb()

.next ->
    new Action (cb) ->
        testSeqWithError = Action.sequence [monadicActionFoo, monadicActionFail, monadicActionBar]
        testSeqWithError('data')
        .next (data) ->
            assertData data, 'this wont fire'
        .guard (e) ->
            assertData e.message, 'testError'
        .go ->
            console.log 'Action.sequence with error ok'
            cb()

.next ->
    new Action (cb) ->

        testAny = Action.any [monadicActionFoo, monadicActionBar]
        testAny(['data1', 'data2'])
        .next (data) ->
            assertData data, 'data1foo'
        .go ->
            console.log 'Action.any without error ok'
            cb()

.next ->
    new Action (cb) ->

        testAnyWhenError = Action.any [monadicActionBar, monadicActionFail]
        testAnyWhenError(['data1', 'data2'])
        .next (data) ->
            assertData data, 'this wont fire'
        .guard (e) ->
            assertData e.message, 'testError'
        .go ->
            console.log 'Action.any with error ok'
            cb()

.next ->
    new Action (cb) ->

        testAnySuccess = Action.anySuccess [monadicActionFoo, monadicActionBar]
        testAnySuccess(['data1', 'data2'])
        .next (data) ->
            assertData data, 'data1foo'
        .go ->
            console.log 'Action.anySuccess without error ok'
            cb()

.next ->
    new Action (cb) ->

        testAnySuccessWhenError1 = Action.anySuccess [monadicActionFoo, monadicActionFail]
        testAnySuccessWhenError1(['data1', 'data2'])
        .next (data) ->
            assertData data, 'data1foo'
        .go ->
            console.log 'Action.anySuccess with error 1 ok'
            cb()

.next ->
    new Action (cb) ->

        testAnySuccessWhenError2 = Action.anySuccess [monadicActionBar, monadicActionFail]
        testAnySuccessWhenError2(['data1', 'data2'])
        .next (data) ->
            assertData data, 'data1bar'
        .go ->
            console.log 'Action.anySuccess with error 2 ok'
            cb()

.next ->
    new Action (cb) ->

        testAnySuccessWhenALLError = Action.anySuccess [monadicActionFail, monadicActionFail]
        testAnySuccessWhenALLError(['data1', 'data2'])
        .next (data) ->
            assertData data, 'this wont fire'
        .guard (e) ->
            assertData e.message, 'All actions failed'
        .go ->
            console.log 'Action.anySuccess with all error ok'
            cb()

.next ->
    new Action (cb) ->


.go -> console.log 'test all passed'
