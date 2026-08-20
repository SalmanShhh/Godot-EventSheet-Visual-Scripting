@tool
class_name EventSheetPatternReadings
extends RefCounted

# The SHEET-WIDE facts behind the pattern readings, and the one walk that claims them.
#
# A pattern is a shape several lines make together, so no single line can decide it. `cooldown -=
# delta` is arithmetic until somewhere else in the file asks whether `cooldown` has reached zero;
# `pool.pop_back()` is a list step until an `is_empty()` guard and an `instantiate()` fallback stand
# beside it. Those questions are answered ONCE per rebuild here, handed to the sentence grammar as
# ordinary context keys, and claimed in the pattern registry on the event that owns them.
#
# Everything here reads the sheet and answers questions. Nothing here edits a row, and nothing a
# reading decides may change what is emitted: the file is untouched and the byte round-trip cannot
# move. Every function is static and takes the sheet, so a test can pin a fact without a viewport.

## The words a per-frame delta is written in. Only these four: a variable that happens to shrink by
## some other number every tick is a subtraction, and calling it a countdown would be a guess.
const DELTA_WORDS: PackedStringArray = [
	"delta", "_delta", "get_process_delta_time()", "get_physics_process_delta_time()"
]

## The clamped spellings of the same countdown, as {call name: how the row says it stays above zero}.
const CLAMPED_COUNTDOWNS: Dictionary = {
	"max": "never below 0", "maxf": "never below 0", "move_toward": "never below 0"
}

## The list steps that TAKE something out of a pool, in the order a pool is usually drained.
const POOL_TAKE_METHODS: PackedStringArray = ["pop_back", "pop_front"]

## The steps a returned object is put to sleep with, and the one that puts it back. Any subset of the
## sleep steps in any order counts: which of them a project uses is a matter of what its objects do.
const POOL_SLEEP_METHODS: PackedStringArray = [
	"hide", "set_process", "set_physics_process", "set_process_input", "set_deferred"
]

## The step that returns the object to the list it came from.
const POOL_RETURN_METHODS: PackedStringArray = ["push_back", "push_front", "append"]


## Everything the sentence grammar needs to know about the patterns THIS sheet writes, merged into
## the row builder's sentence context once per rebuild:
##
##   "countdown_variables" {name: how it stays above zero, "" for a plain `-= delta`}
##   "pool_variables"      {name: true}   - the lists used as object pools
##   "state_machine"       the FSM this file writes out, {} when it writes none (S1)
##
## Takes the file's lines rather than the sheet, so nothing here has to know what a sheet is: the
## caller already walks the rows once for the other fact maps and hands the same lines to all of them.
static func facts(lines: PackedStringArray) -> Dictionary:
	var machine: Dictionary = EventSheetStateMachineFacts.facts(lines)
	if not machine.is_empty():
		# The declarations the one FSM line stands for ride along with the facts, so the claim can
		# show them as its evidence without a second walk over the file.
		machine["evidence"] = EventSheetStateMachineFacts.evidence(lines, machine)
	return {
		"countdown_variables": countdown_variables(lines),
		"pool_variables": pool_variables(lines),
		"state_machine": machine
	}


## S3. Whether a function body is a SEQUENCE - rows that alternate waiting and doing, which is what
## a cutscene, an intro and a combo are made of - as {waits, seconds, open_ended} or {} when it is not.
##
##   waits       how many times the body stops and waits
##   seconds     the timer waits added up, so the header can say how long the whole thing takes
##   open_ended  true when one of the waits is on something whose length nobody knows (an animation,
##               a signal), which is why the header says "+ a wait" rather than a wrong total
##
## Two waits at least, and something to do between them: one `await` in a function is a pause, not a
## sequence, and reading it as one would promise a structure that is not there.
static func wait_sequence(body: PackedStringArray) -> Dictionary:
	var waits: int = 0
	var seconds: float = 0.0
	var open_ended: bool = false
	var steps: int = 0
	for line: String in body:
		var text: String = line.strip_edges()
		if text.is_empty() or text.begins_with("#"):
			continue
		if not text.begins_with("await "):
			steps += 1
			continue
		waits += 1
		var timed: String = _timer_wait_seconds(text)
		if timed.is_empty():
			open_ended = true
		else:
			seconds += timed.to_float()
	if waits < 2 or steps < 1:
		return {}
	return {"waits": waits, "seconds": seconds, "open_ended": open_ended}


