# EventForge - a variable row says what the Inspector does with it as coloured tiles, one per fact
# (in the Inspector, kept in a range, has a description), in EVERY look, and trails its `##` note.
# Each tile opens a hover card (title, sentence, the code that earns it). A variable `@export_storage`
# saves is hidden from the Inspector, so it wears the saved-but-hidden tile and never the eye. The
# retired quiet-marks theme value still loads and saves, but changes nothing and is no setting. The
# Variable window's type list wears each type's editor icon, and the parameters window frames its
# object's icon on a tile. The Variable window carries the row's own tile beside each option that puts
# one on the row (same colours, same card), and a member under an earlier member's group line opens
# on that group without writing the line again; an empty section field says "none".
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NativeVariableMarks := preload("res://addons/eventsheet/editor/interaction/native_variable_marks.gd")
const P := "variable_mark_tiles_test"
const VARIABLE_DIALOG := preload("res://addons/eventsheet/editor/variable_dialog.gd")
const CAROUSEL := "res://demo/showcase/carousel/showcase_carousel.gd"
const STORAGE_FIXTURE := "user://variable_mark_tiles_storage.gd"
const STORAGE_SOURCE := "extends Node2D\n\n## Written by Bake.\n@export_storage var baked_cells: Array = []\n@export var brush_size: int = 3\n"
const WINDOW_SOURCE := "extends Node2D\n\n@export_group(\"Bullet\", \"bullet\")\n@export var bullet_speed: float = 400.0\n@export var bullet_count: int = 3\n@export_group(\"\")\n@export var health: int = 10\n"


static func run() -> bool:
	var default_beat: Dictionary = _row_facts(CAROUSEL, "beat", _default_look_style())
	var retired_beat: Dictionary = _row_facts(CAROUSEL, "beat", _default_look_style(true))
	var storage_file := FileAccess.open(STORAGE_FIXTURE, FileAccess.WRITE)
	storage_file.store_string(STORAGE_SOURCE)
	storage_file.close()
	var baked: Dictionary = _row_facts(STORAGE_FIXTURE, "baked_cells", _default_look_style())
	var brush: Dictionary = _row_facts(STORAGE_FIXTURE, "brush_size", _default_look_style())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STORAGE_FIXTURE))
	var eye_card: Dictionary = NativeVariableMarks.badge_card(NativeVariableMarks.BADGE_INSPECTOR)
	var range_card: Dictionary = NativeVariableMarks.badge_card(NativeVariableMarks.BADGE_RANGE,
		default_beat.get("variable") as LocalVariable)
	var tip_card: Dictionary = NativeVariableMarks.badge_card(NativeVariableMarks.BADGE_TOOLTIP)
	var light: Dictionary = EventSheetEditorThemeDeriver.NATIVE_COLOURS_LIGHT
	var ok: bool = SUPPORT.pins(P, [
		["the default look's beat wears all three tiles", default_beat["badges"],
			PackedStringArray(["inspector", "range", "tooltip"])],
		["and trails its ## note", default_beat["note"], "Beats elapsed."],
		["a theme still saying quiet marks draws them all the same", retired_beat["badges"],
			PackedStringArray(["inspector", "range", "tooltip"])],
		["and its note", retired_beat["note"], "Beats elapsed."],
		["the retired value is no setting in the Theme Editor", _editable_token_names().has("variable_quiet_marks"), false],
		["but a theme file naming it still stores it", _stored("variable_quiet_marks"), true],
		["a tile is 20 px, as the design draws it", NativeVariableMarks.TILE_SIZE, 20.0],
		["@export_storage wears the saved-but-hidden tile, no eye", baked["badges"],
			PackedStringArray(["storage", "tooltip"])],
		["a plain @export keeps its eye", brush["badges"], PackedStringArray(["inspector"])],
		["the eye's card title", eye_card.get("title"), "In the Inspector"],
		["the eye's card sentence", Array(eye_card.get("lines", PackedStringArray())),
			["Designers can change this per object in the Inspector, without opening the script."]],
		["the eye's card code, under the sentence", [eye_card.get("mono"), eye_card.get("code_last")], ["@export", true]],
		["the range card names its limits", Array(range_card.get("lines", PackedStringArray())),
			["A slider in the Inspector, from 0 to 9999."]],
		["the description card", [tip_card.get("title"), tip_card.get("mono")], ["Has a description", "## ..."]],
		["the storage card", NativeVariableMarks.badge_card(NativeVariableMarks.BADGE_STORAGE).get("title"), "Saved, hidden"],
		["a hidden tile is grey", _is_grey(NativeVariableMarks.badge_ink(null, NativeVariableMarks.BADGE_STORAGE, true)), true],
		["light eye ink is the design's", light["inspector_badge_foreground_color"], Color("#094380")],
		["light range ink is the design's", light["range_badge_foreground_color"], Color("#502793")],
		["light description ink is the design's", light["tooltip_badge_foreground_color"], Color("#664100")],
		# The type list's icons: every name below was found in the live editor theme by an --editor
		# probe (46 of the list's 47; Resource has none and wears its parent's).
		["a typed list wears the Array icon", VARIABLE_DIALOG.type_icon_name("Array[int]"), "Array"],
		["a typed map wears the Dictionary icon", VARIABLE_DIALOG.type_icon_name("Dictionary[String, int]"), "Dictionary"],
		["a class wears its own", VARIABLE_DIALOG.type_icon_name("Node2D"), "Node2D"],
		["the parameters window frames its object icon on a tile", _params_icon_framing(),
			["PanelContainer", EventSheetPalette.scaled_f(32.0), EventSheetPalette.scaled_f(18.0)]],
		["the tile's ground is the design's", [ACEParamsDialog.ICON_TILE_DARK, ACEParamsDialog.ICON_TILE_LIGHT],
			[Color("#3a4350"), Color("#d3dce6")]],
		["the retired behaviour column is no setting in the Theme Editor",
			_editable_token_names().has("behaviour_in_object_column"), false],
		["but a theme file naming it still stores it", _stored("behaviour_in_object_column"), true],
	])
	return SUPPORT.pins(P, _window_pins()) and ok


