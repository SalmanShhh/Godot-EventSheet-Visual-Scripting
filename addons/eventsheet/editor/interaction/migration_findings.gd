# Godot EventSheets - the row whose verb the vocabulary no longer has.
#
# A pack is uninstalled, or a studio's own vocabulary drops a verb, and a sheet written against it is
# suddenly holding a word nobody answers to any more. The row is NOT broken: its template was baked
# onto it when it was applied, so it compiles to exactly the line it always compiled to, and its
# reading was baked beside the template, so it still says exactly what it said. What it has lost is
# the ability to be edited, re-picked or explained - and that is the whole of what this file reports.
#
# THE QUIET SHEET LAW. Nothing here renders in the sheet. A finding sets the quiet amber state and
# stops: no block, no icon, no inline sentence, no hover. The words live in the Doctor's triage inbox
# and in the help strip under the selected row, and a sheet with nothing to answer says nothing.
#
# TWO DOORS, AND THEY ARE DOORS RATHER THAN FIXES. "See what replaced it" opens the picker - at the
# forwarding address when the vocabulary carries one, at the near names otherwise - and the reader
# chooses. "Keep as code" turns the row into the same honest verbatim block every lift already falls
# back to, so the line stays exactly as written and re-lifts by itself if the words come back.
# Neither happens without somebody pressing something, and both go through the sheet's undo funnel.
#
# THE RULE IS NARROW ON PURPOSE, which is the difference between a section worth reading and a wall
# of noise. A row is only reported when it IS an ACE row (every other row kind answers `null` to a
# question about `ace_id`, which is "not a verb" rather than "a verb that is gone"), it names a plain
# verb (a reflected `method:`/`property:` id is generated on demand and is absent from every registry
# build by design), the vocabulary has no entry for it, AND it carries a baked template - because
# that template is what keeps it compiling, and a row with neither a verb nor a template is a
# different and worse thing to say.
#
# NOTHING IS STORED. Every finding is derived on every ask, so a row that is re-picked or kept as
# code stops reporting with no state to clean up.
#
# PURE + STATIC: no viewport, no dialog, no display server, so every word is pinned headless.
@tool
class_name EventSheetMigrationFindings
extends RefCounted

## The one finding, by id. Frozen: the amber state, the help strip, the Doctor's Migration section
## and the tests all address it by this - one finding under four roofs.
const KIND_VERB_GONE := "migration-verb-gone"

## Where the note hangs. The finding is about a row inside an event, so it anchors at the event - the
## same anchor the spawning, networking and tool-edit notes use for the same reason.
const ANCHOR_EVENT := "event"

## The two doors, by the ids the dock's strip and the inbox chip both dispatch on.
const FIX_SEE_REPLACEMENT := "see_what_replaced_it"
const FIX_KEEP_AS_CODE := "keep_it_as_code"

## A generated id carries the member it reflects after a colon (`method:play`, `property:speed`).
## Such a verb is built on demand from whatever the project's own scripts hold, so it is absent from
## a registry build for perfectly ordinary reasons and is never a verb the vocabulary "lost".
const GENERATED_ID_MARK := ":"

# The `{slot}` shape and a run of spaces, compiled once for the whole session: a stored reading may
# name a parameter the row never answered, and printing the vocabulary's own placeholder at a reader
# is worse than a slightly shorter sentence.
static var _unfilled_slot_re: RegEx = null
static var _run_of_spaces_re: RegEx = null


## Every gone-verb note this sheet earns, one per row that names a verb the vocabulary has no entry
## for. `known` answers "does this project still have <provider, ace_id>" and is the caller's,
## because the editor asks its live registry and a headless run asks the shipped catalogue - two
## corpora, one rule. `script_path` is the file the sheet lives in and is only the label the
## sentence leads with; a sheet with no file yet leads with nothing rather than with a guess.
static func findings(sheet: EventSheetResource, script_path: String = "",
		known: Callable = Callable()) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if sheet == null or not known.is_valid():
		return found
	var label_path: String = script_path if not script_path.is_empty() else str(sheet.resource_path)
	# The behaviour host accessor, spelled the way the compiler spells it: a behaviour sheet compiles
	# to a Node that acts on its PARENT, so its node-scoped rows emit `host.` in front. Read once per
	# sheet, because it is a fact about the sheet and not about any row.
	var host: String = "host" if sheet.behavior_mode else ""
	_walk(sheet.events, label_path.get_file(), known, found, "", host)
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function != null:
			_walk(_function_rows(event_function), label_path.get_file(), known, found, "", host)
	return found


