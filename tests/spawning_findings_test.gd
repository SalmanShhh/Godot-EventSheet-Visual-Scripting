# Godot EventSheets - the spawns band, and the four crashes found before the game is run.
#
# What this gate holds, in the order the mistakes actually happen:
#   1. THE BAND. What a sheet spawns, with the cap and the pool its own rows put on it, and the band
#      scale law: the first few named, the rest counted. A sheet that spawns nothing grows no band.
#   2. NEVER CRIES WOLF, BOTH WAYS. Every one of the four checks is pinned TWICE - on a sheet that
#      has the bug, and on the sheet next to it that does not. A check that only fires is as useless
#      as one that never does, and only the pair proves neither.
#   3. THE WORDS AND THE REPAIRS. The sentence a reader acts on and the button beside it are pinned
#      as values, because the sentence IS the feature; a count would go on passing while the wrong
#      words appeared under the row.
#   4. THE RESPELLING. The deferred spelling of a parenting line is pinned as the exact text, and so
#      is its refusal to touch a line that is already deferred - applying the repair twice writes
#      nothing the second time.
#   5. THE SECTION. The Doctor files each kind under its own check id, so the note on the row and the
#      line in the report are the same finding under two roofs.
#
# Values are pinned, never counts: a count would go on passing while the wrong line moved.
@tool
class_name SpawningFindingsTest
extends RefCounted

## The scene the fixtures spawn, and the parameters a spawn row takes.
const BULLET: String = "load(\"res://bullet.tscn\")"
const ENEMY: String = "load(\"res://enemy.tscn\")"


static func run() -> bool:
	var passed: bool = true
	passed = _test_the_band_says_what_the_sheet_spawns() and passed
	passed = _test_the_band_counts_what_it_did_not_name() and passed
	passed = _test_added_during_physics() and passed
	passed = _test_a_maybe_freed_reference() and passed
	passed = _test_the_scene_that_spawns_itself() and passed
	passed = _test_freed_but_still_booked() and passed
	passed = _test_the_deferred_respelling() and passed
	passed = _test_the_guard_repair_is_about_the_name() and passed
	passed = _test_the_strip_reads_the_stamp() and passed
	passed = _test_the_doctor_files_each_kind() and passed
	passed = _test_the_doctor_files_a_real_finding() and passed
	return passed


# ── 1. The band ──


static func _test_the_band_says_what_the_sheet_spawns() -> bool:
	var passed: bool = true
	# A sheet that spawns nothing has nothing to say about spawning, so the head is exactly as it was.
	passed = _check("a sheet that spawns nothing grows no band",
		EventSheetSpawnFacts.bands(_sheet()).size(), 0) and passed

	var sheet: EventSheetResource = _sheet()
	sheet.events.append(_event("OnReady", [_action("SpawnNewCopy", {
		"scene": BULLET, "name": "shot", "at": "global_position", "parent": "self"})]))
	var bands: Array[Dictionary] = EventSheetSpawnFacts.bands(sheet)
	passed = _check("one spawn row is one band", bands.size(), 1) and passed
	passed = _check("the band names the scene file",
		str(bands[0].get("value", "")), "bullet.tscn") and passed
	passed = _check("and echoes the line the file holds",
		str(bands[0].get("echo", "")), "var shot = load(\"res://bullet.tscn\").instantiate()") and passed
	passed = _check("and carries the file, so the click has somewhere to go",
		str(bands[0].get("reference", "")), "res://bullet.tscn") and passed

	# The cap is the fact that decides whether the spawning is safe to leave running, so the band
	# says it beside the scene rather than leaving it buried in the row.
	var capped: EventSheetResource = _sheet()
	capped.events.append(_event("OnProcess", [_action("SpawnIntoCrowdOldestFirst", {
		"scene": ENEMY, "name": "foe", "crowd": "\"enemies\"", "cap": "12",
		"at": "global_position", "parent": "self"})]))
	passed = _check("a capped crowd says the cap and the crowd",
		str(EventSheetSpawnFacts.bands(capped)[0].get("value", "")),
		"enemy.tscn - at most 12 in enemies") and passed

	# And a pool is the other one. Read off the line the pack's own row writes, so a pool declared
	# with its scene is said against that scene rather than named twice.
	var pooled: EventSheetResource = _sheet()
	pooled.events.append(_event("OnReady", [_raw(
		"ObjectPool.create_pool(\"bullets\", \"res://bullet.tscn\", 8)")]))
	passed = _check("a declared pool says the scene and the pool",
		str(EventSheetSpawnFacts.bands(pooled)[0].get("value", "")),
		"bullet.tscn - pooled as bullets") and passed

	# ONE POOL IS ONE BAND. Declaring a pool and taking copies out of it are the two halves of one
	# spawning, and a sheet doing both - which is the only way a pool is ever used - said one thing.
	# Pinned in both orders, because the sheet decides which half it says first.
	var both: EventSheetResource = _sheet()
	both.events.append(_event("OnReady", [_raw(
		"ObjectPool.create_pool(\"bullets\", \"res://bullet.tscn\", 8)")]))
	both.events.append(_event("OnProcess", [_raw("var shot = ObjectPool.spawn(\"bullets\")")]))
	var both_bands: Array[Dictionary] = EventSheetSpawnFacts.bands(both)
	passed = _check("a pool declared and drawn from is one band", both_bands.size(), 1) and passed
	passed = _check("saying the scene it was declared with",
		str(both_bands[0].get("value", "")), "bullet.tscn - pooled as bullets") and passed

	var drawn_first: EventSheetResource = _sheet()
	drawn_first.events.append(_event("OnProcess", [_raw("var shot = ObjectPool.spawn(\"bullets\")")]))
	drawn_first.events.append(_event("OnReady", [_raw(
		"ObjectPool.create_pool(\"bullets\", \"res://bullet.tscn\", 8)")]))
	var drawn_bands: Array[Dictionary] = EventSheetSpawnFacts.bands(drawn_first)
	passed = _check("and one band still when the drawing is said first",
		drawn_bands.size(), 1) and passed
	passed = _check("the declaring half naming the scene on the band the other opened",
		str(drawn_bands[0].get("value", "")), "bullet.tscn - pooled as bullets") and passed
	passed = _check("with the file behind it, so the click has somewhere to go",
		str(drawn_bands[0].get("reference", "")), "res://bullet.tscn") and passed

	# A pool this sheet only draws from says the pool's own name, which is the whole of what it knows.
	var borrowed: EventSheetResource = _sheet()
	borrowed.events.append(_event("OnProcess", [_raw("var shot = ObjectPool.spawn(\"bullets\")")]))
	passed = _check("a pool only drawn from says the pool and nothing it was not told",
		str(EventSheetSpawnFacts.bands(borrowed)[0].get("value", "")),
		"bullets - pooled as bullets") and passed
	return passed


