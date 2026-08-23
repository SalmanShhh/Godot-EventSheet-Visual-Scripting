# EventForge - V6/V7/V9/V10/V11/V12: who owns a variable, and every surface that now asks.
#
# Pins: the catalog's three owner groups (this object's variables, an autoload's globals, the locals
# in scope) and the insert spelling each carries; the row builder leading a variable row's object
# column with that owner instead of System; the two new boolean verbs (Core/SetBool, Core/IsBoolSet)
# and their exclusion from the reverse index; the picker's familiar Variables order plus the
# variables each verb can take; the Anatomy rail's scope sections; the expression picker's per-owner
# leaves and its type-fit greying; the Inspector plugin's variable census and its "not in the
# Inspector" note; and the two notes an event grows when a row names a variable that is not there or
# is the wrong kind.
@tool
class_name VariableOwnersTest
extends RefCounted

const EXPRESSION_PICKER := preload("res://addons/eventsheet/editor/ace_params_expression_picker.gd")
const INSPECTOR_PLUGIN := preload("res://addons/eventforge/editor/sheet_edit_inspector_plugin.gd")


static func run() -> bool:
	var ok: bool = true
	ok = _test_catalog() and ok
	ok = _test_new_boolean_verbs() and ok
	ok = _test_picker_order_and_notes() and ok
	ok = _test_anatomy_sections() and ok
	ok = _test_expression_picker_leaves() and ok
	ok = _test_inspector_census() and ok
	ok = _test_row_owner_and_notes() and ok
	return ok


static func _sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Player"
	sheet.host_class = "Node2D"
	sheet.variables = {
		"hp": {"type": "int", "default": 100, "exported": false},
		"nickname": {"type": "String", "default": "Ana", "exported": true},
	}
	var speed: LocalVariable = LocalVariable.new()
	speed.name = "speed"
	speed.type_name = "float"
	speed.default_value = 200.0
	speed.exported = true
	sheet.events.append(speed)
	return sheet


# ── The catalog ──


static func _test_catalog() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = _sheet()
	var event: EventRow = EventRow.new()
	event.event_uid = "e1"
	var dealt: LocalVariable = LocalVariable.new()
	dealt.name = "dealt"
	dealt.type_name = "float"
	dealt.default_value = 0.0
	event.local_variables.append(dealt)
	sheet.events.append(event)

	var entries: Array[Dictionary] = EventSheetVariableOwners.catalog(sheet)
	ok = _check("the sheet's own object owns its variables",
		EventSheetVariableOwners.owner_for(entries, "hp"), "Player") and ok
	ok = _check("a local belongs to System",
		EventSheetVariableOwners.owner_for(entries, "dealt"), "System") and ok
	ok = _check("a name the sheet never declares has no owner",
		EventSheetVariableOwners.owner_for(entries, "hpp"), "") and ok
	ok = _check("a tree variable is in the catalog too",
		EventSheetVariableOwners.owner_for(entries, "speed"), "Player") and ok
	ok = _check("an instance variable inserts its bare name",
		str(EventSheetVariableOwners.find(entries, "hp").get("insert_text", "")), "hp") and ok
	ok = _check("the sentence is the row's, minus the owner",
		EventSheetVariableOwners.sentence(EventSheetVariableOwners.find(entries, "hp")),
		"Instance whole number hp = 100") and ok

	var groups: Array[Dictionary] = EventSheetVariableOwners.group_entries(entries)
	var titles: PackedStringArray = PackedStringArray()
	for group: Dictionary in groups:
		titles.append(str(group.get("title", "")))
	ok = _check("groups read by owner, this object first",
		titles, PackedStringArray(["Player - instance variables", "Locals in scope"])) and ok

	# The verb table: which variables each verb can actually take.
	ok = _check("Add to offers only the numbers",
		EventSheetVariableOwners.verb_variable_note(entries, "AddVar"), "speed, hp, dealt") and ok
	ok = _check("Set boolean offers nothing here",
		EventSheetVariableOwners.verb_variable_note(entries, "SetBool"), "") and ok
	ok = _check("Set value offers everything",
		EventSheetVariableOwners.verb_variable_note(entries, "SetVar"),
		"speed, hp, nickname, dealt") and ok
	ok = _check("the familiar order puts Set value first, the questions last",
		EventSheetVariableOwners.verb_rank("SetVar") < EventSheetVariableOwners.verb_rank("IsBoolSet"),
		true) and ok

	# Type fitting - what the expression picker greys and what the notes warn about.
	ok = _check("a whole number fits a float parameter",
		EventSheetVariableOwners.fits(EventSheetVariableOwners.find(entries, "hp"), "float"), true) and ok
	ok = _check("text does not fit a number parameter",
		EventSheetVariableOwners.fits(EventSheetVariableOwners.find(entries, "nickname"), "float"),
		false) and ok
	ok = _check("an unsettled parameter takes anything",
		EventSheetVariableOwners.fits(EventSheetVariableOwners.find(entries, "nickname"), ""), true) and ok

	var unknown: Dictionary = EventSheetVariableOwners.unknown_note(entries, "hpp", "Player")
	ok = _check("an unknown name says whose it is not",
		str(unknown.get("note", "")), "hpp is not a variable of Player. Did you mean hp?") and ok
	ok = _check("and offers the nearest name as the fix",
		str(unknown.get("suggestion", "")), "hp") and ok
	ok = _check("a name that IS a variable grows no note",
		EventSheetVariableOwners.unknown_note(entries, "hp", "Player").is_empty(), true) and ok
	return ok


