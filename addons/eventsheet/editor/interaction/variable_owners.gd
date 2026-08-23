# Godot EventSheets - WHO OWNS A VARIABLE, and the one list every surface reads it from.
#
# A variable row already says its sentence (EventSheetVariableSentence). What that sentence does not
# say is whose variable it is, and an event sheet answers that in the OBJECT column: an instance
# variable belongs to the sheet's own object (Player), a global belongs to the autoload it lives in
# (Game), and a local belongs to nobody in particular, which the sheet has always spelled System.
#
# Five surfaces used to work that out for themselves - the row builder's object column, the picker's
# Variables group, the Anatomy rail, the expression picker and the Doctor's "no such variable" note.
# They now all ask here, so the picker cannot offer a verb for a variable the row would file under a
# different owner, and a note cannot name an object the row does not.
#
# PURE + STATIC. Nothing here reads a viewport, a dock or a canvas; it takes a sheet and returns
# words and dictionaries. The catalog is deliberately re-derived per call: it is asked once per
# gesture (open a picker, build a note), never per row.
@tool
class_name EventSheetVariableOwners
extends RefCounted

## The owner a local variable reads with - nobody's property, so the sheet's own word for "the
## machinery itself". Frozen: rows, the picker and the notes all address this group by it.
const OWNER_SYSTEM: String = "System"

## The group ids the catalog buckets into. Frozen for the same reason the scope keys are.
const GROUP_INSTANCE: String = "instance"
const GROUP_GLOBAL: String = "global"
const GROUP_LOCAL: String = "local"

## The order a reader meets the groups in: this object first (the one they are editing), then the
## globals it reaches for, then the locals in view. The same order the expression picker, the
## Anatomy rail and the picker's Variables section list them in.
const GROUP_ORDER: PackedStringArray = [GROUP_INSTANCE, GROUP_GLOBAL, GROUP_LOCAL]


## Every variable this sheet can name, as one flat list in reading order:
## [{"name", "type_name", "type_word", "value", "scope", "owner", "group", "inspector",
##   "description", "insert_text", "autoload"}].
##
## `name` is the bare name a row shows; `insert_text` is what a parameter field must actually
## receive - bare for an instance variable or a local, `Game.Score` for a global, because inside an
## expression the prefix is real code and cannot be dropped.
static func catalog(sheet: EventSheetResource) -> Array[Dictionary]:
	var entries: Array[Dictionary] = own_entries(sheet)
	entries.append_array(global_entries(sheet))
	entries.append_array(local_entries(sheet))
	return entries


## Only the variables the sheet DECLARES - its own object's. Split out because the row builder asks
## once per sweep and only ever needs these: a qualified `Game.Score` already carries its owner in
## the name, and a local already reads as System, so scanning every autoload's script to answer a
## row's object column would be work with no answer in it.
static func own_entries(sheet: EventSheetResource) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if sheet == null:
		return entries
	var self_object: String = owner_of_sheet(sheet)
	var seen: Dictionary = {}
	for row: Dictionary in EventSheetInstanceVariableTable.rows_for(sheet):
		var name_text: String = str(row.get("name", "")).strip_edges()
		if name_text.is_empty() or seen.has(name_text):
			continue
		seen[name_text] = true
		entries.append({
			"name": name_text,
			"type_name": str(row.get("type_name", "")),
			"type_word": str(row.get("type_word", "")),
			"value": str(row.get("value", "")),
			"scope": str(row.get("scope", EventSheetVariableSentence.SCOPE_INSTANCE)),
			"owner": self_object,
			"group": GROUP_INSTANCE,
			"inspector": bool(row.get("inspector", false)),
			"description": str(row.get("description", "")),
			"insert_text": name_text,
			"resource": row.get("resource", null),
			"autoload": ""
		})
	# A tree variable declared INSIDE a group or a sub-event is still a member of the object - the
	# table only lists the top-level ones because that is where an author puts them, but an opened
	# pack can put a knob anywhere, and a knob the catalog cannot see is one the picker cannot offer.
	var resource_host: bool = EventSheetVariableSentence.is_resource_host(str(sheet.host_class))
	var autoload: bool = not str(sheet.get("autoload_name")).strip_edges().is_empty()
	var nested: Array = []
	EventSheetSelfExpressions.collect_tree_variables_into(sheet.events, nested)
	for entry: Variant in nested:
		if not (entry is LocalVariable):
			continue
		var descriptor: LocalVariable = entry as LocalVariable
		var nested_name: String = descriptor.name.strip_edges()
		if nested_name.is_empty() or seen.has(nested_name):
			continue
		seen[nested_name] = true
		var attributes: Dictionary = descriptor.attributes if descriptor.attributes is Dictionary else {}
		entries.append({
			"name": nested_name,
			"type_name": descriptor.type_name,
			"type_word": ViewportRowBuilder.friendly_type_word(descriptor.type_name),
			"value": VariableDialog._default_display_text(descriptor.default_value),
			"scope": EventSheetVariableSentence.member_scope(
				descriptor.is_constant, descriptor.is_static, autoload, resource_host),
			"owner": self_object,
			"group": GROUP_INSTANCE,
			"inspector": descriptor.exported,
			"description": str(attributes.get("tooltip", descriptor.description)),
			"insert_text": nested_name,
			"resource": descriptor,
			"autoload": ""
		})
	return entries


