# Godot EventSheets - Godot-native workflow arc: entry points (attach/open from the
# places Godot devs already click), settings registration, and the debug/docs tier.
# Editor glue (EventSheetContextMenu) is never instantiated headless - the
# EditorDebuggerPlugin lesson; cores are tested here, glue by the editor smoke.
@tool
class_name GodotWorkflowTest
extends RefCounted


class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false


static func run() -> bool:
	var all_passed: bool = true

	# ── Attach Event Sheet (the "Attach Script" reflex): a single hand-editable .gd, no .tres ──
	for stale: String in ["user://boss_fight_sheet.gd", "user://boss_fight_sheet-2.gd",
			"user://boss_fight_sheet.tres", "user://boss_fight_sheet_generated.gd"]:
		if FileAccess.file_exists(stale):
			DirAccess.remove_absolute(stale)
	var node: Node2D = Node2D.new()
	node.name = "Boss Fight"
	var created: Dictionary = EventSheetWorkflow.create_sheet_for_node(node, "user://")
	# The attached sheet is a plain .gd (the default format), so it lifts back to an EventSheetResource.
	var created_sheet: EventSheetResource = GDScriptImporter.new().import_external(str(created.get("sheet_path")))
	all_passed = _check("attach creates a host-matched .gd sheet beside the scene",
		bool(created.get("ok")) and str(created.get("sheet_path")) == "user://boss_fight_sheet.gd"
		and created_sheet != null and created_sheet.host_class == "Node2D", true) and all_passed
	all_passed = _check("attach writes a single .gd (no .tres companion) and scripts the node",
		node.get_script() != null
		and not FileAccess.file_exists("user://boss_fight_sheet.tres"), true) and all_passed
	all_passed = _check("nodes that already have a script are refused",
		bool(EventSheetWorkflow.create_sheet_for_node(node, "user://").get("ok")), false) and all_passed
	var sibling_node: Node2D = Node2D.new()
	sibling_node.name = "Boss Fight"
	var suffixed: Dictionary = EventSheetWorkflow.create_sheet_for_node(sibling_node, "user://")
	all_passed = _check("name collisions suffix instead of overwriting",
		str(suffixed.get("sheet_path")), "user://boss_fight_sheet-2.gd") and all_passed

	# ── New Event Sheet (the FileSystem "Create New > Event Sheet" core) ──────────
	# write_sheet_file compiles a starter straight to a hand-editable .gd (the default sheet
	# format) in the chosen folder; the .gd IS the sheet, so it lifts back to an EventSheetResource.
	for stale_gd: String in ["user://event_sheet.gd", "user://event_sheet-2.gd", "user://loot_table.gd", "user://escape.gd", "user://player.gd"]:
		if FileAccess.file_exists(stale_gd):
			DirAccess.remove_absolute(stale_gd)
	var made: Dictionary = EventSheetWorkflow.write_sheet_file(EventSheetStarterTemplates.build_starter(0), "user://", "event_sheet")
	all_passed = _check("Create New writes a .gd sheet file that exists",
		bool(made.get("ok")) and FileAccess.file_exists(str(made.get("sheet_path"))), true) and all_passed
	all_passed = _check("Create New returns the .gd path (the default format, no .tres)",
		str(made.get("sheet_path")), "user://event_sheet.gd") and all_passed
	var made_sheet: EventSheetResource = GDScriptImporter.new().import_external(str(made.get("sheet_path")))
	all_passed = _check("the created .gd lifts back to a sheet that compiles",
		made_sheet != null and bool(SheetCompiler.compile(made_sheet, "").get("success")), true) and all_passed
	# event_sheet.gd now exists, so a same-named create must suffix.
	var made_again: Dictionary = EventSheetWorkflow.write_sheet_file(EventSheetStarterTemplates.build_starter(0), "user://", "event_sheet")
	all_passed = _check("a second Create New suffixes instead of overwriting",
		str(made_again.get("sheet_path")), "user://event_sheet-2.gd") and all_passed
	# Clear both so the empty-name fallback lands on the un-suffixed default.
	for reset_gd: String in ["user://event_sheet.gd", "user://event_sheet-2.gd"]:
		if FileAccess.file_exists(reset_gd):
			DirAccess.remove_absolute(reset_gd)
	var blank_named: Dictionary = EventSheetWorkflow.write_sheet_file(EventSheetResource.new(), "user://", "")
	all_passed = _check("a blank name falls back to event_sheet.gd",
		str(blank_named.get("sheet_path")), "user://event_sheet.gd") and all_passed
	var loot: Dictionary = EventSheetWorkflow.write_sheet_file(EventSheetStarterTemplates.build_starter(9), "user://", "Loot Table")
	var loot_sheet: EventSheetResource = GDScriptImporter.new().import_external(str(loot.get("sheet_path")))
	all_passed = _check("the given name snake_cases into the filename and keeps the starter's shape",
		str(loot.get("sheet_path")) == "user://loot_table.gd"
		and loot_sheet != null and loot_sheet.host_class == "Resource", true) and all_passed
	all_passed = _check("a null sheet is refused, never written",
		bool(EventSheetWorkflow.write_sheet_file(null, "user://", "x").get("ok")), false) and all_passed
	# The typed name is sanitized to a bare filename: "../escape" can't traverse out of the folder,
	# and "player.gd" doesn't become player.gd.gd.
	var traversal: Dictionary = EventSheetWorkflow.write_sheet_file(EventSheetResource.new(), "user://", "../escape")
	all_passed = _check("a name with ../ stays inside the chosen folder",
		str(traversal.get("sheet_path")), "user://escape.gd") and all_passed
	var double_ext: Dictionary = EventSheetWorkflow.write_sheet_file(EventSheetResource.new(), "user://", "player.gd")
	all_passed = _check("a .gd in the typed name is not doubled",
		str(double_ext.get("sheet_path")), "user://player.gd") and all_passed
	for cleanup_gd: String in ["user://event_sheet.gd", "user://event_sheet-2.gd", "user://loot_table.gd", "user://escape.gd", "user://player.gd"]:
		if FileAccess.file_exists(cleanup_gd):
			DirAccess.remove_absolute(cleanup_gd)

	# ── The starter dispatcher: the New menu and the Create-New dialog share one source ─
	all_passed = _check("build_starter maps ids to the right host + intent",
		EventSheetStarterTemplates.build_starter(1).host_class == "CharacterBody2D"
		and EventSheetStarterTemplates.build_starter(9).host_class == "Resource"
		and EventSheetStarterTemplates.build_starter(10).tool_mode
		and EventSheetStarterTemplates.build_starter(0).events.is_empty(), true) and all_passed

	# ── New Event Sheet dialog: confirm carries the folder, name and starter id ────
	var new_sheet_dialog: EventSheetNewSheetDialog = EventSheetNewSheetDialog.new()
	var new_sheet_host: Node = Node.new()
	new_sheet_dialog.init_dialog(new_sheet_host)
	new_sheet_dialog._directory = "res://scenes"
	new_sheet_dialog._name_edit.text = "My Sheet"
	new_sheet_dialog._start_option.select(0)  # Blank (id 0)
	var create_payload: Array = [null]
	new_sheet_dialog.create_requested.connect(func(dir: String, nm: String, sid: int) -> void:
		create_payload[0] = [dir, nm, sid])
	new_sheet_dialog._on_confirmed()
	all_passed = _check("the dialog emits the folder, raw name and starter id on confirm",
		create_payload[0] is Array
		and str((create_payload[0] as Array)[0]) == "res://scenes"
		and str((create_payload[0] as Array)[1]) == "My Sheet"
		and int((create_payload[0] as Array)[2]) == 0, true) and all_passed
	all_passed = _check("the starter dropdown offers the curated dock-free set",
		new_sheet_dialog._start_option.item_count, EventSheetStarterTemplates.create_new_starters().size()) and all_passed
	new_sheet_host.free()

	# ── Open as Event Sheet eligibility ───────────────────────────────────────────
	all_passed = _check("sheet .tres files are openable",
		EventSheetWorkflow.is_openable_as_sheet("res://demo/sheets/player.tres"), true) and all_passed
	all_passed = _check("non-sheet .tres files are not",
		EventSheetWorkflow.is_openable_as_sheet("res://demo/themes/dracula_theme.tres"), false) and all_passed
	all_passed = _check("any .gd opens (GDScript-backed sheets)",
		EventSheetWorkflow.is_openable_as_sheet("res://addons/eventforge/plugin.gd"), true) and all_passed
	all_passed = _check("other extensions are not sheets",
		EventSheetWorkflow.is_openable_as_sheet("res://icon.png"), false) and all_passed

	# ── Script → sheet pairing (the Inspector button + Go to Sheet Row backbone) ──
	# The .tres-companion case (a .tres sheet compiles to a <name>_generated.gd whose header points
	# back) still exists for .tres-authored sheets; build one explicitly so the pairing is tested
	# independently of how Attach Event Sheet writes its file (a plain .gd, tested above).
	for stale_paired: String in ["user://paired.tres", "user://paired_generated.gd"]:
		if FileAccess.file_exists(stale_paired):
			DirAccess.remove_absolute(stale_paired)
	var paired_sheet: EventSheetResource = EventSheetResource.new()
	paired_sheet.host_class = "Node2D"
	ResourceSaver.save(paired_sheet, "user://paired.tres")
	var paired_loaded: EventSheetResource = ResourceLoader.load("user://paired.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	paired_loaded.take_over_path("user://paired.tres")
	SheetCompiler.compile(paired_loaded, "")
	var paired_gd: String = SheetCompiler._resolve_output_path(paired_loaded, "")
	all_passed = _check("the Source header pairs generated scripts to their sheet",
		EventSheetProjectDoctor.sheet_for_script(paired_gd), "user://paired.tres") and all_passed
	all_passed = _check("a behaviour pack .gd pairs to itself (the .gd IS the sheet, no .tres)",
		EventSheetProjectDoctor.sheet_for_script("res://eventsheet_addons/spring/spring_behavior.gd"),
		"res://eventsheet_addons/spring/spring_behavior.gd") and all_passed
	all_passed = _check("hand-written scripts pair to nothing",
		EventSheetProjectDoctor.sheet_for_script("res://addons/eventforge/plugin.gd"), "") and all_passed
	# The generated script extends the host_class (Node2D here), so 4.7's stricter
	# set_script requires a matching base type - a plain Node would be rejected.
	var scripted: Node = Node2D.new()
	scripted.set_script(load(paired_gd))
	var plain: Node = Node.new()
	all_passed = _check("the Inspector button handles sheet-scripted nodes only",
		EventSheetEditButtonPlugin.sheet_path_for(scripted) == "user://paired.tres"
		and EventSheetEditButtonPlugin.sheet_path_for(plain) == "", true) and all_passed
	scripted.free()
	plain.free()
	node.free()
	sibling_node.free()
	for cleanup: String in ["user://boss_fight_sheet.gd", "user://boss_fight_sheet-2.gd",
			"user://paired.tres", paired_gd]:
		if FileAccess.file_exists(cleanup):
			DirAccess.remove_absolute(cleanup)

	# ── Settings registration: discoverable, value-neutral ────────────────────────
	EventSheetSettings.register_all()
	all_passed = _check("settings register with their in-code defaults",
		ProjectSettings.has_setting("eventsheets/editor/compile_on_save")
		and bool(ProjectSettings.get_setting("eventsheets/editor/compile_on_save")) == true
		and int(ProjectSettings.get_setting("eventsheets/editor/backup_count")) == 10
		and str(ProjectSettings.get_setting("eventsheets/addons/composition_mode")) == "allowed", true) and all_passed
	ProjectSettings.set_setting("eventsheets/editor/backup_count", 3)
	EventSheetSettings.register_all()
	all_passed = _check("re-registering never clobbers a changed value",
		int(ProjectSettings.get_setting("eventsheets/editor/backup_count")), 3) and all_passed
	ProjectSettings.set_setting("eventsheets/editor/backup_count", null)

	# ── Rebindable shortcuts: exact modifier matching, Project Settings overrides ─
	var parsed: Dictionary = EventSheetShortcuts.parse("Ctrl+Shift+S")
	all_passed = _check("bindings parse modifiers + key",
		int(parsed.get("keycode")) == KEY_S and bool(parsed.get("ctrl")) and bool(parsed.get("shift")), true) and all_passed
	var combo: InputEventKey = InputEventKey.new()
	combo.keycode = KEY_D
	combo.ctrl_pressed = true
	all_passed = _check("default bindings match their combo",
		EventSheetShortcuts.matches(combo, "duplicate") and not EventSheetShortcuts.matches(combo, "copy"), true) and all_passed
	var chord: InputEventKey = InputEventKey.new()
	chord.keycode = KEY_C
	chord.ctrl_pressed = true
	chord.shift_pressed = true
	all_passed = _check("chords never shadow their plain form",
		EventSheetShortcuts.matches(chord, "add_condition_chord") and not EventSheetShortcuts.matches(chord, "copy"), true) and all_passed
	EventSheetShortcuts.set_binding("duplicate", "Alt+D")
	var rebound: InputEventKey = InputEventKey.new()
	rebound.keycode = KEY_D
	rebound.alt_pressed = true
	all_passed = _check("custom rebinds win over defaults",
		EventSheetShortcuts.matches(rebound, "duplicate") and not EventSheetShortcuts.matches(combo, "duplicate"), true) and all_passed
	all_passed = _check("format_event round-trips a captured chord",
		EventSheetShortcuts.format_event(rebound), "Alt+D") and all_passed
	all_passed = _check("conflicting_action flags a clash with another action's binding",
		EventSheetShortcuts.conflicting_action("copy", "Alt+D"), "duplicate") and all_passed
	EventSheetShortcuts.reset("duplicate")
	all_passed = _check("reset restores the default binding",
		EventSheetShortcuts.binding_for("duplicate"), "Ctrl+D") and all_passed

	# ── The Construct-parity key grammar: the defaults ARE C3's event-sheet keys ─
	for c3_pair: Array in [["add_event", "E"], ["add_condition", "C"], ["add_action", "A"],
			["add_comment", "Q"], ["add_group", "G"], ["toggle_enabled", "D"],
			["add_blank_subevent", "B"], ["add_sub_condition", "S"], ["add_variable", "V"],
			["invert_condition", "I"], ["replace_ace", "R"]]:
		all_passed = _check("C3 key parity: %s is %s" % [str(c3_pair[0]), str(c3_pair[1])],
			str(EventSheetShortcuts.DEFAULTS.get(str(c3_pair[0]), "")), str(c3_pair[1])) and all_passed
	var bare_s: InputEventKey = InputEventKey.new()
	bare_s.keycode = KEY_S
	all_passed = _check("bare S routes to add-sub-event, not Save",
		EventSheetShortcuts.matches(bare_s, "add_sub_condition") and not EventSheetShortcuts.matches(bare_s, "save"), true) and all_passed

	# ── Go to Sheet Row + docs links ──────────────────────────────────────────────
	all_passed = _check("class docs resolve to the engine help topic",
		ACEParamsDialog.open_class_docs("CharacterBody2D"), "class_name:CharacterBody2D") and all_passed
	var goto_editor: EventSheetEditor = EventSheetEditor.new()
	var goto_sheet: EventSheetResource = EventSheetResource.new()
	goto_sheet.host_class = "Node"
	var goto_event: EventRow = EventRow.new()
	goto_event.trigger_provider_id = "Core"
	goto_event.trigger_id = "OnProcess"
	var goto_raw: RawCodeRow = RawCodeRow.new()
	goto_raw.code = "print(\"tick\")"
	goto_event.actions.append(goto_raw)
	goto_sheet.events.append(goto_event)
	goto_editor.setup(goto_sheet)
	goto_editor.set_undo_redo_manager(NoopUndoManager.new())
	var preview: Dictionary = SheetCompiler.compile(goto_sheet, "user://goto_probe.gd")
	var event_line: int = 0
	for entry: Variant in (preview.get("source_map", []) as Array):
		if entry is Dictionary and str((entry as Dictionary).get("kind")) == "event":
			event_line = int((entry as Dictionary).get("start", 0))
			break
	goto_editor.goto_generated_line(event_line)
	all_passed = _check("goto_generated_line opens the panel and selects the emitting row",
		goto_editor.is_code_panel_visible()
		and goto_editor._viewport.get_selected_row_data() != null
		and goto_editor._viewport.get_selected_row_data().source_resource == goto_event, true) and all_passed
	goto_editor.free()
	DirAccess.remove_absolute("user://goto_probe.gd")

	# ── The welcome panel's Godot-native default: code panel rides every sheet ────
	ProjectSettings.set_setting("eventsheets/editor/open_code_panel_by_default", true)
	var native_editor: EventSheetEditor = EventSheetEditor.new()
	var native_sheet: EventSheetResource = EventSheetResource.new()
	native_sheet.host_class = "Node"
	native_editor.setup(native_sheet)
	native_editor.set_undo_redo_manager(NoopUndoManager.new())
	all_passed = _check("Godot-native default opens the GDScript panel with the sheet",
		native_editor.is_code_panel_visible(), true) and all_passed
	ProjectSettings.set_setting("eventsheets/editor/open_code_panel_by_default", null)
	native_editor.free()
	var plain_editor: EventSheetEditor = EventSheetEditor.new()
	plain_editor.setup(EventSheetResource.new())
	plain_editor.set_undo_redo_manager(NoopUndoManager.new())
	all_passed = _check("the default stays off without the setting",
		plain_editor.is_code_panel_visible(), false) and all_passed
	plain_editor.free()

	# ── GDScript-coverage arc: if/elif/else reverse-lift (sub-events + else chains)
	# round-trips through the compiler and back ────────────────────────────────────
	var rt_sheet: EventSheetResource = EventSheetResource.new()
	rt_sheet.host_class = "CharacterBody2D"
	var rt_event: EventRow = EventRow.new()
	rt_event.trigger_provider_id = "Core"
	rt_event.trigger_id = "OnPhysicsProcess"
	var grounded: ACECondition = ACECondition.new()
	grounded.provider_id = "Core"
	grounded.ace_id = "IsOnFloor"
	grounded.codegen_template = "is_on_floor()"
	rt_event.conditions.append(grounded)
	var run_raw: RawCodeRow = RawCodeRow.new()
	run_raw.code = "velocity.x = 100.0"
	rt_event.actions.append(run_raw)
	var jump_sub: EventRow = EventRow.new()
	var pressed: ACECondition = ACECondition.new()
	pressed.provider_id = "Core"
	pressed.ace_id = "IsActionJustPressed"
	pressed.codegen_template = "Input.is_action_just_pressed(&{action})"
	pressed.params = {"action": "\"ui_accept\""}
	jump_sub.conditions.append(pressed)
	var jump_raw: RawCodeRow = RawCodeRow.new()
	jump_raw.code = "velocity.y = -300.0"
	jump_sub.actions.append(jump_raw)
	rt_event.sub_events.append(jump_sub)
	var settle_sub: EventRow = EventRow.new()
	settle_sub.else_mode = EventRow.ElseMode.ELSE
	var settle_raw: RawCodeRow = RawCodeRow.new()
	settle_raw.code = "velocity.y = 0.0"
	settle_sub.actions.append(settle_raw)
	rt_event.sub_events.append(settle_sub)
	rt_sheet.events.append(rt_event)
	var airborne_event: EventRow = EventRow.new()
	airborne_event.trigger_provider_id = "Core"
	airborne_event.trigger_id = "OnPhysicsProcess"
	airborne_event.else_mode = EventRow.ElseMode.ELSE
	var spin_raw: RawCodeRow = RawCodeRow.new()
	spin_raw.code = "rotation = 0.0"
	airborne_event.actions.append(spin_raw)
	rt_sheet.events.append(airborne_event)
	var rt_compile: Dictionary = SheetCompiler.compile(rt_sheet, "user://lift_roundtrip.gd")
	all_passed = _check("the branching fixture compiles", bool(rt_compile.get("success")), true) and all_passed
	var lifted: EventSheetResource = GDScriptImporter.new().import_external("user://lift_roundtrip.gd")
	var lifted_events: Array = []
	for row: Variant in lifted.events:
		if row is EventRow:
			lifted_events.append(row)
	all_passed = _check("both chained events lift back",
		lifted_events.size() == 2
		and (lifted_events[1] as EventRow).else_mode == EventRow.ElseMode.ELSE, true) and all_passed
	var lifted_first: EventRow = lifted_events[0] as EventRow
	all_passed = _check("conditions reverse-match through the chain",
		lifted_first.conditions.size() == 1 and (lifted_first.conditions[0] as ACECondition).ace_id == "IsOnFloor", true) and all_passed
	all_passed = _check("nested if/else lifts into sub-events with else_mode",
		lifted_first.sub_events.size() == 2
		and (lifted_first.sub_events[0] as EventRow).conditions.size() == 1
		and ((lifted_first.sub_events[0] as EventRow).conditions[0] as ACECondition).ace_id == "IsActionJustPressed"
		and (lifted_first.sub_events[1] as EventRow).else_mode == EventRow.ElseMode.ELSE, true) and all_passed
	var rt_back: Dictionary = SheetCompiler.compile(lifted, "user://lift_roundtrip_back.gd")
	all_passed = _check("the lifted structure reproduces the source byte-for-byte",
		str(rt_back.get("output")), FileAccess.get_file_as_string("user://lift_roundtrip.gd")) and all_passed

	# ── The lift report: the boundary explains itself ─────────────────────────────
	all_passed = _check("await blocks point at Wait",
		EventSheetLiftReport.reason_for("func wait_a_bit() -> void:\n\tawait get_tree().create_timer(1.0).timeout").contains("Wait"), true) and all_passed
	all_passed = _check("while loops point at the loop ACEs",
		EventSheetLiftReport.reason_for("func spin() -> void:\n\twhile true:\n\t\tpass").contains("while loop"), true) and all_passed
	all_passed = _check("match blocks point at Add Match",
		EventSheetLiftReport.reason_for("func route(x) -> void:\n\tmatch x:\n\t\t_: pass").contains("match"), true) and all_passed
	all_passed = _check("preludes are explained as declarations",
		EventSheetLiftReport.reason_for("extends Node\n\nvar hp: int = 3").contains("prelude"), true) and all_passed
	var report: Array[Dictionary] = EventSheetLiftReport.for_sheet(lifted)
	var event_entries: int = 0
	for entry: Dictionary in report:
		if str(entry.get("kind")) == "event":
			event_entries += 1
	all_passed = _check("the report covers lifted events and the summary counts them",
		event_entries == 2 and EventSheetLiftReport.summary(report).contains("2 event(s)"), true) and all_passed
	DirAccess.remove_absolute("user://lift_roundtrip.gd")
	DirAccess.remove_absolute("user://lift_roundtrip_back.gd")

	# ── Sweep regression: the export-integrity pass skips template blueprints ─────
	ProjectSettings.set_setting("eventsheets/project/templates_dir", "res://demo/sheets")
	var filtered: Dictionary = EventSheetExportIntegrityPlugin.recompile_all_sheets("res://demo/sheets")
	all_passed = _check("export pass never compiles template sheets",
		int(filtered.get("compiled", -1)), 0) and all_passed
	ProjectSettings.set_setting("eventsheets/project/templates_dir", null)
	var unfiltered: Dictionary = EventSheetExportIntegrityPlugin.recompile_all_sheets("res://demo/sheets")
	all_passed = _check("non-template sheets still recompile at export",
		int(unfiltered.get("compiled", 0)) >= 1, true) and all_passed

	# ── Review fixes: Run Scene targets the .gd itself for GDScript-backed sheets;
	# the welcome panel discovers the newest showcase instead of hardcoding it ─────
	var run_target_file: FileAccess = FileAccess.open("user://run_target.gd", FileAccess.WRITE)
	run_target_file.store_string("extends Node\n\n\nfunc _ready() -> void:\n\tpass\n")
	run_target_file.close()
	var external_sheet: EventSheetResource = GDScriptImporter.new().import_external("user://run_target.gd")
	var run_editor_2: EventSheetEditor = EventSheetEditor.new()
	run_editor_2.setup(external_sheet)
	run_editor_2.set_undo_redo_manager(NoopUndoManager.new())
	run_editor_2._current_sheet_path = "user://run_target.gd"
	all_passed = _check("Run Scene targets the source .gd for GDScript-backed sheets",
		run_editor_2._run_target_script_path(), "user://run_target.gd") and all_passed
	run_editor_2.free()
	DirAccess.remove_absolute("user://run_target.gd")
	all_passed = _check("the welcome panel discovers the newest showcase scene",
		EventForgePlugin._find_showcase_scene(), "res://demo/showcase/carousel/showcase_carousel.tscn") and all_passed

	# ── Toolbar redesign: grouped menus, flow-wraps instead of clipping ───────────
	var toolbar_editor: EventSheetEditor = EventSheetEditor.new()
	toolbar_editor.setup(EventSheetResource.new())
	toolbar_editor.set_undo_redo_manager(NoopUndoManager.new())
	all_passed = _check("the toolbar wraps instead of clipping",
		toolbar_editor._toolbar is HFlowContainer, true) and all_passed
	all_passed = _check("grouping leaves a short toolbar",
		toolbar_editor._toolbar.get_child_count() <= 17, true) and all_passed  # +1: the Simple Mode pill
	var sheet_menu: MenuButton = toolbar_editor._toolbar.find_child("EventSheetSheetMenu", true, false) as MenuButton
	var add_menu: MenuButton = toolbar_editor._toolbar.find_child("EventSheetAddMenu", true, false) as MenuButton
	var edit_menu: MenuButton = toolbar_editor._toolbar.find_child("EventSheetEditMenu", true, false) as MenuButton
	var view_menu: MenuButton = toolbar_editor._toolbar.find_child("EventSheetViewMenu", true, false) as MenuButton
	all_passed = _check("Sheet/Add/Edit/View menus carry the consolidated actions",
		sheet_menu != null and sheet_menu.get_popup().item_count == 16  # +New Behaviour Addon…, +Teach a Verb, +Inspector Designer, +New Editor Tool…, +New Custom Resource…
		and add_menu != null and add_menu.get_popup().item_count == 6 + 1 + EventSheetBlockRegistry.addable_kinds().size()  # +separator +Code action, then +separator + one item per registered Custom Block kind
		and edit_menu != null and edit_menu.get_popup().item_count == 10
		and view_menu != null and view_menu.get_popup().item_count == 22, true) and all_passed  # +1: Open Sheets Panel, +1: Language submenu, +1: Object Icons toggle, +1: Event Numbers toggle, +1: Outline

	# ── Welcome window: self-sizing dialog, margined, reopenable, checkbox synced ─
	# The window now lives in the extracted EventSheetWelcomeWindow (dock/welcome_window.gd); the dock
	# keeps thin show_welcome / show_welcome_if_first_run delegates. Build via the helper directly.
	toolbar_editor._welcome._build()
	all_passed = _check("welcome self-sizes to its content (AcceptDialog)",
		toolbar_editor._welcome._welcome_window is AcceptDialog, true) and all_passed
	# The body is wrapped in the shared EventSheetPopupUI.margined() helper now (a MarginContainer
	# child of the dialog) rather than a hand-named "WelcomeMargin" - assert real margins remain.
	var welcome_margin: MarginContainer = null
	for child: Node in toolbar_editor._welcome._welcome_window.get_children():
		if child is MarginContainer:
			welcome_margin = child as MarginContainer
			break
	all_passed = _check("welcome content sits inside real margins",
		welcome_margin != null and welcome_margin.get_theme_constant("margin_left") >= 8, true) and all_passed
	all_passed = _check("welcome exposes the native-default checkbox for reopen sync",
		toolbar_editor._welcome._welcome_window.get_meta("native_check") is CheckBox, true) and all_passed
	toolbar_editor.free()

	# ── Merged block cells: GDScript + action comments group their lines so the
	# renderer paints ONE cell (per-line spans stay the layout/hit-test truth) ─────
	var block_sheet: EventSheetResource = EventSheetResource.new()
	block_sheet.host_class = "Node"
	var block_event: EventRow = EventRow.new()
	block_event.trigger_provider_id = "Core"
	block_event.trigger_id = "OnProcess"
	var block_raw: RawCodeRow = RawCodeRow.new()
	block_raw.code = "var a := 1\nvar b := 2\nprint(a + b)"
	block_event.actions.append(block_raw)
	var block_comment: CommentRow = CommentRow.new()
	block_comment.text = "first line\nsecond line"
	block_event.actions.append(block_comment)
	block_sheet.events.append(block_event)
	var block_viewport: EventSheetViewport = EventSheetViewport.new()
	block_viewport.set_sheet(block_sheet)
	var block_row: EventRowData = null
	for flat_entry: Dictionary in block_viewport.get_flat_rows():
		var candidate: EventRowData = flat_entry.get("row")
		if candidate != null and candidate.source_resource == block_event:
			block_row = candidate
	block_viewport._ensure_event_spans(block_row)
	var code_lines: int = 0
	var comment_lines: int = 0
	var comment_has_chip_chrome: bool = false
	for span: SemanticSpan in block_row.spans:
		if span == null or not (span.metadata is Dictionary):
			continue
		var span_meta: Dictionary = span.metadata
		if bool(span_meta.get("code_cell", false)) and int(span_meta.get("block_lines", 0)) == 3:
			code_lines += 1
		if bool(span_meta.get("action_comment", false)) and int(span_meta.get("block_lines", 0)) == 2:
			comment_lines += 1
			comment_has_chip_chrome = comment_has_chip_chrome or span_meta.has("chip_bg") or bool(span_meta.get("chip", false))
	all_passed = _check("GDScript lines group into one code cell",
		code_lines, 3) and all_passed
	all_passed = _check("action comments group and carry the action-cell chrome",
		comment_lines == 2 and comment_has_chip_chrome, true) and all_passed
	block_viewport.free()

	# ── Vector params split into per-axis fields (single-param ACEs only) ─────────
	all_passed = _check("vector literals split on top-level commas",
		ACEParamsDialog.vector_literal_parts("Vector2(maxf(0, 1), speed * 2)"),
		PackedStringArray(["maxf(0, 1)", "speed * 2"])) and all_passed
	all_passed = _check("vector3 literals split into three axes",
		ACEParamsDialog.vector_literal_parts("Vector3(1, 2, 3)").size(), 3) and all_passed
	all_passed = _check("non-vector values never split",
		ACEParamsDialog.vector_literal_parts("position + Vector2(1, 2)").is_empty(), true) and all_passed
	var vector_dialog: ACEParamsDialog = ACEParamsDialog.new()
	var vector_host: Node = Node.new()
	vector_dialog.init_dialog(vector_host)
	vector_dialog._single_param_form = true
	var vector_field: Control = vector_dialog._create_field({"id": "pos", "default_value": "Vector2(4, 8)"}, {}, "pos", "")
	all_passed = _check("a lone vector param becomes per-axis fields that recompose",
		vector_field.has_meta("vector_axis_edits")
		and str(vector_dialog._extract_value(vector_field)) == "Vector2(4, 8)", true) and all_passed
	vector_host.free()

	# ── Variable dialog: progressive disclosure + enum→combo fill ─────────────────
	var variable_dialog: VariableDialog = VariableDialog.new()
	var variable_host: Node = Node.new()
	variable_dialog.init_dialog(variable_host)
	variable_dialog.set_enum_provider(func() -> Array:
		return [{"name": "State", "members": PackedStringArray(["IDLE", "RUN", "HURT = 4"])}])
	variable_dialog.open_for_edit("global", {}, "speed", "float", "1.0", false, "Edit Variable", false, true)
	all_passed = _check("inspector options start collapsed for plain variables",
		variable_dialog._attr_section_card.visible, false) and all_passed
	all_passed = _check("combo options hide for non-String types",
		variable_dialog._options_row.visible, false) and all_passed
	variable_dialog.open_for_edit("global", {"attributes": {"group": "Combat"}}, "title", "String", "\"x\"", false, "Edit Variable", false, true)
	all_passed = _check("existing (advanced) attributes auto-expand the section",
		variable_dialog._attr_section_card.visible and variable_dialog._options_row.visible, true) and all_passed
	# Description (the promoted tooltip field) is always visible now, so a description-only variable
	# must NOT unfurl More options - only genuinely-advanced attributes do.
	variable_dialog.open_for_edit("global", {"attributes": {"tooltip": "hi"}}, "note", "String", "\"x\"", false, "Edit Variable", false, true)
	all_passed = _check("a description-only variable keeps More options collapsed",
		variable_dialog._attr_section_card.visible, false) and all_passed
	variable_dialog._populate_enum_fill_menu()
	var enum_popup: PopupMenu = variable_dialog._enum_fill_menu.get_popup()
	all_passed = _check("sheet enums fill the combo with member names (values stripped)",
		enum_popup.item_count == 1 and str(enum_popup.get_item_metadata(0)) == "IDLE, RUN, HURT", true) and all_passed
	variable_host.free()

	# ── Function dialog: expanding params, auto-unique names, duplicate guard ─────
	var function_dialog: EventSheetFunctionDialog = EventSheetFunctionDialog.new()
	var function_host: Node = Node.new()
	function_dialog.init_dialog(function_host)
	function_dialog.set_taken_names_provider(func() -> PackedStringArray:
		return PackedStringArray(["existing_fn"]))
	function_dialog.open()
	function_dialog.add_param_row()
	function_dialog.add_param_row()
	all_passed = _check("param rows auto-suggest unique names",
		function_dialog.collect_params().size() == 2
		and str(function_dialog.collect_params()[1].get("id")) == "param_2", true) and all_passed
	function_dialog._name_edit.text = "Deal Damage"
	var built: Dictionary = function_dialog.build_function_data()
	all_passed = _check("function names auto-snake_case and params carry types",
		str(built.get("name")) == "deal_damage"
		and (built.get("params") as Array).size() == 2
		and str(built.get("problem")).is_empty(), true) and all_passed
	function_dialog._name_edit.text = "existing_fn"
	all_passed = _check("duplicate names are refused with the reason named",
		str(function_dialog.build_function_data().get("problem")).contains("already exists"), true) and all_passed
	# Dock apply: the validated data becomes a real EventFunction on the sheet.
	var function_editor: EventSheetEditor = EventSheetEditor.new()
	var function_sheet: EventSheetResource = EventSheetResource.new()
	function_sheet.host_class = "Node"
	function_editor.setup(function_sheet)
	function_editor.set_undo_redo_manager(NoopUndoManager.new())
	function_editor._apply_function_data({"name": "boost", "return_type": TYPE_NIL,
		"params": [{"id": "amount", "type_name": "float"}], "expose": true,
		"ace_display_name": "Boost", "ace_category": "Combat"})
	var created_function: EventFunction = function_sheet.functions[0] as EventFunction
	all_passed = _check("dock apply creates the sheet function",
		created_function.function_name == "boost" and created_function.expose_as_ace
		and created_function.params.size() == 1 and (created_function.params[0] as ACEParam).id == "amount", true) and all_passed
	function_editor.free()
	function_host.free()

	# ── Field-test regressions: picker preselect must REVEAL (expand ancestors);
	# a broken lint context must never lock the params dialog's OK ─────────────────
	var pre_editor: EventSheetEditor = EventSheetEditor.new()
	var pre_sheet: EventSheetResource = EventSheetResource.new()
	pre_sheet.host_class = "CharacterBody2D"
	var pre_event: EventRow = EventRow.new()
	pre_event.trigger_provider_id = "Core"
	pre_event.trigger_id = "OnProcess"
	var pre_cond: ACECondition = ACECondition.new()
	pre_cond.provider_id = "Core"
	pre_cond.ace_id = "IsOnFloor"
	pre_cond.codegen_template = "is_on_floor()"
	pre_event.conditions.append(pre_cond)
	pre_sheet.events.append(pre_event)
	pre_editor.setup(pre_sheet)
	pre_editor.set_undo_redo_manager(NoopUndoManager.new())
	pre_editor._ace_picker.init_dialog(pre_editor, pre_editor._ace_registry)
	pre_editor._refresh_ace_registry()
	pre_editor._ace_picker._context = {"mode": "replace_condition", "signals_only": false, "selected_resource": pre_event}
	pre_editor._ace_picker._refresh_tree()
	# Collapse every group: selection inside a collapsed group is what read as
	# "not preselecting" in the field test.
	var group_item: TreeItem = pre_editor._ace_picker._tree.get_root().get_first_child()
	while group_item != null:
		group_item.collapsed = true
		group_item = group_item.get_next()
	pre_editor._ace_picker.preselect("IsOnFloor")
	var preselected: TreeItem = pre_editor._ace_picker._tree.get_selected()
	all_passed = _check("preselect reveals the entry (selected + ancestors expanded)",
		preselected != null and preselected.get_text(0) == "Is On Floor"
		and not preselected.get_parent().collapsed, true) and all_passed

	# Broken lint context: a sheet variable shadowing a host member breaks the
	# scratch script, so EVERY expression "fails" - OK must still commit.
	var broken_sheet: EventSheetResource = EventSheetResource.new()
	broken_sheet.host_class = "CharacterBody2D"
	broken_sheet.variables = {"velocity": {"type": "float", "default": 0.0, "exported": true}}
	all_passed = _check("the shadowed-member sheet really breaks the lint baseline",
		bool(EventSheetGDScriptLint.lint_expression("0", broken_sheet).get("ok", true)), false) and all_passed
	var guard_dialog: ACEParamsDialog = ACEParamsDialog.new()
	var guard_host: Node = Node.new()
	guard_dialog.init_dialog(guard_host)
	guard_dialog.set_lint_context_provider(func() -> EventSheetResource: return broken_sheet)
	var guard_definition: ACEDefinition = ACEDefinition.new()
	guard_definition.id = "GuardProbe"
	guard_definition.parameters = [{"id": "value", "display_name": "Value", "hint": "expression", "default_value": "1.0"}]
	guard_dialog._definition = guard_definition
	guard_dialog._context = {"mode": "append_action"}
	guard_dialog._build_form(guard_definition, {})
	var guard_fired: Array = [false]
	guard_dialog.params_confirmed.connect(func(_d, _v, _c) -> void: guard_fired[0] = true)
	guard_dialog._on_confirmed()
	all_passed = _check("a broken lint context never locks the OK button",
		guard_fired[0], true) and all_passed
	guard_host.free()
	pre_editor.free()

	# ── Review fix: clicking any line of a multi-line block resolves to the block
	# head + full union (selection/hover drew nothing when a non-head line was clicked).
	var s0: SemanticSpan = SemanticSpan.new()
	s0.rect = Rect2(0, 0, 100, 10)
	s0.metadata = {"chip": true, "code_cell": true, "block_lines": 3, "block_line": 0}
	var s1: SemanticSpan = SemanticSpan.new()
	s1.rect = Rect2(0, 10, 100, 10)
	s1.metadata = {"chip": true, "code_cell": true, "block_lines": 3, "block_line": 1}
	var s2: SemanticSpan = SemanticSpan.new()
	s2.rect = Rect2(0, 20, 100, 10)
	s2.metadata = {"chip": true, "code_cell": true, "block_lines": 3, "block_line": 2}
	var groups: Dictionary = EventRowRenderer.resolve_block_groups([s0, s1, s2])
	all_passed = _check("clicking the last block line resolves to the head",
		int((groups["heads"] as Dictionary).get(2, -1)), 0) and all_passed
	all_passed = _check("the block union covers every member line",
		(groups["unions"] as Dictionary).get(2), Rect2(0, 0, 100, 30)) and all_passed

	# ── Review fix: a numeric-only attribute left over after switching type is inert
	# (it's hidden), not a can't-fix error about an invisible field.
	var leftover_dialog: VariableDialog = VariableDialog.new()
	var leftover_host: Node = Node.new()
	leftover_dialog.init_dialog(leftover_host)
	leftover_dialog.open_for_edit("global", {}, "label", "float", "1.0", false, "Edit Variable", false, true)
	leftover_dialog._attr_range_edit.text = "0, 100, 1"
	leftover_dialog._attr_clamp_check.button_pressed = true
	# "Text" is the friendly dropdown label that stores the String type (Number/Text/Yes-No aliases).
	leftover_dialog._select_stored_type("String")
	leftover_dialog._refresh_contextual_rows()
	leftover_dialog._default_edit.text = "\"hi\""
	var captured_attrs: Array = [null]
	leftover_dialog.variable_confirmed.connect(func(_n, _t, _d, _s, _c, _ic, _ex, _co, attrs, _r) -> void: captured_attrs[0] = attrs)
	leftover_dialog._on_confirmed()
	all_passed = _check("leftover numeric attributes are inert after switching type",
		captured_attrs[0] is Dictionary and not (captured_attrs[0] as Dictionary).has("range")
		and not (captured_attrs[0] as Dictionary).has("clamp"), true) and all_passed
	leftover_host.free()

	# ── Native polish: the GDScript panel reads like the script editor ────────────
	var code_editor: EventSheetEditor = EventSheetEditor.new()
	code_editor.setup(EventSheetResource.new())
	code_editor.set_undo_redo_manager(NoopUndoManager.new())
	var probe_code_edit: CodeEdit = CodeEdit.new()
	code_editor._apply_editor_code_settings(probe_code_edit)
	all_passed = _check("the code panel adopts script-editor chrome (minimap, current line)",
		probe_code_edit.minimap_draw and probe_code_edit.highlight_current_line, true) and all_passed
	probe_code_edit.free()
	code_editor.free()

	# ── Context menu truncation: rebuilt per row type, short, type-specific ───────
	var menu_editor: EventSheetEditor = EventSheetEditor.new()
	menu_editor.setup(EventSheetResource.new())
	menu_editor.set_undo_redo_manager(NoopUndoManager.new())
	var event_row: EventRowData = EventRowData.new()
	event_row.row_type = EventRowData.RowType.EVENT
	menu_editor._context_row = event_row
	menu_editor._build_row_context_menu(event_row)
	var event_labels: PackedStringArray = _menu_labels(menu_editor._row_context_menu)
	all_passed = _check("event menu is short and type-specific",
		event_labels.size() <= 13  # +1: Cut joined Copy/Paste (C3 parity)
		and event_labels.has("Add Sub-Event") and event_labels.has("Convert to OR Block")
		and event_labels.has("Cut")
		and event_labels.has("Insert") and event_labels.has("More") and event_labels.has("Delete")
		and not event_labels.has("Group Color…") and not event_labels.has("Edit Comment…"), true) and all_passed
	# Single-row disable uses the singular id so the live state can relabel it
	# Disable Row / Enable Row (regression: a static "Disable / Enable" label was shipped).
	all_passed = _check("single-row disable keeps the dynamic Row label",
		event_labels.has("Disable Row") and not event_labels.has("Disable / Enable"), true) and all_passed
	var group_row: EventRowData = EventRowData.new()
	group_row.row_type = EventRowData.RowType.GROUP
	menu_editor._context_row = group_row
	menu_editor._build_row_context_menu(group_row)
	var group_labels: PackedStringArray = _menu_labels(menu_editor._row_context_menu)
	all_passed = _check("group menu shows group items, hides event-only ones",
		group_labels.has("Group Color…") and group_labels.has("Runtime Toggleable")
		and not group_labels.has("Convert to OR Block") and not group_labels.has("Edit Comment…"), true) and all_passed
	var comment_row: EventRowData = EventRowData.new()
	comment_row.row_type = EventRowData.RowType.COMMENT
	menu_editor._context_row = comment_row
	menu_editor._build_row_context_menu(comment_row)
	var comment_labels: PackedStringArray = _menu_labels(menu_editor._row_context_menu)
	all_passed = _check("comment menu shows comment items, hides group/event ones",
		comment_labels.has("Edit Comment…") and comment_labels.has("Attach To Event Above")
		and not comment_labels.has("Group Color…") and not comment_labels.has("Add Sub-Event"), true) and all_passed
	# The advanced/event-only authoring lives in More, not at the top.
	menu_editor._context_row = event_row
	menu_editor._build_row_more_submenu(true)
	all_passed = _check("advanced authoring is folded into More",
		_menu_labels(menu_editor._row_more_submenu).has("Add Pick Filter (For Each)…"), true) and all_passed
	menu_editor.free()

	# ── Feature tags: the Has Feature param is an editable suggest combo (curated tags +
	# free text for custom export-preset tags), never a closed dropdown, and the template
	# stays the frozen OS.has_feature shape.
	var feature_descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "HasOSFeature")
	all_passed = _check("Has Feature keeps its frozen template",
		feature_descriptor != null and feature_descriptor.codegen_template == "OS.has_feature({feature})", true) and all_passed
	all_passed = _check("the feature param suggests the full curated tag set (typeable, not a closed dropdown)",
		feature_descriptor != null and feature_descriptor.params[0].options.is_empty()
		and feature_descriptor.params[0].autocomplete.has("\"windows\"")
		and feature_descriptor.params[0].autocomplete.has("\"template_release\"")
		and feature_descriptor.params[0].autocomplete.has("\"mobile\""), true) and all_passed

	return all_passed


static func _menu_labels(menu: PopupMenu) -> PackedStringArray:
	var labels: PackedStringArray = PackedStringArray()
	for i in range(menu.item_count):
		if not menu.is_item_separator(i):
			labels.append(menu.get_item_text(i))
	return labels


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] godot_workflow_test: %s" % label)
		return true
	print("[FAIL] godot_workflow_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
