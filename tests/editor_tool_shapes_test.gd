@tool
class_name EditorToolShapesTest
extends RefCounted
# W17 / W18 / W21 / W23 - every shape Godot's editor has as a New Sheet entry, the tool author's
# everyday Editor words, and the twenty-four editor-building nouns Familiar Words now carries.
#
# The load-bearing gate here is the two-way one: each of the fifteen shapes is compiled, the result
# is opened again as a sheet, and the recompile has to reproduce every byte. A skeleton that cannot
# be re-read is worse than no skeleton - it would hand a reader a file the editor stops
# understanding the moment they save it.


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_shape_list() and all_passed
	all_passed = _test_every_shape_round_trips() and all_passed
	all_passed = _test_sheet_type_dialog() and all_passed
	all_passed = _test_intents() and all_passed
	all_passed = _test_editor_vocabulary() and all_passed
	all_passed = _test_editor_signal_triggers() and all_passed
	all_passed = _test_editor_reading_words() and all_passed
	all_passed = _test_editor_words_glossary() and all_passed
	all_passed = _test_picker_pages() and all_passed
	all_passed = _test_command_tool_rows() and all_passed
	all_passed = _test_glossary_hover() and all_passed
	return all_passed


## W17. The list itself, as VALUES: fifteen shapes, the four R33 ones keeping their ids, in the
## mockup's order. An id is what a saved sheet was created from, so a renumbering shows up here.
static func _test_shape_list() -> bool:
	var all_passed: bool = true
	var ids: PackedStringArray = PackedStringArray()
	var labels: PackedStringArray = PackedStringArray()
	for shape: Dictionary in EventSheetStarterTemplates.EDITOR_TOOL_SHAPES:
		ids.append(str(int(shape["id"])))
		labels.append(str(shape["label"]))
	all_passed = _check("every editor shape keeps its id",
		",".join(ids), "10,12,13,14,15,16,17,18,19,20,21,22,23,24,25") and all_passed
	all_passed = _check("the list reads in the mockup's order and words",
		" | ".join(labels),
		"One-click chore | Editor plugin | Importer add-on | Export hook | Dock panel | Bottom panel | Tools menu item | Properties bar add-on | Context menu item | Layout view handle | Thumbnail maker | Debugger panel | Command tool | Test sheet | Object type") and all_passed
	var new_labels: PackedStringArray = PackedStringArray()
	for starter: Dictionary in EventSheetStarterTemplates.create_new_starters():
		if int(starter["id"]) == 23:
			new_labels.append(str(starter["label"]))
	all_passed = _check("the FileSystem Create New dialog offers the shapes with their note",
		"|".join(new_labels), "Command tool - headless, run with arguments") and all_passed
	return all_passed


## W17. Compile each skeleton, open the result, compile again - byte for byte. Also pins the host
## each shape ships as, because the host is what the editor looks at to decide what this file IS.
static func _test_every_shape_round_trips() -> bool:
	var all_passed: bool = true
	var hosts: PackedStringArray = PackedStringArray()
	for shape: Dictionary in EventSheetStarterTemplates.EDITOR_TOOL_SHAPES:
		var template_id: int = int(shape["id"])
		var sheet: EventSheetResource = EventSheetStarterTemplates.build_starter(template_id)
		hosts.append(sheet.host_class)
		var path: String = "user://w17_shape_%d.gd" % template_id
		var first: String = str(SheetCompiler.compile(sheet, path).get("output", ""))
		var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		handle.store_string(first)
		handle.close()
		var reopened: EventSheetResource = GDScriptImporter.new().import_external(path)
		var second: String = str(SheetCompiler.compile(reopened, path).get("output", ""))
		all_passed = _check("the %s skeleton re-opens as exactly what it was written from" % str(shape["label"]),
			second, first) and all_passed
	all_passed = _check("each shape ships as the class the editor calls",
		",".join(hosts),
		"EditorScript,EditorPlugin,EditorScript,EditorScript,EditorPlugin,EditorPlugin,EditorPlugin,EditorInspectorPlugin,EditorContextMenuPlugin,EditorPlugin,EditorResourcePreviewGenerator,EditorDebuggerPlugin,SceneTree,Node,EditorPlugin") and all_passed
	# The pairing is the lesson each plugin skeleton teaches: what is added when the plugin is
	# switched on comes back out when it is switched off.
	var dock_sheet: EventSheetResource = EventSheetStarterTemplates.build_starter(15)
	var added: PackedStringArray = PackedStringArray()
	var removed: PackedStringArray = PackedStringArray()
	for entry: Variant in dock_sheet.events:
		var event: EventRow = entry as EventRow
		if event == null:
			continue
		for action: Variant in event.actions:
			if not (action is ACEAction):
				continue
			if event.trigger_id == "OnPluginEnabled":
				added.append((action as ACEAction).ace_id)
			elif event.trigger_id == "OnPluginDisabled":
				removed.append((action as ACEAction).ace_id)
	all_passed = _check("the dock skeleton hangs its panel on enable",
		",".join(added), "AddEditorDock") and all_passed
	all_passed = _check("and takes it down again on disable",
		",".join(removed), "RemoveEditorDock") and all_passed
	# What a shape adds to the editor is what its own Include bar says it adds - a Bottom panel sheet
	# claimed nothing there until the census learned the verb.
	var claimed: PackedStringArray = PackedStringArray()
	for entry: Dictionary in EventSheetEditorToolCensus.from_sheet(EventSheetStarterTemplates.build_starter(16)):
		claimed.append(str(entry.get("label", "")))
	all_passed = _check("the bottom-panel shape says what it adds to the editor",
		"|".join(claimed), "bottom panel: My Panel") and all_passed
	return all_passed


