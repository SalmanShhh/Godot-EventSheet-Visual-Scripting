# EventForge module - the MATERIAL vocabulary: what a surface looks like, said in words.
#
# THE MESH AS THE OBJECT. Every row here is node-scoped: the mesh sits in the object column and the
# row says the word - "Crate - Set colour to Color(1, 0, 0)" - while the code echo shows the property
# the material really has. Nothing is written twice. The words come from EventForgeMaterialWords,
# which asks ClassDB which spelling each word resolves to and what value it opens on, and every row
# of every word is built by one of the four builders below (a value, a colour, a texture, a choice).
#
# THE OWN-IT COURTESY IS IN THE TEMPLATE, not in a row a reader has to remember. A material is a
# FILE: two meshes pointing at the same `.tres` point at ONE object, so recolouring the goblin the
# player hit recolours all twelve of them. So every write below opens with the lines that give this
# mesh its own copy - a duplicate of whatever it is drawing with now, parked on
# `material_override`, where it shadows the shared one for this node and no other. It is emitted,
# never assumed, and it is taken once: a mesh already wearing a copy of its own keeps it, and a mesh
# wearing a shared FILE in that slot is copied off it, because a material dropped into the Inspector
# is somebody else's just as much as the mesh's own surface material is.
#
# WHICH IS ALSO WHY THE WRITING ROWS ARE HOST-ONLY. Their templates open with an `if`, so the
# cross-node transform leaves them alone: a row that gives ANOTHER node its own copy and then writes
# through it would have to spell the same guard twice around a node named in the middle, and the
# shorter, plain reading is the mesh in the object column saying what it looks like. The READ rows
# are plain member reads and take the ordinary "On node" the transform appends to every such row -
# looking at another mesh's surface changes nothing on it, so there is nothing to own first.
#
# READING IT BACK. Every read row is the plain `get_active_material(0).<property>` a person would
# type, so a hand-written line and a picked row are the same bytes and read as the same sentence.
#
# 3D ONLY, and it says so: these nine words are BaseMaterial3D's. A sprite's look is a
# CanvasItemMaterial with two knobs of its own, and those two rows live at the foot of this file
# hosted on CanvasItem.
#
# AND NO ROW HERE IS CALLED WHAT ANOTHER SHELF ALREADY CALLS SOMETHING ELSE. The material's alpha is
# "surface opacity" rather than "see-through", because the Native 3D shelf has published Set
# See-Through - `GeometryInstance3D.transparency`, a per-instance fade with no material copy in it -
# since long before this file existed, a MeshInstance3D IS a GeometryInstance3D so both rows land on
# the same node, and the two scales run opposite ways.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility covenant).
@tool
class_name EventForgeMaterialACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")
const W := preload("res://addons/eventforge/registration/material_words.gd")

## The picker category every row here is filed under - one Material section, whichever of the words
## a reader came looking for.
const CAT := "Material"

## How long a fade takes when nobody says - the same half second every other fade in the vocabulary
## opens on, so two fades side by side start in step.
const DEFAULT_FADE_SECONDS := "0.5"

## The slot every word's value is edited in, spelled once so the lift, the tests and the picker
## address them all by it.
const VALUE_PARAM := "value"

## The two slots the surface rows carry: which surface, and the material the row is about.
const SURFACE_PARAM := "surface"
const MATERIAL_PARAM := "material"

## The field a texture is picked in - a file field over the project's own resources, rather than an
## expression box a path has to be typed into by hand.
const TEXTURE_HINT := "resource_path"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	for word: String in W.words():
		descriptors.append_array(_rows_of(word))
	descriptors.append_array(_surface_rows())
	for word: String in W.sprite_words():
		descriptors.append_array(_sprite_rows(W.sprite_word_entry(word)))
	return descriptors


