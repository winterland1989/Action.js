Action.js, a sane way to write async code
=========================================

Promise and async/await are all great stuff, but Action.js offer an alternative faster and more concise.

Understand Action.js in 3 minutes
---------------------------------

Let's solve the callback hell proble form scratch, suppose we have a lovely function called `readFile`, and we want to read `data.txt`

    readFile("data.txt", callback)

We want compose different actions with this reading action, so we don't want to give a callback to it now, instead we save this action in a new `Action`:

```js
var Action = function Action(action1) {
    this.action = action1;
}

var readFileAction = new Action(
    function(cb){
        readFile("data.txt", cb);
    }
);
```
Ok, now we must have a method to extract the action from our `readFileAction`, instead use `readFileAction.action` directly, we write a function to accpet a callback, and pass this callback to the action inside our `readFileAction`:
```js
Action.prototype._go = function(cb) {
    return this.action(cb);
};
readFileAction._go(function(data){
    console.log(data);
})
```
You should understand what above `_go` does is equivalent to following:
```js
readFile("data.txt", function(data){
    console.log(data);
});
```
Just with one different, we seperate action creation(wrap `readFile` in `new Action`) and application(use `_go` to supply a callback), in fact we have successfully did a [CPS transformation](https://en.wikipedia.org/wiki/Continuation-passing_style), we will talk about that later.

Now we want to chain callbacks in Promise `then` style:
```js
Action.prototype._next = function(cb) {
    var self = this;
    return new Action(function(_cb) {
        return self.action(function(data) {
            var _data = cb(data);
            return _cb(_data);
        });
    });
};
```
Let's break down a little here:

+ `_next` should accept a callback `cb`, and return a new `Action`.
+ When the new `Action` fired, the original `Action`'s action should be fired first, and send the value to `cb`.

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

Nice, we just use two simple functions, and the callbacks can be written in a more readable way, but we have a very important problem to be solve yet: what if we want nest async `Action`s inside an `Action`, it turn out with an adjusted `_next` function, we can handle that:

```js
Action.prototype._next = function(cb) {
    var self = this;
    return new Action(function(_cb) {
        return self.action(function(data) {
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
We use `instanceof Action` to check if a callback returns a `Action` or not, if an `Action` is returned, we fire it with callbacks in future:

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
Now we can say we have solved the callback hell problem! well, actually just 50% of it.
One important thing to remember: **an `Action` is not happening if you don't fire it, and it can be fired multiple times, it's just a reference to a wrapped function**:
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

We'll present `freeze` to fire an `Action` immediately, now let's face another 50% of the callback hell issue.

Error handling
--------------

One biggest issue with `Promise` is the error handleing is somewhat magic and complex:

+ It will eat your error sliently if you don't supply a `catch` at the end of the chain.
+ You have to use two different functions, `resolve` to pass value to the callbacks and `reject` to skip them, what about `throw` an `Error`?

What we can do to make it simpler? Well, it's a complex problem, so we start solving it by simplify it: **We use `Error` type as a special type to pass error information to the downstream**, what does this mean?

```js
Action.prototype.next = function(cb) {
    var self = this;
    return new Action(function(_cb) {
        return self.action(function(data) {
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

Here, let me present the final version of our `next` function, comparing to `_next` we write before, can you see what's the different? It still reture a new `Action`, when it fired, the original action are called, and we checked if the data are `instanceof Error`, if it's not, everything as usual, we feed it to `cb` that `next` received, but if it's an `Error`, we pass it to a future `_cb`, which we don't have now.

Symmetrically, we have to define a function that special deal with `Errors`, and let normal values pass:

```js
Action.prototype.guard = function(cb) {
    var self = this;
    return new Action(function(_cb) {
        return self.action(function(data) {
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

This time, we know the `cb` that `guard` received are prepared for `Error` values, so when we flip the logic.

Following code demonstrate how to use our `next` and `guard`:

```
new Action(function(cb){
    readFile('fileA', function(err, data){
        if (err){
            // see how to pass an Error to downstream, not reject, not throw, just return
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
.next(
    try{
        return someProcessMayWentWrong(data);
    }catch(e){
        // same as above, we return the error
        return e;
    }
}))
.next(function(data){
    // This process will be skip if previous step pass an Error
    return anotherProcess(data);
})
.guard(function(e){
    // This process will be skip if there's no Errors
    return processError(e);
});
._go(console.log);

```

The final result will be produced by `anotherProcess` if `someProcessMayWentWrong` didn't go wrong, or produced by `processError` otherwise.

You can place `guard` in the middle of the chain, all `Errors` before if will be handled by it, and the value it produced, will be passed to the rest of the chain.

So, what if the use didn't supply a `guard`? Well, since use have to supply a callback to the `_go`, they can check if the callback they supplied received an `Error` or not like this:

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
Yeah, it does work, but we don't want force our user to write like above, and we should throw `Error` in case user didn't `guard` them:

```js
Action.prototype.go = function(cb) {
    return this.action(function(data) {
        if (data instanceof Error) {
            throw data;
        } else if (cb != null) {
            return cb(data);
        }
    });
};

```
Now if user don't guard `Error`s, we will yell at them when `Error` occurs!
```
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
.go() // The Error will be throw!

```

Finally, to ease error management, and to attack the [v8 optimization problems](https://github.com/petkaantonov/bluebird/wiki/Optimization-killers#2-unsupported-syntax). We recommand use `Action.safe`:

```js
// this small function minimize v8 try-catch overhead, and make attaching custom Error easy
Action.safe = function(err, fn) {
    return function(data) {
        try {
            return fn(data);
        } catch (_error) {
            return _error;
        }
    };
};
```
And use `safe` wrap your `someProcessMayWentWrong`:
```
var safe = Action.safe;
new Action(function(cb){
    readFile('fileA', function(err, data){
        if (err){
            // see how to pass an Error to downstream, not reject, not throw, just return
            cb(err);
        }else{
            cb(data);
        }
    });
})
.next(
    safe(new Error("PROCESS_ERROR_XXX: process xxx failed when xxx"), someProcessMayWentWrong)
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

That's all core functions of `Action` is going to give you.
