# Godot EventSheets - "Optimise this sheet": what would change, before anything does.
#
# The optimiser is allowed to rewrite rows, so the whole of its trustworthiness is in this dialog:
# it shows the line the row compiles to NOW and the line it would compile to AFTER, and it does not
# touch anything until the reader has read both. Two shapes, one window:
#
#   ONE finding    the row, the reason, what it costs today, and the two lines side by side.
#   THE BATCH      every provably safe fix as a ticked box, the timing ones listed unticked with
#                  the reason they are not offered in bulk, and one button that applies the ticked
#                  ones as a SINGLE undo step.
#
# The line pairs are built by the compiler's own echo, never by a re-implementation, so the dialog
# cannot promise a line the compiler would not write.
@tool
class_name EventSheetOptimiseDialog
extends RefCounted

var _dock: Control = null
var _dialog: ConfirmationDialog = null
var _body: VBoxContainer = null
## The ONE help strip at the foot: what the focused choice is, what the sheet will read as
## afterwards, and the line it compiles to.
var _help_strip: EventSheetPopupUI.HelpStrip = null
## The finding this window is currently about ({} while it is showing the batch), and the tick boxes
## of the batch, in the order the findings came.
var _finding: Dictionary = {}
var _checks: Array[CheckBox] = []
var _safe: Array[Dictionary] = []


func init(dock: Control) -> void:
	_dock = dock


## One finding, with its diff. Confirming applies exactly that fix, as its own undo step.
func confirm_one(finding: Dictionary) -> void:
	if finding.is_empty():
		return
	_finding = finding
	_safe = []
	_build()
	_dialog.title = EventSheetL10n.translate("Optimise this row")
	_dialog.ok_button_text = EventSheetL10n.translate("Apply")
	_fill_one(finding)
	_dialog.popup_centered(Vector2i(560, 420))


## The whole sheet: the safe fixes as ticks, the timing ones as a list with their reason.
func open_batch() -> void:
	_finding = {}
	var found: Array[Dictionary] = _dock._optimiser.findings()
	_safe = EventSheetPerformanceFindings.safe(found)
	_build()
	_dialog.title = EventSheetL10n.translate("Optimise this sheet")
	_dialog.ok_button_text = EventSheetL10n.translate("Apply %d safe fixes") % _safe.size()
	_fill_batch(found)
	_dialog.popup_centered(Vector2i(600, 480))


func _build() -> void:
	if _dialog == null:
		_dialog = ConfirmationDialog.new()
		_dialog.visible = false
		_dialog.confirmed.connect(_on_confirmed)
		_dock.add_child(_dialog)
		var form: VBoxContainer = EventSheetPopupUI.form_box()
		_dialog.add_child(EventSheetPopupUI.margined(form))
		_body = EventSheetPopupUI.form_box()
		form.add_child(_body)
		_help_strip = EventSheetPopupUI.help_strip()
		form.add_child(_help_strip)
	for stale: Node in _body.get_children():
		stale.queue_free()
		_body.remove_child(stale)
	_checks = []


func _fill_one(finding: Dictionary) -> void:
	_body.add_child(EventSheetPopupUI.hint_label(str(finding.get("message", ""))))
	_body.add_child(EventSheetPopupUI.labelled_card(EventSheetL10n.translate("WHAT CHANGES"),
		EventSheetPopupUI.compact_table(
			PackedStringArray([EventSheetL10n.translate("Now"), EventSheetL10n.translate("After")]),
			[diff_lines(finding, _dock._current_sheet)], 1)))
	var cost: String = cost_words(finding)
	if not cost.is_empty():
		_body.add_child(EventSheetPopupUI.hint_label(cost))
	_help_strip.describe(_heading(finding), _explanation(finding))
	_help_strip.set_reading(str(finding.get("message", "")), str(diff_lines(finding, _dock._current_sheet)[1]))


func _fill_batch(found: Array[Dictionary]) -> void:
	if found.is_empty():
		_body.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate(
			"Nothing in this sheet is spending a frame it did not have to. Run the game with the profiler and look again after the game has grown.")))
		_help_strip.describe(EventSheetL10n.translate("Nothing to do"), EventSheetL10n.translate(
			"The optimiser reads the sheet, not the run: a sheet with no per-frame work earns no findings, whether or not a game has ever been run."))
		return
	for finding: Dictionary in _safe:
		var check: CheckBox = CheckBox.new()
		check.text = str(finding.get("message", ""))
		check.button_pressed = true
		check.focus_entered.connect(func() -> void:
			_help_strip.describe(_heading(finding), _explanation(finding))
			_help_strip.set_reading(str(finding.get("message", "")), str(diff_lines(finding, _dock._current_sheet)[1])))
		_checks.append(check)
		_body.add_child(check)
	var timing: Array[Dictionary] = []
	for finding: Dictionary in found:
		if not bool(finding.get("safe", false)):
			timing.append(finding)
	if not timing.is_empty():
		var rows: Array = []
		for finding: Dictionary in timing:
			rows.append(PackedStringArray([str(finding.get("message", "")), _why_not_batched(finding)]))
		_body.add_child(EventSheetPopupUI.labelled_card(EventSheetL10n.translate("ONE AT A TIME"),
			EventSheetPopupUI.compact_table(PackedStringArray([
				EventSheetL10n.translate("Finding"), EventSheetL10n.translate("Why not in the batch")]), rows, 0)))
	_help_strip.describe(
		EventSheetL10n.translate("Safe fixes · %d row(s)") % _safe.size(),
		EventSheetL10n.translate("Every ticked fix keeps the game behaving exactly as it does now - only the emitted code changes. They apply as ONE undo step. The ones below change WHEN something happens, so they are opened one at a time."))
	_help_strip.set_reading("",
		"" if _safe.is_empty() else str(diff_lines(_safe[0], _dock._current_sheet)[1]))


