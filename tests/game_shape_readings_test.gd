# Godot EventSheets - the four game shapes read, claimed, authored and gated.
#
# X21 a pity system, X24 the stealth detection loop, X26 a boss fight's phase ladder, X27 a mission
# clock. Each one is a shape several lines make TOGETHER, so each one is answered from a walk of the
# whole file rather than line by line, and each one is claimed in the pattern registry.
#
# What this pins, in the order the mistakes actually happen:
#   1. THE GATE. Every reading here is one word away from claiming a shape that is not there - a
#      clamped add is not a meter, a health check is not a phase, a countdown is not a mission, a
#      roll without a growing chance is not pity. The negative pins are the point of this file.
#   2. THE WORDS. The exact sentence each shape reads as, pinned by VALUE.
#   3. THE ROWS. The picker verbs emit exactly the line the reading recognises, and a compiled sheet
#      reopens with the same rows - the two-way byte gate.
#   4. THE NOTES. The three advisory Doctor findings, each on a shape MISSING a half.
#   5. THE STARTERS. All four build and compile.
@tool
class_name GameShapeReadingsTest
extends RefCounted

## The pity system exactly as a jam script writes it - the four halves, spread apart.
const PITY_SOURCE: PackedStringArray = [
	"pity += 1",
	"var chance := base_chance + pity_step * float(pity)",
	"if pity >= pity_cap or randf() < chance:",
	"pity = 0",
	"return \"rare\""
]

## The detection loop: a meter filled while the target is seen, drained while it is not.
const DETECTION_SOURCE: PackedStringArray = [
	"if _can_see(player) and not player.is_hidden:",
	"suspicion = minf(suspicion + detect_rate * delta, 100.0)",
	"last_known = player.global_position",
	"else:",
	"suspicion = maxf(suspicion - calm_rate * delta, 0.0)",
	"if suspicion >= 100.0:",
	"change_state(State.HUNTING)"
]

## The boss ladder: two guarded thresholds, and a plain health check that must NOT read as one.
const BOSS_SOURCE: PackedStringArray = [
	"hp -= amount",
	"if phase == 1 and hp <= max_hp * 0.6:",
	"phase = 2",
	"_enter_phase_2()",
	"if phase == 2 and hp <= max_hp * 0.25:",
	"phase = 3",
	"_enter_phase_3()",
	"if hp <= 0.0:",
	"defeated.emit()"
]

## The mission clock: counted down by a delta, asked about against zero, shown as m:ss.
const MISSION_SOURCE: PackedStringArray = [
	"mission_left = maxf(0.0, mission_left - delta)",
	"label.text = (\"%02d:%02d\" % [int(mission_left) / 60, int(mission_left) % 60])",
	"if mission_left <= 0.0:",
	"mission_failed.emit()"
]

const SCRATCH_DIR := "user://eventforge_game_shapes_test"


static func run() -> bool:
	var ok: bool = true
	ok = _pity_reading() and ok
	ok = _detection_reading() and ok
	ok = _boss_reading() and ok
	ok = _mission_reading() and ok
	ok = _vocabulary() and ok
	ok = _minutes_seconds_field() and ok
	ok = _round_trip() and ok
	ok = _doctor_notes() and ok
	ok = _starters() and ok
	return ok


