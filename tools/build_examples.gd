# Showcase/example builder (release ritual): regenerates demo/showcase/ - a flagship
# "Carousel of Juice" plus two deeper demos (Starfall arcade, Quest FSM). Each is built
# programmatically via the public EventSheet API, compiled to plain GDScript, and packed
# into a playable scene. Run:
#   godot --headless --path . --script tools/build_examples.gd
# The flagship is the ONLY demo/showcase/showcase_*.tscn, so EventForgePlugin._find_showcase_scene
# discovers it deterministically; the secondaries use un-versioned names so they never go stale.
@tool
extends SceneTree

const PackLib := preload("res://tools/pack_builders/_lib.gd")


func _init() -> void:
	var all_ok: bool = true
	all_ok = _build_carousel() and all_ok
	all_ok = _build_starfall() and all_ok
	all_ok = _build_quest_fsm() and all_ok
	all_ok = _build_platformer_shooter() and all_ok
	all_ok = _build_swarm() and all_ok
	all_ok = _build_family_arena() and all_ok
	all_ok = _build_inspector_playground() and all_ok
	all_ok = _build_enemy_stats() and all_ok
	all_ok = _build_menu_starter() and all_ok
	all_ok = _build_utility_ai() and all_ok
	all_ok = _build_htn_agent() and all_ok
	all_ok = _build_uhtn_planning() and all_ok
	all_ok = _build_fps_arena() and all_ok
	all_ok = _build_input_rebind() and all_ok
	all_ok = _build_path_chase() and all_ok
	all_ok = _build_draw_lab() and all_ok
	all_ok = _build_raycast_lab() and all_ok
	all_ok = _build_raycast_lab_3d() and all_ok
	all_ok = _build_hierarchy_playground() and all_ok
	all_ok = _build_mirror_and_flip() and all_ok
	all_ok = _build_boomer_level() and all_ok
	all_ok = _build_pin_modes() and all_ok
	all_ok = _build_skill_tree() and all_ok
	all_ok = _build_skate_park() and all_ok
	all_ok = _build_skate_park_3d() and all_ok
	all_ok = _build_combo_fighter() and all_ok
	print("[build_examples] ALL_OK=", all_ok)
	quit(0 if all_ok else 1)

# ── shared helpers ───────────────────────────────────────────────────────────


## A 48x48 soft-cornered white sprite texture, built in-tool so no example depends on
## res://icon.svg existing.
func _make_texture() -> ImageTexture:
	var img: Image = Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(48):
		for x in range(48):
			var dx: float = absf(x - 23.5)
			var dy: float = absf(y - 23.5)
			# rounded square mask
			if dx <= 20.0 and dy <= 20.0:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
			elif dx <= 23.0 and dy <= 23.0:
				img.set_pixel(x, y, Color(1, 1, 1, 0.55))
	return ImageTexture.create_from_image(img)


## The SHIPPED codegen template for a builtin ACE, with its per-row `{uid}` baked to `uid`.
##
## Reading the LIVE descriptor beats pasting a copy into a builder: the showcase then demonstrates the
## vocabulary exactly as published, and cannot drift from it or quote it wrong. Baking has to happen
## here because the dock bakes `{uid}` at APPLY time and the compiler never does - an unbaked `{uid}`
## would sail straight into the emitted GDScript as a syntax error.
func _ace_template(ace_id: String, uid: String = "") -> String:
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		if str(descriptor.ace_id) == ace_id:
			return str(descriptor.codegen_template).replace("{uid}", uid)
	push_error("[build_examples] no builtin ACE named %s" % ace_id)
	return ""


## The LINE a shipped ACE writes, with its parameters already filled in - the same substitution the
## compiler runs, so a function body written with this and a row dropped from the picker are the same
## bytes. Function bodies take raw code rather than rows (a function is a body, not an event lane),
## and `_compile`'s reverse lift turns the result back into rows where it re-emits byte for byte.
func _ace_line(ace_id: String, uid: String, params: Dictionary) -> String:
	return ActionCodegen._apply_template(_ace_template(ace_id, uid), params)


func _condition(provider: String, ace_id: String, template: String, params: Dictionary,
		member_decl: String = "", prelude: String = "", on_true: String = "") -> ACECondition:
	var c: ACECondition = ACECondition.new()
	c.provider_id = provider
	c.ace_id = ace_id
	c.codegen_template = template
	c.params = params
	c.member_declaration = member_decl
	c.codegen_prelude = prelude
	c.codegen_on_true = on_true
	return c


func _action(provider: String, ace_id: String, template: String, params: Dictionary) -> ACEAction:
	var a: ACEAction = ACEAction.new()
	a.provider_id = provider
	a.ace_id = ace_id
	a.codegen_template = template
	a.params = params
	return a


func _raw(code: String) -> RawCodeRow:
	var r: RawCodeRow = RawCodeRow.new()
	r.code = code
	return r


func _every(uid: String, seconds: String) -> ACECondition:
	var member: String = "var __every_%s: float = 0.0" % uid
	return _condition(
		"Core", "EveryXSeconds",
		"__every_%s >= maxf(%s, 0.001)" % [uid, seconds],
		{"seconds": seconds},
		member,
		"__every_%s += delta" % uid,
		"__every_%s = fmod(__every_%s, maxf(%s, 0.001))" % [uid, uid, seconds]
	)


func _attach_behavior(parent: Node, node_name: String, path: String, root: Node, props: Dictionary = {}) -> Node:
	var node: Node = (load(path) as GDScript).new()
	node.name = node_name
	parent.add_child(node)
	node.owner = root
	for key: String in props.keys():
		node.set(key, props[key])
	return node


## Compile sheet straight to a banner-less .gd (no .tres) - the .gd IS the showcase sheet, hand-editable.
func _compile(sheet: EventSheetResource, _tres_path: String, gd_path: String) -> bool:
	# Code-free by default: reverse-lift each function's RawCode body into ACE rows where it recompiles
	# byte-identically (same build-time pass the behaviour packs use). The showcase ships identical
	# GDScript but reads as events.
	EventSheetACELifter.lift_function_bodies(sheet)
	# Same for event bodies (an OnProcess tick block -> if/else condition rows + action rows),
	# folded into each event's sub_events, per-event byte-gated.
	EventSheetACELifter.lift_event_bodies(sheet)
	# @ace_trigger signal blocks -> SignalRow trigger rows (relocated to the signal prelude).
	EventSheetACELifter.lift_signal_declarations(sheet, false)
	# Class-level helper `func` blocks -> EventFunction rows (exposed ones publish as ACEs).
	EventSheetACELifter.lift_function_declarations(sheet, false)
	# Deterministic row uids so rebuilding an unchanged showcase is byte-identical (no diff
	# churn) - same fix the behavior-pack builder uses.
	EventSheets.stabilize_row_uids(sheet)
	# .gd-only: the showcase .gd IS the sheet (no .tres companion), banner-less so it's hand-editable.
	# Normal synthesizing compile - do NOT set external_source_path (that path is only for opening an
	# existing .gd). Round-trip is covered by the showcase tests + import_external.
	# Each showcase lives in its own demo/showcase/<name>/ folder - create it on demand so a
	# fresh checkout (or a brand-new showcase) regenerates without manual mkdir.
	DirAccess.make_dir_recursive_absolute(gd_path.get_base_dir())
	var result: Dictionary = SheetCompiler.compile(sheet, gd_path, true)
	var success: bool = bool(result.get("success", false))
	print("[build_examples] %s compile=%s warnings=%s errors=%s" % [
		gd_path.get_file(), str(success), str(result.get("warnings", [])), str(result.get("errors", []))])
	return success


