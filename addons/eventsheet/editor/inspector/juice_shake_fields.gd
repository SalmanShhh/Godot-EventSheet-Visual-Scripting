# Godot EventSheets - what the Shake card holds beyond an amount and a length: two ticks, a Curve of
# your own, the little drawing of the shape and the sentences that say what the card will do.
#
# The ticks and the curve are only offered when the Juice pack on disk can play them, so a project that
# keeps an older copy of the pack is never handed a tick it would ignore. A card keeps the keys
# `fade_in` and `fade_out` (true or false) and `curve` (the Curve file's uid text); a card with none of
# them shakes as it always has. This file is path-loaded by the card schema and is not part of the
# editor's first open.
@tool
extends RefCounted

## The Juice pack's row that shakes for a length. A pack without it cannot play the ticks.
const TIMED_VERB: String = "shake_for"

## The file the shape is written in, shared by the running shake and the picture below.
const RUNNER_PATH: String = "res://eventsheet_addons/juice/moment_runner.gd"

## How many bars the shape is drawn with.
const BARS: int = 16

## The drawing's colour: the camera family's own.
const BAR_COLOUR: Color = Color("#8B63E0")


## Whether the pack read from disk plays timed shakes.
static func offered(reading: Dictionary) -> bool:
	var verbs: Variant = reading.get("verbs")
	return verbs is Dictionary and (verbs as Dictionary).has(TIMED_VERB)


## The fields a Shake card draws after its Amount and Seconds.
static func fields() -> Array:
	return [
		{"key": "fade_in", "label": "Fade in", "drawer": "bool", "unset": false, "suffix": "rises from nothing", "redraw": true, "grey_when": curve_is_set},
		{"key": "fade_out", "label": "Fade out", "drawer": "bool", "unset": false, "suffix": "goes down to nothing", "redraw": true, "grey_when": curve_is_set},
		{"key": "curve", "label": "Custom curve", "drawer": "resource:Curve", "unset": ""},
		{"key": "shake_shape", "label": "", "drawer": "custom", "build": shape_strip},
		{"key": "shake_says", "label": "", "drawer": "note", "text": says, "hide_empty": true},
		{"key": "shake_old", "label": "", "drawer": "note", "text": old_card_line, "warn_when": is_old_card, "hide_empty": true}
	]


## What a NEW Shake card starts with: Fade out ticked, and a length that means something.
static func new_card_keys() -> Dictionary:
	return {"fade_out": true}


## Whether the card names a Curve file, in which case the curve is the shape and the ticks are greyed.
static func curve_is_set(card: Dictionary) -> bool:
	return not str(card.get("curve", "")).strip_edges().is_empty()


## A Shake card saved before the ticks existed: none of the keys. It shakes by the Juice node's Shake
## Decay, so its Seconds is not how long it lasts.
static func is_old_card(card: Dictionary) -> bool:
	return not card.has("fade_in") and not card.has("fade_out") and not curve_is_set(card)


## The one quiet line an old card shows until a tick is touched.
static func old_card_line(card: Dictionary) -> String:
	if not is_old_card(card):
		return ""
	return EventSheetL10n.translate("This card still shakes for as long as the Juice node's Shake Decay says. Tick Fade in or Fade out to make Seconds the real length.")


## What the card does, in one grey sentence under the picture.
static func says(card: Dictionary) -> String:
	if is_old_card(card):
		return ""
	var amount: String = _plain(float(card.get("amount", 1.0)))
	var seconds: String = _plain(float(card.get("seconds", 0.0)))
	if curve_is_set(card):
		return EventSheetL10n.translate("Follows your curve over %s s, at most %s.") % [seconds, amount]
	var fade_in: bool = bool(card.get("fade_in", false))
	var fade_out: bool = bool(card.get("fade_out", false))
	if fade_in and fade_out:
		return EventSheetL10n.translate("Swells to %s half way and is gone at %s s.") % [amount, seconds]
	if fade_in:
		return EventSheetL10n.translate("Starts at nothing and reaches %s at %s s.") % [amount, seconds]
	if fade_out:
		return EventSheetL10n.translate("Starts at %s and is gone at %s s.") % [amount, seconds]
	return EventSheetL10n.translate("Holds %s for %s s, then stops.") % [amount, seconds]


## The share of the amount the card has at a share of its time, asked of the shared runner so the picture
## and the game cannot disagree. 1 when the runner is not there.
static func shape_at(card: Dictionary, through: float) -> float:
	var runner: Script = load(RUNNER_PATH) as Script if ResourceLoader.exists(RUNNER_PATH) else null
	if runner == null or not runner.has_method("shake_shape"):
		return 1.0
	var kept: String = str(card.get("curve", "")).strip_edges()
	var curve: Curve = load(kept) as Curve if not kept.is_empty() and ResourceLoader.exists(kept) else null
	return float(runner.call("shake_shape", through, bool(card.get("fade_in", false)), bool(card.get("fade_out", false)), curve))


