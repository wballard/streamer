###
This is our hot code loading server using express and socket.io to connect
the core streamer library to clients.
###

express = require 'express'
path = require 'path'
streamer = require './streamer'
fs = require 'fs'

exports.run = (port, root_directory) ->
    app = require('express')()
    server = require('http').createServer(app)
    io = require('socket.io').listen(server)

    #stream on demand
    app.use '/src', streamer.deliver(
        #deliver compiled source from
        directory: root_directory
        log: false
    )
    #stream over socket io on file changes
    app.use streamer.push(
        directory: root_directory
        log: true
        io: io
    )

    #otherwise, this is a single page app index.html
    app.use '/', (request, response, next) ->
        response.sendfile path.join(fs.realpathSync(__filename), '../boilerplate.html')

    io.set 'log level', 0

    console.log "serving #{root_directory} on #{port}"
    server.listen(port)
