# Godot EventSheets - everything the editor SAYS about a pattern, pinned by value.
#
# The registry is proved on its own by pattern_facts_test; this is the layer above it - the pre-pass
# that claims a pattern from a real hand-written file, the chip that names it, the counts on the
# coverage chip, the evidence a hover owes the reader, the Adopt plan and its refusals, the Doctor's
# smells, the Manual page, and the lens that turns the whole thing off.
#
# EVERY ASSERTION IS A VALUE. The words a reader is shown are the thing under test, so a count would
# pass while the sentence rotted; and the fixtures are opened the way the dock opens a `.gd`, so the
# rows pinned here are the rows a reader gets.
#
# The last test is the covenant under all of it: both fixtures still re-emit BYTE FOR BYTE. Naming a
# pattern is a lens, and a lens that changed a file would not be one.
@tool
class_name PatternUXTest
extends RefCounted

const COUNTDOWN_PATH := "res://tests/fixtures/patterns/countdown.gd"
const POOL_PATH := "res://tests/fixtures/patterns/object_pool.gd"
const TEMP_PATH := "user://pattern_ux_emitted.gd"


static func run() -> bool:
	var ok: bool = true
	ok = _test_claims_from_a_real_file() and ok
	ok = _test_the_chip_names_the_pattern() and ok
	ok = _test_the_coverage_chip_counts_them() and ok
	ok = _test_the_hover_owes_its_evidence() and ok
	ok = _test_the_adopt_plan() and ok
	ok = _test_the_adopt_refusals() and ok
	ok = _test_the_doctor_smells() and ok
	ok = _test_the_manual_page() and ok
	ok = _test_the_theme_token_derives() and ok
	ok = _test_round_trip_is_byte_identical() and ok
	return ok


# ── The pre-pass ──


static func _test_claims_from_a_real_file() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = _sheet(COUNTDOWN_PATH)
	EventSheetPatternFacts.clear(sheet)
	EventSheetViewportReadingRows.claim_patterns(sheet)
	var claims: Array = EventSheetPatternFacts.claims(sheet)
	ok = _check("a hand-written cooldown is claimed once", claims.size(), 1) and ok
	var claim: Dictionary = claims[0] if not claims.is_empty() else {}
	ok = _check("as the countdown pattern", str(claim.get("pattern", "")), "countdown") and ok
	# The claim's own words are the SENTENCE the hover shows; the chip says the pattern's NAME.
	ok = _check("the claim says what the file does, in one line", str(claim.get("words", "")),
		"counts cooldown down and asks whether it has run out") and ok
	ok = _check("the reading named no behavior itself", str(claim.get("adoptable", "")), "") and ok
	# ...so the pattern's own default stands in, and the offer appears anyway.
	ok = _check("but the pattern names one, which is what everything offering an adoption asks",
		EventSheetPatternVocabulary.adoptable_for(claim), "core_cooldown") and ok
	# The evidence is the exact source lines, never a paraphrase.
	ok = _check("with the exact source line as its evidence",
		", ".join(claim.get("evidence", PackedStringArray())), "cooldown -= delta") and ok

	var pooling: EventSheetResource = _sheet(POOL_PATH)
	EventSheetPatternFacts.clear(pooling)
	EventSheetViewportReadingRows.claim_patterns(pooling)
	var pool_claims: Array = EventSheetPatternFacts.claims(pooling)
	ok = _check("taking an object out of a list instead of making one is an object pool",
		str((pool_claims[0] as Dictionary).get("pattern", "")) if not pool_claims.is_empty() else "",
		"object_pool") and ok
	# THIS reading names its own behavior, where the countdown above left it to the pattern - and
	# both routes land on the same answer, which is the point of asking the vocabulary either way.
	ok = _check("and this reading names the behavior itself",
		EventSheetPatternVocabulary.adoptable_for(pool_claims[0] as Dictionary) if not pool_claims.is_empty() else "?",
		"object_pool") and ok
	# ...but no adapter ships for it yet, so nothing OFFERS the swap. An offer that cannot run is
	# worse than no offer.
	ok = _check("...which this build cannot yet perform, so nothing offers it",
		EventSheetPatternAdopt.is_adoptable(pool_claims[0] as Dictionary) if not pool_claims.is_empty() else true,
		false) and ok
	return ok


# ─────────


