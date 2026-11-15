# Godot EventSheets - the three classic Godot mistakes, each pinned to fire when it should and to stay
# quiet beside its look-alike.
#
# A Control set to a position inside a Container is moved back by the Container; a Tween on a rigid
# body's position or scale fights the physics engine; a behaviour that moves its parent fights it too
# when that parent is a rigid body. The sheet says so on the row (quiet amber, the words in the help
# strip). Every pin here holds the other half as firmly: the same row on a node that is NOT in the
# trap (a Control under a plain Control, a character body, an animatable body, a child Sprite2D, a
# behaviour told to act on another node) earns nothing, and so does a sheet no scene runs.
#
# The scenes are tests/fixtures/classic_box.tscn, classic_body.tscn and classic_ride.tscn: a script is
# judged against them by passing its fixture path, which is how the editor finds the scene a sheet runs in.
@tool
class_name ClassicMistakesTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME: String = "classic_mistakes"

const FIX := "res://tests/fixtures/classic_"
const IN_BOX := FIX + "in_box.gd"
const LOOSE := FIX + "loose.gd"
const BARE := FIX + "bare.gd"
const MENU := FIX + "menu.gd"
const BALL := FIX + "ball.gd"
const BALL_3D := FIX + "ball_3d.gd"
const WALKER := FIX + "walker.gd"
const DOOR := FIX + "door.gd"
const RIDER := FIX + "rider.gd"
const SITTER := FIX + "sitter.gd"
const ACTS := FIX + "acts.gd"

const CONTAINER := "control-inside-a-container"
const TWEEN := "tween-fights-physics-body"
const BEHAVIOUR := "behaviour-fights-physics-body"

## A behaviour the way a pack is written: it finds its host from its parent and moves it every frame.
const MOVER := "class_name ClassicMover\nextends Node\n\nvar host: Node2D = null\n\n\nfunc _enter_tree() -> void:\n\thost = get_parent() as Node2D\n\n\nfunc _process(delta: float) -> void:\n\thost.position.x += 40.0 * delta\n"
const PUSHER := "class_name ClassicPusher\nextends Node\n\nvar host: RigidBody2D = null\n\n\nfunc _enter_tree() -> void:\n\thost = get_parent() as RigidBody2D\n\n\nfunc _process(_delta: float) -> void:\n\thost.apply_central_impulse(Vector2.RIGHT)\n"


static func run() -> bool:
	EventSheetSceneConnections.clear_cache()
	EventSheetMistakeFindings.clear_cache()
	var ok: bool = true
	ok = _container_pins() and ok
	ok = _tween_pins() and ok
	ok = _behaviour_pins() and ok
	ok = _word_pins() and ok
	EventSheetMistakeFindings.clear_cache()
	return ok


## The classic findings of a sheet reopened from source, as [kind, subject] rows.
static func _rows(source: String, script_path: String) -> Array:
	var sheet: EventSheetResource = SUPPORT.reopen(source, true, script_path)
	return _brief(EventSheetMistakeFindings.findings(sheet, script_path))


static func _brief(found: Array[Dictionary]) -> Array:
	var brief: Array = []
	for finding: Dictionary in found:
		if [CONTAINER, TWEEN, BEHAVIOUR].has(str(finding["kind"])):
			brief.append([finding["kind"], finding["subject"]])
	return brief


## A sheet with one event holding one action built by hand - the way a picked row is stored.
static func _picked(ace_id: String, params: Dictionary, script_path: String) -> Array:
	var sheet: EventSheetResource = EventSheetResource.new()
	var event_row: EventRow = EventRow.new()
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	event_row.actions = [action]
	sheet.events = [event_row]
	return _brief(EventSheetMistakeFindings.findings(sheet, script_path))


static func _body(statement: String, base: String = "Button") -> String:
	return "extends %s\n\n\nfunc _ready() -> void:\n\t%s\n" % [base, statement]


