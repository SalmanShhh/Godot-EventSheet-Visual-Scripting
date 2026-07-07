# EventForge module - Procedural vocabulary (stateless, seeded generation for tools + resources).
#
# The Advanced Random pack is an autoload, so it only runs in the game. These are its STATELESS cousins:
# pure hash-based expressions that need no autoload and hold no state, so a seed plus an index always
# gives the same value. That makes them usable where the autoload is not - inside an Editor Tool sheet
# generating content in the editor, or while filling a Custom Resource with procedural data - as well as
# at runtime. They compile to plain Godot (hash / absi), honouring the parity covenant. Grouped under
# "Procedural"; the game-time seeded generators live in the Advanced Random pack.
@tool
class_name EventForgeProceduralACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Procedural"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	descriptors.append(F.make_descriptor("Core", "SeededValue", "Seeded Value", ACEDescriptor.ACEType.EXPRESSION, "(float(absi(hash(str({seed}) + \"#\" + str({index}))) % 1000000) / 1000000.0)", "", [_seed_param(), _index_param()], CAT, "seeded value {seed} #{index}")
		.described("A stable pseudo-random float in [0, 1) for a seed and an index - the same inputs always give the same value. No autoload, so it works in Editor Tool sheets and while generating Custom Resource data, as well as at runtime.").featured())

	descriptors.append(F.make_descriptor("Core", "SeededInt", "Seeded Int", ACEDescriptor.ACEType.EXPRESSION, "({minimum} + absi(hash(str({seed}) + \"#\" + str({index}))) % maxi({maximum} - {minimum} + 1, 1))", "", [_seed_param(), _index_param(), F.make_param("minimum", "int", "0", "Min", "Lowest value (inclusive).", "expression"), F.make_param("maximum", "int", "9", "Max", "Highest value (inclusive).", "expression")], CAT, "seeded int {seed} #{index} in {minimum}..{maximum}")
		.described("A stable pseudo-random integer between min and max (inclusive) for a seed and an index - deterministic, no autoload."))

	descriptors.append(F.make_descriptor("Core", "SeededPick", "Seeded Pick", ACEDescriptor.ACEType.EXPRESSION, "(({options} as Array)[absi(hash(str({seed}) + \"#\" + str({index}))) % maxi(({options} as Array).size(), 1)] if not ({options} as Array).is_empty() else null)", "", [_seed_param(), _index_param(), F.make_param("options", "Array", "[]", "Options", "The array to pick from.", "expression")], CAT, "seeded pick from {options} ({seed} #{index})")
		.described("A stable pseudo-random element of an array for a seed and an index (null if empty) - deterministic, no autoload."))

	descriptors.append(F.make_descriptor("Core", "SeededSign", "Seeded Sign", ACEDescriptor.ACEType.EXPRESSION, "(1 if (absi(hash(str({seed}) + \"#\" + str({index}))) % 2) == 0 else -1)", "", [_seed_param(), _index_param()], CAT, "seeded sign {seed} #{index}")
		.described("A stable -1 or +1 for a seed and an index - deterministic, no autoload."))

	descriptors.append(F.make_descriptor("Core", "SeededChance", "Seeded Chance", ACEDescriptor.ACEType.CONDITION, "((float(absi(hash(str({seed}) + \"#\" + str({index}))) % 1000000) / 1000000.0) * 100.0 < {percent})", "", [_seed_param(), _index_param(), F.make_param("percent", "float", "50.0", "Percent", "Chance from 0 to 100.", "expression")], CAT, "seeded chance {percent}% ({seed} #{index})")
		.described("True for a stable share of seed+index pairs (0-100) - a deterministic Chance you can use in tools and resource generation."))

	return descriptors


static func _seed_param() -> ACEParam:
	return F.make_param("seed", "String", "\"map\"", "Seed", "Any seed text - the same seed reproduces the same sequence.", "expression")


static func _index_param() -> ACEParam:
	return F.make_param("index", "int", "0", "Index", "Which value in the sequence (a cell number, an item index, a tile coordinate hash, ...).", "expression")


static func section_descriptions() -> Dictionary:
	return {CAT: "Stateless seeded generation (a seed + an index -> a stable value), usable where the Advanced Random autoload is not: inside Editor Tool sheets and while filling Custom Resources, as well as at runtime."}
