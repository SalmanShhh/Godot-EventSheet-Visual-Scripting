# Godot EventSheets - MIGRATING A ROW ONTO THE SPELLING THE VOCABULARY USES TODAY.
#
# The head band counts the rows that have a newer spelling; this is the door out of that count, and
# the whole of what it promises:
#
#   1. asking costs the file NOTHING. Planning a migration compiles nothing into the sheet, moves no
#      byte of what it writes, and leaves every row exactly as it was found.
#   2. a rewritten row lands COMPLETE - values under their new names, the reading that goes with the
#      new verb, and the line the new verb writes.
#   3. a row that cannot prove its rewrite STAYS. Four different situations, four different
#      sentences, and every one of them leaves the row untouched: the vocabulary has nowhere to send
#      it, the newer verb keeps state of its own, the line does not read back as itself, or the file
#      would not compile with it in place.
#      (`── 3` covers three of those; the fourth is `── 4`, which is the one worth its own heading.)
#   4. Apply is ONE undo step, and Ctrl+Z puts every row back with its id, template, values and
#      reading unharmed.
#   5. the project report says the same thing in the same numbers, sorted, with no timestamps.
#
# THE FIXTURES ARE HALF REAL ON PURPOSE. The old verb is invented - a pack that was here once - but
# every successor is a verb this plugin really ships, because the gate reads the rewritten line back
# through the importer's own reverse grammar and a made-up successor would prove nothing about
# whether a real one round-trips.
@tool
class_name MigrationApplyTest
extends RefCounted

## The pack that used to be here, spelled once so every fixture below asks about the same verbs.
const OLD_PROVIDER := "MigrationProbe"

## Where a compiled probe is written. `user://` so nothing under res:// is touched by a test.
const PROBE_PATH := "user://eventforge_migration_apply_probe.gd"
const FIXTURE_ONE := "user://eventforge_migration_fixture_one.tres"
const FIXTURE_TWO := "user://eventforge_migration_fixture_two.tres"


static func run() -> bool:
	var ok: bool = _test_asking_writes_nothing()
	ok = _test_a_clean_rewrite_lands_complete() and ok
	ok = _test_the_ways_a_row_stays() and ok
	ok = _test_the_round_trip_gate_refuses() and ok
	ok = _test_the_receipt() and ok
	ok = _test_apply_is_one_undo_step() and ok
	ok = _test_the_button_applies_the_plan_it_drew() and ok
	ok = _test_the_project_report() and ok
	ok = _test_the_doors_are_the_only_doors() and ok
	ok = _test_the_shipped_address() and ok
	ok = _test_the_shipped_address_in_the_report() and ok
	ok = _test_the_shipped_address_with_a_cleared_from() and ok
	return ok


# ── the vocabulary these fixtures are written against ─────────────────────────────


## The installed vocabulary plus the invented verbs below. One dictionary handed to every ask, so
## every test here is answered by the same corpus and none of them reflects the packs twice.
static func _known() -> Dictionary:
	var known: Dictionary = EventForgeSuccessors.catalog().duplicate()
	# Clears a control's bindings, superseded by the shipped verb that spells the control as a
	# StringName. Every value travels, and both spellings are GDScript, so this one migrates.
	known["%s::ClearBinding" % OLD_PROVIDER] = _entry("ClearBinding", "Clear binding",
		"InputMap.action_erase_events({control})", "Clear the bindings for {control}",
		PackedStringArray(["control"]), {"control": "\"ui_accept\""},
		{"id": "Core::ActionEraseEvents", "renames": {"control": "action"}, "defaults": {}})
	# The same address, met by a row whose value is a CALL. It was fine where it was; it is not fine
	# in a slot the newer verb spells as a name, and the file is what says so.
	known["%s::ClearComputedBinding" % OLD_PROVIDER] = _entry("ClearComputedBinding",
		"Clear computed binding", "InputMap.action_erase_events({control})",
		"Clear the bindings for {control}", PackedStringArray(["control"]),
		{"control": "\"ui_accept\""},
		{"id": "Core::ActionEraseEvents", "renames": {"control": "action"}, "defaults": {}})
	# PolishTheLamp is deliberately NOT here: a verb the vocabulary no longer has at all is the one
	# state nothing can carry a forwarding address for, because the address would have been on the
	# entry that is missing.
	# And one whose successor keeps state of its own, so it has to be picked rather than rewritten.
	known["%s::EverySoOften" % OLD_PROVIDER] = _entry("EverySoOften", "Every so often",
		"every_so_often({seconds})", "Every {seconds} seconds", PackedStringArray(["seconds"]),
		{"seconds": "1.0"},
		{"id": "%s::StatefulTimer" % OLD_PROVIDER, "renames": {}, "defaults": {}})
	var stateful: Dictionary = _entry("StatefulTimer", "Stateful timer",
		"__tick_{uid}.ready({seconds})", "Every {seconds} seconds", PackedStringArray(["seconds"]),
		{"seconds": "1.0"}, {})
	stateful["needs_baking"] = true
	known["%s::StatefulTimer" % OLD_PROVIDER] = stateful
	# Tells a group to do something, superseded by the shipped verb that takes an argument with it -
	# and the map forgets to say where the argument goes. The successor already declares that value
	# as its own, so nothing is written for it, and the shorter line the emitter then writes is one
	# the vocabulary reads back as a DIFFERENT verb. A map that leaves a parameter unanswered is the
	# authoring mistake this gate exists to catch, and the row stays exactly where it was.
	known["%s::TellEveryone" % OLD_PROVIDER] = _entry("TellEveryone", "Tell everyone",
		"get_tree().call_group({who}, {what}, {payload})", "Tell {who} to {what} with {payload}",
		PackedStringArray(["who", "what", "payload"]),
		{"who": "\"enemies\"", "what": "\"take_damage\"", "payload": "10"},
		{"id": "Core::CallGroupWith",
			"renames": {"who": "group", "what": "method"}, "defaults": {}})
	return known


