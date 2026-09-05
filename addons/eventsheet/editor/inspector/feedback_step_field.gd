# Godot EventSheets - the parameter field a feedback STEP is written in: the same card the Feedback
# Player's Inspector list unfolds, opened from a row.
#
# THE ONE THING THIS FILE IS ABOUT: a feedback added by a row and a feedback added in the Inspector
# have to be the same thing. Add Feedback takes a dictionary, and a dictionary typed by hand into a
# parameter box is the worst field in the editor - no kinds, no fields, no help, and a missing brace
# for a mistake. So the box opens the CARD: the very drawer the Inspector draws the list with,
# holding one card, and what it gives back is written into the box as the dictionary literal the row
# emits.
#
# IT IS A LineEdit, because that is the params dialog's contract for a registered editor: the dialog
# reads the value off `.text`, so a card that never opens still round-trips whatever is in the box,
# and a project without the editor plugin gets a plain box that takes the same literal.
#
# THE LITERAL IS DETERMINISTIC. Keys are written in a fixed order (the four a moment file holds
# first, then the rest sorted), so opening a card and closing it again without touching anything
# leaves the row's bytes exactly as they were - which is what the sheet's own byte-exact round trip
# needs from every field that rewrites a value.
# NO class_name ON PURPOSE: the plugin loads this file BY PATH when it registers the editor, so a
# global name would put it (and the card drawer it names) on the boot compile to buy nothing.
@tool
extends LineEdit

## The keys a moment file holds, written first and in this order so the literal reads the way the
## file does. Everything else follows, sorted, so the order can never depend on a dictionary's own.
const LEADING_KEYS: PackedStringArray = ["verb", "amount", "effect", "seconds"]

## The card vocabulary this field draws with - the same name the Feedback Player's export marker
## asks for, so the row's card and the list's card are one schema.
const SCHEMA_NAME: String = "feedback_steps"

var _window: Window = null
var _drawer: EventSheetCardListDrawer = null


func _init(starting_text: String = "") -> void:
	text = starting_text
	placeholder_text = "{\"verb\": \"shake\", \"amount\": 0.4, \"seconds\": 0.2}"
	tooltip_text = "The feedback this row adds. Press the card button to fill it in."
	var open: Button = Button.new()
	open.text = "Card"
	open.tooltip_text = "Open this feedback as the card the Inspector's list draws."
	open.flat = true
	open.focus_mode = Control.FOCUS_ALL
	open.pressed.connect(_open_card)
	# The button rides INSIDE the box, right-aligned, so the field is still one control the dialog
	# lays out as a field rather than a row of two things that have to be kept in step.
	open.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	open.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(open)


## The card, opened. The drawer holds exactly one card because a step IS one card; adding a second
## in there would be a list, and the list is what the node's Inspector is for.
func _open_card() -> void:
	if _window != null and is_instance_valid(_window):
		_window.grab_focus()
		return
	_drawer = EventSheetCardListDrawer.new({
		"kind_key": "verb", "schema": SCHEMA_NAME, "stripe_key": "category"})
	_drawer.set_value([parse_step(text)])
	_window = Window.new()
	_window.title = "Feedback"
	_window.size = Vector2i(520, 460)
	_window.close_requested.connect(_close_card)
	var frame: MarginContainer = MarginContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		frame.add_theme_constant_override("margin_" + side, 10)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.add_child(_drawer)
	_drawer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_child(scroll)
	_window.add_child(frame)
	add_child(_window)
	_window.popup_centered()


## Closing the card writes it back. The FIRST card is the step: a drawer that was emptied leaves the
## box exactly as it was rather than writing an empty dictionary over what somebody typed.
func _close_card() -> void:
	if _drawer != null and is_instance_valid(_drawer):
		var cards: Array = _drawer.get_value()
		if cards.size() > 0 and cards[0] is Dictionary:
			text = step_literal(cards[0] as Dictionary)
			text_submitted.emit(text)
	if _window != null and is_instance_valid(_window):
		_window.queue_free()
	_window = null
	_drawer = null


## What is in the box, read back as a card. A box holding an expression rather than a literal (which
## is allowed - the row emits whatever is typed) opens as a plain shake, because a card cannot draw
## an expression and pretending otherwise would silently overwrite it on close.
##
## STATIC AND PURE, so the suite pins the round trip without an editor.
static func parse_step(written: String) -> Dictionary:
	var trimmed: String = written.strip_edges()
	# Only a literal is even offered to the parser: handing it an expression would print an engine
	# error about text nobody wrote wrongly, which is worse than the answer it would give back.
	if not trimmed.begins_with("{") or not trimmed.ends_with("}"):
		return {"verb": "shake", "amount": 1.0, "effect": "", "seconds": 0.0}
	# THE ENGINE'S OWN READER FIRST, because it is the one that keeps a whole number whole: a card
	# holds counts (loops, repeats) as well as times, and JSON hands every number back as a float,
	# which would rewrite `"loops": 2` as `"loops": 2.0` on a card that was only ever looked at.
	var spelled: Variant = str_to_var(trimmed)
	if spelled is Dictionary:
		return spelled as Dictionary
	var parsed: Variant = JSON.parse_string(trimmed)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {"verb": "shake", "amount": 1.0, "effect": "", "seconds": 0.0}


## One card written as the GDScript dictionary literal the row emits. The four a moment file holds
## lead, in the file's own order, and the rest follow sorted - so the same card always writes the
## same bytes however the dictionary it came from was built up.
##
## STATIC AND PURE, for the same reason.
static func step_literal(card: Dictionary) -> String:
	var written: PackedStringArray = PackedStringArray()
	var rest: PackedStringArray = PackedStringArray()
	for key: Variant in card:
		if not LEADING_KEYS.has(str(key)):
			rest.append(str(key))
	rest.sort()
	var order: PackedStringArray = PackedStringArray()
	for key: String in LEADING_KEYS:
		if card.has(key):
			order.append(key)
	order.append_array(rest)
	for key: String in order:
		written.append("\"%s\": %s" % [key, _as_literal(card[key])])
	return "{%s}" % ", ".join(written)


## One value as GDScript spells it. Only the four kinds a card ever holds are spelled out; anything
## else is written through `var_to_str`, which is the engine's own answer and round-trips.
static func _as_literal(value: Variant) -> String:
	if value is String:
		return "\"%s\"" % (value as String).c_escape()
	if value is bool:
		return "true" if value else "false"
	if value is int:
		return str(value)
	if value is float:
		var spelled: String = String.num(value as float, 4)
		if spelled.contains("."):
			spelled = spelled.rstrip("0")
			if spelled.ends_with("."):
				spelled += "0"
		return spelled
	return var_to_str(value)
