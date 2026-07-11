# EventSheets - short descriptions for ACE picker SECTIONS (category / sub-section / provider headers).
#
# The picker groups ACEs under category and node-type headers. On its own a header is just a word;
# this registry gives it a one-line "what is this group" blurb, shown in the picker's info panel when
# the header is selected (and as its hover tooltip). Three sources feed it, first-wins:
#   1. A built-in seed here for the core categories.
#   2. Each builtin ACE module's optional `static func section_descriptions() -> Dictionary`.
#   3. (In the picker, as a fallback) a pack's own class doc comment via metadata["provider_description"],
#      so an addon's category header describes the addon with no extra wiring.
# Extensions can add their own with EventSheetSectionInfo.describe(name, text).
@tool
class_name EventSheetSectionInfo
extends RefCounted

## name (the category / sub-section / node-type text shown on the header) -> short description.
static var _descriptions: Dictionary = {}
static var _seeded: bool = false


## Registers (or replaces) the description shown for a picker section by its exact header text.
static func describe(name: String, text: String) -> void:
	_descriptions[name.strip_edges()] = text.strip_edges()


## The description for a section header, or "" when none is registered.
static func description_for(name: String) -> String:
	_ensure_seeded()
	return str(_descriptions.get(name.strip_edges(), ""))


## Whether any description is registered for a section header.
static func has(name: String) -> bool:
	_ensure_seeded()
	return _descriptions.has(name.strip_edges())


## Extension seam (EventSheets.register_section_description): packs register the blurb their
## picker section shows when its header is selected - same channel as the built-ins.
static func register_description(name: String, blurb: String) -> void:
	_ensure_seeded()
	_descriptions[name.strip_edges()] = blurb


## A copy of every registered description (for tests / tooling).
static func all() -> Dictionary:
	_ensure_seeded()
	return _descriptions.duplicate()


## Test seam: drops the seed so a following describe()/lookup re-seeds from scratch.
static func _reset_for_test() -> void:
	_descriptions = {}
	_seeded = false


## Seeds the core categories once, then merges each ACE module's own section_descriptions()
## (module entries never override a core seed). Idempotent.
static func _ensure_seeded() -> void:
	if _seeded:
		return
	_seeded = true
	for name: Variant in _SEED:
		_descriptions[str(name)] = str(_SEED[name])
	var module_sections: Dictionary = EventForgeBuiltinACEs.section_descriptions()
	for name: Variant in module_sections:
		var key: String = str(name).strip_edges()
		if not key.is_empty() and not _descriptions.has(key):
			_descriptions[key] = str(module_sections[name])


## Built-in category blurbs (plain-language, for a beginner). Names must match the category strings the
## modules author. A name with no match here simply shows no blurb - harmless.
const _SEED: Dictionary = {
	"Helpers": "Escape-hatch actions for anything without a dedicated ACE - set a property, call a method, run a line of GDScript, or an inline if.",
	"Debug": "Print, assert, and pause tools for seeing what your game is doing while you build it.",
	"Groups": "Tag nodes into named groups, then find, count, or act on every member at once.",
	"Metadata": "Store and read your own named values on any node without adding a variable.",
	"Nodes": "Walk the scene tree - parent, children, find by name, the scene owner.",
	"Editor Tools": "Automate the Godot editor from a Tool sheet - open and save scenes, add nodes, write resources. These run in the editor, not in your exported game.",
	"Game Window": "Control the game window - fullscreen or windowed, size, title, vsync, and the frame-rate cap.",
	"Game Options": "The knobs a settings menu changes - audio volume per bus, mute, vsync, frame cap, and saving them to a file.",
	"Input": "Rebind controls, read whether an action is pressed and how hard, and manage the mouse.",
	"Vibration": "Rumble a gamepad or buzz a phone, and stop it again.",
	"Object Pool": "Reuse nodes instead of creating and freeing them - spawn from a pool and return them, so heavy scenes stay smooth.",
	"Fade": "Fade a sprite or UI in and out by animating its transparency.",
	"Slide Movement": "Grid movement where a tap sends the character sliding until it hits a wall.",
	"Tile Movement": "Grid-locked stepping - one tile per press, snapped to the grid.",
}
