@tool
class_name EventSheetRepeatedRows
extends RefCounted
# Tools ▸ Find Repeated Rows… - the scan whose fix is the shipped extraction.
#
# The abstraction lever ships: right-click an event ▸ Extract All Actions to Function… turns a run
# of actions into one named verb. What it cannot do is NOTICE. A sheet past a few hundred rows has
# copy-paste runs its author has forgotten, and the lever only ever acts on the one site you already
# picked. This scans for identical ORDERED runs of actions occurring twice or more, ranks them by
# rows saved, and offers each as one gesture: name it, extract it at the first site, replace every
# other occurrence with a Call - all in ONE undo step.
#
# The scan (repeated_runs) is static and pure over the sheet, so it is pinned headless. The fix is
# not re-implemented here: it calls EventSheetExtractOps.extract_actions_to_function for the first
# site and then rewrites the remaining sites, so the two gestures can never drift apart.
#
# THE SHIPPED CONSTRAINT, respected: the extractor refuses a run that depends on an event-local or a
# For-Each iterator it cannot turn into a parameter, and a run whose sites would each need DIFFERENT
# arguments cannot be one call anyway. Such runs are listed and marked "needs parameters" rather
# than offered as a one-click fix that would fail.

var _dock: Control = null

var window: Window = null
var tree: Tree = null
var summary_label: Label = null
var make_verb_button: Button = null

var _runs: Array = []


func init(dock: Control) -> void:
	_dock = dock


## A stable, comparable signature for one action row. Two actions with the same signature emit the
## same line, which is what makes a run a repeat rather than a coincidence: the provider, the verb,
## the baked template and every parameter value all take part. Anything the scan does not model
## (a custom block, a Match row) gets a signature unique to that instance, so a run simply stops
## there instead of matching two things that are not the same.
static func action_signature(action: Resource) -> String:
	if action is ACEAction:
		var ace: ACEAction = action as ACEAction
		var keys: Array = ace.params.keys()
		keys.sort()
		var parts: PackedStringArray = PackedStringArray()
		for key: Variant in keys:
			parts.append("%s=%s" % [str(key), str(ace.params[key])])
		return "ace|%s|%s|%s|%s" % [ace.provider_id, ace.ace_id, ace.codegen_template, "|".join(parts)]
	if action is RawCodeRow:
		return "raw|%s" % (action as RawCodeRow).code.strip_edges()
	return "other|%d" % action.get_instance_id()


## Identical ordered runs of actions appearing `min_occurrences`+ times across the sheet's events,
## ranked by rows saved. Returns [{signature, length, rows_saved, needs_parameters, labels,
## occurrences: [{event, start_index}]}] - `labels` being the run's action labels for display.
##
## Overlap rule: the LONGEST, most-repeated run wins, and no reported occurrence overlaps another
## reported one. Without it, a four-row repeat would also be reported as three two-row repeats,
## and extracting one of them would corrupt the others.
static func repeated_runs(sheet: EventSheetResource, min_length: int = 2, min_occurrences: int = 2) -> Array:
	if sheet == null:
		return []
	var events: Array = []
	_collect_events(sheet.events, events)
	var candidates: Dictionary = {}
	for event: EventRow in events:
		var signatures: PackedStringArray = PackedStringArray()
		for action: Variant in event.actions:
			signatures.append(action_signature(action as Resource) if action is Resource else "other|null")
		for start: int in range(signatures.size()):
			for length: int in range(min_length, signatures.size() - start + 1):
				var signature: String = "|||".join(signatures.slice(start, start + length))
				if not candidates.has(signature):
					candidates[signature] = {"length": length, "occurrences": []}
				(candidates[signature]["occurrences"] as Array).append({"event": event, "start_index": start})
	var ranked: Array = []
	for signature: String in candidates:
		var candidate: Dictionary = candidates[signature]
		var occurrences: Array = candidate["occurrences"]
		if occurrences.size() < min_occurrences:
			continue
		ranked.append({
			"signature": signature,
			"length": int(candidate["length"]),
			"occurrences": occurrences,
			"rows_saved": (occurrences.size() - 1) * int(candidate["length"]),
		})
	# Longest first, then most rows saved: the greedy pass below keeps the biggest true repeat and
	# drops every fragment of it.
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["length"]) != int(b["length"]):
			return int(a["length"]) > int(b["length"])
		return int(a["rows_saved"]) > int(b["rows_saved"]))
	var taken: Dictionary = {}
	var results: Array = []
	for candidate: Dictionary in ranked:
		var length: int = int(candidate["length"])
		var kept: Array = []
		for occurrence: Dictionary in (candidate["occurrences"] as Array):
			if not _claims(taken, occurrence, length, false):
				kept.append(occurrence)
		if kept.size() < min_occurrences:
			continue
		for occurrence: Dictionary in kept:
			_claims(taken, occurrence, length, true)
		candidate["occurrences"] = kept
		candidate["rows_saved"] = (kept.size() - 1) * length
		candidate["needs_parameters"] = _needs_parameters(kept, length)
		candidate["labels"] = _run_labels(kept[0] as Dictionary, length)
		results.append(candidate)
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["rows_saved"]) > int(b["rows_saved"]))
	return results


