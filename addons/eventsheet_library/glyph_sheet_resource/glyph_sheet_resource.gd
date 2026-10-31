## @ace_version(1.0.0)
@icon("res://eventsheet_addons/glyph_sheet_resource/icon.svg")
class_name GlyphSheetResource
extends Resource
## Which picture stands for a control, per device: the keyboard, a generic pad, and the three console layouts. The Prompts director draws the right one automatically and the Glyph For row hands it to anything else. It is your file - draw your own buttons into it, rename it, share it.

# @inspector_header Sheet #7c9cf5
# @inspector_info Each device below is a Dictionary of control name to texture: {"ui_accept": the picture of that button}. A control missing from the layout in hand falls back to the generic pad, then to the keyboard.
## Label for this glyph sheet; nothing looks it up by name.
@export var sheet_name: String = ""
# @inspector_header Devices #5fb37a
## Keyboard and mouse pictures by control name; the last fallback.
@export var keyboard: Dictionary = {}
## Generic gamepad pictures, used when a pad matches no layout below.
@export var pad: Dictionary = {}
## The pictures for a pad whose product name reads as this layout (A, B, X, Y). Leave it empty and such a pad uses the generic pad's pictures.
@export var xbox: Dictionary = {}
## Pictures for PlayStation-style pads; empty uses the generic pad.
@export var playstation: Dictionary = {}
## Pictures for Nintendo-style pads; empty uses the generic pad.
@export var nintendo: Dictionary = {}
