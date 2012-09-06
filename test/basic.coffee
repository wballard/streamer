###
Basic works-at-all tests.
###

should = require 'should'
fs = require 'fs'
streamer = require '../streamer.coffee'

watcher = null

describe 'basic compilation', ->

    afterEach (done) ->
        watcher.close()
        done()

    it 'should fire events on start', (done) ->
        hits = 0
        watcher = streamer.watch
            directory: __dirname + '/src'
            log: true
            , (source_file_name, compiled, options) ->
                hits += 1
                done() if hits == 1

    it 'should fire events on change', (done) ->
        watcher = streamer.watch
            directory: '/tmp'
            log: true
            walk: false
            , (source_file_name, compiled, options) ->
                done()
        source = '/tmp/generated.coffee'
        if fs.existsSync source
            fs.unlinkSync source
        fs.writeFileSync source, '#A comment'


