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

	# Hierarchy Playground - the scene tree changed at run time, in the spellings the hierarchy
	# readings recognise. The tokens below ARE those spellings, so a reading that stops matching one
	# and a builder that starts writing a different one both land here.
	#
	# The RUNTIME behaviour was verified by a NON-headless harness (physics does not step in this
	# suite: run_tests.gd's _init runs before the main loop exists, so there is no scene tree to
	# reach). The recipe, and the numbers it produced, so anyone can repeat it:
	#   a temp SceneTree script instantiates hierarchy_playground.tscn under `root`, sets
	#   `current_scene` to it (the dismount hands the rider back to `get_tree().current_scene`, which
	#   a hand-parked scene has not set), awaits ~12 process+physics frames, then reads:
	#     squad_hp                     -> 200   (four soldiers, 40 each, one heal of +10 each)
	#     every crate's global y        -> 0.5   (parked on the ground the downward ray found)
	#     %HealthBar.rotation_degrees   -> (0, 0, 0) while the rider leans ~10 degrees (upright)
	#     %Rider.get_parent().name      -> Saddle after mount, HierarchyPlayground after dismount
	#     %Hat global scale             -> (1, 1, 1) after %Head is scaled to 2 (size flag honoured)
	# That last one is why `hat.top_level = true` is in the emitted equip: WITHOUT it the hat grew
	# with the head and the RemoteTransform changed nothing, which the harness caught and no static
	# check could have.
	passed = _check_sheet("hierarchy_playground", "res://demo/showcase/hierarchy_playground/hierarchy_playground.gd", [
		"class_name HierarchyPlayground",
		"rider.reparent($Horse/Saddle, false)",
		"rider.reparent(get_tree().current_scene)",
		"hat.reparent(%Head)",
		"hat.top_level = true",
		"var __follow_hat := RemoteTransform3D.new()",
		"__follow_hat.remote_path = __follow_hat.get_path_to(hat)",
		"__follow_hat.update_scale = false",
		"%HealthBar.top_level = true",
		"for unit in leader.get_children():",
		"if unit.is_in_group(\"soldier\"):",
		"unit.hp += 10",
		"$CameraPivot.rotation_degrees = Vector3(0.0, orbit_deg, 0.0)",
		"var __ground := get_world_3d().direct_space_state.intersect_ray(__down)",
	]) and passed
	passed = _check_sheet("hierarchy_soldier", "res://demo/showcase/hierarchy_playground/soldier.gd", [
		"class_name HierarchySoldier",
		"@export var hp: int = 40",
		"self.add_to_group(\"soldier\")",
	]) and passed
	passed = _check("hierarchy_playground bakes every per-row uid",
		FileAccess.get_file_as_string("res://demo/showcase/hierarchy_playground/hierarchy_playground.gd").contains("{uid}"), false) and passed
	passed = _check_scene("hierarchy_playground scene wires the horse, the rider, the squad and the crates",
		"res://demo/showcase/hierarchy_playground/hierarchy_playground.tscn",
		["Horse", "Saddle", "Rider", "Head", "HealthBar", "Hat", "Squad", "Soldier1", "Crates", "Crate1", "CameraPivot", "Readout"]) and passed

	# ── Mirror and Flip ─────────────────────────────────────────────────────────────────────────
	#
	# The RUNTIME behaviour was verified by a temp SceneTree harness (this suite has no main loop, so
	# nothing here can step a frame). The recipe, and the numbers it produced, so anyone can repeat it:
	#   a harness adds hero.tscn under `root`, connects `process_frame`, sets the pacing clock `t` and
	#   reads after two frames - `t = 1.0` (moving right) then `t = 3.0` (moving left):
	#     hero.scale.x                                    ->  1.0  then -1.0
	#     sign(Sword tip global x - Sword global x)       ->  1.0  then -1.0   (the ray turns)
	#     sign(Muzzle global x - Hero global x)           ->  1.0  then -1.0   (the spawn point turns)
	#     Plate.get_global_transform().x.x                ->  1.0  then  1.0   (the name plate does NOT)
	#   then mirror_and_flip.tscn for eight frames:
	#     $Panel.scale.x -> -1.0 with pivot_offset.x -> 150.0 (half its 300-wide box: mirrored IN PLACE)
	#     $Mirror.scale.x -> -1.0
	#     $Tiles.is_cell_flipped_h(Vector2i(2, 0)) -> true, and (1, 0) -> false (one tile, not the row)
	#     $Mirror/View/Twin yaw -> 0 degrees, then 180 after one Turn Around
	# That fourth number is the whole of the facing rule: the ray and the muzzle turn because they are children of
	# the object that mirrored, and the plate does not because Keep Upright re-negates it.
	passed = _check_sheet("mirror_hero", "res://demo/showcase/mirror_and_flip/hero.gd", [
		"class_name MirrorHero",
		"var velocity: Vector2 = Vector2(0.0, 0.0)",
		"if velocity.x != 0.0:",
		"scale.x = -1.0 if velocity.x < 0.0 else 1.0",
		"$Plate.scale.x = signf(scale.x)",
	]) and passed
	passed = _check_sheet("mirror_and_flip", "res://demo/showcase/mirror_and_flip/mirror_and_flip.gd", [
		"class_name MirrorAndFlip",
		"$Panel.pivot_offset.x = $Panel.size.x * 0.5",
		"$Panel.scale.x = -1.0 if mirror_ui else 1.0",
		"$Mirror.scale.x = -1.0 if mirror_view else 1.0",
		"$Tiles.set_cell(Vector2i(2, 0), $Tiles.get_cell_source_id(Vector2i(2, 0)), $Tiles.get_cell_atlas_coords(Vector2i(2, 0)), TileSetAtlasSource.TRANSFORM_FLIP_H if flip_tile else 0)",
		"$Mirror/View/Twin.rotate_y(PI)",
	]) and passed
	passed = _check("mirror_and_flip bakes every per-row uid",
		FileAccess.get_file_as_string("res://demo/showcase/mirror_and_flip/mirror_and_flip.gd").contains("{uid}"), false) and passed
	passed = _check_scene("the hero drags its ray, its muzzle, its dust and its name plate along",
		"res://demo/showcase/mirror_and_flip/hero.tscn",
		["Picture", "Face", "Sword", "Blade", "Muzzle", "MuzzleDot", "Dust", "Plate"]) and passed
	passed = _check_scene("the room holds a panel, a tile row, a mirrored view and a 3D twin",
		"res://demo/showcase/mirror_and_flip/mirror_and_flip.tscn",
		["Hero", "Tiles", "Panel", "PanelText", "Mirror", "View", "Twin", "TwinMesh", "Nose", "Eye", "Sun"]) and passed

	# ── the two skate parks ─────────────────────────────────────────────────────────────────────
	#
	# Both sheets are pinned on the pack CALLS rather than on any arithmetic, because that is the
	# claim: a skate park has no skating math in it. The physics was verified by a temp non-headless
	# harness (this suite has no main loop, so nothing here can step a frame), and the numbers it
	# produced, so anyone can repeat it:
	#   2D  the board lands on the slope at frame 22, x speed 0.00 -> 93.61 over the next 40 frames,
	#       carrying it from x 110.0 to x 153.7 (Roll With The Slope is the only thing pushing it);
	#       ollie(420) sets velocity.y to -420.0 and Is Airborne is true three frames later;
	#       is_near_rail is true 8 px off the line at 16 and false 52 px off it;
	#       start_grinding puts the board at (560.0, 552.0), the curve's own point;
	#       the chain reads 100, then 600 at x4, banks 600 and leaves 0 at x1;
	#       Set Needle builds the needle on first use, at x 163.0 of a 220-wide box for balance 0.5,
	#       moving to x 207.0 and turning the warning colour at 0.9;
	#       a bail hands the board to the Checkpoint pack, back to (110.0, 300.0), chain 0, banked 600.
	#   3D  ground speed 0.00 -> 2.90 m/s over 40 frames on the slope;
	#       ollie(6) sets velocity.y to 6.00 and Is Airborne is true three frames later;
	#       is_near_rail is true 0.3 m off the line at 0.8 and false 2.5 m off it;
	#       start_grinding puts the board at (3.50, -1.00, 0.00).
	passed = _check_sheet("skate_park", "res://demo/showcase/skate_park/skate_park.gd", [
		"class_name SkatePark",
		"$Skater/Skateboard.roll_with_slope()",
		"$Skater/Skateboard.push(40.0)",
		"$Skater/Skateboard.ollie(420.0)",
		"$Skater/Skateboard.is_near_rail($Rail, 16.0)",
		"$Skater/Skateboard.grind_along_rail(320.0, false)",
		"$Hud/HudKit.set_needle(\"BalanceMeter\", $Skater/Skateboard.balance(), 0.6)",
		"$Skater/Checkpoint.respawn()",
	]) and passed
	passed = _check_sheet("skate_park_3d", "res://demo/showcase/skate_park_3d/skate_park_3d.gd", [
		"class_name SkatePark3D",
		"$Skater/Skateboard.roll_with_slope()",
		"$Skater/Skateboard.align_board_to_surface()",
		"$Skater/Skateboard.launched_off_the_lip.connect(_on_launched)",
		"$Skater/Skateboard.is_near_rail($Rail, 0.8)",
		"$Skater/Skateboard.bank_chain()",
	]) and passed
	passed = _check("the skate parks bake every per-row uid",
		FileAccess.get_file_as_string("res://demo/showcase/skate_park/skate_park.gd").contains("{uid}")
			or FileAccess.get_file_as_string("res://demo/showcase/skate_park_3d/skate_park_3d.gd").contains("{uid}"),
		false) and passed
	passed = _check_scene("the park has a slope, a flat, a rail, a quarterpipe and a skater on a board",
		"res://demo/showcase/skate_park/skate_park.tscn",
		["Slope", "Ground", "Quarterpipe", "Rail", "RailMark", "Skater", "Skateboard", "Checkpoint",
			"Hud", "HudKit", "BalanceMeter"]) and passed
	passed = _check_scene("the 3D park has the same run on a surface, with a bank to launch off",
		"res://demo/showcase/skate_park_3d/skate_park_3d.tscn",
		["Slope", "Ground", "Bank", "Rail", "RailMark", "Skater", "Skateboard", "Board", "Camera",
			"Sun", "Overlay", "Hud"]) and passed
	# The rider survives being mounted only because it is addressed by its scene-unique name: the
	# moment it moves under the saddle, a $Rider path points at nothing.
	passed = _check("the rider, head, bar and hat keep their scene-unique names in the packed scene",
		FileAccess.get_file_as_string("res://demo/showcase/hierarchy_playground/hierarchy_playground.tscn").count("unique_name_in_owner = true"), 4) and passed
	# "every soldier among the children" matches nobody unless the group reached the packed scene,
	# and PackedScene.pack() saves PERSISTENT groups only.
	passed = _check("the squad keeps its group in the packed scene",
		FileAccess.get_file_as_string("res://demo/showcase/hierarchy_playground/hierarchy_playground.tscn").contains("groups=[\"soldier\"]"), true) and passed

	# The traversal courses: the Traversal Kit (2D) and its 3D twin, one station per move. The
	# RUNTIME behaviour was verified by a NON-headless harness (physics does not step in this suite:
	# run_tests.gd's _init runs before the main loop exists, so there is no scene tree to reach).
	# The recipe, and the numbers it produced, so anyone can repeat it:
	#   a temp SceneTree script instantiates traversal_course.tscn under `root`, connects
	#   Climber/Traversal.on_climbed, steps 200 PHYSICS frames at 60 Hz, then reads:
	#     Climber hangs at frame          -> 28    (it falls beside the tower with no drive at all)
	#     Climber y while hanging         -> 431.6 (the tower's lip is y 420 - it is holding it)
	#     On Climbed fires                -> 1     (the 0.4 s mantle put it on top of the tower)
	#     Jumper peak |velocity.x|        -> 275   (its walking top speed is 200: the wall PUSHED it)
	#     Jumper x range                  -> 626.1 .. 821.9 (it leaves both shaft walls, then homes back)
	#     at frame 60: Diver y / Stone y  -> 517.7 / 566.0 (the stone has landed; the swimmer is
	#                                        still 48 px higher, which is the whole point of Swim)
	#   then the same for traversal_course_3d.tscn, 200 physics frames:
	#     Climber hangs at frame          -> 31    at y 2.43 (the tower top is y 3.0)
	#     Jumper z range                  -> -1.05 .. 1.05 (it crosses the shaft BOTH ways - the push
	#                                        follows the wall's own normal, not a hard-coded side)
	#     at frame 90: Diver y / Stone y  -> 2.42 / 0.80 (Float holds the swimmer a metre under the
	#                                        surface at y 3.5 while the stone lies on the ground)
	#     Vaulter reached x               -> 6.99  (it vaulted the block at x 3.5 .. 4.5)
	#     Ladder Bot reached y            -> 4.48  (it climbed the marked Area3D from y 0.9)
	# The margins are what matter here, not the decimals: a grab that never happens, a wall jump that
	# pushes into the wall, or a swimmer that falls like a stone would each move one of these by more
	# than the whole number.
	passed = _check_sheet("traversal_course", "res://demo/showcase/traversal_course/traversal_course.gd", [
		"class_name TraversalCourseDemo",
		"$Player/Traversal.is_at_a_ledge() and $Player/Movement.is_falling()",
		"$Player/Traversal.grab_ledge()",
		"$Player/Traversal.climb_up(0.3)",
		"$Player/Traversal.drop()",
		"$Player/Traversal.slide_down_wall(60.0)",
		"$Player/Traversal.climb_ladder(120.0)",
		"$Player/Traversal.vault_over(0.4)",
		"$Player/Traversal.swim(20.0, 10.0)",
		"$Jumper/Traversal.wall_jump(300.0, 500.0)",
		"$Jumper/Movement.ai_move_axis = signf($Jumper.velocity.x)",
	]) and passed
	passed = _check("traversal_course bakes every per-row uid",
		FileAccess.get_file_as_string("res://demo/showcase/traversal_course/traversal_course.gd").contains("{uid}"), false) and passed
	passed = _check_scene("traversal_course scene has every station and every actor",
		"res://demo/showcase/traversal_course/traversal_course.tscn",
		["Ground", "LedgeTower", "VaultBlock", "WallLeft", "WallRight", "Platform", "Ladder", "Pool",
			"Player", "Climber", "Jumper", "Diver", "Stone", "Readout"]) and passed
	# The kit finds a ladder and a pool by GROUP, and PackedScene.pack() saves persistent groups
	# only: without the persistent flag both volumes reach the player as ordinary Areas and every
	# water and ladder row silently never fires.
	passed = _check("the ladder and the pool keep their groups in the packed scene",
		FileAccess.get_file_as_string("res://demo/showcase/traversal_course/traversal_course.tscn").count("groups=["), 2) and passed
	passed = _check_sheet("traversal_course_3d", "res://demo/showcase/traversal_course_3d/traversal_course_3d.gd", [
		"class_name TraversalCourse3DDemo",
		"$Climber/Traversal.grab_ledge()",
		"$Climber/Traversal.climb_up(0.5)",
		"$Jumper/Traversal.slide_down_wall(1.5)",
		"$Jumper/Traversal.wall_jump(6.0, 4.5)",
		"$LadderBot/Traversal.climb_ladder(2.5)",
		"$Vaulter/Traversal.vault_over(0.4)",
		"$Diver/Traversal.swim(20.0, 10.0)",
		"$Diver/Traversal.float_in_water(12.0)",
		"$Climber.move_and_slide()",
	]) and passed
	passed = _check_scene("traversal_course_3d scene has every station and every actor",
		"res://demo/showcase/traversal_course_3d/traversal_course_3d.tscn",
		["Ground", "LedgeTower", "WallLeft", "WallRight", "VaultBlock", "LadderWall", "Ladder",
			"Pool", "Climber", "Jumper", "LadderBot", "Vaulter", "Diver", "Stone", "Readout"]) and passed
	# Combo Fighter: three combos driving three animations, a cancel window, a
	# buffered punch, and a hit frame the uppercut's OWN animation calls. Every shape in it is one
	# the reading recognises, which is why the tokens below are spelled exactly as the readings
	# expect them: a builder that starts writing a different spelling lands here first.
	#
	# The RUNTIME behaviour was verified by a NON-headless harness, for the same reason the room
	# above needed one - this suite has no scene tree and no physics. What it saw:
	#     press("punch") x2 then press("kick")  -> current_animation == "uppercut", combo emptied
	#     the method track at 0.35 s            -> hits == 1 (the animation really called the sheet)
	#     the hit frame's Hitstop row           -> time_scale left 1.0 and was back at 1.0 after
	#     seek(0.45) then try_cancel()          -> true  (inside the 0.3 - 0.6 window)
	#     seek(0.75) then try_cancel()          -> false (outside it)
	passed = _check_sheet("combo_fighter", "res://demo/showcase/combo_fighter/combo_fighter.gd", [
		"class_name ComboFighter",
		"combo.append(button)",
		"combo_timer = 0.5",
		"match \",\".join(combo):",
		"\t\t\t$AnimationPlayer.play(\"uppercut\")",
		"punch_input = Time.get_ticks_msec() / 1000.0 + 0.1",
		"if (Time.get_ticks_msec() / 1000.0 <= punch_input):",
		"punch_input = Time.get_ticks_msec() / 1000.0 - 1.0",
		"$AnimationPlayer.current_animation == \"uppercut\" and $AnimationPlayer.current_animation_position > 0.3",
		"func _on_hit_frame() -> void:",
		"await get_tree().create_timer(0.05, true, false, true).timeout",
	]) and passed
	passed = _check("combo_fighter bakes every per-row uid",
		FileAccess.get_file_as_string("res://demo/showcase/combo_fighter/combo_fighter.gd").contains("{uid}"), false) and passed
	passed = _check_scene("combo_fighter scene wires the body, the player and the two labels",
		"res://demo/showcase/combo_fighter/combo_fighter.tscn",
		["Body", "AnimationPlayer", "Info", "Moves"]) and passed
	# The animation side of the contract: the clip is NAMED in the file (AnimationLibrary keys are
	# not written as resource names on their own), and its method track calls the function the sheet
	# defines. Without the name, nothing reading the scene could say which clip the hit frame is on.
	passed = _check("the uppercut clip is named in the scene and calls the hit frame",
		FileAccess.get_file_as_string("res://demo/showcase/combo_fighter/combo_fighter.tscn")
			.contains("resource_name = \"uppercut\""), true) and passed
	passed = _check("the method track names the function the sheet defines",
		FileAccess.get_file_as_string("res://demo/showcase/combo_fighter/combo_fighter.tscn")
			.contains("\"method\": &\"_on_hit_frame\""), true) and passed

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

	# Boomer Level - the shooter kit end to end, as four sheets: the level, the door, a grunt and the
	# pickup. The tokens below are the SPELLINGS the keycard, feel and enemy readings recognise, so a
	# reading that stops matching one and a builder that starts writing a different one both land here.
	passed = _check_sheet("boomer_level", "res://demo/showcase/boomer_level/boomer_level.gd", [
		"class_name BoomerLevel",
		"\tkeys.append(\"red_key\")",
		"\tvar __door_level = $RedDoor",
		"\tif str(__door_level.needs_key) in keys:",
		"\t\t__door_level.locked_door_tried(str(__door_level.needs_key))",
		"\t$Player/FPSController.bob_with_movement($Player/Head/Weapon)",
		"\t$Player/FPSController.sway_with_mouse($Player/Head/Weapon)",
		"\tif not \"SecretRoom\" in secrets_found:",
		"\tkills += 1",
	]) and passed
	passed = _check_sheet("boomer_door", "res://demo/showcase/boomer_level/keycard_door.gd", [
		"class_name BoomerLevelDoor",
		"func locked_door_tried(key: Variant) -> void:",
		"func open_door() -> void:",
		"\tif not door_open:",
	]) and passed
	passed = _check_sheet("boomer_grunt", "res://demo/showcase/boomer_level/grunt.gd", [
		"class_name BoomerLevelGrunt",
		"func alerted(who: Variant) -> void:",
		"\tif who.is_in_group(\"enemies\"):",
		"\t\tif __alerted_hurt != self and __alerted_hurt.global_position.distance_to(global_position) < shout_radius:",
	]) and passed
	passed = _check_sheet("boomer_pickup", "res://demo/showcase/boomer_level/health_pickup.gd", [
		"class_name BoomerLevelPickup",
		"\tawait get_tree().create_timer(respawn_seconds).timeout",
		"\tset_deferred(\"monitoring\", true)",
	]) and passed
	passed = _check("boomer_level bakes every per-row uid",
		FileAccess.get_file_as_string("res://demo/showcase/boomer_level/boomer_level.gd").contains("{uid}"), false) and passed
	passed = _check_scene("boomer_level scene wires the player rig, the card, the door and the grunts",
		"res://demo/showcase/boomer_level/boomer_level.tscn",
		["Player", "FPSController", "Head", "Weapon", "RedCard", "RedDoor", "DoorTrigger",
			"Grunt1", "Grunt2", "HealthPickup", "SecretRoom", "Exit", "Tally"]) and passed
	# The alert row walks a GROUP, so a group that did not survive packing makes the whole item a
	# silent no-op - which is exactly what an unpersisted add_to_group produces.
	passed = _check("both grunts keep their group in the packed scene",
		FileAccess.get_file_as_string("res://demo/showcase/boomer_level/boomer_level.tscn").count("groups=[\"enemies\"]"),
		2) and passed

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
