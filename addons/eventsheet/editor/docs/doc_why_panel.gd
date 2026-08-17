# Godot EventSheets - "Why didn't this fire?" (the live condition explainer)
#
# The compiler folds a row's conditions into one joined `if`, so at runtime nobody knows which
# half of the AND said no. This panel answers that for ONE row the reader right-clicked: each
# condition, its verdict, and the value it was tested against - read from the values the Live
# Values stream is already carrying, never from a guess.
#
# The rules it obeys:
#   - It is a PANEL, not an annotation. The sheet is untouched: no verdict text is written into
#     any cell, no mode is left on, and closing the window leaves nothing behind.
#   - It never invents a verdict. A condition whose expression cannot be evaluated from the
#     streamed variables (it calls into the node - `is_on_floor()`, a behaviour's state) is
#     reported as "not observable from here", and with no running game the panel says so in one
#     plain line instead of showing a table of confident nonsense.
#
# Loaded by path from the dock's row menu; the assembly half (`build_report`) is static and pure,
# so the suite can drive the real explanation without an editor or a debug session.
@tool
class_name EventSheetWhyPanel
extends RefCounted

## Verdicts a condition can carry. TRUE/FALSE come from a real evaluation; UNKNOWN means the
## expression reached past the streamed values (a node call, a member) and was NOT guessed.
const VERDICT_TRUE := "T"
const VERDICT_FALSE := "F"
const VERDICT_UNKNOWN := "?"

## What the panel says when there is nothing to explain from. Stated once so the window, the
## status line and the test all quote the same sentence.
const NO_SESSION_LINE := "No live values yet. Turn on Tools > Live Values (and Tools > Event Trace for the counts), recompile, and run the game - then ask again."


## THE assembly: one event row plus the latest streamed values -> everything the panel shows.
## Returns {streaming, headline, verdict_line, blocker_index, conditions: [{label, expression,
## verdict, seen, note}]}. Pure and static - no editor, no session, no drawing.
static func build_report(event_row: EventRow, values: Dictionary, streaming: bool = true) -> Dictionary:
	var report: Dictionary = {
		"streaming": streaming and not values.is_empty(),
		"headline": "",
		"verdict_line": "",
		"blocker_index": -1,
		"conditions": [],
	}
	if event_row == null:
		report["headline"] = "No event row."
		return report
	report["headline"] = _headline_for(event_row)
	if not bool(report["streaming"]):
		report["verdict_line"] = NO_SESSION_LINE
		# The conditions are still listed - reading WHICH conditions gate a row is useful with the
		# game stopped, and an empty panel would look broken. They simply carry no verdict.
		for condition: ACECondition in event_row.conditions:
			(report["conditions"] as Array).append(_condition_entry(condition, {}, false))
		return report
	var false_count: int = 0
	var unknown_count: int = 0
	for condition: ACECondition in event_row.conditions:
		var entry: Dictionary = _condition_entry(condition, values, true)
		(report["conditions"] as Array).append(entry)
		if str(entry["verdict"]) == VERDICT_FALSE:
			false_count += 1
			if int(report["blocker_index"]) < 0:
				report["blocker_index"] = (report["conditions"] as Array).size() - 1
		elif str(entry["verdict"]) == VERDICT_UNKNOWN:
			unknown_count += 1
	report["verdict_line"] = _verdict_line(event_row, (report["conditions"] as Array).size(), false_count, unknown_count)
	return report


## The row named the way the reader names it, plus what kind of gate it is. A trigger row that
## never arrived is a different problem from a condition that rejected it, and the panel has to
## keep those two apart or it answers the wrong question.
static func _headline_for(event_row: EventRow) -> String:
	if event_row.conditions.is_empty():
		if not event_row.trigger_id.strip_edges().is_empty():
			return "This row is a trigger with no conditions: if it did not run, the trigger never arrived."
		return "This row has no conditions - there is nothing here that could say no."
	if not event_row.trigger_id.strip_edges().is_empty():
		return "A trigger plus %d condition(s): the trigger has to arrive AND every condition has to be true." % event_row.conditions.size()
	if event_row.condition_mode == EventRow.ConditionMode.OR:
		return "An OR block of %d condition(s): any ONE of them being true runs the row." % event_row.conditions.size()
	return "%d condition(s), all of which have to be true at once." % event_row.conditions.size()


