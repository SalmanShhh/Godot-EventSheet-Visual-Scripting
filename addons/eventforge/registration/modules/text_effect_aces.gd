# EventForge module - text that MOVES: the six effects a rich text label already knows, and the
# reveal that types a line out one character at a time.
#
# Godot's RichTextLabel ships wave, shake, tornado, rainbow, fade and pulse as BBCode tags, and a
# seventh door - install_effect - for a RichTextEffect you wrote yourself. None of them had a word on
# the sheet, so a title that wobbles was a tag typed by hand into a string and a custom effect was a
# class nobody found. These rows say it.
#
#  - EFFECTS: Set Text With Effect writes the engine's own tag around the words. Wrap Selection In
#    Effect puts the same tag around a stretch of the text that is already there, so a name inside a
#    sentence can shake while the sentence does not. Clear Effects takes every tag back off, and
#    Effect Is Active asks whether one is on. Install Text Effect is the custom door: a RichTextEffect
#    resource out of a folder you own becomes a word the "custom" choice writes.
#  - REVEAL: Reveal Text types a line out at so many characters a second, with an optional sound per
#    character. Skip Reveal ends it now, Is Revealing and Revealed Fraction read it, Pause Reveal At
#    holds a beat at one character (the comma pause), and On Reveal Finished is where the next thing
#    starts. The Dialogue Kit keeps its own typewriter - these are for every other label.
#
# TWO ACCESSIBILITY SETTINGS ARE READ BY EVERY EFFECT ROW, because an effect nobody can look at is
# not a feature. Both are the shipped Engine metas the Game Accessibility shelf sets:
#   * "text_size_scale" multiplies the effect's own knob, so an effect grows with the text it is
#     drawn on rather than staying the size it was designed at.
#   * "no_flashing" calms what flashes: a shake drops to a third of its strength - a drift rather
#     than a rattle - and the two COLOUR-CYCLING effects, rainbow and pulse, go to a frequency of
#     zero, which is the engine's own way of spelling "hold still". Both are read at the moment the
#     row runs, so a player turning the setting on mid-game is answered by the next line of text.
#
# Verified against Godot 4.7 rather than assumed:
#   * bbcode_enabled starts FALSE, so a label handed a tag without it draws the tag as characters.
#     Every row that writes a tag turns it on in the line above, which is why those templates are two
#     statements rather than one.
#   * get_parsed_text() hands back the words with every tag stripped (the wave example below reads
#     back as "Starfall"), which is exactly what Clear Effects needs and means that row needs no tag
#     list of its own.
#   * visible_characters and visible_ratio are two faces of one number: setting visible_characters to
#     3 of 8 reads back as a ratio of 0.375, and setting the ratio to 1.0 reads back as -1 characters,
#     the engine's spelling for "all of them". So Is Revealing and Revealed Fraction ask the ratio,
#     which is total whichever face was written.
#   * get_total_character_count() counts the PARSED characters (8 for the wave example, not the 35
#     the tagged string holds), so a reveal times the words rather than the markup.
#   * RichTextLabel's own `finished` signal is about the document being LOADED, not about a reveal
#     ending - so On Reveal Finished is a named moment the reveal's own tween calls, exactly as the
#     archive rows call their three answers. A sheet with a Reveal Text row and no On Reveal Finished
#     event does not parse, which is the plainest way a missing answer can announce itself.
#
# Every template is plain GDScript over native calls: no plugin runtime, no helper library.
# ace_ids and codegen_templates are a compatibility covenant: frozen once shipped (deprecate, never rename).
@tool
class_name EventForgeTextEffectACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")
const CAT_TEXT := "Text"

## The label these rows belong to. Only RichTextLabel parses BBCode and only it counts characters, so
## a plain Label is deliberately not offered one of these rows.
const HOST := "RichTextLabel"

## The name a reveal parks its running tween under, so Skip Reveal can end the one that is going and a
## second Reveal Text cannot leave two tweens typing over each other. A plain meta name, readable in
## the remote inspector and settable by hand.
const REVEAL_META := "&\"reveal\""

## The name the comma pauses are parked under: a Dictionary of character index to seconds, written by
## Pause Reveal At and read by the reveal that follows it.
const PAUSES_META := "&\"reveal_pauses\""

## The function the reveal calls when the last character has landed. Named rather than connected,
## because there is no engine signal for it - the same seam the archive rows' three answers use.
const FINISHED_CALL := "_on_reveal_finished"

