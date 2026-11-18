# Godot EventSheets - a 3D file's velocity rows read under the file's own name.
#
# Set Velocity X and Add To Velocity are filed under CharacterBody2D and have no 3D twin, so a row of
# either in a file that extends CharacterBody3D read "CharacterBody2D | Set velocity X to 4" while the
# line beside it (Move and slide, which has a twin) read under the file's own name. The template of
# each is as true of a 3D body as of a 2D one, so in a file that extends a 3D class the row now reads
# under the host's own name. A 2D file, and a file that extends a plain Node, read as they always did,
# and the bytes of the line are the same in every file.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const LINES := preload("res://tools/reading_lines.gd")
const P := "host_name_on_three_d_files_test"


static func run() -> bool:
	var rows: Array = []
	var three_d: String = "class_name WalkerThreeD\nextends CharacterBody3D\n\n\nfunc _physics_process(_delta: float) -> void:\n\tvelocity.x = 4.0\n\tvelocity += Vector3.UP\n\tmove_and_slide()\n"
	rows.append(["a 3D file: every row reads under the file's own name", _objects(three_d), ["WalkerThreeD", "WalkerThreeD", "WalkerThreeD"]])
	var two_d: String = "class_name WalkerTwoD\nextends CharacterBody2D\n\n\nfunc _physics_process(_delta: float) -> void:\n\tvelocity.x = 4.0\n\tvelocity += Vector2.UP\n\tmove_and_slide()\n"
	rows.append(["a 2D file: every row reads under the file's own name", _objects(two_d), ["WalkerTwoD", "WalkerTwoD", "WalkerTwoD"]])
	# A row aimed at another node is that node's line, whichever file it sits in.
	var aimed: String = "class_name AimerThreeD\nextends Node3D\n\n\nfunc _ready() -> void:\n\t$Body.velocity.x = 4.0\n"
	rows.append(["a 3D file: a row aimed at another node keeps its class", _objects(aimed), ["CharacterBody2D"]])
	var plain: String = "class_name AimerPlain\nextends Node\n\n\nfunc _ready() -> void:\n\t$Body.velocity.x = 4.0\n"
	rows.append(["a plain Node file: a row aimed at another node keeps its class", _objects(plain), ["CharacterBody2D"]])
	for source: String in [three_d, two_d]:
		var name: String = "host_name_%d.gd" % source.hash()
		rows.append(["the bytes of the file are the same (%s)" % source.get_slice("\n", 1), SUPPORT.reemit(source, SUPPORT.own_path(name)), source])
	return SUPPORT.pins(P, rows)


## The object word of every action cell of the file, in order, read against the editor's own vocabulary.
static func _objects(source: String) -> Array:
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	var no_sources: Array[Object] = []
	registry.refresh_from_sources(no_sources, true)
	var words: Array = []
	for reading: Variant in LINES.readings_of_sheet(SUPPORT.reopen(source), "own", registry):
		if str(reading.lane) == "action":
			words.append(str(reading.object_label))
	return words
