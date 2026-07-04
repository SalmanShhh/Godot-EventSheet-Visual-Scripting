# Godot EventSheets - Autoload (Singleton) sheets: a new sheet type compiling to
# project-wide Nodes whose exposed functions publish ACEs addressed by autoload name.
@tool
class_name SingletonSheetsTest
extends RefCounted


class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false
	func undo() -> void: pass
	func redo() -> void: pass
	func clear_history() -> void: pass


static func run() -> bool:
	var all_passed: bool = true

	# Sheet Type applies the autoload identity (extends Node, named).
	var editor: EventSheetEditor = EventSheetEditor.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	editor._apply_sheet_type_settings(4, "", "", "", false, PackedStringArray(), PackedStringArray(), PackedStringArray(), PackedStringArray(), "GameState")
	all_passed = _check("Sheet Type applies the autoload identity",
		sheet.autoload_mode and sheet.autoload_name == "GameState" and sheet.host_class == "Node", true) and all_passed

	# Exposed functions publish ACEs that call THROUGH the autoload name.
	var add_score: EventFunction = EventFunction.new()
	add_score.function_name = "add_score"
	add_score.expose_as_ace = true
	var amount: ACEParam = ACEParam.new()
	amount.id = "amount"
	amount.type_name = "int"
	add_score.params.append(amount)
	var body: RawCodeRow = RawCodeRow.new()
	body.code = "pass"
	add_score.events.append(body)
	sheet.functions.append(add_score)
	var output: String = str(SheetCompiler.compile(sheet, "user://eventsheets_singleton.gd").get("output", ""))
	all_passed = _check("autoload sheets extend Node", output.contains("extends Node"), true) and all_passed
	all_passed = _check("exposed ACEs call through the singleton name",
		output.contains("## @ace_codegen_template(\"GameState.add_score({amount})\")"), true) and all_passed
	var generated: GDScript = GDScript.new()
	generated.source_code = output
	all_passed = _check("singleton output parses", generated.reload(true) == OK, true) and all_passed

	# Register flow: guards + the ProjectSettings entry (temp name, cleaned up).
	all_passed = _check("unnamed autoloads refuse to register",
		editor._register_autoload_entry(EventSheetResource.new(), "user://x.tres").is_empty(), false) and all_passed
	sheet.autoload_name = "EventSheetsTestSingleton"
	var register_problem: String = editor._register_autoload_entry(sheet, "user://eventsheets_singleton.tres")
	all_passed = _check("registration succeeds for a valid sheet", register_problem, "") and all_passed
	all_passed = _check("the autoload entry points at the generated script",
		str(ProjectSettings.get_setting("autoload/EventSheetsTestSingleton")), "*user://eventsheets_singleton.gd") and all_passed
	ProjectSettings.set_setting("autoload/EventSheetsTestSingleton", "*res://somewhere_else.gd")
	all_passed = _check("name collisions refuse to overwrite",
		editor._register_autoload_entry(sheet, "user://eventsheets_singleton.tres").contains("already exists"), true) and all_passed
	ProjectSettings.set_setting("autoload/EventSheetsTestSingleton", null)
	editor.free()

	# Singleton starter templates build, compile, and parse.
	for template_id in [3, 4, 5]:
		var template_editor: EventSheetEditor = EventSheetEditor.new()
		template_editor.setup(EventSheetResource.new())
		template_editor.set_undo_redo_manager(NoopUndoManager.new())
		template_editor._starter._new_sheet_from_template(template_id)
		var template_sheet: EventSheetResource = template_editor._current_sheet
		var template_output: String = str(SheetCompiler.compile(template_sheet, "user://eventsheets_tpl_%d.gd" % template_id).get("output", ""))
		var template_script: GDScript = GDScript.new()
		template_script.source_code = template_output
		all_passed = _check("singleton template %d is an autoload that compiles + parses" % template_id,
			template_sheet.autoload_mode and not template_sheet.autoload_name.is_empty() and template_script.reload(true) == OK, true) and all_passed
		template_editor.free()

	# ── Event-bus triggers: autoload signals fire events in ANY sheet ──
	ProjectSettings.set_setting("autoload/TestBus", "*res://tests/fixtures/test_bus.gd")
	var consumer: EventSheetResource = EventSheetResource.new()
	var bus_event: EventRow = EventRow.new()
	bus_event.trigger_provider_id = "TestBus"
	bus_event.trigger_id = "signal:game_paused"
	bus_event.trigger_source_path = "autoload:TestBus"
	var pause_action: ACEAction = ACEAction.new()
	pause_action.provider_id = "Core"
	pause_action.ace_id = "X"
	pause_action.codegen_template = "print(\"paused\")"
	bus_event.actions.append(pause_action)
	consumer.events.append(bus_event)
	var bus_output: String = str(SheetCompiler.compile(consumer, "user://eventsheets_bus.gd").get("output", ""))
	all_passed = _check("bus triggers connect by singleton name",
		bus_output.contains("	TestBus.game_paused.connect(_on_test_bus_game_paused)"), true) and all_passed
	all_passed = _check("bus handlers token on the bus name",
		bus_output.contains("func _on_test_bus_game_paused() -> void:"), true) and all_passed
	# (No reload() assert here: the GDScript analyzer snapshots autoloads at project
	# load, so a runtime-registered TestBus isn't resolvable headless - the editor
	# smoke covers real in-editor usage.)
	ProjectSettings.set_setting("autoload/TestBus", null)

	# Registered autoloads join the provider scan and map class -> singleton name.
	ProjectSettings.set_setting("autoload/SpringDemo", "*res://eventsheet_addons/spring/spring_behavior.gd")
	var scan_editor: EventSheetEditor = EventSheetEditor.new()
	scan_editor.setup(EventSheetResource.new())
	scan_editor.set_undo_redo_manager(NoopUndoManager.new())
	scan_editor._build_addon_ace_sources()
	all_passed = _check("registered autoloads map provider class to singleton name",
		str(scan_editor._autoload_provider_names.get("SpringBehavior", "")), "SpringDemo") and all_passed
	var bus_definition: ACEDefinition = ACEDefinition.new()
	bus_definition.provider_id = "SpringBehavior"
	bus_definition.id = "signal:spring_reached"
	bus_definition.ace_type = ACEDefinition.ACEType.TRIGGER
	var baked_event: EventRow = EventRow.new()
	scan_editor._bake_trigger_signature(baked_event, bus_definition)
	all_passed = _check("picked bus triggers bake the autoload source",
		baked_event.trigger_source_path, "autoload:SpringDemo") and all_passed
	scan_editor.free()
	ProjectSettings.set_setting("autoload/SpringDemo", null)

	# ── Addon-author loop: publish surface, pack README, test bench ──
	var author_editor: EventSheetEditor = EventSheetEditor.new()
	var pack: EventSheetResource = EventSheetResource.new()
	pack.behavior_mode = true
	pack.host_class = "Node2D"
	pack.custom_class_name = "JuiceKit"
	pack.addon_tags = PackedStringArray(["juice"])
	pack.variables = {"strength": {"type": "float", "default": 1.0, "exported": true, "attributes": {"tooltip": "How juicy."}}}
	var kick: EventFunction = EventFunction.new()
	kick.function_name = "kick"
	kick.expose_as_ace = true
	kick.ace_display_name = "Kick"
	kick.ace_category = "Juice"
	var kick_param: ACEParam = ACEParam.new()
	kick_param.id = "amount"
	kick_param.type_name = "float"
	kick.params.append(kick_param)
	var kick_body: RawCodeRow = RawCodeRow.new()
	kick_body.code = "pass"
	kick.events.append(kick_body)
	pack.functions.append(kick)
	var kit_signal: RawCodeRow = RawCodeRow.new()
	kit_signal.code = "## @ace_trigger
