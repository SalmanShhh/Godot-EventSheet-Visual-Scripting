# Godot EventSheets - the honest watcher, and the two archive verbs.
#
# Three claims, proven the way the rest of the file vocabulary is proven: the EMITTED text is pinned
# (a shipped template is a compatibility covenant), the BEHAVIOUR is run for real by building the
# emitted lines into a GDScript and calling them, and the BAND is read off a sheet with no canvas.
#
# WHAT IS WORTH TESTING HERE, and why:
#   - THE GUARD IS THE FEATURE. An archive entry names its own path, so an unpack is a write to
#     wherever a stranger's zip says. The test builds a zip holding an entry that climbs out of the
#     target folder, runs the SHIPPED loop over it, and asserts that nothing was written outside, the
#     run stopped, and the refusal said which entry and why. A guard nobody tested is a guard.
#   - THE THREE EVENTS ARE CALLED BY NAME. The loop calls _on_unpack_progress / _on_unpack_refused /
#     _on_unpack_finished, so a sheet with an unpack row and no answer event does not parse. The
#     names are pinned against what the compiler writes for those triggers, in one test, because they
#     are the two halves of one promise.
#   - THE WATCHER IS A POLL AND SAYS SO. The shipped pack is read as text for the two facts that
#     cannot be seen from the picker: it parks its tick when stopped, and it sorts the directory walk
#     (the engine promises no order, and two machines raising events in different orders is the kind
#     of bug that is found once a year). Its diff is then driven for real.
#   - A MODIFIED TIME IS A CLOCK, AND A TEST MAY NOT WAIT ON ONE. A filesystem stamps a file to the
#     nearest second, so rewriting a file inside a test raises nothing. The changed-file case
#     therefore ages the watcher's own last reading rather than sleeping: what is under test is the
#     diff, not the disk's clock.
#   - THE LOOPS OPEN AGAIN. Both archive templates span lines, and a multi-line spelling is not one
#     the reverse index can claim, so an opened file keeps them as verbatim blocks. What is gated is
#     the promise that actually matters: opening such a file and saving it untouched reproduces its
#     bytes.
@tool
class_name WatcherAndArchivesTest
extends RefCounted

const MODULE_PATH := "res://addons/eventforge/registration/modules/file_aces.gd"
const PACK_PATH := "res://eventsheet_addons/folder_watcher/folder_watcher_behavior.gd"

const WORK_DIR := "user://watcher_archives_probe"
const SOURCE_DIR := WORK_DIR + "/source"
const OUT_DIR := WORK_DIR + "/unpacked"
const ARCHIVE := WORK_DIR + "/bundle.zip"
const HOSTILE := WORK_DIR + "/hostile.zip"
const BLOCKED := WORK_DIR + "/blocked.zip"
const BLOCKED_DIR := OUT_DIR + "/taken"
const PROBE_SCRIPT := "user://watcher_archives_probe.gd"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _run_registration() and all_passed
	all_passed = _run_emission() and all_passed
	all_passed = _run_archive_runtime() and all_passed
	all_passed = _run_guard() and all_passed
	all_passed = _run_handlers() and all_passed
	all_passed = _run_lift() and all_passed
	all_passed = _run_watcher_shape() and all_passed
	all_passed = _run_watcher_runtime() and all_passed
	all_passed = _run_band() and all_passed
	_clean()
	if all_passed:
		print("[PASS] watcher_and_archives_test: the honest watcher, and the two archive verbs")
	return all_passed


