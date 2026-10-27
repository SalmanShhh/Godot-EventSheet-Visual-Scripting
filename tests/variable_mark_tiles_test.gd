# EventForge - a variable row says what the Inspector does with it as coloured tiles, one per fact
# (in the Inspector, kept in a range, has a description), in EVERY look, and trails its `##` note.
# Each tile opens a hover card (title, sentence, the code that earns it). A variable `@export_storage`
# saves is hidden from the Inspector, so it wears the saved-but-hidden tile and never the eye. The
# retired quiet-marks theme value still loads and saves, but changes nothing and is no setting. The
# Variable window's type list wears each type's editor icon, and the parameters window frames its
# object's icon on a tile.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NativeVariableMarks := preload("res://addons/eventsheet/editor/interaction/native_variable_marks.gd")
const P := "variable_mark_tiles_test"
const VARIABLE_DIALOG := preload("res://addons/eventsheet/editor/variable_dialog.gd")
const CAROUSEL := "res://demo/showcase/carousel/showcase_carousel.gd"
const STORAGE_FIXTURE := "user://variable_mark_tiles_storage.gd"
const STORAGE_SOURCE := "extends Node2D\n\n## Written by Bake.\n@export_storage var baked_cells: Array = []\n@export var brush_size: int = 3\n"


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
	return SUPPORT.pins(P, [
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
	])


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
