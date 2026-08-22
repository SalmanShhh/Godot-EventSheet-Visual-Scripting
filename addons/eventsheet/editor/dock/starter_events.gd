@tool
class_name EventSheetStarterEvents
extends RefCounted
# STARTER EVENTS (V13) - the four events you were going to type anyway.
#
# A class knows its common events: a body is created, moves every physics tick, gets hit and dies; a
# button is clicked; a timer times out; an area is collided with; an attached behaviour pack fires
# its own triggers. Object bar ▸ right-click an object ▸ "Add common events…" adds them, each with
# nothing in its action lane yet - the sheet's own "+ Add action" placeholder, ready for the Ghost
# Row.
#
# DERIVED FIRST: every class's own signals ARE its starter events, read straight out of ClassDB, so
# a class nobody listed still offers the right ones. The table below is an OVERRIDE list - the few
# classes whose everyday events are a curated handful rather than "all of them", plus the two
# lifecycle starters no signal list can know about. Nothing here invents a word: a starter's label
# is the one the row will read with.
#
# Pure and static, so the whole mapping is testable without a dock: `starters_for` answers the list,
# `build_event` turns one entry into the EventRow the sheet gets, and the dock does the undo step.

## The lifecycle starters, by their Core trigger ids - what "the object was made" and "every physics
## tick" are called everywhere else in the plugin.
const TRIGGER_CREATED := "OnReady"
const TRIGGER_PHYSICS_TICK := "OnPhysicsProcess"

## The override list. A class here gets EXACTLY these starters instead of its derived signal list;
## everything else derives. Entries are trigger ids: a `signal:<name>` id whose signal the class
## does not declare is a signal the SHEET declares, and applying the starter declares it.
const STARTER_OVERRIDES: Dictionary = {
	"CharacterBody2D": [TRIGGER_CREATED, TRIGGER_PHYSICS_TICK, "signal:hit", "signal:died"],
	"CharacterBody3D": [TRIGGER_CREATED, TRIGGER_PHYSICS_TICK, "signal:hit", "signal:died"],
	"RigidBody2D": [TRIGGER_CREATED, "signal:body_entered"],
	"RigidBody3D": [TRIGGER_CREATED, "signal:body_entered"],
	"Area2D": ["signal:body_entered"],
	"Area3D": ["signal:body_entered"],
	"Button": ["signal:pressed"],
	"CheckBox": ["signal:toggled"],
	"Timer": ["signal:timeout"],
	"AnimationPlayer": ["signal:animation_finished"],
}

## The words a starter reads with where the sheet already has one that no signal name can give.
## Every other label is derived from the trigger itself.
const STARTER_WORDS: Dictionary = {
	"signal:pressed": "On clicked",
	"signal:toggled": "On toggled",
	"signal:timeout": "On timer",
	"signal:body_entered": "On collision with",
	"signal:hit": "On hit",
	"signal:died": "On died",
}

## How many derived signals a class nobody curated offers before the list stops being a starter set
## and becomes a directory.
const DERIVED_LIMIT := 6


## The starter events for one host class, plus a trigger per attached behaviour pack. Entries are
## `{"trigger_provider_id", "trigger_id", "trigger_args", "label", "declares_signal"}` - everything
## the dock needs to build the event and to say what it added.
static func starters_for(host_class: String, pack_triggers: PackedStringArray = PackedStringArray()) -> Array:
	var starters: Array = []
	for trigger_id: String in _override_ids_for(host_class):
		starters.append(entry_for(trigger_id, host_class))
	if starters.is_empty():
		starters.append(entry_for(TRIGGER_CREATED, host_class))
		for trigger_id: String in derived_trigger_ids(host_class):
			starters.append(entry_for(trigger_id, host_class))
	for pack_trigger: String in pack_triggers:
		var clean: String = pack_trigger.strip_edges()
		if clean.is_empty():
			continue
		starters.append(entry_for(clean if clean.contains(":") else "signal:%s" % clean, host_class))
	return starters


