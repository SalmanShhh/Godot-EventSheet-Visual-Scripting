# Godot EventSheets - the compiler only rewrites the generated .gd when its content changed.
#
# Rewriting a byte-identical file bumps its mtime and makes the Godot editor prompt
# "Files have been modified outside Godot" on every scene open/close - alarming users into
# thinking they broke something. SheetCompiler skips the write when the on-disk content already
# matches. This pins that contract: missing -> writes; identical -> skips (no-op, content stable);
# different -> writes the new content.
@tool
class_name WriteIfChangedTest
extends RefCounted

const P: String = "user://eventsheets_write_guard_test.gd"


static func run() -> bool:
	var ok: bool = true
	_cleanup()

	# Missing file: not current, and the write creates it.
	ok = _check("not current when file is missing", SheetCompiler._output_is_current(P, "A\n"), false) and ok
	ok = _check("writes when missing (returns true)", SheetCompiler._write_output_if_changed(P, "A\n"), true) and ok
	ok = _check("file holds A after first write", FileAccess.get_file_as_string(P), "A\n") and ok

	# Identical content: now current, so the write is a no-op skip (still succeeds, content stable).
	ok = _check("current when on-disk content is identical", SheetCompiler._output_is_current(P, "A\n"), true) and ok
	ok = _check("no-op write returns true", SheetCompiler._write_output_if_changed(P, "A\n"), true) and ok
	ok = _check("file unchanged after no-op", FileAccess.get_file_as_string(P), "A\n") and ok

	# Changed content: not current, so the write replaces it.
	ok = _check("not current when content differs", SheetCompiler._output_is_current(P, "B\n"), false) and ok
	ok = _check("writes changed content (returns true)", SheetCompiler._write_output_if_changed(P, "B\n"), true) and ok
	ok = _check("file holds B after change", FileAccess.get_file_as_string(P), "B\n") and ok

	_cleanup()
	return ok


static func _cleanup() -> void:
	if FileAccess.file_exists(P):
		DirAccess.remove_absolute(P)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] write_if_changed_test: %s" % label)
		return true
	print("[FAIL] write_if_changed_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
