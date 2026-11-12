# Godot EventSheets - the everyday object rows, under the words people look for them by.
#
# Pins, by VALUE: the line each new row writes (the bare Godot property or call), that opacity reads as
# a percentage while the script keeps 0 to 1, that the two on-screen rows which ignore the camera are
# deprecated with the address of the right one and still compile, and that Once Ever runs an event one
# time for the life of the object where Trigger Once re-arms.
@tool
class_name CommonObjectRowsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME: String = "common_object_rows_test"


static func run() -> bool:
	var passed: bool = true
	passed = _the_lines_the_rows_write() and passed
	passed = _opacity_reads_as_a_percentage() and passed
	passed = _the_camera_blind_rows_are_retired() and passed
	passed = _once_ever() and passed
	passed = _the_notifier_goes_in_with_the_row() and passed
	return passed


static func _template(ace_id: String) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	return descriptor.codegen_template if descriptor != null else "(missing)"


static func _sheet_with(condition_id: String, action_id: String, action_params: Dictionary) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	if not condition_id.is_empty():
		var condition: ACECondition = ACECondition.new()
		condition.provider_id = "Core"
		condition.ace_id = condition_id
		# What the dock bakes into a row when it is applied: the template and the member the row declares.
		var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", condition_id)
		condition.codegen_template = descriptor.codegen_template.replace("{uid}", "t1")
		condition.member_declaration = descriptor.member_template.replace("{uid}", "t1")
		condition.evaluate_last = descriptor.evaluate_last
		event.conditions.append(condition)
	if not action_id.is_empty():
		var action: ACEAction = ACEAction.new()
		action.provider_id = "Core"
		action.ace_id = action_id
		action.params = action_params
		event.actions.append(action)
	sheet.events.append(event)
	return sheet


static func _the_lines_the_rows_write() -> bool:
	var passed: bool = SUPPORT.pins(NAME, [
		["Set Opacity writes the alpha of the tint", _template("SetOpacity"), "{target.}modulate.a = {opacity}"],
		["Opacity reads the alpha of the tint", _template("Opacity"), "{target.}modulate.a"],
		["Set Sprite Size writes the scale that gives the size", _template("SetSpriteSize"), "{target.}scale = {size} / texture.get_size()"],
		["Width is the picture's width times the scale", _template("SpriteWidth"), "(get_rect().size.x * scale.x)"],
		["Height is the picture's height times the scale", _template("SpriteHeight"), "(get_rect().size.y * scale.y)"],
		["Left edge", _template("SpriteLeft"), "(global_position.x + get_rect().position.x * scale.x)"],
		["Right edge", _template("SpriteRight"), "(global_position.x + get_rect().end.x * scale.x)"],
		["Top edge", _template("SpriteTop"), "(global_position.y + get_rect().position.y * scale.y)"],
		["Bottom edge", _template("SpriteBottom"), "(global_position.y + get_rect().end.y * scale.y)"],
		["Instance Id is get_instance_id()", _template("InstanceId"), "{target.}get_instance_id()"],
		["Marker Position reads the Marker2D child", _template("MarkerPosition"), "(get_node({marker}) as Node2D).global_position"],
		["Outside the level bounds asks a Rect2", _template("IsOutsideLevelBounds"), "not {bounds}.has_point(global_position)"],
	])
	var output: String = SUPPORT.compile_output(_sheet_with("", "SetOpacity", {"opacity": "0.5"}))
	passed = SUPPORT.pin_value(NAME, "a Set Opacity row compiles to the bare property line", output.contains("\tmodulate.a = 0.5\n"), true) and passed
	var sized: String = SUPPORT.compile_output(_sheet_with("", "SetSpriteSize", {"size": "Vector2(96, 96)"}))
	passed = SUPPORT.pin_value(NAME, "a Set Sprite Size row compiles to the scale line", sized.contains("\tscale = Vector2(96, 96) / texture.get_size()\n"), true) and passed
	return passed


static func _opacity_reads_as_a_percentage() -> bool:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "SetOpacity")
	var lens: String = descriptor.params[0].display_lens if descriptor != null and not descriptor.params.is_empty() else ""
	var host: String = descriptor.node_type if descriptor != null else ""
	return SUPPORT.pins(NAME, [
		["the opacity field reads through the fraction lens", lens, EventForgeValueLens.LENS_FRACTION],
		["0.5 reads as 50%", EventForgeValueLens.read(lens, "0.5"), "50%"],
		["1.0 reads as 100%", EventForgeValueLens.read(lens, "1.0"), "100%"],
		["an expression is left as it is written", EventForgeValueLens.read(lens, "fade_amount"), "fade_amount"],
		["it is offered on anything drawn", host, "CanvasItem"],
		["its description names the property it writes", descriptor.description.contains("modulate.a"), true],
	])


