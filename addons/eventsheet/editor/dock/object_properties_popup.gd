@tool
class_name EventSheetObjectProperties
extends RefCounted

# The OBJECT popup - what an object label hands over when you click it.
#
# A row's object column carries a name and a picture and nothing else, which is right: the row is
# about what happens, not about what the object is. Everything a reader then wants to know - what
# type it is, where in the scene it lives, which verbs this file uses it with, which of its signals
# the file listens to - lives here, one click away, in ONE place instead of scattered across rows.
#
# The panel is a pure function of a census entry (property_rows/build_panel are static and
# display-free), so a test can pin the exact rows an object answers with and a headless run builds
# it without a display server. Only open_for() needs a live editor.
#
# The three buttons REUSE surfaces that already exist - the viewport's filter lens for highlighting,
# Godot's own scene selection, and the script editor for the code - so nothing here can disagree
# with the rest of the editor about what it is showing.


## Rows shown above the buttons, in order. Kept as data so a caller (and a test) reads exactly what
## an object answers, and so the panel builder has one loop instead of five hand-placed rows.
## Each entry: {"label": String, "value": String, "form": String} - form is "text" (a plain value)
## or "code" (a monospace card).
static func property_rows(entry: Dictionary, scene_name: String = "",
		source_path: String = "") -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if entry.is_empty():
		return rows
	rows.append({"label": EventSheetL10n.translate("Type"), "value": type_summary(entry), "form": "text"})
	rows.append_array(identity_rows(entry, source_path))
	var path: String = path_summary(entry, scene_name)
	if not path.is_empty():
		rows.append({"label": EventSheetL10n.translate("Path"), "value": path, "form": "code"})
	rows.append({"label": EventSheetL10n.translate("Rows"), "value": rows_summary(entry), "form": "text"})
	var signals_used: String = signals_summary(entry)
	if not signals_used.is_empty():
		rows.append({"label": EventSheetL10n.translate("Signals used"), "value": signals_used, "form": "text"})
	return rows


## Q1 - what the object IS, as opposed to what this file does with it: the instance variables it
## carries, the functions and triggers it offers, the behaviors mounted on it and the families it
## belongs to. Each row is a chip list, in the order a reader asks for them; a row with nothing in it
## is not built, because "Behaviors: none" is a line on nearly every object.
##
## The families row carries the muted Godot word as its note - a Godot group IS the sheet's family,
## and a reader who knows only one of the two words needs the bridge exactly once.
static func identity_rows(entry: Dictionary, source_path: String,
		familiar_words: bool = false) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if entry.is_empty():
		return rows
	var facts: Dictionary = EventSheetObjectFacts.facts_for_entry(entry, source_path)
	_append_chip_row(rows, EventSheetL10n.translate("Instance variables"),
		_named_chips(facts.get("variables", [])))
	_append_chip_row(rows, EventSheetL10n.translate("Functions"),
		_signature_chips(facts.get("functions", []), EventSheetL10n.translate("condition")))
	_append_chip_row(rows, EventSheetL10n.translate("Triggers"),
		_signature_chips(facts.get("triggers", []), ""))
	_append_chip_row(rows, EventSheetL10n.translate("Behaviors"), _behavior_chips(facts.get("behaviors", [])))
	var families: Array = _family_chips(facts.get("families", PackedStringArray()))
	if not families.is_empty():
		rows.append({
			# T9. The word for an inheritance set is a setting, so the object page asks the one helper
			# for it exactly as the Object bar and the head folder do.
			"label": EventSheetFamilyFacts.plural(familiar_words),
			"value": _chip_text(families),
			"form": "chips",
			"chips": families,
			"note": EventSheetL10n.translate("(groups)")
		})
	return rows


static func _append_chip_row(rows: Array[Dictionary], label: String, chips: Array) -> void:
	if chips.is_empty():
		return
	rows.append({"label": label, "value": _chip_text(chips), "form": "chips", "chips": chips, "note": ""})


## `{"text", "note"}` per chip - the note is the muted half a chip carries (a parameter list, a
## behavior's setting, the word "condition").
static func _named_chips(named: Array) -> Array:
	var chips: Array = []
	for item: Variant in named:
		chips.append({"text": str((item as Dictionary).get("name", "")), "note": ""})
	return chips


