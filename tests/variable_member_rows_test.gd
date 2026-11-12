# Godot EventSheets - the member rows a sheet declares, as the variable owners read them.
#
# Pins the VALUES: one row per variable, the type word, the initial value in the spelling the Add
# variable dialog writes back, and whether it wears the Inspector tick.
@tool
class_name VariableMemberRowsTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	sheet.events.append(_variable("speed", "float", 200.0, true, "how fast it walks"))
	sheet.events.append(_variable("lives", "int", 3, true, ""))
	sheet.events.append(_variable("alive", "bool", true, false, ""))
	sheet.events.append(_variable("tint", "Color", Color(1, 0, 0), false, ""))
	var rows: Array[Dictionary] = EventSheetVariableOwners.member_rows(sheet)

	ok = _check("the table lists every variable the object carries, in file order",
		_names(rows), "speed, lives, alive, tint") and ok
	ok = _check("a float reads number, and the value is the one the dialog writes back",
		[str(rows[0].get("type_word", "")), str(rows[0].get("value", "")), bool(rows[0].get("inspector", false))],
		["number", "200.0", true]) and ok
	ok = _check("a declared int is a whole number",
		[str(rows[1].get("type_word", "")), str(rows[1].get("value", ""))], ["whole number", "3"]) and ok
	ok = _check("a variable with no Inspector tick does not claim one",
		[str(rows[2].get("type_word", "")), bool(rows[2].get("inspector", true))], ["boolean", false]) and ok
	ok = _check("a colour keeps its literal spelling in the value column",
		[str(rows[3].get("type_word", "")), str(rows[3].get("value", ""))], ["color", "Color(1.0, 0.0, 0.0, 1.0)"]) and ok
	ok = _check("the description column carries what the author wrote",
		str(rows[0].get("description", "")), "how fast it walks") and ok
	ok = _check("a member of a plain node is an Instance variable",
		str(rows[0].get("scope", "")), EventSheetVariableSentence.SCOPE_INSTANCE) and ok

	# The value the table shows must be the value the write path reads back - the pair is what makes
	# retyping and revaluing from the table land the same line the dialog would have written.
	ok = _check("the shown value parses back to the value it came from",
		VariableDialog._parse_default("float",
			str(rows[0].get("value", ""))), 200.0) and ok

	# ── A Resource script's members are Fields, an autoload's are Globals ──
	var data_sheet: EventSheetResource = EventSheetResource.new()
	data_sheet.host_class = "Resource"
	data_sheet.events.append(_variable("price", "float", 0.0, true, ""))
	ok = _check("a Resource script's member is a Field",
		str(EventSheetVariableOwners.member_rows(data_sheet)[0].get("scope", "")),
		EventSheetVariableSentence.SCOPE_FIELD) and ok
	var constant_sheet: EventSheetResource = EventSheetResource.new()
	constant_sheet.host_class = "Node"
	var maximum: LocalVariable = _variable("MAX_HP", "int", 100, false, "")
	maximum.is_constant = true
	constant_sheet.events.append(maximum)
	ok = _check("a const member is a Constant",
		str(EventSheetVariableOwners.member_rows(constant_sheet)[0].get("scope", "")),
		EventSheetVariableSentence.SCOPE_CONSTANT) and ok

	# ── Sheet-scope variables are members too, and they sort by name after the placed ones ──
	var mixed: EventSheetResource = EventSheetResource.new()
	mixed.host_class = "Node"
	mixed.events.append(_variable("hp", "int", 100, false, ""))
	mixed.variables["score"] = {"type": "int", "default": 0, "exported": false}
	ok = _check("a sheet-scope variable is in the table too",
		_names(EventSheetVariableOwners.member_rows(mixed)), "hp, score") and ok

	# ── Empty sheets answer with nothing rather than with a broken table ──
	ok = _check("a sheet with no variables lists none",
		EventSheetVariableOwners.member_rows(EventSheetResource.new()).size(), 0) and ok
	ok = _check("and neither does a missing sheet",
		EventSheetVariableOwners.member_rows(null).size(), 0) and ok

	return ok


static func _variable(variable_name: String, type_name: String, value: Variant,
		exported: bool, description: String) -> LocalVariable:
	var variable: LocalVariable = LocalVariable.new()
	variable.name = variable_name
	variable.type_name = type_name
	variable.default_value = value
	variable.exported = exported
	if not description.is_empty():
		variable.attributes = {"tooltip": description}
	return variable


static func _names(rows: Array[Dictionary]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for row: Dictionary in rows:
		parts.append(str(row.get("name", "")))
	return ", ".join(parts)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("variable_member_rows_test", label, actual, expected)
