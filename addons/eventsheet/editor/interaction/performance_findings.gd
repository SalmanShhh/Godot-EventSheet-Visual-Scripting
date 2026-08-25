# Godot EventSheets - the six classic ways a sheet spends a frame, found by reading the sheet.
#
# Every one of them is the same mistake in a different costume: work that happens sixty times a
# second when it needed to happen once. None of them is a bug - the game runs, nothing errors, the
# frame is just slower than it had to be - which is exactly why they survive to shipping.
#
#   looked up every tick   - a row resolves a node path that never changes, every frame.
#   scans every tick       - a row walks a group or a child list every frame for an answer that
#                            changes rarely.
#   distance, root paid    - a row takes a square root to compare two distances.
#   heavy loop in a frame  - a row loops a large literal count inside a per-tick event.
#   made and freed         - one per-tick row makes an instance and another frees one.
#   text rebuilt           - a per-tick row writes a label's text whether or not it changed.
#
# NOTHING is stored: each finding is derived from the rows and the lines they compile to, so a fixed
# sheet stops reporting it with nothing to clean up. A sheet with no per-tick event earns NO
# findings at all - which is most menu sheets, most option screens, and every sheet that only reacts
# to signals.
#
# Two of the repairs are row edits the plugin makes itself, through the same undo funnel every other
# change uses; the rest are named with the shipped thing that solves them, because routing a loop
# through a behaviour is a decision about the game and not a line to rewrite.
#
# PURE + STATIC: no viewport, no dialog, no display server, so every word is pinned headless.
@tool
class_name EventSheetPerformanceFindings
extends RefCounted

## The six, by id. Frozen: the note rows, the Doctor and the tests all address one by these.
const KIND_CONSTANT_LOOKUP := "looked-up-every-tick"
const KIND_FULL_SCAN := "scans-every-tick"
const KIND_DISTANCE_ROOT := "distance-root-every-tick"
const KIND_HEAVY_LOOP := "heavy-loop-in-one-frame"
const KIND_SPAWN_CHURN := "made-and-freed-every-tick"
const KIND_SAME_TEXT := "text-rebuilt-every-tick"

## The repairs. The first two are row edits the plugin performs; the last two open the dialog that
## adds the shipped behaviour, because the wiring is the offer and the decision stays the author's.
const FIX_HOIST := "hoist_lookup"
const FIX_EVERY_N := "recheck_every"
const FIX_TIME_SLICER := "route_time_slicer"
const FIX_OBJECT_POOL := "route_object_pool"

## Which repairs keep the game's behaviour exactly - only the emitted code changes. These are the
## ones "Apply the safe fixes" is allowed to batch into a single undo step; every other repair
## changes WHEN something happens and stays a decision made one row at a time.
const SAFE_FIXES: PackedStringArray = [FIX_HOIST]

## The note hangs under the event that has the problem - all six are about a row.
const ANCHOR_EVENT := "event"

## How many turns of a literal loop is enough to be worth spreading over frames. A dozen tiles is
## nothing; two hundred in one tick is a visible hitch on a slow machine.
const HEAVY_ITERATIONS := 200

## The seconds the re-check fix writes. Five times a second is invisible to a player and twelve
## times cheaper than every frame - and it is a plain number in a plain row, so it is tunable.
const RECHECK_SECONDS := "0.2"

## The triggers that mean "every frame". A top-level event with NO trigger means the same thing,
## which is why the walk below treats an empty one as a tick at the top level only.
const TICK_TRIGGERS: PackedStringArray = ["OnProcess", "OnPhysicsProcess"]


## Every finding this sheet earns, in the order the rules run. Empty for a sheet with nothing
## happening every frame, which is what keeps a menu sheet exactly as it was.
static func findings(sheet: EventSheetResource) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if sheet == null:
		return found
	var rows: Array[Dictionary] = tick_rows(sheet)
	if rows.is_empty():
		return found
	_looked_up_every_tick(rows, found)
	_scans_every_tick(rows, found)
	_distance_root(rows, found)
	_heavy_loop(rows, found)
	_made_and_freed(rows, found)
	_text_rebuilt(rows, found)
	return found


## The findings anchored at one event row - what the canvas hangs under it. Matched by IDENTITY, so
## the caller never has to name a row that has no name.
static func for_event(found: Array[Dictionary], event_row: EventRow) -> Array[Dictionary]:
	var mine: Array[Dictionary] = []
	if event_row == null:
		return mine
	for entry: Dictionary in found:
		if is_same(entry.get("event"), event_row):
			mine.append(entry)
	return mine


## The findings whose repair is provably semantics-preserving - what the batch button applies.
static func safe(found: Array[Dictionary]) -> Array[Dictionary]:
	var mine: Array[Dictionary] = []
	for entry: Dictionary in found:
		if SAFE_FIXES.has(str(entry.get("fix", ""))):
			mine.append(entry)
	return mine


