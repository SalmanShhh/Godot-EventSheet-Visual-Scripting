# Godot EventSheets - the row whose verb the vocabulary no longer has, and the honest exit for it.
#
# THE SPINE LAW IS PINNED FIRST, because everything else is only allowed to exist if it holds:
# opening a sheet full of verbs nobody answers to any more and saving it untouched reproduces the
# file byte for byte. Deriving the findings, reading the rows and counting the head band are all
# QUESTIONS, and no question here writes anything.
#
# Then the state itself: the row keeps its last stored reading (so a missing descriptor can never
# blank the one lane a beginner reads first), earns the quiet amber, and offers two doors. And then
# the second of those doors: the row kept as the honest verbatim block, the comment offered above it,
# the whole thing one undo step, and Ctrl+Z putting the picked row back.
@tool
class_name MigrationGoneVerbTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
## The verb the vocabulary has lost, spelled once so every test below asks about the same row.
const GONE_PROVIDER := "LightFlicker"
const GONE_ACE := "FlickerLight"
const GONE_TEMPLATE := "flicker({light}, {amount})"
const GONE_READING := "Flicker {light} by {amount}"
const GONE_SENTENCE := "Flicker $Lamp by 0.4"
const GONE_LINE := "flicker($Lamp, 0.4)"

## Where a compiled probe is written. `user://` so nothing under res:// is touched by a test.
const PROBE_PATH := "user://eventforge_migration_probe.gd"


static func run() -> bool:
	var ok: bool = _test_the_sheet_is_never_written_to()
	ok = _test_the_row_keeps_its_reading() and ok
	ok = _test_the_quiet_state_and_its_two_doors() and ok
	ok = _test_the_head_band_counts_both_halves() and ok
	ok = _test_what_is_not_a_finding() and ok
	ok = _test_keeping_it_as_code() and ok
	ok = _test_the_doctor_files_the_same_words() and ok
	ok = _test_the_two_corpus_modes() and ok
	return ok


# ── 1. the spine law ──────────────────────────────────────────────────────────────


## A sheet holding a verb nobody has any more compiles to exactly what it compiled to before, and
## goes on doing so after every question in this file has been asked of it. The row is not touched,
## the params are not rewritten, and the emitted file does not move a byte.
static func _test_the_sheet_is_never_written_to() -> bool:
	var sheet: EventSheetResource = _sheet_with_a_gone_verb()
	var before: String = _compiled(sheet)
	var ok: bool = _check("the row still compiles, because its template was baked onto it",
		before.contains(GONE_LINE), true)
	# Every question this pass asks of such a sheet, asked here in a row.
	var found: Array[Dictionary] = EventSheetMigrationFindings.findings(sheet, "res://probe.gd",
		_known_vocabulary())
	var _reading: String = EventSheetMigrationFindings.reading_text(GONE_READING,
		{"light": "$Lamp", "amount": "0.4"})
	var _band: String = EventForgeVocabularyRecord.band_reading(
		EventForgeVocabularyRecord.band_facts(0, EventSheetMigrationFindings.events_asking(found)))
	ok = _check("and asking every question about it changes nothing at all",
		_compiled(sheet), before) and ok
	var action: Resource = (sheet.events[0] as EventRow).actions[0] as Resource
	ok = _check("the row keeps its own id, template and values",
		[str(action.get("ace_id")), str(action.get("codegen_template")),
			str((action.get("params") as Dictionary).get("light", ""))],
		[GONE_ACE, GONE_TEMPLATE, "$Lamp"]) and ok

	# And the round trip the whole plugin stands on: the emitted file, opened as a sheet and emitted
	# again, is the same bytes. A lost verb degrades to a verbatim block, which is exactly the shape
	# that reproduces itself.
	var wrote: Error = _write(PROBE_PATH, before)
	ok = _check("the probe is written", wrote, OK) and ok
	var reopened: EventSheetResource = GDScriptImporter.new().import_external(PROBE_PATH)
	ok = _check("the file opens as a sheet", reopened != null, true) and ok
	if reopened != null:
		ok = _check("and saving it untouched reproduces it byte for byte",
			_compiled(reopened), before) and ok
	return ok


