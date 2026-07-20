class_name DrawLabDemo
extends Node2D

var baked: bool = false
var comet_angle: float = 0.0
var facing_deg: float = 0.0
var paste_timer: float = 0.0
var __every_paint: float = 0.0


func _ready() -> void:
	# Three prefab stampings prove position / scale / rotation reuse of ONE .tres.
	var marker: Resource = load("res://demo/showcase/draw_lab/target_marker.tres")
	$PaintLayer/Paint.draw_prefab(marker, 180.0, 140.0, 1.0, 0.0)
	$PaintLayer/Paint.draw_prefab(marker, 980.0, 500.0, 0.6, 45.0)
	$PaintLayer/Paint.draw_prefab(marker, 180.0, 520.0, 1.4, 15.0)
	$FxLayer/Fx.start_ribbon($Comet, 34, 7.0, Color(0.45, 0.9, 1.0, 0.85))
	# Paste demo - build one gem texture and give the orbiting comet a gem icon. The tick leaves a
	# Paste Node trail behind it and bakes a whole gem LAYER onto the canvas on its first run.
	var gem_image: Image = Image.create(20, 20, false, Image.FORMAT_RGBA8)
	gem_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for gem_y: int in 20:
		for gem_x: int in 20:
			if absi(gem_x - 10) + absi(gem_y - 10) <= 8:
				gem_image.set_pixel(gem_x, gem_y, Color(1.0, 0.84, 0.32))
	var comet_icon: Sprite2D = Sprite2D.new()
	comet_icon.name = "Icon"
	comet_icon.texture = ImageTexture.create_from_image(gem_image)
	$Comet.add_child(comet_icon)


func _physics_process(delta: float) -> void:
	facing_deg += 40.0 * delta
	comet_angle += 1.4 * delta
	$Comet.position = Vector2(576.0, 324.0) + Vector2.from_angle(comet_angle) * 205.0
	# The live drawings: re-issued every tick, wiped by their AUTO-CLEAR canvases.
	$Player/Vision.draw_line_of_sight($Player.global_position.x, $Player.global_position.y, facing_deg, 80.0, 280.0, 1, Color(1.0, 0.92, 0.45, 0.3))
	$Enemy/Telegraph.draw_canvas_cone($Enemy.global_position.x, $Enemy.global_position.y, -facing_deg * 1.5, 50.0, 170.0, Color(1.0, 0.3, 0.25, 0.4))
	if Input.is_action_just_pressed("ui_accept"):
		$PaintLayer/Paint.draw_prefab(load("res://demo/showcase/draw_lab/target_marker.tres"), $Player.global_position.x, $Player.global_position.y, 0.8, facing_deg)
	# Paste Node the orbiting comet's gem onto the PERSISTENT canvas ~8x a second: a trail of baked
	# gem stamps follows the orbit (the discrete-decal counterpart to the comet's live cyan ribbon).
	paste_timer -= delta
	if paste_timer <= 0.0 and $Comet.has_node("Icon"):
		paste_timer = 0.12
		$PaintLayer/Paint.paste_node($Comet/Icon)
	# Paste Layer In Box (once, at load): scatter a gem LAYER, bake every gem inside the box onto the
	# persistent canvas, then free the originals - one texture instead of N sprites. Done on the first
	# live tick (an on-ready bake would buffer before the canvas surface exists).
	if not baked and $Comet.has_node("Icon"):
		baked = true
		var gem_texture: Texture2D = $Comet/Icon.texture
		var gems: Node2D = Node2D.new()
		add_child(gems)
		for gem_spot: Vector2 in [Vector2(80.0, 185.0), Vector2(150.0, 185.0), Vector2(220.0, 185.0), Vector2(290.0, 185.0), Vector2(360.0, 185.0)]:
			var gem: Sprite2D = Sprite2D.new()
			gem.texture = gem_texture
			gems.add_child(gem)
			gem.global_position = gem_spot
		$PaintLayer/Paint.paste_layer_in_box(gems, 50.0, 170.0, 340.0, 35.0)
		gems.queue_free()


func _process(delta: float) -> void:
	__every_paint += delta
	if __every_paint >= maxf(0.1, 0.001):
		__every_paint = fmod(__every_paint, maxf(0.1, 0.001))
		$PaintLayer/Paint.draw_canvas_circle($Player.global_position.x, $Player.global_position.y + 12.0, 7.0, Color(0.35, 0.6, 1.0, 0.25))

# [b]Draw Lab[/b] - four Drawing Canvases with different jobs. The Player carries an AUTO-CLEAR canvas redrawing a raycast Line Of Sight fan every tick (the walls carve it); the Enemy carries one redrawing a rotating attack-telegraph cone; the whole-screen PERSISTENT canvas keeps everything drawn on it - the paint trail dripping under the Player and the target-marker DRAWING PREFABS (an ordered shape formation authored as a .tres, replayed by Draw Prefab at any position/scale/rotation - press Space to stamp one where you stand); and the center canvas ribbons the orbiting comet.
