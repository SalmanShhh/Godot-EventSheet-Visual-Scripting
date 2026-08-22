@tool
class_name EventSheetGlobalVariables
extends RefCounted
# GLOBAL VARIABLES - one value the whole project shares.
#
# On the sheet a global is a row you add at the top of any sheet. In Godot it lives on an autoload,
# and that is deliberately kept as the truth: one place, no second variable system, nothing magic
# for the compiler to invent. What this file adds is the GESTURE - Add ▸ Global variable… from any
# sheet at all - plus the two readings that make a global visible where it is used rather than only
# where it is declared:
#
#   Add ▸ Global variable…  name / type / value / write into: [Game ▾]
#   ▸ Global variables used here    Score · Lives  (from Game)
#
# The writer does not poke at another file behind the user's back: it OPENS the autoload sheet the
# way the Include bar's "open as a sheet" opens anything, then adds the variable there through the
# ordinary undo funnel. So the line that lands is the line the Add variable dialog would have
# written, the user sees where their global went, and Ctrl+Z on that tab takes it back.

## What an autoload's script has to end in for the sheet to be able to write a variable into it.
const SHEET_EXTENSIONS: PackedStringArray = ["gd", "tres"]

## script path -> {"stamp": modified time, "declared": the scan}. See declared_globals.
static var _declared_cache: Dictionary = {}


## Every autoload the project has registered that the sheet can open, in project order:
## [{"name": "Game", "path": "res://game.gd"}]. Walking ProjectSettings is cheap enough to do per
## gesture and nothing caches it - the Project Settings dialog can add one at any moment.
static func autoload_sheets() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for property_info: Dictionary in ProjectSettings.get_property_list():
		var setting: String = str(property_info.get("name", ""))
		if not setting.begins_with("autoload/"):
			continue
		var singleton: String = setting.trim_prefix("autoload/").strip_edges()
		var path: String = str(ProjectSettings.get_setting(setting, "")).trim_prefix("*").strip_edges()
		if singleton.is_empty() or not SHEET_EXTENSIONS.has(path.get_extension()):
			continue
		found.append({"name": singleton, "path": path})
	return found


## The globals THIS sheet reads or writes: [{"autoload": "Game", "name": "Score"}], deduplicated and
## in the order a reader meets them. Derived from what the rows actually say - `Game.Score` in a
## parameter, an expression or a script block - so the list cannot claim a global the file does not
## touch, and cannot miss one just because it was written by hand.
static func used_here(sheet: EventSheetResource) -> Array[Dictionary]:
	var used: Array[Dictionary] = []
	if sheet == null:
		return used
	var names: PackedStringArray = PackedStringArray()
	for entry: Dictionary in autoload_sheets():
		names.append(str(entry.get("name", "")))
	if names.is_empty():
		return used
	var seen: Dictionary = {}
	var pattern: RegEx = RegEx.new()
	# Members only: `Game.Score`, never `Game.add_score()` - a call is the autoload's verb, and the
	# folder is about VALUES. The trailing look-ahead is done by hand because RegEx has none here:
	# the match keeps the character after the name so an opening bracket can be rejected.
	pattern.compile("\\b(%s)\\.([A-Za-z_][A-Za-z0-9_]*)(.?)" % "|".join(names))
	for fragment: Dictionary in EventSheetFindReferences.text_fragments(sheet):
		for found: RegExMatch in pattern.search_all(str(fragment.get("text", ""))):
			if found.get_string(3) == "(":
				continue
			var key: String = "%s.%s" % [found.get_string(1), found.get_string(2)]
			if seen.has(key):
				continue
			seen[key] = true
			used.append({"autoload": found.get_string(1), "name": found.get_string(2)})
	return used


