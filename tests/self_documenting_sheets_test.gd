# Godot EventSheets - one description per thing, drafted from its own rows, and the manual that
# writes itself out of both.
#
# WHAT THIS PINS, and why each of these was worth a test:
#  - the description of a thing is read from the ONE field the file already carries for it, so a
#    reader and a writer can never end up looking at different text,
#  - an undescribed thing reads the same soft nudge everywhere rather than each list inventing a way
#    of saying nothing is here,
#  - a draft is composed from the rows themselves and is the SAME string every time, because an
#    export of these words goes into version control and a draft that varied would diff for nothing,
#  - a row nobody can read as a sentence composes to "runs its own code" and never to a guess,
#  - a description that no longer names anything its rows do is reported as drifted, while one that
#    was merely reworded is not,
#  - a manual page is composed, never stored, and states its coverage as a plain fact.
@tool
class_name SelfDocumentingSheetsTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var all_passed: bool = true

	# ── The one store: what is read is what the file carries ────────────────────────────────
	var sheet: EventSheetResource = _sheet()
	all_passed = _check("the sheet's own description is its class doc",
		EventSheetDescriptions.for_sheet(sheet), "The player's health and how it is spent.") and all_passed
	all_passed = _check("a variable's description is the line above its declaration",
		EventSheetDescriptions.for_variable(sheet, "hp"), "How much damage the player can still take.") and all_passed
	all_passed = _check("an undescribed variable answers with nothing at all",
		EventSheetDescriptions.for_variable(sheet, "max_hp"), "") and all_passed

	# A plain helper's description is its `##` doc comment; a PUBLISHED verb's is its picker blurb,
	# because the picker's words and the reader's words have to be one text.
	var heal: EventFunction = _function_named(sheet, "heal")
	all_passed = _check("a plain function's description is its doc comment",
		EventSheetDescriptions.for_function(heal), "Raises hp and lights the icon.") and all_passed
	var published: EventFunction = EventFunction.new()
	published.function_name = "spend"
	published.expose_as_ace = true
	published.description = "Spends a charge."
	all_passed = _check("a published verb's picker blurb IS its description",
		EventSheetDescriptions.for_function(published), "Spends a charge.") and all_passed
	all_passed = _check("a write for a published verb lands on the blurb, not a second field",
		EventSheetDescriptions.write_field_for_function(published), "description") and all_passed
	all_passed = _check("a write for a plain helper lands on the doc comment",
		EventSheetDescriptions.write_field_for_function(heal), "doc_comment") and all_passed

	# ── The nudge, one wording everywhere ───────────────────────────────────────────────────
	all_passed = _check("an undescribed thing shows the soft nudge",
		EventSheetDescriptions.display(""), "no description yet") and all_passed
	all_passed = _check("a described thing shows its own words",
		EventSheetDescriptions.display("  Spends a charge.  "), "Spends a charge.") and all_passed

	# ── The join: every describable thing, once, in a stable order ──────────────────────────
	var catalog: Array[Dictionary] = EventSheetDescriptions.catalog(sheet)
	var keys: PackedStringArray = PackedStringArray()
	for entry: Dictionary in catalog:
		keys.append("%s:%s" % [str(entry.get("kind", "")), str(entry.get("name", ""))])
	all_passed = _check("the catalog lists the sheet, its variables, its functions and its groups once each",
		", ".join(keys),
		"sheet:Player, variable:hp, variable:max_hp, function:heal, function:hurt, group:Damage") and all_passed
	all_passed = _check("a function entry carries its signature as the detail beside the name",
		str(catalog[3].get("detail", "")), "heal(amount: int) -> void") and all_passed

	# Coverage is a fact, not a score: the described count, the total, and WHICH ones are missing.
	var coverage: Dictionary = EventSheetDescriptions.coverage(sheet)
	all_passed = _check("coverage counts the described things",
		int(coverage.get("described", 0)), 3) and all_passed
	all_passed = _check("coverage counts every describable thing",
		int(coverage.get("total", 0)), 6) and all_passed
	all_passed = _check("coverage names the ones still to write",
		", ".join(coverage.get("undescribed", PackedStringArray())),
		"variable:max_hp, function:hurt, group:Damage") and all_passed
	all_passed = _check("the coverage sentence states it plainly",
		EventSheetDescriptions.coverage_sentence(sheet), "3 of 6 described") and all_passed

	# ── Drafts: composed from the rows, and the same string every time ──────────────────────
	var hurt: EventFunction = _function_named(sheet, "hurt")
	var draft: String = EventSheetDescriptionDrafts.for_function(hurt)
	all_passed = _check("a function's draft composes its own rows into one sentence",
		draft, "Set self.hp = hp - amount; print hit") and all_passed
	all_passed = _check("the same rows compose the same draft on every ask",
		EventSheetDescriptionDrafts.for_function(hurt), draft) and all_passed

	# A block of hand-written code is said honestly rather than glossed over.
	var coded: EventFunction = EventFunction.new()
	coded.function_name = "solve"
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = "var answer := _solver.step(delta)"
	coded.events = [raw]
	all_passed = _check("a row nobody can read as a sentence says so, and does not guess",
		EventSheetDescriptionDrafts.for_function(coded), "Runs its own code") and all_passed

	# It lists what is there and counts the rest, rather than composing a forty-clause sentence.
	var busy: EventFunction = EventFunction.new()
	busy.function_name = "busy"
	var busy_row: EventRow = EventRow.new()
	for index: int in range(5):
		busy_row.actions.append(_print_action("line %d" % index))
	busy.events = [busy_row]
	all_passed = _check("a long function names the first steps and counts the rest",
		EventSheetDescriptionDrafts.for_function(busy),
		"Print line 0, print line 1; print line 2; and 2 more steps") and all_passed

	# A function with nothing in it drafts nothing: a draft of nothing would just be its own name.
	all_passed = _check("an empty function drafts nothing at all",
		EventSheetDescriptionDrafts.for_function(EventFunction.new()), "") and all_passed

	# A parameter drafts from the row that uses it, and stays silent when nothing reads it.
	all_passed = _check("a parameter drafts from the first row that names it",
		EventSheetDescriptionDrafts.for_parameter(hurt, "amount"),
		"Used to set self.hp = hp - amount") and all_passed
	all_passed = _check("a parameter nothing reads has nothing honest to say",
		EventSheetDescriptionDrafts.for_parameter(hurt, "unused"), "") and all_passed

	# ── Drift: rewording is not drift, losing the subject is ────────────────────────────────
	var reworded: EventFunction = _function_named(sheet, "hurt")
	reworded.doc_comment = "Takes amount off hp, however much armour says."
	all_passed = _check("a reworded description whose rows still name its subject has not drifted",
		EventSheetDescriptionDrafts.function_description_drifted(reworded), false) and all_passed
	reworded.doc_comment = ""
	var drifted: EventFunction = _function_named(sheet, "heal")
	all_passed = _check("a description whose rows no longer mention any of it has drifted",
		EventSheetDescriptionDrafts.function_description_drifted(drifted), true) and all_passed
	var undescribed_function: EventFunction = EventFunction.new()
	undescribed_function.function_name = "quiet"
	all_passed = _check("a function with no description cannot drift - there is no claim to check",
		EventSheetDescriptionDrafts.function_description_drifted(undescribed_function), false) and all_passed

	# ── The Doctor's page: notes only, each carrying the draft its rows compose ──────────────
	var findings: Array[Dictionary] = EventSheetSelfDocDoctor.report(sheet, "res://player.tres")
	var severities: PackedStringArray = PackedStringArray()
	var checks: PackedStringArray = PackedStringArray()
	for finding: Dictionary in findings:
		severities.append(str(finding.get("severity", "")))
		checks.append(str(finding.get("check", "")))
	all_passed = _check("nothing on the page is an error or a warning",
		", ".join(severities), "info, info, info, info, info") and all_passed
	all_passed = _check("the page opens with a summary and lists one line per undescribed thing",
		", ".join(checks),
		"self-doc, self-doc-undescribed, self-doc-undescribed, self-doc-undescribed, self-doc-drifted") and all_passed
	all_passed = _check("an undescribed thing's line carries the draft its own rows compose",
		str(findings[2].get("message", "")),
		"function hurt has no description. Draft from its own rows: \"Set self.hp = hp - amount; print hit\"") and all_passed
	all_passed = _check("the drift note shows the old words and the fresh draft side by side",
		str(findings[4].get("message", "")),
		"heal still says \"Raises hp and lights the icon.\", but its rows no longer mention any of that. Fresh draft: \"Print healed\"") and all_passed

	# ── The manual page: composed, never stored ─────────────────────────────────────────────
	var page: String = EventSheetProjectManual.page_for(sheet)
	all_passed = _check("the page leads with the sheet and its own description",
		page.split("\n")[0], "# Player") and all_passed
	all_passed = _check("the page states its coverage as a plain fact",
		page.contains("3 of 6 described."), true) and all_passed
	all_passed = _check("the footer names what is still to describe",
		page.contains("Still to describe: `variable:max_hp`, `function:hurt`, `group:Damage`."), true) and all_passed
	all_passed = _check("an undescribed thing reads the nudge on the page, not a blank",
		page.contains("*no description yet*"), true) and all_passed
	all_passed = _check("the same sheet composes the same bytes, so an export is diffable",
		EventSheetProjectManual.page_for(sheet), page) and all_passed
	all_passed = _check("pages for several sheets come back in sorted order, whatever order they arrived in",
		", ".join(EventSheetProjectManual.pages_for({"b.tres": sheet, "a.tres": sheet}).keys()),
		"a.tres, b.tres") and all_passed

	return all_passed


