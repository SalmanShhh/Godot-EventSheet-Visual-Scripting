@tool
class_name EventSheetInspectorLooks
extends RefCounted

## THE INSPECTOR LOOKS: every way a variable can look in Godot's Inspector, as one table the
## variable dialog's "Inspector look" dropdown, its detail fields and the preview card all read.
##
## A look is {id, label, types, tip, writes, fields}:
##   types   the variable types it applies to ([] = any type the Inspector can show)
##   tip     the sentence its dropdown option carries on hover
##   writes  the annotation it compiles to, as the hover's second line
##   fields  its details, each [key, label, kind, default, hint]; kind is "number", "text",
##           "pick" (hint = the choices) or "tick" (hint = the words beside the box)
##
## The table is English on purpose: each label, tip and detail word is the key its translation is filed
## under, and label() / description() / plain_label() hand it out in the editor's language.
##
## fold() turns a look and its detail values into the attribute keys the compiler reads, and
## unfold() reads them back, so a variable reopens on the look and the details it was saved with.
## The keys are the compiler's own (range, flags, layers, file, drawer, ...) - this file only
## chooses which of them a look sets.

const MIN_MAX_STEP: Array = [["min", "Min", "number", "0"], ["max", "Max", "number", "100"], ["step", "Step", "number", "1"]]
const SLIDER_EXTRAS: Array = [["unit", "Unit", "text", "", "px, s, %, tiles/s"],
	["or_greater", "Above max", "tick", false, "allow typing above the max (or_greater)"],
	["or_less", "Below min", "tick", false, "allow typing below the min (or_less)"]]
const LAYER_KINDS: Array = ["2d_physics", "2d_render", "2d_navigation", "3d_physics", "3d_render", "3d_navigation", "avoidance"]
const REACH: Array = ["project", "anywhere on disk"]
const VECTOR_TYPES: Array = ["Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Vector4i"]

