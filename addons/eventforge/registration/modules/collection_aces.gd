# EventForge module - Collections (rich variables)
#
# Curated Dictionary/Array/JSON vocabulary - every op a direct GDScript one-liner.
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility
# covenant); this file only changes where the descriptors are AUTHORED.
@tool
class_name EventForgeCollectionACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The named parts a pair, a triple, a colour or a record can be read and written by, shared by
## Part Of and Set Part Of so the two sides can never drift apart. The keys are QUOTED strings
## because the emitted access is a subscript (`velocity["y"]`, `save["score"]`): Godot resolves a
## string subscript as a COMPONENT on Vector2/Vector3/Color and as a FIELD on a Dictionary, which is
## what lets one verb speak about all four. The labels carry the plain-English half ("the up/down
## part" rather than ".y"). An option value can never contain a {param} placeholder - substitution
## is a single left-to-right pass, so a placeholder arriving FROM an option would be emitted
## literally into the user's GDScript.
## The warning the type-guarded fallbacks all owe the author, in the ROW's own help rather than only
## in a code comment: their guard re-reads the value expression, so a value that CHANGES something
## each time it is read (a method that consumes, deals or advances) runs twice per row.
const DOUBLE_READ_NOTE := "The value is read twice in the emitted line, so keep it a plain read and not something that changes the game."

