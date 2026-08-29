# Godot EventSheets - the optimiser: a finding, a fix, and the receipt afterwards.
#
# The findings are read out of the sheet elsewhere; this is the half that CHANGES it. Two rules
# hold the whole thing together:
#
#   1. Every fix is an ordinary sheet edit through the ordinary undo funnel. Nothing is done behind
#      the compiler's back and nothing is done to a file that is not open: the row changes, the row
#      is visibly different, and Ctrl+Z puts it back. A byte-identical round trip is a promise, so
#      an existing sheet gets the visible edit rather than a cleverer compiler.
#   2. A fix that cannot be proven to leave the game behaving identically is applied ONE at a time,
#      with its dialog, and is never in the batch. Remembering a node path is safe; asking a
#      question less often is a change to the game, however sensible.
#
# The batch is one undo step for all of them, because six safe rewrites the reader approved once
# should not cost six presses of Ctrl+Z to reconsider.
@tool
class_name EventSheetOptimiser
extends RefCounted

## The re-check condition the timing fix writes. A shipped row with a shipped id - the fix adds
## vocabulary the author could have added themselves, never a private construction.
const RECHECK_PROVIDER := "Core"
const RECHECK_ACE := "EveryXSeconds"

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock


## Every finding this sheet earns right now. Derived on the spot: a sheet that has just been fixed
## reports one fewer, with nothing to clean up.
func findings() -> Array[Dictionary]:
	return EventSheetPerformanceFindings.findings(_dock._current_sheet as EventSheetResource)


## One finding, applied. True when the sheet changed - which is also when the receipt is written, so
## a fix that did nothing never claims a measurement.
func apply(finding: Dictionary) -> bool:
	var event_row: EventRow = finding.get("event") as EventRow
	if event_row == null:
		return false
	var label: String = _undo_label(str(finding.get("kind", "")))
	# A Dictionary, because a lambda captures a local by VALUE: assigning a plain variable inside the
	# edit would leave the receipt outside it empty, and the way back would quietly not exist.
	var carried: Dictionary = {}
	var applied: bool = _dock._perform_undoable_sheet_edit(label, func() -> bool:
		carried["undo"] = _rewrite(finding)
		return not (carried["undo"] as Dictionary).is_empty())
	if applied:
		_remember(event_row, str(finding.get("kind", "")), carried.get("undo", {}))
		_dock._set_status(EventSheetL10n.translate("%s - run the game with the profiler to see what it saved.") % label)
	return applied


## Every provably safe fix this sheet has, applied as ONE undo step. Returns how many rows changed.
func apply_safe() -> int:
	return apply_findings(EventSheetPerformanceFindings.safe(findings()))


## A chosen set of fixes, applied as ONE undo step. Six rewrites the reader approved once should not
## cost six presses of Ctrl+Z to reconsider.
func apply_findings(safe: Array[Dictionary]) -> int:
	if safe.is_empty():
		return 0
	var undos: Dictionary = {}
	var applied: bool = _dock._perform_undoable_sheet_edit(
		EventSheetL10n.translate("Apply the safe fixes"), func() -> bool:
			for index: int in range(safe.size()):
				var undo: Dictionary = _rewrite(safe[index])
				if not undo.is_empty():
					undos[index] = undo
			return not undos.is_empty())
	if not applied:
		return 0
	for index: Variant in undos:
		var finding: Dictionary = safe[int(index)]
		_remember(finding.get("event") as EventRow, str(finding.get("kind", "")), undos[index])
	return undos.size()


## Puts one fix back: the note's way out when the next run says it did not help. The inverse of each
## fix is as small as the fix, which is the reason only invertible repairs are offered as buttons.
func put_back(event_row: EventRow) -> bool:
	if event_row == null:
		return false
	var receipt: Dictionary = EventSheetOptimiserReceipts.receipt_for(_sheet_path(), event_row.event_uid)
	if receipt.is_empty():
		return false
	var undone: bool = _dock._perform_undoable_sheet_edit(
		EventSheetL10n.translate("Put the fix back"), func() -> bool:
			return _revert(event_row, receipt))
	if undone:
		EventSheetOptimiserReceipts.forget(_sheet_path(), event_row.event_uid)
	return undone


# ── The rewrites ───────────────────────────────────────────────────────────────────────────
## One finding's edit, inside the funnel. Returns what it would take to put the change back, or {}
## when nothing changed - the funnel commits nothing on an empty answer, so a fix that found nothing
## to do must not cost an undo step.
func _rewrite(finding: Dictionary) -> Dictionary:
	match str(finding.get("fix", "")):
		EventSheetPerformanceFindings.FIX_HOIST:
			return _hoist(finding)
		EventSheetPerformanceFindings.FIX_EVERY_N:
			return _recheck_less_often(finding)
	return {}


## The safe one: the node path moves into a variable resolved once, at ready time, and the row
## points at the variable. The sentence the row shows does not change; the line it compiles to does.
func _hoist(finding: Dictionary) -> Dictionary:
	var ace: Resource = _ace_of(finding)
	var path: String = str(finding.get("subject", ""))
	var param: String = str(finding.get("param", ""))
	if ace == null or path.is_empty() or param.is_empty():
		return {}
	var sheet: EventSheetResource = _dock._current_sheet
	var name: String = _declare_remembered_node(sheet, path)
	if name.is_empty():
		return {}
	return _write_param(ace, param, name, path, finding)


