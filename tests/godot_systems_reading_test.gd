@tool
class_name GodotSystemsReadingTest
extends RefCounted

# Pins the four Godot-systems patterns batch eight reads - the shapes several lines of a script make
# together, each of which an event sheet already has rows for:
#
#   Loading a layout in the background: Load layout X in the background, X has finished
#        loading, and the progress the status array carries
#   The movement math a hand-rolled character body is built from, in the movement behaviors'
#        own words: Apply gravity, Accelerate toward, Limit speed, Move, the collision switches,
#        Set angle toward, Rotate toward
#   The high-level multiplayer messages: Send X to everyone / to the host / to a peer, Is host,
#        Owns this object, MyID
#   A navigation agent: Find path to, Move along path, Has arrived
#
# Three gates, in the order they matter:
#   1. the grammar's own values - one shape, one sentence, asserted literally;
#   2. the whole path - a hand-written file opened as a sheet, walked row by row, so a reading that
#      stops reaching the canvas is caught even when the grammar still answers on its own;
#   3. the promise every one of these rests on - the file still saves byte-identically, because all
#      of them are lenses over values the row already holds.
#
# The source lives here as a string rather than in tests/fixtures/ for the same reason its sibling
# reading tests' sources do: the lifter's byte gate compares against what the COMPILER would emit,
# and the compiler puts ONE blank line between functions, so a checked-in two-blank-line file could
# never lift and the fixture would silently test nothing.

const SOURCE_PATH := "user://eventforge_godot_systems_reading.gd"

const SOURCE: String = """extends CharacterBody2D

@export var gravity: float = 980.0
@export var speed: float = 200.0
@export var accel: float = 1200.0
@export var max_speed: float = 400.0
var path: String = "res://levels/level_2.tscn"
var dir: float = 0.0
var platform: PhysicsBody2D
var target_angle: float = 0.0
var hp: int = 100
var agent: NavigationAgent2D
var player: Node2D

@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: int) -> void:
	hp -= amount

func _ready() -> void:
	ResourceLoader.load_threaded_request("res://levels/level_2.tscn")
	set_collision_mask_value(2, false)
	add_collision_exception_with(platform)

func _process(_delta: float) -> void:
	var p: Array = []
	var st: int = ResourceLoader.load_threaded_get_status(path, p)
	if st == ResourceLoader.THREAD_LOAD_LOADED:
		get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(path))

func _physics_process(delta: float) -> void:
	velocity.y += gravity * delta
	velocity.x = move_toward(velocity.x, dir * speed, accel * delta)
	velocity = velocity.limit_length(max_speed)
	move_and_slide()
	agent.target_position = player.global_position
	var next: Vector2 = agent.get_next_path_position()
	velocity = global_position.direction_to(next) * speed
	agent.set_velocity(velocity)
	rotation = lerp_angle(rotation, target_angle, 5 * delta)

func aim(_delta: float) -> void:
	take_damage.rpc(10)
	take_damage.rpc_id(1, 10)
	hp = multiplayer.get_unique_id()
	if multiplayer.is_server():
		hp = 1
	if is_multiplayer_authority():
		hp = 2
	if agent.is_navigation_finished():
		hp = 3

func _on_agent_velocity_computed(safe: Vector2) -> void:
	velocity = safe
	move_and_slide()
"""