## A function or trigger chip: its display name, with its parameter names as the muted note. A
## function that answers yes-or-no is a CONDITION on the sheet, and says so.
static func _signature_chips(declared: Array, condition_word: String) -> Array:
	var chips: Array = []
	for item: Variant in declared:
		var declaration: Dictionary = item
		var note: String = " ".join(PackedStringArray(declaration.get("params", PackedStringArray())))
		if not condition_word.is_empty() and bool(declaration.get("condition", false)):
			note = condition_word if note.is_empty() else "%s · %s" % [note, condition_word]
		chips.append({"text": str(declaration.get("display", "")), "note": note})
	return chips


## A behavior chip: the pack's name, with what the scene set on it as the note.
static func _behavior_chips(behaviors: Array) -> Array:
	var chips: Array = []
	for item: Variant in behaviors:
		var behavior: Dictionary = item
		var settings: PackedStringArray = PackedStringArray()
		for property_entry: Variant in behavior.get("properties", []):
			var property: Dictionary = property_entry
			settings.append("%s = %s" % [str(property.get("name", "")), str(property.get("value", ""))])
		chips.append({"text": str(behavior.get("name", "")), "note": " · ".join(settings)})
	return chips


static func _family_chips(families: PackedStringArray) -> Array:
	var chips: Array = []
	for family: String in families:
		chips.append({"text": family, "note": ""})
	return chips


## One chip row read back as plain text, so a test pins what the row says without walking Controls.
static func _chip_text(chips: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for item: Variant in chips:
		var chip: Dictionary = item
		var note: String = str(chip.get("note", ""))
		parts.append(str(chip.get("text", "")) if note.is_empty() else "%s (%s)" % [str(chip.get("text", "")), note])
	return " · ".join(parts)


## What the object IS: its class when the file declares one, otherwise the kind of thing it is. A
## behaviour says which pack it is, because that is the answer to "what is this node for".
static func type_summary(entry: Dictionary) -> String:
	var class_name_str: String = str(entry.get("class", "")).strip_edges()
	if not class_name_str.is_empty():
		return class_name_str
	var kind: String = str(entry.get("kind", ""))
	return EventSheetL10n.translate(str(EventSheetViewportReadingRows.OBJECT_KIND_WORDS.get(kind, kind)))


## Where the object lives: its node path, and the scene that path is written in when the editor knows
## which scene that is. Empty for a thing with no place - a group is a name, not a location.
static func path_summary(entry: Dictionary, scene_name: String) -> String:
	var path: String = str(entry.get("path", "")).strip_edges()
	if path.is_empty() or str(entry.get("kind", "")) == "group":
		return ""
	if scene_name.strip_edges().is_empty():
		return path
	return EventSheetL10n.translate("%s in %s") % [path, scene_name.strip_edges()]


## The verbs this file uses the object with, and how many rows do - the answer to "what does this
## file actually do with it". "no verbs" when the file only names it, which is itself worth knowing.
static func rows_summary(entry: Dictionary) -> String:
	var verbs: PackedStringArray = entry.get("verbs", PackedStringArray())
	var count: int = int(entry.get("rows", 0))
	var count_word: String = EventSheetL10n.translate("1 row") if count == 1 \
		else EventSheetL10n.translate("%d rows") % count
	if verbs.is_empty():
		return count_word
	return "%s · %s" % [" · ".join(verbs), count_word]


## The object's signals this file listens to or fires, or "" when it uses none - a row saying "no
## signals" would be noise on nearly every object.
static func signals_summary(entry: Dictionary) -> String:
	var signals_used: PackedStringArray = entry.get("signals", PackedStringArray())
	return ", ".join(signals_used)


## The panel an object label opens: a title line naming the object and its kind, the property rows,
## and the three ways out. Built with the shared popup helpers, so it wears the same card /
## small-caps / code-card look as every other dialog here. Display-free, so it builds fine headless.
## `on_highlight` / `on_select` / `on_code` are optional - a button with no handler is not built.
static func build_panel(entry: Dictionary, scene_name: String = "", class_map: Dictionary = {},
		on_highlight: Callable = Callable(), on_select: Callable = Callable(),
		on_code: Callable = Callable(), source_path: String = "",
		on_add_condition: Callable = Callable(), on_add_action: Callable = Callable(),
		on_open_sheet: Callable = Callable(), variable_table: Control = null) -> Control:
	var column: VBoxContainer = EventSheetPopupUI.form_box()
	column.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(360.0), 0.0)
	if entry.is_empty():
		column.add_child(EventSheetPopupUI.hint_label(
			EventSheetL10n.translate("This object is no longer used by this file.")))
		return EventSheetPopupUI.margined(column)
	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(6.0)))
	var icon: Texture2D = EventSheetViewportReadingRows.object_icon(entry, class_map, source_path)
	if icon != null:
		var picture: TextureRect = TextureRect.new()
		picture.texture = icon
		picture.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(16.0), EventSheetPalette.scaled_f(16.0))
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		title_row.add_child(picture)
	var title: Label = Label.new()
	title.text = str(entry.get("label", ""))
	title_row.add_child(title)
	var trailing: Label = Label.new()
	trailing.text = EventSheetL10n.translate("object")
	trailing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trailing.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	trailing.add_theme_color_override("font_color", EventSheetActiveTheme.reading().muted_text_color)
	title_row.add_child(trailing)
	column.add_child(title_row)
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	for row: Dictionary in property_rows(entry, scene_name, source_path):
		form.add_child(EventSheetPopupUI.form_row(str(row.get("label", "")), _field_for(row)))
	column.add_child(EventSheetPopupUI.panel_section(form))
	# R39 - the object's own variables as a TABLE, not a chip list: the popup is where a reader
	# already came to ask what the object is, so it is where adding, renaming, retyping and
	# deleting one belongs. Only the sheet's own object gets it - the table writes into THIS file.
	if variable_table != null:
		column.add_child(EventSheetPopupUI.section_header(
			EventSheetL10n.translate("Instance variables")))
		column.add_child(variable_table)
	# Q1 - the two ways to START using the object, first: the popup is where a reader who just learned
	# what an object offers reaches for it, and both open the picker already scoped to this object.
	var authoring: HBoxContainer = HBoxContainer.new()
	authoring.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(6.0)))
	_add_button(authoring, EventSheetL10n.translate("Add condition"), on_add_condition, true)
	_add_button(authoring, EventSheetL10n.translate("Add action"), on_add_action, true)
	var own_file: String = str(EventSheetObjectFacts.facts_for_entry(entry, source_path).get("script_path", ""))
	if not own_file.is_empty() and own_file != source_path:
		_add_button(authoring, EventSheetL10n.translate("Open %s as sheet") % own_file.get_file(),
			on_open_sheet, true)
	if authoring.get_child_count() > 0:
		column.add_child(authoring)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(6.0)))
	_add_button(buttons, EventSheetL10n.translate("Highlight rows"), on_highlight, true)
	# Selecting in the scene only means anything while that scene is the one open in the editor;
	# offered-but-dead is worse than plainly unavailable, so it greys out instead of failing.
	_add_button(buttons, EventSheetL10n.translate("Select in scene"), on_select, can_select_in_scene(entry, scene_name))
	_add_button(buttons, EventSheetL10n.translate("Show in code"), on_code, true)
	if buttons.get_child_count() > 0:
		column.add_child(buttons)
	return EventSheetPopupUI.margined(column)


