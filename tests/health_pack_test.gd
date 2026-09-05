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
const DAMAGE_TYPE_FACTS := "res://addons/eventforge/damage_type_facts.gd"


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
	all_passed = _credit_is_only_taken_for_a_hit_that_landed() and all_passed
	all_passed = _the_type_set_reads_its_own_starter() and all_passed
	all_passed = _the_doctor_sees_both_disagreements() and all_passed
	all_passed = _the_shipped_starter_is_not_the_projects_own_set() and all_passed
	all_passed = _a_handwritten_typed_hit_comes_back_byte_for_byte() and all_passed
	all_passed = _the_difficulty_factor_scales_the_hit() and all_passed
	all_passed = _assists_are_counted_from_the_death() and all_passed
	all_passed = _a_hit_of_no_kind_says_so() and all_passed
	all_passed = _the_two_readings_read_the_lines_projects_write() and all_passed
	return all_passed


## THE SCALED-BY FIELD. A typed hit may name a difficulty factor, and the number it is scaled by
## comes off Engine metadata - which is why this test can write that metadata by hand and needs no
## Settings autoload, no scene tree and no other pack installed. Three hits prove the three answers
## that matter: a factor the difficulty writes, a factor it does not, and a row that named none.
##
## The metadata is put back the way it was found, because a test that left a difficulty in force
## would quietly halve the damage of every test that ran after it.
static func _the_difficulty_factor_scales_the_hit() -> bool:
	var script: GDScript = load(PACK)
	var had: bool = Engine.has_meta("difficulty_factors")
	var before: Variant = Engine.get_meta("difficulty_factors", {})
	Engine.set_meta("difficulty_factors", {"damage_taken": 0.5})
	var halved: Node = _fresh(script)
	halved.call("take_typed_damage", 20.0, "physical", null, "damage_taken")
	var unknown: Node = _fresh(script)
	unknown.call("take_typed_damage", 20.0, "physical", null, "no_such_factor")
	var plain: Node = _fresh(script)
	plain.call("take_typed_damage", 20.0, "physical", null)
	var passed: bool = SUPPORT.pins("health_pack_test", [
		["a named factor of 0.5 halves the hit", halved.call("last_damage_dealt_value"), 10.0],
		["and the report shows the scaled hit, not the number the row was written with",
			halved.call("last_damage_before_mitigation_value"), 10.0],
		["a factor the difficulty has no key for counts as 1",
			unknown.call("last_damage_dealt_value"), 20.0],
		["and a row that named no factor at all is untouched",
			plain.call("last_damage_dealt_value"), 20.0]
	])
	halved.free()
	unknown.free()
	plain.free()
	if had:
		Engine.set_meta("difficulty_factors", before)
	else:
		Engine.remove_meta("difficulty_factors")
	return passed


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
	# THE FLOOR NEVER RAISES A HIT. Minimum Damage exists so armour cannot make a node immortal, so
	# it may only ever put back what ARMOUR took off: a graze past no armour at all, and a hit
	# resistance has already worn down to less than the minimum, both land for exactly what they are.
	var grazed: Node = _fresh(script)
	grazed.call("take_typed_damage", 0.5, "physical", null)
	var worn: Node = _fresh(script)
	worn.call("resist", "fire", 50.0)
	worn.call("take_typed_damage", 1.0, "fire", null)
	var passed: bool = SUPPORT.pins("health_pack_test", [
		["immunity takes the whole hit away", immune.call("current_health_value"), 100.0],
		["and says so in the report", immune.call("last_damage_dealt_value"), 0.0],
		["but still remembers what was thrown",
			immune.call("last_damage_before_mitigation_value"), 50.0],
		["a doubled weakness turns 10 into 20", weak.call("current_health_value"), 80.0],
		["armour past the whole hit still lets the minimum through",
			walled.call("current_health_value"), 99.0],
		["a half-point graze past no armour lands for its half point",
			grazed.call("last_damage_dealt_value"), 0.5],
		["and takes exactly that much health", grazed.call("current_health_value"), 99.5],
		["a hit resistance wore down below the minimum is not put back up",
			worn.call("last_damage_dealt_value"), 0.5]
	])
	for node: Node in [immune, weak, walled, grazed, worn]:
		node.free()
	return passed


