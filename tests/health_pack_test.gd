# Godot EventSheets - the Health pack, driven for real.
#
# Two things are proved here, and both by RUNNING the shipped pack rather than by reading it:
#
#   1. THE POOLS. The named pools (shields/armour) were untyped Dictionary entries read via float()
#      casts at ~20 sites; they are now a typed HealthPool inner class. The real absorption, decay
#      and death paths are driven to prove the inner class emits and parses, and that absorption,
#      decay and death behave exactly as they did.
#   2. THE TYPED PIPELINE. Take Damage Of Type runs resistance, then armour, then the critical, then
#      the pools and health - IN THAT ORDER - and the order is the whole feature, so it is pinned by
#      ARITHMETIC rather than by reading the emitted text: 12 fire against 50% resistance, 3 armour
#      and a certain x2 critical is 6, and no other order of those three gives 6. Immunity, weakness
#      and the minimum-damage floor are each one hit with one expected number, and the report the
#      row leaves behind (type, dealt, before mitigation, crit) is read back through the shipped
#      expressions rather than off the members.
#
# THE FROZEN ROW IS ASSERTED TOO: plain Take Damage still lowers health by exactly what it is given,
# because the typed row is a layer in front of it and must never have changed it.
#
# The type set is checked the same way: the shipped starter file is read and its four kinds and
# their colours answered by the shipped class, since a starter nobody can read is not a starter.
#
# Values are pinned, never counts.
@tool
class_name HealthPackTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PACK := "res://eventsheet_addons/health/health_behavior.gd"

## The damage-type set and its one starter file, and the Doctor section that compares what a project
## deals against what it has written down. All three loaded BY PATH so the test does not wait on the
## editor class cache having been regenerated for a newly added file.
const TYPE_SET_PACK := "res://eventsheet_addons/damage_type_set_resource/damage_type_set.gd"
const TYPE_SET_STARTER := "res://eventsheet_addons/damage_type_set_resource/damage_types.tres"
const DAMAGE_DOCTOR := "res://addons/eventforge/damage_doctor.gd"


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("health pack loads + parses (HealthPool inner class emits)", script != null, true) and all_passed
	if script == null:
		return all_passed

	var h: Node = script.new()  # no _ready (not in tree): current_health stays at its literal default 100
	all_passed = _check("starts at full health", h.current_health_value(), 100.0) and all_passed

	h.take_damage(30.0)
	all_passed = _check("plain damage lowers HP", h.current_health_value(), 70.0) and all_passed
	all_passed = _check("not dead after a light hit", h.is_dead(), false) and all_passed

	# A shield pool absorbs before real HP.
	h.add_health_pool("shield", 50.0)
	all_passed = _check("pool registered (typed)", h.has_health_pool("shield") and h.health_pool_value("shield") == 50.0, true) and all_passed
	h.take_damage(20.0)
	all_passed = _check("pool soaks the hit, HP untouched", h.current_health_value(), 70.0) and all_passed
	all_passed = _check("pool drained by the absorbed amount", h.health_pool_value("shield"), 30.0) and all_passed
	h.take_damage(40.0)
	all_passed = _check("pool depletes then overflow hits HP", h.health_pool_value("shield") == 0.0 and h.current_health_value() == 60.0, true) and all_passed

	# Pool decay over time (the OnProcess tick).
	h.setup_health_pool("armor", 10.0, 5.0, 1.0, 1.0)  # amount 10, decay 5/s
	h._process(1.0)
	all_passed = _check("pool decays per second", h.health_pool_value("armor"), 5.0) and all_passed

	# Death.
	h.take_damage(100.0)
	all_passed = _check("lethal damage kills + zeroes HP", h.is_dead() == true and h.current_health_value() == 0.0, true) and all_passed

	# Revive restores.
	h.revive(0.0)
	all_passed = _check("revive clears death + refills", h.is_dead() == false and h.current_health_value() == 100.0, true) and all_passed

	h.free()
	all_passed = _the_typed_pipeline_runs_in_its_fixed_order() and all_passed
	all_passed = _immunity_weakness_and_the_minimum() and all_passed
	all_passed = _the_type_set_reads_its_own_starter() and all_passed
	all_passed = _the_doctor_sees_both_disagreements() and all_passed
	all_passed = _a_handwritten_typed_hit_comes_back_byte_for_byte() and all_passed
	return all_passed


