# EventForge - the undo adapter speaks the plain UndoRedo's language as well as the editor's.
# With no editor around (tests, preview harnesses) the dock falls back to a plain UndoRedo, whose
# add_do_method / add_undo_method take ONE Callable. The adapter handed it the editor's spelling
# (object, method, args), so every edit printed "Method expected 1 argument(s), but called with 3"
# and recorded no step. It now binds a Callable there, and commits without running the step,
# because the caller has already applied its edit (and nothing ran at commit before either).
@tool
class_name UndoFallbackTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")


## Records each call it gets, so the test can say which side of the step ran and with what.
class Target:
	extends RefCounted
	var calls: PackedStringArray = PackedStringArray()


	func apply(value: String) -> void:
		calls.append(value)


static func run() -> bool:
	var target: Target = Target.new()
	var undo_redo: UndoRedo = UndoRedo.new()
	var adapter: EventSheetUndoRedoAdapter = EventSheetUndoRedoAdapter.new()
	adapter.set_manager(undo_redo)
	adapter.create_action("Rename")
	adapter.add_do_method(target, "apply", ["after"])
	adapter.add_undo_method(target, "apply", ["before"])
	adapter.commit_action()
	var rows: Array = [
		["the commit records the step", adapter.has_undo(), true],
		["without running it (the edit is already applied)", target.calls.duplicate(), PackedStringArray()],
	]
	adapter.undo()
	rows.append(["undo runs the undo side with its argument", target.calls.duplicate(), PackedStringArray(["before"])])
	rows.append(["and leaves a redo", adapter.has_redo(), true])
	adapter.redo()
	rows.append(["redo runs the do side with its argument", target.calls.duplicate(), PackedStringArray(["before", "after"])])
	undo_redo.free()
	return SUPPORT.pins("undo_fallback_test", rows)
