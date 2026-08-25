@tool
class_name InputWindowPromptTest
extends RefCounted

# The input WINDOW owns the prompt.
#
# Before this, a prompt was a row of its own with no lifetime: something put a key on a label and
# nothing ever took it off, so the label went on asking for a control long after the moment had
# passed. Now opening a window puts the prompt up and closing one takes it down, and the two rows
# that do it are the two rows that already opened and closed the window.
#
# The whole risk of saying that is the promise underneath it: a window authored before prompts
# existed must still write the very bytes it wrote then. The Prompt parameter is therefore optional,
# blank by default, and its slot sits at the very END of both templates - so a blank answer leaves
# the emitted lines untouched. `_promptless_open_is_byte_identical` is that promise, pinned.
#
# The gates, in the order they matter:
#   1. the promptless forms, byte for byte - including a row saved with NO prompt key at all;
#   2. the line the picker composes, and the same line read back into the fields it came from;
#   3. the prompt-carrying forms, byte for byte;
#   4. the grammar, reading the very bytes gate 3 emitted as ONE row;
#   5. the whole path - a file written this way, opened as a sheet, walked row by row and saved
#      back byte-identically.

const SOURCE_PATH := "user://eventforge_input_window_prompt.gd"

## The label an opened window puts the prompt on, and the control it asks for. Written once so the
## expected bytes below and the source that has to reproduce them cannot drift apart.
const LABEL := "$PromptLabel"
const ACTION := "\"dodge\""

## What Open Input Window writes when nobody asked for a prompt - the two lines it has always
## written, quoted here so a change to them fails rather than passes quietly.
const PROMPTLESS_OPEN := "window_open = true\nwindow_until = Time.get_ticks_msec() / 1000.0 + 0.5"

## What Close Input Window writes when nobody asked for a prompt.
const PROMPTLESS_CLOSE := "window_open = false"

## The extra line a prompt adds on the way in: the control's CURRENT binding, asked of the Input Map
## every time, so a rebind moves the prompt with it.
const PROMPT_SHOW_LINE := "$PromptLabel.text = InputMap.action_get_events(\"dodge\")[0].as_text() if not InputMap.action_get_events(\"dodge\").is_empty() else \"\""

## And the line it adds on the way out.
const PROMPT_CLEAR_LINE := "$PromptLabel.text = \"\""

const SOURCE: String = """extends Node2D

var window_open := false
var window_until := 0.0

func open_dodge_window(seconds: float) -> void:
	window_open = true
	window_until = Time.get_ticks_msec() / 1000.0 + seconds
	$PromptLabel.text = InputMap.action_get_events("dodge")[0].as_text() if not InputMap.action_get_events("dodge").is_empty() else ""

func close_dodge_window() -> void:
	window_open = false
	$PromptLabel.text = ""

func answer_the_window(event: InputEvent) -> void:
	if window_open and event.is_action_pressed("dodge"):
		print("good")
"""


static func run() -> bool:
	var ok: bool = true
	ok = _promptless_open_is_byte_identical() and ok
	ok = _the_picker_composes_the_line() and ok
	ok = _the_field_never_shows_code() and ok
	ok = _prompt_carrying_forms() and ok
	ok = _the_grammar_reads_what_was_emitted() and ok
	ok = _the_reverse_index_claims_nothing_new() and ok
	ok = _the_whole_path() and ok
	return ok


