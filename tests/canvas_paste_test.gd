# EventForge - CanvasSurface "paste a node" capture math (headless-safe: no live viewport needed).
#
# The paste verbs bake a node's visual onto the canvas by (1) resolving its texture + source region + local
# destination rect from the node type, and (2) composing its world transform into canvas space. That pure
# geometry is what breaks silently, so it is pinned here on ORPHAN nodes (get_global_transform on an
# un-parented Node2D is its own transform, so no scene tree is needed). The actual rendering - a pasted
# sprite showing up on the texture, and the layer box filter including/excluding nodes - is verified by the
# non-headless runtime smoke (colored squares baked and read back), not here.
@tool
class_name CanvasPasteTest
extends RefCounted

const SURFACE := "res://eventsheet_addons/canvas_surface/canvas_surface.gd"


static func run() -> bool:
	var ok: bool = true
	var script: GDScript = load(SURFACE)
	ok = _check("canvas surface loads", script != null, true) and ok
	if script == null:
		return ok

	var surface: Node = script.new()
	var host: Node2D = Node2D.new()
	host.position = Vector2.ZERO
	surface._host = host
	surface.coordinates = "world"
	surface.canvas_width = 512
	surface.canvas_height = 512

	var tex: ImageTexture = _solid(Color(1, 0, 0), 32, 32)

	# A centered Sprite2D: local dest rect is the frame centered on the origin, no source region.
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = tex
	sprite.centered = true
	var centered: Dictionary = surface._node_texture_info(sprite)
	ok = _check("sprite texture resolves", centered.get("texture"), tex) and ok
	ok = _check("centered dest rect is frame centered on origin", centered.get("dest_rect"), Rect2(-16, -16, 32, 32)) and ok
	ok = _check("whole-texture sprite has no source region", centered.get("src_rect"), Rect2()) and ok
	ok = _check("unflipped sprite reports flip_h false", centered.get("flip_h"), false) and ok

	# Non-centered: the dest rect starts at the origin (plus offset).
	sprite.centered = false
	sprite.offset = Vector2(4, 5)
	var top_left: Dictionary = surface._node_texture_info(sprite)
	ok = _check("non-centered dest rect starts at offset", top_left.get("dest_rect"), Rect2(4, 5, 32, 32)) and ok

	# A region-enabled sprite draws only its region_rect.
	var region_sprite: Sprite2D = Sprite2D.new()
	region_sprite.texture = tex
	region_sprite.centered = false
	region_sprite.region_enabled = true
	region_sprite.region_rect = Rect2(8, 8, 16, 16)
	var region: Dictionary = surface._node_texture_info(region_sprite)
	ok = _check("region sprite source rect is the region", region.get("src_rect"), Rect2(8, 8, 16, 16)) and ok
	ok = _check("region sprite dest size matches the region", (region.get("dest_rect") as Rect2).size, Vector2(16, 16)) and ok

	# A spritesheet cell (2x2, frame 3 = bottom-right) reads that quadrant as the source.
	var sheet_sprite: Sprite2D = Sprite2D.new()
	sheet_sprite.texture = _solid(Color(0, 1, 0), 64, 64)
	sheet_sprite.hframes = 2
	sheet_sprite.vframes = 2
	sheet_sprite.frame = 3
	var cell: Dictionary = surface._node_texture_info(sheet_sprite)
	ok = _check("spritesheet frame 3 source is the bottom-right cell", cell.get("src_rect"), Rect2(32, 32, 32, 32)) and ok

	# A TextureRect pastes its whole rect from the top-left.
	var rect_node: TextureRect = TextureRect.new()
	rect_node.texture = tex
	rect_node.size = Vector2(40, 24)
	var rect_info: Dictionary = surface._node_texture_info(rect_node)
	# Pin the relationship (origin-anchored at the control's own size), not a literal - an off-tree Control's
	# size is subject to its texture minimum with no layout pass, so the exact number is not the contract.
	ok = _check("texture rect dest rect is its own size from the origin", rect_info.get("dest_rect"), Rect2(Vector2.ZERO, rect_node.size)) and ok

	# A node with no texture yields nothing to paste.
	var bare: Node2D = Node2D.new()
	ok = _check("a textureless node resolves to nothing", surface._node_texture_info(bare).is_empty(), true) and ok

	# The world -> canvas mapping: a sprite at world (100, 0) with the host at the origin lands at canvas
	# (356, 256) - the canvas is 512 wide and centered on the host, so (100,0) + (256,256).
	var placed: Sprite2D = Sprite2D.new()
	placed.texture = tex
	placed.centered = true
	placed.position = Vector2(100, 0)
	var command: Dictionary = surface._node_paste_command(placed, null)
	ok = _check("paste command is a node_stamp", command.get("kind"), "node_stamp") and ok
	ok = _check("world (100,0) maps to canvas (356,256)", (command.get("xform") as Transform2D).origin, Vector2(356, 256)) and ok

	# flip_h folds a horizontal mirror into the transform (its x basis flips sign).
	var flipped: Sprite2D = Sprite2D.new()
	flipped.texture = tex
	flipped.flip_h = true
	var flip_command: Dictionary = surface._node_paste_command(flipped, null)
	ok = _check("flip_h negates the transform x basis", (flip_command.get("xform") as Transform2D).x.x < 0.0, true) and ok

	# _enclosing_rect: an identity transform passes the local rect through unchanged.
	ok = _check("enclosing rect under identity is the input rect", surface._enclosing_rect(Transform2D.IDENTITY, Rect2(10, 20, 30, 40)), Rect2(10, 20, 30, 40)) and ok

	# _node_world_rect: a centered 32px sprite at world (100,0) occupies world Rect2(84,-16,32,32).
	ok = _check("node world rect is the transformed drawable rect", surface._node_world_rect(placed), Rect2(84, -16, 32, 32)) and ok

	sprite.free()
	region_sprite.free()
	sheet_sprite.free()
	rect_node.free()
	bare.free()
	placed.free()
	flipped.free()
	host.free()
	surface.free()
	return ok


static func _solid(color: Color, w: int, h: int) -> ImageTexture:
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] canvas_paste_test: %s" % label)
		return true
	print("[FAIL] canvas_paste_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
