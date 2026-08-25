## @ace_tags(spawning, waves, pacing, encounter)
## @ace_category("Encounter Timeline")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/encounter_timeline/icon.svg")
class_name EncounterTimelineBehavior
extends Node
## The spawn/beat timeline, worn by whatever runs the encounter: an arena, a boss, a tutorial director, ambient traffic. Load an EncounterResource (.tres) of beats - at_seconds, scene, count, group, note - then Start Encounter and the behavior ticks its own clock, spawns each beat on schedule (through the ObjectPool autoload when one is installed), and fires On Entry Spawned and On Encounter Finished. Write Encounter Report summarises the plan, spawn density included.

## The node this behavior acts on (its parent). Required host: Node.
var host: Node = null

func _enter_tree() -> void:
	host = get_parent() as Node
	if host == null:
		push_warning("EncounterTimelineBehavior behavior requires a Node parent.")

## @ace_trigger
## @ace_name("On Entry Spawned")
## @ace_category("Encounter Timeline")
signal on_entry_spawned(node: Node, group_name: String)
## @ace_trigger
## @ace_name("On Encounter Finished")
## @ace_category("Encounter Timeline")
signal on_encounter_finished

## Start the encounter as soon as this node is ready, instead of waiting for a Start Encounter action. Handy for an arena that begins the moment its scene loads; leave it off when a cutscene or a door should decide.
@export var auto_start: bool = false
## Optional: drop an EncounterResource (.tres) here to load its beats on ready - the data-driven way to plan an encounter without events. You can also load one later (or a different difficulty) with Load Encounter.
@export var encounter: Resource = null
## When on (the default), spawns go through the ObjectPool autoload IF one is registered - a long encounter then reuses nodes instead of creating and freeing them. With no ObjectPool installed, or with this off, the timeline instantiates the scene itself. Either way the triggers fire identically.
@export var use_object_pool: bool = true

# The loaded plan, kept sorted by time: one record per beat, {at, scene, count, group, note}.
# _next is the index of the beat that has not played yet, so the clock never re-reads the past.
var _entries: Array = []
var _clock: float = 0.0
var _next: int = 0
var _running: bool = false
var _finished: bool = false
var _spawned: int = 0
var _encounter_name: String = ""
# Last-spawn context, readable outside the trigger (the trigger carries the same two values).
var _last_spawned: Node = null
var _last_group: String = ""
# An explicit pool handed over by Use Object Pool Node, tried before the autoload.
var _pool_node: Node = null
# The pooling seam. Nothing here depends on the Object Pool pack: the node given to Use Object
# Pool Node, else any autoload registered at /root/ObjectPool, qualifies as long as it answers
# has_pool / create_pool / spawn - and without one the timeline instantiates the scene itself.
# One pool per scene path, created the first time that scene is needed.
func _pool() -> Node:
	if not use_object_pool:
		return null
	var pool: Node = _pool_node if _pool_node != null and is_instance_valid(_pool_node) else null
	if pool == null and is_inside_tree():
		pool = get_node_or_null("/root/ObjectPool")
	if pool == null:
		return null
	if pool.has_method("has_pool") and pool.has_method("create_pool") and pool.has_method("spawn"):
		return pool
	return null
# One instance of a scene, pooled when a pool answers. Returns nothing for a blank path or a
# scene that is not in the project - checked with ResourceLoader.exists so a typo is a quiet
# skip (and a line in the report) instead of a console full of load errors.
func _make_one(scene_path: String) -> Node:
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return null
	var pool: Node = _pool()
	if pool != null:
		if not bool(pool.call("has_pool", scene_path)):
			pool.call("create_pool", scene_path, scene_path, 0)
		return pool.call("spawn", scene_path) as Node
	var scene: PackedScene = ResourceLoader.load(scene_path) as PackedScene
	return scene.instantiate() if scene != null else null
# Where fresh spawns are parented: the running scene, so a moving spawner never drags its wave
# around by its transform. Falls back to this node when there is no scene (a headless run or a
# test). A pooled node arrives already parented, and is left where the pool put it.
func _spawn_parent() -> Node:
	if is_inside_tree() and get_tree() != null and get_tree().current_scene != null:
		return get_tree().current_scene
	return self
