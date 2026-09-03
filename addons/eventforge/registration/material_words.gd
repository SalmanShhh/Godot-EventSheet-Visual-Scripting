# EventForge - the MATERIAL WORDS: nine things a game touches on a surface, and the property each one
# really is.
#
# A mesh's LOOK is one resource with a hundred properties on it, and the nine below are the ones a
# game reaches for at run time: what colour it is, how hard it glows, how rough and how metal it
# looks, how see-through it is, what picture is painted on it, how it blends with what is behind it,
# how it handles transparency, and which of its two sides are drawn. Godot keeps every one of them on
# BaseMaterial3D, and a reader should not have to know that `metal` is spelled `metallic` and that
# `glow` is spelled `emission_energy_multiplier` and only does anything once `emission_enabled` is
# true.
#
# So the mapping is DERIVED, exactly the way the light words are. The table below says only what the
# WORDS are and which spellings each word can take, in preference order; which of those spellings the
# material class actually answers to is asked of ClassDB, and so is the value each row opens on. Add
# a spelling and the rows resolve themselves.
#
# THE ONE THING THAT IS NOT DERIVED is the `ace_id` stem beside each spelling, and it cannot be: an
# ace_id is a compatibility promise (a sheet saved today names it forever), so it is written down
# once, frozen, and never computed from a property name the engine could rename under it.
#
# THE OWN-IT COURTESY, and why it is in the template rather than in a row of its own. A material is a
# FILE, and two meshes pointing at the same `.tres` are pointing at ONE object: recolouring the
# goblin the player hit recolours all twelve of them. So every write below is preceded by the two
# lines that give this mesh its own copy first - a duplicate of whatever it is drawing with now,
# parked on `material_override`, where it shadows the shared one for this node and no other. The
# guard is `material_override == null` rather than a meta flag, because the override IS the flag: it
# is the thing the copy is stored in, so a mesh that has one has already been given one, and a mesh
# whose override was cleared by some later row is given a fresh copy rather than writing through a
# null. The copy is taken once, whichever of the two ways the row is reached.
#
# 2D IS A DIFFERENT SURFACE, not a second dimension of this one: a sprite's look is a
# CanvasItemMaterial with two knobs (blend and light mode), not a BaseMaterial3D with nine. Those two
# words live beside these in material_aces.gd and are hosted on CanvasItem; the seven that have no
# 2D meaning are 3D-only and say so.
@tool
class_name EventForgeMaterialWords
extends RefCounted

## The node class every row here is hosted on - the one that can be asked what it is drawing with
## (`get_active_material`) and given its own copy of it. A bare GeometryInstance3D wears
## `material_override` but cannot answer the first question, so it is not offered rows that would
## have to guess.
const HOST: String = "MeshInstance3D"

## Where the override a row writes through really lives, for the code echo: `material_override` is
## GeometryInstance3D's, and every MeshInstance3D inherits it.
const OVERRIDE_ROOT: String = "GeometryInstance3D"

## The member a row's copy is parked on, and the call that answers what a mesh is drawing with now.
const OVERRIDE_MEMBER: String = "material_override"
const ACTIVE_CALL: String = "get_active_material"

## The two calls a SURFACE SLOT is addressed through - one material per slot, beside the whole-mesh
## override above.
const SURFACE_OVERRIDE_GET: String = "get_surface_override_material"
const SURFACE_OVERRIDE_SET: String = "set_surface_override_material"

## The member one material hands the drawing on to - a second pass drawn over the first.
const NEXT_PASS_MEMBER: String = "next_pass"

## The class the words are RESOLVED against: every spelling below is a property of it, or of nothing.
## Asked of ClassDB rather than listed, so a spelling the engine moves is a spelling this stops
## claiming rather than one that quietly writes nothing.
const MATERIAL_ROOT: String = "BaseMaterial3D"

## The class the DEFAULTS are asked of - the concrete material Godot hands a new mesh, and the only
## one that can be asked for a property's starting value.
const MATERIAL_CLASS: String = "StandardMaterial3D"

## The material a mesh drawing with nothing at all is given, so a row on a bare MeshInstance3D writes
## a surface rather than reaching through a null.
const FALLBACK_MATERIAL: String = "StandardMaterial3D"

## What kind of row a word makes. A VALUE word is set to a number and can be read back; a COLOUR is a
## value with a colour field rather than an expression one; a TEXTURE takes a picture; a CHOICE is
## one of a fixed list of engine constants. One builder per kind, in material_aces.gd.
const KIND_VALUE: String = "value"
const KIND_COLOUR: String = "colour"
const KIND_TEXTURE: String = "texture"
const KIND_CHOICE: String = "choice"

## THE TWO LINES every write is preceded by - the own-it courtesy, spelled once. A mesh that already
## has its own override keeps it; one that has none is given a copy of whatever it is drawing with,
## or a plain material when it is drawing with nothing.
const OWN_LINES: String = "if %s == null:\n\t%s = %s(0).duplicate() if %s(0) != null else %s.new()\n" % [
	OVERRIDE_MEMBER, OVERRIDE_MEMBER, ACTIVE_CALL, ACTIVE_CALL, FALLBACK_MATERIAL]

