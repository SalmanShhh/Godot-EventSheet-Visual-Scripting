# EventForge - the ASK runs: the branch that opens the player's own file chooser, read back as the
# one row that emits it.
#
# Ask For A File To Open and Ask Where To Save each compile to a BRANCH, on purpose: most desktops
# have a chooser of their own and a platform without one still has to ask somehow, so both spellings
# are emitted in an if/else a reader can see. That makes a single row fourteen statements on disk,
# and opened again it came back as fourteen: an if event holding a lambda and a call, and an else
# event holding eleven lines about a FileDialog. The sentence the sheet was written in was gone the
# first time it was reopened. This family claims the whole branch as the row that wrote it.
#
# THE SHAPE IS THE SHIPPED TEMPLATE, NEVER TYPED OUT HERE. Both shapes are read off the descriptors
# the compiler emits from, so the spelling this family recognises cannot drift from the spelling the
# compiler writes - and a change to either row's emitted code is a change to what this recognises,
# with no second copy to remember.
#
# HOW A RUN IS READ. Two values are pulled out of it and everything else is literal:
#
#   the uid       the suffix on the two locals the row names after itself (`__answer_7`,
#                 `__chooser_7`). It is not a value of the row - it is the dock's bake at apply time -
#                 so it is read off the one line that spells it alone, put back onto the template,
#                 and written out again exactly as it was found. A run whose two locals disagree is
#                 not claimed, because the template could not write it back.
#   the filters   the row's one field: which files the chooser offers. Read off the line the template
#                 spells it alone on, once the uid is known.
#
# AND THEN THE RUN IS WRITTEN AGAIN AND COMPARED BYTE FOR BYTE. That comparison is the whole
# guarantee, exactly as it is for the file runs beside this: a run this family hands back is one the
# compiler re-emits precisely as it found it, so anything the two readings above guessed wrong about
# is refused rather than saved back as something else. It also means a hand-written branch is claimed
# on the same terms as an emitted one, as long as every byte but the uid is the row's own.
#
# AND THE UID IS A SUFFIX, WHICH IS THE ONE LIMIT WORTH KNOWING. The reading above finds it by
# holding the shape's `var __answer_{uid} := ` against the line written there, so what a hand-written
# branch may choose is the part AFTER those stems: `__answer_mine` and `__chooser_mine` are claimed,
# `pick_answer` and `pick_chooser` are not. That is a narrower promise than "call them anything", and
# it is the honest one - a branch this family will not claim opens as the statements it is, byte for
# byte, which is the contract either way.
#
# THE RUN OPENS ON AN `if`, WHICH IS WHY THE LIFTER ASKS THIS FAMILY BEFORE ITS IF GRAMMAR. Every
# other run here opens on a statement; this one opens on a branch whose two halves are one row's
# code, and an `if` read as a block would hand back two events and lose the row.
#
# WHAT IS DELIBERATELY NOT CLAIMED: a branch with anything ADDED to either half. The row emits these
# lines and only these; a half somebody wrote a line into is a different program, and it opens as the
# statements it is.
@tool
class_name EventForgeAskRunLift
extends RefCounted

## Where the two Ask descriptors live, and the ids they are registered under. Loaded by path rather
## than by class name so the importer never waits on the editor's class cache - the rule every other
## file here follows.
const FILE_MODULE_PATH: String = "res://addons/eventforge/registration/modules/file_aces.gd"
const ASK_ACE_IDS: Array[String] = ["AskForAFileToOpen", "AskWhereToSave"]

## The cheap first refusal. Every statement of every opened file reaches this family, so a run is
## ruled out on a substring before a shape is built: both Ask rows open on the one question that asks
## whether this platform has a chooser of its own.
const OPENING_MARK: String = "DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)"

## The two slots a shape holds: the bake the dock made, and the row's own field.
const UID_SLOT: String = "{uid}"
const FILTERS_SLOT: String = "{filters}"

## The shipped templates, keyed by ace_id, read once and held for the life of the session - this
## family is asked about every `if` of every opened file, and loading the module per line was the
## whole cost of doing this at all.
static var _templates: Dictionary = {}


## The row a run of statements means, or {} when this family does not claim it. `lines` is the
## function body as the lifter holds it, `index` the statement the run would open on, and `depth` the
## indentation that statement is written at. Returns {ace_id, params, template, consumed}.
static func match_run(lines: PackedStringArray, index: int, depth: int) -> Dictionary:
	if index < 0 or index >= lines.size() or not lines[index].contains(OPENING_MARK):
		return {}
	for ace_id: String in ASK_ACE_IDS:
		var claimed: Dictionary = _match_ask(lines, index, depth, ace_id, _template_of(ace_id))
		if not claimed.is_empty():
			return claimed
	return {}


