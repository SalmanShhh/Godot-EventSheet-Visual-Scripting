# Godot EventSheets - shakers on channels: a shake said once, and heard by everything listening.
#
# THE ONE THING THIS FILE IS ABOUT: a channel is a GROUP. Nothing is invented - Shake Channel is a
# call_group, a listener is a node in that group, and the Node dock already shows which groups a
# node is in. So the pins here are the two halves of that: who is IN the channel (two listeners
# are, a node that never asked is not), and what one listener does when the broadcast arrives.
#
# WHY IT CAN RUN HEADLESS: a node tracks its own groups whether or not it is in a tree, and the
# arrival half is arithmetic over a delta - the same tick the pack was already paying for. The
# broadcast itself is one engine call over that membership, which is why the membership is what a
# test can honestly pin and the call is not.
#
# THE ENGINE LEDGER IS BALANCED: this test writes the effect-strength dial and puts it back exactly
# as it found it, because the suite runs serially on CI and a leaked dial quietens a later test.
@tool
class_name ShakerChannelsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PACK := preload("res://eventsheet_addons/juice/juice_behavior.gd")
const PACK_3D := preload("res://eventsheet_addons/juice_3d/juice_3d_behavior.gd")

const TEST_NAME: String = "shaker_channels"

## The project-wide dial every camera effect is already scaled by, spelled the way both packs
## spell it, so the pin asks the real question.
const EFFECT_STRENGTH: StringName = &"effect_strength"


static func run() -> bool:
	var ok: bool = true
	ok = _membership_pins() and ok
	ok = _arrival_pins() and ok
	ok = _dial_pins() and ok
	ok = _parking_pins() and ok
	ok = _twin_pins() and ok
	return ok


## Who is in the channel. Two nodes told to listen are in the group the broadcast walks; a third
## that was never told is not, which is the whole of "and nothing else in the game hears a thing".
## Stop Listening takes one of them off again and leaves the other alone.
static func _membership_pins() -> bool:
	var first: Node = PACK.new()
	var second: Node = PACK.new()
	var bystander: Node = PACK.new()
	first.listen_on_channel("props", "this node")
	second.listen_on_channel("props", "the camera")
	var joined: Array = [first.is_in_group("props"), second.is_in_group("props"), bystander.is_in_group("props")]
	var reached: Array = [first.has_method("shake_from_channel"), second.has_method("shake_from_channel")]
	first.stop_listening_on_channel("props")
	var after: Array = [first.is_in_group("props"), second.is_in_group("props")]
	# Leaving a channel a node was never on is a no-op rather than an error.
	bystander.stop_listening_on_channel("props")
	var answers: Array = [first._channel_shakes, second._channel_shakes]
	first.free()
	second.free()
	bystander.free()
	return SUPPORT.pins(TEST_NAME, [
		["both listeners are in the channel, and the bystander is not", joined, [true, true, false]],
		["a broadcast reaches every listener by the one method name", reached, [true, true]],
		["each listener keeps its own answer", answers, ["this node", "the camera"]],
		["leaving takes one off and leaves the other listening", after, [false, true]]
	])


## What one listener does when the broadcast arrives. A node listener rides the noise around the
## pose it was found in and is handed back exactly there the frame the shake runs out; a camera
## listener holds the trauma the mixer already reads up, so the two never draw two shakes at once.
static func _arrival_pins() -> bool:
	var behavior: Node = PACK.new()
	var panel: ColorRect = ColorRect.new()
	behavior.host = panel
	panel.position = Vector2(40.0, 90.0)
	behavior.listen_on_channel("hud", "this node")
	behavior.shake_from_channel(6.0, 0.4)
	behavior._process(0.2)
	var moved: bool = panel.position != Vector2(40.0, 90.0)
	behavior._process(0.2)
	var back: Vector2 = panel.position
	var camera_listener: Node = PACK.new()
	camera_listener.listen_on_channel("world", "the camera")
	camera_listener.shake_from_channel(0.5, 0.4)
	camera_listener._process(0.05)
	var trauma: float = camera_listener.current_trauma()
	behavior.free()
	panel.free()
	camera_listener.free()
	return SUPPORT.pins(TEST_NAME, [
		["a node listener is moved off its rest pose", moved, true],
		["and is handed back exactly where it was found", back, Vector2(40.0, 90.0)],
		["a camera listener holds the trauma the mixer reads up to what the channel asked for",
			trauma > 0.0 and trauma <= 0.5, true]
	])


