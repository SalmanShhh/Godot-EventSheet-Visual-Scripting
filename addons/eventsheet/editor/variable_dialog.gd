# EventSheet - the Add / Edit variable window.
#
# The window writes ONE row, so it asks for that row in the order the row is read, in four cards:
# the variable itself (scope, name, type, initial value, description, flags), how the Inspector
# shows it (the look and its details), where it sits there (category, group, prefix, subgroup), and
# what happens when it changes (folded away until wanted). Every dropdown option carries the
# sentence that says what it means, and ONE help strip describes whatever is focused. The strip's
# READS AS line is the row itself, composed through EventSheetVariableSentence like every other
# surface, and its IN CODE lines are the compiler's own emitted declaration, so the window can
# never promise a line the compiler would not write.
#
# Connect to variable_confirmed to receive the result; a Global lands through
# project_global_requested instead, because a global belongs to an autoload rather than to this file.
@tool
class_name VariableDialog
extends RefCounted

## Emitted when the user confirms variable creation or editing.
## scope is "global" or "local". exported = accessible outside the generated script
## (@export var) vs. private (var). `context` carries the placement answers - which event or group
## owns a Local, which row is being edited, the `static_local` tick - and how the value was written:
## `default_text` (the words in the field), `value_is_code` (the value is GDScript to write as it
## stands, not a literal), `write_type` and `export_hint` (an annotation kept as the file wrote it).
signal variable_confirmed(name: String, type_name: String, default_value: Variant, scope: String, context: Dictionary, is_constant: bool, exported: bool, options: PackedStringArray, attributes: Dictionary, onready: bool, is_static: bool)

## The Scope dropdown says Global and the window was confirmed. A global lives on an autoload,
## not in this file, so the window hands over the answers it collected (with the autoload the "Write
## into" picker chose) rather than writing a member that only looks global.
signal project_global_requested(name: String, type_name: String, value_text: String, target: Dictionary)

const NativeVariableMarks := preload("res://addons/eventsheet/editor/interaction/native_variable_marks.gd")
const ExportSections := preload("res://addons/eventsheet/editor/interaction/export_sections.gd")
const VariableMarkTile := preload("res://addons/eventsheet/editor/variable_mark_tile.gd")

## The options that put a tile on the variable's row, keyed by the word each option is written with,
## and the tile each one carries beside it - the row's own tile, in the row's colours. The Inspector
## look's tile is the look's own (a slider for a range, the hidden eye for saved-but-hidden), so it is
## read from the look in front of the reader rather than listed here.
const OPTION_BADGES: Dictionary = {
	"Editable in the Inspector": NativeVariableMarks.BADGE_INSPECTOR,
	"Description": NativeVariableMarks.BADGE_TOOLTIP,
	"On ready": NativeVariableMarks.BADGE_ON_READY,
	"Show if": NativeVariableMarks.BADGE_SHOW_IF,
	"Setter body": NativeVariableMarks.BADGE_ON_CHANGE,
}
## The option word the Inspector look's tile stands beside.
const LOOK_OPTION := "Inspector look"

## The scopes the window offers, in the sheet's own order.
const CHOOSABLE_SCOPES: PackedStringArray = EventSheetVariableSentence.SCOPE_ORDER

## What each field is, one paragraph each, keyed by the word its row leads with. The strip shows an
## entry when the field is focused, and puts it back when a refusal about that field is answered.
## The dropdowns describe themselves per OPTION instead.
const FIELD_HELP: Dictionary = {
	"Name": "What the row will call it. Letters, digits and underscores, and not a word GDScript already uses. "
		+ "A name already taken in this scope is flagged under the field as you type.",
	"Initial value": "The value it starts at, in the editor the Inspector would give its type. Left empty it starts "
		+ "at nothing - 0 for a number, \"\" for text, false for a boolean.",
	"Description": "One line saying what the variable is for. It compiles to a ## comment above the declaration, which "
		+ "IS the description Godot shows in the Inspector - so it is never written twice.",
	"Static": "One value shared by every copy of the object rather than one each, and readable without a copy at "
		+ "all. Never combined with Constant - GDScript has no static const.",
	"Write the type in code": "Ticked, the line names its type (`var hp: int = 100`), so a later value of another kind "
		+ "is an error rather than a quiet change. Unticked, the code gives no type and Godot takes one from the "
		+ "initial value (`var hp = 100`). Either way the row reads the same.",
	"Static local": "The local keeps its value between runs of its event - a hit counter, a cooldown - instead of "
		+ "starting over each time. The row stays where it is; only the declaration moves, to a private "
		+ "member the rest of the sheet cannot name.",
	"Constant": "Set here and never changed while the game runs. A constant is neither Static nor an Inspector "
		+ "property, so both grey out when it is ticked.",
	"On ready": "The value is a lookup made when the node enters the scene ($Player, get_node(\"UI/Score\")), "
		+ "written as @onready var. The type is any class name.",
	"Editable in the Inspector": "A designer can tune this per copy in Godot's Inspector (@export var). Off, it is internal state "
		+ "only the sheet touches. A Local is never a property - it is gone before the Inspector could show it.",
	"Write into": "The autoload the global will live on - every sheet then reads it as Game.Score. \"New global "
		+ "sheet…\" makes one and registers it for you.",
	"Class": "The class the slot accepts: any node class (Node2D, Area2D, Label…), any resource class, or a "
		+ "class_name of your own. Only things of that class can be dropped in.",
	"Keep in step": "Whether a MultiplayerSynchronizer in this object's scene sends this value to the other players, "
		+ "and how often: Always every frame, On change only when it moves, At spawn only once with the "
		+ "object. The fact lives in the scene, so picking here writes the .tscn - the Replication panel "
		+ "is the same switch, and either can be undone from the scene.",
	"Category": "A heavy band in the Inspector that splits a long script into chapters (@export_category).",
	"Group": "A folder in the Inspector for the exported variables that share it (@export_group). Dragging rows "
		+ "together on the sheet does the same.",
	"Only names starting": "Godot puts only the names that start with this into the group, and shows them without "
		+ "it: bullet_speed reads as Speed under Bullet.",
	"Subgroup": "A folder inside the group (@export_subgroup).",
}

## The type list, every type GDScript can declare, grouped the way a reader looks for one:
## [group, type, short words, the sentence its option carries, how its initial value is edited].
## The value kinds: number, bool, text, string_name, node_path, color, vector, enum, callable, class
## (a node or resource class typed in the Class field), collection, code (written as GDScript) and
## none (Godot has no editor for it).
const TYPES: Array = [
	["Basic", "bool", "True or false", "On or off: is_locked, can_jump. The Inspector shows a checkbox.", "bool"],
	["Basic", "int", "Whole number", "A whole number: counts, lives, levels. No decimals. Sliders, dropdowns, flags and layer grids are its looks.", "number"],
	["Basic", "float", "Number with decimals", "A number that can have decimals: speeds, times, distances. Sliders with units, angles and easing curves are its looks.", "number"],
	["Text", "String", "Text", "Text: names, messages, file paths. File and folder pickers, big text boxes and dropdowns are its looks.", "text"],
	["Text", "StringName", "Unique name", "Text that is compared fast: action names, animation names, group names (&\"jump\").", "string_name"],
	["Text", "NodePath", "Path to a node", "A path such as ^\"Muzzle\", resolved when used. Can be limited to some node classes.", "node_path"],
	["Vectors and maths", "Vector2", "X and Y pair", "Two numbers together: a position, a size, a direction. The Inspector shows X and Y fields.", "vector"],
	["Vectors and maths", "Vector2i", "Whole X and Y", "Two whole numbers: a grid cell, a tile size.", "vector"],
	["Vectors and maths", "Vector3", "X, Y and Z", "Three numbers: a 3D position, size or direction.", "vector"],
	["Vectors and maths", "Vector3i", "Whole X, Y and Z", "Three whole numbers: a voxel or 3D grid cell.", "vector"],
	["Vectors and maths", "Vector4", "Four numbers", "Four numbers together, often shader values or corners.", "vector"],
	["Vectors and maths", "Vector4i", "Four whole numbers", "Four whole numbers together.", "vector"],
	["Vectors and maths", "Rect2", "Rectangle", "A position and a size: an area on screen.", "code"],
	["Vectors and maths", "Rect2i", "Whole rectangle", "A rectangle in whole numbers: a region of tiles.", "code"],
	["Vectors and maths", "Transform2D", "2D transform", "Position, rotation and scale together, in 2D.", "code"],
	["Vectors and maths", "Transform3D", "3D transform", "Position, rotation and scale together, in 3D.", "code"],
	["Vectors and maths", "Basis", "3D rotation and scale", "The rotation and scale part of a 3D transform.", "code"],
	["Vectors and maths", "Quaternion", "3D rotation", "A 3D rotation that blends smoothly.", "code"],
	["Vectors and maths", "Plane", "Plane", "An infinite flat surface in 3D: a normal and a distance.", "code"],
	["Vectors and maths", "AABB", "3D box", "An axis-aligned box in 3D: a position and a size.", "code"],
	["Vectors and maths", "Projection", "4x4 matrix", "A camera-style 4x4 projection matrix.", "code"],
	["Colour", "Color", "Colour", "A colour, with or without transparency. The Inspector shows a swatch you click to pick.", "color"],
	["Colour", "Gradient", "Colour ramp", "A smooth colour ramp (fire, sky, a health bar), edited in the Inspector's gradient editor.", "class"],
	["Nodes and resources", "Node2D", "A node in the scene", "A link to another node, picked from the scene tree. Any node class works (Node, Node3D, Control, Area2D...); only nodes of that class can be picked.", "class"],
	["Nodes and resources", "Resource", "A resource file", "A saved data file (.tres) such as stats or a curve, shared by everything that uses it. Any resource class or your own class_name works.", "class"],
	["Nodes and resources", "Texture2D", "Image", "An image or sprite resource.", "class"],
	["Nodes and resources", "Curve", "Curve", "A shape over 0 to 1 (easing, falloff, ramps), edited in the Inspector's curve editor.", "class"],
	["Nodes and resources", "Callable", "A function to call", "A function stored as a value. Exported, it becomes an Inspector button that runs in the editor (@tool).", "callable"],
	["Collections", "Array", "List of anything", "A list of values of any type. The Inspector edits each element.", "collection"],
	["Collections", "Array[int]", "List of whole numbers", "A typed list: every element is a whole number - scores, ids, tile indexes.", "collection"],
	["Collections", "Array[float]", "List of numbers", "A typed list of numbers - weights, timings, chances.", "collection"],
	["Collections", "Array[String]", "List of text", "A typed list of text - names, lines, tags.", "collection"],
	["Collections", "Array[Dictionary]", "List of rows", "A list of rows - the typed form of a table. The Editable table look edits it as a grid.", "collection"],
	["Collections", "Dictionary", "Key to value map", "Pairs of keys and values of any type.", "collection"],
	["Collections", "Dictionary[String, int]", "Whole numbers by name", "Keys of text and values of whole numbers - costs[\"sword\"] = 10.", "collection"],
	["Collections", "Dictionary[String, float]", "Numbers by name", "Keys of text and values of numbers - volumes[\"music\"] = 0.8.", "collection"],
	["Collections", "Dictionary[String, String]", "Text by name", "Keys of text and values of text - lines[\"greeting\"].", "collection"],
	["Collections", "Dictionary[String, Variant]", "Anything by name", "Keys of text and values of any type - a flexible data bag.", "collection"],
	["Packed arrays", "PackedByteArray", "Packed bytes", "A compact list of bytes: raw data.", "code"],
	["Packed arrays", "PackedInt32Array", "Packed whole numbers", "A compact list of 32-bit whole numbers.", "code"],
	["Packed arrays", "PackedFloat32Array", "Packed decimals", "A compact list of decimal numbers.", "code"],
	["Packed arrays", "PackedStringArray", "Packed text", "A compact list of texts.", "code"],
	["Packed arrays", "PackedVector2Array", "Packed 2D points", "A compact list of 2D points: a path, a polygon.", "code"],
	["Packed arrays", "PackedColorArray", "Packed colours", "A compact list of colours: a gradient, a palette.", "code"],
	["Special", "Variant", "Any type (untyped)", "No written type: holds anything. The Inspector needs a value to know what to show.", "text"],
	["Special", "Signal", "A signal as a value", "A signal stored in a variable. A real type, but the Inspector cannot show it.", "code"],
	["Special", "RID", "Server resource id", "A low-level handle to a server resource. A real type, but the Inspector cannot show it.", "none"],
]
## Types Godot cannot show in the Inspector, so the Inspector tick greys out for them.
const NOT_EXPORTABLE: PackedStringArray = ["Signal", "RID"]
## The value kinds whose field holds GDScript to write as it stands rather than a literal.
const CODE_KINDS: PackedStringArray = ["string_name", "node_path", "enum", "callable", "class", "code"]
## The "Keep in step" item that offers to add a synchronizer rather than pick a mode.
const SYNC_ADD_CHOICE: String = "add"
## The colour each axis letter wears, the way the editor's own vector fields tint them.
const AXIS_COLORS: Array = [Color("#f07a7a"), Color("#8ee09a"), Color("#7cb8ff"), Color("#9a9a9a")]

