# Godot EventSheets - the card vocabulary a Juice Player's list is edited with (editor-only,
# UI-free).
#
# A Juice Player holds an Array of Dictionaries, and each dictionary is one felt thing: the same
# four keys a moment FILE holds (verb, amount, effect, seconds) plus the timing keys a file cannot
# carry. This file says what those dictionaries MEAN so the card-list drawer can draw them: what
# each word is called, what it explains, which fields it has and which of its values the running
# game writes back.
#
# DERIVED, NOT WRITTEN DOWN TWICE. The ten words a moment is made of are read off the Juice pack's
# own Moment Step verb - its `verb` parameter already lists them - and each word's title and help
# come from the pack verb of that name, so a pack that renames Shake renames the card with it and a
# pack that adds a word gets a card for free. Only the words that are NOT a Juice verb are written
# here: the four that move the head (Pause, Hold, Loop Start, Loop Back) and the three that are not
# a feeling (Tween Property, Emit Signal, Play Player).
#
# THE PACK IS READ AS TEXT, not reflected. A pack script is not a `@tool` script, so the editor
# cannot instantiate one at all (`can_instantiate()` is false there) and reflecting it would give
# this file a vocabulary in a headless run and nothing in the editor, which is exactly the wrong way
# round. The `## @ace_*` annotations on disk are the same words the picker builds itself from, so
# reading them is reading the pack's own vocabulary in the one form that is always there.
#
# The two small tables below are OVERRIDE lists, not the vocabulary: which family a word's stripe
# is coloured by, and the one word whose derived title would collide with a timing word's. A word
# in neither still gets a card - an uncoloured one, under its own name.
#
# A NEW CARD IS A FILE STEP. Every derived kind seeds all four of a moment file's keys, whether its
# word reads the extra one or not, so a card added here and a step written in a file are the same
# dictionary and neither has to be converted into the other.
#
# NOTHING HERE DRAWS. The schema is plain data plus one callable, which is what lets the suite pin
# the whole vocabulary without an editor, an Inspector or a running game.
@tool
class_name EventSheetFeedbackCardSchema
extends RefCounted

## The name the Juice Player's export marker asks for, and the name the plugin registers.
const SCHEMA_NAME: String = "feedback_steps"

## The pack the ten words come from, and the verb that lists them.
const JUICE_PACK_PATH: String = "res://eventsheet_addons/juice/juice_behavior.gd"
const STEP_VERB: String = "moment_step"

## The keys one card carries. The first four are a moment file's own, which is what makes a file's
## step a valid card and a plain card a valid file step.
const WORD_KEY: String = "verb"
const AMOUNT_KEY: String = "amount"
const EFFECT_KEY: String = "effect"
const SECONDS_KEY: String = "seconds"
const LABEL_KEY: String = "label"
const ENABLED_KEY: String = "active"

## The words this node adds to the ten - spelled the same here and in the pack, because the pack is
## what plays them.
const PAUSE: String = "pause"
const HOLD_UNTIL: String = "hold_until"
const LOOP_START: String = "loop_start"
const LOOP_BACK: String = "loop_back"
const TWEEN_PROPERTY: String = "tween_property"
const EMIT_SIGNAL: String = "emit_signal"
const PLAY_PLAYER: String = "play_player"

## The word of the card that plays a sound, and the two that end or move one.
const SOUND: String = "sound"
const STOP_SOUND: String = "stop_sound"
const FADE_BUS: String = "fade_bus"
const VIBRATE: String = "vibrate"

## The key a Hold names the card it waits for under.
const WAITS_FOR: String = "waits_for"

## The editor-side file that plays things for a moment and puts them back: Listen on a Sound card, and
## the strip's play buttons. By path, so the first open of the editor does not compile it.
const PREVIEW_PATH: String = "res://addons/eventsheet/editor/inspector/juice_preview.gd"

## The strip of buttons that plays the whole list, drawn under it.
const STRIP_PATH: String = "res://addons/eventsheet/editor/inspector/feedback_player_strip.gd"