static func _test_the_band_counts_what_it_did_not_name() -> bool:
	var passed: bool = true
	# THE BAND SCALE LAW: a head longer than the sheet is not a head, so the band names what fits and
	# counts the rest on one line.
	var many: EventSheetResource = _sheet()
	for index: int in range(EventSheetSpawnFacts.SHOWN_LIMIT + 2):
		many.events.append(_event("OnReady", [_action("SpawnNewCopy", {
			"scene": "load(\"res://scene_%d.tscn\")" % index, "name": "copy_%d" % index,
			"at": "global_position", "parent": "self"})]))
	var bands: Array[Dictionary] = EventSheetSpawnFacts.bands(many)
	passed = _check("the band names what fits and adds one line for the rest",
		bands.size(), EventSheetSpawnFacts.SHOWN_LIMIT + 1) and passed
	passed = _check("and the last line is the count, not another scene",
		str(bands[bands.size() - 1].get("value", "")), "and 2 more scene(s) spawned") and passed
	passed = _check("which has no file behind it to browse to",
		str(bands[bands.size() - 1].get("reference", "")), "") and passed

	# And the head really shows them: the band model reads the readings under its own key, in reading
	# order, with the word the band opens with and the gesture on its right edge.
	var head: Array[Dictionary] = EventSheetHeadBands.bands({
		"extends": "Node2D", "spawns": [{"value": "bullet.tscn", "echo": "var shot = Bullet.instantiate()",
			"reference": "res://bullet.tscn"}]})
	var spawns: Dictionary = _band_of(head, EventSheetHeadBands.BAND_SPAWNS)
	passed = _check("the head grows a spawns band", str(spawns.get("value", "")), "bullet.tscn") and passed
	passed = _check("opening with the word the line is about",
		str(spawns.get("leader", "")), "spawns") and passed
	passed = _check("and the gesture a file wants",
		str(spawns.get("control", "")), "browse the scene") and passed
	passed = _check("after the band saying who spawns THIS one, which is the file's own order",
		EventSheetHeadBands.ORDER.find(EventSheetHeadBands.BAND_SPAWNS)
			> EventSheetHeadBands.ORDER.find(EventSheetHeadBands.BAND_SPAWNED), true) and passed
	return passed


# ── 2. Added while the physics server is busy ──


