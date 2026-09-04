# Godot EventSheets - the Status Effects pack, driven for real.
#
# The pack is machinery plus files, and both halves are run here rather than read:
#
#   1. THE STACKING RULES, BY VALUE. Refresh, extend and add are the whole difference between the
#      three kinds of effect, they are pure arithmetic on the effect file, and they are asked of the
#      SHIPPED starters - so a starter edited into a rule it does not mean fails here.
#   2. THE TICK, THROUGH A REAL HEALTH BEHAVIOUR. The status node is given a host carrying the
#      shipped Health pack, and the health lost is the number the typed pipeline produces - which is
#      what proves the tick goes through resistances and armour rather than around them.
#   3. CLEANSE AND IMMUNITY. A cleanse with no name takes the cleansable ones and leaves the rest;
#      an immunity takes one off and keeps it off.
#   4. THE TINT COMES BACK OFF. A status tints the host's modulate and the last one leaving puts the
#      original colour back, because a status that leaves a coloured sprite behind is a bug nobody
#      finds until the enemy is orange for the rest of the level.
#   5. SPEED FACTOR IS A PRODUCT, so a slow and a root stack the way multipliers do.
#   6. EVERY STARTER LOADS and answers to its own name - a starter nobody can read is not a starter,
#      and a file whose Status Name disagrees with its file name is found by the name it says,
#      through the folder as well as through the list dropped on the node.
#   7. THE TICK DUE AS A STATUS EXPIRES IS PAID, and a sheet row that ends other statuses from
#      inside a tick handler leaves the frame it interrupted able to finish.
#
# There is no scene tree here, so the tick is driven by hand: `_process(delta)` is called with the
# seconds a frame would have carried, which is exactly what the shipped code does with game time.
#
# Values are pinned, never counts.
@tool
class_name StatusEffectsPackTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

## Everything is loaded BY PATH so the test does not wait on the editor class cache having been
## regenerated for two newly added class names.
const PACK := "res://eventsheet_addons/status_effects/status_effects_behavior.gd"
const EFFECT_RESOURCE := "res://eventsheet_addons/status_effect_resource/status_effect_resource.gd"
const HEALTH_PACK := "res://eventsheet_addons/health/health_behavior.gd"
const EFFECTS_FOLDER := "res://eventsheet_addons/status_effects"
const BOOSTS_PACK := "res://eventsheet_addons/boosts/boosts_addon.gd"

## The two accessibility meta the tint reads. Saved and put back around the tint check, because the
## suite runs serially in one process on CI and a meta left behind is the next test's mystery.
const NO_FLASHING_META: StringName = &"no_flashing"
const EFFECT_STRENGTH_META: StringName = &"effect_strength"


static func run() -> bool:
	var passed: bool = true
	var script: GDScript = load(PACK)
	passed = _check("the status pack loads + parses", script != null, true) and passed
	if script == null:
		return passed
	passed = _the_starters_read_their_own_names() and passed
	passed = _the_three_stacking_rules_by_value() and passed
	passed = _a_tick_goes_through_the_typed_pipeline() and passed
	passed = _cleanse_leaves_what_is_not_cleansable() and passed
	passed = _immunity_takes_it_off_and_keeps_it_off() and passed
	passed = _the_tint_goes_on_and_comes_back_off() and passed
	passed = _speed_factor_is_the_product_of_what_is_on() and passed
	passed = _the_tick_due_at_the_end_is_paid() and passed
	passed = _a_tick_handler_may_end_the_others() and passed
	passed = _a_file_is_found_by_the_name_it_calls_itself() and passed
	passed = _extending_a_status_extends_its_multiplier() and passed
	passed = _a_handwritten_apply_comes_back_byte_for_byte() and passed
	return passed