## The seconds an `await get_tree().create_timer(N).timeout` waits, or "" for any other await.
static func _timer_wait_seconds(line: String) -> String:
	const HEAD := "await get_tree().create_timer("
	const TAIL := ").timeout"
	if not line.begins_with(HEAD) or not line.ends_with(TAIL):
		return ""
	var inner: String = line.substr(HEAD.length(), line.length() - HEAD.length() - TAIL.length()).strip_edges()
	return inner if inner.is_valid_float() else ""


## S3. What the chip on a sequence's header says: how long the whole run takes, and whether one of
## its waits is on something whose length nobody knows.
static func wait_sequence_words(facts: Dictionary) -> String:
	if facts.is_empty():
		return ""
	var seconds: float = float(facts.get("seconds", 0.0))
	var total: String = "%s s" % String.num(seconds, 2).trim_suffix("0").trim_suffix("0").trim_suffix(".")
	if bool(facts.get("open_ended", false)):
		return "%s %s + %s" % [EventSheetL10n.translate("sequence ·"), total,
			EventSheetL10n.translate("a wait")]
	return "%s %s" % [EventSheetL10n.translate("sequence ·"), total]


## The patterns a BODY writes, given the whole file's facts, as an array of
## {pattern, evidence, words, adoptable, ace_ids} ready to hand to the registry. `body` is the lines
## of one owning unit - a trigger event, a tick event, a function - and `facts` is what `facts()`
## answered for the whole file, because a countdown counted here may be asked about anywhere.
##
## The evidence is the exact source lines, never a paraphrase: the chip that shows it is showing the
## reader why the row says what it says, and a paraphrase there would be a second reading to distrust.
static func claims_in(body: PackedStringArray, file_facts: Dictionary) -> Array:
	var found: Array = []
	var countdowns: Dictionary = file_facts.get("countdown_variables", {})
	var pools: Dictionary = file_facts.get("pool_variables", {})
	var countdown_evidence: PackedStringArray = PackedStringArray()
	var countdown_names: PackedStringArray = PackedStringArray()
	var pool_evidence: PackedStringArray = PackedStringArray()
	var pool_names: PackedStringArray = PackedStringArray()
	for line: String in body:
		var text: String = line.strip_edges()
		if text.is_empty():
			continue
		var step: Dictionary = countdown_step(text)
		var counted: String = str(step.get("name", ""))
		if not counted.is_empty() and countdowns.has(counted):
			countdown_evidence.append(text)
			if not countdown_names.has(counted):
				countdown_names.append(counted)
		var taken: Dictionary = pool_take_parts(text)
		if not taken.is_empty():
			pool_evidence.append(text)
			var pool_name: String = str(taken.get("pool", ""))
			if not pool_names.has(pool_name):
				pool_names.append(pool_name)
			continue
		var returned: Dictionary = pool_return_step(text, pools)
		if str(returned.get("kind", "")) == "return":
			pool_evidence.append(text)
			var back_to: String = str(returned.get("pool", ""))
			if not pool_names.has(back_to):
				pool_names.append(back_to)
	if not countdown_evidence.is_empty():
		found.append({
			"pattern": "countdown", "evidence": countdown_evidence,
			"words": "counts %s down and asks whether it has run out" % ", ".join(countdown_names),
			"adoptable": "", "ace_ids": PackedStringArray(["Core/StartCooldown", "Core/CooldownReady"])
		})
	var sequence: Dictionary = wait_sequence(body)
	if not sequence.is_empty():
		var beats: PackedStringArray = PackedStringArray()
		for line: String in body:
			if line.strip_edges().begins_with("await "):
				beats.append(line.strip_edges())
		found.append({
			"pattern": "wait_sequence", "evidence": beats, "words": wait_sequence_words(sequence),
			"adoptable": "", "ace_ids": PackedStringArray()
		})
	var nearest: Dictionary = nearest_pick(body)
	if not nearest.is_empty():
		found.append({
			"pattern": "picking", "evidence": nearest.get("evidence", PackedStringArray()),
			"words": str(nearest.get("words", "")), "adoptable": "",
			"ace_ids": PackedStringArray(["Core/PickNearest", "Core/PickFarthest",
				"Core/PickRandomInstance", "Core/PickWhere", "Core/PickByUid"])
		})
	if not pool_evidence.is_empty():
		found.append({
			"pattern": "object_pool", "evidence": pool_evidence,
			"words": "reuses objects from %s instead of making a new one" % ", ".join(pool_names),
			"adoptable": "object_pool", "ace_ids": PackedStringArray()
		})
	# X2 / X30. The camera-ray run, and X20's nearest-on-the-canvas walk. Both are SHAPES spread over
	# several lines joined only by their locals' names, so they are claimed here rather than read as a
	# row: the rows stay exactly as they are, and the chip, the hover evidence and the coverage count
	# get the one sentence each shape is.
	var ray: Dictionary = cursor_ray_run(body)
	if not ray.is_empty():
		var aimed_at: String = str(ray.get("aimed", ""))
		var by_mouse: bool = aimed_at.is_empty() or aimed_at == EventSheetSentence.CURSOR_MOUSE_POINT
		found.append({
			"pattern": "cursor_ray", "evidence": ray.get("evidence", PackedStringArray()),
			"words": "asks what is under the cursor" if by_mouse else "asks what the crosshair is aimed at",
			"adoptable": "", "ace_ids": PackedStringArray(["Core/MouseRayCollider3D",
				"Core/MouseRayPoint3D", "Core/CastMouseRayInto3D"])
		})
	var canvas_pick: Dictionary = canvas_nearest_pick(body)
	if not canvas_pick.is_empty():
		found.append({
			"pattern": "aim_assist", "evidence": canvas_pick.get("evidence", PackedStringArray()),
			"words": "keeps the one nearest the crosshair, measured on the canvas in pixels",
			"adoptable": "", "ace_ids": PackedStringArray(["Core/PickNearestToCanvasPoint"])
		})
	var machine_claim: Dictionary = state_machine_claim(body, file_facts)
	if not machine_claim.is_empty():
		found.append(machine_claim)
	var circle_claim: Dictionary = polar_claim(body)
	if not circle_claim.is_empty():
		found.append(circle_claim)
	return found


