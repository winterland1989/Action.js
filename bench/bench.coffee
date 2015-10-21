Action = require '../Action.coffee'
PromiseBlueBird = require './bluebird.js'
os = require 'os'

checkMem = ->
    mem = process.memoryUsage()
    memFormat = []
    for k, v of mem
        memFormat.push "#{k} - #{Math.floor(v / 1024 / 1024)}mb"

    memFormat.join ' | '


console.log(
    """
        Node #{process.version}
        OS   #{os.platform()}
        Arch #{os.arch()}
        CPU  #{os.cpus()[0].model}

    """
)

new Action (cb) ->
    console.log 'Sequence run sync operation 100000 times:'
    start = Date.now()

    p = Promise.resolve 0

    for i in [1..100000]
        p = p.then (x) -> x + 1

    initTime = Date.now()

    p.then (acc) ->
        if (acc != 100000)
            console.log 'Checksum wrong, check your test'
        else
            console.log(
                """

                Native
                init time:  #{initTime - start}ms
                total time: #{Date.now() - start}ms
                memory:     #{checkMem()}

                """
            )
        cb()

.next ->
    new Action (cb) ->
        start = Date.now()

        p = PromiseBlueBird.resolve 0

        for i in [1..100000]
            p = p.then (x) -> x + 1

        initTime = Date.now()

        p.then (acc) ->
            if (acc != 100000)
                console.log 'Checksum wrong, check your test'
            else
                console.log(
                    """

                    Bluebird v2.9.34
                    init time:  #{initTime - start}ms
                    total time: #{Date.now() - start}ms
                    memory:     #{checkMem()}

                    """
                )
            cb()

.next ->
    new Action (cb) ->

        start = Date.now()
        a = Action.wrap 0
        for i in [1..100000]
            a = a.next (x) -> x + 1
            # keep callback depth under runtime limit
            if i % 1000 == 0
                a = Action.freeze a

        initTime = Date.now()
        a.go (acc) ->
            if (acc != 100000)
                console.log 'Checksum wrong, check your test'
            else
                console.log(
                    """

                    Action.js v1.0.0
                    init time:  #{initTime - start}ms
                    total time: #{Date.now() - start}ms
                    memory:     #{checkMem()}

                    """
                )
            cb()

.next ->
    console.log 'Sequence run async operation 1000 times:'
    new Action (cb) ->
        start = Date.now()

        p = Promise.resolve 0
        for i in [1..1000]
            p = p.then (x) ->
                new Promise (resolve, reject) ->
                    setTimeout(
                        -> resolve x + 1
                        0
                    )

        initTime = Date.now()
        p.then (acc) ->
            if (acc != 1000)
                console.log 'Checksum wrong, check your test'
            else
                console.log(
                    """

                    Native v2.9.34
                    init time:  #{initTime - start}ms
                    total time: #{Date.now() - start}ms
                    memory:     #{checkMem()}

                    """
                )
            cb()

.next ->
    new Action (cb) ->
        start = Date.now()

        p = PromiseBlueBird.resolve 0
        for i in [1..1000]
            p = p.then (x) ->
                new Promise (resolve, reject) ->
                    setTimeout(
                        -> resolve x + 1
                        0
                    )

        initTime = Date.now()
        p.then (acc) ->
            if (acc != 1000)
                console.log 'Checksum wrong, check your test'
            else
                console.log(
                    """

                    Bluebird v2.9.34
                    init time:  #{initTime - start}ms
                    total time: #{Date.now() - start}ms
                    memory:     #{checkMem()}

                    """
                )
            cb()

.next ->
    new Action (cb) ->

        start = Date.now()

        a = Action.wrap 0
        for i in [1..1000]
            a = a.next  (x) ->
                new Action (cb) ->
                    setTimeout(
                        -> cb x + 1
                        0
                    )

        initTime = Date.now()
        a.go (acc) ->
            if (acc != 1000)
                console.log 'Checksum wrong, check your test'
            else
                console.log(
                    """

                    Action.js v1.0.0
                    init time:  #{initTime - start}ms
                    total time: #{Date.now() - start}ms
                    memory:     #{checkMem()}

                    """
                )
            cb()
.go()


