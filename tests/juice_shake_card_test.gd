# Godot EventSheets - the Shake card's Fade in and Fade out ticks, its Custom curve, and the two
# Juice rows that shake for a length: Shake For and Shake With Curve.
#
# THE ONE THING THIS FILE IS ABOUT: a shake the user times lasts exactly the Seconds they typed and
# has the shape they asked for, while a Shake card saved before the ticks existed, and the shipped
# Shake row, shake exactly as they always have (trauma that fades at the Juice node's Shake Decay).
# The shape is applied to the amount BEFORE the camera squares it, a timed shake adds to the trauma
# under the same cap of 1, and Stop Shake ends both kinds and says so.
#
# The suite has no scene tree, so the Juice node's frame is stepped by hand: the trauma and the timed
# level advance without a camera. What the camera does with them (the offset, a camera that ignores
# rotation, the camera put back exactly) is measured on a running tree, frame by frame.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const TEST_NAME: String = "juice_shake_card"

const JUICE: String = "res://eventsheet_addons/juice/juice_behavior.gd"
const PLAYER: String = "res://eventsheet_addons/juice/juice_player.gd"
const SCHEMA: String = "res://addons/eventsheet/editor/inspector/feedback_card_schema.gd"
## The file both the Juice node and the Juice Player already share, where the shape is written once
## so the editor preview of a Shake card and the running shake can never disagree.
const RUNNER: String = "res://eventsheet_addons/juice/moment_runner.gd"

## One frame at 60 frames a second.
const FRAME: float = 1.0 / 60.0

## The row that has shipped, and the line it writes. Frozen.
const SHAKE_TEMPLATE: String = "## @ace_codegen_template(\"$JuiceBehavior.shake({strength})\")"


static func run() -> bool:
	var ok: bool = true
	ok = _trauma_pins() and ok
	return ok


## Today's shake, pinned before anything moves: Shake 0.4 loses 1.4 a second whatever Seconds says.
## The numbers were measured on a running tree with the code as it stood before the timed shake.
static func _trauma_pins() -> bool:
	var juice: Node = (load(JUICE) as GDScript).new()
	var heard: Array = [0]
	juice.connect("shake_stopped", func() -> void: heard[0] += 1)
	juice.call("shake", 0.4)
	_step(juice, 6)
	var after_six: float = snappedf(float(juice.call("current_trauma")), 0.001)
	_step(juice, 12)
	var after_eighteen: bool = bool(juice.call("is_shaking"))
	var stopped_alone: int = heard[0]
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["a trauma shake of 0.4 is 0.26 after six frames", after_six, 0.26],
		["and over after eighteen (0.3 s), however long the card said", after_eighteen, false],
		["On Shake Stopped is heard once when it fades out", stopped_alone, 1],
	])
	juice.free()
	return ok


## Steps a Juice node's frame by hand.
static func _step(juice: Node, frames: int) -> void:
	for frame: int in range(frames):
		juice.call("_process", FRAME)
