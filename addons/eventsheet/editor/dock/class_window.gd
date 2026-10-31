@tool
extends RefCounted
# The Class window: what a click on the sheet head's name opens. One small window, four fields, and
# each field is exactly one line of the file - Name is `class_name`, "A kind of" / "Extends" is
# `extends`, Icon is `@icon` and Description is the `##` line above them. Every field completes as
# it is typed (your classes first, then Godot's; the project's pictures), a name another class has
# is said before anything is written, and Apply is ONE undo step however many lines it changes.
#
# Renaming goes through the same walk as Rename Everywhere (dock/sheet_head_actions.gd), so the
# window lists every file and row the new name will touch before it touches any. Changing what the
# class is built on lists the members the old base gave that the new one does not, among the ones
# this sheet's rows use.
#
# DELIBERATELY NO `class_name`: the head reaches it with load() when a click asks for it, so opening
# a sheet never reads it. The pure questions (what is wrong with a field, which lines a set of
# answers changes) are static, so a test asks them without a window.

const KINDS_PATH := "res://addons/eventsheet/editor/dock/class_kinds.gd"
const NEW_SHEET_DIALOG_PATH := "res://addons/eventsheet/editor/new_sheet_dialog.gd"
## The pictures a class icon may be. Godot's own `@icon` takes SVG, and the importer reads these.
const ICON_EXTENSIONS: PackedStringArray = ["svg", "png", "webp"]

var _dock: Control = null
var _heads: RefCounted = null
var _window: ConfirmationDialog = null
var _name_edit: LineEdit = null
var _base_edit: LineEdit = null
var _icon_edit: LineEdit = null
var _description_edit: LineEdit = null
var _current: Dictionary = {}
var _compiled: String = ""
var _compiled_ready: bool = false
var _places: Array = []


func init(dock: Control, heads: RefCounted) -> void:
	_dock = dock
	_heads = heads


## What is wrong with the typed class name, or "" when it is fine (or empty, which names nothing).
## `current` is the name the sheet has now, `own_paths` the files whose own `class_name` it is.
static func name_problem(typed: String, current: String, own_paths: PackedStringArray) -> String:
	var wanted: String = typed.strip_edges()
	if wanted.is_empty() or wanted == current:
		return ""
	if not EventSheetIdentifierRules.is_valid(wanted):
		return EventSheetL10n.translate("\"%s\" cannot be a class name.") % wanted
	if EventSheetHeadActions.class_name_taken(wanted, own_paths):
		return EventSheetL10n.translate("\"%s\" is already the name of another class.") % wanted
	return ""


## What is wrong with the typed "kind of" class, or "" when it is empty, a class of the project or a
## Godot class. Held back while the field still completes what is typed.
static func base_problem(typed: String) -> String:
	var wanted: String = typed.strip_edges()
	if wanted.is_empty() or load(NEW_SHEET_DIALOG_PATH).kind_has_completion(wanted):
		return ""
	return load(NEW_SHEET_DIALOG_PATH).kind_problem_text(wanted)


## What is wrong with the typed icon path, or "" when it is empty or names a picture of the project.
static func icon_problem(typed: String) -> String:
	var wanted: String = typed.strip_edges()
	if wanted.is_empty():
		return ""
	if wanted.begins_with("res://") and ICON_EXTENSIONS.has(wanted.get_extension().to_lower()) \
			and (ResourceLoader.exists(wanted) or FileAccess.file_exists(wanted)):
		return ""
	return EventSheetL10n.translate("No picture there.")


