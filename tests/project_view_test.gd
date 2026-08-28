# Godot EventSheets - the whole game on one page: the roll-up, the search that reaches every sheet,
# and the refusal to quietly pick a side after a merge.
#
# WHAT THIS PINS:
#  - the roll-up is a JOIN of numbers that already exist and takes its findings and its milliseconds
#    as arguments, so drawing the page can never start a Doctor run or a profiler run,
#  - a sheet nobody profiled shows no millisecond number rather than a zero, because zero is a claim,
#  - rows come back sorted by path whatever order the caller's dictionary was filled in, since a
#    directory walk orders itself differently on different filesystems,
#  - a name is searchable by what was DONE with it: written, read, compared, or as a node, and the
#    facets disagree, which is the entire point of having them,
#  - a merge-damaged file reports BOTH parents' spellings, and the sentence it states names neither
#    as the right one.
@tool
class_name ProjectViewTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# ── The roll-up: one row per sheet, sorted, joining what already exists ──────────────────
	var player: EventSheetResource = _player_sheet()
	var menu: EventSheetResource = _menu_sheet()
	var sheets: Dictionary = {"res://menu.tres": menu, "res://player.tres": player}
	var findings: Array = [
		{"path": "res://player.tres", "severity": "warning", "message": "one"},
		{"path": "res://player.tres", "severity": "info", "message": "two"},
	]
	var rows: Array[Dictionary] = EventSheetProjectViewModel.rows(sheets, findings,
		{"res://player.tres": 4.25})
	var paths: PackedStringArray = PackedStringArray()
	for row: Dictionary in rows:
		paths.append(str(row.get("path", "")))
	all_passed = _check("rows come back sorted by path, not in the order the caller filled its dictionary",
		", ".join(paths), "res://menu.tres, res://player.tres") and all_passed

	var player_row: Dictionary = rows[1]
	all_passed = _check("a sheet is filed under what it runs as",
		str(player_row.get("scene", "")), "Player") and all_passed
	all_passed = _check("the row counts every event, at any depth, including inside functions",
		int(player_row.get("events", 0)), 3) and all_passed
	all_passed = _check("the row carries the description coverage the catalog counted",
		"%d of %d" % [int(player_row.get("described", 0)), int(player_row.get("describable", 0))],
		"1 of 4") and all_passed
	all_passed = _check("the row carries the Doctor's findings for that path, and nobody else's",
		int(player_row.get("findings", 0)), 2) and all_passed
	all_passed = _check("a profiled sheet carries the milliseconds the stored run measured",
		float(player_row.get("milliseconds")), 4.25) and all_passed
	all_passed = _check("a sheet nobody profiled has no millisecond number at all, rather than a zero",
		rows[0].get("milliseconds") == null, true) and all_passed
	all_passed = _check("a sheet with no findings is not blamed for anybody else's",
		int(rows[0].get("findings", 0)), 0) and all_passed
	all_passed = _check("the row states itself in one sentence",
		EventSheetProjectViewModel.row_sentence(player_row),
		"3 event(s), 1 of 4 described, 2 finding(s), 4.3 ms measured") and all_passed

	# ── The search: the same name, different facets, different answers ──────────────────────
	var written: Array[Dictionary] = EventSheetProjectViewModel.find(sheets, "hp",
		EventSheetProjectViewModel.FACET_WRITTEN)
	all_passed = _check("hp written is found where a row assigns it",
		_hit_line(written), "res://player.tres|hurt|SetProperty (target)") and all_passed
	var compared: Array[Dictionary] = EventSheetProjectViewModel.find(sheets, "hp",
		EventSheetProjectViewModel.FACET_COMPARED)
	all_passed = _check("hp compared is found only where a condition tests it",
		_hit_line(compared), "res://player.tres|Damage|CompareVar (var_name)") and all_passed
	var animations: Array[Dictionary] = EventSheetProjectViewModel.find(sheets, "hurt_flash",
		EventSheetProjectViewModel.FACET_ANIMATION)
	all_passed = _check("an animation name is found under the animation facet",
		_hit_line(animations), "res://player.tres|Damage|PlayAnimation (anim_name)") and all_passed
	all_passed = _check("a name nothing carries finds nothing",
		EventSheetProjectViewModel.find(sheets, "nowhere_at_all").size(), 0) and all_passed
	all_passed = _check("an empty query finds nothing rather than everything",
		EventSheetProjectViewModel.find(sheets, "   ").size(), 0) and all_passed

	# ── Merge defence: both parents kept, neither called right ──────────────────────────────
	var clean: String = "func hurt(amount: int) -> void:\n\thp -= amount\n"
	all_passed = _check("a clean file reports no damage, which is the ordinary case",
		EventSheetProjectViewModel.merge_damage(clean).size(), 0) and all_passed
	var damaged: Array[Dictionary] = EventSheetProjectViewModel.merge_damage(_conflicted())
	all_passed = _check("a merge-damaged file reports the one damaged place",
		damaged.size(), 1) and all_passed
	all_passed = _check("this branch's spelling is kept whole",
		str(damaged[0].get("ours", "")), "\thp -= amount") and all_passed
	all_passed = _check("the other branch's spelling is kept whole beside it",
		str(damaged[0].get("theirs", "")), "\thp -= amount * armour") and all_passed
	all_passed = _check("the sentence names both branches and neither as the right one",
		EventSheetProjectViewModel.merge_damage_sentence(damaged[0]),
		"Conflict 1: HEAD against armour-pass came back from a merge with two spellings (HEAD and armour-pass). Both are kept until you pick one.") and all_passed

	return all_passed


## A file a merge left unresolved, in the shape a merge writes it.
static func _conflicted() -> String:
	return "func hurt(amount: int) -> void:\n<<<<<<< HEAD\n\thp -= amount\n=======\n\thp -= amount * armour\n>>>>>>> armour-pass\n"


## Every hit as one line, so a facet's whole answer can be pinned as a value rather than a count.
static func _hit_line(hits: Array[Dictionary]) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for hit: Dictionary in hits:
		lines.append("%s|%s|%s" % [str(hit.get("path", "")), str(hit.get("where", "")), str(hit.get("text", ""))])
	return ", ".join(lines)


## A sheet with a group that tests hp and plays an animation, and a function that writes hp.
static func _player_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Player"
	sheet.class_description = "The player."
	sheet.variables = {"hp": {"type": "int", "value": "10", "description": ""}}

	var tested: EventRow = EventRow.new()
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "CompareVar"
	condition.params = {"var_name": "hp", "op": ">", "value": "0"}
	tested.conditions = [condition]
	var play: ACEAction = ACEAction.new()
	play.provider_id = "Core"
	play.ace_id = "PlayAnimation"
	play.params = {"anim_name": "hurt_flash"}
	tested.actions = [play]

	var group: EventGroup = EventGroup.new()
	group.name = "Damage"
	group.events = [tested]

	var idle: EventRow = EventRow.new()
	sheet.events = [group, idle]

	var hurt: EventFunction = EventFunction.new()
	hurt.function_name = "hurt"
	var write_row: EventRow = EventRow.new()
	var write: ACEAction = ACEAction.new()
	write.provider_id = "Core"
	write.ace_id = "SetProperty"
	write.params = {"target": "hp", "property": "value", "value": "hp - amount"}
	write_row.actions = [write]
	hurt.events = [write_row]
	sheet.functions = [hurt]
	return sheet


## A second sheet, so the roll-up has two rows to sort and the search two sheets to reach.
static func _menu_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Menu"
	return sheet


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] project_view_test: %s" % label)
		return true
	print("[FAIL] project_view_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
