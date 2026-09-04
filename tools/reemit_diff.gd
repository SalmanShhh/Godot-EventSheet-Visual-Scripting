# Prints the first line where a pack's re-emission differs from the file it was opened from.
# Run: godot --headless --path . --script tools/reemit_diff.gd -- res://eventsheet_addons/x/y.gd
@tool
extends SceneTree


func _init() -> void:
	for path: String in OS.get_cmdline_user_args():
		var source: String = FileAccess.get_file_as_string(path)
		var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
		var reopened: String = str(SheetCompiler.compile(sheet, path).get("output", ""))
		var was: PackedStringArray = source.split("\n")
		var now: PackedStringArray = reopened.split("\n")
		print("%s: %d lines -> %d lines" % [path, was.size(), now.size()])
		for index: int in mini(was.size(), now.size()):
			if was[index] != now[index]:
				print("  first difference at line %d" % (index + 1))
				print("    was: %s" % was[index])
				print("    now: %s" % now[index])
				break
	quit(0)
