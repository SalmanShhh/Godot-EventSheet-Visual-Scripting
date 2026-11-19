# EventSheets - the Project Doctor's disk work on worker threads gives the answers the main thread gave.
#
# An audit in the editor lists the project, reads the scripts and opens the sheets on worker threads so
# the window keeps drawing. None of that may change what the audit says: this pins each piece against the
# plain way it was always done - the walks against the walks, the `.tres` header against `load()`, the
# threaded reads against direct reads, a sheet opened on the worker against one opened here, the page
# order against the order the old sort gave - and that stopping a worker leaves nothing running.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "doctor_background_test"
const ProjectFiles := preload("res://addons/eventforge/project_files.gd")
const ProjectListing := preload("res://addons/eventforge/project_listing.gd")
const BACKGROUND := preload("res://addons/eventforge/doctor_background.gd")
const PREFETCH := preload("res://addons/eventforge/doctor_sheet_prefetch.gd")


static func run() -> bool:
	var rows: Array = []
	rows.append_array(_walk_rows())
	rows.append_array(_sheet_listing_rows())
	rows.append_array(_read_rows())
	rows.append_array(_prefetch_rows())
	rows.append_array(_page_rows())
	rows.append_array(_audit_state_rows())
	return SUPPORT.pins(P, rows)


static func _wait(job: RefCounted) -> void:
	while job.is_running():
		OS.delay_msec(2)


## Every walk the audit makes, served from a held listing, is the walk made on the disk.
static func _walk_rows() -> Array:
	var rows: Array = []
	var cases: Array = [
		[PackedStringArray(["addons"]), ".gd"],
		[PackedStringArray(["addons", "eventsheet_addons"]), ".gd"],
		[PackedStringArray(["addons", "tests"]), ".tscn"],
		[PackedStringArray(["addons"]), ".tres"],
		[PackedStringArray(), ".md"],
	]
	var disk: Array = []
	for held: Array in cases:
		var suffix: String = held[1]
		disk.append(ProjectFiles.walk(held[0], func(path: String) -> bool: return path.ends_with(suffix)))
	var references_on_disk: PackedStringArray = EventSheetFindReferences.project_scripts()
	ProjectFiles.hold(ProjectListing.new(ProjectListing.list_everything()))
	for index: int in range(cases.size()):
		var held: Array = cases[index]
		var suffix: String = held[1]
		var from_listing: PackedStringArray = ProjectFiles.walk(held[0], func(path: String) -> bool: return path.ends_with(suffix))
		rows.append(["a walk of %s skipping %s is the same from the held listing" % [suffix, ", ".join(held[0])], from_listing, disk[index]])
	rows.append(["the scripts the references window lists are the same from the held listing",
		EventSheetFindReferences.project_scripts(), references_on_disk])
	ProjectFiles.hold(null)
	rows.append(["a walk after the audit is the disk's again", ProjectFiles.held_listing() == null, true])
	return rows


## The `.tres` sheets named by their first line are the ones `load()` calls sheets.
static func _sheet_listing_rows() -> Array:
	var by_load: PackedStringArray = EventSheetProjectFind.list_project_sheets()
	var verdicts: Dictionary = {}
	for entry: Variant in ProjectListing.list_everything():
		var directory_path: String = (entry as Array)[0]
		if ProjectListing.inside_skipped(directory_path, ProjectFiles.PLUGIN_DIRECTORIES):
			continue
		for file_name: String in ((entry as Array)[1] as PackedStringArray):
			if file_name.ends_with(".tres"):
				verdicts[directory_path.path_join(file_name)] = BACKGROUND._verdict_of(directory_path.path_join(file_name))
	var named: PackedStringArray = PackedStringArray()
	var paths: Array = verdicts.keys()
	paths.sort()
	for path: Variant in paths:
		var verdict: int = int(verdicts[path])
		if verdict == BACKGROUND.SHEET_YES or (verdict == BACKGROUND.SHEET_UNSURE and load(str(path)) is EventSheetResource):
			named.append(str(path))
	return [["the sheets the headers name are the sheets load() names", named, by_load]]


