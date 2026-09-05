# Godot EventSheets - the safe name, the free path, the door back to the desktop, and the one check
# that draws the line between a file and a program.
#
# Three of the four are small and are pinned the way every verb is: the exact emitted line, the exact
# category, and a run of the compiled script that proves the line does what the row says.
#
# The fourth is the Doctor's trust boundary, and it is pinned BOTH WAYS on purpose. A check that only
# ever saw its own bug fixture would be a check that reports every project; a check that only ever saw
# clean code would be one that reports none. So every shape below appears twice: once with an outside
# path reaching `load()`, and once with the same doors reaching a reader that answers with data. The
# hand-written spellings are in the same list as the emitted ones, because the reading is over TEXT
# and there is no third thing for it to be.
@tool
class_name SafeNamesAndOutsideContentTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_DIR := "user://__safe_name_test"

## The two paths this test compiles TO. A compile writes its output where it is told, so these are
## files on the machine that ran the suite and belong in the clean-up like anything else it wrote.
const COMPILE_OUTPUTS: Array[String] = [
	"user://__safe_name_gen.gd", "user://__safe_name_round_trip.gd",
]


static func run() -> bool:
	var ok: bool = true
	ok = _vocabulary() and ok
	ok = _runs_on_disk() and ok
	ok = _round_trips() and ok
	ok = _doctor_finds_the_bug() and ok
	ok = _doctor_leaves_clean_code_alone() and ok
	ok = _doctor_says_the_risk_and_the_doors() and ok
	# LAST, not half way through. The round trip above compiles after the on-disk half has tidied
	# up after itself, so a clean-up that only ran there left the round trip's own output behind.
	_cleanup()
	return ok


## The three new rows: their kinds, their places in the picker, and their exact emitted lines.
static func _vocabulary() -> bool:
	var ok: bool = true
	var by_id: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	for ace_id: String in ["SafeFileName", "FreeFilePath", "ShowInFileManager"]:
		ok = _check("registered: %s" % ace_id, by_id.has(ace_id), true) and ok
	if not (by_id.has("SafeFileName") and by_id.has("FreeFilePath") and by_id.has("ShowInFileManager")):
		return false

	var safe: ACEDescriptor = by_id["SafeFileName"]
	ok = _check("the safe name ANSWERS, so it is an expression",
		safe.ace_type, ACEDescriptor.ACEType.EXPRESSION) and ok
	ok = _check("the safe name is the engine's own validate_filename, in its own brackets",
		str(safe.codegen_template),
		"{?fallback}({/fallback}({name}).validate_filename().lstrip(\".\")"
		+ "{?fallback} if not ({name}).validate_filename().lstrip(\".\").is_empty()"
		+ " else {fallback}){/fallback}") and ok
	ok = _check("the safe name's fallback is the second slot",
		(safe.params[1] as ACEParam).id, "fallback") and ok

	var free: ACEDescriptor = by_id["FreeFilePath"]
	ok = _check("the free path ANSWERS, so it is an expression",
		free.ace_type, ACEDescriptor.ACEType.EXPRESSION) and ok
	ok = _check("the free path reads its path expression exactly once",
		str(free.codegen_template).count("{path}"), 1) and ok
	ok = _check("the free path's ceiling is a slot on the row",
		str(free.codegen_template).contains("range(1, ({at_most}) + 1)"), true) and ok
	ok = _check("the free path numbers before the extension, with no stray dot",
		str(free.codegen_template).contains(
			"__wanted.get_basename() + \"_\" + str(__number)"
			+ " + __wanted.trim_prefix(__wanted.get_basename())"), true) and ok

	var show: ACEDescriptor = by_id["ShowInFileManager"]
	ok = _check("showing the file DOES something, so it is an action",
		show.ace_type, ACEDescriptor.ACEType.ACTION) and ok
	ok = _check("showing the file is the engine's own desktop call",
		str(show.codegen_template),
		"OS.shell_show_in_file_manager(ProjectSettings.globalize_path({path}))") and ok
	ok = _check("showing the file says desktop only",
		str(show.description).contains("DESKTOP ONLY"), true) and ok
	for ace_id: String in ["SafeFileName", "FreeFilePath", "ShowInFileManager"]:
		var descriptor: ACEDescriptor = by_id[ace_id]
		ok = _check("%s is filed under Files" % ace_id, str(descriptor.category), "Files") and ok
		for parameter: ACEParam in descriptor.params:
			ok = _check("%s.%s says what it is for" % [ace_id, parameter.id],
				str(parameter.description).length() > 20, true) and ok
	return ok


