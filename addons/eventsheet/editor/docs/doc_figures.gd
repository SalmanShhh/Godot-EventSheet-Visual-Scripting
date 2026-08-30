# EventSheet - EventSheetDocFigures: which fenced block in a guide becomes a LIVE figure.
#
# ONE decision function (recognize) runs per fence, in a fixed precedence order, so there is
# exactly one answer to "why is this a figure?" - and it is the same answer in the reader, in the
# suite and in the build check:
#
#   1. ```eventsheet          the AUTHORED fence. Always a figure. A body that cannot lift is a
#                             NAMED BUILD ERROR pointing at the fence - never a silent code card,
#                             because the author asked for an illustration and got nothing.
#   2. <!-- no-figure -->     the authored opt-OUT. The fence below stays code forever.
#   3. ```gdscript passing the gate   an AUTOMATIC figure. Zero authoring churn: a guide written
#                             in the house style grows figures by existing.
#   4. anything else          a code card, exactly as before.
#
# THE GATE, and why it is what it is. It has three parts, and the third was chosen by measuring
# the whole corpus rather than guessed:
#
#   a. `EventSheets.round_trips(body)` - re-emitting the lift reproduces the fence byte for byte,
#      so a figure can never quietly disagree with the code printed beside it.
#   b. the lift yields at least one row that is not a RawCodeRow - a wall of verbatim code is not
#      an illustration, and round_trips alone says nothing here (re-emitting verbatim code is
#      trivially lossless, so a header-less fragment passes (a) while lifting to nothing).
#   c. the body declares a script header (`extends` / `class_name` / `@tool`).
#
# Part (c) is the tuning. Measured over every ```gdscript fence in docs/, docs/Addons/ and
# docs/Modules/: 526 fences, 114 pass (a)+(b) alone - but most of those 114 are extension-API
# samples (a provider script, an EditorPlugin, a block kind) that a reader must copy into a FILE,
# not rows they would author in a sheet. They lift only because the generic statement catch-alls
# claim any assignment or call. Requiring a script header cuts that to 37, and 30 of the 37 are
# the module guides' worked examples - the fences this feature exists for. Row count does NOT
# discriminate (a "2+ rows" rule keeps 25, mostly the wrong ones, and drops most real figures),
# which is why the conservative variant the plan offered was measured and rejected. The five
# survivors that still read better as code carry <!-- no-figure -->, which is what that marker is
# for.
#
# WHERE THE VERDICT COMES FROM. Answering the gate honestly costs a full import and a compile -
# over 100 ms for a five-line body, and a guide page carries a dozen fences - so the answers are
# BAKED INTO THE BUNDLE at build time, keyed by the hash of the fence body, and the reader looks
# them up instead of recomputing them. The baked half is never trusted blindly: the suite gates
# with `use_prebaked = false` and then compares every baked verdict against the live one, so a
# lifter change that would invalidate them fails the suite rather than showing a wall of code
# where a figure used to be.
#
# The file is STATIC and PURE in the sense that matters: no Control, no Window, no dock. It reads
# the live lifter and the live registry, so it is fully exercised headlessly.
@tool
class_name EventSheetDocFigures
extends RefCounted

## The authored fence tag, and the language an automatic figure is detected in. Both are frozen:
## every guide already written with them is a promise.
const AUTHORED_TAG := "eventsheet"
const AUTO_LANGUAGE := "gdscript"

## What recognize() answers with. A figure is drawn; an error is drawn loudly AND fails the suite;
## code is the card the reader has always had.
const MODE_FIGURE := "figure"
const MODE_CODE := "code"
const MODE_ERROR := "error"

## Where a figure verdict came from, for a test (and a build report) that needs to tell the two
## layers apart without re-deriving them.
const ORIGIN_AUTHORED := "authored"
const ORIGIN_AUTOMATIC := "automatic"

