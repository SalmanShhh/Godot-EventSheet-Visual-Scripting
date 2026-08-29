# Godot EventSheets - the one description per thing the user made.
#
# A function, a variable, a group, a signal and the sheet itself can each carry ONE line of prose
# saying what it is for. That line is not a field this plugin invented: it is the `##` documentation
# comment the generated GDScript already writes directly above the declaration, so the same words
# are there for a reader who never installs the plugin, survive a save, and come back byte for byte
# on the next open. Typing it into a dialog and typing it into the file are the same act.
#
# THERE IS NO SECOND STORE, and this file is the reason that stays true: every reader - the picker
# entry, the completion detail, a dialog's help strip, the generated manual, the project view, the
# Doctor - asks HERE, and every writer writes back to the field this file names. Nothing caches a
# description anywhere else, so two places can never disagree about what a function is for.
#
# WHERE THE LINE LIVES PER KIND, and why it differs. The plugin follows the file rather than
# imposing a shape on it:
#   - the sheet: the `##` block right after `extends` (Godot's class-doc position)
#   - a function: its plain `##` block; a function PUBLISHED as a verb carries its prose in the
#     `## @ace_description(...)` line instead, because that is the text the picker shows, and the
#     picker's words and the reader's words must be one text
#   - a variable: the `##` line above the declaration, which is also its Inspector tooltip
#   - a signal: the `##` prose above its annotation block
#   - a group: the group header's `description=` field, a group having no GDScript declaration of
#     its own to sit above
#
# THE NUDGE, not a warning. An undescribed thing reads "no description yet" in soft type wherever it
# is listed. Nothing is blocked, no count goes red, and a game with no descriptions at all runs
# exactly as well as one with all of them - the nudge is there so the gap is visible at the moment
# somebody is already looking at the thing, which is the only moment writing the line is cheap.
@tool
class_name EventSheetDescriptions
extends RefCounted

## The soft placeholder shown wherever an undescribed thing is listed. One wording, so the picker,
## the manual and the project view cannot each invent their own way of saying nothing is here.
const NO_DESCRIPTION_NUDGE := "no description yet"

## The kinds a description can belong to, in the order a manual page and the project view list them:
## the sheet's own head first, then its data, then the things that act, then the groups that organize
## them. Frozen, because the manual's page order and every test that pins it read this list.
const KIND_ORDER: PackedStringArray = ["sheet", "variable", "function", "signal", "group"]


## The description of the whole sheet, as prose with its `##` prefixes already off. Empty when the
## sheet has none - callers that display it use `display()` to get the nudge instead.
static func for_sheet(sheet: EventSheetResource) -> String:
	if sheet == null:
		return ""
	return _flatten(sheet.class_description)


## The description of one function. A published verb's picker blurb IS its description, so an exposed
## function answers with that; a plain helper answers with its `##` doc comment. When a function
## somehow carries both (a hand-written file may), the doc comment wins, because that is the line a
## reader of the file sees first.
static func for_function(event_function: EventFunction) -> String:
	if event_function == null:
		return ""
	var doc: String = _flatten(event_function.doc_comment)
	if not doc.is_empty():
		return doc
	return _flatten(event_function.description)


## Which field a write from a dialog must land in for this function, so the words end up on the line
## the file already uses rather than adding a second one. Returns "doc_comment" or "description".
static func write_field_for_function(event_function: EventFunction) -> String:
	if event_function == null:
		return "doc_comment"
	if not _flatten(event_function.doc_comment).is_empty():
		return "doc_comment"
	if event_function.expose_as_ace:
		return "description"
	return "doc_comment"


## The description of one sheet variable, read out of the variable descriptor the sheet stores under
## its name. An explicit Inspector tooltip attribute wins, exactly as the emitter resolves it, so the
## words shown here are the words the generated `##` line carries.
static func for_variable(sheet: EventSheetResource, variable_name: String) -> String:
	if sheet == null:
		return ""
	var descriptor: Variant = sheet.variables.get(variable_name)
	if not descriptor is Dictionary:
		return ""
	var attributes: Variant = (descriptor as Dictionary).get("attributes")
	if attributes is Dictionary:
		var tooltip: String = _flatten(str((attributes as Dictionary).get("tooltip", "")))
		if not tooltip.is_empty():
			return tooltip
	return _flatten(str((descriptor as Dictionary).get("description", "")))


## The description of one group. Groups have no declaration of their own in the generated script, so
## the header line's `description=` field is where their prose lives and comes back from.
static func for_group(group: EventGroup) -> String:
	if group == null:
		return ""
	return _flatten(group.description)


