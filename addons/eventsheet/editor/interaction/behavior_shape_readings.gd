@tool
class_name EventSheetBehaviorShapes
extends RefCounted

# T1-T4. The hand-rolled BEHAVIOR shapes, read with the shipped behavior's own words.
#
# A projectile script is three lines of vector arithmetic; a mover is a flag, a `move_toward` and a
# distance compare; a spinner, a wrapper, a clamp, a pin and a fade are one line each. Every one of
# those shapes is a behavior that already ships as a pack, and the pack's words are what the code is
# doing. So the rows read in those words - `Bullet ▸ Set angle of motion to angle`, `Move To ▸ Is
# moving`, `Rotate ▸ Rotate clockwise at speed` - the pattern is claimed on the event that owns it,
# and the claim names the pack that could replace the hand-written shape.
#
# Everything here is DISPLAY ONLY, exactly like the sentence grammar it hangs off: the RawCodeRow is
# untouched, nothing decides what is emitted, and the byte round-trip cannot move. Every function is
# static and pure, so a test pins a reading by value without a viewport.
#
# Strictness is the whole point. A shape that is ALMOST a bullet is worse than the arithmetic it
# replaced, so the ambiguous halves are gated on a FILE fact that only a real instance of the shape
# can set: `speed += accel * delta` reads as a bullet's acceleration only in a file that also writes
# the angle-of-motion line and the step, and `position.distance_to(start)` reads as distance
# travelled only when `start` is a variable this file declares. Anything else returns {} and the row
# keeps reading as the plain statement it is.

## The behavior each shape belongs to - the pack's own `addon_category`, which is the chip the row
## wears. Frozen with the pattern ids: a chip, a Manual page and Adopt behavior all key on the pair.
const CHIP_BULLET := "Bullet"
const CHIP_TURRET := "Turret"
const CHIP_MOVE_TO := "Move To"
const CHIP_ROTATE := "Rotate"
const CHIP_WRAP := "Wrap"
const CHIP_BOUND := "Bound To"
const CHIP_PIN := "Pin"
const CHIP_FADE := "Fade"

## The spellings of "the object's own place" a one-liner is written against. `transform.origin` is
## the 3D twin of `position` and reads the same.
const OWN_PLACE_NAMES: PackedStringArray = [
	"position", "global_position", "transform.origin", "global_transform.origin"
]

## The spellings of "the object's own angle".
const OWN_ANGLE_NAMES: PackedStringArray = ["rotation", "global_rotation"]
const OWN_DEGREE_NAMES: PackedStringArray = ["rotation_degrees", "global_rotation_degrees"]

## How a direction is built from an angle, as the head each spelling starts with. All three mean the
## one thing a bullet's angle of motion means, so all three read alike.
const ANGLE_DIRECTION_HEADS: PackedStringArray = [
	"Vector2.RIGHT.rotated(", "Vector2.from_angle(", "Vector3.RIGHT.rotated("
]

## The two ways a bullet takes its step: moving its own place, or sweeping there through what it hits.
const STEP_CALL_METHODS: PackedStringArray = ["move_and_collide", "move_and_slide"]

## The comparison signs a distance question is shown with, by the operator the file writes.
const COMPARISON_SIGNS: Dictionary = {" >= ": "≥", " <= ": "≤", " > ": ">", " < ": "<", " == ": "="}

## The alpha property a fade tweens. Nothing else counts: a tween of `scale` is a tween, and calling
## it a fade would be a guess.
const FADE_PROPERTY := "modulate:a"

## T27. The line each shipped ACTION row stands for - both the rows the importer lifts a shape to and
## the rows the picker writes it as. One table, read by the fact walk (so the file can tell it is a
## projectile even when every line of it was claimed) and by the row builder (so a picked row reads in
## the behavior's words). `{slot}` names the row's own params; `{host.}` and `{target}.` come off,
## which is the spelling a plain sheet emits and a hand-written file has.
const ACE_LINES: Dictionary = {
	# The shipped rows a hand-written shape gets lifted to.
	"MoveBy2D": "position += {offset}",
	"SetVelocity2D": "velocity = {vel}",
	"SetPosition2D": "position = {pos}",
	"ApplyGravitySimple": "velocity.y += {gravity} * {delta_t}",
	"SetProperty": "{target}.{property} = {value}",
	# The rows the picker writes each shape as, whose templates ARE these lines.
	"SetAngleOfMotion": "velocity = Vector2.RIGHT.rotated({angle}) * {speed}",
	"StepAlongVelocity": "position += velocity * {delta_t}",
	"AccelerateSpeed": "{speed_var} += {acceleration} * {delta_t}",
	"BounceOffSolid": "velocity = velocity.bounce({normal})",
	"GlideToward": "position = position.move_toward({destination}, {speed} * {delta_t})",
	"RotateClockwise": "rotation_degrees += {degrees_per_second} * {delta_t}",
	"WrapAroundLayoutX": "position.x = wrapf(position.x, {low}, {high})",
	"WrapAroundLayoutY": "position.y = wrapf(position.y, {low}, {high})",
	"BoundToLayout": "position = position.clamp({low}, {high})",
	"PinToObject": "global_position = {anchor}.global_position + {offset}",
	"PinAngleToObject": "rotation = {anchor}.rotation"
}

