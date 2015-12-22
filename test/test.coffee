Action = require '../Action.coffee'
core = require './core.coffee'
freeze = require './freeze.coffee'
chain = require './chain.coffee'
race = require './race.coffee'
delay = require './delay.coffee'
signal = require './signal.coffee'
retry = require './retry.coffee'
parallel = require './parallel.coffee'
join = require './join.coffee'
throttle = require './throttle.coffee'
sequence = require './sequence.coffee'
safes = require './safes.coffee'
makeNodeAction = require './makeNodeAction.coffee'
co = require './co.coffee'


console.log 'Testing core functions ====================='
core
.next ->
    console.log 'Test Action.freeze ====================='
    freeze
.next ->
    console.log 'Test Action.chain ======================'
    chain
.next ->
    console.log 'Test Action.race ======================='
    race
.next ->
    console.log 'Test Action.delay ======================'
    delay
.next ->
    console.log 'Test Action.retry ======================'
    retry
.next ->
    console.log 'Test Action.parallel ==================='
    parallel
.next ->
    console.log 'Test Action.join ======================='
    join
.next ->
    console.log 'Test Action.sequence ==================='
    sequence
.next ->
    console.log 'Test Action.throttle ==================='
    throttle
.next ->
    console.log 'Test Action.safe and safeRaw ==========='
    safes
.next ->
    console.log 'Test Action.makeNodeAction ============='
    makeNodeAction
.next ->
    console.log 'Test Action.co ========================='
    co
.next ->
    console.log 'Test Action.signal and fuseSignal ======'
    signal
.go -> console.log 'Tests all passed'
