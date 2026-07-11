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
## replaces them with a single Call - turning a pile of statement-level rows into one named CONCEPT (the
## "create abstraction" gesture). Unlike the old GDScript-only extractor, this works on ANY action -
## structured ACE actions AND GDScript blocks - and PRESERVES them as rows in the function body (wrapped
## in a trigger-less, condition-less event, which the shared event-body compile path emits as plain
## statements, structure intact). Static + pure (operates on the passed sheet) so it is headlessly
## testable; the dock wraps it in an undoable edit + a name prompt. Returns the new function, or null when
## there is nothing to extract.
##
## Scope note: the function compiles to a METHOD on the same class, so it can freely read sheet variables
## and host members WITHOUT parameters. It does NOT capture event-LOCAL variables or For-Each iterators
## (those are trigger/loop-scoped) - extracting actions that depend on them needs params, a later
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
	# Event-SCOPED names the actions reference become real typed PARAMETERS where sound
	# (iterators; locals declared in kept actions) - the function receives the live
	# values instead of refusing. A local declared nowhere visible still refuses: the
	# output could not parse, and always-valid .gd is the load-bearing invariant.
	var plan: Dictionary = _capture_plan(event, ordered)
	if not str(plan.get("refused", "")).is_empty():
		return null
	var captures: Array = plan.get("params", [])
	var insert_at: int = event.actions.find(ordered[0])
	var function_name: String = EventSheetDock._unique_extracted_function_name(sheet, EventSheetDock._sanitize_function_name(raw_name))
	var display_name: String = raw_name.strip_edges()
	var function: EventFunction = EventFunction.new()
	function.function_name = function_name
	function.expose_as_ace = true
	function.ace_display_name = display_name if not display_name.is_empty() else function_name.capitalize()
	function.ace_category = "Functions"
	function.description = "Extracted from an event - reusable from the picker."
	var argument_names: PackedStringArray = PackedStringArray()
	for capture: Dictionary in captures:
		var parameter: ACEParam = ACEParam.new()
		parameter.id = str(capture.get("name"))
		parameter.type_name = str(capture.get("type")) if _PARAM_SAFE_TYPES.has(str(capture.get("type"))) else "Variant"
		function.params.append(parameter)
		argument_names.append(str(capture.get("name")))
	# Function body: one trigger-less, condition-less event holding the extracted actions in order. A
	# condition-less event emits its actions directly (no `if` wrapper), so structured AND raw actions
	# both survive - and the function renders showing those same rows.
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
	# Captured scope values ride along as call arguments, matching the params above.
	call_action.params = {"function_name": function_name, "args": ", ".join(argument_names)}
	event.actions.insert(clampi(insert_at, 0, event.actions.size()), call_action)
	return function


## The first event-SCOPED identifier (an event-local variable or a For-Each iterator name) referenced by
## the given actions, or "" if none. An extracted function is a SEPARATE method, so it can't see these -
## extracting an action that uses one would emit a script that won't parse. The dock refuses with this
## name (a clear message) instead of silently producing a broken .gd. Whole-word match so "speed" doesn't
## trip on "speedometer". Scans GDScript blocks, ACE param/template text, and a Match action's subject.
## Event-scope names (locals + For-Each iterators) the given actions actually reference,
## in declaration order, as [{name, type, kind: "local"|"iterator"}].
static func _scope_captures(event: EventRow, actions: Array) -> Array:
	var scoped: Array = []
	for local_entry: Variant in event.local_variables:
		if local_entry is LocalVariable and not (local_entry as LocalVariable).name.strip_edges().is_empty():
			scoped.append({"name": (local_entry as LocalVariable).name.strip_edges(), "type": (local_entry as LocalVariable).type_name.strip_edges(), "kind": "local"})
	for filter_entry: Variant in event.pick_filters:
		if filter_entry is PickFilter and not (filter_entry as PickFilter).iterator_name.strip_edges().is_empty():
			scoped.append({"name": (filter_entry as PickFilter).iterator_name.strip_edges(), "type": "Variant", "kind": "iterator"})
	if scoped.is_empty():
		return []
	var text: String = _actions_text(actions)
	var captures: Array = []
	for entry: Dictionary in scoped:
		var word: RegEx = RegEx.new()
		if word.compile("\\b" + str(entry.get("name")) + "\\b") == OK and word.search(text) != null:
			captures.append(entry)
	return captures


## The searchable text of a run of actions: raw code, baked templates, and param values.
static func _actions_text(actions: Array) -> String:
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
	return text


