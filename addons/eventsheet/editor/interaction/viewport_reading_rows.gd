@tool
class_name EventSheetViewportReadingRows
extends RefCounted

# The row-level reading lenses, kept beside the text lenses but separate from them because these
# need to ASK things - the sheet for its host class, the editor theme for a class icon, the
# sheet's functions for their parameter names. Like the text lenses they are display-only: every
# function here returns something to draw, and nothing here touches a row model, a sheet
# resource, or emitted GDScript.
#
#   M13/M20  class icons on objects   - the pack's host, a $Node / %Node reference, and any
#                                       @onready-declared node variable draw their Godot class
#                                       icon before the object label
#   M16      Functions > Call Name    - a call to a known function reads with its display name
#                                       and one argument per parameter name
#   M17      folded code cards        - a raw block that could not lift reads as one card
#   M20      object declaration rows  - @onready var hp_bar: ProgressBar = %HpBar
#   N4       autoloads and behaviours - an autoload reads as a global, and a pack node under the
#                                       script's own node reads as that object's behaviour


## The object label a pack's host is shown under. One constant so the icon map, the row builder
## and the tests can never disagree about which label the host icon belongs to.
const HOST_LABEL := "host"


## M25/M27/M28. What the sentence grammar needs to know about THIS sheet that only something able to
## ASK can answer: the name of the object the script itself is, the engine properties that object has
## (so `position.x = 100` reads under it and a plain script variable does not), and each declared
## signal's parameter names (so an emit shows named payload chips).
##
## Merged into the row builder's sentence context once per rebuild. Everything here is a lookup - no
## instancing, no scene loading - because it runs whenever the sheet identity changes.
static func sentence_context_extras(sheet: EventSheetResource) -> Dictionary:
	if sheet == null:
		return {}
	# ── M38 / M40 lens hook ────────────────────────────────────────────────────────────────────
	# The sheet's own enums (so an unambiguous member can drop its enum name) and the class behind
	# every object label (so `play` can tell an animation from a sound). Both are plain walks of the
	# sheet, cached with the rest of the context.
	var enums: Dictionary = enum_member_map(sheet)
	return {
		"script_object": script_object_name(sheet),
		"engine_properties": engine_property_set(sheet),
		"signal_params": signal_parameter_map(sheet),
		"enum_members": enums.get("members", {}),
		"enum_names": enums.get("names", {}),
		"object_classes": object_class_map(sheet),
		"self_class": sheet.host_class.strip_edges(),
		# ── P9 ────────────────────────────────────────────────────────────────────────────────
		# Whether this file is the scene's OWN script, which decides whether its `_ready` reads as the
		# layout starting or as one object being created. Cached here with the rest of the context
		# because the answer only changes when the opened sheet does.
		"scene_root": is_scene_root_script(sheet)
	}


## P9. True when the opened file is the script the SCENE ITSELF carries - the one on its root node.
## The scene scan already answers exactly this (it records a script only when the ROOT carries it), so
## this is a lookup rather than a second walk of the project.
static func is_scene_root_script(sheet: EventSheetResource) -> bool:
	if sheet == null:
		return false
	var source_path: String = str(sheet.external_source_path).strip_edges()
	if source_path.is_empty():
		return false
	return not ViewportRowBuilder.scene_using_script(source_path).is_empty()


## M38. The sheet's enums, as {"names": {EnumName: true}, "members": {MEMBER: how many enums declare
## it}}. The count is what decides whether a member may drop its enum name: `State.PATROL` reads
## `PATROL` only while no other enum on the sheet has a `PATROL` of its own.
static func enum_member_map(sheet: EventSheetResource) -> Dictionary:
	var names: Dictionary = {}
	var members: Dictionary = {}
	if sheet == null:
		return {"names": names, "members": members}
	for entry: Variant in sheet.events:
		var enum_row: EnumRow = entry as EnumRow
		if enum_row == null or enum_row.enum_name.strip_edges().is_empty():
			continue
		names[enum_row.enum_name.strip_edges()] = true
		for value: String in enum_row.members:
			# A value may carry its number ("PATROL = 0"); the NAME is its head.
			var member: String = value.strip_edges()
			if member.contains("="):
				member = member.substr(0, member.find("=")).strip_edges()
			if not member.is_empty():
				members[member] = int(members.get(member, 0)) + 1
	return {"names": names, "members": members}


## M25. The name a script's own object goes by: its `class_name` first, then the class it extends -
## the node it sits on, which is the object a reader sees in the scene tree. Never `self`.
##
## A plain `extends Node` script with no class_name gets NO name, and its rows stay with System: a
## bare Node has nothing an object picture could show, and the file name it happens to be saved
## under is not a name anybody calls it by.
static func script_object_name(sheet: EventSheetResource) -> String:
	if sheet == null:
		return ""
	var declared: String = sheet.custom_class_name.strip_edges()
	if not declared.is_empty():
		return declared
	# On a BEHAVIOUR the host class belongs to `host`, the node the pack is attached TO - naming the
	# script after it would send a reader looking for the object on the wrong node.
	if sheet.behavior_mode or _declares_host(sheet):
		return ""
	var host_class: String = sheet.host_class.strip_edges()
	return host_class if not host_class.is_empty() and host_class != "Node" else ""


## True when the sheet keeps its own `host` reference - the mark of a behaviour, whose host class is
## the node it rides rather than the class the script itself is.
static func _declares_host(sheet: EventSheetResource) -> bool:
	for entry: Variant in sheet.events:
		var variable: LocalVariable = entry as LocalVariable
		if variable != null and variable.name == HOST_LABEL:
			return true
	return false


## M25. Every property the ENGINE reports on the class this script extends, as a set. A name the
## sheet declares as its own variable is removed: a script that keeps a variable called `position`
## means ITS variable, and reading it as the node's place would be a confident lie.
static func engine_property_set(sheet: EventSheetResource) -> Dictionary:
	var properties: Dictionary = {}
	if sheet == null:
		return properties
	var host_class: String = sheet.host_class.strip_edges()
	if host_class.is_empty() or not ClassDB.class_exists(host_class):
		return properties
	for entry: Dictionary in ClassDB.class_get_property_list(host_class, false):
		var property_name: String = str(entry.get("name", ""))
		# Category / group rows carry no name a row could ever set.
		if not property_name.is_empty() and not property_name.contains("/"):
			properties[property_name] = true
	for entry: Variant in sheet.events:
		var variable: LocalVariable = entry as LocalVariable
		if variable != null:
			properties.erase(variable.name)
	return properties