func _save_scene(root: Node, path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var packed: PackedScene = PackedScene.new()
	var pack_err: Error = packed.pack(root)
	var save_err: Error = ResourceSaver.save(packed, path)
	# Godot stamps every node with a random `unique_id=NNNN` at pack time (editor scene-merge
	# metadata, unused by this plugin and by scene loading). Left in, it turns every regeneration
	# into a spurious diff and defeats reproducibility. Strip it so a rebuild is byte-identical -
	# the scene still loads and instantiates identically without it (verified). It is the ONLY
	# non-deterministic token these scenes emit; ext/sub-resource ids are already stable.
	if save_err == OK:
		save_err = _strip_scene_unique_ids(path)
	print("[build_examples] %s pack=%d save=%d" % [path.get_file(), pack_err, save_err])
	return pack_err == OK and save_err == OK


## Removes the non-deterministic ` unique_id=NNNN` node tokens ResourceSaver stamps into a .tscn so
## regenerating a showcase scene is byte-stable. The pattern only matches the bare-digit node token,
## never the quoted `id="1_abc"` ext/sub-resource ids. Returns OK, or the file open error.
func _strip_scene_unique_ids(path: String) -> Error:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return FileAccess.get_open_error()
	var unique_id_token: RegEx = RegEx.new()
	unique_id_token.compile(" unique_id=\\d+")
	var stripped: String = unique_id_token.sub(text, "", true)
	if stripped == text:
		return OK
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(stripped)
	file.close()
	return OK

# ── 1. Carousel of Juice (flagship) ─────────────────────────────────────────

const SPRING := "res://eventsheet_addons/spring/spring_behavior.gd"
const TWEEN := "res://eventsheet_addons/tween/tween_behavior.gd"
const SINE := "res://eventsheet_addons/sine/sine_behavior.gd"
const FLASH := "res://eventsheet_addons/flash/flash_behavior.gd"
const UTILITY_AI := "res://eventsheet_addons/utility_ai/utility_ai_addon.gd"
const HTN_AGENT := "res://eventsheet_addons/htn_agent/htn_agent_behavior.gd"
const UHTN_PLANNER := "res://eventsheet_addons/uhtn_planning/uhtn_planning_behavior.gd"
const UHTN_RESOURCE := "res://eventsheet_addons/uhtn_plan_resource/uhtn_plan_resource.gd"


func _build_carousel() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "CarouselOfJuice"
	sheet.emit_live_values = false
	sheet.variables = {
		"beat": {"type": "int", "default": 0, "exported": true,
			"attributes": {"tooltip": "Beats elapsed.", "range": {"min": "0", "max": "9999", "step": "1"}}},
		"intensity": {"type": "float", "default": 1.4, "exported": true,
			"attributes": {"tooltip": "Spring kick strength.", "range": {"min": "1", "max": "3", "step": "0.05"}, "clamp": true}},
		"party_on": {"type": "bool", "default": true, "exported": true,
			"attributes": {"tooltip": "Is the Juice group running."}}
	}

	var about: CommentRow = CommentRow.new()
	about.text = "[b]Carousel of Juice[/b] - 8 tiles sine-sway and spring-pop on the beat (one reused juice_tile function). A runtime-toggleable Juice group plus an if/elif/else keypress chain re-skin the board: [b]ui_accept[/b] starts the party, [b]ui_cancel[/b] calms it. Watch beat/intensity stream in Live Values."
	sheet.events.append(about)

	# Reused function: juice one tile by index.
	var fn: EventFunction = EventFunction.new()
	fn.function_name = "juice_tile"
	fn.enabled = true
	var p_index: ACEParam = ACEParam.new(); p_index.id = "index"; p_index.type_name = "int"; p_index.type = TYPE_INT
	var p_kick: ACEParam = ACEParam.new(); p_kick.id = "kick"; p_kick.type_name = "float"; p_kick.type = TYPE_FLOAT
	fn.params = [p_index, p_kick]
	fn.events = [_raw(
		"var t: Node2D = $Tiles.get_child(index % $Tiles.get_child_count())\n" +
		"t.get_node(\"SpringBehavior\").add_impulse(\"__scale\", kick)\n" +
		"t.get_node(\"SpringBehavior\").spring_host_scale(1.0)\n" +
		"t.get_node(\"TweenBehavior\").tween_rotation(t.rotation_degrees + 90.0, 0.5)")]
	sheet.functions.append(fn)

	# Runtime-toggleable Juice group.
	var juice: EventGroup = EventGroup.new()
	juice.group_name = "Juice"
	juice.runtime_toggleable = true
	juice.custom_color = Color(0.55, 0.4, 0.85, 1.0)

	var beat_row: EventRow = EventRow.new()
	beat_row.trigger_provider_id = "Core"
	beat_row.trigger_id = "OnProcess"
	beat_row.conditions.append(_every("beat_caro", "0.5"))
	beat_row.actions.append(_action("Core", "AddVar", "{var_name} += {amount}", {"var_name": "beat", "amount": "1"}))
	beat_row.actions.append(_action("Core", "CallFunction", "{function_name}({args})", {"function_name": "juice_tile", "args": "beat, intensity * 5.0"}))
	juice.events.append(beat_row)

	var spin_row: EventRow = EventRow.new()
	spin_row.trigger_provider_id = "Core"
	spin_row.trigger_id = "OnProcess"
	spin_row.conditions.append(_every("spin_caro", "2.0"))
	spin_row.actions.append(_action("TweenBehavior", "method:tween_rotation", "{target}.tween_rotation({degrees}, {duration})", {"target": "$TweenBehavior", "degrees": "rotation_degrees + 360.0", "duration": "1.8"}))
	spin_row.actions.append(_action("FlashBehavior", "method:flash", "{target}.flash({seconds})", {"target": "$FlashBehavior", "seconds": "0.25"}))
	juice.events.append(spin_row)
	sheet.events.append(juice)

	# if / elif / else keypress chain (else_mode).
	var start_row: EventRow = EventRow.new()
	start_row.trigger_provider_id = "Core"
	start_row.trigger_id = "OnProcess"
	start_row.conditions.append(_condition("Core", "IsActionJustPressed", "Input.is_action_just_pressed(&{action})", {"action": "\"ui_accept\""}))
	start_row.actions.append(_action("Core", "SetVar", "{var_name} = {value}", {"var_name": "party_on", "value": "true"}))
	start_row.actions.append(_action("Core", "SetGroupActive", "set(\"__group_\" + {group} + \"_active\", {active})", {"group": "\"juice\"", "active": "true"}))
	start_row.actions.append(_action("SpringBehavior", "method:add_impulse", "{target}.add_impulse({spring_name}, {amount})", {"target": "$Hero/SpringBehavior", "spring_name": "\"__scale\"", "amount": "intensity * 6.0"}))
	start_row.actions.append(_action("FlashBehavior", "method:flash", "{target}.flash({seconds})", {"target": "$Hero/FlashBehavior", "seconds": "0.4"}))
	sheet.events.append(start_row)

	var calm_row: EventRow = EventRow.new()
	calm_row.trigger_provider_id = "Core"
	calm_row.trigger_id = "OnProcess"
	calm_row.else_mode = EventRow.ElseMode.ELIF
	calm_row.conditions.append(_condition("Core", "IsActionJustPressed", "Input.is_action_just_pressed(&{action})", {"action": "\"ui_cancel\""}))
	calm_row.actions.append(_action("Core", "SetVar", "{var_name} = {value}", {"var_name": "party_on", "value": "false"}))
	calm_row.actions.append(_action("Core", "SetGroupActive", "set(\"__group_\" + {group} + \"_active\", {active})", {"group": "\"juice\"", "active": "false"}))
	calm_row.actions.append(_action("TweenBehavior", "method:tween_rotation", "{target}.tween_rotation({degrees}, {duration})", {"target": "$Hero/TweenBehavior", "degrees": "0.0", "duration": "0.4"}))
	sheet.events.append(calm_row)

	var idle_row: EventRow = EventRow.new()
	idle_row.trigger_provider_id = "Core"
	idle_row.trigger_id = "OnProcess"
	idle_row.else_mode = EventRow.ElseMode.ELSE
	idle_row.actions.append(_action("SpringBehavior", "method:spring_host_scale", "{on_node}.spring_host_scale({target})", {"on_node": "$Hero/SpringBehavior", "target": "1.0 + sin(Time.get_ticks_msec() / 1000.0) * 0.04"}))
	sheet.events.append(idle_row)

	var seed_row: EventRow = EventRow.new()
	seed_row.trigger_provider_id = "Core"
	seed_row.trigger_id = "OnReady"
	seed_row.actions.append(_raw("for c: Node in $Tiles.get_children():\n\tc.get_node(\"SineBehavior\").active = true"))
	sheet.events.append(seed_row)

	if not _compile(sheet, "res://demo/showcase/carousel/showcase_carousel.tres", "res://demo/showcase/carousel/showcase_carousel.gd"):
		return false

	# Scene
	var tex: ImageTexture = _make_texture()
	var root: Node2D = Node2D.new()
	root.name = "Carousel"
	root.set_script(load("res://demo/showcase/carousel/showcase_carousel.gd"))
	# root-level behaviors for the bare $TweenBehavior / $FlashBehavior board calls
	# (SpringBehavior too, so the showcase wires the canonical Spring + Tween pair).
	_attach_behavior(root, "SpringBehavior", SPRING, root)
	_attach_behavior(root, "TweenBehavior", TWEEN, root)
	_attach_behavior(root, "FlashBehavior", FLASH, root)
	# Hero
	var hero: Sprite2D = Sprite2D.new()
	hero.name = "Hero"
	hero.texture = tex
	hero.position = Vector2(576, 324)
	hero.scale = Vector2(1.6, 1.6)
	hero.modulate = Color(1, 1, 1, 1)
	root.add_child(hero)
	hero.owner = root
	_attach_behavior(hero, "SpringBehavior", SPRING, root)
	_attach_behavior(hero, "TweenBehavior", TWEEN, root)
	_attach_behavior(hero, "FlashBehavior", FLASH, root)
	# Tiles ring
	var tiles: Node2D = Node2D.new()
	tiles.name = "Tiles"
	root.add_child(tiles)
	tiles.owner = root
	for i in range(8):
		var ang: float = float(i) / 8.0 * TAU
		var tile: Sprite2D = Sprite2D.new()
		tile.name = "Tile%d" % i
		tile.texture = tex
		tile.position = Vector2(576, 324) + Vector2(cos(ang), sin(ang)) * 220.0
		tile.modulate = Color.from_hsv(float(i) / 8.0, 0.85, 1.0)
		tiles.add_child(tile)
		tile.owner = root
		_attach_behavior(tile, "SineBehavior", SINE, root, {"magnitude": 18.0, "period": 1.6, "movement": "vertical", "active": true})
		_attach_behavior(tile, "SpringBehavior", SPRING, root)
		_attach_behavior(tile, "TweenBehavior", TWEEN, root)

	return _save_scene(root, "res://demo/showcase/carousel/showcase_carousel.tscn")

# ── 2. Starfall (arcade mini-game) ───────────────────────────────────────────

const BULLET := "res://eventsheet_addons/bullet/bullet_behavior.gd"
const PLATFORMER := "res://eventsheet_addons/platformer_movement/platformer_movement_behavior.gd"
const WEAPON_KIT := "res://eventsheet_addons/weapon_kit/weapon_kit_behavior.gd"


func _build_starfall() -> bool:
	# Star sub-scene (group-tagged falling sprite, BulletBehavior provides the fall).
	var tex: ImageTexture = _make_texture()
	var star: Sprite2D = Sprite2D.new()
	star.name = "Star"
	star.texture = tex
	star.scale = Vector2(0.3, 0.3)
	star.modulate = Color(1.0, 0.86, 0.3, 1.0)
	star.add_to_group("stars", true)
	_attach_behavior(star, "BulletBehavior", BULLET, star, {"speed": 150.0, "align_rotation": false})
	if not _save_scene(star, "res://demo/showcase/starfall/star.tscn"):
		return false

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "Starfall"
	sheet.emit_live_values = false

	var about: CommentRow = CommentRow.new()
	about.text = "[b]Starfall[/b] - a complete restartable arcade game authored as events: move the ship (ui_left/ui_right) to catch falling stars. Shows an enum+match state machine (PLAYING/GAME_OVER), a group pick-filter that scores & culls stars, an Every-2s spawner, and if/elif input branches. Miss 3 and it's GAME OVER - press ui_accept to restart."
	sheet.events.append(about)

	var state_enum: EnumRow = EnumRow.new()
	state_enum.enum_name = "State"
	state_enum.members = PackedStringArray(["PLAYING", "GAME_OVER"])
	sheet.events.append(state_enum)

	sheet.variables = {
		"score": {"type": "int", "default": 0, "exported": true,
			"attributes": {"tooltip": "Stars caught.", "range": {"min": "0", "max": "999", "step": "1"}}},
		"lives": {"type": "int", "default": 3, "exported": true,
			"attributes": {"tooltip": "Misses remaining."}},
		"state": {"type": "int", "default": 0, "exported": true,
			"attributes": {"tooltip": "0=PLAYING, 1=GAME_OVER."}},
		"ship_speed": {"type": "float", "default": 320.0, "exported": true,
			"attributes": {"tooltip": "Ship move speed (px/s)."}}
	}

	# Place the ship + a clamp helper.
	var place: EventRow = EventRow.new()
	place.trigger_provider_id = "Core"; place.trigger_id = "OnReady"
	place.actions.append(_action("Core", "SetProperty", "{target}.{property} = {value}", {"target": "$Ship", "property": "position", "value": "Vector2(576, 590)"}))
	sheet.events.append(place)

	# FSM tick (enum + match), restart on ui_accept when GAME_OVER.
	var fsm: EventRow = EventRow.new()
	fsm.trigger_provider_id = "Core"; fsm.trigger_id = "OnPhysicsProcess"
	var fsm_match: MatchRow = MatchRow.new()
	fsm_match.match_expression = "state"
	fsm_match.branches_text = "State.PLAYING:\n\tpass\nState.GAME_OVER:\n\tif Input.is_action_just_pressed(&\"ui_accept\"):\n\t\tscore = 0\n\t\tlives = 3\n\t\tstate = State.PLAYING\n\t\tfor s: Node in get_tree().get_nodes_in_group(\"stars\"):\n\t\t\ts.queue_free()\n_:\n\tpass"
	fsm.actions.append(fsm_match)
	sheet.events.append(fsm)

	# Move left (if) - whole-Vector2 assign avoids the value-type-copy pitfall.
	var move_left: EventRow = EventRow.new()
	move_left.trigger_provider_id = "Core"; move_left.trigger_id = "OnPhysicsProcess"
	move_left.conditions.append(_condition("Core", "CompareVar", "{var_name} {op} {value}", {"var_name": "state", "op": "==", "value": "State.PLAYING"}))
	move_left.conditions.append(_condition("Core", "IsActionPressed", "Input.is_action_pressed(&{action})", {"action": "\"ui_left\""}))
	move_left.actions.append(_raw("$Ship.position += Vector2(-ship_speed * delta, 0.0)"))
	sheet.events.append(move_left)

	# Move right (elif)
	var move_right: EventRow = EventRow.new()
	move_right.trigger_provider_id = "Core"; move_right.trigger_id = "OnPhysicsProcess"
	move_right.else_mode = EventRow.ElseMode.ELIF
	move_right.conditions.append(_condition("Core", "CompareVar", "{var_name} {op} {value}", {"var_name": "state", "op": "==", "value": "State.PLAYING"}))
	move_right.conditions.append(_condition("Core", "IsActionPressed", "Input.is_action_pressed(&{action})", {"action": "\"ui_right\""}))
	move_right.actions.append(_raw("$Ship.position += Vector2(ship_speed * delta, 0.0)"))
	sheet.events.append(move_right)

	# Keep the ship on-screen.
	var clamp_row: EventRow = EventRow.new()
	clamp_row.trigger_provider_id = "Core"; clamp_row.trigger_id = "OnPhysicsProcess"
	clamp_row.actions.append(_raw("$Ship.position = Vector2(clampf($Ship.position.x, 40.0, 1112.0), $Ship.position.y)"))
	sheet.events.append(clamp_row)

	# Spawn a star every 2s while playing.
	var spawn: EventRow = EventRow.new()
	spawn.trigger_provider_id = "Core"; spawn.trigger_id = "OnPhysicsProcess"
	spawn.conditions.append(_condition("Core", "CompareVar", "{var_name} {op} {value}", {"var_name": "state", "op": "==", "value": "State.PLAYING"}))
	spawn.conditions.append(_every("spawn_sf", "2.0"))
	spawn.actions.append(_action("Core", "SpawnSceneAt",
		"var __spawn_star = load(\"res://demo/showcase/starfall/star.tscn\").instantiate()\n__spawn_star.position = Vector2(randf_range(60.0, 1100.0), -20.0)\n__spawn_star.rotation_degrees = 90.0\nadd_child(__spawn_star)", {}))
	sheet.events.append(spawn)

	# Score / cull via a GROUP pick-filter (for-each star past the catch line).
	var collect: EventRow = EventRow.new()
	collect.trigger_provider_id = "Core"; collect.trigger_id = "OnPhysicsProcess"
	collect.conditions.append(_condition("Core", "CompareVar", "{var_name} {op} {value}", {"var_name": "state", "op": "==", "value": "State.PLAYING"}))
	var pf: PickFilter = PickFilter.new()
	pf.enabled = true
	pf.collection_kind = PickFilter.CollectionKind.GROUP
	pf.collection_value = "stars"
	pf.iterator_name = "star"
	pf.predicate_expression = "star.position.y > 560.0"
	collect.pick_filters.append(pf)
	collect.actions.append(_raw("if absf(star.position.x - $Ship.position.x) < 64.0:\n\tscore += 1\nelse:\n\tlives -= 1\nstar.queue_free()"))
	sheet.events.append(collect)

	# Lose condition.
	var lose: EventRow = EventRow.new()
	lose.trigger_provider_id = "Core"; lose.trigger_id = "OnPhysicsProcess"
	lose.conditions.append(_condition("Core", "CompareVar", "{var_name} {op} {value}", {"var_name": "lives", "op": "<=", "value": "0"}))
	lose.conditions.append(_condition("Core", "CompareVar", "{var_name} {op} {value}", {"var_name": "state", "op": "==", "value": "State.PLAYING"}))
	lose.actions.append(_action("Core", "SetVar", "{var_name} = {value}", {"var_name": "state", "value": "State.GAME_OVER"}))
	sheet.events.append(lose)

	# HUD (render-only).
	var hud: EventRow = EventRow.new()
	hud.trigger_provider_id = "Core"; hud.trigger_id = "OnProcess"
	hud.actions.append(_action("Core", "SetTextFormatted", "{target}.text = {template} % [{args}]", {"target": "$ScoreLabel", "template": "\"Score %d    Lives %d    %s\"", "args": "score, lives, (\"GAME OVER - press Enter\" if state == State.GAME_OVER else \"PLAYING\")"}))
	sheet.events.append(hud)

	if not _compile(sheet, "res://demo/showcase/starfall/starfall.tres", "res://demo/showcase/starfall/starfall.gd"):
		return false

	# Scene
	var root: Node2D = Node2D.new()
	root.name = "Starfall"
	root.set_script(load("res://demo/showcase/starfall/starfall.gd"))
	var ship: Sprite2D = Sprite2D.new()
	ship.name = "Ship"
	ship.texture = tex
	ship.position = Vector2(576, 590)
	ship.modulate = Color(0.4, 0.9, 1.0, 1.0)
	root.add_child(ship); ship.owner = root
	var label: Label = Label.new()
	label.name = "ScoreLabel"
	label.position = Vector2(28, 22)
	label.add_theme_font_size_override("font_size", 28)
	label.text = "Score 0    Lives 3    PLAYING"
	root.add_child(label); label.owner = root
	return _save_scene(root, "res://demo/showcase/starfall/starfall.tscn")

# ── 3. Quest & Inventory FSM (software-logic systems demo) ───────────────────


func _local_var(var_name: String, type_id: int, type_name: String, default_value: Variant) -> LocalVariable:
	var lv: LocalVariable = LocalVariable.new()
	lv.name = var_name
	lv.type = type_id
	lv.type_name = type_name
	lv.default_value = default_value
	lv.exported = true
	return lv


func _build_quest_fsm() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "QuestFsm"
	sheet.emit_live_values = false

	var about: CommentRow = CommentRow.new()
	about.text = "[b]Quest & Inventory FSM[/b] - a self-driving quest engine (no input): an enum+match state machine walks OFFERED -> ACTIVE -> COMPLETE, a reused grant_item() function fills a Dictionary inventory + Array quest log and emits signals, and signal: triggers spring/tween the icon on every beat. Proves the sheet compiles real software logic - collections, signals, functions, match - not just movement."
	sheet.events.append(about)

	var qstate: EnumRow = EnumRow.new()
	qstate.enum_name = "QuestState"
	qstate.members = PackedStringArray(["OFFERED", "ACTIVE", "COMPLETE"])
	sheet.events.append(qstate)

	var sig_item: SignalRow = SignalRow.new()
	sig_item.signal_name = "item_collected"
	sig_item.params = PackedStringArray(["id: String"])
	sheet.events.append(sig_item)
	var sig_quest: SignalRow = SignalRow.new()
	sig_quest.signal_name = "quest_advanced"
	sig_quest.params = PackedStringArray(["phase: int"])
	sheet.events.append(sig_quest)

	sheet.events.append(_local_var("inventory", TYPE_DICTIONARY, "Dictionary", {}))
	sheet.events.append(_local_var("quest_log", TYPE_ARRAY, "Array", []))
	sheet.events.append(_local_var("tick", TYPE_INT, "int", 0))

	sheet.variables = {
		"quest_state": {"type": "int", "default": 0, "exported": true,
			"attributes": {"tooltip": "0=OFFERED, 1=ACTIVE, 2=COMPLETE."}}
	}

	# Reused function: grant an item and log it.
	var fn: EventFunction = EventFunction.new()
	fn.function_name = "grant_item"
	fn.enabled = true
	var p_id: ACEParam = ACEParam.new(); p_id.id = "id"; p_id.type_name = "String"; p_id.type = TYPE_STRING
	var p_qty: ACEParam = ACEParam.new(); p_qty.id = "qty"; p_qty.type_name = "int"; p_qty.type = TYPE_INT
	fn.params = [p_id, p_qty]
	# Function bodies compile through _emit_event_body, which processes ROWS - so the
	# collection ACEs live inside an (untriggered) EventRow, not bare on fn.events.
	var grant_body: EventRow = EventRow.new()
	grant_body.actions.append(_action("Core", "DictSetKey", "{var_name}[{key}] = {value}", {"var_name": "inventory", "key": "id", "value": "inventory.get(id, 0) + qty"}))
	grant_body.actions.append(_action("Core", "ArrayAppend", "{var_name}.append({value})", {"var_name": "quest_log", "value": "id"}))
	grant_body.actions.append(_action("Core", "EmitSignal", "item_collected.emit(id)", {}))
	fn.events = [grant_body]
	sheet.functions.append(fn)

	# Self-driving tick: advance the FSM once per second.
	var tick_row: EventRow = EventRow.new()
	tick_row.trigger_provider_id = "Core"; tick_row.trigger_id = "OnProcess"
	tick_row.conditions.append(_every("quest", "1.0"))
	tick_row.actions.append(_action("Core", "AddVar", "{var_name} += {amount}", {"var_name": "tick", "amount": "1"}))
	var qmatch: MatchRow = MatchRow.new()
	qmatch.match_expression = "quest_state"
	qmatch.branches_text = "QuestState.OFFERED:\n\tquest_state = QuestState.ACTIVE\n\tquest_advanced.emit(quest_state)\nQuestState.ACTIVE:\n\tgrant_item(\"gold\", 3)\n\tif quest_log.size() >= 3:\n\t\tquest_state = QuestState.COMPLETE\n\t\tquest_advanced.emit(quest_state)\n_:\n\tpass"
	tick_row.actions.append(qmatch)
	sheet.events.append(tick_row)

	# signal: triggers - react to the sheet's own signals (auto-connected in _ready).
	var on_item: EventRow = EventRow.new()
	on_item.trigger_provider_id = "Core"; on_item.trigger_id = "signal:item_collected"; on_item.trigger_args = "id: String"
	on_item.actions.append(_action("SpringBehavior", "method:spring_host_scale", "{on_node}.spring_host_scale({target})", {"on_node": "$Icon/SpringBehavior", "target": "1.0"}))
	on_item.actions.append(_action("SpringBehavior", "method:add_impulse", "{target}.add_impulse({spring_name}, {amount})", {"target": "$Icon/SpringBehavior", "spring_name": "\"__scale\"", "amount": "6.0"}))
	sheet.events.append(on_item)

	var on_quest: EventRow = EventRow.new()
	on_quest.trigger_provider_id = "Core"; on_quest.trigger_id = "signal:quest_advanced"; on_quest.trigger_args = "phase: int"
	on_quest.actions.append(_action("TweenBehavior", "method:tween_rotation", "{target}.tween_rotation({degrees}, {duration})", {"target": "$Icon/TweenBehavior", "degrees": "$Icon.rotation_degrees + 120.0", "duration": "0.4"}))
	on_quest.actions.append(_action("SpringBehavior", "method:spring_host_scale", "{on_node}.spring_host_scale({target})", {"on_node": "$Icon/SpringBehavior", "target": "1.6"}))
	sheet.events.append(on_quest)

	# HUD.
	var hud: EventRow = EventRow.new()
	hud.trigger_provider_id = "Core"; hud.trigger_id = "OnProcess"
	hud.actions.append(_action("Core", "SetTextFormatted", "{target}.text = {template} % [{args}]", {"target": "$Screen", "template": "\"QUEST: %s\nitems: %d   log: %d\nt = %d\"", "args": "[\"OFFERED\", \"ACTIVE\", \"COMPLETE\"][quest_state], inventory.size(), quest_log.size(), tick"}))
	sheet.events.append(hud)

	if not _compile(sheet, "res://demo/showcase/quest_fsm/quest_fsm.tres", "res://demo/showcase/quest_fsm/quest_fsm.gd"):
		return false

	# Scene
	var tex: ImageTexture = _make_texture()
	var root: Node2D = Node2D.new()
	root.name = "QuestDemo"
	root.set_script(load("res://demo/showcase/quest_fsm/quest_fsm.gd"))
	var icon: Sprite2D = Sprite2D.new()
	icon.name = "Icon"
	icon.texture = tex
	icon.position = Vector2(576, 360)
	icon.scale = Vector2(2.0, 2.0)
	icon.modulate = Color(0.7, 0.85, 1.0, 1.0)
	root.add_child(icon); icon.owner = root
	_attach_behavior(icon, "SpringBehavior", SPRING, root)
	_attach_behavior(icon, "TweenBehavior", TWEEN, root)
	var label: Label = Label.new()
	label.name = "Screen"
	label.position = Vector2(40, 40)
	label.add_theme_font_size_override("font_size", 30)
	label.text = "QUEST: OFFERED\nitems: 0   log: 0\nt = 0"
	root.add_child(label); label.owner = root
	return _save_scene(root, "res://demo/showcase/quest_fsm/quest_fsm.tscn")


# ── Utility AI showcase: a guard whose UtilityBrain scores patrol/chase/flee ──
func _build_utility_ai() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "GuardBrainDemo"
	sheet.emit_live_values = false

	var about: CommentRow = CommentRow.new()
	about.text = "[b]Guard Brain (Utility AI)[/b] - a self-driving guard with no input. The UtilityBrain scores three actions (patrol / chase / flee) from a threat signal that rises and falls plus a stamina wave; a response curve shapes each score, and the highest wins. Set Input -> Evaluate -> read Current Action is the whole loop - the addon drives a real decision maker, not a fixed state machine. Attach a UtilityBrain to any node and score your own actions the same way."
	sheet.events.append(about)

	sheet.events.append(_local_var("t", TYPE_FLOAT, "float", 0.0))
	sheet.events.append(_local_var("threat", TYPE_FLOAT, "float", 0.0))
	sheet.events.append(_local_var("stamina", TYPE_FLOAT, "float", 1.0))

	# One-time setup: register three actions and shape each with considerations + response curves.
	var setup: EventRow = EventRow.new()
	setup.trigger_provider_id = "Core"; setup.trigger_id = "OnReady"
	setup.actions.append(_action("UtilityBrain", "method:add_action", "{target}.add_action({action_name}, {cooldown}, {interruptible}, {priority})", {"target": "$Guard/Brain", "action_name": "\"patrol\"", "cooldown": "0.0", "interruptible": "true", "priority": "0.3"}))
	setup.actions.append(_action("UtilityBrain", "method:add_action", "{target}.add_action({action_name}, {cooldown}, {interruptible}, {priority})", {"target": "$Guard/Brain", "action_name": "\"chase\"", "cooldown": "0.0", "interruptible": "true", "priority": "1.0"}))
	setup.actions.append(_action("UtilityBrain", "method:add_action", "{target}.add_action({action_name}, {cooldown}, {interruptible}, {priority})", {"target": "$Guard/Brain", "action_name": "\"flee\"", "cooldown": "0.0", "interruptible": "false", "priority": "1.2"}))
	# patrol likes LOW threat; chase scales with threat; flee spikes at high threat and low stamina.
	setup.actions.append(_action("UtilityBrain", "method:add_consideration", "{target}.add_consideration({action_name}, {input_key}, {curve}, {weight}, {curve_center}, {curve_slope})", {"target": "$Guard/Brain", "action_name": "\"patrol\"", "input_key": "\"threat\"", "curve": "\"inverse\"", "weight": "1.0", "curve_center": "0.5", "curve_slope": "1.0"}))
	setup.actions.append(_action("UtilityBrain", "method:add_consideration", "{target}.add_consideration({action_name}, {input_key}, {curve}, {weight}, {curve_center}, {curve_slope})", {"target": "$Guard/Brain", "action_name": "\"chase\"", "input_key": "\"threat\"", "curve": "\"quadratic\"", "weight": "1.0", "curve_center": "0.5", "curve_slope": "1.0"}))
	setup.actions.append(_action("UtilityBrain", "method:add_consideration", "{target}.add_consideration({action_name}, {input_key}, {curve}, {weight}, {curve_center}, {curve_slope})", {"target": "$Guard/Brain", "action_name": "\"flee\"", "input_key": "\"threat\"", "curve": "\"logistic\"", "weight": "1.0", "curve_center": "0.8", "curve_slope": "8.0"}))
	setup.actions.append(_action("UtilityBrain", "method:add_consideration", "{target}.add_consideration({action_name}, {input_key}, {curve}, {weight}, {curve_center}, {curve_slope})", {"target": "$Guard/Brain", "action_name": "\"flee\"", "input_key": "\"stamina\"", "curve": "\"inverse\"", "weight": "0.6", "curve_center": "0.5", "curve_slope": "1.0"}))
	sheet.events.append(setup)

	# Self-driving tick: oscillate the world signals, feed them in, and evaluate.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"; tick.trigger_id = "OnProcess"
	tick.actions.append(_action("Core", "AddVar", "{var_name} += {amount}", {"var_name": "t", "amount": "delta"}))
	tick.actions.append(_action("Core", "SetVar", "{var_name} = {value}", {"var_name": "threat", "value": "0.5 + 0.5 * sin(t * 0.8)"}))
	tick.actions.append(_action("Core", "SetVar", "{var_name} = {value}", {"var_name": "stamina", "value": "0.5 + 0.5 * cos(t * 0.5)"}))
	tick.actions.append(_action("UtilityBrain", "method:set_input", "{target}.set_input({key}, {value})", {"target": "$Guard/Brain", "key": "\"threat\"", "value": "threat"}))
	tick.actions.append(_action("UtilityBrain", "method:set_input", "{target}.set_input({key}, {value})", {"target": "$Guard/Brain", "key": "\"stamina\"", "value": "stamina"}))
	tick.actions.append(_action("UtilityBrain", "method:evaluate", "{target}.evaluate()", {"target": "$Guard/Brain"}))
	sheet.events.append(tick)

	# HUD: show the winning action, its score, and the live inputs.
	var hud: EventRow = EventRow.new()
	hud.trigger_provider_id = "Core"; hud.trigger_id = "OnProcess"
	hud.actions.append(_action("Core", "SetTextFormatted", "{target}.text = {template} % [{args}]", {"target": "$Screen", "template": "\"GUARD BRAIN (Utility AI)\naction: %s  (score %.2f)\nthreat %.2f   stamina %.2f\"", "args": "$Guard/Brain.current_action(), $Guard/Brain.decision_score(), threat, stamina"}))
	sheet.events.append(hud)

	if not _compile(sheet, "res://demo/showcase/utility_ai/utility_ai_demo.tres", "res://demo/showcase/utility_ai/utility_ai_demo.gd"):
		return false

	# Scene
	var root: Node2D = Node2D.new()
	root.name = "GuardBrainDemo"
	root.set_script(load("res://demo/showcase/utility_ai/utility_ai_demo.gd"))
	var guard: Sprite2D = Sprite2D.new()
	guard.name = "Guard"
	guard.texture = _make_texture()
	guard.position = Vector2(576, 360)
	guard.scale = Vector2(2.0, 2.0)
	guard.modulate = Color(1.0, 0.82, 0.4, 1.0)
	root.add_child(guard); guard.owner = root
	_attach_behavior(guard, "Brain", UTILITY_AI, root)
	var label: Label = Label.new()
	label.name = "Screen"
	label.position = Vector2(40, 40)
	label.add_theme_font_size_override("font_size", 28)
	label.text = "GUARD BRAIN (Utility AI)"
	root.add_child(label); label.owner = root
	return _save_scene(root, "res://demo/showcase/utility_ai/utility_ai_demo.tscn")


# ── HTN Agent showcase: a chef that plans make_meal -> gather -> cook -> serve ──
func _build_htn_agent() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "ChefPlannerDemo"
	sheet.emit_live_values = false

	var about: CommentRow = CommentRow.new()
	about.text = "[b]Chef Planner (HTN Agent)[/b] - a self-driving planner, no input. The compound task make_meal decomposes (via a method whose world-state condition holds) into an ordered plan gather -> cook -> serve; a tick marks each primitive task complete and walks the plan to the end. Add tasks + methods, Request Plan, Mark Task Complete - the whole hierarchical-planning loop. Attach an HTN Agent to any node and give it your own task network."
	sheet.events.append(about)

	# One-time setup: declare the task network, seed the world, and plan.
	var setup: EventRow = EventRow.new()
	setup.trigger_provider_id = "Core"; setup.trigger_id = "OnReady"
	setup.actions.append(_action("HTNAgent", "method:set_world_state", "{target}.set_world_state({key}, {value})", {"target": "$Chef/Planner", "key": "\"has_kitchen\"", "value": "true"}))
	setup.actions.append(_action("HTNAgent", "method:add_compound", "{target}.add_compound({task_name})", {"target": "$Chef/Planner", "task_name": "\"make_meal\""}))
	setup.actions.append(_action("HTNAgent", "method:add_primitive", "{target}.add_primitive({task_name})", {"target": "$Chef/Planner", "task_name": "\"gather\""}))
	setup.actions.append(_action("HTNAgent", "method:add_primitive", "{target}.add_primitive({task_name})", {"target": "$Chef/Planner", "task_name": "\"cook\""}))
	setup.actions.append(_action("HTNAgent", "method:add_primitive", "{target}.add_primitive({task_name})", {"target": "$Chef/Planner", "task_name": "\"serve\""}))
	setup.actions.append(_action("HTNAgent", "method:add_method", "{target}.add_method({task_name}, {method_id}, {utility})", {"target": "$Chef/Planner", "task_name": "\"make_meal\"", "method_id": "\"cook_it\"", "utility": "1.0"}))
	setup.actions.append(_action("HTNAgent", "method:add_method_condition", "{target}.add_method_condition({task_name}, {method_id}, {key}, {op}, {value})", {"target": "$Chef/Planner", "task_name": "\"make_meal\"", "method_id": "\"cook_it\"", "key": "\"has_kitchen\"", "op": "\"==\"", "value": "true"}))
	setup.actions.append(_action("HTNAgent", "method:add_method_subtask", "{target}.add_method_subtask({task_name}, {method_id}, {subtask})", {"target": "$Chef/Planner", "task_name": "\"make_meal\"", "method_id": "\"cook_it\"", "subtask": "\"gather\""}))
	setup.actions.append(_action("HTNAgent", "method:add_method_subtask", "{target}.add_method_subtask({task_name}, {method_id}, {subtask})", {"target": "$Chef/Planner", "task_name": "\"make_meal\"", "method_id": "\"cook_it\"", "subtask": "\"cook\""}))
	setup.actions.append(_action("HTNAgent", "method:add_method_subtask", "{target}.add_method_subtask({task_name}, {method_id}, {subtask})", {"target": "$Chef/Planner", "task_name": "\"make_meal\"", "method_id": "\"cook_it\"", "subtask": "\"serve\""}))
	setup.actions.append(_action("HTNAgent", "method:request_plan", "{target}.request_plan()", {"target": "$Chef/Planner"}))
	sheet.events.append(setup)

	# Self-driving: once a second, complete the current primitive task to walk the plan.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"; tick.trigger_id = "OnProcess"
	tick.conditions.append(_every("chef", "1.0"))
	tick.conditions.append(_condition("HTNAgent", "method:has_plan", "{target}.has_plan()", {"target": "$Chef/Planner"}))
	tick.actions.append(_action("HTNAgent", "method:mark_complete", "{target}.mark_complete()", {"target": "$Chef/Planner"}))
	sheet.events.append(tick)

	# HUD: show the running task and how many steps remain.
	var hud: EventRow = EventRow.new()
	hud.trigger_provider_id = "Core"; hud.trigger_id = "OnProcess"
	hud.actions.append(_action("Core", "SetTextFormatted", "{target}.text = {template} % [{args}]", {"target": "$Screen", "template": "\"CHEF PLANNER (HTN)\ntask: %s\nsteps left: %d\"", "args": "$Chef/Planner.current_task(), $Chef/Planner.plan_length()"}))
	sheet.events.append(hud)

	if not _compile(sheet, "res://demo/showcase/htn_agent/htn_agent_demo.tres", "res://demo/showcase/htn_agent/htn_agent_demo.gd"):
		return false

	# Scene
	var root: Node2D = Node2D.new()
	root.name = "ChefPlannerDemo"
	root.set_script(load("res://demo/showcase/htn_agent/htn_agent_demo.gd"))
	var chef: Sprite2D = Sprite2D.new()
	chef.name = "Chef"
	chef.texture = _make_texture()
	chef.position = Vector2(576, 360)
	chef.scale = Vector2(2.0, 2.0)
	chef.modulate = Color(0.6, 0.9, 0.7, 1.0)
	root.add_child(chef); chef.owner = root
	_attach_behavior(chef, "Planner", HTN_AGENT, root, {"root_task": "make_meal"})
	var label: Label = Label.new()
	label.name = "Screen"
	label.position = Vector2(40, 40)
	label.add_theme_font_size_override("font_size", 28)
	label.text = "CHEF PLANNER (HTN)"
	root.add_child(label); label.owner = root
	return _save_scene(root, "res://demo/showcase/htn_agent/htn_agent_demo.tscn")


## Guard Post (UHTN Planning) - the full utility-driven feature sweep, DATA-DRIVEN: the whole plan
## (tasks, methods, preconditions, scorers) ships as a UHTNPlanResource .tres built here exactly as a
## designer would fill the Inspector grids, dropped onto the planner's Plan Resource slot. A prowler
## sweeps closer and further on a sine; the guard's closeness fact flows through a linear curve into an
## "aggro" scorer that ranks the chase method LIVE (far = the fixed-utility watch wins, near = chase
## overtakes), while an oscillating health fact drives a "fear" scorer (inverse curve) whose flee method
## is precondition-gated on hurt == 1. Every 9 seconds Force Task pushes a scripted "salute" beat. The
## HUD prints the current task plus both scorer values - the live-curve-debugging workflow.
func _build_uhtn_planning() -> bool:
	# The plan asset, authored the way the Inspector grids would author it.
	var plan: Resource = (load(UHTN_RESOURCE) as GDScript).new()
	plan.set("plan_name", "guard_post")
	plan.set("root_task", "root")
	plan.set("tasks", [
		{"name": "watch_step", "kind": "primitive"},
		{"name": "chase_step", "kind": "primitive"},
		{"name": "flee_step", "kind": "primitive"},
		{"name": "root", "kind": "compound"},
		{"name": "engage", "kind": "compound"}
	])
	plan.set("methods", [
		{"task": "root", "method": "m_watch", "subtasks": "watch_step", "scorer": "", "utility": 0.25},
		{"task": "root", "method": "m_engage", "subtasks": "engage", "scorer": "aggro", "utility": 0.0},
		{"task": "root", "method": "m_flee", "subtasks": "flee_step", "scorer": "fear", "utility": 0.0},
		{"task": "engage", "method": "m_rush", "subtasks": "chase_step", "scorer": "", "utility": 1.0}
	])
	plan.set("conditions", [
		{"method": "m_flee", "key": "hurt", "op": "==", "value": "1"}
	])
	plan.set("scorer_inputs", [
		{"scorer": "aggro", "input": "closeness", "curve": "linear", "weight": 1.0, "center": 0.5, "slope": 0.2},
		{"scorer": "fear", "input": "health", "curve": "inverse", "weight": 1.0, "center": 0.5, "slope": 0.2}
	])
	DirAccess.make_dir_recursive_absolute("res://demo/showcase/uhtn_planning")
	if ResourceSaver.save(plan, "res://demo/showcase/uhtn_planning/guard_plan.tres") != OK:
		return false

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "GuardPostDemo"
	sheet.emit_live_values = false

	var about: CommentRow = CommentRow.new()
	about.text = "[b]Guard Post (UHTN Planning)[/b] - Utility AI steering an HTN, fully data-driven. The whole plan lives in guard_plan.tres (Inspector grids: tasks, methods, preconditions, scorer curves) dropped on the planner's Plan Resource slot. The prowler sweeps in and out; a closeness fact through a linear curve ranks the chase method LIVE, so far = watch (fixed utility 0.25) and near = chase, with no re-authoring. Oscillating health feeds a fear scorer (inverse curve) whose flee method only competes while the hurt precondition holds. Every 9s Force Task pushes a scripted salute beat. The HUD shows both scorer values ticking - tune the curves in the .tres and watch behavior change."
	sheet.events.append(about)

	# Facts every tick: closeness from the real prowler distance, health on a slow sine, hurt from health.
	var facts: EventRow = EventRow.new()
	facts.trigger_provider_id = "Core"; facts.trigger_id = "OnProcess"
	facts.actions.append(_action("UHTNPlanner", "method:set_world_state", "{target}.set_world_state({key}, {value})", {"target": "$Guard/Planner", "key": "\"closeness\"", "value": "1.0 - clampf($Guard.position.distance_to($Prowler.position) / 600.0, 0.0, 1.0)"}))
	facts.actions.append(_action("UHTNPlanner", "method:set_world_state", "{target}.set_world_state({key}, {value})", {"target": "$Guard/Planner", "key": "\"health\"", "value": "0.5 + 0.5 * sin(Time.get_ticks_msec() / 4000.0)"}))
	facts.actions.append(_action("UHTNPlanner", "method:set_world_state", "{target}.set_world_state({key}, {value})", {"target": "$Guard/Planner", "key": "\"hurt\"", "value": "1 if $Guard/Planner.world_value(\"health\") < 0.3 else 0"}))
	sheet.events.append(facts)

	# Replan once a second with the fresh scores (event-paced, not per-tick) - the current task stays
	# visible between ticks because replanning restarts the plan rather than consuming it.
	var replan: EventRow = EventRow.new()
	replan.trigger_provider_id = "Core"; replan.trigger_id = "OnProcess"
	replan.conditions.append(_every("uhtn_replan", "1.0"))
	replan.actions.append(_action("UHTNPlanner", "method:request_plan", "{target}.request_plan()", {"target": "$Guard/Planner"}))
	sheet.events.append(replan)

	# Walk the plan on a slower beat: completing a step is the gameplay layer's job (here, a timer).
	var walk: EventRow = EventRow.new()
	walk.trigger_provider_id = "Core"; walk.trigger_id = "OnProcess"
	walk.conditions.append(_every("uhtn_walk", "3.0"))
	walk.conditions.append(_condition("UHTNPlanner", "method:has_plan", "{target}.has_plan()", {"target": "$Guard/Planner"}))
	walk.actions.append(_action("UHTNPlanner", "method:mark_complete", "{target}.mark_complete()", {"target": "$Guard/Planner"}))
	sheet.events.append(walk)

	# The scripted-override beat: every 9 seconds, Force Task pushes a salute in front of the plan.
	var beat: EventRow = EventRow.new()
	beat.trigger_provider_id = "Core"; beat.trigger_id = "OnProcess"
	beat.conditions.append(_every("uhtn_salute", "9.0"))
	beat.actions.append(_action("UHTNPlanner", "method:force_task", "{target}.force_task({task_name})", {"target": "$Guard/Planner", "task_name": "\"salute\""}))
	sheet.events.append(beat)

	# The prowler sweeps toward and away from the guard, so closeness (and the aggro score) oscillates.
	var sweep: EventRow = EventRow.new()
	sweep.trigger_provider_id = "Core"; sweep.trigger_id = "OnProcess"
	sweep.actions.append(_action("Core", "SetProperty", "{target}.{property} = {value}", {"target": "$Prowler", "property": "position", "value": "Vector2(576.0 + 500.0 * sin(Time.get_ticks_msec() / 3000.0), 360.0)"}))
	sheet.events.append(sweep)

	# HUD: the current task plus BOTH live scorer values (the Scorer Value expression at work).
	var hud: EventRow = EventRow.new()
	hud.trigger_provider_id = "Core"; hud.trigger_id = "OnProcess"
	hud.actions.append(_action("Core", "SetTextFormatted", "{target}.text = {template} % [{args}]", {"target": "$Screen", "template": "\"GUARD POST (UHTN PLANNING)\ntask: %s\naggro: %.2f   fear: %.2f\"", "args": "$Guard/Planner.current_task(), $Guard/Planner.scorer_value(\"aggro\"), $Guard/Planner.scorer_value(\"fear\")"}))
	sheet.events.append(hud)

	if not _compile(sheet, "res://demo/showcase/uhtn_planning/uhtn_planning_demo.tres", "res://demo/showcase/uhtn_planning/uhtn_planning_demo.gd"):
		return false

	# Scene: the guard (planner + the .tres on its Plan Resource slot) and the sweeping prowler.
	var root: Node2D = Node2D.new()
	root.name = "GuardPostDemo"
	root.set_script(load("res://demo/showcase/uhtn_planning/uhtn_planning_demo.gd"))
	var guard: Sprite2D = Sprite2D.new()
	guard.name = "Guard"
	guard.texture = _make_texture()
	guard.position = Vector2(576, 360)
	guard.scale = Vector2(2.0, 2.0)
	guard.modulate = Color(0.55, 0.75, 1.0, 1.0)
	root.add_child(guard); guard.owner = root
	_attach_behavior(guard, "Planner", UHTN_PLANNER, root, {
		"plan_resource": load("res://demo/showcase/uhtn_planning/guard_plan.tres")
	})
	var prowler: Sprite2D = Sprite2D.new()
	prowler.name = "Prowler"
	prowler.texture = _make_texture()
	prowler.position = Vector2(1076, 360)
	prowler.scale = Vector2(1.4, 1.4)
	prowler.modulate = Color(1.0, 0.5, 0.45, 1.0)
	root.add_child(prowler); prowler.owner = root
	var label: Label = Label.new()
	label.name = "Screen"
	label.position = Vector2(40, 40)
	label.add_theme_font_size_override("font_size", 28)
	label.text = "GUARD POST (UHTN PLANNING)"
	root.add_child(label); label.owner = root
	return _save_scene(root, "res://demo/showcase/uhtn_planning/uhtn_planning_demo.tscn")

# ── 4. Platformer-Shooter (two new behavior packs working together) ──────────


func _build_platformer_shooter() -> bool:
	var tex: ImageTexture = _make_texture()

	# Bullet the player fires (moves along its rotation via BulletBehavior).
	var shot: Sprite2D = Sprite2D.new()
	shot.name = "Shot"
	shot.texture = tex
	shot.scale = Vector2(0.22, 0.12)
	shot.modulate = Color(1.0, 0.95, 0.4, 1.0)
	_attach_behavior(shot, "BulletBehavior", BULLET, shot, {"speed": 720.0, "align_rotation": false})
	if not _save_scene(shot, "res://demo/showcase/platformer_shooter/shot.tscn"):
		return false

	# Target that drifts in from the right (also a BulletBehavior, slower).
	var target: Sprite2D = Sprite2D.new()
	target.name = "Target"
	target.texture = tex
	target.scale = Vector2(0.4, 0.4)
	target.modulate = Color(1.0, 0.4, 0.45, 1.0)
	_attach_behavior(target, "BulletBehavior", BULLET, target, {"speed": 130.0, "align_rotation": false})
	if not _save_scene(target, "res://demo/showcase/platformer_shooter/target.tscn"):
		return false

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "PlatformerShooter"
	sheet.emit_live_values = false

	var about: CommentRow = CommentRow.new()
	about.text = "[b]Platformer-Shooter[/b] - the new Platformer + Weapon Kit packs working together. Run with A/D, jump with Up (double jump + coyote time + variable height from the Platformer pack), and hold Space to shoot (fire-rate, ammo and auto-reload from the Weapon Kit). Shots destroy the red targets drifting in from the right."
	sheet.events.append(about)

	sheet.variables = {
		"score": {"type": "int", "default": 0, "exported": true,
			"attributes": {"tooltip": "Targets destroyed."}}
	}

	# Jump (Up): press to jump, release for variable jump height - fully code-free, one event per
	# edge. The Platformer pack's own _physics_process already runs A/D movement + gravity; we feed
	# it the jump button via its node-targeted Jump / Jump Released actions on $Player/PlatformerMovement.
	var jump_press: EventRow = EventRow.new()
	jump_press.trigger_provider_id = "Core"; jump_press.trigger_id = "OnPhysicsProcess"
	jump_press.conditions.append(_condition("Core", "IsActionJustPressed", "Input.is_action_just_pressed(&{action})", {"action": "\"ui_up\""}))
	jump_press.actions.append(_action("PlatformerMovement", "method:jump", "{target}.jump()", {"target": "$Player/PlatformerMovement"}))
	sheet.events.append(jump_press)
	var jump_release: EventRow = EventRow.new()
	jump_release.trigger_provider_id = "Core"; jump_release.trigger_id = "OnPhysicsProcess"
	jump_release.conditions.append(_condition("Core", "IsActionJustReleased", "Input.is_action_just_released(&{action})", {"action": "\"ui_up\""}))
	jump_release.actions.append(_action("PlatformerMovement", "method:jump_released", "{target}.jump_released()", {"target": "$Player/PlatformerMovement"}))
	sheet.events.append(jump_release)

	# Fire (hold Space): FULLY CODE-FREE - conditions on the left (the input + the Weapon Kit's own
	# Can Fire gate, targeting the behavior at $Player/WeaponKit), actions on the right (the pack's
	# Fire, then Spawn Scene (Full) aimed by the Platformer pack's facing_direction). This is the row
	# the node-targetable pack ACEs unlocked - no raw GDScript, the same legibility as event sheets.
	var fire: EventRow = EventRow.new()
	fire.trigger_provider_id = "Core"; fire.trigger_id = "OnPhysicsProcess"
	fire.conditions.append(_condition("Core", "IsActionPressed", "Input.is_action_pressed(&{action})", {"action": "\"ui_accept\""}))
	fire.conditions.append(_condition("WeaponKit", "method:can_fire", "{target}.can_fire()", {"target": "$Player/WeaponKit"}))
	fire.actions.append(_action("WeaponKit", "method:fire", "{target}.fire()", {"target": "$Player/WeaponKit"}))
	fire.actions.append(_action("Core", "SpawnSceneFull", "var __spawn_shot = load({path}).instantiate()\n__spawn_shot.position = {position}\n__spawn_shot.rotation_degrees = {rotation}\nadd_child(__spawn_shot)\nif {group} != \"\": __spawn_shot.add_to_group({group})", {"path": "\"res://demo/showcase/platformer_shooter/shot.tscn\"", "position": "$Player.position + Vector2(32.0 * $Player/PlatformerMovement.facing_direction(), -6.0)", "rotation": "0.0 if $Player/PlatformerMovement.facing_direction() >= 0 else 180.0", "group": "\"shots\""}))
	sheet.events.append(fire)

	# Keep the player on screen.
	var clamp_row: EventRow = EventRow.new()
	clamp_row.trigger_provider_id = "Core"; clamp_row.trigger_id = "OnPhysicsProcess"
	clamp_row.actions.append(_action("Core", "SetProperty", "{target}.{property} = {value}", {"target": "$Player", "property": "position.x", "value": "clampf($Player.position.x, 40.0, 1112.0)"}))
	sheet.events.append(clamp_row)

	# Spawn a target from the right every 1.5s.
	var spawn: EventRow = EventRow.new()
	spawn.trigger_provider_id = "Core"; spawn.trigger_id = "OnPhysicsProcess"
	spawn.conditions.append(_every("ps_spawn", "1.5"))
	spawn.actions.append(_action("Core", "SpawnSceneFull", "var __spawn_shot = load({path}).instantiate()\n__spawn_shot.position = {position}\n__spawn_shot.rotation_degrees = {rotation}\nadd_child(__spawn_shot)\nif {group} != \"\": __spawn_shot.add_to_group({group})", {"path": "\"res://demo/showcase/platformer_shooter/target.tscn\"", "position": "Vector2(1240.0, randf_range(120.0, 540.0))", "rotation": "180.0", "group": "\"targets\""}))
	sheet.events.append(spawn)

	# Hit detection (shots x targets) + off-screen culling.
	var hits: EventRow = EventRow.new()
	hits.trigger_provider_id = "Core"; hits.trigger_id = "OnPhysicsProcess"
	hits.actions.append(_raw("\n".join(PackedStringArray([
		"for __shot in get_tree().get_nodes_in_group(\"shots\"):",
		"\tfor __target in get_tree().get_nodes_in_group(\"targets\"):",
		"\t\tif is_instance_valid(__shot) and is_instance_valid(__target) and __shot.global_position.distance_to(__target.global_position) < 42.0:",
		"\t\t\t__shot.queue_free()",
		"\t\t\t__target.queue_free()",
		"\t\t\tscore += 1",
		"\t\t\tbreak",
		"for __node in get_tree().get_nodes_in_group(\"shots\") + get_tree().get_nodes_in_group(\"targets\"):",
		"\tif __node.global_position.x < -60.0 or __node.global_position.x > 1300.0:",
		"\t\t__node.queue_free()"
	]))))
	sheet.events.append(hits)

	# HUD (render-only): score + the Weapon Kit's live ammo/reload state.
	var hud_row: EventRow = EventRow.new()
	hud_row.trigger_provider_id = "Core"; hud_row.trigger_id = "OnProcess"
	hud_row.actions.append(_action("Core", "SetTextFormatted", "{target}.text = {template} % [{args}]", {"target": "$Hud", "template": "\"Score %d    Ammo %d/%d    %s\"", "args": "score, $Player/WeaponKit.current_ammo, $Player/WeaponKit.max_ammo, (\"RELOADING...\" if $Player/WeaponKit.is_reloading() else \"A/D move   Up jump   hold Space fire\")"}))
	sheet.events.append(hud_row)

	if not _compile(sheet, "res://demo/showcase/platformer_shooter/platformer_shooter.tres", "res://demo/showcase/platformer_shooter/platformer_shooter.gd"):
		return false

	# ── Scene: floor + player (with both behaviors) + HUD ──
	var root: Node2D = Node2D.new()
	root.name = "PlatformerShooter"
	root.set_script(load("res://demo/showcase/platformer_shooter/platformer_shooter.gd"))

	# Add each container to the tree BEFORE its children set owner = root (owner must be an
	# ancestor already in the tree, else the node is dropped from the packed scene).
	var floor_body: StaticBody2D = StaticBody2D.new()
	floor_body.name = "Floor"
	floor_body.position = Vector2(576.0, 660.0)
	root.add_child(floor_body); floor_body.owner = root
	var floor_shape: CollisionShape2D = CollisionShape2D.new()
	var floor_rect: RectangleShape2D = RectangleShape2D.new()
	floor_rect.size = Vector2(1180.0, 48.0)
	floor_shape.shape = floor_rect
	floor_body.add_child(floor_shape); floor_shape.owner = root
	var floor_sprite: Sprite2D = Sprite2D.new()
	floor_sprite.texture = tex
	floor_sprite.scale = Vector2(24.6, 1.0)
	floor_sprite.modulate = Color(0.3, 0.34, 0.4, 1.0)
	floor_body.add_child(floor_sprite); floor_sprite.owner = root

	var player: CharacterBody2D = CharacterBody2D.new()
	player.name = "Player"
	player.position = Vector2(220.0, 540.0)
	root.add_child(player); player.owner = root
	var player_shape: CollisionShape2D = CollisionShape2D.new()
	var player_rect: RectangleShape2D = RectangleShape2D.new()
	player_rect.size = Vector2(40.0, 48.0)
	player_shape.shape = player_rect
	player.add_child(player_shape); player_shape.owner = root
	var player_sprite: Sprite2D = Sprite2D.new()
	player_sprite.texture = tex
	player_sprite.modulate = Color(0.4, 0.9, 1.0, 1.0)
	player.add_child(player_sprite); player_sprite.owner = root
	_attach_behavior(player, "PlatformerMovement", PLATFORMER, root,
		{"move_speed": 280.0, "jump_velocity": -500.0, "max_jumps": 2, "coyote_time": 0.12})
	_attach_behavior(player, "WeaponKit", WEAPON_KIT, root,
		{"max_ammo": 8, "current_ammo": 8, "fire_rate": 7.0, "reload_time": 0.8, "fire_mode": 1})

	var hud: Label = Label.new()
	hud.name = "Hud"
	hud.position = Vector2(28.0, 22.0)
	hud.add_theme_font_size_override("font_size", 26)
	hud.text = "Score 0    Ammo 8/8    A/D move   Up jump   hold Space fire"
	root.add_child(hud); hud.owner = root

	return _save_scene(root, "res://demo/showcase/platformer_shooter/platformer_shooter.tscn")

# ── 5. Swarm - frame-spreading crowd (Budgeted For Each) ─────────────────────


func _build_swarm() -> bool:
	# Dot sub-scene: a small group-tagged sprite the sheet spawns by the hundreds.
	var tex: ImageTexture = _make_texture()
	var dot: Sprite2D = Sprite2D.new()
	dot.name = "Dot"
	dot.texture = tex
	dot.scale = Vector2(0.32, 0.32)
	dot.add_to_group("swarm", true)
	if not _save_scene(dot, "res://demo/showcase/swarm/dot.tscn"):
		return false

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "Swarm"
	sheet.emit_live_values = false

	var about: CommentRow = CommentRow.new()
	about.text = "[b]Swarm[/b] - frame-spreading made visible. On Ready spawns 800 sprites into the \"swarm\" group; ONE For Each with a frame-spread budget of 90/frame wobbles them, so only a slice updates each frame and the colour refresh SWEEPS through the crowd - that visible wave IS the spreading. The FPS stays pinned even though the loop never touches the whole crowd in a single frame. Tick frame_spread_count on any For Each to get this - no behavior, no await."
	sheet.events.append(about)

	sheet.variables = {
		"count": {"type": "int", "default": 800, "exported": true,
			"attributes": {"tooltip": "How many sprites to spawn.", "range": {"min": "100", "max": "2000", "step": "50"}}},
		"t": {"type": "float", "default": 0.0, "exported": false,
			"attributes": {"tooltip": "Animation clock (seconds)."}}
	}

	# On Ready: spawn the crowd in a 40-wide grid into the "swarm" group.
	var spawn: EventRow = EventRow.new()
	spawn.trigger_provider_id = "Core"; spawn.trigger_id = "OnReady"
	spawn.actions.append(_raw("var __cols: int = 40\nfor __i: int in range(count):\n\tvar __dot: Sprite2D = load(\"res://demo/showcase/swarm/dot.tscn\").instantiate()\n\t__dot.position = Vector2(48.0 + float(__i % __cols) * 27.0, 70.0 + float(__i / __cols) * 27.0)\n\tadd_child(__dot)"))
	sheet.events.append(spawn)

	# On Process: advance the clock + show the live FPS so you can see it stay smooth.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"; tick.trigger_id = "OnProcess"
	tick.actions.append(_raw("t += delta"))
	tick.actions.append(_action("Core", "SetTextFormatted", "{target}.text = {template} % [{args}]", {"target": "$Info", "template": "\"%d sprites   ·   Budgeted For Each: 90/frame   ·   %d FPS\"", "args": "count, Engine.get_frames_per_second()"}))
	sheet.events.append(tick)

	# On Process: a Budgeted For Each over the crowd - wobble the texture offset + sweep the hue.
	# frame_spread_count = 90 makes it process only ~90 sprites per frame, resuming next frame.
	var wobble: EventRow = EventRow.new()
	wobble.trigger_provider_id = "Core"; wobble.trigger_id = "OnProcess"
	var pf: PickFilter = PickFilter.new()
	pf.enabled = true
	pf.collection_kind = PickFilter.CollectionKind.GROUP
	pf.collection_value = "swarm"
	pf.iterator_name = "dot"
	pf.frame_spread_count = 90
	wobble.pick_filters.append(pf)
	wobble.actions.append(_raw("dot.offset = Vector2(sin(t * 2.0 + dot.position.x * 0.02) * 10.0, cos(t * 2.4 + dot.position.y * 0.02) * 10.0)\ndot.modulate = Color.from_hsv(fmod(t * 0.08 + dot.position.x * 0.0008, 1.0), 0.65, 1.0)"))
	sheet.events.append(wobble)

	if not _compile(sheet, "res://demo/showcase/swarm/swarm.tres", "res://demo/showcase/swarm/swarm.gd"):
		return false

	# Scene: the script-bearing root + a HUD label.
	var root: Node2D = Node2D.new()
	root.name = "Swarm"
	root.set_script(load("res://demo/showcase/swarm/swarm.gd"))
	var label: Label = Label.new()
	label.name = "Info"
	label.position = Vector2(24, 18)
	label.add_theme_font_size_override("font_size", 24)
	label.text = "800 sprites   ·   Budgeted For Each: 90/frame   ·   60 FPS"
	root.add_child(label); label.owner = root
	return _save_scene(root, "res://demo/showcase/swarm/swarm.tscn")


# ── 6. Family Arena (the Families trio: horizontal abstraction) ───────────────
# Demonstrates a FAMILY end-to-end: an `Enemy` Sprite2D whose instances auto-join the family_enemy
# group, with instance variables (health, fall_speed) and a family-bound ACE (take_damage). A separate
# FamilyArena sheet then writes ONE rule per behaviour over ALL enemies (a family For Each), so adding an
# enemy type changes no rules. Also exercises the @ace_family round-trip via the showcase byte-identity gate.
func _build_family_arena() -> bool:
	var tex: ImageTexture = _make_texture()

	# Enemy - a Sprite2D custom node marked as a Family. health/fall_speed are its instance variables.
	var enemy: EventSheetResource = EventSheetResource.new()
	enemy.host_class = "Sprite2D"
	enemy.custom_class_name = "Enemy"
	enemy.is_family = true
	enemy.addon_tags = PackedStringArray(["family", "demo"])
	enemy.class_description = "A falling enemy, marked as a Family so one rule can move or damage every Enemy at once."
	enemy.variables = {
		"health": {"type": "int", "default": 3, "exported": true,
			"attributes": {"tooltip": "Hits this enemy survives before it dies."}},
		"fall_speed": {"type": "float", "default": 90.0, "exported": true,
			"attributes": {"tooltip": "How fast (px/sec) this enemy falls."}}
	}
	# On Ready: join the family group (membership - the "Add To Family" gesture is Add To Group with the
	# family's group) and give each instance its own look + speed.
	var enemy_ready: EventRow = EventRow.new()
	enemy_ready.trigger_provider_id = "Core"; enemy_ready.trigger_id = "OnReady"
	enemy_ready.actions.append(_action("Core", "AddToGroup", "{target}.add_to_group({group})", {"target": "self", "group": "\"family_enemy\""}))
	enemy_ready.actions.append(_raw("fall_speed = randf_range(60.0, 140.0)\nmodulate = Color.from_hsv(randf(), 0.6, 1.0)\nscale = Vector2(0.4, 0.4)"))
	enemy.events.append(enemy_ready)
	# take_damage(amount) - the family-bound ACE: lose health, free at zero.
	var take_damage: EventFunction = EventFunction.new()
	take_damage.function_name = "take_damage"
	take_damage.enabled = true
	take_damage.expose_as_ace = true
	take_damage.ace_display_name = "Take Damage"
	take_damage.ace_category = "Enemy"
	var p_amount: ACEParam = ACEParam.new(); p_amount.id = "amount"; p_amount.type_name = "int"; p_amount.type = TYPE_INT
	take_damage.params = [p_amount]
	take_damage.events = [_raw("health -= amount\nif health <= 0:\n\tqueue_free()")]
	enemy.functions.append(take_damage)
	if not _compile(enemy, "res://demo/showcase/family_arena/enemy.tres", "res://demo/showcase/family_arena/enemy.gd"):
		return false
	# Enemy sub-scene: a Sprite2D bearing the compiled Enemy script.
	var enemy_node: Sprite2D = Sprite2D.new()
	enemy_node.name = "Enemy"
	enemy_node.set_script(load("res://demo/showcase/family_arena/enemy.gd"))
	enemy_node.texture = tex
	if not _save_scene(enemy_node, "res://demo/showcase/family_arena/enemy.tscn"):
		return false

	# FamilyArena - spawns Enemies, then drives them all with FAMILY-SCOPED rules.
	var arena: EventSheetResource = EventSheetResource.new()
	arena.host_class = "Node2D"
	arena.custom_class_name = "FamilyArena"
	var about: CommentRow = CommentRow.new()
	about.text = "[b]Family Arena[/b] - the Families trio in one screen. [b]Enemy[/b] is a Family: a Sprite2D whose instances auto-join the family_enemy group, each carrying its own health + fall_speed. This sheet writes ONE rule per behaviour over ALL of them - a family For Each makes every Enemy fall by its own speed and recycle at the bottom, and a timer damages a random one through the Enemy: Take Damage ACE. Add a new enemy type and not one rule changes - that's horizontal reuse, the thing event sheets were missing."
	arena.events.append(about)
	arena.variables = {
		"spawn_count": {"type": "int", "default": 18, "exported": true,
			"attributes": {"tooltip": "How many Enemies to spawn.", "range": {"min": "4", "max": "60", "step": "1"}}}
	}
	# On Ready: spawn the Enemies into a grid.
	var spawn: EventRow = EventRow.new()
	spawn.trigger_provider_id = "Core"; spawn.trigger_id = "OnReady"
	spawn.actions.append(_raw("var __cols: int = 6\nfor __i: int in range(spawn_count):\n\tvar __e: Sprite2D = load(\"res://demo/showcase/family_arena/enemy.tscn\").instantiate()\n\t__e.position = Vector2(80.0 + float(__i % __cols) * 90.0, 40.0 + float(__i / __cols) * 80.0)\n\tadd_child(__e)"))
	arena.events.append(spawn)
	# On Process: ONE family rule moves every Enemy by its own instance fall_speed + recycles it.
	var fall: EventRow = EventRow.new()
	fall.trigger_provider_id = "Core"; fall.trigger_id = "OnProcess"
	var pf: PickFilter = PickFilter.new()
	pf.enabled = true
	pf.collection_kind = PickFilter.CollectionKind.GROUP
	pf.collection_value = "family_enemy"
	pf.iterator_name = "enemy"
	fall.pick_filters.append(pf)
	fall.actions.append(_raw("enemy.position.y += enemy.fall_speed * delta\nif enemy.position.y > 560.0:\n\tenemy.position.y = -20.0"))
	arena.events.append(fall)
	# Every 0.5s: damage a random Enemy via the family ACE + refresh the HUD count.
	var strike: EventRow = EventRow.new()
	strike.trigger_provider_id = "Core"; strike.trigger_id = "OnProcess"
	strike.conditions.append(_every("strike_fam", "0.5"))
	strike.actions.append(_raw("var __e = get_tree().get_nodes_in_group(\"family_enemy\").pick_random()\nif __e != null:\n\t__e.take_damage(1)"))
	strike.actions.append(_action("Core", "SetTextFormatted", "{target}.text = {template} % [{args}]", {"target": "$Info", "template": "\"%d Enemies · one family For Each moves them all\"", "args": "get_tree().get_node_count_in_group(\"family_enemy\")"}))
	arena.events.append(strike)
	if not _compile(arena, "res://demo/showcase/family_arena/family_arena.tres", "res://demo/showcase/family_arena/family_arena.gd"):
		return false

	# Scene: the FamilyArena root + a HUD label.
	var root: Node2D = Node2D.new()
	root.name = "FamilyArena"
	root.set_script(load("res://demo/showcase/family_arena/family_arena.gd"))
	var label: Label = Label.new()
	label.name = "Info"
	label.position = Vector2(24, 18)
	label.add_theme_font_size_override("font_size", 22)
	label.text = "18 Enemies · one family For Each moves them all"
	root.add_child(label); label.owner = root
	return _save_scene(root, "res://demo/showcase/family_arena/family_arena.tscn")


# ── 7. Inspector Playground (Tier 3 custom drawers + @export grouping) ────────
# Shows off the Custom Inspector features: every exported variable uses a different drawer (direction dial,
# colour swatch row, texture preview, curve, progress bars) across the new value types (Vector2/Color/
# Texture2D/Curve), all sorted into @export_group / @export_subgroup Inspector sections. Select the node and
# open the Inspector to see the rich drawers; press Play and the ship drifts/tints/scales from those same
# designer-tweakable variables - zero code.
func _build_inspector_playground() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "InspectorPlayground"
	sheet.emit_live_values = false
	# Names are group-prefixed (aim_/body_/stat_) so the dict-variable emission's alphabetical order keeps each
	# @export_group's members consecutive. Texture2D/Curve default to null (resource exports have no literal
	# default - assigned in the Inspector).
	sheet.variables = {
		"aim_dir": {"type": "Vector2", "default": Vector2(70, -35), "exported": true,
			"attributes": {"tooltip": "Drift direction + speed - drag the dial.", "group": "Aim", "drawer": "vector_dial", "range": {"min": "0", "max": "120", "step": "1"}}},
		"body_icon": {"type": "Texture2D", "default": null, "exported": true,
			"attributes": {"tooltip": "Emblem texture - drop one in.", "group": "Body", "drawer": "texture_preview"}},
		"body_tint": {"type": "Color", "default": Color("#3aa6e0"), "exported": true,
			"attributes": {"tooltip": "Hull colour - click a swatch.", "group": "Body", "drawer": "swatch_row"}},
		"stat_curve": {"type": "Curve", "default": null, "exported": true,
			"attributes": {"tooltip": "Pulse shape over time.", "group": "Stats", "subgroup": "Tuning", "drawer": "curve_editor"}},
		"stat_health": {"type": "int", "default": 80, "exported": true,
			"attributes": {"tooltip": "Health - drag the bar.", "group": "Stats", "subgroup": "Tuning", "drawer": "progress_bar", "range": {"min": "0", "max": "100", "step": "1"}}},
		"stat_speed": {"type": "float", "default": 90.0, "exported": true,
			"attributes": {"tooltip": "Drift amplitude - drag the bar.", "group": "Stats", "subgroup": "Tuning", "drawer": "progress_bar", "range": {"min": "0", "max": "200", "step": "1"}}}
	}

	var about: CommentRow = CommentRow.new()
	about.text = "[b]Inspector Playground[/b] - select this node and open the Inspector: every exported variable uses a [b]custom drawer[/b] (a direction dial, a colour swatch row, a texture preview, a curve, progress bars) sorted into [b]@export_group[/b] sections. Tweak them and press Play - the ship drifts along the dial, scales with health, and wears your colour. All from designer-tweakable variables, zero code."
	sheet.events.append(about)

	# OnReady: adopt the emblem texture if the designer assigned one.
	var ready_row: EventRow = EventRow.new()
	ready_row.trigger_provider_id = "Core"
	ready_row.trigger_id = "OnReady"
	ready_row.actions.append(_raw("if body_icon != null:\n\t$Emblem.texture = body_icon"))
	sheet.events.append(ready_row)

	# OnProcess: drive the ship live from the tunable variables, so Inspector edits show instantly.
	var move_row: EventRow = EventRow.new()
	move_row.trigger_provider_id = "Core"
	move_row.trigger_id = "OnProcess"
	move_row.actions.append(_raw(
		"var t: float = Time.get_ticks_msec() / 1000.0\n" +
		"var phase: float = sin(t * 2.0) * 0.5 + 0.5\n" +
		"if stat_curve != null and stat_curve.point_count > 0:\n\tphase = stat_curve.sample(phase)\n" +
		"$Body.position = aim_dir.normalized() * (phase - 0.5) * stat_speed\n" +
		"$Body.rotation = aim_dir.angle()\n" +
		"$Body.color = body_tint\n" +
		"$Body.scale = Vector2.ONE * (0.6 + stat_health / 100.0)"))
	sheet.events.append(move_row)

	if not _compile(sheet, "res://demo/showcase/inspector_playground/inspector_playground.tres", "res://demo/showcase/inspector_playground/inspector_playground.gd"):
		return false

	# Scene: a ship Body (Polygon2D, tinted live by body_tint) + a centred Emblem (Sprite2D, default texture).
	var root: Node2D = Node2D.new()
	root.name = "TunableShip"
	root.position = Vector2(288, 180)
	root.set_script(load("res://demo/showcase/inspector_playground/inspector_playground.gd"))
	var body: Polygon2D = Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([Vector2(30, 0), Vector2(-20, 18), Vector2(-8, 0), Vector2(-20, -18)])
	body.color = Color("#3aa6e0")
	root.add_child(body); body.owner = root
	var emblem: Sprite2D = Sprite2D.new()
	emblem.name = "Emblem"
	emblem.texture = _make_texture()
	emblem.scale = Vector2(0.5, 0.5)
	root.add_child(emblem); emblem.owner = root
	var info: Label = Label.new()
	info.name = "Info"
	info.position = Vector2(-268, -160)
	info.add_theme_font_size_override("font_size", 16)
	info.text = "Select this node → the Inspector shows custom drawers\n(dial · swatches · texture · curve · bars) in @export groups.\nTweak them and the ship responds."
	root.add_child(info); info.owner = root
	return _save_scene(root, "res://demo/showcase/inspector_playground/inspector_playground.tscn")


# ── 9. EnemyStats - a Custom Resource with a designed Inspector ──────────────
# The data-asset showcase: a `class_name EnemyStats extends Resource` built entirely from a
# sheet, using the whole rich-inspector surface - accent section headers, an info note, a
# REQUIRED portrait slot, a min-max damage range, a clamped health bar, swatches, an inline
# curve, tooltips, and a rolled-damage helper. Click enemy_stats_example.tres in the
# FileSystem and the Inspector reads like a hand-built tool.


func _build_enemy_stats() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "EnemyStats"
	sheet.emit_live_values = false
	# Names are group-prefixed (combat_/id_/spawn_) so the dict emission's alphabetical order keeps
	# each @export_group's members consecutive; decor sits on each group's first member.
	sheet.variables = {
		"combat_damage_range": {"type": "Vector2", "default": Vector2(4, 11), "exported": true,
			"attributes": {"tooltip": "Damage rolled per hit - x is the low end, y the high.", "group": "Combat",
				"header": "Combat", "header_color": "#e06666", "drawer": "min_max", "range": {"min": "0", "max": "60", "step": "1"}}},
		"combat_falloff": {"type": "Curve", "default": null, "exported": true,
			"attributes": {"tooltip": "Damage multiplier over distance.", "group": "Combat", "drawer": "curve_editor"}},
		"combat_loot": {"type": "Array", "default": [], "exported": true,
			"attributes": {"tooltip": "Drop table - one row per possible drop.", "group": "Combat", "drawer": "table",
				"table_columns": [{"name": "item", "type": "String"}, {"name": "count", "type": "int"}, {"name": "rare", "type": "bool"}]}},
		"combat_max_health": {"type": "int", "default": 120, "exported": true,
			"attributes": {"tooltip": "Hit points - drag the bar.", "group": "Combat", "drawer": "progress_bar",
				"range": {"min": "0", "max": "200", "step": "1"}, "clamp": true}},
		"id_display_name": {"type": "String", "default": "Cave Rat", "exported": true,
			"attributes": {"tooltip": "Shown in dialogs and the bestiary.", "group": "Identity",
				"header": "Identity", "header_color": "#3aa6e0", "placeholder": "e.g. Cave Rat"}},
		"id_portrait": {"type": "Texture2D", "default": null, "exported": true,
			"attributes": {"tooltip": "Bestiary portrait.", "group": "Identity", "drawer": "texture_preview", "required": true}},
		"id_tint": {"type": "Color", "default": Color("#8a5a3b"), "exported": true,
			"attributes": {"tooltip": "Body tint - click a swatch.", "group": "Identity", "drawer": "swatch_row"}},
		"spawn_gap": {"type": "Vector2", "default": Vector2(8, 20), "exported": true,
			"attributes": {"tooltip": "Seconds between spawns - low end to high end.", "group": "Spawning",
				"header": "Spawning", "info": "Shared resource - edits affect every enemy that references it.",
				"drawer": "min_max", "range": {"min": "0", "max": "30", "step": "1"}}}
	}

	var about: CommentRow = CommentRow.new()
	about.text = "[b]EnemyStats[/b] - a Custom Resource whose Inspector was [b]designed from this sheet[/b]: accent section headers, an info note, a [b]required[/b] portrait slot (red warning until assigned), a min-max damage range, a [b]loot table edited as a grid[/b], a clamped health bar, swatches, and an inline curve. Click [i]enemy_stats_example.tres[/i] in the FileSystem to see it; every marker is a plain comment or annotation, so the resource works without the plugin."
	sheet.events.append(about)
	sheet.events.append(_raw("func roll_damage() -> float:\n\treturn randf_range(combat_damage_range.x, combat_damage_range.y)"))

	if not _compile(sheet, "res://demo/showcase/enemy_stats/enemy_stats.tres", "res://demo/showcase/enemy_stats/enemy_stats.gd"):
		return false
	# Compiler output is single-blank by design, but a checked-in showcase .gd is ALSO a repo script,
	# so it must pass the style gate's two-blank-lines-around-functions rule. The importer preserves
	# blank lines, so the byte round-trip the showcase test pins still holds.
	var emitted: String = FileAccess.get_file_as_string("res://demo/showcase/enemy_stats/enemy_stats.gd")
	emitted = emitted.replace("\n\nfunc roll_damage", "\n\n\nfunc roll_damage")
	var out: FileAccess = FileAccess.open("res://demo/showcase/enemy_stats/enemy_stats.gd", FileAccess.WRITE)
	out.store_string(emitted)
	out.close()

	# A saved instance to click in the FileSystem: tuned values, the portrait deliberately left
	# empty so the REQUIRED warning shows the moment the Inspector opens.
	var stats: Resource = (load("res://demo/showcase/enemy_stats/enemy_stats.gd") as GDScript).new() as Resource
	stats.set("id_display_name", "Cave Rat")
	stats.set("combat_max_health", 120)
	stats.set("combat_damage_range", Vector2(4, 11))
	stats.set("combat_loot", [
		{"item": "Rat Tail", "count": 1, "rare": false},
		{"item": "Cheese Wheel", "count": 2, "rare": false},
		{"item": "Plague Blade", "count": 1, "rare": true},
	])
	stats.set("spawn_gap", Vector2(8, 20))
	var falloff: Curve = Curve.new()
	falloff.add_point(Vector2(0.0, 1.0))
	falloff.add_point(Vector2(1.0, 0.25))
	stats.set("combat_falloff", falloff)
	var save_err: Error = ResourceSaver.save(stats, "res://demo/showcase/enemy_stats/enemy_stats_example.tres")
	print("[build_examples] enemy_stats_example.tres save=%d" % save_err)
	return save_err == OK


# ── 10. Menu Starter - a whole menu driven by the HUD Kit pack, zero wiring ───
# The "UI starter": title -> settings -> game -> pause, all screen flips and button
# handling through ONE HudKit behavior by node name. No connected signals in the scene;
# every Button reports through the pack's On Button Pressed.


func _build_menu_starter() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Control"
	sheet.custom_class_name = "MenuStarter"
	sheet.emit_live_values = false
	sheet.variables = {
		"time_alive": {"type": "float", "default": 0.0, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "[b]Menu Starter[/b] - a complete menu flow (title / settings / game / pause overlay) driven by [b]one HUD Kit behavior[/b]: screens switch by NAME, bars and labels update by NAME, and every Button reports through the pack's single [b]On Button Pressed[/b] trigger - the scene contains [b]zero connected signals[/b]. Copy this scene as your project's UI starting point."
	sheet.events.append(about)

	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"
	var on_ready_body: RawCodeRow = RawCodeRow.new()
	on_ready_body.code = "\n".join(PackedStringArray([
		"$HudKit.switch_screen(\"TitleScreen\")",
		"$HudKit.on_button_pressed.connect(handle_button)"
	]))
	on_ready.actions.append(on_ready_body)
	sheet.events.append(on_ready)

	# The in-game clock: proof the HUD updates live while the Game screen is up.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if $HudKit.is_panel_visible(\"GameScreen\"):",
		"\ttime_alive += delta",
		"\t$HudKit.set_text(\"ScoreLabel\", \"Time: %0.1fs\" % time_alive)"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	# The whole menu flow in one reused function, routed by button NAME.
	var handle_fn: EventFunction = EventFunction.new()
	handle_fn.function_name = "handle_button"
	handle_fn.enabled = true
	handle_fn.description = "Routes every menu button by name - the whole flow in one place."
	handle_fn.events = [_raw("\n".join(PackedStringArray([
		"var pressed_button: String = $HudKit.last_button_name_value()",
		"match pressed_button:",
		"\t\"StartButton\":",
		"\t\ttime_alive = 0.0",
		"\t\t$HudKit.switch_screen(\"GameScreen\")",
		"\t\t$HudKit.set_bar(\"HpBar\", 100.0, 100.0)",
		"\t\t$HudKit.show_toast(\"Good luck!\")",
		"\t\"SettingsButton\":",
		"\t\t$HudKit.switch_screen(\"SettingsScreen\")",
		"\t\"BackButton\":",
		"\t\t$HudKit.switch_screen(\"TitleScreen\")",
		"\t\"PauseButton\":",
		"\t\t$HudKit.show_panel(\"PauseScreen\")",
		"\t\"ResumeButton\":",
		"\t\t$HudKit.hide_panel(\"PauseScreen\")",
		"\t\"MenuButton\":",
		"\t\t$HudKit.switch_screen(\"TitleScreen\")",
		"\t\"QuitButton\":",
		"\t\t$HudKit.show_toast(\"Quit is disabled in the demo.\")"
	])))]
	sheet.functions.append(handle_fn)

	if not _compile(sheet, "res://demo/showcase/menu_starter/menu_starter.tres", "res://demo/showcase/menu_starter/menu_starter.gd"):
		return false
	# Compiler output is single-blank; a checked-in showcase .gd is ALSO a repo script, so it must
	# pass the style gate's two-blank-lines-around-functions rule. The importer preserves blank
	# lines, so the byte round-trip the showcase test pins still holds.
	var emitted: String = FileAccess.get_file_as_string("res://demo/showcase/menu_starter/menu_starter.gd")
	emitted = emitted.replace("\n\nfunc ", "\n\n\nfunc ")
	emitted = emitted.replace("\n\n## @ace_hidden\nfunc ", "\n\n\n## @ace_hidden\nfunc ")
	var out: FileAccess = FileAccess.open("res://demo/showcase/menu_starter/menu_starter.gd", FileAccess.WRITE)
	out.store_string(emitted)
	out.close()

	# The scene: four sibling screens under one Screens container + the HudKit behavior.
	var root: Control = Control.new()
	root.name = "MenuStarter"
	root.size = Vector2(1152, 648)
	root.set_script(load("res://demo/showcase/menu_starter/menu_starter.gd"))
	_attach_behavior(root, "HudKit", "res://eventsheet_addons/hud_kit/hud_kit_behavior.gd", root)
	var screens: Control = Control.new()
	screens.name = "Screens"
	screens.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(screens)
	screens.add_child(_menu_screen("TitleScreen", "MENU STARTER", [
		["StartButton", "Start"], ["SettingsButton", "Settings"], ["QuitButton", "Quit"]]))
	screens.add_child(_menu_screen("SettingsScreen", "SETTINGS", [
		["BackButton", "Back"]]))
	var game_screen: VBoxContainer = _menu_screen("GameScreen", "PLAYING", [
		["PauseButton", "Pause"]])
	var hp_bar: ProgressBar = ProgressBar.new()
	hp_bar.name = "HpBar"
	hp_bar.custom_minimum_size = Vector2(260.0, 24.0)
	hp_bar.value = 100.0
	game_screen.add_child(hp_bar)
	var score_label: Label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = "Time: 0.0s"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_screen.add_child(score_label)
	screens.add_child(game_screen)
	screens.add_child(_menu_screen("PauseScreen", "PAUSED", [
		["ResumeButton", "Resume"], ["MenuButton", "Back to Menu"]]))
	# Ownership last: a node can only be owned once it sits inside the owner's tree.
	_own_deep(screens, root)
	return _save_scene(root, "res://demo/showcase/menu_starter/menu_starter.tscn")


## One centred menu screen: a heading plus a column of named buttons (owners assigned later).
func _menu_screen(screen_name: String, heading: String, buttons: Array) -> VBoxContainer:
	var screen: VBoxContainer = VBoxContainer.new()
	screen.name = screen_name
	screen.set_anchors_preset(Control.PRESET_CENTER)
	screen.offset_left = -140.0
	screen.offset_right = 140.0
	screen.offset_top = -120.0
	screen.add_theme_constant_override("separation", 10)
	screen.visible = false
	var title: Label = Label.new()
	title.text = heading
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	screen.add_child(title)
	for button_spec: Array in buttons:
		var button: Button = Button.new()
		button.name = str(button_spec[0])
		button.text = str(button_spec[1])
		screen.add_child(button)
	return screen


func _own_deep(node: Node, root: Node) -> void:
	node.owner = root
	for child: Node in node.get_children():
		_own_deep(child, root)


# ── 12. FPS Arena - first/third-person controller (fps_controller pack) ──────
const FPS_CONTROLLER := "res://eventsheet_addons/fps_controller/fps_controller_behavior.gd"
const NAV_AGENT_3D := "res://eventsheet_addons/nav_agent_3d/nav_agent_3d_behavior.gd"


## A walkable 3D arena driven by the FPSController behavior: mouse look, WASD move, Shift
## sprint, Space jump, Tab flips first/third person (the sheet calls the behavior's ACE),
## Esc frees the mouse. The Player rig (Head > Arm > Camera3D) is the reference layout the
## pack's camera-mode verbs expect.
func _build_fps_arena() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node3D"
	var about: CommentRow = CommentRow.new()
	about.text = "FPS Arena: the FPSController behavior does all the work - this sheet only prints the controls and flips the camera mode on Tab."
	sheet.events.append(about)
	var ready_event: EventRow = EventRow.new()
	ready_event.trigger_provider_id = "Core"
	ready_event.trigger_id = "OnReady"
	ready_event.actions.append(_action("Core", "PrintLog", "print({message})", {
		"message": "\"FPS Arena - WASD/arrows move, mouse looks, Shift sprints, Space jumps, Tab flips the camera, Esc frees the mouse.\""}))
	# Bake the navmesh from the arena's live geometry, then the stalker can path on it.
	ready_event.actions.append(_raw("$Stalker/Navigator.bake_navigation_region($NavRegion)"))
	sheet.events.append(ready_event)
	var camera_toggle: EventRow = EventRow.new()
	camera_toggle.trigger_provider_id = "Core"
	camera_toggle.trigger_id = "OnProcess"
	camera_toggle.actions.append(_raw("if Input.is_action_just_pressed(\"ui_focus_next\"):\n\t$Player/FPSController.toggle_camera_mode()"))
	sheet.events.append(camera_toggle)
	# The stalker: navmesh-path to wherever the player is, once a second (verb symmetry with
	# the 2D Path Chase showcase - same Find Path To Node, different dimension).
	var stalk: EventRow = EventRow.new()
	stalk.trigger_provider_id = "Core"
	stalk.trigger_id = "OnProcess"
	stalk.conditions.append(_every("stalk", "1.0"))
	stalk.actions.append(_raw("$Stalker/Navigator.find_path_to_node($Player, \"nearest\")"))
	sheet.events.append(stalk)
	if not _compile(sheet, "res://demo/showcase/fps_arena/fps_arena.tres", "res://demo/showcase/fps_arena/fps_arena.gd"):
		return false

	var root: Node3D = Node3D.new()
	root.name = "FpsArena"
	root.set_script(load("res://demo/showcase/fps_arena/fps_arena.gd"))

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	sun.shadow_enabled = true
	root.add_child(sun); sun.owner = root

	# Floor + crates live INSIDE the NavigationRegion3D so the runtime bake parses their
	# meshes into the walkable surface (the stalker's world).
	var nav_region: NavigationRegion3D = NavigationRegion3D.new()
	nav_region.name = "NavRegion"
	nav_region.navigation_mesh = NavigationMesh.new()
	root.add_child(nav_region); nav_region.owner = root

	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.name = "Floor"
	nav_region.add_child(floor_body); floor_body.owner = root
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(40.0, 1.0, 40.0)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_shape); floor_shape.owner = root
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var floor_box_mesh: BoxMesh = BoxMesh.new()
	floor_box_mesh.size = Vector3(40.0, 1.0, 40.0)
	var floor_material: StandardMaterial3D = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.32, 0.36, 0.42, 1.0)
	floor_box_mesh.material = floor_material
	floor_mesh.mesh = floor_box_mesh
	floor_mesh.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_mesh); floor_mesh.owner = root

	var crate_material: StandardMaterial3D = StandardMaterial3D.new()
	crate_material.albedo_color = Color(0.75, 0.55, 0.3, 1.0)
	var crate_positions: Array[Vector3] = [
		Vector3(4.0, 1.0, -3.0), Vector3(-5.0, 1.0, -6.0), Vector3(0.0, 1.0, -10.0), Vector3(7.0, 1.0, 4.0)
	]
	for crate_index: int in range(crate_positions.size()):
		var crate: StaticBody3D = StaticBody3D.new()
		crate.name = "Crate%d" % (crate_index + 1)
		crate.position = crate_positions[crate_index]
		nav_region.add_child(crate); crate.owner = root
		var crate_shape: CollisionShape3D = CollisionShape3D.new()
		var crate_box: BoxShape3D = BoxShape3D.new()
		crate_box.size = Vector3(2.0, 2.0, 2.0)
		crate_shape.shape = crate_box
		crate.add_child(crate_shape); crate_shape.owner = root
		var crate_mesh: MeshInstance3D = MeshInstance3D.new()
		var crate_box_mesh: BoxMesh = BoxMesh.new()
		crate_box_mesh.size = Vector3(2.0, 2.0, 2.0)
		crate_box_mesh.material = crate_material
		crate_mesh.mesh = crate_box_mesh
		crate.add_child(crate_mesh); crate_mesh.owner = root

	var player: CharacterBody3D = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0.0, 1.2, 8.0)
	root.add_child(player); player.owner = root
	var player_shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = 0.4
	player_shape.shape = capsule
	player.add_child(player_shape); player_shape.owner = root
	var player_mesh: MeshInstance3D = MeshInstance3D.new()
	var capsule_mesh: CapsuleMesh = CapsuleMesh.new()
	capsule_mesh.height = 1.8
	capsule_mesh.radius = 0.4
	var player_material: StandardMaterial3D = StandardMaterial3D.new()
	player_material.albedo_color = Color(0.4, 0.8, 1.0, 1.0)
	capsule_mesh.material = player_material
	player_mesh.mesh = capsule_mesh
	player.add_child(player_mesh); player_mesh.owner = root
	# The camera rig the pack's verbs drive: Head pitches, the 180-degree-turned Arm extends
	# BEHIND the player in third person (SpringArm3D pushes children along its local -Z), and
	# the camera un-turns so it always faces where the player faces.
	var head: Node3D = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 0.6, 0.0)
	player.add_child(head); head.owner = root
	var arm: SpringArm3D = SpringArm3D.new()
	arm.name = "Arm"
	arm.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	arm.spring_length = 0.05
	head.add_child(arm); arm.owner = root
	var camera: Camera3D = Camera3D.new()
	camera.name = "Camera3D"
	camera.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	camera.current = true
	arm.add_child(camera); camera.owner = root
	_attach_behavior(player, "FPSController", FPS_CONTROLLER, root, {})

	# The stalker: an orange capsule that navmesh-paths to the player via the Nav Agent 3D
	# pack's built-in driver (no FPS Controller on it - the fallback moves the body itself).
	var stalker: CharacterBody3D = CharacterBody3D.new()
	stalker.name = "Stalker"
	stalker.position = Vector3(-12.0, 1.2, -12.0)
	root.add_child(stalker); stalker.owner = root
	var stalker_shape: CollisionShape3D = CollisionShape3D.new()
	var stalker_capsule: CapsuleShape3D = CapsuleShape3D.new()
	stalker_capsule.height = 1.8
	stalker_capsule.radius = 0.4
	stalker_shape.shape = stalker_capsule
	stalker.add_child(stalker_shape); stalker_shape.owner = root
	var stalker_mesh: MeshInstance3D = MeshInstance3D.new()
	var stalker_capsule_mesh: CapsuleMesh = CapsuleMesh.new()
	stalker_capsule_mesh.height = 1.8
	stalker_capsule_mesh.radius = 0.4
	var stalker_material: StandardMaterial3D = StandardMaterial3D.new()
	stalker_material.albedo_color = Color(1.0, 0.5, 0.2, 1.0)
	stalker_capsule_mesh.material = stalker_material
	stalker_mesh.mesh = stalker_capsule_mesh
	stalker.add_child(stalker_mesh); stalker_mesh.owner = root
	_attach_behavior(stalker, "Navigator", NAV_AGENT_3D, root, {"move_speed": 3.0})

	var hud_layer: CanvasLayer = CanvasLayer.new()
	hud_layer.name = "HudLayer"
	root.add_child(hud_layer); hud_layer.owner = root
	var hud: Label = Label.new()
	hud.name = "Hud"
	hud.position = Vector2(24.0, 20.0)
	hud.add_theme_font_size_override("font_size", 20)
	hud.text = "WASD/arrows move · mouse looks · Shift sprints · Space jumps · Tab flips camera · Esc frees mouse\nThe orange Stalker navmesh-paths to you (Nav Agent 3D)"
	hud_layer.add_child(hud); hud.owner = root

	return _save_scene(root, "res://demo/showcase/fps_arena/fps_arena.tscn")


