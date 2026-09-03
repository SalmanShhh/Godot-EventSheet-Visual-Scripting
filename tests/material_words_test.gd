# The material words, and the rows they build.
#
# The claim this file holds to account is that the sheet says ONE word where Godot says a property
# name: `metal` is `metallic`, `glow` is `emission_energy_multiplier` and does nothing until
# `emission_enabled` is true, `see-through` is the alpha channel of `albedo_color` and does nothing
# until the material is in alpha transparency. The mapping is derived from ClassDB, so what is
# pinned here is the ANSWERS - by value - rather than the table that produces them.
#
# And the OWN-IT COURTESY, which is the whole reason these templates are three lines rather than
# one: every write duplicates whatever the mesh is drawing with into `material_override` first, so a
# material file worn by twelve meshes never changes under the other eleven. It is pinned as the
# emitted BYTES, because that promise is only kept by what the row actually writes.
@tool
class_name MaterialWordsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const W := preload("res://addons/eventforge/registration/material_words.gd")
const MODULE := preload("res://addons/eventforge/registration/modules/material_aces.gd")

## The two lines every write opens with, written out here rather than read from the file under test:
## a test that builds its expectation from the same constant proves only that a constant equals
## itself.
const OWN_LINES := "if material_override == null:\n" \
	+ "\tmaterial_override = get_active_material(0).duplicate() if get_active_material(0) != null else StandardMaterial3D.new()\n"


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_word_map() and ok
	ok = _test_the_defaults_come_from_classdb() and ok
	ok = _test_the_id_stems() and ok
	ok = _test_the_templates() and ok
	ok = _test_the_choice_words() and ok
	ok = _test_the_surface_slots() and ok
	ok = _test_ids_are_unique() and ok
	ok = _test_every_row_carries_help() and ok
	ok = _test_mesh_classes() and ok
	return ok


## Every word resolves to a property BaseMaterial3D really has - which is the one thing the whole
## vocabulary is derived from, so it is pinned by value, word by word.
static func _test_the_word_map() -> bool:
	var resolved: Dictionary = {}
	for word: String in W.words():
		resolved[word] = W.property_of(word)
	var ok: bool = SUPPORT.check("material_words_test", "each word resolves to its property",
		resolved, {
			"colour": "albedo_color",
			"glow": "emission_energy_multiplier",
			"roughness": "roughness",
			"metal": "metallic",
			"see-through": "albedo_color",
			"texture": "albedo_texture",
			"blend": "blend_mode",
			"transparency": "transparency",
			"sides": "cull_mode"
		})
	# The MEMBER a row writes is the property for eight of the nine, and the alpha channel of the
	# colour for the ninth - the one word whose property is not the thing it means.
	ok = SUPPORT.check("material_words_test", "see-through writes the colour's alpha channel",
		[W.member_of("see-through"), W.tween_path_of("see-through")],
		["albedo_color.a", "albedo_color:a"]) and ok
	return SUPPORT.check("material_words_test", "every word the table names really resolves",
		W.words().size(), W.WORDS.size()) and ok


## The value a row opens on is Godot's own, asked of ClassDB - so a dropped row starts where the
## engine starts and a reader never meets a number nobody chose. The one exception says why it is
## one: Godot registers `alpha_scissor_threshold` only while scissor is chosen, so ClassDB has no
## default to hand back and the table writes the engine's own down.
static func _test_the_defaults_come_from_classdb() -> bool:
	var defaults: Dictionary = {}
	for word: String in ["colour", "glow", "roughness", "metal", "see-through"]:
		defaults[word] = W.default_of(word)
	return SUPPORT.check("material_words_test", "each field opens on Godot's own default", defaults, {
		"colour": "Color.WHITE",
		"glow": "1.0",
		"roughness": "1.0",
		"metal": "0.0",
		"see-through": "1.0"
	})


## The one thing that is NOT derived, because an ace_id is a compatibility promise: the stem each
## word's rows are named after.
static func _test_the_id_stems() -> bool:
	var stems: Dictionary = {}
	for word: String in W.words():
		stems[word] = W.id_stem(word)
	return SUPPORT.check("material_words_test", "the frozen id stems", stems, {
		"colour": "Colour", "glow": "Glow", "roughness": "Roughness", "metal": "Metal",
		"see-through": "SeeThrough", "texture": "Texture", "blend": "Blend",
		"transparency": "Transparency", "sides": "Sides"
	})


## The bytes four rows write. The own-it lines first on every write, the switch a word does nothing
## without written on the same row, and a read that is the plain line a person would type.
static func _test_the_templates() -> bool:
	var templates: Dictionary = _templates()
	return SUPPORT.pins("material_words_test", [
		["a plain write owns the material first",
			templates.get("MaterialSetRoughness", ""),
			OWN_LINES + "material_override.roughness = {value}"],
		["glow turns emission on in the same row",
			templates.get("MaterialSetGlow", ""),
			OWN_LINES + "material_override.emission_enabled = true\n"
				+ "material_override.emission_energy_multiplier = {value}"],
		["see-through switches the material to alpha transparency",
			templates.get("MaterialSetSeeThrough", ""),
			OWN_LINES + "material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA\n"
				+ "material_override.albedo_color.a = {value}"],
		["a fade walks the owned copy, never the shared file",
			templates.get("MaterialFadeSeeThrough", ""),
			OWN_LINES + "material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA\n"
				+ "create_tween().tween_property(material_override, \"albedo_color:a\", {value}, {seconds})"],
		["transparency writes its companion threshold beside it",
			templates.get("MaterialSetTransparency", ""),
			OWN_LINES + "material_override.transparency = {value}\n"
				+ "material_override.alpha_scissor_threshold = {threshold}"],
		["a read is the plain line a person would type",
			templates.get("MaterialMetal", ""), "get_active_material(0).metallic"]
	])


