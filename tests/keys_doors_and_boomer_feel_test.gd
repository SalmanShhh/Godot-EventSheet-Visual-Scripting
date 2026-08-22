@tool
class_name KeysDoorsAndBoomerFeelTest
extends RefCounted

# Pins batch fourteen's boomer parcel - the three items that finish the shooter kit:
#
#   Y16  keys and doors: the four keycard rows, the door pair, the trigger a door answers with,
#        the writable "needs key" mark and the event a marked door's drop offers, and the Keycard
#        Door starter
#   Y17  the feel layer: the FPS Controller's air control, bunny hop, bob and sway knobs, the two
#        weapon rows, and the readings that recognise the hand-written shapes of all three
#   Y18  enemies and pickups: alerting, infighting, the respawning pickup, and the exit tally
#
# Everything here pins VALUES: the exact emitted line, the exact reading, the exact template. The
# RUNTIME behaviour of the showcase was verified by a NON-headless harness (physics does not step in
# this suite: run_tests.gd's _init runs before the main loop exists, so there is no scene tree to
# reach). The recipe, and the numbers it produced, so anyone can repeat it:
#
#   a SceneTree script instantiates res://demo/showcase/boomer_level/boomer_level.tscn, lets two
#   physics frames pass, then calls the level's own handlers -
#     _on_doortrigger_body_entered(Player)  with no key   -> door_open=false, the door stays at
#                                                            y=1.6, locked_hint reads
#                                                            "Locked. You need the red_key keycard."
#     _on_redcard_body_entered(Player)                    -> keys == ["red_key"]
#     _on_doortrigger_body_entered(Player)  with the key  -> door_open=true, the door rises exactly
#                                                            3.2 to y=4.8, collision_layer=0
#     HealthPickup._on_body_entered(Player), 0.4 s timer   -> visible=false, then visible=true and
#                                                            monitoring=true after the wait
#     Grunt1.take_damage(5.0)                             -> Grunt2.target IS Grunt1, and Grunt1's
#                                                            own target stays null (nobody is
#                                                            alerted about themselves)
#     _on_exit_body_entered(Player)                       -> the tally reads
#                                                            "Kills 0 of 2   Secrets 0 of 1   Time 00:01 of 01:00"


static func run() -> bool:
	var ok: bool = true
	ok = _keycard_vocabulary() and ok
	ok = _door_contract() and ok
	ok = _needs_key_mark() and ok
	ok = _keycard_door_starter() and ok
	ok = _feel_knobs() and ok
	ok = _readings() and ok
	ok = _enemies_and_pickups() and ok
	ok = _showcase_sheets() and ok
	return ok


## Y16. The four keycard rows are the LIST words said about keys, so each template is exactly the
## line a project already writes by hand - which is what lets the same file round-trip either way.
static func _keycard_vocabulary() -> bool:
	var ok: bool = true
	var by_id: Dictionary = _descriptors()
	ok = _check("picking a key up is the plain append",
		_template(by_id, "PickUpKey"), "{keys}.append({key})") and ok
	ok = _check("carrying one is the plain membership test",
		_template(by_id, "HasKey"), "({key} in {keys})") and ok
	ok = _check("missing one is its negation",
		_template(by_id, "NeedsKey"), "(not {key} in {keys})") and ok
	ok = _check("how many are carried is the plain size",
		_template(by_id, "KeysHeld"), "{keys}.size()") and ok
	ok = _check("the rows default to the same list", _param_default(by_id, "PickUpKey", "keys"), "keys") and ok
	ok = _check("and to the same key", _param_default(by_id, "HasKey", "key"), "\"red_key\"") and ok
	ok = _check("Keys Held is an expression",
		int((by_id.get("KeysHeld") as ACEDescriptor).ace_type), int(ACEDescriptor.ACEType.EXPRESSION)) and ok
	# THE SHADOW GATE. Three of these spell the most general operations a list has, so none of them
	# may speak for a line nobody wrote them for: they author, and the reading says what a line means.
	for shadowed: String in ["PickUpKey", "HasKey", "NeedsKey"]:
		ok = _check("%s stays out of the reverse index" % shadowed,
			EventSheetACELifter.REVERSE_LIFT_EXCLUDED_ACE_IDS.has(shadowed), true) and ok
	return ok