# ── 13. Input Rebind - a working rebind screen from the input vocabulary ─────


## A playable options-menu slice: two actions (jump/dash) with live binding labels, a
## click-then-press-anything rebind flow that accepts KEYBOARD, MOUSE, or GAMEPAD input
## (InputMap.action_add_event takes the captured event verbatim), a demo-defaults reset, and a
## gamepad panel (count + product name every frame, test vibration). The actions are created at
## RUNTIME (Add Input Action) so the demo never touches project.godot. UI is one HUD Kit
## behavior: labels update by NAME, every Button reports through On Button Pressed - zero
## connected signals in the scene.
func _build_input_rebind() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Control"
	sheet.custom_class_name = "InputRebindDemo"
	sheet.emit_live_values = false
	sheet.variables = {
		"rebinding_action": {"type": "String", "default": "", "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "[b]Input Rebind[/b] - a working rebind screen built from the Input/InputMap/Gamepad vocabulary: click Rebind, then press ANY key, mouse button, or gamepad button (the captured event binds verbatim). Binding labels read InputMap.action_get_events(...).as_text() - the Action Binding As Text pattern. Actions are created at runtime, so the demo leaves your project's Input Map alone."
	sheet.events.append(about)

	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"
	var on_ready_body: RawCodeRow = RawCodeRow.new()
	on_ready_body.code = "\n".join(PackedStringArray([
		"setup_default_bindings()",
		"$HudKit.on_button_pressed.connect(handle_button)",
		"$HudKit.set_text(\"StatusLabel\", \"Click a Rebind button, then press any input.\")"
	]))
	on_ready.actions.append(on_ready_body)
	sheet.events.append(on_ready)

	# The capture step: while a rebind is armed, the FIRST pressed input of any device becomes
	# the action's whole binding. _input sees the event raw, before any UI eats it.
	var on_input: EventRow = EventRow.new()
	on_input.trigger_provider_id = "Core"
	on_input.trigger_id = "OnInput"
	var on_input_body: RawCodeRow = RawCodeRow.new()
	on_input_body.code = "\n".join(PackedStringArray([
		"if rebinding_action == \"\":",
		"\treturn",
		"if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadButton and event.pressed):",
		"\tInputMap.action_erase_events(rebinding_action)",
		"\tInputMap.action_add_event(rebinding_action, event)",
		"\t$HudKit.set_text(\"StatusLabel\", \"%s bound to %s\" % [rebinding_action.capitalize(), event.as_text()])",
		"\trebinding_action = \"\"",
		"\trefresh_binding_labels()"
	]))
	on_input.actions.append(on_input_body)
	sheet.events.append(on_input)

	# Live feedback: test the actions wherever they are bound now + the gamepad panel.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if Input.is_action_just_pressed(\"demo_jump\"):",
		"\t$HudKit.show_toast(\"Jump!\")",
		"if Input.is_action_just_pressed(\"demo_dash\"):",
		"\t$HudKit.show_toast(\"Dash!\")",
		"var pads: Array = Input.get_connected_joypads()",
		"if pads.is_empty():",
		"\t$HudKit.set_text(\"GamepadLabel\", \"No gamepad connected - plug one in\")",
		"else:",
		"\t$HudKit.set_text(\"GamepadLabel\", \"%d gamepad(s) - %s\" % [pads.size(), Input.get_joy_name(pads[0])])"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	var handle_fn: EventFunction = EventFunction.new()
	handle_fn.function_name = "handle_button"
	handle_fn.enabled = true
	handle_fn.description = "Routes every button by name: arm a rebind, reset the defaults, or buzz the gamepad."
	handle_fn.events = [_raw("\n".join(PackedStringArray([
		"var pressed_button: String = $HudKit.last_button_name_value()",
		"match pressed_button:",
		"\t\"RebindJumpButton\":",
		"\t\trebinding_action = \"demo_jump\"",
		"\t\t$HudKit.set_text(\"StatusLabel\", \"Press any key, mouse or gamepad button to bind Jump…\")",
		"\t\"RebindDashButton\":",
		"\t\trebinding_action = \"demo_dash\"",
		"\t\t$HudKit.set_text(\"StatusLabel\", \"Press any key, mouse or gamepad button to bind Dash…\")",
		"\t\"ResetButton\":",
		"\t\tsetup_default_bindings()",
		"\t\t$HudKit.set_text(\"StatusLabel\", \"Bindings restored to the demo defaults.\")",
		"\t\"VibrateButton\":",
		"\t\tInput.start_joy_vibration(0, 0.5, 0.5, 0.4)",
		"\t\t$HudKit.set_text(\"StatusLabel\", \"Vibrating gamepad 0 (if one is connected).\")"
	])))]
	sheet.functions.append(handle_fn)

	# Demo-defaults (NOT Restore Default Bindings: these actions live only at runtime, so
	# InputMap.load_from_project_settings() would erase them instead of resetting them).
	var setup_fn: EventFunction = EventFunction.new()
	setup_fn.function_name = "setup_default_bindings"
	setup_fn.enabled = true
	setup_fn.description = "Creates the demo actions if missing and binds Jump=Space, Dash=C."
	setup_fn.events = [_raw("\n".join(PackedStringArray([
		"if not InputMap.has_action(\"demo_jump\"):",
		"\tInputMap.add_action(\"demo_jump\")",
		"if not InputMap.has_action(\"demo_dash\"):",
		"\tInputMap.add_action(\"demo_dash\")",
		"InputMap.action_erase_events(\"demo_jump\")",
		"var jump_key: InputEventKey = InputEventKey.new()",
		"jump_key.physical_keycode = KEY_SPACE",
		"InputMap.action_add_event(\"demo_jump\", jump_key)",
		"InputMap.action_erase_events(\"demo_dash\")",
		"var dash_key: InputEventKey = InputEventKey.new()",
		"dash_key.physical_keycode = KEY_C",
		"InputMap.action_add_event(\"demo_dash\", dash_key)",
		"refresh_binding_labels()"
	])))]
	sheet.functions.append(setup_fn)

	var refresh_fn: EventFunction = EventFunction.new()
	refresh_fn.function_name = "refresh_binding_labels"
	refresh_fn.enabled = true
	refresh_fn.description = "Prints each action's current binding as readable text next to its row."
	refresh_fn.events = [_raw("\n".join(PackedStringArray([
		"$HudKit.set_text(\"JumpLabel\", \"Jump: %s\" % binding_text(\"demo_jump\"))",
		"$HudKit.set_text(\"DashLabel\", \"Dash: %s\" % binding_text(\"demo_dash\"))"
	])))]
	sheet.functions.append(refresh_fn)

	var binding_fn: EventFunction = EventFunction.new()
	binding_fn.function_name = "binding_text"
	binding_fn.enabled = true
	binding_fn.return_type = TYPE_STRING
	binding_fn.description = "An action's first binding as readable text (the Action Binding As Text pattern)."
	var binding_param: ACEParam = ACEParam.new()
	binding_param.id = "action_name"
	binding_param.type_name = "String"
	binding_fn.params.append(binding_param)
	binding_fn.events = [_raw("\n".join(PackedStringArray([
		"var events: Array = InputMap.action_get_events(action_name)",
		"return events[0].as_text() if not events.is_empty() else \"unbound\""
	])))]
	sheet.functions.append(binding_fn)

	if not _compile(sheet, "res://demo/showcase/input_rebind/input_rebind.tres", "res://demo/showcase/input_rebind/input_rebind.gd"):
		return false
	var emitted: String = FileAccess.get_file_as_string("res://demo/showcase/input_rebind/input_rebind.gd")
	emitted = emitted.replace("\n\nfunc ", "\n\n\nfunc ")
	emitted = emitted.replace("\n\n## @ace_hidden\nfunc ", "\n\n\n## @ace_hidden\nfunc ")
	var out: FileAccess = FileAccess.open("res://demo/showcase/input_rebind/input_rebind.gd", FileAccess.WRITE)
	out.store_string(emitted)
	out.close()

	# The scene: one centred column of named labels/buttons + the HudKit behavior.
	var root: Control = Control.new()
	root.name = "InputRebindDemo"
	root.size = Vector2(1152, 648)
	root.set_script(load("res://demo/showcase/input_rebind/input_rebind.gd"))
	_attach_behavior(root, "HudKit", "res://eventsheet_addons/hud_kit/hud_kit_behavior.gd", root)
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.offset_left = -220.0
	column.offset_right = 220.0
	column.offset_top = -180.0
	column.add_theme_constant_override("separation", 12)
	root.add_child(column)
	var title: Label = Label.new()
	title.name = "TitleLabel"
	title.text = "INPUT REBINDING + GAMEPAD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	var info: Label = Label.new()
	info.name = "InfoLabel"
	info.text = "Click Rebind, then press any key, mouse button, or gamepad button.\nTest with your bindings: Jump toasts, Dash toasts."
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 13)
	column.add_child(info)
	column.add_child(_binding_row("JumpLabel", "Jump: Space", "RebindJumpButton"))
	column.add_child(_binding_row("DashLabel", "Dash: C", "RebindDashButton"))
	var reset_button: Button = Button.new()
	reset_button.name = "ResetButton"
	reset_button.text = "Restore Demo Defaults"
	column.add_child(reset_button)
	var status: Label = Label.new()
	status.name = "StatusLabel"
	status.text = ""
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(status)
	var gamepad: Label = Label.new()
	gamepad.name = "GamepadLabel"
	gamepad.text = "No gamepad connected - plug one in"
	gamepad.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(gamepad)
	var vibrate_button: Button = Button.new()
	vibrate_button.name = "VibrateButton"
	vibrate_button.text = "Test Gamepad Vibration"
	column.add_child(vibrate_button)
	_own_deep(column, root)
	return _save_scene(root, "res://demo/showcase/input_rebind/input_rebind.tscn")


# ── 14. Path Chase - Platformer Pathfinding driving Platformer Movement ──────
const PLATFORMER_MOVEMENT := "res://eventsheet_addons/platformer_movement/platformer_movement_behavior.gd"
const PLATFORMER_PATHFINDING := "res://eventsheet_addons/platformer_pathfinding/platformer_pathfinding_behavior.gd"


## The pathfinding pairing showcase: a tile level (ground with a gap + an escapable pit, a
## two-step stair to a mid platform, a hop, a high platform, and a floating platform that is
## PORTAL-ONLY), a keyboard-driven Player, and a Chaser whose PlatformerPathfinding behavior
## routes to the Player once a second and DRIVES the sibling PlatformerMovement through its
## ai_move_axis seam. A tile BRIDGE across the gap toggles every 3 seconds (Regenerate Nav
## Graph after each toggle) so the route flips between walking the bridge and jumping the gap,
## the portal blinks the Chaser up to the floating platform, and variable jump keeps flat hops
## low. Green line = the live path.
func _build_path_chase() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "PathChaseDemo"
	sheet.emit_live_values = false
	sheet.variables = {
		"bridge_on": {"type": "bool", "default": false, "exported": false},
		"platform_time": {"type": "float", "default": 0.0, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "[b]Path Chase[/b] - Platformer Pathfinding + Platformer Movement on one Chaser: the graph is built from the TileMapLayer once, then Find Path To Node re-routes to the Player every second. The pathfinder derives jump reach from the movement pack and steers it through the ai_move_axis seam - the same movement rules you play with, variable jump included. The purple PORTAL pair links the ground to the floating platform, the tile BRIDGE over the gap toggles every 3 seconds + Regenerate Nav Graph, the red zone is a DEADLY HAZARD routes refuse (forcing the high-platform detour), and the orange ELEVATOR is a registered moving platform - the Chaser waits for it, rides it, and walks off onto the tower. Green line = the Chaser's path."
	sheet.events.append(about)

	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"
	var on_ready_body: RawCodeRow = RawCodeRow.new()
	on_ready_body.code = "\n".join(PackedStringArray([
		"$Chaser/Pathfinding.build_nav_graph($Level)",
		"$Chaser/Pathfinding.add_portal(976.0, 528.0, 176.0, 304.0, true)",
		"$Chaser/Pathfinding.add_hazard(704.0, 512.0, 192.0, 64.0, true)",
		"$Chaser/Pathfinding.add_moving_platform($MovingPlatform, 1088.0, 552.0, 1088.0, 200.0)",
		"$Chaser/Pathfinding.set_nav_debug_draw(true)"
	]))
	on_ready.actions.append(on_ready_body)
	sheet.events.append(on_ready)

	# The elevator: an AnimatableBody2D ping-ponging between exactly the registered endpoints
	# (the pack navigates it; the sheet owns the motion - moved in physics so riders carry).
	var elevator: EventRow = EventRow.new()
	elevator.trigger_provider_id = "Core"
	elevator.trigger_id = "OnPhysicsProcess"
	var elevator_body: RawCodeRow = RawCodeRow.new()
	elevator_body.code = "\n".join(PackedStringArray([
		"# 8s cycle with 1.5s DWELLS at both ends - the pathfinder boards only a parked platform.",
		"platform_time = fmod(platform_time + delta, 8.0)",
		"var travel: float = 0.0",
		"if platform_time < 1.5:",
		"\ttravel = 0.0",
		"elif platform_time < 4.0:",
		"\ttravel = (platform_time - 1.5) / 2.5 * 352.0",
		"elif platform_time < 5.5:",
		"\ttravel = 352.0",
		"else:",
		"\ttravel = (1.0 - (platform_time - 5.5) / 2.5) * 352.0",
		"$MovingPlatform.global_position = Vector2(1088.0, 552.0 - travel)"
	]))
	elevator.actions.append(elevator_body)
	sheet.events.append(elevator)

	# The chase: re-route to wherever the Player is now, once a second.
	var repath: EventRow = EventRow.new()
	repath.trigger_provider_id = "Core"
	repath.trigger_id = "OnProcess"
	repath.conditions.append(_every("repath", "1.0"))
	var repath_body: RawCodeRow = RawCodeRow.new()
	repath_body.code = "$Chaser/Pathfinding.find_path_to_node($Player, \"nearest\")"
	repath.actions.append(repath_body)
	sheet.events.append(repath)

	# The moving object: a tile bridge across the gap appears/vanishes every 3 seconds, and
	# one Regenerate Nav Graph makes the router see the new level instantly.
	var bridge: EventRow = EventRow.new()
	bridge.trigger_provider_id = "Core"
	bridge.trigger_id = "OnProcess"
	bridge.conditions.append(_every("bridge", "3.0"))
	var bridge_body: RawCodeRow = RawCodeRow.new()
	bridge_body.code = "toggle_bridge()"
	bridge.actions.append(bridge_body)
	sheet.events.append(bridge)

	var bridge_fn: EventFunction = EventFunction.new()
	bridge_fn.function_name = "toggle_bridge"
	bridge_fn.enabled = true
	bridge_fn.description = "Places or removes the bridge tiles over the gap, then rebuilds the nav graph so routes flip between walking the bridge and jumping the gap."
	bridge_fn.events = [_raw("\n".join(PackedStringArray([
		"bridge_on = not bridge_on",
		"for x in range(15, 18):",
		"\tif bridge_on:",
		"\t\t$Level.set_cell(Vector2i(x, 17), 0, Vector2i.ZERO)",
		"\telse:",
		"\t\t$Level.erase_cell(Vector2i(x, 17))",
		"$Chaser/Pathfinding.regenerate_nav_graph()"
	])))]
	sheet.functions.append(bridge_fn)

	# Player jump keys (movement itself reads ui_left/ui_right on its own).
	var jump_keys: EventRow = EventRow.new()
	jump_keys.trigger_provider_id = "Core"
	jump_keys.trigger_id = "OnProcess"
	var jump_keys_body: RawCodeRow = RawCodeRow.new()
	jump_keys_body.code = "\n".join(PackedStringArray([
		"if Input.is_action_just_pressed(\"ui_accept\"):",
		"\t$Player/Movement.jump()",
		"if Input.is_action_just_released(\"ui_accept\"):",
		"\t$Player/Movement.jump_released()"
	]))
	jump_keys.actions.append(jump_keys_body)
	sheet.events.append(jump_keys)

	if not _compile(sheet, "res://demo/showcase/path_chase/path_chase.tres", "res://demo/showcase/path_chase/path_chase.gd"):
		return false
	var emitted: String = FileAccess.get_file_as_string("res://demo/showcase/path_chase/path_chase.gd")
	emitted = emitted.replace("\n\nfunc ", "\n\n\nfunc ")
	emitted = emitted.replace("\n\n## @ace_hidden\nfunc ", "\n\n\n## @ace_hidden\nfunc ")
	var out: FileAccess = FileAccess.open("res://demo/showcase/path_chase/path_chase.gd", FileAccess.WRITE)
	out.store_string(emitted)
	out.close()

	# ── The scene ──
	var root: Node2D = Node2D.new()
	root.name = "PathChase"
	root.set_script(load("res://demo/showcase/path_chase/path_chase.gd"))

	# The level: ground with a 3-cell gap (pit floor below, escapable), a two-step stair onto
	# a mid platform, a hop platform, a high platform, and a floating platform reachable ONLY
	# through the portal. 32px tiles.
	var level: TileMapLayer = TileMapLayer.new()
	level.name = "Level"
	level.tile_set = _chase_tileset()
	for x in range(1, 35):
		if x < 15 or x > 17:
			level.set_cell(Vector2i(x, 17), 0, Vector2i.ZERO)
	for x in range(15, 18):
		level.set_cell(Vector2i(x, 19), 0, Vector2i.ZERO)
	for wall_y in range(10, 18):
		level.set_cell(Vector2i(0, wall_y), 0, Vector2i.ZERO)
		level.set_cell(Vector2i(35, wall_y), 0, Vector2i.ZERO)
	level.set_cell(Vector2i(7, 16), 0, Vector2i.ZERO)
	level.set_cell(Vector2i(8, 16), 0, Vector2i.ZERO)
	level.set_cell(Vector2i(8, 15), 0, Vector2i.ZERO)
	for x in range(9, 13):
		level.set_cell(Vector2i(x, 15), 0, Vector2i.ZERO)
	for x in range(19, 21):
		level.set_cell(Vector2i(x, 15), 0, Vector2i.ZERO)
	for x in range(22, 28):
		level.set_cell(Vector2i(x, 13), 0, Vector2i.ZERO)
	for x in range(3, 9):
		level.set_cell(Vector2i(x, 10), 0, Vector2i.ZERO)
	# The tower: reachable ONLY by riding the elevator (11 cells above the ground).
	for x in range(30, 33):
		level.set_cell(Vector2i(x, 6), 0, Vector2i.ZERO)
	root.add_child(level)
	level.owner = root

	# The deadly hazard (spikes): a red zone on the ground under the high platform - routes
	# refuse it, forcing the scenic detour OVER the platform. Visual only; the routing rect
	# is the sheet's add_hazard call.
	var hazard_zone: ColorRect = ColorRect.new()
	hazard_zone.name = "HazardZone"
	hazard_zone.color = Color(1.0, 0.25, 0.2, 0.35)
	hazard_zone.position = Vector2(704.0, 512.0)
	hazard_zone.size = Vector2(160.0, 64.0)
	root.add_child(hazard_zone)
	hazard_zone.owner = root

	# The elevator: an AnimatableBody2D the sheet ping-pongs between the registered endpoints.
	var moving_platform: AnimatableBody2D = AnimatableBody2D.new()
	moving_platform.name = "MovingPlatform"
	moving_platform.position = Vector2(1088.0, 552.0)
	moving_platform.sync_to_physics = true
	var platform_collider: CollisionShape2D = CollisionShape2D.new()
	platform_collider.name = "Collider"
	var platform_shape: RectangleShape2D = RectangleShape2D.new()
	# 48 wide: the shaft clears both the tower's east edge and the boundary wall by 8px, so a
	# body resting at either lip is never clipped by the moving collider (an AnimatableBody2D
	# push is effectively infinite-mass - grazing it ejects a CharacterBody2D violently).
	platform_shape.size = Vector2(48.0, 16.0)
	platform_collider.shape = platform_shape
	moving_platform.add_child(platform_collider)
	var platform_visual: ColorRect = ColorRect.new()
	platform_visual.name = "Visual"
	platform_visual.color = Color(1.0, 0.62, 0.2)
	platform_visual.position = Vector2(-24.0, -8.0)
	platform_visual.size = Vector2(48.0, 16.0)
	moving_platform.add_child(platform_visual)
	root.add_child(moving_platform)
	_own_deep(moving_platform, root)

	# The portal pair: entrance on the right ground, exit on the floating platform (the
	# platform is 7 cells up - portal-only by design). Purple markers are visuals; the LINK
	# is the sheet's add_portal call.
	for portal_spec: Array in [["PortalEntrance", Vector2(976.0, 528.0)], ["PortalExit", Vector2(176.0, 304.0)]]:
		var portal_marker: ColorRect = ColorRect.new()
		portal_marker.name = str(portal_spec[0])
		portal_marker.color = Color(0.72, 0.4, 1.0, 0.85)
		portal_marker.position = (portal_spec[1] as Vector2) + Vector2(-10.0, -26.0)
		portal_marker.size = Vector2(20.0, 42.0)
		root.add_child(portal_marker)
		portal_marker.owner = root

	var player: CharacterBody2D = _chase_actor("Player", Vector2(208.0, 288.0), Color(0.35, 0.65, 1.0))
	root.add_child(player)
	_own_deep(player, root)
	_attach_behavior(player, "Movement", PLATFORMER_MOVEMENT, root)
	var chaser: CharacterBody2D = _chase_actor("Chaser", Vector2(112.0, 512.0), Color(1.0, 0.35, 0.35))
	root.add_child(chaser)
	_own_deep(chaser, root)
	_attach_behavior(chaser, "Movement", PLATFORMER_MOVEMENT, root)
	_attach_behavior(chaser, "Pathfinding", PLATFORMER_PATHFINDING, root)

	var hud_layer: CanvasLayer = CanvasLayer.new()
	hud_layer.name = "HudLayer"
	root.add_child(hud_layer)
	hud_layer.owner = root
	var hud: Label = Label.new()
	hud.name = "Hud"
	hud.position = Vector2(24.0, 16.0)
	hud.add_theme_font_size_override("font_size", 18)
	hud.text = "Arrows move · Space jumps · the red Chaser pathfinds to you (green = its path)\nPurple = portal · red zone = deadly hazard (routes refuse it) · the bridge toggles every 3s\nOrange elevator = a moving platform: stand on the tower and watch it wait, ride, and walk off"
	hud_layer.add_child(hud)
	hud.owner = root

	return _save_scene(root, "res://demo/showcase/path_chase/path_chase.tscn")


## A 32px TileSet with one solid grey physics tile (source id 0, atlas (0,0)).
func _chase_tileset() -> TileSet:
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	tile_set.add_physics_layer()
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	var image: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.42, 0.45, 0.52))
	for edge in range(32):
		image.set_pixel(edge, 0, Color(0.55, 0.58, 0.66))
		image.set_pixel(edge, 31, Color(0.3, 0.32, 0.38))
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(32, 32)
	# The source must join the set before tile data is configured (physics layers live on the set).
	tile_set.add_source(source, 0)
	source.create_tile(Vector2i.ZERO)
	var tile_data: TileData = source.get_tile_data(Vector2i.ZERO, 0)
	tile_data.add_collision_polygon(0)
	tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]))
	return tile_set


