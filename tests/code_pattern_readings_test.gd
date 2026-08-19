@tool
class_name CodePatternReadingsTest
extends RefCounted

# Pins the batch-eight PATTERN readings - the shapes several lines make together, which no single
# line can decide:
#
#   S4  a number counted down by a delta and asked about against zero reads as a countdown
#   S2  a list drained behind an is_empty guard with an instantiate fallback reads as a pool
#
# Two gates: the whole-file facts (which names are countdowns, which lists are pools) and the
# sentences the grammar builds once it has them. Both are values, pinned literally, so a reading
# that drifts is a failing line rather than a changed count.


static func run() -> bool:
	var ok: bool = true
	ok = _countdown_facts() and ok
	ok = _countdown_sentences() and ok
	ok = _pool_facts() and ok
	ok = _claims() and ok
	ok = _existence_sentences() and ok
	ok = _list_and_table_sentences() and ok
	ok = _local_storage_sentences() and ok
	ok = _wait_sequences() and ok
	return ok


## S3. A function of alternating waits and actions wears a sequence chip saying how long it takes.
static func _wait_sequences() -> bool:
	var ok: bool = true
	var intro: PackedStringArray = PackedStringArray([
		"logo.show()",
		"await get_tree().create_timer(1.0).timeout",
		"title.show()",
		"await get_tree().create_timer(2.0).timeout",
		"await fade.play(\"out\")",
		"start_game()"
	])
	ok = _check("the whole run is added up",
		EventSheetPatternReadings.wait_sequence_words(EventSheetPatternReadings.wait_sequence(intro)),
		"sequence · 3 s + a wait") and ok
	var timed_only: PackedStringArray = PackedStringArray([
		"a.show()", "await get_tree().create_timer(0.5).timeout",
		"b.show()", "await get_tree().create_timer(0.25).timeout", "c.show()"
	])
	ok = _check("with no open-ended wait the total stands on its own",
		EventSheetPatternReadings.wait_sequence_words(EventSheetPatternReadings.wait_sequence(timed_only)),
		"sequence · 0.75 s") and ok
	ok = _check("one wait is a pause, not a sequence",
		EventSheetPatternReadings.wait_sequence(PackedStringArray([
			"a.show()", "await get_tree().create_timer(1.0).timeout"])).is_empty(), true) and ok
	ok = _check("waits with nothing between them are not a sequence either",
		EventSheetPatternReadings.wait_sequence(PackedStringArray([
			"await get_tree().create_timer(1.0).timeout",
			"await get_tree().create_timer(1.0).timeout"])).is_empty(), true) and ok
	return ok


## S5. Saving and loading, in the words a reader whose only storage rows were Set item / Item has.
static func _local_storage_sentences() -> bool:
	var ok: bool = true
	var context: Dictionary = {"script_object": "Player"}
	ok = _check("a section and a key address one item",
		_reading(EventSheetSentence.statement("cfg.set_value(\"player\", \"score\", score)", context)),
		"Local Storage ▸ Set item player/score to score") and ok
	ok = _check("a key worked out at run time keeps the section apart",
		_reading(EventSheetSentence.statement("cfg.set_value(\"player\", key, score)", context)),
		"Local Storage ▸ Set item key to score (section \"player\")") and ok
	ok = _check("reading one back names the item the same way",
		_reading(EventSheetSentence.statement(
			"score = cfg.get_value(\"player\", \"score\", 0)", context)),
		"System ▸ Set score to Local Storage.Item(\"player/score\") (or 0)") and ok
	ok = _check("a JSON save file is a save file too",
		_reading(EventSheetSentence.statement("cfg.save(\"user://save.json\")", context)),
		"Local Storage ▸ Save \"save.json\"") and ok
	ok = _check("the error code asks whether there is a save file",
		_reading(EventSheetSentence.condition("cfg.load(\"user://save.cfg\") != OK", context)),
		"Local Storage ▸ save file is missing (\"save.cfg\")") and ok
	ok = _check("and the other way round",
		_reading(EventSheetSentence.condition("cfg.load(\"user://save.cfg\") == OK", context)),
		"Local Storage ▸ save file exists (\"save.cfg\")") and ok
	ok = _check("an image written to disk is not storage",
		_reading(EventSheetSentence.statement("sprite.save(\"user://shot.png\")", context)), "") and ok
	return ok


## S6. The sentences the sheet has for identity and family.
static func _existence_sentences() -> bool:
	var ok: bool = true
	var context: Dictionary = {"script_object": "Player", "variable_types": {"items": "Array"}}
	ok = _check("a careful null check still asks whether it exists",
		_reading(EventSheetSentence.condition("is_instance_valid(t)", context)), "t ▸ exists") and ok
	ok = _check("letting go of a reference is Forget",
		_reading(EventSheetSentence.statement("target = null", context)), "Player ▸ Forget target") and ok
	ok = _check("a property cleared to null is still a Set",
		_reading(EventSheetSentence.statement("sprite.texture = null", context)),
		"sprite ▸ Set texture to null") and ok
	ok = _check("leaving the layout is not being destroyed",
		_reading(EventSheetSentence.statement("get_parent().remove_child(self)", context)),
		"Player ▸ Remove from layout (kept alive, not destroyed)") and ok
	return ok


