# Godot EventSheets - the dock follows a switch of the editor theme from a timer, not from the notification
#
# Following a theme switch reads the whole sheet again, which compiles stand-in scripts for the type
# check. A script compile started from inside the engine's own theme notification never returned: the
# editor froze with no thread running, whenever the check's answers had been dropped by a filesystem
# change since the sheet was opened. The suite has no editor and no scene tree to send the notification
# through, so the contract is pinned in the source: the notification branch only asks for the follow-up,
# and the follow-up (which does the work) is reached from the timer alone.
@tool
class_name ThemeFollowDeferredTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME := "theme_follow_deferred_test"
const DOCK := "res://addons/eventsheet/editor/event_sheet_dock.gd"


static func run() -> bool:
	var source: String = FileAccess.get_file_as_string(DOCK)
	var branch_start: int = source.find("elif what == NOTIFICATION_THEME_CHANGED")
	var branch_end: int = source.find("# ── External sheet file watching", branch_start)
	var branch: String = source.substr(branch_start, branch_end - branch_start) if branch_start >= 0 and branch_end > branch_start else ""
	var code_lines: PackedStringArray = PackedStringArray()
	for line: String in branch.split("\n"):
		if not line.strip_edges().begins_with("#"):
			code_lines.append(line)
	var branch_code: String = "\n".join(code_lines)
	var follow_start: int = source.find("func _follow_editor_theme()")
	var follow_end: int = source.find("\n\n\n", follow_start)
	var follow: String = source.substr(follow_start, follow_end - follow_start) if follow_start >= 0 and follow_end > follow_start else ""
	return SUPPORT.pins(NAME, [
		["the notification branch was found", branch_code.is_empty(), false],
		["the notification only schedules the follow-up", branch_code.contains("_schedule_editor_theme_follow()"), true],
		["the notification does not re-seat the sheet itself", branch_code.contains("_apply_editor_native_defaults"), false],
		["the notification does not rebuild the rows itself", branch_code.contains("_follow_editor_icons"), false],
		["the follow-up re-seats the sheet", follow.contains("_apply_editor_native_defaults()"), true],
		["the follow-up follows the icon set", follow.contains("_follow_editor_icons()"), true],
		["the follow-up is reached from a timer", source.contains("create_timer(EDITOR_THEME_FOLLOW_DELAY_SEC).timeout.connect(_follow_editor_theme)"), true],
		["a burst of notifications folds into one follow-up", source.contains("if _editor_theme_follow_pending or not is_inside_tree():"), true],
	])