## The globals this sheet reads or writes, one entry each. The declared type and value come from the
## autoload's own script when it says so, because that file is the declaration and this sheet is only
## a reader of it.
static func global_entries(sheet: EventSheetResource) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if sheet == null:
		return entries
	var declared_by_path: Dictionary = {}
	var paths: Dictionary = {}
	for autoload_entry: Dictionary in EventSheetGlobalVariables.autoload_sheets():
		paths[str(autoload_entry.get("name", ""))] = str(autoload_entry.get("path", ""))
	for used: Dictionary in EventSheetGlobalVariables.used_here(sheet):
		var autoload_name: String = str(used.get("autoload", ""))
		var name_text: String = str(used.get("name", ""))
		if autoload_name.is_empty() or name_text.is_empty():
			continue
		var path: String = str(paths.get(autoload_name, ""))
		if not declared_by_path.has(path):
			declared_by_path[path] = EventSheetGlobalVariables.declared_globals(path)
		var type_name: String = ""
		var value_text: String = ""
		for declaration: Dictionary in (declared_by_path[path] as Array):
			if str(declaration.get("name", "")) != name_text:
				continue
			type_name = str(declaration.get("type", ""))
			value_text = str(declaration.get("value", ""))
			break
		entries.append({
			"name": name_text,
			"type_name": type_name,
			"type_word": ViewportRowBuilder.friendly_type_word(type_name),
			"value": value_text,
			"scope": EventSheetVariableSentence.SCOPE_GLOBAL,
			"owner": autoload_name,
			"group": GROUP_GLOBAL,
			"inspector": false,
			"description": "",
			"insert_text": "%s.%s" % [autoload_name, name_text],
			"resource": null,
			"autoload": autoload_name
		})
	return entries


## The locals this sheet declares anywhere - event locals, group locals and function locals. Owned by
## System, because a local belongs to the event it sits in and to nothing a reader can select.
static func local_entries(sheet: EventSheetResource) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if sheet == null:
		return entries
	var seen: Dictionary = {}
	for descriptor: LocalVariable in _declared_locals(sheet):
		var name_text: String = descriptor.name.strip_edges()
		if name_text.is_empty() or seen.has(name_text):
			continue
		seen[name_text] = true
		entries.append({
			"name": name_text,
			"type_name": descriptor.type_name,
			"type_word": ViewportRowBuilder.friendly_type_word(descriptor.type_name),
			"value": VariableDialog._default_display_text(descriptor.default_value),
			"scope": EventSheetVariableSentence.SCOPE_LOCAL,
			"owner": OWNER_SYSTEM,
			"group": GROUP_LOCAL,
			"inspector": false,
			"description": descriptor.description,
			"insert_text": name_text,
			"resource": descriptor,
			"autoload": ""
		})
	return entries


## The object a sheet's OWN variables belong to: the class it declares, else the file it is, and
## System when the sheet is not anything yet. An autoload answers with its singleton name - the name
## every other sheet reaches it by, which is what a reader looking at `Game.Score` expects to see.
static func owner_of_sheet(sheet: EventSheetResource) -> String:
	if sheet == null:
		return OWNER_SYSTEM
	var autoload_name: String = str(sheet.get("autoload_name")).strip_edges()
	if not autoload_name.is_empty():
		return autoload_name
	return EventSheetArrangement.self_object_of(sheet)