## The findings anchored at one event row - what the canvas puts into the amber state. Matched by
## IDENTITY, so the caller never has to name a row that has no name.
static func for_event(found: Array[Dictionary], event_row: EventRow) -> Array[Dictionary]:
	var mine: Array[Dictionary] = []
	if event_row == null:
		return mine
	for entry: Dictionary in found:
		if str(entry.get("anchor", "")) == ANCHOR_EVENT and entry.get("event") == event_row:
			mine.append(entry)
	return mine


## How many EVENTS of this sheet hold a verb the vocabulary no longer has - the "ask you" half of the
## head band's counting line. Counted per event rather than per row, because the band counts rows a
## reader would go and look at.
static func events_asking(found: Array[Dictionary]) -> int:
	var seen: Array = []
	for entry: Dictionary in found:
		var event_row: Variant = entry.get("event")
		if event_row != null and not seen.has(event_row):
			seen.append(event_row)
	return seen.size()


## A resolver over a fixed set of "<provider>::<ace_id>" keys - what a test hands in, and the shape
## the editor and the Doctor each build their own version of.
static func resolver_over(keys: Dictionary) -> Callable:
	return func(provider_id: String, ace_id: String) -> bool:
		return keys.has(EventForgeSuccessors.key_of(provider_id, ace_id))


## The resolver a headless run uses: the shipped vocabulary as the forwarding-address catalogue
## reflects it, which is the built-in descriptors plus every installed pack. Built once and closed
## over, so a walk of a hundred rows reflects the packs once rather than a hundred times.
static func catalog_resolver() -> Callable:
	return resolver_over(EventForgeSuccessors.catalog())


## Where this row's verb went, as a "<provider>::<ace_id>" key, or "" when the vocabulary has no
## forwarding address for it. A verb that is gone is usually gone without one - the address is
## carried BY the old entry, and the old entry is what is missing - so this answers for the case
## where the catalogue still holds the map even though the editor's registry no longer offers the
## verb, and says nothing at all otherwise.
##
## ASKED AT THE DOOR, NEVER DURING THE WALK. The forwarding-address catalogue reflects every
## installed pack to answer, which is a fine price for a button somebody pressed and a terrible one
## for a sweep that runs every time a sheet is drawn. So the finding carries the key it is ABOUT and
## the two consumers - the picker door and the comment offer - ask this when a person acts.
static func replacement_key_of(key: String) -> String:
	var resolved: Dictionary = EventForgeSuccessors.resolve(key)
	return "" if resolved.is_empty() else str(resolved[EventForgeSuccessors.KEY_ID])


## What the picker should be opened on: the words of the verb that is gone, so a search over the
## installed vocabulary lands on the nearest thing to it. The id's own words rather than the id -
## "FlickerLight" is not a search anybody's vocabulary answers, "Flicker Light" is.
static func near_names(ace_id: String) -> String:
	var words: String = ace_id.strip_edges()
	if words.contains(GENERATED_ID_MARK):
		words = words.substr(words.rfind(GENERATED_ID_MARK) + 1)
	return words.capitalize()


## A row's stored reading, filled with its own values - the sentence such a row shows in the sheet,
## the sentence the receipt puts on the left of its arrow, and the sentence the offered comment
## names. One filling, so the three can never disagree.
##
## The stored half is the display TEMPLATE with its slots intact, so the sentence still follows the
## row when a value is edited. A slot the row has no value for is dropped rather than left showing
## `{name}` - the descriptor that knew that parameter's default is exactly what is gone - and the gap
## it leaves closes with it, so the sentence still reads as one.
##
## It goes through the catalog like every other display template: a sentence this plugin wrote is
## prose, and a reader in another language should not lose theirs because a pack was uninstalled.
static func reading_text(stored: String, params_dict: Dictionary) -> String:
	var template: String = stored.strip_edges()
	if template.is_empty():
		return ""
	var text: String = EventSheetL10n.translate(template)
	for key: Variant in params_dict.keys():
		text = text.replace("{%s}" % str(key), str(params_dict[key]))
	if _unfilled_slot_re == null:
		_unfilled_slot_re = RegEx.new()
		_unfilled_slot_re.compile("\\{[A-Za-z_][A-Za-z0-9_]*\\}")
	if _run_of_spaces_re == null:
		_run_of_spaces_re = RegEx.new()
		_run_of_spaces_re.compile("[ \\t]{2,}")
	return _run_of_spaces_re.sub(_unfilled_slot_re.sub(text, "", true), " ", true).strip_edges()


