# EventForge module - Editor Tools vocabulary (build @tool / EditorScript sheets by events).
#
# The everyday editor-automation calls you reach for when a sheet is a tool rather than a game
# script: open / save / play a scene, rescan the project, select or inspect a node, save a resource,
# make a folder, and two combined builders (add a node to the edited scene, or pack a node into a
# .tscn) that would otherwise be three lines each. They compile to the exact plain Godot the editor
# exposes - EditorInterface, ResourceSaver, DirAccess, Engine - with ZERO plugin references, honouring
# the parity covenant. These are editor-only: use them in a Tool sheet (Sheet Type -> Tool, which
# emits @tool + extends EditorScript + On Editor Run). Grouped under "Editor Tools".
@tool
class_name EventForgeToolingACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Editor Tools"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Scene lifecycle (open / save / play the scene you are editing) ──
	descriptors.append(F.make_descriptor("Core", "OpenSceneInEditor", "Open Scene In Editor", ACEDescriptor.ACEType.ACTION, "EditorInterface.open_scene_from_path({path})", "", [F.make_param("path", "String", "\"res://scene.tscn\"", "Scene Path", "The .tscn to open as the edited scene.", "scene_path")], CAT, "open scene {path}")
		.described("Opens a scene file in the editor as the current edited scene."))
	descriptors.append(F.make_descriptor("Core", "SaveEditedScene", "Save Current Scene", ACEDescriptor.ACEType.ACTION, "EditorInterface.save_scene()", "", [], CAT, "save current scene")
		.described("Saves the scene currently open in the editor."))
	descriptors.append(F.make_descriptor("Core", "SaveEditedSceneAs", "Save Scene As", ACEDescriptor.ACEType.ACTION, "EditorInterface.save_scene_as({path})", "", [F.make_param("path", "String", "\"res://scene.tscn\"", "Scene Path", "Where to save a copy of the current scene.", "scene_path")], CAT, "save scene as {path}")
		.described("Saves the current scene to a new path."))
	descriptors.append(F.make_descriptor("Core", "PlayCurrentScene", "Play Current Scene", ACEDescriptor.ACEType.ACTION, "EditorInterface.play_current_scene()", "", [], CAT, "play current scene")
		.described("Runs the scene open in the editor, as if you pressed Play Scene."))
	descriptors.append(F.make_descriptor("Core", "StopPlayingScene", "Stop Playing", ACEDescriptor.ACEType.ACTION, "EditorInterface.stop_playing_scene()", "", [], CAT, "stop playing")
		.described("Stops the running game started from the editor."))
	descriptors.append(F.make_descriptor("Core", "RescanProjectFiles", "Rescan Project Files", ACEDescriptor.ACEType.ACTION, "EditorInterface.get_resource_filesystem().scan()", "", [], CAT, "rescan project files")
		.described("Re-imports the FileSystem dock so files written by a tool show up right away."))

	# ── Selection + inspector (drive what the editor is focused on) ──
	descriptors.append(F.make_descriptor("Core", "SelectNodeInEditor", "Select Node In Editor", ACEDescriptor.ACEType.ACTION, "EditorInterface.get_selection().clear()\nEditorInterface.get_selection().add_node({node})", "", [F.make_param("node", "Node", "self", "Node", "The node to select in the Scene dock.", "expression")], CAT, "select {node} in editor")
		.described("Clears the current selection and selects a node in the Scene dock."))
	descriptors.append(F.make_descriptor("Core", "InspectInEditor", "Inspect In Editor", ACEDescriptor.ACEType.ACTION, "EditorInterface.inspect_object({object})", "", [F.make_param("object", "Object", "self", "Object", "The node or resource to show in the Inspector.", "expression")], CAT, "inspect {object}")
		.described("Shows a node or resource in the Inspector dock."))

	# ── Files + resources (write what a tool generates back to disk) ──
	descriptors.append(F.make_descriptor("Core", "SaveResourceToFile", "Save Resource To File", ACEDescriptor.ACEType.ACTION, "ResourceSaver.save({resource}, {path})", "", [F.make_param("resource", "Resource", "Resource.new()", "Resource", "The resource to write to disk.", "expression"), F.make_param("path", "String", "\"res://data.tres\"", "Path", "Where to save it (a .tres / .res path).", "expression")], CAT, "save {resource} to {path}")
		.described("Writes a resource out to a file on disk."))
	descriptors.append(F.make_descriptor("Core", "EnsureFolderExists", "Make Sure Folder Exists", ACEDescriptor.ACEType.ACTION, "DirAccess.make_dir_recursive_absolute({path})", "", [F.make_param("path", "String", "\"res://generated\"", "Folder", "The folder to create (parents are made too).", "expression")], CAT, "make sure folder {path} exists")
		.described("Creates a folder (and any missing parents) so a tool can write into it."))
	descriptors.append(F.make_descriptor("Core", "ResourceFileExists", "Resource Exists", ACEDescriptor.ACEType.CONDITION, "ResourceLoader.exists({path})", "", [F.make_param("path", "String", "\"res://data.tres\"", "Path", "The resource path to test.", "expression")], CAT, "resource {path} exists")
		.described("True when a resource file already exists at the given path."))

	# ── Combined builders (three lines of scene-building in one pickable row) ──
	descriptors.append(F.make_descriptor("Core", "AddNodeToEditedScene", "Add Node To Edited Scene", ACEDescriptor.ACEType.ACTION, "var __node_{uid} = {node}\n{parent}.add_child(__node_{uid})\n__node_{uid}.owner = EditorInterface.get_edited_scene_root()", "", [F.make_param("node", "Node", "Node2D.new()", "Node", "The node to add (for example Sprite2D.new()).", "expression"), F.make_param("parent", "Node", "EditorInterface.get_edited_scene_root()", "Parent", "The node to add it under.", "expression")], CAT, "add {node} under {parent}")
		.described("Adds a new node to the edited scene AND sets its owner, so it is saved with the scene."))
	descriptors.append(F.make_descriptor("Core", "SaveNodeAsScene", "Save Node As Scene", ACEDescriptor.ACEType.ACTION, "var __scene_{uid} = PackedScene.new()\n__scene_{uid}.pack({node})\nResourceSaver.save(__scene_{uid}, {path})", "", [F.make_param("node", "Node", "self", "Node", "The node (with its children) to turn into a scene.", "expression"), F.make_param("path", "String", "\"res://saved.tscn\"", "Path", "Where to save the .tscn.", "expression")], CAT, "save {node} as scene {path}")
		.described("Packs a node and its children into a PackedScene and saves it as a .tscn file."))

	# ── Editor state (guards + queries a tool sheet reads) ──
	descriptors.append(F.make_descriptor("Core", "IsInEditor", "Is In Editor", ACEDescriptor.ACEType.CONDITION, "Engine.is_editor_hint()", "", [], CAT, "running in the editor")
		.described("True when the script is running inside the editor (a @tool script), not the running game."))
	descriptors.append(F.make_descriptor("Core", "EditedSceneRoot", "Edited Scene Root", ACEDescriptor.ACEType.EXPRESSION, "EditorInterface.get_edited_scene_root()", "", [], CAT, "edited scene root")
		.described("Returns the root node of the scene currently open in the editor."))
	descriptors.append(F.make_descriptor("Core", "EditorSelectedNodes", "Selected Nodes", ACEDescriptor.ACEType.EXPRESSION, "EditorInterface.get_selection().get_selected_nodes()", "", [], CAT, "selected nodes")
		.described("Returns the array of nodes currently selected in the Scene dock."))
	descriptors.append(F.make_descriptor("Core", "EditorUiScale", "Editor Scale", ACEDescriptor.ACEType.EXPRESSION, "EditorInterface.get_editor_scale()", "", [], CAT, "editor scale")
		.described("Returns the editor's display scale (1.0 at 100%), for sizing tool UI."))

	return descriptors
