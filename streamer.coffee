###
Streamer compiler, turns source into events to allow streaming updates.
###
_ = require 'underscore'
walk = require 'walk'
fs = require 'fs'
path = require 'path'
Q = require 'q'
coffeescript = require 'coffee-script'
uglifyjs = require 'uglify-js'


#Just plain functions here
merge = (object, rest...) ->
    _.extend object, rest...

realpath = (options) ->
    defer = Q.defer()
    fs.realpath options.file_name, (err, full_file_name) ->
        if err
            defer.reject err
        else
            options.file_name = full_file_name
            defer.resolve options
    defer.promise

read = (options) ->
    defer = Q.defer()
    fs.readFile options.file_name, 'utf-8', (err, data) ->
        if err
            defer.reject err
        else
            options.source = data
            defer.resolve options
    defer.promise

coffee = (options) ->
    Q.fcall ->
        options.source = coffeescript.compile options.source, options
        options

uglify = (options) ->
    Q.fcall ->
        ast = uglifyjs.parser.parse options.source
        ast = uglifyjs.uglify.ast_mangle ast
        ast = uglifyjs.uglify.ast_squeeze ast
        options.source =  uglifyjs.uglify.gen_code ast
        options

compile = (file_name, options, callback) ->
    #pick the right pipeline, then create a Q chain from it
    pipeline = options.pipelines[path.extname(file_name)]
    options = merge {file_name: file_name}, options

    #and a promise chain, adding in the compiler sequences as a pipeline
    result = Q.resolve options
    result.then realpath

    pipeline.forEach (f) ->
        result = result.then f

    result
        .then (options) ->
            Q.fcall () ->
                console.log
                callback options.file_name, options.source, options
        .fail (error) ->
            console.log error
        .end()

#our exported bits
exports.DEFAULTS = DEFAULTS =
    directory: process.cwd()
    followLinks: true
    walk: true
    pipelines:
        '.coffee': [read, coffee, uglify]

exports.watch = (options, callback) ->
    options = merge DEFAULTS, options

    #changes for sure
    watcher = fs.watch options.directory, (event, filename) ->
        console.log event, filename

    #and initially all files
    if options.walk
        walker = walk.walk options.directory, options
        walker.on 'file', (root, fileStats, next) ->
            try
                compile path.join(root, fileStats.name), options, callback
            catch err
                console.log err
            finally
                next()
