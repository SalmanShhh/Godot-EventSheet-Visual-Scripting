# Godot EventSheets - the three traversal shapes read, claimed, and gated against the packs.
#
# A ledge grab, the three wall moves, a water volume. Each is a shape several lines make
# TOGETHER - a probe pair, a wall the body is touching, a flag raised on the way into a volume - so
# each is answered from a walk of the file and claimed in the pattern registry.
#
# What this pins, in the order the mistakes actually happen:
#   1. THE GATE. Every reading here is one word away from claiming a move that is not there. A lone
#      ray is not a ledge, a velocity write in a file that never touches a wall is not a wall move,
#      and `velocity *= 0.9` on its own is a slowdown, not a swim. The negative pins are the point.
#   2. THE WORDS. The exact sentence each shape reads as, pinned by VALUE.
#   3. THE PACKS. Every verb the hand-written shapes turn into is a shipped row on the
#      Traversal Kit (2D) and its 3D twin - pack parity, pinned by the published ACE names.
#
# The RUNTIME half (a grab that happens at a real lip, a wall jump that pushes away, a swimmer that
# sinks slower than a faller) needs a stepped physics world, which this suite has no main loop for.
# It is verified live in the traversal_course / traversal_course_3d showcases; the numbers that
# harness produced are written down beside the showcase checks in showcase_examples_test.gd.
@tool
class_name TraversalReadingsTest
extends RefCounted

## The ledge grab exactly as a tutorial writes it: two rays asked in one question, a flag raised at
## the lip, and the two exits.
const LEDGE_SOURCE: PackedStringArray = [
	"if not hanging and wall_ray.is_colliding() and not ledge_ray.is_colliding() and velocity.y > 0.0:",
	"hanging = true",
	"velocity = Vector2.ZERO",
	"if hanging:",
	"hanging = false",
	"velocity.y = -jump_speed"
]

## The same two rays with nothing above them: one cast, no pair, no ledge.
const ONE_RAY_SOURCE: PackedStringArray = [
	"if wall_ray.is_colliding():",
	"hanging = true",
	"if hanging:",
	"velocity = Vector2.ZERO"
]

## The three wall moves, each written the way the tutorial hands it over.
const WALL_SOURCE: PackedStringArray = [
	"if is_on_wall() and velocity.y > 0.0:",
	"velocity.y = min(velocity.y, slide_speed)",
	"var wall_normal := get_wall_normal()",
	"velocity = Vector2(-wall_normal.x * push, -jump)",
	"velocity.y += gravity * wall_run_scale * delta"
]

## Ordinary movement: gravity, a run, a damping. No wall is ever touched, so none of it is a wall
## move - this is the shadow the reading must not cast over every platformer in the world.
const PLAIN_SOURCE: PackedStringArray = [
	"velocity.y += gravity * delta",
	"velocity.x = move_toward(velocity.x, speed, accel * delta)",
	"velocity *= 0.9",
	"move_and_slide()"
]

## Water: the marked area toggles the flag, and the tick trades gravity for drag underneath it.
const WATER_SOURCE: PackedStringArray = [
	"in_water = true",
	"in_water = false",
	"if in_water:",
	"velocity.y += water_gravity * delta",
	"velocity *= 0.9"
]

## The same drag with no volume behind it: a slowdown, not a swim.
const DRAG_ONLY_SOURCE: PackedStringArray = [
	"if braking:",
	"velocity *= 0.9"
]


static func run() -> bool:
	var ok: bool = true
	ok = _ledge_reading() and ok
	ok = _wall_reading() and ok
	ok = _swim_reading() and ok
	ok = _registry() and ok
	ok = _pack_parity() and ok
	return ok