## CREDIT IS FOR A HIT THAT LANDED. A boss that turns on whoever hurt it last must not turn on
## somebody whose hit it was immune to, whose hit arrived inside its i-frames, or who hit it while it
## was invulnerable: none of those hurt it. And the source is answered as NOTHING once it has been
## freed, because a row under On Death reads a name off whatever Killer Of hands it.
static func _credit_is_only_taken_for_a_hit_that_landed() -> bool:
	var script: GDScript = load(PACK)
	var ally: Node = Node.new()
	ally.name = "Ally"
	var ghost: Node = Node.new()
	ghost.name = "Ghost"
	var immune: Node = _fresh(script)
	immune.call("immune_to", "fire")
	immune.call("take_damage_from", 5.0, ally)
	immune.call("take_typed_damage", 50.0, "fire", ghost)
	var last_after_immune: Variant = immune.call("last_hit_from_value")
	var refused: Node = _fresh(script)
	refused.set("invulnerable", true)
	refused.call("take_damage_from", 5.0, ally)
	var nobody: Variant = refused.call("last_hit_from_value")
	var orphaned: Node = _fresh(script)
	orphaned.call("take_damage_from", 500.0, ghost)
	var killed_by_the_ghost: bool = orphaned.call("killer_of") == ghost
	ghost.free()
	var passed: bool = SUPPORT.pins("health_pack_test", [
		["a hit the node is immune to does not take the credit",
			last_after_immune == ally, true],
		["and leaves no assist behind either",
			(immune.call("assists_of") as Array).is_empty(), true],
		["a hit refused while invulnerable credits nobody at all", nobody == null, true],
		["the kill is credited while the killer is still there", killed_by_the_ghost, true],
		["and reads as nothing once the killer has gone", orphaned.call("killer_of") == null, true],
		["so does the hit before it", orphaned.call("last_hit_from_value") == null, true]
	])
	for node: Node in [immune, refused, orphaned, ally]:
		node.free()
	return passed


## THE ASSIST WINDOW IS MEASURED FROM THE DEATH. A results screen is read seconds after the kill,
## and a window counted from the moment somebody asks would list nobody by then - so the killing
## hit's own stamp is the moment used. Time cannot be moved in a test, so the stamps are moved
## instead: backdating every hit by nine seconds is the same arithmetic as nine seconds passing.
##
## And the second half: the stamps are not kept for ever. A bullet nobody claimed is its own root
## owner, so every unclaimed projectile that hits leaves a key behind - and once it is freed that
## key is a freed object nothing can be asked about. The next hit lets those go.
static func _assists_are_counted_from_the_death() -> bool:
	var script: GDScript = load(PACK)
	var helper: Node = Node.new()
	helper.name = "Helper"
	var killer: Node = Node.new()
	killer.name = "Killer"
	var victim: Node = _fresh(script)
	victim.set("assist_seconds", 8.0)
	victim.call("take_damage_from", 10.0, helper)
	victim.call("take_damage_from", 500.0, killer)
	var listed_at_the_death: Array = victim.call("assists_of")
	# Nine seconds after the kill, read off a results screen.
	var stamps: Dictionary = victim.get("assist_hits")
	for who: Variant in stamps.keys():
		stamps[who] = int(stamps[who]) - 9000
	var listed_later: Array = victim.call("assists_of")

	# A hit from something that is then freed leaves a key nothing can answer about; the next hit
	# lets it go, and so does a hit older than the window.
	var doomed: Node = Node.new()
	doomed.name = "Doomed"
	var boss: Node = _fresh(script)
	boss.set("max_health", 10000.0)
	boss.set("current_health", 10000.0)
	boss.set("assist_seconds", 8.0)
	boss.call("take_damage_from", 5.0, doomed)
	doomed.free()
	boss.call("take_damage_from", 5.0, helper)
	var boss_stamps: Dictionary = boss.get("assist_hits")
	var freed_keys: bool = false
	for who: Variant in boss_stamps.keys():
		if not is_instance_valid(who):
			freed_keys = true

	var passed: bool = SUPPORT.pins("health_pack_test", [
		["the helper is an assist at the moment of the kill",
			listed_at_the_death == [helper], true],
		["and is still one when the results screen asks nine seconds later",
			listed_later == [helper], true],
		["the killer is never their own assist", listed_later.has(killer), false],
		["a hit from something since freed is not still remembered", freed_keys, false],
		["and the one that is still there is", boss_stamps.has(helper), true]
	])
	for node: Node in [victim, boss, helper, killer]:
		node.free()
	return passed


