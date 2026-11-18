extends CharacterBody3D

@onready var cam: Camera3D = $CameraPivot/Camera3D
@onready var arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_state: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")
@onready var horn: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var rock: MeshInstance3D = $Rock
@onready var env: Environment = $WorldEnvironment.environment
@onready var name_tag: Label3D = $NameTag
@onready var hp_bar: Sprite3D = $HpBar
@onready var panel_view: SubViewport = $Screen/SubViewport
@export var run_speed := 6.0
var moon_angle := 0.0
var moon_radius := 8.0
var moon: Node3D = null


func _physics_process(delta: float) -> void:
	var input := Input.get_vector(&"left", &"right", &"forward", &"back")
	var cam_basis := cam.global_transform.basis
	var dir := cam_basis.x * input.x + cam_basis.z * input.y
	dir.y = 0.0
	dir = dir.normalized()
	velocity.x = dir.x * run_speed
	velocity.z = dir.z * run_speed
	velocity.y -= 30.0 * delta


func circle_the_moon(delta: float) -> void:
	moon_angle += delta
	global_position = moon.global_position + Vector3(cos(moon_angle), 0.0, sin(moon_angle)) * moon_radius
	arm.spring_length = 6.0


func animate(pace: float) -> void:
	anim_tree.set("parameters/Locomotion/blend_position", pace)
	anim_state.travel("Jump")
	anim_tree.set("parameters/TimeScale/scale", 0.5)
	anim_tree.set("parameters/Shoot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func tune() -> void:
	horn.max_distance = 40.0
	horn.unit_size = 3.0
	rock.visibility_range_begin = 10.0
	rock.visibility_range_end = 90.0
	rock.transparency = 0.4
	rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func apply_dusk() -> void:
	env.fog_enabled = true
	env.fog_density = 0.02
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.ambient_light_energy = 0.3
	RenderingServer.global_shader_parameter_set("wind_strength", 2.0)


func dress_the_knight(hp: float) -> void:
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.no_depth_test = true
	hp_bar.pixel_size = 0.004
	hp_bar.region_rect.size.x = hp
	panel_view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
