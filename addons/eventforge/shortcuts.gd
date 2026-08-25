# Godot EventSheets - rebindable authoring shortcuts
#
# Godot devs expect editor keys to be rebindable. The Editor-Settings shortcut dialog isn't exposed
# to GDScript plugins, so this is the plugin's own remap layer: every authoring/editing shortcut
# reads its binding from a PER-USER file (user://eventforge_shortcuts.cfg) - local to each developer,
# never committed to git - with DEFAULTS as the fallback. Bindings are "Ctrl+S" / "Q" / "Ctrl+Shift+S"
# (modifiers + one key name). Matching is EXACT on modifiers, so a chord never shadows its plain form
# (Ctrl+Shift+C ≠ Ctrl+C ≠ C). Structural keys (Tab nesting, Delete, Enter/F2 inline edit, Escape)
# stay fixed - they're grammar, not preference. Tools ▸ Keyboard Shortcuts is the editor for these.
@tool
class_name EventSheetShortcuts
extends RefCounted

const OVERRIDES_FILE := "user://eventforge_shortcuts.cfg"

const DEFAULTS: Dictionary = {
	"add_comment": "Q",
	"add_event": "E",
	"add_condition": "C",
	"add_action": "A",
	"add_group": "G",
	# D matches the event-sheet keyboard grammar's toggle-disabled key (was X; rebind via Tools -
	# Keyboard Shortcuts).
	"toggle_enabled": "D",
	"add_blank_subevent": "B",
	# S matches the event-sheet keyboard grammar's add-sub-event key: picker-backed sub-condition
	# under the selection.
	"add_sub_condition": "S",
	# V is the add-GLOBAL-variable key event-sheet authors already have in their fingers - a global
	# belongs to the project, so V works on any sheet at all. The Ctrl+Shift+V chord adds an instance
	# variable, the member of the object this file is.
	"add_variable": "V",
	"invert_condition": "I",
	"replace_ace": "R",
	# F opens the Function dialog: a function is the eighth thing an author adds, and the beginner
	# toolbar names this key on its own button.
	"add_function": "F",
	# Collapse / expand the selected block. Unbound by default - Left / Right already do it and are
	# grammar - but it exists so the "another event-sheet editor" preset can put it on Ctrl+E.
	"toggle_collapse": "",
	# The three Preview gestures. Godot's own run keys, so the sheet's buttons and the editor's
	# play bar never disagree about what F5 means.
	"preview_layout": "F6",
	"preview_project": "F5",
	"debug_layout": "",
	"project_search": "Ctrl+Shift+F",
	# Run an editor tool from its own sheet. Ctrl+Shift+X because X is the "execute" chord every
	# script editor uses, and a tool sheet is the only sheet where "run" means something other than
	# playing the game.
	"run_editor_tool": "Ctrl+Shift+X",
	"history_back": "Alt+Left",
	"history_forward": "Alt+Right",
	# Live edit: save AND ask the running game to reload it. Deliberately a sibling of Save
	# rather than a chord on it - it is a different promise, and it does nothing at all when there
	# is no game running.
	"apply_to_running_game": "Ctrl+Alt+S",
	"save": "Ctrl+S",
	"save_as": "Ctrl+Shift+S",
	"open": "Ctrl+O",
	"copy": "Ctrl+C",
	"paste": "Ctrl+V",
	"duplicate": "Ctrl+D",
	"undo": "Ctrl+Z",
	"redo": "Ctrl+Shift+Z",
	"add_event_chord": "Ctrl+E",
	# Ctrl+Shift+C is Copy as text, the chord every event-sheet editor uses for it; adding a
	# condition keeps its primary key (C) and moved its Ctrl alternate one modifier over.
	"add_condition_chord": "Ctrl+Alt+C",
	"add_action_chord": "Ctrl+Shift+A",
	"add_variable_chord": "Ctrl+Shift+V",
	"copy_as_text": "Ctrl+Shift+C",
}

## Friendly labels for the Keyboard Shortcuts editor (the action ids are internal).
const LABELS: Dictionary = {
	"add_event": "Add event",
	"add_condition": "Add condition",
	"add_action": "Add action",
	"add_comment": "Add comment",
	"add_group": "Group the selection (or add an empty group)",
	"toggle_enabled": "Toggle enabled / disabled",
	"add_blank_subevent": "Add blank sub-event",
	"add_sub_condition": "Add sub-event (picker)",
	"add_variable": "Add global variable",
	"add_function": "Add function",
	"toggle_collapse": "Collapse / expand the selected block",
	"preview_layout": "Preview layout (run this sheet's scene)",
	"preview_project": "Preview project (run the main scene)",
	"debug_layout": "Debug layout (run with the sheet's debugger armed)",
	"invert_condition": "Invert selected condition",
	"project_search": "Search all sheets",
	"run_editor_tool": "Run this editor tool now",
	"replace_ace": "Replace selected trigger / condition / action",
	"history_back": "Jump back (navigation history)",
	"history_forward": "Jump forward (navigation history)",
	"duplicate": "Duplicate event",
	"copy": "Copy rows",
	"paste": "Paste rows",
	"undo": "Undo",
	"redo": "Redo",
	"apply_to_running_game": "Apply to running game",
	"save": "Save",
	"save_as": "Save as…",
	"open": "Open…",
	"add_event_chord": "Add event (Ctrl alternate)",
	"add_condition_chord": "Add condition (Ctrl alternate)",
	"add_action_chord": "Add action (Ctrl alternate)",
	"add_variable_chord": "Add instance variable",
	"copy_as_text": "Copy as text",
}

