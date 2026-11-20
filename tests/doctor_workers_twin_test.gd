# Godot EventSheets - the Doctor's third speed pass answers what the passes before it answered.
#
# Three kinds of change are pinned here: a question about a script's text that is asked on a worker thread now
# (the ranking of the Mistake checks, the groups scripts add, four Ship it questions) must give the answer the
# loop over the scripts gives; a check that learns from one cheap look that a script has nothing to find (a
# script that never says res://, never names a loader) must still find what such a script would; and the quote
# stripper's shortcut for a line with no quote must be the line itself.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "doctor_workers_twin_test"
const CORPUS: PackedStringArray = [
	"res://demo/showcase/boomer_level/boomer_level.gd",
	"res://demo/showcase/skate_park/skate_park.gd",
	"res://demo/showcase/draw_lab/draw_lab.gd",
]


static func run() -> bool:
	var rows: Array = []
	# The ranking: text rules asked on a worker, the scene rule asked after, one list.
	rows.append(["the ranking in turns is the ranking", await EventSheetMistakeChecksDoctor.ranked_in_turns(CORPUS), EventSheetMistakeChecksDoctor.ranked(CORPUS)])
	for path: String in CORPUS:
		var text: String = FileAccess.get_file_as_string(path)
		var scene_rule: int = 1 if EventSheetMistakeChecksDoctor._says_any(text, EventSheetMistakeChecksDoctor.SCENE_WORDS) and not EventSheetSceneReplication.scenes_using(path).is_empty() else 0
		rows.append(["the evidence of %s is what its text says plus the scene rule" % path.get_file(), EventSheetMistakeChecksDoctor.evidence(text, path), EventSheetMistakeChecksDoctor.evidence_of_text(text) + scene_rule])
	# The groups scripts add, read a batch at a time, are the groups the plain walk makes.
	EventSheetMistakeFindings.clear_cache()
	var whole: Dictionary = EventSheetMistakeFindings.project_groups().duplicate()
	EventSheetMistakeFindings.clear_cache()
	var turns: Dictionary = (await EventSheetMistakeFindings.project_groups_in_turns()).duplicate()
	rows.append(["the project's groups in turns are the groups", turns.keys(), whole.keys()])
	rows.append(["and name where each comes from the same way", turns, whole])
	EventSheetMistakeFindings.clear_cache()
	# A script that names no res:// path writes none to it; one that does is still found.
	rows.append(["a script with no res:// has no res write", EventSheetFilesDoctor.res_write_lines("extends Node\nfunc _ready() -> void:\n\tvar f := FileAccess.open(\"user://a.txt\", FileAccess.WRITE)\n"), PackedStringArray()])
	rows.append(["a write to a res:// literal is still found", EventSheetFilesDoctor.res_write_lines("extends Node\nfunc _ready() -> void:\n\tvar f := FileAccess.open(\"res://a.txt\", FileAccess.WRITE)\n"), PackedStringArray(["var f := FileAccess.open(\"res://a.txt\", FileAccess.WRITE)"])])
	# A script that names no loader loads no outside file; one that does is still found.
	rows.append(["a script with no loader call loads nothing from outside", EventForgeOutsidePaths.loading_outside_lines("extends Node\nvar path := \"user://mods/a.tscn\"\n"), PackedStringArray()])
	var dropped: String = "extends Node\nfunc _ready() -> void:\n\tget_window().files_dropped.connect(_on_drop)\n\n\nfunc _on_drop(files: PackedStringArray) -> void:\n\tvar scene = load(files[0])\n"
	rows.append(["a path from a drop handed to load is still found", EventForgeOutsidePaths.loading_outside_lines(dropped).size(), 1])
	# The quote stripper.
	rows.append(["a line with no quote is its own code", EventForgeMultiplayerLift.outside_strings("rpc(take, 1)"), "rpc(take, 1)"])
	rows.append(["a quoted run is removed", EventForgeMultiplayerLift.outside_strings("rpc(\"take\", 1)"), "rpc(, 1)"])
	rows.append(["and so is a single-quoted one", EventForgeMultiplayerLift.outside_strings("print('x') # rpc"), "print() # rpc"])
	# The Ship it questions asked of every text at once.
	var sources: Dictionary = {
		"res://a.gd": "extends Node\nfunc _ready() -> void:\n\tprint(\"hi\")\n\tget_tree().change_scene_to_file(\"res://big.tscn\")\n",
		"res://b.gd": "extends Node\nfunc _ready() -> void:\n\tpass\n",
	}
	var mapped: Dictionary = await EventSheetShipItDoctor._map_texts(sources, EventSheetShipItDoctor.plainly_opened_scenes)
	rows.append(["the scenes each script opens are mapped by path", mapped.keys(), ["res://a.gd", "res://b.gd"]])
	rows.append(["and are the scenes the script itself names", mapped["res://a.gd"], EventSheetShipItDoctor.plainly_opened_scenes(str(sources["res://a.gd"]))])
	rows.append(["a script that opens none maps to none", mapped["res://b.gd"], PackedStringArray()])
	return SUPPORT.pins(P, rows)
