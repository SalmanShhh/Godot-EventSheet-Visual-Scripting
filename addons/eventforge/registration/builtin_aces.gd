# EventForge — Built-in ACE descriptors
# Provides the minimum Core ACE surface for Phase 1.
@tool
extends RefCounted
class_name EventForgeBuiltinACEs

const COMPARISON_OPERATORS: Array[String] = EventForgeACEFactory.COMPARISON_OPERATORS

## Returns the minimum built-in ACE descriptor set for Phase 1.
static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# Per-vocabulary modules (the maintainable shape — see ace_factory.gd for the module
	# contract). New vocabularies land here; the legacy groups below migrate over time.
	descriptors.append_array(EventForgeAudioACEs.get_descriptors())

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
	descriptors.append(_make_descriptor("Core", "OnEditorRun", "On Editor Run", ACEDescriptor.ACEType.TRIGGER, "", "_run", [], "Editor Tools", "On editor run (File > Run)"))
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
	descriptors.append(_make_descriptor("Core", "ReturnValue", "Return Value", ACEDescriptor.ACEType.ACTION, "return {value}", "", [_make_param("value", "String", "0", "Value", "Expression to return (function return types are set on the function).", "expression")], "Functions", "Return {value}"))
	descriptors.append(_make_descriptor("Core", "ReturnEarly", "Return (stop here)", ACEDescriptor.ACEType.ACTION, "return", "", [], "Functions", "Return"))
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

	# System vocabulary — moved to modules/system_aces.gd (part 1).
	descriptors.append_array(EventForgeSystemACEs.get_descriptors())
	# Device input — moved to modules/device_aces.gd.
	descriptors.append_array(EventForgeDeviceACEs.get_descriptors())
	# (shader/date/platform + stateful + spawn ride in EventForgeSystemACEs above)
	# 3D vocabulary — moved to modules/native_3d_aces.gd.
	descriptors.append_array(EventForge3DACEs.get_descriptors())
	# Collections — moved to modules/collection_aces.gd.
	descriptors.append_array(EventForgeCollectionACEs.get_descriptors())

	return descriptors

## The project's InputMap action names as quoted GDScript string literals (custom actions
## from project settings first, then the ui_* defaults) — dropdown options for action
## params, so users pick real actions instead of typing strings.
static func _input_action_options() -> Array[String]:
	return EventForgeACEFactory.input_action_options()

## First custom project action when one exists, else "ui_accept".
static func _default_input_action() -> String:
	return EventForgeACEFactory.default_input_action()

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
