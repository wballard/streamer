###
This is the main application script. It:
-sets up a CommonJS module repository
-connects socket.io to get hot code updates
-takes those hot code updates and maintains them as modules
###

#following the CommonJS format, let's build a modules dictionary, this will
#keep track of all modules that are under the hot loading scheme
modules = {}
#and a require function that let's us get modules from this dictionary
#this isn't very smart yet, but will serve in a pinch
_require = (module_name) ->
    modules[module_name]

#code loading has deferreds so that we can handle the startup
deferred = {}
resolveCode = (relative_name) ->
    if not deferred[relative_name]
        deferred[relative_name] = new $.Deferred()
    deferred[relative_name].resolve()

#make things visible at the top level as an app
@app = {}
@app.modules = modules
@app.promiseCode = (relative_name) ->
    if not deferred[relative_name]
        deferred[relative_name] = new $.Deferred()
    deferred[relative_name].promise()

#hooking up to socket.io to get code updates, this is where templates
#and code come from -- and this is it, the rest of the application is
#dynamically loaded
socket = io.connect('')
socket.on 'code', (data) =>
    #code comes in as a string, let's wrap and execute it as if it
    #was a CommonJS module, and store it named by the relative file path
    relative_name = data.file_name.replace data.directory, ''
    data.name = data.name or relative_name
    exports = {}
    require = _require
    #call in context, this will expose objects via exports, and in the case
    #of handlebars templates will hook them onto window.Handlebars
    console.log @app
    Function(data.source).call(@app)
    #tracking all our own hot loaded modules
    modules[data.name] = exports
    resolveCode(data.name)
    $(window).trigger 'code', data