static func _test_added_during_physics() -> bool:
	var passed: bool = true
	# THE BUG: a hand-written parenting line inside a collision callback. Godot refuses the add while
	# the physics server is flushing, and the error names a line nobody was looking at.
	var bad: EventSheetResource = _sheet()
	bad.events.append(_event("OnBodyEntered", [_raw("add_child(Bullet.instantiate())")]))
	var found: Array[Dictionary] = EventSheetSpawnFindings.findings(bad)
	passed = _check("a naked add_child in a collision callback is found",
		_kinds(found), PackedStringArray([EventSheetSpawnFindings.KIND_ADDED_DURING_PHYSICS])) and passed
	passed = _check("and says why Godot refuses it",
		_message_of(found, EventSheetSpawnFindings.KIND_ADDED_DURING_PHYSICS),
		"This adds a node to the tree while the physics server is busy, and Godot refuses it. Add it on the next idle moment instead.") and passed
	passed = _check("with the one-click respelling beside it",
		_fix_of(found, EventSheetSpawnFindings.KIND_ADDED_DURING_PHYSICS),
		EventSheetSpawnFindings.FIX_DEFER_THE_ADD) and passed
	passed = _check("hanging under the event that has it",
		EventSheetSpawnFindings.for_event(found, bad.events[0] as EventRow).size(), 1) and passed

	# AND IT DOES NOT CRY WOLF. The same line already deferred is the answer, not the problem.
	var deferred: EventSheetResource = _sheet()
	deferred.events.append(_event("OnBodyEntered",
		[_raw("call_deferred(\"add_child\", Bullet.instantiate())")]))
	passed = _check("a line that already defers the add is not reported",
		_kinds(EventSheetSpawnFindings.findings(deferred)), PackedStringArray()) and passed
	# Nor is the same line anywhere the physics server is not flushing.
	var elsewhere: EventSheetResource = _sheet()
	elsewhere.events.append(_event("OnReady", [_raw("add_child(Bullet.instantiate())")]))
	passed = _check("and the same line outside a physics callback is nobody's problem",
		_kinds(EventSheetSpawnFindings.findings(elsewhere)), PackedStringArray()) and passed

	# A PICKED spawn row in the same place gets the row that stands beside it, by name.
	var picked: EventSheetResource = _sheet()
	picked.events.append(_event("OnAreaEntered", [_action("SpawnNewCopy", {
		"scene": BULLET, "name": "shot", "at": "global_position", "parent": "self"})]))
	var on_row: Array[Dictionary] = EventSheetSpawnFindings.findings(picked)
	passed = _check("a picked spawn row in a collision callback is offered the safe row",
		_label_of(on_row, EventSheetSpawnFindings.KIND_ADDED_DURING_PHYSICS),
		"Use the safe spawn row") and passed
	passed = _check("naming the deferred row it swaps to",
		str(on_row[0].get("to", "")), "SpawnNewCopyDeferred") and passed
	# And the deferred spawn row itself is the answer, so it is never reported.
	var safe: EventSheetResource = _sheet()
	safe.events.append(_event("OnAreaEntered", [_action("SpawnNewCopyDeferred", {
		"scene": BULLET, "name": "shot", "at": "position", "parent": "self"})]))
	passed = _check("and the deferred spawn row is never reported",
		_kinds(EventSheetSpawnFindings.findings(safe)), PackedStringArray()) and passed
	return passed


# ── 3. A reference that may already be gone ──