const LOOKS: Array[Dictionary] = [
	{"id": "slider", "label": "Slider", "types": ["int", "float"], "writes": "@export_range(0, 100, 1)",
		"tip": "A slider between a min and a max, with an optional unit after the number.",
		"fields": MIN_MAX_STEP + SLIDER_EXTRAS},
	{"id": "angle", "label": "Angle in degrees", "types": ["float"], "writes": "@export_range(0, 360, 0.1, \"radians_as_degrees\")",
		"tip": "An angle: stored in radians, shown and typed in degrees.",
		"fields": MIN_MAX_STEP + [["angle", "Stored as", "pick", "radians_as_degrees", ["radians_as_degrees", "degrees"]]]},
	{"id": "exp_slider", "label": "Exponential slider", "types": ["float"], "writes": "@export_range(0.01, 100, 0.01, \"exp\")",
		"tip": "A slider with fine control near the low end: zoom, volume, scale.", "fields": MIN_MAX_STEP},
	{"id": "no_handle", "label": "Slider, no handle", "types": ["int", "float"], "writes": "@export_range(0, 100, 1, \"hide_slider\")",
		"tip": "A number box kept between a min and a max, with no slider drawn.", "fields": MIN_MAX_STEP},
	{"id": "progress_bar", "label": "Progress bar", "types": ["int", "float"], "writes": "@export_custom(PROPERTY_HINT_NONE, \"es_drawer:progress_bar…\")",
		"tip": "A filled bar between a min and a max. Without this plugin it is a plain number.",
		"fields": [["min", "Min", "number", "0"], ["max", "Max", "number", "100"]]},
	{"id": "number_choices", "label": "Dropdown of numbers", "types": ["int"], "writes": "@export_enum(\"Slow:30\", \"Fast:60\")",
		"tip": "A dropdown where each word stands for a number.",
		"fields": [["choices", "Choices", "text", "", "Slow:30, Fast:60"]]},
	{"id": "flags", "label": "Checkbox flags", "types": ["int"], "writes": "@export_flags(\"Fire\", \"Ice\")",
		"tip": "Several on/off boxes packed into one number.",
		"fields": [["flags", "Flags", "text", "", "Fire, Ice, Poison"]]},
	{"id": "layers", "label": "Layers grid", "types": ["int"], "writes": "@export_flags_2d_physics",
		"tip": "The little grid of layer toggles physics and rendering use.",
		"fields": [["layers", "Which layers", "pick", "2d_physics", LAYER_KINDS]]},
	{"id": "easing", "label": "Easing curve", "types": ["float"], "writes": "@export_exp_easing(\"attenuation\")",
		"tip": "An easing-curve handle for a 0 to 1 value: falloff, attenuation.",
		"fields": [["curve", "Curve", "pick", "attenuation", ["plain", "attenuation", "positive_only", "both"]]]},
	{"id": "unit", "label": "Number with its unit", "types": ["float"], "writes": "@export_custom(PROPERTY_HINT_NONE, \"es_drawer:unit…\")",
		"tip": "A number with a unit dropdown beside it - switching the unit changes the reading, never the stored value.",
		"fields": [["units", "Units", "text", "", "px|world|screen, store=world"]]},
	{"id": "file", "label": "File picker", "types": ["String"], "writes": "@export_file(\"*.png\", \"*.webp\")",
		"tip": "Pick a file, with a filter on the kinds it accepts.",
		"fields": [["filters", "Filters", "text", "", "*.png, *.webp"], ["reach", "Reach", "pick", "project", REACH],
			["plain_path", "Path as typed", "tick", false, "keep the path, never a uid:// reference"]]},
	{"id": "folder", "label": "Folder picker", "types": ["String"], "writes": "@export_dir",
		"tip": "Pick a folder.", "fields": [["reach", "Reach", "pick", "project", REACH]]},
	{"id": "multiline", "label": "Big text box", "types": ["String"], "writes": "@export_multiline",
		"tip": "A tall text box for several lines.", "fields": []},
	{"id": "placeholder", "label": "Hint inside the box", "types": ["String"], "writes": "@export_placeholder(\"res://…\")",
		"tip": "Grey hint text shown while the box is empty.", "fields": [["hint", "Hint", "text", "", "shown while empty"]]},
	{"id": "choices", "label": "Dropdown", "types": ["String"], "writes": "@export_enum(\"Round\", \"Laser\")",
		"tip": "A dropdown of fixed choices.", "fields": [["choices", "Choices", "text", "", "Round, Laser, Rocket"]]},
	{"id": "suggestions", "label": "Dropdown, free typing", "types": ["String"], "writes": "@export_custom(PROPERTY_HINT_ENUM_SUGGESTION, \"Round,Laser\")",
		"tip": "A dropdown of suggestions that still accepts anything typed.",
		"fields": [["choices", "Suggestions", "text", "", "Round, Laser"]]},
	{"id": "toggle_row", "label": "Toggle buttons", "types": ["String"], "writes": "@export_custom(PROPERTY_HINT_NONE, \"es_drawer:toggle_row…\")",
		"tip": "A row of buttons, one per choice. Without this plugin it is a plain text box.",
		"fields": [["choices", "Choices", "text", "", "easy, normal, hard"]]},
	{"id": "password", "label": "Password dots", "types": ["String"], "writes": "@export_custom(PROPERTY_HINT_PASSWORD, \"\")",
		"tip": "Typed text shows as dots.", "fields": []},
	{"id": "expression", "label": "Expression field", "types": ["String"], "writes": "@export_custom(PROPERTY_HINT_EXPRESSION, \"\")",
		"tip": "A box meant for a math expression.", "fields": []},
	{"id": "no_alpha", "label": "Solid colour, no alpha", "types": ["Color"], "writes": "@export_color_no_alpha",
		"tip": "A colour swatch with no transparency slider.", "fields": []},
	{"id": "swatch_row", "label": "Swatch row", "types": ["Color"], "writes": "@export_custom(PROPERTY_HINT_NONE, \"es_drawer:swatch_row\")",
		"tip": "A row of colour swatches to pick from. Without this plugin it is a plain colour.", "fields": []},
	{"id": "link", "label": "Linked axes", "types": VECTOR_TYPES, "writes": "@export_custom(PROPERTY_HINT_LINK, \"\")",
		"tip": "Drag one axis and the others follow.", "fields": []},
	{"id": "vector_dial", "label": "Direction dial", "types": ["Vector2"], "writes": "@export_custom(PROPERTY_HINT_NONE, \"es_drawer:vector_dial…\")",
		"tip": "The vector as an arrow on a dial. Without this plugin it is X and Y fields.",
		"fields": [["max", "Reach", "number", "100"]]},
	{"id": "min_max", "label": "Min-max range", "types": ["Vector2"], "writes": "@export_custom(PROPERTY_HINT_NONE, \"es_drawer:min_max…\")",
		"tip": "Two handles on one slider: x is the low end, y the high end.",
		"fields": [["min", "Min", "number", "0"], ["max", "Max", "number", "100"]]},
	{"id": "corners", "label": "Four corners", "types": ["Vector4"], "writes": "@export_custom(PROPERTY_HINT_NONE, \"es_drawer:corners\")",
		"tip": "One number for all four corners, with a button that opens a box per corner.", "fields": []},
	{"id": "node_path", "label": "Node path, filtered", "types": ["NodePath"], "writes": "@export_node_path(\"Marker2D\")",
		"tip": "Pick a scene node, limited to the classes you list.",
		"fields": [["types", "Only these types", "text", "", "Marker2D, Node2D"]]},
	{"id": "tool_button", "label": "Inspector button", "types": ["Callable"], "writes": "@export_tool_button(\"Bake\", \"Bake\")",
		"tip": "A button in the Inspector that runs the function in the editor. The sheet has to be a Tool sheet.",
		"fields": [["label", "Button label", "text", "", "what the button says"], ["icon", "Editor icon", "text", "", "an editor icon name, e.g. Bake"]]},
	{"id": "texture_preview", "label": "Texture preview", "types": ["Texture2D"], "writes": "@export_custom(PROPERTY_HINT_NONE, \"es_drawer:texture_preview\")",
		"tip": "A bigger picture of the texture under the slot.", "fields": []},
	{"id": "curve_editor", "label": "Curve preview", "types": ["Curve"], "writes": "@export_custom(PROPERTY_HINT_NONE, \"es_drawer:curve_editor\")",
		"tip": "A picture of the curve; its points are shaped in Godot's own curve editor.", "fields": []},
	{"id": "table", "label": "Editable table", "types": ["Array", "Array[Dictionary]"], "writes": "@export_custom(PROPERTY_HINT_NONE, \"es_drawer:table…\")",
		"tip": "Every element a row of cells. Columns: name:type (String, int, float, bool, color, enum(a|b)).",
		"fields": [["columns", "Columns", "text", "", "item:String, count:int"]]},
	{"id": "table_row", "label": "Pick a row of a data table", "types": ["int"], "writes": "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:table_row:drops:name\")",
		"tip": "A dropdown of the rows of a data table, shown by their name column. The file still stores the row's number.",
		"fields": [["table", "Table", "text", "", "the table variable, e.g. drops"], ["name_column", "Name column", "text", "name", "the column that names a row"]]},
	{"id": "custom", "label": "Your own hint", "types": [], "writes": "@export_custom(PROPERTY_HINT_…, \"…\", PROPERTY_USAGE_…)",
		"tip": "Any PROPERTY_HINT_* with its hint text, and the usage flags when they matter.",
		"fields": [["hint", "Hint", "text", "PROPERTY_HINT_NONE", "PROPERTY_HINT_…"], ["text", "Hint text", "text", "", "optional"],
			["usage", "Usage", "text", "", "e.g. PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY"]]},
	{"id": "storage", "label": "Saved but hidden", "types": [], "writes": "@export_storage",
		"tip": "Saved with the scene but not shown in the Inspector: data a tool writes.", "fields": []},
]

