extends Control

var selected = 0


func _ready():
	$Play.pressed.connect(func(): start_game())
	$Quit.pressed.connect(func(): get_tree().quit())


func start_game():
	get_tree().change_scene_to_file("res://level.tscn")


func focus_entry(index):
	selected = index