## Gate one. The promise the optional parameter rests on: a row that says nothing about a prompt -
## including one SAVED before the parameter existed, which carries no `prompt` key at all - writes
## exactly the bytes it wrote before. Both spellings are pinned, because they reach the emitter by
## different roads: an absent key is filled from the descriptor's blank default, a present-and-empty
## one is substituted as it stands.
static func _promptless_open_is_byte_identical() -> bool:
	var ok: bool = true
	ok = _check("a window row saved before prompts existed still writes its two lines",
		ActionCodegen.generate_action(_action("OpenInputWindow",
			{"open_flag": "window_open", "deadline": "window_until", "seconds": "0.5"})),
		PROMPTLESS_OPEN) and ok
	ok = _check("and so does one that answers the prompt with nothing",
		ActionCodegen.generate_action(_action("OpenInputWindow",
			{"open_flag": "window_open", "deadline": "window_until", "seconds": "0.5",
			"prompt": ""})),
		PROMPTLESS_OPEN) and ok
	ok = _check("a close saved before prompts existed still writes its one line",
		ActionCodegen.generate_action(_action("CloseInputWindow", {"open_flag": "window_open"})),
		PROMPTLESS_CLOSE) and ok
	ok = _check("and so does one that answers the prompt with nothing",
		ActionCodegen.generate_action(_action("CloseInputWindow",
			{"open_flag": "window_open", "prompt": ""})),
		PROMPTLESS_CLOSE) and ok
	return ok


## Gate two. The picker's job is to never show anybody the line: it takes a label and a control and
## composes it. Read back the other way, the same two halves have to come out of it - and out of
## somebody ELSE'S line, nothing at all, so a foreign value cannot be half-parsed into the fields.
static func _the_picker_composes_the_line() -> bool:
	var ok: bool = true
	ok = _check("a label and a control compose the prompt line",
		ACEParamsDialog.input_prompt_show_tail(LABEL, ACTION), "\n%s" % PROMPT_SHOW_LINE) and ok
	ok = _check("a label alone composes the line that takes it back off",
		ACEParamsDialog.input_prompt_clear_tail(LABEL), "\n%s" % PROMPT_CLEAR_LINE) and ok
	ok = _check("no label means no prompt at all",
		ACEParamsDialog.input_prompt_show_tail("  ", ACTION), "") and ok
	ok = _check("and neither does no control",
		ACEParamsDialog.input_prompt_show_tail(LABEL, ""), "") and ok
	var facts: Dictionary = ACEParamsDialog.input_prompt_show_facts("\n%s" % PROMPT_SHOW_LINE)
	ok = _check("the line reads back as the label it was composed from",
		str(facts.get("label", "")), LABEL) and ok
	ok = _check("and as the control it was composed from",
		str(facts.get("action", "")), ACTION) and ok
	ok = _check("a line nobody composed here reads back as nothing",
		ACEParamsDialog.input_prompt_show_facts("\n$Score.text = str(points)").is_empty(), true) and ok
	ok = _check("the clearing line reads back as its label",
		ACEParamsDialog.input_prompt_clear_label("\n%s" % PROMPT_CLEAR_LINE), LABEL) and ok
	ok = _check("and a plain empty-string assignment does not",
		ACEParamsDialog.input_prompt_clear_label("name = \"\""), "") and ok
	return ok


## The promise the two hints exist for: the Prompt parameter's VALUE is a line of GDScript, and the
## person filling the row never sees it. What they get is a tick, a label and a control - and what
## comes back out is the line. Built here for real and read back through the dialog's own value read,
## so a field that quietly turned back into a code box fails rather than ships.
static func _the_field_never_shows_code() -> bool:
	var ok: bool = true
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	var shown: Control = dialog._create_input_prompt_show_field("prompt",
		"\n%s" % PROMPT_SHOW_LINE)
	ok = _check("the label field shows a label, not code",
		(shown.get_meta("input_prompt_label") as LineEdit).text, LABEL) and ok
	ok = _check("the control field shows a control, not code",
		(shown.get_meta("input_prompt_action") as LineEdit).text, ACTION) and ok
	ok = _check("a row that already had a prompt opens with its tick on",
		(shown.get_meta("input_prompt_toggle") as CheckBox).button_pressed, true) and ok
	ok = _check("and reads back as the very line it was opened with",
		str(dialog._extract_value(shown)), "\n%s" % PROMPT_SHOW_LINE) and ok
	(shown.get_meta("input_prompt_toggle") as CheckBox).button_pressed = false
	ok = _check("untick it and the row goes back to writing nothing",
		str(dialog._extract_value(shown)), "") and ok
	var cleared: Control = dialog._create_input_prompt_clear_field("prompt", "")
	ok = _check("a fresh close row asks for no prompt at all",
		str(dialog._extract_value(cleared)), "") and ok
	(cleared.get_meta("input_prompt_toggle") as CheckBox).button_pressed = true
	ok = _check("ticked on, it writes the line that takes the prompt down",
		str(dialog._extract_value(cleared)), "\n%s" % PROMPT_CLEAR_LINE) and ok
	shown.free()
	cleared.free()
	return ok


