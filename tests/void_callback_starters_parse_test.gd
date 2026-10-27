# EventForge - the editor-tool starters whose callback starts empty write a script Godot can parse.
#
# Tools menu item, Properties bar add-on and Context menu item each start with a `-> void` callback
# holding only a comment. The empty-body stub read the return type NAME, saw "void" there, and wrote
# `return null` - "A void function cannot return a value", so the new file failed to load the moment
# it was made. A void function's stub is `pass`, however its type is spelled.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "void_callback_starters_parse_test"
const STARTERS_PATH := "res://addons/eventsheet/editor/dock/starter_templates.gd"
## Tools menu item, Properties bar add-on, Context menu item.
const VOID_CALLBACK_STARTERS: Array[int] = [17, 18, 19]


static func run() -> bool:
	var rows: Array = []
	for starter_id: int in VOID_CALLBACK_STARTERS:
		var sheet: EventSheetResource = load(STARTERS_PATH).build_starter(starter_id)
		var output: String = str(SheetCompiler.echo(sheet, true).get("output", ""))
		rows.append(["starter %d writes no value out of a void callback" % starter_id, output.contains("\treturn null"), false])
		rows.append(["starter %d's script parses" % starter_id, _parses(output), OK])
	return SUPPORT.pins(P, rows)


## Whether `source` compiles. Its class_name is left out: the check is the body, and a name that
## collides with one the project has would fail for a reason that is not this one.
static func _parses(source: String) -> int:
	var lines: PackedStringArray = source.split("\n")
	for index: int in lines.size():
		if lines[index].begins_with("class_name "):
			lines[index] = ""
	var script: GDScript = GDScript.new()
	script.source_code = "\n".join(lines)
	return script.reload()
