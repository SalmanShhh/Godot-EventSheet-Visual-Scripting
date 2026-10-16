# Godot EventSheets - every dialog explains itself the same way, and something checks that.
#
# The shape is a rule: fields, and ONE help strip at the foot that says what the FOCUSED field is,
# what the row will read as, and what it will be in code. It replaced a hint under every field, and
# it only stays replaced if a gate notices the next dialog that goes back to the old way - or the one
# that builds the strip and then never wires a field to it, which looks right in a screenshot and
# says nothing when you tab through it.
#
# WHAT IS WALKED. Dialogs are found by SCANNING the editor for the one call that makes a strip, so a
# dialog written next month is covered by existing rather than by being added to a list here. Each
# one is read for the three halves of the contract it can be read for (one strip, wired to follow
# something, and a reading set), and the RUNTIME half is probed on a built specimen through
# EventSheetPopupUI.probe_help_dialog - the same probe any test or tool can point at a real dialog.
#
# WHY A SPECIMEN AND NOT THE DIALOGS THEMSELVES: each dialog builds its window lazily, from a dock,
# and building one here would mean faking a dock rather than testing a dialog. The specimen is a
# real, shipped builder of the shape (the preview module that draws it), so the probe runs against
# code somebody looks at rather than against a fixture written to suit the probe.
@tool
class_name DialogHelpWalkTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
## Where the editor's dialogs live, and the calls that make a strip: the strip itself, and a result
## list, which brings its own strip naming the picked result.
const EDITOR_DIR: String = "res://addons/eventsheet/editor"
const STRIP_CALLS: Array[String] = ["EventSheetPopupUI.help_strip(", "EventSheetPopupUI.add_results("]

## The component itself, which of course names the call it defines.
const THE_COMPONENT: String = "res://addons/eventsheet/editor/popup_ui.gd"

## The built specimen of the shape: fields, a strip that follows them, a reading.
const SPECIMEN: String = "res://tools/previews/dialog_shape.gd"

## The ways a dialog can tell its strip to follow something. One of these has to appear beside the
## strip it builds, or the strip is a decoration.
const FOLLOW_CALLS: Array[String] = [".follow(", ".follow_option(", ".follow_form(", ".show_note(", ".describe("]

## The ways it says what the row will read as. `help_strip(` with arguments counts: the two reading
## lines are its third and fourth.
const READING_CALLS: Array[String] = [".set_reading(", "help_strip(\""]

## The calls that make a dialog, the window kit's included. A file may hold more than one (the Message
## dialog holds the message and the send), and each of them is allowed its own strip - never two.
const DIALOG_CALLS: Array[String] = ["ConfirmationDialog.new()", "AcceptDialog.new()", "panel_window(", "action_window("]

## The dialogs with NO reads-as line, and why: the Sheet type dialog's preview IS the head of the
## sheet it is about to write, so a sentence beside it would be the same words twice; the Words page
## draws its live preview and Ask its Proposed card, which are their reading; and the shortcuts window
## and Generate write no row they could name before it exists; and the Theme Editor writes no row at
## all: its strip's two lines are the pointed token (THIS FIELD) and the line it writes into a preset
## (IN FILE). Deliberate, and therefore written down rather than quietly passing.
const NO_READING_BY_DESIGN: Array[String] = ["sheet_type_dialog.gd", "command_palette.gd", "debugger_window.gd",
	"repeated_rows.gd", "event_sheet_shortcuts_dialog.gd", "words_settings_dialog.gd", "ask_window.gd",
	"ai_generate_window.gd", "theme_editor_dialog.gd"]

## The result windows, whose strip describes the PICKED line of a list (a hit, a use, a run) rather
## than a focused field: the selection handler wires it by setting the strip's "This row" line, so
## `.set_line(` counts as following for these files and for no other. The command palette's strip
## is its key legend (Enter, the arrows, the four prefixes), the same whatever is picked, and so
## follows nothing by design; the debugger names a running value and the repeated rows a run that
## spans several rows, so neither has one row to read as (listed above). The Theme Editor's strip
## follows the token row under the pointer the same way, through its two lines, and the Inspector
## Designer's the variable under the pointer.
const RESULT_WINDOWS: Array[String] = ["find_references_panel.gd", "project_find.gd", "repeated_rows.gd",
	"theme_editor_dialog.gd", "inspector_designer_dialog.gd"]
const KEY_LEGEND_BY_DESIGN: Array[String] = ["command_palette.gd"]


static func run() -> bool:
	var ok: bool = true
	ok = _test_dialogs_are_found() and ok
	ok = _test_one_strip_per_dialog() and ok
	ok = _test_every_strip_is_wired() and ok
	ok = _test_the_specimen_behaves() and ok
	ok = _test_the_probe_can_fail() and ok
	return ok