## The file that says where the Juice Player's code is, which is where a word's FAMILY is written down.
const NAMES_PATH: String = "res://addons/eventsheet/editor/inspector/juice_player_names.gd"
const FAMILY_CONSTANT: String = "CATEGORY_OF"

## The one derived title that would collide with a timing word's. The pack's screen-effect "hold"
## and the list's own Hold are different things, and two cards called Hold in one dropdown is a
## dropdown nobody can use. An OVERRIDE list of one, for exactly that reason.
const TITLE_OF: Dictionary = {"hold": "Hold Effect"}

## The one word the pack spells more than one way. A word with no verb of its own takes the first
## verb whose name it begins - which is right for zoom, chromatic and pulse, and wrong for punch,
## because the pack publishes a punch of the scale, the rotation and the position and the step word
## means the first of them. An OVERRIDE naming the VERB rather than the title, so the card is still
## titled and explained by whatever that verb says about itself.
const VERB_OF: Dictionary = {"punch": "punch_scale"}

## What a NEW card of three words starts with, because the amount means something different for each
## and 1.0 does nothing: a hitstop's amount is the time scale it freezes to (0 is a full stop, and it
## needs a length to be felt), a slowmo's is the time scale it slows to, and a zoom's is a percentage.
## An OVERRIDE list: every other word starts at 1.0 for 0 s. Only a card ADDED here takes these - a
## stored card keeps the numbers it was saved with.
const SEEDS: Dictionary = {
	"hitstop": {"amount": 0.0, "seconds": 0.08},
	"slowmo": {"amount": 0.3, "seconds": 0.3},
	"zoom": {"amount": 110.0, "seconds": 0.2}
}

## The words whose `effect` key means something. The other seven carry an amount and a duration and
## nothing else, so their cards do not offer a field that would never be read.
const EFFECT_WORDS: PackedStringArray = ["flash", "pulse", "hold"]

## The stripe colour per family. The drawer derives a colour from any word it is handed, so this is
## the small set the eye has to tell apart at a glance rather than a colour per verb.
const STRIPES: Dictionary = {
	"audio": "#E061A8",
	"transform": "#4C8DF0",
	"camera": "#8B63E0",
	"screen": "#39B8A8",
	"pause": "#59B85C",
	"scene": "#F2C744",
	"device": "#F08A2B",
	"loop": "#9A9A9A",
	"signal": "#9A9A9A"
}

## The same families for a light editor. The dark colours read 3:1 on a dark card line and several of
## them do not on a light one (the yellow reads 1.5:1), so a light editor draws these: the same hue,
## darkened until it reaches 3:1 on the light card line.
const STRIPES_LIGHT: Dictionary = {
	"audio": "#dd60a6",
	"transform": "#4C8DF0",
	"camera": "#8B63E0",
	"screen": "#309c8e",
	"pause": "#4d9f4f",
	"scene": "#a88a2f",
	"device": "#cf7725",
	"loop": "#8d8d8d",
	"signal": "#8d8d8d"
}

## What a family is called where a person reads it: a heading in the Add box. The words a family is
## saved and muted by do not change (a card keeps `audio`, the Mute row offers `audio`); only the words
## shown do. Loop and signal cards are both Flow.
const GROUPS: Dictionary = {
	"audio": "Sound",
	"scene": "Scene",
	"transform": "Object",
	"device": "Device",
	"camera": "Camera",
	"screen": "Screen",
	"pause": "Time",
	"loop": "Flow",
	"signal": "Flow"
}

## The order the headings come in.
const GROUP_ORDER: PackedStringArray = ["Sound", "Scene", "Object", "Device", "Camera", "Screen", "Time", "Flow"]

## The pack, read once per session: a file on disk that does not change while the editor is open.
static var _reading_cache: Dictionary = {}
static var _reading_done: bool = false

## And the family table, read once for the same reason.
static var _family_cache: Dictionary = {}
static var _family_done: bool = false