## What the no-look choice is called for each type: the Inspector's own editor for it.
const PLAIN_LABELS: Dictionary = {"int": "Plain number", "float": "Plain number", "String": "Plain text",
	"bool": "Checkbox", "Color": "Colour with alpha", "NodePath": "Node path", "Callable": "A function value"}


## The looks a variable of `type_name` can wear, in the table's order.
static func for_type(type_name: String) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for look: Dictionary in LOOKS:
		var types: Array = look.get("types", [])
		if types.is_empty() or types.has(type_name):
			output.append(look)
	return output


static func by_id(look_id: String) -> Dictionary:
	for look: Dictionary in LOOKS:
		if str(look.get("id")) == look_id:
			return look
	return {}


## The no-look choice's name for a type ("Plain number"), in the editor's language.
static func plain_label(type_name: String) -> String:
	if VECTOR_TYPES.has(type_name):
		return EventSheetL10n.translate("Axis fields")
	if PLAIN_LABELS.has(type_name):
		return EventSheetL10n.translate(str(PLAIN_LABELS[type_name]))
	return EventSheetL10n.translate("Its own editor")


## A look's name on its dropdown option, in the editor's language.
static func label(look: Dictionary) -> String:
	return EventSheetL10n.translate(str(look.get("label", "")))


## A look's hover: what it shows, then the annotation it writes.
static func description(look: Dictionary) -> String:
	return "%s\n%s" % [EventSheetL10n.translate(str(look.get("tip", ""))),
		EventSheetL10n.translate("Writes %s") % str(look.get("writes", ""))]


