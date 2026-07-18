@tool
class_name EventSheetACEApply
extends RefCounted
# The ACE-APPLICATION + row/ACE DRAG-DROP subsystem. This helper owns turning a picked
# ACEDefinition + its params + a picker/edit context into concrete sheet mutations -
# condition/action/trigger baking and insertion - plus the row and ACE drag-and-drop
# reorder logic. Extracted from event_sheet_dock.gd to keep that file maintainable.
#
# WHAT STAYS ON THE DOCK (reached here through `_dock`): the mutation funnel
# (`_perform_undoable_sheet_edit`, `_mark_dirty`, `_set_status`, `_refresh_after_edit`),
# the active-view/state accessors (`_current_sheet`, `_active_view`, `_active_viewport_ref`),
# the shared registry/definition lookups (`_find_definition`, `_build_ace_edit_context`,
# `_resource_contains_descendant`, `_ensure_sheet_for_editing`), the STATIC uid minter
# (`_fresh_uid_token`, called as `_dock._fresh_uid_token()`), the picker/params/preview widgets
# (`_ace_picker`/`_ace_params`/`_preview_window`/`_preview_list`/`_preview_title`/`_status_label`),
# and the reflection helpers (`_autoload_provider_names`, `_param_resolver`).
#
# The dock keeps thin one-line delegates (original names + signatures) for every method that is
# reached from outside this helper - the connect() sites in _build_ui, the tests, the sibling
# dock/ helpers (variables_manager / comment_and_scope_dialogs reach `_dock._find_resource_location`
# and `_dock._group_children_array`), and multi_view_manager (which connects
# `_dock._on_viewport_ace_picker_requested` / `_dock._on_viewport_ace_edit_requested` by name).
# So those callers do not change.
#
# CLOSURE NOTE: `_apply_ace_definition`, `_move_rows`, and `_on_viewport_ace_drop_requested`
# hand lambdas to `_dock._perform_undoable_sheet_edit(...)`. Those lambdas capture `self`, which
# is now THIS helper - so every dock STATE/STAY reference inside them is written `_dock.` while
# calls to methods that live here (e.g. `_group_children_array`, `_find_resource_location`,
# `_create_condition_from_definition`) stay bare helper calls.

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock

# ── ACE picker signal handler ────────────────────────────────────────────────


func _on_ace_picker_selected(definition: ACEDefinition, context: Dictionary) -> void:
	if definition.parameters.is_empty():
		_apply_ace_definition(definition, {}, context)
		return
	var initial_values: Dictionary = context.get("existing_params", {})
	context["from_picker"] = true
	_dock._ace_params.open_with_values(definition, context, initial_values)


## Re-opens the ACE picker when the params dialog requests Back.
func _on_ace_params_back_requested(definition: ACEDefinition, context: Dictionary) -> void:
	var mode: String = str(context.get("mode", "new_event"))
	var signals_only: bool = bool(context.get("signals_only", false))
	var selected_resource: Resource = context.get("selected_resource", null)
	# Preselect the ACE you were editing so Back lands on it in the picker (swap it, or re-pick the
	# same one to tweak params) - matching the edit-and-swap.
	if definition != null:
		context["preselect_ace_id"] = definition.id
	_dock._ace_picker.open(mode, signals_only, selected_resource, context)


## A .gd opens as a read-only preview, but the FIRST intentional edit unlocks it automatically - no
## "click Edit Events" wall (that extra click is the friction now that .gd is the default format).
## Pure viewing stays protected: Save keeps its own read-only guard, so a casual look + Ctrl+S can
## still never overwrite a file you only opened to look at.
func _unlock_preview_for_edit() -> void:
	if _dock._current_sheet != null and _dock._current_sheet.read_only:
		_dock._on_preview_edit_requested()


func _on_viewport_ace_picker_requested(row_data: EventRowData, lane: String) -> void:
	_unlock_preview_for_edit()
	if row_data == null or not (row_data.source_resource is EventRow):
		return
	match lane:
		"action":
			_dock._ace_picker.open("append_action", false, row_data.source_resource)
		_:
			_dock._ace_picker.open("append_condition", false, row_data.source_resource)


func _on_viewport_ace_edit_requested(row_data: EventRowData, span_index: int, metadata: Dictionary) -> void:
	if row_data == null or not (row_data.source_resource is EventRow):
		return
	var event_row: EventRow = row_data.source_resource as EventRow
	# Action-cell comments edit in the comment dialog, not the ACE editor.
	if bool(metadata.get("action_comment", false)):
		var comment_index: int = int(metadata.get("ace_index", -1))
		if comment_index >= 0 and comment_index < event_row.actions.size() and event_row.actions[comment_index] is CommentRow:
			_dock._open_comment_dialog(event_row.actions[comment_index])
			return
	var edit_context: Dictionary = _dock._build_ace_edit_context(event_row, span_index, metadata)
	if edit_context.is_empty():
		return
	var definition: ACEDefinition = edit_context.get("definition", null)
	if definition == null:
		_dock._set_status("Couldn't load this row for editing (its action or condition definition is missing).", true)
		return
	# Triggers always go to the picker (clicking a trigger means "change what fires this event"), as does
	# any ACE with no params to edit - both land in the picker preselected on the current ACE, so the
	# obvious move is to swap it (or re-pick the same one). An ACE WITH params (action/condition) opens
	# the params editor instead, which carries its own "Back" button to this same preselected picker.
	if definition.parameters.is_empty() or str(edit_context.get("mode", "")) == "replace_trigger":
		edit_context["preselect_ace_id"] = definition.id
		_dock._ace_picker.open(str(edit_context.get("mode", "")), false, event_row, edit_context)
		return
	_dock._ace_params.open_with_values(definition, edit_context, edit_context.get("existing_params", {}))

