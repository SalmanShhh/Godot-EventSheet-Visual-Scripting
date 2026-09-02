# Godot EventSheets - the idle-costs-nothing budget, asserted on the mechanism.
#
# Behavior packs park their per-frame callback while idle (`set_process(false)` /
# `set_physics_process(false)`), so a stopped behavior costs literally zero frame time. The claim
# lives where frames do: `idle_processing_probe.gd` is run as a subprocess with a real main loop,
# builds a crowd of idle behavior instances plus a handful of running ones, and reads the
# processing FLAGS - never wall-clock time, so nothing here can flake under load. This test runs
# the probe and pins its verdict; a probe that cannot run at all FAILS rather than passing quietly.
@tool
class_name IdleProcessingSmokeTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
## The probe that owns the assertions, run in a process of its own.
const PROBE: String = "res://tests/idle_processing_probe.gd"


static func run() -> bool:
	var output: Array = []
	var arguments: PackedStringArray = PackedStringArray(["--headless", "--path",
		ProjectSettings.globalize_path("res://"), "--script", PROBE])
	OS.execute(OS.get_executable_path(), arguments, output, true)
	var text: String = ""
	for chunk: Variant in output:
		text += "%s\n" % str(chunk)
	var checks: int = -1
	var fails: int = -1
	for line: String in text.split("\n"):
		if not line.begins_with("idle_probe "):
			continue
		for pair: String in line.trim_prefix("idle_probe ").split(" ", false):
			var parts: PackedStringArray = pair.split("=")
			if parts.size() != 2:
				continue
			if parts[0] == "checks":
				checks = int(parts[1])
			elif parts[0] == "fails":
				fails = int(parts[1])
	var passed: bool = _check("the idle processing probe answered", checks > 0, true)
	if not passed:
		print("  the probe printed no result line; its output was:")
		for chunk: Variant in output:
			print("  %s" % str(chunk))
		return false
	if fails > 0:
		for line: String in text.split("\n"):
			if line.begins_with("idle_probe_fail "):
				print("  %s" % line.trim_prefix("idle_probe_fail "))
	return _check("every idle behavior has its callback off (%d checks, %d failed)" % [
		checks, fails], fails, 0) and passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("idle_processing_smoke_test", label, actual, expected)
