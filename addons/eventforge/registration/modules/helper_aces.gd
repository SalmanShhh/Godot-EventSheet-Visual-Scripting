# EventForge module - Helper vocabulary (the "structured escape hatch").
#
# These ACEs exist for the GDScript a user would otherwise drop to a raw block for: setting
# an arbitrary property, calling an arbitrary method, a one-line statement, a ternary, a
# null-check, a runtime signal connection, the math/string idioms not covered elsewhere.
# Every template is a single, direct GDScript line (parity covenant - no plugin indirection,
# no reflection helpers), so picking a helper keeps logic as an editable row instead of an
# opaque code block while compiling to exactly what you'd have hand-written.
#
# Design rule: these are deliberately GENERIC (target/property/method/code are free
# expressions) so one helper replaces a whole family of one-off raw blocks. Where a typed,
# specific ACE already exists (SetPosition2D, Wait, Clamp, Choose, array/dict ops…), prefer
# it - these fill the gaps, they don't shadow the curated vocabulary.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility covenant);
# this file only changes where the descriptors are AUTHORED.
@tool
class_name EventForgeHelperACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Helpers"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Generic node access (the biggest gap: reach any property/method without a block) ──
	# Set/Get ANY property by name on any target ("self" by default). property is a bare
	# identifier (e.g. modulate), not a quoted string, so it stays typed + fast.
	descriptors.append(F.act("SetProperty", "Set Property", "{target}.{property} = {value}", CAT, "set {target}.{property} = {value}", "Sets any property on any node, like visible, position, or modulate.").param("target", "self", "Target", "Node/object expression (self, $Path, a variable).", "expression").param("property", "modulate", "Property", "Property name (e.g. modulate, visible, position).", "property_reference").param("value", "Color.WHITE", "Value", "Value expression to assign.", "expression"))
	# Compound-assign twins of Set Property: change a property RELATIVE to itself (the += / -= / *= / /=
	# that "self.position += velocity" or "$Sprite.modulate.a -= fade" would otherwise leave as a raw block).
	descriptors.append(F.act("AddToProperty", "Add To Property", "{target}.{property} += {value}", CAT, "{target}.{property} += {value}", "Adds an amount to a node's property, like nudging position or raising an alpha.").param("target", "self", "Target", "Node/object expression (self, $Path, a variable).", "expression").param("property", "position", "Property", "Property name (e.g. position, rotation).", "property_reference").param("value", "Vector2(1, 0)", "Value", "Amount to add to the property.", "expression"))
	descriptors.append(F.act("SubtractFromProperty", "Subtract From Property", "{target}.{property} -= {value}", CAT, "{target}.{property} -= {value}", "Subtracts an amount from a node's property, like fading an alpha down.").param("target", "self", "Target", "Node/object expression (self, $Path, a variable).", "expression").param("property", "position", "Property", "Property name (e.g. position, modulate.a).", "property_reference").param("value", "Vector2(1, 0)", "Value", "Amount to subtract from the property.", "expression"))
	descriptors.append(F.act("MultiplyProperty", "Multiply Property", "{target}.{property} *= {value}", CAT, "{target}.{property} *= {value}", "Scales a node's property by a factor, like growing a sprite's scale.").param("target", "self", "Target", "Node/object expression (self, $Path, a variable).", "expression").param("property", "scale", "Property", "Property name (e.g. scale).", "property_reference").param("value", "1.1", "Value", "Factor to multiply the property by.", "expression"))
	descriptors.append(F.act("DivideProperty", "Divide Property", "{target}.{property} /= {value}", CAT, "{target}.{property} /= {value}", "Divides a node's property by a value, like shrinking a sprite's scale.").param("target", "self", "Target", "Node/object expression (self, $Path, a variable).", "expression").param("property", "scale", "Property", "Property name (e.g. scale).", "property_reference").param("value", "2.0", "Value", "What to divide the property by.", "expression"))
	descriptors.append(F.expr("GetProperty", "Get Property", "{target}.{property}", CAT, "{target}.{property}", "Reads the current value of any property on any node.").param("target", "self", "Target", "Node/object expression.", "expression").param("property", "visible", "Property", "Property name to read.", "property_reference"))
	# Call ANY method, as a fire-and-forget action or as a value-returning expression.
	descriptors.append(F.act("CallMethod", "Call Method", "{target}.{method}({args})", CAT, "{target}.{method}({args})", "Calls a method on a node when you need something not in the menus.").param("target", "self", "Target", "Node/object expression.", "expression").param("method", "queue_free", "Method", "Method name to call.", "method_reference").param("args", "", "Arguments", "Comma-separated argument expressions (may be empty).", "expression"))
	descriptors.append(F.expr("CallMethodValue", "Call Method (value)", "{target}.{method}({args})", CAT, "{target}.{method}({args})", "Calls a method on a node and uses the value it returns.").param("target", "self", "Target", "Node/object expression.", "expression").param("method", "get_index", "Method", "Method name to call.", "method_reference").param("args", "", "Arguments", "Comma-separated argument expressions.", "expression"))
	descriptors.append(F.expr("GetNode", "Get Node", "get_node({path})", CAT, "get_node({path})", "Looks up another node by its scene path so you can use it.").param("path", "\"Sprite2D\"", "Path", "Node path string (e.g. \"Sprite2D\" or \"../Enemy\").", "expression"))

	# ── The universal escape, but pickable: a raw statement/expression as a real ACE row ──
	# RunGDScript is one statement (still an editable, searchable, codegen-tooltipped row
	# rather than a multi-line block). The Evaluate pair lets any inline expression stand in
	# as a condition or a value.
	descriptors.append(F.act("RunGDScript", "Run GDScript", "{code}", CAT, "run: {code}", "Drops in one line of raw GDScript for things the menus can't do.").param("code", "pass", "Code", "A single GDScript statement to run here.", "expression"))
	descriptors.append(F.cond("EvaluateGDScript", "Evaluate GDScript", "({code})", CAT, "({code})", "True when your own GDScript boolean expression evaluates to true.").param("code", "true", "Code", "A GDScript boolean expression.", "expression"))
	descriptors.append(F.expr("EvaluateExpression", "Evaluate Expression", "({code})", CAT, "({code})", "Returns the result of any GDScript expression you type in.").param("code", "0", "Code", "Any GDScript value expression.", "expression"))

	# ── Control-flow helpers that don't warrant a whole row structure ──
	descriptors.append(F.expr("InlineIf", "Value If (one of two values)", "({true_value} if {condition} else {false_value})", CAT, "{true_value} if {condition} else {false_value}", "Picks one of two values depending on a condition, all in one line.").param("true_value", "1", "If true", "Value when the condition holds.", "expression").param("condition", "true", "Condition", "Boolean expression.", "expression").param("false_value", "0", "If false", "Value otherwise.", "expression"))
	descriptors.append(F.act("ToggleBool", "Toggle Boolean", "{var_name} = not {var_name}", CAT, "toggle {var_name}", "Flips a true/false variable to its opposite value.").param("var_name", "var", "Variable", "Boolean variable to flip.", "variable_reference"))

	# ── Lambdas & callables: little inline functions you can hand to signals, timers, sorters ──
	# Two lambda shapes (return a value / run a statement) plus the two Callable staples (reference a
	# method by name, pre-fill arguments). Expressions stay opaque strings, so these round-trip verbatim.
	descriptors.append(F.expr("LambdaValue", "Lambda (returns a value)", "(func({params}): return {value})", CAT, "func({params}): return {value}", "A small inline function that computes and returns a value - hand it to sort(), map(), or filter().").param("params", "x", "Parameters", "Comma-separated parameter names (may be empty).", "expression").param("value", "x * 2", "Returns", "The expression the lambda returns.", "expression"))
	descriptors.append(F.expr("LambdaStatement", "Lambda (runs a statement)", "(func({params}): {statement})", CAT, "func({params}): {statement}", "A small inline function that runs one statement - connect it to a signal or a timer.").param("params", "x", "Parameters", "Comma-separated parameter names (may be empty).", "expression").param("statement", "print(x)", "Runs", "The single statement the lambda runs.", "expression"))
	descriptors.append(F.expr("CallableFromMethod", "Callable of Method", "Callable({target}, \"{method}\")", CAT, "Callable({target}, {method})", "A reference to a named method you can pass around, connect, or call later.").param("target", "self", "Target", "Node/object expression that owns the method.", "expression").param("method", "queue_free", "Method", "The method name the callable will invoke.", "method_reference"))
	descriptors.append(F.expr("CallableBind", "Bind Arguments", "{callable}.bind({args})", CAT, "{callable}.bind({args})", "Pre-fills arguments of a callable, so the receiver can call it with fewer of its own.").param("callable", "Callable(self, \"queue_free\")", "Callable", "The callable to pre-fill (a lambda or Callable expression).", "expression").param("args", "0", "Arguments", "Comma-separated argument values to pre-fill.", "expression"))
	# Declares an event-local temp later actions in the same event body can reference.
	descriptors.append(F.act("SetLocalVar", "Set Local Variable", "var {name} = {value}", CAT, "var {name} = {value}", "Creates a temporary variable used only within this event.").param("name", "temp", "Name", "Local variable name (scoped to this event body).").param("value", "0", "Value", "Initial value expression.", "expression"))
	# Typed sibling: a statically-typed local, so dense interleaved typed temporaries (the kind that
	# force RawCode in a behaviour tick) stay expressible as ACE rows.
	descriptors.append(F.act("SetLocalVarTyped", "Set Local Variable (typed)", "var {name}: {var_type} = {value}", CAT, "var {name}: {var_type} = {value}", "Creates a temporary variable of a fixed type within this event.").param("name", "temp", "Name", "Local variable name (scoped to this event body).").param_choice("var_type", "float", "Type", "Static type for the local.", ["float", "int", "bool", "String", "Vector2", "Vector3"]).param("value", "0.0", "Value", "Initial value expression.", "expression"))
	# Inferred sibling (`:=`): a local whose type is inferred from its value - the idiomatic
	# `var heading := Vector2.from_angle(...)`. Without this, a `:=` line forced a RawCode block (the plain
	# `=` template needs a space-equals-space, which `:=` never has). Reverse-lifts + round-trips byte-exact.
	descriptors.append(F.act("SetLocalVarInferred", "Set Local Variable (inferred)", "var {name} := {value}", CAT, "var {name} := {value}", "Creates a temporary variable whose type is inferred from its value, within this event.").param("name", "temp", "Name", "Local variable name (scoped to this event body).").param("value", "0.0", "Value", "Value expression; its type is inferred.", "expression"))
	# Local CONSTANT twins of the SetLocalVar family - a `const` inside a flow body (a tuning constant or a
	# lookup value the compiler folds once). Three variants so `const N = 3`, `const N: int = 3` and
	# `const N := 3` each reverse-lift to the right row instead of a generic Set Variable named "const N".
	descriptors.append(F.act("SetLocalConst", "Set Local Constant", "const {name} = {value}", CAT, "const {name} = {value}", "Creates a named constant used only within this event.").param("name", "temp", "Name", "Local constant name (scoped to this event body).").param("value", "0", "Value", "Constant value expression (must be compile-time constant).", "expression"))
	descriptors.append(F.act("SetLocalConstTyped", "Set Local Constant (typed)", "const {name}: {const_type} = {value}", CAT, "const {name}: {const_type} = {value}", "Creates a typed named constant used only within this event.").param("name", "temp", "Name", "Local constant name (scoped to this event body).").param_choice("const_type", "int", "Type", "Static type for the constant.", ["int", "float", "bool", "String", "Vector2", "Vector3"]).param("value", "0", "Value", "Constant value expression.", "expression"))
	descriptors.append(F.act("SetLocalConstInferred", "Set Local Constant (inferred)", "const {name} := {value}", CAT, "const {name} := {value}", "Creates a named constant whose type is inferred from its value, within this event.").param("name", "temp", "Name", "Local constant name (scoped to this event body).").param("value", "0", "Value", "Constant value expression; its type is inferred.", "expression"))

	# ── Validity / null (freed-instance safety, the classic source of crashes) ──
	descriptors.append(F.cond("IsValid", "Is Valid", "is_instance_valid({target})", CAT, "{target} is valid", "True when the object still exists and hasn't been freed.").param("target", "self", "Target", "Object expression to test.", "expression"))
	descriptors.append(F.cond("IsNull", "Is Null", "{target} == null", CAT, "{target} is null", "True when the value is null, meaning nothing or missing.").param("target", "self", "Target", "Expression to test for null.", "expression"))
	# Type-of (the typeof gap). For an `is` class check, use Expression Is True with e.g. `self is Area2D`.
	descriptors.append(F.expr("TypeOf", "Type Of", "typeof({value})", CAT, "typeof({value})", "Returns a number identifying what kind of value something is.").param("value", "0", "Value", "Value whose Variant.Type (an int) to read.", "expression"))

	# ── Runtime signal wiring (connect/disconnect without a _ready block) ──
	descriptors.append(F.act("ConnectSignal", "Connect Signal", "{source}.{signal}.connect({callable})", CAT, "connect {source}.{signal} -> {callable}", "Wires a node's signal to run a method whenever it fires.").param("source", "self", "Source", "Object emitting the signal.", "expression").param("signal", "pressed", "Signal", "Signal name.").param("callable", "_on_pressed", "Callable", "Method/Callable to connect.", "expression"))
	descriptors.append(F.act("DisconnectSignal", "Disconnect Signal", "{source}.{signal}.disconnect({callable})", CAT, "disconnect {source}.{signal} -> {callable}", "Stops a signal from calling a method, so that response no longer fires.").param("source", "self", "Source", "Object emitting the signal.", "expression").param("signal", "pressed", "Signal", "Signal name.").param("callable", "_on_pressed", "Callable", "Method/Callable to disconnect.", "expression"))
	descriptors.append(F.cond("IsSignalConnected", "Signal Is Connected", "{source}.{signal}.is_connected({callable})", CAT, "{source}.{signal} connected to {callable}", "True when a method is currently hooked up to listen for that signal.").param("source", "self", "Source", "Object emitting the signal.", "expression").param("signal", "pressed", "Signal", "Signal name.").param("callable", "_on_pressed", "Callable", "Method/Callable to test.", "expression"))
	# Plain Connect Signal is NOT idempotent: running it twice stacks a second handler and the response
	# fires twice (the classic "my handler runs 40 times" bug). These two make re-running safe - guard on
	# is_connected, or let the connection fire once and drop itself.
	descriptors.append(F.act("ConnectSignalUnique", "Connect Signal (if not already)", "if not {source}.{signal}.is_connected({callable}):\n\t{source}.{signal}.connect({callable})", CAT, "connect {source}.{signal} -> {callable} (if not already)", "Wires a signal only when it is not already wired, so re-running never stacks duplicate handlers.").param("source", "self", "Source", "Object emitting the signal.", "expression").param("signal", "pressed", "Signal", "Signal name.").param("callable", "_on_pressed", "Callable", "Method/Callable to connect.", "expression"))
	descriptors.append(F.act("ConnectSignalOneShot", "Connect Signal (one-shot)", "{source}.{signal}.connect({callable}, CONNECT_ONE_SHOT)", CAT, "connect {source}.{signal} -> {callable} (one-shot)", "Wires a signal to run ONCE - the connection drops itself after it fires.").param("source", "self", "Source", "Object emitting the signal.", "expression").param("signal", "pressed", "Signal", "Signal name.").param("callable", "_on_pressed", "Callable", "Method/Callable to run once.", "expression"))
	# Modern Godot 4 form `target.signal.emit(args)` - `signal` is a BARE identifier (not a quoted
	# string), which keeps the output parity-clean (the legacy `emit_signal("name")` matches a banned
	# pattern in codegen_parity_test.gd) and idiomatic. Pairs with a trigger that receives the args.
	descriptors.append(F.act("EmitSignalOn", "Emit Signal On", "{target}.{signal}.emit({args})", CAT, "emit {target}.{signal}", "Fires a signal on an object to notify everything listening for it.").param("target", "self", "Target", "Object that owns the signal.", "expression").param("signal", "died", "Signal", "Signal name (a bare identifier, e.g. died).", "signal_reference").param("args", "", "Arguments", "Optional signal arguments (comma-separated)."))
	# Group-scoped signal wiring - the OBSERVER direction, decoupled. A listener wires ITSELF to a signal on
	# every current member of a group at once, holding no direct reference to (and no tree path to) any
	# emitter - the fix for "react to any enemy dying" without one Connect Signal per enemy. The is_connected
	# guard makes re-runs idempotent (never stacks duplicate handlers). Pairs with the call_group broadcast.
	# Connects only CURRENT members; nodes that join the group later are wired by re-running it or on spawn -
	# or, since the arrival triggers shipped, by On Node Joins Group, which hands over the one node that
	# just arrived so a group growing all game long stays wired without the loop being run again.
	descriptors.append(F.act("ConnectGroupSignal", "Connect Group Signal", "for __emitter_{uid}: Node in get_tree().get_nodes_in_group({group}):\n\tif not __emitter_{uid}.{signal}.is_connected({callable}):\n\t\t__emitter_{uid}.{signal}.connect({callable})", CAT, "connect {group}.{signal} -> {callable}", "Listens to a signal on every current member of a group at once, with no reference to any of them.").param("group", "\"enemies\"", "Group", "Every current member of this group is wired - no per-node reference.", "group_reference").param("signal", "died", "Signal", "Signal name (a bare identifier, e.g. died) the members emit.", "signal_reference").param("callable", "_on_group_signal", "Callable", "Method/Callable to run when any member fires it.", "expression").featured())
	descriptors.append(F.act("DisconnectGroupSignal", "Disconnect Group Signal", "for __emitter_{uid}: Node in get_tree().get_nodes_in_group({group}):\n\tif __emitter_{uid}.{signal}.is_connected({callable}):\n\t\t__emitter_{uid}.{signal}.disconnect({callable})", CAT, "disconnect {group}.{signal} -> {callable}", "Stops listening to a signal on every current member of a group.").param("group", "\"enemies\"", "Group", "Every current member of this group is unwired.", "group_reference").param("signal", "died", "Signal", "Signal name (a bare identifier).", "signal_reference").param("callable", "_on_group_signal", "Callable", "Method/Callable to stop running.", "expression"))

	# ── Math/string idioms not already covered (Clamp/Lerp/Choose/Random live in Core) ──
	descriptors.append(F.expr("AbsValue", "Absolute Value", "abs({value})", CAT, "abs({value})", "Returns a number's size without its sign, so -5 becomes 5.").param("value", "0", "Value", "Value.", "expression"))
	descriptors.append(F.expr("MinValue", "Min", "min({a}, {b})", CAT, "min({a}, {b})", "Returns whichever of two numbers is smaller.").param("a", "0", "A", "First value.", "expression").param("b", "0", "B", "Second value.", "expression"))
	descriptors.append(F.expr("MaxValue", "Max", "max({a}, {b})", CAT, "max({a}, {b})", "Returns whichever of two numbers is larger.").param("a", "0", "A", "First value.", "expression").param("b", "0", "B", "Second value.", "expression"))
	descriptors.append(F.expr("RoundValue", "Round", "round({value})", CAT, "round({value})", "Rounds a number to the nearest whole number.").param("value", "0.0", "Value", "Value to round.", "expression"))
	descriptors.append(F.expr("SignValue", "Sign", "sign({value})", CAT, "sign({value})", "Returns -1, 0, or 1 to tell whether a number is negative, zero, or positive.").param("value", "0", "Value", "Value (-1/0/1).", "expression"))
	descriptors.append(F.expr("MoveTowardValue", "Move Toward", "move_toward({from}, {to}, {amount})", CAT, "move_toward({from}, {to}, {amount})", "Nudges a value toward a target by a set step, great for smooth changes.").param("from", "0.0", "From", "Current value.", "expression").param("to", "1.0", "To", "Target value.", "expression").param("amount", "0.1", "Amount", "Max step toward target.", "expression"))
	descriptors.append(F.expr("WrapValue", "Wrap", "wrapf({value}, {min}, {max})", CAT, "wrap({value}, {min}, {max})", "Wraps a value to stay within a range, looping past the edges back around.").param("value", "0.0", "Value", "Value to wrap.", "expression").param("min", "0.0", "Min", "Lower bound.", "expression").param("max", "1.0", "Max", "Upper bound.", "expression"))
	descriptors.append(F.expr("RemapValue", "Remap Range", "remap({value}, {in_min}, {in_max}, {out_min}, {out_max})", CAT, "remap({value}, …)", "Rescales a number from one range into another, like mapping 0-100 onto 0-1.").param("value", "0.0", "Value", "Value to remap.", "expression").param("in_min", "0.0", "In min", "Input range start.", "expression").param("in_max", "1.0", "In max", "Input range end.", "expression").param("out_min", "0.0", "Out min", "Output range start.", "expression").param("out_max", "1.0", "Out max", "Output range end.", "expression"))
	# Phase 4 math expressions (siblings to Abs/Min/Max): common one-liners that used to force a RawCode
	# expression. Pure ƒx-field expressions; defaults compile under builtin_ace_compile_test.
	descriptors.append(F.expr("SquareRoot", "Square Root", "sqrt({value})", CAT, "sqrt({value})", "Returns the square root of a number.").param("value", "1.0", "Value", "Value (>= 0).", "expression"))
	descriptors.append(F.expr("PowValue", "Power", "pow({base}, {exp})", CAT, "pow({base}, {exp})", "Raises a base number to an exponent power, like 2 to the 8th.").param("base", "2.0", "Base", "Base value.", "expression").param("exp", "2.0", "Exponent", "Exponent.", "expression"))
	descriptors.append(F.expr("FloorValue", "Floor", "floor({value})", CAT, "floor({value})", "Rounds a number down to the nearest whole number.").param("value", "0.0", "Value", "Round down to the nearest integer.", "expression"))
	descriptors.append(F.expr("CeilValue", "Ceil", "ceil({value})", CAT, "ceil({value})", "Rounds a number up to the nearest whole number.").param("value", "0.0", "Value", "Round up to the nearest integer.", "expression"))
	descriptors.append(F.expr("FmodValue", "Float Modulo", "fmod({a}, {b})", CAT, "fmod({a}, {b})", "Returns the remainder after dividing one number by another.").param("a", "0.0", "A", "Dividend.", "expression").param("b", "1.0", "B", "Divisor.", "expression"))
	descriptors.append(F.expr("EaseValue", "Ease", "ease({value}, {curve})", CAT, "ease({value}, {curve})", "Bends a 0-to-1 value along an easing curve for smoother eased motion.").param("value", "0.0", "Value", "A 0..1 input.", "expression").param("curve", "2.0", "Curve", "Easing exponent (>1 ease-in, <1 ease-out).", "expression"))
	descriptors.append(F.expr("SnappedValue", "Snapped", "snappedf({value}, {step})", CAT, "snappedf({value}, {step})", "Snaps a value to the nearest multiple of a step, like a grid.").param("value", "0.0", "Value", "Value to snap.", "expression").param("step", "1.0", "Step", "Snap increment (e.g. grid size).", "expression"))
	# Load a resource at runtime into a variable. (preload is parse-time only - author it as a RawCode
	# const where a compile-time scene is required; a placeholder-defaulted preload can't compile-test.)
	descriptors.append(F.expr("LoadResource", "Load Resource", "load({path})", CAT, "load({path})", "Loads a scene or resource from a res:// path so you can use it.").param("path", "\"res://\"", "Path", "res:// path to the resource/scene.", "expression"))
	# Trig + interpolation - the vocabulary that lets oscillation/rotation/easing behaviours (sine
	# wobble, orbit, look-at, smooth follow) be authored as ƒx expressions instead of a RawCode block.
	descriptors.append(F.expr("SinValue", "Sine", "sin({value})", CAT, "sin({value})", "Returns the sine of an angle in radians, handy for waves and circular motion.").param("value", "0.0", "Value", "Angle in radians.", "expression"))
	descriptors.append(F.expr("CosValue", "Cosine", "cos({value})", CAT, "cos({value})", "Returns the cosine of an angle in radians, handy for waves and circular motion.").param("value", "0.0", "Value", "Angle in radians.", "expression"))
	descriptors.append(F.expr("TanValue", "Tangent", "tan({value})", CAT, "tan({value})", "Returns the tangent of an angle given in radians.").param("value", "0.0", "Value", "Angle in radians.", "expression"))
	descriptors.append(F.expr("Atan2Value", "Arc Tangent (y, x)", "atan2({y}, {x})", CAT, "atan2({y}, {x})", "Returns the angle (in radians) pointing toward a given y and x direction.").param("y", "0.0", "Y", "Y component.", "expression").param("x", "1.0", "X", "X component.", "expression"))
	# (Lerp already lives in Core.) clampf is the float-typed clamp for ƒx expressions.
	descriptors.append(F.expr("ClampFloatValue", "Clamp (float)", "clampf({value}, {min}, {max})", CAT, "clampf({value}, {min}, {max})", "Keeps a number from going below a minimum or above a maximum.").param("value", "0.0", "Value", "Value to clamp.", "expression").param("min", "0.0", "Min", "Lower bound.", "expression").param("max", "1.0", "Max", "Upper bound.", "expression"))
	# The integer-typed twins: clampf/wrapf return a float, which truncates or type-errors when stored back
	# into a whole-number variable (score, health, ammo, a menu index). These keep the result a clean int.
	descriptors.append(F.expr("ClampIntValue", "Clamp (int)", "clampi({value}, {min}, {max})", CAT, "clampi({value}, {min}, {max})", "Keeps a whole number within a min and max - use this (not the float clamp) for scores, health, and ammo.").param("value", "0", "Value", "Whole-number value to clamp.", "expression").param("min", "0", "Min", "Lower bound.", "expression").param("max", "10", "Max", "Upper bound.", "expression"))
	descriptors.append(F.expr("WrapIntValue", "Wrap (int)", "wrapi({value}, {min}, {max})", CAT, "wrapi({value}, {min}, {max})", "Wraps a whole number around a range - perfect for cycling a menu or inventory index past the ends back to the start.").param("value", "0", "Value", "Whole-number value to wrap.", "expression").param("min", "0", "Min", "Lower bound (inclusive).", "expression").param("max", "10", "Max", "Upper bound (exclusive).", "expression"))
	descriptors.append(F.expr("DegToRadValue", "Degrees To Radians", "deg_to_rad({degrees})", CAT, "deg_to_rad({degrees})", "Converts an angle from degrees into radians for math functions.").param("degrees", "0.0", "Degrees", "Angle in degrees.", "expression"))
	descriptors.append(F.expr("RadToDegValue", "Radians To Degrees", "rad_to_deg({radians})", CAT, "rad_to_deg({radians})", "Converts an angle from radians back into easier-to-read degrees.").param("radians", "0.0", "Radians", "Angle in radians.", "expression"))
	descriptors.append(F.expr("FormatString", "Format String", "{template} % [{args}]", CAT, "{template} % [{args}]", "Builds a text string by filling placeholders with your values, like scores.").param("template", "\"Score: %d\"", "Template", "Format string (printf-style).", "expression").param("args", "0", "Arguments", "Comma-separated values for the placeholders.", "expression"))
	# Set a node's text from a printf-style template in one row (replaces a RawCode block).
	descriptors.append(F.act("SetTextFormatted", "Set Text (formatted)", "{target}.text = {template} % [{args}]", CAT, "set {target} text = {template}", "Sets a label or button's text using a format string filled with your values.").param("target", "self", "Target", "Node with a text property (Label, RichTextLabel, Button…).", "expression").param("template", "\"Score: %d\"", "Template", "printf-style format string.", "expression").param("args", "0", "Arguments", "Comma-separated values for the placeholders (must match the format).", "expression"))

	return descriptors
