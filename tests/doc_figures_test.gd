# EventSheets - live figures in the guides (Phase 4)
#
# Two halves, in this order on purpose (the discipline personal_paths_test established): PROVE THE
# DETECTOR against fixtures that must pass and fixtures that must fail, and only then sweep the
# real corpus. A gate that silently matches nothing looks exactly like a clean repo.
#
# What this catches, and nothing else in the suite does:
#   - an AUTHORED ```eventsheet fence whose GDScript stopped lifting - the author asked for an
#     illustration, so this is a build error naming the fence, never a silent code card;
#   - a figure whose rows no longer resolve in the live vocabulary, which is what a renamed verb
#     looks like from a guide's point of view;
#   - the two authored markers losing their meaning: an opt-out that stops opting out, or a
#     caption that stops reaching the figure;
#   - a BAKED verdict going stale. The reader does not run this gate - it costs an import and a
#     compile per fence - it reads the answers shipped in the bundle. So this file asks the live
#     lifter (use_prebaked = false) and then checks every baked answer against what it just said.
#
# The corpus swept is docs/ + docs/Addons/ + docs/Modules/ - the sources, discovered as
# DIRECTORIES, so a new doc set is gated by existing rather than by being added to a list here.
@tool
class_name DocFiguresTest
extends RefCounted

const DOC_DIRS := ["res://docs", "res://docs/Addons", "res://docs/Modules"]

## A whole little script: a header, a lifecycle function, one verb. This is the shape the module
## guides are written in, and the shape the automatic layer exists to light up.
const GOOD_BODY := "extends Node\n\n\nfunc _ready() -> void:\n\tprint(\"ready ran\")\n"

## The same statement without a script header. It round-trips (re-emitting verbatim code is
## trivially lossless) and it is NOT a figure - which is exactly why round_trips alone is not the
## gate.
const HEADERLESS_BODY := "func _ready() -> void:\n\tprint(\"ready ran\")\n"

## A fragment with no header that DOES lift to a row. The automatic layer skips it (nobody said it
## was a sheet); the authored tag draws it (somebody did).
const FRAGMENT_BODY := "@export var speed: float = 220.0\n"


static func run() -> bool:
	var all_passed: bool = true
	# THE LIVE GATE. The reader answers this question from verdicts baked into the bundle, because
	# computing one costs a full import and a compile. This test must never do that: its whole job
	# is to ask the lifter that ships TODAY, and then to check that the baked answers still agree
	# with it (_test_corpus). Reading back the bundle here would make the gate a mirror.
	EventSheetDocFigures.use_prebaked = false
	EventSheetDocFigures.clear_gate_cache()
	all_passed = _test_gate() and all_passed
	all_passed = _test_recognizer() and all_passed
	all_passed = _test_markers() and all_passed
	all_passed = _test_prelude_crop() and all_passed
	all_passed = _test_corpus() and all_passed
	EventSheetDocFigures.use_prebaked = true
	EventSheetDocFigures.clear_gate_cache()
	return all_passed


## The detector, proved before it is trusted.
static func _test_gate() -> bool:
	var all_passed: bool = true
	all_passed = _check("a whole little script passes the gate",
		EventSheetDocFigures.gate_failure(GOOD_BODY), "") and all_passed
	all_passed = _check("a header-less fragment is refused",
		EventSheetDocFigures.gate_failure(HEADERLESS_BODY).is_empty(), false) and all_passed
	all_passed = _check("and it is refused for the RIGHT reason (not the round trip)",
		EventSheetDocFigures.gate_failure(HEADERLESS_BODY).contains("no script header"), true) and all_passed
	all_passed = _check("the header-less fragment still round-trips, which is why round_trips is not the gate",
		EventSheets.round_trips(HEADERLESS_BODY), true) and all_passed
	all_passed = _check("an empty body is refused",
		EventSheetDocFigures.gate_failure("").is_empty(), false) and all_passed
	all_passed = _check("a header with nothing under it draws no rows",
		EventSheetDocFigures.gate_failure("extends Node\n").contains("no rows to draw"), true) and all_passed
	all_passed = _check("a script header is seen through comments and blank lines",
		EventSheetDocFigures.has_script_header("# a note\n\nextends Node\n"), true) and all_passed
	all_passed = _check("a fragment starting with a func has none",
		EventSheetDocFigures.has_script_header(HEADERLESS_BODY), false) and all_passed
	return all_passed


