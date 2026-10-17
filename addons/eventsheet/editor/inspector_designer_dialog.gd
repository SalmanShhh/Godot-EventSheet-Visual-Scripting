# Godot EventSheets - the Inspector Designer: the WHOLE sheet's Inspector as one live view.
#
# Per-variable dialogs answer "what will THIS property look like"; this dialog answers "what does
# my whole Inspector look like" - every exported variable rendered top-to-bottom with its decor,
# grouping, and widget miniature, through the same preview-card builders the Variable dialog uses
# (one source of truth: the mock cannot lie). The view itself only READS; every edit routes back
# through the dock (the ✎ button opens the same Variable dialog, ▲ reorders through the undo
# funnel), and the dock calls refresh() afterwards - so the Designer can never mutate a sheet
# behind the funnel's back. Without wired handlers (tests, render harnesses) it stays a pure view.
@tool
class_name EventSheetInspectorDesignerDialog
extends AcceptDialog

var _column: VBoxContainer = null
var _row_card_count: int = 0
# The foot: the strip says what the row under the pointer does and the line it is in the file; the
# note beside Close says why the sheet variables at the top carry no ▲.
var _strip: EventSheetPopupUI.HelpStrip = null
var _this_field: Label = null
var _order_note: Label = null
# Editing seams, wired by the dock: ✎ routes the entry to the shared Variable dialog, ▲ moves a
# tree variable above the exported one before it (move_up_among_exported), and live_sheet re-fetches the CURRENT
# sheet on refresh (the funnel replaces resources - a cached sheet reference goes stale).
var _edit_handler: Callable = Callable()
var _move_up_handler: Callable = Callable()
var _live_sheet: Callable = Callable()


## Wires the editing seams (dock-side); called once right after construction.
func wire_editing(edit_handler: Callable, move_up_handler: Callable, live_sheet: Callable) -> void:
	_edit_handler = edit_handler
	_move_up_handler = move_up_handler
	_live_sheet = live_sheet


## Rebuilds from the LIVE sheet - the dock calls this after a Designer-initiated edit lands.
func refresh() -> void:
	if _live_sheet.is_valid():
		rebuild_for_sheet(_live_sheet.call())


func _init() -> void:
	title = EventSheetL10n.translate("Inspector Designer")
	ok_button_text = EventSheetL10n.translate("Close")
	min_size = Vector2i(560, 620)
	var body: VBoxContainer = VBoxContainer.new()
	add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520.0, 460.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 6)
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_column)
	_strip = EventSheetPopupUI.help_strip()
	_this_field = _strip.add_line(EventSheetL10n.translate("THIS FIELD"), true)
	body.add_child(_strip)
	_order_note = Label.new()
	_order_note.text = EventSheetL10n.translate("Sheet variables keep the file's order")
	_order_note.add_theme_color_override("font_color", EventSheetPopupUI.muted_text_color())
	get_ok_button().add_sibling(_order_note)
	_order_note.get_parent().move_child(_order_note, 0)


## Every Inspector-visible variable of the sheet, in Inspector order: sheet-level (dict) variables
## first, in the order the compiler emits them, then tree variables in sheet order. The order comes
## from the compiler itself rather than being re-derived here - a preview that lists the properties
## in an order Godot will not show them in answers the wrong question. Each entry carries the SAME
## keys the preview card reads. Static + UI-free so the suite pins the collection without popping a
## dialog.
static func collect_entries(sheet: EventSheetResource) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if sheet == null:
		return entries
	for var_name: Variant in SheetCompiler.variable_emit_order(sheet.variables):
		var descriptor: Variant = sheet.variables.get(var_name)
		if not (descriptor is Dictionary) or not bool((descriptor as Dictionary).get("exported", true)):
			continue
		var descriptor_dict: Dictionary = descriptor as Dictionary
		var attributes: Dictionary = (descriptor_dict.get("attributes") as Dictionary).duplicate(true) if descriptor_dict.get("attributes") is Dictionary else {}
		var combo_options: Array = descriptor_dict.get("options") if descriptor_dict.get("options") is Array else []
		if not combo_options.is_empty():
			attributes["options"] = combo_options
		entries.append({
			"name": str(var_name),
			"scope": "global",
			"type_name": str(descriptor_dict.get("type", "Variant")),
			"default_text": EventSheetVariableOwners.default_text(descriptor_dict.get("default")),
			"attributes": attributes,
			"constant": false,
			"code": EventSheetCodeEcho.line_for_descriptor(str(var_name), descriptor_dict)
		})
	for entry: Variant in sheet.events:
		if entry is LocalVariable and (entry as LocalVariable).exported:
			var tree_var: LocalVariable = entry as LocalVariable
			entries.append({
				"name": tree_var.name,
				"scope": "tree",
				"type_name": tree_var.type_name,
				"default_text": EventSheetVariableOwners.default_text(tree_var.default_value),
				"attributes": (tree_var.attributes as Dictionary).duplicate(true) if tree_var.attributes is Dictionary else {},
				"constant": tree_var.is_constant,
				"code": EventSheetCodeEcho.line_for(tree_var)
			})
	return entries