## The folded head folder's note: "Score · Lives  (from Game)", or "" when the file touches none.
## Two autoloads read as "Score · Lives  (from Game, Save)" - the source is part of the answer,
## because a reader who wants to change one has to know which file to open.
static func used_here_note(used: Array[Dictionary]) -> String:
	if used.is_empty():
		return ""
	var names: PackedStringArray = PackedStringArray()
	var sources: PackedStringArray = PackedStringArray()
	for entry: Dictionary in used:
		names.append(str(entry.get("name", "")))
		var source: String = str(entry.get("autoload", ""))
		if not source.is_empty() and not sources.has(source):
			sources.append(source)
	return EventSheetL10n.translate("%s  (from %s)") % [" · ".join(names), ", ".join(sources)]


## What an autoload DECLARES, read straight off its script text: [{"name", "type", "value"}]. A light
## scan, not a lift - it answers the Object bar's hover ("Score = 0") for a file nobody has opened,
## and being wrong about an exotic declaration costs a hover note, never a written line.
static func declared_globals(script_path: String) -> Array[Dictionary]:
	var declared: Array[Dictionary] = []
	if not FileAccess.file_exists(script_path):
		return declared
	# The row builder asks this once per autoload per REBUILD, so the read is keyed by the file's
	# modified time: an autoload that has not been touched costs a stat, not a parse, and one that
	# has is re-read on the very next rebuild. Never a plain cache - a stale global list would say
	# "not declared on Game" about a variable the user just added.
	var stamp: int = FileAccess.get_modified_time(script_path)
	var cached: Variant = _declared_cache.get(script_path)
	if cached is Dictionary and int((cached as Dictionary).get("stamp", -1)) == stamp:
		return (cached as Dictionary).get("declared", declared)
	var text: String = FileAccess.get_file_as_string(script_path)
	var pattern: RegEx = RegEx.new()
	pattern.compile("^(?:@export[^\\n]*\\n)?(?:static )?(?:var|const) +([A-Za-z_][A-Za-z0-9_]*) *(?::=|: *([A-Za-z0-9_\\[\\], ]+?) *=|=) *(.+)$")
	for line: String in text.split("\n"):
		# Members only: a `var` inside a function is indented, and is nobody else's global.
		if line.begins_with("\t") or line.begins_with(" "):
			continue
		var found: RegExMatch = pattern.search(line)
		if found == null:
			continue
		declared.append({
			"name": found.get_string(1),
			"type": found.get_string(2).strip_edges(),
			"value": found.get_string(3).strip_edges()
		})
	_declared_cache[script_path] = {"stamp": stamp, "declared": declared}
	return declared


## One global's value for a hover: "Score = 0", or just the name when the file does not say.
static func hover_text(autoload_name: String, variable_name: String, declared: Array[Dictionary]) -> String:
	for entry: Dictionary in declared:
		if str(entry.get("name", "")) == variable_name:
			return "%s.%s = %s" % [autoload_name, variable_name, str(entry.get("value", ""))]
	return "%s.%s" % [autoload_name, variable_name]


# ── The gesture (editor only) ──────────────────────────────────────────────────────────────────

var _dock: Control = null
var _dialog: ConfirmationDialog = null
var _name_edit: LineEdit = null
var _type_picker: OptionButton = null
var _value_edit: LineEdit = null
var _target_picker: OptionButton = null
var _preview: Label = null


func init(dock: Control) -> void:
	_dock = dock


## Add ▸ Global variable… (V). Offered on ANY sheet: a global belongs to the project, so the sheet
## you happen to be looking at is never the reason you cannot declare one.
func open() -> void:
	if _dock == null or not _dock.is_inside_tree():
		return
	_build_dialog()
	_refresh_targets()
	_name_edit.text = ""
	_value_edit.text = "0"
	_type_picker.selected = 0
	_refresh_preview()
	_dialog.popup_centered(Vector2i(int(EventSheetPalette.scaled_f(460.0)), int(EventSheetPalette.scaled_f(280.0))))
	_name_edit.grab_focus()