## W17. The Sheet Type dialog's two new shapes. The add-on is the one tool type whose host the sheet
## does NOT force - which of Godot's add-on classes it is, is the whole choice.
static func _test_sheet_type_dialog() -> bool:
	var all_passed: bool = true
	all_passed = _check("the dialog offers twelve types",
		EventSheetSheetTypeDialog.TYPE_HINTS.size(), 12) and all_passed
	all_passed = _check("the add-on line names the six shapes rather than the concept",
		EventSheetSheetTypeDialog.TYPE_HINTS[10],
		"A piece a plugin hands the editor: a Properties bar add-on, importer, thumbnail maker, debugger panel, context menu or view handle.") and all_passed
	all_passed = _check("the command-tool line says where it runs",
		EventSheetSheetTypeDialog.TYPE_HINTS[11],
		"A script the Godot binary runs headless from the command line, with arguments and an exit code.") and all_passed
	all_passed = _check("an add-on keeps its host field",
		bool(EventSheetSheetTypeDialog.field_visibility(10).get("host", false)), true) and all_passed
	all_passed = _check("a command tool does not - it is always a SceneTree",
		bool(EventSheetSheetTypeDialog.field_visibility(11).get("host", true)), false) and all_passed
	all_passed = _check("an untyped add-on previews the one most people mean first",
		EventSheetSheetTypeDialog.identity_preview(10, "", "", ""),
		"Ships as:  extends EditorInspectorPlugin") and all_passed
	all_passed = _check("a typed add-on previews the class that was typed",
		EventSheetSheetTypeDialog.identity_preview(10, "", "EditorImportPlugin", ""),
		"Ships as:  extends EditorImportPlugin") and all_passed
	all_passed = _check("a command tool previews its forced host",
		EventSheetSheetTypeDialog.identity_preview(11, "", "Node", ""),
		"Ships as:  extends SceneTree") and all_passed
	all_passed = _check("both new types are tool sheets",
		EventSheetSheetTypeDialog.TOOL_TYPE_INDICES.has(10) and EventSheetSheetTypeDialog.TOOL_TYPE_INDICES.has(11),
		true) and all_passed
	return all_passed


