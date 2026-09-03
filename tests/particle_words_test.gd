# The particle words, and the two objects an effect really is.
#
# The claim this file holds to account is that a reader saying "make the sparks fall faster" never has
# to know which of an effect's TWO objects the word lives on. How many particles there are and how
# long each one lasts belong to the emitter; which way they fall, how wide they fan out, how fast and
# how big they are and what colour they are belong to a ParticleProcessMaterial hanging off it. The
# mapping is derived from ClassDB, so what is pinned here is the ANSWERS - by value - rather than the
# table producing them.
#
# And the OWN-IT COURTESY, which is why the material rows are five lines rather than one: every write
# gives this emitter its own copy of its process material first, so an effect file worn by every torch
# in the level never changes under the other torches - and an emitter driven by somebody's particle
# SHADER is left completely alone, because those settings live inside the shader and there is nothing
# here to set. Both are pinned as the emitted BYTES, because that is the only place the promise is
# kept.
#
# The frozen rows are pinned too, in the one way that matters: they still come FIRST, because
# registration order is the reverse-lifter's tie-break and a hand-written `amount = 8` must keep
# reading as the row it has always read as.
@tool
class_name ParticleWordsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const W := preload("res://addons/eventforge/registration/particle_words.gd")
const MODULE := preload("res://addons/eventforge/registration/modules/particle_aces.gd")

## The four lines every material write opens with, written out here rather than read from the file
## under test: a test that builds its expectation from the same constant proves only that a constant
## equals itself.
const OWN_LINES := "if process_material == null:\n" \
	+ "\tprocess_material = ParticleProcessMaterial.new()\n" \
	+ "elif process_material is ParticleProcessMaterial and not process_material.resource_path.is_empty():\n" \
	+ "\tprocess_material = process_material.duplicate()\n"

## The guard that follows them, for the same reason.
const GUARD := "if process_material is ParticleProcessMaterial:\n"


static func run() -> bool:
	var ok: bool = true
	ok = _test_which_object_each_word_lives_on() and ok
	ok = _test_the_word_map() and ok
	ok = _test_the_defaults_come_from_classdb() and ok
	ok = _test_the_id_stems() and ok
	ok = _test_the_material_templates() and ok
	ok = _test_the_node_templates() and ok
	ok = _test_both_dimensions_ship_every_word() and ok
	ok = _test_the_frozen_rows_still_come_first() and ok
	ok = _test_ids_are_unique() and ok
	ok = _test_every_row_carries_help() and ok
	ok = _test_a_hand_written_line_reads_as_the_word() and ok
	return ok


## The whole point of the table, pinned first: which of an effect's two objects each word is on.
static func _test_which_object_each_word_lives_on() -> bool:
	var lives_on: Dictionary = {}
	for word: String in W.words(W.HOSTS[0]):
		lives_on[word] = "material" if W.is_material_word(word) else "the emitter"
	return SUPPORT.check("particle_words_test", "which object each word lives on", lives_on, {
		"gravity": "material",
		"spread": "material",
		"speed": "material",
		"size": "material",
		"colour": "material",
		"lifetime": "the emitter",
		"amount": "the emitter"
	})


## Every word resolves to a property the class it lives on really has - the one thing the whole
## vocabulary is derived from, so it is pinned by value, word by word.
static func _test_the_word_map() -> bool:
	var resolved: Dictionary = {}
	for word: String in W.words(W.HOSTS[0]):
		resolved[word] = "%s.%s" % [W.class_of(word, W.HOSTS[0]), W.property_of(word, W.HOSTS[0])]
	var ok: bool = SUPPORT.check("particle_words_test", "each word resolves to its property",
		resolved, {
			"gravity": "ParticleProcessMaterial.gravity",
			"spread": "ParticleProcessMaterial.spread",
			"speed": "ParticleProcessMaterial.initial_velocity_min",
			"size": "ParticleProcessMaterial.scale_min",
			"colour": "ParticleProcessMaterial.color",
			"lifetime": "GPUParticles2D.lifetime",
			"amount": "GPUParticles2D.amount"
		})
	return SUPPORT.check("particle_words_test", "every word the table names really resolves",
		W.words(W.HOSTS[0]).size(), W.WORDS.size()) and ok


