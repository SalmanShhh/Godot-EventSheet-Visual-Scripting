# Godot EventSheets - the Doctor's long sections give the editor a frame between the scripts they read.
#
# A section that read every script of a project in one go held the editor still for as long as it took,
# four seconds for the mistake checks on a project of two thousand scripts. Each now has a twin that
# takes one script a turn: it must answer exactly what the whole-corpus one answers, and it must offer
# a frame once per script it reads (a count, not a clock, so a slow machine cannot flap it).
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "doctor_turns_test"
const CORPUS: PackedStringArray = [
	"res://demo/showcase/boomer_level/boomer_level.gd",
	"res://demo/showcase/skate_park/skate_park.gd",
	"res://demo/showcase/draw_lab/draw_lab.gd",
]


static func run() -> bool:
	var doctor: GDScript = EventSheetProjectDoctor
	var rows: Array = []

	var before: int = int(doctor.get("breathe_calls"))
	var mistakes_whole: Array[Dictionary] = EventSheetMistakeChecksDoctor.report(CORPUS)
	rows.append(["the whole-corpus mistake report offers no frame", int(doctor.get("breathe_calls")) - before, 0])
	var mistakes_turns: Array[Dictionary] = await EventSheetMistakeChecksDoctor.report_in_turns(CORPUS)
	rows.append(["the mistake report in turns answers the same", mistakes_turns, mistakes_whole])
	rows.append(["and offers a frame for each script it read", int(doctor.get("breathe_calls")) - before, CORPUS.size()])

	var reading_whole: Array[Dictionary] = EventSheetReadingDoctor.report(CORPUS)
	before = int(doctor.get("breathe_calls"))
	var reading_turns: Array[Dictionary] = await EventSheetReadingDoctor.report_in_turns(CORPUS)
	rows.append(["the reading page in turns answers the same", reading_turns, reading_whole])
	rows.append(["and offers a frame for each script it read", int(doctor.get("breathe_calls")) - before, CORPUS.size()])

	var performance_whole: Array[Dictionary] = EventSheetPerformanceDoctor.report(CORPUS)
	before = int(doctor.get("breathe_calls"))
	var performance_turns: Array[Dictionary] = await EventSheetPerformanceDoctor.report_in_turns(CORPUS)
	rows.append(["the performance report in turns answers the same", performance_turns, performance_whole])
	rows.append(["and offers a frame for each script it opened", int(doctor.get("breathe_calls")) - before, mini(CORPUS.size(), EventSheetPerformanceDoctor.MEASURED_LIMIT)])

	# The plugin's own class names are read a few files at a time.
	var clash: GDScript = load("res://addons/eventforge/class_name_clash_doctor.gd")
	clash.set("_plugin_names", {})
	before = int(doctor.get("breathe_calls"))
	var names: Dictionary = await clash.plugin_names()
	var files: int = int(clash.get("_files_read"))
	rows.append(["the plugin's class names are found", names.has("EventSheetProjectDoctor"), true])
	rows.append(["and a frame is offered at least once for every sixteen files read", int(doctor.get("breathe_calls")) - before >= files / 16, true])

	# A family's members are listed once each, in order, however many classes share its base.
	var families: Dictionary = EventSheetFamilyFacts.project_families()
	var tidy: bool = true
	for base: Variant in families:
		var members: PackedStringArray = (families[base] as Dictionary)["members"]
		var sorted: PackedStringArray = members.duplicate()
		sorted.sort()
		var seen: Dictionary = {}
		for member: String in members:
			seen[member] = true
		tidy = tidy and members == sorted and seen.size() == members.size()
	rows.append(["every family lists its members once, sorted", tidy, true])
	rows.append(["and there are families to check", families.size() > 0, true])
	return SUPPORT.pins(P, rows)
