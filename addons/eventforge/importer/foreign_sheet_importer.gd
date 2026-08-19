# EventForge - reading an event sheet exported from another event-sheet editor
#
# That editor saves a project as a zip whose members are JSON: one project file naming the project,
# then eventSheets/<name>.json, layouts/<name>.json, objectTypes/<name>.json, families/<name>.json.
# An event sheet file is {"name": ..., "events": [...]} and each entry in `events` is tagged by its
# `eventType`: "block" (conditions + actions + children), "group", "comment", "variable",
# "include", "function-block", "script". A condition or action carries `objectClass`, `id`,
# `parameters`, and optionally `behavior-type`, `isInverted`, `isOr` and `disabled`.
#
# This reads that tree and hands back an EventSheetResource plus an EXACT report. The one rule the
# whole file is built around: never pretend. A row the vocabulary can spell becomes that row; a row
# it cannot becomes a DISABLED row whose original words survive as a comment, counted and named in
# the report; a parameter that arrived in a spelling only the other editor understands is kept
# verbatim and flagged. Nothing is silently dropped and nothing is silently approximated.
#
# The source file is only ever READ. Saving happens through the compiler, into a new .gd the user
# picks, after they have looked at the result.
@tool
class_name EventSheetForeignImporter
extends RefCounted

## The stable words an unmapped row leaves in the generated file. The project health check greps
## for exactly this, so changing it changes a shipped finding - deprecate, never re-spell.
const UNMAPPED_MARKER: String = "Not mapped on import:"

## The stable words a kept-verbatim parameter leaves behind.
const FLAGGED_MARKER: String = "Check on import:"

## Where the members of an exported project live inside the zip.
const SHEETS_DIR: String = "eventSheets/"
const OBJECTS_DIR: String = "objectTypes/"
const FAMILIES_DIR: String = "families/"


## Reads an exported project archive. Returns
## {"ok": bool, "error": String, "project_name": String, "sheets": {name: Dictionary},
##  "objects": {name: kind}, "families": PackedStringArray}.
## The archive is opened read-only and closed again; nothing is written back to it, ever.
static func read_project(archive_path: String) -> Dictionary:
	var result: Dictionary = {
		"ok": false, "error": "", "project_name": "", "sheets": {}, "objects": {},
		"families": PackedStringArray(),
	}
	var reader: ZIPReader = ZIPReader.new()
	if reader.open(archive_path) != OK:
		result["error"] = "That file could not be opened as a project archive."
		return result
	for entry: String in reader.get_files():
		var text: String = reader.read_file(entry).get_string_from_utf8()
		var parsed: Variant = JSON.parse_string(text)
		if not (parsed is Dictionary):
			continue
		var data: Dictionary = parsed as Dictionary
		if entry.begins_with(SHEETS_DIR) and entry.ends_with(".json"):
			var sheet_name: String = str(data.get("name", entry.get_file().get_basename()))
			(result["sheets"] as Dictionary)[sheet_name] = data
		elif entry.begins_with(OBJECTS_DIR) and entry.ends_with(".json"):
			var object_name: String = str(data.get("name", entry.get_file().get_basename()))
			(result["objects"] as Dictionary)[object_name] = object_kind_for_plugin(str(data.get("plugin-id", "")))
		elif entry.begins_with(FAMILIES_DIR) and entry.ends_with(".json"):
			(result["families"] as PackedStringArray).append(str(data.get("name", entry.get_file().get_basename())))
		elif data.has("projectFormatVersion") or entry.ends_with(".c3proj"):
			result["project_name"] = str(data.get("name", ""))
	reader.close()
	if (result["sheets"] as Dictionary).is_empty():
		result["error"] = "No event sheets were found in that archive."
		return result
	result["ok"] = true
	return result