## Every row's template by its id, read straight off the module rather than through the registry, so
## what is pinned is what the module authored - the cross-node transform's own effect on these rows
## is a separate claim, made in the vocabulary tests beside this one.
static func _templates() -> Dictionary:
	var found: Dictionary = {}
	for row: ACEDescriptor in MODULE.get_descriptors():
		found[row.ace_id] = str(row.codegen_template)
	return found


## The three dropdown words: what the reader sees, and the engine constant the row writes. A label
## drifting from its key is a row that says one thing and compiles another.
static func _test_the_choice_words() -> bool:
	var spelled: Dictionary = {}
	for row: ACEDescriptor in MODULE.get_descriptors():
		for parameter: ACEParam in row.params:
			if parameter.options.is_empty():
				continue
			var pairs: Array = []
			for option: Variant in parameter.options:
				pairs.append("%s = %s" % [str((option as Dictionary)["label"]),
					str((option as Dictionary)["key"])])
			spelled[row.ace_id] = pairs
	return SUPPORT.check("material_words_test", "the dropdown words and the constants they write",
		spelled, {
			"MaterialSetBlend": [
				"mix = BaseMaterial3D.BLEND_MODE_MIX",
				"add = BaseMaterial3D.BLEND_MODE_ADD",
				"subtract = BaseMaterial3D.BLEND_MODE_SUB",
				"multiply = BaseMaterial3D.BLEND_MODE_MUL",
				"premultiplied alpha = BaseMaterial3D.BLEND_MODE_PREMULT_ALPHA"],
			"MaterialSetTransparency": [
				"solid = BaseMaterial3D.TRANSPARENCY_DISABLED",
				"alpha = BaseMaterial3D.TRANSPARENCY_ALPHA",
				"alpha scissor = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR",
				"alpha hash = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH",
				"alpha with depth pre-pass = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS"],
			"MaterialSetSides": [
				"front = BaseMaterial3D.CULL_BACK",
				"back = BaseMaterial3D.CULL_FRONT",
				"both = BaseMaterial3D.CULL_DISABLED"]
		})


## The four rows that mean ONE SURFACE rather than the whole mesh. Two of them own that surface
## before they write it, and the fourth deliberately does not: a surface still drawing with a shared
## material file keeps its layer, because taking one off there would take it off every mesh wearing
## the file.
static func _test_the_surface_slots() -> bool:
	var templates: Dictionary = _templates()
	var own: String = "if get_surface_override_material({surface}) == null:\n" \
		+ "\tset_surface_override_material({surface}, get_active_material({surface}).duplicate()" \
		+ " if get_active_material({surface}) != null else StandardMaterial3D.new())\n"
	return SUPPORT.pins("material_words_test", [
		["one slot is painted without touching the others",
			templates.get("MaterialSetSurfaceMaterial", ""),
			"set_surface_override_material({surface}, {material})"],
		["a slot's material reads back as what it is drawing with",
			templates.get("MaterialSurfaceMaterial", ""), "get_active_material({surface})"],
		["a layer owns the slot before it lays anything over it",
			templates.get("MaterialLayerOverSurface", ""),
			own + "get_surface_override_material({surface}).next_pass = {material}"],
		["removing a layer leaves a shared material alone",
			templates.get("MaterialRemoveSurfaceLayer", ""),
			"if get_surface_override_material({surface}) != null:\n"
				+ "\tget_surface_override_material({surface}).next_pass = null"]
	])


## Every id this module publishes, once. An ace_id is a compatibility promise the moment it ships, so
## two descriptors answering to one id is a silent coin toss over which template a row compiles
## through.
static func _test_ids_are_unique() -> bool:
	var seen: Dictionary = {}
	var doubled: PackedStringArray = PackedStringArray()
	for row: ACEDescriptor in MODULE.get_descriptors():
		if seen.has(row.ace_id):
			doubled.append(row.ace_id)
		seen[row.ace_id] = true
	var ok: bool = SUPPORT.check("material_words_test", "no id is published twice", doubled,
		PackedStringArray())
	return SUPPORT.check("material_words_test", "the module publishes every word's rows",
		seen.size(), 27) and ok


## Help on the row and on every field it offers - the words a reader meets before they have run
## anything.
static func _test_every_row_carries_help() -> bool:
	var silent: PackedStringArray = PackedStringArray()
	for row: ACEDescriptor in MODULE.get_descriptors():
		if str(row.description).strip_edges().is_empty():
			silent.append(row.ace_id)
		for parameter: ACEParam in row.params:
			if str(parameter.description).strip_edges().is_empty() \
					or str(parameter.display_name).strip_edges().is_empty():
				silent.append("%s.%s" % [row.ace_id, parameter.id])
	var hosted: PackedStringArray = PackedStringArray()
	for row: ACEDescriptor in MODULE.get_descriptors():
		if str(row.node_type) != W.HOST:
			hosted.append(row.ace_id)
	var ok: bool = SUPPORT.check("material_words_test", "every row and field carries help", silent,
		PackedStringArray())
	return SUPPORT.check("material_words_test", "every row is hosted on the mesh it writes through",
		hosted, PackedStringArray()) and ok


## What counts as a mesh: the class itself and a project's own subclass of it, and nothing else.
## Asked through ClassDB rather than against a list, which is what lets a subclass resolve.
static func _test_mesh_classes() -> bool:
	return SUPPORT.pin_table("material_words_test", {
		"MeshInstance3D": true,
		"MultiMeshInstance3D": false,
		"GeometryInstance3D": false,
		"Sprite2D": false,
		"NotAClassAtAll": false,
		"": false
	}, func(class_text: Variant) -> bool: return W.is_mesh_class(str(class_text)))