## The five words register with the ids, kinds and defaults the picker groups them by.
static func _run_registration() -> bool:
	var ok: bool = true
	var by_id: Dictionary = _by_id()
	for ace_id: String in ["PackFolderIntoZip", "UnpackZipIntoFolder", "OnUnpackProgress",
			"OnUnpackRefused", "OnUnpackFinished"]:
		ok = _check("%s is registered" % ace_id, by_id.has(ace_id), true) and ok
		ok = _check("%s groups with the archives" % ace_id, str(by_id[ace_id].category),
			"Files: Archives") and ok
	ok = _check("packing is an action", int(by_id["PackFolderIntoZip"].ace_type),
		int(ACEDescriptor.ACEType.ACTION)) and ok
	ok = _check("unpacking is an action", int(by_id["UnpackZipIntoFolder"].ace_type),
		int(ACEDescriptor.ACEType.ACTION)) and ok
	for ace_id: String in ["OnUnpackProgress", "OnUnpackRefused", "OnUnpackFinished"]:
		ok = _check("%s is an event" % ace_id, int(by_id[ace_id].ace_type),
			int(ACEDescriptor.ACEType.TRIGGER)) and ok
	# A path field says its place - the hint that puts the row on the files band.
	ok = _check("the packed folder says its place", _hint(by_id, "PackFolderIntoZip", "folder"),
		"file_path") and ok
	ok = _check("the archive written says its place", _hint(by_id, "PackFolderIntoZip", "archive"),
		"file_path") and ok
	ok = _check("the archive read says its place", _hint(by_id, "UnpackZipIntoFolder", "archive"),
		"file_path") and ok
	ok = _check("the folder unpacked into says its place",
		_hint(by_id, "UnpackZipIntoFolder", "folder"), "file_path") and ok
	# Defaults are what the row shows the moment it is dropped, so each must stand on its own.
	ok = _check("packing opens on a user:// folder", _default(by_id, "PackFolderIntoZip", "folder"),
		"\"user://runs\"") and ok
	ok = _check("and a user:// archive beside it", _default(by_id, "PackFolderIntoZip", "archive"),
		"\"user://runs.zip\"") and ok
	ok = _check("unpacking opens on a user:// folder", _default(by_id, "UnpackZipIntoFolder", "folder"),
		"\"user://unpacked\"") and ok
	# Every word carries a description, and so does every parameter of it.
	for ace_id: String in ["PackFolderIntoZip", "UnpackZipIntoFolder", "OnUnpackProgress",
			"OnUnpackRefused", "OnUnpackFinished"]:
		ok = _check("%s is described" % ace_id, str(by_id[ace_id].description).length() > 40, true) and ok
		for entry: Variant in by_id[ace_id].params:
			var param: ACEParam = entry as ACEParam
			ok = _check("%s.%s is described" % [ace_id, param.id],
				str(param.description).length() > 20, true) and ok
	return ok


## What the two verbs compile to. The guard is a LINE, and the line is pinned.
static func _run_emission() -> bool:
	var ok: bool = true
	var pack: String = _emitted("PackFolderIntoZip", {"folder": "\"user://runs\"",
		"archive": "\"user://runs.zip\"", "uid": "3"})
	ok = _check("packing uses the engine's own packer",
		pack.contains("var __packer_3 := ZIPPacker.new()"), true) and ok
	ok = _check("and writes nothing when the archive cannot be opened",
		pack.contains("if __packer_3.open(\"user://runs.zip\") == OK:"), true) and ok
	ok = _check("and walks the files in that one folder",
		pack.contains("for __entry_3: String in DirAccess.get_files_at(\"user://runs\"):"), true) and ok
	ok = _check("and closes the archive", pack.contains("__packer_3.close()"), true) and ok

	var unpack: String = _emitted("UnpackZipIntoFolder", {"archive": "\"user://runs.zip\"",
		"folder": "\"user://unpacked\"", "uid": "4"})
	ok = _check("unpacking uses the engine's own reader",
		unpack.contains("var __reader_4 := ZIPReader.new()"), true) and ok
	ok = _check("the folder is made before anything is written into it",
		unpack.contains("DirAccess.make_dir_recursive_absolute(\"user://unpacked\")"), true) and ok
	# THE GUARD, in full. It is compared on REAL paths (a `..` means nothing to res:// or user://
	# until the path is globalized) and the folder keeps its trailing slash, so a target of
	# `user://mods` cannot accept an entry landing in `user://mods_of_mine`.
	ok = _check("the folder is resolved to a real path, with its slash kept",
		unpack.contains("var __root_4 := ProjectSettings.globalize_path(\"user://unpacked\")"
			+ ".simplify_path().trim_suffix(\"/\") + \"/\""), true) and ok
	ok = _check("and every entry is checked against it before a byte is written",
		unpack.contains("if not ProjectSettings.globalize_path(__into_4).simplify_path()"
			+ ".begins_with(__root_4):"), true) and ok
	ok = _check("the guard records the entry and leaves the loop",
		unpack.contains("\t\t\t__refused_4 = __entry_4\n\t\t\tbreak\n"), true) and ok
	# A `return` here would be two bugs at once: a sheet function that answers with a value would
	# not parse, and an ordinary handler would abandon every later row of the same event.
	ok = _check("and it never leaves by returning", unpack.contains("\t\t\treturn\n"), false) and ok
	ok = _check("the archive is closed once, whichever way the loop ended",
		unpack.count("__reader_4.close()"), 1) and ok
	ok = _check("the refusal carries the reason", unpack.contains(
		"_on_unpack_refused(__refused_4, \"it points outside the folder it is being unpacked into\")"),
		true) and ok
	# THE COUNTS ARE WHAT LANDED: both increments and the progress call are inside the write guard,
	# so an entry the machine refused to write moves neither the bar nor the totals.
	ok = _check("the entry count is raised only by a write that succeeded",
		unpack.contains("\t\t\t__file_4.close()\n\t\t\t__written_4 += 1\n\t\t\t__bytes_4"
			+ " += __data_4.size()\n\t\t\t_on_unpack_progress(__written_4, __bytes_4)\n"), true) and ok
	ok = _check("and the run ends at one of the two events, chosen after the loop",
		unpack.contains("\tif __refused_4.is_empty():\n\t\t_on_unpack_finished(__written_4,"
			+ " __bytes_4)\n\telse:\n"), true) and ok
	ok = _check("an entry that is a folder carries no bytes and is skipped",
		unpack.contains("if __entry_4.ends_with(\"/\"):"), true) and ok
	ok = _check("no unsubstituted placeholder survives", unpack.contains("{"), false) and ok
	return ok


