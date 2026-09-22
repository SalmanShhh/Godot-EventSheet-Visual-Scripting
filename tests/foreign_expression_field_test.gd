@tool
class_name ForeignExpressionFieldTest
extends RefCounted

# EventForge - an expression field reads the spelling another event-sheet editor uses.
#
# `Player.X + random(10) & " px"` is the first expression a reader from that editor writes, and it
# used to fail as GDScript. The field now says the GDScript it becomes and OK writes that - one truth
# on disk, so the round trip is untouched. What these pins hold:
#   1. the rewrite itself, by value: object properties, Self, `&` joining text, the functions;
#   2. `&` between two numbers stays bitwise AND unless the field takes text;
#   3. an object that is not in the scene is left as written, never guessed;
#   4. in the dialog: the field is not refused, it carries a quiet note, and OK writes the GDScript;
#   5. a keystroke after the note makes the field read afresh - a stale translation never commits.

const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = _the_rewrite()
	ok = _in_the_dialog() and ok
	return ok


static func _the_rewrite() -> bool:
	var scene: Dictionary = {"Player": "$Player", "Label": "$HUD/Label"}
	return SUPPORT.pins("foreign_expression_field_test", [
		["an object's X, a random and a joined unit",
			EventSheetForeignACEMap.field_expression("Player.X + random(10) & \" px\"", scene, true),
			"str($Player.position.x + randf_range(0.0, 10)) + \" px\""],
		["Self is the object the sheet is on",
			EventSheetForeignACEMap.field_expression("Self.X + 4", scene, false), "position.x + 4"],
		["a nested node keeps its path", EventSheetForeignACEMap.field_expression("Label.Text", scene, true),
			"$HUD/Label.text"],
		["two numbers joined by & in a number field stay bitwise AND",
			EventSheetForeignACEMap.field_expression("flags & 4", scene, false), ""],
		["but in a text field they join as text",
			EventSheetForeignACEMap.field_expression("score & lives", scene, true), "str(score) + str(lives)"],
		["a StringName literal is not a join", EventSheetForeignACEMap.field_expression("&\"idle\"", scene, true), ""],
		["an object the scene has not got is left as written",
			EventSheetForeignACEMap.field_expression("Enemy.X", scene, false), ""],
		["valid GDScript comes back unchanged", EventSheetForeignACEMap.field_expression("position.x", scene, false), ""],
	])


static func _in_the_dialog() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var scene_root: Node2D = Node2D.new()
	scene_root.name = "Level"
	var player: Node2D = Node2D.new()
	player.name = "Player"
	scene_root.add_child(player)
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	dialog.set_lint_context_provider(func() -> EventSheetResource: return sheet)
	dialog.node_validation_scene_override = scene_root
	var box: Control = dialog._create_expression_field("value", "")
	var edit: CodeEdit = box.find_children("*", "CodeEdit", true, false)[0] as CodeEdit
	dialog._fields["value"] = edit
	dialog._param_dicts["value"] = {"type": TYPE_STRING}
	edit.text = "Player.X + random(10) & \" px\""
	dialog._validate_expression_field(edit)
	var note: Dictionary = dialog._field_notes.get("value", {})
	var written: Variant = dialog._extract_value(edit)
	var refused: bool = dialog._first_invalid_expression() != null
	edit.text = "Player.X + random(10) &"
	dialog._validate_expression_field(edit)
	var after_keystroke: Variant = dialog._extract_value(edit)
	var ok: bool = SUPPORT.pins("foreign_expression_field_test", [
		["the field is not refused", refused, false],
		["it carries a quiet note, not an error", note.get("level", ""), EventSheetParamFieldFactory.LEVEL_NOTE],
		["the note says the GDScript", note.get("body", ""), "str($Player.position.x + randf_range(0.0, 10)) + \" px\""],
		["nothing is said beside OK", note.get("reason", "x"), ""],
		["OK writes the GDScript", written, "str($Player.position.x + randf_range(0.0, 10)) + \" px\""],
		["a keystroke after it reads afresh", after_keystroke, "Player.X + random(10) &"],
		["and an unfinished line is refused again", dialog._first_invalid_expression() != null, true],
	])
	box.free()
	scene_root.free()
	return ok
