# helper functions
# ignore params
ignore = ->

# Main class
class Action
    # save an action to feed callback later
    constructor: (@_go) ->

    # return a new Action that when fire, it will call current action first, then the callback
    _next: (cb) ->
        _go = @_go
        new Action (_cb) ->
            _go (data) ->
                _data = cb(data)
                # if a cb return an Action
                if _data instanceof Action
                    _data._go _cb
                else _cb _data

    # return a new Action that when fire, it will call current action first, then the callback
    # if current action want to pass an error to the callback, stop it and pass it on
    next: (cb) ->
        _go = @_go
        new Action (_cb) ->
            _go (data) ->
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
        _go = @_go
        new Action (_cb) ->
            _go (data) ->
                if data instanceof Error
                    _data = cb data
                    if _data instanceof Action
                        _data._go _cb
                    else
                        _cb _data

                else _cb data

    # fire the callback chain with given callback(or ignore), any unhandled error will be thrown
    go: (cb) ->
        @_go (data) ->
            if data instanceof Error
                throw data
            else if cb? then cb data

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
            callbacks = undefined
    new Action (cb) ->
        if pending then callbacks.push cb
        else cb data

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

# retry an Action n times if it failed
Action.gapRetry = (times, delay, action) ->
    a = (Action.delay delay, action).guard (e) ->
        if times-- != 0 then a
        else new Error 'RETRY_ERROR: Retry limit reached'

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
            cb new Error 'RACE_ERROR: All actions failed'
        else for action in actions
            action._go (data) ->
                countDown--
                if (data not instanceof Error) or stopAtError
                    cb data
                    cb = ignore
                    countDown = -1
                else if countDown == 0
                    cb new Error 'RACE_ERROR: All actions failed'

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
Action.makeNodeAction = (nodeAPI) -> (args...) ->
    self = @
    new Action (cb) ->
        args.push (err, data) ->
            cb if err then err else data
        nodeAPI.apply self, args

# recursively build query string
makeQueryStrR = (prefix , data) ->
    result = []
    for k, v of data
        key = if prefix then prefix + '[' + k + ']' else k
        if (typeof v) == 'object'
            result.push makeQueryStrR(key, v)
        else if v?
            result.push encodeURIComponent(key) + "=" + encodeURIComponent(v)
    result.join '&'

# build query string
Action.param = (data) -> makeQueryStrR('', data)

# make a jsonp request
Action.jsonp = (opts) ->
    new Action (cb) ->
        callbackName = 'callback_' + (Math.round(Math.random() * 1e16)).toString(36)
        script = document.createElement 'script'

        window[callbackName] = (resp) ->
            script.parentNode.removeChild script
            cb resp
            window[callbackName] = undefined

        script.onerror = ->
            script.parentNode.removeChild script
            cb new Error 'REQUEST_ERROR: error when making jsonp request'
            window[callbackName] = undefined
            false

        script.onload = -> false

        script.src = opts.url + (if opts.url.indexOf('?') == -1 then '?' else '&') +
            (if opts.callback then opts.callback else 'callback') +
            '=' + callbackName

        document.body.appendChild script
        script

# make a ajax request
Action.ajax = (opts) ->
    new Action (cb) ->
        xhr = new (window.XMLHttpRequest)
        xhr.open opts.method, opts.url, true, opts.user, opts.password
        xhr.onload = ->
            if xhr.readyState == 4
                if xhr.status >= 200 and xhr.status < 300
                    if opts.responseType? then cb xhr.response
                    else cb xhr.responseText
                else
                    cb new Error 'REQUEST_ERROR: status' + xhr.status

        for k, v of opts.headers
            xhr.setRequestHeader k, v

        if opts.timeout
            xhr.timeout = opts.timeout
            xhr.ontimeout = ->
                cb new Error 'REQUEST_ERROR: timeout'

        if opts.responseType
            xhr.responseType = opts.responseType

        switch typeof opts.data
            when 'string'
                xhr.setRequestHeader 'Content-Type', 'application/x-www-form-urlencoded'
                xhr.send opts.data

            when 'object'
                if opts.data instanceof window.FormData
                    xhr.send opts.data
                else
                    xhr.setRequestHeader 'Content-Type', 'application/json; charset=UTF-8'
                    xhr.send JSON.stringify opts.data

            else
                xhr.send()
        xhr

if module? and  module.exports?
    module.exports = Action
else if (typeof define == "function" and define.amd)
    define -> Action
else if window?
    window.Action = Action
