@tool
class_name EventSheetSnippetBlanksDialog
extends AcceptDialog
# "Insert Snippet…", for a snippet that carries BLANKS.
#
# Snippets ship and are well built - Save Selection as Snippet, Insert Snippet, and a portable text
# form that survives crossing projects and chat clients. They are strictly literal, so every reuse
# is insert-then-fix-the-five-values. A snippet whose author wrote {{blank:Label}} into a parameter
# gets this small form instead: one field per label, filled once, and what lands on the sheet is
# plain conditions and actions with no placeholder left anywhere.
#
# Insert stays exactly where it is. The library's insert path (dock/author_actions.gd) asks
# EventSheetSnippet.has_blanks and opens this only when the answer is yes, so a snippet without
# blanks behaves precisely as it always did.
#
# `confirm()` is the tested surface: it fills the text and hands it to the shipped one-undo-step
# paste path, which assigns fresh event uids and creates any missing sheet variables. Nothing here
# inserts rows of its own.

const DIALOG_NAME := "EventSheetSnippetBlanksDialog"

var _dock: Control = null
var _snippet_text: String = ""
var _fields: Array[Dictionary] = []
var _summary: Label = null


## Opens the fill-in form for a snippet, replacing any form still on screen from a previous insert
## (a different snippet means different fields). Returns the dialog so callers and tests can drive
## it; the dock owns it as a child, so it lives exactly as long as the sheet editor does.
static func open_for(dock: Control, snippet_name: String, text: String) -> EventSheetSnippetBlanksDialog:
	if dock == null:
		return null
	var stale: Node = dock.get_node_or_null(DIALOG_NAME)
	if stale != null:
		dock.remove_child(stale)
		stale.queue_free()
	var dialog: EventSheetSnippetBlanksDialog = EventSheetSnippetBlanksDialog.new()
	dialog.name = DIALOG_NAME
	dialog.configure(dock, snippet_name, text)
	dock.add_child(dialog)
	if dock.is_inside_tree():
		dialog.popup_centered(Vector2i(EventSheetPalette.scaled(460), EventSheetPalette.scaled(320)))
	return dialog


## Builds the form for THIS snippet: one labelled field per blank, seeded with the blank's own
## default so a form left untouched still produces the rows the snippet's author demonstrated.
func configure(dock: Control, snippet_name: String, text: String) -> void:
	_dock = dock
	_snippet_text = text
	_fields.clear()
	title = "Insert Snippet"
	ok_button_text = "Insert"
	# AcceptDialog hides on OK BEFORE `confirmed` reaches confirm(), which would throw the form away
	# on the one press that must keep it: a blank left empty is refused, and the refusal is worthless
	# if it costs the reader every other answer they typed. confirm() hides on success itself.
	dialog_hide_on_ok = false
	add_cancel_button("Cancel")
	confirmed.connect(func() -> void: confirm())
	var content: VBoxContainer = EventSheetPopupUI.form_box()
	content.add_child(EventSheetPopupUI.hint_label(
		"\"%s\" asks for a few values. Fill them in and the rows land filled - the snippet keeps its blanks for next time." % snippet_name))
	var fields_box: VBoxContainer = EventSheetPopupUI.form_box()
	for blank: Dictionary in EventSheetSnippet.blanks_in(text):
		var edit: LineEdit = LineEdit.new()
		edit.text = str(blank.get("default", ""))
		edit.placeholder_text = str(blank.get("label", ""))
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.text_changed.connect(func(_typed: String) -> void: refresh_summary())
		fields_box.add_child(EventSheetPopupUI.form_row(str(blank.get("label", "")), edit))
		_fields.append({"label": str(blank.get("label", "")), "edit": edit})
	content.add_child(EventSheetPopupUI.titled_card("Fill in", fields_box))
	_summary = EventSheetPopupUI.hint_label("")
	content.add_child(_summary)
	add_child(EventSheetPopupUI.margined(content))
	EventSheetL10n.apply_to(self)
	refresh_summary()


## label -> the answer typed for it.
func values() -> Dictionary:
	var answers: Dictionary = {}
	for field: Dictionary in _fields:
		answers[str(field.get("label", ""))] = (field.get("edit") as LineEdit).text.strip_edges()
	return answers


## Says, before the button is pressed, whether anything is still unanswered - a blank left empty
## would land a row with a placeholder in it, which is the one thing this feature promises never
## to do. Called on every keystroke and from confirm(), so the sentence and the refusal agree.
func refresh_summary() -> void:
	if _summary == null:
		return
	var missing: PackedStringArray = EventSheetSnippet.missing_blanks(_snippet_text, values())
	_summary.text = "Ready to insert." if missing.is_empty() else "Still to fill in: %s." % ", ".join(missing)


## Fills the blanks and inserts the rows as ONE undo step through the shipped paste path.
## Returns true when rows landed.
func confirm() -> bool:
	if _dock == null or not _dock._ensure_sheet_for_editing():
		return false
	var missing: PackedStringArray = EventSheetSnippet.missing_blanks(_snippet_text, values())
	if not missing.is_empty():
		_dock._set_status("Fill in %s first - a blank left empty would land a row with a placeholder in it." % ", ".join(missing), true)
		refresh_summary()
		return false
	# The shipped one-undo-step paste path, handed the FILLED snippet: fresh event uids, missing
	# sheet variables created, never overwritten. Called through paste_snippet rather than the text
	# front so the answer here means "rows landed", not "that text was a snippet".
	var inserted: bool = _dock._clipboard_glue.paste_snippet(
		EventSheetSnippet.deserialize(EventSheetSnippet.fill_blanks(_snippet_text, values())), "Insert Snippet")
	if inserted:
		hide()
	return inserted