## X21. All four halves, or nothing.
static func _pity_reading() -> bool:
	var ok: bool = true
	var facts: Dictionary = EventSheetPatternReadings.facts(PITY_SOURCE)
	var rolls: Dictionary = facts.get("pity_rolls", {})
	ok = _check("the roll-or-cap line is the pity question",
		", ".join(rolls.keys()), "pity >= pity_cap or randf() < chance") and ok
	var roll: Dictionary = rolls.get("pity >= pity_cap or randf() < chance", {})
	ok = _check("it counts the right counter", str(roll.get("counter", "")), "pity") and ok
	ok = _check("it names the growing chance", str(roll.get("chance", "")), "chance") and ok
	ok = _check("and the cap that guarantees the win", str(roll.get("cap", "")), "pity_cap") and ok

	# The words, whole - the run is NOT split into two comparisons.
	var pieces: Dictionary = EventSheetSentence.condition_pieces(
		"pity >= pity_cap or randf() < chance", facts)
	ok = _check("the row belongs to the randomness pack", str(pieces.get("object", "")), "AdvancedRandom") and ok
	ok = _check("and reads as one sentence", _words(pieces),
		"Rolled with pity (chance, guaranteed at pity_cap)") and ok

	# THE GATE. A plain chance roll is the Chance condition it already is.
	var plain: Dictionary = EventSheetPatternReadings.facts(PackedStringArray([
		"if randf() < 0.05:", "return \"rare\""
	]))
	ok = _check("a plain roll claims no pity", (plain.get("pity_rolls", {}) as Dictionary).size(), 0) and ok
	# A counter with no reset is the classic bug, and is deliberately NOT read as a pity system.
	var buggy: Dictionary = EventSheetPatternReadings.facts(PackedStringArray([
		"pity += 1",
		"var chance := base_chance + pity_step * float(pity)",
		"if pity >= pity_cap or randf() < chance:",
		"return \"rare\""
	]))
	ok = _check("a pity counter that never resets is not a pity system",
		(buggy.get("pity_rolls", {}) as Dictionary).size(), 0) and ok
	ok = _check("it is the Doctor's business instead",
		", ".join((buggy.get("pity_unreset", {}) as Dictionary).keys()), "pity") and ok

	var claims: Array = EventSheetPatternReadings.claims_in(PITY_SOURCE, facts)
	ok = _check("the event claims the pity pattern", _claim_patterns(claims).has("pity"), true) and ok
	ok = _check("adoptable as the randomness pack",
		str(_claim_of(claims, "pity").get("adoptable", "")), "advanced_random") and ok
	return ok


## X24. A meter is the PAIR, and a detection meter is the pair plus the question that gates it.
static func _detection_reading() -> bool:
	var ok: bool = true
	var facts: Dictionary = EventSheetPatternReadings.facts(DETECTION_SOURCE)
	var meters: Dictionary = facts.get("meter_variables", {})
	ok = _check("the file keeps one meter", ", ".join(meters.keys()), "suspicion") and ok
	var meter: Dictionary = meters.get("suspicion", {})
	ok = _check("filled at the detect rate", str(meter.get("fill_rate", "")), "detect_rate") and ok
	ok = _check("up to a hundred", str(meter.get("cap", "")), "100.0") and ok
	ok = _check("drained at the calm rate", str(meter.get("drain_rate", "")), "calm_rate") and ok
	ok = _check("down to zero", str(meter.get("floor", "")), "0.0") and ok

	# THE GATE, twice over. A clamped add with no rate is not a meter, and a fill with no drain is
	# not a meter either - which is what keeps every bar in every project out of these words.
	var topped_up: Dictionary = EventSheetPatternReadings.facts(PackedStringArray([
		"stamina = minf(stamina + 10.0, 100.0)"
	]))
	ok = _check("a clamped add is not a meter",
		(topped_up.get("meter_variables", {}) as Dictionary).size(), 0) and ok
	var one_way: Dictionary = EventSheetPatternReadings.facts(PackedStringArray([
		"charge = minf(charge + rate * delta, 100.0)"
	]))
	ok = _check("a fill with no drain is not a meter",
		(one_way.get("meter_variables", {}) as Dictionary).size(), 0) and ok

	var claims: Array = EventSheetPatternReadings.claims_in(DETECTION_SOURCE, facts)
	ok = _check("the loop claims detection", _claim_patterns(claims).has("detection"), true) and ok
	# Without the sight-or-hidden question the same pair is an ordinary meter, and says so.
	var ungated: PackedStringArray = PackedStringArray([
		"heat = minf(heat + gain * delta, 100.0)",
		"heat = maxf(heat - loss * delta, 0.0)"
	])
	var ungated_facts: Dictionary = EventSheetPatternReadings.facts(ungated)
	ok = _check("a meter nobody is looking for is not detection",
		_claim_patterns(EventSheetPatternReadings.claims_in(ungated, ungated_facts)).has("detection"),
		false) and ok
	return ok