func _on_confirmed() -> void:
	if not _finding.is_empty():
		_dock._optimiser.apply(_finding)
		_dock._refresh_after_edit()
		return
	var wanted: Array[Dictionary] = []
	for index: int in range(_checks.size()):
		if _checks[index].button_pressed and index < _safe.size():
			wanted.append(_safe[index])
	var changed: int = _dock._optimiser.apply_findings(wanted)
	if changed > 0:
		_dock._refresh_after_edit()
	_dock._set_status(EventSheetL10n.translate("%d row(s) optimised, as one undo step.") % changed
		if changed > 0 else EventSheetL10n.translate("Nothing was changed."), changed <= 0)


# ── What the dialog says (static and pure, so the suite reads every word of it) ─────────────
## The line this row compiles to now, and the line it would compile to after the fix - the pair the
## reader is being asked to approve. Both come from the compiler's own echo of the row.
## `sheet` is what the fix would be written into: the name a hoist lands on depends on what is
## already declared there, and a receipt showing a different name from the one that lands is not a
## receipt. Null is allowed - a caller with no sheet in hand gets the plain readable name.
static func diff_lines(finding: Dictionary, sheet: EventSheetResource = null) -> PackedStringArray:
	var event_row: EventRow = finding.get("event") as EventRow
	var lane: Array = []
	if event_row != null:
		lane = event_row.actions if str(finding.get("lane", "")) == "actions" else event_row.conditions
	var index: int = int(finding.get("index", -1))
	var now: String = ""
	if index >= 0 and index < lane.size() and lane[index] is Resource:
		now = EventSheetLightingFindings.compiled_line(lane[index] as Resource)
	match str(finding.get("fix", "")):
		EventSheetPerformanceFindings.FIX_HOIST:
			var path: String = str(finding.get("subject", ""))
			var name: String = EventSheetPerformanceFindings.remembered_name_in(sheet, path)
			return PackedStringArray([now, now.replace("get_node(\"%s\")" % path, name).replace("$%s" % path, name)])
		EventSheetPerformanceFindings.FIX_EVERY_N:
			return PackedStringArray([
				EventSheetL10n.translate("every tick"),
				"__every_… >= maxf(%s, 0.001)" % EventSheetPerformanceFindings.RECHECK_SECONDS])
	return PackedStringArray([now, now])


## What the last profiled run says this row costs, or "" when nothing has measured it. A finding on a
## row nobody has ever paid for reads differently from a finding on the row eating the frame, and the
## dialog is where that difference belongs.
static func cost_words(finding: Dictionary) -> String:
	var ms: float = float(finding.get("measured_ms", -1.0))
	if ms < 0.0:
		return EventSheetL10n.translate("No profiled run has measured this row, so there is no number beside it yet.")
	return EventSheetL10n.translate("The last profiled run measured %.2f ms a fire here.") % ms


## Why a timing fix is not in the batch, in the words of what it would change.
static func _why_not_batched(finding: Dictionary) -> String:
	match str(finding.get("fix", "")):
		EventSheetPerformanceFindings.FIX_EVERY_N:
			return EventSheetL10n.translate("changes how often the row runs")
		EventSheetPerformanceFindings.FIX_TIME_SLICER, EventSheetPerformanceFindings.FIX_OBJECT_POOL:
			return EventSheetL10n.translate("adds a behaviour to the scene")
	return EventSheetL10n.translate("a decision about the game, not a line to rewrite")


static func _heading(finding: Dictionary) -> String:
	return EventSheetL10n.translate("Safe fix") if bool(finding.get("safe", false)) \
		else EventSheetL10n.translate("Changes the timing")


static func _explanation(finding: Dictionary) -> String:
	if bool(finding.get("safe", false)):
		return EventSheetL10n.translate("The game behaves exactly as it does now - only the emitted line changes, and Ctrl+Z puts it back. The row keeps reading the way it reads.")
	return EventSheetL10n.translate("This one changes WHEN the work happens, so it is applied on its own and its effect is measured on the next profiled run.")