## S7. The list and table shapes that read as calls today.
static func _list_and_table_sentences() -> bool:
	var ok: bool = true
	var context: Dictionary = {"script_object": "Player", "variable_types": {"items": "Array"}}
	ok = _check("a table read says what stands in when the key is missing",
		_reading(EventSheetSentence.statement("hp = stats.get(\"hp\", 100)", context)),
		"System ▸ Set hp to stats \"hp\" (or 100 when missing)") and ok
	ok = _check("the head of a list reads as the first few of it",
		_reading(EventSheetSentence.statement("top = items.slice(0, 3)", context)),
		"System ▸ Set top to the first 3 of items") and ok
	ok = _check("a one-line reduce that adds one member up is a total",
		_reading(EventSheetSentence.statement(
			"total = items.reduce(func(acc, i): return acc + i.price, 0)", context)),
		"System ▸ Set total to the sum of price over items") and ok
	ok = _check("sorting by a member says which way it goes",
		_reading(EventSheetSentence.statement(
			"items.sort_custom(func(a, b): return a.price < b.price)", context)),
		"System ▸ Sort items by price (lowest first)") and ok
	ok = _check("the other direction says so too",
		_reading(EventSheetSentence.statement(
			"items.sort_custom(func(a, b): return a.price > b.price)", context)),
		"System ▸ Sort items by price (highest first)") and ok
	ok = _check("a list asked whether it holds something contains it",
		_reading(EventSheetSentence.condition("items.has(sword)", context)),
		"System ▸ items contains sword") and ok
	ok = _check("a table asked the same question is asked about its keys",
		_reading(EventSheetSentence.condition("stats.has(\"hp\")", context)),
		"System ▸ stats has key \"hp\"") and ok
	ok = _check("a function held in a table is called by the entry that holds it",
		_reading(EventSheetSentence.statement("commands[\"equip\"].call()", context)),
		"Functions ▸ Call the function stored in commands \"equip\" (a table of functions)") and ok
	ok = _check("a lambda written over two lines keeps its own code",
		EventSheetSentence.sorted_member("func(a, b):\n\treturn a.price < b.price").is_empty(), true) and ok
	ok = _check("comparing two different members is not a Sort by",
		EventSheetSentence.sorted_member("func(a, b): return a.price < b.weight").is_empty(), true) and ok
	return ok


## Every pattern reading claims its pattern on the row that owns it, with the source lines as
## evidence and the shipped behavior when one could replace the hand-written shape.
static func _claims() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	var tick: EventRow = EventRow.new()
	tick.event_uid = "tick-1"
	var counted: RawCodeRow = RawCodeRow.new()
	counted.code = "cooldown -= delta\nif cooldown <= 0:\n\tshoot()"
	tick.actions.append(counted)
	var spawn: EventRow = EventRow.new()
	spawn.event_uid = "spawn-1"
	var pooled: RawCodeRow = RawCodeRow.new()
	pooled.code = "var b = pool.pop_back() if not pool.is_empty() else BULLET.instantiate()"
	spawn.actions.append(pooled)
	sheet.events.append(tick)
	sheet.events.append(spawn)
	EventSheetPatternFacts.clear(sheet)
	EventSheetViewportReadingRows.claim_patterns(sheet)
	var tick_claims: Array = EventSheetPatternFacts.claims_for_row(sheet, "tick-1")
	ok = _check("the tick event owns one claim", tick_claims.size(), 1) and ok
	if tick_claims.size() == 1:
		var claim: Dictionary = tick_claims[0]
		ok = _check("it is the countdown", claim.get("pattern", ""), "countdown") and ok
		ok = _check("its evidence is the source line",
			", ".join(claim.get("evidence", PackedStringArray())), "cooldown -= delta") and ok
	var spawn_claims: Array = EventSheetPatternFacts.claims_for_row(sheet, "spawn-1")
	ok = _check("the spawning event owns the pool claim", spawn_claims.size(), 1) and ok
	if spawn_claims.size() == 1:
		ok = _check("the shipped pool behavior is offered",
			(spawn_claims[0] as Dictionary).get("adoptable", ""), "object_pool") and ok
	EventSheetPatternFacts.clear(sheet)
	return ok