## T27. The same for the CONDITION rows a shape is asked with.
const ACE_CONDITION_LINES: Dictionary = {
	"IsFartherThan": "{a}.distance_to({b}) > {distance}",
	"HasArrived": "position.distance_to({destination}) < {tolerance}"
}


## T27. The line a row stands for, with its params put back in, or "" when a slot the line needs was
## never filled - in which case the row is not the shape, and guessing at the missing half would be
## worse than saying nothing. Longer slot names substitute first, so `{speed_var}` is never eaten by
## a `{speed}` that happens to share its opening.
static func line_for(ace_id: String, params: Dictionary, conditions: bool = false) -> String:
	var table: Dictionary = ACE_CONDITION_LINES if conditions else ACE_LINES
	if not table.has(ace_id):
		return ""
	var code: String = str(table[ace_id])
	var slots: PackedStringArray = PackedStringArray()
	for key: Variant in params:
		slots.append(str(key))
	slots.sort()
	slots.reverse()
	for key: String in slots:
		code = code.replace("{%s}" % key, str(params[key]))
	code = code.replace("{delta_t}", "delta")
	# A write with no receiver is spelled without the dot, which is how the file itself has it.
	if code.begins_with("."):
		code = code.substr(1)
	return "" if code.contains("{") else code


## Everything the readings below need to know about the FILE, merged into the row builder's sentence
## context once per rebuild. No single line can answer any of these: whether the file is a bullet at
## all, which variable holds a turret's target, which one is a move-to destination, which local holds
## a fade. Answered once here, from the same ordered lines the other fact maps walk.
##
##   bullet_motion        true when the file writes BOTH an angle-of-motion line and a step
##   bullet_speeds        {name: true} - the speed factors those angle-of-motion lines multiply by
##   turret_targets       {name: true} - the variables a nearest-in-family loop fills
##   move_to_destinations {name: true} - the points a `move_toward` glide aims at
##   move_to_speeds       {destination: the speed expression its glide uses}
##   move_to_flags        {name: true} - the booleans that say a glide is running
##   pin_anchors          {name: true} - the objects a place is copied from
##   fade_locals          {local: seconds} - the tweens that fade alpha to nothing
##   fade_destroys        {local: true} - those of them that destroy the object afterwards
static func facts(lines: PackedStringArray) -> Dictionary:
	var bullet_speeds: Dictionary = {}
	var stepped: bool = false
	var move_destinations: Dictionary = {}
	var move_speeds: Dictionary = {}
	var pin_anchors: Dictionary = {}
	var pin_angle_anchors: Dictionary = {}
	for line: String in lines:
		var text: String = line.strip_edges()
		if text.is_empty() or text.begins_with("#"):
			continue
		var angle_parts: Dictionary = angle_of_motion_parts(text)
		if not angle_parts.is_empty():
			bullet_speeds[str(angle_parts.get("speed", ""))] = true
		if is_step_line(text):
			stepped = true
		var glide: Dictionary = glide_parts(text)
		if not glide.is_empty():
			move_destinations[str(glide.get("destination", ""))] = true
			move_speeds[str(glide.get("destination", ""))] = str(glide.get("speed", ""))
		var pinned: Dictionary = pin_parts(text)
		if not pinned.is_empty():
			pin_anchors[str(pinned.get("anchor", ""))] = true
		var turned: String = pin_angle_anchor(text)
		if not turned.is_empty():
			pin_angle_anchors[turned] = true
	return {
		"bullet_motion": stepped and not bullet_speeds.is_empty(),
		"bullet_speeds": bullet_speeds,
		"turret_targets": turret_target_names(lines),
		"move_to_destinations": move_destinations,
		"move_to_speeds": move_speeds,
		"move_to_flags": move_to_flag_names(lines, move_destinations),
		"pin_anchors": pin_anchors,
		"pin_angle_anchors": pin_angle_anchors,
		"fade_locals": fade_facts(lines).get("seconds", {}),
		"fade_destroys": fade_facts(lines).get("destroys", {})
	}


## T1. `Vector2.RIGHT.rotated(rotation) * speed`, `Vector2.from_angle(rotation) * speed` and
## `transform.x * speed` are the three spellings of one sentence: fly at `speed` along an angle.
## Returns {angle, speed} for the assignment that writes it into `velocity`, or {} for anything else.
static func angle_of_motion_parts(text: String) -> Dictionary:
	var assign_at: int = EventSheetSentence.top_level_index(text, " = ")
	if assign_at <= 0:
		return {}
	var target: String = text.substr(0, assign_at).strip_edges().trim_prefix("self.")
	if target != "velocity":
		return {}
	var value: String = text.substr(assign_at + 3).strip_edges()
	var times_at: int = EventSheetSentence.top_level_index(value, " * ")
	if times_at <= 0:
		return {}
	var direction: String = value.substr(0, times_at).strip_edges()
	var speed: String = value.substr(times_at + 3).strip_edges()
	if speed.is_empty():
		return {}
	# `transform.x` IS the object's facing, with no angle written down: the row still says "angle of
	# motion", because the object's own angle is what it flew off along.
	if direction == "transform.x" or direction == "global_transform.x" or direction == "transform.basis.x":
		return {"angle": "", "speed": speed}
	for head: String in ANGLE_DIRECTION_HEADS:
		if not direction.begins_with(head) or not direction.ends_with(")"):
			continue
		var inner: String = direction.substr(head.length(), direction.length() - head.length() - 1)
		return {"angle": inner.strip_edges(), "speed": speed}
	return {}


