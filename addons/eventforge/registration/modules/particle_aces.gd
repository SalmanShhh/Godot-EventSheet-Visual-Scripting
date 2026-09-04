# EventForge module - Particles (GPUParticles2D / GPUParticles3D / CPUParticles2D)
#
# TWO HALVES, ON PURPOSE, and this file holds both so that "Particles" is one vocabulary in one place.
#
# THE SWITCHES came first: emitting, restart, one-shot, amount, speed scale, and an On Particles
# Finished trigger (the "finished" signal, connected via the OnParticlesFinished arm in
# trigger_resolver.gd). Lane-1 wraps of native particle nodes, single-line per the parity contract.
# GPU and CPU are distinct classes, so the picker scopes by node_type - CPU gets its own ace_id where
# it differs. Their ace_ids and templates are frozen API, and everything added below is a NEW id
# beside them rather than a replacement.
#
# THE WORDS came second: what the effect actually looks like - which way it falls, how wide it fans
# out, how fast and how big the particles are, what colour they are, how long they last and how many
# there are. Those come from EventForgeParticleWords, which knows the thing the switches never had to:
# a particle effect is TWO objects. Amount and lifetime are the emitter's own; gravity, spread, speed,
# size and colour live on a ParticleProcessMaterial hanging off it. The table says which, so no row
# has to guess and no reader has to know.
#
# THE OWN-IT COURTESY IS IN THE TEMPLATE for every material word: a process material is a FILE, and
# two emitters pointing at the same `.tres` point at ONE object, so turning the sparks red would turn
# every spark in the level red. The write gives this emitter its own copy first, and then asks whether
# what it is holding really is a process material - an emitter driven by somebody's particle SHADER is
# left completely alone, because those settings live inside the shader and there is nothing here to
# set. The two node words need neither: `amount` and `lifetime` are the emitter's own.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (covenant).
@tool
class_name EventForgeParticleACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")
const W := preload("res://addons/eventforge/registration/particle_words.gd")

## The picker category every row here is filed under, switches and words alike, so "Particles" is one
## section of the vocabulary rather than two.
const CAT := "Particles"

## How long a fade takes when nobody says - the same half second every other fade in the vocabulary
## opens on, so two fades side by side start in step.
const DEFAULT_FADE_SECONDS := "0.5"

