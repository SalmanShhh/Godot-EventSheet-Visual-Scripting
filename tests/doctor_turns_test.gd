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
	# A sheet is judged a stage at a time, so a frame is offered between the stages as well as between the scripts.
	rows.append(["and offers a frame for each script it read, and between the stages of each", int(doctor.get("breathe_calls")) - before >= CORPUS.size() * 2, true])

	var reading_whole: Array[Dictionary] = EventSheetReadingDoctor.report(CORPUS)
	before = int(doctor.get("breathe_calls"))
	var reading_turns: Array[Dictionary] = await EventSheetReadingDoctor.report_in_turns(CORPUS)
	rows.append(["the reading page in turns answers the same", reading_turns, reading_whole])
	rows.append(["and offers a frame for each script it read", int(doctor.get("breathe_calls")) - before, CORPUS.size()])

	var performance_whole: Array[Dictionary] = EventSheetPerformanceDoctor.report(CORPUS)
	before = int(doctor.get("breathe_calls"))
	var performance_turns: Array[Dictionary] = await EventSheetPerformanceDoctor.report_in_turns(CORPUS)
	rows.append(["the performance report in turns answers the same", performance_turns, performance_whole])
	# A sheet's rows are read a turn at a time as well, so a frame is offered for each script and more besides.
	rows.append(["and offers a frame for each script it opened", int(doctor.get("breathe_calls")) - before >= mini(CORPUS.size(), EventSheetPerformanceDoctor.MEASURED_LIMIT), true])

	# The renames and collisions sections, and the Ship it page, in turns: the same report, a frame a script.
	var renames_paths: PackedStringArray = PackedStringArray(CORPUS)
	var renames_whole: Array[Dictionary] = EventSheetRenameDoctor.report(renames_paths)
	before = int(doctor.get("breathe_calls"))
	var renames_turns: Array[Dictionary] = await EventSheetRenameDoctor.report_in_turns(renames_paths)
	rows.append(["the renames report in turns answers the same", renames_turns, renames_whole])
	rows.append(["and offers a frame for each sheet it read", int(doctor.get("breathe_calls")) - before, CORPUS.size()])
	var collisions_whole: Array[Dictionary] = EventSheetCollisionsDoctor.report(CORPUS)
	var collisions_ranked: PackedStringArray = await EventSheetCollisionsDoctor.ranked_in_turns(CORPUS)
	rows.append(["the collisions ranking in turns is the ranking", collisions_ranked, EventSheetCollisionsDoctor.ranked(CORPUS)])
	rows.append(["the collisions report in turns answers the same", await EventSheetCollisionsDoctor.report_in_turns(collisions_ranked), collisions_whole])
	var shipped_sources: Dictionary = {}
	for corpus_path: String in CORPUS:
		shipped_sources[corpus_path] = FileAccess.get_file_as_string(corpus_path)
	shipped_sources["res://made_up_console.gd"] = "extends Node\n\n\nfunc _ready() -> void:\n\tprint(tr(\"hello\"))\n\tprint(\"debug\")\n"
	rows.append(["the Ship it page in turns answers the same", await EventSheetShipItDoctor.report_in_turns(shipped_sources), EventSheetShipItDoctor.report(shipped_sources)])
	rows.append(["the collision layers report in turns answers the same", await EventSheetCollisionLayerDoctor.report_in_turns(CORPUS), EventSheetCollisionLayerDoctor.report(CORPUS)])
	rows.append(["the dashes sweep in turns finds the same scripts", await EventSheetShapesDoctor.scripts_scrolling_dashes_in_turns(), EventSheetShapesDoctor.scripts_scrolling_dashes()])
	rows.append(["the tool sweep in turns finds the same scripts", await EventSheetToolEditsDoctor.scene_editing_tools_in_turns(), EventSheetToolEditsDoctor.scene_editing_tools()])
	# The checks that walk every script, in turns: the same findings.
	for check_name: String in ["check_generated_outputs", "check_debug_residue", "check_untranslated_project", "check_save_key_symmetry",
			"check_unsaved_rebindings", "check_background_thread_safety", "check_imported_rows"]:
		var whole: Array[Dictionary] = []
		var turns: Array[Dictionary] = []
		doctor.call(check_name, PackedStringArray(CORPUS), whole)
		await doctor.call(check_name + "_in_turns", PackedStringArray(CORPUS), turns)
		rows.append(["%s in turns answers the same" % check_name, turns, whole])
	var menu_whole: Array[Dictionary] = []
	var menu_turns: Array[Dictionary] = []
	doctor.check_menu_ids(menu_whole)
	await doctor.check_menu_ids_in_turns(menu_turns)
	rows.append(["check_menu_ids in turns answers the same", menu_turns, menu_whole])
	# The sheet judged a stage at a time is judged the same.
	var staged_sheet: EventSheetResource = EventSheetGDScriptImporter.new().import_external(CORPUS[0])
	rows.append(["the mistake findings of a sheet in turns are the same findings",
		await EventSheetMistakeFindings.findings_in_turns(staged_sheet, CORPUS[0], doctor.breathe),
		EventSheetMistakeFindings.findings(staged_sheet, CORPUS[0])])

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
