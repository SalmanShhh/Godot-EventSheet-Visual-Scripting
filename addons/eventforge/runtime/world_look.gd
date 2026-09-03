# EventForge runtime - a whole world's look, swapped or crossed over, from a file the project owns.
#
# The other environment words are one property each, because each of them is one measurement: how
# colourful, how thick the fog is, what colour the sky is at the top. A LOOK is not one measurement -
# it is every one of them at once, saved as an Environment file somebody made in the Inspector - so
# it is the one environment word that is a function rather than a line, and this is that function.
#
# NOTHING HERE IS A STYLE. No look ships with the plugin and none is named in it: a look is an
# ordinary `.tres` a person saved out of their own scene, and these two calls put one on and take one
# off. What the file holds is entirely theirs.
#
# THE OWN-IT COURTESY IS THE WHOLE POINT. An Environment is a FILE, and a node pointing at one points
# at the SAME object every other scene loading it points at. So a look is never worn directly: the
# file is loaded, deep-copied, and the COPY is what the node wears. Turning the fog up afterwards
# turns it up on the copy, and the artist's file on disk is exactly as they left it - which is what
# lets the same look be worn by four scenes at once and edited from any of them.
#
# WHAT A BLEND DOES, in the order it does it:
#   crossed     every property of an Environment that is a NUMBER, a vector or a colour is walked
#               from where it is now to where the wanted look has it, over the seconds asked for.
#               That is the fog thinning, the saturation draining, the sky going orange.
#   cut         every property that is not - a switch, a mode, a sky, a colour-grade picture - is
#               written all at once at the HALFWAY point, because there is nothing between "glow on"
#               and "glow off" to walk through and the middle of the crossfade is where a cut is
#               least visible.
#   said        when the walk lands, the node's own `world_look_blended` signal is raised with the
#               look it landed on, so a sheet can run the next thing when the world finished
#               changing. A plain signal a sheet declares for itself, like any other.
#
# AND IT DOES NOTHING WHEN THERE IS NOTHING TO DO. A path that names no file, a file that is not an
# Environment, a node with no `environment` slot at all: each of those is answered by doing nothing
# rather than by erroring, because a look is a piece of dressing and a missing one must never take a
# game down.
#
# PLAIN GDSCRIPT, NO PLUGIN. Nothing here touches the editor, the sheet format or any EventForge
# class, so a generated game carries this file the way it carries any other runtime script.
class_name WorldLook
extends RefCounted

## Where the path a worn look came from is remembered. A copy has no `resource_path` of its own -
## that is what makes it a copy - so the file it came from is written down beside it, on the node.
const LOOK_META: StringName = &"eventforge_world_look"

## The signal a finished blend raises on the node it was asked of. A plain signal the sheet declares
## for itself (`signal world_look_blended(look)`), which is why this is a name and not a mechanism.
const BLENDED_SIGNAL: StringName = &"world_look_blended"

## The property types a blend can walk THROUGH rather than cut TO. Everything else - switches, modes,
## the sky, a colour-grade picture - has nothing in between, so it is cut at the halfway point.
const CROSSED_TYPES: Array[int] = [TYPE_FLOAT, TYPE_VECTOR2, TYPE_VECTOR3, TYPE_COLOR]

## The class the two calls read their property list from, so a look holds exactly what an Environment
## holds and nothing else is copied across.
const ENVIRONMENT_CLASS: StringName = &"Environment"

## The class whose own properties are NOT part of a look. A resource's name, its path and whether it
## is local to the scene say where a file lives rather than what a world looks like, and carrying them
## across would hand this scene the artist file's identity along with its appearance.
const IDENTITY_CLASS: StringName = &"Resource"


## Puts a look on, at once. `host` is any node with an `environment` slot - a WorldEnvironment, or a
## Camera3D wearing an environment of its own. The file is deep-copied first, so the copy the node
## wears is the node's and the artist's file is never touched.
static func use(host: Node, look_path: String) -> void:
	var wanted: Environment = _own_copy_of(look_path)
	if not _can_wear(host) or wanted == null:
		return
	host.set("environment", wanted)
	host.set_meta(LOOK_META, look_path)


## Crosses over to a look: every number, vector and colour walked there over `seconds`, everything
## else cut at the halfway point, and the node's `world_look_blended` signal raised with the look
## when the walk lands. A blend of no time at all is the same thing as putting the look on.
static func blend(host: Node, look_path: String, seconds: float) -> void:
	var wanted: Environment = _own_copy_of(look_path)
	if not _can_wear(host) or wanted == null:
		return
	if seconds <= 0.0 or not host.is_inside_tree():
		use(host, look_path)
		_say_it_landed(host, look_path)
		return
	var live: Environment = _worn_by(host)
	if live == null:
		return
	var tween: Tween = host.create_tween()
	tween.set_parallel(true)
	for property: String in crossed_properties(wanted):
		tween.tween_property(live, NodePath(property), wanted.get(property), seconds)
	tween.tween_callback(apply_cut.bind(live, cut_values(wanted))).set_delay(seconds * 0.5)
	tween.tween_callback(_landed_on.bind(host, look_path)).set_delay(seconds)


