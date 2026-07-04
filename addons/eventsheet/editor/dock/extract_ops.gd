@tool
class_name EventSheetExtractOps
extends RefCounted
# The EXTRACT operations, moved out of event_sheet_dock.gd: turning a selection of
# actions into a named, reusable function (the abstraction lever: select -> name ->
# one verb), and extracting rows into an include sheet. The two statics are the
# PURE transform (tests drive them directly through the dock's static forwarders);
# the instance methods are the dock-side flow (prompt, undo funnel, refresh).
# Bodies moved VERBATIM; instance member access goes through the `_dock.`
# back-reference and the dock keeps one-line delegates/forwarders.

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock


## Extracts the given actions of an event into a new NAMED, reusable Function (exposed as an ACE) and
## replaces them with a single Call — turning a pile of statement-level rows into one named CONCEPT (the
## "create abstraction" gesture). Unlike the old GDScript-only extractor, this works on ANY action —
## structured ACE actions AND GDScript blocks — and PRESERVES them as rows in the function body (wrapped
## in a trigger-less, condition-less event, which the shared event-body compile path emits as plain
## statements, structure intact). Static + pure (operates on the passed sheet) so it is headlessly
## testable; the dock wraps it in an undoable edit + a name prompt. Returns the new function, or null when
## there is nothing to extract.
##
## Scope note: the function compiles to a METHOD on the same class, so it can freely read sheet variables
## and host members WITHOUT parameters. It does NOT capture event-LOCAL variables or For-Each iterators
## (those are trigger/loop-scoped) — extracting actions that depend on them needs params, a later
## refinement. The actions are taken in their original event order, so a non-contiguous selection still
## extracts deterministically (consolidated where the first one was).
static func extract_actions_to_function(sheet: EventSheetResource, event: EventRow, actions_to_extract: Array, raw_name: String) -> EventFunction:
	if sheet == null or event == null or actions_to_extract.is_empty():
		return null
	# Keep only the requested actions that actually belong to this event, in their original order.
	var ordered: Array = []
	for action: Variant in event.actions:
		if actions_to_extract.has(action) and action is Resource:
			ordered.append(action)
	if ordered.is_empty():
		return null
	# Refuse if any action references an event-SCOPED name (a local variable or For-Each iterator): the
	# extracted function is a separate method that can't see those, so extracting would emit a .gd that
	# won't parse. The dock checks this first to show WHICH name; this guard makes the core safe too.
	if not _scope_capture_offender(event, ordered).is_empty():
		return null
	var insert_at: int = event.actions.find(ordered[0])
	var function_name: String = EventSheetDock._unique_extracted_function_name(sheet, EventSheetDock._sanitize_function_name(raw_name))
	var display_name: String = raw_name.strip_edges()
	var function: EventFunction = EventFunction.new()
	function.function_name = function_name
	function.expose_as_ace = true
	function.ace_display_name = display_name if not display_name.is_empty() else function_name.capitalize()
	function.ace_category = "Functions"
	function.description = "Extracted from an event — reusable as an ACE."
	# Function body: one trigger-less, condition-less event holding the extracted actions in order. A
	# condition-less event emits its actions directly (no `if` wrapper), so structured AND raw actions
	# both survive — and the function renders showing those same rows.
	var body_event: EventRow = EventRow.new()
	var body_actions: Array[Resource] = []
	for action: Variant in ordered:
		body_actions.append(action as Resource)
	body_event.actions = body_actions
	function.events.append(body_event)
	sheet.functions.append(function)
	# Remove the extracted actions, then drop a Call to the new function where the first one was.
	for action: Variant in ordered:
		event.actions.erase(action)
	var call_action: ACEAction = ACEAction.new()
	call_action.provider_id = "Core"
	call_action.ace_id = "CallFunction"
	call_action.codegen_template = "{function_name}({args})"
	call_action.params = {"function_name": function_name, "args": ""}
	event.actions.insert(clampi(insert_at, 0, event.actions.size()), call_action)
	return function


