# Godot EventSheets - the findings a Project Doctor picture shows (dev tool for tools/doc_shots.gd).
#
# The Doctor window audits the whole project, and this repository's own files would bury the one
# section a guide is talking about. So a picture asks for a PAGE by name and this file produces the
# findings that page holds, by running the Doctor's real checks over a small staged project: the
# checks, the messages and the fix doors are the shipped ones, only the project is made up. The
# window draws them through its own page code, so what is photographed is what a reader gets.
#
# Nothing here is written under res://. The staged files live in user:// and are deleted again.
@tool
extends RefCounted

const STAGE: String = "user://doc_shots_doctor_pages"


## The findings for `page`, in the shape the Doctor's inbox takes.
static func findings(page: String) -> Array:
	match page:
		"migration":
			return _migration()
		"reading":
			return _reading()
		"collisions":
			return _collisions()
		"scene_trust":
			return EventSheetFilesDoctor.untrusted_scene_findings({"res://mod_loader.gd": _scene_loader_source()})
		"watch":
			return EventSheetFilesDoctor.watch_never_stops_findings(_watcher_sources())
		"tidiness":
			return _tidiness()
	return []


static func _migration() -> Array:
	var module: Object = load("res://tools/previews/migration_doctor_inbox.gd")
	var paths: PackedStringArray = module._stage()
	var known: Dictionary = module._vocabulary()
	var found: Array[Dictionary] = EventSheetMigrationDoctor.report(paths, known)
	found.append_array(EventSheetMigrationDoctor.sheet_lines(EventSheetMigrationDoctor.rows(paths, known)))
	module._unstage(paths)
	return found


static func _reading() -> Array:
	var module: Object = load("res://tools/previews/doctor_reading_page.gd")
	var paths: PackedStringArray = module._stage()
	var found: Array[Dictionary] = EventSheetReadingDoctor.report(paths)
	module._unstage(paths)
	return found


static func _collisions() -> Array:
	var module: Object = load("res://tools/previews/collisions_doctor_report.gd")
	for entry: Array in module.LAYER_SETTINGS:
		ProjectSettings.set_setting(str(entry[0]), str(entry[1]))
	EventSheetSceneCollisionFacts.clear_cache()
	return EventSheetCollisionsDoctor.report(module.SCRIPTS, module.SCENES)


## Puts the layer names the collisions page set back, so the next picture sees the project as it is.
static func release_collisions() -> void:
	var module: Object = load("res://tools/previews/collisions_doctor_report.gd")
	for entry: Array in module.LAYER_SETTINGS:
		ProjectSettings.set_setting(str(entry[0]), null)
	EventSheetSceneCollisionFacts.clear_cache()


static func _scene_loader_source() -> String:
	return "extends Node\n\n\nfunc _on_load_pressed() -> void:\n\tvar level: Node = load(\"user://mods/level.tscn\").instantiate()\n\tlevel.name = \"Mod\"\n\tget_tree().root.add_child(level)\n"


static func _watcher_sources() -> Dictionary:
	return {
		"res://scenes/menu.gd": "extends Control\n\n\nfunc _ready() -> void:\n\t$FolderWatcher.watch_folder(\"user://mods\", 2.0)\n",
		"res://scenes/level_select.gd": "extends Control\n\n\nfunc _ready() -> void:\n\t$LevelWatcher.watch_folder(\"user://levels\", 5.0)\n",
	}


## A sheet with one of everything the tidiness sweep names, saved where the real check can read it.
static func _tidiness() -> Array:
	DirAccess.make_dir_recursive_absolute(STAGE)
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	var off: EventRow = EventRow.new()
	off.enabled = false
	var kept: LocalVariable = LocalVariable.new()
	kept.name = "speed"
	var dead: LocalVariable = LocalVariable.new()
	dead.name = "old_speed"
	off.local_variables = [kept, dead] as Array[LocalVariable]
	off.actions = [_action("SetProperty", {"value": "speed * 2"})] as Array[Resource]
	var rows: Array[Resource] = [off]
	for index: int in 3:
		var event: EventRow = EventRow.new()
		event.actions = [_action("SetProperty", {"value": "400"})] as Array[Resource]
		rows.append(event)
	var never: SignalRow = SignalRow.new()
	never.signal_name = "died"
	never.trigger = true
	rows.append(never)
	sheet.events = rows
	var unused: EventFunction = EventFunction.new()
	unused.function_name = "debug_dump"
	sheet.functions = [unused] as Array[Resource]
	sheet.requires_behaviors = ["FlashBehavior"] as Array[String]
	var path: String = STAGE.path_join("arena_rules.tres")
	ResourceSaver.save(sheet, path)
	var found: Array[Dictionary] = []
	EventSheetDoctorTidiness.check_tidiness(PackedStringArray([path]), found)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STAGE))
	return found


static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	return action