## One invented vocabulary entry, in the shape the forwarding-address catalogue keeps them.
static func _entry(ace_id: String, name: String, template: String, reading: String,
		params: PackedStringArray, defaults: Dictionary, map: Dictionary) -> Dictionary:
	var answered: PackedStringArray = PackedStringArray()
	for parameter: String in params:
		if not str(defaults.get(parameter, "")).strip_edges().is_empty():
			answered.append(parameter)
	return {
		"key": EventForgeSuccessors.key_of(OLD_PROVIDER, ace_id), "name": name,
		"template": template, "display_template": reading, "needs_baking": false,
		"ace_type": ACEDefinition.ACEType.ACTION, "params": params,
		"declared_defaults": defaults, "answered_by_default": answered, "map": map,
	}


## One action row on an invented verb, with its template and its reading baked on exactly as the dock
## bakes them at apply time.
static func _row(ace_id: String, params: Dictionary) -> ACEAction:
	var known: Dictionary = _known()
	var key: String = "%s::%s" % [OLD_PROVIDER, ace_id]
	# The verb that is GONE has no entry to read its template off, which is the whole point of it -
	# the row goes on compiling because the template was baked onto it when it was applied.
	var entry: Dictionary = known[key] if known.has(key) else {
		"template": "polish($Lamp)", "display_template": "Polish the lamp"}
	var action: ACEAction = ACEAction.new()
	action.provider_id = OLD_PROVIDER
	action.ace_id = ace_id
	action.codegen_template = str(entry["template"])
	action.display_text = str(entry["display_template"])
	action.params = params
	return action


## One row written in the spelling the vocabulary uses today - a verb-carrying row the report has
## nothing to say about, which is nearly every row of nearly every sheet. It is the row that has to
## be COUNTED and not LISTED for the report's ordinal to mean what it says.
static func _current_row() -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "ActionEraseEvents"
	action.codegen_template = "InputMap.action_erase_events(&{action})"
	action.display_text = "Clear bindings for {action}"
	action.params = {"action": "\"pause\""}
	return action


## A one-event sheet holding the given rows, in order.
static func _sheet(rows: Array) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "MigrationApplyFixture"
	sheet.host_class = "Node"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	for row: Variant in rows:
		event.actions.append(row as Resource)
	sheet.events.append(event)
	return sheet


static func _compiled(sheet: EventSheetResource) -> String:
	return str(SheetCompiler.compile(sheet, PROBE_PATH).get("output", ""))


# ── 1. asking costs the file nothing ──────────────────────────────────────────────


## THE SPINE OF THE PASS. Planning a migration is a question: it compiles trial answers on a COPY,
## and the sheet it was asked about writes the same bytes afterwards with every row still naming the
## verb it named.
static func _test_asking_writes_nothing() -> bool:
	var sheet: EventSheetResource = _sheet([
		_row("ClearBinding", {"control": "\"jump\""}),
		_row("PolishTheLamp", {}),
	])
	var before: String = _compiled(sheet)
	var planned: Array[Dictionary] = EventSheetMigrationPlan.plan(sheet, _known())
	var ok: bool = _check("the sheet writes the same bytes after being asked", _compiled(sheet), before)
	var first: ACEAction = (sheet.events[0] as EventRow).actions[0] as ACEAction
	ok = _check("and the row still names the verb it was written on", first.ace_id, "ClearBinding") and ok
	ok = _check("with its values untouched", first.params, {"control": "\"jump\""}) and ok
	ok = _check("two rows had something to say about themselves", planned.size(), 2) and ok
	return ok