## W17. Reopening a saved add-on or command tool has to land on the same type it was created as -
## before this, an EditorInspectorPlugin sheet classified as a custom node and lost its host the next
## time anyone pressed OK on the dialog.
static func _test_intents() -> bool:
	var all_passed: bool = true
	var addon: EventSheetResource = EventSheetStarterTemplates.build_starter(18)
	all_passed = _check("a Properties bar add-on reopens as an editor add-on",
		EventSheetScriptIntent.of_sheet(addon), EventSheetScriptIntent.Intent.EDITOR_ADDON) and all_passed
	var command: EventSheetResource = EventSheetStarterTemplates.build_starter(23)
	all_passed = _check("a SceneTree script reopens as a command tool",
		EventSheetScriptIntent.of_sheet(command), EventSheetScriptIntent.Intent.COMMAND_TOOL) and all_passed
	all_passed = _check("and each says what it is on the identity pill",
		"%s / %s" % [
			str(EventSheetScriptIntent.display(EventSheetScriptIntent.Intent.EDITOR_ADDON).get("label", "")),
			str(EventSheetScriptIntent.display(EventSheetScriptIntent.Intent.COMMAND_TOOL).get("label", ""))],
		"Editor Add-on / Command Tool") and all_passed
	var plugin: EventSheetResource = EventSheetStarterTemplates.build_starter(12)
	all_passed = _check("the two shipped tool intents are untouched",
		"%d/%d" % [EventSheetScriptIntent.of_sheet(plugin), EventSheetScriptIntent.of_sheet(EventSheetStarterTemplates.build_starter(10))],
		"%d/%d" % [EventSheetScriptIntent.Intent.EDITOR_PLUGIN, EventSheetScriptIntent.Intent.EDITOR_TOOL]) and all_passed
	# An add-on has no entry point of its own, so its bar offers no Run - but Reload and Output are
	# exactly as useful on it as on a chore.
	var kinds: PackedStringArray = PackedStringArray()
	for button: Dictionary in EventSheetEditorToolBar.buttons_for(addon, ""):
		kinds.append(str(button["kind"]))
	all_passed = _check("an add-on's bar reloads and shows output, but offers no Run",
		",".join(kinds), "editor_tool_reload,editor_tool_output") and all_passed
	return all_passed


## W18. The tool author's everyday set: each row emits the exact EditorInterface / ProjectSettings
## line it names. A template is a frozen promise, so it is pinned as a value.
static func _test_editor_vocabulary() -> bool:
	var all_passed: bool = true
	var expected: Dictionary = {
		"EditorIcon": "EditorInterface.get_editor_theme().get_icon({icon_name}, \"EditorIcons\")",
		"EditorPreference": "EditorInterface.get_editor_settings().get_setting({path})",
		"ProjectSetting": "ProjectSettings.get_setting({path})",
		"EditorMainScreen": "EditorInterface.get_editor_main_screen()",
		"SetProjectSetting": "ProjectSettings.set_setting({path}, {value})",
		"SaveProjectSettings": "ProjectSettings.save()",
		"SwitchToWorkspace": "EditorInterface.set_main_screen_editor({workspace})",
		"ShowInProjectBar": "EditorInterface.get_file_system_dock().navigate_to_path({path})",
		"OpenScriptAtLine": "EditorInterface.get_script_editor().goto_line({line})",
		"AddEditorWindow": "EditorInterface.get_base_control().add_child({window})",
		"AddCommandPaletteCommand": "EditorInterface.get_command_palette().add_command({title}, {key_name}, {handler})",
		"AddBottomPanel": "add_control_to_bottom_panel({control}, {title})",
		"RemoveBottomPanel": "remove_control_from_bottom_panel({control})",
	}
	var found: Dictionary = {}
	var categories: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeEditorAuthorACEs.get_descriptors():
		found[descriptor.ace_id] = descriptor.codegen_template
		categories[descriptor.ace_id] = descriptor.category
	for ace_id: String in expected:
		all_passed = _check("%s emits the line the reading recognises" % ace_id,
			str(found.get(ace_id, "")), str(expected[ace_id])) and all_passed
	all_passed = _check("the project settings live on their own page",
		str(categories.get("SaveProjectSettings", "")), "Editor Tools: Project & preferences") and all_passed
	all_passed = _check("and the editor's surfaces on theirs",
		str(categories.get("SwitchToWorkspace", "")), "Editor Tools: Panels & menus") and all_passed
	all_passed = _check("the icon field is the one that draws what it names",
		_param_hint(found, "EditorIcon", "icon_name"), "editor_icon") and all_passed
	all_passed = _check("the preference path field offers the real paths",
		_param_hint(found, "EditorPreference", "path"), "editor_preference") and all_passed
	all_passed = _check("and so does the project setting one",
		_param_hint(found, "SetProjectSetting", "path"), "project_setting") and all_passed
	# There is no editor around in a headless run, so the icon field degrades to a plain text box
	# rather than erroring - the one behaviour a test can pin about a live picker.
	all_passed = _check("with no editor around the icon field simply has nothing to offer",
		ACEParamsDialog.editor_icon_choices().size(), 0) and all_passed
	return all_passed


