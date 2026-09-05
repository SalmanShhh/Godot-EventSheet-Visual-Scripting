# Godot EventSheets - the three extension registries a BOOT FILE may write to, and nothing else.
#
# `EventSheets` is the public API and it is the plugin's heaviest single name: between them its
# methods name the compiler, the importer, the Doctor, the viewport and the dock, so naming that one
# class anywhere compiles all of it. That is fine in a dialog built on first open, and it is not
# fine in `plugin.gd`, which the editor loads at every start of every project.
#
# The plugin's own `_enter_tree` has to register a card schema and a parameter field before any
# workspace is open, and a registration is three dictionary writes. Doing those writes through the
# API charged every editor start for the whole subtree: the cold-boot closure measured ~330 ms
# before the Feedback Player's schema was registered that way and ~19,000 ms after it.
#
# So the STORAGE lives here, in a file that names nothing at all, and `EventSheets` forwards to it.
# The public method shapes on the API are unchanged - they are a frozen contract - and this is only
# where the three dictionaries sit. A boot file reaches this file by path and pays a parse of these
# few lines instead of a compile of the plugin.
#
# DELIBERATELY NO `class_name`: a global name is the exact thing a boot file must not use, and this
# file exists so that there is nothing here worth naming. Readers that are already paying for the
# API (the params dialog, the card drawer) keep going through `EventSheets` and should - the split
# is about who may write at boot, not about routing every caller around the front door.
@tool
extends RefCounted

## Param editors: hint or type_name -> Callable(param_dict, initial_text) -> LineEdit.
static var _param_editors: Dictionary = {}
## Param help strip paragraphs: hint -> the sentence the strip says about a field of that kind.
static var _param_help: Dictionary = {}
## Card schemas: schema name -> Callable() -> Dictionary, asked when an Inspector draws the list.
static var _card_schemas: Dictionary = {}


static func register_param_editor(tag: String, factory: Callable) -> void:
	_param_editors[tag] = factory


static func param_editor_for(tag: String) -> Callable:
	return _param_editors.get(tag, Callable())


static func register_param_help(hint: String, paragraph: String) -> void:
	_param_help[hint] = paragraph


static func param_help_for(hint: String) -> String:
	return str(_param_help.get(hint, ""))


static func register_card_schema(schema_name: String, provider: Callable) -> void:
	_card_schemas[schema_name] = provider


static func unregister_card_schema(schema_name: String) -> void:
	_card_schemas.erase(schema_name)


## The schema registered under a name, or an empty Dictionary when nothing was registered (a card
## list whose pack is absent still edits, and still saves the bytes it was opened with).
static func card_schema(schema_name: String) -> Dictionary:
	var provider: Variant = _card_schemas.get(schema_name)
	if not (provider is Callable) or not (provider as Callable).is_valid():
		return {}
	var answer: Variant = (provider as Callable).call()
	return answer if answer is Dictionary else {}
