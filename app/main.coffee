#This is a simple 'app' to get the idea

home = require 'home.handlebars'
message = require 'message.handlebars'
$ = require 'jquery-1.8.2.js'
$('body').html home({})
#remove this comment and save
#$('.container').append message({})