static func _param_hint(_found: Dictionary, ace_id: String, param_id: String) -> String:
	for descriptor: ACEDescriptor in EventForgeEditorAuthorACEs.get_descriptors():
		if descriptor.ace_id != ace_id:
			continue
		for parameter: ACEParam in descriptor.params:
			if parameter.id == param_id:
				return parameter.hint
	return ""


## W18. The two things the editor tells a tool about. Both connect on an editor object rather than
## on the sheet's own node, and both have to come back as themselves when the file is opened again.
static func _test_editor_signal_triggers() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "EditorPlugin"
	sheet.tool_mode = true
	for pair: Array in [["OnProjectFilesChanged", "EditorInterface.get_resource_filesystem().filesystem_changed.connect(_on_project_files_changed)"],
			["OnPreferencesChanged", "EditorInterface.get_editor_settings().settings_changed.connect(_on_preferences_changed)"]]:
		var event: EventRow = EventRow.new()
		event.trigger_provider_id = "Core"
		event.trigger_id = str(pair[0])
		var body: RawCodeRow = RawCodeRow.new()
		body.code = "print(\"changed\")"
		event.actions.append(body)
		var one_sheet: EventSheetResource = EventSheetResource.new()
		one_sheet.host_class = "EditorPlugin"
		one_sheet.tool_mode = true
		one_sheet.events.append(event)
		var path: String = "user://w18_%s.gd" % str(pair[0])
		var first: String = str(SheetCompiler.compile(one_sheet, path).get("output", ""))
		all_passed = _check("%s connects on the editor's own object" % str(pair[0]),
			first.contains(str(pair[1])), true) and all_passed
		var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		handle.store_string(first)
		handle.close()
		var reopened: EventSheetResource = GDScriptImporter.new().import_external(path)
		all_passed = _check("%s re-opens as itself, byte for byte" % str(pair[0]),
			str(SheetCompiler.compile(reopened, path).get("output", "")), first) and all_passed
		var lifted: PackedStringArray = PackedStringArray()
		for entry: Variant in reopened.events:
			if entry is EventRow and not (entry as EventRow).trigger_id.is_empty():
				lifted.append((entry as EventRow).trigger_id)
		all_passed = _check("%s comes back as the trigger, not as a handler function" % str(pair[0]),
			",".join(lifted), str(pair[0])) and all_passed
	return all_passed


## W18. The reading side: the three editor questions that carry an argument, in the Editor object's
## own dotted names. A whole-spelling replace cannot reach them, so they go through the pattern pass.
static func _test_editor_reading_words() -> bool:
	var all_passed: bool = true
	all_passed = _check("an editor icon reads as the Editor's own expression",
		EventSheetSentence.editor_words("EditorInterface.get_editor_theme().get_icon(\"Node2D\", \"EditorIcons\")"),
		"Editor.Icon(\"Node2D\")") and all_passed
	all_passed = _check("one Editor Setting reads as a preference, not as the settings object",
		EventSheetSentence.editor_words("EditorInterface.get_editor_settings().get_setting(\"interface/theme/base_color\")"),
		"Editor.Preference(\"interface/theme/base_color\")") and all_passed
	all_passed = _check("the settings object itself still reads as itself",
		EventSheetSentence.editor_words("EditorInterface.get_editor_settings()"), "Editor.Settings") and all_passed
	all_passed = _check("a project setting reads as the project's, not the editor's",
		EventSheetSentence.editor_words("ProjectSettings.get_setting(\"application/config/name\")"),
		"Project.Setting(\"application/config/name\")") and all_passed
	all_passed = _check("the workspace area gets its name",
		EventSheetSentence.editor_words("EditorInterface.get_editor_main_screen()"), "Editor.MainScreen") and all_passed
	all_passed = _check("a line with none of it is handed straight back",
		EventSheetSentence.editor_words("position.x + 1"), "position.x + 1") and all_passed
	return all_passed


