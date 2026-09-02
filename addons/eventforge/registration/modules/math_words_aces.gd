# EventForge module - the four value-shaping words, with the call in the echo.
#
# clamp, lerp, remap and wrapf are the four functions every game leans on and the four names
# beginners bounce off. The expressions for all four already ship, and an expression is the wrong
# shape for what people actually write with them: `hp = clampf(hp, 0, max_hp)` is a whole statement
# whose subject appears twice, and building it out of an expression row means naming `hp` three
# times and getting the assignment right by hand.
#
# These are those statements, as rows. Each template IS exactly the line the echo shows, so a
# hand-written `clampf` line opens as the Keep row and saves back as its own bytes:
#
#   Keep hp between 0 and max_hp            hp = clampf(hp, 0.0, max_hp)
#   Move zoom toward 1.5 by 10% each tick   zoom = lerp(zoom, 1.5, 0.1)
#   Rescale hp from 0..max_hp to 0..1       bar.value = remap(hp, 0, max_hp, 0, 1)
#   Wrap heading around 0..360              heading = wrapf(heading, 0.0, 360.0)
#
# THE 10% IS A READING, not a second value: `lerp` takes the fraction and the row emits the fraction.
# The percentage is how the canvas says 0.1 out loud, through the same lens family that reads a
# darkness colour as "81% dark" - the row shows the fact and the file holds the number.
#
# EASING VERSUS A RATE is the one thing the strip has to teach, because it is the one thing the
# shape hides: a tenth of the way each tick eases in and never quite arrives, and it moves further
# on a fast machine than on a slow one. The frame-rate-independent form of the same idea already
# ships beside this one (Move Toward, smooth), and the strip points at it rather than mint a second
# spelling of one row.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility covenant); this file
# only changes where the descriptors are AUTHORED.
@tool
class_name EventForgeMathWordsACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")
const LENS := preload("res://addons/eventforge/registration/value_lens.gd")

## The picker page these rows are filed on - beside the expressions they are the statement forms of.
const CAT := "Math & Random"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append(F.act("KeepBetween", "Keep Between", "{var_name} = clampf({var_name}, {low}, {high})", CAT, "Keep [b]{var_name}[/b] between [i]{low}[/i] and [i]{high}[/i]", "Holds a value inside a range whatever else does to it - health that cannot pass its maximum, a volume that cannot go negative, a camera zoom with a floor and a ceiling. Written once here instead of two comparisons everywhere the value changes.").param("var_name", "value", "Value", "The value being kept in range.", "variable_reference").param("low", "0.0", "At least", "It never goes below this.", "expression").param("high", "1.0", "At most", "It never goes above this.", "expression").featured())
	descriptors.append(F.act("MoveTowardEachTick", "Move Toward (each tick)", "{var_name} = lerp({var_name}, {target}, {weight})", CAT, "Move [b]{var_name}[/b] toward [i]{target}[/i] by [i]{weight}[/i] each tick", "Eases a value toward another one - a camera zoom settling, a bar catching up, a colour fading. It closes a share of the gap every tick, so it slows as it arrives and never quite lands. That also means it moves further on a fast machine than a slow one: when the speed has to be the same everywhere, use Move Toward (smooth), which says the same thing per second.").param("var_name", "value", "Value", "The value being eased.", "variable_reference").param("target", "1.0", "Toward", "The value it heads for.", "expression").param_built(F.make_param("weight", "String", "0.1", "Each tick", "How much of the remaining gap it closes every tick. 0.1 is a tenth of the way.", "expression").with_lens(LENS.LENS_FRACTION)).featured())
	descriptors.append(F.act("RescaleInto", "Rescale", "{into} = remap({amount}, {in_low}, {in_high}, {out_low}, {out_high})", CAT, "Rescale [i]{amount}[/i] from [i]{in_low}[/i]..[i]{in_high}[/i] to [i]{out_low}[/i]..[i]{out_high}[/i] into [b]{into}[/b]", "Turns a number measured on one scale into the same number measured on another - health in points into a bar's 0 to 1, a temperature into a colour's position, a slider's percent into a volume. The maths nobody remembers, said as what it is for.").param("into", "value", "Into", "Where the rescaled number is put.", "variable_reference").param("amount", "0.0", "Rescale", "The number being rescaled.", "expression").param("in_low", "0.0", "From", "What counts as empty in the number's own range.", "expression").param("in_high", "1.0", "to", "What counts as full in the number's own range.", "expression").param("out_low", "0.0", "Into range", "What empty becomes.", "expression").param("out_high", "1.0", "to", "What full becomes.", "expression").featured())
	descriptors.append(F.act("WrapAround", "Wrap Around", "{var_name} = wrapf({var_name}, {low}, {high})", CAT, "Wrap [b]{var_name}[/b] around [i]{low}[/i]..[i]{high}[/i]", "Sends a value round a loop instead of letting it run off the end - a heading that passes 360 and comes back at 0, an index that walks past the last item and back to the first, a clock. The low end is included and the high end is not, which is what makes 360 and 0 the same heading rather than two.").param("var_name", "value", "Value", "The value being wrapped.", "variable_reference").param("low", "0.0", "From", "The low end it comes back to.", "expression").param("high", "360.0", "to", "The high end it goes past.", "expression").featured())
	return descriptors


static func section_descriptions() -> Dictionary:
	return {CAT: "The value-shaping words as whole statements: keep a value in range, ease it toward another, rescale it from one range into another, and wrap it round a loop. Each writes exactly the call its echo shows."}