## Reads one exported event sheet file. Returns {"ok": bool, "error": String, "sheet": Dictionary}.
static func read_sheet_file(json_path: String) -> Dictionary:
	if not FileAccess.file_exists(json_path):
		return {"ok": false, "error": "That file does not exist.", "sheet": {}}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not (parsed is Dictionary) or not (parsed as Dictionary).has("events"):
		return {"ok": false, "error": "That file is not an exported event sheet.", "sheet": {}}
	return {"ok": true, "error": "", "sheet": parsed as Dictionary}


## The object kind an exported object type answers to, from the plugin that made it.
static func object_kind_for_plugin(plugin_id: String) -> String:
	var lowered: String = plugin_id.to_lower()
	if lowered.contains("sprite"):
		return "Sprite"
	if lowered.contains("text") or lowered.contains("spritefont"):
		return "Text"
	if lowered.contains("audio"):
		return "Audio"
	if lowered.contains("array"):
		return "Array"
	if lowered.contains("dictionary"):
		return "Dictionary"
	if lowered.is_empty():
		return "Object"
	return "Object"


## Every object name the sheet actually mentions, sorted, so the wizard's mapping table lists the
## objects this sheet needs rather than every object in the project.
static func object_names(sheet_json: Dictionary) -> PackedStringArray:
	var seen: Dictionary = {}
	_collect_object_names(sheet_json.get("events", []) as Array, seen)
	var names: Array = seen.keys()
	names.sort()
	var out: PackedStringArray = PackedStringArray()
	for entry: String in names:
		out.append(entry)
	return out


static func _collect_object_names(events: Array, seen: Dictionary) -> void:
	for entry: Variant in events:
		if not (entry is Dictionary):
			continue
		var event: Dictionary = entry as Dictionary
		for cell: Variant in (event.get("conditions", []) as Array) + (event.get("actions", []) as Array):
			if cell is Dictionary:
				var object_name: String = str((cell as Dictionary).get("objectClass", "")).strip_edges()
				if not object_name.is_empty() and not EventSheetForeignACEMap.SYSTEM_OBJECT_KINDS.has(object_name):
					seen[object_name] = true
		_collect_object_names(event.get("children", []) as Array, seen)