static func _test_the_chip_names_the_pattern() -> bool:
	var ok: bool = true
	var rows: PackedStringArray = _row_texts(_open(COUNTDOWN_PATH, true))
	ok = _check("the event that OWNS the pattern wears the chip",
		_row_containing(rows, "Subtract dt from cooldown"),
		"Subtract dt from cooldown | ⟡ Cooldown") and ok
	# The rows that merely USE the pattern's words get nothing: the claim names one row, and a chip
	# on every row that mentions the variable would be noise rather than a name.
	ok = _check("and the rows that only use its words do not",
		_row_containing(rows, "Call Shoot").contains("⟡"), false) and ok

	# The lens is what turns the whole thing off, and it is a SPAN-level lens: with it off the
	# sheet reads as its own plain sentences and nothing else about the row changes.
	var plain: EventSheetViewport = _open(COUNTDOWN_PATH, true)
	plain.patterns_lens = false
	plain.set_sheet(plain._sheet)
	ok = _check("with the Patterns lens off the row is its plain sentence again",
		_row_containing(_row_texts(plain), "Subtract dt from cooldown"),
		"Subtract dt from cooldown") and ok
	return ok


# ─────────


static func _test_the_coverage_chip_counts_them() -> bool:
	var ok: bool = true
	var view: EventSheetViewport = _open(COUNTDOWN_PATH, true)
	var summary: Dictionary = EventSheetPatternFacts.summary(view._sheet)
	# TWO claims here: the cooldown, and the Every-tick one the blank event carries. The registry
	# counts both, because both are true; the CHIP counts only the marked one, below.
	ok = _check("both claims are in the registry", int(summary.get("patterns", -1)), 2) and ok
	# The registry counts what the CLAIMS named; the chip below counts what a reader will actually be
	# offered, which is the same number once the pattern's own default is allowed to stand in.
	ok = _check("the reading itself named no behavior here", int(summary.get("adoptable", -1)), 0) and ok
	ok = _check("the chip says both counts, and ends in the arrow that promises a walk",
		EventSheetReadingCoverage.chip_text(view._sheet),
		"reads as events · 1 pattern · 1 adoptable ▸") and ok
	# The Every-tick claim on the same event is NOT counted and wears no chip: a marker beside a row
	# whose own margin already says it runs every tick is the same fact twice.
	ok = _check("a pattern the sheet does not mark is not counted either",
		EventSheetPatternVocabulary.is_marked("blank_event"), false) and ok
	# A file with no claims must not grow "0 patterns": a number with nothing in it is worse than
	# no number.
	ok = _check("and a file the readings claimed nothing on says only the good news",
		EventSheetReadingCoverage.pattern_chip_text(EventSheetResource.new()), "") and ok
	return ok


# ─────────


static func _test_the_hover_owes_its_evidence() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = _sheet(COUNTDOWN_PATH)
	EventSheetPatternFacts.clear(sheet)
	EventSheetViewportReadingRows.claim_patterns(sheet)
	var owner: String = str((EventSheetPatternFacts.claims(sheet)[0] as Dictionary).get("row_uid", ""))
	ok = _check("the hover says WHICH pattern and WHY, in the file's own lines",
		ViewportTooltipHelper.pattern_evidence_line(sheet, owner),
		"read as the Cooldown pattern because: cooldown -= delta") and ok
	ok = _check("a row that owns no claim owes nothing",
		ViewportTooltipHelper.pattern_evidence_line(sheet, "not-a-row"), "") and ok
	ok = _check("the chip itself explains the pattern and offers the Manual",
		ViewportTooltipHelper.pattern_chip_tooltip("countdown"),
		"a number counted down every tick, with something that happens when it reaches zero\nOpen in the Manual") and ok
	return ok


# ─────────


