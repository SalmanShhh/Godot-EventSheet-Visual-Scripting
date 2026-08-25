# The Input Map read as an object: which actions the project declares, what each one is bound
# to in the sheet's spelling, its deadzone as a percent, and which object its rows read on.
#
# Every check pins a VALUE (the exact words a bar or a row shows), never a count, because the point
# of this layer is the wording.
@tool
class_name InputMapFactsTest
extends RefCounted


static func run() -> bool:
	var passed: bool = true
	passed = _check_project_actions() and passed
	passed = _check_binding_words() and passed
	passed = _check_deadzone_and_object() and passed
	passed = _check_player_conventions() and passed
	passed = _check_gamepad_words() and passed
	return passed


## The names come from the `[input]` section of project.godot, so the engine's own ui_text_* defaults
## never crowd out the actions a game is about.
static func _check_project_actions() -> bool:
	EventSheetInputMapFacts.clear_cache()
	var names: PackedStringArray = EventSheetInputMapFacts.project_action_names()
	var passed: bool = _pin("project actions are the ones project.godot declares",
		", ".join(names), "ui_left, ui_right, ui_up, ui_down")
	passed = _pin("an action the project declares is known",
		str(EventSheetInputMapFacts.has_action("ui_left")), "true") and passed
	passed = _pin("an action the project does not declare is the row's warning",
		str(EventSheetInputMapFacts.has_action("dash")), "false") and passed
	# The LIST is the project's own, so a bar led by ui_text_backspace_word can never happen. But a row
	# that NAMES an engine default is right, and flagging it would be the bar crying wolf about the
	# controls Godot ships with - so the two questions have two answers.
	passed = _pin("an engine default is not in the project's list",
		str(Array(names).has("ui_accept")), "false") and passed
	passed = _pin("...but a row that names one is not flagged",
		str(EventSheetInputMapFacts.has_action("ui_accept")), "true") and passed
	passed = _pin("an engine default reads with its own bindings",
		EventSheetInputMapFacts.bindings_line("ui_accept"), "Enter · Kp Enter · Space") and passed
	return passed


## The chip the Object bar and the row note show.
static func _check_binding_words() -> bool:
	EventSheetInputMapFacts.clear_cache()
	var passed: bool = _pin("bindings read as the keys they are",
		EventSheetInputMapFacts.bindings_line("ui_left"), "Left · A")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	passed = _pin("a key binding is the name Godot prints",
		EventSheetInputMapFacts.binding_words(key), "Space") and passed
	var joy_button := InputEventJoypadButton.new()
	joy_button.button_index = JOY_BUTTON_A
	passed = _pin("a gamepad button binding is the Gamepad object's word",
		EventSheetInputMapFacts.binding_words(joy_button), "A button") and passed
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	passed = _pin("a stick binding is the stick, not one of its two axes",
		EventSheetInputMapFacts.binding_words(motion), "Left stick") and passed
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	passed = _pin("a trigger binding says trigger",
		EventSheetInputMapFacts.binding_words(trigger), "Right trigger") and passed
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	passed = _pin("a mouse binding is the Mouse object's word",
		EventSheetInputMapFacts.binding_words(mouse), "Left mouse button") and passed
	return passed


## The deadzone reads the way the Gamepad object shows its Analog deadzone property - a percent.
static func _check_deadzone_and_object() -> bool:
	EventSheetInputMapFacts.clear_cache()
	var passed: bool = _pin("the deadzone reads as a percent",
		EventSheetInputMapFacts.deadzone_percent("ui_left"), "20%")
	passed = _pin("an action bound to keys reads on the Keyboard",
		EventSheetInputMapFacts.object_of("ui_left"), "Keyboard") and passed
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	passed = _pin("a mouse binding belongs to the Mouse object",
		EventSheetInputMapFacts.binding_object(mouse), "Mouse") and passed
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_B
	passed = _pin("a gamepad binding belongs to the Gamepad object",
		EventSheetInputMapFacts.binding_object(joy), "Gamepad") and passed
	var touch := InputEventScreenTouch.new()
	passed = _pin("a finger belongs to the Touch object",
		EventSheetInputMapFacts.binding_object(touch), "Touch") and passed
	return passed


## The two per-player naming conventions a local-multiplayer project uses.
static func _check_player_conventions() -> bool:
	var passed: bool = _pin("p2_jump is jump on gamepad 1",
		"%s on gamepad %d" % [EventSheetInputMapFacts.base_action_words("p2_jump"),
			EventSheetInputMapFacts.gamepad_number_of("p2_jump")], "jump on gamepad 1")
	passed = _pin("jump_2 is jump on gamepad 1",
		"%s on gamepad %d" % [EventSheetInputMapFacts.base_action_words("jump_2"),
			EventSheetInputMapFacts.gamepad_number_of("jump_2")], "jump on gamepad 1") and passed
	passed = _pin("p3_fire is fire on gamepad 2",
		"%s on gamepad %d" % [EventSheetInputMapFacts.base_action_words("p3_fire"),
			EventSheetInputMapFacts.gamepad_number_of("p3_fire")], "fire on gamepad 2") and passed
	passed = _pin("a plain action carries no gamepad number",
		str(EventSheetInputMapFacts.gamepad_number_of("jump")), "-1") and passed
	passed = _pin("a plain action keeps its whole name",
		EventSheetInputMapFacts.base_action_words("move_left"), "move_left") and passed
	return passed


## The axis and button names the Compare axis condition and the Gamepad expressions show, from both
## spellings a row can carry: Godot's stored number and the constant a template writes.
static func _check_gamepad_words() -> bool:
	var passed: bool = _pin("an axis constant reads as the Gamepad object's word",
		EventSheetInputMapFacts.axis_words("JOY_AXIS_LEFT_X"), "Left analog X")
	passed = _pin("a stored axis number reads the same",
		EventSheetInputMapFacts.axis_words(3), "Right analog Y") and passed
	passed = _pin("a trigger axis reads as a trigger",
		EventSheetInputMapFacts.axis_words("JOY_AXIS_TRIGGER_RIGHT"), "Right trigger") and passed
	passed = _pin("a button constant reads as the Gamepad object's word",
		EventSheetInputMapFacts.button_words("JOY_BUTTON_A"), "A") and passed
	passed = _pin("a d-pad button reads as the d-pad",
		EventSheetInputMapFacts.button_words("JOY_BUTTON_DPAD_UP"), "D-pad up") and passed
	passed = _pin("a stored button number reads the same",
		EventSheetInputMapFacts.button_words(9), "Left shoulder") and passed
	return passed


static func _pin(label: String, actual: String, expected: String) -> bool:
	if actual == expected:
		print("[PASS] input_map_facts_test: %s" % label)
		return true
	print("[FAIL] input_map_facts_test: %s -> %s (expected %s)" % [label, actual, expected])
	return false