## The value a row opens on is Godot's own, asked of ClassDB - including the two a vector has to be
## spelled for, because `str(Vector3(0, -9.8, 0))` is not a thing anybody can type.
static func _test_the_defaults_come_from_classdb() -> bool:
	var defaults: Dictionary = {}
	for word: String in W.words(W.HOSTS[0]):
		defaults[word] = W.default_of(word, W.HOSTS[0])
	return SUPPORT.check("particle_words_test", "each field opens on Godot's own default", defaults,
		{
			"gravity": "Vector3(0.0, -9.8, 0.0)",
			"spread": "45.0",
			"speed": "0.0",
			"size": "1.0",
			"colour": "Color.WHITE",
			"lifetime": "1.0",
			"amount": "8"
		})


## The one thing that is NOT derived, because an ace_id is a compatibility promise: the stem each
## word's rows are named after, in each dimension.
static func _test_the_id_stems() -> bool:
	var stems: Dictionary = {}
	for host: Dictionary in W.HOSTS:
		for word: String in W.words(host):
			stems["%s %s" % [str(host["which"]), word]] = W.id_stem(word, host)
	return SUPPORT.check("particle_words_test", "the frozen id stems", stems, {
		"2D gravity": "Gravity", "2D spread": "Spread", "2D speed": "Speed", "2D size": "Size",
		"2D colour": "Colour", "2D lifetime": "Lifetime", "2D amount": "Amount",
		"3D gravity": "Gravity3D", "3D spread": "Spread3D", "3D speed": "Speed3D",
		"3D size": "Size3D", "3D colour": "Colour3D", "3D lifetime": "Lifetime3D",
		"3D amount": "Amount3D"
	})


## The bytes a MATERIAL word writes: the own-it lines, the guard that leaves a shader-driven emitter
## alone, and then the write itself - with both ends of a range on the one row.
static func _test_the_material_templates() -> bool:
	var templates: Dictionary = _templates()
	return SUPPORT.pins("particle_words_test", [
		["a plain write owns the process material first", templates.get("ParticleSetSpread", ""),
			OWN_LINES + GUARD + "\tprocess_material.spread = {value}"],
		["a range writes both of its ends on one row", templates.get("ParticleSetSpeed", ""),
			OWN_LINES + GUARD + "\tprocess_material.initial_velocity_min = {value}\n"
				+ "\tprocess_material.initial_velocity_max = {most}"],
		["and a fade walks both of them together", templates.get("ParticleFadeSize", ""),
			OWN_LINES + GUARD
				+ "\tcreate_tween().tween_property(process_material, \"scale_min\", {value}, {seconds})\n"
				+ "\tcreate_tween().tween_property(process_material, \"scale_max\", {most}, {seconds})"],
		["a read is a cast, so a shader-driven emitter answers with the value a new material starts on",
			templates.get("ParticleColour", ""),
			"(process_material as ParticleProcessMaterial).color if process_material is ParticleProcessMaterial else Color.WHITE"],
		["and the other end of a range is answerable on its own",
			templates.get("ParticleSpeedMost", ""),
			"(process_material as ParticleProcessMaterial).initial_velocity_max if process_material is ParticleProcessMaterial else 0.0"]
	])


## The bytes a NODE word writes: the plain member a person would type, with no courtesy in front of it
## because the emitter's own amount and lifetime are nobody else's. And no fade for amount, because
## writing it throws the whole particle buffer away.
static func _test_the_node_templates() -> bool:
	var templates: Dictionary = _templates()
	return SUPPORT.pins("particle_words_test", [
		["the emitter's own words are plain member writes", templates.get("ParticleSetLifetime", ""),
			"lifetime = {value}"],
		["and plain member reads", templates.get("ParticleAmount", ""), "amount"],
		["their fade carries its own node, because the emitter is the tween's argument",
			templates.get("ParticleFadeLifetime", ""),
			"create_tween().tween_property({target}, \"lifetime\", {value}, {seconds})"],
		["and amount has no fade at all", templates.has("ParticleFadeAmount"), false]
	])


## The twin rule: every word ships in both dimensions, hosted on the emitter of that dimension.
static func _test_both_dimensions_ship_every_word() -> bool:
	var missing: PackedStringArray = PackedStringArray()
	var misplaced: PackedStringArray = PackedStringArray()
	var hosts: Dictionary = {}
	for row: ACEDescriptor in MODULE.get_descriptors():
		hosts[row.ace_id] = str(row.node_type)
	for host: Dictionary in W.HOSTS:
		for word: String in W.words(host):
			var stem: String = W.id_stem(word, host)
			for shape: String in ["ParticleSet%s", "Particle%s"]:
				var ace_id: String = shape % stem
				if not hosts.has(ace_id):
					missing.append(ace_id)
				elif str(hosts[ace_id]) != str(host["host"]):
					misplaced.append(ace_id)
	var ok: bool = SUPPORT.check("particle_words_test", "every word ships in both dimensions",
		missing, PackedStringArray())
	return SUPPORT.check("particle_words_test", "each on the emitter of its own dimension",
		misplaced, PackedStringArray()) and ok


