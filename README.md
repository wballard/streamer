# Let's Get Rolling

Find yourself a nice scratch directory and `cd` on in...

```
npm install git://github.com/wballard/streamer.git -g
streamer --sample
streamer
```

Now hit it with your [browser](http://localhost:9000). Follow the
suggestions.

# Goals

Think of all the times you reload or refresh your browser during
development. I want that time back. I want to be able to edit my
templates, scripts, and styles and have the pages just update.

I want to be able to build browser applications without reloading the
page or restarting the server.

Streamer takes a different approach compared to other web frameworks, it
focuses on *hot loading code* over *socket.io* including:
    * templates
    * script
    * styles

# How is this Different?

Web frameworks are fundamentally code and assets loaded over *GET*.
Streamer is a push based, event driven framework that makes your code
update in the browser without you or your user needing to reload a page.

## Target Applications

Streamer is aimed at single page applications and widgets where you are
injecting code into a container page. It doesn't impose a framework or
an application design, it is just a way to get code.

## Code Loading

Lots of ways to get JavaScript modules out there. Streamer takes the
CommonJS approach, you just `require(...)`, and the hot loading system
takes care of dependencies for you by simply reloading until the
dependencies are filled.

## HTML5 Boilerplate

When you want to make a new single page application, Streamer serves
HTML5 boilerplate at the root, allowing you to customize from there with
hot loaded code.

## Dealing with State

Streamer really does reload your code, which means it really does re-run
it. So, you can double up event handlers, and overwrite variables as
code reloads. This is a feature, but you need to be a bit careful.

### Events

### Data & Variables

The most important thing to realize is variables in your hot loaded
scripts can and will be re-set, so you can adopt a strategy like this:

```
var x = x || {"default": "value"};
```

Alternately, you can put things in local storage or explicitly hang them
off of `window`.