## X26. The guard IS the trigger-once, and a plain health check is not a phase.
static func _boss_reading() -> bool:
	var ok: bool = true
	var facts: Dictionary = EventSheetPatternReadings.facts(BOSS_SOURCE)
	var steps: Dictionary = facts.get("boss_phase_steps", {})
	ok = _check("both guarded thresholds are the ladder",
		", ".join(steps.keys()),
		"phase == 1 and hp <= max_hp * 0.6, phase == 2 and hp <= max_hp * 0.25") and ok
	var second: Dictionary = steps.get("phase == 1 and hp <= max_hp * 0.6", {})
	ok = _check("the first step starts phase two", str(second.get("into", "")), "2") and ok
	ok = _check("at sixty percent of maximum", str(second.get("percent", "")), "60") and ok

	var pieces: Dictionary = EventSheetSentence.condition_pieces(
		"phase == 1 and hp <= max_hp * 0.6", facts)
	ok = _check("and reads as the phase starting, once", _words(pieces),
		"Phase 2 starts (hp ≤ 60%, once)") and ok

	# THE GATE. `hp <= 0` is a health check in every game ever written, and stays one.
	ok = _check("a plain health check is not a phase", steps.has("hp <= 0.0"), false) and ok
	var no_guard: Dictionary = EventSheetPatternReadings.facts(PackedStringArray([
		"if hp <= max_hp * 0.5:", "stagger()"
	]))
	ok = _check("an unguarded threshold is not a phase either",
		(no_guard.get("boss_phase_steps", {}) as Dictionary).size(), 0) and ok

	var claims: Array = EventSheetPatternReadings.claims_in(BOSS_SOURCE, facts)
	ok = _check("the function claims the phase ladder",
		_claim_patterns(claims).has("boss_phases"), true) and ok
	return ok


## X27. Three halves - counted down, asked about, and SHOWN.
static func _mission_reading() -> bool:
	var ok: bool = true
	var facts: Dictionary = EventSheetPatternReadings.facts(MISSION_SOURCE)
	ok = _check("the file runs one mission clock",
		", ".join((facts.get("mission_timers", {}) as Dictionary).keys()), "mission_left") and ok
	ok = _check("the m:ss arithmetic reads as the format it is",
		EventSheetSentence.minutes_seconds_expression(
			"(\"%02d:%02d\" % [int(mission_left) / 60, int(mission_left) % 60])", facts),
		"mission_left as minutes:seconds") and ok

	# THE GATE. A countdown nobody can see is a countdown, not a mission.
	var unseen: Dictionary = EventSheetPatternReadings.facts(PackedStringArray([
		"cooldown = maxf(0.0, cooldown - delta)", "if cooldown <= 0.0:", "fire()"
	]))
	ok = _check("a countdown nobody shows is not a mission",
		(unseen.get("mission_timers", {}) as Dictionary).size(), 0) and ok
	ok = _check("and it is still a countdown",
		", ".join((unseen.get("countdown_variables", {}) as Dictionary).keys()), "cooldown") and ok

	var claims: Array = EventSheetPatternReadings.claims_in(MISSION_SOURCE, facts)
	ok = _check("the tick claims the mission timer",
		_claim_patterns(claims).has("quest_timer"), true) and ok
	return ok