## W21. The editor-building words: twenty-four entries, both spellings, and the Manual page that
## says why each one was renamed.
static func _test_editor_words_glossary() -> bool:
	var all_passed: bool = true
	all_passed = _check("the toggle carries all twenty-four editor words",
		EventSheetWords.EDITOR_KEYS.size(), 24) and all_passed
	for pair: Array in [["editor_plugin", "Editor plugin", "EditorPlugin"],
			["editor_object", "Editor", "EditorInterface"],
			["filesystem_dock", "Project bar", "FileSystem dock"],
			["editor_preferences", "Preferences", "EditorSettings"],
			["tool_annotation", "runs in the editor too", "@tool"],
			["command_tool", "Command tool", "SceneTree script"],
			["shared_store", "Shared store", "Static class"],
			["behavior_of", "Behavior of …", "Helper class"],
			["workspace", "Workspace", "Main screen"],
			["object_type", "Object type", "Custom type"]]:
		all_passed = _check("%s reads both ways" % str(pair[0]),
			"%s / %s" % [EventSheetWords.familiar_default(str(pair[0])), EventSheetWords.plain_default(str(pair[0]))],
			"%s / %s" % [str(pair[1]), str(pair[2])]) and all_passed
	all_passed = _check("Godot's spelling is one lookup away from the sheet's",
		EventSheetWords.godot_word("Project bar"), "FileSystem dock") and all_passed
	all_passed = _check("and the sheet's is one lookup away from Godot's",
		EventSheetWords.sheet_word("EditorSettings"), "Preferences") and all_passed
	all_passed = _check("a word neither vocabulary has says so rather than guessing",
		EventSheetWords.godot_word("Nonesuch"), "") and all_passed
	all_passed = _check("the game words still lead the page",
		EventSheetWords.keys()[0], "inheritance_set") and all_passed
	var rows: Array[Dictionary] = EventSheetDocEditorWords.rows()
	all_passed = _check("the Manual page lists every one of them", rows.size(), 24) and all_passed
	all_passed = _check("each row carries the reason the word changed",
		str(EventSheetDocEditorWords.row("filesystem_dock").get("why", "")),
		"It is the project, listed. \"FileSystem\" describes the storage; a reader is looking for their project.") and all_passed
	var chapters: int = 0
	for block: Dictionary in EventSheetDocEditorWords.blocks():
		if str(block.get("kind", "")) == "heading" and int(block.get("level", 0)) == 2:
			chapters += 1
	all_passed = _check("the page is one chapter per word", chapters, 24) and all_passed
	all_passed = _check("and the Manual can route to it",
		EventSheetDocReference.has_page("reference:editorwords"), true) and all_passed
	all_passed = _check("under the title the mockup gave it",
		EventSheetDocReference.title_for(EventSheetDocReference.KIND_EDITOR_WORDS, ""),
		"The words for building editor tools") and all_passed
	return all_passed