## Y16. The door pair and the trigger between them. Try Door is the whole gesture; Open Door is what
## a door does about it, once; On Locked Door Tried is the door's answer when the key does not fit.
static func _door_contract() -> bool:
	var ok: bool = true
	var by_id: Dictionary = _descriptors()
	ok = _check("Try Door dispatches on the door by name, through an untyped local",
		_template(by_id, "TryDoor"), "\n".join(PackedStringArray([
			"var __door_{uid} = {door}",
			"if str(__door_{uid}.needs_key) in {keys}:",
			"\t__door_{uid}.open_door()",
			"else:",
			"\t__door_{uid}.locked_door_tried(str(__door_{uid}.needs_key))"
		]))) and ok
	ok = _check("Open Door opens once, stops blocking, and slides",
		_template(by_id, "OpenDoor"), "\n".join(PackedStringArray([
			"if not {opened}:",
			"\t{opened} = true",
			"\tvar __door_{uid} = {door}",
			"\t__door_{uid}.set_deferred(\"collision_layer\", 0)",
			"\tcreate_tween().tween_property(__door_{uid}, \"position\", __door_{uid}.position + {slide}, {seconds})"
		]))) and ok
	ok = _check("the opened flag defaults to the door's own",
		_param_default(by_id, "OpenDoor", "opened"), "door_open") and ok
	ok = _check("On Locked Door Tried is a trigger",
		int((by_id.get("OnLockedDoorTried") as ACEDescriptor).ace_type),
		int(ACEDescriptor.ACEType.TRIGGER)) and ok
	# The handler it compiles to IS the function Try Door calls, or the pair does nothing at all.
	var door_event: EventRow = EventRow.new()
	door_event.trigger_provider_id = "Core"
	door_event.trigger_id = "OnLockedDoorTried"
	var resolved: Dictionary = TriggerResolver.resolve_trigger(door_event)
	ok = _check("and compiles to the function Try Door calls",
		str(resolved.get("function_name", "")), "locked_door_tried") and ok
	ok = _check("with the key that was wanted as its argument",
		str(resolved.get("args", "")), "key: Variant") and ok
	ok = _check("an opened door script reads that handler as the trigger",
		str(EventSheetACELifter.LIFECYCLE_TRIGGERS.get(
			"func locked_door_tried(key: Variant) -> void:", "")), "OnLockedDoorTried") and ok
	return ok


## Y16. The mark a reader writes on a door, and the event dropping that door then offers.
static func _needs_key_mark() -> bool:
	var ok: bool = true
	EventSheetObjectProperties.reset_needs_key_for_tests()
	var door: Dictionary = {"label": "RedDoor", "class": "StaticBody3D", "kind": "node",
		"path": "RedDoor", "rows": 1, "verbs": PackedStringArray()}
	var label: Dictionary = {"label": "Hud", "class": "Label", "kind": "node",
		"path": "Hud", "rows": 1, "verbs": PackedStringArray()}
	ok = _check("a body can want a key", EventSheetObjectProperties.can_need_key(door), true) and ok
	ok = _check("a label cannot", EventSheetObjectProperties.can_need_key(label), false) and ok
	ok = _check("no door wants a key until one is named",
		EventSheetObjectProperties.needs_key_of("res://level.gd", "RedDoor"), "") and ok
	EventSheetObjectProperties.set_needs_key("res://level.gd", "RedDoor", "red_key")
	ok = _check("naming one sticks",
		EventSheetObjectProperties.needs_key_of("res://level.gd", "RedDoor"), "red_key") and ok
	ok = _check("the mark belongs to the file that made it",
		EventSheetObjectProperties.needs_key_of("res://other.gd", "RedDoor"), "") and ok
	var key_row: Dictionary = {}
	for row: Dictionary in EventSheetObjectProperties.property_rows(door, "", "res://level.gd"):
		if str(row.get("form", "")) == "key":
			key_row = row
	ok = _check("the popup offers it as a name field",
		str(key_row.get("label", "")), "Needs key") and ok
	ok = _check("filled in, it reads back filled in", str(key_row.get("value", "")), "red_key") and ok
	ok = _check("and knows which door it is about", str(key_row.get("object", "")), "RedDoor") and ok
	EventSheetObjectProperties.set_needs_key("res://level.gd", "RedDoor", "")
	ok = _check("clearing it sticks too",
		EventSheetObjectProperties.needs_key_of("res://level.gd", "RedDoor"), "") and ok
	var offered: EventRow = EventSheetStarterEvents.locked_door_event("RedDoor", "StaticBody3D")
	ok = _check("the offered event rides the door's own walked-into trigger",
		offered.trigger_id, "OnBodyEntered") and ok
	ok = _check("and points at the door that was dropped",
		offered.trigger_source_path, "RedDoor") and ok
	ok = _check("its one action is the shipped Try Door row",
		str((offered.actions[0] as ACEAction).ace_id), "TryDoor") and ok
	ok = _check("which tries that door with the sheet's key list",
		(offered.actions[0] as ACEAction).params,
		{"door": "$RedDoor", "keys": "keys"}) and ok
	ok = _check("the row's template is the shipped one, not a retyped copy",
		EventSheetStarterEvents.locked_door_template(),
		_template(_descriptors(), "TryDoor")) and ok
	ok = _check("the list it reads is an array that starts empty",
		EventSheetStarterEvents.keys_variable_entry().get("default"), []) and ok
	return ok


