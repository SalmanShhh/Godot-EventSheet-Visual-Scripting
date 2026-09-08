# Godot EventSheets - the Inspector's "Edit Event Sheet" button, and the declared table under it
#
# Godot devs live in the Inspector: when the selected node's script is generated
# from a sheet (the pairing rule knows), one button jumps straight to the sheet -
# and quietly says "edit the sheet, not the script".
#
# The object's own variables are not a button any more: they are Inspector ROWS, drawn by the
# plugin beside this one from the very table this file reads. So the reading lives here, where the
# pairing rule already is, and the drawing lives there.
#
# That table is a LIGHT SCAN of the script's own text, not a sheet open: this plugin is
# registered at editor boot and a selection must not cost a compile. It reads member declarations
# the same way the autoload scan does, and being wrong about an exotic one costs a row, never a
# written line.
@tool
class_name EventSheetEditButtonPlugin
extends EditorInspectorPlugin

var open_sheet: Callable = Callable()  # Callable(sheet_path: String)


func _can_handle(object: Object) -> bool:
	return not sheet_path_for(object).is_empty()


func _parse_begin(object: Object) -> void:
	var sheet_path: String = sheet_path_for(object)
	if sheet_path.is_empty():
		return
	var row: HBoxContainer = HBoxContainer.new()
	var button: Button = Button.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = "Edit Event Sheet"
	button.tooltip_text = "%s is generated from %s - edit the sheet, not the script." % [
		(object.get_script() as Script).resource_path.get_file() if object.get_script() != null else "the script", sheet_path.get_file()]
	button.pressed.connect(func() -> void:
		if open_sheet.is_valid():
			open_sheet.call(sheet_path))
	row.add_child(button)
	add_custom_control(row)


