# Godot EventSheets - MIGRATE: the one door out of the head band's counting line.
#
# A sheet's head says "3 rows have a newer spelling" and nothing else, because a row written in an
# older spelling is not wrong: it keeps its id, its template and its place in the picker forever, and
# it compiles to exactly the line it always compiled to. This dialog is where somebody who wants
# their sheets written the way the vocabulary spells things TODAY says so once.
#
# NEVER ON OPEN, NEVER ON SAVE, NEVER AUTOMATIC. This is the only place Apply exists. Opening a sheet
# full of older spellings and saving it untouched reproduces the file byte for byte, and every
# question this dialog asks is a question and writes nothing.
#
# RECEIPT FIRST, IN BOTH LANGUAGES A ROW HAS. Every row is shown twice over: the sentence it reads
# today beside the sentence it would read, and the line it writes today beside the line it would
# write. A migration that only showed the sentence would hide the half a reviewer reads in the diff;
# one that only showed the line would hide the half a beginner reads in the sheet.
#
# ROWS WITH NOWHERE TO GO ARE LISTED, NOT TOUCHED. A verb the vocabulary no longer has at all cannot
# carry a forwarding address - the address would have been on the entry that is missing - and a row
# the file itself refuses is one this cannot honestly write. Both are listed under their own heading
# with the reason, because "12 rows migrated" over a list that quietly held 13 is how trust goes.
#
# ONE UNDO STEP. Every proved row moves inside a single `_perform_undoable_sheet_edit`, so one Ctrl+Z
# puts all of them back with their ids, templates, values and readings unharmed. The plan is built
# again INSIDE that edit and dropped when it commits: the funnel replaces every resource with a
# snapshot duplicate, so no row reference may outlive it.
@tool
class_name EventSheetMigrateDialog
extends RefCounted

var _dock: Node = null
var _dialog: AcceptDialog = null
var _summary_label: Label = null
var _rewrite_list: ItemList = null
var _left_alone_card: Control = null
var _left_alone_list: ItemList = null
var _planned: Array[Dictionary] = []
## The vocabulary this receipt was drawn against, held so the button answers the same corpus the
## reader was shown. Reflecting the installed packs twice would let the two disagree.
var _vocabulary: Dictionary = {}


func init(dock: Node) -> void:
	_dock = dock


## Opens the dialog over the sheet in front of the reader. Nothing is changed until the button.
func open(vocabulary: Dictionary = {}) -> void:
	if _dock == null or _dock._current_sheet == null:
		return
	_vocabulary = vocabulary
	_planned = EventSheetMigrationPlan.plan(_dock._current_sheet, _vocabulary)
	if _planned.is_empty():
		_dock._set_status(EventSheetL10n.translate(
			"Every row in this sheet is written in the spelling the vocabulary uses today."))
		return
	_build_dialog()
	_fill()
	if _dock.is_inside_tree():
		_dialog.popup_centered(Vector2i(760, 520))


## The rewrite list, exactly as the dialog draws it: two lines per row, the sentence then the code.
## The suite reads THIS, so the words a reader is shown are pinned rather than assumed.
static func preview_lines(planned: Array[Dictionary]) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for entry: Dictionary in EventSheetMigrationPlan.migrating(planned):
		lines.append("%s → %s" % [_said(entry, "reading_before"), _said(entry, "reading_after")])
		lines.append("    %s → %s" % [str(entry.get("before", "")), str(entry.get("after", ""))])
	return lines


## The other list: every row that is named and left exactly as it is, with the reason beside it.
static func left_alone_lines(planned: Array[Dictionary]) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for entry: Dictionary in EventSheetMigrationPlan.asking(planned):
		lines.append("%s - %s" % [_said(entry, "reading_before"), reason_text(entry)])
	return lines


## Why one row is being left alone, in the words the reader needs to decide what to do about it.
## Each reason names a different situation and a different next step, which is the whole reason they
## are four sentences rather than one "could not migrate".
static func reason_text(entry: Dictionary) -> String:
	match str(entry.get("why", "")):
		EventSheetMigrationPlan.WHY_NO_SUCCESSOR:
			return EventSheetL10n.translate("the vocabulary has no newer spelling for this one, so it stays exactly as written")
		EventSheetMigrationPlan.WHY_NEEDS_PICKING:
			return EventSheetL10n.translate("the newer verb keeps state of its own, so it has to be picked rather than rewritten")
		EventSheetMigrationPlan.WHY_FILE_REFUSES:
			return EventSheetL10n.translate("the rewritten line is not something this file would compile, so it is left alone")
	return EventSheetL10n.translate("the rewritten row could not be read back as the same row, so it is left alone")


## The summary above both lists: what would move, and what would not.
static func summary_text(planned: Array[Dictionary]) -> String:
	var moving: int = EventSheetMigrationPlan.migrating(planned).size()
	var staying: int = EventSheetMigrationPlan.asking(planned).size()
	if moving == 0:
		return EventSheetL10n.translate("Nothing here can be rewritten on its own - %d row(s) are listed below with the reason.") % staying
	if staying == 0:
		return EventSheetL10n.translate("%d row(s) would be rewritten, in one step you can undo.") % moving
	return EventSheetL10n.translate("%d row(s) would be rewritten in one step you can undo, and %d are left exactly as they are.") % [
		moving, staying]