## Y16. The Keycard Door starter: what kind of script it is, and the fact that it compiles to a door
## that keeps the whole contract - the key it wants, the opening, and the refusal.
static func _keycard_door_starter() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetStarterTemplates.build_starter(33)
	ok = _check("the keycard door is a body", sheet.host_class, "StaticBody3D") and ok
	ok = _check("it names itself", sheet.custom_class_name, "KeycardDoor") and ok
	ok = _check("the key it wants is the designer's knob",
		str((sheet.variables.get("needs_key", {}) as Dictionary).get("default", "")), "red_key") and ok
	ok = _check("and how far it slides",
		float((sheet.variables.get("slide_height", {}) as Dictionary).get("default", -1.0)), 3.2) and ok
	var built: String = str(SheetCompiler.compile(sheet, "user://y16_keycard_door.gd").get("output", ""))
	var script: GDScript = GDScript.new()
	script.source_code = built
	ok = _check("the keycard door starter compiles to GDScript that parses", script.reload(), OK) and ok
	ok = _check("it answers to the name Try Door calls when the key fits",
		built.contains("func open_door() -> void:"), true) and ok
	ok = _check("and to the one it calls when the key does not",
		built.contains("func locked_door_tried(key: Variant) -> void:"), true) and ok
	ok = _check("the opening is the shipped Open Door row",
		built.contains("\t\t__door_keycard_door.set_deferred(\"collision_layer\", 0)"), true) and ok
	ok = _check("and it slides by the door's own knobs",
		built.contains("create_tween().tween_property(__door_keycard_door, \"position\", __door_keycard_door.position + Vector3(0.0, slide_height, 0.0), slide_seconds)"), true) and ok
	ok = _check("the refusal writes a line the player can read",
		built.contains("locked_hint = \"Locked. You need the %s keycard.\" % str(key)"), true) and ok
	ok = _check("nothing ships an unbaked row id", built.contains("{uid}"), false) and ok
	return ok