## The magnitude a listener draws is scaled by the accessibility dial - once. A node listener
## applies it as the broadcast arrives; a camera listener does NOT, because the camera mixer
## applies the same dial itself and doing it twice would square it.
static func _dial_pins() -> bool:
	var had: bool = Engine.has_meta(EFFECT_STRENGTH)
	var was: Variant = Engine.get_meta(EFFECT_STRENGTH) if had else null
	Engine.set_meta(EFFECT_STRENGTH, 0.5)
	var node_listener: Node = PACK.new()
	node_listener.host = ColorRect.new()
	node_listener.listen_on_channel("hud", "this node")
	node_listener.shake_from_channel(0.8, 0.4)
	var scaled: float = node_listener._channel_amount
	var camera_listener: Node = PACK.new()
	camera_listener.listen_on_channel("world", "the camera")
	camera_listener.shake_from_channel(0.8, 0.4)
	var untouched: float = camera_listener._channel_amount
	if had:
		Engine.set_meta(EFFECT_STRENGTH, was)
	else:
		Engine.remove_meta(EFFECT_STRENGTH)
	var host_of_node: Node = node_listener.host
	node_listener.free()
	host_of_node.free()
	camera_listener.free()
	return SUPPORT.pins(TEST_NAME, [
		["a node listener's magnitude is scaled by the dial", is_equal_approx(scaled, 0.4), true],
		["a camera listener's is left for the mixer to scale once", is_equal_approx(untouched, 0.8), true]
	])


## The tick parks. A listener that has never heard anything is not processing; one whose shake has
## run out stops paying for the tick again, which is what makes a level full of shakers free until
## something actually shakes.
static func _parking_pins() -> bool:
	var behavior: Node = PACK.new()
	var panel: ColorRect = ColorRect.new()
	behavior.host = panel
	behavior.listen_on_channel("hud", "this node")
	var idle: bool = behavior.is_processing()
	behavior.shake_from_channel(4.0, 0.2)
	var woken: bool = behavior.is_processing()
	behavior._process(0.1)
	behavior._process(0.2)
	behavior._process(0.1)
	var parked: bool = behavior.is_processing()
	var busy: bool = behavior._channel_busy()
	behavior.free()
	panel.free()
	return SUPPORT.pins(TEST_NAME, [
		["listening on a channel costs nothing per frame", idle, false],
		["a broadcast wakes the tick", woken, true],
		["and the tick parks once the shake has run out", parked, false],
		["with nothing left to draw", busy, false]
	])


## The 3D twin answers the same broadcast with the same words, so one Shake Channel row reaches a
## prop in the level and a panel on the interface and shakes both. What differs is the only thing
## that can: a 3D host is moved in three axes.
static func _twin_pins() -> bool:
	var deep: Node = PACK_3D.new()
	var prop: Node3D = Node3D.new()
	deep.host = prop
	prop.position = Vector3(1.0, 2.0, 3.0)
	deep.listen_on_channel("props", "this node")
	deep.shake_from_channel(0.5, 0.4)
	deep._process(0.2)
	var moved: bool = prop.position != Vector3(1.0, 2.0, 3.0)
	deep._process(0.2)
	var back: Vector3 = prop.position
	var words: Array = [
		[PACK.CHANNEL_SHAKE_CAMERA, PACK.CHANNEL_SHAKE_NODE, PACK.CHANNEL_SHAKE_SCREEN],
		[PACK_3D.CHANNEL_SHAKE_CAMERA, PACK_3D.CHANNEL_SHAKE_NODE, PACK_3D.CHANNEL_SHAKE_SCREEN]
	]
	var in_group: bool = deep.is_in_group("props")
	deep.free()
	prop.free()
	return SUPPORT.pins(TEST_NAME, [
		["both packs answer with the same three words", words[0], words[1]],
		["a 3D listener joins the same kind of channel", in_group, true],
		["a 3D host is moved off its rest pose", moved, true],
		["and is handed back exactly where it was found", back, Vector3(1.0, 2.0, 3.0)]
	])