## The object's own member declarations, read off its script, in file order:
## [{"name", "exported", "constant", "type_name", "value", "line", "complete"}].
##
## `exported` says whether `@export` (in any of its hinted spellings) puts the variable in the
## Inspector's own property list; `line` is the 1-based line the declaration sits on, which is what
## the pencil beside a row opens the sheet on; `complete` is false when the value runs on past the
## end of its line (a table or a list written across several), which is a value no one-line field
## may offer to rewrite. Static + pure, so every one of those is testable without an editor.
static func member_variables(script_path: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if script_path.is_empty() or not FileAccess.file_exists(script_path):
		return found
	if _declaration_pattern == null:
		_declaration_pattern = RegEx.new()
		# `const` is a declaration like `var`: a pack's tuning constant is one of the values a
		# reader comes to the object looking for, and the row says which of the two it is.
		_declaration_pattern.compile("^(?:static +)?(var|const) +([A-Za-z_][A-Za-z0-9_]*)")
	var exported_next: bool = false
	var line_number: int = 0
	for line: String in FileAccess.get_file_as_string(script_path).split("\n"):
		line_number += 1
		# Members only: anything indented is inside a function and is nobody's property.
		if line.begins_with("\t") or line.begins_with(" "):
			continue
		var bare: String = line.strip_edges()
		# `@export var speed: float = 200.0` puts both facts on one line; `@export_range(0, 100)` on
		# its own line marks the NEXT one. Both spellings are the same declaration, so the annotation
		# is taken off the front and whatever is left is read as usual.
		if bare.begins_with("@export"):
			# A section annotation labels the Inspector band; it exports nothing by itself, so it
			# must not vouch for the variable under it.
			exported_next = not (bare.begins_with("@export_group") or bare.begins_with("@export_subgroup")
				or bare.begins_with("@export_category"))
			bare = _without_export_annotation(bare)
			if bare.is_empty():
				continue
		# `@onready var sprite := $Sprite` declares a member like any other line here - the
		# annotation only says WHEN it is filled in.
		if bare.begins_with("@onready "):
			bare = bare.substr("@onready ".length()).strip_edges()
		var found_match: RegExMatch = _declaration_pattern.search(bare)
		if found_match == null:
			if not bare.is_empty() and not bare.begins_with("#"):
				exported_next = false
			continue
		var parts: Dictionary = _declaration_parts(bare.substr(found_match.get_end()))
		found.append({
			"name": found_match.get_string(2),
			"exported": exported_next,
			"constant": found_match.get_string(1) == "const",
			"type_name": str(parts.get("type_name", "")),
			"value": str(parts.get("value", "")),
			"complete": bool(parts.get("complete", true)),
			"line": line_number,
		})
		exported_next = false
	return found


## Compiled once and kept: `_can_handle` fires on every Inspector refresh, so the scan behind it
## must not rebuild a regular expression per selection.
static var _declaration_pattern: RegEx = null


## The `: Type` and `= value` halves of whatever follows `var name`, as {"type_name", "value"}.
## Both are "" when the line declares neither (`var hp`), and the type is "" for the inferred
## spellings (`var hp := 100`), where the value is the only thing that says what the variable is.
static func _declaration_parts(rest: String) -> Dictionary:
	var tail: String = _without_trailing_comment(rest)
	var assignment: int = _assignment_index(tail)
	var type_part: String = (tail if assignment < 0 else tail.left(assignment)).strip_edges()
	var value_part: String = "" if assignment < 0 else tail.substr(assignment + 1).strip_edges()
	# `var hp := 100` writes the colon as part of the ASSIGNMENT, not as a declared type, so what
	# is left of the operator is a bare ":" and says nothing.
	if type_part.begins_with(":"):
		type_part = type_part.substr(1).strip_edges()
	# `var hp: int:` and `var hp := 3:` open a property block on the lines below; the trailing colon
	# belongs to the block, and is on whichever side of the declaration ends the line.
	type_part = type_part.trim_suffix(":").strip_edges()
	value_part = value_part.trim_suffix(":").strip_edges()
	return {
		"type_name": type_part,
		"value": _display_value(value_part, not type_part.is_empty()),
		"complete": _is_complete(value_part),
	}


## Whether the value ends on the line it started on: a table or a list written across several lines
## leaves a bracket open here, and what this line holds is the first fragment of it, not the value.
static func _is_complete(value_text: String) -> bool:
	var quote: String = ""
	var depth: int = 0
	for index: int in range(value_text.length()):
		var glyph: String = value_text[index]
		if not quote.is_empty():
			if glyph == "\\":
				continue
			if glyph == quote:
				quote = ""
			continue
		if glyph == "\"" or glyph == "'":
			quote = glyph
		elif glyph == "(" or glyph == "[" or glyph == "{":
			depth += 1
		elif glyph == ")" or glyph == "]" or glyph == "}":
			depth -= 1
	return quote.is_empty() and depth == 0


## Where the declaration's `=` is, or -1. Quoted text is skipped so a default carrying an equals
## sign inside a string cannot be mistaken for the operator.
static func _assignment_index(text: String) -> int:
	var quote: String = ""
	for index: int in range(text.length()):
		var glyph: String = text[index]
		if not quote.is_empty():
			if glyph == "\\":
				continue
			if glyph == quote:
				quote = ""
			continue
		if glyph == "\"" or glyph == "'":
			quote = glyph
		elif glyph == "=":
			return index
	return -1


## The line without the comment a reader wrote after it. Same quote-aware walk as above: a `#`
## inside a string literal is part of the value (`var tint := "#ff0000"`).
static func _without_trailing_comment(text: String) -> String:
	var quote: String = ""
	for index: int in range(text.length()):
		var glyph: String = text[index]
		if not quote.is_empty():
			if glyph == "\\":
				continue
			if glyph == quote:
				quote = ""
			continue
		if glyph == "\"" or glyph == "'":
			quote = glyph
		elif glyph == "#":
			return text.left(index)
	return text


## The initial value as a ROW shows it, and as the write-back reads it again.
##
## A declaration that names its type (`var mode: String = "idle"`) holds a real VALUE, and the sheet
## shows a text value without its quotes - so this does too, and a value typed back in is quoted
## again on the way out. A declaration that infers its type (`var mode := "idle"`) holds SOURCE
## TEXT, which is emitted exactly as it was written, so its quotes are part of the value and stay.
## Anything else - a number, a constructor, a list, a node path - is already what a reader reads.
static func _display_value(value_text: String, has_declared_type: bool) -> String:
	if not has_declared_type or value_text.length() < 2:
		return value_text
	var quote: String = value_text[0]
	if quote != "\"" and quote != "'":
		return value_text
	if not value_text.ends_with(quote):
		return value_text
	var inner: String = value_text.substr(1, value_text.length() - 2)
	return value_text if inner.contains(quote) else inner


## What is left of a line once its leading `@export…` annotation is taken off: "" for an annotation
## that stands alone on its line, and the declaration for one written in front of a `var`. The
## argument list is walked by bracket depth (skipping quoted text) rather than cut at the first
## space, because the arguments carry spaces of their own - `@export_range(0, 100) var speed: float`
## is exactly the spelling the compiler emits, and cutting at a space leaves `100) var speed: float`.
static func _without_export_annotation(bare: String) -> String:
	var index: int = 0
	while index < bare.length() and not " \t(".contains(bare[index]):
		index += 1
	if index >= bare.length() or bare[index] != "(":
		return bare.substr(index).strip_edges()
	var depth: int = 0
	var quote: String = ""
	while index < bare.length():
		var glyph: String = bare[index]
		if not quote.is_empty():
			if glyph == "\\":
				index += 1
			elif glyph == quote:
				quote = ""
		elif glyph == "\"" or glyph == "'":
			quote = glyph
		elif glyph == "(":
			depth += 1
		elif glyph == ")":
			depth -= 1
			if depth == 0:
				index += 1
				break
		index += 1
	return bare.substr(index).strip_edges()


# _can_handle fires on every Inspector refresh; sheet_for_script reads files, so
# results are memoized by script path + mtime (review catch).
static var _pairing_cache: Dictionary = {}


## The sheet behind this object's attached script, or "" (which also means
## "don't handle").
static func sheet_path_for(object: Object) -> String:
	if not (object is Node):
		return ""
	var script: Script = (object as Node).get_script() as Script
	if script == null or script.resource_path.is_empty():
		return ""
	var script_path: String = script.resource_path
	var mtime: int = int(FileAccess.get_modified_time(script_path))
	var cached: Variant = _pairing_cache.get(script_path)
	if cached is Dictionary and int((cached as Dictionary).get("mtime")) == mtime:
		return str((cached as Dictionary).get("sheet"))
	# Loaded by path, not named as a class: this inspector plugin registers at editor boot, and
	# naming EventSheetProjectDoctor would compile its whole subtree (the compiler included)
	# right there. The first Inspector selection absorbs the one-time load instead.
	var sheet_path: String = load("res://addons/eventforge/project_doctor.gd").sheet_for_script(script_path)
	_pairing_cache[script_path] = {"mtime": mtime, "sheet": sheet_path}
	return sheet_path
