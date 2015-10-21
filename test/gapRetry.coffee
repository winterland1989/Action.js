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
        testGapRetry = Action.gapRetry(3, 300, randomAction)
        testGapRetry
        .next (data) ->
            assertData data, 'good'
        .guard (e) ->
            assertData e.message, 'RETRY_ERROR: Retry limit reached'
        .go ->
            console.log 'Action.gapRetry ok'
            cb()

    .next ->
        new Action (cb) ->

            console.log "retry 10 times"
            testGapRetry = Action.gapRetry(10, 300, randomAction)
            testGapRetry
            .next (data) ->
                assertData data, 'good'
            .guard (e) ->
                assertData e.message, 'RETRY_ERROR: Retry limit reached'
            .go ->
                console.log 'Action.gapRetry ok'
                cb()

    .next ->
        new Action (cb) ->

            console.log "retry forever"
            testGapRetry = Action.gapRetry(-1, 300, randomAction)
            testGapRetry
            .next (data) ->
                assertData data, 'good'
            .guard (e) ->
                assertData e.message, 'RETRY_ERROR: Retry limit reached'
            .go ->
                console.log 'Action.gapRetry ok'
                cb()
