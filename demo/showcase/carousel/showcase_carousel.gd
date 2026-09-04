class_name CarouselOfJuice
extends Node2D
## @ace_group(uid="juice", name="Juice", toggleable=true)

## Beats elapsed.
@export_range(0, 9999, 1) var beat: int = 0
## Spring kick strength.
@export_range(1, 3, 0.05) var intensity: float = 1.4:
	set(value):
		intensity = clampf(value, 1, 3)
## Is the Juice group running.
@export var party_on: bool = true
## Impact moments played.
@export_range(0, 9999, 1) var moments_played: int = 0
var __group_juice_active: bool = true
var __every_beat_caro: float = 0.0
var __every_spin_caro: float = 0.0

func _process(delta: float) -> void:
	__every_beat_caro += delta
	# @group:juice
	if __group_juice_active and __every_beat_caro >= maxf(0.5, 0.001):
		__every_beat_caro = fmod(__every_beat_caro, maxf(0.5, 0.001))
		beat += 1
		juice_tile(beat, intensity * 5.0)
		$ScreenFx.pulse_post_effect("vignette", 0.45, 0.35)
		$JuiceBehavior.chromatic_shake(4.0, 0.3, "reducing", randf_range(0.0, 360.0))
	__every_spin_caro += delta
	# @group:juice
	if __group_juice_active and __every_spin_caro >= maxf(2.0, 0.001):
		__every_spin_caro = fmod(__every_spin_caro, maxf(2.0, 0.001))
		$TweenBehavior.tween_rotation(rotation_degrees + 360.0, 1.8)
		$FlashBehavior.flash(0.25)
	if Input.is_action_just_pressed(&"ui_accept"):
		party_on = true
		set("__group_" + "juice" + "_active", true)
		$Hero/SpringBehavior.add_impulse("__scale", intensity * 6.0)
		$Hero/FlashBehavior.flash(0.4)
		$JuiceBehavior.moment("impact", intensity * 0.6)
		moments_played += 1
		$ScreenFx.add_post_effect("scanlines", "party", 0.3)
		$ScreenFx.save_look("user://looks/carousel.tres", "Carousel")
		$ScreenFx.use_look(ResourceLoader.load("user://looks/carousel.tres", "", ResourceLoader.CACHE_MODE_IGNORE))
	elif Input.is_action_just_pressed(&"ui_cancel"):
		party_on = false
		set("__group_" + "juice" + "_active", false)
		$Hero/TweenBehavior.tween_rotation(0.0, 0.4)
		$JuiceBehavior.moment("calm", 1.0)
		$SceneFlowBehavior.reload_scene_with("fade", 0.6, "smooth")
	else:
		$Hero/SpringBehavior.spring_host_scale(1.0 + sin(Time.get_ticks_msec() / 1000.0) * 0.04)

func _ready() -> void:
	for c: Node in $Tiles.get_children():
		c.get_node("SineBehavior").active = true
	$BlendModes.blend_as($Tiles/Tile3, "screen", 1.0)

## @ace_hidden
func juice_tile(index: int, kick: float) -> void:
	var t: Node2D = $Tiles.get_child(index % $Tiles.get_child_count())
	t.get_node("SpringBehavior").add_impulse("__scale", kick)
	t.get_node("SpringBehavior").spring_host_scale(1.0)
	t.get_node("TweenBehavior").tween_rotation(t.rotation_degrees + 90.0, 0.5)

# [b]Carousel of Juice[/b] - 8 tiles sine-sway and spring-pop on the beat (one reused juice_tile function), and every beat pulses a vignette over the screen and pulls the colour channels apart along a fresh angle. A runtime-toggleable Juice group plus an if/elif/else keypress chain re-skin the board: [b]ui_accept[/b] starts the party - an impact moment at your own intensity, one more effect on the post stack, then the live look written to user:// and worn straight back off disk - and [b]ui_cancel[/b] calms it and starts over behind a fade. One tile is drawn blended as screen - Blend Modes ships as an autoload, and this row is that autoload's verb called on a child node of the same name, so the showcase runs with no project setting added. Watch beat/intensity/moments_played stream in Live Values.