# ── ACE params dialog signal handler ────────────────────────────────────────


func _on_ace_params_confirmed(definition: ACEDefinition, values: Dictionary, context: Dictionary) -> void:
	_apply_ace_definition(definition, values, context)
	# "Apply & Add Another": reopen the picker in the same append mode so the next
	# condition/action can be added without re-summoning the picker by hand.
	if bool(context.get("chain_add", false)):
		var mode: String = str(context.get("mode", ""))
		var selected_resource: Resource = context.get("selected_resource", null)
		if mode in ["append_condition", "append_action"] and selected_resource is EventRow:
			_dock._ace_picker.open(mode, false, selected_resource, {})


## Batch param edit: every condition/action that appears MORE THAN ONCE across the given
## rows (same provider + ace id + lane) is a batch group - edit its params once, apply to
## every instance. Walks sub-events and group children so "across the selection" means the
## whole selected subtree. Triggers are excluded (they edit through the picker) and so are
## action-cell comments. Static and pure so tests pin the enumeration headless.
static func batch_edit_groups(targets: Array) -> Array:
	var groups: Dictionary = {}
	_collect_batch_targets(targets, groups)
	var result: Array = []
	for key: Variant in groups.keys():
		var group: Dictionary = groups[key]
		if (group.get("targets", []) as Array).size() >= 2:
			result.append(group)
	return result


static func _collect_batch_targets(rows: Array, groups: Dictionary) -> void:
	for entry: Variant in rows:
		if entry is EventGroup:
			_collect_batch_targets((entry as EventGroup).events if not (entry as EventGroup).events.is_empty() else (entry as EventGroup).rows, groups)
			continue
		if not (entry is EventRow):
			continue
		var event_row: EventRow = entry as EventRow
		for condition_index: int in range(event_row.conditions.size()):
			if event_row.conditions[condition_index] is ACECondition:
				_record_batch_target(groups, "condition", event_row.conditions[condition_index], event_row, condition_index)
		for action_index: int in range(event_row.actions.size()):
			if event_row.actions[action_index] is ACEAction:
				_record_batch_target(groups, "action", event_row.actions[action_index], event_row, action_index)
		_collect_batch_targets(event_row.sub_events, groups)


static func _record_batch_target(groups: Dictionary, kind: String, ace: Resource, event_row: EventRow, index: int) -> void:
	var provider_id: String = str(ace.get("provider_id"))
	var ace_id: String = str(ace.get("ace_id"))
	if provider_id.is_empty() or ace_id.is_empty():
		return
	var key: String = "%s|%s|%s" % [kind, provider_id, ace_id]
	if not groups.has(key):
		groups[key] = {"kind": kind, "provider_id": provider_id, "ace_id": ace_id, "targets": []}
	(groups[key].get("targets") as Array).append({"event": event_row, "index": index})


## Select All Matching: every EventRow (walking groups and sub-events) that USES the given
## ACE - as its trigger (resource or baked ids), a condition, or an action. Static and pure
## so tests pin the walk; feeds the multi-select that Replace Object and batch edit act on.
static func matching_event_rows(rows: Array, provider_id: String, ace_id: String) -> Array:
	var matches: Array = []
	for entry: Variant in rows:
		if entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			matches.append_array(matching_event_rows(group.events if not group.events.is_empty() else group.rows, provider_id, ace_id))
			continue
		if not (entry is EventRow):
			continue
		var event_row: EventRow = entry as EventRow
		if _event_uses_ace(event_row, provider_id, ace_id):
			matches.append(event_row)
		matches.append_array(matching_event_rows(event_row.sub_events, provider_id, ace_id))
	return matches


static func _event_uses_ace(event_row: EventRow, provider_id: String, ace_id: String) -> bool:
	if event_row.trigger_provider_id == provider_id and event_row.trigger_id == ace_id:
		return true
	if event_row.trigger is ACECondition and (event_row.trigger as ACECondition).provider_id == provider_id and (event_row.trigger as ACECondition).ace_id == ace_id:
		return true
	for condition: Variant in event_row.conditions:
		if condition is ACECondition and (condition as ACECondition).provider_id == provider_id and (condition as ACECondition).ace_id == ace_id:
			return true
	for action: Variant in event_row.actions:
		if action is ACEAction and (action as ACEAction).provider_id == provider_id and (action as ACEAction).ace_id == ace_id:
			return true
	return false


