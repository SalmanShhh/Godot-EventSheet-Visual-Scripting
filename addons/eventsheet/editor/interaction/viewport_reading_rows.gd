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
	return {
		"script_object": script_object_name(sheet),
		"engine_properties": engine_property_set(sheet),
		"signal_params": signal_parameter_map(sheet)
	}


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
	var host_class: String = sheet.host_class.strip_edges()
	return host_class if not host_class.is_empty() and host_class != "Node" else ""


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


## M27. Construct's words for the two tick triggers. The trigger ids are untouched - this is the
## reading only, so a sheet still stores (and compiles to) exactly what it did before.
static func tick_trigger_words(trigger_id: String, display_text: String) -> String:
	match trigger_id:
		"OnPhysicsProcess":
			return "%s %s" % [EventSheetL10n.translate("Every tick"), EventSheetL10n.translate("(physics)")]
		"OnProcess":
			return "%s %s" % [EventSheetL10n.translate("Every tick"), EventSheetL10n.translate("(draw)")]
	return display_text


## M33. Construct's own words for a loop row, and the object it belongs to.
##
## Returns {"text", "object"} - `object` empty for the System loops, and the host for a loop over
## another object's children, which Construct draws as that object's own For each. The loop rows
## themselves are unchanged: this is what they SAY, never what they are.
static func loop_words(kind: int, iterator_name: String, collection: String) -> Dictionary:
	var iterator: String = iterator_name.strip_edges()
	var source: String = collection.strip_edges()
	match kind:
		PickFilter.CollectionKind.REPEAT:
			var bounds: PackedStringArray = EventSheetSentence.split_top_level(source, ", ")
			if bounds.size() == 2:
				# Construct's For loop is INCLUSIVE at both ends, and `range(2, 8)` stops at 7 - so the
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
	# `for child in host.get_children()` is that object's own For each, exactly as Construct draws it -
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


## `8` -> `7`, so a half-open Godot range reads as the inclusive Construct one. Empty when the bound
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
		var node_reference: String = variable.default_value.strip_edges()
		if node_reference.begins_with("%") or node_reference.begins_with("$"):
			map[node_reference] = declared_type
			map[node_reference.substr(1)] = declared_type
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
## reads a node out of the scene. Those are the ones that become Construct's object list.
static func is_object_declaration(variable: LocalVariable) -> bool:
	if variable == null or not variable.onready:
		return false
	var value: String = variable.default_value.strip_edges()
	return value.begins_with("%") or value.begins_with("$")


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
