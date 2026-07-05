# Godot EventSheets - the Inspector Designer: the WHOLE sheet's Inspector as one live view.
#
# Per-variable dialogs answer "what will THIS property look like"; this dialog answers "what does
# my whole Inspector look like" - every exported variable rendered top-to-bottom with its decor,
# grouping, and widget miniature, through the same preview-card builders the Variable dialog uses
# (one source of truth: the mock cannot lie). This first slice is a pure VIEW: it only reads the
# sheet; editing gestures (reorder, regroup, click-through) layer on top of it next.
@tool
class_name EventSheetInspectorDesignerDialog
extends AcceptDialog

var _column: VBoxContainer = null
var _empty_hint: Label = null


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
	var entries: Array[Dictionary] = collect_entries(sheet)
	if entries.is_empty():
		_empty_hint = Label.new()
		_empty_hint.text = "No Inspector-visible variables yet - tick \"Editable in the Inspector\" on a variable and it appears here."
		_empty_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_column.add_child(_empty_hint)
		return
	var intro: Label = Label.new()
	intro.text = "Every Inspector-visible variable, exactly as Godot will show it. Edit a variable from its row in the sheet (hover it there for this same preview)."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 11)
	intro.modulate = Color(1.0, 1.0, 1.0, 0.65)
	_column.add_child(intro)
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
		_column.add_child(card)


func open_for_sheet(sheet: EventSheetResource) -> void:
	rebuild_for_sheet(sheet)
	popup_centered()


## The number of variable rows currently shown (excludes the intro/empty hint) - test seam.
func row_count() -> int:
	var count: int = 0
	for child: Node in _column.get_children():
		if child is EventSheetInspectorPreviewCard:
			count += 1
	return count
