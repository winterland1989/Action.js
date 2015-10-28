Action = require '../Action.coffee'
readline = require 'readline'

{assertData} = require './fixture.coffee'

testSignal = undefined
testSignalError = undefined

module.exports =
    new Action (cb) ->
        testSignal =
            Action.signal
            .next (data) ->
                console.log 'You said: ' + data + ', test finished'
            .go ->
                console.log 'Action.signal without error ok'

        testSignalError =
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
            testSignal answer
            testSignalError new Error 'testError'
            cb()

