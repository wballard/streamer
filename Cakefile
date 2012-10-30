fs    = require 'fs'
log   = console.log
spawn = require('child_process').spawn
chokidar = require 'chokidar'

server = null

watcher = chokidar.watch 'lib/server'
watcher.on 'all', (path) ->
    server.kill() if server

task 'start', 'Start server.coffee and restart on server file changes', ->
    log "Starting server, kill with Ctrl-c"
    server = spawn "coffee", ["lib/server/server.coffee"]
    server.stdout.on "data", (data) ->
        log "#{data}"

    server.stderr.on "data", (data) ->
        log "#{data}"

    server.on "exit", ->
        log "Restart server"
        invoke "start"



