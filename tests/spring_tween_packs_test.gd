# Godot EventSheets — Spring + Tween behavior packs (the C3 simple_spring port, cleaned,
# and Godot Tweens as a behavior). The spring assert SIMULATES: a stepped spring must
# converge on its target and fire On Spring Reached.
@tool
extends RefCounted
class_name SpringTweenPacksTest

static func run() -> bool:
	var all_passed: bool = true

	var spring_script: GDScript = load("res://eventsheet_addons/spring/spring_behavior.gd")
	var tween_script: GDScript = load("res://eventsheet_addons/tween/tween_behavior.gd")
	all_passed = _check("both packs load", spring_script != null and tween_script != null, true) and all_passed

	# Spring simulation: converge on the target, settle, fire the trigger.
	var spring: Node = spring_script.new()
	var reached_names: Array = []
	spring.spring_reached.connect(func(spring_name: String) -> void: reached_names.append(spring_name))
	spring.spring_to("health_bar", 100.0)
	all_passed = _check("springing reports active", spring.is_springing("health_bar"), true) and all_passed
	for step in range(600):
		spring._process(1.0 / 60.0)
	all_passed = _check("spring converges on its target",
		absf(spring.spring_value("health_bar") - 100.0) < 0.5, true) and all_passed
	all_passed = _check("settled springs fire On Spring Reached",
		reached_names.has("health_bar") and not spring.is_springing("health_bar"), true) and all_passed
	all_passed = _check("progress reads 1 at rest", spring.spring_progress("health_bar"), 1.0) and all_passed
	spring.add_impulse("health_bar", 500.0)
	all_passed = _check("impulses re-activate the spring", spring.is_springing("health_bar"), true) and all_passed
	spring.set_spring("health_bar", 5.0)
	all_passed = _check("Set Spring snaps without motion",
		spring.spring_value("health_bar") == 5.0 and not spring.is_springing("health_bar"), true) and all_passed
	spring.free()

	# Tween pack: combo mappings resolve to the right Godot enums (no tree needed).
	var tween: Node = tween_script.new()
	tween.transition = "elastic"
	tween.easing = "in_out"
	all_passed = _check("transition combo maps to TRANS_ELASTIC", tween._trans_id(), Tween.TRANS_ELASTIC) and all_passed
	all_passed = _check("easing combo maps to EASE_IN_OUT", tween._ease_id(), Tween.EASE_IN_OUT) and all_passed
	tween.transition = "nonsense"
	all_passed = _check("unknown transitions fall back to sine", tween._trans_id(), Tween.TRANS_SINE) and all_passed
	all_passed = _check("not tweening before any call", tween.is_tweening(), false) and all_passed
	tween.free()

	# Inspector attributes shipped INSIDE a pack: the spring exports carry ranges.
	var spring_source: String = FileAccess.get_file_as_string("res://eventsheet_addons/spring/spring_behavior.gd")
	all_passed = _check("pack exports carry Inspector attributes",
		spring_source.contains("@export_range(0, 1, 0.01) var default_damping") and spring_source.contains("## Spring force toward the target"), true) and all_passed
	var tween_source: String = FileAccess.get_file_as_string("res://eventsheet_addons/tween/tween_behavior.gd")
	all_passed = _check("tween combos compile to @export_enum",
		tween_source.contains("@export_enum(\"linear\", \"sine\""), true) and all_passed

	# Save System addon (pack 21): autoload-mode persistence vocabulary.
	var save_sheet: EventSheetResource = load("res://eventsheet_addons/save_system/save_system_addon.tres")
	all_passed = _check("save pack is an autoload sheet",
		save_sheet.autoload_mode and save_sheet.autoload_name == "SaveSystem", true) and all_passed
	var save_source: String = FileAccess.get_file_as_string("res://eventsheet_addons/save_system/save_system_addon.gd")
	all_passed = _check("save ACEs call through the SaveSystem singleton",
		save_source.contains("@ace_codegen_template(\"SaveSystem.save_number({key}, {value})\")"), true) and all_passed
	all_passed = _check("save pack loads as a script",
		load("res://eventsheet_addons/save_system/save_system_addon.gd") != null, true) and all_passed
	var save_instance: Node = load("res://eventsheet_addons/save_system/save_system_addon.gd").new()
	save_instance.slot = 7
	all_passed = _check("slots map to per-slot files", save_instance._slot_path(), "user://save_7.cfg") and all_passed
	save_instance.save_number("hp", 42.0)
	all_passed = _check("saved values round-trip", save_instance.load_number("hp"), 42.0) and all_passed
	all_passed = _check("has_save_key sees the key", save_instance.has_save_key("hp"), true) and all_passed
	save_instance.delete_slot()
	all_passed = _check("delete clears the slot", save_instance.has_save_key("hp"), false) and all_passed
	# v2: Variant core, formats, encryption, lifecycle, slot metadata, autosave.
	var v2: Node = load("res://eventsheet_addons/save_system/save_system_addon.gd").new()
	v2.slot = 8
	v2.save_value("spawn", Vector2(3, 4))
	all_passed = _check("Variant values round-trip", v2.load_value("spawn", Vector2.ZERO), Vector2(3, 4)) and all_passed
	v2.format = "json"
	v2.file_pattern = "save_{slot}.json"
	v2.save_value("name", "Robin")
	all_passed = _check("json format round-trips", str(v2.load_value("name", "")), "Robin") and all_passed
	v2.encryption_key = "hunter2"
	v2.file_pattern = "save_{slot}.enc"
	v2.save_value("secret", 99.0)
	all_passed = _check("encrypted saves round-trip", float(v2.load_value("secret", 0.0)), 99.0) and all_passed
	var raw_bytes: String = FileAccess.get_file_as_string(v2._slot_path())
	all_passed = _check("encrypted files don't leak plaintext", raw_bytes.contains("secret"), false) and all_passed
	v2.encryption_key = ""
	v2.format = "config"
	v2.file_pattern = "save_{slot}.cfg"
	var broadcast_log: Array = []
	v2.before_save.connect(func(slot_index: int) -> void: broadcast_log.append("before:%d" % slot_index))
	v2.after_load.connect(func(slot_index: int) -> void: broadcast_log.append("after:%d" % slot_index))
	v2.save_game()
	v2.load_game()
	all_passed = _check("lifecycle broadcasts fire in order",
		broadcast_log == ["before:8", "after:8"], true) and all_passed
	v2.save_value("hp", 5.0)
	all_passed = _check("slot metadata sees the file",
		v2.slot_exists(8) and v2.list_slots().has(8) and int(v2.slot_modified_time(8)) > 0, true) and all_passed
	v2.delete_slot()
	broadcast_log.clear()
	v2.autosave_interval = 0.5
	for step in range(40):
		v2._process(1.0 / 60.0)
	all_passed = _check("autosave fires On Before Save on its interval",
		broadcast_log.has("before:8"), true) and all_passed
	v2.free()
	save_instance.free()

	# Release showcase (the release ritual): loads, parses, scene instantiates.
	var showcase_sheet: EventSheetResource = load("res://demo/showcase/showcase_v070.tres")
	all_passed = _check("showcase sheet loads with Live Values on",
		showcase_sheet != null and showcase_sheet.emit_live_values, true) and all_passed
	all_passed = _check("showcase script loads",
		load("res://demo/showcase/showcase_v070.gd") != null, true) and all_passed
	var showcase_scene: PackedScene = load("res://demo/showcase/showcase_v070.tscn")
	var showcase_root: Node = showcase_scene.instantiate()
	all_passed = _check("showcase scene wires Spring + Tween behaviors",
		showcase_root.get_node_or_null("SpringBehavior") != null and showcase_root.get_node_or_null("TweenBehavior") != null, true) and all_passed
	showcase_root.free()

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] spring_tween_packs_test: %s" % label)
		return true
	print("[FAIL] spring_tween_packs_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