# ── 2. a clean rewrite ────────────────────────────────────────────────────────────


## The whole of one migration, as VALUES: where it goes, what it writes, what it reads, and what it
## carries. Every one of these is a line somebody will read in a diff.
static func _test_a_clean_rewrite_lands_complete() -> bool:
	var sheet: EventSheetResource = _sheet([_row("ClearBinding", {"control": "\"jump\""})])
	var planned: Array[Dictionary] = EventSheetMigrationPlan.plan(sheet, _known())
	var ok: bool = _check("one row is planned", planned.size(), 1)
	if not ok:
		return false
	var entry: Dictionary = planned[0]
	ok = _check("it does not ask anybody anything", entry["asks"], false) and ok
	ok = _check("it is the first verb-carrying row of the sheet", entry["ordinal"], 1) and ok
	ok = _check("it comes from the verb the row names", entry["from"],
		"%s::ClearBinding" % OLD_PROVIDER) and ok
	ok = _check("and goes to the spelling that stands there now", entry["to"],
		"Core::ActionEraseEvents") and ok
	ok = _check("the line it writes today", entry["before"],
		"InputMap.action_erase_events(\"jump\")") and ok
	ok = _check("and the line it would write", entry["after"],
		"InputMap.action_erase_events(&\"jump\")") and ok
	ok = _check("the sentence it reads today", entry["reading_before"],
		"Clear the bindings for \"jump\"") and ok
	ok = _check("and the sentence it would read", entry["reading_after"],
		"Clear bindings for \"jump\"") and ok
	ok = _check("the value arrives under its new name", entry["params_after"],
		{"action": "\"jump\""}) and ok
	return ok


# ── 3. the ways a row stays exactly as it is ──────────────────────────────────────


## Three rows, three reasons, and not one of them moves. The reasons are separate because the next
## step is different for each: pick something else, pick this one properly, or look at the line.
##
## THE FILE'S REFUSAL GETS A SHEET OF ITS OWN, because it is the only one of the three that asks the
## compiler: a sheet already holding a line no compiler would take (the two invented verbs above are
## calls to functions nothing declares) has a problem migration did not cause, and the gate stands
## down rather than blaming a rewrite for it.
static func _test_the_ways_a_row_stays() -> bool:
	var sheet: EventSheetResource = _sheet([
		_row("PolishTheLamp", {}),
		_row("EverySoOften", {"seconds": "2.0"}),
	])
	var planned: Array[Dictionary] = EventSheetMigrationPlan.plan(sheet, _known())
	var ok: bool = _check("both are listed", planned.size(), 2)
	if not ok:
		return false
	ok = _check("both of them ask you",
		[bool(planned[0]["asks"]), bool(planned[1]["asks"])], [true, true]) and ok
	ok = _check("the verb with nowhere to go says so", planned[0]["why"],
		EventSheetMigrationPlan.WHY_NO_SUCCESSOR) and ok
	ok = _check("and the one whose successor keeps state says it has to be picked",
		planned[1]["why"], EventSheetMigrationPlan.WHY_NEEDS_PICKING) and ok
	# `after` is empty EXACTLY when a row asks - a row nothing can rewrite has no line to show for a
	# rewrite that will not happen. The public report's shape leans on this.
	ok = _check("and neither offers a line it will not write",
		[str(planned[0]["after"]), str(planned[1]["after"])], ["", ""]) and ok
	ok = _check("applying the plan moves nothing", EventSheetMigrationPlan.apply(planned), 0) and ok

	# The third reason, on a sheet the compiler is happy with until the rewrite goes in. The value was
	# perfectly good where it stood; the newer verb spells that slot as a name, and `&` in front of a
	# call is not GDScript. Nothing but the file could have said so.
	var refused: EventSheetResource = _sheet([_row("ClearComputedBinding",
		{"control": "get_class()"})])
	var about: Array[Dictionary] = EventSheetMigrationPlan.plan(refused, _known())
	ok = _check("the row whose rewrite the file will not take is listed", about.size(), 1) and ok
	if about.is_empty():
		return false
	ok = _check("and says exactly that", about[0]["why"],
		EventSheetMigrationPlan.WHY_FILE_REFUSES) and ok
	ok = _check("offering no line it will not write", about[0]["after"], "") and ok
	ok = _check("applying it moves nothing", EventSheetMigrationPlan.apply(about), 0) and ok
	ok = _check("and the row still names its own verb",
		str(((refused.events[0] as EventRow).actions[0] as ACEAction).ace_id),
		"ClearComputedBinding") and ok
	return ok