## T1. The step a bullet takes each frame: its own place moved by the velocity, or that same motion
## swept through whatever is in the way.
static func is_step_line(text: String) -> bool:
	var grows_at: int = EventSheetSentence.top_level_index(text, " += ")
	if grows_at > 0:
		var grown: String = text.substr(0, grows_at).strip_edges().trim_prefix("self.")
		if OWN_PLACE_NAMES.has(grown) and _is_velocity_step(text.substr(grows_at + 4)):
			return true
	var call: Dictionary = EventSheetSentence.call_parts(text)
	if call.is_empty() or not str(call.get("target", "")).strip_edges() in ["", "self"]:
		return false
	if not STEP_CALL_METHODS.has(str(call.get("method", ""))):
		return false
	var args: PackedStringArray = call.get("args", PackedStringArray())
	return args.size() == 1 and _is_velocity_step(args[0])


## `velocity * delta` in either order - the one product a step is written as.
static func _is_velocity_step(value: String) -> bool:
	var factor: String = EventSheetSentence.per_second_factor(value)
	return factor.strip_edges().trim_prefix("self.") == "velocity"


## T3. `p = p.move_toward(destination, speed * delta)` and its two siblings (`lerp` toward the point,
## `direction_to(point) * speed` added to the place) - the one step a glide is made of. Returns
## {destination, speed} or {}.
static func glide_parts(text: String) -> Dictionary:
	var assign_at: int = EventSheetSentence.top_level_index(text, " = ")
	if assign_at > 0:
		var target: String = text.substr(0, assign_at).strip_edges().trim_prefix("self.")
		if not OWN_PLACE_NAMES.has(target):
			return {}
		var value: String = text.substr(assign_at + 3).strip_edges()
		for method: String in ["move_toward", "lerp"]:
			var head: String = ".%s(" % method
			var head_at: int = value.find(head)
			if head_at <= 0 or not value.ends_with(")"):
				continue
			if not OWN_PLACE_NAMES.has(value.substr(0, head_at).strip_edges().trim_prefix("self.")):
				continue
			var inner: String = value.substr(head_at + head.length(),
				value.length() - head_at - head.length() - 1)
			var parts: PackedStringArray = EventSheetSentence.split_top_level(inner, ",")
			if parts.size() != 2:
				continue
			var destination: String = parts[0].strip_edges()
			var rate: String = EventSheetSentence.per_second_factor(parts[1])
			if not EventSheetSentence.is_identifier(destination) or rate.is_empty():
				continue
			return {"destination": destination, "speed": rate}
		return {}
	var grows_at: int = EventSheetSentence.top_level_index(text, " += ")
	if grows_at <= 0:
		return {}
	if not OWN_PLACE_NAMES.has(text.substr(0, grows_at).strip_edges().trim_prefix("self.")):
		return {}
	var moved: String = EventSheetSentence.per_second_factor(text.substr(grows_at + 4))
	if moved.is_empty():
		return {}
	var speed_at: int = EventSheetSentence.top_level_index(moved, " * ")
	if speed_at <= 0:
		return {}
	var toward: String = moved.substr(0, speed_at).strip_edges()
	var speed: String = moved.substr(speed_at + 3).strip_edges()
	const TOWARD := ".direction_to("
	var toward_at: int = toward.find(TOWARD)
	if toward_at <= 0 or not toward.ends_with(")"):
		return {}
	if not OWN_PLACE_NAMES.has(toward.substr(0, toward_at).strip_edges().trim_prefix("self.")):
		return {}
	var point: String = toward.substr(toward_at + TOWARD.length(),
		toward.length() - toward_at - TOWARD.length() - 1).strip_edges()
	if not EventSheetSentence.is_identifier(point):
		return {}
	return {"destination": point, "speed": speed}


## T3. The booleans that say a glide is RUNNING: set true on the same line run that fills a
## destination, and asked about somewhere else. Both halves are required, so an ordinary flag stays a
## flag and a destination filled with no flag beside it never invents one.
static func move_to_flag_names(lines: PackedStringArray, destinations: Dictionary) -> Dictionary:
	if destinations.is_empty():
		return {}
	var set_true: Dictionary = {}
	var set_false: Dictionary = {}
	for line: String in lines:
		var text: String = line.strip_edges()
		var assign_at: int = EventSheetSentence.top_level_index(text, " = ")
		if assign_at <= 0:
			continue
		var name_text: String = text.substr(0, assign_at).strip_edges().trim_prefix("self.")
		if not EventSheetSentence.is_identifier(name_text):
			continue
		match text.substr(assign_at + 3).strip_edges():
			"true":
				set_true[name_text] = true
			"false":
				set_false[name_text] = true
	var found: Dictionary = {}
	for name_text: String in set_true:
		if set_false.has(name_text):
			found[name_text] = true
	return found


## T2. The variables a nearest-in-family loop FILLS - my own minimal recogniser for the loop, kept
## deliberately small because the picking words themselves belong elsewhere. The shape asked for is
## the whole of it: a `for` over a group, a distance measured inside it, a `<` against a running
## best, and the winner handed to a variable afterwards.
static func turret_target_names(lines: PackedStringArray) -> Dictionary:
	var found: Dictionary = {}
	for run: Dictionary in nearest_in_family_runs(lines):
		var name_text: String = str(run.get("target", ""))
		if not name_text.is_empty():
			found[name_text] = true
	return found


