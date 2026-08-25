# Godot EventSheets - the Doctor's Effects section (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The rows are drawn by the Project Doctor window's OWN filler, so what is photographed here is the
# report a reader gets rather than a lookalike of it - and the findings are the real ones, measured
# from the fixture scenes and the fixture sheets: a shared material eleven rows away from a bug, a
# dial the shader does not declare, a global nothing has declared, and a screen effect left drawing
# while every dial is at rest.
@tool
extends RefCounted

const PREVIEW_NAME: String = "effect-doctor-report"
const PREVIEW_SIZE: Vector2i = Vector2i(1240, 360)

const SCENES: Array[String] = [
	"res://tests/fixtures/effect_scene_goblin.tscn",
	"res://tests/fixtures/effect_scene_orc.tscn",
	"res://tests/fixtures/effect_scene_screen.tscn"
]
const SHEETS: Array[String] = [
	"res://tests/fixtures/effect_scene_goblin.gd",
	"res://tests/fixtures/effect_scene_boss.gd"
]


static func build(host: Window) -> Control:
	EventSheetProjectShareIndex.clear_cache()
	var tree: Tree = Tree.new()
	tree.hide_root = true
	tree.columns = 3
	tree.set_column_title(0, "Severity")
	tree.set_column_title(1, "Where")
	tree.set_column_title(2, "Finding")
	tree.set_column_expand(0, false)
	tree.set_column_custom_minimum_width(0, 80)
	tree.set_column_expand(1, false)
	tree.set_column_custom_minimum_width(1, 220)
	tree.column_titles_visible = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	EventSheetProjectDoctorPanel.fill(tree, tree.create_item(), EventSheetEffectsDoctor.report(
		PackedStringArray(SCENES), PackedStringArray(SHEETS)))
	var body: MarginContainer = EventSheetPopupUI.margined(
		EventSheetPopupUI.titled_card("Findings", tree))
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(body)
	return body
