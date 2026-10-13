extends Node
# Autoload ("GameState" in Project Settings > Globals). Score, coins, and the save file.

signal score_changed(score)
signal level_finished(level_name: String)

const SAVE_PATH = "user://savegame.cfg"
const LEVELS = [
	"res://levels/level_1.tscn",
	"res://levels/level_2.tscn",
	"res://levels/level_3.tscn",
]

var score = 0:
	set(value):
		score = max(value, 0)
		score_changed.emit(score)
var coins := 0
var current_level := 0
var unlocked := {}


class SaveSlot:
	var name: String
	var score: int
	var level: int

	func _init(p_name := "Slot", p_score := 0, p_level := 0):
		name = p_name
		score = p_score
		level = p_level

	func to_dict() -> Dictionary:
		return {"name": name, "score": score, "level": level}


func _ready():
	load_game()


func add_coins(amount):
	coins += amount
	score += amount * 10


func finish_level():
	level_finished.emit(LEVELS[current_level].get_file().get_basename())
	unlocked[current_level + 1] = true
	if current_level + 1 < LEVELS.size():
		current_level += 1
		get_tree().change_scene_to_file(LEVELS[current_level])
	save_game()


func save_game():
	var config = ConfigFile.new()
	var slot = SaveSlot.new("Main", score, current_level)
	for key in slot.to_dict():
		config.set_value("save", key, slot.to_dict()[key])
	config.set_value("save", "coins", coins)
	config.save(SAVE_PATH)


func load_game():
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	score = config.get_value("save", "score", 0)
	coins = config.get_value("save", "coins", 0)
	current_level = config.get_value("save", "level", 0)
