# Godot EventSheets - R33. The rest of the editor-tool family: the three Sheet Type entries the
# dialog gained (Editor plugin / Import tool / Export hook), the starters each arrives with, the
# On File Imported trigger and its lift, the Include bar's own buttons, and the Doctor's
# "touches nodes outside the open layout" refinement.
#
# Everything asserted here is a VALUE - the exact host a type ships as, the exact words a button
# says, the exact function a trigger compiles to - because those are the things a reader and a
# generated file have to agree about.
@tool
class_name EditorToolTypesTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_type_table() and all_passed
	all_passed = _test_starters() and all_passed
	all_passed = _test_import_trigger() and all_passed
	all_passed = _test_tool_bar() and all_passed
	all_passed = _test_outside_layout_doctor() and all_passed
	return all_passed


## The three parallel tables the dialog reads: a hint per type, the host each forces, and the
## identity line each previews. A type with a hint but no host would ship as a plain Node script.
static func _test_type_table() -> bool:
	var passed: bool = true
	passed = _check("hint count covers every type",
		EventSheetSheetTypeDialog.TYPE_HINTS.size(), 10) and passed
	passed = _check("Editor plugin hint",
		EventSheetSheetTypeDialog.TYPE_HINTS[7],
		"A plugin the editor switches on: it adds a dock, a Tools menu item, an object type.") and passed
	passed = _check("Import tool hint",
		EventSheetSheetTypeDialog.TYPE_HINTS[8],
		"Runs when files are imported - fix up or check what just landed in the project.") and passed
	passed = _check("Export hook hint",
		EventSheetSheetTypeDialog.TYPE_HINTS[9],
		"Runs when the project is exported - stamp a build, bake a file, strip debug content.") and passed
	passed = _check("Editor plugin ships as an EditorPlugin",
		EventSheetSheetTypeDialog.identity_preview(7, "", "CharacterBody2D", ""),
		"Ships as:  extends EditorPlugin") and passed
	passed = _check("Import tool ships as an EditorScript",
		EventSheetSheetTypeDialog.identity_preview(8, "", "", ""),
		"Ships as:  extends EditorScript") and passed
	passed = _check("Export hook ships as an EditorScript",
		EventSheetSheetTypeDialog.identity_preview(9, "", "", ""),
		"Ships as:  extends EditorScript") and passed
	# The host field hides for all four tool types (each forces its own), and the capability ticks
	# belong to the Editor plugin alone.
	for type_index: int in [3, 7, 8, 9]:
		passed = _check("type %d hides the host field" % type_index,
			bool(EventSheetSheetTypeDialog.field_visibility(type_index)["host"]), false) and passed
	passed = _check("only the Editor plugin shows capability ticks",
		bool(EventSheetSheetTypeDialog.field_visibility(7)["plugin_capabilities"]), true) and passed
	passed = _check("an Import tool shows no capability ticks",
		bool(EventSheetSheetTypeDialog.field_visibility(8)["plugin_capabilities"]), false) and passed
	return passed


## Each starter arrives as the thing its menu entry promised, and the dialog reopens on the type it
## actually is - the round trip that makes the three EditorScript types distinguishable at all.
static func _test_starters() -> bool:
	var passed: bool = true
	var plugin: EventSheetResource = EventSheetStarterTemplates.build_starter(12)
	passed = _check("the Editor Plugin starter is an EditorPlugin", plugin.host_class, "EditorPlugin") and passed
	passed = _check("the Editor Plugin starter is a @tool script", plugin.tool_mode, true) and passed
	passed = _check("the Editor Plugin starter classifies as a plugin",
		EventSheetScriptIntent.of_sheet(plugin), EventSheetScriptIntent.Intent.EDITOR_PLUGIN) and passed
	passed = _check("the Editor Plugin starter already adds a Tools menu item",
		EventSheetSheetTypeDialog.sheet_has_capability(plugin, "menu_item"), true) and passed
	passed = _check("the Editor Plugin starter adds no dock yet",
		EventSheetSheetTypeDialog.sheet_has_capability(plugin, "dock"), false) and passed

	var import_tool: EventSheetResource = EventSheetStarterTemplates.build_starter(13)
	passed = _check("the Import Tool starter is an EditorScript", import_tool.host_class, "EditorScript") and passed
	passed = _check("the Import Tool starter reopens as an Import tool",
		EventSheetSheetTypeDialog.editor_script_type_index(import_tool), 8) and passed

	var export_hook: EventSheetResource = EventSheetStarterTemplates.build_starter(14)
	passed = _check("the Export Hook starter is an EditorScript", export_hook.host_class, "EditorScript") and passed
	passed = _check("the Export Hook starter reopens as an Export hook",
		EventSheetSheetTypeDialog.editor_script_type_index(export_hook), 9) and passed

	# A plain Editor Tool has neither trigger and stays index 3 - the one you press Run on.
	passed = _check("a plain Editor Tool reopens as an Editor Tool",
		EventSheetSheetTypeDialog.editor_script_type_index(EventSheetStarterTemplates.build_starter(10)), 3) and passed
	return passed


