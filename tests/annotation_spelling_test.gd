# Godot EventSheets - an annotation reads the same with one `#` or two, and an ordinary comment is not one.
#
# Godot shows every `##` line as documentation, so a pack's Help page and Inspector tooltips read
# `@ace_category("Sine") @ace_expose_all(node)`. Newly written annotation lines use `#`; every reader
# accepts both forever, and a file keeps the spelling it has. The pack reader reads annotations OFF
# DISK, so every file here is written to a per-process folder and loaded with load().
#
# Every place that reads the words is asked the same question of a two-hash file, a one-hash file and a
# file that mixes both, and must answer alike. The writers (the compiler, the annotation editor) are
# asked what they write for each.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "annotation_spelling_test"
const PACK := "res://eventsheet_addons/sine/sine_behavior.gd"
const FINDINGS := preload("res://addons/eventsheet/ace/annotation_findings.gd")
const RUNNER := preload("res://addons/eventsheet/editor/test_sheet_runner.gd")

## A small pack as the compiler writes it, two-hash spelling, covering every kind of line the readers look at.
const SAMPLE := """@tool
## @ace_tags(motion, retro)
## @ace_category("Motion")
## @ace_version(1.2.3)
## @ace_requires(Health)
## @ace_provider_id(Spellings)
@icon("res://addons/eventsheet/icons/eventsheet.svg")
class_name SpellingSample
extends Node2D
## Waves a node about.

## @ace_action
## @ace_name("Wave")
## @ace_description("Waves the node.")
## @ace_display_template("Wave {times} times")
## @ace_param(times, default: 3, desc: "How many")
func wave(times: int) -> void:
	pass


## @ace_condition
## @ace_name("Is Waving")
func is_waving() -> bool:
	return true
"""


static func run() -> bool:
	var ok: bool = true
	ok = _the_rule_tells_an_annotation_from_a_comment() and ok
	ok = _the_analyzer_reads_every_spelling_alike() and ok
	ok = _the_other_readers_read_every_spelling_alike() and ok
	ok = _the_importer_keeps_each_file_in_its_spelling() and ok
	ok = _a_comment_that_looks_like_an_annotation_stays_a_comment() and ok
	ok = _the_compiler_writes_one_hash_for_a_built_sheet() and ok
	ok = _a_description_stays_directly_above_its_member() and ok
	ok = _the_annotation_editor_writes_the_spelling_the_file_has() and ok
	return ok


# ── the rule ─────────────────────────────────────────────────────────────────────────────────────


static func _the_rule_tells_an_annotation_from_a_comment() -> bool:
	var rows: Array = [
		["two hashes", "## @ace_hidden", "##"],
		["one hash, a word alone", "# @ace_hidden", "#"],
		["one hash, a closed bracket", "# @ace_name(\"Wave\")", "#"],
		["one hash, indented", "\t# @ace_action", "#"],
		["one hash, a bracket still open", "# @ace_param_options(a=A|", "#"],
		["one hash, prose after the word", "# @ace_hidden is what the old version used", ""],
		["one hash, prose after the bracket", "# @ace_name(\"Wave\") is the label", ""],
		["one hash, a word nobody knows", "# @ace_typo", ""],
		["one hash, the old space form", "# @ace_category Combat", ""],
		["two hashes keep the loose reading, so a typo is still reported", "## @ace_typo", "##"],
		["an ordinary comment", "# a note about @ace_hidden", ""],
		["a decorator", "@export var speed: float", ""],
	]
	var ok: bool = true
	for row: Array in rows:
		ok = SUPPORT.check(P, str(row[0]), EventSheetAnnotationLine.marker_of(str(row[1])), str(row[2])) and ok
	ok = SUPPORT.check(P, "two hashes to one and back", EventSheetAnnotationLine.canonical(EventSheetAnnotationLine.hashed("## @ace_name(\"Wave\")")), "## @ace_name(\"Wave\")") and ok
	ok = SUPPORT.check(P, "a mistyped word keeps its two hashes when a file is written with one", EventSheetAnnotationLine.hashed("## @ace_typo"), "## @ace_typo") and ok
	ok = SUPPORT.check(P, "a file with both spellings is told so", EventSheetAnnotationLine.spelling_of("## @ace_hidden\n# @ace_action\n"), "mixed") and ok
	ok = SUPPORT.check(P, "a file with none says none", EventSheetAnnotationLine.spelling_of("extends Node\n# a plain comment\n"), "none") and ok
	return ok


# ── the analyzer, on the shipped Sine pack ───────────────────────────────────────────────────────


