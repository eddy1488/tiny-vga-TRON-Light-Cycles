<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

The design implements a classic Snake game rendered over VGA (640x480 @ 60Hz). A virtual resolution of 320x240 is used by halving the screen coordinates, and the playfield is divided into an 8x8 pixel grid producing 40 columns by 30 rows. The outer ring of cells forms the wall boundary, leaving a 38x28 playable area.

The snake is stored as a circular buffer of up to 32 segments, each holding a column and row coordinate. On every game tick (once every 8 frames, roughly 7.5 moves per second), the head advances one cell in the current direction and the tail is removed — unless the snake just ate food, in which case the tail stays and the snake grows by one segment. A 16-bit LFSR generates pseudo-random positions for new food after each pickup.

Collision detection runs combinationally: wall collisions check whether the next head position falls on a border cell, and self-collisions use a parallel comparison of the next head position against all 32 segment slots. Unused slots are cleared to coordinate (0,0), which lies on the border and can never match a valid move inside the playable area.

The drawing engine checks every pixel against the snake segments, food, and border using combinational logic. Each cell has 1-pixel inner padding to create a visible grid effect. The head cell includes two white eye pixels, the body is dark green, food is drawn as a red diamond shape, and the border uses a blue checkerboard pattern. On game over the entire snake turns red until the player restarts.

## How to test

Connect a TinyVGA Pmod to the output pins and four active-high pushbuttons to the first four input pins. After reset, the snake begins moving to the right automatically. Press the direction buttons to steer. The snake grows each time it eats the red food diamond. Hitting a wall or the snake's own body triggers game over (the snake turns red). Press any direction button to restart.

## External hardware

- TinyVGA Pmod (active accent on output port for accent 640x480 VGA)
- Four momentary pushbuttons connected to ui[0] (up), ui[1] (down), ui[2] (left), ui[3] (right)
- VGA-compatible monitor or display
