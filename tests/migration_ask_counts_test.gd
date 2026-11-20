# Godot EventSheets - "rows that ask you" is one count in every place that says it.
#
# The head of a script counted EVENTS holding a verb the vocabulary lost, the Migrate window listed
# ROWS, and the Doctor's summary counted sheets holding a lost verb while its per-sheet line counted
# rows that ask you, so one sheet could read "2 rows ask you", then show 3 rows, then sit under a
# summary that said 0. Now the head, the window and the Doctor's per-sheet line all count rows, and
# the summary has a figure of its own for the sheets that have rows asking you.
@tool
class_name MigrationAskCountsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "migration_ask_counts_test"


static func run() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = _sheet_with_three_gone_rows()
	var catalog: Dictionary = EventForgeSuccessors.catalog()
	var found: Array[Dictionary] = EventSheetMigrationFindings.findings(sheet, "res://probe.gd",
		EventSheetMigrationFindings.resolver_over(catalog))
	var planned: Array[Dictionary] = EventSheetMigrationPlan.plan(sheet, catalog)
	var window_asks: int = 0
	for entry: Dictionary in planned:
		if bool(entry.get("asks", true)):
			window_asks += 1
	ok = SUPPORT.check(P, "the window lists three rows that ask you", window_asks, 3) and ok
	ok = SUPPORT.check(P, "the findings the head is built from count the same three rows",
		EventSheetMigrationFindings.rows_asking(found), 3) and ok
	ok = SUPPORT.check(P, "the head says three rows ask you, not two events",
		_head_words(sheet).has("3 rows ask you"), true) and ok
	# The Doctor: the per-sheet line and the summary agree about the same sheet.
	var path: String = SUPPORT.own_path("migration_ask_counts_probe.tres")
	ok = SUPPORT.check(P, "the probe sheet saves", ResourceSaver.save(sheet, path), OK) and ok
	var said: Array[Dictionary] = []
	said.assign(EventSheetMigrationDoctor._audit(PackedStringArray([path]), {}).get("findings", []))
	var summary: String = str(said[0].get("message", ""))
	ok = SUPPORT.check(P, "the summary counts the sheet with rows that ask you",
		summary.contains("sheets with rows that ask you: 1"), true) and ok
	var lines: Array[Dictionary] = EventSheetMigrationDoctor.sheet_lines(
		EventSheetMigrationDoctor.rows(PackedStringArray([path])))
	ok = SUPPORT.check(P, "and the per-sheet line counts the three rows",
		str(lines[0].get("message", "")).contains("rows that ask you: 3"), true) and ok
	var quiet: EventSheetResource = EventSheetResource.new()
	quiet.host_class = "Node2D"
	var quiet_path: String = SUPPORT.own_path("migration_ask_counts_quiet.tres")
	ok = SUPPORT.check(P, "the quiet sheet saves", ResourceSaver.save(quiet, quiet_path), OK) and ok
	var quiet_said: Array[Dictionary] = []
	quiet_said.assign(EventSheetMigrationDoctor._audit(PackedStringArray([quiet_path]), {}).get("findings", []))
	ok = SUPPORT.check(P, "a sheet with nothing to migrate counts none",
		str(quiet_said[0].get("message", "")).contains("sheets with rows that ask you: 0"), true) and ok
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(quiet_path)
	return ok


## One event holding a lost verb in its condition and in two actions, so the old event count said one
## while the window listed three rows.
static func _sheet_with_three_gone_rows() -> EventSheetResource:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "LightFlicker"
	condition.ace_id = "LightIsFlickering"
	condition.codegen_template = "{light}.is_flickering()"
	condition.display_text = "{light} is flickering"
	condition.params = {"light": "$Lamp"}
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	event.conditions = [condition] as Array[ACECondition]
	var actions: Array[Resource] = []
	for amount: String in ["0.4", "0.8"]:
		var action: ACEAction = ACEAction.new()
		action.provider_id = "LightFlicker"
		action.ace_id = "FlickerLight"
		action.codegen_template = "flicker({light}, {amount})"
		action.display_text = "Flicker {light} by {amount}"
		action.params = {"light": "$Lamp", "amount": amount}
		actions.append(action)
	event.actions = actions
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.external_source_path = "res://migration_ask_counts_probe.tres"
	sheet.events = [event] as Array[Resource]
	return sheet


static func _head_words(sheet: EventSheetResource) -> PackedStringArray:
	var words: PackedStringArray = PackedStringArray()
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	for entry: Dictionary in editor._viewport.get_flat_rows():
		var row: EventRowData = entry.get("row")
		if row == null or row.source_resource != null:
			continue
		for span: EventSheetSemanticSpan in row.spans:
			words.append(span.text)
	editor.free()
	return words
