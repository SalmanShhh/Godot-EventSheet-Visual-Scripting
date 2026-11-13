@tool
extends EventSheetInspectorLook

## Editable table
## Every element a row of cells. Columns: name:type (String, int, float, bool, color, enum(a|b)).

## The kinds of property this look can be put on.
@export var works_on: String = "Array,Array[Dictionary]"
## item:String, count:int
@export var columns: String = ""

## The door the plugin hands in: opens a .tres in the sheet editor's table view. Unset, no link is drawn.
var open_table: Callable = Callable()

## The sentence the preview card says under a variable that wears this look.
const PREVIEW_SENTENCE := "Shown as an editable table."

var _table: Control
var _open_path: String = ""


## A table with no columns leaves the plain list, as without this plugin.
func _can_draw() -> bool:
	return not _columns().is_empty()


func _look_built() -> void:
	_table = EventSheetAttributeDrawers.widgets().DrawerTable.new(_columns())
	_table.connect("value_changed", _on_table_changed)
	add_child(_table)
	set_bottom_editor(_table)


func _value_shown(value: Variant) -> void:
	# Guard by VALUE, not a one-shot flag: the echo from our own commit (and from the `changed` signal we
	# fire for the live preview) carries a value equal to what the grid already shows, so we skip the
	# rebuild and the cell being typed in keeps focus. Only an external change (undo, reselecting the
	# asset) brings a different value that actually rebuilds the grid.
	var incoming: Array = value if value is Array else []
	_offer_open_link(field_object())
	if incoming == _table.call("get_value"):
		return
	_table.call("set_value", incoming)


func _on_table_changed(rows: Array) -> void:
	set_field_value(rows)
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
