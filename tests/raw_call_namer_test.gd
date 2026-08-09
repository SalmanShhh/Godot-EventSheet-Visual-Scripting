# EventSheet - Sheet ▸ Name Raw Calls (EventSheetRawCallNamer.sweep_sheet).
#
# The sweep binds raw one-call code rows to vocabulary that already exists, so `item.set_collapsed(true)`
# stops reading as grey code and becomes a real action with an editable parameter field. The only thing
# that makes that safe is the per-row byte gate, so the headline check here is not "it converted" but
# "it converted AND the file still compiles to exactly the same bytes". The rest pin the refusals: an
# unknown target, a deeper (indented) line, and a target that is an expression rather than a reference
# all stay raw, because a confidently wrong name is worse than no name - it would still compile.
#
# The rows are built the way the editor produces them (import a real source, then turn the lifted calls
# back into code rows), because that is what a hand-typed GDScript block or an unattributed lift is.
@tool
class_name RawCallNamerTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# The core win: a typed local declared one row up tells the sweep which class the call belongs to,
	# the reflected TreeItem verb matches by name and arity, and the emission is byte-identical.
	var source: String = "extends Node\n\n\nfunc _ready() -> void:\n\tvar item: TreeItem = null\n\titem.set_collapsed(true)\n"
	var sheet: EventSheetResource = _raw_sheet(source)
	var counters: Dictionary = EventSheetRawCallNamer.sweep_sheet(sheet)
	ok = _check("a known typed local's call is named", int(counters.get("named", -1)), 1) and ok
	ok = _check("the named call is the only candidate counted", int(counters.get("total", -1)), 1) and ok
	ok = _check("nothing was skipped in the happy path", int(counters.get("skipped", -1)), 0) and ok
	ok = _check("the row is now a structured action", _last_action_kind(sheet), "ace") and ok
	ok = _check("the action names the reflected class", _last_action_field(sheet, "provider_id"), "TreeItem") and ok
	ok = _check("the action names the reflected method", _last_action_field(sheet, "ace_id"), "method:set_collapsed") and ok
	ok = _check("the argument became a parameter value", _last_action_param(sheet, "enable"), "true") and ok
	ok = _check("the call's target rides on the row", _last_action_param(sheet, "target"), "item") and ok
	# The whole point: naming a row may never change one byte of what it compiles to.
	ok = _check("the named sheet re-emits the source byte-identically", _recompile(sheet), source) and ok

	# An identifier the sheet never declares a type for: nothing can be said about which class it is,
	# so the row stays code and the report says so.
	var unknown_source: String = "extends Node\n\n\nfunc _ready() -> void:\n\tmystery.set_collapsed(true)\n"
	var unknown_sheet: EventSheetResource = _raw_sheet(unknown_source)
	var unknown_counters: Dictionary = EventSheetRawCallNamer.sweep_sheet(unknown_sheet)
	ok = _check("an unknown target names nothing", int(unknown_counters.get("named", -1)), 0) and ok
	ok = _check("an unknown target counts as a candidate", int(unknown_counters.get("total", -1)), 1) and ok
	ok = _check("an unknown target counts as skipped", int(unknown_counters.get("skipped", -1)), 1) and ok
	ok = _check("an unknown target's row stays code", _last_action_kind(unknown_sheet), "raw") and ok

	# A deeper line sits inside something the row also carries; converting it would re-emit at the
	# action lane's own indent and silently move the statement, so it is refused.
	var deeper_sheet: EventSheetResource = _raw_sheet(source)
	_indent_last_action(deeper_sheet)
	var deeper_counters: Dictionary = EventSheetRawCallNamer.sweep_sheet(deeper_sheet)
	ok = _check("an indented call names nothing", int(deeper_counters.get("named", -1)), 0) and ok
	ok = _check("an indented call counts as skipped", int(deeper_counters.get("skipped", -1)), 1) and ok
	ok = _check("an indented call's row stays code", _last_action_kind(deeper_sheet), "raw") and ok

	# A target that is itself a call is an expression, not a reference: the sweep will not guess
	# through it, and it is not even counted as a candidate.
	var expression_sheet: EventSheetResource = _raw_sheet(source)
	_set_last_action_code(expression_sheet, "get_root().set_collapsed(true)")
	var expression_counters: Dictionary = EventSheetRawCallNamer.sweep_sheet(expression_sheet)
	ok = _check("a call on a call is not a candidate", int(expression_counters.get("total", -1)), 0) and ok
	ok = _check("a call on a call stays code", _last_action_kind(expression_sheet), "raw") and ok

	# An empty sheet reports nothing rather than pretending it swept something.
	var empty_counters: Dictionary = EventSheetRawCallNamer.sweep_sheet(EventSheetResource.new())
	ok = _check("an empty sheet has no candidates", int(empty_counters.get("total", -1)), 0) and ok

	return ok


## Imports a source, then turns every lifted generic call back into a code row - which is exactly what
## a hand-typed GDScript block, or a call the lifter could not attribute, looks like in a real sheet.
static func _raw_sheet(source: String) -> EventSheetResource:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	sheet.external_source_path = "user://raw_call_namer_test.gd"
	for row: Variant in sheet.events:
		if not (row is EventRow):
			continue
		var event: EventRow = row as EventRow
		for index: int in range(event.actions.size()):
			var action: Variant = event.actions[index]
			if not (action is ACEAction) or str((action as ACEAction).ace_id) != "CallMethod":
				continue
			var raw: RawCodeRow = RawCodeRow.new()
			raw.code = ActionCodegen.generate_action(action as ACEAction, "", "")
			event.actions[index] = raw
	return sheet


static func _recompile(sheet: EventSheetResource) -> String:
	return str(SheetCompiler.compile(sheet, "user://raw_call_namer_test.gd").get("output", ""))


static func _last_action(sheet: EventSheetResource) -> Resource:
	for row: Variant in sheet.events:
		if row is EventRow and not (row as EventRow).actions.is_empty():
			var actions: Array = (row as EventRow).actions
			return actions[actions.size() - 1]
	return null


static func _last_action_kind(sheet: EventSheetResource) -> String:
	var action: Resource = _last_action(sheet)
	if action is RawCodeRow:
		return "raw"
	if action is ACEAction:
		return "ace"
	return "none"


static func _last_action_field(sheet: EventSheetResource, field: String) -> String:
	var action: Resource = _last_action(sheet)
	return "" if action == null else str(action.get(field))


static func _last_action_param(sheet: EventSheetResource, key: String) -> String:
	var action: Resource = _last_action(sheet)
	if not (action is ACEAction):
		return ""
	return str(((action as ACEAction).params as Dictionary).get(key, ""))


static func _indent_last_action(sheet: EventSheetResource) -> void:
	var action: Resource = _last_action(sheet)
	if action is RawCodeRow:
		(action as RawCodeRow).code = "\t%s" % (action as RawCodeRow).code


static func _set_last_action_code(sheet: EventSheetResource, code: String) -> void:
	var action: Resource = _last_action(sheet)
	if action is RawCodeRow:
		(action as RawCodeRow).code = code


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] raw_call_namer_test: %s" % label)
		return true
	print("[FAIL] raw_call_namer_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
