# Godot EventSheets - the sheet map: which sheets, scenes and globals reach which.
#
# The map is DERIVED, so the pins are the graph a real fixture project produces - three scripts that
# reach each other every way the map draws: one includes another, one signals a third, and one
# changes layout to a scene. Values, not counts: a scanner that started reading a different thing
# would change WHAT an edge says long before it changed how many there are.
@tool
class_name SheetMapTest
extends RefCounted

const FIXTURE_ROOT := "res://tests/fixtures/sheet_map"


static func run() -> bool:
	var passed: bool = true
	EventSheetSignalFanout.clear_cache()
	var found: Dictionary = EventSheetSheetMap.graph(FIXTURE_ROOT)
	passed = _the_nodes(found) and passed
	passed = _the_edges(found) and passed
	passed = _the_summary(found) and passed
	passed = _the_arrangement(found) and passed
	passed = _a_long_name_still_reads(found) and passed
	passed = _what_a_click_on_a_line_finds() and passed
	passed = _lines_meet_the_facing_edges() and passed
	passed = _every_line_says_what_it_is() and passed
	passed = _a_click_on_a_scene_opens_it() and passed
	EventSheetSignalFanout.clear_cache()
	return passed


static func _the_nodes(found: Dictionary) -> bool:
	var passed: bool = true
	passed = _check("every script is a sheet on the map, and the scene it goes to is a scene",
		_node_lines(found),
		"Game [sheet] · Hud [sheet] · Level Two (scene) [scene] · Player [sheet]") and passed
	return passed


static func _the_edges(found: Dictionary) -> bool:
	var passed: bool = true
	passed = _check("the map says who includes, who signals and who changes layout",
		_edge_lines(found),
		"Game -> Level Two (scene): Go to layout · Game -> Player: includes · Player -> Hud: signals On sheet_map_fixture_died") and passed
	return passed


static func _the_summary(found: Dictionary) -> bool:
	return _check("the map says what it drew, in the sheet's words",
		EventSheetSheetMap.summary(found), "3 sheets, 1 scene, 3 connections")


static func _the_arrangement(found: Dictionary) -> bool:
	var passed: bool = true
	var placed: Dictionary = EventSheetSheetMapPanel.default_positions(found.get("nodes", []) as Array)
	passed = _check("every node gets a place before anyone drags one",
		placed.size(), 4) and passed
	passed = _check("sheets stack down one column, scenes start the next",
		[placed["%s/game.gd" % FIXTURE_ROOT].x == placed["%s/player.gd" % FIXTURE_ROOT].x,
		placed["%s/level_two.tscn" % FIXTURE_ROOT].x > placed["%s/game.gd" % FIXTURE_ROOT].x],
		[true, true]) and passed
	return passed


## A box is a name, so the name has to fit in it: a sheet called something long gets a WIDER box
## rather than a name cut off mid-word, and the column after it starts past the widest box in this
## one instead of underneath it.
static func _a_long_name_still_reads(found: Dictionary) -> bool:
	var passed: bool = true
	var font: Font = ThemeDB.fallback_font
	var font_size: int = ThemeDB.fallback_font_size
	var long_name: String = "Ancient Vault Boss Encounter Director"
	var long_width: float = EventSheetSheetMapPanel.width_for_label(long_name, font, font_size, 1.0)
	var text_width: float = font.get_string_size(long_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		font_size).x
	passed = _check("a long name gets the whole name plus its clear space on both sides",
		snappedf(long_width - text_width, 0.001), snappedf(EventSheetSheetMapPanel.TEXT_INSET * 2.0, 0.001)) and passed
	passed = _check("the name really fits inside the box it was given",
		[long_width - EventSheetSheetMapPanel.TEXT_INSET * 2.0 >= text_width,
		long_width > EventSheetSheetMapPanel.BOX_WIDTH],
		[true, true]) and passed
	passed = _check("a short name keeps the standard box",
		EventSheetSheetMapPanel.width_for_label("Hud", font, font_size, 1.0),
		EventSheetSheetMapPanel.BOX_WIDTH) and passed
	# At 200% the font is already twice as big, so the answer still comes back in 1x space.
	passed = _check("the width comes back at 1x whatever the display scale",
		EventSheetSheetMapPanel.width_for_label(long_name, font, font_size, 2.0),
		maxf(EventSheetSheetMapPanel.BOX_WIDTH,
			text_width * 0.5 + EventSheetSheetMapPanel.TEXT_INSET * 2.0)) and passed
	# One wide box in the sheets column moves the scenes column over by exactly what it took.
	var widened: Dictionary = {"%s/game.gd" % FIXTURE_ROOT: 300.0}
	var placed: Dictionary = EventSheetSheetMapPanel.default_positions(
		found.get("nodes", []) as Array, widened)
	passed = _check("the widest box in a column decides where the next column starts",
		[placed["%s/game.gd" % FIXTURE_ROOT].x, placed["%s/level_two.tscn" % FIXTURE_ROOT].x],
		[220.0, 576.0]) and passed
	return passed


