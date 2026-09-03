# EventForge - the camera settings people write as a RUN of statements, and the row each run means.
#
# A camera row that sets one property is one line, and the general reverse index reads it back on its
# own. The rows here are the ones that are not: a dead zone is two flags and four margins, a
# projection is the projection and the number that describes it, a clip range is both ends, a fit is
# four limits, and a timed look-at is an aim, a guard and a tween. Each of those is several
# statements that only mean the row TOGETHER, which is exactly what a multi-statement table entry is
# for (see EventForgeLiftTable): an ordered list of patterns matched at the indentation each says it
# is written at, sharing their captures, and spliced back with the author's own bytes.
#
# WHY THE RECEIVER IS A PARAM AND THE LOCALS ARE NOT. Every run below may be written with a node in
# front of it (`$Camera.near = 0.1`) or without one (`near = 0.1`, on a sheet attached to the camera
# itself). That is the "On node" field, so it is a param, and it is spelled with the optional-prefix
# idiom `{target.}` so a cleared field emits the bare member operation. The LOCALS the timed look-at
# makes are the opposite: they are named three and four times, all the mentions have to agree for the
# run to be that row at all, and none of them is a value anybody edits - so they are shared captures,
# matched and put back verbatim, and the author's own word for the local survives the round trip.
#
# WHERE THE LINE IS DRAWN, and it is drawn narrowly on purpose. `near` and `far` are ordinary words,
# and a project could have two adjacent lines that set two variables by those names. What makes the
# pair below a Set Clip Range is that they are adjacent, at the same indentation, in that order, and
# that either both carry the same receiver or neither carries one. The bytes are unaffected either
# way - a run is spliced back exactly as it came in - so the only thing at stake in a wrong claim is
# the sentence on the row, and the shape is tight enough that it is the sentence a reader wants.
# Anything looser (one line of the pair, a different order, a stray line between them) is claimed by
# nothing here and keeps the reading it already had.
#
# THE RECEIVERS ARE ASKED ONE BY ONE, and that is what the sentence above needs to be true. A shared
# capture cannot answer it: an optional group that matched NOTHING is not a capture at all, so
# `$Other.near = 0.1` followed by a bare `far = 2000.0` agreed with itself and lifted as one row on
# the first receiver - and the first param edit would then re-emit the bare line onto `$Other`. So
# every statement captures its own receiver under its own name, and `_receivers_agree` refuses the
# run unless all of them are the same node or none of them names one.
@tool
class_name EventForgeCameraLift
extends RefCounted

const G := preload("res://addons/eventforge/importer/lift_grammar.gd")

## The value a row's receiver carries when the line names no node: "On node", left blank, which is
## what every node-scoped descriptor opens on. A blank receiver means the node the SHEET is on, so
## `near = 0.1` on a sheet attached to a camera is the same row as `$Camera.near = 0.1` beside it.
const BLANK_RECEIVER: Dictionary = {"target": ""}

## The sample node a generated fixture writes its runs against, one per dimension, so a fixture line
## reads like a line somebody would really have written.
const FIXTURE_CAMERA_2D: String = "$Camera2D"
const FIXTURE_CAMERA_3D: String = "$Camera3D"

## A GDScript local, as the timed look-at's three of them are matched. A shared capture rather than
## text spliced into a pattern: a pattern carrying somebody's identifier would mint - and hold, for
## the life of the session - one compiled RegEx per distinct name any opened file ever used.
const AIM: String = "(?<aim>[A-Za-z_][A-Za-z0-9_]*)"
const FROM: String = "(?<from>[A-Za-z_][A-Za-z0-9_]*)"
const TO: String = "(?<to>[A-Za-z_][A-Za-z0-9_]*)"
const WEIGHT: String = "(?<weight>[A-Za-z_][A-Za-z0-9_]*)"

## Built once for the life of the session: these are tried against every statement of every opened
## file, and each entry's `mark` is what rules almost all of them out before a pattern runs.
static var _entries: Array[Dictionary] = []


