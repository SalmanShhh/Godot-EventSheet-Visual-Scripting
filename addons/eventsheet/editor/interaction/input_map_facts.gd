@tool
class_name EventSheetInputMapFacts
extends RefCounted

# R23 - the project's Input Map as an object the sheet can describe.
#
# Every input event a sheet reads is really about ONE thing the sheet could not see until now: the
# project-wide Input Map, a list of named actions with their bindings, their deadzone and the device
# each binding belongs to. To find out what "jump" is you had to leave the sheet and open Project
# Settings. This reads that list, in the sheet's own spelling, so the Object bar, the head bar, the
# row notes and the Doctor can all say it.
#
# The action NAMES come from the `[input]` section of project.godot read as TEXT, which is exactly
# the set a project declares - the engine's own ui_* defaults live in the property list too, and a
# bar led by ui_text_backspace_word would bury the four actions the game is actually about. The
# BINDINGS come back through ProjectSettings, because those are real InputEvent objects and asking
# them what they are beats re-parsing the Object(...) blobs the file stores them as.
#
# Nothing here writes: reading the Input Map must never change it. Adding an action is a separate,
# explicit step (the picker's New action and the Doctor's Add it), which is why `add_action` is the
# only function here that touches the file and why it is never called on a read.
#
# Display-free and static, so a test pins the exact words without a display server.

const PROJECT_FILE := "res://project.godot"

## Which sheet object an action reads on - the device of its first binding, the way the sheet has
## always chosen: keys are the Keyboard's, buttons the Mouse's, sticks the Gamepad's, fingers the
## Touch object's.
const OBJECT_KEYBOARD := "Keyboard"
const OBJECT_MOUSE := "Mouse"
const OBJECT_GAMEPAD := "Gamepad"
const OBJECT_TOUCH := "Touch"

## The Gamepad object's own axis names, by Godot's JoyAxis value. These are the words the Compare
## axis condition and the Gamepad.Axis expression already show, so a lifted row and a picked row say
## exactly the same thing.
const AXIS_WORDS: Dictionary = {
	0: "Left analog X",
	1: "Left analog Y",
	2: "Right analog X",
	3: "Right analog Y",
	4: "Left trigger",
	5: "Right trigger",
}

## The Gamepad object's button names, by Godot's JoyButton value.
const BUTTON_WORDS: Dictionary = {
	0: "A",
	1: "B",
	2: "X",
	3: "Y",
	4: "Back",
	5: "Guide",
	6: "Start",
	7: "Left stick",
	8: "Right stick",
	9: "Left shoulder",
	10: "Right shoulder",
	11: "D-pad up",
	12: "D-pad down",
	13: "D-pad left",
	14: "D-pad right",
}

## Which stick or trigger an axis belongs to, for a binding chip - a stick is one thing to a reader
## even though Godot counts its two axes separately.
const AXIS_GROUP_WORDS: Dictionary = {
	0: "Left stick",
	1: "Left stick",
	2: "Right stick",
	3: "Right stick",
	4: "Left trigger",
	5: "Right trigger",
}

## Godot's own constant order, so a template's `JOY_AXIS_LEFT_X` and a stored `0` are one answer.
const AXIS_CONSTANTS: Array = [
	"JOY_AXIS_LEFT_X", "JOY_AXIS_LEFT_Y", "JOY_AXIS_RIGHT_X", "JOY_AXIS_RIGHT_Y",
	"JOY_AXIS_TRIGGER_LEFT", "JOY_AXIS_TRIGGER_RIGHT"
]

const BUTTON_CONSTANTS: Array = [
	"JOY_BUTTON_A", "JOY_BUTTON_B", "JOY_BUTTON_X", "JOY_BUTTON_Y", "JOY_BUTTON_BACK",
	"JOY_BUTTON_GUIDE", "JOY_BUTTON_START", "JOY_BUTTON_LEFT_STICK", "JOY_BUTTON_RIGHT_STICK",
	"JOY_BUTTON_LEFT_SHOULDER", "JOY_BUTTON_RIGHT_SHOULDER", "JOY_BUTTON_DPAD_UP",
	"JOY_BUTTON_DPAD_DOWN", "JOY_BUTTON_DPAD_LEFT", "JOY_BUTTON_DPAD_RIGHT"
]

