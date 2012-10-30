###
This is the root server for a simple one page application using jQuery mobile.
It
-is able to stream all source code at /src form ./src
-serves a root page at /
-serves static assets at /assets from ./assets
-serves static libraries from third parties at /lib from ./lib
-is able to push hot code updates for everything in ./src/client
###

express = require 'express'
path = require 'path'
streamer = require './streamer'

app = require('express')()
server = require('http').createServer(app)
io = require('socket.io').listen(server)

app.use '/assets', express.static('assets')
app.use '/lib', express.static('lib')
app.use '/src', streamer.deliver(
    #deliver compiled source from
    directory: path.join(__dirname, '..')
    log: false
)
app.use streamer.push(
    #any time source changes in here, push it over socket io
    directory: path.join(__dirname, '..', 'client')
    log: true
    io: io
)

#otherwise, this is a single page app
app.use '/', (request, response, next) ->
    console.log request.url
    response.sendfile path.join(__dirname, '../index.html')

io.set 'log level', 0

server.listen(9000)
