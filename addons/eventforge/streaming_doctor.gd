# Godot EventSheets - the Doctor's Streaming section.
#
# A streamed world is a folder of scenes named by cell, so the two things that go wrong with one
# are facts about that FOLDER rather than about any row:
#
#   A HOLE IN THE GRID    a folder that is a filled rectangle except for two cells nobody made.
#                       Nothing errors: the player simply walks into a void where the ground
#                       should be, at run time, on the machine the game was sent to.
#   A CAMERA IN A CHUNK   a chunk scene carrying a Camera2D or Camera3D. A camera SAVED AS THE
#                       CURRENT one takes the view the moment its chunk enters the tree, and where
#                       a viewport has no current camera at all the first chunk to arrive keeps it.
#                       Neither is a thing the chunk was authored to do. It works perfectly while
#                       the chunk is the scene you are editing - it is the only camera there - and
#                       only misbehaves once it is one tile of a world. The engine does NOT hand
#                       the view to every camera that streams in; saying it did named a jump that
#                       would not happen, over scenes that behave.
#
# Neither is a line anybody wrote, so no amount of reading the sheet would find them. Both are
# visible in the file names and the `.tscn` before the game is run once.
#
# It ships as an EXTENSION check, registered through the very seam a pack uses
# (`EventSheets.register_doctor_check`), so a project that streams with a loader of its own adds
# its chunk folders to this same section rather than inventing a second report. Registering from
# the Doctor's own run is what makes it show up in all four runners (the panel, the headless CLI,
# CI and the MCP server) without the plugin having to be loaded first.
#
# NOTHING is written and nothing is stored, and a project with no chunk folder in it costs one
# name test per scene and reports nothing at all.
@tool
class_name EventSheetStreamingDoctor
extends EventSheetDoctorSection

## The id the section is registered under, and the ids each kind of finding is filed as. Frozen
## alongside the wording: the quick-fix chips and the tests address a finding by its check id.
const CHECK_ID := "streaming"
const CHECK_GAP := "streaming-chunk-gap"
const CHECK_CAMERA := "streaming-chunk-camera"

## The two node classes a chunk must not carry. Spelled as the `.tscn` spells them, because that
## is what is read - a scene file names its node types in full.
const CAMERA_CLASSES := ["Camera2D", "Camera3D"]

## How many missing cells a gap finding names before it says "and more". A reader needs to know
## WHICH cells to make; a list of forty is a wall.
const NAMED_GAPS := 6


## Registers the section, replacing any previous registration - so a plugin reload, a second
## Doctor run and a test that registers it by hand all leave exactly one.
static func ensure_registered() -> void:
	EventSheets.register_doctor_check(CHECK_ID, Callable(EventSheetStreamingDoctor, "check"))


## The section itself, with the contract every registered check has: append findings, never write
## inside res://.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	var folders: Dictionary = chunk_folders()
	findings.append_array(report(folders, scene_texts(folders)))


## Every chunk folder in the project, keyed by folder. The plugin's own tree is left out, like
## every other Doctor corpus. One file-name test per scene, and no scene is opened here.
static func chunk_folders() -> Dictionary:
	var paths: PackedStringArray = PackedStringArray()
	for scene_path: String in EventSheetSceneConnections.scene_paths():
		if scene_path.begins_with(PLUGIN_DIRECTORY):
			continue
		paths.append(scene_path)
	return EventForgeChunkFolderFacts.folders(paths)


## The text of every scene in those folders, keyed by path - the only reading that opens a file,
## and only for scenes already known to be chunks.
static func scene_texts(folders: Dictionary) -> Dictionary:
	var texts: Dictionary = {}
	for folder: String in folders.keys():
		for scene_path: String in (folders[folder] as Dictionary)["paths"] as PackedStringArray:
			texts[scene_path] = EventSheetProjectDoctor.source_of(scene_path)
	return texts


## The whole section as findings, the summary first: how many chunk folders the project has and
## how many of them have something to look at, then the holes, then the cameras. Pure over its two
## corpora, so a test can hand it one folder and one scene.
static func report(folders: Dictionary, texts: Dictionary) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	if folders.is_empty():
		return findings
	var names: Array = folders.keys()
	names.sort()
	var troubled: int = 0
	# The summary points at the FIRST folder with something wrong, because that is the one worth
	# opening - double-clicking the line in the panel is what takes the reader there.
	var worst_folder: String = str(names[0])
	for folder: String in names:
		var found: Array[Dictionary] = folder_findings(folder, folders[folder] as Dictionary, texts)
		if found.is_empty():
			continue
		if troubled == 0:
			worst_folder = folder
		troubled += 1
		findings.append_array(found)
	findings.insert(0, _finding("info", CHECK_ID, worst_folder,
		EventSheetL10n.translate("Streaming: %d chunk folder(s), %d with something to look at.") % [
			names.size(), troubled], ""))
	return findings


## What one chunk folder contributes: its holes, then a line per chunk carrying a camera, in path
## order. Pure over the folder's own reading and the texts it was handed.
static func folder_findings(folder: String, entry: Dictionary, texts: Dictionary) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var cells: Array = entry["cells"] as Array
	var flat: bool = bool(entry["flat"])
	# COUNTED BEFORE IT IS LISTED. The box a deliberately sparse world spans is enormous and almost
	# all hole, and naming its cells to decide they are not worth naming is the whole box walked on
	# every Doctor run - in the panel, the headless run, CI and the server alike.
	var holes: int = EventForgeChunkFolderFacts.missing_count(cells)
	if EventForgeChunkFolderFacts.gap_is_worth_reporting(cells.size(), holes):
		var missing: Array[Vector3i] = EventForgeChunkFolderFacts.missing_cells(cells)
		findings.append(_finding("warning", CHECK_GAP, folder,
			EventSheetL10n.translate("%s holds %d chunk scenes with %d cell(s) missing from the middle of the grid: %s. A player who walks into one of those cells finds nothing there.") % [
				folder, cells.size(), missing.size(),
				EventForgeChunkFolderFacts.cells_as_words(missing, flat, NAMED_GAPS)],
			EventForgeChunkFolderFacts.file_name_of(str(entry["prefix"]), missing[0], flat)))
	for scene_path: String in entry["paths"] as PackedStringArray:
		if not carries_a_camera(str(texts.get(scene_path, ""))):
			continue
		findings.append(_finding("warning", CHECK_CAMERA, scene_path,
			EventSheetL10n.translate("%s is a chunk scene carrying a camera. A camera saved as the current one takes the view the moment its chunk streams in, and where nothing else is current the first chunk to arrive keeps it - keep the camera in the scene that owns the player.") % scene_path.get_file(),
			scene_path.get_file()))
	return findings


## Whether a scene's text declares a camera node. A `.tscn` names its node types in full, so this
## is the same question the editor answers when it draws the scene tree - and it is asked of text
## rather than of a loaded scene, because loading every chunk of a streamed world to audit it
## would be the very thing the pack exists to avoid.
static func carries_a_camera(scene_text: String) -> bool:
	for camera_class: String in CAMERA_CLASSES:
		if scene_text.contains("type=\"%s\"" % camera_class):
			return true
	return false
