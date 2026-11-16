# Godot EventSheets - trying a Juice Player's list in the editor (editor-only, loaded by path).
#
# What the Inspector's play buttons and the Sound card's Listen button have in common: a thing that
# runs in the editor for a moment, touches something the scene saves, and has to put it back. This
# file is where that lives, so there is ONE answer to "what did the preview move" and ONE door the
# editor calls before it saves.
#
# The list of what a preview may move is written down BEFORE it plays (`watched_properties`), the strip
# that plays it keeps that list, and `restore_all` puts every live preview back. The plugin calls that
# before a scene is saved, so a file saved in the middle of a preview never holds a half-played value.
#
# No class_name on purpose: Create Node lists every named class, and an editor-only helper has no
# business there. Everything public is a static the strip, the card drawer and the suite call by path.
@tool
extends RefCounted

## The file that says where the pack whose statics the preview reads lives. By PATH, because naming the
## pack here would compile it into every editor boot in projects that hold no Juice Player.
const NAMES_PATH: String = "res://addons/eventsheet/editor/inspector/juice_player_names.gd"

## What a preview may write on the object a Juice Player is under, always; a tweened property is added
## to this for the list being played.
const ALWAYS_WATCHED: PackedStringArray = ["position", "rotation", "scale", "modulate"]

## How a preview plays part of a list.
const ONE: String = "one"
const FROM_HERE: String = "from_here"
const ALL: String = "all"

## The strips that are alive right now, by the object they are about, so the plugin can put every one
## back before a save and a card's play mark can find the strip that plays for its list.
static var _live: Dictionary = {}


## The part of a list a preview plays: one card, a card and everything under it, or the whole list.
## The cards are the list's own entries, not copies, so a number changed while it repeats is the
## number the next pass reads.
static func sub_list(list: Array, index: int, mode: String) -> Array:
	if mode == ALL or index < 0 or index >= list.size():
		return list.duplicate()
	if mode == ONE:
		return [list[index]]
	return list.slice(index)


## The positions in the list that `sub_list` took, in the same order.
static func sub_indices(list: Array, index: int, mode: String) -> PackedInt32Array:
	var taken: PackedInt32Array = PackedInt32Array()
	if mode == ONE and index >= 0 and index < list.size():
		taken.append(index)
		return taken
	for position: int in range(maxi(index, 0) if mode == FROM_HERE else 0, list.size()):
		taken.append(position)
	return taken


## Everything a preview of this list may move: the four every play writes, then each property a Tween
## Property card names. The preview writes these down before the first frame and puts them back after
## the last, so what it is allowed to touch is exactly what it restores.
static func watched_properties(list: Array) -> PackedStringArray:
	var watched: PackedStringArray = ALWAYS_WATCHED.duplicate()
	for entry: Variant in list:
		if not (entry is Dictionary):
			continue
		var card: Dictionary = entry as Dictionary
		var property: String = str(card.get("effect", "")).strip_edges()
		if str(card.get("verb", "")) == "tween_property" and not property.is_empty() and not watched.has(property):
			watched.append(property)
	return watched


## Which cards of a list are being felt `time` seconds into a play of it, as list positions. A card is
## felt from the moment the plan starts it until it ends, and a card the plan leaves out (a Pause, a loop
## word, a card switched off) is never in the answer. The card list lights a mark on each of these.
static func playing_at(list: Array, positions: PackedInt32Array, time: float) -> PackedInt32Array:
	var pack: Script = pack_script()
	var lit: PackedInt32Array = PackedInt32Array()
	if pack == null:
		return lit
	var plan: Array = pack.call("schedule_of", list)
	var planned: PackedInt32Array = PackedInt32Array()
	for at_index: int in range(list.size()):
		var card: Dictionary = list[at_index] as Dictionary
		var word: String = str(card.get("verb", ""))
		if bool(card.get("active", true)) and word != "pause" and word != "hold_until" and word != "loop_start" and word != "loop_back":
			planned.append(positions[at_index] if at_index < positions.size() else at_index)
	for plan_index: int in range(mini(plan.size(), planned.size())):
		var entry: Dictionary = plan[plan_index] as Dictionary
		var starts: float = float(entry.get("at", 0.0))
		if time >= starts and time <= starts + maxf(float(entry.get("seconds", 0.0)), 0.05):
			lit.append(planned[plan_index])
	return lit


## The pack's script, or null when the project has no Juice Player.
static func pack_script() -> Script:
	return load(str(load(NAMES_PATH).pack_path())) as Script


## A strip for one object, registered so the plugin can restore it and a card's mark can find it. An
## object may have more than one (the one under its list and the toolbar's own).
static func register(object: Object, strip: Control) -> void:
	var key: int = object.get_instance_id()
	if not _live.has(key):
		_live[key] = []
	(_live[key] as Array).append(strip)


