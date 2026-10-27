# Godot EventSheets - a row says what it is by its icons, never by a word in front of it.
#
# A trigger line carries a green arrow in front of its object icon, an inverted condition a red cross
# in the same slot, and every other line nothing; the action lane carries no mark at all. A function
# head is a line like any other - the function icon, then "On function <name>" straight after it with
# no object name - with one line per parameter under it (the parameter icon, its name, its type) and a local variable as a line with
# the local icon; no "Action" / "Function" / "PARAM" / "Local" word is drawn. A behaviour's action keeps
# the node it is mounted on and starts its words with the behaviour's name and a colon. The pins hold:
#   1. which mark a badge span draws, as a pure function;
#   2. the trigger and the inverted badges are built in every look (the native look's number gutter
#      no longer swallows the trigger's badge) and the marks' colours per hand;
#   3. the function head, its parameter lines and a local line, with no kind word anywhere, and a
#      function's return line, which like the head names no object;
#   4. a behaviour's action words lead with "Name: " and the old object-column shape is retired.
# Headless-safe: the icons themselves need an editor theme, so the pins read the spans' words and
# metadata, never a texture.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "row_kind_marks_test"
const NativeRowMarks := preload("res://addons/eventsheet/editor/interaction/native_row_marks.gd")
const NATIVE_THEME := "res://addons/eventsheet/themes/editor_native_theme.tres"


static func run() -> bool:
	var ok: bool = true
	ok = _test_mark_rule() and ok
	ok = _test_badges_in_every_look() and ok
	ok = _test_function_head_lines() and ok
	ok = _test_behaviour_words() and ok
	ok = _test_function_return_lines() and ok
	return ok


static func _test_mark_rule() -> bool:
	return SUPPORT.pins(TEST_NAME, [
		["a one-off trigger wears the arrow",
			NativeRowMarks.kind_mark_for({"badge_style": "trigger", "tempo": TriggerResolver.TEMPO_ONCE}, "▶"),
			NativeRowMarks.KIND_MARK_TRIGGER],
		["an input trigger wears the arrow",
			NativeRowMarks.kind_mark_for({"badge_style": "trigger", "tempo": TriggerResolver.TEMPO_INPUT}, "⌨"),
			NativeRowMarks.KIND_MARK_TRIGGER],
		["a signal trigger wears the arrow", NativeRowMarks.kind_mark_for({"badge_style": "trigger"}, "➜"),
			NativeRowMarks.KIND_MARK_TRIGGER],
		["a per-frame event is not a trigger: no mark",
			NativeRowMarks.kind_mark_for({"badge_style": "trigger", "tempo": TriggerResolver.TEMPO_EVERY_TICK}, "⟳"), ""],
		["a repeating timer is not a trigger either", NativeRowMarks.kind_mark_for({"badge_style": "trigger"}, "⟳"), ""],
		["a state's case is a plain check", NativeRowMarks.kind_mark_for({"badge_style": "trigger"}, "◆"), ""],
		["an inverted condition wears the cross", NativeRowMarks.kind_mark_for({"badge_style": "negated"}, "not"),
			NativeRowMarks.KIND_MARK_INVERTED],
		["any other badge draws no kind mark", NativeRowMarks.kind_mark_for({"badge_style": "scope"}, "x"), ""],
		["the mark is centred in its slot",
			NativeRowMarks.kind_mark_rect(Rect2(10.0, 0.0, 16.0, 20.0)), Rect2(12.0, 4.0, 12.0, 12.0)],
	])