func _apply_ace_definition(definition: ACEDefinition, params: Dictionary, context: Dictionary) -> void:
	if definition == null:
		return
	var mode: String = str(context.get("mode", "new_event"))
	var selected_resource: Resource = context.get("selected_resource", null)
	var message := {"text": ""}
	# This lambda runs inside the dock's undo funnel and captures `self` (this helper), so every
	# dock state reference below is written `_dock.` while calls into helper methods stay bare.
	var changed: bool = _dock._perform_undoable_sheet_edit("Apply Cell Edit", func() -> bool:
		match mode:
			"new_condition_event":
				var condition_event: EventRow = EventRow.new()
				if definition.ace_type == ACEDefinition.ACEType.TRIGGER:
					condition_event.trigger = _create_condition_from_definition(definition, params)
					_bake_trigger_signature(condition_event, definition)
				else:
					_append_condition_entry(condition_event, definition, params)
				var insert_into: Variant = context.get("insert_into", null)
				if insert_into is EventGroup:
					_group_children_array(insert_into as EventGroup).append(condition_event)
				elif insert_into is EventSheetResource:
					(insert_into as EventSheetResource).events.append(condition_event)
				else:
					_insert_row_below_selection(condition_event)
				message["text"] = "Added event."
				return true
			"new_sub_condition_event":
				if selected_resource is EventRow:
					var child_condition_event: EventRow = EventRow.new()
					if definition.ace_type == ACEDefinition.ACEType.TRIGGER:
						child_condition_event.trigger = _create_condition_from_definition(definition, params)
						_bake_trigger_signature(child_condition_event, definition)
					else:
						_append_condition_entry(child_condition_event, definition, params)
					(selected_resource as EventRow).sub_events.append(child_condition_event)
					message["text"] = "Added sub-condition."
					return true
			"append_condition":
				if selected_resource is EventRow:
					var target_event: EventRow = selected_resource as EventRow
					if _is_looping_condition(definition):
						target_event.pick_filters.append(_create_pick_filter_from_definition(definition, params))
						message["text"] = "Added loop."
						return true
					var condition_entry: ACECondition = _create_condition_from_definition(definition, params)
					# Only use the trigger slot when the event has no trigger yet; otherwise
					# append as a normal condition so an existing trigger (e.g. "Every tick")
					# is never overwritten by adding a condition.
					if definition.ace_type == ACEDefinition.ACEType.TRIGGER and target_event.trigger == null and target_event.trigger_id.is_empty():
						target_event.trigger = condition_entry
						_bake_trigger_signature(target_event, definition)
					else:
						target_event.conditions.append(condition_entry)
					message["text"] = "Added condition."
					return true
			"append_action":
				if selected_resource is EventRow:
					var action_entry: ACEAction = _create_action_from_definition(definition, params)
					(selected_resource as EventRow).actions.append(action_entry)
					message["text"] = "Added action."
					return true
			"replace_trigger":
				if selected_resource is EventRow:
					(selected_resource as EventRow).trigger = _create_condition_from_definition(definition, params)
					_bake_trigger_signature(selected_resource as EventRow, definition)
					message["text"] = "Updated trigger."
					return true
			"replace_condition":
				if selected_resource is EventRow:
					var condition_index: int = int(context.get("ace_index", -1))
					if condition_index >= 0 and condition_index < (selected_resource as EventRow).conditions.size():
						(selected_resource as EventRow).conditions[condition_index] = _create_condition_from_definition(definition, params)
						message["text"] = "Updated condition."
						return true
			"replace_action":
				if selected_resource is EventRow:
					var action_index: int = int(context.get("ace_index", -1))
					if action_index >= 0 and action_index < (selected_resource as EventRow).actions.size():
						(selected_resource as EventRow).actions[action_index] = _create_action_from_definition(definition, params)
						message["text"] = "Updated action."
						return true
			"batch_edit_params":
				# One dialog, every matching instance: each target slot is re-verified at apply
				# time (same lane, index still in range, same provider + ace id) so a slot that
				# changed since the menu opened is skipped, never corrupted. Fresh resources per
				# slot: stateful conditions each bake their own {uid}. All inside THIS one funnel
				# call, so the whole sweep is a single undo step.
				var kind: String = str(context.get("batch_kind", "action"))
				var applied: int = 0
				for target: Variant in context.get("batch_targets", []):
					if not (target is Dictionary):
						continue
					var target_event: EventRow = (target as Dictionary).get("event", null) as EventRow
					var slot_index: int = int((target as Dictionary).get("index", -1))
					if target_event == null or slot_index < 0:
						continue
					var lane_array: Array = target_event.conditions if kind == "condition" else target_event.actions
					if slot_index >= lane_array.size():
						continue
					var existing: Resource = lane_array[slot_index]
					if existing == null or str(existing.get("provider_id")) != definition.provider_id or str(existing.get("ace_id")) != definition.id:
						continue
					var fresh: Resource
					if kind == "condition":
						fresh = _create_condition_from_definition(definition, params)
					else:
						fresh = _create_action_from_definition(definition, params)
					# Per-param apply: keys left unchecked in the dialog keep each instance's
					# OWN value - only the checked ones take the dialog's value. An absent
					# list means apply everything (the original whole-dialog behavior).
					if context.has("batch_apply_params"):
						var apply_keys: Array = context.get("batch_apply_params", [])
						var existing_params: Dictionary = existing.get("params")
						var fresh_params: Dictionary = fresh.get("params")
						for param_key: Variant in fresh_params.keys():
							if not apply_keys.has(str(param_key)) and existing_params.has(param_key):
								fresh_params[param_key] = existing_params[param_key]
					lane_array[slot_index] = fresh
					applied += 1
				if applied > 0:
					message["text"] = "Updated %d matching %s." % [applied, ("conditions" if applied != 1 else "condition") if kind == "condition" else ("actions" if applied != 1 else "action")]
					return true
			_:
				var event_row: EventRow = EventRow.new()
				if definition.ace_type == ACEDefinition.ACEType.TRIGGER:
					event_row.trigger = _create_condition_from_definition(definition, params)
					_bake_trigger_signature(event_row, definition)
				elif definition.ace_type == ACEDefinition.ACEType.CONDITION:
					_append_condition_entry(event_row, definition, params)
				elif definition.ace_type == ACEDefinition.ACEType.ACTION:
					event_row.actions.append(_create_action_from_definition(definition, params))
				_insert_row_below_selection(event_row)
				message["text"] = "Added event."
				return true
		return false
	)
	if changed:
		_dock._mark_dirty(str(message.get("text", "Applied.")))


