@tool
class_name Batch12BookmarksHelperFixture
extends RefCounted

var _dock: Control = null
var window: Window = null
var tree: Tree = null


func _init(dock: Control) -> void:
	_dock = dock


func build() -> void:
	if window != null:
		return
	window = Window.new()
	window.title = "Bookmarks"
	window.size = Vector2i(400, 340)
	window.close_requested.connect(func() -> void: window.hide())
	var next_button: Button = Button.new()
	next_button.text = "Next"
	next_button.pressed.connect(func() -> void: _cycle(1))


func _cycle(step: int) -> void:
	var sheet: EventSheetResource = _dock._current_sheet
	if sheet == null:
		return
	_dock._select_row(_next_bookmark(sheet, step))


func _next_bookmark(sheet: EventSheetResource, step: int) -> int:
	return step if sheet != null else 0
