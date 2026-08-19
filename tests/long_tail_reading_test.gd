@tool
class_name LongTailReadingTest
extends RefCounted

# Pins the long tail of reading batch ten gave the sheet's own words to:
#
#   U6   HTTPRequest and JSON read as the AJAX and JSON objects - Request / Post / request succeeded
#        / AJAX.LastData / JSON.Parse / JSON.ToString, and a run of indexes as one possessive address
#   U7   a light's knobs read as the Light rows - light energy as a percentage, light colour, the
#        on-off pair, shadows - plus the layer tint and the world's ambient light under System
#   U8   the 3D words - Look at, and an object's own forward / right / up
#   U9   threads read as Run <verb> in the background / Wait for it to finish, claimed as one pattern
#        with the behavior that could replace the shape
#   U10  the signal steps that are ACTIONS - Wire / Unwire, the at-end-of-frame chip, a signal held
#        in a variable and fired by name, and the wired-up question
#   U11  a call made by name, and a callable held in a value
#   U12  a video player is the Video object, and how far a sound carries is a hearing distance
#
# Four gates, in the order they matter:
#   1. the grammar's own values - one shape, one sentence, asserted literally;
#   2. the whole path - a hand-written file opened as a sheet, walked row by row;
#   3. the pattern registry - each new shape claimed on the event that owns it;
#   4. the promise all of them rest on - the file still saves byte-identically.
#
# The source lives here as a string rather than in tests/fixtures/ for the same reason its sibling
# reading tests' sources do: the lifter's byte gate compares against what the COMPILER would emit,
# and the compiler puts ONE blank line between functions.

const SOURCE_PATH := "user://eventforge_long_tail_reading.gd"

const SOURCE: String = """extends Node3D

@onready var http: HTTPRequest = $HTTPRequest
@onready var lamp: PointLight2D = $PointLight2D
@onready var film: VideoStreamPlayer = $VideoStreamPlayer
@onready var horn: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var cam: Camera3D = $Camera3D
@onready var music_a: AudioStreamPlayer = $MusicA
@onready var music_b: AudioStreamPlayer = $MusicB
var last_data := ""

func load_scores() -> void:
	http.request("https://example.com/scores")

func light_the_level() -> void:
	lamp.energy = 0.5
	lamp.enabled = false
	lamp.shadow_enabled = true

func set_the_scene() -> void:
	horn.max_distance = 600
	horn.attenuation = 2.0
	film.play()

func turn_the_head(relative: Vector2) -> void:
	rotate_y(-relative.x * 0.002)
	cam.rotate_x(-relative.y * 0.002)
	cam.rotation.x = clamp(cam.rotation.x, -1.2, 1.2)

func fade_the_music(t: float) -> void:
	music_a.volume_db = linear_to_db(1.0 - t)
	music_b.volume_db = linear_to_db(t)

func bake_the_level() -> void:
	WorkerThreadPool.add_task(chunk_of.bind(1))
	WorkerThreadPool.wait_for_task_completion(1)

func chunk_of(index: int) -> void:
	last_data = str(index)
"""

## Every reading the opened file must contain, one per shape these items claim.
static var EXPECTED_READINGS: PackedStringArray = PackedStringArray([
	"AJAX ▸ Request \"https://example.com/scores\"",
	"lamp ▸ Set light energy to 50%",
	"lamp ▸ Set shadows on",
	"horn ▸ Set hearing distance to 600",
	"horn ▸ Set falloff to 2",
	"Video ▸ Play",
	"System ▸ Run Chunk Of in the background   index = 1",
	"System ▸ ⏳ Wait for it to finish",
	# U8 / U12 - the two runs whose lines only mean anything together, each ONE row. The look belongs
	# to the script's own object, which this file names by the class it extends.
	"Node3D ▸ Mouse look",
	"System ▸ Crossfade music a → music b by t"
])

## Readings the file must NOT contain: the words each shape replaced. A reading that silently stopped
## firing would otherwise pass the list above by never being asked about.
static var FORBIDDEN_READINGS: PackedStringArray = PackedStringArray([
	"lamp ▸ Set energy to 0.5",
	"lamp ▸ Set enabled to false",
	"horn ▸ Set max_distance to 600",
	# The two faders the crossfade run swallowed: each was a perfectly good volume row on its own,
	# and a run that stopped firing would leave them behind.
	"music_a ▸ Set volume to 1 - t (0 to 1)",
	"music_b ▸ Set volume to t (0 to 1)"
])

