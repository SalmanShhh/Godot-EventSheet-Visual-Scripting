@tool
class_name ReadingNounsTest
extends RefCounted

# Pins the event-sheet NOUNS - the constants, the sprite and audio verbs, the collision family, the
# angles and distances, the counts, the system values, the familiar-words glossary and the node
# lookups (M38 - M47).
#
# Four gates, in the order they matter:
#   1. the grammar's own values - one shape, one sentence, asserted literally;
#   2. the whole path - a hand-written file opened as a sheet, walked row by row, so a reading that
#      stops reaching the canvas is caught even when the grammar still answers on its own;
#   3. the View toggle - off by default, and each of its words only while it is on;
#   4. the two promises the reading rests on - the file still saves byte-identically, and a row built
#      from the PICKER reads exactly what the same shape typed by hand reads.
#
# The source lives here as a string rather than in tests/fixtures/ because the lifter's byte gate
# compares against what the COMPILER would emit, and the compiler puts ONE blank line between
# functions, so a checked-in two-blank-line file could never lift and the fixture would test nothing.

const SOURCE_PATH := "user://eventforge_reading_nouns.gd"

const SOURCE: String = """class_name ReadingNounsPlayer
extends CharacterBody2D

enum State { PATROL, CHASE }

var state: int = State.PATROL
var dir: Vector2 = Vector2.ZERO
var reading: float = 0.0
var items: Array = []
var hp: int = 3

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var sfx: AudioStreamPlayer = $Sfx
@onready var hud: CanvasLayer = $HUD
@onready var boss: Node2D = $Enemies/Boss
@onready var score: Label = get_node_or_null("HUD/Score")

func _ready() -> void:
	state = State.CHASE
	dir = Vector2.UP
	modulate = Color.RED
	reading = PI / 2
	sprite.play("run")
	sprite.stop()
	sfx.play()
	visible = false
	modulate.a = 0.5
	sprite.flip_h = true
	scale = Vector2(2, 2)
	rotation_degrees = 90
	look_at(boss.global_position)
	reading = global_position.distance_to(boss)
	reading = velocity.length()
	dir = dir.normalized()
	hp = get_tree().get_nodes_in_group("enemies").size()
	reading = get_viewport_rect().size.x
	dir = get_global_mouse_position()
	reading = Time.get_ticks_msec() / 1000.0
	reading = Engine.get_frames_per_second()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
	hud.visible = false
	get_node("Enemies/Boss").hp -= 10
	boss.set("hp", 3)
	hp = boss.get("hp")

func _physics_process(_delta: float) -> void:
	if is_on_wall():
		hp += 1
	if velocity.y < 0:
		hp += 1
	if items.is_empty():
		hp = 0
	if get_tree().get_nodes_in_group("enemies").size() == 0:
		hp = 2
	if boss.get("hp") > 0:
		hp = 3
	if hud.overlaps_body(boss):
		hp = 4
"""

## Every reading the opened file must contain, one per shape M38 - M47 claims.
static var EXPECTED_READINGS: PackedStringArray = PackedStringArray([
	# M38 - constants have no namespace, and the ones with a symbol wear it
	"System ▸ Set state to CHASE",
	"System ▸ Set dir to up",
	"System ▸ Set reading to π / 2",
	# M40 - the sprite / audio / visibility verbs, by the object's own class
	"sprite ▸ Set animation to \"run\" (play)",
	"sprite ▸ Stop animation",
	"Audio ▸ Play",
	"sprite ▸ Set mirrored",
	"ReadingNounsPlayer ▸ Set invisible",
	"ReadingNounsPlayer ▸ Set opacity to 50%",
	"ReadingNounsPlayer ▸ Set size to 200%",
	# M43 - angles, distances and directions
	"ReadingNounsPlayer ▸ Set angle to 90",
	"System ▸ Set reading to distance to boss",
	"System ▸ Set reading to length of velocity",
	"System ▸ Set dir to dir, normalized",
	# M44 - counting
	"System ▸ Set hp to enemies (group) count",
	# M45 - the system values
	"System ▸ Set reading to ViewportWidth",
	"Mouse ▸ Set dir to mouse position",
	"System ▸ Set reading to time",
	"System ▸ Set reading to fps",
	# R8 - the layout words are the action's own name, so they are on whatever the glossary says
	"System ▸ Go to layout Menu",
	# M47 - a node lookup IS the object it names, and an "or null" one says it may not be there
	"Boss ▸ Subtract 10 from hp",
	"$HUD/Score",
	"may be missing",
	"boss ▸ Set hp to 3",
	# M41 - the collision family and the platform words
	"ReadingNounsPlayer ▸ Is by wall",
	"ReadingNounsPlayer ▸ Is jumping",
	"hud ▸ Is overlapping boss",
	"enemies (group) ▸ count == 0",
	"boss ▸ hp > 0"
])