# ── 2. the last stored reading ────────────────────────────────────────────────────


## The reading rides with the row precisely so a missing descriptor cannot blank it. Slots and all,
## filled from the row's own values, so the sentence still follows the row when a value is edited.
static func _test_the_row_keeps_its_reading() -> bool:
	var ok: bool = _check("the stored reading is filled from the row's own values",
		EventSheetMigrationFindings.reading_text(GONE_READING,
			{"light": "$Lamp", "amount": "0.4"}), GONE_SENTENCE)
	ok = _check("a slot the row never answered is emptied, not printed at the reader",
		EventSheetMigrationFindings.reading_text("Set {property} to {value}", {"value": "5"}),
		"Set to 5") and ok
	ok = _check("a row with no stored reading says nothing, and the old fallbacks answer",
		EventSheetMigrationFindings.reading_text("", {"a": "1"}), "") and ok
	# What the dock bakes onto a row when it is applied: the display TEMPLATE, never a finished
	# sentence - a sentence would stop following the row the first time a value changed.
	var definition := ACEDefinition.new()
	definition.display_name = "Flicker Light"
	definition.metadata = {"display_template": GONE_READING}
	ok = _check("apply bakes the template, not the sentence",
		EventSheetACEApply.baked_reading_for(definition), GONE_READING) and ok
	definition.metadata = {}
	ok = _check("and a verb with no template bakes its name",
		EventSheetACEApply.baked_reading_for(definition), "Flicker Light") and ok
	return ok


# ── 3. the quiet amber state, and its two doors ───────────────────────────────────


static func _test_the_quiet_state_and_its_two_doors() -> bool:
	var sheet: EventSheetResource = _sheet_with_a_gone_verb()
	var event: EventRow = sheet.events[0]
	var found: Array[Dictionary] = EventSheetMigrationFindings.findings(sheet, "res://probe.gd",
		_known_vocabulary())
	var ok: bool = _check("the sheet earns exactly one note", found.size(), 1)
	if not ok:
		return false
	ok = _check("filed under the id the Doctor files it under",
		str(found[0].get("kind", "")), EventSheetMigrationDoctor.CHECK_VERB_GONE) and ok
	ok = _check("anchored at the event that holds the row",
		EventSheetMigrationFindings.for_event(found, event).size(), 1) and ok
	ok = _check("naming the row's lane and slot, which is how the doors find it again",
		[str(found[0].get("lane", "")), int(found[0].get("index", -1))], ["action", 0]) and ok
	ok = _check("and the line it still compiles to, which is what the second door holds",
		str(found[0].get("line", "")), GONE_LINE) and ok
	ok = _check("the words lead with the pack that no longer has the verb",
		str(found[0].get("message", "")).begins_with("%s no longer has this verb." % GONE_PROVIDER),
		true) and ok
	ok = _check("and quote the reading the row still shows, values and all",
		str(found[0].get("message", "")).contains("\"%s\"" % GONE_SENTENCE), true) and ok
	ok = _check("door one is the picker",
		[str(found[0].get("fix", "")), str(found[0].get("fix_label", ""))],
		[EventSheetMigrationFindings.FIX_SEE_REPLACEMENT, "See what replaced it"]) and ok
	ok = _check("door two is the honest exit",
		[str(found[0].get("second_fix", "")), str(found[0].get("second_fix_label", ""))],
		[EventSheetMigrationFindings.FIX_KEEP_AS_CODE, "Keep as code"]) and ok
	ok = _check("the picker opens on the words of the verb that is gone, not on its id",
		EventSheetMigrationFindings.near_names(GONE_ACE), "Flicker Light") and ok

	# A CONDITION loses its words exactly the way an action does, and earns the same amber - but a
	# verbatim block is a statement and a condition is a term inside an `if`, so it offers one door.
	var asking_condition: EventSheetResource = _sheet_with_a_gone_condition()
	var condition_found: Array[Dictionary] = EventSheetMigrationFindings.findings(
		asking_condition, "res://probe.gd", _known_vocabulary())
	ok = _check("a condition earns the state too", condition_found.size(), 1) and ok
	if condition_found.size() == 1:
		ok = _check("in the condition lane", str(condition_found[0].get("lane", "")),
			"condition") and ok
		ok = _check("with the picker door and no second one",
			[str(condition_found[0].get("fix", "")),
				str(condition_found[0].get("second_fix", ""))],
			[EventSheetMigrationFindings.FIX_SEE_REPLACEMENT, ""]) and ok
	return ok