static func _test_a_maybe_freed_reference() -> bool:
	var passed: bool = true
	# THE BUG: a node kept in a variable across frames, reached into without asking. The sheet spawns,
	# which is what puts it in the business of things arriving and leaving - and is the gate the rule
	# sits behind, so a sheet that merely holds a node grows no note about it.
	var bad: EventSheetResource = _sheet()
	bad.variables = {"held_boss": {"type": "Node2D", "default": "null", "exported": false}}
	bad.events.append(_event("OnReady", [_action("SpawnNewCopy", {
		"scene": ENEMY, "name": "foe", "at": "global_position", "parent": "self"})]))
	bad.events.append(_event("OnProcess", [_action("SetProperty",
		{"target": "held_boss", "property": "\"visible\"", "value": "true"})]))
	# And the sheet destroys it somewhere, which is what says the reference can really be dangling -
	# the rule asks for the sheet's own word on that rather than suspecting every held node.
	bad.events.append(_event("OnAreaEntered", [_action("DestroyNow", {"object": "held_boss"})]))
	var found: Array[Dictionary] = EventSheetSpawnFindings.findings(bad)
	passed = _check("a stored node reached into without a guard is found",
		_kinds(found), PackedStringArray([EventSheetSpawnFindings.KIND_MAYBE_FREED])) and passed
	passed = _check("and says whose reference it is",
		_message_of(found, EventSheetSpawnFindings.KIND_MAYBE_FREED),
		"held_boss is kept between frames, and anything could have destroyed it by now. Ask whether it is still here before reaching into it.") and passed
	passed = _check("with the guard one click away",
		_fix_of(found, EventSheetSpawnFindings.KIND_MAYBE_FREED),
		EventSheetSpawnFindings.FIX_GUARD_IT) and passed

	# AND IT DOES NOT CRY WOLF. A sheet that already asked has asked, in either spelling.
	var asked: EventSheetResource = _sheet()
	asked.variables = bad.variables.duplicate(true)
	asked.events.append(_event("OnReady", [_action("SpawnNewCopy", {
		"scene": ENEMY, "name": "foe", "at": "global_position", "parent": "self"})]))
	var guarded: EventRow = _event("OnProcess", [_action("SetProperty",
		{"target": "held_boss", "property": "\"visible\"", "value": "true"})])
	guarded.conditions.append(_condition("IsStillHere", {"object": "held_boss"}))
	asked.events.append(guarded)
	asked.events.append(_event("OnAreaEntered", [_action("DestroyNow", {"object": "held_boss"})]))
	passed = _check("a sheet that already asked is not asked again",
		_kinds(EventSheetSpawnFindings.findings(asked)), PackedStringArray()) and passed

	# Nor is a destroy row, which the compiler's own guard already writes the question for.
	var removing: EventSheetResource = _sheet()
	removing.variables = bad.variables.duplicate(true)
	removing.events.append(_event("OnReady", [_action("SpawnNewCopy", {
		"scene": ENEMY, "name": "foe", "at": "global_position", "parent": "self"})]))
	removing.events.append(_event("OnProcess", [_action("DestroyNow", {"object": "held_boss"})]))
	passed = _check("a destroy row carries its own guard and is left alone",
		_kinds(EventSheetSpawnFindings.findings(removing)), PackedStringArray()) and passed

	# Nor is a value that cannot be a node at all.
	var counted: EventSheetResource = _sheet()
	counted.variables = {"score": {"type": "int", "default": "0", "exported": false}}
	counted.events.append(_event("OnReady", [_action("SpawnNewCopy", {
		"scene": ENEMY, "name": "foe", "at": "global_position", "parent": "self"})]))
	counted.events.append(_event("OnProcess", [_action("SetProperty",
		{"target": "score", "property": "\"value\"", "value": "1"})]))
	passed = _check("a number is not a reference that can be freed",
		_kinds(EventSheetSpawnFindings.findings(counted)), PackedStringArray()) and passed
	return passed


# ── 4. The scene that spawns itself ──


static func _test_the_scene_that_spawns_itself() -> bool:
	var passed: bool = true
	# THE BUG: the copy runs the same sheet, spawns another, and the count doubles - a hang rather
	# than an error, so there is no line to point at afterwards.
	var bad: EventSheetResource = _sheet()
	bad.events.append(_event("OnReady", [_action("SpawnNewCopy", {
		"scene": "load(\"res://enemy.tscn\")", "name": "another", "at": "global_position",
		"parent": "get_parent()"})]))
	var found: Array[Dictionary] = EventSheetSpawnFindings.findings(bad, "res://enemy.tscn")
	passed = _check("a scene spawning itself on creation is found",
		_kinds(found), PackedStringArray([EventSheetSpawnFindings.KIND_SPAWNS_ITSELF])) and passed
	passed = _check("as an error, because it is a hang rather than a wrong result",
		str(found[0].get("severity", "")), "error") and passed
	passed = _check("and says what happens",
		_message_of(found, EventSheetSpawnFindings.KIND_SPAWNS_ITSELF),
		"This spawns the scene it is already running in, every time a copy is created, with nothing in the way. Each copy makes another one.") and passed
	passed = _check("with no repair, because the answer is a decision about the game",
		_fix_of(found, EventSheetSpawnFindings.KIND_SPAWNS_ITSELF), "") and passed

	# AND IT DOES NOT CRY WOLF. A spawn under a condition is a game - a boss that splits when it is
	# hit - and reachability rather than text matching is what tells the two apart.
	var conditioned: EventSheetResource = _sheet()
	var gated: EventRow = _event("OnReady", [_action("SpawnNewCopy", {
		"scene": "load(\"res://enemy.tscn\")", "name": "another", "at": "global_position",
		"parent": "get_parent()"})])
	gated.conditions.append(_condition("CompareNumbers",
		{"first": "health", "operator": "<", "second": "10"}))
	conditioned.events.append(gated)
	passed = _check("a spawn of the same scene under a condition is a game, not a loop",
		_kinds(EventSheetSpawnFindings.findings(conditioned, "res://enemy.tscn")),
		PackedStringArray()) and passed
	# Nor is a spawn of somebody ELSE's scene, however unconditional it is.
	var other: EventSheetResource = _sheet()
	other.events.append(_event("OnReady", [_action("SpawnNewCopy", {
		"scene": BULLET, "name": "shot", "at": "global_position", "parent": "self"})]))
	passed = _check("and spawning another scene on creation is ordinary",
		_kinds(EventSheetSpawnFindings.findings(other, "res://enemy.tscn")),
		PackedStringArray()) and passed
	# And a sheet nobody passed a scene for earns a guess about nothing.
	passed = _check("a sheet with no scene behind it earns no guess",
		_kinds(EventSheetSpawnFindings.findings(bad)), PackedStringArray()) and passed
	return passed