## THE TEXT DIAL, as an expression a row can multiply by. One number every text size multiplies by,
## set by the Game Accessibility shelf's Set Text Size Scale and 1.0 when nobody has touched it.
const TEXT_SCALE := "float(Engine.get_meta(\"text_size_scale\", 1.0))"

## THE CALM FACTOR for an effect that MOVES the letters. A third of the strength when the player has
## asked for no flashing, which turns a rattle into a drift without taking the emphasis away.
const CALM := "(0.3 if bool(Engine.get_meta(\"no_flashing\", false)) else 1.0)"

## THE STOP FACTOR for an effect that CYCLES COLOUR. Zero when the player has asked for no flashing:
## rainbow and pulse both take a frequency, and a frequency of zero is the engine's own way of
## holding the colour still rather than a second spelling invented here.
const STILL := "(0.0 if bool(Engine.get_meta(\"no_flashing\", false)) else 1.0)"

## THE SEVEN EFFECTS, as the things a row needs to write one: the word the picker shows, the opening
## tag with its one `%s` knob, the closing tag, and the expression that fills the knob.
##
## ONE TABLE, TWO ROWS. Set Text With Effect and Wrap Selection In Effect both write these tags - one
## around new words, one around words already on the label - so the tags are written down once and
## both templates are built from them. A seventh entry, "custom", spells its tag out of the field
## naming YOUR RichTextEffect instead of a fixed word, which is what makes the custom door the same
## row rather than a different one.
##
## Each entry says which accessibility factor that effect answers to, and the choice is the effect's
## own nature rather than a preference: the ones that move letters scale with the text, the shake
## calms, and the two that cycle colour stop.
##
## `amount` IS THE EFFECT'S OWN NATURAL NUMBER, and it is here because one Strength field cannot mean
## six different things. The knobs are not one scale: a wave's height is tens of pixels, a rainbow's
## frequency is about one, and a rainbow written at a wave's number cycles colour forty times a
## second - a strobe nobody asked for. So the field is a MULTIPLE of what the effect is drawn at by
## default, and each effect carries what that default is. 1 in the row means "as this effect is
## normally drawn", whichever effect the row picked.
const EFFECTS: Array[Dictionary] = [
	{"word": "wave", "open": "\"[wave amp=%s freq=5]\"", "close": "\"[/wave]\"", "amount": "40.0", "factor": TEXT_SCALE},
	{"word": "shake", "open": "\"[shake rate=20 level=%s]\"", "close": "\"[/shake]\"", "amount": "10.0", "factor": CALM},
	{"word": "tornado", "open": "\"[tornado radius=%s freq=2]\"", "close": "\"[/tornado]\"", "amount": "10.0", "factor": TEXT_SCALE},
	{"word": "rainbow", "open": "\"[rainbow freq=%s sat=0.8 val=0.8]\"", "close": "\"[/rainbow]\"", "amount": "1.0", "factor": STILL},
	{"word": "fade", "open": "\"[fade start=0 length=%s]\"", "close": "\"[/fade]\"", "amount": "4.0", "factor": TEXT_SCALE},
	{"word": "pulse", "open": "\"[pulse freq=%s color=#ffffff40 ease=-2.0]\"", "close": "\"[/pulse]\"", "amount": "1.0", "factor": STILL},
	{"word": "custom", "open": "(\"[\" + {custom} + \" strength=%s]\")", "close": "(\"[/\" + {custom} + \"]\")", "amount": "1.0", "factor": TEXT_SCALE},
]


## The expression that fills one effect's knob: the row's own dial, the effect's natural amount when
## that is not simply 1, and the accessibility factor the effect answers to. Written once here so the
## two templates and the lift family that reads their lines back can never spell it three ways.
static func knob_of(effect: Dictionary) -> String:
	var amount: String = str(effect.get("amount", "1.0"))
	var scaled: String = "{strength}" if amount == "1.0" else "{strength} * " + amount
	return scaled + " * " + str(effect.get("factor", TEXT_SCALE))