# ── 4. the head band ──────────────────────────────────────────────────────────────


## One counting line and nothing else. The question leads, the reassurance follows, and the two
## counts are over disjoint sets of rows - a verb that is gone cannot carry a forwarding address.
static func _test_the_head_band_counts_both_halves() -> bool:
	var ok: bool = _check("the band says both halves",
		EventForgeVocabularyRecord.band_reading(EventForgeVocabularyRecord.band_facts(12, 2)),
		"2 rows ask you - 12 migrate cleanly")
	ok = _check("one of each reads as one of each",
		EventForgeVocabularyRecord.band_reading(EventForgeVocabularyRecord.band_facts(1, 1)),
		"1 row asks you - 1 migrates cleanly") and ok
	ok = _check("nothing to migrate cleanly leaves only the question",
		EventForgeVocabularyRecord.band_reading(EventForgeVocabularyRecord.band_facts(0, 2)),
		"2 rows ask you") and ok
	ok = _check("and a sheet with nothing asking keeps the line it always had",
		EventForgeVocabularyRecord.band_reading({"count": 3, "asking": 0, "since": ""}),
		"3 rows have a newer spelling") and ok
	ok = _check("a sheet with nothing to say says nothing",
		EventForgeVocabularyRecord.band_reading(EventForgeVocabularyRecord.band_facts(0, 0)),
		"") and ok
	# The count the band's first half is built from, over the rows themselves.
	var sheet: EventSheetResource = _sheet_with_a_gone_verb()
	ok = _check("the asking count is over EVENTS, so a row is counted where a reader would look",
		EventSheetMigrationFindings.events_asking(EventSheetMigrationFindings.findings(
			sheet, "res://probe.gd", _known_vocabulary())), 1) and ok
	return ok


# ── 5. what the rule declines to report ───────────────────────────────────────────


