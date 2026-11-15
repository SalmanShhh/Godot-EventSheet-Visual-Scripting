# Godot EventSheets - a row from a shipped pack starts on the one node of the open scene that wears it.
#
# Before this, only a script of the reader's own was aimed at the scene; a pack row always started on
# `$ClassName`, so a Juice Player called HitJuice (or an old FeedbackPlayer called HitFeedback) got
# rows that failed at run time with "node not found" until each was retargeted. A node counts as a
# wearer when its script IS the pack script or EXTENDS it, which is what lets an old FeedbackPlayer
# node (the old name extends the new class) be found by a row from the new file.
class_name JuiceRowAimingTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const APPLY := preload("res://addons/eventsheet/editor/dock/ace_apply.gd")

const TEST_NAME: String = "juice_row_aiming"
const NEW_PATH: String = "res://eventsheet_addons/juice/juice_player.gd"
const OLD_PATH: String = "res://eventsheet_addons/juice/feedback_player.gd"


static func run() -> bool:
	var source: String = NEW_PATH if ResourceLoader.exists(NEW_PATH) else OLD_PATH
	var play: ACEDefinition = null
	for definition: ACEDefinition in EventSheetACEGenerator.new().generate_from_script(load(source)):
		if definition.id == "method:play":
			play = definition
	var start: String = _target(play)
	var root: Node2D = Node2D.new()
	root.name = "Level"
	var hit: Node = (load(OLD_PATH) as GDScript).new()
	hit.name = "HitFeedback"
	root.add_child(hit)
	var one_old: String = _target(APPLY.aimed_at_scene(play, root))
	var second: Node = (load(source) as GDScript).new()
	second.name = "HitJuice"
	root.add_child(second)
	var two: String = _target(APPLY.aimed_at_scene(play, root))
	hit.free()
	var one_new: String = _target(APPLY.aimed_at_scene(play, root))
	root.free()
	return SUPPORT.pins(TEST_NAME, [
		["one old-name node in the scene: the row starts on it", one_old, "$HitFeedback"],
		["two wearers: the row keeps its starting value", two, start],
		["one node made from the pack file: the row starts on it", one_new, "$HitJuice"],
		["the shared definition is never written to", _target(play), start],
	])


static func _target(definition: ACEDefinition) -> String:
	if definition == null:
		return "<no play row>"
	for parameter: Variant in definition.parameters:
		if parameter is Dictionary and str((parameter as Dictionary).get("id", "")) == "target":
			return str((parameter as Dictionary).get("default_value", ""))
	return ""
