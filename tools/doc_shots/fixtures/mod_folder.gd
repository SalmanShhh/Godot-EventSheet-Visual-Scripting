extends Node
## Keeps an eye on the folder the player drops mods into.


func _enter_tree() -> void:
	$FolderWatcher.watch_folder("user://mods", 2)


func _exit_tree() -> void:
	$FolderWatcher.stop_watching()
