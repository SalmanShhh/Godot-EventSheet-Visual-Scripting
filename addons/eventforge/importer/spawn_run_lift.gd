# EventForge - the two spawn runs that are several statements and one sentence.
#
# Most of the spawn vocabulary is one statement per row, and the general index reads those back. Two
# rows are not: a formation is a loop with a place expression in it, and a launched copy is a spawn
# with a facing and a speed under it. Neither means anything a line at a time - a `for` that
# instantiates is a loop to any reader, and a `rotation =` beside a `velocity =` is two ordinary
# property writes - so both are claimed as RUNS, before any single line of them is looked at.
#
# THE ENTRIES ARE DERIVED, not written out. Each of the two rows carries its template with a branch
# per formation, per timing, per facing and per way of moving; an entry here is that template with
# those branches collapsed to ONE combination, turned into patterns mechanically: every character
# outside a `{slot}` escaped verbatim, every slot a named capture, and a slot spelled twice in one
# line a back reference to the first. The shape an entry stores is therefore the exact text the row
# emits for that combination, which is what makes the byte round trip the shape of the mechanism
# rather than a promise this file keeps. Adding a formation word to the module adds its entries here
# with nothing to edit.
#
# WHY THE FORMATION RUN OPENS ON A `var`. The loop reads its scene once, above the loop, which is
# worth a line on its own merits - a `load()` in the field is otherwise a lookup per copy. It is also
# what lets the run be recognised at all: the lifter reads a `for` at the top of a statement as a
# loop before it asks any run family about it, so a run that opened on the loop header would never be
# offered here. The `var` above it is the first statement of the run, and the loop is its second.
#
# WHAT IS NOT CLAIMED. A hand-written loop that spawns is still a loop: these entries want the whole
# shape, the group join and the placement local included, and anything short of it keeps the reading
# it already had. That is the intended failure - a run nothing here claims is an honest loop with
# honest rows in it, never a mangled formation.
@tool
class_name EventForgeSpawnRunLift
extends RefCounted

## The module the shapes come from, by path so the importer never waits on the editor's class cache.
const SPAWN := preload("res://addons/eventforge/registration/modules/spawn_aces.gd")

## The rows these runs mean. Frozen with the descriptors they name.
const FORMATION_ACE_ID: String = "SpawnFormation"
const FORMATION_ACE_ID_3D: String = "SpawnFormation3D"
const LAUNCHED_ACE_ID: String = "SpawnFacingAndMoving"
const LAUNCHED_ACE_ID_3D: String = "SpawnFacingAndMoving3D"

## The cheap first refusal each family of entries opens with - one `contains` that rules out nearly
## every statement in a project before a pattern is compiled, let alone run.
const FORMATION_MARK: String = "_scene = "
const LAUNCHED_MARK: String = ".instantiate()"

## The one slot whose value is always a GDScript identifier: the name the row gives the copy, which
## the run then spells four more times. Captured as an identifier rather than as an expression so the
## `_scene`, `_index`, `_place` and `_launch` suffixes around it cannot be swallowed into it.
const NAME_SLOT: String = "name"

## The value spans a slot can hold: an identifier for the name above, the rest of the line for a slot
## that ends its line, and the shortest run that still lets the line finish for one that does not.
const IDENTIFIER: String = EventForgeLiftGrammar.IDENTIFIER
const TO_END: String = ".+"
const UP_TO_NEXT: String = ".+?"

## Built once for the life of the session: sixty-odd entries, each a handful of patterns, and every
## one of them gated by its mark before anything is compiled.
static var _entries: Array[Dictionary] = []


## The row a run of statements means, or {} when nothing here claims it. `lines` is the function body
## as the lifter holds it, `index` the statement to try, `depth` its indentation.
static func match_run(lines: PackedStringArray, index: int, depth: int) -> Dictionary:
	return EventForgeLiftTable.match_run(lift_entries(), lines, index, depth)


## Every spelling the two rows write, as table entries. The launched entries that CARRY the spawner's
## speed come first, for the reason the layout family states about its own pair: their run is the
## shorter one with a line inside it, so asked the other way round the shorter entry would claim the
## first six statements of the longer one and leave its last line stranded.
static func lift_entries() -> Array[Dictionary]:
	if not _entries.is_empty():
		return _entries
	var built: Array[Dictionary] = []
	_add_formations(built, FORMATION_ACE_ID, SPAWN.formation_template(SPAWN.formation_places(),
		SPAWN.FORMATION_ORDER), SPAWN.FORMATION_ORDER, "", [])
	_add_formations(built, FORMATION_ACE_ID_3D, SPAWN.formation_template(SPAWN.formation_places_3d(),
		SPAWN.FORMATION_ORDER_3D), SPAWN.FORMATION_ORDER_3D, "3d_", [SPAWN.FORMATION_LINE])
	_add_launched(built, LAUNCHED_ACE_ID, SPAWN.launched_template(SPAWN.facing_lines(),
		"Vector2.from_angle({name}.rotation)", SPAWN.move_lines(SPAWN.BULLET_CHILD),
		SPAWN.FACING_ORDER), SPAWN.FACING_ORDER, "")
	_add_launched(built, LAUNCHED_ACE_ID_3D, SPAWN.launched_template(SPAWN.facing_lines_3d(),
		"-{name}.global_transform.basis.z", SPAWN.move_lines(SPAWN.BULLET_CHILD_3D),
		SPAWN.FACING_ORDER_3D), SPAWN.FACING_ORDER_3D, "3d_")
	_entries = built
	return _entries