## The pair is the gate: one cast that hits and a higher one that is clear, in one question.
static func _ledge_reading() -> bool:
	var ok: bool = true
	ok = _check("two casts, one negated, read as the ledge test",
		EventSheetPatternReadings.is_ledge_probe_pair(
			"not hanging and wall_ray.is_colliding() and not ledge_ray.is_colliding() and velocity.y > 0.0"),
		true) and ok
	ok = _check("one cast is a ray, not a ledge",
		EventSheetPatternReadings.is_ledge_probe_pair("wall_ray.is_colliding()"), false) and ok
	ok = _check("two casts that must BOTH hit are not a ledge either",
		EventSheetPatternReadings.is_ledge_probe_pair(
			"wall_ray.is_colliding() and ledge_ray.is_colliding()"), false) and ok

	var claim: Dictionary = _claim_of(LEDGE_SOURCE, "ledge")
	ok = _check("the ledge shape says what it found",
		str(claim.get("words", "")),
		"a wall ahead with nothing above it is a ledge, and hanging is the hang it puts the body in") and ok
	ok = _check("and offers the kit that ships it",
		str(claim.get("adoptable", "")), "traversal_kit") and ok
	ok = _check("its evidence is the three statements that ARE the shape",
		" | ".join(claim.get("evidence", PackedStringArray())),
		"if not hanging and wall_ray.is_colliding() and not ledge_ray.is_colliding() and velocity.y > 0.0: | hanging = true | if hanging:") and ok
	ok = _check("a single ray claims nothing", _patterns_of(ONE_RAY_SOURCE), "") and ok
	return ok


## The wall the body is touching is the gate; which moves it carries is what the claim says.
static func _wall_reading() -> bool:
	var ok: bool = true
	var normals: PackedStringArray = PackedStringArray(["wall_normal"])
	ok = _check("a capped fall is the slide",
		EventSheetPatternReadings.wall_move_kind("velocity.y = min(velocity.y, slide_speed)", normals),
		"slide") and ok
	ok = _check("a velocity built from the wall's normal is the jump",
		EventSheetPatternReadings.wall_move_kind("velocity = Vector2(-wall_normal.x * push, -jump)", normals),
		"jump") and ok
	ok = _check("gravity scaled down is the run",
		EventSheetPatternReadings.wall_move_kind("velocity.y += gravity * wall_run_scale * delta", normals),
		"run") and ok
	ok = _check("plain gravity is still plain gravity",
		EventSheetPatternReadings.wall_move_kind("velocity.y += gravity * delta", normals), "") and ok

	var claim: Dictionary = _claim_of(WALL_SOURCE, "wall_move")
	ok = _check("the wall shape names all three moves",
		str(claim.get("words", "")),
		"the wall it is touching carries a capped slide down it, a jump away along its own normal and a run on reduced gravity") and ok
	ok = _check("and offers the kit that ships them",
		str(claim.get("adoptable", "")), "traversal_kit") and ok
	ok = _check("movement that never touches a wall claims nothing",
		_patterns_of(PLAIN_SOURCE), "") and ok
	return ok


## The volume is the gate: a flag with water in its name, raised AND lowered, in a file that
## actually swims.
static func _swim_reading() -> bool:
	var ok: bool = true
	var facts: Dictionary = EventSheetPatternReadings.facts(WATER_SOURCE)
	ok = _check("the file keeps one water flag",
		", ".join((facts.get("water_flags", {}) as Dictionary).keys()), "in_water") and ok
	ok = _check("drag with no volume behind it keeps no flag",
		", ".join((EventSheetPatternReadings.facts(DRAG_ONLY_SOURCE).get(
			"water_flags", {}) as Dictionary).keys()), "") and ok
	ok = _check("a fraction of the velocity is the drag",
		EventSheetPatternReadings.is_water_drag("velocity *= 0.9"), true) and ok
	ok = _check("but doubling it is a boost",
		EventSheetPatternReadings.is_water_drag("velocity *= 2.0"), false) and ok
	ok = _check("the water's own pull is the gravity swap",
		EventSheetPatternReadings.is_water_gravity_swap("velocity.y += water_gravity * delta"), true) and ok

	var claim: Dictionary = _claim_of(WATER_SOURCE, "swim")
	ok = _check("the water shape says what the flag buys",
		str(claim.get("words", "")),
		"while in_water is up, gravity is traded for the water's own pull and drag") and ok
	ok = _check("and offers the kit that ships it",
		str(claim.get("adoptable", "")), "traversal_kit") and ok
	ok = _check("a drag with no volume claims nothing", _patterns_of(DRAG_ONLY_SOURCE), "") and ok
	return ok


