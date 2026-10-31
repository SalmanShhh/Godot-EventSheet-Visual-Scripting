## @ace_version(1.0.0)
@icon("res://eventsheet_addons/flash/icon.svg")
class_name BlinkPatternResource
extends Resource
## A blink written down as a file: the phases something appears and disappears in, each one "on for this long, off for that long, this many times". Play it with the Flash pack's Blink row. It is your file - rename it, retune it in the Inspector, share it between the hurt flicker and the failing bulb.

# @inspector_header Blink pattern #e8a33d
# @inspector_info One entry in Phases per stretch of the rhythm, in order. A phase is on seconds, off seconds and how many times to repeat that pair before the next phase takes over.
## What this rhythm is called. For your own reading: the Blink row takes the file itself, so a pattern never has to be looked up by name.
@export var pattern_name: String = ""
## Blink rhythm as steps of seconds visible, seconds hidden and repeat count.
@export var phases: Array[Dictionary] = []
