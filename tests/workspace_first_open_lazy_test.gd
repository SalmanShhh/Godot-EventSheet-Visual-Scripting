@tool
extends RefCounted
# Godot EventSheets - the first open of a sheet compiles what the first paint draws, and the dialogs,
# windows and studios a click opens are compiled on that click.
#
# The workspace is loaded by path on the first open, and in GDScript a class named anywhere in a
# file's CODE compiles that class - and everything it names - the moment the file loads. The dock used
# to hold ~95 delegates as typed, eagerly built fields, and register itself through the public API,
# so the first open compiled the Manual, the Doctor, the studios, the wizards and the whole API with
# it. Pinned here as values:
#   1. the files the first open measures (the static walk tools/measure_editor_closure.gd does) leave
#      out the click-only windows, dialogs and studios;
#   2. the dock and the helpers the first paint builds never name the API, the compiler, the importer,
#      the Doctor or the pickers in code - they reach each by path when somebody asks;
#   3. every path they reach that way exists, so a renamed file fails here rather than on the click;
#   4. the storage the workspace writes to is the storage the public API reads, and a freed workspace
#      takes its own palette commands and row items with it;
#   5. a delegate built on demand is wired exactly as the eager one was: built once, back-reference
#      set, its signals connected to the dock.

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "workspace_first_open_lazy_test"
const CLOSURE_TOOL := "res://tools/measure_editor_closure.gd"
const EDITOR_PATH := "res://addons/eventforge/editor/event_sheet_editor.gd"
const DOCK_PATH := "res://addons/eventsheet/editor/event_sheet_dock.gd"
const DOCK_REGISTRY_PATH := "res://addons/eventsheet/api/dock_registry.gd"

## What a click opens, and the first open of a sheet must not compile.
const CLICK_ONLY := [
	"res://addons/eventsheet/editor/docs/doc_window.gd",
	"res://addons/eventsheet/editor/docs/doc_chores.gd",
	"res://addons/eventsheet/editor/dock/welcome_window.gd",
	"res://addons/eventsheet/editor/dock/tour_window.gd",
	"res://addons/eventsheet/editor/dock/project_doctor_panel.gd",
	"res://addons/eventsheet/editor/dock/save_studio.gd",
	"res://addons/eventsheet/editor/dock/translation_studio.gd",
	"res://addons/eventsheet/editor/dock/starter_templates.gd",
	"res://addons/eventsheet/editor/dock/find_references_panel.gd",
	"res://addons/eventsheet/editor/dock/import_sheet_wizard.gd",
	"res://addons/eventsheet/editor/dock/new_addon_panel.gd",
	"res://addons/eventsheet/editor/dock/new_resource_wizard.gd",
	"res://addons/eventsheet/editor/dock/ai_generate_window.gd",
	"res://addons/eventsheet/editor/dock/ask_window.gd",
	"res://addons/eventsheet/editor/dock/include_manager.gd",
	"res://addons/eventsheet/editor/dock/debugger_window.gd",
	"res://addons/eventsheet/editor/dock/export_pack.gd",
	"res://addons/eventsheet/editor/dock/custom_block_dialog.gd",
	"res://addons/eventsheet/editor/dock/sheet_type_dialog.gd",
	"res://addons/eventsheet/editor/dock/grid_csv_dialog.gd",
	"res://addons/eventsheet/editor/dock/moment_file_door.gd",
	"res://addons/eventsheet/editor/dock/refactor_menu.gd",
	"res://addons/eventsheet/editor/dock/compare_dialog.gd",
	"res://addons/eventsheet/editor/event_sheet_shortcuts_dialog.gd",
	"res://addons/eventsheet/editor/behavior_preview.gd",
	"res://addons/eventsheet/editor/words_settings_dialog.gd",
	"res://addons/eventsheet/editor/inspector_designer_dialog.gd",
	"res://addons/eventsheet/editor/theme_editor_dialog.gd",
	"res://addons/eventsheet/mcp/mcp_server.gd",
	# Read only when something asks: the Doctor's Files section for one sentence of a finding, the
	# translation scanner and the grid codec for a pseudo column or a project walk, the Inspector mock
	# for a hover, the Project bar (off unless the project asks for it) and the Hierarchy pane.
	"res://addons/eventforge/files_doctor.gd",
	"res://addons/eventsheet/editor/translation_scan.gd",
	"res://addons/eventsheet/editor/grid_csv.gd",
	"res://addons/eventsheet/editor/inspector_preview_card.gd",
	"res://addons/eventsheet/editor/project_bar.gd",
	"res://addons/eventsheet/editor/dock/object_hierarchy.gd",
]