static func unregister(object: Object, strip: Control) -> void:
	var key: int = object.get_instance_id()
	if _live.has(key):
		(_live[key] as Array).erase(strip)
		if (_live[key] as Array).is_empty():
			_live.erase(key)


## The strip under the list of an object, or null. The toolbar's own strip has no list under it and is
## not the one a card's mark means.
static func strip_for(object: Object) -> Control:
	for strip: Variant in _live.get(object.get_instance_id(), []):
		if strip != null and is_instance_valid(strip) and (strip as Control).get("_drawer") != null:
			return strip as Control
	return null


## Puts everything every live preview moved back, now. The plugin calls it before a scene is saved or run.
static func restore_all() -> void:
	for strips: Variant in _live.values():
		for strip: Variant in strips as Array:
			if strip != null and is_instance_valid(strip) and (strip as Control).has_method("stop"):
				(strip as Control).call("stop")


## What a card does when the card list's play mark or its menu is pressed: finds the strip that plays
## for this object and has it play the part of the list asked for.
static func card_action(object: Object, action: String, index: int) -> void:
	var strip: Control = strip_for(object)
	if strip != null and strip.has_method("play_part"):
		strip.call("play_part", ONE if action == "play_one" else FROM_HERE, index)


## The Listen button for a Sound card: Play, a thin bar that fills while it sounds, and how long it is.
## `current` asks for the card as it is NOW, so a number changed a moment ago is what is heard.
static func listen_control(current: Callable) -> Control:
	return ListenRow.new(current)


## One row: press to hear the card alone with its own volume, pitch and bus (a new pitch and volume
## rolled each press, so the spread is heard), press again to stop. It owns its own audio player,
## which lives under this row and goes when the row does, so nothing is ever added to the scene.
class ListenRow:
	extends HBoxContainer

	var _current: Callable = Callable()
	var _button: Button = null
	var _bar: ProgressBar = null
	var _length_label: Label = null
	var _voice: AudioStreamPlayer = null
	var _length: float = 0.0

	func _init(current: Callable) -> void:
		_current = current
		add_theme_constant_override("separation", 6)
		_button = Button.new()
		_button.text = EventSheetL10n.translate("Play")
		_button.tooltip_text = EventSheetL10n.translate("Hear this card alone, with its own volume, pitch and bus. A new pitch is rolled each press. Press again to stop.")
		_button.pressed.connect(_on_pressed)
		add_child(_button)
		_bar = ProgressBar.new()
		_bar.show_percentage = false
		_bar.max_value = 1.0
		_bar.custom_minimum_size = Vector2(0.0, 6.0)
		_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(_bar)
		_length_label = Label.new()
		_length_label.add_theme_color_override("font_color", EventSheetLookStyle.quiet())
		add_child(_length_label)
		_voice = AudioStreamPlayer.new()
		_voice.finished.connect(_finish)
		add_child(_voice)
		set_process(false)
		_show_length()

	## What the row says the card lasts, asked of the pack so Listen, the badge and the plan agree.
	func _show_length() -> void:
		var pack: Script = load("res://addons/eventsheet/editor/inspector/juice_preview.gd").call("pack_script")
		var card: Dictionary = _current.call()
		_length = float(pack.call("card_length", card)) if pack != null else 0.0
		_length_label.text = "%.2f s" % _length

	func _on_pressed() -> void:
		if _voice.playing:
			_voice.stop()
			_finish()
			return
		var pack: Script = load("res://addons/eventsheet/editor/inspector/juice_preview.gd").call("pack_script")
		if pack == null:
			return
		var card: Dictionary = _current.call()
		var settings: Dictionary = pack.call("sound_settings", card, 1.0, randf(), randf())
		var path: String = str(settings.get("stream", ""))
		var stream: AudioStream = load(path) as AudioStream if not path.is_empty() and ResourceLoader.exists(path) else null
		if stream == null:
			_length_label.text = EventSheetL10n.translate("No sound picked.")
			return
		var bus: String = str(settings.get("bus", "Master"))
		_voice.bus = bus if AudioServer.get_bus_index(bus) >= 0 else "Master"
		_voice.stream = stream
		_voice.volume_db = float(settings.get("volume_db", 0.0))
		_voice.pitch_scale = float(settings.get("pitch_scale", 1.0))
		_button.text = EventSheetL10n.translate("Stop")
		_show_length()
		_voice.play()
		set_process(true)

	func _process(_delta: float) -> void:
		if _voice.playing and _length > 0.0:
			_bar.value = clampf(_voice.get_playback_position() / _length, 0.0, 1.0)

	func _finish() -> void:
		set_process(false)
		_bar.value = 0.0
		_button.text = EventSheetL10n.translate("Play")
		_show_length()
