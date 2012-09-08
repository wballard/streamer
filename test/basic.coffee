###
Basic works-at-all tests.
###

should = require 'should'
fs = require 'fs'
streamer = require '../streamer.coffee'
request = require 'supertest'
connect = require 'connect'
Handlebars = require 'handlebars'


describe 'can deliver code via GET', ->
    app = connect()
    app.use(streamer.deliver(
        directory: __dirname + '/src'
        mount: '/at'
        log: false
    ))
    it 'should be able to stream coffescript', (done) ->
        request(app)
            .get('/at/scratch.coffee.js')
            .expect(200)
            .expect('Content-Type', /javascript/)
            .end (req, res) ->
                eval(res.body)
                done()


watcher = null

describe 'callbacks from code changes', ->

    afterEach (done) ->
        watcher.close()
        done()

    it 'should fire events on start', (done) ->
        watcher = streamer.watch
            directory: __dirname + '/src/scratch.coffee'
            log: false
            , (error, data) ->
                data.should.have.property('source')
                eval(data.source)
                done()

    it 'should fire events on change', (done) ->
        watcher = streamer.watch
            directory: '/tmp/generated.coffee'
            walk: false
            log: false
            , (error, data) ->
                data.should.have.property('source')
                eval(data.source)
                done()
        source = '/tmp/generated.coffee'
        if fs.existsSync source
            fs.unlinkSync source
        fs.writeFileSync source, '#A comment'


    it 'knows about handlebars', (done) ->
        watcher = streamer.watch
            directory: __dirname + '/src/scratch.handlebars'
            , (error, data) ->
                data.should.have.property('source')
                eval(data.source)
                done()