static func _test_badges_in_every_look() -> bool:
	var ok: bool = true
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var row: EventRow = EventRow.new()
	row.trigger_id = "OnReady"
	var condition: ACECondition = ACECondition.new()
	condition.ace_id = "cond_inverted"
	condition.negated = true
	row.conditions.append(condition)
	sheet.events.append(row)
	viewport.set_sheet(sheet)
	var default_badges: PackedStringArray = _badge_styles(viewport._row_builder._build_event_spans(row))
	var native: EventSheetEditorStyle = load(NATIVE_THEME) as EventSheetEditorStyle
	viewport.apply_editor_style(native)
	var native_badges: PackedStringArray = _badge_styles(viewport._row_builder._build_event_spans(row))
	var dark: EventSheetEventStyle = EventSheetEditorThemeDeriver.native_style(
		EventSheetEditorThemeDeriver.NATIVE_DARK_REFERENCE_BASE).get_event_style()
	var light: EventSheetEventStyle = EventSheetEditorThemeDeriver.native_style(Color("#e6e6e6")).get_event_style()
	ok = SUPPORT.pins(TEST_NAME, [
		["the trigger line and the inverted line each carry their badge", default_badges,
			PackedStringArray(["trigger", "negated"])],
		["the native look keeps the trigger's badge in the lane too", native_badges,
			PackedStringArray(["trigger", "negated"])],
		["the native look gives every condition line a 16 px mark slot",
			native.get_event_style().condition_badge_column_width, 16],
		["the native rule gives it the same slot", dark.condition_badge_column_width, 16],
		["the trigger arrow is green on a dark sheet", dark.trigger_mark_color, Color("#6ccb4e")],
		["and a deeper green on a light one", light.trigger_mark_color, Color("#22700e")],
		["the inverted cross is red on a dark sheet", dark.invert_marker_color, Color("#f07a7a")],
		["and a deeper red on a light one", light.invert_marker_color, Color("#b42318")],
		["the shipped native look says the same green", native.get_event_style().trigger_mark_color.to_html(false), "6ccb4e"],
	]) and ok
	viewport.free()
	return ok


static func _test_function_head_lines() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event_function: EventFunction = EventFunction.new()
	event_function.function_name = "juice_tile"
	event_function.expose_as_ace = true
	for pair: Array in [["index", "int", ""], ["kick", "float", "1.0"]]:
		var param: ACEParam = ACEParam.new()
		param.id = str(pair[0])
		param.type_name = str(pair[1])
		param.gdscript_default = str(pair[2])
		event_function.params.append(param)
	sheet.functions.append(event_function)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var head: EventRowData = null
	for entry: Dictionary in dock._active_view().get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.row_uid.begins_with("define_fn_juice_tile"):
			head = row_data
	var texts: PackedStringArray = PackedStringArray()
	var head_meta: Dictionary = {}
	var param_lines: Array = []
	if head != null:
		for span: SemanticSpan in head.spans:
			texts.append(span.text)
			var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
			if bool(metadata.get("function_name", false)):
				head_meta = metadata
			if str(metadata.get("kind", "")) == "verb_param":
				param_lines.append([str(metadata.get("object_label", "")), span.text,
					str(metadata.get("object_glyph", "")), int(metadata.get("line_index", -1))])
	ok = SUPPORT.pins(TEST_NAME, [
		["the head's first words read On function <name>, the name as written", texts[0] if not texts.is_empty() else "",
			"On function juice_tile"],
		["no object name stands before the words: the icon says function", str(head_meta.get("object_label", "")), ""],
		["the head leads with the function icon", str(head_meta.get("object_glyph", "")), NativeRowMarks.OBJECT_GLYPH_FUNCTION],
		["one line per parameter: its icon, its name, its type (and default)", param_lines, [
			["index", "int", NativeRowMarks.OBJECT_GLYPH_PARAMETER, 1],
			["kick", "float = 1.0", NativeRowMarks.OBJECT_GLYPH_PARAMETER, 2]]],
		["no Action word", texts.has("Action"), false],
		["no Function word", texts.has("Function"), false],
		["no PARAM word", texts.has("PARAM"), false],
		["no In Add Action chip on the row", texts.has("In Add Action"), false],
		["the kind is said by the name's hover instead",
			str(head_meta.get("hover_note", "")).contains("Action: Runs when an event calls it."), true],
		["and so is the flag",
			str(head_meta.get("hover_note", "")).contains("In Add Action: Listed in Add Action"), true],
		["an untyped parameter still says what it is",
			ViewportRowBuilder.function_param_type_words(_untyped_param()), "Variant"],
	]) and ok
	# A local variable is a line with the local icon: no "Local" word.
	var local_spans: Array = []
	dock._active_view()._row_builder.append_local_declaration_spans(local_spans,
		{"type_word": "Node2D", "name": "t", "value": "Tiles's child index"}, {"lane": "action", "line_index": 0}, {})
	var local_texts: PackedStringArray = PackedStringArray()
	for span: SemanticSpan in local_spans:
		local_texts.append(span.text)
	var local_meta: Dictionary = (local_spans[0] as SemanticSpan).metadata if not local_spans.is_empty() else {}
	ok = SUPPORT.pins(TEST_NAME, [
		["a local reads as its type then its value", local_texts, PackedStringArray(["Node2D", "= Tiles's child index"])],
		["its name stands in the object column", str(local_meta.get("object_label", "")), "t"],
		["with the local icon", str(local_meta.get("object_glyph", "")), NativeRowMarks.OBJECT_GLYPH_LOCAL],
	]) and ok
	dock.free()
	return ok