## X31. The two shapes a body draws with an angle and a distance: a RING - a loop that gives each step
## its share of a full turn and places something at that angle - and a SPIRAL, where the angle and the
## distance both grow every tick and a place is worked out from the pair.
##
## A lone conversion is an expression, not a pattern: `Vector2.from_angle(a) * r` on its own is one
## value with one sentence, and a marker beside it would say nothing the row does not already.
## Returns {pattern, evidence, words, adoptable, ace_ids} or {} when the body draws neither.
static func polar_claim(body: PackedStringArray) -> Dictionary:
	var share_lines: PackedStringArray = PackedStringArray()
	var point_lines: PackedStringArray = PackedStringArray()
	for line: String in body:
		var text: String = line.strip_edges()
		if text.is_empty() or text.begins_with("#"):
			continue
		var value: String = text
		var assign_at: int = EventSheetSentence.top_level_index(text, " = ")
		if assign_at > 0:
			value = text.substr(assign_at + 3).strip_edges()
		var declared_at: int = EventSheetSentence.top_level_index(text, " := ")
		if declared_at > 0:
			value = text.substr(declared_at + 4).strip_edges()
		if not EventSheetSentence.turn_share_index(value).is_empty():
			share_lines.append(text)
			continue
		if _holds_polar_point(value):
			point_lines.append(text)
	if point_lines.is_empty():
		return {}
	var evidence: PackedStringArray = PackedStringArray()
	evidence.append_array(share_lines)
	evidence.append_array(point_lines)
	# A ring is the loop's share of a turn placed at a distance; a spiral is the same point worked out
	# without one, which is what the growing angle and radius above it make it.
	var ring: bool = not share_lines.is_empty()
	return {
		"pattern": "polar", "evidence": evidence,
		"words": "places things evenly around a circle" if ring \
			else "works a place out as an angle and a distance",
		"adoptable": "", "ace_ids": PackedStringArray(["Core/CreateAroundCircle", "Core/PointAtAngle"])
	}