## The slots a word's value, its second half and a length of time are edited in, spelled once so the
## tests and the picker address them all by it.
const VALUE_PARAM := "value"
const MOST_PARAM := "most"
const SECONDS_PARAM := "seconds"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	descriptors.append(F.trig("OnParticlesFinished", "On Particles Finished", "finished", "Signals / Scene / Input", "On particles finished", "Fires once when this particle emitter's one-shot burst finishes playing.", "GPUParticles2D"))
	descriptors.append(F.act("SetEmitting", "Set Emitting", "emitting = {emitting}", "Particles", "Set emitting {emitting}", "Starts or stops the particle emitter, e.g. switching an effect on.", "GPUParticles2D").param_choice("emitting", "true", "Emitting", "Start / stop emitting.", ["true", "false"]))
	descriptors.append(F.act("RestartParticles", "Restart / Burst", "restart()", "Particles", "Restart particles", "Restarts the particle system from the beginning, e.g. firing a fresh burst.", "GPUParticles2D"))
	descriptors.append(F.act("SetOneShot", "Set One-Shot", "one_shot = {one_shot}", "Particles", "Set one-shot {one_shot}", "Sets the emitter to fire a single burst then stop, rather than looping.", "GPUParticles2D").param_choice("one_shot", "true", "One-Shot", "Emit a single burst then stop.", ["true", "false"]))
	descriptors.append(F.act("SetParticleAmount", "Set Amount", "amount = {amount}", "Particles", "Set amount to {amount}", "Sets how many particles the emitter spawns, controlling effect density.", "GPUParticles2D").param("amount", "8", "Amount", "Number of particles.", "expression"))
	descriptors.append(F.cond("IsEmitting", "Is Emitting", "emitting", "Particles", "Is emitting", "True when the particle emitter is currently emitting particles.", "GPUParticles2D"))
	descriptors.append(F.expr("GetParticleAmount", "Amount", "amount", "Particles", "particle amount", "Returns how many particles the emitter is set to spawn.", "GPUParticles2D"))
	descriptors.append(F.act("SetParticleSpeedScale", "Set Speed Scale", "speed_scale = {scale}", "Particles", "Set speed scale to {scale}", "Speeds up or slows down the particle effect, e.g. 0 freezes it, 2 doubles it.", "GPUParticles2D").param("scale", "1.0", "Scale", "1 = normal, 0.5 = slow, 0 = frozen, 2 = double speed.", "expression"))
	# CPUParticles2D parallel (distinct class - same member names, separate picker section).
	descriptors.append(F.act("SetEmittingCPU", "Set Emitting (CPU)", "emitting = {emitting}", "Particles", "Set emitting {emitting}", "Starts or stops a CPU particle emitter, e.g. switching an effect on.", "CPUParticles2D").param_choice("emitting", "true", "Emitting", "Start / stop emitting.", ["true", "false"]))
	descriptors.append(F.act("RestartParticlesCPU", "Restart / Burst (CPU)", "restart()", "Particles", "Restart particles", "Restarts a CPU particle system from the beginning, e.g. firing a fresh burst.", "CPUParticles2D"))
	descriptors.append(F.act("SetParticleSpeedScaleCPU", "Set Speed Scale (CPU)", "speed_scale = {scale}", "Particles", "Set speed scale to {scale}", "Speeds up or slows down a CPU particle effect, e.g. 0 freezes it, 2 doubles it.", "CPUParticles2D").param("scale", "1.0", "Scale", "1 = normal, 0.5 = slow, 0 = frozen, 2 = double speed.", "expression"))

	# The words, LAST and for a reason: registration order is the reverse-lifter's tie-break, so the
	# frozen rows above keep every line they already claimed. A hand-written `amount = 8` still reads
	# as the row it has always read as.
	#
	# WHICH IS ALSO THE COST, said here so nobody has to find it out from a sheet. Two of the words
	# land on a line a frozen row already spells: `amount` and `lifetime` on a 2D emitter are Set
	# Amount and Set Lifetime to the reverse-lifter forever, never Set Particle Amount and never Set
	# Particle Lifetime. So "every particle word reads backwards" is true of the material words and
	# of both node words in 3D, and NOT of those two lines in 2D - they read as the older row, which
	# emits the identical GDScript and says the same thing in fewer letters. The alternative was
	# taking a line away from a row somebody's saved sheet already holds, and a frozen row keeping
	# what it claimed is worth more than a tidy sentence here.
	for host: Dictionary in W.HOSTS:
		for word: String in W.words(host):
			descriptors.append_array(_word_rows(W.word_entry(word), host))

	return descriptors


static func section_descriptions() -> Dictionary:
	return {CAT: "Particle effects, said in words: start and stop them, and set what they look like - which way they fall, how wide they fan out, how fast and how big the particles are, what colour they are, how long each one lasts and how many there are at once. The five that live on the emitter's process material give this emitter its own copy of it first, so an effect file shared between emitters never changes under the others."}


# -- The words ------------------------------------------------------------------------------------


## Every row one word makes on one host: the Set row, the expression that reads it back, an expression
## for the second half of a word that is really a range, and - for a word an effect can be walked to
## over time - the tween that walks it.
static func _word_rows(entry: Dictionary, host: Dictionary) -> Array[ACEDescriptor]:
	var setter: ACEDescriptor = _set_row(entry, host)
	if bool(entry.get("featured", false)):
		setter.featured()
	var rows: Array[ACEDescriptor] = [setter, _read_row(entry, host)]
	if entry.has("companion"):
		rows.append(_companion_read_row(entry, host))
	if bool(entry.get("fades", false)):
		rows.append(_fade_row(entry, host))
	return rows