var _dialog: ConfirmationDialog = null
var _help_strip: EventSheetPopupUI.HelpStrip = null
## "to Player": whose variable this will be, said once at the top.
var _owner_label: Label = null
var _scope_option: OptionButton = null
var _global_target_option: OptionButton = null
var _global_target_row: Control = null
var _name_edit: LineEdit = null
var _name_warning: EventSheetPopupUI.StateNote = null
var _type_option: OptionButton = null
var _type_row: Control = null
var _type_search: LineEdit = null
## The class a node or resource slot accepts, and the free-typed type of an @onready lookup.
var _class_edit: LineEdit = null
var _class_row: Control = null
## The initial value: one field whose words are the truth, and the editors that write into it.
var _default_edit: LineEdit = null
var _value_prefix: Label = null
var _bool_check: CheckBox = null
var _color_button: ColorPickerButton = null
var _axis_box: HBoxContainer = null
var _items_button: Button = null
var _slot_buttons: HBoxContainer = null
var _value_note: Label = null
var _items_window: AcceptDialog = null
var _items_edit: TextEdit = null
var _write_type_check: CheckBox = null
var _attr_tooltip_edit: LineEdit = null
var _static_check: CheckBox = null
var _static_local_check: CheckBox = null
var _const_check: CheckBox = null
var _onready_check: CheckBox = null
var _sync_option: OptionButton = null
## The Inspector card: its tick, the look, the look's details and the preview of the result.
var _inspector_card: Control = null
var _exported_check: CheckBox = null
var _look_option: OptionButton = null
var _look_details: VBoxContainer = null
var _look_note: EventSheetPopupUI.StateNote = null
var _inspector_preview_card: EventSheetInspectorPreviewCard = null
## Where it sits: category, group, the group's name prefix, subgroup.
var _sections_card: Control = null
var _category_edit: LineEdit = null
var _group_edit: LineEdit = null
var _prefix_check: CheckBox = null
var _prefix_edit: LineEdit = null
var _subgroup_edit: LineEdit = null
var _prefix_note: EventSheetPopupUI.StateNote = null
## When it changes: everything that wires the variable to other code, folded away until wanted.
var _changes_fold: FoldableContainer = null
var _changes_edits: Dictionary = {}
var _changes_checks: Dictionary = {}
var _setter_edit: TextEdit = null
var _getter_edit: TextEdit = null
var _refresh_label: Label = null

## Queried at gating time (a dock-owned preference); invalid Callable = expert mode.
var simple_mode_provider: Callable = Callable()
## Returns the EventSheetEventStyle of the sheet the window edits, whose tile colours the option tiles
## wear so they match the row's; unset wears the default style's.
var style_provider: Callable = Callable()
## The tile beside each option that puts one on the row, keyed by the option's word (OPTION_BADGES,
## plus LOOK_OPTION).
var _mark_tiles: Dictionary = {}
## The sections the edited variable sits in on the row - written above an earlier member and carried
## down to it, the Inspector's own reading - as {category, group, group_prefix, subgroup}. Shown in the
## section fields, and written back only when the reader changes one.
var _inherited_sections: Dictionary = {}
var _sheet_provider: Callable = Callable()
var _enum_provider: Callable = Callable()
var _scope: String = "global"
## The MEMBER spelling the window opened with ("global" or "tree"), so Instance can put a variable
## back exactly where it came from after a trip through Local.
var _member_scope: String = "global"
var _context: Dictionary = {}
var _is_static: bool = false
## The scope the last variable used, so a fresh one opens there instead of on Instance every time.
var _last_scope_key: String = ""
var _writes_project_global: bool = false
var _refusal_field: String = ""
## The attributes the variable opened with. A key no field of this window edits (a section's end
## line, which side of its section lines the `##` sat) rides through a save untouched.
var _opened_attributes: Dictionary = {}
## The look the window opened on and its detail values, so a look nobody touched keeps its keys.
var _opened_look: Array = ["", {}]
## The detail values typed per look, keyed "look|field", so switching looks and back loses nothing.
var _look_values: Dictionary = {}
## An annotation the file wrote that no look reads (kept verbatim while "As written" is the look).
var _export_hint: String = ""


## Builds the window under parent_node. Must be called before open().
func init_dialog(parent_node: Node) -> void:
	if _dialog != null:
		return
	_dialog = ConfirmationDialog.new()
	_dialog.title = EventSheetL10n.translate("Add variable")
	_dialog.ok_button_text = EventSheetL10n.translate("Add")
	_dialog.visible = false
	_dialog.min_size = Vector2i(int(EventSheetPalette.scaled_f(900.0)), int(EventSheetPalette.scaled_f(600.0)))
	_dialog.confirmed.connect(_on_confirmed)
	_dialog.canceled.connect(_close)
	parent_node.add_child(_dialog)
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	_owner_label = EventSheetPopupUI.hint_label("")
	form.add_child(_owner_label)
	form.add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("Variable"), _build_variable_card()))
	_inspector_card = _build_inspector_card()
	form.add_child(_inspector_card)
	_sections_card = EventSheetPopupUI.titled_card(EventSheetL10n.translate("Where it sits in the Inspector"), _build_sections_card())
	form.add_child(_sections_card)
	_changes_fold = _build_changes_fold()
	form.add_child(_changes_fold)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)
	# The live column, read as you pick: the row and the code (the strip's two reading lines, under
	# whatever is focused) and the Inspector the choices add up to.
	var live: VBoxContainer = EventSheetPopupUI.form_box()
	live.add_child(EventSheetPopupUI.small_caps_label(EventSheetL10n.translate("Live, as you pick")))
	_help_strip = EventSheetPopupUI.help_strip("", "", "", "", 300.0)
	# The code can run long; it wraps inside the column rather than widening the window.
	_help_strip.in_code_value.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	live.add_child(_help_strip)
	_inspector_preview_card = EventSheetInspectorPreviewCard.new()
	live.add_child(_inspector_preview_card)
	var band: BoxContainer = EventSheetPopupUI.responsive_band(scroll, live)
	band.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.6
	_dialog.add_child(EventSheetPopupUI.margined(band))
	_wire_help_strip()


func _build_variable_card() -> VBoxContainer:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	_scope_option = EventSheetPopupUI.described_option()
	for scope_key: String in CHOOSABLE_SCOPES:
		_scope_option.add_item(EventSheetVariableSentence.scope_word(scope_key))
		_scope_option.set_item_metadata(_scope_option.item_count - 1, scope_key)
	_scope_option.item_selected.connect(func(index: int) -> void:
		_apply_scope_key(str(_scope_option.get_item_metadata(index))))
	box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Scope"), _scope_option))
	_global_target_option = OptionButton.new()
	_global_target_row = EventSheetPopupUI.form_row(EventSheetL10n.translate("Write into"), _global_target_option)
	_global_target_row.visible = false
	box.add_child(_global_target_row)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "health"
	_name_edit.text_changed.connect(func(_text: String) -> void:
		_refresh_name_warning()
		_refresh_reading())
	box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Name"), _name_edit))
	_name_warning = EventSheetPopupUI.StateNote.new(380.0)
	box.add_child(_name_warning)
	_type_option = EventSheetPopupUI.described_option()
	_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_type_option.item_selected.connect(func(_index: int) -> void: _on_type_changed())
	var type_box: HBoxContainer = HBoxContainer.new()
	type_box.add_child(_type_option)
	# The list is long; a few letters of a type, of its words or of a class find it.
	_type_search = LineEdit.new()
	_type_search.placeholder_text = EventSheetL10n.translate("Search types…")
	_type_search.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(150.0), 0.0)
	EventSheetCompletionPopup.attach_entries(_type_search, type_search_entries)
	type_box.add_child(_type_search)
	_type_row = EventSheetPopupUI.form_row(EventSheetL10n.translate("Type"), type_box)
	box.add_child(_type_row)
	_class_edit = LineEdit.new()
	_class_edit.placeholder_text = "Node2D, Area2D, EnemyStats…"
	_class_edit.text_changed.connect(func(_text: String) -> void: _refresh_reading())
	EventSheetCompletionPopup.attach(_class_edit, EventSheetCompletions.FIELD_CLASS, Callable())
	_class_row = EventSheetPopupUI.form_row(EventSheetL10n.translate("Class"), _class_edit)
	box.add_child(_class_row)
	box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Initial value"), _build_value_box()))
	_attr_tooltip_edit = LineEdit.new()
	_attr_tooltip_edit.placeholder_text = EventSheetL10n.translate("What it is for - the Inspector tooltip")
	_attr_tooltip_edit.text_changed.connect(func(_text: String) -> void: _refresh_reading())
	box.add_child(_with_label_tile(EventSheetPopupUI.form_row(EventSheetL10n.translate("Description"), _attr_tooltip_edit),
		"Description"))
	var flags: HBoxContainer = HBoxContainer.new()
	flags.add_theme_constant_override("separation", EventSheetPopupUI.ROW_SEPARATION)
	_static_check = _tick(flags, EventSheetL10n.translate("Static"))
	_static_local_check = _tick(flags, EventSheetL10n.translate("Static local"))
	_const_check = _tick(flags, EventSheetL10n.translate("Constant"))
	_const_check.toggled.connect(func(pressed: bool) -> void:
		if pressed:
			_is_static = false
		_apply_scope_gating()
		refresh_scope_selection())
	_static_check.toggled.connect(func(pressed: bool) -> void:
		_is_static = pressed
		if pressed:
			_const_check.set_pressed_no_signal(false)
		_apply_scope_gating()
		refresh_scope_selection())
	flags.add_child(_option_tile("On ready", str(OPTION_BADGES["On ready"])))
	_onready_check = _tick(flags, EventSheetL10n.translate("On ready"))
	_onready_check.toggled.connect(_on_onready_toggled_interactive)
	box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Flags"), flags))
	_sync_option = OptionButton.new()
	_sync_option.item_selected.connect(_on_sync_mode_chosen)
	box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Keep in step"), _sync_option))
	return box


## A tick that refreshes the reading when it changes, parented into `row`.
func _tick(row: Control, words: String) -> CheckBox:
	var tick: CheckBox = CheckBox.new()
	tick.text = words
	tick.toggled.connect(func(_on: bool) -> void: _refresh_reading())
	row.add_child(tick)
	return tick


## The tile the option written `option` puts on the variable's row, made to stand beside it.
func _option_tile(option: String, badge: String) -> Control:
	var tile: Control = VariableMarkTile.new()
	tile.set("badge", badge)
	tile.set("style_provider", _tile_style)
	_mark_tiles[option] = tile
	return tile


## Sets the option's tile at the right end of a form row's label, where the label meets its field: the
## field column stays where every other row has it.
func _with_label_tile(row: HBoxContainer, option: String) -> HBoxContainer:
	var label: Label = row.get_child(0) as Label
	if label == null:
		return row
	var tile: Control = _option_tile(option, str(OPTION_BADGES.get(option, "")))
	label.add_child(tile)
	var side: float = tile.custom_minimum_size.x
	var gap: float = EventSheetPalette.scaled_f(6.0)
	tile.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	tile.offset_left = -side - gap
	tile.offset_right = -gap
	tile.offset_top = -side * 0.5
	tile.offset_bottom = side * 0.5
	return row


## The style the sheet's rows are drawn in, whose tile colours the option tiles wear.
func _tile_style() -> EventSheetEventStyle:
	if style_provider.is_valid():
		return style_provider.call() as EventSheetEventStyle
	return null


## The tile an Inspector look puts on the row: the slider for a look written as `@export_range`, the
## hidden eye for saved-but-hidden, none for any other look. `written_hint` is the annotation the file
## wrote, which the "As written" look keeps.
static func look_badge(look_id: String, written_hint: String = "") -> String:
	var writes: String = written_hint.strip_edges() if look_id == "written" \
		else str(EventSheetInspectorLooks.by_id(look_id).get("writes", ""))
	if writes.begins_with("@export_range("):
		return NativeVariableMarks.BADGE_RANGE
	if writes == "@export_storage":
		return NativeVariableMarks.BADGE_STORAGE
	return ""


## The badge beside each option, by the option's word, as the window shows it now ("" for a tile that
## is hidden).
func option_badges() -> Dictionary:
	var shown: Dictionary = {}
	for option: Variant in _mark_tiles:
		shown[option] = str((_mark_tiles[option] as Control).get("badge"))
	return shown


## The look's tile follows the look in front of the reader, and every tile's card names the variable
## being edited.
func _refresh_mark_tiles() -> void:
	var edited: LocalVariable = _context.get("variable_resource") as LocalVariable
	for option: Variant in _mark_tiles:
		(_mark_tiles[option] as Control).set("variable", edited)
	if _mark_tiles.has(LOOK_OPTION):
		(_mark_tiles[LOOK_OPTION] as Control).set("badge", look_badge(_selected_look_id(), _export_hint))


## The Initial value: the words field, and the editor the Inspector would give the type beside it -
## a tick, a swatch, one field per axis. Each editor writes into the words, which stay the one truth.
func _build_value_box() -> HBoxContainer:
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(6.0)))
	_value_prefix = Label.new()
	_value_prefix.add_theme_color_override("font_color", EventSheetPopupUI.muted_text_color())
	box.add_child(_value_prefix)
	_default_edit = LineEdit.new()
	_default_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_default_edit.text_changed.connect(func(_text: String) -> void:
		_refresh_default_hint()
		_refresh_reading())
	box.add_child(_default_edit)
	# An enum's members and the sheet's functions are offered as the value is typed.
	EventSheetCompletionPopup.attach_entries(_default_edit, func(typed: String) -> Array:
		return Array(_value_suggestions()).filter(func(known: String) -> bool:
			return typed.is_empty() or known.to_lower().contains(typed.to_lower())))
	_bool_check = CheckBox.new()
	_bool_check.toggled.connect(func(on: bool) -> void: _set_value_words("true" if on else "false"))
	box.add_child(_bool_check)
	_color_button = ColorPickerButton.new()
	_color_button.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(60.0), 0.0)
	_color_button.color_changed.connect(func(picked: Color) -> void:
		_set_value_words(SheetCompiler._to_code_literal(picked)))
	box.add_child(_color_button)
	_axis_box = HBoxContainer.new()
	box.add_child(_axis_box)
	_value_note = Label.new()
	_value_note.text = EventSheetL10n.translate("Set in code: Godot has no editor for this type.")
	_value_note.add_theme_color_override("font_color", EventSheetPopupUI.muted_text_color())
	box.add_child(_value_note)
	_items_button = Button.new()
	_items_button.text = EventSheetL10n.translate("Edit items…")
	_items_button.tooltip_text = EventSheetL10n.translate("Edit the items one per line instead of typing a literal.")
	_items_button.pressed.connect(_open_items_editor)
	box.add_child(_items_button)
	# A node or resource slot is filled the way the Inspector fills one - pick the node, load a file
	# or make a new one - each through the editor's own window.
	_slot_buttons = HBoxContainer.new()
	_slot_button(EventSheetL10n.translate("Pick"), EventSheetL10n.translate("Pick a node of this class in the open scene. The variable looks it up when the node is ready (@onready)."), _pick_node)
	_slot_button(EventSheetL10n.translate("Load"), EventSheetL10n.translate("Load a saved resource file of this class (preload)."), _load_resource)
	_slot_button(EventSheetL10n.translate("New"), EventSheetL10n.translate("Make a new resource of this class or one of its kinds (.new())."), _new_resource)
	box.add_child(_slot_buttons)
	_write_type_check = _tick(box, EventSheetL10n.translate("Write the type in code"))
	return box


