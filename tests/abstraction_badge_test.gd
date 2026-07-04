# Godot EventSheets - the compression cue (abstraction made visible).
#
# A row earns its keep when 1 row != 1 line. Actions whose baked template compiles to
# more than one GDScript line now carry span metadata "compiled_lines"; the renderer
# draws a muted "→N" after the text, so compressing rows read as earned leverage and
# plain 1:1 rows read as Extract-to-Function candidates.
@tool
class_name AbstractionBadgeTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# The classifier is pure: line count of the baked template, 0 when nothing is baked.
	var multi: ACEAction = ACEAction.new()
	multi.codegen_template = "var __t_{uid} := $Player\nif __t_{uid} != null:\n\t__t_{uid}.show()"
	ok = _check("a three-line template counts 3", ViewportRowBuilder.compiled_line_count(multi), 3) and ok
	var single: ACEAction = ACEAction.new()
	single.codegen_template = "queue_free()"
	ok = _check("a one-line template counts 1", ViewportRowBuilder.compiled_line_count(single), 1) and ok
	ok = _check("no baked template claims nothing", ViewportRowBuilder.compiled_line_count(ACEAction.new()), 0) and ok

	# Through a real view build: the action span carries the count for the renderer.
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var compressing: ACEAction = ACEAction.new()
	compressing.provider_id = "Core"
	compressing.ace_id = "ShowPlayer"
	compressing.codegen_template = "var __t := $Player\nif __t != null:\n\t__t.show()"
	event.actions.append(compressing)
	var plain: ACEAction = ACEAction.new()
	plain.provider_id = "Core"
	plain.ace_id = "Print"
	plain.codegen_template = "print({value})"
	plain.params = {"value": "\"hi\""}
	event.actions.append(plain)
	sheet.events.append(event)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var viewport: EventSheetViewport = editor.get_viewport_control()
	var counts: Array = []
	for row_index in range(viewport.get_total_row_count()):
		var row_data: EventRowData = viewport._row_at(row_index)
		if row_data == null:
			continue
		for span: SemanticSpan in row_data.spans:
			if str(span.metadata.get("kind", "")) == "action" and span.metadata.has("compiled_lines"):
				counts.append(int(span.metadata.get("compiled_lines")))
	ok = _check("action spans carry the compression counts", counts, [3, 1]) and ok
	editor.free()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] abstraction_badge_test: %s" % label)
		return true
	print("[FAIL] abstraction_badge_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