## One Ask row's branch, read at `index`, or {} when the lines there are not that row's own code.
static func _match_ask(lines: PackedStringArray, index: int, depth: int, ace_id: String,
		template: String) -> Dictionary:
	if template.is_empty():
		return {}
	var shape: PackedStringArray = template.split("\n")
	var written: PackedStringArray = _run_at(lines, index, depth, shape.size())
	if written.is_empty():
		return {}
	var uid: String = _slot_value(shape, written, UID_SLOT)
	if uid.is_empty():
		return {}
	var baked: PackedStringArray = template.replace(UID_SLOT, uid).split("\n")
	var filters: String = _slot_value(baked, written, FILTERS_SLOT)
	if filters.is_empty():
		return {}
	# The uid rides back onto the template exactly as the dock bakes it when a row is applied, so the
	# lifted row is the row the picker would have authored - and the filters stay a field, because
	# they are the only thing about this branch a person edits.
	var row_template: String = template.replace(UID_SLOT, uid)
	var params: Dictionary = {"filters": filters}
	if EventForgeLiftTable.emit_row(row_template, params, EventForgeLiftTable.DEFAULT_PROVIDER,
			ace_id) != "\n".join(written):
		return {}
	return {"ace_id": ace_id, "params": params, "template": row_template,
		"consumed": written.size()}


## The `count` lines at `index`, each with `depth` tabs taken off - or an empty list when the body
## ends first, when one of them is written shallower than the run, or when a line still deeper than
## the run's last one follows it. That last refusal is what keeps a branch somebody added a line to
## out of this reading: the row emits these lines and only these.
static func _run_at(lines: PackedStringArray, index: int, depth: int, count: int) -> PackedStringArray:
	var indent: String = "\t".repeat(depth)
	var written: PackedStringArray = PackedStringArray()
	for step: int in count:
		var at: int = index + step
		if at >= lines.size() or not lines[at].begins_with(indent):
			return PackedStringArray()
		written.append(lines[at].substr(depth))
	var after: int = index + count
	if after < lines.size() and lines[after].begins_with(indent + "\t"):
		return PackedStringArray()
	return written


## What one slot reads on the line the shape spells it alone on, or "" when no line spells it alone,
## or when the line written there does not have the shape's own text on either side of it. Reading a
## slot off a line that holds nothing else is what lets a value be pulled out without a pattern: the
## text before it and the text after it are both known exactly.
static func _slot_value(shape: PackedStringArray, written: PackedStringArray, slot: String) -> String:
	for step: int in mini(shape.size(), written.size()):
		var shape_line: String = shape[step]
		if shape_line.count(slot) != 1 or _has_another_slot(shape_line, slot):
			continue
		var at: int = shape_line.find(slot)
		var before: String = shape_line.substr(0, at)
		var after: String = shape_line.substr(at + slot.length())
		var line: String = written[step]
		if not line.begins_with(before) or not line.ends_with(after):
			continue
		var value: String = line.substr(before.length(),
			line.length() - before.length() - after.length())
		if not value.is_empty():
			return value
	return ""


## Whether a line of a shape holds a slot other than this one. A line with two of them cannot be read
## this way - neither value's ends are known until the other has been filled in - so it is skipped
## and the value is read off a line that spells it alone.
static func _has_another_slot(shape_line: String, slot: String) -> bool:
	for other: String in [UID_SLOT, FILTERS_SLOT]:
		if other != slot and shape_line.contains(other):
			return true
	return false


## One Ask row's shipped template, off the descriptor that ships it. Empty when the module cannot be
## read, which makes the shape refuse rather than guess at a spelling - and an empty answer is
## deliberately NOT remembered, so a read that failed once does not silence the family for the rest
## of the session.
static func _template_of(ace_id: String) -> String:
	if _templates.has(ace_id):
		return str(_templates[ace_id])
	var module: GDScript = load(FILE_MODULE_PATH)
	if module == null:
		return ""
	for descriptor: ACEDescriptor in module.get_descriptors():
		if descriptor.ace_id == ace_id:
			_templates[ace_id] = str(descriptor.codegen_template)
	return str(_templates.get(ace_id, ""))