## The one decision function, in precedence order.
static func _test_recognizer() -> bool:
	var all_passed: bool = true
	var auto: Dictionary = EventSheetDocFigures.recognize(_fence("gdscript", GOOD_BODY))
	all_passed = _check("a gdscript fence that passes the gate is a figure",
		str(auto.get("mode", "")), EventSheetDocFigures.MODE_FIGURE) and all_passed
	all_passed = _check("and it says the automatic layer decided it",
		str(auto.get("origin", "")), EventSheetDocFigures.ORIGIN_AUTOMATIC) and all_passed
	all_passed = _check("a gdscript fragment stays a code card",
		str(EventSheetDocFigures.recognize(_fence("gdscript", HEADERLESS_BODY)).get("mode", "")),
		EventSheetDocFigures.MODE_CODE) and all_passed
	all_passed = _check("an untagged fence is never a figure",
		str(EventSheetDocFigures.recognize(_fence("", GOOD_BODY)).get("mode", "")),
		EventSheetDocFigures.MODE_CODE) and all_passed
	all_passed = _check("a shell fence is never a figure",
		str(EventSheetDocFigures.recognize(_fence("sh", GOOD_BODY)).get("mode", "")),
		EventSheetDocFigures.MODE_CODE) and all_passed
	var authored: Dictionary = EventSheetDocFigures.recognize(_fence("eventsheet", GOOD_BODY))
	all_passed = _check("an authored fence is a figure",
		str(authored.get("mode", "")), EventSheetDocFigures.MODE_FIGURE) and all_passed
	all_passed = _check("and it says the author decided it",
		str(authored.get("origin", "")), EventSheetDocFigures.ORIGIN_AUTHORED) and all_passed
	# The header rule is the automatic layer's tuning, not a capability limit: a fence the author
	# tagged is drawn if it CAN be drawn, which is the whole reason the tag exists alongside the
	# detector.
	all_passed = _check("the automatic layer refuses a header-less fragment that does lift",
		str(EventSheetDocFigures.recognize(_fence("gdscript", FRAGMENT_BODY)).get("mode", "")),
		EventSheetDocFigures.MODE_CODE) and all_passed
	all_passed = _check("and the authored tag draws that same fragment",
		str(EventSheetDocFigures.recognize(_fence("eventsheet", FRAGMENT_BODY)).get("mode", "")),
		EventSheetDocFigures.MODE_FIGURE) and all_passed
	var broken: Dictionary = EventSheetDocFigures.recognize(_fence("eventsheet", HEADERLESS_BODY))
	all_passed = _check("an authored fence that cannot lift is an ERROR, never a quiet code card",
		str(broken.get("mode", "")), EventSheetDocFigures.MODE_ERROR) and all_passed
	all_passed = _check("and the error names the fence's line",
		str(broken.get("error", "")).contains("line 1"), true) and all_passed
	return all_passed