# ── 4. the round-trip gate says no ────────────────────────────────────────────────


## THE GATE THAT MATTERS MOST, met by a rewrite that looks perfectly good on paper. Every named value
## travels and the line the successor writes compiles - but the map leaves one of the successor's
## parameters unanswered, so the emitter writes a SHORTER line than the row wrote before, and the
## vocabulary reads that shorter line back as a DIFFERENT verb. A row migrated onto it would come
## back as something else the next time somebody opened the file. That is the lossless round-trip law
## asked one row at a time, and the row stays exactly where it was.
##
## The line has to CHANGE for any of that to be a question. A rewrite that writes the byte already in
## the file is proved without reading anything back - there is no new line to read - and the cleared
## `From` below is the shipped case of it.
static func _test_the_round_trip_gate_refuses() -> bool:
	var sheet: EventSheetResource = _sheet([_row("TellEveryone", {
		"who": "\"enemies\"", "what": "\"take_damage\"", "payload": "10"})])
	var planned: Array[Dictionary] = EventSheetMigrationPlan.plan(sheet, _known())
	var ok: bool = _check("the row is listed", planned.size(), 1)
	if not ok:
		return false
	ok = _check("it asks you", planned[0]["asks"], true) and ok
	ok = _check("because the rewritten line does not read back as itself", planned[0]["why"],
		EventSheetMigrationPlan.WHY_UNPROVABLE) and ok
	ok = _check("it offers no line it will not write", planned[0]["after"], "") and ok
	ok = _check("and applying the plan leaves it alone",
		EventSheetMigrationPlan.apply(planned), 0) and ok
	ok = _check("still naming its own verb",
		str(((sheet.events[0] as EventRow).actions[0] as ACEAction).ace_id), "TellEveryone") and ok
	return ok


# ── 5. the receipt ────────────────────────────────────────────────────────────────


## What the dialog draws, pinned as the strings it draws. Two lines per rewritten row - the sentence
## and then the code - because a migration that showed only one of them would hide the half somebody
## reads.
static func _test_the_receipt() -> bool:
	var planned: Array[Dictionary] = EventSheetMigrationPlan.plan(_sheet([
		_row("ClearBinding", {"control": "\"jump\""}),
		_row("PolishTheLamp", {}),
	]), _known())
	var ok: bool = _check("the rewrite list says the sentence, then the code",
		EventSheetMigrateDialog.preview_lines(planned), PackedStringArray([
			"Clear the bindings for \"jump\" → Clear bindings for \"jump\"",
			"    InputMap.action_erase_events(\"jump\") → InputMap.action_erase_events(&\"jump\")",
		]))
	ok = _check("the other list names the row and the reason",
		EventSheetMigrateDialog.left_alone_lines(planned), PackedStringArray([
			"Polish the lamp - the vocabulary has no newer spelling for this one, so it stays exactly as written",
		])) and ok
	ok = _check("and the summary counts both halves",
		EventSheetMigrateDialog.summary_text(planned),
		"1 row(s) would be rewritten in one step you can undo, and 1 are left exactly as they are.") and ok
	return ok


# ── 6. one undo step ──────────────────────────────────────────────────────────────


## Two rows migrate together, and ONE Ctrl+Z puts both back - id, template, values and reading.
static func _test_apply_is_one_undo_step() -> bool:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	var sheet: EventSheetResource = _sheet([
		_row("ClearBinding", {"control": "\"jump\""}),
		_row("ClearBinding", {"control": "\"fire\""}),
	])
	sheet.external_source_path = PROBE_PATH
	dock.setup(sheet)
	dock._migrate_dialog.open(_known())
	dock._migrate_dialog.confirm()
	var moved: Array = (dock.get_current_sheet().events[0] as EventRow).actions
	var ok: bool = _check("both rows now name the spelling that stands there today",
		[str((moved[0] as ACEAction).ace_id), str((moved[1] as ACEAction).ace_id)],
		["ActionEraseEvents", "ActionEraseEvents"])
	ok = _check("under the provider that publishes it",
		str((moved[0] as ACEAction).provider_id), "Core") and ok
	ok = _check("carrying the successor's template",
		str((moved[0] as ACEAction).codegen_template),
		"InputMap.action_erase_events(&{action})") and ok
	ok = _check("and its reading, so the row goes on saying something if that pack ever goes too",
		str((moved[0] as ACEAction).display_text), "Clear bindings for {action}") and ok
	ok = _check("the file now carries the newer line",
		_compiled(dock.get_current_sheet()).contains("InputMap.action_erase_events(&\"fire\")"),
		true) and ok

	dock._undo_redo_adapter.undo()
	var back: Array = (dock.get_current_sheet().events[0] as EventRow).actions
	ok = _check("and ONE Ctrl+Z puts both of them back",
		[str((back[0] as ACEAction).ace_id), str((back[1] as ACEAction).ace_id)],
		["ClearBinding", "ClearBinding"]) and ok
	ok = _check("with their values unharmed",
		[(back[0] as ACEAction).params, (back[1] as ACEAction).params],
		[{"control": "\"jump\""}, {"control": "\"fire\""}]) and ok
	ok = _check("and their readings unharmed",
		str((back[0] as ACEAction).display_text), "Clear the bindings for {control}") and ok
	dock.free()
	return ok


