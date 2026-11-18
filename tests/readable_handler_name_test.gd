# Godot EventSheets - a handler placed now on a node path is named for the path alone.
#
# A signal source written as a path (`$Services/Settings`) used to name its handler with a short number
# after the path (`_on_services_settings_1184_setting_changed`), there so two paths that spell the same
# letters (`A/B` and `A_B`) never share a function. A handler placed now (`readable_handler_name`) leaves
# the number off, the way a person would write it, and gives it back only to the later of two handlers whose
# plain names would meet. A handler saved before keeps the number it was named with, and a file already
# written either way opens and saves back byte for byte.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "readable_handler_name_test"


static func run() -> bool:
	var ok: bool = SUPPORT.check(P, "a handler can say it is named for its path alone", "readable_handler_name" in EventRow.new(), true)
	if not ("readable_handler_name" in EventRow.new()):
		return false
	var sheet: EventSheetResource = EventSheets.new_sheet()
	var handler: EventRow = _handler("Services/Settings")
	sheet.events.append(handler)
	var saved_before: String = _text(sheet)
	ok = SUPPORT.check(P, "a handler saved before keeps the number in its name",
		saved_before.contains("func _on_services_settings_1184_setting_changed("), true) and ok
	handler.readable_handler_name = true
	var placed_now: String = _text(sheet)
	ok = SUPPORT.check(P, "a handler placed now is named for the path alone",
		placed_now.contains("func _on_services_settings_setting_changed(") and placed_now.contains(".connect(_on_services_settings_setting_changed)"), true) and ok
	ok = SUPPORT.check(P, "and writes no number anywhere", placed_now.contains("1184"), false) and ok
	# What a file already has opens and saves back byte for byte, in either spelling.
	ok = SUPPORT.check(P, "a file with the numbered name saves back byte for byte", EventSheets.round_trips(saved_before), true) and ok
	ok = SUPPORT.check(P, "a file with the plain name saves back byte for byte", EventSheets.round_trips(placed_now), true) and ok
	var reopened_numbered: EventSheetResource = SUPPORT.reopen(saved_before, true, "")
	var reopened_plain: EventSheetResource = SUPPORT.reopen(placed_now, true, "")
	ok = SUPPORT.check(P, "the numbered file opens as a handler that keeps its number",
		_first_handler(reopened_numbered).readable_handler_name if _first_handler(reopened_numbered) != null else null, false) and ok
	ok = SUPPORT.check(P, "the plain file opens as a handler named for its path",
		_first_handler(reopened_plain).readable_handler_name if _first_handler(reopened_plain) != null else null, true) and ok
	ok = SUPPORT.check(P, "the plain file opens with its handler lifted as an event, not left as code",
		_first_handler(reopened_plain) != null, true) and ok
	# Two paths whose plain names meet are two functions, not one.
	var twins: EventSheetResource = EventSheets.new_sheet()
	for source: String in ["Hud/Tally", "Hud_Tally"]:
		var twin: EventRow = _handler(source)
		twin.readable_handler_name = true
		twins.events.append(twin)
	var twin_text: String = _text(twins)
	ok = SUPPORT.check(P, "the first of two paths that meet keeps the plain name",
		twin_text.contains("func _on_hud_tally_setting_changed("), true) and ok
	ok = SUPPORT.check(P, "the later one takes the number back so the two never share a function",
		twin_text.count("func _on_hud_tally_"), 2) and ok
	ok = SUPPORT.check(P, "and the text still reads back byte for byte", EventSheets.round_trips(twin_text), true) and ok
	# The shipped example that was written with the numbers is still the file it was.
	ok = SUPPORT.check(P, "the options example's handlers carry no number",
		FileAccess.get_file_as_string("res://demo/showcase/options_and_quick_save/options_and_quick_save.gd").contains("_on_services_settings_setting_changed"), true) and ok
	return ok


static func _handler(source: String) -> EventRow:
	var handler: EventRow = EventRow.new()
	handler.trigger_provider_id = ""
	handler.trigger_id = "signal:setting_changed"
	handler.trigger_args = "name: String"
	handler.trigger_source_path = source
	var line: RawCodeRow = RawCodeRow.new()
	line.code = "print(name)"
	handler.actions.append(line)
	return handler


static func _first_handler(sheet: EventSheetResource) -> EventRow:
	if sheet == null:
		return null
	for entry: Variant in sheet.events:
		if entry is EventRow and not (entry as EventRow).trigger_source_path.is_empty():
			return entry as EventRow
	return null


static func _text(sheet: EventSheetResource) -> String:
	return str(EventSheets.echo(sheet).get("output", ""))