## The three ids are in the registry, each with a page of its own, and the 3D twin is offered when
## the shape is written in 3D.
static func _registry() -> bool:
	var ok: bool = true
	var missing: PackedStringArray = PackedStringArray()
	for id: String in ["ledge", "wall_move", "swim"]:
		if not EventSheetPatternFacts.PATTERN_IDS.has(id):
			missing.append(id)
	ok = _check("every traversal id is claimable", ", ".join(missing), "") and ok
	ok = _check("the ledge page names the shape",
		str((EventSheetPatternVocabulary.ENTRIES.get("ledge", {}) as Dictionary).get("words", "")),
		"Ledge grab") and ok
	ok = _check("the wall page names the shape",
		str((EventSheetPatternVocabulary.ENTRIES.get("wall_move", {}) as Dictionary).get("words", "")),
		"Wall moves") and ok
	ok = _check("the water page names the shape",
		str((EventSheetPatternVocabulary.ENTRIES.get("swim", {}) as Dictionary).get("words", "")),
		"Swimming") and ok
	ok = _check("both kits have a name to be offered under",
		"%s / %s" % [str(EventSheetPatternVocabulary.PACK_LABELS.get("traversal_kit", "")),
			str(EventSheetPatternVocabulary.PACK_LABELS.get("traversal_kit_3d", ""))],
		"Traversal Kit / Traversal Kit 3D") and ok

	var in_3d: PackedStringArray = PackedStringArray([
		"if not hanging and wall_ray.is_colliding() and not ledge_ray.is_colliding():",
		"hanging = true",
		"velocity = Vector3.ZERO",
		"if hanging:",
		"velocity.y = jump_speed"
	])
	ok = _check("a shape written in 3D offers the 3D kit",
		str(_claim_of(in_3d, "ledge").get("adoptable", "")), "traversal_kit_3d") and ok
	return ok


## Pack parity: every verb the readings name is a shipped row on both kits, under the same words.
static func _pack_parity() -> bool:
	var ok: bool = true
	var expected: String = "Climb Ladder, Climb Up, Crouch, Drop, Grab Ledge, Is Above The Surface, " \
		+ "Is At A Ledge, Is At A Vaultable Obstacle, Is Crouching, Is Hanging, Is In Water, " \
		+ "Is On Ladder, Is Wall Running, Is Wall Sliding, Slide Down Wall, Stand, Swim, Vault Over, " \
		+ "Wall Jump, Wall Run, Water Depth"
	ok = _check("the 2D kit publishes the traversal words",
		_published("res://eventsheet_addons/traversal_kit/traversal_kit_behavior.gd"), expected) and ok
	ok = _check("the 3D kit publishes the same words plus Float",
		_published("res://eventsheet_addons/traversal_kit_3d/traversal_kit_3d_behavior.gd"),
		expected.replace("Grab Ledge, ", "Float, Grab Ledge, ")) and ok
	ok = _check("and both fire the ledge triggers",
		_triggers("res://eventsheet_addons/traversal_kit/traversal_kit_behavior.gd"),
		"On Climbed, On Entered Water, On Ledge Grabbed, On Left Water, On Vaulted") and ok
	return ok


## The published verb names of a pack, sorted - read off the shipped file the way the picker does.
static func _published(path: String) -> String:
	return _names_after(path, ["## @ace_action", "## @ace_condition", "## @ace_expression"])


## The published trigger names of a pack, sorted.
static func _triggers(path: String) -> String:
	return _names_after(path, ["## @ace_trigger"])


## Every `## @ace_name("X")` that follows one of the given markers, sorted and joined.
static func _names_after(path: String, markers: Array) -> String:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return "MISSING %s" % path
	var names: Array[String] = []
	var armed: bool = false
	for line: String in text.split("\n"):
		var trimmed: String = line.strip_edges()
		if markers.has(trimmed):
			armed = true
			continue
		if not trimmed.begins_with("## @ace_name("):
			continue
		if armed:
			names.append(trimmed.substr(14, trimmed.length() - 16))
		armed = false
	names.sort()
	return ", ".join(names)


## The one claim of a pattern a body makes, or {} when it makes none.
static func _claim_of(body: PackedStringArray, pattern: String) -> Dictionary:
	for claim: Dictionary in EventSheetPatternReadings.game_shape_claims(
			body, EventSheetPatternReadings.facts(body)):
		if str(claim.get("pattern", "")) == pattern:
			return claim
	return {}


## Every pattern a body claims, sorted and joined - "" when it claims none.
static func _patterns_of(body: PackedStringArray) -> String:
	var found: Array[String] = []
	for claim: Dictionary in EventSheetPatternReadings.game_shape_claims(
			body, EventSheetPatternReadings.facts(body)):
		found.append(str(claim.get("pattern", "")))
	found.sort()
	return ", ".join(found)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] traversal_readings_test: %s" % label)
		return true
	print("[FAIL] traversal_readings_test: %s (expected %s, got %s)" % [label, str(expected), str(actual)])
	return false