## Which family a word's stripe is coloured by. NOT written here: it is the Juice Player's own
## CATEGORY_OF, read off the shipped pack, because the running game asks the same question when Mute
## Feedback Category decides what to skip and a word must not be able to belong to one family in the
## Inspector and another in the game. Still an OVERRIDE list at the far end - a word the pack does
## not place takes the uncategorised colour under its own name.
##
## The constant is read off the SCRIPT rather than off an instance: a pack script is not a `@tool`
## script and cannot be instantiated in the editor at all, but its constants are known the moment it
## is loaded. A project that deleted the pack reads an empty table and colours by word.
static func family_of() -> Dictionary:
	if _family_done:
		return _family_cache
	_family_done = true
	var player_path: String = str(load(NAMES_PATH).pack_path())
	var pack: GDScript = load(player_path) as GDScript if ResourceLoader.exists(player_path) else null
	if pack == null:
		return _family_cache
	var declared: Variant = pack.get_script_constant_map().get(FAMILY_CONSTANT)
	if declared is Dictionary:
		_family_cache = declared as Dictionary
	return _family_cache


## The whole vocabulary: the ten derived words first, in the order the pack lists them, then the
## timing words, then the three that are not a feeling.
static func schema() -> Dictionary:
	var kinds: Array = []
	kinds.append_array(derived_kinds(pack_reading()))
	kinds.append_array(sound_kinds())
	kinds.append_array(sound_control_kinds())
	kinds.append_array(timing_kinds())
	kinds.append_array(other_kinds())
	return {
		"kinds": kinds,
		"label_key": LABEL_KEY,
		"enabled_key": ENABLED_KEY,
		"stripes": STRIPES,
		"stripes_light": STRIPES_LIGHT,
		"groups": GROUPS,
		"group_order": GROUP_ORDER,
		"tiles": true,
		"together": start_together,
		"footer": strip_footer,
		"marks": {"run": play_card}
	}


## The Juice pack's vocabulary, read once and kept for the session.
static func pack_reading() -> Dictionary:
	if not _reading_done:
		_reading_done = true
		_reading_cache = read_pack(JUICE_PACK_PATH)
	return _reading_cache


## One pack script read as its own annotations: {words, verbs, params}. `words` is the option list
## on the step verb's word parameter, `verbs` maps a function name to the title and help the picker
## reads out for it, and `params` is the step verb's own parameters by id. An absent pack reads as
## empty rather than failing: a project that deleted the Juice pack still edits its saved lists.
static func read_pack(script_path: String) -> Dictionary:
	var reading: Dictionary = {"words": PackedStringArray(), "verbs": {}, "params": {}}
	if not FileAccess.file_exists(script_path):
		return reading
	var title: String = ""
	var help: String = ""
	# The plain `##` prose above a verb, which IS its help when it carries no `@ace_description` -
	# the shape a pack ships whenever its author wrote an ordinary Godot doc comment. Read the same
	# way the rest of the plugin reads it: skip the annotation lines, join the rest with a space.
	var prose: PackedStringArray = PackedStringArray()
	var params: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(script_path).split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("## @ace_name("):
			title = _quoted_value(trimmed)
		elif trimmed.begins_with("## @ace_description("):
			help = _quoted_value(trimmed)
		elif trimmed.begins_with("##") and not trimmed.begins_with("## @"):
			var text: String = trimmed.trim_prefix("##").strip_edges()
			if not text.is_empty():
				prose.append(text)
		elif trimmed.begins_with("## @ace_param("):
			var parsed: Dictionary = _param_line(trimmed)
			if not parsed.is_empty():
				params[str(parsed.get("id"))] = parsed
		elif trimmed.begins_with("func ") or trimmed.begins_with("static func "):
			var member: String = trimmed.trim_prefix("static ").substr(5).get_slice("(", 0).strip_edges()
			if not title.is_empty():
				(reading["verbs"] as Dictionary)[member] = {
					"label": title,
					"help": help if not help.is_empty() else " ".join(prose)
				}
			if member == STEP_VERB:
				reading["words"] = (params.get(WORD_KEY, {}) as Dictionary).get("options", PackedStringArray())
				reading["params"] = params
			title = ""
			help = ""
			prose = PackedStringArray()
			params = {}
		elif not trimmed.is_empty():
			# A real line of code that is not a function header ends the run of doc comments above it,
			# so prose written over a variable cannot drift down onto the next verb.
			prose = PackedStringArray()
	return reading


