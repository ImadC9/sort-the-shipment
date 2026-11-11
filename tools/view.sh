#!/bin/bash
# usage: tools/view.sh out.png WxH [viewer args...]
G=${GODOT:-godot}   # set GODOT to your Godot 4.5 binary if it is not on PATH
OUT=$1; RES=$2; shift 2
cd "$(dirname "$0")/.."
timeout 120 xvfb-run -a -s "-screen 0 ${RES}x24" $G --path . --rendering-driver opengl3 --resolution $RES res://tools/viewer.tscn -- --shot=$OUT "$@" 2>&1 | grep -E "SCRIPT ERROR|at: res" | head
