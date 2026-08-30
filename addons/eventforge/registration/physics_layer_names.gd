# EventForge - the project's own names for its physics layers.
#
# Godot keeps two lists of layer names in Project Settings - `layer_names/2d_physics/layer_1` and
# its 3D twin - and every collision knob in the engine addresses a layer by its NUMBER. A person
# addresses it by the name they gave it, which is the whole reason they gave it one. This is the
# one place that turns a number into that name and a name back into that number, so the picker, the
# row's sentence, the lift and the Doctor all read one list rather than four copies of the same
# `ProjectSettings.get_setting` call drifting apart.
#
# READ LIVE, NEVER CACHED. A layer renamed in Project Settings a minute ago must read by its new
# name without an editor restart, and the read is one setting lookup - cheaper than the cache
# invalidation it would need. It also means nothing here can leak project state between two tests
# in one process.
#
# NOTHING HERE IS EMITTED. Emitted code carries the NUMBER, because that is what the engine's own
# `set_collision_mask_value` takes and the names live in project.godot where Godot keeps them. A
# name is a reading, and a reading of a layer the project never named is that layer's number - which
# is all anyone could honestly call it.
@tool
class_name EventForgePhysicsLayers
extends RefCounted

## The two physics lists, spelled as Project Settings spells them. The render list beside them is
## the same shape and is named here so a caller never has to write the raw path either.
const DIMENSION_2D := "2d_physics"
const DIMENSION_3D := "3d_physics"
const DIMENSION_RENDER_2D := "2d_render"

## Godot's own limit: a collision layer is one bit of a 32-bit mask, numbered 1 to 32 on every
## surface the engine shows.
const FIRST_LAYER := 1
const LAST_LAYER := 32

## How many layers a picker offers before the project has said anything about them. Layers past the
## eighth only appear once they are named (or once a row already points at one) - thirty-two
## anonymous entries would bury the ones that matter.
const UNNAMED_SHOWN := 8


## The Project Settings path one layer's name lives at.
static func setting_path(layer_number: int, dimension: String) -> String:
	return "layer_names/%s/layer_%d" % [dimension, layer_number]


## True when a number is one Godot would accept as a layer.
static func is_layer_number(layer_number: int) -> bool:
	return layer_number >= FIRST_LAYER and layer_number <= LAST_LAYER


## The project's name for one layer, or "" when the project never named it (and for a number that is
## not a layer at all).
static func name_of(layer_number: int, dimension: String) -> String:
	if not is_layer_number(layer_number):
		return ""
	return str(ProjectSettings.get_setting(setting_path(layer_number, dimension), "")).strip_edges()


## One layer as a SENTENCE says it: the project's name for it, or the bare number when the project
## never named it. The honest reading - a row pointing at layer 5 of a project that named nothing
## says "5", because inventing a name would be a guess about somebody else's setup.
static func words_for(layer_number: int, dimension: String) -> String:
	var named: String = name_of(layer_number, dimension)
	return named if not named.is_empty() else str(layer_number)


## The same reading taken off the value a ROW carries, which is GDScript text rather than an int. A
## value that is not a plain whole number is an expression the author wrote (a variable, a call that
## works one out), and it comes back untouched: a name for it would be a guess this cannot make.
static func words_for_value(value: String, dimension: String) -> String:
	var text: String = value.strip_edges()
	if not text.is_valid_int():
		return value
	var number: int = text.to_int()
	if not is_layer_number(number):
		return value
	return words_for(number, dimension)


## The number the project gave one NAME, or 0 when no layer of this dimension carries it. Case is
## respected: these are the author's own words, spelled the way they spelled them.
static func number_of(layer_name: String, dimension: String) -> int:
	var wanted: String = layer_name.strip_edges()
	if wanted.is_empty():
		return 0
	for number: int in range(FIRST_LAYER, LAST_LAYER + 1):
		if name_of(number, dimension) == wanted:
			return number
	return 0


## Every layer the project NAMED, as {number, name}, lowest first. Empty for a project that never
## named one, which is the state a fresh project is in.
static func named_layers(dimension: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for number: int in range(FIRST_LAYER, LAST_LAYER + 1):
		var named: String = name_of(number, dimension)
		if not named.is_empty():
			found.append({"number": number, "name": named})
	return found


## True when the project has named ANY layer of this dimension. The question the Doctor asks before
## it says anything at all: a project that names no layers is not one that renamed one away.
static func names_any(dimension: String) -> bool:
	return not named_layers(dimension).is_empty()


## The layers a picker LISTS: the first eight always, every named one, and whichever one the row
## already points at (so a row on layer 20 of a project that stopped naming it can still be read and
## still be changed). Lowest first, each as {number, name, named}.
static func listed_layers(dimension: String, current: int = 0) -> Array[Dictionary]:
	var listed: Array[Dictionary] = []
	for number: int in range(FIRST_LAYER, LAST_LAYER + 1):
		var named: String = name_of(number, dimension)
		if number > UNNAMED_SHOWN and named.is_empty() and number != current:
			continue
		listed.append({"number": number, "name": named, "named": not named.is_empty()})
	return listed


## Which of the two lists a class's collision knobs read from. A 3D node names 3D layers; everything
## else reads the 2D names, which is what a 2D project wants and the honest answer for a class this
## cannot place.
static func dimension_for_class(class_text: String) -> String:
	var text: String = class_text.strip_edges()
	if text.is_empty():
		return DIMENSION_2D
	if ClassDB.class_exists(text) and ClassDB.is_parent_class(text, "Node3D"):
		return DIMENSION_3D
	return DIMENSION_3D if text.ends_with("3D") else DIMENSION_2D


## Writes a name onto a layer, and says whether the file took it. The ONE write in this file, called
## only from the explicit door that offers it - reading the layer names must never change them.
##
## Refuses to overwrite a name the project already has: renaming a layer moves every row pointing at
## it, which is a decision for Project Settings and not a side effect of authoring one row.
static func name_layer(layer_number: int, dimension: String, layer_name: String) -> bool:
	var clean: String = layer_name.strip_edges()
	if clean.is_empty() or not is_layer_number(layer_number):
		return false
	if not name_of(layer_number, dimension).is_empty():
		return false
	var path: String = setting_path(layer_number, dimension)
	ProjectSettings.set_setting(path, clean)
	ProjectSettings.set_initial_value(path, "")
	return ProjectSettings.save() == OK


## The receipt naming a layer leaves: the Project Settings line as it was, and as it now is. Not
## translated, and deliberately - both sides are lines of `project.godot` and the arrow between them
## is punctuation. The same shape every other door in this family says its write in, and it names the
## setting that was really written rather than restating the layer's number twice.
static func receipt(layer_number: int, dimension: String, layer_name: String) -> String:
	var path: String = setting_path(layer_number, dimension)
	return "%s = \"\" -> %s = \"%s\"" % [path, path, layer_name]


## Takes a name back off a layer - the undo half of the write above, so naming a layer from a row is
## one step a person can take back. Returns whether the file took it.
static func unname_layer(layer_number: int, dimension: String) -> bool:
	if not is_layer_number(layer_number):
		return false
	var path: String = setting_path(layer_number, dimension)
	ProjectSettings.set_setting(path, "")
	ProjectSettings.set_initial_value(path, "")
	return ProjectSettings.save() == OK