# ── 5. Freed, and still booked ──


static func _test_freed_but_still_booked() -> bool:
	var passed: bool = true
	# THE BUG: the destroy is marked at once and the wait is then booked against something that is on
	# its way out of the world.
	var bad: EventSheetResource = _sheet()
	bad.events.append(_event("OnReady", [
		_action("DestroyNow", {"object": "$Enemy"}),
		_action("DestroyAfterSeconds", {"object": "$Enemy", "seconds": "2.0"}),
	]))
	# The subject is a node path here, so the rows are given a bare name the sheet minted instead.
	var minted: EventSheetResource = _sheet()
	minted.events.append(_event("OnReady", [
		_action("SpawnNewCopy", {"scene": ENEMY, "name": "foe", "at": "global_position",
			"parent": "self"}),
		_action("DestroyNow", {"object": "foe"}),
		_action("DestroyAfterSeconds", {"object": "foe", "seconds": "2.0"}),
	]))
	var found: Array[Dictionary] = EventSheetSpawnFindings.findings(minted)
	passed = _check("a wait booked against something destroyed above it is found",
		_kinds(found), PackedStringArray([EventSheetSpawnFindings.KIND_FREED_STILL_BOOKED])) and passed
	passed = _check("and says the two ways out",
		_message_of(found, EventSheetSpawnFindings.KIND_FREED_STILL_BOOKED),
		"foe is destroyed earlier in this event, and this row books a wait against it. Move the destroy below this row, or destroy it after a delay instead.") and passed
	passed = _check("with the reorder one click away",
		_fix_of(found, EventSheetSpawnFindings.KIND_FREED_STILL_BOOKED),
		EventSheetSpawnFindings.FIX_REMOVE_LAST) and passed
	passed = _check("pointing at the destroy row rather than at the booking",
		int(found[0].get("index", -1)), 1) and passed

	# AND IT DOES NOT CRY WOLF. The same two rows in the other order are simply correct.
	var ordered: EventSheetResource = _sheet()
	ordered.events.append(_event("OnReady", [
		_action("SpawnNewCopy", {"scene": ENEMY, "name": "foe", "at": "global_position",
			"parent": "self"}),
		_action("DestroyAfterSeconds", {"object": "foe", "seconds": "2.0"}),
		_action("DestroyNow", {"object": "foe"}),
	]))
	passed = _check("the wait booked before the destroy is the order that works",
		_kinds(EventSheetSpawnFindings.findings(ordered)), PackedStringArray()) and passed
	# And a booking against something ELSE has nothing to do with the destroy above it.
	var elsewhere: EventSheetResource = _sheet()
	elsewhere.events.append(_event("OnReady", [
		_action("SpawnNewCopy", {"scene": ENEMY, "name": "foe", "at": "global_position",
			"parent": "self"}),
		_action("DestroyNow", {"object": "foe"}),
		_action("DestroyAfterSeconds", {"object": "$Other", "seconds": "2.0"}),
	]))
	passed = _check("a wait booked against something else is nobody's problem",
		_kinds(EventSheetSpawnFindings.findings(elsewhere)), PackedStringArray()) and passed
	# The unused fixture above proves nothing on its own; it is compiled to keep the pair honest.
	passed = _check("a node path is not a name this rule follows",
		_kinds(EventSheetSpawnFindings.findings(bad)), PackedStringArray()) and passed
	return passed


# ── 6. The respelling ──


