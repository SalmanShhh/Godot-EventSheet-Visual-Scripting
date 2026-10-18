# EventSheet - what a variable row offers besides its window: the help strip's doors under a selected
# member, the Inspector look and Group submenus of its right-click menu, Group by prefix, End group
# here and the end line dragged onto another member, and Add > Inspector button. A member declared in
# ANOTHER file (an autoload's global used here) is only ever pointed at: its group changes in that file.
#
# Nothing here is a new data model. Every write lands on the attribute keys the compiler already reads
# and the importer already lifts back - a group is `group` (and `group_prefix`) on the member it opens
# above, an end is `group_end` on the member the line stands over, a look is the keys
# EventSheetInspectorLooks folds - and goes through the dock's undo funnel, whose commit replaces the
# sheet's resources, so every write finds its variable on the live sheet by name.
#
# DELIBERATELY NO `class_name`: the dock loads it by path the first time one of these is asked for.
@tool
extends RefCounted

const SMALL_PROMPT_PATH := "res://addons/eventsheet/editor/small_prompt.gd"
const ExportSections := preload("res://addons/eventsheet/editor/interaction/export_sections.gd")

## The doors the help strip can show under a selected variable, in the order they are offered.
const LINK_MOVE := "move"
const LINK_RANGE := "range"
const LINK_PROPERTIES := "properties"
const LINK_SHAPE := "shape"
## How many doors the strip has room for; a door past them waits in its "…" menu.
const STRIP_DOORS := 3

## The Group submenu's own items; a group of the sheet is GROUP_MENU_FIRST plus its place in the list.
const GROUP_MENU_NEW := 1
const GROUP_MENU_BY_PREFIX := 2
const GROUP_MENU_END_HERE := 3
const GROUP_MENU_OPEN_FILE := 4
const GROUP_MENU_FIRST := 100

## The fewest characters of the help strip's sentence a narrow dock still shows: the counts give way
## first, then the doors fold into one "…" menu. The whole sentence stays on the strip's hover.
const STRIP_SENTENCE_CHARS := 60

var _dock: Control = null
## What the two submenus offered when they last opened, by item id.
var _menu_looks: PackedStringArray = PackedStringArray()
var _menu_groups: PackedStringArray = PackedStringArray()
## The file the Group submenu's "Open" item opens, for a member declared in another file.
var _menu_file: String = ""
## The doors folded into one menu at a narrow dock, made the first time a variable's strip is fitted;
## and the strip width the last fit was for, so a resize that changes nothing fits nothing.
var _more_door: MenuButton = null
var _fitted_width: float = -1.0


func init(dock: Control) -> void:
	_dock = dock

# ── Reading a variable, in either store ───────────────────────────────────────────────────────────


## A member of the sheet by name: the LocalVariable a row among the events declares, else the
## sheet-level descriptor (a Dictionary). Null for a name the sheet does not declare.
static func member(sheet: EventSheetResource, var_name: String) -> Variant:
	if sheet == null or var_name.is_empty():
		return null
	for entry: Variant in sheet.events:
		if entry is LocalVariable and (entry as LocalVariable).name == var_name:
			return entry
	return sheet.variables.get(var_name) if sheet.variables.get(var_name) is Dictionary else null


static func attributes_of(found: Variant) -> Dictionary:
	if found is LocalVariable:
		return (found as LocalVariable).attributes if (found as LocalVariable).attributes is Dictionary else {}
	if found is Dictionary and (found as Dictionary).get("attributes") is Dictionary:
		return (found as Dictionary)["attributes"]
	return {}


static func _set_attributes(found: Variant, attributes: Dictionary) -> void:
	if found is LocalVariable:
		(found as LocalVariable).attributes = attributes
	elif found is Dictionary:
		(found as Dictionary)["attributes"] = attributes


static func is_exported(found: Variant) -> bool:
	if found is LocalVariable:
		return (found as LocalVariable).exported
	return found is Dictionary and bool((found as Dictionary).get("exported", (found as Dictionary).get("exposed", true)))


static func _type_of(found: Variant) -> String:
	if found is LocalVariable:
		return (found as LocalVariable).type_name
	return str((found as Dictionary).get("type", "Variant")) if found is Dictionary else "Variant"


## The value the row shows, as code: `10`, `"hi"`, `$Muzzle`. "" when it declares none.
static func _value_words(found: Variant) -> String:
	var value: Variant = null
	var as_code: bool = false
	if found is LocalVariable:
		if (found as LocalVariable).no_default:
			return ""
		value = (found as LocalVariable).default_value
		as_code = (found as LocalVariable).expression_default
	elif found is Dictionary:
		value = (found as Dictionary).get("default")
		as_code = bool((found as Dictionary).get("expression", false))
	if value == null:
		return ""
	return "\"%s\"" % str(value).c_escape() if value is String and not as_code else str(value)


