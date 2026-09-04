## @ace_version(1.0.0)
@icon("res://eventsheet_addons/glyph_sheet_resource/icon.svg")
class_name GlyphSheetResource
extends Resource
## Which picture stands for a control, per device: the keyboard, a generic pad, and the three console layouts. The Prompts director draws the right one automatically and the Glyph For row hands it to anything else. It is your file - draw your own buttons into it, rename it, share it.

# @inspector_header Sheet #7c9cf5
# @inspector_info Each device below is a Dictionary of control name to texture: {"ui_accept": the picture of that button}. A control missing from the layout in hand falls back to the generic pad, then to the keyboard.
## What this sheet is called, for your own sake when a project holds more than one - a plain set and a large-print set, say. Nothing looks a sheet up by this name; it is a label.
@export var sheet_name: String = ""
# @inspector_header Devices #5fb37a
## The keyboard and mouse pictures, by control name: {"ui_accept": the Enter key picture}. This is the last fallback, so a control drawn only here still shows something on every device.
@export var keyboard: Dictionary = {}
## The generic gamepad pictures, for a pad whose product name matches none of the three layouts below - and the fallback for a control one of them has not drawn.
@export var pad: Dictionary = {}
## The pictures for a pad whose product name reads as this layout (A, B, X, Y). Leave it empty and such a pad uses the generic pad's pictures.
@export var xbox: Dictionary = {}
## The pictures for a pad whose product name reads as this layout (cross, circle, square, triangle). Leave it empty and such a pad uses the generic pad's pictures.
@export var playstation: Dictionary = {}
## The pictures for a pad whose product name reads as this layout (B, A, Y, X - the east-west pair swapped). Leave it empty and such a pad uses the generic pad's pictures.
@export var nintendo: Dictionary = {}