## Every picked row that runs EVERY FRAME, with the one fact the rules need about it: the line it
## compiles to. One walk, six rules - a second walk would be a second answer to the same question.
## Rows under a signal trigger are not here at all: a row that runs when something happens is not
## spending the frame, however it is written.
static func tick_rows(sheet: EventSheetResource) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if sheet == null:
		return rows
	_walk(sheet.events, false, true, rows)
	return rows


static func _walk(items: Array, inside_tick: bool, top_level: bool, into: Array[Dictionary]) -> void:
	for item: Variant in items:
		if item is EventGroup:
			_walk(EventSheetGroupFacts.children(item as EventGroup), inside_tick, top_level, into)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		var ticks: bool = inside_tick or _is_tick_trigger(event_row.trigger_id, top_level)
		if ticks:
			for is_action: bool in [false, true]:
				var lane: Array = event_row.actions if is_action else event_row.conditions
				for index: int in range(lane.size()):
					if lane[index] is Resource:
						into.append({
							"event": event_row, "ace": lane[index] as Resource,
							# The row a fix rewrites is named by its LANE and SLOT rather than held:
							# the fix runs through the undo funnel, and the funnel replaces resources
							# as it commits.
							"lane": "actions" if is_action else "conditions", "index": index,
							"line": EventSheetLightingFindings.compiled_line(lane[index] as Resource),
						})
		_walk(event_row.sub_events, ticks, false, into)


## True when this trigger means "every frame". A blank trigger says it only at the TOP level: a
## sub-event with no trigger runs when its parent does, and inherits whatever that was.
static func _is_tick_trigger(trigger_id: String, top_level: bool) -> bool:
	var declared: String = trigger_id.strip_edges()
	if declared.is_empty():
		return top_level
	return TICK_TRIGGERS.has(declared)


# -- The six rules --------------------------------------------------------------------------------


## A row that resolves a node path every frame for a node that has been in the same place since the
## scene loaded. The only one of the six whose repair changes nothing but the emitted line, which is
## why it is the only one the batch button touches.
static func _looked_up_every_tick(rows: Array[Dictionary], found: Array[Dictionary]) -> void:
	for context: Dictionary in rows:
		var path: String = constant_path_in(str(context.get("line", "")))
		if path.is_empty():
			continue
		# WHICH parameter holds it, because the fix rewrites that one value and leaves the rest of
		# the row exactly as the author wrote it. A path baked into the template itself and not into
		# a parameter is not this finding: there is nothing to point somewhere else.
		var param: String = param_holding(context.get("ace") as Resource, path)
		if param.is_empty():
			continue
		var finding: Dictionary = _finding(KIND_CONSTANT_LOOKUP, context, path,
			EventSheetL10n.translate("%s is looked up every frame and never moves. Remember it once, at ready time, and the row reads the same.") % path,
			FIX_HOIST, EventSheetL10n.translate("Remember it once"))
		finding["param"] = param
		found.append(finding)


## A row that walks a whole group (or a whole child list) every frame. The answer usually changes
## once a second, so the repair asks how often it really needs asking.
static func _scans_every_tick(rows: Array[Dictionary], found: Array[Dictionary]) -> void:
	for context: Dictionary in rows:
		var line: String = str(context.get("line", ""))
		if not (line.contains("get_nodes_in_group(") or line.contains(".get_children()")):
			continue
		found.append(_finding(KIND_FULL_SCAN, context, "",
			EventSheetL10n.translate("This looks at every object in the group, sixty times a second. Ask less often, or ask when something changes."),
			FIX_EVERY_N, EventSheetL10n.translate("Re-check every %s s") % RECHECK_SECONDS))


## A distance compared against a number pays a square root to answer a question that never needed
## one. Said, not repaired: the row reads as a distance, and a row that reads as a distance and
## compiles to a squared one is a sheet that lies about itself.
static func _distance_root(rows: Array[Dictionary], found: Array[Dictionary]) -> void:
	for context: Dictionary in rows:
		if not str(context.get("line", "")).contains(".distance_to("):
			continue
		found.append(_finding(KIND_DISTANCE_ROOT, context, "",
			EventSheetL10n.translate("Measuring a distance takes a square root every frame. Where you are only comparing it to a number, comparing the squared distances answers the same question for less."),
			"", ""))


## A loop with a large literal count inside a per-tick event: the whole of it happens between two
## drawn frames, and the frame it lands in is the one that stutters.
static func _heavy_loop(rows: Array[Dictionary], found: Array[Dictionary]) -> void:
	for context: Dictionary in rows:
		var turns: int = literal_loop_count(str(context.get("line", "")))
		if turns < HEAVY_ITERATIONS:
			continue
		found.append(_finding(KIND_HEAVY_LOOP, context, str(turns),
			EventSheetL10n.translate("%d turns of this loop happen in one frame. The Time Slicer behaviour spreads that work over several, on a budget you set.") % turns,
			FIX_TIME_SLICER, EventSheetL10n.translate("Add the Time Slicer…")))