## The description of one declared signal - the plain prose above its annotation block, which is what
## the analyzer and every reader treat as the signal's description.
static func for_signal(signal_row: Resource) -> String:
	if signal_row == null or not ("description" in signal_row):
		return ""
	return _flatten(str(signal_row.get("description")))


## What to SHOW for a description: the words when there are any, and the soft nudge when there are
## none. Display code calls this rather than testing emptiness itself, so the nudge reads the same
## everywhere it appears.
static func display(text: String) -> String:
	var trimmed: String = text.strip_edges()
	return trimmed if not trimmed.is_empty() else NO_DESCRIPTION_NUDGE


## THE JOIN: every describable thing this sheet declares, once, in a stable order. Each entry is
## {kind, name, text, described, detail}: `detail` is the extra line a reader wants beside the name
## (a function's signature, a variable's type, a group's trigger count) and is never part of the
## description itself.
##
## This is the ONE walk. The picker, the manual, the coverage footer, the Doctor page and the project
## view all read this array, so a thing counted in one place is counted the same way in the others.
static func catalog(sheet: EventSheetResource) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if sheet == null:
		return entries
	entries.append(_entry("sheet", _sheet_title(sheet), for_sheet(sheet), _sheet_detail(sheet)))
	var variable_names: PackedStringArray = PackedStringArray()
	for key: Variant in sheet.variables.keys():
		variable_names.append(str(key))
	# Dictionary key order follows insertion, which differs between a sheet built by the editor and
	# the same sheet lifted from a file, so the listing sorts rather than trusting it.
	variable_names.sort()
	for variable_name: String in variable_names:
		entries.append(_entry("variable", variable_name, for_variable(sheet, variable_name),
			_variable_detail(sheet, variable_name)))
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			var event_function: EventFunction = function_entry as EventFunction
			entries.append(_entry("function", event_function.function_name,
				for_function(event_function), signature_of(event_function)))
	var signal_rows: Array[Resource] = []
	var groups: Array[Resource] = []
	_collect_rows(sheet.events, signal_rows, groups)
	for signal_row: Resource in signal_rows:
		entries.append(_entry("signal", str(signal_row.get("signal_name")),
			for_signal(signal_row), _signal_detail(signal_row)))
	for group_entry: Resource in groups:
		var group: EventGroup = group_entry as EventGroup
		entries.append(_entry("group", group_name_of(group), for_group(group), _group_detail(group)))
	return entries


## How many of this sheet's things carry a description, and which ones do not - the numbers a manual
## page's footer states and the Doctor's page turns into one-click drafts. `undescribed` holds
## "kind:name" keys in catalog order, so the list reads top to bottom the way the page does.
static func coverage(sheet: EventSheetResource) -> Dictionary:
	var described: int = 0
	var undescribed: PackedStringArray = PackedStringArray()
	var entries: Array[Dictionary] = catalog(sheet)
	for entry: Dictionary in entries:
		if bool(entry.get("described", false)):
			described += 1
		else:
			undescribed.append("%s:%s" % [str(entry.get("kind", "")), str(entry.get("name", ""))])
	# `paragraphs` counts the sheet's DOCUMENTATION comment rows - the `##` lines that become the
	# manual's prose. Private `#` notes are deliberately absent from this number and from every other
	# number here: a note to yourself is not documentation somebody owes.
	return {
		"described": described,
		"total": entries.size(),
		"undescribed": undescribed,
		"paragraphs": EventSheetSheetProse.paragraph_count(sheet),
	}


## The one-line sentence a coverage footer states. Reads as a fact, never as a score to chase.
static func coverage_sentence(sheet: EventSheetResource) -> String:
	var numbers: Dictionary = coverage(sheet)
	return EventSheetL10n.translate("%d of %d described") % [int(numbers.get("described", 0)), int(numbers.get("total", 0))]


## A function's head as a reader writes it - "heal(amount: int) -> void" - built from the same
## parameter and return-type fields the emitter uses, so the manual and the file agree.
static func signature_of(event_function: EventFunction) -> String:
	if event_function == null:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for param_entry: Variant in event_function.params:
		if param_entry is ACEParam:
			var param: ACEParam = param_entry as ACEParam
			var param_id: String = param.id if not param.id.strip_edges().is_empty() else param.name
			var type_name: String = param.type_name.strip_edges()
			if type_name.is_empty():
				parts.append(param_id)
			else:
				parts.append("%s: %s" % [param_id, type_name])
	var head: String = "%s(%s)" % [event_function.function_name, ", ".join(parts)]
	if event_function.no_return_annotation:
		return head
	if not event_function.return_type_name.strip_edges().is_empty():
		return "%s -> %s" % [head, event_function.return_type_name.strip_edges()]
	return "%s -> %s" % [head, type_string(event_function.return_type) if event_function.return_type != TYPE_NIL else "void"]


