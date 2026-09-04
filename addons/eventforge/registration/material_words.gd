# EventForge - the MATERIAL WORDS: nine things a game touches on a surface, and the property each one
# really is.
#
# A mesh's LOOK is one resource with a hundred properties on it, and the nine below are the ones a
# game reaches for at run time: what colour it is, how hard it glows, how rough and how metal it
# looks, how solid its surface is, what picture is painted on it, how it blends with what is behind
# it, how it handles transparency, and which of its two sides are drawn. Godot keeps every one of them on
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
# goblin the player hit recolours all twelve of them. So every write below is preceded by the lines
# that give this mesh its own copy first - a duplicate of whatever it is drawing with now, parked on
# `material_override`, where it shadows the shared one for this node and no other.
#
# THE GUARD ASKS TWO QUESTIONS, and it has to. An empty `material_override` is a mesh drawing with
# the mesh resource's own surface material, so the copy is taken from `get_active_material`. A
# FILLED `material_override` is not proof the mesh owns anything: the commonest way a material is
# assigned at all is by dropping a shared `.tres` into that very slot in the Inspector, and a rule
# that read "has an override" as "owns one" would write and tween the shared file - all twelve
# goblins again, which is the exact failure this courtesy exists to prevent. So the second question
# is the one every other table here asks: an override still carrying a `resource_path` came from a
# file and is copied. A copy taken once has no path, so a row running every frame takes one copy and
# not sixty, and a mesh whose override was cleared by some later row is given a fresh one rather
# than writing through a null.
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

## THE LINES every write is preceded by - the own-it courtesy, spelled once, asking TWO questions.
## A mesh drawing with nothing of its own is given a copy of whatever it IS drawing with, or a plain
## material when it is drawing with nothing at all. A mesh already wearing an override is given a
## copy of that one when it came from a file, because dropping a shared `.tres` into that very slot
## in the Inspector is the commonest way a material is assigned. A copy taken once has no
## `resource_path`, so a row running every frame takes one copy and not sixty.
const OWN_LINES: String = "if %s == null:\n\t%s = %s(0).duplicate() if %s(0) != null else %s.new()\nelif not %s.resource_path.is_empty():\n\t%s = %s.duplicate()\n" % [
	OVERRIDE_MEMBER, OVERRIDE_MEMBER, ACTIVE_CALL, ACTIVE_CALL, FALLBACK_MATERIAL,
	OVERRIDE_MEMBER, OVERRIDE_MEMBER, OVERRIDE_MEMBER]

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
		# NOT "see-through", which the Native 3D shelf has already published for years as
		# `GeometryInstance3D.transparency` - one node, two rows, and the two scales run OPPOSITE
		# ways (that row's 0 is solid, this one's 1 is), so a name shared between them would have
		# handed a reader the opposite of what they meant about half the time. This is the
		# MATERIAL's own alpha, which is a different thing worth having: it copies the material,
		# switches it into alpha transparency and can be tweened, where the frozen row is a
		# per-instance fade that needs none of that. The ace_id stem stays `SeeThrough` because an
		# ace_id is a promise; only the words a reader sees moved.
		"word": "surface opacity",
		"kind": KIND_VALUE,
		"name": "Set Surface Opacity",
		"verb": "Set surface opacity to {value}",
		"reads": "surface opacity",
		"label": "Surface opacity",
		"about": "How solid the SURFACE is: 1 is solid, 0 is invisible. Godot keeps it as the colour's alpha channel, which does nothing until the material is in alpha transparency - so the row switches that on as well. The Native 3D shelf's Set See-Through fades the whole object without touching its material, and counts the other way round.",
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

## 2D IS A DIFFERENT SURFACE, and these are its two words. A sprite's look is a CanvasItemMaterial
## with two knobs on it - how it mixes with what is behind it, and whether the lights reach it - and
## neither of them is a BaseMaterial3D property, so they are their own small table rather than two
## more spellings in the one above.
##
## The node class they are hosted on, the material class they resolve against, and the class a
## sprite drawing with nothing at all is given.
const SPRITE_HOST: String = "CanvasItem"
const SPRITE_MATERIAL_CLASS: String = "CanvasItemMaterial"