## The drawing of the shape: left is the start of the shake, right is the end, and the height is how much
## of the amount is felt. A card with none of the keys draws nothing, because its shake has no shape of its own.
static func shape_strip(card: Dictionary, _now: Callable, _edited: Object) -> Control:
	var box: ShapeBox = ShapeBox.new()
	box.setup(card)
	return box


## The curve a card names, the one Godot keeps in memory for that file (so an edit made in the Inspector's
## curve editor is the one this reads), or null when it names none or the file is not there.
static func curve_of(card: Dictionary) -> Curve:
	var kept: String = str(card.get("curve", "")).strip_edges()
	return load(kept) as Curve if not kept.is_empty() and ResourceLoader.exists(kept) else null


## Whether the curve in memory differs from the curve in its file. The game plays the file, so a curve that has
## been edited and not saved is not what the game will shake by.
static func has_unsaved_edits(card: Dictionary) -> bool:
	var live: Curve = curve_of(card)
	if live == null:
		return false
	var kept: String = str(card.get("curve", "")).strip_edges()
	var saved: Curve = ResourceLoader.load(kept, "Curve", ResourceLoader.CACHE_MODE_IGNORE) as Curve
	return saved != null and _signature(live) != _signature(saved)


## Everything about a curve that changes what it draws, as one text, so two curves can be told apart.
static func _signature(curve: Curve) -> String:
	var parts: PackedStringArray = PackedStringArray([str(curve.min_value), str(curve.max_value), str(curve.min_domain), str(curve.max_domain), str(curve.point_count)])
	for index: int in range(curve.point_count):
		parts.append("%s %s %s %d %d" % [curve.get_point_position(index), curve.get_point_left_tangent(index), curve.get_point_right_tangent(index), curve.get_point_left_mode(index), curve.get_point_right_mode(index)])
	return "|".join(parts)


## The one quiet sentence under the drawing when the curve has edits that are not saved to its file.
static func unsaved_line(card: Dictionary) -> String:
	if not has_unsaved_edits(card):
		return ""
	return EventSheetL10n.translate("This curve has changes that are not saved to its file yet. The game plays the saved file.")


static func _plain(value: float) -> String:
	return str(snappedf(value, 0.001)).trim_suffix(".0")


## The drawing and the sentence under it. It redraws when the curve it follows changes, so the bars are the shape
## the curve has now, and it says so when the curve has edits the file does not.
class ShapeBox:
	extends VBoxContainer

	var strip: Strip = null
	var note: Label = null
	var card: Dictionary = {}
	var curve: Curve = null
	## How many times the curve told this it changed, so a test can see that it was listening.
	var refreshes: int = 0

	func setup(shaken: Dictionary) -> void:
		card = shaken
		var shake_fields: Script = load("res://addons/eventsheet/editor/inspector/juice_shake_fields.gd") as Script
		strip = Strip.new()
		strip.card = card
		strip.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled(24))
		strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(strip)
		note = EventSheetLookStyle.message_line("", EventSheetLookStyle.Tone.WARNING)
		note.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
		note.hide()
		add_child(note)
		visible = not bool(shake_fields.call("is_old_card", card))
		curve = shake_fields.call("curve_of", card) as Curve
		if curve != null:
			curve.changed.connect(_on_curve_changed)
		_show_note()

	func _on_curve_changed() -> void:
		refreshes += 1
		strip.queue_redraw()
		_show_note()

	func _show_note() -> void:
		var shake_fields: Script = load("res://addons/eventsheet/editor/inspector/juice_shake_fields.gd") as Script
		note.text = str(shake_fields.call("unsaved_line", card))
		note.visible = not note.text.is_empty()

	func _exit_tree() -> void:
		if curve != null and curve.changed.is_connected(_on_curve_changed):
			curve.changed.disconnect(_on_curve_changed)


## The bars.
class Strip:
	extends Control

	var card: Dictionary = {}

	func _draw() -> void:
		var gap: float = 3.0
		var width: float = (size.x - gap * float(BARS - 1)) / float(BARS)
		if width <= 0.0:
			return
		var shake_fields: Script = load("res://addons/eventsheet/editor/inspector/juice_shake_fields.gd") as Script
		for bar: int in range(BARS):
			var level: float = clampf(float(shake_fields.call("shape_at", card, (float(bar) + 0.5) / float(BARS))), 0.0, 1.0)
			var height: float = maxf(size.y * level, 1.0)
			draw_rect(Rect2(float(bar) * (width + gap), size.y - height, width, height), BAR_COLOUR)