## Discovery, pinned as a value: these are the dialogs that wear the shape today. A new one turns up
## here as a surplus, which is the moment somebody reads the three checks below and decides whether
## it keeps the contract - never a moment that passes unnoticed.
static func _test_dialogs_are_found() -> bool:
	var found: PackedStringArray = _dialog_paths()
	return _check("the dialogs that build a help strip", found, PackedStringArray([
		"res://addons/eventsheet/editor/ace_params_dialog.gd",
		"res://addons/eventsheet/editor/ace_params_node_picker.gd",
		"res://addons/eventsheet/editor/ace_picker.gd",
		"res://addons/eventsheet/editor/add_behavior_dialog.gd",
		"res://addons/eventsheet/editor/chunk_tools_dialog.gd",
		"res://addons/eventsheet/editor/connect_signal_dialog.gd",
		"res://addons/eventsheet/editor/dock/ai_generate_window.gd",
		"res://addons/eventsheet/editor/dock/ask_window.gd",
		"res://addons/eventsheet/editor/dock/author_actions.gd",
		"res://addons/eventsheet/editor/dock/command_palette.gd",
		"res://addons/eventsheet/editor/dock/comment_and_scope_dialogs.gd",
		"res://addons/eventsheet/editor/dock/compare_condition_dialog.gd",
		"res://addons/eventsheet/editor/dock/debugger_window.gd",
		"res://addons/eventsheet/editor/dock/find_references_panel.gd",
		"res://addons/eventsheet/editor/dock/import_sheet_wizard.gd",
		"res://addons/eventsheet/editor/dock/include_manager.gd",
		"res://addons/eventsheet/editor/dock/insert_snippet_dialog.gd",
		"res://addons/eventsheet/editor/dock/message_dialog.gd",
		"res://addons/eventsheet/editor/dock/modes_dialog.gd",
		"res://addons/eventsheet/editor/dock/new_resource_wizard.gd",
		"res://addons/eventsheet/editor/dock/optimise_dialog.gd",
		"res://addons/eventsheet/editor/dock/paste_special_dialog.gd",
		"res://addons/eventsheet/editor/dock/project_find.gd",
		"res://addons/eventsheet/editor/dock/quick_prompt_dialogs.gd",
		"res://addons/eventsheet/editor/dock/rename_receipt.gd",
		"res://addons/eventsheet/editor/dock/repeated_rows.gd",
		"res://addons/eventsheet/editor/dock/sheet_diff.gd",
		"res://addons/eventsheet/editor/dock/sheet_type_dialog.gd",
		"res://addons/eventsheet/editor/dock/start_page.gd",
		"res://addons/eventsheet/editor/dock/states_dialog.gd",
		"res://addons/eventsheet/editor/dock/struct_row_dialogs.gd",
		"res://addons/eventsheet/editor/dock/variable_retype_dialog.gd",
		"res://addons/eventsheet/editor/dock/welcome_window.gd",
		"res://addons/eventsheet/editor/event_sheet_shortcuts_dialog.gd",
		"res://addons/eventsheet/editor/function_dialog.gd",
		"res://addons/eventsheet/editor/inspector_designer_dialog.gd",
		"res://addons/eventsheet/editor/mod_template_dialog.gd",
		"res://addons/eventsheet/editor/new_sheet_dialog.gd",
		"res://addons/eventsheet/editor/param_dialog.gd",
		"res://addons/eventsheet/editor/theme_editor_dialog.gd",
		"res://addons/eventsheet/editor/variable_dialog.gd",
		"res://addons/eventsheet/editor/words_settings_dialog.gd"
	]))


## ONE strip per dialog. Two would be two places to look, which is the thing the strip replaced -
## so a file is allowed a strip for each dialog it builds, and not one more.
static func _test_one_strip_per_dialog() -> bool:
	var offenders: PackedStringArray = PackedStringArray()
	for path: String in _dialog_paths():
		var source: String = FileAccess.get_file_as_string(path)
		var strips: int = 0
		for call_text: String in STRIP_CALLS:
			strips += source.count(call_text)
		var dialogs: int = 0
		for call_text: String in DIALOG_CALLS:
			dialogs += source.count(call_text)
		if strips < 1 or strips > maxi(dialogs, 1):
			offenders.append("%s builds %d strip(s) for %d dialog(s)" % [path.get_file(), strips, dialogs])
	return _check("every dialog builds exactly one help strip", offenders, PackedStringArray())