## The words, in one place, so the Doctor's line and the sentence the sheet's own help strip shows
## under the selected row are the same finding said once. `pack` is the provider the row names,
## `reading` what the row still says, and `line` the code it still compiles to - the three facts a
## reader needs before deciding between the two doors.
static func verb_gone_message(pack: String, reading: String, line: String) -> String:
	var message: String = EventSheetL10n.translate("%s no longer has this verb.") % pack
	message += " " + EventSheetL10n.translate("The row still reads \"%s\" and still compiles to %s, because both were written onto it when it was added - what it has lost is the vocabulary that could edit or explain it.") % [
		reading, line]
	message += " " + EventSheetL10n.translate("See what replaced it to pick the verb that stands there now, or keep it as code to hold the line exactly as it is.")
	return message


## One row's emitted code - the line the sentence above quotes, and the line "Keep as code" would
## hold. THE COMPILER'S OWN CALL, with the compiler's own arguments: the enclosing "With node X:"
## scope and the behaviour host accessor, both carried down the walk exactly as the compiler carries
## them. Filling the template by hand instead would be a second emitter, and a second emitter is a
## second answer - a row inside a scope would have been kept as a call on the wrong node.
##
## "" when the row compiles to nothing, which is a row with no baked template and no descriptor left
## to fall back on: a different and louder state than a row that has outlived its words.
static func emitted_line(entry: Resource, scope: String = "", host: String = "") -> String:
	if entry is ACEAction:
		return ActionCodegen.generate_action(entry as ACEAction, scope, host).strip_edges()
	if entry is ACECondition:
		return ConditionCodegen.generate_condition(entry as ACECondition, host).strip_edges()
	return ""


## The comment "Keep as code" offers to leave above the kept line - the note a developer would have
## typed themselves, saying what the line was and where its words went. Offered in the receipt and
## strikeable there: a comment nobody wants is a comment they would delete on the next read.
##
## ENGLISH, deliberately, and not through the catalog. This is a line of the reader's own `.gd` file
## from the moment it is written, exactly like every other string the compiler emits, and a source
## comment that changed language with the editor's locale would be a surprise in a diff.
## "" for a row with nothing to say about itself.
static func kept_comment(reading: String, pack: String, replacement_name: String) -> String:
	var sentence: String = reading.strip_edges()
	if sentence.is_empty():
		return ""
	# The row's own sentence leads, because that is the thing the code below no longer says.
	var said: String = "# %s - the old %s row, kept as written." % [sentence, pack.strip_edges()] \
		if not pack.strip_edges().is_empty() else "# %s - kept as written." % sentence
	if not replacement_name.strip_edges().is_empty():
		said += " The vocabulary spells it %s now." % replacement_name.strip_edges()
	return said


## What "Keep as code" WOULD do to the row, as the before/after pair the dialog draws before anybody
## presses anything: the sentence the row reads now, and the line it becomes. Pure, so the receipt
## and the edit can never be two different answers.
static func keep_as_code_receipt(finding: Dictionary, comment: String) -> Dictionary:
	var line: String = str(finding.get("line", ""))
	var reading: String = str(finding.get("reading", "")).strip_edges()
	return {
		"before": reading if not reading.is_empty() else str(finding.get("subject", "")),
		"after": line if comment.strip_edges().is_empty() else "%s\n%s" % [comment, line],
		"line": line,
	}


## One finding's second door: the row, kept as the honest verbatim block every lift already falls
## back to. The emitted line is held exactly as it was written, so the compiled file does not move a
## byte, and the block is precisely what the lift tables read - so the row lifts back into words by
## itself if the vocabulary ever grows them again.
##
## Only the ACTION lane, and that is a fact about the sheet rather than a shortcut: a condition is a
## term inside an `if`, and a verbatim block is a statement. A condition whose verb is gone keeps its
## first door and says so.
##
## False when there is nothing to write, which is how a caller that repairs in a loop ends.
static func keep_it_as_code(finding: Dictionary, comment: String = "") -> bool:
	var event_row: EventRow = finding.get("event", null) as EventRow
	var slot: int = int(finding.get("index", -1))
	var line: String = str(finding.get("line", "")).strip_edges()
	if event_row == null or line.is_empty() or str(finding.get("lane", "")) != "action":
		return false
	if slot < 0 or slot >= event_row.actions.size():
		return false
	if event_row.actions[slot] is RawCodeRow:
		return false
	var block := RawCodeRow.new()
	block.code = line if comment.strip_edges().is_empty() else "%s\n%s" % [comment.strip_edges(), line]
	block.enabled = bool(event_row.actions[slot].get("enabled"))
	# Editor-only and never emitted: why this block is a block, for the reader who meets it later.
	block.lift_note = EventSheetL10n.translate("Kept as code when the vocabulary stopped offering %s.") \
		% str(finding.get("subject", ""))
	event_row.actions[slot] = block
	return true


