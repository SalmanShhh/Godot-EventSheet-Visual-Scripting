# Godot EventSheets - the Lift Workbench over a mixed buffer (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The buffer is chosen to show all three claims at once rather than a happy path: a send spelling a
# lift-table entry claims by name, ordinary statements that arrive as rows without one, and a lambda
# that stays honest code - with the draft door already live on the first line nothing claims. The
# red half of the third pane has its own picture beside this one (lift_workbench_diff.gd).
@tool
extends RefCounted

const PREVIEW_NAME: String = "lift-workbench"
const PREVIEW_SIZE: Vector2i = Vector2i(1180, 760)

const BUFFER: String = """extends Node

var lives: int = 3


func _ready() -> void:
	rpc("player_joined", name)
	lives = 3
	var timer: Timer = Timer.new()
	timer.timeout.connect(func() -> void:
		lives -= 1
	)
	add_child(timer)
"""


static func build(host: Window) -> Node:
	var bench: EventSheetLiftWorkbench = EventSheetLiftWorkbench.new()
	bench.init(null)
	var window: Window = bench.build_window()
	host.add_child(window)
	bench.set_buffer(BUFFER)
	window.popup_centered(PREVIEW_SIZE - Vector2i(60, 60))
	return window
