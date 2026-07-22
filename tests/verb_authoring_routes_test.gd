# Godot EventSheets - a verb's parameters and guards are authored ON THE SHEET.
#
# The verb dialog used to carry a parameter list and a "Run only when" card. Both were second, weaker
# ways to say something the sheet already says: a parameter is a cell on the verb's row, and a guard is
# a CONDITION on an event inside the verb. Removing them only works if the sheet-side routes actually
# exist, so this pins the two that carry the load:
#
#   1. The "+ Add parameter" cell must appear on a .gd-backed sheet. That is the DEFAULT sheet format
#      (external_source_path is always set), and the cell used to be hidden there - so removing the
#      dialog's list without this would have left NO way to add a parameter to almost any real sheet.
#   2. A verb whose body is editable must offer "+ Add event to <verb>", owned by the EventFunction.
#      A freshly created verb has an empty body, so without it there is nowhere to put the first event -
#      and a guard is a condition on exactly that event.
@tool
class_name VerbAuthoringRoutesTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	# The default format: a sheet backed by a .gd file.
	var gd_backed: Dictionary = _routes_for("res://demo/does_not_exist_probe.gd")
	all_passed = _check("a .gd-backed sheet offers + Add parameter", gd_backed.get("add_param"), true) and all_passed
	# An authored (in-memory) sheet, where the verb body is live.
	var authored: Dictionary = _routes_for("")
	all_passed = _check("an authored sheet offers + Add parameter", authored.get("add_param"), true) and all_passed
	all_passed = _check("an editable verb body offers + Add event", authored.get("add_event"), true) and all_passed
	all_passed = _check("that add-event cell is owned by the verb itself", authored.get("owner_is_function"), true) and all_passed

	# A read-only sheet must grow neither - it can honour no edit.
	var locked: Dictionary = _routes_for("", true)
	all_passed = _check("a read-only sheet offers no + Add parameter", locked.get("add_param"), false) and all_passed

	if all_passed:
		print("[PASS] verb_authoring_routes: parameters and guards are reachable from the sheet.")
	return all_passed


## Builds a one-verb sheet and reports which authoring affordances its rows carry.
static func _routes_for(source_path: String, read_only: bool = false) -> Dictionary:
	var sheet := EventSheetResource.new()
	sheet.external_source_path = source_path
	sheet.read_only = read_only
	var verb := EventFunction.new()
	verb.function_name = "deal_damage"
	verb.ace_display_name = "Deal Damage"
	verb.expose_as_ace = true
	sheet.functions = [verb]
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var viewport: EventSheetViewport = editor.get_viewport_control()
	viewport._rebuild_row_metrics()
	var result := {"add_param": false, "add_event": false, "owner_is_function": false}
	for entry: Dictionary in viewport.get_flat_rows():
		var row: EventRowData = entry.get("row")
		if row == null:
			continue
		viewport._ensure_event_spans(row)
		for span: SemanticSpan in row.spans:
			var meta: Dictionary = span.metadata if span.metadata is Dictionary else {}
			match str(meta.get("kind", "")):
				"verb_param_add":
					result["add_param"] = true
				"add_event":
					# The SHEET's own footer carries this kind too, with a different owner - so accumulate
					# rather than assign, or whichever row comes last silently decides the answer.
					if meta.get("add_event_owner") is EventFunction:
						result["add_event"] = true
						result["owner_is_function"] = true
	editor.free()
	return result


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] verb_authoring_routes: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