## WHAT LANDS IS WHAT WAS READ. The plan has to be rebuilt inside the funnel - no row reference may
## cross a commit - but rebuilding is not the same as re-approving. A row added, pasted or edited
## while the receipt was open makes the fresh plan a different plan, and applying it would rewrite a
## row that never appeared in "What will be rewritten" while the status line reported the larger
## count. The button compares the two receipts and, when they differ, writes NOTHING and draws the
## window again.
static func _test_the_button_applies_the_plan_it_drew() -> bool:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	var sheet: EventSheetResource = _sheet([_row("ClearBinding", {"control": "\"jump\""})])
	sheet.external_source_path = PROBE_PATH
	dock.setup(sheet)
	dock._migrate_dialog.open(_known())
	var drawn: PackedStringArray = EventSheetMigrationPlan.receipt_of(
		EventSheetMigrationPlan.plan(dock.get_current_sheet(), _known()))
	var ok: bool = _check("the receipt drawn is one line for the one row", drawn.size(), 1)
	# A second row arrives while the window is open - the exact thing a paste does.
	var event_row: EventRow = dock.get_current_sheet().events[0] as EventRow
	event_row.actions.append(_row("ClearBinding", {"control": "\"fire\""}))
	dock._migrate_dialog.confirm()
	var rows: Array = (dock.get_current_sheet().events[0] as EventRow).actions
	ok = _check("nothing was rewritten - the sheet is not the sheet that was read",
		[str((rows[0] as ACEAction).ace_id), str((rows[1] as ACEAction).ace_id)],
		["ClearBinding", "ClearBinding"]) and ok
	ok = _check("and the reader is told why they are reading it again",
		str(dock._status_label.text).replace("⚠  ", ""),
		"This sheet changed while the receipt was open, so nothing was rewritten - here is what it says now.") and ok
	# Read again, and the same button now applies exactly what the second reading showed.
	dock._migrate_dialog.confirm()
	var moved: Array = (dock.get_current_sheet().events[0] as EventRow).actions
	ok = _check("reading it again is what makes the button work",
		[str((moved[0] as ACEAction).ace_id), str((moved[1] as ACEAction).ace_id)],
		["ActionEraseEvents", "ActionEraseEvents"]) and ok
	# And the receipt itself is a reading, not a set of live rows: two plans of one sheet agree.
	ok = _check("two readings of one sheet are the same receipt",
		EventSheetMigrationPlan.receipt_of(EventSheetMigrationPlan.plan(
			dock.get_current_sheet(), _known())),
		EventSheetMigrationPlan.receipt_of(EventSheetMigrationPlan.plan(
			dock.get_current_sheet(), _known()))) and ok
	dock.free()
	return ok


# ── 7. the project report ─────────────────────────────────────────────────────────


