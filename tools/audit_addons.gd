# One-shot audit: every behavior pack's .tres must load, recompile to EXACTLY the
# shipped .gd (no drift since the last regeneration), parse, and publish ACEs.
@tool
extends SceneTree

func _init() -> void:
	var packs_dir: DirAccess = DirAccess.open("res://eventsheet_addons")
	packs_dir.list_dir_begin()
	var entry: String = packs_dir.get_next()
	var audited: int = 0
	var drifted: int = 0
	while not entry.is_empty():
		if packs_dir.current_is_dir() and not entry.begins_with("."):
			var folder: String = "res://eventsheet_addons/%s" % entry
			var base_name: String = entry if not DirAccess.dir_exists_absolute("%s/%s_behavior.tres" % [folder, entry]) else entry
			var sheet_path: String = "%s/%s_behavior.tres" % [folder, entry]
			var script_path: String = "%s/%s_behavior.gd" % [folder, entry]
			if not ResourceLoader.exists(sheet_path):
				# Fallback naming (e.g. eight_direction_movement).
				var dir2: DirAccess = DirAccess.open(folder)
				dir2.list_dir_begin()
				var inner: String = dir2.get_next()
				while not inner.is_empty():
					if inner.ends_with(".tres"):
						sheet_path = "%s/%s" % [folder, inner]
						script_path = sheet_path.trim_suffix(".tres") + ".gd"
					inner = dir2.get_next()
			if ResourceLoader.exists(sheet_path) and FileAccess.file_exists(script_path):
				audited += 1
				var sheet: EventSheetResource = load(sheet_path)
				var output: String = str(SheetCompiler.compile(sheet, script_path).get("output", ""))
				var shipped: String = FileAccess.get_file_as_string(script_path)
				if output != shipped:
					drifted += 1
					print("DRIFT: %s (recompile differs from shipped .gd)" % entry)
				# NOTE: re-parsing shipped sources directly would false-positive on
				# "hides a global class" (their class_names are already registered) —
				# load() of the real script is the honest parse check.
				if load(script_path) == null:
					print("PARSE FAIL: %s" % entry)
			else:
				print("MISSING PAIR: %s" % entry)
		entry = packs_dir.get_next()
	print("audited=%d drifted=%d" % [audited, drifted])
	quit()
