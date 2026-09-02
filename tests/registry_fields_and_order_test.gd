# Godot EventSheets - THE TWO TEXTS THE SORTED ONES CANNOT SEE.
#
# The descriptor-identity gate is four texts now, and the two this file pins were added because the
# first two, between them, sign off changes that break the editor in front of a user.
#
#   FIELDS  is what a verb OFFERS. Every parameter's hint, dropdown options, autocomplete
#           suggestions, reading lens, option-label flag and required flag, plus the descriptor's own
#           node type, signal, return type and the featured / project-scoped / deprecated flags. Not
#           one of those moves an emitted byte or a printed word, so the identity dump and the
#           wording dump are structurally blind to all of them - and a comparison parameter that lost
#           its options, a required flag that went false, or a dial verb that stopped being
#           project-scoped is a picker somebody cannot use while both older texts read `same`.
#   ORDER   is the SEQUENCE, and it is the one text that is deliberately not sorted. The other three
#           sort by key, which is what makes them diffable and what makes them unable to see the
#           thing sorting destroys. Registration order decides which of two verbs sharing an id
#           shadows the other in the picker index, and it is the reverse-lifter's TIE-BREAK: the
#           lifter takes the FIRST entry whose template matches, its index is ordered by literal
#           character count, and equal specificity is settled by registration order alone. Reorder
#           two modules and a hand-written line can come back as a different row - identical emitted
#           bytes, a different sentence - with all three sorted texts saying nothing moved.
#
# WHAT IS PROVED HERE, and the two middle items are the point of the whole file:
#
#   1. THE LINE IS THE FIELDS. Key, node type, signal, return type, flags, and every parameter as
#      `id=hint;options;autocomplete;lens;option_labels;required` in the descriptor's own order.
#   2. A HINT CHANGE MOVES ONLY THE FIELDS TEXT. The same verb with one parameter's hint rewritten
#      leaves the identity line and the wording line byte-identical and moves the fields line.
#   3. A REORDERING MOVES ONLY THE ORDER TEXT. The same two verbs registered the other way round
#      leave all three sorted texts byte-identical and move the order text, on both of its halves.
#   4. THE ORDER TEXT IS TWO SECTIONS, headed by comment lines a diff skips, with the reverse half
#      carrying the literal-character count the tie-break sorts on.
#   5. EACH TEXT HAS ITS OWN FORMAT VERSION, so no two of the four can be mistaken for each other.
#
# Nothing here reads or writes a sheet and nothing needs a live registry: every function under test
# is pure over the catalog-shaped dictionaries, descriptors and index entries it is handed.
@tool
class_name RegistryFieldsAndOrderTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const WORDING := preload("res://tools/registry_wording.gd")
const PICKER_FIELDS := preload("res://tools/registry_fields.gd")
const ORDER := preload("res://tools/registry_order.gd")
const P: String = "registry_fields_and_order_test"


static func run() -> bool:
	var passed: bool = true
	passed = _test_the_line_is_the_fields() and passed
	passed = _test_a_hint_change_moves_only_the_fields_text() and passed
	passed = _test_a_reordering_moves_only_the_order_text() and passed
	passed = _test_the_order_text_is_two_headed_sections() and passed
	passed = _test_each_text_has_its_own_version() and passed
	return passed


## One entry in the shape `EventForgeSuccessors.entry_of` returns, with everything the four texts
## read. `hint` is an argument because the second test turns on that one field and nothing else.
static func _entry(hint: String) -> Dictionary:
	return {
		"key": "Probe::Wave",
		"name": "Wave",
		"description": "Waves at somebody.",
		"display_template": "wave at {who}",
		"template": "wave({who})",
		"category": "Greetings",
		"ace_type": ACEDefinition.ACEType.ACTION,
		"params": PackedStringArray(["who"]),
		"declared_types": {"who": "String"},
		"declared_defaults": {"who": "\"nobody\""},
		"declared_labels": {"who": "Who"},
		"declared_descriptions": {"who": "The one waved at."},
		"declared_hints": {"who": hint},
		"declared_options": {"who": "near=Somebody near|far=Somebody far"},
		"declared_autocomplete": {"who": "player|enemy"},
		"declared_lenses": {"who": "darkness"},
		"declared_option_labels": {"who": true},
		"declared_required": {"who": true},
		"node_type": "Node2D",
		"signal_name": "waved",
		"return_type": TYPE_BOOL,
		"is_featured": true,
		"is_project_scoped": false,
		"is_deprecated": true,
		"answered_by_default": PackedStringArray(["who"]),
		"map": {},
	}


## A second verb, so the order tests have two things to put in two orders. Deliberately keyed AFTER
## the first alphabetically, so "sorted" and "registered second" are the same position here and a
## reordering is the only thing that can move the order text without moving a sorted one.
static func _second_entry() -> Dictionary:
	var entry: Dictionary = _entry("expression")
	entry["key"] = "Probe::Yell"
	entry["name"] = "Yell"
	return entry


## A descriptor carrying only the two fields the order text reads off one.
static func _descriptor(ace_id: String) -> ACEDescriptor:
	var descriptor: ACEDescriptor = ACEDescriptor.new()
	descriptor.provider_id = "Probe"
	descriptor.ace_id = ace_id
	return descriptor


