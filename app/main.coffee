#This is a simple 'app' to get the idea

home = require 'home.handlebars'
message = require 'message.handlebars'
$('body').html home({})
#remove this comment and save
#$('.container').append message({})
