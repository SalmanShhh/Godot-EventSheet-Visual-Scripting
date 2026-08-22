@tool
class_name SecretObjectsAndStatsScreenTest
extends RefCounted

# Pins the four X25 leftovers - the pieces of the boomer-shooter shape that were named but not built:
#
#   A  the FPS Controller's firing slowdown: an exported firing speed, a window a weapon opens, and
#      the tick's speed line folding it in without touching Set Move Speed
#   B  the end-of-level stats screen starter - kills, secrets and time reaching a named panel
#      through the shipped HUD Kit rows, and nothing wired by hand
#   C  the writable `secret` mark on an Area, and the counting event a drop then offers
#   D  the Boomer Arsenal starter's ammo as a TABLE - an Array of records read with the shipped
#      Row Where word instead of a Dictionary keyed by weapon name
#
# Everything here pins VALUES: the exact emitted line, the exact record shape, the exact template.


static func run() -> bool:
	var ok: bool = true
	ok = _firing_slowdown() and ok
	ok = _stats_screen_starter() and ok
	ok = _secret_mark() and ok
	ok = _ammo_table() and ok
	return ok


## A. The pack's shipped source is the contract, so the assertions read it rather than the builder.
static func _firing_slowdown() -> bool:
	var ok: bool = true
	var source: String = FileAccess.get_file_as_string(
		"res://eventsheet_addons/fps_controller/fps_controller_behavior.gd")
	ok = _check("the firing speed is an exported knob",
		source.contains("@export var firing_move_speed: float = 2.5"), true) and ok
	ok = _check("the firing window is private state",
		source.contains("var _firing_timer: float = 0.0"), true) and ok
	ok = _check("the tick picks the firing speed while the window is open",
		source.contains("var base_speed := firing_move_speed if _firing_timer > 0.0 else move_speed"), true) and ok
	ok = _check("sprint and crouch still multiply it",
		source.contains("var speed := base_speed * (sprint_multiplier if sprint_held else 1.0) * (crouch_speed_multiplier if crouching else 1.0)"), true) and ok
	ok = _check("the window closes on its own",
		source.contains("_firing_timer = maxf(_firing_timer - delta, 0.0)"), true) and ok
	ok = _check("the new row is one droppable action",
		source.contains("func set_move_speed_while_firing(speed: float, seconds: float) -> void:"), true) and ok
	ok = _check("its template is the row a sheet writes",
		source.contains("## @ace_codegen_template(\"$FPSController.set_move_speed_while_firing({speed}, {seconds})\")"), true) and ok
	ok = _check("the firing state reads back as a condition",
		source.contains("func is_firing() -> bool:"), true) and ok
	# The frozen neighbour: adding a row must not have retemplated the one that shipped.
	ok = _check("Set Move Speed is untouched",
		source.contains("## @ace_codegen_template(\"$FPSController.set_move_speed({value})\")"), true) and ok
	return ok


## B. The stats screen starter: the kind of script it is, the numbers it binds, and the fact that it
## compiles. A starter is the first thing a newcomer compiles, so one that does not parse is worse
## than no starter at all.
static func _stats_screen_starter() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetStarterTemplates.build_starter(32)
	ok = _check("the stats screen is a screen", sheet.host_class, "Control") and ok
	ok = _check("it names itself", sheet.custom_class_name, "LevelStatsScreen") and ok
	ok = _check("par is the designer's knob",
		float((sheet.variables.get("par_seconds", {}) as Dictionary).get("default", -1.0)), 180.0) and ok
	ok = _check("the secrets total is the designer's knob",
		int((sheet.variables.get("secrets_total", {}) as Dictionary).get("default", -1)), 3) and ok
	var built: String = str(SheetCompiler.compile(sheet, "user://x25_stats_screen.gd").get("output", ""))
	var script: GDScript = GDScript.new()
	script.source_code = built
	ok = _check("the stats screen starter compiles to GDScript that parses", script.reload(), OK) and ok
	# Every number reaches the screen through a shipped HUD Kit row, by NAME, with no wiring.
	ok = _check("the panel is flipped by the shipped Switch Screen row",
		built.contains("$HudKitBehavior.switch_screen(\"StatsScreen\")"), true) and ok
	ok = _check("kills reach a named label",
		built.contains("$HudKitBehavior.set_text(\"KillsValue\", str(kills))"), true) and ok
	ok = _check("secrets are counted with the shipped Secrets Found word",
		built.contains("$HudKitBehavior.set_text(\"SecretsValue\", \"%d of %d\" % [secrets_found.size(), secrets_total])"), true) and ok
	ok = _check("the time is the shipped mm:ss word, against par",
		built.contains("(\"%02d:%02d\" % [int(level_seconds) / 60, int(level_seconds) % 60]) + \" of \" + (\"%02d:%02d\" % [int(par_seconds) / 60, int(par_seconds) % 60])"), true) and ok
	ok = _check("the secrets bar is filled by the shipped Set Bar row",
		built.contains("$HudKitBehavior.set_bar(\"SecretsBar\", float(secrets_found.size()), float(secrets_total))"), true) and ok
	ok = _check("the button is answered through the pack's one trigger",
		built.contains("get_node(\"HudKitBehavior\").on_button_pressed.connect(_on_hudkitbehavior_on_button_pressed)"), true) and ok
	ok = _check("and named rather than connected",
		built.contains("if $HudKitBehavior.button_is(\"ContinueButton\"):"), true) and ok
	return ok


