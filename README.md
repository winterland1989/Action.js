Action.js
=========

A sane way to chain asynchronous actions inspired by cont monad in haskell. offer an alternative to state machine based promise.

Example
-------

```js
var safe = Action.safe;

var exampleAction = new Action(function(cb){
    readFile('fileA', function(err, data){
        if (err){
            cb(err);
        }else{
            cb(data);
        }
    });
})
.next(function(data){
    return processData(data);
})
.next(function(data){
    return new Action(function(cb){
        processDataAsync(data, cb);
    })
})
.next(safe(new Error('Something went wrong'), function(data){
    return someThingMayWentWrong(data);
}))
.next(function(data){
    // This process will be skip if previous step pass a Error
    return anotherProcess(data);
})
.guard(function(e){
    switch e.message
        case '...': ...
        ...

    return 'Error handled'
});

exampleAction.go(console.log)

...
// after fileA changed you can go again
exampleAction.go(console.log)

```
If you prefer read coffee:
```coffee
{safe} = Action

exampleAction = new Action (cb) ->
    readFile 'fileA', (err, data) ->
        cb if err then err else data
.next (data) ->
    processData data
.next (data) ->
    new Action (cb) ->
        processDataAsync data, cb
.next safe (new Error 'Something went wrong'), (data) ->
    someThingMayWentWrong data
.next (data) ->
    # This process will be skip if previous step pass a Error
    anotherProcess data
.guard (e) ->
    switch e.message
        when '...' then ...
        ...
    'Error handled'

exampleAction.go console.log

...
# after fileA changed you can go again
exampleAction.go console.log

```

Difference from a promise
-------------------------

Action has different semantics, inside it's not a state machine, but a function reference waiting for next continuation, so you can easily build an Action chain, the chain can be fired many times, rather than resolved once and waiting for consume, sometimes it's more suitable than a promise, and it's very easy if you want to memorize an Action's resolved value.

Another difference is that if you want to pass errors to downstream, you simply return them inside your continuation, following continuations won't run until the error reach a guard.

Check out the Document, it's really simple, and check the soure code if you feel interesting, it's less than 200 lines.

Usage
-----

It's simple and stable, just grab from git and use, dist/Action.js is intend to be used as a common js module, and dist/Action.min.js is used in browser(window.Action namespace will be used).

Document and tutorial
---------------------

First you construct an Action like you contruct a Promise, the differences are that an Action won't run immediately at next tick, and any errors should be passed to the callback argument, we will talk about errors later:

```js
var exampleAction = new Action(function(cb){
    readFile('fileA', function(err, data){
        if (err){
            cb(err);
        }else{
            cb(data);
        }
    });
});
```
```coffee
exampleAction = new Action (cb) ->
    readFile 'fileA', (err, data) ->
        cb if err then err else data
```

If you don't have any process going on, you can fire the action and get the data now:

```js
exampleAction
.go(function(data){
    console.log(data);
});
```
```coffee
exampleAction
.go (data) ->
    console.log data
```

Most of the time you want to process the data, you have to give an Action a continuation to do the next, a continuation is something like this:

    continuation :: data -> data | Action | Error

e.g. You process data inside continuation, return it, or return a new Action, or return an Error if error occurred. Examples:

```js
exampleAction
.next(function(data){
    return processData(data);
})
.next(function(data){
    return new Action(function(cb){
        processDataAsync(data, cb);
    })
})
.next(function(data){
    if(someThingMayWentWrong(data)){
        return new Error('Something went wrong');
    }
})
...
```
```coffee
exampleAction
.next (data) ->
    processData data
.next (data) ->
    new Action (cb) ->
        processDataAsync data, cb
.next (data) ->
    if someThingMayWentWrong data
        new Error 'Something went wrong'
...
```

Remember, you can't pass a continuation after you fire an Action. because action.go doesn't produce an Action.

```js
// this is wrong, and produce an error sort like 'next is undefined'
exampleAction
.go(function(data){
    finish(data);
})
.next(function(data){
    cantGetDataHere(data);
})
```
```coffee
# this is wrong, and produce an error sort like 'next is undefined'
exampleAction
.go (data) ->
    finish data
.next (data) ->
    cantGetDataHere data
```

But you can reuse the origin action if you want to fire it again.