static func _test_the_deferred_respelling() -> bool:
	var passed: bool = true
	passed = _check("a parenting line is respelled with Godot's own deferral",
		EventSheetSpawnFindings.deferred_spelling("add_child(bullet)"),
		"call_deferred(\"add_child\", bullet)") and passed
	passed = _check("the parent it was added under is kept exactly where it was",
		EventSheetSpawnFindings.deferred_spelling("\t$Layer.add_child(bullet)"),
		"\t$Layer.call_deferred(\"add_child\", bullet)") and passed
	passed = _check("and everything the block says beside it is left alone",
		EventSheetSpawnFindings.deferred_spelling(
			"var bullet = Bullet.instantiate()\nadd_child(bullet)\nbullet.position = Vector2.ZERO"),
		"var bullet = Bullet.instantiate()\ncall_deferred(\"add_child\", bullet)\nbullet.position = Vector2.ZERO") and passed
	# Applying the repair twice writes nothing the second time, which is what makes it safe to press.
	passed = _check("a line that is already deferred is left exactly as it is",
		EventSheetSpawnFindings.deferred_spelling("call_deferred(\"add_child\", bullet)"),
		"call_deferred(\"add_child\", bullet)") and passed
	passed = _check("and the receipt shows the line before and the line after",
		EventSheetSpawnFindings.respell_receipt("add_child(bullet)",
			"call_deferred(\"add_child\", bullet)"),
		"add_child(bullet) -> call_deferred(\"add_child\", bullet)") and passed
	return passed


# ── 6b. "Guard it", and the name it is about ──


## The repair adds a question about ONE name, so it may only refuse when that name is the one already
## asked about. Two stored names reached into by rows of the same event each earn their own finding
## (the rule dedupes by name across the sheet, not by event), so a dedupe on the row KIND made the
## second button do nothing while truthfully saying the event had already asked - about the other one.
static func _test_the_guard_repair_is_about_the_name() -> bool:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	var sheet: EventSheetResource = _sheet()
	sheet.variables = {
		"held_boss": {"type": "Node2D", "default": null, "exported": false},
		"held_door": {"type": "Node2D", "default": null, "exported": false},
	}
	sheet.events.append(_event("OnProcess", [
		_action("SetProperty", {"target": "held_boss", "property": "\"visible\"", "value": "true"}),
		_action("SetProperty", {"target": "held_door", "property": "\"visible\"", "value": "true"}),
	]))
	dock.setup(sheet)
	var passed: bool = true
	# The row is re-fetched from the live sheet after every edit: the undo funnel commits by REPLACING
	# resources with snapshot duplicates, so a row held across it is a row that no longer exists.
	for name_text: String in ["held_boss", "held_door"]:
		dock._guard_the_reference({"variable_note_event": _live_event(dock)}, name_text)
	var asked: Dictionary = EventForgeRemovalGuard.asked_names(_live_event(dock))
	passed = _check("each name gets its own question", asked.keys().size(), 2) and passed
	passed = _check("the first name is asked about", asked.has("held_boss"), true) and passed
	passed = _check("and so is the second", asked.has("held_door"), true) and passed
	# And it still refuses the one it should: the same name twice is one question, not two.
	dock._guard_the_reference({"variable_note_event": _live_event(dock)}, "held_door")
	passed = _check("asking twice about one name adds nothing",
		EventForgeRemovalGuard.asked_names(_live_event(dock)).keys().size(), 2) and passed
	dock.free()
	return passed


## The dock's own copy of the sheet's first event, fetched fresh.
static func _live_event(dock: EventSheetDock) -> EventRow:
	return dock._current_sheet.events[0] as EventRow


## THE QUIET SHEET LAW's other half: the sheet's only signal is the amber state, and the words wait
## in the row's stamp for THIS strip. Selecting the stamped row shows the finding's sentence and its
## one door; clicking the door runs the family's own dock operation - the same edit the inbox chip
## makes - and a row with nothing wrong hides the whole strip again.
static func _test_the_strip_reads_the_stamp() -> bool:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	var sheet: EventSheetResource = _sheet()
	sheet.events.append(_event("OnBodyEntered", [_raw("add_child(Bullet.instantiate())")]))
	dock.setup(sheet)
	var passed: bool = true
	var stamped: EventRowData = null
	for candidate: EventRowData in dock._viewport._root_rows:
		if not candidate.attention_note.is_empty():
			stamped = candidate
	passed = _check("the canvas stamped the amber row", stamped != null, true) and passed
	if stamped == null:
		dock.free()
		return false
	passed = _check("and hung no note row under it", stamped.children.size(), 0) and passed
	dock._update_row_help_strip(stamped)
	passed = _check("selecting it puts the finding's sentence on the strip",
		dock._row_help_label.text,
		"This adds a node to the tree while the physics server is busy, and Godot refuses it. Add it on the next idle moment instead.") and passed
	passed = _check("and shows it", dock._row_help_label.visible, true) and passed
	passed = _check("with the door's own label on the button",
		dock._row_help_button.text, "Add it on the next idle moment") and passed
	passed = _check("and the button shown", dock._row_help_button.visible, true) and passed
	# The door itself: the strip's click respells the very line, through the undo funnel.
	dock.apply_selected_row_fix()
	var respelled: Variant = _live_event(dock).actions[0]
	passed = _check("the strip's door writes the deferred spelling of the same line",
		str((respelled as RawCodeRow).code) if respelled is RawCodeRow else "",
		"call_deferred(\"add_child\", Bullet.instantiate())") and passed
	# And nothing wrong means nothing said.
	dock._update_row_help_strip(EventRowData.new())
	passed = _check("a clean row hides the sentence", dock._row_help_label.visible, false) and passed
	passed = _check("and the door", dock._row_help_button.visible, false) and passed
	dock.free()
	return passed