## On File Imported compiles to the plain named function the import hook calls, and reads straight
## back out of a compiled file - the whole reason it is a function rather than a signal connection.
static func _test_import_trigger() -> bool:
	var passed: bool = true
	var signature: Dictionary = TriggerResolver.resolve_trigger(_import_event())
	passed = _check("On File Imported compiles to the hook function",
		str(signature.get("function_name", "")), "_on_files_imported") and passed
	passed = _check("On File Imported is handed the imported paths",
		str(signature.get("args", "")), "paths: PackedStringArray") and passed
	passed = _check("On File Imported never wires a signal",
		str(signature.get("signal_name", "")), "") and passed

	var sheet: EventSheetResource = EventSheetStarterTemplates.build_starter(13)
	var output_path: String = "user://eventsheets_import_tool_probe.gd"
	var compiled: Dictionary = SheetCompiler.compile(sheet, output_path)
	passed = _check("the Import Tool starter compiles", bool(compiled.get("success", false)), true) and passed
	var output: String = FileAccess.get_file_as_string(output_path)
	passed = _check("the compiled tool declares the hook the editor calls",
		output.contains("func _on_files_imported(paths: PackedStringArray) -> void:"), true) and passed
	# The seam's own discovery has to find that file, or the trigger fires for nobody. Loaded by path
	# because the hook carries no class_name on purpose (naming it would widen the editor's boot).
	var hook: GDScript = load("res://addons/eventforge/editor/import_tools_plugin.gd") as GDScript
	passed = _check("the import hook's text test matches the emitted header",
		output.contains("func %s(" % str(hook.get("HOOK_FUNCTION"))), true) and passed
	DirAccess.remove_absolute(output_path)
	return passed


## The Include bar's own buttons: which sheets get them, in which order, and what each says.
static func _test_tool_bar() -> bool:
	var passed: bool = true
	EventSheetEditorToolBar.clear_output()
	var plain: EventSheetResource = EventSheetResource.new()
	plain.host_class = "CharacterBody2D"
	passed = _check("a game sheet gets no tool buttons",
		EventSheetEditorToolBar.buttons_for(plain).size(), 0) and passed

	var tool_sheet: EventSheetResource = EventSheetStarterTemplates.build_starter(10)
	passed = _check("an editor script gets Run now, Reload and Output",
		_button_texts(tool_sheet), "▶ Run now|↻ Reload|Output ▾ no output yet") and passed

	var plugin: EventSheetResource = EventSheetStarterTemplates.build_starter(12)
	passed = _check("a plugin also gets Enable plugin",
		_button_texts(plugin), "▶ Run now|↻ Reload|Output ▾ no output yet|Enable plugin") and passed

	# Once a run has printed something, Output says how much rather than "no output yet".
	EventSheetEditorToolBar.record_output("res://addons/probe/probe.gd", PackedStringArray(["a", "b", "c"]))
	passed = _check("Output counts the lines the last run printed",
		EventSheetEditorToolBar.output_text("res://addons/probe/probe.gd"), "Output ▾ 3 lines") and passed
	EventSheetEditorToolBar.clear_output()

	passed = _check("a plugin's folder is the name Godot enables it by",
		EventSheetEditorToolBar.plugin_folder_name("res://addons/snap_selection/snap_selection.gd"), "snap_selection") and passed
	passed = _check("a script outside res://addons has no plugin folder",
		EventSheetEditorToolBar.plugin_folder_name("res://tools/snap.gd"), "") and passed
	passed = _check("the plugin.cfg names the script beside it",
		EventSheetEditorToolBar.plugin_cfg_text("Snap Selection", "Snaps the selection", "snap_selection.gd").contains("script=\"snap_selection.gd\""), true) and passed
	return passed


## The Doctor refinement: mutating nodes reached by path, with no anchor on the open layout.
static func _test_outside_layout_doctor() -> bool:
	var passed: bool = true
	passed = _check("a tool that edits nodes it looked up by path is flagged",
		_outside_layout_message("var marker: Node2D = Node2D.new()\nget_node(\"Player\").add_child(marker)", "etol_bare").contains("lands outside your scene"), true) and passed
	passed = _check("the same tool anchored on the open layout is not flagged",
		_outside_layout_message("var root: Node = EditorInterface.get_edited_scene_root()\nvar marker: Node2D = Node2D.new()\nroot.get_node(\"Player\").add_child(marker)", "etol_anchored").is_empty(), true) and passed
	passed = _check("a tool that only reads by path is not flagged",
		_outside_layout_message("print(get_node(\"Player\").name)", "etol_read").is_empty(), true) and passed
	return passed


static func _import_event() -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnFileImported"
	return event


static func _button_texts(sheet: EventSheetResource) -> String:
	var texts: PackedStringArray = PackedStringArray()
	for button: Dictionary in EventSheetEditorToolBar.buttons_for(sheet):
		texts.append(str(button["text"]))
	return "|".join(texts)


## Compiles a tool fixture, runs the single safety check, and returns the outside-layout message
## ("" when there is none). Both files are cleaned up.
static func _outside_layout_message(body: String, name: String) -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "EditorScript"
	sheet.tool_mode = true
	var run_event: EventRow = EventRow.new()
	run_event.trigger_provider_id = "Core"
	run_event.trigger_id = "OnEditorRun"
	var chore: RawCodeRow = RawCodeRow.new()
	chore.code = body
	run_event.actions.append(chore)
	sheet.events.append(run_event)
	var path: String = "user://%s.tres" % name
	ResourceSaver.save(sheet, path)
	var output_path: String = EventSheetProjectDoctor.output_path_for(path)
	SheetCompiler.compile(sheet, output_path)
	var findings: Array[Dictionary] = []
	EventSheetProjectDoctor.check_editor_tool_safety(PackedStringArray([path]), findings)
	var message: String = ""
	for finding: Dictionary in findings:
		if str(finding.get("check")) == "editor-tool-outside-layout":
			message = str(finding.get("message"))
	DirAccess.remove_absolute(path)
	if FileAccess.file_exists(output_path):
		DirAccess.remove_absolute(output_path)
	return message


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual != expected:
		print("  [FAIL] %s (got %s, expected %s)" % [label, actual, expected])
		return false
	print("[PASS] editor_tool_types_test: %s" % label)
	return true
