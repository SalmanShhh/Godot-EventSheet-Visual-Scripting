@tool
class_name EventSheetLiveEditBar
extends RefCounted
# The status strip's live-edit offer: ⟳ Apply to running game (V8).
#
# While a game is running and the open sheet has an unapplied edit, this button appears on the
# status strip. Pressing it (or Ctrl+Alt+S) saves the sheet - which writes its script - and asks the
# running game to reload that script, then pulses the rows that changed so the reader sees exactly
# what they just changed land. Whatever instance state the engine keeps across a script reload is
# kept; nothing here promises more than that.
#
# When the change is one a live reload cannot carry - a variable whose TYPE changed, a function that
# was REMOVED and may be running - the strip says so in those words and offers Restart instead. That
# honesty is the whole reason the button is safe to press: it never half-applies.
#
# Nothing appears at all unless a game is running. All the deciding lives in EventSheetLiveEdit
# (static, pure, pinned headless); this file is the shell.

## Where a pending compile goes while the strip works out whether it can be reloaded. Never res://.
const SCRATCH_PATH := "user://eventsheets_live_edit_scratch.gd"

var _dock: Control = null

var button: Button = null
var restart_button: Button = null

## What the sheet's script said the last time it was applied (or opened), so a plan can be made
## against the change actually pending rather than against the file on disk.
var _applied_source: String = ""
var _applied_sheet: EventSheetResource = null
## Re-entry guard: an apply saves, and a save marks dirty, which is where an apply starts.
var _applying: bool = false


func init(dock: Control) -> void:
	_dock = dock


## Adds the two buttons to the status strip, hidden. Built with the strip so no later code has to
## find it again; visibility is the only thing that ever changes.
func build(status_strip: Control) -> void:
	button = Button.new()
	button.name = "EventSheetLiveEditApply"
	button.flat = true
	button.visible = false
	button.pressed.connect(apply)
	status_strip.add_child(button)
	restart_button = Button.new()
	restart_button.name = "EventSheetLiveEditRestart"
	restart_button.text = EventSheetL10n.translate(EventSheetLiveEdit.RESTART_TEXT)
	restart_button.tooltip_text = EventSheetL10n.translate("Stop the game and run it again - the only way to pick this change up.")
	restart_button.flat = true
	restart_button.visible = false
	restart_button.pressed.connect(_restart)
	status_strip.add_child(restart_button)


## Remembers what is currently live, so the next plan compares against it. Called when a sheet is
## opened and after every apply.
func mark_applied() -> void:
	_applied_source = pending_source()
	_applied_sheet = _dock._current_sheet.duplicate(true) if _dock._current_sheet != null else null


## Re-reads the state and re-words the strip. Called on every edit, so the two cheap questions - is
## anything running, is anything unsaved - are asked BEFORE the sheet is compiled to find out what
## would change: with no game running this costs nothing at all.
func refresh() -> void:
	if button == null:
		return
	if _applying or not EventSheetLiveEdit.is_running():
		button.visible = false
		restart_button.visible = false
		return
	if not _dock._dirty:
		# Saved is in step with what is running - that IS the applied state, whether it got there
		# through the ⟳ or through an ordinary Save.
		mark_applied()
		button.visible = false
		restart_button.visible = false
		return
	var plan: Dictionary = EventSheetLiveEdit.plan(_applied_source, pending_source())
	button.visible = true
	button.text = EventSheetL10n.translate(str(plan["message"]))
	button.tooltip_text = EventSheetL10n.translate("Save this sheet and ask the running game to reload it. The rows you changed pulse once so you can see them land.") \
		if bool(plan["can_reload"]) else EventSheetL10n.translate(str(plan["message"]))
	button.disabled = not bool(plan["can_reload"])
	restart_button.visible = bool(plan["offer_restart"])


## Ctrl+Alt+S and the button: save, reload, pulse. Returns what happened, so the shortcut and a test
## read the same answer.
func apply() -> bool:
	if _applying:
		return false
	if not EventSheetLiveEdit.is_running():
		_dock._set_status(EventSheetL10n.translate("Nothing is running - Apply to running game needs a game to apply to."))
		return false
	var before_sheet: EventSheetResource = _applied_sheet
	var plan: Dictionary = EventSheetLiveEdit.plan(_applied_source, pending_source())
	if not bool(plan["can_reload"]):
		_dock._set_status(str(plan["message"]), true)
		return false
	# Saving marks the sheet dirty again on its way through, which would re-enter here through the
	# auto-apply path; one apply is one apply.
	_applying = true
	_dock._on_save_requested()
	_applying = false
	var script_path: String = _script_path()
	if _debugger() != null:
		_debugger().send_reload_scripts(PackedStringArray([script_path]))
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		# The editor's own filesystem notice is what makes Sync Script Changes carry the file into
		# the running game; the message above is the direct ask. Both are the engine's reload.
		EditorInterface.get_resource_filesystem().update_file(script_path)
	var changed: PackedStringArray = EventSheetLiveEdit.changed_event_uids(before_sheet, _dock._current_sheet)
	_pulse(changed)
	mark_applied()
	refresh()
	_dock._set_status(EventSheetLiveEdit.applied_text(changed.size()))
	return true


func _debugger() -> EventSheetLiveValuesDebugger:
	return _dock._ensure_live_values_panel().debugger as EventSheetLiveValuesDebugger


## The pulse: the changed rows flash once on the canvas, through the same channel the Event Trace
## uses, so a reader watching the trace sees the change land where the firing does.
func _pulse(uids: PackedStringArray) -> void:
	if uids.is_empty():
		return
	for pane: EventSheetViewport in [_dock._viewport, _dock._multi_view._split_viewport, _dock._detached_viewport]:
		if pane != null:
			pane.set_fired_events(uids)


func _restart() -> void:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return
	EditorInterface.stop_playing_scene()
	_dock._run_from_sheet()


## What the open sheet WOULD be if it were saved right now. The comparison has to be against the
## pending edit, not against the file on disk - the file on disk is still what is running, which is
## exactly the other side of the comparison. Compiled to a user:// scratch and removed again: the
## live-edit offer never writes inside res:// until you press it.
func pending_source() -> String:
	if _dock._current_sheet == null:
		return ""
	var result: Dictionary = SheetCompiler.compile(_dock._current_sheet, SCRATCH_PATH)
	DirAccess.remove_absolute(SCRATCH_PATH)
	return str(result.get("output", ""))


func _script_path() -> String:
	return str(_dock._current_sheet_path)
