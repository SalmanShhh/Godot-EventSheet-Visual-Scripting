# Godot EventSheets - what the Project Doctor needs to read a `.gd` sheet.
#
# `.gd` is the default sheet format: a script IS the sheet, and opening it lifts its lines into
# rows. The Doctor's sheet checks used to be handed only the project's `.tres` files, so in a
# project of scripts they said nothing at all and gave no sign they had not looked. This file holds
# the three small things that widening needs, kept out of `project_doctor.gd` so that file does not
# grow by them:
#
#   * which scripts count as the reader's sheets (`script_sheets`)
#   * how a script says "debug code is compiled in" (`residue_in_source`) - a `.tres` sheet keeps
#     four switches for that, a script keeps only the lines the switches wrote
#   * the one sentence that says which checks did NOT apply to a script, and why (`coverage_finding`)
#
# DELIBERATELY NO `class_name`, so loading it compiles nothing more: reach it with a const preload.
@tool
extends RefCounted

## The checks that do not read a script, each with the reason, in the order the note lists them. The
## reason is part of the check's contract: a check that skips a whole format must say why, or the
## silence it leaves is the thing this file exists to remove.
const NOT_APPLIED: Array[Dictionary] = [
	{"name": "generated outputs", "why": "a script is its own output, so it cannot be out of date with itself (the sheet-contract gate checks that a script opens and saves back to the same bytes)"},
	{"name": "autoload registration", "why": "a script is an autoload only because the project registers it, so none can be left unregistered"},
	{"name": "duplicated globals", "why": "a variable in a script is that script's own member, and two scripts naming the same member is ordinary rather than one shared value"},
	{"name": "every-tick setup", "why": "a blank event has no spelling in a script, where every line sits under a function"},
	{"name": "tidiness notes", "why": "a function or signal in a script is a public offer to code that may call it from anywhere"},
]

## Where Godot keeps the starter files it offers for a new script. They are blueprints with
## placeholders in them, not game code.
const SCRIPT_TEMPLATES := "res://script_templates/"


## The project's own scripts, opened as sheets by the checks: every `.gd` the audit walks (so a folder
## the project declared out of its audit stays out), minus this plugin's own code, the packs the
## plugin ships and the starter files Godot offers. Path order, like every list the audit walks.
static func script_sheets() -> PackedStringArray:
	var sheets: PackedStringArray = PackedStringArray()
	for script_path: String in EventSheetDoctorSection.own_paths(EventSheetProjectDoctor._project_scripts()):
		if script_path.begins_with(SCRIPT_TEMPLATES) or EventSheetTemplates.is_template_path(script_path):
			continue
		sheets.append(script_path)
	return sheets


## What debug code a script's own text carries, as the words the `.tres` check uses for the same four
## switches. Each marker is a line only the compiler's debug switches write: the live-values timer,
## the trace buffer, the replay receiver's banner, and a `breakpoint` statement on a line of its own
## (a comment or a string that merely says the word never matches).
static func residue_in_source(source: String) -> PackedStringArray:
	var flags: PackedStringArray = PackedStringArray()
	for line: String in source.split("\n"):
		if line.strip_edges() == "breakpoint":
			flags.append("breakpoints")
			break
	if source.contains("var __live_values_timer"):
		flags.append("live-values telemetry")
	if source.contains("var __eventsheets_fired"):
		flags.append("event trace")
	if source.contains("## Replay recording receiver (debug sessions only)."):
		flags.append("replay recording")
	return flags


## The one note that says how much of the project the sheet checks read and which of them did not
## apply to a script. Empty when there were no scripts, because then nothing was left unsaid.
static func coverage_finding(tres_count: int, script_count: int) -> Dictionary:
	if script_count <= 0:
		return {}
	var parts: PackedStringArray = PackedStringArray()
	for entry: Dictionary in NOT_APPLIED:
		parts.append("%s (%s)" % [str(entry["name"]), str(entry["why"])])
	var message: String = "The sheet checks read %d .gd sheet(s) and %d .tres sheet(s). These checks do not apply to a .gd sheet: %s." % [
		script_count, tres_count, "; ".join(parts)]
	return {"severity": "info", "check": "sheet-coverage", "path": "", "message": message, "event": 0}


