# Godot EventSheets - the Inspector facts a setting row shows: limits, choices, filters, swatches.
#
# An event sheet's properties panel shows a value's RANGE and its CHOICES, not just its number. A
# tuned Godot script carries exactly the same facts - `@export_range`, `@export_enum`,
# `@export_file`, `@export_flags`, `@export_multiline`, `@export_node_path`, a Color - and until this
# existed the setting row threw all of them away: `mode = 0` where the Inspector says a dropdown
# reading "Walk", `speed = 5` where the Inspector says a slider from 0 to 20 in half steps.
#
# WHERE THE FACTS COME FROM. The importer already lifts every one of these hint families into
# STRUCTURED attributes (byte-gated: a hint it cannot reproduce stays verbatim in `export_hint`), so
# this reads what is already stored rather than re-parsing the file. Both places are read, because a
# hint that failed the structured lift - a two-argument `@export_range(0, 1)`, an `@export_multiline`
# - is still a fact the reader wants, and it is sitting right there in `export_hint`.
#
# PURE READING. Nothing here is written back, nothing is edited through it, and a variable with no
# hints returns an empty fact set so its row draws exactly as it did before.
@tool
class_name EventSheetSettingFacts
extends RefCounted

## The primary colour words, the ones a reader would actually say out loud. A colour outside this set
## keeps its numbers - inventing a name for `(0.31, 0.44, 0.29, 1)` would be less honest than the
## value, and the swatch beside it already answers "what colour is that".
const COLOUR_WORDS: Dictionary = {
	"1,1,1,1": "white",
	"0,0,0,1": "black",
	"1,0,0,1": "red",
	"0,1,0,1": "green",
	"0,0,1,1": "blue",
	"1,1,0,1": "yellow",
	"0,1,1,1": "cyan",
	"1,0,1,1": "magenta",
	"0,0,0,0": "transparent"
}


## Every Inspector fact one variable carries, as:
##   {"type_word": String, "value_text": String, "note": String, "swatch": Color or null}
## Empty strings mean "leave the row's own reading alone" - the type chip, the value and the muted
## note all keep whatever they already said.
static func facts(variable: LocalVariable) -> Dictionary:
	var found: Dictionary = {
		"type_word": "", "value_text": "", "note": "", "swatch": null,
		# A button has no value to show: `= _bake` is which function it calls, which the note
		# says in words. `name_text` overrides the name the row leads with for the same reason: the
		# button's own label is what the Inspector shows on it.
		"hide_value": false, "name_text": ""
	}
	if variable == null:
		return found
	var attributes: Dictionary = variable.attributes if variable.attributes is Dictionary else {}
	var hint: String = variable.export_hint.strip_edges()
	_apply_tool_button(found, variable, attributes)
	_apply_range(found, variable, attributes, hint)
	_apply_choices(found, variable, attributes)
	_apply_file(found, attributes, hint)
	_apply_multiline(found, hint)
	_apply_flags(found, attributes)
	_apply_node_path(found, variable, attributes)
	_apply_colour(found, variable)
	return found


## An Inspector button is the smallest editor tool there is - one line - and it reads as one:
## `button Bake  in the Inspector · calls Bake`. The row leads with the button's own label rather
## than the variable name behind it, and shows no value at all, because `= _bake` is not a setting a
## reader tunes - it is which function the button calls, which the note says in words.
static func _apply_tool_button(found: Dictionary, variable: LocalVariable, attributes: Dictionary) -> void:
	if not (attributes.get("tool_button") is Dictionary):
		return
	var button: Dictionary = attributes["tool_button"] as Dictionary
	found["type_word"] = EventSheetL10n.translate("button")
	found["hide_value"] = true
	var label: String = str(button.get("label", "")).strip_edges()
	if not label.is_empty():
		found["name_text"] = label
	var called: String = str(variable.default_value).strip_edges().trim_prefix("_").capitalize()
	found["note"] = EventSheetL10n.translate("in the Inspector") if called.is_empty() \
		else "%s · %s %s" % [EventSheetL10n.translate("in the Inspector"),
			EventSheetL10n.translate("calls"), called]


## `@export_range(0, 20, 0.5)` reads "0 to 20, step 0.5"; a 0-to-1 range is a PERCENT, which is how
## the Inspector shows it and how anybody talks about it, so the value itself reads "50%".
static func _apply_range(found: Dictionary, variable: LocalVariable, attributes: Dictionary, hint: String) -> void:
	var bounds: Dictionary = {}
	if attributes.get("range") is Dictionary:
		bounds = attributes["range"] as Dictionary
	elif hint.begins_with("@export_range("):
		bounds = _bounds_from_hint(hint)
	if bounds.is_empty():
		return
	var low: String = _trim_number(str(bounds.get("min", "")))
	var high: String = _trim_number(str(bounds.get("max", "")))
	if low.is_empty() or high.is_empty():
		return
	if low == "0" and high == "1":
		var fraction: float = float(str(variable.default_value))
		found["value_text"] = "%d%%" % int(round(fraction * 100.0))
		return
	var step: String = _trim_number(str(bounds.get("step", "")))
	found["note"] = EventSheetL10n.translate("%s to %s") % [low, high] if step.is_empty() \
		else EventSheetL10n.translate("%s to %s, step %s") % [low, high, step]