## The narrowness is the whole difference between a section worth reading and a wall of noise.
static func _test_what_is_not_a_finding() -> bool:
	var known: Callable = _known_vocabulary()
	var ordinary: EventSheetResource = _sheet_with(_print_action())
	var ok: bool = _check("a verb the vocabulary still has is nobody's finding",
		EventSheetMigrationFindings.findings(ordinary, "res://probe.gd", known).size(), 0)

	# A reflected verb is built on demand out of the project's own scripts, so it is absent from a
	# registry build for perfectly ordinary reasons and was never a verb the vocabulary "lost".
	var reflected: ACEAction = _gone_action()
	reflected.ace_id = "method:flicker"
	ok = _check("a reflected member id is not a lost verb",
		EventSheetMigrationFindings.findings(_sheet_with(reflected), "res://probe.gd",
			known).size(), 0) and ok

	# A row with no template does not compile to anything, which is a different and louder thing
	# than a row that has outlived its words.
	var templateless: ACEAction = _gone_action()
	templateless.codegen_template = ""
	ok = _check("a row with nothing baked on it is a different story, and not this one",
		EventSheetMigrationFindings.findings(_sheet_with(templateless), "res://probe.gd",
			known).size(), 0) and ok

	# A verbatim block has no verb to lose - and neither does any other row kind. Every one of them
	# answers `null` to a question about `ace_id`, which is "not a verb" rather than "a verb the
	# vocabulary lost"; a section that could not tell those apart reported every sheet in this repo.
	var block := RawCodeRow.new()
	block.code = GONE_LINE
	ok = _check("and a block that is already code has nothing to be asked",
		EventSheetMigrationFindings.findings(_sheet_with(block), "res://probe.gd",
			known).size(), 0) and ok
	ok = _check("nor has any other row kind, which is not a verb at all",
		EventSheetMigrationFindings.findings(_sheet_with(CustomBlockRow.new()), "res://probe.gd",
			known).size(), 0) and ok

	# The Doctor's corpus: every stored sheet, then a capped sample of the scripts, sorted so two
	# machines read the same files in the same order.
	var corpus: PackedStringArray = EventSheetMigrationDoctor.corpus(
		PackedStringArray(["res://b.tres", "res://a.tres"]),
		PackedStringArray(["res://z.gd", "res://a.gd"]))
	ok = _check("the stored sheets are read whole and first, then the scripts, all in path order",
		corpus, PackedStringArray(["res://a.tres", "res://b.tres", "res://a.gd", "res://z.gd"])) and ok
	var many: PackedStringArray = PackedStringArray()
	for index: int in range(EventSheetMigrationDoctor.SCRIPTS_SAMPLED + 10):
		many.append("res://s%02d.gd" % index)
	ok = _check("and the script half is capped rather than read whole",
		EventSheetMigrationDoctor.corpus(PackedStringArray(), many).size(),
		EventSheetMigrationDoctor.SCRIPTS_SAMPLED) and ok
	return ok


# ── 6. the honest exit ────────────────────────────────────────────────────────────


## "Keep as code" writes the line exactly as it already compiles, with the offered comment above it,
## as ONE undo step - and Ctrl+Z puts the picked row back exactly as it was.
static func _test_keeping_it_as_code() -> bool:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	var sheet: EventSheetResource = _sheet_with_a_gone_verb()
	sheet.external_source_path = PROBE_PATH
	dock.setup(sheet)
	var finding: Dictionary = EventSheetMigrationFindings.findings(
		dock.get_current_sheet(), PROBE_PATH, _known_vocabulary())[0]

	var comment: String = EventSheetKeepAsCodeDialog.comment_for(finding)
	var ok: bool = _check("the offered comment leads with the sentence the code no longer says",
		comment, "# %s - the old %s row, kept as written." % [GONE_SENTENCE, GONE_PROVIDER])
	ok = _check("the receipt shows the row as it reads and the block it becomes",
		EventSheetKeepAsCodeDialog.receipt_lines(finding, comment),
		PackedStringArray([GONE_SENTENCE, "%s\n%s" % [comment, GONE_LINE]])) and ok
	ok = _check("and striking the comment out leaves the bare line",
		EventSheetKeepAsCodeDialog.receipt_lines(finding, "")[1], GONE_LINE) and ok

	var before_output: String = _compiled(dock.get_current_sheet())
	dock._keep_as_code_dialog.open(finding)
	dock._keep_as_code_dialog.confirm()
	var kept: Variant = (dock.get_current_sheet().events[0] as EventRow).actions[0]
	ok = _check("the row is now the honest verbatim block", kept is RawCodeRow, true) and ok
	if kept is RawCodeRow:
		ok = _check("holding the comment and the line, exactly as shown",
			(kept as RawCodeRow).code, "%s\n%s" % [comment, GONE_LINE]) and ok
	ok = _check("the code the file compiles to still carries that exact line",
		_compiled(dock.get_current_sheet()).contains(GONE_LINE), true) and ok

	dock._undo_redo_adapter.undo()
	var restored: Variant = (dock.get_current_sheet().events[0] as EventRow).actions[0]
	ok = _check("and one Ctrl+Z puts the picked row back", restored is ACEAction, true) and ok
	if restored is ACEAction:
		ok = _check("with its id, its template and its reading unharmed",
			[(restored as ACEAction).ace_id, (restored as ACEAction).codegen_template,
				(restored as ACEAction).display_text],
			[GONE_ACE, GONE_TEMPLATE, GONE_READING]) and ok
	ok = _check("leaving the file compiling to exactly what it did before",
		_compiled(dock.get_current_sheet()), before_output) and ok
	dock.free()

	# The pure edit refuses what it cannot write, rather than writing something else.
	ok = _check("a condition cannot become a statement, and says so by refusing",
		EventSheetMigrationFindings.keep_it_as_code(
			{"event": EventRow.new(), "index": 0, "lane": "condition", "line": GONE_LINE}),
		false) and ok
	ok = _test_the_scope_travels_with_the_line() and ok
	ok = _test_the_byte_gate_refuses_what_it_cannot_prove() and ok
	ok = _test_the_row_is_found_again_rather_than_held() and ok
	return ok


