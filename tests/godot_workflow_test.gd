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

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] godot_workflow_test: %s" % label)
		return true
	print("[FAIL] godot_workflow_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