## THE TWO WORDS A SPRITE HAS, at the foot of the file because they are the other surface: a 2D
## item's look is a CanvasItemMaterial with two knobs on it, not a BaseMaterial3D with nine. Each is
## a dropdown that sets it and an expression that reads it back.
##
## THREE THINGS THE WRITE DOES, in this order and for a reason each. A sprite drawing with nothing is
## given a plain material, because there is nothing to copy. One drawing with a material FILE is
## given its own copy of it first, so a `.tres` worn by every coin in the level never changes under
## the other coins. And a sprite wearing a SHADER is left completely alone: blend and light live
## inside that shader, there is no property here to set, and quietly setting nothing is better than a
## line that would fail - the Doctor's effects section says so where words belong.
static func _sprite_rows(entry: Dictionary) -> Array[ACEDescriptor]:
	var property: String = str(entry["property"])
	var template: String = "%sif %s is %s:\n\t%s.%s = {%s}" % [W.SPRITE_OWN_LINES, W.SPRITE_MEMBER,
		W.SPRITE_MATERIAL_CLASS, W.SPRITE_MEMBER, property, VALUE_PARAM]
	var setter: ACEDescriptor = F.act("Material%s" % str(entry["id_stem"]), str(entry["name"]),
		template, CAT, str(entry["verb"]), _sprite_about(entry), W.SPRITE_HOST).param_built(
		_choice_param(entry, str(entry["default"])))
	if bool(entry.get("featured", false)):
		setter.featured()
	# The read is written as a CAST rather than a plain member, for the reason the write has an `is`
	# in it: `material` on a CanvasItem is a Material, and only a CanvasItemMaterial carries these
	# two. A sprite wearing a shader, or wearing nothing, answers with the value Godot itself starts
	# a material on rather than reaching through something that is not there.
	var reader: ACEDescriptor = F.expr("Material%s" % str(entry["read_stem"]),
		str(entry["read_name"]),
		"(%s as %s).%s if %s is %s else %s" % [W.SPRITE_MEMBER, W.SPRITE_MATERIAL_CLASS, property,
			W.SPRITE_MEMBER, W.SPRITE_MATERIAL_CLASS, str(entry["default"])],
		CAT, str(entry["reads"]),
		"Reads the sprite's %s back: `%s.%s`. A sprite wearing a shader, or wearing no material at all, answers with the value a new material starts on. Use it in any value field." % [
			str(entry["word"]), W.SPRITE_MATERIAL_CLASS, property], W.SPRITE_HOST)
	return [setter, reader]


## What one sprite row does, said once: the word, then the three promises the template keeps.
static func _sprite_about(entry: Dictionary) -> String:
	return "%s Gives this item its own %s first when it is drawing with nothing or with a shared material file, so a material worn by other items never changes under them. An item wearing a shader is left alone: blend and light live inside the shader there. Writes `%s.%s`." % [
		str(entry["about"]), W.SPRITE_MATERIAL_CLASS, W.SPRITE_MATERIAL_CLASS,
		str(entry["property"])]