func _build_inspector_card() -> PanelContainer:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	var head: HBoxContainer = HBoxContainer.new()
	head.add_child(EventSheetPopupUI.section_header(EventSheetL10n.translate("In the Inspector")))
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(_option_tile("Editable in the Inspector", str(OPTION_BADGES["Editable in the Inspector"])))
	_exported_check = CheckBox.new()
	_exported_check.text = EventSheetL10n.translate("Editable in the Inspector")
	_exported_check.toggled.connect(func(_pressed: bool) -> void:
		_update_attr_gating()
		_refresh_reading())
	head.add_child(_exported_check)
	box.add_child(head)
	_look_option = EventSheetPopupUI.described_option()
	_look_option.item_selected.connect(func(_index: int) -> void:
		_rebuild_look_details()
		_refresh_reading())
	# The annotation the chosen look writes sits muted beside it, so the friendly name teaches the code.
	box.add_child(_with_label_tile(EventSheetPopupUI.form_row(EventSheetL10n.translate("Inspector look"),
		EventSheetPopupUI.code_noted_option(_look_option, func(_index: int) -> String: return annotation_text())), LOOK_OPTION))
	var annotation_note: Label = _look_option.get_meta("code_note") as Label
	annotation_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	annotation_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_look_details = VBoxContainer.new()
	_look_details.add_theme_constant_override("separation", EventSheetPopupUI.ROW_SEPARATION)
	box.add_child(_look_details)
	_look_note = EventSheetPopupUI.StateNote.new(380.0)
	box.add_child(_look_note)
	return EventSheetPopupUI.panel_section(box)


func _build_sections_card() -> VBoxContainer:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	# The empty fields say "none": a made-up section name there reads as a value the variable has.
	_category_edit = _section_field(box, EventSheetL10n.translate("Category"), EventSheetL10n.translate("none"), "category")
	_group_edit = _section_field(box, EventSheetL10n.translate("Group"), EventSheetL10n.translate("none"), "group")
	var prefix_row: HBoxContainer = HBoxContainer.new()
	_prefix_check = CheckBox.new()
	_prefix_check.toggled.connect(func(on: bool) -> void:
		if on and _prefix_edit.text.strip_edges().is_empty():
			_prefix_edit.text = suggested_prefix()
		_prefix_edit.editable = on
		_refresh_reading())
	prefix_row.add_child(_prefix_check)
	_prefix_edit = LineEdit.new()
	_prefix_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prefix_edit.placeholder_text = EventSheetL10n.translate("none")
	_prefix_edit.text_changed.connect(func(_text: String) -> void: _refresh_reading())
	prefix_row.add_child(_prefix_edit)
	box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Only names starting"), prefix_row))
	_subgroup_edit = _section_field(box, EventSheetL10n.translate("Subgroup"), EventSheetL10n.translate("none"), "subgroup")
	_prefix_note = EventSheetPopupUI.StateNote.new(380.0)
	box.add_child(_prefix_note)
	return box


## One section field: a line that completes from the sections the sheet already has at `level`.
func _section_field(box: VBoxContainer, label: String, placeholder: String, level: String) -> LineEdit:
	var edit: LineEdit = LineEdit.new()
	edit.placeholder_text = placeholder
	edit.text_changed.connect(func(_text: String) -> void: _refresh_reading())
	EventSheetCompletionPopup.attach_entries(edit, func(typed: String) -> Array:
		return Array(_sheet_sections(level)).filter(func(known: String) -> bool:
			return typed.is_empty() or known.to_lower().contains(typed.to_lower())))
	box.add_child(EventSheetPopupUI.form_row(label, edit))
	return edit


## "When it changes": the wiring to other code - clamp, on changed, show if, lock unless, setter,
## getter - and the Inspector decor that hangs above the field. Folded until something in it is set.
func _build_changes_fold() -> FoldableContainer:
	var fold: FoldableContainer = FoldableContainer.new()
	fold.title = EventSheetL10n.translate("When it changes")
	fold.folded = true
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	for spec: Array in [
		["on_changed", EventSheetL10n.translate("On changed"), EventSheetL10n.translate("a sheet function called after the value is set"), EventSheetCompletions.FIELD_FUNCTION],
		["show_if", EventSheetL10n.translate("Show if"), EventSheetL10n.translate("a bool variable - hidden while it is false"), EventSheetCompletions.FIELD_VARIABLE],
		["group_show_if", EventSheetL10n.translate("Show group if"), EventSheetL10n.translate("a bool variable - hides this with its whole group"), EventSheetCompletions.FIELD_VARIABLE],
		["lock_unless", EventSheetL10n.translate("Lock unless"), EventSheetL10n.translate("a bool variable - read-only while it is false"), EventSheetCompletions.FIELD_VARIABLE],
		["link_with", EventSheetL10n.translate("Link with"), EventSheetL10n.translate("the neighbouring number this one keeps a ratio with"), EventSheetCompletions.FIELD_VARIABLE],
		["validate", EventSheetL10n.translate("Validate with"), EventSheetL10n.translate("a sheet function returning a warning (empty = fine)"), EventSheetCompletions.FIELD_FUNCTION],
		["action", EventSheetL10n.translate("Field button"), EventSheetL10n.translate("function and button words, e.g. reroll_stats Reroll"), EventSheetCompletions.FIELD_FUNCTION],
		["header", EventSheetL10n.translate("Section header"), EventSheetL10n.translate("an accent label above, e.g. Combat #e06666"), ""],
		["info", EventSheetL10n.translate("Info note"), EventSheetL10n.translate("a quiet note panel above the field"), ""],
	]:
		var edit: LineEdit = LineEdit.new()
		edit.placeholder_text = str(spec[2])
		edit.text_changed.connect(func(_text: String) -> void: _refresh_reading())
		if not str(spec[3]).is_empty():
			EventSheetCompletionPopup.attach(edit, str(spec[3]), func() -> Variant: return _sheet())
		edit.set_meta("label", str(spec[1]))
		_changes_edits[spec[0]] = edit
		var change_row: HBoxContainer = EventSheetPopupUI.form_row(str(spec[1]), edit)
		if spec[0] == "show_if":
			_with_label_tile(change_row, "Show if")
		box.add_child(change_row)
	var ticks: HBoxContainer = HBoxContainer.new()
	for spec: Array in [["wait_for_ready", EventSheetL10n.translate("Wait for ready")], ["clamp", EventSheetL10n.translate("Clamp to range")], ["read_only", EventSheetL10n.translate("Read-only")],
			["required", EventSheetL10n.translate("Required")]]:
		_changes_checks[spec[0]] = _tick(ticks, str(spec[1]))
	box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Also"), ticks))
	_refresh_label = Label.new()
	_refresh_label.add_theme_color_override("font_color", EventSheetPopupUI.muted_text_color())
	box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Refresh the Inspector"), _refresh_label))
	_setter_edit = _code_box(box, EventSheetL10n.translate("Setter body"), "health = clampi(value, 0, max_health)")
	_with_label_tile(_setter_edit.get_parent() as HBoxContainer, "Setter body")
	_changes_edits["setter_param"] = LineEdit.new()
	(_changes_edits["setter_param"] as LineEdit).placeholder_text = "value"
	box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Setter parameter"), _changes_edits["setter_param"]))
	_getter_edit = _code_box(box, EventSheetL10n.translate("Getter body"), "return _health")
	fold.add_child(box)
	return fold


func _code_box(box: VBoxContainer, label: String, placeholder: String) -> TextEdit:
	var edit: TextEdit = TextEdit.new()
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(54.0))
	box.add_child(EventSheetPopupUI.form_row(label, edit))
	return edit


## Every field says what it is THROUGH THE STRIP. The dropdowns describe each option as it is
## arrowed over, before it is picked.
func _wire_help_strip() -> void:
	_help_strip.follow_option(_scope_option, _describe_scope_index)
	_help_strip.follow_option(_type_option, _describe_type_index)
	_help_strip.follow_option(_look_option, func(index: int) -> Dictionary:
		return {"heading": EventSheetL10n.translate("Inspector look · %s") % _look_option.get_item_text(index), "body": _look_option.get_item_tooltip(index)})
	for wired: Array in [
		[_name_edit, "Name"], [_default_edit, "Initial value"], [_attr_tooltip_edit, "Description"],
		[_static_check, "Static"], [_static_local_check, "Static local"], [_write_type_check, "Write the type in code"],
		[_onready_check, "On ready"], [_exported_check, "Editable in the Inspector"], [_sync_option, "Keep in step"],
		[_global_target_option, "Write into"], [_class_edit, "Class"], [_category_edit, "Category"],
		[_group_edit, "Group"], [_prefix_edit, "Only names starting"], [_subgroup_edit, "Subgroup"],
	]:
		_help_strip.follow(wired[0] as Control, EventSheetL10n.translate(str(wired[1])), field_help(str(wired[1])))
	# The Constant tick greys out for a type that cannot be frozen, and a greyed tick is exactly what
	# the reader asks the strip about - so its paragraph is worked out when it is reached.
	_help_strip.follow(_const_check, EventSheetL10n.translate("Constant"), field_help("Constant"), _constant_help)


## The paragraph the strip shows for a field, in the editor's language; "" for one the table does
## not carry. The table stays English: it is the key each translation is filed under.
static func field_help(field: String) -> String:
	return EventSheetL10n.translate(str(FIELD_HELP.get(field, "")))


func _constant_help() -> String:
	if _const_check != null and _const_check.disabled and not _supports_constant(_selected_stored_type()):
		return EventSheetL10n.translate("Const is unavailable for Variant variables - GDScript needs a known type to freeze one.")
	return field_help("Constant")


## What each scope means, said twice: `short` is the line under its option, `long` the paragraph
## the help strip shows for it. `{who}` is the object the variable will belong to.
const SCOPE_FACTS: Dictionary = {
	EventSheetVariableSentence.SCOPE_INSTANCE: {
		"short": "one per {who} - each copy in the scene has its own",
		"long": "One per {who}. Every {who} in the scene gets its own; change it on one and the others keep "
			+ "theirs. Pick Global for a value the whole game shares, Local for a value only this event needs."
	},
	EventSheetVariableSentence.SCOPE_LOCAL: {
		"short": "lives inside the event it sits in, and is gone when it ends",
		"long": "Lives inside one event. It is made when the event runs and gone when it ends, so nothing "
			+ "else in the sheet can read it - which is exactly what you want for a working total."
	},
	EventSheetVariableSentence.SCOPE_GLOBAL: {
		"short": "one value the whole project shares - written into an autoload",
		"long": "One value the whole project shares. It lives on an autoload, so every sheet reads it as "
			+ "Game.Score; \"Write into\" says which autoload gets it."
	},
	EventSheetVariableSentence.SCOPE_CONSTANT: {
		"short": "never changes while the game runs",
		"long": "Set here and never changed while the game runs. Use it for the numbers a reader should be "
			+ "able to find in one place - a top speed, a maximum. A constant is never a Static and never "
			+ "an Inspector property."
	},
	EventSheetVariableSentence.SCOPE_STATIC: {
		"short": "one value shared by every {who}, kept between scenes",
		"long": "One value shared by every {who} rather than one each - a count of how many exist, a high "
			+ "score kept while the scene changes. Reading it needs no copy of the object at all."
	}
}


## What a scope means, in the one line that sits under its option.
static func scope_description(scope_key: String, owner: String) -> String:
	return _scope_fact(scope_key, "short", owner)


## The help strip's paragraph for a scope.
static func scope_help(scope_key: String, owner: String) -> String:
	return _scope_fact(scope_key, "long", owner)


static func _scope_fact(scope_key: String, length: String, owner: String) -> String:
	if not (SCOPE_FACTS.get(scope_key) is Dictionary):
		return ""
	var who: String = owner.strip_edges() if not owner.strip_edges().is_empty() else EventSheetL10n.translate("this object")
	return EventSheetL10n.translate(str((SCOPE_FACTS[scope_key] as Dictionary).get(length, ""))).replace("{who}", who)


## The sentence a type's option carries: what it holds, in plain words, in the editor's language.
static func type_description(stored_type: String) -> String:
	for entry: Array in TYPES:
		if str(entry[1]) == stored_type:
			return EventSheetL10n.translate(str(entry[3]))
	return stored_type


## Every type the list offers, in order - for a caller that needs the names alone.
static func type_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for entry: Array in TYPES:
		ids.append(str(entry[1]))
	return ids


## How a type's initial value is edited (see TYPES).
static func value_kind(type_name: String) -> String:
	for entry: Array in TYPES:
		if str(entry[1]) == type_name:
			return str(entry[4])
	if type_name.begins_with("Array") or type_name.begins_with("Dictionary"):
		return "collection"
	if type_name.begins_with("Packed"):
		return "code"
	return "class"


## Adds every type of the table to `option`, under its group's heading: "int · Whole number", with
## the type as the item's metadata and its sentence as the item's hover. The words are translated
## here, as they are shown; the type itself is code and never is.
static func add_type_items(option: OptionButton) -> void:
	var group: String = ""
	for entry: Array in TYPES:
		if str(entry[0]) != group:
			group = str(entry[0])
			option.add_separator(EventSheetL10n.translate(group))
		var index: int = EventSheetPopupUI.add_described_item(option,
			"%s · %s" % [entry[1], EventSheetL10n.translate(str(entry[2]))],
			EventSheetL10n.translate(str(entry[3])), str(entry[1]))
		# Each type wears the icon the Inspector gives it (the editor's own int, Vector2, Node2D...).
		# A class with no icon of its own (Resource) wears its nearest parent's, as the Inspector does.
		var icon_name: String = type_icon_name(str(entry[1]))
		var type_icon: Texture2D = EventSheetEditorIcons.icon(icon_name)
		while type_icon == null and ClassDB.class_exists(icon_name) and not ClassDB.get_parent_class(icon_name).is_empty():
			icon_name = ClassDB.get_parent_class(icon_name)
			type_icon = EventSheetEditorIcons.icon(icon_name)
		if type_icon != null:
			option.set_item_icon(index, type_icon)


