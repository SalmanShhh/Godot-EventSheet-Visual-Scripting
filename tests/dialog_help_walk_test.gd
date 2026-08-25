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

## Where the editor's dialogs live, and the call that makes a strip.
const EDITOR_DIR: String = "res://addons/eventsheet/editor"
const STRIP_CALL: String = "EventSheetPopupUI.help_strip("

## The component itself, which of course names the call it defines.
const THE_COMPONENT: String = "res://addons/eventsheet/editor/popup_ui.gd"

## The built specimen of the shape: fields, a strip that follows them, a reading.
const SPECIMEN: String = "res://tools/previews/dialog_shape.gd"

## The ways a dialog can tell its strip to follow something. One of these has to appear beside the
## strip it builds, or the strip is a decoration.
const FOLLOW_CALLS: Array[String] = [".follow(", ".follow_option(", ".show_note(", ".describe("]

## The ways it says what the row will read as. `help_strip(` with arguments counts: the two reading
## lines are its third and fourth.
const READING_CALLS: Array[String] = [".set_reading(", "help_strip(\""]

## The calls that make a dialog. A file may hold more than one (the Message dialog holds the message
## and the send), and each of them is allowed its own strip - never two.
const DIALOG_CALLS: Array[String] = ["ConfirmationDialog.new()", "AcceptDialog.new()"]

## The one dialog with NO reads-as line, and why: the Sheet type dialog's preview IS the head of the
## sheet it is about to write, so a sentence beside it would be the same words twice. Deliberate, and
## therefore written down rather than quietly passing.
const NO_READING_BY_DESIGN: Array[String] = ["sheet_type_dialog.gd"]


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
		"res://addons/eventsheet/editor/dock/compare_condition_dialog.gd",
		"res://addons/eventsheet/editor/dock/message_dialog.gd",
		"res://addons/eventsheet/editor/dock/modes_dialog.gd",
		"res://addons/eventsheet/editor/dock/optimise_dialog.gd",
		"res://addons/eventsheet/editor/dock/quick_prompt_dialogs.gd",
		"res://addons/eventsheet/editor/dock/sheet_type_dialog.gd",
		"res://addons/eventsheet/editor/variable_dialog.gd"
	]))


## ONE strip per dialog. Two would be two places to look, which is the thing the strip replaced -
## so a file is allowed a strip for each dialog it builds, and not one more.
static func _test_one_strip_per_dialog() -> bool:
	var offenders: PackedStringArray = PackedStringArray()
	for path: String in _dialog_paths():
		var source: String = FileAccess.get_file_as_string(path)
		var strips: int = source.count(STRIP_CALL)
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
		if not _mentions_any(source, FOLLOW_CALLS):
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
		if FileAccess.get_file_as_string(path).contains(STRIP_CALL):
			found.append(path)
	for sub_directory: String in dir.get_directories():
		_scan("%s/%s" % [directory, sub_directory], found)


static func _mentions_any(source: String, calls: Array[String]) -> bool:
	for call_text: String in calls:
		if source.contains(call_text):
			return true
	return false


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] dialog_help_walk_test: %s" % label)
		return true
	print("[FAIL] dialog_help_walk_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
