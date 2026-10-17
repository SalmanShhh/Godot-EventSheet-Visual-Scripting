extends Node
# Autoload ("SaveManager"). Writes every node in the "persist" group to one file.

const SAVE_FILE := "user://remembered.cfg"

var slot := 0
var last_saved_at = ""
var settings = {"volume": 0.8, "fullscreen": false}
var unlocked_levels: Array[String] = []


func _ready():
	add_to_group("persist")
	load_game()


func save_state() -> Dictionary:
	return {
		"slot": slot,
		"settings": settings.duplicate(true),
		"unlocked_levels": unlocked_levels.duplicate(true)
	}


func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	slot = int(state.get("slot", slot))
	settings = (state.get("settings", {}) as Dictionary).duplicate(true)
	unlocked_levels.assign((state.get("unlocked_levels", unlocked_levels) as Array).duplicate(true))


func save_game():
	var config := ConfigFile.new()
	for node in get_tree().get_nodes_in_group("persist"):
		config.set_value("vars", str(node.get_path()), node.save_state())
	last_saved_at = Time.get_datetime_string_from_system()
	config.save(SAVE_FILE)


func load_game():
	var config := ConfigFile.new()
	if config.load(SAVE_FILE) != OK:
		return
	for node in get_tree().get_nodes_in_group("persist"):
		var key := str(node.get_path())
		if config.has_section_key("vars", key):
			node.load_state(config.get_value("vars", key))