## The editor icon a type in the list wears: its own name, with a typed collection's element types
## dropped (`Array[int]` wears Array, `Dictionary[String, int]` wears Dictionary).
static func type_icon_name(type_name: String) -> String:
	return type_name.get_slice("[", 0).strip_edges()


## Fills the type list: the table's groups, then the sheet's own enums, then - when the variable
## opened holds a type the list does not name - that type under "This variable", so nothing is lost.
func _fill_type_option(current: String) -> void:
	_type_option.clear()
	add_type_items(_type_option)
	var enums: PackedStringArray = _enum_names()
	if not enums.is_empty():
		_type_option.add_separator(EventSheetL10n.translate("This sheet's enums"))
		for enum_name: String in enums:
			EventSheetPopupUI.add_described_item(_type_option, EventSheetL10n.translate("%s · One of a named list") % enum_name,
				EventSheetL10n.translate("A value from an enum you declare. The Inspector shows a dropdown of its members, written as declared."), enum_name)
	if not current.is_empty() and _type_index(current) < 0 and _class_entry(current) < 0:
		_type_option.add_separator(EventSheetL10n.translate("This variable"))
		EventSheetPopupUI.add_described_item(_type_option, current, EventSheetL10n.translate("The type this variable already has."), current)


func _type_index(type_name: String) -> int:
	for index: int in range(_type_option.item_count):
		if not _type_option.is_item_separator(index) and str(_type_option.get_item_metadata(index)) == type_name:
			return index
	return -1


## The Node2D or Resource entry a class name belongs under, -1 for a name that is neither.
func _class_entry(type_name: String) -> int:
	match slot_kind(type_name):
		"node":
			return _type_index("Node2D")
		"resource":
			return _type_index("Resource")
	return -1


## "node" or "resource" for a class a slot can hold - Godot's own, or a class_name of the project
## followed up its bases - and "" for anything else.
static func slot_kind(type_name: String) -> String:
	if type_name.is_empty() or type_name.contains("["):
		return ""
	var bases: Dictionary = {}
	for global_class: Dictionary in ProjectSettings.get_global_class_list():
		bases[str(global_class.get("class", ""))] = str(global_class.get("base", ""))
	var base: String = type_name
	for _step: int in range(32):
		if ClassDB.class_exists(base):
			if ClassDB.is_parent_class(base, "Node"):
				return "node"
			return "resource" if ClassDB.is_parent_class(base, "Resource") else ""
		if not bases.has(base):
			return ""
		base = str(bases[base])
	return ""


## "Search types…": every type whose name, words or sentence hold what is typed - the list's own and
## the sheet's enums - then the node and resource classes starting with it, each entry picking itself.
func type_search_entries(typed: String) -> Array:
	var wanted: String = typed.strip_edges().to_lower()
	var found: Array = []
	if wanted.is_empty():
		return found
	for entry: Array in TYPES:
		var words: String = EventSheetL10n.translate(str(entry[2]))
		if ("%s %s %s" % [entry[1], words, EventSheetL10n.translate(str(entry[3]))]).to_lower().contains(wanted):
			found.append(_type_search_entry(str(entry[1]), words))
	for enum_name: String in _enum_names():
		if enum_name.to_lower().contains(wanted):
			found.append(_type_search_entry(enum_name, EventSheetL10n.translate("One of a named list")))
	var classes: PackedStringArray = ClassDB.get_class_list()
	for global_class: Dictionary in ProjectSettings.get_global_class_list():
		classes.append(str(global_class.get("class", "")))
	var listed: PackedStringArray = type_ids()
	var shown: int = 0
	for found_class: String in classes:
		if shown >= 8 or listed.has(found_class) or not found_class.to_lower().begins_with(wanted):
			continue
		var kind: String = slot_kind(found_class)
		if not kind.is_empty():
			found.append(_type_search_entry(found_class, EventSheetL10n.translate("A node in the scene") if kind == "node"
				else EventSheetL10n.translate("A resource file")))
			shown += 1
	# A type whose NAME starts with what was typed leads; one only its words mention follows.
	var named: Array = found.filter(func(entry: Dictionary) -> bool: return str(entry["text"]).to_lower().begins_with(wanted))
	return named + found.filter(func(entry: Dictionary) -> bool: return not named.has(entry))


func _type_search_entry(type_name: String, words: String) -> Dictionary:
	return {"text": "%s · %s" % [type_name, words], "detail": "", "open": func() -> void: pick_type(type_name)}


## Puts the variable on `type_name`; a class lands on its slot with the class written beside it.
func pick_type(type_name: String) -> void:
	_select_stored_type(type_name)
	_type_search.text = ""


## The sheet's enum names, from the enum provider.
func _enum_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	if _enum_provider.is_valid():
		for entry: Variant in (_enum_provider.call() as Array):
			if entry is Dictionary and not str((entry as Dictionary).get("name", "")).is_empty():
				names.append(str((entry as Dictionary).get("name")))
	return names


## The real Godot type the window stores. A node or resource slot is the class typed beside it; an
## @onready lookup's type is typed freely (Variant when left empty).
func _selected_stored_type() -> String:
	var typed_class: String = _class_edit.text.strip_edges() if _class_edit != null else ""
	if _onready_check != null and _onready_check.button_pressed:
		return typed_class if not typed_class.is_empty() else "Variant"
	if _type_option == null or _type_option.selected < 0:
		return "int"
	var stored: String = str(_type_option.get_item_metadata(_type_option.selected))
	if _class_row != null and _class_row.visible and not typed_class.is_empty():
		return typed_class
	return stored


## Selects the entry that stores `type_name` - by METADATA, never by the words on the item. A class
## lands on its Node2D or Resource entry with the class typed in the Class field.
func _select_stored_type(type_name: String) -> void:
	_fill_type_option(type_name)
	var index: int = _type_index(type_name)
	var is_class: bool = index >= 0 and value_kind(type_name) == "class" and not _enum_names().has(type_name)
	if index < 0 and _class_entry(type_name) >= 0:
		index = _class_entry(type_name)
		is_class = true
	_class_edit.text = type_name if is_class else ""
	_type_option.select(index)
	EventSheetPopupUI.follow_description(_type_option)
	_on_type_changed(false)


## A new type: the Class field, the value editor, the Constant tick and the looks all follow it.
func _on_type_changed(reset_class: bool = true) -> void:
	var meta: String = str(_type_option.get_item_metadata(_type_option.selected)) if _type_option.selected >= 0 else ""
	var is_class: bool = value_kind(meta) == "class" and _enum_names().find(meta) < 0
	if reset_class:
		_class_edit.text = meta if is_class else ""
	_class_row.visible = is_class or _onready_check.button_pressed
	_type_row.visible = not _onready_check.button_pressed
	_refresh_value_editor()
	_refresh_const_ui()
	_refresh_default_hint()
	_refresh_looks()
	_update_attr_gating()
	_refresh_reading()


## The kind of editor the current type's value needs (a sheet enum is a pick of its members).
func _current_value_kind() -> String:
	if _onready_check != null and _onready_check.button_pressed:
		return "code"
	var stored: String = _selected_stored_type()
	if _enum_names().has(stored):
		return "enum"
	# Any type reads its field as text, but a row the file wrote with code for its value
	# (`var tint = Color.WHITE`) is code: read as text, OK would quote it into a String.
	if stored == "Variant" and _context.get("variable_resource") is LocalVariable \
			and (_context["variable_resource"] as LocalVariable).expression_default:
		return "code"
	var meta: String = str(_type_option.get_item_metadata(_type_option.selected)) if _type_option.selected >= 0 else stored
	return value_kind(meta)


## Shows the value editor the type wants, and loads the words into it.
func _refresh_value_editor() -> void:
	var kind: String = _current_value_kind()
	var words: String = _default_edit.text.strip_edges()
	_value_prefix.text = {"string_name": "&\"", "node_path": "^\""}.get(kind, "")
	_value_prefix.visible = not _value_prefix.text.is_empty()
	_default_edit.visible = not (kind in ["bool", "color", "vector", "none"])
	_bool_check.visible = kind == "bool"
	_bool_check.set_pressed_no_signal(words.to_lower() in ["true", "1", "yes"])
	_bool_check.text = "true" if _bool_check.button_pressed else "false"
	_color_button.visible = kind == "color"
	var parsed_color: Variant = _parse_default("Color", words) if kind == "color" else null
	if parsed_color is Color:
		_color_button.color = parsed_color
	_value_note.visible = kind == "none"
	_items_button.visible = kind == "collection"
	var slot: String = slot_kind(_selected_stored_type()) if kind == "class" or _onready_check.button_pressed else ""
	_slot_buttons.get_child(0).visible = slot == "node" and _scope == "tree"
	_slot_buttons.get_child(1).visible = slot == "resource"
	_slot_buttons.get_child(2).visible = slot == "resource"
	_rebuild_axes(kind)
	var placeholders: Dictionary = {"class": EventSheetL10n.translate("(set in the Inspector)"), "callable": "_bake", "enum": "Kind.ROUND",
		"code": "%s()" % _selected_stored_type(), "collection": "{\"key\": 1}" if _selected_stored_type().begins_with("Dictionary") else "[1, 2, 3]"}
	_default_edit.placeholder_text = "$Player or get_node(\"UI/Score\")" if _onready_check.button_pressed \
		else str(placeholders.get(kind, "0" if kind == "number" else ""))


## One field per axis for a vector type, coloured like the editor's own, composing back to the
## constructor in the words field.
func _rebuild_axes(kind: String) -> void:
	for old: Node in _axis_box.get_children():
		_axis_box.remove_child(old)
		old.queue_free()
	_axis_box.visible = kind == "vector"
	if kind != "vector":
		return
	var type_name: String = _selected_stored_type()
	var count: int = int(type_name.substr(6, 1))
	var parsed: Variant = _parse_default(type_name, _default_edit.text)
	var edits: Array[LineEdit] = []
	for axis: int in range(count):
		var letter: Label = Label.new()
		letter.text = "xyzw"[axis]
		letter.add_theme_color_override("font_color", AXIS_COLORS[axis])
		_axis_box.add_child(letter)
		var edit: LineEdit = LineEdit.new()
		edit.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(52.0), 0.0)
		edit.text = str(parsed[axis]) if parsed != null and typeof(parsed) != TYPE_STRING else "0"
		_axis_box.add_child(edit)
		edits.append(edit)
	for edit: LineEdit in edits:
		edit.text_changed.connect(func(_text: String) -> void:
			var parts: PackedStringArray = PackedStringArray()
			for each: LineEdit in edits:
				parts.append(each.text.strip_edges() if not each.text.strip_edges().is_empty() else "0")
			_set_value_words("%s(%s)" % [type_name, ", ".join(parts)]))


func _slot_button(words: String, tip: String, action: Callable) -> void:
	var button: Button = Button.new()
	button.text = words
	button.tooltip_text = tip
	button.pressed.connect(action)
	_slot_buttons.add_child(button)


static func _editor() -> Object:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		return Engine.get_singleton("EditorInterface")
	return null


func _pick_node() -> void:
	if _editor() != null:
		_editor().popup_node_selector(_on_node_picked, [StringName(_selected_stored_type())])


func _load_resource() -> void:
	if _editor() != null:
		_editor().popup_quick_open(_on_resource_loaded, [StringName(_selected_stored_type())])


func _new_resource() -> void:
	if _editor() != null:
		_editor().popup_create_dialog(_on_resource_created, StringName(_selected_stored_type()), "",
			EventSheetL10n.translate("New resource"), [])


## A node picked in the open scene: the value is its lookup ($Muzzle), which only resolves once this
## node is in the scene, so On ready is ticked with it.
func _on_node_picked(path: NodePath) -> void:
	var text: String = str(path)
	if text.is_empty():
		return
	var plain: bool = true
	for part: String in text.split("/"):
		plain = plain and part.is_valid_identifier()
	if not _onready_check.button_pressed:
		_onready_check.button_pressed = true
	_set_value_words("$%s" % text if plain else "get_node(\"%s\")" % text.c_escape())


func _on_resource_loaded(path: String) -> void:
	if not path.is_empty():
		_set_value_words("preload(\"%s\")" % path)


func _on_resource_created(type_name: String) -> void:
	if not type_name.is_empty():
		_set_value_words("%s.new()" % type_name)


## What the value field offers for the type in front of it: an enum's members, written as
## `Kind.ROUND`, or the sheet's functions for a Callable.
func _value_suggestions() -> PackedStringArray:
	var offered: PackedStringArray = PackedStringArray()
	match _current_value_kind():
		"enum":
			var enum_name: String = _selected_stored_type()
			for entry: Variant in (_enum_provider.call() as Array if _enum_provider.is_valid() else []):
				if entry is Dictionary and str((entry as Dictionary).get("name", "")) == enum_name:
					for member: Variant in (entry as Dictionary).get("members", []):
						offered.append("%s.%s" % [enum_name, str(member).get_slice("=", 0).strip_edges()])
		"callable":
			var sheet: EventSheetResource = _sheet()
			for entry: Variant in (sheet.functions if sheet != null else []):
				if entry is EventFunction:
					offered.append((entry as EventFunction).function_name)
	return offered


## Writes a value editor's answer into the words field, quietly, and refreshes what reads it.
func _set_value_words(words: String) -> void:
	_default_edit.text = words
	_bool_check.text = "true" if _bool_check.button_pressed else "false"
	_refresh_default_hint()
	_refresh_reading()


