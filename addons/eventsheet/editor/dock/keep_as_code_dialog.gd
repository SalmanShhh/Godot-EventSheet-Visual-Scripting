# Godot EventSheets - KEEP AS CODE: the honest exit for a row whose verb the vocabulary has lost.
#
# A pack goes away and a row is left holding a word nobody answers to. The row still compiles - its
# template was baked onto it when it was applied - so nothing is broken, but nothing can edit it
# either. This dialog is the second of the two doors that state offers: hold the line exactly as it
# is, as the same verbatim block every lift already falls back to.
#
# RECEIPT FIRST, ALWAYS. The reader is shown the row as it reads now and the block it becomes,
# side by side, before any button does anything. What lands is what was shown.
#
# THE BLOCK IS NOT A DOWNGRADE. It is precisely the shape the lift tables read, so a line kept as
# code today lifts back into words by itself the day the vocabulary grows them again - and the
# compiled file does not move a byte either way, which is what the gate below actually proves.
#
# THE COMMENT IS AN OFFER. A developer meeting this line in six months deserves to know what it was
# and where its words went, so a plain comment is offered above it - and struck out with one tick by
# anybody who does not want it. It is written in English like every other line this plugin emits:
# it becomes a line of the reader's own file the moment it lands, and a source comment that changed
# language with the editor's locale would be a surprise in somebody's diff.
@tool
class_name EventSheetKeepAsCodeDialog
extends RefCounted

## Where the byte gate compiles, and it is NEVER the sheet's own file. `SheetCompiler.compile()`
## writes its output to the path it is given, so asking it a question about a sheet with that
## sheet's real path would save the trial answer over somebody's work. Both sides compile under this
## one temporary name, outside the project, which also makes the class name identical on both sides
## so it can never be the thing that differs.
const COMPILE_PROBE_PATH: String = "user://eventforge_keep_as_code_gate.gd"

var _dock: Node = null
var _dialog: AcceptDialog = null
var _summary_label: Label = null
var _before_label: Label = null
var _after_label: Label = null
var _comment_check: CheckBox = null
var _finding: Dictionary = {}
var _comment: String = ""


func init(dock: Node) -> void:
	_dock = dock


## Open the dialog for one gone-verb finding. Nothing is changed until the reader presses the button.
func open(finding: Dictionary) -> void:
	_finding = finding
	_comment = comment_for(finding)
	_build_dialog()
	_fill()
	if _dock.is_inside_tree():
		_dialog.popup_centered(Vector2i(680, 420))


## The comment this row would carry: what it read as, and where its words went when the vocabulary
## still knows. Static and pure, so the dialog and the tests read the same sentence.
static func comment_for(finding: Dictionary) -> String:
	var reading: String = str(finding.get("reading", "")).strip_edges()
	if reading.is_empty():
		reading = str(finding.get("subject", "")).strip_edges()
	# Asked here rather than during the sweep that made the finding: answering it reflects every
	# installed pack, which is a fine price for a dialog somebody opened and a terrible one for a
	# walk that runs every time a sheet is drawn.
	var replacement: String = EventSheetMigrationFindings.replacement_key_of(
		str(finding.get("from", "")))
	var replacement_name: String = "" if replacement.is_empty() \
		else EventForgeSuccessors.split_key(replacement)[1]
	var pack: String = EventForgeSuccessors.split_key(str(finding.get("from", "")))[0]
	return EventSheetMigrationFindings.kept_comment(reading, pack, replacement_name)


## The two halves of the receipt, as the lines the dialog draws - the suite-tested surface, so the
## words a reader is shown are pinned rather than assumed.
static func receipt_lines(finding: Dictionary, comment: String) -> PackedStringArray:
	var pair: Dictionary = EventSheetMigrationFindings.keep_as_code_receipt(finding, comment)
	return PackedStringArray([str(pair["before"]), str(pair["after"])])


## The edit. One undo step through the funnel every other mutation takes, and the row is found by its
## LANE and SLOT rather than held across it - the funnel replaces resources as it commits.
##
## THE BYTE GATE RUNS FIRST, and it is the whole reason this is safe to press: the sheet is compiled
## as it stands and compiled again with the block in place of the row, WITHOUT the comment, and the
## two must be the same bytes. A row that cannot prove its own rewrite stays exactly as it was and
## says so, which is the standing rule for every rewritten row in this pass.
func confirm() -> void:
	var comment: String = _comment if _comment_check != null and _comment_check.button_pressed else ""
	var event_row: EventRow = _finding.get("event", null) as EventRow
	var slot: int = int(_finding.get("index", -1))
	if _dock._current_sheet == null or event_row == null or slot < 0:
		return
	if not _rewrite_is_byte_exact():
		_dock._set_status(EventSheetL10n.translate("This row cannot be kept as code without changing what the file compiles to, so it has been left exactly as it is."), true)
		return
	if not _dock._perform_undoable_sheet_edit(EventSheetL10n.translate("Keep as code"),
			func() -> bool:
				return EventSheetMigrationFindings.keep_it_as_code({
					"event": event_row, "index": slot, "lane": str(_finding.get("lane", "")),
					"subject": str(_finding.get("subject", "")),
					"line": str(_finding.get("line", ""))
				}, comment)):
		_dock._set_status(EventSheetL10n.translate("This row is already written as code."))
		return
	_dock._set_status(EventSheetL10n.translate("Kept as written: %s") % str(_finding.get("line", "")))


