# Godot EventSheets - a built pack leaves out the member lines that only repeat the class's own.
#
# A pack that names its icon and its category once on the class (`@icon`, `## @ace_category`) used to
# write the same two lines again above every verb. The reader gives a member the class's icon and
# category when it has none of its own, so the repeats say nothing: a sheet built from rows now writes
# them only where they differ, and a file opened from disk keeps the lines it has, so opening and saving
# one never moves a byte.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "member_annotation_repeats_test"
const ICON := "res://addons/eventsheet/icons/eventsheet.svg"


static func run() -> bool:
	var ok: bool = true
	ok = _built_sheet_writes_each_thing_once() and ok
	ok = _what_differs_is_kept() and ok
	ok = _an_opened_file_keeps_its_lines() and ok
	ok = _the_reader_sees_the_same_verbs() and ok
	return ok


static func _sheet(class_name_text: String, category: String, member_category: String, icon: String) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.behavior_mode = true
	sheet.custom_class_name = class_name_text
	sheet.custom_class_icon = icon
	sheet.addon_category = category
	var verb: EventFunction = EventFunction.new()
	verb.function_name = "wave"
	verb.expose_as_ace = true
	verb.ace_display_name = "Wave"
	verb.ace_category = member_category
	verb.description = "Waves."
	var body: EventRow = EventRow.new()
	verb.events.append(body)
	sheet.functions.append(verb)
	return sheet


static func _built_sheet_writes_each_thing_once() -> bool:
	var out: String = SUPPORT.compile_output(_sheet("MemberRepeatProbe", "Motion", "Motion", ICON), SUPPORT.own_path("member_repeat_a.gd"))
	var ok: bool = SUPPORT.check(P, "the class names its category once", out.count("@ace_category(\"Motion\")"), 1)
	ok = SUPPORT.check(P, "the class names its icon once", out.count("\"%s\"" % ICON), 1) and ok
	ok = SUPPORT.check(P, "the member keeps its own name and description", out.contains("@ace_name(\"Wave\")") and out.contains("@ace_description(\"Waves.\")"), true) and ok
	return ok


static func _what_differs_is_kept() -> bool:
	var other: String = SUPPORT.compile_output(_sheet("MemberRepeatProbeB", "Motion", "Waves", ICON), SUPPORT.own_path("member_repeat_b.gd"))
	var ok: bool = SUPPORT.check(P, "a member with a category of its own keeps the line", other.count("@ace_category"), 2)
	var no_class: String = SUPPORT.compile_output(_sheet("", "Motion", "Motion", ICON), SUPPORT.own_path("member_repeat_c.gd"))
	ok = SUPPORT.check(P, "a sheet with no class name writes no class icon, so the member keeps its icon line", no_class.contains("# @ace_icon(\"%s\")" % ICON), true) and ok
	return ok


## The file as the old compiler wrote it, with both repeated lines, opens and saves back to the same bytes.
static func _an_opened_file_keeps_its_lines() -> bool:
	var old_form: String = "@tool\n## @ace_category(\"Motion\")\n@icon(\"%s\")\nclass_name MemberRepeatOld\nextends Node2D\n\n## @ace_action\n## @ace_name(\"Wave\")\n## @ace_category(\"Motion\")\n## @ace_description(\"Waves.\")\n## @ace_icon(\"%s\")\n## @ace_codegen_template(\"$MemberRepeatOld.wave()\")\nfunc wave() -> void:\n\tpass\n" % [ICON, ICON]
	return SUPPORT.check(P, "an old-form file with the repeated lines round trips", EventSheets.round_trips(old_form), true)


## A pack written without the repeats reads the same verbs, categories and icons as the one with them.
static func _the_reader_sees_the_same_verbs() -> bool:
	var with_lines: String = "@tool\n## @ace_category(\"Motion\")\n@icon(\"%s\")\nclass_name MemberRepeatRead\nextends Node2D\n\n## @ace_action\n## @ace_name(\"Wave\")\n## @ace_category(\"Motion\")\n## @ace_description(\"Waves.\")\n## @ace_icon(\"%s\")\n## @ace_codegen_template(\"$MemberRepeatRead.wave()\")\nfunc wave() -> void:\n\tpass\n" % [ICON, ICON]
	var without: String = with_lines.replace("## @ace_category(\"Motion\")\n## @ace_description", "## @ace_description").replace("## @ace_icon(\"%s\")\n" % ICON, "")
	var ok: bool = SUPPORT.check(P, "the copy without the repeats still has its other lines", without.contains("@ace_name(\"Wave\")"), true)
	ok = SUPPORT.check(P, "and has lost exactly the two repeats", with_lines.length() - without.length() > 40, true) and ok
	ok = SUPPORT.check(P, "the lean copy opens and saves back byte for byte", EventSheets.round_trips(without), true) and ok
	var opened: EventSheetResource = EventSheetGDScriptImporter.new().import_external_source(without)
	var lifted: EventFunction = EventSheetCompiler._find_function_by_name(opened, "wave")
	ok = SUPPORT.check(P, "the lean copy still opens its verb as a function row, not a code block", lifted != null and lifted.expose_as_ace, true) and ok
	ok = SUPPORT.check(P, "the lean copy reads the same definitions", _definitions(without, "lean"), _definitions(with_lines, "full")) and ok
	return ok


static func _definitions(text: String, key: String) -> PackedStringArray:
	var path: String = SUPPORT.own_path("member_repeat_%s.gd" % key)
	var renamed: String = text.replace("MemberRepeatRead", "MemberRepeatRead_" + key)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(renamed)
	file.close()
	var script: Script = load(path)
	var out: Array = []
	for definition: ACEDefinition in EventSheetACEGenerator.new().generate_from_script(script):
		var parts: PackedStringArray = PackedStringArray()
		for property: Dictionary in definition.get_property_list():
			if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
				parts.append("%s=%s" % [property["name"], var_to_str(definition.get(str(property["name"])))])
		out.append(" ".join(parts).replace(path, "P").replace("MemberRepeatRead_" + key, "X"))
	out.sort()
	return PackedStringArray(out)