## THE SURFACE SLOTS, beside the frozen Set Mesh Material the Mesh section already ships. That row
## paints the WHOLE mesh with one material; a mesh imported from a model usually has several
## surfaces, one material each, and a game that wants the visor and not the helmet has to be able to
## say which. These four say it: set the material of one slot, read it back, lay a second material
## OVER it as a pass, and take that pass off again.
##
## THE SLOT IS A NUMBER, and the help says so rather than the field pretending to offer names. A
## surface's name lives in the imported mesh resource rather than in the scene, so a picker that
## listed names would have to load every mesh of every scene to build a dropdown, and would still
## have nothing to show for a mesh built at run time by the primitive builders. Mesh Surface Count
## answers how many there are, and slot 0 is the whole of a single-surface mesh.
static func _surface_rows() -> Array[ACEDescriptor]:
	return [
		F.act("MaterialSetSurfaceMaterial", "Set Material Of Surface",
			"%s({%s}, {%s})" % [W.SURFACE_OVERRIDE_SET, SURFACE_PARAM, MATERIAL_PARAM], CAT,
			"Set material of surface {%s} to {%s}" % [SURFACE_PARAM, MATERIAL_PARAM],
			"Gives ONE surface of the mesh its own material, leaving the others alone - which is what a model with a body, a visor and a pack needs, and what Set Mesh Material cannot do because it paints all of them at once. Writes `MeshInstance3D.set_surface_override_material`.",
			W.HOST).param_built(_surface_param("Which surface to paint."))
			.param("material", "null", "Material", "A Material resource, or a variable holding one.",
				"expression").featured(),
		F.expr("MaterialSurfaceMaterial", "Material Of Surface",
			"%s({%s})" % [W.ACTIVE_CALL, SURFACE_PARAM], CAT,
			"material of surface {%s}" % SURFACE_PARAM,
			"The material one surface is drawing with right now - its own override when it has one, and the mesh's otherwise. Use it in any value field. Writes `MeshInstance3D.get_active_material`.",
			W.HOST).param_built(_surface_param("Which surface to ask about.")),
		F.act("MaterialLayerOverSurface", "Layer Over Surface",
			"%s%s({%s}).%s = {%s}" % [W.own_surface_lines("{%s}" % SURFACE_PARAM),
				W.SURFACE_OVERRIDE_GET, SURFACE_PARAM, W.NEXT_PASS_MEMBER, MATERIAL_PARAM], CAT,
			"Layer {%s} over surface {%s}" % [MATERIAL_PARAM, SURFACE_PARAM],
			"Draws a second material OVER one surface without replacing what is under it - an outline, a frost, a shield shimmer over the skin the model came with. Gives that surface its own copy first, so the layer never appears on every other mesh wearing the same material file. Writes `Material.next_pass`.",
			W.HOST).param_built(_surface_param("Which surface to lay the second material over."))
			.param("material", "null", "Layer", "The material drawn over the one already there.",
				"expression"),
		F.act("MaterialRemoveSurfaceLayer", "Remove Layer",
			"if %s({%s}) != null:\n\t%s({%s}).%s = null" % [W.SURFACE_OVERRIDE_GET, SURFACE_PARAM,
				W.SURFACE_OVERRIDE_GET, SURFACE_PARAM, W.NEXT_PASS_MEMBER], CAT,
			"Remove the layer over surface {%s}" % SURFACE_PARAM,
			"Takes the second material back off a surface this mesh owns. A surface still drawing with a shared material file is left alone on purpose: the layer on it belongs to every mesh wearing that file, and taking it off here would take it off all of them.",
			W.HOST).param_built(_surface_param("Which surface to take the layer off."))
	]


## The slot field, said the same way on every row that has one. A plain expression rather than a
## dropdown, for the reason the section header gives.
static func _surface_param(about: String) -> ACEParam:
	return F.make_param(SURFACE_PARAM, "String", "0", "Surface",
		"%s Surfaces are numbered from 0; Mesh Surface Count says how many this mesh has, and a mesh with one surface only has surface 0." % about,
		"expression")


## The rows of this module that WRITE, by ace_id and by which surface they write - `{"mesh": [...],
## "sprite": [...]}`. What the Doctor's effects section asks a row about before it says anything
## about the material underneath it, and derived from the descriptors published above rather than
## listed by hand, so a word added to the table is asked about with nothing added here. Built once
## for the life of the process: an ace_id is frozen and this answer never changes.
static var _writing_ids: Dictionary = {}


static func writing_ids() -> Dictionary:
	if not _writing_ids.is_empty():
		return _writing_ids
	var mesh: PackedStringArray = PackedStringArray()
	var sprite: PackedStringArray = PackedStringArray()
	for row: ACEDescriptor in get_descriptors():
		if row.ace_type != ACEDescriptor.ACEType.ACTION:
			continue
		if str(row.node_type) == W.SPRITE_HOST:
			sprite.append(row.ace_id)
		else:
			mesh.append(row.ace_id)
	_writing_ids = {"mesh": mesh, "sprite": sprite}
	return _writing_ids


static func section_descriptions() -> Dictionary:
	return {CAT: "What a surface looks like, said in words. On a mesh: its colour, glow, roughness, metal, see-through, texture, blend, transparency, which of its sides are drawn, and the material of one surface slot. On a 2D item: how it blends and how the lights reach it. Every write gives the node its own copy of the material first, so a material shared between nodes never changes under the others."}


