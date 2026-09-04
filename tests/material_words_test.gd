# The material words, and the rows they build.
#
# The claim this file holds to account is that the sheet says ONE word where Godot says a property
# name: `metal` is `metallic`, `glow` is `emission_energy_multiplier` and does nothing until
# `emission_enabled` is true, `surface opacity` is the alpha channel of `albedo_color` and does nothing
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

## The fixture behind the sharing question and the two findings: a crate and a barrel wearing one
## stone material between them - one on the whole mesh, one on a surface slot - and a banner wearing
## a shader.
const FIXTURE_DIR: String = "res://tests/fixtures/"
const CRATE: String = FIXTURE_DIR + "material_scene_crate.gd"
const CRATE_SCENE: String = FIXTURE_DIR + "material_scene_crate.tscn"
const STONE: String = FIXTURE_DIR + "material_shared_stone.tres"
const BANNER_MATERIAL: String = FIXTURE_DIR + "material_banner_shader.tres"

## The lines every write opens with, written out here rather than read from the file under test:
## a test that builds its expectation from the same constant proves only that a constant equals
## itself. The `elif` is the half a shared `.tres` dropped into the Inspector needs - without it
## a mesh with an override was taken for a mesh that owns one, and every Set and Fade wrote the
## shared file.
const OWN_LINES := "if material_override == null:\n" \
	+ "\tmaterial_override = get_active_material(0).duplicate() if get_active_material(0) != null else StandardMaterial3D.new()\n" \
	+ "elif not material_override.resource_path.is_empty():\n" \
	+ "\tmaterial_override = material_override.duplicate()\n"


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_word_map() and ok
	ok = _test_the_defaults_come_from_classdb() and ok
	ok = _test_the_id_stems() and ok
	ok = _test_the_templates() and ok
	ok = _test_the_choice_words() and ok
	ok = _test_the_surface_slots() and ok
	ok = _test_the_sprite_words() and ok
	ok = _test_ids_are_unique() and ok
	ok = _test_no_name_lands_twice_on_one_node() and ok
	ok = _test_every_row_carries_help() and ok
	ok = _test_mesh_classes() and ok
	ok = _test_who_else_wears_it() and ok
	ok = _test_the_two_quiet_findings() and ok
	ok = _test_a_hand_written_line_reads_as_the_word() and ok
	# Dropped on the way out: a share index left warm here answers questions later tests never
	# asked, which a serial run notices and a sharded one hides.
	_fresh()
	return ok


## WHO ELSE WEARS IT, answered for a 3D scene. A mesh wears its material on `material_override` or on
## `surface_material_override/N`, and neither is the `material` the 2D walk reads - so before this,
## "who else wears this file" answered nothing at all however many meshes were sharing one `.tres`.
## Pinned by the NAMES that come back, over a fixture whose two meshes wear one file two different
## ways, because reading only one of the two spellings would still have looked like it worked.
static func _test_who_else_wears_it() -> bool:
	_fresh()
	EventSheetProjectShareIndex.build_scenes_now()
	var worn: PackedStringArray = PackedStringArray()
	for wearer: Dictionary in EventSheetProjectShareIndex.wearers_of(STONE):
		worn.append("%s in %s" % [str(wearer["name"]), str(wearer["scene_path"]).get_file()])
	var ok: bool = SUPPORT.check("material_words_test",
		"both spellings of a mesh's material are read", worn,
		PackedStringArray(["Crate in material_scene_crate.tscn",
			"Barrel in material_scene_crate.tscn"]))
	var meshes: PackedStringArray = PackedStringArray()
	for mesh: Dictionary in EventSheetProjectShareIndex.mesh_wearers_in(CRATE_SCENE):
		meshes.append("%s (%s) wears %s" % [str(mesh["name"]), str(mesh["class"]),
			", ".join(mesh["materials"] as PackedStringArray).get_file()])
	ok = SUPPORT.check("material_words_test", "and the other half of the question, per mesh", meshes,
		PackedStringArray(["Crate (MeshInstance3D) wears material_shared_stone.tres",
			"Barrel (MeshInstance3D) wears material_shared_stone.tres"])) and ok
	# The banner is a Sprite2D and wears its material the 2D way, so it is not a mesh wearer - but it
	# IS a wearer of its own file, which is what the sprite finding below is asked about.
	return SUPPORT.check("material_words_test", "a 2D item is not filed as a mesh",
		EventSheetProjectShareIndex.wearers_of(BANNER_MATERIAL).size(), 1) and ok


