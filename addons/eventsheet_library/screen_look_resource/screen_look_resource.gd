## @ace_version(1.0.0)
@icon("res://eventsheet_addons/screen_look_resource/icon.svg")
class_name ScreenLookResource
extends Resource
## One screen look as a file: which post effects, in which order, how far each goes and what its own dials are set to. Build a look live with Screen FX rows, save it with Save Look, and wear it with Use Look or Blend To Look. It is your file - rename it, edit it in the Inspector, share it.

# @inspector_header Screen Look #7bc96f
# @inspector_info One entry in Rows per post effect, in the order they are drawn: the first is applied to the screen first and the last one has the last word.
## What the look answers to. Look Is and Current Look compare this, so two files holding the same name are the same look.
@export var look_name: String = "Clean"
## One entry per effect, in draw order. Each is {"called": a name, "effect": one of the effect words, "strength": 0 to 1, "params": that effect's own dials by uniform name}.
@export var rows: Array[Dictionary] = []
