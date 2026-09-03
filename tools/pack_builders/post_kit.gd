# Pack builder - post_kit (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Post Kit: the camera's own post stack, and an outline that goes through walls.
##
## Godot 4 gives a 3D camera a Compositor, and a Compositor a list of CompositorEffects: scripts that
## are handed the frame after it is drawn and may do anything to it. It is the right seam and almost
## nobody reaches it, because reaching it means a compute shader, a rendering device, a uniform set
## and a dispatch before a game gets its first vignette.
##
## So the pack ships them. Five effects wearing the SAME WORDS the 2D post stack uses - vignette,
## desaturate, pixelate, tint, fade - so a row reads alike whether it is on the screen or on the
## camera, and a project that moves renderer keeps its sheet. Plus the one thing only a 3D camera can
## do: an outline drawn through walls, from a mask that a second camera renders of one visual layer.
##
## ONLY FORWARD+ HAS A COMPOSITOR, and the pack says so in every row's help, does nothing at all on
## Mobile and Compatibility rather than erroring, and is named once by the ship-it check with the 2D
## packs as the door.
##
## The effect scripts and their compute shaders are REAL FILES in their own source folder, copied
## into the pack's `effects/` folder by `Lib.ship_files` the way any companion a pack needs would be.
## They sit in a folder of their own so a reader can drag one straight onto a Compositor in the
## Inspector without the pack at all.
static func build() -> bool:
	var src: Lib.PackSource = Lib.pack_from_source("post_kit", "Node", "PostKitBehavior",
		"The camera's own post stack, for Forward+: vignette, desaturate, pixelate, tint and fade, under the same names the 2D post stack uses, added by name and pulsed in one row. Plus an outline drawn through walls - mark a group, and a second camera's mask of one visual layer is edge-detected over the frame. Attach it under the Camera3D or the WorldEnvironment that carries the Compositor.",
		Lib.manifest().behavior().category("Post Kit").tags(PackedStringArray([
			"camera", "effects", "shader", "3d", "visual"])))
	src.note("Post Kit behavior: attach it under the Camera3D (or the WorldEnvironment) whose Compositor you want to fill. Add Post Effect wears one of five effects - vignette, desaturate, pixelate, tint, fade - the same words the 2D post stack uses, so a row reads alike on either; Pulse Post Effect is the whole sentence a hit wants in one row. Outline Group Through Walls marks a group's meshes on the pack's mask layer and draws their edge over the frame, wall or no wall; Stop Outlining ends it and frees the rig. FORWARD+ ONLY: on Mobile and Compatibility these rows do nothing at all, and the Screen FX and Blend Modes packs do the same looks on any renderer. This pack is an event sheet - extend it by editing it.")
	src.block("runtime")
	src.on_ready()
	src.on_process()
	if not Lib.publish(src, "res://eventsheet_addons/post_kit/post_kit_behavior"):
		return false
	# The effects ARE the pack: without their scripts and their compute shaders every row here adds
	# an entry to a stack that draws nothing. They ship in the same build, into a folder of their
	# own beside the pack script.
	return Lib.ship_files("post_kit_effects", "res://eventsheet_addons/post_kit/effects/post_kit_effects",
		PackedStringArray(["gd", "glsl"]))