## One chase actor: a CharacterBody2D with a 22x28 collider and a coloured box visual.
func _chase_actor(actor_name: String, world_position: Vector2, tint: Color) -> CharacterBody2D:
	var actor: CharacterBody2D = CharacterBody2D.new()
	actor.name = actor_name
	actor.position = world_position
	var collider: CollisionShape2D = CollisionShape2D.new()
	collider.name = "Collider"
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(22.0, 28.0)
	collider.shape = shape
	actor.add_child(collider)
	var visual: ColorRect = ColorRect.new()
	visual.name = "Visual"
	visual.color = tint
	visual.position = Vector2(-11.0, -14.0)
	visual.size = Vector2(22.0, 28.0)
	actor.add_child(visual)
	return actor


## One rebind row: the live binding label on the left, the named Rebind button on the right.
func _binding_row(label_name: String, label_text: String, button_name: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = label_name + "Row"
	row.add_theme_constant_override("separation", 14)
	var label: Label = Label.new()
	label.name = label_name
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 18)
	row.add_child(label)
	var button: Button = Button.new()
	button.name = button_name
	button.text = "Rebind"
	row.add_child(button)
	return row


# ── Draw Lab (Drawing Canvas feature tour) ──────────────────────────────────


const EIGHT_DIRECTION := "res://eventsheet_addons/eight_direction/eight_direction_movement_behavior.gd"
const DRAWING_CANVAS := "res://eventsheet_addons/drawing_canvas/drawing_canvas_behavior.gd"
const DRAWING_PREFAB := "res://eventsheet_addons/drawing_prefab_resource/drawing_prefab_resource.gd"


## The Drawing Canvas showcase: four canvases with different jobs on one screen. The Player
## carries an auto-clear canvas drawing a live LINE OF SIGHT fan the walls carve; an Enemy
## carries one drawing a rotating attack-telegraph cone; a whole-screen persistent canvas
## collects a paint trail plus DRAWING PREFABS (a target-marker formation authored as a
## .tres, stamped with Space); and a center auto-clear canvas runs a ribbon trailing an
## orbiting comet.
func _build_draw_lab() -> bool:
	# The prefab asset: an ordered target-marker formation the sheet stamps around.
	var prefab: Resource = (load(DRAWING_PREFAB) as GDScript).new()
	prefab.set("prefab_name", "target_marker")
	prefab.set("steps", [
		{"kind": "ring", "x": 0.0, "y": 0.0, "p1": 46.0, "p2": 5.0, "p3": 0.0, "color": "#ffd24d", "texture": ""},
		{"kind": "ring", "x": 0.0, "y": 0.0, "p1": 18.0, "p2": 3.0, "p3": 0.0, "color": "#ffd24d", "texture": ""},
		{"kind": "line", "x": -60.0, "y": 0.0, "p1": 60.0, "p2": 0.0, "p3": 3.0, "color": "#ffd24dcc", "texture": ""},
		{"kind": "line", "x": 0.0, "y": -60.0, "p1": 0.0, "p2": 60.0, "p3": 3.0, "color": "#ffd24dcc", "texture": ""},
		{"kind": "circle", "x": 40.0, "y": -40.0, "p1": 5.0, "p2": 0.0, "p3": 0.0, "color": "#ff8844", "texture": ""},
		{"kind": "circle", "x": -40.0, "y": -40.0, "p1": 5.0, "p2": 0.0, "p3": 0.0, "color": "#ff8844", "texture": ""},
		{"kind": "circle", "x": 40.0, "y": 40.0, "p1": 5.0, "p2": 0.0, "p3": 0.0, "color": "#ff8844", "texture": ""},
		{"kind": "circle", "x": -40.0, "y": 40.0, "p1": 5.0, "p2": 0.0, "p3": 0.0, "color": "#ff8844", "texture": ""}
	])
	DirAccess.make_dir_recursive_absolute("res://demo/showcase/draw_lab")
	if ResourceSaver.save(prefab, "res://demo/showcase/draw_lab/target_marker.tres") != OK:
		push_error("[build_examples] draw_lab: could not save target_marker.tres")
		return false

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "DrawLabDemo"
	sheet.emit_live_values = false
	sheet.variables = {
		"facing_deg": {"type": "float", "default": 0.0, "exported": false},
		"comet_angle": {"type": "float", "default": 0.0, "exported": false},
		"paste_timer": {"type": "float", "default": 0.0, "exported": false},
		"baked": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "[b]Draw Lab[/b] - four Drawing Canvases with different jobs. The Player carries an AUTO-CLEAR canvas redrawing a raycast Line Of Sight fan every tick (the walls carve it); the Enemy carries one redrawing a rotating attack-telegraph cone; the whole-screen PERSISTENT canvas keeps everything drawn on it - the paint trail dripping under the Player and the target-marker DRAWING PREFABS (an ordered shape formation authored as a .tres, replayed by Draw Prefab at any position/scale/rotation - press Space to stamp one where you stand); and the center canvas ribbons the orbiting comet."
	sheet.events.append(about)

	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"
	var ready_body: RawCodeRow = RawCodeRow.new()
	ready_body.code = "\n".join(PackedStringArray([
		"# Three prefab stampings prove position / scale / rotation reuse of ONE .tres.",
		"var marker: Resource = load(\"res://demo/showcase/draw_lab/target_marker.tres\")",
		"$PaintLayer/Paint.draw_prefab(marker, 180.0, 140.0, 1.0, 0.0)",
		"$PaintLayer/Paint.draw_prefab(marker, 980.0, 500.0, 0.6, 45.0)",
		"$PaintLayer/Paint.draw_prefab(marker, 180.0, 520.0, 1.4, 15.0)",
		"$FxLayer/Fx.start_ribbon($Comet, 34, 7.0, Color(0.45, 0.9, 1.0, 0.85))",
		"# Paste demo - build one gem texture and give the orbiting comet a gem icon. The tick leaves a",
		"# Paste Node trail behind it and bakes a whole gem LAYER onto the canvas on its first run.",
		"var gem_image: Image = Image.create(20, 20, false, Image.FORMAT_RGBA8)",
		"gem_image.fill(Color(0.0, 0.0, 0.0, 0.0))",
		"for gem_y: int in 20:",
		"\tfor gem_x: int in 20:",
		"\t\tif absi(gem_x - 10) + absi(gem_y - 10) <= 8:",
		"\t\t\tgem_image.set_pixel(gem_x, gem_y, Color(1.0, 0.84, 0.32))",
		"var comet_icon: Sprite2D = Sprite2D.new()",
		"comet_icon.name = \"Icon\"",
		"comet_icon.texture = ImageTexture.create_from_image(gem_image)",
		"$Comet.add_child(comet_icon)"
	]))
	on_ready.actions.append(ready_body)
	sheet.events.append(on_ready)

	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnPhysicsProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"facing_deg += 40.0 * delta",
		"comet_angle += 1.4 * delta",
		"$Comet.position = Vector2(576.0, 324.0) + Vector2.from_angle(comet_angle) * 205.0",
		"# The live drawings: re-issued every tick, wiped by their AUTO-CLEAR canvases.",
		"$Player/Vision.draw_line_of_sight($Player.global_position.x, $Player.global_position.y, facing_deg, 80.0, 280.0, 1, Color(1.0, 0.92, 0.45, 0.3))",
		"$Enemy/Telegraph.draw_canvas_cone($Enemy.global_position.x, $Enemy.global_position.y, -facing_deg * 1.5, 50.0, 170.0, Color(1.0, 0.3, 0.25, 0.4))",
		"if Input.is_action_just_pressed(\"ui_accept\"):",
		"\t$PaintLayer/Paint.draw_prefab(load(\"res://demo/showcase/draw_lab/target_marker.tres\"), $Player.global_position.x, $Player.global_position.y, 0.8, facing_deg)",
		"# Paste Node the orbiting comet's gem onto the PERSISTENT canvas ~8x a second: a trail of baked",
		"# gem stamps follows the orbit (the discrete-decal counterpart to the comet's live cyan ribbon).",
		"paste_timer -= delta",
		"if paste_timer <= 0.0 and $Comet.has_node(\"Icon\"):",
		"\tpaste_timer = 0.12",
		"\t$PaintLayer/Paint.paste_node($Comet/Icon)",
		"# Paste Layer In Box (once, at load): scatter a gem LAYER, bake every gem inside the box onto the",
		"# persistent canvas, then free the originals - one texture instead of N sprites. Done on the first",
		"# live tick (an on-ready bake would buffer before the canvas surface exists).",
		"if not baked and $Comet.has_node(\"Icon\"):",
		"\tbaked = true",
		"\tvar gem_texture: Texture2D = $Comet/Icon.texture",
		"\tvar gems: Node2D = Node2D.new()",
		"\tadd_child(gems)",
		"\tfor gem_spot: Vector2 in [Vector2(80.0, 185.0), Vector2(150.0, 185.0), Vector2(220.0, 185.0), Vector2(290.0, 185.0), Vector2(360.0, 185.0)]:",
		"\t\tvar gem: Sprite2D = Sprite2D.new()",
		"\t\tgem.texture = gem_texture",
		"\t\tgems.add_child(gem)",
		"\t\tgem.global_position = gem_spot",
		"\t$DecorLayer/Decor.paste_layer_in_box(gems, 50.0, 170.0, 340.0, 35.0)",
		"\tgems.queue_free()"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	# The paint trail: a persistent splat under the Player, ten times a second - the
	# accumulate-until-cleared half of the canvas story.
	var trail: EventRow = EventRow.new()
	trail.trigger_provider_id = "Core"
	trail.trigger_id = "OnProcess"
	trail.conditions.append(_every("paint", "0.1"))
	var trail_body: RawCodeRow = RawCodeRow.new()
	trail_body.code = "$PaintLayer/Paint.draw_canvas_circle($Player.global_position.x, $Player.global_position.y + 12.0, 7.0, Color(0.35, 0.6, 1.0, 0.25))"
	trail.actions.append(trail_body)
	sheet.events.append(trail)

	if not _compile(sheet, "res://demo/showcase/draw_lab/draw_lab.tres", "res://demo/showcase/draw_lab/draw_lab.gd"):
		return false
	var emitted: String = FileAccess.get_file_as_string("res://demo/showcase/draw_lab/draw_lab.gd")
	emitted = emitted.replace("\n\nfunc ", "\n\n\nfunc ")
	emitted = emitted.replace("\n\n## @ace_hidden\nfunc ", "\n\n\n## @ace_hidden\nfunc ")
	var out: FileAccess = FileAccess.open("res://demo/showcase/draw_lab/draw_lab.gd", FileAccess.WRITE)
	out.store_string(emitted)
	out.close()

	# ── The scene ──
	var root: Node2D = Node2D.new()
	root.name = "DrawLab"
	root.set_script(load("res://demo/showcase/draw_lab/draw_lab.gd"))
	var backdrop: ColorRect = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.09, 0.1, 0.13)
	backdrop.size = Vector2(1152.0, 648.0)
	root.add_child(backdrop)
	backdrop.owner = root

	# Walls (physics layer 1) that carve the Player line of sight.
	for wall_spec: Array in [[Vector2(576.0, 110.0), Vector2(300.0, 36.0)], [Vector2(820.0, 330.0), Vector2(36.0, 240.0)], [Vector2(390.0, 470.0), Vector2(220.0, 36.0)]]:
		var wall: StaticBody2D = StaticBody2D.new()
		wall.name = "Wall%d" % (root.get_child_count())
		wall.position = wall_spec[0]
		wall.collision_layer = 1
		var wall_shape: CollisionShape2D = CollisionShape2D.new()
		wall_shape.name = "Shape"
		var wall_rect: RectangleShape2D = RectangleShape2D.new()
		wall_rect.size = wall_spec[1]
		wall_shape.shape = wall_rect
		wall.add_child(wall_shape)
		var wall_visual: ColorRect = ColorRect.new()
		wall_visual.name = "Visual"
		wall_visual.color = Color(0.4, 0.44, 0.54)
		wall_visual.position = -(wall_spec[1] as Vector2) / 2.0
		wall_visual.size = wall_spec[1]
		wall.add_child(wall_visual)
		root.add_child(wall)
		_own_deep(wall, root)

	# The whole-screen persistent paint canvas + the center auto-clear ribbon canvas.
	var paint_layer: Node2D = Node2D.new()
	paint_layer.name = "PaintLayer"
	paint_layer.position = Vector2(576.0, 324.0)
	root.add_child(paint_layer)
	paint_layer.owner = root
	_attach_behavior(paint_layer, "Paint", DRAWING_CANVAS, root, {"canvas_width": 1152, "canvas_height": 648})
	var fx_layer: Node2D = Node2D.new()
	fx_layer.name = "FxLayer"
	fx_layer.position = Vector2(576.0, 324.0)
	root.add_child(fx_layer)
	fx_layer.owner = root
	_attach_behavior(fx_layer, "Fx", DRAWING_CANVAS, root, {"canvas_width": 1152, "canvas_height": 648, "auto_clear": true})
	# A dedicated persistent canvas that only ever receives the one-shot decor bake (Paste Layer In Box) -
	# keeping the flattened layer off the busy Paint canvas so it stays crisp.
	var decor_layer: Node2D = Node2D.new()
	decor_layer.name = "DecorLayer"
	decor_layer.position = Vector2(576.0, 324.0)
	root.add_child(decor_layer)
	decor_layer.owner = root
	_attach_behavior(decor_layer, "Decor", DRAWING_CANVAS, root, {"canvas_width": 1152, "canvas_height": 648})

	# The Player: 8-Direction movement + an auto-clear vision canvas.
	var player: CharacterBody2D = _chase_actor("Player", Vector2(280.0, 320.0), Color(0.35, 0.65, 1.0))
	root.add_child(player)
	_own_deep(player, root)
	_attach_behavior(player, "Movement", EIGHT_DIRECTION, root)
	_attach_behavior(player, "Vision", DRAWING_CANVAS, root, {"canvas_width": 640, "canvas_height": 640, "auto_clear": true})

	# The Enemy: a static threat with an auto-clear telegraph canvas.
	var enemy: Node2D = Node2D.new()
	enemy.name = "Enemy"
	enemy.position = Vector2(950.0, 170.0)
	var enemy_visual: ColorRect = ColorRect.new()
	enemy_visual.name = "Visual"
	enemy_visual.color = Color(1.0, 0.35, 0.3)
	enemy_visual.position = Vector2(-13.0, -13.0)
	enemy_visual.size = Vector2(26.0, 26.0)
	enemy.add_child(enemy_visual)
	root.add_child(enemy)
	_own_deep(enemy, root)
	_attach_behavior(enemy, "Telegraph", DRAWING_CANVAS, root, {"canvas_width": 420, "canvas_height": 420, "auto_clear": true})

	# The comet the ribbon trails.
	var comet: Node2D = Node2D.new()
	comet.name = "Comet"
	comet.position = Vector2(781.0, 324.0)
	var comet_visual: ColorRect = ColorRect.new()
	comet_visual.name = "Visual"
	comet_visual.color = Color(0.75, 0.95, 1.0)
	comet_visual.position = Vector2(-7.0, -7.0)
	comet_visual.size = Vector2(14.0, 14.0)
	comet.add_child(comet_visual)
	root.add_child(comet)
	_own_deep(comet, root)

	var hud_layer: CanvasLayer = CanvasLayer.new()
	hud_layer.name = "HudLayer"
	root.add_child(hud_layer)
	hud_layer.owner = root
	var hud: Label = Label.new()
	hud.name = "Hud"
	hud.position = Vector2(24.0, 16.0)
	hud.add_theme_font_size_override("font_size", 18)
	hud.text = "Arrows move · Space stamps the target-marker PREFAB (a .tres formation) where you stand\nYellow fan = your live line of sight (walls carve it) · red wedge = the enemy telegraph\nCyan ribbon trails the comet · your steps drip paint - persistent vs auto-clear canvases\nGem cluster = a LAYER flattened onto the canvas with Paste Layer In Box · gem trail = the comet Pasted 8x a second"
	hud_layer.add_child(hud)
	hud.owner = root

	return _save_scene(root, "res://demo/showcase/draw_lab/draw_lab.tscn")


# ── 17. Raycast Lab - every way to ask the physics world a question ──────────
const RAYCAST_LAB_DIR := "res://demo/showcase/raycast_lab"


## The Raycast Lab showcase: six different casts running at once, each drawn so you can SEE the
## question being asked. A sweeping RayCast2D radar; a ShapeCast2D gate sweeping a corridor; a
## Cast Ray Into beam that follows the cursor and reports what it struck; a circle overlap ring; a
## point query under the cursor; and a swept-disc motion cast that stops short of the wall.
##
## Every cast is a real ACE row using the SHIPPED template (see _ace_template), so the generated
## GDScript beside this scene is literally what the raycasting vocabulary emits - nothing hand-written.
## The DRAWING is plain code, because visualising a cast is the Drawing Canvas pack's job, not the
## raycaster's.
func _build_raycast_lab() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "RaycastLabDemo"
	sheet.emit_live_values = false
	sheet.variables = {
		"sweep_deg": {"type": "float", "default": 0.0, "exported": false},
		"radar_hit": {"type": "bool", "default": false, "exported": false},
		"radar_end": {"type": "Vector2", "default": Vector2.ZERO, "exported": false},
		"radar_normal": {"type": "Vector2", "default": Vector2.ZERO, "exported": false},
		"hit": {"type": "Dictionary", "default": {}, "exported": false},
		"laser_end": {"type": "Vector2", "default": Vector2.ZERO, "exported": false},
		"laser_normal": {"type": "Vector2", "default": Vector2.ZERO, "exported": false},
		"laser_on_target": {"type": "bool", "default": false, "exported": false},
		"picked": {"type": "Array", "default": [], "exported": false},
		"nearby": {"type": "Array", "default": [], "exported": false},
		"travel": {"type": "float", "default": 1.0, "exported": false},
		"probe_end": {"type": "Vector2", "default": Vector2.ZERO, "exported": false},
		"gate_count": {"type": "int", "default": 0, "exported": false},
		"gate_travel": {"type": "float", "default": 1.0, "exported": false}
	}

	var about: CommentRow = CommentRow.new()
	about.text = "[b]Raycast Lab[/b] - six ways to ask the physics world a question, all drawn live. [b]Yellow[/b] is a RayCast2D NODE sweeping for whatever it can see. [b]Cyan[/b] is Cast Ray Into, firing ONE ray at your cursor and storing the result, which the Ray Result verbs then read for the hit point, the surface normal, and whether it was a target - three facts, one cast. [b]Green[/b] is Query Bodies In Circle collecting everything within 130px; [b]white[/b] is Query Bodies Under Mouse. [b]Pink[/b] is Cast Circle Motion Into - how far a disc could slide before it jams, which is how you move something fast without it tunnelling through a wall. [b]Blue[/b] is a ShapeCast2D sweeping the corridor: a ray with THICKNESS, parked at its safe fraction."
	sheet.events.append(about)

	# ── The casting tick. Every cast below is a real raycast ACE row. ──
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnPhysicsProcess"
	tick.actions.append(_raw("\n".join(PackedStringArray([
		"sweep_deg = fmod(sweep_deg + 55.0 * delta, 360.0)",
		"radar_hit = false",
		"laser_on_target = false"
	]))))
	# RAYCAST2D NODE: aim it, then force it to re-check THIS frame - a raycast otherwise reports what
	# it saw on the last physics frame, which is the classic "my ray is one frame behind" bug.
	tick.actions.append(_action("Core", "RayCast2DSetTarget", _ace_template("RayCast2DSetTarget"),
		{"target": "$Player/Radar", "reach": "Vector2.from_angle(deg_to_rad(sweep_deg)) * 230.0"}))
	tick.actions.append(_action("Core", "RayCast2DForceUpdate", _ace_template("RayCast2DForceUpdate"),
		{"target": "$Player/Radar"}))
	tick.actions.append(_raw("radar_end = $Player.global_position + Vector2.from_angle(deg_to_rad(sweep_deg)) * 230.0"))
	# CAST RAY INTO: ONE ray at the cursor, whole result stored. The exclude list drops the player's
	# own body so the beam can never stop on the thing that fired it.
	tick.actions.append(_action("Core", "CastRayInto2D", _ace_template("CastRayInto2D", "laser"), {
		"into": "hit",
		"from": "$Player.global_position",
		"to": "get_global_mouse_position()",
		"mask": "1",
		"exclude": "[$Player.get_rid()]",
		"hit_areas": "false"
	}))
	tick.actions.append(_raw("\n".join(PackedStringArray([
		"laser_end = get_global_mouse_position()",
		"laser_normal = Vector2.ZERO"
	]))))
	# A POINT query under the cursor, and a CIRCLE overlap around the player.
	tick.actions.append(_action("Core", "QueryBodiesUnderMouse2D", _ace_template("QueryBodiesUnderMouse2D", "pick"),
		{"into": "picked", "hit_areas": "false", "max_results": "8"}))
	tick.actions.append(_action("Core", "QueryBodiesInCircle2D", _ace_template("QueryBodiesInCircle2D", "zone"),
		{"into": "nearby", "center": "$Player.global_position", "radius": "130.0", "max_results": "16"}))
	# MOTION CAST: how much of the trip to the cursor an 18px disc could actually make.
	tick.actions.append(_action("Core", "CastCircleMotion2D", _ace_template("CastCircleMotion2D", "probe"), {
		"into": "travel",
		"from": "$Player.global_position",
		"motion": "get_global_mouse_position() - $Player.global_position",
		"radius": "18.0",
		"mask": "1"
	}))
	tick.actions.append(_raw("probe_end = $Player.global_position + (get_global_mouse_position() - $Player.global_position) * travel"))
	# SHAPECAST2D NODE: the swept shape, and how far along its rail it stays clear.
	tick.actions.append(_action("Core", "ShapeCast2DForceUpdate", _ace_template("ShapeCast2DForceUpdate"),
		{"target": "$Gate"}))
	tick.actions.append(_raw("\n".join(PackedStringArray([
		"gate_count = $Gate.get_collision_count()",
		"gate_travel = $Gate.get_closest_collision_safe_fraction()"
	]))))
	sheet.events.append(tick)

	# Reading the RayCast2D node: a CONDITION row, so the reads only happen when it actually hit.
	var radar_row: EventRow = EventRow.new()
	radar_row.trigger_provider_id = "Core"
	radar_row.trigger_id = "OnPhysicsProcess"
	radar_row.conditions.append(_condition("Core", "RayCast2DIsColliding",
		_ace_template("RayCast2DIsColliding"), {"target": "$Player/Radar"}))
	radar_row.actions.append(_raw("\n".join(PackedStringArray([
		"radar_hit = true",
		"radar_end = $Player/Radar.get_collision_point()",
		"radar_normal = $Player/Radar.get_collision_normal()"
	]))))
	sheet.events.append(radar_row)

	# Reading the STORED ray result: point, normal, and a group test - three facts off ONE cast, and
	# the group test is safe on a clear ray because it checks for nothing-hit first.
	var laser_row: EventRow = EventRow.new()
	laser_row.trigger_provider_id = "Core"
	laser_row.trigger_id = "OnPhysicsProcess"
	laser_row.conditions.append(_condition("Core", "RayResultHit2D",
		_ace_template("RayResultHit2D"), {"result": "hit"}))
	laser_row.actions.append(_raw("\n".join(PackedStringArray([
		"laser_end = hit.get(\"position\", Vector2.ZERO)",
		"laser_normal = hit.get(\"normal\", Vector2.ZERO)"
	]))))
	var on_target: EventRow = EventRow.new()
	on_target.conditions.append(_condition("Core", "RayResultInGroup2D",
		_ace_template("RayResultInGroup2D"), {"result": "hit", "group": "\"targets\""}))
	on_target.actions.append(_raw("laser_on_target = true"))
	laser_row.sub_events.append(on_target)
	sheet.events.append(laser_row)

	# ── The drawing tick: pack verbs, not raycast verbs. Visualising a cast is the canvas's job. ──
	var paint: EventRow = EventRow.new()
	paint.trigger_provider_id = "Core"
	paint.trigger_id = "OnProcess"
	paint.actions.append(_raw("\n".join(PackedStringArray([
		"var ink: DrawingCanvas = $InkLayer/Ink",
		"var here: Vector2 = $Player.global_position",
		"var mouse: Vector2 = get_global_mouse_position()",
		"# RayCast2D node - dim to its full reach, bright to whatever stopped it.",
		"ink.draw_canvas_line(here.x, here.y, radar_end.x, radar_end.y, 2.0, Color(1.0, 0.85, 0.3, 0.4))",
		"if radar_hit:",
		"\tink.draw_canvas_line(here.x, here.y, radar_end.x, radar_end.y, 3.0, Color(1.0, 0.85, 0.3, 0.95))",
		"\tink.draw_canvas_ring(radar_end.x, radar_end.y, 9.0, 2.0, Color(1.0, 0.85, 0.3, 1.0))",
		"\tink.draw_canvas_line(radar_end.x, radar_end.y, radar_end.x + radar_normal.x * 26.0, radar_end.y + radar_normal.y * 26.0, 2.0, Color(1.0, 1.0, 1.0, 0.75))",
		"# Query Bodies In Circle - the scan ring, and a mark on everything it collected.",
		"ink.draw_canvas_dashed_ring(here.x, here.y, 130.0, 9.0, 7.0, 1.0, Color(0.45, 1.0, 0.6, 0.45))",
		"for body: Node2D in nearby:",
		"\tink.draw_canvas_ring(body.global_position.x, body.global_position.y, 20.0, 2.0, Color(0.45, 1.0, 0.6, 0.75))",
		"# Cast Ray Into - the cursor beam, stopped at the first thing in the way.",
		"ink.draw_canvas_line(here.x, here.y, laser_end.x, laser_end.y, 2.0, Color(0.4, 0.85, 1.0, 0.9))",
		"if laser_normal != Vector2.ZERO:",
		"\tink.draw_canvas_ring(laser_end.x, laser_end.y, 7.0, 2.0, Color(0.4, 0.85, 1.0, 1.0))",
		"\tink.draw_canvas_line(laser_end.x, laser_end.y, laser_end.x + laser_normal.x * 24.0, laser_end.y + laser_normal.y * 24.0, 2.0, Color(1.0, 1.0, 1.0, 0.7))",
		"if laser_on_target:",
		"\tink.draw_canvas_ring(laser_end.x, laser_end.y, 16.0, 3.0, Color(1.0, 0.55, 0.2, 1.0))",
		"# Cast Circle Motion Into - where an 18px disc would jam on its way to the cursor.",
		"ink.draw_canvas_dashed_line(here.x, here.y, probe_end.x, probe_end.y, 8.0, 6.0, 1.0, Color(1.0, 0.45, 0.85, 0.45))",
		"ink.draw_canvas_ring(probe_end.x, probe_end.y, 18.0, 2.0, Color(1.0, 0.45, 0.85, 0.9))",
		"# Query Bodies Under Mouse - a ring around whatever the cursor is sitting on.",
		"ink.draw_canvas_ring(mouse.x, mouse.y, 5.0, 1.0, Color(1.0, 1.0, 1.0, 0.45))",
		"for body: Node2D in picked:",
		"\tink.draw_canvas_ring(body.global_position.x, body.global_position.y, 30.0, 3.0, Color(1.0, 1.0, 1.0, 0.9))",
		"# ShapeCast2D node - the rail it sweeps, and the disc parked at its safe fraction.",
		"var rail: Vector2 = $Gate.global_position",
		"var reach: Vector2 = $Gate.target_position",
		"ink.draw_canvas_dashed_line(rail.x, rail.y, rail.x + reach.x, rail.y + reach.y, 10.0, 8.0, 1.0, Color(0.5, 0.7, 1.0, 0.45))",
		"ink.draw_canvas_ring(rail.x + reach.x * gate_travel, rail.y + reach.y * gate_travel, 16.0, 2.0, Color(0.5, 0.7, 1.0, 0.9))",
		"$HudLayer/Readout.text = \"under cursor %d - in circle %d - disc travel %.2f - gate sweep %.2f - gate touching %d\" % [picked.size(), nearby.size(), travel, gate_travel, gate_count]"
	]))))
	sheet.events.append(paint)

	if not _compile(sheet, "%s/raycast_lab.tres" % RAYCAST_LAB_DIR, "%s/raycast_lab.gd" % RAYCAST_LAB_DIR):
		return false
	var emitted: String = FileAccess.get_file_as_string("%s/raycast_lab.gd" % RAYCAST_LAB_DIR)
	emitted = emitted.replace("\n\nfunc ", "\n\n\nfunc ")
	emitted = emitted.replace("\n\n## @ace_hidden\nfunc ", "\n\n\n## @ace_hidden\nfunc ")
	var out: FileAccess = FileAccess.open("%s/raycast_lab.gd" % RAYCAST_LAB_DIR, FileAccess.WRITE)
	out.store_string(emitted)
	out.close()

	# ── The scene ──
	var root: Node2D = Node2D.new()
	root.name = "RaycastLab"
	root.set_script(load("%s/raycast_lab.gd" % RAYCAST_LAB_DIR))
	var backdrop: ColorRect = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.08, 0.09, 0.12)
	backdrop.size = Vector2(1152.0, 648.0)
	root.add_child(backdrop)
	backdrop.owner = root

	# The arena: a border plus interior blocks for every cast to bite on. Collision layer 1 is what
	# every cast in the sheet masks against.
	var walls: Array = [
		[Vector2(576.0, 12.0), Vector2(1152.0, 24.0)], [Vector2(576.0, 636.0), Vector2(1152.0, 24.0)],
		[Vector2(12.0, 324.0), Vector2(24.0, 648.0)], [Vector2(1140.0, 324.0), Vector2(24.0, 648.0)],
		[Vector2(430.0, 190.0), Vector2(200.0, 28.0)], [Vector2(300.0, 470.0), Vector2(28.0, 180.0)],
		[Vector2(700.0, 420.0), Vector2(240.0, 28.0)], [Vector2(880.0, 250.0), Vector2(28.0, 160.0)]
	]
	var wall_index: int = 0
	for wall_spec: Array in walls:
		wall_index += 1
		var wall: StaticBody2D = StaticBody2D.new()
		wall.name = "Wall%d" % wall_index
		wall.position = wall_spec[0]
		wall.collision_layer = 1
		var wall_shape: CollisionShape2D = CollisionShape2D.new()
		wall_shape.name = "Shape"
		var wall_rect: RectangleShape2D = RectangleShape2D.new()
		wall_rect.size = wall_spec[1]
		wall_shape.shape = wall_rect
		wall.add_child(wall_shape)
		var wall_visual: ColorRect = ColorRect.new()
		wall_visual.name = "Visual"
		wall_visual.color = Color(0.34, 0.38, 0.47)
		wall_visual.position = -(wall_spec[1] as Vector2) / 2.0
		wall_visual.size = wall_spec[1]
		wall.add_child(wall_visual)
		root.add_child(wall)
		_own_deep(wall, root)

	# Targets: same collision layer, but in the "targets" GROUP - what Ray Result Is In Group asks
	# about, so the beam can tell scenery from something worth shooting.
	var target_index: int = 0
	for spot: Vector2 in [Vector2(760.0, 150.0), Vector2(980.0, 500.0), Vector2(200.0, 250.0), Vector2(560.0, 560.0)]:
		target_index += 1
		var target: StaticBody2D = StaticBody2D.new()
		target.name = "Target%d" % target_index
		target.position = spot
		target.collision_layer = 1
		# persistent=true, or the group is a builder-only fact: PackedScene.pack() saves only
		# PERSISTENT groups, so a non-persistent one vanishes and Ray Result Is In Group never fires.
		target.add_to_group("targets", true)
		var target_shape: CollisionShape2D = CollisionShape2D.new()
		target_shape.name = "Shape"
		var target_circle: CircleShape2D = CircleShape2D.new()
		target_circle.radius = 20.0
		target_shape.shape = target_circle
		target.add_child(target_shape)
		var target_visual: ColorRect = ColorRect.new()
		target_visual.name = "Visual"
		target_visual.color = Color(0.95, 0.45, 0.25)
		# Sized to MATCH the 20px-radius collider. A smaller visual would make every ray stop in
		# mid-air beside the target, which in a demo about "the ray stops exactly where it hit"
		# reads as a bug in the raycasting rather than a mismatched sprite.
		target_visual.position = Vector2(-20.0, -20.0)
		target_visual.size = Vector2(40.0, 40.0)
		target.add_child(target_visual)
		root.add_child(target)
		_own_deep(target, root)

	# The canvas every cast draws itself on. AUTO-CLEAR: the picture is this frame's answers, not a
	# smear of every frame's.
	var ink_layer: Node2D = Node2D.new()
	ink_layer.name = "InkLayer"
	ink_layer.position = Vector2(576.0, 324.0)
	root.add_child(ink_layer)
	ink_layer.owner = root
	_attach_behavior(ink_layer, "Ink", DRAWING_CANVAS, root, {"canvas_width": 1152, "canvas_height": 648, "auto_clear": true})

	# The Player, carrying the RayCast2D the radar rows drive.
	var player: CharacterBody2D = _chase_actor("Player", Vector2(430.0, 330.0), Color(0.35, 0.65, 1.0))
	root.add_child(player)
	_own_deep(player, root)
	# Layer 2, not 1: every cast in the sheet masks layer 1 (walls + targets), so a player left on
	# the default layer would answer its OWN overlap query and sit under its own cursor pick.
	player.collision_layer = 2
	player.collision_mask = 1
	_attach_behavior(player, "Movement", EIGHT_DIRECTION, root)
	var radar: RayCast2D = RayCast2D.new()
	radar.name = "Radar"
	radar.target_position = Vector2(0.0, -230.0)
	radar.collision_mask = 1
	radar.enabled = true
	player.add_child(radar)
	radar.owner = root

	# The Gate: a ShapeCast2D sweeping the right-hand corridor, thick enough not to thread a gap.
	var gate: ShapeCast2D = ShapeCast2D.new()
	gate.name = "Gate"
	gate.position = Vector2(1010.0, 90.0)
	gate.target_position = Vector2(0.0, 420.0)
	gate.collision_mask = 1
	var gate_shape: CircleShape2D = CircleShape2D.new()
	gate_shape.radius = 16.0
	gate.shape = gate_shape
	gate.enabled = true
	root.add_child(gate)
	gate.owner = root

	var hud_layer: CanvasLayer = CanvasLayer.new()
	hud_layer.name = "HudLayer"
	root.add_child(hud_layer)
	hud_layer.owner = root
	var hud: Label = Label.new()
	hud.name = "Hud"
	hud.position = Vector2(24.0, 16.0)
	hud.add_theme_font_size_override("font_size", 17)
	hud.text = "Arrows move - the cursor aims the cyan beam\nYellow = a RayCast2D NODE sweeping - cyan = Cast Ray Into (orange ring = it hit a target)\nGreen = Query Bodies In Circle - white = Query Bodies Under Mouse\nPink = Cast Circle Motion Into (where an 18px disc would jam) - blue = a ShapeCast2D sweeping the corridor"
	hud_layer.add_child(hud)
	hud.owner = root
	var readout: Label = Label.new()
	readout.name = "Readout"
	readout.position = Vector2(24.0, 604.0)
	readout.add_theme_font_size_override("font_size", 17)
	readout.text = "under cursor 0 - in circle 0 - disc travel 1.00 - gate sweep 1.00 - gate touching 0"
	hud_layer.add_child(readout)
	readout.owner = root

	return _save_scene(root, "%s/raycast_lab.tscn" % RAYCAST_LAB_DIR)