## THE TWO QUIET FINDINGS, pinned as the SENTENCES a reader meets. One is information and says so -
## every material word takes its own copy before it writes, so the other wearers are safe and the
## note carries no fix. The other is a row that really does nothing: blend on a 2D item lives inside
## its shader, and the row is written to leave that shader alone.
static func _test_the_two_quiet_findings() -> bool:
	_fresh()
	EventSheetProjectShareIndex.build_scenes_now()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.external_source_path = CRATE
	sheet.events.append(_word_event("MaterialSetColour", "", "Color.RED"))
	sheet.events.append(_word_event("MaterialSetBlending", "Banner",
		"CanvasItemMaterial.BLEND_MODE_ADD"))
	var found: Array[Dictionary] = EventSheetEffectFindings.findings(sheet)
	var said: PackedStringArray = PackedStringArray()
	for finding: Dictionary in found:
		said.append("%s [%s] %s" % [str(finding["kind"]), str(finding["severity"]),
			str(finding["message"])])
	return SUPPORT.check("material_words_test", "the words a reader meets under the two rows", said,
		PackedStringArray([
			"material-word-on-a-material-other-meshes-wear [info] material_shared_stone.tres is worn by Barrel as well, and a material is one object. Every material word here gives this mesh its own copy before it writes, so the others are left as they are - this is only worth knowing.",
			"material-word-on-an-item-wearing-a-shader [warning] Banner wears effect_dissolve.gdshader, and blending and lighting live inside a shader rather than on a property - so this row leaves the shader alone and the value goes nowhere. Set it in the shader, or move the row onto a child that wears no shader."
		]))


## WHAT A HAND-WRITTEN LINE READS AS. A project older than this plugin already writes these lines,
## and every one of them has to open as the WORD the sheet has for it rather than as the property
## name Godot happens to spell it with - the same promise a light's `energy` keeps by reading as
## brightness. Pinned as the SENTENCE, because the sentence is the whole of the claim.
##
## The refusals are pinned beside them, and they are the more important half: a line that reaches a
## material some other way, and a 2D item's `material.blend_mode` (which a mesh's material spells
## too, so a bare `material.` line cannot say which of the two words it means) both keep the plain
## property reading they already had.
static func _test_a_hand_written_line_reads_as_the_word() -> bool:
	var context: Dictionary = {"script_object": "Crate", "object_classes": {}}
	var read: Dictionary = {
		"material_override.albedo_color = Color.RED": "Crate ▸ Set colour to red",
		"material_override.albedo_color.a = 0.5": "Crate ▸ Set surface opacity to 0.5",
		"get_active_material(0).roughness = 0.2": "Crate ▸ Set roughness to 0.2",
		"$Barrel.material_override.metallic = 1.0": "Barrel ▸ Set metal to 1",
		# A CHOICE word says the dropdown word, not the constant behind it, so a typed line and a
		# picked row read the same sentence - and a value outside the dropdown falls back to the
		# ordinary expression reading rather than being called a word it is not.
		"get_active_material(1).cull_mode = BaseMaterial3D.CULL_DISABLED":
			"Crate ▸ Set sides to both",
		"material_override.blend_mode = BaseMaterial3D.BLEND_MODE_ADD":
			"Crate ▸ Set blend to add",
		"material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR":
			"Crate ▸ Set transparency to alpha scissor",
		"material_override.cull_mode = picked_mode": "Crate ▸ Set sides to picked_mode",
		# And the lines this must NOT claim.
		"material.blend_mode = 1": "material ▸ Set blend_mode to 1",
		"material_override.some_other_thing = 3": "material_override ▸ Set some_other_thing to 3"
	}
	return SUPPORT.pin_table("material_words_test", read, func(line: Variant) -> String:
		return _joined(EventSheetSentence.statement(str(line), context)))