## Whether the occurrence's action span touches one already claimed; `claim` marks it as taken.
## One dictionary keyed by "<event id>:<action index>" - overlap is exactly "the same action row
## appears in two reported runs".
static func _claims(taken: Dictionary, occurrence: Dictionary, length: int, claim: bool) -> bool:
	var event: EventRow = occurrence["event"] as EventRow
	var start: int = int(occurrence["start_index"])
	for offset: int in range(length):
		var key: String = "%d:%d" % [event.get_instance_id(), start + offset]
		if claim:
			taken[key] = true
		elif taken.has(key):
			return true
	return false


## True when this run cannot become one shared verb: some site references an event-local or a
## For-Each iterator, so the extraction would either refuse or need per-site arguments. Such a run
## is worth SEEING (it is still duplication) but must not be offered as a one-click fix.
static func _needs_parameters(occurrences: Array, length: int) -> bool:
	for occurrence: Dictionary in occurrences:
		var event: EventRow = occurrence["event"] as EventRow
		var actions: Array = event.actions.slice(int(occurrence["start_index"]), int(occurrence["start_index"]) + length)
		var plan: Dictionary = EventSheetExtractOps._capture_plan(event, actions)
		if not str(plan.get("refused", "")).is_empty() or not (plan.get("params", []) as Array).is_empty():
			return true
	return false


static func _run_labels(occurrence: Dictionary, length: int) -> PackedStringArray:
	var labels: PackedStringArray = PackedStringArray()
	var event: EventRow = occurrence["event"] as EventRow
	for offset: int in range(length):
		var index: int = int(occurrence["start_index"]) + offset
		if index < event.actions.size():
			labels.append(action_label(event.actions[index] as Resource))
	return labels


## A short, readable name for one action row - the verb's id for a structured action, the first
## line for a code block. Display only; the scan compares signatures, never labels.
static func action_label(action: Resource) -> String:
	if action is ACEAction:
		var ace: ACEAction = action as ACEAction
		return "%s %s" % [ace.provider_id, ace.ace_id] if ace.provider_id != "Core" else ace.ace_id
	if action is RawCodeRow:
		var lines: PackedStringArray = (action as RawCodeRow).code.split("\n")
		return lines[0].strip_edges() if lines.size() > 0 else "(code)"
	return action.get_class()


static func _collect_events(rows: Array, events: Array) -> void:
	for row: Variant in rows:
		if row is EventGroup:
			var group: EventGroup = row as EventGroup
			_collect_events(group.events if not group.events.is_empty() else group.rows, events)
		elif row is EventRow:
			events.append(row as EventRow)
			_collect_events((row as EventRow).sub_events, events)


