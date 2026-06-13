# Godot EventSheets — Godot-native workflow arc: entry points (attach/open from the
# places Godot devs already click), settings registration, and the debug/docs tier.
# Editor glue (EventSheetContextMenu) is never instantiated headless — the
# EditorDebuggerPlugin lesson; cores are tested here, glue by the editor smoke.
@tool
extends RefCounted
class_name GodotWorkflowTest

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

	# ── Attach Event Sheet (the "Attach Script" reflex) ───────────────────────────
	for stale: String in ["user://boss_fight_sheet.tres", "user://boss_fight_sheet_generated.gd",
			"user://boss_fight_sheet-2.tres", "user://boss_fight_sheet-2_generated.gd"]:
		if FileAccess.file_exists(stale):
			DirAccess.remove_absolute(stale)
	var node: Node2D = Node2D.new()
	node.name = "Boss Fight"
	var created: Dictionary = EventSheetWorkflow.create_sheet_for_node(node, "user://")
	var created_sheet: EventSheetResource = ResourceLoader.load(str(created.get("sheet_path")), "", ResourceLoader.CACHE_MODE_IGNORE)
	all_passed = _check("attach creates a host-matched sheet beside the scene",
		bool(created.get("ok")) and str(created.get("sheet_path")) == "user://boss_fight_sheet.tres"
		and created_sheet.host_class == "Node2D", true) and all_passed
	all_passed = _check("attach compiles the pair and scripts the node",
		node.get_script() != null
		and FileAccess.file_exists("user://boss_fight_sheet_generated.gd"), true) and all_passed
	all_passed = _check("nodes that already have a script are refused",
		bool(EventSheetWorkflow.create_sheet_for_node(node, "user://").get("ok")), false) and all_passed
	var sibling_node: Node2D = Node2D.new()
	sibling_node.name = "Boss Fight"
	var suffixed: Dictionary = EventSheetWorkflow.create_sheet_for_node(sibling_node, "user://")
	all_passed = _check("name collisions suffix instead of overwriting",
		str(suffixed.get("sheet_path")), "user://boss_fight_sheet-2.tres") and all_passed

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
	all_passed = _check("the Source header pairs generated scripts to their sheet",
		EventSheetProjectDoctor.sheet_for_script("user://boss_fight_sheet_generated.gd"),
		"user://boss_fight_sheet.tres") and all_passed
	all_passed = _check("pack siblings pair through the pairing rule",
		EventSheetProjectDoctor.sheet_for_script("res://eventsheet_addons/spring/spring_behavior.gd"),
		"res://eventsheet_addons/spring/spring_behavior.tres") and all_passed
	all_passed = _check("hand-written scripts pair to nothing",
		EventSheetProjectDoctor.sheet_for_script("res://addons/eventforge/plugin.gd"), "") and all_passed
	var scripted: Node = Node.new()
	scripted.set_script(load("user://boss_fight_sheet_generated.gd"))
	var plain: Node = Node.new()
	all_passed = _check("the Inspector button handles sheet-scripted nodes only",
		EventSheetEditButtonPlugin.sheet_path_for(scripted) == "user://boss_fight_sheet.tres"
		and EventSheetEditButtonPlugin.sheet_path_for(plain) == "", true) and all_passed
	scripted.free()
	plain.free()
	node.free()
	sibling_node.free()
	for cleanup: String in ["user://boss_fight_sheet.tres", "user://boss_fight_sheet_generated.gd",
			"user://boss_fight_sheet-2.tres", "user://boss_fight_sheet-2_generated.gd"]:
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
	ProjectSettings.set_setting("eventsheets/editor/shortcuts/duplicate", "Alt+D")
	var rebound: InputEventKey = InputEventKey.new()
	rebound.keycode = KEY_D
	rebound.alt_pressed = true
	all_passed = _check("Project Settings rebinds win over defaults",
		EventSheetShortcuts.matches(rebound, "duplicate") and not EventSheetShortcuts.matches(combo, "duplicate"), true) and all_passed
	ProjectSettings.set_setting("eventsheets/editor/shortcuts/duplicate", null)

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
		EventForgePlugin._find_showcase_scene(), "res://demo/showcase/showcase_v070.tscn") and all_passed

	# ── Toolbar redesign: grouped menus, flow-wraps instead of clipping ───────────
	var toolbar_editor: EventSheetEditor = EventSheetEditor.new()
	toolbar_editor.setup(EventSheetResource.new())
	toolbar_editor.set_undo_redo_manager(NoopUndoManager.new())
	all_passed = _check("the toolbar wraps instead of clipping",
		toolbar_editor._toolbar is HFlowContainer, true) and all_passed
	all_passed = _check("grouping leaves a short toolbar",
		toolbar_editor._toolbar.get_child_count() <= 16, true) and all_passed
	var sheet_menu: MenuButton = toolbar_editor._toolbar.find_child("EventSheetSheetMenu", true, false) as MenuButton
	var add_menu: MenuButton = toolbar_editor._toolbar.find_child("EventSheetAddMenu", true, false) as MenuButton
	var edit_menu: MenuButton = toolbar_editor._toolbar.find_child("EventSheetEditMenu", true, false) as MenuButton
	var view_menu: MenuButton = toolbar_editor._toolbar.find_child("EventSheetViewMenu", true, false) as MenuButton
	all_passed = _check("Sheet/Add/Edit/View menus carry the consolidated actions",
		sheet_menu != null and sheet_menu.get_popup().item_count == 8
		and add_menu != null and add_menu.get_popup().item_count == 4
		and edit_menu != null and edit_menu.get_popup().item_count == 5
		and view_menu != null and view_menu.get_popup().item_count == 12, true) and all_passed

	# ── Welcome window: self-sizing dialog, margined, reopenable, checkbox synced ─
	toolbar_editor._build_welcome_window()
	all_passed = _check("welcome self-sizes to its content (AcceptDialog)",
		toolbar_editor._welcome_window is AcceptDialog, true) and all_passed
	var welcome_margin: MarginContainer = toolbar_editor._welcome_window.find_child("WelcomeMargin", true, false) as MarginContainer
	all_passed = _check("welcome content sits inside real margins",
		welcome_margin != null and welcome_margin.get_theme_constant("margin_left") == 14, true) and all_passed
	all_passed = _check("welcome exposes the native-default checkbox for reopen sync",
		toolbar_editor._welcome_window.get_meta("native_check") is CheckBox, true) and all_passed
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
		variable_dialog._attr_section.visible, false) and all_passed
	all_passed = _check("combo options hide for non-String types",
		variable_dialog._options_row.visible, false) and all_passed
	variable_dialog.open_for_edit("global", {"attributes": {"tooltip": "hi"}}, "title", "String", "\"x\"", false, "Edit Variable", false, true)
	all_passed = _check("existing attributes auto-expand the section",
		variable_dialog._attr_section.visible and variable_dialog._options_row.visible, true) and all_passed
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

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] godot_workflow_test: %s" % label)
		return true
	print("[FAIL] godot_workflow_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
