Action = require '../src/Action'
Promise = require './bluebird.js'

new Action (cb) ->
    start = Date.now()

    mkPromise = (acc) ->
        new Promise (resolve, reject) ->
            resolve acc + 1

    p = mkPromise(0)
    for i in [0..1000]
        p = p.then mkPromise

    p.then (acc) ->
        console.log acc, ' should be 1002, use time: ', Date.now() - start
        cb()

.next ->
    new Action (cb) ->

        start = Date.now()

        monadicAction = (acc) ->
            new Action (cb) ->
                cb acc + 1

        a = monadicAction(0)
        for i in [0..1000]
            a = a.next monadicAction

        a.go (acc) ->
            console.log acc, ' should be 1002, use time: ', Date.now() - start
        cb()

.next ->
    new Action (cb) ->
        start = Date.now()

        mkPromise = (acc) ->
            new Promise (resolve, reject) ->
                setTimeout(
                    -> resolve acc + 1
                    0
                )

        p = mkPromise(0)
        for i in [0..1000]
            p = p.then mkPromise

        p.then (acc) ->
            console.log acc, ' should be 1002, use time: ', Date.now() - start
            cb()

.next ->
    new Action (cb) ->

        start = Date.now()

        monadicAction = (acc) ->
            new Action (cb) ->
                setTimeout(
                    -> cb acc + 1
                    0
                )

        a = monadicAction(0)
        for i in [0..1000]
            a = a.next monadicAction

        a.go (acc) ->
            console.log acc, ' should be 1002, use time: ', Date.now() - start
        cb()

.go()