# ── The window ────────────────────────────────────────────────────────────────────────────────
## Builds the window without popping it (testable headless); open() pops it up.
func build() -> void:
	if window != null:
		return
	window = Window.new()
	window.title = "Find Repeated Rows"
	window.size = Vector2i(600, 480)
	window.min_size = Vector2i(420, 320)
	window.close_requested.connect(func() -> void: window.hide())
	var body: VBoxContainer = EventSheetPopupUI.form_box()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_label = EventSheetPopupUI.hint_label(
		"Runs of actions that appear more than once. Pick one and make it a function: it is extracted at the first place and called at the rest, in one undo step.", 460.0)
	body.add_child(summary_label)
	tree = Tree.new()
	tree.hide_root = true
	tree.columns = 2
	tree.set_column_title(0, "Repeated run")
	tree.set_column_title(1, "Saves")
	tree.column_titles_visible = true
	tree.set_column_expand(1, false)
	tree.set_column_custom_minimum_width(1, 110)
	tree.select_mode = Tree.SELECT_ROW
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.item_selected.connect(_on_run_selected)
	tree.item_activated.connect(_on_run_activated)
	var card: PanelContainer = EventSheetPopupUI.labelled_card("Repeats", tree)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(card)
	make_verb_button = Button.new()
	make_verb_button.text = "Make a Function…"
	make_verb_button.tooltip_text = "Name this run: it becomes one reusable function, extracted where it first appears and called everywhere else."
	make_verb_button.disabled = true
	make_verb_button.pressed.connect(_on_make_verb_pressed)
	body.add_child(make_verb_button)
	var margined: MarginContainer = EventSheetPopupUI.margined(body)
	margined.set_anchors_preset(Control.PRESET_FULL_RECT)
	window.add_child(margined)
	_dock.add_child(window)


func open() -> void:
	build()
	refresh()
	if window.is_inside_tree():
		window.popup_centered()


## Rescans the current sheet and rebuilds the list (popup-free, so tests drive it headlessly).
## Returns the number of repeated runs found.
func refresh() -> int:
	build()
	_runs = repeated_runs(_dock._current_sheet)
	tree.clear()
	var root: TreeItem = tree.create_item()
	for run_index: int in range(_runs.size()):
		var run: Dictionary = _runs[run_index]
		var item: TreeItem = tree.create_item(root)
		var places: int = (run["occurrences"] as Array).size()
		item.set_text(0, "%d places × %d rows%s" % [places, int(run["length"]),
			"  (needs parameters)" if bool(run.get("needs_parameters", false)) else ""])
		item.set_text(1, "%d rows" % int(run["rows_saved"]))
		item.set_metadata(0, run_index)
		for label: String in (run["labels"] as PackedStringArray):
			var child: TreeItem = tree.create_item(item)
			child.set_text(0, label)
			child.set_metadata(0, run_index)
	make_verb_button.disabled = true
	summary_label.text = "No repeated runs - every action sequence on this sheet is written once." if _runs.is_empty() \
		else "%d repeated run(s). Pick one and make it a function: extracted where it first appears, called everywhere else, one undo step." % _runs.size()
	return _runs.size()


func _selected_run_index() -> int:
	var selected: TreeItem = tree.get_selected() if tree != null else null
	if selected == null or selected.get_metadata(0) == null:
		return -1
	return int(selected.get_metadata(0))


func _on_run_selected() -> void:
	var index: int = _selected_run_index()
	make_verb_button.disabled = index < 0 or bool((_runs[index] as Dictionary).get("needs_parameters", false))


## Double-click jumps to the run's first site, so a repeat can be read in place before it is named.
func _on_run_activated() -> void:
	var index: int = _selected_run_index()
	if index < 0:
		return
	var first: Dictionary = ((_runs[index] as Dictionary)["occurrences"] as Array)[0]
	var view: EventSheetViewport = _dock._active_view()
	if view != null:
		view.reveal_resource(first["event"] as Resource)
		view.select_resource(first["event"] as Resource)


func _on_make_verb_pressed() -> void:
	var index: int = _selected_run_index()
	if index < 0:
		return
	_dock._quick_prompts.prompt_extract_function_name(func(entered_name: String) -> void:
		make_verb(index, entered_name))


