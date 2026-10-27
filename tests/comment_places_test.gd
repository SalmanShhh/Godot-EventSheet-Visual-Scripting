# EventForge - every place a comment can sit on the sheet, and the line it writes
#
# A comment row between events is written right above the event it sits over, at that event's indent,
# and opening the file reads it back as the same row (it used to land at the end of the file, a blank
# line before every line, its `##` lost). A comment inside a group goes under the group's tag. An
# action's note is the comment at the end of its own code line, both ways. A condition takes no note,
# and a comment written after an `if` in opened code stays exactly as written. A plain var keeps every
# line of its `##` description. A comment inside a match case keeps its marker and its off state. The
# colour a comment wears is the sheet's only: it never reaches the code.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const NAME := "comment_places_test"
const SAVED_AT := "user://comment_places_test.gd"


static func run() -> bool:
	var ok: bool = _sheet_comments_sit_over_their_event()
	ok = _opened_comments_read_back_as_rows() and ok
	ok = _action_notes_ride_their_line() and ok
	ok = _plain_var_keeps_every_description_line() and ok
	ok = _match_case_comment_keeps_marker_and_off() and ok
	ok = _colour_stays_on_the_sheet() and ok
	ok = _comments_keep_their_place_in_an_opened_file() and ok
	return ok


