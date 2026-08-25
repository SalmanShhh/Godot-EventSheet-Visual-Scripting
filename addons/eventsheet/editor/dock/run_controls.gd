@tool
class_name EventSheetRunControls
extends RefCounted

# PREVIEW ON THE SHEET. A reader coming from another event-sheet editor reaches for Preview on
# the sheet, not for the editor's own play bar at the top of the window. Three buttons:
#
#   ▶  Preview layout   run the scene this sheet belongs to      (Godot's F6)
#   ▶▶ Preview project  run the project's main scene             (Godot's F5)
#   🐞 Debug layout     the same run, with Event Trace, Live Values and breakpoints armed
#
# The keys are Godot's and the names are the familiar ones, which is the whole shape of the item: it
# adds no way to run anything. Every button hands the run to EditorInterface, and while a game is
# running the first two become Stop / Restart so the strip is never lying about what it will do.

## The buttons, in order, as [id, resting label, tooltip]. Static so a test pins the set without a
## dock behind it, and so Simple mode's beginner toolbar can offer the same three.
const BUTTONS: Array = [
	["preview_layout", "▶ Preview layout",
		"Run the scene this sheet's script is on (F6). The sheet keeps running beside it."],
	["preview_project", "▶▶ Preview project",
		"Run the project's main scene (F5) - the whole game from its start, not just this layout."],
	["debug_layout", "🐞 Debug layout",
		"Run this layout with the sheet's own debugger armed: Event Trace lights the rows as they fire, Live Values streams the variables, and rows with a breakpoint pause the game."],
	["run_profiler", "⏱ Run with profiler",
		"Run this layout with the trace armed and the costs lens on. Play for a while, stop, and every row wears what one fire of it cost - kept until you clear it, and still there when you open the editor tomorrow."],
]

## What the first two buttons say instead while a game is running.
const RUNNING_LABELS: Dictionary = {
	"preview_layout": "■ Stop",
	"preview_project": "↻ Restart",
}

var _dock: Control = null
var _buttons: Dictionary = {}


func init(dock: Control) -> void:
	_dock = dock


## Registers a button so the strip can relabel it when the game starts and stops.
func adopt(button_id: String, button: Button) -> void:
	_buttons[button_id] = button


## The label a button wears right now: its resting name, or what it does while a game is running.
static func label_for(button_id: String, running: bool) -> String:
	if running and RUNNING_LABELS.has(button_id):
		return str(RUNNING_LABELS[button_id])
	for entry: Variant in BUTTONS:
		if str((entry as Array)[0]) == button_id:
			return str((entry as Array)[1])
	return button_id


## Relabels every adopted button for the current run state. Cheap enough to call on a timer or on
## any dock refresh.
func refresh() -> void:
	var running: bool = is_playing()
	for button_id: Variant in _buttons:
		var button: Button = _buttons[button_id]
		if button != null:
			button.text = EventSheetL10n.translate(label_for(str(button_id), running))


func is_playing() -> bool:
	var editor_interface: Object = _editor_interface()
	if editor_interface == null or not editor_interface.has_method("is_playing_scene"):
		return false
	return bool(editor_interface.call("is_playing_scene"))


## One button pressed. While a game runs the first two stop and restart it instead, which is what
## their labels say by then.
func activate(button_id: String) -> void:
	var running: bool = is_playing()
	match button_id:
		"preview_layout":
			if running:
				_stop()
			else:
				_play_current()
		"preview_project":
			if running:
				_stop()
				_play_main()
			else:
				_play_main()
		"debug_layout":
			_arm_debugger()
			if running:
				_stop()
			_play_current()
		"run_profiler":
			# The dock owns this one: arming the trace is the small half, and clearing the old numbers
			# and turning the costs lens on is the half that makes the button mean what it says.
			if _dock != null and _dock.has_method("_run_with_profiler"):
				_dock.call("_run_with_profiler")
	refresh()


## Debug layout is the ordinary run with the sheet's own debugger turned on first - the three
## switches the Tools menu already offers, flipped together so "debug this layout" is one gesture.
func _arm_debugger() -> void:
	var sheet: EventSheetResource = _dock._current_sheet
	if sheet == null:
		return
	# Set the flags rather than calling the toggles: a toggle turns a switch that is already on back
	# OFF, and "Debug layout" must always end with all three armed.
	sheet.emit_event_trace = true
	sheet.emit_live_values = true
	sheet.emit_breakpoints = true
	_dock._set_status("Debug layout: Event Trace, Live Values and breakpoints are on for this run.")


func _play_current() -> void:
	var editor_interface: Object = _editor_interface()
	if editor_interface == null or not editor_interface.has_method("play_current_scene"):
		_dock._set_status("Preview needs the Godot editor - there is nothing to run from here.", true)
		return
	_dock._on_save_requested()
	editor_interface.call("play_current_scene")


func _play_main() -> void:
	var editor_interface: Object = _editor_interface()
	if editor_interface == null or not editor_interface.has_method("play_main_scene"):
		_dock._set_status("Preview needs the Godot editor - there is nothing to run from here.", true)
		return
	_dock._on_save_requested()
	editor_interface.call("play_main_scene")


func _stop() -> void:
	var editor_interface: Object = _editor_interface()
	if editor_interface != null and editor_interface.has_method("stop"):
		editor_interface.call("stop")


static func _editor_interface() -> Object:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return null
	return Engine.get_singleton("EditorInterface")
