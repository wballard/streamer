###
# Overview

This is the main application script. It:

- defines a root application, store at this.app, which in the browser is window.app
- sets up a CommonJS module repository
- tracks the dependency graph generated by require
- fulfills require() calls via promises using a [two pass technique](#two-pass)
- exposes via exports
- tracks modules by their source name
- tracks modules by their module.id
- connects socket.io to get hot code updates

# Hot Updates
Any time you change a watched module, it will be redelivered to this client via socket.io. Even more than that, the require chain is a dependency graph, so that modules will be rebound when lower level dependencies change.

# Two Pass {#two-pass}
Code loading will make *at least* two passes if there is a require statement. This is actually running the code, not trying to tweak past it with regular expressions that short out require, since require can plenty well be a function on function!

Code needs to be reloadable, which means that it will be run more than once in a given browser session. With this in mind, you will need to pay attention to a few key things at the top level of your script
- If you register events, you should do so with namespaces and turn them off at the start of your script
- If you manipulate the DOM, you should be prepared to remove your changes

Now, if you put your event registration and DOM manipulation in event handlers then this is less of a concern, just know that your script will *run* when it is hot loaded. And it will be run at least twice if you use require at all. This is because the require system will set a dependency, and likley that code will not be available. So, your script on the first run will end up with a require that doesn't quite work yet!

Once that required code is loaded, your script will be run again, it may:
- work without error
- hit another require statement, triggering another dependency pass
- errors our, in which case it is not available

# Events
## loadingcode
Triggered with `(event, data, app)` where data is the information just back from the server over socket.io. This allows you to hook and intercept.
## loadedcode `(event, data, app)` where data is the information now that the code is all the way loaded. You can no longer hook, but you know code is available.

## Requirements
This relies on jQuery being available to trigger events.


###

#keep track of code as it is loading
loading = {}

#loaded code modules are kept here along with their exports
loaded = {}

#ask the server to start off a code load sequence
loadCode = (socket, module_name, force) ->
    console.log("asking server for #{module_name}") if app.log
    if loading[module_name] and not force
        #re-entrancy protection
    else
        loading[module_name] = true
        socket.emit('load', module_name)

#call when we start loading, and this may just ask the server for bytes
loadingCode = (socket, data, app, force) ->
    module_name = data.module_name
    if loading[module_name] and not force
        #re-entrancy prevention
    else
        loading[module_name] = true
        if $
            $(window).trigger 'loadingcode', [data, app]
        console.log("loading #{module_name}") if app.log

#call when we are done loading
loadedCode = (socket, data, app) ->
    module_name = data.module_name
    console.log("loaded #{module_name}") if app.log
    loaded[module_name] = app.module
    #all dependent modules need to be reloaded
    dependent_modules = dependencies[module_name] or []
    for dependent_module, _ of dependent_modules
        loadCode socket, dependent_module, true
    if $
        $(window).trigger 'loadedcode', [data, app]

#keep track of dependencies built up via require
dependencies = {}
trackRequirement = (module_name, requires_module_name) ->
    chain = dependencies[requires_module_name] or {}
    chain[module_name] = true
    dependencies[requires_module_name] = chain

#make things visible at the top level as an app
@app = app = {}
app.log = false
app.loaded = loaded

#hooking up to socket.io to get code updates, this is where templates
#and code come from -- and this is it, the rest of the application is
#dynamically loaded
socket = io.connect('')
socket.on 'code', (data) ->
    loadingCode socket, data, app, true
    #a context that shorts out part of the application, so that app is still
    #our 'global', but we can have a temporaty exports and module buffer
    #this approach lets libraries like handlebars that install into a global
    #'this' get hooked into our app, not window.
    app.exports = {}
    app.module =
            id: data.module_name
            exports: app.exports
    app.require = (module_name) ->
        #requirements set up a dependency chain
        trackRequirement data.module_name, module_name
        #first things first, we may actually have code already loaded
        return loaded[module_name] if loaded[module_name]
        #and of course, we need to load the required module, if it isn't around
        loadCode socket, module_name
        throw "#{module_name} not yet available"
    #call in context, 'this' is app for the injected code, so all our hot loaded
    #code is run inside the app, not in the browser or global
    try
        Function(
            """
                require = this.require;
                exports = this.exports;
                module = this.module;
                #{data.source}
            """).call(app)
        loadedCode(socket, data, app)
    catch e
        console.log(e, data, app) if app.log


