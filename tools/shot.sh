#!/bin/bash
# usage: tools/shot.sh out.png [user args...]
G=${GODOT:-godot}   # set GODOT to your Godot 4.5 binary if it is not on PATH
OUT=$1; shift
cd "$(dirname "$0")/.."
timeout 180 xvfb-run -a -s "-screen 0 720x1280x24" $G --path . --rendering-driver opengl3 --resolution 720x1280 -- --shot=$OUT "$@" 2>&1 | grep -E "SCRIPT ERROR|ERROR: .*res://|Parse Error|at: " | grep -v ALSA | head -20