const MOUSE_BUTTON_WORDS: Dictionary = {
	1: "Left mouse button",
	2: "Right mouse button",
	3: "Middle mouse button",
	4: "Mouse wheel up",
	5: "Mouse wheel down",
}

## The per-player naming conventions a local-multiplayer project uses: `p2_jump` and `jump_2` are
## both "jump on gamepad 1". Recognising them is what lets those actions group under their gamepad
## instead of reading as four unrelated names.
const PLAYER_PREFIX := "p"
const PLAYER_SUFFIX := "_"

static var _cache: Dictionary = {}
## The quoted-name matcher, compiled once (see action_names_in). Not part of _cache: it never
## goes stale, so clear_cache() must not drop it.
static var _literal_regex: RegEx = null


## Drops the cached read of project.godot. The editor calls this when the filesystem changes; tests
## call it between fixtures so one project's actions cannot answer for the next one's.
static func clear_cache() -> void:
	_cache.clear()


## Every action the PROJECT declares, in the order project.godot lists them. The engine's ui_*
## defaults are not here unless the project overrode one (in which case the file says so).
static func project_action_names() -> PackedStringArray:
	if _cache.has("names"):
		return _cache["names"]
	var names: PackedStringArray = _parse_action_names(_read_project_file())
	_cache["names"] = names
	return names


## Everything the bar, the head and the row notes need about one action:
##   {"name", "deadzone": float, "bindings": PackedStringArray, "object": String,
##    "devices": PackedStringArray, "gamepad": int}
## An empty Dictionary when the project has no such action - which is the ⚠ on the row.
static func action(action_name: String) -> Dictionary:
	var clean: String = action_name.strip_edges()
	if clean.is_empty():
		return {}
	var by_name: Dictionary = _actions_by_name()
	if by_name.has(clean):
		return (by_name[clean] as Dictionary).duplicate(true)
	# An engine default the project never overrode (`ui_accept`, `ui_cancel`) is not in the file's
	# `[input]` section, but it IS a control the game has - so a row that names one is right, and
	# flagging it would be the bar crying wolf about the actions Godot ships with.
	var setting: Variant = ProjectSettings.get_setting("input/%s" % clean, null)
	return _describe(clean, setting as Dictionary) if setting is Dictionary else {}


## Every project action as `action()` describes it, in the file's order.
static func actions() -> Array[Dictionary]:
	var listed: Array[Dictionary] = []
	var by_name: Dictionary = _actions_by_name()
	for action_name: String in project_action_names():
		if by_name.has(action_name):
			listed.append((by_name[action_name] as Dictionary).duplicate(true))
	return listed


## True when the project's Input Map has this action. The one question a row that names an action
## needs answered, and the whole of the ⚠ check.
static func has_action(action_name: String) -> bool:
	return not action(action_name).is_empty()


## One action's bindings as the muted chip the bar and the row note show: `Space · A button · Up`.
## "" when the action is unbound (which the bar says with the word "unbound" instead).
static func bindings_line(action_name: String) -> String:
	var facts: Dictionary = action(action_name)
	if facts.is_empty():
		return ""
	var bindings: PackedStringArray = facts.get("bindings", PackedStringArray())
	return " · ".join(bindings)


## The action's own deadzone from the Input Map, as the Gamepad object shows its Analog deadzone
## property: a percent. "" for an action the project does not have.
static func deadzone_percent(action_name: String) -> String:
	var facts: Dictionary = action(action_name)
	if facts.is_empty():
		return ""
	return "%d%%" % int(round(float(facts.get("deadzone", 0.0)) * 100.0))


## Which sheet object an action's rows read on.
static func object_of(action_name: String) -> String:
	var facts: Dictionary = action(action_name)
	return str(facts.get("object", OBJECT_KEYBOARD)) if not facts.is_empty() else OBJECT_KEYBOARD


## The gamepad number a per-player action belongs to, or -1 when the name carries no convention.
## `p2_jump` and `jump_2` are both gamepad 1, because the sheet counts gamepads from 0 and players
## from 1 - player 2 holds the second pad.
static func gamepad_number_of(action_name: String) -> int:
	var clean: String = action_name.strip_edges()
	var underscore: int = clean.find(PLAYER_SUFFIX)
	if underscore > 1 and clean.begins_with(PLAYER_PREFIX):
		var head: String = clean.substr(1, underscore - 1)
		if head.is_valid_int() and int(head) >= 1:
			return int(head) - 1
	var last: int = clean.rfind(PLAYER_SUFFIX)
	if last > 0 and last < clean.length() - 1:
		var tail: String = clean.substr(last + 1)
		if tail.is_valid_int() and int(tail) >= 1:
			return int(tail) - 1
	return -1


