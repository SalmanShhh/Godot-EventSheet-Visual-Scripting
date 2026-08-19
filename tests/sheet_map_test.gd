# Godot EventSheets - U17 the sheet map: which sheets, scenes and globals reach which.
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
	passed = _what_a_click_on_a_line_finds() and passed
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
		EventSheetSheetMap.summary(found), "4 sheets, 3 connections")


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