## One kind per moment word, derived: the word list off the pack's step verb, the title and help off
## the pack verb of that name, and the fields off the step verb's own parameters. A word with no
## verb of its own (the screen stack answers some of them) keeps the word as its title, which is
## still the pack's own spelling rather than this file's.
static func derived_kinds(reading: Dictionary) -> Array:
	var verbs: Dictionary = reading.get("verbs") if reading.get("verbs") is Dictionary else {}
	var params: Dictionary = reading.get("params") if reading.get("params") is Dictionary else {}
	var kinds: Array = []
	for word: String in (reading.get("words") if reading.get("words") is PackedStringArray else PackedStringArray()):
		var named: String = str(VERB_OF.get(word, word))
		var twin: Dictionary = verbs.get(named, _verb_spelling_out(verbs, word + "_"))
		var fields: Array = [_param_field(params, AMOUNT_KEY, "num"), _param_field(params, SECONDS_KEY, "unit:time")]
		if EFFECT_WORDS.has(word):
			fields.insert(1, _param_field(params, EFFECT_KEY, "text"))
		kinds.append({
			"kind": word,
			"category": str(family_of().get(word, "")),
			"label": str(TITLE_OF.get(word, twin.get("label", word.capitalize()))),
			"help": str(twin.get("help", (params.get(WORD_KEY, {}) as Dictionary).get("help", ""))),
			"fields": fields,
			"live": [],
			"defaults": seeds_for(word),
			"badge": seconds_badge
		})
	return kinds


## The values a new card of a derived word starts with: the four keys a moment file's step holds, in
## the file's order, with the word's own seed where it has one.
static func seeds_for(word: String) -> Dictionary:
	var seed: Dictionary = SEEDS.get(word, {}) as Dictionary
	return {
		AMOUNT_KEY: float(seed.get(AMOUNT_KEY, 1.0)),
		EFFECT_KEY: "",
		SECONDS_KEY: float(seed.get(SECONDS_KEY, 0.0))
	}


## The Sound card: a stream picked with Godot's own resource picker (kept as the file's uid), how loud and
## how high with a little random either side so one file does not sound like a machine gun, which bus it
## plays on and whether it is placed in space, and a Listen button that plays it alone. Its length is the
## stream's length at its pitch, so it has no Seconds field: the badge reads that off the file.
static func sound_kinds() -> Array:
	return [
		{
			"kind": SOUND,
			"category": str(family_of().get(SOUND, "")),
			"label": "Sound",
			"help": "Plays a sound when the list reaches this card. Muted with the Sound family, retimed with the rest, and scaled by the play strength when you tick Follows strength.",
			"fields": [
				{"key": "stream", "label": "Stream", "drawer": "resource:AudioStream", "default": ""},
				{"key": "sound_missing", "label": "", "drawer": "note", "text": sound_note, "visible_when": sound_needs_care, "warn_when": sound_needs_care},
				{"key": "volume_db", "label": "Volume", "drawer": "num", "default": 0.0, "suffix": "dB"},
				{"key": "volume_spread_db", "label": "Random volume", "drawer": "spread", "default": 2.0, "suffix": "dB"},
				{"key": "pitch", "label": "Pitch", "drawer": "num", "default": 1.0},
				{"key": "pitch_spread", "label": "Random pitch", "drawer": "spread", "default": 0.1},
				{"key": "pitch_range", "label": "", "drawer": "note", "text": pitch_note},
				{"key": "bus", "label": "Bus", "drawer": "bus", "default": "Master"},
				{"key": "heard_from", "label": "Heard from", "drawer": "options:here=This object,everywhere=Everywhere", "default": "here"},
				{"key": "follows_strength", "label": "Follows strength", "drawer": "bool", "default": false},
				{"key": "delay", "label": "Delay", "drawer": "num", "unset": 0.0, "suffix": "s"},
				{"key": "listen", "label": "Listen", "drawer": "custom", "build": listen_row}
			],
			"live": [],
			"defaults": {"stream": "", "volume_db": 0.0, "volume_spread_db": 2.0, "pitch": 1.0, "pitch_spread": 0.1, "bus": "Master", "heard_from": "here", "follows_strength": false},
			"badge": seconds_badge
		}
	]


