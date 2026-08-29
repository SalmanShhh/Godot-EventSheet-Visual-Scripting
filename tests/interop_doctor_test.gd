# The Doctor's Interop section: what the plugin understood, and what it was told to leave alone.
#
# The section answers the one question somebody slotting this into an existing game actually has -
# "where should I start?" - and its opposite, which matters just as much: a script marked to stay
# code is never measured, never counted and never offered anything. The mark is a comment line, so
# the decision lives in the file rather than in anything this plugin remembers.
#
# The score gates nothing. These pins are about the section saying true things, in order, cheaply.
@tool
class_name InteropDoctorTest
extends RefCounted

const CORPUS: Array[String] = [
	"res://tests/fixtures/interop_corpus/player.gd",
	"res://tests/fixtures/interop_corpus/pickup.gd",
	"res://tests/fixtures/interop_corpus/solver.gd",
]

const SOLVER: String = "res://tests/fixtures/interop_corpus/solver.gd"
const PLAYER: String = "res://tests/fixtures/interop_corpus/player.gd"
const PICKUP: String = "res://tests/fixtures/interop_corpus/pickup.gd"


static func run() -> bool:
	var ok: bool = true
	# From cold, so what the section says here is what it says in a fresh editor rather than what an
	# earlier test happened to leave in the project caches.
	_drop_the_project_caches()

	# ── The mark, read off the file ─────────────────────────────────────────────────────────
	ok = _check("a marked script says so", EventSheetInteropDoctor.stays_code(SOLVER), true) and ok
	ok = _check("an unmarked one does not", EventSheetInteropDoctor.stays_code(PLAYER), false) and ok
	ok = _check("and a nameless question is not a mark",
		EventSheetInteropDoctor.stays_code(""), false) and ok
	# The mark has to survive the plugin being uninstalled, which means it has to be a comment.
	ok = _check("the mark is a comment line",
		EventSheetInteropDoctor.STAYS_CODE_MARK.begins_with("#"), true) and ok

	# ── One script's facts ──────────────────────────────────────────────────────────────────
	var player: Dictionary = EventSheetInteropDoctor.adoption(PLAYER)
	ok = _check("a measured script names itself", str(player.get("path", "")), PLAYER) and ok
	ok = _check("with the functions that opened as functions", int(player.get("lifted", 0)), 3) and ok
	ok = _check("and none of them still sitting as code", int(player.get("verbatim", -1)), 0) and ok
	ok = _check("and the share of it that reads as rows", int(player.get("reads_as", 0)), 100) and ok

	# ── The section itself ──────────────────────────────────────────────────────────────────
	var findings: Array[Dictionary] = EventSheetInteropDoctor.report(PackedStringArray(CORPUS))
	ok = _check("the summary leads the section",
		str(findings[0].get("check", "")) if not findings.is_empty() else "",
		EventSheetInteropDoctor.CHECK_ID) and ok
	ok = _check("and says installing changed nothing",
		str(findings[0].get("message", "")).contains("changed nothing") if not findings.is_empty() else false,
		true) and ok
	ok = _check("and counts the marked file out of the candidates",
		str(findings[0].get("message", "")).contains("2 script(s)") if not findings.is_empty() else false,
		true) and ok
	ok = _check("every line is advisory - the score gates nothing",
		_severities(findings), PackedStringArray(["info"])) and ok
	# Best candidate first: the script that already reads as rows is the one to open next.
	ok = _check("the measured scripts are sorted best candidate first",
		_measured_paths(findings), PackedStringArray([PLAYER, PICKUP])) and ok
	ok = _check("and the marked one is listed as left alone, not as a candidate",
		_stays_code_paths(findings), PackedStringArray([SOLVER])) and ok
	ok = _check("a corpus with nothing in it reports nothing",
		EventSheetInteropDoctor.report(PackedStringArray()).size(), 0) and ok

	# The section asks the project index how many other files call each function, which starts the
	# project-wide scan and leaves three caches warm. Continuous integration runs the whole suite
	# serially in ONE process, so anything left warm here is inherited by every later test that pins
	# what a cold project answers - and the sharded local run, which puts them in other processes,
	# would never show it.
	_drop_the_project_caches()
	return ok


## The three the section warms, dropped together. They are one question asked three ways - what this
## project's scenes are, what its scripts are, and who calls whom - so they are also dropped as one.
static func _drop_the_project_caches() -> void:
	EventSheetProjectShareIndex.clear_cache()
	EventSheetSceneConnections.clear_cache()
	EventSheetProjectDoctor.clear_project_scripts()


static func _severities(findings: Array[Dictionary]) -> PackedStringArray:
	var seen: PackedStringArray = PackedStringArray()
	for finding: Dictionary in findings:
		var severity: String = str(finding.get("severity", ""))
		if not seen.has(severity):
			seen.append(severity)
	return seen


static func _measured_paths(findings: Array[Dictionary]) -> PackedStringArray:
	return _paths_of(findings, EventSheetInteropDoctor.CHECK_SCRIPT)


static func _stays_code_paths(findings: Array[Dictionary]) -> PackedStringArray:
	return _paths_of(findings, EventSheetInteropDoctor.CHECK_STAYS_CODE)


static func _paths_of(findings: Array[Dictionary], check_id: String) -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	for finding: Dictionary in findings:
		if str(finding.get("check", "")) == check_id:
			paths.append(str(finding.get("path", "")))
	return paths


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] interop_doctor_test: %s" % label)
		return true
	print("[FAIL] interop_doctor_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
