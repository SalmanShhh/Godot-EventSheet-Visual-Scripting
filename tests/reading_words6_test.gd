@tool
class_name ReadingWords6Test
extends RefCounted

# Pins the reading words batch six added - the six shapes a real script is full of that used to read
# as the GDScript they are rather than as the sheet's own row:
#
#   Q3   a just-pressed / just-released poll at the top of a tick handler reads as the TRIGGER it is,
#        and the "Every tick" words go away; a HELD poll keeps them, because holding is a check
#   Q5   numbers read the way a person writes them - 300.0 is 300, a million is grouped, 1e3 is
#        spelled out, π/2 is named, and a 0..1 setting reads as a percentage
#   Q6   list, table and text steps read in the List / Text modules' own words
#   Q7   the deferred family says the delay out loud, and a one-shot connection is Trigger once
#   Q8   physics layers and input actions read by their PROJECT names, and an action's bound device
#        chooses the object it files under
#   Q11  a number written where an enum is expected reads as the member it names
#
# Three gates, in the order they matter:
#   1. the grammar's own values - one shape, one sentence, asserted literally;
#   2. the whole path - a hand-written file opened as a sheet, walked row by row, so a reading that
#      stops reaching the canvas is caught even when the grammar still answers on its own;
#   3. the promise every one of these rests on - the file still saves byte-identically, because all
#      six are lenses over values the row already holds.
#
# The source lives here as a string rather than in tests/fixtures/ for the same reason its sibling
# reading tests' sources do: the lifter's byte gate compares against what the COMPILER would emit,
# and the compiler puts ONE blank line between functions, so a checked-in two-blank-line file could
# never lift and the fixture would silently test nothing.
#
# The project settings this reads (physics layer names, one input action bound to the mouse) are
# process-global state shared with every other test, so they are captured on the way in and put back
# on the way out.

const SOURCE_PATH := "user://eventforge_reading_words6.gd"

const LAYER_SETTINGS: Array = [
	["layer_names/2d_physics/layer_1", "World"],
	["layer_names/2d_physics/layer_2", "Enemies"],
	["layer_names/2d_physics/layer_3", "Player"]
]
const MOUSE_ACTION_SETTING := "input/reading_words6_fire"

const SOURCE: String = """extends CharacterBody2D

enum Direction { UP, RIGHT, DOWN, LEFT }

var items: Array = []
var inventory: Dictionary = {}
var label: String = ""
var dir: Direction = Direction.UP
@export_range(0, 1) var half: float = 0.5
@onready var art: Sprite2D = $Art
@onready var caption: Label = $Caption

func _ready() -> void:
	$Beat.timeout.connect(_on_beat_timeout, CONNECT_ONE_SHOT)
	items.append(1)
	items.push_front(2)
	items.pop_back()
	items.insert(2, 3)
	items.remove_at(0)
	items.erase(3)
	items.clear()
	items.sort()
	items.shuffle()
	items.reverse()
	inventory.erase("potion")
	label += "!"
	call_deferred("reset")
	set_deferred("visible", true)
	set_collision_layer_value(2, true)
	collision_layer = 5
	process_mode = 3
	dir = 2
	half = 0.5
	art.texture_filter = 1
	caption.horizontal_alignment = 1
	position.x = 300.0
	position.y = 1000000
	rotation = 1.5707963
	velocity.x = 1e3

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		reset()
	if Input.is_action_just_released("reading_words6_fire"):
		reset()

func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("hold"):
		reset()

func _on_beat_timeout() -> void:
	reset()

func reset() -> void:
	pass
"""