## The group a selected member sits in, as the Inspector reads the file: the walk's answer stamped
## on a member of an opened script, else the group its own attributes name.
static func group_of_row(row_data: EventRowData, found: Variant) -> String:
	for span: SemanticSpan in row_data.spans:
		if span.metadata is Dictionary and (span.metadata as Dictionary).has("variable_group"):
			return str((span.metadata as Dictionary)["variable_group"])
	return str(attributes_of(found).get("group", "")).strip_edges()


## The identity of a member row, {scope, name}, or {} for a row that is not a member of the sheet.
static func identity_of(row_data: EventRowData) -> Dictionary:
	var identity: Dictionary = EventSheetVariableGrouping.row_identity(row_data)
	if identity.is_empty() or str(identity.get("name", "")).is_empty() or str(identity.get("scope", "")) == "local":
		return {}
	return identity

# ── The help strip ────────────────────────────────────────────────────────────────────────────────


## What the help strip says under a selected member and the doors beside it: {text, detail, links}.
## The strip shares the status bar with the doors and the counts, so `text` is only the one thing the
## selected row cannot say itself - why it is outside the group above it, else its slider, else where
## the Inspector shows it. `detail`, the hover, is the whole of it with the type, name and value
## first. The row itself never says any of it. {} for any other row.
static func strip_for(row_data: EventRowData, sheet: EventSheetResource) -> Dictionary:
	if row_data == null:
		return {}
	var identity: Dictionary = identity_of(row_data)
	var found: Variant = member(sheet, str(identity.get("name", ""))) if not identity.is_empty() else null
	if found == null:
		return {}
	var exported: bool = is_exported(found)
	var words: String = "%s %s" % [_type_of(found), str(identity["name"])]
	if not _value_words(found).is_empty():
		words += " = %s" % _value_words(found)
	var facts: PackedStringArray = PackedStringArray()
	var links: PackedStringArray = PackedStringArray()
	var group: String = group_of_row(row_data, found)
	if exported:
		facts.append(EventSheetL10n.translate("in the Inspector"))
		facts.append(EventSheetL10n.translate("in group %s") % group if not group.is_empty() else EventSheetL10n.translate("not in a group"))
		# The Designer's Look tab offers the looks the Variable window does, and the other five kinds.
		links.append(LINK_SHAPE)
		if group.is_empty():
			links.append(LINK_MOVE)
	else:
		facts.append(EventSheetL10n.translate("not in the Inspector"))
	var text: String = " · ".join(facts)
	var detail: String = "%s · %s" % [words, text]
	var bounds: Variant = attributes_of(found).get("range")
	if exported and bounds is Dictionary:
		text = EventSheetL10n.translate("A slider from %s to %s in the Inspector.") % [
			str((bounds as Dictionary).get("min", "")), str((bounds as Dictionary).get("max", ""))]
		detail += "  " + text
		links.append(LINK_RANGE)
	if not row_data.help_note.is_empty():
		text = row_data.help_note
		detail += "  " + row_data.help_note
	links.append(LINK_PROPERTIES)
	return {"text": text, "detail": detail, "links": links}


static func link_label(link: String) -> String:
	match link:
		LINK_MOVE:
			return EventSheetL10n.translate("Move into a group…")
		LINK_RANGE:
			return EventSheetL10n.translate("Edit range…")
		LINK_SHAPE:
			return EventSheetL10n.translate("Shape in the Inspector…")
	return EventSheetL10n.translate("Properties…")


## One of the strip's doors, pressed: the move asks which group, the shape opens the Inspector Designer
## with this field picked; the rest open the variable window on the part they name.
func run_link(link: String, row_data: EventRowData) -> void:
	if link == LINK_MOVE:
		prompt_move_into_group(row_data)
		return
	if link == LINK_SHAPE:
		_dock._open_inspector_designer(str(identity_of(row_data).get("name", "")))
		return
	open_window(row_data, {LINK_RANGE: "details"}.get(link, ""))


## The variable window for a member row, turned to `part` ("look", "details", "group") when named and
## on `look_id` when one is given.
func open_window(row_data: EventRowData, part: String = "", look_id: String = "") -> void:
	var metadata: Dictionary = {}
	for span: SemanticSpan in row_data.spans:
		if span.metadata is Dictionary and not str((span.metadata as Dictionary).get("variable_name", "")).is_empty():
			metadata = span.metadata
			break
	_dock._variables._on_viewport_variable_edit_requested(row_data, metadata)
	if not part.is_empty():
		_dock._variable_dlg.focus_part(part, look_id)


