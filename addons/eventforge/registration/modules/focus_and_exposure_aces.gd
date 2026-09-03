# EventForge module - the LENS vocabulary: what the camera lets in, and what it keeps sharp.
#
# THE CAMERA AS THE OBJECT. Every row here is node-scoped: the camera (or the WorldEnvironment
# standing in for every camera that has none of its own) sits in the object column and the row says
# the word - "Camera - Set camera exposure to 2.0" - while the code echo shows the property the
# CameraAttributes really has. Nothing is written twice. The words come from
# EventForgeCameraAttributeWords, which asks ClassDB which spelling each word resolves to and what
# value it opens on; the two focus rows below them are hand-built, because "focus on that crate" is
# one sentence a person says and three numbers the engine wants, and no table can make that trade.
#
# THE OWN-IT COURTESY IS IN THE TEMPLATE, not in a row a reader has to remember. A CameraAttributes
# is a FILE: two cameras pointing at the same `.tres` point at ONE object, so dimming the lens on the
# cutscene camera dims it on the gameplay camera too. So every write below opens with the lines that
# give this node its own copy - a plain CameraAttributesPractical when the slot is holding nothing, a
# duplicate when it is holding a file. It is emitted, never assumed, and it is taken once.
#
# PRACTICAL, NEVER PHYSICAL. A slot holding nothing is given the Practical resource, whose blur is
# metres and whose exposure is a multiplier - not the Physical one, which would hand a reader a focal
# length, an f-stop, an aperture and a shutter speed to answer a question they asked in one word. A
# slot somebody deliberately filled with a Physical lens keeps it: the duplicate keeps its class, and
# every line only a Practical can answer sits inside a guard that asks first. The ordinary property
# row is still the right row for anyone who knows what f/16 means.
#
# WHICH IS ALSO WHY THE WRITING ROWS ARE HOST-ONLY. Their templates open with an `if`, so the
# cross-node transform leaves them alone: a row that gave ANOTHER node's lens its own copy and then
# wrote through it would have to spell the same guard twice around a node named in the middle. The
# READ rows are plain member reads and take the ordinary "On node" the transform appends to every
# such row - looking at a camera's exposure changes nothing about it.
#
# RENDERER HONESTY. Auto exposure is a Forward+ feature: on Mobile and on Compatibility the flag is
# set, the renderer ignores it, and nothing errors - so its rows SAY so, in their own descriptions and
# in the help words a reader meets on the row, and the Doctor's ship-it section says it once more for
# a project whose rendering method is not Forward+.
#
# AND IT REGISTERS AFTER THE WORLD'S OWN WORDS, which is why the file is named for what it holds
# rather than for the resource it writes through. Module discovery is sorted by file name, and that
# order is what a node's shelf in the picker is listed in - so a WorldEnvironment must still open with
# the world's own look (saturation, fog, the sky) and carry the lens after it, rather than leading
# with an exposure row a reader was not looking for.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility covenant).
@tool
class_name EventForgeFocusAndExposureACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")
const W := preload("res://addons/eventforge/registration/camera_attribute_words.gd")

## The picker category every row here is filed under - the same shelf the camera's own rows already
## sit on, so "Camera" is one section of the vocabulary rather than two that have to be read together.
const CAT := "Camera"

## How long a fade takes when nobody says - the same half second every other fade in the vocabulary
## opens on, so two fades side by side start in step.
const DEFAULT_FADE_SECONDS := "0.5"

## The slot every word's value is edited in, and the slot a length of time is, spelled once so the
## tests and the picker address them all by it.
const VALUE_PARAM := "value"
const SECONDS_PARAM := "seconds"

## The two fields the focus rows ask for: what to focus on, and how far past it the picture goes soft.
const SUBJECT_PARAM := "subject"
const BEYOND_PARAM := "beyond"

## What Focus On opens on when nobody has picked a subject yet: a plain distance in metres, so the
## dropped row stands on its own in any scene rather than naming a node that may not be there.
const DEFAULT_SUBJECT := "10.0"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	for host: Dictionary in W.HOSTS:
		for word: String in W.words():
			descriptors.append_array(_rows_of(W.word_entry(word), host))
	descriptors.append_array(_focus_rows(W.HOSTS[0]))
	return descriptors


