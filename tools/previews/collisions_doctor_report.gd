# Godot EventSheets - the Doctor's Collisions section, with its doors (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The rows are drawn by the Project Doctor window's OWN filler, so what is photographed is the report
# a reader gets rather than a lookalike of it, and the findings are the real ones measured from the
# fixture scenes: a trigger nothing can reach, an Area with its monitoring switched off, and a
# collision object with no shape at all.
#
# The doors under it are the chips the panel offers for whichever finding is selected, asked of the
# same catalog the panel asks - so what is photographed is what a click would really do.
@tool
extends RefCounted

const PREVIEW_NAME: String = "collisions-doctor-report"
const PREVIEW_SIZE: Vector2i = Vector2i(1320, 400)

const SCENES: PackedStringArray = [
	"res://tests/fixtures/collision_scene_door.tscn",
	"res://tests/fixtures/collision_scene_enemy.tscn",
	"res://tests/fixtures/collision_scene_gate.tscn",
	"res://tests/fixtures/collision_scene_hollow.tscn",
	"res://tests/fixtures/collision_scene_hushed.tscn",
]
const SCRIPTS: PackedStringArray = [
	"res://tests/fixtures/collision_scene_door.gd",
	"res://tests/fixtures/collision_scene_gate.gd",
	"res://tests/fixtures/collision_scene_hollow.gd",
	"res://tests/fixtures/collision_scene_hushed.gd",
]

const LAYER_SETTINGS: Array = [
	["layer_names/2d_physics/layer_1", "World"],
	["layer_names/2d_physics/layer_2", "Doors"],
	["layer_names/2d_physics/layer_3", "Enemies"],
]


static func build(host: Window) -> Control:
	for entry: Array in LAYER_SETTINGS:
		ProjectSettings.set_setting(str(entry[0]), str(entry[1]))
	EventSheetSceneCollisionFacts.clear_cache()
	var findings: Array[Dictionary] = EventSheetCollisionsDoctor.report(SCRIPTS, SCENES)
	var tree: Tree = Tree.new()
	tree.hide_root = true
	tree.columns = 3
	tree.set_column_title(0, "Severity")
	tree.set_column_title(1, "Where")
	tree.set_column_title(2, "Finding")
	tree.set_column_expand(0, false)
	tree.set_column_custom_minimum_width(0, 80)
	tree.set_column_expand(1, false)
	tree.set_column_custom_minimum_width(1, 230)
	tree.column_titles_visible = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Asked for outright rather than left to the stretch: the doors sit under the report, so the two
	# cards share the height and a Tree with no appetite of its own would come out one row tall.
	tree.custom_minimum_size = Vector2(0.0, 240.0)
	EventSheetProjectDoctorPanel.fill(tree, tree.create_item(), findings)
	var doors: HBoxContainer = HBoxContainer.new()
	doors.add_theme_constant_override("separation", 6)
	for finding: Dictionary in findings:
		for offer: Dictionary in EventSheetQuickFixes.fixes_for(finding):
			var chip: Button = Button.new()
			chip.text = str(offer.get("label", ""))
			doors.add_child(chip)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	stack.add_child(EventSheetPopupUI.titled_card("Findings", tree))
	stack.add_child(EventSheetPopupUI.titled_card("What one click can do", doors))
	var body: MarginContainer = EventSheetPopupUI.margined(stack)
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(body)
	return body
