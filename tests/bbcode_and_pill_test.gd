# Godot EventSheets - BBCode in cells/tooltips + removal of the scope pill.
#
# R4: a condition/action cell whose display text carries BBCode-lite ([b]/[i]/[color]) draws styled, with the
# STRIPPED text driving layout (so the colour swatch + width align); plain text with stray brackets is left
# alone. A hover description with markup gets a rich (BBCode) tooltip; plain text uses the default.
# R3: variable rows no longer show a scope pill ("local"/"global") - it confused users.
@tool
class_name BBCodeAndPillTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	var viewport: EventSheetViewport = EventSheetViewport.new()

	# R4 - when the AUTHOR's display template carried markup (the one-shot flag is set), the cell renders
	# styled, with the stripped text driving layout.
	viewport._pending_display_bbcode = true
	var styled: SemanticSpan = viewport._make_span("[b]Destroy[/b] [color=red]enemy[/color]", SemanticSpan.SpanType.VALUE, {"kind": "condition"})
	all_passed = _check("author-markup cell text is stripped for layout", styled.text, "Destroy enemy") and all_passed
	all_passed = _check("author-markup cell sets styled segments",
		styled.metadata.get("bbcode_segments") is Array and (styled.metadata["bbcode_segments"] as Array).size() >= 2, true) and all_passed

	# R4 FIX (review): a USER param value/note containing literal BBCode, in a PLAIN-template cell (flag
	# clear), is drawn LITERALLY - never stripped or styled. This is the footgun the adversarial review caught
	# (e.g. a "Set RichTextLabel text to [b]Hi[/b]" action whose text is the user's own BBCode).
	viewport._pending_display_bbcode = false
	var user_value: SemanticSpan = viewport._make_span("Set label to [b]Hi[/b]", SemanticSpan.SpanType.VALUE, {"kind": "action"})
	all_passed = _check("a user value with literal BBCode is left intact (plain template)", user_value.text, "Set label to [b]Hi[/b]") and all_passed
	all_passed = _check("a plain-template cell has no bbcode segments", user_value.metadata.has("bbcode_segments"), false) and all_passed

	# R4 - hover tooltip: a custom rich widget only when the description has markup.
	all_passed = _check("a BBCode description yields a custom tooltip widget",
		viewport._make_custom_tooltip("[b]Bold[/b] help") != null, true) and all_passed
	all_passed = _check("a plain description uses the default tooltip (null)",
		viewport._make_custom_tooltip("just plain help") == null, true) and all_passed

	# R3 - no variable row shows a scope pill anymore.
	var event: EventRow = EventRow.new()
	var local_var: LocalVariable = LocalVariable.new()
	local_var.name = "combo"
	local_var.type_name = "int"
	local_var.default_value = 0
	event.local_variables.append(local_var)
	all_passed = _check("a local variable row shows no scope pill",
		_has_scope_pill(viewport._build_local_variable_rows(event, 1)), false) and all_passed

	viewport.free()

	# Rich-param rendering (the Rich Print rule): an ACE that IS rich text (print_rich
	# stream / bbcode_text param) shows its BBCode's EFFECT in the cell; a plain string
	# param keeps the tags verbatim - `[b]` in an ordinary Print is data, not styling.
	var rich_event: EventRow = EventRow.new()
	rich_event.trigger_provider_id = "Core"
	rich_event.trigger_id = "OnReady"
	var rich_action: ACEAction = ACEAction.new()
	rich_action.provider_id = "Core"
	rich_action.ace_id = "ConsoleLog"
	rich_action.params = {"message": "\"[b]Wave 2[/b] begins\"", "level": "print_rich"}
	rich_event.actions.append(rich_action)
	var plain_action: ACEAction = ACEAction.new()
	plain_action.provider_id = "Core"
	plain_action.ace_id = "PushWarning"
	plain_action.codegen_template = "push_warning({message})"
	plain_action.params = {"message": "\"literal [b]tags[/b]\""}
	rich_event.actions.append(plain_action)
	var rich_sheet: EventSheetResource = EventSheetResource.new()
	rich_sheet.events.append(rich_event)
	var rich_editor: EventSheetEditor = EventSheetEditor.new()
	rich_editor.setup(rich_sheet)
	var rich_span: SemanticSpan = null
	var plain_span: SemanticSpan = null
	for flat_entry: Dictionary in rich_editor.get_viewport_control().get_flat_rows():
		var row_data: EventRowData = flat_entry.get("row")
		if row_data == null:
			continue
		for span: Variant in row_data.spans:
			var meta: Dictionary = (span as SemanticSpan).metadata if (span as SemanticSpan).metadata is Dictionary else {}
			if str(meta.get("kind", "")) == "action":
				if int(meta.get("ace_index", -1)) == 0:
					rich_span = span
				elif int(meta.get("ace_index", -1)) == 1:
					plain_span = span
	all_passed = _check("a print_rich cell strips the tags from its display text",
		rich_span != null and not rich_span.text.contains("[b]"), true) and all_passed
	all_passed = _check("a print_rich cell carries styled segments",
		rich_span != null and (rich_span.metadata.get("bbcode_segments", []) as Array).size() >= 2, true) and all_passed
	all_passed = _check("a plain string param keeps its literal tags",
		plain_span != null and plain_span.text.contains("[b]"), true) and all_passed
	rich_editor.free()

	return all_passed


## True when any row carries a scope-pill badge span (text "local"/"global"/"tree").
static func _has_scope_pill(rows: Array) -> bool:
	for row: Variant in rows:
		if not (row is EventRowData):
			continue
		for span: Variant in (row as EventRowData).spans:
			var meta: Dictionary = (span as SemanticSpan).metadata if (span as SemanticSpan).metadata is Dictionary else {}
			if str((span as SemanticSpan).text) in ["local", "global", "tree"] and bool(meta.get("badge", false)):
				return true
	return false


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] bbcode_and_pill_test: %s" % label)
		return true
	print("[FAIL] bbcode_and_pill_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