## The curated list for the nearest class in `host_class`'s own inheritance chain that has one, so a
## `Player extends CharacterBody2D` gets the body's starters rather than nothing.
static func _override_ids_for(host_class: String) -> PackedStringArray:
	var clean: String = host_class.strip_edges()
	if clean.is_empty():
		return PackedStringArray()
	if STARTER_OVERRIDES.has(clean):
		return PackedStringArray(STARTER_OVERRIDES[clean])
	if not ClassDB.class_exists(clean):
		return PackedStringArray()
	var cursor: String = ClassDB.get_parent_class(clean)
	while not cursor.is_empty():
		if STARTER_OVERRIDES.has(cursor):
			return PackedStringArray(STARTER_OVERRIDES[cursor])
		cursor = ClassDB.get_parent_class(cursor)
	return PackedStringArray()


## A class's own signals, in ClassDB order - the derived starter set for everything nobody curated.
static func derived_trigger_ids(host_class: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var clean: String = host_class.strip_edges()
	if clean.is_empty() or not ClassDB.class_exists(clean):
		return out
	for signal_info: Dictionary in ClassDB.class_get_signal_list(clean, true):
		var signal_name: String = str(signal_info.get("name", "")).strip_edges()
		if signal_name.is_empty():
			continue
		out.append("signal:%s" % signal_name)
		if out.size() >= DERIVED_LIMIT:
			break
	return out


## One starter entry from a trigger id. A `signal:<name>` whose signal the host class already
## declares rides the engine's own trigger; one it does not is a signal this sheet declares, and
## `declares_signal` names it so applying the starter declares it too.
static func entry_for(trigger_id: String, host_class: String = "") -> Dictionary:
	var clean: String = trigger_id.strip_edges()
	var entry: Dictionary = {
		"trigger_provider_id": "Core",
		"trigger_id": clean,
		"trigger_args": "",
		"label": "",
		"declares_signal": "",
	}
	if clean.begins_with("signal:"):
		var signal_name: String = clean.trim_prefix("signal:")
		var native: Dictionary = _native_signal(host_class, signal_name)
		if EventSheetACELifter.CORE_SIGNAL_TRIGGERS.has(signal_name):
			entry["trigger_id"] = str(EventSheetACELifter.CORE_SIGNAL_TRIGGERS[signal_name])
		else:
			entry["trigger_provider_id"] = ""
			entry["trigger_args"] = _args_signature(native)
			if native.is_empty():
				entry["declares_signal"] = signal_name
	entry["label"] = label_for(clean, str(entry["trigger_id"]), str(entry["trigger_provider_id"]))
	return entry


## The words one starter reads with: the sheet's own word where it has one, then the trigger's own
## display name, then the signal's name read as a sentence.
static func label_for(requested_id: String, trigger_id: String, provider_id: String) -> String:
	if STARTER_WORDS.has(requested_id):
		return EventSheetL10n.translate(str(STARTER_WORDS[requested_id]))
	var probe: EventRow = EventRow.new()
	probe.trigger_provider_id = provider_id
	probe.trigger_id = trigger_id
	return EventSheetArrangement.trigger_words(probe)


## The EventRow one starter entry adds - a trigger and an empty action lane, which is exactly the
## sheet's own "+ Add action" placeholder.
static func build_event(entry: Dictionary) -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = str(entry.get("trigger_provider_id", "Core"))
	event.trigger_id = str(entry.get("trigger_id", ""))
	event.trigger_args = str(entry.get("trigger_args", ""))
	return event


## The signals a starter set needs the sheet to declare, minus the ones it already declares. One
## SignalRow each, in the order the starters name them.
static func missing_signal_rows(starters: Array, sheet: EventSheetResource) -> Array:
	var declared: Dictionary = {}
	if sheet != null:
		for row: Variant in sheet.events:
			if row is SignalRow:
				declared[str((row as SignalRow).signal_name)] = true
	var rows: Array = []
	for entry: Variant in starters:
		var signal_name: String = str((entry as Dictionary).get("declares_signal", "")).strip_edges()
		if signal_name.is_empty() or declared.has(signal_name):
			continue
		declared[signal_name] = true
		var declaration: SignalRow = SignalRow.new()
		declaration.signal_name = signal_name
		rows.append(declaration)
	return rows


# ── X25. The secrets counter one object marked `secret` is offered on drop ────────────────────
# An area marked a secret has exactly one event worth writing: when the player walks into it, count
# it - once, however many times they walk back through. That is the shipped Mark Secret Found row,
# and this is the whole event around it, built here rather than in the dock so it is pure and a
# test can pin what the offer would add without opening a canvas.

## The list every Mark Secret Found row counts into, and the name the shipped row's own default
## already reads with - so a sheet that has this variable and a sheet that took it from the Boomer
## Arsenal starter are the same sheet.
const SECRETS_VARIABLE := "secrets_found"


## The variable declaration a sheet needs before it can count secrets, in the sheet's own
## variables-dictionary shape. Only added when the sheet does not declare it already.
static func secrets_variable_entry() -> Dictionary:
	return {"type": "Array", "default": [], "exported": false,
		"attributes": {"tooltip": "Every secret counted so far. Each one goes in once, so walking back through a room does not count it twice."}}


## The event an object marked `secret` offers: its own "walked into" trigger with the shipped Mark
## Secret Found row already in the action lane, naming the object as the secret.
static func secret_counter_event(object_label: String, host_class: String = "Area3D") -> EventRow:
	var event: EventRow = build_event(entry_for("signal:body_entered", host_class))
	event.trigger_source_path = object_label
	var count_it: ACEAction = ACEAction.new()
	count_it.provider_id = "Core"
	count_it.ace_id = "MarkSecretFound"
	count_it.codegen_template = secret_counter_template()
	count_it.params = {"name": "\"%s\"" % object_label, "found": SECRETS_VARIABLE}
	event.actions.append(count_it)
	return event


## The template the shipped Mark Secret Found row writes, taken from the registry rather than
## re-typed here - the same no-drift rule the starter sheets follow.
static func secret_counter_template() -> String:
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		if str(descriptor.ace_id) == "MarkSecretFound":
			return str(descriptor.codegen_template)
	return ""


# ── Y16. The door event an object marked "needs key" is offered on drop ───────────────────────
# A body the reader named a key for has exactly one event worth writing: when the player walks into
# it, try it - and the shipped Try Door row is the whole of trying it, because it opens the door when
# the key fits and tells the door it was refused when it does not. Built here rather than in the dock
# so it is pure and a test can pin what the offer would add without opening a canvas.

## The list every keycard row reads, and the name the shipped rows' own defaults already use - so a
## sheet that has this variable and a sheet that took it from the Keycard Door starter are the same
## sheet.
const KEYS_VARIABLE := "keys"


## The variable declaration a sheet needs before it can carry keys, in the sheet's own
## variables-dictionary shape. Only added when the sheet does not declare it already.
static func keys_variable_entry() -> Dictionary:
	return {"type": "Array", "default": [], "exported": false,
		"attributes": {"tooltip": "Every keycard picked up so far, by name. The door rows read this list."}}


## The event a body marked with a key offers: its own walked-into trigger with the shipped Try Door
## row already in the action lane, pointed at the door that was dropped.
static func locked_door_event(object_label: String, host_class: String = "StaticBody3D") -> EventRow:
	var event: EventRow = build_event(entry_for("signal:body_entered", host_class))
	event.trigger_source_path = object_label
	var try_it: ACEAction = ACEAction.new()
	try_it.provider_id = "Core"
	try_it.ace_id = "TryDoor"
	try_it.codegen_template = locked_door_template()
	try_it.params = {"door": "$%s" % object_label, "keys": KEYS_VARIABLE}
	event.actions.append(try_it)
	return event


## The template the shipped Try Door row writes, taken from the registry rather than re-typed here -
## the same no-drift rule the starter sheets follow.
static func locked_door_template() -> String:
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		if str(descriptor.ace_id) == "TryDoor":
			return str(descriptor.codegen_template)
	return ""


# ── Y11. The water rows one area marked `water` is offered on drop ────────────────────────────
# A volume the reader calls water has two events, not one: the way in and the way out. Together they
# hold a flag that says "I am in the water", which is the fact every swimming rule is then written
# against - the sheet can test it in any condition, and the swim reading recognises the pair.

## The flag the two rows raise and lower. One name, so a sheet that took the rows from a drop and a
## sheet that took them from a traversal starter are the same sheet.
const WATER_VARIABLE := "in_water"


## The flag declaration a sheet needs before the water rows mean anything, in the sheet's own
## variables-dictionary shape. Only added when the sheet does not declare it already.
static func water_variable_entry() -> Dictionary:
	return {"type": "bool", "default": false, "exported": false,
		"attributes": {"tooltip": "True while the body is inside a volume marked water. Every swimming rule is written against this."}}


## The two events an object marked `water` offers: its own walked-in trigger raising the flag, and
## its walked-out trigger lowering it, in that order.
static func water_volume_events(object_label: String, host_class: String = "Area3D") -> Array:
	return [
		water_flag_event(object_label, host_class, "body_entered", "true"),
		water_flag_event(object_label, host_class, "body_exited", "false")
	]


## One half of the pair: the area's own trigger with a Set value row in the action lane, writing the
## flag literally - `in_water = true` on the way in, `in_water = false` on the way out.
static func water_flag_event(object_label: String, host_class: String, signal_name: String,
		value: String) -> EventRow:
	var event: EventRow = build_event(entry_for("signal:%s" % signal_name, host_class))
	event.trigger_source_path = object_label
	var write_flag: ACEAction = ACEAction.new()
	write_flag.provider_id = "Core"
	write_flag.ace_id = "SetVar"
	write_flag.codegen_template = set_value_template()
	write_flag.params = {"var_name": WATER_VARIABLE, "value": value}
	event.actions.append(write_flag)
	return event


## The template the shipped Set value row writes, taken from the registry rather than re-typed here
## - the same no-drift rule the secrets counter follows.
static func set_value_template() -> String:
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		if str(descriptor.ace_id) == "SetVar":
			return str(descriptor.codegen_template)
	return ""


## `{"name": ..., "args": [...]}` for a signal the host class itself declares, or {} when the class
## does not have one by that name (which is what makes it a signal the sheet declares).
static func _native_signal(host_class: String, signal_name: String) -> Dictionary:
	var clean: String = host_class.strip_edges()
	if clean.is_empty() or not ClassDB.class_exists(clean):
		return {}
	for signal_info: Dictionary in ClassDB.class_get_signal_list(clean, false):
		if str(signal_info.get("name", "")) == signal_name:
			return signal_info
	return {}


## The baked handler signature a `signal:` trigger carries ("body: Node2D"), read off the signal's
## own argument list so the handler's parameters are the ones the engine will send.
static func _args_signature(signal_info: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for argument: Variant in signal_info.get("args", []):
		var argument_info: Dictionary = argument
		var argument_name: String = str(argument_info.get("name", ""))
		if argument_name.is_empty():
			continue
		var argument_class: String = str(argument_info.get("class_name", "")).strip_edges()
		var argument_type: int = int(argument_info.get("type", TYPE_NIL))
		if not argument_class.is_empty():
			parts.append("%s: %s" % [argument_name, argument_class])
		elif argument_type != TYPE_NIL:
			parts.append("%s: %s" % [argument_name, type_string(argument_type)])
		else:
			parts.append(argument_name)
	return ", ".join(parts)