## THE ROW IS FOUND AGAIN, NEVER HELD. The finding carries the EventRow the sheet was BUILT with, and
## the undo funnel replaces every resource with a snapshot duplicate when it commits - so a dialog
## that wrote into the held row after any intervening edit would mutate a detached object, return
## true, record an undo entry for nothing, and report success over a sheet that did not change. The
## row is addressed by the event's own uid and the slot, and a row that is genuinely gone is said out
## loud rather than silently succeeded over.
static func _test_the_row_is_found_again_rather_than_held() -> bool:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	var sheet: EventSheetResource = _sheet_with_a_gone_verb()
	sheet.external_source_path = PROBE_PATH
	dock.setup(sheet)
	var finding: Dictionary = EventSheetMigrationFindings.findings(
		dock.get_current_sheet(), PROBE_PATH, _known_vocabulary())[0]
	dock._keep_as_code_dialog.open(finding)
	# The funnel's own commit, written out: every resource in the sheet is replaced by a snapshot
	# duplicate, which is exactly what detaches a row somebody held across the edit.
	dock._perform_undoable_sheet_edit("An edit that snapshots the sheet", func() -> bool:
		var replaced: Array[Resource] = []
		for item: Variant in dock.get_current_sheet().events:
			replaced.append((item as Resource).duplicate(true))
		dock.get_current_sheet().events.assign(replaced)
		return true)
	var held: EventRow = finding.get("event", null) as EventRow
	var ok: bool = _check("the held row really is a different object now",
		held == (dock.get_current_sheet().events[0] as EventRow), false)
	ok = _check("wearing the same uid, which is how it is found again",
		held.event_uid, (dock.get_current_sheet().events[0] as EventRow).event_uid) and ok
	dock._keep_as_code_dialog.confirm()
	var kept: Variant = (dock.get_current_sheet().events[0] as EventRow).actions[0]
	ok = _check("and the button still writes into the sheet that is open",
		kept is RawCodeRow, true) and ok
	ok = _check("saying what it did rather than reporting over nothing",
		str(dock._status_label.text).begins_with("Kept as written:"), true) and ok
	# And a row that is genuinely gone is refused with words, not swallowed.
	dock._perform_undoable_sheet_edit("Take the row out", func() -> bool:
		(dock.get_current_sheet().events[0] as EventRow).actions.clear()
		return true)
	dock._keep_as_code_dialog.confirm()
	ok = _check("a row that is no longer there is said out loud",
		str(dock._status_label.text).replace("⚠  ", ""),
		"That row is no longer in this sheet, so nothing was written - the sheet changed while this was open.") and ok
	dock.free()
	return ok


