@tool
class_name MarkedPlaceIconTest
extends RefCounted

# A place copied off a MARKED spot wears the mark: `crate.global_position = spawn.global_position`
# reads "crate ▸ Set position to spawn spawn point", and the value in it names the marker's own class
# so the canvas can draw that class's picture beside it - the picture the scene tree shows the node by.
#
# The class is named by the sentence layer, which had already resolved it for the note, so the canvas
# never looks a class up on its own. Three gates:
#   1. the class is named on a marked place, and on nothing else - a place copied off a plain object
#      has no mark to wear, and the row must not invent one;
#   2. the words did not move: naming the class is an extra fact on the reading, not a new sentence;
#   3. the promise it rests on - an icon is DISPLAY, so the file still saves byte-identically.

const GDScriptImporter := preload("res://addons/eventforge/importer/gdscript_importer.gd")

const SOURCE_PATH := "user://eventforge_marked_place_icon.gd"

const SOURCE: String = """extends Node3D

@onready var crate: Node3D = $Crate
@onready var spawn: Marker3D = $SpawnPoint
@onready var target: Node3D = $Target

func place_them():
	crate.global_position = spawn.global_position
	crate.global_position = target.global_position
"""


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _icon_class() and all_passed
	all_passed = _words_unmoved() and all_passed
	all_passed = _round_trip() and all_passed
	return all_passed


## Gate one: which value gets a picture, and which does not.
static func _icon_class() -> bool:
	var ok: bool = true
	var context: Dictionary = _context()
	ok = _check("a place copied off a marker names the marker's class",
		str(EventSheetSentence.statement(
			"crate.global_position = spawn.global_position", context).get("value_icon_class", "")),
		"Marker3D") and ok
	ok = _check("a place copied off a plain object names none",
		str(EventSheetSentence.statement(
			"crate.global_position = target.global_position", context).get("value_icon_class", "")),
		"") and ok
	# The 2D marker is not reachable here at all - the whole section is gated on a spatial object -
	# but a 3D object standing where a 2D one stands would be a row nobody could trust, so pin that
	# the placement is not claimed and no picture is named.
	var flat: Dictionary = _context()
	(flat["object_classes"] as Dictionary)["spawn"] = "Node2D"
	var flat_reading: Dictionary = EventSheetSentence.statement(
		"crate.global_position = spawn.global_position", flat)
	ok = _check("a place copied off a 2D node claims no placement",
		str(flat_reading.get("pattern", "")), "") and ok
	ok = _check("and names no picture either",
		str(flat_reading.get("value_icon_class", "")), "") and ok
	# The slope row is the section's other placement sentence and takes no value picture.
	ok = _check("aligning to a slope names no class either",
		str(EventSheetSentence.statement(
			"crate.basis = Basis(Quaternion(Vector3.UP, ground_normal)) * crate.basis",
			context).get("value_icon_class", "")), "") and ok
	return ok


## Gate two: the sentence itself is exactly what it was - the extra fact is beside the words, not in
## them, and the muted note still says which kind of place it is.
static func _words_unmoved() -> bool:
	var ok: bool = true
	var context: Dictionary = _context()
	ok = _check("the marked place still reads the way it did",
		_joined(EventSheetSentence.statement("crate.global_position = spawn.global_position", context)),
		"crate ▸ Set position to spawn spawn point") and ok
	ok = _check("and the plain one too",
		_joined(EventSheetSentence.statement("crate.global_position = target.global_position", context)),
		"crate ▸ Set position to target another object") and ok
	ok = _check("the row still claims the placement pattern",
		str(EventSheetSentence.statement(
			"crate.global_position = spawn.global_position", context).get("pattern", "")),
		"placement") and ok
	ok = _check("with the line it read as its evidence",
		", ".join(EventSheetSentence.statement("crate.global_position = spawn.global_position",
			context).get("evidence", PackedStringArray())),
		"crate.global_position = spawn.global_position") and ok
	return ok


## Gate three: the picture is display only, so opening the file and saving it untouched puts back
## every byte. An icon that moved one byte of emitted GDScript would break every project.
static func _round_trip() -> bool:
	var handle: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	var output: String = str(SheetCompiler.compile(sheet, SOURCE_PATH).get("output", ""))
	return _check("opening the file and saving it reproduces every byte", output, SOURCE)


## The sentence context an opened 3D script hands the grammar.
static func _context() -> Dictionary:
	return {
		"self_object": "Level",
		"script_object": "Level",
		"self_class": "Node3D",
		"engine_properties": {"position": true, "global_position": true, "basis": true},
		"object_classes": {"crate": "Node3D", "spawn": "Marker3D", "target": "Node3D"}
	}


## "object ▸ sentence" for one reading, so a moved word fails loudly.
static func _joined(statement: Dictionary) -> String:
	var text: String = ""
	for segment: Variant in (statement.get("segments", []) as Array):
		text += str((segment as Dictionary).get("text", ""))
	var object_label: String = str(statement.get("object", ""))
	return "%s ▸ %s" % [object_label, text.strip_edges()] if not object_label.is_empty() \
		else text.strip_edges()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] marked_place_icon_test: %s" % label)
		return true
	print("[FAIL] marked_place_icon_test: %s - expected %s, got %s" % [label, expected, actual])
	return false