static func _the_analyzer_reads_every_spelling_alike() -> bool:
	var source: String = FileAccess.get_file_as_string(PACK)
	var mixed: PackedStringArray = PackedStringArray()
	var member: int = 0
	for line: String in source.split("\n"):
		if line.begins_with("func ") or line.begins_with("@export") or line.begins_with("signal "):
			member += 1
		mixed.append(EventSheetAnnotationLine.hashed(line) if member % 2 == 0 else line)
	var reading: Dictionary = {
		"two": _definitions_of(source, "two"),
		"one": _definitions_of(EventSheetAnnotationLine.hashed_text(source), "one"),
		"mixed": _definitions_of("\n".join(mixed), "mixed"),
	}
	var ok: bool = SUPPORT.check(P, "the shipped pack reads some definitions", (reading["two"] as PackedStringArray).size() > 20, true)
	ok = SUPPORT.check(P, "one hash reads the same definitions as two", reading["one"], reading["two"]) and ok
	ok = SUPPORT.check(P, "a file mixing both reads the same definitions", reading["mixed"], reading["two"]) and ok
	return ok


static func _definitions_of(text: String, key: String) -> PackedStringArray:
	var renamed: String = RegEx.create_from_string("(?m)^class_name \\w+$").sub(text, "class_name SpellingProbe_" + key)
	var path: String = SUPPORT.own_path("annotation_spelling_%s.gd" % key)
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
		out.append(" ".join(parts).replace(path, "P").replace("SpellingProbe_" + key, "X"))
	out.sort()
	return PackedStringArray(out)


# ── every other reader ───────────────────────────────────────────────────────────────────────────


static func _written(text: String, key: String) -> String:
	var path: String = SUPPORT.own_path("annotation_spelling_%s.gd" % key)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return path


## What each reader says about the sample, as one dictionary per spelling.
static func _readers_say(text: String, key: String) -> Dictionary:
	var path: String = _written(text, key)
	var said: Dictionary = {}
	said["version"] = EventSheetPackCatalog.version_of(path)
	said["tags"] = EventSheetPackLibrary.tags_of(path)
	said["members"] = EventSheetScriptMembers.of_script(path)
	said["findings"] = FINDINGS.read(text)
	said["surface"] = EventSheetVocabularyDoc.script_pack_surface(text)
	said["is_shared"] = EventSheetSharedSheets.is_shared_sheet(text + "\n## @ace_shared_sheet(helper)\n")
	said["is_test"] = RUNNER.has_marker(text + "\n## @ace_test_sheet\n")
	var folder: String = SUPPORT.own_path("annotation_spelling_pack_%s" % key)
	DirAccess.make_dir_recursive_absolute(folder.path_join("sample"))
	var inside: FileAccess = FileAccess.open(folder.path_join("sample").path_join("sample.gd"), FileAccess.WRITE)
	inside.store_string(text)
	inside.close()
	var described: Dictionary = EventSheetPackCatalog.describe("sample", folder)
	described.erase("path")
	said["describe"] = described
	said["requires"] = EventSheetPackLibrary.requirement_entries(folder.path_join("sample"))
	return said


static func _the_other_readers_read_every_spelling_alike() -> bool:
	var two: Dictionary = _readers_say(SAMPLE, "two")
	var one: Dictionary = _readers_say(EventSheetAnnotationLine.hashed_text(SAMPLE), "one")
	var mixed_lines: PackedStringArray = SAMPLE.split("\n")
	for index: int in range(mixed_lines.size()):
		if index % 2 == 0:
			mixed_lines[index] = EventSheetAnnotationLine.hashed(mixed_lines[index])
	var mixed: Dictionary = _readers_say("\n".join(mixed_lines), "mixed")
	var ok: bool = SUPPORT.check(P, "the two-hash file reads its version", two["version"], "1.2.3")
	ok = SUPPORT.check(P, "the two-hash file reads its tags", two["tags"], PackedStringArray(["motion", "retro"])) and ok
	ok = SUPPORT.check(P, "the two-hash file has no annotation findings", (two["findings"] as Array).size(), 0) and ok
	ok = SUPPORT.check(P, "the two-hash file lists a verb", (two["surface"]["actions"] as Array).size() >= 1, true) and ok
	ok = SUPPORT.check(P, "the two-hash file is a shared sheet and a test sheet when it says so", [two["is_shared"], two["is_test"]], [true, true]) and ok
	for key: String in ["version", "tags", "findings", "surface", "is_shared", "is_test", "describe", "requires"]:
		ok = SUPPORT.check(P, "one hash reads the same %s" % key, one[key], two[key]) and ok
		ok = SUPPORT.check(P, "a mixed file reads the same %s" % key, mixed[key], two[key]) and ok
	ok = SUPPORT.check(P, "one hash reads the same members", str(one["members"]).replace("annotation_spelling_one", "x"), str(two["members"]).replace("annotation_spelling_two", "x")) and ok
	return ok


