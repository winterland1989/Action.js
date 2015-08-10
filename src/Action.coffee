ignore = ->

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

Action.wrap = (data) ->
    new Action (cb) -> cb data

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
    else Action.wrap new Error 'No monadic actions given'

Action.any = (actions) ->
    new Action (cb) ->
        for action in actions
            action._go (data) ->
                cb data
                cb = ignore

Action.anySuccess = (actions) ->
    countDown = actions.length
    new Action (cb) ->
        for action in actions
            action._go (data) ->
                countDown--
                if data not instanceof Error
                    cb data
                    cb = ignore
                    countDown = -1
                else if countDown == 0
                    cb new Error 'All actions failed'

Action.retry = (times, action) ->
    a = action.guard (e) ->
        if times-- != 0 then a
        else new Error 'Retry limit reached'
    a

Action.gapRetry = (times, interval, action) ->
    a = action.guard (e) ->
        new Action (cb) ->
            setTimeout cb, interval
        .next ->
            if times-- != 0 then a
            else new Error 'Retry limit reached'
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
                    cb = ignore
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

Action.sequenceTry = (args, monadicAction) ->
    length = args.length
    countUp = 0
    a = (arg) ->
        monadicAction(arg).guard (e) ->
            if countUp++ < length
                a(args[countUp])
            else
                new Error 'Try limit reached'
    if length > 0
        a(args[0])
    else Action.wrap new Error 'No argmuents for monadic'

Action.mkNodeAction = (nodeAPI, arg) ->
    new Action (cb) ->
        nodeAPI arg, (err, data) ->
            cb if err then err else data

module.exports = Action
