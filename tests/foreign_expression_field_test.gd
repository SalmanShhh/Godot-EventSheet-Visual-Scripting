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
#   5. a keystroke after the note makes the field read afresh - a stale translation never commits;
#   6. the C# spellings a reader from a general-purpose engine types - Mathf, Random.Range, the
#      Distance helpers, Time.deltaTime, `$"..{x}.."` - become the Godot call, and what has no clean
#      twin (a typed-only Random.Range, a formatted slot, a Mathf call nobody spells) is refused.

const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = _the_rewrite()
	ok = _in_the_dialog() and ok
	ok = _the_csharp_spellings() and ok
	ok = _an_interpolation_in_the_dialog() and ok
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


static func _the_csharp_spellings() -> bool:
	var none: Dictionary = {}
	return SUPPORT.pins("foreign_expression_field_test", [
		["Mathf.Lerp and Mathf.InverseLerp, nested",
			EventSheetForeignACEMap.field_expression("Mathf.Lerp(0, 1, Mathf.InverseLerp(0, 400, speed))", none, false),
			"lerpf(0, 1, inverse_lerp(0, 400, speed))"],
		["Mathf.Clamp", EventSheetForeignACEMap.field_expression("Mathf.Clamp(hp, 0, 100)", none, false), "clamp(hp, 0, 100)"],
		["Mathf.Abs, Min, Max and Sqrt",
			EventSheetForeignACEMap.field_expression("Mathf.Max(Mathf.Min(Mathf.Abs(x), 5), Mathf.Sqrt(y))", none, false),
			"max(min(abs(x), 5), sqrt(y))"],
		["two whole numbers never reach the top",
			EventSheetForeignACEMap.field_expression("Random.Range(0, 10)", none, false), "randi_range(0, 9)"],
		["a decimal makes it a float, f dropped",
			EventSheetForeignACEMap.field_expression("Random.Range(0.5f, 2f)", none, false), "randf_range(0.5, 2.0)"],
		["a call inside its arguments is read whole",
			EventSheetForeignACEMap.field_expression("Random.Range(0.5f, Mathf.Max(2f, low))", none, false),
			"randf_range(0.5, max(2.0, low))"],
		["two names cannot say which, so it is left to be refused",
			EventSheetForeignACEMap.field_expression("Random.Range(low, high)", none, false), ""],
		["Vector2.Distance", EventSheetForeignACEMap.field_expression("Vector2.Distance(a, b)", none, false),
			"a.distance_to(b)"],
		["Vector3.Distance", EventSheetForeignACEMap.field_expression("Vector3.Distance(origin, target)", none, false),
			"origin.distance_to(target)"],
		["Time.deltaTime", EventSheetForeignACEMap.field_expression("speed * Time.deltaTime", none, false), "speed * delta"],
		["an interpolated string", EventSheetForeignACEMap.field_expression("$\"HP: {hp} / {max_hp}\"", none, true),
			"\"HP: %s / %s\" % [hp, max_hp]"],
		["a slot holds any expression, braces and percents survive",
			EventSheetForeignACEMap.field_expression("$\"{{{names[0] + \"!\"}}} at {rate}%\"", none, true),
			"\"{%s} at %s%%\" % [names[0] + \"!\", rate]"],
		["a formatted slot has no clean twin", EventSheetForeignACEMap.field_expression("$\"HP: {hp:0.0}\"", none, true), ""],
		["a node path is GDScript's own", EventSheetForeignACEMap.field_expression("$\"HUD/Label\"", none, false), ""],
		["an f inside quoted words is words", EventSheetForeignACEMap.field_expression("\"Level 2f\" & lives", none, true),
			"\"Level 2f\" + str(lives)"],
		["the importer is told a Mathf call it cannot spell still needs a human",
			EventSheetForeignACEMap.translate_expression("Mathf.SmoothStep(0, 1, t)")["translated"], false],
		["has_interpolation tells a pattern from a node path",
			[EventSheetForeignACEMap.has_interpolation("$\"HP: {hp}\""), EventSheetForeignACEMap.has_interpolation("$\"HUD/Label\"")],
			[true, false]],
	])


## An interpolated string LINTS as GDScript - `$"..."` is a node path there - so the field has to ask
## about it on purpose, or the reader's text would be committed as a path to a node called "HP: {hp}".
static func _an_interpolation_in_the_dialog() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	dialog.set_lint_context_provider(func() -> EventSheetResource: return sheet)
	var box: Control = dialog._create_expression_field("value", "")
	var edit: CodeEdit = box.find_children("*", "CodeEdit", true, false)[0] as CodeEdit
	dialog._fields["value"] = edit
	dialog._param_dicts["value"] = {"type": TYPE_STRING}
	edit.text = "$\"Speed: {Mathf.Abs(4)}\""
	dialog._validate_expression_field(edit)
	var ok: bool = SUPPORT.pins("foreign_expression_field_test", [
		["the note says the GDScript", (dialog._field_notes.get("value", {}) as Dictionary).get("body", ""),
			"\"Speed: %s\" % [abs(4)]"],
		["OK writes the GDScript", dialog._extract_value(edit), "\"Speed: %s\" % [abs(4)]"],
	])
	box.free()
	return ok
