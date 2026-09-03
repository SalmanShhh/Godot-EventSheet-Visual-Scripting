# Pack builder - camera_rail (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")

## The four shot curves, as a dropdown on every verb that takes one. The keys are the words the
## behaviour matches, the labels are what the picker shows.
const _EASES := ["linear=Linear", "ease_in=Ease in", "ease_out=Ease out",
	"ease_in_out=Ease in and out"]


## Camera Rail: a shot list for a Camera2D. Attach it under the camera you want to direct and the
## rail flies that camera along a drawn Path2D over a number of seconds, holds on a beat, blends
## onto another camera and hands the view over, or cuts to one outright. Every shot ends in a
## trigger, so a cutscene is a chain of rows rather than a coroutine.
##
## The rail moves a camera; it does not decorate one. Shake and the FOV punch from the Juice packs
## ride on whichever camera is CURRENT, the rail's own included, so the two compose without either
## knowing about the other.
static func build() -> bool:
	var src: Lib.PackSource = Lib.pack_from_source("camera_rail", "Camera2D", "CameraRailBehavior",
		"A shot list for a Camera2D: fly the camera along a drawn Path2D over a number of seconds, hold on a beat, blend onto another camera and hand the view over, or cut to one outright. On Shot Finished and On Blend Finished end every shot, so a cutscene is a chain of rows.",
		Lib.manifest().behavior().category("Camera Rail").tags(["camera", "cinematic", "path"]))
	src.note("Camera Rail behavior: attach it under the Camera2D you want to direct. Fly Along walks that camera down a drawn Path2D over seconds, Hold parks it on a beat, Blend To travels onto another camera and hands the view over, and Cut To switches outright. On Shot Finished chains the next shot. Shake and zoom from the Juice pack ride on whichever camera is current, this one included. This pack is an event sheet - extend it by editing it.")
	src.block("block_1")
	src.on_ready()
	src.on_process()
	src.verb("fly_along", "Fly Along",
		"Flies the rail's camera along a drawn Path2D, start to end, over a number of seconds - the dolly shot. Leave the path empty to walk the route set in the Inspector, and 0 seconds to use the rail's default pace. On Shot Finished fires at the end of the run.",
		[["path", "Path2D"], ["seconds", "float"], ["ease", "String"]])
	_options(src.sheet, "ease", _EASES)
	src.verb("cut_to", "Cut To",
		"Hands the view to another camera immediately - the hard cut. Whatever shot the rail was running stops where it stands, without firing On Shot Finished, because the cut is the ending.",
		[["camera", "Camera2D"]])
	src.verb("blend_to", "Blend To",
		"Travels the rail's camera onto another camera - position, rotation and zoom together - over a number of seconds, then hands the view to it. The soft cut between two framed shots. On Blend Finished fires at the handover.",
		[["camera", "Camera2D"], ["seconds", "float"], ["ease", "String"]])
	_options(src.sheet, "ease", _EASES)
	src.verb("hold", "Hold",
		"Parks the rail for a number of seconds and then fires On Shot Finished - the beat between two moves. 0 seconds falls back to the rail's default pace.",
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
		"fly_along": "fly along [i]{path}[/i] over [b]{seconds}[/b]s, [b]{ease}[/b]",
		"cut_to": "cut to [i]{camera}[/i]",
		"blend_to": "blend onto [i]{camera}[/i] over [b]{seconds}[/b]s, [b]{ease}[/b]",
		"hold": "hold this shot for [b]{seconds}[/b]s",
		"stop_rail": "stop the rail",
		"is_flying": "the rail is flying",
	})
	Lib.feature_verbs(src.sheet, ["fly_along", "blend_to", "cut_to"])
	return Lib.publish(src, "res://eventsheet_addons/camera_rail/camera_rail_behavior")


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