## Bakes a trigger definition's identity + argument signature onto the event row, so the
## compiler can group it, generate a connectable handler (`func _on_<signal>(args)`), and
## emit the `_ready` connection - all without registry access at compile time. Fixes the
## gap where picker-created trigger events never set trigger_id and silently skipped
## compilation. Mirrors codegen_template baking on conditions/actions.
func _bake_trigger_signature(event_row: EventRow, definition: ACEDefinition) -> void:
	if event_row == null or definition == null or definition.ace_type != ACEDefinition.ACEType.TRIGGER:
		return
	event_row.trigger_provider_id = definition.provider_id
	event_row.trigger_id = definition.id
	# Bus triggers: autoload providers connect by singleton name (project-wide signals).
	if _dock._autoload_provider_names.has(definition.provider_id):
		event_row.trigger_source_path = "autoload:%s" % str(_dock._autoload_provider_names[definition.provider_id])
	var parts: PackedStringArray = PackedStringArray()
	for parameter in definition.parameters:
		if not (parameter is Dictionary):
			continue
		var param_id: String = str((parameter as Dictionary).get("id", ""))
		if param_id.is_empty():
			continue
		var param_type: int = int((parameter as Dictionary).get("type", TYPE_NIL))
		parts.append(param_id if param_type == TYPE_NIL else "%s: %s" % [param_id, type_string(param_type)])
	event_row.trigger_args = ", ".join(parts)
	# On Language Changed compiles to the _notification virtual, which the engine
	# calls for EVERY notification - so applying the trigger auto-adds its gate
	# condition (visible in the sheet, deletable, round-trips as a plain condition).
	if definition.id == "OnLocaleChanged" and event_row.conditions.is_empty():
		var gate: ACECondition = ACECondition.new()
		gate.provider_id = "Core"
		gate.ace_id = "IsLocaleChangeNotification"
		gate.codegen_template = "what == NOTIFICATION_TRANSLATION_CHANGED"
		event_row.conditions.append(gate)


## Routes a picked condition into the event: a LOOPING condition (@ace_looping) lands as a
## pick filter (the event's actions run once per returned item), a plain one as an if-condition.
func _append_condition_entry(event_row: EventRow, definition: ACEDefinition, params: Dictionary) -> void:
	if _is_looping_condition(definition):
		event_row.pick_filters.append(_create_pick_filter_from_definition(definition, params))
	else:
		event_row.conditions.append(_create_condition_from_definition(definition, params))


func _is_looping_condition(definition: ACEDefinition) -> bool:
	return definition != null and definition.ace_type == ACEDefinition.ACEType.CONDITION and bool(definition.metadata.get("looping", false))


## A looping condition compiles through the existing pick machinery: the definition's call
## template with the dialog's params baked in becomes the loop's collection expression, and
## the annotation's iterator name scopes the loop variable. Everything downstream (the for
## emission, the pick lane UI, frame-spreading, round-trip lift) comes for free.
func _create_pick_filter_from_definition(definition: ACEDefinition, params: Dictionary) -> PickFilter:
	var pick: PickFilter = PickFilter.new()
	pick.collection_kind = PickFilter.CollectionKind.EXPRESSION
	pick.collection_value = build_looping_collection(definition, _resolve_definition_params(definition, params))
	pick.iterator_name = str(definition.metadata.get("looping_iterator", "item"))
	return pick