# ── V7: the two new verbs ──


static func _test_new_boolean_verbs() -> bool:
	var ok: bool = true
	var set_bool: ACEDescriptor = ACERegistry.find_descriptor("Core", "SetBool")
	var is_set: ACEDescriptor = ACERegistry.find_descriptor("Core", "IsBoolSet")
	ok = _check("Core/SetBool is registered", set_bool != null, true) and ok
	ok = _check("Core/IsBoolSet is registered", is_set != null, true) and ok
	if set_bool == null or is_set == null:
		return false
	ok = _check("Set boolean writes a plain assignment",
		set_bool.codegen_template, "{var_name} = {value}") and ok
	ok = _check("Set boolean reads as the sentence",
		set_bool.get_display_text(), "Set boolean {var_name} to {value}") and ok
	ok = _check("Is boolean set IS the name", is_set.codegen_template, "{var_name}") and ok
	ok = _check("Is boolean set reads as a question", is_set.get_display_text(), "Is {var_name}") and ok
	ok = _check("both are filed under Variables",
		"%s/%s" % [set_bool.category, is_set.category], "Variables/Variables") and ok
	var options: PackedStringArray = PackedStringArray()
	for parameter: ACEParam in set_bool.params:
		for option: Variant in parameter.options:
			if option is Dictionary:
				options.append(str((option as Dictionary).get("key", "")))
	ok = _check("the value is picked, not typed", options, PackedStringArray(["true", "false"])) and ok
	ok = _check("neither speaks for a line the older rows already lift",
		EventSheetACELifter.REVERSE_LIFT_EXCLUDED_ACE_IDS.has("SetBool")
			and EventSheetACELifter.REVERSE_LIFT_EXCLUDED_ACE_IDS.has("IsBoolSet"), true) and ok
	return ok


# ── V7: the picker ──


static func _test_picker_order_and_notes() -> bool:
	var ok: bool = true
	var order: Array[ACEDefinition] = []
	for ace_id: String in ["IsBoolSet", "ToggleVar", "SetVar", "SubtractVar"]:
		var definition: ACEDefinition = ACEDefinition.new()
		definition.id = ace_id
		definition.category = ACEPickerDialog.VARIABLES_CATEGORY
		definition.display_name = ace_id
		order.append(definition)
	var reordered: PackedStringArray = PackedStringArray()
	for definition: ACEDefinition in ACEPickerDialog.ordered_variable_verbs(order):
		reordered.append(str(definition.id))
	ok = _check("the Variables group reads in the familiar order",
		reordered, PackedStringArray(["SetVar", "SubtractVar", "ToggleVar", "IsBoolSet"])) and ok

	var entries: Array[Dictionary] = EventSheetVariableOwners.catalog(_sheet())
	var add_to: ACEDefinition = ACEDefinition.new()
	add_to.id = "AddVar"
	add_to.category = ACEPickerDialog.VARIABLES_CATEGORY
	add_to.display_name = "Add to"
	ok = _check("a verb names the variables it can take",
		ACEPickerDialog.variable_verb_note(entries, add_to), "speed, hp") and ok
	var set_bool: ACEDefinition = ACEDefinition.new()
	set_bool.id = "SetBool"
	set_bool.category = ACEPickerDialog.VARIABLES_CATEGORY
	set_bool.display_name = "Set boolean"
	ok = _check("a verb with nothing to take says so",
		ACEPickerDialog.variable_verb_note(entries, set_bool), "nothing of that kind yet") and ok
	var elsewhere: ACEDefinition = ACEDefinition.new()
	elsewhere.id = "QueueFree"
	elsewhere.category = "General Actions"
	ok = _check("a verb outside the group says nothing",
		ACEPickerDialog.variable_verb_note(entries, elsewhere), "") and ok
	ok = _check("the footer reads each variable's own sentence",
		ACEPickerDialog.variable_sentences_footer(entries, add_to),
		"Player  Instance number speed = 200.0\nPlayer  Instance whole number hp = 100") and ok
	return ok


