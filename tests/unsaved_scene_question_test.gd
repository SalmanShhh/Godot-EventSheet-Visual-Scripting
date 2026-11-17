# EventSheets - closing ONE scene tab asks only about the sheets that belong to that scene.
#
# Godot hands the plugin the scene's path when a single scene tab is closed, and an empty string when the
# editor quits or the project closes. The plugin used to ignore it, so closing any scene listed every
# unsaved sheet. A scene is answered with the sheets attached to its nodes (or that are the scene opened
# as a sheet); an empty argument is answered for all of them, as Godot's contract says.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "unsaved_scene_question_test"
const HELPER_PATH: String = "res://addons/eventsheet/editor/dock/unsaved_sheets.gd"


static func run() -> bool:
	var helper: GDScript = load(HELPER_PATH)
	var related_script: String = SUPPORT.own_path("related_sheet.gd")
	var other_script: String = SUPPORT.own_path("unrelated_sheet.gd")
	var scene_path: String = SUPPORT.own_path("level.tscn")
	var elsewhere_scene: String = SUPPORT.own_path("elsewhere.tscn")
	_write(related_script, "extends Node\n")
	_write(other_script, "extends Node\n")
	_write(scene_path, "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"Script\" path=\"%s\" id=\"1_a\"]\n\n[node name=\"Level\" type=\"Node\"]\nscript = ExtResource(\"1_a\")\n" % related_script)
	_write(elsewhere_scene, "[gd_scene format=3]\n\n[node name=\"Elsewhere\" type=\"Node\"]\n")
	var dock: EventSheetEditor = EventSheetEditor.new()
	var related: EventSheetResource = EventSheetResource.new()
	related.external_source_path = related_script
	var other: EventSheetResource = EventSheetResource.new()
	other.external_source_path = other_script
	dock._open_tabs.clear()
	dock._open_tabs.append({"sheet": related, "path": related_script, "dirty": true})
	dock._open_tabs.append({"sheet": other, "path": other_script, "dirty": true})
	dock._active_tab_index = 0
	# The tab in front keeps its sheet and its flag on the dock itself, as it does while it is edited.
	dock._current_sheet = related
	dock._current_sheet_path = related_script
	dock._dirty = true
	var everything: String = helper.status_text(dock)
	var for_level: String = helper.status_text(dock, scene_path)
	var for_elsewhere: String = helper.status_text(dock, elsewhere_scene)
	var ok: bool = SUPPORT.pins(P, [
		["quitting (no scene) names both unsaved sheets", everything.contains("related_sheet.gd") and everything.contains("unrelated_sheet.gd"), true],
		["closing the scene its script is attached to names that sheet", for_level.contains("related_sheet.gd"), true],
		["and does not name a sheet of another scene", for_level.contains("unrelated_sheet.gd"), false],
		["closing a scene with no unsaved sheet of its own asks nothing", for_elsewhere, ""],
		["a scene that is not on disk asks nothing", helper.status_text(dock, "res://not_there.tscn"), ""],
		["the tab for the scene file itself belongs to that scene", helper.belongs_to_scene({"sheet": related, "path": scene_path}, scene_path), true],
	])
	dock.free()
	return ok


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
