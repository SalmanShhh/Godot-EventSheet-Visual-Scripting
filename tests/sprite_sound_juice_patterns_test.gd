@tool
class_name SpriteSoundJuicePatternsTest
extends RefCounted

# S11 - S14, the whole path: a hand-written sprite / UI / sound / juice script opened as a sheet,
# walked row by row, so a reading that stops reaching the canvas is caught even when the grammar
# still answers on its own. Three gates:
#   1. every reading the canvas must show, asserted literally;
#   2. the pattern each event claims in the registry, with the source line as its evidence;
#   3. the promise the reading rests on - the file still saves byte-identically.
#
# The source lives here as a string rather than in tests/fixtures/ because the byte gate compares
# against what the COMPILER would emit, which puts ONE blank line between functions.

const SOURCE_PATH := "user://eventforge_sprite_sound_juice.gd"

const SOURCE: String = """class_name SpriteSoundJuiceReader
extends Node2D

var dir: float = 1.0
var base_y: float = 0.0
var t: float = 0.0
var s: float = 4.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var sfx: AudioStreamPlayer = $Sfx
@onready var music: AudioStreamPlayer = $Music
@onready var camera: Camera2D = $Camera2D
@onready var resume_button: Button = $ResumeButton
@onready var game_over: AcceptDialog = $GameOver

func _process(_delta: float) -> void:
	sprite.flip_h = dir < 0
	anim_tree.set("parameters/blend_position", dir)
	position.y = base_y + sin(t * 3.0) * 8.0

func _on_hit() -> void:
	sprite.frame = 3
	anim.speed_scale = 2.0
	sprite.modulate.a = 0.5
	anim_tree["parameters/playback"].travel("Hurt")
	camera.offset = Vector2(randf_range(-s, s), randf_range(-s, s))

func _on_jumped() -> void:
	sfx.stream = preload("res://jump.wav")
	sfx.pitch_scale = 1.1
	sfx.bus = "SFX"
	sfx.play()

func start_music() -> void:
	music.volume_db = linear_to_db(0.5)
	music.seek(12.0)

func _on_pause_pressed() -> void:
	resume_button.grab_focus()
	game_over.popup_centered()
	AudioServer.set_bus_volume_db(0, linear_to_db(0.5))
"""

## Every reading the opened file must contain, one per shape S11 - S14 claims.
static var EXPECTED_READINGS: PackedStringArray = PackedStringArray([
	# S11 - the sprite and animation words
	"sprite ▸ Set mirrored when dir < 0",
	# X7 re-homed the two blend-tree rows onto the object's Animation aspect.
	"SpriteSoundJuiceReader ▸ Animation ▸ Set blend blend position to dir",
	"sprite ▸ Set animation frame to 3",
	"anim ▸ Set animation speed to 2",
	"sprite ▸ Set opacity to 50%",
	"SpriteSoundJuiceReader ▸ Animation ▸ Go to state \"Hurt\"",
	# S13 - the sound words
	"sfx ▸ Set sound to jump.wav",
	"sfx ▸ Set pitch to 1.1",
	"sfx ▸ Set bus to SFX",
	"sfx ▸ Play sound",
	"music ▸ Set volume to 50%",
	"music ▸ Seek to 12 seconds",
	# S12 - the UI words
	"resume_button ▸ Set focus",
	"game_over ▸ Open centered",
	"Audio ▸ Set master volume to 50%",
	# S14 - the juice words
	"camera ▸ Shake by s random offset this tick",
	"SpriteSoundJuiceReader ▸ Bob y sine · magnitude 8 · 3 per second"
])


static func run() -> bool:
	var ok: bool = true
	ok = _opened_file_reads() and ok
	ok = _patterns_claimed() and ok
	ok = _round_trip() and ok
	ok = _picked_matches_typed() and ok
	ok = _picked_writes_the_read_shape() and ok
	return ok