## M28. Each declared signal's parameter names, in order, so an emit reads with named payload chips.
static func signal_parameter_map(sheet: EventSheetResource) -> Dictionary:
	var declared: Dictionary = {}
	if sheet == null:
		return declared
	for entry: Variant in sheet.events:
		var signal_row: SignalRow = entry as SignalRow
		if signal_row == null:
			continue
		var names: PackedStringArray = PackedStringArray()
		for parameter: String in signal_row.params:
			# A declaration carries its type ("amount: int"); the NAME is its head, and the type is
			# never part of a sentence.
			var bare: String = parameter.strip_edges()
			if bare.contains(":"):
				bare = bare.substr(0, bare.find(":")).strip_edges()
			if not bare.is_empty():
				names.append(bare)
		if not names.is_empty():
			declared[signal_row.signal_name] = names
	return declared


## M26. The engine's own names for a method's arguments ("name", "custom_speed" for
## AnimatedSprite2D.play), so a call's chips say what each value MEANS. Empty whenever the class or
## the method is not one the engine knows - the chips then show plain values, which is the honest
## answer.
static func method_parameter_names(class_name_str: String, method_name: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var bare_class: String = class_name_str.strip_edges()
	if bare_class.is_empty() or method_name.strip_edges().is_empty():
		return names
	if not ClassDB.class_exists(bare_class) or not ClassDB.class_has_method(bare_class, method_name, false):
		return names
	for entry: Dictionary in ClassDB.class_get_method_list(bare_class, false):
		if str(entry.get("name", "")) != method_name:
			continue
		for argument: Variant in (entry.get("args", []) as Array):
			names.append(str((argument as Dictionary).get("name", "")))
		break
	return names


## M26. The class a call's object is, for the parameter-name lookup: whatever the sheet's own object
## map knows, else the object label itself when it IS a class name (`$Sprite2D` names its class).
static func class_of_object(object_label: String, class_map: Dictionary) -> String:
	var label: String = object_label.strip_edges()
	if label.is_empty():
		return ""
	var known: String = str(class_map.get(label, ""))
	if not known.is_empty():
		return known
	return label if ClassDB.class_exists(label) else ""


## M27. The event-sheet words for the two tick triggers. The trigger ids are untouched - this is the
## reading only, so a sheet still stores (and compiles to) exactly what it did before.
static func tick_trigger_words(trigger_id: String, display_text: String) -> String:
	match trigger_id:
		"OnPhysicsProcess":
			return "%s %s" % [EventSheetL10n.translate("Every tick"), EventSheetL10n.translate("(physics)")]
		"OnProcess":
			return "%s %s" % [EventSheetL10n.translate("Every tick"), EventSheetL10n.translate("(draw)")]
	# M41 - the collision family reads as the event-sheet's own two triggers.
	var collision: String = collision_trigger_words(trigger_id)
	return collision if not collision.is_empty() else display_text


## P8. The notification a `_notification` branch reads as. Only the ones an event sheet already has a
## word for are named; every other notification humanizes, which says what happened without pretending
## the sheet has a trigger of its own for it.
const NOTIFICATION_TRIGGER_WORDS: Dictionary = {
	"NOTIFICATION_APPLICATION_PAUSED": "On suspended",
	"NOTIFICATION_APPLICATION_RESUMED": "On resumed",
	"NOTIFICATION_APPLICATION_FOCUS_OUT": "On lost focus",
	"NOTIFICATION_APPLICATION_FOCUS_IN": "On gained focus",
	"NOTIFICATION_WM_CLOSE_REQUEST": "On close",
	"NOTIFICATION_PAUSED": "On paused",
	"NOTIFICATION_UNPAUSED": "On unpaused",
	"NOTIFICATION_PREDELETE": "On destroyed"
}

## The trigger id prefix a lifted `_notification` branch carries, with Godot's own constant after it.
const NOTIFICATION_TRIGGER_PREFIX := "OnNotification:"

## P8/P9. The lifecycle triggers whose reading is the same wherever the script sits. `_ready` and
## `_exit_tree` are NOT here: what those two say depends on whether the file is the scene's own script,
## which is the whole point of P9.
const LIFECYCLE_TRIGGER_WORDS: Dictionary = {
	"OnDraw": "On draw",
	"OnEnterTree": "On created",
	"OnExitTree": "On destroyed"
}


## P8/P9. The lifecycle triggers in the event sheet's own words, and who they belong to.
##
## Always on, never behind the Familiar Words toggle: these are not a friendlier spelling of Godot's
## names, they ARE the sheet's trigger names, and a reader who knows the sheet should find them here.
## Godot's own word stays one hover away, as it does for every other reading.
##
## The scene decides two of them. A `_ready` on the script the SCENE ITSELF carries is the layout
## starting - there is one of those per layout, and it runs when the layout opens; a `_ready` on a
## script sitting on some object in the scene is that object being created, which happens once per
## instance. Same split for `_exit_tree`: the layout ending, or the object being destroyed.
##
## Returns {"text", "object"} - both always filled - or {} when the trigger is not a lifecycle one,
## which is the caller's cue to keep whatever it was already drawing.
static func lifecycle_trigger_reading(trigger_id: String, object_label: String,
		scene_root: bool, script_object: String) -> Dictionary:
	var owner: String = script_object.strip_edges()
	if owner.is_empty():
		owner = object_label
	var system: String = EventSheetL10n.translate("System")
	match trigger_id:
		"OnReady":
			if scene_root:
				return {"text": EventSheetL10n.translate("On start of layout"), "object": system}
			return {"text": EventSheetL10n.translate("On created"), "object": owner}
		"OnExitTree":
			if scene_root:
				return {"text": EventSheetL10n.translate("On end of layout"), "object": system}
			return {"text": EventSheetL10n.translate("On destroyed"), "object": owner}
	if LIFECYCLE_TRIGGER_WORDS.has(trigger_id):
		return {"text": EventSheetL10n.translate(str(LIFECYCLE_TRIGGER_WORDS[trigger_id])), "object": owner}
	if trigger_id.begins_with(NOTIFICATION_TRIGGER_PREFIX):
		# A notification is something that happened to the GAME, not to one node, so it belongs to
		# System - the same object the sheet files its other whole-game triggers under.
		return {"text": notification_trigger_words(trigger_id.substr(NOTIFICATION_TRIGGER_PREFIX.length())),
			"object": system}
	return {}


## P8. One notification constant in the sheet's words. An unknown one reads as its own name in plain
## words ("On wm mouse enter") rather than as the SCREAMING_CASE constant: the reader still learns what
## happened, and nothing claims a trigger the sheet does not have.
static func notification_trigger_words(constant_name: String) -> String:
	var bare: String = constant_name.strip_edges()
	if NOTIFICATION_TRIGGER_WORDS.has(bare):
		return EventSheetL10n.translate(str(NOTIFICATION_TRIGGER_WORDS[bare]))
	var humanized: String = bare.trim_prefix("NOTIFICATION_").capitalize().to_lower()
	if humanized.is_empty():
		return EventSheetL10n.translate("On notification")
	return "%s %s" % [EventSheetL10n.translate("On"), humanized]


## M41. An event sheet has one collision trigger and one for the overlap ending, where Godot has four
## signals (bodies and areas, entering and leaving). Keyed by the trigger id AND usable from the
## signal name, so a handler lifted from a `.connect(...)` line and one lifted from a declared
## `func _on_body_entered` read the same words. "" when the trigger is not one of the four.
static func collision_trigger_words(trigger_id: String) -> String:
	match trigger_id:
		"OnBodyEntered", "OnAreaEntered", "body_entered", "area_entered":
			return EventSheetL10n.translate("On collision with")
		"OnBodyExited", "OnAreaExited", "body_exited", "area_exited":
			return EventSheetL10n.translate("On stopped overlapping")
	return ""


## M33. The event-sheet words for a loop row, and the object it belongs to.
##
## Returns {"text", "object"} - `object` empty for the System loops, and the host for a loop over
## another object's children, which an event sheet draws as that object's own For each. The loop rows
## themselves are unchanged: this is what they SAY, never what they are.
static func loop_words(kind: int, iterator_name: String, collection: String) -> Dictionary:
	var iterator: String = iterator_name.strip_edges()
	var source: String = collection.strip_edges()
	match kind:
		PickFilter.CollectionKind.REPEAT:
			var bounds: PackedStringArray = EventSheetSentence.split_top_level(source, ", ")
			if bounds.size() == 2:
				# The event-sheet For loop is INCLUSIVE at both ends, and `range(2, 8)` stops at 7 - so the
				# row says 7, which is the last value the loop body actually sees.
				var last: String = _one_less(bounds[1])
				if not last.is_empty():
					return {"text": "%s \"%s\" %s %s %s %s" % [EventSheetL10n.translate("For"), iterator,
						EventSheetL10n.translate("from"), bounds[0], EventSheetL10n.translate("to"), last], "object": ""}
			var repeat_text: String = "%s %s %s" % [EventSheetL10n.translate("Repeat"), source, EventSheetL10n.translate("times")]
			if not iterator.is_empty():
				repeat_text += " (%s %s)" % [EventSheetL10n.translate("loopindex"), iterator]
			return {"text": repeat_text, "object": ""}
		PickFilter.CollectionKind.WHILE:
			return {"text": "%s %s" % [EventSheetL10n.translate("While"), source], "object": ""}
		PickFilter.CollectionKind.CHILDREN:
			return {"text": "%s %s" % [EventSheetL10n.translate("For each child"), iterator], "object": ""}
	# `for child in host.get_children()` is that object's own For each, exactly as a sheet draws it -
	# and a receiver-less `get_children()` is the script's own, which the object column already names.
	if source == "get_children()":
		return {"text": "%s %s" % [EventSheetL10n.translate("For each child"), iterator], "object": ""}
	var children_of: String = _children_receiver(source)
	if not children_of.is_empty():
		return {"text": "%s %s" % [EventSheetL10n.translate("For each child"), iterator], "object": children_of}
	return {}


## The object whose children an expression walks (`host.get_children()` -> "host"), or "" when the
## expression is anything else.
static func _children_receiver(expression: String) -> String:
	var text: String = expression.strip_edges()
	if not text.ends_with(".get_children()"):
		return ""
	var receiver: String = text.substr(0, text.length() - ".get_children()".length()).strip_edges()
	if receiver.is_empty() or receiver.contains("(") or receiver.contains(" "):
		return ""
	return EventSheetSentence.object_of_reference(receiver)


## `8` -> `7`, so a half-open Godot range reads as the inclusive event-sheet one. Empty when the bound
## is not a plain number - `range(2, n)` has no last value a reader could be shown.
static func _one_less(bound: String) -> String:
	var text: String = bound.strip_edges()
	return str(text.to_int() - 1) if text.is_valid_int() else ""


## M13/M20 - the object-label to class-name map recovered from a sheet, so any row naming one of
## these objects can draw its Godot class icon.
##
## Three sources, cheapest first, and nothing else: the pack's declared host class; every
## @onready node variable's declared type (both under its own name and under the node path it
## reads, so `hp_bar` and `%HpBar` both resolve); nothing is instantiated and no scene is opened,
## because this runs on every span rebuild. A node reference with no declared type simply gets no
## icon, which is the honest answer - a guessed icon is worse than none.
static func object_class_map(sheet: EventSheetResource) -> Dictionary:
	var map: Dictionary = {}
	if sheet == null:
		return map
	var host_class: String = sheet.host_class.strip_edges()
	if not host_class.is_empty() and host_class != "Node":
		map[HOST_LABEL] = host_class
		# M25 - the script's own object draws the picture of the class it IS, so a row that names it
		# (`Player ▸ Set X to 100`) shows the same icon the scene tree shows for that node.
		var script_object: String = script_object_name(sheet)
		if not script_object.is_empty():
			map[script_object] = host_class
	for entry: Variant in sheet.events:
		var variable: LocalVariable = entry as LocalVariable
		if variable == null or not variable.onready:
			continue
		var declared_type: String = variable.type_name.strip_edges()
		if declared_type.is_empty():
			continue
		map[variable.name] = declared_type
		# `%HpBar` / `$Head`: the row that USES the node often names the path rather than the
		# variable, so the path resolves to the same class. Both spellings, and the bare name
		# after the sigil, so "HpBar" resolves too.
		# M47 - a `get_node("A/B")` lookup names the same node `$A/B` does, so both spellings (and the
		# last segment the rows read it under) resolve to the class the variable declared.
		var node_reference: String = EventSheetSentence.node_lookup_text(variable.default_value.strip_edges())
		if node_reference.begins_with("%") or node_reference.begins_with("$"):
			map[node_reference] = declared_type
			map[node_reference.substr(1)] = declared_type
			map[EventSheetSentence.object_of_reference(node_reference)] = declared_type
	return map


## M13 - the Godot class icon for an object label, or null when nothing is known (which is also
## what headless returns, so a headless render keeps the text-only look and never crashes).
static func class_icon_for(object_label: String, class_map: Dictionary) -> Texture2D:
	var trimmed: String = object_label.strip_edges()
	if trimmed.is_empty():
		return null
	var class_name_str: String = str(class_map.get(trimmed, ""))
	if class_name_str.is_empty():
		return null
	return ACEPickerDialog.editor_icon(class_name_str)


## M20 - the class name a node declaration shows after its value ("ProgressBar"), or "" when the
## variable declared no type.
static func declared_class_of(variable: LocalVariable) -> String:
	if variable == null or not variable.onready:
		return ""
	return variable.type_name.strip_edges()


## M20 - true when a variable is an OBJECT declaration rather than a value one: an @onready that
## reads a node out of the scene. Those are the ones that become the sheet's object list.
static func is_object_declaration(variable: LocalVariable) -> bool:
	if variable == null or not variable.onready:
		return false
	var value: String = variable.default_value.strip_edges()
	# M47 - `get_node("A/B")` names a node exactly as `$A/B` does, so it is the same declaration.
	return value.begins_with("%") or value.begins_with("$") \
		or value.begins_with("get_node(") or value.begins_with("get_node_or_null(")


## M47. What an object declaration's VALUE reads as: the node reference in its `$Path` spelling,
## whichever way the file spells it. A `get_node_or_null` lookup may find nothing, and that is worth
## saying, so the note comes back beside the value: {"value", "note"} - `note` empty for the rest.
static func object_declaration_value(variable: LocalVariable) -> Dictionary:
	if variable == null:
		return {"value": "", "note": ""}
	var raw: String = variable.default_value.strip_edges()
	var shown: String = EventSheetSentence.node_lookup_text(raw)
	var note: String = EventSheetL10n.translate("may be missing") if raw.begins_with("get_node_or_null(") else ""
	return {"value": shown, "note": note}


## M17 - the label on a folded code card: "code  12 lines". The exact GDScript is what the card
## opens to, and it is on the row's hover either way, so the closed card only has to say how much
## is behind it.
static func code_card_label(line_count: int) -> String:
	var lines_word: String = EventSheetL10n.translate("line") if line_count == 1 else EventSheetL10n.translate("lines")
	return "%d %s" % [line_count, lines_word]


## M17 - whether a raw block should render as ONE folded card rather than as statement rows.
## Reading mode folds it (a stubborn helper costs one row until you want it); authoring keeps the
## statement rows, because that is what you edit. The fold itself is view state, so the caller
## seeds it from the viewport's fold map with THIS as the default.
static func code_card_default_folded(reading_mode: bool) -> bool:
	return reading_mode


## The raw function name a one-call statement invokes ("add_look" from "add_look(a, b)" or from
## "self.add_look(a, b)"), or "" when the line is not a plain call. The sentence layer hands back
## a DISPLAY verb; this recovers the name to look the function up by.
static func called_function_name(code: String) -> String:
	var text: String = code.strip_edges()
	var open_at: int = text.find("(")
	if open_at <= 0 or not text.ends_with(")"):
		return ""
	var callee: String = text.substr(0, open_at).strip_edges()
	if callee.contains("."):
		callee = callee.substr(callee.rfind(".") + 1)
	if not EventSheetViewportLenses.is_identifier(callee):
		return ""
	return callee


## M16 - the sentence pieces for a call to a KNOWN function: "Functions > Call Add Look" plus one
## argument per parameter, named by the function's own parameter names so the call is
## self-documenting. Returns [] when the function is not one this sheet knows, which is the
## caller's cue to keep the ordinary call reading - a call to something unknown must not be
## dressed up as a project function.
##
## `parameter_names` is the callee's parameter list in order; a shorter list simply leaves the
## remaining arguments unnamed, so a signature the editor only partly knows still reads.
static func call_reading_pieces(
	display_name: String,
	arguments: PackedStringArray,
	parameter_names: PackedStringArray,
	humanize: bool,
	knob_names: Dictionary = {}
) -> Array:
	if display_name.strip_edges().is_empty():
		return []
	var pieces: Array = []
	pieces.append([EventSheetL10n.translate("Functions") + "  ", "object"])
	pieces.append([EventSheetL10n.translate("Call") + " ", "plain"])
	pieces.append([display_name, "name"])
	for index: int in range(arguments.size()):
		var parameter_name: String = parameter_names[index] if index < parameter_names.size() else ""
		var value: String = arguments[index].strip_edges()
		if humanize:
			value = EventSheetViewportLenses.humanize_expression(value, knob_names)
		else:
			value = EventSheetViewportLenses.possessive_in_expression(value, false)
		pieces.append(["   ", "plain"])
		pieces.append([EventSheetViewportLenses.call_argument_chip(parameter_name, value, false), "value"])
	return pieces


## M26. The whole reading of a call the sheet has no verb of its own for: Object, verb in words, one
## chip per argument, and never a pair of parentheses. Returns {"object", "pieces"} - {} when the
## line is not exactly one call, which is the caller's cue to keep whatever it was drawing.
##
## `class_map` is the sheet's object-to-class map, so the chips can be named by the engine's own
## parameter names whenever the object's class is known.
static func generic_call_pieces(code: String, context: Dictionary, class_map: Dictionary) -> Dictionary:
	var call: Dictionary = EventSheetSentence.call_parts(code.strip_edges())
	if call.is_empty():
		return {}
	var method: String = str(call.get("method", ""))
	var object_label: String = EventSheetSentence.call_object(str(call.get("target", "")), method, context)
	var parameter_names: PackedStringArray = method_parameter_names(class_of_object(object_label, class_map), method)
	var reading: Dictionary = EventSheetSentence.call_reading(code, context, parameter_names)
	if reading.is_empty():
		return {}
	var pieces: Array = []
	for entry: Variant in (reading.get("segments", []) as Array):
		var segment: Dictionary = entry
		pieces.append([str(segment.get("text", "")), str(segment.get("tone", "plain"))])
	return {"object": str(reading.get("object", "")), "pieces": pieces}


## The parameter names of one of the sheet's own functions, in order. Empty when the function is
## unknown or declared none - the call then reads with plain argument values.
static func parameter_names_of(event_function: EventFunction) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	if event_function == null:
		return names
	for entry: Variant in event_function.params:
		var param: ACEParam = entry as ACEParam
		if param != null and not param.id.strip_edges().is_empty():
			names.append(param.id.strip_edges())
	if names.is_empty():
		for legacy: Variant in event_function.parameters:
			var legacy_name: String = str(legacy).strip_edges()
			# The legacy spelling is a whole declaration ("amount: float"); the name is its head.
			if legacy_name.contains(":"):
				legacy_name = legacy_name.substr(0, legacy_name.find(":")).strip_edges()
			if not legacy_name.is_empty():
				names.append(legacy_name)
	return names


## Every @export knob name on a sheet, as a set. The humanized-names lens shows these with Godot's
## Inspector capitalisation, so it needs to know which names they are.
static func export_knob_names(sheet: EventSheetResource) -> Dictionary:
	var knobs: Dictionary = {}
	if sheet == null:
		return knobs
	for entry: Variant in sheet.events:
		var variable: LocalVariable = entry as LocalVariable
		if variable != null and variable.exported:
			knobs[variable.name] = true
	return knobs


# ── N4. Autoloads as globals, pack nodes as behaviours ────────────────────────────────────────
# An event sheet has project-wide globals and per-object behaviours; Godot spells those as autoload
# singletons and as behaviour packs mounted on child nodes. Both already READ - `Game.score += 1`
# lands under the object `Game`, `$Health.take_damage(3)` under `Health` - but neither says WHAT it
# is, so a reader cannot tell a project-wide global from a node, or a behaviour from a sibling.
# Everything below only decides what those two shapes SAY; no row model and no emitted line moves.


## The muted word an autoload's object label wears, so a global is legible as one.
const GLOBAL_NOTE := "(global)"

## Editor-theme icons tried, in order, as the globe on an autoload's row. Which names a build ships
## is not something a headless run can answer - it has no editor theme and returns null for every
## name - so this degrades to NO icon rather than to a wrong one, and the "(global)" note carries
## the meaning on its own.
const AUTOLOAD_ICON_NAMES: PackedStringArray = ["Environment", "World3D", "Node"]


## Every registered autoload, singleton name -> the path its script lives at.
##
## Deliberately not the project scanner's list: that one drops an autoload whose script sits inside
## an addon, which is right for a picker (its verbs arrive through the provider system) and wrong
## here - an autoload is a global a reader can name whatever folder it was written in.
##
## Walking ProjectSettings is not free and the answer is the same for every row in a rebuild, so
## every per-row caller takes the map as an argument and the row builder hoists this call beside its
## other per-rebuild lens caches. Nothing here caches: a hidden cache on a settings list that the
## Project Settings dialog can change under it would go stale exactly when it mattered.
static func autoload_singletons() -> Dictionary:
	var found: Dictionary = {}
	for property_info: Dictionary in ProjectSettings.get_property_list():
		var setting: String = str(property_info.get("name", ""))
		if not setting.begins_with("autoload/"):
			continue
		var singleton: String = setting.trim_prefix("autoload/").strip_edges()
		if singleton.is_empty():
			continue
		found[singleton] = str(ProjectSettings.get_setting(setting, "")).trim_prefix("*").strip_edges()
	return found


## True when an object label names a registered autoload - the singleton name game code types.
static func is_autoload_object(object_label: String, autoloads: Dictionary) -> bool:
	var label: String = object_label.strip_edges()
	return not label.is_empty() and autoloads.has(label)


## An autoload's object label with its note: "Game" -> "Game (global)". Every other label comes back
## untouched, so a caller can pipe all of them through this one door.
static func global_object_label(object_label: String, autoloads: Dictionary) -> String:
	if not is_autoload_object(object_label, autoloads):
		return object_label
	return "%s %s" % [object_label.strip_edges(), EventSheetL10n.translate(GLOBAL_NOTE)]


## The globe an autoload's row wears, or null when the editor theme has nothing to give.
static func autoload_icon() -> Texture2D:
	for icon_name: String in AUTOLOAD_ICON_NAMES:
		var icon: Texture2D = ACEPickerDialog.editor_icon(icon_name)
		if icon != null:
			return icon
	return null


## N4. A condition written on an autoload's member, re-attributed to the autoload: `Game.score > 100`
## becomes the object `Game (global)` and the test `score > 100`, so the owner is visible in the
## object column instead of buried in the sentence.
##
## Returns {"object", "text"}, or {} when the term does not open with a registered singleton, which
## is the caller's cue to read it exactly as before.
static func global_condition(condition_text: String, autoloads: Dictionary) -> Dictionary:
	var text: String = condition_text.strip_edges()
	var dot_at: int = text.find(".")
	if dot_at <= 0:
		return {}
	var head: String = text.substr(0, dot_at).strip_edges()
	if not is_autoload_object(head, autoloads):
		return {}
	var rest: String = text.substr(dot_at + 1).strip_edges()
	if not EventSheetViewportLenses.is_identifier(leading_identifier(rest)):
		return {}
	return {"object": global_object_label(head, autoloads), "text": rest}


## N4. A lifted row whose parameters reach THROUGH an autoload to one of its members, re-read as a
## row belonging to that autoload: a Compare on `EventForgeBridge.score` becomes the object
## `EventForgeBridge (global)` comparing `score`, so the owner sits in the object column rather than
## inside the sentence, where it read as a possessive ("event forge bridge's score").
##
## Returns {"object", "params"} - the owner's label and a COPY of the parameters with the singleton
## prefix taken off every value that carried it. Returns {} unless exactly one autoload is named:
## a row reaching through two globals has no single owner, and guessing one would be a lie.
##
## Nothing here mutates the row. The caller reads the rewritten copy and throws it away; the stored
## parameters, and everything the row compiles to, are untouched.
static func global_member_params(params: Dictionary, autoloads: Dictionary) -> Dictionary:
	var owner: String = ""
	var rewritten: Dictionary = {}
	var changed: bool = false
	for key: Variant in params.keys():
		var value: String = str(params[key])
		var dot_at: int = value.find(".")
		var head: String = value.substr(0, dot_at).strip_edges() if dot_at > 0 else ""
		var member: String = leading_identifier(value.substr(dot_at + 1)) if dot_at > 0 else ""
		if head.is_empty() or member.is_empty() or not is_autoload_object(head, autoloads):
			rewritten[key] = params[key]
			continue
		if not owner.is_empty() and owner != head:
			return {}
		owner = head
		rewritten[key] = value.substr(dot_at + 1)
		changed = true
	if not changed:
		return {}
	return {"object": global_object_label(owner, autoloads), "params": rewritten}


## The identifier a piece of code opens with ("score" from "score > 100"), or "" when it opens with
## anything else.
static func leading_identifier(text: String) -> String:
	var out: String = ""
	for index: int in text.length():
		var character: String = text[index]
		if character == "_" or character.to_lower() != character.to_upper() or character.is_valid_int():
			out += character
		else:
			break
	return out


## Every behaviour pack the editor ships or the project drops in, indexed by every name a row could
## call it by: its `class_name`, its folder in PascalCase, and its `@ace_category` with the spaces
## taken out. The value is that category - the pack's own display name, which is exactly the chip
## that belongs between an object and its behaviour verb ("Player > [Platform] Set max speed").
##
## Derived, never a maintained table: packs are compiler output, and a new one appears by being
## dropped in a folder. Only each file's HEAD is read (class_name and the annotations all sit above
## the first member), and the index is cached on the scanner's own file listing.
static func behaviour_pack_index() -> Dictionary:
	var scripts: Array[String] = EventSheetAddonScanner.list_addon_scripts()
	var key: String = "|".join(scripts)
	if key == _pack_index_key:
		return _pack_index
	var index: Dictionary = {}
	for path: String in scripts:
		var head: Dictionary = _pack_head(path)
		var category: String = str(head.get("category", ""))
		if category.is_empty():
			continue
		var declared: String = str(head.get("class", ""))
		if not declared.is_empty():
			index[declared] = category
		index[path.get_base_dir().get_file().to_pascal_case()] = category
		index[category.replace(" ", "")] = category
	_pack_index_key = key
	_pack_index = index
	return _pack_index


static var _pack_index: Dictionary = {}
static var _pack_index_key: String = ""


## A pack script's `class_name` and its `@ace_category`, read off the file's head. Stops at the first
## member declaration: everything wanted here is above it, and a pack file runs to thousands of lines.
static func _pack_head(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var head: Dictionary = {}
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.begins_with("class_name "):
			head["class"] = line.substr("class_name ".length()).strip_edges()
		elif line.begins_with("## @ace_category("):
			head["category"] = line.substr("## @ace_category(".length()).trim_suffix(")").strip_edges() \
				.trim_prefix("\"").trim_suffix("\"")
		elif line.begins_with("func ") or line.begins_with("var ") or line.begins_with("signal "):
			break
	file.close()
	return head


## N4. The behaviour a call's object IS, when that object is a pack node mounted under the script's
## own node. Returns the pack's display name, or "" when the label names no pack the editor knows.
##
## Two ways in, both honest: the label's DECLARED class is a pack class (`@onready var health:
## SimpleHealthBehavior`), or the label itself is a name a pack goes by. The declared class is tried
## first, so a node merely NAMED like a pack but typed as something else keeps its own reading.
static func behaviour_pack_of(object_label: String, class_map: Dictionary) -> String:
	var label: String = object_label.strip_edges()
	if label.is_empty():
		return ""
	var index: Dictionary = behaviour_pack_index()
	var declared: String = str(class_map.get(label, ""))
	if not declared.is_empty():
		return str(index.get(declared, ""))
	return str(index.get(label, ""))


## N4 applied to a finished reading, at the one moment a lane holds both its object label and its
## sentence pieces. Returns {"object", "pieces", "icon"} - always all three, so a caller never has to
## ask whether anything happened.
##
## Two shapes and nothing else. An autoload gains its "(global)" note and a globe. A pack node hands
## its rows back to the object the pack is mounted ON, with the pack's name as the leading chip, so
## the row reads "Player > [Health] Take damage 3". When the sheet has no object of its own (a plain
## `extends Node`), a behaviour keeps its own label rather than being handed to nobody.
static func object_attribution(object_label: String, pieces: Array, script_object: String,
		class_map: Dictionary, autoloads: Dictionary) -> Dictionary:
	var label: String = object_label.strip_edges()
	var unchanged: Dictionary = {"object": object_label, "pieces": pieces, "icon": null}
	if label.is_empty():
		return unchanged
	if is_autoload_object(label, autoloads):
		return {"object": global_object_label(label, autoloads), "pieces": pieces, "icon": autoload_icon()}
	var pack: String = behaviour_pack_of(label, class_map)
	if pack.is_empty():
		return unchanged
	var owner: String = script_object.strip_edges()
	if owner.is_empty():
		return unchanged
	var chipped: Array = [[pack, "behaviour"], ["  ", "plain"]]
	chipped.append_array(pieces)
	return {"object": owner, "pieces": chipped, "icon": class_icon_for(owner, class_map)}


# ── N10. The census: every object an open file uses ───────────────────────────────────────────
# One derived list, read by the Objects rail, by the object popup and by the picker's object page,
# so those three can never disagree about what is in this file. Everything here is recovered FROM
# the sheet - there is no stored object list to fall out of date, and nothing is instantiated and no
# scene is opened, because a rail refresh runs on every sheet change.
#
# The order is the one a reader looks for: the script's own object first, then the nodes it reaches
# for, then the behaviours mounted on it, then the project-wide globals, then groups, then the
# scenes it spawns.


## The kinds an object entry can be, in the order the rail lists them.
const OBJECT_KINDS: PackedStringArray = ["script", "node", "behaviour", "autoload", "group", "scene"]

## The muted words each kind wears in the rail and in the popup's title line.
const OBJECT_KIND_WORDS: Dictionary = {
	"script": "this script",
	"node": "node",
	"behaviour": "behaviour",
	"autoload": "autoload",
	"group": "group",
	"scene": "scene"
}


## Every object the open file uses, in rail order. Each entry:
##   {"label", "kind", "class", "path", "rows", "verbs", "signals", "note"}
## `rows` counts the TOP-LEVEL rows whose subtree mentions the object, which is the number a reader
## can go and click; `verbs` are the verbs the file calls on it, in first-seen order; `signals` the
## signals it connects or waits on.
static func object_census(sheet: EventSheetResource) -> Array:
	if sheet == null:
		return []
	var class_map: Dictionary = object_class_map(sheet)
	var autoloads: Dictionary = autoload_singletons()
	var by_label: Dictionary = {}
	var order: Array = []
	var script_object: String = script_object_name(sheet)
	if not script_object.is_empty():
		order.append(_new_object_entry(by_label, script_object, "script", sheet.host_class.strip_edges(), ""))
	# @onready node declarations are the file's own object list, already typed and already named.
	for entry: Variant in sheet.events:
		var variable: LocalVariable = entry as LocalVariable
		if variable == null or not is_object_declaration(variable):
			continue
		var declared: String = declared_class_of(variable)
		var kind: String = "behaviour" if not str(behaviour_pack_index().get(declared, "")).is_empty() else "node"
		var reference: String = str(variable.default_value).strip_edges()
		order.append(_new_object_entry(by_label, variable.name, kind, declared, reference))
		# `@onready var hp_bar := %HpBar` is ONE object with two names. Claiming the path's own label
		# here keeps the scan below from listing the same node a second time as "HpBar".
		by_label[EventSheetSentence.object_of_reference(reference)] = by_label[variable.name]
	# Then everything the CODE names that nothing declared: bare $Node / %Unique references, the
	# autoloads it touches, the groups it addresses and the scenes it preloads.
	var units: Array = _row_units(sheet)
	for unit: Dictionary in units:
		var code: String = str(unit.get("code", ""))
		for reference: String in _node_references(code):
			var label: String = EventSheetSentence.object_of_reference(reference)
			if label.is_empty() or by_label.has(label):
				continue
			var declared: String = str(class_map.get(label, ""))
			var pack: String = behaviour_pack_of(label, class_map)
			order.append(_new_object_entry(by_label, label,
				"behaviour" if not pack.is_empty() else "node",
				pack if not pack.is_empty() else declared, reference))
		for singleton: String in _autoload_references(code, autoloads):
			if not by_label.has(singleton):
				order.append(_new_object_entry(by_label, singleton, "autoload", "",
					str(autoloads.get(singleton, ""))))
		for group_name: String in _group_references(code):
			if not by_label.has(group_name):
				order.append(_new_object_entry(by_label, group_name, "group", "", ""))
		for scene_path: String in _scene_references(code):
			var scene_label: String = scene_path.get_file().get_basename().to_pascal_case()
			if not by_label.has(scene_label):
				order.append(_new_object_entry(by_label, scene_label, "scene", "", scene_path, scene_path))
	_tally_usage(order, by_label, units)
	for index: int in order.size():
		(order[index] as Dictionary)["found_at"] = index
	order.sort_custom(_by_kind_order)
	return order


## A fresh census entry, registered under its label so a second sighting only tallies.
## `match_token` is the text the tally counts by when it differs from the label - a scene is named
## in code by its res:// path, never by the display name the rail shows it under.
static func _new_object_entry(by_label: Dictionary, label: String, kind: String,
		class_name_str: String, path: String, match_token: String = "") -> Dictionary:
	var entry: Dictionary = {
		"label": label, "kind": kind, "class": class_name_str, "path": path,
		"match": match_token if not match_token.is_empty() else label,
		"rows": 0, "verbs": PackedStringArray(), "signals": PackedStringArray()
	}
	by_label[label] = entry
	return entry


## Rail order: the kinds in their declared order, and within a kind the order they were found in,
## which is the order the file itself introduces them.
##
## The found-at tiebreaker is load-bearing, not decoration: `sort_custom` is NOT a stable sort, so
## without it two objects of the same kind could swap places between refreshes and the rail would
## reshuffle under the reader's cursor for no reason.
static func _by_kind_order(left: Dictionary, right: Dictionary) -> bool:
	var left_kind: int = Array(OBJECT_KINDS).find(str(left.get("kind", "")))
	var right_kind: int = Array(OBJECT_KINDS).find(str(right.get("kind", "")))
	if left_kind != right_kind:
		return left_kind < right_kind
	return int(left.get("found_at", 0)) < int(right.get("found_at", 0))


## One text unit per TOP-LEVEL row: every line of code in that row's subtree, joined. The rail's
## "N rows" is a count of these, so a number in the rail is a number of things a reader can click.
static func _row_units(sheet: EventSheetResource) -> Array:
	var units: Array = []
	for entry: Variant in sheet.events:
		var lines: PackedStringArray = PackedStringArray()
		_collect_code(entry, lines)
		if not lines.is_empty():
			units.append({"code": "\n".join(lines)})
	return units


## Everything under one row resource, however deeply it nests, rendered back into the ONE shape the
## scanners read: lines of GDScript-looking text.
##
## A lifted row does not hold code - it holds an object in one parameter and a verb in another - so
## an ACE row is written back out as the call it stands for (`$Health.take_damage(3)`). That way a
## hand-written line and the lifted row beside it are censused by exactly the same scanner, and a
## file that has been half-lifted cannot report two different object lists.
static func _collect_code(resource: Variant, into: PackedStringArray) -> void:
	if resource == null or not (resource is Resource):
		return
	var raw: RawCodeRow = resource as RawCodeRow
	if raw != null:
		into.append(_without_comments(raw.code))
		return
	var variable: LocalVariable = resource as LocalVariable
	if variable != null:
		into.append("%s = %s" % [variable.name, str(variable.default_value)])
		return
	var event_row: EventRow = resource as EventRow
	if event_row != null:
		_collect_ace_code(event_row.trigger, into)
		for condition: Variant in event_row.conditions:
			_collect_ace_code(condition, into)
		for action: Variant in event_row.actions:
			_collect_code(action, into)
		for pick_filter: Variant in event_row.pick_filters:
			var filter: PickFilter = pick_filter as PickFilter
			if filter != null:
				into.append(filter.collection_value if not filter.collection_value.is_empty()
					else filter.source_expression)
		for local: Variant in event_row.local_variables:
			_collect_code(local, into)
		for sub_event: Variant in event_row.sub_events:
			_collect_code(sub_event, into)
		return
	for container_property: String in ["events", "rows"]:
		var children: Variant = (resource as Resource).get(container_property)
		if children is Array and not (children as Array).is_empty():
			for child: Variant in (children as Array):
				_collect_code(child, into)
			return
	if (resource as Resource).get("params") != null or (resource as Resource).get("parameters") != null:
		_collect_ace_code(resource, into)
		return
	# Any other row kind - a preload, a signal declaration, a pack block - contributes its text.
	# A custom block keeps its content in a `fields` dictionary rather than in properties, which is
	# where a preload row's scene path lives; without it the rail was silently short every scene the
	# file spawns, with nothing to say it had missed one.
	var fields: Variant = (resource as Resource).get("fields")
	if fields is Dictionary:
		for value: Variant in (fields as Dictionary).values():
			into.append(str(value))
	for property_info: Dictionary in (resource as Resource).get_property_list():
		if int(property_info.get("type", TYPE_NIL)) != TYPE_STRING:
			continue
		var text: String = str((resource as Resource).get(str(property_info.get("name", ""))))
		if not text.is_empty():
			into.append(text)


## A block of GDScript with its comment lines dropped. Prose is not use: a doc comment that MENTIONS
## `$Health` describes the file, and censusing it put objects in the rail that no line of the file
## ever touches. Only whole-line comments go - a trailing `# note` after real code cannot introduce
## an object the code did not already name.
static func _without_comments(code: String) -> String:
	var kept: PackedStringArray = PackedStringArray()
	for line: String in code.split("\n"):
		if not line.strip_edges().begins_with("#"):
			kept.append(line)
	return "\n".join(kept)


## One lifted row written back out as the call it stands for. A row carrying both a target and a
## method reconstructs the call exactly; one carrying only a target names the member it touches; a
## row with neither contributes its parameter values, which is where any remaining object name hides.
static func _collect_ace_code(resource: Variant, into: PackedStringArray) -> void:
	if not (resource is Resource):
		return
	# Only the LIVE parameters. The legacy `parameters` mirror carries an unfilled row's DEFAULTS, and
	# a default target ("$Node") censused as a real reference put a node in the rail that no line of
	# the file ever names.
	var params: Variant = (resource as Resource).get("params")
	if not (params is Dictionary):
		return
	var params_dict: Dictionary = params
	var target: String = str(params_dict.get("target", "")).strip_edges()
	var method: String = str(params_dict.get("method", "")).strip_edges()
	var property_name: String = str(params_dict.get("property", params_dict.get("var_name", ""))).strip_edges()
	if not target.is_empty() and not method.is_empty():
		into.append("%s.%s(%s)" % [target, method, str(params_dict.get("args", ""))])
	elif not target.is_empty() and not property_name.is_empty():
		into.append("%s.%s" % [target, property_name])
	elif not target.is_empty():
		into.append(target)
	for value: Variant in params_dict.values():
		into.append(str(value))


## How many top-level rows each object appears in, and which verbs and signals it is used with.
static func _tally_usage(order: Array, by_label: Dictionary, units: Array) -> void:
	for unit: Dictionary in units:
		var code: String = str(unit.get("code", ""))
		var seen: Dictionary = {}
		for entry: Dictionary in order:
			var label: String = str(entry.get("label", ""))
			var token: String = str(entry.get("match", label))
			if seen.has(label) or not _mentions(code, token):
				continue
			seen[label] = true
			entry["rows"] = int(entry.get("rows", 0)) + 1
			_collect_members(code, label, entry)
	for entry: Dictionary in order:
		by_label[str(entry.get("label", ""))] = entry


## The verbs and signals one object is used with, in the order the code introduces them. A member
## followed by `(` is a verb; one connected or awaited is a signal.
static func _collect_members(code: String, label: String, entry: Dictionary) -> void:
	var verbs: PackedStringArray = entry.get("verbs", PackedStringArray())
	var signals_used: PackedStringArray = entry.get("signals", PackedStringArray())
	for prefix: String in ["%s." % label, "$%s." % label, "%%%s." % label]:
		var from: int = code.find(prefix)
		while from >= 0:
			var after: int = from + prefix.length()
			var member: String = leading_identifier(code.substr(after))
			if not member.is_empty():
				var tail: String = code.substr(after + member.length())
				if tail.begins_with("("):
					var verb: String = EventSheetSentence.verb_words(member)
					if not verb.is_empty() and Array(verbs).find(verb) < 0:
						verbs.append(verb)
				elif tail.begins_with(".connect") or tail.begins_with(".emit") or tail.begins_with(".disconnect"):
					if Array(signals_used).find(member) < 0:
						signals_used.append(member)
			from = code.find(prefix, after)
	entry["verbs"] = verbs
	entry["signals"] = signals_used


## True when a piece of code names an object - as a whole word, so `hp` does not match `hp_bar`.
static func _mentions(code: String, label: String) -> bool:
	if label.is_empty():
		return false
	var from: int = code.find(label)
	while from >= 0:
		var before_ok: bool = from == 0 or not _is_word_character(code[from - 1])
		var after_at: int = from + label.length()
		var after_ok: bool = after_at >= code.length() or not _is_word_character(code[after_at])
		if before_ok and after_ok:
			return true
		from = code.find(label, from + 1)
	return false


static func _is_word_character(character: String) -> bool:
	return character == "_" or character.to_lower() != character.to_upper() or character.is_valid_int()


## Every `$Node` / `%Unique` reference written in a piece of code.
##
## The name must open with a capital, which is what keeps a format string out of the object list:
## `"%s"` and `"%d"` are the same two characters as a unique-name reference, and one phantom object
## in the rail costs a reader more than a lowercase node name that goes unlisted (that node still
## reaches the rail through its @onready declaration, which is typed and unambiguous).
static func _node_references(code: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for index: int in code.length():
		var sigil: String = code[index]
		if sigil != "$" and sigil != "%":
			continue
		var head: String = code[index + 1] if index + 1 < code.length() else ""
		if head.is_empty() or head != head.to_upper() or head == head.to_lower():
			continue
		var body: String = ""
		var walk: int = index + 1
		while walk < code.length() and (_is_word_character(code[walk]) or code[walk] == "/"):
			body += code[walk]
			walk += 1
		if not body.is_empty():
			found.append(sigil + body)
	return found


## Every registered singleton a piece of code names as an object (`Game.score`), so an autoload that
## is merely mentioned in a string is not mistaken for one that is used.
static func _autoload_references(code: String, autoloads: Dictionary) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for singleton: Variant in autoloads.keys():
		var name_text: String = str(singleton)
		if code.contains("%s." % name_text) and _mentions(code, name_text):
			found.append(name_text)
	return found


## The group names a piece of code addresses. Only the calls that TAKE a group name are read, so an
## ordinary string never becomes a phantom object in the rail.
static func _group_references(code: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for marker: String in ["get_nodes_in_group(", "add_to_group(", "remove_from_group(",
			"is_in_group(", "call_group(", "get_first_node_in_group(", "notify_group("]:
		var from: int = code.find(marker)
		while from >= 0:
			var after: int = from + marker.length()
			var rest: String = code.substr(after).strip_edges()
			# call_group takes the group SECOND ("group", "method"); the first argument is a flag on
			# some overloads, so only a leading string literal is read and anything else is skipped.
			if rest.begins_with("\"") or rest.begins_with("&\""):
				var quoted: String = rest.trim_prefix("&").substr(1)
				var close_at: int = quoted.find("\"")
				if close_at > 0:
					found.append(quoted.substr(0, close_at))
			from = code.find(marker, after)
	return found


## Every packed scene a piece of code names. Any `res://` path ending in a scene extension counts,
## whether it was written as a `preload("…")` call or arrived as a preload row's stored field - the
## two spellings are the same object, and matching only the call shape listed the scenes a file
## typed while missing the ones it declared.
static func _scene_references(code: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var from: int = code.find("res://")
	while from >= 0:
		var walk: int = from
		while walk < code.length() and not code[walk] in ["\"", "'", " ", "\t", "\n", ")", ","]:
			walk += 1
		var path: String = code.substr(from, walk - from)
		if path.ends_with(".tscn") or path.ends_with(".scn"):
			found.append(path)
		from = code.find("res://", from + 1)
	return found


## The muted note one census entry wears in the rail: what kind of thing it is, the class or path it
## resolves to when that adds anything, and how many rows use it.
static func object_note(entry: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var kind: String = str(entry.get("kind", ""))
	var kind_word: String = str(OBJECT_KIND_WORDS.get(kind, kind))
	var class_name_str: String = str(entry.get("class", "")).strip_edges()
	var path: String = str(entry.get("path", "")).strip_edges()
	if kind == "script":
		parts.append(EventSheetL10n.translate(kind_word))
		if not class_name_str.is_empty():
			parts.append(class_name_str)
		return " · ".join(parts)
	if path.begins_with("$") or path.begins_with("%"):
		parts.append(path)
	else:
		parts.append(EventSheetL10n.translate(kind_word))
	if not class_name_str.is_empty() and class_name_str != parts[0]:
		parts.append(class_name_str)
	var rows: int = int(entry.get("rows", 0))
	if rows > 0:
		parts.append(EventSheetL10n.translate("%d rows") % rows if rows != 1 else EventSheetL10n.translate("1 row"))
	return " · ".join(parts)


## The icon one census entry draws: its class picture for a node, the globe for an autoload, and
## nothing for a group (which is a name, not a thing with a picture).
static func object_icon(entry: Dictionary, class_map: Dictionary) -> Texture2D:
	if str(entry.get("kind", "")) == "autoload":
		return autoload_icon()
	var class_name_str: String = str(entry.get("class", "")).strip_edges()
	if not class_name_str.is_empty() and ClassDB.class_exists(class_name_str):
		return ACEPickerDialog.editor_icon(class_name_str)
	return class_icon_for(str(entry.get("label", "")), class_map)
