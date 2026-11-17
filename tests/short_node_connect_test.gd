# Godot EventSheets - a handler placed now on a plain node path connects the way a person types it.
#
# `get_node("RedCard").body_entered.connect(...)` becomes `$RedCard.body_entered.connect(...)` for a
# handler placed now (`connect_short`). A handler saved before keeps `get_node("...")`, a path that is not
# plain names joined by slashes keeps it too, and a handler read from a file keeps the connect line it was
# written with. Every spelling opens and saves back byte for byte.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "short_node_connect_test"


static func run() -> bool:
	var ok: bool = true
	ok = SUPPORT.check(P, "a handler can say: connect with $Name", "connect_short" in EventRow.new(), true) and ok
	if not ("connect_short" in EventRow.new()):
		return false
	var sheet: EventSheetResource = EventSheets.new_sheet()
	var handler: EventRow = EventRow.new()
	handler.trigger_provider_id = "Core"
	handler.trigger_id = "OnBodyEntered"
	handler.trigger_source_path = "RedCard"
	var print_line: RawCodeRow = RawCodeRow.new()
	print_line.code = "print(\"key\")"
	handler.actions.append(print_line)
	sheet.events.append(handler)
	ok = SUPPORT.check(P, "a handler saved before keeps get_node", _text(sheet).contains("\tget_node(\"RedCard\").body_entered.connect("), true) and ok
	handler.connect_short = true
	ok = SUPPORT.check(P, "a new handler connects with $Name", _text(sheet).contains("\t$RedCard.body_entered.connect("), true) and ok
	handler.trigger_source_path = "Hud/Tally"
	ok = SUPPORT.check(P, "a path of names and slashes is spelled with $", _text(sheet).contains("\t$Hud/Tally.body_entered.connect("), true) and ok
	for path: String in ["Hud Tally", "../Door", "%Door", "Hud/Tally 2", "1Door"]:
		handler.trigger_source_path = path
		ok = SUPPORT.check(P, "%s keeps get_node" % path, _text(sheet).contains("get_node(\"%s\").body_entered.connect(" % path), true) and ok
	# Two events sharing one handler: one of them without the flag keeps the long spelling for both.
	handler.trigger_source_path = "RedCard"
	var second: EventRow = EventRow.new()
	second.trigger_provider_id = "Core"
	second.trigger_id = "OnBodyEntered"
	second.trigger_source_path = "RedCard"
	second.actions.append(print_line.duplicate())
	sheet.events.append(second)
	ok = SUPPORT.check(P, "one event without the flag keeps the shared connect line long", _text(sheet).contains("get_node(\"RedCard\").body_entered.connect("), true) and ok
	second.connect_short = true
	ok = SUPPORT.check(P, "both events with the flag share the short connect line", _text(sheet).contains("\t$RedCard.body_entered.connect("), true) and ok
	# What a file already has opens and saves back byte for byte: the showcase that ships the long spelling,
	# a hand-written short one, and the text a new handler writes.
	ok = SUPPORT.check(P, "the shipped file with get_node connects saves back byte for byte", EventSheets.round_trips(FileAccess.get_file_as_string("res://demo/showcase/boomer_level/boomer_level.gd")), true) and ok
	var written: String = _text(sheet)
	ok = SUPPORT.check(P, "a file with the short connect line saves back byte for byte", EventSheets.round_trips(written), true) and ok
	ok = SUPPORT.check(P, "and keeps its short connect line", SUPPORT.reemit(written, SUPPORT.own_path("short_connect.gd")).contains("\t$RedCard.body_entered.connect("), true) and ok
	return ok


static func _text(sheet: EventSheetResource) -> String:
	return str(EventSheets.echo(sheet).get("output", ""))