## The first event-SCOPED identifier (an event-local variable or a For-Each iterator name) referenced by
## the given actions, or "" if none. An extracted function is a SEPARATE method, so it can't see these —
## extracting an action that uses one would emit a script that won't parse. The dock refuses with this
## name (a clear message) instead of silently producing a broken .gd. Whole-word match so "speed" doesn't
## trip on "speedometer". Scans GDScript blocks, ACE param/template text, and a Match action's subject.
static func _scope_capture_offender(event: EventRow, actions: Array) -> String:
	var scoped: PackedStringArray = PackedStringArray()
	for local_entry: Variant in event.local_variables:
		if local_entry is LocalVariable and not (local_entry as LocalVariable).name.strip_edges().is_empty():
			scoped.append((local_entry as LocalVariable).name.strip_edges())
	for filter_entry: Variant in event.pick_filters:
		if filter_entry is PickFilter and not (filter_entry as PickFilter).iterator_name.strip_edges().is_empty():
			scoped.append((filter_entry as PickFilter).iterator_name.strip_edges())
	if scoped.is_empty():
		return ""
	var text: String = ""
	for action: Variant in actions:
		if action is RawCodeRow:
			text += "\n" + (action as RawCodeRow).code
		elif action is ACEAction:
			text += "\n" + (action as ACEAction).codegen_template
			for value: Variant in (action as ACEAction).params.values():
				text += "\n" + str(value)
		elif action is MatchRow:
			text += "\n" + (action as MatchRow).match_expression
	for name: String in scoped:
		var word: RegEx = RegEx.new()
		if word.compile("\\b" + name + "\\b") == OK and word.search(text) != null:
			return name
	return ""


## Right-click action: extract the event's actions into a NAMED reusable Function (the "create
## abstraction" gesture). Reachable from an action's menu or the event row menu. Extracts ALL of the
## event's actions — turning this event's "do" into one named verb — then prompts for a name and runs the
## edit undoably. (A future refinement can honour a partial action selection.)
func extract_to_function_requested() -> void:
	if _dock._context_row == null or not (_dock._context_row.source_resource is EventRow):
		_dock._set_status("Right-click an event or one of its actions to extract.", true)
		return
	var event: EventRow = _dock._context_row.source_resource as EventRow
	if event.actions.is_empty():
		_dock._set_status("That event has no actions to extract into a function.", true)
		return
	var to_extract: Array = event.actions.duplicate()
	# Refuse (with the offending name) rather than silently emit a script that won't parse.
	var captured: String = _scope_capture_offender(event, to_extract)
	if not captured.is_empty():
		_dock._set_status("Can't extract: these actions use \"%s\", which lives in this event's scope (a local variable or loop iterator) — a function can't see it. Move it to a sheet variable first, then extract." % captured, true)
		return
	prompt_extract_function_name(func(entered_name: String) -> void:
		var changed: bool = _dock._perform_undoable_sheet_edit("Extract to Function", func() -> bool:
			return extract_actions_to_function(_dock._current_sheet, event, to_extract, entered_name) != null
		)
		if changed:
			_dock._refresh_functions_list()
			_dock._mark_dirty("Extracted %d action(s) into a reusable Function — now callable as an ACE (Functions)." % to_extract.size())
	)


func do_extract_to_include(path: String, rows: Array[Resource]) -> void:
	var target: String = path if path.get_extension() == "tres" else path + ".tres"
	# Build + save the library FIRST (duplicating the rows so uids carry over), so a write
	# failure leaves the current sheet untouched.
	var library: EventSheetResource = EventSheetResource.new()
	library.host_class = _dock._current_sheet.host_class
	library.behavior_mode = _dock._current_sheet.behavior_mode
	for row: Resource in rows:
		library.events.append(row.duplicate(true))
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	if ResourceSaver.save(library, target) != OK:
		_dock._set_status("Could not write %s." % target.get_file(), true)
		return
	# Then remove the originals + add the include, undoably (one snapshot captures both).
	var changed: bool = _dock._perform_undoable_sheet_edit("Extract to Include", func() -> bool:
		for row: Resource in rows:
			var index: int = _dock._current_sheet.events.find(row)
			if index != -1:
				_dock._current_sheet.events.remove_at(index)
		if not _dock._current_sheet.includes.has(target):
			_dock._current_sheet.includes.append(target)
		return true
	)
	if changed:
		_dock._mark_dirty("Extracted %d row(s) into %s (now included)." % [rows.size(), target.get_file()])


# ── Quick prompt popups (Extract-to-Function name / Conditional Breakpoint / Group editor) → dock/quick_prompt_dialogs.gd ──
# Thin delegates so context menus, viewport signals, and tests keep calling the dock unchanged.
func prompt_extract_function_name(callback: Callable) -> void:
	_dock._quick_prompts.prompt_extract_function_name(callback)
