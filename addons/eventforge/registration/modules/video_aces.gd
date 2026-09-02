# EventForge module - the Video object (playing a film in the layout).
#
# A VideoStreamPlayer node plays an .ogv file inside the game: an intro, a cutscene, a looping
# background. The rows here are its four verbs and its one question, filed under the one object name
# the sheet gives every video row - so a hand-written player opened as a sheet and a player driven
# from the picker are the same bytes and read as the same rows.
#
# Whether the film has ENDED is a signal on the node (`finished`), which the sheet wires up the way
# it wires any other node signal.
@tool
class_name EventForgeVideoACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Video"

## The node every row acts on. A VideoStreamPlayer beside the sheet's own node is the arrangement
## nearly every project uses, so it is the default the row arrives with.
const NODE_DEFAULT := "$VideoStreamPlayer"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Actions ──
	descriptors.append(F.act("VideoSetStream", "Set Video", "{node}.stream = load({file})", CAT, "Set video to {file}", "Loads a film into the player. The row names the file, not the folders in front of it.").param_typed("String", "node", NODE_DEFAULT, "Player", "The VideoStreamPlayer that shows the film.", "expression").param("file", "\"res://intro.ogv\"", "File", "The .ogv file to play.", "expression").featured())
	descriptors.append(F.act("VideoPlay", "Play Video", "{node}.play()", CAT, "Play", "Starts the film from where it stands.").param_typed("String", "node", NODE_DEFAULT, "Player", "The VideoStreamPlayer to start.", "expression").featured())
	descriptors.append(F.act("VideoSetPaused", "Pause Video", "{node}.paused = {paused}", CAT, "Pause", "Holds the film on its current frame, or lets it run on again.").param_typed("String", "node", NODE_DEFAULT, "Player", "The VideoStreamPlayer to hold.", "expression").param_built(F.make_param("paused", "bool", "true", "Paused", "false starts it again from the same frame.", "", ["true", "false"])))
	descriptors.append(F.act("VideoStop", "Stop Video", "{node}.stop()", CAT, "Stop", "Stops the film and rewinds it to the beginning.").param_typed("String", "node", NODE_DEFAULT, "Player", "The VideoStreamPlayer to stop.", "expression"))

	# ── Conditions ──
	descriptors.append(F.cond("VideoIsPlaying", "Video Is Playing", "{node}.is_playing()", CAT, "Is playing", "True while the film is running - false when it is paused, stopped or finished.").param_typed("String", "node", NODE_DEFAULT, "Player", "The VideoStreamPlayer to ask about.", "expression").featured())

	return descriptors
