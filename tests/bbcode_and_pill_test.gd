# Godot EventSheets — BBCode in cells/tooltips + removal of the scope pill.
#
# R4: a condition/action cell whose display text carries BBCode-lite ([b]/[i]/[color]) draws styled, with the
# STRIPPED text driving layout (so the colour swatch + width align); plain text with stray brackets is left
# alone. A hover description with markup gets a rich (BBCode) tooltip; plain text uses the default.
# R3: variable rows no longer show a scope pill ("local"/"global") — it confused users.
@tool
extends RefCounted
class_name BBCodeAndPillTest

static func run() -> bool:
	var all_passed: bool = true
	var viewport: EventSheetViewport = EventSheetViewport.new()

	# R4 — BBCode in a condition/action cell: styled segments + stripped text for layout.
	var styled: SemanticSpan = viewport._make_span("[b]Destroy[/b] [color=red]enemy[/color]", SemanticSpan.SpanType.VALUE, {"kind": "condition"})
	all_passed = _check("BBCode cell text is stripped for layout", styled.text, "Destroy enemy") and all_passed
	all_passed = _check("BBCode cell sets styled segments",
		styled.metadata.get("bbcode_segments") is Array and (styled.metadata["bbcode_segments"] as Array).size() >= 2, true) and all_passed

	# A plain cell with stray brackets must NOT be treated as markup (has_markup is conservative).
	var plain: SemanticSpan = viewport._make_span("Set array to [1, 2, 3]", SemanticSpan.SpanType.VALUE, {"kind": "action"})
	all_passed = _check("plain cell text is left as-is", plain.text, "Set array to [1, 2, 3]") and all_passed
	all_passed = _check("plain cell has no bbcode segments", plain.metadata.has("bbcode_segments"), false) and all_passed

	# R4 — hover tooltip: a custom rich widget only when the description has markup.
	all_passed = _check("a BBCode description yields a custom tooltip widget",
		viewport._make_custom_tooltip("[b]Bold[/b] help") != null, true) and all_passed
	all_passed = _check("a plain description uses the default tooltip (null)",
		viewport._make_custom_tooltip("just plain help") == null, true) and all_passed

	# R3 — no variable row shows a scope pill anymore.
	var event: EventRow = EventRow.new()
	var local_var: LocalVariable = LocalVariable.new()
	local_var.name = "combo"
	local_var.type_name = "int"
	local_var.default_value = 0
	event.local_variables.append(local_var)
	all_passed = _check("a local variable row shows no scope pill",
		_has_scope_pill(viewport._build_local_variable_rows(event, 1)), false) and all_passed

	viewport.free()
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