## The one-line answer, written the way the question was asked.
static func _verdict_line(event_row: EventRow, total: int, false_count: int, unknown_count: int) -> String:
	if total == 0:
		return "Nothing to evaluate."
	if event_row.condition_mode == EventRow.ConditionMode.OR:
		if false_count == total:
			return "Every branch of the OR is false right now - that is why it did not run."
		return "At least one branch of the OR is true right now."
	if false_count == 0 and unknown_count == 0:
		return "Every condition is true right now: if the row still did not run, look at its trigger or an enclosing group."
	if false_count == 0:
		return "Nothing observable said no, but %d condition(s) could not be read from here (see the notes)." % unknown_count
	if false_count == 1:
		return "One condition said no - it is marked below."
	return "%d conditions said no - the first is marked below." % false_count


## One condition -> its row in the table. `evaluate` false = list it without a verdict.
static func _condition_entry(condition: ACECondition, values: Dictionary, evaluate: bool) -> Dictionary:
	var entry: Dictionary = {
		"label": label_for(condition),
		"expression": expression_for(condition),
		"verdict": VERDICT_UNKNOWN,
		"seen": "",
		"note": "",
	}
	if condition == null:
		return entry
	if not condition.enabled:
		entry["note"] = "disabled - the compiler leaves it out entirely"
		return entry
	if not evaluate:
		return entry
	var expression: String = str(entry["expression"])
	if expression.strip_edges().is_empty():
		entry["note"] = "no compiled expression to read"
		return entry
	var verdict: Dictionary = EventSheetLiveValuesPanel.evaluate_watch(expression, values)
	if not bool(verdict.get("ok", false)):
		# Reaching past the streamed variables is the COMMON case (`is_on_floor()`, a behaviour's
		# member), not an error to shout about: the panel says it cannot see it and stops there.
		entry["note"] = "not observable from here - it reads the node, not a sheet variable"
		return entry
	var value: Variant = verdict.get("value")
	entry["verdict"] = VERDICT_TRUE if bool(value) else VERDICT_FALSE
	entry["seen"] = str(value)
	# The value that made the call is the interesting fact, so the operands are reported too when
	# they are plain sheet variables ("score = 142" beside "score >= 100 -> false").
	var operands: PackedStringArray = _operand_values(expression, values)
	if not operands.is_empty():
		entry["seen"] = ", ".join(operands)
	return entry


## The sheet variables an expression mentions, with the value each one HAD when it was tested.
## Substring matching on identifiers, deliberately simple: it decorates the verdict, never
## decides it, so a miss costs a hint and never a wrong answer.
static func _operand_values(expression: String, values: Dictionary) -> PackedStringArray:
	var seen: PackedStringArray = PackedStringArray()
	var names: Array = values.keys()
	names.sort()
	for key: Variant in names:
		var name: String = str(key)
		if not name.is_valid_identifier():
			continue
		if _mentions_identifier(expression, name):
			seen.append("%s = %s" % [name, str(values[key])])
	return seen


## True when `identifier` appears in `text` as a whole word (so "score" does not match
## "high_score" and a variable named `x` does not match every expression in the sheet).
static func _mentions_identifier(text: String, identifier: String) -> bool:
	var from_index: int = 0
	while true:
		var found: int = text.find(identifier, from_index)
		if found < 0:
			return false
		var before_ok: bool = found == 0 or not _is_identifier_char(text[found - 1])
		var after_index: int = found + identifier.length()
		var after_ok: bool = after_index >= text.length() or not _is_identifier_char(text[after_index])
		if before_ok and after_ok:
			return true
		from_index = found + 1
	return false


## Letters, digits and underscore - the characters that would make a longer identifier. Spelled
## out rather than leaning on is_valid_identifier(), which is false for a bare digit and would
## make "score" match inside "score2".
static func _is_identifier_char(character: String) -> bool:
	return character == "_" or (character + "a").is_valid_identifier() or character.is_valid_int()