# ── the importer ─────────────────────────────────────────────────────────────────────────────────


static func _functions_of(sheet: EventSheetResource) -> Array:
	var out: Array = []
	for entry: Variant in sheet.functions:
		var function: EventFunction = entry as EventFunction
		out.append([function.function_name, function.expose_as_ace, function.ace_display_name, function.description, function.return_type])
	return out


static func _the_importer_keeps_each_file_in_its_spelling() -> bool:
	var two_sheet: EventSheetResource = EventSheets.open_gd_as_sheet(SAMPLE)
	var one_text: String = EventSheetAnnotationLine.hashed_text(SAMPLE, true)
	var one_sheet: EventSheetResource = EventSheets.open_gd_as_sheet(one_text)
	var mixed_lines: PackedStringArray = SAMPLE.split("\n")
	for index: int in range(mixed_lines.size()):
		if index % 2 == 0:
			mixed_lines[index] = EventSheetAnnotationLine.hashed(mixed_lines[index])
	var mixed_text: String = "\n".join(mixed_lines)
	var ok: bool = SUPPORT.check(P, "a two-hash file opens and saves back byte for byte", EventSheets.round_trips(SAMPLE), true)
	ok = SUPPORT.check(P, "a one-hash file opens and saves back byte for byte", EventSheets.round_trips(one_text), true) and ok
	ok = SUPPORT.check(P, "a file mixing both opens and saves back byte for byte", EventSheets.round_trips(mixed_text), true) and ok
	ok = SUPPORT.check(P, "the two-hash file reads its verbs as function rows", _functions_of(two_sheet).size(), 2) and ok
	ok = SUPPORT.check(P, "the one-hash file reads the same verbs", _functions_of(one_sheet), _functions_of(two_sheet)) and ok
	ok = SUPPORT.check(P, "a one-hash file remembers its spelling", one_sheet.annotation_spelling, "#") and ok
	ok = SUPPORT.check(P, "a two-hash file leaves the spelling alone", two_sheet.annotation_spelling, "##") and ok
	# The spelling a file with no annotation yet will use for the first one is the one hash.
	var bare: EventSheetResource = EventSheets.open_gd_as_sheet("extends Node\n\nfunc go() -> void:\n\tpass\n")
	ok = SUPPORT.check(P, "a file with no annotation yet is written with one hash from now on", bare.annotation_spelling, "#") and ok
	# Every real pack, as it ships (two hashes) and written with one: same bytes back, same verbs.
	var packs_checked: int = 0
	for pack_name: String in ["sine", "wave", "health", "platformer_movement"]:
		var folder: String = "res://eventsheet_addons/%s" % pack_name
		for file_name: String in DirAccess.get_files_at(folder):
			if not file_name.ends_with("_behavior.gd") and not file_name.ends_with("_addon.gd"):
				continue
			var shipped: String = FileAccess.get_file_as_string(folder.path_join(file_name))
			var rewritten: String = EventSheetAnnotationLine.hashed_text(shipped, true)
			packs_checked += 1
			ok = SUPPORT.check(P, "%s opens and saves back with one hash" % file_name, EventSheets.round_trips(rewritten), true) and ok
			ok = SUPPORT.check(P, "%s reads the same verbs with one hash" % file_name,
				_functions_of(EventSheets.open_gd_as_sheet(rewritten)), _functions_of(EventSheets.open_gd_as_sheet(shipped))) and ok
	ok = SUPPORT.check(P, "some packs were compared", packs_checked >= 3, true) and ok
	return ok


