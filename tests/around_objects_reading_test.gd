@tool
class_name AroundObjectsReadingTest
extends RefCounted

# Pins the batch-nine "around objects" readings - the four families a project writes ABOUT an object
# rather than about its behaviour, each of which an event sheet already has one row for:
#
#   T8   picking: which instances the rows below are about - nearest, farthest, random, by
#        comparison, top, bottom, by UID - each naming what it filled
#   T10  layers and Z order: Set Z order, Move to top / bottom of layer, Move to layer, Set layer
#        order, Set layer visible
#   T11  text: Set font size / font colour / horizontal alignment / word wrap / font, and translated
#   T12  the browser and the platform: Go to URL, Copy to clipboard, Request fullscreen, Alert, and
#        Is on web / Is Android in the shipped Platform Info pack's own words
#
# Four gates, in the order they matter:
#   1. the grammar's own values - one shape, one sentence, asserted literally;
#   2. the word for an inheritance set (T9), pinned in all three of its states;
#   3. every pattern the file holds, claimed on the row that owns it;
#   4. the promise all of it rests on - the file still saves byte-identically, because every reading
#      here is a lens over a value the row already holds.
#
# The source lives here as a string rather than in tests/fixtures/ for the same reason its sibling
# reading tests' sources do: the lifter's byte gate compares against what the COMPILER would emit,
# and the compiler puts ONE blank line between functions, so a checked-in two-blank-line file could
# never lift and the fixture would silently test nothing.

const SOURCE_PATH := "user://eventforge_around_objects_reading.gd"

const SOURCE: String = """extends Node2D

@onready var label: Label = $Label
@onready var hud_layer: CanvasLayer = $HUD
var code: String = "ABCD"
var saved_id: int = 0

func _ready() -> void:
	z_index = 5
	z_as_relative = false
	move_to_front()
	reparent($"../FX")
	hud_layer.layer = 10
	hud_layer.visible = false
	label.add_theme_font_size_override("font_size", 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD

func share() -> void:
	OS.shell_open("https://example.com")
	DisplayServer.clipboard_set(code)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	OS.alert("Saved!")

func aim() -> void:
	var enemies = get_tree().get_nodes_in_group("enemy")
	var victim = enemies.pick_random()
	var by_id = instance_from_id(saved_id)
	if OS.has_feature("web"):
		saved_id = 1
	if OS.get_name() == "Android":
		saved_id = 2
"""

## The statements whose sentence this parcel settles, as "object ▸ sentence".
static var STATEMENT_READINGS: Dictionary = {
	# T10 - where an object sits in the drawing order
	"z_index = 5": "Player ▸ Set Z order to 5 (absolute)",
	"z_as_relative = false": "Player ▸ Set Z order absolute",
	"move_to_front()": "Player ▸ Move to top of layer",
	"move_to_back()": "Player ▸ Move to bottom of layer",
	"reparent($\"../FX\")": "Player ▸ Move to layer FX",
	"hud_layer.layer = 10": "hud_layer ▸ Set layer order to 10",
	# T11 - how its text is styled
	"label.add_theme_font_size_override(\"font_size\", 32)": "label ▸ Set font size to 32",
	"label.add_theme_color_override(\"font_color\", Color.RED)": "label ▸ Set font colour to red",
	"label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER":
		"label ▸ Set horizontal alignment to centre",
	"label.autowrap_mode = TextServer.AUTOWRAP_WORD": "label ▸ Set word wrap on",
	"label.autowrap_mode = TextServer.AUTOWRAP_OFF": "label ▸ Set word wrap off",
	"label.label_settings.font = preload(\"res://ui/bold.ttf\")": "label ▸ Set font to bold.ttf",
	# T12 - what it asks of the machine it runs on
	"OS.shell_open(\"https://example.com\")": "Browser ▸ Go to URL \"https://example.com\"",
	"DisplayServer.clipboard_set(code)": "Browser ▸ Copy code to clipboard",
	"DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)":
		"Browser ▸ Request fullscreen",
	"DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)": "Browser ▸ Leave fullscreen",
	"OS.alert(\"Saved!\")": "Browser ▸ Alert \"Saved!\"",
	# T8 - which instances, and the name each pick filled
	"var victim = enemies.pick_random()": "System ▸ Pick a random Enemy → victim",
	"var rich = enemies.filter(func(e): return e.gold > 50)":
		"System ▸ Pick Enemy where gold > 50 → rich",
	"var top = enemies.back()": "System ▸ Pick top Enemy → top",
	"var bottom = enemies.front()": "System ▸ Pick bottom Enemy → bottom",
	"var by_id: Enemy = instance_from_id(saved_id)": "System ▸ Pick Enemy by UID saved_id → by id"
}