## The two authored markers, which are the whole frozen grammar besides the tag itself.
static func _test_markers() -> bool:
	var all_passed: bool = true
	all_passed = _check("the opt-out marker parses",
		bool(EventSheetDocMarkdown.figure_marker("<!-- no-figure -->").get("no_figure", false)), true) and all_passed
	all_passed = _check("the caption marker parses",
		str(EventSheetDocMarkdown.figure_marker("<!-- caption: Appending to a list -->").get("caption", "")),
		"Appending to a list") and all_passed
	all_passed = _check("an ordinary HTML comment is not a marker",
		EventSheetDocMarkdown.figure_marker("<!-- keep this in sync -->").is_empty(), true) and all_passed

	var opted_out: String = "## Reading a value\n\n<!-- no-figure -->\n```gdscript\n%s```\n" % GOOD_BODY
	var blocks: Array[Dictionary] = EventSheetDocMarkdown.parse(opted_out, "FIXTURE")
	all_passed = _check("the marker is consumed, never shown as prose", blocks.size(), 2) and all_passed
	all_passed = _check("the fence records the opt-out", bool(blocks[1].get("no_figure", false)), true) and all_passed
	all_passed = _check("and the opt-out wins over the automatic layer",
		str(EventSheetDocFigures.recognize(blocks[1]).get("mode", "")),
		EventSheetDocFigures.MODE_CODE) and all_passed

	var captioned: String = "## Reading a value\n\nSome prose.\n\n```gdscript\n%s```\n" % GOOD_BODY
	var heading_blocks: Array[Dictionary] = EventSheetDocMarkdown.parse(captioned, "FIXTURE")
	all_passed = _check("a fence with no caption marker takes the nearest heading",
		str(heading_blocks[2].get("caption", "")), "Reading a value") and all_passed
	var twice: String = "## Use cases\n\n```gdscript\n%s```\n\n```gdscript\n%s```\n" % [GOOD_BODY, GOOD_BODY]
	var twice_blocks: Array[Dictionary] = EventSheetDocMarkdown.parse(twice, "FIXTURE")
	all_passed = _check("the heading captions the FIRST figure under it",
		str(twice_blocks[1].get("caption", "")), "Use cases") and all_passed
	all_passed = _check("and never repeats itself above the second",
		str(twice_blocks[2].get("caption", "")), "") and all_passed
	var explicit: String = "## Reading a value\n\n<!-- caption: Print the value once -->\n```gdscript\n%s```\n" % GOOD_BODY
	var explicit_blocks: Array[Dictionary] = EventSheetDocMarkdown.parse(explicit, "FIXTURE")
	all_passed = _check("an explicit caption wins over the heading",
		str(EventSheetDocFigures.recognize(explicit_blocks[1]).get("caption", "")), "Print the value once") and all_passed
	var authored_caption: String = "<!-- caption: The whole loop -->\n```eventsheet\n%s```\n" % GOOD_BODY
	var authored_blocks: Array[Dictionary] = EventSheetDocMarkdown.parse(authored_caption, "FIXTURE")
	all_passed = _check("the caption marker works above an authored fence too",
		str(EventSheetDocFigures.recognize(authored_blocks[0]).get("caption", "")), "The whole loop") and all_passed
	all_passed = _check("a marker applies to ONE fence only",
		bool(EventSheetDocMarkdown.parse("<!-- no-figure -->\n```gdscript\na\n```\n\n```gdscript\nb\n```\n", "F")[1].get("no_figure", true)),
		false) and all_passed
	return all_passed