## The line prefixes that make a body a whole little script rather than a fragment. A doc comment
## or a plain comment above them is still a header line - guides open with one constantly.
const HEADER_PREFIXES := ["extends ", "class_name ", "@tool", "@icon", "@abstract", "@static_unload"]


## The one decision, for one parsed fence block (see doc_markdown.gd for the block shape).
## Always returns the same keys, so a caller reads `mode` and then what it needs:
##   {mode, origin, caption, body, error}
## `error` is filled only for MODE_ERROR, and it names the fence's own line so a build report can
## point at it.
static func recognize(block: Dictionary) -> Dictionary:
	var verdict: Dictionary = {"mode": MODE_CODE, "origin": "", "caption": "", "body": "", "error": ""}
	if str(block.get("kind", "")) != "code":
		return verdict
	var body: String = body_of(block)
	verdict["body"] = body
	verdict["caption"] = str(block.get("caption", ""))
	var language: String = str(block.get("language", "")).strip_edges().to_lower()
	if language == AUTHORED_TAG:
		# The header rule is the AUTOMATIC layer's tuning - a way to tell a sheet example from an
		# extension-API sample when nobody said which it was. An author who tagged the fence said
		# which it was, so the tag drops that rule and keeps the two the renderer actually needs.
		var reason: String = gate_failure(body, false)
		if reason.is_empty():
			verdict["mode"] = MODE_FIGURE
			verdict["origin"] = ORIGIN_AUTHORED
			return verdict
		verdict["mode"] = MODE_ERROR
		verdict["error"] = "line %d: an ```%s fence cannot be drawn as rows - %s" % [
			int(block.get("line", 0)), AUTHORED_TAG, reason,
		]
		return verdict
	if bool(block.get("no_figure", false)):
		return verdict
	if language != AUTO_LANGUAGE:
		return verdict
	if not gate_failure(body).is_empty():
		return verdict
	verdict["mode"] = MODE_FIGURE
	verdict["origin"] = ORIGIN_AUTOMATIC
	return verdict