# ── The words ────────────────────────────────────────────────────────────────────────────────────


## Every row one word makes on one host, by the kind of thing the word is.
static func _rows_of(entry: Dictionary, host: Dictionary) -> Array[ACEDescriptor]:
	if str(entry["kind"]) == W.KIND_SWITCH:
		return _switch_rows(entry, host)
	return _value_rows(entry, host)


## A word that is set to a NUMBER: the Set row, the expression that reads it back, and - for a word
## the lens can be walked to over time - the one-line tween a fade is.
static func _value_rows(entry: Dictionary, host: Dictionary) -> Array[ACEDescriptor]:
	var word: String = str(entry["word"])
	var stem: String = W.id_stem(word, host)
	var member: String = str(host["member"])
	var property: String = W.property_of(word)
	var setter: ACEDescriptor = F.act("CamSet%s" % stem, str(entry["name"]),
		"%s%s.%s = {%s}" % [W.own_lines(host), member, property, VALUE_PARAM], CAT,
		str(entry["verb"]), _about(entry, host), str(host["host"])).param_typed(
		"String", VALUE_PARAM, W.default_of(word), _label(entry), str(entry["about"]), "expression")
	if bool(entry.get("featured", false)):
		setter.featured()
	var rows: Array[ACEDescriptor] = [setter, _read_row(entry, host)]
	if bool(entry.get("fades", false)):
		rows.append(_fade_row(entry, host))
	return rows


## The expression that reads a word back - the plain member a person would type, so a hand-written
## read and a picked one are the same bytes, and so the cross-node transform can hand it the ordinary
## "On node" every other read row wears.
static func _read_row(entry: Dictionary, host: Dictionary) -> ACEDescriptor:
	var word: String = str(entry["word"])
	return F.expr("Cam%s" % W.id_stem(word, host), str(entry["read_name"]),
		"%s.%s" % [str(host["member"]), W.property_of(word)], CAT, str(entry["reads"]),
		"Reads the %s back: %s. Answers for %s. Use it in any value field." % [word, _echo(entry, host),
			str(host["which"])], str(host["host"]))


## The one row that is not a plain write: a tween walks the property from where it is to where the row
## says, over a number of seconds. The own-it lines come first here too, because the tween holds on to
## the lens it was handed and would otherwise walk a shared one.
static func _fade_row(entry: Dictionary, host: Dictionary) -> ACEDescriptor:
	var word: String = str(entry["word"])
	var template: String = "%screate_tween().tween_property(%s, \"%s\", {%s}, {%s})" % [
		W.own_lines(host), str(host["member"]), W.property_of(word), VALUE_PARAM, SECONDS_PARAM]
	return F.act("CamFade%s" % W.id_stem(word, host), "Fade %s" % str(entry["read_name"]), template,
		CAT, "Fade %s to {%s} over {%s} s" % [word, VALUE_PARAM, SECONDS_PARAM],
		"Walks the %s to a new value over time instead of jumping to it - one tween, no state to keep, and the whole of a fade to white. Gives this node its own copy of the camera attributes first. Writes %s." % [
			word, _echo(entry, host)], str(host["host"])).param_typed(
		"String", VALUE_PARAM, W.default_of(word), _label(entry), "The %s to arrive at." % word,
		"expression").param_typed("String", SECONDS_PARAM, DEFAULT_FADE_SECONDS, "Seconds",
		"How long the fade takes.", "expression")