## A fixed set of choices is a COMBO - the property type the sheet's own plugins declare - and it
## reads as the chosen LABEL, never as the number behind it. Both spellings arrive here: an int-backed
## `@export_enum("Walk", "Run", "Fly")` (structured into enum_values) and a String one (the sheet's
## own `options` list).
static func _apply_choices(found: Dictionary, variable: LocalVariable, attributes: Dictionary) -> void:
	var labels: PackedStringArray = PackedStringArray()
	var chosen: String = ""
	if attributes.get("enum_values") is Array and not (attributes["enum_values"] as Array).is_empty():
		var index: int = int(str(variable.default_value)) if str(variable.default_value).is_valid_int() else 0
		var position: int = 0
		for entry: Variant in (attributes["enum_values"] as Array):
			if not (entry is Dictionary):
				continue
			var label: String = str((entry as Dictionary).get("label", ""))
			labels.append(label)
			# `"Fly:7"` pins its own number; an unnumbered entry is simply its position in the list.
			var declared: String = str((entry as Dictionary).get("value", "")).strip_edges()
			var number: int = int(declared) if declared.is_valid_int() else position
			if number == index:
				chosen = label
			position += 1
	elif not variable.options.is_empty():
		labels = variable.options
		chosen = str(variable.default_value)
	if labels.is_empty():
		return
	found["type_word"] = EventSheetL10n.translate("combo")
	if not chosen.is_empty():
		found["value_text"] = chosen
	found["note"] = " / ".join(labels)


## A path knob says WHAT it picks - a file (with the filters it accepts) or a folder - because "text"
## is the least useful true thing anybody could say about it.
static func _apply_file(found: Dictionary, attributes: Dictionary, hint: String) -> void:
	var spec: Dictionary = attributes["file"] as Dictionary if attributes.get("file") is Dictionary else {}
	if spec.is_empty():
		if hint == "@export_dir" or hint == "@export_global_dir":
			found["type_word"] = EventSheetL10n.translate("folder")
		elif hint.begins_with("@export_file") or hint.begins_with("@export_global_file"):
			found["type_word"] = EventSheetL10n.translate("file")
		return
	if str(spec.get("mode", "")) == "dir":
		found["type_word"] = EventSheetL10n.translate("folder")
		return
	found["type_word"] = EventSheetL10n.translate("file")
	if spec.get("filters") is Array and not (spec["filters"] as Array).is_empty():
		var filters: PackedStringArray = PackedStringArray()
		for filter_text: Variant in (spec["filters"] as Array):
			filters.append(str(filter_text))
		found["note"] = " ".join(filters)


## `@export_multiline` is text with room to breathe - the same word, with the one fact that makes it
## different said in the note.
static func _apply_multiline(found: Dictionary, hint: String) -> void:
	if hint != "@export_multiline":
		return
	found["type_word"] = EventSheetL10n.translate("text")
	found["note"] = EventSheetL10n.translate("multiline")


## A bit field reads as flags with the names of the bits, which is the whole reason the author wrote
## the names instead of a number. The layer grids (`@export_flags_2d_physics`) name their grid.
static func _apply_flags(found: Dictionary, attributes: Dictionary) -> void:
	if attributes.get("flags") is Array and not (attributes["flags"] as Array).is_empty():
		var labels: PackedStringArray = PackedStringArray()
		for entry: Variant in (attributes["flags"] as Array):
			if entry is Dictionary:
				labels.append(str((entry as Dictionary).get("label", "")))
		found["type_word"] = EventSheetL10n.translate("flags")
		found["note"] = " / ".join(labels)
		return
	var layers: String = str(attributes.get("layers", "")).strip_edges()
	if layers.is_empty():
		return
	found["type_word"] = EventSheetL10n.translate("flags")
	found["note"] = layers.replace("_", " ")


## A NodePath points at something in the scene, so it says so - and lists the classes it will accept
## when the author narrowed it.
static func _apply_node_path(found: Dictionary, variable: LocalVariable, attributes: Dictionary) -> void:
	var types: Array = attributes["node_path_types"] as Array if attributes.get("node_path_types") is Array else []
	if types.is_empty() and variable.type_name.strip_edges() != "NodePath":
		return
	found["type_word"] = EventSheetL10n.translate("node path")
	if types.is_empty():
		return
	var names: PackedStringArray = PackedStringArray()
	for entry: Variant in types:
		names.append(str(entry))
	found["note"] = " / ".join(names)


