# EventForge - the ONE reading of a group-filtered touch trigger.
#
# Four triggers say "this touch, but only for one group": a body starting and stopping a collision,
# and an Area starting and stopping an overlap. All four compile to the SAME engine signal the bare
# triggers beside them use - what makes them filtered is the FIRST LINE of the handler, an early
# return that leaves at once when the thing that arrived is not in the group:
#
#     func _on_body_entered_enemies(body: Node) -> void:
#         if not body.is_in_group("enemies"):
#             return
#         <the event's own rows>
#
# The guard is visible code, not a hidden clause: it is the line a reader would have written, it is
# what the row's echo shows, and it is what an opened script is recognised BY.
#
# Three readers share this file so they can never disagree about which handler a filter belongs to:
# the trigger resolver (which function the signal is connected to), the compiler (the guard it
# writes at the top of that function), and the importer (the guard it reads back off a file).
@tool
class_name EventForgeCollisionFilters
extends RefCounted

## The trigger param every filtered touch trigger carries: the group the arrival must be in.
const GROUP_PARAM: String = "group"

## The exact guard lines a LIFTED handler had, kept verbatim so re-emission writes the author's own
## bytes back (their spacing, their `&"name"`, their one-line `: return`) instead of the canonical
## spelling below. Only ever set at lift time.
const SOURCE_GUARD_META: String = "__source_guard_lines"

## Every filtered trigger id -> the engine signal it connects to and the handler-name stem that
## signal already owns. The two words per signal are the same touch read from the two sides Godot
## files it under: a body BLOCKS what it hits, so its news is a collision; an Area only notices, so
## its news is an overlap. Both are `body_entered` / `body_exited`, which is why one guard shape
## covers all four and why a mis-read side costs words, never bytes.
const FILTERED_TRIGGERS: Dictionary = {
	"OnCollisionWithGroup": {"signal": "body_entered", "stem": "body_entered"},
	"OnStoppedCollidingWithGroup": {"signal": "body_exited", "stem": "body_exited"},
	"OnOverlapWithGroup": {"signal": "body_entered", "stem": "body_entered"},
	"OnOverlapEndedWithGroup": {"signal": "body_exited", "stem": "body_exited"},
	"OnCollisionWithGroup3D": {"signal": "body_entered", "stem": "body_entered"},
	"OnStoppedCollidingWithGroup3D": {"signal": "body_exited", "stem": "body_exited"},
	"OnOverlapWithGroup3D": {"signal": "body_entered", "stem": "body_entered"},
	"OnOverlapEndedWithGroup3D": {"signal": "body_exited", "stem": "body_exited"}
}

## The bare trigger a filtered one is the filtered form OF, per side and per dimension. Keyed
## [bare trigger id][side] where side is "area" for a node that only notices and "body" for one that
## blocks; the importer picks the side from the emitting node's class and falls back to "body",
## which is the primary wording.
const FILTERED_FOR_BARE: Dictionary = {
	"OnBodyEntered": {
		"body": {"2d": "OnCollisionWithGroup", "3d": "OnCollisionWithGroup3D"},
		"area": {"2d": "OnOverlapWithGroup", "3d": "OnOverlapWithGroup3D"}
	},
	"OnBodyExited": {
		"body": {"2d": "OnStoppedCollidingWithGroup", "3d": "OnStoppedCollidingWithGroup3D"},
		"area": {"2d": "OnOverlapEndedWithGroup", "3d": "OnOverlapEndedWithGroup3D"}
	}
}


## True when this trigger id is one of the four (in both dimensions).
static func is_filtered(trigger_id: String) -> bool:
	return FILTERED_TRIGGERS.has(trigger_id)


## The group expression a filtered event names, exactly as the author wrote it (`"enemies"`, a
## constant, a variable). "" for every other trigger, and for a filtered row nobody has filled in
## yet - which is what makes a half-written row compile to the plain unfiltered handler rather than
## to a guard against nothing.
static func group_of(event: EventRow) -> String:
	if event == null or not is_filtered(event.trigger_id):
		return ""
	return str(event.trigger_params.get(GROUP_PARAM, "")).strip_edges()


## A safe, readable identifier fragment for one group expression: `"enemies"` -> `_enemies`. It is
## what keeps two filters on the same signal in two functions - same signal, same node, two groups,
## two handlers - because one function cannot hold two different early returns. "" when the group is
## blank or spells nothing an identifier can carry (an expression rather than a plain name), in which
## case the row shares the bare handler and its guard is simply the first line of it.
static func group_token(group_expression: String) -> String:
	var bare: String = group_expression.strip_edges().lstrip("&").strip_edges()
	bare = bare.trim_prefix("\"").trim_suffix("\"").trim_prefix("'").trim_suffix("'")
	var token: String = ""
	for index: int in range(bare.length()):
		var glyph: String = bare[index]
		var is_letter: bool = glyph.to_lower() != glyph.to_upper()
		if is_letter or glyph.is_valid_int() or glyph == "_":
			token += glyph
		else:
			return ""
	token = token.to_snake_case().strip_edges().lstrip("_")
	return "" if token.is_empty() else "_%s" % token


## What a filtered handler's name ends in, so it can never be the bare handler's name. The bare
## trigger beside these owns `_on_body_entered`; a filtered one always adds something, because both
## can sit on the same node for the same signal and two functions may not share a name.
##
## A plain group name reads as itself (`_on_body_entered_enemies`), which is the whole point. A group
## named by an expression has no name to read, so it says only that it is filtered, plus a short
## stable digest that keeps two different expressions in two functions. A row nobody has filled in
## yet says just `_filtered`, and every such row shares that one handler.
static func handler_suffix(group_expression: String) -> String:
	var token: String = group_token(group_expression)
	if not token.is_empty():
		return token
	if group_expression.strip_edges().is_empty():
		return "_filtered"
	return "_filtered_%s" % str(abs(hash(group_expression.strip_edges()))).substr(0, 4)