## Y17. The five feel knobs, on the pack's SHIPPED source - which is the contract, so the assertions
## read it rather than the builder.
static func _feel_knobs() -> bool:
	var ok: bool = true
	var source: String = FileAccess.get_file_as_string(
		"res://eventsheet_addons/fps_controller/fps_controller_behavior.gd")
	ok = _check("air control is an exported share",
		source.contains("@export var air_control: float = 0.35"), true) and ok
	ok = _check("the bunny hop is an exported switch",
		source.contains("@export var keep_momentum: bool = true"), true) and ok
	ok = _check("the bob has a size and a period",
		source.contains("@export var bob_amount: float = 0.045") \
			and source.contains("@export var bob_period: float = 0.6"), true) and ok
	ok = _check("the sway has a weight and a catch-up rate",
		source.contains("@export var sway_amount: float = 0.002") \
			and source.contains("@export var sway_speed: float = 10.0"), true) and ok
	ok = _check("the landing frame with jump held is held as one fact",
		source.contains("var hopping := keep_momentum and on_floor and not was_on_floor and Input.is_action_pressed(\"ui_accept\")"), true) and ok
	ok = _check("which the airborne write reads",
		source.contains("if (not on_floor or hopping) and air_control < 1.0:"), true) and ok
	ok = _check("steering the run instead of replacing it",
		source.contains("\t\t\thost.velocity.x = lerpf(host.velocity.x, direction.x * speed + push_x, steer)"), true) and ok
	ok = _check("and which the jump read reads too",
		source.contains("if Input.is_action_just_pressed(\"ui_accept\") or hopping:"), true) and ok
	ok = _check("the sway is the last look movement, bleeding away",
		source.contains("_sway_x = lerpf(_sway_x, 0.0, sway_decay)"), true) and ok
	ok = _check("recorded where the look arrives", source.contains("\t_sway_x = x"), true) and ok
	ok = _check("the bob is one droppable row",
		source.contains("func bob_with_movement(weapon: Node3D) -> void:"), true) and ok
	ok = _check("whose template is the row a sheet writes",
		source.contains("## @ace_codegen_template(\"$FPSController.bob_with_movement({weapon})\")"), true) and ok
	ok = _check("and it scales with how fast the host is going",
		source.contains("var pace := clampf(current_speed() / maxf(move_speed, 0.001), 0.0, 1.0)"), true) and ok
	ok = _check("the sway is the other row",
		source.contains("func sway_with_mouse(weapon: Node3D) -> void:"), true) and ok
	ok = _check("lagging the weapon behind the view",
		source.contains("weapon.rotation.y = lerpf(weapon.rotation.y, -_sway_x * sway_amount, catch_up)"), true) and ok
	ok = _check("air control is retunable at run time",
		source.contains("func set_air_control(share: float) -> void:"), true) and ok
	ok = _check("and the hop reads back as a question",
		source.contains("func is_bunny_hopping() -> bool:"), true) and ok
	# The frozen neighbours: adding knobs must not have retemplated the rows that shipped.
	ok = _check("Set Move Speed is untouched",
		source.contains("## @ace_codegen_template(\"$FPSController.set_move_speed({value})\")"), true) and ok
	ok = _check("and so is the firing slowdown",
		source.contains("var base_speed := firing_move_speed if _firing_timer > 0.0 else move_speed"), true) and ok
	return ok


## Y16 / Y17. The readings, and - as much as the readings themselves - what they REFUSE. Each of
## these lines is the most general line in GDScript, so every claim is matched by a line that looks
## exactly like it and is about something else.
static func _readings() -> bool:
	var ok: bool = true
	ok = _check("a key going into a key list reads as picking it up",
		_says("keys.append(\"red_key\")"), "Pick up key \"red\"") and ok
	ok = _check("and the colour is the word, not the programmer's suffix",
		_says("door_keys.append(\"blue_key\")"), "Pick up key \"blue\"") and ok
	ok = _check("an ordinary append is still an ordinary append",
		_says("inventory.append(\"red_key\")").contains("Pick up key"), false) and ok
	ok = _check("and so is a key list taking something that is not a key",
		_says("keys.append(score)").contains("Pick up key"), false) and ok
	ok = _check("carrying a key reads as carrying it",
		_asks("\"red_key\" in keys"), "Has key \"red\"") and ok
	ok = _check("the .has() spelling reads the same",
		_asks("keys.has(\"red_key\")"), "Has key \"red\"") and ok
	ok = _check("missing one reads as needing it",
		_asks("not \"red_key\" in keys"), "Needs key \"red\"") and ok
	ok = _check("a door's own question names the key it needs",
		_asks("door.needs_key in keys"), "Has key the key it needs") and ok
	ok = _check("a membership test about anything else is untouched",
		_asks("\"gold\" in secrets_found").contains("Has key"), false) and ok
	# Y17. The feel shapes.
	ok = _check("an airborne lerp on a velocity component reads as air control",
		_says("velocity.x = lerpf(velocity.x, wish.x * speed, air_control * delta)"),
		"Air control air_control (steers the run in the air, keeps the rest)") and ok
	ok = _check("a lerp on a velocity that does not start from itself is not one",
		_says("velocity.x = lerpf(0.0, wish.x * speed, air_control * delta)").contains("Air control"), false) and ok
	ok = _check("a lerp with no per-second rate is not one either",
		_says("velocity.x = lerpf(velocity.x, wish.x * speed, 0.5)").contains("Air control"), false) and ok
	ok = _check("a sine driving a height reads as a bob",
		_says("weapon.position.y = base_y + sin(clock * 10.0) * 0.04"),
		"Bob up and down (a sine wave, as you move)") and ok
	ok = _check("a sine driving anything else is arithmetic",
		_says("weapon.position.x = base_x + sin(clock * 10.0) * 0.04").contains("Bob up and down"), false) and ok
	ok = _check("a rotation lerped toward the look movement reads as sway",
		_says("weapon.rotation.y = lerpf(weapon.rotation.y, -mouse_delta.x * 0.002, 10.0 * delta)"),
		"Sway with the mouse (catching up at 10.0 * delta)") and ok
	ok = _check("a rotation lerped toward a fixed angle is still a turn",
		_says("weapon.rotation.y = lerpf(weapon.rotation.y, 1.5, 10.0 * delta)").contains("Sway"), false) and ok
	# Every reading claims its pattern, or the chip and the Manual never hear about it.
	ok = _check("the keycard readings claim the keys-and-doors pattern",
		str(EventSheetSentence.keys_doors_statement("keys.append(\"red_key\")", {}).get("pattern", "")),
		"keys_doors") and ok
	ok = _check("and the feel readings claim movement",
		str(EventSheetSentence.movement_feel_statement(
			"velocity.x = lerpf(velocity.x, wish.x * speed, air_control * delta)", {}).get("pattern", "")),
		"movement") and ok
	ok = _check("keys_doors is a pattern the registry knows",
		EventSheetPatternFacts.PATTERN_IDS.has("keys_doors"), true) and ok
	return ok