## Gate three. With a prompt chosen, the open is THREE lines and the close is TWO - no more, and the
## prompt line is the last of each, which is what keeps the promise in gate one available.
static func _prompt_carrying_forms() -> bool:
	var ok: bool = true
	var open_code: String = ActionCodegen.generate_action(_action("OpenInputWindow",
		{"open_flag": "window_open", "deadline": "window_until", "seconds": "0.5",
		"prompt": ACEParamsDialog.input_prompt_show_tail(LABEL, ACTION)}))
	ok = _check("an opened window with a prompt writes three lines",
		open_code, "%s\n%s" % [PROMPTLESS_OPEN, PROMPT_SHOW_LINE]) and ok
	ok = _check("three lines and no more", open_code.split("\n").size(), 3) and ok
	var close_code: String = ActionCodegen.generate_action(_action("CloseInputWindow",
		{"open_flag": "window_open",
		"prompt": ACEParamsDialog.input_prompt_clear_tail(LABEL)}))
	ok = _check("a closed window with a prompt writes two lines",
		close_code, "%s\n%s" % [PROMPTLESS_CLOSE, PROMPT_CLEAR_LINE]) and ok
	ok = _check("two lines and no more", close_code.split("\n").size(), 2) and ok
	return ok


## Gate four. The two-way gate: the grammar is handed the very bytes gate three emitted, split back
## into lines, and has to read them as ONE row. Nothing here is a hand-typed copy of what the
## emitter writes - it IS what the emitter wrote, so the picker and the reader cannot drift.
static func _the_grammar_reads_what_was_emitted() -> bool:
	var ok: bool = true
	var context: Dictionary = {
		"self_object": "Player", "script_object": "Player", "self_class": "Node2D",
		"input_window": {"flag": "window_open", "deadline": "window_until",
			"action": ACTION, "perfect": ""}
	}
	var open_lines: PackedStringArray = ActionCodegen.generate_action(_action("OpenInputWindow",
		{"open_flag": "window_open", "deadline": "window_until", "seconds": "seconds",
		"prompt": ACEParamsDialog.input_prompt_show_tail(LABEL, ACTION)})).split("\n")
	var opened: Dictionary = EventSheetSentence.input_window_parts(open_lines[0], open_lines[1],
		context, open_lines[2])
	ok = _check("the three emitted lines read as one opened window",
		str(opened.get("text", "")), "Open input window \"dodge\" for seconds") and ok
	ok = _check("and the row says where the prompt went and which clock it is on",
		str(opened.get("note", "")),
		"prompt on $PromptLabel · on the engine clock, which keeps running while paused") and ok
	ok = _check("the label is named as the prompt's own fact",
		str(opened.get("prompt", "")), LABEL) and ok
	# The same two lines with no prompt beneath them stay the two-line row they always were.
	ok = _check("a promptless window reads exactly as it did before",
		str(EventSheetSentence.input_window_parts(open_lines[0], open_lines[1], context)
			.get("note", "")), "on the engine clock, which keeps running while paused") and ok
	# A third line that is somebody else's is not swallowed: the window is still read, unprompted.
	ok = _check("a line the window did not write is not read as its prompt",
		str(EventSheetSentence.input_window_parts(open_lines[0], open_lines[1], context,
			"hp = 100").get("prompt", "")), "") and ok
	var close_lines: PackedStringArray = ActionCodegen.generate_action(_action("CloseInputWindow",
		{"open_flag": "window_open",
		"prompt": ACEParamsDialog.input_prompt_clear_tail(LABEL)})).split("\n")
	var closed: Dictionary = EventSheetSentence.input_window_close_parts(close_lines[0],
		close_lines[1], context)
	ok = _check("the two emitted lines read as one closed window",
		str(closed.get("text", "")), "Close input window") and ok
	ok = _check("and the row says which label the prompt came off",
		str(closed.get("note", "")), "prompt taken off $PromptLabel") and ok
	ok = _check("a flag going false with an unrelated line beneath it is NOT a closed window",
		EventSheetSentence.input_window_close_parts(close_lines[0], "hp = 100", context).is_empty(),
		true) and ok
	return ok


