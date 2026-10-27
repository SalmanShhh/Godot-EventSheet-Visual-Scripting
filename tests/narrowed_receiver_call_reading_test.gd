# Godot EventSheets - a call on a value the event has checked the class of reads with that class's
# own parameter names.
#
# In a user's enemy script, `_on_body_entered(body: Node2D)` guards with `if body is Player:` and then
# calls `body.take_damage(damage)`. The row read "Take damage   damage": the value chip had no name,
# because the reading only knew `body` as the Node2D the handler was handed. GDScript itself narrows
# `body` to Player under that `is` question, and so does the reading now - the chip says which of the
# method's parameters the value fills. A negated question narrows nothing.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "narrowed_receiver_call_reading_test"

## A project class with a method of its own stands in for the user's Player: the pack's health
## behaviour, whose `take_damage(amount: float)` names its parameter.
const SOURCE := """extends Area2D

@export var damage := 1.0


func _on_body_entered(body: Node2D) -> void:
	if body is SimpleHealthBehavior:
		body.take_damage(damage)
"""


static func run() -> bool:
	var narrowed: String = _call_reading(SOURCE, "narrowed")
	var not_narrowed: String = _call_reading(SOURCE.replace("if body is SimpleHealthBehavior:",
		"if not body is SimpleHealthBehavior:"), "negated")
	return SUPPORT.pins(P, [
		["a call under the event's own is question names the parameter its value fills",
			narrowed, "Take damage   amount = damage"],
		["a negated question settles no class", not_narrowed, "Take damage   damage"],
	])


## The words of the row that makes the call, read in the editor itself.
static func _call_reading(source: String, tag: String) -> String:
	var path: String = "user://narrowed_receiver_%s.gd" % tag
	var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	handle.store_string(source)
	handle.close()
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(GDScriptImporter.new().import_external(path))
	var said: String = ""
	for entry: Dictionary in dock._active_view().get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data == null:
			continue
		for span: SemanticSpan in row_data.spans:
			if span.text.to_lower().contains("damage") and str(span.metadata.get("lane", "")) == "action":
				said = span.text
	dock.free()
	return said
