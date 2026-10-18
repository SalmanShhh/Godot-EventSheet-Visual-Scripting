# Godot EventSheets - the Inspector Designer: the WHOLE sheet's Inspector as one live view.
#
# Per-variable dialogs answer "what will THIS property look like"; this dialog answers "what does
# my whole Inspector look like" - every exported variable rendered top-to-bottom with its decor,
# grouping, and widget miniature, through the same preview-card builders the Variable dialog uses
# (one source of truth: the mock cannot lie). The view itself only READS; every edit routes back
# through the dock (the ✎ button opens the same Variable dialog, ▲ reorders through the undo
# funnel), and the dock calls refresh() afterwards - so the Designer can never mutate a sheet
# behind the funnel's back. Without wired handlers (tests, render harnesses) it stays a pure view.
#
# Clicking a field picks it, and the "Shape this field" panel beside the list (inspector_shape_panel.gd,
# loaded by path with the Designer itself) offers its six kinds of choice, and "Groups show as" above
# the list says how the groups are drawn. A choice is handed to the dock's shape handler as (name,
# kind, option, answers) - one undo step - and the refresh that follows shows the field wearing it.
@tool
class_name EventSheetInspectorDesignerDialog
extends AcceptDialog

const SHAPE_PANEL_PATH := "res://addons/eventsheet/editor/inspector_shape_panel.gd"
const SHAPE_PATH := "res://addons/eventsheet/editor/inspector_shape.gd"

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
var _shape_handler: Callable = Callable()
# The picked field, kept by name across refreshes (the funnel replaces the resources), and the tab
# its panel shows; the cards' frames by name, so the pick can be redrawn without a rebuild.
var _picked: String = ""
var _picked_category: String = ""
var _frames: Dictionary = {}
var _entries: Array[Dictionary] = []
var _sheet: EventSheetResource = null
var _shape_panel: VBoxContainer = null
var _groups_option: OptionButton = null


## Wires the editing seams (dock-side); called once right after construction.
func wire_editing(edit_handler: Callable, move_up_handler: Callable, live_sheet: Callable) -> void:
	_edit_handler = edit_handler
	_move_up_handler = move_up_handler
	_live_sheet = live_sheet


## Wires the shaping seam (dock-side): `handler` is called with (var_name, category, option_id,
## answers) for every choice the "Shape this field" panel makes.
func wire_shaping(handler: Callable) -> void:
	_shape_handler = handler


## Rebuilds from the LIVE sheet - the dock calls this after a Designer-initiated edit lands.
func refresh() -> void:
	if _live_sheet.is_valid():
		rebuild_for_sheet(_live_sheet.call())


func _init() -> void:
	title = EventSheetL10n.translate("Inspector Designer")
	ok_button_text = EventSheetL10n.translate("Close")
	min_size = Vector2i(1120, 660)
	var body: VBoxContainer = VBoxContainer.new()
	add_child(body)
	body.add_child(_build_groups_row())
	var split: HBoxContainer = HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(split)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(440.0, 460.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(scroll)
	_shape_panel = load(SHAPE_PANEL_PATH).new()
	_shape_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shape_panel.visible = false
	_shape_panel.chose.connect(_on_shape_chosen)
	split.add_child(EventSheetPopupUI.panel_section(_shape_panel))
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
				"attributes": _with_options((tree_var.attributes as Dictionary).duplicate(true) if tree_var.attributes is Dictionary else {}, tree_var.options),
				"constant": tree_var.is_constant,
				"code": EventSheetCodeEcho.line_for(tree_var)
			})
	return entries


## A String dropdown's choices ride the entry's attributes under "options", as a sheet variable's do.
static func _with_options(attributes: Dictionary, options: PackedStringArray) -> Dictionary:
	if not options.is_empty():
		attributes["options"] = Array(options)
	return attributes


## Rebuilds the whole-Inspector view (popup-free so tests can count rows).
func rebuild_for_sheet(sheet: EventSheetResource) -> void:
	while _column.get_child_count() > 0:
		var stale: Node = _column.get_child(0)
		_column.remove_child(stale)
		stale.free()
	_row_card_count = 0
	_frames = {}
	_sheet = sheet
	_strip.set_line(_this_field, "")
	_strip.set_reading("", "")
	var handle_chips: PackedStringArray = declared_handle_chips(sheet)
	if not handle_chips.is_empty():
		_column.add_child(_build_handle_chips(handle_chips))
	var entries: Array[Dictionary] = collect_entries(sheet)
	_entries = entries
	_follow_group_style()
	_order_note.visible = _move_up_handler.is_valid() and entries.any(func(entry: Dictionary) -> bool: return entry.get("scope") == "global")
	if entries.is_empty():
		_column.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate("No Inspector-visible variables yet - tick \"Editable in the Inspector\" on a variable and it appears here.")))
		_shape_panel.visible = false
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
		_dim_for_switch(card, entry, entries)
		_row_card_count += 1
		var above: String = previous_tree
		var said: String = row_sentence(entry, above) if _edit_handler.is_valid() else ""
		card.mouse_entered.connect(_point_at.bind(said, str(entry.get("code", ""))))
		if _row_card_count == 1:
			_point_at(said, str(entry.get("code", "")))
		if str(entry.get("scope", "")) == "tree":
			previous_tree = str(entry.get("name"))
		var frame: PanelContainer = _pickable_frame(card, str(entry.get("name")))
		if not _edit_handler.is_valid():
			_column.add_child(frame)
			continue
		var row: HBoxContainer = HBoxContainer.new()
		row.add_child(frame)
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
	_column.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate("Click a field to shape it.")))
	var names: Array = entries.map(func(entry: Dictionary) -> String: return str(entry.get("name")))
	pick_field(_picked if names.has(_picked) else str(names[0]), _picked_category)


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


