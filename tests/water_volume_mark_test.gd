# Godot EventSheets - the WATER mark on an area, and the two rows a drop then offers.
#
# The second mark in the object popup, built on the secret mark's seam: a tick that says "this area
# is water", kept in the project's editor metadata so it never reaches the emitted bytes, and read
# by the canvas drop so the object arrives with the rows it was always going to need.
#
# What this pins, in the order the mistakes actually happen:
#   1. THE STORE. The mark round-trips, it belongs to the file that made it, and unticking clears it.
#   2. THE GATE. Only an area is a volume you can be INSIDE, so only Area2D / Area3D can be water. A
#      sprite, a family and a scene file are the negative pins.
#   3. THE ROWS. The two events the offer adds, by VALUE: the two triggers, the object they ride, the
#      shipped Set value row, and the exact statements it writes.
#   4. THE READING. The emitted file claims the swim shape, because `in_water = true` on the way in
#      and `in_water = false` on the way out is literally what the water reading looks for. The flag
#      alone is only a flag, so the drag a swimmer writes next stands in the file beside it - that is
#      the reading's own gate, and this proves the rows land on the right side of it.
@tool
class_name WaterVolumeMarkTest
extends RefCounted

const SHEET_PATH := "res://water_level.gd"
const OTHER_SHEET_PATH := "res://other_level.gd"


static func run() -> bool:
	var ok: bool = true
	ok = _the_mark() and ok
	ok = _who_can_be_water() and ok
	ok = _the_rows() and ok
	ok = _the_reading() and ok
	return ok


## 1. The mark is writable, it is remembered, and it belongs to the file that made it.
static func _the_mark() -> bool:
	var ok: bool = true
	EventSheetObjectProperties.reset_water_flags_for_tests()
	EventSheetObjectProperties.reset_secret_flags_for_tests()
	ok = _check("nothing is water until it is marked",
		EventSheetObjectProperties.is_water(SHEET_PATH, "Pool"), false) and ok
	EventSheetObjectProperties.set_water(SHEET_PATH, "Pool", true)
	ok = _check("marking it sticks",
		EventSheetObjectProperties.is_water(SHEET_PATH, "Pool"), true) and ok
	ok = _check("the mark belongs to the file that made it",
		EventSheetObjectProperties.is_water(OTHER_SHEET_PATH, "Pool"), false) and ok
	ok = _check("and to the object that was ticked",
		EventSheetObjectProperties.is_water(SHEET_PATH, "Lava"), false) and ok
	# The two marks are two stores: water is not secret, and marking one leaves the other alone.
	ok = _check("water is not the secret mark",
		EventSheetObjectProperties.is_secret(SHEET_PATH, "Pool"), false) and ok

	# The popup offers it as a tick box beside the secret one, and says what ticking it does.
	var pool: Dictionary = _entry("Pool", "Area2D", "node")
	var water_row: Dictionary = _row_marked("water", pool)
	ok = _check("the popup offers the mark as a tick box",
		str(water_row.get("label", "")), "Water") and ok
	ok = _check("ticked, it reads back as ticked", bool(water_row.get("checked", false)), true) and ok
	ok = _check("and reads in words", str(water_row.get("value", "")), "Counts as water") and ok
	ok = _check("the tick knows which object it is about",
		str(water_row.get("object", "")), "Pool") and ok
	ok = _check("and which file it writes into", str(water_row.get("source", "")), SHEET_PATH) and ok
	ok = _check("it is the writable form", str(water_row.get("form", "")), "check") and ok
	ok = _check("the secret tick is still there beside it",
		str(_row_marked("secret", pool).get("label", "")), "Secret") and ok

	EventSheetObjectProperties.set_water(SHEET_PATH, "Pool", false)
	ok = _check("unticking it sticks too",
		EventSheetObjectProperties.is_water(SHEET_PATH, "Pool"), false) and ok
	ok = _check("and the row reads the other way round",
		str(_row_marked("water", pool).get("value", "")), "Not water") and ok
	return ok


## 2. Only an area is a volume you can be inside. Everything else is asked no question at all.
static func _who_can_be_water() -> bool:
	var ok: bool = true
	ok = _check("a 2D area can be water",
		EventSheetObjectProperties.can_be_water(_entry("Pool", "Area2D", "node")), true) and ok
	ok = _check("a 3D area can be water",
		EventSheetObjectProperties.can_be_water(_entry("Deep", "Area3D", "node")), true) and ok
	ok = _check("a class that extends an area can be water too",
		EventSheetObjectProperties.can_be_water(_entry("Ocean", "Area2D", "script")), true) and ok
	ok = _check("a sprite cannot",
		EventSheetObjectProperties.can_be_water(_entry("Splash", "Sprite2D", "node")), false) and ok
	ok = _check("a body cannot either",
		EventSheetObjectProperties.can_be_water(_entry("Player", "CharacterBody2D", "node")), false) and ok
	ok = _check("a family is a name, not a volume",
		EventSheetObjectProperties.can_be_water(_entry("swimmers", "", "group")), false) and ok
	ok = _check("a scene file is not a volume either",
		EventSheetObjectProperties.can_be_water(_entry("pool.tscn", "Area2D", "scene")), false) and ok
	ok = _check("and nothing is nothing",
		EventSheetObjectProperties.can_be_water({}), false) and ok
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
		built.contains("func _on_watervolume_body_entered(body: Node) -> void:\n\tin_water = true"),
		true) and ok
	ok = _check("the way out lowers it",
		built.contains("func _on_watervolume_body_exited(body: Node) -> void:\n\tin_water = false"),
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
	return str(SheetCompiler.compile(sheet, "user://water_volume_mark.gd").get("output", ""))


## One census entry, in the shape the object popup is handed.
static func _entry(label: String, host_class: String, kind: String) -> Dictionary:
	return {"label": label, "class": host_class, "kind": kind, "path": label, "rows": 1,
		"verbs": PackedStringArray()}


## The property row carrying one mark's tick box, or {} when the object is not offered that mark.
static func _row_marked(mark: String, entry: Dictionary) -> Dictionary:
	for row: Dictionary in EventSheetObjectProperties.property_rows(entry, "", SHEET_PATH):
		if str(row.get("mark", "")) == mark:
			return row
	return {}


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] water_volume_mark_test: %s" % label)
		return true
	print("[FAIL] water_volume_mark_test: %s - expected %s, got %s" % [label, expected, actual])
	return false