## The texts the workers read are the texts a direct read gives, and a stopped reader leaves nothing running.
static func _read_rows() -> Array:
	var scripts: PackedStringArray = ProjectFiles.all_scripts().slice(0, 60)
	var job: RefCounted = BACKGROUND.new()
	var started: bool = job.start_reading(scripts)
	_wait(job)
	var texts: Dictionary = job.finish_reading()
	var same: int = 0
	for path: String in scripts:
		if texts.get(path, null) == FileAccess.get_file_as_string(path):
			same += 1
	var stopped: RefCounted = BACKGROUND.new()
	stopped.start_reading(ProjectFiles.all_scripts())
	stopped.stop()
	_wait(stopped)
	stopped.finish_reading()
	return [
		["the reader started", started, true],
		["every text read on a worker is the text read directly", same, scripts.size()],
		["a stopped reader has no thread left running", stopped.is_running(), false],
	]


## A sheet opened on the worker is the sheet opened here, and a worker told to stop leaves the lifter free.
static func _prefetch_rows() -> Array:
	var paths: PackedStringArray = PackedStringArray([
		"res://tests/fixtures/canvas_dialog_reading_fixture.gd", "res://tests/fixtures/handwritten_state_patrol.gd"])
	var open_job_class: GDScript = load("res://addons/eventforge/importer/open_job.gd")
	var job: RefCounted = PREFETCH.new()
	var started: bool = job.begin(paths, open_job_class)
	_wait(job)
	var finished: Dictionary = job.finish(open_job_class)
	var sheets: Dictionary = finished["sheets"]
	var same: int = 0
	for path: String in paths:
		var here: EventSheetResource = EventSheetGDScriptImporter.new().import_external(path)
		var there: EventSheetResource = sheets.get(path, null) as EventSheetResource
		if here != null and there != null and str(EventSheetCompiler.echo(here).get("output", "")) == str(EventSheetCompiler.echo(there).get("output", "")):
			same += 1
	var stopped: RefCounted = PREFETCH.new()
	stopped.begin(paths, open_job_class)
	stopped.preempt()
	var stopped_alone: bool = not stopped.is_running()
	stopped.finish(open_job_class)
	return [
		["the worker started", started, true],
		["every script finished says what finishing it here says", same, paths.size()],
		["all of them were finished", int(finished["done"]), paths.size()],
		["a worker the reader's own open preempted has stopped", stopped_alone, true],
		["and the lifter is no longer asked to stop", EventSheetACELifter.cancel_requested, false],
		["and nothing is left to preempt", open_job_class.preempt_background.is_valid(), false],
	]


## The page the inbox draws: the same order and marks as the sort it replaced, in one frame or in many.
static func _page_rows() -> Array:
	var findings: Array = []
	var checks: PackedStringArray = PackedStringArray(["unused", "files", "reading", "tidy"])
	for number: int in range(240):
		var finding: Dictionary = {"severity": ["info", "warning", "error"][number % 3],
			"check": checks[number % 4], "path": "res://s%d.gd" % (number % 17),
			"message": "m%d" % ((number * 7) % 31), "subject": "s%d" % (number % 5)}
		if number % 40 == 0:
			finding["order"] = "reading|%04d" % number
		findings.append(finding)
	var seen: PackedStringArray = PackedStringArray([EventSheetDoctorInbox.identity(findings[3]), EventSheetDoctorInbox.identity(findings[50])])
	var page: Array[Dictionary] = EventSheetDoctorInbox.triage(findings, seen)
	var reference: Array[Dictionary] = _triage_as_it_was(findings, seen)
	var identities: PackedStringArray = EventSheetDoctorInbox.identities_of(page)
	var tree_whole: Tree = Tree.new()
	EventSheetProjectDoctorPanel.fill_inbox(tree_whole, tree_whole.create_item(), page)
	var tree_turns: Tree = Tree.new()
	var filler: Object = EventSheetProjectDoctorPanel.InboxFill.new(tree_turns, tree_turns.create_item(), page)
	var turns: int = 0
	while not filler.step(1):
		turns += 1
	var result: Array = [
		["the page has the order and the marks the old sort gave", _shape(page), _shape(reference)],
		["its identities are listed once each and sorted", identities.size() <= page.size() and _is_sorted(identities), true],
		["a page laid in turns is the page laid at once", _rows_of(tree_turns), _rows_of(tree_whole)],
		["and it did take more than one turn", turns > 1, true],
	]
	tree_whole.free()
	tree_turns.free()
	return result