## The value as the code will write it: a StringName or NodePath gets its prefix and quotes back.
func _value_text() -> String:
	var words: String = _default_edit.text.strip_edges()
	match _current_value_kind():
		"string_name", "node_path":
			if not words.begins_with("&\"") and not words.begins_with("^\""):
				return "%s%s\"" % [_value_prefix.text, words.trim_prefix("\"").trim_suffix("\"")]
		"none":
			return ""
	return words


## Loads saved value words into the field, without a StringName's or NodePath's prefix and quotes.
func _show_value(words: String) -> void:
	_default_edit.text = words
	if _current_value_kind() in ["string_name", "node_path"] and (words.begins_with("&\"") or words.begins_with("^\"")):
		_default_edit.text = words.substr(2).trim_suffix("\"")
	_refresh_value_editor()


## The looks the current type can wear, the plain one first; the selection is kept when it still applies.
func _refresh_looks() -> void:
	var previous: String = _selected_look_id()
	var type_name: String = _selected_stored_type()
	_look_option.clear()
	EventSheetPopupUI.add_described_item(_look_option, EventSheetInspectorLooks.plain_label(type_name),
		"%s\n%s" % [EventSheetL10n.translate("The Inspector shows the type's own editor."), EventSheetL10n.translate("Writes %s") % "@export"], "")
	if not _export_hint.is_empty():
		EventSheetPopupUI.add_described_item(_look_option, EventSheetL10n.translate("As written"),
			"%s\n%s" % [EventSheetL10n.translate("Keeps the annotation the file wrote."), EventSheetL10n.translate("Writes %s") % _export_hint], "written")
	for look: Dictionary in EventSheetInspectorLooks.for_type(type_name):
		EventSheetPopupUI.add_described_item(_look_option, EventSheetInspectorLooks.label(look), EventSheetInspectorLooks.description(look),
			str(look.get("id")))
	_select_look(previous)
	_rebuild_look_details()


func _select_look(look_id: String) -> void:
	for index: int in range(_look_option.item_count):
		if str(_look_option.get_item_metadata(index)) == look_id:
			_look_option.select(index)
			EventSheetPopupUI.follow_description(_look_option)
			return
	_look_option.select(0)
	EventSheetPopupUI.follow_description(_look_option)


func _selected_look_id() -> String:
	if _look_option == null or _look_option.selected < 0:
		return ""
	return str(_look_option.get_item_metadata(_look_option.selected))


## The chosen look's detail fields, each remembering what was typed into it for this look.
func _rebuild_look_details() -> void:
	for old: Node in _look_details.get_children():
		_look_details.remove_child(old)
		old.queue_free()
	var look_id: String = _selected_look_id()
	_refresh_write_type()
	for field: Array in EventSheetInspectorLooks.by_id(look_id).get("fields", []):
		var key: String = "%s|%s" % [look_id, field[0]]
		var value: Variant = _look_values.get(key, field[3])
		var control: Control = null
		match str(field[2]):
			"tick":
				var tick: CheckBox = CheckBox.new()
				tick.text = EventSheetL10n.translate(str(field[4]))
				tick.button_pressed = bool(value)
				tick.toggled.connect(func(on: bool) -> void: _set_look_value(key, on))
				control = tick
			"pick":
				# The choice is the value the look folds; the words on it are the editor's language.
				var pick: OptionButton = OptionButton.new()
				for choice: Variant in field[4]:
					pick.add_item(EventSheetL10n.translate(str(choice)))
					pick.set_item_metadata(pick.item_count - 1, str(choice))
					if str(choice) == str(value):
						pick.select(pick.item_count - 1)
				pick.item_selected.connect(func(index: int) -> void: _set_look_value(key, str(pick.get_item_metadata(index))))
				control = pick
			_:
				var edit: LineEdit = LineEdit.new()
				edit.text = str(value)
				edit.placeholder_text = EventSheetL10n.translate(str(field[4])) if field.size() > 4 else ""
				edit.text_changed.connect(func(typed: String) -> void: _set_look_value(key, typed))
				control = edit
		_look_details.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate(str(field[1])), control))
	_refresh_look_note()


## A row among the events may leave its type out - but not an @onready lookup, which implies none,
## nor an Inspector button, which Godot spells without one.
func _refresh_write_type() -> void:
	_write_type_check.visible = _scope == "tree" and not _onready_check.button_pressed and _selected_look_id() != "tool_button"


func _set_look_value(key: String, value: Variant) -> void:
	_look_values[key] = value
	_refresh_look_note()
	_refresh_reading()


## The values typed into the chosen look's fields (its defaults where nothing was typed).
func _look_field_values(look_id: String) -> Dictionary:
	var values: Dictionary = {}
	for field: Array in EventSheetInspectorLooks.by_id(look_id).get("fields", []):
		values[field[0]] = _look_values.get("%s|%s" % [look_id, field[0]], field[3])
	var args_key: String = "%s|args" % look_id
	if _look_values.has(args_key):
		values["args"] = _look_values[args_key]
	return values


## An Inspector button's icon is checked against the editor's own theme, so a name the editor does
## not have is caught here rather than as a blank button.
func _refresh_look_note() -> void:
	var icon: String = str(_look_values.get("tool_button|icon", "")).strip_edges()
	var missing: bool = _selected_look_id() == "tool_button" and not icon.is_empty() \
		and Engine.is_editor_hint() and EventSheetPopupUI._editor_icon(icon) == null
	_look_note.say(EventSheetL10n.translate("The editor has no icon called %s, so the button would show none.") % icon if missing else "",
		EventSheetPopupUI.TONE_WARNING)


## The attributes the window's fields add up to. `for_preview` skips the checks a confirm makes.
func _collect_attributes(type_name: String) -> Dictionary:
	var attributes: Dictionary = {}
	for key: Variant in _opened_attributes:
		if not _owned_keys().has(str(key)):
			attributes[key] = _opened_attributes[key]
	var description: String = _attr_tooltip_edit.text.strip_edges()
	if not description.is_empty():
		attributes["tooltip"] = description
	var look_id: String = _selected_look_id()
	if not look_id in ["", "written"]:
		var folded: Dictionary = EventSheetInspectorLooks.fold(look_id, _look_field_values(look_id), type_name)
		folded.erase("options")
		if folded.get("table_columns") is Array:
			EventSheetInspectorLooks.carry_column_notes(folded["table_columns"], _opened_attributes.get("table_columns"))
		attributes.merge(folded, true)
	# The look it opened with, its details untouched: the keys it opened with keep the file's own
	# spelling (a step left to Godot, `"exp", "hide_slider"` together) over the look's rebuild of them.
	if look_id == str(_opened_look[0]) and _look_field_values(look_id) == _opened_look[1]:
		for key: String in EventSheetInspectorLooks.look_keys():
			if _opened_attributes.has(key):
				attributes[key] = _opened_attributes[key]
	for level: Array in [["category", _category_edit], ["group", _group_edit], ["subgroup", _subgroup_edit]]:
		var words: String = (level[1] as LineEdit).text.strip_edges()
		# A section the variable only sits in - written above an earlier member - is the field's words
		# but not this variable's line: writing it would add a second section line above it.
		if words == str(_inherited_sections.get(level[0], "")) and not _opened_attributes.has(level[0]):
			continue
		if not words.is_empty():
			attributes[level[0]] = words
	if _prefix_check.button_pressed and attributes.has("group") and not _prefix_edit.text.strip_edges().is_empty():
		attributes["group_prefix"] = _prefix_edit.text.strip_edges()
	# Two opened keys no field shows ride through only while they still mean something: a subgroup's
	# prefix needs its subgroup, and the end of a group above the variable is gone once it sits in one.
	if not attributes.has("subgroup"):
		attributes.erase("subgroup_prefix")
	if attributes.has("group"):
		attributes.erase("group_end")
	for key: String in ["on_changed", "show_if", "group_show_if", "lock_unless", "link_with", "validate", "info"]:
		var words: String = (_changes_edits[key] as LineEdit).text.strip_edges()
		if not words.is_empty():
			attributes[key] = words
	attributes.merge(_decor_split(), true)
	for key: String in ["wait_for_ready", "read_only", "required"]:
		if (_changes_checks[key] as CheckBox).button_pressed:
			attributes[key] = true
	if (_changes_checks["clamp"] as CheckBox).button_pressed and type_name in ["int", "float"]:
		attributes["clamp"] = true
	var setter_body: String = _setter_edit.text.strip_edges()
	if not setter_body.is_empty():
		attributes["setter_body"] = setter_body
		var param: String = (_changes_edits["setter_param"] as LineEdit).text.strip_edges()
		attributes["setter_param"] = param if not param.is_empty() else "value"
	if not _getter_edit.text.strip_edges().is_empty():
		attributes["getter_body"] = _getter_edit.text.strip_edges()
	return attributes


## Every attribute key a field of this window writes; the rest of what a variable opened with rides
## through untouched.
static func _owned_keys() -> PackedStringArray:
	var owned: PackedStringArray = EventSheetInspectorLooks.look_keys()
	owned.append_array(["tooltip", "category", "group", "group_prefix", "subgroup", "on_changed", "show_if",
		"group_show_if", "lock_unless", "link_with", "validate", "action", "action_label", "header", "header_color",
		"info", "wait_for_ready", "read_only", "required", "clamp", "setter_body", "setter_param", "getter_body"])
	return owned


## The Section header field's trailing #rrggbb accent and the Field button's words, split into the
## keys the compiler reads.
func _decor_split() -> Dictionary:
	var decor: Dictionary = {}
	var header: String = (_changes_edits["header"] as LineEdit).text.strip_edges()
	var last: String = header.get_slice(" ", header.get_slice_count(" ") - 1)
	if header.contains(" ") and last.length() == 7 and last.begins_with("#") and last.substr(1).is_valid_hex_number():
		decor["header_color"] = last
		header = header.trim_suffix(last).strip_edges()
	if not header.is_empty():
		decor["header"] = header
	var action: String = (_changes_edits["action"] as LineEdit).text.strip_edges()
	var function_name: String = action.get_slice(" ", 0)
	if function_name.is_valid_identifier():
		decor["action"] = function_name
		if not action.substr(function_name.length()).strip_edges().is_empty():
			decor["action_label"] = action.substr(function_name.length()).strip_edges()
	return decor


## Opens the window to add a variable. A fresh one opens on the scope the last one used.
func open(scope: String) -> void:
	open_for_edit(scope, {}, "", "int", "", false, "Create Variable", false, false)
	if not _last_scope_key.is_empty():
		_apply_scope_key(_last_scope_key)


func open_for_edit(
	scope: String,
	context: Dictionary = {},
	name: String = "",
	type_name: String = "int",
	default_value: Variant = "",
	lock_type: bool = false,
	title: String = "Edit Variable",
	is_constant: bool = false,
	exported: bool = true,
	onready: bool = false,
	is_static: bool = false
) -> void:
	if _dialog == null:
		push_error("VariableDialog.open() called before init_dialog().")
		return
	_is_static = is_static and not is_constant
	# The dropdown speaks the sheet's reading words; `_scope` is where the variable is STORED, and an
	# Instance variable is stored in the sheet's own variables.
	_scope = "global" if scope == EventSheetVariableSentence.SCOPE_INSTANCE else scope
	_writes_project_global = false
	if _scope != "local":
		_member_scope = _scope
	_context = context.duplicate(true)
	var is_editing: bool = bool(context.get("editing", false))
	_dialog.title = EventSheetL10n.translate("Edit variable") if is_editing else EventSheetL10n.translate("Add variable")
	_dialog.ok_button_text = EventSheetL10n.translate("Save") if is_editing else EventSheetL10n.translate("Add")
	var owner_group: EventGroup = _context.get("group") as EventGroup
	var owner: String = _owner_name()
	if owner_group != null:
		_owner_label.text = EventSheetL10n.translate("in group %s") % EventSheetGroupFacts.display_name(owner_group)
	else:
		_owner_label.text = (EventSheetL10n.translate("to %s") % owner) if not owner.is_empty() else ""
	_owner_label.visible = not _owner_label.text.is_empty()
	_refresh_scope_descriptions()
	_refresh_global_targets()
	var attributes: Dictionary = context.get("attributes") if context.get("attributes") is Dictionary else {}
	_opened_attributes = attributes.duplicate(true)
	_export_hint = str(context.get("export_hint", "")).strip_edges()
	_look_values.clear()
	_name_edit.text = name
	var is_tree: bool = _scope == "tree"
	_onready_check.set_pressed_no_signal(onready and is_tree)
	_default_edit.text = EventSheetVariableOwners.default_text(default_value)
	_type_search.text = ""
	_select_stored_type(type_name)
	_show_value(EventSheetVariableOwners.default_text(default_value))
	_context["opened_words"] = _default_edit.text
	_const_check.set_pressed_no_signal(is_constant)
	# A row placed among the events can be written with or without its type; the tick says which, and
	# names the type it writes. A sheet-level variable always writes one, so it is not asked.
	var inferred_type: String = str(context.get("inferred_type", ""))
	_write_type_check.text = EventSheetL10n.translate("Write the type in code (: %s)") % (inferred_type if not inferred_type.is_empty() else type_name)
	_write_type_check.set_pressed_no_signal(inferred_type.is_empty())
	_context["written_untyped"] = not inferred_type.is_empty()
	var is_local: bool = _scope == "local"
	_static_local_check.set_pressed_no_signal(is_local and bool(context.get("static_local", false)))
	_exported_check.set_pressed_no_signal(exported and not is_local and not onready)
	_attr_tooltip_edit.text = str(attributes.get("tooltip", ""))
	_category_edit.text = str(attributes.get("category", ""))
	_group_edit.text = str(attributes.get("group", ""))
	_subgroup_edit.text = str(attributes.get("subgroup", ""))
	_prefix_edit.text = str(attributes.get("group_prefix", ""))
	# A member under an earlier member's section line sits in that section all the same, so its fields
	# say the section it is in rather than opening empty.
	_inherited_sections = {}
	var edited_variable: LocalVariable = context.get("variable_resource") as LocalVariable
	if is_editing and edited_variable != null and _sheet() != null:
		_inherited_sections = inherited_sections(_sheet().events, edited_variable)
	for level: Array in [["category", _category_edit], ["group", _group_edit], ["subgroup", _subgroup_edit]]:
		if (level[1] as LineEdit).text.strip_edges().is_empty():
			(level[1] as LineEdit).text = str(_inherited_sections.get(level[0], ""))
	if _prefix_edit.text.is_empty() and not attributes.has("group"):
		_prefix_edit.text = str(_inherited_sections.get("group_prefix", ""))
	_prefix_check.set_pressed_no_signal(not _prefix_edit.text.is_empty())
	_prefix_edit.editable = _prefix_check.button_pressed
	for key: String in ["on_changed", "show_if", "group_show_if", "lock_unless", "link_with", "validate", "info"]:
		(_changes_edits[key] as LineEdit).text = str(attributes.get(key, ""))
	(_changes_edits["header"] as LineEdit).text = ("%s %s" % [attributes.get("header", ""), attributes.get("header_color", "")]).strip_edges()
	(_changes_edits["action"] as LineEdit).text = ("%s %s" % [attributes.get("action", ""), attributes.get("action_label", "")]).strip_edges()
	(_changes_edits["setter_param"] as LineEdit).text = str(attributes.get("setter_param", ""))
	_setter_edit.text = str(attributes.get("setter_body", ""))
	_getter_edit.text = str(attributes.get("getter_body", ""))
	for key: String in _changes_checks:
		(_changes_checks[key] as CheckBox).set_pressed_no_signal(bool(attributes.get(key, false)))
	var changes_used: bool = false
	for key: String in ["on_changed", "show_if", "group_show_if", "lock_unless", "link_with", "validate", "action",
			"header", "info", "setter_body", "getter_body", "wait_for_ready", "clamp", "read_only", "required"]:
		changes_used = changes_used or attributes.has(key)
	_changes_fold.folded = not changes_used
	# The look the variable was saved with, and its details, come back from its attributes.
	var unfolded: Array = EventSheetInspectorLooks.unfold(attributes, PackedStringArray(context.get("options", [])))
	# A Big text box a file wrote is kept as its annotation; it is the look of that name all the same.
	if _export_hint == "@export_multiline" and str(unfolded[0]).is_empty():
		unfolded = ["multiline", {}]
		_export_hint = ""
	for key: Variant in (unfolded[1] as Dictionary):
		_look_values["%s|%s" % [unfolded[0], key]] = (unfolded[1] as Dictionary)[key]
	_refresh_looks()
	_select_look("written" if not _export_hint.is_empty() and str(unfolded[0]).is_empty() else str(unfolded[0]))
	_rebuild_look_details()
	_opened_look = [_selected_look_id(), _look_field_values(_selected_look_id())]
	_refresh_sync_option()
	_type_option.disabled = lock_type
	_apply_onready_state(_onready_check.button_pressed)
	_apply_scope_gating()
	refresh_scope_selection()
	_refresh_name_warning()
	_refusal_field = ""
	if lock_type:
		_help_strip.show_note(EventSheetL10n.translate("Type"), EventSheetL10n.translate("Type is locked because this variable is already in use."),
			EventSheetPopupUI.HelpStrip.TONE_WARNING)
	else:
		var opening: Dictionary = _describe_scope_index(_scope_option.selected)
		_help_strip.show_note(str(opening.get("heading", "")), str(opening.get("body", "")))
	_refresh_reading()
	if _dialog.is_inside_tree():
		_dialog.popup_centered()
		_name_edit.grab_focus()
		_name_edit.select_all()


