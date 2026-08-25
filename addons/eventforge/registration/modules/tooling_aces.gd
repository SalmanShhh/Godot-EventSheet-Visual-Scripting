# EventForge module - Editor Tools vocabulary (build @tool / EditorScript sheets by events).
#
# The everyday editor-automation calls you reach for when a sheet is a tool rather than a game
# script: open / save / play a scene, rescan the project, select or inspect a node, save a resource,
# make a folder, and two combined builders (add a node to the edited scene, or pack a node into a
# .tscn) that would otherwise be three lines each. On top of those sit three heavier chores that are
# still one pickable row: render a scene to a PNG, preview a weighted table's real odds, and stamp a
# build version - plus the On Project Export trigger and its two flag conditions, which turn a tool
# sheet into a bake step the exporter runs. They compile to the exact plain Godot the editor
# exposes - EditorInterface, ResourceSaver, DirAccess, Engine, plus SubViewport / RenderingServer,
# RandomNumberGenerator and ConfigFile for the three heavy ones - with ZERO plugin references, honouring
# the parity covenant. These are editor-only: use them in a Tool sheet (Sheet Type -> Tool, which
# emits @tool + extends EditorScript + On Editor Run). Grouped under "Editor Tools".
@tool
class_name EventForgeToolingACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Editor Tools"