## The cards that end a sound, move a bus and rumble the hand. None of them is felt in the editor, so Debug
## view names each as skipped rather than faking it.
static func sound_control_kinds() -> Array:
	return [
		{
			"kind": STOP_SOUND,
			"category": str(family_of().get(STOP_SOUND, "")),
			"label": "Stop Sound",
			"help": "Stops the sound an earlier Sound card started, by that card's name, with a fade if you want one: a charge-up hum that ends on release. Pick no card to stop every sound this player has going.",
			"fields": [
				{"key": EFFECT_KEY, "label": "Sound card", "drawer": "above", "above": sound_cards_above,
					"all_label": EventSheetL10n.translate("Every sound of this player")},
				{"key": SECONDS_KEY, "label": "Fade out", "drawer": "unit:time", "default": 0.0}
			],
			"live": [],
			"defaults": {EFFECT_KEY: "", SECONDS_KEY: 0.0},
			"badge": seconds_badge
		},
		{
			"kind": FADE_BUS,
			"category": str(family_of().get(FADE_BUS, "")),
			"label": "Fade Bus",
			"help": "Moves a bus volume to a value over a time: duck the music under a big hit. Restore puts the volume back.",
			"fields": [
				{"key": EFFECT_KEY, "label": "Bus", "drawer": "bus", "default": "Master"},
				{"key": AMOUNT_KEY, "label": "To", "drawer": "num", "default": -12.0, "suffix": "dB"},
				{"key": SECONDS_KEY, "label": "Over", "drawer": "unit:time", "default": 0.3}
			],
			"live": [],
			"defaults": {EFFECT_KEY: "Master", AMOUNT_KEY: -12.0, SECONDS_KEY: 0.3},
			"badge": seconds_badge
		},
		{
			"kind": VIBRATE,
			"category": str(family_of().get(VIBRATE, "")),
			"label": "Vibrate",
			"help": "Rumbles every connected controller, the weak motor and the strong one, and buzzes a phone, for a time. Does nothing on the web. Scaled by the strength of the play.",
			"fields": [
				{"key": "weak", "label": "Weak motor", "drawer": "num", "default": 0.5},
				{"key": "strong", "label": "Strong motor", "drawer": "num", "default": 0.5},
				{"key": SECONDS_KEY, "label": "For", "drawer": "unit:time", "default": 0.2}
			],
			"live": [],
			"defaults": {"weak": 0.5, "strong": 0.5, SECONDS_KEY: 0.2},
			"badge": seconds_badge
		}
	]


## Which cards start together: one number per card, the same for the felt cards between two words that move
## the head, and -1 for a card that stands apart (Pause, Hold, the two loop words).
static func start_together(cards: Array) -> Array:
	var ids: Array = []
	var group: int = 0
	var open_run: bool = false
	for card: Variant in cards:
		var word: String = str((card as Dictionary).get(WORD_KEY, "")).strip_edges().to_lower()
		if [PAUSE, HOLD_UNTIL, LOOP_START, LOOP_BACK].has(word):
			if open_run:
				group += 1
			open_run = false
			ids.append(-1)
		else:
			open_run = true
			ids.append(group)
	return ids


## The name a card answers to in the running game, which is what a Hold stores when it waits for it.
static func pack_name_of(card: Dictionary) -> String:
	return str(load(str(load(NAMES_PATH).pack_path())).call("card_label", card))


## What a card is called where a person reads it: its own name, else its kind's title.
static func shown_name_of(card: Dictionary) -> String:
	var named: String = str(card.get(LABEL_KEY, "")).strip_edges()
	if not named.is_empty():
		return named
	var entry: Dictionary = EventSheetCardSchemas.kind_entry(schema(), str(card.get(WORD_KEY, "")))
	return str(entry.get("label", str(card.get(WORD_KEY, "")).capitalize()))