## @ace_name(\"On Kicked\")
signal kicked"
	pack.events.append(kit_signal)
	author_editor.setup(pack)
	author_editor.set_undo_redo_manager(NoopUndoManager.new())
	var surface: Dictionary = author_editor._collect_publish_surface(pack)
	all_passed = _check("publish surface lists exposed actions",
		str((surface.get("actions", []) as Array)[0].get("name", "")), "Kick") and all_passed
	all_passed = _check("publish surface lists annotated triggers",
		str((surface.get("triggers", []) as Array)[0].get("name", "")), "On Kicked") and all_passed
	all_passed = _check("publish surface lists exported properties",
		str((surface.get("properties", []) as Array)[0].get("name", "")), "strength") and all_passed
	var surface_text: String = EventSheetEditor.publish_surface_text(surface)
	all_passed = _check("surface text renders all sections",
		surface_text.contains("Kick (amount: float)") and surface_text.contains("On Kicked") and surface_text.contains("strength: float"), true) and all_passed
	var readme: String = author_editor._generate_pack_readme(pack)
	all_passed = _check("pack README documents the surface",
		readme.contains("# JuiceKit") and readme.contains("**Tags:** juice") and readme.contains("- **Kick** (`amount: float`)") and readme.contains("`strength: float` (default `1.0`) - How juicy."), true) and all_passed
	var bench_problem: String = author_editor._build_test_bench(pack, "user://eventsheets_bench.tscn")
	all_passed = _check("test bench builds host + behavior scene", bench_problem, "") and all_passed
	var bench_scene: PackedScene = load("user://eventsheets_bench.tscn")
	var bench_root: Node = bench_scene.instantiate()
	all_passed = _check("bench host carries the behavior child",
		bench_root is Node2D and bench_root.get_child_count() == 1 and bench_root.get_child(0).get_script() != null, true) and all_passed
	bench_root.free()
	all_passed = _check("bench script rides next to the scene (no repo-root pollution)",
		FileAccess.file_exists("user://eventsheets_bench.gd"), true) and all_passed
	# Unannotated autoload scripts must NOT publish (the bridge mentions \"@ace_*\" in a
	# doc comment - that must not count either).
	ProjectSettings.set_setting("autoload/PlainBus", "*res://tests/fixtures/test_bus.gd")
	author_editor._build_addon_ace_sources()
	all_passed = _check("unannotated autoloads stay out of the provider scan",
		author_editor._autoload_provider_names.values().has("PlainBus"), false) and all_passed
	ProjectSettings.set_setting("autoload/PlainBus", null)
	author_editor.free()

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] singleton_sheets_test: %s" % label)
		return true
	print("[FAIL] singleton_sheets_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
