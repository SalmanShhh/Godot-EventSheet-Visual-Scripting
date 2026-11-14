@tool
class_name AnnotationFindingsTest
extends RefCounted

# Godot EventSheets - a script's own comments that nothing reads are named, with the line.
#
# A `##` word one letter off is not an error anywhere: it is prose, and the member reads without it.
# The findings scan names those lines, the line number and the close spelling, and it must stay quiet
# about everything that is fine - ordinary doc comments, native annotations, a correctly written file.

const SUPPORT := preload("res://tests/support.gd")
const FINDINGS := preload("res://addons/eventsheet/ace/annotation_findings.gd")

const TYPO_SOURCE: String = """class_name Demo
extends Node

## @ace_nmae("Hurt")
func take_damage(amount: int) -> void:
	pass


## @ace_param(amount, defualt: 5, hint expression, desc: "How hard")
func hit(amount: int) -> void:
	pass


## @ace_name("Cut off")
# a plain comment
func cut_off() -> void:
	pass


## @ace_category("Combat")
func pick():
	pass


## @ace_description("Fine")
func fine(amount: int = 1) -> bool:
	return true
"""


static func run() -> bool:
	var found: Array[Dictionary] = FINDINGS.read(TYPO_SOURCE)
	var rows: Array = []
	for entry: Dictionary in found:
		rows.append("%s@%d:%s:%s:%s" % [entry["kind"], entry["line"], entry["text"], entry["member"], entry["suggestion"]])
	var ok: bool = SUPPORT.pins("annotation_findings_test", [
		["every finding, in file order, with its line", rows, [
			"near_miss@4:@ace_nmae::@ace_name",
			"param_key@9:defualt::default",
			"param_colon@9:hint expression::",
			"block_cut@15:# a plain comment:cut_off:",
			"untyped@21:func pick()::pick:",
		]],
	])
	ok = _quiet_where_nothing_is_wrong() and ok
	ok = _sentences_name_the_line() and ok
	ok = _closest_spelling() and ok
	return ok


static func _quiet_where_nothing_is_wrong() -> bool:
	var plain: String = """extends Node
## Does a thing. @export and @tool are mentioned in prose.
## @ace_name("Fine")
## @ace_param(amount, hint: expression, default: 5, desc: "How hard, honestly")
func fine(amount: int) -> void:
	pass


# an ordinary comment with no words above it
func other() -> void:
	pass
"""
	var untyped_only: String = "extends Node\n\n\nfunc a():\n\tpass\n"
	return SUPPORT.pins("annotation_findings_test", [
		["a correctly written file has no findings", FINDINGS.read(plain).size(), 0],
		["a script with no words of its own is not named for an untyped function", FINDINGS.read(untyped_only).size(), 0],
		["unless every public function is going to be published", FINDINGS.read(untyped_only, true).size(), 1],
	])


static func _sentences_name_the_line() -> bool:
	var sentence: String = FINDINGS.sentence({"kind": "near_miss", "line": 4, "text": "@ace_nmae", "member": "",
		"suggestion": "@ace_name"})
	var cut: String = FINDINGS.sentence({"kind": "block_cut", "line": 15, "text": "# a plain comment",
		"member": "cut_off", "suggestion": ""})
	return SUPPORT.pins("annotation_findings_test", [
		["the near miss says the line and the word meant", sentence.contains("Line 4") and sentence.contains("@ace_name"), true],
		["no sentence says provider or verb", (sentence + cut).to_lower().contains("provider") or (sentence + cut).to_lower().contains("verb"), false],
		["the cut names the function it cut off", cut.contains("cut_off"), true],
	])


static func _closest_spelling() -> bool:
	var known: Array = ["@ace_name", "@ace_hidden", "@ace_category"]
	return SUPPORT.pins("annotation_findings_test", [
		["a missing letter", FINDINGS.closest("@ace_nme", known), "@ace_name"],
		["two neighbours swapped", FINDINGS.closest("@ace_nmae", known), "@ace_name"],
		["nothing close answers nothing", FINDINGS.closest("@export", known), ""],
	])