## The Set row of one word: the write itself, plus the second half of a range on the same row, plus -
## for a material word - the own-it lines and the guard in front of both.
static func _set_row(entry: Dictionary, host: Dictionary) -> ACEDescriptor:
	var word: String = str(entry["word"])
	var row: ACEDescriptor = F.act("ParticleSet%s" % W.id_stem(word, host), str(entry["name"]),
		_write_line(entry, host), CAT, str(entry["verb"]), _about(entry, host), str(host["host"]))
	_add_value_param(row, entry, host, VALUE_PARAM, str(entry["label"]), str(entry["about"]))
	if entry.has("companion"):
		var companion: Dictionary = entry["companion"]
		_add_value_param(row, entry, host, MOST_PARAM, str(companion["label"]),
			str(companion["about"]), str(companion["property"]))
	return row


## The whole write of one word: the plain member operation for a node word, and the owned, guarded and
## indented one for a material word.
static func _write_line(entry: Dictionary, host: Dictionary) -> String:
	var word: String = str(entry["word"])
	var property: String = W.property_of(word, host)
	if not W.is_material_word(word):
		return "%s = {%s}" % [property, VALUE_PARAM]
	var lines: String = "%s%s\n\t%s.%s = {%s}" % [W.OWN_LINES, W.GUARD_LINE, W.MATERIAL_MEMBER,
		property, VALUE_PARAM]
	if entry.has("companion"):
		lines += "\n\t%s.%s = {%s}" % [W.MATERIAL_MEMBER,
			str((entry["companion"] as Dictionary)["property"]), MOST_PARAM]
	return lines


## The expression that reads a word back. A node word is the plain member a person would type, so a
## hand-written read and a picked one are the same bytes; a material word is a CAST, for the reason
## the write has an `is` in it - an emitter driven by a shader, or by nothing at all, answers with the
## value a new process material starts on rather than reaching through something that is not there.
static func _read_row(entry: Dictionary, host: Dictionary) -> ACEDescriptor:
	var word: String = str(entry["word"])
	var property: String = W.property_of(word, host)
	return F.expr("Particle%s" % W.id_stem(word, host), str(entry["read_name"]),
		_read_expression(property, W.default_of(word, host), W.is_material_word(word)), CAT,
		str(entry["reads"]),
		"Reads the effect's %s back. %s Use it in any value field." % [word,
			_read_note(entry, host, property)], str(host["host"]))


## The second half of a range, read back on its own - because a row that offers both ends must be
## answerable at both ends too.
static func _companion_read_row(entry: Dictionary, host: Dictionary) -> ACEDescriptor:
	var companion: Dictionary = entry["companion"]
	var property: String = str(companion["property"])
	var word: String = str(entry["word"])
	return F.expr("Particle%s%s" % [str(companion["stem"]), str(host["suffix"])],
		str(companion["read_name"]), _read_expression(property,
			W.default_literal(W.class_of(word, host), property), W.is_material_word(word)), CAT,
		str(companion["reads"]),
		"Reads the other end of the effect's %s back. %s Use it in any value field." % [word,
			_read_note(entry, host, property)], str(host["host"]))


## One read, as the bytes it is: a plain member on the emitter, or the guarded cast through its
## process material.
static func _read_expression(property: String, opening: String, through_material: bool) -> String:
	if not through_material:
		return property
	return "(%s as %s).%s if %s is %s else %s" % [W.MATERIAL_MEMBER, W.MATERIAL_CLASS, property,
		W.MATERIAL_MEMBER, W.MATERIAL_CLASS, opening]


