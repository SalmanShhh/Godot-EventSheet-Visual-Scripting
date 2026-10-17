@tool
extends Node2D
## Spawns waves of enemies around the player. Tuned in the Inspector, previewed in the editor.

signal wave_started(index)
signal wave_cleared(index: int)

enum Pattern { RING, LINE, RANDOM }

const MAX_ALIVE = 64
const ENEMY_SCENES = {
	"slime": preload("res://tests/fixtures/existing_project_large/weapon_data.gd"),
}

@export var pattern: Pattern = Pattern.RING:
	set(value):
		pattern = value
		notify_property_list_changed()
		queue_redraw()
@export var use_timer = true:
	set(value):
		use_timer = value
		notify_property_list_changed()
@export_range(0, 100) var spawn_chance = 50
@export_range(0.5, 10.0) var interval: float = 2.0
@export_range(1,20) var per_wave := 5
@export var radius = 240.0
@export var line_length = 400
@export var tint = Color.WHITE
@export var offsets = [Vector2.ZERO]
@export var weights = {}
@export_group("Waves", "wave_")
@export var wave_count = 3
@export var wave_delay = 1.5 # seconds between waves
@export_subgroup("Boss")
@export var wave_boss_every = 5
@export_subgroup("")
@export var wave_scaling = 1.1
@export_group("")
@export var debug_draw = false

static var total_spawned = 0

var alive = []
var _wave = 0
var _timer = 0.0
var _rng = RandomNumberGenerator.new()
var _last = null
var _hex = 0xFF
var _big = 1_000_000
var _sci = 1e3
var _neg = -1
var _half = .5
var _name = "spawner"
var _key = &"enemy"
var _path = ^"Enemies"


func _validate_property(property: Dictionary) -> void:
	if property.name == "interval" and not use_timer:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == "line_length" and pattern != Pattern.LINE:
		property.usage |= PROPERTY_USAGE_READ_ONLY


func _ready():
	if Engine.is_editor_hint():
		return
	_rng.randomize()
	start_wave()


func _process(delta):
	if Engine.is_editor_hint() or not use_timer:
		return
	_timer += delta
	if _timer >= interval and alive.size() < MAX_ALIVE:
		_timer = 0.0
		_spawn_one()


func _draw():
	if not debug_draw:
		return
	match pattern:
		Pattern.RING:
			draw_arc(Vector2.ZERO, radius, 0, TAU, 48, tint)
		Pattern.LINE:
			draw_line(Vector2(-line_length / 2.0, 0), Vector2(line_length / 2.0, 0), tint)
		_:
			draw_circle(Vector2.ZERO, 8, tint)


func start_wave():
	_wave += 1
	wave_started.emit(_wave)
	for i in per_wave:
		if _rng.randi_range(0, 100) < spawn_chance:
			_spawn_one()


func _spawn_one():
	var enemy = ENEMY_SCENES["slime"]
	_last = enemy
	total_spawned += 1
	alive.append(enemy)


func _on_enemy_died(enemy):
	alive.erase(enemy)
	if alive.is_empty():
		wave_cleared.emit(_wave)
		if _wave < wave_count:
			await get_tree().create_timer(wave_delay).timeout
			start_wave()
