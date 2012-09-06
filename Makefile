
TOP=$(dir $(realpath $(lastword $(MAKEFILE_LIST))))
XPATH=$(TOP)node_modules/.bin:`pwd`/node_modules/.bin:$(PATH)
.PHONY: test

all: streamer.js

%.js: %.coffee
	export PATH=$(XPATH); coffee --compile $<

test:
	export PATH=$(XPATH); mocha --compilers coffee:coffee-script

watch:
	export PATH=$(XPATH); mocha --compilers coffee:coffee-script --watch