static func _a_comment_that_looks_like_an_annotation_stays_a_comment() -> bool:
	var comment: String = "@tool\nclass_name SpellingProbeComment\nextends Node\n\n# @ace_hidden is what the old version used, and it is gone now.\nfunc wave() -> void:\n\tpass\n"
	var annotation: String = "@tool\nclass_name SpellingProbeHidden\nextends Node\n\n# @ace_hidden\nfunc wave() -> void:\n\tpass\n"
	var ok: bool = SUPPORT.check(P, "a comment starting `# @ace_hidden is ...` hides nothing", (_definitions_of(comment, "comment") as PackedStringArray).size() > 0, true)
	ok = SUPPORT.check(P, "a bare `# @ace_hidden` line hides the member", (_definitions_of(annotation, "hidden") as PackedStringArray).size(), 0) and ok
	ok = SUPPORT.check(P, "the comment file opens and saves back byte for byte", EventSheets.round_trips(comment), true) and ok
	var opened: EventSheetResource = EventSheets.open_gd_as_sheet(comment)
	var hidden_functions: int = 0
	for entry: Variant in opened.functions:
		if not (entry as EventFunction).expose_as_ace and not (entry as EventFunction).lifted_unannotated:
			hidden_functions += 1
	ok = SUPPORT.check(P, "the comment is not read as a hidden verb", hidden_functions, 0) and ok
	return ok


# ── the writers ──────────────────────────────────────────────────────────────────────────────────


static func _built_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.behavior_mode = true
	sheet.custom_class_name = "SpellingBuilt"
	sheet.addon_category = "Motion"
	var verb: EventFunction = EventFunction.new()
	verb.function_name = "wave"
	verb.expose_as_ace = true
	verb.ace_display_name = "Wave"
	verb.description = "Waves."
	verb.events.append(EventRow.new())
	sheet.functions.append(verb)
	return sheet


static func _the_compiler_writes_one_hash_for_a_built_sheet() -> bool:
	var out: String = SUPPORT.compile_output(_built_sheet(), SUPPORT.own_path("annotation_spelling_built.gd"))
	var ok: bool = SUPPORT.check(P, "a built sheet writes its annotations with one hash", out.contains("# @ace_name(\"Wave\")") and out.contains("# @ace_category(\"Motion\")"), true)
	ok = SUPPORT.check(P, "and writes none with two", out.contains("## @ace_"), false) and ok
	ok = SUPPORT.check(P, "the one-hash output opens and saves back byte for byte", EventSheets.round_trips(out), true) and ok
	var opened: EventSheetResource = EventSheets.open_gd_as_sheet(out)
	ok = SUPPORT.check(P, "and reads the verb back", _functions_of(opened).size(), 1) and ok
	var old_spelling: EventSheetResource = _built_sheet()
	old_spelling.annotation_spelling = "##"
	var two: String = SUPPORT.compile_output(old_spelling, SUPPORT.own_path("annotation_spelling_built_two.gd"))
	ok = SUPPORT.check(P, "a sheet that says two hashes writes two", two.contains("## @ace_name(\"Wave\")"), true) and ok
	# A file read with two hashes keeps writing two, even for a verb added to it.
	var reopened: EventSheetResource = EventSheets.open_gd_as_sheet(two)
	reopened.external_source_path = SUPPORT.own_path("annotation_spelling_reopened.gd")
	var added: EventFunction = EventFunction.new()
	added.function_name = "spin"
	added.expose_as_ace = true
	added.ace_display_name = "Spin"
	added.events.append(EventRow.new())
	reopened.functions.append(added)
	var grown: String = SUPPORT.compile_output(reopened, reopened.external_source_path)
	ok = SUPPORT.check(P, "a verb added to a two-hash file is written with two", grown.contains("## @ace_name(\"Spin\")"), true) and ok
	var one_file: EventSheetResource = EventSheets.open_gd_as_sheet(out)
	one_file.external_source_path = SUPPORT.own_path("annotation_spelling_reopened_one.gd")
	var added_one: EventFunction = EventFunction.new()
	added_one.function_name = "spin"
	added_one.expose_as_ace = true
	added_one.ace_display_name = "Spin"
	added_one.events.append(EventRow.new())
	one_file.functions.append(added_one)
	var grown_one: String = SUPPORT.compile_output(one_file, one_file.external_source_path)
	ok = SUPPORT.check(P, "a verb added to a one-hash file is written with one", grown_one.contains("# @ace_name(\"Spin\")") and not grown_one.contains("## @ace_name(\"Spin\")"), true) and ok
	return ok