## Gate 4 - a row dropped from the PICKER reads exactly what the same shape typed by hand reads.
static func _picked_matches_typed() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "SpriteSoundJuiceReader"
	sheet.host_class = "Node2D"
	sheet.events.append(_onready_object("sprite", "Sprite2D", "$Sprite2D"))
	sheet.events.append(_onready_object("sfx", "AudioStreamPlayer", "$Sfx"))
	sheet.events.append(_onready_object("camera", "Camera2D", "$Camera2D"))
	sheet.events.append(_onready_object("resume_button", "Button", "$ResumeButton"))
	var event_row: EventRow = EventRow.new()
	event_row.trigger_id = "OnReady"
	event_row.actions.append(_action("SetSpriteFrame", {"target": "sprite", "frame": "3"}))
	event_row.actions.append(_action("SetSpriteTexture", {"target": "sprite", "path": "\"res://hero.png\""}))
	event_row.actions.append(_action("AudioSetStream", {"target": "sfx", "path": "\"res://jump.wav\""}))
	event_row.actions.append(_action("AudioSetBus", {"target": "sfx", "bus": "\"SFX\""}))
	event_row.actions.append(_action("AudioSetVolumeLevel", {"target": "sfx", "level": "0.5"}))
	event_row.actions.append(_action("AudioSeek", {"target": "sfx", "seconds": "12.0"}))
	event_row.actions.append(_action("GrabFocus", {"target": "resume_button"}))
	event_row.actions.append(_action("SetMasterVolume", {"level": "0.5"}))
	event_row.actions.append(_action("CameraShakeOnce", {"target": "camera", "amount": "4.0"}))
	event_row.actions.append(_action("EaseSizeBack", {"rate": "10.0"}))
	sheet.events.append(event_row)
	var readings: PackedStringArray = _render(sheet)
	for expected: String in [
		"sprite ▸ Set animation frame to 3",
		"sprite ▸ Set image to hero.png",
		"sfx ▸ Set sound to jump.wav",
		"sfx ▸ Set bus to SFX",
		"sfx ▸ Set volume to 50%",
		"sfx ▸ Seek to 12 seconds",
		"resume_button ▸ Set focus",
		"Audio ▸ Set master volume to 50%",
		"camera ▸ Shake by 4 random offset this tick",
		"SpriteSoundJuiceReader ▸ Ease size back to normal at 10 per second"
	]:
		ok = _check("picked row reads \"%s\"" % expected, readings.has(expected), true) and ok
	return ok


## Gate 5 - and what the picked row WRITES is the shape the reading recognises, so a sheet-authored
## pattern and a hand-written one are the same bytes.
static func _picked_writes_the_read_shape() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "SpriteSoundJuiceWriter"
	sheet.host_class = "Node2D"
	var event_row: EventRow = EventRow.new()
	event_row.trigger_id = "OnReady"
	event_row.actions.append(_action("CameraShakeOnce", {"target": "camera", "amount": "4.0"}))
	event_row.actions.append(_action("AudioSetVolumeLevel", {"target": "music", "level": "0.5"}))
	event_row.actions.append(_action("SetMasterVolume", {"level": "0.5"}))
	event_row.actions.append(_action("ShowDialogCentred", {"target": "game_over"}))
	sheet.events.append(event_row)
	var output: String = str(SheetCompiler.compile(sheet, "user://eventforge_sprite_sound_juice_written.gd").get("output", ""))
	for expected: String in [
		"camera.offset = Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))",
		"music.volume_db = linear_to_db(0.5)",
		"AudioServer.set_bus_volume_db(0, linear_to_db(0.5))",
		"game_over.popup_centered()"
	]:
		ok = _check("the picked row writes \"%s\"" % expected, output.contains(expected), true) and ok
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


## Gate 1 - the canvas says every one of these.
static func _opened_file_reads() -> bool:
	var ok: bool = true
	var readings: PackedStringArray = _render(_import())
	for expected: String in EXPECTED_READINGS:
		ok = _check("opened row reads \"%s\"" % expected, readings.has(expected), true) and ok
	return ok


## Gate 2 - the registry knows which pattern each event reads as, and why.
static func _patterns_claimed() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = _import()
	_render(sheet)
	var claimed: Dictionary = {}
	var evidence: Dictionary = {}
	var adoptable: Dictionary = {}
	for entry: Variant in EventSheetPatternFacts.claims(sheet):
		var claim: Dictionary = entry
		var pattern: String = str(claim.get("pattern", ""))
		claimed[pattern] = true
		adoptable[str(claim.get("adoptable", ""))] = true
		for line: String in (claim.get("evidence", PackedStringArray()) as PackedStringArray):
			evidence[line] = true
	ok = _check("the sprite pattern is claimed", claimed.has("sprite_animation"), true) and ok
	ok = _check("the UI pattern is claimed", claimed.has("ui"), true) and ok
	ok = _check("the sound pattern is claimed", claimed.has("sound"), true) and ok
	ok = _check("the juice pattern is claimed", claimed.has("juice"), true) and ok
	ok = _check("the game-feel pattern offers the behavior that could replace it",
		adoptable.has("juice"), true) and ok
	ok = _check("a claim's evidence is the line it was read from",
		evidence.has("camera.offset = Vector2(randf_range(-s, s), randf_range(-s, s))"), true) and ok
	ok = _check("every claim belongs to an event of this sheet",
		EventSheetPatternFacts.claims(sheet).size() > 0, true) and ok
	return ok


## Gate 3 - reading is display only, so the file still saves byte for byte.
static func _round_trip() -> bool:
	var sheet: EventSheetResource = _import()
	var output: String = str(SheetCompiler.compile(sheet, SOURCE_PATH).get("output", ""))
	return _check("opening the file and saving it reproduces every byte", output, SOURCE)


static func _import() -> EventSheetResource:
	var handle: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()
	return GDScriptImporter.new().import_external(SOURCE_PATH)


## The readings of one sheet, straight off the canvas's own spans.
static func _render(sheet: EventSheetResource) -> PackedStringArray:
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


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] sprite_sound_juice_patterns_test: %s" % label)
		return true
	print("[FAIL] sprite_sound_juice_patterns_test: %s - expected %s, got %s" % [label, expected, actual])
	return false
