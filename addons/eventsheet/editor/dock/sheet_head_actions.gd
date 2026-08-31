@tool
class_name EventSheetHeadActions
extends RefCounted
# The gestures on the sheet's HEAD bands - the dock side of the band stack.
#
# Each band of the head stands for exactly one line of the file, so each gesture writes exactly that
# line: F2 on the name band renames the class everywhere, "change…" on the extends band opens the
# host picker, the icon swatch opens a file dialog, the `@tool` switch writes or removes the
# annotation, the description edits in place, and "+ add" offers only the lines this sheet could
# have and does not.
#
# The rewrite itself is `rewrite_prelude()` - pure, static and testable: a block of prelude text and
# one band goes in, the same text with that one line written goes out. Nothing here stores a fact
# anywhere but in the file (and, for a `.tres` sheet whose prelude the compiler writes, in the
# matching sheet field), so a band can never disagree with the line it echoes.

var _dock: Control = null
var _icon_dialog: EditorFileDialog = null
var _add_menu: PopupMenu = null
var _add_offers: PackedStringArray = PackedStringArray()
var _rename_dialog: ConfirmationDialog = null
var _rename_edit: LineEdit = null
var _rename_count: Label = null
var _text_dialog: ConfirmationDialog = null
var _text_edit: LineEdit = null
var _text_band: String = ""


func init(dock: Control) -> void:
	_dock = dock


## One band's gesture. The viewport names the band; everything a gesture needs (the sheet, the
## dialogs, the undo funnel) lives here.
func handle(action: String) -> void:
	if _dock._current_sheet == null:
		return
	# The bands that stand for a fact of the SCENE name the node they are about after
	# a colon. All of them mean the same gesture: the other editor of that fact - the Replication
	# panel, the Inspector - is over there, so open the scene and select the node. Asked of the band
	# model rather than listed here, so a scene band a later pass adds arrives already clickable.
	# The spawns band is about a FILE rather than about a node of a scene, so its gesture is the one
	# a file wants: show it where it lives. Answered before the loop below because it is the one scene
	# band whose reference is a scene path on its own, with no node inside it to select.
	if action.begins_with("%s:" % EventSheetHeadBands.BAND_SPAWNS):
		browse_to_scene(action.trim_prefix("%s:" % EventSheetHeadBands.BAND_SPAWNS))
		return
	for scene_band: Variant in EventSheetHeadBands.SCENE_BANDS.keys():
		if not action.begins_with("%s:" % scene_band):
			continue
		var reference: String = action.trim_prefix("%s:" % scene_band)
		reveal_scene_node(reference.get_slice("|", 0), reference.get_slice("|", 1))
		return
	match action:
		EventSheetHeadBands.BAND_NAME:
			open_class_rename()
		EventSheetHeadBands.BAND_EXTENDS:
			_dock._open_sheet_type_dialog()
		EventSheetHeadBands.BAND_ICON:
			open_icon_dialog()
		EventSheetHeadBands.BAND_TOOL:
			toggle_tool_mode()
		EventSheetHeadBands.BAND_DESCRIPTION:
			# The band's own line, not the whole doc-comment block: a one-line field cannot hold a
			# block, and seeding it with one would write the block back as a single line.
			_prompt_for_text(EventSheetHeadBands.BAND_DESCRIPTION, "Description",
				EventSheetHeadBands.description_line(_dock._current_sheet.class_description))
		EventSheetHeadBands.BAND_AUTOLOAD:
			_dock._set_status(EventSheetL10n.translate(
				"Project Settings ▸ Autoload is where this name lives - it is not in this file."))
		EventSheetHeadBands.BAND_INCLUDE:
			_dock._set_status(EventSheetL10n.translate(
				"Sheet ▸ Sheet Type… ▸ More is where the included sheets are listed."))
		EventSheetHeadBands.BAND_MODES:
			_dock.open_modes_dialog()
		EventSheetHeadBands.BAND_STATES:
			_dock.open_states_dialog()
		EventSheetHeadBands.BAND_ATTACH:
			_dock._attach_behavior_to_selection()
		"add":
			open_add_menu()


