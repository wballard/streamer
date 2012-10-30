# Overview

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