## T2. Every nearest-in-family loop the lines hold, as {family, range, target, evidence, best,
## nearest}. The minimal min-loop recogniser: the family the loop walks, the number the search starts
## from (which is the range), the local that holds the winner, and the variable it is handed to.
##
## Written as a walk over the lines rather than over the events, because the shape spans a `for` and
## the assignment after it, and only the file sees both.
static func nearest_in_family_runs(lines: PackedStringArray) -> Array:
	const GROUP_HEAD := "get_nodes_in_group("
	var runs: Array = []
	for index: int in range(lines.size()):
		var text: String = lines[index].strip_edges()
		if not text.begins_with("for ") or not text.ends_with(":"):
			continue
		var group_at: int = text.find(GROUP_HEAD)
		if group_at < 0 or not text.contains(" in "):
			continue
		var closing: int = EventSheetSentence.closing_paren(text, group_at + GROUP_HEAD.length() - 1)
		if closing < 0:
			continue
		var family: String = text.substr(group_at + GROUP_HEAD.length(),
			closing - group_at - GROUP_HEAD.length()).strip_edges()
		if not (family.begins_with("\"") and family.ends_with("\"") and family.length() > 1):
			continue
		var evidence: PackedStringArray = PackedStringArray([text])
		var nearest: String = ""
		var best: String = ""
		var range_from: String = ""
		# The best-so-far is declared just ABOVE the loop, which is the only place it can be.
		for back: int in range(maxi(0, index - 3), index):
			var above: String = lines[back].strip_edges()
			var declared: Dictionary = _declared_pair(above)
			if declared.is_empty():
				continue
			var value: String = str(declared.get("value", ""))
			if value == "null":
				nearest = str(declared.get("name", ""))
				evidence.append(above)
			elif EventSheetSentence.is_identifier(value) or value.is_valid_float():
				best = str(declared.get("name", ""))
				range_from = value
				evidence.append(above)
		if nearest.is_empty() or best.is_empty():
			continue
		var closer: bool = false
		var handed: String = ""
		for ahead: int in range(index + 1, mini(lines.size(), index + 9)):
			var below: String = lines[ahead].strip_edges()
			if below.is_empty():
				continue
			# `if d < best:` when the line is still text, and the bare `d < best` a lifted comparison
			# is rebuilt as - the same question, asked either way round the importer left it.
			if below.contains(" < %s" % best):
				closer = true
				evidence.append(below)
				continue
			var assign_at: int = EventSheetSentence.top_level_index(below, " = ")
			if assign_at <= 0:
				continue
			var name_text: String = below.substr(0, assign_at).strip_edges().trim_prefix("self.")
			if below.substr(assign_at + 3).strip_edges() == nearest \
					and EventSheetSentence.is_identifier(name_text) and name_text != nearest:
				handed = name_text
				evidence.append(below)
				break
		if not closer or handed.is_empty():
			continue
		runs.append({
			"family": family.substr(1, family.length() - 2),
			"range": range_from,
			"target": handed,
			"nearest": nearest,
			"best": best,
			"evidence": evidence
		})
	return runs


## A `var x = <value>` / `var x := <value>` pair, or {} for any other line.
static func _declared_pair(text: String) -> Dictionary:
	if not text.begins_with("var "):
		return {}
	for separator: String in [" := ", " = "]:
		var at: int = EventSheetSentence.top_level_index(text, separator)
		if at <= 0:
			continue
		var name_text: String = text.substr(4, at - 4).strip_edges()
		var colon_at: int = name_text.find(":")
		if colon_at >= 0:
			name_text = name_text.substr(0, colon_at).strip_edges()
		if not EventSheetSentence.is_identifier(name_text):
			return {}
		return {"name": name_text, "value": text.substr(at + separator.length()).strip_edges()}
	return {}


## T4. `global_position = anchor.global_position + offset` - one place copied from another's, which
## is what pinning IS. Returns {anchor, offset} or {}.
static func pin_parts(text: String) -> Dictionary:
	var assign_at: int = EventSheetSentence.top_level_index(text, " = ")
	if assign_at <= 0:
		return {}
	var target: String = text.substr(0, assign_at).strip_edges().trim_prefix("self.")
	if not OWN_PLACE_NAMES.has(target):
		return {}
	var value: String = text.substr(assign_at + 3).strip_edges()
	var offset: String = ""
	var plus_at: int = EventSheetSentence.top_level_index(value, " + ")
	if plus_at > 0:
		offset = value.substr(plus_at + 3).strip_edges()
		value = value.substr(0, plus_at).strip_edges()
	var dot_at: int = value.rfind(".")
	if dot_at <= 0:
		return {}
	var anchor: String = value.substr(0, dot_at).strip_edges()
	if not OWN_PLACE_NAMES.has(value.substr(dot_at + 1).strip_edges()):
		return {}
	if not EventSheetSentence.is_identifier(anchor) or anchor == "self":
		return {}
	return {"anchor": anchor, "offset": offset}