## The row a run of statements means, or {} when nothing here claims it. `lines` is the function body
## as the lifter holds it, `index` the statement to try, `depth` its indentation.
static func match_run(lines: PackedStringArray, index: int, depth: int) -> Dictionary:
	return EventForgeLiftTable.match_run(lift_entries(), lines, index, depth)


## Every run this family claims. The drift entry comes before the tight-follow one because both open
## on the same property name and only the value tells them apart, and a table is asked in order.
static func lift_entries() -> Array[Dictionary]:
	if _entries.is_empty():
		_entries = [_drift_entry(), _follow_tightly_entry(), _smooth_turns_entry(), _fit_limits_entry(),
			_perspective_entry(), _orthogonal_entry(), _clip_range_entry(), _look_at_entry()]
	return _entries


## `drag_horizontal_enabled = true` … and the four margins under it: the dead zone, written as the six
## lines Godot spells it in. The two margin values are each written twice and have to agree, which is
## what says the box is symmetrical and therefore the row rather than four independent numbers.
static func _drift_entry() -> Dictionary:
	return {
		"id": "camera_drift_margins",
		"ace_id": "CameraDriftMargins",
		"mark": "drag_horizontal_enabled",
		"statements": [
			{"pattern": _flag_pattern(0, "drag_horizontal_enabled", "true")},
			{"pattern": _flag_pattern(1, "drag_vertical_enabled", "true")},
			{"pattern": _value_pattern(2, "drag_left_margin", "across")},
			{"pattern": _value_pattern(3, "drag_right_margin", "across")},
			{"pattern": _value_pattern(4, "drag_top_margin", "down")},
			{"pattern": _value_pattern(5, "drag_bottom_margin", "down")}
		],
		"params": ["target", "across", "down"],
		"defaults": BLANK_RECEIVER,
		"guard": _agreeing_receivers(6),
		"shape": _slot("drag_horizontal_enabled = true") + "\n" + _slot("drag_vertical_enabled = true")
			+ "\n" + _slot("drag_left_margin = {across}") + "\n" + _slot("drag_right_margin = {across}")
			+ "\n" + _slot("drag_top_margin = {down}") + "\n" + _slot("drag_bottom_margin = {down}"),
		"slots": {"target": FIXTURE_CAMERA_2D, "across": "0.25", "down": "0.15"}
	}


## The same two flags turned off, which is the whole of Follow Tightly - there is nothing left for
## the row to show, so the value is not a param.
static func _follow_tightly_entry() -> Dictionary:
	return {
		"id": "camera_follow_tightly",
		"ace_id": "CameraFollowTightly",
		"mark": "drag_horizontal_enabled",
		"statements": [
			{"pattern": _flag_pattern(0, "drag_horizontal_enabled", "false")},
			{"pattern": _flag_pattern(1, "drag_vertical_enabled", "false")}
		],
		"params": ["target"],
		"defaults": BLANK_RECEIVER,
		"guard": _agreeing_receivers(2),
		"shape": _slot("drag_horizontal_enabled = false") + "\n" + _slot("drag_vertical_enabled = false"),
		"slots": {"target": FIXTURE_CAMERA_2D}
	}


## Rotation smoothing: the switch and the speed beside it.
static func _smooth_turns_entry() -> Dictionary:
	return {
		"id": "camera_smooth_turns",
		"ace_id": "CameraSmoothTurns",
		"mark": "rotation_smoothing_enabled",
		"statements": [
			{"pattern": _value_pattern(0, "rotation_smoothing_enabled", "enabled")},
			{"pattern": _value_pattern(1, "rotation_smoothing_speed", "speed")}
		],
		"params": ["target", "enabled", "speed"],
		"defaults": BLANK_RECEIVER,
		"guard": _agreeing_receivers(2),
		"shape": _slot("rotation_smoothing_enabled = {enabled}") + "\n" + _slot("rotation_smoothing_speed = {speed}"),
		"slots": {"target": FIXTURE_CAMERA_2D, "enabled": "true", "speed": "4.0"}
	}


