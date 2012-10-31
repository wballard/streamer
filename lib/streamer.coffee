###
Streamer compiler, turns source into events to allow streaming updates.
###
_ = require 'underscore'
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
    if options.module_name[0] is '/'
        options.module_name = options.module_name.slice(1)
    #and read on in the file content
    fs.readFile options.file_name, 'utf-8', (err, data) ->
        if err
            defer.reject err
        else
            options.source = data
            #full file name is provided
            options.provides.push options.file_name
            #name without extension
            options.provides.push \
                options.file_name.replace path.extname(options.file_name), ''
            #name without the relative directory
            without_directory = \
                options.file_name.replace((options.directory + '/'), '')
            options.provides.push without_directory
            #and hey -- without the name or relative directory
            options.provides.push \
                without_directory.replace(path.extname(options.file_name), '')
            #and well known modules
            for name, file_name of options.module_file_names
                if file_name is options.file_name
                    options.provides.push name
            defer.resolve options
    defer.promise

#shove in some extra lines of text
injector = (options) ->
    Q.fcall ->
        if options.inject
            options.source = "#{options.inject}\n#{options.source}"
        options

#Promise to compile the source from coffeescript to javascript
coffeescript = (options) ->
    Q.fcall ->
        options.source = compilers.coffeescript.compile options.source, options
        options

#Promise to uglify the source, returning compacted javascript
uglify = (options) ->
    Q.fcall ->
        ast = compilers.uglify.parser.parse options.source
        ast = compilers.uglify.uglify.ast_mangle ast
        ast = compilers.uglify.uglify.ast_squeeze ast
        options.source =  compilers.uglify.uglify.gen_code ast
        options

#Promise to compile the source from handlebars to javascript
handlebars = (options) ->
    Q.fcall ->

        #referenced partials need to be extracted
        needs_partials = []
        provides_partials = []

        ast = compilers.handlebars.parse options.source
        recurseForPartials = (o) ->
            if o.statements
                for statement in o.statements
                    if statement?.type is 'mustache'
                        if statement?.id?.string is 'partial'
                            for param in (statement.params or [])
                                provides_partials.push param?.string

                    #asking for a partial sets up a dependency
                    if statement?.type is 'partial'
                        needs_partials.push statement?.id?.string
                    #deal with handlebars being nested
                    if statement.program
                        recurseForPartials statement.program
        recurseForPartials ast
        options.depends_on = needs_partials

        #compile that source, and get a function post compilation
        template_function = compilers.handlebars.precompile options.source, options
        source = String template_function
        options.source =
            """
            Handlebars = this.Handlebars || require('handlebars.runtime.js')
            Handlebars.partials = Handlebars.partials || {};
            Handlebars.registerHelper("partial", function() {
                return "";
            });
            template = Handlebars.template(#{source});
            module.exports = template;
            """
        for name in provides_partials
            options.source += "\nHandlebars.partials['#{name}'] = module.exports;"
            options.provides.push name
        options.name = options.template_name
        options

#marker when we have compiled a template function, not just plain code
template = (options) ->
    Q.fcall ->
        options.template = true
        options

#marker that this is code
code = (options) ->
    Q.fcall ->
        options.content_type = 'application/javascript'
        options

#marker that this is style
stylesheet = (options) ->
    Q.fcall ->
        options.content_type = 'text/css'
        options


#Run the compilation sequence for a file, calling back when done
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
    options.depends_on = []
    options.provides = []

    #and a promise chain, adding in the compiler sequences as a pipeline
    result = Q.resolve options
    result.then realpath

    pipeline.forEach (f) ->
        result = result.then f

    result
        .then (options) ->
            Q.fcall () ->
                console.log("compiled #{file_name}") if options.log
                callback null, options
        .fail (error) ->
            callback error, options
        .end()

#our exported bits
###
Default options for watch.
###
exports.DEFAULTS = DEFAULTS =
    #this is a module name to file name translation table for well known modules
    module_file_names:
        'handlebars.runtime.js': path.join(__dirname, '../support/handlebars.runtime.js')
    #root directory where we'll build relative paths from
    directory: process.cwd()
    #follow links on file watching
    followLinks: true
    log: false
    pipelines:
        '.coffee': [read, injector, coffeescript, code]
        '.js': [read, code]
        '.handlebars': [read, handlebars, template, code]
        '.css': [read, stylesheet]
        '.png': [read]
    makes:
        '.coffee.js': '.coffee'
        '.js': '.js'
        '.css': '.css'


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
        io.of('/streamer').on 'connection', (socket) ->

            send_it = (data) ->
                if data.content_type is 'application/javascript'
                    socket.emit 'code', data
                else if data.content_type is 'text/css'
                    socket.emit 'stylesheet', data

            #a client has connected to us, time to look for code changes
            watcher = watch options, (error, data) ->
                if error
                    console.log(error) if options.log
                else
                    send_it data

            socket.on 'load', (module_name) ->
                #this is an explicit request to load code
                if options.module_file_names[module_name]
                    #a name we recognize, in which case we look up the file name
                    load_from_file = options.module_file_names[module_name]
                else if options.module_file_names[path.basename(module_name)]
                    load_from_file = options.module_file_names[path.basename(module_name)]
                else if module_name[0] is '/'
                    #assume this to be a full path when we have a prefix
                    load_from_file = module_name
                else
                    load_from_file = path.join(options.directory, module_name)
                compile load_from_file, options,
                    (error, data) ->
                        if error
                            console.log error
                        else
                            data.module_name = module_name
                            send_it data


            socket.on 'disconnect', () ->
                #clean up the file watcher
                watcher.close()

    #watch is also middleware that delivers a client library
    (request, response, next) ->
        if request.method is 'GET' and url.parse(request.url).pathname.toLowerCase() is '/streamer.js'
            if request.headers.referer
                referer_protocol = url.parse(request.headers.referer).protocol
            else
                referer_protocol = 'http:'
            options.inject = "host = '#{referer_protocol}//#{request.headers.host}'"
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
