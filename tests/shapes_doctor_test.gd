# Godot EventSheets - the Doctor's Shapes section: a shape marched with no dashes to march.
#
# Two fixture pairs, both real files, and the pins read both directions on the same rule. The HUD
# scene dashes its reticle in the Inspector and leaves its range ring plain, so one of its two
# Scroll Dashes rows is the mistake and the other is not - which is the pin that matters, because a
# check that reported both would be a check reporting the word rather than the shape. The answered
# scene has the same plain ring with a Set Dashes row above the scroll, and says nothing at all.
#
# THE SILENCES ARE THE POINT. A target the section cannot resolve, a shape it cannot find in a
# scene, a speed of zero and a sheet no scene uses each have a pin of their own, because the failure
# this section can actually cause is not a missed line - it is a line on a shape that was fine.
@tool
class_name ShapesDoctorTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PREFIX := "shapes_doctor_test"

## The sheet that marches a dashed reticle and a plain range ring, and the one that answers for its
## ring with a Set Dashes row above the scroll.
const HUD := "res://tests/fixtures/shapes_scene_hud.gd"
const ANSWERED := "res://tests/fixtures/shapes_scene_answered.gd"


static func run() -> bool:
	var all_passed: bool = true
	# From cold, so what the section says here is what it says in a fresh editor rather than what an
	# earlier test happened to leave in the project caches.
	_drop_the_project_caches()
	all_passed = _pin_the_targets() and all_passed
	all_passed = _pin_one_sheet() and all_passed
	all_passed = _pin_the_section() and all_passed
	# The section asks the scene index which scenes use a script, which walks the project and leaves
	# caches warm. CI runs the whole suite serially in ONE process, so anything left warm here is
	# inherited by every later test that pins what a cold project answers.
	_drop_the_project_caches()
	return all_passed


## The reading of a target out of an emitted line, which is the whole of what this section parses.
## Pinned as VALUES rather than through a file, so a spelling it cannot resolve is named here rather
## than showing up later as a silence somebody has to explain.
static func _pin_the_targets() -> bool:
	return SUPPORT.pins(PREFIX, [
		["the targets a sheet scrolls, in the order it writes them",
			",".join(EventSheetShapesDoctor.scrolled_targets(
				"\t$Reticle.scroll_dashes(2.0)\n\t%Ring.scroll_dashes(speed)\n")), "$Reticle,%Ring"],
		["a stopped scroll is not a scroll", ",".join(EventSheetShapesDoctor.scrolled_targets(
			"\t$Reticle.scroll_dashes(0.0)\n")), ""],
		["and neither is the pack's own declaration of the verb",
			",".join(EventSheetShapesDoctor.scrolled_targets("func scroll_dashes(speed: float) -> void:\n")), ""],
		["nor the annotation that spells the row's template, which a substring test cannot tell apart",
			",".join(EventSheetShapesDoctor.scrolled_targets(
				"## @ace_codegen_template(\"$VectorShape2D.scroll_dashes({patterns_per_second})\")\n")), ""],
		["a target named twice is named once", ",".join(EventSheetShapesDoctor.scrolled_targets(
			"\t$Ring.scroll_dashes(1.0)\n\t$Ring.scroll_dashes(2.0)\n")), "$Ring"],
		["a node path resolves to its last step",
			EventSheetShapesDoctor._node_name_of("$Hud/Aim/Reticle"), "Reticle"],
		["a scene-unique name resolves to itself", EventSheetShapesDoctor._node_name_of("%Ring"), "Ring"],
		["and a target that is not a node path resolves to nothing at all",
			EventSheetShapesDoctor._node_name_of("held_line"), ""],
	])


## One sheet's findings: which of its two scrolled shapes is reported, in which words.
static func _pin_one_sheet() -> bool:
	var hud: Array[Dictionary] = EventSheetShapesDoctor.script_findings(HUD)
	var answered: Array[Dictionary] = EventSheetShapesDoctor.script_findings(ANSWERED)
	return SUPPORT.pins(PREFIX, [
		["the plain ring is the one reported", _subjects(hud), "$RangeRing"],
		["and the reticle, dashed in the scene, is left alone", str(_subjects(hud).contains("Reticle")), "false"],
		["the note says which shape, which scene, and both ways out",
			str(hud[0].get("message", "")) if not hud.is_empty() else "",
			"shapes_scene_hud.gd marches the dashes on $RangeRing, and that shape has none to march: its Dashed box is off in shapes_scene_hud.tscn, and no row here turns it on. Turn Dashed on in the Inspector, or put a Set Dashes row before the Scroll Dashes."],
		["it points at the sheet to open", str(hud[0].get("path", "")) if not hud.is_empty() else "", HUD],
		["and it is a warning, not an error",
			str(hud[0].get("severity", "")) if not hud.is_empty() else "", "warning"],
		["a Set Dashes row above the scroll answers for the same plain ring", _subjects(answered), ""],
		["a sheet no scene uses is never reported",
			_subjects(EventSheetShapesDoctor.script_findings("res://tests/fixtures/lighting_scene_room.gd")), ""],
	])


## The section: registered exactly once through the public seam, leading with its summary, and
## silent on a corpus with nothing in it.
static func _pin_the_section() -> bool:
	EventSheetShapesDoctor.ensure_registered()
	var registered: int = 0
	for entry: Dictionary in EventSheetProjectDoctor._extension_checks:
		if str(entry.get("id", "")) == EventSheetShapesDoctor.CHECK_ID:
			registered += 1
	var report: Array[Dictionary] = EventSheetShapesDoctor.report(PackedStringArray([HUD, ANSWERED]))
	return SUPPORT.pins(PREFIX, [
		# Registering twice would run the section twice; the seam replaces by id, and this is what
		# proves it.
		["the section is registered through the public seam, exactly once", registered, 1],
		["it leads with a summary counting the sheets and the troubled ones",
			str(report[0].get("message", "")) if not report.is_empty() else "",
			"Shapes: 2 sheet(s) march a shape's dashes, 1 of them on a shape whose dashes are off."],
		["the summary is a note and the finding under it is a warning", _severities(report), "info,warning"],
		["and every line is filed under the check its kind is", _checks(report),
			"shapes,shapes-scroll-without-dashes"],
		["a project with no shape scrolled in it reports nothing at all",
			EventSheetShapesDoctor.report(PackedStringArray()).size(), 0],
	])


## The three the section warms, dropped together: what this project's scenes are, what its scripts
## are, and who uses whom.
static func _drop_the_project_caches() -> void:
	EventSheetProjectShareIndex.clear_cache()
	EventSheetSceneConnections.clear_cache()
	EventSheetProjectDoctor.clear_project_scripts()


static func _subjects(findings: Array[Dictionary]) -> String:
	var subjects: PackedStringArray = PackedStringArray()
	for finding: Dictionary in findings:
		subjects.append(str(finding.get("subject", "")))
	return ",".join(subjects)


static func _severities(findings: Array[Dictionary]) -> String:
	var severities: PackedStringArray = PackedStringArray()
	for finding: Dictionary in findings:
		severities.append(str(finding.get("severity", "")))
	return ",".join(severities)


static func _checks(findings: Array[Dictionary]) -> String:
	var checks: PackedStringArray = PackedStringArray()
	for finding: Dictionary in findings:
		checks.append(str(finding.get("check", "")))
	return ",".join(checks)