## Rebuilds the whole-Inspector view (popup-free so tests can count rows).
func rebuild_for_sheet(sheet: EventSheetResource) -> void:
	while _column.get_child_count() > 0:
		var stale: Node = _column.get_child(0)
		_column.remove_child(stale)
		stale.free()
	_row_card_count = 0
	_strip.set_line(_this_field, "")
	_strip.set_reading("", "")
	var handle_chips: PackedStringArray = declared_handle_chips(sheet)
	if not handle_chips.is_empty():
		_column.add_child(_build_handle_chips(handle_chips))
	var entries: Array[Dictionary] = collect_entries(sheet)
	_order_note.visible = _move_up_handler.is_valid() and entries.any(func(entry: Dictionary) -> bool: return entry.get("scope") == "global")
	if entries.is_empty():
		_column.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate("No Inspector-visible variables yet - tick \"Editable in the Inspector\" on a variable and it appears here.")))
		return
	_column.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate("Every Inspector-visible variable, named exactly as the file declares it. ✎ edits a variable; ▲ moves a sheet variable up (the list is in the order the file declares them).") \
		if _edit_handler.is_valid() else EventSheetL10n.translate("Every Inspector-visible variable, named exactly as the file declares it. Edit a variable from its row in the sheet (hover it there for this same preview).")))
	var previous_tree: String = ""
	for entry: Dictionary in entries:
		var card: EventSheetInspectorPreviewCard = EventSheetInspectorPreviewCard.new()
		card.hide_caption()
		card.update_preview(
			str(entry.get("name")),
			str(entry.get("type_name")),
			str(entry.get("default_text")),
			entry.get("attributes") as Dictionary,
			true,
			bool(entry.get("constant", false))
		)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_row_card_count += 1
		var above: String = previous_tree
		var said: String = row_sentence(entry, above) if _edit_handler.is_valid() else ""
		card.mouse_entered.connect(_point_at.bind(said, str(entry.get("code", ""))))
		if _row_card_count == 1:
			_point_at(said, str(entry.get("code", "")))
		if str(entry.get("scope", "")) == "tree":
			previous_tree = str(entry.get("name"))
		if not _edit_handler.is_valid():
			_column.add_child(card)
			continue
		var row: HBoxContainer = HBoxContainer.new()
		row.add_child(card)
		var buttons: VBoxContainer = VBoxContainer.new()
		var edit_button: Button = Button.new()
		edit_button.text = "✎"
		edit_button.tooltip_text = EventSheetL10n.translate("Edit %s in the Variable dialog") % str(entry.get("name"))
		edit_button.pressed.connect(_on_edit_pressed.bind(entry.duplicate(true)))
		buttons.add_child(edit_button)
		if str(entry.get("scope", "")) == "tree" and _move_up_handler.is_valid():
			var up_button: Button = Button.new()
			up_button.text = "▲"
			up_button.tooltip_text = EventSheetL10n.translate("Move this variable up in the Inspector (one undo step)")
			up_button.disabled = above.is_empty()
			up_button.pressed.connect(_on_move_up_pressed.bind(str(entry.get("name"))))
			buttons.add_child(up_button)
		for button: Node in buttons.get_children():
			(button as Button).mouse_entered.connect(_point_at.bind(said, str(entry.get("code", ""))))
			(button as Button).focus_entered.connect(_point_at.bind(said, str(entry.get("code", ""))))
		row.add_child(buttons)
		_column.add_child(row)


