Action = require '../Action'
lift = Action.makeNodeAction

fs = require 'fs'
readDirA = lift fs.readdir
statA    = lift fs.stat

path = require 'path'

dirTree = (dirName) ->
    readDirA dirName
    .next (fileNames) ->
        Action.parallel fileNames.map (fileName) ->
            p = path.join(dirName, fileName)
            statA(p).next (stat) ->
                if stat.isDirectory() then dirTree p else p

dirTree('./').go (paths) ->
    console.log(paths.join '\n')