## Godot reads a member's documentation from the `##` lines directly above it, and one ordinary comment line
## between the two drops it. With the words written as comments they go first and the description last, for a
## function, a trigger signal and a declaration written by hand; a two-hash file keeps the order it always had.
static func _a_description_stays_directly_above_its_member() -> bool:
	var sheet: EventSheetResource = _built_sheet()
	(sheet.functions[0] as EventFunction).doc_comment = "Waves the node about."
	var signal_row: SignalRow = SignalRow.new()
	signal_row.signal_name = "waved"
	signal_row.trigger = true
	signal_row.ace_name = "On Waved"
	signal_row.description = "Fires when the wave ends."
	sheet.events.append(signal_row)
	var out: String = SUPPORT.compile_output(sheet, SUPPORT.own_path("annotation_spelling_docs.gd"))
	var ok: bool = SUPPORT.check(P, "a function writes its words, then its description, then the function",
		out.contains("# @ace_name(\"Wave\")\n") and out.contains("## Waves the node about.\nfunc wave"), true)
	ok = SUPPORT.check(P, "no comment line separates the description from the function", out.contains("## Waves the node about.\n#"), false) and ok
	ok = SUPPORT.check(P, "a trigger signal writes its words, then its description, then the signal",
		out.contains("# @ace_trigger\n# @ace_name(\"On Waved\")\n## Fires when the wave ends.\nsignal waved"), true) and ok
	ok = SUPPORT.check(P, "that output opens and saves back byte for byte", EventSheets.round_trips(out), true) and ok
	var opened: EventSheetResource = EventSheets.open_gd_as_sheet(out)
	var read_back: EventFunction = EventSheetCompiler._find_function_by_name(opened, "wave")
	ok = SUPPORT.check(P, "and reads the description back as the description", read_back != null and read_back.doc_comment == "Waves the node about.", true) and ok
	var read_signal: bool = false
	for entry: Variant in opened.events:
		if entry is SignalRow and (entry as SignalRow).trigger and (entry as SignalRow).description == "Fires when the wave ends.":
			read_signal = true
	ok = SUPPORT.check(P, "and reads the trigger signal back as one row with its description", read_signal, true) and ok
	var two: EventSheetResource = _built_sheet()
	two.annotation_spelling = "##"
	(two.functions[0] as EventFunction).doc_comment = "Waves the node about."
	var old_order: String = SUPPORT.compile_output(two, SUPPORT.own_path("annotation_spelling_docs_two.gd"))
	ok = SUPPORT.check(P, "a two-hash file keeps the description first", old_order.contains("## Waves the node about.\n## @ace_action"), true) and ok
	var raw_before: String = "## Peak strength of the wave.\n## @ace_hidden\n@export var magnitude: float = 50.0\n"
	ok = SUPPORT.check(P, "words written under a description by hand are moved above it when a built sheet is written with one hash",
		EventSheetAnnotationLine.hashed_text(raw_before, true), "# @ace_hidden\n## Peak strength of the wave.\n@export var magnitude: float = 50.0\n") and ok
	ok = SUPPORT.check(P, "and nothing moves when no description comes before the words",
		EventSheetAnnotationLine.hashed_text("## @ace_hidden\n## Peak strength.\n@export var magnitude: float = 50.0\n", true), "# @ace_hidden\n## Peak strength.\n@export var magnitude: float = 50.0\n") and ok
	return ok


static func _the_annotation_editor_writes_the_spelling_the_file_has() -> bool:
	var edit: Array = [{"source_kind": "method", "member": "wave", "name": "Wave Twice"}]
	var two: Dictionary = EventSheetACEAnnotationWriter.apply(SAMPLE, edit)
	var one: Dictionary = EventSheetACEAnnotationWriter.apply(EventSheetAnnotationLine.hashed_text(SAMPLE), edit)
	var plain_source: String = "@tool\nclass_name SpellingPlain\nextends Node\n\nfunc wave() -> void:\n\tpass\n"
	var plain: Dictionary = EventSheetACEAnnotationWriter.apply(plain_source, edit)
	var ok: bool = SUPPORT.check(P, "editing a two-hash file writes two hashes", str(two["source"]).contains("## @ace_name(\"Wave Twice\")"), true)
	ok = SUPPORT.check(P, "and leaves its other lines as they were", str(two["source"]).contains("## @ace_description(\"Waves the node.\")"), true) and ok
	ok = SUPPORT.check(P, "editing a one-hash file writes one hash", str(one["source"]).contains("# @ace_name(\"Wave Twice\")") and not str(one["source"]).contains("## @ace_name"), true) and ok
	ok = SUPPORT.check(P, "and the rest of the file keeps its one hash", str(one["source"]).contains("# @ace_description(\"Waves the node.\")") and not str(one["source"]).contains("## @ace_description"), true) and ok
	ok = SUPPORT.check(P, "the first annotation in a file with none is written with one hash", str(plain["source"]).contains("# @ace_name(\"Wave Twice\")") and not str(plain["source"]).contains("## @ace_"), true) and ok
	return ok