static func _the_camera_blind_rows_are_retired() -> bool:
	var on_screen: ACEDescriptor = ACERegistry.find_descriptor("Core", "IsOnScreen")
	var outside: ACEDescriptor = ACERegistry.find_descriptor("Core", "IsOutsideLayout")
	var passed: bool = SUPPORT.pins(NAME, [
		["Is On-Screen is deprecated", on_screen.is_deprecated, true],
		["Is On-Screen carries the address of the right row", on_screen.replacement_ace_id, "Core::RenderingIsOnScreen"],
		["Is Outside Layout is deprecated", outside.is_deprecated, true],
		["Is Outside Layout carries the address of the right row", outside.replacement_ace_id, "Core::RenderingIsOnScreen"],
		["Is Outside Layout is no longer featured", outside.is_featured, false],
		["Is On-Screen keeps writing the line it always did", on_screen.codegen_template, "{target.}get_viewport_rect().has_point({point})"],
		["Is Outside Layout keeps writing the line it always did", outside.codegen_template, "not get_viewport_rect().has_point({point})"],
	])
	var old: String = SUPPORT.compile_output(_sheet_with("IsOnScreen", "SetOpacity", {"opacity": "0.5"}))
	passed = SUPPORT.pin_value(NAME, "a sheet that already used Is On-Screen still compiles it unchanged", old.contains("get_viewport_rect().has_point("), true) and passed
	return passed


static func _once_ever() -> bool:
	var output: String = SUPPORT.compile_output(_sheet_with("OnceEver", "SetOpacity", {"opacity": "0.5"}))
	var trigger_once: String = SUPPORT.compile_output(_sheet_with("TriggerOnce", "SetOpacity", {"opacity": "0.5"}))
	return SUPPORT.pins(NAME, [
		["Once Ever declares one plain bool on the script", output.contains("var __once_ever_seen_t1: bool = false"), true],
		["and sets it the first time it is asked", output.contains("= true\n\treturn true"), true],
		["and says false from then on", output.contains("\t\treturn false\n"), true],
		["Trigger Once keeps its own, different, bookkeeping", trigger_once.contains("__once_ever_seen_t1"), false],
	])


## Adding Is On Screen puts a VisibleOnScreenNotifier2D under the node it asks about, owned by the scene
## so it is saved, and does not add a second one when one is there. (The one-undo-step half is proven in
## the real editor; a test run has no editor undo history.)
static func _the_notifier_goes_in_with_the_row() -> bool:
	var scene_root: Node2D = Node2D.new()
	scene_root.name = "Level"
	var enemy: Node2D = Node2D.new()
	enemy.name = "Enemy"
	scene_root.add_child(enemy)
	enemy.owner = scene_root
	var plain: Node = Node.new()
	plain.name = "Timer"
	scene_root.add_child(plain)
	var notifier_script: GDScript = load("res://addons/eventsheet/editor/dock/on_screen_notifier.gd") as GDScript
	var before: Node = notifier_script.needs_notifier(scene_root, "$Enemy")
	var added: Node = notifier_script.add_under(before, scene_root)
	var after: Node = notifier_script.needs_notifier(scene_root, "$Enemy")
	var passed: bool = SUPPORT.pins(NAME, [
		["the row's node, written $Enemy, is found in the scene", before, enemy],
		["self is the node that runs the sheet", notifier_script.target_of(scene_root, "self"), scene_root],
		["no node text at all is that node too", notifier_script.target_of(scene_root, ""), scene_root],
		["a path that leads nowhere finds nothing", notifier_script.target_of(scene_root, "$Nobody"), null],
		["the notifier is a child of the node it asks about", added.get_parent(), enemy],
		["named as Godot names the node", str(added.name), "VisibleOnScreenNotifier2D"],
		["owned by the scene, so it is saved with it", added.owner, scene_root],
		["a node that has one needs no second", after, null],
		["a node that is not drawn gets none", notifier_script.needs_notifier(scene_root, "$Timer"), null],
	])
	scene_root.free()
	return passed