## C. The mark is writable, it is remembered, it is offered only where it means something, and the
## event it offers is the shipped counting row on the object's own walked-into trigger.
static func _secret_mark() -> bool:
	var ok: bool = true
	EventSheetObjectProperties.reset_secret_flags_for_tests()
	var area: Dictionary = {"label": "SecretRoom", "class": "Area3D", "kind": "node",
		"path": "SecretRoom", "rows": 1, "verbs": PackedStringArray()}
	var timer: Dictionary = {"label": "Clock", "class": "Timer", "kind": "node",
		"path": "Clock", "rows": 1, "verbs": PackedStringArray()}
	ok = _check("an area can be a secret", EventSheetObjectProperties.can_be_secret(area), true) and ok
	ok = _check("a timer cannot", EventSheetObjectProperties.can_be_secret(timer), false) and ok
	ok = _check("nothing is a secret until it is marked",
		EventSheetObjectProperties.is_secret("res://level.gd", "SecretRoom"), false) and ok
	EventSheetObjectProperties.set_secret("res://level.gd", "SecretRoom", true)
	ok = _check("marking it sticks",
		EventSheetObjectProperties.is_secret("res://level.gd", "SecretRoom"), true) and ok
	ok = _check("the mark belongs to the file that made it",
		EventSheetObjectProperties.is_secret("res://other.gd", "SecretRoom"), false) and ok
	# The panel offers the mark as a WRITABLE row, and says what ticking it does. An area carries a
	# second tick beside it (Y11's water mark), so the row is picked by the mark it writes.
	var secret_row: Dictionary = {}
	for row: Dictionary in EventSheetObjectProperties.property_rows(area, "", "res://level.gd"):
		if str(row.get("mark", "")) == "secret":
			secret_row = row
	ok = _check("the popup offers the mark as a tick box",
		str(secret_row.get("label", "")), "Secret") and ok
	ok = _check("ticked, it reads back as ticked", bool(secret_row.get("checked", false)), true) and ok
	ok = _check("the tick knows which object it is about",
		str(secret_row.get("object", "")), "SecretRoom") and ok
	EventSheetObjectProperties.set_secret("res://level.gd", "SecretRoom", false)
	ok = _check("unmarking it sticks too",
		EventSheetObjectProperties.is_secret("res://level.gd", "SecretRoom"), false) and ok
	# The event the drop then offers.
	var offered: EventRow = EventSheetStarterEvents.secret_counter_event("SecretRoom", "Area3D")
	ok = _check("it rides the object's own walked-into trigger",
		offered.trigger_id, "OnBodyEntered") and ok
	ok = _check("and points at the object that was dropped",
		offered.trigger_source_path, "SecretRoom") and ok
	ok = _check("its one action is the shipped counting row",
		str((offered.actions[0] as ACEAction).ace_id), "MarkSecretFound") and ok
	ok = _check("which counts this secret by name into the shared list",
		(offered.actions[0] as ACEAction).params,
		{"name": "\"SecretRoom\"", "found": "secrets_found"}) and ok
	ok = _check("the counting row's template is the shipped one, not a retyped copy",
		EventSheetStarterEvents.secret_counter_template(),
		"if not {name} in {found}:\n\t{found}.append({name})") and ok
	ok = _check("the list it counts into is an array that starts empty",
		EventSheetStarterEvents.secrets_variable_entry().get("default"), []) and ok
	return ok


## D. The arsenal's ammo is a table: an Array of records with a weapon column and a rounds column,
## read with the shipped Row Where word. Spending a round writes back into the table because Row
## Where hands back the record itself.
static func _ammo_table() -> bool:
	var ok: bool = true
	var arsenal: EventSheetResource = EventSheetStarterTemplates.build_starter(30)
	ok = _check("the arsenal starter is still a body that moves", arsenal.host_class, "CharacterBody3D") and ok
	var ammo: Dictionary = arsenal.variables.get("ammo", {})
	ok = _check("ammo is a table, not a keyed dictionary", str(ammo.get("type", "")), "Array") and ok
	ok = _check("with one record per weapon, a name column and a rounds column",
		ammo.get("default"), [
			{"weapon": "shotgun", "rounds": 30},
			{"weapon": "rifle", "rounds": 90},
			{"weapon": "launcher", "rounds": 8}
		]) and ok
	ok = _check("and it is still the designer's to retune", bool(ammo.get("exported", false)), true) and ok
	var built: String = str(SheetCompiler.compile(arsenal, "user://x25_arsenal.gd").get("output", ""))
	var script: GDScript = GDScript.new()
	script.source_code = built
	ok = _check("the arsenal starter still compiles to GDScript that parses", script.reload(), OK) and ok
	ok = _check("the record is found with the shipped Row Where word",
		built.contains("current_ammo = ammo.reduce(func(__found, __record): return __found if not __found.is_empty() else (__record if str(__record.get(\"weapon\", \"\")) == str(weapons[weapon_index]) else __found), {})"), true) and ok
	ok = _check("and the round is spent on the record it found",
		built.contains("\t\tif int(current_ammo.get(\"rounds\", 0)) > 0:\n\t\t\tcurrent_ammo[\"rounds\"] = int(current_ammo[\"rounds\"]) - 1"), true) and ok
	ok = _check("nothing looks ammo up by weapon name any more",
		built.contains("ammo.get(weapons[weapon_index]"), false) and ok
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] secret_objects_and_stats_screen_test: %s" % label)
		return true
	print("[FAIL] secret_objects_and_stats_screen_test: %s - expected %s, got %s" % [label, expected, actual])
	return false
