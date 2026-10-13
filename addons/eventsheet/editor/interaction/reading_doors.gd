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


static func _script(path: String) -> Script:
	var found: Script = _loaded.get(path) as Script
	if found == null:
		found = load(path) as Script
		_loaded[path] = found
	return found