# ── 7. The Doctor's section ──


static func _test_the_doctor_files_each_kind() -> bool:
	var passed: bool = true
	for kind: String in [EventSheetSpawnFindings.KIND_ADDED_DURING_PHYSICS,
			EventSheetSpawnFindings.KIND_MAYBE_FREED, EventSheetSpawnFindings.KIND_SPAWNS_ITSELF,
			EventSheetSpawnFindings.KIND_FREED_STILL_BOOKED]:
		passed = _check("the Doctor files \"%s\" under a check of its own" % kind,
			EventSheetSpawningDoctor.CHECK_FOR_KIND.has(kind), true) and passed
	# THE PRE-READ, which is what decides whether a script is opened at all. Asked per FUNCTION, so
	# the two words a rule needs have to be in ONE body: a file that parents somewhere and has a
	# physics callback somewhere else is not a candidate, and a file that does both in one is.
	passed = _check("a parenting inside a physics callback is worth opening",
		EventSheetSpawningDoctor.says_enough(
			"func _physics_process(delta: float) -> void:\n\tadd_child(Bullet.instantiate())\n"), true) and passed
	passed = _check("the same two words in different functions are not",
		EventSheetSpawningDoctor.says_enough(
			"func _physics_process(delta: float) -> void:\n\tposition.x += 1.0\n\n\nfunc build() -> void:\n\tadd_child(Label.new())\n"),
		false) and passed
	passed = _check("and a file that says neither is never opened",
		EventSheetSpawningDoctor.says_enough("func _process(delta: float) -> void:\n\tpass\n"),
		false) and passed
	# The maybe-freed pre-read is the one that spans functions, so it is narrowed by the DECLARATION
	# instead - and by ClassDB, which is the same question the removal guard asks of a sheet.
	passed = _check("a node kept in a variable and freed through its name is worth opening",
		EventSheetSpawningDoctor.says_enough("var boss: Node2D = null\n\n\nfunc go() -> void:\n\tboss.queue_free()\n"),
		true) and passed
	passed = _check("a number kept in a variable is not",
		EventSheetSpawningDoctor.says_enough("var score: int = 0\n\n\nfunc go() -> void:\n\tother.queue_free()\n"),
		false) and passed
	passed = _check("and a node freeing itself is not a stored reference",
		EventSheetSpawningDoctor.says_enough("var boss: Node2D = null\n\n\nfunc go() -> void:\n\tqueue_free()\n"),
		false) and passed
	# Ranking is what makes the ceilings safe: the strongest evidence is read first, and ties are
	# broken by path so two audits of an unchanged project read the same.
	passed = _check("a script that could earn two findings outweighs one that could earn one",
		EventSheetSpawningDoctor.evidence(
			"func _physics_process(delta: float) -> void:\n\tadd_child(Bullet.instantiate())\n\tget_tree().create_timer(1.0)\n\tfoe.queue_free()\n")
			> EventSheetSpawningDoctor.evidence("var boss: Node2D = null\n\n\nfunc go() -> void:\n\tboss.queue_free()\n"),
		true) and passed

	# A corpus with nothing in it reports nothing at all - the section does not announce itself to a
	# project that never spawns.
	passed = _check("a project that spawns nothing gets no section",
		EventSheetSpawningDoctor.report(PackedStringArray()).size(), 0) and passed
	# And the plugin's own folder is not the project author's code, so it is never in the corpus.
	passed = _check("the plugin's own scripts are left out of the corpus",
		EventSheetSpawningDoctor.report(PackedStringArray([
			"res://addons/eventforge/compiler/sheet_compiler.gd"])).size(), 0) and passed
	return passed


# ── Harness ──


static func _sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	return sheet


static func _event(trigger_id: String, actions: Array) -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = trigger_id
	for action: Variant in actions:
		event.actions.append(action)
	return event


static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params.duplicate()
	return action


static func _condition(ace_id: String, params: Dictionary) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.params = params.duplicate()
	return condition


