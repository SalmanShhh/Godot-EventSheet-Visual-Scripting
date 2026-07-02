@tool
class_name EventSheetFunctionsPanel
extends VBoxContainer
# The Functions overview as its OWN dockable left-rail panel — previously welded inside the
# Generated-GDScript side panel, so seeing your functions meant opening the code view. Now it sits
# in the rail (under Open Sheets, above Anatomy) behind a fold header you expand whenever you want:
# every sheet function at a glance with its signature (✦ = exposed as an ACE), ＋ adds one, and the
# list keeps its click/right-click behaviour (the dock owns those handlers — this panel is shell +
# fold state only). Expanded/collapsed persists per-project across editor restarts.

## The header's ＋ — the dock opens the function dialog (the ACE Studio).
signal add_requested

const _META_KEY: String = "eventsheets_functions_panel"

var list: ItemList = null

var _header_button: Button = null
var _count: int = 0
var _expanded: bool = false

func _init() -> void:
	name = "Functions"
	custom_minimum_size = Vector2(180.0, 0.0)
	var header: HBoxContainer = HBoxContainer.new()
	_header_button = Button.new()
	_header_button.flat = true
	_header_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_button.tooltip_text = "Every sheet function at a glance (✦ = published as an ACE). Click to expand or collapse."
	_header_button.pressed.connect(func() -> void: set_expanded(not _expanded))
	header.add_child(_header_button)
	var add_button: Button = Button.new()
	add_button.text = "＋"
	add_button.flat = true
	add_button.tooltip_text = "Add a function…"
	add_button.pressed.connect(func() -> void: add_requested.emit())
	header.add_child(add_button)
	add_child(header)
	list = ItemList.new()
	list.name = "EventSheetFunctionsList"
	list.custom_minimum_size = Vector2(0.0, 110.0)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.allow_reselect = true
	add_child(list)
	set_expanded(bool(_read_prefs().get("expanded", false)))

## Expanding gives the list rail space (it competes with Open Sheets / Anatomy); collapsing shrinks
## the panel back to its one-line header.
func set_expanded(expanded: bool) -> void:
	_expanded = expanded
	list.visible = expanded
	size_flags_vertical = Control.SIZE_EXPAND_FILL if expanded else Control.SIZE_SHRINK_BEGIN
	_refresh_header()
	_save_prefs()

func is_expanded() -> bool:
	return _expanded

## The dock pushes the function count after every refresh so the collapsed header still tells the
## sheet's weight ("▸ Functions · 12") without expanding.
func set_count(count: int) -> void:
	_count = count
	_refresh_header()

func _refresh_header() -> void:
	_header_button.text = "%s Functions · %d" % ["▾" if _expanded else "▸", _count]

func _read_prefs() -> Dictionary:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var meta: Variant = EditorInterface.get_editor_settings().get_project_metadata("eventsheets", _META_KEY, {})
		if meta is Dictionary:
			return meta
	return {}

func _save_prefs() -> void:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		EditorInterface.get_editor_settings().set_project_metadata("eventsheets", _META_KEY, {"expanded": _expanded})
