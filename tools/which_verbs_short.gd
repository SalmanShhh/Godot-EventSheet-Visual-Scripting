# Names the verbs a pack declares but does not lift - the ones an opened pack still shows as code.
# Run: godot --headless --path . --script tools/which_verbs_short.gd -- res://eventsheet_addons/x/y.gd
@tool
extends SceneTree


func _init() -> void:
	for path: String in OS.get_cmdline_user_args():
		var source: String = FileAccess.get_file_as_string(path)
		var declared: PackedStringArray = PackedStringArray()
		var lines: PackedStringArray = source.split("\n")
		for index: int in lines.size():
			var line: String = lines[index]
			if line == "## @ace_action" or line == "## @ace_condition" or line == "## @ace_expression":
				for ahead: int in range(index, mini(index + 20, lines.size())):
					if lines[ahead].begins_with("func ") or lines[ahead].begins_with("static func "):
						declared.append(lines[ahead].split("(")[0].split(" ")[-1])
						break
		var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
		var lifted: PackedStringArray = PackedStringArray()
		for function: Variant in sheet.functions:
			if function is EventFunction:
				lifted.append((function as EventFunction).function_name)
		var short: PackedStringArray = PackedStringArray()
		for name: String in declared:
			if not lifted.has(name):
				short.append(name)
		print("%s: %d declared, %d short: %s" % [path, declared.size(), short.size(),
			", ".join(short)])
	quit(0)