## The grammar's own context for an opened CharacterBody2D script with these objects on it.
const CONTEXT: Dictionary = {
	"self_object": "System",
	"script_object": "Player",
	"self_class": "CharacterBody2D",
	"object_classes": {
		"Player": "CharacterBody2D",
		"sprite": "AnimatedSprite2D",
		"anim": "AnimationPlayer",
		"sfx": "AudioStreamPlayer",
		"hud": "CanvasLayer",
		"boss": "Node2D"
	},
	"enum_names": {"State": true},
	"enum_members": {"PATROL": 1, "CHASE": 1},
	"engine_properties": {
		"position": true, "global_position": true, "rotation": true, "rotation_degrees": true,
		"velocity": true, "visible": true, "modulate": true, "scale": true
	}
}


static func run() -> bool:
	var ok: bool = true
	ok = _constant_values() and ok
	ok = _verb_values() and ok
	ok = _measurement_values() and ok
	ok = _condition_values() and ok
	ok = _familiar_words() and ok
	ok = _opened_file_reads() and ok
	ok = _toggle_defaults_off() and ok
	ok = _round_trip() and ok
	ok = _picked_matches_typed() and ok
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] reading_nouns_test: %s" % label)
		return true
	print("[FAIL] reading_nouns_test: %s - expected %s, got %s" % [label, expected, actual])
	return false


static func _joined(result: Dictionary) -> String:
	var text: String = ""
	for segment: Variant in (result.get("segments", []) as Array):
		text += str((segment as Dictionary).get("text", ""))
	return text


static func _labelled(result: Dictionary) -> String:
	if result.is_empty():
		return ""
	var object_name: String = str(result.get("object", ""))
	return _joined(result) if object_name.is_empty() else "%s ▸ %s" % [object_name, _joined(result)]


static func _read(code: String, context: Dictionary = CONTEXT) -> String:
	return _labelled(EventSheetSentence.statement(code, context))


static func _read_condition(expression: String, context: Dictionary = CONTEXT) -> String:
	return _labelled(EventSheetSentence.condition(expression, context))


## M38 - enum members, vector / colour constants, and the symbols.
static func _constant_values() -> bool:
	var ok: bool = true
	for pair: Array in [
		["state = State.CHASE", "System ▸ Set state to CHASE"],
		["dir = Vector2.UP", "System ▸ Set dir to up"],
		["velocity = Vector2.ZERO", "Player ▸ Set velocity to (0, 0)"],
		["dir = Vector3.ZERO", "System ▸ Set dir to (0, 0, 0)"],
		["dir = Vector3.FORWARD", "System ▸ Set dir to forward"],
		["dir = Vector2.ONE", "System ▸ Set dir to (1, 1)"],
		["modulate = Color.RED", "Player ▸ Set modulate to red"],
		["reading = PI / 2", "System ▸ Set reading to π / 2"],
		["reading = TAU", "System ▸ Set reading to τ"],
		["reading = INF", "System ▸ Set reading to ∞"],
		["reading = NAN", "System ▸ Set reading to NAN"],
		# An enum member that two enums share keeps its enum, because the name alone stops saying which
		["state = Facing.LEFT", "System ▸ Set state to Facing.LEFT"]
	]:
		ok = _check("\"%s\" reads \"%s\"" % [str(pair[0]), str(pair[1])], _read(str(pair[0])), str(pair[1])) and ok
	# The uniqueness rule itself: the same line reads differently on a sheet where the member is shared.
	var shared: Dictionary = CONTEXT.duplicate(true)
	shared["enum_names"] = {"State": true, "Facing": true}
	shared["enum_members"] = {"PATROL": 1, "CHASE": 2}
	ok = _check("a member two enums share keeps its enum name",
		_read("state = State.CHASE", shared), "System ▸ Set state to State.CHASE") and ok
	ok = _check("a constant inside a string literal is content, never a constant",
		EventSheetSentence.constant_words("\"Vector2.ZERO\" & PI", CONTEXT), "\"Vector2.ZERO\" & π") and ok
	return ok


