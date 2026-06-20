# EventForge module — Helper vocabulary (the "structured escape hatch").
#
# These ACEs exist for the GDScript a user would otherwise drop to a raw block for: setting
# an arbitrary property, calling an arbitrary method, a one-line statement, a ternary, a
# null-check, a runtime signal connection, the math/string idioms not covered elsewhere.
# Every template is a single, direct GDScript line (parity covenant — no plugin indirection,
# no reflection helpers), so picking a helper keeps logic as an editable row instead of an
# opaque code block while compiling to exactly what you'd have hand-written.
#
# Design rule: these are deliberately GENERIC (target/property/method/code are free
# expressions) so one helper replaces a whole family of one-off raw blocks. Where a typed,
# specific ACE already exists (SetPosition2D, Wait, Clamp, Choose, array/dict ops…), prefer
# it — these fill the gaps, they don't shadow the curated vocabulary.
#
# Module contract: see ace_factory.gd — ace_ids/templates are API (compatibility covenant);
# this file only changes where the descriptors are AUTHORED.
@tool
extends RefCounted
class_name EventForgeHelperACEs

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Helpers"

static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Generic node access (the biggest gap: reach any property/method without a block) ──
	# Set/Get ANY property by name on any target ("self" by default). property is a bare
	# identifier (e.g. modulate), not a quoted string, so it stays typed + fast.
	descriptors.append(F.make_descriptor("Core", "SetProperty", "Set Property", ACEDescriptor.ACEType.ACTION, "{target}.{property} = {value}", "", [F.make_param("target", "String", "self", "Target", "Node/object expression (self, $Path, a variable).", "expression"), F.make_param("property", "String", "modulate", "Property", "Property name (e.g. modulate, visible, position).", "property_reference"), F.make_param("value", "String", "Color.WHITE", "Value", "Value expression to assign.", "expression")], CAT, "set {target}.{property} = {value}"))
	descriptors.append(F.make_descriptor("Core", "GetProperty", "Get Property", ACEDescriptor.ACEType.EXPRESSION, "{target}.{property}", "", [F.make_param("target", "String", "self", "Target", "Node/object expression.", "expression"), F.make_param("property", "String", "visible", "Property", "Property name to read.", "property_reference")], CAT, "{target}.{property}"))
	# Call ANY method, as a fire-and-forget action or as a value-returning expression.
	descriptors.append(F.make_descriptor("Core", "CallMethod", "Call Method", ACEDescriptor.ACEType.ACTION, "{target}.{method}({args})", "", [F.make_param("target", "String", "self", "Target", "Node/object expression.", "expression"), F.make_param("method", "String", "queue_free", "Method", "Method name to call.", "method_reference"), F.make_param("args", "String", "", "Arguments", "Comma-separated argument expressions (may be empty).", "expression")], CAT, "{target}.{method}({args})"))
	descriptors.append(F.make_descriptor("Core", "CallMethodValue", "Call Method (value)", ACEDescriptor.ACEType.EXPRESSION, "{target}.{method}({args})", "", [F.make_param("target", "String", "self", "Target", "Node/object expression.", "expression"), F.make_param("method", "String", "get_index", "Method", "Method name to call.", "method_reference"), F.make_param("args", "String", "", "Arguments", "Comma-separated argument expressions.", "expression")], CAT, "{target}.{method}({args})"))
	descriptors.append(F.make_descriptor("Core", "GetNode", "Get Node", ACEDescriptor.ACEType.EXPRESSION, "get_node({path})", "", [F.make_param("path", "String", "\"Sprite2D\"", "Path", "Node path string (e.g. \"Sprite2D\" or \"../Enemy\").", "expression")], CAT, "get_node({path})"))

	# ── The universal escape, but pickable: a raw statement/expression as a real ACE row ──
	# RunGDScript is one statement (still an editable, searchable, codegen-tooltipped row
	# rather than a multi-line block). The Evaluate pair lets any inline expression stand in
	# as a condition or a value.
	descriptors.append(F.make_descriptor("Core", "RunGDScript", "Run GDScript", ACEDescriptor.ACEType.ACTION, "{code}", "", [F.make_param("code", "String", "pass", "Code", "A single GDScript statement to run here.", "expression")], CAT, "run: {code}"))
	descriptors.append(F.make_descriptor("Core", "EvaluateGDScript", "Evaluate GDScript", ACEDescriptor.ACEType.CONDITION, "({code})", "", [F.make_param("code", "String", "true", "Code", "A GDScript boolean expression.", "expression")], CAT, "({code})"))
	descriptors.append(F.make_descriptor("Core", "EvaluateExpression", "Evaluate Expression", ACEDescriptor.ACEType.EXPRESSION, "({code})", "", [F.make_param("code", "String", "0", "Code", "Any GDScript value expression.", "expression")], CAT, "({code})"))

	# ── Control-flow helpers that don't warrant a whole row structure ──
	descriptors.append(F.make_descriptor("Core", "InlineIf", "Inline If (ternary)", ACEDescriptor.ACEType.EXPRESSION, "({true_value} if {condition} else {false_value})", "", [F.make_param("true_value", "String", "1", "If true", "Value when the condition holds.", "expression"), F.make_param("condition", "String", "true", "Condition", "Boolean expression.", "expression"), F.make_param("false_value", "String", "0", "If false", "Value otherwise.", "expression")], CAT, "{true_value} if {condition} else {false_value}"))
	descriptors.append(F.make_descriptor("Core", "ToggleBool", "Toggle Boolean", ACEDescriptor.ACEType.ACTION, "{var_name} = not {var_name}", "", [F.make_param("var_name", "String", "var", "Variable", "Boolean variable to flip.", "variable_reference")], CAT, "toggle {var_name}"))
	# Declares an event-local temp later actions in the same event body can reference.
	descriptors.append(F.make_descriptor("Core", "SetLocalVar", "Set Local Variable", ACEDescriptor.ACEType.ACTION, "var {name} = {value}", "", [F.make_param("name", "String", "temp", "Name", "Local variable name (scoped to this event body)."), F.make_param("value", "String", "0", "Value", "Initial value expression.", "expression")], CAT, "var {name} = {value}"))

	# ── Validity / null (freed-instance safety, the classic source of crashes) ──
	descriptors.append(F.make_descriptor("Core", "IsValid", "Is Valid", ACEDescriptor.ACEType.CONDITION, "is_instance_valid({target})", "", [F.make_param("target", "String", "self", "Target", "Object expression to test.", "expression")], CAT, "{target} is valid"))
	descriptors.append(F.make_descriptor("Core", "IsNull", "Is Null", ACEDescriptor.ACEType.CONDITION, "{target} == null", "", [F.make_param("target", "String", "self", "Target", "Expression to test for null.", "expression")], CAT, "{target} is null"))

	# ── Runtime signal wiring (connect/disconnect without a _ready block) ──
	descriptors.append(F.make_descriptor("Core", "ConnectSignal", "Connect Signal", ACEDescriptor.ACEType.ACTION, "{source}.{signal}.connect({callable})", "", [F.make_param("source", "String", "self", "Source", "Object emitting the signal.", "expression"), F.make_param("signal", "String", "pressed", "Signal", "Signal name."), F.make_param("callable", "String", "_on_pressed", "Callable", "Method/Callable to connect.", "expression")], CAT, "connect {source}.{signal} -> {callable}"))
	descriptors.append(F.make_descriptor("Core", "DisconnectSignal", "Disconnect Signal", ACEDescriptor.ACEType.ACTION, "{source}.{signal}.disconnect({callable})", "", [F.make_param("source", "String", "self", "Source", "Object emitting the signal.", "expression"), F.make_param("signal", "String", "pressed", "Signal", "Signal name."), F.make_param("callable", "String", "_on_pressed", "Callable", "Method/Callable to disconnect.", "expression")], CAT, "disconnect {source}.{signal} -> {callable}"))

	# ── Math/string idioms not already covered (Clamp/Lerp/Choose/Random live in Core) ──
	descriptors.append(F.make_descriptor("Core", "AbsValue", "Absolute Value", ACEDescriptor.ACEType.EXPRESSION, "abs({value})", "", [F.make_param("value", "String", "0", "Value", "Value.", "expression")], CAT, "abs({value})"))
	descriptors.append(F.make_descriptor("Core", "MinValue", "Min", ACEDescriptor.ACEType.EXPRESSION, "min({a}, {b})", "", [F.make_param("a", "String", "0", "A", "First value.", "expression"), F.make_param("b", "String", "0", "B", "Second value.", "expression")], CAT, "min({a}, {b})"))
	descriptors.append(F.make_descriptor("Core", "MaxValue", "Max", ACEDescriptor.ACEType.EXPRESSION, "max({a}, {b})", "", [F.make_param("a", "String", "0", "A", "First value.", "expression"), F.make_param("b", "String", "0", "B", "Second value.", "expression")], CAT, "max({a}, {b})"))
	descriptors.append(F.make_descriptor("Core", "RoundValue", "Round", ACEDescriptor.ACEType.EXPRESSION, "round({value})", "", [F.make_param("value", "String", "0.0", "Value", "Value to round.", "expression")], CAT, "round({value})"))
	descriptors.append(F.make_descriptor("Core", "SignValue", "Sign", ACEDescriptor.ACEType.EXPRESSION, "sign({value})", "", [F.make_param("value", "String", "0", "Value", "Value (-1/0/1).", "expression")], CAT, "sign({value})"))
	descriptors.append(F.make_descriptor("Core", "MoveTowardValue", "Move Toward", ACEDescriptor.ACEType.EXPRESSION, "move_toward({from}, {to}, {amount})", "", [F.make_param("from", "String", "0.0", "From", "Current value.", "expression"), F.make_param("to", "String", "1.0", "To", "Target value.", "expression"), F.make_param("amount", "String", "0.1", "Amount", "Max step toward target.", "expression")], CAT, "move_toward({from}, {to}, {amount})"))
	descriptors.append(F.make_descriptor("Core", "WrapValue", "Wrap", ACEDescriptor.ACEType.EXPRESSION, "wrapf({value}, {min}, {max})", "", [F.make_param("value", "String", "0.0", "Value", "Value to wrap.", "expression"), F.make_param("min", "String", "0.0", "Min", "Lower bound.", "expression"), F.make_param("max", "String", "1.0", "Max", "Upper bound.", "expression")], CAT, "wrap({value}, {min}, {max})"))
	descriptors.append(F.make_descriptor("Core", "RemapValue", "Remap Range", ACEDescriptor.ACEType.EXPRESSION, "remap({value}, {in_min}, {in_max}, {out_min}, {out_max})", "", [F.make_param("value", "String", "0.0", "Value", "Value to remap.", "expression"), F.make_param("in_min", "String", "0.0", "In min", "Input range start.", "expression"), F.make_param("in_max", "String", "1.0", "In max", "Input range end.", "expression"), F.make_param("out_min", "String", "0.0", "Out min", "Output range start.", "expression"), F.make_param("out_max", "String", "1.0", "Out max", "Output range end.", "expression")], CAT, "remap({value}, …)"))
	descriptors.append(F.make_descriptor("Core", "FormatString", "Format String", ACEDescriptor.ACEType.EXPRESSION, "{template} % [{args}]", "", [F.make_param("template", "String", "\"Score: %d\"", "Template", "Format string (printf-style).", "expression"), F.make_param("args", "String", "0", "Arguments", "Comma-separated values for the placeholders.", "expression")], CAT, "{template} % [{args}]"))

	return descriptors
