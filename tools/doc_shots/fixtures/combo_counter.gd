extends Node2D

var score: int = 0
var __every_1: float = 0.0
var __changed_prev_1: Variant = null
var __changed_seen_1: bool = false


func __has_changed_1(current: Variant) -> bool:
	if not __changed_seen_1:
		__changed_seen_1 = true
		__changed_prev_1 = current
		return false
	if current == __changed_prev_1:
		return false
	__changed_prev_1 = current
	return true


func _process(_delta: float) -> void:
	__every_1 += get_process_delta_time()
	if __every_1 >= 0.5:
		__every_1 = fmod(__every_1, 0.5)
		score = score + 1
	if __has_changed_1(score):
		create_tween().tween_property(self, "scale", Vector2(1.15, 1.15), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if Time.get_ticks_msec() >= int(get_meta(&"__ef_cool_" + str("dash"), 0)):
		set_meta(&"__ef_cool_" + str("dash"), Time.get_ticks_msec() + int(1.5 * 1000.0))
		create_tween().tween_property(self, "position", position + Vector2(160, 0), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	score = 0
