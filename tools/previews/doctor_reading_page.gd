# Godot EventSheets - the Doctor's Reading section over a staged project (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The rows are drawn by the Project Doctor window's OWN inbox filler, so what is photographed is the
# page a reader gets rather than a lookalike of it.
#
# THE PROJECT IS STAGED rather than borrowed, and the staging is the point of the picture. The
# repository's own showcases are compiler output and read almost entirely as rows, so a page taken
# over them would be a page with nothing on it. These four files are ordinary hand-written game code
# of the kind somebody opens the plugin with for the first time: a repeated statement worth a table
# entry one day, a couple of doors into where it is said, and a tail of lines nothing else repeats -
# which are meant to stay code and are counted rather than listed.
#
# Nothing is written under res://: the files live in user:// and are deleted once the picture is
# taken.
@tool
extends RefCounted

const PREVIEW_NAME: String = "doctor-reading-page"
const PREVIEW_SIZE: Vector2i = Vector2i(1280, 640)

## Where the staged project is written, and what is in it. Four small scripts that repeat one
## statement between them and disagree about the rest.
const STAGED_DIR: String = "user://reading_preview_project"

const STAGED_SOURCES: Dictionary = {
	"coin.gd": """extends Area2D

var value: int = 1


func collect() -> void:
	var pop: Tween = create_tween()
	pop.tween_property(self, "modulate:a", 0.0, 0.25)
	pop.chain().tween_callback(queue_free)
""",
	"crate.gd": """extends StaticBody2D

enum Phase {WHOLE, CRACKED, BROKEN}

var phase: int = Phase.WHOLE


func smash() -> void:
	var dust: Tween = create_tween()
	dust.chain().tween_callback(queue_free)
""",
	"door.gd": """extends Node2D

enum State {CLOSED, OPENING, OPEN, LOCKED}

var state: int = State.CLOSED


func shut() -> void:
	var swing: Tween = create_tween()
	swing.chain().tween_callback(queue_free)
""",
	"spark.gd": """extends GPUParticles2D


func burn_out() -> void:
	var fade: Tween = create_tween()
	fade.chain().tween_callback(queue_free)
"""
}


static func build(host: Window) -> Control:
	var paths: PackedStringArray = _stage()
	var findings: Array[Dictionary] = EventSheetReadingDoctor.report(paths)
	_unstage(paths)
	var tree: Tree = Tree.new()
	tree.hide_root = true
	tree.columns = 4
	tree.set_column_title(0, "New")
	tree.set_column_title(1, "Section")
	tree.set_column_title(2, "Where")
	tree.set_column_title(3, "Finding")
	tree.set_column_expand(0, false)
	tree.set_column_custom_minimum_width(0, 40)
	tree.set_column_expand(1, false)
	tree.set_column_custom_minimum_width(1, 170)
	tree.set_column_expand(2, false)
	tree.set_column_custom_minimum_width(2, 170)
	tree.column_titles_visible = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Triaged against an EMPTY read, so every line wears its "new since you last looked" mark: the
	# picture is of a page somebody is opening for the first time.
	EventSheetProjectDoctorPanel.fill_inbox(tree, tree.create_item(),
		EventSheetDoctorInbox.triage(findings, PackedStringArray()))
	# The stage is the EDITOR's own window, which is already full of editor: a card with a
	# transparent ground lets the 3D viewport and the docks read straight through the ledger's lines.
	# So the picture carries its own opaque floor, in the editor's own base colour, and the card sits
	# on that.
	var stage: Control = Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var floor_rect: ColorRect = ColorRect.new()
	floor_rect.color = _base_colour()
	floor_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(floor_rect)
	var body: MarginContainer = EventSheetPopupUI.margined(
		EventSheetPopupUI.titled_card("Inbox", tree))
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(body)
	host.add_child(stage)
	return stage


## The colour a Doctor panel actually sits on. Asked of the running editor's theme so the picture is
## of the editor a reader has, and answered with the plugin's own dark ground when there is no editor
## around to ask - a preview run without one is still worth a picture.
static func _base_colour() -> Color:
	if Engine.is_editor_hint() and EditorInterface.get_editor_theme() != null:
		return EditorInterface.get_editor_theme().get_color("base_color", "Editor")
	return Color("#252525")


## Writes the staged project and hands back its paths, sorted - the order the section reads them in.
static func _stage() -> PackedStringArray:
	DirAccess.make_dir_recursive_absolute(STAGED_DIR)
	var paths: PackedStringArray = PackedStringArray()
	for name: String in STAGED_SOURCES:
		var path: String = STAGED_DIR.path_join(name)
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			continue
		file.store_string(str(STAGED_SOURCES[name]))
		file.close()
		paths.append(path)
	paths.sort()
	return paths


static func _unstage(paths: PackedStringArray) -> void:
	for path: String in paths:
		DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(STAGED_DIR)