## The six shipped files, read by the shipped class. Each answers to its own name with nothing typed
## into Status Name beyond the word, and one number of each is pinned so a starter quietly edited
## into a different effect is caught here rather than in somebody's game.
static func _the_starters_read_their_own_names() -> bool:
	var names: PackedStringArray = PackedStringArray()
	var rules: PackedStringArray = PackedStringArray()
	for word: String in ["burn", "freeze", "poison", "shield", "slow", "stun"]:
		var starter: Resource = load("%s/%s.tres" % [EFFECTS_FOLDER, word])
		if starter == null:
			return _check("every starter loads (%s)" % word, false, true)
		names.append(str(starter.call("called")))
		rules.append(str(starter.get("stacking")))
	var burn: Resource = load("%s/burn.tres" % EFFECTS_FOLDER)
	var poison: Resource = load("%s/poison.tres" % EFFECTS_FOLDER)
	var slow: Resource = load("%s/slow.tres" % EFFECTS_FOLDER)
	var shield: Resource = load("%s/shield.tres" % EFFECTS_FOLDER)
	return SUPPORT.pins("status_effects_pack_test", [
		["all six starters answer to their own file names",
			Array(names), ["burn", "freeze", "poison", "shield", "slow", "stun"]],
		["and each one carries the stacking rule it was written with",
			Array(rules), ["refresh", "extend", "add", "refresh", "refresh", "refresh"]],
		["burn ticks fire", str(burn.get("tick_type")), "fire"],
		["and ticks it twice a second", float(burn.get("tick_seconds")), 0.5],
		["poison piles up to five", int(poison.get("max_stacks")), 5],
		["slow halves the speed", float(slow.get("speed_factor")), 0.5],
		["a shield is not what an antidote answers", bool(shield.get("cleansable")), false]
	])


## THE THREE RULES, as arithmetic on the shipped files. Refresh puts the clock back and leaves one
## stack; extend adds the new time to what was left; add piles stacks up to the file's own ceiling.
## No host, no tree and no time are involved, which is the point of keeping the rules on the file.
static func _the_three_stacking_rules_by_value() -> bool:
	var burn: Resource = load("%s/burn.tres" % EFFECTS_FOLDER)
	var freeze: Resource = load("%s/freeze.tres" % EFFECTS_FOLDER)
	var poison: Resource = load("%s/poison.tres" % EFFECTS_FOLDER)
	return SUPPORT.pins("status_effects_pack_test", [
		["refresh puts the clock back to the new time", burn.call("seconds_after", 2.0, 3.0), 3.0],
		["and leaves a one-stack effect on one stack", burn.call("stacks_after", 1, 1), 1],
		["extend adds the new time to what was left", freeze.call("seconds_after", 2.0, 3.0), 5.0],
		["add piles the stacks up", poison.call("stacks_after", 2, 1), 3],
		["but never past the file's own ceiling", poison.call("stacks_after", 4, 3), 5],
		["and still refreshes the clock", poison.call("seconds_after", 2.0, 3.0), 3.0]
	])


## THE TICK. A burn on a host carrying the shipped Health pack: half a second later the host has
## lost exactly what the typed pipeline makes of two points of fire, and the damage report names the
## kind - which is what proves the tick went THROUGH the pipeline rather than around it. Then the
## same tick under five stacks of poison, to pin that stacks multiply what a tick is worth.
static func _a_tick_goes_through_the_typed_pipeline() -> bool:
	var burning: Dictionary = _host_with_health()
	var status: Node = burning["status"]
	var health: Node = burning["health"]
	status.call("apply", "burn", 3.0, 1)
	status.call("_process", 0.5)
	var after_one_tick: float = float(health.call("current_health_value"))
	var kind: String = str(health.call("last_damage_type_value"))
	var ticked: int = int(status.call("status_stacks", "burn"))
	var left: float = float(status.call("status_time_left", "burn"))

	var poisoned: Dictionary = _host_with_health()
	var stacked: Node = poisoned["status"]
	for application: int in 3:
		stacked.call("apply", "poison", 4.0, 1)
	stacked.call("_process", 1.0)
	var poison_health: float = float((poisoned["health"] as Node).call("current_health_value"))
	var poison_stacks: int = int(stacked.call("status_stacks", "poison"))
	var listed: Array = stacked.call("active_statuses")

	# A burn told to be resisted by half lands for half, because a tick is an ordinary typed hit.
	var resistant: Dictionary = _host_with_health()
	(resistant["health"] as Node).call("resist", "fire", 50.0)
	(resistant["status"] as Node).call("apply", "burn", 3.0, 1)
	(resistant["status"] as Node).call("_process", 0.5)
	var resisted: float = float((resistant["health"] as Node).call("current_health_value"))

	var passed: bool = SUPPORT.pins("status_effects_pack_test", [
		["two points of fire come off the host's health", after_one_tick, 98.0],
		["and the damage report names the kind the file asked for", kind, "fire"],
		["the status is on one stack", ticked, 1],
		["with the rest of its clock left", left, 2.5],
		["three stacks of poison tick for three", poison_health, 97.0],
		["because the stacks added up", poison_stacks, 3],
		["and the node lists what is on it", listed, ["poison"]],
		["a resisted kind ticks for half", resisted, 99.0]
	])
	for made: Dictionary in [burning, poisoned, resistant]:
		(made["host"] as Node).free()
	return passed