# ── V9: the Anatomy rail ──


static func _test_anatomy_sections() -> bool:
	var ok: bool = true
	var organs: Array = BehaviourAnatomyPanel.collect_anatomy(_sheet())
	var ids: PackedStringArray = PackedStringArray()
	var titles: Dictionary = {}
	var labels: Dictionary = {}
	for organ: Dictionary in organs:
		ids.append(str(organ.get("id", "")))
		titles[str(organ.get("id", ""))] = str(organ.get("title", ""))
		var entry_labels: PackedStringArray = PackedStringArray()
		for entry: Dictionary in (organ.get("entries", []) as Array):
			entry_labels.append(str(entry.get("label", "")))
		labels[str(organ.get("id", ""))] = entry_labels
	ok = _check("the variable organs are named by scope",
		PackedStringArray([ids[0], ids[1], ids[2]]),
		PackedStringArray(["instance", "global", "local"])) and ok
	ok = _check("the instance heading names the object",
		str(titles.get("instance", "")), "Instance, of Player") and ok
	ok = _check("an empty globals heading claims no source",
		str(titles.get("global", "")), "Globals used here") and ok
	ok = _check("each line is the row's sentence",
		labels.get("instance"), PackedStringArray([
			"Instance number speed = 200.0", "Instance whole number hp = 100",
			"Instance text nickname = Ana"])) and ok
	ok = _check("nine organ headers", ids.size(), 9) and ok
	ok = _check("the heading with no owner still says its scope",
		BehaviourAnatomyPanel.variable_organ_title("local", ""), "Locals in view") and ok
	return ok


# ── V11: the expression picker ──


static func _test_expression_picker_leaves() -> bool:
	var ok: bool = true
	var entries: Array[Dictionary] = EventSheetVariableOwners.catalog(_sheet())
	ok = _check("a leaf shows the type word and what it starts as",
		EventSheetVariableOwners.leaf_text(EventSheetVariableOwners.find(entries, "hp")),
		"hp   whole number = 100") and ok
	ok = _check("a designer knob says so",
		EventSheetVariableOwners.leaf_text(EventSheetVariableOwners.find(entries, "speed")),
		"speed   number = 200.0  · Inspector") and ok
	ok = _check("the footer says what will land in the field",
		EXPRESSION_PICKER.inserts_note("Game.Score"), "Inserts Game.Score") and ok
	ok = _check("nothing highlighted, nothing said", EXPRESSION_PICKER.inserts_note(""), "") and ok
	return ok


# ── V10: the Inspector's census ──