static func _container_pins() -> bool:
	var place: String = "position = Vector2(10, 10)"
	return SUPPORT.pins(TEST_NAME, [
		["a Button in a VBoxContainer that is given a position is a finding, named by its node", _rows(_body(place), IN_BOX), [[CONTAINER, "InBox"]]],
		["the picked Set Control Position row says the same", _picked("SetControlPosition", {"pos": "Vector2(0, 0)"}, IN_BOX), [[CONTAINER, "InBox"]]],
		["moving it by one axis is the same mistake", _rows(_body("position.x = 4.0"), IN_BOX), [[CONTAINER, "InBox"]]],
		["adding to the position is the same mistake", _rows(_body("position += Vector2(1, 0)"), IN_BOX), [[CONTAINER, "InBox"]]],
		["the same row on a Button under a plain Control is quiet", _rows(_body(place), LOOSE), []],
		["under the base Container class, which arranges nothing, is quiet", _rows(_body(place), BARE), []],
		["a sheet no scene runs earns nothing", _rows(_body(place), ""), []],
		["a script no scene uses earns nothing", _rows(_body(place), "res://tests/fixtures/classic_nobody.gd"), []],
		["another node's position, in a Container, is a finding named by that node", _rows(_body("$Box/Label.position = Vector2(2, 2)", "Control"), MENU), [[CONTAINER, "Label"]]],
		["another node's position, under a plain Control, is quiet", _rows(_body("$Free/Loose.position = Vector2(2, 2)", "Control"), MENU), []],
		["the Container itself, under a plain Control, is quiet", _rows(_body("$Box.position = Vector2(2, 2)", "Control"), MENU), []],
		["a node held in a variable is never judged", _rows(_body("some_node.position = Vector2(2, 2)", "Control"), MENU), []],
		["the size is a different row: not this finding", _rows(_body("size = Vector2(2, 2)"), IN_BOX), []],
		["a comment that says it is quiet", _rows(_body("pass # position = Vector2(1, 1)"), IN_BOX), []],
	])


static func _tween_pins() -> bool:
	var slide: String = "create_tween().tween_property(self, \"%s\", Vector2(100, 0), 0.5)"
	return SUPPORT.pins(TEST_NAME, [
		["a Tween on a RigidBody2D's position is a finding, named by the body", _rows(_body(slide % "position", "RigidBody2D"), BALL), [[TWEEN, "Ball"]]],
		["its scale too", _rows(_body(slide % "scale", "RigidBody2D"), BALL), [[TWEEN, "Ball"]]],
		["its global position too", _rows(_body(slide % "global_position", "RigidBody2D"), BALL), [[TWEEN, "Ball"]]],
		["one axis of it too", _rows(_body(slide % "position:x", "RigidBody2D"), BALL), [[TWEEN, "Ball"]]],
		["the picked Tween Property row says the same", _picked("TweenProperty", {"target": "self", "property": "\"position\"", "value": "Vector2(100, 0)", "duration": "0.5", "transition": "Tween.TRANS_SINE", "ease": "Tween.EASE_IN_OUT"}, BALL), [[TWEEN, "Ball"]]],
		["a RigidBody3D is the same", _rows(_body(slide % "position", "RigidBody3D"), BALL_3D), [[TWEEN, "Ball3D"]]],
		["a property the engine does not move is quiet", _rows(_body(slide % "modulate", "RigidBody2D"), BALL), []],
		["the same Tween on the Sprite2D inside the body is quiet", _rows(_body("create_tween().tween_property($Sprite, \"position\", Vector2(0, -8), 0.5)", "RigidBody2D"), BALL), []],
		["on a CharacterBody2D is quiet: code moves it on purpose", _rows(_body(slide % "position", "CharacterBody2D"), WALKER), []],
		["on an AnimatableBody2D is quiet: it is made to be moved", _rows(_body(slide % "position", "AnimatableBody2D"), DOOR), []],
		["a sheet no scene runs earns nothing", _rows(_body(slide % "position", "RigidBody2D"), ""), []],
		["a property held in a variable is never judged", _rows(_body("create_tween().tween_property(self, which, Vector2(100, 0), 0.5)", "RigidBody2D"), BALL), []],
	])


