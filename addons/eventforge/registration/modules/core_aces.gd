# EventForge module - Core vocabulary (the Phase-1 surface, fully migrated).
#
# Triggers (lifecycle + common signals), InputMap conditions (HIDDEN-OPTIMIZATION RULE:
# templates may use expert idioms like &"name" StringName literals - the picker shows
# friendly labels, generated code stays readable, user fx/blocks are NEVER rewritten),
# variable get/set/compare, and the small native-node
# action set (Node2D/CharacterBody2D/RigidBody2D/Timer/AnimationPlayer).
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility
# covenant); this file only changes where the descriptors are AUTHORED.
@tool
class_name EventForgeCoreACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# Triggers
	descriptors.append(F.make_descriptor("Core", "OnReady", "On Ready", ACEDescriptor.ACEType.TRIGGER, "", "ready", [], "Run Context", "Run on ready")
		.described("Runs once when this node first enters the scene, ideal for setup and initial values."))
	descriptors.append(F.make_descriptor("Core", "OnProcess", "Every Frame", ACEDescriptor.ACEType.TRIGGER, "", "_process", [], "Run Context", "Run every tick")
		.described("Runs every rendered frame, perfect for continuous movement, timers, or polling input."))
	descriptors.append(F.make_descriptor("Core", "OnPhysicsProcess", "On Physics Process", ACEDescriptor.ACEType.TRIGGER, "", "_physics_process", [], "Run Context", "Run on physics process")
		.described("Runs every fixed physics step, the right place for physics-based movement and forces."))
	descriptors.append(F.make_descriptor("Core", "OnPostTick", "After Every Frame (post-tick)", ACEDescriptor.ACEType.TRIGGER, "", "process_frame", [], "Run Context", "Run after every frame", "Node")
		.described("Runs once AFTER every node has processed this frame - for logic that must come last, like a camera that follows after movement, or end-of-frame cleanup."))
	descriptors.append(F.make_descriptor("Core", "OnPhysicsPostTick", "After Every Physics Tick", ACEDescriptor.ACEType.TRIGGER, "", "physics_frame", [], "Run Context", "Run after every physics tick", "Node")
		.described("Runs once AFTER every node has finished its physics step this tick - the physics sibling of post-tick."))
	descriptors.append(F.make_descriptor("Core", "OnCloseRequested", "On Close Requested", ACEDescriptor.ACEType.TRIGGER, "", "close_requested", [], "Signals / Scene / Input", "On window close requested", "Node")
		.described("Runs when the player clicks the window's close button (X) or asks to quit - the place to save progress or pop a confirm dialog before exiting."))
	descriptors.append(F.make_descriptor("Core", "OnBodyEntered", "On Body Entered", ACEDescriptor.ACEType.TRIGGER, "", "body_entered", [F.make_param("body", "Node")], "Signals / Scene / Input", "On body entered {body}", "Area2D")
		.described("Runs when a physics body enters this 2D Area, e.g. detecting the player walking into a trigger."))
	descriptors.append(F.make_descriptor("Core", "OnAreaEntered", "On Area Entered", ACEDescriptor.ACEType.TRIGGER, "", "area_entered", [F.make_param("area", "Area2D")], "Signals / Scene / Input", "On area entered {area}", "Area2D")
		.described("Runs when another 2D Area overlaps this one, e.g. a hitbox touching a hurtbox."))
	descriptors.append(F.make_descriptor("Core", "OnBodyExited", "On Body Exited", ACEDescriptor.ACEType.TRIGGER, "", "body_exited", [F.make_param("body", "Node")], "Signals / Scene / Input", "On body exited {body}", "Area2D")
		.described("Runs when a physics body leaves this 2D Area, e.g. the player stepping out of a zone."))
	descriptors.append(F.make_descriptor("Core", "OnAreaExited", "On Area Exited", ACEDescriptor.ACEType.TRIGGER, "", "area_exited", [F.make_param("area", "Area2D")], "Signals / Scene / Input", "On area exited {area}", "Area2D")
		.described("Runs when another 2D Area stops overlapping this one."))
	descriptors.append(F.make_descriptor(
		"Core",
		"OnSignal",
		"On Signal",
		ACEDescriptor.ACEType.TRIGGER,
		"",
		"",
		[F.make_param("signal_name", "String", "eventforge_signal", "Signal Name", "Signal to listen for.", "signal_reference"), F.make_param("args", "String", "", "Arguments", "Optional - the signal's argument signature so this event receives its parameters, e.g. \"amount: int\" or \"x: float, y: float\". Leave empty for a signal with no arguments.", "expression")],
		"Signals / Scene / Input",
		"On signal {signal_name}"
	)
		.described("Runs whenever the named signal fires, letting you react to any custom or built-in event."))
	descriptors.append(F.make_descriptor("Core", "OnEditorRun", "On Editor Run", ACEDescriptor.ACEType.TRIGGER, "", "_run", [], "Editor Tools", "On editor run (File > Run)")
		.described("Runs inside the editor while building, useful for tool scripts and live previews."))
	descriptors.append(F.make_descriptor("Core", "OnInput", "On Input", ACEDescriptor.ACEType.TRIGGER, "", "_input", [], "Input", "On input event")
		.described("Runs on every input event the node receives, for catching keys, mouse, or touch."))
	descriptors.append(F.make_descriptor("Core", "OnUnhandledInput", "On Unhandled Input", ACEDescriptor.ACEType.TRIGGER, "", "_unhandled_input", [], "Input", "On unhandled input event")
		.described("Runs on input no UI element consumed, ideal for gameplay controls that ignore menu clicks."))
	descriptors.append(F.make_descriptor("Core", "OnTimeout", "On Timeout", ACEDescriptor.ACEType.TRIGGER, "", "timeout", [], "Signals / Scene / Input", "On timeout", "Timer")
		.described("Runs when this Timer counts down to zero, e.g. ending a cooldown or spawn delay."))
	descriptors.append(F.make_descriptor("Core", "OnAnimationFinished", "On Animation Finished", ACEDescriptor.ACEType.TRIGGER, "", "animation_finished", [F.make_param("anim_name", "String", "", "Animation", "Name of the animation that finished.")], "Signals / Scene / Input", "On animation finished {anim_name}", "AnimationPlayer")
		.described("Runs when an animation finishes playing, e.g. chaining the next animation or action."))
	# Scene-tree membership signals (every Node) - REACT to a node entering/leaving instead of polling
	# IsInsideTree in On Process. Surface as SOURCE-node triggers (another node); for the host's OWN
	# first entry, On Ready is the idiomatic answer. tree_exiting fires while still in-tree, tree_exited
	# after removal.
	descriptors.append(F.make_descriptor("Core", "OnTreeEntered", "On Tree Entered", ACEDescriptor.ACEType.TRIGGER, "", "tree_entered", [], "Signals / Scene / Input", "On tree entered", "Node")
		.described("Runs when this node is added into the scene tree."))
	descriptors.append(F.make_descriptor("Core", "OnTreeExiting", "On Tree Exiting", ACEDescriptor.ACEType.TRIGGER, "", "tree_exiting", [], "Signals / Scene / Input", "On tree exiting (still in tree)", "Node")
		.described("Runs just before this node leaves the scene tree, a good spot for cleanup."))
	descriptors.append(F.make_descriptor("Core", "OnTreeExited", "On Tree Exited", ACEDescriptor.ACEType.TRIGGER, "", "tree_exited", [], "Signals / Scene / Input", "On tree exited (removed)", "Node")
		.described("Runs after this node has been removed from the scene tree."))
	descriptors.append(F.make_descriptor("Core", "OnRenamed", "On Renamed", ACEDescriptor.ACEType.TRIGGER, "", "renamed", [], "Signals / Scene / Input", "On renamed", "Node")
		.described("Runs when this node's name changes in the scene tree."))
	descriptors.append(F.make_descriptor("Core", "OnChildEnteredTree", "On Child Entered Tree", ACEDescriptor.ACEType.TRIGGER, "", "child_entered_tree", [F.make_param("node", "Node")], "Signals / Scene / Input", "On child entered {node}", "Node")
		.described("Runs when a child node is added beneath this one, e.g. reacting to spawned items."))

	# HIDDEN-OPTIMIZATION RULE: templates may use expert idioms a beginner wouldn't type
	# (&"name" StringName literals below skip the per-call String->StringName hash in hot
	# loops) - the picker shows friendly labels, the generated code stays readable, and
	# user fx/blocks are NEVER rewritten.
	# Input (action names come from the project's InputMap + the ui_* defaults)
	descriptors.append(F.make_descriptor("Core", "IsActionPressed", "Is Action Pressed", ACEDescriptor.ACEType.CONDITION, "Input.is_action_pressed(&{action})", "", [F.make_param("action", "String", F.default_input_action(), "Action", "Input action (from the InputMap).", "", F.input_action_options())], "Input", "{action} is pressed")
		.described("True while the named input action is held down, for continuous controls like running."))
	descriptors.append(F.make_descriptor("Core", "IsActionJustPressed", "On Action Just Pressed", ACEDescriptor.ACEType.CONDITION, "Input.is_action_just_pressed(&{action})", "", [F.make_param("action", "String", F.default_input_action(), "Action", "Input action (from the InputMap).", "", F.input_action_options())], "Input", "{action} just pressed")
		.described("True only on the frame the named input action was first pressed, for jumps or single taps."))
	descriptors.append(F.make_descriptor("Core", "IsActionJustReleased", "On Action Just Released", ACEDescriptor.ACEType.CONDITION, "Input.is_action_just_released(&{action})", "", [F.make_param("action", "String", F.default_input_action(), "Action", "Input action (from the InputMap).", "", F.input_action_options())], "Input", "{action} just released")
		.described("True only on the frame the named input action was let go, for charge-and-release moves."))
	# Conditions
	descriptors.append(F.make_descriptor("Core", "Always", "Always", ACEDescriptor.ACEType.CONDITION, "true", "", [], "General Conditions", "Always")
		.described("Always true, so its actions run every time the event is checked."))
	descriptors.append(F.make_descriptor("Core", "IsOnFloor", "Is On Floor", ACEDescriptor.ACEType.CONDITION, "{host.}is_on_floor()", "", [], "General Conditions", "Is on floor", "CharacterBody2D")
		.described("True when this 2D character body is standing on the ground, used to gate jumping."))
	descriptors.append(F.make_descriptor("Core", "HasGroupMember", "Has Group Member", ACEDescriptor.ACEType.CONDITION, "is_in_group(&{group})", "", [F.make_param("group", "String", "", "Group", "Group name to test.")], "General Conditions", "In group {group}")
		.described("True when this node belongs to the named group, for tagging and identifying objects."))
	descriptors.append(F.make_descriptor("Core", "CompareVar", "Compare Variable", ACEDescriptor.ACEType.CONDITION, "{var_name} {op} {value}", "", [F.make_param("var_name", "String", "var", "Variable", "Variable name to compare.", "variable_reference"), F.make_param("op", "String", "==", "Operator", "Comparison operator.", "", F.COMPARISON_OPERATORS), F.make_param("value", "String", "0", "Value", "Comparison value.", "expression")], "Variables", "{var_name} {op} {value}")
		.described("True when a variable compares against a value as you specify, for branching on game state."))
	descriptors.append(F.make_descriptor("Core", "IsTimerStopped", "Is Timer Stopped", ACEDescriptor.ACEType.CONDITION, "is_stopped()", "", [], "General Conditions", "Is timer stopped", "Timer")
		.described("True when the Timer is not currently running."))
	descriptors.append(F.make_descriptor("Core", "IsAnimationPlaying", "Is Animation Playing", ACEDescriptor.ACEType.CONDITION, "is_playing()", "", [], "General Conditions", "Is animation playing", "AnimationPlayer")
		.described("True while the AnimationPlayer is playing an animation."))

	# Actions
	descriptors.append(F.make_descriptor("Core", "SetVar", "Set Variable", ACEDescriptor.ACEType.ACTION, "{var_name} = {value}", "", [F.make_param("var_name", "String", "var", "Variable", "Variable name to set.", "variable_reference"), F.make_param("value", "String", "0", "Value", "Value to assign.", "expression")], "Variables", "Set variable {var_name} to {value}")
		.described("Sets a variable to a value you give, the basic way to store game state."))
	descriptors.append(F.make_descriptor("Core", "AddVar", "Add Variable", ACEDescriptor.ACEType.ACTION, "{var_name} += {amount}", "", [F.make_param("var_name", "String", "var", "Variable", "Variable name to increment.", "variable_reference"), F.make_param("amount", "String", "1", "Amount", "Amount to add.", "expression")], "Variables", "Add {amount} to {var_name}")
		.described("Adds an amount to a variable, e.g. increasing score or health."))
	# Compound-assign siblings to Add Variable (the -=/*=// gap that forced a raw block).
	descriptors.append(F.make_descriptor("Core", "SubtractVar", "Subtract From Variable", ACEDescriptor.ACEType.ACTION, "{var_name} -= {amount}", "", [F.make_param("var_name", "String", "var", "Variable", "Variable name to decrement.", "variable_reference"), F.make_param("amount", "String", "1", "Amount", "Amount to subtract.", "expression")], "Variables", "Subtract {amount} from {var_name}")
		.described("Subtracts an amount from a variable, e.g. spending money or taking damage."))
	descriptors.append(F.make_descriptor("Core", "MultiplyVar", "Multiply Variable", ACEDescriptor.ACEType.ACTION, "{var_name} *= {amount}", "", [F.make_param("var_name", "String", "var", "Variable", "Variable name to scale.", "variable_reference"), F.make_param("amount", "String", "2", "Factor", "Factor to multiply by.", "expression")], "Variables", "Multiply {var_name} by {amount}")
		.described("Multiplies a variable by a factor, e.g. scaling speed or applying a bonus."))
	descriptors.append(F.make_descriptor("Core", "DivideVar", "Divide Variable", ACEDescriptor.ACEType.ACTION, "{var_name} /= {amount}", "", [F.make_param("var_name", "String", "var", "Variable", "Variable name to divide.", "variable_reference"), F.make_param("amount", "String", "2", "Divisor", "What to divide by.", "expression")], "Variables", "Divide {var_name} by {amount}")
		.described("Divides a variable by a value, e.g. halving a stat."))
	descriptors.append(F.make_descriptor("Core", "PrintLog", "Print Log", ACEDescriptor.ACEType.ACTION, "print({message})", "", [F.make_param("message", "String", "\"TODO\"", "Message", "Message to print.")], "General Actions", "Print {message}")
		.described("Prints a message to the output console, useful for debugging and checking values."))
	descriptors.append(F.make_descriptor("Core", "QueueFree", "Queue Free", ACEDescriptor.ACEType.ACTION, "queue_free()", "", [], "General Actions", "Queue free")
		.described("Removes this node safely at the end of the frame, e.g. destroying a defeated enemy."))
	descriptors.append(F.make_descriptor("Core", "ReturnValue", "Return Value", ACEDescriptor.ACEType.ACTION, "return {value}", "", [F.make_param("value", "String", "0", "Value", "Expression to return (function return types are set on the function).", "expression")], "Functions", "Return {value}")
		.described("Returns a value from the current function back to whatever called it."))
	descriptors.append(F.make_descriptor("Core", "ReturnEarly", "Return (stop here)", ACEDescriptor.ACEType.ACTION, "return", "", [], "Functions", "Return")
		.described("Exits the current function immediately, skipping any remaining actions."))
	descriptors.append(F.make_descriptor("Core", "CallFunction", "Call Function", ACEDescriptor.ACEType.ACTION, "{function_name}({args})", "", [F.make_param("function_name", "String", "", "Function", "Name of the sheet function to call."), F.make_param("args", "String", "", "Arguments", "Comma-separated argument expressions.")], "Functions", "Call {function_name}({args})")
		.described("Calls one of your sheet functions with arguments, for reusing logic across events."))
	descriptors.append(F.make_descriptor("Core", "EmitSignal", "Emit Signal", ACEDescriptor.ACEType.ACTION, "{signal_name}.emit({args})", "", [F.make_param("signal_name", "String", "died", "Signal Name", "Signal to emit (a bare identifier, e.g. died).", "signal_reference"), F.make_param("args", "String", "", "Arguments", "Optional signal arguments (comma-separated).")], "Signals / Scene / Input", "Emit signal {signal_name}")
		.described("Fires a signal so other events or nodes can react, the way to broadcast custom events."))
	# Node2D actions
	descriptors.append(F.make_descriptor("Core", "SetPosition2D", "Set Position", ACEDescriptor.ACEType.ACTION, "position = {pos}", "", [F.make_param("pos", "String", "Vector2(0, 0)", "Position", "Target position as a Vector2 expression.", "expression")], "General Actions", "Set position to {pos}", "Node2D")
		.described("Places a 2D node at an exact position, e.g. teleporting or snapping to a spot."))
	descriptors.append(F.make_descriptor("Core", "MoveBy2D", "Move By", ACEDescriptor.ACEType.ACTION, "position += {offset}", "", [F.make_param("offset", "String", "Vector2(0, 0)", "Offset", "Amount to move by (Vector2 expression).", "expression")], "General Actions", "Move by {offset}", "Node2D")
		.described("Shifts a 2D node by an offset from where it is, for simple step-based movement."))
	descriptors.append(F.make_descriptor("Core", "SetRotationDeg", "Set Rotation (Degrees)", ACEDescriptor.ACEType.ACTION, "rotation_degrees = {degrees}", "", [F.make_param("degrees", "String", "0.0", "Degrees", "Rotation angle in degrees.", "expression")], "General Actions", "Set rotation to {degrees}°", "Node2D")
		.described("Sets a 2D node's rotation in degrees, e.g. aiming or facing a direction."))
	# CharacterBody2D actions
	descriptors.append(F.make_descriptor("Core", "MoveAndSlide", "Move And Slide", ACEDescriptor.ACEType.ACTION, "{host.}move_and_slide()", "", [], "General Actions", "Move and slide", "CharacterBody2D")
		.described("Moves the character body using its velocity and slides along walls; call each physics frame."))
	descriptors.append(F.make_descriptor("Core", "SetVelocity2D", "Set Velocity", ACEDescriptor.ACEType.ACTION, "{host.}velocity = {vel}", "", [F.make_param("vel", "String", "Vector2(0, 0)", "Velocity", "Velocity vector as a Vector2 expression.", "expression")], "General Actions", "Set velocity to {vel}", "CharacterBody2D")
		.described("Sets the character's full movement velocity to the Vector2 you provide."))
	# CharacterBody2D movement - component-wise velocity + gravity + acceleration: the vocabulary a
	# platformer/runner behaviour needs WITHOUT dropping to GDScript. The {host.} prefix targets the
	# parent host inside a behaviour and is empty on a plain CharacterBody2D sheet (byte-stable). The
	# accel param is named target_speed (not "target") so it never collides with the {target.} scope.
	descriptors.append(F.make_descriptor("Core", "SetVelocityX", "Set Velocity X", ACEDescriptor.ACEType.ACTION, "{host.}velocity.x = {x}", "", [F.make_param("x", "String", "0.0", "X", "New horizontal velocity (pixels/second).", "expression")], "Movement", "Set velocity X to {x}", "CharacterBody2D")
		.described("Sets only the horizontal speed of the character, leaving vertical motion untouched."))
	descriptors.append(F.make_descriptor("Core", "SetVelocityY", "Set Velocity Y", ACEDescriptor.ACEType.ACTION, "{host.}velocity.y = {y}", "", [F.make_param("y", "String", "0.0", "Y", "New vertical velocity (pixels/second; negative = up).", "expression")], "Movement", "Set velocity Y to {y}", "CharacterBody2D")
		.described("Sets only the vertical speed of the character (negative values move upward)."))
	descriptors.append(F.make_descriptor("Core", "AddVelocity", "Add To Velocity", ACEDescriptor.ACEType.ACTION, "{host.}velocity += {delta_v}", "", [F.make_param("delta_v", "String", "Vector2(0, 0)", "Amount", "Velocity to add, as a Vector2 expression.", "expression")], "Movement", "Add {delta_v} to velocity", "CharacterBody2D")
		.described("Adds a Vector2 to the current velocity, handy for nudges, knockback or boosts."))
	descriptors.append(F.make_descriptor("Core", "ApplyGravity", "Apply Gravity (with terminal velocity)", ACEDescriptor.ACEType.ACTION, "{host.}velocity.y = minf({host.}velocity.y + {gravity} * {delta_t}, {max_fall})", "", [F.make_param("gravity", "String", "980.0", "Gravity", "Downward acceleration (pixels per second, per second).", "expression"), F.make_param("max_fall", "String", "1000.0", "Max fall speed", "Terminal velocity - never fall faster than this.", "expression"), F.make_param("delta_t", "String", "delta", "Delta", "Frame time; defaults to `delta` (valid inside On Physics Process / On Process).", "expression")], "Movement", "Apply gravity {gravity} (max fall {max_fall})", "CharacterBody2D")
		.described("Pulls the character downward each frame but caps the maximum falling speed."))
	descriptors.append(F.make_descriptor("Core", "ApplyGravitySimple", "Apply Gravity", ACEDescriptor.ACEType.ACTION, "{host.}velocity.y += {gravity} * {delta_t}", "", [F.make_param("gravity", "String", "980.0", "Gravity", "Downward acceleration (pixels per second, per second).", "expression"), F.make_param("delta_t", "String", "delta", "Delta", "Frame time; defaults to `delta`.", "expression")], "Movement", "Apply gravity {gravity}", "CharacterBody2D")
		.described("Adds constant downward acceleration to the character each frame, making it fall."))
	descriptors.append(F.make_descriptor("Core", "AccelerateVelocityX", "Accelerate Velocity X Toward", ACEDescriptor.ACEType.ACTION, "{host.}velocity.x = move_toward({host.}velocity.x, {target_speed}, {rate} * {delta_t})", "", [F.make_param("target_speed", "String", "0.0", "Target speed", "Horizontal speed to ease toward (e.g. direction * move_speed).", "expression"), F.make_param("rate", "String", "1500.0", "Rate", "Max change per second (acceleration / deceleration).", "expression"), F.make_param("delta_t", "String", "delta", "Delta", "Frame time; defaults to `delta`.", "expression")], "Movement", "Accelerate velocity X toward {target_speed}", "CharacterBody2D")
		.described("Smoothly eases horizontal speed toward a target, giving gradual acceleration and braking."))
	descriptors.append(F.make_descriptor("Core", "AccelerateVelocityY", "Accelerate Velocity Y Toward", ACEDescriptor.ACEType.ACTION, "{host.}velocity.y = move_toward({host.}velocity.y, {target_speed}, {rate} * {delta_t})", "", [F.make_param("target_speed", "String", "0.0", "Target speed", "Vertical speed to ease toward.", "expression"), F.make_param("rate", "String", "1500.0", "Rate", "Max change per second.", "expression"), F.make_param("delta_t", "String", "delta", "Delta", "Frame time; defaults to `delta`.", "expression")], "Movement", "Accelerate velocity Y toward {target_speed}", "CharacterBody2D")
		.described("Smoothly eases vertical speed toward a target value over time."))
	descriptors.append(F.make_descriptor("Core", "GetVelocityX", "Velocity X", ACEDescriptor.ACEType.EXPRESSION, "{host.}velocity.x", "", [], "Movement", "velocity X", "CharacterBody2D")
		.described("Returns the character's current horizontal speed in pixels per second."))
	descriptors.append(F.make_descriptor("Core", "GetVelocityY", "Velocity Y", ACEDescriptor.ACEType.EXPRESSION, "{host.}velocity.y", "", [], "Movement", "velocity Y", "CharacterBody2D")
		.described("Returns the character's current vertical speed in pixels per second."))
	# RigidBody2D actions
	descriptors.append(F.make_descriptor("Core", "ApplyCentralImpulse", "Apply Central Impulse", ACEDescriptor.ACEType.ACTION, "apply_central_impulse({impulse})", "", [F.make_param("impulse", "String", "Vector2(0, 0)", "Impulse", "Impulse vector as a Vector2 expression.", "expression")], "General Actions", "Apply impulse {impulse}", "RigidBody2D")
		.described("Gives a rigid body an instant push in a direction, like a kick or explosion."))
	descriptors.append(F.make_descriptor("Core", "ApplyCentralForce2D", "Apply Central Force", ACEDescriptor.ACEType.ACTION, "apply_central_force({force})", "", [F.make_param("force", "String", "Vector2(0, 0)", "Force", "Force vector applied this physics frame (use under On Physics Process).", "expression")], "General Actions", "Apply force {force}", "RigidBody2D")
		.described("Applies a continuous push to a rigid body each physics frame, like steady thrust."))
	descriptors.append(F.make_descriptor("Core", "ApplyTorqueImpulse2D", "Apply Torque Impulse", ACEDescriptor.ACEType.ACTION, "apply_torque_impulse({torque})", "", [F.make_param("torque", "String", "0.0", "Torque", "Angular impulse (spin).", "expression")], "General Actions", "Apply torque impulse {torque}", "RigidBody2D")
		.described("Gives a rigid body an instant spin, making it start rotating."))
	# Timer actions
	descriptors.append(F.make_descriptor("Core", "StartTimer", "Start Timer", ACEDescriptor.ACEType.ACTION, "start({time})", "", [F.make_param("time", "String", "-1", "Duration", "Duration in seconds (-1 uses the Timer's wait_time).", "expression")], "General Actions", "Start timer ({time}s)", "Timer")
		.described("Starts a Timer node counting down, optionally with a custom duration."))
	descriptors.append(F.make_descriptor("Core", "StopTimer", "Stop Timer", ACEDescriptor.ACEType.ACTION, "stop()", "", [], "General Actions", "Stop timer", "Timer")
		.described("Stops a running Timer so it no longer counts down or fires."))
	# AnimationPlayer actions
	descriptors.append(F.make_descriptor("Core", "PlayAnimation", "Play Animation", ACEDescriptor.ACEType.ACTION, "play(&{anim_name})", "", [F.make_param("anim_name", "String", "\"idle\"", "Animation", "Name of the animation to play.", "animation_reference")], "General Actions", "Play animation {anim_name}", "AnimationPlayer")
		.described("Plays a named animation on an AnimationPlayer, e.g. for walking or attacking."))
	descriptors.append(F.make_descriptor("Core", "StopAnimation", "Stop Animation", ACEDescriptor.ACEType.ACTION, "stop()", "", [], "General Actions", "Stop animation", "AnimationPlayer")
		.described("Stops the currently playing animation on the AnimationPlayer."))

	# ── 2D spatial queries (mirror of the 3D raycast block - shooting, interaction, AI
	# vision, ground-snap. A RayCast2D node set + host-agnostic Node2D world queries via
	# intersect_ray, single-line per the parity contract). ──
	descriptors.append(F.make_descriptor("Core", "RayCast2DIsColliding", "RayCast Is Colliding (2D)", ACEDescriptor.ACEType.CONDITION, "is_colliding()", "", [], "Raycast 2D", "RayCast is colliding", "RayCast2D")
		.described("True when the RayCast2D is currently hitting something in its path."))
	descriptors.append(F.make_descriptor("Core", "RayCast2DForceUpdate", "Force RayCast Update (2D)", ACEDescriptor.ACEType.ACTION, "force_raycast_update()", "", [], "Raycast 2D", "Force raycast update", "RayCast2D")
		.described("Immediately re-checks the raycast this frame instead of waiting for physics."))
	descriptors.append(F.make_descriptor("Core", "RayCast2DGetCollider", "RayCast Collider (2D)", ACEDescriptor.ACEType.EXPRESSION, "get_collider()", "", [], "Raycast 2D", "raycast collider", "RayCast2D")
		.described("Returns the node the raycast is currently hitting, or nothing if clear."))
	descriptors.append(F.make_descriptor("Core", "RayCast2DGetPoint", "RayCast Hit Point (2D)", ACEDescriptor.ACEType.EXPRESSION, "get_collision_point()", "", [], "Raycast 2D", "raycast hit point", "RayCast2D")
		.described("Returns the world point where the raycast hit something."))
	descriptors.append(F.make_descriptor("Core", "RayCast2DGetNormal", "RayCast Hit Normal (2D)", ACEDescriptor.ACEType.EXPRESSION, "get_collision_normal()", "", [], "Raycast 2D", "raycast hit normal", "RayCast2D")
		.described("Returns the surface direction (normal) at the raycast's hit point."))
	descriptors.append(F.make_descriptor("Core", "WorldRaycastHit2D", "World Raycast Hits? (2D)", ACEDescriptor.ACEType.CONDITION, "not get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create({from}, {to})).is_empty()", "", [F.make_param("from", "String", "Vector2(0, 0)", "From", "Ray start (Vector2 expression).", "expression"), F.make_param("to", "String", "Vector2(0, 0)", "To", "Ray end (Vector2 expression).", "expression")], "Raycast 2D", "world raycast {from} -> {to} hits", "Node2D")
		.described("True when a ray drawn between two points hits any physics object."))
	descriptors.append(F.make_descriptor("Core", "WorldRaycastPoint2D", "World Raycast Point (2D)", ACEDescriptor.ACEType.EXPRESSION, "get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create({from}, {to})).get(\"position\", Vector2.ZERO)", "", [F.make_param("from", "String", "Vector2(0, 0)", "From", "Ray start (Vector2 expression).", "expression"), F.make_param("to", "String", "Vector2(0, 0)", "To", "Ray end (Vector2 expression).", "expression")], "Raycast 2D", "world raycast point {from} -> {to}", "Node2D")
		.described("Returns where a one-shot ray between two points strikes a surface."))
	descriptors.append(F.make_descriptor("Core", "WorldRaycastCollider2D", "World Raycast Collider (2D)", ACEDescriptor.ACEType.EXPRESSION, "get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create({from}, {to})).get(\"collider\", null)", "", [F.make_param("from", "String", "Vector2(0, 0)", "From", "Ray start (Vector2 expression).", "expression"), F.make_param("to", "String", "Vector2(0, 0)", "To", "Ray end (Vector2 expression).", "expression")], "Raycast 2D", "world raycast collider {from} -> {to}", "Node2D")
		.described("Returns the object a one-shot ray between two points hits, or nothing."))

	# ── 2D overlap queries (one-shot "what is HERE right now" - no Area2D node needed).
	# Multi-statement templates bake a per-row {uid} local; results land in a variable,
	# so For Each picks over them and Expression Is True gates on `not X.is_empty()`. ──
	descriptors.append(F.make_descriptor("Core", "QueryBodiesAtPoint2D", "Query Bodies At Point (2D)", ACEDescriptor.ACEType.ACTION, "var __pq_{uid} := PhysicsPointQueryParameters2D.new()\n__pq_{uid}.position = {point}\n{into} = []\nfor __hit_{uid} in get_world_2d().direct_space_state.intersect_point(__pq_{uid}, {max_results}):\n\t{into}.append(__hit_{uid}.get(\"collider\"))", "", [F.make_param("into", "String", "data", "Into Variable", "Variable receiving the Array of overlapping objects.", "variable_reference"), F.make_param("point", "String", "Vector2(0, 0)", "Point", "World position to test (Vector2 expression).", "expression"), F.make_param("max_results", "String", "32", "Max Results", "Most objects to collect.", "expression")], "Overlap 2D", "query bodies at {point} into {into}", "Node2D")
		.described("Collects every physics object at a world point into a variable - like tapping the world with a finger."))
	descriptors.append(F.make_descriptor("Core", "QueryBodiesInCircle2D", "Query Bodies In Circle (2D)", ACEDescriptor.ACEType.ACTION, "var __cs_{uid} := CircleShape2D.new()\n__cs_{uid}.radius = {radius}\nvar __sq_{uid} := PhysicsShapeQueryParameters2D.new()\n__sq_{uid}.shape = __cs_{uid}\n__sq_{uid}.transform = Transform2D(0.0, {center})\n{into} = []\nfor __hit_{uid} in get_world_2d().direct_space_state.intersect_shape(__sq_{uid}, {max_results}):\n\t{into}.append(__hit_{uid}.get(\"collider\"))", "", [F.make_param("into", "String", "data", "Into Variable", "Variable receiving the Array of overlapping objects.", "variable_reference"), F.make_param("center", "String", "global_position", "Center", "Circle center in world space (Vector2 expression).", "expression"), F.make_param("radius", "String", "64.0", "Radius", "Circle radius in pixels.", "expression"), F.make_param("max_results", "String", "32", "Max Results", "Most objects to collect.", "expression")], "Overlap 2D", "query bodies within {radius}px of {center} into {into}", "Node2D")
		.described("Collects every physics object inside a circle into a variable - explosion radii, pickup magnets, proximity checks."))
	descriptors.append(F.make_descriptor("Core", "QueryBodiesInRect2D", "Query Bodies In Rectangle (2D)", ACEDescriptor.ACEType.ACTION, "var __rs_{uid} := RectangleShape2D.new()\n__rs_{uid}.size = {size}\nvar __sq_{uid} := PhysicsShapeQueryParameters2D.new()\n__sq_{uid}.shape = __rs_{uid}\n__sq_{uid}.transform = Transform2D(0.0, {center})\n{into} = []\nfor __hit_{uid} in get_world_2d().direct_space_state.intersect_shape(__sq_{uid}, {max_results}):\n\t{into}.append(__hit_{uid}.get(\"collider\"))", "", [F.make_param("into", "String", "data", "Into Variable", "Variable receiving the Array of overlapping objects.", "variable_reference"), F.make_param("center", "String", "global_position", "Center", "Rectangle center in world space (Vector2 expression).", "expression"), F.make_param("size", "String", "Vector2(128, 64)", "Size", "Rectangle width and height (Vector2 expression).", "expression"), F.make_param("max_results", "String", "32", "Max Results", "Most objects to collect.", "expression")], "Overlap 2D", "query bodies in {size} rect at {center} into {into}", "Node2D")
		.described("Collects every physics object inside a rectangle into a variable - selection boxes, damage zones, room checks."))

	# ── Project utility ACEs (settings / window / debug / time / reparent) ──
	# ── Settings: a ConfigFile in user:// (the standard persistent-settings store) ──
	# Multi-statement templates bake a per-row {uid} local so two in one event don't collide.
	descriptors.append(F.make_descriptor("Core", "SaveSetting", "Save Setting", ACEDescriptor.ACEType.ACTION, "var __cfg_{uid} = ConfigFile.new()\n__cfg_{uid}.load({path})\n__cfg_{uid}.set_value({section}, {key}, {value})\n__cfg_{uid}.save({path})", "", [F.make_param("path", "String", "\"user://settings.cfg\"", "File", "Config file path (user:// persists across runs).", "expression"), F.make_param("section", "String", "\"audio\"", "Section", "Section name.", "expression"), F.make_param("key", "String", "\"volume\"", "Key", "Setting key.", "expression"), F.make_param("value", "String", "1.0", "Value", "Value to store (any type).", "expression")], "Utility: Settings", "save {section}/{key} = {value}")
		.described("Writes a value into a config file on disk so it persists between play sessions."))
	descriptors.append(F.make_descriptor("Core", "LoadSettingInto", "Load Setting Into Variable", ACEDescriptor.ACEType.ACTION, "var __cfg_{uid} = ConfigFile.new()\n__cfg_{uid}.load({path})\n{var_name} = __cfg_{uid}.get_value({section}, {key}, {default})", "", [F.make_param("var_name", "String", "data", "Into Variable", "Variable receiving the loaded value.", "variable_reference"), F.make_param("path", "String", "\"user://settings.cfg\"", "File", "Config file path.", "expression"), F.make_param("section", "String", "\"audio\"", "Section", "Section name.", "expression"), F.make_param("key", "String", "\"volume\"", "Key", "Setting key.", "expression"), F.make_param("default", "String", "1.0", "Default", "Fallback when the key is missing.", "expression")], "Utility: Settings", "load {section}/{key} into {var_name}")
		.described("Reads a saved value from a config file into a variable, with a fallback default."))

	# ── Window / screen / mouse / clipboard ──
	descriptors.append(F.make_descriptor("Core", "SetWindowTitle", "Set Window Title", ACEDescriptor.ACEType.ACTION, "get_window().title = {title}", "", [F.make_param("title", "String", "\"My Game\"", "Title", "Window title bar text.", "expression")], "Utility: Window", "set window title to {title}")
		.described("Changes the text shown in the game window's title bar."))
	descriptors.append(F.make_descriptor("Core", "GetWindowSize", "Window Size", ACEDescriptor.ACEType.EXPRESSION, "get_window().size", "", [], "Utility: Window", "window size")
		.described("Returns the game window's current size in pixels."))
	descriptors.append(F.make_descriptor("Core", "GetScreenSize", "Screen Size", ACEDescriptor.ACEType.EXPRESSION, "DisplayServer.screen_get_size()", "", [], "Utility: Window", "screen size")
		.described("Returns the size of the player's monitor in pixels."))
	# (Set Mouse Mode lives in device_aces under "Mouse" - not duplicated here.)
	descriptors.append(F.make_descriptor("Core", "SetClipboard", "Set Clipboard Text", ACEDescriptor.ACEType.ACTION, "DisplayServer.clipboard_set({text})", "", [F.make_param("text", "String", "\"\"", "Text", "Text to copy to the OS clipboard.", "expression")], "Utility: Window", "copy {text} to clipboard")
		.described("Copies text to the operating system clipboard for pasting elsewhere."))
	descriptors.append(F.make_descriptor("Core", "GetClipboard", "Clipboard Text", ACEDescriptor.ACEType.EXPRESSION, "DisplayServer.clipboard_get()", "", [], "Utility: Window", "clipboard text")
		.described("Returns whatever text is currently on the system clipboard."))

	# ── Debug / profiling (read live engine performance monitors) ──
	descriptors.append(F.make_descriptor("Core", "GetPerfMonitor", "Performance Monitor", ACEDescriptor.ACEType.EXPRESSION, "Performance.get_monitor({monitor})", "", [F.make_param("monitor", "String", "Performance.TIME_FPS", "Monitor", "Which engine monitor to read.", "", ["Performance.TIME_FPS", "Performance.TIME_PROCESS", "Performance.TIME_PHYSICS_PROCESS", "Performance.OBJECT_COUNT", "Performance.OBJECT_NODE_COUNT", "Performance.RENDER_TOTAL_OBJECTS_IN_FRAME", "Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME", "Performance.PHYSICS_2D_ACTIVE_OBJECTS"])], "Utility: Debug", "monitor {monitor}")
		.described("Returns a live engine performance reading, like FPS or memory, for debugging."))
	descriptors.append(F.make_descriptor("Core", "GetStaticMemory", "Static Memory (bytes)", ACEDescriptor.ACEType.EXPRESSION, "OS.get_static_memory_usage()", "", [], "Utility: Debug", "static memory")
		.described("Returns how much memory the game is currently using, in bytes."))

	# ── Time formatting (turn seconds into clock text; read the system clock) ──
	descriptors.append(F.make_descriptor("Core", "FormatTime", "Format Time (mm:ss)", ACEDescriptor.ACEType.EXPRESSION, "(\"%02d:%02d\" % [int({seconds}) / 60, int({seconds}) % 60])", "", [F.make_param("seconds", "String", "0.0", "Seconds", "Total seconds to format.", "expression")], "Utility: Time", "format {seconds} as mm:ss")
		.described("Turns a number of seconds into a tidy mm:ss string for timers and clocks."))
	descriptors.append(F.make_descriptor("Core", "GetSystemTime", "System Time String", ACEDescriptor.ACEType.EXPRESSION, "Time.get_time_string_from_system()", "", [], "Utility: Time", "system time string")
		.described("Returns the player's current clock time as a text string."))
	descriptors.append(F.make_descriptor("Core", "GetSystemDate", "System Date String", ACEDescriptor.ACEType.EXPRESSION, "Time.get_date_string_from_system()", "", [], "Utility: Time", "system date string")
		.described("Returns the player's current calendar date as a text string."))

	# ── Nodes ──
	descriptors.append(F.make_descriptor("Core", "ReparentNode", "Reparent To", ACEDescriptor.ACEType.ACTION, "reparent({new_parent})", "", [F.make_param("new_parent", "String", "get_tree().current_scene", "New Parent", "Node to become the new parent (keeps global transform).", "expression")], "Utility: Nodes", "reparent to {new_parent}")
		.described("Moves this node under a new parent while keeping its on-screen position."))

	return descriptors