## T4. `rotation = anchor.rotation` - the angle half of a pin. Returns the anchor or "".
static func pin_angle_anchor(text: String) -> String:
	var assign_at: int = EventSheetSentence.top_level_index(text, " = ")
	if assign_at <= 0:
		return ""
	var target: String = text.substr(0, assign_at).strip_edges().trim_prefix("self.")
	if not OWN_ANGLE_NAMES.has(target) and not OWN_DEGREE_NAMES.has(target):
		return ""
	var value: String = text.substr(assign_at + 3).strip_edges()
	var dot_at: int = value.rfind(".")
	if dot_at <= 0:
		return ""
	var member: String = value.substr(dot_at + 1).strip_edges()
	if not OWN_ANGLE_NAMES.has(member) and not OWN_DEGREE_NAMES.has(member):
		return ""
	var anchor: String = value.substr(0, dot_at).strip_edges()
	return anchor if EventSheetSentence.is_identifier(anchor) and anchor != "self" else ""


## T4. The tweens that fade alpha to nothing, as {"seconds": {local: the duration}, "destroys":
## {local: true}}. Two lines make the shape - the alpha step and the callback that follows it - so
## the file is what answers, exactly as the tween chain facts beside it do.
static func fade_facts(lines: PackedStringArray) -> Dictionary:
	var seconds: Dictionary = {}
	var destroys: Dictionary = {}
	for line: String in lines:
		var text: String = line.strip_edges()
		var step: Dictionary = fade_step_parts(text)
		if not step.is_empty():
			seconds[str(step.get("local", ""))] = str(step.get("seconds", ""))
			continue
		var call: Dictionary = EventSheetSentence.call_parts(text)
		if call.is_empty() or str(call.get("method", "")) != "tween_callback":
			continue
		var args: PackedStringArray = call.get("args", PackedStringArray())
		var local: String = str(call.get("target", "")).strip_edges()
		if args.size() == 1 and EventSheetSentence.is_identifier(local) \
				and args[0].strip_edges() in ["queue_free", "self.queue_free"]:
			destroys[local] = true
	return {"seconds": seconds, "destroys": destroys}


## T4. `tw.tween_property(self, "modulate:a", 0.0, 1.0)` - the alpha step a fade out IS. Returns
## {local, seconds} or {}. Only a fade to NOTHING counts; a tween to half opacity is a tween.
static func fade_step_parts(text: String) -> Dictionary:
	var call: Dictionary = EventSheetSentence.call_parts(text)
	if call.is_empty() or str(call.get("method", "")) != "tween_property":
		return {}
	var local: String = str(call.get("target", "")).strip_edges()
	if not EventSheetSentence.is_identifier(local):
		return {}
	var args: PackedStringArray = call.get("args", PackedStringArray())
	if args.size() != 4:
		return {}
	if args[0].strip_edges() != "self":
		return {}
	var property_text: String = args[1].strip_edges()
	if property_text != "\"%s\"" % FADE_PROPERTY and property_text != "&\"%s\"" % FADE_PROPERTY:
		return {}
	var to_value: String = args[2].strip_edges()
	if to_value != "0" and to_value != "0.0":
		return {}
	return {"local": local, "seconds": args[3].strip_edges()}


## The reading of ONE statement in the behaviors' words, or {} when no shape is recognised. Called by
## the sentence grammar after the shipped readings have had their say, so nothing already settled
## moves and a shape claimed here is one nothing else had words for.
static func statement(text: String, context: Dictionary) -> Dictionary:
	var bullet: Dictionary = _bullet_statement(text, context)
	if not bullet.is_empty():
		return bullet
	var turret: Dictionary = _turret_statement(text, context)
	if not turret.is_empty():
		return turret
	var glide: Dictionary = _move_to_statement(text, context)
	if not glide.is_empty():
		return glide
	return _one_liner_statement(text, context)


## The reading of ONE condition in the behaviors' words, or {} when no shape is recognised.
static func condition(text: String, context: Dictionary) -> Dictionary:
	# A glide's ARRIVAL first: a destination is a point the file itself aims a `move_toward` at, which
	# is a stronger statement than "some variable this file declares", and the two questions are
	# written with the same call.
	var arrived: Dictionary = _arrived_condition(text, context)
	if not arrived.is_empty():
		return arrived
	var travelled: Dictionary = _distance_travelled_condition(text, context)
	if not travelled.is_empty():
		return travelled
	var held: Dictionary = _has_target_condition(text, context)
	if not held.is_empty():
		return held
	return _move_to_flag_condition(text, context)


## T2. `if target:` - the Turret behavior's own question about whether it is holding one, rather than
## the existence check the line is written as. Only the variable the loop FILLED reads this way.
static func _has_target_condition(text: String, context: Dictionary) -> Dictionary:
	var held: String = text.strip_edges().trim_prefix("self.")
	if not (context.get("turret_targets", {}) as Dictionary).has(held):
		return {}
	return _shape(EventSheetSentence.script_object(context), CHIP_TURRET, "turret", "Has target", {})


## One reading in a behavior's words: the pack's name rides on the row as a chip, the step follows in
## that pack's own words, and the pattern the row is an instance of is written on the reading so the
## row builder can claim it without a second walk.
static func _shape(object_name: String, chip: String, pattern: String, template: String,
		values: Dictionary) -> Dictionary:
	var reading: Dictionary = EventSheetSentence.behaviour_sentence_of(object_name, chip, template, values)
	if reading.is_empty():
		return reading
	reading["pattern"] = pattern
	return reading