static func _test_the_adopt_plan() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = _sheet(COUNTDOWN_PATH)
	EventSheetPatternFacts.clear(sheet)
	EventSheetViewportReadingRows.claim_patterns(sheet)
	var claim: Dictionary = EventSheetPatternFacts.claims(sheet)[0]
	ok = _check("the claim is one this build can rewrite", EventSheetPatternAdopt.is_adoptable(claim), true) and ok
	var current: Dictionary = EventSheetPatternAdopt.plan(sheet, claim)
	ok = _check("the plan is offered", bool(current.get("ok", false)), true) and ok
	ok = _check("under the behavior's own name", str(current.get("title", "")), "Adopt behavior: Cooldown") and ok
	# THE PREVIEW is the surface a reader is asked to trust, so its words are pinned rather than its
	# shape: three hand-written rows become two, and the per-tick subtraction goes entirely.
	ok = _check("the preview shows every changing event, before and after",
		"\n".join(EventSheetPatternAdoptDialog.preview_lines(current)),
		"● Subtract delta from cooldown  ->  (this event is no longer needed)\n"
		+ "● cooldown <= 0.0 · fire · Call shoot() · Set cooldown to 0.5"
		+ "  ->  cooldown cooldown is ready · fire · Call shoot() · start cooldown cooldown for 0.5s") and ok
	ok = _check("and says what was checked before offering it",
		" ".join(current.get("checks", PackedStringArray())),
		"cooldown is used only by these events."
		+ " The behavior counts the same 0.5 seconds the code did."
		+ " Cooldown Is Ready becomes true at the moment the countdown reached zero.") and ok

	# APPLY does exactly what the preview said: the subtraction is gone, the comparison is the
	# behavior's condition, the restart is the behavior's action - and nothing else moved.
	ok = _check("applying it changes exactly the rows the plan listed",
		EventSheetPatternAdopt.apply(sheet, claim), 3) and ok
	ok = _check("and the file it emits is the behavior's own code",
		_emitted(sheet).contains("set_meta(&\"__ef_cool_\" + str(\"cooldown\")"), true) and ok
	ok = _check("with the per-tick subtraction gone entirely",
		_emitted(sheet).contains("cooldown -= delta"), false) and ok
	ok = _check("...and every untouched line still there",
		_emitted(sheet).contains("func shoot() -> void:"), true) and ok
	return ok


static func _test_the_adopt_refusals() -> bool:
	var ok: bool = true
	# NO RESTART: a countdown the code never puts back has no length for the behavior to keep, so
	# rewriting it would invent one.
	var no_restart: EventSheetResource = _sheet(COUNTDOWN_PATH)
	for event_row: EventRow in _events(no_restart):
		var kept: Array[Resource] = []
		for action: Variant in event_row.actions:
			if action is ACEAction and (action as ACEAction).ace_id == "SetVar":
				continue
			kept.append(action)
		event_row.actions = kept
	ok = _check("a countdown nothing restarts is refused, with the reason",
		str(_plan_for(no_restart).get("reason", "")),
		"Nothing ever puts cooldown back above zero, so there is no cooldown length for the behavior to use.") and ok

	# COMPARED TO SOMETHING ELSE: the behavior knows ready and not-ready, nothing in between. The
	# reading refuses this one before the adopter ever sees it - a number merely subtracted from is
	# not a countdown at all - which is the check landing one layer earlier than it had to.
	var wrong_compare: EventSheetResource = _sheet(COUNTDOWN_PATH)
	for event_row: EventRow in _events(wrong_compare):
		for condition: ACECondition in event_row.conditions:
			if condition != null and condition.ace_id == "CompareVar":
				condition.params["value"] = "1.0"
	ok = _check("a countdown compared to something other than zero is not even a countdown",
		_plan_for(wrong_compare).is_empty(), true) and ok

	# READ SOMEWHERE ELSE: a readout of the seconds left needs the number, and taking the counter
	# away from under it would break it.
	var also_read: EventSheetResource = _sheet(COUNTDOWN_PATH)
	for event_row: EventRow in _events(also_read):
		for action: Variant in event_row.actions:
			if action is ACEAction and (action as ACEAction).ace_id == "SetVar":
				var readout := ACEAction.new()
				readout.provider_id = "Core"
				readout.ace_id = "SetVar"
				readout.params = {"var_name": "label_text", "value": "cooldown"}
				event_row.actions.append(readout)
				break
	ok = _check("a countdown something else reads is refused, naming what reads it",
		str(_plan_for(also_read).get("reason", "")),
		"cooldown is also read by Set label_text to cooldown, which needs the number itself.") and ok

	# And a refusal draws its reason instead of a preview - there is nothing to press a button for.
	ok = _check("a refused plan previews the reason and nothing else",
		"\n".join(EventSheetPatternAdoptDialog.preview_lines(_plan_for(no_restart))),
		"Nothing ever puts cooldown back above zero, so there is no cooldown length for the behavior to use.") and ok
	return ok


# ─────────


