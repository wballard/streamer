###
Basic works-at-all tests.
###

should = require 'should'
fs = require 'fs'
streamer = require '../streamer.coffee'

watcher = null

describe 'compilation', ->

    afterEach (done) ->
        watcher.close()
        done()

    it 'should fire events on start', (done) ->
        watcher = streamer.watch
            directory: __dirname + '/src/scratch.coffee'
            log: true
            , (source_file_name, compiled, options) ->
                eval(compiled)
                done()

    it 'should fire events on change', (done) ->
        watcher = streamer.watch
            directory: '/tmp/generated.coffee'
            log: true
            walk: false
            , (source_file_name, compiled, options) ->
                eval(compiled)
                done()
        source = '/tmp/generated.coffee'
        if fs.existsSync source
            fs.unlinkSync source
        fs.writeFileSync source, '#A comment'


    it 'knows about handlebars', (done) ->
        watcher = streamer.watch
            directory: __dirname + '/src/scratch.handlebars'
            log: true
            , (source_file_name, compiled, options) ->
                console.log compiled
                eval(compiled)
                done()