func _build_dialog() -> void:
	if _dialog != null:
		return
	_dialog = ConfirmationDialog.new()
	_dialog.title = EventSheetL10n.translate("Add global variable")
	_dialog.ok_button_text = EventSheetL10n.translate("Add")
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Score"
	_name_edit.text_changed.connect(func(_text: String) -> void: _refresh_preview())
	form.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Name"), _name_edit))
	_type_picker = OptionButton.new()
	for word: String in EventSheetVariableSentence.TYPE_WORD_ORDER:
		_type_picker.add_item(EventSheetL10n.translate(word))
		_type_picker.set_item_metadata(_type_picker.item_count - 1,
			str(EventSheetVariableSentence.TYPE_WORD_TO_GDSCRIPT.get(word, "Variant")))
	_type_picker.item_selected.connect(func(_index: int) -> void: _refresh_preview())
	form.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Type"), _type_picker))
	_value_edit = LineEdit.new()
	_value_edit.text_changed.connect(func(_text: String) -> void: _refresh_preview())
	form.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Value"), _value_edit))
	_target_picker = OptionButton.new()
	_target_picker.item_selected.connect(func(_index: int) -> void: _refresh_preview())
	form.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Write into"), _target_picker))
	_preview = Label.new()
	_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(EventSheetPopupUI.panel_section(_preview))
	form.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate(
		"A global lives on an autoload - one file the whole project can read.")))
	_dialog.add_child(EventSheetPopupUI.margined(form))
	_dialog.confirmed.connect(_on_confirmed)
	_dock.add_child(_dialog)
	EventSheetL10n.apply_to(_dialog)


func _refresh_targets() -> void:
	_target_picker.clear()
	for entry: Dictionary in autoload_sheets():
		_target_picker.add_item("%s  (%s)" % [str(entry.get("name", "")), str(entry.get("path", "")).get_file()])
		_target_picker.set_item_metadata(_target_picker.item_count - 1, entry)
	_target_picker.add_item(EventSheetL10n.translate("New global sheet…"))
	_target_picker.set_item_metadata(_target_picker.item_count - 1, {})
	_target_picker.selected = 0


## The row the sheet will show, live, in the R37 shape - the same preview the Add variable dialog
## gives, because the dialog's whole job is to write one row.
func _refresh_preview() -> void:
	var word: String = str(EventSheetVariableSentence.TYPE_WORD_ORDER[maxi(_type_picker.selected, 0)])
	_preview.text = "%s %s = %s" % [
		EventSheetVariableSentence.chip_text(EventSheetVariableSentence.SCOPE_GLOBAL, word),
		_name_edit.text.strip_edges() if not _name_edit.text.strip_edges().is_empty() else "Score",
		_value_edit.text.strip_edges()
	]


func _on_confirmed() -> void:
	var picked: Dictionary = _target_picker.get_item_metadata(_target_picker.selected)
	add_global(_name_edit.text, str(_type_picker.get_item_metadata(_type_picker.selected)), _value_edit.text, picked)


## Writes one global into `target` ({} = "make me a global sheet"), the only path that puts a global
## anywhere. THIS dialog calls it with what its fields hold; the Add variable dialog (V5) calls it
## with what ITS fields hold when its Scope dropdown says Global - so a global written from either
## place lands as the same line, in the same file, under the same one undo step.
func add_global(raw_name: String, type_name: String, value_text: String, target: Dictionary) -> void:
	var variable_name: String = EventSheetIdentifierRules.sanitize(raw_name)
	if variable_name.is_empty() or not EventSheetIdentifierRules.is_valid(variable_name):
		_dock._set_status("\"%s\" can't be a variable name (letters/digits/underscores, not a GDScript keyword)." % raw_name, true)
		return
	if target.is_empty():
		# "New global sheet…". The project has no autoload to write into yet (or the reader wants a
		# second one), so make it here rather than sending them away to make it and come back.
		target = _create_global_sheet(variable_name)
		if target.is_empty():
			return
	var value: Variant = VariableDialog._parse_default(type_name, value_text)
	var path: String = str(target.get("path", ""))
	# Open (or focus) the autoload as a sheet FIRST, then write into it through the ordinary funnel:
	# the user sees where their global went, and the undo step lands on the tab that owns the file.
	_dock._navigate.record_current()
	_dock._navigate.open_or_focus(path)
	var sheet: EventSheetResource = _dock._current_sheet
	if sheet == null or str(sheet.get("external_source_path")) != path:
		_dock._set_status("Open %s and add %s there - it could not be opened from here." % [path.get_file(), variable_name], true)
		return
	if _dock._perform_undoable_sheet_edit("Add global variable %s" % variable_name, func() -> bool:
			return write_global(_dock._current_sheet, variable_name, type_name, value)):
		_dock._refresh_after_edit()
		_dock._mark_dirty("Added global variable %s to %s." % [variable_name, str(target.get("name", ""))])
	else:
		_dock._set_status("%s already declares %s." % [str(target.get("name", "")), variable_name], true)


