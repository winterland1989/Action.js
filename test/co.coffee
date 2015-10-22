Action = require '../Action.coffee'
{assertData, actionFoo, monadicActionFoo, actionBar, monadicActionFail} = require './fixture.coffee'

coTestActionFn = Action.co ->
    l = 3
    v = yield actionBar
    assertData v, 'bar'
    acc = v
    while l-- > 0
        acc += 'foo'
        v = yield monadicActionFoo v
        assertData v, acc
    v = yield actionBar
    assertData v, 'bar'

coTestActionFnWithErrors = Action.co ->
    try
        l = 3
        v = yield actionBar
        assertData v, 'bar'
        acc = v
        while l-- > 0
            acc += 'foo'
            v = yield monadicActionFail v
            assertData v, acc
        v = yield actionBar
        assertData v, 'bar'
    catch e
        assertData e.message, 'testError'
        yield Action.wrap e

module.exports =
    coTestActionFn()
    .next ->
        console.log 'co test without errors ok'
        coTestActionFnWithErrors()
    .guard (err) ->
        assertData err.message, 'testError'
        console.log 'co test with errors ok'