# ── 18. Raycast Lab 3D - the same six questions, asked in three dimensions ───
const RAYCAST_LAB_3D_DIR := "res://demo/showcase/raycast_lab_3d"


## The 3D half of the Raycast Lab. Same six casts as the 2D room, in the dimension where two of them
## only exist: CAMERA PICKING (the screen-to-world ray under the cursor, which is the whole of
## click-to-select) and FACE INDEX (which triangle of a mesh a ray struck).
##
## The camera ORBITS instead of being mouse-driven, on purpose: a first-person controller captures
## the pointer, and a captured pointer has no screen position to project a picking ray through. A lab
## about casting needs the cursor free.
##
## Visualising a cast in 3D has no Drawing Canvas to lean on, so the sheet moves real meshes: a thin
## box stretched between two points is a beam, and a small sphere parked at a hit point is a marker.
## That is plain Godot, and it keeps the generated script readable.
func _build_raycast_lab_3d() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node3D"
	sheet.custom_class_name = "RaycastLab3DDemo"
	sheet.emit_live_values = false
	sheet.variables = {
		"turret_deg": {"type": "float", "default": 0.0, "exported": false},
		"orbit_deg": {"type": "float", "default": 0.0, "exported": false},
		"radar_hit": {"type": "bool", "default": false, "exported": false},
		"radar_end": {"type": "Vector3", "default": Vector3.ZERO, "exported": false},
		"radar_normal": {"type": "Vector3", "default": Vector3.ZERO, "exported": false},
		"pick": {"type": "Dictionary", "default": {}, "exported": false},
		"pick_point": {"type": "Vector3", "default": Vector3.ZERO, "exported": false},
		"pick_normal": {"type": "Vector3", "default": Vector3.ZERO, "exported": false},
		"pick_face": {"type": "int", "default": -1, "exported": false},
		"pick_on_target": {"type": "bool", "default": false, "exported": false},
		"nearby": {"type": "Array", "default": [], "exported": false},
		"in_box": {"type": "Array", "default": [], "exported": false},
		"at_point": {"type": "Array", "default": [], "exported": false},
		"travel": {"type": "float", "default": 1.0, "exported": false},
		"probe_end": {"type": "Vector3", "default": Vector3.ZERO, "exported": false},
		"sweep_count": {"type": "int", "default": 0, "exported": false},
		"sweep_travel": {"type": "float", "default": 1.0, "exported": false}
	}

	var about: CommentRow = CommentRow.new()
	about.text = "[b]Raycast Lab 3D[/b] - the same six questions as the 2D room, in the dimension where two of them only exist. [b]Cyan[/b] is [b]Cast Ray From Mouse Into[/b]: the camera projects a ray through your cursor and stores what it finds, which is the whole of click-to-select in 3D - the readout even names the mesh TRIANGLE it struck (Ray Result Face Index, a 3D-only fact). [b]Yellow[/b] is a RayCast3D NODE on the turning turret. [b]Blue[/b] is a ShapeCast3D sweeping with THICKNESS, parked at its safe fraction. [b]Pink[/b] is Cast Sphere Motion Into - how far a ball could roll before it jams. [b]Green[/b] rings mark what Query Bodies In Sphere caught. The camera orbits rather than being mouse-driven on purpose: a captured pointer has no screen position to project a picking ray through."
	sheet.events.append(about)

	# ── The casting tick. Every cast below is a real raycast ACE row. ──
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnPhysicsProcess"
	tick.actions.append(_raw("\n".join(PackedStringArray([
		"turret_deg = fmod(turret_deg + 40.0 * delta, 360.0)",
		"orbit_deg += (Input.get_axis(\"ui_left\", \"ui_right\")) * 45.0 * delta",
		"radar_hit = false",
		"pick_on_target = false",
		"pick_face = -1",
		"$CameraArm.rotation_degrees = Vector3(0.0, orbit_deg, 0.0)"
	]))))
	# RAYCAST3D NODE on the turret: aim it, then force it to re-check THIS frame.
	tick.actions.append(_action("Core", "RayCast3DSetTarget", _ace_template("RayCast3DSetTarget"),
		{"target": "$Turret/Radar", "reach": "Vector3(sin(deg_to_rad(turret_deg)), 0.0, cos(deg_to_rad(turret_deg))) * 14.0"}))
	tick.actions.append(_action("Core", "RayCast3DForceUpdate", _ace_template("RayCast3DForceUpdate"),
		{"target": "$Turret/Radar"}))
	tick.actions.append(_raw("radar_end = $Turret.global_position + Vector3(sin(deg_to_rad(turret_deg)), 0.0, cos(deg_to_rad(turret_deg))) * 14.0"))
	# CAMERA PICKING: the screen-to-world ray under the cursor. This is the verb 2D has no need of.
	tick.actions.append(_action("Core", "CastMouseRayInto3D", _ace_template("CastMouseRayInto3D", "pick"), {
		"into": "pick",
		"distance": "200.0",
		"mask": "1",
		"exclude": "[]",
		"hit_areas": "false"
	}))
	# VOLUME + POINT queries: a sphere around the turret, a box over the far bay, and a pinprick
	# straight down from the turret to name the floor tile under it.
	tick.actions.append(_action("Core", "QueryBodiesInSphere3D", _ace_template("QueryBodiesInSphere3D", "zone"),
		{"into": "nearby", "center": "$Turret.global_position", "radius": "7.0", "mask": "1", "max_results": "16"}))
	tick.actions.append(_action("Core", "QueryBodiesInBox3D", _ace_template("QueryBodiesInBox3D", "bay"),
		{"into": "in_box", "center": "Vector3(9.0, 1.0, -9.0)", "size": "Vector3(8.0, 4.0, 8.0)", "mask": "1", "max_results": "16"}))
	tick.actions.append(_action("Core", "QueryBodiesAtPoint3D", _ace_template("QueryBodiesAtPoint3D", "spot"),
		{"into": "at_point", "point": "$Turret.global_position - Vector3(0.0, 1.05, 0.0)", "hit_areas": "false", "max_results": "8"}))
	# MOTION CAST: how far a 0.6m ball could roll from the turret before something stops it.
	tick.actions.append(_action("Core", "CastSphereMotion3D", _ace_template("CastSphereMotion3D", "probe"), {
		"into": "travel",
		"from": "$Turret.global_position",
		"motion": "Vector3(cos(deg_to_rad(turret_deg)), 0.0, -sin(deg_to_rad(turret_deg))) * 12.0",
		"radius": "0.6",
		"mask": "1"
	}))
	tick.actions.append(_raw("probe_end = $Turret.global_position + Vector3(cos(deg_to_rad(turret_deg)), 0.0, -sin(deg_to_rad(turret_deg))) * 12.0 * travel"))
	# SHAPECAST3D NODE: the thick sweep down the corridor.
	tick.actions.append(_action("Core", "ShapeCast3DForceUpdate", _ace_template("ShapeCast3DForceUpdate"),
		{"target": "$Sweep"}))
	tick.actions.append(_raw("\n".join(PackedStringArray([
		"sweep_count = $Sweep.get_collision_count()",
		"sweep_travel = $Sweep.get_closest_collision_safe_fraction()"
	]))))
	sheet.events.append(tick)

	# Reading the RayCast3D node, only when it actually hit something.
	var radar_row: EventRow = EventRow.new()
	radar_row.trigger_provider_id = "Core"
	radar_row.trigger_id = "OnPhysicsProcess"
	radar_row.conditions.append(_condition("Core", "RayCast3DIsColliding",
		_ace_template("RayCast3DIsColliding"), {"target": "$Turret/Radar"}))
	radar_row.actions.append(_raw("\n".join(PackedStringArray([
		"radar_hit = true",
		"radar_end = $Turret/Radar.get_collision_point()",
		"radar_normal = $Turret/Radar.get_collision_normal()"
	]))))
	sheet.events.append(radar_row)

	# Reading the STORED pick: point, normal, the mesh triangle, and a group test. Four facts, and
	# the cursor ray was cast exactly ONCE to get them.
	var pick_row: EventRow = EventRow.new()
	pick_row.trigger_provider_id = "Core"
	pick_row.trigger_id = "OnPhysicsProcess"
	pick_row.conditions.append(_condition("Core", "RayResultHit3D",
		_ace_template("RayResultHit3D"), {"result": "pick"}))
	pick_row.actions.append(_raw("\n".join(PackedStringArray([
		"pick_point = pick.get(\"position\", Vector3.ZERO)",
		"pick_normal = pick.get(\"normal\", Vector3.ZERO)",
		"pick_face = pick.get(\"face_index\", -1)"
	]))))
	var pick_target: EventRow = EventRow.new()
	pick_target.conditions.append(_condition("Core", "RayResultInGroup3D",
		_ace_template("RayResultInGroup3D"), {"result": "pick", "group": "\"targets\""}))
	pick_target.actions.append(_raw("pick_on_target = true"))
	pick_row.sub_events.append(pick_target)
	sheet.events.append(pick_row)

	# ── Showing the answers. No Drawing Canvas in 3D, so the sheet moves real meshes: a thin box
	# stretched between two points is a beam, a small sphere parked somewhere is a marker. ──
	var show: EventRow = EventRow.new()
	show.trigger_provider_id = "Core"
	show.trigger_id = "OnProcess"
	show.actions.append(_raw("\n".join(PackedStringArray([
		"# The turning turret's ray: a yellow beam to whatever stopped it, and a marker on the spot.",
		"aim_beam($Beams/RadarBeam, $Turret.global_position, radar_end)",
		"$Markers/RadarMark.visible = radar_hit",
		"$Markers/RadarMark.global_position = radar_end",
		"# The cursor pick: the headline 3D cast. Cyan beam from the camera to whatever is under the",
		"# pointer, and the marker turns orange when that thing is a target.",
		"$Markers/PickMark.visible = not pick.is_empty()",
		"$Markers/PickMark.global_position = pick_point",
		"$Markers/PickMark.scale = Vector3.ONE * (1.6 if pick_on_target else 1.0)",
		"# NOT a beam from the camera to the cursor: you are looking straight down that ray, so it draws",
		"# as a stray line skidding over the floor. The surface NORMAL at the hit is the fact worth",
		"# showing, and it stands up off whatever was struck.",
		"aim_beam($Beams/PickBeam, pick_point, pick_point + pick_normal * 1.8)",
		"# Where a rolling 0.6m ball would jam, and where the thick sweep runs out of clear road.",
		"$Markers/ProbeMark.global_position = probe_end",
		"aim_beam($Beams/ProbeBeam, $Turret.global_position, probe_end)",
		"$Markers/SweepMark.global_position = $Sweep.global_position + $Sweep.target_position * sweep_travel",
		"aim_beam($Beams/SweepBeam, $Sweep.global_position, $Sweep.global_position + $Sweep.target_position)",
		"# Query Bodies In Sphere: park a ring of markers on whatever the sphere caught.",
		"var ring: Node3D = $Markers/ZoneMarks",
		"for slot: int in ring.get_child_count():",
		"\tvar mark: Node3D = ring.get_child(slot)",
		"\tmark.visible = slot < nearby.size()",
		"\tif mark.visible:",
		"\t\tmark.global_position = (nearby[slot] as Node3D).global_position + Vector3(0.0, 1.6, 0.0)",
		"$HudLayer/Readout.text = \"cursor: %s   face %d   in sphere %d   in box %d   under turret %d   ball travel %.2f   sweep %.2f (%d)\" % [\"TARGET\" if pick_on_target else (\"scenery\" if not pick.is_empty() else \"sky\"), pick_face, nearby.size(), in_box.size(), at_point.size(), travel, sweep_travel, sweep_count]"
	]))))
	sheet.events.append(show)

	# One helper, so the three beams do not repeat the same orientation maths three times.
	var beam_fn: EventFunction = EventFunction.new()
	beam_fn.function_name = "aim_beam"
	beam_fn.enabled = true
	beam_fn.description = "Stretches a unit-long beam mesh so it spans from one point to another."
	var p_beam: ACEParam = ACEParam.new(); p_beam.id = "beam"; p_beam.type_name = "Node3D"; p_beam.type = TYPE_OBJECT
	var p_from: ACEParam = ACEParam.new(); p_from.id = "from"; p_from.type_name = "Vector3"; p_from.type = TYPE_VECTOR3
	var p_to: ACEParam = ACEParam.new(); p_to.id = "to"; p_to.type_name = "Vector3"; p_to.type = TYPE_VECTOR3
	beam_fn.params = [p_beam, p_from, p_to]
	beam_fn.events = [_raw("\n".join(PackedStringArray([
		"var span: float = from.distance_to(to)",
		"beam.visible = span > 0.05",
		"if not beam.visible:",
		"\treturn",
		"beam.global_position = (from + to) * 0.5",
		"beam.look_at(to, Vector3.UP)",
		"# The mesh is a unit box on -Z, so scaling z by the span turns it into a beam of that length.",
		"beam.scale = Vector3(1.0, 1.0, span)"
	])))]
	sheet.functions.append(beam_fn)

	if not _compile(sheet, "%s/raycast_lab_3d.tres" % RAYCAST_LAB_3D_DIR, "%s/raycast_lab_3d.gd" % RAYCAST_LAB_3D_DIR):
		return false
	var emitted: String = FileAccess.get_file_as_string("%s/raycast_lab_3d.gd" % RAYCAST_LAB_3D_DIR)
	emitted = emitted.replace("\n\nfunc ", "\n\n\nfunc ")
	emitted = emitted.replace("\n\n## @ace_hidden\nfunc ", "\n\n\n## @ace_hidden\nfunc ")
	var out: FileAccess = FileAccess.open("%s/raycast_lab_3d.gd" % RAYCAST_LAB_3D_DIR, FileAccess.WRITE)
	out.store_string(emitted)
	out.close()

	# ── The scene ──
	var root: Node3D = Node3D.new()
	root.name = "RaycastLab3D"
	root.set_script(load("%s/raycast_lab_3d.gd" % RAYCAST_LAB_3D_DIR))

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.shadow_enabled = true
	root.add_child(sun)
	sun.owner = root
	var sky_env: WorldEnvironment = WorldEnvironment.new()
	sky_env.name = "World"
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.08, 0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.62)
	env.ambient_light_energy = 0.7
	sky_env.environment = env
	root.add_child(sky_env)
	sky_env.owner = root

	# The floor. A CONCAVE collision shape, deliberately: face index only means anything on one, so
	# a box-shaped floor would make Ray Result Face Index read -1 forever.
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.collision_layer = 1
	root.add_child(floor_body)
	floor_body.owner = root
	var floor_plane: PlaneMesh = PlaneMesh.new()
	floor_plane.size = Vector2(40.0, 40.0)
	floor_plane.subdivide_width = 8
	floor_plane.subdivide_depth = 8
	var floor_material: StandardMaterial3D = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.28, 0.32, 0.4, 1.0)
	floor_plane.material = floor_material
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	floor_mesh.name = "Mesh"
	floor_mesh.mesh = floor_plane
	floor_body.add_child(floor_mesh)
	floor_mesh.owner = root
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	floor_shape.name = "Shape"
	floor_shape.shape = floor_plane.create_trimesh_shape()
	floor_body.add_child(floor_shape)
	floor_shape.owner = root

	# Crates: plain scenery for the casts to bite on.
	var crate_material: StandardMaterial3D = StandardMaterial3D.new()
	crate_material.albedo_color = Color(0.62, 0.66, 0.76, 1.0)
	var crate_index: int = 0
	for crate_spot: Vector3 in [Vector3(-6.0, 1.0, -4.0), Vector3(5.0, 1.0, 5.0), Vector3(-3.0, 1.0, 7.0),
			Vector3(9.0, 1.0, -9.0), Vector3(7.0, 1.0, -10.5), Vector3(0.0, 1.0, -12.0)]:
		crate_index += 1
		var crate: StaticBody3D = StaticBody3D.new()
		crate.name = "Crate%d" % crate_index
		crate.position = crate_spot
		crate.collision_layer = 1
		root.add_child(crate)
		crate.owner = root
		var crate_box: BoxShape3D = BoxShape3D.new()
		crate_box.size = Vector3(2.0, 2.0, 2.0)
		var crate_shape: CollisionShape3D = CollisionShape3D.new()
		crate_shape.name = "Shape"
		crate_shape.shape = crate_box
		crate.add_child(crate_shape)
		crate_shape.owner = root
		var crate_box_mesh: BoxMesh = BoxMesh.new()
		crate_box_mesh.size = Vector3(2.0, 2.0, 2.0)
		crate_box_mesh.material = crate_material
		var crate_mesh: MeshInstance3D = MeshInstance3D.new()
		crate_mesh.name = "Mesh"
		crate_mesh.mesh = crate_box_mesh
		crate.add_child(crate_mesh)
		crate_mesh.owner = root

	# Targets: same layer, but in the "targets" GROUP (persistent, or PackedScene drops it), which is
	# what Ray Result Is In Group asks about when the cursor lands on one.
	var target_material: StandardMaterial3D = StandardMaterial3D.new()
	target_material.albedo_color = Color(0.95, 0.45, 0.25, 1.0)
	var target_index: int = 0
	for target_spot: Vector3 in [Vector3(3.0, 1.2, -6.0), Vector3(-8.0, 1.2, 3.0), Vector3(0.0, 1.2, 3.5)]:
		target_index += 1
		var target: StaticBody3D = StaticBody3D.new()
		target.name = "Target%d" % target_index
		target.position = target_spot
		target.collision_layer = 1
		target.add_to_group("targets", true)
		root.add_child(target)
		target.owner = root
		var target_sphere: SphereShape3D = SphereShape3D.new()
		target_sphere.radius = 1.2
		var target_shape: CollisionShape3D = CollisionShape3D.new()
		target_shape.name = "Shape"
		target_shape.shape = target_sphere
		target.add_child(target_shape)
		target_shape.owner = root
		var target_sphere_mesh: SphereMesh = SphereMesh.new()
		target_sphere_mesh.radius = 1.2
		target_sphere_mesh.height = 2.4
		target_sphere_mesh.material = target_material
		var target_mesh: MeshInstance3D = MeshInstance3D.new()
		target_mesh.name = "Mesh"
		target_mesh.mesh = target_sphere_mesh
		target.add_child(target_mesh)
		target_mesh.owner = root

	# A solid pad under the turret. The point query asks what is directly beneath it, and the floor
	# is a TRIMESH - a concave shape has no interior, so intersect_point can never report one. A
	# convex box can be stood inside, which is what makes the question answerable at all.
	var pad: StaticBody3D = StaticBody3D.new()
	pad.name = "Pad"
	pad.position = Vector3(0.0, 0.15, 0.0)
	pad.collision_layer = 1
	root.add_child(pad)
	pad.owner = root
	var pad_box: BoxShape3D = BoxShape3D.new()
	pad_box.size = Vector3(3.0, 0.3, 3.0)
	var pad_shape: CollisionShape3D = CollisionShape3D.new()
	pad_shape.name = "Shape"
	pad_shape.shape = pad_box
	pad.add_child(pad_shape)
	pad_shape.owner = root
	var pad_box_mesh: BoxMesh = BoxMesh.new()
	pad_box_mesh.size = Vector3(3.0, 0.3, 3.0)
	var pad_material: StandardMaterial3D = StandardMaterial3D.new()
	pad_material.albedo_color = Color(0.4, 0.44, 0.54, 1.0)
	pad_box_mesh.material = pad_material
	var pad_mesh: MeshInstance3D = MeshInstance3D.new()
	pad_mesh.name = "Mesh"
	pad_mesh.mesh = pad_box_mesh
	pad.add_child(pad_mesh)
	pad_mesh.owner = root

	# The turret: the RayCast3D's host, turning so its ray sweeps the room.
	var turret: Node3D = Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0.0, 1.2, 0.0)
	root.add_child(turret)
	turret.owner = root
	var turret_mesh: MeshInstance3D = MeshInstance3D.new()
	turret_mesh.name = "Mesh"
	var turret_cyl: CylinderMesh = CylinderMesh.new()
	turret_cyl.top_radius = 0.35
	turret_cyl.bottom_radius = 0.5
	turret_cyl.height = 1.2
	var turret_material: StandardMaterial3D = StandardMaterial3D.new()
	turret_material.albedo_color = Color(0.35, 0.65, 1.0, 1.0)
	turret_cyl.material = turret_material
	turret_mesh.mesh = turret_cyl
	turret.add_child(turret_mesh)
	turret_mesh.owner = root
	var radar: RayCast3D = RayCast3D.new()
	radar.name = "Radar"
	radar.target_position = Vector3(0.0, 0.0, -14.0)
	radar.collision_mask = 1
	radar.enabled = true
	turret.add_child(radar)
	radar.owner = root

	# The Sweep: a ShapeCast3D running down the corridor, thick enough not to thread a gap.
	var sweep: ShapeCast3D = ShapeCast3D.new()
	sweep.name = "Sweep"
	sweep.position = Vector3(-6.0, 1.2, -14.0)
	sweep.target_position = Vector3(0.0, 0.0, 20.0)
	sweep.collision_mask = 1
	var sweep_shape: SphereShape3D = SphereShape3D.new()
	sweep_shape.radius = 0.9
	sweep.shape = sweep_shape
	sweep.enabled = true
	root.add_child(sweep)
	sweep.owner = root

	# The orbiting camera. NOT mouse-driven: the cursor has to stay free for the picking ray.
	var camera_arm: Node3D = Node3D.new()
	camera_arm.name = "CameraArm"
	root.add_child(camera_arm)
	camera_arm.owner = root
	var camera: Camera3D = Camera3D.new()
	camera.name = "Camera"
	camera.position = Vector3(0.0, 12.0, 15.0)
	camera.rotation_degrees = Vector3(-38.0, 0.0, 0.0)
	camera.current = true
	camera_arm.add_child(camera)
	camera.owner = root

	# Beams: unit boxes the sheet stretches between two points.
	var beams: Node3D = Node3D.new()
	beams.name = "Beams"
	root.add_child(beams)
	beams.owner = root
	for beam_spec: Array in [["RadarBeam", Color(1.0, 0.85, 0.3)], ["PickBeam", Color(0.4, 0.85, 1.0)],
			["ProbeBeam", Color(1.0, 0.45, 0.85)], ["SweepBeam", Color(0.5, 0.7, 1.0)]]:
		var beam: MeshInstance3D = MeshInstance3D.new()
		beam.name = beam_spec[0]
		var beam_box: BoxMesh = BoxMesh.new()
		beam_box.size = Vector3(0.08, 0.08, 1.0)
		var beam_material: StandardMaterial3D = StandardMaterial3D.new()
		beam_material.albedo_color = beam_spec[1]
		beam_material.emission_enabled = true
		beam_material.emission = beam_spec[1]
		beam_material.emission_energy_multiplier = 1.4
		beam_box.material = beam_material
		beam.mesh = beam_box
		beams.add_child(beam)
		beam.owner = root

	# Markers: small spheres the sheet parks on the answers.
	var markers: Node3D = Node3D.new()
	markers.name = "Markers"
	root.add_child(markers)
	markers.owner = root
	for mark_spec: Array in [["RadarMark", Color(1.0, 0.85, 0.3), 0.35], ["PickMark", Color(0.4, 0.85, 1.0), 0.35],
			["ProbeMark", Color(1.0, 0.45, 0.85), 0.6], ["SweepMark", Color(0.5, 0.7, 1.0), 0.9]]:
		var mark: MeshInstance3D = MeshInstance3D.new()
		mark.name = mark_spec[0]
		var mark_sphere: SphereMesh = SphereMesh.new()
		mark_sphere.radius = mark_spec[2]
		mark_sphere.height = float(mark_spec[2]) * 2.0
		var mark_material: StandardMaterial3D = StandardMaterial3D.new()
		mark_material.albedo_color = mark_spec[1]
		mark_material.emission_enabled = true
		mark_material.emission = mark_spec[1]
		mark_material.emission_energy_multiplier = 1.2
		mark_sphere.material = mark_material
		mark.mesh = mark_sphere
		markers.add_child(mark)
		mark.owner = root
	# A fixed pool the sphere query parks on whatever it caught - sized to its own max_results, so a
	# crowded frame can never ask for a marker that is not there.
	var zone_marks: Node3D = Node3D.new()
	zone_marks.name = "ZoneMarks"
	markers.add_child(zone_marks)
	zone_marks.owner = root
	var zone_material: StandardMaterial3D = StandardMaterial3D.new()
	zone_material.albedo_color = Color(0.45, 1.0, 0.6, 1.0)
	zone_material.emission_enabled = true
	zone_material.emission = Color(0.45, 1.0, 0.6)
	for zone_index: int in range(16):
		var zone_mark: MeshInstance3D = MeshInstance3D.new()
		zone_mark.name = "Zone%d" % (zone_index + 1)
		var zone_torus: TorusMesh = TorusMesh.new()
		zone_torus.inner_radius = 0.5
		zone_torus.outer_radius = 0.7
		zone_torus.material = zone_material
		zone_mark.mesh = zone_torus
		zone_mark.visible = false
		zone_marks.add_child(zone_mark)
		zone_mark.owner = root

	var hud_layer: CanvasLayer = CanvasLayer.new()
	hud_layer.name = "HudLayer"
	root.add_child(hud_layer)
	hud_layer.owner = root
	var hud: Label = Label.new()
	hud.name = "Hud"
	hud.position = Vector2(24.0, 16.0)
	hud.add_theme_font_size_override("font_size", 17)
	hud.text = "Move the mouse to aim the cyan pick ray - Left/Right arrows orbit the camera\nCyan = Cast Ray From Mouse Into (the marker grows when the cursor is on a target)\nYellow = a RayCast3D NODE on the turning turret - pink = Cast Sphere Motion Into\nBlue = a ShapeCast3D sweeping with thickness - green rings = Query Bodies In Sphere"
	hud_layer.add_child(hud)
	hud.owner = root
	var readout: Label = Label.new()
	readout.name = "Readout"
	readout.position = Vector2(24.0, 604.0)
	readout.add_theme_font_size_override("font_size", 17)
	readout.text = "cursor: sky   face -1   in sphere 0   in box 0   under turret 0   ball travel 1.00   sweep 1.00 (0)"
	hud_layer.add_child(readout)
	readout.owner = root

	return _save_scene(root, "%s/raycast_lab_3d.tscn" % RAYCAST_LAB_3D_DIR)


# ── 19. Hierarchy Playground (parenting, unparenting, and the follow-flags) ───

const HIERARCHY_DIR := "res://demo/showcase/hierarchy_playground"


## The hierarchy in one room: everything a game actually does to the scene tree while it runs, each
## written in the spelling the sheet reads as a hierarchy sentence.
##
##   MOUNT     the rider is reparented onto the horse's saddle, snapping to it
##   EQUIP     the hat becomes a child of the rider's head, but does NOT follow its size
##   SQUAD     one walk over a leader's children heals every soldier among them
##   BAR       the health bar stays a child and stops following - it never tilts
##   CAMERA    a pivot turns, and the camera parked on it orbits for free
##   CRATES    a downward ray under each crate parks it exactly on the ground
##
## Everything is plain GDScript on purpose: these are the very lines the hierarchy readings
## recognise, so the showcase is the round-trip proof as well as the demo. Press Space to mount and
## dismount; the readout names the tree as it stands.
func _build_hierarchy_playground() -> bool:
	# The soldier: a Node3D that carries its own hp, so "heal every child" has something to add to.
	var soldier: EventSheetResource = EventSheetResource.new()
	soldier.host_class = "Node3D"
	soldier.custom_class_name = "HierarchySoldier"
	soldier.class_description = "One member of the squad, carrying the hp a per-child heal adds to."
	soldier.variables = {
		"hp": {"type": "int", "default": 40, "exported": true,
			"attributes": {"tooltip": "This soldier's health. Healing the squad walks the leader's children and tops each one up."}}
	}
	var soldier_ready: EventRow = EventRow.new()
	soldier_ready.trigger_provider_id = "Core"
	soldier_ready.trigger_id = "OnReady"
	soldier_ready.actions.append(_action("Core", "AddToGroup", "{target}.add_to_group({group})",
		{"target": "self", "group": "\"soldier\""}))
	soldier.events.append(soldier_ready)
	if not _compile(soldier, "%s/soldier.tres" % HIERARCHY_DIR, "%s/soldier.gd" % HIERARCHY_DIR):
		return false

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node3D"
	sheet.custom_class_name = "HierarchyPlayground"
	sheet.emit_live_values = false
	sheet.variables = {
		"orbit_deg": {"type": "float", "default": 0.0, "exported": false},
		"mounted": {"type": "bool", "default": false, "exported": false},
		"crates_settled": {"type": "bool", "default": false, "exported": false},
		"squad_hp": {"type": "int", "default": 0, "exported": false}
	}

	var about: CommentRow = CommentRow.new()
	about.text = "[b]Hierarchy Playground[/b] - everything a game does to the scene tree while it runs, in one room. [b]Space[/b] mounts the rider onto the horse's [b]Saddle[/b] and dismounts again: mounting SNAPS the rider to its new parent, dismounting hands it back to the layout keeping the place it stands in. The [b]hat[/b] is a child of the rider's head that follows position and angle but NOT size - the flag that Godot has no single property for, so a RemoteTransform3D drives it instead. The [b]health bar[/b] is still a child and still dies with the rider, but ignores its movement, which is why it never tilts. The [b]squad[/b] is healed by ONE walk over the leader's children. The [b]camera[/b] orbits because its parent pivot turns - it does nothing itself. The [b]crates[/b] each cast a ray down and park on whatever the ray found."
	sheet.events.append(about)

	# ── Start of layout: build the tree the demo starts from. ──
	var setup: EventRow = EventRow.new()
	setup.trigger_provider_id = "Core"
	setup.trigger_id = "OnReady"
	setup.actions.append(_raw("equip(%Hat)"))
	# X13's first escape hatch: still a child (still freed with the rider, still picked as one of its
	# children), but its own transform is global from here on.
	setup.actions.append(_raw("%HealthBar.top_level = true"))
	setup.actions.append(_raw("heal_squad($Squad)"))
	sheet.events.append(setup)

	# ── Space: mount, and press again to get back off. ──
	var mount_row: EventRow = EventRow.new()
	mount_row.trigger_provider_id = "Core"
	mount_row.trigger_id = "OnProcess"
	mount_row.conditions.append(_condition("Core", "IsActionJustPressed",
		_ace_template("IsActionJustPressed"), {"action": "\"ui_accept\""}))
	mount_row.actions.append(_raw("\n".join(PackedStringArray([
		"if mounted:",
		"\tdismount(%Rider)",
		"else:",
		"\tmount(%Rider)",
		"mounted = not mounted"
	]))))
	sheet.events.append(mount_row)

	# ── The first physics frame: park every crate on the ground. ──
	#
	# Not at start of layout: the physics world has nothing in it until the first step, so a ray cast
	# in _ready finds an empty room and every crate stays floating.
	var settle: EventRow = EventRow.new()
	settle.trigger_provider_id = "Core"
	settle.trigger_id = "OnPhysicsProcess"
	settle.conditions.append(_condition("Core", "ExpressionIsTrue",
		_ace_template("ExpressionIsTrue"), {"expr": "not crates_settled"}))
	settle.actions.append(_raw("\n".join(PackedStringArray([
		"for crate: Node3D in $Crates.get_children():",
		"\tvar __down := PhysicsRayQueryParameters3D.create(",
		"\t\tcrate.global_position + Vector3(0.0, 3.0, 0.0),",
		"\t\tcrate.global_position - Vector3(0.0, 8.0, 0.0), 1)",
		"\tvar __ground := get_world_3d().direct_space_state.intersect_ray(__down)",
		"\tif not __ground.is_empty():",
		"\t\tcrate.global_position = __ground[\"position\"] + Vector3(0.0, 0.5, 0.0)",
		"crates_settled = true"
	]))))
	sheet.events.append(settle)

	# ── Every frame: turn the pivot, keep the bar upright, say what the tree looks like. ──
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	tick.actions.append(_raw("\n".join(PackedStringArray([
		"# The camera does nothing: its PARENT turns, and a child goes where its parent goes.",
		"orbit_deg = fmod(orbit_deg + 18.0 * delta, 360.0)",
		"$CameraPivot.rotation_degrees = Vector3(0.0, orbit_deg, 0.0)",
		"# The rider leans as it rides. The hat leans with it; the bar, ignoring the rider's",
		"# movement, has to be told where to stand - which is exactly what that flag costs.",
		"%Rider.rotation_degrees = Vector3(0.0, 0.0, sin(orbit_deg * 0.08) * 14.0)",
		"%HealthBar.global_position = %Rider.global_position + Vector3(0.0, 1.9, 0.0)",
		"%HealthBar.rotation = Vector3.ZERO",
		"$HudLayer/Readout.text = \"rider's parent: %s   hat follows size: no   bar ignores movement: yes   squad hp: %d   crates settled: %s\" % [%Rider.get_parent().name, squad_hp, \"yes\" if crates_settled else \"no\"]"
	]))))
	sheet.events.append(tick)

	# ── The hierarchy's own verbs, one function each. ──
	var mount_fn: EventFunction = EventFunction.new()
	mount_fn.function_name = "mount"
	mount_fn.enabled = true
	mount_fn.description = "Makes the rider a child of the saddle, snapping it to where the saddle stands."
	var p_rider: ACEParam = ACEParam.new()
	p_rider.id = "rider"
	p_rider.type_name = "Node3D"
	p_rider.type = TYPE_OBJECT
	mount_fn.params = [p_rider]
	mount_fn.events = [_raw("rider.reparent($Horse/Saddle, false)")]
	sheet.functions.append(mount_fn)

	var dismount_fn: EventFunction = EventFunction.new()
	dismount_fn.function_name = "dismount"
	dismount_fn.enabled = true
	dismount_fn.description = "Hands the rider back to the layout, keeping the place it already stands in."
	var p_dismount: ACEParam = ACEParam.new()
	p_dismount.id = "rider"
	p_dismount.type_name = "Node3D"
	p_dismount.type = TYPE_OBJECT
	dismount_fn.params = [p_dismount]
	dismount_fn.events = [_raw("rider.reparent(get_tree().current_scene)")]
	sheet.functions.append(dismount_fn)

	# The flags shape. A plain child follows position, angle AND size, and Godot has no single
	# property for "follow everything except size" - so the child is detached from its parent's
	# transform and a RemoteTransform3D puts back exactly the parts that stayed ticked. Both lines
	# are needed: detaching alone stops all following, and the follower alone changes nothing at all
	# while the child is still inheriting on its own (which is how this room caught it).
	var equip_fn: EventFunction = EventFunction.new()
	equip_fn.function_name = "equip"
	equip_fn.enabled = true
	equip_fn.description = "Puts the hat on the rider's head, following its position and angle but not its size."
	var p_hat: ACEParam = ACEParam.new()
	p_hat.id = "hat"
	p_hat.type_name = "Node3D"
	p_hat.type = TYPE_OBJECT
	equip_fn.params = [p_hat]
	equip_fn.events = [_raw("\n".join(PackedStringArray([
		"hat.reparent(%Head)",
		"hat.top_level = true",
		"var __follow_hat := RemoteTransform3D.new()",
		"%Head.add_child(__follow_hat)",
		"__follow_hat.remote_path = __follow_hat.get_path_to(hat)",
		"__follow_hat.update_scale = false"
	])))]
	sheet.functions.append(equip_fn)

	# One walk over a leader's children. It only READS each child, so walking the live list is safe -
	# a walk that MOVED them would have to take a copy first, which is the footgun the Doctor names.
	var heal_fn: EventFunction = EventFunction.new()
	heal_fn.function_name = "heal_squad"
	heal_fn.enabled = true
	heal_fn.description = "Tops up every soldier among a leader's children, and totals what they now carry."
	var p_leader: ACEParam = ACEParam.new()
	p_leader.id = "leader"
	p_leader.type_name = "Node3D"
	p_leader.type = TYPE_OBJECT
	heal_fn.params = [p_leader]
	heal_fn.events = [_raw("\n".join(PackedStringArray([
		"squad_hp = 0",
		"for unit in leader.get_children():",
		"\tif unit.is_in_group(\"soldier\"):",
		"\t\tunit.hp += 10",
		"\t\tsquad_hp += unit.hp"
	])))]
	sheet.functions.append(heal_fn)

	if not _compile(sheet, "%s/hierarchy_playground.tres" % HIERARCHY_DIR,
			"%s/hierarchy_playground.gd" % HIERARCHY_DIR):
		return false
	var emitted: String = FileAccess.get_file_as_string("%s/hierarchy_playground.gd" % HIERARCHY_DIR)
	emitted = emitted.replace("\n\nfunc ", "\n\n\nfunc ")
	emitted = emitted.replace("\n\n## @ace_hidden\nfunc ", "\n\n\n## @ace_hidden\nfunc ")
	var out: FileAccess = FileAccess.open("%s/hierarchy_playground.gd" % HIERARCHY_DIR, FileAccess.WRITE)
	out.store_string(emitted)
	out.close()

	return _save_hierarchy_scene()