## Every reading the opened file must contain, one per shape this parcel claims.
##
## A line that LIFTED to one of the shipped rows reads through that row's own words, and a line that
## stayed verbatim reads through the grammar. Both are pinned here on purpose: the point of this
## parcel is that the two say the same sentence, so a rename on either side has to be made on both.
static var EXPECTED_READINGS: PackedStringArray = PackedStringArray([
	# The background-loading idiom
	"System ▸ layout Level 2 has finished loading",
	# The movement words, on a character body
	"System ▸ Apply Gravity Gravity (per second)",
	"System ▸ Accelerate x toward dir * Speed at Accel (per second)",
	"System ▸ Limit Speed to Max Speed",
	"System ▸ Move (and slide along what it hits)",
	# Re-pin: the named-layer verbs lift, so the line is now the ROW a picker would have authored.
	# The project never named layer 2, so the row says the number - which is all anyone can call it.
	"System ▸ Stop colliding with 2",
	"System ▸ Ignore collisions with platform",
	"System ▸ Rotate toward target angle at 5 (per second)",
	# The path words
	"System ▸ Has arrived",
	# The messages
	# A Send row belongs to the object whose function the message is (this file has no
	# class_name, so its object is what it extends), whether the row is the grammar's reading of a
	# typed line or the lifted Send action itself.
	"CharacterBody2D ▸ Send Take Damage to the host   amount = 10",
	"CharacterBody2D ▸ Send take damage to everyone 10",
	"Functions ▸ On message Take Damage",
	"Multiplayer ▸ Is host",
	"Multiplayer ▸ Owns this object"
])

## Readings the file must NOT contain: the words each shape replaced. A reading that silently stops
## firing would otherwise pass the list above by never being asked about.
static var FORBIDDEN_READINGS: PackedStringArray = PackedStringArray([
	"Player ▸ Set collision with layer \"Enemies\" off",
	"System ▸ Set velocity.y to velocity.y + gravity × delta"
])

## The condition readings the grammar must answer on its own, as "object ▸ sentence".
static var CONDITION_READINGS: Dictionary = {
	# The status enum, named by the layout rather than by the local it was read into
	"st == ResourceLoader.THREAD_LOAD_LOADED": "System ▸ layout Level 2 has finished loading",
	# What a slide collision hit
	"c.get_collider().is_in_group(\"enemy\")": "c ▸ collided object is in family enemy",
	# The two questions Godot's high-level multiplayer answers
	"multiplayer.is_server()": "Multiplayer ▸ Is host",
	"is_multiplayer_authority()": "Multiplayer ▸ Owns this object",
	# The arrival question, about the object that is walking
	"agent.is_navigation_finished()": "Player ▸ Has arrived"
}

## The statements whose sentence this parcel settles, as "object ▸ sentence".
static var STATEMENT_READINGS: Dictionary = {
	"ResourceLoader.load_threaded_request(\"res://levels/level_2.tscn\")":
		"System ▸ Load layout Level 2 in the background",
	"ResourceLoader.load_threaded_request(path)": "System ▸ Load layout Level 2 in the background",
	"get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(path))":
		"System ▸ Go to layout Level 2",
	"velocity.y += gravity * delta": "Player ▸ Apply gravity gravity (per second)",
	"velocity.x = move_toward(velocity.x, dir * speed, accel * delta)":
		"Player ▸ Accelerate x toward dir * speed at accel (per second)",
	"velocity = velocity.limit_length(max_speed)": "Player ▸ Limit speed to max_speed",
	"move_and_slide()": "Player ▸ Move (and slide along what it hits)",
	"set_collision_mask_value(2, false)": "Player ▸ Disable collisions with 2",
	"add_collision_exception_with(platform)": "Player ▸ Ignore collisions with platform",
	"look_at(player.global_position)": "Player ▸ Set angle toward player.global_position",
	"rotation = lerp_angle(rotation, target_angle, 5 * delta)":
		"Player ▸ Rotate toward target_angle at 5 (per second)",
	"take_damage.rpc(10)": "Player ▸ Send Take Damage to everyone   amount = 10",
	"take_damage.rpc_id(1, 10)": "Player ▸ Send Take Damage to the host   amount = 10",
	"take_damage.rpc_id(peer, 10)": "Player ▸ Send Take Damage to peer   amount = 10",
	"agent.target_position = player.global_position": "Player ▸ Find path to player",
	"velocity = global_position.direction_to(next) * speed":
		"Player ▸ Move along path at speed (avoiding others)"
}