## The cards a Hold at `index` can be told to wait for: the felt cards between it and the Hold above it.
static func cards_a_hold_can_wait_for(cards: Array, index: int) -> Array:
	var found: Array = []
	var walk: int = index - 1
	while walk >= 0:
		var card: Dictionary = cards[walk] as Dictionary
		var word: String = str(card.get(WORD_KEY, "")).strip_edges().to_lower()
		if word == HOLD_UNTIL:
			break
		if not [PAUSE, LOOP_START, LOOP_BACK].has(word):
			found.push_front({"value": pack_name_of(card), "text": shown_name_of(card)})
		walk -= 1
	return found


## The Sound cards above a Stop Sound card, by name.
static func sound_cards_above(cards: Array, index: int) -> Array:
	var found: Array = []
	for walk: int in range(mini(index, cards.size())):
		var card: Dictionary = cards[walk] as Dictionary
		if str(card.get(WORD_KEY, "")).strip_edges().to_lower() == SOUND:
			found.append({"value": pack_name_of(card), "text": shown_name_of(card)})
	return found


## How long a Hold will wait: what is left of the cards it waits for when the head reaches it, then its own
## wait. The same function the running game waits by.
static func hold_wait(card: Dictionary, cards: Array, index: int) -> float:
	var pack: Script = load(str(load(NAMES_PATH).pack_path())) as Script
	var left: float = float(pack.call("left_above", cards, index)) if pack != null and index >= 0 else 0.0
	return left + maxf(float(card.get(SECONDS_KEY, 0.0)), 0.0) + maxf(float(card.get("delay", 0.0)), 0.0)


static func hold_badge(card: Dictionary, cards: Array, index: int) -> String:
	return "%.2f s" % hold_wait(card, cards, index)


## The line under a Hold's fields: how long it waits and for what.
static func hold_note(card: Dictionary, cards: Array, index: int) -> String:
	var waited: String = EventSheetL10n.translate("all the cards above")
	var wanted: String = str(card.get(WAITS_FOR, "")).strip_edges()
	if not wanted.is_empty():
		for entry: Variant in cards_a_hold_can_wait_for(cards, index):
			if str((entry as Dictionary).get("value", "")) == wanted:
				waited = str((entry as Dictionary).get("text", wanted))
	var said: String = EventSheetL10n.translate("Waiting %.2f s, for %s.") % [hold_wait(card, cards, index), waited]
	if hold_names_nothing(card, cards, index):
		said += " " + EventSheetL10n.translate("No card called \"%s\" is above this Hold, so it waits for all of them.") % wanted
	return said


## Whether the Hold names a card that is not above it any more.
static func hold_names_nothing(card: Dictionary, cards: Array, index: int) -> bool:
	var wanted: String = str(card.get(WAITS_FOR, "")).strip_edges()
	if wanted.is_empty():
		return false
	for entry: Variant in cards_a_hold_can_wait_for(cards, index):
		if str((entry as Dictionary).get("value", "")) == wanted:
			return false
	return true


## The strip under the list: the head line, the buttons that play the list in the editor and the debug
## timeline. Built once for the object being edited, and handed the drawer so it can light the card
## that is sounding.
static func strip_footer(object: Object, drawer: Control) -> Control:
	return load(STRIP_PATH).new(object, drawer) as Control


## What a card's play mark and the "Play from here" entry of its menu do: ask the strip under this list to
## play that part of it ("play_one", "play_from") or to stop ("stop").
static func play_card(object: Object, action: String, index: int) -> void:
	load(PREVIEW_PATH).call("card_action", object, action, index)


## The grey line under the pitch: the range a random roll lands in.
static func pitch_note(card: Dictionary) -> String:
	var middle: float = float(card.get("pitch", 1.0))
	var spread: float = maxf(float(card.get("pitch_spread", 0.0)), 0.0)
	return EventSheetL10n.translate("Each play lands between %.2f and %.2f.") % [maxf(middle - spread, 0.05), middle + spread]


## What is wrong with the sound a Sound card names, in words, or nothing when it is fine.
static func sound_note(card: Dictionary) -> String:
	var path: String = str(card.get("stream", ""))
	if path.is_empty():
		return EventSheetL10n.translate("Pick a sound. Until then this card is silent.")
	if not ResourceLoader.exists(path):
		return EventSheetL10n.translate("That sound is not in the project any more, so this card is silent.")
	return ""