## THE EDIT. One undo step for every proved row, through the funnel every other mutation takes.
##
## The plan is built AGAIN inside the closure rather than reused from the preview: the funnel snapshots
## the sheet around the operation, and a plan built before the dialog opened holds references to rows
## the reader may have edited since. Building it here means what lands is proved against the sheet as
## it stands at the moment the button is pressed.
##
## AND IT HAS TO BE THE SAME PLAN. Rebuilding is necessary and not sufficient: a row pasted, edited or
## deleted while this window was open makes the fresh plan a DIFFERENT plan, and applying it would
## rewrite rows that never appeared in "What will be rewritten" while the status line reported the
## larger count. So the two are compared as the receipts they draw, and a plan that has moved is not
## applied at all - the window redraws on what the sheet says now, and the reader reads it again.
## Nothing is rewritten that was not read first, which is the whole rule this pass is built on.
func confirm() -> void:
	if _dock == null or _dock._current_sheet == null:
		return
	var shown: PackedStringArray = EventSheetMigrationPlan.receipt_of(_planned)
	var moved: Array[int] = [0]
	var moved_on: Array[bool] = [false]
	if not _dock._perform_undoable_sheet_edit(EventSheetL10n.translate("Migrate rows"),
			func() -> bool:
				var now: Array[Dictionary] = EventSheetMigrationPlan.plan(_dock._current_sheet,
					_vocabulary)
				if EventSheetMigrationPlan.receipt_of(now) != shown:
					moved_on[0] = true
					return false
				moved[0] = EventSheetMigrationPlan.apply(now)
				return moved[0] > 0):
		if moved_on[0]:
			_redraw_on_what_the_sheet_says_now()
			return
		_dock._set_status(EventSheetL10n.translate(
			"Nothing was rewritten - every row here is either already current or listed as one this cannot write."))
		return
	_dock._set_status(EventSheetL10n.translate("%d row(s) migrated - one Ctrl+Z takes all of it back.")
		% moved[0])


## What happens when the sheet moved under an open receipt: nothing is written, the window is drawn
## again on the plan the sheet has now, and the reader is told why they are reading it twice.
func _redraw_on_what_the_sheet_says_now() -> void:
	_planned = EventSheetMigrationPlan.plan(_dock._current_sheet, _vocabulary)
	_fill()
	if _dock.is_inside_tree():
		_dialog.popup_centered(Vector2i(760, 520))
	_dock._set_status(EventSheetL10n.translate("This sheet changed while the receipt was open, so nothing was rewritten - here is what it says now."), true)


## One half of one line of the receipt, falling back to the row's own verb id when it has no sentence
## to show - a row applied before readings were baked has none, and an id is a poorer answer than a
## sentence but a far better one than a blank.
static func _said(entry: Dictionary, key: String) -> String:
	var text: String = str(entry.get(key, "")).strip_edges()
	if not text.is_empty():
		return text
	return EventForgeSuccessors.split_key(str(entry.get("from", "")))[1]


func _build_dialog() -> void:
	if _dialog != null:
		return
	_dialog = AcceptDialog.new()
	_dialog.ok_button_text = EventSheetL10n.translate("Migrate These Rows")
	_dialog.add_cancel_button(EventSheetL10n.translate("Cancel"))
	_dialog.confirmed.connect(confirm)
	var content: VBoxContainer = EventSheetPopupUI.form_box()
	_summary_label = EventSheetPopupUI.hint_label("")
	content.add_child(_summary_label)
	_rewrite_list = EventSheetPopupUI.sized_list(180.0)
	content.add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("What will be rewritten"), _rewrite_list))
	_left_alone_list = EventSheetPopupUI.sized_list(90.0)
	_left_alone_card = EventSheetPopupUI.titled_card(EventSheetL10n.translate("Left exactly as they are"), _left_alone_list)
	content.add_child(_left_alone_card)
	_dialog.add_child(EventSheetPopupUI.margined(content))
	EventSheetL10n.apply_to(_dialog)
	_dock.add_child(_dialog)


## Draws the receipt for the plan this dialog was opened on. What is shown is what would land: both
## lists come from the same plan the button applies.
func _fill() -> void:
	_dialog.title = EventSheetL10n.translate("Migrate rows")
	_summary_label.text = summary_text(_planned)
	_rewrite_list.clear()
	for line: String in preview_lines(_planned):
		_rewrite_list.add_item(line)
		# A long sentence is wider than the list; the tooltip carries the whole of it so nothing the
		# receipt promises to say is only half-said.
		_rewrite_list.set_item_tooltip(_rewrite_list.item_count - 1, line)
	_left_alone_list.clear()
	for line: String in left_alone_lines(_planned):
		_left_alone_list.add_item(line)
		_left_alone_list.set_item_tooltip(_left_alone_list.item_count - 1, line)
	# A card with nothing under it is a heading that says a sheet has a problem it does not have.
	_left_alone_card.visible = _left_alone_list.item_count > 0
	_dialog.get_ok_button().disabled = _rewrite_list.item_count == 0
