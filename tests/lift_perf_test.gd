# Godot EventSheets - opening a .gd as a sheet stays fast.
#
# The lift matches every line of a file against the reverse-template index, and BUILDING that index
# compiles one RegEx per reversible descriptor template (894 of them on a stock install). The
# per-function lift path used to rebuild it once per function, so a file with N functions paid N
# full index builds: measured 2026-08-19 on this tree, that one line was ~80% of the time an open
# took (fps_controller_behavior.gd 6769 ms, save_system_addon.gd 11714 ms). Memoized, the same two
# files lift in 1143 ms and 2014 ms.
#
# This pins the win two ways, because a millisecond budget alone would either flap on a loaded
# machine or be set so loose it catches nothing:
#   1. A STRUCTURAL pin: the index is handed out by reference, so two calls return the SAME Array.
#      A future edit that goes back to composing a fresh index per caller fails here immediately,
#      on any machine, at any load - this is the invariant that actually made it fast.
#   2. A generous wall budget on a real pack open, as the backstop for a regression that keeps the
#      sharing but makes the matching itself slow. Set ~3.5x over the measured time so ordinary
#      machine load cannot trip it, while the pre-fix 6769 ms is caught with room to spare.
@tool
class_name LiftPerfTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
## A real shipped pack with many functions - the shape that exposed the per-function rebuild.
const SAMPLE_PACK: String = "res://eventsheet_addons/fps_controller/fps_controller_behavior.gd"
## Measured 1143 ms after the fix; 6769 ms before it. Generous enough not to flap under load.
const LIFT_BUDGET_MS: int = 4000
## A pack script that extends an ENGINE class, so the block-kind scan can answer "not a block kind"
## off its text and never load it. Every shipped pack but one has this shape.
const ENGINE_BASE_PACK: String = "res://eventsheet_addons/health/health_behavior.gd"
## Rebuilding the canvas rows of the sample pack - what the canvas pays after every edit, and the
## number a per-function rescan of the addon folders was once buried in (1718 ms of it).
##
## Re-measured on a QUIET machine every time the FIXTURE grows, and set at the near-doubled margin
## each earlier figure carried over its own measurement. The variable sentence took the sheet from
## 389 rows to 414 (the globals it borrows, and the folder strips over them), and those 414 rebuild
## in 950-1117 ms across five runs, one of them inside the full suite - so 1800. A budget sized
## while the machine is loaded is a budget everyone learns to ignore, so the load is taken away
## rather than paid for. What the pin is for is a rebuild that got ALGORITHMICALLY slower, and a
## regression of that kind lands far outside this band rather than just inside it.
const REBUILD_BUDGET_MS: int = 1800
## A warm warm_registries() must be a no-op. Measured 0.1 ms; 50 catches a re-run without flapping.
const WARM_REPEAT_BUDGET_MS: int = 50
## 200 mouse-motion events inside one cell. Measured 0.3 ms once a repeat is recognised as already
## answered (17.6 ms before, and it grows with the sheet). 6 catches the re-answer without flapping.
const HOVER_REPEAT_BUDGET_MS: int = 6


static func run() -> bool:
	var all_passed: bool = true

	# 1. The index is shared, not recomposed. Identity, not equality: two Arrays with equal
	# contents would still mean every caller paid a full rebuild.
	var first: Array = EventSheetACELifter._build_reverse_entries()
	var second: Array = EventSheetACELifter._build_reverse_entries()
	all_passed = _check("reverse index is composed once and shared by reference",
		is_same(first, second), true) and all_passed
	all_passed = _check("reverse index is not empty (a shared empty one would pass vacuously)",
		first.is_empty(), false) and all_passed

	# 2. The wall backstop, on a real pack opened the way the dock opens it.
	if not FileAccess.file_exists(SAMPLE_PACK):
		return _check("sample pack exists: %s" % SAMPLE_PACK.get_file(), false, true) and all_passed
	var source: String = FileAccess.get_file_as_string(SAMPLE_PACK)
	var importer: GDScriptImporter = GDScriptImporter.new()
	var sheet: EventSheetResource = importer.import_external(SAMPLE_PACK, false)
	all_passed = _check("sample pack imports", sheet == null, false) and all_passed
	if sheet == null:
		return false
	var start_usec: int = Time.get_ticks_usec()
	EventSheetACELifter.attempt_lift(sheet, source)
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	all_passed = _check("lifting %s under %d ms (took %.1f ms)" % [SAMPLE_PACK.get_file(), LIFT_BUDGET_MS, elapsed_ms],
		elapsed_ms <= float(LIFT_BUDGET_MS), true) and all_passed

	all_passed = _pin_pack_index() and all_passed
	all_passed = _pin_block_kind_prefilter() and all_passed
	all_passed = _pin_shared_matchers() and all_passed
	all_passed = _pin_warm_registries() and all_passed
	all_passed = _pin_tool_census_cache() and all_passed
	all_passed = _pin_row_rebuild(sheet) and all_passed

	return all_passed