## THE WORDS. One entry per thing a game touches, and for each one the spellings it can take in
## preference order, as `property -> ace_id stem`. The stems are frozen (see the header); which
## spelling the material class resolves to is not written down anywhere, it is asked of ClassDB.
##
## `member` is the path a row WRITES when that is not the property itself (see-through is the alpha
## channel of the colour). `turns_on` is the switch a word does nothing without, written on the same
## row rather than left as a second thing to remember. `sets` is the same idea for a word that only
## means anything in one mode.
const WORDS: Array[Dictionary] = [
	{
		"word": "colour",
		"kind": KIND_COLOUR,
		"name": "Set Colour",
		"verb": "Set colour to {value}",
		"reads": "colour",
		"about": "The colour the surface is painted, before any light falls on it.",
		"fades": true,
		"featured": true,
		"spellings": {"albedo_color": "Colour"}
	},
	{
		"word": "glow",
		"kind": KIND_VALUE,
		"name": "Set Glow",
		"verb": "Set glow to {value}",
		"reads": "glow",
		"about": "How hard the surface gives off light of its own: 0 is dark, 1 is lit, higher bleeds into the world's glow.",
		"fades": true,
		"featured": true,
		"turns_on": "emission_enabled",
		"spellings": {"emission_energy_multiplier": "Glow"}
	},
	{
		"word": "roughness",
		"kind": KIND_VALUE,
		"name": "Set Roughness",
		"verb": "Set roughness to {value}",
		"reads": "roughness",
		"about": "How scattered the reflections are, as a fraction: 0 is a mirror, 1 is chalk.",
		"fades": true,
		"spellings": {"roughness": "Roughness"}
	},
	{
		"word": "metal",
		"kind": KIND_VALUE,
		"name": "Set Metal",
		"verb": "Set metal to {value}",
		"reads": "metal",
		"about": "How metal the surface reads, as a fraction: 0 is paint or plastic, 1 is bare metal.",
		"fades": true,
		"spellings": {"metallic": "Metal"}
	},
	{
		"word": "see-through",
		"kind": KIND_VALUE,
		"name": "Set See-Through",
		"verb": "Set see-through to {value}",
		"reads": "see-through",
		"label": "See-Through",
		"about": "How solid the surface is: 1 is solid, 0 is invisible. Godot keeps it as the colour's alpha channel, which does nothing until the material is in alpha transparency - so the row switches that on as well.",
		"fades": true,
		"member": "albedo_color:a",
		"tween_path": "albedo_color:a",
		"default": "1.0",
		"sets": {"transparency": "BaseMaterial3D.TRANSPARENCY_ALPHA"},
		"spellings": {"albedo_color": "SeeThrough"}
	},
	{
		"word": "texture",
		"kind": KIND_TEXTURE,
		"name": "Set Texture",
		"verb": "Set texture to {value}",
		"reads": "texture",
		"about": "The picture painted over the surface. Blank it with null to go back to a flat colour.",
		"spellings": {"albedo_texture": "Texture"}
	},
	{
		"word": "blend",
		"kind": KIND_CHOICE,
		"name": "Set Blend",
		"verb": "Set blend to {value}",
		"reads": "blend",
		"label": "Blend",
		"about": "How the surface is mixed with whatever is already drawn behind it.",
		"choices": [
			{"key": "BaseMaterial3D.BLEND_MODE_MIX", "label": "mix"},
			{"key": "BaseMaterial3D.BLEND_MODE_ADD", "label": "add"},
			{"key": "BaseMaterial3D.BLEND_MODE_SUB", "label": "subtract"},
			{"key": "BaseMaterial3D.BLEND_MODE_MUL", "label": "multiply"},
			{"key": "BaseMaterial3D.BLEND_MODE_PREMULT_ALPHA", "label": "premultiplied alpha"}
		],
		"default": "BaseMaterial3D.BLEND_MODE_MIX",
		"spellings": {"blend_mode": "Blend"}
	},
	{
		"word": "transparency",
		"kind": KIND_CHOICE,
		"name": "Set Transparency",
		"verb": "Set transparency to {value}",
		"reads": "transparency",
		"label": "Transparency",
		"about": "How the surface handles being see-through at all. Scissor keeps every pixel either fully there or fully gone, which is what leaves and fences want and what costs the least.",
		"choices": [
			{"key": "BaseMaterial3D.TRANSPARENCY_DISABLED", "label": "solid"},
			{"key": "BaseMaterial3D.TRANSPARENCY_ALPHA", "label": "alpha"},
			{"key": "BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR", "label": "alpha scissor"},
			{"key": "BaseMaterial3D.TRANSPARENCY_ALPHA_HASH", "label": "alpha hash"},
			{"key": "BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS", "label": "alpha with depth pre-pass"}
		],
		"default": "BaseMaterial3D.TRANSPARENCY_DISABLED",
		# The companion property, written on the same row: it decides where scissor cuts, and it is
		# meaningless in every other mode - which the row's help says rather than the row hiding it.
		"companion": {
			"property": "alpha_scissor_threshold",
			"param": "threshold",
			# Godot registers this property only while scissor is chosen, so ClassDB has no default
			# to hand back for it and the engine's own is written down here instead - the one place
			# in this table a value is not asked for.
			"default": "0.5",
			"label": "Scissor threshold",
			"about": "Where alpha scissor cuts: a pixel more see-through than this is not drawn at all. Only alpha scissor reads it."
		},
		"spellings": {"transparency": "Transparency"}
	},
	{
		"word": "sides",
		"kind": KIND_CHOICE,
		"name": "Set Sides",
		"verb": "Set sides to {value}",
		"reads": "sides",
		"label": "Sides",
		"about": "Which faces of the surface are drawn. Both is what a flat leaf, a curtain or a single-sided wall wants; it costs twice the drawing.",
		"choices": [
			{"key": "BaseMaterial3D.CULL_BACK", "label": "front"},
			{"key": "BaseMaterial3D.CULL_FRONT", "label": "back"},
			{"key": "BaseMaterial3D.CULL_DISABLED", "label": "both"}
		],
		"default": "BaseMaterial3D.CULL_BACK",
		"spellings": {"cull_mode": "Sides"}
	}
]