## Names the run at `run_index`: the shipped extractor turns the FIRST site into a function and a
## Call, then every other site's run is replaced by a Call to the same function. One undo step for
## the lot - a half-applied refactor would be worse than none. Returns true when the sheet changed.
func make_verb(run_index: int, raw_name: String) -> bool:
	if run_index < 0 or run_index >= _runs.size():
		return false
	var run: Dictionary = _runs[run_index]
	if bool(run.get("needs_parameters", false)):
		_dock._set_status("That run uses an event-local or a For-Each item, so the sites can't share one function without parameters. Extract it at one site instead.", true)
		return false
	var occurrences: Array = run["occurrences"]
	var length: int = int(run["length"])
	var sites: int = occurrences.size()
	var signature: String = str(run["signature"])
	# A scan is a SNAPSHOT. The undo funnel replaces every resource on commit, so an edit made
	# between opening this window and pressing the button leaves these EventRows orphaned - they
	# would still be rewritten, but on rows no longer in the sheet, publishing a verb with no call
	# sites and leaving every repeat in place. Re-scanning here is cheap and always correct.
	if not _occurrences_are_live(occurrences):
		refresh()
		_dock._set_status("The sheet changed since this list was built - it has been rescanned. Pick the run again.", true)
		return false
	var changed: bool = _dock._perform_undoable_sheet_edit("Make a Function from Repeated Rows", func() -> bool:
		var first: Dictionary = occurrences[0]
		var first_event: EventRow = first["event"] as EventRow
		var first_start: int = int(first["start_index"])
		# Every remaining site's index is resolved BEFORE anything moves, then the rewrites run from
		# the highest index down. Two occurrences of one run can share an event (the scan only
		# rejects OVERLAPPING spans), and replaying pre-scan indices after an earlier rewrite has
		# already shortened that action list deletes rows the run never touched.
		if not _span_matches(first_event, first_start, length, signature):
			return false
		var pending: Array = []
		for cursor: int in range(1, occurrences.size()):
			var occurrence: Dictionary = occurrences[cursor]
			var event: EventRow = occurrence["event"] as EventRow
			var start: int = int(occurrence["start_index"])
			if not _span_matches(event, start, length, signature):
				return false
			if event == first_event and start > first_start:
				# The first site loses `length` actions and gains one Call.
				start -= length - 1
			pending.append({"event": event, "start": start})
		pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["start"]) > int(b["start"]))
		var first_actions: Array = first_event.actions.slice(first_start, first_start + length)
		var function: EventFunction = EventSheetExtractOps.extract_actions_to_function(
			_dock._current_sheet, first_event, first_actions, raw_name)
		if function == null:
			return false
		for entry: Dictionary in pending:
			var event: EventRow = entry["event"] as EventRow
			var start: int = int(entry["start"])
			for _removed: int in range(length):
				event.actions.remove_at(start)
			event.actions.insert(start, _call_action(function.function_name))
		return true
	)
	if changed:
		_dock._refresh_functions_list()
		_dock._mark_dirty("\"%s\" is a function now - defined once, called at %d places." % [raw_name.strip_edges(), sites])
		refresh()
	else:
		_dock._set_status("That run couldn't be extracted - open the first site and try Extract All Actions to Function there.", true)
	return changed


## True when every scanned occurrence still belongs to an event the LIVE sheet holds. The window is
## not modal, so a scan can outlive the sheet it was taken from; a rewrite of orphaned rows would
## report success and change nothing the author can see.
func _occurrences_are_live(occurrences: Array) -> bool:
	var live_events: Array = []
	_collect_events(_dock._current_sheet.events if _dock._current_sheet != null else [], live_events)
	for occurrence: Dictionary in occurrences:
		if not live_events.has(occurrence["event"]):
			return false
	return true


## True when `event.actions[start ..< start + length]` still spells exactly `signature`. The last
## guard before anything is deleted: a span that no longer matches is not this run, and rewriting it
## would destroy rows the author never asked about.
static func _span_matches(event: EventRow, start: int, length: int, signature: String) -> bool:
	if event == null or start < 0 or start + length > event.actions.size():
		return false
	var signatures: PackedStringArray = PackedStringArray()
	for offset: int in range(length):
		var action: Variant = event.actions[start + offset]
		signatures.append(action_signature(action as Resource) if action is Resource else "other|null")
	return "|||".join(signatures) == signature


## The Call row the other sites get: exactly the one the shipped extractor writes at the first
## site, so every call site is the same ordinary action row.
static func _call_action(function_name: String) -> ACEAction:
	var call_action: ACEAction = ACEAction.new()
	call_action.provider_id = "Core"
	call_action.ace_id = "CallFunction"
	call_action.codegen_template = "{function_name}({args})"
	call_action.params = {"function_name": function_name, "args": ""}
	return call_action
