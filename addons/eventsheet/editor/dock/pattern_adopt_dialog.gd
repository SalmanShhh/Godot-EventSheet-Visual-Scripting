# Godot EventSheets - the ADOPT BEHAVIOR dialog: read what would change, then press the button.
#
# Preview-first, like Change Type Everywhere: the whole dialog is drawn from EventSheetPatternAdopt's
# plan and the commit runs that same plan's apply, so what is shown and what happens are the same
# walk over the same sheet. A reader sees the events as they read now on the left, as they would read
# on the right, every changing row marked, and a "keeps working because" line saying what was
# checked - which is the only way a beginner can reasonably be asked to trust a refactor.
#
# A plan that REFUSES draws its reason instead of a preview and offers no button. That is deliberate:
# a hand-written shape doing something the behavior cannot must be told so in the sheet's own words,
# not quietly rewritten into one that does less.
@tool
class_name EventSheetPatternAdoptDialog
extends RefCounted

## The mark on a row the adoption changes. A glyph rather than a colour, because the preview is a
## list of sentences and a reader scanning it needs the changed ones to stand out in the text
## itself.
const CHANGED_MARK := "●"

var _dock: Node = null
var _dialog: AcceptDialog = null
var _summary_label: Label = null
var _before_list: ItemList = null
var _after_list: ItemList = null
var _checks_label: Label = null
var _claim: Dictionary = {}


func init(dock: Node) -> void:
	_dock = dock


## Open the dialog for one claim. Nothing is changed until the reader presses the button.
func open(claim: Dictionary) -> void:
	_claim = claim
	var current: Dictionary = EventSheetPatternAdopt.plan(_dock._current_sheet, claim)
	_build_dialog()
	_dialog.title = str(current.get("title", "")) if bool(current.get("ok", false)) \
		else EventSheetL10n.translate("Adopt behavior")
	_fill(current)
	if _dock.is_inside_tree():
		_dialog.popup_centered(Vector2i(720, 520))


## The lines each half of the preview shows, and the "keeps working because" line under them - the
## suite-tested surface, so the words a reader is shown are pinned rather than assumed.
static func preview_lines(plan: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if not bool(plan.get("ok", false)):
		lines.append(str(plan.get("reason", "")))
		return lines
	var changed: PackedInt32Array = plan.get("changed", PackedInt32Array())
	var before: PackedStringArray = plan.get("before", PackedStringArray())
	var after: PackedStringArray = plan.get("after", PackedStringArray())
	for index: int in before.size():
		var mark: String = CHANGED_MARK if changed.has(index) else " "
		lines.append("%s %s  ->  %s" % [mark, before[index], after[index] if index < after.size() else ""])
	return lines


func _build_dialog() -> void:
	if _dialog != null:
		return
	_dialog = AcceptDialog.new()
	_dialog.ok_button_text = "Adopt"
	_dialog.add_cancel_button("Cancel")
	_dialog.confirmed.connect(confirm)
	var content: VBoxContainer = EventSheetPopupUI.form_box()
	_summary_label = EventSheetPopupUI.hint_label("")
	content.add_child(_summary_label)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(8.0)))
	_before_list = ItemList.new()
	_before_list.custom_minimum_size = Vector2(0.0, 220.0)
	_before_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_after_list = ItemList.new()
	_after_list.custom_minimum_size = Vector2(0.0, 220.0)
	_after_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(EventSheetPopupUI.titled_card("As it reads now", _before_list))
	columns.add_child(EventSheetPopupUI.titled_card("After adopting", _after_list))
	content.add_child(columns)
	_checks_label = EventSheetPopupUI.hint_label("")
	content.add_child(EventSheetPopupUI.titled_card("Keeps working because", _checks_label))
	_dialog.add_child(EventSheetPopupUI.margined(content))
	EventSheetL10n.apply_to(_dialog)
	_dock.add_child(_dialog)


## Draw one plan. A refusal fills the summary and empties everything else, and the button is
## disabled - there is nothing to press it for.
func _fill(current: Dictionary) -> void:
	_before_list.clear()
	_after_list.clear()
	var ok: bool = bool(current.get("ok", false))
	_dialog.get_ok_button().disabled = not ok
	if not ok:
		_summary_label.text = str(current.get("reason", ""))
		_checks_label.text = ""
		return
	var changed: PackedInt32Array = current.get("changed", PackedInt32Array())
	_summary_label.text = EventSheetL10n.translate("%d event(s) change; every other line of the file stays exactly as it is.") \
		% current.get("before", PackedStringArray()).size()
	var before: PackedStringArray = current.get("before", PackedStringArray())
	var after: PackedStringArray = current.get("after", PackedStringArray())
	for index: int in before.size():
		var mark: String = CHANGED_MARK if changed.has(index) else " "
		_before_list.add_item("%s %s" % [mark, before[index]])
		_after_list.add_item("%s %s" % [mark, after[index] if index < after.size() else ""])
	var checks: PackedStringArray = current.get("checks", PackedStringArray())
	_checks_label.text = "\n".join(checks)


## The commit. Through the dock's undo funnel, so one Ctrl+Z puts the hand-written shape back; the
## plan is derived again inside it, because the funnel replaces every resource with a duplicate.
func confirm() -> void:
	var claim: Dictionary = _claim
	# Named BEFORE the edit: afterwards the shape is gone, so a plan derived then would rightly
	# refuse and have nothing to name.
	var pack: String = EventSheetPatternVocabulary.pack_label(str(claim.get("adoptable", "")))
	var changed: bool = _dock._perform_undoable_sheet_edit(
		EventSheetL10n.translate("Adopt behavior"),
		func() -> bool: return EventSheetPatternAdopt.apply(_dock._current_sheet, claim) > 0)
	if changed:
		_dock._mark_dirty(EventSheetL10n.translate(
			"Adopted %s - the hand-written rows now use the shipped behavior.") % pack)
