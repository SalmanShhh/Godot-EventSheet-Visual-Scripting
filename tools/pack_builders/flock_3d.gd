# Pack builder - flock_3d (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Flock 3D: the Flock pack's twin for a Node3D, word for word, in metres instead of pixels. The
## host turns to look along its flight (Godot's forward, -Z) instead of rotating in the plane, and
## a member outside the scene tree reads its own position, so the arithmetic answers headless too.
##
## Every member runs its own small loop over the group, which is right for tens of members. The
## guide says where to go for hundreds: one script driving a MultiMeshInstance3D.
static func build() -> bool:
	var src: Lib.PackSource = Lib.pack_from_source("flock_3d", "Node3D", "Flock3DBehavior",
		"Flocking for a Node3D: every member of a group steers by the members around it - keep apart from the ones too close, fly the way the rest are flying, drift toward their middle - and flees anything in an avoid group. Weights, speeds, the steering force and both radii are Inspector values with a Set row each.",
		Lib.manifest().behavior().category("Flock 3D").tags(["movement", "steering", "group"]))
	src.note("Flock 3D behavior: attach it under every bird, fish or bat that should fly together. Each member looks at the members of its flock group inside the neighbour radius and blends three pushes: separation from the ones too close, alignment with the way they fly, cohesion toward their middle. An avoid group is fled on top. A CharacterBody3D host flies with move_and_slide; any other Node3D is moved along. The host turns to look the way it flies. This pack is an event sheet - extend it by editing it.")
	src.block("block_1")
	src.on_ready()
	src.on_physics_process()
	src.verb("set_flock_weights", "Set Flock Weights",
		"Sets how strongly the three rules pull: separation keeps members apart, alignment turns them the way their neighbours fly, cohesion draws them toward their neighbours' middle. Zero switches a rule off; a weight is relative to the other two.",
		[["separation", "float"], ["alignment", "float"], ["cohesion", "float"]])
	src.verb("set_flock_speeds", "Set Flock Speeds",
		"Sets the slowest and the fastest a member flies, in metres per second. A maximum below the minimum is raised to it, so the two can never cross.",
		[["minimum", "float"], ["maximum", "float"]])
	src.verb("set_max_force", "Set Max Force",
		"Sets how quickly a member may change its velocity, in metres per second per second, for each rule. Low turns in wide arcs; high turns on the spot.",
		[["force", "float"]])
	src.verb("set_flock_radii", "Set Flock Radii",
		"Sets how far a member looks for neighbours, and how close a neighbour may come before separation pushes it away. Make the second a little wider than the model and members never overlap.",
		[["neighbours", "float"], ["too_close", "float"]])
	src.verb("set_avoid_group", "Set Avoid Group",
		"Sets the group the flock flees - a predator, the player, a hazard - how close it must come before the flock reacts, and how strongly it flees. An empty group avoids nothing.",
		[["group", "StringName"], ["radius", "float"], ["weight", "float"]])
	src.verb("set_flock_group", "Set Flock Group",
		"Moves the host from its flock to another one in a single row: it leaves the old group and joins the new, so it is never counted by both.",
		[["group", "StringName"]])
	src.verb("set_flocking_enabled", "Set Flocking Enabled",
		"Turns the steering on or off at runtime. Off, the host keeps still and costs nothing per frame; on again, it flies off at the velocity it had.",
		[["enabled", "bool"]])
	Lib.verb_sentences(src.sheet, {
		"set_flock_weights": "flock with separation [b]{separation}[/b], alignment [b]{alignment}[/b], cohesion [b]{cohesion}[/b]",
		"set_flock_speeds": "fly between [b]{minimum}[/b] and [b]{maximum}[/b] m/s",
		"set_max_force": "steer with at most [b]{force}[/b] force",
		"set_flock_radii": "see neighbours within [b]{neighbours}[/b], keep [b]{too_close}[/b] apart",
		"set_avoid_group": "flee [b]{group}[/b] within [b]{radius}[/b], weight [b]{weight}[/b]",
		"set_flock_group": "fly with the [b]{group}[/b] flock",
		"set_flocking_enabled": "Set flocking to [b]{enabled}[/b]",
	})
	Lib.feature_verbs(src.sheet, ["set_flock_weights", "set_avoid_group"])
	return Lib.publish(src, "res://eventsheet_addons/flock_3d/flock_3d_behavior")
