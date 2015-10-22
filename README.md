Action.js, a sane way to write async code
=========================================
    
+ [FAQ](#FAQ)
+ [Changelog](#Changelog)
+ [Benchmark](https://github.com/winterland1989/Action.js/wiki/Benchmark)
+ [API document](https://github.com/winterland1989/Action.js/wiki/API-document)
+ Usage: 
    + `npm i action-js` and `var Action = require('action-js')`.
    + `git clone https://github.com/winterland1989/Action.js.git` and `var Action = require('Action.js')`.
    + Add a script tag and use `window.Action`.

+ Highlights:
    + [Faster](https://github.com/winterland1989/Action.js/wiki/Benchmark) and simpler(~1kB minified gzipped)
    + Full control capability with `retry`, `parallel`, `race`, `sequence` and more.
    + [Cancellable](https://github.com/winterland1989/Action.js/wiki/Return-value-of-go) and [retriable](https://github.com/winterland1989/Action.js/wiki/Difference-from-Promise) semantics.
    + Bundled with `ajax`, `jsonp` for front-end usage.

Understand Action.js
--------------------

Suppose we want to solve the nest callback problem form scratch, there's an async function called `readFile`, and we want to use it to read `data.txt`, we have to supply a `callback` to it:

```js
// suppose this simple readFile never fail
readFile("data.txt", function(data){
    console.log(data);
});
```

Instead we don't give a callback(the `console.log`) to it right now, we save this read action in a new `Action`:

```js
var Action = function(go) {
    this._go = go;
}

var readFileAction = new Action(
    function(cb){
        readFile("data.txt", cb);
    }
);
```

Ok, now we must have a way to extract the action from our `readFileAction`, let's using `readFileAction._go` directly:

```js
readFileAction._go(function(data){
    console.log(data);
})
```

What above does is equivalent to what we write at beginning, right?:

```js
readFile("data.txt", function(data){
    console.log(data);
});
```

Just with one difference, we seperate action creation(wrap `readFile` in `new Action`) and application(supply a callback to `_go`), Now we want to chain more callbacks in Promise `then` style:

```js
Action.prototype._next = function(cb) {
    var _go = this._go;
    return new Action(function(_cb) {
        return _go(function(data) {
            var _data = cb(data);
            return _cb(_data);
        });
    });
};
```

Let's break down `_next` a little here:

+ `_next` accept a callback `cb`, and return a new `Action`.

+ When the new `Action` fired with `_cb`, the original `Action`'s action will be fired first, and send the value to `cb`.

+ We apply `cb` with `data` from the original `Action`

+ Then we send the `_data` produced by `cb(data)` to `_cb`.

+ The order is (original `Action`'s `_go`) --> (`cb` which `_next` received) --> (`_cb` we give to our new `Action`).

+ Since we haven't fired our new `Action` yet, we haven't send the `_cb`, the whole callback chain is saved in our new `Action`.

With our `_next`, we can chain multiply callbacks and pass data between them:

```js
readFileAction
._next(function(data){
    return data.length;
})
._next(function(data){
    // data here is the length we obtain last step
    console.log(data);
    return length > 0
})
._go(function(data){
    // data here is a Boolean
    if(data){
        ...
    }
})
```

Each `_next` return a new `Action`, Now if we give the final `Action` a callback with `_go`, the whole callback chain will be fired sequential.

Nice, we just use a simple class with only one field, one very simple functions, the callbacks are written in a much more readable way now, but we have a key problem to be solved yet: what if we want to nest async `Action` inside an `Action`? Turn out with a little modification to our `_next` function, we can handle that:

```js
Action.prototype._next = function(cb) {
    var _go = this._go;
    return new Action(function(_cb) {
        return _go(function(data) {
            var _data = cb(data);
            if (_data instanceof Action) {
                return _data._go(_cb);
            } else {
                return _cb(_data);
            }
        });
    });
};
```

We use `instanceof Action` to check if `cb` returns an `Action` or not, if an `Action` is returned, we fire it with `_cb`, the callback which our new `Action` will going to receive:

```js
readFileAction
._next(function(data){
    var newFile = parse(data);
    return new Action(function(cb){
        readFile(newFile, cb);
    });
})
._go(function(data){
    // data here is the newFile's content
    console.log(data)
})
```

Now we can say we have solved the callback hell problem! Well, actually just 50% of it.
Before we proceed another 50%, one important thing to keep in mind: **an `Action` is not a `Promise`, it will not happen if you don't fire it with `_go`, and it can be fired multiple times, it's just a reference to a wrapped function**:

```js
readFileAction
._next(processOne)
._go(console.log)

// after we do other things, or inside another request handler
...

// processTwo may receive different data since the file may change!
readFileAction
._next(processTwo)
._go(console.log)
```

I'll present `Action.freeze` in [Difference from Promise](https://github.com/winterland1989/Action.js/wiki/Difference-from-Promise) to give you `Promise` behavior when you need it, now let's attack another 50% of the callback hell issue.

Error handling
--------------

One biggest issue with `Promise` is that error handleing is somewhat magic and complex:

+ It will eat your error sliently if you don't supply a `catch` at the end of the chain.

+ You have to use two different functions, `resolve` to pass value to the callbacks and `reject` to skip them, what will happen if you `throw` an `Error`, well, just the same as `reject`.

What we can do to make it simpler? It's a complex problem, we start solving it by simplify it: **Action.js use `Error` type as a special type to pass error information to the downstream**, what does this mean?

```js
Action.prototype.next = function(cb) {
    var _go = this._go;
    return new Action(function(_cb) {
        return _go(function(data) {
            if (data instanceof Error) {
                return _cb(data);
            } else {
                var _data = cb(data);
                if (_data instanceof Action) {
                    return _data._go(_cb);
                } else {
                    return _cb(_data);
                }
            }
        });
    });
};
```

Here, let me present the final version of our `next` function, comparing to `_next` we write before, can you see what's the different? 

+ It still reture a new `Action`, when it fired, the original action are called.

+ We checked if the `data` coming from upstream is `instanceof Error`, if it's not, everything as usual, we feed it to `cb` that `next` received.

+ But if it's an `Error`, we skip `cb`, pass it to a future `_cb`, which we don't have now.

`next` ensure the `cb` it received, **will never receive an `Error`**, we just skip `cb` and pass `Error` downstream, Symmetrically, we define a function which only deal with `Error`, and let normal values pass:

```js
Action.prototype.guard = function(cb) {
    var _go = this._go;
    return new Action(function(_cb) {
        return _go(function(data) {
           if (data instanceof Error) {
            var _data = cb(data);
                if (_data instanceof Action) {
                    return _data._go(_cb);
                } else {
                    return _cb(_data);
                }
            } else {
                return _cb(data);
            }
        });
    });
};
```

This time, we know the `cb` that `guard` received are prepared for `Error` values, so we flip the logic, you can also return an `Action` if your need some async code to deal with the `Error`.

Following code demonstrate how to use our `next` and `guard`:

```js
new Action(function(cb){
    readFile('fileA', function(err, data){
        if (err){
            // see how to pass an Error to downstream
            // not reject, not throw, just pass it on, let it go
            cb(err);
        }else{
            cb(data);
        }
    });
})
.next(function(data){
    // sync process
    return processData(data);
})
.next(function(data){
    // async process
    return new Action(function(cb){
        processDataAsync(data, cb);
    })
})
.next(
    try{
        return someProcessMayWentWrong(data);
    }catch(e){
        // same as above, we return the error to pass it on
        return e;
    }
}))
.next(function(data){
    // This process will be skip if previous steps pass an Error
    return anotherProcess(data);
})
.guard(function(e){
    // This process will be skip if there's no Errors
    return processError(e);
});
._go(console.log);

```

The final result will be produced by `anotherProcess` if `someProcessMayWentWrong` didn't go wrong and `readFile` didn't fail, otherwise it will be produced by `processError`.

You can place `guard` in the middle of the chain, all `Errors` before it will be handled by it, and the value it produced, sync or async, will be passed to the rest of the chain.

So, what if we don't supply a `guard`? Since we have to supply a callback to `_go`, we can check if the final result is an `Error` or not like this:

```js
apiReturnAction('...')._go(function(data){
    if (data instanceof Error){
        //handle error here
        ...
    } else {
        // process data here
        ...
    }
});

```

Yeah, it does work(and sometimes you want it work in this way), but:

+ we don't want to force our user to supply a `cb` like above.

+ we should throw `Error` in case user didn't `guard` them.

So here let me present the final version of `go`:

```js
Action.prototype.go = function(cb) {
    return this._go(function(data) {
        if (data instanceof Error) {
            throw data;
        } else if (cb != null) {
            return cb(data);
        }
    });
};

```

Now user can omit the callback, and if user don't guard `Error`s, we will yell at them when `Error` occurs!

```js
new Action(function(cb){
    readFile('fileA', function(err, data){
        if (err){
            // suppose we got an Error here
            cb(err);
        }else{

            cb(data);
        }
    });
})
.go() // The Error will be thrown!

```

Finally, to ease error management, and to attack the [v8 optimization problems](https://github.com/petkaantonov/bluebird/wiki/Optimization-killers#2-unsupported-syntax). We recommand using `Action.safe`:

```js
// this small function minimize v8 try-catch overhead
// and make attaching custom Error easy
Action.safe = function(err, fn) {
    return function(data) {
        try {
            return fn(data);
        } catch (_error) {
            return err;
        }
    };
};
```

And use `safe` wrap your `someProcessMayWentWrong` like this:

```js
var safe = Action.safe;
new Action(function(cb){
    readFile('fileA', function(err, data){
        if (err){
            cb(err);
        }else{
            cb(data);
        }
    });
})
.next(
    safe( new Error("PROCESS_ERROR_XXX: process xxx failed when xxx")
        , someProcessMayWentWrong)
)
.next(...)
.next(...)
.guard(function(e){
    if (e.message.indexOf('ENOENT') === 0){
        ...
    }
    if (e.message.indexOf('PROCESS_ERROR_XXX') === 0 ){
        ...
    }
})
.go()

```

That's all core functions of `Action` is going to give you, thank you for reading, how long does it take you? hope you enjoy my solution :)

+ Check [API doc](https://github.com/winterland1989/Action.js/wiki/API-document) for interesting things like `Action.parallel`, `Action.race`, `Action.sequence` and `Action.retry`.

+ Read [Return value of go](https://github.com/winterland1989/Action.js/wiki/Return-value-of-go) to learn how to cancel an `Action`.

+ Read [Difference from Promise](https://github.com/winterland1989/Action.js/wiki/Difference-from-Promise) to get a deeper understanding.


FAQ<a name="FAQ"></a>
=====================

What makes `Action` fast?
-------------------------

Check out [Benchmark](https://github.com/winterland1989/Action.js/wiki/Benchmark), even use bluebird's benchmark suit, which heavily depend on library's [promisify](https://github.com/petkaantonov/bluebird/blob/master/src/promisify.js#L124) implementation, `Action` can match bluebird's performance.

Generally speaking, `Action` simply does less work:

+ It doesn't maintain any internal state.

+ It just have a single field, which is a reference to a function.

+ It just add a redirect call to original callback, and some type checking.

Why following code doesn't work?
--------------------------------

```js
var fileA = readFileAction
.go(processOne)

// Error, fileA is not an Action anymore
fileA
.next(processTwo)
.go()
```

Well, read [Difference from Promise](https://github.com/winterland1989/Action.js/wiki/Difference-from-Promise) to get a detailed answer, tl,dr... here is the short answer:

```js
// readFile now and return a Action, this function won't block
var fileA = Action.freeze(readFileAction.next(processOne))

// now fileA will always have the same content
// and file will never be read again.
fileA
.next(processTwo)
.go()

// processTwo will receive the same content
fileA
.next(processTwo)
.go()
```

If you want have a `Promise` behavior(fire and memorize), use `Action.freeze`, `go` won't return a new `Action`.

When to use this library?
-------------------------

With `Promise` added to ES6 and ES7 `async/await` proposal, one must ask, why another library to do the same things again?

Actually `Action` have a [very elegant `Action.co` implementation](https://github.com/winterland1989/Action.js/blob/master/Action.coffee#L205) to work with generators, nevertheless, use this library if you:

+ Want something small, fast and memory effient in browser, Action.js even have `ajax/jsonp` bundled.

+ Want manage cancelable actions, read the [Return value of go](https://github.com/winterland1989/Action.js/wiki/Return-value-of-go) to get a elegant solution to cancelable actions.

+ Want a different sementics, with `Promise`, you just can't reuse your callback chain, you have to create a new `Promise`, with `Action`, just `go` again, never waste memory on GC. 

+ Want to control exactly when the action will run, with `Promise`, all action run in next tick, While with `Action`, action runs when you call `go`, `_go` or `Action.freeze`. 

+ Want raw speed, this is somehow not really an issue, most of the time, `Promise` or `Action` won't affect that much, and on node we have heavily v8-optimized bluebird, nevertheless, `Action.js` can guarantee speed close to handroll callbacks in any runtime, just much cleaner.

If you have a FP background, you must find all i have done is porting the `Cont` monad from Haskell, and i believe you have divided your program into many composable functions already, just connect them with `next`.

How can i send an `Error` to downstream's `next`
------------------------------------------------

No, you can't, however, you can receive `Error` from upstream use `_next`, `_go` or `guard`. or you can wrap the `Error` in an `Array` like `[e]`.

The choice of using `Error` to skip `next` and hit `guard` is not arbitrary, instead of creating an `ActionError` class, use `Error` unify type with system runtime, and providing callstack information. And you can now break your program by throwing an Error if you really want to.

Changelog<a name="Changelog"></a>
================================

v2.0.0
Update doc, Remove `gapRetry`, since it's just a `retry` compose `delay`. 

v1.4.1
Run bluebird benchmark, add some optimization.

v1.4.0
Add Action.co, fix Action.join typos, test cover 100% agian.

v1.3.0
Add Action.join, optimized internal

v1.2.4
Improve makeNodeAction

v1.2.3
Fix responseType related.

v1.2.2
Auto add header based on data type.

v1.2.1
Clear some error types.

v1.2.0
add `param`, `jsonp` and `ajax` for front-end usage.