## Whether putting the block where the row is leaves the compiled file byte for byte as it was. The
## comment is left out of the question on purpose: a comment is a line the reader asked for, and what
## is being proved here is that the CODE does not move.
func _rewrite_is_byte_exact() -> bool:
	var sheet: EventSheetResource = _dock._current_sheet
	if sheet == null:
		return false
	var path: String = COMPILE_PROBE_PATH
	var before: String = str(SheetCompiler.compile(sheet, path).get("output", ""))
	if before.is_empty():
		return false
	# On a COPY, so the sheet the reader is looking at is not touched by a question about it.
	var trial: EventSheetResource = sheet.duplicate(true)
	var located: Dictionary = _same_row_in(trial)
	if located.is_empty():
		return false
	if not EventSheetMigrationFindings.keep_it_as_code({
			"event": located["event"], "index": int(located["index"]),
			"lane": str(_finding.get("lane", "")), "subject": str(_finding.get("subject", "")),
			"line": str(_finding.get("line", ""))
		}, ""):
		return false
	return str(SheetCompiler.compile(trial, path).get("output", "")) == before


## The same row, in the duplicated sheet. A deep duplicate is a different set of objects, so the row
## is found again by the address it is named by everywhere else - the event's own uid and the slot.
func _same_row_in(trial: EventSheetResource) -> Dictionary:
	var event_row: EventRow = _finding.get("event", null) as EventRow
	if event_row == null:
		return {}
	var wanted: String = event_row.event_uid
	var slot: int = int(_finding.get("index", -1))
	var found: EventRow = _event_with_uid(trial.events, wanted)
	if found == null:
		for entry: Variant in trial.functions:
			var event_function: EventFunction = entry as EventFunction
			if event_function == null:
				continue
			var rows: Array = event_function.events if not event_function.events.is_empty() \
				else event_function.rows
			found = _event_with_uid(rows, wanted)
			if found != null:
				break
	if found == null or slot < 0 or slot >= found.actions.size():
		return {}
	return {"event": found, "index": slot}


## One walk for the event carrying a uid, groups and sub-events included.
static func _event_with_uid(items: Array, wanted: String) -> EventRow:
	for item: Variant in items:
		if item is EventGroup:
			var inside: EventRow = _event_with_uid(
				EventSheetGroupFacts.children(item as EventGroup), wanted)
			if inside != null:
				return inside
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		if event_row.event_uid == wanted:
			return event_row
		var nested: EventRow = _event_with_uid(event_row.sub_events, wanted)
		if nested != null:
			return nested
	return null


## One half of the comparison: a wrapping, selectable label with room for a few lines, so a long
## sentence reads as a sentence instead of being cut off at the column edge.
func _column_label() -> Label:
	var label: Label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(260.0),
		EventSheetPalette.scaled_f(90.0))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return label


func _build_dialog() -> void:
	if _dialog != null:
		return
	_dialog = AcceptDialog.new()
	_dialog.ok_button_text = "Keep as code"
	_dialog.add_cancel_button("Cancel")
	_dialog.confirmed.connect(confirm)
	var content: VBoxContainer = EventSheetPopupUI.form_box()
	_summary_label = EventSheetPopupUI.hint_label("")
	content.add_child(_summary_label)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(8.0)))
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_before_label = _column_label()
	_after_label = _column_label()
	for card: Control in [EventSheetPopupUI.titled_card("As it reads now", _before_label),
			EventSheetPopupUI.titled_card("As it will be written", _after_label)]:
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(card)
	content.add_child(columns)
	# The comment is an OFFER: ticked by default because a line whose words went away deserves a note
	# saying so, and struck out with one click by anybody who would rather have the bare line.
	_comment_check = CheckBox.new()
	_comment_check.button_pressed = true
	_comment_check.toggled.connect(func(_on: bool) -> void: _fill())
	content.add_child(_comment_check)
	_dialog.add_child(EventSheetPopupUI.margined(content))
	EventSheetL10n.apply_to(_dialog)
	_dock.add_child(_dialog)


## Draw the receipt for the finding this dialog was opened on, as it stands with the comment on or
## off. Called again whenever the tick changes, so what is shown is always what would land.
func _fill() -> void:
	var comment: String = _comment if _comment_check.button_pressed else ""
	var lines: PackedStringArray = receipt_lines(_finding, comment)
	_dialog.title = EventSheetL10n.translate("Keep as code")
	_summary_label.text = EventSheetL10n.translate("This row keeps the line it already compiles to, written out as code. Nothing else in the file changes, and it reads back as a picked row again if the vocabulary ever has the verb once more.")
	_before_label.text = lines[0]
	_after_label.text = lines[1]
	_comment_check.text = EventSheetL10n.translate("Leave a comment above it")
	_comment_check.disabled = _comment.is_empty()