## The file the look a node is wearing came from, or "" when it is wearing one nobody named - a world
## built in the scene rather than loaded, or none at all. What the Current Look expression reads.
static func came_from(host: Node) -> String:
	if not _can_wear(host):
		return ""
	if host.has_meta(LOOK_META):
		return str(host.get_meta(LOOK_META))
	var worn: Variant = host.get("environment")
	return str((worn as Environment).resource_path) if worn is Environment else ""


## Every property of an Environment a look carries across - the ones walked through and the ones cut
## to alike, in the engine's own order. Derived from ClassDB rather than listed, so a property the
## engine adds is carried without a line changing here; the grouped ones the editor shows as
## `glow_levels/1` are left out, because a slash is not a property path a tween or a `set` can follow.
static func carried_properties() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var identity: Dictionary = {}
	for described: Dictionary in ClassDB.class_get_property_list(IDENTITY_CLASS, true):
		identity[str(described.get("name", ""))] = true
	for described: Dictionary in ClassDB.class_get_property_list(ENVIRONMENT_CLASS, false):
		var name_text: String = str(described.get("name", ""))
		var usage: int = int(described.get("usage", 0))
		if name_text.is_empty() or name_text.contains("/") or identity.has(name_text):
			continue
		if usage & PROPERTY_USAGE_STORAGE == 0:
			continue
		found.append(name_text)
	return found


## The properties a blend WALKS to their new value: the numbers, the vectors and the colours, which
## are the half of a world that has something in between two settings of it. In the engine's own
## order, so two runs of the same blend walk the same list.
static func crossed_properties(wanted: Environment) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if wanted == null:
		return found
	for property: String in carried_properties():
		if CROSSED_TYPES.has(typeof(wanted.get(property))):
			found.append(property)
	return found


## The properties a blend CUTS to, with the values it cuts them to: the switches, the modes, the sky
## and the pictures - the half of a world with nothing in between two settings of it. Written all at
## once at the halfway point, where a cut is least visible.
static func cut_values(wanted: Environment) -> Dictionary:
	var found: Dictionary = {}
	if wanted == null:
		return found
	for property: String in carried_properties():
		var target: Variant = wanted.get(property)
		if not CROSSED_TYPES.has(typeof(target)):
			found[property] = target
	return found


## The halfway cut itself: everything a blend cannot walk through, written at once - and the walked
## half put back exactly as it was found.
##
## THE PUT-BACK IS NOT TIDINESS, it is the whole reason this is a function. Some of Godot's own mode
## setters move a number as a side effect: writing `fog_mode` writes a fog density to go with it, so a
## cut landing in the middle of a fade would jerk the fog to the new mode's default for one frame
## before the walk carried it on again. So the walked half is read before the cut and written back
## after it, and a crossfade stays a crossfade.
static func apply_cut(live: Environment, cut: Dictionary) -> void:
	if live == null:
		return
	var walking: Dictionary = {}
	for property: String in crossed_properties(live):
		walking[property] = live.get(property)
	for property: String in cut.keys():
		live.set(property, cut[property])
	for property: String in walking.keys():
		live.set(property, walking[property])


## A private, deep copy of the look at a path, or null when the path names no Environment. Deep,
## because an Environment holds a Sky which holds a sky material, and a shallow copy would hand the
## node the artist's own sub-resources to write through.
static func _own_copy_of(look_path: String) -> Environment:
	var wanted: String = look_path.strip_edges()
	if wanted.is_empty() or not ResourceLoader.exists(wanted):
		return null
	var loaded: Resource = load(wanted)
	return (loaded as Environment).duplicate(true) if loaded is Environment else null


## True when a node can wear a look at all - anything with an `environment` slot on it.
static func _can_wear(host: Node) -> bool:
	if host == null or not is_instance_valid(host):
		return false
	for described: Dictionary in host.get_property_list():
		if str(described.get("name", "")) == "environment":
			return true
	return false


## The environment a node is wearing, made its own first: a node holding nothing is given a plain
## one, and a node holding a FILE is given its own copy of it, so a blend never walks a shared world
## out from under the other scenes that loaded it.
static func _worn_by(host: Node) -> Environment:
	var worn: Variant = host.get("environment")
	if not (worn is Environment):
		var fresh: Environment = Environment.new()
		host.set("environment", fresh)
		return fresh
	var live: Environment = worn
	if not live.resource_path.is_empty():
		live = live.duplicate(true)
		host.set("environment", live)
	return live


## The end of a blend: the look written down as the one this node came to wear, and then said out
## loud.
static func _landed_on(host: Node, look_path: String) -> void:
	if host == null or not is_instance_valid(host):
		return
	host.set_meta(LOOK_META, look_path)
	_say_it_landed(host, look_path)


## The signal, raised only when the sheet declared it. A node that never asked to hear about blends
## simply does not, which is what keeps this a plain signal rather than machinery.
static func _say_it_landed(host: Node, look_path: String) -> void:
	if host != null and is_instance_valid(host) and host.has_signal(BLENDED_SIGNAL):
		host.emit_signal(BLENDED_SIGNAL, look_path)
