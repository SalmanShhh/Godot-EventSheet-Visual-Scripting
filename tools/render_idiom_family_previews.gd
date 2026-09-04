# EventForge - render harness (dev tool) for the two idiom figures this slice is measured on. Run
# NON-headless (a headless run cannot render):
#   godot --path . --script tools/render_idiom_family_previews.gd
#
# Two figures, each the same lines twice - the file above, the rows it opens as below:
#
#   physics-query-rows.png  the ray asked of the space state directly, in both spellings, with the
#                           shape query beside them staying the honest code it is.
#   tween-chain-rows.png    the step of a held tween chain, which got no table entry BECAUSE the
#                           reading it already has says more than an entry could - the node being
#                           moved, `opacity` where the line says `"modulate:a"`, the modifiers as
#                           chips, and which step follows which.
@tool
extends SceneTree

## The two staged scripts, each with the body drawn verbatim above the rows it becomes.
##
## A staging path a previous run left behind cannot always be reopened for writing, and the import
## then reads yesterday's file while everything else about the run looks right - so these names are
## this harness's alone and both files are removed on the way out.
const FIGURES: Array[Dictionary] = [
	{
		"path": "user://idiom_physics_figure.gd",
		"image": "res://docs/images/physics-query-rows.png",
		"title": "Physics Query Rows",
		"above": "The three statements the engine's own pages print, and the compact spelling of the same question",
		"below": "One Cast Ray Into row per question - and the shape query beside them staying the code it is",
		"height": 648,
		"source": "extends CharacterBody2D

@export var target: Node2D = null


func _physics_process(_delta: float) -> void:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	query.collision_mask = 2
	var sight := space_state.intersect_ray(query)
	var ground := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, target.global_position))
	var sweep := PhysicsShapeQueryParameters2D.new()
	var caught := get_world_2d().direct_space_state.intersect_shape(sweep, 8)
	print(sight, ground, caught)
",
		"shown": "	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	query.collision_mask = 2
	var sight := space_state.intersect_ray(query)
	var ground := get_world_2d()...intersect_ray(PhysicsRayQueryParameters2D.create(...))
	var caught := get_world_2d().direct_space_state.intersect_shape(sweep, 8)"
	},
	{
		"path": "user://idiom_tween_figure.gd",
		"image": "res://docs/images/tween-chain-rows.png",
		"title": "Tween Chain Rows",
		"above": "A held tween chain - the shape a SEQUENCE of movements is written in",
		"below": "The reading it already has: the node moved, the sheet's own property words, the modifiers as chips, and which step follows which",
		"height": 620,
		"source": "extends Node2D

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	var pop: Tween = create_tween()
	pop.tween_property(sprite, \"modulate:a\", 0.0, 0.25).set_trans(Tween.TRANS_SINE)
	pop.tween_property(sprite, \"position:y\", -8.0, 0.3).set_ease(Tween.EASE_OUT)
	pop.set_parallel()
	pop.tween_property(sprite, \"scale\", Vector2.ONE, 0.2)
",
		"shown": "	var pop: Tween = create_tween()
	pop.tween_property(sprite, \"modulate:a\", 0.0, 0.25).set_trans(Tween.TRANS_SINE)
	pop.tween_property(sprite, \"position:y\", -8.0, 0.3).set_ease(Tween.EASE_OUT)
	pop.set_parallel()
	pop.tween_property(sprite, \"scale\", Vector2.ONE, 0.2)"
	}
]

var _index: int = 0
var _frames: int = 0
var _viewport: EventSheetViewport = null


func _init() -> void:
	_stage(FIGURES[0])
	process_frame.connect(_on_frame)


## One figure built into the editor's own window: the body verbatim over the rows it opens as.
##
## The sheet is opened BEFORE anything else is built: an ACE registry constructed and left
## unrefreshed is a registry with no vocabulary in it, and the lifter matches templates against
## whatever registry is current - so importing after one exists reads the file as a verbatim block.
func _stage(figure: Dictionary) -> void:
	var sheet: EventSheetResource = _staged_sheet(figure)
	for child: Node in root.get_children():
		root.remove_child(child)
		child.queue_free()
	root.title = str(figure["title"])
	root.size = Vector2i(1160, int(figure["height"]))
	root.gui_embed_subwindows = true
	var base := Color("#252525")
	var background: ColorRect = ColorRect.new()
	background.color = base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var column: VBoxContainer = VBoxContainer.new()
	column.position = Vector2(10, 8)
	column.size = Vector2(1140, int(figure["height"]) - 16)
	column.add_theme_constant_override("separation", 8)
	root.add_child(column)
	column.add_child(_caption(str(figure["above"])))
	column.add_child(_code_block(str(figure["shown"])))
	column.add_child(_caption(str(figure["below"])))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_viewport = EventSheetViewport.new()
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	scroll.add_child(_viewport)
	_viewport.set_sheet(sheet)
	_frames = 0


## A muted heading over each half, so the figure says which is which without a caption elsewhere.
func _caption(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("#8b9099"))
	return label


## The staged body shown verbatim, in the editor's own ink.
func _code_block(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("#ced0d2"))
	return label


## The sheet, opened from the staged file the way a reader's own script is opened.
func _staged_sheet(figure: Dictionary) -> EventSheetResource:
	var handle: FileAccess = FileAccess.open(str(figure["path"]), FileAccess.WRITE)
	if handle != null:
		handle.store_string(str(figure["source"]))
		handle.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(str(figure["path"]))
	if sheet == null:
		return null
	var style := EventSheetEditorStyle.new()
	style.ensure_defaults()
	var base := Color("#252525")
	EventSheetGodotTheme.apply(style, base, base.darkened(0.15), base.darkened(0.25),
		Color("#569eff"), Color("#ced0d2"))
	sheet.editor_style = style
	return sheet


## Whether the build in front of us is the settled one - the sheet is rebuilt more than once on the
## way up (the project scan finishes some frames after the file is opened), so the shot waits for
## rows to exist rather than for a frame count that happened to work once.
func _rows_built() -> bool:
	return not _viewport._root_rows.is_empty()


func _on_frame() -> void:
	_frames += 1
	if _frames < 12 or (not _rows_built() and _frames < 400):
		return
	var figure: Dictionary = FIGURES[_index]
	var image: Image = root.get_texture().get_image()
	image.save_png(str(figure["image"]))
	print("[preview] %s %dx%d" % [figure["title"], image.get_width(), image.get_height()])
	DirAccess.remove_absolute(str(figure["path"]))
	_index += 1
	if _index >= FIGURES.size():
		quit(0)
		return
	_stage(FIGURES[_index])