## The public seam, over a fixture project of two sheets: one row per thing to say, sorted by file and
## then by row, with `after` filled exactly when `asks` is false.
static func _test_the_project_report() -> bool:
	var one: EventSheetResource = _sheet([
		_row("ClearBinding", {"control": "\"jump\""}),
		_row("PolishTheLamp", {}),
	])
	var two: EventSheetResource = _sheet([_row("ClearBinding", {"control": "\"fire\""})])
	ResourceSaver.save(one, FIXTURE_ONE)
	ResourceSaver.save(two, FIXTURE_TWO)
	# Deliberately the wrong way round, so the sort is proved rather than inherited from the caller.
	var listed: Array[Dictionary] = EventSheetMigrationDoctor.rows(
		PackedStringArray([FIXTURE_TWO, FIXTURE_ONE]), _known())
	var ok: bool = _check("every row of both sheets is reported", listed.size(), 3)
	if not ok:
		return false
	ok = _check("sorted by file, then by row",
		[str(listed[0]["sheet"]), int(listed[0]["row"]), str(listed[1]["sheet"]),
			int(listed[1]["row"]), str(listed[2]["sheet"]), int(listed[2]["row"])],
		[FIXTURE_ONE, 1, FIXTURE_ONE, 2, FIXTURE_TWO, 1]) and ok
	ok = _check("the shape of one row is the seven things it promises", listed[0], {
		"sheet": FIXTURE_ONE, "row": 1, "from_id": "%s::ClearBinding" % OLD_PROVIDER,
		"to_id": "Core::ActionEraseEvents",
		"before": "InputMap.action_erase_events(\"jump\")",
		"after": "InputMap.action_erase_events(&\"jump\")", "asks": false,
	}) and ok
	ok = _check("and a row with nowhere to go names no successor and offers no line", listed[1], {
		"sheet": FIXTURE_ONE, "row": 2, "from_id": "%s::PolishTheLamp" % OLD_PROVIDER,
		"to_id": "", "before": "polish($Lamp)", "after": "", "asks": true,
	}) and ok
	ok = _check("the Doctor's per-sheet lines say the same numbers",
		_messages(EventSheetMigrationDoctor.sheet_lines(listed)), PackedStringArray([
			"%s - 1 row(s) migrate cleanly, 1 ask you." % FIXTURE_ONE.get_file(),
			"%s - 1 row(s) migrate cleanly, 0 ask you." % FIXTURE_TWO.get_file(),
		])) and ok
	# Deterministic: the same corpus asked twice answers the same, with nothing remembered between.
	ok = _check("and asking twice answers the same",
		EventSheetMigrationDoctor.rows(PackedStringArray([FIXTURE_ONE, FIXTURE_TWO]), _known()),
		listed) and ok
	# THE `row` KEY IS THE ROW'S PLACE AMONG VERB-CARRYING ROWS, which is what the API doc, the
	# guide's table and the gate's own "Event %d writes ..." all say it is - an address a person can
	# count to in the sheet in front of them. Counted among PLANNED rows instead, it named a
	# different row on any sheet where some rows are current and some are not, which is every sheet
	# the report has anything to say about. Pinned on a sheet whose SECOND row is already current.
	var mixed: EventSheetResource = _sheet([
		_row("ClearBinding", {"control": "\"jump\""}),
		_current_row(),
		_row("PolishTheLamp", {}),
	])
	ResourceSaver.save(mixed, FIXTURE_ONE)
	var counted: Array[Dictionary] = EventSheetMigrationDoctor.rows(
		PackedStringArray([FIXTURE_ONE]), _known())
	ok = _check("a row on the current spelling is not in the report at all", counted.size(), 2) and ok
	if counted.size() == 2:
		ok = _check("but it is still counted, so the two rows are events 1 and 3",
			[int(counted[0]["row"]), int(counted[1]["row"])], [1, 3]) and ok
	DirAccess.remove_absolute(FIXTURE_ONE)
	DirAccess.remove_absolute(FIXTURE_TWO)
	return ok


static func _messages(findings: Array[Dictionary]) -> PackedStringArray:
	var said: PackedStringArray = PackedStringArray()
	for finding: Dictionary in findings:
		said.append(str(finding.get("message", "")))
	return said


# ── 8. the doors, and the ones that are not doors ─────────────────────────────────


## The band's word opens the receipt, the inbox's chip opens the receipt, and NOTHING applies from
## the report. The last of those is the one worth a test: a chip that rewrote files from a list
## nobody was looking at is the fatal version of this feature.
static func _test_the_doors_are_the_only_doors() -> bool:
	var ok: bool = _check("the counting line carries one word, and it opens a receipt",
		EventSheetHeadBands.control_label(EventSheetHeadBands.BAND_MIGRATION), "Migrate…")
	var offered: Array[Dictionary] = EventSheetQuickFixes.fixes_for(
		{"check": EventSheetMigrationDoctor.CHECK_SHEET, "subject": "res://player.gd",
			"path": "res://player.gd"})
	ok = _check("the per-sheet line offers exactly one chip", offered.size(), 1) and ok
	if not offered.is_empty():
		ok = _check("and it is a way in, not a rewrite", str(offered[0]["label"]),
			"Apply per sheet…") and ok
	# With no dock to reach, the chip says where the gesture lives and changes nothing.
	var answered: Dictionary = EventSheetQuickFixes.apply("apply_migrations",
		{"check": EventSheetMigrationDoctor.CHECK_SHEET, "path": "res://player.gd"}, {})
	ok = _check("and with nothing open it writes nothing", answered["ok"], false) and ok
	# The gone-verb finding keeps its own two doors: this pass adds a third surface, not a third door.
	ok = _check("the row's own doors are untouched",
		[EventSheetMigrationFindings.FIX_SEE_REPLACEMENT,
			EventSheetMigrationFindings.FIX_KEEP_AS_CODE],
		["see_what_replaced_it", "keep_it_as_code"]) and ok
	return ok


# ── 10. the shipped address, with nothing invented ────────────────────────────────