## In an opened file whose handler sits in the middle of it: a comment row added under the handler's last
## event is written at the end of that handler, and one over a variable is written right above it.
static func _comments_keep_their_place_in_an_opened_file() -> bool:
	var sheet: EventSheetResource = SUPPORT.reopen("
".join([
		"extends CharacterBody2D",
		"",
		"var coins := 0",
		"",
		"",
		"func _physics_process(delta: float) -> void:",
		"	if not is_on_floor():",
		"		velocity.y += 980.0 * delta",
		"	move_and_slide()",
		"",
		"",
		"## @ace_group(name=\"Coins\")",
		"func add_coin(amount: int = 1) -> void:",
		"	# Coins go to the tally.",
		"	coins += amount",
		""]))
	sheet.external_source_path = SAVED_AT
	var last_event: int = -1
	var variable: int = -1
	for index: int in range(sheet.events.size()):
		if sheet.events[index] is EventRow:
			last_event = index
		elif sheet.events[index] is LocalVariable:
			variable = index
	sheet.events.insert(last_event + 1, _comment("Then the state."))
	sheet.events.insert(variable, _comment("Coins: the tally."))
	var written: String = SUPPORT.compile_output(sheet, SAVED_AT)
	return SUPPORT.pins(NAME, [
		["a comment under a handler's last event ends that handler", written.contains("	move_and_slide()
	# Then the state.
"), true],
		["a comment over a variable is written right above it", written.contains("
# Coins: the tally.
var coins := 0
"), true],
		["and the file saves byte for byte", SUPPORT.reemit(written, SAVED_AT), written],
	])


static func _print_action(said: String, note: String = "") -> ACEAction:
	var say: ACEAction = ACEAction.new()
	say.provider_id = "Core"
	say.ace_id = "Print"
	say.codegen_template = "print({value})"
	say.params = {"value": "\"%s\"" % said}
	say.comment = note
	return say


static func _event(trigger: String, said: String, note: String = "") -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = trigger
	row.actions.append(_print_action(said, note))
	return row


static func _comment(text: String, marker: String = "", on: bool = true) -> CommentRow:
	var comment: CommentRow = CommentRow.new()
	comment.text = text
	comment.source_marker = marker
	comment.enabled = on
	return comment


## The sheet the board draws, as rows: a comment between events, a coloured two-line one, a group
## holding a manual paragraph and a switched-off note, and one comment with nothing below it. The events
## are an opened file's (each an `if`), so the rows are placed the way a sheet places them.
static func _authored_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = SUPPORT.reopen("\n".join([
		"extends Node",
		"",
		"var speed := 1.0",
		"",
		"",
		"func _process(_delta: float) -> void:",
		"\tif speed > 0.0:",
		"\t\tprint(\"walk\")",
		"\tif speed > 1.0:",
		"\t\tprint(\"jump\")",
		"\tif speed > 3.0:",
		"\t\tprint(\"coin\")",
		"",
		"",
		"func _ready() -> void:",
		"\tif speed > 2.0:",
		"\t\tprint(\"ready\")",
		""]))
	sheet.external_source_path = SAVED_AT
	var events: Array = []
	var others: Array = []
	for entry: Variant in sheet.events:
		(events if entry is EventRow else others).append(entry)
	var coloured: CommentRow = _comment("Jump: hold the button for a higher jump.\nCoyote time lives in the Jump behaviour.")
	coloured.color_tag = "orange"
	var group: EventGroup = EventGroup.new()
	group.name = "Coins"
	group.group_name = "Coins"
	group.group_uid = "coins"
	group.events.append(_comment("Coins: touching one adds it to the total.", CommentRow.DOC_MARKER))
	group.events.append(events[2])
	group.events.append(_comment("Old idea: double the coins on a combo.", "", false))
	group.events.append(events[3])
	sheet.events.clear()
	sheet.events.append_array(others)
	sheet.events.append_array([_comment("[b]Movement[/b] - the player walks and jumps."), events[0], coloured, events[1], group,
		_comment("Last words.")])
	return sheet


static func _sheet_comments_sit_over_their_event() -> bool:
	var written: String = SUPPORT.compile_output(_authored_sheet(), SAVED_AT)
	var body: String = written.substr(written.find("func _process("))
	return SUPPORT.pins(NAME, [
		["a comment between events is written right above its event, at its indent, marker and all", body, "\n".join([
			"func _process(_delta: float) -> void:",
			"\t# [b]Movement[/b] - the player walks and jumps.",
			"\tif speed > 0.0:",
			"\t\tprint(\"walk\")",
			"\t# Jump: hold the button for a higher jump.",
			"\t# Coyote time lives in the Jump behaviour.",
			"\tif speed > 1.0:",
			"\t\tprint(\"jump\")",
			"\t# @group:coins",
			"\t## Coins: touching one adds it to the total.",
			"\tif speed > 3.0:",
			"\t\tprint(\"coin\")",
			"",
			"",
			"func _ready() -> void:",
			"\t# @group:coins",
			"\t# @off: Old idea: double the coins on a combo.",
			"\tif speed > 2.0:",
			"\t\tprint(\"ready\")",
			"",
			"# Last words.",
			""])],
		["the file reopens and saves byte for byte", SUPPORT.reemit(written, SAVED_AT), written],
		["and the comments come back as the rows they were, in their places", _shape(SUPPORT.reopen(written).events), [
			"comment: [b]Movement[/b] - the player walks and jumps.", "event", "comment: Jump: hold the button for a higher jump.\nCoyote time lives in the Jump behaviour.",
			"event", ["comment: Coins: touching one adds it to the total.", "event", "comment(off): Old idea: double the coins on a combo.",
			"event"], "comment: Last words."]],
	])


## A hand-written handler: a note written right above an `if` reads back as a comment row above that
## event, and an `if` with a comment after it stays exactly as written.
static func _opened_comments_read_back_as_rows() -> bool:
	var source: String = "\n".join([
		"extends Node",
		"",
		"var speed := 1.0",
		"",
		"",
		"func _process(_delta: float) -> void:",
		"\tprint(\"tick\")",
		"\t# Jump: press the button while on the floor.",
		"\t# Coyote time lets a late press still count.",
		"\tif speed > 0.0:",
		"\t\tprint(\"jump\")",
		"",
		"\t# Crouch - hold down to squash the sprite.",
		"\tif speed > 1.0:  # crouch only on the ground",
		"\t\tprint(\"crouch\")",
		""])
	var opened: EventSheetResource = SUPPORT.reopen(source)
	return SUPPORT.pins(NAME, [
		["the note above the if is a comment row above its event", _shape(opened.events).slice(-4, -1), [
			"event", "comment: Jump: press the button while on the floor.\nCoyote time lets a late press still count.", "event"]],
		["the if with a comment after it is kept as written", source.contains("\tif speed > 1.0:  # crouch only on the ground")
			and SUPPORT.reemit(source, SAVED_AT) == source, true],
		["the file saves byte for byte", SUPPORT.reemit(source, SAVED_AT), source],
	])


static func _action_notes_ride_their_line() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.external_source_path = SAVED_AT
	sheet.events.append(_event("OnReady", "blip", "short blip"))
	var written: String = SUPPORT.compile_output(sheet, SAVED_AT)
	var hand_written: String = "\n".join([
		"extends Node2D",
		"",
		"",
		"func _ready() -> void:",
		"\tprint(\"one\")  # short blip",
		"\tprint(\"# not a note\")",
		"\tprint(\"two\")  # a note with \"quotes\" in it",
		""])
	var opened: EventSheetResource = SUPPORT.reopen(hand_written)
	var notes: Array = []
	for entry: Variant in opened.events:
		if entry is EventRow:
			for action: Variant in (entry as EventRow).actions:
				notes.append((action as ACEAction).comment if action is ACEAction else str(action))
	return SUPPORT.pins(NAME, [
		["an action's note is the comment at the end of its own line", written.contains("\tprint(\"blip\")  # short blip\n"), true],
		["it reopens as that action with that note", _first_action_note(SUPPORT.reopen(written)), "short blip"],
		["a note written by hand reads back onto its action; a # in a string is no note", notes,
			["short blip", "", "a note with \"quotes\" in it"]],
		["and the file saves byte for byte", SUPPORT.reemit(hand_written, SAVED_AT), hand_written],
	])


static func _plain_var_keeps_every_description_line() -> bool:
	var source: String = "\n".join([
		"extends Node",
		"",
		"## Coins picked up this run.",
		"## Kept on a plain var too.",
		"var coins := 0",
		""])
	var opened: EventSheetResource = SUPPORT.reopen(source)
	var coins: LocalVariable = null
	for entry: Variant in opened.events:
		if entry is LocalVariable:
			coins = entry
	var authored: LocalVariable = LocalVariable.new()
	authored.name = "lives"
	authored.type_name = "int"
	authored.default_value = 3
	authored.description = "Lives left.\nThe last one is the hardest."
	return SUPPORT.pins(NAME, [
		["a plain var's ## lines are its description, every line", coins.attributes.get("tooltip", "") if coins != null else null,
			"Coins picked up this run.\nKept on a plain var too."],
		["the file saves byte for byte", SUPPORT.reemit(source, SAVED_AT), source],
		["a description typed on a plain var is written as its ## lines", SheetCompiler._emit_tree_variable_line(authored),
			"## Lives left.\n## The last one is the hardest.\nvar lives: int = 3"],
	])


static func _match_case_comment_keeps_marker_and_off() -> bool:
	var case_on: MatchCase = MatchCase.new()
	case_on.pattern = "0"
	case_on.events = [_comment("Shows in the manual.", CommentRow.DOC_MARKER), _print_action("zero")]
	var case_off: MatchCase = MatchCase.new()
	case_off.pattern = "_"
	case_off.events = [_comment("Old idea.", "", false), _print_action("other")]
	var match_row: MatchRow = MatchRow.new()
	match_row.match_expression = "state"
	match_row.cases = [case_on, case_off]
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.actions.append(match_row)
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.external_source_path = SAVED_AT
	var state: LocalVariable = LocalVariable.new()
	state.name = "state"
	state.type_name = "int"
	state.default_value = 0
	sheet.events.append(state)
	sheet.events.append(event)
	var written: String = SUPPORT.compile_output(sheet, SAVED_AT)
	return SUPPORT.pins(NAME, [
		["a manual paragraph in a case keeps its ##", written.contains("\t\t\t## Shows in the manual.\n"), true],
		["a switched-off comment in a case is written off", written.contains("\t\t\t# @off: Old idea.\n"), true],
	])


static func _colour_stays_on_the_sheet() -> bool:
	var plain: String = SUPPORT.compile_output(_authored_sheet(), SAVED_AT)
	var painted: EventSheetResource = _authored_sheet()
	for entry: Variant in painted.events:
		if entry is CommentRow:
			(entry as CommentRow).color_tag = "purple"
			(entry as CommentRow).custom_color = Color(0.2, 0.4, 0.6)
	var style: EventSheetEventStyle = EventSheetEventStyle.new()
	return SUPPORT.pins(NAME, [
		["a comment's colour is never written to the code", SUPPORT.compile_output(painted, SAVED_AT), plain],
		["and reopening shows the default colour", _first_comment_tag(SUPPORT.reopen(plain)), ""],
		["a named colour is the theme's comment colour turned to that hue",
			[style.comment_tag_color("") == style.comment_row_background_color,
				style.comment_tag_color("red") != style.comment_tag_color("blue"),
				style.comment_tag_color("grey").s], [true, true, 0.0]],
	])


## The rows of `rows` as words: a comment as `comment: <text>` (`comment(off)` when off), an event as
## `event`, a group as the list of its own rows.
static func _shape(rows: Array) -> Array:
	var out: Array = []
	for entry: Variant in rows:
		if entry is CommentRow:
			out.append("comment%s: %s" % ["" if (entry as CommentRow).enabled else "(off)", (entry as CommentRow).text])
		elif entry is EventRow:
			out.append("event")
		elif entry is EventGroup:
			out.append(_shape((entry as EventGroup).child_rows()))
	return out


static func _first_action_note(sheet: EventSheetResource) -> String:
	for entry: Variant in sheet.events:
		if entry is EventRow and not (entry as EventRow).actions.is_empty() and (entry as EventRow).actions[0] is ACEAction:
			return ((entry as EventRow).actions[0] as ACEAction).comment
	return "<none>"


static func _first_comment_tag(sheet: EventSheetResource) -> String:
	for entry: Variant in sheet.events:
		if entry is CommentRow:
			return (entry as CommentRow).color_tag
	return "<none>"
