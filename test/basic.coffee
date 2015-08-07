Action = require '../src/Action'

#foo = new Action (cb) ->
#    setTimeout (() -> cb 'foo'), 1000
#
#foo
#.next (data) ->
#    data + 'bar'
#.next (data) ->
#    new Action (cb) ->
#        setTimeout (() -> cb(data + '!')), 1000
#
#.go (data) -> console.log data


fooE = new Action (cb) ->
    setTimeout (() -> cb 'foo'), 1000

#fooE
#.next (data) ->
#    data + 'bar'
#.next (data) ->
#    new Action (cb) ->
#        setTimeout (() -> cb(new Error 'wtf')), 100
#.go (data) -> console.log data
#
#fooE = new Action (cb) ->
#    setTimeout (() -> cb 'foo'), 1000

fooE
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
