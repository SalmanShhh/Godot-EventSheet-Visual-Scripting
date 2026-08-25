@tool
class_name EventSheetPackAssets
extends RefCounted

# The files a pack brings with it, and what adding the pack does with them.
#
# Five of the shipped effect packs are a shader and some verbs. The verbs come from the pack script
# the way every pack's do; the shader has to end up somewhere the project can see it, on a material
# the node really wears, or the verbs write dials into nothing.
#
# COPIED, NOT REFERENCED. The shader is copied into the project rather than pointed at where the
# pack keeps it, because the whole point of shipping a shader is that it is a starting point: the
# burn edge, the outline thickness, the noise scale are meant to be opened and changed. A file
# inside the plugin's own folder is a file the next update overwrites. A file in `res://effects/` is
# the author's.
#
# NOTHING IS EVER OVERWRITTEN. Adding the same pack to a second node finds the shader and the
# material already there and uses them, so the second goblin wears the same file as the first - and
# the behaviour takes its own private copy at run time, which is what stops one goblin's dissolve
# from burning all of them.
#
# DERIVED, NOT DECLARED. What a pack ships is what is in its folder: the one `.gdshader` beside the
# pack script is its shader, and the one `.tscn` beside it is the scene adding it drops in. That is
# the same rule the pack icon already follows, and it means a pack author ships an asset by putting
# it in the folder rather than by learning an annotation.
#
# A pack that ships a SCENE ships its shader inside it - the scene's own nodes already wear it - so
# nothing is copied and nothing is put on the host. Installing is for the packs that are a behaviour
# and a shader, where the host is the thing that has to end up wearing something.
#
# PURE ENOUGH TO TEST. Reading what a pack ships is a folder listing and needs no editor; installing
# is file work that takes the destination as an argument, so a test installs into `user://` and asks
# what came out. Only the material assignment needs the editor, and it is the one function that says
# so.

## Where a copied effect lives in the author's project. A plain top-level folder, because that is
## where somebody looking for their own shaders will look.
const DEFAULT_FOLDER: String = "res://effects"

## What a copied shader's material file is called: the shader's own name and this. One material per
## shader per project, found again by name the next time the pack is added to anything.
const MATERIAL_SUFFIX: String = "_material.tres"

## The two extensions a pack may ship one of, and what each one means when it is found.
const SHADER_EXTENSION: String = "gdshader"
const SCENE_EXTENSION: String = "tscn"


## What the pack whose script is at `script_path` brings with it: `{"shader": path, "scene": path}`,
## each "" when the pack ships none. Exactly one of each counts - a folder with two shaders in it is
## ambiguous about which one the pack means, so it is treated as shipping neither rather than as
## shipping whichever the filesystem listed first.
static func shipped_by(script_path: String) -> Dictionary:
	var folder: String = script_path.get_base_dir()
	return {
		"shader": _only_file_with(folder, SHADER_EXTENSION),
		"scene": _only_file_with(folder, SCENE_EXTENSION),
	}


## Copies a pack's shader into the project and makes sure there is a material wearing it. Returns
## `{"ok", "shader_path", "material_path", "created"}` - `created` naming the files this call really
## wrote, so a second call on an already-installed pack reports nothing new rather than pretending.
##
## `into_folder` is where the copies land; the default is the one a project's own effects go in.
static func install(shipped_shader: String, into_folder: String = DEFAULT_FOLDER) -> Dictionary:
	var answer: Dictionary = {"ok": false, "shader_path": "", "material_path": "", "created": PackedStringArray()}
	if shipped_shader.is_empty() or not FileAccess.file_exists(shipped_shader):
		return answer
	var folder: String = into_folder.rstrip("/")
	if DirAccess.make_dir_recursive_absolute(folder) != OK and not DirAccess.dir_exists_absolute(folder):
		return answer
	var created: PackedStringArray = PackedStringArray()
	var shader_path: String = folder.path_join(shipped_shader.get_file())
	if not FileAccess.file_exists(shader_path):
		# A byte copy rather than a read and a write: a shader is a text file the author will open,
		# and rewriting it through a string is how a file changes its line endings without anybody
		# asking it to.
		if DirAccess.copy_absolute(shipped_shader, shader_path) != OK:
			return answer
		created.append(shader_path)
	var material_path: String = folder.path_join(
		"%s%s" % [shipped_shader.get_file().get_basename(), MATERIAL_SUFFIX])
	if not FileAccess.file_exists(material_path):
		var shader: Shader = ResourceLoader.load(shader_path, "Shader", ResourceLoader.CACHE_MODE_IGNORE) as Shader
		if shader == null:
			return answer
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = shader
		if ResourceSaver.save(material, material_path) != OK:
			return answer
		created.append(material_path)
	answer["ok"] = true
	answer["shader_path"] = shader_path
	answer["material_path"] = material_path
	answer["created"] = created
	return answer


## Puts the material on the node, as a step Ctrl+Z takes back. A material assignment is a scene edit
## like any other, so it goes through the editor's own undo rather than around it - and outside the
## editor (a test, a headless run) it is a plain assignment, because there is no history to join.
##
## Answers false when the node already wears a ShaderMaterial: whatever an author put there by hand
## outranks what a pack would have put there, and quietly replacing it is how work disappears.
static func wear_material(node: Node, material_path: String) -> bool:
	if node == null or not (node is CanvasItem) or material_path.is_empty():
		return false
	if (node as CanvasItem).material is ShaderMaterial:
		return false
	var material: Material = ResourceLoader.load(material_path, "Material") as Material
	if material == null:
		return false
	var undo: Object = _editor_undo()
	if undo == null:
		(node as CanvasItem).material = material
		return true
	undo.call("create_action", "Wear %s" % material_path.get_file())
	undo.call("add_do_property", node, "material", material)
	undo.call("add_undo_property", node, "material", (node as CanvasItem).material)
	undo.call("commit_action")
	return true


## Tells the editor about files written from code. Without it a freshly copied shader is on disk and
## not in the filesystem dock until something else triggers a scan, and a material saved beside it
## loads from the old cache. Does nothing outside the editor.
static func notice_new_files(paths: PackedStringArray) -> void:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return
	var filesystem: Object = EditorInterface.get_resource_filesystem()
	if filesystem == null:
		return
	for path: String in paths:
		filesystem.call("update_file", path)


## The one file with this extension in a folder, or "" when there is none or more than one.
static func _only_file_with(folder: String, extension: String) -> String:
	if folder.is_empty():
		return ""
	var found: String = ""
	for file_name: String in DirAccess.get_files_at(folder):
		if file_name.get_extension().to_lower() != extension:
			continue
		if not found.is_empty():
			return ""
		found = folder.path_join(file_name)
	return found


## The editor's undo history, or null when there is no editor to join.
static func _editor_undo() -> Object:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return null
	return EditorInterface.get_editor_undo_redo()