## The action's name with its per-player convention taken off - what the row actually says. `p2_jump`
## and `jump_2` both read as `jump`, because the gamepad number is already in the sentence.
static func base_action_words(action_name: String) -> String:
	var clean: String = action_name.strip_edges()
	if gamepad_number_of(clean) < 0:
		return clean
	var underscore: int = clean.find(PLAYER_SUFFIX)
	if underscore > 1 and clean.begins_with(PLAYER_PREFIX) and clean.substr(1, underscore - 1).is_valid_int():
		return clean.substr(underscore + 1)
	return clean.substr(0, clean.rfind(PLAYER_SUFFIX))


## The Gamepad object's word for one axis, by Godot's JoyAxis value or its constant name.
static func axis_words(axis: Variant) -> String:
	var index: int = _joy_constant_value(axis, "JOY_AXIS_")
	return str(AXIS_WORDS.get(index, "")) if AXIS_WORDS.has(index) else str(axis)


## The Gamepad object's word for one button, by Godot's JoyButton value or its constant name.
static func button_words(button: Variant) -> String:
	var index: int = _joy_constant_value(button, "JOY_BUTTON_")
	return str(BUTTON_WORDS.get(index, "")) if BUTTON_WORDS.has(index) else str(button)


## One binding as the sheet spells it: a key by the name Godot prints for it, a gamepad button or
## stick by the Gamepad object's word, a mouse button by the Mouse object's.
static func binding_words(event: InputEvent) -> String:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		# Godot tags a physical binding "Space - Physical" so the Input Map screen can tell the two
		# apart. On a chip that says which key it is, the tag is noise about how the binding is stored.
		var text: String = key_event.as_text().trim_suffix(" - Physical").trim_suffix(" (Physical)")
		return text if not text.is_empty() else "?"
	if event is InputEventMouseButton:
		var button: int = int((event as InputEventMouseButton).button_index)
		return str(MOUSE_BUTTON_WORDS.get(button, "Mouse button %d" % button))
	if event is InputEventJoypadButton:
		var joy_button: int = int((event as InputEventJoypadButton).button_index)
		return "%s button" % str(BUTTON_WORDS.get(joy_button, str(joy_button)))
	if event is InputEventJoypadMotion:
		var axis: int = int((event as InputEventJoypadMotion).axis)
		return str(AXIS_GROUP_WORDS.get(axis, str(AXIS_WORDS.get(axis, str(axis)))))
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return "Touch"
	return "?"


## Which object a single binding belongs to.
static func binding_object(event: InputEvent) -> String:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		return OBJECT_MOUSE
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return OBJECT_GAMEPAD
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return OBJECT_TOUCH
	return OBJECT_KEYBOARD


## Every Input Map action THIS sheet names, in the order it first names them, as
##   {"name", "known": bool, "deadzone", "bindings", "devices", "object", "gamepad"}
## An entry with `known` false is an action the script asks for that the project does not have - the
## typo every beginner makes, and the whole of the ⚠ on the row and the Doctor's finding.
static func actions_named_by(sheet: EventSheetResource) -> Array[Dictionary]:
	var named: Array[Dictionary] = []
	var seen: Dictionary = {}
	for action_name: String in action_names_in(EventSheetViewportReadingRows.sheet_code_text(sheet)):
		if seen.has(action_name):
			continue
		seen[action_name] = true
		var facts: Dictionary = action(action_name)
		if facts.is_empty():
			named.append({
				"name": action_name, "known": false, "deadzone": 0.0,
				"bindings": PackedStringArray(), "devices": PackedStringArray(),
				"object": OBJECT_KEYBOARD, "gamepad": gamepad_number_of(action_name),
			})
			continue
		facts["known"] = true
		named.append(facts)
	return named


