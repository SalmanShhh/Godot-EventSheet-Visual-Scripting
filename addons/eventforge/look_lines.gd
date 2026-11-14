@tool
class_name EventForgeLookLines
extends RefCounted

## THE LOOKS THAT KEEP GODOT'S OWN EXPORT LINE. A look whose data Godot can say itself (the choices of a
## row of toggle buttons, the bounds of a progress bar, the stored unit of a number) is written as that
## ordinary Godot line - `@export_enum(...)`, `@export_range(...)` - and carries the look on the plain
## comment line `# @inspector_look <word>[:<value>...]` directly above the variable's block. Without
## the plugin the variable then shows Godot's own control with the same limits; with it, the comment
## names the look and the Godot line supplies the data.
##
## The old spelling, `@export_custom(PROPERTY_HINT_NONE, "eventsheet:<word>...")`, stays readable
## forever and an untouched old line re-emits byte for byte. A variable remembers which spelling its
## file used in the attribute `look_line` (true = the comment spelling); the Variable window sets it
## on every new pick, and the importer sets it only when it read the comment line.
##
## The comment body is the marker text after `eventsheet:` minus whatever the Godot line already says:
##   progress_bar                       (the bounds are the @export_range's)
##   toggle_row[:segmented][:icons=...] (the choices are the @export_enum's)
##   unit:kinds=px|world|screen,store=px (the stored unit is also the range's "suffix:")
## Everything here is static and UI-free so the headless suite pins it.

## The looks written this way. Any other word keeps the marker spelling.
const WORDS: PackedStringArray = ["progress_bar", "toggle_row", "unit"]
## The attribute that says a variable's look rides the comment spelling.
const FLAG: String = "look_line"
## The comment line's head, and the length of it.
const COMMENT_HEAD: String = "# @inspector_look "
## The range a unit look writes: it only has to carry the suffix, so it is unbounded both ways, with no slider.
const UNIT_RANGE: String = "@export_range(0, 1, 0.001, \"or_greater\", \"or_less\", \"hide_slider\", \"suffix:%s\")"


## Whether this variable's look is written the comment way: a word in WORDS and the flag.
static func uses_comment(attributes: Variant) -> bool:
	if not (attributes is Dictionary):
		return false
	var word: String = str((attributes as Dictionary).get("drawer", ""))
	return bool((attributes as Dictionary).get(FLAG, false)) and WORDS.has(word)


## {prefix, body} for a variable written the comment way: the Godot annotation (with its trailing space,
## ready to sit before `var`) and the comment body. {} when the look cannot be written for this type or
## these values - the variable then stays a plain field, exactly as the marker spelling does.
static func parts(attributes: Dictionary, type_name: String) -> Dictionary:
	if not uses_comment(attributes):
		return {}
	match str(attributes.get("drawer", "")):
		"progress_bar":
			return _progress_bar_parts(attributes, type_name)
		"toggle_row":
			return _toggle_row_parts(attributes, type_name)
		"unit":
			return _unit_parts(attributes, type_name)
	return {}


static func _progress_bar_parts(attributes: Dictionary, type_name: String) -> Dictionary:
	if type_name != "int" and type_name != "float":
		return {}
	var bounds: Dictionary = (attributes.get("range") as Dictionary).duplicate() if attributes.get("range") is Dictionary else {}
	if not bounds.has("min"):
		bounds["min"] = "0"
	if not bounds.has("max"):
		bounds["max"] = "100"
	# A bar's step is Godot's own unless the file wrote one, so a whole-number bar and a fractional one
	# both read with the control Godot gives that type.
	if not bounds.has("step") or str(bounds["step"]).strip_edges() == "1":
		bounds["step"] = LocalVariable.RANGE_STEP_UNWRITTEN
	var prefix: String = EventSheetCompiler._structured_hint_prefix({"range": bounds}, type_name)
	if prefix.is_empty():
		return {}
	return {"prefix": prefix, "body": "progress_bar"}


static func _toggle_row_parts(attributes: Dictionary, type_name: String) -> Dictionary:
	if not (type_name in ["String", "int"]) or not (attributes.get("toggle_options") is Array):
		return {}
	var values: PackedStringArray = PackedStringArray()
	for option: Variant in attributes.get("toggle_options"):
		var cleaned: String = str(option).strip_edges()
		if not cleaned.is_empty() and not cleaned.contains(",") and not cleaned.contains(":") and not cleaned.contains("\""):
			values.append(cleaned)
	if values.is_empty():
		return {}
	var body: String = "toggle_row"
	if bool(attributes.get("toggle_segmented", false)):
		body += ":segmented"
	var icon_source: String = str(attributes.get("toggle_icons", "")).strip_edges()
	if not icon_source.is_empty() and not icon_source.contains("\"") and not icon_source.contains(","):
		body += ":icons=%s" % icon_source
	return {"prefix": EventSheetCompiler._export_enum_prefix(values) + " ", "body": body}