## True when the object IS the thing this file is - the one object whose instance variables the
## open sheet declares, and so the only one whose variable table can write anything. Every other
## object in the census lives in another file (or in the scene) and answers with facts only.
static func owns_sheet_variables(entry: Dictionary) -> bool:
	return str(entry.get("kind", "")) == "script"


## True when "Select in scene" can do what it says: the object has a node path, and the editor has
## the scene that path is written in open.
static func can_select_in_scene(entry: Dictionary, scene_name: String) -> bool:
	if str(entry.get("kind", "")) in ["group", "scene", "autoload"]:
		return false
	var path: String = str(entry.get("path", "")).strip_edges()
	return not path.is_empty() and not scene_name.strip_edges().is_empty()


## One property row's field control, by its declared form.
static func _field_for(row: Dictionary) -> Control:
	var value: String = str(row.get("value", ""))
	var form: String = str(row.get("form", "text"))
	if form == "code":
		return EventSheetPopupUI.code_card(value, EventSheetPalette.scaled_f(240.0))
	if form == "chips":
		return _chip_field(row)
	var label: Label = Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(240.0), 0.0)
	return label


## A chip row's field: one badge per name, wrapping, with the row's muted note (the Godot word behind
## "Families") trailing. Built from the shared badge helper, so a chip here wears the same look as a
## chip on a row.
static func _chip_field(row: Dictionary) -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", int(EventSheetPalette.scaled_f(4.0)))
	flow.add_theme_constant_override("v_separation", int(EventSheetPalette.scaled_f(4.0)))
	flow.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(240.0), 0.0)
	for item: Variant in row.get("chips", []):
		var chip: Dictionary = item
		var note: String = str(chip.get("note", ""))
		var text: String = str(chip.get("text", ""))
		flow.add_child(EventSheetPopupUI.metadata_badge(text if note.is_empty() else "%s  %s" % [text, note]))
	var note_text: String = str(row.get("note", ""))
	if not note_text.is_empty():
		var muted := Label.new()
		muted.text = note_text
		muted.add_theme_color_override("font_color", EventSheetActiveTheme.reading().muted_text_color)
		flow.add_child(muted)
	return flow


