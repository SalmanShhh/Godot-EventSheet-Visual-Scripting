# Godot EventSheets - the Outline panel (dock subsystem)
#
# The script editor's method-list, for sheets: a slim jump tree of the STRUCTURAL rows -
# groups (nested), region fences, and published functions - so a ballooning sheet
# navigates by the names you remember, not by scrolling. Clicking an entry reveals +
# selects the row. The entry walk is static and pure, so tests pin it headless.
@tool
class_name EventSheetOutlinePanel
extends RefCounted

const COLOR_GROUP := Color("#e0b070")     # amber - groups (the picker's section tint)
const COLOR_REGION := Color("#7fb3d5")    # blue - region fences (the script editor's fold hue)
const COLOR_FUNCTION := Color("#c79bf0")  # purple - published verbs (the picker's custom tint)

var _dock: Control = null

var window: Window = null
var tree: Tree = null
var _empty_hint: Label = null


func _init(dock: Control) -> void:
	_dock = dock


## The structural walk: groups (with nesting), region openers, then the sheet's published
## functions. Returns [{label, resource, depth, kind}] in sheet order - pure, so tests pin it.
static func outline_entries(sheet: EventSheetResource) -> Array:
	var entries: Array = []
	if sheet == null:
		return entries
	_collect_outline(sheet.events, 0, entries)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			entries.append({
				"label": (function_entry as EventFunction).function_name,
				"resource": function_entry,
				"depth": 0,
				"kind": "function"
			})
	return entries


static func _collect_outline(rows: Array, depth: int, entries: Array) -> void:
	for entry: Variant in rows:
		if entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			entries.append({"label": group.group_name, "resource": group, "depth": depth, "kind": "group"})
			_collect_outline(group.events if not group.events.is_empty() else group.rows, depth + 1, entries)
		elif entry is CustomBlockRow:
			var block: CustomBlockRow = entry as CustomBlockRow
			if block.kind_id == "region" and not bool(block.fields.get("is_end", false)):
				var label: String = str(block.fields.get("label", "")).strip_edges()
				entries.append({"label": label if not label.is_empty() else "(region)", "resource": block, "depth": depth, "kind": "region"})
		elif entry is EventRow:
			_collect_outline((entry as EventRow).sub_events, depth + 1, entries)


## Builds the window + tree without popping it (testable headless); open() pops it up.
func build() -> void:
	if window != null:
		return
	window = Window.new()
	window.title = "Outline"
	window.size = Vector2i(360, 420)
	window.close_requested.connect(func() -> void: window.hide())
	var body_box: VBoxContainer = VBoxContainer.new()
	body_box.add_theme_constant_override("separation", 6)
	body_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree = Tree.new()
	tree.hide_root = true
	tree.select_mode = Tree.SELECT_ROW
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.custom_minimum_size = Vector2(0.0, 240.0)
	tree.item_selected.connect(_on_entry_selected)
	body_box.add_child(tree)
	_empty_hint = EventSheetPopupUI.hint_label("Nothing structural yet - groups, #region fences, and published functions appear here as you add them.", 320.0)
	body_box.add_child(_empty_hint)
	var card: Control = EventSheetPopupUI.titled_card("Outline", body_box)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body: Control = EventSheetPopupUI.margined(card)
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	window.add_child(body)
	_dock.add_child(window)


func open() -> void:
	build()
	refresh()
	window.popup_centered()


## Rebuilds the jump tree from the current sheet (popup-free; testable headless).
func refresh() -> void:
	if tree == null:
		return
	tree.clear()
	var root: TreeItem = tree.create_item()
	var entries: Array = outline_entries(_dock._current_sheet)
	# depth -> parent TreeItem, so nested groups indent naturally.
	var parents: Dictionary = {0: root}
	for entry: Dictionary in entries:
		var depth: int = int(entry.get("depth", 0))
		var parent: TreeItem = parents.get(depth, root)
		var item: TreeItem = tree.create_item(parent)
		var kind: String = str(entry.get("kind", ""))
		item.set_text(0, _entry_prefix(kind) + str(entry.get("label", "")))
		item.set_custom_color(0, _entry_color(kind))
		item.set_metadata(0, entry.get("resource", null))
		if kind == "group":
			parents[depth + 1] = item
	if _empty_hint != null:
		_empty_hint.visible = entries.is_empty()


static func _entry_prefix(kind: String) -> String:
	match kind:
		"group":
			return "▸ "
		"region":
			return "# "
		"function":
			return "ƒ "
	return ""


static func _entry_color(kind: String) -> Color:
	match kind:
		"group":
			return COLOR_GROUP
		"region":
			return COLOR_REGION
		"function":
			return COLOR_FUNCTION
	return Color.WHITE


func _on_entry_selected() -> void:
	var selected: TreeItem = tree.get_selected()
	if selected == null:
		return
	var target: Resource = selected.get_metadata(0)
	if target != null and _dock._viewport != null:
		_dock._viewport.reveal_resource(target)
		_dock._viewport.select_resource(target)
