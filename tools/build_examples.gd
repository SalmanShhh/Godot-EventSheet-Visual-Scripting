# Showcase/example builder (release ritual): regenerates demo/showcase/ — a flagship
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

## Save sheet -> reload (so it has a real path) -> compile to gd -> assert success.
func _compile(sheet: EventSheetResource, tres_path: String, gd_path: String) -> bool:
	# Deterministic row uids so rebuilding an unchanged showcase is byte-identical (no diff
	# churn) — same fix the behavior-pack builder uses.
	PackLib._assign_stable_uids(sheet)
	var save_err: Error = ResourceSaver.save(sheet, tres_path)
	var saved: EventSheetResource = load(tres_path)
	if saved == null:
		print("[build_examples] FAIL load %s" % tres_path)
		return false
	saved.take_over_path(tres_path)
	var result: Dictionary = SheetCompiler.compile(saved, gd_path)
	var success: bool = bool(result.get("success", false))
	print("[build_examples] %s save=%d compile=%s warnings=%s errors=%s" % [
		tres_path.get_file(), save_err, str(success), str(result.get("warnings", [])), str(result.get("errors", []))])
	return success

func _save_scene(root: Node, path: String) -> bool:
	var packed: PackedScene = PackedScene.new()
	var pack_err: Error = packed.pack(root)
	var save_err: Error = ResourceSaver.save(packed, path)
	print("[build_examples] %s pack=%d save=%d" % [path.get_file(), pack_err, save_err])
	return pack_err == OK and save_err == OK

# ── 1. Carousel of Juice (flagship) ─────────────────────────────────────────