## The ids a first-paint file spells out rather than reading off a file it must not compile, each
## beside the constant it copies: [file, its constant, the source file, the source's constant].
const SPELLED_OUT := [
	["res://addons/eventsheet/editor/event_sheet_viewport.gd", "PROJECT_BAR_DRAG_TYPE",
		"res://addons/eventsheet/editor/project_bar.gd", "DRAG_TYPE"],
	["res://addons/eventsheet/editor/event_sheet_viewport.gd", "HIERARCHY_CHILD_DRAG_TYPE",
		"res://addons/eventsheet/editor/dock/object_hierarchy.gd", "CHILD_DRAG_TYPE"],
	["res://addons/eventsheet/editor/interaction/scene_trust_findings.gd", "KIND_UNTRUSTED_SCENE",
		"res://addons/eventforge/files_doctor.gd", "CHECK_UNTRUSTED_SCENE"],
]

## The dock and the helpers the first paint builds.
const FIRST_PAINT_FILES := [
	DOCK_PATH,
	"res://addons/eventsheet/editor/dock/menu_bar.gd",
	"res://addons/eventsheet/editor/dock/context_menus.gd",
	"res://addons/eventsheet/editor/dock/sheet_io.gd",
	"res://addons/eventsheet/editor/dock/theme_manager.gd",
	"res://addons/eventsheet/editor/dock/sheet_type_glue.gd",
	"res://addons/eventsheet/editor/dock/properties_bar.gd",
	"res://addons/eventsheet/editor/dock/dock_ui_builder.gd",
	"res://addons/eventsheet/editor/dock/live_edit_bar.gd",
	"res://addons/eventsheet/editor/dock/provider_registry_glue.gd",
	"res://addons/eventsheet/editor/dock/code_panel_glue.gd",
	"res://addons/eventsheet/editor/dock/dock_input_dispatch.gd",
	"res://addons/eventsheet/editor/dock/find_results_bar.gd",
	"res://addons/eventsheet/editor/dock/editor_tool_bar.gd",
]

## The names none of those files may hold in code. The API keeps its DOT, as in the boot lint: the
## files print "EventSheets" in messages, and a call is what compiles.
const HEAVY_NAMES := [
	"EventSheets.", "SheetCompiler", "GDScriptImporter", "EventSheetProjectDoctor",
	"ACEPickerDialog", "ACEParamsDialog", "VariableDialog", "EventSheetDocWindow",
	"EventSheetDocExplain", "EventSheetMCPServer", "EventSheetDocChores", "EventSheetThemeEditor",
	"EventSheetSheetTypeDialog", "EventSheetWelcomeWindow", "EventSheetStarterTemplates",
	"EventSheetSaveStudio", "EventSheetTranslationStudio", "EventSheetProjectDoctorPanel",
]