## A group's name through both the current field and the older alias, so a sheet saved by any version
## of this plugin lists its groups under the name it actually shows.
static func group_name_of(group: EventGroup) -> String:
	if group == null:
		return ""
	var name: String = group.name.strip_edges()
	return name if not name.is_empty() else group.group_name.strip_edges()


## One catalog entry, with `described` decided in exactly one place.
static func _entry(kind: String, name: String, text: String, detail: String) -> Dictionary:
	var trimmed: String = text.strip_edges()
	return {
		"kind": kind,
		"name": name,
		"text": trimmed,
		"described": not trimmed.is_empty(),
		"detail": detail,
	}


## The title the sheet's own head entry carries: its class name when it declares one, else the file
## it came from, else a plain word - never empty, because the entry is a row in a list.
static func _sheet_title(sheet: EventSheetResource) -> String:
	if not sheet.custom_class_name.strip_edges().is_empty():
		return sheet.custom_class_name.strip_edges()
	if not sheet.external_source_path.strip_edges().is_empty():
		return sheet.external_source_path.get_file().get_basename()
	return "Sheet"


## What kind of sheet this is, in the words the editor uses for it.
static func _sheet_detail(sheet: EventSheetResource) -> String:
	if sheet.autoload_mode:
		return EventSheetL10n.translate("Autoload sheet")
	if sheet.behavior_mode:
		return EventSheetL10n.translate("Behavior sheet")
	if sheet.test_mode:
		return EventSheetL10n.translate("Test sheet")
	if not sheet.custom_class_name.strip_edges().is_empty():
		return EventSheetL10n.translate("Node type %s, extending %s") % [sheet.custom_class_name.strip_edges(), sheet.host_class]
	return EventSheetL10n.translate("Sheet on %s") % sheet.host_class


## A variable's type word plus whether it is exported, which is what a reader of the manual wants
## beside the name.
static func _variable_detail(sheet: EventSheetResource, variable_name: String) -> String:
	var descriptor: Variant = sheet.variables.get(variable_name)
	if not descriptor is Dictionary:
		return ""
	var entry: Dictionary = descriptor as Dictionary
	var type_name: String = str(entry.get("type", ""))
	if type_name.strip_edges().is_empty():
		type_name = "Variant"
	if bool(entry.get("const", false)):
		return EventSheetL10n.translate("%s constant") % type_name
	return EventSheetL10n.translate("%s, exported") % type_name if bool(entry.get("exported", true)) else type_name


## A signal's declared arguments, as the emitted `signal` line spells them.
static func _signal_detail(signal_row: Resource) -> String:
	var arguments: PackedStringArray = PackedStringArray()
	if "params" in signal_row:
		arguments = signal_row.get("params") as PackedStringArray
	return "signal %s(%s)" % [str(signal_row.get("signal_name")), ", ".join(arguments)]


## How much a group holds, as a count of its immediate rows - the roll-up a chapter heading wants.
static func _group_detail(group: EventGroup) -> String:
	var rows: Array = group.events if not group.events.is_empty() else group.rows
	return EventSheetL10n.translate("1 event") if rows.size() == 1 else EventSheetL10n.translate("%d events") % rows.size()


## The recursive walk that finds every declared signal and every group, at any depth, in sheet order.
static func _collect_rows(rows: Array, signal_rows: Array[Resource], groups: Array[Resource]) -> void:
	for entry: Variant in rows:
		if entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			groups.append(group)
			_collect_rows(group.events if not group.events.is_empty() else group.rows, signal_rows, groups)
		elif entry is SignalRow:
			signal_rows.append(entry as SignalRow)
		elif entry is EventRow:
			_collect_rows((entry as EventRow).sub_events, signal_rows, groups)


## Prose out of a stored `##` block: the prefixes are already off in the store, so this only collapses
## the block to one readable line and trims it. Multi-line descriptions stay legal in the file; a list
## row simply has one line to show.
static func _flatten(text: String) -> String:
	var joined: String = text.replace("\r\n", "\n").replace("\n", " ")
	while joined.contains("  "):
		joined = joined.replace("  ", " ")
	return joined.strip_edges()