## W23. The Editor object's pages. A page is still the Editor, so every gate that used to compare
## the whole category has to recognise the prefix - comparing on equality would have quietly
## un-scoped every paged row onto game sheets, which is the one thing the R30 rule forbids.
static func _test_picker_pages() -> bool:
	var all_passed: bool = true
	all_passed = _check("a paged Editor row is still an Editor row",
		ACEPickerDialog.is_editor_tools_category("Editor Tools: Panels & menus"), true) and all_passed
	all_passed = _check("and is still hidden on a game sheet",
		ACEPickerDialog.editor_ace_hidden("Editor Tools: Project & preferences", false), true) and all_passed
	all_passed = _check("while a tool sheet sees it",
		ACEPickerDialog.editor_ace_hidden("Editor Tools: Project & preferences", true), false) and all_passed
	all_passed = _check("a category that merely starts with the words is not one of ours",
		ACEPickerDialog.is_editor_tools_category("Editor Toolsmith"), false) and all_passed
	all_passed = _check("each page says what it is for",
		str(EventForgeEditorAuthorACEs.section_descriptions().get("Editor Tools: Project & preferences", "")).begins_with("This project's settings"),
		true) and all_passed
	# The two rows that are about the PROJECT rather than about the editor wear the project's name.
	all_passed = _check("writing a project setting reads as the Project, not the Editor",
		"|".join(ViewportRowBuilder.PROJECT_ACE_IDS), "SetProjectSetting|SaveProjectSettings") and all_passed
	# ── W23, the rest of the pages. Every row that belonged to one named surface is filed on it, so
	# the flat root keeps only the one-off chores. Pinned by VALUE per row: a row that quietly slid
	# back onto the root would still pass a count.
	var filed: Dictionary = {}
	for module: Object in [EventForgeToolingACEs, EventForgeEditorObjectACEs, EventForgeEditorAuthorACEs]:
		for descriptor: ACEDescriptor in module.call("get_descriptors"):
			filed[str(descriptor.ace_id)] = str(descriptor.category)
	for pair: Array in [
			["OnPluginEnabled", "Editor Tools: Plugin lifecycle"],
			["OnEditorObjectSelected", "Editor Tools: Plugin lifecycle"],
			["AddEditorDock", "Editor Tools: Panels & menus"],
			["AddEditorObjectType", "Editor Tools: Panels & menus"],
			["AddEditorWindow", "Editor Tools: Panels & menus"],
			["AddEditorInspectorPlugin", "Editor Tools: Properties bar"],
			["RemoveEditorInspectorPlugin", "Editor Tools: Properties bar"],
			["EditorUndoHistory", "Editor Tools: Undo history"],
			["EditorSettingsObject", "Editor Tools: Project & preferences"],
			["OnFileImported", "Editor Tools: Import & export"],
			["ExportHasFeature", "Editor Tools: Import & export"],
			["EnsureFolderExists", "Editor Tools: Files & folders"],
			["SaveNodeAsScene", "Editor Tools: Files & folders"],
			["OnCommandToolRun", "Editor Tools: Command tool"],
			["CommandToolFinishWithCode", "Editor Tools: Command tool"],
			# W6 - the menu page: the item that goes in one, and the event the chosen item runs.
			["MenuAddItem", "Editor Tools: Menus"],
			["OnMenuItemChosen", "Editor Tools: Menus"],
			# The one-off chores stay on the root, so the folder a reader lands on is not empty.
			["OpenSceneInEditor", "Editor Tools"],
			["EditorSelectedNodes", "Editor Tools"]]:
		all_passed = _check("%s is filed on its own surface" % str(pair[0]),
			str(filed.get(str(pair[0]), "")), str(pair[1])) and all_passed
	for page: String in ["Editor Tools: Plugin lifecycle", "Editor Tools: Properties bar",
			"Editor Tools: Undo history", "Editor Tools: Files & folders",
			"Editor Tools: Import & export", "Editor Tools: Command tool", "Editor Tools: Menus"]:
		all_passed = _check("the %s page is gated to tool sheets" % page,
			"%s/%s" % [ACEPickerDialog.editor_ace_hidden(page, false), ACEPickerDialog.editor_ace_hidden(page, true)],
			"true/false") and all_passed
		all_passed = _check("the %s page says what it is for" % page,
			EventSheetSectionInfo.description_for(page).is_empty(), false) and all_passed
	return all_passed