## The save event a player meets: one trigger, three deeds. The name they typed is made safe, the
## path is moved off one that is taken, and the file is written there.
static func _runs_on_disk() -> bool:
	var ok: bool = true
	var by_id: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	_cleanup()
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var taken: FileAccess = FileAccess.open("%s/my_run.txt" % TEST_DIR, FileAccess.WRITE)
	taken.store_string("the first one")
	taken.close()

	var safe_name: String = str(by_id["SafeFileName"].codegen_template)\
		.replace("{?fallback}", "").replace("{/fallback}", "")\
		.replace("{name}", "\"  my/run  \"").replace("{fallback}", "\"untitled\"")
	var wanted: String = "\"%s/\" + %s + \".txt\"" % [TEST_DIR, safe_name]
	var free_path: String = str(by_id["FreeFilePath"].codegen_template)\
		.replace("{path}", wanted).replace("{at_most}", "9")

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.actions.append(_action("WriteTextFile", by_id, {
		"path": free_path, "text": "\"the second one\""}, "w1"))
	sheet.events.append(event)
	var output: String = str(SheetCompiler.compile(sheet, COMPILE_OUTPUTS[0]).get("output", ""))
	var script: GDScript = GDScript.new()
	script.source_code = output
	var reloaded: bool = script.reload() == OK
	ok = _check("the safe-name save event compiles to valid GDScript", reloaded, true) and ok
	if reloaded:
		var node: Node = script.new()
		node._ready()
		ok = _check("the name the player typed became a name a file system takes",
			FileAccess.file_exists("%s/my_run_1.txt" % TEST_DIR), true) and ok
		ok = _check("the free path stepped past the file that was already there",
			FileAccess.get_file_as_string("%s/my_run_1.txt" % TEST_DIR), "the second one") and ok
		ok = _check("the file that was already there is untouched",
			FileAccess.get_file_as_string("%s/my_run.txt" % TEST_DIR), "the first one") and ok
		node.free()

	# The two answers on their own, run as the lines they compile to.
	var blank_name: String = str(by_id["SafeFileName"].codegen_template)\
		.replace("{?fallback}", "").replace("{/fallback}", "")\
		.replace("{name}", "\"   \"").replace("{fallback}", "\"untitled\"")
	ok = _check("a name that is nothing once it is safe answers the fallback",
		_answer(blank_name), "untitled") and ok
	# `..` IS THE ONE NAME THAT IS A PATH. The engine's own validate_filename takes it unchanged, and
	# the documented next step is joining the answer onto a folder - where `"user://saves"` joined
	# with ".." is `user://`, the folder ABOVE the one the row meant.
	var climbing: String = str(by_id["SafeFileName"].codegen_template)\
		.replace("{?fallback}", "").replace("{/fallback}", "")\
		.replace("{name}", "\"..\"").replace("{fallback}", "\"untitled\"")
	ok = _check("a name that is only dots is not a name, and answers the fallback",
		_answer(climbing), "untitled") and ok
	var hidden: String = str(by_id["SafeFileName"].codegen_template)\
		.replace("{?fallback}", "").replace("{/fallback}", "")\
		.replace("{name}", "\".hidden\"").replace("{fallback}", "\"untitled\"")
	ok = _check("and a name that merely begins with one keeps the rest of itself",
		_answer(hidden), "hidden") and ok
	# A SLOT HOLDS AN EXPRESSION, AND A METHOD BINDS TO ITS LAST OPERAND. A name written as a JOIN is
	# the ordinary way this row is used - the player's word plus the extension the game gives it - and
	# unbracketed it validated only the `".json"`, handing `..` through the very row that exists to
	# stop it. The answer here is the whole join made safe: no slash, no leading dots.
	var joined: String = str(by_id["SafeFileName"].codegen_template)\
		.replace("{?fallback}", "").replace("{/fallback}", "")\
		.replace("{name}", "\"../evil\" + \".json\"").replace("{fallback}", "\"untitled\"")
	ok = _check("a name built out of pieces is made safe whole, not just its last piece",
		_answer(joined), "_evil.json") and ok
	var untaken: String = str(by_id["FreeFilePath"].codegen_template)\
		.replace("{path}", "\"%s/never_written.txt\"" % TEST_DIR).replace("{at_most}", "9")
	ok = _check("a path with nothing at it is answered back unchanged",
		_answer(untaken), "%s/never_written.txt" % TEST_DIR) and ok
	_cleanup()
	return ok


