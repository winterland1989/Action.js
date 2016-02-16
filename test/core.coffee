Action = require '../Action.coffee'
{assertData, actionFoo} = require './fixture.coffee'

module.exports =
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
        .guard 'notTestError', (e) ->
            throw new Error 'This will skipped'
            e
        .guard 'testError', (e) ->
            assertData e.message, 'testError'
            e.message = 'testErrorChanged'
            e
        .guard (e) ->
            assertData e.message, 'testErrorChanged'
            'errorHandled'
        .next (data) ->
            assertData data, 'errorHandled'
        .go ->
            console.log 'Core function ok'
            cb()