## Cropping is DISPLAY only: the gate always ran on the whole body.
static func _test_prelude_crop() -> bool:
	var all_passed: bool = true
	var body: String = "extends CharacterBody2D\n\n\nfunc _ready() -> void:\n\tprint(\"hello\")\n"
	var full: EventSheetResource = EventSheetDocFigures.sheet_for_body(body, false)
	# Guarded, not assumed: sheet_for_body answers null the moment the gate refuses the body, and
	# a lifter change that broke this fixture is exactly the regression this file exists to catch.
	# Indexing a null here would abort the whole file - and a crashed test prints no [FAIL] at all.
	all_passed = _check("the fixture body still lifts", full != null and full.events.size() > 1, true) and all_passed
	if full == null or full.events.size() < 2:
		return false
	all_passed = _check("the full lift keeps the header row",
		full.events[0] is RawCodeRow, true) and all_passed
	all_passed = _check("and that row is the extends line",
		(full.events[0] as RawCodeRow).code.strip_edges(), "extends CharacterBody2D") and all_passed
	var cropped: EventSheetResource = EventSheetDocFigures.sheet_for_body(body)
	all_passed = _check("the cropped lift is still a sheet", cropped != null and not cropped.events.is_empty(), true) and all_passed
	if cropped == null or cropped.events.is_empty():
		return false
	all_passed = _check("the figure drops the header row",
		cropped.events[0] is RawCodeRow, false) and all_passed
	all_passed = _check("and keeps exactly the rows that were the lesson",
		cropped.events.size(), full.events.size() - 1) and all_passed
	all_passed = _check("cropping never changes what the gate ran on",
		EventSheetDocFigures.gate_failure(body), "") and all_passed
	var all_prelude: EventSheetResource = EventSheets.open_gd_as_sheet("extends Node\n")
	all_passed = _check("the all-prelude fixture lifts at all", all_prelude != null, true) and all_passed
	if all_prelude == null:
		return false
	EventSheetDocFigures.crop_prelude_rows(all_prelude)
	all_passed = _check("a body that is ALL prelude keeps its rows (an empty sheet is not a figure)",
		all_prelude.events.is_empty(), false) and all_passed
	return all_passed


## The anti-rot sweep. Every fence the reader will see drawn as rows is drawn here first, and
## every verb those rows name is resolved against the LIVE registry - so a renamed verb, a changed
## template or a broken guide edit fails the suite instead of shipping a hole in a page.
static func _test_corpus() -> bool:
	var all_passed: bool = true
	var registry_ids: Dictionary = _registry_ids()
	all_passed = _check("the live vocabulary is loaded", registry_ids.is_empty(), false) and all_passed
	var errors: PackedStringArray = PackedStringArray()
	var unknown: PackedStringArray = PackedStringArray()
	var stale: PackedStringArray = PackedStringArray()
	var baked: Dictionary = EventSheetDocLibrary.gate_verdicts()
	var compared: int = 0
	var authored: int = 0
	var automatic: int = 0
	for path: String in _corpus_files():
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		for block: Dictionary in EventSheetDocMarkdown.parse(file.get_as_text(), path):
			if str(block.get("kind", "")) != "code":
				continue
			# The bundle ships this verdict so the reader does not pay an import and a compile per
			# fence. Recomputed live just above; if the two ever disagree, the shipped answer is
			# stale and the reader would see a wall of code where a figure used to be.
			var body: String = EventSheetDocFigures.body_of(block)
			var key: String = EventSheetDocFigures.gate_key(body)
			if _is_gatable(str(block.get("language", "")), body):
				if not baked.has(key):
					stale.append("%s line %d: no baked verdict" % [path, int(block.get("line", 0))])
				else:
					compared += 1
					if str(baked[key]) != EventSheetDocFigures.live_capability_failure(body):
						stale.append("%s line %d: baked verdict is not what the lifter says" % [path, int(block.get("line", 0))])
			var verdict: Dictionary = EventSheetDocFigures.recognize(block)
			var mode: String = str(verdict.get("mode", ""))
			if mode == EventSheetDocFigures.MODE_ERROR:
				errors.append("%s %s" % [path, str(verdict.get("error", ""))])
				continue
			if mode != EventSheetDocFigures.MODE_FIGURE:
				continue
			if str(verdict.get("origin", "")) == EventSheetDocFigures.ORIGIN_AUTHORED:
				authored += 1
			else:
				automatic += 1
			var sheet: EventSheetResource = EventSheetDocFigures.sheet_for_body(str(verdict.get("body", "")))
			if sheet == null:
				errors.append("%s line %d: recognized as a figure but produced no sheet" % [path, int(block.get("line", 0))])
				continue
			for verb: String in _verbs_in(sheet):
				if not registry_ids.has(verb):
					unknown.append("%s line %d: %s" % [path, int(block.get("line", 0)), verb])
	for entry: String in errors:
		print("  figure build error: %s" % entry)
	for entry: String in unknown:
		print("  figure names a verb the registry does not offer: %s" % entry)
	for entry: String in stale:
		print("  %s" % entry)
	all_passed = _check("every authored figure in the corpus can be drawn", errors.size(), 0) and all_passed
	all_passed = _check("every figure's verbs resolve in the live vocabulary", unknown.size(), 0) and all_passed
	# Both halves of the bake, in one list: a verdict the bundle forgot (the reader would pay the
	# import and compile in the editor) and a verdict that no longer matches the lifter (the reader
	# would see a wall of code where a figure used to be).
	all_passed = _check("every gatable fence has a baked verdict, and every one still holds", ", ".join(stale), "") and all_passed
	all_passed = _check("and there were verdicts to compare", compared > 0, true) and all_passed
	print("[INFO] doc_figures_test: %d authored + %d automatic figure(s) across the corpus, %d baked verdict(s) rechecked." % [
		authored, automatic, compared])
	return all_passed


