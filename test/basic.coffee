###
Basic works-at-all tests.
###

should = require 'should'
fs = require 'fs'
path = require 'path'
lib  = path.join(path.dirname(fs.realpathSync(__filename)), '../lib')
streamer = require lib + '/streamer'
request = require 'supertest'
connect = require 'connect'
Handlebars = require 'handlebars'
path = require 'path'

describe 'can deliver code via GET', ->
    app = connect()
    app.use(streamer.deliver(
        directory: __dirname + '/src'
        log: false
    ))
    it 'should be able to stream coffescript as js', (done) ->
        request(app)
            .get('/alternate.coffee.js')
            .expect('Content-Type', /javascript/)
            .expect('Location', /alternate.coffee/)
            .expect(201, done)

    it 'should be able to stream coffescript', (done) ->
        request(app)
            .get('/alternate.coffee')
            .expect('Content-Type', /javascript/)
            .expect('Location', /alternate.coffee/)
            .expect(201, done)

    it 'should be able to stream coffescript without an extension, require style', (done) ->
        request(app)
            .get('/alternate')
            .expect('Content-Type', /javascript/)
            .expect('Location', /alternate.coffee/)
            .expect(201, done)

    it 'should be able to stream javascript', (done) ->
        request(app)
            .get('/scratch.js')
            .expect('Content-Type', /javascript/)
            .expect('Location', /scratch.js/)
            .expect(201, done)

    it 'should be able to stream javascript without an extension, require style', (done) ->
        request(app)
            .get('/scratch')
            .expect('Content-Type', /javascript/)
            .expect('Location', /scratch.js/)
            .expect(201, done)

    it 'should be able to stream css', (done) ->
        request(app)
            .get('/scratch.css')
            .expect('Content-Type', /css/)
            .expect('Location', /scratch.css/)
            .expect(201, done)

watcher = null

describe 'as middleware', ->

    it 'provides a client library', (done) ->
        app = connect()
        app.use(streamer.push())
        request(app)
            .get('/streamer.js')
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

describe 'know about handlebars', ->

    afterEach (done) ->
        watcher.close()
        done()

    it 'fires an initial event', (done) ->
        watcher = streamer.watch
            directory: __dirname + '/src/hb'
            , (error, data) ->
                data.should.have.property('source')
                data.should.have.property('template')
                #if you use a partial, as is the case in this template, you
                #depend on it by name
                data.depends_on.should.eql(['somepartial'])
                data.require_from.should.eql(__dirname + '/src/hb')
                #and since this is a template that registers as a partial
                data.provides.should.eql [
                    path.join(__dirname, 'src/hb/scratch.handlebars'),
                    'this_is_scratch']
                #this is a handlebars template, and should show up as runnable code
                context =
                    #feed in handlebars, no need to prove we can load it here
                    Handlebars: Handlebars
                    module: {}
                Function("""
                module = this.module;
                #{data.source}
                """).call(context)
                #self registration as a partial with a supplied name in the
                #source {{registerPartial ...}} tag
                context.Handlebars.partials.should.have.property('this_is_scratch')
                done()