## The final collection expression for a looping condition: the baked call template with
## every {param} token substituted. Static and pure, so tests pin it headless.
static func build_looping_collection(definition: ACEDefinition, resolved_params: Dictionary) -> String:
	var explicit: String = str(definition.metadata.get("codegen_template", ""))
	var template: String = explicit if not explicit.strip_edges().is_empty() else definition.instance_backed_template()
	for key: Variant in resolved_params.keys():
		template = template.replace("{%s}" % str(key), str(resolved_params[key]))
	return template


func _create_condition_from_definition(definition: ACEDefinition, params: Dictionary) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = definition.provider_id
	condition.ace_id = definition.id
	condition.params = _resolve_definition_params(definition, params)
	# Bake the custom/addon codegen template so the ACE compiles standalone.
	condition.codegen_template = _baked_template_for(definition)
	# Stateful conditions (Every X Seconds…): bake a fresh uid into the member/prelude/
	# on-true/template so every applied instance owns its own state.
	var member_template: String = str(definition.metadata.get("member_template", ""))
	if not member_template.is_empty():
		var stateful_uid: String = _dock._fresh_uid_token()
		condition.member_declaration = member_template.replace("{uid}", stateful_uid)
		condition.codegen_prelude = str(definition.metadata.get("codegen_prelude", "")).replace("{uid}", stateful_uid)
		condition.codegen_on_true = str(definition.metadata.get("codegen_on_true", "")).replace("{uid}", stateful_uid)
		condition.codegen_on_exit = str(definition.metadata.get("codegen_on_exit", "")).replace("{uid}", stateful_uid)
		condition.codegen_template = condition.codegen_template.replace("{uid}", stateful_uid)
	# Edge gates (Trigger Once style, descriptor .evaluated_last()): the compiler hoists the term to the
	# end of the chain so any condition-cell position works. Baked so the flag rides the saved sheet.
	condition.evaluate_last = bool(definition.metadata.get("evaluate_last", false))
	return condition