## What one expression answers with, run as the line it compiles to.
static func _answer(expression: String) -> Variant:
	var script: GDScript = GDScript.new()
	script.source_code = "extends RefCounted\n\n\nfunc answer() -> Variant:\n\treturn %s\n" % expression
	if script.reload() != OK:
		return "<did not compile>"
	return script.new().answer()


## Hand-written spellings of the three, opened as a sheet and saved untouched, byte for byte.
static func _round_trips() -> bool:
	var ok: bool = true
	var sources: Dictionary = {
		"the safe name": "extends Node\n\n\nfunc name_it(typed: String) -> String:\n"
			+ "\treturn typed.validate_filename() if not typed.validate_filename().is_empty()"
			+ " else \"untitled\"\n",
		"showing the file": "extends Node\n\n\nfunc reveal(where: String) -> void:\n"
			+ "\tOS.shell_show_in_file_manager(ProjectSettings.globalize_path(where))\n",
	}
	for label: String in sources:
		var source: String = str(sources[label])
		ok = _check("%s round-trips byte-identically" % label, _recompile(source), source) and ok

	# The action is also READ back as the row it means, with the author's own word in its slot - the
	# statement forms lift through the reverse index with no table entry of their own.
	var lifted: Dictionary = _first_action(GDScriptImporter.new().import_external_source(
		str(sources["showing the file"])))
	ok = _check("the hand-written desktop call reads back as the row it means",
		str(lifted.get("ace_id", "")), "ShowInFileManager") and ok
	ok = _check("and it keeps the author's own expression in the slot",
		str((lifted.get("params", {}) as Dictionary).get("path", "")), "where") and ok
	return ok


## The first ACE action anywhere in an opened sheet, as {ace_id, params}, or {} when there is none.
static func _first_action(sheet: EventSheetResource) -> Dictionary:
	var rows: Array = sheet.events.duplicate()
	for entry: Variant in sheet.functions:
		if entry is EventFunction:
			var event_function: EventFunction = entry
			rows.append_array(event_function.events if not event_function.events.is_empty()
				else event_function.rows)
	while not rows.is_empty():
		var row: Variant = rows.pop_front()
		if row is EventGroup:
			var group: EventGroup = row
			rows.append_array(group.events if not group.events.is_empty() else group.rows)
		elif row is EventRow:
			var event: EventRow = row
			for action: Variant in event.actions:
				if action is ACEAction:
					var typed: ACEAction = action
					return {"ace_id": typed.ace_id, "params": typed.params}
			rows.append_array(event.sub_events)
	return {}


## Every shape the trace is meant to reach, each one loading an outside path.
static func _doctor_finds_the_bug() -> bool:
	var ok: bool = true
	for label: String in _bug_fixtures():
		var lines: PackedStringArray = EventForgeOutsidePaths.loading_outside_lines(
			str(_bug_fixtures()[label]))
		ok = _check("reported: %s" % label, lines.size() >= 1, true) and ok
	var dropped: PackedStringArray = EventForgeOutsidePaths.loading_outside_lines(
		str(_bug_fixtures()["a dropped file, loaded"]))
	ok = _check("the reported line is the load itself, quoted",
		"" if dropped.is_empty() else dropped[0], "var brought := load(files[0])") and ok
	return ok


## The same doors, reaching a reader that answers with data instead. None of these is reported.
static func _doctor_leaves_clean_code_alone() -> bool:
	var ok: bool = true
	for label: String in _clean_fixtures():
		var lines: PackedStringArray = EventForgeOutsidePaths.loading_outside_lines(
			str(_clean_fixtures()[label]))
		ok = _check("left alone: %s" % label, _joined(lines), "") and ok
	return ok


