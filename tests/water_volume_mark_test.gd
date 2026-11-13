# Godot EventSheets - the two rows a drop offers for an area in the water group.
#
# Whether a node is water is Godot's own fact (the group `water`), read by the canvas drop from the
# scene; scene_node_offers_test pins that. This file pins what the offer then adds.
#
# What this pins, in the order the mistakes actually happen:
#   1. THE ROWS. The two events the offer adds, by VALUE: the two triggers, the object they ride, the
#      shipped Set value row, and the exact statements it writes.
#   2. THE READING. The emitted file claims the swim shape, because `in_water = true` on the way in
#      and `in_water = false` on the way out is literally what the water reading looks for. The flag
#      alone is only a flag, so the drag a swimmer writes next stands in the file beside it - that is
#      the reading's own gate, and this proves the rows land on the right side of it.
@tool
class_name WaterVolumeMarkTest
extends RefCounted



static func run() -> bool:
	var ok: bool = true
	ok = _the_rows() and ok
	ok = _the_reading() and ok
	return ok


## 3. The two rows the offer adds, pinned by VALUE: the way in, the way out, and the statement each
## one writes.
static func _the_rows() -> bool:
	var ok: bool = true
	var events: Array = EventSheetStarterEvents.water_volume_events("WaterVolume", "Area2D")
	ok = _check("the offer is two events, the way in and the way out", events.size(), 2) and ok
	if events.size() != 2:
		return false
	var went_in: EventRow = events[0]
	var came_out: EventRow = events[1]
	ok = _check("the first rides the area's own walked-in trigger",
		went_in.trigger_id, "OnBodyEntered") and ok
	ok = _check("the second rides its walked-out trigger",
		came_out.trigger_id, "OnBodyExited") and ok
	ok = _check("both point at the object that was dropped",
		[went_in.trigger_source_path, came_out.trigger_source_path],
		["WaterVolume", "WaterVolume"]) and ok
	ok = _check("the way in writes one row",
		[went_in.actions.size(), came_out.actions.size()], [1, 1]) and ok
	var raise_it: ACEAction = went_in.actions[0]
	var lower_it: ACEAction = came_out.actions[0]
	ok = _check("which is the shipped Set value row", str(raise_it.ace_id), "SetVar") and ok
	ok = _check("raising the sheet's own water flag", raise_it.params,
		{"var_name": "in_water", "value": "true"}) and ok
	ok = _check("and the way out lowers the same flag", lower_it.params,
		{"var_name": "in_water", "value": "false"}) and ok
	ok = _check("the row's template is the shipped one, not a retyped copy",
		EventSheetStarterEvents.set_value_template(), "{var_name} = {value}") and ok
	ok = _check("the flag it holds is the name every swimming rule is written against",
		EventSheetStarterEvents.WATER_VARIABLE, "in_water") and ok
	ok = _check("declared as a yes-or-no that starts false",
		[str(EventSheetStarterEvents.water_variable_entry().get("type", "")),
			EventSheetStarterEvents.water_variable_entry().get("default")], ["bool", false]) and ok
	return ok


## 4. The emitted file: the two statements, word for word, and the swim shape they claim.
static func _the_reading() -> bool:
	var ok: bool = true
	var built: String = _compiled_water_sheet()
	ok = _check("the way in raises the flag",
		built.contains("func _on_watervolume_body_entered(_body: Node) -> void:\n\tin_water = true"),
		true) and ok
	ok = _check("the way out lowers it",
		built.contains("func _on_watervolume_body_exited(_body: Node) -> void:\n\tin_water = false"),
		true) and ok
	ok = _check("and the flag is declared on the sheet",
		built.contains("var in_water: bool = false"), true) and ok

	var lines: PackedStringArray = PackedStringArray()
	for line: String in built.split("\n"):
		lines.append(line.strip_edges())
	var facts: Dictionary = EventSheetPatternReadings.facts(lines)
	var marks: Dictionary = facts.get("water_flags", {})
	ok = _check("the file reads back as holding a water flag",
		(marks.get("in_water", {}) as Dictionary).get("in_line", ""), "in_water = true") and ok
	ok = _check("lowered on the way out",
		(marks.get("in_water", {}) as Dictionary).get("out_line", ""), "in_water = false") and ok

	var toggles: PackedStringArray = PackedStringArray(["in_water = true", "in_water = false"])
	var claims: Array = EventSheetPatternReadings.game_shape_claims(toggles, facts)
	var swim: Dictionary = {}
	for claim: Dictionary in claims:
		if str(claim.get("pattern", "")) == "swim":
			swim = claim
	ok = _check("the two rows claim the swim shape", str(swim.get("pattern", "")), "swim") and ok
	ok = _check("and say what they found in words", str(swim.get("words", "")),
		"in_water is raised on the way into the water and lowered on the way out") and ok
	ok = _check("with the two statements themselves as the evidence",
		swim.get("evidence", PackedStringArray()), toggles) and ok
	return ok


## The sheet a reader ends up with: the two rows the drop offered, and the drag a swimmer writes
## next. Both halves are needed - a boolean nothing swims on is only a boolean, which is exactly the
## gate the water reading applies.
static func _compiled_water_sheet() -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	sheet.variables = {
		EventSheetStarterEvents.WATER_VARIABLE: EventSheetStarterEvents.water_variable_entry()
	}
	for event: EventRow in EventSheetStarterEvents.water_volume_events("WaterVolume", "Area2D"):
		sheet.events.append(event)
	var swimming: EventRow = EventRow.new()
	swimming.trigger_provider_id = "Core"
	swimming.trigger_id = "OnPhysicsProcess"
	var drag: RawCodeRow = RawCodeRow.new()
	drag.code = "velocity *= 0.9"
	swimming.actions.append(drag)
	sheet.events.append(swimming)
	return str(EventSheetCompiler.compile(sheet, "user://water_volume_mark.gd").get("output", ""))


## One census entry, in the shape the object popup is handed.
static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] water_volume_mark_test: %s" % label)
		return true
	print("[FAIL] water_volume_mark_test: %s - expected %s, got %s" % [label, expected, actual])
	return false