## The one row that is not a plain write: a tween walks the property from where it is to where the row
## says, over a number of seconds - and walks the second half of a range beside it, so both ends
## arrive together.
static func _fade_row(entry: Dictionary, host: Dictionary) -> ACEDescriptor:
	var word: String = str(entry["word"])
	var row: ACEDescriptor = F.act("ParticleFade%s" % W.id_stem(word, host),
		"Fade %s" % str(entry["name"]).trim_prefix("Set "), _fade_template(entry, host), CAT,
		"Fade %s to {%s} over {%s} s" % [word, VALUE_PARAM, SECONDS_PARAM],
		"Walks the effect's %s to a new value over time instead of jumping to it - one tween, no state to keep. %s" % [
			word, _read_note(entry, host, W.property_of(word, host))], str(host["host"]))
	if not W.is_material_word(word):
		row.param_built(F.make_param("target", "String", "self", "On node",
			"The emitter to fade. Leave it as self to fade the one this sheet is on.", "expression"))
	_add_value_param(row, entry, host, VALUE_PARAM, str(entry["label"]),
		"The %s to arrive at." % word)
	if entry.has("companion"):
		var companion: Dictionary = entry["companion"]
		_add_value_param(row, entry, host, MOST_PARAM, str(companion["label"]),
			"The other end of the range to arrive at.", str(companion["property"]))
	return row.param_typed("String", SECONDS_PARAM, DEFAULT_FADE_SECONDS, "Seconds",
		"How long the fade takes.", "expression")


## A fade's whole template: the tween for a node word, and the owned, guarded pair for a material one.
## The node word's tween carries its own `target` (which is why the cross-node transform leaves it
## alone), because the emitter is an ARGUMENT of the call there rather than its receiver.
static func _fade_template(entry: Dictionary, host: Dictionary) -> String:
	var word: String = str(entry["word"])
	var property: String = W.property_of(word, host)
	if not W.is_material_word(word):
		return "create_tween().tween_property({target}, \"%s\", {%s}, {%s})" % [property,
			VALUE_PARAM, SECONDS_PARAM]
	var lines: String = "%s%s\n\tcreate_tween().tween_property(%s, \"%s\", {%s}, {%s})" % [
		W.OWN_LINES, W.GUARD_LINE, W.MATERIAL_MEMBER, property, VALUE_PARAM, SECONDS_PARAM]
	if entry.has("companion"):
		lines += "\n\tcreate_tween().tween_property(%s, \"%s\", {%s}, {%s})" % [W.MATERIAL_MEMBER,
			str((entry["companion"] as Dictionary)["property"]), MOST_PARAM, SECONDS_PARAM]
	return lines


## One field, opened on the engine's own default for the property it writes and given the field kind
## its value asks for - a colour picker for a colour, an expression box for everything else.
static func _add_value_param(row: ACEDescriptor, entry: Dictionary, host: Dictionary,
		param_id: String, label: String, description: String, property: String = "") -> void:
	var word: String = str(entry["word"])
	var opening: String = W.default_of(word, host) if property.is_empty() \
		else W.default_literal(W.class_of(word, host), property)
	var is_colour: bool = str(entry["kind"]) == W.KIND_COLOUR
	row.param_typed("Color" if is_colour else "String", param_id, opening, label, description,
		"color" if is_colour else "expression")


## What a row does, said once per word: the word, then whichever of the two promises this word's
## object needs, then the property the class really answers to.
static func _about(entry: Dictionary, host: Dictionary) -> String:
	return "%s %s" % [str(entry["about"]),
		_read_note(entry, host, W.property_of(str(entry["word"]), host))]


## The sentence that says where a word lives and what that costs, shared by every row of it.
static func _read_note(entry: Dictionary, host: Dictionary, property: String) -> String:
	if not W.is_material_word(str(entry["word"])):
		return "Writes `%s.%s`, which is the emitter's own." % [str(host["host"]), property]
	return "Gives this emitter its own copy of its process material first, so an effect file shared with other emitters never changes under them. An emitter driven by a particle shader is left alone - these settings live inside the shader there. Writes `%s.%s`." % [
		W.MATERIAL_CLASS, property]
