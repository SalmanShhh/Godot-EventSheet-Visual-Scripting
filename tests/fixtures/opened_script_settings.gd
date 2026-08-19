## A tuned script whose SETTINGS are the subject: every @export hint family a designer actually
## reaches for, so the setting rows can be pinned against the facts the Inspector would show.
class_name TunedKnobs
extends Node2D

## How fast it walks, in pixels per second.
@export_group("Movement")
@export_range(0, 20, 0.5) var speed: float = 5.0
@export_enum("Walk", "Run", "Fly") var mode: int = 0
@export_range(0, 1) var grip: float = 0.5

@export_group("Look")
@export_file("*.png") var portrait: String = ""
@export_dir var shot_folder: String = ""
@export_multiline var intro_text: String = ""
@export_color_no_alpha var tint: Color = Color.WHITE
@export_flags("Fire", "Water", "Wind") var elements: int = 0
