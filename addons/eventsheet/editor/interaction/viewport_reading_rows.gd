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