## STRUCTURAL: a pack's editor-tool census is read once. The picker asks for it per provider card as
## it fills the Objects tree, and answering means reading every .gd of that pack end to end - 84 ms
## across the shipped packs on the first pass, 0.1 ms on every pass after it.
static func _pin_tool_census_cache() -> bool:
	var passed: bool = true
	var pack: String = "timer"
	EventSheetEditorToolCensus.clear_cache()
	EventSheetEditorToolCensus.from_pack(pack)
	passed = _check("a pack's census is remembered after the first read",
		EventSheetEditorToolCensus._pack_cache.has(pack), true) and passed
	# A caller may sort or annotate what it got back, so each reader gets its own copy of the answer.
	var first: Array = EventSheetEditorToolCensus.from_pack(pack)
	var second: Array = EventSheetEditorToolCensus.from_pack(pack)
	passed = _check("each reader gets its own copy of the census",
		is_same(first, second), false) and passed
	passed = _check("the copies say the same thing", first == second, true) and passed
	EventSheetEditorToolCensus.clear_cache()
	passed = _check("clearing drops the remembered censuses",
		EventSheetEditorToolCensus._pack_cache.is_empty(), true) and passed
	return passed


## STRUCTURAL: the behaviour-pack index is HELD, not re-derived. Identity, not equality - two equal
## dictionaries would still mean every caller paid a full stat of every pack folder, which is what
## made one row rebuild ask 219 times and cost 1.7 seconds.
static func _pin_pack_index() -> bool:
	var passed: bool = true
	var first: Dictionary = EventSheetViewportReadingRows.behaviour_pack_index()
	var second: Dictionary = EventSheetViewportReadingRows.behaviour_pack_index()
	passed = _check("behaviour-pack index is held and handed out by reference",
		is_same(first, second), true) and passed
	passed = _check("behaviour-pack index is not empty (a shared empty one would pass vacuously)",
		first.is_empty(), false) and passed
	# ...and dropping it really does rebuild, so a pack added to the project still appears.
	EventSheetViewportReadingRows.clear_pack_index()
	var rebuilt: Dictionary = EventSheetViewportReadingRows.behaviour_pack_index()
	passed = _check("clearing the index rebuilds it on the next reader",
		is_same(first, rebuilt), false) and passed
	passed = _check("the rebuilt index carries the same packs",
		rebuilt.size() == first.size(), true) and passed
	return passed


## STRUCTURAL: the block-kind scan reads a pack script's own text before deciding to load it. A
## script whose top-level `extends` names an engine class has no base SCRIPT chain at all, so it can
## never reach block_kind.gd - loading (and compiling) it was pure cost, 807 ms of it per session.
static func _pin_block_kind_prefilter() -> bool:
	var passed: bool = true
	passed = _check("a pack extending an engine class is not loaded by the block-kind scan",
		EventSheetBlockRegistry._could_extend_block_kind(ENGINE_BASE_PACK), false) and passed
	# The prefilter must never hide a real kind. Checked by MEMBERSHIP, not by the whole list: other
	# tests in the same run register their own kinds into the same process-wide registry.
	var ids: PackedStringArray = PackedStringArray()
	for kind: EventSheetBlockKind in EventSheetBlockRegistry.all_kinds():
		ids.append(kind.kind_id)
	for expected_id: String in ["enum", "preload", "region", "signal", "demo.note"]:
		passed = _check("block kind still registers: %s" % expected_id,
			ids.has(expected_id), true) and passed
	return passed