## The picker verbs: each template is the exact line its reading recognises.
static func _vocabulary() -> bool:
	var ok: bool = true
	var by_id: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeGameMechanicsACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	ok = _check("Fill Meter writes the clamped rise",
		_template(by_id, "FillMeter"), "{var_name} = minf({var_name} + {rate} * delta, {cap})") and ok
	ok = _check("Drain Meter writes the clamped fall",
		_template(by_id, "DrainMeter"), "{var_name} = maxf({var_name} - {rate} * delta, {floor})") and ok
	ok = _check("Make Noise writes the group walk",
		_template(by_id, "MakeNoise"),
		"for __heard_{uid} in get_tree().get_nodes_in_group({group}):\n\tif __heard_{uid}.global_position.distance_to({at}) < {radius}:\n\t\t__heard_{uid}.hear({at})") and ok
	ok = _check("Phase Starts writes the guarded threshold",
		_template(by_id, "BossPhaseStarts"), "{phase_var} < {phase} and {hp} <= {max_hp} * {share}") and ok
	ok = _check("Set Invulnerable For writes the flag and the timer",
		_template(by_id, "SetInvulnerableFor"),
		"{flag} = true\nawait get_tree().create_timer({seconds}).timeout\n{flag} = false") and ok
	ok = _check("Mission Time Left writes the m:ss the reading recognises",
		_template(by_id, "MissionTimeLeft"),
		"(\"%02d:%02d\" % [int({var_name}) / 60, int({var_name}) % 60])") and ok
	ok = _check("and its own output reads back as minutes and seconds",
		EventSheetPatternReadings.is_minutes_seconds(
			"(\"%02d:%02d\" % [int(mission_left) / 60, int(mission_left) % 60])", "mission_left"), true) and ok
	ok = _check("Start Mission Timer takes its time in minutes:seconds",
		_param_hint(by_id.get("StartMissionTimer", null), "seconds"), "minutes_seconds") and ok

	# The receiving half of Make Noise is a handler the noise maker calls by name.
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnNoiseHeard"
	var signature: Dictionary = TriggerResolver.resolve_trigger(event)
	ok = _check("On Noise Heard resolves to its handler", str(signature.get("function_name", "")), "hear") and ok
	ok = _check("which receives where the noise came from", str(signature.get("args", "")), "at: Variant") and ok
	ok = _check("its tempo badge says it reacts", TriggerResolver.tempo_class_for("OnNoiseHeard"),
		TriggerResolver.TEMPO_SIGNAL) and ok
	ok = _check("and the lifter reads that header back",
		str(EventSheetACELifter.LIFECYCLE_TRIGGERS.get("func hear(at: Variant) -> void:", "")),
		"OnNoiseHeard") and ok

	# The two mission rows whose templates are a plain Set and a plain Add stay OUT of the reverse
	# index: admitted, they would claim every assignment in every project.
	ok = _check("Start Mission Timer never shadows a plain Set",
		EventSheetACELifter.REVERSE_LIFT_EXCLUDED_ACE_IDS.has("StartMissionTimer"), true) and ok
	ok = _check("Add Mission Time never shadows a plain Add",
		EventSheetACELifter.REVERSE_LIFT_EXCLUDED_ACE_IDS.has("AddMissionTime"), true) and ok

	# The seeded pack's three pity verbs, on the SHIPPED pack (so a builder that was never rebuilt
	# fails here rather than in a game).
	var pack: String = FileAccess.get_file_as_string(
		"res://eventsheet_addons/advanced_random/advanced_random_addon.gd")
	ok = _check("the pack ships Roll With Pity", pack.contains("func roll_with_pity("), true) and ok
	ok = _check("and Reset Pity", pack.contains("func reset_pity("), true) and ok
	ok = _check("and Pity Count", pack.contains("func pity_count("), true) and ok
	ok = _check("its counters ride the seeded generator",
		pack.contains("if _rng.randf() < base_chance + step * float(count):"), true) and ok
	ok = _check("and survive a save", pack.contains("\"pity\": _pity.duplicate()"), true) and ok
	return ok


## X27. The minutes:seconds field: typed as a player reads it, stored as the seconds that ship.
static func _minutes_seconds_field() -> bool:
	var ok: bool = true
	ok = _check("3:00 stores as seconds", ACEParamsDialog.minutes_seconds_as_seconds("3:00"), "180.0") and ok
	ok = _check("0:30 too", ACEParamsDialog.minutes_seconds_as_seconds("0:30"), "30.0") and ok
	ok = _check("and seconds open as minutes:seconds",
		ACEParamsDialog.seconds_as_minutes_seconds("180.0"), "3:00") and ok
	ok = _check("a short one keeps its leading zero",
		ACEParamsDialog.seconds_as_minutes_seconds("30"), "0:30") and ok
	# A time slot is still an expression slot: a variable belongs in it as much as a number does.
	ok = _check("a variable passes through untouched",
		ACEParamsDialog.minutes_seconds_as_seconds("mission_length"), "mission_length") and ok
	ok = _check("both ways", ACEParamsDialog.seconds_as_minutes_seconds("mission_length"),
		"mission_length") and ok
	return ok