## Whether something other than a scene gives a script a reason to exist: it names a class (so other
## code can use it by that name), another script or a saved resource points at its path, or it is a
## registered autoload. A script with none of those and no scene is the one worth a note.
static func script_is_reached(script_path: String) -> bool:
	var own_source: String = EventSheetProjectDoctor.source_of(script_path)
	if RegEx.create_from_string("(?m)^class_name\\s").search(own_source) != null:
		return true
	for other_path: String in EventSheetProjectDoctor._project_scripts():
		if other_path != script_path and EventSheetProjectDoctor.source_of(other_path).contains(script_path):
			return true
	for resource_path: String in EventSheetProjectDoctor._list_files_with_extension("tres"):
		if EventSheetProjectDoctor.source_of(resource_path).contains(script_path):
			return true
	for property: Dictionary in ProjectSettings.get_property_list():
		if str(property.get("name", "")).begins_with("autoload/") \
				and str(ProjectSettings.get_setting(str(property.get("name")))).trim_prefix("*") == script_path:
			return true
	return false


## Whether a variable of this script is read or written anywhere the sheet's rows do not show: in the
## script's own lines the importer kept as code, or as `something.name` in another project script. A
## member of a script is public to every other script, which a `.tres` sheet's compiled output is not.
static func script_names_it(script_path: String, variable_name: String) -> bool:
	var name_pattern: RegEx = RegEx.create_from_string("\\b%s\\b" % variable_name)
	var declaration: RegEx = RegEx.create_from_string("^\\s*(@[A-Za-z_]+(\\([^)]*\\))?\\s*)*(static\\s+)?(var|const)\\s+%s\\b" % variable_name)
	for line: String in EventSheetProjectDoctor.source_of(script_path).split("\n"):
		if declaration.search(line) == null and name_pattern.search(line) != null:
			return true
	var member_use: RegEx = RegEx.create_from_string("\\.%s\\b" % variable_name)
	for other_path: String in EventSheetProjectDoctor._project_scripts():
		if other_path != script_path and member_use.search(EventSheetProjectDoctor.source_of(other_path)) != null:
			return true
	return false


## Every name a line of this sheet may use that is not a member: its locals, the parameters of its
## functions and of its handlers, a loop's item and counter, and the names a line kept as code
## declares. {name: true}, over the WHOLE sheet - the canvas settles which body a name belongs to,
## and the audit, which must never accuse a working line, settles for "declared somewhere".
static func local_names_anywhere(sheet: EventSheetResource) -> Dictionary:
	var names: Dictionary = {}
	if sheet == null:
		return names
	_note_local_names(sheet.events, names, {})
	_note_local_names(sheet.functions, names, {})
	return names


static func _note_local_names(entries: Variant, names: Dictionary, walked: Dictionary) -> void:
	if not (entries is Array):
		return
	for entry: Variant in entries:
		if not (entry is Resource) or walked.has(entry):
			continue
		walked[entry] = true
		if entry is RawCodeRow:
			EventSheetViewportRowBuilder._collect_code_declared_names((entry as RawCodeRow).code, names)
			continue
		if entry is LocalVariable:
			continue  # A variable row among the events is a MEMBER, and the member list already has it.
		if entry is EventRow:
			var event_row: EventRow = entry as EventRow
			for action: Variant in event_row.actions:
				if action is RawCodeRow:
					EventSheetViewportRowBuilder._collect_code_declared_names((action as RawCodeRow).code, names)
				elif action is ACEAction and EventSheetViewportRowBuilder.LOCAL_DECLARATION_ACES.has((action as ACEAction).ace_id):
					var params: Dictionary = (action as ACEAction).params if not (action as ACEAction).params.is_empty() else (action as ACEAction).parameters
					names[str(params.get("name", "")).strip_edges()] = true
			for local: Variant in event_row.local_variables:
				if local is LocalVariable:
					names[(local as LocalVariable).name.strip_edges()] = true
			for filter: PickFilter in event_row.pick_filters:
				if filter != null:
					EventSheetViewportRowBuilder._collect_parameter_names(PackedStringArray([filter.iterator_name, filter.index_name]), names)
			EventSheetViewportRowBuilder._collect_parameter_names(event_row.trigger_args.split(","), names)
			if not event_row.trigger_id.is_empty():
				EventSheetViewportRowBuilder._collect_parameter_names(
					str(EventSheetTriggerResolver.resolve_trigger(event_row).get("args", "")).split(","), names)
			_note_local_names(event_row.sub_events, names, walked)
			continue
		if entry is EventGroup:
			for local: Variant in (entry as EventGroup).local_variables:
				if local is LocalVariable:
					names[(local as LocalVariable).name.strip_edges()] = true
		if entry is EventFunction:
			var function: EventFunction = entry as EventFunction
			for param: ACEParam in function.params:
				if param != null and not param.id.strip_edges().is_empty():
					names[param.id.strip_edges()] = true
			EventSheetViewportRowBuilder._collect_parameter_names(PackedStringArray(function.parameters), names)
			for local_name: Variant in function.local_variables.keys():
				names[str(local_name)] = true
		for key: String in ["events", "rows"]:
			_note_local_names((entry as Resource).get(key), names, walked)