const SPRING := "res://eventsheet_addons/spring/spring_behavior.gd"
const TWEEN := "res://eventsheet_addons/tween/tween_behavior.gd"
const SINE := "res://eventsheet_addons/sine/sine_behavior.gd"
const FLASH := "res://eventsheet_addons/flash/flash_behavior.gd"

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
	about.text = "[b]Carousel of Juice[/b] — 8 tiles sine-sway and spring-pop on the beat (one reused juice_tile function). A runtime-toggleable Juice group plus an if/elif/else keypress chain re-skin the board: [b]ui_accept[/b] starts the party, [b]ui_cancel[/b] calms it. Watch beat/intensity stream in Live Values."
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

	if not _compile(sheet, "res://demo/showcase/showcase_carousel.tres", "res://demo/showcase/showcase_carousel.gd"):
		return false

	# Scene
	var tex: ImageTexture = _make_texture()
	var root: Node2D = Node2D.new()
	root.name = "Carousel"
	root.set_script(load("res://demo/showcase/showcase_carousel.gd"))
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

	return _save_scene(root, "res://demo/showcase/showcase_carousel.tscn")

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
	if not _save_scene(star, "res://demo/showcase/star.tscn"):
		return false

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "Starfall"
	sheet.emit_live_values = false

	var about: CommentRow = CommentRow.new()
	about.text = "[b]Starfall[/b] — a complete restartable arcade game authored as events: move the ship (ui_left/ui_right) to catch falling stars. Shows an enum+match state machine (PLAYING/GAME_OVER), a group pick-filter that scores & culls stars, an Every-2s spawner, and if/elif input branches. Miss 3 and it's GAME OVER — press ui_accept to restart."
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
	place.actions.append(_raw("$Ship.position = Vector2(576, 590)"))
	sheet.events.append(place)

	# FSM tick (enum + match), restart on ui_accept when GAME_OVER.
	var fsm: EventRow = EventRow.new()
	fsm.trigger_provider_id = "Core"; fsm.trigger_id = "OnPhysicsProcess"
	var fsm_match: MatchRow = MatchRow.new()
	fsm_match.match_expression = "state"
	fsm_match.branches_text = "State.PLAYING:\n\tpass\nState.GAME_OVER:\n\tif Input.is_action_just_pressed(&\"ui_accept\"):\n\t\tscore = 0\n\t\tlives = 3\n\t\tstate = State.PLAYING\n\t\tfor s: Node in get_tree().get_nodes_in_group(\"stars\"):\n\t\t\ts.queue_free()\n_:\n\tpass"
	fsm.actions.append(fsm_match)
	sheet.events.append(fsm)

	# Move left (if) — whole-Vector2 assign avoids the value-type-copy pitfall.
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
		"var __spawn_star = load(\"res://demo/showcase/star.tscn\").instantiate()\n__spawn_star.position = Vector2(randf_range(60.0, 1100.0), -20.0)\n__spawn_star.rotation_degrees = 90.0\nadd_child(__spawn_star)", {}))
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
	hud.actions.append(_raw("$ScoreLabel.text = \"Score %d    Lives %d    %s\" % [score, lives, (\"GAME OVER - press Enter\" if state == State.GAME_OVER else \"PLAYING\")]"))
	sheet.events.append(hud)

	if not _compile(sheet, "res://demo/showcase/starfall.tres", "res://demo/showcase/starfall.gd"):
		return false

	# Scene
	var root: Node2D = Node2D.new()
	root.name = "Starfall"
	root.set_script(load("res://demo/showcase/starfall.gd"))
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
	return _save_scene(root, "res://demo/showcase/starfall.tscn")

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
	about.text = "[b]Quest & Inventory FSM[/b] — a self-driving quest engine (no input): an enum+match state machine walks OFFERED -> ACTIVE -> COMPLETE, a reused grant_item() function fills a Dictionary inventory + Array quest log and emits signals, and signal: triggers spring/tween the icon on every beat. Proves the sheet compiles real software logic — collections, signals, functions, match — not just movement."
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
	# Function bodies compile through _emit_event_body, which processes ROWS — so the
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

	# signal: triggers — react to the sheet's own signals (auto-connected in _ready).
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
	hud.actions.append(_raw("$Screen.text = \"QUEST: %s\nitems: %d   log: %d\nt = %d\" % [[\"OFFERED\", \"ACTIVE\", \"COMPLETE\"][quest_state], inventory.size(), quest_log.size(), tick]"))
	sheet.events.append(hud)

	if not _compile(sheet, "res://demo/showcase/quest_fsm.tres", "res://demo/showcase/quest_fsm.gd"):
		return false

	# Scene
	var tex: ImageTexture = _make_texture()
	var root: Node2D = Node2D.new()
	root.name = "QuestDemo"
	root.set_script(load("res://demo/showcase/quest_fsm.gd"))
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
	return _save_scene(root, "res://demo/showcase/quest_fsm.tscn")

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
	if not _save_scene(shot, "res://demo/showcase/shot.tscn"):
		return false

	# Target that drifts in from the right (also a BulletBehavior, slower).
	var target: Sprite2D = Sprite2D.new()
	target.name = "Target"
	target.texture = tex
	target.scale = Vector2(0.4, 0.4)
	target.modulate = Color(1.0, 0.4, 0.45, 1.0)
	_attach_behavior(target, "BulletBehavior", BULLET, target, {"speed": 130.0, "align_rotation": false})
	if not _save_scene(target, "res://demo/showcase/target.tscn"):
		return false

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "PlatformerShooter"
	sheet.emit_live_values = false

	var about: CommentRow = CommentRow.new()
	about.text = "[b]Platformer-Shooter[/b] — the new Platformer + Weapon Kit packs working together. Run with A/D, jump with Up (double jump + coyote time + variable height from the Platformer pack), and hold Space to shoot (fire-rate, ammo and auto-reload from the Weapon Kit). Shots destroy the red targets drifting in from the right."
	sheet.events.append(about)

	sheet.variables = {
		"score": {"type": "int", "default": 0, "exported": true,
			"attributes": {"tooltip": "Targets destroyed."}}
	}

	# Jump (Up): press to jump, release for variable jump height — fully code-free, one event per
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

	# Fire (hold Space): FULLY CODE-FREE — conditions on the left (the input + the Weapon Kit's own
	# Can Fire gate, targeting the behavior at $Player/WeaponKit), actions on the right (the pack's
	# Fire, then Spawn Scene (Full) aimed by the Platformer pack's facing_direction). This is the row
	# the node-targetable pack ACEs unlocked — no raw GDScript, the same legibility as Construct.
	var fire: EventRow = EventRow.new()
	fire.trigger_provider_id = "Core"; fire.trigger_id = "OnPhysicsProcess"
	fire.conditions.append(_condition("Core", "IsActionPressed", "Input.is_action_pressed(&{action})", {"action": "\"ui_accept\""}))
	fire.conditions.append(_condition("WeaponKit", "method:can_fire", "{target}.can_fire()", {"target": "$Player/WeaponKit"}))
	fire.actions.append(_action("WeaponKit", "method:fire", "{target}.fire()", {"target": "$Player/WeaponKit"}))
	fire.actions.append(_action("Core", "SpawnSceneFull", "var __spawn_shot = load({path}).instantiate()\n__spawn_shot.position = {position}\n__spawn_shot.rotation_degrees = {rotation}\nadd_child(__spawn_shot)\nif {group} != \"\": __spawn_shot.add_to_group({group})", {"path": "\"res://demo/showcase/shot.tscn\"", "position": "$Player.position + Vector2(32.0 * $Player/PlatformerMovement.facing_direction(), -6.0)", "rotation": "0.0 if $Player/PlatformerMovement.facing_direction() >= 0 else 180.0", "group": "\"shots\""}))
	sheet.events.append(fire)

	# Keep the player on screen.
	var clamp_row: EventRow = EventRow.new()
	clamp_row.trigger_provider_id = "Core"; clamp_row.trigger_id = "OnPhysicsProcess"
	clamp_row.actions.append(_raw("$Player.position.x = clampf($Player.position.x, 40.0, 1112.0)"))
	sheet.events.append(clamp_row)

	# Spawn a target from the right every 1.5s.
	var spawn: EventRow = EventRow.new()
	spawn.trigger_provider_id = "Core"; spawn.trigger_id = "OnPhysicsProcess"
	spawn.conditions.append(_every("ps_spawn", "1.5"))
	spawn.actions.append(_raw("\n".join(PackedStringArray([
		"var __target = load(\"res://demo/showcase/target.tscn\").instantiate()",
		"__target.position = Vector2(1240.0, randf_range(120.0, 540.0))",
		"__target.rotation_degrees = 180.0",
		"add_child(__target)",
		"__target.add_to_group(\"targets\")"
	]))))
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
	hud_row.actions.append(_raw("$Hud.text = \"Score %d    Ammo %d/%d    %s\" % [score, $Player/WeaponKit.current_ammo, $Player/WeaponKit.max_ammo, (\"RELOADING...\" if $Player/WeaponKit.is_reloading() else \"A/D move   Up jump   hold Space fire\")]"))
	sheet.events.append(hud_row)

	if not _compile(sheet, "res://demo/showcase/platformer_shooter.tres", "res://demo/showcase/platformer_shooter.gd"):
		return false

	# ── Scene: floor + player (with both behaviors) + HUD ──
	var root: Node2D = Node2D.new()
	root.name = "PlatformerShooter"
	root.set_script(load("res://demo/showcase/platformer_shooter.gd"))

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

	return _save_scene(root, "res://demo/showcase/platformer_shooter.tscn")

