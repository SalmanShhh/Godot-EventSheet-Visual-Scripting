# Godot EventSheets - the keys a Juice Player card holds, for the field box of the rows that tune one
# (editor-only, loaded by path).
#
# Set Juice Card Field and Juice Card Field name a value on a card by its key. The eight shipped names
# (amount, effect, seconds, ...) are only the keys EVERY card may hold; a Sound card holds a stream and a
# pitch, a card of your own holds its exports. So when the scene the sheet runs in is known and its Juice
# Player holds a card of the label the row names, the box offers THAT card's keys, each with the word the
# Inspector shows for it beside it. When the scene, the player or the card cannot be found (no scene
# runs the sheet, a player made while the game runs) the box offers the eight and still takes any key typed.
#
# `verb` and `card_script` are never offered: they are what makes a card the card it is. The scene is read
# from its saved bytes, nothing is instanced. No class_name on purpose, and nothing here is named by the
# first open of the workspace.
@tool
extends RefCounted

const NAMES_PATH: String = "res://addons/eventsheet/editor/inspector/juice_player_names.gd"
const SCHEMA_PATH: String = "res://addons/eventsheet/editor/inspector/feedback_card_schema.gd"
const OWN_PATH: String = "res://addons/eventsheet/editor/inspector/juice_own_cards.gd"

## The keys every card may hold, offered when the card cannot be found, each with the word the Inspector
## shows for it. The first eight are the ones the rows have always offered; the last three are the clock and
## the strength window of the Timing foldout.
const EVERY_CARD: Dictionary = {
	"amount": "Amount", "effect": "Effect", "seconds": "Seconds", "delay": "Delay", "interval": "Every",
	"repeat": "Repeat", "chance": "Chance", "loops": "Loops", "clock": "Clock",
	"min_strength": "Only at strength, from", "max_strength": "Only at strength, up to"}

## The words of the two keys every card carries that no kind draws as a field.
const SHARED_WORDS: Dictionary = {"label": "Label", "active": "Active"}

## The keys that make a card the card it is, never offered.
const NEVER: PackedStringArray = ["verb", "card_script"]


## The keys to offer for a row of the sheet at `sheet_path`: [{key, word}]. `target` is the node text the row
## plays (`$HitJuice`, `%Hit`), `label` the card the row names (a label, or a position counting from 1).
static func for_sheet(sheet_path: String, target: String, label: String) -> Array:
	var scenes: PackedStringArray = EventSheetSceneConnections.scenes_using_script(sheet_path) if sheet_path.begins_with("res://") else PackedStringArray()
	for scene_path: String in scenes:
		var found: Array = in_scene(scene_path, target, label)
		if not found.is_empty():
			return found
	return fallback()


## The names every card may hold, as the same {key, word} entries.
static func fallback() -> Array:
	var offered: Array = []
	for key: String in EVERY_CARD:
		offered.append({"key": key, "word": EventSheetL10n.translate(str(EVERY_CARD[key]))})
	return offered


## The labels of the cards of the player a row acts on, read from the saved scene the sheet runs in: each
## card's label, or its kind when it has none. Empty when no scene shows the player, which leaves the box a
## plain one.
static func labels_for_sheet(sheet_path: String, target: String) -> PackedStringArray:
	var scenes: PackedStringArray = EventSheetSceneConnections.scenes_using_script(sheet_path) if sheet_path.begins_with("res://") else PackedStringArray()
	for scene_path: String in scenes:
		var steps: Variant = player_steps(scene_path, target)
		if steps is Array:
			return labels_of(steps as Array)
	return PackedStringArray()


## The labels of a list of cards, in order, each once.
static func labels_of(steps: Array) -> PackedStringArray:
	var labels: PackedStringArray = PackedStringArray()
	for entry: Variant in steps:
		if entry is Dictionary:
			var named: String = str((entry as Dictionary).get("label", "")).strip_edges()
			if named.is_empty():
				named = str((entry as Dictionary).get("verb", "")).strip_edges()
			if not named.is_empty() and not labels.has(named):
				labels.append(named)
	return labels