## W10. The command tool's four rows, and the one thing that makes them worth having: each writes
## EXACTLY the line the reading already recognises, so a tool authored from the picker and one typed
## by hand are the same file. The whole-shape byte gate above covers the skeleton; this covers the
## individual spellings, which is where a paraphrase would hide.
static func _test_command_tool_rows() -> bool:
	var all_passed: bool = true
	var descriptors: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeToolingACEs.get_descriptors():
		descriptors[str(descriptor.ace_id)] = descriptor
	for pair: Array in [["CommandToolFinish", "quit()"],
			["CommandToolFinishWithCode", "quit({code})"],
			["CommandToolArguments", "OS.get_cmdline_user_args()"]]:
		all_passed = _check("%s writes the line the reading claims" % str(pair[0]),
			str((descriptors[str(pair[0])] as ACEDescriptor).codegen_template), str(pair[1])) and all_passed
	var run_event: EventRow = EventRow.new()
	run_event.trigger_provider_id = "Core"
	run_event.trigger_id = "OnCommandToolRun"
	all_passed = _check("On run is the SceneTree script's whole run",
		str(TriggerResolver.resolve_trigger(run_event).get("function_name", "")), "_init") and all_passed
	all_passed = _check("and it runs once, like every other lifetime callback",
		TriggerResolver.tempo_class_for("OnCommandToolRun"), TriggerResolver.TEMPO_ONCE) and all_passed
	# The object cell: a command tool is not the editor - nothing of the editor is even open - so its
	# rows wear the same object a hand-written tools/*.gd already reads under.
	all_passed = _check("a command tool row is the Command tool's, not the Editor's",
		EventSheetToolFiles.OBJECT_COMMAND_TOOL, "Command tool") and all_passed
	all_passed = _check("the object cell reads the page it is keyed off",
		ViewportRowBuilder.COMMAND_TOOL_PAGE, "Editor Tools: Command tool") and all_passed
	# The skeleton itself: an EVENT with the On run trigger, not a hand-written `_init` function.
	var skeleton: EventSheetResource = EventSheetStarterTemplates.build_starter(23)
	var triggers: PackedStringArray = PackedStringArray()
	for entry: Variant in skeleton.events:
		if entry is EventRow:
			triggers.append(str((entry as EventRow).trigger_id))
	all_passed = _check("the New Sheet skeleton starts from the On run event",
		"|".join(triggers), "OnCommandToolRun") and all_passed
	all_passed = _check("and carries no hand-written callback beside it",
		skeleton.functions.size(), 0) and all_passed
	var compiled: String = str(SheetCompiler.compile(skeleton, "user://w10_command_tool.gd").get("output", ""))
	all_passed = _check("so the file it compiles to opens as a command tool",
		EventSheetToolFiles.kind_of(compiled.split("\n")), EventSheetToolFiles.KIND_COMMAND_TOOL) and all_passed
	all_passed = _check("with the run as a plain _init and no annotation on it",
		compiled.contains("\nfunc _init() -> void:\n\tvar args: PackedStringArray = OS.get_cmdline_user_args()"),
		true) and all_passed
	all_passed = _check("and the finish the picker wrote, verbatim",
		compiled.contains("\n\tquit()\n"), true) and all_passed
	return all_passed


## M46. The glossary lens as a hover line. The promise the renamed nouns are only acceptable under is
## that nothing is HIDDEN by the rename - so the lookup has to answer from either side, and has to
## stay silent about a word it does not know rather than inventing a translation.
static func _test_glossary_hover() -> bool:
	var all_passed: bool = true
	all_passed = _check("the sheet's word hovers as Godot's",
		EventSheetWords.glossary_hover_for("Properties bar", true, {}),
		"Properties bar - Godot calls this Inspector.\nThe properties panel and its add-ons.") and all_passed
	all_passed = _check("and Godot's hovers as the sheet's",
		EventSheetWords.glossary_hover_for("Inspector", false, {}),
		"Inspector - this sheet calls it Properties bar.\nThe properties panel and its add-ons.") and all_passed
	all_passed = _check("a command tool says what a SceneTree script is",
		EventSheetWords.glossary_hover_for("Command tool", true, {}),
		"Command tool - Godot calls this SceneTree script.\nA script run from the command line.") and all_passed
	all_passed = _check("a word spelled the same in both vocabularies says nothing",
		EventSheetWords.glossary_hover_for("Tools menu", true, {}), "") and all_passed
	all_passed = _check("and a word that is not one of ours says nothing either",
		EventSheetWords.glossary_hover_for("velocity", true, {}), "") and all_passed
	all_passed = _check("a word the reader typed themselves still names Godot's",
		EventSheetWords.glossary_hover_for("Side bar", true, {"familiar": {"inspector": "Side bar"}}),
		"Side bar - Godot calls this Inspector.\nThe properties panel and its add-ons.") and all_passed
	var covered: int = 0
	for key: String in EventSheetWords.EDITOR_KEYS:
		if not EventSheetWords.glossary_hover_for(EventSheetWords.familiar_default(key), true, {}).is_empty():
			covered += 1
	# Tools menu is the one noun spelled identically in both vocabularies, so twenty-three of the
	# twenty-four have something to say. A lens that answered for all of them would be padding.
	all_passed = _check("every editor noun with two spellings carries the lens", covered, 23) and all_passed
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] editor_tool_shapes_test: %s" % label)
		return true
	print("[FAIL] editor_tool_shapes_test: %s (got %s, expected %s)" % [label, actual, expected])
	return false