## THE TWO-WAY GATE: rows dropped from the picker emit the line the reading recognises, and the
## compiled file reopens as the same rows.
static func _round_trip() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node3D"
	sheet.custom_class_name = "GameShapeRoundTrip"
	sheet.variables = {
		"suspicion": {"type": "float", "default": 0.0},
		"hp": {"type": "float", "default": 100.0},
		"max_hp": {"type": "float", "default": 100.0},
		"phase": {"type": "int", "default": 1}
	}
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnPhysicsProcess"
	tick.actions.append(_action("FillMeter", {"var_name": "suspicion", "rate": "40.0", "cap": "100.0"}))
	tick.actions.append(_action("DrainMeter", {"var_name": "suspicion", "rate": "15.0", "floor": "0.0"}))
	tick.actions.append(_action("MakeNoise", {"at": "global_position", "radius": "200.0",
		"group": "\"hears_noise\"", "uid": "1"}))
	sheet.events.append(tick)
	var phase_event: EventRow = EventRow.new()
	phase_event.trigger_provider_id = "Core"
	phase_event.trigger_id = "OnProcess"
	var phase_condition: ACECondition = ACECondition.new()
	phase_condition.provider_id = "Core"
	phase_condition.ace_id = "BossPhaseStarts"
	phase_condition.params = {"phase": "2", "share": "0.6", "hp": "hp", "max_hp": "max_hp",
		"phase_var": "phase"}
	phase_event.conditions.append(phase_condition)
	phase_event.actions.append(_action("SetVar", {"var_name": "phase", "value": "2"}))
	sheet.events.append(phase_event)

	var compiled: String = str(SheetCompiler.compile(sheet, "user://__game_shapes.gd").get("output", ""))
	ok = _check("the meter rows emit the clamped pair",
		compiled.contains("\tsuspicion = minf(suspicion + 40.0 * delta, 100.0)"), true) and ok
	ok = _check("and the drain beside it",
		compiled.contains("\tsuspicion = maxf(suspicion - 15.0 * delta, 0.0)"), true) and ok
	ok = _check("the noise row emits the group walk",
		compiled.contains("\tfor __heard_1 in get_tree().get_nodes_in_group(\"hears_noise\"):"), true) and ok
	ok = _check("the phase row emits the guarded threshold",
		compiled.contains("\tif phase < 2 and hp <= max_hp * 0.6:"), true) and ok

	DirAccess.make_dir_recursive_absolute(SCRATCH_DIR)
	var compiled_path: String = SCRATCH_DIR + "/round_trip.gd"
	var file: FileAccess = FileAccess.open(compiled_path, FileAccess.WRITE)
	if file != null:
		file.store_string(compiled)
		file.close()
	ok = _check("the compiled sheet parses", load(compiled_path) != null, true) and ok

	var reopened: EventSheetResource = GDScriptImporter.new().import_external_source(compiled)
	var reopened_ids: PackedStringArray = PackedStringArray()
	for entry: Variant in reopened.events:
		if not (entry is EventRow):
			continue
		for action: Variant in (entry as EventRow).actions:
			if action is ACEAction:
				reopened_ids.append((action as ACEAction).ace_id)
		for condition: Variant in (entry as EventRow).conditions:
			if condition is ACECondition:
				reopened_ids.append((condition as ACECondition).ace_id)
	# The meter rows come back as themselves: one statement, one row, straight through the reverse
	# index. The noise walk (three lines) and the guarded phase pair (a run the importer files as two
	# comparisons, which is what the `and` says) are not single-statement rows, so they reopen as the
	# lines they are - and the readings above are what give those lines their words back.
	ok = _check("and reopens with the single-statement rows back",
		_sorted_unique(reopened_ids), "CompareVar, DrainMeter, FillMeter, SetVar") and ok
	# NOTHING IS LOST, which is the promise that actually matters for the shapes that reopen as their
	# lines: saving the reopened sheet writes every one of them back, spelling and all.
	var re_emitted: String = str(SheetCompiler.compile(
		reopened, "user://__game_shapes.gd").get("output", ""))
	var lost: PackedStringArray = PackedStringArray()
	for line: String in ["suspicion = minf(suspicion + 40.0 * delta, 100.0)",
			"suspicion = maxf(suspicion - 15.0 * delta, 0.0)",
			"for __heard_1 in get_tree().get_nodes_in_group(\"hears_noise\"):",
			"__heard_1.hear(global_position)",
			"if phase < 2 and hp <= max_hp * 0.6:", "phase = 2"]:
		if not re_emitted.contains(line):
			lost.append(line)
	ok = _check("and writes every one of those lines back", ", ".join(lost), "") and ok
	return ok