## The four scroll limits taken off one rectangle. The rectangle is written four times and all four
## have to agree, which is what makes the run a fit rather than four unrelated limit writes - the
## shipped Set Scroll Limits row writes four independent numbers and is not claimed here.
static func _fit_limits_entry() -> Dictionary:
	return {
		"id": "camera_fit_limits",
		"ace_id": "CameraFitLimits",
		"mark": "limit_left = int(",
		"statements": [
			{"pattern": _limit_pattern(0, "limit_left", "position", "x")},
			{"pattern": _limit_pattern(1, "limit_top", "position", "y")},
			{"pattern": _limit_pattern(2, "limit_right", "end", "x")},
			{"pattern": _limit_pattern(3, "limit_bottom", "end", "y")}
		],
		"params": ["target", "area"],
		"defaults": BLANK_RECEIVER,
		"guard": _agreeing_receivers(4),
		"shape": _slot("limit_left = int({area}.position.x)") + "\n" + _slot("limit_top = int({area}.position.y)")
			+ "\n" + _slot("limit_right = int({area}.end.x)") + "\n" + _slot("limit_bottom = int({area}.end.y)"),
		"slots": {"target": FIXTURE_CAMERA_2D, "area": "Rect2(0, 0, 1920, 1080)"}
	}


## The perspective shot: the projection, then how wide it sees.
static func _perspective_entry() -> Dictionary:
	return _projection_entry("camera_switch_perspective", "CameraSwitchToPerspective",
		"PROJECTION_PERSPECTIVE", "fov", "degrees", "70.0")


## The flat shot: the projection, then how tall the view is.
static func _orthogonal_entry() -> Dictionary:
	return _projection_entry("camera_switch_orthogonal", "CameraSwitchToOrthogonal",
		"PROJECTION_ORTHOGONAL", "size", "size", "12.0")


## One projection swap: the constant that names it and the single number that describes it.
static func _projection_entry(id: String, ace_id: String, constant: String, property: String,
		value_name: String, sample: String) -> Dictionary:
	return {
		"id": id,
		"ace_id": ace_id,
		"mark": constant,
		"statements": [
			{"pattern": "^%sprojection = Camera3D\\.%s$" % [G.receiver(_receiver_name(0)), constant]},
			{"pattern": _value_pattern(1, property, value_name)}
		],
		"params": ["target", value_name],
		"defaults": BLANK_RECEIVER,
		"guard": _agreeing_receivers(2),
		"shape": _slot("projection = Camera3D.%s" % constant) + "\n" + _slot("%s = {%s}" % [property, value_name]),
		"slots": {"target": FIXTURE_CAMERA_3D, value_name: sample}
	}


## How close and how far the camera can see, in the order Godot lists them.
static func _clip_range_entry() -> Dictionary:
	return {
		"id": "camera_clip_range",
		"ace_id": "CameraSetClipRange",
		"mark": "near",
		"statements": [
			{"pattern": _value_pattern(0, "near", "near")},
			{"pattern": _value_pattern(1, "far", "far")}
		],
		"params": ["target", "near", "far"],
		"defaults": BLANK_RECEIVER,
		"guard": _agreeing_receivers(2),
		"shape": _slot("near = {near}") + "\n" + _slot("far = {far}"),
		"slots": {"target": FIXTURE_CAMERA_3D, "near": "0.1", "far": "2000.0"}
	}