## The room: a lit ground plane, the horse and its saddle, the rider with a head and a bar, a squad
## of four, three floating crates and an orbit pivot carrying the camera.
func _save_hierarchy_scene() -> bool:
	var root: Node3D = Node3D.new()
	root.name = "HierarchyPlayground"
	root.set_script(load("%s/hierarchy_playground.gd" % HIERARCHY_DIR))

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.shadow_enabled = true
	root.add_child(sun)
	sun.owner = root
	var world: WorldEnvironment = WorldEnvironment.new()
	world.name = "World"
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.08, 0.09, 0.12)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.46, 0.52, 0.64)
	environment.ambient_light_energy = 0.75
	world.environment = environment
	root.add_child(world)
	world.owner = root

	# The ground the crates land on - a real body on layer 1, because the crate snapping asks physics
	# where the floor is rather than assuming y = 0.
	var ground: StaticBody3D = StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = 1
	root.add_child(ground)
	ground.owner = root
	var ground_plane: PlaneMesh = PlaneMesh.new()
	ground_plane.size = Vector2(30.0, 30.0)
	var ground_material: StandardMaterial3D = StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.26, 0.3, 0.38, 1.0)
	ground_plane.material = ground_material
	var ground_mesh: MeshInstance3D = MeshInstance3D.new()
	ground_mesh.name = "Mesh"
	ground_mesh.mesh = ground_plane
	ground.add_child(ground_mesh)
	ground_mesh.owner = root
	var ground_shape: CollisionShape3D = CollisionShape3D.new()
	ground_shape.name = "Shape"
	var ground_box: BoxShape3D = BoxShape3D.new()
	ground_box.size = Vector3(30.0, 0.4, 30.0)
	ground_shape.shape = ground_box
	ground_shape.position = Vector3(0.0, -0.2, 0.0)
	ground.add_child(ground_shape)
	ground_shape.owner = root

	var horse: Node3D = Node3D.new()
	horse.name = "Horse"
	horse.position = Vector3(-2.0, 0.0, 0.0)
	root.add_child(horse)
	horse.owner = root
	_add_block(horse, root, "Mesh", Vector3(0.0, 0.9, 0.0), Vector3(2.4, 1.0, 0.9), Color(0.55, 0.4, 0.3))
	# The saddle is an empty marker, which is the point: a parent is a PLACE, not a thing you can see.
	var saddle: Node3D = Node3D.new()
	saddle.name = "Saddle"
	saddle.position = Vector3(0.0, 1.5, 0.0)
	horse.add_child(saddle)
	saddle.owner = root

	# The rider starts standing beside the horse. It is addressed by its SCENE-UNIQUE name, not by a
	# path: the moment it is mounted, `$Rider` would point at nothing, and %Rider still finds it.
	var rider: Node3D = Node3D.new()
	rider.name = "Rider"
	rider.unique_name_in_owner = true
	rider.position = Vector3(1.6, 0.0, 1.2)
	root.add_child(rider)
	rider.owner = root
	_add_block(rider, root, "Mesh", Vector3(0.0, 0.8, 0.0), Vector3(0.5, 1.6, 0.5), Color(0.35, 0.6, 0.95))
	var head: Node3D = Node3D.new()
	head.name = "Head"
	head.unique_name_in_owner = true
	head.position = Vector3(0.0, 1.75, 0.0)
	rider.add_child(head)
	head.owner = root
	var health_bar: MeshInstance3D = _add_block(rider, root, "HealthBar",
		Vector3(0.0, 1.9, 0.0), Vector3(1.0, 0.12, 0.12), Color(0.4, 0.95, 0.5))
	health_bar.unique_name_in_owner = true

	var hat: MeshInstance3D = _add_block(root, root, "Hat",
		Vector3(3.4, 0.2, 1.2), Vector3(0.7, 0.25, 0.7), Color(0.95, 0.75, 0.3))
	hat.unique_name_in_owner = true

	var squad: Node3D = Node3D.new()
	squad.name = "Squad"
	squad.position = Vector3(3.0, 0.0, -3.0)
	root.add_child(squad)
	squad.owner = root
	var soldier_script: GDScript = load("%s/soldier.gd" % HIERARCHY_DIR) as GDScript
	for index: int in range(4):
		var unit: Node3D = Node3D.new()
		unit.name = "Soldier%d" % (index + 1)
		unit.set_script(soldier_script)
		unit.position = Vector3(float(index) * 1.1, 0.0, 0.0)
		squad.add_child(unit)
		unit.owner = root
		# Persistent, or PackedScene.pack() drops it and "every soldier among the children" matches
		# nobody in the shipped scene.
		unit.add_to_group("soldier", true)
		_add_block(unit, root, "Mesh", Vector3(0.0, 0.6, 0.0), Vector3(0.4, 1.2, 0.4), Color(0.8, 0.45, 0.45))

	# Three crates left floating on purpose: the snapping row is what puts them down.
	var crates: Node3D = Node3D.new()
	crates.name = "Crates"
	root.add_child(crates)
	crates.owner = root
	var crate_spots: Array[Vector3] = [Vector3(-4.5, 2.4, 3.0), Vector3(-6.0, 3.1, 0.5),
		Vector3(-3.2, 1.9, -3.4)]
	for index: int in range(crate_spots.size()):
		var crate: Node3D = _add_block(crates, root, "Crate%d" % (index + 1),
			crate_spots[index], Vector3(1.0, 1.0, 1.0), Color(0.66, 0.7, 0.8))
		crate.owner = root

	# The pivot IS the orbit: the camera is parked on it and never moves itself.
	var pivot: Node3D = Node3D.new()
	pivot.name = "CameraPivot"
	root.add_child(pivot)
	pivot.owner = root
	var camera: Camera3D = Camera3D.new()
	camera.name = "Camera"
	camera.position = Vector3(0.0, 4.2, 8.0)
	camera.rotation_degrees = Vector3(-20.0, 0.0, 0.0)
	camera.current = true
	pivot.add_child(camera)
	camera.owner = root

	var hud_layer: CanvasLayer = CanvasLayer.new()
	hud_layer.name = "HudLayer"
	root.add_child(hud_layer)
	hud_layer.owner = root
	var hud: Label = Label.new()
	hud.name = "Hud"
	hud.position = Vector2(24.0, 16.0)
	hud.add_theme_font_size_override("font_size", 17)
	hud.text = "Space mounts the rider onto the horse's saddle, and dismounts again\nThe hat is a child that does not follow size - the bar is a child that ignores movement\nOne walk over the squad leader's children heals every soldier among them\nThe camera orbits because its parent pivot turns - the crates park on the ray they cast down"
	hud_layer.add_child(hud)
	hud.owner = root
	var readout: Label = Label.new()
	readout.name = "Readout"
	readout.position = Vector2(24.0, 604.0)
	readout.add_theme_font_size_override("font_size", 17)
	readout.text = "rider's parent: HierarchyPlayground   hat follows size: no   bar ignores movement: yes   squad hp: 0   crates settled: no"
	hud_layer.add_child(readout)
	readout.owner = root

	return _save_scene(root, "%s/hierarchy_playground.tscn" % HIERARCHY_DIR)


# ── 20. Boomer Level - the shooter kit end to end ───────────────────────────────────────────

const BOOMER_DIR := "res://demo/showcase/boomer_level"


## A small 3D level built out of the shooter vocabulary and nothing else: a red keycard, the door
## that wants it, two grunts that shout to each other and turn on whoever hurt them, a health pickup
## that comes back, a secret, and an exit that reads the tally out. Four sheets - the level, the
## door, a grunt and the pickup - because three of those verbs are things an OBJECT does about
## itself, and a level sheet that reached into them would be exactly the tangle the rows exist to
## avoid. The player is the FPS Controller pack with the feel knobs turned on, and the weapon under
## the Head bobs and sways through the pack's own two rows.
func _build_boomer_level() -> bool:
	if not _build_boomer_door_sheet():
		return false
	if not _build_boomer_grunt_sheet():
		return false
	if not _build_boomer_pickup_sheet():
		return false
	if not _build_boomer_level_sheet():
		return false
	return _save_boomer_scene()


## The door: it knows the key it wants, how it opens, and what it does when it is tried without one.
func _build_boomer_door_sheet() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "StaticBody3D"
	sheet.custom_class_name = "BoomerLevelDoor"
	sheet.class_description = "The red keycard door. Try Door on the level's sheet opens it when the key fits and tells it here when it does not."
	sheet.variables = {
		"needs_key": {"type": "String", "default": "red_key", "exported": true,
			"attributes": {"tooltip": "The key this door wants. Try Door reads it off the door itself."}},
		"door_open": {"type": "bool", "default": false, "exported": false,
			"attributes": {"tooltip": "True once the door has opened - what makes the slide happen once."}},
		"slide_height": {"type": "float", "default": 3.2, "exported": true,
			"attributes": {"tooltip": "How far the door rises out of the way, in metres."}},
		"slide_seconds": {"type": "float", "default": 0.6, "exported": true,
			"attributes": {"tooltip": "How long the door takes to open."}},
		"locked_hint": {"type": "String", "default": "", "exported": false,
			"attributes": {"tooltip": "What to tell the player when the door refuses. The level's HUD reads it."}}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Keycard door: it opens when the key fits and says so when it does not."
	sheet.events.append(about)
	var open_door: EventFunction = EventFunction.new()
	open_door.function_name = "open_door"
	open_door.description = "Opens the door and leaves it open. Try Door calls this when the key fits."
	open_door.events.append(_raw(_ace_line("OpenDoor", "door", {
		"door": "self", "opened": "door_open",
		"slide": "Vector3(0.0, slide_height, 0.0)", "seconds": "slide_seconds"})))
	sheet.functions.append(open_door)
	var refused: EventRow = EventRow.new()
	refused.trigger_provider_id = "Core"
	refused.trigger_id = "OnLockedDoorTried"
	refused.actions.append(_action("Core", "SetVar", _ace_template("SetVar"), {
		"var_name": "locked_hint", "value": "\"Locked. You need the %s keycard.\" % str(key)"}))
	sheet.events.append(refused)
	return _compile(sheet, "%s/keycard_door.tres" % BOOMER_DIR, "%s/keycard_door.gd" % BOOMER_DIR)


## A grunt: it can be told who to go for, it turns on whoever hurt it, and it walks at its target.
func _build_boomer_grunt_sheet() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody3D"
	sheet.custom_class_name = "BoomerLevelGrunt"
	sheet.class_description = "One grunt. Alert Enemies Within tells it who to go for, and being hurt makes it shout - which is what turns a room of them on each other."
	sheet.variables = {
		"hp": {"type": "float", "default": 40.0, "exported": true,
			"attributes": {"tooltip": "How much damage this grunt takes before it falls."}},
		"walk_speed": {"type": "float", "default": 2.4, "exported": true,
			"attributes": {"tooltip": "How fast it walks at whatever it is going for."}},
		"shout_radius": {"type": "float", "default": 9.0, "exported": true,
			"attributes": {"tooltip": "How far its shout carries when something hurts it."}}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "A grunt: told who to go for by Alert Enemies Within, and shouting to the room when it is hurt."
	sheet.events.append(about)
	# `target` is a NODE, which the variables table has no spelling for, so it is declared here -
	# the same reason the FPS Controller pack declares its gravity direction as a class-level line.
	var member: RawCodeRow = RawCodeRow.new()
	member.code = "## Whoever this grunt is going for right now.\nvar target: Node3D = null"
	sheet.events.append(member)
	# Told who to go for. The shipped Retaliate row is the whole rule: only its own kind counts, so a
	# shout from the player never makes two grunts fight each other over you.
	var alerted: EventRow = EventRow.new()
	alerted.trigger_provider_id = "Core"
	alerted.trigger_id = "OnAlerted"
	alerted.actions.append(_action("Core", "RetaliateAgainstAttacker",
		_ace_template("RetaliateAgainstAttacker", "grunt"),
		{"attacker": "who", "group": "\"enemies\"", "target": "target"}))
	sheet.events.append(alerted)
	# Walking at it. One tick row, so the whole of what a grunt does is three events.
	var walk: EventRow = EventRow.new()
	walk.trigger_provider_id = "Core"
	walk.trigger_id = "OnPhysicsProcess"
	walk.actions.append(_raw("\n".join(PackedStringArray([
		"if target != null and is_instance_valid(target):",
		"\tvar toward := (target.global_position - global_position)",
		"\tvelocity.x = toward.normalized().x * walk_speed",
		"\tvelocity.z = toward.normalized().z * walk_speed",
		"move_and_slide()"
	]))))
	sheet.events.append(walk)
	var take_damage: EventFunction = EventFunction.new()
	take_damage.function_name = "take_damage"
	take_damage.description = "Takes a hit. The blast rows call this by name; the shout is what makes the room turn."
	var amount: ACEParam = ACEParam.new()
	amount.id = "amount"
	amount.type_name = "float"
	take_damage.params.append(amount)
	take_damage.events.append(_raw("hp -= amount"))
	take_damage.events.append(_raw(_ace_line("AlertEnemiesWithin", "hurt",
		{"at": "global_position", "radius": "shout_radius", "target": "self", "group": "\"enemies\""})))
	take_damage.events.append(_raw("\n".join(PackedStringArray([
		"if hp <= 0.0:",
		"\tget_parent().count_kill()",
		"\tqueue_free()"
	]))))
	sheet.functions.append(take_damage)
	return _compile(sheet, "%s/grunt.tres" % BOOMER_DIR, "%s/grunt.gd" % BOOMER_DIR)


## The health pickup: one row, on the pickup itself, because coming back is something it does.
func _build_boomer_pickup_sheet() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Area3D"
	sheet.custom_class_name = "BoomerLevelPickup"
	sheet.class_description = "A health pickup that comes back. Walking into it takes it away and the Respawn After row puts it back."
	sheet.variables = {
		"respawn_seconds": {"type": "float", "default": 3.0, "exported": true,
			"attributes": {"tooltip": "How long the pickup stays gone before it comes back."}}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "A health pickup: taken, then back after its own timer."
	sheet.events.append(about)
	var taken: EventRow = EventRow.new()
	taken.trigger_provider_id = "Core"
	taken.trigger_id = "OnBodyEntered"
	taken.actions.append(_action("Core", "RespawnAfter", _ace_template("RespawnAfter", "pickup"),
		{"seconds": "respawn_seconds"}))
	sheet.events.append(taken)
	return _compile(sheet, "%s/health_pickup.tres" % BOOMER_DIR, "%s/health_pickup.gd" % BOOMER_DIR)


## The level: the keys, the door, the secret, the rocket and the tally at the exit.
func _build_boomer_level_sheet() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node3D"
	sheet.custom_class_name = "BoomerLevel"
	sheet.class_description = "A small shooter level: a red keycard, the door that wants it, two grunts that turn on each other, a respawning pickup, a secret and the exit tally."
	sheet.variables = {
		"keys": {"type": "Array", "default": [], "exported": false,
			"attributes": {"tooltip": "Every keycard picked up so far, by name. The door rows read this list."}},
		"secrets_found": {"type": "Array", "default": [], "exported": false,
			"attributes": {"tooltip": "Every secret counted so far. Each one goes in once."}},
		"secrets_total": {"type": "int", "default": 1, "exported": true,
			"attributes": {"tooltip": "How many secrets this level hides."}},
		"kills": {"type": "int", "default": 0, "exported": false,
			"attributes": {"tooltip": "How many grunts have fallen."}},
		"enemies_total": {"type": "int", "default": 2, "exported": true,
			"attributes": {"tooltip": "How many grunts the level started with."}},
		"level_seconds": {"type": "float", "default": 0.0, "exported": false,
			"attributes": {"tooltip": "How long the level has been running."}},
		"par_seconds": {"type": "float", "default": 60.0, "exported": true,
			"attributes": {"tooltip": "The time to beat, shown beside your own."}},
		"level_over": {"type": "bool", "default": false, "exported": false,
			"attributes": {"tooltip": "True once the exit is reached - the clock stops and the tally is written."}}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Boomer Level: WASD moves, the mouse looks, Tab throws a rocket at the grunts. Find the red keycard, open the door, take the exit."
	sheet.events.append(about)

	var ready_event: EventRow = EventRow.new()
	ready_event.trigger_provider_id = "Core"
	ready_event.trigger_id = "OnReady"
	ready_event.actions.append(_action("Core", "PrintLog", "print({message})", {
		"message": "\"Boomer Level - WASD/arrows move, mouse looks, Space jumps (hold it on landing to bunny hop), Tab throws a rocket, Esc frees the mouse.\""}))
	sheet.events.append(ready_event)

	# The clock, which runs while the level is not over.
	var clock: EventRow = EventRow.new()
	clock.trigger_provider_id = "Core"
	clock.trigger_id = "OnPhysicsProcess"
	clock.conditions.append(_condition("Core", "CompareVar", _ace_template("CompareVar"),
		{"var_name": "level_over", "op": "==", "value": "false"}))
	clock.actions.append(_action("Core", "AddVar", _ace_template("AddVar"),
		{"var_name": "level_seconds", "amount": "delta"}))
	sheet.events.append(clock)

	# The feel layer: the weapon under the Head bobs as you run and lags as you turn. Two rows.
	var feel: EventRow = EventRow.new()
	feel.trigger_provider_id = "Core"
	feel.trigger_id = "OnProcess"
	feel.actions.append(_raw("$Player/FPSController.bob_with_movement($Player/Head/Weapon)"))
	feel.actions.append(_raw("$Player/FPSController.sway_with_mouse($Player/Head/Weapon)"))
	sheet.events.append(feel)

	# The rocket. Explode At pushes bodies away from the point, so standing in your own blast throws
	# you - which is the whole of rocket jumping, and is why the grunts start shouting at each other.
	var rocket: EventRow = EventRow.new()
	rocket.trigger_provider_id = "Core"
	rocket.trigger_id = "OnProcess"
	rocket.conditions.append(_condition("Core", "IsActionJustPressed",
		_ace_template("IsActionJustPressed"), {"action": "\"ui_focus_next\""}))
	rocket.actions.append(_action("Core", "ExplodeAt", _ace_template("ExplodeAt", "rocket"), {
		"point": "$Grunt1.global_position", "radius": "6.0", "damage": "35", "push": "10.0", "mask": "1"}))
	sheet.events.append(rocket)

	# The keycard. Pick Up Key is the list word, said about keys.
	var card: EventRow = EventRow.new()
	card.trigger_provider_id = "Core"
	card.trigger_id = "OnBodyEntered"
	card.trigger_source_path = "RedCard"
	card.actions.append(_action("Core", "PickUpKey", _ace_template("PickUpKey"),
		{"key": "\"red_key\"", "keys": "keys"}))
	card.actions.append(_raw("$RedCard.hide()"))
	card.actions.append(_raw("$RedCard.set_deferred(\"monitoring\", false)"))
	sheet.events.append(card)

	# The door. One row does the whole of trying it: it opens, or it says it is locked.
	var door: EventRow = EventRow.new()
	door.trigger_provider_id = "Core"
	door.trigger_id = "OnBodyEntered"
	door.trigger_source_path = "DoorTrigger"
	door.actions.append(_action("Core", "TryDoor", _ace_template("TryDoor", "level"),
		{"door": "$RedDoor", "keys": "keys"}))
	sheet.events.append(door)

	# The secret, counted once however many times you walk back through it.
	var secret: EventRow = EventRow.new()
	secret.trigger_provider_id = "Core"
	secret.trigger_id = "OnBodyEntered"
	secret.trigger_source_path = "SecretRoom"
	secret.actions.append(_action("Core", "MarkSecretFound", _ace_template("MarkSecretFound"),
		{"name": "\"SecretRoom\"", "found": "secrets_found"}))
	sheet.events.append(secret)

	# The exit: the clock stops and the tally is written, in the shipped words for every number in it.
	var exit_event: EventRow = EventRow.new()
	exit_event.trigger_provider_id = "Core"
	exit_event.trigger_id = "OnBodyEntered"
	exit_event.trigger_source_path = "Exit"
	exit_event.actions.append(_action("Core", "SetVar", _ace_template("SetVar"),
		{"var_name": "level_over", "value": "true"}))
	# Built by concatenation rather than by formatting: the line it writes is ITSELF a `%` format
	# string, and running one through another would eat the emitted `%d`s.
	exit_event.actions.append(_raw("$HudLayer/Tally.text = \"Kills %d of %d   Secrets %d of %d   Time %s of %s\" % [kills, enemies_total, " \
		+ _ace_template("SecretsFoundCount").format({"found": "secrets_found"}) + ", secrets_total, " \
		+ _ace_template("FormatTime").format({"seconds": "level_seconds"}) + ", " \
		+ _ace_template("FormatTime").format({"seconds": "par_seconds"}) + "]"))
	sheet.events.append(exit_event)

	# The HUD line the door and the keys write to, refreshed every tick.
	var hud: EventRow = EventRow.new()
	hud.trigger_provider_id = "Core"
	hud.trigger_id = "OnProcess"
	hud.actions.append(_raw("$HudLayer/Hud.text = \"Keys %d   Secrets %d of %d   %s\" % [" \
		+ _ace_template("KeysHeld").format({"keys": "keys"}) + ", " \
		+ _ace_template("SecretsFoundCount").format({"found": "secrets_found"}) \
		+ ", secrets_total, $RedDoor.locked_hint]"))
	sheet.events.append(hud)

	var count_kill: EventFunction = EventFunction.new()
	count_kill.function_name = "count_kill"
	count_kill.description = "Counts a grunt that fell. Each grunt calls this by name as it goes."
	count_kill.events.append(_raw(_ace_line("AddVar", "", {"var_name": "kills", "amount": "1"})))
	sheet.functions.append(count_kill)
	return _compile(sheet, "%s/boomer_level.tres" % BOOMER_DIR, "%s/boomer_level.gd" % BOOMER_DIR)


## The level itself: a floor, the player rig with a weapon under the Head, the card, the door and
## its trigger, two grunts in the enemies group, a pickup, a secret and the exit.
func _save_boomer_scene() -> bool:
	var root: Node3D = Node3D.new()
	root.name = "BoomerLevel"
	root.set_script(load("%s/boomer_level.gd" % BOOMER_DIR))

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	sun.shadow_enabled = true
	root.add_child(sun); sun.owner = root

	_boomer_floor(root)

	var player: CharacterBody3D = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0.0, 1.2, 10.0)
	root.add_child(player); player.owner = root
	var player_shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = 0.4
	player_shape.shape = capsule
	player.add_child(player_shape); player_shape.owner = root
	var head: Node3D = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 0.6, 0.0)
	player.add_child(head); head.owner = root
	# The weapon the feel rows drive. It hangs off the Head, so looking around moves it and the sway
	# row is the only thing that makes it lag.
	var weapon: MeshInstance3D = MeshInstance3D.new()
	weapon.name = "Weapon"
	weapon.position = Vector3(0.28, -0.24, -0.55)
	var weapon_mesh: BoxMesh = BoxMesh.new()
	weapon_mesh.size = Vector3(0.12, 0.12, 0.6)
	var weapon_material: StandardMaterial3D = StandardMaterial3D.new()
	weapon_material.albedo_color = Color(0.22, 0.24, 0.3, 1.0)
	weapon_mesh.material = weapon_material
	weapon.mesh = weapon_mesh
	head.add_child(weapon); weapon.owner = root
	var arm: SpringArm3D = SpringArm3D.new()
	arm.name = "Arm"
	arm.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	arm.spring_length = 0.05
	head.add_child(arm); arm.owner = root
	var camera: Camera3D = Camera3D.new()
	camera.name = "Camera3D"
	camera.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	camera.current = true
	arm.add_child(camera); camera.owner = root
	# The feel knobs the mockup names, set here so the showcase reads as its own settings rather than
	# as the pack's defaults: a shooter's air control, the bunny hop on, a visible bob and a soft sway.
	_attach_behavior(player, "FPSController", FPS_CONTROLLER, root, {
		"air_control": 0.35, "keep_momentum": true,
		"bob_amount": 0.05, "bob_period": 0.55, "sway_amount": 0.0025, "sway_speed": 9.0})

	var card: Area3D = _boomer_area(root, "RedCard", Vector3(-6.0, 0.8, 0.0), Vector3(0.6, 0.6, 0.1))
	_boomer_mesh(card, root, Vector3(0.6, 0.6, 0.1), Color(0.9, 0.2, 0.24, 1.0))

	var red_door: StaticBody3D = StaticBody3D.new()
	red_door.name = "RedDoor"
	red_door.position = Vector3(0.0, 1.6, -8.0)
	red_door.set_script(load("%s/keycard_door.gd" % BOOMER_DIR))
	root.add_child(red_door); red_door.owner = root
	var door_shape: CollisionShape3D = CollisionShape3D.new()
	var door_box: BoxShape3D = BoxShape3D.new()
	door_box.size = Vector3(3.0, 3.2, 0.4)
	door_shape.shape = door_box
	red_door.add_child(door_shape); door_shape.owner = root
	_boomer_mesh(red_door, root, Vector3(3.0, 3.2, 0.4), Color(0.72, 0.18, 0.2, 1.0))

	# Every trigger box sits clear of the floor. An Area3D reports a StaticBody3D the same way it
	# reports the player, so a box whose bottom face grazes the ground counts the floor as a visitor
	# the moment the level loads - which counted the secret before anybody had walked anywhere.
	var door_trigger: Area3D = _boomer_area(root, "DoorTrigger", Vector3(0.0, 1.3, -6.4),
		Vector3(3.0, 2.0, 1.6))

	_boomer_grunt(root, "Grunt1", Vector3(-2.5, 1.0, -3.0), Color(0.86, 0.45, 0.16, 1.0))
	_boomer_grunt(root, "Grunt2", Vector3(2.5, 1.0, -3.0), Color(0.7, 0.35, 0.5, 1.0))

	var pickup: Area3D = _boomer_area(root, "HealthPickup", Vector3(5.0, 0.7, 2.0),
		Vector3(0.7, 0.7, 0.7))
	pickup.set_script(load("%s/health_pickup.gd" % BOOMER_DIR))
	_boomer_mesh(pickup, root, Vector3(0.7, 0.7, 0.7), Color(0.25, 0.8, 0.4, 1.0))

	var secret: Area3D = _boomer_area(root, "SecretRoom", Vector3(-8.5, 1.3, 5.0),
		Vector3(2.4, 2.0, 2.4))
	var exit_area: Area3D = _boomer_area(root, "Exit", Vector3(0.0, 1.3, -11.0),
		Vector3(3.0, 2.0, 1.2))

	var hud_layer: CanvasLayer = CanvasLayer.new()
	hud_layer.name = "HudLayer"
	root.add_child(hud_layer); hud_layer.owner = root
	var hud: Label = Label.new()
	hud.name = "Hud"
	hud.position = Vector2(24.0, 20.0)
	hud.add_theme_font_size_override("font_size", 19)
	hud.text = "Keys 0   Secrets 0 of 1"
	hud_layer.add_child(hud); hud.owner = root
	var tally: Label = Label.new()
	tally.name = "Tally"
	tally.position = Vector2(24.0, 52.0)
	tally.add_theme_font_size_override("font_size", 19)
	tally.text = ""
	hud_layer.add_child(tally); tally.owner = root
	# Every node named above is reached by path from the sheet, so a rename here is a broken row -
	# which is what the showcase test's node-name list is for.
	return _save_scene(root, "%s/boomer_level.tscn" % BOOMER_DIR) \
		and door_trigger != null and secret != null and exit_area != null


## The floor everything in the level stands on.
func _boomer_floor(root: Node3D) -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.name = "Floor"
	root.add_child(floor_body); floor_body.owner = root
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(30.0, 1.0, 30.0)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_shape); floor_shape.owner = root
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var floor_box_mesh: BoxMesh = BoxMesh.new()
	floor_box_mesh.size = Vector3(30.0, 1.0, 30.0)
	var floor_material: StandardMaterial3D = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.3, 0.33, 0.38, 1.0)
	floor_box_mesh.material = floor_material
	floor_mesh.mesh = floor_box_mesh
	floor_mesh.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_mesh); floor_mesh.owner = root


## One Area3D with a box shape, which is what a card, a door trigger, a pickup, a secret and an exit
## all are in this level - so all five are built the same way and none of them can drift.
func _boomer_area(root: Node3D, node_name: String, at: Vector3, box_size: Vector3) -> Area3D:
	var area: Area3D = Area3D.new()
	area.name = node_name
	area.position = at
	root.add_child(area); area.owner = root
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = box_size
	shape.shape = box
	area.add_child(shape); shape.owner = root
	return area


## A coloured box hung under a node, for the things a player has to be able to see.
func _boomer_mesh(parent: Node3D, root: Node3D, box_size: Vector3, tint: Color) -> void:
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	mesh_node.name = "Mesh"
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = box_size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = tint
	box_mesh.material = material
	mesh_node.mesh = box_mesh
	parent.add_child(mesh_node); mesh_node.owner = root


## One grunt, in the `enemies` group PERSISTENTLY - a group added without that flag is not saved into
## the packed scene, and the alert row walks that group, so the whole item would silently do nothing.
func _boomer_grunt(root: Node3D, node_name: String, at: Vector3, tint: Color) -> void:
	var grunt: CharacterBody3D = CharacterBody3D.new()
	grunt.name = node_name
	grunt.position = at
	grunt.set_script(load("%s/grunt.gd" % BOOMER_DIR))
	root.add_child(grunt); grunt.owner = root
	grunt.add_to_group("enemies", true)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = 0.4
	shape.shape = capsule
	grunt.add_child(shape); shape.owner = root
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	mesh_node.name = "Mesh"
	var capsule_mesh: CapsuleMesh = CapsuleMesh.new()
	capsule_mesh.height = 1.8
	capsule_mesh.radius = 0.4
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = tint
	capsule_mesh.material = material
	mesh_node.mesh = capsule_mesh
	grunt.add_child(mesh_node); mesh_node.owner = root


## One coloured box, parented and owned in the one step every node in this room needs.
func _add_block_shape(parent: Node, root: Node, node_name: String, at: Vector3, box_size: Vector3,
		tint: Color) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.position = at
	parent.add_child(body)
	body.owner = root
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	mesh_node.name = "Mesh"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = tint
	mesh.material = material
	mesh_node.mesh = mesh
	body.add_child(mesh_node)
	mesh_node.owner = root
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.name = "Collider"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = box_size
	collider.shape = shape
	body.add_child(collider)
	collider.owner = root
	return body


## One coloured box, parented and owned in the one step every node in this room needs.
func _add_block(parent: Node, root: Node, node_name: String, at: Vector3, box_size: Vector3,
		tint: Color) -> MeshInstance3D:
	var block: MeshInstance3D = MeshInstance3D.new()
	block.name = node_name
	block.position = at
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = tint
	mesh.material = material
	block.mesh = mesh
	parent.add_child(block)
	block.owner = root
	return block


# ── 20. Mirror and Flip - which way a thing faces, on every host ──────────────


const MIRROR_DIR := "res://demo/showcase/mirror_and_flip"