## The three advisory notes, each on a shape missing a half.
static func _doctor_notes() -> bool:
	var ok: bool = true
	var buggy: EventSheetResource = EventSheetResource.new()
	buggy.host_class = "Node"
	var body: RawCodeRow = RawCodeRow.new()
	body.code = "\n".join(PackedStringArray([
		"pity += 1",
		"var chance := base_chance + pity_step * float(pity)",
		"if pity >= pity_cap or randf() < chance:",
		"\treturn \"rare\"",
		"charge = minf(charge + gain * delta, 100.0)"
	]))
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	event.actions.append(body)
	buggy.events.append(event)
	var findings: Array[Dictionary] = []
	EventSheetProjectDoctor.scan_game_shape_smells(buggy, "res://buggy.gd", findings)
	var checks: PackedStringArray = PackedStringArray()
	for finding: Dictionary in findings:
		checks.append(str(finding.get("check", "")))
	ok = _check("the never-reset pity counter is noticed",
		checks.has("pity-counter-never-resets"), true) and ok
	ok = _check("so is the meter that only fills", checks.has("meter-never-drains"), true) and ok
	ok = _check("and both are advisory",
		_severities(findings), "info") and ok

	var unseen: EventSheetResource = EventSheetResource.new()
	unseen.host_class = "Node"
	var start_event: EventRow = EventRow.new()
	start_event.trigger_provider_id = "Core"
	start_event.trigger_id = "OnReady"
	start_event.actions.append(_action("StartMissionTimer",
		{"var_name": "mission_time_left", "seconds": "180.0"}))
	unseen.events.append(start_event)
	var timer_findings: Array[Dictionary] = []
	EventSheetProjectDoctor.scan_game_shape_smells(unseen, "res://unseen.gd", timer_findings)
	var timer_checks: PackedStringArray = PackedStringArray()
	for finding: Dictionary in timer_findings:
		timer_checks.append(str(finding.get("check", "")))
	ok = _check("a mission clock nothing shows is noticed",
		timer_checks.has("mission-timer-not-shown"), true) and ok

	# A whole shape is not accused of anything.
	var healthy: EventSheetResource = EventSheetResource.new()
	healthy.host_class = "Node"
	var whole: RawCodeRow = RawCodeRow.new()
	whole.code = "\n".join(PITY_SOURCE)
	var healthy_event: EventRow = EventRow.new()
	healthy_event.trigger_provider_id = "Core"
	healthy_event.trigger_id = "OnProcess"
	healthy_event.actions.append(whole)
	healthy.events.append(healthy_event)
	var clean: Array[Dictionary] = []
	EventSheetProjectDoctor.scan_game_shape_smells(healthy, "res://healthy.gd", clean)
	ok = _check("a complete pity system is accused of nothing", clean.size(), 0) and ok
	return ok


