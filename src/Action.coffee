doNothing = ->

class Action
    constructor: (@action) ->

    _go: (cb) -> @action cb

    next: (cb) ->
        self = @
        new Action (_cb) ->
            self.action (data) ->
                if data instanceof Error
                    _cb data
                else
                    _data = cb(data)
                    # if a cb return an Action
                    if _data instanceof Action
                        _data._go _cb
                    else _cb _data

    guard: (cb) ->
        self = @
        new Action (_cb) ->
            self.action (data) ->
                if data instanceof Error
                    _data = cb data
                    if _data instanceof Action
                        _data._go _cb
                    else
                        _cb _data

                else _cb data

    go: (cb) ->
        @action (data) ->
            if data instanceof Error
                throw data
            else if cb? then cb data

Action.safe = (err, fn) -> (data) ->
    try fn(data) catch e then err

Action.safeRaw = (fn) -> (data) ->
    try fn(data) catch e then e

Action.sequence = (monadicActions) -> (init) ->
    if monadicActions.length > 0
        a = monadicActions[0](init)
        for monadicAction in monadicActions[1..]
            a = a.next monadicAction
        a
    else throw new Error 'No monadic actions given'


Action.any = (actions) ->
    new Action (cb) ->
        for action in actions
            action._go (data) ->
                cb data
                cb = doNothing

Action.anySuccess = (actions) ->
    countDown = actions.length
    new Action (cb) ->
        for action in actions
            action._go (data) ->
                countDown--
                if data not instanceof Error
                    cb data
                    cb = doNothing
                    countDown = -1
                else if countDown == 0
                    cb new Error 'All actions failed'

Action.retry = (times, action) ->
    a = action.guard (e) ->
        if times-- > 0
            a
        else
            new Error 'Retry limit reached'
    a

Action.all = (actions) ->
    results = []
    countDown = actions.length
    new Action (cb) ->
        for action, i in actions then do (index = i) ->
            action._go (data) ->
                countDown--
                if data instanceof Error
                    cb data
                    cb = doNothing
                else
                    results[index] = data
                    if countDown == 0
                        cb results

Action.allSuccess = (actions) ->
    results = []
    countDown = actions.length
    new Action (cb) ->
        for action, i in actions then do (index = i) ->
            action._go (data) ->
                countDown--
                results[index] = data
                if countDown == 0
                    cb results

Action.multiTry = (args, mondicAction) ->
    countDown = args.length
    new Action (cb) ->
        replica = for a in args then do (arg = a) ->
            (cont) ->
                new Action (_cb) ->
                    if cont then (mondicAction arg)._go (data) ->
                        countDown--
                        if data not instanceof Error
                            cb data
                            cb = doNothing
                            _cb false
                        else
                            _cb true
                            if countDown-- == 0
                                cb new Error 'Try limit reached'
                    else _cb false

        Action.sequence(replica)(true).go()

module.exports = Action