## Turns the open window to the part a door promised - "look", the look's "details" or the "group"
## field - on `look_id` when one is named, and returns the control it focuses.
func focus_part(part: String, look_id: String = "") -> Control:
	if not look_id.is_empty() and not _exported_check.disabled:
		_exported_check.button_pressed = true
		_select_look(look_id)
		_rebuild_look_details()
		_refresh_reading()
	var target: Control = _group_edit if part == "group" else _look_option
	if part == "details":
		for row: Node in _look_details.get_children():
			var field: Control = row.get_child(row.get_child_count() - 1) as Control
			if field is LineEdit:
				target = field
				break
	if target.is_inside_tree():
		target.call_deferred("grab_focus")
	return target


func _close() -> void:
	if _dialog != null:
		_dialog.hide()


func _on_confirmed() -> void:
	var var_name: String = _name_edit.text.strip_edges()
	if var_name.is_empty():
		return
	# A name that shadows a host-class member breaks the generated script: refuse it.
	var shadow_owner: String = _shadow_owner(var_name)
	if not shadow_owner.is_empty():
		_name_warning.say(EventSheetL10n.translate("✗ \"%s\" shadows a %s member - pick another name.") % [var_name, shadow_owner])
		_reopen()
		return
	_last_scope_key = current_scope_word()
	_context["static_local"] = static_local_wanted()
	var type_name: String = _selected_stored_type()
	if _writes_project_global:
		project_global_requested.emit(var_name, type_name, _value_text(), selected_global_target())
		return
	# @onready: the value is an expression looked up when the node is ready, never a literal.
	if _onready_check.button_pressed and _scope == "tree":
		if _value_text().is_empty():
			_refuse("Initial value", EventSheetL10n.translate("@onready needs an expression (e.g. $Player or get_node(\"UI/Score\"))."))
			return
		variable_confirmed.emit(var_name, type_name, _value_text(), _scope, _context.duplicate(true), false, false, PackedStringArray(), {}, true, false)
		return
	var verdict: Dictionary = validate_default(type_name, _value_text())
	if not bool(verdict.get("ok", true)):
		_refuse("Initial value", str(verdict.get("error", "")))
		return
	var editing_resource: Variant = _context.get("variable_resource", null)
	if editing_resource is LocalVariable and (editing_resource as LocalVariable).inferred_type \
			and not (_write_type_check.visible and _write_type_check.button_pressed):
		var inferred_refusal: String = inferred_value_refusal(str(_context.get("inferred_type", "")), _value_text())
		if not inferred_refusal.is_empty():
			_refuse("Initial value", inferred_refusal)
			return
	var value_is_code: bool = _current_value_kind() in CODE_KINDS and not _value_text().is_empty()
	var empty_code: bool = _current_value_kind() in CODE_KINDS and not value_is_code
	var default_value: Variant = _value_text() if value_is_code else (null if empty_code else _parse_default(type_name, _value_text()))
	# A value nobody touched keeps the file's own spelling (`null`, `1e3`, `Vector2(1, 2)`,
	# `1.5 # seconds`) rather than the window's reading of it, which can differ in more than looks.
	if editing_resource is LocalVariable and type_name == (editing_resource as LocalVariable).type_name \
			and _default_edit.text == str(_context.get("opened_words", "")):
		value_is_code = (editing_resource as LocalVariable).expression_default
		default_value = (editing_resource as LocalVariable).default_value
	var attributes: Dictionary = _collect_attributes(type_name)
	var look_id: String = _selected_look_id()
	var combo_options: PackedStringArray = PackedStringArray()
	if look_id == "choices" and type_name == "String":
		combo_options = PackedStringArray(EventSheetInspectorLooks.fold(look_id, _look_field_values(look_id), type_name).get("options", []))
		if str(default_value).strip_edges().is_empty() and not combo_options.is_empty():
			default_value = combo_options[0]
		elif not combo_options.is_empty() and not combo_options.has(str(default_value)):
			_refuse("Initial value", EventSheetL10n.translate("The initial value must be one of the choices (%s).") % ", ".join(combo_options))
			return
	for key: String in ["on_changed", "show_if", "group_show_if", "lock_unless", "link_with"]:
		if attributes.has(key) and not EventSheetIdentifierRules.is_valid(str(attributes[key])):
			var field: String = str((_changes_edits[key] as LineEdit).get_meta("label", key))
			_refuse(field, EventSheetL10n.translate("%s takes a single identifier (a variable or function name).") % field)
			return
	if bool(attributes.get("clamp", false)) and not attributes.get("range") is Dictionary:
		_refuse(EventSheetL10n.translate("Clamp to range"), EventSheetL10n.translate("Clamp needs a slider look (a min and a max) to clamp to."))
		return
	var is_constant: bool = _const_check.button_pressed and _supports_constant(type_name)
	var exported: bool = _exported_check.button_pressed and not _exported_check.disabled
	_context["default_text"] = _value_text()
	_context["value_is_code"] = value_is_code
	_context["write_type"] = _write_type_check.visible and _write_type_check.button_pressed and bool(_context.get("written_untyped", false))
	_context["untyped"] = _write_type_check.visible and not _write_type_check.button_pressed
	_context["export_hint"] = _export_hint if look_id == "written" else ""
	variable_confirmed.emit(var_name, type_name, default_value, _scope, _context.duplicate(true), is_constant, exported,
		combo_options, attributes, false, _is_static and not is_constant)


## A refusal, said in the ONE strip, with the window back up and everything typed still in it.
func _refuse(field: String, reason: String) -> void:
	_say_refusal(field, reason)
	_reopen()


func _reopen() -> void:
	if _dialog.is_inside_tree():
		_dialog.call_deferred("popup_centered")


func _say_refusal(field: String, reason: String) -> void:
	_refusal_field = field
	_help_strip.show_note(EventSheetL10n.translate(field), reason, EventSheetPopupUI.HelpStrip.TONE_ERROR)


## Takes a refusal back once the field it was about is fixed; a no-op for any other field.
func _clear_refusal(field: String) -> void:
	if _refusal_field != field or _help_strip.tone != EventSheetPopupUI.HelpStrip.TONE_ERROR:
		return
	_refusal_field = ""
	_help_strip.show_note(EventSheetL10n.translate(field), field_help(field))


## Returns the trimmed text from the name field.
func get_last_name_text() -> String:
	return _name_edit.text.strip_edges() if _name_edit != null else ""


## Parses a comma-separated choices text ("a, b, c").
static func parse_options(raw: String) -> PackedStringArray:
	return PackedStringArray(EventSheetInspectorLooks.split_list(raw))


static func _parse_default(type_name: String, raw: String) -> Variant:
	var value: String = raw.strip_edges()
	if is_collection_type(type_name):
		var parsed: Variant = str_to_var(value) if not value.is_empty() else null
		if parsed is Array or parsed is Dictionary:
			return parsed
		return {} if type_name.begins_with("Dictionary") else []
	match type_name:
		"int":
			return int(value) if not value.is_empty() else 0
		"float":
			return float(value) if not value.is_empty() else 0.0
		"bool":
			return value.to_lower() in ["true", "1", "yes"]
		"String", "Variant":
			return value
		"Color":
			if value.begins_with("#"):
				return Color.from_string(value, Color.WHITE)
			var rgba: PackedStringArray = value.split(",")
			if not value.begins_with("Color(") and rgba.size() >= 3:
				return Color(rgba[0].to_float(), rgba[1].to_float(), rgba[2].to_float(), rgba[3].to_float() if rgba.size() >= 4 else 1.0)
			var literal_color: Variant = str_to_var(value)
			return literal_color if literal_color is Color else Color.WHITE
		"Texture2D", "Curve", "Gradient":
			return null
	if type_name.begins_with("Vector"):
		var vector: Variant = str_to_var(value) if value.begins_with(type_name + "(") else null
		var zero: Variant = type_convert(null, _variant_type(type_name))
		if vector != null and typeof(vector) == typeof(zero):
			return vector
		# "x, y" typed bare is the vector of those numbers; one number in a Vector4 is all four corners.
		var parts: PackedStringArray = value.split(",")
		var size: int = int(type_name.substr(6, 1))
		if parts.size() == 1 and size == 4 and not value.is_empty():
			parts = PackedStringArray([value, value, value, value])
		if parts.size() != size:
			return zero
		return str_to_var("%s(%s)" % [type_name, ", ".join(parts)])
	return value


static func _variant_type(type_name: String) -> int:
	for type_index: int in range(TYPE_MAX):
		if type_string(type_index) == type_name:
			return type_index
	return TYPE_NIL


static func is_collection_type(type_name: String) -> bool:
	return type_name.begins_with("Array") or type_name.begins_with("Dictionary")


## Validates a value text against the chosen type ({ok, error}). Collections must be GDScript
## literals of the right container kind; typed containers also check builtin element types.
static func validate_default(type_name: String, raw: String) -> Dictionary:
	var value: String = raw.strip_edges()
	if not is_collection_type(type_name) or value.is_empty():
		return {"ok": true, "error": ""}
	var parsed: Variant = str_to_var(value)
	var wants_dictionary: bool = type_name.begins_with("Dictionary")
	if parsed == null or (wants_dictionary and not (parsed is Dictionary)) or (not wants_dictionary and not (parsed is Array)):
		return {"ok": false, "error": EventSheetL10n.translate("Not a valid %s literal - e.g. %s") % [
			"Dictionary" if wants_dictionary else "Array", "{\"key\": 1}" if wants_dictionary else "[1, 2, 3]"]}
	var element_type: String = ""
	if type_name.contains("[") and type_name.ends_with("]"):
		var inner: String = type_name.get_slice("[", 1).trim_suffix("]")
		element_type = inner.get_slice(",", 1).strip_edges() if wants_dictionary else inner.strip_edges()
	var scalar_checks: Dictionary = {"int": TYPE_INT, "float": TYPE_FLOAT, "String": TYPE_STRING, "bool": TYPE_BOOL}
	if scalar_checks.has(element_type):
		var expected_type: int = int(scalar_checks[element_type])
		var values: Array = (parsed as Dictionary).values() if wants_dictionary else (parsed as Array)
		for element: Variant in values:
			if typeof(element) == TYPE_INT and expected_type == TYPE_FLOAT:
				continue
			if typeof(element) != expected_type:
				return {"ok": false, "error": EventSheetL10n.translate("Element %s is not %s (declared %s).") % [str(element), element_type, type_name]}
	return {"ok": true, "error": ""}


