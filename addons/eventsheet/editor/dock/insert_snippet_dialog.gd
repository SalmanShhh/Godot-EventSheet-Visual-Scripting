@tool
extends ConfirmationDialog
# "Insert Snippet…" - the project's snippet library and the snippet's blanks in ONE window.
#
# The list on the left of the window is every snippet in the library, by the name it was saved
# under, searchable, with how many blanks each asks for. Picking one shows its blanks as fields
# ({{blank:Label}} in the snippet's text), seeded with the defaults its author demonstrated; Insert
# lands the rows filled, with no placeholder left anywhere, and a snippet without blanks inserts
# straight away. The snippet file keeps its blanks for next time.
#
# `confirm()` is the tested surface: it fills the text and hands it to the shipped one-undo-step
# paste path, which assigns fresh event uids and creates any missing sheet variables. Nothing here
# inserts rows of its own. No class_name: author_actions loads this by path on first use.

const DIALOG_NAME := "EventSheetInsertSnippetDialog"

var _dock: Control = null
var _snippets: PackedStringArray = PackedStringArray()
var _shown: PackedStringArray = PackedStringArray()
var _search: LineEdit = null
var _list: Tree = null
var _fill_card: Control = null
var _fields_box: VBoxContainer = null
var _note: EventSheetPopupUI.StateNote = null
var _strip: EventSheetPopupUI.HelpStrip = null
var _snippet_path: String = ""
var _snippet_text: String = ""
var _fields: Array[Dictionary] = []


## Opens the window over the library, replacing one still on screen. Returns it so callers and tests
## can drive it; the dock owns it as a child, so it lives exactly as long as the sheet editor does.
static func open_for(dock: Control, snippets: PackedStringArray) -> ConfirmationDialog:
	if dock == null:
		return null
	var stale: Node = dock.get_node_or_null(DIALOG_NAME)
	if stale != null:
		dock.remove_child(stale)
		stale.queue_free()
	var dialog: ConfirmationDialog = load("res://addons/eventsheet/editor/dock/insert_snippet_dialog.gd").new()
	dialog.name = DIALOG_NAME
	dialog.call("configure", dock, snippets)
	dock.add_child(dialog)
	if dock.is_inside_tree():
		EventSheetPopupUI.popup_fitted(dialog, Vector2i(EventSheetPalette.scaled(480), 0))
	return dialog


## The name a snippet is listed and titled by: its file's name exactly as saved, never re-cased.
static func snippet_label(snippet_path: String) -> String:
	return snippet_path.get_file().get_basename()


func configure(dock: Control, snippets: PackedStringArray) -> void:
	_dock = dock
	_snippets = snippets
	title = EventSheetL10n.translate("Insert Snippet")
	ok_button_text = EventSheetL10n.translate("Insert")
	# OK must not throw the form away on the one press that refuses: a blank left empty is refused,
	# and confirm() hides on success itself.
	dialog_hide_on_ok = false
	confirmed.connect(func() -> void: confirm())
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	var library: VBoxContainer = EventSheetPopupUI.form_box()
	_search = LineEdit.new()
	_search.placeholder_text = EventSheetL10n.translate("Search snippets")
	_search.right_icon = EventSheetPopupUI._editor_icon("Search")
	_search.text_changed.connect(func(_typed: String) -> void: _fill_list())
	library.add_child(_search)
	_list = Tree.new()
	_list.columns = 2
	_list.hide_root = true
	_list.set_column_expand(1, false)
	_list.set_column_custom_minimum_width(1, EventSheetPalette.scaled(100))
	_list.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(420.0), EventSheetPalette.scaled_f(140.0))
	_list.item_selected.connect(func() -> void:
		var item: TreeItem = _list.get_selected()
		if item != null:
			select_snippet(str(item.get_metadata(0))))
	_list.item_activated.connect(func() -> void: confirm())
	library.add_child(_list)
	form.add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("Snippets"), library))
	_fields_box = EventSheetPopupUI.form_box()
	_fill_card = EventSheetPopupUI.titled_card(EventSheetL10n.translate("Fill in"), _fields_box)
	form.add_child(_fill_card)
	_note = EventSheetPopupUI.StateNote.new(EventSheetPalette.scaled_f(400.0))
	form.add_child(_note)
	_strip = EventSheetPopupUI.help_strip(EventSheetL10n.translate("Fill in"),
		EventSheetL10n.translate("Fill it once and the rows land filled; the snippet keeps its blanks for next time."),
		"", "", EventSheetPalette.scaled_f(400.0))
	form.add_child(_strip)
	_strip.follow(_search, EventSheetL10n.translate("Search snippets"),
		EventSheetL10n.translate("Narrows the list to the snippets whose name holds what you type."))
	_strip.follow(_list, EventSheetL10n.translate("Snippets"),
		EventSheetL10n.translate("Every snippet in the project's library, by the name it was saved under. Save Selection as Snippet… adds to it."))
	add_child(EventSheetPopupUI.margined(form))
	_fill_list()