## One statement reading as "object ▸ sentence" - the same shape every reading test joins.
static func _joined(reading: Dictionary) -> String:
	var text: String = ""
	for segment: Variant in (reading.get("segments", []) as Array):
		text += str((segment as Dictionary).get("text", ""))
	var object_label: String = str(reading.get("object", ""))
	return "%s ▸ %s" % [object_label, text.strip_edges()] if not object_label.is_empty() \
		else text.strip_edges()


## One event holding one material word aimed at `target`. Built here rather than lifted, because
## these rows are picked rather than typed: their templates are three lines, and a hand-written line
## that is only the last of the three is not one of them.
static func _word_event(ace_id: String, target: String, value: String) -> EventRow:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = {"target": target, "value": value}
	var event_row: EventRow = EventRow.new()
	event_row.actions.append(action)
	return event_row


## Every reader dropped, so one test's scan cannot answer the next one's question. The same call the
## editor makes when the filesystem changes.
static func _fresh() -> void:
	EventSheetProjectShareIndex.clear_cache()
	EventSheetSceneEffects.clear_cache()
	EventForgeShaderUniforms.clear_cache()


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
			"surface opacity": "albedo_color",
			"texture": "albedo_texture",
			"blend": "blend_mode",
			"transparency": "transparency",
			"sides": "cull_mode"
		})
	# The MEMBER a row writes is the property for eight of the nine, and the alpha channel of the
	# colour for the ninth - the one word whose property is not the thing it means.
	ok = SUPPORT.check("material_words_test", "surface opacity writes the colour's alpha channel",
		[W.member_of("surface opacity"), W.tween_path_of("surface opacity")],
		["albedo_color.a", "albedo_color:a"]) and ok
	return SUPPORT.check("material_words_test", "every word the table names really resolves",
		W.words().size(), W.WORDS.size()) and ok


## The value a row opens on is Godot's own, asked of ClassDB - so a dropped row starts where the
## engine starts and a reader never meets a number nobody chose. The one exception says why it is
## one: Godot registers `alpha_scissor_threshold` only while scissor is chosen, so ClassDB has no
## default to hand back and the table writes the engine's own down.
static func _test_the_defaults_come_from_classdb() -> bool:
	var defaults: Dictionary = {}
	for word: String in ["colour", "glow", "roughness", "metal", "surface opacity"]:
		defaults[word] = W.default_of(word)
	return SUPPORT.check("material_words_test", "each field opens on Godot's own default", defaults, {
		"colour": "Color.WHITE",
		"glow": "1.0",
		"roughness": "1.0",
		"metal": "0.0",
		"surface opacity": "1.0"
	})


