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
        log: false
    ))
    it 'should be able to stream coffescript', (done) ->
        request(app)
            .get('/scratch.coffee.js')
            .expect('Content-Type', /javascript/)
            .expect('Location', /scratch.coffee/)
            .expect(201, done)


watcher = null

describe 'watch as middleware', ->

    it 'provides a client library', (done) ->
        app = connect()
        app.use(streamer.push())
        request(app)
            .get('/streamer/streamer.js')
            .expect('Content-Type', /javascript/)
            .expect(201, done)




describe 'provides callbacks from code changes', ->

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
            directory: __dirname + '/src/hb'
            , (error, data) ->
                data.should.have.property('source')
                data.should.have.property('template')
                #this is a handlebars template, and should show up as runnable code
                context =
                    Handlebars: Handlebars
                    module: {}
                Function("""
                module = this.module;
                #{data.source}
                """).call(context)
                context.module.id.should.equal('/scratch')
                context.Handlebars.partials.should.have.property('this_is_scratch')
                done()