static func run() -> bool:
	var ok: bool = true
	ok = _grammar_values() and ok
	var readings: PackedStringArray = _open_and_read()
	for expected: String in EXPECTED_READINGS:
		ok = _check("opened row reads \"%s\"" % expected, readings.has(expected), true) and ok
	for forbidden: String in FORBIDDEN_READINGS:
		ok = _check("no row still reads \"%s\"" % forbidden, readings.has(forbidden), false) and ok
	ok = _claims() and ok
	ok = _round_trip() and ok
	return ok


## Gate four: every pattern the file holds is CLAIMED on the event that owns it, with the source
## lines as evidence and the pack that could replace the shape. Everything downstream - the chip, the
## hover, Adopt behavior, the Doctor - reads these rather than looking at the file again.
static func _claims() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	EventSheetPatternFacts.clear(sheet)
	EventSheetViewportReadingRows.claim_godot_systems_patterns(sheet)
	# A claim belongs to ONE event, so a file with several events of the same pattern makes several
	# claims - which is the point, since the chip is drawn on each of them. The gates below therefore
	# ask what the SET of claims says rather than assuming one claim per pattern.
	var claimed: Dictionary = {}
	var adoptable: Dictionary = {}
	var evidence: Dictionary = {}
	for entry: Variant in EventSheetPatternFacts.claims(sheet):
		var claim: Dictionary = entry
		var pattern: String = str(claim.get("pattern", ""))
		claimed[pattern] = true
		var offers: PackedStringArray = adoptable.get(pattern, PackedStringArray())
		offers.append(str(claim.get("adoptable", "")))
		adoptable[pattern] = offers
		var lines: PackedStringArray = evidence.get(pattern, PackedStringArray())
		lines.append_array(claim.get("evidence", PackedStringArray()))
		evidence[pattern] = lines
	for pattern: String in ["background_loading", "movement", "multiplayer", "navigation"]:
		ok = _check("the file claims the %s pattern" % pattern, claimed.has(pattern), true) and ok
	ok = _check("a body that applies gravity offers the platformer behavior",
		(adoptable.get("movement", PackedStringArray()) as PackedStringArray).has("platformer_movement"),
		true) and ok
	ok = _check("a 2D navigation block offers the pathfinding behavior",
		(adoptable.get("navigation", PackedStringArray()) as PackedStringArray).has("platformer_pathfinding"),
		true) and ok
	ok = _check("background loading offers no behavior of its own",
		"".join(adoptable.get("background_loading", PackedStringArray()) as PackedStringArray), "") and ok
	var loading_lines: PackedStringArray = evidence.get("background_loading", PackedStringArray())
	ok = _check("the loading claim keeps what it saw as evidence",
		"\n".join(loading_lines).contains("LoadLayoutInBackground")
			or "\n".join(loading_lines).contains("load_threaded"), true) and ok
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] godot_systems_reading_test: %s" % label)
		return true
	print("[FAIL] godot_systems_reading_test: %s - expected %s, got %s" % [label, expected, actual])
	return false


## The sentence context an opened controller script hands the grammar, including the multi-line facts
## the reading rows gather once per rebuild.
static func _context() -> Dictionary:
	return {
		"self_object": "Player",
		"script_object": "Player",
		"self_class": "CharacterBody2D",
		"engine_properties": {"position": true, "rotation": true, "velocity": true,
			"global_position": true},
		"variable_types": {"hp": "int", "speed": "float", "dir": "float"},
		"loading_paths": {"path": "\"res://levels/level_2.tscn\""},
		"loading_progress": {"p": true},
		"loading_status": {"st": "path"},
		"message_names": {"take_damage": "Take Damage"},
		"message_params": {"take_damage": PackedStringArray(["amount"])},
		"nav_agents": {"agent": true},
		"nav_waypoints": {"next": true},
		"nav_avoidance": true
	}