static func get_descriptors() -> Array[ACEDescriptor]:
	var d: Array[ACEDescriptor] = []

	# ── The effects the label already knows ──
	d.append(F.act("SetTextWithEffect", "Set Text With Effect", _set_template(), CAT_TEXT, "set text to {text} with [b]{effect}[/b]", "Puts words on a rich text label already wearing an effect: a title that waves, a warning that shakes, a legendary drop in a rainbow. It writes the engine's own tag around the text, so the label needs nothing installed and the emitted line is the line you would have typed. The strength is the one knob - bigger waves higher, shakes harder, fades longer - and it answers the player's text-size and no-flashing settings without a row of its own.", HOST).param("text", "\"Starfall\"", "Text", "The words to show. An expression, so a score, a name or a translated key all work.", "expression").param_built(_effect_param()).param("strength", "1.0", "Strength", "How much of the effect, as a multiple of the amount it is normally drawn at: 1 is that amount, 2 is twice as much, 0.5 is half. Each effect has its own natural number - a wave's height and a rainbow's speed are not the same kind of number - so this dial means the same thing whichever effect the row picks.", "expression").param_built(_custom_param()).param_built(_on_node_param()).featured())

	d.append(F.act("WrapSelectionInEffect", "Wrap Selection In Effect", _wrap_template(), CAT_TEXT, "wrap characters {from} to {to} in [b]{effect}[/b]", "Puts an effect around a STRETCH of the text already on the label, counted in characters, leaving the rest of the line alone. This is the row for one shaking word inside a calm sentence, or a name that glows where the sentence does not. It counts characters of the string the label holds, so wrap before you add more tags, not after.", HOST).param("from", "0", "From", "The character the effect starts at, counting from 0.", "expression").param("to", "5", "To", "The character it stops before. From 0 to 5 wraps the first five characters.", "expression").param_built(_effect_param()).param("strength", "1.0", "Strength", "How much of the effect, as a multiple of the amount it is normally drawn at - the same dial Set Text With Effect uses.", "expression").param_built(_custom_param()).param_built(_on_node_param()))

	d.append(F.act("ClearEffects", "Clear Effects", "{target.}text = {target.}get_parsed_text()", CAT_TEXT, "clear text effects", "Takes every effect back off and leaves the words. It asks the label for its own parsed text - the string with the tags stripped - so it clears effects nobody here wrote as well, and there is no list of tag names to keep up to date.", HOST).param_built(_on_node_param()))

	d.append(F.cond("EffectIsActive", "Effect Is Active", "text.contains(\"[{effect}\")", CAT_TEXT, "[b]{effect}[/b] is active", "True while the label's text carries that effect's tag. Ask it before writing another one, or to tell a shaking warning from a calm one without a variable beside it. Type the name of your own effect here to ask about that instead.", HOST).param_suggesting("effect", "wave", "Effect", "The effect to ask about - one of the engine's six, or the name your own RichTextEffect answers to.", _effect_words()))

	d.append(F.act("InstallTextEffect", "Install Text Effect", "install_effect({effect})", CAT_TEXT, "install text effect {effect}", "Teaches this label ONE effect you wrote yourself: a RichTextEffect resource out of a folder you own, whose bbcode name then works in a tag like any of the engine's six. Point Set Text With Effect at \"custom\" and type that same name to use it.", HOST).param_typed("Resource", "effect", "null", "Effect", "The RichTextEffect to install - load(\"res://text/effects/your_effect.gd\").new() for a script, or load(\"res://text/effects/your_effect.tres\") for a resource you saved.", "expression"))

	# ── The reveal: a line typed out, and the five words about it ──
	d.append(F.act("RevealText", "Reveal Text", _reveal_template(), CAT_TEXT, "reveal {text} at {chars_per_second} chars/s", "Types a line out one character at a time, at the speed you name. Any pause set by Pause Reveal At is held on the way, a sound plays on each character when you name one, and On Reveal Finished runs when the last character lands. Starting a second reveal on the same label ends the first, so a player who skips ahead never gets two lines typing over each other.", HOST).param("text", "\"The bridge is out.\"", "Text", "The line to type out. Tags are allowed - the count is of the words, not the markup.", "expression").param("chars_per_second", "40", "Chars per second", "How fast it types. About 40 reads like speech; 15 is slow and deliberate.", "expression").param_typed("Node", "sound", "null", "Sound", "A player to click on every character - point it at an AudioStreamPlayer node, e.g. $Blip. Left empty the reveal is silent.", "expression").param_built(_on_node_param()).featured())

	d.append(F.act("SkipReveal", "Skip Reveal", _skip_template(), CAT_TEXT, "skip the reveal", "Ends the reveal now and shows the whole line, then runs On Reveal Finished exactly as a reveal that finished on its own would. This is the second press of the button that started the line, and it is why the answer belongs in the trigger rather than after the Reveal Text row.", HOST).param_built(_on_node_param()).featured())

	d.append(F.cond("IsRevealing", "Is Revealing", "visible_ratio < 1.0", CAT_TEXT, "is revealing", "True while a line is still typing itself out. Ask it to make one button do both jobs: skip while it is revealing, go on to the next line when it is not.", HOST))

	d.append(F.expr("RevealedFraction", "Revealed Fraction", "visible_ratio", CAT_TEXT, "revealed fraction", "How much of the line is showing, from 0 to 1. The number to drive a progress bar, a portrait's mouth flap or a sound that gets quieter as the line ends.", HOST))

	d.append(F.act("PauseRevealAt", "Pause Reveal At", _pause_template(), CAT_TEXT, "pause the reveal at character {at} for {seconds} s", "Holds the reveal for a beat when it reaches one character - the comma pause that makes a typed line sound like speech rather than a printer. Drop it BEFORE the Reveal Text row: it writes the pause down on the label, and the reveal that follows reads it. Several pauses on one line are several rows.", HOST).param("at", "12", "At character", "Which character to hold on, counting from 1.", "expression").param("seconds", "0.4", "For", "How long to hold, in seconds.", "expression").param_built(_on_node_param()))

	d.append(F.trig("OnRevealFinished", "On Reveal Finished", "", CAT_TEXT, "On reveal finished", "Runs when a reveal reaches its last character, and when Skip Reveal ends one early - the same moment either way, which is what lets the Continue prompt be written once. It runs ONCE per line: a skip after the line has already landed finds nothing left to end. Nothing is handed to it, so a sheet typing out more than one line keeps the line it is on in a variable of its own."))

	return d