## The mapping table the wizard shows before anything is imported: one row per object the sheet
## mentions, pre-filled with the kind the project said it was and a node name that matches.
static func default_object_map(sheet_json: Dictionary, project_objects: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	for object_name: String in object_names(sheet_json):
		out[object_name] = {
			"kind": str(project_objects.get(object_name, "Object")),
			"node": "$%s" % object_name,
		}
	return out


## The whole import as one pure function: an exported sheet plus the object mapping in, a sheet and
## an exact report out. No file is touched and no window is needed, so the wizard's preview, the
## Save As… path and the tests all run the very same code.
##
## Returns {"sheet": EventSheetResource, "report": Dictionary} where report is
## {"total": int, "mapped": int, "percent": int, "unmapped": Array, "flagged": Array,
##  "notes": Array}.
static func import_sheet(sheet_json: Dictionary, object_map: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = str(options.get("host_class", "Node2D"))
	sheet.custom_class_name = ""
	var report: Dictionary = {
		"total": 0, "mapped": 0, "percent": 100,
		"unmapped": [], "flagged": [], "notes": [],
	}
	var context: Dictionary = {"objects": object_map, "report": report, "sheet": sheet}
	var title: String = str(sheet_json.get("name", "")).strip_edges()
	if not title.is_empty():
		var heading: CommentRow = CommentRow.new()
		heading.style = CommentRow.CommentStyle.SECTION
		heading.text = "%s - imported from another event-sheet editor. Rows it could not spell are switched off with their original words beside them." % title
		sheet.events.append(heading)
	var rows: Array = _convert_events(sheet_json.get("events", []) as Array, context, true)
	for row: Resource in rows:
		sheet.events.append(row)
	report["percent"] = 100 if int(report["total"]) == 0 else int(round(100.0 * float(report["mapped"]) / float(report["total"])))
	return {"sheet": sheet, "report": report}


## "12 of 14 rows mapped (86%)" - the report in one line, exactly as counted.
static func report_summary(report: Dictionary) -> String:
	return "%d of %d rows mapped (%d%%)" % [int(report.get("mapped", 0)), int(report.get("total", 0)), int(report.get("percent", 100))]


# --- the tree ---------------------------------------------------------------------------------


static func _convert_events(events: Array, context: Dictionary, top_level: bool) -> Array:
	var out: Array = []
	for entry: Variant in events:
		if not (entry is Dictionary):
			continue
		var event: Dictionary = entry as Dictionary
		match str(event.get("eventType", "block")):
			"group":
				out.append(_convert_group(event, context))
			"comment":
				out.append(_convert_comment(event, context))
			"variable":
				out.append(_convert_variable(event, context))
			"include":
				out.append(_convert_include(event, context))
			"function-block":
				_convert_function(event, context)
			"script":
				out.append(_script_comment(str(event.get("script", "")), context))
			_:
				for row: Resource in _convert_block(event, context, top_level):
					out.append(row)
	return out


## A block becomes one event row: its conditions become conditions (the first that needs a run
## context opens the trigger), its actions become actions, its children become sub-events. A
## top-level block with no trigger of its own runs every frame, which is what a top-level event
## means in the sheet it came from.
static func _convert_block(event: Dictionary, context: Dictionary, top_level: bool) -> Array:
	var row: EventRow = EventRow.new()
	row.enabled = not bool(event.get("disabled", false))
	if bool(event.get("isElse", false)):
		row.else_mode = EventRow.ElseMode.ELSE
	var leading: Array = []
	for cell: Variant in event.get("conditions", []) as Array:
		if not (cell is Dictionary):
			continue
		var source: Dictionary = cell as Dictionary
		if bool(source.get("isOr", false)):
			row.condition_mode = EventRow.ConditionMode.OR
		var built: Dictionary = _build_cell(source, context, EventSheetForeignACEMap.KIND_CONDITION)
		if built.is_empty():
			row.enabled = false
			row.comment = _cell_label(source, context)
			leading.append(_unmapped_comment(source, context))
			continue
		if built.has("trigger") and row.trigger_id.is_empty():
			row.trigger_provider_id = "Core"
			row.trigger_id = str(built["trigger"])
		if built.get("kind", "") == EventSheetForeignACEMap.KIND_TRIGGER:
			row.trigger_provider_id = "Core"
			row.trigger_id = str(built["ace"])
			continue
		var condition: ACECondition = ACECondition.new()
		condition.provider_id = "Core"
		condition.ace_id = str(built["ace"])
		condition.params = built["params"] as Dictionary
		condition.negated = bool(source.get("isInverted", false))
		condition.comment = str(built.get("note", ""))
		row.conditions.append(condition)
	for cell: Variant in event.get("actions", []) as Array:
		if not (cell is Dictionary):
			continue
		var action_source: Dictionary = cell as Dictionary
		if str(action_source.get("type", "")) == "script":
			row.actions.append(_script_comment(str(action_source.get("script", "")), context))
			continue
		var built_action: Dictionary = _build_cell(action_source, context, EventSheetForeignACEMap.KIND_ACTION)
		if built_action.is_empty():
			row.actions.append(_unmapped_comment(action_source, context))
			continue
		var action: ACEAction = ACEAction.new()
		action.provider_id = "Core"
		action.ace_id = str(built_action["ace"])
		action.params = built_action["params"] as Dictionary
		action.enabled = not bool(action_source.get("disabled", false))
		action.comment = str(built_action.get("note", ""))
		row.actions.append(action)
	for child: Resource in _convert_events(event.get("children", []) as Array, context, false):
		row.sub_events.append(child)
	if top_level and row.trigger_id.is_empty() and row.else_mode == EventRow.ElseMode.NONE:
		row.trigger_provider_id = "Core"
		row.trigger_id = "OnProcess"
	var out: Array = leading
	out.append(row)
	return out


static func _convert_group(event: Dictionary, context: Dictionary) -> EventGroup:
	var group: EventGroup = EventGroup.new()
	group.name = str(event.get("title", "Group"))
	group.description = str(event.get("description", ""))
	group.enabled = not bool(event.get("disabled", false))
	if event.has("isActiveOnStart") and not bool(event.get("isActiveOnStart", true)):
		_note(context, "The group \"%s\" started switched off. Groups here are always on; add a condition that guards it." % group.name)
	for child: Resource in _convert_events(event.get("children", []) as Array, context, true):
		group.events.append(child)
	return group


static func _convert_comment(event: Dictionary, context: Dictionary) -> CommentRow:
	_count(context, true)
	var comment: CommentRow = CommentRow.new()
	comment.text = str(event.get("text", ""))
	return comment


static func _convert_variable(event: Dictionary, context: Dictionary) -> LocalVariable:
	_count(context, true)
	var variable: LocalVariable = LocalVariable.new()
	variable.name = str(event.get("name", "value")).to_snake_case()
	variable.is_constant = bool(event.get("isConstant", false))
	variable.is_static = bool(event.get("isStatic", false))
	variable.description = str(event.get("comment", ""))
	var initial: String = str(event.get("initialValue", "")).strip_edges()
	match str(event.get("type", "number")).to_lower():
		"number":
			variable.type = TYPE_FLOAT
			variable.type_name = "float"
			variable.default_value = float(initial) if initial.is_valid_float() else 0.0
		"boolean":
			variable.type = TYPE_BOOL
			variable.type_name = "bool"
			variable.default_value = initial.to_lower() == "true" or initial == "1"
		_:
			variable.type = TYPE_STRING
			variable.type_name = "String"
			variable.default_value = initial
	return variable


static func _convert_include(event: Dictionary, context: Dictionary) -> CommentRow:
	_count(context, true)
	var included: String = str(event.get("includeSheet", "")).strip_edges()
	_note(context, "This sheet included \"%s\". Import that sheet too, then add it under Sheet > Manage Includes." % included)
	var comment: CommentRow = CommentRow.new()
	comment.style = CommentRow.CommentStyle.NOTE
	comment.text = "NOTE: this sheet included \"%s\" - import that sheet and add it under Manage Includes." % included
	return comment


## A function block becomes a sheet function: its name in the condition lane, its parameters as
## chips, its own conditions and actions as the one event inside it.
static func _convert_function(event: Dictionary, context: Dictionary) -> void:
	_count(context, true)
	var function: EventFunction = EventFunction.new()
	function.function_name = str(event.get("functionName", "do_thing")).to_snake_case()
	function.description = str(event.get("functionDescription", ""))
	function.is_async = bool(event.get("functionIsAsync", false))
	for entry: Variant in event.get("functionParameters", []) as Array:
		if not (entry is Dictionary):
			continue
		var source: Dictionary = entry as Dictionary
		var param: ACEParam = ACEParam.new()
		param.id = str(source.get("name", "value")).to_snake_case()
		param.display_name = str(source.get("name", "value"))
		param.description = str(source.get("comment", ""))
		match str(source.get("type", "number")).to_lower():
			"number":
				param.type = TYPE_FLOAT
				param.type_name = "float"
			"boolean":
				param.type = TYPE_BOOL
				param.type_name = "bool"
			_:
				param.type = TYPE_STRING
				param.type_name = "String"
		function.params.append(param)
	var body: Dictionary = {
		"conditions": event.get("conditions", []),
		"actions": event.get("actions", []),
		"children": event.get("children", []),
	}
	for row: Resource in _convert_block(body, context, false):
		function.events.append(row)
	(context["sheet"] as EventSheetResource).functions.append(function)


# --- one condition or action ------------------------------------------------------------------


## Builds one cell. Returns an empty dictionary when the vocabulary has no word for it - the caller
## then switches the row off and keeps the original words.
static func _build_cell(source: Dictionary, context: Dictionary, wanted_kind: String) -> Dictionary:
	_count(context, false)
	var object_name: String = str(source.get("objectClass", "")).strip_edges()
	var behavior: String = str(source.get("behavior-type", source.get("behaviorType", ""))).strip_edges()
	if not behavior.is_empty():
		_reject_behavior(source, context, behavior)
		return {}
	var kind: String = _object_kind(object_name, context)
	var entry: Dictionary = EventSheetForeignACEMap.lookup(kind, str(source.get("id", "")))
	if entry.is_empty():
		_reject(context, _cell_label(source, context), "No row here spells this yet.")
		return {}
	if str(entry.get("kind", "")) != wanted_kind and str(entry.get("kind", "")) != EventSheetForeignACEMap.KIND_TRIGGER:
		_reject(context, _cell_label(source, context), "This reads as a %s here, not a %s." % [entry.get("kind", ""), wanted_kind])
		return {}
	var built: Dictionary = {
		"ace": str(entry["ace"]),
		"kind": str(entry.get("kind", wanted_kind)),
		"params": {},
		"note": str(entry.get("note", "")),
	}
	if entry.has("trigger"):
		built["trigger"] = str(entry["trigger"])
	var flagged: PackedStringArray = PackedStringArray()
	for param_id: String in (entry.get("params", {}) as Dictionary):
		var filled: Dictionary = _fill_param(str((entry["params"] as Dictionary)[param_id]), source, object_name, context)
		(built["params"] as Dictionary)[param_id] = filled["text"]
		if bool(filled["flagged"]):
			flagged.append(param_id)
	if not entry.get("note", "").is_empty():
		_flag(context, _cell_label(source, context), str(entry["note"]))
	if not flagged.is_empty():
		_flag(context, _cell_label(source, context), "Kept as written: %s." % ", ".join(flagged))
		built["note"] = ("%s %s %s" % [built["note"], FLAGGED_MARKER, ", ".join(flagged)]).strip_edges()
	_count_mapped(context)
	return built


## One parameter, from the little source language in the mapping table.
static func _fill_param(source_spec: String, cell: Dictionary, object_name: String, context: Dictionary) -> Dictionary:
	if source_spec.begins_with("$"):
		return {"text": source_spec.substr(1), "flagged": false}
	if source_spec.begins_with("@"):
		var node: String = _object_node(object_name, context)
		match source_spec:
			"@node":
				return {"text": node, "flagged": node.is_empty() and not object_name.is_empty()}
			"@self":
				return {"text": node if not node.is_empty() else "self", "flagged": false}
			"@name":
				return {"text": object_name.to_snake_case(), "flagged": false}
		return {"text": node, "flagged": false}
	if source_spec.begins_with("%"):
		var parts: PackedStringArray = source_spec.substr(1).split("|")
		var values: Array = []
		var any_flagged: bool = false
		for index: int in range(1, parts.size()):
			var piece: Dictionary = _fill_param(parts[index], cell, object_name, context)
			values.append(piece["text"])
			any_flagged = any_flagged or bool(piece["flagged"])
		return {"text": parts[0] % values, "flagged": any_flagged}
	var verbatim: bool = source_spec.begins_with("!")
	var raw: String = str(_parameter(cell, source_spec.substr(1)))
	if verbatim:
		return {"text": raw, "flagged": true}
	var translated: Dictionary = EventSheetForeignACEMap.translate_expression(raw)
	return {"text": str(translated["text"]), "flagged": not bool(translated["translated"])}


## A parameter by the name the export gave it, matched loosely (the export writes human labels, and
## an editor release may re-space one).
static func _parameter(cell: Dictionary, wanted: String) -> Variant:
	var parameters: Dictionary = cell.get("parameters", {}) as Dictionary
	if parameters.has(wanted):
		return parameters[wanted]
	var normalized: String = EventSheetForeignACEMap.normalize_id(wanted)
	for key: String in parameters:
		if EventSheetForeignACEMap.normalize_id(key) == normalized:
			return parameters[key]
	return ""


# --- honesty ----------------------------------------------------------------------------------


static func _object_kind(object_name: String, context: Dictionary) -> String:
	if EventSheetForeignACEMap.SYSTEM_OBJECT_KINDS.has(object_name):
		return object_name
	var entry: Variant = (context["objects"] as Dictionary).get(object_name, {})
	if entry is Dictionary:
		return str((entry as Dictionary).get("kind", "Object"))
	return "Object"


## The node an object was mapped to. An object nobody mapped stays unmapped: the row is built at
## the sheet's own scope and the original object name is recorded, rather than guessing a node.
static func _object_node(object_name: String, context: Dictionary) -> String:
	if object_name.is_empty() or EventSheetForeignACEMap.SYSTEM_OBJECT_KINDS.has(object_name):
		return ""
	var entry: Variant = (context["objects"] as Dictionary).get(object_name, {})
	if entry is Dictionary:
		return str((entry as Dictionary).get("node", "")).strip_edges()
	return ""


static func _cell_label(cell: Dictionary, _context: Dictionary) -> String:
	var object_name: String = str(cell.get("objectClass", "")).strip_edges()
	var behavior: String = str(cell.get("behavior-type", cell.get("behaviorType", ""))).strip_edges()
	var head: String = object_name if behavior.is_empty() else "%s (%s)" % [object_name, behavior]
	return "%s ▸ %s" % [head, str(cell.get("id", ""))]


static func _unmapped_comment(cell: Dictionary, context: Dictionary) -> CommentRow:
	var comment: CommentRow = CommentRow.new()
	comment.style = CommentRow.CommentStyle.TODO
	comment.text = "%s %s" % [UNMAPPED_MARKER, _cell_label(cell, context)]
	return comment


static func _script_comment(script_text: String, context: Dictionary) -> CommentRow:
	_count(context, false)
	_reject(context, "script block", "A script block is not GDScript - rewrite it as rows or as a Script block.")
	var comment: CommentRow = CommentRow.new()
	comment.style = CommentRow.CommentStyle.TODO
	comment.text = "%s a script block\n%s" % [UNMAPPED_MARKER, script_text.strip_edges()]
	return comment


static func _reject_behavior(cell: Dictionary, context: Dictionary, behavior: String) -> void:
	var key: String = EventSheetForeignACEMap.normalize_behavior(behavior)
	if EventSheetForeignACEMap.ADOPTABLE.has(key):
		var pack: Dictionary = EventSheetForeignACEMap.ADOPTABLE[key] as Dictionary
		_reject(context, _cell_label(cell, context),
			"The shipped %s behaviour covers this - attach it (Add behavior…) and add the row from its own words." % pack["words"])
		return
	if EventSheetForeignACEMap.NO_HOME.has(key):
		_reject(context, _cell_label(cell, context), str(EventSheetForeignACEMap.NO_HOME[key]))
		return
	_reject(context, _cell_label(cell, context), "No behaviour here matches this yet.")


static func _count(context: Dictionary, mapped: bool) -> void:
	var report: Dictionary = context["report"] as Dictionary
	report["total"] = int(report["total"]) + 1
	if mapped:
		report["mapped"] = int(report["mapped"]) + 1


static func _count_mapped(context: Dictionary) -> void:
	var report: Dictionary = context["report"] as Dictionary
	report["mapped"] = int(report["mapped"]) + 1


static func _reject(context: Dictionary, label: String, reason: String) -> void:
	((context["report"] as Dictionary)["unmapped"] as Array).append({"label": label, "reason": reason})


static func _flag(context: Dictionary, label: String, reason: String) -> void:
	((context["report"] as Dictionary)["flagged"] as Array).append({"label": label, "reason": reason})


static func _note(context: Dictionary, text: String) -> void:
	((context["report"] as Dictionary)["notes"] as Array).append(text)
