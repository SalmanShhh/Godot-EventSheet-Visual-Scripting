# EventForge module - Console vocabulary (browser/console-style logging).
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

	# Bare immediate log to any stream - the familiar "Log message" with a type dropdown. The trailing
	# `# @ace:Core.ConsoleLog` marker rides the line so it reverse-lifts back AS this combined verb:
	# without it, a `push_warning("x")` line is identical to (and shadowed by) the specific Push Warning
	# verb, so it would silently reopen as that. The marker makes this verb's reverse-template distinct
	# (Push Warning's `$`-anchored regex rejects the trailing comment), so a marked line lifts here and a
	# plain hand-written one still lifts to Push Warning. The call runs untouched in-game - the comment
	# is inert. The only cost is that one comment in the generated line.
	descriptors.append(F.act("ConsoleLog", "Log", "{level}({message})" + LOG_MARKER, "Debug", "log {message}", "Writes a message to the console as a Message, Warning, Error, or Rich text - one action for all four.").param("message", "\"hello\"", "Message", "Value/expression to write to the console.", "expression").param_built(_level_param()).rich_text_when("level", "print_rich"))

	# Conditional log - write only when a test holds, without wrapping it in its own event row.
	descriptors.append(F.act("ConsoleLogIf", "Log If", "if {condition}: {level}({message})", "Debug", "log {message} if {condition}", "Writes a message to the console only when a condition is true - as a Message, Warning, or Error.").param("condition", "true", "If", "Only log when this is true.", "expression").param("message", "\"low health\"", "Message", "Value/expression to write to the console.", "expression").param_built(_level_param()).rich_text_when("level", "print_rich"))

	# Debug-builds-only log - compiled out of exported release games (the first OS.is_debug_build guard).
	descriptors.append(F.act("ConsoleDebugLog", "Log (Debug Builds Only)", "if OS.is_debug_build(): {level}({message})", "Debug", "log {message} (debug only)", "Writes to the console only in debug builds - the line is skipped entirely in an exported release game.").param("message", "\"trace\"", "Message", "Value/expression to write to the console.", "expression").param_built(_level_param()).rich_text_when("level", "print_rich"))

	# Labeled value dump - "name = value" in one go, to any stream. Distinct `("%s = %s" % …)` shape.
	descriptors.append(F.act("ConsoleLogValue", "Log Value", "{level}(\"%s = %s\" % [{label}, {value}])", "Debug", "log {label} = {value}", "Prints a value tagged with a name, e.g. \"health = 80\", so debug lines are easy to tell apart.").param("label", "\"value\"", "Label", "Name shown before the value.", "expression").param("value", "0", "Value", "Value/expression to print after the label.", "expression").param_built(_level_param()).rich_text_when("level", "print_rich"))

	# Variant -> printable text, for building a readable log line out of any value.
	descriptors.append(F.expr("Stringify", "To Text", "var_to_str({value})", "Debug", "text of {value}", "Turns any value (numbers, vectors, arrays…) into readable text for a log message.").param("value", "self", "Value", "Any value to turn into readable text.", "expression"))

	return descriptors