static func _test_inspector_census() -> bool:
	var ok: bool = true
	var path: String = "user://variable_owners_census.gd"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("extends Node2D\n\n@export var speed: float = 200.0\nvar hp: int = 100\n"
		+ "var alive: bool = true\n\n\nfunc _ready() -> void:\n\tvar dealt := 0\n\tprint(dealt)\n")
	file.close()
	var variables: Array[Dictionary] = INSPECTOR_PLUGIN.member_variables(path)
	var names: PackedStringArray = PackedStringArray()
	for entry: Dictionary in variables:
		names.append(str(entry.get("name", "")))
	ok = _check("the census reads the members, never the locals",
		names, PackedStringArray(["speed", "hp", "alive"])) and ok
	ok = _check("@export is what puts one in the Inspector",
		bool(variables[0].get("exported", false)), true) and ok
	ok = _check("and the plain ones are not",
		bool(variables[1].get("exported", true)), false) and ok
	ok = _check("the note names the ones that are missing and the way to add them",
		INSPECTOR_PLUGIN.hidden_variables_note(variables),
		"Not in the Inspector: hp, alive - open the table to expose one.") and ok
	var all_exported: Array[Dictionary] = [{"name": "speed", "exported": true}]
	ok = _check("nothing hidden, nothing said",
		INSPECTOR_PLUGIN.hidden_variables_note(all_exported), "") and ok
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# A hinted export carries SPACES inside its arguments - `@export_range(0, 100)` is the exact
	# spelling the compiler emits - so the annotation has to be taken off by its brackets, not cut
	# at the first space. Both spellings of it, on the line and above the line, are the same export.
	var hinted_path: String = "user://variable_owners_census_hinted.gd"
	var hinted: FileAccess = FileAccess.open(hinted_path, FileAccess.WRITE)
	hinted.store_string("extends Node2D

@export_range(0, 100) var speed: float = 200.0
"
		+ "@export_enum(\"Left\", \"Right\")
var facing: int = 0
"
		+ "@export_file(\"*.png\") var art: String = \"\"
"
		+ "@export_group(\"Combat\")
var hp: int = 100
")
	hinted.close()
	var hinted_census: Array[Dictionary] = INSPECTOR_PLUGIN.member_variables(hinted_path)
	var hinted_names: PackedStringArray = PackedStringArray()
	var hinted_flags: Array[bool] = []
	for entry: Dictionary in hinted_census:
		hinted_names.append(str(entry.get("name", "")))
		hinted_flags.append(bool(entry.get("exported", false)))
	ok = _check("a hinted export is still a variable the census counts",
		hinted_names, PackedStringArray(["speed", "facing", "art", "hp"])) and ok
	ok = _check("and every hinted spelling is read as exported",
		hinted_flags, [true, true, true, false]) and ok
	ok = _check("so the note only names the one that really is not down there",
		INSPECTOR_PLUGIN.hidden_variables_note(hinted_census),
		"Not in the Inspector: hp - open the table to expose one.") and ok
	DirAccess.remove_absolute(ProjectSettings.globalize_path(hinted_path))
	return ok


# ── V6 + V12: the row's object column, and the notes under an event ──


static func _test_row_owner_and_notes() -> bool:
	var ok: bool = true
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	var sheet: EventSheetResource = _sheet()
	var event: EventRow = EventRow.new()
	event.event_uid = "owned"
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var subtract: ACEAction = ACEAction.new()
	subtract.provider_id = "Core"
	subtract.ace_id = "SubtractVar"
	subtract.params = {"var_name": "hp", "amount": "10"}
	event.actions.append(subtract)
	sheet.events.append(event)
	var typo_event: EventRow = EventRow.new()
	typo_event.event_uid = "typo"
	typo_event.trigger_provider_id = "Core"
	typo_event.trigger_id = "OnProcess"
	var wrong: ACEAction = ACEAction.new()
	wrong.provider_id = "Core"
	wrong.ace_id = "SubtractVar"
	wrong.params = {"var_name": "hpp", "amount": "1"}
	typo_event.actions.append(wrong)
	var mismatched: ACEAction = ACEAction.new()
	mismatched.provider_id = "Core"
	mismatched.ace_id = "AddVar"
	mismatched.params = {"var_name": "nickname", "amount": "1"}
	typo_event.actions.append(mismatched)
	sheet.events.append(typo_event)
	dock.setup(sheet)

	var owned_row: EventRowData = _row_with_uid(dock, "owned")
	ok = _check("the event was built", owned_row != null, true) and ok
	if owned_row != null:
		dock._viewport._ensure_event_spans(owned_row)
		ok = _check("a step that changes hp leads with the object that HAS an hp",
			_object_label_of(owned_row), "Player") and ok

	var notes: Array = _note_rows(_row_with_uid(dock, "typo"))
	ok = _check("one note per problem", notes.size(), 2) and ok
	if notes.size() == 2:
		ok = _check("the unknown name is named, with the fix",
			_note_text(notes[0]),
			"hpp is not a variable of Player. Did you mean hp? Use hp") and ok
		ok = _check("the wrong kind says which verb fits",
			_note_text(notes[1]),
			"nickname is text - Add to wants a number. Set value fits.") and ok
		ok = _check("a note is inert - nothing can be deleted through it",
			(notes[0] as EventRowData).source_resource == null, true) and ok
	# The fix: one click renames every use of the misspelled name.
	dock._apply_variable_note_fix(notes[0] if not notes.is_empty() else null)
	ok = _check("the fix rewrote the row", str(wrong.params.get("var_name", "")), "hp") and ok

	# The mismatch note is a reading only - the sheet never moved.
	var mismatch: Dictionary = ViewportRowBuilder.variable_mismatch_note(
		EventSheetVariableOwners.find(EventSheetVariableOwners.catalog(sheet), "hp"), "AddVar")
	ok = _check("a number handed to Add to grows no note", mismatch.is_empty(), true) and ok
	dock.free()
	return ok


static func _row_with_uid(dock: EventSheetDock, uid: String) -> EventRowData:
	for row: EventRowData in dock._viewport._root_rows:
		if row.row_uid == uid:
			return row
	return null


static func _note_rows(event_row: EventRowData) -> Array:
	var notes: Array = []
	if event_row == null:
		return notes
	for child: EventRowData in event_row.children:
		if child.row_uid.begins_with("variable_note_"):
			notes.append(child)
	return notes


static func _note_text(row: EventRowData) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for span: SemanticSpan in (row as EventRowData).spans:
		var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
		if str(metadata.get("variable_note", "")) == "mark":
			continue
		parts.append(span.text)
	return " ".join(parts).strip_edges()


static func _object_label_of(row: EventRowData) -> String:
	for span: SemanticSpan in row.spans:
		var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
		var label: String = str(metadata.get("object_label", ""))
		if not label.is_empty():
			return label
	return ""


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] variable_owners_test: %s" % label)
		return true
	print("[FAIL] variable_owners_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