## The pages the rows below are filed on, all under the same "Editor Tools: " root the tool-sheet
## gate and the "Editor" object label test the prefix of. Everything that is a one-off CHORE - open a
## scene, select a node, ask the editor a question - stays on the flat root, because that is the page
## a reader lands on and it should not be empty; the rows that belong to one named surface get a page.
const CAT_FILES := "Editor Tools: Files & folders"
const CAT_PIPELINE := "Editor Tools: Import & export"
const CAT_COMMAND := "Editor Tools: Command tool"


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
	descriptors.append(F.make_descriptor("Core", "SaveResourceToFile", "Save Resource To File", ACEDescriptor.ACEType.ACTION, "ResourceSaver.save({resource}, {path})", "", [F.make_param("resource", "Resource", "Resource.new()", "Resource", "The resource to write to disk.", "expression"), F.make_param("path", "String", "\"res://data.tres\"", "Path", "Where to save it (a .tres / .res path).", "expression")], CAT_FILES, "save {resource} to {path}")
		.described("Writes a resource out to a file on disk."))
	descriptors.append(F.make_descriptor("Core", "EnsureFolderExists", "Make Sure Folder Exists", ACEDescriptor.ACEType.ACTION, "DirAccess.make_dir_recursive_absolute({path})", "", [F.make_param("path", "String", "\"res://generated\"", "Folder", "The folder to create (parents are made too).", "expression")], CAT_FILES, "make sure folder {path} exists")
		.described("Creates a folder (and any missing parents) so a tool can write into it."))
	descriptors.append(F.make_descriptor("Core", "ResourceFileExists", "Resource Exists", ACEDescriptor.ACEType.CONDITION, "ResourceLoader.exists({path})", "", [F.make_param("path", "String", "\"res://data.tres\"", "Path", "The resource path to test.", "expression")], CAT_FILES, "resource {path} exists")
		.described("True when a resource file already exists at the given path."))

	# ── Combined builders (three lines of scene-building in one pickable row) ──
	descriptors.append(F.make_descriptor("Core", "AddNodeToEditedScene", "Add Node To Edited Scene", ACEDescriptor.ACEType.ACTION, "var __node_{uid} = {node}\n{parent}.add_child(__node_{uid})\n__node_{uid}.owner = EditorInterface.get_edited_scene_root()", "", [F.make_param("node", "Node", "Node2D.new()", "Node", "The node to add (for example Sprite2D.new()).", "expression"), F.make_param("parent", "Node", "EditorInterface.get_edited_scene_root()", "Parent", "The node to add it under.", "expression")], CAT, "add {node} under {parent}")
		.described("Adds a new node to the edited scene AND sets its owner, so it is saved with the scene."))
	descriptors.append(F.make_descriptor("Core", "SaveNodeAsScene", "Save Node As Scene", ACEDescriptor.ACEType.ACTION, "var __scene_{uid} = PackedScene.new()\n__scene_{uid}.pack({node})\nResourceSaver.save(__scene_{uid}, {path})", "", [F.make_param("node", "Node", "self", "Node", "The node (with its children) to turn into a scene.", "expression"), F.make_param("path", "String", "\"res://saved.tscn\"", "Path", "Where to save the .tscn.", "expression")], CAT_FILES, "save {node} as scene {path}")
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

	# ── Rendering + data previews (the heavy chores that stay one pickable row) ──
	descriptors.append(F.make_descriptor("Core", "RenderSceneToImage", "Render Scene To Image", ACEDescriptor.ACEType.ACTION, _render_scene_template(), "", [F.make_param("scene_path", "String", "\"res://scene.tscn\"", "Scene", "The scene to render. It needs its own camera (or a Control layout) - the renderer photographs what that scene shows.", "scene_path"), F.make_param("width", "int", "512", "Width", "Image width in pixels.", "expression"), F.make_param("height", "int", "512", "Height", "Image height in pixels.", "expression"), F.make_param("save_path", "String", "\"res://thumbnail.png\"", "Save To", "Where to write the PNG.", "expression")], CAT, "render {scene_path} to {save_path} at {width}x{height}")
		.described("Instantiates a scene into an off-screen viewport, lets it settle for a frame, and saves what it shows as a PNG - thumbnails, store shots, doc figures, baked sprites. Needs a windowed editor: a headless run has no renderer, so it warns and writes nothing."))
	descriptors.append(F.make_descriptor("Core", "PreviewTableRolls", "Preview Table Rolls", ACEDescriptor.ACEType.ACTION, _preview_table_rolls_template(), "", [F.make_param("table", "String", "\"res://loot_table.tres\"", "Table", "A weighted table: the path to a table resource, the resource itself, or a plain Dictionary of value to weight.", "expression"), F.make_param("rolls", "int", "1000", "Rolls", "How many draws to simulate.", "expression"), F.make_param("seed", "int", "12345", "Seed", "The random seed. The same seed always produces the same report.", "expression"), F.make_param("save_path", "String", "\"\"", "Save To", "Optional file to write the report to. Leave empty to print it to the Output panel only.", "expression")], CAT, "preview {rolls} rolls of {table}")
		.described("Rolls a weighted table many times and reports what actually came out: per entry the rolled percent, the percent its weight implies, and the gap between them. Pure maths - it runs anywhere, and the same seed always gives the same numbers."))

	# ── Project export bake step (the trigger + the flags the exporter hands it) ──
	descriptors.append(F.make_descriptor("Core", "OnProjectExport", "On Project Export", ACEDescriptor.ACEType.TRIGGER, "", "_on_project_export", [], CAT_PIPELINE, "On project export (bake step)")
		.described("Runs while a project export is starting, before the files are written - the place to stamp a build number, bake a data file, or strip debug content."))
	descriptors.append(F.make_descriptor("Core", "WriteVersionStamp", "Write Version Stamp", ACEDescriptor.ACEType.ACTION, _write_version_stamp_template(), "", [F.make_param("path", "String", "\"res://build_stamp.cfg\"", "Save To", "Where to write the stamp file (a ConfigFile the game reads back with ConfigFile.load).", "expression"), F.make_param("version", "String", "ProjectSettings.get_setting(\"application/config/version\", \"0.0.0\")", "Version", "The version string to record. Defaults to the project's own version setting.", "expression")], CAT_PIPELINE, "write version stamp to {path}")
		.described("Writes a small build stamp file: the version string plus the date and time the stamp was written. The timestamp is read when the tool runs, so the generated code stays identical every save."))
	descriptors.append(F.make_descriptor("Core", "ExportIsDebug", "Export Is Debug", ACEDescriptor.ACEType.CONDITION, "is_debug", "", [], CAT_PIPELINE, "the export is a debug build")
		.described("True when the export that triggered this bake step is a debug build. Use it inside On Project Export to keep test content out of release builds."))
	descriptors.append(F.make_descriptor("Core", "ExportHasFeature", "Export Has Feature", ACEDescriptor.ACEType.CONDITION, "features.has({feature})", "", [F.make_param("feature", "String", "\"mobile\"", "Feature", "A feature tag of the export preset (mobile, web, windows, or one you added yourself).", "feature_tag")], CAT_PIPELINE, "the export has feature {feature}")
		.described("True when the export preset that triggered this bake step carries the given feature tag - the way to bake different data for mobile, web or desktop."))

	# ── The import reaction. Deliberately shaped like the bake step above: a plain named
	# handler the editor's import hook calls, so an opened tool reads it straight back as this event.
	descriptors.append(F.make_descriptor("Core", "OnFileImported", "On File Imported", ACEDescriptor.ACEType.TRIGGER, "", "_on_files_imported", [], CAT_PIPELINE, "On file imported")
		.described("Runs just after Godot finishes importing assets - the paths that landed arrive as `paths`. The place to rename what a designer dropped in, check an atlas for the wrong settings, or write a manifest."))
	# (There is deliberately no "Imported Paths" expression. `paths` is the handler's own argument, so
	# a row carrying it only compiles inside On File Imported - and an expression that does not stand
	# on its own is one the picker would offer everywhere and break everywhere else. Inside the event
	# the identifier is simply there to write.)

	# ── The command tool: the four rows a script the Godot binary runs headless is made of.
	# The READING of each of these already ships (a hand-written tools/*.gd reads "Command tool ▸ On
	# run", "Finish with code 1", "Command tool.Arguments"), and these are the picker's half of that
	# same sentence: each row emits EXACTLY the line the reading recognises, so a tool authored here
	# and one typed by hand are the same file and re-open as the same rows.
	descriptors.append(F.make_descriptor("Core", "OnCommandToolRun", "On Run", ACEDescriptor.ACEType.TRIGGER, "", "_init", [], CAT_COMMAND, "On run")
		.described("Where a command tool starts. The Godot binary runs the script as its whole main loop, so this is not a node's ready - nothing is in a scene tree and nothing is on screen. Finish with an exit code when the work is done."))
	descriptors.append(F.make_descriptor("Core", "CommandToolArguments", "Arguments", ACEDescriptor.ACEType.EXPRESSION, "OS.get_cmdline_user_args()", "", [], CAT_COMMAND, "Command tool.Arguments")
		.described("The words typed after the `--` on the command line, as a list of text. Everything before the `--` belongs to Godot itself, so this is only what the caller meant for this tool."))
	descriptors.append(F.make_descriptor("Core", "CommandToolFinish", "Finish", ACEDescriptor.ACEType.ACTION, "quit()", "", [], CAT_COMMAND, "Finish")
		.described("Ends the tool, reporting success. Whatever called it - a shell script, a build step, a test runner - reads that as \"this worked\"."))
	descriptors.append(F.make_descriptor("Core", "CommandToolFinishWithCode", "Finish With Code", ACEDescriptor.ACEType.ACTION, "quit({code})", "", [F.make_param("code", "int", "1", "Code", "The exit code. 0 means success; anything else means something went wrong, and is what makes a build step fail instead of passing quietly.", "expression")], CAT_COMMAND, "Finish with code {code}")
		.described("Ends the tool with an exit code. Use it for the failure paths - a missing argument, a file that would not load - so a script calling this tool can tell that it did not work."))

	return descriptors


## Blurbs for the three pages this module opens. The root "Editor Tools" blurb is not named here:
## it is seeded elsewhere and the merge keeps the first answer registered for a name.
static func section_descriptions() -> Dictionary:
	return {
		CAT_FILES: "Writing what a tool generates back to the project: a resource to a file, a node as a scene, a folder to put them in, and the question of whether one is already there.",
		CAT_PIPELINE: "The two moments the editor calls a tool without being asked: just after assets are imported, and while a project export is starting.",
		CAT_COMMAND: "A script the Godot binary runs headless from the command line: where it starts, the arguments it was handed, and the exit code it finishes with.",
	}


## Render Scene To Image. Honest degradation first: a headless run (the test suite, a CI export, any
## `--headless` invocation) has no renderer at all, so the emitted code SAYS so and writes nothing
## rather than silently saving a blank or crashing on a null texture - the same rule the repo's own
## preview harnesses live by. The viewport is parented to the editor's base control because that is
## the one Control an EditorScript can always reach, and it is freed again on the way out.
static func _render_scene_template() -> String:
	return "\n".join(PackedStringArray([
		"var __shot_{uid}: PackedScene = (load({scene_path}) as PackedScene) if ResourceLoader.exists({scene_path}) else null",
		"if DisplayServer.get_name() == \"headless\":",
		"\tpush_warning(\"[Render Scene To Image] This run has no display - rendering needs a windowed editor, so nothing was written to %s.\" % {save_path})",
		"elif __shot_{uid} == null:",
		"\tpush_warning(\"[Render Scene To Image] No scene at %s - nothing rendered.\" % {scene_path})",
		"else:",
		"\tvar __shot_view_{uid} := SubViewport.new()",
		"\t__shot_view_{uid}.size = Vector2i(int({width}), int({height}))",
		"\t__shot_view_{uid}.transparent_bg = true",
		"\t__shot_view_{uid}.own_world_3d = true",
		"\t__shot_view_{uid}.render_target_update_mode = SubViewport.UPDATE_ALWAYS",
		"\tEditorInterface.get_base_control().add_child(__shot_view_{uid})",
		"\t__shot_view_{uid}.add_child(__shot_{uid}.instantiate())",
		"\tawait __shot_view_{uid}.get_tree().process_frame",
		"\tawait RenderingServer.frame_post_draw",
		"\t__shot_view_{uid}.get_texture().get_image().save_png({save_path})",
		"\t__shot_view_{uid}.queue_free()",
	]))


## Preview Table Rolls. Reads BOTH shipped weighted-table shapes and the hand-written one:
## a table resource exposing an `entries` Array of {value|item|id, weight} dictionaries (what
## RandomTableResource and LootTableResource save), and a plain Dictionary of value to weight.
## A String is treated as a path and loaded - and a path that resolves to nothing is NAMED in the
## report, so "nothing to roll" never has to be guessed at. Everything after that is arithmetic over
## a seeded RandomNumberGenerator, so the report is identical on every machine and in a headless run.
##
## One authoring rule this template had to learn: a codegen template may not contain a literal `{}`.
## Every brace pair in a template is read as a parameter placeholder - by the reverse-lifter, which
## turns each one into a named regex capture - so an empty pair compiles to `(?<>.+?)` and makes the
## whole pattern invalid, spamming the console on every import. Build the empty dictionary with
## `Dictionary()` instead.
static func _preview_table_rolls_template() -> String:
	return "\n".join(PackedStringArray([
		"var __tbl_{uid}: Variant = {table}",
		"var __tbl_from_{uid}: String = str(__tbl_{uid}) if __tbl_{uid} is String else \"\"",
		"if __tbl_{uid} is String:",
		"\t__tbl_{uid} = load(__tbl_{uid}) if ResourceLoader.exists(__tbl_{uid}) else null",
		"var __tbl_src_{uid}: Variant = (__tbl_{uid} as Object).get(\"entries\") if __tbl_{uid} is Object else __tbl_{uid}",
		"var __tbl_rows_{uid}: Array = []",
		"if __tbl_src_{uid} is Dictionary:",
		"\tfor __tbl_key_{uid}: Variant in (__tbl_src_{uid} as Dictionary):",
		"\t\t__tbl_rows_{uid}.append([str(__tbl_key_{uid}), maxf(float((__tbl_src_{uid} as Dictionary)[__tbl_key_{uid}]), 0.0)])",
		"elif __tbl_src_{uid} is Array:",
		"\tfor __tbl_entry_{uid}: Variant in (__tbl_src_{uid} as Array):",
		"\t\tvar __tbl_dict_{uid}: Dictionary = __tbl_entry_{uid} if __tbl_entry_{uid} is Dictionary else Dictionary()",
		"\t\tvar __tbl_name_{uid}: String = str(__tbl_dict_{uid}.get(\"value\", __tbl_dict_{uid}.get(\"item\", __tbl_dict_{uid}.get(\"id\", \"entry %d\" % __tbl_rows_{uid}.size()))))",
		"\t\t__tbl_rows_{uid}.append([__tbl_name_{uid}, maxf(float(__tbl_dict_{uid}.get(\"weight\", 0.0)), 0.0)])",
		"var __tbl_total_{uid}: float = 0.0",
		"for __tbl_row_{uid}: Array in __tbl_rows_{uid}:",
		"\t__tbl_total_{uid} += float(__tbl_row_{uid}[1])",
		"var __tbl_out_{uid}: PackedStringArray = PackedStringArray()",
		"__tbl_out_{uid}.append(\"Table roll preview - %d rolls, seed %d\" % [maxi(int({rolls}), 0), int({seed})])",
		"if __tbl_total_{uid} <= 0.0:",
		"\tif __tbl_{uid} == null and not __tbl_from_{uid}.is_empty():",
		"\t\t__tbl_out_{uid}.append(\"(no table at %s - nothing to roll)\" % __tbl_from_{uid})",
		"\telse:",
		"\t\t__tbl_out_{uid}.append(\"(no entry has a weight above zero - nothing to roll)\")",
		"else:",
		"\tvar __tbl_rng_{uid} := RandomNumberGenerator.new()",
		"\t__tbl_rng_{uid}.seed = int({seed})",
		"\tvar __tbl_hits_{uid}: PackedInt32Array = PackedInt32Array()",
		"\t__tbl_hits_{uid}.resize(__tbl_rows_{uid}.size())",
		"\tfor __tbl_i_{uid}: int in maxi(int({rolls}), 0):",
		"\t\tvar __tbl_pick_{uid}: float = __tbl_rng_{uid}.randf() * __tbl_total_{uid}",
		"\t\tvar __tbl_walk_{uid}: float = 0.0",
		"\t\tfor __tbl_j_{uid}: int in __tbl_rows_{uid}.size():",
		"\t\t\t__tbl_walk_{uid} += float((__tbl_rows_{uid}[__tbl_j_{uid}] as Array)[1])",
		"\t\t\tif __tbl_pick_{uid} < __tbl_walk_{uid}:",
		"\t\t\t\t__tbl_hits_{uid}[__tbl_j_{uid}] += 1",
		"\t\t\t\tbreak",
		"\t__tbl_out_{uid}.append(\"entry | rolled | expected | delta\")",
		"\tfor __tbl_k_{uid}: int in __tbl_rows_{uid}.size():",
		"\t\tvar __tbl_got_{uid}: float = 100.0 * float(__tbl_hits_{uid}[__tbl_k_{uid}]) / float(maxi(int({rolls}), 1))",
		"\t\tvar __tbl_want_{uid}: float = 100.0 * float((__tbl_rows_{uid}[__tbl_k_{uid}] as Array)[1]) / __tbl_total_{uid}",
		"\t\t__tbl_out_{uid}.append(\"%s | %.2f%% | %.2f%% | %+.2f%%\" % [str((__tbl_rows_{uid}[__tbl_k_{uid}] as Array)[0]), __tbl_got_{uid}, __tbl_want_{uid}, __tbl_got_{uid} - __tbl_want_{uid}])",
		"print(\"\\n\".join(__tbl_out_{uid}))",
		"if not str({save_path}).is_empty():",
		"\tvar __tbl_file_{uid} := FileAccess.open({save_path}, FileAccess.WRITE)",
		"\tif __tbl_file_{uid} != null:",
		"\t\t__tbl_file_{uid}.store_string(\"\\n\".join(__tbl_out_{uid}) + \"\\n\")",
		"\t\t__tbl_file_{uid}.close()",
	]))


## Write Version Stamp. The parity covenant forbids nondeterministic EMISSION, so nothing about the
## build is baked into the generated code: the code asks the clock at run time, which is also what a
## build stamp actually wants. ConfigFile because the game reads it back in three lines and it stays
## readable in a diff. The save error is READ, not discarded: a stamp aimed at a folder that does not
## exist (or a read-only res:// in a CI export) would otherwise write nothing at all while the export
## reported success, and the game would ship reading a stale stamp.
static func _write_version_stamp_template() -> String:
	return "\n".join(PackedStringArray([
		"var __stamp_{uid} := ConfigFile.new()",
		"__stamp_{uid}.set_value(\"build\", \"version\", {version})",
		"__stamp_{uid}.set_value(\"build\", \"stamped_at\", Time.get_datetime_string_from_system(true))",
		"var __stamp_err_{uid} := __stamp_{uid}.save({path})",
		"if __stamp_err_{uid} != OK:",
		"\tpush_warning(\"[Write Version Stamp] Could not write %s (%s) - the build carries no stamp.\" % [{path}, error_string(__stamp_err_{uid})])",
	]))