static func _behaviour_pins() -> bool:
	return SUPPORT.pins(TEST_NAME, [
		["a behaviour that moves its parent, under a RigidBody2D, is a finding, named by the body", _rows(MOVER, RIDER), [[BEHAVIOUR, "Crate"]]],
		["the same behaviour under a plain Node2D is quiet", _rows(MOVER, SITTER), []],
		["told to act on another node it is not judged by what it sits under", _rows(MOVER, ACTS), []],
		["a behaviour that only pushes the body with an impulse is quiet", _rows(PUSHER, RIDER), []],
		["a sheet no scene runs earns nothing", _rows(MOVER, ""), []],
		["it is said once, however many rows write the position", _rows(MOVER.replace("\thost.position.x += 40.0 * delta\n", "\thost.position.x += 40.0 * delta\n\thost.position.y += 1.0\n"), RIDER), [[BEHAVIOUR, "Crate"]]],
	])


static func _word_pins() -> bool:
	var container: Array[Dictionary] = EventSheetMistakeFindings.findings(
		SUPPORT.reopen(_body("position = Vector2(10, 10)"), true, IN_BOX), IN_BOX)
	var tween: Array[Dictionary] = EventSheetMistakeFindings.findings(
		SUPPORT.reopen(_body("create_tween().tween_property(self, \"position\", Vector2(100, 0), 0.5)", "RigidBody3D"), true, BALL_3D), BALL_3D)
	var behaviour: Array[Dictionary] = EventSheetMistakeFindings.findings(SUPPORT.reopen(MOVER, true, RIDER), RIDER)
	var say: Callable = func(found: Array[Dictionary], kind: String) -> Dictionary:
		for finding: Dictionary in found:
			if str(finding["kind"]) == kind:
				return finding
		return {"message": "", "severity": "", "fix": "x"}
	var in_box: Dictionary = say.call(container, CONTAINER)
	var ball: Dictionary = say.call(tween, TWEEN)
	var crate: Dictionary = say.call(behaviour, BEHAVIOUR)
	return SUPPORT.pins(TEST_NAME, [
		["each is quiet amber: a warning, never an error", [in_box["severity"], ball["severity"], crate["severity"]], ["warning", "warning", "warning"]],
		["and offers no door, the sentence is the answer", [in_box["fix"], ball["fix"], crate["fix"]], ["", "", ""]],
		["the Container sentence names the Container and what to do", [str(in_box["message"]).contains("VBoxContainer"), str(in_box["message"]).contains("plain Control node"), str(in_box["message"]).contains("size flags")], [true, true, true]],
		["the Tween sentence names the body, the property and a child node to use", [str(ball["message"]).contains("RigidBody3D"), str(ball["message"]).contains("Tween on its position"), str(ball["message"]).contains("Tween a child node")], [true, true, true]],
		["a 3D body is told the 3D impulse row", str(ball["message"]).contains("Apply Central Impulse (3D)"), true],
		["the behaviour sentence names the body and the property", [str(crate["message"]).contains("under Crate, a RigidBody2D"), str(crate["message"]).contains("parent's position")], [true, true]],
		["and says what to put it on", str(crate["message"]).contains("not a physics body"), true],
		["the Doctor files each under its own check id", [
			EventSheetMistakeChecksDoctor.script_findings(IN_BOX, container)[0]["check"],
			EventSheetMistakeChecksDoctor.script_findings(BALL_3D, tween)[0]["check"],
			EventSheetMistakeChecksDoctor.script_findings(RIDER, behaviour)[0]["check"]], [CONTAINER, TWEEN, BEHAVIOUR]],
		["a script that tweens or writes a position is worth opening for them", [
			EventSheetMistakeChecksDoctor.evidence("extends Node2D\n\nfunc go() -> void:\n\tcreate_tween().tween_property(self, \"position\", Vector2.ZERO, 1.0)\n") > 0,
			EventSheetMistakeChecksDoctor.evidence("extends Control\n\nfunc go() -> void:\n\tposition = Vector2.ZERO\n") > 0,
			EventSheetMistakeChecksDoctor.evidence("extends Node\n\nfunc go() -> void:\n\tpass\n")], [true, true, 0]],
	])