static func _shape(page: Array[Dictionary]) -> PackedStringArray:
	var shape: PackedStringArray = PackedStringArray()
	for finding: Dictionary in page:
		shape.append("%s|%s|%s" % [EventSheetDoctorInbox.identity(finding), str(finding.get("message")), str(finding.get("is_new"))])
	return shape


static func _is_sorted(names: PackedStringArray) -> bool:
	for index: int in range(1, names.size()):
		if names[index - 1] > names[index]:
			return false
	return true


static func _rows_of(tree: Tree) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var branch: TreeItem = tree.get_root().get_first_child()
	while branch != null:
		out.append("%s|%s" % [branch.get_text(1), branch.get_text(3)])
		var item: TreeItem = branch.get_first_child()
		while item != null:
			out.append("%s|%s|%s|%s|%s" % [item.get_text(1), item.get_text(2), item.get_text(3), str(item.get_metadata(3)), str(item.get_metadata(0))])
			item = item.get_next()
		branch = branch.get_next()
	return out


## The page as the inbox built it before the sort keys were made once: a comparison that builds both keys.
static func _triage_as_it_was(findings: Array, seen: PackedStringArray) -> Array[Dictionary]:
	var sorted: Array[Dictionary] = []
	for finding: Variant in findings:
		sorted.append((finding as Dictionary).duplicate())
	sorted.sort_custom(EventSheetDoctorInbox._before)
	var out: Array[Dictionary] = []
	for finding: Dictionary in sorted:
		var entry: Dictionary = finding.duplicate()
		entry["identity"] = EventSheetDoctorInbox.identity(finding)
		entry["is_new"] = not seen.has(str(entry["identity"]))
		out.append(entry)
	return out


## What an audit in progress keeps, and what a question asked twice over the same scripts pays for.
static func _audit_state_rows() -> Array:
	var doctor: GDScript = EventSheetProjectDoctor
	var source_cache: Dictionary = doctor.get("_source_cache")
	source_cache["res://probe_kept.gd"] = "text"
	doctor.set("_run_in_progress", true)
	# The editor's filesystem hook arrives as often as a file is saved: it does not empty an audit half way through.
	doctor.clear_project_scripts()
	var kept_in_audit: bool = (doctor.get("_source_cache") as Dictionary).has("res://probe_kept.gd")
	doctor.clear_project_scripts(true)
	var dropped_when_forced: bool = not (doctor.get("_source_cache") as Dictionary).has("res://probe_kept.gd")
	doctor.set("_run_in_progress", false)
	(doctor.get("_source_cache") as Dictionary)["res://probe_kept.gd"] = "text"
	doctor.clear_project_scripts()
	var dropped_outside: bool = not (doctor.get("_source_cache") as Dictionary).has("res://probe_kept.gd")
	# A question over scripts' text answers the same held or not, and holds nothing outside an audit.
	var scripts: PackedStringArray = ProjectFiles.all_scripts().slice(0, 40)
	var says_extends: Callable = func(text: String) -> bool: return text.contains("extends Node")
	var direct: PackedStringArray = PackedStringArray()
	for path: String in scripts:
		if FileAccess.get_file_as_string(path).contains("extends Node"):
			direct.append(path)
	var outside: PackedStringArray = doctor.gate("probe", scripts, says_extends)
	var held_outside: int = (doctor.get("_gate_memo") as Dictionary).size()
	doctor.set("_run_in_progress", true)
	var first: PackedStringArray = doctor.gate("probe", scripts, says_extends)
	var second: PackedStringArray = doctor.gate("probe", scripts, says_extends)
	var held_in_audit: int = (doctor.get("_gate_memo") as Dictionary).size()
	doctor.set("_run_in_progress", false)
	(doctor.get("_gate_memo") as Dictionary).clear()
	(doctor.get("_source_cache") as Dictionary).clear()
	return [
		["an audit in progress keeps what it has read when the filesystem hook fires", kept_in_audit, true],
		["and the next audit begins from nothing", dropped_when_forced, true],
		["outside an audit the hook still empties it", dropped_outside, true],
		["a gate answers what asking each script does, outside an audit", outside, direct],
		["and holds nothing there", held_outside, 0],
		["inside an audit it answers the same, first and again", first == direct and second == direct, true],
		["and holds the answer once", held_in_audit, 1],
	]