## Fits the strip to the status bar's width (`width`, or the bar's own when 0): everything shows while
## the sentence has room for STRIP_SENTENCE_CHARS characters; short of that the counts give way, then
## the doors fold into one "…" menu. Puts the counts and the doors back whenever no variable's strip
## is showing.
func fit_strip(width: float = 0.0) -> void:
	var label: Label = _dock._row_help_label
	var strip: HBoxContainer = label.get_parent() as HBoxContainer if label != null else null
	if strip == null:
		return
	if _more_door == null:
		_more_door = MenuButton.new()
		_more_door.name = "EventSheetRowHelpMore"
		_more_door.text = "…"
		_more_door.flat = true
		_more_door.get_popup().id_pressed.connect(func(id: int) -> void: _dock._run_variable_link(id))
		strip.add_child(_more_door)
		strip.move_child(_more_door, _dock._row_help_button_third.get_index() + 1)
		strip.resized.connect(_on_strip_resized)
	_more_door.visible = false
	_more_door.get_popup().clear()
	var counts: Array = [_dock._problem_count_label, _dock._event_count_label]
	for count: Label in counts:
		count.visible = _dock._current_sheet != null
	_fitted_width = -1.0
	if not label.visible or str(_dock._row_help_finding.get("family", "")) != _dock.VARIABLE_LINKS_FAMILY:
		return
	var links: PackedStringArray = _dock._row_help_finding.get("links", PackedStringArray())
	for index: int in range(STRIP_DOORS, links.size()):
		_more_door.get_popup().add_item(link_label(links[index]), index)
		_more_door.visible = true
	_fitted_width = width if width > 0.0 else strip.size.x
	var need: float = label.get_theme_font("font").get_string_size(label.text.left(STRIP_SENTENCE_CHARS),
		HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
	if _sentence_room(strip, _fitted_width) >= need:
		return
	for count: Label in counts:
		count.visible = false
	if _sentence_room(strip, _fitted_width) >= need:
		return
	var popup: PopupMenu = _more_door.get_popup()
	popup.clear()
	for index: int in links.size():
		popup.add_item(link_label(links[index]), index)
	for door: Button in [_dock._row_help_button, _dock._row_help_button_second, _dock._row_help_button_third]:
		door.visible = false
	_more_door.visible = true


## The width the strip's sentence gets at `width`, the way the bar shares it out: what is left after
## every shown piece's own width and the gaps, split between the labels that stretch.
static func _sentence_room(strip: HBoxContainer, width: float) -> float:
	var taken: float = 0.0
	var ratios: float = 0.0
	var shown: int = 0
	var share: float = 0.0
	for child: Node in strip.get_children():
		var control: Control = child as Control
		if control == null or not control.visible:
			continue
		shown += 1
		taken += control.get_combined_minimum_size().x
		if control.size_flags_horizontal & Control.SIZE_EXPAND:
			ratios += control.size_flags_stretch_ratio
			if control.name == "EventSheetRowHelp":
				share = control.size_flags_stretch_ratio
	taken += strip.get_theme_constant("separation") * maxi(shown - 1, 0)
	return maxf(width - taken, 0.0) * share / maxf(ratios, 1.0)


func _on_strip_resized() -> void:
	var strip: Control = _more_door.get_parent() as Control
	if _fitted_width < 0.0 or strip == null or is_equal_approx(strip.size.x, _fitted_width):
		return
	_dock._update_row_help_strip.call_deferred(_dock._row_help_finding.get("row") as EventRowData)

# ── Groups ────────────────────────────────────────────────────────────────────────────────────────


## The groups the sheet's members name, in the order they first appear.
static func sheet_groups(sheet: EventSheetResource) -> PackedStringArray:
	var groups: PackedStringArray = PackedStringArray()
	if sheet == null:
		return groups
	var holders: Array = sheet.events.filter(func(entry: Variant) -> bool: return entry is LocalVariable)
	holders.append_array(sheet.variables.values())
	for holder: Variant in holders:
		var group: String = str(attributes_of(holder).get("group", "")).strip_edges()
		if not group.is_empty() and not groups.has(group):
			groups.append(group)
	return groups


## Puts one member in `group`: the group's line is written right above it. A prefix and an end it
## carried go, since the line it now opens says what it is.
static func move_into_group(sheet: EventSheetResource, var_name: String, group: String) -> bool:
	var found: Variant = member(sheet, var_name)
	var clean: String = group.strip_edges()
	if found == null or clean.is_empty() or not is_exported(found):
		return false
	var attributes: Dictionary = attributes_of(found).duplicate(true)
	if str(attributes.get("group", "")) == clean and not attributes.has("group_prefix"):
		return false
	attributes["group"] = clean
	for key: String in ["group_prefix", "group_end", "subgroup", "subgroup_prefix"]:
		attributes.erase(key)
	_set_attributes(found, attributes)
	return true


## Group by prefix: the FIRST of the members in the sheet's order opens `title`, taking only names that
## start with `prefix`; the rest stop opening groups of their own so they fall into it. A sheet-level
## variable carries the group itself, as that store writes a group line only where it changes.
static func group_by_prefix(sheet: EventSheetResource, names: PackedStringArray, title: String, prefix: String) -> bool:
	if sheet == null or title.strip_edges().is_empty() or prefix.strip_edges().is_empty():
		return false
	var ordered: Array = sheet.events.filter(func(entry: Variant) -> bool:
		return entry is LocalVariable and names.has((entry as LocalVariable).name) and (entry as LocalVariable).exported)
	for var_name: String in names:
		if sheet.variables.get(var_name) is Dictionary and is_exported(sheet.variables[var_name]):
			ordered.append(sheet.variables[var_name])
	for index: int in ordered.size():
		var attributes: Dictionary = attributes_of(ordered[index]).duplicate(true)
		for key: String in ["group", "group_prefix", "group_end", "subgroup", "subgroup_prefix"]:
			attributes.erase(key)
		if index == 0 or ordered[index] is Dictionary:
			attributes["group"] = title.strip_edges()
			attributes["group_prefix"] = prefix.strip_edges()
		_set_attributes(ordered[index], attributes)
	return not ordered.is_empty()


## The file a member row stands for when its declaration is written in ANOTHER file, "" for a member
## this sheet declares. Its group can only change in that file, so nothing here writes one for it.
static func declared_in(row_data: EventRowData) -> String:
	if row_data == null or row_data.spans.is_empty() or not (row_data.spans[0].metadata is Dictionary):
		return ""
	return str((row_data.spans[0].metadata as Dictionary).get("include_path", "")).strip_edges()


static func elsewhere_note(path: String) -> String:
	return EventSheetL10n.translate("This variable lives in %s; open that file to end its group.") % path.get_file()


## True when "End group here" means something on this member: it is declared in this sheet and in the
## Inspector, sits inside a group, and neither opens a group nor already ends one.
static func can_end_group_here(row_data: EventRowData, sheet: EventSheetResource) -> bool:
	if not declared_in(row_data).is_empty():
		return false
	var identity: Dictionary = identity_of(row_data)
	var found: Variant = member(sheet, str(identity.get("name", "")))
	if not (found is LocalVariable) or not is_exported(found):
		return false
	var attributes: Dictionary = attributes_of(found)
	return not group_of_row(row_data, found).is_empty() and str(attributes.get("group", "")).is_empty() \
		and not bool(attributes.get("group_end", false))


## Writes `@export_group("")` above the member, so the group ends there instead of running on.
static func end_group_here(sheet: EventSheetResource, var_name: String) -> bool:
	var found: Variant = member(sheet, var_name)
	if not (found is LocalVariable) or not str(attributes_of(found).get("group", "")).is_empty():
		return false
	var attributes: Dictionary = attributes_of(found).duplicate(true)
	attributes["group_end"] = true
	_set_attributes(found, attributes)
	return true


## Moves the end line from the member it stood over (`from_name`) to `to_name`.
static func move_group_end(sheet: EventSheetResource, from_name: String, to_name: String) -> bool:
	var from: Variant = member(sheet, from_name)
	var to: Variant = member(sheet, to_name)
	if not (from is LocalVariable) or not (to is LocalVariable) or from == to \
			or not str(attributes_of(to).get("group", "")).is_empty():
		return false
	var cleared: Dictionary = attributes_of(from).duplicate(true)
	cleared.erase("group_end")
	_set_attributes(from, cleared)
	var moved: Dictionary = attributes_of(to).duplicate(true)
	moved["group_end"] = true
	_set_attributes(to, moved)
	return true


## An end line let go over a member: the end moves above it (or above the member after it, for a
## drop on its lower edge). True when the drag was an end line's, whatever became of it.
func drop_group_end(source_row: EventRowData, target_row: EventRowData, drop_mode: String) -> bool:
	if source_row == null or source_row.spans.is_empty() or not (source_row.spans[0].metadata is Dictionary):
		return false
	var owner: String = str((source_row.spans[0].metadata as Dictionary).get("group_end_owner", ""))
	if owner.is_empty():
		return false
	var sheet: EventSheetResource = _dock._current_sheet
	var target: LocalVariable = target_row.source_resource as LocalVariable if target_row != null else null
	if target != null and drop_mode == "after":
		var members: Array = sheet.events.filter(func(entry: Variant) -> bool: return entry is LocalVariable)
		var at: int = members.find(target)
		target = members[at + 1] if at >= 0 and at + 1 < members.size() else null
	if not declared_in(target_row).is_empty():
		_dock._set_status(elsewhere_note(declared_in(target_row)), true)
		return true
	if target == null:
		_dock._set_status(EventSheetL10n.translate("Drop the end line on the variable the group should end above."), true)
		return true
	var to_name: String = target.name
	if not _write(EventSheetL10n.translate("Move the group's end"), EventSheetL10n.translate("The group now ends above %s.") % to_name,
			func() -> bool: return move_group_end(_dock._current_sheet, owner, to_name)):
		_dock._set_status(EventSheetL10n.translate("%s opens a group of its own, so the end line cannot stand above it.") % to_name, true)
	return true


## Runs one of the strip's or the menu's group writes through the undo funnel and says what it did.
func _write(undo_note: String, done: String, operation: Callable) -> bool:
	var changed: bool = _dock._perform_undoable_sheet_edit(undo_note, operation)
	if changed:
		_dock._refresh_after_edit()
		_dock._mark_dirty(done)
	return changed


## "Move into a group…": which group, from the sheet's own or a new name typed.
func prompt_move_into_group(row_data: EventRowData) -> void:
	var var_name: String = str(identity_of(row_data).get("name", ""))
	if var_name.is_empty():
		return
	var groups: PackedStringArray = sheet_groups(_dock._current_sheet)
	var edit: LineEdit = LineEdit.new()
	edit.text = groups[0] if not groups.is_empty() else ""
	edit.placeholder_text = EventSheetL10n.translate("a group of this sheet, or a new name")
	EventSheetCompletionPopup.attach_entries(edit, func(typed: String) -> Array:
		return Array(groups).filter(func(known: String) -> bool: return known.to_lower().contains(typed.to_lower())))
	var small_prompt: GDScript = load(SMALL_PROMPT_PATH)
	var prompt: ConfirmationDialog = small_prompt.open(_dock, {
		"title": EventSheetL10n.translate("Move %s into a group?") % var_name,
		"say": EventSheetL10n.translate("The Inspector shows it in that group's folder. The group's line is written right above it."),
		"body": EventSheetPopupUI.form_row(EventSheetL10n.translate("Group"), edit),
		"code": ExportSections.code_line(ExportSections.GROUP, edit.text),
		"note": EventSheetL10n.translate("Ctrl+Z puts it back."),
		"main": EventSheetL10n.translate("Move"),
		"on_main": func() -> void: move_into(var_name, edit.text),
	})
	edit.text_changed.connect(func(typed: String) -> void:
		small_prompt.set_code(prompt, ExportSections.code_line(ExportSections.GROUP, typed.strip_edges())))


func move_into(var_name: String, group: String) -> bool:
	return _write(EventSheetL10n.translate("Move %s into %s") % [var_name, group.strip_edges()],
		EventSheetL10n.translate("%s is in %s now.") % [var_name, group.strip_edges()],
		func() -> bool: return move_into_group(_dock._current_sheet, var_name, group))


## The exported members among the rows: the selection when the clicked row is in it, else that row.
func _selected_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var rows: Array = _dock._viewport.get_selected_rows() if _dock._viewport != null else []
	if _dock._context_row != null and not rows.has(_dock._context_row):
		rows = [_dock._context_row]
	for row_data: EventRowData in rows:
		var var_name: String = str(identity_of(row_data).get("name", ""))
		if not var_name.is_empty() and is_exported(member(_dock._current_sheet, var_name)) and not names.has(var_name):
			names.append(var_name)
	return names


## "Group by prefix…": proposes the start the selected names share as the prefix, and that start read
## as words as the group's name, then writes the one prefix group.
func prompt_group_by_prefix() -> void:
	var names: PackedStringArray = _selected_names()
	var prefix: String = ExportSections.shared_start(names)
	if names.is_empty() or prefix.is_empty():
		_dock._set_status(EventSheetL10n.translate("Select exported variables whose names start the same way (bullet_count, bullet_speed)."), true)
		return
	var title_edit: LineEdit = LineEdit.new()
	title_edit.text = prefix.capitalize()
	var prefix_edit: LineEdit = LineEdit.new()
	prefix_edit.text = prefix
	var fields: VBoxContainer = EventSheetPopupUI.form_box()
	fields.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Group"), title_edit))
	fields.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Only names starting"), prefix_edit))
	var listed: Array = []
	for var_name: String in names:
		listed.append([var_name, ""])
	var code_for: Callable = func() -> String:
		return ExportSections.code_line(ExportSections.GROUP, title_edit.text.strip_edges(), prefix_edit.text.strip_edges())
	var small_prompt: GDScript = load(SMALL_PROMPT_PATH)
	var prompt: ConfirmationDialog = small_prompt.open(_dock, {
		"title": EventSheetL10n.translate("Group these by the start they share?"),
		"say": EventSheetL10n.translate("Godot puts only the names that start with the prefix into the group, and shows them without it: bullet_speed reads as Speed."),
		"list": listed,
		"body": fields,
		"code": code_for.call(),
		"note": EventSheetL10n.translate("Ctrl+Z puts them back."),
		"main": EventSheetL10n.translate("Group"),
		"on_main": func() -> void: group_names(names, title_edit.text, prefix_edit.text),
	})
	for edit: LineEdit in [title_edit, prefix_edit]:
		edit.text_changed.connect(func(_typed: String) -> void: small_prompt.set_code(prompt, code_for.call()))


func group_names(names: PackedStringArray, title: String, prefix: String) -> bool:
	return _write(EventSheetL10n.translate("Group by prefix"),
		EventSheetL10n.translate("%s now holds the names starting %s.") % [title.strip_edges(), prefix.strip_edges()],
		func() -> bool: return group_by_prefix(_dock._current_sheet, names, title, prefix))

# ── The right-click submenus ──────────────────────────────────────────────────────────────────────


## Group ▸ for the right-clicked member: a new group, each group the sheet has (ticked at its own),
## Group by prefix and End group here - greyed, with the reason and an "Open" item, for a member
## declared in another file.
func fill_group_menu(menu: PopupMenu) -> void:
	menu.clear()
	var row_data: EventRowData = _dock._context_row
	_menu_file = declared_in(row_data)
	var found: Variant = member(_dock._current_sheet, str(identity_of(row_data).get("name", ""))) \
		if row_data != null and _menu_file.is_empty() else null
	menu.add_item(EventSheetL10n.translate("New group…"), GROUP_MENU_NEW)
	_menu_groups = sheet_groups(_dock._current_sheet)
	if not _menu_groups.is_empty():
		menu.add_separator(EventSheetL10n.translate("Move into"))
	var current: String = group_of_row(row_data, found) if found != null else ""
	for index: int in _menu_groups.size():
		menu.add_radio_check_item(_menu_groups[index], GROUP_MENU_FIRST + index)
		menu.set_item_checked(menu.item_count - 1, _menu_groups[index] == current)
		menu.set_item_disabled(menu.item_count - 1, found == null or not is_exported(found))
	menu.add_separator()
	menu.add_item(EventSheetL10n.translate("Group by prefix…"), GROUP_MENU_BY_PREFIX)
	menu.add_item(EventSheetL10n.translate("End group here"), GROUP_MENU_END_HERE)
	menu.set_item_disabled(menu.get_item_index(GROUP_MENU_END_HERE), not can_end_group_here(row_data, _dock._current_sheet))
	if not _menu_file.is_empty():
		for id: int in [GROUP_MENU_NEW, GROUP_MENU_END_HERE]:
			menu.set_item_disabled(menu.get_item_index(id), true)
			menu.set_item_tooltip(menu.get_item_index(id), elsewhere_note(_menu_file))
		menu.add_item(EventSheetL10n.translate("Open %s") % _menu_file.get_file(), GROUP_MENU_OPEN_FILE)


func on_group_menu(id: int) -> void:
	var var_name: String = str(identity_of(_dock._context_row).get("name", "")) if _dock._context_row != null else ""
	match id:
		GROUP_MENU_NEW:
			_dock._variables._group_context_selection()
		GROUP_MENU_BY_PREFIX:
			prompt_group_by_prefix()
		GROUP_MENU_OPEN_FILE:
			_dock.open_object_file_as_sheet(_menu_file)
		GROUP_MENU_END_HERE:
			_write(EventSheetL10n.translate("End the group above %s") % var_name,
				EventSheetL10n.translate("The group now ends above %s.") % var_name,
				func() -> bool: return end_group_here(_dock._current_sheet, var_name))
		_:
			if id - GROUP_MENU_FIRST >= 0 and id - GROUP_MENU_FIRST < _menu_groups.size():
				move_into(var_name, _menu_groups[id - GROUP_MENU_FIRST])


## Inspector look ▸ for the right-clicked member: the type's own editor and every look it can wear,
## ticked at the one it wears now. A look with details to fill ends in "…" and opens the window on them.
func fill_look_menu(menu: PopupMenu) -> void:
	menu.clear()
	var found: Variant = member(_dock._current_sheet, str(identity_of(_dock._context_row).get("name", ""))) if _dock._context_row != null else null
	_menu_looks = PackedStringArray([""])
	if found == null:
		return
	var type_name: String = _type_of(found)
	var options: PackedStringArray = (found as LocalVariable).options if found is LocalVariable else PackedStringArray()
	var current: String = str(EventSheetInspectorLooks.unfold(attributes_of(found), options)[0]) if is_exported(found) else "-"
	menu.add_radio_check_item(EventSheetInspectorLooks.plain_label(type_name), 0)
	menu.set_item_checked(0, current.is_empty())
	for look: Dictionary in EventSheetInspectorLooks.for_type(type_name):
		var has_details: bool = not (look.get("fields", []) as Array).is_empty()
		menu.add_radio_check_item(EventSheetInspectorLooks.label(look) + ("…" if has_details else ""), _menu_looks.size())
		menu.set_item_tooltip(menu.item_count - 1, EventSheetInspectorLooks.description(look))
		menu.set_item_checked(menu.item_count - 1, current == str(look.get("id")))
		_menu_looks.append(str(look.get("id")))


func on_look_menu(id: int) -> void:
	if id < 0 or id >= _menu_looks.size() or _dock._context_row == null:
		return
	var look_id: String = _menu_looks[id]
	if not (EventSheetInspectorLooks.by_id(look_id).get("fields", []) as Array).is_empty():
		open_window(_dock._context_row, "details", look_id)
		return
	var var_name: String = str(identity_of(_dock._context_row).get("name", ""))
	_write(EventSheetL10n.translate("Change how %s looks in the Inspector") % var_name,
		EventSheetL10n.translate("%s has a new look in the Inspector.") % var_name,
		func() -> bool: return set_look(_dock._current_sheet, var_name, look_id))


## Puts a member on one look with its details at their defaults ("" = the type's own editor). The
## member is in the Inspector afterwards, which is the only place a look shows.
static func set_look(sheet: EventSheetResource, var_name: String, look_id: String) -> bool:
	var found: Variant = member(sheet, var_name)
	if found == null:
		return false
	var attributes: Dictionary = attributes_of(found).duplicate(true)
	for key: String in EventSheetInspectorLooks.look_keys():
		attributes.erase(key)
	if not look_id.is_empty():
		attributes.merge(EventSheetInspectorLooks.fold(look_id, {}, _type_of(found)), true)
	attributes.erase("options")
	_set_attributes(found, attributes)
	if found is LocalVariable:
		(found as LocalVariable).exported = true
		(found as LocalVariable).export_hint = ""
	else:
		(found as Dictionary)["exported"] = true
		(found as Dictionary)["exposed"] = true
	return true

# ── Add > Inspector button ────────────────────────────────────────────────────────────────────────


## The lines a button writes: its group (when it names one), the button and, for a new function,
## the function it calls.
static func inspector_button_code(label: String, icon: String, runs: String, group: String, new_function: bool) -> String:
	var lines: PackedStringArray = PackedStringArray()
	if not group.strip_edges().is_empty():
		lines.append(ExportSections.code_line(ExportSections.GROUP, group.strip_edges()))
	lines.append("@export_tool_button(%s) var %s_button = %s" % [button_arguments(label, icon), label.strip_edges().to_snake_case(), runs])
	if new_function:
		lines.append("\nfunc %s() -> void:\n\tpass" % runs)
	return "\n".join(lines)


## The annotation's arguments, in Godot's spelling: the label, then the icon when there is one.
static func button_arguments(label: String, icon: String) -> String:
	var arguments: String = "\"%s\"" % label.strip_edges().c_escape()
	if not icon.strip_edges().is_empty():
		arguments += ", \"%s\"" % icon.strip_edges().c_escape()
	return arguments


## Add > Inspector button: what the button says, the editor icon it shows (checked against the editor's
## own theme), the function it runs - one of the sheet's or a new one - and the group it sits in.
func prompt_inspector_button() -> void:
	var sheet: EventSheetResource = _dock._current_sheet
	if sheet == null:
		return
	var label_edit: LineEdit = LineEdit.new()
	label_edit.text = "Bake"
	var icon_edit: LineEdit = LineEdit.new()
	icon_edit.placeholder_text = "Bake"
	var icon_note: EventSheetPopupUI.StateNote = EventSheetPopupUI.StateNote.new(380.0)
	var runs: OptionButton = OptionButton.new()
	runs.add_item(EventSheetL10n.translate("New function…"))
	for entry: Variant in sheet.functions:
		if entry is EventFunction:
			runs.add_item((entry as EventFunction).function_name)
	var group_edit: LineEdit = LineEdit.new()
	group_edit.placeholder_text = EventSheetL10n.translate("Tool buttons")
	var groups: PackedStringArray = sheet_groups(sheet)
	EventSheetCompletionPopup.attach_entries(group_edit, func(typed: String) -> Array:
		return Array(groups).filter(func(known: String) -> bool: return known.to_lower().contains(typed.to_lower())))
	var fields: VBoxContainer = EventSheetPopupUI.form_box()
	fields.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Label"), label_edit))
	fields.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Editor icon"), icon_edit))
	fields.add_child(icon_note)
	fields.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Runs"), runs))
	fields.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Group"), group_edit))
	var target: Callable = func() -> String:
		return "_%s" % label_edit.text.strip_edges().to_snake_case() if runs.selected <= 0 else runs.get_item_text(runs.selected)
	var code_for: Callable = func() -> String:
		return inspector_button_code(label_edit.text, icon_edit.text, target.call(), group_edit.text, runs.selected <= 0)
	var small_prompt: GDScript = load(SMALL_PROMPT_PATH)
	var prompt: ConfirmationDialog = small_prompt.open(_dock, {
		"title": EventSheetL10n.translate("Add an Inspector button?"),
		"say": EventSheetL10n.translate("Pressing the button in the Inspector runs the function in the editor. The sheet has to be a Tool sheet for it to run there."),
		"body": fields,
		"code": code_for.call(),
		"note": EventSheetL10n.translate("Ctrl+Z removes the button again."),
		"main": EventSheetL10n.translate("Add Button"),
		"on_main": func() -> void:
			add_inspector_button(label_edit.text, icon_edit.text, "" if runs.selected <= 0 else runs.get_item_text(runs.selected), group_edit.text),
	})
	var refresh: Callable = func() -> void:
		small_prompt.set_code(prompt, code_for.call())
		var icon: String = icon_edit.text.strip_edges()
		icon_note.say(EventSheetL10n.translate("The editor has no icon called %s, so the button would show none.") % icon
			if not icon.is_empty() and Engine.is_editor_hint() and EventSheetPopupUI._editor_icon(icon) == null else "",
			EventSheetPopupUI.TONE_WARNING)
	for edit: LineEdit in [label_edit, icon_edit, group_edit]:
		edit.text_changed.connect(func(_typed: String) -> void: refresh.call())
	runs.item_selected.connect(func(_index: int) -> void: refresh.call())
	if label_edit.is_inside_tree():
		label_edit.grab_focus()
		label_edit.select_all()


## Writes the button - a Callable variable among the members, `@export_tool_button` - and, when `runs`
## is empty, the new function it calls, in ONE undo step.
func add_inspector_button(label: String, icon: String, runs: String, group: String) -> bool:
	var sheet: EventSheetResource = _dock._current_sheet
	var words: String = label.strip_edges()
	if sheet == null or words.is_empty():
		return false
	var function_name: String = runs if not runs.is_empty() \
		else _dock._unique_extracted_function_name(sheet, "_%s" % words.to_snake_case())
	var var_name: String = "%s_button" % words.to_snake_case()
	var suffix: int = 2
	while member(sheet, var_name) != null:
		var_name = "%s_button_%d" % [words.to_snake_case(), suffix]
		suffix += 1
	var arguments: String = button_arguments(words, icon)
	var changed: bool = _dock._perform_undoable_sheet_edit(EventSheetL10n.translate("Add Inspector Button"), func() -> bool:
		var button: LocalVariable = LocalVariable.new()
		button.name = var_name
		button.type_name = "Callable"
		button.default_value = function_name
		button.expression_default = true
		button.exported = true
		button.attributes = {"tool_button": {"args": arguments, "label": words}}
		if not group.strip_edges().is_empty():
			button.attributes["group"] = group.strip_edges()
		var events: Array = _dock._current_sheet.events
		var last_member: int = -1
		for index: int in events.size():
			if events[index] is LocalVariable:
				last_member = index
		events.insert(last_member + 1, button)
		if runs.is_empty():
			var made: EventFunction = EventFunction.new()
			made.function_name = function_name
			_dock._current_sheet.functions.append(made)
		return true)
	if changed:
		_dock._refresh_after_edit()
		_dock._mark_dirty(EventSheetL10n.translate("Added the Inspector button \"%s\", which calls %s.") % [words, function_name]
			+ ("" if sheet.tool_mode else " " + EventSheetL10n.translate("(turn on Tool in the Sheet Type dialog for it to run in the editor.)")))
	return changed