## A strip nothing is wired to describes the dialog's first state forever. Every dialog has to both
## point its strip at something and set the reading lines, or it is showing an empty foot.
static func _test_every_strip_is_wired() -> bool:
	var unwired: PackedStringArray = PackedStringArray()
	var silent: PackedStringArray = PackedStringArray()
	for path: String in _dialog_paths():
		var source: String = FileAccess.get_file_as_string(path)
		var picks: bool = RESULT_WINDOWS.has(path.get_file()) and source.contains(".set_line(")
		var follows: bool = picks or _mentions_any(source, FOLLOW_CALLS) or KEY_LEGEND_BY_DESIGN.has(path.get_file())
		if not follows:
			unwired.append(path.get_file())
		if not _mentions_any(source, READING_CALLS) and not NO_READING_BY_DESIGN.has(path.get_file()):
			silent.append(path.get_file())
	var ok: bool = _check("every strip is told what to follow", unwired, PackedStringArray())
	return _check("and what the row will read as", silent, PackedStringArray()) and ok


## The runtime half, on the built specimen: one strip, every field wired to it, the description
## CHANGING as focus moves, and both reading lines rendered.
static func _test_the_specimen_behaves() -> bool:
	var host: Window = Window.new()
	var built: Control = load(SPECIMEN).call("build", host)
	var probe: Dictionary = EventSheetPopupUI.probe_help_dialog(built)
	var ok: bool = _check("the specimen holds one strip", int(probe.get("strips", 0)), 1)
	ok = _check("with every field of it wired", probe.get("unwired", PackedStringArray()), PackedStringArray()) and ok
	ok = _check("and every field wired to it", int(probe.get("wired", 0)), int(probe.get("fields", 0))) and ok
	ok = _check("the strip follows focus from field to field", bool(probe.get("follows_focus", false)), true) and ok
	ok = _check("it says what the row reads as", str(probe.get("reads_as", "")),
		"Torch - Fade brightness to 1.2 over 0.4 seconds") and ok
	ok = _check("and what the row is in code", str(probe.get("in_code", "")),
		"create_tween().tween_property($Torch, \"energy\", 1.2, 0.4)") and ok
	host.free()
	return ok


## The probe pointed at the two shapes it exists to refuse: a dialog with a field nothing describes,
## and one whose strip says the same thing whatever is focused.
static func _test_the_probe_can_fail() -> bool:
	var box: VBoxContainer = VBoxContainer.new()
	var first: LineEdit = LineEdit.new()
	first.name = "Unwired"
	var second: LineEdit = LineEdit.new()
	second.name = "Wired"
	box.add_child(first)
	box.add_child(second)
	var strip: EventSheetPopupUI.HelpStrip = EventSheetPopupUI.help_strip()
	strip.follow(second, "Wired", "This one says something.")
	box.add_child(strip)
	var probe: Dictionary = EventSheetPopupUI.probe_help_dialog(box)
	var ok: bool = _check("a field nothing describes is named", probe.get("unwired", PackedStringArray()),
		PackedStringArray(["Unwired"]))
	var same: VBoxContainer = VBoxContainer.new()
	var left: LineEdit = LineEdit.new()
	var right: LineEdit = LineEdit.new()
	same.add_child(left)
	same.add_child(right)
	var one_note: EventSheetPopupUI.HelpStrip = EventSheetPopupUI.help_strip()
	one_note.follow(left, "Fields", "Some fields.")
	one_note.follow(right, "Fields", "Some fields.")
	same.add_child(one_note)
	ok = _check("a strip that says one thing for every field is not following focus",
		bool(EventSheetPopupUI.probe_help_dialog(same).get("follows_focus", true)), false) and ok
	box.free()
	same.free()
	return ok


# ── the walk ────────────────────────────────────────────────────────────────────


## Every editor script that builds a help strip, sorted. Found by reading the source rather than by
## loading it, because a dialog is a RefCounted that wants a dock and this question does not.
static func _dialog_paths() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	_scan(EDITOR_DIR, found)
	found.sort()
	return found


static func _scan(directory: String, found: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		var name: String = file_name.trim_suffix(".remap")
		var path: String = "%s/%s" % [directory, name]
		if not name.ends_with(".gd") or path == THE_COMPONENT:
			continue
		if _mentions_any(FileAccess.get_file_as_string(path), STRIP_CALLS):
			found.append(path)
	for sub_directory: String in dir.get_directories():
		_scan("%s/%s" % [directory, sub_directory], found)


static func _mentions_any(source: String, calls: Array[String]) -> bool:
	for call_text: String in calls:
		if source.contains(call_text):
			return true
	return false


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("dialog_help_walk_test", label, actual, expected)