## The frozen rows still come FIRST. Registration order is the reverse-lifter's tie-break, so a
## hand-written `amount = 8` keeps reading as the row it has always read as.
static func _test_the_frozen_rows_still_come_first() -> bool:
	var frozen_at: int = -1
	var first_word_at: int = -1
	var index: int = 0
	for row: ACEDescriptor in MODULE.get_descriptors():
		if row.ace_id == "SetParticleAmount":
			frozen_at = index
		if first_word_at < 0 and row.ace_id.begins_with("ParticleSet"):
			first_word_at = index
		index += 1
	return SUPPORT.pins("particle_words_test", [
		["the frozen amount row is still published", frozen_at >= 0, true],
		["and it is registered before the first word row", frozen_at < first_word_at, true]
	])


## No id is published twice - the whole module, frozen rows and words together.
static func _test_ids_are_unique() -> bool:
	var seen: Dictionary = {}
	var doubled: PackedStringArray = PackedStringArray()
	for row: ACEDescriptor in MODULE.get_descriptors():
		if seen.has(row.ace_id):
			doubled.append(row.ace_id)
		seen[row.ace_id] = true
	return SUPPORT.check("particle_words_test", "no id is published twice", doubled,
		PackedStringArray())


## Every word row and every field says what it is for.
static func _test_every_row_carries_help() -> bool:
	var silent: PackedStringArray = PackedStringArray()
	for row: ACEDescriptor in MODULE.get_descriptors():
		if not row.ace_id.begins_with("Particle"):
			continue
		if str(row.description).strip_edges().is_empty():
			silent.append(row.ace_id)
		for parameter: ACEParam in row.params:
			if str(parameter.description).strip_edges().is_empty():
				silent.append("%s.%s" % [row.ace_id, parameter.id])
	return SUPPORT.check("particle_words_test", "every word row and field carries help", silent,
		PackedStringArray())


## A LINE SOMEBODY TYPED reads as the word the sheet has for it - both through the material slot and
## on the emitter itself, which are the two gates the reading has to keep apart.
static func _test_a_hand_written_line_reads_as_the_word() -> bool:
	return SUPPORT.pin_table("particle_words_test", {
		"process_material.spread = 20.0|GPUParticles2D": "Set spread to 20",
		"process_material.gravity = Vector3(0, 9.8, 0)|GPUParticles2D":
			# The reading spells a vector the way the canvas shows one: the numbers, without the
			# constructor around them. That is the sheet's own convention and not this table's.
			"Set gravity to (0, 9.8, 0)",
		"process_material.initial_velocity_min = 40.0|GPUParticles2D":
			"Set slowest particle speed to 40",
		"process_material.scale_max = 3.0|GPUParticles3D": "Set biggest particle size to 3",
		"lifetime = 2.0|GPUParticles3D": "Set lifetime to 2",
		"amount = 64|GPUParticles2D": "Set amount to 64",
		# The class is the gate for the emitter's own two words: `lifetime` on anything else is
		# nobody's word here, and claiming it would rename lines this table knows nothing about.
		"lifetime = 2.0|AnimationPlayer": "(nothing)",
		# And a property no word here means keeps whatever reading it already had.
		"process_material.flatness = 1.0|GPUParticles2D": "(nothing)"
	}, func(line: Variant) -> String:
		var parts: PackedStringArray = str(line).split("|")
		var text: String = parts[0]
		var written: int = text.find(" = ")
		var target: String = text.substr(0, written)
		var dot_at: int = target.rfind(".")
		var said: Dictionary = EventSheetSentence.particle_word_assignment("Sparks", parts[1],
			target if dot_at < 0 else target.substr(dot_at + 1),
			"" if dot_at < 0 else target.substr(0, dot_at), text.substr(written + 3), {})
		if said.is_empty():
			return "(nothing)"
		var words: PackedStringArray = PackedStringArray()
		for segment: Variant in (said["segments"] as Array):
			words.append(str((segment as Dictionary)["text"]))
		return "".join(words))


## Every template the module publishes, by ace_id - the one walk the pins above share.
static func _templates() -> Dictionary:
	var found: Dictionary = {}
	for row: ACEDescriptor in MODULE.get_descriptors():
		found[row.ace_id] = str(row.codegen_template)
	return found
