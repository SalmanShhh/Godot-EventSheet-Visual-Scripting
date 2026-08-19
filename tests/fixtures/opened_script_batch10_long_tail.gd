class_name LongTailReader
extends Node3D

@onready var http: HTTPRequest = $HTTPRequest
@onready var lamp: PointLight2D = $PointLight2D
@onready var film: VideoStreamPlayer = $VideoStreamPlayer
@onready var horn: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var cam: Camera3D = $Camera3D
@onready var music_a: AudioStreamPlayer = $MusicA
@onready var music_b: AudioStreamPlayer = $MusicB
var last_data := ""
var target: Node3D


func load_scores() -> void:
	http.request("https://example.com/scores")


func light_the_level() -> void:
	lamp.energy = 0.5
	lamp.shadow_enabled = true


func show_the_intro() -> void:
	film.stream = load("res://intro.ogv")
	film.play()
	horn.max_distance = 600
	horn.attenuation = 2.0


func turn_the_head(relative: Vector2) -> void:
	rotate_y(-relative.x * 0.002)
	cam.rotate_x(-relative.y * 0.002)
	cam.rotation.x = clamp(cam.rotation.x, -1.2, 1.2)
	look_at(target.global_position, Vector3.UP)


func fade_the_music(t: float) -> void:
	music_a.volume_db = linear_to_db(1.0 - t)
	music_b.volume_db = linear_to_db(t)


func bake_the_level() -> void:
	WorkerThreadPool.add_task(chunk_of.bind(1))
	WorkerThreadPool.wait_for_task_completion(1)


func stop_listening() -> void:
	film.finished.disconnect(on_video_done)


func chunk_of(index: int) -> void:
	last_data = str(index)


func on_video_done() -> void:
	call("light_the_level")
