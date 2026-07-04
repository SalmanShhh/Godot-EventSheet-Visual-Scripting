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
	descriptors.append(F.make_descriptor("Core", "SetProperty", "Set Property", ACEDescriptor.ACEType.ACTION, "{target}.{property} = {value}", "", [F.make_param("target", "String", "self", "Target", "Node/object expression (self, $Path, a variable).", "expression"), F.make_param("property", "String", "modulate", "Property", "Property name (e.g. modulate, visible, position).", "property_reference"), F.make_param("value", "String", "Color.WHITE", "Value", "Value expression to assign.", "expression")], CAT, "set {target}.{property} = {value}")
		.described("Sets any property on any node, like visible, position, or modulate."))
	descriptors.append(F.make_descriptor("Core", "GetProperty", "Get Property", ACEDescriptor.ACEType.EXPRESSION, "{target}.{property}", "", [F.make_param("target", "String", "self", "Target", "Node/object expression.", "expression"), F.make_param("property", "String", "visible", "Property", "Property name to read.", "property_reference")], CAT, "{target}.{property}")
		.described("Reads the current value of any property on any node."))
	# Call ANY method, as a fire-and-forget action or as a value-returning expression.
	descriptors.append(F.make_descriptor("Core", "CallMethod", "Call Method", ACEDescriptor.ACEType.ACTION, "{target}.{method}({args})", "", [F.make_param("target", "String", "self", "Target", "Node/object expression.", "expression"), F.make_param("method", "String", "queue_free", "Method", "Method name to call.", "method_reference"), F.make_param("args", "String", "", "Arguments", "Comma-separated argument expressions (may be empty).", "expression")], CAT, "{target}.{method}({args})")
		.described("Calls a method on a node when you need something not in the menus."))
	descriptors.append(F.make_descriptor("Core", "CallMethodValue", "Call Method (value)", ACEDescriptor.ACEType.EXPRESSION, "{target}.{method}({args})", "", [F.make_param("target", "String", "self", "Target", "Node/object expression.", "expression"), F.make_param("method", "String", "get_index", "Method", "Method name to call.", "method_reference"), F.make_param("args", "String", "", "Arguments", "Comma-separated argument expressions.", "expression")], CAT, "{target}.{method}({args})")
		.described("Calls a method on a node and uses the value it returns."))
	descriptors.append(F.make_descriptor("Core", "GetNode", "Get Node", ACEDescriptor.ACEType.EXPRESSION, "get_node({path})", "", [F.make_param("path", "String", "\"Sprite2D\"", "Path", "Node path string (e.g. \"Sprite2D\" or \"../Enemy\").", "expression")], CAT, "get_node({path})")
		.described("Looks up another node by its scene path so you can use it."))

	# ── The universal escape, but pickable: a raw statement/expression as a real ACE row ──
	# RunGDScript is one statement (still an editable, searchable, codegen-tooltipped row
	# rather than a multi-line block). The Evaluate pair lets any inline expression stand in
	# as a condition or a value.
	descriptors.append(F.make_descriptor("Core", "RunGDScript", "Run GDScript", ACEDescriptor.ACEType.ACTION, "{code}", "", [F.make_param("code", "String", "pass", "Code", "A single GDScript statement to run here.", "expression")], CAT, "run: {code}")
		.described("Drops in one line of raw GDScript for things the menus can't do."))
	descriptors.append(F.make_descriptor("Core", "EvaluateGDScript", "Evaluate GDScript", ACEDescriptor.ACEType.CONDITION, "({code})", "", [F.make_param("code", "String", "true", "Code", "A GDScript boolean expression.", "expression")], CAT, "({code})")
		.described("True when your own GDScript boolean expression evaluates to true."))
	descriptors.append(F.make_descriptor("Core", "EvaluateExpression", "Evaluate Expression", ACEDescriptor.ACEType.EXPRESSION, "({code})", "", [F.make_param("code", "String", "0", "Code", "Any GDScript value expression.", "expression")], CAT, "({code})")
		.described("Returns the result of any GDScript expression you type in."))

	# ── Control-flow helpers that don't warrant a whole row structure ──
	descriptors.append(F.make_descriptor("Core", "InlineIf", "Inline If (ternary)", ACEDescriptor.ACEType.EXPRESSION, "({true_value} if {condition} else {false_value})", "", [F.make_param("true_value", "String", "1", "If true", "Value when the condition holds.", "expression"), F.make_param("condition", "String", "true", "Condition", "Boolean expression.", "expression"), F.make_param("false_value", "String", "0", "If false", "Value otherwise.", "expression")], CAT, "{true_value} if {condition} else {false_value}")
		.described("Picks one of two values depending on a condition, all in one line."))
	descriptors.append(F.make_descriptor("Core", "ToggleBool", "Toggle Boolean", ACEDescriptor.ACEType.ACTION, "{var_name} = not {var_name}", "", [F.make_param("var_name", "String", "var", "Variable", "Boolean variable to flip.", "variable_reference")], CAT, "toggle {var_name}")
		.described("Flips a true/false variable to its opposite value."))
	# Declares an event-local temp later actions in the same event body can reference.
	descriptors.append(F.make_descriptor("Core", "SetLocalVar", "Set Local Variable", ACEDescriptor.ACEType.ACTION, "var {name} = {value}", "", [F.make_param("name", "String", "temp", "Name", "Local variable name (scoped to this event body)."), F.make_param("value", "String", "0", "Value", "Initial value expression.", "expression")], CAT, "var {name} = {value}")
		.described("Creates a temporary variable used only within this event."))
	# Typed sibling: a statically-typed local, so dense interleaved typed temporaries (the kind that
	# force RawCode in a behaviour tick) stay expressible as ACE rows.
	descriptors.append(F.make_descriptor("Core", "SetLocalVarTyped", "Set Local Variable (typed)", ACEDescriptor.ACEType.ACTION, "var {name}: {var_type} = {value}", "", [F.make_param("name", "String", "temp", "Name", "Local variable name (scoped to this event body)."), F.make_param("var_type", "String", "float", "Type", "Static type for the local.", "", ["float", "int", "bool", "String", "Vector2", "Vector3"]), F.make_param("value", "String", "0.0", "Value", "Initial value expression.", "expression")], CAT, "var {name}: {var_type} = {value}")
		.described("Creates a temporary variable of a fixed type within this event."))

	# ── Validity / null (freed-instance safety, the classic source of crashes) ──
	descriptors.append(F.make_descriptor("Core", "IsValid", "Is Valid", ACEDescriptor.ACEType.CONDITION, "is_instance_valid({target})", "", [F.make_param("target", "String", "self", "Target", "Object expression to test.", "expression")], CAT, "{target} is valid")
		.described("True when the object still exists and hasn't been freed."))
	descriptors.append(F.make_descriptor("Core", "IsNull", "Is Null", ACEDescriptor.ACEType.CONDITION, "{target} == null", "", [F.make_param("target", "String", "self", "Target", "Expression to test for null.", "expression")], CAT, "{target} is null")
		.described("True when the value is null, meaning nothing or missing."))
	# Type-of (the typeof gap). For an `is` class check, use Expression Is True with e.g. `self is Area2D`.
	descriptors.append(F.make_descriptor("Core", "TypeOf", "Type Of", ACEDescriptor.ACEType.EXPRESSION, "typeof({value})", "", [F.make_param("value", "String", "0", "Value", "Value whose Variant.Type (an int) to read.", "expression")], CAT, "typeof({value})")
		.described("Returns a number identifying what kind of value something is."))

	# ── Runtime signal wiring (connect/disconnect without a _ready block) ──
	descriptors.append(F.make_descriptor("Core", "ConnectSignal", "Connect Signal", ACEDescriptor.ACEType.ACTION, "{source}.{signal}.connect({callable})", "", [F.make_param("source", "String", "self", "Source", "Object emitting the signal.", "expression"), F.make_param("signal", "String", "pressed", "Signal", "Signal name."), F.make_param("callable", "String", "_on_pressed", "Callable", "Method/Callable to connect.", "expression")], CAT, "connect {source}.{signal} -> {callable}")
		.described("Wires a node's signal to run a method whenever it fires."))
	descriptors.append(F.make_descriptor("Core", "DisconnectSignal", "Disconnect Signal", ACEDescriptor.ACEType.ACTION, "{source}.{signal}.disconnect({callable})", "", [F.make_param("source", "String", "self", "Source", "Object emitting the signal.", "expression"), F.make_param("signal", "String", "pressed", "Signal", "Signal name."), F.make_param("callable", "String", "_on_pressed", "Callable", "Method/Callable to disconnect.", "expression")], CAT, "disconnect {source}.{signal} -> {callable}")
		.described("Stops a signal from calling a method, so that response no longer fires."))
	descriptors.append(F.make_descriptor("Core", "IsSignalConnected", "Signal Is Connected", ACEDescriptor.ACEType.CONDITION, "{source}.{signal}.is_connected({callable})", "", [F.make_param("source", "String", "self", "Source", "Object emitting the signal.", "expression"), F.make_param("signal", "String", "pressed", "Signal", "Signal name."), F.make_param("callable", "String", "_on_pressed", "Callable", "Method/Callable to test.", "expression")], CAT, "{source}.{signal} connected to {callable}")
		.described("True when a method is currently hooked up to listen for that signal."))
	# Modern Godot 4 form `target.signal.emit(args)` - `signal` is a BARE identifier (not a quoted
	# string), which keeps the output parity-clean (the legacy `emit_signal("name")` matches a banned
	# pattern in codegen_parity_test.gd) and idiomatic. Pairs with a trigger that receives the args.
	descriptors.append(F.make_descriptor("Core", "EmitSignalOn", "Emit Signal On", ACEDescriptor.ACEType.ACTION, "{target}.{signal}.emit({args})", "", [F.make_param("target", "String", "self", "Target", "Object that owns the signal.", "expression"), F.make_param("signal", "String", "died", "Signal", "Signal name (a bare identifier, e.g. died).", "signal_reference"), F.make_param("args", "String", "", "Arguments", "Optional signal arguments (comma-separated).")], CAT, "emit {target}.{signal}")
		.described("Fires a signal on an object to notify everything listening for it."))

	# ── Math/string idioms not already covered (Clamp/Lerp/Choose/Random live in Core) ──
	descriptors.append(F.make_descriptor("Core", "AbsValue", "Absolute Value", ACEDescriptor.ACEType.EXPRESSION, "abs({value})", "", [F.make_param("value", "String", "0", "Value", "Value.", "expression")], CAT, "abs({value})")
		.described("Returns a number's size without its sign, so -5 becomes 5."))
	descriptors.append(F.make_descriptor("Core", "MinValue", "Min", ACEDescriptor.ACEType.EXPRESSION, "min({a}, {b})", "", [F.make_param("a", "String", "0", "A", "First value.", "expression"), F.make_param("b", "String", "0", "B", "Second value.", "expression")], CAT, "min({a}, {b})")
		.described("Returns whichever of two numbers is smaller."))
	descriptors.append(F.make_descriptor("Core", "MaxValue", "Max", ACEDescriptor.ACEType.EXPRESSION, "max({a}, {b})", "", [F.make_param("a", "String", "0", "A", "First value.", "expression"), F.make_param("b", "String", "0", "B", "Second value.", "expression")], CAT, "max({a}, {b})")
		.described("Returns whichever of two numbers is larger."))
	descriptors.append(F.make_descriptor("Core", "RoundValue", "Round", ACEDescriptor.ACEType.EXPRESSION, "round({value})", "", [F.make_param("value", "String", "0.0", "Value", "Value to round.", "expression")], CAT, "round({value})")
		.described("Rounds a number to the nearest whole number."))
	descriptors.append(F.make_descriptor("Core", "SignValue", "Sign", ACEDescriptor.ACEType.EXPRESSION, "sign({value})", "", [F.make_param("value", "String", "0", "Value", "Value (-1/0/1).", "expression")], CAT, "sign({value})")
		.described("Returns -1, 0, or 1 to tell whether a number is negative, zero, or positive."))
	descriptors.append(F.make_descriptor("Core", "MoveTowardValue", "Move Toward", ACEDescriptor.ACEType.EXPRESSION, "move_toward({from}, {to}, {amount})", "", [F.make_param("from", "String", "0.0", "From", "Current value.", "expression"), F.make_param("to", "String", "1.0", "To", "Target value.", "expression"), F.make_param("amount", "String", "0.1", "Amount", "Max step toward target.", "expression")], CAT, "move_toward({from}, {to}, {amount})")
		.described("Nudges a value toward a target by a set step, great for smooth changes."))
	descriptors.append(F.make_descriptor("Core", "WrapValue", "Wrap", ACEDescriptor.ACEType.EXPRESSION, "wrapf({value}, {min}, {max})", "", [F.make_param("value", "String", "0.0", "Value", "Value to wrap.", "expression"), F.make_param("min", "String", "0.0", "Min", "Lower bound.", "expression"), F.make_param("max", "String", "1.0", "Max", "Upper bound.", "expression")], CAT, "wrap({value}, {min}, {max})")
		.described("Wraps a value to stay within a range, looping past the edges back around."))
	descriptors.append(F.make_descriptor("Core", "RemapValue", "Remap Range", ACEDescriptor.ACEType.EXPRESSION, "remap({value}, {in_min}, {in_max}, {out_min}, {out_max})", "", [F.make_param("value", "String", "0.0", "Value", "Value to remap.", "expression"), F.make_param("in_min", "String", "0.0", "In min", "Input range start.", "expression"), F.make_param("in_max", "String", "1.0", "In max", "Input range end.", "expression"), F.make_param("out_min", "String", "0.0", "Out min", "Output range start.", "expression"), F.make_param("out_max", "String", "1.0", "Out max", "Output range end.", "expression")], CAT, "remap({value}, …)")
		.described("Rescales a number from one range into another, like mapping 0-100 onto 0-1."))
	# Phase 4 math expressions (siblings to Abs/Min/Max): common one-liners that used to force a RawCode
	# expression. Pure ƒx-field expressions; defaults compile under builtin_ace_compile_test.
	descriptors.append(F.make_descriptor("Core", "SquareRoot", "Square Root", ACEDescriptor.ACEType.EXPRESSION, "sqrt({value})", "", [F.make_param("value", "String", "1.0", "Value", "Value (>= 0).", "expression")], CAT, "sqrt({value})")
		.described("Returns the square root of a number."))
	descriptors.append(F.make_descriptor("Core", "PowValue", "Power", ACEDescriptor.ACEType.EXPRESSION, "pow({base}, {exp})", "", [F.make_param("base", "String", "2.0", "Base", "Base value.", "expression"), F.make_param("exp", "String", "2.0", "Exponent", "Exponent.", "expression")], CAT, "pow({base}, {exp})")
		.described("Raises a base number to an exponent power, like 2 to the 8th."))
	descriptors.append(F.make_descriptor("Core", "FloorValue", "Floor", ACEDescriptor.ACEType.EXPRESSION, "floor({value})", "", [F.make_param("value", "String", "0.0", "Value", "Round down to the nearest integer.", "expression")], CAT, "floor({value})")
		.described("Rounds a number down to the nearest whole number."))
	descriptors.append(F.make_descriptor("Core", "CeilValue", "Ceil", ACEDescriptor.ACEType.EXPRESSION, "ceil({value})", "", [F.make_param("value", "String", "0.0", "Value", "Round up to the nearest integer.", "expression")], CAT, "ceil({value})")
		.described("Rounds a number up to the nearest whole number."))
	descriptors.append(F.make_descriptor("Core", "FmodValue", "Float Modulo", ACEDescriptor.ACEType.EXPRESSION, "fmod({a}, {b})", "", [F.make_param("a", "String", "0.0", "A", "Dividend.", "expression"), F.make_param("b", "String", "1.0", "B", "Divisor.", "expression")], CAT, "fmod({a}, {b})")
		.described("Returns the remainder after dividing one number by another."))
	descriptors.append(F.make_descriptor("Core", "EaseValue", "Ease", ACEDescriptor.ACEType.EXPRESSION, "ease({value}, {curve})", "", [F.make_param("value", "String", "0.0", "Value", "A 0..1 input.", "expression"), F.make_param("curve", "String", "2.0", "Curve", "Easing exponent (>1 ease-in, <1 ease-out).", "expression")], CAT, "ease({value}, {curve})")
		.described("Bends a 0-to-1 value along an easing curve for smoother eased motion."))
	descriptors.append(F.make_descriptor("Core", "SnappedValue", "Snapped", ACEDescriptor.ACEType.EXPRESSION, "snappedf({value}, {step})", "", [F.make_param("value", "String", "0.0", "Value", "Value to snap.", "expression"), F.make_param("step", "String", "1.0", "Step", "Snap increment (e.g. grid size).", "expression")], CAT, "snappedf({value}, {step})")
		.described("Snaps a value to the nearest multiple of a step, like a grid."))
	# Load a resource at runtime into a variable. (preload is parse-time only - author it as a RawCode
	# const where a compile-time scene is required; a placeholder-defaulted preload can't compile-test.)
	descriptors.append(F.make_descriptor("Core", "LoadResource", "Load Resource", ACEDescriptor.ACEType.EXPRESSION, "load({path})", "", [F.make_param("path", "String", "\"res://\"", "Path", "res:// path to the resource/scene.", "expression")], CAT, "load({path})")
		.described("Loads a scene or resource from a res:// path so you can use it."))
	# Trig + interpolation - the vocabulary that lets oscillation/rotation/easing behaviours (sine
	# wobble, orbit, look-at, smooth follow) be authored as ƒx expressions instead of a RawCode block.
	descriptors.append(F.make_descriptor("Core", "SinValue", "Sine", ACEDescriptor.ACEType.EXPRESSION, "sin({value})", "", [F.make_param("value", "String", "0.0", "Value", "Angle in radians.", "expression")], CAT, "sin({value})")
		.described("Returns the sine of an angle in radians, handy for waves and circular motion."))
	descriptors.append(F.make_descriptor("Core", "CosValue", "Cosine", ACEDescriptor.ACEType.EXPRESSION, "cos({value})", "", [F.make_param("value", "String", "0.0", "Value", "Angle in radians.", "expression")], CAT, "cos({value})")
		.described("Returns the cosine of an angle in radians, handy for waves and circular motion."))
	descriptors.append(F.make_descriptor("Core", "TanValue", "Tangent", ACEDescriptor.ACEType.EXPRESSION, "tan({value})", "", [F.make_param("value", "String", "0.0", "Value", "Angle in radians.", "expression")], CAT, "tan({value})")
		.described("Returns the tangent of an angle given in radians."))
	descriptors.append(F.make_descriptor("Core", "Atan2Value", "Arc Tangent (y, x)", ACEDescriptor.ACEType.EXPRESSION, "atan2({y}, {x})", "", [F.make_param("y", "String", "0.0", "Y", "Y component.", "expression"), F.make_param("x", "String", "1.0", "X", "X component.", "expression")], CAT, "atan2({y}, {x})")
		.described("Returns the angle (in radians) pointing toward a given y and x direction."))
	# (Lerp already lives in Core.) clampf is the float-typed clamp for ƒx expressions.
	descriptors.append(F.make_descriptor("Core", "ClampFloatValue", "Clamp (float)", ACEDescriptor.ACEType.EXPRESSION, "clampf({value}, {min}, {max})", "", [F.make_param("value", "String", "0.0", "Value", "Value to clamp.", "expression"), F.make_param("min", "String", "0.0", "Min", "Lower bound.", "expression"), F.make_param("max", "String", "1.0", "Max", "Upper bound.", "expression")], CAT, "clampf({value}, {min}, {max})")
		.described("Keeps a number from going below a minimum or above a maximum."))
	descriptors.append(F.make_descriptor("Core", "DegToRadValue", "Degrees To Radians", ACEDescriptor.ACEType.EXPRESSION, "deg_to_rad({degrees})", "", [F.make_param("degrees", "String", "0.0", "Degrees", "Angle in degrees.", "expression")], CAT, "deg_to_rad({degrees})")
		.described("Converts an angle from degrees into radians for math functions."))
	descriptors.append(F.make_descriptor("Core", "RadToDegValue", "Radians To Degrees", ACEDescriptor.ACEType.EXPRESSION, "rad_to_deg({radians})", "", [F.make_param("radians", "String", "0.0", "Radians", "Angle in radians.", "expression")], CAT, "rad_to_deg({radians})")
		.described("Converts an angle from radians back into easier-to-read degrees."))
	descriptors.append(F.make_descriptor("Core", "FormatString", "Format String", ACEDescriptor.ACEType.EXPRESSION, "{template} % [{args}]", "", [F.make_param("template", "String", "\"Score: %d\"", "Template", "Format string (printf-style).", "expression"), F.make_param("args", "String", "0", "Arguments", "Comma-separated values for the placeholders.", "expression")], CAT, "{template} % [{args}]")
		.described("Builds a text string by filling placeholders with your values, like scores."))
	# Set a node's text from a printf-style template in one row (replaces a RawCode block).
	descriptors.append(F.make_descriptor("Core", "SetTextFormatted", "Set Text (formatted)", ACEDescriptor.ACEType.ACTION, "{target}.text = {template} % [{args}]", "", [F.make_param("target", "String", "self", "Target", "Node with a text property (Label, RichTextLabel, Button…).", "expression"), F.make_param("template", "String", "\"Score: %d\"", "Template", "printf-style format string.", "expression"), F.make_param("args", "String", "0", "Arguments", "Comma-separated values for the placeholders (must match the format).", "expression")], CAT, "set {target} text = {template}")
		.described("Sets a label or button's text using a format string filled with your values."))

	return descriptors
