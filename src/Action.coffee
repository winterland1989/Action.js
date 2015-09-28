# helper functions

# ignore params
ignore = ->

# return an array repicate x n times if n > 0, else return []
replicate = (x, n) -> while n-- >0 then x

# Main class
class Action
    # save an action to feed callback later
    constructor: (@action) ->

    # simplily fire action with given callback
    _go: (cb) -> @action cb

    # return a new Action that when fire, it will call current action first, then the callback
    _next: (cb) ->
        self = @
        new Action (_cb) ->
            self.action (data) ->
                _data = cb(data)
                # if a cb return an Action
                if _data instanceof Action
                    _data._go _cb
                else _cb _data

    # return a new Action that when fire, it will call current action first, then the callback
    # if current action want to pass an error to the callback, stop it and pass it on
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

    # return a new Action that when fire, it will call current action first, then the callback
    # if current action want to pass a non error value to the callback, stop it and pass it on
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

    # fire the callback chain with given callback(or ignore), any unhandled error will be thrown
    go: (cb) ->
        @action (data) ->
            if data instanceof Error
                throw data
            else if cb? then cb data


# Action error list
Action.ERR_RETRY_LIMIT_REACHED = new Error 'Retry limit reached'
Action.ERR_ALL_ACTIONS_FAILED = new Error 'All actions failed'


# wrap a value in an Action
Action.wrap = (data) ->
    new Action (cb) -> cb data

# fire current callback chain now, and save pending callbacks, when async action finish, feed the value to them
Action.freeze = (action) ->
    pending = true
    data = undefined
    callbacks = []
    action._go (_data) ->
        if pending
            data = _data
            pending = false
            for cb in callbacks then cb _data
            cb = []
    new Action (cb) ->
        if pending then callbacks.push cb
        else cb data

# helper to supply custom error
Action.safe = (err, fn) -> (data) ->
    try fn(data) catch e then err

# helper to return raw error
Action.safeRaw = (fn) -> (data) ->
    try fn(data) catch e then e

# heler to chain monadic actions
Action.chain = (monadicActions) -> (init) ->
    if monadicActions.length > 0
        a = monadicActions[0](init)
        for monadicAction in monadicActions[1..]
            a = a.next monadicAction
        a
    else Action.wrap undefined

# repeat an Action n times
Action.repeat = (times, action, stopAtError = false) ->
    a = action._next (data) ->
        if ((data instanceof Error) and stopAtError) or times-- == 0
            data
        else a

# delay an Action in millisecond
Action.delay = (delay, action) ->
    new Action (cb) ->
        setTimeout cb, delay
    ._next -> action

# retry an Action n times if it failed
Action.retry = (times, action) ->
    a = action.guard (e) ->
        if times-- != 0 then a
        else Action.ERR_RETRY_LIMIT_REACHED

# retry an Action n times if it failed
Action.gapRetry = (times, delay, action) ->
    a = (Action.delay delay, action).guard (e) ->
        if times-- != 0 then a
        else Action.ERR_RETRY_LIMIT_REACHED

# run an Array of Actions in parallel, return an Action wraps results in an Array
Action.parallel = (actions, stopAtError = false) ->
    results = []
    countDown = actions.length
    new Action (cb) ->
        if countDown > 0
            # we have to remember the index here to get the results in order
            for action, i in actions then do (index = i) ->
                action._go (data) ->
                    countDown--
                    if (data instanceof Error) and stopAtError
                        cb data
                        cb = ignore
                    else
                        results[index] = data
                        if countDown == 0
                            cb results
        else cb result

# run an Array of Actions in parallel, return an Action wraps first result
Action.race = (actions, stopAtError = false) ->
    countDown = actions.length
    new Action (cb) ->
        if countDown == 0
            cb Action.ERR_ALL_ACTIONS_FAILED
        else for action in actions
            action._go (data) ->
                countDown--
                if (data not instanceof Error) or stopAtError
                    cb data
                    cb = ignore
                    countDown = -1
                else if countDown == 0
                    cb Action.ERR_ALL_ACTIONS_FAILED

# run an Array of Actions in sequence, return an Action wraps results in an Array
Action.sequence = (actions, stopAtError = false) ->
    results = []
    countDown = actions.length
    if countDown > 0
        a = actions[0]
        for action in actions[1..] then do (action = action) ->
            a = a._next (data) ->
                if (data instanceof Error) and stopAtError
                    data
                else
                    results.push data
                    action

        a._next (data) ->
            if (data instanceof Error) and stopAtError
                data
            else
                results.push data
                results

    else Action.wrap results

# make an Action from a node style function
Action.makeNodeAction = (nodeAPI, arg) ->
    new Action (cb) ->
        nodeAPI arg, (err, data) ->
            cb if err then err else data

if module? and  module.exports?
    module.exports = Action
else if (typeof define == "function" and define.amd)
    define () -> Action
else if window?
    window.Action = Actions
