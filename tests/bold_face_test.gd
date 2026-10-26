# Godot EventSheets - a bold run on a sheet row is drawn in the bold FACE of the row's font, once.
# It used to be the regular text drawn twice, 0.7 px apart, which at row size reads as a smear
# ("Set group Boss active" looked doubled) rather than as weight. Pins: the face is the row's own font,
# stroked in its own colour as it is filled; it measures exactly as the regular face does (so a bold
# run never moves a word after it); and it is made once per font.
@tool
class_name BoldFaceTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var regular: Font = ThemeDB.fallback_font
	var bold: Font = EventRowRenderer.bold_font(regular)
	var variation: FontVariation = bold as FontVariation
	return SUPPORT.pins("bold_face_test", [
		["the bold face is the row's own font, marked to be stroked",
			[variation != null, variation.base_font == regular if variation != null else false,
				bold.has_meta(EventRowRenderer.BOLD_FACE_META) if bold != null else false],
			[true, true, true]],
		["it measures exactly as the regular face, so nothing after it moves",
			bold.get_string_size("Set group Boss active", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14).x,
			regular.get_string_size("Set group Boss active", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14).x],
		["one face per font for the session", EventRowRenderer.bold_font(regular) == bold, true],
		["no font, no face", EventRowRenderer.bold_font(null), null],
	])