## Opens on `sheet`, with `field` picked and its panel on the tab `category` when they are named (the
## help strip's and the Inspector's doors open it so).
func open_for_sheet(sheet: EventSheetResource, field: String = "", category: String = "") -> void:
	if not field.is_empty():
		_picked = field
	_picked_category = category
	rebuild_for_sheet(sheet)
	if is_inside_tree():
		popup_centered()


## Picks a field: its card is framed and the panel shows its choices on `category` (or the tab it was on).
func pick_field(var_name: String, category: String = "") -> void:
	var entry: Dictionary = {}
	for candidate: Dictionary in _entries:
		if str(candidate.get("name")) == var_name:
			entry = candidate
	if entry.is_empty():
		return
	_picked = var_name
	if not category.is_empty():
		_picked_category = category
	for named: Variant in _frames:
		_paint_frame(_frames[named] as PanelContainer, str(named) == var_name)
	_shape_panel.visible = true
	_shape_panel.show_field(_sheet, entry, _entries, _picked_category)
	_point_at(row_sentence(entry, "") if _edit_handler.is_valid() else "", str(entry.get("code", "")))


## The field picked now - test seam.
func picked_field() -> String:
	return _picked


## The "Shape this field" panel - test seam.
func shape_panel() -> VBoxContainer:
	return _shape_panel


## The "Groups show as" dropdown - test seam.
func groups_dropdown() -> OptionButton:
	return _groups_option


func _on_shape_chosen(category: String, option_id: String, answers: Dictionary) -> void:
	_picked_category = category
	if _shape_handler.is_valid():
		_shape_handler.call(_picked, category, option_id, answers)
	refresh()


## "Groups show as": Sections or Tabs, each described; a way not built yet is greyed with the reason.
func _build_groups_row() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	var lead: Label = Label.new()
	lead.text = EventSheetL10n.translate("Groups show as")
	lead.add_theme_color_override("font_color", EventSheetPopupUI.muted_text_color())
	row.add_child(lead)
	_groups_option = EventSheetPopupUI.described_option()
	for style: Dictionary in load(SHAPE_PATH).group_styles():
		var reason: String = str(style.get("reason", ""))
		var index: int = EventSheetPopupUI.add_described_item(_groups_option, str(style.get("label")),
			str(style.get("tip")) if reason.is_empty() else "%s\n%s" % [style.get("tip"), reason], str(style.get("id")))
		_groups_option.set_item_disabled(index, not reason.is_empty())
	_groups_option.item_selected.connect(func(index: int) -> void:
		var style_id: String = str(_groups_option.get_item_metadata(index))
		if _shape_handler.is_valid() and style_id != load(SHAPE_PATH).group_style(_sheet):
			_shape_handler.call("", "groups", style_id, {})
		refresh())
	row.add_child(_groups_option)
	# The chosen way's sentence stays in view beside the dropdown, as a described field keeps it under.
	var note: Label = EventSheetPopupUI.hint_label("", 640.0)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_groups_option.set_meta("chosen_note", note)
	row.add_child(note)
	return row


func _follow_group_style() -> void:
	var style_id: String = load(SHAPE_PATH).group_style(_sheet) if _sheet != null else "sections"
	for index: int in range(_groups_option.item_count):
		if str(_groups_option.get_item_metadata(index)) == style_id:
			_groups_option.select(index)
	EventSheetPopupUI.follow_description(_groups_option)


## A card inside a frame a click picks it by: the frame wears the accent while its field is picked.
func _pickable_frame(card: Control, var_name: String) -> PanelContainer:
	var frame: PanelContainer = PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.focus_mode = Control.FOCUS_ALL
	frame.tooltip_text = EventSheetL10n.translate("Click to shape %s") % var_name
	frame.add_child(card)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	frame.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
				or (event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode in [KEY_ENTER, KEY_SPACE]):
			pick_field(var_name))
	_frames[var_name] = frame
	_paint_frame(frame, false)
	return frame


static func _paint_frame(frame: PanelContainer, picked: bool) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(EventSheetPopupUI.accent_color(), 0.14) if picked else Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = EventSheetPopupUI.accent_color() if picked else Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(EventSheetPalette.scaled(2))
	style.set_corner_radius_all(EventSheetPalette.scaled(3))
	frame.add_theme_stylebox_override("panel", style)


## A field a Show when ties to a tick box that starts off is drawn the way Godot will draw it then:
## faint while hidden, greyed while read-only, and its hover says why.
static func _dim_for_switch(card: Control, entry: Dictionary, entries: Array[Dictionary]) -> void:
	var attributes: Dictionary = entry.get("attributes", {})
	var hides: String = str(attributes.get("show_if", "")).strip_edges()
	var locks: String = str(attributes.get("lock_unless", "")).strip_edges()
	var switch: String = hides if not hides.is_empty() else locks
	if switch.is_empty():
		return
	for other: Dictionary in entries:
		if str(other.get("name")) == switch and str(other.get("default_text")) == "false":
			card.modulate = Color(1.0, 1.0, 1.0, 0.45 if not hides.is_empty() else 0.6)
			card.tooltip_text = EventSheetL10n.translate("Hidden while %s is off.") % switch if not hides.is_empty() \
				else EventSheetL10n.translate("Read-only while %s is off.") % switch


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