## M40 / M47 - the verbs an event sheet writes instead of a property write or a call.
static func _verb_values() -> bool:
	var ok: bool = true
	for pair: Array in [
		["sprite.play(\"run\")", "sprite ▸ Set animation to \"run\" (play)"],
		["sprite.stop()", "sprite ▸ Stop animation"],
		["sfx.play()", "Audio ▸ Play"],
		["sfx.stop()", "Audio ▸ Stop"],
		["visible = false", "Player ▸ Set invisible"],
		["sprite.visible = true", "sprite ▸ Set visible"],
		["hide()", "Player ▸ Set invisible"],
		["show()", "Player ▸ Set visible"],
		["modulate.a = 0.5", "Player ▸ Set opacity to 50%"],
		["sprite.flip_h = true", "sprite ▸ Set mirrored"],
		["sprite.flip_h = false", "sprite ▸ Set not mirrored"],
		["sprite.flip_v = true", "sprite ▸ Set flipped"],
		["scale = Vector2(2, 2)", "Player ▸ Set size to 200%"],
		# A non-uniform scale is two numbers, and one percentage would hide one of them
		["scale = Vector2(2, 1)", "Player ▸ Set scale to (2, 1)"],
		# M47 - a property set and read by name
		["boss.set(\"hp\", 3)", "boss ▸ Set hp to 3"],
		["hp = boss.get(\"hp\")", "System ▸ Set hp to boss's hp"],
		["get_node(\"Enemies/Boss\").hp -= 10", "Boss ▸ Subtract 10 from hp"],
		["get_node_or_null(\"HUD/Score\").text = \"0\"", "Score ▸ Set text to \"0\""],
		# An unknown class keeps the plain call reading: `play` means two things and only a class says which
		["mystery.play(\"run\")", ""]
	]:
		ok = _check("\"%s\" reads \"%s\"" % [str(pair[0]), str(pair[1])], _read(str(pair[0])), str(pair[1])) and ok
	return ok


## M43 / M44 / M45 - angles, distances, counts and the system values.
static func _measurement_values() -> bool:
	var ok: bool = true
	for pair: Array in [
		["rotation_degrees = 90", "Player ▸ Set angle to 90"],
		["rotation = 1.5", "Player ▸ Set angle (radians) to 1.5"],
		["look_at(boss.global_position)", "Player ▸ Set angle toward boss.global_position"],
		["reading = global_position.distance_to(boss)", "System ▸ Set reading to distance to boss"],
		["reading = a.distance_to(b)", "System ▸ Set reading to distance from a to b"],
		["reading = position.angle_to_point(p)", "System ▸ Set reading to angle to p"],
		["reading = velocity.length()", "System ▸ Set reading to length of velocity"],
		["dir = dir.normalized()", "System ▸ Set dir to dir, normalized"],
		["reading = dir.dot(velocity)", "System ▸ Set reading to dir · velocity"],
		["hp = get_tree().get_nodes_in_group(\"enemies\").size()", "System ▸ Set hp to enemies (group) count"],
		# The name lens spells the property as words on the canvas; the grammar keeps the member it read.
		["hp = get_child_count()", "System ▸ Set hp to child_count"],
		# R11 renamed these two to the sheet's own expression names, which a reader TYPES.
		["reading = get_viewport_rect().size.x", "System ▸ Set reading to ViewportWidth"],
		["reading = get_viewport_rect().size.y", "System ▸ Set reading to ViewportHeight"],
		["dir = get_viewport().get_mouse_position()", "Mouse ▸ Set dir to mouse position"],
		["dir = get_global_mouse_position()", "Mouse ▸ Set dir to mouse position"],
		["reading = Time.get_ticks_msec() / 1000.0", "System ▸ Set reading to time"],
		# R5 - writing the clock into a variable is the sheet's "Set ... to now".
		["reading = Time.get_ticks_msec()", "System ▸ Set reading to now"],
		["reading = Engine.get_frames_per_second()", "System ▸ Set reading to fps"]
	]:
		ok = _check("\"%s\" reads \"%s\"" % [str(pair[0]), str(pair[1])], _read(str(pair[0])), str(pair[1])) and ok
	return ok