## All four starters build and compile.
static func _starters() -> bool:
	var ok: bool = true
	for entry: Array in [[15, "LootChest"], [16, "StealthGuard"], [17, "BossFight"], [18, "MissionTimer"]]:
		var sheet: EventSheetResource = EventSheetStarterTemplates.build_starter(int(entry[0]))
		ok = _check("starter %d is the %s sheet" % [int(entry[0]), str(entry[1])],
			sheet.custom_class_name, str(entry[1])) and ok
		var compiled: String = str(SheetCompiler.compile(
			sheet, "user://__starter_%d.gd" % int(entry[0])).get("output", ""))
		var script: GDScript = GDScript.new()
		script.source_code = compiled
		ok = _check("and compiles to valid GDScript", script.reload(true) == OK, true) and ok
	# The loot chest is the pity shape the reading recognises - the starter and the words agree.
	var chest: EventSheetResource = EventSheetStarterTemplates.build_starter(15)
	var chest_lines: PackedStringArray = EventSheetViewportReadingRows.ordered_code_lines(chest)
	ok = _check("the loot chest starter reads as a pity system",
		(EventSheetPatternReadings.facts(chest_lines).get("pity_rolls", {}) as Dictionary).size(), 1) and ok
	var guard: EventSheetResource = EventSheetStarterTemplates.build_starter(16)
	var guard_lines: PackedStringArray = EventSheetViewportReadingRows.ordered_code_lines(guard)
	ok = _check("the stealth guard starter keeps a real meter",
		", ".join((EventSheetPatternReadings.facts(guard_lines).get("meter_variables", {}) as Dictionary).keys()),
		"suspicion") and ok
	var boss: EventSheetResource = EventSheetStarterTemplates.build_starter(17)
	var boss_lines: PackedStringArray = EventSheetViewportReadingRows.ordered_code_lines(boss)
	ok = _check("the boss starter climbs a two-step ladder",
		(EventSheetPatternReadings.facts(boss_lines).get("boss_phase_steps", {}) as Dictionary).size(), 2) and ok
	var mission: EventSheetResource = EventSheetStarterTemplates.build_starter(18)
	var mission_lines: PackedStringArray = EventSheetViewportReadingRows.ordered_code_lines(mission)
	ok = _check("the mission starter runs a clock the player can read",
		", ".join((EventSheetPatternReadings.facts(mission_lines).get("mission_timers", {}) as Dictionary).keys()),
		"mission_time_left") and ok
	return ok


## An ACEAction with its params already filled - the row a picker drop leaves behind.
static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	return action


## The sentence a condition reads as, its segments joined - what a reader sees in the cell.
static func _words(pieces: Dictionary) -> String:
	var text: String = ""
	for piece: Variant in (pieces.get("pieces", []) as Array):
		text += str((piece as Array)[0])
	return text.strip_edges()


static func _claim_patterns(claims: Array) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for entry: Variant in claims:
		found.append(str((entry as Dictionary).get("pattern", "")))
	return found


static func _claim_of(claims: Array, pattern: String) -> Dictionary:
	for entry: Variant in claims:
		if str((entry as Dictionary).get("pattern", "")) == pattern:
			return entry
	return {}


static func _template(by_id: Dictionary, ace_id: String) -> String:
	var descriptor: Variant = by_id.get(ace_id, null)
	return str((descriptor as ACEDescriptor).codegen_template) if descriptor is ACEDescriptor else ""


static func _param_hint(descriptor: Variant, param_id: String) -> String:
	if not (descriptor is ACEDescriptor):
		return ""
	for param: ACEParam in (descriptor as ACEDescriptor).params:
		if str(param.id) == param_id:
			return str(param.hint)
	return ""


static func _sorted_unique(values: PackedStringArray) -> String:
	var seen: Dictionary = {}
	for value: String in values:
		seen[value] = true
	var ordered: Array = seen.keys()
	ordered.sort()
	var out: PackedStringArray = PackedStringArray()
	for value: Variant in ordered:
		out.append(str(value))
	return ", ".join(out)


static func _severities(findings: Array[Dictionary]) -> String:
	var seen: Dictionary = {}
	for finding: Dictionary in findings:
		seen[str(finding.get("severity", ""))] = true
	var ordered: Array = seen.keys()
	ordered.sort()
	var out: PackedStringArray = PackedStringArray()
	for value: Variant in ordered:
		out.append(str(value))
	return ", ".join(out)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] game_shape_readings_test: %s" % label)
		return true
	print("[FAIL] game_shape_readings_test: %s (expected %s, got %s)" % [label, str(expected), str(actual)])
	return false
