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

randomAction = new Action (cb) ->
    setTimeout(
        ->
            res = Math.random()
            console.log 'random action game seeding: ', res
            if res > 0.9
                cb 'good'
            else cb new Error 'bad'
        50
    )

freezeAction = Action.freeze new Action (cb) ->
    setTimeout(
        ->
            res = Math.random()
            console.log 'random freezed game seeding: ', res
            cb res
        1000
    )

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
        a = Action.repeat 10,
            freezeAction.next (data) -> console.log data
        .go ->
            console.log 'Freezed action should resolve once'
            cb()

.next ->
    new Action (cb) ->
        freezeAction
        .next (data) ->
            new Action (cb) ->
                setTimeout(
                    ->
                        console.log data
                        cb()
                    1000
                )
        .go ->
            console.log 'Freezed action should resolve once after a timeout'
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

        testAny = Action.any [monadicActionFoo('data1'), monadicActionBar('data2')]
        testAny
        .next (data) ->
            assertData data, 'data1foo'
        .go ->
            console.log 'Action.any without error ok'
            cb()

.next ->
    new Action (cb) ->

        testAnyWhenError = Action.any [monadicActionBar('data1'), monadicActionFail('data2')]
        testAnyWhenError
        .next (data) ->
            assertData data, 'this wont fire'
        .guard (e) ->
            assertData e.message, 'testError'
        .go ->
            console.log 'Action.any with error ok'
            cb()

.next ->
    new Action (cb) ->

        testAnySuccess = Action.anySuccess [monadicActionFoo('data1'), monadicActionBar('data2')]
        testAnySuccess
        .next (data) ->
            assertData data, 'data1foo'
        .go ->
            console.log 'Action.anySuccess without error ok'
            cb()

.next ->
    new Action (cb) ->

        testAnySuccessWhenError1 = Action.anySuccess [monadicActionFoo('data1'), monadicActionFail('data2')]
        testAnySuccessWhenError1
        .next (data) ->
            assertData data, 'data1foo'
        .go ->
            console.log 'Action.anySuccess with error 1 ok'
            cb()

.next ->
    new Action (cb) ->

        testAnySuccessWhenError2 = Action.anySuccess [monadicActionBar('data1'), monadicActionFail('data2')]
        testAnySuccessWhenError2
        .next (data) ->
            assertData data, 'data1bar'
        .go ->
            console.log 'Action.anySuccess with error 2 ok'
            cb()

.next ->
    new Action (cb) ->

        testAnySuccessWhenALLError = Action.anySuccess [monadicActionFail('data1'), monadicActionFail('data2')]
        testAnySuccessWhenALLError
        .next (data) ->
            assertData data, 'this wont fire'
        .guard (e) ->
            assertData e.message, 'All actions failed'
        .go ->
            console.log 'Action.anySuccess with all error ok'
            cb()

.next ->
    new Action (cb) ->

        testRetryAllError = Action.retry(3, monadicActionFail('data2'))
        testRetryAllError
        .next (data) ->
            assertData data, 'this wont fire'
        .guard (e) ->
            assertData e.message, 'Retry limit reached'
        .go ->
            console.log 'Action.retry with all Error ok'
            cb()

.next ->
    new Action (cb) ->
        console.log(
            """
            random action game,
            this game will pass 'good' if seed > 0.9, pass error 'bad' if not
            retry 3 times
            """
        )
        testRetry = Action.retry(3, randomAction)
        testRetry
        .next (data) ->
            assertData data, 'good'
        .guard (e) ->
            assertData e.message, 'Retry limit reached'
        .go ->
            console.log 'Action.retry ok'
            cb()

.next ->
    new Action (cb) ->

        console.log "retry 10 times"
        testRetry = Action.retry(10, randomAction)
        testRetry
        .next (data) ->
            assertData data, 'good'
        .guard (e) ->
            assertData e.message, 'Retry limit reached'
        .go ->
            console.log 'Action.retry ok'
            cb()

