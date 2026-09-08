# Godot EventSheets - the Inspector's "Instance variables" category
#
# A Godot dev looks for an object's values in the Inspector, so that is where this object's own
# variables are: a band named "Instance variables · N" and one row under it per declared variable -
# the name, the type in plain words, the initial value, and a pencil that opens the sheet on the
# line that declares it. Typing a new initial value writes that `var` / `const` line through the
# same undo funnel the sheet's own variable table writes through, so both doors produce the same
# line, one Ctrl+Z takes it back, and every other byte of the file is untouched.
#
# INSTANT is the whole point. This plugin is registered at editor boot and a selection must not
# cost a compile, so nothing here opens a sheet, builds an object census or names a class from the
# reading layer: the rows are the light text scan the paired plugin beside this one already reads,
# and the words below are plain literals, because reaching the editor's translation table would
# compile it into every editor start. The rows are a READING - being wrong about an exotic
# declaration costs a row, never a written line.
#
# It carries no class_name on purpose: `plugin.gd` loads it by path, so registering it adds nothing
# to the boot compile.
@tool
extends EditorInspectorPlugin

## Callable(sheet_path: String, line: int) - opens the sheet on the row that declaration became.
var open_line: Callable = Callable()
## Callable(sheet_path: String, variable_name: String, value_text: String) - writes a new initial
## value through the sheet's undo funnel.
var write_value: Callable = Callable()
## Callable(sheet_path: String) - opens the sheet's own Add variable dialog.
var add_variable: Callable = Callable()

## The band's own words. The count is the declared table's size, which is what the reader is being
## told the rows under it are.
const CATEGORY_LABEL: String = "Instance variables"
## The three column words, in the order the sheet's own variable table uses them.
const COLUMN_LABELS: Array = ["Name", "Type", "Initial value"]
const ADD_LABEL: String = "+ Add instance variable"
## The pencil. One glyph, no icon lookup - a plugin that asks the editor theme for an icon it may
## not have draws nothing at all and says nothing about why.
const OPEN_GLYPH: String = "✎"


func _can_handle(object: Object) -> bool:
	return not EventSheetEditButtonPlugin.sheet_path_for(object).is_empty()


func _parse_begin(object: Object) -> void:
	var sheet_path: String = EventSheetEditButtonPlugin.sheet_path_for(object)
	if sheet_path.is_empty():
		return
	var script: Script = object.get_script() as Script
	if script == null or script.resource_path.is_empty():
		return
	add_custom_control(build_category(script.resource_path, sheet_path, open_line, write_value, add_variable))


## The whole band as one control: the header line, a row per declared variable, and the add link.
##
## STATIC, and given the three doors rather than reading them off an instance: an
## EditorInspectorPlugin can only be instantiated by a running editor, so an instance method here
## could not be measured or rendered outside one - and a stand-in for it could stay fast and pretty
## while the thing the Inspector actually draws did neither. A door left empty simply does nothing,
## which is what a preview wants.
static func build_category(script_path: String, sheet_path: String, on_open_line: Callable,
		on_write_value: Callable, on_add_variable: Callable) -> Control:
	var rows: Array[Dictionary] = EventSheetEditButtonPlugin.member_variables(script_path)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_child(_header_label(header_text(rows.size())))
	if rows.is_empty():
		column.add_child(_muted_label("This object declares none yet."))
	else:
		var grid: GridContainer = GridContainer.new()
		grid.columns = 4
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for header: String in COLUMN_LABELS:
			grid.add_child(_muted_label(header))
		grid.add_child(_muted_label(""))
		for row: Dictionary in rows:
			_add_variable_row(grid, row, sheet_path, on_open_line, on_write_value)
		column.add_child(grid)
	var add_link: Button = Button.new()
	add_link.text = ADD_LABEL
	add_link.flat = true
	add_link.alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_link.tooltip_text = "Opens the sheet's Add variable dialog."
	add_link.pressed.connect(func() -> void:
		if on_add_variable.is_valid():
			on_add_variable.call(sheet_path))
	column.add_child(add_link)
	return column


## The band's line: "Instance variables · 6". The count is the whole answer to "what is down here",
## which is why it is said before the rows rather than under them.
static func header_text(count: int) -> String:
	return "%s · %d" % [CATEGORY_LABEL, count]


static func _add_variable_row(grid: GridContainer, row: Dictionary, sheet_path: String,
		on_open_line: Callable, on_write_value: Callable) -> void:
	var variable_name: String = str(row.get("name", ""))
	var name_label: Label = Label.new()
	name_label.text = variable_name
	name_label.tooltip_text = "Declared in %s." % sheet_path.get_file()
	grid.add_child(name_label)
	grid.add_child(_muted_label(type_word(str(row.get("type_name", "")), str(row.get("value", "")))))
	# A value written across several lines is shown as the fragment it is and cannot be typed into:
	# a one-line field that offered to rewrite a ten-line table would replace it with whatever fits.
	if not bool(row.get("complete", true)):
		var fragment: Label = _muted_label("%s…" % str(row.get("value", "")))
		fragment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fragment.tooltip_text = "Written across several lines - edit it on the sheet."
		grid.add_child(fragment)
	else:
		var value_edit: LineEdit = LineEdit.new()
		value_edit.text = str(row.get("value", ""))
		value_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value_edit.tooltip_text = "Enter applies. One undo step, on the sheet."
		value_edit.text_submitted.connect(func(text: String) -> void:
			if on_write_value.is_valid():
				on_write_value.call(sheet_path, variable_name, text))
		grid.add_child(value_edit)
	var open_button: Button = Button.new()
	open_button.text = OPEN_GLYPH
	open_button.tooltip_text = "Open the sheet on this variable's line."
	var line: int = int(row.get("line", 0))
	open_button.pressed.connect(func() -> void:
		if on_open_line.is_valid():
			on_open_line.call(sheet_path, line))
	grid.add_child(open_button)