const PART_OPTIONS: Array = [
	{"key": "\"x\"", "label": "X (left / right)"},
	{"key": "\"y\"", "label": "Y (up / down)"},
	{"key": "\"z\"", "label": "Z (forward / back)"},
	{"key": "\"r\"", "label": "Red"},
	{"key": "\"g\"", "label": "Green"},
	{"key": "\"b\"", "label": "Blue"},
	{"key": "\"a\"", "label": "Alpha (see-through)"}
]


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Collections (rich variables): curated Dictionary / Array / JSON vocabulary ──
	# Event sheets ship these as capability addons; here every op is a direct GDScript one-liner
	# (parity-safe) and the templates double as GDScript teachers. The long tail stays
	# one fx away. Variable params use "variable_reference:<Type>" so dropdowns offer
	# only matching (or Variant/untyped) variables.
	# Dictionary
	descriptors.append(F.make_descriptor("Core", "DictSetKey", "Set Key", ACEDescriptor.ACEType.ACTION, "{var_name}[{key}] = {value}", "", [F.make_param("var_name", "String", "dict", "Dictionary", "Dictionary variable to write into.", "variable_reference:Dictionary"), F.make_param("key", "String", "\"key\"", "Key", "Key expression.", "expression"), F.make_param("value", "String", "0", "Value", "Value expression.", "expression")], "Variables: Dictionary", "Set {var_name}[{key}] to {value}")
		.described("Stores a value under a key in a dictionary variable, adding or overwriting it."))
	descriptors.append(F.make_descriptor("Core", "DictDeleteKey", "Delete Key", ACEDescriptor.ACEType.ACTION, "{var_name}.erase({key})", "", [F.make_param("var_name", "String", "dict", "Dictionary", "Dictionary variable.", "variable_reference:Dictionary"), F.make_param("key", "String", "\"key\"", "Key", "Key to remove.", "expression")], "Variables: Dictionary", "Delete key {key} from {var_name}")
		.described("Removes a key and its value from a dictionary variable."))
	descriptors.append(F.make_descriptor("Core", "DictClear", "Clear Dictionary", ACEDescriptor.ACEType.ACTION, "{var_name}.clear()", "", [F.make_param("var_name", "String", "dict", "Dictionary", "Dictionary variable.", "variable_reference:Dictionary")], "Variables: Dictionary", "Clear {var_name}")
		.described("Empties a dictionary variable, removing every key and value."))
	descriptors.append(F.make_descriptor("Core", "DictMerge", "Merge Dictionary", ACEDescriptor.ACEType.ACTION, "{var_name}.merge({other}, true)", "", [F.make_param("var_name", "String", "dict", "Dictionary", "Destination dictionary.", "variable_reference:Dictionary"), F.make_param("other", "String", "{}", "Other", "Dictionary to merge in (overwrites).", "expression")], "Variables: Dictionary", "Merge {other} into {var_name}")
		.described("Copies another dictionary's keys into this one, overwriting any clashes."))
	descriptors.append(F.make_descriptor("Core", "DictHasKey", "Has Key", ACEDescriptor.ACEType.CONDITION, "{var_name}.has({key})", "", [F.make_param("var_name", "String", "dict", "Dictionary", "Dictionary variable.", "variable_reference:Dictionary"), F.make_param("key", "String", "\"key\"", "Key", "Key to test.", "expression")], "Variables: Dictionary", "{var_name} has key {key}")
		.described("True when the dictionary contains the given key."))
	descriptors.append(F.make_descriptor("Core", "DictHasAllKeys", "Has All Keys", ACEDescriptor.ACEType.CONDITION, "{var_name}.has_all({keys})", "", [F.make_param("var_name", "String", "dict", "Dictionary", "Dictionary variable.", "variable_reference:Dictionary"), F.make_param("keys", "String", "[\"a\", \"b\"]", "Keys", "Array of keys that must all be present.", "expression")], "Variables: Dictionary", "{var_name} has all {keys}")
		.described("True when the dictionary contains every key in the given list."))
	descriptors.append(F.make_descriptor("Core", "DictIsEmpty", "Dictionary Is Empty", ACEDescriptor.ACEType.CONDITION, "{var_name}.is_empty()", "", [F.make_param("var_name", "String", "dict", "Dictionary", "Dictionary variable.", "variable_reference:Dictionary")], "Variables: Dictionary", "{var_name} is empty")
		.described("True when the dictionary has no keys at all."))
	descriptors.append(F.make_descriptor("Core", "DictGet", "Get Key (with default)", ACEDescriptor.ACEType.EXPRESSION, "{var_name}.get({key}, {default})", "", [F.make_param("var_name", "String", "dict", "Dictionary", "Dictionary variable.", "variable_reference:Dictionary"), F.make_param("key", "String", "\"key\"", "Key", "Key to read.", "expression"), F.make_param("default", "String", "0", "Default", "Fallback when the key is missing.", "expression")], "Variables: Dictionary", "{var_name}.get({key})")
		.described("Reads a key's value, returning your fallback when the key is missing."))
	descriptors.append(F.make_descriptor("Core", "DictSize", "Dictionary Size", ACEDescriptor.ACEType.EXPRESSION, "{var_name}.size()", "", [F.make_param("var_name", "String", "dict", "Dictionary", "Dictionary variable.", "variable_reference:Dictionary")], "Variables: Dictionary", "{var_name}.size()")
		.described("Gives how many keys the dictionary currently holds."))
	descriptors.append(F.make_descriptor("Core", "DictKeys", "Dictionary Keys", ACEDescriptor.ACEType.EXPRESSION, "{var_name}.keys()", "", [F.make_param("var_name", "String", "dict", "Dictionary", "Dictionary variable.", "variable_reference:Dictionary")], "Variables: Dictionary", "{var_name}.keys()")
		.described("Gives a list of all the dictionary's keys."))
	descriptors.append(F.make_descriptor("Core", "DictValues", "Dictionary Values", ACEDescriptor.ACEType.EXPRESSION, "{var_name}.values()", "", [F.make_param("var_name", "String", "dict", "Dictionary", "Dictionary variable.", "variable_reference:Dictionary")], "Variables: Dictionary", "{var_name}.values()")
		.described("Gives a list of all the dictionary's values."))
	# Array
	descriptors.append(F.make_descriptor("Core", "ArrayAppend", "Append", ACEDescriptor.ACEType.ACTION, "{var_name}.append({value})", "", [F.make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array"), F.make_param("value", "String", "0", "Value", "Value to append.", "expression")], "Variables: Array", "Append {value} to {var_name}")
		.described("Adds a value to the end of an array variable."))
	descriptors.append(F.make_descriptor("Core", "ArrayInsert", "Insert At", ACEDescriptor.ACEType.ACTION, "{var_name}.insert({index}, {value})", "", [F.make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array"), F.make_param("index", "String", "0", "Index", "Insertion index.", "expression"), F.make_param("value", "String", "0", "Value", "Value to insert.", "expression")], "Variables: Array", "Insert {value} at {index} in {var_name}")
		.described("Inserts a value into an array at a specific position."))
	descriptors.append(F.make_descriptor("Core", "ArrayRemoveAt", "Remove At", ACEDescriptor.ACEType.ACTION, "{var_name}.remove_at({index})", "", [F.make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array"), F.make_param("index", "String", "0", "Index", "Index to remove.", "expression")], "Variables: Array", "Remove index {index} from {var_name}")
		.described("Removes the item at a specific position in an array."))
	descriptors.append(F.make_descriptor("Core", "ArrayErase", "Erase Value", ACEDescriptor.ACEType.ACTION, "{var_name}.erase({value})", "", [F.make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array"), F.make_param("value", "String", "0", "Value", "First matching value to remove.", "expression")], "Variables: Array", "Erase {value} from {var_name}")
		.described("Removes the first item in the array that matches a given value."))
	descriptors.append(F.make_descriptor("Core", "ArrayClear", "Clear Array", ACEDescriptor.ACEType.ACTION, "{var_name}.clear()", "", [F.make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array")], "Variables: Array", "Clear {var_name}")
		.described("Empties an array, removing every item."))
	descriptors.append(F.make_descriptor("Core", "ArraySort", "Sort Array", ACEDescriptor.ACEType.ACTION, "{var_name}.sort()", "", [F.make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array")], "Variables: Array", "Sort {var_name}")
		.described("Sorts an array's items into ascending order."))
	descriptors.append(F.make_descriptor("Core", "ArrayShuffle", "Shuffle Array", ACEDescriptor.ACEType.ACTION, "{var_name}.shuffle()", "", [F.make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array")], "Variables: Array", "Shuffle {var_name}")
		.described("Randomly reorders the items in an array."))
	descriptors.append(F.make_descriptor("Core", "ArrayContains", "Contains", ACEDescriptor.ACEType.CONDITION, "{var_name}.has({value})", "", [F.make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array"), F.make_param("value", "String", "0", "Value", "Value to look for.", "expression")], "Variables: Array", "{var_name} contains {value}")
		.described("True when the array holds the given value somewhere."))
	descriptors.append(F.make_descriptor("Core", "ArrayIsEmpty", "Array Is Empty", ACEDescriptor.ACEType.CONDITION, "{var_name}.is_empty()", "", [F.make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array")], "Variables: Array", "{var_name} is empty")
		.described("True when the array has no items at all."))
	descriptors.append(F.make_descriptor("Core", "ArrayAt", "Value At", ACEDescriptor.ACEType.EXPRESSION, "{var_name}[{index}]", "", [F.make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array"), F.make_param("index", "String", "0", "Index", "Index to read.", "expression")], "Variables: Array", "{var_name}[{index}]")
		.described("Gives the item stored at a specific position in the array."))
	descriptors.append(F.make_descriptor("Core", "ArraySize", "Array Size", ACEDescriptor.ACEType.EXPRESSION, "{var_name}.size()", "", [F.make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array")], "Variables: Array", "{var_name}.size()")
		.described("Gives how many items the array currently holds."))
	descriptors.append(F.make_descriptor("Core", "ArrayPickRandom", "Pick Random", ACEDescriptor.ACEType.EXPRESSION, "{var_name}.pick_random()", "", [F.make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array")], "Variables: Array", "random of {var_name}")
		.described("Gives one random item picked from the array."))
	# JSON moved to its own module (json_aces.gd / EventForgeJsonACEs) so it is its own thing.

	# Time (System: Wait - handlers are implicit coroutines, await is safe anywhere)
	descriptors.append(F.make_descriptor("Core", "Wait", "Wait", ACEDescriptor.ACEType.ACTION, "await get_tree().create_timer({seconds}).timeout", "", [F.make_param("seconds", "String", "1.0", "Seconds", "How long to wait before the next action runs.", "expression")], "Time", "Wait {seconds} s")
		.described("Pauses this event for a number of seconds before continuing."))
	descriptors.append(F.make_descriptor("Core", "AwaitSignal", "Wait For Signal", ACEDescriptor.ACEType.ACTION, "await {signal_expression}", "", [F.make_param("signal_expression", "String", "get_tree().process_frame", "Signal", "Signal to wait for (e.g. $Timer.timeout).", "expression")], "Time", "Wait for {signal_expression}")
		.described("Pauses this event until a chosen signal fires, like a timer finishing."))
	# Frame budgeting (ADVANCED - frame-spreading): hand-roll loop spreading.
	# The handler becomes an implicit coroutine, so use these ONLY inside a one-shot trigger
	# (On Ready / On Signal / a custom function) with a run-once guard - NEVER inside a re-firing On
	# Process, where overlapping suspended runs would duplicate work. For the easy path use the Time Slicer pack.
	descriptors.append(F.make_descriptor("Core", "AwaitNextFrame", "Await Next Frame", ACEDescriptor.ACEType.ACTION, "await get_tree().process_frame", "", [], "Performance", "await next frame")
		.described("Pauses this event until the next game frame, to spread work out."))
	descriptors.append(F.make_descriptor("Core", "BeginFrameBudget", "Begin Frame Budget", ACEDescriptor.ACEType.ACTION, "var __ace_budget_end := Time.get_ticks_usec() + int({ms} * 1000.0)", "", [F.make_param("ms", "String", "8.0", "Budget (ms)", "Per-frame millisecond budget for the loop that follows (pair with Await If Over Budget in the SAME handler).", "expression")], "Performance", "begin {ms}ms frame budget")
		.described("Starts a per-frame time budget for the loop that follows, to avoid stutter."))
	descriptors.append(F.make_descriptor("Core", "AwaitIfOverBudget", "Await If Over Budget", ACEDescriptor.ACEType.ACTION, "if Time.get_ticks_usec() >= __ace_budget_end:\n\t__ace_budget_end = Time.get_ticks_usec() + int({ms} * 1000.0)\n\tawait get_tree().process_frame", "", [F.make_param("ms", "String", "8.0", "Budget (ms)", "Re-arm budget after yielding (match Begin Frame Budget). Drop at the bottom of a loop body to self-pace it.", "expression")], "Performance", "await if over {ms}ms budget")
		.described("Yields to the next frame only if this frame's time budget is used up."))
	descriptors.append(F.make_descriptor("Core", "CallAfterDelay", "Call After Delay", ACEDescriptor.ACEType.ACTION, "get_tree().create_timer({seconds}).timeout.connect({callable})", "", [F.make_param("seconds", "String", "1.0", "Seconds", "Delay before the call fires (does not suspend this event).", "expression"), F.make_param("callable", "String", "queue_free", "Callable", "Method/Callable to invoke after the delay (e.g. queue_free, _on_done).", "expression")], "Time", "Call {callable} after {seconds}s")
		.described("Schedules a method to run later without pausing this event."))
	# Repeat With Delay: the drip-feed loop. Written by hand this is a for loop with an await inside,
	# which is exactly the shape beginners get wrong; as one row it stays honest about suspending -
	# the handler becomes a coroutine for the whole burst, same contract as Wait.
	descriptors.append(F.make_descriptor("Core", "RepeatWithDelay", "Repeat With Delay", ACEDescriptor.ACEType.ACTION, "for __rep_{uid}: int in maxi({times}, 0):\n\t{do}\n\tawait get_tree().create_timer(maxf({delay}, 0.001)).timeout", "", [F.make_param("times", "String", "5", "Times", "How many repeats to run.", "expression"), F.make_param("delay", "String", "0.1", "Seconds Apart", "Pause between repeats.", "expression"), F.make_param("do", "String", "print(\"beat\")", "Do", "One call or statement, run each repeat.", "expression")], "Time", "{times} times, {delay}s apart: {do}")
		.described("Runs one statement several times with a pause between each - burst fire, drip-spawns, a ticking countdown. It suspends this event the same way Wait does, so pair it with Once At A Time (Single Flight) when the trigger can fire again mid-burst."))
	# Input expressions
	descriptors.append(F.make_descriptor("Core", "GetActionStrength", "Action Strength", ACEDescriptor.ACEType.EXPRESSION, "Input.get_action_strength(&{action})", "", [F.make_param("action", "String", F.default_input_action(), "Action", "Input action (analog strength 0..1).", "input_action", F.input_action_options())], "Input", "strength of {action}")
		.described("Gives how hard an input action is pressed, from 0 to 1."))
	descriptors.append(F.make_descriptor("Core", "GetInputAxis", "Input Axis", ACEDescriptor.ACEType.EXPRESSION, "Input.get_axis(&{negative}, &{positive})", "", [F.make_param("negative", "String", "\"ui_left\"", "Negative", "Action for the negative direction.", "input_action", F.input_action_options()), F.make_param("positive", "String", "\"ui_right\"", "Positive", "Action for the positive direction.", "input_action", F.input_action_options())], "Input", "axis {negative}/{positive}")
		.described("Gives a -1 to 1 value from two opposing input actions, like left and right."))
	# The consuming ACTION for the axis above: read input into a typed float local in one row, so
	# "read input, then move" is two ACE rows instead of a RawCode block (closes the input gap).
	descriptors.append(F.make_descriptor("Core", "SetLocalFromAxis", "Read Input Axis Into", ACEDescriptor.ACEType.ACTION, "var {name}: float = Input.get_axis(&{negative}, &{positive})", "", [F.make_param("name", "String", "direction", "Name", "Local variable name (scoped to this event body)."), F.make_param("negative", "String", "\"ui_left\"", "Negative", "Action for the negative direction.", "input_action", F.input_action_options()), F.make_param("positive", "String", "\"ui_right\"", "Positive", "Action for the positive direction.", "input_action", F.input_action_options())], "Input", "read axis {negative}/{positive} into {name}")
		.described("Reads a left/right input axis into a local variable for this event."))
	# ── Native-node providers (coverage Lane 1: wrap NATIVE Godot features; the
	# engine maintains the implementation, we only maintain vocabulary). The familiar
	# names are the display names; see the migration guide for the lane mapping.
	# Tween (Tween behavior -> Godot's built-in create_tween)
	descriptors.append(F.make_descriptor("Core", "TweenProperty", "Tween Property", ACEDescriptor.ACEType.ACTION, "create_tween().tween_property({target}, {property}, {value}, {duration}).set_trans({transition}).set_ease({ease})", "", [F.make_param("target", "String", "self", "Target", "Node whose property tweens.", "expression"), F.make_param("property", "String", "\"position\"", "Property", "Property path to animate."), F.make_param("value", "String", "Vector2(100, 0)", "To", "Final value expression.", "expression"), F.make_param("duration", "String", "0.5", "Duration", "Seconds.", "expression"), F.make_param("transition", "String", "Tween.TRANS_SINE", "Transition", "Curve shape.", "", ["Tween.TRANS_LINEAR", "Tween.TRANS_SINE", "Tween.TRANS_QUAD", "Tween.TRANS_CUBIC", "Tween.TRANS_QUART", "Tween.TRANS_ELASTIC", "Tween.TRANS_BACK", "Tween.TRANS_BOUNCE", "Tween.TRANS_EXPO", "Tween.TRANS_CIRC"]), F.make_param("ease", "String", "Tween.EASE_IN_OUT", "Ease", "In / out / in-out.", "", ["Tween.EASE_IN", "Tween.EASE_OUT", "Tween.EASE_IN_OUT"])], "Tween", "Tween {property} to {value} over {duration}s")
		.described("Smoothly animates a node's property to a target value over time with an easing curve."))
	descriptors.append(F.make_descriptor("Core", "TweenCallback", "Tween Callback", ACEDescriptor.ACEType.ACTION, "create_tween().tween_callback({callable}).set_delay({delay})", "", [F.make_param("callable", "String", "queue_free", "Callable", "Method/Callable to invoke after the delay (e.g. a node method or a lambda).", "expression"), F.make_param("delay", "String", "1.0", "Delay", "Seconds before the call fires.", "expression")], "Tween", "Call {callable} after {delay}s")
		.described("Waits a delay, then calls a method or function once (handy for timed events)."))
	# Scene flow (System: layouts -> Godot scenes)
	descriptors.append(F.make_descriptor("Core", "ChangeScene", "Go To Scene", ACEDescriptor.ACEType.ACTION, "get_tree().change_scene_to_file({path})", "", [F.make_param("path", "String", "\"res://main.tscn\"", "Scene", "Scene file to switch to.", "expression")], "Scene", "Go to scene {path}")
		.described("Switches the game to a different scene file, replacing the current one."))
	descriptors.append(F.make_descriptor("Core", "ReloadScene", "Restart Scene", ACEDescriptor.ACEType.ACTION, "get_tree().reload_current_scene()", "", [], "Scene", "Restart the current scene")
		.described("Restarts the current scene from scratch, useful for retrying a level."))
	descriptors.append(F.make_descriptor("Core", "QuitGame", "Quit Game", ACEDescriptor.ACEType.ACTION, "get_tree().quit()", "", [], "Scene", "Quit the game")
		.described("Closes the game and exits to desktop."))
	# Pairs with the On Close Requested trigger: by default the window's X quits instantly, so set this in
	# On Ready to "Intercept" and the close waits for your On Close Requested handler (save / confirm), which
	# then calls Quit Game explicitly. The friendly dropdown shows "Intercept"/"Allow" but inserts false/true.
	descriptors.append(F.make_descriptor("Core", "HandleQuitRequest", "Handle Quit Myself", ACEDescriptor.ACEType.ACTION, "get_tree().set_auto_accept_quit({mode})", "", [F.make_param("mode", "String", "false", "On close", "Whether the app quits instantly or waits for you to handle it.", "", [{"key": "false", "label": "Intercept (handle it myself)"}, {"key": "true", "label": "Allow (quit immediately)"}])], "Scene", "Handle quit myself: {mode}")
		.described("Stops the window's close button from quitting instantly, so On Close Requested can run first (save progress, pop a confirm dialog) and you quit explicitly with Quit Game. Choose \"Allow\" to restore Godot's default immediate quit."))
	descriptors.append(F.make_descriptor("Core", "SetPaused", "Set Game Paused", ACEDescriptor.ACEType.ACTION, "get_tree().paused = {paused}", "", [F.make_param("paused", "String", "true", "Paused", "Pause state.", "", ["true", "false"])], "Scene", "Set paused to {paused}")
		.described("Pauses or resumes the whole game by toggling the scene tree's pause state."))
	descriptors.append(F.make_descriptor("Core", "SpawnScene", "Spawn Scene Instance", ACEDescriptor.ACEType.ACTION, "add_child(load({path}).instantiate())", "", [F.make_param("path", "String", "\"res://enemy.tscn\"", "Scene", "Scene file to instance as a child.", "expression")], "Scene", "Spawn {path}")
		.described("Loads a scene file and adds an instance of it as a child (spawning objects)."))
	descriptors.append(F.make_descriptor("Core", "IsPaused", "Is Game Paused", ACEDescriptor.ACEType.CONDITION, "get_tree().paused", "", [], "Scene", "Game is paused")
		.described("True when the game is currently paused."))
	# Audio (AudioStreamPlayer / 2D / 3D share these members)
	descriptors.append(F.make_descriptor("Core", "PlayAudio", "Play Sound", ACEDescriptor.ACEType.ACTION, "play({from_position})", "", [F.make_param("from_position", "String", "0.0", "From", "Start position in seconds.", "expression")], "General Actions", "Play sound", "AudioStreamPlayer")
		.described("Plays the sound on an audio player, optionally starting from a given second."))
	descriptors.append(F.make_descriptor("Core", "StopAudio", "Stop Sound", ACEDescriptor.ACEType.ACTION, "stop()", "", [], "General Actions", "Stop sound", "AudioStreamPlayer")
		.described("Stops the sound currently playing on an audio player."))
	descriptors.append(F.make_descriptor("Core", "SetVolumeDb", "Set Volume (dB)", ACEDescriptor.ACEType.ACTION, "volume_db = {db}", "", [F.make_param("db", "String", "0.0", "Decibels", "0 = full volume, -80 = silent.", "expression")], "General Actions", "Set volume to {db} dB", "AudioStreamPlayer")
		.described("Sets an audio player's loudness in decibels (0 is full, -80 is silent)."))
	descriptors.append(F.make_descriptor("Core", "IsAudioPlaying", "Is Playing", ACEDescriptor.ACEType.CONDITION, "playing", "", [], "General Conditions", "Sound is playing", "AudioStreamPlayer")
		.described("True while the audio player is currently playing a sound."))
	descriptors.append(F.make_descriptor("Core", "GetPlaybackPosition", "Playback Position", ACEDescriptor.ACEType.EXPRESSION, "get_playback_position()", "", [], "General Expressions", "playback position", "AudioStreamPlayer")
		.described("Returns how many seconds into the sound the audio player currently is."))
	# AnimatedSprite2D (Sprite animations)
	descriptors.append(F.make_descriptor("Core", "PlaySpriteAnimation", "Play Sprite Animation", ACEDescriptor.ACEType.ACTION, "play(&{anim})", "", [F.make_param("anim", "String", "\"default\"", "Animation", "Animation name.")], "General Actions", "Play animation {anim}", "AnimatedSprite2D")
		.described("Plays a named animation on an animated sprite (e.g. run or jump)."))
	descriptors.append(F.make_descriptor("Core", "StopSpriteAnimation", "Stop Sprite Animation", ACEDescriptor.ACEType.ACTION, "stop()", "", [], "General Actions", "Stop animation", "AnimatedSprite2D")
		.described("Stops the animated sprite's current animation on the spot."))
	descriptors.append(F.make_descriptor("Core", "SetSpriteFrame", "Set Frame", ACEDescriptor.ACEType.ACTION, "frame = {frame}", "", [F.make_param("frame", "String", "0", "Frame", "Frame index.", "expression")], "General Actions", "Set frame to {frame}", "AnimatedSprite2D")
		.described("Jumps the animated sprite to a specific frame number."))
	descriptors.append(F.make_descriptor("Core", "SetFlipH", "Set Mirrored", ACEDescriptor.ACEType.ACTION, "flip_h = {flipped}", "", [F.make_param("flipped", "String", "true", "Mirrored", "Horizontal flip.", "", ["true", "false"])], "General Actions", "Set mirrored {flipped}", "AnimatedSprite2D")
		.described("Mirrors the sprite horizontally, great for facing left or right."))
	descriptors.append(F.make_descriptor("Core", "IsSpriteAnimationPlaying", "Is Animation Playing", ACEDescriptor.ACEType.CONDITION, "is_playing()", "", [], "General Conditions", "Animation is playing", "AnimatedSprite2D")
		.described("True while the animated sprite is currently playing an animation."))
	descriptors.append(F.make_descriptor("Core", "GetSpriteAnimation", "Current Animation", ACEDescriptor.ACEType.EXPRESSION, "animation", "", [], "General Expressions", "current animation", "AnimatedSprite2D")
		.described("Returns the name of the animation the sprite is currently using."))
	# Camera2D
	descriptors.append(F.make_descriptor("Core", "MakeCameraCurrent", "Make Camera Current", ACEDescriptor.ACEType.ACTION, "make_current()", "", [], "General Actions", "Make this camera current", "Camera2D")
		.described("Makes this camera the active one the player views the game through."))
	descriptors.append(F.make_descriptor("Core", "SetCameraZoom", "Set Camera Zoom", ACEDescriptor.ACEType.ACTION, "zoom = {zoom}", "", [F.make_param("zoom", "String", "Vector2(1, 1)", "Zoom", "Zoom factor.", "expression")], "General Actions", "Set zoom to {zoom}", "Camera2D")
		.described("Sets how zoomed in or out the camera is."))
	descriptors.append(F.make_descriptor("Core", "SetCameraOffset", "Set Camera Offset", ACEDescriptor.ACEType.ACTION, "offset = {offset}", "", [F.make_param("offset", "String", "Vector2(0, 0)", "Offset", "Offset from the followed position.", "expression")], "General Actions", "Set offset to {offset}", "Camera2D")
		.described("Shifts the camera view away from the position it follows."))
	descriptors.append(F.make_descriptor("Core", "SetCameraLimits", "Set Camera Limits", ACEDescriptor.ACEType.ACTION, "limit_left = {left}\nlimit_top = {top}\nlimit_right = {right}\nlimit_bottom = {bottom}", "", [F.make_param("left", "String", "0", "Left", "Left bound (px).", "expression"), F.make_param("top", "String", "0", "Top", "Top bound (px).", "expression"), F.make_param("right", "String", "1920", "Right", "Right bound (px).", "expression"), F.make_param("bottom", "String", "1080", "Bottom", "Bottom bound (px).", "expression")], "General Actions", "Set camera limits", "Camera2D")
		.described("Sets the boundaries the camera won't scroll past, keeping it inside the level."))
	# Label / text (Text object)
	descriptors.append(F.make_descriptor("Core", "SetLabelText", "Set Text", ACEDescriptor.ACEType.ACTION, "text = str({value})", "", [F.make_param("value", "String", "\"Hello\"", "Text", "Value to display (str()-converted).", "expression")], "General Actions", "Set text to {value}", "Label")
		.described("Sets the text shown on a label, like a score or message."))
	descriptors.append(F.make_descriptor("Core", "AppendLabelText", "Append Text", ACEDescriptor.ACEType.ACTION, "text += str({value})", "", [F.make_param("value", "String", "\"!\"", "Text", "Value to append.", "expression")], "General Actions", "Append {value}", "Label")
		.described("Adds more text onto the end of a label's existing text."))
	descriptors.append(F.make_descriptor("Core", "GetLabelText", "Get Text", ACEDescriptor.ACEType.EXPRESSION, "text", "", [], "General Expressions", "text", "Label")
		.described("Returns the text currently displayed on the label."))
	# NavigationAgent2D (Pathfinding behavior)
	descriptors.append(F.make_descriptor("Core", "SetNavTarget", "Find Path To", ACEDescriptor.ACEType.ACTION, "target_position = {position}", "", [F.make_param("position", "String", "Vector2(0, 0)", "Target", "World position to path toward.", "expression")], "General Actions", "Find path to {position}", "NavigationAgent2D")
		.described("Tells a navigation agent to pathfind toward a world position, for AI movement."))
	descriptors.append(F.make_descriptor("Core", "IsNavFinished", "Has Arrived", ACEDescriptor.ACEType.CONDITION, "is_navigation_finished()", "", [], "General Conditions", "Arrived at destination", "NavigationAgent2D")
		.described("True once the navigation agent has reached its target destination."))
	descriptors.append(F.make_descriptor("Core", "GetNextPathPosition", "Next Path Position", ACEDescriptor.ACEType.EXPRESSION, "get_next_path_position()", "", [], "General Expressions", "next path position", "NavigationAgent2D")
		.described("Returns the next point along the path the agent should move toward."))
	descriptors.append(F.make_descriptor("Core", "GetNavDistance", "Distance To Target", ACEDescriptor.ACEType.EXPRESSION, "distance_to_target()", "", [], "General Expressions", "distance to target", "NavigationAgent2D")
		.described("Returns how far the agent still is from its navigation target."))
	# Visibility / tint (CanvasItem)
	descriptors.append(F.make_descriptor("Core", "ShowNode", "Show", ACEDescriptor.ACEType.ACTION, "show()", "", [], "General Actions", "Show", "CanvasItem")
		.described("Makes a node visible on screen."))
	descriptors.append(F.make_descriptor("Core", "HideNode", "Hide", ACEDescriptor.ACEType.ACTION, "hide()", "", [], "General Actions", "Hide", "CanvasItem")
		.described("Hides a node so it no longer shows on screen."))
	descriptors.append(F.make_descriptor("Core", "SetModulate", "Set Color Tint", ACEDescriptor.ACEType.ACTION, "modulate = {color}", "", [F.make_param("color", "String", "Color(1, 1, 1, 1)", "Color", "Tint (RGBA).", "color")], "General Actions", "Set tint to {color}", "CanvasItem")
		.described("Tints a node and its children with a color, also useful for fading via alpha."))
	descriptors.append(F.make_descriptor("Core", "SetSelfModulate", "Set Self Tint", ACEDescriptor.ACEType.ACTION, "self_modulate = {color}", "", [F.make_param("color", "String", "Color(1, 1, 1, 1)", "Color", "Tint for this node only (not children).", "color")], "General Actions", "Set self tint to {color}", "CanvasItem")
		.described("Tints just this node with a color without affecting its children."))
	descriptors.append(F.make_descriptor("Core", "IsVisible", "Is Visible", ACEDescriptor.ACEType.CONDITION, "visible", "", [], "General Conditions", "Is visible", "CanvasItem")
		.described("True when the node is currently visible on screen."))
	# Math & random (System expressions: random, choose, clamp, lerp, distance, angle)
	descriptors.append(F.make_descriptor("Core", "RandomRange", "Random", ACEDescriptor.ACEType.EXPRESSION, "randf_range({from}, {to})", "", [F.make_param("from", "String", "0.0", "From", "Lower bound.", "expression"), F.make_param("to", "String", "1.0", "To", "Upper bound.", "expression")], "Math & Random", "random({from}, {to})")
		.described("Returns a random decimal number between the two bounds you give."))
	descriptors.append(F.make_descriptor("Core", "RandomInt", "Random Integer", ACEDescriptor.ACEType.EXPRESSION, "randi_range({from}, {to})", "", [F.make_param("from", "String", "0", "From", "Lower bound (inclusive).", "expression"), F.make_param("to", "String", "9", "To", "Upper bound (inclusive).", "expression")], "Math & Random", "random int({from}, {to})")
		.described("Returns a random whole number between the two bounds, both included."))
	descriptors.append(F.make_descriptor("Core", "Choose", "Choose", ACEDescriptor.ACEType.EXPRESSION, "[{values}].pick_random()", "", [F.make_param("values", "String", "1, 2, 3", "Values", "Comma-separated values to pick from.", "expression")], "Math & Random", "choose({values})")
		.described("Randomly picks one value from a comma-separated list you provide."))
	descriptors.append(F.make_descriptor("Core", "ClampValue", "Clamp", ACEDescriptor.ACEType.EXPRESSION, "clampf({value}, {min}, {max})", "", [F.make_param("value", "String", "0.0", "Value", "Value to clamp.", "expression"), F.make_param("min", "String", "0.0", "Min", "Lower bound.", "expression"), F.make_param("max", "String", "1.0", "Max", "Upper bound.", "expression")], "Math & Random", "clamp({value}, {min}, {max})")
		.described("Keeps a value within a min and max, clipping anything outside the range."))
	descriptors.append(F.make_descriptor("Core", "LerpValue", "Lerp", ACEDescriptor.ACEType.EXPRESSION, "lerpf({from}, {to}, {weight})", "", [F.make_param("from", "String", "0.0", "From", "Start value.", "expression"), F.make_param("to", "String", "1.0", "To", "End value.", "expression"), F.make_param("weight", "String", "0.5", "Weight", "0..1 blend.", "expression")], "Math & Random", "lerp({from}, {to}, {weight})")
		.described("Blends between two values by a 0-to-1 weight, for smooth interpolation."))
	descriptors.append(F.make_descriptor("Core", "DistanceTo", "Distance To", ACEDescriptor.ACEType.EXPRESSION, "position.distance_to({to})", "", [F.make_param("to", "String", "Vector2(0, 0)", "To", "Target position.", "expression")], "Math & Random", "distance to {to}", "Node2D")
		.described("Returns the distance in pixels from this node to a target position."))
	descriptors.append(F.make_descriptor("Core", "AngleToPoint", "Angle Toward", ACEDescriptor.ACEType.EXPRESSION, "position.angle_to_point({to})", "", [F.make_param("to", "String", "Vector2(0, 0)", "To", "Target position.", "expression")], "Math & Random", "angle toward {to}", "Node2D")
		.described("Returns the angle from this node toward a target position, handy for aiming."))
	# More math idioms (movement / animation / AI reach for these constantly).
	descriptors.append(F.make_descriptor("Core", "Snapped", "Snap To Step", ACEDescriptor.ACEType.EXPRESSION, "snappedf({value}, {step})", "", [F.make_param("value", "String", "0.0", "Value", "Value to snap.", "expression"), F.make_param("step", "String", "1.0", "Step", "Snap increment (e.g. grid size).", "expression")], "Math & Random", "snap {value} to {step}")
		.described("Rounds a value to the nearest step, useful for snapping to a grid."))
	descriptors.append(F.make_descriptor("Core", "InverseLerp", "Inverse Lerp", ACEDescriptor.ACEType.EXPRESSION, "inverse_lerp({from}, {to}, {value})", "", [F.make_param("from", "String", "0.0", "From", "Range start.", "expression"), F.make_param("to", "String", "1.0", "To", "Range end.", "expression"), F.make_param("value", "String", "0.5", "Value", "Value in the range.", "expression")], "Math & Random", "inverse lerp {value}")
		.described("Returns where a value sits within a range as a 0-to-1 fraction."))
	descriptors.append(F.make_descriptor("Core", "Smoothstep", "Smoothstep", ACEDescriptor.ACEType.EXPRESSION, "smoothstep({from}, {to}, {value})", "", [F.make_param("from", "String", "0.0", "From", "Edge 0.", "expression"), F.make_param("to", "String", "1.0", "To", "Edge 1.", "expression"), F.make_param("value", "String", "0.5", "Value", "Value to ease.", "expression")], "Math & Random", "smoothstep({from}, {to}, {value})")
		.described("Eases a value between two edges with a smooth S-curve instead of a straight line."))
	descriptors.append(F.make_descriptor("Core", "SmoothLerp", "Smooth Lerp", ACEDescriptor.ACEType.EXPRESSION, "lerpf({from}, {to}, smoothstep(0.0, 1.0, {weight}))", "", [F.make_param("from", "String", "0.0", "From", "Start value.", "expression"), F.make_param("to", "String", "1.0", "To", "End value.", "expression"), F.make_param("weight", "String", "0.5", "Weight", "0..1 progress (eased with an S-curve before blending).", "expression")], "Math & Random", "smooth lerp {from} -> {to}")
		.described("Blends between two values like Lerp, but eases the 0-to-1 weight with a smooth S-curve first, so the motion starts and ends gently instead of at a constant speed."))
	descriptors.append(F.make_descriptor("Core", "Atan2", "Angle Of (atan2)", ACEDescriptor.ACEType.EXPRESSION, "atan2({y}, {x})", "", [F.make_param("y", "String", "0.0", "Y", "Vertical component.", "expression"), F.make_param("x", "String", "0.0", "X", "Horizontal component.", "expression")], "Math & Random", "atan2({y}, {x})")
		.described("Returns the angle (radians) of the direction (x, y), correct in all four quadrants - the standard way to turn a velocity or offset into a heading."))
	descriptors.append(F.make_descriptor("Core", "PingPong", "Ping-Pong", ACEDescriptor.ACEType.EXPRESSION, "pingpong({value}, {length})", "", [F.make_param("value", "String", "0.0", "Value", "Input value (often a timer).", "expression"), F.make_param("length", "String", "1.0", "Length", "Bounce length.", "expression")], "Math & Random", "pingpong({value}, {length})")
		.described("Bounces a value back and forth between 0 and a length, great for looping motion."))
	descriptors.append(F.make_descriptor("Core", "AngleDifference", "Angle Difference", ACEDescriptor.ACEType.EXPRESSION, "angle_difference({from}, {to})", "", [F.make_param("from", "String", "0.0", "From", "From angle (radians).", "expression"), F.make_param("to", "String", "0.0", "To", "To angle (radians).", "expression")], "Math & Random", "angle diff {from} -> {to}")
		.described("Returns the shortest signed turn from one angle to another, in radians."))
	descriptors.append(F.make_descriptor("Core", "RotateTowardAngle", "Rotate Toward (angle)", ACEDescriptor.ACEType.EXPRESSION, "rotate_toward({from}, {to}, {delta})", "", [F.make_param("from", "String", "0.0", "From", "Current angle (radians).", "expression"), F.make_param("to", "String", "0.0", "To", "Target angle (radians).", "expression"), F.make_param("delta", "String", "0.1", "Delta", "Max step (radians).", "expression")], "Math & Random", "rotate {from} toward {to}")
		.described("Steps an angle toward a target by a limited amount, for smooth turning."))
	descriptors.append(F.make_descriptor("Core", "LerpAngle", "Lerp Angle", ACEDescriptor.ACEType.EXPRESSION, "lerp_angle({from}, {to}, {weight})", "", [F.make_param("from", "String", "0.0", "From", "From angle (radians).", "expression"), F.make_param("to", "String", "0.0", "To", "To angle (radians).", "expression"), F.make_param("weight", "String", "0.5", "Weight", "0..1 blend.", "expression")], "Math & Random", "lerp angle {from} -> {to}")
		.described("Blends between two angles by a 0..1 weight, taking the shortest path."))
	descriptors.append(F.make_descriptor("Core", "DegToRad", "Degrees To Radians", ACEDescriptor.ACEType.EXPRESSION, "deg_to_rad({degrees})", "", [F.make_param("degrees", "String", "90.0", "Degrees", "Angle in degrees.", "expression")], "Math & Random", "deg2rad({degrees})")
		.described("Converts an angle from degrees into radians, which Godot uses internally."))
	descriptors.append(F.make_descriptor("Core", "RadToDeg", "Radians To Degrees", ACEDescriptor.ACEType.EXPRESSION, "rad_to_deg({radians})", "", [F.make_param("radians", "String", "0.0", "Radians", "Angle in radians.", "expression")], "Math & Random", "rad2deg({radians})")
		.described("Converts an angle from radians back into easy-to-read degrees."))
	descriptors.append(F.make_descriptor("Core", "PosMod", "Positive Modulo", ACEDescriptor.ACEType.EXPRESSION, "posmod({a}, {b})", "", [F.make_param("a", "String", "0", "A", "Dividend (int).", "expression"), F.make_param("b", "String", "1", "B", "Divisor (int).", "expression")], "Math & Random", "posmod({a}, {b})")
		.described("Returns a modulo result that stays positive, handy for wrapping indexes."))
	descriptors.append(F.make_descriptor("Core", "IsEqualApprox", "Is Equal (approx)", ACEDescriptor.ACEType.CONDITION, "is_equal_approx({a}, {b})", "", [F.make_param("a", "String", "0.0", "A", "First value.", "expression"), F.make_param("b", "String", "0.0", "B", "Second value.", "expression")], "Math & Random", "{a} ≈ {b}")
		.described("True when two numbers are nearly equal, avoiding tiny floating-point errors."))
	descriptors.append(F.make_descriptor("Core", "IsZeroApprox", "Is Zero (approx)", ACEDescriptor.ACEType.CONDITION, "is_zero_approx({value})", "", [F.make_param("value", "String", "0.0", "Value", "Value to test.", "expression")], "Math & Random", "{value} ≈ 0")
		.described("True when a value is essentially zero, ignoring tiny rounding differences."))
	descriptors.append(F.make_descriptor("Core", "SeedRandom", "Seed Random", ACEDescriptor.ACEType.ACTION, "seed({value})", "", [F.make_param("value", "String", "0", "Seed", "Integer seed (same seed = same sequence).", "expression")], "Math & Random", "seed RNG with {value}")
		.described("Sets the random seed so the same number gives a repeatable random sequence."))
	descriptors.append(F.make_descriptor("Core", "RandomizeSeed", "Randomize Seed", ACEDescriptor.ACEType.ACTION, "randomize()", "", [], "Math & Random", "randomize seed")
		.described("Reseeds randomness from the clock so each playthrough differs."))

	# Color math - hit flashes, fades, and tints without dropping to GDScript. The colour params
	# are full expressions (a literal, `modulate`, or another colour ACE), so they compose.
	descriptors.append(F.make_descriptor("Core", "ColorLighten", "Lighten Color", ACEDescriptor.ACEType.EXPRESSION, "({color}).lightened({amount})", "", [F.make_param("color", "String", "Color(1, 1, 1, 1)", "Color", "Base colour.", "color"), F.make_param("amount", "String", "0.2", "Amount", "0..1 toward white.", "expression")], "Color", "lighten {color} by {amount}")
		.described("Returns the colour shifted toward white by the given amount."))
	descriptors.append(F.make_descriptor("Core", "ColorDarken", "Darken Color", ACEDescriptor.ACEType.EXPRESSION, "({color}).darkened({amount})", "", [F.make_param("color", "String", "Color(1, 1, 1, 1)", "Color", "Base colour.", "color"), F.make_param("amount", "String", "0.2", "Amount", "0..1 toward black.", "expression")], "Color", "darken {color} by {amount}")
		.described("Returns the colour shifted toward black by the given amount."))
	descriptors.append(F.make_descriptor("Core", "ColorLerp", "Lerp Color", ACEDescriptor.ACEType.EXPRESSION, "({from}).lerp({to}, {weight})", "", [F.make_param("from", "String", "Color(1, 1, 1, 1)", "From", "Start colour.", "color"), F.make_param("to", "String", "Color(1, 0, 0, 1)", "To", "End colour.", "color"), F.make_param("weight", "String", "0.5", "Weight", "0..1 blend.", "expression")], "Color", "lerp {from} -> {to}")
		.described("Blends two colours by a 0..1 weight for smooth colour fades."))
	descriptors.append(F.make_descriptor("Core", "ColorWithAlpha", "Color With Alpha", ACEDescriptor.ACEType.EXPRESSION, "Color({color}, {alpha})", "", [F.make_param("color", "String", "Color(1, 1, 1, 1)", "Color", "Base colour.", "color"), F.make_param("alpha", "String", "0.5", "Alpha", "New alpha 0..1.", "expression")], "Color", "{color} @ alpha {alpha}")
		.described("Returns the colour with a new transparency, for fade-in or fade-out effects."))
	descriptors.append(F.make_descriptor("Core", "ColorFromHSV", "Color From HSV", ACEDescriptor.ACEType.EXPRESSION, "Color.from_hsv({h}, {s}, {v}, {a})", "", [F.make_param("h", "String", "0.0", "Hue", "0..1.", "expression"), F.make_param("s", "String", "1.0", "Saturation", "0..1.", "expression"), F.make_param("v", "String", "1.0", "Value", "0..1.", "expression"), F.make_param("a", "String", "1.0", "Alpha", "0..1.", "expression")], "Color", "hsv({h}, {s}, {v})")
		.described("Builds a colour from hue, saturation, value and alpha components."))
	descriptors.append(F.make_descriptor("Core", "ColorFromHex", "Color From Hex", ACEDescriptor.ACEType.EXPRESSION, "Color.html({hex})", "", [F.make_param("hex", "String", "\"#ff8800\"", "Hex", "HTML colour string.", "expression")], "Color", "color {hex}")
		.described("Builds a colour from an HTML hex string like #ff8800."))
	descriptors.append(F.make_descriptor("Core", "ColorInverted", "Invert Color", ACEDescriptor.ACEType.EXPRESSION, "({color}).inverted()", "", [F.make_param("color", "String", "Color(1, 1, 1, 1)", "Color", "Colour to invert.", "color")], "Color", "invert {color}")
		.described("Returns the opposite colour, useful for highlight or negative effects."))

	# ── Variable easing / flipping (the two beginner patterns that always come out wrong by hand) ──
	# Move Toward is the frame-rate INDEPENDENT damping form: the exponential decay means the same
	# Speed lands the same distance per SECOND no matter the frame rate, unlike the naive
	# `lerp(a, b, 0.1)` written straight into a per-frame event.
	descriptors.append(F.make_descriptor("Core", "SmoothMoveToward", "Move Toward (smooth)", ACEDescriptor.ACEType.ACTION, "{var_name} = lerp({var_name}, {target}, 1.0 - exp(-maxf({speed}, 0.0) * get_process_delta_time()))", "", [F.make_param("var_name", "String", "value", "Variable", "Variable to ease.", "variable_reference"), F.make_param("target", "String", "1.0", "Toward", "The value to approach.", "expression"), F.make_param("speed", "String", "8.0", "Speed", "How fast it closes the gap - higher is snappier, around 8 feels like a firm camera follow.", "expression")], "Variables", "Move {var_name} toward {target} at speed {speed}")
		.described("Eases a variable smoothly toward a target instead of snapping to it. Works on numbers, Vector2/Vector3 and Colors alike (lerp is generic). It is frame-rate independent - the exponential form behaves the same at 30 and 144 fps."))
	descriptors.append(F.make_descriptor("Core", "ToggleVar", "Toggle", ACEDescriptor.ACEType.ACTION, "{var_name} = not {var_name}", "", [F.make_param("var_name", "String", "enabled_flag", "Variable", "Boolean variable to flip.", "variable_reference")], "Variables", "Toggle {var_name}")
		.described("Flips a true/false variable to its opposite - on becomes off, off becomes on."))
	descriptors.append(F.make_descriptor("Core", "AsClockTime", "As Clock Time", ACEDescriptor.ACEType.EXPRESSION, "(\"%02d:%02d\" % [int(maxf({seconds}, 0.0)) / 60, int(maxf({seconds}, 0.0)) % 60])", "", [F.make_param("seconds", "String", "90.0", "Seconds", "A duration in seconds.", "expression")], "Text", "as clock time ({seconds})")
		.described("Turns a number of seconds into minutes:seconds text - 90 seconds reads \"01:30\". For countdown timers, lap times and speedrun clocks."))
	# Charge Toward: the hold-to-charge meter. Filling by "reach the maximum in N seconds" (rather than
	# "add X per frame") means the tuning number is the one the designer actually thinks in, and the
	# clamp is baked in so the meter can never overfill however long the button is held.
	descriptors.append(F.make_descriptor("Core", "ChargeToward", "Charge Toward", ACEDescriptor.ACEType.ACTION, "{var_name} = minf({var_name} + (maxf({maximum}, 0.0) / maxf({seconds}, 0.001)) * get_process_delta_time(), maxf({maximum}, 0.0))", "", [F.make_param("var_name", "String", "power", "Variable", "The meter to fill.", "variable_reference"), F.make_param("maximum", "String", "100.0", "Up To", "The full value the meter tops out at.", "expression"), F.make_param("seconds", "String", "1.5", "Over Seconds", "How long a full charge takes from empty.", "expression")], "Variables", "charge {var_name} to {maximum} over {seconds}s")
		.described("Fills a variable while the event runs, reaching the maximum after the given seconds - a hold-to-charge meter. Put it under a while-held input condition; it clamps itself at the top, and the release event just reads the value."))
	descriptors.append(F.make_descriptor("Core", "ProgressOf", "Progress Of", ACEDescriptor.ACEType.EXPRESSION, "clampf(inverse_lerp({from}, {to}, {value}), 0.0, 1.0)", "", [F.make_param("value", "String", "5.0", "Value", "The current value.", "expression"), F.make_param("from", "String", "0.0", "From", "The value that counts as empty.", "expression"), F.make_param("to", "String", "10.0", "To", "The value that counts as full.", "expression")], "Math & Random", "progress of {value} from {from} to {to}")
		.described("Gives how far a value has come through a range, as 0 to 1 - feed it straight into a bar's scale, an alpha, or a colour lerp. This is the inverse_lerp nobody finds, with the clamp already applied."))
	descriptors.append(F.make_descriptor("Core", "PercentOf", "Percent Of", ACEDescriptor.ACEType.EXPRESSION, "(clampf(inverse_lerp({from}, {to}, {value}), 0.0, 1.0) * 100.0)", "", [F.make_param("value", "String", "5.0", "Value", "The current value.", "expression"), F.make_param("from", "String", "0.0", "From", "The value that counts as empty.", "expression"), F.make_param("to", "String", "10.0", "To", "The value that counts as full.", "expression")], "Math & Random", "percent of {value} from {from} to {to}")
		.described("The same reading as Progress Of, but as 0 to 100 - the number you show in text, like \"73%\" health."))

	# ── Type-guarded fallbacks: turn "whatever this is" into something a typed variable can take ──
	# Everything LOADED rather than typed arrives as a value that might be the wrong shape, or missing
	# outright: a JSON field, a save slot, a Dictionary read, a method that can return null, a value
	# another sheet handed over. Each of these hands the value back only when it really is that kind of
	# thing, and your own default otherwise, so ONE row replaces a guard row plus a conversion.
	# Three deliberate details, each learned from what GDScript actually accepts:
	#   - the guard is `typeof(x) == TYPE_*`, never `x is String`. The analyzer REFUSES to compile
	#     `i is String` once it knows `i` is an int ("Expression is of type int so it can't be of type
	#     String"), so an `is` guard would turn "pointed the row at the wrong variable" into a build
	#     break. typeof compiles against any type and simply lands on the fallback at runtime.
	#   - a trailing `and {value}` reads "and it is not empty": Godot treats an empty String, Array or
	#     Dictionary as false. `.is_empty()` and a `!= ""` comparison are both unusable here for the
	#     same analyzer reason - each is a parse error against a value of a known other type.
	#   - a zero is NOT missing. Number Or keeps 0 and Value Or keeps 0 and "" alike; only the
	#     emptiness of a text/list/record counts as nothing.
	# The value expression is read two or three times in the emitted line, so keep it a READ (a
	# variable, a .get()), never something that changes the game.
	descriptors.append(F.make_descriptor("Core", "NumberOr", "Number Or", ACEDescriptor.ACEType.EXPRESSION, "({value} if typeof({value}) in [TYPE_INT, TYPE_FLOAT] else {fallback})", "", [F.make_param("value", "String", "0", "Value", "The untyped value to check - a save slot read, a JSON field, a Dictionary key.", "expression"), F.make_param("fallback", "String", "0", "Or", "What you get back when it is not a number.", "expression")], "Variables", "{value} as a number, or {fallback}")
		.described("The value when it really is a number, or your own default when it is missing, null, text, or anything else. A zero counts as a real number and is kept. Use it to put a loaded value straight into a whole-number or decimal variable without a guard row first. " + DOUBLE_READ_NOTE))
	descriptors.append(F.make_descriptor("Core", "TextOr", "Text Or", ACEDescriptor.ACEType.EXPRESSION, "({value} if (typeof({value}) == TYPE_STRING and {value}) else {fallback})", "", [F.make_param("value", "String", "\"\"", "Value", "The untyped value to check - a save slot read, a JSON field, a Dictionary key.", "expression"), F.make_param("fallback", "String", "\"Player\"", "Or", "What you get back when it is not text, or is blank.", "expression")], "Variables", "{value} as text, or {fallback}")
		.described("The value when it really is text with something in it, or your own default when it is missing, null, blank, or another kind of value. The classic use is a saved player name that falls back to \"Player\". " + DOUBLE_READ_NOTE))
	# TYPE_PACKED_BYTE_ARRAY is the FIRST of the packed families and TYPE_MAX sits past the last, so
	# `typeof(x) >= TYPE_PACKED_BYTE_ARRAY` is "x is one of the packed arrays" without naming nine
	# constants. It earns its place because Split Text hands back a PackedStringArray: without it the
	# single most natural way to build a list here fell straight through to the fallback.
	descriptors.append(F.make_descriptor("Core", "ListOr", "List Or", ACEDescriptor.ACEType.EXPRESSION, "({value} if ((typeof({value}) == TYPE_ARRAY or typeof({value}) >= TYPE_PACKED_BYTE_ARRAY) and {value}) else {fallback})", "", [F.make_param("value", "String", "[]", "Value", "The untyped value to check - a loaded inventory, a JSON array, a Split Text result, a Dictionary key.", "expression"), F.make_param("fallback", "String", "[]", "Or", "What you get back when it is not a list, or is empty.", "expression")], "Variables", "{value} as a list, or {fallback}")
		.described("The value when it really is a list with items in it, or your own default when it is missing, null, empty, or another kind of value. A Split Text result counts as a list. Safe to feed straight into a For Each. " + DOUBLE_READ_NOTE))
	descriptors.append(F.make_descriptor("Core", "RecordOr", "Record Or", ACEDescriptor.ACEType.EXPRESSION, "({value} if (typeof({value}) == TYPE_DICTIONARY and {value}) else {fallback})", "", [F.make_param("value", "String", "{}", "Value", "The untyped value to check - a loaded settings block, a JSON object, a Dictionary key.", "expression"), F.make_param("fallback", "String", "{}", "Or", "What you get back when it is not a record, or is empty.", "expression")], "Variables", "{value} as a record, or {fallback}")
		.described("The value when it really is a record (a dictionary) with keys in it, or your own default when it is missing, null, empty, or another kind of value. Pair it with Get Key so a whole missing settings block reads as defaults. " + DOUBLE_READ_NOTE))
	descriptors.append(F.make_descriptor("Core", "ValueOr", "Value Or", ACEDescriptor.ACEType.EXPRESSION, "({value} if {value} != null else {fallback})", "", [F.make_param("value", "String", "null", "Value", "Anything that might be null - a method result, a freed reference, a missing key.", "expression"), F.make_param("fallback", "String", "0", "Or", "What you get back when it is null.", "expression")], "Variables", "{value}, or {fallback} when it is nothing")
		.described("The value unless it is null, in which case your own default. This one guards nothing else: a zero, a blank text and an empty list all count as real values here. Use it for a method that can hand back null. " + DOUBLE_READ_NOTE))

	# Expressions
	descriptors.append(F.make_descriptor("Core", "GetVar", "Get Variable", ACEDescriptor.ACEType.EXPRESSION, "{var_name}", "", [F.make_param("var_name", "String", "var", "Variable", "Variable to read.", "variable_reference")], "Variables", "{var_name}")
		.described("Returns the current value stored in the named variable."))
	descriptors.append(F.make_descriptor("Core", "GetDelta", "Get Delta", ACEDescriptor.ACEType.EXPRESSION, "delta", "", [], "General Expressions", "delta")
		.described("Returns the seconds since last frame, used to make motion frame-rate independent."))
	descriptors.append(F.make_descriptor("Core", "GetPosition2D", "Get Position", ACEDescriptor.ACEType.EXPRESSION, "position", "", [], "General Expressions", "position", "Node2D")
		.described("Returns the node's 2D position as a Vector2."))
	descriptors.append(F.make_descriptor("Core", "GetVelocity2D", "Get Velocity", ACEDescriptor.ACEType.EXPRESSION, "velocity", "", [], "General Expressions", "velocity", "CharacterBody2D")
		.described("Returns the character body's current movement velocity."))
	descriptors.append(F.make_descriptor("Core", "GetLinearVelocity2D", "Get Linear Velocity", ACEDescriptor.ACEType.EXPRESSION, "linear_velocity", "", [], "General Expressions", "linear_velocity", "RigidBody2D")
		.described("Returns the rigid body's current linear velocity from physics."))
	descriptors.append(F.make_descriptor("Core", "GetMonitoring", "Get Monitoring", ACEDescriptor.ACEType.EXPRESSION, "monitoring", "", [], "General Expressions", "monitoring", "Area2D")
		.described("Returns whether the area is currently watching for overlaps."))
	descriptors.append(F.make_descriptor("Core", "GetTimerTimeLeft", "Get Time Left", ACEDescriptor.ACEType.EXPRESSION, "time_left", "", [], "General Expressions", "time_left", "Timer")
		.described("Returns the seconds remaining before the timer fires."))
	descriptors.append(F.make_descriptor("Core", "GetCurrentAnimation", "Get Current Animation", ACEDescriptor.ACEType.EXPRESSION, "current_animation", "", [], "General Expressions", "current_animation", "AnimationPlayer")
		.described("Returns the name of the animation currently playing."))

	# ── More Array helpers (make list manipulation easy without dropping to code) ──
	descriptors.append(F.make_descriptor("Core", "ArrayFront", "First Item", ACEDescriptor.ACEType.EXPRESSION, "{var_name}.front()", "", [F.make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array")], "Variables: Array", "{var_name}.front()")
		.described("Returns the first item in the array."))
	descriptors.append(F.make_descriptor("Core", "ArrayBack", "Last Item", ACEDescriptor.ACEType.EXPRESSION, "{var_name}.back()", "", [F.make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array")], "Variables: Array", "{var_name}.back()")
		.described("Returns the last item in the array."))
	descriptors.append(F.make_descriptor("Core", "ArrayFind", "Index Of", ACEDescriptor.ACEType.EXPRESSION, "{var_name}.find({value})", "", [F.make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array"), F.make_param("value", "String", "0", "Value", "Value to find (-1 if missing).", "expression")], "Variables: Array", "{var_name}.find({value})")
		.described("Returns the position of a value in the array, or -1 if it's missing."))
	descriptors.append(F.make_descriptor("Core", "ArrayCount", "Count Of", ACEDescriptor.ACEType.EXPRESSION, "{var_name}.count({value})", "", [F.make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array"), F.make_param("value", "String", "0", "Value", "Value to count.", "expression")], "Variables: Array", "{var_name}.count({value})")
		.described("Returns how many times a value appears in the array."))
	descriptors.append(F.make_descriptor("Core", "ArrayReverse", "Reverse Array", ACEDescriptor.ACEType.ACTION, "{var_name}.reverse()", "", [F.make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array")], "Variables: Array", "Reverse {var_name}")
		.described("Flips the array so its items run in the opposite order."))
	descriptors.append(F.make_descriptor("Core", "ArrayPushFront", "Push To Front", ACEDescriptor.ACEType.ACTION, "{var_name}.push_front({value})", "", [F.make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array"), F.make_param("value", "String", "0", "Value", "Value to prepend.", "expression")], "Variables: Array", "Push {value} to front of {var_name}")
		.described("Inserts a value at the start of the array, shifting the rest along."))
	descriptors.append(F.make_descriptor("Core", "ArrayPopBack", "Pop Last", ACEDescriptor.ACEType.EXPRESSION, "{var_name}.pop_back()", "", [F.make_param("var_name", "String", "list", "Array", "Array variable (removes + returns last).", "variable_reference:Array")], "Variables: Array", "{var_name}.pop_back()")
		.described("Removes and returns the last item of the array."))
	descriptors.append(F.make_descriptor("Core", "ArrayPopFront", "Pop First", ACEDescriptor.ACEType.EXPRESSION, "{var_name}.pop_front()", "", [F.make_param("var_name", "String", "list", "Array", "Array variable (removes + returns first).", "variable_reference:Array")], "Variables: Array", "{var_name}.pop_front()")
		.described("Removes and returns the first item of the array."))
	descriptors.append(F.make_descriptor("Core", "ArrayAppendArray", "Append Array", ACEDescriptor.ACEType.ACTION, "{var_name}.append_array({other})", "", [F.make_param("var_name", "String", "list", "Array", "Destination array.", "variable_reference:Array"), F.make_param("other", "String", "[]", "Other", "Array whose items are appended.", "expression")], "Variables: Array", "Append {other} to {var_name}")
		.described("Adds every item from another array onto the end of this one."))
	descriptors.append(F.make_descriptor("Core", "ArraySlice", "Slice", ACEDescriptor.ACEType.EXPRESSION, "{var_name}.slice({from}, {to})", "", [F.make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array"), F.make_param("from", "String", "0", "From", "Start index.", "expression"), F.make_param("to", "String", "1", "To", "End index (exclusive).", "expression")], "Variables: Array", "{var_name}.slice({from}, {to})")
		.described("Returns a sub-section of the array between the start and end indexes."))
	descriptors.append(F.make_descriptor("Core", "ArrayJoin", "Join To Text", ACEDescriptor.ACEType.EXPRESSION, "{separator}.join({var_name})", "", [F.make_param("var_name", "String", "list", "Array", "Array of strings.", "variable_reference:Array"), F.make_param("separator", "String", "\", \"", "Separator", "String between items.", "expression")], "Variables: Array", "join {var_name} with {separator}")
		.described("Joins an array of strings into one text using a separator."))
	descriptors.append(F.make_descriptor("Core", "ArrayMax", "Array Max", ACEDescriptor.ACEType.EXPRESSION, "{var_name}.max()", "", [F.make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array")], "Variables: Array", "{var_name}.max()")
		.described("Returns the largest value found in the array."))
	descriptors.append(F.make_descriptor("Core", "ArrayMin", "Array Min", ACEDescriptor.ACEType.EXPRESSION, "{var_name}.min()", "", [F.make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array")], "Variables: Array", "{var_name}.min()")
		.described("Returns the smallest value found in the array."))
	descriptors.append(F.make_descriptor("Core", "ArrayDuplicate", "Copy Array", ACEDescriptor.ACEType.EXPRESSION, "{var_name}.duplicate()", "", [F.make_param("var_name", "String", "list", "Array", "Array variable to copy.", "variable_reference:Array")], "Variables: Array", "{var_name}.duplicate()")
		.described("Returns an independent copy of the array so edits don't affect the original."))
	descriptors.append(F.make_descriptor("Core", "ArrayResize", "Resize Array", ACEDescriptor.ACEType.ACTION, "{var_name}.resize({size})", "", [F.make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array"), F.make_param("size", "String", "0", "Size", "New length.", "expression")], "Variables: Array", "Resize {var_name} to {size}")
		.described("Changes the array's length, adding empty slots or trimming items."))
	descriptors.append(F.make_descriptor("Core", "ArrayFill", "Fill Array", ACEDescriptor.ACEType.ACTION, "{var_name}.fill({value})", "", [F.make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array"), F.make_param("value", "String", "0", "Value", "Value to fill every slot with.", "expression")], "Variables: Array", "Fill {var_name} with {value}")
		.described("Sets every slot in the array to the same value."))

	# ── More Dictionary helpers ──
	descriptors.append(F.make_descriptor("Core", "DictDuplicate", "Copy Dictionary", ACEDescriptor.ACEType.EXPRESSION, "{var_name}.duplicate()", "", [F.make_param("var_name", "String", "dict", "Dictionary", "Dictionary variable to copy.", "variable_reference:Dictionary")], "Variables: Dictionary", "{var_name}.duplicate()")
		.described("Returns an independent copy of the dictionary."))
	descriptors.append(F.make_descriptor("Core", "DictHasValue", "Has Value", ACEDescriptor.ACEType.CONDITION, "{var_name}.values().has({value})", "", [F.make_param("var_name", "String", "dict", "Dictionary", "Dictionary variable.", "variable_reference:Dictionary"), F.make_param("value", "String", "0", "Value", "Value to look for.", "expression")], "Variables: Dictionary", "{var_name} has value {value}")
		.described("True when the dictionary contains the given value anywhere."))

	# ── Vector helpers (Vector2/Vector3 manipulation) ──
	descriptors.append(F.make_descriptor("Core", "MakeVector2", "Make Vector2", ACEDescriptor.ACEType.EXPRESSION, "Vector2({x}, {y})", "", [F.make_param("x", "String", "0.0", "X", "X component.", "expression"), F.make_param("y", "String", "0.0", "Y", "Y component.", "expression")], "Variables: Vector", "Vector2({x}, {y})")
		.described("Builds a Vector2 from separate x and y numbers, for positions or directions."))
	descriptors.append(F.make_descriptor("Core", "MakeVector3", "Make Vector3", ACEDescriptor.ACEType.EXPRESSION, "Vector3({x}, {y}, {z})", "", [F.make_param("x", "String", "0.0", "X", "X component.", "expression"), F.make_param("y", "String", "0.0", "Y", "Y component.", "expression"), F.make_param("z", "String", "0.0", "Z", "Z component.", "expression")], "Variables: Vector", "Vector3({x}, {y}, {z})")
		.described("Builds a 3D point or direction from X, Y and Z numbers."))
	descriptors.append(F.make_descriptor("Core", "VectorLength", "Vector Length", ACEDescriptor.ACEType.EXPRESSION, "{vector}.length()", "", [F.make_param("vector", "String", "Vector2.ZERO", "Vector", "Vector expression.", "expression")], "Variables: Vector", "{vector}.length()")
		.described("Returns how long a vector is, e.g. a velocity's speed."))
	descriptors.append(F.make_descriptor("Core", "VectorNormalized", "Normalized", ACEDescriptor.ACEType.EXPRESSION, "{vector}.normalized()", "", [F.make_param("vector", "String", "Vector2.ZERO", "Vector", "Vector expression.", "expression")], "Variables: Vector", "{vector}.normalized()")
		.described("Returns the vector shrunk to length 1, keeping only its direction."))
	descriptors.append(F.make_descriptor("Core", "VectorDistanceTo", "Distance Between", ACEDescriptor.ACEType.EXPRESSION, "{a}.distance_to({b})", "", [F.make_param("a", "String", "Vector2.ZERO", "From", "First point.", "expression"), F.make_param("b", "String", "Vector2.ZERO", "To", "Second point.", "expression")], "Variables: Vector", "{a}.distance_to({b})")
		.described("Returns the straight-line distance between two points."))
	descriptors.append(F.make_descriptor("Core", "VectorDirectionTo", "Direction To", ACEDescriptor.ACEType.EXPRESSION, "{a}.direction_to({b})", "", [F.make_param("a", "String", "Vector2.ZERO", "From", "Start point.", "expression"), F.make_param("b", "String", "Vector2.ZERO", "To", "Target point.", "expression")], "Variables: Vector", "{a}.direction_to({b})")
		.described("Returns a unit vector pointing from one point toward another, handy for aiming."))
	descriptors.append(F.make_descriptor("Core", "VectorAngle", "Vector Angle", ACEDescriptor.ACEType.EXPRESSION, "{vector}.angle()", "", [F.make_param("vector", "String", "Vector2.ZERO", "Vector", "Vector2 expression (radians).", "expression")], "Variables: Vector", "{vector}.angle()")
		.described("Returns a 2D vector's angle in radians, useful for facing direction."))
	descriptors.append(F.make_descriptor("Core", "VectorDot", "Dot Product", ACEDescriptor.ACEType.EXPRESSION, "{a}.dot({b})", "", [F.make_param("a", "String", "Vector2.ZERO", "A", "First vector.", "expression"), F.make_param("b", "String", "Vector2.ZERO", "B", "Second vector.", "expression")], "Variables: Vector", "{a}.dot({b})")
		.described("Returns the dot product of two vectors, telling how aligned they are."))
	descriptors.append(F.make_descriptor("Core", "VectorRotated", "Rotated", ACEDescriptor.ACEType.EXPRESSION, "{vector}.rotated({radians})", "", [F.make_param("vector", "String", "Vector2.ZERO", "Vector", "Vector2 expression.", "expression"), F.make_param("radians", "String", "0.0", "Radians", "Rotation in radians.", "expression")], "Variables: Vector", "{vector}.rotated({radians})")
		.described("Returns the vector turned by the given angle in radians."))
	descriptors.append(F.make_descriptor("Core", "VectorLerp", "Vector Lerp", ACEDescriptor.ACEType.EXPRESSION, "{a}.lerp({b}, {weight})", "", [F.make_param("a", "String", "Vector2.ZERO", "From", "Start vector.", "expression"), F.make_param("b", "String", "Vector2.ZERO", "To", "End vector.", "expression"), F.make_param("weight", "String", "0.5", "Weight", "0..1 blend.", "expression")], "Variables: Vector", "{a}.lerp({b}, {weight})")
		.described("Returns a point blended between two vectors, great for smooth movement."))
	descriptors.append(F.make_descriptor("Core", "VectorLimitLength", "Clamp Length", ACEDescriptor.ACEType.EXPRESSION, "{vector}.limit_length({max_length})", "", [F.make_param("vector", "String", "Vector2.ZERO", "Vector", "Vector expression.", "expression"), F.make_param("max_length", "String", "1.0", "Max length", "Maximum magnitude.", "expression")], "Variables: Vector", "{vector}.limit_length({max_length})")
		.described("Returns the vector capped to a maximum length, e.g. a speed limit."))
	# ── Named parts: ONE verb for a pair, a triple, a colour and a record alike ──
	# Make Vector2/3 BUILD vectors and Length/Angle/Normalized/Direction To read DERIVED values; until
	# now nothing named a single component, so it was Get/Set Property with a typed-in `position.x`.
	# These read as a sentence instead: "the up/down part of velocity", "the see-through part of
	# modulate". The emitted access is a subscript with a quoted key, which Godot resolves as a
	# component on Vector2/Vector3/Color AND as a field on a Dictionary - so the same row also reads
	# and writes a record's named field, and a saved {"x": …, "y": …} position needs no special case.
	# A record key OUTSIDE the seven named parts stays with the shipped Get Key (with default) / Set
	# Key, which is where an arbitrary key (and its own missing-value fallback) belongs.
	# Why a subscript rather than the `.y` a hand would write: `{var_name}.{part} = {value}` is
	# character-for-character the Set Property catch-all, and being authored in an earlier module it
	# would out-rank it in the reverse-lift index and re-label EVERY hand-written `foo.bar = baz` as
	# Set Part Of. The bracket form ties with Set Key instead, which is authored earlier here and so
	# keeps winning; nothing that lifts today changes.
	# THE PRICE of that choice, stated plainly because it is a real one: the emitted `velocity["y"] =
	# 0.0` is character-for-character what Set Key emits, so REOPENING a .gd-backed sheet lifts the
	# row back as Set Key, not as Set Part Of. The code is byte-identical either way (the lossless
	# covenant is untouched) - what is lost on a reopen is the sentence, and that is the deliberate
	# trade for never mis-labelling somebody else's `save["gold"] = 5`. Pinned in fallbacks_test.
	# The target is a PROPERTY reference, not a sheet-variable dropdown: the headline targets are a
	# node's own members (`velocity`, `modulate`), which a closed variables dropdown cannot name at
	# all. The property field is an editable autocomplete over the host class, so a sheet variable is
	# still typed in the same cell.
	descriptors.append(F.make_descriptor("Core", "PartOf", "Part Of", ACEDescriptor.ACEType.EXPRESSION, "({value})[{part}]", "", [F.make_param("value", "String", "Vector2(1, 2)", "Of", "A Vector2, Vector3, Color or record to read one part of.", "expression"), _part_param("Which named part to read.")], "Variables: Vector", "the {part} part of {value}")
		.described("One named piece of a pair, a triple, a colour or a record: the up/down part of a velocity (the jump-or-fall test), the see-through part of a tint, the forward/back part of a 3D direction. Reads as a sentence instead of a typed-in .y. Pick a part the value actually has - a record that might be missing the field is the shipped Get Key (with default)'s job, because that one takes a fallback and this one does not."))
	descriptors.append(F.make_descriptor("Core", "SetPartOf", "Set Part Of", ACEDescriptor.ACEType.ACTION, "{var_name}[{part}] = {value}", "", [F.make_param("var_name", "String", "self.position", "Variable or property", "What to change one part of: a node's own member (velocity, modulate, position) picked from the list, or the name of a sheet variable holding a Vector, Color or record.", "property_reference"), _part_param("Which named part to write."), F.make_param("value", "String", "0.0", "To", "The new value for that one part.", "expression")], "Variables: Vector", "set the {part} part of {var_name} to {value}")
		.described("Changes one named part and leaves the rest alone: zero the vertical speed on landing and keep the horizontal, flatten a 3D direction to the ground plane, fade only the see-through part of a tint. Writing a part a record does not have yet ADDS it."))

	# ── String helpers (the common manipulations; the long tail stays one fx away) ──
	descriptors.append(F.make_descriptor("Core", "StringContains", "Text Contains", ACEDescriptor.ACEType.CONDITION, "{text}.contains({needle})", "", [F.make_param("text", "String", "\"\"", "Text", "Text to search.", "expression"), F.make_param("needle", "String", "\"\"", "Needle", "Substring to find.", "expression")], "Variables: String", "{text} contains {needle}")
		.described("True when the text contains the given substring somewhere inside it."))
	descriptors.append(F.make_descriptor("Core", "StringBeginsWith", "Text Begins With", ACEDescriptor.ACEType.CONDITION, "{text}.begins_with({prefix})", "", [F.make_param("text", "String", "\"\"", "Text", "Text to test.", "expression"), F.make_param("prefix", "String", "\"\"", "Prefix", "Expected prefix.", "expression")], "Variables: String", "{text} begins with {prefix}")
		.described("True when the text starts with the given prefix."))
	descriptors.append(F.make_descriptor("Core", "StringEndsWith", "Text Ends With", ACEDescriptor.ACEType.CONDITION, "{text}.ends_with({suffix})", "", [F.make_param("text", "String", "\"\"", "Text", "Text to test.", "expression"), F.make_param("suffix", "String", "\"\"", "Suffix", "Expected suffix.", "expression")], "Variables: String", "{text} ends with {suffix}")
		.described("True when the text ends with the given suffix."))
	descriptors.append(F.make_descriptor("Core", "StringSplit", "Split Text", ACEDescriptor.ACEType.EXPRESSION, "{text}.split({separator})", "", [F.make_param("text", "String", "\"\"", "Text", "Text to split.", "expression"), F.make_param("separator", "String", "\",\"", "Separator", "Delimiter.", "expression")], "Variables: String", "{text}.split({separator})")
		.described("Returns the text chopped into a list wherever the separator appears."))
	descriptors.append(F.make_descriptor("Core", "StringToInt", "Text To Int", ACEDescriptor.ACEType.EXPRESSION, "{text}.to_int()", "", [F.make_param("text", "String", "\"0\"", "Text", "Text to parse.", "expression")], "Variables: String", "{text}.to_int()")
		.described("Returns the text parsed into a whole number."))
	descriptors.append(F.make_descriptor("Core", "StringToFloat", "Text To Float", ACEDescriptor.ACEType.EXPRESSION, "{text}.to_float()", "", [F.make_param("text", "String", "\"0.0\"", "Text", "Text to parse.", "expression")], "Variables: String", "{text}.to_float()")
		.described("Returns the text parsed into a decimal number."))
	descriptors.append(F.make_descriptor("Core", "StringPadZeros", "Pad Number", ACEDescriptor.ACEType.EXPRESSION, "str({number}).pad_zeros({digits})", "", [F.make_param("number", "String", "0", "Number", "Number to pad.", "expression"), F.make_param("digits", "String", "2", "Digits", "Minimum digit count.", "expression")], "Variables: String", "pad {number} to {digits} digits")
		.described("Returns the number padded with leading zeros, e.g. for scores like 007."))
	descriptors.append(F.make_descriptor("Core", "StringRepeat", "Repeat Text", ACEDescriptor.ACEType.EXPRESSION, "{text}.repeat({count})", "", [F.make_param("text", "String", "\"#\"", "Text", "Text to repeat.", "expression"), F.make_param("count", "String", "3", "Count", "Number of repetitions.", "expression")], "Variables: String", "{text} x {count}")
		.described("Returns the text repeated the given number of times."))

	# ── AnimationTree (event-sheet-style state machines / blends) ──
	descriptors.append(F.make_descriptor("Core", "SetAnimationTreeActive", "Set AnimationTree Active", ACEDescriptor.ACEType.ACTION, "active = {active}", "", [F.make_param("active", "String", "true", "Active", "Enable the animation tree.", "", ["true", "false"])], "Animation", "Set tree active {active}", "AnimationTree")
		.described("Turns this AnimationTree's playback on or off."))
	descriptors.append(F.make_descriptor("Core", "TravelToState", "Travel To State", ACEDescriptor.ACEType.ACTION, "get(\"parameters/playback\").travel({state})", "", [F.make_param("state", "String", "\"idle\"", "State", "State-machine node to travel to.")], "Animation", "Travel to state {state}", "AnimationTree")
		.described("Tells the state machine to transition to the named animation state."))
	descriptors.append(F.make_descriptor("Core", "SetTreeParam", "Set Tree Parameter", ACEDescriptor.ACEType.ACTION, "set({path}, {value})", "", [F.make_param("path", "String", "\"parameters/TimeScale/scale\"", "Param Path", "AnimationTree parameter path (blend amount / condition / timescale)."), F.make_param("value", "String", "1.0", "Value", "Value (number / Vector2 / bool).", "expression")], "Animation", "Set {path} to {value}", "AnimationTree")
		.described("Sets an AnimationTree parameter like a blend amount, condition or timescale."))
	descriptors.append(F.make_descriptor("Core", "IsTreeActive", "Is Tree Active", ACEDescriptor.ACEType.CONDITION, "active", "", [], "Animation", "Is tree active", "AnimationTree")
		.described("True when this AnimationTree is currently active and playing."))
	descriptors.append(F.make_descriptor("Core", "IsInState", "Is In State", ACEDescriptor.ACEType.CONDITION, "get(\"parameters/playback\").get_current_node() == {state}", "", [F.make_param("state", "String", "\"idle\"", "State", "State-machine node name.")], "Animation", "Is in state {state}", "AnimationTree")
		.described("True when the state machine is currently in the named animation state."))
	descriptors.append(F.make_descriptor("Core", "GetCurrentState", "Current State", ACEDescriptor.ACEType.EXPRESSION, "get(\"parameters/playback\").get_current_node()", "", [], "Animation", "current state", "AnimationTree")
		.described("Returns the name of the state machine's current animation state."))
	descriptors.append(F.make_descriptor("Core", "GetTreeParam", "Tree Parameter", ACEDescriptor.ACEType.EXPRESSION, "get({path})", "", [F.make_param("path", "String", "\"parameters/TimeScale/scale\"", "Param Path", "AnimationTree parameter path.")], "Animation", "param {path}", "AnimationTree")
		.described("Returns the current value of an AnimationTree parameter."))


	# The difficulty curve as a value: start, drift per minute, hard limit - drops into any
	# number param so a spawner literally accelerates over the run. Zeroed by Start Ramp Clock
	# (otherwise minutes count from engine start).
	descriptors.append(F.make_descriptor("Core", "RampedValue", "Ramped", ACEDescriptor.ACEType.EXPRESSION, "clampf({start} + {per_minute} * (float(Time.get_ticks_msec()) / 60000.0 - float(get_meta(&\"__ramp_zero\", 0.0))), minf({start}, {limit}), maxf({start}, {limit}))", "", [F.make_param("start", "String", "2.0", "Start", "The value at minute zero.", "expression"), F.make_param("per_minute", "String", "-0.3", "Per Minute", "Drift per minute - negative ramps down.", "expression"), F.make_param("limit", "String", "0.5", "Limit", "The value never passes this.", "expression")], "Math & Random", "ramped from {start} by {per_minute}/min, limit {limit}")
		.described("A value that drifts over time and stops at a limit - 'Every Ramped(2, -0.3, 0.5) seconds' is a spawner that speeds up as the run goes on. Call Start Ramp Clock when the run begins."))
	descriptors.append(F.make_descriptor("Core", "StartRampClock", "Start Ramp Clock", ACEDescriptor.ACEType.ACTION, "set_meta(&\"__ramp_zero\", float(Time.get_ticks_msec()) / 60000.0)", "", [], "Time", "start the ramp clock")
		.described("Marks minute zero for this node's Ramped values - call it when the run actually starts, not in menus."))
	# Tiles as a unit: distances in tile counts, sized by ONE project setting - so 'within
	# Tiles(3)' reads the way a grid game thinks.
	descriptors.append(F.make_descriptor("Core", "TilesUnit", "Tiles", ACEDescriptor.ACEType.EXPRESSION, "({count} * float(ProjectSettings.get_setting(\"eventforge/tile_size\", 16.0)))", "", [F.make_param("count", "String", "3", "Tiles", "How many tiles.", "expression")], "Math & Random", "Tiles({count})")
		.described("A distance in tiles: Tiles(3) is three tiles in pixels, sized by the eventforge/tile_size project setting (default 16). Set it once and every distance can speak in tiles."))
	return descriptors


## The named-part dropdown Part Of and Set Part Of share. `display_option_labels` is what keeps the
## GDScript out of the sentence: the row emits `velocity["y"]` and READS "the Y (up / down) part of
## velocity", because the emitted value here is always exactly one of the seven option keys.
static func _part_param(description: String) -> ACEParam:
	var parameter: ACEParam = F.make_param("part", "String", "\"y\"", "Part", description, "", PART_OPTIONS)
	parameter.display_option_labels = true
	return parameter
