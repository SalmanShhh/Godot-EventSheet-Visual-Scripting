# Godot EventSheets — an unlocked .gd sheet stays editable across an editor restart.
#
# Opening a .gd lands on a read-only preview; clicking "Edit Events" unlocks it. Previously the
# session restore re-opened every .gd as a fresh read-only preview, so a sheet you were editing came
# back LOCKED on every restart — friction, especially now that .gd is the default format. The session
# now records which sheets were unlocked and restores that state.
@tool
class_name SessionEditableRestoreTest
extends RefCounted

const PROBE := "user://__eventsheet_session_probe.gd"
const SESSION := "user://eventsheets_session.cfg"


static func run() -> bool:
	var all_passed: bool = true
	# Back up any real session so the test never clobbers it.
	var had_session: bool = FileAccess.file_exists(SESSION)
	var backup: String = FileAccess.get_file_as_string(SESSION) if had_session else ""

	var probe_file: FileAccess = FileAccess.open(PROBE, FileAccess.WRITE)
	probe_file.store_string("extends Node\nfunc _ready() -> void:\n\tprint(\"hi\")\n")
	probe_file.close()

	# Session A: open the .gd (read-only preview), unlock it via "Edit Events", which persists.
	var dock_a: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock_a.setup(null)
	dock_a._session._session_tracking = true  # restore normally flips this on; do it manually for the test
	dock_a._load_sheet_from_path(PROBE)
	all_passed = _check("opening a .gd is a read-only preview", dock_a._current_sheet.read_only, true) and all_passed
	dock_a._on_preview_edit_requested()
	all_passed = _check("Edit Events unlocks it", dock_a._current_sheet.read_only, false) and all_passed
	dock_a.free()

	# Session B: a fresh dock restores the session — the unlocked .gd must come back editable.
	var dock_b: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock_b.setup(null)  # _session_tracking is false until _restore_session runs, so this won't overwrite the saved session
	dock_b._restore_session()
	var restored: EventSheetResource = null
	for tab: Dictionary in dock_b._open_tabs:
		if str(tab.get("path", "")) == PROBE:
			restored = tab.get("sheet") as EventSheetResource
			break
	all_passed = _check("the .gd tab was restored", restored != null, true) and all_passed
	if restored != null:
		all_passed = _check("an unlocked .gd stays editable across restart", restored.read_only, false) and all_passed
	dock_b.free()

	# Cleanup: remove the probe and restore the original session file.
	if FileAccess.file_exists(PROBE):
		DirAccess.remove_absolute(PROBE)
	if had_session:
		var restore_file: FileAccess = FileAccess.open(SESSION, FileAccess.WRITE)
		restore_file.store_string(backup)
		restore_file.close()
	elif FileAccess.file_exists(SESSION):
		DirAccess.remove_absolute(SESSION)
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] session_editable_restore_test: %s" % label)
		return true
	print("[FAIL] session_editable_restore_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