func _build_mirror_and_flip() -> bool:
	# The hero: a whole object that mirrors, so its ray, its muzzle point and its dust mirror WITH it.
	# Its name plate is the one child that must not come along, and Keep Upright is why it does not.
	var hero: EventSheetResource = EventSheetResource.new()
	hero.host_class = "Node2D"
	hero.custom_class_name = "MirrorHero"
	hero.class_description = "A character that faces the way it moves - picture, sword ray, muzzle point and dust all together."
	hero.emit_live_values = false
	hero.variables = {
		"speed": {"type": "float", "default": 120.0, "exported": true,
			"attributes": {"tooltip": "How fast the hero paces back and forth, in pixels a second."}},
		"t": {"type": "float", "default": 0.0, "exported": false,
			"attributes": {"tooltip": "The pacing clock, in seconds."}},
		"velocity": {"type": "Vector2", "default": Vector2.ZERO, "exported": false,
			"attributes": {"tooltip": "How fast the hero is moving right now. Its sign is the whole of which way it faces."}}
	}

	var hero_about: CommentRow = CommentRow.new()
	hero_about.text = "[b]Mirror Hero[/b] - one row faces the way it moves, and because it mirrors the WHOLE object every child comes along: the sword's ray reaches the way the hero looks, the muzzle point moves to the other hand, the dust blows the right way. The [b]name plate[/b] is the exception - Keep Upright re-negates it, so the text reads forwards whichever way the hero faces."
	hero.events.append(hero_about)

	var pace: EventRow = EventRow.new()
	pace.trigger_provider_id = "Core"
	pace.trigger_id = "OnProcess"
	pace.actions.append(_raw("t += delta"))
	pace.actions.append(_raw("velocity.x = sin(t * 1.2) * speed"))
	pace.actions.append(_raw("position += velocity * delta"))
	pace.actions.append(_action("Core", "FaceDirectionOfMovement",
		_ace_template("FaceDirectionOfMovement"), {"velocity": "velocity", "target": ""}))
	pace.actions.append(_action("Core", "KeepUpright",
		_ace_template("KeepUpright"), {"target": "$Plate"}))
	hero.events.append(pace)
	if not _compile(hero, "%s/hero.tres" % MIRROR_DIR, "%s/hero.gd" % MIRROR_DIR):
		return false

	var hero_root: Node2D = _mirror_hero_node()
	hero_root.set_script(load("%s/hero.gd" % MIRROR_DIR))
	_own_tree(hero_root, hero_root)
	if not _save_scene(hero_root, "%s/hero.tscn" % MIRROR_DIR):
		return false

	# The stage: the same two words on four more hosts - a UI panel, a sub-viewport's view, one tile,
	# and a 3D twin that turns around instead of scaling itself inside out.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "MirrorAndFlip"
	sheet.emit_live_values = false
	sheet.variables = {
		"mirror_ui": {"type": "bool", "default": true, "exported": true,
			"attributes": {"tooltip": "Mirror the panel. The pivot moves to its middle first, which is why it mirrors in place instead of jumping sideways."}},
		"mirror_view": {"type": "bool", "default": true, "exported": true,
			"attributes": {"tooltip": "Mirror what the sub-viewport shows - the rear-view-mirror trick."}},
		"flip_tile": {"type": "bool", "default": true, "exported": true,
			"attributes": {"tooltip": "Flip the third tile, so one wall drawing covers both sides of the corridor."}}
	}

	var about: CommentRow = CommentRow.new()
	about.text = "[b]Mirror and Flip[/b] - one verb, every host. The [b]hero[/b] mirrors as a whole object and drags its ray, its muzzle and its dust along. The [b]panel[/b] mirrors in place because its pivot moves to the middle first. The [b]sub-viewport[/b] mirrors its view. The third [b]tile[/b] carries the flip bit, so one drawing covers both sides. The [b]3D twin[/b] does NOT scale itself negative - it turns around, which is the honest 3D answer and leaves nothing inside out."
	sheet.events.append(about)

	var setup: EventRow = EventRow.new()
	setup.trigger_provider_id = "Core"
	setup.trigger_id = "OnReady"
	setup.actions.append(_action("Core", "SetMirroredControl",
		_ace_template("SetMirroredControl"), {"mirrored": "mirror_ui", "target": "$Panel"}))
	setup.actions.append(_action("Core", "MirrorViewportView",
		_ace_template("MirrorViewportView"), {"mirrored": "mirror_view", "target": "$Mirror"}))
	setup.actions.append(_action("Core", "SetTileFlipped",
		_ace_template("SetTileFlipped"),
		{"coords": "Vector2i(2, 0)", "mirrored": "flip_tile", "target": "$Tiles"}))
	sheet.events.append(setup)

	var turn: EventRow = EventRow.new()
	turn.trigger_provider_id = "Core"
	turn.trigger_id = "OnProcess"
	turn.conditions.append(_every("turn", "2.0"))
	turn.actions.append(_action("Core", "TurnAround",
		_ace_template("TurnAround"), {"target": "$Mirror/View/Twin"}))
	sheet.events.append(turn)
	if not _compile(sheet, "%s/mirror_and_flip.tres" % MIRROR_DIR, "%s/mirror_and_flip.gd" % MIRROR_DIR):
		return false

	# ── The room ──
	var root: Node2D = Node2D.new()
	root.name = "MirrorAndFlip"
	root.set_script(load("%s/mirror_and_flip.gd" % MIRROR_DIR))

	var title: Label = Label.new()
	title.name = "Title"
	title.position = Vector2(24, 18)
	title.add_theme_font_size_override("font_size", 22)
	title.text = "Mirror and flip   ·   one verb, every host"
	root.add_child(title)
	title.owner = root

	var hero_in_room: Node2D = _mirror_hero_node()
	hero_in_room.set_script(load("%s/hero.gd" % MIRROR_DIR))
	hero_in_room.position = Vector2(300, 300)
	root.add_child(hero_in_room)
	hero_in_room.owner = root
	_own_tree(hero_in_room, root)

	var tiles: TileMapLayer = TileMapLayer.new()
	tiles.name = "Tiles"
	tiles.position = Vector2(80, 460)
	tiles.tile_set = _mirror_tile_set()
	for column: int in 4:
		tiles.set_cell(Vector2i(column, 0), 0, Vector2i(0, 0))
	root.add_child(tiles)
	tiles.owner = root

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Panel"
	panel.position = Vector2(760, 90)
	panel.custom_minimum_size = Vector2(300, 84)
	panel.size = Vector2(300, 84)
	var panel_text: Label = Label.new()
	panel_text.name = "PanelText"
	panel_text.text = "This panel is mirrored in place."
	panel_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(panel_text)
	root.add_child(panel)
	panel.owner = root
	panel_text.owner = root

	var mirror: SubViewportContainer = SubViewportContainer.new()
	mirror.name = "Mirror"
	mirror.position = Vector2(760, 220)
	mirror.custom_minimum_size = Vector2(300, 200)
	mirror.size = Vector2(300, 200)
	mirror.stretch = true
	root.add_child(mirror)
	mirror.owner = root

	var view: SubViewport = SubViewport.new()
	view.name = "View"
	view.size = Vector2i(300, 200)
	view.transparent_bg = false
	mirror.add_child(view)
	view.owner = root

	var twin: Node3D = Node3D.new()
	twin.name = "Twin"
	view.add_child(twin)
	twin.owner = root

	var twin_mesh: MeshInstance3D = MeshInstance3D.new()
	twin_mesh.name = "TwinMesh"
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(1.4, 1.4, 0.5)
	var skin: StandardMaterial3D = StandardMaterial3D.new()
	skin.albedo_color = Color(0.35, 0.62, 0.95)
	box.material = skin
	twin_mesh.mesh = box
	twin.add_child(twin_mesh)
	twin_mesh.owner = root

	var nose: MeshInstance3D = MeshInstance3D.new()
	nose.name = "Nose"
	nose.position = Vector3(0.0, 0.0, 0.5)
	var nose_mesh: BoxMesh = BoxMesh.new()
	nose_mesh.size = Vector3(0.4, 0.4, 0.5)
	var nose_skin: StandardMaterial3D = StandardMaterial3D.new()
	nose_skin.albedo_color = Color(0.98, 0.76, 0.32)
	nose_mesh.material = nose_skin
	nose.mesh = nose_mesh
	twin.add_child(nose)
	nose.owner = root

	var eye: Camera3D = Camera3D.new()
	eye.name = "Eye"
	eye.position = Vector3(0.0, 1.2, 4.0)
	eye.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
	view.add_child(eye)
	eye.owner = root

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	view.add_child(sun)
	sun.owner = root

	return _save_scene(root, "%s/mirror_and_flip.tscn" % MIRROR_DIR)


## The hero subtree, built the same way wherever it is used so both scenes stay byte-stable. Every
## child here exists to be dragged along by the mirror: the ray reaches, the muzzle spawns, the dust
## blows - and the plate is the one that must not.
func _mirror_hero_node() -> Node2D:
	var hero: Node2D = Node2D.new()
	hero.name = "Hero"

	var picture: Sprite2D = Sprite2D.new()
	picture.name = "Picture"
	picture.texture = _make_texture()
	picture.scale = Vector2(1.2, 1.6)
	picture.modulate = Color(0.86, 0.88, 0.94)
	hero.add_child(picture)

	# A face, so which way the hero is looking is visible in a still picture and not only in motion.
	var face: Sprite2D = Sprite2D.new()
	face.name = "Face"
	face.texture = _make_texture()
	face.position = Vector2(14, -14)
	face.scale = Vector2(0.22, 0.22)
	face.modulate = Color(0.16, 0.20, 0.28)
	hero.add_child(face)

	var sword: RayCast2D = RayCast2D.new()
	sword.name = "Sword"
	sword.position = Vector2(20, 0)
	sword.target_position = Vector2(72, 0)
	sword.enabled = true
	hero.add_child(sword)

	# The ray reaches; this is what the reach LOOKS like, drawn along the same 72 pixels.
	var blade: Sprite2D = Sprite2D.new()
	blade.name = "Blade"
	blade.texture = _make_texture()
	blade.position = Vector2(36, 0)
	blade.scale = Vector2(1.5, 0.14)
	blade.modulate = Color(0.98, 0.76, 0.32)
	sword.add_child(blade)

	var muzzle: Marker2D = Marker2D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector2(46, -12)
	hero.add_child(muzzle)

	var muzzle_dot: Sprite2D = Sprite2D.new()
	muzzle_dot.name = "MuzzleDot"
	muzzle_dot.texture = _make_texture()
	muzzle_dot.scale = Vector2(0.18, 0.18)
	muzzle_dot.modulate = Color(0.94, 0.42, 0.38)
	muzzle.add_child(muzzle_dot)

	var dust: GPUParticles2D = GPUParticles2D.new()
	dust.name = "Dust"
	dust.position = Vector2(-26, 22)
	dust.amount = 16
	dust.lifetime = 0.7
	dust.local_coords = true
	dust.texture = _make_texture()
	hero.add_child(dust)

	var plate: Label = Label.new()
	plate.name = "Plate"
	plate.position = Vector2(-34, -66)
	plate.text = "Hero"
	hero.add_child(plate)

	return hero


## Marks every node under `node` as owned by `owner_node`, which is what makes them part of the packed
## scene rather than runtime children the pack drops on the floor.
func _own_tree(node: Node, owner_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner_node
		_own_tree(child, owner_node)


## A tileset built in-tool, so the tile row depends on no art file. One tile, drawn once and flipped
## for the far side of the corridor - which is the whole point the row makes.
func _mirror_tile_set() -> TileSet:
	var image: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.16, 0.20, 0.28, 1.0))
	for y: int in 32:
		for x: int in 32:
			if x < 4 or y < 4:
				image.set_pixel(x, y, Color(0.62, 0.70, 0.86, 1.0))
			elif x + y < 22:
				image.set_pixel(x, y, Color(0.42, 0.52, 0.72, 1.0))
	var atlas: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(image)
	atlas.texture_region_size = Vector2i(32, 32)
	atlas.create_tile(Vector2i(0, 0))
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	tile_set.add_source(atlas, 0)
	return tile_set

# ── 21. Pin modes: every way one thing can ride another (Y4 / Y5) ───────────
#
# One room per mode, side by side, all driven by anchors the sheet moves - so the DIFFERENCES are
# the demo. A rope hangs slack and only pulls when it goes taut; a bar holds its length every tick
# whatever happens; a soft pin lags behind on purpose; a spring overshoots and settles; an
# axis-locked pin follows a column and keeps its own height; a point pin rides a marker on somebody
# else's body rather than the body itself. Then the whole thing again in 3D, with the Pin 3D twin.

const PIN := "res://eventsheet_addons/pin/pin_behavior.gd"
const PIN_3D := "res://eventsheet_addons/pin_3d/pin_3d_behavior.gd"
const PIN_MODES_DIR := "res://demo/showcase/pin_modes"


func _build_pin_modes() -> bool:
	return _build_pin_modes_2d() and _build_pin_modes_3d()


func _build_pin_modes_2d() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "PinModesDemo"
	sheet.emit_live_values = false
	sheet.variables = {"t": {"type": "float", "default": 0.0, "exported": false}}

	var about: CommentRow = CommentRow.new()
	about.text = "[b]Pin Modes[/b] - six ways one object can ride another, running at once. The sheet moves only the ANCHORS (the post, the engine, the walker); everything else is a Pin behavior in a different mode. Watch the rope go slack and then snap taut, the bar hold its length through every turn, the camera target trail behind, the hat overshoot and settle, the shadow keep its own ground line, and the sword stay in the hand rather than beside the body."
	sheet.events.append(about)

	# One-time setup: each pin is started in the mode that names it, in one row.
	var setup: EventRow = EventRow.new()
	setup.trigger_provider_id = "Core"
	setup.trigger_id = "OnReady"
	setup.actions.append(_action("PinBehavior", "method:pin_rope",
		"{target}.pin_rope({anchor}, {max_length})",
		{"target": "$Lantern/Pin", "anchor": "$Post", "max_length": "90.0"}))
	setup.actions.append(_action("PinBehavior", "method:pin_bar",
		"{target}.pin_bar({anchor}, {length})",
		{"target": "$Cart/Pin", "anchor": "$Engine", "length": "70.0"}))
	setup.actions.append(_action("PinBehavior", "method:pin_soft",
		"{target}.pin_soft({anchor}, {speed})",
		{"target": "$CamTarget/Pin", "anchor": "$Player", "speed": "3.0"}))
	setup.actions.append(_action("PinBehavior", "method:pin_spring",
		"{target}.pin_spring({anchor}, {stiffness}, {damping})",
		{"target": "$Hat/Pin", "anchor": "$Player/Head", "stiffness": "140.0", "damping": "0.6"}))
	setup.actions.append(_action("PinBehavior", "method:pin_x_to",
		"{target}.pin_x_to({anchor})", {"target": "$Shadow/Pin", "anchor": "$Player"}))
	setup.actions.append(_action("PinBehavior", "method:pin_to_point",
		"{target}.pin_to_point({anchor}, {point_name})",
		{"target": "$Sword/Pin", "anchor": "$Player", "point_name": "\"Hand\""}))
	sheet.events.append(setup)

	# The anchors move; the pins answer. The lantern also falls, which is what gives the rope
	# something to be slack about - a constraint with nothing pulling on it never shows its shape.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnPhysicsProcess"
	tick.actions.append(_raw("\n".join(PackedStringArray([
		"t += delta",
		"$Post.position = Vector2(250.0 + sin(t * 1.2) * 190.0, 180.0)",
		"$Engine.position = Vector2(180.0 + fmod(t * 90.0, 760.0), 560.0)",
		"$Player.position = Vector2(600.0 + sin(t * 0.8) * 280.0, 420.0)",
		"$Player.rotation = sin(t * 0.8) * 0.25",
		"# Gravity for the lantern alone. The rope never pushes - it only stops the fall once the",
		"# line is straight, which is exactly the difference between a rope and a bar.",
		"$Lantern.position.y = minf($Lantern.position.y + 220.0 * delta, 620.0)"
	]))))
	sheet.events.append(tick)

	var readout: EventRow = EventRow.new()
	readout.trigger_provider_id = "Core"
	readout.trigger_id = "OnProcess"
	readout.actions.append(_raw("$Screen.text = \"PIN MODES   rope %.0f / 90 px   bar %.0f / 70 px   soft lag %.0f px\" % [$Lantern.global_position.distance_to($Post.global_position), $Cart.global_position.distance_to($Engine.global_position), $CamTarget.global_position.distance_to($Player.global_position)]"))
	sheet.events.append(readout)

	if not _compile(sheet, "%s/pin_modes.tres" % PIN_MODES_DIR, "%s/pin_modes.gd" % PIN_MODES_DIR):
		return false

	# ── The scene ──
	var root: Node2D = Node2D.new()
	root.name = "PinModes"
	root.set_script(load("%s/pin_modes.gd" % PIN_MODES_DIR))
	var texture: ImageTexture = _make_texture()

	_pin_sprite(root, root, "Post", Vector2(250.0, 180.0), texture,
		Color(0.62, 0.66, 0.78, 1.0), Vector2(0.55, 0.55))
	var lantern: Sprite2D = _pin_sprite(root, root, "Lantern", Vector2(250.0, 240.0), texture,
		Color(1.0, 0.82, 0.35, 1.0), Vector2(0.7, 0.7))
	_attach_behavior(lantern, "Pin", PIN, root)

	_pin_sprite(root, root, "Engine", Vector2(180.0, 560.0), texture,
		Color(0.5, 0.78, 0.95, 1.0), Vector2(0.9, 0.6))
	var cart: Sprite2D = _pin_sprite(root, root, "Cart", Vector2(110.0, 560.0), texture,
		Color(0.75, 0.85, 0.6, 1.0), Vector2(0.75, 0.55))
	_attach_behavior(cart, "Pin", PIN, root)

	var player: Sprite2D = _pin_sprite(root, root, "Player", Vector2(600.0, 420.0), texture,
		Color(0.95, 0.55, 0.45, 1.0), Vector2(1.0, 1.0))
	var hand: Marker2D = Marker2D.new()
	hand.name = "Hand"
	hand.position = Vector2(30.0, -4.0)
	player.add_child(hand)
	hand.owner = root
	var head: Marker2D = Marker2D.new()
	head.name = "Head"
	head.position = Vector2(0.0, -34.0)
	player.add_child(head)
	head.owner = root

	var sword: Sprite2D = _pin_sprite(root, root, "Sword", Vector2(630.0, 416.0), texture,
		Color(0.85, 0.88, 0.95, 1.0), Vector2(0.5, 0.18))
	_attach_behavior(sword, "Pin", PIN, root)
	var hat: Sprite2D = _pin_sprite(root, root, "Hat", Vector2(600.0, 386.0), texture,
		Color(0.7, 0.5, 0.9, 1.0), Vector2(0.6, 0.3))
	_attach_behavior(hat, "Pin", PIN, root)
	var cam_target: Sprite2D = _pin_sprite(root, root, "CamTarget", Vector2(600.0, 420.0), texture,
		Color(0.4, 0.95, 0.8, 0.7), Vector2(0.4, 0.4))
	_attach_behavior(cam_target, "Pin", PIN, root)
	var shadow: Sprite2D = _pin_sprite(root, root, "Shadow", Vector2(600.0, 470.0), texture,
		Color(0.1, 0.12, 0.16, 0.65), Vector2(0.9, 0.22))
	_attach_behavior(shadow, "Pin", PIN, root)

	_pin_label(root, root, "Screen", Vector2(36.0, 28.0), 26,
		"PIN MODES", Color(0.92, 0.94, 1.0, 1.0))
	_pin_label(root, root, "RopeCaption", Vector2(36.0, 300.0), 15,
		"rope: slack until taut, then it pulls", Color(1.0, 0.82, 0.35, 1.0))
	_pin_label(root, root, "BarCaption", Vector2(36.0, 596.0), 15,
		"bar: held at exactly its length", Color(0.75, 0.85, 0.6, 1.0))
	_pin_label(root, root, "SoftCaption", Vector2(760.0, 300.0), 15,
		"soft: a camera target that trails", Color(0.4, 0.95, 0.8, 1.0))
	_pin_label(root, root, "SpringCaption", Vector2(760.0, 322.0), 15,
		"spring: a hat that overshoots and settles", Color(0.7, 0.5, 0.9, 1.0))
	_pin_label(root, root, "AxisCaption", Vector2(760.0, 344.0), 15,
		"X only: a shadow that keeps its ground line", Color(0.72, 0.76, 0.86, 1.0))
	_pin_label(root, root, "PointCaption", Vector2(760.0, 366.0), 15,
		"point: a sword in the hand, not beside the body", Color(0.85, 0.88, 0.95, 1.0))

	return _save_scene(root, "%s/pin_modes.tscn" % PIN_MODES_DIR)


## One coloured sprite, parented and owned in the one step every node in this room needs.
func _pin_sprite(parent: Node, root: Node, node_name: String, at: Vector2, texture: Texture2D,
		tint: Color, size: Vector2) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = node_name
	sprite.position = at
	sprite.texture = texture
	sprite.modulate = tint
	sprite.scale = size
	parent.add_child(sprite)
	sprite.owner = root
	return sprite


func _pin_label(parent: Node, root: Node, node_name: String, at: Vector2, font_size: int,
		text: String, tint: Color) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.position = at
	label.text = text
	label.modulate = tint
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	label.owner = root
	return label


func _build_pin_modes_3d() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node3D"
	sheet.custom_class_name = "PinModes3DDemo"
	sheet.emit_live_values = false
	sheet.variables = {"t": {"type": "float", "default": 0.0, "exported": false}}

	var about: CommentRow = CommentRow.new()
	about.text = "[b]Pin Modes 3D[/b] - the same six relationships, on the Pin 3D pack. Nothing here is a child of anything it follows: every one of them is a pin, which is why each can let go and none of them is destroyed when its anchor is. The point pin rides a Marker3D on the walker, which is where a BoneAttachment3D would sit on a real rig."
	sheet.events.append(about)

	var setup: EventRow = EventRow.new()
	setup.trigger_provider_id = "Core"
	setup.trigger_id = "OnReady"
	setup.actions.append(_action("Pin3DBehavior", "method:pin_rope",
		"{target}.pin_rope({anchor}, {max_length})",
		{"target": "$Lantern/Pin", "anchor": "$Post", "max_length": "2.0"}))
	setup.actions.append(_action("Pin3DBehavior", "method:pin_bar",
		"{target}.pin_bar({anchor}, {length})",
		{"target": "$Cart/Pin", "anchor": "$Engine", "length": "2.0"}))
	setup.actions.append(_action("Pin3DBehavior", "method:pin_soft",
		"{target}.pin_soft({anchor}, {speed})",
		{"target": "$CamTarget/Pin", "anchor": "$Player", "speed": "3.0"}))
	setup.actions.append(_action("Pin3DBehavior", "method:pin_spring",
		"{target}.pin_spring({anchor}, {stiffness}, {damping})",
		{"target": "$Hat/Pin", "anchor": "$Player/Head", "stiffness": "140.0", "damping": "0.6"}))
	setup.actions.append(_action("Pin3DBehavior", "method:pin_x_to",
		"{target}.pin_x_to({anchor})", {"target": "$Shadow/Pin", "anchor": "$Player"}))
	setup.actions.append(_action("Pin3DBehavior", "method:pin_to_point",
		"{target}.pin_to_point({anchor}, {point_name})",
		{"target": "$Sword/Pin", "anchor": "$Player", "point_name": "\"Hand\""}))
	sheet.events.append(setup)

	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnPhysicsProcess"
	tick.actions.append(_raw("\n".join(PackedStringArray([
		"t += delta",
		"$Post.position = Vector3(-6.0 + sin(t * 1.2) * 3.0, 4.0, 0.0)",
		"$Engine.position = Vector3(fmod(t * 2.0, 14.0) - 7.0, 0.5, 6.0)",
		"$Player.position = Vector3(sin(t * 0.8) * 5.0, 1.0, 0.0)",
		"$Player.rotation.y = sin(t * 0.8) * 0.4",
		"# The same fall the 2D room gives its lantern, so the rope has something to hold.",
		"$Lantern.position.y = maxf($Lantern.position.y - 4.0 * delta, 0.3)"
	]))))
	sheet.events.append(tick)

	var readout: EventRow = EventRow.new()
	readout.trigger_provider_id = "Core"
	readout.trigger_id = "OnProcess"
	readout.actions.append(_raw("$HudLayer/Readout.text = \"PIN MODES 3D   rope %.2f / 2.00   bar %.2f / 2.00   soft lag %.2f\" % [$Lantern.global_position.distance_to($Post.global_position), $Cart.global_position.distance_to($Engine.global_position), $CamTarget.global_position.distance_to($Player.global_position)]"))
	sheet.events.append(readout)

	if not _compile(sheet, "%s/pin_modes_3d.tres" % PIN_MODES_DIR, "%s/pin_modes_3d.gd" % PIN_MODES_DIR):
		return false

	# ── The scene ──
	var root: Node3D = Node3D.new()
	root.name = "PinModes3D"
	root.set_script(load("%s/pin_modes_3d.gd" % PIN_MODES_DIR))

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.shadow_enabled = true
	root.add_child(sun)
	sun.owner = root
	var world: WorldEnvironment = WorldEnvironment.new()
	world.name = "World"
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.08, 0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.62)
	env.ambient_light_energy = 0.7
	world.environment = env
	root.add_child(world)
	world.owner = root
	var camera: Camera3D = Camera3D.new()
	camera.name = "Camera"
	camera.position = Vector3(0.0, 7.0, 16.0)
	camera.rotation_degrees = Vector3(-22.0, 0.0, 0.0)
	root.add_child(camera)
	camera.owner = root

	_add_block(root, root, "Post", Vector3(-6.0, 4.0, 0.0), Vector3(0.5, 0.5, 0.5),
		Color(0.62, 0.66, 0.78, 1.0))
	var lantern: MeshInstance3D = _add_block(root, root, "Lantern", Vector3(-6.0, 3.0, 0.0),
		Vector3(0.6, 0.6, 0.6), Color(1.0, 0.82, 0.35, 1.0))
	_attach_behavior(lantern, "Pin", PIN_3D, root)

	_add_block(root, root, "Engine", Vector3(-7.0, 0.5, 6.0), Vector3(1.2, 0.8, 0.8),
		Color(0.5, 0.78, 0.95, 1.0))
	var cart: MeshInstance3D = _add_block(root, root, "Cart", Vector3(-9.0, 0.5, 6.0),
		Vector3(1.0, 0.7, 0.8), Color(0.75, 0.85, 0.6, 1.0))
	_attach_behavior(cart, "Pin", PIN_3D, root)

	var player: MeshInstance3D = _add_block(root, root, "Player", Vector3(0.0, 1.0, 0.0),
		Vector3(0.8, 1.6, 0.8), Color(0.95, 0.55, 0.45, 1.0))
	var hand: Marker3D = Marker3D.new()
	hand.name = "Hand"
	hand.position = Vector3(0.7, 0.2, 0.0)
	player.add_child(hand)
	hand.owner = root
	var head: Marker3D = Marker3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 1.1, 0.0)
	player.add_child(head)
	head.owner = root

	var sword: MeshInstance3D = _add_block(root, root, "Sword", Vector3(0.7, 1.2, 0.0),
		Vector3(0.12, 1.1, 0.12), Color(0.85, 0.88, 0.95, 1.0))
	_attach_behavior(sword, "Pin", PIN_3D, root)
	var hat: MeshInstance3D = _add_block(root, root, "Hat", Vector3(0.0, 2.1, 0.0),
		Vector3(0.9, 0.25, 0.9), Color(0.7, 0.5, 0.9, 1.0))
	_attach_behavior(hat, "Pin", PIN_3D, root)
	var cam_target: MeshInstance3D = _add_block(root, root, "CamTarget", Vector3(0.0, 1.0, 0.0),
		Vector3(0.4, 0.4, 0.4), Color(0.4, 0.95, 0.8, 1.0))
	_attach_behavior(cam_target, "Pin", PIN_3D, root)
	var shadow: MeshInstance3D = _add_block(root, root, "Shadow", Vector3(0.0, 0.02, 0.0),
		Vector3(1.2, 0.04, 1.2), Color(0.1, 0.12, 0.16, 1.0))
	_attach_behavior(shadow, "Pin", PIN_3D, root)

	var hud: CanvasLayer = CanvasLayer.new()
	hud.name = "HudLayer"
	root.add_child(hud)
	hud.owner = root
	_pin_label(hud, root, "Readout", Vector2(32.0, 26.0), 22, "PIN MODES 3D",
		Color(0.92, 0.94, 1.0, 1.0))

	return _save_scene(root, "%s/pin_modes_3d.tscn" % PIN_MODES_DIR)


# -- 22. Skill Tree - a data asset laid out as a tree, and a player it changes -----------------
# The whole progression is ONE .tres: six skills in two branches, what each costs, what it needs
# first and what it grants. The screen draws it, the Upgrades pack answers every question about it,
# and StatForge carries the one grant that is a number - so unlocking Swift makes the player move
# faster with no formula written anywhere.

const UPGRADES_PACK := "res://eventsheet_addons/upgrades/upgrades_addon.gd"
const SKILL_TREE_RESOURCE := "res://eventsheet_addons/skill_tree_resource/skill_tree_resource.gd"
const STAT_FORGE := "res://eventsheet_addons/stat_forge/stat_forge_behavior.gd"
const HUD_KIT := "res://eventsheet_addons/hud_kit/hud_kit_behavior.gd"

## The showcase tree: a body branch whose middle node is a StatForge speed buff taken up to three
## times, and an agility branch whose middle node is a pure perk the player script asks about.
const SKILL_TREE_ROWS: Array[Dictionary] = [
	{"id": "toughness", "name": "Toughness", "cost": 1, "requires": "", "max_level": 1,
		"grants": "armour +2", "column": 0, "row": 0},
	{"id": "swift", "name": "Swift", "cost": 1, "requires": "toughness", "max_level": 3,
		"grants": "speed x1.1 per level", "column": 1, "row": 0},
	{"id": "sprint", "name": "Sprint", "cost": 2, "requires": "swift", "max_level": 1,
		"grants": "speed x1.25", "column": 2, "row": 0},
	{"id": "agility", "name": "Agility", "cost": 1, "requires": "", "max_level": 1,
		"grants": "jump +1", "column": 0, "row": 1},
	{"id": "double_jump", "name": "Double Jump", "cost": 2, "requires": "agility", "max_level": 1,
		"grants": "", "column": 1, "row": 1},
	{"id": "wall_jump", "name": "Wall Jump", "cost": 2, "requires": "double_jump", "max_level": 1,
		"grants": "jump x1.2", "column": 2, "row": 1},
]


func _build_skill_tree() -> bool:
	var tree: Resource = (load(SKILL_TREE_RESOURCE) as GDScript).new() as Resource
	tree.set("tree_name", "Adventurer")
	tree.set("starting_points", 4)
	tree.set("skills", SKILL_TREE_ROWS.duplicate(true))
	DirAccess.make_dir_recursive_absolute("res://demo/showcase/skill_tree")
	if ResourceSaver.save(tree, "res://demo/showcase/skill_tree/adventurer_tree.tres") != OK:
		return false

	# The player: its speed is never written down, it is asked for. One StatForge total, read every
	# frame, so a skill that multiplies speed changes how the body moves with nothing else touched.
	var player_sheet: EventSheetResource = EventSheetResource.new()
	player_sheet.host_class = "CharacterBody2D"
	player_sheet.custom_class_name = "SkillTreeRunner"
	player_sheet.emit_live_values = false
	var player_note: CommentRow = CommentRow.new()
	player_note.text = "[b]Runner[/b] - the body the tree changes. Its speed is StatForge's Stat Total for \"speed\", so unlocking Swift moves it faster without a formula anywhere; its second jump exists only while the Double Jump perk is unlocked, which is one Is Unlocked question."
	player_sheet.events.append(player_note)
	player_sheet.variables = {
		"base_speed": {"type": "float", "default": 120.0, "exported": true,
			"attributes": {"tooltip": "The speed before any skill touches it."}},
		"jumps_left": {"type": "int", "default": 1, "exported": false,
			"attributes": {"tooltip": "How many jumps are left before the ground is needed again."}},
		"stats": {"type": "Node", "default": null, "exported": false,
			"attributes": {"tooltip": "The StatForge stack the tree's grants are applied to."}},
		"upgrades": {"type": "Node", "default": null, "exported": false,
			"attributes": {"tooltip": "The Upgrades node that answers which skills are unlocked."}}
	}
	var player_ready: EventRow = EventRow.new()
	player_ready.trigger_provider_id = "Core"
	player_ready.trigger_id = "OnReady"
	player_ready.actions.append(_raw("\n".join(PackedStringArray([
		"stats = $Stats",
		"upgrades = get_parent().get_node(\"Upgrades\")",
		"stats.set_stat_base(\"speed\", base_speed)"
	]))))
	player_sheet.events.append(player_ready)
	var player_tick: EventRow = EventRow.new()
	player_tick.trigger_provider_id = "Core"
	player_tick.trigger_id = "OnPhysicsProcess"
	player_tick.actions.append(_raw("\n".join(PackedStringArray([
		"var steer: float = Input.get_axis(&\"ui_left\", &\"ui_right\")",
		"velocity.x = steer * stats.stat_total(\"speed\")",
		"if is_on_floor():",
		"\tjumps_left = 2 if upgrades.is_skill_unlocked(\"double_jump\") else 1",
		"else:",
		"\tvelocity.y += 900.0 * delta",
		"if Input.is_action_just_pressed(&\"ui_accept\") and jumps_left > 0:",
		"\tjumps_left -= 1",
		"\tvelocity.y = -340.0",
		"move_and_slide()"
	]))))
	player_sheet.events.append(player_tick)
	if not _compile(player_sheet, "res://demo/showcase/skill_tree/runner.tres",
			"res://demo/showcase/skill_tree/runner.gd"):
		return false

	# The screen: every node's state is read from the tree's own three questions, so the picture and
	# the rules cannot disagree.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Control"
	sheet.custom_class_name = "SkillTreeShowcase"
	sheet.emit_live_values = false
	var about: CommentRow = CommentRow.new()
	about.text = "[b]Skill Tree[/b] - a data asset, laid out. Six skills in two branches live in adventurer_tree.tres with their costs, their prerequisites and what they grant. The screen spawns one button per skill and draws a line to each one it requires; grey means a prerequisite is missing, gold means it can be taken now, green means it is taken. Clicking one is a single Unlock row, which spends a point, records the level and hands the grant to StatForge - so Swift makes the runner faster with no formula written anywhere, and Double Jump grants nothing at all because the runner asks about it directly. Arrow keys move the runner, Space jumps."
	sheet.events.append(about)
	sheet.variables = {
		"tree": {"type": "Resource", "default": null, "exported": true,
			"attributes": {"tooltip": "The Skill Tree data asset this screen draws."}},
		"upgrades": {"type": "Node", "default": null, "exported": false,
			"attributes": {"tooltip": "The Upgrades node that answers every question about the tree."}},
		"buttons": {"type": "Dictionary", "default": {}, "exported": false,
			"attributes": {"tooltip": "Skill id to the button that stands for it."}},
		"locked_tint": {"type": "Color", "default": Color(0.45, 0.45, 0.5), "exported": true,
			"attributes": {"tooltip": "A skill whose prerequisites are not met yet."}},
		"affordable_tint": {"type": "Color", "default": Color(1.0, 0.86, 0.4), "exported": true,
			"attributes": {"tooltip": "A skill that can be unlocked right now."}},
		"unlocked_tint": {"type": "Color", "default": Color(0.55, 0.9, 0.6), "exported": true,
			"attributes": {"tooltip": "A skill already taken."}}
	}
	var ready_row: EventRow = EventRow.new()
	ready_row.trigger_provider_id = "Core"
	ready_row.trigger_id = "OnReady"
	ready_row.actions.append(_raw("\n".join(PackedStringArray([
		"upgrades = $Upgrades",
		"upgrades.load_skill_tree(tree)",
		"upgrades.apply_grants_to($Runner/Stats)",
		"$HudKit.on_button_pressed.connect(unlock_pressed)",
		"lay_out()"
	]))))
	sheet.events.append(ready_row)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	tick.actions.append(_raw("\n".join(PackedStringArray([
		"refresh_states()",
		"$HudKit.set_text(\"PointsValue\", \"Skill points left: %d\" % upgrades.skill_points_left())",
		"$HudKit.set_text(\"SpeedValue\", \"Speed: %0.0f\" % $Runner/Stats.stat_total(\"speed\"))"
	]))))
	sheet.events.append(tick)
	sheet.functions.append(_showcase_function("lay_out", "\n".join(PackedStringArray([
		"for index: int in range(upgrades.skill_count()):",
		"\tvar id: String = upgrades.skill_id_at(index)",
		"\tvar button: Button = Button.new()",
		"\tbutton.name = id",
		"\tbutton.text = upgrades.skill_name_of(id)",
		"\tbutton.size = Vector2(150.0, 40.0)",
		"\tbutton.position = Vector2(40.0 + float(upgrades.skill_column_of(id)) * 190.0, 60.0 + float(upgrades.skill_row_of(id)) * 74.0)",
		"\tbutton.mouse_entered.connect(show_grants.bind(id))",
		"\t$TreeNodes.add_child(button)",
		"\tbuttons[id] = button",
		"$HudKit.connect_buttons()",
		"refresh_states()",
		"queue_redraw()"
	]))))
	sheet.functions.append(_showcase_function("refresh_states", "\n".join(PackedStringArray([
		"for id: String in buttons:",
		"\tvar button: Button = buttons[id]",
		"\tvar takeable: bool = upgrades.can_unlock_skill(id)",
		"\tif upgrades.is_skill_unlocked(id):",
		"\t\tbutton.modulate = unlocked_tint",
		"\telif takeable:",
		"\t\tbutton.modulate = affordable_tint",
		"\telse:",
		"\t\tbutton.modulate = locked_tint",
		"\tbutton.disabled = not takeable"
	]))))
	sheet.functions.append(_showcase_function("unlock_pressed", "\n".join(PackedStringArray([
		"upgrades.unlock_skill($HudKit.last_button_name_value())",
		"refresh_states()"
	]))))
	sheet.functions.append(_showcase_function("show_grants", "\n".join(PackedStringArray([
		"var grants: String = upgrades.skill_grants_text(id)",
		"$HudKit.set_text(\"GrantsValue\", grants if not grants.is_empty() else \"a perk the runner asks about\")"
	])), [["id", "String"]]))
	sheet.functions.append(_showcase_function("_draw", "\n".join(PackedStringArray([
		"for id: String in buttons:",
		"\tvar button: Button = buttons[id]",
		"\tfor part: String in upgrades.skill_requires_text(id).split(\",\", false):",
		"\t\tvar earlier: Variant = buttons.get(part.strip_edges())",
		"\t\tif not (earlier is Button):",
		"\t\t\tcontinue",
		"\t\tvar earlier_box: Rect2 = (earlier as Button).get_global_rect()",
		"\t\tvar box: Rect2 = button.get_global_rect()",
		"\t\t# Edge to edge rather than centre to centre, so a line never crosses a node's own name.",
		"\t\tvar from: Vector2 = Vector2(earlier_box.end.x, earlier_box.get_center().y) - global_position",
		"\t\tvar to: Vector2 = Vector2(box.position.x, box.get_center().y) - global_position",
		"\t\tdraw_line(from, to, Color(0.5, 0.62, 0.78), 2.0)"
	]))))
	if not _compile(sheet, "res://demo/showcase/skill_tree/skill_tree.tres",
			"res://demo/showcase/skill_tree/skill_tree.gd"):
		return false

	var root: Control = Control.new()
	root.name = "SkillTree"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.set_script(load("res://demo/showcase/skill_tree/skill_tree.gd"))
	root.set("tree", load("res://demo/showcase/skill_tree/adventurer_tree.tres"))
	_attach_behavior(root, "Upgrades", UPGRADES_PACK, root)
	_attach_behavior(root, "HudKit", HUD_KIT, root)
	var nodes_parent: Control = Control.new()
	nodes_parent.name = "TreeNodes"
	nodes_parent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(nodes_parent)
	nodes_parent.owner = root
	for label_pair: Array in [["PointsValue", 18.0], ["GrantsValue", 218.0], ["SpeedValue", 248.0]]:
		var label: Label = Label.new()
		label.name = str(label_pair[0])
		label.position = Vector2(40.0, float(label_pair[1]))
		label.text = str(label_pair[0])
		root.add_child(label)
		label.owner = root
	var runner: CharacterBody2D = CharacterBody2D.new()
	runner.name = "Runner"
	runner.position = Vector2(120.0, 420.0)
	runner.set_script(load("res://demo/showcase/skill_tree/runner.gd"))
	var body: CollisionShape2D = CollisionShape2D.new()
	body.name = "Body"
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(28.0, 44.0)
	body.shape = shape
	runner.add_child(body)
	var runner_sprite: Sprite2D = Sprite2D.new()
	runner_sprite.name = "Look"
	runner_sprite.texture = _make_texture()
	runner.add_child(runner_sprite)
	root.add_child(runner)
	runner.owner = root
	body.owner = root
	runner_sprite.owner = root
	# After the runner is in the tree: an owner must be an ancestor, so the stack cannot be
	# attached before its host has a parent.
	_attach_behavior(runner, "Stats", STAT_FORGE, root)
	var ground: StaticBody2D = StaticBody2D.new()
	ground.name = "Ground"
	ground.position = Vector2(400.0, 470.0)
	var ground_shape: CollisionShape2D = CollisionShape2D.new()
	ground_shape.name = "Floor"
	var ground_rect: RectangleShape2D = RectangleShape2D.new()
	ground_rect.size = Vector2(760.0, 24.0)
	ground_shape.shape = ground_rect
	ground.add_child(ground_shape)
	root.add_child(ground)
	ground.owner = root
	ground_shape.owner = root
	return _save_scene(root, "res://demo/showcase/skill_tree/skill_tree.tscn")


