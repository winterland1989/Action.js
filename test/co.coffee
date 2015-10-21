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

module.exports =
    coTestActionFn()
    .next ->
        coTestActionFnWithErrors()
        .next ->
            console.log 'co test without errors ok'
        .guard (err) ->
            assertData err.message, 'testError'
        .next ->
            console.log 'co test with errors ok'