## THE ORDER, BY ARITHMETIC. 12 of fire, resisted by half, 3 points of armour, and a critical that
## is certain and doubles: 12 -> 6 -> 3 -> 6. Armour before the resistance would give 4.5; the
## critical before the armour would give 9; the armour after the critical would give 3. Only the
## shipped order gives 6, which is why one number is a better gate here than any amount of reading.
##
## The report is read back through the SHIPPED expressions, because those are what a sheet asks with.
static func _the_typed_pipeline_runs_in_its_fixed_order() -> bool:
	var script: GDScript = load(PACK)
	var h: Node = script.new()
	h.set("max_health", 100.0)
	h.set("current_health", 100.0)
	h.call("resist", "fire", 50.0)
	h.call("set_armour", 3.0)
	h.call("set_crit", 1.0, 2.0)
	h.call("take_typed_damage", 12.0, "fire", null)
	var passed: bool = SUPPORT.pins("health_pack_test", [
		["12 fire, resisted 50, armour 3, crit x2 lands for 6",
			h.call("last_damage_dealt_value"), 6.0],
		["and the health lost is that same 6", h.call("current_health_value"), 94.0],
		["the hit is remembered at its full size too",
			h.call("last_damage_before_mitigation_value"), 12.0],
		["the report names the kind", h.call("last_damage_type_value"), "fire"],
		["the kind is answered as a question as well", h.call("damage_type_is", "fire"), true],
		["and a kind it was not is refused", h.call("damage_type_is", "ice"), false],
		["a certain critical reads as a critical", h.call("last_hit_was_a_crit"), true],
		["the frozen plain row is untouched by any of it",
			_plain_take_damage_still_lowers_by_exactly_what_it_is_given(script), 70.0]
	])
	h.free()
	return passed


## Take Damage, alone, on a fresh node: 30 off 100 is 70, whatever the typed row does in front of it.
static func _plain_take_damage_still_lowers_by_exactly_what_it_is_given(script: GDScript) -> float:
	var h: Node = script.new()
	h.set("max_health", 100.0)
	h.set("current_health", 100.0)
	h.call("take_damage", 30.0)
	var left: float = h.call("current_health_value")
	h.free()
	return left


## The three edges of the pipeline, one hit each: a kind that does nothing at all, a kind that does
## half again, and the floor that stops armour from quietly making a node immortal.
static func _immunity_weakness_and_the_minimum() -> bool:
	var script: GDScript = load(PACK)
	var immune: Node = _fresh(script)
	immune.call("immune_to", "ice")
	immune.call("take_typed_damage", 50.0, "ice", null)
	var weak: Node = _fresh(script)
	weak.call("weak_to", "fire", 100.0)
	weak.call("take_typed_damage", 10.0, "fire", null)
	var walled: Node = _fresh(script)
	walled.call("set_armour", 100.0)
	walled.call("take_typed_damage", 5.0, "physical", null)
	var passed: bool = SUPPORT.pins("health_pack_test", [
		["immunity takes the whole hit away", immune.call("current_health_value"), 100.0],
		["and says so in the report", immune.call("last_damage_dealt_value"), 0.0],
		["but still remembers what was thrown",
			immune.call("last_damage_before_mitigation_value"), 50.0],
		["a doubled weakness turns 10 into 20", weak.call("current_health_value"), 80.0],
		["armour past the whole hit still lets the minimum through",
			walled.call("current_health_value"), 99.0]
	])
	for node: Node in [immune, weak, walled]:
		node.free()
	return passed


