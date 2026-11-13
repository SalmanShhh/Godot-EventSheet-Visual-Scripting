@tool
class_name LookCatalogueTest
extends RefCounted

# Godot EventSheets - an Inspector look is a file, and the catalogue reads everything about it from the
# file's TEXT. These pins hold that reading: the name, the hover, the types, the questions and the line a
# look writes, for the looks that ship and for looks written here in the shape a project would write
# them; that a file of the project's own beats a shipped one of the same name; and that the writer and
# the reader of the marker are each other's inverse.
#
# NOT here, on purpose: building the control. An EditorProperty cannot be made outside the editor, so
# a headless test cannot `.new()` a look. The control is built and photographed in a real editor.

const SUPPORT := preload("res://tests/support.gd")
const NAME: String = "look_catalogue_test"
const FIXTURE_FOLDER: String = "user://look_catalogue_test"

const STAR_RATING: String = """@tool
extends EventSheetInspectorLook

## Star rating
## A row of stars. Click one to set the value.

## The kinds of property this look can be put on.
@export var works_on: String = "int"
## How many stars the row shows.
@export var count: int = 5
## What the hover says.
@export_enum("none", "number") var tip: String = "none"
## Draw the empty stars as outlines.
@export var outlined: bool = true
@export var caption := "stars"

var _row: HBoxContainer
"""

const UNIT_LIKE: String = """@tool
extends EventSheetInspectorLook

## Unit like
## Units in one segment.

@export var works_on: String = "float"
@export var kinds: String = "px|world"
@export var store: String = "world"

const MARKER_TEMPLATE := "kinds={kinds},store={store}"
"""


static func run() -> bool:
	var passed: bool = true
	passed = _the_shipped_progress_bar_reads_from_its_file() and passed
	passed = _a_look_written_in_a_project_reads_from_its_text() and passed
	passed = _text_that_is_not_a_look_is_not_one() and passed
	passed = _the_marker_writer_and_reader_are_inverses() and passed
	passed = _a_template_look_writes_one_segment() and passed
	passed = _types_are_matched_by_what_the_inspector_says() and passed
	passed = _a_project_file_beats_a_shipped_one_of_the_same_name() and passed
	passed = _the_window_lists_file_looks_where_the_table_keeps_their_place() and passed
	passed = _a_shipped_look_keeps_its_questions() and passed
	passed = _the_looks_moved_onto_files_read_as_the_table_did() and passed
	passed = _a_look_can_draw_a_type_it_does_not_offer() and passed
	passed = _a_shipped_look_says_its_own_preview_sentence() and passed
	passed = _a_same_length_edit_is_not_drawn_from_the_old_decor() and passed
	return passed