.next ->
    new Action (cb) ->

        console.log "retry forever"
        testRetry = Action.retry(-1, randomAction)
        testRetry
        .next (data) ->
            assertData data, 'good'
        .guard (e) ->
            assertData e.message, 'Retry limit reached'
        .go ->
            console.log 'Action.retry ok'
            cb()

.next ->
    new Action (cb) ->
        console.log(
            """
            random action game,
            this game will pass 'good' if seed > 0.9, pass error 'bad' if not
            retry 3 times
            """
        )
        testGapRetry = Action.gapRetry(3, 1000, randomAction)
        testGapRetry
        .next (data) ->
            assertData data, 'good'
        .guard (e) ->
            assertData e.message, 'Retry limit reached'
        .go ->
            console.log 'Action.gapRetry ok'
            cb()

.next ->
    new Action (cb) ->

        console.log "retry 10 times"
        testGapRetry = Action.gapRetry(10, 1000, randomAction)
        testGapRetry
        .next (data) ->
            assertData data, 'good'
        .guard (e) ->
            assertData e.message, 'Retry limit reached'
        .go ->
            console.log 'Action.gapRetry ok'
            cb()

.next ->
    new Action (cb) ->

        console.log "retry forever"
        testGapRetry = Action.gapRetry(-1, 1000, randomAction)
        testGapRetry
        .next (data) ->
            assertData data, 'good'
        .guard (e) ->
            assertData e.message, 'Retry limit reached'
        .go ->
            console.log 'Action.gapRetry ok'
            cb()

.next ->
    new Action (cb) ->
        testAll = Action.all [monadicActionFoo('data1'), monadicActionBar('data2')]
        testAll
        .next (datas) ->
            assertData datas[0], 'data1foo'
            assertData datas[1], 'data2bar'
        .go ->
            console.log 'Action.all without error ok'
            cb()

.next ->
    new Action (cb) ->
        testAllWithError = Action.all [monadicActionFoo('data1'), monadicActionFail('data2')]
        testAllWithError
        .next (datas) ->
            assertData datas[0], 'this wont fire'
        .guard (e) ->
            assertData e.message, 'testError'
        .go ->
            console.log 'Action.all with error ok'
            cb()

.next ->
    new Action (cb) ->
        testAllSuccess = Action.allSuccess [monadicActionFoo('data1'), monadicActionBar('data2')]
        testAllSuccess
        .next (datas) ->
            assertData datas[0], 'data1foo'
            assertData datas[1], 'data2bar'
        .go ->
            console.log 'Action.allSuccess without error ok'
            cb()

.next ->
    new Action (cb) ->
        testAllSuccessWithError = Action.allSuccess [monadicActionFoo('data1'), monadicActionFail('data2')]
        testAllSuccessWithError
        .next (datas) ->
            assertData datas[0], 'data1foo'
            assertData datas[1].message, 'testError'
        .go ->
            console.log 'Action.allSuccess with error ok'
            cb()

.next ->
    new Action (cb) ->
        testSequenceTry = Action.sequenceTry ['data1', 'data2'], monadicActionFoo
        testSequenceTry
        .next (data) ->
            assertData data, 'data1foo'
        .go ->
            console.log 'Action.sequenceTry without error ok'
            cb()

.next ->
    monadicActionBigger = (threshold) -> new Action (cb) ->
        setTimeout(
            ->
                if threshold > 0.9
                    cb 'good: ' + threshold
                else cb new Error 'bad'
            50
        )
    new Action (cb) ->
        testSequenceTryWithError = Action.sequenceTry [0.13, 0.43, 0.91, 0.14], monadicActionBigger
        testSequenceTryWithError
        .next (data) ->
            assertData data, 'good: 0.91'
        .go ->
            console.log 'Action.sequenceTry with error ok'
            cb()

.next ->

    new Action (cb) ->
        testSequenceTryWithAllError = Action.sequenceTry ['', '', ''], monadicActionFail
        testSequenceTryWithAllError
        .next (data) ->
            assertData data, 'this wont fire'
        .guard (e) ->
            assertData e.message, 'Try limit reached'
        .go ->
            console.log 'Action.sequenceTry with all error ok'
            cb()


.go -> console.log 'test all passed'
