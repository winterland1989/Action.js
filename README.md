# Action.js

A sane way to chain asynchronous actions.

# Motivation

Cont monad in haskell lacks a javascript version, so i decide to make one.

# Examples

new Action (cb) ->
    setTimeout (() -> cb 'foo'), 1000
.next (data) ->
    data + 'bar'
.next (data) ->
    new Action (cb) ->
        setTimeout (() -> cb(new Error 'wtf')), 100

.next (data) ->
    data + 'ok'

.guard (e) ->
    console.log e
    'error handled'
.go (data) -> console.log data + '!'

# difference from a promise

+ The action is lazily called, so if you need call go when you want to fire an action.

+ All error need catch explicitly, e.g.

```coffeescript
.next (data) ->
    try
        launchTheMissle(...)
    catch e then e
```

Yes, when error happened, you return it, so that following action wont fire and a guard after it can handle.

+ You can now store the action and fire them multiple times.
```coffeescript
a = Action (cb) ->
    readFile ('whatever', (data) -> cb data)

a.go (data) ->
    ...

# later
a.go (data) ->
    ...
```