## Shows a spawned scene where it lives, in Godot's own FileSystem dock. Browsing rather than
## opening on purpose: a spawns band lists several scenes and a click meant "which file is that" far
## more often than it meant "close what I am editing". A band with no file behind it - the one that
## counts the scenes it did not name, or a scene the sheet builds a path for at run time - says so
## rather than doing nothing quietly.
func browse_to_scene(scene_path: String) -> void:
	var path: String = scene_path.strip_edges()
	if path.is_empty():
		_dock._set_status(EventSheetL10n.translate(
			"This one is named by an expression the sheet works out as it runs, so there is no file to show."))
		return
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var editor_interface: Object = Engine.get_singleton("EditorInterface")
		if editor_interface.has_method("select_file"):
			editor_interface.call("select_file", path)
	_dock._set_status(EventSheetL10n.translate("%s - shown in the FileSystem dock.") % path.get_file())


## Opens the scene a replication fact lives in and selects the node that holds it, so Godot's
## own Replication panel and Inspector open on it. Says so on the status line either way: a node that
## is not there any more is a fact the sheet read from a file somebody has since changed.
func reveal_scene_node(scene_path: String, node_path: String) -> void:
	if EventSheetSceneReplication.reveal_node(scene_path, node_path):
		_dock._set_status(EventSheetL10n.translate("%s selected in %s - its panels are the Inspector and Replication.")
			% [node_path.get_file(), scene_path.get_file()])
		return
	_dock._set_status(EventSheetL10n.translate("%s is not in %s any more.")
		% [node_path.get_file(), scene_path.get_file()], true)


## What a class rename would touch, before anything is written: {"uses": N, "sheets": M}. The count
## is the whole point of the gesture - a rename nobody can see the blast radius of is a rename
## nobody presses.
static func rename_reach(class_name_text: String, extra_sheets: Dictionary = {}) -> Dictionary:
	var wanted: String = class_name_text.strip_edges()
	if wanted.is_empty():
		return {"uses": 0, "sheets": 0}
	var uses: int = 0
	var sheets: int = 0
	for entry: Variant in EventSheetFindReferences.find_in_project(wanted, extra_sheets):
		if not (entry is Dictionary):
			continue
		var count: int = int((entry as Dictionary).get("count", 0))
		if count <= 0:
			continue
		uses += count
		sheets += 1
	return {"uses": uses, "sheets": sheets}


## The sentence the rename dialog says before it writes anything.
static func rename_reach_text(reach: Dictionary) -> String:
	var uses: int = int(reach.get("uses", 0))
	var sheets: int = int(reach.get("sheets", 0))
	if uses <= 0:
		return EventSheetL10n.translate("renames nothing else - this name is used nowhere yet")
	var use_words: String = EventSheetL10n.translate("renames %d use") % uses if uses == 1 \
		else EventSheetL10n.translate("renames %d uses") % uses
	var sheet_words: String = EventSheetL10n.translate("in %d sheet") % sheets if sheets == 1 \
		else EventSheetL10n.translate("in %d sheets") % sheets
	return "%s %s" % [use_words, sheet_words]


## The head's name band, renamed everywhere: the class line of this file plus every row of every
## sheet that names the class.
func open_class_rename() -> void:
	var current: String = _dock._current_sheet.custom_class_name.strip_edges()
	if current.is_empty():
		current = str(EventSheetHeadBands.facts(_dock._current_sheet, _prelude_text()).get("class_name", ""))
	if _rename_dialog == null:
		_rename_dialog = ConfirmationDialog.new()
		_rename_dialog.title = "Rename class"
		var form: VBoxContainer = EventSheetPopupUI.form_box()
		_rename_edit = LineEdit.new()
		form.add_child(EventSheetPopupUI.form_row("Class name", _rename_edit))
		_rename_count = EventSheetPopupUI.hint_label("")
		form.add_child(_rename_count)
		_rename_dialog.add_child(EventSheetPopupUI.margined(form))
		_rename_dialog.confirmed.connect(_apply_class_rename)
		_dock.add_child(_rename_dialog)
	_rename_edit.text = current
	_rename_count.text = rename_reach_text(
		rename_reach(current, EventSheetFindReferences.open_sheets_of(_dock))
	)
	_rename_dialog.popup_centered(Vector2i(420, 0))
	_rename_edit.grab_focus()
	_rename_edit.select_all()