## The finding a reader meets: the line, the risk in plain words, and the three data-shaped doors.
static func _doctor_says_the_risk_and_the_doors() -> bool:
	var ok: bool = true
	var sources: Dictionary = {
		"res://game/mods.gd": str(_bug_fixtures()["a dropped file, loaded"]),
		"res://game/pictures.gd": str(_clean_fixtures()["a dropped file, read as an image"]),
	}
	var findings: Array[Dictionary] = EventSheetFilesDoctor.loads_outside_findings(sources)
	ok = _check("one finding, on the one file that loads", findings.size(), 1) and ok
	if findings.is_empty():
		return false
	var finding: Dictionary = findings[0]
	ok = _check("it is filed under its own id", str(finding.get("check", "")),
		EventSheetFilesDoctor.CHECK_LOADS_OUTSIDE) and ok
	ok = _check("it is a warning, not an error - a game may mean it",
		str(finding.get("severity", "")), "warning") and ok
	ok = _check("it names the file that loads", str(finding.get("path", "")),
		"res://game/mods.gd") and ok
	ok = _check("it quotes the line", str(finding.get("subject", "")),
		"var brought := load(files[0])") and ok
	var message: String = str(finding.get("message", ""))
	ok = _check("it says a resource file can name a script",
		message.contains("can name a script"), true) and ok
	ok = _check("it says whose code would run",
		message.contains("runs that script with everything this game can reach"), true) and ok
	for door: String in ["Image From File", "Read Text File (or a fallback)", "Table From File"]:
		ok = _check("it offers the door: %s" % door, message.contains(door), true) and ok
	# AND IT SAYS HOW FAR IT REACHED. A trace that names a line and says nothing about its limits
	# leaves a reader believing a quiet file was cleared, which is the one way an honest check
	# misleads. The reach was written in the source header and nowhere a reader could see it.
	ok = _check("it says the trace reads one file only",
		message.contains("follows names inside ONE file"), true) and ok
	ok = _check("and that saying nothing is not clearing it",
		message.contains("is not a file it has cleared"), true) and ok
	# AND THE TWO SHAPES THAT REACH CODE WITHOUT A LOADER are named where a reader meets them, not
	# only in the source header. A path handed to the operating system runs a stranger's PROGRAM,
	# and text set as a script's source becomes code with no loader involved at all.
	ok = _check("it names the calls that run a program rather than load a file",
		message.contains("OS.execute, OS.create_process or OS.shell_open"), true) and ok
	ok = _check("and text turned into a script's source",
		message.contains("set as a script's source becomes code"), true) and ok
	# THE PACK MOUNT SAYS THE EXTRA TRUE THING, and only about a file that holds one. A load is not a
	# mount, so a finding about a load must not carry the mount's sentence.
	ok = _check("a load says nothing about mounting",
		message.contains("MOUNTS a pack"), false) and ok
	var mounting: Array[Dictionary] = EventSheetFilesDoctor.loads_outside_findings(
		{"res://game/packs.gd": str(_bug_fixtures()["a chosen pack, mounted into res://"])})
	ok = _check("one finding, on the file that mounts", mounting.size(), 1) and ok
	var mount_message: String = "" if mounting.is_empty() else str(mounting[0].get("message", ""))
	ok = _check("it says the pack is put under res:// from then on",
		mount_message.contains("puts everything inside it under res:// from then on"), true) and ok
	ok = _check("and that it replaces the game's own files unless told otherwise",
		mount_message.contains("REPLACES the game's own files"), true) and ok
	return ok