## Per class, `property -> true`, filled the first time a class is asked about. ClassDB answers the
## same thing for the life of the process, and this is asked once per word on every descriptor build.
static var _properties: Dictionary = {}


## The property the material class answers a word with, or "" when it has none of that word's
## spellings. Derived: the word says which spellings are possible, ClassDB says which of them the
## class actually has.
static func property_of(word: String) -> String:
	var entry: Dictionary = word_entry(word)
	if entry.is_empty():
		return ""
	for property: String in (entry["spellings"] as Dictionary).keys():
		if has_property(MATERIAL_ROOT, property):
			return property
	return ""


## True when a class really carries a property, inherited ones included. The one question the whole
## word map is derived from.
static func has_property(class_text: String, property: String) -> bool:
	if not _properties.has(class_text):
		var names: Dictionary = {}
		for described: Dictionary in ClassDB.class_get_property_list(class_text, false):
			names[str(described.get("name", ""))] = true
		_properties[class_text] = names
	return bool((_properties[class_text] as Dictionary).get(property, false))


## The word entry by its word, or {}.
static func word_entry(word: String) -> Dictionary:
	for entry: Dictionary in WORDS:
		if str(entry["word"]) == word:
			return entry
	return {}


## The frozen ace_id stem for one word, or "" when the material class answers none of its spellings.
static func id_stem(word: String) -> String:
	var entry: Dictionary = word_entry(word)
	var property: String = property_of(word)
	if entry.is_empty() or property.is_empty():
		return ""
	return str((entry["spellings"] as Dictionary).get(property, ""))


## The member path a row WRITES for one word - the property itself, or the channel of it the word
## really means (see-through is the alpha of the colour).
static func member_of(word: String) -> String:
	var entry: Dictionary = word_entry(word)
	var property: String = property_of(word)
	if property.is_empty():
		return ""
	return str(entry.get("member", property)).replace(":", ".") if entry.has("member") else property


## The path a TWEEN walks for one word. Godot's own spelling, in which a channel of a property is
## reached with a colon rather than a dot.
static func tween_path_of(word: String) -> String:
	var entry: Dictionary = word_entry(word)
	return str(entry.get("tween_path", property_of(word)))


## The value a row starts on: the word's own when it names one (a channel of a colour has no default
## of its own to ask for), and otherwise the ENGINE's default for the property, asked of ClassDB
## through the factory so a dropped row opens where Godot opens it.
static func default_of(word: String) -> String:
	var entry: Dictionary = word_entry(word)
	if entry.has("default"):
		return str(entry["default"])
	var property: String = property_of(word)
	return "" if property.is_empty() else EventForgeACEFactory.default_literal(MATERIAL_CLASS, property)


## Every word this vocabulary really resolves, in table order - the one list the rows, the lift and
## the tests all walk, so none of them can drift from the others.
static func words() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for entry: Dictionary in WORDS:
		if not property_of(str(entry["word"])).is_empty():
			found.append(str(entry["word"]))
	return found


## Every property a word of this vocabulary resolves to, for a prefilter that must never drift from
## the table it guards.
static func properties() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for word: String in words():
		var property: String = property_of(word)
		if not found.has(property):
			found.append(property)
	return found


## True when a class is one these rows speak for - a mesh instance, or a project's own subclass of
## one. Asked through ClassDB rather than against a list, so a subclass resolves too.
static func is_mesh_class(class_text: String) -> bool:
	var text: String = class_text.strip_edges()
	return not text.is_empty() and ClassDB.class_exists(text) and ClassDB.is_parent_class(text, HOST)