## Every row one word makes: the Set row, the expression that reads it back, and - for a word a
## surface can be walked to over time - the one-line tween a fade is.
static func _rows_of(word: String) -> Array[ACEDescriptor]:
	var entry: Dictionary = W.word_entry(word)
	match str(entry["kind"]):
		W.KIND_CHOICE:
			return _choice_rows(entry)
		W.KIND_TEXTURE:
			return _texture_rows(entry)
		W.KIND_COLOUR:
			return _colour_rows(entry)
		_:
			return _value_rows(entry)


## A word that is set to a NUMBER, and can be walked to one over time.
static func _value_rows(entry: Dictionary) -> Array[ACEDescriptor]:
	var word: String = str(entry["word"])
	var rows: Array[ACEDescriptor] = [
		_set_row(entry).param_typed("String", VALUE_PARAM, W.default_of(word), _label(entry),
			str(entry["about"]), "expression"),
		_read_row(entry)
	]
	if bool(entry.get("fades", false)):
		rows.append(_fade_row(entry))
	return rows


## A word that is set to a COLOUR - the same pair, with the field that opens a colour picker.
static func _colour_rows(entry: Dictionary) -> Array[ACEDescriptor]:
	var word: String = str(entry["word"])
	var rows: Array[ACEDescriptor] = [
		_set_row(entry).param_typed("Color", VALUE_PARAM, W.default_of(word), _label(entry),
			str(entry["about"]), "color"),
		_read_row(entry)
	]
	if bool(entry.get("fades", false)):
		rows.append(_fade_row(entry))
	return rows


## A word that is set to a PICTURE. No fade: a texture is swapped, never walked to.
static func _texture_rows(entry: Dictionary) -> Array[ACEDescriptor]:
	return [
		_set_row(entry).param_typed("String", VALUE_PARAM, "null", _label(entry),
			str(entry["about"]), TEXTURE_HINT),
		_read_row(entry)
	]


## A word that is one of a FIXED LIST of engine constants - a dropdown reading the plain word while
## the key stays the constant the template writes. A word with a companion property carries it on the
## same row, because it is the same decision.
static func _choice_rows(entry: Dictionary) -> Array[ACEDescriptor]:
	var word: String = str(entry["word"])
	var setter: ACEDescriptor = _set_row(entry).param_built(
		_choice_param(entry, W.default_of(word)))
	var companion: Dictionary = entry.get("companion", {})
	if not companion.is_empty():
		setter.param_typed("String", str(companion["param"]), str(companion["default"]),
			str(companion["label"]), str(companion["about"]), "expression")
	return [setter, _read_row(entry)]


## The dropdown one choice word offers. `display_option_labels` is what makes the ROW read "Set blend
## to mix" instead of "Set blend to BaseMaterial3D.BLEND_MODE_MIX": the KEY is still the engine
## constant (it is what the template writes and what every saved row holds, both frozen), and only
## the word a reader sees changes. `opening` is the constant the field starts on, which the 3D words
## ask ClassDB for and the two sprite words carry in the table - a CanvasItemMaterial's own defaults
## are the ones Godot hands a new material, and they are written beside the choices they belong to.
static func _choice_param(entry: Dictionary, opening: String) -> ACEParam:
	var parameter: ACEParam = F.make_param(VALUE_PARAM, "String", opening,
		_label(entry), str(entry["about"]), "", entry["choices"] as Array)
	parameter.display_option_labels = true
	return parameter


## The Set row of any word: the own-it lines, whatever switch the word does nothing without, and then
## the write itself.
static func _set_row(entry: Dictionary) -> ACEDescriptor:
	var word: String = str(entry["word"])
	var row: ACEDescriptor = F.act("MaterialSet%s" % W.id_stem(word), str(entry["name"]),
		_write_template(entry), CAT, str(entry["verb"]), _about(entry), W.HOST)
	return row.featured() if bool(entry.get("featured", false)) else row


