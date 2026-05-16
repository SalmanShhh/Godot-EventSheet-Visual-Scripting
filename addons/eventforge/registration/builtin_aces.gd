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
		[_make_param("signal_name", "String", "eventforge_signal", "Signal Name", "Signal to listen for.")],
		"Signals / Scene / Input",
		"On signal {signal_name}"
	))
	descriptors.append(_make_descriptor("Core", "OnTimeout", "On Timeout", ACEDescriptor.ACEType.TRIGGER, "", "timeout", [], "Signals / Scene / Input", "On timeout", "Timer"))
	descriptors.append(_make_descriptor("Core", "OnAnimationFinished", "On Animation Finished", ACEDescriptor.ACEType.TRIGGER, "", "animation_finished", [_make_param("anim_name", "String", "", "Animation", "Name of the animation that finished.")], "Signals / Scene / Input", "On animation finished {anim_name}", "AnimationPlayer"))

	# Conditions
	descriptors.append(_make_descriptor("Core", "Always", "Always", ACEDescriptor.ACEType.CONDITION, "true", "", [], "General Conditions", "Always"))
	descriptors.append(_make_descriptor("Core", "IsOnFloor", "Is On Floor", ACEDescriptor.ACEType.CONDITION, "is_on_floor()", "", [], "General Conditions", "Is on floor", "CharacterBody2D"))
	descriptors.append(_make_descriptor("Core", "HasGroupMember", "Has Group Member", ACEDescriptor.ACEType.CONDITION, "is_in_group({group})", "", [_make_param("group", "String", "", "Group", "Group name to test.")], "General Conditions", "In group {group}"))
	descriptors.append(_make_descriptor("Core", "CompareVar", "Compare Variable", ACEDescriptor.ACEType.CONDITION, "{var_name} {op} {value}", "", [_make_param("var_name", "String", "var", "Variable", "Variable name to compare.", "variable_reference"), _make_param("op", "String", "==", "Operator", "Comparison operator.", "", COMPARISON_OPERATORS), _make_param("value", "String", "0", "Value", "Comparison value.", "expression")], "Variables", "{var_name} {op} {value}"))
	descriptors.append(_make_descriptor("Core", "IsTimerStopped", "Is Timer Stopped", ACEDescriptor.ACEType.CONDITION, "is_stopped()", "", [], "General Conditions", "Is timer stopped", "Timer"))
	descriptors.append(_make_descriptor("Core", "IsAnimationPlaying", "Is Animation Playing", ACEDescriptor.ACEType.CONDITION, "is_playing()", "", [], "General Conditions", "Is animation playing", "AnimationPlayer"))

	# Actions
	descriptors.append(_make_descriptor("Core", "SetVar", "Set Variable", ACEDescriptor.ACEType.ACTION, "{var_name} = {value}", "", [_make_param("var_name", "String", "var", "Variable", "Variable name to set.", "variable_reference"), _make_param("value", "String", "0", "Value", "Value to assign.", "expression")], "Variables", "Set variable {var_name} to {value}"))
	descriptors.append(_make_descriptor("Core", "AddVar", "Add Variable", ACEDescriptor.ACEType.ACTION, "{var_name} += {amount}", "", [_make_param("var_name", "String", "var", "Variable", "Variable name to increment.", "variable_reference"), _make_param("amount", "String", "1", "Amount", "Amount to add.", "expression")], "Variables", "Add {amount} to {var_name}"))
	descriptors.append(_make_descriptor("Core", "PrintLog", "Print Log", ACEDescriptor.ACEType.ACTION, "print({message})", "", [_make_param("message", "String", "\"TODO\"", "Message", "Message to print.")], "General Actions", "Print {message}"))
	descriptors.append(_make_descriptor("Core", "QueueFree", "Queue Free", ACEDescriptor.ACEType.ACTION, "queue_free()", "", [], "General Actions", "Queue free"))
	descriptors.append(_make_descriptor("Core", "EmitSignal", "Emit Signal", ACEDescriptor.ACEType.ACTION, "emit_signal({signal_name}{, args})", "", [_make_param("signal_name", "String", "signal", "Signal Name", "Signal to emit."), _make_param("args", "String", "", "Arguments", "Optional signal arguments.")], "Signals / Scene / Input", "Emit signal {signal_name}"))
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
	descriptors.append(_make_descriptor("Core", "PlayAnimation", "Play Animation", ACEDescriptor.ACEType.ACTION, "play({anim_name})", "", [_make_param("anim_name", "String", "\"idle\"", "Animation", "Name of the animation to play.")], "General Actions", "Play animation {anim_name}", "AnimationPlayer"))
	descriptors.append(_make_descriptor("Core", "StopAnimation", "Stop Animation", ACEDescriptor.ACEType.ACTION, "stop()", "", [], "General Actions", "Stop animation", "AnimationPlayer"))

	# Expressions
	descriptors.append(_make_descriptor("Core", "GetVar", "Get Variable", ACEDescriptor.ACEType.EXPRESSION, "{var_name}", "", [_make_param("var_name", "String", "var", "Variable", "Variable to read.", "variable_reference")], "Variables", "{var_name}"))
	descriptors.append(_make_descriptor("Core", "GetDelta", "Get Delta", ACEDescriptor.ACEType.EXPRESSION, "delta", "", [], "General Expressions", "delta"))
	descriptors.append(_make_descriptor("Core", "GetPosition2D", "Get Position", ACEDescriptor.ACEType.EXPRESSION, "position", "", [], "General Expressions", "position", "Node2D"))
	descriptors.append(_make_descriptor("Core", "GetVelocity2D", "Get Velocity", ACEDescriptor.ACEType.EXPRESSION, "velocity", "", [], "General Expressions", "velocity", "CharacterBody2D"))
	descriptors.append(_make_descriptor("Core", "GetLinearVelocity2D", "Get Linear Velocity", ACEDescriptor.ACEType.EXPRESSION, "linear_velocity", "", [], "General Expressions", "linear_velocity", "RigidBody2D"))
	descriptors.append(_make_descriptor("Core", "GetAreaMonitoring", "Get Monitoring", ACEDescriptor.ACEType.EXPRESSION, "monitoring", "", [], "General Expressions", "monitoring", "Area2D"))
	descriptors.append(_make_descriptor("Core", "GetTimerTimeLeft", "Get Time Left", ACEDescriptor.ACEType.EXPRESSION, "time_left", "", [], "General Expressions", "time_left", "Timer"))
	descriptors.append(_make_descriptor("Core", "GetCurrentAnimation", "Get Current Animation", ACEDescriptor.ACEType.EXPRESSION, "current_animation", "", [], "General Expressions", "current_animation", "AnimationPlayer"))

	return descriptors

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
