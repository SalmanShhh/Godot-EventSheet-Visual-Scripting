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
	descriptors.append(F.make_descriptor("Core", "VideoSetStream", "Set Video", ACEDescriptor.ACEType.ACTION, "{node}.stream = load({file})", "", [F.make_param("node", "String", NODE_DEFAULT, "Player", "The VideoStreamPlayer that shows the film.", "expression"), F.make_param("file", "String", "\"res://intro.ogv\"", "File", "The .ogv file to play.", "expression")], CAT, "Set video to {file}")
		.described("Loads a film into the player. The row names the file, not the folders in front of it.").featured())
	descriptors.append(F.make_descriptor("Core", "VideoPlay", "Play Video", ACEDescriptor.ACEType.ACTION, "{node}.play()", "", [F.make_param("node", "String", NODE_DEFAULT, "Player", "The VideoStreamPlayer to start.", "expression")], CAT, "Play")
		.described("Starts the film from where it stands.").featured())
	descriptors.append(F.make_descriptor("Core", "VideoSetPaused", "Pause Video", ACEDescriptor.ACEType.ACTION, "{node}.paused = {paused}", "", [F.make_param("node", "String", NODE_DEFAULT, "Player", "The VideoStreamPlayer to hold.", "expression"), F.make_param("paused", "bool", "true", "Paused", "false starts it again from the same frame.", "", ["true", "false"])], CAT, "Pause")
		.described("Holds the film on its current frame, or lets it run on again."))
	descriptors.append(F.make_descriptor("Core", "VideoStop", "Stop Video", ACEDescriptor.ACEType.ACTION, "{node}.stop()", "", [F.make_param("node", "String", NODE_DEFAULT, "Player", "The VideoStreamPlayer to stop.", "expression")], CAT, "Stop")
		.described("Stops the film and rewinds it to the beginning."))

	# ── Conditions ──
	descriptors.append(F.make_descriptor("Core", "VideoIsPlaying", "Video Is Playing", ACEDescriptor.ACEType.CONDITION, "{node}.is_playing()", "", [F.make_param("node", "String", NODE_DEFAULT, "Player", "The VideoStreamPlayer to ask about.", "expression")], CAT, "Is playing")
		.described("True while the film is running - false when it is paused, stopped or finished.").featured())

	return descriptors
