# Godot EventSheets - the "saved" badge reads save keys without compiling the Project Doctor.
#
# The badge asks which variables the Save System keeps on the first row build of any sheet whose
# source mentions `save_`. That question used to `load()` the whole Project Doctor, which is about six
# seconds of GDScript compile on a cold editor (health pack: 6.1 s, 5.5 - 6.7 over three fresh
# processes). It is read from `save_key_scan.gd` now: 9 ms (9 - 12) in a fresh process.
#
# Three pins:
#   * VALUE: the small reader and the Doctor answer identically for every shipped pack that touches
#     a save, so a badge and a finding can never disagree.
#   * STRUCTURAL: the badge's source names the small reader and never the Doctor. (That the Doctor
#     stays out of the loaded set while a saving sheet opens is pinned in a fresh process by
#     `cold_boot_probe.gd`, read by huge_project_budget_test; inside the suite the Doctor is always
#     compiled by an earlier test, so only the source can be asked here.)
#   * WALL: a cold `saved_names` of a saving pack, at about 6x the measured figure because the
#     number is small enough for machine noise to matter; the regression it catches costs seconds.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "save_names_badge_test"
const MARKS_SCRIPT: String = "res://addons/eventsheet/editor/interaction/native_variable_marks.gd"
const SCAN_SCRIPT: String = "res://addons/eventforge/save_key_scan.gd"
const SAVING_PACK: String = "res://eventsheet_addons/health/health_behavior.gd"
const SAVE_NAMES_BUDGET_MS: float = 60.0


static func run() -> bool:
	var passed: bool = true
	var marks_source: String = FileAccess.get_file_as_string(MARKS_SCRIPT)
	passed = SUPPORT.check(P, "the badge reads save keys from the small reader",
		marks_source.contains(SCAN_SCRIPT), true) and passed
	passed = SUPPORT.check(P, "the badge never names the Doctor",
		marks_source.contains("project_doctor"), false) and passed

	var scan: Script = load(SCAN_SCRIPT)
	var source: String = FileAccess.get_file_as_string(SAVING_PACK)
	var from_scan: Dictionary = scan.call("save_key_usage", source)
	passed = SUPPORT.check(P, "the Doctor and the small reader agree on the health pack",
		EventSheetProjectDoctor.save_key_usage(source), from_scan) and passed
	for sample: String in ["save_value(\"coins\", 3)\nvar x = load_number(\"coins\")",
			"# save_value(\"commented\", 1)\nfunc save_state():\n\treturn {\"hp\": 1}",
			"__remember_cfg.set_value(\"vars\", \"speed\", 1)"]:
		passed = SUPPORT.check(P, "the Doctor and the small reader agree on a sample",
			EventSheetProjectDoctor.save_key_usage(sample), scan.call("save_key_usage", sample)) and passed

	var marks: Script = load(MARKS_SCRIPT)
	marks.set("_saved_cache", {})
	var start_usec: int = Time.get_ticks_usec()
	var names: Dictionary = marks.call("saved_names", SAVING_PACK)
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	passed = SUPPORT.check(P, "saved_names answers for a saving pack (names=%d)" % names.size(),
		names.is_empty(), false) and passed
	passed = SUPPORT.check(P, "a cold saved_names costs under %.0f ms (took %.1f ms)" % [SAVE_NAMES_BUDGET_MS, elapsed_ms],
		elapsed_ms <= SAVE_NAMES_BUDGET_MS, true) and passed
	return passed
