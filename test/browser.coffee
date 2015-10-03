Action = require '../src/Action.coffee'

new Action (cb) ->
    Action.jsonp
        url: 'http://jsonplaceholder.typicode.com/posts/1'
    .go (data) ->
        console.log data
        cb()
.next ->
    new Action (cb) ->

        script = Action.jsonp
            url: 'http://jsonplaceholder.typicode.com/posts/1'
        .go (data) ->
            console.log script
            console.log data
            cb()

.next ->
    new Action (cb) ->
        Action.ajax
            method: 'GET'
            url: 'http://jsonplaceholder.typicode.com/posts?' + Action.param
                userId: 2
        .next(JSON.parse)
        .go (data) ->
            console.log data
            cb()
.next ->
    new Action (cb) ->

        f = new FormData()
        f.append('username', 'Chris')

        xhr = Action.ajax
            method: 'POST'
            url: 'http://jsonplaceholder.typicode.com/posts'
            data: f
            responseType: 'json'
        .go (data) ->
            console.log xhr.getAllResponseHeaders()
            console.log data
            cb()

.next ->
    new Action (cb) ->
        xhr = Action.ajax
            method: 'POST'
            url: 'http://jsonplaceholder.typicode.com/posts'
            data:
                what: 2
            responseType: 'json'
        .go (data) ->
            console.log xhr.getAllResponseHeaders()
            console.log data
            cb()

.next ->
    new Action (cb) ->
        xhr = Action.ajax
            method: 'POST'
            url: 'http://jsonplaceholder.typicode.com/posts'
            data: Action.param
                what: 3
        .go (data) ->
            console.log xhr.getAllResponseHeaders()
            console.log data
            cb()

.next ->
    new Action (cb) ->
        xhr = Action.ajax
            method: 'DELETE'
            url: 'http://jsonplaceholder.typicode.com/posts/1'
            headers:
                'Test-Header': '1234'
        .go (data) ->
            console.log xhr.getAllResponseHeaders()
            console.log data
            cb()

.next ->
    new Action (cb) ->
        xhr = Action.ajax
            method: 'POST'
            url: 'http://jsonplaceholder.typicode.com/posts'
            data:
                foo: 'bar'
            timeout: 100
        .guard (e) ->
            console.log e
            'error handled'
        .go (data) ->
            console.log data

.go()