## THE REPORT IS ABOUT THE HIT THAT JUST LANDED. Take Damage Of Type writes four readings, and
## before this nothing ever cleared them - so one fire critical left Damage Type Is fire and Last
## Hit Was A Crit true under every hit that followed, and a HUD popping "as crit" under On Damaged
## popped it for the rest of the fight. Take Damage From writes the untyped report instead.
##
## Plain Take Damage is FROZEN and can clear nothing, so what it leaves standing is pinned here too:
## it is a number and nothing else, which is what the guide now says of it.
static func _a_hit_of_no_kind_says_so() -> bool:
	var script: GDScript = load(PACK)
	var shooter: Node = Node.new()
	shooter.name = "Shooter"
	var hazard: Node = Node.new()
	hazard.name = "Hazard"
	var victim: Node = _fresh(script)
	victim.set("crit_chance", 1.0)
	victim.set("crit_multiplier", 2.0)
	victim.call("take_typed_damage", 10.0, "fire", shooter, "")
	var was_fire: bool = victim.call("damage_type_is", "fire")
	var was_crit: bool = victim.call("last_hit_was_a_crit")
	victim.call("take_damage_from", 5.0, hazard)
	var still_fire: bool = victim.call("damage_type_is", "fire")
	var still_crit: bool = victim.call("last_hit_was_a_crit")

	# The frozen row, said plainly rather than wished away: it changes the health and nothing else.
	var plain: Node = _fresh(script)
	plain.call("take_typed_damage", 10.0, "ice", shooter, "")
	plain.call("take_damage", 5.0)
	var after_plain_type: String = plain.call("last_damage_type_value")

	var passed: bool = SUPPORT.pins("health_pack_test", [
		["a typed critical reports its kind", was_fire, true],
		["and reports that it was one", was_crit, true],
		["a hit of no kind afterwards is of no kind", still_fire, false],
		["and was not a critical either", still_crit, false],
		["it reports what it was given", victim.call("last_damage_dealt_value"), 5.0],
		["and who dealt it", victim.call("last_hit_from_value") == hazard, true],
		["while plain Take Damage leaves the last report standing", after_plain_type, "ice"]
	])
	for node: Node in [victim, plain, shooter, hazard]:
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
	# THE PACK ITSELF IS NOT A PROJECT DEALING DAMAGE. The pre-read that picks scripts to open is
	# four words, and the behaviour that DEFINES those words says all four - so a corpus of nothing
	# but definitions must report nothing at all, rather than counting the plugin as two scripts.
	var definitions: Array[Dictionary] = [
		{"path": "res://eventsheet_addons/health/health_behavior.gd",
			"source": "func take_typed_damage(amount: float, type: String, from: Node) -> void:\n\tpass\nfunc resist(type: String, percent: float) -> void:\n\tpass"},
		{"path": "res://eventsheet_addons/status_effects/status_effects_behavior.gd",
			"source": "\thealth.call(\"take_typed_damage\", damage, kind, _source())"}
	]
	var silent: Array[Dictionary] = doctor.call("report", definitions, PackedStringArray(["fire"]), true)
	return SUPPORT.pins("health_pack_test", [
		["a corpus of nothing but definitions is not a project dealing damage",
			silent.is_empty(), true],
		["the summary leads, then the misspelling, then the guard",
			Array(checks), ["damage", "damage-unknown-type", "damage-guard-against-nothing"]],
		["each finding is about the word itself", Array(subjects), ["", "fier", "holy"]],
		["every one of them is a quiet note", str(findings[1]["severity"]), "info"],
		["a project that has written no set down is not told it misspelled anything",
			Array(quiet_checks), ["damage", "damage-guard-against-nothing"]]
	])


