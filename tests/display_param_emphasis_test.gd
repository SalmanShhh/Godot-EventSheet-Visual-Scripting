# EventSheet - the C3 parameter emphasis: display substitution tracks where each param value
# lands ([start, length] ranges the renderer bolds). Pins the tracking helper's VALUES (exact
# starts/lengths, repeated slots, cross-pass shifting, the overlap-drop degenerate, empty
# values), the span attach through the REAL formatter (including the hourglass-prefix shift),
# and the precedence rule: an author's BBCode template supersedes the automatic emphasis.
@tool
class_name DisplayParamEmphasisTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ── The tracking helper (static + pure) ──
	var simple: Dictionary = ViewportRowBuilder.substitute_display_tracking(
		"Set layout scale to {value}", [["{value}", "lerp(LayoutScale, 1, 15 * dt)"]])
	ok = _check("simple text substitutes", str(simple.get("text")), "Set layout scale to lerp(LayoutScale, 1, 15 * dt)") and ok
	ok = _check("simple range lands on the value", simple.get("ranges"), [[20, 29]]) and ok

	var repeated: Dictionary = ViewportRowBuilder.substitute_display_tracking(
		"{x} and {x} then {y}", [["{x}", "10"], ["{y}", "go"]])
	ok = _check("repeated slot substitutes everywhere", str(repeated.get("text")), "10 and 10 then go") and ok
	ok = _check("every occurrence gets its own range", repeated.get("ranges"), [[0, 2], [7, 2], [15, 2]]) and ok

	# A later pass whose token sits BEFORE an existing range must shift that range.
	var shifted: Dictionary = ViewportRowBuilder.substitute_display_tracking(
		"{b} after {a}", [["{a}", "12345"], ["{b}", "x"]])
	ok = _check("later shorter substitution shifts the earlier range", str(shifted.get("text")), "x after 12345") and ok
	ok = _check("shifted ranges stay exact", shifted.get("ranges"), [[0, 1], [8, 5]]) and ok

	# The degenerate: a value that itself contains a later slot token - the later pass rewrites
	# through the first range, which is DROPPED rather than mis-bolded.
	var overlap: Dictionary = ViewportRowBuilder.substitute_display_tracking(
		"say {a}", [["{a}", "pre {b} post"], ["{b}", "X"]])
	ok = _check("overlap text matches the replace chain", str(overlap.get("text")), "say pre X post") and ok
	ok = _check("the rewritten-through range is dropped, the inner one kept", overlap.get("ranges"), [[8, 1]]) and ok

	var empty_value: Dictionary = ViewportRowBuilder.substitute_display_tracking("go {a} now", [["{a}", ""]])
	ok = _check("an empty value leaves no range", (empty_value.get("ranges") as Array).is_empty(), true) and ok
	ok = _check("an empty value still substitutes", str(empty_value.get("text")), "go  now") and ok

	# ── Through the real formatter into span metadata ──
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var play: ACEAction = ACEAction.new()
	play.provider_id = "Core"
	play.ace_id = "PlaySound"
	play.params = {"path": "\"res://sfx/jump.ogg\""}
	event.actions.append(play)
	var wait: ACEAction = ACEAction.new()
	wait.provider_id = "Core"
	wait.ace_id = "Wait"
	wait.params = {"seconds": "0.5"}
	event.actions.append(wait)
	sheet.events.append(event)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var play_span: SemanticSpan = _find_span(editor, "res://sfx/jump.ogg")
	ok = _check("a real action span carries param ranges", play_span != null and play_span.metadata.has("param_ranges"), true) and ok
	if play_span != null and play_span.metadata.has("param_ranges"):
		var first_range: Array = (play_span.metadata["param_ranges"] as Array)[0]
		ok = _check("the range covers exactly the substituted value",
			play_span.text.substr(int(first_range[0]), int(first_range[1])), "\"res://sfx/jump.ogg\"") and ok
	# The Wait action wears the ⏳ prefix AFTER substitution - the attach must shift, not drop.
	var wait_span: SemanticSpan = _find_span(editor, "⏳")
	ok = _check("a decorated (hourglass) span still carries shifted ranges",
		wait_span != null and wait_span.metadata.has("param_ranges"), true) and ok
	if wait_span != null and wait_span.metadata.has("param_ranges"):
		var wait_range: Array = (wait_span.metadata["param_ranges"] as Array)[0]
		ok = _check("the shifted range still covers exactly the value",
			wait_span.text.substr(int(wait_range[0]), int(wait_range[1])), "0.5") and ok

	# ── Precedence: an author BBCode template supersedes the automatic emphasis ──
	var view: EventSheetViewport = editor._active_view()
	view._pending_display_bbcode = true
	view._pending_param_ranges = {"text": "[b]Destroy[/b] enemy", "ranges": [[0, 7]]}
	var styled: SemanticSpan = view._make_span("[b]Destroy[/b] enemy", SemanticSpan.SpanType.VALUE, {"kind": "action"})
	ok = _check("author BBCode wins: no param ranges on a styled cell", styled.metadata.has("param_ranges"), false) and ok
	ok = _check("author BBCode still styles", styled.metadata.has("bbcode_segments"), true) and ok

	# ── Author-marked cells KEEP the typed value tints (ranges on the stripped text) ──
	view._pending_display_bbcode = true
	var tinted: SemanticSpan = view._make_span("[b]Heal[/b] 5 \"x\"", SemanticSpan.SpanType.VALUE, {"kind": "action"})
	ok = _check("a marked cell strips for layout", tinted.text, "Heal 5 \"x\"") and ok
	ok = _check("a marked cell still carries value ranges on the stripped text",
		tinted.metadata.get("value_ranges"), [[5, 1, "number"], [7, 3, "string"]]) and ok

	# ── Translation safety: a marked template falls back to the locale's PLAIN key ──
	var made_dir: bool = not DirAccess.dir_exists_absolute("res://eventsheet_translations")
	if made_dir:
		DirAccess.make_dir_recursive_absolute("res://eventsheet_translations")
	var csv: FileAccess = FileAccess.open("res://eventsheet_translations/xx_emphasis_test.csv", FileAccess.WRITE)
	csv.store_string("keys,xx\nMarked {value} demo,XX {value} fin\n")
	csv.close()
	EventSheetL10n.ensure_loaded()
	var before_locale: String = EventSheetL10n.get_locale()
	EventSheetL10n.reload_if_changed()
	EventSheetL10n.set_locale("xx")
	var marked_definition: ACEDefinition = ACEDefinition.new()
	marked_definition.provider_id = "Test"
	marked_definition.id = "MarkedDemo"
	marked_definition.display_name = "Marked Demo"
	marked_definition.metadata = {"display_template": "Marked [b]{value}[/b] demo"}
	marked_definition.parameters = [{"id": "value"}]
	var builder: ViewportRowBuilder = view._row_builder
	var translated_out: String = builder._format_display_translated(marked_definition, null, {"value": "7"})
	ok = _check("a locale that predates the markup gets its PLAIN sentence", translated_out, "XX 7 fin") and ok
	ok = _check("the plain fallback never arms the styled branch", builder._pending_display_bbcode, false) and ok
	builder._pending_param_ranges = {}
	EventSheetL10n.set_locale("en")
	var english_out: String = builder._format_display_translated(marked_definition, null, {"value": "7"})
	ok = _check("English keeps the marked template substituted", english_out, "Marked [b]7[/b] demo") and ok
	ok = _check("markup in the resolved template arms the styled branch", builder._pending_display_bbcode, true) and ok
	builder._pending_display_bbcode = false
	builder._pending_param_ranges = {}
	DirAccess.remove_absolute("res://eventsheet_translations/xx_emphasis_test.csv")
	if made_dir:
		DirAccess.remove_absolute("res://eventsheet_translations")
	EventSheetL10n.reload_if_changed()
	EventSheetL10n.set_locale(before_locale)

	editor.free()
	return ok


static func _find_span(editor: EventSheetEditor, needle: String) -> SemanticSpan:
	var view: EventSheetViewport = editor._active_view()
	for flat: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = flat.get("row")
		if row_data == null:
			continue
		for span: SemanticSpan in row_data.spans:
			if str(span.metadata.get("kind", "")) == "action" and span.text.contains(needle):
				return span
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] display_param_emphasis_test: %s" % label)
		return true
	print("[FAIL] display_param_emphasis_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
