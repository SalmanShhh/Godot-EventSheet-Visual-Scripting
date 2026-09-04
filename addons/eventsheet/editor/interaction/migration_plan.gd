# Godot EventSheets - what a sheet's rows WOULD be rewritten to, and whether each rewrite can prove
# itself.
#
# A verb that has been superseded keeps its id, its template and its place in the picker forever, and
# a row written on it is not wrong. But somebody who wants their sheets written the way the
# vocabulary spells things today should be able to say so once and have it done - and the difference
# between that and a disaster is that every rewritten row proves itself first.
#
# NEVER ON OPEN, NEVER ON SAVE, NEVER AUTOMATIC. Nothing here writes anything. It answers "what would
# change", and the answer is drawn as a receipt in a dialog a person opened, and applied by a button
# that person pressed, through the sheet's own undo funnel. Opening a sheet and saving it untouched
# never consults this file at all.
#
# THE GATE, PER ROW, BEFORE ANYTHING COMMITS. The rewritten row is emitted through the compiler's own
# emitter, the line it wrote is READ BACK through the importer's own reverse grammar, and the row
# that comes back has to be the same verb and write the same byte. That is the lossless round-trip
# law asked one row at a time: a migrated line has to be a line this editor reads back as the row it
# just wrote, or the next person to open the file gets a different sheet. A row that cannot prove
# that stays on the spelling it has, and the dialog says which one and why. The one rewrite that is
# proved WITHOUT reading anything back is the one that writes the line already there, character for
# character: no file changes, so there is no new line to read and no way for the next person to get
# a different sheet.
#
# WRITTEN FRESH IS THE STANDARD. A migrated row lands with the values it carried under their new
# names and a value for each parameter the successor has that the old row never did - and with
# nothing else. An argument that would only restate what the callee already declares as its own
# default is not written, because it is not an argument anybody typing the line would write. The line
# that lands is the line somebody would have typed.
#
# IT REFUSES MORE THAN IT ACCEPTS, on purpose. A verb that needs baking to land (a `{uid}` of its
# own, a member, a prelude, a term the compiler hoists) has to be PICKED rather than rewritten -
# the dock bakes those at apply time and the compiler never does - so a rewrite onto one is refused
# with that as its reason rather than emitting an unbaked slot into somebody's file.
#
# AND THE FILE ITSELF HAS THE LAST WORD. Reading a line back is not the same as the line being
# GDScript: a value that was a piece of text under the old verb can land in a slot the new one spells
# as a name, and emit + lift would agree with itself all the way to a file that will not parse. So
# every candidate is also compiled INTO the sheet, on a copy, and the written file is put through
# Godot's own parser. A row the file refuses is left on the spelling it has.
#
# PURE + STATIC: no viewport, no dialog and no display server, so every value here is pinned
# headless. The compiler runs only where there is something to migrate, which is nearly nowhere -
# a sheet whose rows are all in the current spelling is answered by the walk alone.
@tool
class_name EventSheetMigrationPlan
extends RefCounted

## The lane a planned row sits in, spelled the way every other finding in this pass spells it.
const LANE_CONDITION := "condition"
const LANE_ACTION := "action"

## Why a row was left alone, by the id the dialog and the report both read. Words, not codes, is the
## rule everywhere else in this plugin - these are ids because the sentence a reader sees is built
## from one of them plus the row's own facts, and two surfaces saying it differently would be two
## answers.
const WHY_NO_SUCCESSOR := "no-successor"
const WHY_NEEDS_PICKING := "needs-picking"
const WHY_UNPROVABLE := "unprovable"
const WHY_FILE_REFUSES := "file-refuses"

## Where a candidate rewrite is compiled, and it is NEVER the sheet's own file: `SheetCompiler.compile`
## writes its output to the path it is given, so asking a question about a sheet under that sheet's
## real path would save the trial answer over somebody's work.
const COMPILE_PROBE_PATH: String = "user://eventforge_migration_gate.gd"


