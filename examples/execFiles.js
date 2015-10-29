var Action = require('../Action.js');
var childProcess = require('child_process');
var execPaths = ['echo', 'echo'];
var execOpts  = ['hello', 'world'];

var execActions= execPaths.map(function(path, i){
    return new Action(function(cb){
        childProcess.execFile(path, [execOpts[i]], function(err, stdout, stderr){
            if (err){
                cb(err);
            } else {
                cb([stdout, stderr]);
            }
        })
    });
});


Action.sequence(execActions).go(function(results){
    results.map(console.log);
});