## The pictures of the project whose path begins with, or holds, what is typed - SVG, PNG and WebP,
## each as the entry the completion list draws. Bare paths: the field holds a path, not a string.
static func icon_entries(typed: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry: Dictionary in EventSheetCompletions.for_field(null, "%s:Texture2D" % EventSheetCompletions.FIELD_FILE, typed):
		var path: String = str(entry.get("text", "")).trim_prefix("\"").trim_suffix("\"")
		if not ICON_EXTENSIONS.has(path.get_extension().to_lower()):
			continue
		var copy: Dictionary = entry.duplicate()
		copy["text"] = path
		entries.append(copy)
	return entries


## The band lines a set of answers changes, as {band: value}: only the fields that differ from what
## the sheet has now, in the order the file writes them. An empty "kind of" is no answer (a class is
## always built on something), so it never removes the `extends` line.
static func changes(current: Dictionary, wanted: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var pairs: Array = [
		[EventSheetHeadBands.BAND_NAME, "name", true],
		[EventSheetHeadBands.BAND_EXTENDS, "extends", false],
		[EventSheetHeadBands.BAND_ICON, "icon", true],
		[EventSheetHeadBands.BAND_DESCRIPTION, "description", true],
	]
	for pair: Array in pairs:
		var key: String = str(pair[1])
		var now: String = str(current.get(key, "")).strip_edges()
		var next: String = str(wanted.get(key, now)).strip_edges()
		if next == now or (next.is_empty() and not bool(pair[2])):
			continue
		out[pair[0]] = next
	return out


## The members the old base gave that the new base lacks, among those `used_text` mentions. Both
## bases may be classes of the project or Godot classes.
static func lost_members(used_text: String, old_base: String, new_base: String) -> PackedStringArray:
	if old_base.strip_edges().is_empty() or new_base.strip_edges().is_empty() or old_base == new_base:
		return PackedStringArray()
	return load(KINDS_PATH).members_lost(used_text, old_base, new_base)


## Opens the window on the open sheet. Every field starts on what the file says now.
func open() -> void:
	if _dock == null or _dock._current_sheet == null:
		return
	var facts: Dictionary = _heads.head_facts()
	_current = {
		"name": _heads._current_class_name(),
		"extends": str(facts.get("extends", "")).strip_edges(),
		"icon": str(facts.get("icon", "")).strip_edges(),
		"description": EventSheetHeadBands.description_line(_dock._current_sheet.class_description),
	}
	_compiled = ""
	_compiled_ready = false
	_places = []
	var familiar: bool = EventSheetWords.familiar_words_enabled()
	_name_edit = _field("name")
	_name_edit.placeholder_text = "Enemy"
	_base_edit = _field("extends")
	_base_edit.placeholder_text = "CharacterBody2D"
	EventSheetCompletionPopup.attach(_base_edit, EventSheetCompletions.FIELD_CLASS, Callable())
	_icon_edit = _field("icon")
	_icon_edit.placeholder_text = "res://icon.svg"
	EventSheetCompletionPopup.attach_entries(_icon_edit, icon_entries)
	_description_edit = _field("description")
	var body: VBoxContainer = EventSheetPopupUI.form_box()
	body.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Name"), _name_edit))
	body.add_child(EventSheetPopupUI.form_row(
		EventSheetL10n.translate("A kind of") if familiar else EventSheetL10n.translate("Extends"), _base_edit))
	body.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Icon"), _icon_edit))
	body.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Description"), _description_edit))
	_window = load(_dock.SMALL_PROMPT_PATH).open(_dock, {
		"title": EventSheetL10n.translate("Class"),
		"glyph": "i",
		"say": EventSheetL10n.translate("Each field writes one line of this file: class_name, extends, @icon and the ## description."),
		"body": body,
		"note": EventSheetHeadActions.class_rename_note(),
		"main": EventSheetL10n.translate("Apply"),
		"on_main": apply,
	})
	for edit: LineEdit in [_name_edit, _base_edit, _icon_edit, _description_edit]:
		edit.text_changed.connect(func(_typed: String) -> void: _sync())
	_sync()
	if _name_edit.is_inside_tree():
		_name_edit.grab_focus()
		_name_edit.select_all()


func _field(key: String) -> LineEdit:
	var edit: LineEdit = LineEdit.new()
	edit.text = str(_current.get(key, ""))
	edit.custom_minimum_size.x = EventSheetPalette.scaled_f(300.0)
	return edit


func _wanted() -> Dictionary:
	return {
		"name": _name_edit.text.strip_edges(),
		"extends": _base_edit.text.strip_edges(),
		"icon": _icon_edit.text.strip_edges(),
		"description": _description_edit.text.strip_edges(),
	}


## The first thing wrong with the answers so far, "" when none.
func _problem() -> String:
	var wanted: Dictionary = _wanted()
	var own: PackedStringArray = _heads.class_name_own_paths()
	for text: String in [name_problem(str(wanted["name"]), str(_current["name"]), own),
			base_problem(str(wanted["extends"])), icon_problem(str(wanted["icon"]))]:
		if not text.is_empty():
			return text
	return ""


func _sync() -> void:
	if not is_instance_valid(_window):
		return
	var wanted: Dictionary = _wanted()
	var problem: String = _problem()
	var written: Dictionary = changes(_current, wanted)
	var say: Label = _window.find_child("Say", true, false) as Label
	var rows: Array = []
	var lost: PackedStringArray = PackedStringArray()
	if written.has(EventSheetHeadBands.BAND_EXTENDS) and problem.is_empty():
		lost = lost_members(_used_text(), str(_current["extends"]), str(wanted["extends"]))
	for member: String in lost:
		rows.append([member, EventSheetL10n.translate("%s does not have it") % str(wanted["extends"])])
	if written.has(EventSheetHeadBands.BAND_NAME) and problem.is_empty():
		rows.append_array(_rename_places(str(_current["name"]), str(wanted["name"])))
	if say != null:
		say.text = say_text(problem, lost, _current, wanted, written)
	load(_dock.SMALL_PROMPT_PATH).set_list(_window, rows)
	_window.get_ok_button().disabled = not problem.is_empty() or written.is_empty()


## The sentence the window says now: the problem when there is one, else what the answers will do.
static func say_text(problem: String, lost: PackedStringArray, current: Dictionary, wanted: Dictionary,
		written: Dictionary) -> String:
	if not problem.is_empty():
		return problem
	if not lost.is_empty():
		return EventSheetL10n.translate("Rows use %s, which %s does not have.") % [", ".join(lost), str(wanted["extends"])]
	if written.has(EventSheetHeadBands.BAND_NAME) and not str(current["name"]).is_empty():
		return EventSheetL10n.translate("%s will be the class name everywhere %s is used.") % [str(wanted["name"]), str(current["name"])]
	return EventSheetL10n.translate("Each field writes one line of this file: class_name, extends, @icon and the ## description.")


## The sheet's rows as the text they compile to - what the rebase warning reads identifiers from.
## Compiled once per window.
func _used_text() -> String:
	if not _compiled_ready:
		_compiled_ready = true
		_compiled = str(SheetCompiler.compile(_dock._current_sheet, "").get("output", ""))
	return _compiled


## The files a rename walks and how many places each holds, as the rows the window lists.
func _rename_places(old_name: String, new_name: String) -> Array:
	if old_name.is_empty() or new_name.is_empty():
		return []
	# The walk is read once per window: any other name touches the same places.
	if not _places.is_empty():
		return _places
	var places: Array = []
	for entry: Dictionary in EventSheetHeadActions.rename_class_across(old_name, old_name + "_",
			EventSheetFindReferences.open_sheets_of(_dock), _heads._generated_paths(),
			EventSheetProjectFind.list_all_project_sheets(), false):
		var count: int = int(entry.get("count", 0))
		places.append([str(entry.get("path", "")).get_file(),
			EventSheetL10n.translate("1 place") if count == 1 else EventSheetL10n.translate("%d places") % count])
	_places = places
	return places


## Writes every line that changed, in one undo step. A rename walks the project like Rename
## Everywhere; the other lines ride the same undo step.
func apply() -> void:
	if _dock == null or _dock._current_sheet == null:
		return
	var written: Dictionary = changes(_current, _wanted())
	if written.is_empty():
		return
	# A script opened as a preview unlocks on this first intentional edit, as every other edit does.
	if _dock._current_sheet.read_only:
		_dock._preview_glue._on_preview_edit_requested()
	var heads: RefCounted = _heads
	var others: Callable = func() -> void:
		for band: String in written:
			if band != EventSheetHeadBands.BAND_NAME:
				heads.write_head_line(band, str(written[band]))
	if written.has(EventSheetHeadBands.BAND_NAME):
		heads.apply_class_rename_to(str(written[EventSheetHeadBands.BAND_NAME]), "Edit Class", others)
		return
	var done: bool = _dock._perform_undoable_sheet_edit("Edit Class", func() -> bool:
		others.call()
		return true)
	if not done:
		return
	_dock._refresh_after_edit()
	_dock._refresh_title_strip()
	_dock._mark_dirty(EventSheetL10n.translate("Class updated."))