## A colour shows itself. The swatch is the fact; the word beside it is a courtesy for the handful of
## colours anybody names out loud, and every other colour keeps the numbers it was written with.
static func _apply_colour(found: Dictionary, variable: LocalVariable) -> void:
	# A colour is ALWAYS a swatch, whether or not the line bothered to declare the type:
	# `var tint := Color.WHITE` is as much a colour as `var tint: Color = ...`, and the swatch is the
	# half of the row a reader actually uses.
	if variable.type_name.strip_edges() != "Color" and not is_colour_literal(str(variable.default_value)):
		return
	var colour: Color = _colour_of(variable)
	found["swatch"] = colour
	# The word for the colours anybody says out loud, else the hex - never raw floats. The hex trails
	# a named colour as its muted note, because "#ffffff" is the thing you paste somewhere else.
	var word: String = colour_word(colour)
	if word.is_empty():
		found["value_text"] = colour_hex(colour)
		return
	found["value_text"] = word
	if found["note"] == "":
		found["note"] = colour_hex(colour)


## `#rrggbb`, or `#rrggbbaa` when the colour is not fully opaque - the spelling everybody pastes.
static func colour_hex(colour: Color) -> String:
	return "#%s" % (colour.to_html(false) if is_equal_approx(colour.a, 1.0) else colour.to_html(true))


## True when a value was WRITTEN as a colour - `Color.RED`, `Color(1, 0.6, 0.2)`, `Color("#ff9b3c")`.
static func is_colour_literal(value_text: String) -> bool:
	var text: String = value_text.strip_edges()
	# `Color.from_hsv(...)` is a CALL, not the colour word red - a swatch for it would be a guess.
	if text.begins_with("Color.") and not text.contains("("):
		return true
	return text.begins_with("Color(")


## The colour a variable holds, whichever way it was written - a real Color value, a `Color.RED`
## constant, a `Color(1, 1, 1, 1)` literal or an "#ff0000" string.
static func _colour_of(variable: LocalVariable) -> Color:
	if variable.default_value is Color:
		return variable.default_value as Color
	var text: String = str(variable.default_value).strip_edges()
	if text.begins_with("Color."):
		return Color.from_string(text.trim_prefix("Color.").replace("_", "").to_lower(), Color.WHITE)
	if text.begins_with("Color("):
		var numbers: PackedStringArray = text.trim_prefix("Color(").trim_suffix(")").split(",")
		if numbers.size() >= 3:
			return Color(
				float(numbers[0]), float(numbers[1]), float(numbers[2]),
				float(numbers[3]) if numbers.size() > 3 else 1.0
			)
	return Color.from_string(text, Color.WHITE)


## The word for a colour, "" when it is not one of the primaries.
static func colour_word(colour: Color) -> String:
	var key: String = "%s,%s,%s,%s" % [
		_trim_number(str(colour.r)), _trim_number(str(colour.g)),
		_trim_number(str(colour.b)), _trim_number(str(colour.a))
	]
	var word: String = str(COLOUR_WORDS.get(key, ""))
	return EventSheetL10n.translate(word) if not word.is_empty() else ""


## The two bounds of a range hint the importer left verbatim - `@export_range(0, 1)` has too few
## arguments for the structured lift, and a 0-to-1 range is exactly the one that reads as a percent.
static func _bounds_from_hint(hint: String) -> Dictionary:
	var open_paren: int = hint.find("(")
	var close_paren: int = hint.rfind(")")
	if open_paren < 0 or close_paren <= open_paren:
		return {}
	var arguments: PackedStringArray = hint.substr(open_paren + 1, close_paren - open_paren - 1).split(",")
	if arguments.size() < 2:
		return {}
	var bounds: Dictionary = {"min": arguments[0].strip_edges(), "max": arguments[1].strip_edges()}
	if arguments.size() > 2 and not arguments[2].strip_edges().begins_with("\""):
		bounds["step"] = arguments[2].strip_edges()
	return bounds


## A whole number written as a float drops the tail GDScript needs and a reader does not - the same
## rule the value itself reads by, so "0.0 to 20.0" and "0 to 20" never both appear.
static func _trim_number(text: String) -> String:
	var trimmed: String = text.strip_edges()
	if not trimmed.contains("."):
		return trimmed
	if not trimmed.is_valid_float():
		return trimmed
	var whole: String = trimmed.split(".")[0]
	return whole if float(trimmed) == float(whole) else trimmed
