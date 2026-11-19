# Godot EventSheets - does the editor's way of running the Project Doctor give the command line's answer?
#
#   godot --headless --path . --script tools/doctor_sliced_check.gd
#
# The audit runs two ways: all at once (the command line, CI, the tests) and a few milliseconds at a time
# on a running editor, with the listing, the reading and the opening of sheets done on worker threads. They
# must say the same thing. This runs both over the project it is pointed at - `known_only` in both, the way
# the editor asks - and compares every finding, in order, and the counts line. It prints one line,
# `sliced check: same` or `sliced check: DIFFERENT`, then the first difference and every line one run has that
# the other has not, and exits 1 when they differ.
#
# Two sections - Interop and Performance - read a few scripts within a wall-clock budget and say how many they read,
# so their answer depends on the machine's speed that minute; they are set aside from the comparison and counted.
#
# A suite test cannot do this (the suite has no frames to wait for), so it is a tool: run it on this
# repository and on a project with every kind of finding.
@tool
extends SceneTree


func _init() -> void:
	_go()


func _go() -> void:
	await process_frame
	var options: Dictionary = {"known_only": true}
	# The sliced run goes FIRST, in a fresh process, so every lazily built cache it reads is built the way the editor
	# builds it (on a worker, from the held listing) and not left warm by the whole run.
	var started: int = Time.get_ticks_msec()
	await EventSheetProjectDoctor.prime_listing(self, Callable())
	var session: Dictionary = EventSheetProjectDoctor.begin(options)
	var sliced: Dictionary = await EventSheetProjectDoctor.run_sliced(session, self, Callable(), Callable())
	var sliced_ms: int = Time.get_ticks_msec() - started
	var whole: Dictionary = EventSheetProjectDoctor.run(options)
	var left: PackedStringArray = _lines(whole)
	var right: PackedStringArray = _lines(sliced)
	var same: bool = left == right
	print("sliced check: %s (%d findings whole, %d sliced; counts %d/%d/%d and %d/%d/%d; sliced run %d ms)" % [
		"same" if same else "DIFFERENT", left.size(), right.size(),
		int(whole["errors"]), int(whole["warnings"]), int(whole["infos"]),
		int(sliced["errors"]), int(sliced["warnings"]), int(sliced["infos"]), sliced_ms])
	if not same:
		for index: int in range(maxi(left.size(), right.size())):
			var a: String = left[index] if index < left.size() else "<none>"
			var b: String = right[index] if index < right.size() else "<none>"
			if a != b:
				print("first difference at %d:\n  whole:  %s\n  sliced: %s" % [index, a, b])
				break
		var shown_whole: int = 0
		var shown_sliced: int = 0
		for line: String in left:
			if not right.has(line) and shown_whole < 25:
				shown_whole += 1
				print("only in the whole run: %s" % line.left(220))
		for line: String in right:
			if not left.has(line) and shown_sliced < 25:
				shown_sliced += 1
				print("only in the sliced run: %s" % line.left(220))
	quit(0 if same else 1)


## Two sections measure a few scripts "within a wall-clock budget" and say how many they read, so what they report
## depends on how fast the machine was that minute: they are set aside from this comparison (and counted).
func _is_timed(check_id: String) -> bool:
	return check_id == "interop" or check_id == "interop-script" or check_id == "interop-adopt" or check_id.begins_with("performance")


## One line per finding, in the order the report holds them, with the counts of what is compared last.
func _lines(report: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var counts: Dictionary = {"error": 0, "warning": 0, "info": 0}
	var set_aside: int = 0
	for finding: Dictionary in (report["findings"] as Array):
		if _is_timed(str(finding.get("check", ""))):
			set_aside += 1
			continue
		counts[str(finding.get("severity"))] = int(counts.get(str(finding.get("severity")), 0)) + 1
		lines.append("%s|%s|%s|%s|%s|%s" % [finding.get("severity"), finding.get("check"), finding.get("path"),
			finding.get("event", 0), finding.get("subject", ""), finding.get("message")])
	lines.append("doctor: %d error(s), %d warning(s), %d note(s)" % [int(counts["error"]), int(counts["warning"]), int(counts["info"])])
	print("  (%d finding(s) of the two timed sections set aside from the comparison)" % set_aside)
	return lines