## The attributes a look writes for `values` (its detail fields by key). A String dropdown's
## choices are not an attribute but the variable's own options, so they come back under "options".
static func fold(look_id: String, values: Dictionary, type_name: String) -> Dictionary:
	var text: Callable = func(key: String) -> String: return str(values.get(key, "")).strip_edges()
	match look_id:
		"slider", "angle", "exp_slider", "no_handle":
			var spec: Dictionary = _range(values)
			if look_id == "slider":
				for flag: String in ["or_greater", "or_less"]:
					if bool(values.get(flag, false)):
						spec[flag] = true
				if not text.call("unit").is_empty() and not text.call("unit").contains("\""):
					spec["suffix"] = text.call("unit")
			elif look_id == "angle":
				spec["angle"] = text.call("angle") if text.call("angle") == "degrees" else "radians_as_degrees"
			else:
				spec["exp" if look_id == "exp_slider" else "hide_slider"] = true
			return {"range": spec}
		"progress_bar", "min_max":
			var bounds: Dictionary = _range(values)
			bounds["step"] = "1"
			return {"drawer": look_id, "range": bounds}
		"vector_dial":
			return {"drawer": look_id, "range": {"min": "0", "max": _or(text.call("max"), "100"), "step": "1"}}
		"number_choices":
			return {"enum_values": parse_labels(text.call("choices"))}
		"flags":
			return {"flags": parse_labels(text.call("flags"))}
		"layers":
			return {"layers": text.call("layers") if LAYER_KINDS.has(text.call("layers")) else "2d_physics"}
		"easing":
			var curve: String = text.call("curve")
			var easing: Dictionary = {"exp_easing": true}
			if curve != "plain":
				easing["exp_easing_flags"] = ["attenuation", "positive_only"] if curve == "both" else [_or(curve, "attenuation")]
			return easing
		"unit":
			var units: Dictionary = parse_units(text.call("units"))
			return {"drawer": "unit", "unit_kinds": units.get("units", []), "unit_store": str(units.get("store", ""))}
		"file", "folder":
			var spec: Dictionary = {"mode": "file" if look_id == "file" else "dir", "global": text.call("reach") == REACH[1]}
			if look_id == "file":
				var filters: Array = split_list(text.call("filters"))
				if not filters.is_empty():
					spec["filters"] = filters
				if bool(values.get("plain_path", false)):
					spec["plain_path"] = true
			return {"file": spec}
		"multiline", "no_alpha", "storage":
			return {look_id: true}
		"placeholder":
			return {"placeholder": text.call("hint")} if not text.call("hint").is_empty() else {}
		"choices":
			return {"options": split_list(text.call("choices"))}
		"suggestions":
			return {"suggestions": split_list(text.call("choices"))}
		"toggle_row":
			return {"drawer": "toggle_row", "toggle_options": split_list(text.call("choices"))}
		"password", "expression", "link":
			return {"custom_preset": look_id}
		"swatch_row", "corners", "texture_preview", "curve_editor":
			return {"drawer": look_id}
		"table":
			return {"drawer": "table", "table_columns": parse_columns(text.call("columns"))}
		"table_row":
			return {"drawer": "table_row", "table_row_table": text.call("table"), "table_row_column": _or(text.call("name_column"), "name")}
		"node_path":
			return {"node_path_types": split_list(text.call("types"))}
		"tool_button":
			return {"tool_button": _tool_button(values)}
		"custom":
			return {"custom_hint": {"hint": _or(text.call("hint"), "PROPERTY_HINT_NONE"), "text": str(values.get("text", "")),
				"usage": text.call("usage")}}
	return {}