## Gate one: the grammar answering on its own, value by value.
static func _grammar_values() -> bool:
	var ok: bool = true
	var context: Dictionary = _context()
	for expression: String in CONDITION_READINGS:
		var reading: Dictionary = EventSheetSentence.condition_pieces(expression, context)
		ok = _check("condition %s" % expression, _joined_pieces(reading),
			str(CONDITION_READINGS[expression])) and ok
	for code: String in STATEMENT_READINGS:
		var reading: Dictionary = EventSheetSentence.statement(code, context)
		ok = _check("statement %s" % code, _joined_segments(reading),
			str(STATEMENT_READINGS[code])) and ok
	# The progress array read by index, as the one expression an event sheet has for it.
	ok = _check("the progress array reads as the loading expression",
		EventSheetSentence.expression_text("p[0] * 100", context), "System.LoadingProgress * 100") and ok
	# The peer id, and the mode words an @rpc annotation carries.
	ok = _check("the peer id reads as the Multiplayer expression",
		EventSheetSentence.expression_text("multiplayer.get_unique_id()", context),
		"Multiplayer.MyID") and ok
	ok = _check("the annotation's modes read as the sheet's words",
		EventSheetMessageFacts.words("@rpc(\"any_peer\", \"call_local\", \"reliable\")"),
		"from anyone · also here · reliable") and ok
	ok = _check("an @rpc naming no mode says nothing",
		EventSheetMessageFacts.words("@rpc()"), "") and ok
	# The movement words are claimed on a BODY only. A plain node's velocity is a variable.
	var plain: Dictionary = _context()
	plain["self_class"] = "Node2D"
	plain["nav_agents"] = {}
	ok = _check("a plain node's vertical speed is not gravity",
		_joined_segments(EventSheetSentence.statement("velocity.y += gravity * delta", plain)),
		"Player ▸ Add gravity * dt to velocity.y") and ok
	# A step that is not scaled by the frame time is not one of these words.
	ok = _check("an unscaled vertical push is not gravity",
		_joined_segments(EventSheetSentence.statement("velocity.y += 10", context)),
		"Player ▸ Add 10 to velocity.y") and ok
	# Without the facts the file states, nothing claims a path.
	ok = _check("a nav step nothing declared an agent for keeps its code",
		_joined_segments(EventSheetSentence.statement("agent.target_position = player.global_position", plain)),
		"agent ▸ Set target_position to player.global_position") and ok
	return ok


## One condition reading as "object ▸ sentence", or the bare sentence when no object is named.
static func _joined_pieces(reading: Dictionary) -> String:
	var text: String = ""
	for piece: Variant in (reading.get("pieces", []) as Array):
		text += str((piece as Array)[0])
	var object_label: String = str(reading.get("object", ""))
	return "%s ▸ %s" % [object_label, text.strip_edges()] if not object_label.is_empty() else text.strip_edges()


## One statement reading as "object ▸ sentence".
static func _joined_segments(reading: Dictionary) -> String:
	var text: String = ""
	for segment: Variant in (reading.get("segments", []) as Array):
		text += str((segment as Dictionary).get("text", ""))
	var object_label: String = str(reading.get("object", ""))
	return "%s ▸ %s" % [object_label, text.strip_edges()] if not object_label.is_empty() else text.strip_edges()


## Writes the source, opens it as a sheet, and returns every cell reading - "object ▸ text" when the
## row names an object, the bare text otherwise.
static func _open_and_read() -> PackedStringArray:
	var handle: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	var readings: PackedStringArray = PackedStringArray()
	for row_data: EventRowData in _walk(viewport._root_rows, viewport):
		for span: SemanticSpan in row_data.spans:
			var object_label: String = str(span.metadata.get("object_label", ""))
			var text: String = span.text.strip_edges()
			readings.append("%s ▸ %s" % [object_label, text] if not object_label.is_empty() else text)
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


## The promise every reading here rests on: each one is a lens over a value the row already holds,
## so opening the file and saving it untouched puts back every byte.
static func _round_trip() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	var output: String = str(SheetCompiler.compile(sheet, SOURCE_PATH).get("output", ""))
	return _check("opening the file and saving it reproduces every byte", output, SOURCE)