## One walk of the rows. Recursive because a row in a sub-event is still a row of the file, and it
## carries the enclosing "With node X:" scope down with it exactly as the compiler's own walk does -
## an event inside a scope inherits it unless it names one of its own.
static func _walk(items: Array, label: String, known: Callable, found: Array[Dictionary],
		scope: String, host: String) -> void:
	for item: Variant in items:
		if item is EventGroup:
			_walk(EventSheetGroupFacts.children(item as EventGroup), label, known, found, scope, host)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		var own: String = event_row.with_node_target.strip_edges()
		var here: String = own if not own.is_empty() else scope
		_note_this_event(event_row, label, known, found, here, host)
		_walk(event_row.sub_events, label, known, found, here, host)


## The findings ONE event earns: one per row of it whose verb the vocabulary no longer has. Both
## lanes, in reading order, because a condition loses its words exactly the way an action does.
static func _note_this_event(event_row: EventRow, label: String, known: Callable,
		found: Array[Dictionary], scope: String, host: String) -> void:
	for slot: int in event_row.conditions.size():
		_note_this_row(event_row, event_row.conditions[slot], "condition", slot, label, known,
			found, scope, host)
	for slot: int in event_row.actions.size():
		_note_this_row(event_row, event_row.actions[slot] as Resource, "action", slot, label,
			known, found, scope, host)


## One row, measured against the rule the header states. Everything it declines to report is declined
## for a named reason, because a section that reports a row nobody can act on is a section its reader
## learns to scroll past.
static func _note_this_row(event_row: EventRow, entry: Resource, lane: String, slot: int,
		label: String, known: Callable, found: Array[Dictionary], scope: String,
		host: String) -> void:
	# An ACE ROW AND NOTHING ELSE. Both lanes hold other kinds - a verbatim block, a custom block, a
	# match, a timeline - and every one of them answers `null` to a question about `ace_id`, which is
	# not "a verb the vocabulary lost" but "not a verb at all". Asking by TYPE rather than by which
	# kinds to skip is what keeps a row kind added tomorrow out of this section for free.
	if not (entry is ACEAction or entry is ACECondition):
		return
	var ace_id: String = str(entry.get("ace_id")).strip_edges()
	if ace_id.is_empty() or ace_id.contains(GENERATED_ID_MARK):
		return
	var provider_id: String = str(entry.get("provider_id")).strip_edges()
	if bool(known.call(provider_id, ace_id)):
		return
	# The baked template is what keeps the row compiling, and a row that does not compile is a
	# different and louder thing than a row that has outlived its words.
	var line: String = emitted_line(entry, scope, host)
	if line.is_empty():
		return
	# The reading as the SHEET shows it, values and all - what the strip quotes, what the receipt puts
	# on the left of its arrow, and what the offered comment names. A row applied before readings were
	# baked has none, and falls back to its id rather than to nothing.
	var params: Variant = entry.get("params")
	var reading: String = reading_text(str(entry.get("display_text")),
		params if params is Dictionary else {})
	var pack: String = provider_id if not provider_id.is_empty() else ace_id
	found.append({
		"kind": KIND_VERB_GONE, "severity": "warning",
		"anchor": ANCHOR_EVENT, "event": event_row,
		"subject": ace_id,
		"message": verb_gone_message(pack, reading if not reading.is_empty() else ace_id, line),
		"fix": FIX_SEE_REPLACEMENT,
		"fix_label": EventSheetL10n.translate("See what replaced it"),
		# The second door is the action lane's alone: a verbatim block is a statement, and a
		# condition is a term inside an `if`. A condition with no door for it offers none rather
		# than one that cannot open.
		"second_fix": FIX_KEEP_AS_CODE if lane == "action" else "",
		"second_fix_label": EventSheetL10n.translate("Keep as code") if lane == "action" else "",
		"lane": lane, "index": slot, "path": label,
		"reading": reading,
		"from": EventForgeSuccessors.key_of(provider_id, ace_id),
		"line": line,
	})


## One function's rows. A function built by the editor holds `events`; one lifted out of a
## hand-written file may hold `rows` instead, and every walk in this plugin reads both - a reader
## that read one of them would go quiet on exactly the files this plugin is for.
static func _function_rows(event_function: EventFunction) -> Array:
	return event_function.events if not event_function.events.is_empty() else event_function.rows