## A `var hp := 100` keeps its value as the words the file wrote and Godot infers the type from them,
## so new words must still infer the same type - or the line quietly changes what the variable is, or
## (a typo) stops compiling. "" when the words are fine. Ticking "Write the type in code" lifts the rule,
## since the type is then written out. An `inferred_type` of "" is one the words never told (a call, a
## constant), so nothing is checked against it.
static func inferred_value_refusal(inferred_type: String, words: String) -> String:
	var said: String = words.strip_edges()
	if inferred_type.is_empty():
		return ""
	if said.is_empty():
		return EventSheetL10n.translate("A := line takes its type from its value, so it needs one.")
	if NativeVariableMarks.gdscript_type_word("", said, true) == inferred_type:
		return ""
	return EventSheetL10n.translate("%s does not read as type %s, and a := line takes its type from its value. Change the value, or tick Write the type in code.") % [
		said, inferred_type]


## Splits an Array/Dictionary literal into its top-level entries (bracket- and string-aware):
## '[1, [2, 3], "a,b"]' -> ['1', '[2, 3]', '"a,b"'].
static func collection_literal_items(literal: String) -> PackedStringArray:
	var items: PackedStringArray = PackedStringArray()
	var trimmed: String = literal.strip_edges()
	if (trimmed.begins_with("[") and trimmed.ends_with("]")) or (trimmed.begins_with("{") and trimmed.ends_with("}")):
		trimmed = trimmed.substr(1, trimmed.length() - 2).strip_edges()
	if trimmed.is_empty():
		return items
	var depth: int = 0
	var quote: String = ""
	var current: String = ""
	for i: int in trimmed.length():
		var ch: String = trimmed[i]
		current += ch
		if not quote.is_empty():
			if ch == quote and (i == 0 or trimmed[i - 1] != "\\"):
				quote = ""
		elif ch == "\"" or ch == "'":
			quote = ch
		elif ch in ["[", "{", "("]:
			depth += 1
		elif ch in ["]", "}", ")"]:
			depth -= 1
		elif ch == "," and depth == 0:
			items.append(current.trim_suffix(",").strip_edges())
			current = ""
	if not current.strip_edges().is_empty():
		items.append(current.strip_edges())
	return items


## Wraps item expressions back into an Array or Dictionary literal. Empty -> "[]" / "{}".
static func items_to_collection_literal(items: PackedStringArray, is_dictionary: bool) -> String:
	var joined: String = ", ".join(items)
	return ("{%s}" % joined) if is_dictionary else ("[%s]" % joined)


## Edits a collection's items one per line instead of a cramped literal; the literal stays the truth.
func _open_items_editor() -> void:
	var is_dict: bool = _selected_stored_type().begins_with("Dictionary")
	if _items_window == null:
		_items_window = AcceptDialog.new()
		_items_window.add_cancel_button(EventSheetL10n.translate("Cancel"))
		_items_window.ok_button_text = EventSheetL10n.translate("Apply")
		_items_edit = TextEdit.new()
		_items_edit.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(380.0), EventSheetPalette.scaled_f(260.0))
		_items_window.add_child(_items_edit)
		_items_window.confirmed.connect(func() -> void:
			var items: PackedStringArray = PackedStringArray()
			for line: String in _items_edit.text.split("\n"):
				if not line.strip_edges().is_empty():
					items.append(line.strip_edges())
			_set_value_words(items_to_collection_literal(items, _selected_stored_type().begins_with("Dictionary"))))
		_dialog.add_child(_items_window)
	_items_edit.text = "\n".join(collection_literal_items(_default_edit.text))
	_items_edit.placeholder_text = EventSheetL10n.translate("one \"key\": value per line") if is_dict else EventSheetL10n.translate("one value per line")
	_items_window.title = EventSheetL10n.translate("Edit Dictionary Items") if is_dict else EventSheetL10n.translate("Edit Array Items")
	_items_window.popup_centered()


## The live reading of everything the window holds: the strip's row and code lines, the Inspector
## preview, the prefix check and the Inspector refresh fact.
func _refresh_reading() -> void:
	if _help_strip == null or _name_edit == null:
		return
	var type_name: String = _selected_stored_type()
	var attributes: Dictionary = _collect_attributes(type_name)
	_help_strip.set_reading(row_preview_text(), code_block_text(attributes))
	_refresh_mark_tiles()
	if _look_option.has_meta("code_note"):
		(_look_option.get_meta("code_note") as Label).text = annotation_text()
	var exported: bool = _exported_check.button_pressed and not _exported_check.disabled
	var shown_name: String = _shown_name()
	var prefix: String = str(attributes.get("group_prefix", ""))
	if exported and not prefix.is_empty() and shown_name.begins_with(prefix):
		shown_name = shown_name.substr(prefix.length())
	_inspector_preview_card.update_preview(shown_name, type_name, _value_text(), attributes, exported,
		_const_check.button_pressed)
	var misses: bool = exported and not prefix.is_empty() and not _shown_name().begins_with(prefix)
	_prefix_note.say(EventSheetL10n.translate("%s does not start with %s, so Godot leaves it outside %s. Rename it, or turn off the prefix.") % [
		_shown_name(), prefix, attributes.get("group", "")] if misses else "", EventSheetPopupUI.TONE_WARNING)
	var controller: String = str(attributes.get("show_if", attributes.get("lock_unless", "")))
	_refresh_label.text = EventSheetL10n.translate("automatic: %s tells it when it changes") % controller \
		if not controller.is_empty() else EventSheetL10n.translate("nothing to refresh")


func _shown_name() -> String:
	var typed: String = _name_edit.text.strip_edges()
	return typed if not typed.is_empty() else "value"


## The start the names in this group share, offered when "Only names starting" is ticked: the
## longest run up to an underscore that every member and this name begin with, else the group's name.
func suggested_prefix() -> String:
	var group: String = _group_edit.text.strip_edges()
	var names: PackedStringArray = PackedStringArray([_name_edit.text.strip_edges()])
	var sheet: EventSheetResource = _sheet()
	if sheet != null:
		for key: Variant in sheet.variables:
			var descriptor: Variant = sheet.variables[key]
			if descriptor is Dictionary and descriptor.get("attributes") is Dictionary \
					and str((descriptor.get("attributes") as Dictionary).get("group", "")) == group:
				names.append(str(key))
	var shared: String = ExportSections.shared_start(names)
	return shared if not shared.is_empty() else group.to_snake_case()


## The Inspector sections `target` sits in, read down the sheet's rows the way the Inspector reads the
## file and the variable rows read it (ExportSections' walk): {category, group, group_prefix,
## subgroup}, or {} when it sits in none - an unexported member, a member past the declarations, or
## one a prefix group shuts out. A note or a blank line between members ends nothing; code does.
static func inherited_sections(entries: Array, target: LocalVariable) -> Dictionary:
	if target == null:
		return {}
	var walk: ExportSections = ExportSections.new()
	for entry: Variant in entries:
		if entry is RawCodeRow:
			var code: String = (entry as RawCodeRow).code
			var sections: Array[Dictionary] = ExportSections.parse_block(code)
			for section: Dictionary in sections:
				walk.enter(section)
			if sections.is_empty() and not _is_note_or_blank(code):
				walk.reset()
			continue
		if not (entry is LocalVariable):
			walk.reset()
			continue
		var member: LocalVariable = entry as LocalVariable
		if member.exported:
			for section: Dictionary in ExportSections.from_attributes(member.attributes):
				walk.enter(section)
			walk.place(member.name)
		if member == target or member.name == target.name:
			if not member.exported or (walk.category.is_empty() and walk.group.is_empty()):
				return {}
			return {"category": walk.category, "group": walk.group, "group_prefix": walk.group_prefix,
				"subgroup": walk.subgroup}
	return {}


## True for a block of comment lines and blank lines only: a member's note, or the spacing the round
## trip keeps.
static func _is_note_or_blank(code: String) -> bool:
	for line: String in code.split("\n"):
		var stripped: String = line.strip_edges()
		if not stripped.is_empty() and not stripped.begins_with("#"):
			return false
	return true


