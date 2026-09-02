# Godot EventSheets - THE WORDS OF THE VOCABULARY ARE A SECOND TEXT, AND THE GATE IS BOTH.
#
# The registry dump is a verb's IDENTITY and carries no wording at all, which is right: a reworded
# verb is the same verb, and a description typo fixed must not read to somebody taking a pack update
# as a retired verb. It leaves a hole a refactor can fall through, and this test is that hole named:
# a module rewritten in a terser form can reproduce every identity line and drop every description,
# and the plugin goes on compiling byte-identical code with every picker in it gone blank.
#
# So the words get a text of their own, in the same shape, with the same escaping and its own format
# version. What is proved here:
#
#   1. THE LINE IS THE WORDING. Key, name, description, the reads-as sentence, and every parameter
#      as `id=label|description` in the descriptor's own order.
#   2. THE TWO TEXTS SEE DIFFERENT CHANGES. A verb whose description is rewritten moves the wording
#      line and leaves the identity line alone; a verb whose template is rewritten does the reverse.
#      Neither text alone is the gate.
#   3. IT IS SORTED, HEADED AND STABLE, like the identity dump, so a diff is a line diff.
#   4. THE ESCAPING IS THE IDENTITY DUMP'S OWN. One function, not two wearing one name - a
#      description with a tab or a newline in it stays on one line.
#
# Nothing here reads or writes a sheet, and nothing needs a live registry: `line_for` and `text` are
# pure over the catalog-shaped dictionaries they are handed.
@tool
class_name RegistryWordingTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const WORDING := preload("res://tools/registry_wording.gd")
const P: String = "registry_wording_test"


static func run() -> bool:
	var passed: bool = true
	passed = _test_the_line_is_the_wording() and passed
	passed = _test_the_two_texts_see_different_changes() and passed
	passed = _test_the_text_is_sorted_and_headed() and passed
	passed = _test_a_description_stays_on_one_line() and passed
	return passed


## One entry in the shape `EventForgeSuccessors.entry_of` returns.
static func _entry(description: String, template: String) -> Dictionary:
	return {
		"key": "Probe::Wave",
		"name": "Wave",
		"description": description,
		"display_template": "wave at {who}",
		"template": template,
		"category": "Greetings",
		"ace_type": ACEDefinition.ACEType.ACTION,
		"params": PackedStringArray(["who"]),
		"declared_types": {"who": "String"},
		"declared_defaults": {"who": "\"nobody\""},
		"declared_labels": {"who": "Who"},
		"declared_descriptions": {"who": "The one waved at."},
		"answered_by_default": PackedStringArray(["who"]),
		"map": {},
	}


static func _test_the_line_is_the_wording() -> bool:
	var line: String = WORDING.line_for("Probe::Wave", _entry("Waves at somebody.", "wave({who})"))
	return SUPPORT.pins(P, [
		["the wording line", line,
			"Probe::Wave\tWave\tWaves at somebody.\twave at {who}\twho=Who|The one waved at."],
		["the fields are named", ",".join(WORDING.FIELDS), "key,name,description,reads_as,params"],
		["a text of its own version", WORDING.HEADER, "# eventsheets wording dump 1"],
		["and it is not the identity dump's", WORDING.HEADER == EventForgeRegistryDump.HEADER, false],
	])


static func _test_the_two_texts_see_different_changes() -> bool:
	var before: Dictionary = _entry("Waves at somebody.", "wave({who})")
	var reworded: Dictionary = _entry("Waves at whoever is named.", "wave({who})")
	var retemplated: Dictionary = _entry("Waves at somebody.", "wave_at({who})")
	return SUPPORT.pins(P, [
		["a rewording moves the wording line",
			WORDING.line_for("Probe::Wave", before) == WORDING.line_for("Probe::Wave", reworded), false],
		["a rewording leaves the identity line alone",
			EventForgeRegistryDump.line_for("Probe::Wave", before),
			EventForgeRegistryDump.line_for("Probe::Wave", reworded)],
		["a retemplating moves the identity line",
			EventForgeRegistryDump.line_for("Probe::Wave", before)
				== EventForgeRegistryDump.line_for("Probe::Wave", retemplated), false],
		["a retemplating leaves the wording line alone",
			WORDING.line_for("Probe::Wave", before), WORDING.line_for("Probe::Wave", retemplated)],
	])


static func _test_the_text_is_sorted_and_headed() -> bool:
	var catalog: Dictionary = {
		"Probe::Zebra": _entry("Last by key.", "zebra()"),
		"Probe::Apple": _entry("First by key.", "apple()"),
	}
	var lines: PackedStringArray = WORDING.text(catalog).strip_edges().split("\n")
	return SUPPORT.pins(P, [
		["the header leads", lines[0], WORDING.HEADER],
		["and the format is recognised", WORDING.is_current_format(WORDING.text(catalog)), true],
		["a foreign text is not", WORDING.is_current_format("Probe::Wave\tWave"), false],
		["sorted by key, first", lines[1].split("\t")[0], "Probe::Apple"],
		["sorted by key, last", lines[2].split("\t")[0], "Probe::Zebra"],
		["one line per verb plus the header", lines.size(), 3],
	])


static func _test_a_description_stays_on_one_line() -> bool:
	var entry: Dictionary = _entry("Two lines.\nAnd a\ttab.", "wave({who})")
	var line: String = WORDING.line_for("Probe::Wave", entry)
	return SUPPORT.pins(P, [
		["no newline survives into the line", line.contains("\n"), false],
		["the description is spelled out", line.split("\t")[2], "Two lines.\\nAnd a\\ttab."],
		["the escaping is the identity dump's own", EventForgeRegistryDump.escape_field("a\tb"), "a\\tb"],
	])
