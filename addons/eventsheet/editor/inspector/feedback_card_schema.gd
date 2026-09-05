# Godot EventSheets - the card vocabulary a Feedback Player's list is edited with (editor-only,
# UI-free).
#
# A Feedback Player holds an Array of Dictionaries, and each dictionary is one felt thing: the same
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

## The name the Feedback Player's export marker asks for, and the name the plugin registers.
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

## The Feedback Player itself, which is where a word's FAMILY is written down.
const PLAYER_PATH: String = "res://eventsheet_addons/juice/feedback_player.gd"
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

## The words whose `effect` key means something. The other seven carry an amount and a duration and
## nothing else, so their cards do not offer a field that would never be read.
const EFFECT_WORDS: PackedStringArray = ["flash", "pulse", "hold"]

## The stripe colour per family. The drawer derives a colour from any word it is handed, so this is
## the small set the eye has to tell apart at a glance rather than a colour per verb.
const STRIPES: Dictionary = {
	"audio": "#b06fc4",
	"transform": "#4f8fd6",
	"camera": "#7b5fd0",
	"screen": "#3fa9a0",
	"pause": "#4faf74",
	"loop": "#d98b3a",
	"signal": "#c76fa8"
}

## The pack, read once per session: a file on disk that does not change while the editor is open.
static var _reading_cache: Dictionary = {}
static var _reading_done: bool = false

## And the family table, read once for the same reason.
static var _family_cache: Dictionary = {}
static var _family_done: bool = false


## Which family a word's stripe is coloured by. NOT written here: it is the Feedback Player's own
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
	var pack: GDScript = load(PLAYER_PATH) as GDScript if ResourceLoader.exists(PLAYER_PATH) else null
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
	kinds.append_array(timing_kinds())
	kinds.append_array(other_kinds())
	return {
		"kinds": kinds,
		"label_key": LABEL_KEY,
		"enabled_key": ENABLED_KEY,
		"stripes": STRIPES
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
	var params: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(script_path).split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("## @ace_name("):
			title = _quoted_value(trimmed)
		elif trimmed.begins_with("## @ace_description("):
			help = _quoted_value(trimmed)
		elif trimmed.begins_with("## @ace_param("):
			var parsed: Dictionary = _param_line(trimmed)
			if not parsed.is_empty():
				params[str(parsed.get("id"))] = parsed
		elif trimmed.begins_with("func ") or trimmed.begins_with("static func "):
			var member: String = trimmed.trim_prefix("static ").substr(5).get_slice("(", 0).strip_edges()
			if not title.is_empty():
				(reading["verbs"] as Dictionary)[member] = {"label": title, "help": help}
			if member == STEP_VERB:
				reading["words"] = (params.get(WORD_KEY, {}) as Dictionary).get("options", PackedStringArray())
				reading["params"] = params
			title = ""
			help = ""
			params = {}
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
			"defaults": {AMOUNT_KEY: 1.0, EFFECT_KEY: "", SECONDS_KEY: 0.0},
			"badge": seconds_badge
		})
	return kinds


## The four words that move the head instead of being felt. Written here rather than derived,
## because there is no verb behind them: they are what a LIST can say that a file cannot.
static func timing_kinds() -> Array:
	return [
		{
			"kind": PAUSE,
			"category": "pause",
			"label": "Pause",
			"help": "Waits this long before the next card, whatever the cards above are still doing.",
			"fields": [{"key": SECONDS_KEY, "label": "Pause", "drawer": "unit:time", "default": 0.25}],
			"live": [],
			"defaults": {SECONDS_KEY: 0.25},
			"badge": seconds_badge
		},
		{
			"kind": HOLD_UNTIL,
			"category": "pause",
			"label": "Hold",
			"help": "Waits for the slowest card above to finish, then this long. What is under a hold is what happens AFTER the hit rather than during it.",
			"fields": [{"key": SECONDS_KEY, "label": "Then wait", "drawer": "unit:time", "default": 0.0}],
			"live": [],
			"defaults": {SECONDS_KEY: 0.0},
			"badge": seconds_badge
		},
		{
			"kind": LOOP_START,
			"category": "loop",
			"label": "Loop Start",
			"help": "Marks where a Loop Back below sends the head. A list with no Loop Start loops back to its last Hold instead.",
			"fields": [],
			"live": [],
			"defaults": {},
			"badge": seconds_badge
		},
		{
			"kind": LOOP_BACK,
			"category": "loop",
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
			"category": "transform",
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
			"category": "signal",
			"label": "Emit Signal",
			"help": "Says one word out of the player's On Feedback Signal trigger, so a sheet can hang anything at all off a point in the list.",
			"fields": [{"key": EFFECT_KEY, "label": "Word", "drawer": "text", "default": ""}],
			"live": [],
			"defaults": {EFFECT_KEY: ""},
			"badge": seconds_badge
		},
		{
			"kind": PLAY_PLAYER,
			"category": "",
			"label": "Play Player",
			"help": "Plays another Feedback Player from inside this one, at a share of this play's strength - which is how a whole object's beat is built out of the beats of its parts.",
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
	return maxf(float(card.get(SECONDS_KEY, 0.0)), 0.0) + maxf(float(card.get("delay", 0.0)), 0.0)


## The timing every card carries whatever its kind is - the fields the unfolded card's Timing
## foldout shows. Offered as one list so a caller adds them to a kind's own fields rather than
## spelling them per kind.
static func timing_fields() -> Array:
	return [
		{"key": "delay", "label": "Initial delay", "drawer": "unit:time", "default": 0.0},
		{"key": "cooldown", "label": "Cooldown", "drawer": "unit:time", "default": 0.0},
		{"key": "repeat", "label": "Repeat", "drawer": "int", "default": 1},
		{"key": "interval", "label": "Interval", "drawer": "unit:time", "default": 0.0},
		{"key": "clock", "label": "Clock", "drawer": "toggle_row:game,real", "default": "game"},
		{"key": "min_strength", "label": "Only if strength over", "drawer": "num", "default": 0.0},
		{"key": "max_strength", "label": "and under", "drawer": "num", "default": 0.0},
		{"key": "skip_on_stop", "label": "Skip on stop", "drawer": "bool", "default": false},
		{"key": "chance", "label": "Chance", "drawer": "progress_bar:0:100", "default": 100.0}
	]


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
