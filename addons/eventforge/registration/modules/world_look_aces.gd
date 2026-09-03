# EventForge module - LOOKS: a whole world's appearance, saved as a file and put on in one row.
#
# The environment words beside these say one thing each - how colourful, how thick the fog is, what
# colour the sky is at the top. A LOOK says all of them at once: it is an Environment resource
# somebody built in the Inspector and saved, and these rows put one on, cross over to one, and answer
# which one is being worn.
#
# NOTHING HERE IS A STYLE, and that is deliberate. No look ships with this plugin and none is named
# in it. A look is a `.tres` in the project, made the ordinary Godot way - open a WorldEnvironment,
# set the world the way you want it, save the Environment out - and these rows take the path to it.
# The vocabulary supplies the verbs; the looks are entirely the project's own.
#
# NEITHER ARTIST FILE IS TOUCHED. Both rows load the file, take a DEEP copy of it, and put the copy
# on the node - so the look on disk is exactly as it was saved, and the world being worn belongs to
# this scene. A node already wearing an environment that came from a file is given its own copy of
# that too before anything walks it, which is the same courtesy every other environment row pays.
#
# WHAT A CROSSFADE REALLY IS. Half of an Environment is numbers, vectors and colours, and those can
# be walked: the fog thins, the saturation drains, the sky goes orange. The other half is switches
# and modes - glow on or off, which tone map, which sky - and there is nothing between two of those
# to walk through. So the numbers are tweened over the seconds asked for and the rest is CUT at the
# halfway point, where a cut is least visible. The row says so in its own words rather than pretending
# the whole world dissolves.
#
# THE WORK ITSELF IS A REAL FILE a debugger can step into: `WorldLook` under the runtime folder, plain
# typed GDScript with no plugin class named anywhere in it, exactly like the placement helper the
# spawn rows call. A compiled game carries it the way it carries any other script.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility covenant).
@tool
class_name EventForgeWorldLookACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The picker category every row here is filed under - the same shelf the environment words sit on,
## so the world's look is one section of the vocabulary rather than two.
const CAT := "Environment"

## The runtime helper the rows call, named once. Frozen with the templates that spell it.
const LOOK_CALL: String = "WorldLook"

## The signal a finished blend raises. A plain signal the sheet declares for itself, which is why it
## is a name here and not a mechanism: the blend raises it and On World Look Blended connects to it.
const BLENDED_SIGNAL: String = "world_look_blended"

## The node a look row starts on - the one node in a scene that exists to hold a world.
const DEFAULT_NODE: String = "$WorldEnvironment"

## How long a crossfade takes when nobody says. Longer than the half second a single dial fades over,
## because a whole world changing wants to be noticed rather than glimpsed.
const DEFAULT_SECONDS: String = "1.0"

## The field a look is picked in - a file field over the project's own resources, rather than an
## expression box a path has to be typed into by hand.
const RESOURCE_HINT: String = "resource_path"


static func get_descriptors() -> Array[ACEDescriptor]:
	return [
		F.act("WorldUseLook", "Use World Look", "%s.use({node}, {look})" % LOOK_CALL, CAT,
			"Use world look {look}",
			"Puts a whole saved world on at once - the fog, the glow, the sky, the colour grading and everything else that lives on an Environment - from a file in the project. The file is deep-copied first, so the look on disk is left exactly as it was saved and the world this scene is wearing is this scene's own: turning the fog up afterwards changes nothing anywhere else. Make a look the ordinary Godot way, by setting a WorldEnvironment up the way you want it and saving its Environment out; nothing is shipped for you.",
			"").param_built(_node_param()).param_built(_look_param(
			"The look to put on, as an Environment file in the project.")).featured(),
		F.act("WorldBlendToLook", "Blend To World Look",
			"%s.blend({node}, {look}, {seconds})" % LOOK_CALL, CAT,
			"Blend to world look {look} over {seconds} s",
			"Crosses over to a saved world instead of cutting to it. Every number, vector and colour an Environment holds - fog thickness, saturation, exposure, the sky's colours - is walked from where it is now to where the look has it over the seconds asked for. Everything that is a switch or a mode - glow on or off, which tone map, which sky - has nothing in between to walk through, so it is cut all at once at the HALFWAY point, where a cut is least visible. When the walk lands, this node's world_look_blended signal is raised with the look it landed on, which On World Look Blended listens to.",
			"").param_built(_node_param()).param_built(_look_param(
			"The look to cross over to, as an Environment file in the project.")).param_typed(
			"String", "seconds", DEFAULT_SECONDS, "Seconds",
			"How long the crossfade takes. The switches and modes are cut at half of it.",
			"expression").featured(),
		F.expr("WorldCurrentLook", "Current World Look", "%s.came_from({node})" % LOOK_CALL, CAT,
			"the world look being worn",
			"The path of the look file this node's world came from, or blank when it is wearing a world nobody named - one built in the scene rather than loaded. Reads what the last Use World Look or Blend To World Look wrote down, which is the only place the answer can come from: the copy a row put on is a copy, and a copy has no file of its own.",
			"").param_built(_node_param()),
		F.trig("OnWorldLookBlended", "On World Look Blended", BLENDED_SIGNAL, CAT,
			"On the world look landing",
			"Runs when a Blend To World Look row finished crossing over, and hands over the look it landed on. The signal is one this sheet declares for itself - add a signal block saying world_look_blended(look) and both halves are ordinary Godot - so the moment the world finished changing becomes something the game can answer: start the scene, let the player move, play the next line.",
			"Node")
	]


## The node every look row acts on. A parameter rather than a host, because the two nodes that can
## wear a world spell the slot the same way and neither of them is more the owner of a look than the
## other: a WorldEnvironment holds the world the whole scene sees, and a Camera3D can hold one of its
## own that only its own view sees.
static func _node_param() -> ACEParam:
	return F.make_param("node", "String", DEFAULT_NODE, "On node",
		"The node wearing the world: a WorldEnvironment, or a Camera3D with an environment of its own.",
		"expression")


## The look file itself. A file field over the project's own resources rather than a box a path is
## typed into, so a reader picks the look they made instead of spelling its path.
static func _look_param(description: String) -> ACEParam:
	return F.make_param("look", "String", "\"\"", "Look", description, RESOURCE_HINT)