```js
exampleAction.go(function(data){...});
// after some time, or inside another request handler, the data maybe different this time!
exampleAction.go(function(data){...});
```
```coffee
exampleAction.go (data) -> ...
# after some time, or inside another request handler, the data maybe different this time!
exampleAction.go (data) -> ...
```

There's a combinator that fire an Action actionA immediately and return a Action actionB, it's Action.freeze, during the pending stage all the continuation are saved, after actionA are resolved with valueA, pass continuation to actionB will resolved with valueA, you may find actionB is just a Promise in disguse, it's a memorized ActionA, resolved only once.

```js
// FileA will be read immediately, processA will pending
freezedFileA = Action.freeze(new Action(function(cb){
    readFile('FileA', function(err, data){
        if(err){
            cb(err);
        }else{
            cb(data);
        }
    });
})
freezedFileA
.next(function(data){
    processA(data)
})
.go()

// after some time, freezedFileA will resolve immediately with the just the same data when freezing.
freezedFileA
.next(function(data){
    processB(data)
})
.go()

```
```coffee
# FileA will be read immediately, processA will pending
freezedFileA = Action.freeze new Action (cb) ->
    readFile 'FileA', (err, data) ->
        cb if err then err else data

freezedFileA
.next (data) ->
    processA(data)
.go()

# after some time, freezedFileA will resolve immediately with the just the same data when freezing.
freezedFileA
.next (data) ->
    processB(data)
.go()
```

If Action resulted in error, Action.freeze will throw it, be sure to put a guard before it! Let's talk about errors, don't panic, once a continuation return a Error object, the following continuation won't fire, you can catch the error by putting a guard on the end. Of course guards have to be put before go.

```js
exampleAction
.guard(function(e){
    switch e.message
        case '...' : ...
        ...
})
.go()
```
```coffee
exampleAction
.guard (e) ->
    switch e.message
        when '...' ...
        ...
.go()
```

You can put guard between continuations, so that it can handle errors upstream and produce meaningful data to downstream, you can produce an Action inside guard too.

The guard pattern works great on node APIs, becasue they often don't throw error, but have an err flag, so you don't have to write try-catch, there's also a helper to make an Action from node style APIs.

```js
var mkNodeAction = Action.mkNodeAction;
exampleAction = mkNodeAction(readFile, 'fileA');
// this is equivalent to below
exampleAction = new Action(function(cb){
    readFile('fileA', function(err, data){
        if(err){
            cb(err); 
        }else{
            cb(data);
        }
    });
});
```
```coffee
{mkNodeAction} = Action
exampleAction = mkNodeAction readFile, 'fileA'
# this is equivalent to below
exampleAction = new Action (cb) ->
    readFile 'fileA', (err, data) ->
        cb if err then err else data
```

But some errors have to be caught explicitly, you can do something like this:

```js
exampleAction
.next(function(data){
    try{
        someDangerousThing(data);
    }
    catch(e){
        return e;
    }
}
```
```coffee
exampleAction
.next (data) ->
    try somedangerousthing data
    catch e then e
```

but this's boring, more importantly, it hurts the performance if you are not careful enough, because v8 doesn't optimize functions contain try-catch, so we use a combinator to get around it(minimize the function contain try-catch), and for sure, it's shorter!

```js
var safe = Action.safe
var safeRaw = Action.safeRaw
// this will catch the error during someThingMayWentWrong and return it
.next(safeRaw(function(data){
    someThingMayWentWrong(data);
}))
.next ...
// this will return a customized error when error happened.
.next(safe(new Error('Fire missile failed'), function(data){
    FireMissle(data);
}))
.next ...
```
```coffee
{safe, safeRaw} = Action
# this will catch the error during someThingMayWentWrong and return it
.next safeRaw (data) ->
    someThingMayWentWrong data
.next ...
# this will return a customized error when error happened.
.next safe (new Error 'Fire missile failed'), (data) ->
    FireMissle data
.next ...
```

It's a design choice that Action.js don't catch errors by default, it will make you pure code faster, and make your errors explicit, use safe instead of safeRaw is also highly recommended, MAKE YOUR ERRORS MORE MEANINGFUL!

The price is we can't catch your error instead of yourself and provide long-stack-trace, hopefully this design choice can help you write better error handling code rather than bite you.

Notice that if you don't guard errors before go, and error happened, then go will throw it, this behavior may make sense or not, there's another function to fire an Action but also can capture error, it's sort of:

    Action.prototype._go :: ( cb :: (Error | data) -> a ) -> b

