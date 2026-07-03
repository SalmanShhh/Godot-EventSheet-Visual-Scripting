# EventForge — GDScript importer (structural round-trip)
#
# Imports GDScript into an EventSheetResource (extends host class, exported variables,
# functions with bodies preserved as RawCodeRow) and verifies a structural round-trip back
# through the compiler. ACE-level body parsing is future work. Headless-safe.
@tool
class_name ImporterTest
extends RefCounted

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

	all_passed = _check("host_class imported", sheet.host_class, "CharacterBody2D") and all_passed
	all_passed = _check("two variables imported", sheet.variables.size(), 2) and all_passed
	all_passed = _check("health type", str((sheet.variables.get("health", {}) as Dictionary).get("type", "")), "int") and all_passed
	all_passed = _check("health default (typed int)", (sheet.variables.get("health", {}) as Dictionary).get("default"), 100) and all_passed
	all_passed = _check("health is exported", bool((sheet.variables.get("health", {}) as Dictionary).get("exported", false)), true) and all_passed
	all_passed = _check("speed default (typed float)", (sheet.variables.get("speed", {}) as Dictionary).get("default"), 200.0) and all_passed
	all_passed = _check("two functions imported", sheet.functions.size(), 2) and all_passed
	all_passed = _check("first function name", (sheet.functions[0] as EventFunction).function_name, "_ready") and all_passed
	all_passed = _check("second function name", (sheet.functions[1] as EventFunction).function_name, "do_thing") and all_passed
	var do_thing: EventFunction = sheet.functions[1] as EventFunction
	all_passed = _check("function param parsed with type",
		do_thing.params.size() == 1 and (do_thing.params[0] as ACEParam).type_name == "int", true) and all_passed

	# Structural round-trip: compile the imported sheet and confirm the pieces survive.
	var compiled: String = str(SheetCompiler.compile(sheet, "user://eventforge_import_rt.gd").get("output", ""))
	all_passed = _check("round-trip: extends", compiled.contains("extends CharacterBody2D"), true) and all_passed
	all_passed = _check("round-trip: health var", compiled.contains("@export var health: int = 100"), true) and all_passed
	all_passed = _check("round-trip: speed var", compiled.contains("@export var speed: float = 200.0"), true) and all_passed
	all_passed = _check("round-trip: _ready func", compiled.contains("func _ready() -> void:"), true) and all_passed
	all_passed = _check("round-trip: body preserved", compiled.contains("\tprint(\"ready\")"), true) and all_passed
	all_passed = _check("round-trip: do_thing func", compiled.contains("func do_thing(amount: int) -> void:"), true) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] importer_test: %s" % label)
		return true
	print("[FAIL] importer_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
