# Godot EventSheets - typing a whole row into the Add picker (preview module).
#
# Rendered by tools/render_previews.gd. The order of the results is not staged: each candidate is
# scored by the real quick-add reader against the real query, and the value shown beside the leader
# is what its prefill actually returns. A picture of a ranking that the code does not produce would
# be worse than no picture.
@tool
extends RefCounted

const PREVIEW_NAME: String = "quick-add-sentence"
const PREVIEW_SIZE: Vector2i = Vector2i(680, 360)

## The query, and the rows it could mean - each with the node it is aimed at, its keywords, and the
## parameters a value could land in.
const QUERY := "boss fla 0.4"
const CANDIDATES: Array[Dictionary] = [
	{"name": "Fade effect.dissolve to", "object": "$Boss", "keywords": "Effects dial tween",
		"params": [{"id": "value", "type_name": "float", "hint": "expression"}]},
	{"name": "Flash white for", "object": "$Boss", "keywords": "Effects pack hit",
		"params": [{"id": "seconds", "type_name": "float", "hint": "expression"}]},
	{"name": "Flash white and shake for", "object": "$Boss", "keywords": "Effects pack hit juice",
		"params": [{"id": "seconds", "type_name": "float", "hint": "expression"}]},
	{"name": "Set flip_h", "object": "$Boss", "keywords": "Sprite2D member",
		"params": [{"id": "value", "type_name": "bool", "hint": ""}]},
]


static func build(host: Window) -> Control:
	var column: VBoxContainer = EventSheetPopupUI.form_box()
	var search: LineEdit = LineEdit.new()
	search.text = QUERY
	column.add_child(EventSheetPopupUI.form_row("Search", search))
	var results: ItemList = ItemList.new()
	results.custom_minimum_size = Vector2(0.0, 120.0)
	for entry: Dictionary in _ranked():
		results.add_item(str(entry["line"]))
	if results.item_count > 0:
		results.select(0)
	column.add_child(EventSheetPopupUI.panel_section(results))
	column.add_child(EventSheetPopupUI.hint_label(
		"Words match object, verb and value in any order. Enter inserts the top row, Tab steps into its parameters.",
		460.0))
	var margined: MarginContainer = EventSheetPopupUI.margined(
		EventSheetPopupUI.titled_card("Add action", column))
	margined.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(margined)
	return margined


## The candidates the words reach, best first, each read as the picker will offer it - and with the
## value the query carried already in its parameter.
static func _ranked() -> Array[Dictionary]:
	var scored: Array[Dictionary] = []
	for candidate: Dictionary in CANDIDATES:
		var score: int = EventSheetQuickAdd.score(QUERY, str(candidate["name"]),
			str(candidate["object"]), str(candidate["keywords"]))
		if score <= 0:
			continue
		var filled: Dictionary = EventSheetQuickAdd.prefill(QUERY, candidate["params"] as Array)
		var line: String = "%s - %s" % [str(candidate["object"]).trim_prefix("$"), str(candidate["name"])]
		for value: Variant in filled.values():
			line += " %s" % str(value)
		scored.append({"score": score + EventSheetQuickAdd.value_bonus(QUERY, candidate["params"] as Array),
			"line": line})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["score"]) > int(b["score"]))
	return scored