## One per-tick row makes an instance and another frees one: the allocator is doing the work the
## game is not. The Object Pool behaviour is the shipped answer; the offer is the wiring.
static func _made_and_freed(rows: Array[Dictionary], found: Array[Dictionary]) -> void:
	var makes: Dictionary = {}
	var frees: bool = false
	for context: Dictionary in rows:
		var line: String = str(context.get("line", ""))
		if line.contains(".instantiate()"):
			makes[context.get("event")] = context
		elif line.contains("queue_free()") or line.contains(".free()"):
			frees = true
	if not frees:
		return
	for context: Variant in makes.values():
		found.append(_finding(KIND_SPAWN_CHURN, context as Dictionary, "",
			EventSheetL10n.translate("This makes a new copy every frame while another row frees one. The Object Pool behaviour hands out the same copies again instead."),
			FIX_OBJECT_POOL, EventSheetL10n.translate("Add the Object Pool…")))


## A label written every frame, whether or not the words changed. Setting a Label's text is not
## free: it re-shapes the line and re-draws it.
static func _text_rebuilt(rows: Array[Dictionary], found: Array[Dictionary]) -> void:
	for context: Dictionary in rows:
		var line: String = str(context.get("line", ""))
		if not (line.contains(".text = ") or line.begins_with("text = ")):
			continue
		found.append(_finding(KIND_SAME_TEXT, context, "",
			EventSheetL10n.translate("The text is written every frame, even when it has not changed. Move this under the event that changes the value and it is written once per change."),
			"", ""))


## One finding, in the shape the note rows and the Doctor both read - plus what the last profiled
## run said this row cost, when there is one, so a finding on a row nobody has ever paid for reads
## differently from a finding on the row eating the frame.
static func _finding(kind: String, context: Dictionary, subject: String, message: String,
		fix: String, fix_label: String) -> Dictionary:
	var event_row: EventRow = context.get("event") as EventRow
	var uid: String = "" if event_row == null else event_row.event_uid
	return {
		"kind": kind, "severity": "warning", "anchor": ANCHOR_EVENT,
		"event": event_row, "subject": subject, "message": message,
		"fix": fix, "fix_label": fix_label,
		"lane": str(context.get("lane", "")), "index": int(context.get("index", -1)), "param": "",
		"safe": SAFE_FIXES.has(fix),
		"measured_ms": EventSheetRunProfile.ms_for(uid) if not uid.is_empty() else -1.0,
	}


## The parameter of one row whose VALUE carries `needle`, or "" when no parameter does (the value is
## baked into the template, or the row was authored with the path in a place a fix cannot reach).
static func param_holding(ace: Resource, needle: String) -> String:
	if ace == null or needle.is_empty():
		return ""
	var params: Variant = ace.get("params")
	if not (params is Dictionary) or (params as Dictionary).is_empty():
		params = ace.get("parameters")
	if not (params is Dictionary):
		return ""
	for key: Variant in params as Dictionary:
		if str((params as Dictionary)[key]).contains(needle):
			return str(key)
	return ""


## The node path a line resolves from a LITERAL, or "" when it resolves one it worked out. A path
## built from a variable is a different node each time and cannot be remembered once.
static func constant_path_in(line: String) -> String:
	var quoted: RegEx = RegEx.new()
	quoted.compile("get_node\\(\\s*\"([^\"]+)\"\\s*\\)")
	var found: RegExMatch = quoted.search(line)
	if found != null:
		return found.get_string(1)
	var dollar: RegEx = RegEx.new()
	dollar.compile("\\$([A-Za-z_%][A-Za-z0-9_/%]*)")
	found = dollar.search(line)
	return "" if found == null else found.get_string(1)


## How many turns a literal `range(...)` in this line takes, or 0 when the count is worked out at
## runtime. Only the one-argument form is read: `range(a, b)` with names in it is not a literal, and
## guessing at it would put a number in a sentence nobody can check.
static func literal_loop_count(line: String) -> int:
	if not line.contains("for "):
		return 0
	var counted: RegEx = RegEx.new()
	counted.compile("range\\(\\s*(\\d+)\\s*\\)")
	var found: RegExMatch = counted.search(line)
	return 0 if found == null else int(found.get_string(1))


## A variable name for a remembered node path: "UI/Bar" -> "ui_bar", "%HealthBar" -> "health_bar".
## Deterministic, so the same path always earns the same name and applying the fix twice in two
## sheets reads the same way in both.
static func remembered_name(path: String) -> String:
	var cleaned: String = path.replace("%", "").replace("/", "_").replace(".", "_")
	var snake: String = cleaned.to_snake_case().strip_edges()
	while snake.contains("__"):
		snake = snake.replace("__", "_")
	snake = snake.lstrip("_")
	return "the_" + snake if snake.is_empty() or snake[0].is_valid_int() else snake