## THE SECOND EMITTER TRAP, pinned. A row standing inside a "With node X:" scope compiles to a call
## ON THAT NODE, because the compiler folds the scope in - and a kept line that filled the template
## by hand would have been a call on the host instead, which is a different program. The line comes
## from the compiler's own call, so it carries the scope, and the file does not move a byte.
static func _test_the_scope_travels_with_the_line() -> bool:
	var dock: EventSheetDock = _dock_with_a_scoped_gone_verb()
	var found: Array[Dictionary] = EventSheetMigrationFindings.findings(
		dock.get_current_sheet(), "", _known_vocabulary())
	var ok: bool = _check("the scoped row earns the state like any other", found.size(), 1)
	if not ok:
		dock.free()
		return false
	ok = _check("and the line it would keep is the call the compiler makes, scope and all",
		str(found[0].get("line", "")), "$Enemy.flicker(0.4)") and ok
	var before: String = _compiled(dock.get_current_sheet())
	dock._keep_as_code_dialog.open(found[0])
	# The comment struck out, because this measurement is about the CODE: a comment is a line the
	# reader asked for, and the gate leaves it out of the question for the same reason.
	dock._keep_as_code_dialog._comment_check.button_pressed = false
	dock._keep_as_code_dialog.confirm()
	ok = _check("keeping it as code writes the block",
		(dock.get_current_sheet().events[0] as EventRow).actions[0] is RawCodeRow, true) and ok
	ok = _check("and the file compiles to exactly what it did before",
		_compiled(dock.get_current_sheet()), before) and ok
	dock.free()
	return ok


## THE GATE, from the side that matters: a rewrite that would move the file's bytes is refused, and
## the row is left exactly as it is. Driven by handing the dialog a line that is not what the row
## emits - which is precisely the shape of every bug the gate is there to catch.
static func _test_the_byte_gate_refuses_what_it_cannot_prove() -> bool:
	var dock: EventSheetDock = _dock_with_a_scoped_gone_verb()
	var found: Array[Dictionary] = EventSheetMigrationFindings.findings(
		dock.get_current_sheet(), "", _known_vocabulary())
	if found.is_empty():
		dock.free()
		return _check("a finding to test the gate with", false, true)
	var wrong: Dictionary = found[0].duplicate()
	wrong["line"] = "flicker(999)"
	var before: String = _compiled(dock.get_current_sheet())
	dock._keep_as_code_dialog.open(wrong)
	dock._keep_as_code_dialog.confirm()
	var ok: bool = _check("the row is left exactly as it was, because the bytes would have moved",
		(dock.get_current_sheet().events[0] as EventRow).actions[0] is ACEAction, true)
	ok = _check("and the file still compiles to what it did",
		_compiled(dock.get_current_sheet()), before) and ok
	dock.free()
	return ok


## One dock over one event that stands inside a "With node X:" scope and holds a lost verb whose
## template is retargetable - the shape both gate tests above are about.
static func _dock_with_a_scoped_gone_verb() -> EventSheetDock:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	var scoped: ACEAction = _gone_action()
	scoped.codegen_template = "{target.}flicker({amount})"
	scoped.params = {"amount": "0.4"}
	var event := EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.with_node_target = "$Enemy"
	event.actions = [scoped] as Array[Resource]
	var sheet := EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.events = [event] as Array[Resource]
	dock.setup(sheet)
	return dock


# ── 7. the Doctor's triage inbox ──────────────────────────────────────────────────