## Every row of this sheet that migration has something to say about, in reading order.
##
## Two populations, and they are genuinely different states. A row whose verb has a forwarding
## address can be rewritten; a row whose verb the vocabulary no longer has at all cannot, because
## the address would have been carried by the entry that is missing. Both are listed - a report that
## showed only the first would tell somebody their sheet was clean while a row in it had outlived
## its words.
##
## A row written in the CURRENT spelling is not here at all, which is nearly every row of nearly
## every sheet.
##
## `known` is the vocabulary to answer against, so a test can hand in a corpus of three and the
## editor and the Doctor can share one reflection of the installed packs.
static func plan(sheet: EventSheetResource, known: Dictionary = {}) -> Array[Dictionary]:
	var planned: Array[Dictionary] = []
	if sheet == null:
		return planned
	var vocabulary: Dictionary = known if not known.is_empty() else EventForgeSuccessors.catalog()
	if vocabulary.is_empty():
		return planned
	# The behaviour host accessor, spelled the way the compiler spells it: a behaviour sheet compiles
	# to a Node that acts on its PARENT, so its node-scoped rows emit `host.` in front. A fact about
	# the sheet, read once rather than per row.
	var host: String = "host" if sheet.behavior_mode else ""
	var counter: Array[int] = [0]
	_walk(sheet.events, vocabulary, planned, "", host, counter)
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function != null:
			_walk(_function_rows(event_function), vocabulary, planned, "", host, counter)
	_hold_to_the_file(sheet, vocabulary, planned)
	return planned


## The last gate, and the only one that asks the FILE. Every candidate is written into a copy of the
## sheet on its own, the copy is compiled, and the GDScript that came out is put through Godot's own
## parser. A candidate the parser refuses is put back and listed as a row the file will not take.
##
## On a COPY, always, so a question about a sheet never touches the sheet somebody is looking at. The
## copy is walked again rather than reached into: the walk is deterministic, so the row at ordinal N
## of the copy is the row at ordinal N of the original, and no reference crosses between the two.
##
## A sheet that does not parse BEFORE anything is migrated has a problem migration did not cause and
## cannot answer for, so its rows fall back to the round-trip gate they already passed.
static func _hold_to_the_file(sheet: EventSheetResource, known: Dictionary,
		planned: Array[Dictionary]) -> void:
	var candidates: Array[Dictionary] = migrating(planned)
	if candidates.is_empty():
		return
	var copy: EventSheetResource = sheet.duplicate(true)
	if copy == null:
		return
	var mirror: Array[Dictionary] = []
	var host: String = "host" if copy.behavior_mode else ""
	var counter: Array[int] = [0]
	_walk(copy.events, known, mirror, "", host, counter)
	for entry: Variant in copy.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function != null:
			_walk(_function_rows(event_function), known, mirror, "", host, counter)
	if mirror.size() != planned.size():
		return
	var baseline: Dictionary = SheetCompiler.compile(copy, COMPILE_PROBE_PATH)
	var baseline_parses: bool = bool(baseline.get("success", false)) \
		and parses(str(baseline.get("output", "")))
	if not baseline_parses:
		return
	for index: int in planned.size():
		if bool(planned[index].get("asks", true)):
			continue
		var trial: Dictionary = mirror[index]
		var row: Resource = trial.get("row", null) as Resource
		if row == null:
			continue
		var held: Dictionary = _identity_of(row)
		apply([trial])
		var written: Dictionary = SheetCompiler.compile(copy, COMPILE_PROBE_PATH)
		var accepted: bool = bool(written.get("success", false)) \
			and parses(str(written.get("output", "")))
		_restore_identity(row, held)
		if not accepted:
			planned[index]["asks"] = true
			planned[index]["why"] = WHY_FILE_REFUSES
			planned[index]["after"] = ""
			planned[index]["reading_after"] = ""