func _apply_class_rename() -> void:
	var new_name: String = _rename_edit.text.strip_edges()
	if new_name.is_empty():
		return
	if not EventSheetIdentifierRules.is_valid(new_name):
		_dock._set_status(EventSheetL10n.translate("\"%s\" cannot be a class name.") % new_name, true)
		return
	var old_name: String = _dock._current_sheet.custom_class_name.strip_edges()
	if old_name.is_empty():
		old_name = str(EventSheetHeadBands.facts(_dock._current_sheet, _prelude_text()).get("class_name", ""))
	if old_name == new_name:
		return
	var written: bool = _dock._perform_undoable_sheet_edit("Rename Class", func() -> bool:
		_write_head_line(EventSheetHeadBands.BAND_NAME, new_name)
		_dock._current_sheet.custom_class_name = new_name
		if not old_name.is_empty():
			EventSheetRefactor.rename_symbol(_dock._current_sheet, old_name, new_name, true)
		return true
	)
	if not written:
		return
	var touched: PackedStringArray = PackedStringArray()
	if not old_name.is_empty():
		touched = _dock._rename.rename_in_includers(
			old_name, new_name, EventSheetProjectFind.list_project_sheets()
		)
	_dock._refresh_after_edit()
	_dock._refresh_title_strip()
	_dock._mark_dirty(EventSheetL10n.translate("Renamed %s to %s.") % [old_name, new_name] \
		+ ("" if touched.is_empty() else " (%s)" % ", ".join(touched)))


## The `@icon` band's swatch: a file dialog filtered to images, writing the annotation.
func open_icon_dialog() -> void:
	if _icon_dialog == null:
		_icon_dialog = EditorFileDialog.new()
		_icon_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		_icon_dialog.access = EditorFileDialog.ACCESS_RESOURCES
		_icon_dialog.add_filter("*.svg, *.png, *.webp", "Images")
		_icon_dialog.file_selected.connect(func(path: String) -> void: apply_band_value(
			EventSheetHeadBands.BAND_ICON, path))
		_dock.add_child(_icon_dialog)
	_icon_dialog.popup_centered_ratio(0.5)


## The `@tool` band's switch: the annotation goes in or comes out, in one undo step.
func toggle_tool_mode() -> void:
	var switching_on: bool = not _dock._current_sheet.tool_mode
	apply_band_value(EventSheetHeadBands.BAND_TOOL, "true" if switching_on else "false")


## "+ add" under the stack: only the lines this sheet could have and does not.
func open_add_menu() -> void:
	_add_offers = EventSheetHeadBands.addable(
		EventSheetHeadBands.facts(_dock._current_sheet, _prelude_text())
	)
	if _add_offers.is_empty():
		return
	if _add_menu == null:
		_add_menu = PopupMenu.new()
		_add_menu.id_pressed.connect(_on_add_menu_pressed)
		_dock.add_child(_add_menu)
	_add_menu.clear()
	for index: int in range(_add_offers.size()):
		_add_menu.add_item(EventSheetHeadBands.add_label(_add_offers[index]), index)
	_add_menu.position = Vector2i(_dock.get_screen_position() + _dock.size * 0.5)
	_add_menu.reset_size()
	_add_menu.popup()


func _on_add_menu_pressed(index: int) -> void:
	if index < 0 or index >= _add_offers.size():
		return
	handle(_add_offers[index])