## The condition readings the grammar must answer on its own, as "object ▸ sentence".
static var CONDITION_READINGS: Dictionary = {
	"OS.has_feature(\"web\")": "Platform ▸ Is on web",
	"OS.has_feature(\"mobile\")": "Platform ▸ Is on mobile",
	"OS.has_feature(\"pc\")": "Platform ▸ Is on desktop",
	"OS.has_feature(\"demo\")": "Platform ▸ Has feature tag \"demo\"",
	"OS.get_name() == \"Android\"": "Platform ▸ Is Android"
}

## Readings the file must NOT contain: the words each new shape replaced. A reading that silently
## stops firing would otherwise pass the list above by never being asked about.
static var FORBIDDEN_READINGS: PackedStringArray = PackedStringArray([
	"Player ▸ Set z_index to 5",
	"hud_layer ▸ Set layer to 10",
	"OS ▸ Shell open \"https://example.com\""
])

## Readings the opened file must contain - and these are the AUTHORING half's own words, on purpose.
##
## Every line of the source above is exactly what one of this parcel's picker rows writes, so opening
## the file LIFTS each of them into that row and the canvas shows the row's own sentence rather than
## the grammar's. That is the parity being asserted: a shape typed by hand and the same shape dropped
## from the picker are one row and one file. The grammar's own sentences for the same shapes are
## pinned value by value in the gate above, which is where a shape nothing lifts would land.
static var EXPECTED_READINGS: PackedStringArray = PackedStringArray([
	"System ▸ set Z order to 5",
	"System ▸ set Z order absolute",
	"System ▸ move to top of layer",
	"System ▸ move to layer $\"../FX\"",
	"System ▸ set layer order to 10",
	"System ▸ set font size to 32",
	"System ▸ set horizontal alignment to HORIZONTAL_ALIGNMENT_CENTER",
	"System ▸ set word wrap on",
	"System ▸ go to URL \"https://example.com\"",
	"System ▸ copy code to clipboard",
	"System ▸ request fullscreen",
	"System ▸ alert \"Saved!\"",
	"System ▸ pick a random one of enemies -> victim",
	"System ▸ is on web"
])


static func run() -> bool:
	var ok: bool = true
	ok = _grammar_values() and ok
	ok = _inheritance_word() and ok
	var readings: PackedStringArray = _open_and_read()
	for expected: String in EXPECTED_READINGS:
		ok = _check("opened row reads \"%s\"" % expected, readings.has(expected), true) and ok
	for forbidden: String in FORBIDDEN_READINGS:
		ok = _check("no row still reads \"%s\"" % forbidden, readings.has(forbidden), false) and ok
	ok = _claims() and ok
	ok = _round_trip() and ok
	return ok


## The sentence context an opened script hands the grammar, including the two multi-line facts the
## reading rows gather once per rebuild.
static func _context() -> Dictionary:
	return {
		"self_object": "Player",
		"script_object": "Player",
		"self_class": "Node2D",
		"engine_properties": {"z_index": true, "z_as_relative": true, "visible": true,
			"position": true},
		"object_classes": {"hud_layer": "CanvasLayer", "label": "Label"},
		"z_order_relative": {"Player": false},
		"family_lists": {"enemies": "Enemy"}
	}


## Gate one: the grammar answering on its own, value by value.
static func _grammar_values() -> bool:
	var ok: bool = true
	var context: Dictionary = _context()
	for code: String in STATEMENT_READINGS:
		ok = _check("statement %s" % code,
			_joined_segments(EventSheetSentence.statement(code, context)),
			str(STATEMENT_READINGS[code])) and ok
	for expression: String in CONDITION_READINGS:
		ok = _check("condition %s" % expression,
			_joined_pieces(EventSheetSentence.condition_pieces(expression, context)),
			str(CONDITION_READINGS[expression])) and ok
	# T11 - a translation key is not a call a reader thinks about.
	ok = _check("a translation key reads as translated text",
		EventSheetSentence.expression_text("tr(\"HELLO\")", context), "translated \"HELLO\"") and ok
	# T10 - the layer number is only a drawing order on something that IS a layer.
	var plain: Dictionary = _context()
	plain["object_classes"] = {}
	ok = _check("a plain node's layer number stays a number",
		_joined_segments(EventSheetSentence.statement("hud_layer.layer = 10", plain)),
		"hud_layer ▸ Set layer to 10") and ok
	# T8 - a list nothing said the kind of is not picked from.
	ok = _check("a pick from a list of unknown kind keeps its own words",
		_joined_segments(EventSheetSentence.statement("var one = things.pick_random()", plain)),
		"Local value one = things.pick_random()") and ok
	# T12 - the editor tag stays the sheet's own "running in the editor" question.
	ok = _check("the editor feature tag is not a platform",
		_joined_pieces(EventSheetSentence.condition_pieces("OS.has_feature(\"editor\")", context)),
		"System ▸ is in the editor") and ok
	return ok