## Set Text With Effect: turn BBCode on, then write the tag around the words. Two statements because
## bbcode_enabled starts false and a label without it draws the tag as characters.
##
## The per-effect line is chosen by the STATED CHOICE segment idiom rather than by a slot, because the
## seven answers are seven different lines - each engine effect names its own knob (amp, level, radius,
## freq, length) and the custom one spells its tag out of a field. A slot could only have filled a hole
## that all seven shared, and they share none.
static func _set_template() -> String:
	var lines: PackedStringArray = PackedStringArray(["{target.}bbcode_enabled = true"])
	for effect: Dictionary in EFFECTS:
		lines.append("{?effect=%s}\n{target.}text = %s %% (%s) + {text} + %s{/effect}" % [
			effect["word"], effect["open"], knob_of(effect), effect["close"]])
	return "".join(lines)


## Wrap Selection In Effect: the same seven tags, inserted around a stretch of the text the label is
## already holding. The CLOSING tag goes in first, at the higher index, so inserting the opening one
## cannot shift the position the closing one was measured at.
static func _wrap_template() -> String:
	var lines: PackedStringArray = PackedStringArray(["{target.}bbcode_enabled = true"])
	for effect: Dictionary in EFFECTS:
		lines.append("{?effect=%s}\n{target.}text = {target.}text.insert(int({to}), %s).insert(int({from}), %s %% (%s)){/effect}" % [
			effect["word"], effect["close"], effect["open"], knob_of(effect)])
	return "".join(lines)


## Reveal Text, one emitted line per array entry.
##
## THE REVEAL IS A TWEEN OF CALLBACKS, one per character, rather than one tween over the ratio. That
## is what buys the two things a typed line needs and a smooth interpolation cannot give: a sound on
## each character, and a pause held at a named one. The tween is parked on the label so the next
## reveal - or a skip - can end it, which is the difference between a player pressing the button twice
## and two lines typing over each other.
##
## Locals carry {uid} because the compiler emits this INTO the sheet class, once per applied row.
static func _reveal_template() -> String:
	var lines: PackedStringArray = PackedStringArray([
		"{target.}bbcode_enabled = true",
		"{target.}text = {text}",
		"{target.}visible_characters = 0",
		"if {target.}has_meta(%s):" % REVEAL_META,
		"\t({target.}get_meta(%s) as Tween).kill()" % REVEAL_META,
		"var __voice_{uid}: Node = {sound}",
		"var __pauses_{uid}: Dictionary = {target.}get_meta(%s, {})" % PAUSES_META,
		"if {target.}has_meta(%s):" % PAUSES_META,
		"\t{target.}remove_meta(%s)" % PAUSES_META,
		"var __step_{uid}: float = 1.0 / maxf(1.0, float({chars_per_second}))",
		"var __reveal_{uid}: Tween = {target.}create_tween()",
		"{target.}set_meta(%s, __reveal_{uid})" % REVEAL_META,
		"for __at_{uid}: int in range(1, {target.}get_total_character_count() + 1):",
		"\t__reveal_{uid}.tween_callback({target.}set_visible_characters.bind(__at_{uid})).set_delay(__step_{uid})",
		"\tif __voice_{uid} != null:",
		"\t\t__reveal_{uid}.tween_callback(__voice_{uid}.play)",
		"\tif __pauses_{uid}.has(__at_{uid}):",
		"\t\t__reveal_{uid}.tween_interval(float(__pauses_{uid}[__at_{uid}]))",
		"__reveal_{uid}.tween_callback({target.}remove_meta.bind(%s))" % REVEAL_META,
		"__reveal_{uid}.tween_callback(%s)" % FINISHED_CALL,
	])
	return "\n".join(lines)


