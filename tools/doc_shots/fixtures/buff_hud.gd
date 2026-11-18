extends Node


func _process(delta: float) -> void:
	for buff_id in $StatForge.each_buff():
		print(buff_id)