## X31. True when a value works a POINT out of an angle and a distance anywhere inside it, so the
## `centre + <point>` a spiral is written as counts as much as the bare product a ring uses.
static func _holds_polar_point(value: String) -> bool:
	var text: String = value.strip_edges()
	if not EventSheetSentence.polar_point_words(text, {}).is_empty():
		return true
	for operator: String in [" + ", " - "]:
		var at: int = EventSheetSentence.top_level_index(text, operator)
		if at <= 0:
			continue
		if not EventSheetSentence.polar_point_words(text.substr(at + 3), {}).is_empty():
			return true
	return false


## T8. The nearest-or-farthest LOOP a body writes: walk a list, measure the distance to each one,
## keep the best so far. An event sheet says that in one row - Pick nearest / Pick farthest - and no
## single line of the loop is it, which is why it is recognised here rather than in the grammar.
##
## Returns {evidence, words, farthest} or {} when the body holds no such loop. All three halves are
## required - the walk, the measurement, and a best-so-far comparison that keeps the winner - so a
## loop that merely measures something stays the loop it is.
static func nearest_pick(body: PackedStringArray) -> Dictionary:
	var evidence: PackedStringArray = PackedStringArray()
	var iterator_name: String = ""
	var measured: bool = false
	var kept: bool = false
	var farthest: bool = false
	for line: String in body:
		var text: String = line.strip_edges()
		if text.is_empty() or text.begins_with("#"):
			continue
		if text.begins_with("for ") and text.ends_with(":"):
			var head: String = text.substr(4, text.length() - 5)
			var in_at: int = EventSheetSentence.top_level_index(head, " in ")
			var walker: String = _loop_variable_name(head.substr(0, in_at).strip_edges()) if in_at > 0 else ""
			if not walker.is_empty():
				iterator_name = walker
				measured = false
				kept = false
				evidence = PackedStringArray([text])
			continue
		if iterator_name.is_empty():
			continue
		if text.contains(".distance_to(") or text.contains(".distance_squared_to("):
			measured = true
			evidence.append(text)
			continue
		# The comparison says which end of the walk is being kept: `<` keeps the nearest so far, `>`
		# the farthest. Anything else is a loop that measures and does something the sheet has no one
		# word for, so nothing is claimed.
		# A lifted condition arrives as the bare test - the `if` and its colon are the row now - so both
		# spellings are read, or a lifted farthest loop would be told back to its author as a nearest one.
		var test: String = text
		if test.begins_with("if ") and test.ends_with(":"):
			test = test.substr(3, test.length() - 4).strip_edges()
		if EventSheetSentence.top_level_index(test, " = ") <= 0:
			if EventSheetSentence.top_level_index(test, " < ") > 0:
				evidence.append(text)
				continue
			if EventSheetSentence.top_level_index(test, " > ") > 0:
				farthest = true
				evidence.append(text)
				continue
		if test != text:
			continue
		var assign_at: int = EventSheetSentence.top_level_index(text, " = ")
		if assign_at > 0 and text.substr(assign_at + 3).strip_edges() == iterator_name:
			kept = true
			evidence.append(text)
	if iterator_name.is_empty() or not measured or not kept:
		return {}
	return {
		"evidence": evidence, "farthest": farthest,
		"words": "picks the farthest one by distance" if farthest else "picks the nearest one by distance"
	}


## The name a `for` loop walks under, with a written-out type set aside: `foe` for both `for foe in`
## and `for foe: Node2D in`. The typed spelling is the one a careful project writes, so reading only
## the bare one would quietly skip every loop in a typed file. "" when the head is not a plain name.
static func _loop_variable_name(head: String) -> String:
	var text: String = head.strip_edges()
	var colon_at: int = text.find(":")
	if colon_at >= 0:
		text = text.substr(0, colon_at).strip_edges()
	return text if EventSheetSentence.is_identifier(text) else ""


## S1. The shipped behavior a hand-rolled state machine could be replaced by. Named here rather than
## guessed at from a row, so the chip, Adopt behavior and the Doctor all offer the same one.
const STATE_MACHINE_PACK: String = "StateMachineBehavior"


