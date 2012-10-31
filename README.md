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

## How is this Different?

Web frameworks are fundamentally code and assets loaded over *GET*.
Streamer is a push based, event driven framework that makes your code
update in the browser without you or your user needing to reload a page.

## Target Applications

Streamer is aimed at single page applications and widgets where you are
injecting code into a container page. It doesn't impose a framework or
an application design, it is just a way to get code.

# Code Loading

Lots of ways to get JavaScript modules out there. Streamer takes the
CommonJS approach, you just `require(...)`, and the hot loading system
takes care of dependencies for you by simply reloading until the
dependencies are filled.