## Y18. Alerting, infighting and the pickup that comes back.
static func _enemies_and_pickups() -> bool:
	var ok: bool = true
	var by_id: Dictionary = _descriptors()
	ok = _check("alerting walks the group and calls each one by name",
		_template(by_id, "AlertEnemiesWithin"), "\n".join(PackedStringArray([
			"for __alerted_{uid} in get_tree().get_nodes_in_group({group}):",
			"\tif __alerted_{uid} != {target} and __alerted_{uid}.global_position.distance_to({at}) < {radius}:",
			"\t\t__alerted_{uid}.alerted({target})"
		]))) and ok
	ok = _check("infighting is the one test in a hurt handler",
		_template(by_id, "RetaliateAgainstAttacker"), "\n".join(PackedStringArray([
			"if {attacker}.is_in_group({group}):",
			"\t{target} = {attacker}"
		]))) and ok
	ok = _check("and it only turns on its own kind",
		_param_default(by_id, "RetaliateAgainstAttacker", "group"), "\"enemies\"") and ok
	ok = _check("a pickup goes away, waits and comes back",
		_template(by_id, "RespawnAfter"), "\n".join(PackedStringArray([
			"hide()",
			"set_deferred(\"monitoring\", false)",
			"await get_tree().create_timer({seconds}).timeout",
			"show()",
			"set_deferred(\"monitoring\", true)"
		]))) and ok
	ok = _check("and it stops being collectable while it is gone",
		_template(by_id, "RespawnAfter").contains("set_deferred(\"monitoring\", false)"), true) and ok
	ok = _check("Respawn After belongs to a pickup",
		str((by_id.get("RespawnAfter") as ACEDescriptor).node_type), "Area3D") and ok
	var alert_event: EventRow = EventRow.new()
	alert_event.trigger_provider_id = "Core"
	alert_event.trigger_id = "OnAlerted"
	var resolved: Dictionary = TriggerResolver.resolve_trigger(alert_event)
	ok = _check("On Alerted compiles to the function the alert calls",
		str(resolved.get("function_name", "")), "alerted") and ok
	ok = _check("with who to go for as its argument",
		str(resolved.get("args", "")), "who: Variant") and ok
	ok = _check("an opened enemy script reads that handler as the trigger",
		str(EventSheetACELifter.LIFECYCLE_TRIGGERS.get(
			"func alerted(who: Variant) -> void:", "")), "OnAlerted") and ok
	return ok