## A declaration's type in the words the sheet's rows use for it - "text", "number", "table",
## "list of texts" - so the Inspector and the sheet say the same thing about the same variable.
##
## A declared type always wins, because the author said it on purpose. `const SPEED := 300.0` and
## `var mode := "idle"` declare no type at all, and "any" would tell a reader nothing the value in
## front of them does not already say, so an undeclared type is read off the literal instead.
##
## This is the ONE place the vocabulary is spelled twice: the sheet's own reading lives in the row
## builder, which a boot-path file may not name (it carries the whole reading layer with it). The
## two are held together by a test that asks both the same table of declarations and compares the
## answers, so a word that moved there and not here is a red suite rather than a drift nobody sees.
static func type_word(type_name: String, value_text: String) -> String:
	var declared: String = type_name.strip_edges()
	if declared.is_empty() or declared == "Variant":
		var inferred: String = _inferred_type_word(value_text)
		if not inferred.is_empty():
			return inferred
	return _friendly_type_word(declared)


## The type word a literal gives away, "" when the value settles nothing.
static func _inferred_type_word(value_text: String) -> String:
	var text: String = value_text.strip_edges()
	if text.is_empty():
		return ""
	if text == "true" or text == "false":
		return _friendly_type_word("bool")
	if text.begins_with("\"") or text.begins_with("'"):
		return _friendly_type_word("String")
	if text.begins_with("["):
		return _friendly_type_word("Array")
	if text.begins_with("{"):
		return _friendly_type_word("Dictionary")
	if text.is_valid_float():
		return _friendly_type_word("float")
	for constructed: String in ["Color", "Vector2", "Vector3", "Vector4"]:
		if text.begins_with("%s." % constructed) or text.begins_with("%s(" % constructed):
			return _friendly_type_word(constructed)
	return ""


## A declared type read as plain words. A type with no plain word passes through as it was written:
## a class called HealthPool is the author's own noun, and a word for it would be a guess.
static func _friendly_type_word(type_name: String) -> String:
	match type_name.strip_edges():
		"String", "StringName":
			return "text"
		"float":
			return "number"
		"int":
			return "whole number"
		"bool":
			return "boolean"
		"Vector2", "Vector3", "Vector4":
			return "vector"
		"Color":
			return "color"
		"PackedScene":
			return "scene"
		"Array":
			return "list"
		"Dictionary":
			return "table"
		"Callable":
			return "function"
		"Signal":
			return "signal"
		"", "Variant":
			return "any"
		_:
			var bare_type: String = type_name.strip_edges()
			var element: String = _element_type(bare_type)
			if not element.is_empty():
				return "list of %s" % _plural_type_word(element)
			if bare_type.begins_with("Array[") and bare_type.ends_with("]"):
				return "list"
			# Every Node class is one word to a reader: a node. Derived from ClassDB rather than a
			# list, so a class the engine adds tomorrow reads right with no edit here.
			if ClassDB.class_exists(bare_type) and ClassDB.is_parent_class(bare_type, "Node"):
				return "object"
			return bare_type


## The element type a collection holds ("Array[String]" / "PackedStringArray" -> "String"), or ""
## when the type is not a collection or names no element type. Packed*Array is normalised to the
## Array[...] spelling it behaves like, so one rule covers both.
static func _element_type(type_name: String) -> String:
	match type_name:
		"PackedStringArray":
			return "String"
		"PackedInt32Array", "PackedInt64Array", "PackedByteArray":
			return "int"
		"PackedFloat32Array", "PackedFloat64Array":
			return "float"
		"PackedVector2Array":
			return "Vector2"
		"PackedVector3Array", "PackedVector4Array":
			return "Vector3"
		"PackedColorArray":
			return "Color"
	if type_name.begins_with("Array[") and type_name.ends_with("]"):
		return type_name.substr(6, type_name.length() - 7).strip_edges()
	return ""


## The plural of a friendly type word, for "list of …". Only the words a collection actually reads
## with are spelled out; a class name is already the noun the author chose and is repeated as-is.
static func _plural_type_word(type_name: String) -> String:
	match type_name.strip_edges():
		"String", "StringName":
			return "text"
		"int", "float":
			return "numbers"
		"bool":
			return "booleans"
		"Vector2", "Vector3", "Vector4":
			return "vectors"
		"Color":
			return "colors"
		"Dictionary":
			return "tables"
		_:
			var bare_type: String = type_name.strip_edges()
			if ClassDB.class_exists(bare_type) and ClassDB.is_parent_class(bare_type, "Node"):
				return "objects"
			return bare_type


## The band's own line, drawn the way the Inspector draws a category when there is an editor theme
## to ask, and as a plain bold line when there is not (a render harness, a headless test).
static func _header_label(text: String) -> Control:
	var label: Label = Label.new()
	label.text = text
	var band: PanelContainer = PanelContainer.new()
	if Engine.is_editor_hint():
		var editor_theme: Theme = EditorInterface.get_editor_theme()
		if editor_theme != null:
			if editor_theme.has_font("bold", "EditorFonts"):
				label.add_theme_font_override("font", editor_theme.get_font("bold", "EditorFonts"))
			# The Inspector's own category ground, so the band sits among the object's other
			# categories instead of looking like something bolted on above them.
			if editor_theme.has_stylebox("bg", "EditorInspectorCategory"):
				band.add_theme_stylebox_override("panel",
					editor_theme.get_stylebox("bg", "EditorInspectorCategory"))
	band.add_child(label)
	return band


static func _muted_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.modulate = Color(1.0, 1.0, 1.0, 0.7)
	return label