## S4. Both halves are required: counted down by a delta AND compared against zero.
static func _countdown_facts() -> bool:
	var ok: bool = true
	var lines: PackedStringArray = PackedStringArray([
		"cooldown -= delta",
		"if cooldown <= 0 and Input.is_action_pressed(\"fire\"):",
		"invincible_for = max(0.0, invincible_for - delta)",
		"if invincible_for > 0:",
		"fuse = move_toward(fuse, 0, delta)",
		"if fuse <= 0:",
		"score -= delta",
		"ammo -= 1",
		"if ammo <= 0:"
	])
	var facts: Dictionary = EventSheetPatternReadings.countdown_variables(lines)
	ok = _check("a bare delta countdown is one", facts.get("cooldown", "missing"), "") and ok
	ok = _check("a clamped countdown says it stays above zero",
		facts.get("invincible_for", "missing"), "never below 0") and ok
	ok = _check("move_toward toward zero is a countdown",
		facts.get("fuse", "missing"), "never below 0") and ok
	ok = _check("a number never compared to zero is not a countdown", facts.has("score"), false) and ok
	ok = _check("a number never counted down by a delta is not a countdown", facts.has("ammo"), false) and ok
	ok = _check("nothing else is claimed", facts.size(), 3) and ok
	return ok


## S4. The four sentences a countdown reads in, with the file's own facts in the context.
static func _countdown_sentences() -> bool:
	var ok: bool = true
	var context: Dictionary = {
		"script_object": "Player",
		"countdown_variables": {"cooldown": "", "invincible_for": "never below 0"}
	}
	ok = _check("counting down reads as counting down",
		_reading(EventSheetSentence.statement("cooldown -= delta", context)),
		"Player ▸ Count down cooldown (by dt)") and ok
	ok = _check("a clamped countdown says so",
		_reading(EventSheetSentence.statement("invincible_for = max(0.0, invincible_for - delta)", context)),
		"Player ▸ Count down invincible_for (never below 0)") and ok
	ok = _check("setting a countdown starts it",
		_reading(EventSheetSentence.statement("cooldown = 0.5", context)),
		"Player ▸ Start cooldown for 0.5 seconds") and ok
	ok = _check("reaching zero is running out",
		_reading(EventSheetSentence.condition("cooldown <= 0", context)),
		"Player ▸ cooldown has run out") and ok
	ok = _check("above zero is still running",
		_reading(EventSheetSentence.condition("invincible_for > 0", context)),
		"Player ▸ invincible_for is running") and ok
	# With no countdown facts in the context nothing fires, and every line keeps its own reading.
	ok = _check("a plain subtraction is still a subtraction",
		_reading(EventSheetSentence.statement("cooldown -= delta", {"script_object": "Player"})),
		"System ▸ Subtract dt from cooldown") and ok
	return ok


## S2. The pooled-Create line, in both orders of the ternary that writes it.
static func _pool_facts() -> bool:
	var ok: bool = true
	var taken: Dictionary = EventSheetPatternReadings.pool_take_parts(
		"var b = pool.pop_back() if not pool.is_empty() else BULLET.instantiate()")
	ok = _check("the pool is named", taken.get("pool", ""), "pool") and ok
	ok = _check("the scene is named", taken.get("scene", ""), "BULLET") and ok
	ok = _check("the new object keeps its own name", taken.get("alias", ""), "b") and ok
	var flipped: Dictionary = EventSheetPatternReadings.pool_take_parts(
		"var b = BULLET.instantiate() if pool.is_empty() else pool.pop_front()")
	ok = _check("the other order of the ternary reads the same", flipped.get("pool", ""), "pool") and ok
	ok = _check("a pool with no guard is not a pool",
		EventSheetPatternReadings.pool_take_parts("var b = pool.pop_back()").is_empty(), true) and ok
	ok = _check("a ternary that makes two different things is not a pool",
		EventSheetPatternReadings.pool_take_parts(
			"var b = A.instantiate() if pool.is_empty() else C.instantiate()").is_empty(), true) and ok
	var pools: Dictionary = EventSheetPatternReadings.pool_variables(PackedStringArray([
		"var b = pool.pop_back() if not pool.is_empty() else BULLET.instantiate()"
	]))
	ok = _check("the file's pools are found", pools.has("pool"), true) and ok
	var sleep_step: Dictionary = EventSheetPatternReadings.pool_return_step("b.set_process(false)", pools)
	ok = _check("switching an object off is a sleep step", sleep_step.get("kind", ""), "sleep") and ok
	var back: Dictionary = EventSheetPatternReadings.pool_return_step("pool.push_back(b)", pools)
	ok = _check("pushing it back is the return step", back.get("kind", ""), "return") and ok
	ok = _check("the returned object is named", back.get("object", ""), "b") and ok
	ok = _check("a push onto a list that is not a pool is not a return step",
		EventSheetPatternReadings.pool_return_step("names.push_back(b)", pools).is_empty(), true) and ok
	return ok


## "Object ▸ sentence", the way the canvas draws a row, so a pin reads like the row it stands for.
static func _reading(result: Dictionary) -> String:
	var text: String = ""
	for segment: Variant in (result.get("segments", []) as Array):
		text += str((segment as Dictionary).get("text", ""))
	var object_name: String = str(result.get("object", ""))
	return text.strip_edges() if object_name.is_empty() else "%s ▸ %s" % [object_name, text.strip_edges()]


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] code_pattern_readings_test: %s" % label)
		return true
	print("[FAIL] code_pattern_readings_test: %s - expected %s, got %s" % [label, expected, actual])
	return false