func _create_action_from_definition(definition: ACEDefinition, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = definition.provider_id
	action.ace_id = definition.id
	action.params = _resolve_definition_params(definition, params)
	# Bake the custom/addon codegen template so the ACE compiles standalone.
	action.codegen_template = _baked_template_for(definition)
	# Multi-statement action templates declare locals - bake a fresh uid per instance.
	if action.codegen_template.contains("{uid}"):
		action.codegen_template = action.codegen_template.replace("{uid}", _dock._fresh_uid_token())
	return action


## The codegen template baked onto applied ACEs. Explicit @ace_codegen_template wins; addon
## METHODS without one become **instance-backed**: the call targets a per-provider member
## (`__eventsheet_provider_<Class>.method({args})`) that the compiler declares as a plain
## owned instance of the addon class - so template-less addon ACEs compile and run in
## exported games with zero EventForge dependency (the addon script ships like any class).
func _baked_template_for(definition: ACEDefinition) -> String:
	var explicit: String = str(definition.metadata.get("codegen_template", ""))
	if not explicit.strip_edges().is_empty():
		return explicit
	# The owned-instance synthesis lives ON the definition so the picker and expression
	# previews show exactly what this bake produces.
	return definition.instance_backed_template()


func _resolve_definition_params(definition: ACEDefinition, row_params: Dictionary) -> Dictionary:
	return _dock._param_resolver.resolve_all(definition, row_params if row_params != null else {})


func _insert_row_below_selection(row_resource: Resource, explicit_selected_resource: Resource = null) -> void:
	_insert_row_at_selection(row_resource, explicit_selected_resource, 1)


func _insert_row_above_selection(row_resource: Resource, explicit_selected_resource: Resource = null) -> void:
	_insert_row_at_selection(row_resource, explicit_selected_resource, 0)


## Shared placement for Insert Above / Below: same anchor resolution, only the offset differs
## (0 = the anchor's own slot, pushing it down; 1 = right after it).
func _insert_row_at_selection(row_resource: Resource, explicit_selected_resource: Resource, offset: int) -> void:
	if _dock._current_sheet == null or row_resource == null:
		return
	var selected_resource: Resource = explicit_selected_resource if explicit_selected_resource != null else _dock._active_view().get_selected_context().get("source_resource", null)
	if selected_resource == null:
		_dock._current_sheet.events.append(row_resource)
		return
	# Anchoring on a published-verb header (its source_resource is the EventFunction) targets that verb's own
	# body on an AUTHORED sheet, so adding an event with the header selected grows the function - including
	# its FIRST row when the body is empty - instead of leaking into the main event loop. On an opened pack
	# the body stays read-only (bodies are inert), so the header anchor keeps its prior main-loop fallback.
	if selected_resource is EventFunction:
		if _sheet_is_authored():
			(selected_resource as EventFunction).events.append(row_resource)
		else:
			_dock._current_sheet.events.append(row_resource)
		return
	var location: Dictionary = _find_resource_location(selected_resource)
	var container: Array = location.get("container", _dock._current_sheet.events)
	var index: int = int(location.get("index", container.size() - 1))
	container.insert(index + offset, row_resource)


func _find_resource_location(target: Resource) -> Dictionary:
	var in_events: Dictionary = _find_resource_location_in_array(target, _dock._current_sheet.events)
	if not in_events.is_empty():
		return in_events
	# An editable function's body lives in sheet.functions[].events - a SEPARATE array from sheet.events - so
	# resolve a body row's container there, letting add / delete / drag reach the right array. The model
	# never aliases a resource across both, so searching events first is safe. Only LIVE body rows reach this
	# search (an authored sheet's bodies, or an opened pack's per-function opted-in body); every still-inert
	# opened-pack body has a null source_resource, so it is never located and its .gd round-trip is untouched.
	for function_entry: Variant in _dock._current_sheet.functions:
		if function_entry is EventFunction:
			var event_function: EventFunction = function_entry as EventFunction
			var body: Array = event_function.events if not event_function.events.is_empty() else event_function.rows
			var in_body: Dictionary = _find_resource_location_in_array(target, body)
			if not in_body.is_empty():
				return in_body
	return {}


## Which top-level tree a row lives in: the sheet itself (its main event list, including groups and
## sub-events) or a specific EventFunction (its editable body). A drag may reorder rows within ONE tree but
## must never move one across trees, so _move_rows refuses a source and target whose owners differ. Returns
## null when the resource is in neither tree (e.g. an inert opened-pack body row, whose source is nulled).
## True when the current sheet is AUTHORED - a .tres / new sheet with no opened .gd behind it (empty
## external_source_path) and not a read-only preview - so its function bodies are freely editable. An opened
## behaviour pack has verbatim source to protect, so its verb bodies stay read-only until per-function opt-in.
func _sheet_is_authored() -> bool:
	var sheet: EventSheetResource = _dock._current_sheet
	return sheet != null and sheet.external_source_path.strip_edges().is_empty() and not sheet.read_only


func _row_tree_owner(target: Resource) -> Object:
	if not _find_resource_location_in_array(target, _dock._current_sheet.events).is_empty():
		return _dock._current_sheet
	for function_entry: Variant in _dock._current_sheet.functions:
		if function_entry is EventFunction:
			var event_function: EventFunction = function_entry as EventFunction
			var body: Array = event_function.events if not event_function.events.is_empty() else event_function.rows
			if not _find_resource_location_in_array(target, body).is_empty():
				return event_function
	return null


func _find_resource_location_in_array(target: Resource, container: Array) -> Dictionary:
	for index in range(container.size()):
		var entry: Resource = container[index]
		if entry == target:
			return {"container": container, "index": index}
		if entry is EventGroup:
			var group_children: Array = _group_children_array(entry as EventGroup)
			var nested_group: Dictionary = _find_resource_location_in_array(target, group_children)
			if not nested_group.is_empty():
				return nested_group
		elif entry is EventRow:
			var nested_event: Dictionary = _find_resource_location_in_array(target, (entry as EventRow).sub_events)
			if not nested_event.is_empty():
				return nested_event
	return {}


func _group_children_array(group: EventGroup) -> Array:
	if not group.events.is_empty():
		return group.events
	return group.rows


func _on_row_drop_requested(source_row: EventRowData, target_row: EventRowData, drop_mode: String = "before", copy_mode: bool = false) -> void:
	if source_row == null:
		return
	_move_rows([source_row], target_row, drop_mode, copy_mode)


func _on_rows_drop_requested(
	source_rows: Array,
	target_row: EventRowData,
	drop_mode: String = "before",
	copy_mode: bool = false
) -> void:
	_move_rows(source_rows, target_row, drop_mode, copy_mode)


func _move_rows(source_rows: Array, target_row: EventRowData, drop_mode: String, copy_mode: bool = false) -> void:
	if target_row == null or _dock._current_sheet == null or source_rows.is_empty():
		return
	var target_resource: Resource = target_row.source_resource
	if target_resource == null:
		return
	# A drag may reorder rows WITHIN one tree - the sheet's main event list (with its groups and
	# sub-events) or a single editable function's body - but must never cross between them. Moving a main
	# event into a verb body (or the reverse) would emit unintended code, e.g. a trigger row inside a plain
	# function, so a cross-tree drop is refused. Both trees resolve to the same owner for an in-tree move.
	var target_owner: Object = _row_tree_owner(target_resource)
	var source_resources: Array[Resource] = []
	for source_row in source_rows:
		if not (source_row is EventRowData):
			continue
		var source_resource: Resource = (source_row as EventRowData).source_resource
		if source_resource == null or source_resource == target_resource or source_resources.has(source_resource):
			continue
		if _row_tree_owner(source_resource) != target_owner:
			_dock._set_status("Cannot move a row between the sheet and a function's body.", true)
			return
		if not copy_mode and _dock._resource_contains_descendant(source_resource, target_resource):
			_dock._set_status("Cannot move a row into one of its descendants.", true)
			return
		source_resources.append(source_resource)
	if source_resources.is_empty():
		return
	# Undo-funnel lambda captures `self` (this helper): helper calls stay bare, dock state is `_dock.`.
	var moved: bool = _dock._perform_undoable_sheet_edit("Drag Row", func() -> bool:
		var inserted_resources: Array[Resource] = []
		if copy_mode:
			for source_resource in source_resources:
				inserted_resources.append(source_resource.duplicate(true))
		else:
			# Only rows actually removed get re-inserted. A source we cannot locate in the live sheet - e.g.
			# an inert function-body row, whose resource lives in event_function.events and NOT sheet.events -
			# is left untouched (never removed, never inserted), so it can't be aliased into two arrays and
			# emitted twice. Aliasing there would corrupt an opened .gd's byte round-trip.
			for source_resource in source_resources:
				var source_location: Dictionary = _find_resource_location(source_resource)
				if source_location.is_empty():
					continue
				var source_container: Array = source_location.get("container", [])
				var source_index: int = int(source_location.get("index", -1))
				if source_index >= 0 and source_index < source_container.size():
					source_container.remove_at(source_index)
					inserted_resources.append(source_resource)
			if inserted_resources.is_empty():
				return false  # nothing locatable to move - no spurious snapshot / dirty
		var target_container: Array = []
		var insertion_index: int = 0
		if drop_mode == "inside":
			if target_resource is EventGroup:
				target_container = _group_children_array(target_resource as EventGroup)
				insertion_index = target_container.size()
			elif target_resource is EventRow:
				target_container = (target_resource as EventRow).sub_events
				insertion_index = target_container.size()
		else:
			var target_location: Dictionary = _find_resource_location(target_resource)
			if target_location.is_empty():
				return false
			target_container = target_location.get("container", [])
			insertion_index = int(target_location.get("index", 0))
			if drop_mode == "after":
				insertion_index += 1
		for offset in range(inserted_resources.size()):
			target_container.insert(insertion_index + offset, inserted_resources[offset])
		return true
	)
	if moved:
		_dock._mark_dirty("Copied row via drag and drop." if copy_mode else "Moved row via drag and drop.")


func _on_viewport_ace_drop_requested(
	source_entries: Array,
	target_row: EventRowData,
	target_lane: String,
	target_ace_index: int,
	insert_mode: String,
	copy_mode: bool = false
) -> void:
	if target_row == null or not ["condition", "action"].has(target_lane):
		return
	var target_event: EventRow = target_row.source_resource as EventRow
	if target_event == null:
		return
	var normalized_entries: Array = _normalize_ace_drag_entries(source_entries, target_lane)
	if normalized_entries.is_empty():
		return
	var trigger_entries: Array = []
	var excluded_trigger_resources: Array = []
	for entry in normalized_entries:
		if _drag_entry_is_trigger_like(entry):
			trigger_entries.append(entry)
			if not copy_mode:
				var trigger_resource: Resource = entry.get("resource", null) as Resource
				if trigger_resource != null:
					excluded_trigger_resources.append(trigger_resource)
	if target_lane == "condition":
		if trigger_entries.size() > 1:
			_dock._set_status("Events can only have one trigger.", true)
			return
		if not trigger_entries.is_empty() and _event_has_trigger_like(target_event, excluded_trigger_resources):
			_dock._set_status("This event already has a trigger.", true)
			return
	var target_anchor: Resource = _resolve_event_ace_resource(target_event, target_lane, target_ace_index)
	if not copy_mode and target_anchor != null:
		for entry in normalized_entries:
			if entry.get("resource", null) == target_anchor:
				target_anchor = null
				break
	# Undo-funnel lambda captures `self` (this helper): helper calls stay bare, dock state is `_dock.`.
	var moved: bool = _dock._perform_undoable_sheet_edit("Drag Cell", func() -> bool:
		var moving_resources: Array = []
		var moved_trigger: ACECondition = null
		for entry in normalized_entries:
			var source_resource: Resource = entry.get("resource", null) as Resource
			if source_resource == null:
				continue
			var inserted_resource: Resource = source_resource.duplicate(true) if copy_mode else source_resource
			if _drag_entry_is_trigger_like(entry):
				moved_trigger = inserted_resource as ACECondition
			else:
				moving_resources.append(inserted_resource)
		if not copy_mode:
			var removal_groups: Dictionary = {}
			for entry in normalized_entries:
				var source_event: EventRow = entry.get("event_row")
				var removal_entries: Array = removal_groups.get(source_event, []).duplicate()
				removal_entries.append(entry)
				removal_groups[source_event] = removal_entries
			for source_event in removal_groups.keys():
				var entries_to_remove: Array = removal_groups.get(source_event, []).duplicate()
				entries_to_remove.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
					return int(a.get("ace_index", -1)) > int(b.get("ace_index", -1))
				)
				for removal_entry in entries_to_remove:
					_remove_drag_entry_from_source(removal_entry)
		if moved_trigger != null:
			target_event.trigger = moved_trigger
		var target_array: Array = _event_ace_array(target_event, target_lane)
		var insertion_index: int = target_array.size()
		if target_anchor != null:
			var anchor_index: int = target_array.find(target_anchor)
			if anchor_index >= 0:
				insertion_index = anchor_index + (1 if insert_mode == "after" else 0)
		for offset in range(moving_resources.size()):
			target_array.insert(insertion_index + offset, moving_resources[offset])
		return moved_trigger != null or not moving_resources.is_empty()
	)
	if moved:
		_dock._mark_dirty("Copied the cell via drag and drop." if copy_mode else "Moved the cell via drag and drop.")