## The timed look-at: the aim, the guard that refuses a target the camera is standing on, and the
## tween between two orientations. Three locals, each named twice or more, all of them shared
## captures - the author's own words for them ride back out untouched.
static func _look_at_entry() -> Dictionary:
	return {
		"id": "camera_look_at_over_seconds",
		"ace_id": "CameraLookAtOverSeconds",
		"mark": ".global_position - global_position",
		"statements": [
			{"pattern": "^var[ \\t]+%s: Vector3 = (?<at>.+)\\.global_position - global_position$" % AIM},
			{"pattern": "^if %s\\.length_squared\\(\\) > 0\\.000001:$" % AIM},
			{"pattern": "^var[ \\t]+%s: Basis = global_basis$" % FROM, "indent": 1},
			{"pattern": "^var[ \\t]+%s: Basis = Basis\\.looking_at\\(%s, Vector3\\.UP if absf\\(%s\\.normalized\\(\\)\\.y\\) < 0\\.999 else Vector3\\.FORWARD\\)$" % [TO, AIM, AIM],
				"indent": 1},
			{"pattern": "^create_tween\\(\\)\\.tween_method\\(func\\(%s: float\\) -> void: global_basis = %s\\.slerp\\(%s, %s\\), 0\\.0, 1\\.0, maxf\\((?<seconds>.+), 0\\.001\\)\\)$"
				% [WEIGHT, FROM, TO, WEIGHT], "indent": 1}
		],
		"params": ["at", "seconds"],
		"shape": "var __aim_look: Vector3 = {at}.global_position - global_position\n"
			+ "if __aim_look.length_squared() > 0.000001:\n"
			+ "\tvar __from_look: Basis = global_basis\n"
			+ "\tvar __to_look: Basis = Basis.looking_at(__aim_look, Vector3.UP if absf(__aim_look.normalized().y) < 0.999 else Vector3.FORWARD)\n"
			+ "\tcreate_tween().tween_method(func(__weight_look: float) -> void: global_basis = __from_look.slerp(__to_look, __weight_look), 0.0, 1.0, maxf({seconds}, 0.001))",
		"slots": {"at": "$Player", "seconds": "0.6"}
	}


## THE NAME ONE STATEMENT'S RECEIVER IS CAPTURED UNDER. The first is `target`, which is the row's own
## "On node" field; every statement after it gets a numbered name of its own, so the guard below can
## see what each line actually said. They cannot share one name: a receiver is OPTIONAL, and a group
## that matched nothing leaves no capture behind to disagree with.
static func _receiver_name(step: int) -> String:
	return "target" if step == 0 else "target_%d" % (step + 1)


## The guard every run of member operations here carries: the statements all address the SAME node,
## or none of them addresses one. `statements` is how many lines the run has, because a receiver
## nobody wrote leaves no capture behind and absence is exactly what has to be counted.
static func _receivers_agree(captures: Dictionary, statements: int) -> bool:
	var written: String = ""
	var named: int = 0
	for step: int in statements:
		var name: String = _receiver_name(step)
		if not captures.has(name):
			continue
		var text: String = str(captures[name])
		if named > 0 and text != written:
			return false
		written = text
		named += 1
	return named == 0 or named == statements


## The guard above bound to one run's length - the shape a table entry stores.
static func _agreeing_receivers(statements: int) -> Callable:
	return Callable(EventForgeCameraLift, "_receivers_agree").bind(statements)


## `<node>.<property> = <one written value>` - a line whose value IS which row this is, so there is
## nothing for the row to show and the value is not a capture.
static func _flag_pattern(step: int, property: String, written: String) -> String:
	return "^%s%s = %s$" % [G.receiver(_receiver_name(step)), property, written]


## `<node>.<property> = <anything>` - the value is the row's, whatever the author wrote there.
static func _value_pattern(step: int, property: String, value_name: String) -> String:
	return "^%s%s = (?<%s>.+)$" % [G.receiver(_receiver_name(step)), property, value_name]


## One of the four limit writes: the same rectangle every time, read for one of its four numbers.
static func _limit_pattern(step: int, property: String, corner: String, axis: String) -> String:
	return "^%s%s = int\\((?<area>.+)\\.%s\\.%s\\)$" % [G.receiver(_receiver_name(step)),
		property, corner, axis]


## One statement of a shape, with the receiver slot in front of it - the optional prefix a row with
## its "On node" field cleared writes nothing for.
static func _slot(statement: String) -> String:
	return G.optional_prefix_slot("target") + statement
