# Godot EventSheets - L8: the Doctor's Lighting section (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The rows are drawn by the Project Doctor window's OWN filler, so what is photographed here is the
# report a reader gets rather than a lookalike of it - and the findings are the real ones, measured
# from the fixture scenes and the fixture sheet, not typed in.
@tool
extends RefCounted

const PREVIEW_NAME: String = "lighting-doctor-report"
const PREVIEW_SIZE: Vector2i = Vector2i(1180, 360)

const SCENES: Array[String] = [
	"res://tests/fixtures/lighting_scene_room.tscn",
	"res://tests/fixtures/lighting_scene_crypt.tscn",
	"res://tests/fixtures/lighting_scene_vault.tscn"
]
const SHEETS: Array[String] = ["res://tests/fixtures/lighting_scene_crypt.gd"]


static func build(host: Window) -> Control:
	var tree: Tree = Tree.new()
	tree.hide_root = true
	tree.columns = 3
	tree.set_column_title(0, "Severity")
	tree.set_column_title(1, "Where")
	tree.set_column_title(2, "Finding")
	tree.set_column_expand(0, false)
	tree.set_column_custom_minimum_width(0, 80)
	tree.set_column_expand(1, false)
	tree.set_column_custom_minimum_width(1, 200)
	tree.column_titles_visible = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	EventSheetProjectDoctorPanel.fill(tree, tree.create_item(), EventSheetLightingDoctor.report(
		PackedStringArray(SCENES), PackedStringArray(SHEETS)))
	var body: MarginContainer = EventSheetPopupUI.margined(
		EventSheetPopupUI.titled_card("Findings", tree))
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(body)
	return body