## Whether the sound note has anything to say.
static func sound_needs_care(card: Dictionary) -> bool:
	return not sound_note(card).is_empty()


## The Listen row, built by the preview file the first time a Sound card is opened.
static func listen_row(_card: Dictionary, current: Callable, _edited: Object) -> Control:
	return load(PREVIEW_PATH).call("listen_control", current)


## The four words that move the head instead of being felt. Written here rather than derived,
## because there is no verb behind them: they are what a LIST can say that a file cannot.
static func timing_kinds() -> Array:
	return [
		{
			"kind": PAUSE,
			"category": str(family_of().get(PAUSE, "")),
			"label": "Pause",
			"help": "Waits this long before the next card, whatever the cards above are still doing.",
			"fields": [{"key": SECONDS_KEY, "label": "Pause", "drawer": "unit:time", "default": 0.25}],
			"live": [],
			"defaults": {SECONDS_KEY: 0.25},
			"search": PackedStringArray(["wait", "delay", "gap"]),
			"badge": seconds_badge
		},
		{
			"kind": HOLD_UNTIL,
			"category": str(family_of().get(HOLD_UNTIL, "")),
			"label": "Hold",
			"help": "Waits for the slowest card above to finish, or for the one card you pick, then this long. What is under a hold is what happens AFTER the hit rather than during it.",
			"fields": [
				{"key": WAITS_FOR, "label": "Waits for", "drawer": "above", "above": cards_a_hold_can_wait_for,
					"all_label": EventSheetL10n.translate("All cards above")},
				{"key": SECONDS_KEY, "label": "Then wait", "drawer": "unit:time", "default": 0.0},
				{"key": "hold_note", "label": "", "drawer": "note", "text": hold_note, "warn_when": hold_names_nothing}
			],
			"live": [],
			"defaults": {SECONDS_KEY: 0.0},
			"search": PackedStringArray(["wait", "until", "after"]),
			"badge": hold_badge
		},
		{
			"kind": LOOP_START,
			"category": str(family_of().get(LOOP_START, "")),
			"label": "Loop Start",
			"help": "Marks where a Loop Back below sends the head. A list with no Loop Start loops back to its last Hold instead.",
			"fields": [],
			"live": [],
			"defaults": {},
			"badge": seconds_badge
		},
		{
			"kind": LOOP_BACK,
			"category": str(family_of().get(LOOP_BACK, "")),
			"label": "Loop Back",
			"help": "Moves the head back to the last Hold or Loop Start above, a number of times, pausing each time it lands.",
			"fields": [
				{"key": SECONDS_KEY, "label": "Pause", "drawer": "unit:time", "default": 0.25},
				{"key": "to_hold", "label": "Loop to last Hold", "drawer": "bool", "default": true},
				{"key": "to_loop_start", "label": "Loop to last Loop Start", "drawer": "bool", "default": true},
				{"key": "loops", "label": "Loops", "drawer": "int", "default": 2}
			],
			"live": [{"key": "loops_left", "label": "Loops left"}],
			"defaults": {SECONDS_KEY: 0.25, "loops": 2},
			"badge": seconds_badge
		}
	]


