@tool
extends EventSheetInspectorLook

## Editable table
## Every element a row of cells. Columns: name:type (String, int, float, bool, color, enum(a|b)).

## The kinds of property this look can be put on.
@export var works_on: String = "Array,Array[Dictionary]"
## Columns
## item:String, count:int
@export var columns: String = ""
## Weight column
## The number column each row's share is worked out from. Leave empty for none.
@export var weight_column: String = ""

## The door the plugin hands in: opens a .tres in the sheet editor's table view. Unset, no link is drawn.
var open_table: Callable = Callable()

## The sentence the preview card says under a variable that wears this look.
const PREVIEW_SENTENCE := "Shown as an editable table."

## Which tables the person folded, by edited object and property, for as long as the editor runs: the
## Inspector rebuilds its rows on every selection, and a table folded a moment ago stays folded.
static var _folded: Dictionary = {}

var _table: Control
var _fold: Button
var _panel: PanelContainer
var _open_path: String = ""


## A table with no columns leaves the plain list, as without this plugin.
func _can_draw() -> bool:
	return not _columns().is_empty()


func _look_built() -> void:
	_fold = Button.new()
	_fold.toggle_mode = true
	_fold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fold.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_fold.toggled.connect(_on_fold_toggled)
	add_child(_fold)
	add_focusable(_fold)
	_table = EventSheetAttributeDrawers.widgets().DrawerTable.new(_columns())
	_table.connect("value_changed", _on_table_changed)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", EventSheetLookStyle.panel_box())
	_panel.add_child(_table)
	add_child(_panel)
	set_bottom_editor(_panel)
	draw_background = false


func _value_shown(value: Variant) -> void:
	# Guard by VALUE, not a one-shot flag: the echo from our own commit (and from the `changed` signal we
	# fire for the live preview) carries a value equal to what the grid already shows, so we skip the
	# rebuild and the cell being typed in keeps focus. Only an external change (undo, reselecting the
	# asset) brings a different value that actually rebuilds the grid.
	var incoming: Array = value if value is Array else []
	_offer_open_link(field_object())
	_show_fold(incoming.size())
	if incoming == _table.call("get_value"):
		return
	_table.call("set_value", incoming)
	_show_fold(incoming.size())


## The button's words: how many rows the table holds. It is down while the table is open.
func _show_fold(rows: int) -> void:
	_fold.text = EventSheetL10n.translate("Table (1 row)") if rows == 1 else EventSheetL10n.translate("Table (%d rows)") % rows
	var open: bool = not _folded.get(_fold_key(), false)
	_fold.set_pressed_no_signal(open)
	_panel.visible = open
	var picture: Texture2D = EventSheetLookStyle.icon(&"GuiTreeArrowDown" if open else &"GuiTreeArrowRight")
	_fold.icon = picture


func _on_fold_toggled(open: bool) -> void:
	_folded[_fold_key()] = not open
	_panel.visible = open
	_show_fold(_table.call("get_value").size())


func _fold_key() -> String:
	var edited: Object = field_object()
	return "%d:%s" % [edited.get_instance_id() if edited != null else 0, field_name()]


func _on_table_changed(rows: Array) -> void:
	set_field_value(rows)
	_show_fold(rows.size())
	# Writing the value onto the resource through the inspector does NOT fire the resource's `changed`
	# signal, so live-preview listeners (the DrawingPrefab preview panel, a DrawingPrefabStamp) would
	# never repaint on a table edit. Emit `changed` explicitly so they refresh from the just-written
	# value; the echo it may provoke is a no-op (equal value).
	var edited: Object = field_object()
	if edited is Resource:
		(edited as Resource).emit_changed()


func _columns() -> Array:
	return EventSheetAttributeDrawers.parse_table_columns(str(marker_args[0]) if marker_args.size() > 0 else "", marker_args.slice(1))


## "Open as a table" under the grid, for a list kept in a file of its own: the file opens in the
## table view of the sheet editor. A list inside a scene or a sub-resource has no file to open.
func _offer_open_link(edited: Object) -> void:
	var path: String = file_of(edited) if open_table.is_valid() else ""
	if path == _open_path:
		return
	_open_path = path
	_table.set("open_table", open_table.bind(path) if not path.is_empty() else Callable())
	_table.call("_rebuild")


## The file an edited object is kept in, when it is a .tres or .res of its own; "" otherwise.
static func file_of(edited: Object) -> String:
	var path: String = (edited as Resource).resource_path if edited is Resource else ""
	return path if path.get_extension() in ["tres", "res"] and not path.contains("::") else ""
