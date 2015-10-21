Action = require '../Action.coffee'
{assertData, randomAction} = require './fixture.coffee'

module.exports =
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
            assertData e.message, 'RETRY_ERROR: Retry limit reached'
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
                assertData e.message, 'RETRY_ERROR: Retry limit reached'
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
                assertData e.message, 'RETRY_ERROR: Retry limit reached'
            .go ->
                console.log 'Action.retry ok'
                cb()