# Everything the plan does not say clearly, derived from the entries themselves - a beat with no
# scene, a scene that is not in the project, a count of 0, a spawn that joins no group. The report
# prints these verbatim instead of quietly rounding them away.
func _problems() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var index: int = 0
	for entry: Dictionary in _entries:
		var where: String = "beat %d at %ss" % [index + 1, String.num(float(entry.at), 2)]
		var scene_path: String = str(entry.scene)
		if scene_path.is_empty():
			out.append("%s: no scene path - it spawns nothing" % where)
		elif not ResourceLoader.exists(scene_path):
			out.append("%s: scene not found in this project (%s)" % [where, scene_path])
		if int(entry.count) <= 0:
			out.append("%s: count is 0 - it spawns nothing" % where)
		if str(entry.group).is_empty():
			out.append("%s: no group name - its spawns join no group" % where)
		index += 1
	return out

func _process(delta: float) -> void:
	advance(delta)

func _ready() -> void:
	if encounter != null:
		load_encounter(encounter)
	if auto_start:
		# Deferred so the first beat cannot spawn before the host's sheet has connected its
		# triggers - the host readies AFTER this child, and On Entry Spawned would be missed.
		start_encounter.call_deferred()

## @ace_action
## @ace_featured
## @ace_name("Load Encounter")
## @ace_category("Encounter Timeline")
## @ace_description("Loads a whole plan from an EncounterResource (.tres) - every beat with its time, scene, count, group and note - REPLACING whatever was loaded before and rewinding the clock. Rows may be written in any order; they are sorted by time as they load.")
## @ace_display_template("Load encounter [b]{resource}[/b]")
## @ace_icon("res://eventsheet_addons/encounter_timeline/icon.svg")
## @ace_codegen_template("$EncounterTimelineBehavior.load_encounter({resource})")
func load_encounter(resource: Resource) -> void:
	if resource == null:
		return
	clear_encounter()
	var raw_name: Variant = resource.get("encounter_name")
	_encounter_name = str(raw_name) if raw_name != null else ""
	for row: Dictionary in _rows(resource, "entries"):
		_insert_sorted({
			"at": maxf(_num(_cell(row, "at_seconds", 0.0)), 0.0),
			"scene": str(_cell(row, "scene_path", "")),
			"count": maxi(int(_num(_cell(row, "count", 1))), 0),
			"group": str(_cell(row, "group_name", "")),
			"note": str(_cell(row, "note", ""))
		})

## @ace_action
## @ace_name("Add Encounter Entry")
## @ace_category("Encounter Timeline")
## @ace_description("Adds one beat from a sheet, for an encounter built at runtime - a wave scaled to the player's level, a boss phase queued by the fight itself. It lands in time order wherever it belongs, even mid-encounter (a beat added before the clock has passed it still plays).")
## @ace_display_template("Add beat at [b]{at_seconds}[/b]s: [b]{count}[/b] x [b]{scene_path}[/b] into [b]{group_name}[/b]")
## @ace_icon("res://eventsheet_addons/encounter_timeline/icon.svg")
## @ace_codegen_template("$EncounterTimelineBehavior.add_entry({at_seconds}, {scene_path}, {count}, {group_name}, {note})")
func add_entry(at_seconds: float, scene_path: String, count: int, group_name: String, note: String) -> void:
	var at: int = _insert_sorted({
		"at": maxf(at_seconds, 0.0),
		"scene": scene_path,
		"count": maxi(count, 0),
		"group": group_name,
		"note": note
	})
	# A beat inserted BEFORE the cursor is one the clock has already run past, so the cursor
	# steps over it: adding an early beat mid-encounter must not replay it, and must not push
	# the next real beat out of reach either.
	if at < _next:
		_next += 1

## @ace_action
## @ace_name("Clear Encounter")
## @ace_category("Encounter Timeline")
## @ace_description("Empties the plan and rewinds everything - no beats, clock at 0, nothing running. Load Encounter does this for you; call it yourself before building a plan out of Add Encounter Entry rows.")
## @ace_icon("res://eventsheet_addons/encounter_timeline/icon.svg")
## @ace_codegen_template("$EncounterTimelineBehavior.clear_encounter()")
func clear_encounter() -> void:
	_entries.clear()
	_clock = 0.0
	_next = 0
	_spawned = 0
	_running = false
	_finished = false

