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
var _empty_hint: Label = null
var _row_card_count: int = 0
# Editing seams, wired by the dock: ✎ routes the entry to the shared Variable dialog, ▲ swaps a
# tree variable with the previous one in emission order, and live_sheet re-fetches the CURRENT
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
	title = "Inspector Designer"
	ok_button_text = "Close"
	min_size = Vector2i(560, 620)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520.0, 560.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 6)
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_column)


## Every Inspector-visible variable of the sheet, in Inspector order: sheet-level (dict)
## variables first (alphabetical - the order the compiler emits them), then tree variables in
## sheet order. Each entry carries the SAME keys the preview card reads. Static + UI-free so
## the suite pins the collection without popping a dialog.
static func collect_entries(sheet: EventSheetResource) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if sheet == null:
		return entries
	var dict_names: Array = sheet.variables.keys()
	dict_names.sort()
	for var_name: Variant in dict_names:
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
			"default_text": VariableDialog._default_display_text(descriptor_dict.get("default")),
			"attributes": attributes,
			"constant": false
		})
	for entry: Variant in sheet.events:
		if entry is LocalVariable and (entry as LocalVariable).exported:
			var tree_var: LocalVariable = entry as LocalVariable
			entries.append({
				"name": tree_var.name,
				"scope": "tree",
				"type_name": tree_var.type_name,
				"default_text": VariableDialog._default_display_text(tree_var.default_value),
				"attributes": (tree_var.attributes as Dictionary).duplicate(true) if tree_var.attributes is Dictionary else {},
				"constant": tree_var.is_constant
			})
	return entries


## Rebuilds the whole-Inspector view (popup-free so tests can count rows).
func rebuild_for_sheet(sheet: EventSheetResource) -> void:
	while _column.get_child_count() > 0:
		var stale: Node = _column.get_child(0)
		_column.remove_child(stale)
		stale.free()
	_empty_hint = null
	_row_card_count = 0
	var entries: Array[Dictionary] = collect_entries(sheet)
	if entries.is_empty():
		_empty_hint = Label.new()
		_empty_hint.text = "No Inspector-visible variables yet - tick \"Editable in the Inspector\" on a variable and it appears here."
		_empty_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_column.add_child(_empty_hint)
		return
	var intro: Label = Label.new()
	intro.text = "Every Inspector-visible variable, exactly as Godot will show it. ✎ edits a variable; ▲ moves a sheet variable up (top-level variables sort alphabetically)." if _edit_handler.is_valid() else "Every Inspector-visible variable, exactly as Godot will show it. Edit a variable from its row in the sheet (hover it there for this same preview)."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 11)
	intro.modulate = Color(1.0, 1.0, 1.0, 0.65)
	_column.add_child(intro)
	var first_tree_entry: bool = true
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
		if not _edit_handler.is_valid():
			_column.add_child(card)
			continue
		var row: HBoxContainer = HBoxContainer.new()
		row.add_child(card)
		var buttons: VBoxContainer = VBoxContainer.new()
		var edit_button: Button = Button.new()
		edit_button.text = "✎"
		edit_button.tooltip_text = "Edit %s in the Variable dialog" % str(entry.get("name"))
		edit_button.pressed.connect(_on_edit_pressed.bind(entry.duplicate(true)))
		buttons.add_child(edit_button)
		if str(entry.get("scope", "")) == "tree" and _move_up_handler.is_valid():
			var up_button: Button = Button.new()
			up_button.text = "▲"
			up_button.tooltip_text = "Move this variable up in the Inspector (one undo step)"
			up_button.disabled = first_tree_entry
			up_button.pressed.connect(_on_move_up_pressed.bind(str(entry.get("name"))))
			buttons.add_child(up_button)
		if str(entry.get("scope", "")) == "tree":
			first_tree_entry = false
		row.add_child(buttons)
		_column.add_child(row)


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
