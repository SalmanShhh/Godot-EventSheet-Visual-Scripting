@tool
extends RefCounted

# The parameters window checks a field against the names its line can really use. Opening an action
# read out of a hand-written `_physics_process` - `velocity.x = move_toward(velocity.x, direction *
# speed, acceleration * delta)` - used to say "direction is not a variable of Player" and that `delta`
# would not compile, and kept Done shut on a line nobody had touched: the check knew the members but
# not the function's local or the value its trigger hands it. A typo is still caught.

const SUPPORT := preload("res://tests/support.gd")
const P := "params_window_scope_test"

const DIR := "user://params_window_scope_test"
const SOURCE := """class_name ScopePlayer
extends CharacterBody2D

@export var speed: float = 220.0
@export var acceleration: float = 1200.0


func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)


func hurt(amount: int) -> void:
	for spike in get_children():
		spike.queue_free()
"""


static func run() -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path: String = DIR + "/scope_player.gd"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(SOURCE)
	file.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	var names: PackedStringArray = EventSheetGDScriptLint.scope_names_of(sheet)
	# A field of a line inside hurt() knows hurt's names, not _physics_process's local.
	var hurt_event: EventRow = null
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction and (function_entry as EventFunction).function_name == "hurt":
			for entry: Variant in (function_entry as EventFunction).events:
				if entry is EventRow and hurt_event == null:
					hurt_event = entry as EventRow
	var in_hurt: PackedStringArray = EventSheetGDScriptLint.scope_names_of(sheet, hurt_event)
	return SUPPORT.pins(P, [
		["a field inside one function knows that function's names only", in_hurt,
			PackedStringArray(["amount", "spike"])],
		["so another function's local is a typo there", _ok("direction * speed", sheet, in_hurt), false],
		["the names a line can use besides the members", names,
			PackedStringArray(["amount", "delta", "direction", "spike"])],
		["the function's local is a name the field can use", _ok("direction * speed", sheet, names), true],
		["so is the value the tick hands it", _ok("acceleration * delta", sheet, names), true],
		["a typo is still caught", _ok("directoin * speed", sheet, names), false],
		["and a member alone needs no help", _ok("speed * 2.0", sheet, PackedStringArray()), true],
	])


static func _ok(expression: String, sheet: EventSheetResource, names: PackedStringArray) -> bool:
	return bool(EventSheetGDScriptLint.lint_expression(expression, sheet, names).get("ok", false))