## @ace_action
## @ace_featured
## @ace_name("Start Encounter")
## @ace_category("Encounter Timeline")
## @ace_description("Runs the plan from the top: the clock restarts at 0, the spawn tally resets, and each beat fires as its time arrives. An encounter with no beats finishes on its very next frame, so On Encounter Finished still tells you the wave is over.")
## @ace_icon("res://eventsheet_addons/encounter_timeline/icon.svg")
## @ace_codegen_template("$EncounterTimelineBehavior.start_encounter()")
func start_encounter() -> void:
	_clock = 0.0
	_next = 0
	_spawned = 0
	_running = true
	_finished = false

## @ace_action
## @ace_name("Stop Encounter")
## @ace_category("Encounter Timeline")
## @ace_description("Freezes the encounter where it stands - the clock stops and no further beat spawns. Already-spawned nodes are left alone (they are yours). Elapsed Seconds keeps its value, so a paused wave can be inspected; Start Encounter restarts from the top.")
## @ace_icon("res://eventsheet_addons/encounter_timeline/icon.svg")
## @ace_codegen_template("$EncounterTimelineBehavior.stop_encounter()")
func stop_encounter() -> void:
	_running = false

## @ace_action
## @ace_name("Use Object Pool Node")
## @ace_category("Encounter Timeline")
## @ace_description("Spawns through THIS pool node instead of searching for the ObjectPool autoload - for a per-arena pool, or a pool you wrote yourself. The contract is three functions: has_pool(name), create_pool(name, scene_path, prewarm) and spawn(name); a node missing any of them is ignored and the timeline instantiates scenes as usual. Pass nothing to go back to the autoload.")
## @ace_display_template("Use object pool node [i]{node}[/i]")
## @ace_icon("res://eventsheet_addons/encounter_timeline/icon.svg")
## @ace_codegen_template("$EncounterTimelineBehavior.use_pool_node({node})")
func use_pool_node(node: Node) -> void:
	_pool_node = node

## @ace_action
## @ace_name("Skip To")
## @ace_category("Encounter Timeline")
## @ace_description("Jumps the clock to a time WITHOUT spawning anything it passes - the debug action for checking a late beat, or for a director that fast-forwards a tutorial the player already knows. Beats before that time are marked as played.")
## @ace_display_template("Skip to [b]{seconds}[/b]s")
## @ace_icon("res://eventsheet_addons/encounter_timeline/icon.svg")
## @ace_codegen_template("$EncounterTimelineBehavior.skip_to({seconds})")
func skip_to(seconds: float) -> void:
	_clock = maxf(seconds, 0.0)
	_next = 0
	while _next < _entries.size() and _clock >= float(_entries[_next].at):
		_next += 1