## The action names a block of GDScript asks for, in the order they appear. A name is only taken from
## a line that is ALREADY about input - `Input.`, `InputMap.` or an `is_action…` call - so an ordinary
## string a script happens to carry can never be mistaken for a control.
static func action_names_in(code: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	# Compiled once: this runs over the whole sheet's code on every rebuild of the head bars, and
	# once per script in the Doctor's sweep.
	if _literal_regex == null:
		_literal_regex = RegEx.new()
		_literal_regex.compile("&?\"([^\"]+)\"")
	var literal: RegEx = _literal_regex
	for line: String in code.split("\n"):
		if not (line.contains("Input.") or line.contains("InputMap.") or line.contains("is_action")
				or line.contains(".is_action(")):
			continue
		for found_match: RegExMatch in literal.search_all(line):
			var candidate: String = found_match.get_string(1)
			# A path is never a control, and neither is an empty name.
			if candidate.is_empty() or candidate.contains("/") or candidate.contains(":"):
				continue
			if not found.has(candidate):
				found.append(candidate)
	return found


## Adds an action to the project's Input Map and saves project.godot - the one write in this file,
## behind the picker's New action and the Doctor's Add it. Returns false when the action is already
## there or the name is empty, so a caller never reports having added what it did not.
static func add_action(action_name: String, deadzone: float = 0.5) -> bool:
	var clean: String = action_name.strip_edges()
	if clean.is_empty() or ProjectSettings.has_setting("input/%s" % clean):
		return false
	ProjectSettings.set_setting("input/%s" % clean, {"deadzone": deadzone, "events": []})
	ProjectSettings.set_initial_value("input/%s" % clean, {"deadzone": deadzone, "events": []})
	var saved: int = ProjectSettings.save()
	clear_cache()
	return saved == OK


# ── Reading project.godot ─────────────────────────────────────────────────────────────────────


static func _read_project_file() -> String:
	var file: FileAccess = FileAccess.open(PROJECT_FILE, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


## The names in the `[input]` section, at column zero and followed by `=`. Platform overrides
## (`ui_close_dialog.macos`) are the same action said twice, so only the plain name is listed.
static func _parse_action_names(project_text: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var in_section: bool = false
	for line: String in project_text.split("\n"):
		if line.begins_with("["):
			in_section = line.strip_edges() == "[input]"
			continue
		if not in_section:
			continue
		var equals: int = line.find("=")
		if equals <= 0 or line.begins_with(" ") or line.begins_with("\t") or line.begins_with("\""):
			continue
		var name_part: String = line.substr(0, equals).strip_edges()
		if name_part.is_empty() or name_part.contains(" "):
			continue
		if name_part.contains("."):
			name_part = name_part.get_slice(".", 0)
		if not names.has(name_part):
			names.append(name_part)
	return names


static func _actions_by_name() -> Dictionary:
	if _cache.has("by_name"):
		return _cache["by_name"]
	var by_name: Dictionary = {}
	for action_name: String in project_action_names():
		var setting: Variant = ProjectSettings.get_setting("input/%s" % action_name, null)
		if not (setting is Dictionary):
			continue
		by_name[action_name] = _describe(action_name, setting as Dictionary)
	_cache["by_name"] = by_name
	return by_name


static func _describe(action_name: String, setting: Dictionary) -> Dictionary:
	var bindings: PackedStringArray = PackedStringArray()
	var devices: PackedStringArray = PackedStringArray()
	for entry: Variant in setting.get("events", []):
		if not (entry is InputEvent):
			continue
		var words: String = binding_words(entry as InputEvent)
		if not bindings.has(words):
			bindings.append(words)
		var owner_object: String = binding_object(entry as InputEvent)
		if not devices.has(owner_object):
			devices.append(owner_object)
	return {
		"name": action_name,
		"deadzone": float(setting.get("deadzone", 0.5)),
		"bindings": bindings,
		"devices": devices,
		"object": devices[0] if not devices.is_empty() else OBJECT_KEYBOARD,
		"gamepad": gamepad_number_of(action_name),
	}


## A JoyAxis / JoyButton written either as the number Godot stores or as the constant a codegen
## template carries (`JOY_AXIS_LEFT_X`), as its number. -1 when it is neither.
static func _joy_constant_value(value: Variant, prefix: String) -> int:
	if value is int or value is float:
		return int(value)
	var text: String = str(value).strip_edges()
	if text.is_valid_int():
		return int(text)
	if not text.begins_with(prefix):
		return -1
	var names: Array = AXIS_CONSTANTS if prefix == "JOY_AXIS_" else BUTTON_CONSTANTS
	return names.find(text)