static func _test_the_doctor_smells() -> bool:
	var ok: bool = true
	var findings: Array[Dictionary] = []
	EventSheetProjectDoctor.scan_pattern_smells(_sheet(COUNTDOWN_PATH), "res://player.gd", findings)
	ok = _check("a whole cooldown is not accused of anything",
		_finding_messages(findings, "pattern-countdown-never-restarts"), "") and ok
	ok = _check("but it IS offered the behavior, which is how Adopt gets discovered",
		_finding_messages(findings, "pattern-is-a-behavior"),
		"This block is the Cooldown behavior - Adopt behavior?") and ok

	var half_written: EventSheetResource = _sheet(COUNTDOWN_PATH)
	for event_row: EventRow in _events(half_written):
		var kept: Array[Resource] = []
		for action: Variant in event_row.actions:
			if action is ACEAction and (action as ACEAction).ace_id == "SetVar":
				continue
			kept.append(action)
		event_row.actions = kept
	var half_findings: Array[Dictionary] = []
	EventSheetProjectDoctor.scan_pattern_smells(half_written, "res://player.gd", half_findings)
	ok = _check("a countdown with no restart is the classic half-written pattern",
		_finding_messages(half_findings, "pattern-countdown-never-restarts"),
		"cooldown counts down but never restarts - this event subtracts from it and nothing sets it above zero.") and ok
	ok = _check("and it is a warning, because the game misbehaves rather than fails to run",
		_finding_severity(half_findings, "pattern-countdown-never-restarts"), "warning") and ok
	ok = _check("...and it is no longer offered a behavior it cannot become",
		_finding_messages(half_findings, "pattern-is-a-behavior"), "") and ok
	ok = _check("a sheet with no claims is accused of nothing at all",
		_scan(EventSheetResource.new()).size(), 0) and ok
	return ok


# ───────────────


static func _test_the_manual_page() -> bool:
	var ok: bool = true
	ok = _check("only the patterns with a fixture reach the page",
		", ".join(EventSheetPatternVocabulary.documented_ids()), "countdown, object_pool") and ok
	var blocks: Array[Dictionary] = EventSheetPatternManual.pattern_blocks("countdown")
	ok = _check("a section leads with the pattern's name",
		str(blocks[0].get("text", "")) if not blocks.is_empty() else "", "Cooldown") and ok
	ok = _check("then the one line that says what it is",
		str(blocks[1].get("bbcode", "")) if blocks.size() > 1 else "",
		"a number counted down every tick, with something that happens when it reaches zero") and ok
	# THE TWO COLUMNS, and the whole point of them: the right one is the same text as the left,
	# handed to the renderer as a figure - so the page cannot show a shape the sheet does not read.
	var columns: Array = blocks[2].get("columns", []) as Array if blocks.size() > 2 else []
	ok = _check("the left column is the file, printed",
		str(((columns[0] as Array)[1] as Dictionary).get("language", "")) if columns.size() > 0 else "", "gdscript") and ok
	ok = _check("the right column is the very same text, drawn as rows",
		str(((columns[1] as Array)[1] as Dictionary).get("language", "")) if columns.size() > 1 else "", "eventsheet") and ok
	ok = _check("...literally the same lines, so the two halves can never disagree",
		((columns[0] as Array)[1] as Dictionary).get("lines", []) == ((columns[1] as Array)[1] as Dictionary).get("lines", []),
		true) and ok
	ok = _check("and a pattern with a shipped behavior offers it right there",
		str((blocks[blocks.size() - 1] as Dictionary).get("label", "")), "Adopt behavior: Cooldown") and ok
	ok = _check("a pattern with no fixture has no section to show",
		EventSheetPatternManual.pattern_blocks("tilemap").size(), 0) and ok

	# The join from a verb to the patterns it belongs to, over the claims' own ace_ids.
	var sheet: EventSheetResource = _sheet(COUNTDOWN_PATH)
	EventSheetPatternFacts.clear(sheet)
	EventSheetViewportReadingRows.claim_patterns(sheet)
	var using: Array[Dictionary] = EventSheetPatternManual.patterns_using(sheet, "Core", "StartCooldown")
	ok = _check("a verb names the pattern it is part of",
		str(using[0].get("title", "")) if not using.is_empty() else "", "⟡ Cooldown") and ok
	ok = _check("and links to that pattern's page",
		str(using[0].get("doc_id", "")) if not using.is_empty() else "", "reference:pattern/countdown") and ok
	ok = _check("a verb in no pattern says nothing",
		EventSheetPatternManual.patterns_using(sheet, "Core", "PrintLog").size(), 0) and ok
	ok = _check("the page is a real Manual page, addressable by id",
		EventSheetDocReference.has_page("reference:pattern/countdown"), true) and ok
	ok = _check("...and one for a pattern with no fixture is not",
		EventSheetDocReference.has_page("reference:pattern/tilemap"), false) and ok
	return ok


static func _test_the_theme_token_derives() -> bool:
	var ok: bool = true
	var style := EventSheetReadingStyle.new()
	# ALPHA 0 means DERIVE, not transparent: a preset saved before patterns existed must dress the
	# chip in its own palette rather than take a hard-coded plate.
	ok = _check("an undressed pattern chip takes the plain chip's plate",
		style.resolved_pattern_chip_background(), style.plain_chip_background_color) and ok
	ok = _check("and the muted text tone, which is what makes it read as a note",
		style.resolved_pattern_chip_foreground(), style.muted_text_color) and ok
	style.pattern_chip_background_color = Color(0.1, 0.2, 0.3, 1.0)
	ok = _check("a theme that dresses it wins", style.resolved_pattern_chip_background(),
		Color(0.1, 0.2, 0.3, 1.0)) and ok
	return ok


