# Godot EventSheets - the parallel launcher's stamped verdict may only answer for one exact tree.
#
# A green run records the working tree's content identity and reprints that verdict on the next
# invocation if the identity still matches. The whole safety of that trade is the identity: it has to
# miss on ANY difference, including a file that git reports by name only (an untracked one) and whose
# content changed underneath the same name. So the launcher answers `-IdentityOnly` with nothing but
# the identity, and this asks it four times around a probe file: created, changed, removed.
#
# The identity is computed by a PowerShell launcher, so the live half of this runs on Windows with
# git reachable and pins the launcher's TEXT everywhere else - the rule is still read on Linux CI,
# just not executed there.
@tool
class_name VerdictStampTest
extends RefCounted

## Runs a second process and creates a file in the repository root, so it wants the machine to
## itself rather than a shard beside seven other Godot processes.
const PARALLEL_UNSAFE := true

const LAUNCHER := "res://tools/run_tests_parallel.ps1"

## An untracked file in the repository root: what git reports by NAME in `status --porcelain`, which
## is exactly the case an identity built from the porcelain alone would answer wrongly for.
const PROBE := "res://verdict_stamp_probe.tmp"

## Phrases the launcher's identity and its two neighbours are built from. Pinned as text so the rule
## is still checked where PowerShell cannot be run.
const REQUIRED_TEXT: Array[String] = [
	"rev-parse HEAD",
	"status --porcelain",
	"diff HEAD",
	"ls-files --others --exclude-standard",
	"Get-FileHash",
	"$stampFile",
	"$lockPath",
	"slowest ten:",
]


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_launcher_builds_the_identity_from_all_four_sources() and ok
	ok = _test_a_touched_file_misses_the_stamp() and ok
	return ok


static func _test_the_launcher_builds_the_identity_from_all_four_sources() -> bool:
	var source: String = FileAccess.get_file_as_string(LAUNCHER)
	var ok: bool = true
	for needle: String in REQUIRED_TEXT:
		if not source.contains(needle):
			print("[FAIL] verdict_stamp_test: the launcher no longer mentions %s" % needle)
			ok = false
	if not source.contains("-Force"):
		print("[FAIL] verdict_stamp_test: the stamp has no -Force escape hatch")
		ok = false
	return ok


static func _test_a_touched_file_misses_the_stamp() -> bool:
	var before: String = _identity()
	if before.is_empty():
		return true  # no PowerShell or no git here; the text pins above are what answers
	var probe: String = ProjectSettings.globalize_path(PROBE)
	var ok: bool = true
	_write(probe, "probe\n")
	var with_probe: String = _identity()
	_write(probe, "probe changed\n")
	var with_changed_probe: String = _identity()
	DirAccess.remove_absolute(probe)
	var after: String = _identity()
	if with_probe == before:
		print("[FAIL] verdict_stamp_test: a new untracked file did not change the tree identity")
		ok = false
	if with_changed_probe == with_probe:
		print("[FAIL] verdict_stamp_test: editing an untracked file did not change the tree identity")
		ok = false
	if after != before:
		print("[FAIL] verdict_stamp_test: the identity did not come back after the probe was removed"
			+ " - expected %s, got %s" % [before, after])
		ok = false
	return ok


## The launcher's own answer for the current tree, or "" when it cannot be asked here.
static func _identity() -> String:
	if OS.get_name() != "Windows":
		return ""
	var output: Array = []
	var arguments: PackedStringArray = PackedStringArray(["-NoProfile", "-File",
		ProjectSettings.globalize_path(LAUNCHER), "-IdentityOnly"])
	if OS.execute("powershell", arguments, output, true) != 0:
		return ""
	return str(output[0] if not output.is_empty() else "").strip_edges()


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()