## S1. The state-machine claim a BODY makes, or {} when its lines never turn the machine or ask about
## it. A machine is a fact about the FILE, but the claim belongs on the event that drives it: an
## enum nobody switches on is a list of names, and marking every event of the file would say nothing.
static func state_machine_claim(body: PackedStringArray, file_facts: Dictionary) -> Dictionary:
	var machine: Dictionary = file_facts.get("state_machine", {})
	if machine.is_empty():
		return {}
	var current: String = str(machine.get("variable", ""))
	var previous: String = str(machine.get("previous", ""))
	var transition: String = str(machine.get("transition", ""))
	var used: bool = false
	for line: String in body:
		var text: String = line.strip_edges()
		if text.is_empty():
			continue
		if not transition.is_empty() and text.contains("%s(" % transition):
			used = true
			break
		for word: String in [current, previous]:
			if word.is_empty():
				continue
			if text.begins_with("%s " % word) or text.contains(" %s " % word) or text.contains("[%s]" % word):
				used = true
				break
		if used:
			break
	if not used:
		return {}
	return {
		"pattern": "state_machine", "evidence": machine.get("evidence", PackedStringArray()),
		"words": "one named state at a time, switched by Go to state",
		"adoptable": STATE_MACHINE_PACK, "ace_ids": PackedStringArray()
	}


## S4. The numbers this file uses as countdowns: counted DOWN by a per-frame delta somewhere and
## compared against zero somewhere else. Both halves are required, so an ordinary subtraction stays a
## subtraction and a number merely compared to zero stays a comparison.
##
## The value is the note the Count down row shows: "" for a bare `x -= delta`, "never below 0" for
## the clamped spellings, which is the one thing those add and the one thing a reader wants told.
static func countdown_variables(lines: PackedStringArray) -> Dictionary:
	var counted: Dictionary = {}
	var compared: Dictionary = {}
	for line: String in lines:
		var text: String = line.strip_edges()
		if text.is_empty():
			continue
		var down: Dictionary = countdown_step(text)
		if not down.is_empty():
			var name_text: String = str(down.get("name", ""))
			# The clamped spelling wins when a file uses both: it is the stronger statement, and it is
			# the one whose note a reader needs.
			if not counted.has(name_text) or str(counted[name_text]).is_empty():
				counted[name_text] = str(down.get("note", ""))
		for zero_name: String in _zero_comparisons(text):
			compared[zero_name] = true
	var out: Dictionary = {}
	for name_text: String in counted:
		if compared.has(name_text):
			out[name_text] = counted[name_text]
	return out


## S4. The countdown step a line IS, as {name, note}, or {} when the line is not one. The three
## spellings a jam script writes:
##
##   cooldown -= delta                            {name: "cooldown", note: ""}
##   invincible_for = max(0.0, invincible_for - delta)   {name: ..., note: "never below 0"}
##   fuse = move_toward(fuse, 0, delta)                  {name: ..., note: "never below 0"}
static func countdown_step(line: String) -> Dictionary:
	var text: String = line.strip_edges()
	var minus_at: int = EventSheetSentence.top_level_index(text, " -= ")
	if minus_at > 0:
		var target: String = text.substr(0, minus_at).strip_edges()
		var amount: String = text.substr(minus_at + 4).strip_edges()
		if EventSheetSentence.is_identifier(target) and is_delta_value(amount):
			return {"name": target, "note": ""}
	var equals_at: int = EventSheetSentence.top_level_index(text, " = ")
	if equals_at <= 0:
		return {}
	var name_text: String = text.substr(0, equals_at).strip_edges()
	var value: String = text.substr(equals_at + 3).strip_edges()
	if not EventSheetSentence.is_identifier(name_text):
		return {}
	var call: Dictionary = EventSheetSentence.call_parts(value)
	if call.is_empty() or not str(call.get("target", "")).is_empty():
		return {}
	var head: String = str(call.get("method", ""))
	if not CLAMPED_COUNTDOWNS.has(head):
		return {}
	var args: PackedStringArray = call.get("args", PackedStringArray())
	if head == "move_toward":
		if args.size() != 3 or args[0].strip_edges() != name_text or not _is_zero(args[1]) \
				or not is_delta_value(args[2]):
			return {}
		return {"name": name_text, "note": str(CLAMPED_COUNTDOWNS[head])}
	if args.size() != 2 or not _is_zero(args[0]):
		return {}
	if not _is_delta_subtraction(args[1], name_text):
		return {}
	return {"name": name_text, "note": str(CLAMPED_COUNTDOWNS[head])}


## True when a value is the per-frame delta under one of its four names.
static func is_delta_value(value: String) -> bool:
	return DELTA_WORDS.has(value.strip_edges())


