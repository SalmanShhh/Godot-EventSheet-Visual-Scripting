# Godot EventSheets - the Doctor's line between a file and a program (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The rows are drawn by the Project Doctor window's OWN filler, so what is photographed is the report
# a reader gets rather than a lookalike of it, and the findings are the real ones - the sources below
# are handed to the check and whatever it says is what appears.
#
# THE PICTURE IS THE PAIR. Two files open the same door: one hands the path the player brought to
# `load()`, the other hands it to a reader that answers with pixels. Only the first is reported, and
# the finding's own words say why and offer the three doors that read the same file as data.
@tool
extends RefCounted

const PREVIEW_NAME: String = "outside-content-doctor-report"
const PREVIEW_SIZE: Vector2i = Vector2i(1240, 340)

## The pair, as {script path: source}. Short on purpose: the finding is the picture, not the fixture.
const SOURCES: Dictionary = {
	"res://game/mods.gd": "extends Node\n\n\nfunc _ready() -> void:\n"
		+ "\tget_window().files_dropped.connect(_on_files_dropped)\n\n\n"
		+ "func _on_files_dropped(files: PackedStringArray) -> void:\n"
		+ "\tadd_child(load(files[0]).instantiate())\n",
	"res://game/portraits.gd": "extends Node\n\n\nfunc _ready() -> void:\n"
		+ "\tget_window().files_dropped.connect(_on_files_dropped)\n\n\n"
		+ "func _on_files_dropped(files: PackedStringArray) -> void:\n"
		+ "\t$Portrait.texture = ImageTexture.create_from_image(Image.load_from_file(files[0]))\n",
}


static func build(host: Window) -> Control:
	var findings: Array[Dictionary] = EventSheetFilesDoctor.loads_outside_findings(SOURCES)
	var tree: Tree = Tree.new()
	tree.custom_minimum_size = Vector2(0, 90)
	tree.hide_root = true
	tree.columns = 3
	tree.set_column_title(0, "Severity")
	tree.set_column_title(1, "Where")
	tree.set_column_title(2, "Finding")
	tree.set_column_expand(0, false)
	tree.set_column_custom_minimum_width(0, 80)
	tree.set_column_expand(1, false)
	tree.set_column_custom_minimum_width(1, 140)
	tree.column_titles_visible = true
	EventSheetProjectDoctorPanel.fill(tree, tree.create_item(), findings)

	# A report row is one line wide and the finding is longer than one line, so the words the reader
	# actually meets live in the row's own tooltip. The card below is that tooltip's text, read off
	# the same finding - the doors are the half a truncated row can never show.
	var words: Label = Label.new()
	words.text = "" if findings.is_empty() else str(findings[0].get("message", ""))
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	stack.add_child(EventSheetPopupUI.titled_card("Findings", tree))
	stack.add_child(EventSheetPopupUI.titled_card("The finding, in full", words))
	var body: MarginContainer = EventSheetPopupUI.margined(stack)
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(body)
	return body