## Whether this GDScript is GDScript. The `class_name` line is dropped first: a probe built from a
## string is not a file, and asking the engine to parse a global class declaration that belongs to a
## file somewhere else is a question about the wrong thing.
##
## THE ENGINE IS ASKED QUIETLY. A refused candidate is the WHOLE POINT of this call - it is how a
## rewrite that would not compile gets left alone - but `reload()` prints the parse error and a
## backtrace into the editor's Output as it answers, so merely opening the Migrate dialog over a
## sheet with a refusable row filled the console with SCRIPT ERROR lines and read as a broken
## project. The printing is turned off around the one call and put back exactly as it was found, so a
## project that had it off stays off.
static func parses(source: String) -> bool:
	if source.strip_edges().is_empty():
		return false
	var kept: PackedStringArray = PackedStringArray()
	for line: String in source.split("\n"):
		if not line.begins_with("class_name "):
			kept.append(line)
	var probe: GDScript = GDScript.new()
	probe.source_code = "\n".join(kept)
	var was_printing: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	var verdict: int = probe.reload(true)
	Engine.print_error_messages = was_printing
	return verdict == OK


## The five fields a rewrite moves, held so a trial can be put back exactly as it was.
static func _identity_of(row: Resource) -> Dictionary:
	return {
		"provider_id": str(row.get("provider_id")), "ace_id": str(row.get("ace_id")),
		"codegen_template": str(row.get("codegen_template")),
		"params": (row.get("params") as Dictionary).duplicate(true),
		"display_text": str(row.get("display_text")),
	}


static func _restore_identity(row: Resource, held: Dictionary) -> void:
	for field: Variant in held.keys():
		row.set(str(field), held[field])


## ONE PLAN AS THE RECEIPT IT DRAWS, so two plans can be compared without holding either of them.
##
## The dialog draws a plan and the button applies a plan built AGAIN a moment later - it has to, since
## no row reference may cross the undo funnel - and the two are only the same plan if the sheet did
## not move in between. A row pasted, edited or deleted while the window was open would otherwise be
## rewritten without ever having appeared in "What will be rewritten". This is what the button
## compares: every row of the plan, in order, as the facts a reader was shown plus the verdict that
## was reached about it. Strings, so the comparison is between two readings rather than between two
## sets of live resources.
static func receipt_of(planned: Array[Dictionary]) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for entry: Dictionary in planned:
		lines.append("%d	%s	%s	%s	%s	%s	%s" % [
			int(entry.get("ordinal", 0)), str(entry.get("from", "")), str(entry.get("to", "")),
			str(entry.get("before", "")), str(entry.get("after", "")),
			"asks" if bool(entry.get("asks", true)) else "moves", str(entry.get("why", "")),
		])
	return lines


