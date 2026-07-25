# Godot EventSheets - showcase examples regression test.
# Guards the three shipped demos (flagship Carousel + Starfall + Quest FSM): each .tres
# must compile to plain GDScript, the compiled output must contain the power-feature
# constructs each demo advertises, and each .tscn must instantiate. Uses the stable
# un-versioned filenames so it survives future showcase refreshes (regenerate the demos
# with tools/build_examples.gd).
@tool
class_name ShowcaseExamplesTest
extends RefCounted


static func run() -> bool:
	var passed: bool = true

	# EnemyStats - the Custom Resource with a designed Inspector (the rich-inspector showcase).
	passed = _check_sheet("enemy_stats", "res://demo/showcase/enemy_stats/enemy_stats.gd", [
		"class_name EnemyStats",
		"extends Resource",
		"# @inspector_header Combat #e06666",
		"# @inspector_info Shared resource - edits affect every enemy that references it.",
		"# @inspector_required",
		"eventsheet:min_max:0:60",
		"eventsheet:table:item=String,count=int,rare=bool",
		"eventsheet:progress_bar:0:200",
		"combat_max_health = clampi(value, 0, 200)",
		"@export_placeholder(\"e.g. Cave Rat\")",
		"func roll_damage() -> float",
	]) and passed
	passed = _check("enemy_stats example instance exists",
		ResourceLoader.exists("res://demo/showcase/enemy_stats/enemy_stats_example.tres"), true) and passed

	# Menu Starter - the UI starter driven by the HUD Kit pack (zero connected signals).
	passed = _check_sheet("menu_starter", "res://demo/showcase/menu_starter/menu_starter.gd", [
		"class_name MenuStarter",
		"$HudKit.switch_screen(\"TitleScreen\")",
		"$HudKit.on_button_pressed.connect(handle_button)",
		"func handle_button() -> void:",
		"$HudKit.set_bar(\"HpBar\", 100.0, 100.0)",
		"$HudKit.is_panel_visible(\"GameScreen\")",
		"$HudKit.show_toast(",
	]) and passed
	passed = _check_scene("menu_starter scene wires HudKit + the four screens",
		"res://demo/showcase/menu_starter/menu_starter.tscn", ["HudKit", "TitleScreen", "SettingsScreen", "GameScreen", "PauseScreen"]) and passed

	# Input Rebind - the rebind screen built from the Input/InputMap/Gamepad vocabulary.
	passed = _check_sheet("input_rebind", "res://demo/showcase/input_rebind/input_rebind.gd", [
		"class_name InputRebindDemo",
		"InputMap.action_erase_events(rebinding_action)",
		"InputMap.action_add_event(rebinding_action, event)",
		"Input.is_action_just_pressed(\"demo_jump\")",
		"Input.get_joy_name(pads[0])",
		"Input.start_joy_vibration(0, 0.5, 0.5, 0.4)",
		"func binding_text(action_name: String) -> String:",
		"return events[0].as_text() if not events.is_empty() else \"unbound\"",
	]) and passed
	passed = _check_scene("input_rebind scene wires HudKit + the rebind rows",
		"res://demo/showcase/input_rebind/input_rebind.tscn", ["HudKit", "JumpLabel", "RebindJumpButton", "DashLabel", "RebindDashButton", "ResetButton", "GamepadLabel", "VibrateButton"]) and passed

	# Path Chase - Platformer Pathfinding driving Platformer Movement through the ai seam.
	passed = _check_sheet("path_chase", "res://demo/showcase/path_chase/path_chase.gd", [
		"class_name PathChaseDemo",
		"$Chaser/Pathfinding.build_nav_graph($Level)",
		"$Chaser/Pathfinding.add_portal(976.0, 528.0, 176.0, 304.0, true)",
		"$Chaser/Pathfinding.set_nav_debug_draw(true)",
		"$Chaser/Pathfinding.find_path_to_node($Player, \"nearest\")",
		"$Chaser/Pathfinding.regenerate_nav_graph()",
		"func toggle_bridge() -> void:",
		"$Player/Movement.jump()",
	]) and passed
	passed = _check_scene("path_chase scene wires the Level + actors + the portal pair",
		"res://demo/showcase/path_chase/path_chase.tscn", ["Level", "Player", "Chaser", "Movement", "Pathfinding", "PortalEntrance", "PortalExit"]) and passed

	# Raycast Lab - all six ways to ask the physics world a question, each an ACE row using the
	# SHIPPED template. These tokens ARE the raycasting vocabulary's emitted form, so if a frozen
	# template ever drifts, this notices. The `$Player/Radar.` prefixes prove the "On node" target
	# works: a Node2D-hosted sheet driving verbs whose host class is RayCast2D.
	passed = _check_sheet("raycast_lab", "res://demo/showcase/raycast_lab/raycast_lab.gd", [
		"class_name RaycastLabDemo",
		"$Player/Radar.target_position = Vector2.from_angle(deg_to_rad(sweep_deg)) * 230.0",
		"$Player/Radar.force_raycast_update()",
		"if $Player/Radar.is_colliding():",
		"$Player/Radar.get_collision_point()",
		"PhysicsRayQueryParameters2D.create($Player.global_position, get_global_mouse_position(), 1, [$Player.get_rid()])",
		"hit = get_world_2d().direct_space_state.intersect_ray(__rq_laser)",
		"if not hit.is_empty():",
		"hit.get(\"position\", Vector2.ZERO)",
		"if (hit.get(\"collider\", null) != null and hit[\"collider\"].is_in_group(\"targets\")):",
		"__pq_pick.position = get_global_mouse_position()",
		"direct_space_state.intersect_point(__pq_pick, 8)",
		"direct_space_state.intersect_shape(__sq_zone, 16)",
		"var __cm_probe := get_world_2d().direct_space_state.cast_motion(__sq_probe)",
		"travel = __cm_probe[0] if __cm_probe.size() > 0 else 1.0",
		"$Gate.force_shapecast_update()",
		"$Gate.get_closest_collision_safe_fraction()",
	]) and passed
	# No `{uid}` may survive into the emitted script: the dock bakes it at apply time and the
	# compiler never does, so a builder that forgets ships a syntax error.
	passed = _check("raycast_lab bakes every per-row uid",
		FileAccess.get_file_as_string("res://demo/showcase/raycast_lab/raycast_lab.gd").contains("{uid}"), false) and passed
	passed = _check_scene("raycast_lab scene wires the radar, the gate, the canvas and the targets",
		"res://demo/showcase/raycast_lab/raycast_lab.tscn", ["Player", "Radar", "Gate", "InkLayer", "Ink", "Target1", "Readout"]) and passed
	# Ray Result Is In Group can only fire if the group actually reached the packed scene, and
	# PackedScene saves PERSISTENT groups only - a plain add_to_group() is a builder-only fact.
	passed = _check("raycast_lab targets keep their group in the packed scene",
		FileAccess.get_file_as_string("res://demo/showcase/raycast_lab/raycast_lab.tscn").contains("groups=[\"targets\"]"), true) and passed

	# Raycast Lab 3D - the same six casts one dimension up, plus the two verbs that only exist there:
	# camera picking, and the mesh-triangle face index. The Vector3 variable declarations are pinned
	# because a missing constructor literal emits a bare "(0, 0, 0)" that does not parse, and the
	# compile reports SUCCESS while doing it.
	passed = _check_sheet("raycast_lab_3d", "res://demo/showcase/raycast_lab_3d/raycast_lab_3d.gd", [
		"class_name RaycastLab3DDemo",
		"var pick_point: Vector3 = Vector3(0.0, 0.0, 0.0)",
		"$Turret/Radar.target_position = Vector3(sin(deg_to_rad(turret_deg)), 0.0, cos(deg_to_rad(turret_deg))) * 14.0",
		"$Turret/Radar.force_raycast_update()",
		"if $Turret/Radar.is_colliding():",
		"var __cam_pick := get_viewport().get_camera_3d()",
		"var __to_pick := __from_pick + __cam_pick.project_ray_normal(__mouse_pick) * 200.0",
		"pick = get_world_3d().direct_space_state.intersect_ray(__rq_pick)",
		"pick_face = pick.get(\"face_index\", -1)",
		"if (pick.get(\"collider\", null) != null and pick[\"collider\"].is_in_group(\"targets\")):",
		"__sq_zone.transform = Transform3D(Basis(), $Turret.global_position)",
		"direct_space_state.intersect_shape(__sq_zone, 16)",
		"__bs_bay.size = Vector3(8.0, 4.0, 8.0)",
		"__pq_spot.position = $Turret.global_position - Vector3(0.0, 1.05, 0.0)",
		"var __cm_probe := get_world_3d().direct_space_state.cast_motion(__sq_probe)",
		"$Sweep.force_shapecast_update()",
		"$Sweep.get_closest_collision_safe_fraction()",
		"func aim_beam(beam: Node3D, from: Vector3, to: Vector3) -> void:",
	]) and passed
	passed = _check("raycast_lab_3d bakes every per-row uid",
		FileAccess.get_file_as_string("res://demo/showcase/raycast_lab_3d/raycast_lab_3d.gd").contains("{uid}"), false) and passed
	passed = _check_scene("raycast_lab_3d scene wires the turret, the sweep, the camera and the markers",
		"res://demo/showcase/raycast_lab_3d/raycast_lab_3d.tscn",
		["Turret", "Radar", "Sweep", "CameraArm", "Camera", "Beams", "Markers", "ZoneMarks", "Pad", "Target1"]) and passed
	passed = _check("raycast_lab_3d targets keep their group in the packed scene",
		FileAccess.get_file_as_string("res://demo/showcase/raycast_lab_3d/raycast_lab_3d.tscn").contains("groups=[\"targets\"]"), true) and passed

	# Flagship: Carousel of Juice - function reuse, runtime group, if/elif/else, behaviors.
	passed = _check_sheet("showcase_carousel", "res://demo/showcase/carousel/showcase_carousel.gd", [
		"func juice_tile(index: int, kick: float)",
		"juice_tile(beat, intensity * 5.0)",
		"__group_juice_active",
		"elif Input.is_action_just_pressed(&\"ui_cancel\")",
		"else:",
	]) and passed
	passed = _check_scene("showcase_carousel scene wires Spring + Tween",
		"res://demo/showcase/carousel/showcase_carousel.tscn", ["SpringBehavior", "TweenBehavior"]) and passed

	# Starfall - enum + match FSM, group pick-filter, spawner.
	passed = _check_sheet("starfall", "res://demo/showcase/starfall/starfall.gd", [
		"enum State { PLAYING, GAME_OVER }",
		"match state:",
		"for star in get_tree().get_nodes_in_group(\"stars\")",
		"if not (star.position.y > 560.0):",
		"load(\"res://demo/showcase/starfall/star.tscn\").instantiate()",
	]) and passed
	passed = _check_scene("starfall scene has Ship + ScoreLabel",
		"res://demo/showcase/starfall/starfall.tscn", ["Ship", "ScoreLabel"]) and passed
	passed = _check("star sub-scene exists", ResourceLoader.exists("res://demo/showcase/starfall/star.tscn"), true) and passed

	# Quest FSM - enum + match, Dictionary/Array collections, signals, function.
	passed = _check_sheet("quest_fsm", "res://demo/showcase/quest_fsm/quest_fsm.gd", [
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
		"res://demo/showcase/quest_fsm/quest_fsm.tscn", ["Icon", "Screen"]) and passed

	# Guard Brain - the Utility AI pack driving a self-scoring decision maker (patrol/chase/flee).
	passed = _check_sheet("utility_ai_demo", "res://demo/showcase/utility_ai/utility_ai_demo.gd", [
		"class_name GuardBrainDemo",
		"$Guard/Brain.add_action(\"flee\", 0.0, false, 1.2)",
		"$Guard/Brain.add_consideration(\"chase\", \"threat\", \"quadratic\", 1.0, 0.5, 1.0)",
		"$Guard/Brain.set_input(\"threat\", threat)",
		"$Guard/Brain.evaluate()",
		"$Guard/Brain.current_action()",
		"threat = 0.5 + 0.5 * sin(t * 0.8)",
	]) and passed
	passed = _check_scene("utility_ai_demo scene has Guard + Brain + Screen",
		"res://demo/showcase/utility_ai/utility_ai_demo.tscn", ["Guard", "Brain", "Screen"]) and passed

	# Chef Planner - the HTN Agent pack decomposing a compound task into an ordered plan.
	passed = _check_sheet("htn_agent_demo", "res://demo/showcase/htn_agent/htn_agent_demo.gd", [
		"class_name ChefPlannerDemo",
		"$Chef/Planner.add_compound(\"make_meal\")",
		"$Chef/Planner.add_method_condition(\"make_meal\", \"cook_it\", \"has_kitchen\", \"==\", true)",
		"$Chef/Planner.add_method_subtask(\"make_meal\", \"cook_it\", \"serve\")",
		"$Chef/Planner.request_plan()",
		"$Chef/Planner.has_plan()",
		"$Chef/Planner.mark_complete()",
		"$Chef/Planner.current_task()",
	]) and passed
	passed = _check_scene("htn_agent_demo scene has Chef + Planner + Screen",
		"res://demo/showcase/htn_agent/htn_agent_demo.tscn", ["Chef", "Planner", "Screen"]) and passed

	# Platformer-Shooter - the new Platformer + Weapon Kit packs combined.
	passed = _check_sheet("platformer_shooter", "res://demo/showcase/platformer_shooter/platformer_shooter.gd", [
		"$Player/PlatformerMovement.jump()",
		"$Player/PlatformerMovement.jump_released()",
		"$Player/PlatformerMovement.facing_direction()",
		"$Player/WeaponKit.can_fire()",
		"$Player/WeaponKit.fire()",
		"get_tree().get_nodes_in_group(\"shots\")",
		"score += 1",
	]) and passed
	passed = _check_scene("platformer_shooter scene has Player + Floor + Hud",
		"res://demo/showcase/platformer_shooter/platformer_shooter.tscn", ["Player", "Floor", "Hud"]) and passed
	passed = _check("shot + target sub-scenes exist",
		ResourceLoader.exists("res://demo/showcase/platformer_shooter/shot.tscn") and ResourceLoader.exists("res://demo/showcase/platformer_shooter/target.tscn"), true) and passed

	# Swarm - frame-spreading: a Budgeted For Each over a spawned crowd (the visible-sweep demo).
	passed = _check_sheet("swarm", "res://demo/showcase/swarm/swarm.gd", [
		"var __loop_cursor_",
		"Array(get_tree().get_nodes_in_group(\"swarm\"))",
		"load(\"res://demo/showcase/swarm/dot.tscn\").instantiate()",
		"dot.offset = Vector2(",
		"Color.from_hsv(",
	]) and passed
	passed = _check_scene("swarm scene has Info HUD", "res://demo/showcase/swarm/swarm.tscn", ["Info"]) and passed
	passed = _check("dot sub-scene exists", ResourceLoader.exists("res://demo/showcase/swarm/dot.tscn"), true) and passed

	# Family Arena - the Families trio: an Enemy Family (instances + a family ACE) driven by family-scoped
	# rules. The byte-identity check inside _check_sheet doubles as the @ace_family round-trip proof.
	passed = _check_sheet("enemy", "res://demo/showcase/family_arena/enemy.gd", [
		"## @ace_family(Enemy)",
		"class_name Enemy",
		"extends Sprite2D",
		"self.add_to_group(\"family_enemy\")",
		"func take_damage(amount: int)",
		"@export var health: int = 3",
	]) and passed
	passed = _check_sheet("family_arena", "res://demo/showcase/family_arena/family_arena.gd", [
		"class_name FamilyArena",
		"for enemy in get_tree().get_nodes_in_group(\"family_enemy\"):",
		"enemy.position.y += enemy.fall_speed * delta",
		"__e.take_damage(1)",
	]) and passed
	passed = _check_scene("family_arena scene has Info HUD", "res://demo/showcase/family_arena/family_arena.tscn", ["Info"]) and passed
	passed = _check("enemy sub-scene exists", ResourceLoader.exists("res://demo/showcase/family_arena/enemy.tscn"), true) and passed

	# Inspector Playground - every Tier 3 custom drawer + @export grouping across the new value types
	# (Vector2/Color/Texture2D/Curve). The byte-identity check inside _check_sheet doubles as the drawer +
	# grouping round-trip proof (open the .gd → recompile → byte-identical).
	passed = _check_sheet("inspector_playground", "res://demo/showcase/inspector_playground/inspector_playground.gd", [
		"class_name InspectorPlayground",
		"@export_group(\"Aim\")",
		"@export_custom(PROPERTY_HINT_NONE, \"eventsheet:vector_dial:120\") var aim_dir: Vector2",
		"@export_custom(PROPERTY_HINT_NONE, \"eventsheet:swatch_row\") var body_tint: Color",
		"@export_custom(PROPERTY_HINT_NONE, \"eventsheet:texture_preview\") var body_icon: Texture2D = null",
		"@export_subgroup(\"Tuning\")",
		"@export_custom(PROPERTY_HINT_NONE, \"eventsheet:curve_editor\") var stat_curve: Curve = null",
		"@export_custom(PROPERTY_HINT_NONE, \"eventsheet:progress_bar:0:100\") var stat_health: int = 80",
	]) and passed
	passed = _check_scene("inspector_playground scene has Body + Emblem + Info",
		"res://demo/showcase/inspector_playground/inspector_playground.tscn", ["Body", "Emblem", "Info"]) and passed

	# Discovery: the flagship is the one the plugin opens; the secondaries never compete.
	passed = _check("flagship is the discovered showcase",
		EventForgePlugin._find_showcase_scene(), "res://demo/showcase/carousel/showcase_carousel.tscn") and passed

	return passed


static func _check_sheet(label: String, path: String, required: Array) -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	var ok: bool = _check("%s opens as a sheet" % label, sheet is EventSheetResource, true)
	if sheet == null:
		return false
	var result: Dictionary = SheetCompiler.compile(sheet, "user://%s_showcase_test.gd" % label)
	ok = _check("%s compiles to GDScript" % label, bool(result.get("success", false)), true) and ok
	var output: String = str(result.get("output", ""))
	# The .gd IS the showcase sheet now (no .tres): opening it and recompiling must reproduce it exactly
	# (the lossless round-trip / GDScript<->event-sheet consistency gate, the same one audit_addons pins).
	ok = _check("%s recompiles to its shipped .gd byte-identically" % label, output == FileAccess.get_file_as_string(path), true) and ok
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
