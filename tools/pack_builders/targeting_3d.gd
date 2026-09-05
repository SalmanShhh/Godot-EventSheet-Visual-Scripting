# Pack builder - targeting_3d (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Targeting 3D: the Targeting pack's twin for a Node3D, word for word, with the two things only
## 3D has - the cone is measured around the CAMERA's forward rather than the host's rotation,
## because a third-person game locks on to what is on screen, and Snap On Aim Down Sights turns
## the host onto the nearest target the moment the player raises the sights.
##
## Like its twin it reads Engine's "aim_assist_radius" meta, the one the shipped accessibility
## rows write, so one options slider governs the assist in both dimensions.
static func build() -> bool:
	var src: Lib.PackSource = Lib.pack_from_source("targeting_3d", "Node3D", "Targeting3DBehavior",
		"Lock-on and aim help for a Node3D: hold the nearest hostile in a cone around the camera's forward, cycle to the next, let go when it dies or leaves the range, bend a stick direction toward whatever the player is nearly pointing at, and snap onto a target when the sights come up. The bend is the accessibility Aim Assist Radius setting, so a zero radius turns the help off from the options screen.",
		Lib.manifest().behavior().category("Targeting 3D").tags(["combat", "aim", "targeting"]))
	src.note("Targeting 3D behavior: attach it under the node that aims. Lock On To Nearest searches a cone around the CAMERA's forward - what is on screen is what can be locked - for the closest member of a group; Cycle Target steps along that same cone, left to right, and wraps. A lock ends when the target dies, leaves the range, steps behind a wall (with sight checking on) or is released, and On Target Lost says which. Assisted Aim, Magnetism and Snap On Aim Down Sights read the shipped Aim Assist Radius setting, so a zero radius is the off switch the options screen already has. This pack is an event sheet - extend it by editing it.")
	src.block("block_1")
	src.on_ready()
	src.on_process()
	src.verb("lock_nearest", "Lock On To Nearest",
		"Searches a cone around the camera's forward for the closest member of a group inside a range, and holds it. On Target Locked fires when the held target changes; a search that finds nothing leaves the current lock alone, so a row polled every frame does not drop the target on the first frame it goes behind cover. Leave the group empty for the behaviour's own Target Group, and write 0 for the cone or the range to use its own defaults. With no camera in the scene the cone falls back to the host's own forward axis, which is what a turret has.",
		[["group", "StringName"], ["cone_degrees", "float"], ["max_range", "float"]])
	src.verb("lock_on_to", "Lock On To",
		"Holds one node you name, whatever the cone and the range say - the boss the cutscene points at, the enemy the player clicked. It becomes the only entry in the ring, so a Cycle Target after it stays on it until the next search.",
		[["node", "Node3D"]])
	src.verb("cycle_target", "Cycle Target",
		"Steps to the next candidate the last Lock On To Nearest found, left to right by angle around the world's up axis, and wraps round to the leftmost after the rightmost. Candidates that died since the search are dropped first, so cycling never lands on a corpse. With nothing held it takes the leftmost.",
		[])
	src.verb("release_lock", "Release Lock",
		"Lets the held target go on purpose. On Target Lost fires with the reason 'released', so one trigger row cleans the reticle up whether the target died, walked away, ducked behind a wall or was let go.",
		[])
	src.verb("snap_on_aim_down_sights", "Snap On Aim Down Sights",
		"Turns the host to face the nearest target the aim is already nearly on - the settle a controller player gets the instant the sights come up. It refuses a turn wider than the degrees you allow, so it never yanks the view somewhere the player was not looking, and it does nothing at all while the Aim Assist Radius is zero.",
		[["max_degrees", "float"]])
	src.condition("is_locked_on", "Is Locked On",
		"True while this behaviour is holding a target that is still alive - the gate for a reticle, a homing shot or a strafe camera.",
		[])
	src.object_expression("locked_target", "Locked Target",
		"The node being held, or null when nothing is. Hand it to any row that takes a node: a homing rocket, a Look At, a nameplate's anchor.",
		[], "Node3D")
	src.expression("locked_target_on_screen", "Locked Target On Screen",
		"Where the held target lands on screen right now, through the camera's own projection - the position for a reticle living on a CanvasLayer. Vector2.ZERO when nothing is held or there is no camera to ask.",
		[], TYPE_VECTOR2)
	src.expression("distance_to_target", "Distance To Target",
		"How far the held target is, in metres. INF when nothing is held, so a row asking whether the target is closer than something is simply false rather than accidentally true.",
		[], TYPE_FLOAT)
	src.expression("assisted_aim", "Assisted Aim",
		"The aim direction you hand it, bent toward the nearest target the ray is nearly pointing at, by a strength from 0 (no help) to 1 (dead on). 'Nearly' is the accessibility Aim Assist Radius, measured across the ray, so a zero radius hands the direction straight back and the options screen turns the help off. The length you passed in is kept.",
		[["direction", "Vector3"], ["strength", "float"]], TYPE_VECTOR3)
	src.expression("magnetism", "Magnetism",
		"The turn rate you hand it, slowed by the behaviour's Magnetism Slowdown while the aim is crossing a target - the drag that makes a stick settle on an enemy instead of sliding past. Unchanged when nothing is under the aim, and unchanged when the Aim Assist Radius is zero.",
		[["turn_rate", "float"]], TYPE_FLOAT)
	Lib.verb_sentences(src.sheet, {
		"lock_nearest": "lock on to the nearest [b]{group}[/b] in a [b]{cone_degrees}[/b]° cone, [b]{max_range}[/b] out",
		"lock_on_to": "lock on to [i]{node}[/i]",
		"cycle_target": "cycle to the next target",
		"release_lock": "release the lock",
		"snap_on_aim_down_sights": "snap onto a target within [b]{max_degrees}[/b]°",
		"is_locked_on": "locked on to something",
	})
	Lib.feature_verbs(src.sheet, ["lock_nearest", "cycle_target", "assisted_aim"])
	return Lib.publish(src, "res://eventsheet_addons/targeting_3d/targeting_3d_behavior")