## The bug fixtures. Two are emitted spellings, three are the way somebody writes this by hand.
static func _bug_fixtures() -> Dictionary:
	return {
		"a dropped file, loaded": "extends Node\n\n\nfunc _ready() -> void:\n"
			+ "\tget_window().files_dropped.connect(_on_files_dropped)\n\n\n"
			+ "func _on_files_dropped(files: PackedStringArray) -> void:\n"
			+ "\tvar brought := load(files[0])\n\tadd_child(brought.instantiate())\n",
		"a chosen file, remembered on the object, loaded later":
			"extends Node\n\nvar _picked: String = \"\"\n\n\n"
			+ "func _on_file_chosen(path: String) -> void:\n\t_picked = path\n\n\n"
			+ "func apply() -> void:\n\tvar skin := ResourceLoader.load(_picked)\n\tprint(skin)\n",
		"a file out of a watched folder, loaded": "extends Node\n\n\nfunc _ready() -> void:\n"
			+ "\t$FolderWatcher.watch_folder(\"user://mods\", 2.0)\n\n\n"
			+ "func _on_file_appeared(path: String) -> void:\n\tvar mod := load(path)\n\tprint(mod)\n",
		"a file named under the watched folder, loaded": "extends Node\n\n\nfunc _ready() -> void:\n"
			+ "\t$FolderWatcher.watch_folder(\"user://mods\", 2.0)\n\n\n"
			+ "func apply() -> void:\n\tvar mod := load(\"user://mods/first.tscn\")\n\tprint(mod)\n",
		# THE SHAPE THE TRACE'S OWN HEADER NAMES: one handler stores the path on this object and
		# another loads it. Written as `self.chosen` it went unseen, because the dot rule that keeps
		# SOMEBODY ELSE'S property out was reading `self` as somebody else.
		"a chosen file, stored on self, loaded later":
			"extends Node\n\nvar chosen: String = \"\"\n\n\n"
			+ "func _on_file_chosen(path: String) -> void:\n\tself.chosen = path\n\n\n"
			+ "func apply() -> void:\n\tvar skin := load(self.chosen)\n\tprint(skin)\n",
		# And a watched folder HELD IN A NAME is the same watch as a literal one. The header claims
		# folders this file watches are followed; a name is how half of them are written.
		"a file under a watched folder held in a name": "extends Node\n\n\nfunc _ready() -> void:\n"
			+ "\tvar folder := \"user://mods\"\n\t$FolderWatcher.watch_folder(folder, 2.0)\n\n\n"
			+ "func apply() -> void:\n\tvar mod := load(\"user://mods/first.tscn\")\n\tprint(mod)\n",
		# TRAVELLING TO A LAYOUT BUILDS IT. `change_scene_to_file` attaches whatever script the scene
		# names exactly as `load` does, and a dropped path handed to it earned nothing at all while
		# the same path handed to `load` earned a finding.
		"a dropped file, travelled to": "extends Node\n\n\nfunc _ready() -> void:\n"
			+ "\tget_window().files_dropped.connect(_on_files_dropped)\n\n\n"
			+ "func _on_files_dropped(files: PackedStringArray) -> void:\n"
			+ "\tget_tree().change_scene_to_file(files[0])\n",
		# AND MOUNTING A PACK IS WIDER THAN EITHER. Nothing is built at that moment; everything
		# after it may be somebody else's, because the pack's files ARE res:// from then on.
		"a chosen pack, mounted into res://": "extends Node\n\n\n"
			+ "func _on_file_chosen(path: String) -> void:\n"
			+ "\tProjectSettings.load_resource_pack(path, true)\n",
		# The threaded pair is one call that asks and another that hands the object over. Only the
		# second one builds, and it was the one nothing watched.
		"a chosen file, asked for and taken threaded": "extends Node\n\n\n"
			+ "func _on_file_chosen(path: String) -> void:\n"
			+ "\tvar skin := ResourceLoader.load_threaded_get(path)\n\tprint(skin)\n",
		# A LAMBDA IS A HANDLER WITH NO NAME, and it is the shortest way anybody writes this. The
		# lambda's whole TEXT was stored as if it were a handler name, no `func ` line ever matched
		# it, and the trace started from nothing - so the loudest shape in the file went unread.
		"a dropped file, loaded by a lambda on the connect line": "extends Node\n\n\n"
			+ "func _ready() -> void:\n\tget_window().files_dropped.connect("
			+ "func(files: PackedStringArray) -> void: add_child(load(files[0]).instantiate()))\n",
		# AND AN UNPACK FOLDER HELD IN A NAME is the same folder as a literal one, exactly as a
		# watched folder held in a name is. The watch followed the name back to what it was bound
		# to; the unpack did not, so half of the shapes it claims to read went unread.
		"a file under an unpack folder held in a name": "extends Node\n\n\nfunc unpack() -> void:\n"
			+ "\tvar target := \"user://unpacked\"\n\tvar __reader_a := ZIPReader.new()\n"
			+ "\tif __reader_a.open(\"user://pack.zip\") == OK:\n"
			+ "\t\tDirAccess.make_dir_recursive_absolute(target)\n\t\t__reader_a.close()\n\n\n"
			+ "func apply() -> void:\n\tprint(load(\"user://unpacked/main.tscn\"))\n",
		"a file out of an unpacked archive, loaded": "extends Node\n\n\nfunc unpack() -> void:\n"
			+ "\tvar __reader_a := ZIPReader.new()\n\tif __reader_a.open(\"user://pack.zip\") == OK:\n"
			+ "\t\tDirAccess.make_dir_recursive_absolute(\"user://unpacked\")\n"
			+ "\t\t__reader_a.close()\n\n\nfunc apply() -> void:\n"
			+ "\tfor entry in DirAccess.get_files_at(\"user://unpacked\"):\n"
			+ "\t\tprint(load(\"user://unpacked\".path_join(entry)))\n",
	}


