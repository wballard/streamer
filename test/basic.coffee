###
Basic works-at-all tests.
###

should = require 'should'
fs = require 'fs'
streamer = require '../streamer.coffee'

describe 'basic compilation', ->
    it 'should fire events on start', (done) ->
        watcher = streamer.watch
            directory: __dirname + '/src'
            , (source_file_name, compiled, options) ->
                done()

    it 'should fire events on change', (done) ->
        watcher = streamer.watch
            directory: __dirname + '/src'
            walk: false
            , (source_file_name, compiled, options) ->
                done()
        source = __dirname + '/src/generated.coffee'
        if fs.existsSync source
            fs.unlinkSync source
        fs.writeFileSync source, '#A comment'


