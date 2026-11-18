extends Area2D

var score: int = 0
var lives: int = 3
var combo: int = 0


func _ready() -> void:
	print("level start")


func _process(_delta: float) -> void:
	combo = max(combo - 1, 0)


func on_coin_taken() -> void:
	score += 5
	combo += 1
	print("coin taken")


func on_coin_lost() -> void:
	if lives > 0:
		lives -= 1


func on_gem_taken() -> void:
	score += 5
	combo += 1
	print("gem taken")


func on_gem_lost() -> void:
	if lives > 0:
		lives -= 1


func on_key_taken() -> void:
	score += 5
	combo += 1
	print("key taken")


func on_key_lost() -> void:
	if lives > 0:
		lives -= 1


func on_heart_taken() -> void:
	score += 5
	combo += 1
	print("heart taken")


func on_heart_lost() -> void:
	if lives > 0:
		lives -= 1


func on_star_taken() -> void:
	score += 5
	combo += 1
	print("star taken")


func on_star_lost() -> void:
	if lives > 0:
		lives -= 1


func on_shield_taken() -> void:
	score += 5
	combo += 1
	print("shield taken")


func on_shield_lost() -> void:
	if lives > 0:
		lives -= 1


func on_door_taken() -> void:
	score += 5
	combo += 1
	print("door taken")


func on_door_lost() -> void:
	if lives > 0:
		lives -= 1


func on_chest_taken() -> void:
	score += 5
	combo += 1
	print("chest taken")


func on_chest_lost() -> void:
	if lives > 0:
		lives -= 1


func on_torch_taken() -> void:
	score += 5
	combo += 1
	print("torch taken")


func on_torch_lost() -> void:
	if lives > 0:
		lives -= 1


func on_bomb_taken() -> void:
	score += 5
	combo += 1
	print("bomb taken")


func on_bomb_lost() -> void:
	if lives > 0:
		lives -= 1
