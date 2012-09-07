###
Streamer compiler, turns source into events to allow streaming updates.
###
_ = require 'underscore'
walk = require 'walk'
fs = require 'fs'
path = require 'path'
Q = require 'q'
chokidar = require 'chokidar'
url = require 'url'

#namespace out the compilers, so I can call these by name at the top level
compilers =
    coffeescript: require 'coffee-script'
    uglify: require 'uglify-js'
    handlebars: require 'handlebars'


#Just plain functions here
merge = (object, rest...) ->
    _.extend _.clone(object), rest...

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
        template_name = options.file_name.replace options.directory, ''
        options.template_name = template_name.replace path.extname(template_name), ''
        options.source = String template_function
        options.source =
            """
            (function() {
                var template = Handlebars.template, templates = Handlebars.templates = Handlebars.templates || {};
                templates['#{options.template_name}'] = template(#{options.source});
                })();
            """
        options.name = options.template_name
        options

compile = (file_name, options, callback) ->
    #pick the right pipeline, then create a Q chain from it
    pipeline = options.pipelines[path.extname(file_name)]
    if not pipeline
        if options.log
            console.log "no pipeline for #{file_name}"
        return
    if options.log
        console.log "compiling #{file_name} #{options.directory}"
    options = merge {file_name: file_name}, options

    #and a promise chain, adding in the compiler sequences as a pipeline
    result = Q.resolve options
    result.then realpath

    pipeline.forEach (f) ->
        result = result.then f

    result
        .then (options) ->
            Q.fcall () ->
                callback options, null
        .fail (error) ->
            callback options, error
        .end()

#our exported bits
###
Default options for watch.
@param
###
exports.DEFAULTS = DEFAULTS =
    directory: process.cwd()
    mount: '/'
    followLinks: true
    walk: true
    log: false
    pipelines:
        '.coffee': [read, coffeescript]
        '.handlebars': [read, handlebars]
    makes:
        '.coffee.js': '.coffee'


###
Connect middleware, this will stream compiled content on demand.
###
exports.deliver = (options) ->
    options = merge DEFAULTS, options
    match_mount = new RegExp "^#{options.mount}"
    (request, response, next) ->
        #should we try at all?
        if request.method isnt 'GET'
            return next()
        pathname = url.parse(request.url).pathname
        if not match_mount.exec pathname
            return next()
        pathname = pathname.replace match_mount, ''
        pathname = path.join options.directory, pathname
        #now let's figure all the actual file names possible
        possible = null
        for to, from of options.makes
            match_to = new RegExp("#{to}$")
            if match_to.exec pathname
                possible = pathname.replace match_to, from
                break
        if possible
            if options.log
                console.log "possibly streaming #{possible}"
            compile possible, options, (data, error) ->
                if error
                    if options.log
                        console.log error
                    next()
                else
                    response.setHeader 'Location', data.file_name
                    response.end data.source
        else
            next()

###
Watch a directory for source file changes, firing the callback with compiled
source.
@param {} options Take a look at DEFAULTS
@param {Function) callback (data, error)
###
exports.watch = (options, callback) ->
    options = merge DEFAULTS, options
    #changes for sure
    watcher = chokidar.watch options.directory
    watcher.on 'error', (error) ->
        if options.log
            console.log error
    watcher.on 'add', (path) ->
        #this gets called on an add -- and as an initial walk when we turn on
        options.why = 'fileadd'
        compile path, options, callback
    watcher.on 'change', (path) ->
        options.why = 'filechange'
        compile path, options, callback
    watcher
