# Godot EventSheets — semantic 3-way merge driver test.
# Exercises the pure merge core (tools/sheet_merge.gd merge_sheets): non-overlapping edits
# merge cleanly keyed on row UIDs, identical edits don't conflict, genuine same-row edits
# are flagged (keeping both versions), and adds/deletes/variables 3-way merge correctly.
@tool
extends RefCounted
class_name SheetMergeTest

const Merge := preload("res://tools/sheet_merge.gd")

static func run() -> bool:
	var passed: bool = true

	# 1. Ours edits row A, theirs edits row B → clean merge, both edits survive.
	var ancestor: EventSheetResource = _sheet([_event("a", "hp", "1"), _event("b", "mp", "1")])
	var ours: EventSheetResource = _sheet([_event("a", "hp", "2"), _event("b", "mp", "1")])
	var theirs: EventSheetResource = _sheet([_event("a", "hp", "1"), _event("b", "mp", "9")])
	var out: Dictionary = Merge.merge_sheets(ancestor, ours, theirs)
	passed = _check("non-overlapping edits merge with no conflict", (out["conflicts"] as Array).size(), 0) and passed
	passed = _check("ours' edit to A survives", _param_of(out["sheet"], "a"), "2") and passed
	passed = _check("theirs' edit to B is pulled in", _param_of(out["sheet"], "b"), "9") and passed

	# 2. Both edit row A differently → conflict, both versions kept (4 rows: 2 markers + 2).
	var anc2: EventSheetResource = _sheet([_event("a", "hp", "1")])
	var out2: Dictionary = Merge.merge_sheets(anc2, _sheet([_event("a", "hp", "2")]), _sheet([_event("a", "hp", "3")]))
	passed = _check("same-row conflicting edits are flagged", (out2["conflicts"] as Array).size(), 1) and passed
	passed = _check("conflict keeps both versions + markers for review", (out2["sheet"].events as Array).size(), 4) and passed

	# 3. Same edit on both sides → not a conflict.
	var out3: Dictionary = Merge.merge_sheets(anc2, _sheet([_event("a", "hp", "5")]), _sheet([_event("a", "hp", "5")]))
	passed = _check("identical edits don't conflict", (out3["conflicts"] as Array).size(), 0) and passed
	passed = _check("identical edit applied once", _param_of(out3["sheet"], "a"), "5") and passed

	# 4. Theirs adds a row → merged in.
	var out4: Dictionary = Merge.merge_sheets(
		_sheet([_event("a", "hp", "1")]),
		_sheet([_event("a", "hp", "1")]),
		_sheet([_event("a", "hp", "1"), _event("c", "gold", "1")]))
	passed = _check("theirs' added row is merged in", (out4["sheet"].events as Array).size(), 2) and passed

	# 5. Theirs deletes a row ours left untouched → honoured.
	var out5: Dictionary = Merge.merge_sheets(
		_sheet([_event("a", "hp", "1"), _event("b", "mp", "1")]),
		_sheet([_event("a", "hp", "1"), _event("b", "mp", "1")]),
		_sheet([_event("a", "hp", "1")]))
	passed = _check("upstream deletion is honoured", (out5["sheet"].events as Array).size(), 1) and passed

	# 6. Variables: each side adds one → both present, no conflict.
	var av: EventSheetResource = _sheet([])
	av.variables = {"shared": {"type": "int", "default": 0}}
	var ov: EventSheetResource = _sheet([])
	ov.variables = {"shared": {"type": "int", "default": 0}, "only_ours": {"type": "int", "default": 1}}
	var tv: EventSheetResource = _sheet([])
	tv.variables = {"shared": {"type": "int", "default": 0}, "only_theirs": {"type": "int", "default": 2}}
	var out6: Dictionary = Merge.merge_sheets(av, ov, tv)
	var merged_vars: Dictionary = out6["sheet"].variables
	passed = _check("both sides' new variables merge",
		merged_vars.has("only_ours") and merged_vars.has("only_theirs") and (out6["conflicts"] as Array).is_empty(), true) and passed

	# 7. Conflicting variable edit (same key, different default) → flagged.
	var out7: Dictionary = Merge.merge_sheets(
		_var_sheet({"hp": 100}), _var_sheet({"hp": 120}), _var_sheet({"hp": 80}))
	passed = _check("conflicting variable edit is flagged", (out7["conflicts"] as Array).size(), 1) and passed

	return passed

static func _sheet(rows: Array) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	for row: Variant in rows:
		sheet.events.append(row)
	return sheet

static func _var_sheet(hp_defaults: Dictionary) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	for key: Variant in hp_defaults:
		sheet.variables[str(key)] = {"type": "int", "default": hp_defaults[key]}
	return sheet

static func _event(uid: String, var_name: String, amount: String) -> EventRow:
	var row: EventRow = EventRow.new()
	row.event_uid = uid
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "AddVar"
	action.params = {"var_name": var_name, "amount": amount}
	row.actions.append(action)
	return row

static func _param_of(sheet: EventSheetResource, uid: String) -> String:
	for row: Variant in sheet.events:
		if row is EventRow and (row as EventRow).event_uid == uid:
			for action: Variant in (row as EventRow).actions:
				if action is ACEAction:
					return str((action as ACEAction).params.get("amount", ""))
	return "?"

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] sheet_merge_test: %s" % label)
		return true
	print("[FAIL] sheet_merge_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