# ── The covenant ──


static func _test_round_trip_is_byte_identical() -> bool:
	var ok: bool = true
	for path: String in [COUNTDOWN_PATH, POOL_PATH]:
		var view: EventSheetViewport = _open(path, true)
		_row_texts(view)
		ok = _check("%s re-emits byte for byte after being read" % path.get_file(),
			_emitted(view._sheet), FileAccess.get_file_as_string(path)) and ok
	return ok


# ── Helpers ──


## The fixture, opened the way the dock opens a `.gd` - and DEEP-COPIED, because the importer hands
## back rows that are shared with every other import of the same file: an Adopt test that rewrote
## them in place would silently rewrite the fixture for every test after it.
static func _sheet(path: String) -> EventSheetResource:
	var sheet: EventSheetResource = (GDScriptImporter.new().import_external(path)).duplicate(true)
	sheet.read_only = true
	return sheet


static func _open(path: String, reading: bool) -> EventSheetViewport:
	var sheet: EventSheetResource = _sheet(path)
	var style := EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	view.set_reading_mode(reading)
	return view


## Every row of a view as the reader sees it - spans joined, folded children included, because a row
## folded out of sight must not decide a pass or a fail.
static func _row_texts(view: EventSheetViewport) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for entry: Variant in view.get_flat_rows():
		var row: EventRowData = (entry as Dictionary).get("row")
		if row == null:
			continue
		view._row_builder._ensure_event_spans(row)
		_collect_row_texts(view, row, texts)
	return texts


static func _collect_row_texts(view: EventSheetViewport, row: EventRowData, texts: PackedStringArray) -> void:
	view._row_builder._ensure_event_spans(row)
	var parts: PackedStringArray = PackedStringArray()
	for span: SemanticSpan in row.spans:
		parts.append(str(span.text))
	texts.append(" | ".join(parts))
	for child: EventRowData in row.children:
		_collect_row_texts(view, child, texts)


static func _row_containing(texts: PackedStringArray, needle: String) -> String:
	for text: String in texts:
		if text.contains(needle):
			return text
	return ""


static func _events(sheet: EventSheetResource) -> Array[EventRow]:
	var found: Array[EventRow] = []
	_collect_events(sheet.events, found)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			_collect_events((function_entry as EventFunction).events, found)
	return found


static func _collect_events(source: Array, into: Array[EventRow]) -> void:
	for entry: Variant in source:
		if not (entry is EventRow):
			continue
		into.append(entry as EventRow)
		_collect_events((entry as EventRow).sub_events, into)


## The plan for a sheet's first claim, whatever the readings made of it.
static func _plan_for(sheet: EventSheetResource) -> Dictionary:
	EventSheetPatternFacts.clear(sheet)
	EventSheetViewportReadingRows.claim_patterns(sheet)
	var claims: Array = EventSheetPatternFacts.claims(sheet)
	if claims.is_empty():
		return {}
	return EventSheetPatternAdopt.plan(sheet, claims[0] as Dictionary)


static func _scan(sheet: EventSheetResource) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	EventSheetProjectDoctor.scan_pattern_smells(sheet, "res://player.gd", findings)
	return findings


static func _finding_messages(findings: Array[Dictionary], check_id: String) -> String:
	var messages: PackedStringArray = PackedStringArray()
	for finding: Dictionary in findings:
		if str(finding.get("check", "")) == check_id:
			messages.append(str(finding.get("message", "")))
	return " ".join(messages)


static func _finding_severity(findings: Array[Dictionary], check_id: String) -> String:
	for finding: Dictionary in findings:
		if str(finding.get("check", "")) == check_id:
			return str(finding.get("severity", ""))
	return ""


## The GDScript a sheet emits. Compiled to a TEMPORARY path on purpose: the compiler writes its output
## to the sheet's own file, so emitting a sheet this test has deliberately rewritten would rewrite
## the fixture under every test after it.
static func _emitted(sheet: EventSheetResource) -> String:
	return str(SheetCompiler.compile(sheet, TEMP_PATH).get("output", ""))


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("  [PASS] %s" % label)
		return true
	print("  [FAIL] %s\n    expected: %s\n    actual:   %s" % [label, str(expected), str(actual)])
	return false
