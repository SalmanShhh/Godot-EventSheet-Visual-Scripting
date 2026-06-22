# EventForge module — Core vocabulary (the Phase-1 surface, fully migrated).
#
# Triggers (lifecycle + common signals), InputMap conditions (HIDDEN-OPTIMIZATION RULE:
# templates may use expert idioms like &"name" StringName literals — the picker shows
# friendly labels, generated code stays readable, user fx/blocks are NEVER rewritten;
# see GDSCRIPT-PAIRING-SPEC), variable get/set/compare, and the small native-node
# action set (Node2D/CharacterBody2D/RigidBody2D/Timer/AnimationPlayer).
# Module contract: see ace_factory.gd — ace_ids/templates are API (compatibility
# covenant); this file only changes where the descriptors are AUTHORED.
@tool
extends RefCounted
class_name EventForgeCoreACEs

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# Triggers
	descriptors.append(F.make_descriptor("Core", "OnReady", "On Ready", ACEDescriptor.ACEType.TRIGGER, "", "ready", [], "Run Context", "Run on ready"))
	descriptors.append(F.make_descriptor("Core", "OnProcess", "Every Frame", ACEDescriptor.ACEType.TRIGGER, "", "_process", [], "Run Context", "Run every tick"))
	descriptors.append(F.make_descriptor("Core", "OnPhysicsProcess", "On Physics Process", ACEDescriptor.ACEType.TRIGGER, "", "_physics_process", [], "Run Context", "Run on physics process"))
	descriptors.append(F.make_descriptor("Core", "OnBodyEntered", "On Body Entered", ACEDescriptor.ACEType.TRIGGER, "", "body_entered", [F.make_param("body", "Node")], "Signals / Scene / Input", "On body entered {body}", "Area2D"))
	descriptors.append(F.make_descriptor("Core", "OnAreaEntered", "On Area Entered", ACEDescriptor.ACEType.TRIGGER, "", "area_entered", [F.make_param("area", "Area2D")], "Signals / Scene / Input", "On area entered {area}", "Area2D"))
	descriptors.append(F.make_descriptor("Core", "OnBodyExited", "On Body Exited", ACEDescriptor.ACEType.TRIGGER, "", "body_exited", [F.make_param("body", "Node")], "Signals / Scene / Input", "On body exited {body}", "Area2D"))
	descriptors.append(F.make_descriptor("Core", "OnAreaExited", "On Area Exited", ACEDescriptor.ACEType.TRIGGER, "", "area_exited", [F.make_param("area", "Area2D")], "Signals / Scene / Input", "On area exited {area}", "Area2D"))
	descriptors.append(F.make_descriptor(
		"Core",
		"OnSignal",
		"On Signal",
		ACEDescriptor.ACEType.TRIGGER,
		"",
		"",
		[F.make_param("signal_name", "String", "eventforge_signal", "Signal Name", "Signal to listen for.", "signal_reference"), F.make_param("args", "String", "", "Arguments", "Optional — the signal's argument signature so this event receives its parameters, e.g. \"amount: int\" or \"x: float, y: float\". Leave empty for a signal with no arguments.", "expression")],
		"Signals / Scene / Input",
		"On signal {signal_name}"
	))
	descriptors.append(F.make_descriptor("Core", "OnEditorRun", "On Editor Run", ACEDescriptor.ACEType.TRIGGER, "", "_run", [], "Editor Tools", "On editor run (File > Run)"))
	descriptors.append(F.make_descriptor("Core", "OnInput", "On Input", ACEDescriptor.ACEType.TRIGGER, "", "_input", [], "Input", "On input event"))
	descriptors.append(F.make_descriptor("Core", "OnUnhandledInput", "On Unhandled Input", ACEDescriptor.ACEType.TRIGGER, "", "_unhandled_input", [], "Input", "On unhandled input event"))
	descriptors.append(F.make_descriptor("Core", "OnTimeout", "On Timeout", ACEDescriptor.ACEType.TRIGGER, "", "timeout", [], "Signals / Scene / Input", "On timeout", "Timer"))
	descriptors.append(F.make_descriptor("Core", "OnAnimationFinished", "On Animation Finished", ACEDescriptor.ACEType.TRIGGER, "", "animation_finished", [F.make_param("anim_name", "String", "", "Animation", "Name of the animation that finished.")], "Signals / Scene / Input", "On animation finished {anim_name}", "AnimationPlayer"))
	# Scene-tree membership signals (every Node) — REACT to a node entering/leaving instead of polling
	# IsInsideTree in On Process. Surface as SOURCE-node triggers (another node); for the host's OWN
	# first entry, On Ready is the idiomatic answer. tree_exiting fires while still in-tree, tree_exited
	# after removal.
	descriptors.append(F.make_descriptor("Core", "OnTreeEntered", "On Tree Entered", ACEDescriptor.ACEType.TRIGGER, "", "tree_entered", [], "Signals / Scene / Input", "On tree entered", "Node"))
	descriptors.append(F.make_descriptor("Core", "OnTreeExiting", "On Tree Exiting", ACEDescriptor.ACEType.TRIGGER, "", "tree_exiting", [], "Signals / Scene / Input", "On tree exiting (still in tree)", "Node"))
	descriptors.append(F.make_descriptor("Core", "OnTreeExited", "On Tree Exited", ACEDescriptor.ACEType.TRIGGER, "", "tree_exited", [], "Signals / Scene / Input", "On tree exited (removed)", "Node"))
	descriptors.append(F.make_descriptor("Core", "OnRenamed", "On Renamed", ACEDescriptor.ACEType.TRIGGER, "", "renamed", [], "Signals / Scene / Input", "On renamed", "Node"))
	descriptors.append(F.make_descriptor("Core", "OnChildEnteredTree", "On Child Entered Tree", ACEDescriptor.ACEType.TRIGGER, "", "child_entered_tree", [F.make_param("node", "Node")], "Signals / Scene / Input", "On child entered {node}", "Node"))

	# HIDDEN-OPTIMIZATION RULE: templates may use expert idioms a beginner wouldn't type
	# (&"name" StringName literals below skip the per-call String->StringName hash in hot
	# loops) — the picker shows friendly labels, the generated code stays readable, and
	# user fx/blocks are NEVER rewritten. See GDSCRIPT-PAIRING-SPEC "Hidden optimization".
	# Input (action names come from the project's InputMap + the ui_* defaults)
	descriptors.append(F.make_descriptor("Core", "IsActionPressed", "Is Action Pressed", ACEDescriptor.ACEType.CONDITION, "Input.is_action_pressed(&{action})", "", [F.make_param("action", "String", F.default_input_action(), "Action", "Input action (from the InputMap).", "", F.input_action_options())], "Input", "{action} is pressed"))
	descriptors.append(F.make_descriptor("Core", "IsActionJustPressed", "On Action Just Pressed", ACEDescriptor.ACEType.CONDITION, "Input.is_action_just_pressed(&{action})", "", [F.make_param("action", "String", F.default_input_action(), "Action", "Input action (from the InputMap).", "", F.input_action_options())], "Input", "{action} just pressed"))
	descriptors.append(F.make_descriptor("Core", "IsActionJustReleased", "On Action Just Released", ACEDescriptor.ACEType.CONDITION, "Input.is_action_just_released(&{action})", "", [F.make_param("action", "String", F.default_input_action(), "Action", "Input action (from the InputMap).", "", F.input_action_options())], "Input", "{action} just released"))
	# Conditions
	descriptors.append(F.make_descriptor("Core", "Always", "Always", ACEDescriptor.ACEType.CONDITION, "true", "", [], "General Conditions", "Always"))
	descriptors.append(F.make_descriptor("Core", "IsOnFloor", "Is On Floor", ACEDescriptor.ACEType.CONDITION, "is_on_floor()", "", [], "General Conditions", "Is on floor", "CharacterBody2D"))
	descriptors.append(F.make_descriptor("Core", "HasGroupMember", "Has Group Member", ACEDescriptor.ACEType.CONDITION, "is_in_group(&{group})", "", [F.make_param("group", "String", "", "Group", "Group name to test.")], "General Conditions", "In group {group}"))
	descriptors.append(F.make_descriptor("Core", "CompareVar", "Compare Variable", ACEDescriptor.ACEType.CONDITION, "{var_name} {op} {value}", "", [F.make_param("var_name", "String", "var", "Variable", "Variable name to compare.", "variable_reference"), F.make_param("op", "String", "==", "Operator", "Comparison operator.", "", F.COMPARISON_OPERATORS), F.make_param("value", "String", "0", "Value", "Comparison value.", "expression")], "Variables", "{var_name} {op} {value}"))
	descriptors.append(F.make_descriptor("Core", "IsTimerStopped", "Is Timer Stopped", ACEDescriptor.ACEType.CONDITION, "is_stopped()", "", [], "General Conditions", "Is timer stopped", "Timer"))
	descriptors.append(F.make_descriptor("Core", "IsAnimationPlaying", "Is Animation Playing", ACEDescriptor.ACEType.CONDITION, "is_playing()", "", [], "General Conditions", "Is animation playing", "AnimationPlayer"))

	# Actions
	descriptors.append(F.make_descriptor("Core", "SetVar", "Set Variable", ACEDescriptor.ACEType.ACTION, "{var_name} = {value}", "", [F.make_param("var_name", "String", "var", "Variable", "Variable name to set.", "variable_reference"), F.make_param("value", "String", "0", "Value", "Value to assign.", "expression")], "Variables", "Set variable {var_name} to {value}"))
	descriptors.append(F.make_descriptor("Core", "AddVar", "Add Variable", ACEDescriptor.ACEType.ACTION, "{var_name} += {amount}", "", [F.make_param("var_name", "String", "var", "Variable", "Variable name to increment.", "variable_reference"), F.make_param("amount", "String", "1", "Amount", "Amount to add.", "expression")], "Variables", "Add {amount} to {var_name}"))
	descriptors.append(F.make_descriptor("Core", "PrintLog", "Print Log", ACEDescriptor.ACEType.ACTION, "print({message})", "", [F.make_param("message", "String", "\"TODO\"", "Message", "Message to print.")], "General Actions", "Print {message}"))
	descriptors.append(F.make_descriptor("Core", "QueueFree", "Queue Free", ACEDescriptor.ACEType.ACTION, "queue_free()", "", [], "General Actions", "Queue free"))
	descriptors.append(F.make_descriptor("Core", "ReturnValue", "Return Value", ACEDescriptor.ACEType.ACTION, "return {value}", "", [F.make_param("value", "String", "0", "Value", "Expression to return (function return types are set on the function).", "expression")], "Functions", "Return {value}"))
	descriptors.append(F.make_descriptor("Core", "ReturnEarly", "Return (stop here)", ACEDescriptor.ACEType.ACTION, "return", "", [], "Functions", "Return"))
	descriptors.append(F.make_descriptor("Core", "CallFunction", "Call Function", ACEDescriptor.ACEType.ACTION, "{function_name}({args})", "", [F.make_param("function_name", "String", "", "Function", "Name of the sheet function to call."), F.make_param("args", "String", "", "Arguments", "Comma-separated argument expressions.")], "Functions", "Call {function_name}({args})"))
	descriptors.append(F.make_descriptor("Core", "EmitSignal", "Emit Signal", ACEDescriptor.ACEType.ACTION, "emit_signal(&{signal_name}{, args})", "", [F.make_param("signal_name", "String", "\"signal\"", "Signal Name", "Signal to emit.", "signal_reference:quoted"), F.make_param("args", "String", "", "Arguments", "Optional signal arguments.")], "Signals / Scene / Input", "Emit signal {signal_name}"))
	# Node2D actions
	descriptors.append(F.make_descriptor("Core", "SetPosition2D", "Set Position", ACEDescriptor.ACEType.ACTION, "position = {pos}", "", [F.make_param("pos", "String", "Vector2(0, 0)", "Position", "Target position as a Vector2 expression.", "expression")], "General Actions", "Set position to {pos}", "Node2D"))
	descriptors.append(F.make_descriptor("Core", "MoveBy2D", "Move By", ACEDescriptor.ACEType.ACTION, "position += {offset}", "", [F.make_param("offset", "String", "Vector2(0, 0)", "Offset", "Amount to move by (Vector2 expression).", "expression")], "General Actions", "Move by {offset}", "Node2D"))
	descriptors.append(F.make_descriptor("Core", "SetRotationDeg", "Set Rotation (Degrees)", ACEDescriptor.ACEType.ACTION, "rotation_degrees = {degrees}", "", [F.make_param("degrees", "String", "0.0", "Degrees", "Rotation angle in degrees.", "expression")], "General Actions", "Set rotation to {degrees}°", "Node2D"))
	# CharacterBody2D actions
	descriptors.append(F.make_descriptor("Core", "MoveAndSlide", "Move And Slide", ACEDescriptor.ACEType.ACTION, "move_and_slide()", "", [], "General Actions", "Move and slide", "CharacterBody2D"))
	descriptors.append(F.make_descriptor("Core", "SetVelocity2D", "Set Velocity", ACEDescriptor.ACEType.ACTION, "velocity = {vel}", "", [F.make_param("vel", "String", "Vector2(0, 0)", "Velocity", "Velocity vector as a Vector2 expression.", "expression")], "General Actions", "Set velocity to {vel}", "CharacterBody2D"))
	# RigidBody2D actions
	descriptors.append(F.make_descriptor("Core", "ApplyCentralImpulse", "Apply Central Impulse", ACEDescriptor.ACEType.ACTION, "apply_central_impulse({impulse})", "", [F.make_param("impulse", "String", "Vector2(0, 0)", "Impulse", "Impulse vector as a Vector2 expression.", "expression")], "General Actions", "Apply impulse {impulse}", "RigidBody2D"))
	descriptors.append(F.make_descriptor("Core", "ApplyCentralForce2D", "Apply Central Force", ACEDescriptor.ACEType.ACTION, "apply_central_force({force})", "", [F.make_param("force", "String", "Vector2(0, 0)", "Force", "Force vector applied this physics frame (use under On Physics Process).", "expression")], "General Actions", "Apply force {force}", "RigidBody2D"))
	descriptors.append(F.make_descriptor("Core", "ApplyTorqueImpulse2D", "Apply Torque Impulse", ACEDescriptor.ACEType.ACTION, "apply_torque_impulse({torque})", "", [F.make_param("torque", "String", "0.0", "Torque", "Angular impulse (spin).", "expression")], "General Actions", "Apply torque impulse {torque}", "RigidBody2D"))
	# Timer actions
	descriptors.append(F.make_descriptor("Core", "StartTimer", "Start Timer", ACEDescriptor.ACEType.ACTION, "start({time})", "", [F.make_param("time", "String", "-1", "Duration", "Duration in seconds (-1 uses the Timer's wait_time).", "expression")], "General Actions", "Start timer ({time}s)", "Timer"))
	descriptors.append(F.make_descriptor("Core", "StopTimer", "Stop Timer", ACEDescriptor.ACEType.ACTION, "stop()", "", [], "General Actions", "Stop timer", "Timer"))
	# AnimationPlayer actions
	descriptors.append(F.make_descriptor("Core", "PlayAnimation", "Play Animation", ACEDescriptor.ACEType.ACTION, "play(&{anim_name})", "", [F.make_param("anim_name", "String", "\"idle\"", "Animation", "Name of the animation to play.", "animation_reference")], "General Actions", "Play animation {anim_name}", "AnimationPlayer"))
	descriptors.append(F.make_descriptor("Core", "StopAnimation", "Stop Animation", ACEDescriptor.ACEType.ACTION, "stop()", "", [], "General Actions", "Stop animation", "AnimationPlayer"))

	# ── 2D spatial queries (mirror of the 3D raycast block — shooting, interaction, AI
	# vision, ground-snap. A RayCast2D node set + host-agnostic Node2D world queries via
	# intersect_ray, single-line per the parity contract). ──
	descriptors.append(F.make_descriptor("Core", "RayCast2DIsColliding", "RayCast Is Colliding (2D)", ACEDescriptor.ACEType.CONDITION, "is_colliding()", "", [], "Raycast 2D", "RayCast is colliding", "RayCast2D"))
	descriptors.append(F.make_descriptor("Core", "RayCast2DForceUpdate", "Force RayCast Update (2D)", ACEDescriptor.ACEType.ACTION, "force_raycast_update()", "", [], "Raycast 2D", "Force raycast update", "RayCast2D"))
	descriptors.append(F.make_descriptor("Core", "RayCast2DGetCollider", "RayCast Collider (2D)", ACEDescriptor.ACEType.EXPRESSION, "get_collider()", "", [], "Raycast 2D", "raycast collider", "RayCast2D"))
	descriptors.append(F.make_descriptor("Core", "RayCast2DGetPoint", "RayCast Hit Point (2D)", ACEDescriptor.ACEType.EXPRESSION, "get_collision_point()", "", [], "Raycast 2D", "raycast hit point", "RayCast2D"))
	descriptors.append(F.make_descriptor("Core", "RayCast2DGetNormal", "RayCast Hit Normal (2D)", ACEDescriptor.ACEType.EXPRESSION, "get_collision_normal()", "", [], "Raycast 2D", "raycast hit normal", "RayCast2D"))
	descriptors.append(F.make_descriptor("Core", "WorldRaycastHit2D", "World Raycast Hits? (2D)", ACEDescriptor.ACEType.CONDITION, "not get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create({from}, {to})).is_empty()", "", [F.make_param("from", "String", "Vector2(0, 0)", "From", "Ray start (Vector2 expression).", "expression"), F.make_param("to", "String", "Vector2(0, 0)", "To", "Ray end (Vector2 expression).", "expression")], "Raycast 2D", "world raycast {from} -> {to} hits", "Node2D"))
	descriptors.append(F.make_descriptor("Core", "WorldRaycastPoint2D", "World Raycast Point (2D)", ACEDescriptor.ACEType.EXPRESSION, "get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create({from}, {to})).get(\"position\", Vector2.ZERO)", "", [F.make_param("from", "String", "Vector2(0, 0)", "From", "Ray start (Vector2 expression).", "expression"), F.make_param("to", "String", "Vector2(0, 0)", "To", "Ray end (Vector2 expression).", "expression")], "Raycast 2D", "world raycast point {from} -> {to}", "Node2D"))
	descriptors.append(F.make_descriptor("Core", "WorldRaycastCollider2D", "World Raycast Collider (2D)", ACEDescriptor.ACEType.EXPRESSION, "get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create({from}, {to})).get(\"collider\", null)", "", [F.make_param("from", "String", "Vector2(0, 0)", "From", "Ray start (Vector2 expression).", "expression"), F.make_param("to", "String", "Vector2(0, 0)", "To", "Ray end (Vector2 expression).", "expression")], "Raycast 2D", "world raycast collider {from} -> {to}", "Node2D"))

	# ── Project utility ACEs (settings / window / debug / time / reparent) ──
	# ── Settings: a ConfigFile in user:// (the standard persistent-settings store) ──
	# Multi-statement templates bake a per-row {uid} local so two in one event don't collide.
	descriptors.append(F.make_descriptor("Core", "SaveSetting", "Save Setting", ACEDescriptor.ACEType.ACTION, "var __cfg_{uid} = ConfigFile.new()\n__cfg_{uid}.load({path})\n__cfg_{uid}.set_value({section}, {key}, {value})\n__cfg_{uid}.save({path})", "", [F.make_param("path", "String", "\"user://settings.cfg\"", "File", "Config file path (user:// persists across runs).", "expression"), F.make_param("section", "String", "\"audio\"", "Section", "Section name.", "expression"), F.make_param("key", "String", "\"volume\"", "Key", "Setting key.", "expression"), F.make_param("value", "String", "1.0", "Value", "Value to store (any type).", "expression")], "Utility: Settings", "save {section}/{key} = {value}"))
	descriptors.append(F.make_descriptor("Core", "LoadSettingInto", "Load Setting Into Variable", ACEDescriptor.ACEType.ACTION, "var __cfg_{uid} = ConfigFile.new()\n__cfg_{uid}.load({path})\n{var_name} = __cfg_{uid}.get_value({section}, {key}, {default})", "", [F.make_param("var_name", "String", "data", "Into Variable", "Variable receiving the loaded value.", "variable_reference"), F.make_param("path", "String", "\"user://settings.cfg\"", "File", "Config file path.", "expression"), F.make_param("section", "String", "\"audio\"", "Section", "Section name.", "expression"), F.make_param("key", "String", "\"volume\"", "Key", "Setting key.", "expression"), F.make_param("default", "String", "1.0", "Default", "Fallback when the key is missing.", "expression")], "Utility: Settings", "load {section}/{key} into {var_name}"))

	# ── Window / screen / mouse / clipboard ──
	descriptors.append(F.make_descriptor("Core", "SetWindowTitle", "Set Window Title", ACEDescriptor.ACEType.ACTION, "get_window().title = {title}", "", [F.make_param("title", "String", "\"My Game\"", "Title", "Window title bar text.", "expression")], "Utility: Window", "set window title to {title}"))
	descriptors.append(F.make_descriptor("Core", "GetWindowSize", "Window Size", ACEDescriptor.ACEType.EXPRESSION, "get_window().size", "", [], "Utility: Window", "window size"))
	descriptors.append(F.make_descriptor("Core", "GetScreenSize", "Screen Size", ACEDescriptor.ACEType.EXPRESSION, "DisplayServer.screen_get_size()", "", [], "Utility: Window", "screen size"))
	# (Set Mouse Mode lives in device_aces under "Mouse" — not duplicated here.)
	descriptors.append(F.make_descriptor("Core", "SetClipboard", "Set Clipboard Text", ACEDescriptor.ACEType.ACTION, "DisplayServer.clipboard_set({text})", "", [F.make_param("text", "String", "\"\"", "Text", "Text to copy to the OS clipboard.", "expression")], "Utility: Window", "copy {text} to clipboard"))
	descriptors.append(F.make_descriptor("Core", "GetClipboard", "Clipboard Text", ACEDescriptor.ACEType.EXPRESSION, "DisplayServer.clipboard_get()", "", [], "Utility: Window", "clipboard text"))

	# ── Debug / profiling (read live engine performance monitors) ──
	descriptors.append(F.make_descriptor("Core", "GetPerfMonitor", "Performance Monitor", ACEDescriptor.ACEType.EXPRESSION, "Performance.get_monitor({monitor})", "", [F.make_param("monitor", "String", "Performance.TIME_FPS", "Monitor", "Which engine monitor to read.", "", ["Performance.TIME_FPS", "Performance.TIME_PROCESS", "Performance.TIME_PHYSICS_PROCESS", "Performance.OBJECT_COUNT", "Performance.OBJECT_NODE_COUNT", "Performance.RENDER_TOTAL_OBJECTS_IN_FRAME", "Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME", "Performance.PHYSICS_2D_ACTIVE_OBJECTS"])], "Utility: Debug", "monitor {monitor}"))
	descriptors.append(F.make_descriptor("Core", "GetStaticMemory", "Static Memory (bytes)", ACEDescriptor.ACEType.EXPRESSION, "OS.get_static_memory_usage()", "", [], "Utility: Debug", "static memory"))

	# ── Time formatting (turn seconds into clock text; read the system clock) ──
	descriptors.append(F.make_descriptor("Core", "FormatTime", "Format Time (mm:ss)", ACEDescriptor.ACEType.EXPRESSION, "(\"%02d:%02d\" % [int({seconds}) / 60, int({seconds}) % 60])", "", [F.make_param("seconds", "String", "0.0", "Seconds", "Total seconds to format.", "expression")], "Utility: Time", "format {seconds} as mm:ss"))
	descriptors.append(F.make_descriptor("Core", "GetSystemTime", "System Time String", ACEDescriptor.ACEType.EXPRESSION, "Time.get_time_string_from_system()", "", [], "Utility: Time", "system time string"))
	descriptors.append(F.make_descriptor("Core", "GetSystemDate", "System Date String", ACEDescriptor.ACEType.EXPRESSION, "Time.get_date_string_from_system()", "", [], "Utility: Time", "system date string"))

	# ── Nodes ──
	descriptors.append(F.make_descriptor("Core", "ReparentNode", "Reparent To", ACEDescriptor.ACEType.ACTION, "reparent({new_parent})", "", [F.make_param("new_parent", "String", "get_tree().current_scene", "New Parent", "Node to become the new parent (keeps global transform).", "expression")], "Utility: Nodes", "reparent to {new_parent}"))

	return descriptors
