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
	descriptors.append(F.trig("OnReady", "On Ready", "ready", "Run Context", "Run on ready", "Runs once when this node first enters the scene, ideal for setup and initial values."))
	descriptors.append(F.trig("OnProcess", "Every Frame", "_process", "Run Context", "Run every tick", "Runs every rendered frame, perfect for continuous movement, timers, or polling input."))
	descriptors.append(F.trig("OnPhysicsProcess", "Every Physics Tick", "_physics_process", "Run Context", "Run every physics tick", "Runs every fixed physics step, the right place for physics-based movement and forces."))
	descriptors.append(F.trig("OnPostTick", "After Every Frame (post-tick)", "process_frame", "Run Context", "Run after every frame", "Runs once AFTER every node has processed this frame - for logic that must come last, like a camera that follows after movement, or end-of-frame cleanup.", "Node"))
	descriptors.append(F.trig("OnPhysicsPostTick", "After Every Physics Tick", "physics_frame", "Run Context", "Run after every physics tick", "Runs once AFTER every node has finished its physics step this tick - the physics sibling of post-tick.", "Node"))
	descriptors.append(F.trig("OnEnterTree", "On Created", "_enter_tree", "Run Context", "Run when created", "Runs the moment this object is added to the scene - before its children exist, which is what makes it earlier than On Ready.", "Node"))
	descriptors.append(F.trig("OnExitTree", "On Destroyed", "_exit_tree", "Run Context", "Run when destroyed", "Runs when this object leaves the scene - the place to let go of what it was holding, save its state, or tell others it is gone.", "Node"))
	descriptors.append(F.trig("OnDraw", "On Draw", "_draw", "Run Context", "Run when drawing", "Runs when this object is asked to paint itself - the only place the drawing actions may be used. Ask for a repaint with Queue Redraw.", "CanvasItem"))
	descriptors.append(F.trig("OnControlInput", "On Input On This Element", "_gui_input", "Signals / Scene / Input", "On input on this element", "Runs when input lands on this UI element - a click, a drag or a key while it has focus. Ends with Consume Input when nothing behind it should also react.", "Control"))
	descriptors.append(F.trig("OnCloseRequested", "On Close Requested", "close_requested", "Signals / Scene / Input", "On window close requested", "Runs when the player clicks the window's close button (X) or asks to quit - the place to save progress or pop a confirm dialog before exiting.", "Node"))
	descriptors.append(F.trig("OnSomethingWentWrong", "On Something Went Wrong", "something_went_wrong", "Run Context", "On something went wrong ([b]report[/b])", "Runs when a script error happens while the game is running - in a build a player is holding, not only in the editor. The report says what failed and where. Save it to a file, show a \"please send this\" dialog, or just skip the broken thing and keep playing.").param("report", "", "", "What failed and where, as the engine said it - the message, the script and the line. Filled in for you when the trigger fires."))
	descriptors.append(F.trig("OnBodyEntered", "On Body Entered", "body_entered", "Signals / Scene / Input", "On body entered {body}", "Runs when a physics body enters this 2D Area, e.g. detecting the player walking into a trigger.", "Area2D").param_typed("Node", "body", "", "", "The body that entered this area. Filled in for you when the trigger fires."))
	descriptors.append(F.trig("OnAreaEntered", "On Area Entered", "area_entered", "Signals / Scene / Input", "On area entered {area}", "Runs when another 2D Area overlaps this one, e.g. a hitbox touching a hurtbox.", "Area2D").param_typed("Area2D", "area", "", "", "The area that entered this one. Filled in for you when the trigger fires."))
	descriptors.append(F.trig("OnBodyExited", "On Body Exited", "body_exited", "Signals / Scene / Input", "On body exited {body}", "Runs when a physics body leaves this 2D Area, e.g. the player stepping out of a zone.", "Area2D").param_typed("Node", "body", "", "", "The body that left this area. Filled in for you when the trigger fires."))
	descriptors.append(F.trig("OnAreaExited", "On Area Exited", "area_exited", "Signals / Scene / Input", "On area exited {area}", "Runs when another 2D Area stops overlapping this one.", "Area2D").param_typed("Area2D", "area", "", "", "The area that left this one. Filled in for you when the trigger fires."))
	descriptors.append(F.trig("OnSignal", "On Signal", "", "Signals / Scene / Input", "On signal {signal_name}", "Runs whenever the named signal fires, letting you react to any custom or built-in event.").param("signal_name", "eventforge_signal", "Signal Name", "Signal to listen for.", "signal_reference").param("args", "", "Arguments", "Optional - the signal's argument signature so this event receives its parameters, e.g. \"amount: int\" or \"x: float, y: float\". Leave empty for a signal with no arguments.", "expression"))
	descriptors.append(F.trig("OnEditorRun", "On Editor Run", "_run", "Editor Tools", "On editor run (File > Run)", "Runs inside the editor while building, useful for tool scripts and live previews."))
	descriptors.append(F.trig("OnInput", "On Input", "_input", "Input", "On input event", "Runs on every input event the node receives, for catching keys, mouse, or touch."))
	descriptors.append(F.trig("OnUnhandledInput", "On Unhandled Input", "_unhandled_input", "Input", "On unhandled input event", "Runs on input no UI element consumed, ideal for gameplay controls that ignore menu clicks."))
	descriptors.append(F.trig("OnUnhandledKeyInput", "On Unhandled Key Input", "_unhandled_key_input", "Input", "On unhandled key input", "Runs on keyboard input no UI element consumed - the keys-only sibling of On Unhandled Input, so mouse and gamepad traffic never wakes it."))
	descriptors.append(F.trig("OnInputEvent", "On Input On This Object", "_input_event", "Input", "On input on this object", "Runs when input lands on this object's own collision shape - a click, a drag or a touch that hit it rather than the world behind it.", "CollisionObject2D"))
	descriptors.append(F.trig("OnTimeout", "On Timeout", "timeout", "Signals / Scene / Input", "On timeout", "Runs when this Timer counts down to zero, e.g. ending a cooldown or spawn delay.", "Timer"))
	descriptors.append(F.trig("OnAnimationFinished", "On Animation Finished", "animation_finished", "Signals / Scene / Input", "On animation finished {anim_name}", "Runs when an animation finishes playing, e.g. chaining the next animation or action.", "AnimationPlayer").param("anim_name", "", "Animation", "Name of the animation that finished."))
	# Scene-tree membership signals (every Node) - REACT to a node entering/leaving instead of polling
	# IsInsideTree in On Process. Surface as SOURCE-node triggers (another node); for the host's OWN
	# first entry, On Ready is the idiomatic answer. tree_exiting fires while still in-tree, tree_exited
	# after removal.
	descriptors.append(F.trig("OnTreeEntered", "On Tree Entered", "tree_entered", "Signals / Scene / Input", "On tree entered", "Runs when this node is added into the scene tree.", "Node"))
	descriptors.append(F.trig("OnTreeExiting", "On Tree Exiting", "tree_exiting", "Signals / Scene / Input", "On tree exiting (still in tree)", "Runs just before this node leaves the scene tree, a good spot for cleanup.", "Node"))
	descriptors.append(F.trig("OnTreeExited", "On Tree Exited", "tree_exited", "Signals / Scene / Input", "On tree exited (removed)", "Runs after this node has been removed from the scene tree.", "Node"))
	descriptors.append(F.trig("OnRenamed", "On Renamed", "renamed", "Signals / Scene / Input", "On renamed", "Runs when this node's name changes in the scene tree.", "Node"))
	# The two ends of "something joined / left this object" - the pair a spawn counter, an
	# inventory panel and a socket check are all written from. The words are the hierarchy's own
	# ("added" / "leaving"), not the signal names, because the signal names are what a reader has to
	# translate every time they meet them.
	descriptors.append(F.trig("OnChildEnteredTree", "On Child Added", "child_entered_tree", "Signals / Scene / Input", "On child added [i]{node}[/i]", "Runs when a child node is added beneath this one, e.g. reacting to spawned items.", "Node").param_typed("Node", "node", "", "", "The child that was just added under this node. Filled in for you when the trigger fires."))
	descriptors.append(F.trig("OnChildExitingTree", "On Child Leaving", "child_exiting_tree", "Signals / Scene / Input", "On child leaving [i]{node}[/i]", "Runs just before a child node leaves this one - while it is still there to be read, so a count, a total or a panel can be brought up to date with it.", "Node").param_typed("Node", "node", "", "", "The child that is leaving this node. Filled in for you when the trigger fires."))

	# HIDDEN-OPTIMIZATION RULE: templates may use expert idioms a beginner wouldn't type
	# (&"name" StringName literals below skip the per-call String->StringName hash in hot
	# loops) - the picker shows friendly labels, the generated code stays readable, and
	# user fx/blocks are NEVER rewritten.
	# Input (action names come from the project's InputMap + the ui_* defaults)
	descriptors.append(F.cond("IsActionPressed", "Is Action Pressed", "Input.is_action_pressed(&{action})", "Input", "{action} is pressed", "True while the named input action is held down, for continuous controls like running.").param_built(F.make_param("action", "String", F.default_input_action(), "Action", "Input action (from the InputMap).", "input_action", F.input_action_options())))
	descriptors.append(F.cond("IsActionJustPressed", "On Action Just Pressed", "Input.is_action_just_pressed(&{action})", "Input", "{action} just pressed", "True only on the frame the named input action was first pressed, for jumps or single taps.").param_built(F.make_param("action", "String", F.default_input_action(), "Action", "Input action (from the InputMap).", "input_action", F.input_action_options())))
	descriptors.append(F.cond("IsActionJustReleased", "On Action Just Released", "Input.is_action_just_released(&{action})", "Input", "{action} just released", "True only on the frame the named input action was let go, for charge-and-release moves.").param_built(F.make_param("action", "String", F.default_input_action(), "Action", "Input action (from the InputMap).", "input_action", F.input_action_options())))
	# Conditions
	descriptors.append(F.cond("Always", "Always", "true", "General Conditions", "Always", "Always true, so its actions run every time the event is checked."))
	descriptors.append(F.cond("IsOnFloor", "Is On Floor", "{host.}is_on_floor()", "General Conditions", "Is on floor", "True when this 2D character body is standing on the ground, used to gate jumping.", "CharacterBody2D"))
	descriptors.append(F.cond("HasGroupMember", "Has Group Member", "is_in_group(&{group})", "General Conditions", "In group {group}", "True when this node belongs to the named group, for tagging and identifying objects.").param("group", "", "Group", "Group name to test.", "group_reference"))
	descriptors.append(F.cond("CompareVar", "Compare variable", "{var_name} {op} {value}", "Variables", "{var_name} {op} {value}", "True when a variable compares against a value as you specify, for branching on game state.").param("var_name", "var", "Variable", "Variable name to compare.", "variable_reference").param_choice("op", "==", "Operator", "Comparison operator.", F.COMPARISON_OPTIONS).param("value", "0", "Value", "Comparison value.", "expression"))
	# The boolean family's missing half. "Set boolean" / "Toggle boolean" / "Is boolean set" is
	# the trio anyone who has driven an event sheet reaches for, and only the middle one existed:
	# testing a flag meant Compare variable with `== true` beside it, which says the same thing in
	# three more words. The template is the bare name, because a boolean IS the question.
	descriptors.append(F.cond("IsBoolSet", "Is boolean set", "{var_name}", "Variables", "Is {var_name}", "True while a boolean variable is true, the plain way to ask whether a flag is set.").param("var_name", "enabled_flag", "Variable", "Boolean variable to test.", "variable_reference"))
	descriptors.append(F.cond("IsTimerStopped", "Is Timer Stopped", "is_stopped()", "General Conditions", "Is timer stopped", "True when the Timer is not currently running.", "Timer"))
	descriptors.append(F.cond("IsAnimationPlaying", "Is Animation Playing", "is_playing()", "General Conditions", "Is animation playing", "True while the AnimationPlayer is playing an animation.", "AnimationPlayer"))

	# Actions
	descriptors.append(F.act("SetVar", "Set value", "{var_name} = {value}", "Variables", "Set {var_name} to {value}", "Sets a variable to a value you give, the basic way to store game state.").param("var_name", "var", "Variable", "Variable name to set.", "variable_reference").param("value", "0", "Value", "Value to assign.", "expression"))
	# Set value with the two answers a boolean has already in the list, so a flag is set by
	# picking a word rather than by typing one. Same template as Set value, deliberately - the code
	# is identical and only the ROW is clearer, which is why it stays out of the reverse index
	# (ace_lifter.REVERSE_LIFT_EXCLUDED_ACE_IDS): `x = y` must keep lifting back to Set value.
	descriptors.append(F.act("SetBool", "Set boolean", "{var_name} = {value}", "Variables", "Set boolean {var_name} to {value}", "Sets a boolean variable to true or false, picked from the list instead of typed.").param("var_name", "enabled_flag", "Variable", "Boolean variable to set.", "variable_reference").param_choice("value", "true", "Value", "true or false.", [{"key": "true", "label": "true"}, {"key": "false", "label": "false"}]))
	descriptors.append(F.act("AddVar", "Add to", "{var_name} += {amount}", "Variables", "Add {amount} to {var_name}", "Adds an amount to a variable, e.g. increasing score or health.").param("var_name", "var", "Variable", "Variable name to increment.", "variable_reference").param("amount", "1", "Amount", "Amount to add.", "expression"))
	# Compound-assign siblings to Add Variable (the -=/*=// gap that forced a raw block).
	descriptors.append(F.act("SubtractVar", "Subtract from", "{var_name} -= {amount}", "Variables", "Subtract {amount} from {var_name}", "Subtracts an amount from a variable, e.g. spending money or taking damage.").param("var_name", "var", "Variable", "Variable name to decrement.", "variable_reference").param("amount", "1", "Amount", "Amount to subtract.", "expression"))
	descriptors.append(F.act("MultiplyVar", "Multiply Variable", "{var_name} *= {amount}", "Variables", "Multiply {var_name} by {amount}", "Multiplies a variable by a factor, e.g. scaling speed or applying a bonus.").param("var_name", "var", "Variable", "Variable name to scale.", "variable_reference").param("amount", "2", "Factor", "Factor to multiply by.", "expression"))
	descriptors.append(F.act("DivideVar", "Divide Variable", "{var_name} /= {amount}", "Variables", "Divide {var_name} by {amount}", "Divides a variable by a value, e.g. halving a stat.").param("var_name", "var", "Variable", "Variable name to divide.", "variable_reference").param("amount", "2", "Divisor", "What to divide by.", "expression"))
	# The last compound-assign sibling (%=), so `health %= 3` reads as a row instead of a raw block.
	descriptors.append(F.act("ModuloVar", "Modulo Variable", "{var_name} %= {amount}", "Variables", "Set {var_name} to its remainder over {amount}", "Replaces a variable with its remainder over a value, e.g. cycling an index that must stay in range.").param("var_name", "var", "Variable", "Variable name to wrap.", "variable_reference").param("amount", "2", "Divisor", "Take the remainder against this.", "expression"))
	descriptors.append(F.act("PrintLog", "Print Log", "print({message})", "General Actions", "Print {message}", "Prints a message to the output console, useful for debugging and checking values.").param("message", "\"TODO\"", "Message", "Message to print."))
	descriptors.append(F.act("QueueFree", "Queue Free", "queue_free()", "General Actions", "Queue free", "Removes this node safely at the end of the frame, e.g. destroying a defeated enemy."))
	descriptors.append(F.act("ReturnValue", "Return Value", "return {value}", "Functions", "Return {value}", "Returns a value from the current function back to whatever called it.").param("value", "0", "Value", "Expression to return (function return types are set on the function).", "expression"))
	descriptors.append(F.act("ReturnEarly", "Return (stop here)", "return", "Functions", "Return", "Exits the current function immediately, skipping any remaining actions."))
	descriptors.append(F.act("CallFunction", "Call Function", "{function_name}({args})", "Functions", "Call {function_name}({args})", "Calls one of your sheet functions with arguments, for reusing logic across events.").param("function_name", "", "Function", "Name of the sheet function to call.").param("args", "", "Arguments", "Comma-separated argument expressions."))
	descriptors.append(F.act("EmitSignal", "Emit Signal", "{signal_name}.emit({args})", "Signals / Scene / Input", "Emit signal {signal_name}", "Fires a signal so other events or nodes can react, the way to broadcast custom events.").param("signal_name", "died", "Signal Name", "Signal to emit (a bare identifier, e.g. died).", "signal_reference").param("args", "", "Arguments", "Optional signal arguments (comma-separated)."))
	# Node2D actions
	descriptors.append(F.act("SetPosition2D", "Set Position", "position = {pos}", "General Actions", "Set position to {pos}", "Places a 2D node at an exact position, e.g. teleporting or snapping to a spot.", "Node2D").param("pos", "Vector2(0, 0)", "Position", "Target position as a Vector2 expression.", "expression"))
	descriptors.append(F.act("MoveBy2D", "Move By", "position += {offset}", "General Actions", "Move by {offset}", "Shifts a 2D node by an offset from where it is, for simple step-based movement.", "Node2D").param("offset", "Vector2(0, 0)", "Offset", "Amount to move by (Vector2 expression).", "expression"))
	descriptors.append(F.act("SetRotationDeg", "Set Rotation (Degrees)", "rotation_degrees = {degrees}", "General Actions", "Set rotation to {degrees}°", "Sets a 2D node's rotation in degrees, e.g. aiming or facing a direction.", "Node2D").param("degrees", "0.0", "Degrees", "Rotation angle in degrees.", "expression"))
	# CharacterBody2D actions
	descriptors.append(F.act("MoveAndSlide", "Move And Slide", "{host.}move_and_slide()", "General Actions", "Move (and slide along what it hits)", "Moves the character body using its velocity and slides along walls; call each physics frame.", "CharacterBody2D"))
	descriptors.append(F.act("SetVelocity2D", "Set Velocity", "{host.}velocity = {vel}", "General Actions", "Set velocity to {vel}", "Sets the character's full movement velocity to the Vector2 you provide.", "CharacterBody2D").param("vel", "Vector2(0, 0)", "Velocity", "Velocity vector as a Vector2 expression.", "expression"))
	# CharacterBody2D movement - component-wise velocity + gravity + acceleration: the vocabulary a
	# platformer/runner behaviour needs WITHOUT dropping to GDScript. The {host.} prefix targets the
	# parent host inside a behaviour and is empty on a plain CharacterBody2D sheet (byte-stable). The
	# accel param is named target_speed (not "target") so it never collides with the {target.} scope.
	descriptors.append(F.act("SetVelocityX", "Set Velocity X", "{host.}velocity.x = {x}", "Movement", "Set velocity X to {x}", "Sets only the horizontal speed of the character, leaving vertical motion untouched.", "CharacterBody2D").param("x", "0.0", "X", "New horizontal velocity (pixels/second).", "expression"))
	descriptors.append(F.act("SetVelocityY", "Set Velocity Y", "{host.}velocity.y = {y}", "Movement", "Set velocity Y to {y}", "Sets only the vertical speed of the character (negative values move upward).", "CharacterBody2D").param("y", "0.0", "Y", "New vertical velocity (pixels/second; negative = up).", "expression"))
	descriptors.append(F.act("AddVelocity", "Add To Velocity", "{host.}velocity += {delta_v}", "Movement", "Add {delta_v} to velocity", "Adds a Vector2 to the current velocity, handy for nudges, knockback or boosts.", "CharacterBody2D").param("delta_v", "Vector2(0, 0)", "Amount", "Velocity to add, as a Vector2 expression.", "expression"))
	descriptors.append(F.act("ApplyGravity", "Apply Gravity (with terminal velocity)", "{host.}velocity.y = minf({host.}velocity.y + {gravity} * {delta_t}, {max_fall})", "Movement", "Apply gravity {gravity} (max fall {max_fall})", "Pulls the character downward each frame but caps the maximum falling speed.", "CharacterBody2D").param("gravity", "980.0", "Gravity", "Downward acceleration (pixels per second, per second).", "expression").param("max_fall", "1000.0", "Max fall speed", "Terminal velocity - never fall faster than this.", "expression").param("delta_t", "delta", "Delta", "Frame time; defaults to `delta` (valid inside On Physics Process / On Process).", "expression"))
	descriptors.append(F.act("ApplyGravitySimple", "Apply Gravity", "{host.}velocity.y += {gravity} * {delta_t}", "Movement", "Apply gravity {gravity} (per second)", "Adds constant downward acceleration to the character each frame, making it fall.", "CharacterBody2D").param("gravity", "980.0", "Gravity", "Downward acceleration (pixels per second, per second).", "expression").param("delta_t", "delta", "Delta", "Frame time; defaults to `delta`.", "expression"))
	descriptors.append(F.act("AccelerateVelocityX", "Accelerate Velocity X Toward", "{host.}velocity.x = move_toward({host.}velocity.x, {target_speed}, {rate} * {delta_t})", "Movement", "Accelerate x toward {target_speed} at {rate} (per second)", "Smoothly eases horizontal speed toward a target, giving gradual acceleration and braking.", "CharacterBody2D").param("target_speed", "0.0", "Target speed", "Horizontal speed to ease toward (e.g. direction * move_speed).", "expression").param("rate", "1500.0", "Rate", "Max change per second (acceleration / deceleration).", "expression").param("delta_t", "delta", "Delta", "Frame time; defaults to `delta`.", "expression"))
	descriptors.append(F.act("AccelerateVelocityY", "Accelerate Velocity Y Toward", "{host.}velocity.y = move_toward({host.}velocity.y, {target_speed}, {rate} * {delta_t})", "Movement", "Accelerate y toward {target_speed} at {rate} (per second)", "Smoothly eases vertical speed toward a target value over time.", "CharacterBody2D").param("target_speed", "0.0", "Target speed", "Vertical speed to ease toward.", "expression").param("rate", "1500.0", "Rate", "Max change per second.", "expression").param("delta_t", "delta", "Delta", "Frame time; defaults to `delta`.", "expression"))
	# The three movement steps a hand-rolled controller is made of that had no row of their own -
	# capping the speed, turning toward an angle over time, and letting one body pass through another.
	# Their templates are EXACTLY the lines the reading recognises, so a picked row and a typed line
	# are the same bytes and read the same sentence.
	descriptors.append(F.act("LimitSpeed", "Limit Speed", "{host.}velocity = {host.}velocity.limit_length({max_speed})", "Movement", "Limit speed to {max_speed}", "Caps how fast the body can travel in any direction, keeping diagonal movement no faster than straight movement.", "CharacterBody2D").param("max_speed", "400.0", "Max speed", "Fastest the body may travel, in pixels per second.", "expression"))
	descriptors.append(F.act("IgnoreCollisionsWith", "Ignore Collisions With", "{host.}add_collision_exception_with({other})", "Movement", "Ignore collisions with {other}", "Lets this body pass through one other body from now on - a moving platform it rides, or the object that just fired it.", "CharacterBody2D").param("other", "self", "Other", "The body to pass through from now on.", "expression"))
	descriptors.append(F.act("RotateToward", "Rotate Toward", "{host.}rotation = lerp_angle({host.}rotation, {angle}, {rate} * {delta_t})", "Movement", "Rotate toward {angle} at {rate} (per second)", "Turns the object toward an angle a little each frame instead of snapping to it, taking the shorter way round.", "Node2D").param("angle", "0.0", "Angle", "Angle to turn toward, in radians.", "expression").param("rate", "5.0", "Rate", "How much of the remaining turn is taken each second.", "expression").param("delta_t", "delta", "Delta", "Frame time; defaults to `delta`.", "expression"))
	descriptors.append(F.expr("GetVelocityX", "Velocity X", "{host.}velocity.x", "Movement", "velocity X", "Returns the character's current horizontal speed in pixels per second.", "CharacterBody2D"))
	descriptors.append(F.expr("GetVelocityY", "Velocity Y", "{host.}velocity.y", "Movement", "velocity Y", "Returns the character's current vertical speed in pixels per second.", "CharacterBody2D"))
	# RigidBody2D actions
	descriptors.append(F.act("ApplyCentralImpulse", "Apply Central Impulse", "apply_central_impulse({impulse})", "General Actions", "Apply impulse {impulse}", "Gives a rigid body an instant push in a direction, like a kick or explosion.", "RigidBody2D").param("impulse", "Vector2(0, 0)", "Impulse", "Impulse vector as a Vector2 expression.", "expression"))
	descriptors.append(F.act("ApplyCentralForce2D", "Apply Central Force", "apply_central_force({force})", "General Actions", "Apply force {force}", "Applies a continuous push to a rigid body each physics frame, like steady thrust.", "RigidBody2D").param("force", "Vector2(0, 0)", "Force", "Force vector applied this physics frame (use under On Physics Process).", "expression"))
	descriptors.append(F.act("ApplyTorqueImpulse2D", "Apply Torque Impulse", "apply_torque_impulse({torque})", "General Actions", "Apply torque impulse {torque}", "Gives a rigid body an instant spin, making it start rotating.", "RigidBody2D").param("torque", "0.0", "Torque", "Angular impulse (spin).", "expression"))
	# Timer actions
	descriptors.append(F.act("StartTimer", "Start Timer", "start({time})", "General Actions", "Start timer ({time}s)", "Starts a Timer node counting down, optionally with a custom duration.", "Timer").param("time", "-1", "Duration", "Duration in seconds (-1 uses the Timer's wait_time).", "expression"))
	descriptors.append(F.act("StopTimer", "Stop Timer", "stop()", "General Actions", "Stop timer", "Stops a running Timer so it no longer counts down or fires.", "Timer"))
	# AnimationPlayer actions
	descriptors.append(F.act("PlayAnimation", "Play Animation", "play(&{anim_name})", "General Actions", "Play animation {anim_name}", "Plays a named animation on an AnimationPlayer, e.g. for walking or attacking.", "AnimationPlayer").param("anim_name", "\"idle\"", "Animation", "Name of the animation to play.", "animation_reference"))
	descriptors.append(F.act("StopAnimation", "Stop Animation", "stop()", "General Actions", "Stop animation", "Stops the currently playing animation on the AnimationPlayer.", "AnimationPlayer"))

	# ── 2D spatial queries (mirror of the 3D raycast block - shooting, interaction, AI
	# vision, ground-snap. A RayCast2D node set + host-agnostic Node2D world queries via
	# intersect_ray, single-line per the parity contract). ──
	descriptors.append(F.cond("RayCast2DIsColliding", "RayCast Is Colliding (2D)", "is_colliding()", "Raycast 2D", "RayCast is colliding", "True when the RayCast2D is currently hitting something in its path.", "RayCast2D"))
	descriptors.append(F.act("RayCast2DForceUpdate", "Force RayCast Update (2D)", "force_raycast_update()", "Raycast 2D", "Force raycast update", "Immediately re-checks the raycast this frame instead of waiting for physics.", "RayCast2D"))
	descriptors.append(F.expr("RayCast2DGetCollider", "RayCast Collider (2D)", "get_collider()", "Raycast 2D", "raycast collider", "Returns the node the raycast is currently hitting, or nothing if clear.", "RayCast2D"))
	descriptors.append(F.expr("RayCast2DGetPoint", "RayCast Hit Point (2D)", "get_collision_point()", "Raycast 2D", "raycast hit point", "Returns the world point where the raycast hit something.", "RayCast2D"))
	descriptors.append(F.expr("RayCast2DGetNormal", "RayCast Hit Normal (2D)", "get_collision_normal()", "Raycast 2D", "raycast hit normal", "Returns the surface direction (normal) at the raycast's hit point.", "RayCast2D"))
	descriptors.append(F.cond("WorldRaycastHit2D", "World Raycast Hits? (2D)", "not get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create({from}, {to})).is_empty()", "Raycast 2D", "world raycast {from} -> {to} hits", "True when a ray drawn between two points hits any physics object.", "Node2D").param("from", "Vector2(0, 0)", "From", "Ray start (Vector2 expression).", "expression").param("to", "Vector2(0, 0)", "To", "Ray end (Vector2 expression).", "expression"))
	descriptors.append(F.expr("WorldRaycastPoint2D", "World Raycast Point (2D)", "get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create({from}, {to})).get(\"position\", Vector2.ZERO)", "Raycast 2D", "world raycast point {from} -> {to}", "Returns where a one-shot ray between two points strikes a surface.", "Node2D").param("from", "Vector2(0, 0)", "From", "Ray start (Vector2 expression).", "expression").param("to", "Vector2(0, 0)", "To", "Ray end (Vector2 expression).", "expression"))
	descriptors.append(F.expr("WorldRaycastCollider2D", "World Raycast Collider (2D)", "get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create({from}, {to})).get(\"collider\", null)", "Raycast 2D", "world raycast collider {from} -> {to}", "Returns the object a one-shot ray between two points hits, or nothing.", "Node2D").param("from", "Vector2(0, 0)", "From", "Ray start (Vector2 expression).", "expression").param("to", "Vector2(0, 0)", "To", "Ray end (Vector2 expression).", "expression"))

	# ── 2D overlap queries (one-shot "what is HERE right now" - no Area2D node needed).
	# Multi-statement templates bake a per-row {uid} local; results land in a variable,
	# so For Each picks over them and Expression Is True gates on `not X.is_empty()`. ──
	descriptors.append(F.act("QueryBodiesAtPoint2D", "Query Bodies At Point (2D)", "var __pq_{uid} := PhysicsPointQueryParameters2D.new()\n__pq_{uid}.position = {point}\n{into} = []\nfor __hit_{uid} in get_world_2d().direct_space_state.intersect_point(__pq_{uid}, {max_results}):\n\t{into}.append(__hit_{uid}.get(\"collider\"))", "Overlap 2D", "query bodies at {point} into {into}", "Collects every physics object at a world point into a variable - like tapping the world with a finger.", "Node2D").param("into", "data", "Into Variable", "Variable receiving the Array of overlapping objects.", "variable_reference").param("point", "Vector2(0, 0)", "Point", "World position to test (Vector2 expression).", "expression").param("max_results", "32", "Max Results", "Most objects to collect.", "expression"))
	descriptors.append(F.act("QueryBodiesInCircle2D", "Query Bodies In Circle (2D)", "var __cs_{uid} := CircleShape2D.new()\n__cs_{uid}.radius = {radius}\nvar __sq_{uid} := PhysicsShapeQueryParameters2D.new()\n__sq_{uid}.shape = __cs_{uid}\n__sq_{uid}.transform = Transform2D(0.0, {center})\n{into} = []\nfor __hit_{uid} in get_world_2d().direct_space_state.intersect_shape(__sq_{uid}, {max_results}):\n\t{into}.append(__hit_{uid}.get(\"collider\"))", "Overlap 2D", "query bodies within {radius}px of {center} into {into}", "Collects every physics object inside a circle into a variable - explosion radii, pickup magnets, proximity checks.", "Node2D").param("into", "data", "Into Variable", "Variable receiving the Array of overlapping objects.", "variable_reference").param("center", "global_position", "Center", "Circle center in world space (Vector2 expression).", "expression").param("radius", "64.0", "Radius", "Circle radius in pixels.", "expression").param("max_results", "32", "Max Results", "Most objects to collect.", "expression"))
	descriptors.append(F.act("QueryBodiesInRect2D", "Query Bodies In Rectangle (2D)", "var __rs_{uid} := RectangleShape2D.new()\n__rs_{uid}.size = {size}\nvar __sq_{uid} := PhysicsShapeQueryParameters2D.new()\n__sq_{uid}.shape = __rs_{uid}\n__sq_{uid}.transform = Transform2D(0.0, {center})\n{into} = []\nfor __hit_{uid} in get_world_2d().direct_space_state.intersect_shape(__sq_{uid}, {max_results}):\n\t{into}.append(__hit_{uid}.get(\"collider\"))", "Overlap 2D", "query bodies in {size} rect at {center} into {into}", "Collects every physics object inside a rectangle into a variable - selection boxes, damage zones, room checks.", "Node2D").param("into", "data", "Into Variable", "Variable receiving the Array of overlapping objects.", "variable_reference").param("center", "global_position", "Center", "Rectangle center in world space (Vector2 expression).", "expression").param("size", "Vector2(128, 64)", "Size", "Rectangle width and height (Vector2 expression).", "expression").param("max_results", "32", "Max Results", "Most objects to collect.", "expression"))

	# ── Project utility ACEs (settings / window / debug / time / reparent) ──
	# ── Settings: a ConfigFile in user:// (the standard persistent-settings store) ──
	# Multi-statement templates bake a per-row {uid} local so two in one event don't collide.
	descriptors.append(F.act("SaveSetting", "Save Setting", "var __cfg_{uid} = ConfigFile.new()\n__cfg_{uid}.load({path})\n__cfg_{uid}.set_value({section}, {key}, {value})\n__cfg_{uid}.save({path})", "Utility: Settings", "save {section}/{key} = {value}", "Writes a value into a config file on disk so it persists between play sessions.").param("path", "\"user://settings.cfg\"", "File", "Config file path (user:// persists across runs).", "expression").param("section", "\"audio\"", "Section", "Section name.", "expression").param("key", "\"volume\"", "Key", "Setting key.", "expression").param("value", "1.0", "Value", "Value to store (any type).", "expression"))
	descriptors.append(F.act("LoadSettingInto", "Load Setting Into Variable", "var __cfg_{uid} = ConfigFile.new()\n__cfg_{uid}.load({path})\n{var_name} = __cfg_{uid}.get_value({section}, {key}, {default})", "Utility: Settings", "load {section}/{key} into {var_name}", "Reads a saved value from a config file into a variable, with a fallback default.").param("var_name", "data", "Into Variable", "Variable receiving the loaded value.", "variable_reference").param("path", "\"user://settings.cfg\"", "File", "Config file path.", "expression").param("section", "\"audio\"", "Section", "Section name.", "expression").param("key", "\"volume\"", "Key", "Setting key.", "expression").param("default", "1.0", "Default", "Fallback when the key is missing.", "expression"))

	# ── Window / screen / mouse / clipboard ──
	descriptors.append(F.act("SetWindowTitle", "Set Window Title", "get_window().title = {title}", "Utility: Window", "Set title to {title}", "Changes the text shown in the game window's title bar.").param("title", "\"My Game\"", "Title", "Window title bar text.", "expression"))
	descriptors.append(F.expr("GetWindowSize", "Window Size", "get_window().size", "Utility: Window", "window size", "Returns the game window's current size in pixels."))
	descriptors.append(F.expr("GetScreenSize", "Screen Size", "DisplayServer.screen_get_size()", "Utility: Window", "screen size", "Returns the size of the player's monitor in pixels."))
	# (Set Mouse Mode lives in device_aces under "Mouse" - not duplicated here.)
	# The row wears the words the reading uses for it - an opened script's
	# `DisplayServer.clipboard_set(x)` reads `Browser ▸ Copy x to clipboard` - so a picked row and a
	# typed line say the same sentence. Id, section and emitted line are frozen and unchanged.
	descriptors.append(F.act("SetClipboard", "Copy To Clipboard", "DisplayServer.clipboard_set({text})", "Utility: Window", "copy {text} to clipboard", "Copies text to the operating system clipboard for pasting elsewhere.").param("text", "\"\"", "Text", "Text to copy to the OS clipboard.", "expression"))
	descriptors.append(F.expr("GetClipboard", "Clipboard Text", "DisplayServer.clipboard_get()", "Utility: Window", "clipboard text", "Returns whatever text is currently on the system clipboard."))

	# ── Debug / profiling (read live engine performance monitors) ──
	descriptors.append(F.expr("GetPerfMonitor", "Performance Monitor", "Performance.get_monitor({monitor})", "Utility: Debug", "monitor {monitor}", "Returns a live engine performance reading, like FPS or memory, for debugging.").param_choice("monitor", "Performance.TIME_FPS", "Monitor", "Which engine monitor to read.", ["Performance.TIME_FPS", "Performance.TIME_PROCESS", "Performance.TIME_PHYSICS_PROCESS", "Performance.OBJECT_COUNT", "Performance.OBJECT_NODE_COUNT", "Performance.RENDER_TOTAL_OBJECTS_IN_FRAME", "Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME", "Performance.PHYSICS_2D_ACTIVE_OBJECTS"]))
	descriptors.append(F.expr("GetStaticMemory", "Static Memory (bytes)", "OS.get_static_memory_usage()", "Utility: Debug", "static memory", "Returns how much memory the game is currently using, in bytes."))

	# ── Time formatting (turn seconds into clock text; read the system clock) ──
	descriptors.append(F.expr("FormatTime", "Format Time (mm:ss)", "(\"%02d:%02d\" % [int({seconds}) / 60, int({seconds}) % 60])", "Utility: Time", "format {seconds} as mm:ss", "Turns a number of seconds into a tidy mm:ss string for timers and clocks.").param("seconds", "0.0", "Seconds", "Total seconds to format.", "expression"))
	# Both belong to the Date object a reader of event sheets looks for, and both say the name a
	# row shows them under. The ids and the templates are frozen; only the words changed.
	descriptors.append(F.expr("GetSystemTime", "Date: Time Text", "Time.get_time_string_from_system()", "Utility: Time", "Date.TimeString", "Returns the player's current clock time as a text string."))
	descriptors.append(F.expr("GetSystemDate", "Date: Today", "Time.get_date_string_from_system()", "Utility: Time", "Date.Today", "Returns the player's current calendar date as a text string."))

	# ── Nodes ──
	descriptors.append(F.act("ReparentNode", "Reparent To", "reparent({new_parent})", "Utility: Nodes", "reparent to {new_parent}", "Moves this node under a new parent while keeping its on-screen position.").param("new_parent", "get_tree().current_scene", "New Parent", "Node to become the new parent (keeps global transform).", "expression"))
	# The same move with the question it always raises asked on the row instead of decided for you.
	# Reparent To above says nothing about the answer and takes Godot's own default (the node keeps
	# the place it has in the world), which is right for the shove-it-under-the-scene-root case it was
	# written for and silently wrong for a weapon that should land in the hand it was holstered to.
	# The words are Add Child (existing node)'s words on purpose - one choice, said one way, whether
	# the row names the child or is the child - and the value it emits is Godot's own second argument
	# to `reparent`, written out rather than left off, so a reader of the file can see which was meant.
	descriptors.append(F.act("ReparentToChoosing", "Reparent To (choosing)", "reparent({new_parent}, {keep})", "Utility: Nodes", "reparent to {new_parent}, {keep}", "Moves this node under a new parent, saying which of the two things should happen to where it is: keeping its place leaves it exactly where it looks, snapping to it puts it at the new parent's own spot. Plain Reparent To keeps its place without saying so.").param("new_parent", "get_tree().current_scene", "New Parent", "Node to become the new parent.", "expression").param_built(_reparent_keep_param()))

	return descriptors


## The one choice a reparent raises, as the dropdown Add Child (existing node) already words it. The
## labels are that row's labels character for character, so the same question reads the same way and
## the same translated string answers both. `display_option_labels` is what makes the row read
## "reparent to X, keeping its place" while the emitted line still carries the `true` Godot's own
## second argument wants; the key differs from the neighbouring row's blank-means-default spelling on
## purpose, because a row that says which it meant should say it in the file too.
static func _reparent_keep_param() -> ACEParam:
	var parameter: ACEParam = F.make_param("keep", "String", "true", "Its place",
		"Whether this node stays where it is in the world, or snaps to its new parent.", "",
		[{"key": "true", "label": "keeping its place"}, {"key": "false", "label": "snapping to it"}])
	parameter.display_option_labels = true
	return parameter
