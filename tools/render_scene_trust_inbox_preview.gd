# EventForge - render harness (dev tool) for the Doctor's triage inbox showing the scene-trust
# finding: a row that builds a scene out of the player's own folder with nobody asking whether the
# file is data. The picture exists because of the quiet sheet law - the sheet itself says nothing but
# the amber state, so THIS is where the words are, and a preview of the row would show a stripe and
# no sentence.
#
# The rows are built through the panel's own `fill_inbox`, and the chip through the same
# `EventSheetQuickFixes.fixes_for`, so what is drawn here is what the window really draws.
#
# Run NON-headless (a headless run cannot render):
#   godot --path . --script tools/render_scene_trust_inbox_preview.gd
@tool
extends SceneTree

const OUTPUT_PATH: String = "res://docs/images/scenes-trust-inbox.png"

## The script the finding is read out of - a made-up project file, so nothing here names a real one.
const SOURCE: String = "extends Node\n\n\nfunc _on_load_pressed() -> void:\n\tvar __layout_a1 = load(\"user://mods/level.tscn\").instantiate()\n\t__layout_a1.name = \"Mod\"\n\tget_tree().root.add_child(__layout_a1)\n"

var _frames: int = 0


func _init() -> void:
	root.title = "Project Doctor"
	root.size = Vector2i(1152, 320)
	var background: ColorRect = ColorRect.new()
	background.color = Color("#252525")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)

	var column: VBoxContainer = VBoxContainer.new()
	column.position = Vector2(10, 10)
	column.size = Vector2(1132, 300)
	column.add_theme_constant_override("separation", 8)
	root.add_child(column)

	var tree: Tree = Tree.new()
	tree.columns = 4
	tree.column_titles_visible = true
	tree.set_column_title(0, "")
	tree.set_column_title(1, "Check")
	tree.set_column_title(2, "Where")
	tree.set_column_title(3, "What was found")
	tree.set_column_expand(0, false)
	tree.set_column_custom_minimum_width(0, 24)
	tree.set_column_expand_ratio(1, 2)
	tree.set_column_expand_ratio(2, 2)
	tree.set_column_expand_ratio(3, 9)
	tree.hide_root = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tree)

	var findings: Array[Dictionary] = EventSheetFilesDoctor.untrusted_scene_findings(
		{"res://mod_loader.gd": SOURCE})
	var page: Array[Dictionary] = []
	for finding: Dictionary in findings:
		var carried: Dictionary = finding.duplicate()
		carried["is_new"] = true
		page.append(carried)
	EventSheetProjectDoctorPanel.fill_inbox(tree, tree.create_item(), page)

	# The chip bar, built the way the window builds it: whatever the finding offers, and nothing else.
	var chips: HBoxContainer = HBoxContainer.new()
	column.add_child(chips)
	for offer: Dictionary in EventSheetQuickFixes.fixes_for(page[0] if not page.is_empty() else {}):
		var chip: Button = Button.new()
		chip.text = "%s %s" % [EventSheetL10n.translate("Fix:"), str(offer.get("label", ""))]
		chips.add_child(chip)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < 8:
		return
	# Cropped to the panel itself: the window a desktop hands back is never smaller than the desktop
	# allows, and a picture that is two thirds empty background teaches nothing.
	var image: Image = root.get_texture().get_image().get_region(Rect2i(0, 0, 1152, 320))
	image.save_png(OUTPUT_PATH)
	print("[preview] scene trust inbox %dx%d" % [image.get_width(), image.get_height()])
	quit(0)
