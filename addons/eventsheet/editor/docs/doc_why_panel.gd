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
## Returns {streaming, headline, verdict_line, blocker_index, trigger, facts, conditions: [{label,
## expression, verdict, seen, note}]}. Pure and static - no editor, no session, no drawing.
##
## `sheet` is optional and only widens the answer: it is what lets the report say who switched off
## the group this row is in. Every fact it adds is something the sheet SAYS plus something the run
## COUNTED - never a guess about which of them was the cause.
static func build_report(event_row: EventRow, values: Dictionary, streaming: bool = true,
		sheet: EventSheetResource = null) -> Dictionary:
	var report: Dictionary = {
		"streaming": streaming and not values.is_empty(),
		"headline": "",
		"verdict_line": "",
		"blocker_index": -1,
		"trigger": "",
		"facts": PackedStringArray(),
		"conditions": [],
	}
	if event_row == null:
		report["headline"] = "No event row."
		return report
	report["headline"] = _headline_for(event_row)
	report["trigger"] = trigger_line(event_row)
	report["facts"] = cross_references(sheet, event_row)
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


## What the RUN says about the row itself, before any condition is read: a trigger that arrived
## twelve times is fine and the answer is below it; a trigger that never arrived is the whole answer
## and no amount of reading conditions will say so. "" when no run has counted anything, because a
## count nobody took is not a zero.
static func trigger_line(event_row: EventRow) -> String:
	if event_row == null or not EventSheetRunProfile.has_numbers():
		return ""
	var count: int = EventSheetRunProfile.calls_for(event_row.event_uid)
	var named: String = "This row" if event_row.trigger_id.strip_edges().is_empty() else "The trigger"
	if count == 0:
		return "%s never ran at all (%s) - so nothing below it was ever asked." % [named, EventSheetRunProfile.label()]
	if count == 1:
		return "%s ran once (%s) - it is not the trigger." % [named, EventSheetRunProfile.label()]
	return "%s ran %s times (%s) - it is not the trigger." % [
		named, EventSheetTraceHitCounts.format_count(count), EventSheetRunProfile.label()]


## The plain facts about this row that live somewhere ELSE in the sheet - the ones a reader would
## have to go and find. Facts only: what the sheet says, and what the run counted. Never a sentence
## joining them into a cause, because the panel does not know which of them mattered.
static func cross_references(sheet: EventSheetResource, event_row: EventRow) -> PackedStringArray:
	var facts: PackedStringArray = PackedStringArray()
	if sheet == null or event_row == null:
		return facts
	var group: EventGroup = _group_holding(sheet.events, event_row)
	if group == null:
		return facts
	if not group.enabled:
		facts.append("The %s group it is in is switched off, so none of its rows are compiled at all." % group.display_name())
	elif group.runtime_toggleable:
		var switched: PackedStringArray = _rows_switching(sheet.events, group.display_name())
		if not switched.is_empty():
			facts.append("The %s group it is in can be switched off while the game runs, and %s." % [
				group.display_name(), ", ".join(switched)])
	return facts


## The innermost group holding this row, or null when it sits at the top of the sheet.
static func _group_holding(items: Array, event_row: EventRow, inside: EventGroup = null) -> EventGroup:
	for item: Variant in items:
		if item is EventGroup:
			var found: EventGroup = _group_holding(EventSheetGroupFacts.children(item as EventGroup),
				event_row, item as EventGroup)
			if found != null:
				return found
			continue
		var row: EventRow = item as EventRow
		if row == null:
			continue
		if is_same(row, event_row):
			return inside
		var nested: EventGroup = _group_holding(row.sub_events, event_row, inside)
		if nested != null:
			return nested
	return null


## The rows anywhere in this sheet that switch a named group off or on, said as what they are.
static func _rows_switching(items: Array, group_name: String) -> PackedStringArray:
	var said: PackedStringArray = PackedStringArray()
	for item: Variant in items:
		if item is EventGroup:
			said.append_array(_rows_switching(EventSheetGroupFacts.children(item as EventGroup), group_name))
			continue
		var row: EventRow = item as EventRow
		if row == null:
			continue
		for action: Variant in row.actions:
			if not (action is Resource) or str((action as Resource).get("ace_id")) != "SetGroupActive":
				continue
			var params: Variant = (action as Resource).get("params")
			if not (params is Dictionary):
				continue
			if str((params as Dictionary).get("group", "")).replace("\"", "").strip_edges() != group_name:
				continue
			var word: String = "a row switches it %s" % (
				"on" if str((params as Dictionary).get("active", "true")).contains("true") else "off")
			if not said.has(word):
				said.append(word)
		said.append_array(_rows_switching(row.sub_events, group_name))
	return said


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
static func open_for_row(host: Control, event_row: EventRow, values: Dictionary, event_number: int = 0,
		sheet: EventSheetResource = null) -> void:
	if host == null or event_row == null:
		return
	var report: Dictionary = build_report(event_row, values, not values.is_empty(), sheet)
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
	var body: Control = build_body(report, event_number)
	body.add_child(_buttons(host, report, event_row))
	_window.add_child(EventSheetPopupUI.margined(body))
	_window.popup_centered()


## The two ways out of the answer: go and look at the row, and watch the value the answer named.
## Both are gestures the editor already has - the panel only points at them.
static func _buttons(host: Control, report: Dictionary, event_row: EventRow) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	var jump: Button = Button.new()
	jump.text = EventSheetL10n.translate("Jump to this row")
	jump.pressed.connect(func() -> void:
		if is_instance_valid(_window):
			_window.hide()
		var view: Object = host.call("_active_view") if host.has_method("_active_view") else null
		if view != null and view.has_method("reveal_resource"):
			view.call("reveal_resource", event_row))
	row.add_child(jump)
	var watched: String = watchable_name(report)
	if not watched.is_empty():
		var watch: Button = Button.new()
		watch.text = EventSheetL10n.translate("Watch %s") % watched
		watch.pressed.connect(func() -> void:
			if host.has_method("_ensure_live_values_panel"):
				host.call("_ensure_live_values_panel").add_watch(watched))
		row.add_child(watch)
	return row


## The name worth watching: the one the blocking condition was about. "" when nothing said no, or
## when what said no was not about a value the stream carries.
static func watchable_name(report: Dictionary) -> String:
	var blocker: int = int(report.get("blocker_index", -1))
	var entries: Array = report.get("conditions", [])
	if blocker < 0 or blocker >= entries.size():
		return ""
	var seen: String = str((entries[blocker] as Dictionary).get("seen", ""))
	var at: int = seen.find(" = ")
	return "" if at <= 0 else seen.substr(0, at)


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
	# What the run counted comes before what the conditions said: a trigger that never arrived is the
	# whole answer, and reading three condition verdicts to reach it wastes the reader's time.
	var trigger: String = str(report.get("trigger", ""))
	if not trigger.is_empty():
		box.add_child(EventSheetPopupUI.hint_label(trigger))
	box.add_child(EventSheetPopupUI.hint_label(str(report.get("verdict_line", ""))))
	for fact: String in PackedStringArray(report.get("facts", PackedStringArray())):
		box.add_child(EventSheetPopupUI.hint_label(fact))
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