## EVERY OTHER TEST HERE INVENTS THE OLD VERB. This one invents nothing: the sheet is written on
## `Core::PlayAudio` and `Core::StopAudio`, the two general-shelf audio rows the Audio shelf
## superseded a day after they landed, and the vocabulary answering is the one the project ships.
##
## Three things are proved of it in the order a reader meets them: the head band counts the rows, the
## receipt says what would change in words and in code, and Apply lands the successor row as ONE
## undoable edit. A synthetic corpus can prove the machinery; only this can prove that the addresses
## the plugin publishes actually carry a real sheet across.
static func _test_the_shipped_address() -> bool:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	var sheet: EventSheetResource = _audio_sheet()
	sheet.external_source_path = PROBE_PATH
	dock.setup(sheet)
	# THE HEAD BAND, counted over the rows themselves rather than remembered anywhere.
	var counted: int = dock._viewport._row_builder._rows_with_a_newer_spelling(dock.get_current_sheet())
	var ok: bool = _check("the head band counts the one event holding both older spellings",
		counted, 1)
	ok = _check("and says so in one line",
		EventForgeVocabularyRecord.band_reading(EventForgeVocabularyRecord.band_facts(counted, 0)),
		"1 row has a newer spelling") and ok
	# THE RECEIPT, against the shipped vocabulary with nothing handed in.
	var planned: Array[Dictionary] = EventSheetMigrationPlan.plan(dock.get_current_sheet())
	ok = _check("the receipt lists both rows, the sentence then the code",
		EventSheetMigrateDialog.preview_lines(planned), PackedStringArray([
			"Play sound → Play from 0.5s",
			"    play(0.5) → play(0.5)",
			"Stop sound → Stop",
			"    stop() → stop()",
		])) and ok
	ok = _check("and leaves nothing behind for a person to answer",
		EventSheetMigrateDialog.left_alone_lines(planned), PackedStringArray()) and ok
	ok = _check("the summary counts one step",
		EventSheetMigrateDialog.summary_text(planned),
		"2 row(s) would be rewritten, in one step you can undo.") and ok
	# THE EDIT.
	dock._migrate_dialog.open()
	dock._migrate_dialog.confirm()
	var moved: Array = (dock.get_current_sheet().events[0] as EventRow).actions
	ok = _check("both rows now name the Audio shelf's own spelling",
		[str((moved[0] as ACEAction).ace_id), str((moved[1] as ACEAction).ace_id)],
		["AudioPlay", "AudioStop"]) and ok
	ok = _check("the renamed value arrived under the name the successor calls it",
		(moved[0] as ACEAction).params, {"from": "0.5", "target": ""}) and ok
	ok = _check("carrying the successor's template",
		str((moved[0] as ACEAction).codegen_template), "{target.}play({from})") and ok
	ok = _check("and its reading", str((moved[0] as ACEAction).display_text),
		"Play from {from}s") and ok
	ok = _check("the file writes the same line it always did",
		_compiled(dock.get_current_sheet()).contains("play(0.5)"), true) and ok
	ok = _check("and the band has nothing left to count",
		dock._viewport._row_builder._rows_with_a_newer_spelling(dock.get_current_sheet()), 0) and ok
	# ONE Ctrl+Z.
	dock._undo_redo_adapter.undo()
	var back: Array = (dock.get_current_sheet().events[0] as EventRow).actions
	ok = _check("and ONE Ctrl+Z puts both of them back",
		[str((back[0] as ACEAction).ace_id), str((back[1] as ACEAction).ace_id)],
		["PlayAudio", "StopAudio"]) and ok
	ok = _check("with their values unharmed", (back[0] as ACEAction).params,
		{"from_position": "0.5", "target": ""}) and ok
	dock.free()
	return ok


## THE DOCTOR'S MIGRATION SECTION, over a STORED sheet holding the same two rows.
##
## Stored on purpose, and the asymmetry is the whole point of this pair. A `.tres` sheet writes down
## which verb each row was picked from, so an older spelling in one is a fact the report can read. A
## `.gd` sheet derives its rows from the file every time it is opened - and these two spellings emit
## the SAME line, `play(0.5)`, so the reverse grammar reads that line back as the current verb and
## there is nothing to report. That is the good half of an address whose two ends write the same
## bytes: a project full of `.gd` sheets gains no migration rows at all from it, so no branch gate
## starts failing and no diff appears anywhere, while the sheet in front of a reader still offers the
## newer spelling on the head band.
static func _test_the_shipped_address_in_the_report() -> bool:
	var path: String = "user://eventforge_migration_shipped_probe.tres"
	if ResourceSaver.save(_audio_sheet(), path) != OK:
		return _check("the probe sheet is stored", false, true)
	var rows: Array[Dictionary] = EventSheetMigrationDoctor.rows(PackedStringArray([path]))
	var said: PackedStringArray = PackedStringArray()
	for row: Dictionary in rows:
		said.append("%d %s -> %s %s" % [int(row.get("row", 0)), str(row.get("from_id", "")),
			str(row.get("to_id", "")), "asks" if bool(row.get("asks", true)) else "moves"])
	var ok: bool = _check("the report names both rows, where they go, and that neither asks", said,
		PackedStringArray([
			"1 Core::PlayAudio -> Core::AudioPlay moves",
			"2 Core::StopAudio -> Core::AudioStop moves",
		]))
	ok = _check("and the per-sheet line counts them the same way",
		EventSheetMigrationDoctor.sheet_lines(rows).size(), 1) and ok
	DirAccess.remove_absolute(path)
	return ok