## @ace_action
## @ace_name("Write Encounter Report")
## @ace_category("Encounter Timeline")
## @ace_description("Saves the Encounter Report to a text file - user://encounter_report.txt is the usual path, and lands in the app's user folder (the editor opens it from Project > Open User Data Folder). Everything in it is derived from the loaded beats, so it always matches the plan; it writes with plain file access and no editor at all, so a build server can produce it too. Warns in the output if the path cannot be written.")
## @ace_display_template("Write encounter report to [b]{path}[/b]")
## @ace_icon("res://eventsheet_addons/encounter_timeline/icon.svg")
## @ace_codegen_template("$EncounterTimelineBehavior.write_report({path})")
func write_report(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Encounter Timeline: could not write the report to %s (%s)." % [path, error_string(FileAccess.get_open_error())])
		return
	file.store_string(encounter_report())
	file.close()

## @ace_condition
## @ace_name("Encounter Is Running")
## @ace_category("Encounter Timeline")
## @ace_description("True between Start Encounter and the last beat (or Stop Encounter) - the guard that stops a second wave being started on top of the first.")
## @ace_icon("res://eventsheet_addons/encounter_timeline/icon.svg")
## @ace_codegen_template("$EncounterTimelineBehavior.is_running()")
func is_running() -> bool:
	return _running

## @ace_condition
## @ace_name("Encounter Is Finished")
## @ace_category("Encounter Timeline")
## @ace_description("True once the last beat has played and the encounter has stopped itself - the "wave cleared, open the door" branch. False while it runs, false after Stop Encounter cut it short, and false again the moment Start Encounter rewinds it.")
## @ace_icon("res://eventsheet_addons/encounter_timeline/icon.svg")
## @ace_codegen_template("$EncounterTimelineBehavior.is_finished()")
func is_finished() -> bool:
	return _finished

## @ace_condition
## @ace_name("Encounter Is Empty")
## @ace_category("Encounter Timeline")
## @ace_description("True when no plan is loaded at all - the check for "did the designer forget the .tres".")
## @ace_icon("res://eventsheet_addons/encounter_timeline/icon.svg")
## @ace_codegen_template("$EncounterTimelineBehavior.is_empty()")
func is_empty() -> bool:
	return _entries.is_empty()

## @ace_expression
## @ace_name("Elapsed Seconds")
## @ace_category("Encounter Timeline")
## @ace_description("How far into the encounter the clock has run - the number behind a wave timer.")
## @ace_icon("res://eventsheet_addons/encounter_timeline/icon.svg")
## @ace_codegen_template("$EncounterTimelineBehavior.elapsed_seconds()")
func elapsed_seconds() -> float:
	return _clock

## @ace_expression
## @ace_name("Encounter Duration")
## @ace_category("Encounter Timeline")
## @ace_description("When the LAST beat happens, in seconds (0 for an empty plan) - the length of the whole encounter.")
## @ace_icon("res://eventsheet_addons/encounter_timeline/icon.svg")
## @ace_codegen_template("$EncounterTimelineBehavior.duration()")
func duration() -> float:
	return float(_entries[_entries.size() - 1].at) if not _entries.is_empty() else 0.0

## @ace_expression
## @ace_name("Next Entry Seconds")
## @ace_category("Encounter Timeline")
## @ace_description("When the next beat is due, in seconds from the start of the encounter (-1 when none is left) - subtract Elapsed Seconds for a countdown to the next wave.")
## @ace_icon("res://eventsheet_addons/encounter_timeline/icon.svg")
## @ace_codegen_template("$EncounterTimelineBehavior.next_entry_seconds()")
func next_entry_seconds() -> float:
	return float(_entries[_next].at) if _next < _entries.size() else -1.0

## @ace_expression
## @ace_name("Entry Count")
## @ace_category("Encounter Timeline")
## @ace_description("How many beats the loaded plan holds.")
## @ace_icon("res://eventsheet_addons/encounter_timeline/icon.svg")
## @ace_codegen_template("$EncounterTimelineBehavior.entry_count()")
func entry_count() -> int:
	return _entries.size()

## @ace_expression
## @ace_name("Planned Spawn Count")
## @ace_category("Encounter Timeline")
## @ace_description("How many nodes the whole plan intends to spawn - every beat's count added up.")
## @ace_icon("res://eventsheet_addons/encounter_timeline/icon.svg")
## @ace_codegen_template("$EncounterTimelineBehavior.planned_spawns()")
func planned_spawns() -> int:
	var total: int = 0
	for entry: Dictionary in _entries:
		total += int(entry.count)
	return total

## @ace_expression
## @ace_name("Spawned Count")
## @ace_category("Encounter Timeline")
## @ace_description("How many nodes this run has actually spawned so far - compare it with Planned Spawn Count to see how much of the wave is out.")
## @ace_icon("res://eventsheet_addons/encounter_timeline/icon.svg")
## @ace_codegen_template("$EncounterTimelineBehavior.spawned_count()")
func spawned_count() -> int:
	return _spawned

## @ace_expression
## @ace_name("Spawns Between")
## @ace_category("Encounter Timeline")
## @ace_description("How many spawns the plan schedules in a window of time - from `from_seconds` (included) up to `to_seconds` (excluded). This is the pacing primitive: the density block of the Encounter Report is built out of it, so a graph you draw yourself agrees with the report exactly.")
## @ace_icon("res://eventsheet_addons/encounter_timeline/icon.svg")
## @ace_codegen_template("$EncounterTimelineBehavior.spawns_between({from_seconds}, {to_seconds})")
func spawns_between(from_seconds: float, to_seconds: float) -> int:
	var total: int = 0
	for entry: Dictionary in _entries:
		var at: float = float(entry.at)
		if at >= from_seconds and at < to_seconds:
			total += int(entry.count)
	return total

## @ace_expression
## @ace_name("Entry Note At")
## @ace_category("Encounter Timeline")
## @ace_description("The designer's note on the beat at a position, in time order ("" out of range) - the plain-language reminder written beside the row.")
## @ace_icon("res://eventsheet_addons/encounter_timeline/icon.svg")
## @ace_codegen_template("$EncounterTimelineBehavior.entry_note_at({index})")
func entry_note_at(index: int) -> String:
	return str(_entries[index].note) if index >= 0 and index < _entries.size() else ""

## @ace_expression
## @ace_name("Entry Seconds At")
## @ace_category("Encounter Timeline")
## @ace_description("When the beat at a position happens, in time order (-1 out of range).")
## @ace_icon("res://eventsheet_addons/encounter_timeline/icon.svg")
## @ace_codegen_template("$EncounterTimelineBehavior.entry_seconds_at({index})")
func entry_seconds_at(index: int) -> float:
	return float(_entries[index].at) if index >= 0 and index < _entries.size() else -1.0

## @ace_expression
## @ace_name("Encounter Name")
## @ace_category("Encounter Timeline")
## @ace_description("The readable name written on the loaded encounter resource ("Wave 3") - the banner over an arena.")
## @ace_icon("res://eventsheet_addons/encounter_timeline/icon.svg")
## @ace_codegen_template("$EncounterTimelineBehavior.encounter_title()")
func encounter_title() -> String:
	return _encounter_name

## @ace_expression
## @ace_name("Last Spawned Node")
## @ace_category("Encounter Timeline")
## @ace_description("The node spawned most recently, or nothing before the first one - place it, aim it, or hand it to another pack right inside On Entry Spawned.")
## @ace_icon("res://eventsheet_addons/encounter_timeline/icon.svg")
## @ace_codegen_template("$EncounterTimelineBehavior.last_spawned_node()")
func last_spawned_node() -> Node:
	return _last_spawned if _last_spawned != null and is_instance_valid(_last_spawned) else null

## @ace_expression
## @ace_name("Last Spawned Group")
## @ace_category("Encounter Timeline")
## @ace_description("The group the most recent spawn was added to ("" when its beat named none).")
## @ace_icon("res://eventsheet_addons/encounter_timeline/icon.svg")
## @ace_codegen_template("$EncounterTimelineBehavior.last_spawned_group()")
func last_spawned_group() -> String:
	return _last_group

## @ace_expression
## @ace_name("Encounter Report")
## @ace_category("Encounter Timeline")
## @ace_description("The whole plan as plain text: the beat table (time, count, scene, group, note), the totals, everything the data does not say clearly, and the spawn density per 30 seconds. Every line is DERIVED from the loaded beats - nothing is written down twice - so it can never fall out of step with the encounter. Print it, show it in a debug overlay, or save it with Write Encounter Report.")
## @ace_icon("res://eventsheet_addons/encounter_timeline/icon.svg")
## @ace_codegen_template("$EncounterTimelineBehavior.encounter_report()")
func encounter_report() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Encounter report: %s" % (_encounter_name if not _encounter_name.is_empty() else "(unnamed)"))
	lines.append("Beats: %d   Planned spawns: %d   Length: %s s" % [_entries.size(), planned_spawns(), String.num(duration(), 2)])
	lines.append("")
	lines.append("  at (s) | count | scene | group | note")
	for entry: Dictionary in _entries:
		lines.append("  %s | %d | %s | %s | %s" % [
			String.num(float(entry.at), 2),
			int(entry.count),
			str(entry.scene) if not str(entry.scene).is_empty() else "(none)",
			str(entry.group) if not str(entry.group).is_empty() else "(none)",
			str(entry.note) if not str(entry.note).is_empty() else "(none)"])
	lines.append("")
	var problems: PackedStringArray = _problems()
	if problems.is_empty():
		lines.append("Every beat reads cleanly.")
	else:
		lines.append("Fields this report could not read as intended:")
		for problem: String in problems:
			lines.append("  %s" % problem)
	lines.append("")
	lines.append("Spawn density (per 30 s):")
	var buckets: int = clampi(int(floor(duration() / 30.0)) + 1, 1, 240)
	for bucket: int in buckets:
		var from_seconds: float = float(bucket) * 30.0
		lines.append("  %d-%d s: %d" % [int(from_seconds), int(from_seconds + 30.0), spawns_between(from_seconds, from_seconds + 30.0)])
	return "\n".join(lines)

## @ace_hidden
func advance(delta: float) -> void:
	# The clock. A while loop (not an if) so one huge delta - a stall, a loading hitch - plays every
	# beat it crossed rather than dropping all but the last. Deliberately unpublished: the behavior
	# drives it from its own _process row, so a sheet never has to hand it a delta.
	if not _running:
		return
	_clock += delta
	while _next < _entries.size() and _clock >= float(_entries[_next].at):
		_spawn_entry(_entries[_next])
		_next += 1
	if _next >= _entries.size():
		_running = false
		_finished = true
		on_encounter_finished.emit()

func _spawn_entry(entry: Dictionary) -> void:
	# Plays one beat: count copies, each added to the beat's group (persistent, so the group survives
	# being packed into a scene) and announced individually. A beat with no scene still fires nothing
	# per node - use its note and On Encounter Finished, or give it a scene.
	var group_name: String = str(entry.group)
	for _i: int in maxi(int(entry.count), 0):
		var node: Node = _make_one(str(entry.scene))
		if node == null:
			continue
		if not group_name.is_empty():
			node.add_to_group(group_name, true)
		if node.get_parent() == null:
			_spawn_parent().add_child(node)
		_spawned += 1
		_last_spawned = node
		_last_group = group_name
		on_entry_spawned.emit(node, group_name)

func _insert_sorted(entry: Dictionary) -> int:
	# Inserts a beat in time order without a sort callable, so the plan is always ordered and
	# equal times keep the order they were written in. Returns where it landed, which is what lets
	# a beat added mid-encounter re-seat the cursor correctly.
	var at: int = _entries.size()
	var index: int = 0
	for existing: Dictionary in _entries:
		if float(existing.at) > float(entry.at):
			at = index
			break
		index += 1
	_entries.insert(at, entry)
	return at

func _rows(source: Variant, field: String) -> Array:
	# A grid off an EncounterResource (a property). Returns an Array of row dicts; a stray
	# non-Dictionary element (a hand-edited .tres) is dropped rather than crashing the typed loops.
	var raw: Variant = source.get(field)
	if not raw is Array:
		return []
	var out: Array = []
	for element: Variant in raw:
		if element is Dictionary:
			out.append(element)
	return out

func _cell(row: Dictionary, key: String, fallback: Variant) -> Variant:
	# One cell off a row, treating a PRESENT-but-null value as missing so the default still applies
	# (Dictionary.get only falls back when the key is ABSENT).
	var value: Variant = row.get(key, fallback)
	return fallback if value == null else value

func _num(value: Variant) -> float:
	if value is float or value is int:
		return float(value)
	if value is String and (value as String).is_valid_float():
		return (value as String).to_float()
	return 0.0

## @ace_hidden
func save_state() -> Dictionary:
	# Save-state seam: the Save System walks any node in its persist group (or targeted
	# by Save/Load Node State) and duck-types these two methods. Plain data only.
	# The plan and the cursor travel together, so a save mid-wave reopens mid-wave; already
	# spawned nodes are NOT saved here (they are the scene's, not the timeline's).
	return {
		"entries": _entries.duplicate(true),
		"encounter_name": _encounter_name,
		"clock": _clock,
		"next": _next,
		"spawned": _spawned,
		"running": _running,
		"finished": _finished
	}

## @ace_hidden
func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_entries = (state.get("entries", []) as Array).duplicate(true)
	_encounter_name = str(state.get("encounter_name", ""))
	_clock = float(state.get("clock", 0.0))
	_next = int(state.get("next", 0))
	_spawned = int(state.get("spawned", 0))
	_running = bool(state.get("running", false))
	_finished = bool(state.get("finished", false))

# Encounter Timeline behavior: attach it to whatever runs the encounter and drop an Encounter resource (.tres) on its slot. Start Encounter plays the beats back on their own clock - the behavior ticks itself, so there is nothing to drive from a sheet - spawning each beat's scene at its at_seconds, adding every copy to the beat's group, and firing On Entry Spawned per node then On Encounter Finished after the last beat. It spawns through the ObjectPool autoload when one is installed and instantiates the scene when none is. Write Encounter Report saves a plain-text plan of the whole encounter. This pack is an event sheet - extend it by editing it.
