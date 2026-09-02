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

	descriptors.append(F.expr("SeededValue", "Seeded Value", "(float(absi(hash(str({seed}) + \"#\" + str({index}))) % 1000000) / 1000000.0)", CAT, "seeded value {seed} #{index}", "A stable pseudo-random float in [0, 1) for a seed and an index - the same inputs always give the same value. No autoload, so it works in Editor Tool sheets and while generating Custom Resource data, as well as at runtime.").param_built(_seed_param()).param_built(_index_param()).featured())

	descriptors.append(F.expr("SeededInt", "Seeded Int", "({minimum} + absi(hash(str({seed}) + \"#\" + str({index}))) % maxi({maximum} - {minimum} + 1, 1))", CAT, "seeded int {seed} #{index} in {minimum}..{maximum}", "A stable pseudo-random integer between min and max (inclusive) for a seed and an index - deterministic, no autoload.").param_built(_seed_param()).param_built(_index_param()).param_typed("int", "minimum", "0", "Min", "Lowest value (inclusive).", "expression").param_typed("int", "maximum", "9", "Max", "Highest value (inclusive).", "expression"))

	descriptors.append(F.expr("SeededPick", "Seeded Pick", "(({options} as Array)[absi(hash(str({seed}) + \"#\" + str({index}))) % maxi(({options} as Array).size(), 1)] if not ({options} as Array).is_empty() else null)", CAT, "seeded pick from {options} ({seed} #{index})", "A stable pseudo-random element of an array for a seed and an index (null if empty) - deterministic, no autoload.").param_built(_seed_param()).param_built(_index_param()).param_typed("Array", "options", "[]", "Options", "The array to pick from.", "expression"))

	descriptors.append(F.expr("SeededSign", "Seeded Sign", "(1 if (absi(hash(str({seed}) + \"#\" + str({index}))) % 2) == 0 else -1)", CAT, "seeded sign {seed} #{index}", "A stable -1 or +1 for a seed and an index - deterministic, no autoload.").param_built(_seed_param()).param_built(_index_param()))

	descriptors.append(F.cond("SeededChance", "Seeded Chance", "((float(absi(hash(str({seed}) + \"#\" + str({index}))) % 1000000) / 1000000.0) * 100.0 < {percent})", CAT, "seeded chance {percent}% ({seed} #{index})", "True for a stable share of seed+index pairs (0-100) - a deterministic Chance you can use in tools and resource generation.").param_built(_seed_param()).param_built(_index_param()).param_typed("float", "percent", "50.0", "Percent", "Chance from 0 to 100.", "expression"))

	return descriptors


static func _seed_param() -> ACEParam:
	return F.make_param("seed", "String", "\"map\"", "Seed", "Any seed text - the same seed reproduces the same sequence.", "expression")


static func _index_param() -> ACEParam:
	return F.make_param("index", "int", "0", "Index", "Which value in the sequence (a cell number, an item index, a tile coordinate hash, ...).", "expression")


static func section_descriptions() -> Dictionary:
	return {CAT: "Stateless seeded generation (a seed + an index -> a stable value), usable where the Advanced Random autoload is not: inside Editor Tool sheets and while filling Custom Resources, as well as at runtime."}