## Same finding, one wording: what the strip says under the selected row is what the inbox files.
static func _test_the_doctor_files_the_same_words() -> bool:
	var sheet: EventSheetResource = _sheet_with_a_gone_verb()
	var mine: Array[Dictionary] = EventSheetMigrationFindings.findings(sheet, "res://probe.gd",
		_known_vocabulary())
	var filed: Array[Dictionary] = EventSheetMigrationDoctor.script_findings("res://probe.gd", mine)
	var ok: bool = _check("one row, one line in the inbox", filed.size(), 1)
	if not ok:
		return false
	ok = _check("filed as a warning under the section's own check id",
		[str(filed[0].get("severity", "")), str(filed[0].get("check", ""))],
		["warning", EventSheetMigrationDoctor.CHECK_VERB_GONE]) and ok
	ok = _check("with the very sentence the help strip shows",
		str(filed[0].get("message", "")), str(mine[0].get("message", ""))) and ok
	ok = _check("and the verb as its subject", str(filed[0].get("subject", "")), GONE_ACE) and ok
	ok = _check("a project with nothing lost files no lines",
		EventSheetMigrationDoctor.script_findings("res://probe.gd", []).size(), 0) and ok
	return ok


# ── helpers ───────────────────────────────────────────────────────────────────────


## The vocabulary this project is pretending to have: everything but the flicker pack.
static func _known_vocabulary() -> Callable:
	return EventSheetMigrationFindings.resolver_over({"Core::print": true, "Core::IsPaused": true})


static func _gone_action() -> ACEAction:
	var action := ACEAction.new()
	action.provider_id = GONE_PROVIDER
	action.ace_id = GONE_ACE
	action.codegen_template = GONE_TEMPLATE
	action.display_text = GONE_READING
	action.params = {"light": "$Lamp", "amount": "0.4"}
	return action


static func _print_action() -> ACEAction:
	var action := ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "print"
	action.codegen_template = "print({text})"
	action.params = {"text": "\"hello\""}
	return action


static func _sheet_with_a_gone_verb() -> EventSheetResource:
	return _sheet_with(_gone_action())


## A sheet whose one event's CONDITION names a verb the vocabulary no longer has.
static func _sheet_with_a_gone_condition() -> EventSheetResource:
	var condition := ACECondition.new()
	condition.provider_id = GONE_PROVIDER
	condition.ace_id = "LightIsFlickering"
	condition.codegen_template = "{light}.is_flickering()"
	condition.display_text = "{light} is flickering"
	condition.params = {"light": "$Lamp"}
	var event := EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	event.conditions = [condition] as Array[ACECondition]
	event.actions = [_print_action()] as Array[Resource]
	var sheet := EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.events = [event] as Array[Resource]
	return sheet


## One event, one trigger, one row in the action lane - whatever the caller wants measured.
static func _sheet_with(row: Resource) -> EventSheetResource:
	var event := EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	event.actions = [row] as Array[Resource]
	var sheet := EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.events = [event] as Array[Resource]
	return sheet


static func _compiled(sheet: EventSheetResource) -> String:
	return str(SheetCompiler.compile(sheet, PROBE_PATH).get("output", ""))


static func _write(path: String, text: String) -> Error:
	var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if handle == null:
		return FileAccess.get_open_error()
	handle.store_string(text)
	handle.close()
	return OK


# ── 8. the two corpus modes ───────────────────────────────────────────────────────


