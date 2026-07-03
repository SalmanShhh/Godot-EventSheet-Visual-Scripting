# git-textconv driver: renders an EventSheetResource .tres as readable rows so PRs and
# `git diff` show events instead of serialized-resource noise. Non-sheet .tres files
# print verbatim (the driver is safe to register for all *.tres).
# Setup: see CONTRIBUTING "Reviewable sheet diffs".
@tool
extends SceneTree


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: godot --headless --path . --script tools/sheet_to_text.gd -- <file.tres>")
		quit(1)
		return
	var path: String = args[0]
	var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if resource is EventSheetResource:
		print(EventSheetTextDump.dump(resource))
	else:
		print(FileAccess.get_file_as_string(path))
	quit()
