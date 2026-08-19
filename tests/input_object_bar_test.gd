# R23 - the Input Map in the Object bar: the INPUT section, the words each control's line carries,
# and the ⚠ on one the project does not have.
#
# Every check pins a VALUE, because the point of the section is what it SAYS.
@tool
class_name InputObjectBarTest
extends RefCounted


static func run() -> bool:
	var passed: bool = true
	passed = _check_section_order() and passed
	passed = _check_entry_words() and passed
	passed = _check_named_actions() and passed
	return passed


## The INPUT section sits between the scene and the globals: the controls a reader is looking at are
## nearer to hand than the families they rarely touch.
static func _check_section_order() -> bool:
	var sections: Array = EventSheetObjectsPanel.sections_for([], [], "", [])
	var ids: PackedStringArray = PackedStringArray()
	for entry: Variant in sections:
		ids.append(str((entry as Dictionary).get("id", "")))
	var passed: bool = _pin("the bar's sections, in order", ", ".join(ids), "used, scene, input, globals")
	var input_section: Dictionary = sections[2]
	passed = _pin("the section header says what dragging one does",
		EventSheetObjectsPanel.section_line(input_section, 4),
		"INPUT  (4) - drag one onto the sheet to start an event") and passed
	return passed


## One control's line: its name, then what it is bound to.
static func _check_entry_words() -> bool:
	var entries: Array = EventSheetObjectsPanel.input_entries([
		{"name": "jump", "known": true, "bindings": PackedStringArray(["Space", "A button", "Up"]),
			"object": "Keyboard"},
		{"name": "fire", "known": true, "bindings": PackedStringArray(["Left mouse button", "Right trigger"]),
			"object": "Mouse"},
		{"name": "sneak", "known": true, "bindings": PackedStringArray(), "object": "Keyboard"},
		{"name": "dash", "known": false, "bindings": PackedStringArray(), "object": "Keyboard"},
	])
	var passed: bool = _pin("a bound control shows what it is bound to",
		EventSheetObjectsPanel.entry_text(entries[0]), "jump  Space · A button · Up")
	passed = _pin("a control on the mouse reads the same way",
		EventSheetObjectsPanel.entry_text(entries[1]),
		"fire  Left mouse button · Right trigger") and passed
	passed = _pin("a control with no binding says so",
		EventSheetObjectsPanel.entry_text(entries[2]), "sneak  unbound") and passed
	passed = _pin("a control the project does not have says THAT",
		EventSheetObjectsPanel.entry_text(entries[3]), "dash  not in the Input Map") and passed
	passed = _pin("an unknown control is flagged, not quietly listed",
		str(entries[3].get("known", true)), "false") and passed
	passed = _pin("a control's line is filtered on its bindings too",
		str(EventSheetObjectsPanel.matches_filter(entries[0], "a button")), "true") and passed
	return passed


## Which controls a block of code asks for - the census the bar, the head bar and the Doctor all read.
static func _check_named_actions() -> bool:
	var source: String = "\n".join([
		"func _physics_process(delta):",
		"\tif Input.is_action_just_pressed(\"jump\"):",
		"\t\tvelocity.y = -420.0",
		"\tvelocity.x = Input.get_axis(&\"move left\", &\"move right\") * 220.0",
		"\tif Input.is_action_pressed(\"dash\"):",
		"\t\tvelocity.x *= 2.0",
		"\tvar label = \"Press jump to start\"",
		"\tsprite.texture = load(\"res://art/hero.png\")",
	])
	var found: PackedStringArray = EventSheetInputMapFacts.action_names_in(source)
	var passed: bool = _pin("the controls a script asks for, in the order it asks",
		", ".join(found), "jump, move left, move right, dash")
	passed = _pin("an ordinary string on a line that is not about input is not a control",
		str(found.has("Press jump to start")), "false") and passed
	passed = _pin("a resource path on an input line is never mistaken for a control",
		str(EventSheetInputMapFacts.action_names_in(
			"Input.set_custom_mouse_cursor(load(\"res://cursor.png\"))").size()), "0") and passed
	return passed


static func _pin(label: String, actual: String, expected: String) -> bool:
	if actual == expected:
		print("[PASS] input_object_bar_test: %s" % label)
		return true
	print("[FAIL] input_object_bar_test: %s -> %s (expected %s)" % [label, actual, expected])
	return false