## M41 / M44 / M47 in the condition lane.
static func _condition_values() -> bool:
	var ok: bool = true
	for pair: Array in [
		["is_on_wall()", "Player ▸ Is by wall"],
		["is_on_floor()", "Player ▸ Is on floor"],
		["is_on_ceiling()", "Player ▸ Is touching ceiling"],
		["velocity.y < 0", "Player ▸ Is jumping"],
		["velocity.y > 0", "Player ▸ Is falling"],
		["hud.overlaps_body(boss)", "hud ▸ Is overlapping boss"],
		["hud.overlaps_area(boss)", "hud ▸ Is overlapping boss"],
		["hud.has_overlapping_bodies()", "hud ▸ Is overlapping something"],
		["items.is_empty()", "items' count = 0"],
		["get_tree().get_nodes_in_group(\"enemies\").size() == 0", "enemies (group) ▸ count == 0"],
		["get_child_count() > 5", "Player ▸ child count > 5"],
		["boss.get(\"hp\") > 0", "boss ▸ hp > 0"]
	]:
		ok = _check("condition \"%s\" reads \"%s\"" % [str(pair[0]), str(pair[1])],
			_read_condition(str(pair[0])), str(pair[1])) and ok
	# M41/R10 - the vertical words follow the AXIS, not the sign: in 3D, where Y grows upward, the
	# very same test means the opposite, and the reading says the opposite word.
	var in_3d: Dictionary = CONTEXT.duplicate(true)
	in_3d["self_class"] = "CharacterBody3D"
	(in_3d["object_classes"] as Dictionary)["Player"] = "CharacterBody3D"
	ok = _check("a 3D body sinking reads as falling",
		_read_condition("velocity.y < 0", in_3d), "Player ▸ Is falling") and ok
	ok = _check("a 3D body rising reads as jumping",
		_read_condition("velocity.y > 0", in_3d), "Player ▸ Is jumping") and ok
	# M44 - the non-empty twin, which reads as the count rather than as a NOT mark
	var pieces: Array = (EventSheetSentence.condition_pieces("not items.is_empty()", CONTEXT).get("pieces", []) as Array)
	var joined: String = ""
	for piece: Variant in pieces:
		joined += str((piece as Array)[0])
	ok = _check("\"not items.is_empty()\" reads as the count it asks about", joined, "items' count > 0") and ok
	return ok


## M46 - the glossary: nothing changes with it off, and each word only appears with it on.
static func _familiar_words() -> bool:
	var ok: bool = true
	var familiar: Dictionary = CONTEXT.duplicate(true)
	familiar["familiar_words"] = true
	# R8 moved the scene-flow words OUT of the glossary: they are the shipped rows' own action names,
	# so they read the same either way, and only the layer noun is still a glossary word.
	for entry: Array in [
		["get_tree().change_scene_to_file(\"res://scenes/menu.tscn\")",
			"System ▸ Go to layout Menu", "System ▸ Go to layout Menu"],
		["get_tree().reload_current_scene()", "System ▸ Restart layout", "System ▸ Restart layout"],
		["get_tree().paused = true", "System ▸ Pause the game", "System ▸ Pause the game"],
		["get_tree().paused = false", "System ▸ Unpause", "System ▸ Unpause"],
		["Engine.time_scale = 0.5", "System ▸ Set time scale to 0.5", "System ▸ Set time scale to 0.5"],
		["get_tree().quit()", "System ▸ Quit game", "System ▸ Quit game"],
		["hud.visible = false", "hud ▸ Set invisible", "hud (layer) ▸ Set layer invisible"]
	]:
		ok = _check("with the glossary off \"%s\" reads \"%s\"" % [str(entry[0]), str(entry[1])],
			_read(str(entry[0])), str(entry[1])) and ok
		ok = _check("with the glossary on \"%s\" reads \"%s\"" % [str(entry[0]), str(entry[2])],
			_read(str(entry[0]), familiar), str(entry[2])) and ok
	return ok


## The whole path: the file opened as a sheet, every row read off the canvas's own spans.
static func _opened_file_reads() -> bool:
	var ok: bool = true
	var readings: PackedStringArray = _render(_import())
	for expected: String in EXPECTED_READINGS:
		ok = _check("opened row reads \"%s\"" % expected, readings.has(expected), true) and ok
	return ok