## One plain helper function on a showcase sheet: a name, a body and, optionally, its parameters.
func _showcase_function(function_name: String, body: String, params: Array = []) -> EventFunction:
	var built: EventFunction = EventFunction.new()
	built.function_name = function_name
	for pair: Array in params:
		var parameter: ACEParam = ACEParam.new()
		parameter.id = str(pair[0])
		parameter.type_name = str(pair[1])
		built.params.append(parameter)
	var body_row: RawCodeRow = RawCodeRow.new()
	body_row.code = body
	built.events.append(body_row)
	return built


# ── 21. Skate Park (2D) ─────────────────────────────────────────────────────
#
# Y22 / Y9 / Y24. The Skateboard pack playable: a slope that hands you speed, a rail across the
# middle, a quarterpipe at the end, and a HUD that shows the chain climbing until you land it.
# Every row is the pack's own vocabulary - there is no skating math in the sheet at all.

const SKATE_PARK_DIR := "res://demo/showcase/skate_park"
const SKATE_PARK_3D_DIR := "res://demo/showcase/skate_park_3d"
const SKATEBOARD := "res://eventsheet_addons/skateboard/skateboard_behavior.gd"
const SKATEBOARD_3D := "res://eventsheet_addons/skateboard_3d/skateboard_3d_behavior.gd"
const CHECKPOINT := "res://eventsheet_addons/checkpoint/checkpoint_behavior.gd"


func _build_skate_park() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "SkatePark"
	sheet.emit_live_values = false

	var about: CommentRow = CommentRow.new()
	about.text = "[b]Skate Park[/b] - the Skateboard pack, playable. The slope hands you speed (Roll With The Slope projects gravity along the floor), the rail across the middle is an ordinary Path2D you snap to, and the quarterpipe at the end gives back what the drop gave you. Left/Right steer the balance, Space pushes, Up ollies, and holding Right in the air spins. Nothing here does skating math - every row is a Skateboard row."
	sheet.events.append(about)

	sheet.variables = {
		"score": {"type": "int", "default": 0, "exported": true,
			"attributes": {"tooltip": "Everything banked so far this run."}}
	}

	var wire: EventRow = EventRow.new()
	wire.trigger_provider_id = "Core"
	wire.trigger_id = "OnReady"
	wire.actions.append(_raw("\n".join(PackedStringArray([
		"$Skater/Skateboard.landed_clean.connect(_on_landed_clean)",
		"$Skater/Skateboard.bailed.connect(_on_bailed)"
	]))))
	sheet.events.append(wire)

	var rolling: EventRow = EventRow.new()
	rolling.trigger_provider_id = "Core"
	rolling.trigger_id = "OnPhysicsProcess"
	rolling.conditions.append(_condition("Core", "IsOnFloor", "{target}.is_on_floor()",
		{"target": "$Skater"}))
	rolling.actions.append(_skate_action("roll_with_slope", "{target}.roll_with_slope()", {}))
	sheet.events.append(rolling)

	var pushing: EventRow = EventRow.new()
	pushing.trigger_provider_id = "Core"
	pushing.trigger_id = "OnPhysicsProcess"
	pushing.conditions.append(_condition("Core", "IsActionJustPressed",
		"Input.is_action_just_pressed(&{action})", {"action": "\"ui_accept\""}))
	pushing.actions.append(_skate_action("push", "{target}.push({amount})", {"amount": "40.0"}))
	sheet.events.append(pushing)

	var ollieing: EventRow = EventRow.new()
	ollieing.trigger_provider_id = "Core"
	ollieing.trigger_id = "OnPhysicsProcess"
	ollieing.conditions.append(_condition("Core", "IsActionJustPressed",
		"Input.is_action_just_pressed(&{action})", {"action": "\"ui_up\""}))
	ollieing.actions.append(_skate_action("ollie", "{target}.ollie({strength})",
		{"strength": "420.0"}))
	sheet.events.append(ollieing)

	var spinning: EventRow = EventRow.new()
	spinning.trigger_provider_id = "Core"
	spinning.trigger_id = "OnPhysicsProcess"
	spinning.conditions.append(_skate_condition("is_airborne", "{target}.is_airborne()", {}))
	spinning.conditions.append(_condition("Core", "IsActionPressed",
		"Input.is_action_pressed(&{action})", {"action": "\"ui_right\""}))
	spinning.actions.append(_skate_action("spin_trick", "{target}.spin_trick({turns})",
		{"turns": "1.0"}))
	sheet.events.append(spinning)

	var catching: EventRow = EventRow.new()
	catching.trigger_provider_id = "Core"
	catching.trigger_id = "OnPhysicsProcess"
	catching.conditions.append(_skate_condition("is_grinding", "not {target}.is_grinding()", {}))
	catching.conditions.append(_skate_condition("is_near_rail",
		"{target}.is_near_rail({rail}, {distance})", {"rail": "$Rail", "distance": "16.0"}))
	catching.actions.append(_skate_action("start_grinding", "{target}.start_grinding({rail})",
		{"rail": "$Rail"}))
	sheet.events.append(catching)

	var riding: EventRow = EventRow.new()
	riding.trigger_provider_id = "Core"
	riding.trigger_id = "OnPhysicsProcess"
	riding.conditions.append(_skate_condition("is_grinding", "{target}.is_grinding()", {}))
	riding.actions.append(_skate_action("grind_along_rail",
		"{target}.grind_along_rail({speed}, {keep_momentum})",
		{"speed": "320.0", "keep_momentum": "false"}))
	riding.actions.append(_skate_action("steer_balance", "{target}.steer_balance({amount})",
		{"amount": "Input.get_axis(\"ui_left\", \"ui_right\")"}))
	sheet.events.append(riding)

	var leaving: EventRow = EventRow.new()
	leaving.trigger_provider_id = "Core"
	leaving.trigger_id = "OnPhysicsProcess"
	leaving.conditions.append(_skate_condition("has_reached_the_end",
		"{target}.has_reached_the_end()", {}))
	leaving.actions.append(_skate_action("add_to_chain",
		"{target}.add_to_chain({trick}, {points})", {"trick": "\"grind\"", "points": "250.0"}))
	leaving.actions.append(_skate_action("hop_off", "{target}.hop_off({hop})", {"hop": "260.0"}))
	sheet.events.append(leaving)

	var hud: EventRow = EventRow.new()
	hud.trigger_provider_id = "Core"
	hud.trigger_id = "OnPhysicsProcess"
	hud.actions.append(_raw("$Hud.text = \"Score %d   chain %d x%d   Space push / Up ollie / Right spin\" % [score, int($Skater/Skateboard.chain_score()), $Skater/Skateboard.multiplier()]"))
	# The balance meter has a MIDDLE, which a bar cannot show, so the HUD pack draws it as a needle.
	hud.actions.append(_action("HudKitBehavior", "method:set_needle",
		"{target}.set_needle({needle_name}, {value}, {warn_at})",
		{"target": "$Hud/HudKit", "needle_name": "\"BalanceMeter\"",
		"value": "$Skater/Skateboard.balance()", "warn_at": "0.6"}))
	sheet.events.append(hud)

	var landed: EventFunction = EventFunction.new()
	landed.function_name = "_on_landed_clean"
	landed.enabled = true
	landed.description = "A clean landing banks the chain: the multiplier goes back to one and the run's total is finally safe."
	landed.events = [_raw("\n".join(PackedStringArray([
		"if $Skater/Skateboard.spin_turns() >= 0.5:",
		"\t$Skater/Skateboard.add_to_chain(\"spin\", 150.0)",
		"$Skater/Skateboard.bank_chain()",
		"score = int($Skater/Skateboard.banked_score())"
	])))]
	sheet.functions.append(landed)

	var bailed: EventFunction = EventFunction.new()
	bailed.function_name = "_on_bailed"
	bailed.enabled = true
	bailed.description = "A bail costs the chain and nothing else - the banked total is untouched, and the Checkpoint pack puts the board back where the run started. This pack owns the wipeout moment and nothing after it, which is why the recovery is somebody else's row."
	bailed.events = [_raw("\n".join(PackedStringArray([
		"$Skater/Checkpoint.respawn()",
		"$Skater.velocity = Vector2.ZERO",
		"$Skater.rotation = 0.0"
	])))]
	sheet.functions.append(bailed)

	if not _compile(sheet, "%s/skate_park.tres" % SKATE_PARK_DIR, "%s/skate_park.gd" % SKATE_PARK_DIR):
		return false
	var emitted: String = FileAccess.get_file_as_string("%s/skate_park.gd" % SKATE_PARK_DIR)
	emitted = emitted.replace("\n\nfunc ", "\n\n\nfunc ")
	emitted = emitted.replace("\n\n## @ace_hidden\nfunc ", "\n\n\n## @ace_hidden\nfunc ")
	var out: FileAccess = FileAccess.open("%s/skate_park.gd" % SKATE_PARK_DIR, FileAccess.WRITE)
	out.store_string(emitted)
	out.close()

	var root: Node2D = Node2D.new()
	root.name = "SkatePark"
	root.set_script(load("%s/skate_park.gd" % SKATE_PARK_DIR))

	# The park, as three collision polygons: the slope that starts the run, the flat with the rail
	# over it, and the quarterpipe that gives the speed back at the far end.
	_add_skate_solid(root, "Slope", PackedVector2Array([
		Vector2(0.0, 300.0), Vector2(360.0, 580.0), Vector2(0.0, 580.0)]),
		Color(0.30, 0.36, 0.48, 1.0))
	_add_skate_solid(root, "Ground", PackedVector2Array([
		Vector2(0.0, 580.0), Vector2(1152.0, 580.0), Vector2(1152.0, 648.0), Vector2(0.0, 648.0)]),
		Color(0.22, 0.26, 0.34, 1.0))
	var pipe: PackedVector2Array = _skate_arc(Vector2(940.0, 400.0), 180.0, 90.0, 0.0, 12)
	pipe.append(Vector2(1152.0, 648.0))
	pipe.append(Vector2(940.0, 648.0))
	_add_skate_solid(root, "Quarterpipe", pipe, Color(0.30, 0.36, 0.48, 1.0))

	var rail: Path2D = Path2D.new()
	rail.name = "Rail"
	var curve: Curve2D = Curve2D.new()
	curve.add_point(Vector2(500.0, 552.0))
	curve.add_point(Vector2(800.0, 552.0))
	rail.curve = curve
	root.add_child(rail)
	rail.owner = root

	var rail_mark: Line2D = Line2D.new()
	rail_mark.name = "RailMark"
	rail_mark.width = 4.0
	rail_mark.default_color = Color(0.66, 0.80, 1.0, 1.0)
	rail_mark.points = PackedVector2Array([Vector2(500.0, 552.0), Vector2(800.0, 552.0)])
	root.add_child(rail_mark)
	rail_mark.owner = root

	var skater: CharacterBody2D = CharacterBody2D.new()
	skater.name = "Skater"
	skater.position = Vector2(110.0, 300.0)
	root.add_child(skater)
	skater.owner = root
	var collider: CollisionShape2D = CollisionShape2D.new()
	collider.name = "Collider"
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(24.0, 28.0)
	collider.shape = shape
	skater.add_child(collider)
	collider.owner = root
	var board: ColorRect = ColorRect.new()
	board.name = "Board"
	board.color = Color(1.0, 0.78, 0.32, 1.0)
	board.position = Vector2(-12.0, -14.0)
	board.size = Vector2(24.0, 28.0)
	skater.add_child(board)
	board.owner = root
	_attach_behavior(skater, "Skateboard", SKATEBOARD, root,
		{"push_speed": 40.0, "max_speed": 600.0, "ollie_speed": 420.0, "slope_grip": 1.0,
		"friction": 40.0, "balance_drift": 0.5})
	# The wipeout's recovery is the Checkpoint pack's job, not the board's: the board fires
	# On Bailed and stops, and something else decides what a bail costs.
	_attach_behavior(skater, "Checkpoint", CHECKPOINT, root, {"capture_on_ready": true})

	var label: Label = Label.new()
	label.name = "Hud"
	label.position = Vector2(28.0, 22.0)
	label.add_theme_font_size_override("font_size", 24)
	label.text = "Score 0   chain 0 x1   Space push / Up ollie / Right spin"
	root.add_child(label)
	label.owner = root
	_attach_behavior(label, "HudKit", HUD_KIT, root, {"auto_connect_buttons": false})
	var meter: Control = Control.new()
	meter.name = "BalanceMeter"
	meter.position = Vector2(0.0, 40.0)
	meter.size = Vector2(220.0, 14.0)
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_child(meter)
	meter.owner = root
	var meter_back: ColorRect = ColorRect.new()
	meter_back.name = "Backing"
	meter_back.color = Color(0.0, 0.0, 0.0, 0.35)
	meter_back.size = Vector2(220.0, 14.0)
	meter_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.add_child(meter_back)
	meter_back.owner = root

	return _save_scene(root, "%s/skate_park.tscn" % SKATE_PARK_DIR)


## One Skateboard verb, addressed at the board on the Skater. The provider id is the pack's class
## name, which is what makes the row read as the pack's own sentence rather than as a call.
func _skate_action(verb: String, template: String, params: Dictionary) -> ACEAction:
	var full: Dictionary = params.duplicate()
	full["target"] = "$Skater/Skateboard"
	return _action("SkateboardMovement", "method:%s" % verb, template, full)


func _skate_condition(verb: String, template: String, params: Dictionary) -> ACECondition:
	var full: Dictionary = params.duplicate()
	full["target"] = "$Skater/Skateboard"
	return _condition("SkateboardMovement", "method:%s" % verb, template, full)


func _skate_action_3d(verb: String, template: String, params: Dictionary) -> ACEAction:
	var full: Dictionary = params.duplicate()
	full["target"] = "$Skater/Skateboard"
	return _action("Skateboard3DMovement", "method:%s" % verb, template, full)


func _skate_condition_3d(verb: String, template: String, params: Dictionary) -> ACECondition:
	var full: Dictionary = params.duplicate()
	full["target"] = "$Skater/Skateboard"
	return _condition("Skateboard3DMovement", "method:%s" % verb, template, full)


## One static collision polygon with a matching filled shape, so the park is both solid and visible.
func _add_skate_solid(root: Node2D, node_name: String, points: PackedVector2Array,
		tint: Color) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = node_name
	root.add_child(body)
	body.owner = root
	var collider: CollisionPolygon2D = CollisionPolygon2D.new()
	collider.name = "Collider"
	collider.polygon = points
	body.add_child(collider)
	collider.owner = root
	var fill: Polygon2D = Polygon2D.new()
	fill.name = "Fill"
	fill.polygon = points
	fill.color = tint
	body.add_child(fill)
	fill.owner = root
	return body


## An arc of a circle as a point run, used for the quarterpipe's transition. Degrees, clockwise on
## screen because Y grows downward.
func _skate_arc(centre: Vector2, radius: float, from_degrees: float, to_degrees: float,
		steps: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for step: int in range(steps + 1):
		var t: float = float(step) / float(steps)
		var angle: float = deg_to_rad(lerpf(from_degrees, to_degrees, t))
		points.append(Vector2(centre.x + cos(angle) * radius, centre.y + sin(angle) * radius))
	return points


func _build_skate_park_3d() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node3D"
	sheet.custom_class_name = "SkatePark3D"
	sheet.emit_live_values = false

	var about: CommentRow = CommentRow.new()
	about.text = "[b]Skate Park 3D[/b] - the Skateboard 3D pack, playable. Roll With The Slope projects gravity onto the surface normal so the bank at the end carves, Align The Board To The Surface keeps the board flat on it, and leaving the bank fires On Launched Off The Lip. The rail is an ordinary Path3D. Space pushes, Up ollies, Right spins in the air."
	sheet.events.append(about)

	sheet.variables = {
		"score": {"type": "int", "default": 0, "exported": true,
			"attributes": {"tooltip": "Everything banked so far this run."}}
	}

	var wire: EventRow = EventRow.new()
	wire.trigger_provider_id = "Core"
	wire.trigger_id = "OnReady"
	wire.actions.append(_raw("\n".join(PackedStringArray([
		"$Skater/Skateboard.landed_clean.connect(_on_landed_clean)",
		"$Skater/Skateboard.launched_off_the_lip.connect(_on_launched)",
		"$Skater/Skateboard.bailed.connect(_on_bailed)"
	]))))
	sheet.events.append(wire)

	var rolling: EventRow = EventRow.new()
	rolling.trigger_provider_id = "Core"
	rolling.trigger_id = "OnPhysicsProcess"
	rolling.conditions.append(_condition("Core", "IsOnFloor3D", "{target}.is_on_floor()",
		{"target": "$Skater"}))
	rolling.actions.append(_skate_action_3d("roll_with_slope", "{target}.roll_with_slope()", {}))
	sheet.events.append(rolling)

	var aligning: EventRow = EventRow.new()
	aligning.trigger_provider_id = "Core"
	aligning.trigger_id = "OnPhysicsProcess"
	aligning.actions.append(_skate_action_3d("align_board_to_surface",
		"{target}.align_board_to_surface()", {}))
	sheet.events.append(aligning)

	var pushing: EventRow = EventRow.new()
	pushing.trigger_provider_id = "Core"
	pushing.trigger_id = "OnPhysicsProcess"
	pushing.conditions.append(_condition("Core", "IsActionJustPressed",
		"Input.is_action_just_pressed(&{action})", {"action": "\"ui_accept\""}))
	pushing.actions.append(_skate_action_3d("push", "{target}.push({amount})", {"amount": "2.0"}))
	sheet.events.append(pushing)

	var ollieing: EventRow = EventRow.new()
	ollieing.trigger_provider_id = "Core"
	ollieing.trigger_id = "OnPhysicsProcess"
	ollieing.conditions.append(_condition("Core", "IsActionJustPressed",
		"Input.is_action_just_pressed(&{action})", {"action": "\"ui_up\""}))
	ollieing.actions.append(_skate_action_3d("ollie", "{target}.ollie({strength})",
		{"strength": "6.0"}))
	sheet.events.append(ollieing)

	var spinning: EventRow = EventRow.new()
	spinning.trigger_provider_id = "Core"
	spinning.trigger_id = "OnPhysicsProcess"
	spinning.conditions.append(_skate_condition_3d("is_airborne", "{target}.is_airborne()", {}))
	spinning.conditions.append(_condition("Core", "IsActionPressed",
		"Input.is_action_pressed(&{action})", {"action": "\"ui_right\""}))
	spinning.actions.append(_skate_action_3d("spin_trick", "{target}.spin_trick({turns})",
		{"turns": "1.0"}))
	sheet.events.append(spinning)

	var catching: EventRow = EventRow.new()
	catching.trigger_provider_id = "Core"
	catching.trigger_id = "OnPhysicsProcess"
	catching.conditions.append(_skate_condition_3d("is_grinding", "not {target}.is_grinding()", {}))
	catching.conditions.append(_skate_condition_3d("is_near_rail",
		"{target}.is_near_rail({rail}, {distance})", {"rail": "$Rail", "distance": "0.8"}))
	catching.actions.append(_skate_action_3d("start_grinding", "{target}.start_grinding({rail})",
		{"rail": "$Rail"}))
	sheet.events.append(catching)

	var riding: EventRow = EventRow.new()
	riding.trigger_provider_id = "Core"
	riding.trigger_id = "OnPhysicsProcess"
	riding.conditions.append(_skate_condition_3d("is_grinding", "{target}.is_grinding()", {}))
	riding.actions.append(_skate_action_3d("grind_along_rail",
		"{target}.grind_along_rail({speed}, {keep_momentum})",
		{"speed": "10.0", "keep_momentum": "false"}))
	sheet.events.append(riding)

	var leaving: EventRow = EventRow.new()
	leaving.trigger_provider_id = "Core"
	leaving.trigger_id = "OnPhysicsProcess"
	leaving.conditions.append(_skate_condition_3d("has_reached_the_end",
		"{target}.has_reached_the_end()", {}))
	leaving.actions.append(_skate_action_3d("add_to_chain",
		"{target}.add_to_chain({trick}, {points})", {"trick": "\"grind\"", "points": "250.0"}))
	leaving.actions.append(_skate_action_3d("hop_off", "{target}.hop_off({hop})", {"hop": "4.5"}))
	sheet.events.append(leaving)

	var hud: EventRow = EventRow.new()
	hud.trigger_provider_id = "Core"
	hud.trigger_id = "OnPhysicsProcess"
	hud.actions.append(_raw("$Overlay/Hud.text = \"Score %d   chain %d x%d   Space push / Up ollie / Right spin\" % [score, int($Skater/Skateboard.chain_score()), $Skater/Skateboard.multiplier()]"))
	sheet.events.append(hud)

	var landed: EventFunction = EventFunction.new()
	landed.function_name = "_on_landed_clean"
	landed.enabled = true
	landed.description = "A clean landing banks the chain: the multiplier goes back to one and the run's total is finally safe."
	landed.events = [_raw("\n".join(PackedStringArray([
		"if $Skater/Skateboard.spin_turns() >= 0.5:",
		"\t$Skater/Skateboard.add_to_chain(\"spin\", 150.0)",
		"$Skater/Skateboard.bank_chain()",
		"score = int($Skater/Skateboard.banked_score())"
	])))]
	sheet.functions.append(landed)

	var launched: EventFunction = EventFunction.new()
	launched.function_name = "_on_launched"
	launched.enabled = true
	launched.description = "Leaving the bank steeper than the lip angle is its own moment, and this is where a camera pull or a slow-motion dip belongs."
	launched.events = [_raw("$Skater/Skateboard.add_to_chain(\"air\", 100.0)")]
	sheet.functions.append(launched)

	var bailed: EventFunction = EventFunction.new()
	bailed.function_name = "_on_bailed"
	bailed.enabled = true
	bailed.description = "A bail costs the chain and nothing else - the banked total is untouched, and the board is put back at the top of the run."
	bailed.events = [_raw("\n".join(PackedStringArray([
		"$Skater.global_position = Vector3(-9.0, 1.0, 0.0)",
		"$Skater.velocity = Vector3.ZERO"
	])))]
	sheet.functions.append(bailed)

	if not _compile(sheet, "%s/skate_park_3d.tres" % SKATE_PARK_3D_DIR,
			"%s/skate_park_3d.gd" % SKATE_PARK_3D_DIR):
		return false
	var emitted: String = FileAccess.get_file_as_string("%s/skate_park_3d.gd" % SKATE_PARK_3D_DIR)
	emitted = emitted.replace("\n\nfunc ", "\n\n\nfunc ")
	emitted = emitted.replace("\n\n## @ace_hidden\nfunc ", "\n\n\n## @ace_hidden\nfunc ")
	var out: FileAccess = FileAccess.open("%s/skate_park_3d.gd" % SKATE_PARK_3D_DIR, FileAccess.WRITE)
	out.store_string(emitted)
	out.close()

	var root: Node3D = Node3D.new()
	root.name = "SkatePark3D"
	root.set_script(load("%s/skate_park_3d.gd" % SKATE_PARK_3D_DIR))

	# The run, left to right: a tilted slab that hands you speed, a flat with a rail over it, and a
	# bank steep enough at the end that leaving it counts as a lip launch rather than a fall.
	var slope: StaticBody3D = _add_block_shape(root, root, "Slope", Vector3(-9.0, -0.6, 0.0),
		Vector3(10.0, 0.5, 6.0), Color(0.30, 0.36, 0.48, 1.0))
	slope.rotation.z = deg_to_rad(-14.0)
	_add_block_shape(root, root, "Ground", Vector3(4.0, -1.85, 0.0), Vector3(18.0, 0.5, 6.0),
		Color(0.22, 0.26, 0.34, 1.0))
	var bank: StaticBody3D = _add_block_shape(root, root, "Bank", Vector3(13.6, -0.6, 0.0),
		Vector3(6.0, 0.5, 6.0), Color(0.30, 0.36, 0.48, 1.0))
	bank.rotation.z = deg_to_rad(-58.0)

	var rail: Path3D = Path3D.new()
	rail.name = "Rail"
	var curve: Curve3D = Curve3D.new()
	curve.add_point(Vector3(0.0, -1.0, 0.0))
	curve.add_point(Vector3(7.0, -1.0, 0.0))
	rail.curve = curve
	root.add_child(rail)
	rail.owner = root
	_add_block(rail, root, "RailMark", Vector3(3.5, -1.0, 0.0), Vector3(7.0, 0.12, 0.12),
		Color(0.66, 0.80, 1.0, 1.0))

	var skater: CharacterBody3D = CharacterBody3D.new()
	skater.name = "Skater"
	skater.position = Vector3(-9.0, 1.0, 0.0)
	root.add_child(skater)
	skater.owner = root
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.name = "Collider"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1.0, 0.5, 0.5)
	collider.shape = shape
	skater.add_child(collider)
	collider.owner = root
	_add_block(skater, root, "Board", Vector3.ZERO, Vector3(1.0, 0.12, 0.4),
		Color(1.0, 0.78, 0.32, 1.0))
	_attach_behavior(skater, "Skateboard", SKATEBOARD_3D, root,
		{"push_speed": 2.0, "max_speed": 18.0, "ollie_speed": 6.0, "slope_grip": 1.0,
		"friction": 0.8, "balance_drift": 0.5, "lip_angle_degrees": 45.0})

	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(-38.0), 0.0)
	root.add_child(light)
	light.owner = root

	var camera: Camera3D = Camera3D.new()
	camera.name = "Camera"
	camera.position = Vector3(2.0, 6.0, 18.0)
	camera.rotation = Vector3(deg_to_rad(-14.0), 0.0, 0.0)
	root.add_child(camera)
	camera.owner = root

	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "Overlay"
	root.add_child(layer)
	layer.owner = root
	var label: Label = Label.new()
	label.name = "Hud"
	label.position = Vector2(28.0, 22.0)
	label.add_theme_font_size_override("font_size", 24)
	label.text = "Score 0   chain 0 x1   Space push / Up ollie / Right spin"
	layer.add_child(label)
	label.owner = root

	return _save_scene(root, "%s/skate_park_3d.tscn" % SKATE_PARK_3D_DIR)


# ── 24. Combo Fighter (Y1 / Y2 / Y3: the three timing tricks a fighting game is made of) ──────
# Three combos drive three animations, a cancel window lets the next move interrupt the last one,
# and the hit frame the animation itself names freezes the whole game for a moment. Every shape here
# is one the READING recognises, so opening combo_fighter.gd as a sheet gives back these very rows:
# the pressed-list-plus-window loop reads as Combo Box ▸ On combo "punch punch kick", the two
# comparisons on the play head read as one Is between row, and the three time-scale lines read as one
# Hitstop row. That double duty is the point - the showcase is also the fixture.


## The three moves, as {combo id: [the joined inputs, the clip it plays]}. One table, so the sheet,
## the animations and the on-screen move list can never disagree about what the character can do.
const FIGHTER_MOVES: Dictionary = {
	"uppercut": ["punch,punch,kick", "uppercut"],
	"sweep": ["kick,kick", "sweep"],
	"spin": ["punch,kick,punch", "spin"]
}


func _build_combo_fighter() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "ComboFighter"
	sheet.emit_live_values = false

	var about: CommentRow = CommentRow.new()
	about.text = "[b]Combo Fighter[/b] - the four pieces a fighting game is made of, each one a row. Press J (punch) and K (kick): the inputs collect into a rolling list with a 0.5 s window, and the move the list spells plays its animation. The uppercut's method track calls the hit frame, which freezes the whole game for 0.05 s - that is hit-stop. Between 0.3 s and 0.6 s of a move the next one may cancel it. A press made a few frames too early is buffered rather than dropped. Open this file as a sheet: every shape reads back as the row that writes it."
	sheet.events.append(about)

	sheet.variables = {
		"combo": {"type": "Array", "default": [], "exported": false,
			"attributes": {"tooltip": "The inputs pressed so far, oldest first. Emptied when the window runs out."}},
		"combo_timer": {"type": "float", "default": 0.0, "exported": false,
			"attributes": {"tooltip": "Seconds left to press the next input of a combo."}},
		"punch_input": {"type": "int", "default": -1, "exported": false,
			"attributes": {"tooltip": "The physics frame a buffered punch stops counting on."}},
		"hits": {"type": "int", "default": 0, "exported": false,
			"attributes": {"tooltip": "How many hit frames have landed this session."}},
		"cancels": {"type": "int", "default": 0, "exported": false,
			"attributes": {"tooltip": "How many moves were cancelled inside their window."}}
	}

	# ── The window that empties the buffer ──────────────────────────────────────────────────
	# A countdown and the list it clears: the shape a combo detector is, and the shape the reading
	# looks for before it will call anything here a combo at all.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	tick.actions.append(_action("Core", "SubtractVar", "{var_name} -= {amount}",
		{"var_name": "combo_timer", "amount": "delta"}))
	tick.actions.append(_action("Core", "SetTextFormatted", "{target}.text = {template} % [{args}]",
		{"target": "$Info", "template": "\"J = punch   ·   K = kick   ·   %d hit frames   ·   %d cancels\"",
			"args": "hits, cancels"}))
	var expired: EventRow = EventRow.new()
	expired.conditions.append(_condition("Core", "CompareVar", "{var_name} {op} {value}",
		{"var_name": "combo_timer", "op": "<=", "value": "0.0"}))
	expired.actions.append(_action("Core", "ArrayClear", "{var_name}.clear()", {"var_name": "combo"}))
	tick.sub_events.append(expired)
	sheet.events.append(tick)

	# ── The buffered press ──────────────────────────────────────────────────────────────────
	# A punch pressed while a move is still running is remembered for six physics frames rather than
	# dropped, and spent the moment the character can act again.
	var punch_pressed: EventRow = EventRow.new()
	punch_pressed.trigger_provider_id = "Core"
	punch_pressed.trigger_id = "OnUnhandledInput"
	punch_pressed.conditions.append(_condition("Core", "KeyEventPressed", "(event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == {key})",
		{"key": "KEY_J"}))
	punch_pressed.actions.append(_action("Core", "BufferInput", "{input} = Engine.get_physics_frames() + {frames}",
		{"input": "punch_input", "frames": "6"}))
	sheet.events.append(punch_pressed)

	var kick_pressed: EventRow = EventRow.new()
	kick_pressed.trigger_provider_id = "Core"
	kick_pressed.trigger_id = "OnUnhandledInput"
	kick_pressed.conditions.append(_condition("Core", "KeyEventPressed", "(event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == {key})",
		{"key": "KEY_K"}))
	kick_pressed.actions.append(_raw("press(\"kick\")"))
	sheet.events.append(kick_pressed)

	# ── Spending the buffer ─────────────────────────────────────────────────────────────────
	# Asked and consumed in the same breath, because the memory stays fresh for the whole six frames
	# and an event that only asks would fire on every one of them.
	var spend: EventRow = EventRow.new()
	spend.trigger_provider_id = "Core"
	spend.trigger_id = "OnPhysicsProcess"
	spend.conditions.append(_condition("Core", "IsInputBuffered", "(Engine.get_physics_frames() <= {input})",
		{"input": "punch_input"}))
	spend.actions.append(_action("Core", "ConsumeBufferedInput", "{input} = Engine.get_physics_frames() - 1",
		{"input": "punch_input"}))
	spend.actions.append(_raw("press(\"punch\")"))
	sheet.events.append(spend)

	# ── The detector itself ─────────────────────────────────────────────────────────────────
	# Push the input, stamp the window, and ask what the list now spells. Three moves, one arm each.
	var press: EventFunction = EventFunction.new()
	press.function_name = "press"
	press.enabled = true
	var button_param: ACEParam = ACEParam.new()
	button_param.id = "button"
	button_param.type_name = "String"
	button_param.type = TYPE_STRING
	press.params = [button_param]
	var press_body: EventRow = EventRow.new()
	press_body.actions.append(_action("Core", "ArrayAppend", "{var_name}.append({value})",
		{"var_name": "combo", "value": "button"}))
	press_body.actions.append(_action("Core", "SetVar", "{var_name} = {value}",
		{"var_name": "combo_timer", "value": "0.5"}))
	var moves: MatchRow = MatchRow.new()
	moves.match_expression = "\",\".join(combo)"
	for move_id: String in ["uppercut", "sweep", "spin"]:
		var spelling: Array = FIGHTER_MOVES[move_id]
		var arm: MatchCase = MatchCase.new()
		arm.pattern = "\"%s\"" % str(spelling[0])
		arm.events = [
			_raw("$AnimationPlayer.play(\"%s\")" % str(spelling[1])),
			_action("Core", "ArrayClear", "{var_name}.clear()", {"var_name": "combo"})
		]
		moves.cases.append(arm)
	press_body.actions.append(moves)
	press.events = [press_body]
	sheet.functions.append(press)

	# ── The cancel window ───────────────────────────────────────────────────────────────────
	# Between 0.3 s and 0.6 s of the uppercut the next move may interrupt it. The clip is part of the
	# question on purpose: a window that also opened during idle would not be a window.
	var cancel: EventFunction = EventFunction.new()
	cancel.function_name = "try_cancel"
	cancel.enabled = true
	cancel.return_type = TYPE_BOOL
	var cancel_body: EventRow = EventRow.new()
	cancel_body.conditions.append(_condition("Core", "AnimationIsBetween",
		"{target.}current_animation == {animation} and {target.}current_animation_position > {from_time} and {target.}current_animation_position < {to_time}",
		{"animation": "\"uppercut\"", "from_time": "0.3", "to_time": "0.6", "target": "$AnimationPlayer"}))
	cancel_body.actions.append(_action("Core", "AddVar", "{var_name} += {amount}",
		{"var_name": "cancels", "amount": "1"}))
	cancel_body.actions.append(_raw("return true"))
	cancel.events = [cancel_body, _raw("return false")]
	sheet.functions.append(cancel)

	# ── The hit frame the ANIMATION names ───────────────────────────────────────────────────
	# The uppercut's method track calls this by name. Nothing in the script says so - which is why
	# the sheet does, and why Project Doctor warns when a track names a function nobody wrote.
	var hit: EventFunction = EventFunction.new()
	hit.function_name = "_on_hit_frame"
	hit.enabled = true
	var hit_body: EventRow = EventRow.new()
	hit_body.actions.append(_action("Core", "AddVar", "{var_name} += {amount}",
		{"var_name": "hits", "amount": "1"}))
	hit_body.actions.append(_action("Core", "Hitstop",
		"Engine.time_scale = {scale}\nawait get_tree().create_timer({seconds}, true, false, true).timeout\nEngine.time_scale = 1.0",
		{"seconds": "0.05", "scale": "0.1"}))
	hit.events = [hit_body]
	sheet.functions.append(hit)

	if not _compile(sheet, "res://demo/showcase/combo_fighter/combo_fighter.tres",
			"res://demo/showcase/combo_fighter/combo_fighter.gd"):
		return false

	var root: Node2D = Node2D.new()
	root.name = "ComboFighter"
	root.set_script(load("res://demo/showcase/combo_fighter/combo_fighter.gd"))
	var body: Sprite2D = Sprite2D.new()
	body.name = "Body"
	body.texture = _make_texture()
	body.position = Vector2(320, 300)
	root.add_child(body)
	body.owner = root
	var player: AnimationPlayer = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.add_animation_library("", _fighter_animations())
	root.add_child(player)
	player.owner = root
	var label: Label = Label.new()
	label.name = "Info"
	label.position = Vector2(24, 18)
	label.add_theme_font_size_override("font_size", 22)
	label.text = "J = punch   ·   K = kick   ·   0 hit frames   ·   0 cancels"
	root.add_child(label)
	label.owner = root
	var moves_label: Label = Label.new()
	moves_label.name = "Moves"
	moves_label.position = Vector2(24, 54)
	moves_label.add_theme_font_size_override("font_size", 18)
	var listed: PackedStringArray = PackedStringArray()
	for move_id: String in ["uppercut", "sweep", "spin"]:
		listed.append("%s = %s" % [str((FIGHTER_MOVES[move_id] as Array)[0]).replace(",", " "), move_id])
	moves_label.text = "\n".join(listed)
	root.add_child(moves_label)
	moves_label.owner = root
	return _save_scene(root, "res://demo/showcase/combo_fighter/combo_fighter.tscn")


## The three moves as real animations, each one a slide-and-tint on the body plus - on the uppercut -
## the METHOD TRACK that calls the hit frame. Built here rather than hand-authored so a regeneration
## is byte-stable and the method track is guaranteed to name a function the sheet defines.
func _fighter_animations() -> AnimationLibrary:
	var library: AnimationLibrary = AnimationLibrary.new()
	library.add_animation("idle", _fighter_move("idle", Vector2.ZERO, Color(1, 1, 1, 1), 0.6, false))
	library.add_animation("uppercut", _fighter_move("uppercut", Vector2(40, -90), Color(1, 0.72, 0.3, 1), 0.9, true))
	library.add_animation("sweep", _fighter_move("sweep", Vector2(70, 24), Color(0.5, 0.85, 1, 1), 0.7, false))
	library.add_animation("spin", _fighter_move("spin", Vector2(0, -40), Color(0.8, 0.6, 1, 1), 0.8, false))
	return library


## One move: the body leaves its rest place, tints, and comes back. `with_hit_frame` adds the method
## track at 0.35 s - the moment the blow connects, said by the animation rather than by a stopwatch.
func _fighter_move(clip_name: String, offset: Vector2, tint: Color, length: float,
		with_hit_frame: bool) -> Animation:
	var move: Animation = Animation.new()
	# The clip's own name, written into the file beside its tracks. Godot does not derive one from the
	# library key, and without it nothing reading the SCENE could say which clip a method track sits on
	# - which is exactly what the animation-event reading and the Doctor both need.
	move.resource_name = clip_name
	move.length = length
	var rest: Vector2 = Vector2(320, 300)
	var place: int = move.add_track(Animation.TYPE_VALUE)
	move.track_set_path(place, "Body:position")
	move.track_insert_key(place, 0.0, rest)
	move.track_insert_key(place, length * 0.4, rest + offset)
	move.track_insert_key(place, length, rest)
	var colour: int = move.add_track(Animation.TYPE_VALUE)
	move.track_set_path(colour, "Body:modulate")
	move.track_insert_key(colour, 0.0, Color(1, 1, 1, 1))
	move.track_insert_key(colour, length * 0.4, tint)
	move.track_insert_key(colour, length, Color(1, 1, 1, 1))
	if with_hit_frame:
		var calls: int = move.add_track(Animation.TYPE_METHOD)
		move.track_set_path(calls, ".")
		move.track_insert_key(calls, 0.35, {"method": &"_on_hit_frame", "args": []})
	return move
