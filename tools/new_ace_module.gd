# Scaffolds a new builtin ACE helper MODULE - the helper for creating helper modules.
#
# A helper module is one file in addons/eventforge/registration/modules/ that exposes
# `static func get_descriptors() -> Array[ACEDescriptor]` (and, optionally, section_descriptions()).
# The registry auto-discovers it on the next load - no wiring to edit. This tool writes a compiling
# skeleton with one example Action, Condition, and Expression plus a section description, so a beginner
# starts from something that already builds and passes the gates, and just edits the ACEs.
#
# Use it:
#   1. Set MODULE_NAME below (snake_case, no "_aces" suffix), for example "weather".
#   2. Run: godot --headless --path . --script tools/new_ace_module.gd
#   3. Open the printed file and replace the example ACEs with your own.
#   4. Regenerate the class cache once (a new class_name was added):
#      godot --editor --headless --path . --quit-after 3   then   git checkout -- project.godot
#
# It never overwrites an existing module. The ace_id you keep is a permanent compatibility promise once
# shipped (deprecate, never rename), and every template must compile to plain Godot (no plugin classes).
@tool
extends SceneTree

## The new module's base name (snake_case, WITHOUT the "_aces" suffix). "weather" -> weather_aces.gd,
## class EventForgeWeatherACEs, category "Weather".
const MODULE_NAME := "example"

const MODULES_DIR := "res://addons/eventforge/registration/modules/"


func _init() -> void:
	var base: String = MODULE_NAME.strip_edges().to_lower()
	if base.is_empty() or not base.is_valid_identifier():
		push_error("[new_ace_module] MODULE_NAME must be a snake_case identifier, got: '%s'" % MODULE_NAME)
		quit()
		return
	var path: String = "%s%s_aces.gd" % [MODULES_DIR, base]
	if FileAccess.file_exists(path):
		push_error("[new_ace_module] %s already exists - pick another MODULE_NAME." % path)
		quit()
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[new_ace_module] could not write %s" % path)
		quit()
		return
	file.store_string(_skeleton(base))
	file.close()
	print("[new_ace_module] wrote %s - edit the example ACEs, then regenerate the class cache." % path)
	quit()


## Turns "poison_gas" into "PoisonGas" (for the class name) and "Poison Gas" (for the category).
static func _pascal(base: String) -> String:
	var out: String = ""
	for part: String in base.split("_", false):
		if not part.is_empty():
			out += part.substr(0, 1).to_upper() + part.substr(1)
	return out


static func _titled(base: String) -> String:
	var words: PackedStringArray = PackedStringArray()
	for part: String in base.split("_", false):
		if not part.is_empty():
			words.append(part.substr(0, 1).to_upper() + part.substr(1))
	return " ".join(words)


## The compiling skeleton: one Action, Condition, and Expression plus a section description.
static func _skeleton(base: String) -> String:
	var pascal: String = _pascal(base)
	var category: String = _titled(base)
	var lines: PackedStringArray = PackedStringArray([
		"# EventForge module - %s vocabulary. Describe what these ACEs are for in this comment." % category,
		"#",
		"# Every template compiles to plain Godot (no EventForge / EventSheet classes) so a game that uses",
		"# them keeps working with the plugin removed - the parity covenant. ace_ids + templates are frozen",
		"# once shipped (deprecate, never rename). Replace the three example ACEs below with your own.",
		"@tool",
		"class_name EventForge%sACEs" % pascal,
		"extends RefCounted",
		"",
		"const F := preload(\"res://addons/eventforge/registration/ace_factory.gd\")",
		"",
		"const CAT := \"%s\"" % category,
		"",
		"",
		"static func get_descriptors() -> Array[ACEDescriptor]:",
		"\tvar descriptors: Array[ACEDescriptor] = []",
		"",
		"\t# An ACTION: does something. The 5th argument is the GDScript it bakes to, with {param} placeholders.",
		"\tdescriptors.append(F.make_descriptor(\"Core\", \"%sExample\", \"%s Example\", ACEDescriptor.ACEType.ACTION, \"print({message})\", \"\", [F.make_param(\"message\", \"String\", \"\\\"hello\\\"\", \"Message\", \"What to print.\", \"expression\")], CAT, \"%s example {message}\")" % [pascal, category, category.to_lower()],
		"\t\t.described(\"An example action - replace this with your own.\"))",
		"",
		"\t# A CONDITION: returns true/false.",
		"\tdescriptors.append(F.make_descriptor(\"Core\", \"%sExampleCheck\", \"%s Example Check\", ACEDescriptor.ACEType.CONDITION, \"{value} > 0\", \"\", [F.make_param(\"value\", \"float\", \"1.0\", \"Value\", \"Number to test.\", \"expression\")], CAT, \"%s {value} is positive\")" % [pascal, category, category.to_lower()],
		"\t\t.described(\"An example condition - replace this with your own.\"))",
		"",
		"\t# An EXPRESSION: returns a value you can use in another field.",
		"\tdescriptors.append(F.make_descriptor(\"Core\", \"%sExampleValue\", \"%s Example Value\", ACEDescriptor.ACEType.EXPRESSION, \"absf({value})\", \"\", [F.make_param(\"value\", \"float\", \"-1.0\", \"Value\", \"Number to read.\", \"expression\")], CAT, \"%s absolute {value}\")" % [pascal, category, category.to_lower()],
		"\t\t.described(\"An example expression - replace this with your own.\"))",
		"",
		"\treturn descriptors",
		"",
		"",
		"## Optional: the one-line description shown when this section's header is selected in the ACE picker.",
		"static func section_descriptions() -> Dictionary:",
		"\treturn {CAT: \"Describe the %s helpers here.\"}" % category.to_lower(),
		""
	])
	return "\n".join(lines)