## The statements whose sentence these items settle, as "object ▸ sentence".
static var STATEMENT_READINGS: Dictionary = {
	# U6 - a request, and the same call carrying the POST verb and a body
	"http.request(\"https://example.com/scores\")": "AJAX ▸ Request \"https://example.com/scores\"",
	"http.request(\"https://example.com/post\", [], HTTPClient.METHOD_POST, payload)":
		"AJAX ▸ Post payload to \"https://example.com/post\"",
	# U7 - the light knobs, the layer tint and the world's ambient light
	"lamp.energy = 0.5": "lamp ▸ Set light energy to 50%",
	"sun.light_energy = 2.0": "sun ▸ Set light energy to 200%",
	"lamp.enabled = false": "lamp ▸ Set light off",
	"lamp.enabled = true": "lamp ▸ Set light on",
	"lamp.shadow_enabled = true": "lamp ▸ Set shadows on",
	"lamp.shadow_enabled = false": "lamp ▸ Set shadows off",
	"tint.color = Color(0.2, 0.2, 0.4)": "System ▸ Set layer tint to Color(0.2, 0.2, 0.4) CanvasModulate",
	"$WorldEnvironment.environment.ambient_light_energy = 0.3": "System ▸ Set ambient light to 30%",
	# U8 - facing something
	"look_at(target.global_position, Vector3.UP)": "Player ▸ Look at target",
	# U9 - work handed off the main thread, and the wait that joins it back up
	"thread.start(bake.bind(level))": "System ▸ Run Bake in the background   level = level",
	"thread.wait_to_finish()": "System ▸ ⏳ Wait for it to finish",
	"WorkerThreadPool.add_task(chunk.bind(index))": "System ▸ Run Chunk in the background   index = index",
	"WorkerThreadPool.add_group_task(row, 64)": "System ▸ Run Row in the background 64 times",
	"WorkerThreadPool.wait_for_group_task_completion(id)": "System ▸ ⏳ Wait for it to finish",
	# U10 - the signal steps that act
	"died.disconnect(on_died)": "Player ▸ Unwire On Died from On Died",
	"sig.emit(10)": "System ▸ Fire sig   10",
	# U11 - a call made by name
	"call(\"heal\", 5)": "Functions ▸ Call Heal   amount = 5 by name",
	"callv(\"heal\", [5, self])":
		"Functions ▸ Call Heal   amount = 5   source = self by name, with a list",
	# U12 - the Video object, and how far a sound carries
	"film.stream = load(\"res://intro.ogv\")": "Video ▸ Set video to intro.ogv",
	"film.play()": "Video ▸ Play",
	"film.pause()": "Video ▸ Pause",
	"horn.max_distance = 600": "horn ▸ Set hearing distance to 600",
	"horn.attenuation = 2.0": "horn ▸ Set falloff to 2"
}

## The questions these items settle, as "object ▸ sentence". The inverted spelling of the request
## question is the one every handler writes, and it reads as the same words with the badge's word.
static var CONDITION_READINGS: Dictionary = {
	"result == HTTPRequest.RESULT_SUCCESS": "AJAX ▸ request succeeded",
	"result != HTTPRequest.RESULT_SUCCESS": "AJAX ▸ not request succeeded",
	"died.is_connected(on_died)": "Player ▸ On Died is wired to On Died",
	"film.is_playing()": "Video ▸ Is playing"
}

## The values these items name, and what the sheet calls them.
static var EXPRESSION_READINGS: Dictionary = {
	"body.get_string_from_utf8()": "AJAX.LastData",
	"JSON.parse_string(last_data)": "JSON.Parse(last_data)",
	"JSON.stringify(payload)": "JSON.ToString(payload)",
	"data[\"scores\"][0][\"name\"]": "data's scores 0 name",
	"-global_transform.basis.z": "Player's forward",
	"global_transform.basis.x": "Player's right",
	"cam.global_transform.basis.y": "cam's up",
	"Callable(self, \"heal\")": "the function Heal",
	# M31's single index is untouched: one index already had a sentence, and a run is a different one.
	"inventory[\"potion\"]": "inventory's \"potion\""
}

