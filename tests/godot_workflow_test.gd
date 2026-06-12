# Godot EventSheets — Godot-native workflow arc: entry points (attach/open from the
# places Godot devs already click), settings registration, and the debug/docs tier.
# Editor glue (EventSheetContextMenu) is never instantiated headless — the
# EditorDebuggerPlugin lesson; cores are tested here, glue by the editor smoke.
@tool
extends RefCounted
class_name GodotWorkflowTest

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

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] godot_workflow_test: %s" % label)
		return true
	print("[FAIL] godot_workflow_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