## The expression that reads a word back - the plain line a person would type, so a hand-written read
## and a picked one are the same bytes.
static func _read_row(entry: Dictionary) -> ACEDescriptor:
	var word: String = str(entry["word"])
	return F.expr("Material%s" % W.id_stem(word), str(entry["name"]).trim_prefix("Set "),
		"%s(0).%s" % [W.ACTIVE_CALL, W.member_of(word)], CAT, str(entry["reads"]),
		"Reads the surface's %s back: %s. Use it in any value field." % [word, _echo(entry)], W.HOST)


## The one row that is not a plain write: a tween walks the property from where it is to where the
## row says, over a number of seconds. The own-it lines come first here too, because the tween holds
## on to the material it was handed and would otherwise walk a shared one.
static func _fade_row(entry: Dictionary) -> ACEDescriptor:
	var word: String = str(entry["word"])
	var template: String = "%screate_tween().tween_property(%s, \"%s\", {%s}, {seconds})" % [
		_preamble(entry), W.OVERRIDE_MEMBER, W.tween_path_of(word), VALUE_PARAM]
	return F.act("MaterialFade%s" % W.id_stem(word), "Fade %s" % _fade_name(entry), template, CAT,
		"Fade %s to {%s} over {seconds} s" % [word, VALUE_PARAM],
		"Walks the surface's %s to a new value over time instead of jumping to it - one tween, no state to keep. Writes %s on this mesh's own copy of the material." % [
			word, _echo(entry)], W.HOST).param_typed(
		"Color" if str(entry["kind"]) == W.KIND_COLOUR else "String", VALUE_PARAM,
		W.default_of(word), _label(entry), "The %s to arrive at." % word,
		"color" if str(entry["kind"]) == W.KIND_COLOUR else "expression").param_typed(
		"String", "seconds", DEFAULT_FADE_SECONDS, "Seconds", "How long the fade takes.",
		"expression")


## The whole write of one word: the preamble, then the member operation itself.
static func _write_template(entry: Dictionary) -> String:
	var word: String = str(entry["word"])
	var lines: String = "%s%s.%s = {%s}" % [_preamble(entry), W.OVERRIDE_MEMBER, W.member_of(word),
		VALUE_PARAM]
	var companion: Dictionary = entry.get("companion", {})
	if companion.is_empty():
		return lines
	return "%s\n%s.%s = {%s}" % [lines, W.OVERRIDE_MEMBER, str(companion["property"]),
		str(companion["param"])]


## Everything a write needs before it: this mesh's own copy of the material, then whatever switch the
## word does nothing without (glow needs emission on; see-through needs alpha transparency).
static func _preamble(entry: Dictionary) -> String:
	var lines: String = W.OWN_LINES
	if entry.has("turns_on"):
		lines += "%s.%s = true\n" % [W.OVERRIDE_MEMBER, str(entry["turns_on"])]
	for property: Variant in (entry.get("sets", {}) as Dictionary):
		lines += "%s.%s = %s\n" % [W.OVERRIDE_MEMBER, str(property),
			str((entry["sets"] as Dictionary)[property])]
	return lines


## What a row does, said once per word: the word, then the own-it promise, then the property the
## material really answers to - so the description and the code echo can never disagree.
static func _about(entry: Dictionary) -> String:
	return "%s Gives this mesh its own copy of the material first, so a material shared with other meshes never changes under them. Writes %s, the override every %s wears." % [
		str(entry["about"]), _echo(entry), W.OVERRIDE_ROOT]


## The property a row writes, as the reader sees it in the code echo.
static func _echo(entry: Dictionary) -> String:
	return "`%s.%s`" % [W.OVERRIDE_MEMBER, W.member_of(str(entry["word"]))]


## The field's name in the dialog: the word's own label where it has one, and the word itself
## otherwise.
static func _label(entry: Dictionary) -> String:
	return str(entry.get("label", str(entry["word"]).capitalize()))


## What a FADE row is called: the word's Set row without its verb, so "Set Colour" and "Fade Colour"
## are the same words twice. The dialog LABEL is not used here - it is a field's name, written in the
## sentence case a field wears, and "Fade Surface opacity" is not a row title.
static func _fade_name(entry: Dictionary) -> String:
	return str(entry["name"]).trim_prefix("Set ")