## Rebuilds the list for the search, keeping the chosen snippet chosen while it is still shown.
func _fill_list() -> void:
	_list.clear()
	var root: TreeItem = _list.create_item()
	var needle: String = _search.text.strip_edges().to_lower()
	var keep: TreeItem = null
	for snippet_path: String in _snippets:
		var label: String = snippet_label(snippet_path)
		if not needle.is_empty() and not label.to_lower().contains(needle):
			continue
		var item: TreeItem = _list.create_item(root)
		item.set_text(0, label)
		item.set_tooltip_text(0, snippet_path)
		item.set_metadata(0, snippet_path)
		var blanks: int = EventSheetSnippet.blanks_in(EventSheetSnippetLibrary.read_snippet(snippet_path)).size()
		if blanks > 0:
			item.set_text(1, EventSheetL10n.translate("{n} blank(s)").replace("{n}", str(blanks)))
			item.set_custom_color(1, EventSheetPopupUI.muted_text_color())
		if snippet_path == _snippet_path:
			keep = item
	if keep == null and root.get_child_count() > 0:
		keep = root.get_child(0)
	if keep != null:
		keep.select(0)
		select_snippet(str(keep.get_metadata(0)))
	else:
		select_snippet("")


## Shows THIS snippet's blanks as fields, each seeded with the blank's own default so a form left
## untouched still produces the rows the snippet's author demonstrated.
func select_snippet(snippet_path: String) -> void:
	if snippet_path == _snippet_path and not snippet_path.is_empty():
		return
	_snippet_path = snippet_path
	# The list follows a choice made from outside it (an insert by path), without asking again.
	var root: TreeItem = _list.get_root()
	if root != null:
		for item: TreeItem in root.get_children():
			if str(item.get_metadata(0)) == snippet_path and not item.is_selected(0):
				item.select(0)
	_snippet_text = EventSheetSnippetLibrary.read_snippet(snippet_path) if not snippet_path.is_empty() else ""
	for old: Node in _fields_box.get_children():
		_fields_box.remove_child(old)
		old.queue_free()
	for field: Dictionary in _fields:
		_strip.followed.erase(field["edit"])
	_fields.clear()
	for blank: Dictionary in EventSheetSnippet.blanks_in(_snippet_text):
		var edit: LineEdit = LineEdit.new()
		edit.text = str(blank.get("default", ""))
		edit.placeholder_text = str(blank.get("label", ""))
		edit.text_changed.connect(func(_typed: String) -> void: refresh_summary())
		_fields_box.add_child(EventSheetPopupUI.form_row(str(blank.get("label", "")), edit))
		_fields.append({"label": str(blank.get("label", "")), "edit": edit})
		_strip.follow(edit, str(blank.get("label", "")),
			EventSheetL10n.translate("Fill it once and the rows land filled; the snippet keeps its blanks for next time."))
	_fill_card.visible = not _fields.is_empty()
	_strip.set_reading("", "")
	_strip.in_code_value.text = snippet_path
	_strip.in_code_row.visible = not snippet_path.is_empty()
	refresh_summary()


## label -> the answer typed for it.
func values() -> Dictionary:
	var answers: Dictionary = {}
	for field: Dictionary in _fields:
		answers[str(field.get("label", ""))] = (field.get("edit") as LineEdit).text.strip_edges()
	return answers


## Says, before Insert is pressed, whether anything is still unanswered - a blank left empty would
## land a row with a placeholder in it, which is the one thing this window promises never to do.
func refresh_summary() -> void:
	if _snippet_path.is_empty():
		_note.say(EventSheetL10n.translate("No snippet's name holds that."), EventSheetPopupUI.TONE_WARNING)
		get_ok_button().disabled = true
		return
	var missing: PackedStringArray = EventSheetSnippet.missing_blanks(_snippet_text, values())
	get_ok_button().disabled = not missing.is_empty()
	if missing.is_empty():
		_note.say(EventSheetL10n.translate("Ready to insert."), EventSheetPopupUI.TONE_OK)
	else:
		_note.say(EventSheetL10n.translate("Still to fill in: {blanks}.").replace("{blanks}", ", ".join(missing)))


## Fills the blanks and inserts the rows as ONE undo step through the shipped paste path.
## Returns true when rows landed.
func confirm() -> bool:
	if _dock == null or _snippet_path.is_empty() or not _dock._ensure_sheet_for_editing():
		return false
	if not EventSheetSnippet.missing_blanks(_snippet_text, values()).is_empty():
		refresh_summary()
		return false
	var snippet: Dictionary = EventSheetSnippet.deserialize(EventSheetSnippet.fill_blanks(_snippet_text, values()))
	if (snippet.get("rows", []) as Array).is_empty():
		_note.say(EventSheetL10n.translate("{file} isn't a sheet snippet.").replace("{file}", _snippet_path.get_file()))
		return false
	var inserted: bool = _dock._clipboard_glue.paste_snippet(snippet, "Insert Snippet")
	if inserted:
		hide()
	return inserted
