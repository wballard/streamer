###
This is our hot code loading server using express and socket.io to connect
the core streamer library to clients.
###

express = require 'express'
path = require 'path'
streamer = require './streamer'
fs = require 'fs'
boilerplate    = path.join(path.dirname(fs.realpathSync(__filename)), '../node_modules/html5-boilerplate');

exports.run = (port, root_directory) ->
    app = require('express')()
    server = require('http').createServer(app)
    io = require('socket.io').listen(server)


    #stream on demand
    app.use '/', streamer.deliver(
        #deliver compiled source from
        directory: root_directory
        log: true
    )
    #stream over socket io on file changes
    app.use streamer.push(
        directory: root_directory
        log: true
        io: io
    )

    #otherwise, this is a single page app index.html
    boilerplate_index = path.join(fs.realpathSync(__filename), '../boilerplate.html')
    app_index = path.join(root_directory, 'boilerplate.html')

    app.get '/', (request, response, next) ->
        console.log app_index
        if fs.existsSync app_index
            response.sendfile app_index
        else
            response.sendfile boilerplate_index
    app.use '/', express.static(boilerplate)


    io.set 'log level', 0

    console.log "serving #{root_directory} on #{port}"
    server.listen(port)