## Every reading the opened file must contain, one per shape this batch claims.
static var EXPECTED_READINGS: PackedStringArray = PackedStringArray([
	# Q6 - the List / Dictionary / Text modules' own words
	"System ▸ Push back 1 to items",
	"System ▸ Push front 2 to items",
	"System ▸ Pop back of items",
	"System ▸ Insert 3 at 2 in items",
	"System ▸ Delete at 0 in items",
	"System ▸ Delete value 3 from items",
	"System ▸ Clear items",
	"System ▸ Sort items",
	"System ▸ Shuffle items",
	"System ▸ Reverse items",
	"System ▸ Delete key \"potion\" from inventory",
	"System ▸ Append \"!\" to label",
	# Q7 - the deferred family says the delay out loud
	"CharacterBody2D ▸ Call Reset (at end of frame)",
	"CharacterBody2D ▸ Set visible to true (at end of frame)",
	# Q8 - the project's own names for its physics layers
	"CharacterBody2D ▸ Set collision with layer \"Enemies\" on",
	"CharacterBody2D ▸ Set collision layers to \"World\", \"Player\"",
	# Q11 - a number written where an enum is expected
	"CharacterBody2D ▸ Set process mode to Always",
	"System ▸ Set dir to DOWN",
	"art ▸ Set texture filter to Nearest",
	# T11 re-pin: alignment is a TEXT reading now, and the sheet's own word for the middle of a line
	# is "centre" rather than the engine constant's spelling.
	"caption ▸ Set horizontal alignment to centre",
	# Q5 - numbers the way a person writes them
	"System ▸ Set Half to 50%",
	"CharacterBody2D ▸ Set X to 300",
	"CharacterBody2D ▸ Set Y to 1,000,000",
	"CharacterBody2D ▸ Set angle (radians) to π/2",
	"System ▸ Set velocity X to 1000",
	# Q3 / Q8 - the poll reads as the trigger it is, under the device the project bound it to
	"Keyboard ▸ On \"jump\" pressed",
	"Mouse ▸ On \"reading_words6_fire\" released",
	# Q3 - a HELD poll is a check, so its handler keeps the tick words
	"System ▸ Every tick (physics)",
	"Keyboard ▸ \"hold\" is down",
	# Q7 - a one-shot connection is the sheet's own Trigger once
	"Beat ▸ On Timeout",
	"Trigger once"
])

## Readings the file must NOT contain: the words each shape replaced. A reading that silently stops
## firing would otherwise pass the list above by never being asked about.
static var FORBIDDEN_READINGS: PackedStringArray = PackedStringArray([
	"System ▸ Every tick (draw)",
	"System ▸ Add \"!\" to label",
	"CharacterBody2D ▸ Set collision with layer 2 on",
	"CharacterBody2D ▸ Set process mode to 3",
	"CharacterBody2D ▸ Set X to 300.0",
	"System ▸ Set velocity X to 1e3"
])


static func run() -> bool:
	var ok: bool = true
	ok = _grammar_values() and ok
	var restore: Dictionary = _apply_project_settings()
	var readings: PackedStringArray = _open_and_read()
	for expected: String in EXPECTED_READINGS:
		ok = _check("opened row reads \"%s\"" % expected, readings.has(expected), true) and ok
	for forbidden: String in FORBIDDEN_READINGS:
		ok = _check("no row still reads \"%s\"" % forbidden, readings.has(forbidden), false) and ok
	ok = _round_trip() and ok
	_restore_project_settings(restore)
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] reading_words6_test: %s" % label)
		return true
	print("[FAIL] reading_words6_test: %s - expected %s, got %s" % [label, expected, actual])
	return false