## One reverse-index entry in the shape `_compose_reverse_entries` appends.
static func _reverse_entry(ace_id: String, literal_len: int) -> Dictionary:
	return {"provider": "Probe", "ace_id": ace_id, "kind": "action", "literal_len": literal_len}


static func _test_the_line_is_the_fields() -> bool:
	var line: String = PICKER_FIELDS.line_for("Probe::Wave", _entry("variable_reference"))
	return SUPPORT.pins(P, [
		["the fields line", line,
			"Probe::Wave\tNode2D\twaved\tbool\tfeatured|deprecated"
			+ "\twho=variable_reference;near=Somebody near|far=Somebody far;player|enemy;darkness;labels;required"],
		["the fields are named", ",".join(PICKER_FIELDS.FIELDS),
			"key,node_type,signal_name,return_type,flags,params"],
		["a flag nobody raised is absent", PICKER_FIELDS.flags_of({}), ""],
		["and the raised ones keep their stated order",
			PICKER_FIELDS.flags_of({"is_deprecated": true, "is_project_scoped": true, "is_featured": true}),
			"featured|project_scoped|deprecated"],
	])


static func _test_a_hint_change_moves_only_the_fields_text() -> bool:
	var before: Dictionary = {"Probe::Wave": _entry("expression")}
	var after: Dictionary = {"Probe::Wave": _entry("variable_reference")}
	return SUPPORT.pins(P, [
		["the identity text does not see a hint",
			EventForgeRegistryDump.text(before) == EventForgeRegistryDump.text(after), true],
		["nor does the wording text", WORDING.text(before) == WORDING.text(after), true],
		["the fields text does", PICKER_FIELDS.text(before) == PICKER_FIELDS.text(after), false],
		["and it is the hint that moved on the line",
			PICKER_FIELDS.line_for("Probe::Wave", _entry("variable_reference")).split("\t")[5].split(";")[0],
			"who=variable_reference"],
	])


static func _test_a_reordering_moves_only_the_order_text() -> bool:
	# The same two verbs, catalogued in the two possible insertion orders. All three sorted texts sort
	# by key before they write a line, so both readings have to come out byte-identical.
	var one_way: Dictionary = {"Probe::Wave": _entry("expression"), "Probe::Yell": _second_entry()}
	var other_way: Dictionary = {"Probe::Yell": _second_entry(), "Probe::Wave": _entry("expression")}
	var registered: Array = [_descriptor("Wave"), _descriptor("Yell")]
	var reregistered: Array = [_descriptor("Yell"), _descriptor("Wave")]
	var indexed: Array = [_reverse_entry("Wave", 7), _reverse_entry("Yell", 7)]
	var reindexed: Array = [_reverse_entry("Yell", 7), _reverse_entry("Wave", 7)]
	return SUPPORT.pins(P, [
		["the identity text does not see the sequence",
			EventForgeRegistryDump.text(one_way) == EventForgeRegistryDump.text(other_way), true],
		["nor does the wording text", WORDING.text(one_way) == WORDING.text(other_way), true],
		["nor does the fields text", PICKER_FIELDS.text(one_way) == PICKER_FIELDS.text(other_way), true],
		["the registration half does",
			ORDER.registration_lines(registered) == ORDER.registration_lines(reregistered), false],
		["and it says which verb registered first",
			"|".join(ORDER.registration_lines(reregistered)), "0\tProbe::Yell|1\tProbe::Wave"],
		["the reverse half does too, at equal specificity",
			ORDER.reverse_lines(indexed) == ORDER.reverse_lines(reindexed), false],
		["and it says the order the lifter walks",
			"|".join(ORDER.reverse_lines(reindexed)),
			"0\tProbe::Yell\taction\t7|1\tProbe::Wave\taction\t7"],
	])


static func _test_the_order_text_is_two_headed_sections() -> bool:
	return SUPPORT.pins(P, [
		["the registration heading is comment-led", ORDER.REGISTRATION_HEADING.begins_with("#"), true],
		["so is the reverse heading", ORDER.REVERSE_HEADING.begins_with("#"), true],
		["a null descriptor is skipped rather than crashed on",
			ORDER.registration_lines([null, _descriptor("Wave")]).size(), 1],
		["and so is an index entry that is not a record",
			ORDER.reverse_lines(["not an entry", _reverse_entry("Wave", 3)]).size(), 1],
	])


static func _test_each_text_has_its_own_version() -> bool:
	var headers: PackedStringArray = PackedStringArray([
		EventForgeRegistryDump.HEADER, WORDING.HEADER, PICKER_FIELDS.HEADER, ORDER.HEADER])
	var unique: Dictionary = {}
	for header: String in headers:
		unique[header] = true
	return SUPPORT.pins(P, [
		["the fields text names itself", PICKER_FIELDS.HEADER, "# eventsheets fields dump 1"],
		["the order text names itself", ORDER.HEADER, "# eventsheets order dump 1"],
		["and no two of the four wear one name", unique.size(), 4],
		["a fields text recognises its own format",
			PICKER_FIELDS.is_current_format(PICKER_FIELDS.HEADER + "\n"), true],
		["and refuses the order text's", PICKER_FIELDS.is_current_format(ORDER.HEADER + "\n"), false],
		["the order text recognises its own",
			ORDER.is_current_format(ORDER.HEADER + "\n"), true],
	])