## The condition as the row shows it (the display sentence with its parameters filled, markup
## stripped), falling back to the ace id so an unknown provider still names something real.
static func label_for(condition: ACECondition) -> String:
	if condition == null:
		return ""
	var params: Dictionary = condition.params if not condition.params.is_empty() else condition.parameters
	var text: String = ""
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(condition.provider_id, condition.ace_id)
	if descriptor != null:
		text = descriptor.get_display_text()
	if text.strip_edges().is_empty():
		text = condition.ace_id
	text = EventSheetBBCodeLite.strip(ViewportTooltipHelper.fill_codegen_template(text, params) if text.contains("{") else text)
	return ("Not: " + text) if condition.negated else text


## The GDScript the compiler actually tests for this condition - the baked template with its
## parameters filled, negation included. This is the string the panel evaluates.
static func expression_for(condition: ACECondition) -> String:
	if condition == null:
		return ""
	var params: Dictionary = condition.params if not condition.params.is_empty() else condition.parameters
	var template: String = condition.codegen_template
	if template.strip_edges().is_empty():
		var descriptor: ACEDescriptor = ACERegistry.find_descriptor(condition.provider_id, condition.ace_id)
		if descriptor != null:
			template = descriptor.codegen_template
	var filled: String = ViewportTooltipHelper.fill_codegen_template(template, params)
	if filled.strip_edges().is_empty():
		return ""
	return ("not (%s)" % filled) if condition.negated else filled


# ── The window (Compact Developer chrome, built with the shared popup helpers) ─────────────
## The one live window, reused: asking about a second row re-fills it rather than stacking
## panels, because two open explanations of two rows is exactly the "layer" this must not be.
static var _window: Window = null


## Opens the panel for one row. `values` is the latest streamed Live Values frame ({} = no
## running game, which the panel states plainly rather than filling in).
static func open_for_row(host: Control, event_row: EventRow, values: Dictionary, event_number: int = 0) -> void:
	if host == null or event_row == null:
		return
	var report: Dictionary = build_report(event_row, values, not values.is_empty())
	if _window == null or not is_instance_valid(_window):
		_window = Window.new()
		_window.title = "Why didn't this fire?"
		_window.size = Vector2i(520, 420)
		_window.close_requested.connect(func() -> void:
			if is_instance_valid(_window):
				_window.hide())
		host.add_child(_window)
	for stale: Node in _window.get_children():
		stale.queue_free()
	_window.add_child(EventSheetPopupUI.margined(build_body(report, event_number)))
	_window.popup_centered()


## The report as controls. Split from open_for_row so a render harness can shoot the body
## without a debug session, and so the window stays a shell around one function.
static func build_body(report: Dictionary, event_number: int = 0) -> Control:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.add_child(EventSheetPopupUI.small_caps_label(
		"EVENT %d" % event_number if event_number > 0 else "THIS EVENT"))
	title_row.add_child(EventSheetPopupUI.metadata_badge(
		"live" if bool(report.get("streaming", false)) else "game not running"))
	box.add_child(title_row)
	box.add_child(EventSheetPopupUI.hint_label(str(report.get("headline", ""))))
	box.add_child(EventSheetPopupUI.hint_label(str(report.get("verdict_line", ""))))
	var rows: Array = []
	var entries: Array = report.get("conditions", [])
	for index: int in range(entries.size()):
		var entry: Dictionary = entries[index]
		var marker: String = str(entry.get("verdict", VERDICT_UNKNOWN))
		if index == int(report.get("blocker_index", -1)):
			marker += "  ← said no"
		rows.append(PackedStringArray([
			marker,
			str(entry.get("label", "")),
			str(entry.get("seen", "")),
			str(entry.get("note", "")),
		]))
	if rows.is_empty():
		rows.append(PackedStringArray(["", "This row has no conditions.", "", ""]))
	box.add_child(EventSheetPopupUI.labelled_card("CONDITIONS",
		EventSheetPopupUI.compact_table(PackedStringArray(["", "Condition", "Value seen", "Note"]), rows, 3)))
	box.add_child(EventSheetPopupUI.hint_label(
		"Read from the values the running game streams. Nothing is written to your sheet, and closing this window leaves nothing behind."))
	return box
