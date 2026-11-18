extends Node2D

@onready var beat: Timer = $Beat
@onready var hp_bar: ProgressBar = $HpBar


func _ready() -> void:
	beat.set_one_shot(true)
	hp_bar.set_indeterminate(true)
	hp_bar.set_show_percentage(false)
