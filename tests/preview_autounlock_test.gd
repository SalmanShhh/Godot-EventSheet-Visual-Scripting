# Godot EventSheets — a .gd preview unlocks on the first real edit (no "Edit Events" wall).
#
# Opening a .gd is a read-only preview (a casual look must never overwrite the file — see
# external_sheet_test). But now that .gd is the default format, making the user click "Edit Events"
# before touching their OWN sheet was friction. The first intentional edit (which funnels through
# _perform_undoable_sheet_edit) now auto-unlocks the preview. Saving keeps its own read-only guard,
# so a pure view + Ctrl+S is still protected — external_sheet_test pins that contract.
@tool
class_name PreviewAutounlockTest
extends RefCounted

const PROBE := "user://__eventsheet_autounlock_probe.gd"
const SOURCE := "extends Node\nvar hp: int = 100\nfunc _ready() -> void:\n\tprint(hp)\n"


static func run() -> bool:
	var all_passed: bool = true
	var probe_file: FileAccess = FileAccess.open(PROBE, FileAccess.WRITE)
	probe_file.store_string(SOURCE)
	probe_file.close()

	var editor: EventSheetEditor = EventSheetEditor.new()
	editor._load_sheet_from_path(PROBE)
	# Use the no-manager refresh path so the undo adapter's EditorUndoRedoManager-style calls don't
	# error against the plain-UndoRedo fallback (irrelevant to what this test checks).
	editor._undo_redo_adapter.set_manager(null)
	all_passed = _check("a .gd opens as a read-only preview", editor._current_sheet.read_only, true) and all_passed

	# The first real edit (any mutation through the funnel) auto-unlocks the preview.
	editor._perform_undoable_sheet_edit("probe edit", func() -> bool: return true)
	all_passed = _check("the first edit auto-unlocks the preview", editor._current_sheet.read_only, false) and all_passed
	editor.free()

	if FileAccess.file_exists(PROBE):
		DirAccess.remove_absolute(PROBE)
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] preview_autounlock_test: %s" % label)
		return true
	print("[FAIL] preview_autounlock_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