## Creates a fresh autoload sheet and registers it in the project's [autoload] list, returning the
## {name, path} entry the rest of the confirm path expects (or {} when it could not be made).
##
## Nothing new is invented here: it builds the sheet the Autoload starter builds, saves it where a
## Godot project keeps its globals, and registers it through the SAME _register_autoload_entry() the
## Tools ▸ Register Autoload menu item uses - so a sheet made this way is indistinguishable from one
## made by hand, and the autoload stays the single truth about where a global lives.
##
## The name is chosen rather than asked for, because the dialog's question is "what global do you
## want", not "what shall the file be called" - and a second one lands as Globals2, Globals3, so the
## gesture never fails on a name that is taken. Rename it later like any other sheet.
func _create_global_sheet(for_variable: String) -> Dictionary:
	var autoload_name: String = _fresh_global_name()
	var path: String = "res://%s.gd" % autoload_name.to_snake_case()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.autoload_mode = true
	sheet.autoload_name = autoload_name
	sheet.host_class = "Node"
	sheet.custom_class_name = autoload_name
	sheet.class_description = "Project-wide values every sheet can read and write by name."
	sheet.external_source_path = path
	var problem: String = _dock._register_autoload_entry(sheet, path)
	if not problem.is_empty():
		_dock._set_status(problem, true)
		return {}
	# The reading caches which names are autoloads; a global added a moment ago has to read as one.
	EventSheetSentence.clear_autoload_cache()
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
	_dock._set_status("Made %s and registered it as an autoload - %s will live there." % [path.get_file(), for_variable])
	return {"name": autoload_name, "path": path}


## The first `Globals`, `Globals2`, `Globals3`… that is neither a registered autoload nor a file on
## disk, so the gesture never fails on a name somebody already used.
func _fresh_global_name() -> String:
	var taken: Dictionary = {}
	for entry: Dictionary in autoload_sheets():
		taken[str(entry.get("name", ""))] = true
	var attempt: int = 1
	while attempt < 100:
		var candidate: String = "Globals" if attempt == 1 else "Globals%d" % attempt
		if not taken.has(candidate) and not ProjectSettings.has_setting("autoload/%s" % candidate) \
				and not FileAccess.file_exists("res://%s.gd" % candidate.to_snake_case()):
			return candidate
		attempt += 1
	return "Globals"


## Appends the global to the autoload sheet as an ordinary member variable - the same LocalVariable
## the Add variable dialog places, so the emitted `var` line is identical either way. Refuses a name
## the file already declares rather than shadowing it.
static func write_global(sheet: EventSheetResource, variable_name: String, type_name: String,
		value: Variant) -> bool:
	if sheet == null or variable_name.is_empty():
		return false
	for entry: Variant in sheet.events:
		var existing: LocalVariable = entry as LocalVariable
		if existing != null and existing.name == variable_name:
			return false
	if sheet.variables.has(variable_name):
		return false
	var variable: LocalVariable = LocalVariable.new()
	variable.name = variable_name
	variable.type_name = type_name
	variable.default_value = value
	# A global is read and written by other files, never by the Inspector - an @export on it would
	# claim it is a per-instance designer knob, which is the one thing a global is not.
	variable.exported = false
	# Straight after the declarations already at the top of the file, so the head stays one block.
	var insert_at: int = 0
	for index: int in range(sheet.events.size()):
		if sheet.events[index] is LocalVariable:
			insert_at = index + 1
	sheet.events.insert(insert_at, variable)
	return true