static func _add_button(host: HBoxContainer, text: String, handler: Callable, enabled: bool) -> void:
	if not handler.is_valid():
		return
	var button: Button = Button.new()
	button.text = text
	button.disabled = not enabled
	if enabled:
		button.pressed.connect(handler)
	host.add_child(button)


# ── The live popup (editor only) ───────────────────────────────────────────────────────────────

var _dock: Control = null
var _popup: PopupPanel = null


func init(dock: Control) -> void:
	_dock = dock


## Opens the properties for one object label at the mouse. Guarded: without a dock (or without a
## display) it simply does nothing, so a headless caller cannot crash on it.
func open_for(object_label: String) -> void:
	if _dock == null or not _dock.is_inside_tree():
		return
	var sheet: EventSheetResource = _dock._current_sheet
	var entry: Dictionary = find_entry(sheet, object_label)
	if _popup == null:
		_popup = PopupPanel.new()
		# One transient popup reused for every object - it dismisses on click-outside and Esc like
		# the verb properties popup and the ghost row, so the gesture is one users already know.
		_popup.popup_window = false
		_dock.add_child(_popup)
	# Snapshot first: removing a child while walking get_children() skips the next one.
	for child: Node in Array(_popup.get_children()):
		_popup.remove_child(child)
		child.queue_free()
	var label: String = str(entry.get("label", object_label))
	var source_path: String = str(sheet.get("external_source_path")) if sheet != null else ""
	var own_file: String = str(EventSheetObjectFacts.facts_for_entry(entry, source_path).get("script_path", ""))
	_popup.add_child(build_panel(
		entry, scene_name_for(sheet), EventSheetViewportReadingRows.object_class_map(sheet),
		func() -> void: _run_and_close(func() -> void: _dock.highlight_object_rows(label)),
		func() -> void: _run_and_close(func() -> void: _dock.select_object_in_scene(str(entry.get("path", "")))),
		func() -> void: _run_and_close(func() -> void: _dock.show_object_in_code(label)),
		source_path,
		func() -> void: _run_and_close(func() -> void: _dock.add_row_for_object(label, false)),
		func() -> void: _run_and_close(func() -> void: _dock.add_row_for_object(label, true)),
		func() -> void: _run_and_close(func() -> void: _dock.open_object_file_as_sheet(own_file)),
		_dock._instance_variables.build_for(sheet) if owns_sheet_variables(entry) else null
	))
	_popup.reset_size()
	_popup.popup(Rect2i(Vector2i(_dock.get_screen_transform() * _dock.get_local_mouse_position()), Vector2i.ZERO))


## The census entry an object label belongs to, re-derived from the LIVE sheet at click time: the
## undo funnel replaces every resource on commit, so a census taken when the row was drawn may
## describe a sheet that no longer exists. Falls back to {} for a label the file no longer uses,
## which the panel says in words rather than by opening empty.
##
## The label is matched with its "(global)" note taken off, because that note is part of how an
## autoload READS, not part of its name.
static func find_entry(sheet: EventSheetResource, object_label: String) -> Dictionary:
	var wanted: String = object_label.strip_edges().trim_suffix(
		EventSheetL10n.translate(EventSheetViewportReadingRows.GLOBAL_NOTE)).strip_edges()
	if sheet == null or wanted.is_empty():
		return {}
	for entry: Dictionary in EventSheetViewportReadingRows.object_census(sheet):
		if str(entry.get("label", "")) == wanted:
			return entry
	return {}


## The scene the sheet's own object lives in, by file name, or "" when no scene in the project uses
## this script. Reuses the scan the file's head bar already does, so the popup and the head can never
## name two different scenes. Only the NAME is shown - a full res:// path in a popup is noise.
static func scene_name_for(sheet: EventSheetResource) -> String:
	if sheet == null:
		return ""
	var source_path: String = str(sheet.get("external_source_path")).strip_edges()
	if source_path.is_empty():
		return ""
	var scene: Dictionary = ViewportRowBuilder.scene_using_script(source_path)
	return str(scene.get("scene_path", "")).get_file()


func _run_and_close(action: Callable) -> void:
	if _popup != null:
		_popup.hide()
	action.call()