## Whether the reader would ever ask this fence's capability question, and therefore whether the
## bundle owes it a baked verdict. The same rule the build step bakes by.
static func _is_gatable(language: String, body: String) -> bool:
	var tag: String = language.strip_edges().to_lower()
	if tag == EventSheetDocFigures.AUTHORED_TAG:
		return true
	return tag == EventSheetDocFigures.AUTO_LANGUAGE and EventSheetDocFigures.has_script_header(body)


## Every guide file, discovered by DIRECTORY so a new doc set is swept by existing.
static func _corpus_files() -> PackedStringArray:
	var files: PackedStringArray = PackedStringArray()
	for directory_path: String in DOC_DIRS:
		var directory: DirAccess = DirAccess.open(directory_path)
		if directory == null:
			continue
		var names: PackedStringArray = directory.get_files()
		names.sort()
		for file_name: String in names:
			if file_name.get_extension().to_lower() == "md":
				files.append(directory_path.path_join(file_name))
	return files


## "provider_id/ace_id" for every verb a figure's rows name, at any depth.
static func _verbs_in(sheet: EventSheetResource) -> PackedStringArray:
	var verbs: PackedStringArray = PackedStringArray()
	for row: Variant in _flatten(sheet.events):
		if not (row is EventRow):
			continue
		var event: EventRow = row as EventRow
		if not event.trigger_id.strip_edges().is_empty():
			verbs.append("%s/%s" % [event.trigger_provider_id, event.trigger_id])
		for condition: Variant in event.conditions:
			if condition is ACECondition:
				verbs.append("%s/%s" % [(condition as ACECondition).provider_id, (condition as ACECondition).ace_id])
		for action: Variant in event.actions:
			if action is ACEAction:
				verbs.append("%s/%s" % [(action as ACEAction).provider_id, (action as ACEAction).ace_id])
	return verbs


static func _flatten(rows: Array) -> Array:
	var out: Array = []
	for row: Variant in rows:
		out.append(row)
		if row is EventRow:
			out.append_array(_flatten((row as EventRow).sub_events))
		elif row is EventGroup:
			out.append_array(_flatten((row as EventGroup).events))
	return out


## "provider_id/ace_id" -> true for the whole builtin vocabulary. Built from the same descriptors
## the editor drops rows from, which is what makes a rename break this test.
static func _registry_ids() -> Dictionary:
	var ids: Dictionary = {}
	for descriptor: ACEDescriptor in ACERegistry.get_all_descriptors():
		ids["%s/%s" % [descriptor.provider_id, descriptor.ace_id]] = true
	return ids


## One parsed fence, as doc_markdown would hand it over.
static func _fence(language: String, body: String) -> Dictionary:
	var lines: Array[String] = []
	for line: String in body.split("\n"):
		lines.append(line)
	if not lines.is_empty() and lines[lines.size() - 1].is_empty():
		lines.remove_at(lines.size() - 1)
	return {"kind": "code", "language": language, "lines": lines, "caption": "", "no_figure": false, "line": 1}


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] doc_figures_test: %s" % label)
		return true
	print("[FAIL] doc_figures_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
