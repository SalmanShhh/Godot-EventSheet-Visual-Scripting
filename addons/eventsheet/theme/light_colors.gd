# Godot EventSheets - a theme's light colours.
#
# A theme file holds the colours it has always held; those are its DARK colours. A block of the theme
# can also hold `light_colors`, a dictionary of token name to colour that names only the tokens given a
# light colour of their own. The sheet wears the side that matches Godot's editor theme.
#
# A theme OPTS IN to a light look by holding at least one light colour, or by asking to follow the
# editor's greys. A theme that does neither is drawn in a light editor exactly as it is in a dark one.
# Of a token with no light colour, an opted-in theme that follows the editor's greys draws the value the
# editor-following rule works out, and any other draws its dark colour. That unresolved side is the
# "auto" swatch of the Theme Editor.
#
# DELIBERATELY NO `class_name`: callers load it by path at the moment they ask, so the first open of
# the workspace does not compile it.
@tool
extends RefCounted


## The property of a block that holds the light colours.
const PROPERTY := "light_colors"


## The blocks of `style` that can hold light colours, as [section name, block] in the order the form
## lists them. A block the theme does not have yet is left out (nothing is created).
static func blocks_of(style: EventSheetEditorStyle) -> Array:
	var blocks: Array = []
	if style == null:
		return blocks
	for pair: Array in [
		["event", style.event_style], ["condition", style.condition_style], ["action", style.action_style],
		["reading", style.reading_style], ["chrome", style.chrome_style], ["manual", style.manual_style],
	]:
		if pair[1] != null:
			blocks.append(pair)
	return blocks


## The light colours a block holds, as a dictionary of token name to colour (empty when it holds none).
static func entries_of(block: Resource) -> Dictionary:
	var held: Variant = block.get(PROPERTY) if block != null else null
	return held as Dictionary if held is Dictionary else {}


## Whether any block of the theme holds a light colour: the theme has opted in to a light look.
static func has_entries(style: EventSheetEditorStyle) -> bool:
	for pair: Array in blocks_of(style):
		if not entries_of(pair[1] as Resource).is_empty():
			return true
	return false


## The light colour a block gives `token`, or null when it gives none.
static func entry_of(block: Resource, token: String) -> Variant:
	var held: Dictionary = entries_of(block)
	return held[token] if held.has(token) and held[token] is Color else null


## Gives `token` a light colour. The dictionary is replaced, never edited, so a copy of the block made
## before keeps what it held.
static func set_entry(block: Resource, token: String, colour: Color) -> void:
	var held: Dictionary = entries_of(block).duplicate()
	held[token] = colour
	block.set(PROPERTY, held)


## Takes `token`'s light colour away, so its light side is worked out again.
static func clear_entry(block: Resource, token: String) -> void:
	var held: Dictionary = entries_of(block).duplicate()
	held.erase(token)
	block.set(PROPERTY, held)


## Puts every light colour of `style` onto the style itself: the caller passes a copy it owns. An entry
## that names something that is not a colour of its block (a token a later version retired) is ignored.
static func apply_entries(style: EventSheetEditorStyle) -> void:
	for pair: Array in blocks_of(style):
		var block: Resource = pair[1]
		var held: Dictionary = entries_of(block)
		for token: Variant in held:
			if held[token] is Color and typeof(block.get(str(token))) == TYPE_COLOR:
				block.set(str(token), held[token])


## A copy of `style` with every light colour taken away: what the theme draws when it gives its light
## side no colour of its own.
static func without_entries(style: EventSheetEditorStyle) -> EventSheetEditorStyle:
	var bare: EventSheetEditorStyle = style.duplicate(true) as EventSheetEditorStyle
	for pair: Array in blocks_of(bare):
		(pair[1] as Resource).set(PROPERTY, {})
	return bare