## The Variable window carries the row's own tile beside each option that puts one on the row, in the
## row's colours, with the row tile's card; and a member written under an earlier member's group line
## opens on the group it sits in, without writing that line a second time.
static func _window_pins() -> Array:
	var sheet: EventSheetResource = EventSheets.open_gd_as_sheet(WINDOW_SOURCE)
	var members: Dictionary = {}
	for entry: Variant in sheet.events:
		if entry is LocalVariable:
			members[(entry as LocalVariable).name] = entry
	var host: Node = Node.new()
	var dialog: VariableDialog = VARIABLE_DIALOG.new()
	dialog.init_dialog(host)
	dialog.set_sheet_provider(func() -> EventSheetResource: return sheet)
	var light: EventSheetEventStyle = EventSheetEditorThemeDeriver.native_style(Color("#e6e6e6")).get_event_style()
	dialog.style_provider = func() -> EventSheetEventStyle: return light
	_open_member(dialog, members.get("bullet_count") as LocalVariable)
	var opened: Dictionary = dialog.option_badges()
	var count_fields: Array = [dialog._category_edit.text, dialog._group_edit.text, dialog._prefix_edit.text,
		dialog._prefix_check.button_pressed, dialog._subgroup_edit.text]
	var count_writes_group: bool = dialog._collect_attributes("int").has("group")
	var placeholders: Array = [dialog._category_edit.placeholder_text, dialog._group_edit.placeholder_text,
		dialog._prefix_edit.placeholder_text, dialog._subgroup_edit.placeholder_text]
	dialog._select_look("slider")
	dialog._refresh_reading()
	var slider_tile: String = str(dialog.option_badges().get(VariableDialog.LOOK_OPTION, ""))
	dialog._select_look("storage")
	dialog._refresh_reading()
	var storage_tile: String = str(dialog.option_badges().get(VariableDialog.LOOK_OPTION, ""))
	var eye_tile: Control = dialog._mark_tiles["Editable in the Inspector"]
	var eye_inks: Array = eye_tile.call("inks")
	var eye_card_title: String = str((eye_tile.call("card") as Dictionary).get("title", ""))
	var described_row: HBoxContainer = dialog._attr_tooltip_edit.get_parent() as HBoxContainer
	var described_order: Array = [described_row.get_child(0).get_child(0).get_child(0) == dialog._mark_tiles["Description"],
		(described_row.get_child(0).get_child(1) as Label).text, dialog.field_order().has("Description")]
	_open_member(dialog, members.get("bullet_speed") as LocalVariable)
	var first_writes_group: bool = dialog._collect_attributes("float").has("group")
	_open_member(dialog, members.get("health") as LocalVariable)
	var after_end: String = dialog._group_edit.text
	host.free()
	var dark: EventSheetEventStyle = EventSheetEditorThemeDeriver.native_style(
		EventSheetEditorThemeDeriver.NATIVE_DARK_REFERENCE_BASE).get_event_style()
	return [
		["each option and the tile it carries", VariableDialog.OPTION_BADGES, {
			"Editable in the Inspector": "inspector", "Description": "tooltip", "On ready": "on_ready",
			"Show if": "show_if", "Setter body": "on_change"}],
		["the window opens with every option's tile, and a plain look puts none on the row", opened, {
			"Editable in the Inspector": "inspector", "Description": "tooltip", "On ready": "on_ready",
			"Show if": "show_if", "Setter body": "on_change", "Inspector look": ""}],
		["a slider look carries the range tile", slider_tile, "range"],
		["saved but hidden carries the hidden eye", storage_tile, "storage"],
		["a tile wears the sheet's own colours", eye_inks,
			[light.inspector_badge_foreground_color, light.inspector_badge_background_color]],
		["and opens the row tile's card", eye_card_title, "In the Inspector"],
		["the tile stands in front of its option's words, and the row still counts as a field",
			described_order, [true, "Description", true]],
		["a member under an earlier member's group line opens on that group and its prefix", count_fields,
			["", "Bullet", "bullet", true, ""]],
		["and saving it untouched writes no second group line", count_writes_group, false],
		["the member the line sits on keeps writing it", first_writes_group, true],
		["a member after the group's end sits in none", after_end, ""],
		["an empty section field says none, never a made-up name", placeholders, ["none", "none", "none", "none"]],
		["the walk names the sections a member sits in",
			VariableDialog.inherited_sections(sheet.events, members.get("bullet_count") as LocalVariable),
			{"category": "", "group": "Bullet", "group_prefix": "bullet", "subgroup": ""}],
		["the three new tiles' cards", [NativeVariableMarks.badge_card(NativeVariableMarks.BADGE_ON_CHANGE).get("title"),
			NativeVariableMarks.badge_card(NativeVariableMarks.BADGE_ON_READY).get("title"),
			NativeVariableMarks.badge_card(NativeVariableMarks.BADGE_SHOW_IF).get("title")],
			["Runs code on change", "Set when the scene is ready", "Shown only if"]],
		["on change is the eye tile turned coral, at each hand's own lightness",
			[NativeVariableMarks.badge_ink(dark, NativeVariableMarks.BADGE_ON_CHANGE, true).to_html(false),
				NativeVariableMarks.badge_ink(light, NativeVariableMarks.BADGE_ON_CHANGE, true).to_html(false)],
			["ff9d7c", "802709"]],
		["show if is the eye tile turned a soft periwinkle",
			NativeVariableMarks.badge_ink(dark, NativeVariableMarks.BADGE_SHOW_IF, false).to_html(false), "36364d"],
		["on ready shares the range tile's", NativeVariableMarks.badge_ink(light, NativeVariableMarks.BADGE_ON_READY, false),
			light.range_badge_background_color],
	]