## The look and detail values a variable's attributes (and a String's dropdown `options`) were
## saved with: [look_id, values]. "" is the plain look.
static func unfold(attributes: Dictionary, options: PackedStringArray = PackedStringArray()) -> Array:
	if bool(attributes.get("storage", false)):
		return ["storage", {}]
	var preset: String = str(attributes.get("custom_preset", ""))
	if preset in ["password", "expression", "link"]:
		return [preset, {}]
	if attributes.get("tool_button") is Dictionary:
		var button: Dictionary = attributes.get("tool_button")
		var quoted: PackedStringArray = _quoted(str(button.get("args", "")))
		return ["tool_button", {"label": str(button.get("label", quoted[0] if quoted.size() > 0 else "")),
			"icon": quoted[1] if quoted.size() > 1 else "", "args": str(button.get("args", ""))}]
	var range_spec: Dictionary = attributes.get("range") if attributes.get("range") is Dictionary else {}
	var bounds: Dictionary = {"min": str(range_spec.get("min", "0")), "max": str(range_spec.get("max", "100")),
		"step": LocalVariable.range_step(range_spec)}
	var drawer: String = str(attributes.get("drawer", ""))
	match drawer:
		"progress_bar", "min_max", "vector_dial":
			return [drawer, bounds]
		"unit":
			return ["unit", {"units": unit_text(attributes)}]
		"toggle_row":
			return ["toggle_row", {"choices": _joined(attributes.get("toggle_options", []))}]
		"table":
			return ["table", {"columns": columns_text(attributes.get("table_columns", []))}]
		"table_row":
			return ["table_row", {"table": str(attributes.get("table_row_table", "")), "name_column": str(attributes.get("table_row_column", ""))}]
		"swatch_row", "corners", "texture_preview", "curve_editor":
			return [drawer, {}]
	if bool(attributes.get("exp_easing", false)):
		var easing_flags: Array = attributes.get("exp_easing_flags") if attributes.get("exp_easing_flags") is Array else []
		var curve: String = "plain" if easing_flags.is_empty() else ("both" if easing_flags.size() > 1 else str(easing_flags[0]))
		return ["easing", {"curve": curve}]
	if not range_spec.is_empty():
		if not str(range_spec.get("angle", "")).is_empty():
			bounds["angle"] = str(range_spec.get("angle"))
			return ["angle", bounds]
		if bool(range_spec.get("exp", false)) or bool(range_spec.get("hide_slider", false)):
			return ["exp_slider" if bool(range_spec.get("exp", false)) else "no_handle", bounds]
		bounds["unit"] = str(range_spec.get("suffix", ""))
		bounds["or_greater"] = bool(range_spec.get("or_greater", false))
		bounds["or_less"] = bool(range_spec.get("or_less", false))
		return ["slider", bounds]
	if attributes.get("flags") is Array:
		return ["flags", {"flags": labels_text(attributes.get("flags"))}]
	if attributes.get("enum_values") is Array:
		return ["number_choices", {"choices": labels_text(attributes.get("enum_values"))}]
	if not str(attributes.get("layers", "")).is_empty():
		return ["layers", {"layers": str(attributes.get("layers"))}]
	if attributes.get("file") is Dictionary:
		var file_spec: Dictionary = attributes.get("file")
		return ["folder" if str(file_spec.get("mode", "file")) == "dir" else "file", {
			"filters": _joined(file_spec.get("filters", [])), "reach": REACH[1] if bool(file_spec.get("global", false)) else REACH[0],
			"plain_path": bool(file_spec.get("plain_path", false))}]
	if attributes.get("node_path_types") is Array:
		return ["node_path", {"types": _joined(attributes.get("node_path_types"))}]
	if attributes.get("suggestions") is Array:
		return ["suggestions", {"choices": _joined(attributes.get("suggestions"))}]
	for flag: String in ["multiline", "no_alpha"]:
		if bool(attributes.get(flag, false)):
			return [flag, {}]
	if not str(attributes.get("placeholder", "")).is_empty():
		return ["placeholder", {"hint": str(attributes.get("placeholder"))}]
	if attributes.get("custom_hint") is Dictionary:
		var custom: Dictionary = attributes.get("custom_hint")
		return ["custom", {"hint": str(custom.get("hint", "")), "text": str(custom.get("text", "")), "usage": str(custom.get("usage", ""))}]
	if not options.is_empty():
		return ["choices", {"choices": ", ".join(options)}]
	return ["", {}]