## A one-field prompt for a band whose value is free text (the description). Kept here rather than
## in the Sheet Type dialog so "+ add ▸ description" answers where it was asked.
func _prompt_for_text(band_kind: String, label_text: String, seed_text: String) -> void:
	_text_band = band_kind
	if _text_dialog == null:
		_text_dialog = ConfirmationDialog.new()
		var form: VBoxContainer = EventSheetPopupUI.form_box()
		_text_edit = LineEdit.new()
		form.add_child(EventSheetPopupUI.form_row("Text", _text_edit))
		_text_dialog.add_child(EventSheetPopupUI.margined(form))
		_text_dialog.confirmed.connect(func() -> void: apply_band_value(_text_band, _text_edit.text))
		_dock.add_child(_text_dialog)
	_text_dialog.title = label_text
	_text_edit.text = seed_text
	_text_dialog.popup_centered(Vector2i(460, 0))
	_text_edit.grab_focus()


## Writes one band's line and the sheet field that mirrors it, in one undo step. The sheet field
## exists because a `.tres` sheet has no prelude text of its own - the compiler writes those lines
## from the fields - so both are kept in step and neither can go stale.
func apply_band_value(band_kind: String, new_value: String) -> void:
	if _dock._current_sheet == null:
		return
	var written: bool = _dock._perform_undoable_sheet_edit("Edit Sheet Head", func() -> bool:
		return _write_head_line(band_kind, new_value)
	)
	if not written:
		return
	_dock._refresh_after_edit()
	_dock._refresh_title_strip()
	_dock._mark_dirty(head_status_text(band_kind, new_value))


## What the status line says after a band was written - one sentence per band, so the reader is told
## which line of the file just changed.
static func head_status_text(band_kind: String, new_value: String) -> String:
	match band_kind:
		EventSheetHeadBands.BAND_ICON:
			return EventSheetL10n.translate("Icon set to %s.") % new_value
		EventSheetHeadBands.BAND_TOOL:
			return EventSheetL10n.translate("This sheet runs in the editor too.") if new_value == "true" \
				else EventSheetL10n.translate("This sheet no longer runs in the editor.")
		EventSheetHeadBands.BAND_DESCRIPTION:
			return EventSheetL10n.translate("Description updated.")
		EventSheetHeadBands.BAND_EXTENDS:
			return EventSheetL10n.translate("This sheet now extends %s.") % new_value
		EventSheetHeadBands.BAND_NAME:
			return EventSheetL10n.translate("Renamed to %s.") % new_value
	return EventSheetL10n.translate("Sheet head updated.")


## Writes one band's line into the sheet - the prelude row it lives in for a `.gd` sheet, the
## matching field for both. Runs INSIDE the undo funnel, and re-reads the live sheet rather than
## holding a row from before the edit.
func _write_head_line(band_kind: String, new_value: String) -> bool:
	var sheet: EventSheetResource = _dock._current_sheet
	if sheet == null:
		return false
	match band_kind:
		EventSheetHeadBands.BAND_NAME:
			sheet.custom_class_name = new_value.strip_edges()
		EventSheetHeadBands.BAND_EXTENDS:
			sheet.host_class = new_value.strip_edges()
		EventSheetHeadBands.BAND_ICON:
			sheet.custom_class_icon = new_value.strip_edges()
		EventSheetHeadBands.BAND_TOOL:
			sheet.tool_mode = new_value == "true"
		EventSheetHeadBands.BAND_DESCRIPTION:
			sheet.class_description = EventSheetHeadBands.replace_description_line(
				sheet.class_description, new_value)
	var target: RawCodeRow = _prelude_row_for(sheet, band_kind)
	if target == null:
		return true
	var rewritten: String = rewrite_prelude(target.code, band_kind, new_value)
	if rewritten == target.code:
		return true
	target.code = rewritten
	return true