## What the strip says about one row: ✎ opens it, and for a variable that can move, ▲ puts it above
## `above` (the exported variable before it). Static so the suite pins the wording.
static func row_sentence(entry: Dictionary, above: String) -> String:
	var var_name: String = str(entry.get("name"))
	if str(entry.get("scope", "")) != "tree" or above.is_empty():
		return EventSheetL10n.translate("%s: ✎ opens it in the Variable dialog.") % var_name
	return EventSheetL10n.translate("%s: ✎ opens it in the Variable dialog; ▲ moves it above %s, as one undo step.") % [var_name, above]


## Puts one row in the strip: what its buttons do, and the line it is in the file.
func _point_at(said: String, code: String) -> void:
	_strip.set_line(_this_field, said)
	_strip.set_reading("", code)


## The viewport handles this sheet's own script declares, as chips. They come from the FILE rather
## than from the rows: a `# @inspector_handle` line is a plain comment a pack author writes, it emits
## nothing and it belongs to no single variable, so there is no row to read it off. A sheet that is
## not backed by a .gd, or one whose script declares none, answers with nothing. Static + UI-free so
## the suite pins the reading.
static func declared_handle_chips(sheet: EventSheetResource) -> PackedStringArray:
	if sheet == null or sheet.external_source_path.is_empty():
		return PackedStringArray()
	if not FileAccess.file_exists(sheet.external_source_path):
		return PackedStringArray()
	var decor: Dictionary = EventSheetInspectorObjectDecor.parse(FileAccess.get_file_as_string(sheet.external_source_path))
	return EventSheetInspectorObjectDecor.chips(decor.get("handles", []))


## The chips row: what a designer will be able to drag in the viewport, read before opening a scene.
func _build_handle_chips(chips: PackedStringArray) -> Control:
	var row: HFlowContainer = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	var lead: Label = Label.new()
	lead.text = EventSheetL10n.translate("Dragged in the viewport:")
	lead.add_theme_font_size_override("font_size", EventSheetPalette.scaled(11))
	lead.add_theme_color_override("font_color", EventSheetPopupUI.muted_text_color())
	row.add_child(lead)
	for chip: String in chips:
		var label: Label = Label.new()
		label.text = chip
		label.add_theme_font_size_override("font_size", EventSheetPalette.scaled(11))
		label.add_theme_color_override("font_color", EventSheetPopupUI.text_color())
		row.add_child(label)
	return row


## Moves the exported sheet variable `var_name` up past the exported one above it - the next one up
## in the Inspector - by taking it out and putting it back right before that one, so every variable
## the Inspector does not show keeps its place. False when it is already first (or not found).
static func move_up_among_exported(events: Array, var_name: String) -> bool:
	var previous_index: int = -1
	for index: int in range(events.size()):
		var entry: Variant = events[index]
		if not (entry is LocalVariable) or not (entry as LocalVariable).exported:
			continue
		if (entry as LocalVariable).name == var_name:
			if previous_index < 0:
				return false
			events.remove_at(index)
			events.insert(previous_index, entry)
			return true
		previous_index = index
	return false


func open_for_sheet(sheet: EventSheetResource) -> void:
	rebuild_for_sheet(sheet)
	popup_centered()


## The number of variable rows currently shown (excludes the intro/empty hint) - test seam.
func row_count() -> int:
	return _row_card_count


func _on_edit_pressed(entry: Dictionary) -> void:
	if _edit_handler.is_valid():
		_edit_handler.call(entry)


func _on_move_up_pressed(var_name: String) -> void:
	if _move_up_handler.is_valid():
		_move_up_handler.call(var_name)
	refresh()
