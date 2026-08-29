# Pack builder - encounter_timeline (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Encounter Timeline: the general spawn/beat timeline, worn by whatever runs the encounter - an arena,
## a boss, a tutorial director, a street that breathes traffic. Attach it, drop an EncounterResource
## (.tres) of beats on its slot, and Start Encounter plays them back on their own schedule: the behavior
## ticks its own clock, spawns each beat's scene the moment its at_seconds arrives, drops every copy in
## the beat's group, and fires On Entry Spawned per node and On Encounter Finished when the last beat
## has played.
##
## Spawning is DECOUPLED from any pooling pack: when an ObjectPool autoload is registered the timeline
## spawns through it (a ten-minute wave reuses nodes instead of churning them), and when none is it
## simply instantiates the scene. Nothing here names another pack's class.
##
## Write Encounter Report turns the loaded data into a plain-text summary - the beat table, the totals,
## the per-30-second spawn density - every number DERIVED from the entries, and every field it could not
## read (a blank scene path, a scene that is not there, a count of 0) listed rather than hidden.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node"
	sheet.custom_class_name = "EncounterTimelineBehavior"
	sheet.class_description = "The spawn/beat timeline, worn by whatever runs the encounter: an arena, a boss, a tutorial director, ambient traffic. Load an EncounterResource (.tres) of beats - at_seconds, scene, count, group, note - then Start Encounter and the behavior ticks its own clock, spawns each beat on schedule (through the ObjectPool autoload when one is installed), and fires On Entry Spawned and On Encounter Finished. Write Encounter Report summarises the plan, spawn density included."
	sheet.addon_category = "Encounter Timeline"
	sheet.addon_tags = PackedStringArray(["spawning", "waves", "pacing", "encounter"])
	sheet.variables = {
		"encounter": {"type": "Resource", "default": null, "exported": true,
			"attributes": {"tooltip": "Optional: drop an EncounterResource (.tres) here to load its beats on ready - the data-driven way to plan an encounter without events. You can also load one later (or a different difficulty) with Load Encounter."}},
		"use_object_pool": {"type": "bool", "default": true, "exported": true,
			"attributes": {"tooltip": "When on (the default), spawns go through the ObjectPool autoload IF one is registered - a long encounter then reuses nodes instead of creating and freeing them. With no ObjectPool installed, or with this off, the timeline instantiates the scene itself. Either way the triggers fire identically."}},
		"auto_start": {"type": "bool", "default": false, "exported": true,
			"attributes": {"tooltip": "Start the encounter as soon as this node is ready, instead of waiting for a Start Encounter action. Handy for an arena that begins the moment its scene loads; leave it off when a cutscene or a door should decide."}}
	}

	var about: CommentRow = CommentRow.new()
	about.text = "Encounter Timeline behavior: attach it to whatever runs the encounter and drop an Encounter resource (.tres) on its slot. Start Encounter plays the beats back on their own clock - the behavior ticks itself, so there is nothing to drive from a sheet - spawning each beat's scene at its at_seconds, adding every copy to the beat's group, and firing On Entry Spawned per node then On Encounter Finished after the last beat. It spawns through the ObjectPool autoload when one is installed and instantiates the scene when none is. Write Encounter Report saves a plain-text plan of the whole encounter. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	var spawned: SignalRow = SignalRow.new()
	spawned.signal_name = "on_entry_spawned"
	spawned.params = PackedStringArray(["node: Node", "group_name: String"])
	spawned.trigger = true
	spawned.ace_name = "On Entry Spawned"
	spawned.ace_category = "Encounter Timeline"
	sheet.events.append(spawned)

	var finished: SignalRow = SignalRow.new()
	finished.signal_name = "on_encounter_finished"
	finished.params = PackedStringArray([])
	finished.trigger = true
	finished.ace_name = "On Encounter Finished"
	finished.ace_category = "Encounter Timeline"
	sheet.events.append(finished)

	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"# The loaded plan, kept sorted by time: one record per beat, {at, scene, count, group, note}.",
		"# _next is the index of the beat that has not played yet, so the clock never re-reads the past.",
		"var _entries: Array = []",
		"var _clock: float = 0.0",
		"var _next: int = 0",
		"var _running: bool = false",
		"var _finished: bool = false",
		"var _spawned: int = 0",
		"var _encounter_name: String = \"\"",
		"# Last-spawn context, readable outside the trigger (the trigger carries the same two values).",
		"var _last_spawned: Node = null",
		"var _last_group: String = \"\"",
		"# An explicit pool handed over by Use Object Pool Node, tried before the autoload.",
		"var _pool_node: Node = null",
		"",
		"# The clock. A while loop (not an if) so one huge delta - a stall, a loading hitch - plays every",
		"# beat it crossed rather than dropping all but the last. Deliberately unpublished: the behavior",
		"# drives it from its own _process row, so a sheet never has to hand it a delta.",
		"## @ace_hidden",
		"func advance(delta: float) -> void:",
		"\tif not _running:",
		"\t\treturn",
		"\t_clock += delta",
		"\twhile _next < _entries.size() and _clock >= float(_entries[_next].at):",
		"\t\t_spawn_entry(_entries[_next])",
		"\t\t_next += 1",
		"\tif _next >= _entries.size():",
		"\t\t_running = false",
		"\t\t_finished = true",
		"\t\t# The plan has played out, so there is no clock left to keep - stop paying for the tick.",
		"\t\t# Turned off BEFORE the trigger fires, so a handler that chains the next wave with Start",
		"\t\t# Encounter turns processing back on and is not undone by this line.",
		"\t\tset_process(false)",
		"\t\ton_encounter_finished.emit()",
		"",
		"# The pooling seam. Nothing here depends on the Object Pool pack: the node given to Use Object",
		"# Pool Node, else any autoload registered at /root/ObjectPool, qualifies as long as it answers",
		"# has_pool / create_pool / spawn - and without one the timeline instantiates the scene itself.",
		"# One pool per scene path, created the first time that scene is needed.",
		"func _pool() -> Node:",
		"\tif not use_object_pool:",
		"\t\treturn null",
		"\tvar pool: Node = _pool_node if _pool_node != null and is_instance_valid(_pool_node) else null",
		"\tif pool == null and is_inside_tree():",
		"\t\tpool = get_node_or_null(\"/root/ObjectPool\")",
		"\tif pool == null:",
		"\t\treturn null",
		"\tif pool.has_method(\"has_pool\") and pool.has_method(\"create_pool\") and pool.has_method(\"spawn\"):",
		"\t\treturn pool",
		"\treturn null",
		"",
		"# One instance of a scene, pooled when a pool answers. Returns nothing for a blank path or a",
		"# scene that is not in the project - checked with ResourceLoader.exists so a typo is a quiet",
		"# skip (and a line in the report) instead of a console full of load errors.",
		"func _make_one(scene_path: String) -> Node:",
		"\tif scene_path.is_empty() or not ResourceLoader.exists(scene_path):",
		"\t\treturn null",
		"\tvar pool: Node = _pool()",
		"\tif pool != null:",
		"\t\tif not bool(pool.call(\"has_pool\", scene_path)):",
		"\t\t\tpool.call(\"create_pool\", scene_path, scene_path, 0)",
		"\t\treturn pool.call(\"spawn\", scene_path) as Node",
		"\tvar scene: PackedScene = ResourceLoader.load(scene_path) as PackedScene",
		"\treturn scene.instantiate() if scene != null else null",
		"",
		"# Where fresh spawns are parented: the running scene, so a moving spawner never drags its wave",
		"# around by its transform. Falls back to this node when there is no scene (a headless run or a",
		"# test). A pooled node arrives already parented, and is left where the pool put it.",
		"func _spawn_parent() -> Node:",
		"\tif is_inside_tree() and get_tree() != null and get_tree().current_scene != null:",
		"\t\treturn get_tree().current_scene",
		"\treturn self",
		"",
		"# Plays one beat: count copies, each added to the beat's group (persistent, so the group survives",
		"# being packed into a scene) and announced individually. A beat with no scene still fires nothing",
		"# per node - use its note and On Encounter Finished, or give it a scene.",
		"func _spawn_entry(entry: Dictionary) -> void:",
		"\tvar group_name: String = str(entry.group)",
		"\tfor _i: int in maxi(int(entry.count), 0):",
		"\t\tvar node: Node = _make_one(str(entry.scene))",
		"\t\tif node == null:",
		"\t\t\tcontinue",
		"\t\tif not group_name.is_empty():",
		"\t\t\tnode.add_to_group(group_name, true)",
		"\t\tif node.get_parent() == null:",
		"\t\t\t_spawn_parent().add_child(node)",
		"\t\t_spawned += 1",
		"\t\t_last_spawned = node",
		"\t\t_last_group = group_name",
		"\t\ton_entry_spawned.emit(node, group_name)",
		"",
		"# Inserts a beat in time order without a sort callable, so the plan is always ordered and",
		"# equal times keep the order they were written in. Returns where it landed, which is what lets",
		"# a beat added mid-encounter re-seat the cursor correctly.",
		"func _insert_sorted(entry: Dictionary) -> int:",
		"\tvar at: int = _entries.size()",
		"\tvar index: int = 0",
		"\tfor existing: Dictionary in _entries:",
		"\t\tif float(existing.at) > float(entry.at):",
		"\t\t\tat = index",
		"\t\t\tbreak",
		"\t\tindex += 1",
		"\t_entries.insert(at, entry)",
		"\treturn at",
		"",
		"# A grid off an EncounterResource (a property). Returns an Array of row dicts; a stray",
		"# non-Dictionary element (a hand-edited .tres) is dropped rather than crashing the typed loops.",
		"func _rows(source: Variant, field: String) -> Array:",
		"\tvar raw: Variant = source.get(field)",
		"\tif not raw is Array:",
		"\t\treturn []",
		"\tvar out: Array = []",
		"\tfor element: Variant in raw:",
		"\t\tif element is Dictionary:",
		"\t\t\tout.append(element)",
		"\treturn out",
		"",
		"# One cell off a row, treating a PRESENT-but-null value as missing so the default still applies",
		"# (Dictionary.get only falls back when the key is ABSENT).",
		"func _cell(row: Dictionary, key: String, fallback: Variant) -> Variant:",
		"\tvar value: Variant = row.get(key, fallback)",
		"\treturn fallback if value == null else value",
		"",
		"func _num(value: Variant) -> float:",
		"\tif value is float or value is int:",
		"\t\treturn float(value)",
		"\tif value is String and (value as String).is_valid_float():",
		"\t\treturn (value as String).to_float()",
		"\treturn 0.0",
		"",
		"# Everything the plan does not say clearly, derived from the entries themselves - a beat with no",
		"# scene, a scene that is not in the project, a count of 0, a spawn that joins no group. The report",
		"# prints these verbatim instead of quietly rounding them away.",
		"func _problems() -> PackedStringArray:",
		"\tvar out: PackedStringArray = PackedStringArray()",
		"\tvar index: int = 0",
		"\tfor entry: Dictionary in _entries:",
		"\t\tvar where: String = \"beat %d at %ss\" % [index + 1, String.num(float(entry.at), 2)]",
		"\t\tvar scene_path: String = str(entry.scene)",
		"\t\tif scene_path.is_empty():",
		"\t\t\tout.append(\"%s: no scene path - it spawns nothing\" % where)",
		"\t\telif not ResourceLoader.exists(scene_path):",
		"\t\t\tout.append(\"%s: scene not found in this project (%s)\" % [where, scene_path])",
		"\t\tif int(entry.count) <= 0:",
		"\t\t\tout.append(\"%s: count is 0 - it spawns nothing\" % where)",
		"\t\tif str(entry.group).is_empty():",
		"\t\t\tout.append(\"%s: no group name - its spawns join no group\" % where)",
		"\t\tindex += 1",
		"\treturn out"
	]))
	sheet.events.append(block)

	# Self-tick: the behavior owns its own clock, so nothing in a user sheet has to feed it a delta.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "advance(delta)"
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	# On ready: load the attached plan, and start it when the designer asked for that.
	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"
	var on_ready_body: RawCodeRow = RawCodeRow.new()
	on_ready_body.code = "\n".join(PackedStringArray([
		"if encounter != null:",
		"\tload_encounter(encounter)",
		"if auto_start:",
		"\t# Deferred so the first beat cannot spawn before the host's sheet has connected its",
		"\t# triggers - the host readies AFTER this child, and On Entry Spawned would be missed.",
		"\tstart_encounter.call_deferred()",
		"# A timeline that is not running has no clock to advance; Start Encounter is what wakes it,",
		"# including the deferred one above.",
		"set_process(_running)"
	]))
	on_ready.actions.append(on_ready_body)
	sheet.events.append(on_ready)

	# --- Planning ---
	Lib.append_function(sheet, "load_encounter", "Load Encounter", "Encounter Timeline",
		"Loads a whole plan from an EncounterResource (.tres) - every beat with its time, scene, count, group and note - REPLACING whatever was loaded before and rewinding the clock. Rows may be written in any order; they are sorted by time as they load.",
		[["resource", "Resource"]],
		"\n".join(PackedStringArray([
			"if resource == null:",
			"\treturn",
			"clear_encounter()",
			"var raw_name: Variant = resource.get(\"encounter_name\")",
			"_encounter_name = str(raw_name) if raw_name != null else \"\"",
			"for row: Dictionary in _rows(resource, \"entries\"):",
			"\t_insert_sorted({",
			"\t\t\"at\": maxf(_num(_cell(row, \"at_seconds\", 0.0)), 0.0),",
			"\t\t\"scene\": str(_cell(row, \"scene_path\", \"\")),",
			"\t\t\"count\": maxi(int(_num(_cell(row, \"count\", 1))), 0),",
			"\t\t\"group\": str(_cell(row, \"group_name\", \"\")),",
			"\t\t\"note\": str(_cell(row, \"note\", \"\"))",
			"\t})"
		])),
		"Load encounter [b]{resource}[/b]")

	Lib.append_function(sheet, "add_entry", "Add Encounter Entry", "Encounter Timeline",
		"Adds one beat from a sheet, for an encounter built at runtime - a wave scaled to the player's level, a boss phase queued by the fight itself. It lands in time order wherever it belongs, even mid-encounter (a beat added before the clock has passed it still plays).",
		[["at_seconds", "float"], ["scene_path", "String"], ["count", "int"], ["group_name", "String"], ["note", "String"]],
		"\n".join(PackedStringArray([
			"var at: int = _insert_sorted({",
			"\t\"at\": maxf(at_seconds, 0.0),",
			"\t\"scene\": scene_path,",
			"\t\"count\": maxi(count, 0),",
			"\t\"group\": group_name,",
			"\t\"note\": note",
			"})",
			"# A beat inserted BEFORE the cursor is one the clock has already run past, so the cursor",
			"# steps over it: adding an early beat mid-encounter must not replay it, and must not push",
			"# the next real beat out of reach either.",
			"if at < _next:",
			"\t_next += 1"
		])),
		"Add beat at [b]{at_seconds}[/b]s: [b]{count}[/b] x [b]{scene_path}[/b] into [b]{group_name}[/b]")

	Lib.append_function(sheet, "clear_encounter", "Clear Encounter", "Encounter Timeline",
		"Empties the plan and rewinds everything - no beats, clock at 0, nothing running. Load Encounter does this for you; call it yourself before building a plan out of Add Encounter Entry rows.",
		[],
		"_entries.clear()\n_clock = 0.0\n_next = 0\n_spawned = 0\n_running = false\n_finished = false\n# Nothing loaded and nothing running - no frame has any work to do until a plan is started.\nset_process(false)")

	# --- Running ---
	Lib.append_function(sheet, "start_encounter", "Start Encounter", "Encounter Timeline",
		"Runs the plan from the top: the clock restarts at 0, the spawn tally resets, and each beat fires as its time arrives. An encounter with no beats finishes on its very next frame, so On Encounter Finished still tells you the wave is over.",
		[],
		"_clock = 0.0\n_next = 0\n_spawned = 0\n_running = true\n_finished = false\n# A running encounter needs the frames it counts its clock in.\nset_process(true)")

	Lib.append_function(sheet, "stop_encounter", "Stop Encounter", "Encounter Timeline",
		"Freezes the encounter where it stands - the clock stops and no further beat spawns. Already-spawned nodes are left alone (they are yours). Elapsed Seconds keeps its value, so a paused wave can be inspected; Start Encounter restarts from the top.",
		[],
		"_running = false\n# A frozen encounter costs nothing per frame; Start Encounter turns the clock back on.\nset_process(false)")

	Lib.append_function(sheet, "use_pool_node", "Use Object Pool Node", "Encounter Timeline",
		"Spawns through THIS pool node instead of searching for the ObjectPool autoload - for a per-arena pool, or a pool you wrote yourself. The contract is three functions: has_pool(name), create_pool(name, scene_path, prewarm) and spawn(name); a node missing any of them is ignored and the timeline instantiates scenes as usual. Pass nothing to go back to the autoload.",
		[["node", "Node"]],
		"_pool_node = node",
		"Use object pool node [i]{node}[/i]")

	Lib.append_function(sheet, "skip_to", "Skip To", "Encounter Timeline",
		"Jumps the clock to a time WITHOUT spawning anything it passes - the debug action for checking a late beat, or for a director that fast-forwards a tutorial the player already knows. Beats before that time are marked as played.",
		[["seconds", "float"]],
		"\n".join(PackedStringArray([
			"_clock = maxf(seconds, 0.0)",
			"_next = 0",
			"while _next < _entries.size() and _clock >= float(_entries[_next].at):",
			"\t_next += 1"
		])),
		"Skip to [b]{seconds}[/b]s")

	# --- The report ---
	Lib.append_function(sheet, "write_report", "Write Encounter Report", "Encounter Timeline",
		"Saves the Encounter Report to a text file - user://encounter_report.txt is the usual path, and lands in the app's user folder (the editor opens it from Project > Open User Data Folder). Everything in it is derived from the loaded beats, so it always matches the plan; it writes with plain file access and no editor at all, so a build server can produce it too. Warns in the output if the path cannot be written.",
		[["path", "String"]],
		"\n".join(PackedStringArray([
			"var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)",
			"if file == null:",
			"\tpush_warning(\"Encounter Timeline: could not write the report to %s (%s).\" % [path, error_string(FileAccess.get_open_error())])",
			"\treturn",
			"file.store_string(encounter_report())",
			"file.close()"
		])),
		"Write encounter report to [b]{path}[/b]")

	# --- Conditions ---
	Lib.condition(sheet, "is_running", "Encounter Is Running", "Encounter Timeline",
		"True between Start Encounter and the last beat (or Stop Encounter) - the guard that stops a second wave being started on top of the first.",
		[],
		"return _running")

	Lib.condition(sheet, "is_finished", "Encounter Is Finished", "Encounter Timeline",
		"True once the last beat has played and the encounter has stopped itself - the \"wave cleared, open the door\" branch. False while it runs, false after Stop Encounter cut it short, and false again the moment Start Encounter rewinds it.",
		[],
		"return _finished")

	Lib.condition(sheet, "is_empty", "Encounter Is Empty", "Encounter Timeline",
		"True when no plan is loaded at all - the check for \"did the designer forget the .tres\".",
		[],
		"return _entries.is_empty()")

	# --- Expressions: the clock ---
	Lib.number(sheet, "elapsed_seconds", "Elapsed Seconds", "Encounter Timeline",
		"How far into the encounter the clock has run - the number behind a wave timer.",
		[],
		"return _clock", TYPE_FLOAT)

	Lib.number(sheet, "duration", "Encounter Duration", "Encounter Timeline",
		"When the LAST beat happens, in seconds (0 for an empty plan) - the length of the whole encounter.",
		[],
		"return float(_entries[_entries.size() - 1].at) if not _entries.is_empty() else 0.0", TYPE_FLOAT)

	Lib.number(sheet, "next_entry_seconds", "Next Entry Seconds", "Encounter Timeline",
		"When the next beat is due, in seconds from the start of the encounter (-1 when none is left) - subtract Elapsed Seconds for a countdown to the next wave.",
		[],
		"return float(_entries[_next].at) if _next < _entries.size() else -1.0", TYPE_FLOAT)

	# --- Expressions: the plan ---
	Lib.number(sheet, "entry_count", "Entry Count", "Encounter Timeline",
		"How many beats the loaded plan holds.",
		[],
		"return _entries.size()", TYPE_INT)

	Lib.number(sheet, "planned_spawns", "Planned Spawn Count", "Encounter Timeline",
		"How many nodes the whole plan intends to spawn - every beat's count added up.",
		[],
		"\n".join(PackedStringArray([
			"var total: int = 0",
			"for entry: Dictionary in _entries:",
			"\ttotal += int(entry.count)",
			"return total"
		])), TYPE_INT)

	Lib.number(sheet, "spawned_count", "Spawned Count", "Encounter Timeline",
		"How many nodes this run has actually spawned so far - compare it with Planned Spawn Count to see how much of the wave is out.",
		[],
		"return _spawned", TYPE_INT)

	Lib.number(sheet, "spawns_between", "Spawns Between", "Encounter Timeline",
		"How many spawns the plan schedules in a window of time - from `from_seconds` (included) up to `to_seconds` (excluded). This is the pacing primitive: the density block of the Encounter Report is built out of it, so a graph you draw yourself agrees with the report exactly.",
		[["from_seconds", "float"], ["to_seconds", "float"]],
		"\n".join(PackedStringArray([
			"var total: int = 0",
			"for entry: Dictionary in _entries:",
			"\tvar at: float = float(entry.at)",
			"\tif at >= from_seconds and at < to_seconds:",
			"\t\ttotal += int(entry.count)",
			"return total"
		])), TYPE_INT)

	Lib.number(sheet, "entry_note_at", "Entry Note At", "Encounter Timeline",
		"The designer's note on the beat at a position, in time order (\"\" out of range) - the plain-language reminder written beside the row.",
		[["index", "int"]],
		"return str(_entries[index].note) if index >= 0 and index < _entries.size() else \"\"", TYPE_STRING)

	Lib.number(sheet, "entry_seconds_at", "Entry Seconds At", "Encounter Timeline",
		"When the beat at a position happens, in time order (-1 out of range).",
		[["index", "int"]],
		"return float(_entries[index].at) if index >= 0 and index < _entries.size() else -1.0", TYPE_FLOAT)

	Lib.number(sheet, "encounter_title", "Encounter Name", "Encounter Timeline",
		"The readable name written on the loaded encounter resource (\"Wave 3\") - the banner over an arena.",
		[],
		"return _encounter_name", TYPE_STRING)

	# --- Expressions: last spawn + the report ---
	var last_node: EventFunction = Lib.exposed_function("last_spawned_node", "Last Spawned Node", "Encounter Timeline",
		"The node spawned most recently, or nothing before the first one - place it, aim it, or hand it to another pack right inside On Entry Spawned.",
		[],
		"return _last_spawned if _last_spawned != null and is_instance_valid(_last_spawned) else null")
	last_node.return_type = TYPE_OBJECT
	last_node.return_type_name = "Node"
	sheet.functions.append(last_node)

	Lib.number(sheet, "last_spawned_group", "Last Spawned Group", "Encounter Timeline",
		"The group the most recent spawn was added to (\"\" when its beat named none).",
		[],
		"return _last_group", TYPE_STRING)

	Lib.number(sheet, "encounter_report", "Encounter Report", "Encounter Timeline",
		"The whole plan as plain text: the beat table (time, count, scene, group, note), the totals, everything the data does not say clearly, and the spawn density per 30 seconds. Every line is DERIVED from the loaded beats - nothing is written down twice - so it can never fall out of step with the encounter. Print it, show it in a debug overlay, or save it with Write Encounter Report.",
		[],
		"\n".join(PackedStringArray([
			"var lines: PackedStringArray = PackedStringArray()",
			"lines.append(\"Encounter report: %s\" % (_encounter_name if not _encounter_name.is_empty() else \"(unnamed)\"))",
			"lines.append(\"Beats: %d   Planned spawns: %d   Length: %s s\" % [_entries.size(), planned_spawns(), String.num(duration(), 2)])",
			"lines.append(\"\")",
			"lines.append(\"  at (s) | count | scene | group | note\")",
			"for entry: Dictionary in _entries:",
			"\tlines.append(\"  %s | %d | %s | %s | %s\" % [",
			"\t\tString.num(float(entry.at), 2),",
			"\t\tint(entry.count),",
			"\t\tstr(entry.scene) if not str(entry.scene).is_empty() else \"(none)\",",
			"\t\tstr(entry.group) if not str(entry.group).is_empty() else \"(none)\",",
			"\t\tstr(entry.note) if not str(entry.note).is_empty() else \"(none)\"])",
			"lines.append(\"\")",
			"var problems: PackedStringArray = _problems()",
			"if problems.is_empty():",
			"\tlines.append(\"Every beat reads cleanly.\")",
			"else:",
			"\tlines.append(\"Fields this report could not read as intended:\")",
			"\tfor problem: String in problems:",
			"\t\tlines.append(\"  %s\" % problem)",
			"lines.append(\"\")",
			"lines.append(\"Spawn density (per 30 s):\")",
			"var buckets: int = clampi(int(floor(duration() / 30.0)) + 1, 1, 240)",
			"for bucket: int in buckets:",
			"\tvar from_seconds: float = float(bucket) * 30.0",
			"\tlines.append(\"  %d-%d s: %d\" % [int(from_seconds), int(from_seconds + 30.0), spawns_between(from_seconds, from_seconds + 30.0)])",
			"return \"\\n\".join(lines)"
		])), TYPE_STRING)

	var persistence: RawCodeRow = RawCodeRow.new()
	persistence.code = "\n".join(PackedStringArray([
		"# Save-state seam: the Save System walks any node in its persist group (or targeted",
		"# by Save/Load Node State) and duck-types these two methods. Plain data only.",
		"# The plan and the cursor travel together, so a save mid-wave reopens mid-wave; already",
		"# spawned nodes are NOT saved here (they are the scene's, not the timeline's).",
		"## @ace_hidden",
		"func save_state() -> Dictionary:",
		"\treturn {",
		"\t\t\"entries\": _entries.duplicate(true),",
		"\t\t\"encounter_name\": _encounter_name,",
		"\t\t\"clock\": _clock,",
		"\t\t\"next\": _next,",
		"\t\t\"spawned\": _spawned,",
		"\t\t\"running\": _running,",
		"\t\t\"finished\": _finished",
		"\t}",
		"",
		"## @ace_hidden",
		"func load_state(state: Dictionary) -> void:",
		"\tif state.is_empty():",
		"\t\treturn",
		"\t_entries = (state.get(\"entries\", []) as Array).duplicate(true)",
		"\t_encounter_name = str(state.get(\"encounter_name\", \"\"))",
		"\t_clock = float(state.get(\"clock\", 0.0))",
		"\t_next = int(state.get(\"next\", 0))",
		"\t_spawned = int(state.get(\"spawned\", 0))",
		"\t_running = bool(state.get(\"running\", false))",
		"\t_finished = bool(state.get(\"finished\", false))",
		"\t# A save taken mid-wave reopens mid-wave, so the clock follows the state that came back",
		"\t# rather than the state the scene was authored with.",
		"\tset_process(_running)"
	]))
	sheet.events.append(persistence)

	Lib.feature_verbs(sheet, ["load_encounter", "start_encounter"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/encounter_timeline/encounter_timeline_behavior")