## The shipped starter, read by the shipped class: the four kinds it names and the colour of one of
## them. A starter file the class cannot read would be a broken example in every new project.
static func _the_type_set_reads_its_own_starter() -> bool:
	var set_script: GDScript = load(TYPE_SET_PACK)
	if set_script == null:
		return _check("the damage type set pack loads", false, true)
	var starter: Resource = load(TYPE_SET_STARTER)
	if starter == null:
		return _check("the starter set loads", false, true)
	return SUPPORT.pins("health_pack_test", [
		["the starter names the four ordinary kinds",
			Array(starter.get("type_names")), ["physical", "fire", "ice", "poison"]],
		["a kind it names is known", starter.call("has_type", "fire"), true],
		["a kind it does not name is not", starter.call("has_type", "holy"), false],
		["fire is drawn in the colour beside it",
			starter.call("colour_of", "fire"), Color(1.0, 0.45, 0.1, 1.0)],
		["and a kind with no colour is drawn white",
			starter.call("colour_of", "holy"), Color.WHITE]
	])


## The two directions the lists can disagree in, asked of the section's pure report over a corpus of
## two scripts written here - so the wording and the filing are pinned without a project on disk.
static func _the_doctor_sees_both_disagreements() -> bool:
	var doctor: GDScript = load(DAMAGE_DOCTOR)
	if doctor == null:
		return _check("the damage doctor loads", false, true)
	var sources: Array[Dictionary] = [
		{"path": "res://enemy.gd",
			"source": "$Health.take_typed_damage(12.0, \"fier\", self)"},
		{"path": "res://boss.gd", "source": "$Health.resist(\"holy\", 50.0)"}
	]
	var declared: PackedStringArray = PackedStringArray(["physical", "fire"])
	var findings: Array[Dictionary] = doctor.call("report", sources, declared, true)
	var checks: PackedStringArray = PackedStringArray()
	var subjects: PackedStringArray = PackedStringArray()
	for finding: Dictionary in findings:
		checks.append(str(finding["check"]))
		subjects.append(str(finding["subject"]))
	# The same corpus with NOTHING written down: the misspelling can no longer be called one, and
	# only the guard against a kind nothing deals survives.
	var quiet: Array[Dictionary] = doctor.call("report", sources, PackedStringArray(), false)
	var quiet_checks: PackedStringArray = PackedStringArray()
	for finding: Dictionary in quiet:
		quiet_checks.append(str(finding["check"]))
	return SUPPORT.pins("health_pack_test", [
		["the summary leads, then the misspelling, then the guard",
			Array(checks), ["damage", "damage-unknown-type", "damage-guard-against-nothing"]],
		["each finding is about the word itself", Array(subjects), ["", "fier", "holy"]],
		["every one of them is a quiet note", str(findings[1]["severity"]), "info"],
		["a project that has written no set down is not told it misspelled anything",
			Array(quiet_checks), ["damage", "damage-guard-against-nothing"]]
	])


## THE LIFT. A hand-written typed hit is ordinary GDScript, and a file holding one must come back
## byte for byte after being opened as a sheet and saved - the standing contract, asked of the line
## this slice adds.
static func _a_handwritten_typed_hit_comes_back_byte_for_byte() -> bool:
	var source: String = "\n".join(PackedStringArray([
		"extends Node2D",
		"",
		"",
		"func _on_bullet_hit(hit: Node) -> void:",
		"\thit.get_node(\"Health\").take_typed_damage(12.0, \"fire\", self)",
		""
	]))
	return SUPPORT.pins("health_pack_test", [
		["a file with a typed hit in it re-emits byte for byte",
			SUPPORT.reemit(source, "user://eventforge_typed_damage_trip.gd"), source]
	])


## A pack node at full health, ready to be hit once.
static func _fresh(script: GDScript) -> Node:
	var h: Node = script.new()
	h.set("max_health", 100.0)
	h.set("current_health", 100.0)
	return h


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("health_pack_test", label, actual, expected)