## True when a value is `<name> - <delta>`, the inner half of a clamped countdown.
static func _is_delta_subtraction(value: String, name_text: String) -> bool:
	var text: String = value.strip_edges()
	var minus_at: int = EventSheetSentence.top_level_index(text, " - ")
	if minus_at <= 0:
		return false
	return text.substr(0, minus_at).strip_edges() == name_text and is_delta_value(text.substr(minus_at + 3))


## True for the two spellings of zero a clamp is written with.
static func _is_zero(value: String) -> bool:
	var text: String = value.strip_edges()
	return text == "0" or text == "0.0"


## S4. Every identifier a line compares against zero - `cooldown <= 0`, `fuse > 0`, `hp == 0`. Only a
## bare identifier on the left counts: `stats["hp"] > 0` asks about a table entry, which is a
## different sentence with a different name.
static func _zero_comparisons(line: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for operator: String in [" <= ", " >= ", " == ", " < ", " > "]:
		var search_from: int = 0
		while true:
			var at: int = line.find(operator, search_from)
			if at < 0:
				break
			search_from = at + operator.length()
			if not _is_zero(_leading_number(line.substr(at + operator.length()))):
				continue
			var left: String = _trailing_identifier(line.substr(0, at))
			if not left.is_empty() and not found.has(left):
				found.append(left)
	return found


## The number a piece of text STARTS with, or "" when it starts with anything else. What the right
## side of `fuse <= 0:` is once the `if`'s colon and whatever follows the comparison are set aside.
static func _leading_number(text: String) -> String:
	var trimmed: String = text.strip_edges()
	var length: int = 0
	while length < trimmed.length() and (trimmed[length] == "." or (trimmed[length] >= "0" and trimmed[length] <= "9")):
		length += 1
	return trimmed.substr(0, length)


## The identifier a piece of text ENDS in, or "" when it ends in anything else (a call, an index, a
## member read). What decides whether a comparison is about a plain variable of this file.
static func _trailing_identifier(text: String) -> String:
	var trimmed: String = text.strip_edges()
	var start: int = trimmed.length()
	while start > 0 and _is_word_character(trimmed[start - 1]):
		start -= 1
	if start >= trimmed.length():
		return ""
	if start > 0 and (trimmed[start - 1] == "." or trimmed[start - 1] == "\"" or trimmed[start - 1] == "'"):
		return ""
	var word: String = trimmed.substr(start)
	return word if EventSheetSentence.is_identifier(word) else ""


static func _is_word_character(character: String) -> bool:
	return character == "_" or character.is_valid_identifier() or (character >= "0" and character <= "9")


## S2. The lists this file uses as object pools: drained through `pop_back()` / `pop_front()` behind
## an `is_empty()` guard with an `instantiate()` fallback, and refilled with `push_back()`. The guard
## is what makes it a pool rather than a queue, so it is required.
static func pool_variables(lines: PackedStringArray) -> Dictionary:
	var pools: Dictionary = {}
	for line: String in lines:
		var taken: Dictionary = pool_take_parts(line.strip_edges())
		if not taken.is_empty():
			pools[str(taken.get("pool", ""))] = true
	return pools


## S2. The pooled-Create line, as {pool, scene, alias} or {} when the line is not one:
##
##   var b = pool.pop_back() if not pool.is_empty() else BULLET.instantiate()
##   var b = BULLET.instantiate() if pool.is_empty() else pool.pop_back()
##
## Both orders of the ternary are read, because both are written. The declaration keyword is
## optional so a plain re-assignment to an existing variable reads the same.
static func pool_take_parts(line: String) -> Dictionary:
	var text: String = line.strip_edges()
	for keyword: String in ["var ", "const "]:
		if text.begins_with(keyword):
			text = text.substr(keyword.length()).strip_edges()
	var alias: String = ""
	var value: String = ""
	for separator: String in [" := ", " = "]:
		var at: int = EventSheetSentence.top_level_index(text, separator)
		if at <= 0:
			continue
		alias = text.substr(0, at).strip_edges()
		var colon_at: int = alias.find(":")
		if colon_at >= 0:
			alias = alias.substr(0, colon_at).strip_edges()
		value = text.substr(at + separator.length()).strip_edges()
		break
	if alias.is_empty() or value.is_empty() or not EventSheetSentence.is_identifier(alias):
		return {}
	var branches: Array = EventSheetSentence.value_branches(value)
	if branches.size() != 2:
		return {}
	var when_true: String = str((branches[0] as Dictionary).get("code", "")).strip_edges()
	var test: String = str((branches[0] as Dictionary).get("condition", "")).strip_edges()
	var when_false: String = str((branches[1] as Dictionary).get("code", "")).strip_edges()
	if test.is_empty():
		return {}
	var negated: bool = test.begins_with("not ")
	if negated:
		test = test.substr(4).strip_edges()
	var pool_name: String = _empty_test_pool(test)
	if pool_name.is_empty():
		return {}
	# `not pool.is_empty()` takes from the pool when the test holds; a bare `pool.is_empty()` makes a
	# new one instead, so the two halves swap.
	var take_text: String = when_true if negated else when_false
	var make_text: String = when_false if negated else when_true
	if _pool_take_of(take_text) != pool_name:
		return {}
	var scene: String = _instantiated_source(make_text)
	if scene.is_empty():
		return {}
	return {"pool": pool_name, "scene": scene, "alias": alias}


## The list a `pool.is_empty()` asks about, or "" for anything else.
static func _empty_test_pool(text: String) -> String:
	if not text.ends_with(".is_empty()"):
		return ""
	var name_text: String = text.substr(0, text.length() - 11).strip_edges()
	return name_text if EventSheetSentence.is_identifier(name_text) else ""


## The list a `pool.pop_back()` drains, or "" for anything else.
static func _pool_take_of(text: String) -> String:
	for method: String in POOL_TAKE_METHODS:
		var suffix: String = ".%s()" % method
		if not text.ends_with(suffix):
			continue
		var name_text: String = text.substr(0, text.length() - suffix.length()).strip_edges()
		return name_text if EventSheetSentence.is_identifier(name_text) else ""
	return ""


## The scene a `BULLET.instantiate()` makes, or "" for anything else.
static func _instantiated_source(text: String) -> String:
	if not text.ends_with(".instantiate()"):
		return ""
	var source: String = text.substr(0, text.length() - 14).strip_edges()
	return source if EventSheetSentence.is_identifier(source) else ""


## S2. The step a line is in a Return-to-pool run, as {kind, object, pool} or {}:
##   "sleep"  b.hide() / b.set_process(false) / b.set_physics_process(false)
##   "return" pool.push_back(b)
static func pool_return_step(line: String, pools: Dictionary) -> Dictionary:
	var text: String = line.strip_edges()
	var call: Dictionary = EventSheetSentence.call_parts(text)
	if call.is_empty():
		return {}
	var args: PackedStringArray = call.get("args", PackedStringArray())
	var receiver: String = str(call.get("target", "")).strip_edges()
	var method: String = str(call.get("method", "")).strip_edges()
	if not EventSheetSentence.is_identifier(receiver):
		return {}
	if POOL_RETURN_METHODS.has(method) and args.size() == 1 and pools.has(receiver):
		return {"kind": "return", "object": args[0].strip_edges(), "pool": receiver}
	if not POOL_SLEEP_METHODS.has(method):
		return {}
	if method == "hide" and args.is_empty():
		return {"kind": "sleep", "object": receiver, "pool": ""}
	if method == "set_deferred" and args.size() == 2:
		return {"kind": "sleep", "object": receiver, "pool": ""}
	if args.size() == 1 and args[0].strip_edges() == "false":
		return {"kind": "sleep", "object": receiver, "pool": ""}
	return {}


## X2 / X30. The camera-ray run a body writes, as {evidence, aimed}, or {} when it writes none. The
## four lines only mean anything together, and the question they ask - what is under the cursor - is
## the thing a reader is looking for when they open the file.
static func cursor_ray_run(body: PackedStringArray) -> Dictionary:
	var evidence: PackedStringArray = PackedStringArray()
	var origin_name: String = ""
	var direction_name: String = ""
	var query_name: String = ""
	var aimed: String = ""
	for line: String in body:
		var text: String = line.strip_edges()
		if text.is_empty() or text.begins_with("#"):
			continue
		var value: String = text
		if text.begins_with("var "):
			for separator: String in [" := ", " = "]:
				var at: int = text.find(separator)
				if at >= 0:
					value = text.substr(at + separator.length()).strip_edges()
					break
		var step: Dictionary = EventSheetSentence.cursor_ray_step_parts(value)
		match str(step.get("step", "")):
			"project_ray_origin":
				origin_name = _cursor_ray_name(text)
				aimed = str(step.get("point", ""))
				evidence = PackedStringArray([text])
			"project_ray_normal":
				if origin_name.is_empty() or str(step.get("point", "")) != aimed:
					continue
				direction_name = _cursor_ray_name(text)
				evidence.append(text)
			"query":
				if direction_name.is_empty():
					continue
				if EventSheetSentence.cursor_ray_reach(str(step.get("to", "")), origin_name,
						direction_name).is_empty():
					continue
				query_name = _cursor_ray_name(text)
				evidence.append(text)
			"cast":
				if query_name.is_empty() or str(step.get("query", "")) != query_name:
					continue
				evidence.append(text)
				return {"evidence": evidence, "aimed": aimed}
	return {}


## X20. The nearest-on-the-CANVAS walk a body writes, as {evidence}, or {} when it writes none. The
## difference from the ordinary nearest pick is the whole point: a distance measured between canvas
## points is in PIXELS, so the pick honours camera zoom, which is exactly what a crosshair must do
## and what a world-distance pick silently gets wrong.
static func canvas_nearest_pick(body: PackedStringArray) -> Dictionary:
	var evidence: PackedStringArray = PackedStringArray()
	var canvas_locals: Dictionary = {}
	var iterator_name: String = ""
	var measured: bool = false
	var kept: bool = false
	for line: String in body:
		var text: String = line.strip_edges()
		if text.is_empty() or text.begins_with("#"):
			continue
		if text.begins_with("for ") and text.ends_with(":"):
			var head: String = text.substr(4, text.length() - 5)
			var in_at: int = EventSheetSentence.top_level_index(head, " in ")
			if in_at > 0 and EventSheetSentence.is_identifier(head.substr(0, in_at).strip_edges()):
				iterator_name = head.substr(0, in_at).strip_edges()
				measured = false
				kept = false
				evidence = PackedStringArray([text])
			continue
		var declared: String = _cursor_ray_name(text)
		if not declared.is_empty():
			var value: String = text.substr(text.find(declared) + declared.length())
			for separator: String in [":= ", "= "]:
				var at: int = value.find(separator)
				if at >= 0:
					value = value.substr(at + separator.length()).strip_edges()
					break
			if not EventSheetSentence.canvas_position_words(value, {}).is_empty() \
					or not EventSheetSentence.canvas_centre_words(value).is_empty():
				canvas_locals[declared] = true
				if not iterator_name.is_empty():
					evidence.append(text)
				continue
		if iterator_name.is_empty():
			continue
		if not EventSheetSentence.canvas_distance_words(_cursor_ray_value(text),
				{"canvas_points": canvas_locals}).is_empty():
			measured = true
			evidence.append(text)
			continue
		var assign_at: int = EventSheetSentence.top_level_index(text, " = ")
		if assign_at > 0 and text.substr(assign_at + 3).strip_edges() == iterator_name:
			kept = true
			evidence.append(text)
	if iterator_name.is_empty() or not measured or not kept:
		return {}
	return {"evidence": evidence}


## The name a `var x … = …` line declares, "" when the line declares nothing.
static func _cursor_ray_name(text: String) -> String:
	var bare: String = text.strip_edges()
	if not bare.begins_with("var "):
		return ""
	for separator: String in [" := ", " = "]:
		var at: int = bare.find(separator)
		if at < 0:
			continue
		var name_text: String = bare.substr(4, at - 4).strip_edges()
		var colon_at: int = name_text.find(":")
		if colon_at >= 0:
			name_text = name_text.substr(0, colon_at).strip_edges()
		return name_text if EventSheetSentence.is_identifier(name_text) else ""
	return ""


## The value a `var x … = …` line is declared from - the whole line when it declares nothing, so a
## measurement written straight into a comparison is read as readily as one given a name.
static func _cursor_ray_value(text: String) -> String:
	var bare: String = text.strip_edges()
	if not bare.begins_with("var "):
		return bare
	for separator: String in [" := ", " = "]:
		var at: int = bare.find(separator)
		if at >= 0:
			return bare.substr(at + separator.length()).strip_edges()
	return bare
