# Godot EventSheets — rebindable authoring shortcuts
#
# Godot devs expect editor keys to be rebindable. The Editor-Settings shortcut dialog isn't exposed
# to GDScript plugins, so this is the plugin's own remap layer: every authoring/editing shortcut
# reads its binding from a PER-USER file (user://eventforge_shortcuts.cfg) — local to each developer,
# never committed to git — with DEFAULTS as the fallback. Bindings are "Ctrl+S" / "Q" / "Ctrl+Shift+S"
# (modifiers + one key name). Matching is EXACT on modifiers, so a chord never shadows its plain form
# (Ctrl+Shift+C ≠ Ctrl+C ≠ C). Structural keys (Tab nesting, Delete, Enter/F2 inline edit, Escape)
# stay fixed — they're grammar, not preference. Tools ▸ Keyboard Shortcuts is the editor for these.
@tool
extends RefCounted
class_name EventSheetShortcuts

const OVERRIDES_FILE := "user://eventforge_shortcuts.cfg"

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

## Friendly labels for the Keyboard Shortcuts editor (the action ids are internal).
const LABELS: Dictionary = {
	"add_event": "Add event",
	"add_condition": "Add condition",
	"add_action": "Add action",
	"add_comment": "Add comment",
	"add_group": "Add group",
	"toggle_enabled": "Toggle enabled / disabled",
	"duplicate": "Duplicate event",
	"copy": "Copy rows",
	"paste": "Paste rows",
	"undo": "Undo",
	"redo": "Redo",
	"save": "Save",
	"save_as": "Save as…",
	"open": "Open…",
	"add_event_chord": "Add event (Ctrl alternate)",
	"add_condition_chord": "Add condition (Ctrl alternate)",
	"add_action_chord": "Add action (Ctrl alternate)",
	"add_variable_chord": "Add variable",
}

## Display order for the editor (DEFAULTS key order isn't guaranteed stable).
const ORDER: Array = [
	"add_event", "add_condition", "add_action", "add_comment", "add_group", "toggle_enabled",
	"duplicate", "copy", "paste", "undo", "redo", "save", "save_as", "open",
	"add_event_chord", "add_condition_chord", "add_action_chord", "add_variable_chord",
]

static func label_for(action: String) -> String:
	return str(LABELS.get(action, action.capitalize()))

# Per-user overrides cached in memory — the key handler probes ~18 actions per keystroke, so binding
# lookups must never touch disk. Loaded once; writes update the cache and the file together.
static var _overrides: Dictionary = {}
static var _overrides_loaded: bool = false

static func _load_overrides() -> void:
	if _overrides_loaded:
		return
	_overrides_loaded = true
	# Outside the editor (compile / headless tests) there's no UI to remap from, so skip the file —
	# matching falls back to DEFAULTS and the test suite stays side-effect-free.
	if not Engine.is_editor_hint():
		return
	var config: ConfigFile = ConfigFile.new()
	if config.load(OVERRIDES_FILE) != OK or not config.has_section("shortcuts"):
		return
	for action: String in config.get_section_keys("shortcuts"):
		_overrides[action] = str(config.get_value("shortcuts", action, ""))

static func _save_overrides() -> void:
	if not Engine.is_editor_hint():
		return
	var config: ConfigFile = ConfigFile.new()
	for action: Variant in _overrides:
		config.set_value("shortcuts", str(action), str(_overrides[action]))
	config.save(OVERRIDES_FILE)

static func binding_for(action: String) -> String:
	_load_overrides()
	if _overrides.has(action):
		return str(_overrides[action])
	return str(DEFAULTS.get(action, ""))

## Persist a new binding ("Ctrl+S") for an action. An empty binding clears the shortcut (the action
## stays reachable via any alternate binding / menu). Saves the per-user file in the editor.
static func set_binding(action: String, binding: String) -> void:
	_load_overrides()
	if binding.strip_edges().is_empty():
		_overrides.erase(action)
	else:
		_overrides[action] = binding
	_save_overrides()

## Restore one action to its DEFAULTS binding (clears the per-user override).
static func reset(action: String) -> void:
	_load_overrides()
	_overrides.erase(action)
	_save_overrides()

## Restore every action to its DEFAULTS binding.
static func reset_all() -> void:
	_load_overrides()
	_overrides.clear()
	_save_overrides()

## "Ctrl+Shift+S" → {keycode, ctrl, shift, alt}. "Cmd"/"Meta" count as Ctrl (the dock treats them as
## one modifier, macOS-style).
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

## InputEventKey → "Ctrl+Shift+S" (the format parse()/matches() expect). Returns "" for a modifier-only
## press (Ctrl alone) so the capture UI keeps waiting for a real key.
static func format_event(event: InputEventKey) -> String:
	if event == null or event.keycode in [KEY_NONE, KEY_CTRL, KEY_SHIFT, KEY_ALT, KEY_META]:
		return ""
	var key_name: String = OS.get_keycode_string(event.keycode)
	if key_name.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	if event.ctrl_pressed or event.meta_pressed:
		parts.append("Ctrl")
	if event.shift_pressed:
		parts.append("Shift")
	if event.alt_pressed:
		parts.append("Alt")
	parts.append(key_name)
	return "+".join(parts)

## Another rebindable action that currently resolves to the same chord as `binding` ("" if none), so
## the editor can flag a clash that would make one unreachable (the key handler fires the first match).
static func conflicting_action(action: String, binding: String) -> String:
	if binding.strip_edges().is_empty():
		return ""
	var target: Dictionary = parse(binding)
	if int(target.get("keycode")) == KEY_NONE:
		return ""
	for other: Variant in DEFAULTS:
		if str(other) == action:
			continue
		if parse(binding_for(str(other))) == target:
			return str(other)
	return ""

# Parse memo: the key handler probes up to ~18 actions per keystroke; bindings only change when the
# binding string does, so cache by (action, binding text).
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
