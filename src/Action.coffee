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
                    if _data?
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

module.exports = Action