## The shapes that must NOT be claimed: a start on something that is not work, a request whose verb
## is not post, a signal variable the sheet never typed, and a name worked out at run time. A reading
## that is ALMOST right is worse than the code it replaced.
static var REFUSED_STATEMENTS: PackedStringArray = PackedStringArray([
	"clock.start(5.0)",
	"http.request(url, [], HTTPClient.METHOD_PUT, payload)",
	"other.emit(10)",
	"call(name_of_it, 5)"
])


static func run() -> bool:
	var ok: bool = true
	ok = _grammar_values() and ok
	var opened: Dictionary = _open_and_read()
	var readings: PackedStringArray = opened.get("readings", PackedStringArray())
	for expected: String in EXPECTED_READINGS:
		ok = _check("opened row reads \"%s\"" % expected, readings.has(expected), true) and ok
	for forbidden: String in FORBIDDEN_READINGS:
		ok = _check("no row still reads \"%s\"" % forbidden, readings.has(forbidden), false) and ok
	ok = _pattern_claims(opened.get("patterns", {})) and ok
	ok = _round_trip() and ok
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] long_tail_reading_test: %s" % label)
		return true
	print("[FAIL] long_tail_reading_test: %s - expected %s, got %s" % [label, expected, actual])
	return false


## The sentence context an opened 3D script hands the grammar: what the script is, what its object
## variables are, which of its variables holds a signal, and what its functions take.
static func _context() -> Dictionary:
	return {
		"self_object": "Player",
		"script_object": "Player",
		"self_class": "Node3D",
		"object_classes": {
			"http": "HTTPRequest", "lamp": "PointLight2D", "sun": "DirectionalLight3D",
			"tint": "CanvasModulate", "film": "VideoStreamPlayer", "horn": "AudioStreamPlayer2D",
			"cam": "Camera3D", "target": "Node3D"
		},
		"engine_properties": {"position": true, "global_position": true},
		"variable_types": {"sig": "Signal"},
		"function_params": {
			"bake": PackedStringArray(["level"]),
			"chunk": PackedStringArray(["index"]),
			"heal": PackedStringArray(["amount", "source"])
		}
	}


