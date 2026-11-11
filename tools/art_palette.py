"""Colours shared by the art tools (keep in step with scripts/palette.gd)."""
CARGO = ["#f25565", "#3d8ef5", "#ffc533", "#36c176", "#9364f0", "#ff8b3d", "#ff72b6", "#1fc4c8"]
INK = "#1f3350"
INK_SOFT = "#5f7590"
CREAM = "#fffaf0"
SKY_TOP = "#63bdf7"
SKY_LOW = "#dff4fc"


def rgb(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)
