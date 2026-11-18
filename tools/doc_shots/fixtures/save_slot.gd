extends Node

var data: String = ""


func _ready() -> void:
	if FileAccess.file_exists("user://save.dat"):
		data = FileAccess.get_file_as_string("user://save.dat")
	else:
		DirAccess.make_dir_recursive_absolute("user://saves")
		var __file_1 = FileAccess.open("user://save.dat", FileAccess.WRITE)
		if __file_1:
			__file_1.store_string("{}")
			__file_1.close()