## Y16 / Y17 / Y18. The showcase, as the LINES the four sheets emit. These are the spellings the
## readings recognise and the rows write, so a reading that stops matching one and a builder that
## starts writing a different one both land here.
static func _showcase_sheets() -> bool:
	var ok: bool = true
	var level: String = FileAccess.get_file_as_string("res://demo/showcase/boomer_level/boomer_level.gd")
	var door: String = FileAccess.get_file_as_string("res://demo/showcase/boomer_level/keycard_door.gd")
	var grunt: String = FileAccess.get_file_as_string("res://demo/showcase/boomer_level/grunt.gd")
	var pickup: String = FileAccess.get_file_as_string("res://demo/showcase/boomer_level/health_pickup.gd")
	ok = _check("the level picks the card up as a key", level.contains("\tkeys.append(\"red_key\")"), true) and ok
	ok = _check("and tries the door with the list it carries",
		level.contains("\tif str(__door_level.needs_key) in keys:"), true) and ok
	ok = _check("the weapon bobs and sways through the pack's own rows",
		level.contains("\t$Player/FPSController.bob_with_movement($Player/Head/Weapon)") \
			and level.contains("\t$Player/FPSController.sway_with_mouse($Player/Head/Weapon)"), true) and ok
	ok = _check("the tally reads every number in the shipped words",
		level.contains("$HudLayer/Tally.text = \"Kills %d of %d   Secrets %d of %d   Time %s of %s\" % [kills, enemies_total, secrets_found.size(), secrets_total, (\"%02d:%02d\" % [int(level_seconds) / 60, int(level_seconds) % 60]), (\"%02d:%02d\" % [int(par_seconds) / 60, int(par_seconds) % 60])]"), true) and ok
	ok = _check("the door answers the trigger Try Door raises",
		door.contains("func locked_door_tried(key: Variant) -> void:"), true) and ok
	ok = _check("and opens once", door.contains("\tif not door_open:"), true) and ok
	ok = _check("a hurt grunt shouts to the room about itself",
		grunt.contains("\t\t\t__alerted_hurt.alerted(self)"), true) and ok
	ok = _check("and nobody is alerted about themselves",
		grunt.contains("__alerted_hurt != self"), true) and ok
	ok = _check("an alerted grunt turns on its own kind",
		grunt.contains("func alerted(who: Variant) -> void:\n\tif who.is_in_group(\"enemies\"):\n\t\ttarget = who"), true) and ok
	ok = _check("the pickup comes back on its own timer",
		pickup.contains("\tawait get_tree().create_timer(respawn_seconds).timeout"), true) and ok
	ok = _check("nothing in the showcase ships an unbaked row id",
		level.contains("{uid}") or door.contains("{uid}") or grunt.contains("{uid}"), false) and ok
	# The grunts have to BE in the group the alert walks, or the whole item silently does nothing.
	ok = _check("the grunts keep their group in the packed scene",
		FileAccess.get_file_as_string("res://demo/showcase/boomer_level/boomer_level.tscn").count(
			"groups=[\"enemies\"]"), 2) and ok
	return ok


## The reading of one STATEMENT as one flat sentence, so a test can pin the words a reader sees.
static func _says(code: String) -> String:
	return _flatten(EventSheetSentence.statement(code, {}))


## The reading of one CONDITION as one flat sentence.
static func _asks(expression: String) -> String:
	return _flatten(EventSheetSentence.condition(expression, {}))


static func _flatten(reading: Dictionary) -> String:
	var text: String = ""
	for segment: Variant in reading.get("segments", []):
		text += str((segment as Dictionary).get("text", ""))
	return text.strip_edges()


static func _descriptors() -> Dictionary:
	var by_id: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[str(descriptor.ace_id)] = descriptor
	return by_id


static func _template(by_id: Dictionary, ace_id: String) -> String:
	var descriptor: ACEDescriptor = by_id.get(ace_id) as ACEDescriptor
	return "" if descriptor == null else str(descriptor.codegen_template)


static func _param_default(by_id: Dictionary, ace_id: String, param_id: String) -> String:
	var descriptor: ACEDescriptor = by_id.get(ace_id) as ACEDescriptor
	if descriptor == null:
		return ""
	for parameter: ACEParam in descriptor.params:
		if str(parameter.id) == param_id:
			return str(parameter.default_value)
	return ""


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] keys_doors_and_boomer_feel_test: %s" % label)
		return true
	print("[FAIL] keys_doors_and_boomer_feel_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
