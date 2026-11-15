# EventForge - the window that lists what a script of yours gives sheets.
#
# Each member of the script is a sentence with a tick: unticking writes `## @ace_hidden` above it, and
# a member the script already leaves out is listed too, so ticking it again brings it back with every
# other word the script had written. Only the ticks that differ from the file are written.
#
# The untyped fixture is the case that justifies the scan: `func is_wave_active():` with no return
# type can only read as an Action, and the fix is an annotation rather than an edit to the user's
# signature.
@tool
class_name ProviderCurateTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const WINDOW_PATH := "res://addons/eventsheet/editor/dock/script_rows_window.gd"
const UNTYPED := "res://tests/fixtures/untyped_provider_fixture.gd"
const SCRATCH := "user://script_rows_window_scratch.gd"


static func run() -> bool:
	var ok: bool = true
	var dock: EventSheetDock = EventSheetDock.new()
	var window: RefCounted = load(WINDOW_PATH).new()
	window.open(dock, UNTYPED)
	# Worth pinning literally: ONE numeric `@export` publishes four rows (read, set, add, subtract),
	# and all four share a single `var` - so all four share one annotation block.
	ok = _check("the window lists every row the script publishes", _members(window), [
		"signal:wave_started", "property:difficulty", "set:difficulty", "add:difficulty",
		"subtract:difficulty", "method:start_wave", "method:is_wave_active"]) and ok
	ok = _check("an untouched window has nothing to write", window.collect_edits(), []) and ok
	var is_active: TreeItem = _row_for(window, "is_wave_active")
	ok = _check("the untyped method reads as an Action", is_active.get_text(2), "Action") and ok
	_row_for(window, "difficulty").set_checked(0, false)
	var edits: Array = window.collect_edits()
	ok = _check("unticking a row writes an opt-out for its member", edits.size() > 0 and bool((edits[0] as Dictionary).get("hidden", false)), true) and ok
	ok = _check("and for that member only", (edits[0] as Dictionary).get("member", ""), "difficulty") and ok
	ok = _check("the fixture on disk is untouched",
		FileAccess.get_file_as_string(UNTYPED).contains("@ace_"), false) and ok

	# Done writes a script of yours, and ticking a left-out member again brings back what it carried.
	var source: String = "extends Node\n\n\n## @ace_name(\"Go Now\")\nfunc go() -> void:\n\tpass\n"
	var handle: FileAccess = FileAccess.open(SCRATCH, FileAccess.WRITE)
	handle.store_string(source)
	handle.close()
	var written: Dictionary = EventSheets.curate_provider(SCRATCH, [{"source_kind": "method", "member": "go", "hidden": true}])
	var hidden_text: String = FileAccess.get_file_as_string(SCRATCH)
	var back: Dictionary = EventSheets.curate_provider(SCRATCH, [{"source_kind": "method", "member": "go", "hidden": false}])
	var shown_text: String = FileAccess.get_file_as_string(SCRATCH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	ok = SUPPORT.pins("provider_curate_test", [
		["hiding a member keeps the words it already carried", [str(written.get("ok", "")), hidden_text.contains("@ace_hidden"), hidden_text.contains("@ace_name(\"Go Now\")")], ["true", true, true]],
		["showing it again removes only the opt-out", [str(back.get("ok", "")), shown_text.contains("@ace_hidden"), shown_text.contains("@ace_name(\"Go Now\")")], ["true", false, true]],
	]) and ok

	# Keep old events working: the button waits for the name it forwards from, and the exact
	# stand-in it would add is shown before anything is written.
	var shim: ConfirmationDialog = dock._providers_glue.open_shim_question("res://tests/fixtures/typed_provider_fixture.gd", "start_wave")
	var add_shim: Button = shim.get_ok_button()
	var old_name: LineEdit = shim.find_children("*", "LineEdit", true, false).back() as LineEdit
	old_name.text_changed.emit("   ")
	var blank_disabled: bool = add_shim.disabled
	var blank_code: bool = (shim.find_child("Code", true, false) as Control).visible
	old_name.text_changed.emit("old_start_wave")
	var code: String = (shim.find_child("Code", true, false).find_children("*", "Label", true, false)[0] as Label).text
	ok = SUPPORT.pins("provider_curate_test", [
		["Keep them working is greyed for an empty old name, with no code to show", [blank_disabled, blank_code], [true, false]],
		["and live once one is typed", add_shim.disabled, false],
		["the code it adds is shown first", code,
			"## @ace_deprecated(\"Renamed to start_wave.\", \"method:start_wave\")\nfunc old_start_wave(index: int) -> void:\n\tstart_wave(index)"],
	]) and ok
	window.window().free()
	dock.free()
	return ok


## Every row's ace_id, in table order - more useful than a count when it disagrees.
static func _members(window: RefCounted) -> Array:
	var output: Array = []
	var item: TreeItem = window.tree().get_root().get_first_child()
	while item != null:
		output.append(str((item.get_metadata(0) as Dictionary).get("ace_id", "")))
		item = item.get_next()
	return output


static func _row_for(window: RefCounted, member: String) -> TreeItem:
	var item: TreeItem = window.tree().get_root().get_first_child()
	while item != null:
		var row: Dictionary = item.get_metadata(0) as Dictionary
		if row != null and str(row.get("member", "")) == member:
			return item
		item = item.get_next()
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("provider_curate_test", label, actual, expected)
