# EventForge - editing an existing verb in the ACE Studio (double-click a Define block). Pins the
# dialog's edit mode: prefill (name/kind card/value type/params/expose block), the own-name collision
# exemption, the apply-updates-in-place path (found by ORIGINAL name in the LIVE sheet - the undo
# funnel replaces resources, so a held reference would go stale), and the byte-safety property that
# confirming with nothing changed is a no-op (an accidental open-and-OK on a reverse-lifted helper
# must not dirty the sheet or clear its annotation-suppression flag).
@tool
class_name FunctionEditDialogTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var heal: EventFunction = EventFunction.new()
	heal.function_name = "heal"
	heal.return_type = TYPE_NIL
	heal.expose_as_ace = true
	heal.ace_display_name = "Heal"
	heal.ace_category = "Health"
	var amount: ACEParam = ACEParam.new()
	amount.id = "amount"
	amount.type_name = "float"
	heal.params.append(amount)
	sheet.functions.append(heal)
	var helper: EventFunction = EventFunction.new()
	helper.function_name = "recalc_cache"
	helper.return_type = TYPE_BOOL
	helper.expose_as_ace = false
	helper.lifted_unannotated = true
	sheet.functions.append(helper)
	var percent: EventFunction = EventFunction.new()
	percent.function_name = "health_percent"
	percent.return_type = TYPE_FLOAT
	percent.expose_as_ace = true
	sheet.functions.append(percent)

	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var glue: EventSheetFunctionDialogGlue = dock._function_dialog_glue

	# ── Prefill: the action verb ──
	glue._open_function_dialog_for(_live_fn(dock, "heal"))
	var dialog: EventSheetFunctionDialog = glue._function_dialog
	ok = _check("name prefilled", dialog._name_edit.text, "heal") and ok
	ok = _check("Action card pre-selected for a void verb", dialog._usable_option.selected, 0) and ok
	ok = _check("expose prefilled", dialog._expose_check.button_pressed, true) and ok
	# The picker metadata is edited inline on the row now, not shown as fields - but the dialog must
	# CARRY the function's existing values so an untouched save re-emits them byte-identically.
	ok = _check("display name carried through", dialog._carried_display_name, "Heal") and ok
	ok = _check("category carried through", dialog._carried_category, "Health") and ok
	ok = _check("the payload carries the display name + category",
		str(dialog.build_function_data().get("ace_display_name")) + "|" + str(dialog.build_function_data().get("ace_category")), "Heal|Health") and ok
	# The dialog no longer EDITS parameters, but it must still carry the verb's existing ones through
	# untouched - the apply assigns target.params wholesale, so reporting an empty list here would
	# silently delete every parameter of any verb someone opened and saved.
	ok = _check("the verb's parameter is carried through", dialog.collect_params().size(), 1) and ok
	ok = _check("carried parameter keeps its id + type",
		str(dialog.collect_params()[0].get("id")) + ":" + str(dialog.collect_params()[0].get("type_name")), "amount:float") and ok
	ok = _check("the payload carries it too, so an untouched save is a no-op",
		(dialog.build_function_data().get("params") as Array).size(), 1) and ok

	# ── Own name is not a collision; another taken name is ──
	ok = _check("own name passes validation", str(dialog.build_function_data().get("problem", "")), "") and ok
	dialog._name_edit.text = "health_percent"
	ok = _check("another function's name is refused",
		str(dialog.build_function_data().get("problem", "")).is_empty(), false) and ok

	# ── Rename + retype applies to the SAME function in place ──
	dialog._name_edit.text = "heal_over_time"
	dialog._on_confirmed()
	ok = _check("old name gone from the live sheet", _live_fn(dock, "heal") == null, true) and ok
	var renamed: EventFunction = _live_fn(dock, "heal_over_time")
	ok = _check("renamed function exists", renamed != null, true) and ok
	ok = _check("no duplicate appended (still 3 functions)", dock.get_current_sheet().functions.size(), 3) and ok
	ok = _check("params survived the edit", renamed.params.size() if renamed != null else -1, 1) and ok
	ok = _check("expose survived the edit", renamed.expose_as_ace if renamed != null else false, true) and ok

	# ── Kind prefill: bool → Condition card, typed → Expression card + value type ──
	glue._open_function_dialog_for(_live_fn(dock, "recalc_cache"))
	ok = _check("bool verb pre-selects the Condition card", dialog._usable_option.selected, 1) and ok
	glue._open_function_dialog_for(_live_fn(dock, "health_percent"))
	ok = _check("typed verb pre-selects the Expression card", dialog._usable_option.selected, 2) and ok
	ok = _check("value type pre-selected to float", dialog._value_type_option.selected, 0) and ok

	# ── Byte-safety: confirming with NOTHING changed is a no-op ──
	glue._open_function_dialog_for(_live_fn(dock, "recalc_cache"))
	dialog._on_confirmed()
	var untouched: EventFunction = _live_fn(dock, "recalc_cache")
	ok = _check("untouched helper still exists", untouched != null, true) and ok
	ok = _check("no-change confirm PRESERVES lifted_unannotated (stays byte-identical on save)",
		untouched.lifted_unannotated if untouched != null else false, true) and ok

	# ── A real change on the helper clears the suppression flag (it's authored now) ──
	# The description is edited on the row now, so the dialog's "real change" here is the doc comment -
	# still a field the dialog owns, and still part of the no-op fingerprint.
	glue._open_function_dialog_for(_live_fn(dock, "recalc_cache"))
	dialog._doc_comment_edit.text = "Recomputes the cached pool totals."
	dialog._on_confirmed()
	var authored: EventFunction = _live_fn(dock, "recalc_cache")
	ok = _check("doc comment applied", authored.doc_comment if authored != null else "", "Recomputes the cached pool totals.") and ok
	ok = _check("a real edit clears lifted_unannotated", authored.lifted_unannotated if authored != null else true, false) and ok

	dock.free()
	return ok


static func _live_fn(dock: EventSheetDock, fn_name: String) -> EventFunction:
	for entry: Variant in dock.get_current_sheet().functions:
		if entry is EventFunction and (entry as EventFunction).function_name == fn_name:
			return entry as EventFunction
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] function_edit_dialog_test: %s" % label)
		return true
	print("[FAIL] function_edit_dialog_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
