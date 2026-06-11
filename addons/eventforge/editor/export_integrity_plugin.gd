# Godot EventSheets — Export integrity hook
# Recompiles every event sheet in the project when an export starts, so an exported game
# can never ship a stale generated script (the architecture guarantee this protects:
# exports contain only plain generated GDScript — no plugin dependency, no interpreter).
# Failures are loud push_errors naming the sheet; GDScript-backed sheets are skipped
# (their .gd already IS the source of truth on disk).
@tool
class_name EventSheetExportIntegrityPlugin
extends EditorExportPlugin

func _get_name() -> String:
	return "GodotEventSheetsExportIntegrity"

func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	var report: Dictionary = recompile_all_sheets()
	print("[Godot EventSheets] export integrity: %d sheet(s) recompiled, %d failed." % [int(report.get("compiled", 0)), int(report.get("failed", 0))])

## Walks res:// for EventSheetResource .tres files and recompiles each to its existing
## pair (the compiler's resolution — never a parallel duplicate next to a builder-shipped
## sibling). Returns {compiled: int, failed: int, failures: Array[String]}.
## Static + headless-safe so tests (and CI) can run the exact export-time pass.
static func recompile_all_sheets(root: String = "res://") -> Dictionary:
	var report: Dictionary = {"compiled": 0, "failed": 0, "failures": []}
	for sheet_path: String in _find_sheet_paths(root):
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet == null or not sheet.external_source_path.is_empty():
			continue
		var result: Dictionary = SheetCompiler.compile(sheet, "")
		if bool(result.get("success", false)):
			report["compiled"] = int(report["compiled"]) + 1
		else:
			report["failed"] = int(report["failed"]) + 1
			(report["failures"] as Array).append(sheet_path)
			push_error("[Godot EventSheets] sheet failed to compile at export: %s — %s" % [sheet_path, str(result.get("errors", []))])
	return report

static func _find_sheet_paths(root: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var directories: Array[String] = [root]
	while not directories.is_empty():
		var current: String = directories.pop_back()
		# The addon folders and .godot never contain user sheets; skipping keeps this fast.
		if current.begins_with("res://.godot") or current.begins_with("res://addons"):
			continue
		var dir: DirAccess = DirAccess.open(current)
		if dir == null:
			continue
		dir.list_dir_begin()
		var entry: String = dir.get_next()
		while not entry.is_empty():
			var entry_path: String = current.path_join(entry)
			if dir.current_is_dir():
				if not entry.begins_with("."):
					directories.append(entry_path)
			elif entry.get_extension() == "tres":
				# Cheap pre-filter: only load .tres files that reference the sheet class.
				var header: String = FileAccess.get_file_as_string(entry_path).left(400)
				if header.contains("EventSheetResource") or header.contains("event_sheet.gd"):
					found.append(entry_path)
			entry = dir.get_next()
		dir.list_dir_end()
	return found