## The three cards that are not a feeling and not a wait: a value walked, a word said, another
## player played. They are what keeps a list from having to leave the Inspector for the one step
## that is about this object rather than about the screen.
static func other_kinds() -> Array:
	return [
		{
			"kind": TWEEN_PROPERTY,
			"category": str(family_of().get(TWEEN_PROPERTY, "")),
			"label": "Tween Property",
			"help": "Walks one property of the object this player is under to a value, over a time. Restore Initial Values puts it back.",
			"fields": [
				{"key": EFFECT_KEY, "label": "Property", "drawer": "text", "default": "rotation"},
				{"key": AMOUNT_KEY, "label": "To", "drawer": "num", "default": 1.0},
				{"key": SECONDS_KEY, "label": "Over", "drawer": "unit:time", "default": 0.2}
			],
			"live": [],
			"defaults": {EFFECT_KEY: "", AMOUNT_KEY: 1.0, SECONDS_KEY: 0.2},
			"badge": seconds_badge
		},
		{
			"kind": EMIT_SIGNAL,
			"category": str(family_of().get(EMIT_SIGNAL, "")),
			"label": "Emit Signal",
			"help": "Says one word out of the player's On Juice Signal trigger, so a sheet can hang anything at all off a point in the list.",
			"fields": [{"key": EFFECT_KEY, "label": "Word", "drawer": "text", "default": ""}],
			"live": [],
			"defaults": {EFFECT_KEY: ""},
			"badge": seconds_badge
		},
		{
			"kind": PLAY_PLAYER,
			"category": str(family_of().get(PLAY_PLAYER, "")),
			"label": "Play Player",
			"help": "Plays another Juice Player from inside this one, at a share of this play's strength - which is how a whole object's beat is built out of the beats of its parts.",
			"fields": [
				{"key": EFFECT_KEY, "label": "Player", "drawer": "text", "default": ""},
				{"key": AMOUNT_KEY, "label": "Strength", "drawer": "num", "default": 1.0}
			],
			"live": [],
			"defaults": {EFFECT_KEY: "", AMOUNT_KEY: 1.0},
			"badge": seconds_badge
		}
	]


## The badge on the right of every card: how long that card takes, including the delay it waits
## first. One function for every kind, so the badges of a list add up to the head's own number.
static func seconds_badge(card: Dictionary) -> String:
	return "%.2f s" % card_seconds(card)


## How long one card takes: its own duration plus the delay before it. The number the badge shows
## and the number the longest path is measured with.
static func card_seconds(card: Dictionary) -> float:
	var pack: Script = load(str(load(NAMES_PATH).pack_path())) as Script if str(card.get(WORD_KEY, "")) == SOUND else null
	var own: float = float(pack.call("card_length", card)) if pack != null else maxf(float(card.get(SECONDS_KEY, 0.0)), 0.0)
	return own + maxf(float(card.get("delay", 0.0)), 0.0)


## The verb whose name begins with a prefix - how a word finds the verb that spells it out in full
## ("punch" finding Punch Scale), without a table saying which is which. Function names only, so a
## signal called On Punch Finished can never be mistaken for the verb.
static func _verb_spelling_out(verbs: Dictionary, prefix: String) -> Dictionary:
	var names: Array = verbs.keys()
	names.sort()
	for member: Variant in names:
		if str(member).begins_with(prefix):
			return verbs[member]
	return {}


## One of the step verb's parameters as one card field, keeping the pack's own help.
static func _param_field(params: Dictionary, key: String, drawer: String) -> Dictionary:
	var parameter: Dictionary = params.get(key, {})
	return {
		"key": key,
		"label": key.capitalize(),
		"drawer": drawer,
		"help": str(parameter.get("help", ""))
	}


## The text inside an annotation written as `## @ace_thing("...")`.
static func _quoted_value(line: String) -> String:
	var opened: int = line.find("(\"")
	if opened < 0 or not line.ends_with("\")"):
		return ""
	return line.substr(opened + 2, line.length() - opened - 4)


## One `## @ace_param(id, options: a|b|c, default: x, desc: "...")` line as {id, options, help}. The
## three parts are read by name rather than by position, because a parameter declares only the ones
## it has.
static func _param_line(line: String) -> Dictionary:
	var opened: int = line.find("(")
	if opened < 0 or not line.ends_with(")"):
		return {}
	var inside: String = line.substr(opened + 1, line.length() - opened - 2)
	var parameter_id: String = inside.get_slice(",", 0).strip_edges()
	if parameter_id.is_empty():
		return {}
	var options: PackedStringArray = PackedStringArray()
	var listed: int = inside.find("options: ")
	if listed >= 0:
		var tail: String = inside.substr(listed + 9)
		var ends: int = tail.find(",")
		options = (tail.substr(0, ends) if ends >= 0 else tail).strip_edges().split("|", false)
	var help: String = ""
	var said: int = inside.find("desc: \"")
	if said >= 0:
		help = inside.substr(said + 7).trim_suffix("\"")
	return {"id": parameter_id, "options": options, "help": help}