## Gate one: the grammar answering on its own, value by value.
static func _grammar_values() -> bool:
	var ok: bool = true
	var context: Dictionary = _context()
	for code: String in STATEMENT_READINGS:
		ok = _check("statement %s" % code, _joined_segments(EventSheetSentence.statement(code, context)),
			str(STATEMENT_READINGS[code])) and ok
	for expression: String in CONDITION_READINGS:
		ok = _check("condition %s" % expression,
			_joined_pieces(EventSheetSentence.condition_pieces(expression, context)),
			str(CONDITION_READINGS[expression])) and ok
	for value: String in EXPRESSION_READINGS:
		ok = _check("expression %s" % value, EventSheetSentence.expression_text(value, context),
			str(EXPRESSION_READINGS[value])) and ok
	for refused: String in REFUSED_STATEMENTS:
		ok = _check("refused %s" % refused,
			EventSheetSentence.statement(refused, context).has("pattern"), false) and ok
	# The pattern each reading carries, which is the only thing the registry is filled from.
	ok = _check("a request row claims the web pattern",
		str(EventSheetSentence.statement("http.request(url)", context).get("pattern", "")), "ajax") and ok
	ok = _check("a light row claims the lighting pattern",
		str(EventSheetSentence.statement("lamp.enabled = false", context).get("pattern", "")),
		"lighting") and ok
	ok = _check("a face-that row claims the first-person pattern",
		str(EventSheetSentence.statement("look_at(target.global_position, Vector3.UP)", context)
			.get("pattern", "")), "fps_look") and ok
	ok = _check("a threaded row claims the background pattern",
		str(EventSheetSentence.statement("thread.wait_to_finish()", context).get("pattern", "")),
		"background") and ok
	ok = _check("the background pattern offers the behavior that does the whole shape",
		str(EventSheetSentence.statement("thread.wait_to_finish()", context).get("adoptable", "")),
		"background_runner") and ok
	# U10 - the flag whose whole meaning is WHEN the handler runs says so, as a chip.
	ok = _check("a deferred connection says when the handler runs",
		_joined_segments(EventSheetSentence.statement("died.connect(on_died, CONNECT_DEFERRED)", context)),
		"Player ▸ Wire On Died to On Died   at end of frame") and ok
	# U10 - a signal held in a value declares as a signal, in the sheet's own word.
	ok = _check("a signal type reads as the sheet's word for it",
		EventSheetSentence.type_word("Signal"), "signal") and ok
	# U8 - the mouse-look run, recognised piece by piece, and the note that shows the file's values.
	var turn: Dictionary = EventSheetSentence.mouse_look_turn_parts("rotate_y(-relative.x * 0.002)")
	var pitch: Dictionary = EventSheetSentence.mouse_look_pitch_parts("cam.rotate_x(-relative.y * 0.002)")
	ok = _check("the body's half of a mouse look is recognised",
		str(turn.get("amount", "")), "-relative.x * 0.002") and ok
	ok = _check("the camera's half names the camera", str(pitch.get("camera", "")), "cam") and ok
	ok = _check("a symmetric clamp gives the look its limit",
		EventSheetSentence.mouse_look_clamp_limit("cam.rotation.x = clamp(cam.rotation.x, -1.2, 1.2)", "cam"),
		"1.2") and ok
	ok = _check("two different limits are two numbers, so the clamp is refused",
		EventSheetSentence.mouse_look_clamp_limit("cam.rotation.x = clamp(cam.rotation.x, -1.2, 0.8)", "cam"),
		"") and ok
	ok = _check("the note shows the file's own values",
		EventSheetSentence.mouse_look_note(turn, pitch, "1.2", context),
		"turn by -relative.x * 0.002, look up/down on cam, clamped ±1.2") and ok
	# U12 - one fraction driving both faders is a crossfade; two unrelated volumes are not.
	ok = _check("two faders driven by one fraction read as a crossfade",
		str(EventSheetSentence.crossfade_parts("music_a.volume_db = linear_to_db(1.0 - t)",
			"music_b.volume_db = linear_to_db(t)", context).get("text", "")),
		"Crossfade music a → music b by t") and ok
	ok = _check("two unrelated volumes are refused",
		EventSheetSentence.crossfade_parts("music_a.volume_db = linear_to_db(0.5)",
			"music_b.volume_db = linear_to_db(t)", context).is_empty(), true) and ok
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


## Writes the source, opens it as a sheet, walks every row and returns {readings, patterns} - the
## cell readings as "object ▸ text", and {pattern id: how many events claimed it}.
static func _open_and_read() -> Dictionary:
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
	var patterns: Dictionary = {}
	for claim: Variant in EventSheetPatternFacts.claims(sheet):
		var pattern: String = str((claim as Dictionary).get("pattern", ""))
		patterns[pattern] = int(patterns.get(pattern, 0)) + 1
	viewport.free()
	return {"readings": readings, "patterns": patterns}


## Every row in the tree, parents before children.
static func _walk(rows: Array, viewport: EventSheetViewport) -> Array:
	var found: Array = []
	for row_data: EventRowData in rows:
		viewport._row_builder._ensure_event_spans(row_data)
		found.append(row_data)
		found.append_array(_walk(row_data.children, viewport))
	return found


## Gate three: each new shape is claimed in the registry, on the event that owns it.
static func _pattern_claims(patterns: Dictionary) -> bool:
	var ok: bool = true
	ok = _check("the web pattern is claimed on the function that makes the request",
		int(patterns.get("ajax", 0)), 1) and ok
	ok = _check("the lighting pattern is claimed on the function that lights the level",
		int(patterns.get("lighting", 0)), 1) and ok
	ok = _check("the background pattern is claimed on the function that hands work off",
		int(patterns.get("background", 0)), 1) and ok
	return ok


## Gate four: every reading here is a lens over a value the row already holds, so opening the file
## and saving it untouched puts back every byte.
static func _round_trip() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	var output: String = str(SheetCompiler.compile(sheet, SOURCE_PATH).get("output", ""))
	return _check("opening the file and saving it reproduces every byte", output, SOURCE)
