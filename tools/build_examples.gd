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
	all_ok = _build_fps_arena() and all_ok
	all_ok = _build_input_rebind() and all_ok
	all_ok = _build_path_chase() and all_ok
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
	PackLib._assign_stable_uids(sheet)
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
	sheet.events.append(ready_event)
	var camera_toggle: EventRow = EventRow.new()
	camera_toggle.trigger_provider_id = "Core"
	camera_toggle.trigger_id = "OnProcess"
	camera_toggle.actions.append(_raw("if Input.is_action_just_pressed(\"ui_focus_next\"):\n\t$Player/FPSController.toggle_camera_mode()"))
	sheet.events.append(camera_toggle)
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

	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.name = "Floor"
	root.add_child(floor_body); floor_body.owner = root
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
		root.add_child(crate); crate.owner = root
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

	var hud_layer: CanvasLayer = CanvasLayer.new()
	hud_layer.name = "HudLayer"
	root.add_child(hud_layer); hud_layer.owner = root
	var hud: Label = Label.new()
	hud.name = "Hud"
	hud.position = Vector2(24.0, 20.0)
	hud.add_theme_font_size_override("font_size", 20)
	hud.text = "WASD/arrows move · mouse looks · Shift sprints · Space jumps · Tab flips camera · Esc frees mouse"
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


## The pathfinding pairing showcase: a tile level (ground with a gap, a two-step stair to a mid
## platform, a hop, and a high platform), a keyboard-driven Player, and a Chaser whose
## PlatformerPathfinding behavior routes to the Player once a second and DRIVES the sibling
## PlatformerMovement through its ai_move_axis seam - stairs walk, the gap is jumped, the
## platforms are climbed, and the green debug line shows the live path.
func _build_path_chase() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "PathChaseDemo"
	sheet.emit_live_values = false
	var about: CommentRow = CommentRow.new()
	about.text = "[b]Path Chase[/b] - Platformer Pathfinding + Platformer Movement on one Chaser: the graph is built from the TileMapLayer once, then Find Path To Node re-routes to the Player every second. The pathfinder derives jump reach from the movement pack and steers it through the ai_move_axis seam - the same movement rules you play with. Green line = the Chaser's live path."
	sheet.events.append(about)

	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"
	var on_ready_body: RawCodeRow = RawCodeRow.new()
	on_ready_body.code = "\n".join(PackedStringArray([
		"$Chaser/Pathfinding.build_nav_graph($Level)",
		"$Chaser/Pathfinding.set_nav_debug_draw(true)"
	]))
	on_ready.actions.append(on_ready_body)
	sheet.events.append(on_ready)

	# The chase: re-route to wherever the Player is now, once a second.
	var repath: EventRow = EventRow.new()
	repath.trigger_provider_id = "Core"
	repath.trigger_id = "OnProcess"
	repath.conditions.append(_every("repath", "1.0"))
	var repath_body: RawCodeRow = RawCodeRow.new()
	repath_body.code = "$Chaser/Pathfinding.find_path_to_node($Player, \"nearest\")"
	repath.actions.append(repath_body)
	sheet.events.append(repath)

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

	# The level: ground with a 3-cell gap, a two-step stair onto a mid platform, a hop
	# platform after the gap, and a high platform (the Player's perch). 32px tiles.
	var level: TileMapLayer = TileMapLayer.new()
	level.name = "Level"
	level.tile_set = _chase_tileset()
	for x in range(1, 35):
		if x < 15 or x > 17:
			level.set_cell(Vector2i(x, 17), 0, Vector2i.ZERO)
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
	root.add_child(level)
	level.owner = root

	var player: CharacterBody2D = _chase_actor("Player", Vector2(784.0, 384.0), Color(0.35, 0.65, 1.0))
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
	hud.text = "Arrows move · Space jumps · the red Chaser pathfinds to you (green line = its path)"
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