## The catalog entry for one name, or {} when this sheet names no such variable. The bare name and
## the qualified spelling both find the global they mean, because a row can carry either.
static func find(entries: Array[Dictionary], name_text: String) -> Dictionary:
	var wanted: String = name_text.strip_edges()
	if wanted.is_empty():
		return {}
	for entry: Dictionary in entries:
		if str(entry.get("name", "")) == wanted or str(entry.get("insert_text", "")) == wanted:
			return entry
	return {}


## The object column a row carrying this variable reads with, or "" when the sheet names no such
## variable and the ordinary provider reading should stand.
static func owner_for(entries: Array[Dictionary], name_text: String) -> String:
	return str(find(entries, name_text).get("owner", ""))


## The catalog bucketed for a list that shows one heading per owner:
## [{"id", "owner", "title", "entries"}], empty groups dropped. The title is what a heading says out
## loud - "Player - instance variables", "Game - globals", "Locals in scope".
static func groups(sheet: EventSheetResource) -> Array[Dictionary]:
	return group_entries(catalog(sheet))


## The same bucketing over a catalog already in hand, so a caller that filtered one does not have to
## re-derive it.
static func group_entries(entries: Array[Dictionary]) -> Array[Dictionary]:
	var grouped: Array[Dictionary] = []
	var by_key: Dictionary = {}
	for entry: Dictionary in entries:
		var owner: String = str(entry.get("owner", OWNER_SYSTEM))
		var group_id: String = str(entry.get("group", GROUP_INSTANCE))
		var key: String = "%s|%s" % [group_id, owner]
		if not by_key.has(key):
			var bucket: Dictionary = {
				"id": group_id, "owner": owner, "title": group_title(group_id, owner), "entries": []
			}
			by_key[key] = bucket
			grouped.append(bucket)
		((by_key[key] as Dictionary)["entries"] as Array).append(entry)
	grouped.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_rank: int = GROUP_ORDER.find(str(left.get("id", "")))
		var right_rank: int = GROUP_ORDER.find(str(right.get("id", "")))
		return left_rank < right_rank)
	return grouped


## The heading one owner's group wears.
static func group_title(group_id: String, owner: String) -> String:
	match group_id:
		GROUP_GLOBAL:
			return EventSheetL10n.translate("%s - globals") % owner
		GROUP_LOCAL:
			return EventSheetL10n.translate("Locals in scope")
	return EventSheetL10n.translate("%s - instance variables") % owner


## One catalog entry as the sentence its ROW reads with, minus the owner: "whole number hp = 100".
## Composed through the same chip the rows use, so a footer and the row it describes can never
## disagree about how a variable is spelled.
static func sentence(entry: Dictionary) -> String:
	if entry.is_empty():
		return ""
	var chip: String = EventSheetVariableSentence.chip_text(
		str(entry.get("scope", "")), str(entry.get("type_word", "")))
	var text: String = "%s %s" % [chip, str(entry.get("name", ""))] if not chip.is_empty() \
		else str(entry.get("name", ""))
	var value_text: String = str(entry.get("value", "")).strip_edges()
	if not value_text.is_empty():
		text += " = %s" % value_text
	var description: String = str(entry.get("description", "")).strip_edges()
	if not description.is_empty():
		text += "   %s" % description
	return text


## True when a variable of this type can go where a parameter of `wanted_type` is asked for. An
## unsettled want takes anything, which is the honest answer: most parameters are plain expressions
## and never claimed to want a kind.
static func fits(entry: Dictionary, wanted_type: String) -> bool:
	var wanted: String = wanted_type.strip_edges()
	if wanted.is_empty() or wanted == "Variant":
		return true
	var have: String = str(entry.get("type_name", "")).strip_edges()
	if have.is_empty() or have == "Variant":
		return true
	if have == wanted:
		return true
	# A number is a number: an `int` goes where a `float` is asked for and back, which is what
	# GDScript does too. Everything else has to match by name.
	var numbers: PackedStringArray = PackedStringArray(["int", "float"])
	return numbers.has(have) and numbers.has(wanted)


## The reason a name cannot be used, as the note the sheet shows under the row: "" when the name IS a
## variable of this sheet. The nearest spelled name rides in `suggestion` so the fix button can offer
## it - a typo is the usual cause, and the fix is one click when the sheet can guess.
static func unknown_note(entries: Array[Dictionary], name_text: String, owner: String) -> Dictionary:
	var wanted: String = name_text.strip_edges()
	if wanted.is_empty() or not find(entries, wanted).is_empty():
		return {}
	var suggestion: String = nearest_name(entries, wanted)
	var note: String = EventSheetL10n.translate("%s is not a variable of %s.") % [wanted, owner]
	if not suggestion.is_empty():
		note += " " + EventSheetL10n.translate("Did you mean %s?") % suggestion
	return {"name": wanted, "note": note, "suggestion": suggestion}


