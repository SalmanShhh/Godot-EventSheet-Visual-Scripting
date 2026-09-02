# The Timeline block: a schedule as rows ("at 0s show Ready, at 1s show GO") compiling to the
# await-chain a GDScript author would write - steps in order, one create_timer await per FORWARD
# gap, equal times back to back. The renderer shows a muted caption on the event plus one
# condition/action child row per beat ("at 1s" left, the action right).
@tool
class_name TimelineBlockTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = true

	# ── Emission: gaps await, equal times run together, order is the schedule ──
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	event.trigger_id = "OnReady"
	event.trigger_provider_id = "Core"
	var timeline: TimelineRow = EventSheets.timeline([
		[0.0, "show_message(\"Ready...\")"],
		[1.0, "show_message(\"GO!\")"],
		[1.0, "flash_screen()"],
		[1.2, "start_round()"],
	])
	ok = _check("the API builds a timeline", timeline != null, true) and ok
	ok = _check("steps stay time-sorted", timeline.steps.size(), 4) and ok
	event.actions.append(timeline)
	sheet.events.append(event)
	var output: String = str(SheetCompiler.compile(sheet, "user://timeline_out.gd").get("output", ""))
	ok = _check("first beat runs immediately (no await before 0.0)", output.contains("show_message(\"Ready...\")"), true) and ok
	ok = _check("the 1.0s gap awaits", output.contains("await get_tree().create_timer(1.0).timeout"), true) and ok
	ok = _check("equal times do not await between each other", output.count("await get_tree().create_timer"), 2) and ok
	ok = _check("the trailing 0.2s gap awaits", output.contains("await get_tree().create_timer(0.2).timeout"), true) and ok
	var go_at: int = output.find("show_message(\"GO!\")")
	var flash_at: int = output.find("flash_screen()")
	var round_at: int = output.find("start_round()")
	ok = _check("schedule order is preserved", go_at >= 0 and go_at < flash_at and flash_at < round_at, true) and ok
	var second: String = str(SheetCompiler.compile(sheet, "user://timeline_out.gd").get("output", ""))
	ok = _check("emission is deterministic", second == output, true) and ok

	# A malformed step list refuses cleanly.
	ok = _check("a malformed pair returns null", EventSheets.timeline([[0.0]]), null) and ok

	# ── Renderer: caption on the event, one child row per beat in condition/action grammar ──
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	var builder: ViewportRowBuilder = viewport._row_builder
	var row_data: EventRowData = builder._build_event_row(event, 0)
	ok = _check("one child row per beat", row_data.children.size(), 4) and ok
	if row_data.children.size() == 4:
		ok = _check("the beat's WHEN is the condition cell", row_data.children[1].spans[0].text, "at 1.0s") and ok
		ok = _check("the beat's WHAT reads in plain words", row_data.children[0].spans[1].text.contains("Show Message"), true) and ok
	var caption_found: bool = false
	for span: SemanticSpan in builder._build_event_spans(event):
		if span.text.contains("timeline · 4"):
			caption_found = true
	ok = _check("the event lane carries the muted caption", caption_found, true) and ok
	viewport.free()

	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("timeline_block_test", label, actual, expected)