## A cleanse with no name takes off everything the files say may be cleansed, and leaves the shield,
## whose file says it may not. A cleanse that names one takes that one only.
static func _cleanse_leaves_what_is_not_cleansable() -> bool:
	var made: Dictionary = _host_with_health()
	var status: Node = made["status"]
	status.call("apply", "poison", 5.0, 1)
	status.call("apply", "burn", 5.0, 1)
	status.call("apply", "shield", 5.0, 1)
	status.call("cleanse", "burn")
	var after_named: Array = status.call("active_statuses")
	# A CLEANSE THAT NAMES THE CURSE IS STILL A CLEANSE. What makes the shield survive an antidote
	# is its own file saying so, and that has to be true whether the antidote named it or not - or
	# Cleanse and Remove Status would be the same row the moment a name is typed into it.
	status.call("cleanse", "shield")
	var shield_after_named_cleanse: bool = status.call("has", "shield")
	status.call("cleanse", "")
	var after_all: Array = status.call("active_statuses")
	var shield_survived: bool = status.call("has", "shield")
	var poison_gone: bool = status.call("has", "poison")
	# Remove Status is the row that takes it off regardless, which is the whole difference.
	status.call("remove_status", "shield")
	var shield_after_remove: bool = status.call("has", "shield")
	var passed: bool = SUPPORT.pins("status_effects_pack_test", [
		["a named cleanse takes that one only", after_named, ["poison", "shield"]],
		["a named cleanse still leaves what may not be cleansed",
			shield_after_named_cleanse, true],
		["a cleanse with no name takes every cleansable one", after_all, ["shield"]],
		["and the shield is still on", shield_survived, true],
		["while the poison is not", poison_gone, false],
		["Remove Status takes it off all the same", shield_after_remove, false]
	])
	(made["host"] as Node).free()
	return passed


## An immunity takes the status off if it is already on, and refuses the next application of it -
## an immunity you have to wait out is not one.
static func _immunity_takes_it_off_and_keeps_it_off() -> bool:
	var made: Dictionary = _host_with_health()
	var status: Node = made["status"]
	status.call("apply", "poison", 5.0, 1)
	status.call("make_immune", "poison", 4.0)
	var straight_after: bool = status.call("has", "poison")
	status.call("apply", "poison", 5.0, 1)
	var still_refused: bool = status.call("has", "poison")
	# Four seconds of game time later the immunity is spent and the poison lands again.
	status.call("_process", 4.5)
	status.call("apply", "poison", 5.0, 1)
	var passed: bool = SUPPORT.pins("status_effects_pack_test", [
		["the immunity takes the status straight off", straight_after, false],
		["and refuses it while it lasts", still_refused, false],
		["once it is spent, the status lands again", status.call("has", "poison"), true],
		["and a status that never landed has no time on it",
			status.call("status_time_left", "burn"), 0.0]
	])
	(made["host"] as Node).free()
	return passed


## THE TINT, ON AND OFF. Burn tints the host and the last status leaving puts the original colour
## back. The two accessibility meta are pinned around this so the check reads the same on a machine
## where an earlier test set them, and put back exactly as they were found.
static func _the_tint_goes_on_and_comes_back_off() -> bool:
	var had_no_flashing: bool = Engine.has_meta(NO_FLASHING_META)
	var had_strength: bool = Engine.has_meta(EFFECT_STRENGTH_META)
	var old_no_flashing: Variant = Engine.get_meta(NO_FLASHING_META) if had_no_flashing else null
	var old_strength: Variant = Engine.get_meta(EFFECT_STRENGTH_META) if had_strength else null
	Engine.set_meta(NO_FLASHING_META, false)
	Engine.set_meta(EFFECT_STRENGTH_META, 1.0)

	var made: Dictionary = _host_with_health()
	var status: Node = made["status"]
	var host: Node2D = made["host"]
	var before: Color = host.modulate
	status.call("apply", "burn", 1.0, 1)
	var tinted: Color = host.modulate
	status.call("remove_status", "burn")
	var restored: Color = host.modulate

	# And the same tint under a player who has asked for no flashing: the colour still moves, but
	# only as far as the ceiling the screen effects use, so nothing here can flicker.
	Engine.set_meta(NO_FLASHING_META, true)
	status.call("apply", "burn", 1.0, 1)
	var held: Color = host.modulate

	var passed: bool = SUPPORT.pins("status_effects_pack_test", [
		["the host starts its own colour", before, Color(1.0, 1.0, 1.0, 1.0)],
		# CHANNEL BY CHANNEL, and approximately: the tint is a lerp, and a lerp that lands on its
		# far end still lands one float32 step off it - 1 + (0.35 - 1) is not 0.35 in single
		# precision. What is being asserted is the colour, not the last bit of it.
		["a burn tints it the colour its file names",
			[is_equal_approx(tinted.r, 1.0), is_equal_approx(tinted.g, 0.62),
				is_equal_approx(tinted.b, 0.35)], [true, true, true]],
		["and the last status leaving puts the colour back", restored, Color(1.0, 1.0, 1.0, 1.0)],
		["no flashing holds the shift under the ceiling",
			is_equal_approx(held.g, 1.0 - 0.38 * 0.3), true]
	])
	host.free()
	if had_no_flashing:
		Engine.set_meta(NO_FLASHING_META, old_no_flashing)
	else:
		Engine.remove_meta(NO_FLASHING_META)
	if had_strength:
		Engine.set_meta(EFFECT_STRENGTH_META, old_strength)
	else:
		Engine.remove_meta(EFFECT_STRENGTH_META)
	return passed