static func run() -> bool:
	var all_passed: bool = true

	# 1. The static walk of the first open, read off the sources.
	var tool: Script = load(CLOSURE_TOOL)
	var graph: Dictionary = tool.build_graph("res://addons/", EDITOR_PATH)
	var closure: PackedStringArray = tool.reach(graph["edges"], EDITOR_PATH, "")
	for path: String in CLICK_ONLY:
		all_passed = _check("the first open does not compile %s" % path.get_file(),
			closure.has(path), false) and all_passed
	for pair: Array in SPELLED_OUT:
		var spelled: String = str(load(pair[0]).get_script_constant_map().get(pair[1], ""))
		all_passed = _check("%s spells %s" % [str(pair[0]).get_file(), pair[1]], spelled.is_empty(), false) and all_passed
		all_passed = _check("%s %s matches %s" % [str(pair[0]).get_file(), pair[1], str(pair[2]).get_file()],
			spelled, str(load(pair[2]).get_script_constant_map().get(pair[3], ""))) and all_passed
	# The dock's registration store is a leaf: it names nothing, so reaching it compiles nothing.
	all_passed = _check("the dock registry names no class",
		Array((graph["edges"] as Dictionary).get(DOCK_REGISTRY_PATH, PackedStringArray())), []) and all_passed
	all_passed = _check("and the public API no longer names the dock",
		(graph["edges"] as Dictionary).get("res://addons/eventsheet/api/eventsheets.gd", PackedStringArray()).has(DOCK_PATH),
		false) and all_passed

	# 2. No heavy name in the code of the files the first paint builds.
	for path: String in FIRST_PAINT_FILES:
		var code: String = _code_only(path)
		all_passed = _check("%s is readable" % path.get_file(), code.is_empty(), false) and all_passed
		for heavy: String in HEAVY_NAMES:
			all_passed = _check("%s never names %s in code" % [path.get_file(), heavy.trim_suffix(".")],
				_names(code, heavy), false) and all_passed

	# 3. Every path those files reach by name of a constant exists.
	var path_constant: RegEx = RegEx.create_from_string("(?m)^const [A-Z_]+_PATH := \"(res://[^\"]+)\"")
	for path: String in FIRST_PAINT_FILES + ["res://addons/eventsheet/editor/picker_warmup.gd"]:
		for found: RegExMatch in path_constant.search_all(FileAccess.get_file_as_string(path)):
			all_passed = _check("%s reaches an existing %s" % [path.get_file(), found.get_string(1).get_file()],
				ResourceLoader.exists(found.get_string(1)), true) and all_passed

	# 4. One store, read by the API and written by the workspace; a freed workspace takes its own.
	var registry: Script = load(DOCK_REGISTRY_PATH)
	var stand_in: Control = Control.new()
	registry.call("register_dock", stand_in)
	all_passed = _check("a dock announced on the store is the one the API answers for",
		EventSheets._dock_alive(), true) and all_passed
	var mine: Callable = stand_in.queue_redraw
	registry.call("register_palette_command", "Zz Workspace Probe", mine)
	registry.call("register_row_menu_item", "Zz Workspace Row", Callable(), mine.unbind(1))
	EventSheets.register_palette_command("Zz Extension Probe", func() -> void: pass)
	all_passed = _check("a command the workspace registers is listed by the API",
		_titles(EventSheets.palette_commands()).has("Zz Workspace Probe"), true) and all_passed
	all_passed = _check("and a row item it registers is offered through the API",
		_labels(EventSheets.row_menu_items_for(Resource.new())).has("Zz Workspace Row"), true) and all_passed
	var heard: Array = []
	EventSheets.on_sheet_opened(func(payload: Dictionary) -> void: heard.append(payload.get("path", "")))
	registry.call("notify_lifecycle", "opened", {"path": "res://zz_probe.gd"})
	all_passed = _check("a listener added through the API hears the workspace's open",
		heard, ["res://zz_probe.gd"]) and all_passed
	registry.call("forget", stand_in)
	all_passed = _check("a forgotten workspace is no longer announced", EventSheets._dock_alive(), false) and all_passed
	all_passed = _check("its palette command goes with it",
		_titles(EventSheets.palette_commands()).has("Zz Workspace Probe"), false) and all_passed
	all_passed = _check("and its row item",
		_labels(EventSheets.row_menu_items_for(Resource.new())).has("Zz Workspace Row"), false) and all_passed
	all_passed = _check("while an extension's command stays",
		_titles(EventSheets.palette_commands()).has("Zz Extension Probe"), true) and all_passed
	EventSheets.unregister_palette_command("Zz Extension Probe")
	stand_in.free()

	# 5. A delegate built on demand is built once, wired back, and connected.
	var editor: Control = load(EDITOR_PATH).new()
	var docs: Object = editor.get("_docs")
	all_passed = _check("the Manual window helper is built when asked", docs != null, true) and all_passed
	all_passed = _check("and asked again it is the same one", editor.get("_docs") == docs, true) and all_passed
	all_passed = _check("its back-reference is the dock", docs.get("_dock") == editor, true) and all_passed
	var compare: Object = editor.get("_compare")
	all_passed = _check("the Compare dialog's confirm still reaches the dock",
		compare.is_connected("compare_confirmed", Callable(editor, "_on_compare_confirmed")), true) and all_passed
	# Opening a sheet refreshes the vocabulary and the rail, and neither may build the picker to do it:
	# both once read the picker field to hand it the registry or ask whether it is open, and reading
	# that field builds the picker - which compiled it, the Doctor, the parameters dialog and the
	# public API into every first open in the real editor.
	editor.call("setup", EventSheetResource.new())
	editor.call("_refresh_ace_registry")
	editor.call("_refresh_anatomy_panel")
	all_passed = _check("opening a sheet does not build the picker", editor.get("_ace_picker_built"), false) and all_passed
	# Escape and a stray left-click on the dock both ask "is the picker open, then close it". Asked by
	# reading the field, that question builds the picker - a freeze on a cancel gesture.
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	editor.get("_input_dispatch").call("unhandled_key_input", escape)
	all_passed = _check("Escape does not build the picker", editor.get("_ace_picker_built"), false) and all_passed
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	editor.call("_gui_input", click)
	all_passed = _check("a click on the dock does not build the picker", editor.get("_ace_picker_built"),
		false) and all_passed
	# The plugin hands the workspace its debugger while building it; that hand-over keeps the debugger
	# for the parameters dialog instead of building the dialog to wire it.
	var dock_source: String = FileAccess.get_file_as_string(DOCK_PATH)
	var hand_over: String = dock_source.get_slice("func set_live_values_debugger(", 1).get_slice("\nfunc ", 0)
	all_passed = _check("the debugger hand-over is found", hand_over.is_empty(), false) and all_passed
	all_passed = _check("and it does not build the parameters dialog", hand_over.contains("_ace_params."), false) and all_passed
	all_passed = _check("opening a sheet does not build the parameters dialog", editor.get("_ace_params_built"),
		false) and all_passed
	var picker: Object = editor.get("_ace_picker")
	all_passed = _check("asking for the picker builds it", editor.get("_ace_picker_built"), true) and all_passed
	all_passed = _check("the picker's selection still reaches the dock",
		picker.is_connected("ace_selected", Callable(editor, "_on_ace_picker_selected")), true) and all_passed
	var params: Object = editor.get("_ace_params")
	all_passed = _check("the parameters dialog's confirm still reaches the dock",
		params.is_connected("params_confirmed", Callable(editor, "_on_ace_params_confirmed")), true) and all_passed
	var variable_dialog: Object = editor.get("_variable_dlg")
	all_passed = _check("the variable dialog's confirm still reaches the dock",
		variable_dialog.is_connected("variable_confirmed", Callable(editor, "_on_variable_dialog_confirmed")),
		true) and all_passed
	all_passed = _check("the workspace's own palette commands are listed while it lives",
		_titles(EventSheets.palette_commands()).has("Collapse All Regions"), true) and all_passed
	editor.free()
	all_passed = _check("and go with it", _titles(EventSheets.palette_commands()).has("Collapse All Regions"),
		false) and all_passed
	return all_passed


## Whether `code` holds `heavy` as a name: a bare word, or the API token with its dot.
static func _names(code: String, heavy: String) -> bool:
	if heavy.ends_with("."):
		return RegEx.create_from_string("(?<![\\w.])" + heavy.replace(".", "\\.")).search(code) != null
	return RegEx.create_from_string("(?<![\\w.])" + heavy + "\\b").search(code) != null


static func _titles(commands: Array[Dictionary]) -> Array:
	return commands.map(func(command: Dictionary) -> String: return str(command.get("title", "")))


static func _labels(items: Array[Dictionary]) -> Array:
	return items.map(func(item: Dictionary) -> String: return str(item.get("label", "")))


## The file's code with comment lines and trailing comments cut, and string literals blanked, so a
## class named in a message or a docstring does not read as a reference.
static func _code_only(path: String) -> String:
	var source: String = FileAccess.get_file_as_string(path)
	if source.is_empty():
		return ""
	var strip: RegEx = RegEx.create_from_string(load(CLOSURE_TOOL).STRIP_PATTERN)
	return strip.sub(source, "", true)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check(TEST_NAME, label, actual, expected)