```js
// use _go if you want to capture the error
exampleAction
._go(function(data){
    if(data instanceof Error){
        ...
    }
    else{
        ...
    }
});
// note, go may don't need a argument, following is ok:
exampleAction
.go()

// but _go must have one, following will produce a error:
exampleAction
._go()
```
```coffee
# use _go if you want to capture the error
exampleAction
._go (data) ->
    if data instanceof Error
        ...
    else
        ...
# note, go may don't need a argument, following is ok:
exampleAction
.go()

# but _go must have one, following will produce a error:
exampleAction
._go()
```

Generally, you may want to use \_go in a control structure library, just like following helpers, there's also Action.\_freeze, which just like \_go, it will not throw error when freezing failed, it silently passed the error to downstream.

Above is all the core stuff of Action.js, following are helpers to make your life easier (js/coffee document is W.I.P, here is source for amuse):

Action.wrap wrap a value in an Action, (a.k.a. return in a haskell monad), when this Action fire, the data will be passed on, the data can be an Error, in that case it will skip all nexts and hit first guard.

    Action.wrap :: a -> Action

```coffee
Action.wrap = (data) ->
    new Action (cb) -> cb data
```

Now let's introduce a concept first:

    monadicAction :: (data) -> Action

A monadicAction is simply a function that produce an Action, don't bother why it's called monadic if you don't want to know. it's just a type of function.

Action.sequence combine an array of monadicActions, and produce a new monadicAction, once this monadicAction get the init data, it will run the all the monadicActions in the array sequential, the data produce by fire first monadicAction will be passed to the second, and so on util all monadicAction are fired.

    Action.sequence :: ([monadicAction]) -> monadicAction

```coffee
Action.sequence = (monadicActions) -> (init) ->
    if monadicActions.length > 0
        a = monadicActions[0](init)
        for monadicAction in monadicActions[1..]
            a = a.next monadicAction
        a
    else Action.wrap new Error 'No monadic actions given'
```

Action.any combine an array of Actions and return a new Action finalA, first we fire all of the Actions, as soon as one of the Actions finished, finalA starts to call its continuation. and rest of the Actions are ignored.

    Action.any :: ([Action]) -> Action

```coffee
Action.any = (actions) ->
    new Action (cb) ->
        for action in actions
            action._go (data) ->
                cb data
                cb = ignore
```

Action.anySuccess is similar to Action.any, but we don't stop when the Actions finished with an Error, we continue to look for the first successful action, if all Actions failed, Action.anySuccess pass an Error 'All actions failed' to following continuations.

    Action.anySuccess :: ([Action]) -> Action

```coffee
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
```

Like Action.any and Action.anySuccess, we have Action.all and Action.allSuccess, the all-functions run all actions and return an Action that need a continuation consuming array, e.g. all the actions' result are passed to down stream as an array, the Action.all will pass the first error if error happend, while Action.allSuccess put all the errors and successful results in the array.

    Action.all :: ([Action]) -> Action
    Action.allSuccess :: ([Action]) -> Action

```coffee
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
```

Action.retry take a number as retry limit, and an Action to retry, it's simple, but one thing to note: the number is retry limit, not the total try number, so if you pass 1, the action will retry once after first fail, that's totally two times. you can pass -1 to try forever util an action successfully finish.

    Action.retry :: (times::Int, Action) -> Action

```coffee
Action.retry = (times, action) ->
    a = action.guard (e) ->
        if times-- != 0 then a
        else new Error 'Retry limit reached'
    a
```

Action.gapRetry will take an extra parameter as interval(in ms) between two retrys, like Action.retry, retry action will pass error 'Retry limit reached' if no action finished successfully:

    Action.retry :: (times::Int, interval::Int, Action) -> Action

```coffee
Action.gapRetry = (times, interval, action) ->
    a = action.guard (e) ->
        new Action (cb) ->
            setTimeout cb, interval
        .next ->
            if times-- != 0 then a
            else new Error 'Retry limit reached'
    a
```

Sometimes, you want to try different input sequential not parallel, you can use Action.sequenceTry, it will pass different input to monadicAction to produce the action to try, and try them in order, like Action.trySuccess, sequenceTry will try to find the first successful action, if all try failed, a 'Try limit reached' error will be passed on:

    Action.sequenceTry :: ([inputs], monadicAction) -> Action

```coffee
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
```

That's all, if you think some other interesting combinators should be here, or find a bug, pull requests are welcome. 
