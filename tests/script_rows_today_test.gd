@tool
class_name ScriptRowsTodayTest
extends RefCounted

# Godot EventSheets - what a user's own script reads as TODAY, pinned before the readings are unified.
#
# A script reaches the picker through three separate readings: the registered-script reading
# (EventSheetACEGenerator, annotations and all), the "Your classes" reading (EventSheetClassDBSource,
# plain reflection) and the member list behind the "Methods in this project" shelf
# (EventSheetScriptMembers). Each is dumped here for the same five real files, as plain text, and
# compared with the committed text beside the fixtures. A later change that moves a reading moves a
# line of that text, which is then a visible, reviewed edit rather than a silent drift.
#
# The fixtures are real files because the annotation reader works off disk: a script built from a
# source string has no path and every annotation would silently do nothing.

const SUPPORT := preload("res://tests/support.gd")
const FIXTURE_DIR: String = "res://tests/fixtures/script_rows/"
const EXPECTED_PATH: String = "res://tests/fixtures/script_rows/expected_today.txt"
## fixture file -> the class name the "Your classes" reading is asked for it under
const FIXTURES: Array = [
	["node_thing.gd", "ScriptRowsNodeThing"],
	["resource_thing.gd", "ScriptRowsResourceThing"],
	["static_only.gd", "ScriptRowsStaticOnly"],
	["loose_thing.gd", "ScriptRowsLooseThing"],
	["annotated_twin.gd", "ScriptRowsAnnotatedTwin"],
]


static func run() -> bool:
	var expected: String = FileAccess.get_file_as_string(EXPECTED_PATH)
	var actual: String = dump()
	var ok: bool = true
	var expected_sections: Dictionary = _sections(expected)
	var actual_sections: Dictionary = _sections(actual)
	ok = SUPPORT.check("script_rows_today_test", "the same sections are dumped",
		actual_sections.keys(), expected_sections.keys()) and ok
	for key: Variant in actual_sections.keys():
		ok = SUPPORT.check("script_rows_today_test", str(key),
			actual_sections[key], expected_sections.get(key, "<missing>")) and ok
	return ok


## The whole text: one section per reading per fixture, `## <reading> <file>` then one line a member.
static func dump() -> String:
	var out: PackedStringArray = PackedStringArray()
	for entry: Array in FIXTURES:
		var file: String = str(entry[0])
		var path: String = FIXTURE_DIR + file
		out.append("## registered %s" % file)
		out.append_array(registered_lines(path))
		out.append("## your_classes %s" % file)
		out.append_array(your_classes_lines(path, str(entry[1])))
		out.append("## members %s" % file)
		out.append_array(member_lines(path))
	return "\n".join(out) + "\n"


static func registered_lines(path: String) -> PackedStringArray:
	var script: Script = load(path) as Script
	return _fingerprints(EventSheetACEGenerator.new().reflect_script(script))


## The "Your classes" door's reading of a script, asked for the class card `class_text`: the one reading
## every script goes through now. The script is handed in, so no class cache has to know the fixture.
static func your_classes_lines(path: String, class_text: String) -> PackedStringArray:
	var reader: GDScript = load("res://addons/eventsheet/ace/script_reader.gd")
	return _fingerprints(reader.definitions_for(class_text, load(path) as Script, ""))


static func member_lines(path: String) -> PackedStringArray:
	var read: Dictionary = EventSheetScriptMembers.of_script(path)
	var lines: PackedStringArray = PackedStringArray()
	for kind: String in ["methods", "signals", "properties"]:
		for member: Dictionary in (read[kind] as Array):
			lines.append("%s | %s | args=%s | ret=%s | doc=%s" % [kind, str(member.get("name", "")),
				str(member.get("args", "")), str(member.get("ret", "")), str(member.get("doc", ""))])
	lines.append("base=%s" % str(read.get("base", "")))
	return lines


static func _fingerprints(definitions: Array[ACEDefinition]) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for definition: ACEDefinition in definitions:
		var params: PackedStringArray = PackedStringArray()
		for parameter: Variant in definition.parameters:
			var param: Dictionary = parameter
			params.append("%s:%s:%s:%s" % [str(param.get("id", "")), type_string(int(param.get("type", 0))),
				str(param.get("default_value", "")), str(param.get("hint", ""))])
		lines.append(" | ".join([definition.id, _type_word(definition.ace_type), definition.display_name,
			definition.category, str(definition.metadata.get("display_template", "")),
			str(definition.metadata.get("codegen_template", "")), ", ".join(params)]) + (" | not offered" if bool(definition.metadata.get("deprecated", false)) else ""))
	return lines


static func _type_word(ace_type: int) -> String:
	match ace_type:
		ACEDefinition.ACEType.ACTION:
			return "action"
		ACEDefinition.ACEType.CONDITION:
			return "condition"
		ACEDefinition.ACEType.EXPRESSION:
			return "expression"
		ACEDefinition.ACEType.TRIGGER:
			return "trigger"
	return "?"


static func _sections(text: String) -> Dictionary:
	var sections: Dictionary = {}
	var current: String = ""
	var body: PackedStringArray = PackedStringArray()
	for line: String in text.split("\n"):
		if line.begins_with("## "):
			if not current.is_empty():
				sections[current] = "\n".join(body)
			current = line.trim_prefix("## ")
			body = PackedStringArray()
		elif not line.is_empty():
			body.append(line)
	if not current.is_empty():
		sections[current] = "\n".join(body)
	return sections