## A fence body as one string, exactly as the author wrote it (the gate is a BYTE comparison, so
## nothing here may normalise it).
static func body_of(block: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for line: Variant in (block.get("lines", []) as Array):
		lines.append(str(line))
	if lines.is_empty():
		return ""
	return "\n".join(lines) + "\n"


## Capability verdicts, keyed by the HASH OF THE BODY and nothing else. The header rule is not in
## the key on purpose: it is a pure string test the caller re-runs for free, while the capability
## question behind it costs a full import AND a compile. Keying the two together is what made every
## automatic figure pay that price twice (once recognised, once drawn) on the same body.
static var _gate_cache: Dictionary = {}

## Whether the verdicts baked into the shipped bundle may answer. TRUE for a reader, because the
## alternative is a page that stalls for a second or more the first time it is opened. FALSE for
## the suite, which has to ask the LIVE lifter or its whole anti-rot job evaporates - and which
## then compares the two, so a baked verdict can never quietly disagree with the code.
static var use_prebaked: bool = true


## "" when `body` can be drawn as rows, and the human reason when it cannot. Written as the reason
## rather than a bool because the authored path has to SAY what went wrong: an author who tagged a
## fence deserves to know whether it was the round trip or the lift that refused it.
static func gate_failure(body: String, require_header: bool = true) -> String:
	if body.strip_edges().is_empty():
		return "the fence is empty"
	if require_header and not has_script_header(body):
		return "it has no script header (an `extends`, `class_name` or `@tool` line), so it is a fragment rather than a sheet"
	return capability_failure(body)


## Whether the body CAN be drawn at all, ignoring whether it should be. Memoised, and answered from
## the bundle's baked verdicts when it can be: a cold verdict measured over 100 ms on a five-line
## body, and a guide page carrying a dozen fences paid that on the click that opened it.
static func capability_failure(body: String) -> String:
	var key: String = body.sha256_text()
	if _gate_cache.has(key):
		return str(_gate_cache[key])
	var baked: Dictionary = EventSheetDocLibrary.gate_verdicts() if use_prebaked else {}
	var reason: String = str(baked[key]) if baked.has(key) else live_capability_failure(body)
	_gate_cache[key] = reason
	return reason


## The verdict computed from the ground up, by the lifter and the compiler that ship today. This is what
## the build step bakes and what the suite compares against; nothing else should call it.
static func live_capability_failure(body: String) -> String:
	if body.strip_edges().is_empty():
		return "the fence is empty"
	if not EventSheets.round_trips(body):
		return "re-emitting the rows would not reproduce the code byte for byte"
	var sheet: EventSheetResource = EventSheets.open_gd_as_sheet(body)
	if lifted_row_count(sheet) <= 0:
		return "every line stayed verbatim code - there are no rows to draw"
	return ""


## The key a body's baked verdict is filed under. One definition, so the build step and the reader
## cannot disagree about what "the same fence" means.
static func gate_key(body: String) -> String:
	return body.sha256_text()


## Drops the memoised verdicts, for a test that changes the vocabulary under itself.
static func clear_gate_cache() -> void:
	_gate_cache.clear()


## True when the body opens like a script file rather than a fragment. Comments and blank lines
## are skipped; the first line of actual code decides.
static func has_script_header(body: String) -> bool:
	for line: String in body.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.is_empty() or stripped.begins_with("#"):
			continue
		for prefix: String in HEADER_PREFIXES:
			if stripped.begins_with(prefix):
				return true
		return false
	return false


## How many top-level rows the lift produced that are NOT verbatim code. The measure the gate's
## second half is written against.
static func lifted_row_count(sheet: EventSheetResource) -> int:
	if sheet == null:
		return 0
	var count: int = 0
	for row: Variant in sheet.events:
		if not (row is RawCodeRow):
			count += 1
	return count


## The sheet a figure draws, or null when the body cannot be drawn. `crop_prelude` drops the
## leading `extends` / `class_name` / `@tool` row from the DISPLAY - the guide's prose already
## established the host, and scaffolding is not the lesson. Cropping never changes what the gate
## ran on: the gate runs on the whole body, above, before this is ever called.
static func sheet_for_body(body: String, crop_prelude: bool = true) -> EventSheetResource:
	# Asked WITHOUT the header rule: whether a body can be drawn is a capability question, and
	# whether it should be is the recognizer's, already answered by the time anyone gets here.
	if not gate_failure(body, false).is_empty():
		return null
	var sheet: EventSheetResource = EventSheets.open_gd_as_sheet(body)
	if sheet == null:
		return null
	if crop_prelude:
		crop_prelude_rows(sheet)
	return sheet


## Drops the leading verbatim rows that are nothing but a script header. MUTATES `sheet`, which is
## safe by construction: every sheet a figure draws is lifted fresh for that figure. A sheet that
## is ALL prelude keeps its rows - an empty sheet would raise the viewport's getting-started
## overlay, whose call-to-action buttons are real click targets.
static func crop_prelude_rows(sheet: EventSheetResource) -> void:
	if sheet == null:
		return
	var first_kept: int = 0
	while first_kept < sheet.events.size():
		var row: Variant = sheet.events[first_kept]
		if not (row is RawCodeRow) or not _is_prelude_code((row as RawCodeRow).code):
			break
		first_kept += 1
	if first_kept <= 0 or first_kept >= sheet.events.size():
		return
	sheet.events = sheet.events.slice(first_kept)


## True when a verbatim row carries nothing but header lines and blanks.
static func _is_prelude_code(code: String) -> bool:
	var saw_header: bool = false
	for line: String in code.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.is_empty() or stripped.begins_with("#"):
			continue
		var is_header: bool = false
		for prefix: String in HEADER_PREFIXES:
			if stripped.begins_with(prefix):
				is_header = true
				break
		if not is_header:
			return false
		saw_header = true
	return saw_header
