# Godot EventSheets - a call made on a pack's node leads with the pack's icon.
#
# A line that calls a method of a behaviour node (`$Player/PlatformerMovement.jump()`) reads as the
# pack's verb ("Platformer: Jump") on the node it is mounted on, and used to lead with the icon of that
# node's own class - the circle every other line of the sheet wears - so the one thing that says whose
# verb it is, the pack, had no picture. It now leads with the icon of the pack's script class, the one the
# script names with `@icon`. Only the picture changes: the words, the object column and the code do not.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const READING_LINES := preload("res://tools/reading_lines.gd")
const NAME: String = "pack_call_row_icon_test"
const SHOWCASE: String = "res://demo/showcase/platformer_shooter/platformer_shooter.gd"
const PLATFORMER_ICON: String = "res://eventsheet_addons/platformer_movement/icon.svg"
const WEAPON_ICON: String = "res://eventsheet_addons/weapon_kit/icon.svg"


static func run() -> bool:
	var sheet: EventSheetResource = EventSheetGDScriptImporter.new().import_external(SHOWCASE)
	var viewport: EventSheetViewport = READING_LINES.viewport_for(sheet)
	var rows: Array = []
	READING_LINES._walk_rows(viewport, viewport._root_rows, rows)
	var jump: EventSheetSemanticSpan = _span_reading(rows, "Platformer: Jump")
	var fire: EventSheetSemanticSpan = _span_reading(rows, "Weapon: Fire")
	var plain: EventSheetSemanticSpan = _span_reading(rows, "Add delta to __every_ps_spawn")
	var platformer_picture: Texture2D = EventSheetACEIcons.path_icon(PLATFORMER_ICON)
	var weapon_picture: Texture2D = EventSheetACEIcons.path_icon(WEAPON_ICON)
	var ok: bool = SUPPORT.pins(NAME, [
		["both packs have an icon to lead with", [platformer_picture != null, weapon_picture != null], [true, true]],
		["the rows are found", [jump != null, fire != null, plain != null], [true, true, true]],
		["a Platformer verb leads with the Platformer pack's icon", _icon_of(jump) == platformer_picture, true],
		["a Weapon verb leads with the Weapon Kit's icon", _icon_of(fire) == weapon_picture, true],
		["a line of the sheet's own does not wear a pack's icon", [_icon_of(plain) == platformer_picture, _icon_of(plain) == weapon_picture], [false, false]],
		["the words of the row are the ones it always had", [jump.text, _object_of(jump), fire.text, _object_of(fire)],
			["Platformer: Jump", "PlatformerShooter", "Weapon: Fire", "PlatformerShooter"]],
		["the pack's name still leads the words as its own chip", _first_segment(jump), "Platformer: "],
		["a typed line reaches the same icon through the attribution, by the node's name",
			EventSheetViewportReadingRows.object_attribution("PlatformerMovement", [["Jump", "name"]], "Player", {}, {})["icon"] == platformer_picture, true],
		["and by the class the node was declared as", EventSheetViewportReadingRows.object_attribution(
			"weapon", [["Fire", "name"]], "Player", {"weapon": "WeaponKit"}, {})["icon"] == weapon_picture, true],
		["a call on a node that is no pack hands back no pack icon", EventSheetViewportReadingRows.object_attribution(
			"Sprite", [["Hide", "name"]], "Player", {}, {}).get("pack_icon"), null],
	])
	viewport.free()
	return ok


static func _span_reading(rows: Array, text: String) -> EventSheetSemanticSpan:
	for row_data: EventRowData in rows:
		for span: EventSheetSemanticSpan in row_data.spans:
			if span.text == text:
				return span
	return null


static func _icon_of(span: EventSheetSemanticSpan) -> Variant:
	return (span.metadata as Dictionary).get("object_icon") if span != null else null


static func _object_of(span: EventSheetSemanticSpan) -> String:
	return str((span.metadata as Dictionary).get("object_label", "")) if span != null else ""


static func _first_segment(span: EventSheetSemanticSpan) -> String:
	var segments: Array = (span.metadata as Dictionary).get("bbcode_segments", []) as Array
	return str((segments[0] as Dictionary).get("text", "")) if not segments.is_empty() else ""
