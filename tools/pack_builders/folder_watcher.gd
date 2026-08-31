# Pack builder - folder_watcher (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Folder Watcher: notices when a file in one folder appeared, changed or went away.
##
## A POLL CALLS ITSELF A POLL. Godot has no file-change notification at run time on any platform it
## ships for, so there is nothing here to subscribe to and nothing this pack could subscribe to for
## you. What it does instead is LOOK, on an interval you choose, and compare what it saw with what it
## saw last time - by file name and by the time each file was last modified. That is the whole
## mechanism, it is in the emitted script where it can be read, and the row that starts it says the
## interval out loud, because "watching" that quietly costs a directory read every frame is the kind
## of thing a project only finds out about on somebody's slow disk.
##
## WHAT ONE LOOK COSTS: one DirAccess.get_files_at of the folder, plus one modified-time question per
## file that passes the filter. Between looks it costs nothing, and while it is stopped it costs
## nothing at all - the per-frame tick is parked with set_process(false), the fleet convention, so a
## stopped watcher is not a node the engine still visits.
##
## THE FIRST LOOK IS THE BASELINE. Starting a watch records what is there without raising anything:
## a folder that already holds two hundred files is not two hundred things that just happened. The
## events start at the second look.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node"
	sheet.custom_class_name = "FolderWatcher"
	sheet.class_description = "Watches one folder and raises On A File Appeared / Changed / Removed. Godot has no runtime file watcher, so this POLLS: it reads the folder every few seconds and compares what it finds with what it found last time, by name and by modified time. Watch Folder starts it, Stop Watching parks it, and a stopped watcher costs nothing per frame."
	sheet.addon_category = "Folder Watcher"
	sheet.ace_expose_all_mode = "node"
	sheet.addon_tags = PackedStringArray(["files", "tools"])
	sheet.variables = {
		"watched_folder": {"type": "String", "default": "user://mods", "exported": true, "description": "The folder to look in. Prefer user:// - a folder under res:// is packed into the export and cannot be written to once the game ships, so nothing in it will ever change."},
		"look_every_seconds": {"type": "float", "default": 2.0, "exported": true, "description": "Seconds between looks. Every look is one directory read plus one modified-time question per file, so a second or two is generous for a mods folder and far too often for a folder holding thousands of files."},
		"only_names_like": {"type": "String", "default": "*", "exported": true, "description": "Which file names count, as a pattern with * and ? in it - \"*.json\" for data files, \"*\" for all of them. Names that do not match are invisible to this watcher: they raise nothing, and they are not looked up."},
		"watch_on_ready": {"type": "bool", "default": false, "exported": true, "description": "Start watching as soon as the node is ready, using the folder and interval above. Off by default, because a watcher is usually started by the sheet at the moment the game actually cares."},
		"_seen": {"type": "Dictionary", "default": {}, "exported": false},
		"_since_last_look": {"type": "float", "default": 0.0, "exported": false},
		"_watching": {"type": "bool", "default": false, "exported": false}
	}

	var about: CommentRow = CommentRow.new()
	about.text = "Folder Watcher: a POLL, not a subscription. Watch Folder starts looking every few seconds; the difference between one look and the next is what raises On A File Appeared / Changed / Removed. Stopped, it parks its per-frame tick and costs nothing."
	sheet.events.append(about)

	# The three events one look can raise, each handing back the WHOLE path so a handler can read the
	# file without rebuilding it. A signal carries its name and nothing else through the pack
	# pipeline, so what each one means is said in the comment above it rather than in an
	# `@ace_description` the emitter would drop.
	var triggers: RawCodeRow = RawCodeRow.new()
	triggers.code = "\n".join(PackedStringArray([
		"# Raised on the first look that finds a file the look before did not.",
		"## @ace_trigger",
		"## @ace_name(\"On A File Appeared\")",
		"signal file_appeared(path: String)",
		"",
		"# Raised when a file that was already there has a NEWER modified time than it had at the last",
		"# look. A program that writes a file in several goes can raise this more than once per save.",
		"## @ace_trigger",
		"## @ace_name(\"On A File Changed\")",
		"signal file_changed(path: String)",
		"",
		"# Raised on the first look that no longer finds a file the look before did. The path names",
		"# what went; there is nothing left at it to read.",
		"## @ace_trigger",
		"## @ace_name(\"On A File Removed\")",
		"signal file_removed(path: String)"
	]))
	sheet.events.append(triggers)

	var looking: RawCodeRow = RawCodeRow.new()
	looking.code = "\n".join(PackedStringArray([
		"## What the folder held at the last look: file name -> the time that file was last modified.",
		"## The whole mechanism is this dictionary compared with the next look's.",
		"## @ace_hidden",
		"func _read_folder() -> Dictionary:",
		"\tvar found: Dictionary = {}",
		"\t# One directory read per look. The names are sorted so two machines walking the same folder",
		"\t# raise the same events in the same order - the engine promises no order of its own.",
		"\tvar names: PackedStringArray = DirAccess.get_files_at(watched_folder)",
		"\tnames.sort()",
		"\tfor entry: String in names:",
		"\t\tif not only_names_like.is_empty() and not entry.match(only_names_like):",
		"\t\t\tcontinue",
		"\t\tfound[entry] = FileAccess.get_modified_time(watched_folder.path_join(entry))",
		"\treturn found",
		"",
		"## One look: read the folder, raise what the difference means, and keep the new reading as the",
		"## one the next look is compared against.",
		"## @ace_hidden",
		"func _look() -> void:",
		"\tvar found: Dictionary = _read_folder()",
		"\tfor entry: String in found:",
		"\t\tif not _seen.has(entry):",
		"\t\t\tfile_appeared.emit(watched_folder.path_join(entry))",
		"\t\telif int(_seen[entry]) != int(found[entry]):",
		"\t\t\tfile_changed.emit(watched_folder.path_join(entry))",
		"\tfor entry: String in _seen:",
		"\t\tif not found.has(entry):",
		"\t\t\tfile_removed.emit(watched_folder.path_join(entry))",
		"\t_seen = found"
	]))
	sheet.events.append(looking)

	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"
	var ready_body: RawCodeRow = RawCodeRow.new()
	ready_body.code = "\n".join(PackedStringArray([
		"# Nothing is being watched yet, so there is nothing to look for once a frame.",
		"set_process(false)",
		"if watch_on_ready:",
		"\twatch_folder(watched_folder, look_every_seconds)"
	]))
	on_ready.actions.append(ready_body)
	sheet.events.append(on_ready)

	# Per-frame: count down to the next look, and take it. This is the only thing the pack does per
	# frame, and it is only reached while a watch is running.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if not _watching:",
		"\tset_process(false)",
		"\treturn",
		"_since_last_look += delta",
		"# A zero or negative interval would be a directory read every single frame, which is never",
		"# what anybody meant by an interval, so the shortest gap the watcher will honour is a tenth",
		"# of a second.",
		"if _since_last_look < maxf(look_every_seconds, 0.1):",
		"\treturn",
		"_since_last_look = 0.0",
		"_look()"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	Lib.append_function(sheet, "watch_folder", "Watch Folder", "Folder Watcher",
		"Starts watching a folder, looking every so many seconds. This is a POLL: the folder is read on that interval and compared with the reading before it, because Godot raises no file-change notification of its own at run time. The first look is the baseline and raises nothing - a folder that already holds files is not a folder where things just happened.",
		[["folder", "String"], ["every_seconds", "float"]], "\n".join(PackedStringArray([
		"watched_folder = folder",
		"look_every_seconds = every_seconds",
		"# The baseline: what is there now, recorded without raising anything.",
		"_seen = _read_folder()",
		"_since_last_look = 0.0",
		"_watching = true",
		"# Looking costs a frame's attention only while a watch is running.",
		"set_process(true)"
	])), "Watch folder [b]{folder}[/b] every [b]{every_seconds}[/b] s")

	Lib.append_function(sheet, "stop_watching", "Stop Watching", "Folder Watcher",
		"Stops looking. The per-frame tick is parked, so a stopped watcher is a node the engine no longer visits at all, and nothing is read from disk until it is started again.",
		[], "\n".join(PackedStringArray([
		"_watching = false",
		"set_process(false)"
	])), "[b]Stop[/b] watching the folder")

	Lib.append_function(sheet, "look_now", "Look Now", "Folder Watcher",
		"Takes one look immediately, without waiting for the interval, and raises whatever the difference means. Use it after your own game has written into the folder, when waiting a second or two for the next look would just be a pause nobody asked for.",
		[], "\n".join(PackedStringArray([
		"_since_last_look = 0.0",
		"_look()"
	])), "[b]Look[/b] at the folder now")

	Lib.condition(sheet, "is_watching", "Is Watching", "Folder Watcher",
		"True while a watch is running - that is, between Watch Folder and Stop Watching.", [],
		"return _watching")

	Lib.number(sheet, "watched_file_count", "Watched File Count", "Folder Watcher",
		"How many files the last look found, after the name filter. Zero before the first look.", [],
		"return _seen.size()", TYPE_INT)

	Lib.number(sheet, "watched_file_names", "Watched File Names", "Folder Watcher",
		"The file names the last look found, after the name filter, in sorted order. Names, not whole paths - join one onto the folder to read it.",
		[], "return _seen.keys()", TYPE_ARRAY)

	Lib.feature_verbs(sheet, ["watch_folder", "stop_watching"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/folder_watcher/folder_watcher_behavior")
