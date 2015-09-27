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

testAction = Action.wrap()
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
        testSeq = Action.chain [monadicActionFoo, monadicActionBar]
        testSeq('data')
        .next (data) ->
            assertData data, 'datafoobar'
        .go ->
            console.log 'Action.chain ok'
            cb()

.next ->
    new Action (cb) ->
        testSeqWithError = Action.chain [monadicActionFoo, monadicActionFail, monadicActionBar]
        testSeqWithError('data')
        .next (data) ->
            assertData data, 'this wont fire'
        .guard (e) ->
            assertData e.message, 'testError'
        .go ->
            console.log 'Action.chain with error ok'
            cb()

.next ->
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
            assertData e.message, 'All actions failed'
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

.next ->
    console.log 'Test Action.delay'
    new Action (cb) ->

        testDelay = Action.delay 1000, monadicActionFoo('data1')
        testDelay
        .next (data) ->
            assertData data, 'data1foo'
        .go ->
            console.log 'Action.delay with error ok'
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
        testAll = Action.parallel [monadicActionFoo('data1'), monadicActionBar('data2')]
        testAll
        .next (datas) ->
            assertData datas[0], 'data1foo'
            assertData datas[1], 'data2bar'
        .go ->
            console.log 'Action.all without error ok'
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
            console.log 'Action.all with error ok'
            cb()

.next ->
    new Action (cb) ->
        testAllSuccess = Action.parallel [monadicActionFoo('data1'), monadicActionBar('data2')]
        testAllSuccess
        .next (datas) ->
            assertData datas[0], 'data1foo'
            assertData datas[1], 'data2bar'
        .go ->
            console.log 'Action.allSuccess without error ok'
            cb()

.next ->
    new Action (cb) ->
        testAllSuccessWithError = Action.parallel [monadicActionFoo('data1'), monadicActionFail('data2')]
        testAllSuccessWithError
        .next (datas) ->
            assertData datas[0], 'data1foo'
            assertData datas[1].message, 'testError'
        .go ->
            console.log 'Action.allSuccess with error ok'
            cb()

.next ->
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

.go -> console.log 'test all passed'