## The name of the first argument a handler signature declares ("body: Node" -> "body"), which is the
## thing the guard asks about. "" when the signature declares nothing.
static func first_argument_name(args: String) -> String:
	var head: String = args.strip_edges().split(",")[0]
	return head.split(":")[0].split("=")[0].strip_edges()


## The guard as the compiler writes it, indented one level for a handler body - two lines, because
## that is how a reader writes an early return and how the style guide wants it. Empty when the event
## is not filtered, when it names no group, or when the handler takes nothing to ask about.
static func guard_lines(event: EventRow, args: String) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if event == null:
		return lines
	if event.has_meta(SOURCE_GUARD_META):
		var recorded: Variant = event.get_meta(SOURCE_GUARD_META)
		# A lifted handler re-emits the author's own guard verbatim. The byte-verify is absolute, and
		# rewriting their `&"enemies"` or their one-line `: return` would revert the whole file.
		for line: Variant in (recorded if recorded is Array or recorded is PackedStringArray else []):
			lines.append(str(line))
		return lines
	var group: String = group_of(event)
	var subject: String = first_argument_name(args)
	if group.is_empty() or subject.is_empty():
		return lines
	lines.append("\tif not %s.is_in_group(%s):" % [subject, group])
	lines.append("\t\treturn")
	return lines


## The two-line and one-line spellings of the guard, as one pattern: `if not <name>.is_in_group(<x>):`
## with the `return` either on the next line or after the colon. Anchored to the whole statement so a
## longer test (`if not body.is_in_group("a") or done:`) is not claimed - that condition means more
## than this row says, and a row that dropped the rest of it would not write the file back.
const GUARD_PATTERN: String = "^[ \\t]*if not ([A-Za-z_][A-Za-z0-9_]*)\\.is_in_group\\((.+)\\):[ \\t]*(return)?[ \\t]*$"

static var _guard_regex: RegEx = null


## The guard a handler's first statement is, or {} when it is not one. `lines` is the function's
## lines and `index` the first body line; returns {subject, group, next} where `next` is the line
## after the guard. Reads BOTH spellings, so a hand-written one-liner opens as the same row a
## two-line one does and comes back written the way it was.
static func match_guard(lines: PackedStringArray, index: int) -> Dictionary:
	if index < 0 or index >= lines.size():
		return {}
	if _guard_regex == null:
		_guard_regex = RegEx.create_from_string(GUARD_PATTERN)
	var hit: RegExMatch = _guard_regex.search(lines[index])
	if hit == null:
		return {}
	var next: int = index + 1
	if hit.get_string(3).is_empty():
		# The block form: the very next line must be the bare return and nothing else, or the `if`
		# is guarding something larger than this row can say.
		if next >= lines.size() or lines[next].strip_edges() != "return":
			return {}
		next += 1
	return {"subject": hit.get_string(1), "group": hit.get_string(2).strip_edges(), "next": next}


## Which side of the touch a node's class puts it on: "area" for a node that only notices, "body" for
## one that blocks. Falls back to "body" for a class nobody named, which is the primary wording.
static func side_for_class(class_text: String) -> String:
	var name_text: String = class_text.strip_edges()
	if name_text.is_empty():
		return "body"
	if name_text == "Area2D" or name_text == "Area3D":
		return "area"
	if ClassDB.class_exists(name_text) and (ClassDB.is_parent_class(name_text, "Area2D")
			or ClassDB.is_parent_class(name_text, "Area3D")):
		return "area"
	return "body"


## The one line the With field teaches while it has focus, for a node that only NOTICES a touch.
## Said here rather than in the dialog so the row, the guide and the strip cannot drift apart.
const AREA_NOTE: String = "This node is an area: it notices what arrives and lets it through. Blocking is a body's job, so pair this with a body if the thing should also be stopped."

## The same line for a node that BLOCKS what it touches.
const BODY_NOTE: String = "This node is a body: what it hits stops, and the hit is reported only while Contact Monitor is on and Max Contacts Reported is above zero. An area would notice the same arrival without stopping anything."


## Which of the two one-liners belongs to a node class - the lesson said on the row where it
## matters, rather than left to a guide the author is not reading right now.
static func side_note(class_text: String) -> String:
	return AREA_NOTE if side_for_class(class_text) == "area" else BODY_NOTE


## Which dimension a node's class belongs to: "3d" for the 3D families, "2d" otherwise (including a
## class nobody named, because 2D is where the bare triggers already live).
static func dimension_for_class(class_text: String) -> String:
	var name_text: String = class_text.strip_edges()
	if name_text.is_empty():
		return "2d"
	if name_text.ends_with("3D"):
		return "3d"
	if ClassDB.class_exists(name_text) and ClassDB.is_parent_class(name_text, "Node3D"):
		return "3d"
	return "2d"


## The filtered trigger a bare one becomes for a given emitting class, or "" when that bare trigger
## has no filtered twin. One place, so the importer's reading and the picker's filing agree.
static func filtered_trigger_for(bare_trigger_id: String, class_text: String) -> String:
	var sides: Dictionary = FILTERED_FOR_BARE.get(bare_trigger_id, {}) as Dictionary
	if sides.is_empty():
		return ""
	var dimensions: Dictionary = sides.get(side_for_class(class_text), {}) as Dictionary
	return str(dimensions.get(dimension_for_class(class_text), ""))
