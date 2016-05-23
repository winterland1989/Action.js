# helper for auto choosing fmap or >>=
fireByResult = (cb, data) ->
    if data instanceof Action then data._go cb
    else cb data

# Main class
class Action
    # save an action to feed callback later
    constructor: (@_go) ->

    # return a new Action that when fire, it will call current action first, then the callback
    _next: (cb) ->
        self = @
        new Action (_cb) ->
            self._go (data) -> fireByResult(_cb, cb(data))

    # return a new Action that when fire, it will call current action first, then the callback
    # if current action want to pass an error to the callback, stop it and pass it on
    next: (cb) ->
        self = @
        new Action (_cb) ->
            self._go (data) ->
                if data instanceof Error
                    _cb data
                else fireByResult _cb, cb(data)

    # return a new Action that when fire, it will call current action first, then the callback
    # if current action want to pass a non error value to the callback, stop it and pass it on
    # you can optional pass a prefix to filter Error by their message
    guard: (prefix, cb) ->
        unless cb? then cb = prefix; prefix = undefined
        self = @
        new Action (_cb) ->
            self._go (data) ->
                if data instanceof Error and (!prefix or (data.message.indexOf prefix) == 0)
                    fireByResult _cb, cb(data)
                else _cb data

    # fire the callback chain with given callback(or ignore), any unhandled error will be thrown
    go: (cb) ->
        @_go (data) ->
            if data instanceof Error
                throw data
            else
                if cb? then cb(data) else data

# wrap a value in an Action
Action.wrap = (data) -> new Action (cb) -> cb data

# signal Action, when fired, the callback chain are returned directly.
Action.signal = new Action (cb) -> cb

# fuse a signal array.
Action.fuseSignal = (actions, fireAtError = false) ->
    l = actions.length
    if l > 0
        new Action (cb) ->
            results = new Array(l)
            returns = new Array(l)
            flags = new Array(l)
            for i in [0..l-1] then flags[i] = false
            fireByIndex = (index) -> (data) ->
                results[index] = data
                flags[index] = true
                noErrorAndFalse = true
                for i in [0..l-1]
                    if flags[i] == false
                        noErrorAndFalse = false
                    if results[i] instanceof Error and fireAtError
                        noErrorAndFalse = false
                        cb results[i]
                        break
                if noErrorAndFalse then cb results
            for action, i in actions
                returns[i] = action._go fireByIndex(i)
            returns
    else Action.wrap []

# fire current callback chain now, and save pending callbacks, when async action finish, feed the value to them
Action.freeze = (action) ->
    pending = true
    data = undefined
    callbacks = []
    handler = action._go (_data) ->
        if pending
            data = _data
            pending = false
            for cb in callbacks then cb _data
            callbacks = undefined
    new Action (cb) ->
        if pending then callbacks.push cb else cb data
        handler

# helper to supply custom error
Action.safe = (err, fn) -> (data) ->
    try fn(data) catch e then err

# helper to return raw error
Action.safeRaw = (fn) -> (data) ->
    try fn(data) catch e then e

# helper to chain monadic actions
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
        else new Error 'RETRY_ERROR: Retry limit reached'

# run an Array of Actions in parallel, return an Action wraps results in an Array
# after returned Action are fired, there will be maxmium n source Actions are running.
Action.throttle = (actions, n, stopAtError = false) ->
    l = actions.length
    if n > l then n = l
    if l > 0
        new Action (cb) ->
            countUp = n
            countDown = l
            resultArray = new Array(l)
            fireByIndex = (index) -> (data) ->
                countDown--
                if data instanceof Error and stopAtError
                    cb?(data)
                    cb = undefined
                    countDown = -1
                else if countDown >= 0
                    resultArray[index] = data
                    if countDown == 0 then cb resultArray
                    else if countUp < l
                        # add new job
                        actions[countUp]._go fireByIndex(countUp)
                        countUp++

            handlerArray = new Array(n)
            for i in [0..n-1]
                handlerArray[i] = actions[i]._go fireByIndex(i)
            handlerArray
    else Action.wrap []

# run an Array of Actions in parallel, return an Action wraps results in an Array
Action.parallel = (actions, stopAtError) ->
    Action.throttle actions, actions.length, stopAtError

# run an Array of Actions in sequence, return an Action wraps results in an Array
Action.sequence = (actions, stopAtError) ->
    Action.throttle actions, 1, stopAtError

# join two Actions together
Action.join = (action1, action2, cb2, stopAtError = false) ->
    new Action (cb) ->
        result1 = result2 = undefined
        countDown = 2
        [
            action1._go (data) ->
                result1 = data
                if (result1 instanceof Error) and stopAtError
                    countDown = -1
                    cb result1
                else
                    countDown--
                    if countDown == 0 then fireByResult(cb, (cb2 result1, result2))

            action2._go (data) ->
                result2 = data
                if (result2 instanceof Error) and stopAtError
                    countDown = -1
                    cb result2
                else
                    countDown--
                    if countDown == 0 then fireByResult(cb, (cb2 result1, result2))
        ]

# run an Array of Actions in parallel, return an Action wraps first result
Action.race = (actions, stopAtError = false) ->
    l = actions.length
    if l > 0
        new Action (cb) ->
            countDown = l
            handlerArray = new Array(l)
            for action, i in actions
                handlerArray[i] = action._go (data) ->
                    countDown--
                    if (data not instanceof Error) or stopAtError
                        cb?(data)
                        cb = undefined
                        countDown = -1
                    else if countDown == 0
                        cb new Error 'RACE_ERROR: All actions failed'
            handlerArray
    else Action.wrap new Error 'RACE_ERROR: All actions failed'

# Helpers for makeNodeAction
makeNodeCb = (cb) -> (err, data) -> cb if err then err else data

# make an Action from a node style function
Action.makeNodeAction = (nodeAPI) -> (a,b,c) ->
    self = @
    l = arguments.length
    switch l
        # from bluebird, these make function call faster
        when 0 then _go = (cb) -> nodeAPI.call(self,makeNodeCb(cb))
        when 1 then _go = (cb) -> nodeAPI.call(self,a,makeNodeCb(cb))
        when 2 then _go = (cb) -> nodeAPI.call(self,a,b,makeNodeCb(cb))
        when 3 then _go = (cb) -> nodeAPI.call(self,a,b,c,makeNodeCb(cb))
        else
            i = l
            args = new Array(l+1)
            while i-- > 0
                args[i] = arguments[i]
            _go = (cb) ->
                args[l] = makeNodeCb cb
                nodeAPI.apply self, args
    new Action _go

# Helpers for Action.co
spawn = (gen, action, cb) ->
    action._go (v) ->
        if v instanceof Error then gen.throw v
        {value: nextAction, done: done} = gen.next(v)
        if done then cb v else spawn(gen, nextAction, cb)

# use generator's yeild to wait on Actions
Action.co = (genFn) -> () ->
    gen = genFn.apply this, arguments
    new Action (cb) ->
        spawn gen, gen.next().value, cb

if module? and module.exports?
    module.exports = Action
else if (typeof define == "function" and define.amd)
    define -> Action
else if window?
    window.Action = Action