## The clean fixtures. Every door is open; nothing that came through one reaches a loader.
static func _clean_fixtures() -> Dictionary:
	return {
		"a dropped file, read as an image": "extends Node\n\n\nfunc _ready() -> void:\n"
			+ "\tget_window().files_dropped.connect(_on_files_dropped)\n\n\n"
			+ "func _on_files_dropped(files: PackedStringArray) -> void:\n"
			+ "\t$Portrait.texture = ImageTexture.create_from_image(Image.load_from_file(files[0]))\n",
		"a chosen file, read as text": "extends Node\n\n\n"
			+ "func _on_file_chosen(path: String) -> void:\n"
			+ "\t$Notes.text = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path)"
			+ " else \"\"\n",
		"a watched file, read as a table": "extends Node\n\n\nfunc _ready() -> void:\n"
			+ "\t$FolderWatcher.watch_folder(\"user://mods\", 2.0)\n\n\n"
			+ "func _on_file_changed(path: String) -> void:\n"
			+ "\t_rows = FileAccess.get_file_as_string(path).split(\"\\n\")\n",
		"a chosen file, played as a sound": "extends Node\n\n\n"
			+ "func _on_file_chosen(path: String) -> void:\n"
			+ "\t$Music.stream = AudioStreamOggVorbis.load_from_file(path)\n",
		"the game's own scene, loaded": "extends Node\n\n\nfunc _ready() -> void:\n"
			+ "\tget_window().files_dropped.connect(_on_files_dropped)\n\n\n"
			+ "func _on_files_dropped(files: PackedStringArray) -> void:\n"
			+ "\tprint(files.size())\n\tadd_child(load(\"res://ui/toast.tscn\").instantiate())\n",
		"the game's own scene, preloaded": "extends Node\n\nconst TOAST := preload(\"res://ui/toast.tscn\")\n\n\n"
			+ "func _on_file_chosen(path: String) -> void:\n\tprint(path)\n\tadd_child(TOAST.instantiate())\n",
		"a property that merely shares a name with an outside one": "extends Node\n\n\n"
			+ "func _on_file_chosen(path: String) -> void:\n\tprint(path)\n\n\n"
			+ "func apply(config: Resource) -> void:\n\tadd_child(load(config.path).instantiate())\n",
		"no doors at all": "extends Node\n\n\nfunc _ready() -> void:\n"
			+ "\tadd_child(load(\"res://ui/toast.tscn\").instantiate())\n",
		# The lambda shape, reaching a reader that answers with pixels. Reading a lambda's parameters
		# as outside names must not make every lambda a finding.
		"a dropped file, read as an image by a lambda": "extends Node\n\n\nfunc _ready() -> void:\n"
			+ "\tget_window().files_dropped.connect(func(files: PackedStringArray) -> void:"
			+ " $Portrait.texture = ImageTexture.create_from_image("
			+ "Image.load_from_file(files[0])))\n",
	}


## ACEAction with the registered template, baking {uid} exactly as the dock does at apply time.
static func _action(ace_id: String, by_id: Dictionary, params: Dictionary, uid: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.codegen_template = str(by_id[ace_id].codegen_template).replace("{uid}", uid)
	action.params = params
	return action


## Open a source as a sheet and emit it again untouched.
static func _recompile(source: String) -> String:
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	imported.external_source_path = COMPILE_OUTPUTS[1]
	return str(SheetCompiler.compile(imported, COMPILE_OUTPUTS[1]).get("output", ""))


static func _joined(lines: PackedStringArray) -> String:
	return " | ".join(lines)


## Everything this test wrote, taken away with it. The two scripts are the OUTPUT of a compile,
## which the compiler writes where it is told to write it: they sit beside the folder rather than
## inside it, so a sweep of the folder alone leaves them behind on the machine that ran the suite.
static func _cleanup() -> void:
	for name_text: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute("%s/%s" % [TEST_DIR, name_text])
	DirAccess.remove_absolute(TEST_DIR)
	for compiled: String in COMPILE_OUTPUTS:
		if FileAccess.file_exists(compiled):
			DirAccess.remove_absolute(compiled)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("safe_names_and_outside_content_test", label, actual, expected)