## Gate one: the grammar answering on its own, value by value. Everything here is pure, so a wrong
## answer is pinned to the one function that produced it rather than to the whole canvas.
static func _grammar_values() -> bool:
	var ok: bool = true
	# Q5 - what each spelling reads as. "" means "already written the way a person writes it".
	var numbers: Dictionary = {
		"300.0": "300", "0.50": "0.5", "1_000_000": "1,000,000", "1e3": "1000",
		"1.5707963": "π/2", "6.2831853": "τ", "1.4142136": "√2", "10000": "10,000",
		"3.14": "", "1": "", "0.5": "", "0x1F": "", "1980": ""
	}
	for literal: String in numbers:
		ok = _check("number %s reads \"%s\"" % [literal, numbers[literal]],
			EventSheetSentence.number_words(literal), str(numbers[literal])) and ok
	# The lens skips what is not a literal: a name that ends in a digit, and anything inside quotes.
	ok = _check("the number lens leaves an identifier alone",
		EventSheetSentence.number_lens("sprite2.frame = 300.0"), "sprite2.frame = 300") and ok
	ok = _check("the number lens leaves a string literal alone",
		EventSheetSentence.number_lens("\"res://a/1000000.png\""), "\"res://a/1000000.png\"") and ok
	# Q11 - Godot writes an enum hint as a comma list, and an entry may pin its own number.
	ok = _check("an enum hint names its member by position",
		EventSheetSentence.enum_hint_member("Inherit,Pausable,When Paused,Always,Disabled", 3), "Always") and ok
	ok = _check("an enum hint honours a pinned number",
		EventSheetSentence.enum_hint_member("Nearest:1,Linear:2", 2), "Linear") and ok
	ok = _check("an enum hint answers nothing for a number it does not name",
		EventSheetSentence.enum_hint_member("Inherit,Pausable", 9), "") and ok
	ok = _check("the engine's own enum hint is found through ClassDB",
		EventSheetSentence.enum_hint_member(
			EventSheetSentence.engine_enum_hint("Node", "process_mode"), 4), "Disabled") and ok
	# Q8 - the project's layer names, and the device an action's bindings put it under.
	var restore: Dictionary = _apply_project_settings()
	ok = _check("a named layer reads by its name",
		EventSheetSentence.physics_layer_name(2, EventSheetSentence.PHYSICS_DIMENSION_2D), "Enemies") and ok
	ok = _check("a mask reads as the layers it holds",
		EventSheetSentence.physics_layer_words(5, EventSheetSentence.PHYSICS_DIMENSION_2D),
		"\"World\", \"Player\"") and ok
	ok = _check("a mask naming nothing the project named reads nothing",
		EventSheetSentence.physics_layer_words(1 << 20, EventSheetSentence.PHYSICS_DIMENSION_2D), "") and ok
	ok = _check("an action bound to the mouse belongs to the Mouse object",
		EventSheetSentence.input_action_object("\"reading_words6_fire\""), EventSheetSentence.OBJECT_MOUSE) and ok
	ok = _check("an action the project never bound stays with Keyboard",
		EventSheetSentence.input_action_object("\"jump\""), EventSheetSentence.OBJECT_KEYBOARD) and ok
	_restore_project_settings(restore)
	return ok


## The physics layer names and the mouse-bound action this test reads, with the previous values
## returned so the caller can put the project back exactly as it found it.
static func _apply_project_settings() -> Dictionary:
	var previous: Dictionary = {}
	for entry: Array in LAYER_SETTINGS:
		previous[entry[0]] = ProjectSettings.get_setting(str(entry[0]), null)
		ProjectSettings.set_setting(str(entry[0]), str(entry[1]))
	previous[MOUSE_ACTION_SETTING] = ProjectSettings.get_setting(MOUSE_ACTION_SETTING, null)
	ProjectSettings.set_setting(MOUSE_ACTION_SETTING,
		{"deadzone": 0.5, "events": [InputEventMouseButton.new()]})
	return previous


static func _restore_project_settings(previous: Dictionary) -> void:
	for key: Variant in previous:
		ProjectSettings.set_setting(str(key), previous[key])


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


## Every row in the tree, parents before children - a folded parent's children read the same as an
## open one's, and what a row says must not depend on whether anything above it happens to be open.
static func _walk(rows: Array, viewport: EventSheetViewport) -> Array:
	var found: Array = []
	for row_data: EventRowData in rows:
		viewport._row_builder._ensure_event_spans(row_data)
		found.append(row_data)
		found.append_array(_walk(row_data.children, viewport))
	return found


## The promise all six readings rest on: every one of them is a lens over a value the row already
## holds, so opening the file and saving it untouched puts back every byte - the CONNECT_ONE_SHOT
## flag on the connect line included, which is the one shape here that widened the lifter.
static func _round_trip() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	var output: String = str(SheetCompiler.compile(sheet, SOURCE_PATH).get("output", ""))
	return _check("opening the file and saving it reproduces every byte", output, SOURCE)