static func _test_behaviour_words() -> bool:
	# The pack index knows every pack by its category with the spaces taken out ("Health").
	var pack_name: String = str(EventSheetViewportReadingRows.behaviour_pack_index().get("Health", ""))
	var pieces: Array = [["Take damage ", "name"], ["3", "value"]]
	var attributed: Dictionary = EventSheetViewportReadingRows.object_attribution(
		"health", pieces, "Player", {"health": "Health"}, {})
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var native: EventSheetEditorStyle = load(NATIVE_THEME) as EventSheetEditorStyle
	viewport.apply_editor_style(native)
	var retired: bool = viewport._row_builder._behaviour_in_object_column()
	viewport.free()
	return SUPPORT.pins(TEST_NAME, [
		["the Health pack is known", pack_name, "Health"],
		["a behaviour's action keeps the node it is mounted on", str(attributed.get("object", "")), "Player"],
		["and its words lead with the behaviour's name and a colon", attributed.get("pieces", []),
			[["Health: ", "behaviour"], ["Take damage ", "name"], ["3", "value"]]],
		["no look names the behaviour in the object column any more", retired, false],
		["the shipped native look leaves the old setting off",
			native.get_event_style().behaviour_in_object_column, false],
	])


static func _test_function_return_lines() -> bool:
	var source: String = "extends CharacterBody2D

@export var health: int = 10


func take_hit(amount: int) -> int:
	var left: int = health - amount
	return left


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 980.0 * delta
		return
"
	var sheet: EventSheetResource = EventSheets.open_gd_as_sheet(source)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var view: EventSheetViewport = dock._active_view()
	var lines: Dictionary = {}
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data == null:
			continue
		view._row_builder._ensure_event_spans(row_data)
		for span: SemanticSpan in row_data.spans:
			var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
			if str(metadata.get("lane", "")) == "action" and (span.text.begins_with("Return") or span.text.begins_with("Stop")):
				lines[span.text] = [str(metadata.get("object_label", "")), str(metadata.get("object_glyph", ""))]
	var return_ace: ACEAction = ACEAction.new()
	return_ace.ace_id = "ReturnValue"
	var raw_return: RawCodeRow = RawCodeRow.new()
	raw_return.code = "return left"
	var raw_call: RawCodeRow = RawCodeRow.new()
	raw_call.code = "returned_count += 1"
	dock.free()
	return SUPPORT.pins(TEST_NAME, [
		["a function's return line names no object and leads with the function icon",
			lines.get("Return left", []), ["", NativeRowMarks.OBJECT_GLYPH_FUNCTION]],
		["a bare return in an event keeps its own reading and object", lines.get("Stop event", []), ["System", ""]],
		["the Core Return action is a return", ViewportRowBuilder.is_function_return(return_ace), true],
		["a return written as code is one", ViewportRowBuilder.is_function_return(raw_return), true],
		["a statement that only starts with the letters is not", ViewportRowBuilder.is_function_return(raw_call), false],
		["a return written with a value hands one back", ViewportRowBuilder.function_returns_value(raw_return), true],
		["a bare return with a comment hands nothing back", ViewportRowBuilder.function_returns_value(_raw("return  # done")), false],
	])


static func _raw(code: String) -> RawCodeRow:
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = code
	return raw


static func _untyped_param() -> ACEParam:
	var param: ACEParam = ACEParam.new()
	param.id = "anything"
	param.type_name = ""
	return param


static func _badge_styles(spans: Array) -> PackedStringArray:
	var styles: PackedStringArray = PackedStringArray()
	for span: Variant in spans:
		var metadata: Dictionary = (span as SemanticSpan).metadata if span is SemanticSpan and (span as SemanticSpan).metadata is Dictionary else {}
		if bool(metadata.get("badge", false)) and str(metadata.get("badge_style", "")) in ["trigger", "negated"]:
			styles.append(str(metadata.get("badge_style", "")))
	return styles
