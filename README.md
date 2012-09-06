## Overview

Let's stream our scripts and templates to single page apps, compiling on
demand, and redraw our application user interfaces doing nothing more
than changing a template or script. No restart of the server, no reload
of the browser, just streaming updates.

## Implementation

Streamer is an asset compiler that builds CSS and JS from source
languages and template systems and delivers them as compiled assets as
server side events. You can hook these events and stream them over a
websocket or socket.io.

Contrast this with the compile/combine/deliver mechanism of systems like
Brunch where you are doing a restart and a reload to get code updates.

### Similarities
* Your source assets turn into CSS and JS

### Differences
* There is no mashing/combining of multiple CSS / JS
* Event driven rather than resource/reload driven
* Only changed scripts need be delivered to the UI
* You can deliver live code changes to users without a browser reload

## Methods

## watch