## The names the sheet already uses at one section level, for the section fields' completion.
func _sheet_sections(level: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var sheet: EventSheetResource = _sheet()
	if sheet == null:
		return found
	var attribute_sets: Array = []
	for descriptor: Variant in sheet.variables.values():
		if descriptor is Dictionary and descriptor.get("attributes") is Dictionary:
			attribute_sets.append(descriptor.get("attributes"))
	for entry: Variant in sheet.events:
		if entry is LocalVariable and (entry as LocalVariable).attributes is Dictionary:
			attribute_sets.append((entry as LocalVariable).attributes)
	for attributes: Dictionary in attribute_sets:
		var words: String = str(attributes.get(level, "")).strip_edges()
		if not words.is_empty() and not found.has(words):
			found.append(words)
	return found


## Inspector polish only means anything on an @export var, so the look and section cards follow the
## tick; a type Godot cannot show greys the tick. Simple Mode keeps "When it changes" out of sight
## (display only - what a variable already has still round-trips).
func _update_attr_gating() -> void:
	if _exported_check == null:
		return
	if NOT_EXPORTABLE.has(_selected_stored_type()):
		_exported_check.set_pressed_no_signal(false)
		_exported_check.disabled = true
	var exported: bool = _exported_check.button_pressed and not _exported_check.disabled
	for index: int in range(1, _inspector_card.get_child(0).get_child_count()):
		(_inspector_card.get_child(0).get_child(index) as Control).visible = exported
	_sections_card.visible = exported
	var simple: bool = simple_mode_provider.is_valid() and bool(simple_mode_provider.call())
	_changes_fold.visible = not simple and _scope != "local" and not _const_check.button_pressed
	if simple:
		_changes_fold.folded = true
	_refresh_look_note()


## Ticking On ready seeds the class with Variant (the safe type for any node lookup) when it is empty.
func _on_onready_toggled_interactive(pressed: bool) -> void:
	if pressed and _class_edit.text.strip_edges().is_empty():
		_class_edit.text = "Variant"
	_apply_onready_state(pressed)


## @onready is exclusive with const and @export (the compiler writes only `@onready var`), and its
## value is an expression: the type becomes free text and the value a code field.
func _apply_onready_state(pressed: bool) -> void:
	if pressed:
		_const_check.set_pressed_no_signal(false)
		_exported_check.set_pressed_no_signal(false)
	_const_check.disabled = pressed or not _supports_constant(_selected_stored_type())
	_exported_check.disabled = pressed or _scope == "local"
	_on_type_changed(false)


## The scope word the window is showing: `const` wins, then a global, a local, a static, an instance.
func current_scope_word() -> String:
	if _const_check != null and _const_check.button_pressed:
		return EventSheetVariableSentence.SCOPE_CONSTANT
	if _writes_project_global:
		return EventSheetVariableSentence.SCOPE_GLOBAL
	if _scope == "local":
		return EventSheetVariableSentence.local_scope(static_local_wanted())
	if _is_static:
		return EventSheetVariableSentence.SCOPE_STATIC
	return EventSheetVariableSentence.SCOPE_INSTANCE


## True when the window will write a Static local: the tick, and only while the scope is Local.
func static_local_wanted() -> bool:
	return _scope == "local" and not _writes_project_global \
		and _static_local_check != null and _static_local_check.button_pressed


## Choosing a scope. Constant and Static only set their flag; Instance, Local and Global move the
## storage and clear both. Global also reveals the write-into picker.
func _apply_scope_key(scope_key: String) -> void:
	_writes_project_global = scope_key == EventSheetVariableSentence.SCOPE_GLOBAL
	_is_static = scope_key == EventSheetVariableSentence.SCOPE_STATIC
	_const_check.set_pressed_no_signal(scope_key == EventSheetVariableSentence.SCOPE_CONSTANT)
	if scope_key == EventSheetVariableSentence.SCOPE_LOCAL:
		_scope = "local"
	elif _scope == "local" or scope_key == EventSheetVariableSentence.SCOPE_INSTANCE:
		_scope = _member_scope if _member_scope != "local" else "global"
	if _writes_project_global:
		_refresh_global_targets()
	_last_scope_key = scope_key
	_apply_scope_gating()
	refresh_scope_selection()
	_refresh_name_warning()


## Selects the dropdown entry that matches the current flags; current_scope_word() stays the truth.
func refresh_scope_selection() -> void:
	if _scope_option == null:
		return
	var active: String = current_scope_word()
	for index: int in range(_scope_option.item_count):
		if str(_scope_option.get_item_metadata(index)) == active:
			_scope_option.select(index)
			EventSheetPopupUI.follow_description(_scope_option)
			break
	_global_target_row.visible = active == EventSheetVariableSentence.SCOPE_GLOBAL
	_refresh_reading()


## What each scope changes elsewhere: a Local is never an Inspector property, a Constant is neither
## Static nor a property, and exactly one of Static / Static local is ever on screen.
func _apply_scope_gating() -> void:
	var is_local: bool = _scope == "local" and not _writes_project_global
	var is_constant: bool = _const_check.button_pressed
	if is_local or is_constant:
		_exported_check.set_pressed_no_signal(false)
	_exported_check.disabled = is_local or is_constant or _onready_check.button_pressed
	_static_check.visible = not is_local
	_static_check.disabled = is_constant
	_static_check.set_pressed_no_signal(_is_static and not is_constant)
	_static_local_check.visible = is_local
	if not is_local:
		_static_local_check.set_pressed_no_signal(false)
	_onready_check.visible = _scope == "tree"
	if _mark_tiles.has("On ready"):
		(_mark_tiles["On ready"] as Control).visible = _onready_check.visible
	_refresh_write_type()
	_update_attr_gating()


## The object this variable will belong to - what the sheet calls itself.
func _owner_name() -> String:
	var sheet: EventSheetResource = _sheet()
	return "" if sheet == null else EventSheetVariableOwners.owner_of_sheet(sheet)


func _sheet() -> EventSheetResource:
	return _sheet_provider.call() as EventSheetResource if _sheet_provider.is_valid() else null


## The one line under each scope option, refreshed on open because it names the object in front.
func _refresh_scope_descriptions() -> void:
	var owner: String = _owner_name()
	for index: int in range(_scope_option.item_count):
		_scope_option.set_item_tooltip(index, scope_description(str(_scope_option.get_item_metadata(index)), owner))
	EventSheetPopupUI.follow_description(_scope_option)


## The window's fields, top to bottom, by the word each row leads with. `visible_only` answers what
## the reader can see for the scope in front of them.
func field_order(visible_only: bool = false) -> PackedStringArray:
	var order: PackedStringArray = PackedStringArray()
	var form: Node = _owner_label.get_parent() if _owner_label != null else null
	if form != null:
		_collect_rows(form, visible_only, order)
	return order


func _collect_rows(node: Node, visible_only: bool, into: PackedStringArray) -> void:
	for child: Node in node.get_children():
		if visible_only and child is Control and not (child as Control).visible:
			continue
		if child is HBoxContainer and child.get_child_count() > 1 and child.get_child(0) is Label \
				and (child.get_child(0) as Label).custom_minimum_size.x == EventSheetPopupUI.LABEL_MIN_WIDTH:
			into.append((child.get_child(0) as Label).text)
			continue
		_collect_rows(child, visible_only, into)


## The strip's text for the scope at `index` of the Scope dropdown.
func _describe_scope_index(index: int) -> Dictionary:
	if index < 0 or index >= _scope_option.item_count:
		return {}
	var scope_key: String = str(_scope_option.get_item_metadata(index))
	return {"heading": EventSheetL10n.translate("Scope · %s") % EventSheetVariableSentence.scope_word(scope_key), "body": scope_help(scope_key, _owner_name())}


## The strip's text for the type at `index` of the Type dropdown ({} for a group heading).
func _describe_type_index(index: int) -> Dictionary:
	if index < 0 or index >= _type_option.item_count or _type_option.is_item_separator(index):
		return {}
	return {"heading": EventSheetL10n.translate("Type · %s") % _type_option.get_item_text(index), "body": _type_option.get_item_tooltip(index)}


## Refills the write-into picker with the project's autoloads (plus "New global sheet…").
func _refresh_global_targets() -> void:
	var previous: String = str(selected_global_target().get("name", ""))
	_global_target_option.clear()
	for entry: Dictionary in EventSheetGlobalVariables.autoload_sheets():
		_global_target_option.add_item("%s  (%s)" % [str(entry.get("name", "")), str(entry.get("path", "")).get_file()])
		_global_target_option.set_item_metadata(_global_target_option.item_count - 1, entry)
	_global_target_option.add_item(EventSheetL10n.translate("New global sheet…"))
	_global_target_option.set_item_metadata(_global_target_option.item_count - 1, {})
	_global_target_option.select(0)
	for index: int in range(_global_target_option.item_count):
		if not previous.is_empty() and str((_global_target_option.get_item_metadata(index) as Dictionary).get("name", "")) == previous:
			_global_target_option.select(index)


## The autoload a Global will be written into ({} = "make me one").
func selected_global_target() -> Dictionary:
	if _global_target_option == null or _global_target_option.selected < 0:
		return {}
	var meta: Variant = _global_target_option.get_item_metadata(_global_target_option.selected)
	return meta as Dictionary if meta is Dictionary else {}


## The EXACT row this window will write, live: `Instance whole number  hp = 100`.
func row_preview_text() -> String:
	var stored_type: String = _selected_stored_type()
	var value_text: String = _value_text()
	if value_text.is_empty():
		value_text = _default_placeholder_for(stored_type)
	return "%s  %s = %s" % [EventSheetVariableSentence.chip_text(current_scope_word(),
		ViewportRowBuilder.friendly_type_word(stored_type)), _shown_name(), value_text]


## The declaration the compiler will write for these choices, built by THE COMPILER'S OWN EMITTER
## over a throwaway variable, so the window can never promise a line the sheet would not write.
func code_line_text() -> String:
	var line: String = EventSheets.row_code_line(_preview_variable(_collect_attributes(_selected_stored_type())))
	var autoload_name: String = str(selected_global_target().get("name", "")).strip_edges()
	if _writes_project_global and not autoload_name.is_empty():
		return "%s    # read elsewhere as %s.%s" % [line, autoload_name, _shown_name()]
	return line


## The whole block the variable compiles to - its sections, its description and the declaration
## with its annotation - for the strip's IN CODE line. Just the declaration for anything unexported.
func code_block_text(attributes: Dictionary) -> String:
	var preview: LocalVariable = _preview_variable(attributes)
	if not preview.exported or _writes_project_global:
		return code_line_text()
	return SheetCompiler._emit_tree_variable_line(preview)


func _preview_variable(attributes: Dictionary) -> LocalVariable:
	var preview: LocalVariable = LocalVariable.new()
	preview.name = _shown_name()
	var stored_type: String = _selected_stored_type()
	preview.type_name = stored_type
	var code: bool = _current_value_kind() in CODE_KINDS or (_onready_check != null and _onready_check.button_pressed)
	# An empty code value is no value (an empty node or resource slot), as the save makes it - never "".
	preview.default_value = (null if _value_text().is_empty() else _value_text()) if code \
		else _parse_default(stored_type, _value_text())
	preview.expression_default = code and not _value_text().is_empty()
	preview.no_default = code and _value_text().is_empty()
	preview.is_constant = _const_check != null and _const_check.button_pressed and _supports_constant(stored_type)
	preview.is_static = _is_static and not preview.is_constant
	preview.exported = _exported_check != null and _exported_check.button_pressed and not _exported_check.disabled
	preview.onready = _onready_check != null and _onready_check.button_pressed and _scope == "tree"
	preview.static_local = static_local_wanted()
	preview.attributes = attributes
	preview.export_hint = _export_hint if _selected_look_id() == "written" else ""
	preview.untyped = _write_type_check != null and _write_type_check.visible and not _write_type_check.button_pressed
	preview.setter_body = str(attributes.get("setter_body", ""))
	preview.getter_body = str(attributes.get("getter_body", ""))
	preview.setter_param = str(attributes.get("setter_param", "value"))
	if _selected_look_id() == "choices" and stored_type == "String":
		preview.options = parse_options(str(_look_values.get("choices|choices", "")))
	return preview


## The annotation the declaration carries - `@export_range(0, 40, 0.5)`, `@export` - "" when unexported.
func annotation_text() -> String:
	var line: String = code_line_text()
	var head: int = line.find("var ")
	return line.substr(0, head).strip_edges() if head > 0 else ""


## What a value field left empty will actually hold, said the way the row will say it.
func _default_placeholder_for(stored_type: String) -> String:
	match stored_type:
		"String":
			return "\"\""
		"bool":
			return "false"
	if is_collection_type(stored_type):
		return EventSheetL10n.translate("empty")
	return "0" if stored_type in ["int", "float"] else "null"


## Fills the "Keep in step" dropdown from the SCENE: Off / Always / On change / At spawn when a
## synchronizer is there, the offer to add one when there is none, and disabled with the reason
## when there is no scene or the variable is not one a synchronizer could watch.
func _refresh_sync_option() -> void:
	_sync_option.clear()
	var scene: Dictionary = _scene_replication()
	var host_named: String = str((scene.get("host", {}) as Dictionary).get("node_name", ""))
	var named: String = _name_edit.text.strip_edges()
	var can_ask: bool = not host_named.is_empty() and _scope != "local" and bool(_context.get("editing", false)) and not named.is_empty()
	if host_named.is_empty():
		_sync_option.add_item(EventSheetL10n.translate("No scene runs this script yet"))
		_sync_option.disabled = true
		return
	if (scene.get("synchronizers", []) as Array).is_empty():
		# The offer is the SECOND item: a dropdown whose only entry is selected never reports a choice.
		_sync_option.add_item(EventSheetL10n.translate("Not kept in step - this scene has no synchronizer"))
		_sync_option.set_item_metadata(0, "")
		_sync_option.add_item(EventSheetL10n.translate("Add a synchronizer to %s…") % host_named)
		_sync_option.set_item_metadata(1, SYNC_ADD_CHOICE)
		_sync_option.disabled = not can_ask
		return
	var current: String = str(EventSheetSceneReplication.entry_for(scene.get("synced", []), named).get("mode", EventSheetSceneReplication.MODE_OFF))
	for choice: Array in [
		[EventSheetSceneReplication.MODE_OFF, EventSheetL10n.translate("Off - stays on this machine")],
		[EventSheetSceneReplication.MODE_ALWAYS, EventSheetL10n.translate("Always - every frame")],
		[EventSheetSceneReplication.MODE_ON_CHANGE, EventSheetL10n.translate("On change - only when it moves")],
		[EventSheetSceneReplication.MODE_AT_SPAWN, EventSheetL10n.translate("At spawn only - once, with the object")],
	]:
		_sync_option.add_item(str(choice[1]))
		_sync_option.set_item_metadata(_sync_option.item_count - 1, str(choice[0]))
		if str(choice[0]) == current:
			_sync_option.select(_sync_option.item_count - 1)
	_sync_option.disabled = not can_ask
	_sync_option.tooltip_text = "" if can_ask else EventSheetL10n.translate("Add the variable first - a synchronizer keeps an existing property in step.")


## A mode picked here goes straight to the scene, whose undo owns it - it cannot ride Save.
func _on_sync_mode_chosen(index: int) -> void:
	var scene: Dictionary = _scene_replication()
	var mode: String = str(_sync_option.get_item_metadata(index))
	if mode.is_empty():
		return
	if mode == SYNC_ADD_CHOICE:
		var host: Dictionary = scene.get("host", {})
		var added: Dictionary = EventSheetSceneReplication.add_synchronizer(str(host.get("scene_path", "")), str(host.get("node_path", ".")))
		_say_sync_result(added, EventSheetL10n.translate("%s added.") % str(added.get("name", "")))
		_refresh_sync_option()
		return
	var named: String = _name_edit.text.strip_edges()
	var entry: Dictionary = EventSheetSceneReplication.entry_for(scene.get("synced", []), named)
	var synchronizers: Array = scene.get("synchronizers", [])
	var holder: Dictionary = entry if not entry.is_empty() else (synchronizers[0] as Dictionary if not synchronizers.is_empty() else {})
	if holder.is_empty():
		return
	_say_sync_result(EventSheetSceneReplication.write_mode(str(holder.get("scene_path", "")),
		str(holder.get("synchronizer_path", holder.get("node_path", ""))), str(entry.get("property_path", ".:%s" % named)), mode),
		"%s · %s" % [named, EventSheetSceneReplication.mode_word(mode)])


func _say_sync_result(result: Dictionary, done: String) -> void:
	var failed: bool = not bool(result.get("ok", false))
	_help_strip.show_note(EventSheetL10n.translate("Keep in step"), str(result.get("reason", "")) if failed else done,
		EventSheetPopupUI.HelpStrip.TONE_ERROR if failed else EventSheetPopupUI.HelpStrip.TONE_NORMAL)


func _scene_replication() -> Dictionary:
	var sheet: EventSheetResource = _sheet()
	return EventSheetSceneReplication.for_script(str(sheet.external_source_path) if sheet != null else "")


## The dock injects the active sheet so the name field can check clashes and shadowing.
func set_sheet_provider(provider: Callable) -> void:
	_sheet_provider = provider


## Owner class if `var_name` shadows a host-class member, else "".
func _shadow_owner(var_name: String) -> String:
	var sheet: EventSheetResource = _sheet()
	return "" if sheet == null else EventSheetProjectDoctor.shadowed_member_class(sheet, var_name.strip_edges())


## A clash is shown INLINE while the name is typed; finding out on OK is finding out too late.
func _refresh_name_warning() -> void:
	var typed: String = _name_edit.text.strip_edges()
	var owner: String = _shadow_owner(typed)
	if not owner.is_empty():
		_name_warning.say(EventSheetL10n.translate("⚠ \"%s\" shadows a %s member - rename to avoid a clash.") % [typed, owner], EventSheetPopupUI.TONE_WARNING)
	elif name_clashes(typed):
		_name_warning.say(EventSheetL10n.translate("⚠ \"%s\" is already a variable here - pick another name.") % typed, EventSheetPopupUI.TONE_WARNING)
	else:
		_name_warning.say("")


## True when the sheet already declares `candidate` and it is not the variable this window opened on.
func name_clashes(candidate: String) -> bool:
	var typed: String = candidate.strip_edges()
	var sheet: EventSheetResource = _sheet()
	if typed.is_empty() or sheet == null or typed == str(_context.get("original_name", "")).strip_edges():
		return false
	# A member variable opens with its own resource rather than an original name: keeping that name is
	# keeping it, not clashing with it.
	var own: LocalVariable = _context.get("variable_resource", null) as LocalVariable
	if own != null and typed == own.name.strip_edges():
		return false
	if sheet.variables.has(typed):
		return true
	for entry: Variant in sheet.events:
		if entry is LocalVariable and entry != own and (entry as LocalVariable).name.strip_edges() == typed:
			return true
	return false


## The sheet's enums ([{name, members}]): they join the type list as types of their own.
func set_enum_provider(provider: Callable) -> void:
	_enum_provider = provider


## A collection literal judged as it is typed: one that does not parse says why in the strip, in
## red; the moment it parses the field's own description comes back.
func _refresh_default_hint() -> void:
	var verdict: Dictionary = validate_default(_selected_stored_type(), _value_text())
	if bool(verdict.get("ok", false)):
		_clear_refusal("Initial value")
	else:
		_say_refusal("Initial value", str(verdict.get("error", "")))


func _refresh_const_ui() -> void:
	var supports_const: bool = _supports_constant(_selected_stored_type())
	_const_check.disabled = not supports_const or _onready_check.button_pressed
	if not supports_const:
		_const_check.set_pressed_no_signal(false)


func _supports_constant(type_name: String) -> bool:
	return constant_allowed(type_name, _context.get("variable_resource"))


## Whether a variable of `type_name` can be a constant. Any type rules out only a typed `: Variant`
## constant: one the file wrote inferred (`const SAVE_FILE := "user://save.cfg"`) is a constant all
## the same, and the window keeps it one.
static func constant_allowed(type_name: String, row: Variant) -> bool:
	return type_name != "Variant" or (row is LocalVariable and (row as LocalVariable).is_constant
		and (row as LocalVariable).inferred_type)