## The rows of `planned` that would be rewritten - everything the Apply button acts on.
static func migrating(planned: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in planned:
		if not bool(entry.get("asks", true)):
			out.append(entry)
	return out


## The rows of `planned` that are listed and left exactly as they are, each carrying the reason.
static func asking(planned: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in planned:
		if bool(entry.get("asks", true)):
			out.append(entry)
	return out


## THE EDIT. Every proved row of this plan, rewritten onto the spelling the vocabulary uses today,
## and the count of what changed.
##
## Called from INSIDE the sheet's undo funnel and nowhere else: the funnel replaces every resource
## with a snapshot duplicate when it commits, so a plan is built against the live sheet, applied, and
## dropped - never held across the commit. Returns how many rows moved, which is what makes the whole
## thing one undo step rather than none.
static func apply(planned: Array[Dictionary]) -> int:
	var moved: int = 0
	for entry: Dictionary in migrating(planned):
		var row: Resource = entry.get("row", null) as Resource
		if row == null:
			continue
		var address: PackedStringArray = EventForgeSuccessors.split_key(str(entry.get("to", "")))
		row.set("provider_id", address[0])
		row.set("ace_id", address[1])
		row.set("codegen_template", str(entry.get("template_after", "")))
		row.set("params", (entry.get("params_after", {}) as Dictionary).duplicate(true))
		# The reading rides along, for the reason it was baked in the first place: a row must go on
		# saying what it says if the pack it now names is ever uninstalled in its turn.
		row.set("display_text", str(entry.get("display_after", "")))
		moved += 1
	return moved


## One walk of the rows, carrying the enclosing "With node X:" scope down exactly as the compiler's
## own walk does - an event inside a scope inherits it unless it names one of its own.
static func _walk(items: Array, known: Dictionary, planned: Array[Dictionary], scope: String,
		host: String, counter: Array[int]) -> void:
	for item: Variant in items:
		if item is EventGroup:
			_walk(EventSheetGroupFacts.children(item as EventGroup), known, planned, scope, host,
				counter)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		var own: String = event_row.with_node_target.strip_edges()
		var here: String = own if not own.is_empty() else scope
		for slot: int in event_row.conditions.size():
			_plan_row(event_row, event_row.conditions[slot] as Resource, LANE_CONDITION, slot,
				known, planned, here, host, counter)
		for slot: int in event_row.actions.size():
			_plan_row(event_row, event_row.actions[slot] as Resource, LANE_ACTION, slot,
				known, planned, here, host, counter)
		_walk(event_row.sub_events, known, planned, here, host, counter)


## One row, measured. Everything it declines to plan is declined for a named reason, because a list
## that reports a row nobody can act on is a list its reader learns to scroll past.
static func _plan_row(event_row: EventRow, row: Resource, lane: String, slot: int,
		known: Dictionary, planned: Array[Dictionary], scope: String, host: String,
		counter: Array[int]) -> void:
	# AN ACE ROW AND NOTHING ELSE. Both lanes hold other kinds - a verbatim block, a custom block, a
	# match, a timeline - and every one of them answers `null` to a question about `ace_id`, which is
	# "not a verb" rather than "a verb with a newer spelling".
	if not (row is ACEAction or row is ACECondition):
		return
	var ace_id: String = str(row.get("ace_id")).strip_edges()
	if ace_id.is_empty():
		return
	# THE ORDINAL IS THE ROW'S PLACE AMONG THIS SHEET'S VERB-CARRYING ROWS, counted HERE - before any
	# of the reasons below to say nothing about it. That is what the public report's `row` key promises,
	# what the guide's table says, and what "Event %d writes ..." means in the gate's own failure line:
	# an address a person can count to in the sheet in front of them. Counted after the early returns
	# instead, it was the row's place among the PLANNED rows - a different number on any sheet where
	# some rows are current and some are not, which is every sheet the report has anything to say about.
	counter[0] += 1
	var provider_id: String = str(row.get("provider_id")).strip_edges()
	var key: String = EventForgeSuccessors.key_of(provider_id, ace_id)
	var here: Variant = known.get(key)
	# A verb the vocabulary DOES have is a verb whatever its id looks like - a pack publishes its
	# functions as `method:` ids and half the forwarding addresses in this plugin are on those. The
	# generated-id rule below applies only to the other branch, where absence from the vocabulary has
	# to be read as a lost verb rather than as a member built on demand from the project's own scripts.
	if not (here is Dictionary) and ace_id.contains(EventSheetMigrationFindings.GENERATED_ID_MARK):
		return
	var resolved: Dictionary = {} if not (here is Dictionary) else EventForgeSuccessors.resolve(key, known)
	# A row on the current spelling with nowhere newer to go is not a migration question at all, and
	# is the state nearly every row of nearly every sheet is in.
	if here is Dictionary and resolved.is_empty():
		return
	var before: String = EventSheetMigrationFindings.emitted_line(row, scope, host)
	if before.is_empty():
		# A row with no baked template and no descriptor left to fall back on compiles to nothing,
		# which is a different and louder state than a row that has been superseded.
		return
	var params: Variant = row.get("params")
	var old_params: Dictionary = params.duplicate(true) if params is Dictionary else {}
	var stored_reading: String = str(row.get("display_text"))
	var listed: Dictionary = {
		"ordinal": counter[0], "event": event_row, "row": row, "lane": lane, "index": slot,
		"from": key, "to": "", "before": before, "after": "",
		"reading_before": EventSheetMigrationFindings.reading_text(stored_reading, old_params),
		"reading_after": "", "params_after": {}, "template_after": "", "display_after": "",
		"asks": true, "why": WHY_NO_SUCCESSOR,
	}
	if not (here is Dictionary):
		# The verb is gone from the vocabulary entirely. Nothing can carry a forwarding address for
		# it, because the address would have been carried by the entry that is missing - so this row
		# is listed and left, and its two doors are the ones the row's own help strip offers.
		planned.append(listed)
		return
	var successor_key: String = str(resolved[EventForgeSuccessors.KEY_ID])
	var successor: Dictionary = known.get(successor_key, {})
	listed["to"] = successor_key
	if successor.is_empty():
		planned.append(listed)
		return
	# A verb that needs baking to land has to be PICKED. The dock bakes a `{uid}`, a member and a
	# prelude at apply time and the compiler never does, so a rewrite that only copied ids and values
	# onto one would put an unbaked slot into somebody's file.
	if bool(successor.get("needs_baking", false)) or _carries_state(row):
		listed["why"] = WHY_NEEDS_PICKING
		planned.append(listed)
		return
	var rewritten: Dictionary = _rewritten(row, resolved, successor, scope, host, before)
	if rewritten.is_empty():
		listed["why"] = WHY_UNPROVABLE
		planned.append(listed)
		return
	listed["asks"] = false
	listed["why"] = ""
	listed["after"] = str(rewritten["line"])
	listed["params_after"] = rewritten["params"]
	listed["template_after"] = str(successor.get("template", ""))
	listed["display_after"] = str(successor.get("display_template", ""))
	listed["reading_after"] = EventSheetMigrationFindings.reading_text(
		str(listed["display_after"]), rewritten["params"] as Dictionary)
	planned.append(listed)


## The rewritten row, once it has proved itself: {"line", "params"}, or {} when it could not.
##
## THE VALUES ARE EXACTLY WHAT THE MAP PROMISES and not one more: every value the row already carries,
## under the name the successor calls it, plus a value for each parameter the old row never had. What
## is deliberately NOT written is anything the successor already declares for itself - an argument
## that only restates the callee's own default is an argument a hand author would not have typed, and
## the emitter drops such a slot where the template makes it optional and fills it where it does not.
## Writing them in would have made every migrated line longer than the line beside it in the picker.
##
## A parameter nothing answers is not a hole this papers over: a slot left showing in the emitted
## line is refused below, and the pack gate refuses a map that leaves one before it can ship.
static func _rewritten(row: Resource, resolved: Dictionary, successor: Dictionary, scope: String,
		host: String, before: String) -> Dictionary:
	var params: Variant = row.get("params")
	var written: Dictionary = EventForgeSuccessors.rewrite_params(
		params.duplicate(true) if params is Dictionary else {}, resolved,
		successor.get("params", PackedStringArray()))
	var line: String = _proved_line(row, successor, written, scope, host, before)
	return {} if line.is_empty() else {"line": line, "params": written}


## One candidate rewrite's line, or "" when it cannot prove itself.
##
## THE GATE. The row is emitted through the compiler's own emitter; the line is read back through the
## importer's own reverse grammar; and the row that comes back has to name the same verb and write
## the same byte again. A line with a slot still showing in it is refused before any of that - that
## is a parameter nothing answered, and a row that landed with a hole in it would compile to code
## with braces in it.
##
## AND A REWRITE THAT WRITES THE BYTE THE ROW ALREADY WRITES HAS NOTHING TO READ BACK. The gate above
## asks one question - would the next person to open this file get a different sheet - and it asks it
## by reading the new line. When the successor emits the line that is already there, character for
## character, no file changes and there is no new line: whatever that line read back as before the
## rewrite, it reads back as after it, because it is the same line. A sheet that STORES its rows (a
## `.tres`) genuinely moves onto the newer spelling; a sheet that derives them from its text (a `.gd`)
## keeps deriving exactly what it derived yesterday. Reading the line back would answer a question
## nobody asked, and answering it wrongly is how an optional argument left empty - `play()` from an
## audio row whose start time was cleared, which the reverse grammar reads as a plain method call -
## refused a rewrite that could not have changed a byte of anybody's project.
static func _proved_line(row: Resource, successor: Dictionary, params: Dictionary, scope: String,
		host: String, before: String) -> String:
	var address: PackedStringArray = EventForgeSuccessors.split_key(str(successor.get("key", "")))
	var candidate: Resource = _copy_onto(row, address, str(successor.get("template", "")), params)
	if candidate == null:
		return ""
	var line: String = EventSheetMigrationFindings.emitted_line(candidate, scope, host)
	if line.is_empty():
		return ""
	for parameter: String in (successor.get("params", PackedStringArray()) as PackedStringArray):
		if line.contains("{%s}" % parameter):
			return ""
	if line == before:
		return line
	var lifted: Resource = EventSheetACELifter.lift_one_line(line, row is ACECondition)
	if lifted == null or not (lifted is ACEAction or lifted is ACECondition):
		return ""
	if str(lifted.get("ace_id")).strip_edges() != address[1]:
		return ""
	# Re-emitted with no scope and no host, because the lift baked whichever of those the line
	# carried straight into the row's own values - which is precisely what opening the file does.
	if EventSheetMigrationFindings.emitted_line(lifted, "", "") != line:
		return ""
	return line


## A copy of this row wearing the successor's identity, template and values, and keeping everything
## about it that is the ROW's rather than the verb's - whether it is on, its note, whether the
## question is inverted, whether the call is awaited.
static func _copy_onto(row: Resource, address: PackedStringArray, template: String,
		params: Dictionary) -> Resource:
	if address.size() < 2 or address[1].strip_edges().is_empty():
		return null
	if row is ACECondition:
		var condition: ACECondition = ACECondition.new()
		condition.provider_id = address[0]
		condition.ace_id = address[1]
		condition.codegen_template = template
		condition.params = params.duplicate(true)
		condition.negated = (row as ACECondition).negated
		condition.negation_wrapped = (row as ACECondition).negation_wrapped
		condition.enabled = (row as ACECondition).enabled
		condition.comment = (row as ACECondition).comment
		return condition
	if row is ACEAction:
		var action: ACEAction = ACEAction.new()
		action.provider_id = address[0]
		action.ace_id = address[1]
		action.codegen_template = template
		action.params = params.duplicate(true)
		action.is_awaited = (row as ACEAction).is_awaited
		action.enabled = (row as ACEAction).enabled
		action.comment = (row as ACEAction).comment
		return action
	return null


## True when this row carries state of its own - a member, a prelude, a line run inside or on the way
## out, or a term the compiler hoists to the end of the chain. Such a row was baked at apply time
## with a uid nobody else has, and rewriting it onto another verb would leave that state declared for
## a row that no longer uses it.
static func _carries_state(row: Resource) -> bool:
	var condition: ACECondition = row as ACECondition
	if condition == null:
		# Only the condition lane carries state today: an action's whole contribution is its line.
		return false
	for field: String in [condition.member_declaration, condition.codegen_prelude,
			condition.codegen_on_true, condition.codegen_on_exit]:
		if not field.strip_edges().is_empty():
			return true
	return condition.evaluate_last


## One function's rows. A function built by the editor holds `events`; one lifted out of a
## hand-written file may hold `rows` instead, and every walk in this plugin reads both.
static func _function_rows(event_function: EventFunction) -> Array:
	return event_function.events if not event_function.events.is_empty() else event_function.rows