## A word that is ON or OFF: two actions that say which, and the condition that asks. Two actions
## rather than one with a true/false field, because "Turn auto exposure off" is the sentence a reader
## writes and "Set auto exposure false" is the one they have to decode. The On row carries whatever
## companion properties are the same decision, so a reader settles the whole behaviour in one row.
static func _switch_rows(entry: Dictionary, host: Dictionary) -> Array[ACEDescriptor]:
	var word: String = str(entry["word"])
	var stem: String = W.id_stem(word, host)
	var member: String = str(host["member"])
	var property: String = W.property_of(word)
	var on_row: ACEDescriptor = F.act("Cam%sOn" % stem, str(entry["on_name"]),
		_switch_on_template(entry, host), CAT, str(entry["on_verb"]), _about(entry, host),
		str(host["host"])).featured()
	for companion: Variant in (entry.get("companions", []) as Array):
		var field: Dictionary = companion
		on_row.param_typed("String", str(field["param"]),
			W.default_literal(str(field["property"])), str(field["label"]), str(field["about"]),
			"expression")
	return [
		on_row,
		F.act("Cam%sOff" % stem, str(entry["off_name"]),
			"%s%s.%s = false" % [W.own_lines(host), member, property], CAT, str(entry["off_verb"]),
			"%s Writes %s." % [str(entry["off_about"]), _echo(entry, host)], str(host["host"])),
		F.cond("CamIs%sOn" % stem, str(entry["asks"]), "%s.%s" % [member, property], CAT,
			str(entry["ask_verb"]), "%s Reads %s." % [str(entry["ask_about"]), _echo(entry, host)],
			str(host["host"]))
	]


## The whole write of a switch word: the own-it lines, the flag itself, whatever companions every lens
## can answer, and then - inside the guard that asks whether this really is a Practical lens - the
## companions only a Practical has. A person who deliberately fitted a Physical lens keeps it, and the
## two lines it cannot answer simply do not run.
static func _switch_on_template(entry: Dictionary, host: Dictionary) -> String:
	var member: String = str(host["member"])
	var lines: String = "%s%s.%s = true" % [W.own_lines(host), member,
		W.property_of(str(entry["word"]))]
	var guarded: String = ""
	for companion: Variant in (entry.get("companions", []) as Array):
		var field: Dictionary = companion
		var written: String = "%s.%s = {%s}" % [member, str(field["property"]), str(field["param"])]
		if bool(field.get("practical", false)):
			guarded += "\n\t%s" % written
		else:
			lines += "\n%s" % written
	return lines if guarded.is_empty() else "%s\n%s%s" % [lines, W.practical_guard(host), guarded]


## What a row does, said once per word: the word, the own-it promise, which cameras it answers for,
## and then the property the attributes resource really answers to - so the description and the code
## echo can never disagree.
static func _about(entry: Dictionary, host: Dictionary) -> String:
	return "%s Applies to %s. Gives this node its own copy of the camera attributes first, so an attributes file shared with other cameras never changes under them - a slot holding nothing is given a practical lens, and one somebody filled with a physical lens keeps it. Writes %s." % [
		str(entry["about"]), str(host["which"]), _echo(entry, host)]


## The property a row writes, as the reader sees it in the code echo.
static func _echo(entry: Dictionary, host: Dictionary) -> String:
	return "`%s.%s`" % [str(host["member"]), W.property_of(str(entry["word"]))]


## The field's name in the dialog: the word's own label where it has one, and the word itself
## otherwise.
static func _label(entry: Dictionary) -> String:
	return str(entry.get("label", str(entry["word"]).capitalize()))


# ── Focus ────────────────────────────────────────────────────────────────────────────────────────


