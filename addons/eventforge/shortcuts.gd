# Godot EventSheets — rebindable authoring shortcuts
#
# Godot devs expect editor keys to be rebindable. The Editor-Settings shortcut
# dialog isn't exposed to GDScript plugins, so this is the rebindable-the-Godot-way
# alternative: every authoring/editing shortcut reads its binding from
# eventsheets/editor/shortcuts/<action> in Project Settings ("Ctrl+D", "Q",
# "Ctrl+Shift+S" — modifiers + one key name). Matching is EXACT on modifiers, so a
# chord can never shadow its plain form (Ctrl+Shift+C ≠ Ctrl+C ≠ C). Structural keys
# (Tab nesting, Delete, Enter/F2 inline edit, Escape) stay fixed — they're grammar,
# not preference.
@tool
extends RefCounted
class_name EventSheetShortcuts

const SETTING_PREFIX := "eventsheets/editor/shortcuts/"

const DEFAULTS: Dictionary = {
	"add_comment": "Q",
	"add_event": "E",
	"add_condition": "C",
	"add_action": "A",
	"add_group": "G",
	"toggle_enabled": "X",
	"save": "Ctrl+S",
	"save_as": "Ctrl+Shift+S",
	"open": "Ctrl+O",
	"copy": "Ctrl+C",
	"paste": "Ctrl+V",
	"duplicate": "Ctrl+D",
	"undo": "Ctrl+Z",
	"redo": "Ctrl+Shift+Z",
	"add_event_chord": "Ctrl+E",
	"add_condition_chord": "Ctrl+Shift+C",
	"add_action_chord": "Ctrl+Shift+A",
	"add_variable_chord": "Ctrl+Shift+V",
}

static func binding_for(action: String) -> String:
	return str(ProjectSettings.get_setting(SETTING_PREFIX + action, DEFAULTS.get(action, "")))

## "Ctrl+Shift+S" → {keycode, ctrl, shift, alt}. "Cmd"/"Meta" count as Ctrl
## (the dock treats them as one modifier, macOS-style).
static func parse(binding: String) -> Dictionary:
	var parsed: Dictionary = {"keycode": KEY_NONE, "ctrl": false, "shift": false, "alt": false}
	for part: String in binding.split("+"):
		var token: String = part.strip_edges()
		match token.to_lower():
			"ctrl", "cmd", "meta":
				parsed["ctrl"] = true
			"shift":
				parsed["shift"] = true
			"alt":
				parsed["alt"] = true
			_:
				parsed["keycode"] = OS.find_keycode_from_string(token)
	return parsed

# Parse memo: the key handler probes up to ~18 actions per keystroke; bindings only
# change when the setting string does, so cache by (action, binding text).
static var _parse_cache: Dictionary = {}

static func matches(event: InputEventKey, action: String) -> bool:
	var binding: String = binding_for(action)
	var cached: Variant = _parse_cache.get(action)
	if not (cached is Dictionary) or str((cached as Dictionary).get("binding")) != binding:
		cached = {"binding": binding, "parsed": parse(binding)}
		_parse_cache[action] = cached
	var parsed: Dictionary = (cached as Dictionary).get("parsed")
	return event.keycode == int(parsed.get("keycode")) \
		and (event.ctrl_pressed or event.meta_pressed) == bool(parsed.get("ctrl")) \
		and event.shift_pressed == bool(parsed.get("shift")) \
		and event.alt_pressed == bool(parsed.get("alt"))
