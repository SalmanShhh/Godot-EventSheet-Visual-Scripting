# EventForge - render harness (dev tool) for the Second View pack RUNNING: a real 2D world, a real
# main camera on the player, and a real second view of the same world rendered into the minimap frame
# in the corner. Nothing here is drawn by hand - the corner panel is a TextureRect holding the
# SubViewport the pack built, so what the picture shows is the pack working. Run NON-headless (a
# headless run has no renderer, so it can produce no picture at all):
#   godot --path . --script tools/render_second_view_running_preview.gd
@tool
extends SceneTree

const PACK: String = "res://eventsheet_addons/second_view/second_view_addon.gd"

## The corner frame, in pixels. The pack sizes the view's render to this on its own.
const FRAME_SIZE: Vector2 = Vector2(260.0, 170.0)

var _frames: int = 0
var _player: Node2D = null
var _frame: TextureRect = null


## One coloured block of the world, so the minimap has something recognisable to be a small copy of.
func _block(at: Vector2, extent: Vector2, tint: Color) -> Polygon2D:
	var block: Polygon2D = Polygon2D.new()
	block.polygon = PackedVector2Array([Vector2.ZERO, Vector2(extent.x, 0.0), extent, Vector2(0.0, extent.y)])
	block.position = at
	block.color = tint
	return block


func _init() -> void:
	root.title = "Second View running"
	root.size = Vector2i(1000, 560)

	var world: Node2D = Node2D.new()
	world.name = "World"
	root.add_child(world)

	var ground: Polygon2D = _block(Vector2(-1400.0, -900.0), Vector2(2800.0, 1800.0), Color("#20262f"))
	world.add_child(ground)
	var palette: PackedStringArray = PackedStringArray(["#3f6f8f", "#8f6a3f", "#4f8f5f", "#8f4f6f", "#6f5f8f"])
	for column: int in 9:
		for row: int in 6:
			if (column + row) % 3 == 0:
				continue
			var tint: Color = Color(palette[(column * 6 + row) % palette.size()])
			world.add_child(_block(Vector2(-1150.0 + column * 260.0, -760.0 + row * 260.0),
				Vector2(170.0, 150.0), tint))

	var player: Node2D = Node2D.new()
	player.name = "Player"
	player.position = Vector2(-120.0, 40.0)
	world.add_child(player)
	player.add_child(_block(Vector2(-22.0, -22.0), Vector2(44.0, 44.0), Color("#ffd166")))

	# The game's own camera, so the big picture is an ordinary close-up view of the world.
	var main_camera: Camera2D = Camera2D.new()
	main_camera.enabled = true
	player.add_child(main_camera)

	# The HUD the minimap sits on. A CanvasLayer belongs to the viewport it is in rather than to the
	# world, which is exactly why none of this appears inside the minimap.
	var hud: CanvasLayer = CanvasLayer.new()
	hud.name = "HUD"
	root.add_child(hud)
	var hud_root: Control = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hud_root)
	var panel: Panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.size = FRAME_SIZE + Vector2(12.0, 12.0)
	panel.position = Vector2(-FRAME_SIZE.x - 36.0, 24.0)
	hud_root.add_child(panel)
	var frame: TextureRect = TextureRect.new()
	frame.name = "MinimapFrame"
	frame.position = Vector2(6.0, 6.0)
	frame.size = FRAME_SIZE
	panel.add_child(frame)

	_player = player
	_frame = frame
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 1:
		# The pack itself, as the autoload it ships as, added once the tree is really running - a
		# SceneTree's _init happens before that, and a view needs the viewport it is a second picture
		# of. Two calls afterwards: the same two rows the sheet shows.
		var views: Node = (load(PACK) as GDScript).new()
		views.name = "SecondView"
		root.add_child(views)
		views.make_a_view("minimap", _player, 0.25)
		views.show_view_in("minimap", _frame)
		return
	if _frames < 12:
		return
	var img: Image = root.get_texture().get_image()
	img.save_png("res://docs/images/second-view-running.png")
	print("[preview] second view running %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