## T1. The four bullet steps and the bounce, each gated on the file actually being a projectile.
static func _bullet_statement(text: String, context: Dictionary) -> Dictionary:
	if not bool(context.get("bullet_motion", false)):
		return {}
	var object_name: String = EventSheetSentence.script_object(context)
	var angle_parts: Dictionary = angle_of_motion_parts(text)
	if not angle_parts.is_empty():
		return _shape(object_name, CHIP_BULLET, "bullet", "Set angle of motion to {angle}",
			{"angle": [_angle_words(str(angle_parts.get("angle", "")), context), "value"]})
	if is_step_line(text):
		return _shape(object_name, CHIP_BULLET, "bullet", "Move", {})
	var grows_at: int = EventSheetSentence.top_level_index(text, " += ")
	if grows_at > 0:
		var grown: String = text.substr(0, grows_at).strip_edges().trim_prefix("self.")
		var rate: String = EventSheetSentence.per_second_factor(text.substr(grows_at + 4))
		if not rate.is_empty() and (context.get("bullet_speeds", {}) as Dictionary).has(grown):
			var accelerating: Dictionary = _shape(object_name, CHIP_BULLET, "bullet",
				"Set speed to {speed}", {"speed": [_member_words(grown), "name"]})
			(accelerating["segments"] as Array).append(
				{"text": " %s " % EventSheetSentence.translate("accelerating by"), "tone": "muted"})
			(accelerating["segments"] as Array).append(
				{"text": EventSheetSentence.expression_text(rate, context), "tone": "value"})
			return accelerating
		if not rate.is_empty() and grown in ["velocity.y", "velocity.z"]:
			return _shape(object_name, CHIP_BULLET, "bullet", "Set gravity to {gravity}",
				{"gravity": [EventSheetSentence.expression_text(rate, context), "value"]})
	var assign_at: int = EventSheetSentence.top_level_index(text, " = ")
	if assign_at <= 0:
		return {}
	if text.substr(0, assign_at).strip_edges().trim_prefix("self.") != "velocity":
		return {}
	var value: String = text.substr(assign_at + 3).strip_edges()
	if value.begins_with("velocity.bounce(") and value.ends_with(")"):
		return _shape(object_name, CHIP_BULLET, "bullet", "Bounce off solids", {})
	return {}


## T1. `position.distance_to(start) > range_px` - how far the bullet has flown, asked in the Bullet
## behavior's own expression name. Gated on the origin being a variable this file DECLARES, so a
## distance to another object stays the distance it is.
static func _distance_travelled_condition(text: String, context: Dictionary) -> Dictionary:
	if not bool(context.get("bullet_motion", false)):
		return {}
	for operator: String in COMPARISON_SIGNS:
		var at: int = EventSheetSentence.top_level_index(text, operator)
		if at <= 0:
			continue
		var measured: String = text.substr(0, at).strip_edges()
		var limit: String = text.substr(at + operator.length()).strip_edges()
		const TAIL := ".distance_to("
		var tail_at: int = measured.find(TAIL)
		if tail_at <= 0 or not measured.ends_with(")"):
			continue
		if not OWN_PLACE_NAMES.has(measured.substr(0, tail_at).strip_edges().trim_prefix("self.")):
			continue
		var origin: String = measured.substr(tail_at + TAIL.length(),
			measured.length() - tail_at - TAIL.length() - 1).strip_edges()
		if not (context.get("variable_types", {}) as Dictionary).has(origin):
			continue
		# A point the file glides TO is a destination, and how far away it still is has its own word.
		if (context.get("move_to_destinations", {}) as Dictionary).has(origin):
			continue
		return _shape(EventSheetSentence.script_object(context), CHIP_BULLET, "bullet",
			"Distance travelled {sign} {limit}", {
				"sign": [str(COMPARISON_SIGNS[operator]), "plain"],
				"limit": [EventSheetSentence.expression_text(limit, context), "value"]
			})
	return {}


## T2. The two turret steps a single line writes: the turn toward the target, and letting go of it.
## The loop that ACQUIRES the target is a shape of its own and is claimed as the pattern's evidence
## rather than collapsed into a row here.
static func _turret_statement(text: String, context: Dictionary) -> Dictionary:
	var targets: Dictionary = context.get("turret_targets", {})
	if targets.is_empty():
		return {}
	var assign_at: int = EventSheetSentence.top_level_index(text, " = ")
	if assign_at <= 0:
		return {}
	var target: String = text.substr(0, assign_at).strip_edges().trim_prefix("self.")
	if not OWN_ANGLE_NAMES.has(target):
		return {}
	var value: String = text.substr(assign_at + 3).strip_edges()
	if not value.begins_with("lerp_angle(") or not value.ends_with(")"):
		return {}
	var eased: PackedStringArray = EventSheetSentence.split_top_level(
		value.substr(11, value.length() - 12), ",")
	if eased.size() != 3:
		return {}
	if not OWN_ANGLE_NAMES.has(eased[0].strip_edges().trim_prefix("self.")):
		return {}
	var rate: String = EventSheetSentence.per_second_factor(eased[2])
	if rate.is_empty() or not _aims_at_target(eased[1].strip_edges(), targets):
		return {}
	return _shape(EventSheetSentence.script_object(context), CHIP_TURRET, "turret",
		"Rotate toward target at {rate}",
		{"rate": [EventSheetSentence.expression_text(rate, context), "value"]})


