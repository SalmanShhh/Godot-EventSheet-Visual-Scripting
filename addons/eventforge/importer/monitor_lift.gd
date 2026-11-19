# EventForge - the lines Show In Monitors and Remove From Monitors write, read back as one row each.
#
# Both rows are several statements that only mean something together:
#
#     if Performance.has_custom_monitor("Game/Enemies"):
#         Performance.remove_custom_monitor("Game/Enemies")
#     Performance.add_custom_monitor("Game/Enemies", func(): return enemies.size())
#     tree_exiting.connect(func(): if Performance.has_custom_monitor("Game/Enemies"): Performance.remove_custom_monitor("Game/Enemies"))
#
# Claimed as runs so a sheet that picked the row opens as the row it was, and saves back byte for
# byte. The name is shared by every statement, so a run that asks about one graph and adds another is
# somebody else's program and is not claimed. A lone `Performance.add_custom_monitor(...)` keeps the
# reading it has: without the guard before it and the clean-up after it, it is not this row, and
# turning it into one would write lines the author never wrote.
@tool
class_name EventForgeMonitorLift
extends RefCounted

## Built once for the life of the session, like every other family's table.
static var _entries: Array[Dictionary] = []


## The row a run of statements means, or {} when nothing here claims it.
static func match_run(lines: PackedStringArray, index: int, depth: int) -> Dictionary:
	return EventForgeLiftTable.match_run(lift_entries(), lines, index, depth)


## The longer run first, because the two lines the shorter one is are the head of the longer.
static func lift_entries() -> Array[Dictionary]:
	if _entries.is_empty():
		_entries = [_show_entry(), _remove_entry()]
	return _entries


static func _show_entry() -> Dictionary:
	return {
		"id": "monitor_show",
		"ace_id": "ShowInMonitors",
		"mark": "has_custom_monitor(",
		"statements": [
			{"pattern": "^if Performance\\.has_custom_monitor\\((?<name>.+)\\):$"},
			{"pattern": "^Performance\\.remove_custom_monitor\\((?<name>.+)\\)$", "indent": 1},
			{"pattern": "^Performance\\.add_custom_monitor\\((?<name>.+?),[ \\t]*func\\(\\): return (?<value>.+)\\)$"},
			{"pattern": "^tree_exiting\\.connect\\(func\\(\\): if Performance\\.has_custom_monitor\\((?<name>.+?)\\): Performance\\.remove_custom_monitor\\(\\k<name>\\)\\)$"}
		],
		"params": ["name", "value"],
		"shape": "if Performance.has_custom_monitor({name}):\n"
			+ "\tPerformance.remove_custom_monitor({name})\n"
			+ "Performance.add_custom_monitor({name}, func(): return {value})\n"
			+ "tree_exiting.connect(func(): if Performance.has_custom_monitor({name}): Performance.remove_custom_monitor({name}))",
		"slots": {"name": "\"Game/Enemies\"", "value": "enemies.size()"}
	}


static func _remove_entry() -> Dictionary:
	return {
		"id": "monitor_remove",
		"ace_id": "RemoveFromMonitors",
		"mark": "has_custom_monitor(",
		"statements": [
			{"pattern": "^if Performance\\.has_custom_monitor\\((?<name>.+)\\):$"},
			{"pattern": "^Performance\\.remove_custom_monitor\\((?<name>.+)\\)$", "indent": 1}
		],
		"params": ["name"],
		"shape": "if Performance.has_custom_monitor({name}):\n\tPerformance.remove_custom_monitor({name})",
		"slots": {"name": "\"Game/Enemies\""}
	}