## Skip Reveal: end the tween that is typing, show the whole line, and answer in the same place a
## reveal that ran out answers. Killing the tween first is what stops its remaining callbacks from
## walking the ratio back down after the skip.
##
## THE WHOLE ROW IS INSIDE THE `if`, so a skip is only a skip while something is being typed. Pressed
## twice - which is what a Continue button gets from a player who is ahead of the text - the second
## press finds no reveal parked on the label and does nothing, rather than answering again and taking
## the conversation two lines on. The reveal drops its own meta as it ends for the same reason: a line
## that finished by itself has nothing left to skip either.
static func _skip_template() -> String:
	return "\n".join(PackedStringArray([
		"if {target.}has_meta(%s):" % REVEAL_META,
		"\t({target.}get_meta(%s) as Tween).kill()" % REVEAL_META,
		"\t{target.}remove_meta(%s)" % REVEAL_META,
		"\t{target.}visible_ratio = 1.0",
		"\t%s()" % FINISHED_CALL,
	]))


## Pause Reveal At: write one beat down on the label, where the next reveal reads it. A Dictionary of
## character to seconds, so several pauses on one line are several rows and the last row to name a
## character wins.
##
## THE PAUSES BELONG TO ONE LINE. The reveal reads them and takes them back off the label, so a comma
## pause written for character 12 of this line is not held again at character 12 of the next one -
## which would be a hesitation nobody wrote, in the middle of a word, for the rest of the conversation.
static func _pause_template() -> String:
	return "\n".join(PackedStringArray([
		"var __pauses_{uid}: Dictionary = {target.}get_meta(%s, {})" % PAUSES_META,
		"__pauses_{uid}[int({at})] = float({seconds})",
		"{target.}set_meta(%s, __pauses_{uid})" % PAUSES_META,
	]))


## The effect chooser: the engine's six by name, plus the door to your own. A closed list, because
## these are the words the tags are spelled with and a seventh typed by hand would simply not draw -
## the custom entry is how a name of your own gets in.
static func _effect_param() -> ACEParam:
	return F.make_param("effect", "String", "wave", "Effect", "Which effect to write. The first six are the engine's own; \"custom\" writes the name in the field below instead, for an effect you installed yourself.", "", _effect_words())


## The name a custom effect answers to, read only when the effect above is "custom". A default that
## says what it is rather than a name out of somebody else's project.
static func _custom_param() -> ACEParam:
	return F.make_param("custom", "String", "\"glitch\"", "Custom name", "The bbcode name your own RichTextEffect answers to - the same word its bbcode property holds. Only read when the effect above is \"custom\".", "expression")


## The seven words the effect field offers, as plain strings - the same list the templates are built
## from, so a row can never offer a word no template writes.
static func _effect_words() -> Array[String]:
	var words: Array[String] = []
	for effect: Dictionary in EFFECTS:
		words.append(str(effect["word"]))
	return words


## The "On node" target, written out by hand instead of taking the one registration appends to a
## node-scoped ACE. That transform prefixes each LINE once, which is correct for a one-member call and
## quietly wrong here: these templates touch `text`, `bbcode_enabled` and `get_meta` in the same run,
## and a `for` or an `if` line cannot be prefixed at all. Owning a param called "target" is also what
## tells registration to leave the template alone, so the two halves agree.
static func _on_node_param() -> ACEParam:
	return F.make_param("target", "String", "", "On node", "Act on another node instead of this one. Leave blank for this node, pick a node, or address one without a tree path - e.g. get_tree().get_first_node_in_group(\"player\").", "expression")
