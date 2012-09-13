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


#Get a merged set of defaults with overrides
merge = (object, rest...) ->
    _.extend _.clone(object), rest...

#Promise the full file name
realpath = (options) ->
    defer = Q.defer()
    fs.realpath options.file_name, (err, full_file_name) ->
        if err
            defer.reject err
        else
            options.file_name = full_file_name
            defer.resolve options
    defer.promise

#Promise to read the source from a file
read = (options) ->
    defer = Q.defer()
    options.module_name =
        options.module_name or (options.file_name.replace options.directory, '')
    fs.readFile options.file_name, 'utf-8', (err, data) ->
        if err
            defer.reject err
        else
            options.module_file_names[options.module_name] =
                options.file_name
            options.source = data
            defer.resolve options
    defer.promise

#Promise to compile the source from coffeescript to javascript
coffeescript = (options) ->
    Q.fcall ->
        options.source = compilers.coffeescript.compile options.source, options
        options.content_type = 'javascript'
        options

#Promise to uglify the source, returning compacted javascript
uglify = (options) ->
    Q.fcall ->
        ast = compilers.uglify.parser.parse options.source
        ast = compilers.uglify.uglify.ast_mangle ast
        ast = compilers.uglify.uglify.ast_squeeze ast
        options.source =  compilers.uglify.uglify.gen_code ast
        options.content_type = 'javascript'
        options

#Promise to compile the source from handlebars to javascript
handlebars = (options) ->
    Q.fcall ->
        template_function = compilers.handlebars.precompile options.source, options
        template_name = options.file_name.replace options.directory, ''
        options.template_name =
            template_name.replace path.extname(template_name), ''
        options.source = String template_function
        options.source =
            """
            Handlebars = this.Handlebars || require('lib/handlebars.runtime.js')
            var template = Handlebars.template,
                templates = Handlebars.templates = Handlebars.templates || {};
            module.id = '#{options.template_name}';
            module.exports = template(#{options.source});
            templates[module.id] = module.exports;
            """
        options.name = options.template_name
        options.content_type = 'javascript'
        options

#marker when we have compiled a template function, not just plain code
template = (options) ->
    Q.fcall ->
        options.template = true

#Run the compilation sequence for a file, calling back when done
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
                callback null, options
        .fail (error) ->
            callback error, options
        .end()

#our exported bits
###
Default options for watch.
###
exports.DEFAULTS = DEFAULTS =
    #this is a module name to file name translation table that is updated
    #any time a module is loaded
    module_file_names: {}
    #root directory where we'll build relative paths from
    directory: process.cwd()
    #follow links on file watching
    followLinks: true
    log: false
    pipelines:
        '.coffee': [read, coffeescript]
        '.js': [read]
        '.handlebars': [read, handlebars, template]
        '': [read]
    makes:
        '.coffee.js': '.coffee'


###
Connect middleware, this will deliver compiled content on demand via GET.
@param {} options Take a look at DEFAULTS
Example:
If there is a file called /src/something.coffee, you just ask for
it to be /src/something.coffee.js, and streamer will deliver a compilation
from .coffee to .coffee.js.
###
exports.deliver = (options) ->
    options = merge DEFAULTS, options

    #This is the actual middleware
    (request, response, next) ->
        #should we try at all?
        if request.method isnt 'GET'
            return next()
        pathname = url.parse(request.url).pathname
        pathname = path.join options.directory, pathname
        #now let's figure all the actual file names possible
        possible = null
        for to, from of options.makes
            match_to = new RegExp("#{to}$")
            if match_to.exec pathname
                possible = pathname.replace match_to, from
                break
        if possible
            console.log("possibly streaming #{possible}") if options.log
            compile possible, options, (error, data) ->
                if error
                    if options.log
                        console.log error
                    next()
                else
                    response.setHeader 'Location', data.file_name
                    response.setHeader 'Content-Type', data.content_type
                    response.statusCode = 201
                    response.end data.source
        else
            next()

###
Watch a directory for source file changes, firing the callback with compiled
source.
@param {} options Take a look at DEFAULTS
@param {Function) node style callback (error, data)
###
exports.watch = watch = (options, callback) ->
    options = merge DEFAULTS, options
    callback = callback or (error, data) ->

    #the actual file watching and events
    watcher = chokidar.watch options.directory
    watcher.on 'error', (error) ->
        callback error, null
    watcher.on 'add', (path) ->
        #this gets called on an add -- and as an initial walk when we turn on
        options.why = 'fileadd'
        compile path, options, callback
    watcher.on 'change', (path) ->
        options.why = 'filechange'
        compile path, options, callback

    watcher

###
Push code upates. This is middle ware that delivers a client library using
socket.io, and sets up a socket.io connection point to watch for and push code
changes.
###
exports.push = (options) ->
    options = merge DEFAULTS, options


    if options.io
        io = options.io
        #we really can't send socket over itself and
        #options is the data context all the way down
        options.io = null
        io.sockets.on 'connection', (socket) ->
            #a client has connected to us, time to look for code changes
            watcher = watch options, (error, data) ->
                if error
                    console.log(error) if options.log
                else
                    socket.emit 'code', data

            socket.on 'load', (module_name) ->
                #this is an explicit request to load code
                if options.module_file_names[module_name]
                    load_from_file = options.module_file_names[module_name]
                else if module_name[0] is '/'
                    load_from_file = module_name
                else
                    load_from_file = path.join(__dirname, module_name)
                compile load_from_file, options,
                    (error, data) ->
                        if error
                            console.log error
                        else
                            data.module_name = module_name
                            socket.emit 'code', data

            socket.on 'disconnect', () ->
                #clean up the file watcher
                watcher.close()

    #watch is also middleware that delivers a client library
    (request, response, next) ->
        if request.method is 'GET' and url.parse(request.url).pathname.toLowerCase() is '/streamer/streamer.js'
            compile path.join(__dirname, 'client.coffee'), options,
                (error, data) ->
                    if error
                        console.log(error) if options.log
                        next()
                    else
                        response.setHeader 'Content-Type', data.content_type
                        response.statusCode = 201
                        response.end data.source
        else
            next()