func _normalize_ace_drag_entries(source_entries: Array, lane: String) -> Array:
	var normalized: Array = []
	for entry in source_entries:
		if not (entry is Dictionary):
			continue
		var entry_dict: Dictionary = entry
		var source_event: EventRow = entry_dict.get("source_resource", null) as EventRow
		var kind: String = str(entry_dict.get("kind", ""))
		var ace_index: int = int(entry_dict.get("ace_index", -1))
		var lane_matches: bool = (
			kind == "action" if lane == "action" else kind in ["condition", "trigger"]
		)
		if source_event == null or not lane_matches or ace_index < 0:
			continue
		var ace_resource: Resource = _resolve_event_ace_resource(source_event, kind, ace_index)
		if ace_resource == null:
			continue
		normalized.append({
			"event_row": source_event,
			"kind": kind,
			"ace_index": ace_index,
			"resource": ace_resource
		})
	return normalized


func _remove_drag_entry_from_source(entry: Dictionary) -> void:
	var source_event: EventRow = entry.get("event_row", null) as EventRow
	if source_event == null:
		return
	var kind: String = str(entry.get("kind", ""))
	var ace_index: int = int(entry.get("ace_index", -1))
	match kind:
		"trigger":
			if source_event.trigger == entry.get("resource", null):
				source_event.trigger = null
		"condition":
			if ace_index >= 0 and ace_index < source_event.conditions.size():
				source_event.conditions.remove_at(ace_index)
		"action":
			if ace_index >= 0 and ace_index < source_event.actions.size():
				source_event.actions.remove_at(ace_index)


