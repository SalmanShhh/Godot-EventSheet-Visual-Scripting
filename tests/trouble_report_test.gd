# EventForge - the two answers to "why is my game doing that?"
#
#   ASKING THE SHEET   "Why didn't this fire?" gained the two facts it could not say before: what
#                      the run counted for the row itself, and what the REST of the sheet does to
#                      the group it sits in. Both are facts. Neither is a sentence joining them
#                      into a cause, because the panel does not know which of them mattered.
#   THE GAME TELLING   On Something Went Wrong is the first thing here that works in a BUILD: the
#                      compiler declares the signal, arms a logger with the engine, and the row
#                      handles the report. So this pins what is emitted, and - just as important -
#                      that a sheet without the trigger emits not one line of it.
@tool
class_name TroubleReportTest
extends RefCounted

const OUT_PATH := "user://__eventsheets_trouble_probe.gd"


static func run() -> bool:
	var all_passed: bool = true
	EventSheetRunProfile.forget()
	all_passed = _run_why_facts() and all_passed
	all_passed = _run_emission() and all_passed
	EventSheetRunProfile.forget()
	if all_passed:
		print("[PASS] trouble_report_test: the run's facts in the why panel, and the shipped error trigger")
	return all_passed


# ── 1. What the why panel can say now ─────────────────────────────────────────────────────
static func _run_why_facts() -> bool:
	var all_passed: bool = true
	EventSheetRunProfile.forget()
	var row: EventRow = EventRow.new()
	row.trigger_id = "OnHurt"
	row.conditions.append(_condition("hp <= 0"))

	# With no run at all there is no count to report, and a count nobody took is not a zero.
	all_passed = _check("no run means no trigger line", EventSheetWhyPanel.trigger_line(row), "") and all_passed
	all_passed = _check("and the menu says what to do about that",
		EventSheetContextMenus.why_label(),
		"Why didn't this fire? Run the game first, then ask") and all_passed

	EventSheetRunProfile.adopt_run_for_test(row.event_uid, 12, 12, 12000, "an earlier run")
	all_passed = _check("the menu goes back to the question once there is a run",
		EventSheetContextMenus.why_label(), "Why didn't this fire?") and all_passed
	all_passed = _check("a trigger that arrived is cleared of it, with the count",
		EventSheetWhyPanel.trigger_line(row),
		"The trigger ran 12 times (last run, an earlier run) - it is not the trigger.") and all_passed

	var never: EventRow = EventRow.new()
	never.trigger_id = "OnDoubleJump"
	never.conditions.append(_condition("hp <= 0"))
	all_passed = _check("a trigger that never arrived IS the answer",
		EventSheetWhyPanel.trigger_line(never),
		"The trigger never ran at all (last run, an earlier run) - so nothing below it was ever asked.") and all_passed

	# The cross-reference: what the rest of the sheet does to the group this row sits in.
	var group: EventGroup = EventGroup.new()
	group.name = "Damage"
	group.runtime_toggleable = true
	group.events.append(row)
	var switcher: EventRow = EventRow.new()
	switcher.actions.append(_action("SetGroupActive", {"group": "\"Damage\"", "active": "false"}))
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.events.append(group)
	sheet.events.append(switcher)
	all_passed = _check("the report says who can switch the group off",
		EventSheetWhyPanel.cross_references(sheet, row),
		PackedStringArray(["The Damage group it is in can be switched off while the game runs, and a row switches it off."])) and all_passed

	group.enabled = false
	all_passed = _check("a group switched off at authoring is the plainer fact",
		EventSheetWhyPanel.cross_references(sheet, row),
		PackedStringArray(["The Damage group it is in is switched off, so none of its rows are compiled at all."])) and all_passed
	group.enabled = true
	group.runtime_toggleable = false
	all_passed = _check("an ordinary group is nothing to report",
		EventSheetWhyPanel.cross_references(sheet, row), PackedStringArray()) and all_passed

	# The Watch button names the value the blocking condition was about, and nothing when nothing
	# said no - a button that watches "" is a button that does nothing.
	var report: Dictionary = EventSheetWhyPanel.build_report(row, {"hp": 40}, true, sheet)
	all_passed = _check("the watchable name is the blocker's own",
		EventSheetWhyPanel.watchable_name(report), "hp") and all_passed
	var passing: Dictionary = EventSheetWhyPanel.build_report(row, {"hp": -1}, true, sheet)
	all_passed = _check("nothing said no, nothing to watch",
		EventSheetWhyPanel.watchable_name(passing), "") and all_passed
	EventSheetRunProfile.forget()
	return all_passed


# ── 2. What the trigger emits, and what a sheet without it does not ───────────────────────
static func _run_emission() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.custom_class_name = "TroubleProbe"
	var quiet: String = str(SheetCompiler.compile(sheet, OUT_PATH).get("output", ""))
	all_passed = _check("a sheet that never asks emits no signal",
		quiet.contains("something_went_wrong"), false) and all_passed
	all_passed = _check("and no logger", quiet.contains("Logger"), false) and all_passed

	var row: EventRow = EventRow.new()
	row.trigger_id = "OnSomethingWentWrong"
	row.actions.append(_action("Core/RawLine", {}, "print({report})"))
	(row.actions[0] as ACEAction).params = {"report": "report"}
	(row.actions[0] as ACEAction).codegen_template = "print({report})"
	sheet.events.append(row)
	var built: String = str(SheetCompiler.compile(sheet, OUT_PATH).get("output", ""))
	all_passed = _check("the channel is declared",
		built.contains("signal something_went_wrong(report: String)"), true) and all_passed
	all_passed = _check("the handler takes the report",
		built.contains("func _on_something_went_wrong(report: String) -> void:"), true) and all_passed
	all_passed = _check("and is wired to the signal",
		built.contains("something_went_wrong.connect(_on_something_went_wrong)"), true) and all_passed
	all_passed = _check("the reporter is a logger the ENGINE gets, not the debugger",
		built.contains("class __EventSheetsTroubleReporter extends Logger:"), true) and all_passed
	all_passed = _check("armed with no debugger test at all - a build has no debugger",
		built.contains("\tOS.add_logger(__trouble)"), true) and all_passed
	all_passed = _check("each failing line is said once per run",
		built.contains("\t\tif _said.has(location):"), true) and all_passed
	all_passed = _check("and the report carries where it happened",
		built.contains("\"%s (%s)\" % [message, location]"), true) and all_passed
	all_passed = _check("the row's own action is in the handler", built.contains("print(report)"), true) and all_passed
	all_passed = _check("the emitted script parses", _parses(built), true) and all_passed

	# A second compile of the QUIET sheet must be quiet again: the flag is per-compile scratch, and a
	# flag left standing is how one file's compile changes what an unrelated file opens as.
	sheet.events.clear()
	var quiet_again: String = str(SheetCompiler.compile(sheet, OUT_PATH).get("output", ""))
	all_passed = _check("the flag does not survive into the next compile",
		quiet_again.contains("something_went_wrong"), false) and all_passed
	return all_passed


## True when a string of GDScript is real GDScript. Written to user:// and loaded, because the
## engine's own parser is the only oracle worth asking.
static func _parses(source: String) -> bool:
	var file: FileAccess = FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(source)
	file.close()
	var script: GDScript = GDScript.new()
	script.source_code = source
	return script.reload() == OK


static func _condition(expression: String) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "TestCondition"
	condition.codegen_template = expression
	return condition


static func _action(ace_id: String, params: Dictionary, template: String = "") -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	action.codegen_template = template
	return action


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] trouble_report_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
