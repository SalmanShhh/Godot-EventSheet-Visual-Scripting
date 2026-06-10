# EventForge — Built-in ACE descriptors
# Provides the minimum Core ACE surface for Phase 1.
@tool
extends RefCounted
class_name EventForgeBuiltinACEs

const COMPARISON_OPERATORS: Array[String] = ["==", "!=", "<", "<=", ">", ">="]

## Returns the minimum built-in ACE descriptor set for Phase 1.
static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# Triggers
	descriptors.append(_make_descriptor("Core", "OnReady", "On Ready", ACEDescriptor.ACEType.TRIGGER, "", "ready", [], "Run Context", "Run on ready"))
	descriptors.append(_make_descriptor("Core", "OnProcess", "Every Frame", ACEDescriptor.ACEType.TRIGGER, "", "_process", [], "Run Context", "Run every tick"))
	descriptors.append(_make_descriptor("Core", "OnPhysicsProcess", "On Physics Process", ACEDescriptor.ACEType.TRIGGER, "", "_physics_process", [], "Run Context", "Run on physics process"))
	descriptors.append(_make_descriptor("Core", "OnBodyEntered", "On Body Entered", ACEDescriptor.ACEType.TRIGGER, "", "body_entered", [_make_param("body", "Node")], "Signals / Scene / Input", "On body entered {body}", "Area2D"))
	descriptors.append(_make_descriptor("Core", "OnAreaEntered", "On Area Entered", ACEDescriptor.ACEType.TRIGGER, "", "area_entered", [_make_param("area", "Area2D")], "Signals / Scene / Input", "On area entered {area}", "Area2D"))
	descriptors.append(_make_descriptor(
		"Core",
		"OnSignal",
		"On Signal",
		ACEDescriptor.ACEType.TRIGGER,
		"",
		"",
		[_make_param("signal_name", "String", "eventforge_signal", "Signal Name", "Signal to listen for.", "signal_reference")],
		"Signals / Scene / Input",
		"On signal {signal_name}"
	))
	descriptors.append(_make_descriptor("Core", "OnInput", "On Input", ACEDescriptor.ACEType.TRIGGER, "", "_input", [], "Input", "On input event"))
	descriptors.append(_make_descriptor("Core", "OnUnhandledInput", "On Unhandled Input", ACEDescriptor.ACEType.TRIGGER, "", "_unhandled_input", [], "Input", "On unhandled input event"))
	descriptors.append(_make_descriptor("Core", "OnTimeout", "On Timeout", ACEDescriptor.ACEType.TRIGGER, "", "timeout", [], "Signals / Scene / Input", "On timeout", "Timer"))
	descriptors.append(_make_descriptor("Core", "OnAnimationFinished", "On Animation Finished", ACEDescriptor.ACEType.TRIGGER, "", "animation_finished", [_make_param("anim_name", "String", "", "Animation", "Name of the animation that finished.")], "Signals / Scene / Input", "On animation finished {anim_name}", "AnimationPlayer"))

	# HIDDEN-OPTIMIZATION RULE: templates may use expert idioms a beginner wouldn't type
	# (&"name" StringName literals below skip the per-call String->StringName hash in hot
	# loops) — the picker shows friendly labels, the generated code stays readable, and
	# user fx/blocks are NEVER rewritten. See GDSCRIPT-PAIRING-SPEC "Hidden optimization".
	# Input (action names come from the project's InputMap + the ui_* defaults)
	descriptors.append(_make_descriptor("Core", "IsActionPressed", "Is Action Pressed", ACEDescriptor.ACEType.CONDITION, "Input.is_action_pressed(&{action})", "", [_make_param("action", "String", _default_input_action(), "Action", "Input action (from the InputMap).", "", _input_action_options())], "Input", "{action} is pressed"))
	descriptors.append(_make_descriptor("Core", "IsActionJustPressed", "On Action Just Pressed", ACEDescriptor.ACEType.CONDITION, "Input.is_action_just_pressed(&{action})", "", [_make_param("action", "String", _default_input_action(), "Action", "Input action (from the InputMap).", "", _input_action_options())], "Input", "{action} just pressed"))
	descriptors.append(_make_descriptor("Core", "IsActionJustReleased", "On Action Just Released", ACEDescriptor.ACEType.CONDITION, "Input.is_action_just_released(&{action})", "", [_make_param("action", "String", _default_input_action(), "Action", "Input action (from the InputMap).", "", _input_action_options())], "Input", "{action} just released"))
	# Conditions
	descriptors.append(_make_descriptor("Core", "Always", "Always", ACEDescriptor.ACEType.CONDITION, "true", "", [], "General Conditions", "Always"))
	descriptors.append(_make_descriptor("Core", "IsOnFloor", "Is On Floor", ACEDescriptor.ACEType.CONDITION, "is_on_floor()", "", [], "General Conditions", "Is on floor", "CharacterBody2D"))
	descriptors.append(_make_descriptor("Core", "HasGroupMember", "Has Group Member", ACEDescriptor.ACEType.CONDITION, "is_in_group(&{group})", "", [_make_param("group", "String", "", "Group", "Group name to test.")], "General Conditions", "In group {group}"))
	descriptors.append(_make_descriptor("Core", "CompareVar", "Compare Variable", ACEDescriptor.ACEType.CONDITION, "{var_name} {op} {value}", "", [_make_param("var_name", "String", "var", "Variable", "Variable name to compare.", "variable_reference"), _make_param("op", "String", "==", "Operator", "Comparison operator.", "", COMPARISON_OPERATORS), _make_param("value", "String", "0", "Value", "Comparison value.", "expression")], "Variables", "{var_name} {op} {value}"))
	descriptors.append(_make_descriptor("Core", "IsTimerStopped", "Is Timer Stopped", ACEDescriptor.ACEType.CONDITION, "is_stopped()", "", [], "General Conditions", "Is timer stopped", "Timer"))
	descriptors.append(_make_descriptor("Core", "IsAnimationPlaying", "Is Animation Playing", ACEDescriptor.ACEType.CONDITION, "is_playing()", "", [], "General Conditions", "Is animation playing", "AnimationPlayer"))

	# Actions
	descriptors.append(_make_descriptor("Core", "SetVar", "Set Variable", ACEDescriptor.ACEType.ACTION, "{var_name} = {value}", "", [_make_param("var_name", "String", "var", "Variable", "Variable name to set.", "variable_reference"), _make_param("value", "String", "0", "Value", "Value to assign.", "expression")], "Variables", "Set variable {var_name} to {value}"))
	descriptors.append(_make_descriptor("Core", "AddVar", "Add Variable", ACEDescriptor.ACEType.ACTION, "{var_name} += {amount}", "", [_make_param("var_name", "String", "var", "Variable", "Variable name to increment.", "variable_reference"), _make_param("amount", "String", "1", "Amount", "Amount to add.", "expression")], "Variables", "Add {amount} to {var_name}"))
	descriptors.append(_make_descriptor("Core", "PrintLog", "Print Log", ACEDescriptor.ACEType.ACTION, "print({message})", "", [_make_param("message", "String", "\"TODO\"", "Message", "Message to print.")], "General Actions", "Print {message}"))
	descriptors.append(_make_descriptor("Core", "QueueFree", "Queue Free", ACEDescriptor.ACEType.ACTION, "queue_free()", "", [], "General Actions", "Queue free"))
	descriptors.append(_make_descriptor("Core", "CallFunction", "Call Function", ACEDescriptor.ACEType.ACTION, "{function_name}({args})", "", [_make_param("function_name", "String", "", "Function", "Name of the sheet function to call."), _make_param("args", "String", "", "Arguments", "Comma-separated argument expressions.")], "Functions", "Call {function_name}({args})"))
	descriptors.append(_make_descriptor("Core", "EmitSignal", "Emit Signal", ACEDescriptor.ACEType.ACTION, "emit_signal(&{signal_name}{, args})", "", [_make_param("signal_name", "String", "\"signal\"", "Signal Name", "Signal to emit.", "signal_reference:quoted"), _make_param("args", "String", "", "Arguments", "Optional signal arguments.")], "Signals / Scene / Input", "Emit signal {signal_name}"))
	# Node2D actions
	descriptors.append(_make_descriptor("Core", "SetPosition2D", "Set Position", ACEDescriptor.ACEType.ACTION, "position = {pos}", "", [_make_param("pos", "String", "Vector2(0, 0)", "Position", "Target position as a Vector2 expression.", "expression")], "General Actions", "Set position to {pos}", "Node2D"))
	descriptors.append(_make_descriptor("Core", "SetRotationDeg", "Set Rotation (Degrees)", ACEDescriptor.ACEType.ACTION, "rotation_degrees = {degrees}", "", [_make_param("degrees", "String", "0.0", "Degrees", "Rotation angle in degrees.", "expression")], "General Actions", "Set rotation to {degrees}°", "Node2D"))
	# CharacterBody2D actions
	descriptors.append(_make_descriptor("Core", "MoveAndSlide", "Move And Slide", ACEDescriptor.ACEType.ACTION, "move_and_slide()", "", [], "General Actions", "Move and slide", "CharacterBody2D"))
	descriptors.append(_make_descriptor("Core", "SetVelocity2D", "Set Velocity", ACEDescriptor.ACEType.ACTION, "velocity = {vel}", "", [_make_param("vel", "String", "Vector2(0, 0)", "Velocity", "Velocity vector as a Vector2 expression.", "expression")], "General Actions", "Set velocity to {vel}", "CharacterBody2D"))
	# RigidBody2D actions
	descriptors.append(_make_descriptor("Core", "ApplyCentralImpulse", "Apply Central Impulse", ACEDescriptor.ACEType.ACTION, "apply_central_impulse({impulse})", "", [_make_param("impulse", "String", "Vector2(0, 0)", "Impulse", "Impulse vector as a Vector2 expression.", "expression")], "General Actions", "Apply impulse {impulse}", "RigidBody2D"))
	# Timer actions
	descriptors.append(_make_descriptor("Core", "StartTimer", "Start Timer", ACEDescriptor.ACEType.ACTION, "start({time})", "", [_make_param("time", "String", "-1", "Duration", "Duration in seconds (-1 uses the Timer's wait_time).", "expression")], "General Actions", "Start timer ({time}s)", "Timer"))
	descriptors.append(_make_descriptor("Core", "StopTimer", "Stop Timer", ACEDescriptor.ACEType.ACTION, "stop()", "", [], "General Actions", "Stop timer", "Timer"))
	# AnimationPlayer actions
	descriptors.append(_make_descriptor("Core", "PlayAnimation", "Play Animation", ACEDescriptor.ACEType.ACTION, "play(&{anim_name})", "", [_make_param("anim_name", "String", "\"idle\"", "Animation", "Name of the animation to play.")], "General Actions", "Play animation {anim_name}", "AnimationPlayer"))
	descriptors.append(_make_descriptor("Core", "StopAnimation", "Stop Animation", ACEDescriptor.ACEType.ACTION, "stop()", "", [], "General Actions", "Stop animation", "AnimationPlayer"))

	# ── Collections (rich variables): curated Dictionary / Array / JSON vocabulary ──
	# C3 ships these as capability addons; here every op is a direct GDScript one-liner
	# (parity-safe) and the templates double as GDScript teachers. The long tail stays
	# one fx away. Variable params use "variable_reference:<Type>" so dropdowns offer
	# only matching (or Variant/untyped) variables.
	# Dictionary
	descriptors.append(_make_descriptor("Core", "DictSetKey", "Set Key", ACEDescriptor.ACEType.ACTION, "{var_name}[{key}] = {value}", "", [_make_param("var_name", "String", "dict", "Dictionary", "Dictionary variable to write into.", "variable_reference:Dictionary"), _make_param("key", "String", "\"key\"", "Key", "Key expression.", "expression"), _make_param("value", "String", "0", "Value", "Value expression.", "expression")], "Variables: Dictionary", "Set {var_name}[{key}] to {value}"))
	descriptors.append(_make_descriptor("Core", "DictDeleteKey", "Delete Key", ACEDescriptor.ACEType.ACTION, "{var_name}.erase({key})", "", [_make_param("var_name", "String", "dict", "Dictionary", "Dictionary variable.", "variable_reference:Dictionary"), _make_param("key", "String", "\"key\"", "Key", "Key to remove.", "expression")], "Variables: Dictionary", "Delete key {key} from {var_name}"))
	descriptors.append(_make_descriptor("Core", "DictClear", "Clear Dictionary", ACEDescriptor.ACEType.ACTION, "{var_name}.clear()", "", [_make_param("var_name", "String", "dict", "Dictionary", "Dictionary variable.", "variable_reference:Dictionary")], "Variables: Dictionary", "Clear {var_name}"))
	descriptors.append(_make_descriptor("Core", "DictMerge", "Merge Dictionary", ACEDescriptor.ACEType.ACTION, "{var_name}.merge({other}, true)", "", [_make_param("var_name", "String", "dict", "Dictionary", "Destination dictionary.", "variable_reference:Dictionary"), _make_param("other", "String", "{}", "Other", "Dictionary to merge in (overwrites).", "expression")], "Variables: Dictionary", "Merge {other} into {var_name}"))
	descriptors.append(_make_descriptor("Core", "DictHasKey", "Has Key", ACEDescriptor.ACEType.CONDITION, "{var_name}.has({key})", "", [_make_param("var_name", "String", "dict", "Dictionary", "Dictionary variable.", "variable_reference:Dictionary"), _make_param("key", "String", "\"key\"", "Key", "Key to test.", "expression")], "Variables: Dictionary", "{var_name} has key {key}"))
	descriptors.append(_make_descriptor("Core", "DictIsEmpty", "Dictionary Is Empty", ACEDescriptor.ACEType.CONDITION, "{var_name}.is_empty()", "", [_make_param("var_name", "String", "dict", "Dictionary", "Dictionary variable.", "variable_reference:Dictionary")], "Variables: Dictionary", "{var_name} is empty"))
	descriptors.append(_make_descriptor("Core", "DictGet", "Get Key (with default)", ACEDescriptor.ACEType.EXPRESSION, "{var_name}.get({key}, {default})", "", [_make_param("var_name", "String", "dict", "Dictionary", "Dictionary variable.", "variable_reference:Dictionary"), _make_param("key", "String", "\"key\"", "Key", "Key to read.", "expression"), _make_param("default", "String", "0", "Default", "Fallback when the key is missing.", "expression")], "Variables: Dictionary", "{var_name}.get({key})"))
	descriptors.append(_make_descriptor("Core", "DictSize", "Dictionary Size", ACEDescriptor.ACEType.EXPRESSION, "{var_name}.size()", "", [_make_param("var_name", "String", "dict", "Dictionary", "Dictionary variable.", "variable_reference:Dictionary")], "Variables: Dictionary", "{var_name}.size()"))
	descriptors.append(_make_descriptor("Core", "DictKeys", "Dictionary Keys", ACEDescriptor.ACEType.EXPRESSION, "{var_name}.keys()", "", [_make_param("var_name", "String", "dict", "Dictionary", "Dictionary variable.", "variable_reference:Dictionary")], "Variables: Dictionary", "{var_name}.keys()"))
	descriptors.append(_make_descriptor("Core", "DictValues", "Dictionary Values", ACEDescriptor.ACEType.EXPRESSION, "{var_name}.values()", "", [_make_param("var_name", "String", "dict", "Dictionary", "Dictionary variable.", "variable_reference:Dictionary")], "Variables: Dictionary", "{var_name}.values()"))
	# Array
	descriptors.append(_make_descriptor("Core", "ArrayAppend", "Append", ACEDescriptor.ACEType.ACTION, "{var_name}.append({value})", "", [_make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array"), _make_param("value", "String", "0", "Value", "Value to append.", "expression")], "Variables: Array", "Append {value} to {var_name}"))
	descriptors.append(_make_descriptor("Core", "ArrayInsert", "Insert At", ACEDescriptor.ACEType.ACTION, "{var_name}.insert({index}, {value})", "", [_make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array"), _make_param("index", "String", "0", "Index", "Insertion index.", "expression"), _make_param("value", "String", "0", "Value", "Value to insert.", "expression")], "Variables: Array", "Insert {value} at {index} in {var_name}"))
	descriptors.append(_make_descriptor("Core", "ArrayRemoveAt", "Remove At", ACEDescriptor.ACEType.ACTION, "{var_name}.remove_at({index})", "", [_make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array"), _make_param("index", "String", "0", "Index", "Index to remove.", "expression")], "Variables: Array", "Remove index {index} from {var_name}"))
	descriptors.append(_make_descriptor("Core", "ArrayErase", "Erase Value", ACEDescriptor.ACEType.ACTION, "{var_name}.erase({value})", "", [_make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array"), _make_param("value", "String", "0", "Value", "First matching value to remove.", "expression")], "Variables: Array", "Erase {value} from {var_name}"))
	descriptors.append(_make_descriptor("Core", "ArrayClear", "Clear Array", ACEDescriptor.ACEType.ACTION, "{var_name}.clear()", "", [_make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array")], "Variables: Array", "Clear {var_name}"))
	descriptors.append(_make_descriptor("Core", "ArraySort", "Sort Array", ACEDescriptor.ACEType.ACTION, "{var_name}.sort()", "", [_make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array")], "Variables: Array", "Sort {var_name}"))
	descriptors.append(_make_descriptor("Core", "ArrayShuffle", "Shuffle Array", ACEDescriptor.ACEType.ACTION, "{var_name}.shuffle()", "", [_make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array")], "Variables: Array", "Shuffle {var_name}"))
	descriptors.append(_make_descriptor("Core", "ArrayContains", "Contains", ACEDescriptor.ACEType.CONDITION, "{var_name}.has({value})", "", [_make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array"), _make_param("value", "String", "0", "Value", "Value to look for.", "expression")], "Variables: Array", "{var_name} contains {value}"))
	descriptors.append(_make_descriptor("Core", "ArrayIsEmpty", "Array Is Empty", ACEDescriptor.ACEType.CONDITION, "{var_name}.is_empty()", "", [_make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array")], "Variables: Array", "{var_name} is empty"))
	descriptors.append(_make_descriptor("Core", "ArrayAt", "Value At", ACEDescriptor.ACEType.EXPRESSION, "{var_name}[{index}]", "", [_make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array"), _make_param("index", "String", "0", "Index", "Index to read.", "expression")], "Variables: Array", "{var_name}[{index}]"))
	descriptors.append(_make_descriptor("Core", "ArraySize", "Array Size", ACEDescriptor.ACEType.EXPRESSION, "{var_name}.size()", "", [_make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array")], "Variables: Array", "{var_name}.size()"))
	descriptors.append(_make_descriptor("Core", "ArrayPickRandom", "Pick Random", ACEDescriptor.ACEType.EXPRESSION, "{var_name}.pick_random()", "", [_make_param("var_name", "String", "list", "Array", "Array variable.", "variable_reference:Array")], "Variables: Array", "random of {var_name}"))
	# JSON (save/load workflows; XML is intentionally unsupported — JSON is the format)
	descriptors.append(_make_descriptor("Core", "JsonStringify", "To JSON Text", ACEDescriptor.ACEType.EXPRESSION, "JSON.stringify({value})", "", [_make_param("value", "String", "data", "Value", "Value to serialize.", "expression")], "Variables: JSON", "JSON.stringify({value})"))
	descriptors.append(_make_descriptor("Core", "JsonParse", "From JSON Text", ACEDescriptor.ACEType.EXPRESSION, "JSON.parse_string({text})", "", [_make_param("text", "String", "\"{}\"", "Text", "JSON text to parse (null when invalid).", "expression")], "Variables: JSON", "JSON.parse_string({text})"))
	descriptors.append(_make_descriptor("Core", "JsonIsValid", "JSON Is Valid", ACEDescriptor.ACEType.CONDITION, "JSON.parse_string({text}) != null", "", [_make_param("text", "String", "\"{}\"", "Text", "JSON text to validate.", "expression")], "Variables: JSON", "{text} is valid JSON"))
	descriptors.append(_make_descriptor("Core", "JsonSaveFile", "Save JSON File", ACEDescriptor.ACEType.ACTION, "FileAccess.open({path}, FileAccess.WRITE).store_string(JSON.stringify({value}, \"\\t\"))", "", [_make_param("path", "String", "\"user://save.json\"", "Path", "File path (user:// is the writable location in exports).", "expression"), _make_param("value", "String", "data", "Value", "Value to serialize and save.", "expression")], "Variables: JSON", "Save {value} as JSON to {path}"))
	descriptors.append(_make_descriptor("Core", "JsonLoadFile", "Load JSON File", ACEDescriptor.ACEType.ACTION, "{var_name} = JSON.parse_string(FileAccess.get_file_as_string({path}))", "", [_make_param("var_name", "String", "data", "Into Variable", "Variable receiving the parsed value (null when missing/invalid).", "variable_reference"), _make_param("path", "String", "\"user://save.json\"", "Path", "File path to read.", "expression")], "Variables: JSON", "Load JSON {path} into {var_name}"))

	# Time (C3 System: Wait — handlers are implicit coroutines, await is safe anywhere)
	descriptors.append(_make_descriptor("Core", "Wait", "Wait", ACEDescriptor.ACEType.ACTION, "await get_tree().create_timer({seconds}).timeout", "", [_make_param("seconds", "String", "1.0", "Seconds", "How long to wait before the next action runs.", "expression")], "Time", "Wait {seconds} s"))
	descriptors.append(_make_descriptor("Core", "AwaitSignal", "Wait For Signal", ACEDescriptor.ACEType.ACTION, "await {signal_expression}", "", [_make_param("signal_expression", "String", "get_tree().process_frame", "Signal", "Signal to wait for (e.g. $Timer.timeout).", "expression")], "Time", "Wait for {signal_expression}"))
	# Input expressions
	descriptors.append(_make_descriptor("Core", "GetActionStrength", "Action Strength", ACEDescriptor.ACEType.EXPRESSION, "Input.get_action_strength(&{action})", "", [_make_param("action", "String", _default_input_action(), "Action", "Input action (analog strength 0..1).", "", _input_action_options())], "Input", "strength of {action}"))
	descriptors.append(_make_descriptor("Core", "GetInputAxis", "Input Axis", ACEDescriptor.ACEType.EXPRESSION, "Input.get_axis(&{negative}, &{positive})", "", [_make_param("negative", "String", "\"ui_left\"", "Negative", "Action for the negative direction.", "", _input_action_options()), _make_param("positive", "String", "\"ui_right\"", "Positive", "Action for the positive direction.", "", _input_action_options())], "Input", "axis {negative}/{positive}"))
	# ── Native-node providers (C3 coverage Lane 1: wrap NATIVE Godot features; the
	# engine maintains the implementation, we only maintain vocabulary). C3 names are
	# the display names; see docs/C3-MIGRATION-GUIDE.md for the lane mapping.
	# Tween (C3 Tween behavior -> Godot's built-in create_tween)
	descriptors.append(_make_descriptor("Core", "TweenProperty", "Tween Property", ACEDescriptor.ACEType.ACTION, "create_tween().tween_property({target}, {property}, {value}, {duration}).set_trans({transition}).set_ease({ease})", "", [_make_param("target", "String", "self", "Target", "Node whose property tweens.", "expression"), _make_param("property", "String", "\"position\"", "Property", "Property path to animate."), _make_param("value", "String", "Vector2(100, 0)", "To", "Final value expression.", "expression"), _make_param("duration", "String", "0.5", "Duration", "Seconds.", "expression"), _make_param("transition", "String", "Tween.TRANS_SINE", "Transition", "Curve shape.", "", ["Tween.TRANS_LINEAR", "Tween.TRANS_SINE", "Tween.TRANS_QUAD", "Tween.TRANS_CUBIC", "Tween.TRANS_QUART", "Tween.TRANS_ELASTIC", "Tween.TRANS_BACK", "Tween.TRANS_BOUNCE", "Tween.TRANS_EXPO", "Tween.TRANS_CIRC"]), _make_param("ease", "String", "Tween.EASE_IN_OUT", "Ease", "In / out / in-out.", "", ["Tween.EASE_IN", "Tween.EASE_OUT", "Tween.EASE_IN_OUT"])], "Tween", "Tween {property} to {value} over {duration}s"))
	# Scene flow (C3 System: layouts -> Godot scenes)
	descriptors.append(_make_descriptor("Core", "ChangeScene", "Go To Scene", ACEDescriptor.ACEType.ACTION, "get_tree().change_scene_to_file({path})", "", [_make_param("path", "String", "\"res://main.tscn\"", "Scene", "Scene file to switch to.", "expression")], "Scene", "Go to scene {path}"))
	descriptors.append(_make_descriptor("Core", "ReloadScene", "Restart Scene", ACEDescriptor.ACEType.ACTION, "get_tree().reload_current_scene()", "", [], "Scene", "Restart the current scene"))
	descriptors.append(_make_descriptor("Core", "QuitGame", "Quit Game", ACEDescriptor.ACEType.ACTION, "get_tree().quit()", "", [], "Scene", "Quit the game"))
	descriptors.append(_make_descriptor("Core", "SetPaused", "Set Game Paused", ACEDescriptor.ACEType.ACTION, "get_tree().paused = {paused}", "", [_make_param("paused", "String", "true", "Paused", "Pause state.", "", ["true", "false"])], "Scene", "Set paused to {paused}"))
	descriptors.append(_make_descriptor("Core", "SpawnScene", "Spawn Scene Instance", ACEDescriptor.ACEType.ACTION, "add_child(load({path}).instantiate())", "", [_make_param("path", "String", "\"res://enemy.tscn\"", "Scene", "Scene file to instance as a child.", "expression")], "Scene", "Spawn {path}"))
	descriptors.append(_make_descriptor("Core", "IsPaused", "Is Game Paused", ACEDescriptor.ACEType.CONDITION, "get_tree().paused", "", [], "Scene", "Game is paused"))
	# Audio (AudioStreamPlayer / 2D / 3D share these members)
	descriptors.append(_make_descriptor("Core", "PlayAudio", "Play Sound", ACEDescriptor.ACEType.ACTION, "play({from_position})", "", [_make_param("from_position", "String", "0.0", "From", "Start position in seconds.", "expression")], "General Actions", "Play sound", "AudioStreamPlayer"))
	descriptors.append(_make_descriptor("Core", "StopAudio", "Stop Sound", ACEDescriptor.ACEType.ACTION, "stop()", "", [], "General Actions", "Stop sound", "AudioStreamPlayer"))
	descriptors.append(_make_descriptor("Core", "SetVolumeDb", "Set Volume (dB)", ACEDescriptor.ACEType.ACTION, "volume_db = {db}", "", [_make_param("db", "String", "0.0", "Decibels", "0 = full volume, -80 = silent.", "expression")], "General Actions", "Set volume to {db} dB", "AudioStreamPlayer"))
	descriptors.append(_make_descriptor("Core", "IsAudioPlaying", "Is Playing", ACEDescriptor.ACEType.CONDITION, "playing", "", [], "General Conditions", "Sound is playing", "AudioStreamPlayer"))
	descriptors.append(_make_descriptor("Core", "GetPlaybackPosition", "Playback Position", ACEDescriptor.ACEType.EXPRESSION, "get_playback_position()", "", [], "General Expressions", "playback position", "AudioStreamPlayer"))
	# AnimatedSprite2D (C3 Sprite animations)
	descriptors.append(_make_descriptor("Core", "PlaySpriteAnimation", "Play Sprite Animation", ACEDescriptor.ACEType.ACTION, "play(&{anim})", "", [_make_param("anim", "String", "\"default\"", "Animation", "Animation name.")], "General Actions", "Play animation {anim}", "AnimatedSprite2D"))
	descriptors.append(_make_descriptor("Core", "StopSpriteAnimation", "Stop Sprite Animation", ACEDescriptor.ACEType.ACTION, "stop()", "", [], "General Actions", "Stop animation", "AnimatedSprite2D"))
	descriptors.append(_make_descriptor("Core", "SetSpriteFrame", "Set Frame", ACEDescriptor.ACEType.ACTION, "frame = {frame}", "", [_make_param("frame", "String", "0", "Frame", "Frame index.", "expression")], "General Actions", "Set frame to {frame}", "AnimatedSprite2D"))
	descriptors.append(_make_descriptor("Core", "SetFlipH", "Set Mirrored", ACEDescriptor.ACEType.ACTION, "flip_h = {flipped}", "", [_make_param("flipped", "String", "true", "Mirrored", "Horizontal flip.", "", ["true", "false"])], "General Actions", "Set mirrored {flipped}", "AnimatedSprite2D"))
	descriptors.append(_make_descriptor("Core", "IsSpriteAnimationPlaying", "Is Animation Playing", ACEDescriptor.ACEType.CONDITION, "is_playing()", "", [], "General Conditions", "Animation is playing", "AnimatedSprite2D"))
	descriptors.append(_make_descriptor("Core", "GetSpriteAnimation", "Current Animation", ACEDescriptor.ACEType.EXPRESSION, "animation", "", [], "General Expressions", "current animation", "AnimatedSprite2D"))
	# Camera2D
	descriptors.append(_make_descriptor("Core", "MakeCameraCurrent", "Make Camera Current", ACEDescriptor.ACEType.ACTION, "make_current()", "", [], "General Actions", "Make this camera current", "Camera2D"))
	descriptors.append(_make_descriptor("Core", "SetCameraZoom", "Set Camera Zoom", ACEDescriptor.ACEType.ACTION, "zoom = {zoom}", "", [_make_param("zoom", "String", "Vector2(1, 1)", "Zoom", "Zoom factor.", "expression")], "General Actions", "Set zoom to {zoom}", "Camera2D"))
	descriptors.append(_make_descriptor("Core", "SetCameraOffset", "Set Camera Offset", ACEDescriptor.ACEType.ACTION, "offset = {offset}", "", [_make_param("offset", "String", "Vector2(0, 0)", "Offset", "Offset from the followed position.", "expression")], "General Actions", "Set offset to {offset}", "Camera2D"))
	# Label / text (C3 Text object)
	descriptors.append(_make_descriptor("Core", "SetLabelText", "Set Text", ACEDescriptor.ACEType.ACTION, "text = str({value})", "", [_make_param("value", "String", "\"Hello\"", "Text", "Value to display (str()-converted).", "expression")], "General Actions", "Set text to {value}", "Label"))
	descriptors.append(_make_descriptor("Core", "AppendLabelText", "Append Text", ACEDescriptor.ACEType.ACTION, "text += str({value})", "", [_make_param("value", "String", "\"!\"", "Text", "Value to append.", "expression")], "General Actions", "Append {value}", "Label"))
	descriptors.append(_make_descriptor("Core", "GetLabelText", "Get Text", ACEDescriptor.ACEType.EXPRESSION, "text", "", [], "General Expressions", "text", "Label"))
	# NavigationAgent2D (C3 Pathfinding behavior)
	descriptors.append(_make_descriptor("Core", "SetNavTarget", "Find Path To", ACEDescriptor.ACEType.ACTION, "target_position = {position}", "", [_make_param("position", "String", "Vector2(0, 0)", "Target", "World position to path toward.", "expression")], "General Actions", "Find path to {position}", "NavigationAgent2D"))
	descriptors.append(_make_descriptor("Core", "IsNavFinished", "Has Arrived", ACEDescriptor.ACEType.CONDITION, "is_navigation_finished()", "", [], "General Conditions", "Arrived at destination", "NavigationAgent2D"))
	descriptors.append(_make_descriptor("Core", "GetNextPathPosition", "Next Path Position", ACEDescriptor.ACEType.EXPRESSION, "get_next_path_position()", "", [], "General Expressions", "next path position", "NavigationAgent2D"))
	descriptors.append(_make_descriptor("Core", "GetNavDistance", "Distance To Target", ACEDescriptor.ACEType.EXPRESSION, "distance_to_target()", "", [], "General Expressions", "distance to target", "NavigationAgent2D"))
	# Visibility / tint (CanvasItem)
	descriptors.append(_make_descriptor("Core", "ShowNode", "Show", ACEDescriptor.ACEType.ACTION, "show()", "", [], "General Actions", "Show", "CanvasItem"))
	descriptors.append(_make_descriptor("Core", "HideNode", "Hide", ACEDescriptor.ACEType.ACTION, "hide()", "", [], "General Actions", "Hide", "CanvasItem"))
	descriptors.append(_make_descriptor("Core", "SetModulate", "Set Color Tint", ACEDescriptor.ACEType.ACTION, "modulate = {color}", "", [_make_param("color", "String", "Color(1, 1, 1, 1)", "Color", "Tint (RGBA).", "expression")], "General Actions", "Set tint to {color}", "CanvasItem"))
	descriptors.append(_make_descriptor("Core", "IsVisible", "Is Visible", ACEDescriptor.ACEType.CONDITION, "visible", "", [], "General Conditions", "Is visible", "CanvasItem"))
	# Math & random (C3 System expressions: random, choose, clamp, lerp, distance, angle)
	descriptors.append(_make_descriptor("Core", "RandomRange", "Random", ACEDescriptor.ACEType.EXPRESSION, "randf_range({from}, {to})", "", [_make_param("from", "String", "0.0", "From", "Lower bound.", "expression"), _make_param("to", "String", "1.0", "To", "Upper bound.", "expression")], "Math & Random", "random({from}, {to})"))
	descriptors.append(_make_descriptor("Core", "RandomInt", "Random Integer", ACEDescriptor.ACEType.EXPRESSION, "randi_range({from}, {to})", "", [_make_param("from", "String", "0", "From", "Lower bound (inclusive).", "expression"), _make_param("to", "String", "9", "To", "Upper bound (inclusive).", "expression")], "Math & Random", "random int({from}, {to})"))
	descriptors.append(_make_descriptor("Core", "Choose", "Choose", ACEDescriptor.ACEType.EXPRESSION, "[{values}].pick_random()", "", [_make_param("values", "String", "1, 2, 3", "Values", "Comma-separated values to pick from.", "expression")], "Math & Random", "choose({values})"))
	descriptors.append(_make_descriptor("Core", "ClampValue", "Clamp", ACEDescriptor.ACEType.EXPRESSION, "clampf({value}, {min}, {max})", "", [_make_param("value", "String", "0.0", "Value", "Value to clamp.", "expression"), _make_param("min", "String", "0.0", "Min", "Lower bound.", "expression"), _make_param("max", "String", "1.0", "Max", "Upper bound.", "expression")], "Math & Random", "clamp({value}, {min}, {max})"))
	descriptors.append(_make_descriptor("Core", "LerpValue", "Lerp", ACEDescriptor.ACEType.EXPRESSION, "lerpf({from}, {to}, {weight})", "", [_make_param("from", "String", "0.0", "From", "Start value.", "expression"), _make_param("to", "String", "1.0", "To", "End value.", "expression"), _make_param("weight", "String", "0.5", "Weight", "0..1 blend.", "expression")], "Math & Random", "lerp({from}, {to}, {weight})"))
	descriptors.append(_make_descriptor("Core", "DistanceTo", "Distance To", ACEDescriptor.ACEType.EXPRESSION, "position.distance_to({to})", "", [_make_param("to", "String", "Vector2(0, 0)", "To", "Target position.", "expression")], "Math & Random", "distance to {to}", "Node2D"))
	descriptors.append(_make_descriptor("Core", "AngleToPoint", "Angle Toward", ACEDescriptor.ACEType.EXPRESSION, "position.angle_to_point({to})", "", [_make_param("to", "String", "Vector2(0, 0)", "To", "Target position.", "expression")], "Math & Random", "angle toward {to}", "Node2D"))

	# Expressions
	descriptors.append(_make_descriptor("Core", "GetVar", "Get Variable", ACEDescriptor.ACEType.EXPRESSION, "{var_name}", "", [_make_param("var_name", "String", "var", "Variable", "Variable to read.", "variable_reference")], "Variables", "{var_name}"))
	descriptors.append(_make_descriptor("Core", "GetDelta", "Get Delta", ACEDescriptor.ACEType.EXPRESSION, "delta", "", [], "General Expressions", "delta"))
	descriptors.append(_make_descriptor("Core", "GetPosition2D", "Get Position", ACEDescriptor.ACEType.EXPRESSION, "position", "", [], "General Expressions", "position", "Node2D"))
	descriptors.append(_make_descriptor("Core", "GetVelocity2D", "Get Velocity", ACEDescriptor.ACEType.EXPRESSION, "velocity", "", [], "General Expressions", "velocity", "CharacterBody2D"))
	descriptors.append(_make_descriptor("Core", "GetLinearVelocity2D", "Get Linear Velocity", ACEDescriptor.ACEType.EXPRESSION, "linear_velocity", "", [], "General Expressions", "linear_velocity", "RigidBody2D"))
	descriptors.append(_make_descriptor("Core", "GetMonitoring", "Get Monitoring", ACEDescriptor.ACEType.EXPRESSION, "monitoring", "", [], "General Expressions", "monitoring", "Area2D"))
	descriptors.append(_make_descriptor("Core", "GetTimerTimeLeft", "Get Time Left", ACEDescriptor.ACEType.EXPRESSION, "time_left", "", [], "General Expressions", "time_left", "Timer"))
	descriptors.append(_make_descriptor("Core", "GetCurrentAnimation", "Get Current Animation", ACEDescriptor.ACEType.EXPRESSION, "current_animation", "", [], "General Expressions", "current_animation", "AnimationPlayer"))

	return descriptors

## The project's InputMap action names as quoted GDScript string literals (custom actions
## from project settings first, then the ui_* defaults) — dropdown options for action
## params, so users pick real actions instead of typing strings.
static func _input_action_options() -> Array[String]:
	var options: Array[String] = []
	for property_info: Dictionary in ProjectSettings.get_property_list():
		var property_name: String = str(property_info.get("name", ""))
		if property_name.begins_with("input/") and not property_name.contains("."):
			options.append("\"%s\"" % property_name.trim_prefix("input/"))
	for builtin: String in ["ui_accept", "ui_cancel", "ui_select", "ui_left", "ui_right", "ui_up", "ui_down"]:
		var quoted: String = "\"%s\"" % builtin
		if not options.has(quoted):
			options.append(quoted)
	return options

## First custom project action when one exists, else "ui_accept".
static func _default_input_action() -> String:
	var options: Array[String] = _input_action_options()
	return options[0] if not options.is_empty() else "\"ui_accept\""

## Creates an ACE descriptor instance.
static func _make_descriptor(provider_id: String, ace_id: String, display_name: String, ace_type: int, codegen_template: String, signal_name: String = "", params: Array[ACEParam] = [], category: String = "", display_text: String = "", node_type: String = "") -> ACEDescriptor:
	var descriptor: ACEDescriptor = ACEDescriptor.new()
	descriptor.provider_id = provider_id
	descriptor.ace_id = ace_id
	descriptor.display_name = display_name
	descriptor.list_name = display_name
	descriptor.display_text = display_text if not display_text.is_empty() else display_name
	descriptor.category = category
	descriptor.ace_type = ace_type
	descriptor.codegen_template = codegen_template
	descriptor.signal_name = signal_name
	descriptor.params = params
	descriptor.node_type = node_type
	descriptor.nodeType = node_type
	return descriptor

## Creates an ACE parameter instance.
static func _make_param(param_id: String, type_name: String, default_value: Variant = "", display_name: String = "", description: String = "", hint: String = "", options: Array[String] = []) -> ACEParam:
	var parameter: ACEParam = ACEParam.new()
	parameter.id = param_id
	parameter.name = param_id
	parameter.display_name = display_name if not display_name.is_empty() else param_id
	parameter.description = description
	parameter.desc = description
	parameter.type_name = type_name
	parameter.default_value = default_value
	parameter.initial_value = default_value
	parameter.initialValue = default_value
	parameter.hint = hint
	parameter.options = options.duplicate()
	return parameter
