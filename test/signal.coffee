Action = require '../Action.coffee'
readline = require 'readline'

{assertData, signalAction, actionFoo, actionFail} = require './fixture.coffee'

testSignal = undefined
testSignalError = undefined

module.exports =
    new Action (cb) ->
        pumps = Action.fuseSignal [ signalAction, signalAction ]
        .next (data) ->
            assertData data[0], 'signalfoo'
            assertData data[1], 'signalbar'
        .go ->
            console.log 'Action.fuseSignal without error ok'

        console.log 'fused signal will be lanched in 200ms'

        setTimeout(
            ->
                pumps[0]('foo')
                pumps[1]('bar')
                cb()
        ,   200
        )
    .next ->
        new Action (cb) ->
            pumps = Action.fuseSignal [ signalAction, signalAction ], true
            .guard (data) ->
                assertData data.message, 'testError'
            .go ->
                console.log 'Action.fuseSignal with error ok'

            console.log 'fused signal will be lanched in 200ms'

            setTimeout(
                ->
                    pumps[0](new Error 'testError')
                    pumps[1](new Error 'testError')
                    cb()
            ,   200
            )
    .next ->
        new Action (cb) ->
            testSignalPump =
                Action.signal
                .next (data) ->
                    assertData data, 'foo'
                .go ->
                    console.log 'Action.signal pumped by Action without error ok'
                    cb()

            actionFoo._go(testSignalPump)

    .next ->
        new Action (cb) ->
            testSignalPump =
                Action.signal
                .guard (err) ->
                    assertData err.message, 'testError'
                .go ->
                    console.log 'Action.signal pumped by Action with error ok'
                    cb()

            actionFail._go(testSignalPump)

    .next ->
        new Action (cb) ->
            testSignalPump =
                Action.signal
                .next (data) ->
                    console.log 'You said: ' + data + ', test finished'
                .go ->
                    console.log 'Action.signal without error ok'

            testSignalErrorPump =
                Action.signal
                .next (data) ->
                    console.log 'this will be skipped'
                .guard (err) ->
                    assertData err.message, 'testError'
                .go ->
                    console.log 'Action.signal with error ok'

            rl = readline.createInterface
                input: process.stdin,
                output: process.stdout

            rl.question "Type something to fire signal, and finish test ", (answer) ->
                rl.close()
                testSignalPump answer
                testSignalErrorPump new Error 'testError'
                cb()