## THE TWO READINGS, over the lines a project really writes. Both are pure over a string, so the
## two shapes that used to defeat them are asked here directly rather than through a project: an
## amount that is a call of its own - `maxf(a, b)` has a comma in it - and a method of the project's
## own whose name merely ENDS in one of the three opinion words.
static func _the_two_readings_read_the_lines_projects_write() -> bool:
	var facts: GDScript = load(DAMAGE_TYPE_FACTS)
	if facts == null:
		return _check("the damage type facts load", false, true)
	var with_a_call: String = "$Health.take_typed_damage(maxf(hit, floor_damage), \"fire\", self)"
	var with_scaled_by: String = "$Health.take_typed_damage(12.0, \"ice\", self, \"damage_taken\")"
	var not_an_opinion: String = "armour.plate_resist(\"cold\")"
	var an_opinion: String = "$Health.resist(\"holy\", 50.0)"
	return SUPPORT.pins("health_pack_test", [
		["an amount with a comma in it still names its kind",
			Array(facts.call("types_dealt", with_a_call)), ["fire"]],
		["and the kind read is the kind, not the difficulty factor after it",
			Array(facts.call("types_dealt", with_scaled_by)), ["ice"]],
		["a method whose name ends in one of the words is not an opinion",
			Array(facts.call("types_opined", not_an_opinion)), []],
		["while the row that is one still is",
			Array(facts.call("types_opined", an_opinion)), ["holy"]]
	])


## THE STARTER IS NOT THE PROJECT'S OWN ANSWER, asked of the REAL filesystem because that is where
## the defect lived: the pure report was right all along, and the walk under it counted the pack's
## own shipped set. `has_any_set` is what the Doctor asks before it may call a word a misspelling, so
## a starter that counted would answer "this project has written its damage types down" in every
## project that merely installed the pack, and every kind that starter does not name would be
## reported as a typo. The file is still read - it is a real set - it simply is not this project's.
static func _the_shipped_starter_is_not_the_projects_own_set() -> bool:
	var facts: GDScript = load(DAMAGE_TYPE_FACTS)
	if facts == null:
		return _check("the damage type facts load", false, true)
	var shipped_among_them: PackedStringArray = PackedStringArray()
	for path: String in facts.call("project_set_files") as PackedStringArray:
		if path.begins_with("res://eventsheet_addons/damage_type_set_resource/") or path.begins_with("res://tools/pack_builders/"):
			shipped_among_them.append(path)
	# THE OTHER READER OF THE SAME FILE WANTS THE OPPOSITE ANSWER. The Doctor must not count the
	# starter or it would report on a set nobody chose; the type field must offer it or it would
	# suggest nothing at all until somebody had already typed the word it was going to teach them.
	var suggested: PackedStringArray = PackedStringArray()
	for kind: Dictionary in facts.call("types_to_suggest") as Array:
		suggested.append(str(kind["name"]))
	return SUPPORT.pins("health_pack_test", [
		["no set the pack ships counts as one this project wrote",
			Array(shipped_among_them), []],
		["and it is a real set all the same, or the filter would be proving nothing",
			Array(facts.call("type_names", facts.call("source_of", TYPE_SET_STARTER))),
			["physical", "fire", "ice", "poison"]],
		["a project that has written no set down is still not one that has",
			facts.call("has_any_set"), false],
		["while the field it types a kind into offers the starter's four words",
			Array(suggested), ["fire", "ice", "physical", "poison"]]
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