## Every attribute key a look can write - what the dialog clears before folding the chosen look.
static func look_keys() -> PackedStringArray:
	return PackedStringArray(["range", "drawer", "enum_values", "flags", "layers", "exp_easing", "exp_easing_flags",
		"unit_kinds", "unit_store", "file", "multiline", "no_alpha", "storage", "placeholder", "suggestions",
		"toggle_options", "custom_preset", "table_columns", "table_row_table", "table_row_column", "node_path_types", "tool_button",
		"custom_hint"])


## "Fire:1, Ice" -> [{label, value}] (the value stays text; empty = automatic).
static func parse_labels(detail: String) -> Array:
	var entries: Array = []
	for part: String in split_list(detail):
		var colon: int = part.rfind(":")
		if colon > 0:
			entries.append({"label": part.substr(0, colon).strip_edges(), "value": part.substr(colon + 1).strip_edges()})
		else:
			entries.append({"label": part, "value": ""})
	return entries


## The inverse of parse_labels, in the field's own spelling.
static func labels_text(entries: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for entry: Variant in entries:
		if entry is Dictionary:
			var value: String = str((entry as Dictionary).get("value", ""))
			var label: String = str((entry as Dictionary).get("label", ""))
			parts.append(label if value.is_empty() else "%s:%s" % [label, value])
	return ", ".join(parts)


## The unit look's field -> {units, store}, written the way the drawer marker reads
## ("kinds=px|world|screen, store=world") and forgiving of shorthand ("s|ms|frames"). An empty field
## means the length units; the store falls back to the first unit listed.
static func parse_units(detail: String) -> Dictionary:
	var units: Array = []
	var store: String = ""
	for token: String in split_list(detail):
		if token.begins_with("store="):
			store = token.substr(6).strip_edges()
			continue
		for unit: String in token.trim_prefix("kinds=").split("|", false):
			if not unit.strip_edges().is_empty() and not units.has(unit.strip_edges()):
				units.append(unit.strip_edges())
	if units.is_empty():
		units = ["px", "world", "screen"]
		if store.is_empty():
			store = "world"
	if store.is_empty() or not units.has(store):
		store = str(units[0])
	return {"units": units, "store": store}


## The unit look's field rebuilt from saved attributes - the inverse of parse_units.
static func unit_text(attributes: Dictionary) -> String:
	var units: Array = attributes.get("unit_kinds") if attributes.get("unit_kinds") is Array else []
	if units.is_empty():
		return ""
	var store: String = str(attributes.get("unit_store", ""))
	return "kinds=%s, store=%s" % [_joined(units, "|"), store if not store.is_empty() else str(units[0])]


## "item:String, count:int, rarity:enum(common|rare)" -> the table drawer's {name, type[, options]}.
## A missing or unknown type is String.
static func parse_columns(detail: String) -> Array:
	var columns: Array = []
	for pair: String in split_list(detail):
		var colon: int = pair.rfind(":")
		var column_name: String = (pair.substr(0, colon) if colon > 0 else pair).strip_edges()
		var column_type: String = pair.substr(colon + 1).strip_edges() if colon > 0 else "String"
		if column_name.is_empty():
			continue
		var enum_options: Array = SheetCompiler.table_enum_options(column_type)
		if not enum_options.is_empty():
			columns.append({"name": column_name, "type": "enum", "options": enum_options})
		else:
			columns.append({"name": column_name, "type": column_type if column_type in SheetCompiler.TABLE_CELL_TYPES else "String"})
	return columns


## Gives each column the Default and Description the same-named column had before, so retyping
## the column list in a window keeps the notes it has no field for.
static func carry_column_notes(columns: Array, before: Variant) -> void:
	for previous: Variant in (before if before is Array else []):
		for column: Variant in columns:
			if previous is Dictionary and column is Dictionary and str(column.get("name", "")) == str(previous.get("name", "")):
				for note: String in SheetCompiler.TABLE_COLUMN_NOTES:
					if (previous as Dictionary).has(note):
						column[note] = previous[note]


## The inverse of parse_columns.
static func columns_text(columns: Variant) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for column: Variant in (columns if columns is Array else []):
		if column is Dictionary:
			var column_type: String = str((column as Dictionary).get("type", "String"))
			if column_type == "enum":
				column_type = SheetCompiler.table_enum_type((column as Dictionary).get("options", []))
			parts.append("%s:%s" % [str((column as Dictionary).get("name", "")), column_type])
	return ", ".join(parts)


## A comma list, trimmed, empties dropped.
static func split_list(detail: String) -> Array:
	var items: Array = []
	for part: String in detail.split(",", false):
		if not part.strip_edges().is_empty():
			items.append(part.strip_edges())
	return items


static func _joined(items: Variant, separator: String = ", ") -> String:
	var parts: PackedStringArray = PackedStringArray()
	for item: Variant in (items if items is Array else []):
		parts.append(str(item))
	return separator.join(parts)


static func _range(values: Dictionary) -> Dictionary:
	return {"min": _or(str(values.get("min", "")).strip_edges(), "0"), "max": _or(str(values.get("max", "")).strip_edges(), "100"),
		"step": _or(str(values.get("step", "")).strip_edges(), "1")}


static func _or(text: String, fallback: String) -> String:
	return fallback if text.is_empty() else text


## The button's annotation arguments: the ones it opened with while the label and icon still say what
## they said, so a reopened button keeps its own spelling; otherwise rebuilt from the two fields.
static func _tool_button(values: Dictionary) -> Dictionary:
	var label: String = str(values.get("label", "")).strip_edges()
	var icon: String = str(values.get("icon", "")).strip_edges()
	var args: String = str(values.get("args", ""))
	var quoted: PackedStringArray = _quoted(args)
	var unchanged: bool = quoted.size() > 0 and quoted[0] == label and (quoted[1] if quoted.size() > 1 else "") == icon
	if not unchanged:
		args = "\"%s\"" % label.c_escape() if icon.is_empty() else "\"%s\", \"%s\"" % [label.c_escape(), icon.c_escape()]
	return {"args": args, "label": label}


## The double-quoted words in an annotation's argument list, in order.
static func _quoted(arguments: String) -> PackedStringArray:
	var words: PackedStringArray = PackedStringArray()
	var parts: PackedStringArray = arguments.split("\"")
	for index: int in range(1, parts.size(), 2):
		words.append(parts[index])
	return words


## A non-interactive miniature of the Inspector widget a look produces, for the preview card. Every
## control is mouse-transparent. "" builds the plain field; a look with no miniature of its own is null.
static func build_preview(look_id: String) -> Control:
	var preview: Control = _build_preview_inner(look_id)
	if preview != null:
		_ignore_mouse(preview)
	return preview


static func _build_preview_inner(look_id: String) -> Control:
	match look_id:
		"file":
			return _path_field("res://sfx/jump.ogg")
		"folder":
			return _path_field("res://levels/")
		"node_path":
			return _path_field("../Player")
		"flags":
			var flags_row := HBoxContainer.new()
			for flag_spec: Array in [["Fire", true], ["Ice", false], ["Poison", true]]:
				var flag_check := CheckBox.new()
				flag_check.text = str(flag_spec[0])
				flag_check.button_pressed = bool(flag_spec[1])
				flag_check.disabled = true
				flags_row.add_child(flag_check)
			return flags_row
		"number_choices", "suggestions", "choices":
			var dropdown := OptionButton.new()
			dropdown.add_item("Slow (30)" if look_id == "number_choices" else "Round")
			dropdown.disabled = true
			return dropdown
		"password", "expression":
			var line := LineEdit.new()
			line.text = "hunter2" if look_id == "password" else "sin(time) * 4.0"
			line.secret = look_id == "password"
			line.editable = false
			line.custom_minimum_size = Vector2(150.0, 0.0)
			return line
		"link":
			var link_label := Label.new()
			link_label.text = "x 4   y 4   (linked)"
			return link_label
		"easing":
			return _EasePreview.new()
		"unit":
			var unit_field := EventSheetDrawerWidgets.DrawerUnitField.new(PackedStringArray(["px", "world", "screen"]), "world")
			unit_field.set_value(0.6)
			unit_field.set_editable(false)
			unit_field.custom_minimum_size = Vector2(170.0, 0.0)
			return unit_field
		"corners":
			var corners_field := EventSheetDrawerWidgets.DrawerCorners.new()
			corners_field.set_value(Vector4(8.0, 8.0, 8.0, 8.0))
			corners_field.set_editable(false)
			corners_field.custom_minimum_size = Vector2(170.0, 0.0)
			return corners_field
		"layers":
			return _LayerGridPreview.new()
		"storage":
			var storage_label := Label.new()
			storage_label.text = EventSheetL10n.translate("(saved, not shown)")
			storage_label.modulate = Color(1.0, 1.0, 1.0, 0.45)
			return storage_label
	if not look_id.is_empty():
		return null
	var default_edit := LineEdit.new()
	default_edit.text = "100"
	default_edit.editable = false
	default_edit.custom_minimum_size = Vector2(150.0, 0.0)
	return default_edit


static func _path_field(path_text: String) -> Control:
	var path_row := HBoxContainer.new()
	var path_edit := LineEdit.new()
	path_edit.text = path_text
	path_edit.editable = false
	path_edit.custom_minimum_size = Vector2(130.0, 0.0)
	path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_row.add_child(path_edit)
	var browse_button := Button.new()
	browse_button.text = "..."
	browse_button.disabled = true
	path_row.add_child(browse_button)
	return path_row


static func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


## The Inspector's layer-matrix widget in miniature: two rows of toggle cells, a few lit.
class _LayerGridPreview:
	extends Control

	const CELL := 11.0
	const GAP := 2.0
	const LIT := [0, 3, 9, 12]


	func _init() -> void:
		custom_minimum_size = Vector2((CELL + GAP) * 8.0, (CELL + GAP) * 2.0)


	func _draw() -> void:
		var lit_color: Color = Color(0.38, 0.60, 0.92, 0.95)
		var off_color: Color = Color(1.0, 1.0, 1.0, 0.12)
		for cell_index in range(16):
			var column: int = cell_index % 8
			var row: int = int(cell_index / 8.0)
			draw_rect(Rect2(column * (CELL + GAP), row * (CELL + GAP), CELL, CELL), lit_color if LIT.has(cell_index) else off_color)


## A tiny exponential-ease curve, the shape the Inspector's easing widget shows.
class _EasePreview:
	extends Control


	func _init() -> void:
		custom_minimum_size = Vector2(110.0, 40.0)


	func _draw() -> void:
		var points: PackedVector2Array = []
		for step in range(25):
			var t: float = step / 24.0
			points.append(Vector2(t * size.x, size.y - (1.0 - pow(t, 2.4)) * (size.y - 4.0) - 2.0))
		draw_polyline(points, Color(0.45, 0.75, 0.95, 0.95), 1.5, true)
