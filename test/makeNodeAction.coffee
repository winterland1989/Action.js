Action = require '../Action.coffee'
{assertData} = require './fixture.coffee'
fs = require 'fs'

module.exports =
    new Action (cb) ->
        readFileAction = Action.makeNodeAction fs.readFile
        console.log 'Reading test.coffee without encoding'
        readFileAction (__dirname + '/test.coffee')
        .next (data) ->
            assertData (data instanceof Buffer),  true
        .go ->
            console.log 'Action.makeNodeAction without options ok'
            cb()

    .next ->
        new Action (cb) ->
            readFileAction = Action.makeNodeAction fs.readFile
            console.log 'Reading test.coffee with encoding'
            readFileAction (__dirname + '/test.coffee'), encoding: 'utf8'
            .next (data) ->
                assertData (typeof data), 'string'
            .go ->
                console.log 'Action.makeNodeAction with options ok'
                cb()