## Gate two: T9's word for an inheritance set, in all three of its states. The whole point of the
## setting is that ONE helper answers, so every place that says the word changes together.
static func _inheritance_word() -> bool:
	var ok: bool = true
	# Headless there is no editor-settings store, so no word is pinned and both defaults answer.
	ok = _check("with the sheet's own glossary on, an inheritance set is a Family",
		EventSheetFamilyFacts.word(true), "Family") and ok
	ok = _check("with it off, it is a base class",
		EventSheetFamilyFacts.word(false), "Base class") and ok
	ok = _check("and the Object bar's heading follows",
		EventSheetFamilyFacts.section_title(true), "FAMILIES") and ok
	ok = _check("and off it says the Godot word, in the plural the bar needs",
		EventSheetFamilyFacts.section_title(false), "BASE CLASSES") and ok
	# The third state: a word the user typed on the Words page, which wins in both glossaries. The
	# pure form of the lookup is used, so the gate does not need a settings store to pin it.
	var pinned: Dictionary = {"familiar": {"inheritance_set": "Kind"}, "plain": {"inheritance_set": "Kind"}}
	ok = _check("a user who pinned Kind gets Kind whichever glossary is showing",
		"%s/%s" % [EventSheetWords.word_for("inheritance_set", true, pinned),
			EventSheetWords.word_for("inheritance_set", false, pinned)], "Kind/Kind") and ok
	# T9 - a group whose members are the set's agrees; one that is not names the stray.
	var agreement: Dictionary = EventSheetFamilyFacts.group_agreement("Enemy",
		PackedStringArray(["Bat", "Slime"]), PackedStringArray(["Bat", "Slime"]))
	ok = _check("a group with the set's own members agrees", agreement.get("matches", false), true) and ok
	var drifted: Dictionary = EventSheetFamilyFacts.group_agreement("Enemy",
		PackedStringArray(["Bat", "Slime"]), PackedStringArray(["Bat", "Goblin"]))
	ok = _check("a group holding something else names it",
		", ".join(drifted.get("strays", PackedStringArray()) as PackedStringArray), "Goblin") and ok
	ok = _check("and says so in one sentence",
		EventSheetFamilyFacts.stray_message("Enemy", "enemy", "Goblin", true),
		"Goblin is in the group \"enemy\" but does not extend Enemy (the family the group is named after).") and ok
	return ok


## Gate three: every pattern the file holds is CLAIMED on the row that owns it, so the chip, the
## hover evidence, Adopt behavior and the Doctor all read one set of claims.
static func _claims() -> bool:
	var ok: bool = true
	var body: PackedStringArray = PackedStringArray([
		"var nearest = null",
		"var best = INF",
		"for e in enemies:",
		"\tvar d = global_position.distance_to(e.global_position)",
		"\tif d < best:",
		"\t\tbest = d",
		"\t\tnearest = e"
	])
	var claims: Array = EventSheetPatternReadings.claims_in(body, {})
	var picking: Dictionary = {}
	for entry: Variant in claims:
		if str((entry as Dictionary).get("pattern", "")) == "picking":
			picking = entry
	ok = _check("a nearest-so-far loop claims the picking pattern",
		str(picking.get("words", "")), "picks the nearest one by distance") and ok
	ok = _check("and keeps the loop's own lines as evidence",
		"\n".join(picking.get("evidence", PackedStringArray()) as PackedStringArray).contains(
			"distance_to"), true) and ok
	var farthest: PackedStringArray = PackedStringArray([
		"for e in enemies:",
		"\tvar d = global_position.distance_to(e.global_position)",
		"\tif d > best:",
		"\t\tfar = e"
	])
	var far_words: String = ""
	for entry: Variant in EventSheetPatternReadings.claims_in(farthest, {}):
		if str((entry as Dictionary).get("pattern", "")) == "picking":
			far_words = str((entry as Dictionary).get("words", ""))
	ok = _check("the other end of the walk says farthest", far_words,
		"picks the farthest one by distance") and ok
	# A loop that measures nothing is not a pick, and claiming one would put a chip on a plain loop.
	var plain_loop: PackedStringArray = PackedStringArray(["for e in enemies:", "\te.hit()"])
	var claimed_plain: bool = false
	for entry: Variant in EventSheetPatternReadings.claims_in(plain_loop, {}):
		if str((entry as Dictionary).get("pattern", "")) == "picking":
			claimed_plain = true
	ok = _check("a loop that only calls something claims no pick", claimed_plain, false) and ok
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] around_objects_reading_test: %s" % label)
		return true
	print("[FAIL] around_objects_reading_test: %s - expected %s, got %s" % [label, expected, actual])
	return false


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


## Writes the source, opens it as a sheet, and returns every cell reading.
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
