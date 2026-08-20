# EventForge - render harness (dev tool) for the four game-shape readings: a pity roll, the stealth
# detection loop, a boss phase ladder and a mission clock, each opened from hand-written GDScript so
# the rows shown are the readings themselves. Run NON-headless:
#   godot --path . --script tools/render_game_shapes_preview.gd
@tool
extends SceneTree

const SHAPES: Array = [
	["pity", "res://docs/images/reading-pity.png", "func _open_chest() -> String:\n\tpity += 1\n\tvar chance := base_chance + pity_step * float(pity)\n\tif pity >= pity_cap or randf() < chance:\n\t\tpity = 0\n\t\treturn \"rare\"\n\treturn \"common\"\n"],
	["detection", "res://docs/images/reading-detection.png", "func _physics_process(delta: float) -> void:\n\tif can_see_player and not player_is_hidden:\n\t\tsuspicion = minf(suspicion + detect_rate * delta, 100.0)\n\t\tlast_known = player.global_position\n\telse:\n\t\tsuspicion = maxf(suspicion - calm_rate * delta, 0.0)\n"],
	["boss", "res://docs/images/reading-boss-phases.png", "func take_damage(amount: float) -> void:\n\thp -= amount\n\tif phase == 1 and hp <= max_hp * 0.6:\n\t\tphase = 2\n\t\t_enter_phase_2()\n\tif phase == 2 and hp <= max_hp * 0.25:\n\t\tphase = 3\n\t\t_enter_phase_3()\n"],
	["mission", "res://docs/images/reading-mission-timer.png", "func _process(delta: float) -> void:\n\tmission_left = maxf(0.0, mission_left - delta)\n\tlabel.text = (\"%02d:%02d\" % [int(mission_left) / 60, int(mission_left) % 60])\n\tif mission_left <= 0.0:\n\t\tmission_failed.emit()\n"]
]

var _frames: int = 0
var _index: int = 0
var _viewport: EventSheetViewport = null
var _scroll: ScrollContainer = null


func _init() -> void:
	root.title = "Game shapes"
	root.size = Vector2i(1100, 420)
	var modern_base := Color("#252525")
	var background: ColorRect = ColorRect.new()
	background.color = modern_base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(8, 8)
	_scroll.size = Vector2(1084, 404)
	root.add_child(_scroll)
	_show(0)
	process_frame.connect(_on_frame)


func _show(index: int) -> void:
	if _viewport != null:
		_viewport.queue_free()
	_viewport = EventSheetViewport.new()
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	_scroll.add_child(_viewport)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(
		"extends Node\n\n\n" + str((SHAPES[index] as Array)[2]))
	var modern_style := EventSheetEditorStyle.new()
	modern_style.ensure_defaults()
	EventSheetGodotTheme.apply(modern_style, modern_base_color(), modern_base_color().darkened(0.15),
		modern_base_color().darkened(0.25), Color("#569eff"), Color("#ced0d2"))
	sheet.editor_style = modern_style
	_viewport.set_sheet(sheet)


func modern_base_color() -> Color:
	return Color("#252525")


func _on_frame() -> void:
	_frames += 1
	if _frames < 8:
		return
	var shape: Array = SHAPES[_index]
	var img: Image = root.get_texture().get_image()
	img.save_png(str(shape[1]))
	print("[preview] %s %dx%d -> %s" % [str(shape[0]), img.get_width(), img.get_height(), str(shape[1])])
	_index += 1
	if _index >= SHAPES.size():
		quit(0)
		return
	_frames = 0
	_show(_index)