## Speed Factor multiplies, so a slow and a root are a root, and nothing at all is 1.
static func _speed_factor_is_the_product_of_what_is_on() -> bool:
	var made: Dictionary = _host_with_health()
	var status: Node = made["status"]
	var nothing_on: float = float(status.call("speed_factor"))
	status.call("apply", "slow", 5.0, 1)
	var slowed: float = float(status.call("speed_factor"))
	status.call("apply", "shield", 5.0, 1)
	var still_slowed: float = float(status.call("speed_factor"))
	status.call("apply", "freeze", 5.0, 1)
	var rooted: float = float(status.call("speed_factor"))
	status.call("remove_status", "freeze")
	status.call("remove_status", "slow")
	var passed: bool = SUPPORT.pins("status_effects_pack_test", [
		["nothing on is full speed", nothing_on, 1.0],
		["one slow halves it", slowed, 0.5],
		["an effect with no opinion about speed changes nothing", still_slowed, 0.5],
		["and a root takes it to nothing", rooted, 0.0],
		["taking them off gives the speed back", float(status.call("speed_factor")), 1.0],
		["an icon nobody drew reads as nothing", status.call("status_icon", "shield"), null]
	])
	(made["host"] as Node).free()
	return passed


## THE TICK DUE AS THE CLOCK RUNS OUT IS PAID. A one-second burn ticking twice a second is two
## ticks - one at the half, one as it goes out - and the second of those falls exactly on the
## expiry, which an ordinary "while there is time left" would drop. Two frames of half a second are
## the frames a game actually runs, so those are the frames it is asked with.
static func _the_tick_due_at_the_end_is_paid() -> bool:
	var made: Dictionary = _host_with_health()
	var status: Node = made["status"]
	var health: Node = made["health"]
	status.call("apply", "burn", 1.0, 1)
	status.call("_process", 0.5)
	var after_first: float = float(health.call("current_health_value"))
	status.call("_process", 0.5)
	var passed: bool = SUPPORT.pins("status_effects_pack_test", [
		["the tick at the half second lands", after_first, 98.0],
		["the tick due exactly as it expires lands too",
			health.call("current_health_value"), 96.0],
		["and the status is over", status.call("has", "burn"), false]
	])
	(made["host"] as Node).free()
	return passed


## A HANDLER THAT ENDS OTHER STATUSES MID-TICK. The words being ticked are a list taken before the
## first one ran, and a sheet row under On Status Ticked may cleanse everything - so the loop has to
## ask whether each word is still on rather than trusting the list. Without that, the frame after an
## antidote fired from a tick handler read a key that was no longer there.
static func _a_tick_handler_may_end_the_others() -> bool:
	var made: Dictionary = _host_with_health()
	var status: Node = made["status"]
	status.call("apply", "burn", 3.0, 1)
	status.call("apply", "poison", 3.0, 1)
	status.connect("status_ticked", func(_status: String, _stacks: int) -> void:
		status.call("cleanse", ""))
	status.call("_process", 0.6)
	var passed: bool = SUPPORT.pins("status_effects_pack_test", [
		["the tick handler's cleanse took everything with it",
			status.call("active_statuses"), []],
		["and the frame after it is quiet", status.call("has", "burn"), false]
	])
	(made["host"] as Node).free()
	return passed