## The declaration the hoist writes: a node reference resolved at ready time, kept untyped because
## the node's class is the scene's business and a wrong annotation here would crash the game rather
## than mis-read it. Returns the name the row should point at, or "" when there is nothing to write.
##
## The name comes from the one answer the receipt reads too, so what the reader approved and what
## lands are the same variable. A declaration already holding this very lookup (a second row wanting
## the same node) is reused; nothing else is ever pointed at.
func _declare_remembered_node(sheet: EventSheetResource, path: String) -> String:
	if sheet == null:
		return ""
	var name: String = EventSheetPerformanceFindings.remembered_name_in(sheet, path)
	if name.is_empty():
		return ""
	var wanted: String = EventSheetPerformanceFindings.remembered_lookup(path)
	for entry: Variant in sheet.events:
		var existing: LocalVariable = entry as LocalVariable
		if existing != null and existing.name == name:
			return name if existing.onready and str(existing.default_value).strip_edges() == wanted else ""
	var declared: LocalVariable = LocalVariable.new()
	declared.name = name
	declared.type_name = "Variant"
	declared.onready = true
	declared.default_value = wanted
	declared.description = "Looked up once, at ready time."
	sheet.events.insert(0, declared)
	return name


## The timing one: the event keeps its per-frame trigger and gains the condition that lets it
## through five times a second. A row the author could have written, added where they would have.
func _recheck_less_often(finding: Dictionary) -> Dictionary:
	var event_row: EventRow = finding.get("event") as EventRow
	if event_row == null or _recheck_index(event_row) >= 0:
		return {}
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(RECHECK_PROVIDER, RECHECK_ACE)
	if descriptor == null:
		return {}
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = RECHECK_PROVIDER
	condition.ace_id = RECHECK_ACE
	condition.codegen_template = descriptor.codegen_template
	condition.params = {"seconds": EventSheetPerformanceFindings.RECHECK_SECONDS}
	event_row.conditions.append(condition)
	return {"put_back": "drop_recheck"}


## The inverses, one each, read off the receipt the fix left. The hoist's is the path back into the
## parameter (the declaration stays - another row may read it by now, and deleting a variable
## somebody else uses is a worse bug than the one being undone); the re-check's is the row it added.
func _revert(event_row: EventRow, receipt: Dictionary) -> bool:
	match str(receipt.get("put_back", "")):
		"drop_recheck":
			var at: int = _recheck_index(event_row)
			if at < 0:
				return false
			event_row.conditions.remove_at(at)
			return true
		"restore_param":
			var lane: Array = event_row.actions if str(receipt.get("lane", "")) == "actions" else event_row.conditions
			var index: int = int(receipt.get("index", -1))
			if index < 0 or index >= lane.size() or not (lane[index] is Resource):
				return false
			var params: Dictionary = _params_of(lane[index] as Resource)
			params[str(receipt.get("param", ""))] = str(receipt.get("was", ""))
			(lane[index] as Resource).set("params", params)
			return true
	return false


## The index of the re-check condition this optimiser added, or -1 when the event has none.
func _recheck_index(event_row: EventRow) -> int:
	for index: int in range(event_row.conditions.size()):
		var condition: ACECondition = event_row.conditions[index] as ACECondition
		if condition != null and condition.provider_id == RECHECK_PROVIDER and condition.ace_id == RECHECK_ACE:
			return index
	return -1


## One parameter, pointed at the remembered name instead of at the path. The value it HELD rides
## back in the answer, so putting the fix back is exact rather than a guess - and it is kept in the
## receipt rather than on the row, because a sheet's bytes are its author's.
func _write_param(ace: Resource, param: String, name: String, path: String,
		finding: Dictionary) -> Dictionary:
	var params: Dictionary = _params_of(ace)
	var current: String = str(params.get(param, ""))
	var rewritten: String = current.replace("get_node(\"%s\")" % path, name).replace("$%s" % path, name)
	if rewritten == current:
		return {}
	params[param] = rewritten
	ace.set("params", params)
	return {
		"put_back": "restore_param", "was": current, "param": param,
		"lane": str(finding.get("lane", "")), "index": int(finding.get("index", -1)),
	}


## The row a finding names, found again AFTER the funnel replaced the sheet's resources: by lane and
## slot on the event the finding carries, never by a reference held across the edit.
func _ace_of(finding: Dictionary) -> Resource:
	var event_row: EventRow = finding.get("event") as EventRow
	var index: int = int(finding.get("index", -1))
	if event_row == null or index < 0:
		return null
	var lane: Array = event_row.actions if str(finding.get("lane", "")) == "actions" else event_row.conditions
	return lane[index] as Resource if index < lane.size() else null


static func _params_of(ace: Resource) -> Dictionary:
	var params: Variant = ace.get("params")
	if params is Dictionary and not (params as Dictionary).is_empty():
		return params
	var fallback: Variant = ace.get("parameters")
	return fallback if fallback is Dictionary else {}


## What the undo step is called - the reader's own words for what they asked for.
static func _undo_label(kind: String) -> String:
	if kind == EventSheetPerformanceFindings.KIND_CONSTANT_LOOKUP:
		return EventSheetL10n.translate("Remember the node once")
	return EventSheetL10n.translate("Ask less often")


func _remember(event_row: EventRow, kind: String, undo: Dictionary) -> void:
	if event_row != null:
		EventSheetOptimiserReceipts.note_fix(_sheet_path(), event_row.event_uid, kind, undo)


func _sheet_path() -> String:
	var sheet: EventSheetResource = _dock._current_sheet
	if sheet == null:
		return ""
	var path: String = str(sheet.external_source_path).strip_edges()
	return path if not path.is_empty() else str(sheet.resource_path)
