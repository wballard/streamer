#This is a simple 'app' to get the idea

home = require 'home.handlebars'
message = require 'message.handlebars'
tools = require 'include/tools'
tools.go()
$('body').html home({})
#remove this comment and save
#$('.container').append message({})