## The keys the card holds in one saved scene, or an empty list when the player or the card is not there. The
## player is the node named by `target` (its last name), or the scene's only Juice Player when the row names
## none that is there.
static func in_scene(scene_path: String, target: String, label: String) -> Array:
	var steps: Variant = player_steps(scene_path, target)
	if not (steps is Array):
		return []
	var card: Dictionary = card_named(steps as Array, label)
	return [] if card.is_empty() else keys_of(card)


## The cards of the Juice Player a row names in one saved scene, or null when the scene or the player is not
## there. The player is the node named by `target` (its last name), or the scene's only Juice Player when the
## row names none that is there. Read from the saved bytes; nothing is instanced.
static func player_steps(scene_path: String, target: String) -> Variant:
	if not ResourceLoader.exists(scene_path):
		return null
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		return null
	var state: SceneState = packed.get_state()
	var wanted: String = target.strip_edges().trim_prefix("$").trim_prefix("%").trim_prefix("\"").trim_suffix("\"") if not target.strip_edges().is_empty() else ""
	var players: Array = []
	for node_index: int in range(state.get_node_count()):
		var steps: Variant = null
		var is_player: bool = false
		for property_index: int in range(state.get_node_property_count(node_index)):
			var property: String = str(state.get_node_property_name(node_index, property_index))
			var value: Variant = state.get_node_property_value(node_index, property_index)
			if property == "script" and value is Script:
				is_player = bool(load(NAMES_PATH).is_player_script(value as Script))
			elif property == "steps" and value is Array:
				steps = value
		if is_player and steps is Array:
			players.append({"name": str(state.get_node_name(node_index)), "steps": steps})
	var chosen: Dictionary = {}
	for player: Variant in players:
		if str((player as Dictionary).get("name")) == wanted.split("/")[-1]:
			chosen = player as Dictionary
	if chosen.is_empty() and players.size() == 1:
		chosen = players[0] as Dictionary
	return null if chosen.is_empty() else chosen.get("steps")


## The card a label (or a position counting from 1) names in a list, or an empty dictionary.
static func card_named(steps: Array, label: String) -> Dictionary:
	var wanted: String = label.strip_edges()
	for entry: Variant in steps:
		if entry is Dictionary:
			var named: String = str((entry as Dictionary).get("label", "")).strip_edges()
			if named.is_empty():
				named = str((entry as Dictionary).get("verb", "")).strip_edges()
			if not wanted.is_empty() and named == wanted:
				return entry as Dictionary
	if wanted.is_valid_int() and int(wanted) >= 1 and int(wanted) <= steps.size() and steps[int(wanted) - 1] is Dictionary:
		return steps[int(wanted) - 1] as Dictionary
	return {}


## The keys one card holds, in the order it holds them, each with the word the Inspector shows for it (its
## field's label; the key itself when the kind has no word for it). `verb` and `card_script` are left out.
static func keys_of(card: Dictionary) -> Array:
	var words: Dictionary = SHARED_WORDS.duplicate()
	var entry: Dictionary = {}
	var schema: Dictionary = load(SCHEMA_PATH).call("schema")
	if card.has("card_script"):
		entry = load(OWN_PATH).call("entry_for", card)
	else:
		entry = EventSheetCardSchemas.kind_entry(schema, str(card.get("verb", "")))
	for field: Variant in EventSheetCardSchemas.all_fields(schema, entry):
		var said: String = str((field as Dictionary).get("word", (field as Dictionary).get("label", ""))) if field is Dictionary else ""
		if field is Dictionary and not str((field as Dictionary).get("key", "")).is_empty() and not said.is_empty():
			words[str((field as Dictionary).get("key"))] = said
	var offered: Array = []
	for key: Variant in card:
		if NEVER.has(str(key)):
			continue
		var shown: String = EventSheetL10n.translate(str(words.get(str(key), "")))
		offered.append({"key": str(key), "word": shown if shown != str(key) else ""})
	return offered
