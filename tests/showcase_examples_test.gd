# Godot EventSheets — showcase examples regression test.
# Guards the three shipped demos (flagship Carousel + Starfall + Quest FSM): each .tres
# must compile to plain GDScript, the compiled output must contain the power-feature
# constructs each demo advertises, and each .tscn must instantiate. Uses the stable
# un-versioned filenames so it survives future showcase refreshes (regenerate the demos
# with tools/build_examples.gd).
@tool
extends RefCounted
class_name ShowcaseExamplesTest

static func run() -> bool:
	var passed: bool = true

	# Flagship: Carousel of Juice — function reuse, runtime group, if/elif/else, behaviors.
	passed = _check_sheet("showcase_carousel", "res://demo/showcase/showcase_carousel.tres", [
		"func juice_tile(index: int, kick: float)",
		"juice_tile(beat, intensity * 5.0)",
		"__group_juice_active",
		"elif Input.is_action_just_pressed(&\"ui_cancel\")",
		"else:",
	]) and passed
	passed = _check_scene("showcase_carousel scene wires Spring + Tween",
		"res://demo/showcase/showcase_carousel.tscn", ["SpringBehavior", "TweenBehavior"]) and passed

	# Starfall — enum + match FSM, group pick-filter, spawner.
	passed = _check_sheet("starfall", "res://demo/showcase/starfall.tres", [
		"enum State { PLAYING, GAME_OVER }",
		"match state:",
		"for star in get_tree().get_nodes_in_group(\"stars\")",
		"if not (star.position.y > 560.0):",
		"load(\"res://demo/showcase/star.tscn\").instantiate()",
	]) and passed
	passed = _check_scene("starfall scene has Ship + ScoreLabel",
		"res://demo/showcase/starfall.tscn", ["Ship", "ScoreLabel"]) and passed
	passed = _check("star sub-scene exists", ResourceLoader.exists("res://demo/showcase/star.tscn"), true) and passed

	# Quest FSM — enum + match, Dictionary/Array collections, signals, function.
	passed = _check_sheet("quest_fsm", "res://demo/showcase/quest_fsm.tres", [
		"enum QuestState {",
		"signal item_collected(id: String)",
		"signal quest_advanced(phase: int)",
		"item_collected.connect(_on_item_collected)",
		"func grant_item(id: String, qty: int)",
		"inventory[id] = inventory.get(id, 0) + qty",
		"quest_log.append(id)",
		"@export var inventory: Dictionary",
		"match quest_state:",
	]) and passed
	passed = _check_scene("quest_fsm scene has Icon + Screen",
		"res://demo/showcase/quest_fsm.tscn", ["Icon", "Screen"]) and passed

	# Discovery: the flagship is the one the plugin opens; the secondaries never compete.
	passed = _check("flagship is the discovered showcase",
		EventForgePlugin._find_showcase_scene(), "res://demo/showcase/showcase_carousel.tscn") and passed

	return passed

static func _check_sheet(label: String, path: String, required: Array) -> bool:
	var sheet: EventSheetResource = load(path) as EventSheetResource
	var ok: bool = _check("%s loads as EventSheetResource" % label, sheet is EventSheetResource, true)
	if sheet == null:
		return false
	var result: Dictionary = SheetCompiler.compile(sheet, "user://%s_showcase_test.gd" % label)
	ok = _check("%s compiles to GDScript" % label, bool(result.get("success", false)), true) and ok
	var output: String = str(result.get("output", ""))
	# The compiled output must PARSE as GDScript, not just be non-empty. Strip the
	# `class_name X` line first: the showcase .gd is already registered as that global class,
	# so re-registering it via reload() would error on the duplicate name (not a parse fault).
	var parse_source: String = ""
	for source_line: String in output.split("\n"):
		if source_line.begins_with("class_name "):
			continue
		parse_source += source_line + "\n"
	var script: GDScript = GDScript.new()
	script.source_code = parse_source
	ok = _check("%s output parses as GDScript" % label, script.reload(true) == OK, true) and ok
	for token: String in required:
		ok = _check("%s output contains: %s" % [label, token], output.contains(token), true) and ok
	return ok

static func _check_scene(label: String, path: String, node_names: Array) -> bool:
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		return _check(label, false, true)
	var root: Node = scene.instantiate()
	var ok: bool = root != null
	for node_name: String in node_names:
		ok = ok and root.find_child(node_name, true, false) != null
	if root != null:
		root.free()
	return _check(label, ok, true)

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] showcase_examples_test: %s" % label)
		return true
	print("[FAIL] showcase_examples_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