## The documented reverse-lift shadow trap, answered by value. A trailing slot that can swallow
## anything is exactly the shape that hijacks every line in every project once it is admitted to the
## index that reads lines BACK. Neither window row is in that index: the open's template spans two
## lines, which no single line can match, and the close is named in the exclusion list. Pinned here
## so admitting either one later has to argue with a test rather than slip through.
static func _the_reverse_index_claims_nothing_new() -> bool:
	var ok: bool = true
	ok = _check("the close row is kept out of the reverse index by name",
		EventSheetACELifter.REVERSE_LIFT_EXCLUDED_ACE_IDS.has("CloseInputWindow"), true) and ok
	var open_template: String = ""
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		if descriptor.ace_id == "OpenInputWindow":
			open_template = descriptor.codegen_template
	ok = _check("the open row's template spans two lines, which no single line can match",
		open_template.contains("\n"), true) and ok
	ok = _check("and its Prompt slot is the very last thing in it",
		open_template.ends_with("{prompt}"), true) and ok
	ok = _check("so is the close row's",
		"{open_flag} = false{prompt}".ends_with("{prompt}"), true) and ok
	return ok


## Gate five. A file written the way these rows write it, opened as a sheet: the window reads as one
## row with its prompt named, the close reads as one row, and saving it untouched puts back every
## byte - the promise every reading in this plugin rests on.
static func _the_whole_path() -> bool:
	var ok: bool = true
	var handle: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()
	var facts: Dictionary = EventSheetPatternReadings.input_window_facts(SOURCE.split("\n"))
	ok = _check("the file's own facts name the flag", str(facts.get("flag", "")), "window_open") and ok
	ok = _check("the deadline beside it", str(facts.get("deadline", "")), "window_until") and ok
	ok = _check("the control it waits for", str(facts.get("action", "")), ACTION) and ok
	ok = _check("and the label its prompt goes on", str(facts.get("prompt", "")), LABEL) and ok
	var readings: PackedStringArray = _readings()
	ok = _check("the opened window reads as one row",
		readings.has("System ▸ Open input window \"dodge\" for seconds"), true) and ok
	ok = _check("the closed window reads as one row",
		readings.has("System ▸ Close input window"), true) and ok
	ok = _check("the prompt line is not left standing beside them",
		readings.has("Player ▸ Set $PromptLabel text to \"\""), false) and ok
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	ok = _check("opening the file and saving it reproduces every byte",
		str(SheetCompiler.compile(sheet, SOURCE_PATH).get("output", "")), SOURCE) and ok
	return ok


## Every cell reading in the opened file, as "object ▸ text".
static func _readings() -> PackedStringArray:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	var readings: PackedStringArray = PackedStringArray()
	for row_data: EventRowData in _walk(viewport._root_rows, viewport):
		for span: SemanticSpan in row_data.spans:
			var object_label: String = str(span.metadata.get("object_label", ""))
			var text: String = span.text.strip_edges()
			readings.append("%s ▸ %s" % [object_label, text] if not object_label.is_empty() else text)
	viewport.free()
	return readings


## Every row in the tree, parents before children.
static func _walk(rows: Array, viewport: EventSheetViewport) -> Array:
	var found: Array = []
	for row_data: EventRowData in rows:
		viewport._row_builder._ensure_event_spans(row_data)
		found.append(row_data)
		found.append_array(_walk(row_data.children, viewport))
	return found


## One authored action row, exactly as the dialog commits it: an ace id and the values typed into
## its fields, with nothing filled in that the author did not answer.
static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	action.enabled = true
	return action


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] input_window_prompt_test: %s" % label)
		return true
	print("[FAIL] input_window_prompt_test: %s - expected %s, got %s" % [label, expected, actual])
	return false
