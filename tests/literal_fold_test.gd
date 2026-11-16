# Godot EventSheets - a guarded value that is a plain number is written as the number, for NEW rows only.
#
# `maxf({seconds}, 0.001)` around a float literal at or above the floor means exactly the literal. A row
# with `folds_literals` on writes the literal; a row without it (every row read from an existing file,
# every `.tres` row saved before the change) writes the guard as it always did, so a file nobody touched
# never moves. The reader takes both spellings as the same verb and remembers which it saw.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "literal_fold_test"
const FOLD_PATH := "res://addons/eventforge/compiler/literal_fold.gd"
const OLD_FORM_PATH := "res://tests/fixtures/every_seconds_old_form.gd"
const NEW_FORM_PATH := "res://tests/fixtures/every_seconds_folded.gd"


static func run() -> bool:
	var ok: bool = true
	var fold: Script = load(FOLD_PATH) if ResourceLoader.exists(FOLD_PATH) else null
	ok = SUPPORT.check(P, "the fold helper exists", fold != null, true) and ok
	ok = SUPPORT.check(P, "a row carries the new-spelling flag", "folds_literals" in ACECondition.new(), true) and ok
	ok = SUPPORT.check(P, "an action carries the new-spelling flag", "folds_literals" in ACEAction.new(), true) and ok
	if fold == null or not ("folds_literals" in ACECondition.new()):
		return false
	var old_form: String = FileAccess.get_file_as_string(OLD_FORM_PATH)
	var new_form: String = FileAccess.get_file_as_string(NEW_FORM_PATH)
	var template: String = "__every_{uid} >= maxf({seconds}, 0.001)"
	var two_guards: String = "{a}.clamp(maxf({lo}, 0.5), maxf({hi}, 1.0))"
	ok = SUPPORT.pins(P, [
		["a float at the floor folds", fold.call("fold_template", template, {"seconds": "2.0"}), "__every_{uid} >= {seconds}"],
		["a negative float below the floor keeps its guard", fold.call("fold_template", template, {"seconds": "-2.0"}), template],
		["an int never folds (it would change a division)", fold.call("fold_template", template, {"seconds": "2"}), template],
		["an expression never folds", fold.call("fold_template", template, {"seconds": "wave_gap"}), template],
		["a value below the floor keeps its guard", fold.call("fold_template", template, {"seconds": "0.0005"}), template],
		["a missing value keeps its guard", fold.call("fold_template", template, {}), template],
		["every guard folding folds the template", fold.call("fold_template", two_guards, {"lo": "0.5", "hi": "3.0"}), "{a}.clamp({lo}, {hi})"],
		["one guard that does not fold keeps all of them", fold.call("fold_template", two_guards, {"lo": "0.5", "hi": "hi_name"}), two_guards],
		["the folded variant names the floors", (fold.call("folded_variant", template) as Dictionary).get("floors"), {"seconds": "0.001"}],
		["a template with no guard has no folded variant", fold.call("folded_variant", "print({x})"), {}],
	]) and ok
	# The old file: opens with the flag off and saves back byte for byte.
	ok = SUPPORT.check(P, "the old spelling reads as Every X Seconds with the flag off", _every_flag(SUPPORT.reopen(old_form)), "false") and ok
	ok = SUPPORT.check(P, "the old spelling saves back byte for byte", SUPPORT.reemit(old_form, SUPPORT.own_path("literal_fold_old.gd")), old_form) and ok
	# The new file: opens with the flag on and saves back byte for byte.
	ok = SUPPORT.check(P, "the new spelling reads as Every X Seconds with the flag on", _every_flag(SUPPORT.reopen(new_form)), "true") and ok
	ok = SUPPORT.check(P, "the new spelling saves back byte for byte", SUPPORT.reemit(new_form, SUPPORT.own_path("literal_fold_new.gd")), new_form) and ok
	# Both spellings in one file keep their own.
	var both: String = old_form + "\nfunc _physics_process(delta: float) -> void:\n\t__every_tick += delta\n\tif __every_tick >= 3.0:\n\t\tprint(\"other\")\n"
	ok = SUPPORT.check(P, "one file holding both spellings saves back byte for byte", SUPPORT.reemit(both, SUPPORT.own_path("literal_fold_both.gd")), both) and ok
	# A hand-written comparison with a name in it is not claimed by the folded pattern.
	var hand: String = "extends Node\n\nvar __every_x: float = 0.0\nvar limit: float = 1.0\n\nfunc _process(_delta: float) -> void:\n\tif __every_x >= limit:\n\t\tprint(\"x\")\n"
	ok = SUPPORT.check(P, "a hand-written comparison stays a comparison", _every_flag(SUPPORT.reopen(hand)), "none") and ok
	# An int is never claimed either: the guard around `2` stays a guard.
	var int_form: String = old_form.replace("maxf(2.0, 0.001)", "maxf(2, 0.001)")
	ok = SUPPORT.check(P, "an int next to its guard is not folded on reading", _every_flag(SUPPORT.reopen(new_form.replace(">= 2.0:", ">= 2:"))), "none") and ok
	ok = SUPPORT.check(P, "an int inside the guard still saves back byte for byte", SUPPORT.reemit(int_form, SUPPORT.own_path("literal_fold_int.gd")), int_form) and ok
	# A row that asks for the fold writes it from the value in the slot, and gives the guard back when the
	# value stops being a plain number.
	var row: ACECondition = ACECondition.new()
	row.provider_id = "Core"
	row.ace_id = "EveryXSeconds"
	row.folds_literals = true
	row.params = {"uid": "tick", "seconds": "2.0"}
	ok = SUPPORT.check(P, "a flagged row writes the number", EventSheetConditionCodegen.generate_condition(row), "__every_tick >= 2.0") and ok
	row.params = {"uid": "tick", "seconds": "wave_gap"}
	ok = SUPPORT.check(P, "a flagged row given a name writes its guard back", EventSheetConditionCodegen.generate_condition(row), "__every_tick >= maxf(wave_gap, 0.001)") and ok
	row.folds_literals = false
	row.params = {"uid": "tick", "seconds": "2.0"}
	ok = SUPPORT.check(P, "an unflagged row writes the guard as it always did", EventSheetConditionCodegen.generate_condition(row), "__every_tick >= maxf(2.0, 0.001)") and ok
	# The short spellings the reader holds: every verb that reads its guarded line also reads the short one,
	# and a short spelling that another verb already writes is refused.
	var folded_ids: Dictionary = {}
	var plain_ids: Dictionary = {}
	for entry: Variant in EventSheetACELifter._build_reverse_entries():
		var holder: Dictionary = folded_ids if not ((entry as Dictionary)["fold_floors"] as Dictionary).is_empty() else plain_ids
		holder[(entry as Dictionary)["ace_id"]] = true
	var lost: PackedStringArray = []
	for descriptor: ACEDescriptor in ACERegistry.get_all_descriptors():
		if plain_ids.has(descriptor.ace_id) and not (fold.call("folded_variant", descriptor.codegen_template) as Dictionary).is_empty() 				and not folded_ids.has(descriptor.ace_id):
			lost.append(descriptor.ace_id)
	ok = SUPPORT.check(P, "no verb with a guard lost its short spelling to a collision", lost, PackedStringArray()) and ok
	var kept: Array = EventSheetACELifter._without_colliding_folds([
		{"variant": "x = {a}", "fold_floors": {}},
		{"variant": "x = {b}", "fold_floors": {"b": "0.5"}},
		{"variant": "y({c})", "fold_floors": {"c": "0.5"}},
		{"variant": "z({d})", "fold_floors": {"d": "0.5"}},
		{"variant": "z({e})", "fold_floors": {"e": "0.5"}},
	])
	var kept_variants: PackedStringArray = []
	for entry: Variant in kept:
		kept_variants.append(str((entry as Dictionary)["variant"]))
	ok = SUPPORT.check(P, "a short spelling equal to another verb's, or to another short one, is refused", kept_variants, PackedStringArray(["x = {a}", "y({c})"])) and ok
	return ok


static func _every_flag(sheet: EventSheetResource) -> String:
	for entry: Variant in sheet.events:
		if entry is EventRow:
			for condition: ACECondition in (entry as EventRow).conditions:
				if condition.ace_id == "EveryXSeconds":
					return str(condition.get("folds_literals"))
	return "none"