## THE SAME SHIPPED ADDRESS, MET BY THE ONE VALUE THAT IS NOT A VALUE: a cleared *From*.
##
## *From* is optional, and a row whose start time has been emptied is a row somebody really has -
## `play()` is the idiomatic call and the field starts life offering a default nobody has to keep.
## Both spellings then emit `$Sfx.play()`, and the reverse grammar reads THAT line as a plain method
## call rather than as either of them, because `play({from})` reverse-matches a call with an argument
## in it. So the round-trip gate, asked whether the rewritten line reads back as the successor, said
## no - and a stored `.tres` holding this row failed `tools/verify_sheets.gd` on a sheet nobody had
## touched, while the head band went on counting it and offering a rewrite Migrate could not make.
##
## A rewrite that writes the byte that is already there changes no file, so there is no new line for
## anybody to read back and nothing for a branch gate to find. Pinned as the plan, the receipt and
## the gate's own failure list, because those are the three surfaces that disagreed.
static func _test_the_shipped_address_with_a_cleared_from() -> bool:
	var sheet: EventSheetResource = _audio_sheet()
	var play: ACEAction = (sheet.events[0] as EventRow).actions[0] as ACEAction
	play.params = {"from_position": "", "target": "$Sfx"}
	var planned: Array[Dictionary] = EventSheetMigrationPlan.plan(sheet)
	var ok: bool = _check("both rows are still listed", planned.size(), 2)
	if not ok:
		return false
	ok = _check("the cleared row asks nobody anything", planned[0]["asks"], false) and ok
	ok = _check("for no reason, because there is none left", str(planned[0]["why"]), "") and ok
	ok = _check("and the line it would write is the line already there",
		[str(planned[0]["before"]), str(planned[0]["after"])],
		["$Sfx.play()", "$Sfx.play()"]) and ok
	ok = _check("the receipt shows it as a rewrite with nothing to answer",
		EventSheetMigrateDialog.left_alone_lines(planned), PackedStringArray()) and ok
	# THE BRANCH GATE, over the stored sheet - the surface that was failing.
	var path: String = "user://eventforge_migration_cleared_probe.tres"
	if ResourceSaver.save(sheet, path) != OK:
		return _check("the probe sheet is stored", false, true)
	var failures: Array[Dictionary] = EventSheetVerify.migration_failures(
		EventSheetMigrationDoctor.rows(PackedStringArray([path])))
	ok = _check("and the branch gate has nothing to say about the stored sheet",
		failures.size(), 0) and ok
	DirAccess.remove_absolute(path)
	return ok


## The sheet the three tests above are about: one event on an AudioStreamPlayer holding the two
## general-shelf audio rows, each with the values a picked row really carries - the older Play Sound
## started half a second in, and a Stop Sound acting on the node the sheet is written on.
static func _audio_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "MigrationShippedFixture"
	sheet.host_class = "AudioStreamPlayer"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var play: ACEAction = ACEAction.new()
	play.provider_id = "Core"
	play.ace_id = "PlayAudio"
	play.codegen_template = "{target.}play({from_position})"
	play.display_text = "Play sound"
	play.params = {"from_position": "0.5", "target": ""}
	event.actions.append(play)
	var stop: ACEAction = ACEAction.new()
	stop.provider_id = "Core"
	stop.ace_id = "StopAudio"
	stop.codegen_template = "{target.}stop()"
	stop.display_text = "Stop sound"
	stop.params = {"target": ""}
	event.actions.append(stop)
	sheet.events.append(event)
	return sheet


static func _check(label: String, got: Variant, expected: Variant) -> bool:
	if got == expected:
		print("[PASS] migration_apply_test: %s" % label)
		return true
	print("[FAIL] migration_apply_test: %s (expected %s, got %s)" % [label, expected, got])
	return false
