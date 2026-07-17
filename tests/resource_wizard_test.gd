# EventForge - the Custom Resource wizard + EventSheets.resource_grid (the approved
# editor-tools spec, slice 2). resource_grid is the ONE owner of the Inspector-grid
# column-hint syntax: plain phrases become typed/dropdown columns, options become
# tooltip/group/required attributes, and formed dictionaries pass through untouched.
# The wizard's pure builder turns three beginner answers into a Resource-host sheet
# whose grid uses exactly that payload - and the result compiles and ROUND-TRIPS
# (the drawer machinery's byte gate), so the wizard can never emit a sheet that
# corrupts on reopen.
@tool
class_name ResourceWizardTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ---- resource_grid: phrase parsing ----
	var descriptor: Dictionary = EventSheets.resource_grid(
		["name", "kind: coin|gem|key", "weight: float", "count: int", "hidden: bool"],
		{"tooltip": "One drop per row.", "group": "Loot", "required": true})
	ok = _check(ok, str(descriptor.get("type")) == "Array" and bool(descriptor.get("exported")), "grid is an exported Array")
	var attributes: Dictionary = descriptor.get("attributes", {})
	ok = _check(ok, str(attributes.get("drawer")) == "table", "grid ships the table drawer")
	var columns: Array = attributes.get("table_columns", [])
	ok = _check(ok, columns.size() == 5, "five columns parsed (got %d)" % columns.size())
	ok = _check(ok, columns[0] == {"name": "name", "type": "String"}, "plain word -> String column (got %s)" % str(columns[0]))
	ok = _check(ok, columns[1] == {"name": "kind", "type": "enum(coin|gem|key)"}, "choices -> enum dropdown (got %s)" % str(columns[1]))
	ok = _check(ok, columns[2] == {"name": "weight", "type": "float"}, "typed column passes (got %s)" % str(columns[2]))
	ok = _check(ok, columns[3] == {"name": "count", "type": "int"}, "int column passes")
	ok = _check(ok, columns[4] == {"name": "hidden", "type": "bool"}, "bool column passes")
	ok = _check(ok, str(attributes.get("tooltip")) == "One drop per row." and str(attributes.get("group")) == "Loot" and bool(attributes.get("required")), "tooltip/group/required options land")

	# Spaced choices are forgiven; a formed dictionary passes through untouched.
	var forgiving: Dictionary = EventSheets.resource_grid(["op: == | != | <", {"name": "custom", "type": "enum(a|b)"}])
	var forgiving_columns: Array = (forgiving.get("attributes", {}) as Dictionary).get("table_columns", [])
	ok = _check(ok, forgiving_columns[0] == {"name": "op", "type": "enum(==|!=|<)"}, "spaces around | are stripped (got %s)" % str(forgiving_columns[0]))
	ok = _check(ok, forgiving_columns[1] == {"name": "custom", "type": "enum(a|b)"}, "a formed column dictionary passes through")
	var bare: Dictionary = EventSheets.resource_grid(["notes"])
	ok = _check(ok, not (bare.get("attributes", {}) as Dictionary).has("required"), "no options -> no stray attributes")

	# ---- the wizard's pure builder ----
	var sheet: EventSheetResource = EventSheetNewResourceWizard.build_wizard_sheet(
		"", "Loot Drop", ["name", "kind: coin|gem|key", "weight: float"], true)
	ok = _check(ok, sheet.host_class == "Resource", "wizard sheet is Resource-hosted")
	ok = _check(ok, sheet.custom_class_name == "LootDropTable", "class name derives from the entry (got %s)" % sheet.custom_class_name)
	ok = _check(ok, sheet.variables.has("loot_drops"), "grid name pluralizes the entry (got %s)" % str(sheet.variables.keys()))
	var grid: Dictionary = sheet.variables.get("loot_drops", {})
	ok = _check(ok, str((grid.get("attributes", {}) as Dictionary).get("drawer")) == "table", "the wizard grid went through resource_grid")
	ok = _check(ok, bool((grid.get("attributes", {}) as Dictionary).get("required")), "the required answer lands on the grid")
	ok = _check(ok, not sheet.class_description.is_empty(), "the sheet describes itself")

	# An explicit resource name wins; messy input still yields a valid identifier.
	ok = _check(ok, EventSheetNewResourceWizard.class_name_for("wave plan", "x") == "WavePlan", "explicit name pascalizes")
	ok = _check(ok, EventSheetNewResourceWizard.class_name_for("", "Boss!") == "BossTable", "punctuation is stripped")
	ok = _check(ok, EventSheetNewResourceWizard.grid_name_for("Dialogue Lines") == "dialogue_lines", "an already-plural entry is not double-pluralized")

	# ---- attach_validator: the validate function + attribute wiring, in one call ----
	var validator_name: String = EventSheets.attach_validator(sheet, "loot_drops")
	ok = _check(ok, validator_name == "validate_loot_drops", "the validator function is named for the grid (got %s)" % validator_name)
	var validator_found: EventFunction = null
	for candidate: Resource in sheet.functions:
		if candidate is EventFunction and (candidate as EventFunction).function_name == validator_name:
			validator_found = candidate as EventFunction
	ok = _check(ok, validator_found != null and validator_found.return_type == TYPE_STRING, "a String-returning validator function was created")
	var grid_attributes: Dictionary = (sheet.variables.get("loot_drops", {}) as Dictionary).get("attributes", {})
	ok = _check(ok, str(grid_attributes.get("validate", "")) == validator_name, "the grid's validate attribute points at it")
	var function_count: int = sheet.functions.size()
	EventSheets.attach_validator(sheet, "loot_drops")
	ok = _check(ok, sheet.functions.size() == function_count, "re-attaching reuses the function (no duplicate)")
	ok = _check(ok, EventSheets.attach_validator(sheet, "no_such_variable") == "", "an unknown variable attaches nothing")

	# ---- the covenant: the wizard's output compiles and round-trips byte-exactly ----
	var compiled: Dictionary = SheetCompiler.compile(sheet, "user://wizard_roundtrip.gd")
	ok = _check(ok, bool(compiled.get("success", false)), "the wizard sheet compiles")
	var source: String = str(compiled.get("output", ""))
	ok = _check(ok, source.contains("class_name LootDropTable") and source.contains("extends Resource"), "output is a named Resource script")
	ok = _check(ok, source.contains("# @inspector_validate validate_loot_drops"), "output carries the validate decor")
	ok = _check(ok, source.contains("func validate_loot_drops() -> String:"), "output ships the validator function")
	ok = _check(ok, EventSheets.round_trips(source), "the wizard sheet round-trips byte-exactly")
	if FileAccess.file_exists("user://wizard_roundtrip.gd"):
		DirAccess.remove_absolute("user://wizard_roundtrip.gd")

	return ok


static func _check(ok: bool, condition: bool, label: String) -> bool:
	if not condition:
		print("  [FAIL] ", label)
	return ok and condition