## A verbatim block - the shape a hand-written line that never lifted keeps inside an event.
static func _raw(code: String) -> RawCodeRow:
	var block: RawCodeRow = RawCodeRow.new()
	block.code = code
	return block


static func _band_of(bands: Array[Dictionary], kind: String) -> Dictionary:
	for band: Dictionary in bands:
		if str(band.get("kind", "")) == kind:
			return band
	return {}


static func _kinds(found: Array[Dictionary]) -> PackedStringArray:
	var kinds: PackedStringArray = PackedStringArray()
	for entry: Dictionary in found:
		kinds.append(str(entry.get("kind", "")))
	return kinds


static func _message_of(found: Array[Dictionary], kind: String) -> String:
	return str(_entry_of(found, kind).get("message", ""))


static func _fix_of(found: Array[Dictionary], kind: String) -> String:
	return str(_entry_of(found, kind).get("fix", ""))


static func _label_of(found: Array[Dictionary], kind: String) -> String:
	return str(_entry_of(found, kind).get("fix_label", ""))


static func _entry_of(found: Array[Dictionary], kind: String) -> Dictionary:
	for entry: Dictionary in found:
		if str(entry.get("kind", "")) == kind:
			return entry
	return {}


static func _check(label: String, got: Variant, expected: Variant) -> bool:
	if got == expected:
		return true
	print("[FAIL] spawning_findings_test: %s -> expected %s, got %s" % [label, expected, got])
	return false


## The Doctor's own summary and one filed finding, produced from a real script on disk rather than
## reasoned about. `report` had only ever been asked for an EMPTY corpus and for a plugin-folder path,
## both of which answer with nothing, so the shape it files - the severity it passes through, the
## check id it maps a kind to, the path it points at, the file name it puts in front of the sentence,
## the subject it carries and the summary line itself - was held by nothing at all.
static func _test_the_doctor_files_a_real_finding() -> bool:
	var path: String = "user://eventforge_spawning_doctor_fixture.gd"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _check("the fixture script can be written", false, true)
	file.store_string(PHYSICS_SPAWN_SOURCE)
	file = null
	var filed: Array[Dictionary] = EventSheetSpawningDoctor.report(PackedStringArray([path]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var passed: bool = _check("the section files a summary and the finding under it", filed.size(), 2)
	if filed.size() != 2:
		return false
	# The summary counts candidates against scripts actually read, so a sampled run can never read as
	# a clean bill of health - and it points at the first script worth opening.
	passed = _check("the summary says what was found, what was read and what is wrong",
		str(filed[0].get("message", "")),
		"Spawning: 1 script(s) that add or destroy nodes, 1 read, 1 with something that will go wrong at run time.") and passed
	passed = _check("the summary is an info line under the section's own id",
		"%s/%s" % [str(filed[0].get("severity", "")), str(filed[0].get("check", ""))],
		"info/%s" % EventSheetSpawningDoctor.CHECK_ID) and passed
	passed = _check("and points at the script worth opening", str(filed[0].get("path", "")), path) and passed
	# And the finding itself, as the panel shows it: the family's own severity and wording, under the
	# check id its kind maps to, with the file named in front of the sentence.
	passed = _check("the finding keeps the family's severity",
		str(filed[1].get("severity", "")), "warning") and passed
	passed = _check("and is filed under the check its kind maps to",
		str(filed[1].get("check", "")), EventSheetSpawningDoctor.CHECK_PHYSICS) and passed
	passed = _check("and names the file in front of the sentence a reader acts on",
		str(filed[1].get("message", "")),
		"eventforge_spawning_doctor_fixture.gd This adds a node to the tree while the physics server is busy, and Godot refuses it. Add it on the next idle moment instead.") and passed
	passed = _check("and carries the name the row gave the copy",
		str(filed[1].get("subject", "")), "foe") and passed
	passed = _check("and the file a double-click would open", str(filed[1].get("path", "")), path) and passed
	return passed


## The fixture: a parenting inside the physics callback, which is the rule the pre-read admits on two
## words in one function body and the rules then confirm by reading the rows.
##
## WRITTEN AS ESCAPED LINES rather than as a `"""` block ON PURPOSE. This file is in the corpus the
## Doctor sweeps over its own repository, and a block quote would put a real `func _physics_process`
## with a real `add_child` at column 0 inside it - which this very section would then open, lift and
## report as a finding against the test that wrote it.
const PHYSICS_SPAWN_SOURCE: String = "extends Node2D\n\n\nfunc _physics_process(_delta: float) -> void:\n"\
	+ "\tvar foe = load(\"res://enemy.tscn\").instantiate()\n"\
	+ "\tadd_child(foe)\n\tfoe.global_position = global_position\n"