## THE TWO ROWS THAT ARE NOT A PROPERTY. "Focus on that crate" is one sentence a person says and three
## numbers the engine wants: whether the far blur is on at all, how many metres away the picture stops
## being sharp, and how many metres it takes to go fully soft. So there are two rows rather than three
## words - one that focuses on something, and one that takes the blur off again - and the ordinary
## Focus Distance expression beside them for a reader who wants the number itself.
##
## CAMERA3D ONLY, and it has to be: the distance is measured from the camera's own position, and a
## WorldEnvironment is not standing anywhere. The exposure words above ship on both hosts; these two
## are 3D camera rows and say so.
static func _focus_rows(host: Dictionary) -> Array[ACEDescriptor]:
	var member: String = str(host["member"])
	return [
		F.act("CamFocusOn", "Focus On", _focus_on_template(host), CAT,
			"Focus on {%s}, soft {%s} m past it, over {%s} s" % [SUBJECT_PARAM, BEYOND_PARAM,
				SECONDS_PARAM],
			"Puts the sharp part of the picture on something and lets everything behind it go soft - the shot that says look here. Takes a node to measure the distance to, or the distance itself in metres, so a cutscene can focus on the speaker and a menu can focus on a fixed plane. Gives this camera its own copy of the camera attributes first, and does nothing at all on a camera somebody fitted with a physical lens. Writes `%s.%s` and `%s.%s`, and walks `%s.%s`." % [
				member, W.FOCUS_ENABLED, member, W.FOCUS_DISTANCE, member, W.FOCUS_TRANSITION],
			str(host["host"])).param_typed("String", SUBJECT_PARAM, DEFAULT_SUBJECT, "Subject",
			"What to keep sharp: a node to measure the distance to, or a distance in metres.",
			"expression").param_typed("String", BEYOND_PARAM,
			W.default_literal(W.FOCUS_TRANSITION), "Soft after",
			"How many metres past the subject the picture takes to go fully soft. Small numbers snap out of focus; large ones drift.",
			"expression").param_typed("String", SECONDS_PARAM, DEFAULT_FADE_SECONDS, "Seconds",
			"How long the focus takes to settle.", "expression").featured(),
		F.act("CamFocusEverywhere", "Focus Everywhere", _focus_everywhere_template(host), CAT,
			"Focus everywhere over {%s} s" % SECONDS_PARAM,
			"Takes the blur off and makes the whole picture sharp again, easing it out rather than cutting - the shot coming back from a close-up. The blur amount is put back where it was once the far blur is off, so the next Focus On starts from the same lens it did the first time. Gives this camera its own copy of the camera attributes first, and does nothing at all on a camera somebody fitted with a physical lens.",
			str(host["host"])).param_typed("String", SECONDS_PARAM, DEFAULT_FADE_SECONDS, "Seconds",
			"How long the picture takes to come back sharp.", "expression"),
		F.expr("CamFocusDistance", "Focus Distance", "%s.%s" % [member, W.FOCUS_DISTANCE], CAT,
			"focus distance",
			"How many metres away the picture stops being sharp, as Focus On last left it. Reads `%s.%s`. Use it in any value field." % [
				member, W.FOCUS_DISTANCE], str(host["host"]))
	]


## Focus On's whole template: this camera's own lens, the subject measured once into a local of its
## own (uid-suffixed, so two of these rows in one function cannot collide), and then - inside the
## guard that asks whether this is a practical lens - the far blur switched on, the distance written,
## and the falloff walked there over time. The subject is asked ONCE and remembered, so a slot holding
## a call is not run twice.
static func _focus_on_template(host: Dictionary) -> String:
	var member: String = str(host["member"])
	return "%svar __subject_{uid} = {%s}\n%s\n\t%s.%s = true\n\t%s.%s = global_position.distance_to(__subject_{uid}.global_position) if __subject_{uid} is Node3D else float(__subject_{uid})\n\tcreate_tween().tween_property(%s, \"%s\", {%s}, {%s})" % [
		W.own_lines(host), SUBJECT_PARAM, W.practical_guard(host), member, W.FOCUS_ENABLED, member,
		W.FOCUS_DISTANCE, member, W.FOCUS_TRANSITION, BEYOND_PARAM, SECONDS_PARAM]


## Focus Everywhere's whole template: this camera's own lens, then - inside the same guard - the blur
## amount remembered, walked to nothing, and the far blur switched off at the end of the walk before
## the amount is put back. Two callbacks rather than one lambda, because a bound method is a plain
## Callable a debugger can step into and a reader can read.
static func _focus_everywhere_template(host: Dictionary) -> String:
	var member: String = str(host["member"])
	return "%s%s\n\tvar __blur_{uid}: float = %s.%s\n\tvar __clear_{uid}: Tween = create_tween()\n\t__clear_{uid}.tween_property(%s, \"%s\", 0.0, {%s})\n\t__clear_{uid}.tween_callback(%s.set.bind(\"%s\", false))\n\t__clear_{uid}.tween_callback(%s.set.bind(\"%s\", __blur_{uid}))" % [
		W.own_lines(host), W.practical_guard(host), member, W.FOCUS_AMOUNT, member, W.FOCUS_AMOUNT,
		SECONDS_PARAM, member, W.FOCUS_ENABLED, member, W.FOCUS_AMOUNT]
