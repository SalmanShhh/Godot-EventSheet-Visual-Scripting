# Godot EventSheets - the heavy scripts the reading layer borrows from, reached BY PATH.
#
# Reading a row now and then asks the compiler what a condition will emit, or asks the lifter how a
# line of GDScript reads as a row; a hover or a drop on the canvas asks a dialog or the public API
# one small question. All of them are large and all of them name much of the plugin, and in
# GDScript naming a global class anywhere in a file's code compiles that class - and everything it
# names - the moment the file loads. The canvas, the row builder and the grammar load on the first
# sheet open, so naming any of these there put the whole compiler, importer, dialogs and API into
# that first open, before any row had asked them anything.
#
# So the reading files ask HERE, and this file loads each script by its path the first time it is
# actually needed. `load()` caches, so each one still compiles exactly once per session; it just
# compiles when it is used rather than when the reader is loaded. The answers are the very same
# static functions and constants the classes have always had - nothing is copied.
#
# DELIBERATELY NO `class_name`, and it names no plugin class: reach it with a const preload.
@tool
extends RefCounted

const COMPILER_PATH: String = "res://addons/eventforge/compiler/sheet_compiler.gd"
const LIFTER_PATH: String = "res://addons/eventforge/importer/ace_lifter.gd"
const API_PATH: String = "res://addons/eventsheet/api/eventsheets.gd"
const PARAMS_DIALOG_PATH: String = "res://addons/eventsheet/editor/ace_params_dialog.gd"
const VARIABLE_DIALOG_PATH: String = "res://addons/eventsheet/editor/variable_dialog.gd"
const DOC_REFERENCE_PATH: String = "res://addons/eventsheet/editor/docs/doc_reference.gd"
const DOCTOR_PATH: String = "res://addons/eventforge/project_doctor.gd"
const PICKER_DIALOG_PATH: String = "res://addons/eventsheet/editor/ace_picker.gd"
const ENGINE_REFERENCE_PATH: String = "res://addons/eventsheet/editor/docs/doc_engine_reference.gd"
const PATTERN_MANUAL_PATH: String = "res://addons/eventsheet/editor/docs/doc_patterns.gd"
const DOC_TRACKS_PATH: String = "res://addons/eventsheet/editor/docs/doc_tracks.gd"
const DOC_LIBRARY_PATH: String = "res://addons/eventsheet/editor/docs/doc_library.gd"
const DOC_FIGURES_PATH: String = "res://addons/eventsheet/editor/docs/doc_figures.gd"
const FILES_DOCTOR_PATH: String = "res://addons/eventforge/files_doctor.gd"
const TRANSLATION_SCAN_PATH: String = "res://addons/eventsheet/editor/translation_scan.gd"
const GRID_CSV_PATH: String = "res://addons/eventsheet/editor/grid_csv.gd"
const INSPECTOR_PREVIEW_CARD_PATH: String = "res://addons/eventsheet/editor/inspector_preview_card.gd"

## path -> the loaded script, so a row sweep asks the resource cache once per script, not per row.
static var _loaded: Dictionary = {}


## The compiler script. Call its statics on the answer as on the class.
static func compiler() -> Script:
	return _script(COMPILER_PATH)


## The lifter script. Its statics and constants answer through it as through the class.
static func lifter() -> Script:
	return _script(LIFTER_PATH)


## The public API script, for the canvas's two questions of it (which asset files a drop takes, and
## the open sheet's variables).
static func api() -> Script:
	return _script(API_PATH)


## The parameters dialog script, for its node-reference spelling of a dropped node.
static func params_dialog() -> Script:
	return _script(PARAMS_DIALOG_PATH)


## The variable dialog script, for the way it writes a default value.
static func variable_dialog() -> Script:
	return _script(VARIABLE_DIALOG_PATH)


## The Manual's reference script, for the help line a mark's tooltip shows.
static func doc_reference() -> Script:
	return _script(DOC_REFERENCE_PATH)


## The Project Doctor script, for the project's script list and the sources it has already read. A
## Doctor section, a fact scanner and the share index ask it these; none of them is the Doctor.
static func doctor() -> Script:
	return _script(DOCTOR_PATH)


## The picker dialog script, for its fuzzy match - the very one the picker's own search uses, so a
## completion list and the picker never disagree about what a typed word finds.
static func picker_dialog() -> Script:
	return _script(PICKER_DIALOG_PATH)


## The Manual's engine reference, for a member's one-line description, its page id and the credit
## line that goes with it. The Manual's Markdown parser and page library sit behind it.
static func engine_reference() -> Script:
	return _script(ENGINE_REFERENCE_PATH)


## The Manual's patterns page, opened from a pattern mark on the canvas.
static func pattern_manual() -> Script:
	return _script(PATTERN_MANUAL_PATH)


## The Manual's learning tracks, for the suggestion the status line makes after a save.
static func doc_tracks() -> Script:
	return _script(DOC_TRACKS_PATH)


## The Manual's page library, for the picker's recipes read off its pages.
static func doc_library() -> Script:
	return _script(DOC_LIBRARY_PATH)


## The Manual's figure reader, for the picker's recipes: which blocks are figures, and their sheets.
static func doc_figures() -> Script:
	return _script(DOC_FIGURES_PATH)


## The Doctor's Files section, for the scene-trust sentence the help strip says under a row.
static func files_doctor() -> Script:
	return _script(FILES_DOCTOR_PATH)


## The translation scanner, for its project file walk and its catalog columns. The grid codec and
## the drawer widgets sit behind it.
static func translation_scan() -> Script:
	return _script(TRANSLATION_SCAN_PATH)


## The grid file codec, for writing a catalog back.
static func grid_csv() -> Script:
	return _script(GRID_CSV_PATH)


## The Inspector mock a hover over an exported variable shows. `.new()` on the answer builds one.
static func inspector_preview_card() -> Script:
	return _script(INSPECTOR_PREVIEW_CARD_PATH)


static func _script(path: String) -> Script:
	var found: Script = _loaded.get(path) as Script
	if found == null:
		found = load(path) as Script
		_loaded[path] = found
	return found
