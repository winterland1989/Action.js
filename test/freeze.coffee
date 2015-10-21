Action = require '../Action.coffee'

module.exports =
    new Action (cb) ->
        freezeAction = Action.freeze new Action (cb) ->
            setTimeout(
                ->
                    res = Math.random()
                    console.log 'random freezed game seeding: ', res
                    cb res
                1000
            )

        a = Action.repeat 10,
            freezeAction.next (data) ->
                console.log data
        .next ->
            console.log 'Freezed action should resolve with same value'

        .next ->
            freezeAction.next (data) ->
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