## Opens the window on `member` the way a double-click on its row does.
static func _open_member(dialog: VariableDialog, member: LocalVariable) -> void:
	if member == null:
		return
	dialog.open_for_edit("tree", {"editing": true, "variable_resource": member,
		"attributes": (member.attributes as Dictionary).duplicate(true) if member.attributes is Dictionary else {},
		"export_hint": member.export_hint, "options": member.options},
		member.name, member.type_name, member.default_value, false, "Edit Variable", member.is_constant,
		member.exported, member.onready, member.is_static)


## [the class of what holds the header icon, its side, the icon's side].
static func _params_icon_framing() -> Array:
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	var header: Control = dialog._build_header()
	var icon: TextureRect = dialog._header_icon
	var holder: Control = icon.get_parent() as Control
	var framing: Array = [holder.get_class(), holder.custom_minimum_size.x, icon.custom_minimum_size.x]
	header.free()
	return framing


## The look a new sheet gets: Inspector-style rows by the deriver's own route. `retired_quiet` sets
## the retired value a Wave-13 theme file may still carry.
static func _default_look_style(retired_quiet: bool = false) -> EventSheetEditorStyle:
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	EventSheetEditorThemeDeriver.read_variables_inspector_style(style.get_event_style())
	if retired_quiet:
		style.get_event_style().set("variable_quiet_marks", true)
	return style


static func _editable_token_names() -> PackedStringArray:
	var names := PackedStringArray()
	for token: Dictionary in EventSheetThemeEditor.editable_tokens(EventSheetEventStyle.new()):
		names.append(str(token.get("name", "")))
	return names


static func _stored(property_name: String) -> bool:
	for info: Dictionary in EventSheetEventStyle.new().get_property_list():
		if str(info.get("name", "")) == property_name:
			return bool(int(info.get("usage", 0)) & PROPERTY_USAGE_STORAGE)
	return false


static func _is_grey(colour: Color) -> bool:
	return is_equal_approx(colour.r, colour.g) and is_equal_approx(colour.g, colour.b)


static func _row_facts(path: String, variable_name: String, style: EventSheetEditorStyle) -> Dictionary:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	sheet.editor_style = style
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	var found: Dictionary = {"badges": PackedStringArray(), "note": "", "variable": null}
	for row_data: EventRowData in view._root_rows:
		var is_row: bool = false
		for span: SemanticSpan in row_data.spans:
			var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
			if bool(metadata.get("variable_name_span", false)) and span.text == variable_name:
				is_row = true
				found["badges"] = PackedStringArray(metadata.get("variable_badges", PackedStringArray()))
				found["variable"] = row_data.source_resource
		if not is_row:
			continue
		for span: SemanticSpan in row_data.spans:
			if span.metadata is Dictionary and bool((span.metadata as Dictionary).get("variable_doc_note", false)):
				found["note"] = span.text
		break
	view.free()
	return found