## The prelude row a band's line lives in: the one already carrying that line, else the identity row
## (the block with `class_name` / `extends`), else the first block of scaffolding. null when this
## sheet has no prelude text at all, which is a `.tres` sheet - its fields are the whole answer.
func _prelude_row_for(sheet: EventSheetResource, band_kind: String) -> RawCodeRow:
	var identity: RawCodeRow = null
	var first: RawCodeRow = null
	for entry: Variant in sheet.events:
		var raw: RawCodeRow = entry as RawCodeRow
		if raw == null or not EventSheetViewport.is_scaffolding_code(raw.code):
			break
		if first == null:
			first = raw
		if _block_carries(raw.code, band_kind):
			return raw
		if identity == null and (raw.code.contains("class_name ") or raw.code.contains("extends ")):
			identity = raw
	return identity if identity != null else first


## True when this block of prelude text already carries the line a band stands for.
static func _block_carries(code: String, band_kind: String) -> bool:
	for raw_line: String in code.split("\n"):
		if EventSheetHeadBands.line_is(raw_line.strip_edges(), band_kind):
			return true
	return false


## One block of prelude text with one band's line written into it: replaced where it is there,
## inserted where GDScript wants it when it is not, removed when the new value is empty (or "false"
## for the `@tool` switch). PURE - the whole head-writing contract, testable without a dock.
static func rewrite_prelude(code: String, band_kind: String, new_value: String) -> String:
	var wanted: String = EventSheetHeadBands.line_text(band_kind, new_value)
	var lines: PackedStringArray = code.split("\n")
	var kept: PackedStringArray = PackedStringArray()
	var replaced: bool = false
	for line: String in lines:
		# ONE line is written: the FIRST the band matches. Every later one is left exactly as it was,
		# because the band never stood for it - a `##` block of several lines is several lines of
		# prose, and dropping the ones the band does not show rewrote a hand-written file behind its
		# author's back, which is the one thing the lossless rule forbids.
		if replaced or not EventSheetHeadBands.line_is(line.strip_edges(), band_kind):
			kept.append(line)
			continue
		replaced = true
		if wanted.is_empty():
			continue  # the line goes away
		kept.append(wanted)
	if wanted.is_empty() or replaced:
		return "\n".join(kept)
	return "\n".join(_insert_head_line(kept, band_kind, wanted))


## Where a line GDScript has rules about goes when the file does not have it yet: `@tool` opens the
## file, `@icon` and the `##` description sit directly above `class_name`, and `class_name` sits
## directly above `extends`.
static func _insert_head_line(lines: PackedStringArray, band_kind: String, wanted: String) -> PackedStringArray:
	var at: int = lines.size()
	match band_kind:
		EventSheetHeadBands.BAND_TOOL:
			at = 0
			while at < lines.size() and lines[at].strip_edges().begins_with("#"):
				at += 1
		EventSheetHeadBands.BAND_NAME:
			at = _index_of_line(lines, EventSheetHeadBands.BAND_EXTENDS, lines.size())
		_:
			at = _index_of_line(lines, EventSheetHeadBands.BAND_NAME,
				_index_of_line(lines, EventSheetHeadBands.BAND_EXTENDS, lines.size()))
	var out: PackedStringArray = PackedStringArray()
	for index: int in range(lines.size()):
		if index == at:
			out.append(wanted)
		out.append(lines[index])
	if at >= lines.size():
		out.append(wanted)
	return out


## The index of the line a band stands for, or `fallback` when the block has no such line.
static func _index_of_line(lines: PackedStringArray, band_kind: String, fallback: int) -> int:
	for index: int in range(lines.size()):
		if EventSheetHeadBands.line_is(lines[index].strip_edges(), band_kind):
			return index
	return fallback


## The sheet's whole prelude as text - what the band model reads.
func _prelude_text() -> String:
	var blocks: PackedStringArray = PackedStringArray()
	if _dock._current_sheet == null:
		return ""
	for entry: Variant in _dock._current_sheet.events:
		var raw: RawCodeRow = entry as RawCodeRow
		if raw == null or not EventSheetViewport.is_scaffolding_code(raw.code):
			break
		blocks.append(raw.code)
	return "\n".join(blocks)