## The catalog name closest to a misspelling, or "" when nothing is close enough to offer. Similarity
## is Godot's own string metric, and the floor is deliberately high: a wrong guess in a fix button
## costs more than no guess at all.
static func nearest_name(entries: Array[Dictionary], name_text: String) -> String:
	var best: String = ""
	var best_score: float = 0.6
	for entry: Dictionary in entries:
		var candidate: String = str(entry.get("name", ""))
		var score: float = candidate.similarity(name_text)
		if score > best_score:
			best_score = score
			best = candidate
	return best


## V7. The Variables group in the order a reader looks for it: set it, change it by an amount, then
## the boolean pair, then the two questions. Ordered by what the verbs DO, not by id - which is the
## order they were in, and the reason "Toggle boolean" sat between "Subtract from" and the compare.
## Any variable verb not named here keeps its place after these, in registry order.
const VARIABLE_VERB_ORDER: PackedStringArray = [
	"SetVar", "AddVar", "SubtractVar", "SetBool", "ToggleVar", "CompareVar", "IsBoolSet"
]

## What kind of variable a verb can take: "" for any, "number" for the arithmetic ones, "boolean" for
## the flag ones. A table rather than a rule, because it is a fact about the seven verbs and not
## something their templates say.
const VARIABLE_VERB_TAKES: Dictionary = {
	"AddVar": "number", "SubtractVar": "number", "MultiplyVar": "number",
	"DivideVar": "number", "ModuloVar": "number",
	"SetBool": "boolean", "ToggleVar": "boolean", "IsBoolSet": "boolean"
}


## The rank a variable verb sorts at, or a number past every named one for a verb the table does not
## name - so an unnamed verb keeps its registry order behind the seven.
static func verb_rank(ace_id: String) -> int:
	var found: int = VARIABLE_VERB_ORDER.find(ace_id)
	return found if found >= 0 else VARIABLE_VERB_ORDER.size()


## The variables one verb can actually take, out of a catalog. "Add to" with no numbers in scope
## comes back empty, which is what lets the picker say so before the row is dropped.
static func variables_for_verb(entries: Array[Dictionary], ace_id: String) -> Array[Dictionary]:
	var takes: String = str(VARIABLE_VERB_TAKES.get(ace_id, ""))
	var offered: Array[Dictionary] = []
	for entry: Dictionary in entries:
		if takes.is_empty() or _type_word_family(str(entry.get("type_word", ""))) == takes:
			offered.append(entry)
	return offered


## The names one verb can take, as the picker writes them beside it: "hp, speed", or "" when the
## sheet has none of that kind.
static func verb_variable_note(entries: Array[Dictionary], ace_id: String) -> String:
	var names: PackedStringArray = PackedStringArray()
	for entry: Dictionary in variables_for_verb(entries, ace_id):
		names.append(str(entry.get("name", "")))
	return ", ".join(names)


## The family a type word belongs to for the verb table: both number words are numbers, and only the
## boolean word is a boolean. Everything else answers with itself, which no verb asks for.
static func _type_word_family(type_word: String) -> String:
	var word: String = type_word.strip_edges()
	if word == EventSheetL10n.translate("number") or word == EventSheetL10n.translate("whole number"):
		return "number"
	if word == EventSheetL10n.translate("boolean"):
		return "boolean"
	return word


## Every LocalVariable this sheet declares, wherever it sits.
static func _declared_locals(sheet: EventSheetResource) -> Array[LocalVariable]:
	var found: Array[LocalVariable] = []
	_collect_locals(sheet.events, found)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			_collect_locals((function_entry as EventFunction).events, found)
	return found


static func _collect_locals(rows: Array, into: Array[LocalVariable]) -> void:
	for entry: Variant in rows:
		if entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			for local_entry: Variant in group.local_variables:
				if local_entry is LocalVariable:
					into.append(local_entry as LocalVariable)
			_collect_locals(EventSheetGroupFacts.children(group), into)
		elif entry is EventRow:
			var event_row: EventRow = entry as EventRow
			for local_entry: Variant in event_row.local_variables:
				if local_entry is LocalVariable:
					into.append(local_entry as LocalVariable)
			_collect_locals(event_row.sub_events, into)