static func _unit_parts(attributes: Dictionary, type_name: String) -> Dictionary:
	if type_name != "float" or not (attributes.get("unit_kinds") is Array):
		return {}
	var values: PackedStringArray = PackedStringArray()
	for kind: Variant in attributes.get("unit_kinds"):
		var cleaned: String = str(kind).strip_edges()
		if not cleaned.is_empty() and not cleaned.contains(",") and not cleaned.contains(":") and not cleaned.contains("|") \
				and not cleaned.contains("\"") and not values.has(cleaned):
			values.append(cleaned)
	if values.is_empty():
		return {}
	var store: String = str(attributes.get("unit_store", "")).strip_edges()
	if store.is_empty() or not values.has(store):
		store = values[0]
	return {"prefix": (UNIT_RANGE % store) + " ", "body": "unit:kinds=%s,store=%s" % ["|".join(values), store]}


## What the importer makes of a `# @inspector_look <body>` line sitting above a variable it already read
## the Godot line of. `lifted` is the LocalVariable as the Godot line left it. Returns {} when the line
## above is not a look this variable can wear (the comment then stays an ordinary comment), else
## {"attributes": the attributes to merge in, "erase": keys to remove, "clear_options": bool}. The
## importer re-emits the whole block and keeps the reading only when it reproduces the source bytes.
static func lift(body: String, lifted: LocalVariable) -> Dictionary:
	if lifted == null or not lifted.exported:
		return {}
	var tokens: PackedStringArray = body.split(":")
	var word: String = tokens[0]
	if not WORDS.has(word):
		return {}
	var existing: Dictionary = lifted.attributes if lifted.attributes is Dictionary else {}
	var found: Dictionary = {"drawer": word, FLAG: true}
	var erase: PackedStringArray = PackedStringArray()
	var clear_options: bool = false
	match word:
		"progress_bar":
			if tokens.size() != 1 or not (existing.get("range") is Dictionary) or not (lifted.type_name in ["int", "float"]):
				return {}
		"toggle_row":
			var names: Array = []
			if lifted.type_name == "String" and not lifted.options.is_empty():
				names = Array(lifted.options)
				clear_options = true
			elif lifted.type_name == "int" and existing.get("enum_values") is Array:
				for entry: Variant in existing.get("enum_values"):
					if not (entry is Dictionary) or not str((entry as Dictionary).get("value", "")).is_empty():
						return {}
					names.append(str((entry as Dictionary).get("label", "")))
				erase.append("enum_values")
			if names.is_empty():
				return {}
			found["toggle_options"] = names
			for index: int in range(1, tokens.size()):
				var tail: String = tokens[index]
				if tail == "segmented":
					found["toggle_segmented"] = true
				elif tail.begins_with("icons="):
					found["toggle_icons"] = ":".join(tokens.slice(index)).substr(6)
					break
				else:
					return {}
		"unit":
			if lifted.type_name != "float" or tokens.size() != 2 or not (existing.get("range") is Dictionary):
				return {}
			var kinds: Array = []
			var store: String = ""
			for token: String in tokens[1].split(","):
				var trimmed: String = token.strip_edges()
				if trimmed.begins_with("kinds="):
					for unit: String in trimmed.substr(6).split("|"):
						if not unit.strip_edges().is_empty():
							kinds.append(unit.strip_edges())
				elif trimmed.begins_with("store="):
					store = trimmed.substr(6).strip_edges()
			if kinds.is_empty() or store.is_empty():
				return {}
			found["unit_kinds"] = kinds
			found["unit_store"] = store
			erase.append("range")
	return {"attributes": found, "erase": erase, "clear_options": clear_options}


## The marker the drawers already understand, rebuilt from a comment line's body and the Godot property
## it sits on (the hint kind and hint string Godot reports for it): `toggle_row` + an enum's choices becomes
## `eventsheet:toggle_row:easy,normal,hard`, `progress_bar` + a range becomes `eventsheet:progress_bar:0:200`.
## "" when the body is not one of these looks or the property's hint does not carry what it needs.
static func marker_for(body: String, hint_type: int, hint_string: String) -> String:
	var tokens: PackedStringArray = body.split(":")
	if tokens.is_empty() or not WORDS.has(tokens[0]):
		return ""
	match tokens[0]:
		"progress_bar":
			if hint_type != PROPERTY_HINT_RANGE:
				return ""
			var bounds: PackedStringArray = hint_string.split(",")
			if bounds.size() < 2:
				return ""
			return "eventsheet:progress_bar:%s:%s" % [bounds[0], bounds[1]]
		"toggle_row":
			if hint_type != PROPERTY_HINT_ENUM or hint_string.is_empty():
				return ""
			var choices: PackedStringArray = PackedStringArray()
			for choice: String in hint_string.split(","):
				# An int enum reports each choice with its number (`b:1`); the strip shows only the word.
				var colon: int = choice.rfind(":")
				choices.append(choice.substr(0, colon) if colon > 0 and choice.substr(colon + 1).is_valid_int() else choice)
			return "eventsheet:toggle_row:%s%s" % [",".join(choices), (":" + ":".join(tokens.slice(1))) if tokens.size() > 1 else ""]
		"unit":
			if tokens.size() < 2:
				return ""
			return "eventsheet:" + body
	return ""


## The line the Variable window's hover says a look writes, for the looks in WORDS ("" for any other).
static func writes_text(word: String) -> String:
	match word:
		"progress_bar":
			return "@export_range(0, 100) + # @inspector_look progress_bar"
		"toggle_row":
			return "@export_enum(\"easy\", \"normal\", \"hard\") + # @inspector_look toggle_row"
		"unit":
			return (UNIT_RANGE % "px") + " + # @inspector_look unit:kinds=px|world|screen,store=px"
	return ""