## T2. True when an angle is measured toward one of the variables a nearest-in-family loop filled.
static func _aims_at_target(angle_text: String, targets: Dictionary) -> bool:
	for method: String in [".angle_to_point(", ".angle_to("]:
		var at: int = angle_text.find(method)
		if at <= 0 or not angle_text.ends_with(")"):
			continue
		var aimed: String = angle_text.substr(at + method.length(),
			angle_text.length() - at - method.length() - 1).strip_edges()
		var dot_at: int = aimed.rfind(".")
		if dot_at > 0:
			aimed = aimed.substr(0, dot_at).strip_edges()
		if targets.has(aimed):
			return true
	return false


## T3. The three glide steps: aiming at a point, starting, and stopping.
static func _move_to_statement(text: String, context: Dictionary) -> Dictionary:
	var destinations: Dictionary = context.get("move_to_destinations", {})
	if destinations.is_empty():
		return {}
	var object_name: String = EventSheetSentence.script_object(context)
	var glide: Dictionary = glide_parts(text)
	if not glide.is_empty():
		return _shape(object_name, CHIP_MOVE_TO, "move_to", "Move toward {destination} at {speed}", {
			"destination": [_member_words(str(glide.get("destination", ""))), "name"],
			"speed": [EventSheetSentence.expression_text(str(glide.get("speed", "")), context), "value"]
		})
	var assign_at: int = EventSheetSentence.top_level_index(text, " = ")
	if assign_at <= 0:
		return {}
	var target: String = text.substr(0, assign_at).strip_edges().trim_prefix("self.")
	var value: String = text.substr(assign_at + 3).strip_edges()
	if destinations.has(target) and not value.is_empty():
		var speed: String = str((context.get("move_to_speeds", {}) as Dictionary).get(target, ""))
		if speed.is_empty():
			return _shape(object_name, CHIP_MOVE_TO, "move_to", "Move to position {point}",
				{"point": [EventSheetSentence.expression_text(value, context), "value"]})
		return _shape(object_name, CHIP_MOVE_TO, "move_to", "Move to position {point} at {speed}", {
			"point": [EventSheetSentence.expression_text(value, context), "value"],
			"speed": [EventSheetSentence.expression_text(speed, context), "value"]
		})
	if not (context.get("move_to_flags", {}) as Dictionary).has(target):
		return {}
	if value == "true":
		return _shape(object_name, CHIP_MOVE_TO, "move_to", "Start moving", {})
	if value == "false":
		return _shape(object_name, CHIP_MOVE_TO, "move_to", "Stop", {})
	return {}


## T3. `if moving:` - the behavior's own state, asked in its own word.
static func _move_to_flag_condition(text: String, context: Dictionary) -> Dictionary:
	var flag: String = text.strip_edges().trim_prefix("self.")
	if not (context.get("move_to_flags", {}) as Dictionary).has(flag):
		return {}
	return _shape(EventSheetSentence.script_object(context), CHIP_MOVE_TO, "move_to", "Is moving", {})


## T3. `global_position.distance_to(destination) < 1.0` - the arrival question, in the Move To
## behavior's own words rather than as the comparison it is written with.
static func _arrived_condition(text: String, context: Dictionary) -> Dictionary:
	var destinations: Dictionary = context.get("move_to_destinations", {})
	if destinations.is_empty():
		return {}
	for operator: String in [" < ", " <= "]:
		var at: int = EventSheetSentence.top_level_index(text, operator)
		if at <= 0:
			continue
		var measured: String = text.substr(0, at).strip_edges()
		const TAIL := ".distance_to("
		var tail_at: int = measured.find(TAIL)
		if tail_at <= 0 or not measured.ends_with(")"):
			continue
		if not OWN_PLACE_NAMES.has(measured.substr(0, tail_at).strip_edges().trim_prefix("self.")):
			continue
		var point: String = measured.substr(tail_at + TAIL.length(),
			measured.length() - tail_at - TAIL.length() - 1).strip_edges()
		if not destinations.has(point):
			continue
		return _shape(EventSheetSentence.script_object(context), CHIP_MOVE_TO, "move_to",
			"Has arrived", {})
	return {}


## T4. The five one-liners - spin, wrap, bound, pin and fade - each the whole of a behavior.
static func _one_liner_statement(text: String, context: Dictionary) -> Dictionary:
	var object_name: String = EventSheetSentence.script_object(context)
	var grows_at: int = EventSheetSentence.top_level_index(text, " += ")
	if grows_at > 0:
		var grown: String = text.substr(0, grows_at).strip_edges().trim_prefix("self.")
		var rate: String = EventSheetSentence.per_second_factor(text.substr(grows_at + 4))
		if not rate.is_empty() and OWN_DEGREE_NAMES.has(grown):
			return _shape(object_name, CHIP_ROTATE, "rotate",
				"Rotate clockwise at {rate} (degrees per second)",
				{"rate": [EventSheetSentence.expression_text(rate, context), "value"]})
		if not rate.is_empty() and OWN_ANGLE_NAMES.has(grown):
			return _shape(object_name, CHIP_ROTATE, "rotate",
				"Rotate clockwise at {rate} (radians per second)",
				{"rate": [EventSheetSentence.expression_text(rate, context), "value"]})
	var faded: Dictionary = _fade_statement(text, context)
	if not faded.is_empty():
		return faded
	var assign_at: int = EventSheetSentence.top_level_index(text, " = ")
	if assign_at <= 0:
		return {}
	var target: String = text.substr(0, assign_at).strip_edges().trim_prefix("self.")
	var value: String = text.substr(assign_at + 3).strip_edges()
	var wrapped: Dictionary = _wrap_statement(object_name, target, value, context)
	if not wrapped.is_empty():
		return wrapped
	var bounded: Dictionary = _bound_statement(object_name, target, value, context)
	if not bounded.is_empty():
		return bounded
	return _pin_statement(object_name, text, context)


