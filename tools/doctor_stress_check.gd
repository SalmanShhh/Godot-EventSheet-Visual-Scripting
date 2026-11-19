# Godot EventSheets - does the editor's way of running the Project Doctor give the same answer every time?
#
#   godot --headless --path . --script tools/doctor_stress_check.gd
#   godot --headless --path . --script tools/doctor_stress_check.gd -- runs=20
#
# The audit's text-only stretches run on worker threads while the main thread draws, and the tables those
# workers read (the texts held for the audit, the compiled patterns) are shared. A race there would not fail
# every run; it would change a finding, or lose one, now and then. So this runs the audit all at once once, to
# have the answer, and then the editor's way - a slice at a time, workers and all - `runs` times (default 10),
# comparing every finding of every run, in order, byte for byte, against that answer. It prints one line,
# `stress check: same (N runs, M findings each)` or `stress check: DIFFERENT`, then the run that differed and
# the first finding that did, and exits 1 when any run differs.
#
# Two sections - Interop and Performance - read a few scripts within a wall-clock budget and say how many
# they read, so their answer depends on the machine's speed that minute; they are left out of the comparison.
# A suite test cannot do this (the suite has no frames to wait for), so it is a tool, like
# `doctor_sliced_check.gd`, which runs the same comparison once and says how long the sliced run took.
@tool
extends SceneTree


func _init() -> void:
	_go()


func _go() -> void:
	await process_frame
	var runs: int = 10
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("runs="):
			runs = maxi(1, int(argument.trim_prefix("runs=")))
	var options: Dictionary = {"known_only": true}
	var whole: Dictionary = EventSheetProjectDoctor.run(options)
	var expected: PackedStringArray = _lines(whole)
	var differing: int = 0
	for run_number: int in range(runs):
		await EventSheetProjectDoctor.prime_listing(self, Callable())
		var session: Dictionary = EventSheetProjectDoctor.begin(options)
		var sliced: Dictionary = await EventSheetProjectDoctor.run_sliced(session, self, Callable(), Callable())
		var got: PackedStringArray = _lines(sliced)
		if got != expected:
			differing += 1
			print("run %d differed: %d findings, expected %d" % [run_number + 1, got.size(), expected.size()])
			for index: int in range(maxi(got.size(), expected.size())):
				var a: String = expected[index] if index < expected.size() else "<none>"
				var b: String = got[index] if index < got.size() else "<none>"
				if a != b:
					print("  first difference at %d:\n    expected: %s\n    got:      %s" % [index, a.left(200), b.left(200)])
					break
	if differing == 0:
		print("stress check: same (%d runs, %d findings each)" % [runs, expected.size()])
	else:
		print("stress check: DIFFERENT (%d of %d runs)" % [differing, runs])
	quit(1 if differing > 0 else 0)


## Two sections measure a few scripts within a wall-clock budget and say how many they read, so they are set aside.
func _is_timed(check_id: String) -> bool:
	return check_id == "interop" or check_id == "interop-script" or check_id == "interop-adopt" or check_id.begins_with("performance")


## Every finding as one line, in order, the timed sections' set aside, then the counts of what was compared.
func _lines(report: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var counts: Dictionary = {"error": 0, "warning": 0, "info": 0}
	for finding: Dictionary in (report.get("findings", []) as Array):
		if _is_timed(str(finding.get("check", ""))):
			continue
		counts[str(finding.get("severity"))] = int(counts.get(str(finding.get("severity")), 0)) + 1
		lines.append("%s|%s|%s|%s|%s|%s" % [finding.get("severity"), finding.get("check"), finding.get("path"),
			finding.get("event", 0), finding.get("subject", ""), finding.get("message")])
	lines.append("doctor: %d error(s), %d warning(s), %d note(s)" % [int(counts["error"]), int(counts["warning"]), int(counts["info"])])
	return lines
