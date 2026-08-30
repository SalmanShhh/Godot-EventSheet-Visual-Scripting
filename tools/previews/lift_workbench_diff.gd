# Godot EventSheets - the Lift Workbench's red half (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The buffer is the one beside it with its final newline removed, which is a REAL difference rather
# than a staged one: the file ends where the saved one has a line more, and the third pane says so
# with the exact bytes on both sides instead of "they differ".
@tool
extends RefCounted

const PREVIEW_NAME: String = "lift-workbench-diff"
const PREVIEW_SIZE: Vector2i = Vector2i(1180, 760)

## Ends without a newline on purpose: that is the red the third pane is for.
const BUFFER: String = """extends Node

var lives: int = 3


func _ready() -> void:
	rpc("player_joined", name)
	lives = 3
	add_child(Timer.new())"""


static func build(host: Window) -> Node:
	var bench: EventSheetLiftWorkbench = EventSheetLiftWorkbench.new()
	bench.init(null)
	var window: Window = bench.build_window()
	host.add_child(window)
	bench.set_buffer(BUFFER)
	window.popup_centered(PREVIEW_SIZE - Vector2i(60, 60))
	return window