## Pack a folder, unpack it again, and compare what came out with what went in.
static func _run_archive_runtime() -> bool:
	var ok: bool = true
	_fresh_dir(SOURCE_DIR)
	_write(SOURCE_DIR + "/one.txt", "first")
	_write(SOURCE_DIR + "/two.txt", "second")
	_run_emitted("PackFolderIntoZip", {"folder": _quote(SOURCE_DIR), "archive": _quote(ARCHIVE),
		"uid": "1"})
	ok = _check("the archive is written", FileAccess.file_exists(ARCHIVE), true) and ok

	_fresh_dir(OUT_DIR)
	var report: Array = _run_emitted("UnpackZipIntoFolder", {"archive": _quote(ARCHIVE),
		"folder": _quote(OUT_DIR), "uid": "1"})
	ok = _check("both files land", FileAccess.get_file_as_string(OUT_DIR + "/one.txt"), "first") and ok
	ok = _check("with the second one's bytes too",
		FileAccess.get_file_as_string(OUT_DIR + "/two.txt"), "second") and ok
	ok = _check("progress was reported once per entry, then the finish",
		_kinds(report), ["progress", "progress", "finished"] as Array) and ok
	ok = _check("the finish counts every entry", report[2][1], 2) and ok
	ok = _check("and every byte", report[2][2], 11) and ok
	ok = _check("the first progress report counts one entry", report[0][1], 1) and ok
	ok = _check("nothing was refused", _kinds(report).has("refused"), false) and ok

	# A WRITE THAT CANNOT SUCCEED. An entry whose name is already a FOLDER in the target cannot be
	# opened for writing on any platform, so this is the portable way to watch the loop meet a write
	# it cannot do. What is under test is the honesty of the numbers: the bar must not move and the
	# finish must not count an entry that never landed.
	_fresh_dir(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(BLOCKED_DIR)
	var packer: ZIPPacker = ZIPPacker.new()
	if packer.open(BLOCKED) != OK:
		print("  [FAIL] watcher_and_archives_test: the blocked archive could not be written")
		return false
	for entry: Array in [["landed.txt", "here"], ["taken", "cannot land"]]:
		packer.start_file(str(entry[0]))
		packer.write_file(str(entry[1]).to_utf8_buffer())
		packer.close_file()
	packer.close()
	var blocked: Array = _run_emitted("UnpackZipIntoFolder", {"archive": _quote(BLOCKED),
		"folder": _quote(OUT_DIR), "uid": "1"})
	ok = _check("the entry that could be written landed",
		FileAccess.get_file_as_string(OUT_DIR + "/landed.txt"), "here") and ok
	ok = _check("the bar moved once, for the one write that happened",
		_kinds(blocked), ["progress", "finished"] as Array) and ok
	ok = _check("and the finish counts the entry that landed and no other",
		blocked[1][1], 1) and ok
	ok = _check("its bytes too, and only its bytes", blocked[1][2], 4) and ok
	DirAccess.remove_absolute(BLOCKED_DIR)
	return ok


## The guard, against an archive whose entry climbs out of the folder it is unpacked into.
static func _run_guard() -> bool:
	var ok: bool = true
	var packer: ZIPPacker = ZIPPacker.new()
	if packer.open(HOSTILE) != OK:
		print("  [FAIL] watcher_and_archives_test: the hostile archive could not be written")
		return false
	# One innocent entry, then one that climbs two folders out of the target and lands beside it.
	for entry: Array in [["safe.txt", "safe"], ["../../escaped.txt", "escaped"]]:
		packer.start_file(str(entry[0]))
		packer.write_file(str(entry[1]).to_utf8_buffer())
		packer.close_file()
	packer.close()

	_fresh_dir(OUT_DIR)
	var escapes_to: String = WORK_DIR.get_base_dir().path_join("escaped.txt")
	var report: Array = _run_emitted("UnpackZipIntoFolder", {"archive": _quote(HOSTILE),
		"folder": _quote(OUT_DIR), "uid": "1"})
	ok = _check("the climbing entry is refused", _kinds(report).has("refused"), true) and ok
	ok = _check("and nothing is written outside the folder",
		FileAccess.file_exists(escapes_to), false) and ok
	ok = _check("the refusal names the entry, spelled as the archive spells it",
		report[report.size() - 1][1], "../../escaped.txt") and ok
	ok = _check("and says why", report[report.size() - 1][2],
		"it points outside the folder it is being unpacked into") and ok
	ok = _check("the run stops there, so no finish is reported",
		_kinds(report).has("finished"), false) and ok
	# The entry BEFORE the bad one landed, which is the honest reading of a stopped unpack: what was
	# written stays written, and the sheet is told where it stopped.
	ok = _check("the entry that came first had already landed",
		FileAccess.get_file_as_string(OUT_DIR + "/safe.txt"), "safe") and ok
	return ok


## The other half of the promise: the compiler writes the three handlers the loop calls by name.
static func _run_handlers() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	for trigger_id: String in ["OnUnpackProgress", "OnUnpackRefused", "OnUnpackFinished"]:
		var row: EventRow = EventRow.new()
		row.trigger_provider_id = "Core"
		row.trigger_id = trigger_id
		var body: RawCodeRow = RawCodeRow.new()
		body.code = "pass"
		row.actions.append(body)
		sheet.events.append(row)
	var compiled: String = str(SheetCompiler.compile(sheet, PROBE_SCRIPT).get("output", ""))
	ok = _check("progress is answered by the function the loop calls",
		compiled.contains("func _on_unpack_progress(entries: int, bytes: int) -> void:"), true) and ok
	ok = _check("refusal too",
		compiled.contains("func _on_unpack_refused(entry: String, reason: String) -> void:"), true) and ok
	ok = _check("and the finish",
		compiled.contains("func _on_unpack_finished(entries: int, bytes: int) -> void:"), true) and ok
	if FileAccess.file_exists(PROBE_SCRIPT):
		DirAccess.remove_absolute(PROBE_SCRIPT)

	# AND THE LOOP FITS IN A FUNCTION THAT ANSWERS WITH A VALUE. The refusal used to leave by
	# `return`, which is a script that does not parse the moment the unpack sits inside a sheet
	# function with a return type - and the compiler reported no error at all, because the emitted
	# text is only checked when Godot reads it. So the whole file is parsed here.
	var answering: EventSheetResource = EventSheetResource.new()
	answering.host_class = "Node"
	for trigger_id: String in ["OnUnpackProgress", "OnUnpackRefused", "OnUnpackFinished"]:
		var answer: EventRow = EventRow.new()
		answer.trigger_provider_id = "Core"
		answer.trigger_id = trigger_id
		var body: RawCodeRow = RawCodeRow.new()
		body.code = "pass"
		answer.actions.append(body)
		answering.events.append(answer)
	var installer: EventFunction = EventFunction.new()
	installer.function_name = "install_pack"
	installer.return_type = TYPE_BOOL
	var unpacking: EventRow = EventRow.new()
	# `{uid}` is baked onto the row when the dock applies it, never by the compiler, so a row built
	# in memory bakes its own - otherwise the placeholder rides into the emitted script.
	var unpack_action: ACEAction = _action("UnpackZipIntoFolder", {"archive": "\"user://mods.zip\"",
		"folder": "\"user://mods\""})
	unpack_action.codegen_template = str(_by_id()["UnpackZipIntoFolder"].codegen_template).replace(
		"{uid}", "9")
	unpacking.actions.append(unpack_action)
	unpacking.actions.append(_action("ReturnValue", {"value": "true"}))
	installer.events.append(unpacking)
	answering.functions.append(installer)
	var answering_output: String = str(SheetCompiler.compile(answering, PROBE_SCRIPT).get("output", ""))
	ok = _check("the unpack sits in a function that answers with a value",
		answering_output.contains("func install_pack() -> bool:"), true) and ok
	var parsed: GDScript = GDScript.new()
	parsed.source_code = answering_output
	ok = _check("and the script Godot is handed actually parses", parsed.reload(), OK) and ok
	if FileAccess.file_exists(PROBE_SCRIPT):
		DirAccess.remove_absolute(PROBE_SCRIPT)
	return ok


## Opening a file that already writes the unpack loop, and saving it again unchanged. A multi-line
## spelling is not one the reverse index claims, so the loop stays a verbatim block - and the block
## re-emits its own bytes, which is the promise the adopt door rests on.
static func _run_lift() -> bool:
	var ok: bool = true
	var body: String = _emitted("UnpackZipIntoFolder", {"archive": "\"user://runs.zip\"",
		"folder": "\"user://unpacked\"", "uid": "1"})
	var indented: PackedStringArray = PackedStringArray()
	for line: String in body.split("\n"):
		indented.append("\t" + line)
	var source: String = "extends Node\n\n\nfunc _ready() -> void:\n" + "\n".join(indented) \
		+ "\n\n\nfunc _on_unpack_progress(entries: int, bytes: int) -> void:\n\tprint(entries, bytes)" \
		+ "\n\n\nfunc _on_unpack_refused(entry: String, reason: String) -> void:\n\tprint(entry, reason)" \
		+ "\n\n\nfunc _on_unpack_finished(entries: int, bytes: int) -> void:\n\tprint(entries, bytes)\n"
	var file: FileAccess = FileAccess.open(PROBE_SCRIPT, FileAccess.WRITE)
	file.store_string(source)
	file.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(PROBE_SCRIPT, false)
	EventSheetACELifter.reset_progress()
	var lifted: bool = EventSheetACELifter.attempt_lift(sheet, source)
	ok = _check("the file opens as events", lifted, true) and ok
	var trigger_ids: Array[String] = []
	for entry: Variant in sheet.events:
		var event_row: EventRow = entry as EventRow
		if event_row != null:
			trigger_ids.append(str(event_row.trigger_id))
	ok = _check("the three answers open as their own events",
		trigger_ids.has("OnUnpackProgress") and trigger_ids.has("OnUnpackRefused")
			and trigger_ids.has("OnUnpackFinished"), true) and ok
	ok = _check("and saving it again reproduces the file byte for byte",
		str(SheetCompiler.compile(sheet, PROBE_SCRIPT).get("output", "")), source) and ok
	DirAccess.remove_absolute(PROBE_SCRIPT)
	return ok


## The shipped watcher pack, read as the text it is: the two facts a picker cannot show.
static func _run_watcher_shape() -> bool:
	var ok: bool = true
	var pack: String = FileAccess.get_file_as_string(PACK_PATH)
	ok = _check("the pack ships", pack.is_empty(), false) and ok
	ok = _check("it names itself the watcher", pack.contains("class_name FolderWatcher"), true) and ok
	ok = _check("a stopped watcher is parked, not visited",
		pack.contains("func stop_watching() -> void:\n\t_watching = false\n\tset_process(false)"),
		true) and ok
	ok = _check("and an unstarted one is parked before anything else",
		pack.contains("func _ready() -> void:"), true) and ok
	ok = _check("the per-frame tick parks itself the moment nothing is being watched",
		pack.contains("if not _watching:\n\t\tset_process(false)\n\t\treturn"), true) and ok
	ok = _check("the interval has a floor, so no answer means a read every frame",
		pack.contains("maxf(look_every_seconds, 0.1)"), true) and ok
	ok = _check("one directory read per look",
		pack.count("DirAccess.get_files_at(watched_folder)"), 1) and ok
	ok = _check("and the walk is sorted, so two machines raise the same events in the same order",
		pack.contains("names.sort()"), true) and ok
	ok = _check("the three events are triggers", pack.count("## @ace_trigger"), 3) and ok
	for signal_name: String in ["file_appeared", "file_changed", "file_removed"]:
		ok = _check("%s hands back a path" % signal_name,
			pack.contains("signal %s(path: String)" % signal_name), true) and ok
	return ok


## The diff, driven for real against a folder on disk.
static func _run_watcher_runtime() -> bool:
	var ok: bool = true
	_fresh_dir(SOURCE_DIR)
	_write(SOURCE_DIR + "/kept.txt", "one")
	_write(SOURCE_DIR + "/ignored.dat", "not a txt")
	var watcher: Node = load(PACK_PATH).new()
	watcher.only_names_like = "*.txt"
	var raised: Array = []
	watcher.file_appeared.connect(func(path: String) -> void: raised.append(["appeared", path]))
	watcher.file_changed.connect(func(path: String) -> void: raised.append(["changed", path]))
	watcher.file_removed.connect(func(path: String) -> void: raised.append(["removed", path]))

	watcher.watch_folder(SOURCE_DIR, 2.0)
	ok = _check("the first look raises nothing - it is the baseline", raised.size(), 0) and ok
	ok = _check("and it is watching", bool(watcher.is_watching()), true) and ok
	ok = _check("the filter is honoured: only the .txt was counted",
		int(watcher.watched_file_count()), 1) and ok
	ok = _check("the folder and interval the row named are what it watches",
		[str(watcher.watched_folder), float(watcher.look_every_seconds)],
		[SOURCE_DIR, 2.0] as Array) and ok

	_write(SOURCE_DIR + "/new.txt", "two")
	watcher.look_now()
	ok = _check("a file that appeared is raised, whole path and all", raised,
		[["appeared", SOURCE_DIR + "/new.txt"]] as Array) and ok

	# A filesystem stamps a file to the nearest second, so rewriting one here would leave the stamp
	# where it was and raise nothing. What is under test is the DIFF, so the watcher's own last
	# reading is aged instead of waiting on the disk's clock.
	raised.clear()
	watcher._seen["kept.txt"] = 0
	watcher.look_now()
	ok = _check("a file whose stamp moved is raised as changed", raised,
		[["changed", SOURCE_DIR + "/kept.txt"]] as Array) and ok

	raised.clear()
	DirAccess.remove_absolute(SOURCE_DIR + "/new.txt")
	watcher.look_now()
	ok = _check("a file that went is raised as removed", raised,
		[["removed", SOURCE_DIR + "/new.txt"]] as Array) and ok

	raised.clear()
	watcher.look_now()
	ok = _check("a look that finds no difference raises nothing", raised.size(), 0) and ok

	watcher.stop_watching()
	ok = _check("stopping stops the watch", bool(watcher.is_watching()), false) and ok
	ok = _check("and parks the per-frame tick", watcher.is_processing(), false) and ok
	watcher.free()
	return ok


## The band: a watch is its own reading, and an archive row lands on the band like any other file row.
static func _run_band() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	var watch: RawCodeRow = RawCodeRow.new()
	watch.code = "$FolderWatcher.watch_folder(\"user://mods\", 2.0)"
	row.actions.append(watch)
	sheet.events.append(row)
	var watches: Array[Dictionary] = EventSheetFileFacts.watched_folders(sheet)
	ok = _check("the watch is one reading", watches.size(), 1) and ok
	ok = _check("naming the folder", str(watches[0].get("folder", "")), "user://mods") and ok
	ok = _check("and the interval, which the path alone cannot say",
		str(watches[0].get("seconds", "")), "2.0") and ok
	var readings: Array[Dictionary] = EventSheetFileFacts.bands(sheet)
	ok = _check("and the band says it in words", str(readings[readings.size() - 1].get("value", "")),
		EventSheetL10n.translate("watching %s every %s s") % ["user://mods", "2.0"]) and ok

	# The same folder watched twice at the same interval is one fact; at two intervals it is two.
	var twice: EventSheetResource = EventSheetResource.new()
	twice.host_class = "Node"
	var repeat: EventRow = EventRow.new()
	repeat.trigger_provider_id = "Core"
	repeat.trigger_id = "OnReady"
	var again: RawCodeRow = RawCodeRow.new()
	again.code = "$FolderWatcher.watch_folder(\"user://mods\", 2.0)\n" \
		+ "$FolderWatcher.watch_folder(\"user://mods\", 2.0)\n" \
		+ "$FolderWatcher.watch_folder(\"user://mods\", 30.0)"
	repeat.actions.append(again)
	twice.events.append(repeat)
	ok = _check("one folder, two intervals, two readings",
		EventSheetFileFacts.watched_folders(twice).size(), 2) and ok

	# And the archive rows: a packed archive is written, an unpacked one is read.
	var archives: EventSheetResource = EventSheetResource.new()
	archives.host_class = "Node"
	var archive_row: EventRow = EventRow.new()
	archive_row.trigger_provider_id = "Core"
	archive_row.trigger_id = "OnReady"
	archive_row.actions.append(_action("PackFolderIntoZip", {"folder": "\"user://runs\"",
		"archive": "\"user://runs.zip\""}))
	archives.events.append(archive_row)
	var archive_bands: Array[Dictionary] = EventSheetFileFacts.bands(archives)
	ok = _check("packing puts both paths on the band", archive_bands.size(), 2) and ok
	ok = _check("the folder it read", str(archive_bands[0].get("value", "")),
		"user://runs - read and written") and ok
	return ok


# -- the pieces ------------------------------------------------------------------------------


## Runs one emitted action for real, inside an object carrying the three answers the loop calls by
## name, and hands back what those answers were told. The text that is pinned is the text that runs.
static func _run_emitted(ace_id: String, params: Dictionary) -> Array:
	var lines: PackedStringArray = PackedStringArray(["@tool", "extends RefCounted", "",
		"var report: Array = []", "", "",
		"func _on_unpack_progress(entries: int, bytes: int) -> void:",
		"\treport.append([\"progress\", entries, bytes])", "", "",
		"func _on_unpack_refused(entry: String, reason: String) -> void:",
		"\treport.append([\"refused\", entry, reason])", "", "",
		"func _on_unpack_finished(entries: int, bytes: int) -> void:",
		"\treport.append([\"finished\", entries, bytes])", "", "",
		"func probe() -> void:"])
	for line: String in _emitted(ace_id, params).split("\n"):
		lines.append("\t" + line)
	var script: GDScript = GDScript.new()
	script.source_code = "\n".join(lines) + "\n"
	if script.reload() != OK:
		print("  [FAIL] watcher_and_archives_test: the emitted %s did not compile" % ace_id)
		return []
	var runner: RefCounted = script.new()
	runner.call("probe")
	return runner.get("report") as Array


## The first word of each thing an unpack reported, in order.
static func _kinds(report: Array) -> Array:
	var kinds: Array = []
	for entry: Variant in report:
		kinds.append(str((entry as Array)[0]))
	return kinds


static func _fresh_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)
	for entry: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(entry))


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


