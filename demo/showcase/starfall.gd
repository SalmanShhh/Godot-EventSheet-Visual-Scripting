class_name Starfall
extends Node2D

enum State { PLAYING, GAME_OVER }

## Misses remaining.
@export var lives: int = 3
## Stars caught.
@export_range(0, 999, 1) var score: int = 0
## Ship move speed (px/s).
@export var ship_speed: float = 320.0
## 0=PLAYING, 1=GAME_OVER.
@export var state: int = 0
var __every_spawn_sf: float = 0.0

func _ready() -> void:
	$Ship.position = Vector2(576, 590)

func _physics_process(delta: float) -> void:
	match state:
		State.PLAYING:
			pass
		State.GAME_OVER:
			if Input.is_action_just_pressed(&"ui_accept"):
				score = 0
				lives = 3
				state = State.PLAYING
				for s: Node in get_tree().get_nodes_in_group("stars"):
					s.queue_free()
		_:
			pass
	if state == State.PLAYING and Input.is_action_pressed(&"ui_left"):
		$Ship.position += Vector2(-ship_speed * delta, 0.0)
	elif state == State.PLAYING and Input.is_action_pressed(&"ui_right"):
		$Ship.position += Vector2(ship_speed * delta, 0.0)
	$Ship.position = Vector2(clampf($Ship.position.x, 40.0, 1112.0), $Ship.position.y)
	__every_spawn_sf += delta
	if state == State.PLAYING and __every_spawn_sf >= maxf(2.0, 0.001):
		__every_spawn_sf = fmod(__every_spawn_sf, maxf(2.0, 0.001))
		var __spawn_star = load("res://demo/showcase/star.tscn").instantiate()
		__spawn_star.position = Vector2(randf_range(60.0, 1100.0), -20.0)
		__spawn_star.rotation_degrees = 90.0
		add_child(__spawn_star)
	if state == State.PLAYING:
		for star in get_tree().get_nodes_in_group("stars"):
			if not (star.position.y > 560.0):
				continue
			if absf(star.position.x - $Ship.position.x) < 64.0:
				score += 1
			else:
				lives -= 1
			star.queue_free()
	if lives <= 0 and state == State.PLAYING:
		state = State.GAME_OVER

func _process(delta: float) -> void:
	$ScoreLabel.text = "Score %d    Lives %d    %s" % [score, lives, ("GAME OVER - press Enter" if state == State.GAME_OVER else "PLAYING")]

# [b]Starfall[/b] — a complete restartable arcade game authored as events: move the ship (ui_left/ui_right) to catch falling stars. Shows an enum+match state machine (PLAYING/GAME_OVER), a group pick-filter that scores & culls stars, an Every-2s spawner, and if/elif input branches. Miss 3 and it's GAME OVER — press ui_accept to restart.