## One statement of a canonical shape as the pattern that matches it: the author's own characters
## escaped, each `{slot}` a named capture, and a slot spelled again in the same line a back reference
## to what the first one read. `line` is the statement already dedented, which is how the engine hands
## a statement to a pattern.
static func statement_pattern(line: String) -> String:
	var slots: RegEx = RegEx.create_from_string("\\{([A-Za-z_][A-Za-z0-9_]*)\\}")
	if slots == null:
		return ""
	var pattern: String = ""
	var cursor: int = 0
	var seen: Dictionary = {}
	for hit: RegExMatch in slots.search_all(line):
		pattern += EventForgeLiftGrammar.escaped_run(line.substr(cursor, hit.get_start() - cursor))
		var slot: String = hit.get_string(1)
		if seen.has(slot):
			pattern += "\\k<%s>" % slot
		else:
			seen[slot] = true
			pattern += "(?<%s>%s)" % [slot, _span(slot, hit.get_end() == line.length())]
		cursor = hit.get_end()
	pattern += EventForgeLiftGrammar.escaped_run(line.substr(cursor))
	return "^%s$" % pattern


# ── the two families ─────────────────────────────────────────────────────────────────────────────


## The formation entries: one per shape word per timing. Ten of them per dimension, and every one is
## the same loop with one expression and two lines changed, which is exactly what the row itself is.
##
## `unclaimed` is the shape words this dimension writes a spelling for that the OTHER dimension
## already speaks for, character for character. The line formation is the whole of that list: it is
## `{around}.lerp({to}, …)` in both dimensions, because lerp is the point's own word whether the point
## has two numbers in it or three. Two entries for one spelling would split every such line between
## them by table order alone, so the 2D one keeps the reading and the 3D row is an authoring word -
## the same rule, and the same nothing-is-lost, as the twin placement expression the module states it
## for. The bytes a sheet emits are identical either way.
static func _add_formations(into: Array[Dictionary], ace_id: String, template: String,
		order: Array[String], tag: String, unclaimed: Array[String]) -> void:
	var defaults: Dictionary = _defaults_of(ace_id)
	for word: String in order:
		if unclaimed.has(word):
			continue
		for timing: String in [SPAWN.WHEN_NOW, SPAWN.WHEN_LATER]:
			into.append(_entry("spawn_formation_%s%s_%s" % [tag, word, timing], ace_id, template,
				{"formation": word, "when": timing}, defaults, defaults, FORMATION_MARK))


## The launched entries: one per facing per way of moving per answer to "and this node's own speed".
## The carried ones are added first, because their run is the other one with a line in the middle of
## it and a shorter run asked first would claim the front of a longer one.
static func _add_launched(into: Array[Dictionary], ace_id: String, template: String,
		order: Array[String], tag: String) -> void:
	var defaults: Dictionary = _defaults_of(ace_id)
	for carried: bool in [true, false]:
		for word: String in order:
			for moved: String in SPAWN.MOVE_ORDER:
				var chosen: Dictionary = {"facing": word, "moves": moved, "carry": carried}
				into.append(_entry("spawn_launched_%s%s_%s%s" % [tag, word, moved,
					"_carried" if carried else ""], ace_id, template, chosen, defaults, defaults,
					LAUNCHED_MARK))


## One entry, from the row's template with its branches collapsed to one combination. The shape IS
## that text; the statements are its lines turned into patterns, each at the indentation the shape
## writes it at; the params are the slots the shape has, and everything else the row carries rides in
## `defaults` so the row a lift hands back is the whole row rather than the part the line said.
static func _entry(id: String, ace_id: String, template: String, chosen: Dictionary,
		defaults: Dictionary, samples: Dictionary, mark: String) -> Dictionary:
	var shape: String = ActionCodegen.collapse_optional_segments(template, chosen)
	var statements: Array[Dictionary] = []
	for line: String in shape.split("\n"):
		var bare: String = line.lstrip("\t")
		statements.append({"pattern": statement_pattern(bare),
			EventForgeLiftTable.INDENT_KEY: line.length() - bare.length()})
	var params: PackedStringArray = EventForgeLiftTable.shape_slot_names(shape)
	var slots: Dictionary = {}
	for slot: String in params:
		slots[slot] = samples.get(slot, "")
	var remaining: Dictionary = defaults.duplicate()
	remaining.merge(chosen, true)
	for slot: String in params:
		remaining.erase(slot)
	return {
		"id": id,
		"ace_id": ace_id,
		EventForgeLiftTable.MARK_KEY: mark,
		EventForgeLiftTable.STATEMENTS_KEY: statements,
		"params": params,
		"defaults": remaining,
		"shape": shape,
		"slots": slots,
	}


## One row's parameter defaults, off the descriptor the module builds. Read from the module rather
## than written down here so a default that moves moves in one place: these are what a lifted row
## holds for the fields its own spelling never mentioned.
static func _defaults_of(ace_id: String) -> Dictionary:
	var values: Dictionary = {}
	for descriptor: ACEDescriptor in SPAWN.get_descriptors():
		if descriptor.ace_id != ace_id:
			continue
		for parameter: ACEParam in descriptor.params:
			values[parameter.id] = parameter.default_value
		return values
	return values


## How wide one slot's capture is allowed to be. The name is an identifier because the run spells it
## with four different suffixes glued on; a slot that ends its line takes the rest of the line; and
## anything else takes the shortest run that still lets the rest of the line match, which is what
## keeps two slots on one line from swallowing each other.
static func _span(slot: String, at_line_end: bool) -> String:
	if slot == NAME_SLOT:
		return IDENTIFIER
	return TO_END if at_line_end else UP_TO_NEXT
