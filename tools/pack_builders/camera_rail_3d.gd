# Pack builder - camera_rail_3d (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")

## The four shot curves, as a dropdown on every verb that takes one. The keys are the words the
## behaviour matches, the labels are what the picker shows.
const _EASES := ["linear=Linear", "ease_in=Ease in", "ease_out=Ease out",
	"ease_in_out=Ease in and out"]

## The class the pack ships as - the prefix a row's emitted call opens with.
const PACK_CLASS := "CameraRail3DBehavior"


## Camera Rail 3D: the Camera Rail's twin for a Camera3D. The same shot list - fly along a drawn
## Path3D over seconds, hold, blend onto another camera and hand the view over, cut to one
## outright - with the two things only 3D has: a node the camera keeps in frame while it flies,
## and a field of view that travels with the blend.
##
## The rail moves a camera; it does not decorate one. Shake and the FOV punch from the Juice 3D
## pack ride on whichever camera is CURRENT, the rail's own included, so the two compose without
## either knowing about the other.
static func build() -> bool:
	var src: Lib.PackSource = Lib.pack_from_source("camera_rail_3d", "Camera3D", "CameraRail3DBehavior",
		"A shot list for a Camera3D: fly the camera along a drawn Path3D over a number of seconds while it keeps a node in frame, hold on a beat, blend onto another camera - transform and field of view together - and hand the view over, or cut to one outright. On Shot Finished and On Blend Finished end every shot.",
		Lib.manifest().behavior().category("Camera Rail 3D").tags(["camera", "cinematic", "path"]))
	src.note("Camera Rail 3D behavior: attach it under the Camera3D you want to direct. Fly Along walks that camera down a drawn Path3D over seconds, optionally keeping a node in frame the whole way; Hold parks it on a beat; Blend To travels onto another camera - transform and field of view together - and hands the view over; Cut To switches outright. On Shot Finished chains the next shot. Shake and the FOV punch from the Juice 3D pack ride on whichever camera is current, this one included. This pack is an event sheet - extend it by editing it.")
	src.block("block_1")
	src.on_ready()
	src.on_process()
	src.verb("fly_along", "Fly Along",
		"Flies the rail's camera along a drawn Path3D, start to end, over a number of seconds - the dolly shot. Name a node to keep in frame and the camera turns to face it the whole way; write null and the camera keeps the heading it was left with. The rail's own camera takes the view as the flight starts, so a flight begun after a Cut To is seen rather than played off screen. Write null for the path to walk the route set in the Inspector, and 0 seconds to use the rail's default pace. On Shot Finished fires at the end of the run.",
		[["path", "Path3D"], ["seconds", "float"], ["ease", "String"], ["look_at", "Node3D"]])
	_options(src.sheet, "ease", _EASES)
	_quoted_argument(src.sheet, "fly_along({path}, {seconds}, \"{ease}\", {look_at})")
	src.verb("cut_to", "Cut To",
		"Hands the view to another camera immediately - the hard cut. Whatever shot the rail was running stops where it stands, without firing On Shot Finished, because the cut is the ending.",
		[["camera", "Camera3D"]])
	src.verb("blend_to", "Blend To",
		"Travels the rail's camera onto another camera - position, rotation and field of view together - over a number of seconds, then hands the view to it. The soft cut between two framed shots. The travel starts from whatever shot is on screen: if the rail had handed the view away, its own camera stands on that shot first and takes the view back, so the blend is continuous rather than a jump. On Blend Finished fires at the handover.",
		[["camera", "Camera3D"], ["seconds", "float"], ["ease", "String"]])
	_options(src.sheet, "ease", _EASES)
	_quoted_argument(src.sheet, "blend_to({camera}, {seconds}, \"{ease}\")")
	src.verb("hold", "Hold",
		"Parks the rail for a number of seconds and then fires On Shot Finished - the beat between two moves. It leaves the view exactly where it is, so a hold after a Cut To is the beat on THAT camera. 0 seconds falls back to the rail's default pace.",
		[["seconds", "float"]])
	src.verb("stop_rail", "Stop Rail",
		"Halts the shot where it stands, WITHOUT firing On Shot Finished - a cutscene the player skipped, a chase that ended early. The next Fly Along, Hold or Blend To starts a fresh shot.",
		[])
	src.condition("is_flying", "Is Flying",
		"True while a Fly Along run is actually travelling. A Hold and a blend are not flights, so this stays false through both - the gate for a skip prompt or a letterbox that only belongs on a dolly.",
		[])
	src.expression("rail_progress", "Rail Progress",
		"How far through the current shot the rail has come, from 0 at its start to 1 when it finished - the progress bar of a cutscene, or the driver for a fade that tracks the move. It is the time through the shot, before the ease bends it, and it keeps its last value once the shot ends.",
		[], TYPE_FLOAT)
	Lib.verb_sentences(src.sheet, {
		"fly_along": "fly along [i]{path}[/i] over [b]{seconds}[/b]s, [b]{ease}[/b], watching [i]{look_at}[/i]",
		"cut_to": "cut to [i]{camera}[/i]",
		"blend_to": "blend onto [i]{camera}[/i] over [b]{seconds}[/b]s, [b]{ease}[/b]",
		"hold": "hold this shot for [b]{seconds}[/b]s",
		"stop_rail": "stop the rail",
		"is_flying": "the rail is flying",
	})
	Lib.feature_verbs(src.sheet, ["fly_along", "blend_to", "cut_to"])
	return Lib.publish(src, "res://eventsheet_addons/camera_rail_3d/camera_rail_3d_behavior")


## Sets the dropdown options[] on the last-declared verb's parameter, so the row offers the words
## it actually accepts instead of a free-text field somebody has to spell right.
static func _options(sheet: EventSheetResource, param_id: String, choices: Array) -> void:
	var typed: Array[String] = []
	for choice: Variant in choices:
		typed.append(str(choice))
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.options = typed


## Rewrites the last-declared verb's emitted call so a slot lands inside GDScript QUOTES. A dropdown
## key is inserted verbatim, so a String argument picked from a list would otherwise emit
## `fly_along($Route, 4, ease_in)` - an identifier nothing declares. The four keys are words the
## behaviour matches, and words in GDScript are written in quotes; the annotation vocabulary carries
## no quoted dropdown key (the scanner reads the quotes off again), so the template holds them.
## The call prefix is the pack's own class name, which is the same one the automatic template uses.
static func _quoted_argument(sheet: EventSheetResource, call: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	fn.codegen_template_override = "$%s.%s" % [PACK_CLASS, call]
