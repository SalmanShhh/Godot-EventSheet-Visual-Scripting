extends SceneTree


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	print("Counting the scenes under: %s" % ", ".join(args))
	quit(0)