## Display order for the editor (DEFAULTS key order isn't guaranteed stable).
const ORDER: Array = [
	"add_event", "add_condition", "add_action", "add_comment", "add_group", "toggle_enabled",
	"add_blank_subevent", "add_sub_condition", "add_variable", "add_function", "invert_condition",
	"replace_ace", "toggle_collapse",
	"preview_layout", "preview_project", "debug_layout",
	"project_search", "run_editor_tool", "history_back", "history_forward",
	"duplicate", "copy", "copy_as_text", "paste", "undo", "redo", "save", "save_as", "open",
	"apply_to_running_game",
	"add_event_chord", "add_condition_chord", "add_action_chord", "add_variable_chord",
]


static func label_for(action: String) -> String:
	return str(LABELS.get(action, action.capitalize()))

# ── Presets ─────────────────────────────────────────────────────────────────────────────
#
# Muscle memory is the cheapest thing to honour. The keys are already MOSTLY the same as the ones an
# author coming from another event-sheet editor has in their fingers - E / S / C / A / G / Q / V / B
# all match already - so a preset is a small table of the handful that DIFFER, applied through the
# same per-user override store the Keyboard Shortcuts dialog writes. Nothing is locked: every key in
# a preset stays rebindable afterwards, and "Reset all to defaults" comes back here.
#
# The preset ids are the shipped identity of a preset and are frozen; the tables may grow.

const PRESET_DEFAULT: String = "eventsheets"
const PRESET_ANOTHER_EDITOR: String = "another_editor"

## preset id -> {action: binding}. The default preset is empty: it IS the DEFAULTS table.
const PRESETS: Dictionary = {
	PRESET_DEFAULT: {},
	PRESET_ANOTHER_EDITOR: {
		"invert_condition": "X",
		"toggle_collapse": "Ctrl+E",
		# Ctrl+E is collapse/expand in the other editor, so the Ctrl alternate for "add event" steps
		# aside. E still adds an event, which is the key that matters.
		"add_event_chord": "",
		"preview_layout": "F4",
		"preview_project": "F5",
	},
}

## What the Preset ▾ offers, in menu order.
const PRESET_ORDER: Array = [PRESET_DEFAULT, PRESET_ANOTHER_EDITOR]

const PRESET_LABELS: Dictionary = {
	PRESET_DEFAULT: "Godot EventSheets",
	PRESET_ANOTHER_EDITOR: "Another event-sheet editor",
}


static func preset_label_for(preset_id: String) -> String:
	return str(PRESET_LABELS.get(preset_id, preset_id))


## The bindings a preset asks for. Empty for the default preset - which is the point: the default is
## whatever DEFAULTS says, so a preset never has to be kept in step with it.
static func preset_bindings(preset_id: String) -> Dictionary:
	var table: Variant = PRESETS.get(preset_id, {})
	return (table as Dictionary).duplicate() if table is Dictionary else {}


## Applies a preset: the default one clears every override, any other one resets first and then
## writes only what it changes, so a preset can never leave a stale key from the one before it.
static func apply_preset(preset_id: String) -> void:
	if not PRESETS.has(preset_id):
		return
	reset_all()
	var bindings: Dictionary = preset_bindings(preset_id)
	for action: Variant in bindings:
		set_binding(str(action), str(bindings[action]))


## Which preset the live bindings match - the one whose every entry is in force, or the default when
## none does. Derived rather than trusted, so a hand-rebound key honestly reads as "Godot EventSheets"
## again the moment it stops matching.
static func active_preset() -> String:
	for preset_id: Variant in PRESET_ORDER:
		var bindings: Dictionary = preset_bindings(str(preset_id))
		if bindings.is_empty():
			continue
		var matched: bool = true
		for action: Variant in bindings:
			if binding_for(str(action)) != str(bindings[action]):
				matched = false
				break
		if matched:
			return str(preset_id)
	return PRESET_DEFAULT

# Per-user overrides cached in memory - the key handler probes ~18 actions per keystroke, so binding
# lookups must never touch disk. Loaded once; writes update the cache and the file together.
static var _overrides: Dictionary = {}
static var _overrides_loaded: bool = false


static func _load_overrides() -> void:
	if _overrides_loaded:
		return
	_overrides_loaded = true
	# Outside the editor (compile / headless tests) there's no UI to remap from, so skip the file -
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
	if config.save(OVERRIDES_FILE) != OK:
		push_warning("EventSheets: couldn't save shortcut overrides to %s - the change lasts only this session." % OVERRIDES_FILE)


static func binding_for(action: String) -> String:
	_load_overrides()
	if _overrides.has(action):
		return str(_overrides[action])
	return str(DEFAULTS.get(action, ""))


## Persist a new binding ("Ctrl+S") for an action. An empty binding is an explicit "no key" - the
## action stays reachable from its menu and from any alternate binding, and it is NOT the same as
## resetting (reset() puts the DEFAULTS key back). Recording an empty override rather than erasing it
## is what lets a preset take a key away from one action to give it to another.
static func set_binding(action: String, binding: String) -> void:
	_load_overrides()
	_overrides[action] = binding.strip_edges()
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
