# EventForge - GDScript importer (structural round-trip)
#
# Imports GDScript into an EventSheetResource (extends host class, exported variables,
# functions with bodies preserved as RawCodeRow) and verifies a structural round-trip back
# through the compiler. ACE-level body parsing is future work. Headless-safe.
@tool
class_name ImporterTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PREFIX := "importer_test"
const SOURCE_LINES: Array = [
	"extends CharacterBody2D",
	"",
	"@export var health: int = 100",
	"@export var speed: float = 200.0",
	"",
	"func _ready() -> void:",
	"\tprint(\"ready\")",
	"\thealth = 100",
	"",
	"func do_thing(amount: int) -> void:",
	"\thealth += amount",
]


static func run() -> bool:
	var all_passed: bool = true
	var source: String = "\n".join(PackedStringArray(SOURCE_LINES))
	var sheet: EventSheetResource = GDScriptImporter.new().import_source(source)

	var health: Dictionary = sheet.variables.get("health", {}) as Dictionary
	var speed: Dictionary = sheet.variables.get("speed", {}) as Dictionary
	var do_thing: EventFunction = sheet.functions[1] as EventFunction
	all_passed = SUPPORT.pins(PREFIX, [
		["host_class imported", sheet.host_class, "CharacterBody2D"],
		["two variables imported", sheet.variables.size(), 2],
		["health type", str(health.get("type", "")), "int"],
		["health default (typed int)", health.get("default"), 100],
		["health is exported", bool(health.get("exported", false)), true],
		["speed default (typed float)", speed.get("default"), 200.0],
		["two functions imported", sheet.functions.size(), 2],
		["first function name", (sheet.functions[0] as EventFunction).function_name, "_ready"],
		["second function name", do_thing.function_name, "do_thing"],
		["function param parsed with type",
			do_thing.params.size() == 1 and (do_thing.params[0] as ACEParam).type_name == "int", true],
	]) and all_passed

	# Structural round-trip: compile the imported sheet and confirm the pieces survive.
	var compiled: String = SUPPORT.compile_output(sheet, "user://eventforge_import_rt.gd")
	all_passed = SUPPORT.pins(PREFIX, [
		["round-trip: extends", compiled.contains("extends CharacterBody2D"), true],
		["round-trip: health var", compiled.contains("@export var health: int = 100"), true],
		["round-trip: speed var", compiled.contains("@export var speed: float = 200.0"), true],
		["round-trip: _ready func", compiled.contains("func _ready() -> void:"), true],
		["round-trip: body preserved", compiled.contains("\tprint(\"ready\")"), true],
		["round-trip: do_thing func", compiled.contains("func do_thing(amount: int) -> void:"), true],
	]) and all_passed

	return all_passed