## The sheet every check above reads: two variables (one described), two functions (one described and
## drifted, one undescribed), a group and a class description. Built in memory so nothing on disk can
## change what these values are.
static func _sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Player"
	sheet.class_description = "The player's health and how it is spent."
	sheet.variables = {
		"hp": {"type": "int", "value": "10", "description": "How much damage the player can still take."},
		"max_hp": {"type": "int", "value": "10", "description": ""},
	}

	var heal: EventFunction = EventFunction.new()
	heal.function_name = "heal"
	heal.doc_comment = "Raises hp and lights the icon."
	heal.return_type = TYPE_NIL
	heal.params = [_param("amount", "int")]
	var heal_row: EventRow = EventRow.new()
	heal_row.actions = [_print_action("healed")]
	heal.events = [heal_row]

	var hurt: EventFunction = EventFunction.new()
	hurt.function_name = "hurt"
	hurt.params = [_param("amount", "int")]
	var hurt_row: EventRow = EventRow.new()
	hurt_row.actions = [_set_property("self", "hp", "hp - amount"), _print_action("hit")]
	hurt.events = [hurt_row]

	sheet.functions = [heal, hurt]

	var group: EventGroup = EventGroup.new()
	group.name = "Damage"
	sheet.events = [group]
	return sheet


static func _param(param_id: String, type_name: String) -> ACEParam:
	var param: ACEParam = ACEParam.new()
	param.id = param_id
	param.type_name = type_name
	return param


static func _print_action(message: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "PrintLog"
	action.params = {"message": "\"%s\"" % message}
	return action


static func _set_property(target: String, property: String, value: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SetProperty"
	action.params = {"target": target, "property": property, "value": value}
	return action


static func _function_named(sheet: EventSheetResource, name: String) -> EventFunction:
	for entry: Variant in sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name == name:
			return entry as EventFunction
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("self_documenting_sheets_test", label, actual, expected)