## THE SAMPLE AND THE WHOLE READ, both pinned by value over a fixture folder, because a mode nobody
## can tell apart from its output is a mode nobody can trust. The sampled run is the default and
## always will be - reading a script means LIFTING it - and the whole read is the opt-in for the run
## that has to be certain.
##
## Two halves. The first is the corpus itself, over invented paths, where "which files were read" is
## the entire difference between the modes and is a value rather than a count. The second is a real
## folder on disk, read through both corpora, proving that the stored sheet's row is reported the
## same way either way: the mode changes how much is opened, never what is said about what was.
static func _test_the_two_corpus_modes() -> bool:
	var stored: PackedStringArray = PackedStringArray(["res://a.tres"])
	var scripts: PackedStringArray = PackedStringArray()
	for index: int in EventSheetMigrationDoctor.SCRIPTS_SAMPLED + 3:
		scripts.append("res://s%02d.gd" % index)
	var sampled: PackedStringArray = PackedStringArray(["res://a.tres"])
	for index: int in EventSheetMigrationDoctor.SCRIPTS_SAMPLED:
		sampled.append("res://s%02d.gd" % index)
	var whole: PackedStringArray = PackedStringArray(["res://a.tres"])
	whole.append_array(scripts)
	var ok: bool = _check("the sampled corpus is the stored sheets and the first few scripts",
		EventSheetMigrationDoctor.corpus(stored, scripts), sampled)
	ok = _check("and the whole read is every one of them, in the same order",
		EventSheetMigrationDoctor.corpus(stored, scripts, true), whole) and ok
	ok = _check("the summary line names both numbers when it sampled",
		EventSheetMigrationDoctor.sample_note(stored, scripts),
		" The .gd half is a sample: %d of %d script(s) were read." % [
			EventSheetMigrationDoctor.SCRIPTS_SAMPLED, scripts.size()]) and ok
	ok = _check("and says so when it read the whole half",
		EventSheetMigrationDoctor.sample_note(stored, scripts, true),
		" The .gd half was read whole: %d script(s)." % scripts.size()) and ok
	# A whole read over a project small enough that the sample already covered it says so anyway -
	# the line is about which mode ran, not about whether it happened to matter.
	ok = _check("a whole read over a small project still names itself",
		EventSheetMigrationDoctor.sample_note(stored, PackedStringArray(["res://one.gd"]), true),
		" The .gd half was read whole: 1 script(s).") and ok

	# The second half: a real folder, read both ways.
	var folder: String = "user://eventforge_corpus_fixture"
	DirAccess.make_dir_recursive_absolute(folder)
	var sheet_path: String = folder.path_join("stored.tres")
	if ResourceSaver.save(_stored_sheet_on_an_older_spelling(), sheet_path) != OK:
		return _check("the fixture sheet is stored", false, true)
	var written: PackedStringArray = PackedStringArray()
	for index: int in EventSheetMigrationDoctor.SCRIPTS_SAMPLED + 2:
		var script_path: String = folder.path_join("filler_%02d.gd" % index)
		var file: FileAccess = FileAccess.open(script_path, FileAccess.WRITE)
		if file == null:
			return _check("the fixture scripts are written", false, true)
		file.store_string("extends Node
")
		file.close()
		written.append(script_path)
	var said: PackedStringArray = PackedStringArray()
	for mode: bool in [false, true]:
		var read: PackedStringArray = EventSheetMigrationDoctor.corpus(
			PackedStringArray([sheet_path]), written, mode)
		var rows: Array[Dictionary] = EventSheetMigrationDoctor.rows(read)
		var line: String = "%d file(s):" % read.size()
		for row: Dictionary in rows:
			line += " %s -> %s %s" % [str(row.get("from_id", "")), str(row.get("to_id", "")),
				"asks" if bool(row.get("asks", true)) else "moves"]
		said.append(line)
	ok = _check("the two modes open different numbers of files and say the same thing about the one that matters",
		said, PackedStringArray([
			"%d file(s): Core::PlayAudio -> Core::AudioPlay moves" % (EventSheetMigrationDoctor.SCRIPTS_SAMPLED + 1),
			"%d file(s): Core::PlayAudio -> Core::AudioPlay moves" % (written.size() + 1),
		])) and ok
	DirAccess.remove_absolute(sheet_path)
	for script_path: String in written:
		DirAccess.remove_absolute(script_path)
	DirAccess.remove_absolute(folder)
	return ok


## A stored sheet holding one row on a spelling the vocabulary has since replaced - the general
## shelf's Play Sound, which the Audio shelf's Play succeeded. Stored rather than written out as
## GDScript because both spellings emit the same line, so only a sheet that WRITES DOWN which verb
## it was picked from can be asked the question at all.
static func _stored_sheet_on_an_older_spelling() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "MigrationCorpusFixture"
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
	sheet.events.append(event)
	return sheet


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("migration_gone_verb_test", label, actual, expected)