## STRUCTURAL: the matchers a rebuild asks per row, per line or per word are compiled ONCE. A RegEx
## rebuilt inside its own function costs more to build than to run, and these run thousands of times
## per rebuild. Identity again: an equal-looking RegEx would mean a fresh compile every call.
static func _pin_shared_matchers() -> bool:
	var passed: bool = true
	EventSheetSentence.leading_word("first")
	var grammar_first: RegEx = EventSheetSentence._leading_word_regex
	EventSheetSentence.leading_word("second")
	passed = _check("the grammar's leading-word matcher is compiled once",
		is_same(grammar_first, EventSheetSentence._leading_word_regex), true) and passed
	passed = _check("the grammar's leading-word matcher exists",
		grammar_first == null, false) and passed
	EventSheetInputMapFacts.action_names_in("Input.is_action_pressed(\"jump\")")
	var input_first: RegEx = EventSheetInputMapFacts._literal_regex
	EventSheetInputMapFacts.action_names_in("Input.is_action_pressed(\"fire\")")
	passed = _check("the input-map name matcher is compiled once",
		is_same(input_first, EventSheetInputMapFacts._literal_regex), true) and passed
	return passed


## The once-per-session registry build the open path forces onto the main thread costs about a
## second cold (1,809 ms before the block-kind scan stopped compiling every pack script, 1,036 ms
## after). It cannot be measured cold from inside the suite - the caches it fills are process-wide
## statics that the tests before this one have already filled - so what is pinned here is the
## property that makes the cold cost a ONE-TIME cost: a second call does nothing at all. A future
## edit that makes any of the four builds re-run per call fails here.
static func _pin_warm_registries() -> bool:
	var start_usec: int = Time.get_ticks_usec()
	EventSheetOpenJob.warm_registries()
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	return _check("warm_registries is free once warm (took %.1f ms, budget %d)" % [elapsed_ms, WARM_REPEAT_BUDGET_MS],
		elapsed_ms <= float(WARM_REPEAT_BUDGET_MS), true)


## The wall backstop on a row rebuild - what the canvas pays after every edit, and the number the
## pack index was buried in.
static func _pin_row_rebuild(sheet: EventSheetResource) -> bool:
	var passed: bool = true
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var viewport: EventSheetViewport = editor.get_viewport_control()
	var start_usec: int = Time.get_ticks_usec()
	viewport.set_sheet(sheet)
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	passed = _check("rebuilding %d rows under %d ms (took %.1f ms)" % [
		viewport.get_total_row_count(), REBUILD_BUDGET_MS, elapsed_ms],
		elapsed_ms <= float(REBUILD_BUDGET_MS), true) and passed
	# STRUCTURAL: a mouse-motion event over a cell the pointer is already in re-answers nothing. The
	# hover highlight walks the sheet for the local's scope and then every span of every row in it,
	# and a motion event fires many times per second while the pointer sits still.
	var hover_row: int = -1
	for index in viewport.get_total_row_count():
		var row: EventRowData = viewport._row_at(index)
		if row != null and row.spans.size() > 1:
			hover_row = index
			break
	passed = _check("a row with spans to hover was found", hover_row >= 0, true) and passed
	if hover_row >= 0:
		viewport._set_hover_state(hover_row, 1)
		var repeat_start: int = Time.get_ticks_usec()
		for repeat in 200:
			viewport._set_hover_state(hover_row, 1)
		var repeat_ms: float = float(Time.get_ticks_usec() - repeat_start) / 1000.0
		passed = _check("200 motion events inside one cell cost under %d ms (took %.1f ms)" % [
			HOVER_REPEAT_BUDGET_MS, repeat_ms],
			repeat_ms <= float(HOVER_REPEAT_BUDGET_MS), true) and passed
	editor.free()
	return passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("lift_perf_test", label, actual, expected)