static func _what_a_click_on_a_line_finds() -> bool:
	var passed: bool = true
	passed = _check("a signal line finds the signal by name",
		EventSheetSheetMapPanel.find_query({"kind": EventSheetSheetMap.EDGE_SIGNALS,
			"label": "signals On died", "to": "res://hud.gd"}), "died") and passed
	passed = _check("a call line finds the global by name",
		EventSheetSheetMapPanel.find_query({"kind": EventSheetSheetMap.EDGE_CALLS,
			"label": "calls Save", "to": "res://save.gd"}), "Save") and passed
	passed = _check("an include line finds the file it includes",
		EventSheetSheetMapPanel.find_query({"kind": EventSheetSheetMap.EDGE_INCLUDES,
			"label": "includes", "to": "res://enemy.gd"}), "enemy") and passed
	return passed


## A line joins the two edges that FACE each other, whichever way round the boxes sit - a line to a
## box on the left used to leave from the right edge and run back through both boxes.
static func _lines_meet_the_facing_edges() -> bool:
	var panel: EventSheetSheetMapPanel = _laid_out_panel()
	return _check("a line to the right, to the left, below and above meets the facing edges", [
		panel.edge_points("a", "b"), panel.edge_points("b", "a"),
		panel.edge_points("a", "c"), panel.edge_points("c", "a"),
	], [
		PackedVector2Array([Vector2(164.0, 33.0), Vector2(220.0, 33.0)]),
		PackedVector2Array([Vector2(220.0, 33.0), Vector2(164.0, 33.0)]),
		PackedVector2Array([Vector2(90.0, 50.0), Vector2(90.0, 68.0)]),
		PackedVector2Array([Vector2(90.0, 68.0), Vector2(90.0, 50.0)]),
	])


## Every line carries its own words at its middle, and two lines between the same pair of boxes
## stack rather than print over each other.
static func _every_line_says_what_it_is() -> bool:
	var panel: EventSheetSheetMapPanel = _laid_out_panel()
	panel.found = {"nodes": panel.found["nodes"], "edges": [
		{"from": "a", "to": "b", "kind": EventSheetSheetMap.EDGE_INCLUDES, "label": "includes"},
		{"from": "b", "to": "a", "kind": EventSheetSheetMap.EDGE_CALLS, "label": "calls Game"},
		{"from": "a", "to": "c", "kind": EventSheetSheetMap.EDGE_LAYOUT, "label": "Go to layout"},
	], "skipped": 0}
	return _check("each line's label sits at its middle, stacked per pair", panel.edge_label_spots(), [
		{"text": "includes", "position": Vector2(192.0, 29.0)},
		{"text": "calls Game", "position": Vector2(192.0, 43.0)},
		{"text": "Go to layout", "position": Vector2(90.0, 55.0)},
	])


## A box is opened by clicking it, and that holds for a scene too: it goes to Godot's scene editor.
static func _a_click_on_a_scene_opens_it() -> bool:
	var editor: EventSheetEditor = EventSheetEditor.new()
	var panel: EventSheetSheetMapPanel = EventSheetSheetMapPanel.new(editor)
	panel._open_node("%s/level_two.tscn" % FIXTURE_ROOT)
	var status: String = editor._status_label.text if editor._status_label != null else ""
	editor.free()
	return _check("clicking a scene box opens that scene", status,
		"Opened level_two.tscn in the scene editor. Sheet ▸ Open… the same file to read the whole layout as one sheet.")


## Three standard boxes: `a` top left, `b` to its right, `c` under `a`.
static func _laid_out_panel() -> EventSheetSheetMapPanel:
	var panel: EventSheetSheetMapPanel = EventSheetSheetMapPanel.new(null)
	panel.found = {"nodes": [
		{"id": "a", "label": "A", "kind": EventSheetSheetMap.NODE_SHEET},
		{"id": "b", "label": "B", "kind": EventSheetSheetMap.NODE_SHEET},
		{"id": "c", "label": "C", "kind": EventSheetSheetMap.NODE_SHEET},
	], "edges": [], "skipped": 0}
	panel.positions = {"a": Vector2(16.0, 16.0), "b": Vector2(220.0, 16.0), "c": Vector2(16.0, 68.0)}
	return panel


# ── Reading the graph ─────────────────────────────────────────────────────────────────────────


static func _node_lines(found: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for entry: Variant in (found.get("nodes", []) as Array):
		var node: Dictionary = entry
		parts.append("%s [%s]" % [str(node.get("label", "")), str(node.get("kind", ""))])
	return " · ".join(parts)


static func _edge_lines(found: Dictionary) -> String:
	var labels: Dictionary = {}
	for entry: Variant in (found.get("nodes", []) as Array):
		labels[str((entry as Dictionary).get("id", ""))] = str((entry as Dictionary).get("label", ""))
	var parts: PackedStringArray = PackedStringArray()
	for entry: Variant in (found.get("edges", []) as Array):
		var edge: Dictionary = entry
		parts.append("%s -> %s: %s" % [str(labels.get(str(edge["from"]), edge["from"])),
			str(labels.get(str(edge["to"]), edge["to"])), str(edge["label"])])
	return " · ".join(parts)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] sheet map: %s" % label)
		return true
	print("[FAIL] sheet map: %s\n  expected: %s\n  actual:   %s" % [label, str(expected), str(actual)])
	return false
