###
Streamer compiler, turns source into events to allow streaming updates.
###
_ = require 'underscore'
walk = require 'walk'
fs = require 'fs'
path = require 'path'
Q = require 'q'
chokidar = require 'chokidar'
compilers =
    coffeescript: require 'coffee-script'
    uglify: require 'uglify-js'
    handlebars: require 'handlebars'


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

coffeescript = (options) ->
    Q.fcall ->
        options.source = compilers.coffeescript.compile options.source, options
        options

uglify = (options) ->
    Q.fcall ->
        ast = compilers.uglify.parser.parse options.source
        ast = compilers.uglify.uglify.ast_mangle ast
        ast = compilers.uglify.uglify.ast_squeeze ast
        options.source =  compilers.uglify.uglify.gen_code ast
        options

handlebars = (options) ->
    Q.fcall ->
        template_function = compilers.handlebars.precompile options.source, options
        options.source = String template_function
        options.source = "var template = #{options.source}"
        options

compile = (file_name, options, callback) ->
    #pick the right pipeline, then create a Q chain from it
    pipeline = options.pipelines[path.extname(file_name)]
    if not pipeline
        if options.log
            console.log "no pipeline for #{file_name}"
        return
    if options.log
        console.log "compiling #{file_name}"
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

###
Default options for watch.
@param
###
exports.DEFAULTS = DEFAULTS =
    directory: process.cwd()
    followLinks: true
    walk: true
    log: false
    pipelines:
        '.coffee': [read, coffeescript, uglify]
        '.handlebars': [read, handlebars]

###
Watch a directory for source file changes, firing the callback with compiled
source.
@param {} options Take a look at DEFAULTS
@param {Function) callback (source_file_name, compiled_source, options)
###
exports.watch = (options, callback) ->
    options = merge DEFAULTS, options

    #changes for sure
    watcher = chokidar.watch options.directory

    watcher.on 'error', (error) ->
        if options.log
            console.log error
    watcher.on 'add', (path) ->
        compile path, options, callback
    watcher.on 'change', (path) ->
        compile path, options, callback
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
    watcher