## M46 - the toggle is off unless somebody asks for it, and turning it on changes exactly its words.
static func _toggle_defaults_off() -> bool:
	var ok: bool = true
	var plain: EventSheetViewport = EventSheetViewport.new()
	ok = _check("the familiar-words glossary is off by default", plain.familiar_words_enabled(), false) and ok
	plain.free()
	var readings: PackedStringArray = _render(_import(), true)
	for expected: String in [
		"System ▸ Go to layout Menu",
		"hud (layer) ▸ Set layer invisible"
	]:
		ok = _check("with the glossary on the opened row reads \"%s\"" % expected, readings.has(expected), true) and ok
	ok = _check("the Godot scene wording is gone",
		readings.has("System ▸ Go to scene \"res://scenes/menu.tscn\""), false) and ok
	return ok


static func _import() -> EventSheetResource:
	var handle: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()
	return GDScriptImporter.new().import_external(SOURCE_PATH)


## The readings of one sheet, straight off the canvas's own spans.
static func _render(sheet: EventSheetResource, familiar_words: bool = false) -> PackedStringArray:
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	# Set BEFORE the sheet: the words are baked into span text at build time, which is exactly why
	# the dock's toggle re-sets the sheet rather than queueing a redraw.
	viewport.familiar_words = familiar_words
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	var readings: PackedStringArray = PackedStringArray()
	for row_data: EventRowData in _walk(viewport._root_rows, viewport):
		for span: SemanticSpan in row_data.spans:
			var label: String = str(span.metadata.get("object_label", ""))
			var text: String = span.text.strip_edges()
			readings.append("%s ▸ %s" % [label, text] if not label.is_empty() else text)
	viewport.free()
	return readings


## Every row in the tree, parents before children.
static func _walk(rows: Array, viewport: EventSheetViewport) -> Array:
	var found: Array = []
	for row_data: EventRowData in rows:
		viewport._row_builder._ensure_event_spans(row_data)
		found.append(row_data)
		found.append_array(_walk(row_data.children, viewport))
	return found


## A reading may never cost a byte: opening the file and saving it untouched reproduces it exactly.
static func _round_trip() -> bool:
	var sheet: EventSheetResource = _import()
	var output: String = str(SheetCompiler.compile(sheet, SOURCE_PATH).get("output", ""))
	return _check("opening the file and saving it reproduces every byte", output, SOURCE)


## The parity promise: a row dropped from the PICKER reads exactly what the same shape typed by hand
## reads - the whole point of the shapes routing through one grammar.
static func _picked_matches_typed() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "ReadingNounsPlayer"
	sheet.host_class = "CharacterBody2D"
	sheet.events.append(_onready_object("sprite", "AnimatedSprite2D", "$Sprite"))
	sheet.events.append(_onready_object("sfx", "AudioStreamPlayer", "$Sfx"))
	var event_row: EventRow = EventRow.new()
	event_row.trigger_id = "OnReady"
	event_row.actions.append(_action("PlaySpriteAnimation", {"target": "sprite", "anim": "\"run\""}))
	event_row.actions.append(_action("StopSpriteAnimation", {"target": "sprite"}))
	event_row.actions.append(_action("AudioPlay", {"target": "sfx", "from": "0.0"}))
	event_row.actions.append(_action("SetFlipH", {"target": "sprite", "flipped": "true"}))
	event_row.actions.append(_action("HideNode", {}))
	event_row.actions.append(_action("SetRotationDeg", {"degrees": "90"}))
	event_row.actions.append(_action("SubtractFromProperty", {
		"target": "get_node(\"Enemies/Boss\")", "property": "hp", "value": "10"}))
	sheet.events.append(event_row)
	var readings: PackedStringArray = _render(sheet)
	for expected: String in [
		"sprite ▸ Set animation to \"run\" (play)",
		"sprite ▸ Stop animation",
		"Audio ▸ Play",
		"sprite ▸ Set mirrored",
		"ReadingNounsPlayer ▸ Set invisible",
		"ReadingNounsPlayer ▸ Set angle to 90",
		"Boss ▸ Subtract 10 from hp"
	]:
		ok = _check("picked row reads \"%s\"" % expected, readings.has(expected), true) and ok
	return ok


static func _onready_object(variable_name: String, type_name: String, value: String) -> LocalVariable:
	var variable: LocalVariable = LocalVariable.new()
	variable.name = variable_name
	variable.type_name = type_name
	variable.default_value = value
	variable.onready = true
	return variable


static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	return action