## The one thing that is NOT derived, because an ace_id is a compatibility promise: the stem each
## word's rows are named after.
static func _test_the_id_stems() -> bool:
	var stems: Dictionary = {}
	for word: String in W.words():
		stems[word] = W.id_stem(word)
	return SUPPORT.check("material_words_test", "the frozen id stems", stems, {
		"colour": "Colour", "glow": "Glow", "roughness": "Roughness", "metal": "Metal",
		"surface opacity": "SeeThrough", "texture": "Texture", "blend": "Blend",
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
		["surface opacity switches the material to alpha transparency",
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
		# The read is a CAST, for the reason the sprite reads are: a mesh drawing with nothing
		# answers null and one wearing a shader answers a ShaderMaterial, and neither carries these
		# nine words. Both answer with the value a new material starts on instead of erroring.
		["a read answers with what a new material starts on when there is none",
			templates.get("MaterialMetal", ""),
			"(get_active_material(0) as BaseMaterial3D).metallic"
				+ " if get_active_material(0) is BaseMaterial3D else 0.0"],
		# A word whose starting value is a resource nobody set has no literal to fall back to, so
		# the read says null rather than ending in `else` with nothing after it.
		# The texture field is the PICTURE one rather than the general resource one, which lists
		# `.tres` and `.res` only and so could not offer a `.png` at all.
		["the texture field lists pictures",
			_hint_of("MaterialSetTexture", "value"), "texture_path"],
		["a picture word falls back to null rather than to nothing",
			templates.get("MaterialTexture", ""),
			"(get_active_material(0) as BaseMaterial3D).albedo_texture"
				+ " if get_active_material(0) is BaseMaterial3D else null"]
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
		# The 3D words only: the two a sprite has are pinned beside them, against their own class's
		# constants, because a CanvasItemMaterial's blend modes are not a BaseMaterial3D's.
		if str(row.node_type) != W.HOST:
			continue
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
		+ " if get_active_material({surface}) != null else StandardMaterial3D.new())\n" \
		+ "elif not get_surface_override_material({surface}).resource_path.is_empty():\n" \
		+ "\tset_surface_override_material({surface}," \
		+ " get_surface_override_material({surface}).duplicate())\n"
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


## THE OTHER SURFACE: the two words a 2D item has. What is pinned is the emitted BYTES, because the
## three promises those rows make are only kept by what they actually write - a sprite with nothing
## is given a material, a sprite wearing a shared FILE is given its own copy, and a sprite wearing a
## SHADER is left completely alone (the `is` guard is what leaves it alone; blend and light live
## inside the shader there and there is no property here to set).
const SPRITE_OWN_LINES := "if material == null:\n" \
	+ "\tmaterial = CanvasItemMaterial.new()\n" \
	+ "elif material is CanvasItemMaterial and not material.resource_path.is_empty():\n" \
	+ "\tmaterial = material.duplicate()\n"


static func _test_the_sprite_words() -> bool:
	var templates: Dictionary = _templates()
	var spelled: Dictionary = {}
	for row: ACEDescriptor in MODULE.get_descriptors():
		if row.ace_id != "MaterialSetBlending" and row.ace_id != "MaterialSetLightResponse":
			continue
		var pairs: Array = []
		for option: Variant in (row.params[0] as ACEParam).options:
			pairs.append("%s = %s" % [str((option as Dictionary)["label"]),
				str((option as Dictionary)["key"])])
		spelled[row.ace_id] = pairs
	var ok: bool = SUPPORT.pins("material_words_test", [
		["a sprite with no material is given one, a shared file is copied, a shader is untouched",
			templates.get("MaterialSetBlending", ""),
			SPRITE_OWN_LINES + "if material is CanvasItemMaterial:\n"
				+ "\tmaterial.blend_mode = {value}"],
		["how the lights reach it is the same shape",
			templates.get("MaterialSetLightResponse", ""),
			SPRITE_OWN_LINES + "if material is CanvasItemMaterial:\n"
				+ "\tmaterial.light_mode = {value}"],
		["a read answers for a sprite wearing a shader instead of reaching through it",
			templates.get("MaterialBlending", ""),
			"(material as CanvasItemMaterial).blend_mode if material is CanvasItemMaterial"
				+ " else CanvasItemMaterial.BLEND_MODE_MIX"],
		["and for one wearing nothing", templates.get("MaterialLightResponse", ""),
			"(material as CanvasItemMaterial).light_mode if material is CanvasItemMaterial"
				+ " else CanvasItemMaterial.LIGHT_MODE_NORMAL"]
	])
	ok = SUPPORT.check("material_words_test", "the sprite dropdowns and the constants they write",
		spelled, {
			"MaterialSetBlending": [
				"mix = CanvasItemMaterial.BLEND_MODE_MIX",
				"add = CanvasItemMaterial.BLEND_MODE_ADD",
				"subtract = CanvasItemMaterial.BLEND_MODE_SUB",
				"multiply = CanvasItemMaterial.BLEND_MODE_MUL",
				"premultiplied alpha = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA"],
			"MaterialSetLightResponse": [
				"normal = CanvasItemMaterial.LIGHT_MODE_NORMAL",
				"unshaded = CanvasItemMaterial.LIGHT_MODE_UNSHADED",
				"light only = CanvasItemMaterial.LIGHT_MODE_LIGHT_ONLY"]
		}) and ok
	# Both words resolve to a property CanvasItemMaterial really has, which is the one thing the
	# small table is derived from - and what counts as a sprite is asked through ClassDB.
	ok = SUPPORT.check("material_words_test", "both sprite words resolve", W.sprite_words(),
		PackedStringArray(["blending", "light response"])) and ok
	return SUPPORT.pin_table("material_words_test", {
		"Sprite2D": true,
		"Label": true,
		"MeshInstance3D": false,
		"Node": false,
		"": false
	}, func(class_text: Variant) -> bool: return W.is_sprite_class(str(class_text))) and ok


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
	# A VALUE rather than a literal count: what is being asserted is that no id was published
	# twice, so the number of distinct ids has to be the number of descriptors.
	return SUPPORT.check("material_words_test", "the module publishes every word's rows",
		seen.size(), MODULE.get_descriptors().size()) and ok


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
	# Every row is hosted on the node it writes THROUGH - the mesh for the nine 3D words and the four
	# surface rows, the canvas item for the two 2D ones. A row hosted on anything else would offer
	# itself on nodes whose property it cannot reach.
	var hosted: PackedStringArray = PackedStringArray()
	for row: ACEDescriptor in MODULE.get_descriptors():
		if str(row.node_type) != W.HOST and str(row.node_type) != W.SPRITE_HOST:
			hosted.append(row.ace_id)
	var ok: bool = SUPPORT.check("material_words_test", "every row and field carries help", silent,
		PackedStringArray())
	return SUPPORT.check("material_words_test", "every row is hosted on the node it writes through",
		hosted, PackedStringArray()) and ok


## One field's HINT, which is what decides the widget the dialog builds for it - and, for a file
## field, which files Browse is even willing to list.
static func _hint_of(ace_id: String, param_id: String) -> String:
	for row: ACEDescriptor in MODULE.get_descriptors():
		if row.ace_id != ace_id:
			continue
		for parameter: ACEParam in row.params:
			if parameter.id == param_id:
				return str(parameter.hint)
	return ""


## THE PICKER'S OWN QUESTION, which no id check can answer: two rows offered on ONE node must not be
## called the same thing. A MeshInstance3D IS a GeometryInstance3D and the picker matches with
## `ClassDB.is_parent_class`, so every Native 3D row lands on a mesh beside every row here - and
## "Set See-Through" was published twice, once as this shelf's material alpha (1 is solid) and once
## as the frozen per-instance `transparency` (0 is solid), with the two scales running opposite ways.
## The names are pinned as the collisions themselves rather than as a count, so a failure says which
## two rows and on what node.
static func _test_no_name_lands_twice_on_one_node() -> bool:
	var collisions: PackedStringArray = PackedStringArray()
	var published: Array = EventForgeBuiltinACEs.get_descriptors()
	for row: ACEDescriptor in MODULE.get_descriptors():
		for other: Variant in published:
			var them: ACEDescriptor = other
			if them.ace_id == row.ace_id or str(them.display_name) != str(row.display_name):
				continue
			if _lands_on_one_node(str(row.node_type), str(them.node_type)):
				collisions.append("%s: %s / %s" % [row.display_name, row.ace_id, them.ace_id])
	collisions.sort()
	return SUPPORT.check("material_words_test", "no row here shares a name on a node it lands on",
		collisions, PackedStringArray())


## True when two hosts put their rows in front of the same node: the same class, one a subclass of
## the other, or a row hosted on nothing at all, which is offered everywhere.
static func _lands_on_one_node(mine: String, theirs: String) -> bool:
	if theirs.is_empty() or theirs == mine:
		return true
	if not ClassDB.class_exists(mine) or not ClassDB.class_exists(theirs):
		return false
	return ClassDB.is_parent_class(mine, theirs) or ClassDB.is_parent_class(theirs, mine)


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