func _drag_entry_is_trigger_like(entry: Dictionary) -> bool:
	if str(entry.get("kind", "")) == "trigger":
		return true
	var resource: Resource = entry.get("resource", null) as Resource
	return resource is ACECondition and _is_trigger_condition(resource as ACECondition)


func _event_has_trigger_like(event_row: EventRow, excluded_resources: Array = []) -> bool:
	if event_row == null:
		return false
	if event_row.trigger != null and not excluded_resources.has(event_row.trigger):
		return true
	if not event_row.trigger_id.is_empty():
		return true
	for condition in event_row.conditions:
		if not (condition is ACECondition):
			continue
		if excluded_resources.has(condition):
			continue
		if _is_trigger_condition(condition as ACECondition):
			return true
	return false


func _is_trigger_condition(condition: ACECondition) -> bool:
	if condition == null:
		return false
	var definition: ACEDefinition = _dock._find_definition(condition.provider_id, condition.ace_id)
	if definition != null:
		return definition.ace_type == ACEDefinition.ACEType.TRIGGER
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(condition.provider_id, condition.ace_id)
	return descriptor != null and descriptor.ace_type == ACEDescriptor.ACEType.TRIGGER


func _event_ace_array(event_row: EventRow, lane: String) -> Array:
	if lane == "condition":
		return event_row.conditions
	return event_row.actions


func _resolve_event_ace_resource(event_row: EventRow, lane: String, ace_index: int) -> Resource:
	if event_row == null or ace_index < 0:
		return null
	if lane == "trigger":
		return event_row.trigger
	var ace_array: Array = _event_ace_array(event_row, lane)
	if ace_index < ace_array.size() and ace_array[ace_index] is Resource:
		return ace_array[ace_index]
	return null


func _on_ace_preview_requested(source_label: String, definitions: Array[ACEDefinition]) -> void:
	if _dock._preview_window == null or _dock._preview_list == null:
		return
	_dock._preview_window.title = "Dropped Node Preview - %s (%d)" % [source_label, definitions.size()]
	_dock._preview_title.text = "Dropped Node Preview - %s (%d)" % [source_label, definitions.size()]
	_dock._preview_list.clear()
	for definition in definitions:
		_dock._preview_list.add_item("[%s] %s" % [_ace_type_label(definition.ace_type), definition.format_display()])
	if definitions.is_empty():
		_dock._preview_list.add_item("No actions or conditions were found on the dropped node.")
	_dock._preview_window.popup_centered(Vector2i(560, 320))


func _ace_type_label(ace_type: int) -> String:
	match ace_type:
		ACEDefinition.ACEType.CONDITION:
			return "Condition"
		ACEDefinition.ACEType.TRIGGER:
			return "Trigger"
		ACEDefinition.ACEType.EXPRESSION:
			return "Expression"
		_:
			return "Action"


func _on_viewport_drag_status_requested(message: String, is_error: bool) -> void:
	_dock._set_status(message, is_error)