static func _the_shipped_progress_bar_reads_from_its_file() -> bool:
	EventSheetInspectorLookCatalogue.use_folders(PackedStringArray())
	var look: Dictionary = EventSheetInspectorLookCatalogue.entry("progress_bar")
	return SUPPORT.pins(NAME, [
		["it is installed", look.is_empty(), false],
		["its label is the first ## line", look.get("label"), "Progress bar"],
		["its hover is the rest of the block", look.get("tip"), "A filled bar between a min and a max. Without this plugin it is a plain number."],
		["it works on int and float", look.get("types"), ["int", "float"]],
		["it asks min then max, in file order", [look["fields"][0][0], look["fields"][1][0]], ["min", "max"]],
		["a number question is a number field", [look["fields"][0][2], look["fields"][1][2]], ["number", "number"]],
		["its defaults are the ones the file gives", [look["fields"][0][3], look["fields"][1][3]], ["0", "100"]],
		["a question's label is its first ## line", [look["fields"][0][1], look["fields"][1][1]], ["Min", "Max"]],
		["the lines after it are the hint", look["fields"][0][4], "The value at the empty end of the bar."],
		["the hover says the name as written, then the hint", look["fields"][0][5], "min
The value at the empty end of the bar."],
		["the line it writes is generated from the file", look.get("writes"),
			"@export_custom(PROPERTY_HINT_NONE, \"eventsheet:progress_bar:0:100\")"],
		["it is a shipped look", look.get("source"), "shipped"],
		["its file is where the plugin keeps its own looks", look.get("script_path"), "res://addons/eventsheet/looks/progress_bar.gd"],
	])


static func _a_look_written_in_a_project_reads_from_its_text() -> bool:
	var look: Dictionary = EventSheetInspectorLookCatalogue.read_look("res://eventsheet_addons/looks/star_rating.gd", STAR_RATING)
	var questions: Array = look.get("questions", [])
	var keys: Array = []
	var kinds: Array = []
	for question: Dictionary in questions:
		keys.append(question["key"])
		kinds.append(question["kind"])
	return SUPPORT.pins(NAME, [
		["the name is the file name", look.get("name"), "star_rating"],
		["the label is the first ## line", look.get("label"), "Star rating"],
		["the hover is the lines after it", look.get("tip"), "A row of stars. Click one to set the value."],
		["it works on int", look.get("types"), ["int"]],
		["works_on is a setting, not a question", keys, ["count", "tip", "outlined", "caption"]],
		["each question has the kind its type asks for", kinds, ["number", "pick", "tick", "text"]],
		["an enum string offers its words", questions[1]["choices"], ["none", "number"]],
		["a default is read as written", [questions[0]["default"], questions[1]["default"], questions[2]["default"], questions[3]["default"]],
			["5", "none", true, "stars"]],
		["a question's label is its ## line", questions[0]["label"], "How many stars the row shows."],
		["a question with no ## line is labelled by its name as written", [questions[3]["label"], questions[3]["hover"]], ["caption", "caption"]],
		["an inferred type is read from the default", questions[3]["type_name"], "String"],
		["the line it writes carries every default in order", look.get("writes"),
			"@export_custom(PROPERTY_HINT_NONE, \"eventsheet:star_rating:5:none:true:stars\")"],
		["a project look is a project look", look.get("source"), "project"],
	])


static func _text_that_is_not_a_look_is_not_one() -> bool:
	return SUPPORT.pins(NAME, [
		["a script that extends something else", EventSheetInspectorLookCatalogue.read_look("res://eventsheet_addons/looks/plain.gd", "extends Node\n"), {}],
		["a file name that is not an identifier", EventSheetInspectorLookCatalogue.read_look("res://eventsheet_addons/looks/star-rating.gd", STAR_RATING), {}],
		["a question named like one of the node's own properties is not asked",
			(EventSheetInspectorLookCatalogue.read_look("res://eventsheet_addons/looks/star_rating.gd", STAR_RATING.replace("var count: int", "var size: int")).get("questions") as Array).size(), 3],
		["the reserved word none", EventSheetInspectorLookCatalogue.read_look("res://eventsheet_addons/looks/none.gd", STAR_RATING), {}],
		["an empty file", EventSheetInspectorLookCatalogue.read_look("res://eventsheet_addons/looks/empty.gd", ""), {}],
	])


static func _the_marker_writer_and_reader_are_inverses() -> bool:
	var look: Dictionary = EventSheetInspectorLookCatalogue.read_look("res://eventsheet_addons/looks/star_rating.gd", STAR_RATING)
	var rows: Array = [
		["numbers are written without a decimal point", EventSheetInspectorLookCatalogue.marker_text(look, {"count": 3.0}),
			"eventsheet:star_rating:3:none:true:stars"],
		["a count typed as text keeps its text", EventSheetInspectorLookCatalogue.marker_text(look, {"count": " 7 "}),
			"eventsheet:star_rating:7:none:true:stars"],
		["a tick is true or false", EventSheetInspectorLookCatalogue.marker_text(look, {"outlined": false}),
			"eventsheet:star_rating:5:none:false:stars"],
		["a word with a colon cannot ride a marker", EventSheetInspectorLookCatalogue.marker_text(look, {"caption": "a:b"}), ""],
		["a word with a quote cannot ride a marker", EventSheetInspectorLookCatalogue.marker_text(look, {"caption": "a\"b"}), ""],
		["a count that is not a number cannot ride a marker", EventSheetInspectorLookCatalogue.marker_text(look, {"count": "many"}), ""],
		["written leniently, a bad value is its default", EventSheetInspectorLookCatalogue.marker_text(look, {"count": "many"}, true),
			"eventsheet:star_rating:5:none:true:stars"],
		["the arguments are what follows the name", EventSheetInspectorLookCatalogue.look_args(look, {"count": 9}), ["9", "none", "true", "stars"]],
		["reading them back gives the values by key", EventSheetInspectorLookCatalogue.marker_values(look, ["9", "number", "false", "x"]),
			{"count": 9, "tip": "number", "outlined": false, "caption": "x"}],
		["a shorter marker takes the defaults for the rest", EventSheetInspectorLookCatalogue.marker_values(look, ["2"]),
			{"count": 2, "tip": "none", "outlined": true, "caption": "stars"}],
	]
	var passed: bool = SUPPORT.pins(NAME, rows)
	# Every generated argument set reads back to what was written.
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	generator.seed = 77
	var drifted: Array = []
	for round: int in range(200):
		var values: Dictionary = {"count": generator.randi_range(-50, 400), "tip": ["none", "number"][generator.randi_range(0, 1)],
			"outlined": generator.randi_range(0, 1) == 1, "caption": "w%d" % generator.randi_range(0, 999)}
		var args: Array = EventSheetInspectorLookCatalogue.look_args(look, values)
		if EventSheetInspectorLookCatalogue.marker_values(look, args) != values:
			drifted.append(values)
	return SUPPORT.pin_value(NAME, "200 generated argument sets read back as written", drifted, []) and passed


static func _a_template_look_writes_one_segment() -> bool:
	var look: Dictionary = EventSheetInspectorLookCatalogue.read_look("res://eventsheet_addons/looks/unit_like.gd", UNIT_LIKE)
	return SUPPORT.pins(NAME, [
		["the template is read from the constant", look.get("template"), "kinds={kinds},store={store}"],
		["the marker is the template filled in", EventSheetInspectorLookCatalogue.marker_text(look, {"kinds": "px|world|screen", "store": "px"}),
			"eventsheet:unit_like:kinds=px|world|screen,store=px"],
		["the whole fill is one argument", EventSheetInspectorLookCatalogue.look_args(look, {"kinds": "a|b", "store": "b"}), ["kinds=a|b,store=b"]],
		["the template reads back", EventSheetInspectorLookCatalogue.marker_values(look, ["kinds=a|b,store=b"]), {"kinds": "a|b", "store": "b"}],
	])


static func _types_are_matched_by_what_the_inspector_says() -> bool:
	var number_look: Dictionary = EventSheetInspectorLookCatalogue.read_look("res://eventsheet_addons/looks/star_rating.gd", STAR_RATING)
	var any_look: Dictionary = number_look.duplicate()
	any_look["types"] = []
	var curve_look: Dictionary = number_look.duplicate()
	curve_look["types"] = ["Curve"]
	return SUPPORT.pins(NAME, [
		["an int look takes an int", EventSheetInspectorLookCatalogue.accepts(number_look, TYPE_INT), true],
		["an int look refuses a String", EventSheetInspectorLookCatalogue.accepts(number_look, TYPE_STRING), false],
		["a look with no types takes anything", EventSheetInspectorLookCatalogue.accepts(any_look, TYPE_VECTOR3), true],
		["a class name takes an empty slot of an object", EventSheetInspectorLookCatalogue.accepts(curve_look, TYPE_OBJECT), true],
		["a class name refuses a number", EventSheetInspectorLookCatalogue.accepts(curve_look, TYPE_INT), false],
	])


static func _a_project_file_beats_a_shipped_one_of_the_same_name() -> bool:
	DirAccess.make_dir_recursive_absolute(FIXTURE_FOLDER)
	_write(FIXTURE_FOLDER + "/progress_bar.gd", STAR_RATING)
	_write(FIXTURE_FOLDER + "/star_rating.gd", STAR_RATING)
	EventSheetInspectorLookCatalogue.use_folders(PackedStringArray([EventSheetInspectorLookCatalogue.SHIPPED_FOLDER, FIXTURE_FOLDER]))
	var names: Array = []
	for look: Dictionary in EventSheetInspectorLookCatalogue.entries():
		names.append(look["name"])
	var overriding: Dictionary = EventSheetInspectorLookCatalogue.entry("progress_bar")
	var passed: bool = SUPPORT.pins(NAME, [
		["the same name is listed once, in the shipped place", names.count("progress_bar"), 1],
		["a new name is listed after the shipped ones", names.find("star_rating") > names.find("progress_bar"), true],
		["the project's file is the one that is read", overriding.get("source"), "project"],
		["its questions are the project file's", overriding["questions"].size(), 4],
	])
	# A look added or removed shows up without anyone asking the catalogue to forget.
	DirAccess.remove_absolute(FIXTURE_FOLDER + "/star_rating.gd")
	passed = SUPPORT.pin_value(NAME, "a removed look is gone", EventSheetInspectorLookCatalogue.entry("star_rating"), {}) and passed
	DirAccess.remove_absolute(FIXTURE_FOLDER + "/progress_bar.gd")
	DirAccess.remove_absolute(FIXTURE_FOLDER)
	EventSheetInspectorLookCatalogue.use_folders(PackedStringArray())
	return passed


static func _the_window_lists_file_looks_where_the_table_keeps_their_place() -> bool:
	EventSheetInspectorLookCatalogue.use_folders(PackedStringArray())
	var ids: Array = []
	for look: Dictionary in EventSheetInspectorLooks.for_type("int"):
		ids.append(look["id"])
	return SUPPORT.pins(NAME, [
		["the progress bar sits where the table put it", ids.slice(ids.find("no_handle"), ids.find("no_handle") + 3), ["no_handle", "progress_bar", "number_choices"]],
		["by_id answers with the file's entry", str(EventSheetInspectorLooks.by_id("progress_bar").get("script_path")), "res://addons/eventsheet/looks/progress_bar.gd"],
		["the other table rows are untouched", EventSheetInspectorLooks.by_id("slider").has("script_path"), false],
		["a look that is not installed is no look", EventSheetInspectorLooks.by_id("star_rating_that_is_not_here"), {}],
	])


## A shipped look is a promise: its questions keep their names and their order, and one added later
## goes at the end with a default that reproduces the old marker. This list is committed here.
static func _a_shipped_look_keeps_its_questions() -> bool:
	var committed: Dictionary = {"progress_bar": ["min", "max"], "min_max": ["min", "max"], "vector_dial": ["max"],
		"table_row": ["table", "name_column"], "unit": ["units"], "toggle_row": ["choices"], "table": ["columns"], "swatch_row": [], "texture_preview": [], "curve_editor": [], "corners": []}
	var rows: Array = []
	for look: Dictionary in EventSheetInspectorLookCatalogue.entries():
		if str(look["source"]) != "shipped":
			continue
		var keys: Array = []
		for question: Dictionary in look["questions"]:
			keys.append(question["key"])
		var wanted: Variant = committed.get(look["name"])
		rows.append(["the questions of the shipped look %s" % look["name"], keys.slice(0, (wanted as Array).size()) if wanted is Array else keys, wanted])
	return SUPPORT.pins(NAME, rows)


## "Save and show" forgets the parsed decor lines: an edit that keeps the script's length (a colour, one
## word for another) would otherwise be drawn from the old map until the length changed.
static func _a_same_length_edit_is_not_drawn_from_the_old_decor() -> bool:
	var script: GDScript = GDScript.new()
	script.source_code = "extends RefCounted
# @inspector_header Alpha
@export var x: int = 1
"
	script.reload()
	var object: RefCounted = RefCounted.new()
	object.set_script(script)
	EventSheetAttributeDrawers.forget_decor()
	var first: Array = EventSheetAttributeDrawers.decor_for(object, "x")
	script.source_code = "extends RefCounted
# @inspector_header Bravo
@export var x: int = 1
"
	var stale: Array = EventSheetAttributeDrawers.decor_for(object, "x")
	EventSheetAttributeDrawers.forget_decor()
	var fresh: Array = EventSheetAttributeDrawers.decor_for(object, "x")
	EventSheetAttributeDrawers.forget_decor()
	return SUPPORT.pins(NAME, [
		["the first read is the header as written", str((first[0] as Dictionary).get("text")), "Alpha"],
		["a same-length edit reads from the old map until it is forgotten", str((stale[0] as Dictionary).get("text")), "Alpha"],
		["after forgetting, the edit is read", str((fresh[0] as Dictionary).get("text")), "Bravo"],
	])


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## The looks that moved from the table onto files keep what the window showed: the same name and hover,
## the same types, and the questions the old fold and unfold read by key.
static func _the_looks_moved_onto_files_read_as_the_table_did() -> bool:
	EventSheetInspectorLookCatalogue.use_folders(PackedStringArray())
	var wanted: Dictionary = {
		"swatch_row": ["Swatch row", "A row of colour swatches to pick from. Without this plugin it is a plain colour.", ["Color"], []],
		"texture_preview": ["Texture preview", "A bigger picture of the texture under the slot.", ["Texture2D"], []],
		"curve_editor": ["Curve preview", "A picture of the curve in the slot, drawn under it (an empty slot draws nothing). Its points are shaped in Godot's own curve editor.", ["Curve"], []],
		"corners": ["Four corners", "One number for all four corners, with a button that opens a box per corner.", ["Vector4"], []],
		"vector_dial": ["Direction dial", "The vector as an arrow on a dial. Without this plugin it is X and Y fields.", ["Vector2"], ["max"]],
		"min_max": ["Min-max range", "Two handles on one slider: x is the low end, y the high end.", ["Vector2"], ["min", "max"]],
		"table_row": ["Pick a row of a data table", "A dropdown of the rows of a data table, shown by their name column. The file still stores the row's number.", ["int"], ["table", "name_column"]],
	}
	var rows: Array = []
	for look_name: String in wanted:
		var look: Dictionary = EventSheetInspectorLooks.by_id(look_name)
		var keys: Array = []
		for field: Array in look.get("fields", []):
			keys.append(field[0])
		var expected: Array = wanted[look_name]
		rows.append(["%s reads as the table did" % look_name, [look.get("label"), look.get("tip"), look.get("types"), keys], expected])
	return SUPPORT.pins(NAME, rows)


## A look for text can still draw an int a script already marked, without the window offering it for ints.
static func _a_look_can_draw_a_type_it_does_not_offer() -> bool:
	var look: Dictionary = EventSheetInspectorLookCatalogue.read_look("res://eventsheet_addons/looks/word_row.gd",
		"@tool\nextends EventSheetInspectorLook\n\n## Word row\n## Words in a row.\n\n@export var works_on: String = \"String\"\nconst ALSO_DRAWS_ON := \"int, float\"\n")
	return SUPPORT.pins(NAME, [
		["the window offers it for the types works_on names", look.get("types"), ["String"]],
		["the extra types are read from the constant", look.get("also_draws"), ["int", "float"]],
		["it is drawn on a String", EventSheetInspectorLookCatalogue.accepts(look, TYPE_STRING), true],
		["it is drawn on an int a marker named", EventSheetInspectorLookCatalogue.accepts(look, TYPE_INT), true],
		["it is not drawn on a colour", EventSheetInspectorLookCatalogue.accepts(look, TYPE_COLOR), false],
	])


## The preview card's sentence under each shipped look is the one its file states, and it is the sentence
## the card always said.
static func _a_shipped_look_says_its_own_preview_sentence() -> bool:
	EventSheetInspectorLookCatalogue.use_folders(PackedStringArray())
	var pinned: Dictionary = {
		"progress_bar": "Shown as a progress bar.", "vector_dial": "Shown as a direction dial.",
		"min_max": "Shown as a min-max range slider.", "table": "Shown as an editable table.",
		"table_row": "Picked from a dropdown of a table's rows.", "toggle_row": "Shown as toggle buttons.",
		"unit": "Shown with a unit dropdown.", "corners": "Shown as four corners.", "swatch_row": "Shown as color swatches.",
		"texture_preview": "Shown with a texture preview.", "curve_editor": "Shown with a curve preview."}
	var rows: Array = []
	for look_name: String in pinned:
		rows.append(["%s: the file states the sentence" % look_name, EventSheetInspectorLookCatalogue.entry(look_name).get("preview"), pinned[look_name]])
		rows.append(["%s: the card says it" % look_name, EventSheetInspectorPreviewCard._widget_sentence({"drawer": look_name}), pinned[look_name]])
	rows.append(["a look the project added and gave no sentence is named", EventSheetInspectorPreviewCard._widget_sentence({"look": "star_rating"}),
		"Shown with the look star_rating."])
	return SUPPORT.pins(NAME, rows)
