# EventForge - the tag somebody typed into a label by hand, and the row it means.
#
# Wobbling a title in Godot has always been one line: turn BBCode on and put the engine's own tag
# around the words. Every project that has ever had a shaking damage number holds a line like
#
#     $Title.text = "[wave amp=%s freq=5]" % (40 * float(Engine.get_meta("text_size_scale", 1.0))) + "Starfall" + "[/wave]"
#
# and that is exactly what Set Text With Effect writes. So the row and the hand-written line are the
# same line, and this family is what says so: open the file and the tag reads back as the row that
# would have written it, with the effect, the strength and the words in its fields.
#
# ONE ENTRY PER EFFECT, because the six tags are six different lines - each names its own knob (amp,
# level, radius, freq, length) and each answers a different accessibility factor. They are BUILT from
# the same table the row's templates are built from (EventForgeTextEffectACEs.EFFECTS), so a tag can
# never be written by a row and refused by this file, or the other way round.
#
# WHAT IS DELIBERATELY NOT CLAIMED:
#   * the "custom" effect, whose tag names YOUR effect in two places on one line. Two mentions of one
#     value cannot each be a capture of the same name, and a lift that guessed which one was the row's
#     value would be guessing. A custom tag written by hand stays the line it is.
#   * `bbcode_enabled = true`, which the row writes on the line above. It is an ordinary property
#     write, it already reads as one, and claiming it here would take a line away from the reading
#     that says exactly what it does.
#   * Wrap Selection In Effect, which names its label three times in one statement, for the same
#     reason the removal family's fade entry gives: three mentions cannot each be an optional prefix
#     of one capture, and a wrap written by hand stays the statement it already was.
#   * THE REVEAL, and this one is worth spelling out because the obvious reading is the wrong one. A
#     line typed out by hand is almost always a smooth tween of `visible_ratio`, and reading THAT as
#     Reveal Text would be a lie the round trip catches: the row emits a tween of one callback per
#     character - which is what buys a sound on each character and a pause held at a named one - so
#     saving the opened file would replace a person's two lines with seventeen they did not write.
#     A lift that cannot reproduce its source must not fire, so a ratio tween stays the tween it is.
@tool
class_name EventForgeTextEffectLift
extends RefCounted

## The vocabulary this family reads its tags out of, by path so the importer never waits on the
## editor's class cache. One table, two readers: the module builds the templates from it and this
## file builds the recognisers, so neither can drift from the other.
const TextEffects := preload("res://addons/eventforge/registration/modules/text_effect_aces.gd")

## The row every entry here hands back.
const ACE_ID: String = "SetTextWithEffect"

## The word the "custom" entry of the table is spelled with - the one effect with no entry here,
## because its tag names the effect twice in one line.
const CUSTOM_WORD: String = "custom"

## The fragment a line must contain for any entry here to be worth trying. `.text = "[` rules out
## almost every statement in a project before a pattern is compiled at all, and every tag this family
## claims opens with it.
const MARK: String = ".text = \"["

## The example values the harness generates its fixture line from. Written here rather than inline so
## the six examples differ in nothing but the tag they carry.
const SAMPLE_NODE: String = "$Title"
const SAMPLE_STRENGTH: String = "40"
const SAMPLE_TEXT: String = "\"Starfall\""

## Built once for the life of the session: these run on every statement of every opened file.
static var _entries: Array[Dictionary] = []


## The row one statement means, or {} when no spelling here claims it. `line` is a single statement,
## already dedented by the lifter.
static func match_line(line: String) -> Dictionary:
	var text: String = line.strip_edges()
	if not text.contains(MARK):
		return {}
	return EventForgeLiftTable.match_line(lift_entries(), text)


## One entry per engine effect, derived from the vocabulary's own table.
static func lift_entries() -> Array[Dictionary]:
	if _entries.is_empty():
		var built: Array[Dictionary] = []
		for effect: Dictionary in TextEffects.EFFECTS:
			var word: String = str(effect["word"])
			if word == CUSTOM_WORD:
				continue
			built.append(_effect_entry(word, effect))
		_entries = built
	return _entries


## The tag one effect writes, as a marked example the table engine turns into a recogniser. The three
## marked spans are the row's three fields; the tag's own attributes, the accessibility factor and the
## author's spacing are outside them, so they ride back out into the saved file untouched.
static func _effect_entry(word: String, effect: Dictionary) -> Dictionary:
	var knob: String = str(effect["knob"]).replace("{strength}", "[[strength|argument: %s]]" % SAMPLE_STRENGTH)
	var example: String = "[[target|node: %s]].text = %s %% (%s) + [[text: %s]] + %s" % [
		SAMPLE_NODE, str(effect["open"]), knob, SAMPLE_TEXT, str(effect["close"])]
	return EventForgeLiftExample.entry("text_effect_%s" % word, ACE_ID, example,
		{"defaults": {"effect": word, "custom": "\"glitch\""}})