# ── 5. Swarm — frame-spreading crowd (Budgeted For Each) ─────────────────────

func _build_swarm() -> bool:
	# Dot sub-scene: a small group-tagged sprite the sheet spawns by the hundreds.
	var tex: ImageTexture = _make_texture()
	var dot: Sprite2D = Sprite2D.new()
	dot.name = "Dot"
	dot.texture = tex
	dot.scale = Vector2(0.32, 0.32)
	dot.add_to_group("swarm", true)
	if not _save_scene(dot, "res://demo/showcase/dot.tscn"):
		return false

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "Swarm"
	sheet.emit_live_values = false

	var about: CommentRow = CommentRow.new()
	about.text = "[b]Swarm[/b] — frame-spreading made visible. On Ready spawns 800 sprites into the \"swarm\" group; ONE For Each with a frame-spread budget of 90/frame wobbles them, so only a slice updates each frame and the colour refresh SWEEPS through the crowd — that visible wave IS the spreading. The FPS stays pinned even though the loop never touches the whole crowd in a single frame. Tick frame_spread_count on any For Each to get this — no behavior, no await."
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
	spawn.actions.append(_raw("var __cols: int = 40\nfor __i: int in range(count):\n\tvar __dot: Sprite2D = load(\"res://demo/showcase/dot.tscn\").instantiate()\n\t__dot.position = Vector2(48.0 + float(__i % __cols) * 27.0, 70.0 + float(__i / __cols) * 27.0)\n\tadd_child(__dot)"))
	sheet.events.append(spawn)

	# On Process: advance the clock + show the live FPS so you can see it stay smooth.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"; tick.trigger_id = "OnProcess"
	tick.actions.append(_raw("t += delta"))
	tick.actions.append(_raw("$Info.text = \"%d sprites   ·   Budgeted For Each: 90/frame   ·   %d FPS\" % [count, Engine.get_frames_per_second()]"))
	sheet.events.append(tick)

	# On Process: a Budgeted For Each over the crowd — wobble the texture offset + sweep the hue.
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

	if not _compile(sheet, "res://demo/showcase/swarm.tres", "res://demo/showcase/swarm.gd"):
		return false

	# Scene: the script-bearing root + a HUD label.
	var root: Node2D = Node2D.new()
	root.name = "Swarm"
	root.set_script(load("res://demo/showcase/swarm.gd"))
	var label: Label = Label.new()
	label.name = "Info"
	label.position = Vector2(24, 18)
	label.add_theme_font_size_override("font_size", 24)
	label.text = "800 sprites   ·   Budgeted For Each: 90/frame   ·   60 FPS"
	root.add_child(label); label.owner = root
	return _save_scene(root, "res://demo/showcase/swarm.tscn")
