# The pause menu every project writes by hand: a layout put OVER the running game rather than
# instead of it, the game paused underneath it, and both undone again when it closes. Written the
# way people actually type it - a local, a name, and the tree root - so the recogniser is measured
# against what is written rather than against what the compiler emits.
#
# The last two functions are the BOUNDARY, and they are here on purpose. `spawn_enemy` is the bare
# one-liner that has always read as Spawn Scene Instance and still does; `add_hud` is the same three
# statements as the pause menu except that the copy goes under THIS node instead of under the tree
# root, which is a different thing to do and is left as the code it is.
extends Node


func open_pause_menu() -> void:
	var menu = load("res://pause_menu.tscn").instantiate()
	menu.name = "PauseMenu"
	get_tree().root.add_child(menu)
	get_tree().paused = true


func open_inventory() -> void:
	var panel := preload("res://inventory.tscn").instantiate()
	panel.name = "Inventory"
	get_tree().root.add_child(panel)


func close_pause_menu() -> void:
	get_tree().paused = false


func spawn_enemy() -> void:
	add_child(load("res://enemy.tscn").instantiate())


func add_hud() -> void:
	var hud = load("res://hud.tscn").instantiate()
	hud.name = "Hud"
	add_child(hud)