static func _clean() -> void:
	DirAccess.remove_absolute(BLOCKED_DIR)
	for folder: String in [SOURCE_DIR, OUT_DIR, WORK_DIR]:
		for entry: String in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(entry))
		DirAccess.remove_absolute(folder)
	DirAccess.remove_absolute(WORK_DIR.get_base_dir().path_join("escaped.txt"))


static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	return action


static func _emitted(ace_id: String, params: Dictionary) -> String:
	var by_id: Dictionary = _by_id()
	if not by_id.has(ace_id):
		return ""
	return ActionCodegen._apply_template(str(by_id[ace_id].codegen_template), params)


static func _by_id() -> Dictionary:
	var by_id: Dictionary = {}
	for descriptor: ACEDescriptor in load(MODULE_PATH).get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	return by_id


static func _default(by_id: Dictionary, ace_id: String, param_id: String) -> String:
	for param: ACEParam in by_id[ace_id].params:
		if param.id == param_id:
			return str(param.default_value)
	return ""


static func _hint(by_id: Dictionary, ace_id: String, param_id: String) -> String:
	for param: ACEParam in by_id[ace_id].params:
		if param.id == param_id:
			return str(param.hint)
	return ""


## A GDScript string literal for arbitrary text.
static func _quote(text: String) -> String:
	return "\"%s\"" % text.c_escape()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] watcher_and_archives_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