## T4. `position.x = wrapf(position.x, 0, screen.x)` - the layout's own edges, per axis.
static func _wrap_statement(object_name: String, target: String, value: String,
		context: Dictionary) -> Dictionary:
	if not target.begins_with("position.") and not target.begins_with("global_position."):
		return {}
	var axis: String = target.substr(target.rfind(".") + 1)
	if not axis in ["x", "y"]:
		return {}
	var call: Dictionary = EventSheetSentence.call_parts(value)
	if call.is_empty() or not str(call.get("target", "")).is_empty():
		return {}
	if not str(call.get("method", "")) in ["wrapf", "wrapi", "wrap", "fmod", "fposmod"]:
		return {}
	var args: PackedStringArray = call.get("args", PackedStringArray())
	if args.is_empty() or args[0].strip_edges().trim_prefix("self.") != target:
		return {}
	var template: String = "Wrap around layout horizontally" if axis == "x" \
		else "Wrap around layout vertically"
	return _shape(object_name, CHIP_WRAP, "wrap", template, {})


## T4. `position = position.clamp(min, max)` - the layout's edges as a wall rather than a doorway.
static func _bound_statement(object_name: String, target: String, value: String,
		context: Dictionary) -> Dictionary:
	if not OWN_PLACE_NAMES.has(target):
		return {}
	const TAIL := ".clamp("
	var tail_at: int = value.find(TAIL)
	if tail_at <= 0 or not value.ends_with(")"):
		return {}
	if not OWN_PLACE_NAMES.has(value.substr(0, tail_at).strip_edges().trim_prefix("self.")):
		return {}
	var bounds: PackedStringArray = EventSheetSentence.split_top_level(
		value.substr(tail_at + TAIL.length(), value.length() - tail_at - TAIL.length() - 1), ",")
	if bounds.size() != 2:
		return {}
	return _shape(object_name, CHIP_BOUND, "bound", "Bound to layout (inside {low} - {high})", {
		"low": [EventSheetSentence.expression_text(bounds[0], context), "value"],
		"high": [EventSheetSentence.expression_text(bounds[1], context), "value"]
	})


## T4. `global_position = anchor.global_position + offset` and the angle copy beside it.
static func _pin_statement(object_name: String, text: String, context: Dictionary) -> Dictionary:
	var pinned: Dictionary = pin_parts(text)
	if not pinned.is_empty():
		var offset: String = str(pinned.get("offset", ""))
		if offset.is_empty():
			# A place copied with NO offset is only a pin when the file copies the anchor's angle too:
			# on its own, `n.position = other.position` is one object put where another one is, and
			# calling that a behavior would be a guess.
			if not (context.get("pin_angle_anchors", {}) as Dictionary).has(str(pinned.get("anchor", ""))):
				return {}
			return _shape(object_name, CHIP_PIN, "pin", "Pin to {anchor} (position)",
				{"anchor": [_member_words(str(pinned.get("anchor", ""))), "name"]})
		return _shape(object_name, CHIP_PIN, "pin", "Pin to {anchor} (position · offset {offset})", {
			"anchor": [_member_words(str(pinned.get("anchor", ""))), "name"],
			"offset": [EventSheetSentence.expression_text(offset, context), "value"]
		})
	var anchor: String = pin_angle_anchor(text)
	if anchor.is_empty() or not (context.get("pin_anchors", {}) as Dictionary).has(anchor):
		return {}
	return _shape(object_name, CHIP_PIN, "pin", "Pin to {anchor} (angle)",
		{"anchor": [_member_words(anchor), "name"]})


## T4. The alpha step a fade out is written as, with the destroy the callback promises said out loud.
static func _fade_statement(text: String, context: Dictionary) -> Dictionary:
	var step: Dictionary = fade_step_parts(text)
	if step.is_empty():
		return {}
	var local: String = str(step.get("local", ""))
	if not (context.get("fade_locals", {}) as Dictionary).has(local):
		return {}
	var template: String = "Fade out over {seconds} seconds (then destroy)" \
		if (context.get("fade_destroys", {}) as Dictionary).has(local) \
		else "Fade out over {seconds} seconds"
	return _shape(EventSheetSentence.script_object(context), CHIP_FADE, "fade", template,
		{"seconds": [EventSheetSentence.expression_text(str(step.get("seconds", "")), context), "value"]})


## The angle a bullet flew off along, in the sheet's word for it. The object's OWN angle is what most
## of these name, and the sheet calls that "angle"; anything else is shown as it is written.
static func _angle_words(angle_text: String, context: Dictionary) -> String:
	var text: String = angle_text.strip_edges().trim_prefix("self.")
	if text.is_empty() or OWN_ANGLE_NAMES.has(text) or OWN_DEGREE_NAMES.has(text):
		return EventSheetSentence.translate("angle")
	return EventSheetSentence.expression_text(text, context)


## A variable's name as a row shows it - underscores read as the spaces they stand for, which is what
## turns `range_px` into "range px" and `since_shot` into "since shot".
static func _member_words(name_text: String) -> String:
	return name_text.strip_edges().trim_prefix("_").replace("_", " ")
