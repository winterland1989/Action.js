Action.js, a fast, small, full feature async library
====================================================
    
+ [FAQ](#FAQ)
+ [Changelog](#Changelog)
+ [Benchmark](https://github.com/winterland1989/Action.js/wiki/Benchmark)
+ [API document](https://github.com/winterland1989/Action.js/wiki/API-document)
+ Usage: 
    + `npm i action-js` and `var Action = require('action-js')`.
    + Clone this repo and use `Action.js` and `ajaxHelper.js` with AMD or CMD loader, bundler.
    + Add a script tag and use `window.Action`.

+ Highlights:
    + [Blazing fast](https://github.com/winterland1989/Action.js/wiki/Benchmark) and extremly small(4.2k/minified 1.4k/gzipped)
    + Full feature APIs like `retry`, `parallel`, `race`, `throttle` and more.
    + [Cancellable](https://github.com/winterland1989/Action.js/wiki/Return-value-of-go) and [retriable](https://github.com/winterland1989/Action.js/wiki/Difference-from-Promise) semantics.
    + `Action.co` to work with generator functions.
    + [Signal and pump](https://github.com/winterland1989/Action.js/wiki/Signal-And-Pump) provides easy and composable async UI management(form validation...).

+ Eco-system:
    + [ajax-action](https://github.com/winterland1989/ajax-action)

What is `Action`
----------------

Interested? `Action` is a fast and clean alternative to both `Promise`(and `Observable` if you'd like to), it's intended to solve what `Promise` can't solve:

+ Can't run async actions without reallocate new instances, see [lazy promise](https://github.com/petkaantonov/bluebird/issues/812), [throttling](https://github.com/petkaantonov/bluebird/issues/570).

+ Sliently eat errors, see [Unhandled Rejection](https://github.com/nodejs/node/issues/830), and [related hack](https://github.com/nodejs/node/issues/5084).

Besides all the benifits, `Action` run at blazing fast speed with simpler and smaller code. A simple example:

```js
var Action = require('action-js');
new Action(function(cb){
    readFile('fileA', function(err, data){
        if (err){
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
.next(function(data){
    // This process will be skip if previous steps pass an Error
    return anotherProcess(data);
})
.guard(function(e){
    // This process will be skip if there's no Errors
    return processError(e);
});
.go(function(data){console.log data});
```

It looks like `Promise` with some differences:

+ Add a `go` call when you want to fire an `Action`, and you can fire multiple times, which means `Action`'s lazily executed, so you can do retry/throttle...

+ If you come across an `Error`, just pass it down like normal values, see `safe/safeRaw` in next chapter.

+ `next` only pass none `Error` value to its callback, and `guard` only call its callback if upstream pass `Error` down, if you'd like to handled `Error` and normal value inside one callback, use `_next`. 

+ `Error` will never be swallowed, and now you can use `throw` to break your program if you really want to.

You can also use `makeNodeAction` to replace `promisify` in other promise library, let's get into the core since now you must have a lot of questions.

How does `Action` works
-----------------------

`Action`'s core is an extremly simple javascript class(to mimic haskell's `newtype`):

```js
var Action = function(go) {
    this._go = go;
}
```

We construct an `Action` by passing a function which consume a callback(aka. contination), take `fs.readFile` as an example:

```js
// suppose this readFile never fail
// we will talk error handleing later
var readFileAction = new Action(function(cb){
    fs.readFile('data.txt', function(err, data){
        cb(data);
    })
});
```

Now if we provide a callback to `readFileAction._go`:

```js
readFileAction._go(function(err, data){
    console.log(data);
})
```

The callback chain will be fired, it's equivalent to following code:

```js
readFile("data.txt", function(data){
    console.log(data);
});
```

With one difference, `Action` seperate contination creation(wrap `readFile` in `new Action`) and application(supply a callback to `_go`), that's the core idea of `Action`, **an Action always wrap a contination inside**. 

Now we can add a method to compose another callback with this contination:

```js
Action.prototype._next = function(cb) {
    var self = this;
    return new Action(function(_cb) {
        return self._go(function(data) {
            var _data = cb(data); // this cb is what we pass to next
            return _cb(_data); // this _cb has not been passed yet!
        });
    });
};
```

Let's break down `_next` a little here:

+ `_next` accept a callback `cb`, and return a new `Action`.

+ When the new `Action` fired with `_cb`, the original `Action`'s action will be fired first, and send the value to `cb`, then send the `_data` produced by `cb(data)` to `_cb`.

+ The order is (original `Action`'s `_go`) --> (`cb` which `_next` received) --> (`_cb` we give to our new `Action`).

+ Since we haven't fired our new `Action` yet, we haven't got the `_cb`, the whole contination is saved in our new `Action`.

With our `_next`, we can chain multiply callbacks, note how data flows between them:

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

Each `_next` return a new `Action`, if we give the final `Action` a callback with `_go`, the whole callback chain will be fired sequential.

Nice, we just use a very simple class, one very simple functions, the callbacks are written in a much more readable way now, but we have a key problem to be solved yet: what if we want to nest async `Action` inside an `Action`? Turn out with a little modification to our `_next` function, we can handle that:

```js
Action.prototype._next = function(cb) {
    var self = this;
    return new Action(function(_cb) {
        return self._go(function(data) {
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

This's the core of composable contination, We use `instanceof Action` to check if `cb` returns an `Action` or not, if an `Action` is returned, we fire it with `_cb`, the callback which our new `Action` will going to receive:

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

Now we have solved the callback hell problem! Well, actually just 50% of it.
Before we proceed another 50%, one important thing to keep in mind: **an `Action` is not a `Promise`, it will not happen if you don't pass a callback to `_go`, and it can be fired multiple times, it's just a reference to a wrapped contination**:

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

+ You lost the ability to break your program by throwing, sometime you do need it.

What we can do to make it simpler? It's a complex problem, we start solving it by simplify it: **Action.js use `Error` type as a special type to pass error information to the downstream**, what does this mean?

```js
Action.prototype.next = function(cb) {
    var self = this;
    return new Action(function(_cb) {
        return self._go(function(data) {
            if (data instanceof Error) {
                return _cb(data); // we directly skip cb here
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

Let me present the final version of our `next` function, comparing to `_next` we write before:

+ It still reture a new `Action`, when it fired, the original action are called.

+ We checked if the `data` coming from upstream is `instanceof Error`, if it's not, everything as usual, we feed it to `cb` that `next` received. But if it's an `Error`, we skip `cb`, pass it directly to `_cb`.

`next` ensure the `cb` it received, **will never receive an `Error`**, we just skip `cb` and pass `Error` downstream, symmetrically, we define a function which only deal with `Error`, and let normal values pass:

```js
Action.prototype.guard = function(cb) {
    var self = this;
    return new Action(function(_cb) {
        return self._go(function(data) {
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

This time, the `cb` that `guard` received are prepared for `Error` values, so we flip the logic, you can also return an `Action` if your need some async code to deal with the `Error`. Actually `guard` can receive an extra parameter before `cb` to filter what kind of `Error` `cb` can deal with, check out [source code](https://github.com/winterland1989/Action.js/blob/master/Action.coffee#L27)/[api doc](https://github.com/winterland1989/Action.js/wiki/API-document#actionprototypeguardcb--error---b).

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
.guard('ENOENT', function(e){
    // This process will be called only when Error's message begin with 'ENOENT'
    return processENOENT(e);
});
.guard(function(e){
    // This process will be skip if there's no Errors
    return processError(e);
})
._go(console.log);

```

The final result will be produced by `anotherProcess` if `someProcessMayWentWrong` didn't go wrong and `readFile` didn't fail, otherwise it will be produced by `processError`.

You can place `guard` in the middle of the chain, all `Errors` before it will be handled by it, and the value it produced, sync or async, will be passed down to the rest of the chain.

What if we don't supply a `guard`? Since we have to supply a callback to `_go`, we can check if the final result is an `Error` or not like this:

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

Yeah, it does work, and often you want it work in this way, but:

+ sometime we don't want to supply a `cb`.

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

Finally, to ease error management, and attack the [v8 optimization problems](https://github.com/petkaantonov/bluebird/wiki/Optimization-killers#2-unsupported-syntax). We recommand using `Action.safe`:

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

Use `safe` wrap your `someProcessMayWentWrong` like this:

```js
var safe = Action.safe;
new Action(function(cb){
    ...
})
.next(
    safe(new Error("PROCESS_ERROR_XXX: process xxx failed when xxx")
        , someProcessMayWentWrong)
)
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

That's all core functions of `Action`, but it's much more powerful than first look! make sure you read:

+ [Difference from Promise](https://github.com/winterland1989/Action.js/wiki/Difference-from-Promise) to get a deeper understanding.

+ [Return value of go](https://github.com/winterland1989/Action.js/wiki/Return-value-of-go) to learn how to cancel an `Action`.

+ [Signal and pump](https://github.com/winterland1989/Action.js/wiki/Signal-and-pump) to see how `Action` making async UI management easy.

+ [API doc](https://github.com/winterland1989/Action.js/wiki/API-document) for interesting things like `Action.parallel`, `Action.race`, `Action.throttle` and `Action.retry`.

+ [ajax-action](https://github.com/winterland1989/ajax-action) for front-end needs like `ajax`, `jsonp` and `parseParam/buildParam`.

FAQ<a name="FAQ"></a>
=====================

When to use this library?
-------------------------

With `Promise` added to ES6 and ES7 `async/await` proposal, one must ask, why another library to do the same things again?

Because `Action` is not `Promise`, It's a faster, simpler and full feature alternative comes with more flexible semantics. Actually `Action` have a [very elegant `Action.co` implementation](https://github.com/winterland1989/Action.js/blob/master/Action.coffee#L234) to work with generators, nevertheless, use this library if you:

+ Want something small, fast and memory effient in browser.

+ Want to manage complex async UI, read [Signal and pump](https://github.com/winterland1989/Action.js/wiki/Signal-and-pump) to get a modular solution to async UI management.

+ Want manage cancellable actions, read the [Return value of go](https://github.com/winterland1989/Action.js/wiki/Return-value-of-go) to get an elegant solution to cancellable actions.

+ Want a different sementics, with `Promise`, you just can't reuse your callback chain, you have to create a new `Promise`, with `Action`, just `go` again, never waste memory on GC. 

+ Want to control exactly when the action will run, with `Promise`, all action run in next tick, While with `Action`, action runs when you call `go`, `_go` or `Action.freeze`.

+ Want raw speed, this is somehow not really an issue, most of the time `Promise` or `Action` won't affect that much, nevertheless, `Action.js` can guarantee speed close to handroll callbacks in any runtime, just much cleaner.

If you have a FP background, you must find all i have done is porting the `Cont` monad from Haskell, and i believe you have divided your program into many composable functions already, just connect them with `next`.

The semantics of `Action` also fit varieties situations like animation and interactive UI, it's far more suitable than `Promise` in these situations.

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

Well, read [Difference from Promise](https://github.com/winterland1989/Action.js/wiki/Difference-from-Promise) and [Return value of go](https://github.com/winterland1989/Action.js/wiki/Return-value-of-go) to get a detailed answer, tl,dr... here is the short answer:

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

If you want have a `Promise` behavior(fire and memorize), use `Action.freeze`, `go` won't return a new `Action`, instead `go` return a cancel handler if underline action can be cancelled.

How can i send an `Error` to downstream's `next`
------------------------------------------------

No, you can't, however, you can receive `Error` from upstream use `_next`, `_go` or `guard`. or you can wrap the `Error` in an `Array` like `[e]`, it's a very rare situation one want to process a `Error` value like normal values.

The choice of using `Error` to skip `next` and hit `guard` is not arbitrary, instead of creating an `ActionError` class, use `Error` unify type with system runtime, and providing callstack information. And you can now break your program by throwing an Error if you really want to.

Changelog<a name="Changelog"></a>
=================================

V4.3.0
fix a nasty bug, failing an Action in `parallel/sequence/throttle..` with `stopAtError = true` should pass first `Error` down only once.

V4.2.2
Seperate ajax related stuff into seperate package, [ajax-action](https://github.com/winterland1989/ajax-action).

V4.2.0
`prototype.guard` now accpet an extra parameter(before cb) to guard Error based on their message (prefix). 

V4.1.1
Small `throttle` optimization.

V4.1.0
Add `throttle`, now `parallel` and `sequence` are implemented by `throttle`.

v3.1.0

1. Add `stopAtError` flag to `Action.join`.

2. Change `ajaxHelpers.buildParam` behavior when input contain arrays, now `foo: [1,2,3]` will output `foo=1&foo=2&foo=3`.

v3.0.0
Seperate ajax related stuff into `ajaxHelper.js`.

v2.4.2
Make `prototype.go` default to id function if no callback is provided.

v2.4.1
Fix a `Action.fuseSignal` bug.

v2.4.0
Add `Action.signal` and `Action.fuseSignal` to ease async UI management.

v2.3.0
Now when you construct an `Action`, the `this` variable inside the contination will be the `Action` instance.

v2.2.0
`Action.join`, `Action.parallel`, `Action.race` now return an `Array` of cancel handler when the composed `Action` fired, you can now cancel them with ease. 

v2.1.1
Fix a bug of `Action.parallel`, add test. 

v2.1.0
Change `Action.co` into more async-await style, you can use try-catch to catch `Error`s now.  

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

License
=======

The MIT License (MIT)

Copyright (c) 2016 Winterland

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
