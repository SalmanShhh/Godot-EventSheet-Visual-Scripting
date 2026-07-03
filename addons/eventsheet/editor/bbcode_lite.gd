# Godot EventSheets — BBCode-lite for comments
# A tiny BBCode subset for comment styling on the custom-drawn canvas:
#   [b]bold[/b]   [i]italic[/i]   [color=#ff7777]tint[/color]   [color=red]named[/color]
# parse() returns styled segments the renderer draws sequentially; unknown tags are
# stripped gracefully (their inner text survives). The RAW text (tags included) stays the
# editing/serialization truth — parsing only shapes the pixels, so no data is ever lost.
@tool
class_name EventSheetBBCodeLite
extends RefCounted


## Segments: [{ "text": String, "color": Variant (Color or null), "bold": bool, "italic": bool }]
static func parse(raw_text: String, base_color: Color = Color.WHITE) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	var bold_depth: int = 0
	var italic_depth: int = 0
	var color_stack: Array[Color] = []
	var cursor: int = 0
	var buffer: String = ""
	while cursor < raw_text.length():
		var open_index: int = raw_text.find("[", cursor)
		if open_index == -1:
			buffer += raw_text.substr(cursor)
			break
		var close_index: int = raw_text.find("]", open_index)
		if close_index == -1:
			buffer += raw_text.substr(cursor)
			break
		buffer += raw_text.substr(cursor, open_index - cursor)
		var tag: String = raw_text.substr(open_index + 1, close_index - open_index - 1).strip_edges().to_lower()
		var handled: bool = true
		match tag:
			"b":
				_flush(segments, buffer, color_stack, bold_depth, italic_depth, base_color)
				buffer = ""
				bold_depth += 1
			"/b":
				_flush(segments, buffer, color_stack, bold_depth, italic_depth, base_color)
				buffer = ""
				bold_depth = maxi(bold_depth - 1, 0)
			"i":
				_flush(segments, buffer, color_stack, bold_depth, italic_depth, base_color)
				buffer = ""
				italic_depth += 1
			"/i":
				_flush(segments, buffer, color_stack, bold_depth, italic_depth, base_color)
				buffer = ""
				italic_depth = maxi(italic_depth - 1, 0)
			"/color":
				_flush(segments, buffer, color_stack, bold_depth, italic_depth, base_color)
				buffer = ""
				if not color_stack.is_empty():
					color_stack.pop_back()
			_:
				if tag.begins_with("color="):
					var parsed: Color = Color.from_string(tag.trim_prefix("color="), base_color)
					_flush(segments, buffer, color_stack, bold_depth, italic_depth, base_color)
					buffer = ""
					color_stack.append(parsed)
				else:
					handled = false
		if not handled:
			# Unknown tag: drop the tag itself, keep flowing (inner text survives).
			pass
		cursor = close_index + 1
	_flush(segments, buffer, color_stack, bold_depth, italic_depth, base_color)
	return segments


## True when the text contains anything this parser would style.
static func has_markup(raw_text: String) -> bool:
	if not raw_text.contains("["):
		return false
	for tag in ["[b]", "[/b]", "[i]", "[/i]", "[color=", "[/color]"]:
		if raw_text.containsn(tag):
			return true
	return false


## Plain text with all recognized tags removed (clipboard/snippet-friendly).
static func strip(raw_text: String) -> String:
	var plain: String = ""
	for segment in parse(raw_text):
		plain += str(segment.get("text", ""))
	return plain


static func _flush(segments: Array[Dictionary], buffer: String, color_stack: Array[Color], bold_depth: int, italic_depth: int, base_color: Color) -> void:
	if buffer.is_empty():
		return
	segments.append({
		"text": buffer,
		"color": color_stack.back() if not color_stack.is_empty() else null,
		"bold": bold_depth > 0,
		"italic": italic_depth > 0
	})
