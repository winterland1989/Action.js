Action = require '../Action.coffee'

module.exports =

    assertData: (data, target, label) ->
        if data != target
            console.log data, ' not equal to ',target
            throw new Error 'Assert failed.'

    actionFoo: new Action (cb) ->
        setTimeout ( -> cb 'foo'), 100

    actionBar: new Action (cb) ->
        setTimeout ( -> cb 'bar'), 200

    actionFail: new Action (cb) ->
            setTimeout ( -> cb new Error 'testError'), 150

    monadicActionFoo: (data) ->
        new Action (cb) ->
            setTimeout ( -> cb data + 'foo'), 100

    monadicActionBar: (data) ->
        new Action (cb) ->
            setTimeout ( -> cb data + 'bar'), 200

    monadicActionFail: (data) ->
        new Action (cb) ->
            setTimeout ( -> cb new Error 'testError'), 150

    randomAction: new Action (cb) ->
        setTimeout(
            ->
                res = Math.random()
                console.log 'random action game seeding: ', res
                if res > 0.9
                    cb 'good'
                else cb new Error 'bad'
            50
        )

    signalAction: Action.signal.next (w) -> 'signal' + w
