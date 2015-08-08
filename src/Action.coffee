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

Action.safe = (fn) -> (data) ->
    try fn(data) catch e then e

Action.sequence = (monadicActions) -> (init) ->
    if monadicActions.length > 0
        a = monadicActions[0](init)
        for monadicAction in monadicActions[1..]
            a = a.next monadicAction
        a
    else throw new Error 'No monadic actions given'


Action.any = (monadicActions) -> (args)->
    if args.length == monadicActions.length
        new Action (cb) ->
            for monadicAction, index in monadicActions
                monadicAction(args[index])
                ._go (data) ->
                    cb data
                    cb = doNothing
    else throw new Error 'Check your arguments for monadic actions'

Action.anySuccess = (monadicActions) -> (args)->
    if (countDown = args.length) == monadicActions.length
        new Action (cb) ->
            for monadicAction, index in monadicActions
                monadicAction(args[index])
                ._go (data) ->
                    countDown--
                    if data not instanceof Error
                        cb data
                        cb = doNothing
                        countDown = -1
                    else if countDown == 0
                        cb new Error 'All actions failed'
    else throw new Error 'Check your arguments for monadic actions'

module.exports = Action