## The member a sprite's material is worn on - the one every 2D effect row already spells.
const SPRITE_MEMBER: String = "material"

## THE SPRITE WORDS. The same entry shape as the table above (word, kind, name, verb, choices, the
## frozen id stem), so one set of builders reads both. Both are CHOICE words: there is no number to
## walk and no colour to pick, only one of a fixed list of engine constants.
const SPRITE_WORDS: Array[Dictionary] = [
	{
		"word": "blending",
		"kind": KIND_CHOICE,
		"name": "Set Blending",
		"verb": "Set blending to {value}",
		"reads": "blending",
		"read_name": "Blending",
		"label": "Blending",
		"id_stem": "SetBlending",
		"read_stem": "Blending",
		"about": "How the sprite is mixed with whatever is already drawn behind it. Add is what fire, sparks and light shafts want; multiply is what a shadow or a stain wants.",
		"featured": true,
		"property": "blend_mode",
		"choices": [
			{"key": "CanvasItemMaterial.BLEND_MODE_MIX", "label": "mix"},
			{"key": "CanvasItemMaterial.BLEND_MODE_ADD", "label": "add"},
			{"key": "CanvasItemMaterial.BLEND_MODE_SUB", "label": "subtract"},
			{"key": "CanvasItemMaterial.BLEND_MODE_MUL", "label": "multiply"},
			{"key": "CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA", "label": "premultiplied alpha"}
		],
		"default": "CanvasItemMaterial.BLEND_MODE_MIX"
	},
	{
		"word": "light response",
		"kind": KIND_CHOICE,
		"name": "Set Light Response",
		"verb": "Set light response to {value}",
		"reads": "light response",
		"read_name": "Light Response",
		"label": "Light response",
		"id_stem": "SetLightResponse",
		"read_stem": "LightResponse",
		"about": "How the 2D lights reach the sprite. Unshaded keeps it at full brightness whatever the lights do, which is what a HUD piece and a lit window want; light only draws it where a light falls and nowhere else.",
		"property": "light_mode",
		"choices": [
			{"key": "CanvasItemMaterial.LIGHT_MODE_NORMAL", "label": "normal"},
			{"key": "CanvasItemMaterial.LIGHT_MODE_UNSHADED", "label": "unshaded"},
			{"key": "CanvasItemMaterial.LIGHT_MODE_LIGHT_ONLY", "label": "light only"}
		],
		"default": "CanvasItemMaterial.LIGHT_MODE_NORMAL"
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


## The own-it courtesy for ONE SURFACE SLOT rather than for the whole mesh. A mesh with several
## surfaces has a material per slot, and the whole-mesh override would paint over all of them - so a
## row that means one slot owns that slot instead. `slot` is the token the row names the surface
## with, spliced in wherever the guard, the copy and the write each ask about that same slot.
static func own_surface_lines(slot: String) -> String:
	return "if %s(%s) == null:\n\t%s(%s, %s(%s).duplicate() if %s(%s) != null else %s.new())\nelif not %s(%s).resource_path.is_empty():\n\t%s(%s, %s(%s).duplicate())\n" % [
		SURFACE_OVERRIDE_GET, slot, SURFACE_OVERRIDE_SET, slot, ACTIVE_CALL, slot, ACTIVE_CALL,
		slot, FALLBACK_MATERIAL, SURFACE_OVERRIDE_GET, slot, SURFACE_OVERRIDE_SET, slot,
		SURFACE_OVERRIDE_GET, slot]


## THE OWN-IT COURTESY FOR A SPRITE, and the one line of it that is not a courtesy at all. A sprite
## drawing with nothing is given a plain CanvasItemMaterial, because there is nothing to copy; one
## drawing with a material that carries a `resource_path` is given a copy of it, so a `.tres` worn by
## every coin in the level never changes under the other coins. That covers the material a scene
## keeps INSIDE itself too: an embedded sub-resource carries a path of its own
## (`res://coin.tscn::CanvasItemMaterial_p3f1c`), and every instance of that scene is wearing the one
## the scene file holds - so copying it once is right rather than over-careful. A copy taken once has
## no path at all, which is what makes a row that runs every frame take one copy and not sixty.
##
## THE SHADER IS NOT TOUCHED, here or in the write that follows. A sprite wearing a ShaderMaterial
## is wearing somebody's shader, and blend and light live inside that shader rather than on a
## property this could set - so these rows set nothing at all on one, and the Doctor says so quietly
## rather than a row failing silently.
const SPRITE_OWN_LINES: String = "if %s == null:\n\t%s = %s.new()\nelif %s is %s and not %s.resource_path.is_empty():\n\t%s = %s.duplicate()\n" % [
	SPRITE_MEMBER, SPRITE_MEMBER, SPRITE_MATERIAL_CLASS, SPRITE_MEMBER, SPRITE_MATERIAL_CLASS,
	SPRITE_MEMBER, SPRITE_MEMBER, SPRITE_MEMBER]


## The sprite word entry by its word, or {}.
static func sprite_word_entry(word: String) -> Dictionary:
	for entry: Dictionary in SPRITE_WORDS:
		if str(entry["word"]) == word:
			return entry
	return {}


## Every sprite word the material class really answers, in table order. Derived the same way the 3D
## words are: the table says what the property would be, ClassDB says whether it is there.
static func sprite_words() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for entry: Dictionary in SPRITE_WORDS:
		if has_property(SPRITE_MATERIAL_CLASS, str(entry["property"])):
			found.append(str(entry["word"]))
	return found


## True when a class is one the sprite rows speak for - any CanvasItem, which is every sprite, every
## Control and every TileMapLayer. Asked through ClassDB rather than against a list.
static func is_sprite_class(class_text: String) -> bool:
	var text: String = class_text.strip_edges()
	return not text.is_empty() and ClassDB.class_exists(text) \
		and ClassDB.is_parent_class(text, SPRITE_HOST)


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


## THE TABLE READ BACKWARDS: the word a member path IS, or "" for a path no word here means. What
## turns a hand-written `material_override.albedo_color = red` back into the sentence the picker
## would have made - the same job the light words do for `energy`, and the reason both tables say
## what they mean rather than only how to write it.
##
## The FULL PATH is asked first and the bare property second, because one property is two words: the
## colour is `albedo_color` and see-through is the alpha channel of it, and a line writing
## `albedo_color.a` means the second one. Asking the other way round would call every see-through
## line a colour.
static func word_of_member(member_path: String) -> String:
	var wanted: String = member_path.strip_edges()
	if wanted.is_empty():
		return ""
	for word: String in words():
		if member_of(word) == wanted:
			return word
	if not wanted.contains("."):
		return ""
	var bare: String = wanted.get_slice(".", 0)
	for word: String in words():
		if member_of(word) == bare:
			return word
	return ""


## THE DROPDOWN WORD a written constant IS - "add" for `BaseMaterial3D.BLEND_MODE_ADD` - or "" for a
## word that is not a choice word and for a constant none of its choices name. What lets a
## hand-written `material_override.blend_mode = BaseMaterial3D.BLEND_MODE_ADD` read back as the plain
## word the picker would have shown, rather than as the constant Godot spells it with.
##
## Asked by WORD rather than by property, because one property here is two words (the colour and its
## alpha channel), so the reading resolves the member to a word before it asks. The bare tail is
## compared as well as the whole spelling, so a line that wrote the constant unqualified resolves too.
static func choice_label(word: String, value: String) -> String:
	var entry: Dictionary = word_entry(word)
	if entry.is_empty() or str(entry["kind"]) != KIND_CHOICE:
		return ""
	var wanted: String = value.strip_edges()
	var bare: String = wanted.substr(wanted.rfind(".") + 1)
	for choice: Variant in (entry["choices"] as Array):
		var option: Dictionary = choice
		var key: String = str(option["key"])
		if key == wanted or key.substr(key.rfind(".") + 1) == bare:
			return str(option["label"])
	return ""


## True when a class is one these rows speak for - a mesh instance, or a project's own subclass of
## one. Asked through ClassDB rather than against a list, so a subclass resolves too.
static func is_mesh_class(class_text: String) -> bool:
	var text: String = class_text.strip_edges()
	return not text.is_empty() and ClassDB.class_exists(text) and ClassDB.is_parent_class(text, HOST)