## What happens to each referenced event-scope name when these actions leave the event:
## For-Each iterators always become PARAMETERS (the loop construct stays behind); a
## local whose `var` declaration is INSIDE the extracted code travels with it (nothing
## to do); a local declared in a KEPT action becomes a parameter (the call passes the
## live value); a referenced local declared nowhere visible REFUSES - the output could
## not parse. Returns {params: [{name, type, kind}], refused: String}.
static func _capture_plan(event: EventRow, ordered: Array) -> Dictionary:
	var params: Array = []
	var refused: String = ""
	var extracted_text: String = _actions_text(ordered)
	var kept: Array = []
	for action: Variant in event.actions:
		if not ordered.has(action):
			kept.append(action)
	var kept_text: String = _actions_text(kept)
	for capture: Dictionary in _scope_captures(event, ordered):
		var name: String = str(capture.get("name"))
		if str(capture.get("kind")) == "iterator":
			params.append(capture)
			continue
		var declares: RegEx = RegEx.new()
		if declares.compile("\\bvar\\s+" + name + "\\b") != OK:
			continue
		if declares.search(extracted_text) != null:
			continue
		if declares.search(kept_text) != null:
			params.append(capture)
		else:
			refused = name
			break
	return {"params": params, "refused": refused}


## Kept for callers that only need a yes/no: the first scope name that would make the
## extraction refuse (declared nowhere the function could reach), or "".
static func _scope_capture_offender(event: EventRow, actions: Array) -> String:
	return str(_capture_plan(event, actions).get("refused", ""))


## The GDScript types a captured local may carry into a parameter annotation; anything
## else (friendly labels, custom classes) emits bare, which the emitter renders as an
## untyped param - always-valid output beats a wrong annotation.
const _PARAM_SAFE_TYPES := ["int", "float", "String", "bool", "Vector2", "Vector3", "Color", "Array", "Dictionary", "NodePath", "StringName"]


## Right-click action: extract the event's actions into a NAMED reusable Function (the "create
## abstraction" gesture). Reachable from an action's menu or the event row menu. Extracts ALL of the
## event's actions - turning this event's "do" into one named verb - then prompts for a name and runs the
## edit undoably. A multi-selection of the event's action cells extracts JUST those.
func extract_to_function_requested() -> void:
	if _dock._context_row == null or not (_dock._context_row.source_resource is EventRow):
		_dock._set_status("Right-click an event or one of its actions to extract.", true)
		return
	var event: EventRow = _dock._context_row.source_resource as EventRow
	if event.actions.is_empty():
		_dock._set_status("That event has no actions to extract into a function.", true)
		return
	# A multi-selection of this event's actions extracts JUST those. The subset must be
	# CONTIGUOUS: the call lands where the first extracted action was, so extracting
	# around a kept action would silently reorder execution. No action selection (or all
	# of them) = the whole pile, the original gesture.
	var to_extract: Array = event.actions.duplicate()
	var selected_indices: Array = _selected_action_indices(event)
	if not selected_indices.is_empty() and selected_indices.size() < event.actions.size():
		for cursor in range(1, selected_indices.size()):
			if int(selected_indices[cursor]) != int(selected_indices[cursor - 1]) + 1:
				_dock._set_status("Can't extract a gapped selection - the kept action in the middle would change run order. Select a contiguous run of actions.", true)
				return
		var subset: Array = []
		for action_index: Variant in selected_indices:
			subset.append(event.actions[int(action_index)])
		to_extract = subset
	# Event-scoped names the actions use become PARAMETERS where sound (the call passes
	# the live values) - tell the user which, so the new signature is no surprise. A
	# local declared nowhere the function could reach still refuses, with the fix named.
	var request_plan: Dictionary = _capture_plan(event, to_extract)
	var refused_name: String = str(request_plan.get("refused", ""))
	if not refused_name.is_empty():
		_dock._set_status("Can't extract: these actions use \"%s\" but nothing visible declares it - the function couldn't compile. Declare it in a kept action or make it a sheet variable, then extract." % refused_name, true)
		return
	var capture_names: PackedStringArray = PackedStringArray()
	for capture: Dictionary in (request_plan.get("params", []) as Array):
		capture_names.append(str(capture.get("name")))
	prompt_extract_function_name(func(entered_name: String) -> void:
		var changed: bool = _dock._perform_undoable_sheet_edit("Extract to Function", func() -> bool:
			return extract_actions_to_function(_dock._current_sheet, event, to_extract, entered_name) != null
		)
		if changed:
			_dock._refresh_functions_list()
			var note: String = "" if capture_names.is_empty() else " Event-scoped %s became parameter(s) - the call passes the live value(s)." % ", ".join(capture_names)
			_dock._mark_dirty("Extracted %d action(s) into a reusable Function - now callable from the picker (Functions).%s" % [to_extract.size(), note])
	)


## The selected action indices belonging to `event` (sorted, deduped), read from the
## active view's multi-selection - [] when the selection isn't action cells of this event.
func _selected_action_indices(event: EventRow) -> Array:
	var view: EventSheetViewport = _dock._active_view()
	if view == null:
		return []
	var indices: Array = []
	for entry: Variant in view.get_selected_ace_entries():
		if not (entry is Dictionary):
			continue
		if (entry as Dictionary).get("source_resource") != event:
			continue
		if str((entry as Dictionary).get("kind", "")) != "action":
			continue
		var action_index: int = int((entry as Dictionary).get("ace_index", -1))
		if action_index >= 0 and action_index < event.actions.size() and not indices.has(action_index):
			indices.append(action_index)
	indices.sort()
	return indices


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