## AN EFFECT ANSWERS TO WHAT IT CALLS ITSELF, through either door. A file named one thing whose
## Status Name says another is found by the name it says - the folder is asked the same question the
## dropped list is - so renaming a file and filling in a Status Name cannot leave a status that one
## row can apply and another cannot find. Written into user:// because the point is a file whose two
## names DISAGREE, and no starter does.
static func _a_file_is_found_by_the_name_it_calls_itself() -> bool:
	var folder: String = "user://eventforge_status_naming"
	DirAccess.make_dir_recursive_absolute(folder)
	var written: FileAccess = FileAccess.open(folder + "/curse.tres", FileAccess.WRITE)
	if written == null:
		return _check("the disagreeing file can be written", false, true)
	written.store_string("\n".join(PackedStringArray([
		"[gd_resource type=\"Resource\" script_class=\"StatusEffectResource\" load_steps=2 format=3]",
		"",
		"[ext_resource type=\"Script\" path=\"%s\" id=\"1_status_effect\"]" % EFFECT_RESOURCE,
		"",
		"[resource]",
		"script = ExtResource(\"1_status_effect\")",
		"status_name = \"hex\"",
		"tick_amount = 3.0",
		"tick_seconds = 0.5",
		""
	])))
	written.close()
	var made: Dictionary = _host_with_health()
	var status: Node = made["status"]
	status.set("effects_folder", folder)
	status.call("apply", "hex", 1.0, 1)
	status.call("_process", 0.5)
	var passed: bool = SUPPORT.pins("status_effects_pack_test", [
		["a file found by its Status Name ticks for what that file says",
			(made["health"] as Node).call("current_health_value"), 97.0],
		["and the word it is on is the one the row applied",
			status.call("active_statuses"), ["hex"]],
		["while the file's own name is nobody's status",
			status.call("has", "curse"), false]
	])
	(made["host"] as Node).free()
	DirAccess.remove_absolute(folder + "/curse.tres")
	DirAccess.remove_absolute(folder)
	return passed


## EXTENDING A STATUS EXTENDS THE MULTIPLIER IT STARTED. A shield extended by five seconds whose
## defence boost still ran out at the old time would leave Has Status saying shield while the shield
## did nothing. The Boosts pack is an autoload, so this half is pinned in the emitted text: there is
## no scene tree here for the status node to find one in, and what would be measured otherwise is
## the absence of the autoload rather than the row.
static func _extending_a_status_extends_its_multiplier() -> bool:
	var pack: String = FileAccess.get_file_as_string(PACK)
	var boosts: String = FileAccess.get_file_as_string(BOOSTS_PACK)
	return SUPPORT.pins("status_effects_pack_test", [
		["the status clock is extended", pack.contains("entry[\"remaining\"] = float(entry[\"remaining\"]) + maxf(seconds, 0.0)"), true],
		["and the boost it started is extended with it",
			pack.contains("boosts.call(\"extend_boost\", _boost_id(status), maxf(seconds, 0.0))"), true],
		["by the same seconds, through the row the Boosts pack ships for it",
			boosts.contains("func extend_boost(id: String, seconds: float) -> void:"), true]
	])


## THE LIFT. A hand-written apply is ordinary GDScript, and a file holding one must come back byte
## for byte after being opened as a sheet and saved - the standing contract, asked of this pack's
## own line.
static func _a_handwritten_apply_comes_back_byte_for_byte() -> bool:
	var source: String = "\n".join(PackedStringArray([
		"extends Node2D",
		"",
		"",
		"func _on_flame_touched() -> void:",
		"\t$Status.apply(\"burn\", 3.0, 1)",
		""
	]))
	return SUPPORT.pins("status_effects_pack_test", [
		["a file with an Apply Status in it re-emits byte for byte",
			SUPPORT.reemit(source, "user://eventforge_status_apply_trip.gd"), source]
	])


## A host carrying the shipped Health pack and this pack, wired the way an attached behaviour is.
## Nothing is in a scene tree, so `host` is set by hand exactly as `_enter_tree` would set it.
static func _host_with_health() -> Dictionary:
	var host: Node2D = Node2D.new()
	var health: Node = (load(HEALTH_PACK) as GDScript).new()
	health.name = "Health"
	health.set("max_health", 100.0)
	health.set("current_health", 100.0)
	host.add_child(health)
	var status: Node = (load(PACK) as GDScript).new()
	status.name = "Status"
	status.set("host", host)
	status.set("effects_folder", EFFECTS_FOLDER)
	host.add_child(status)
	return {"host": host, "health": health, "status": status}


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("status_effects_pack_test", label, actual, expected)
