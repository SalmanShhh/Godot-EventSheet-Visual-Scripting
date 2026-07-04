# EventForge module - Console vocabulary (C3 Browser/console-style logging).
#
# Friendly, combo-driven logging verbs. A single "As" dropdown (Message / Warning / Error) picks the
# output stream - the label is shown, but the matching Godot call (print / push_warning / push_error)
# is what's inserted - so one verb covers all three streams. Each emission is a bare native one-liner
# (parity-clean: a generated game needs no plugin).
#
# Why not a single bare "Log" with just the As combo (the obvious combine)? The reverse-lift is most-
# specific-first, so a generic `{as}({message})` line (e.g. `push_warning("x")`) always lifts back to
# the specific Core/PushWarning verb, never to the combined ACE - a bare combined Log would silently
# become "Push Warning" on reopen. So the plain immediate Print / Push Warning / Push Error stay in
# dev_aces.gd (each round-trips to itself), and the combo lives on verbs whose template is DISTINCT
# (conditional / debug-only / labeled), which reverse-lift cleanly as themselves.
@tool
class_name EventForgeConsoleACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

# The "As" output-stream dropdown: shows a friendly label, inserts the matching Godot call. Reused by
# every verb that can target a stream (the {key,label} option form drives the label↔value split).
const LEVEL_OPTIONS: Array = [
	{"key": "print", "label": "Message"},
	{"key": "push_warning", "label": "Warning"},
	{"key": "push_error", "label": "Error"},
	{"key": "print_rich", "label": "Rich text (BBCode)"},
]

# The marker that rides a bare Log line so it reverse-lifts back AS the combined verb (see ConsoleLog).
const LOG_MARKER: String = "  # @ace:Core.ConsoleLog"


static func _level_param() -> ACEParam:
	return F.make_param("level", "String", "print", "As", "Which console stream to write to.", "", LEVEL_OPTIONS)


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# Bare immediate log to any stream - the C3 "Log message" with a type dropdown. The trailing
	# `# @ace:Core.ConsoleLog` marker rides the line so it reverse-lifts back AS this combined verb:
	# without it, a `push_warning("x")` line is identical to (and shadowed by) the specific Push Warning
	# verb, so it would silently reopen as that. The marker makes this verb's reverse-template distinct
	# (Push Warning's `$`-anchored regex rejects the trailing comment), so a marked line lifts here and a
	# plain hand-written one still lifts to Push Warning. The call runs untouched in-game - the comment
	# is inert. The only cost is that one comment in the generated line.
	descriptors.append(F.make_descriptor("Core", "ConsoleLog", "Log", ACEDescriptor.ACEType.ACTION,
		"{level}({message})" + LOG_MARKER, "",
		[
			F.make_param("message", "String", "\"hello\"", "Message", "Value/expression to write to the console.", "expression"),
			_level_param(),
		], "Debug", "log {message}")
		.described("Writes a message to the console as a Message, Warning, Error, or Rich text - one verb for all four."))

	# Conditional log - write only when a test holds, without wrapping it in its own event row.
	descriptors.append(F.make_descriptor("Core", "ConsoleLogIf", "Log If", ACEDescriptor.ACEType.ACTION,
		"if {condition}: {level}({message})", "",
		[
			F.make_param("condition", "String", "true", "If", "Only log when this is true.", "expression"),
			F.make_param("message", "String", "\"low health\"", "Message", "Value/expression to write to the console.", "expression"),
			_level_param(),
		], "Debug", "log {message} if {condition}")
		.described("Writes a message to the console only when a condition is true - as a Message, Warning, or Error."))

	# Debug-builds-only log - compiled out of exported release games (the first OS.is_debug_build guard).
	descriptors.append(F.make_descriptor("Core", "ConsoleDebugLog", "Log (Debug Builds Only)", ACEDescriptor.ACEType.ACTION,
		"if OS.is_debug_build(): {level}({message})", "",
		[
			F.make_param("message", "String", "\"trace\"", "Message", "Value/expression to write to the console.", "expression"),
			_level_param(),
		], "Debug", "log {message} (debug only)")
		.described("Writes to the console only in debug builds - the line is skipped entirely in an exported release game."))

	# Labeled value dump - "name = value" in one go, to any stream. Distinct `("%s = %s" % …)` shape.
	descriptors.append(F.make_descriptor("Core", "ConsoleLogValue", "Log Value", ACEDescriptor.ACEType.ACTION,
		"{level}(\"%s = %s\" % [{label}, {value}])", "",
		[
			F.make_param("label", "String", "\"value\"", "Label", "Name shown before the value.", "expression"),
			F.make_param("value", "String", "0", "Value", "Value/expression to print after the label.", "expression"),
			_level_param(),
		], "Debug", "log {label} = {value}")
		.described("Prints a value tagged with a name, e.g. \"health = 80\", so debug lines are easy to tell apart."))

	# Variant -> printable text, for building a readable log line out of any value.
	descriptors.append(F.make_descriptor("Core", "Stringify", "To Text", ACEDescriptor.ACEType.EXPRESSION,
		"var_to_str({value})", "",
		[F.make_param("value", "String", "self", "Value", "Any value to turn into readable text.", "expression")],
		"Debug", "text of {value}")
		.described("Turns any value (numbers, vectors, arrays…) into readable text for a log message."))

	return descriptors
