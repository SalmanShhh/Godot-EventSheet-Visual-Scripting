# EventForge - the undo bracket, proved against the editor's real undo manager.
#
# The suite pins the bracket by reading the emitted text: one create_action before the first
# undoable row of an event, one commit_action after the last, and never one inside another. That is
# the shape. This harness asks the other half of the question - whether the shape does what it says
# once the editor's own EditorUndoRedoManager is holding it:
#
#   ONE EVENT IS ONE STEP.  Three undoable rows in one event add ONE entry to the history.
#   CTRL+Z PUTS EVERYTHING BACK.  That one undo restores every property the event touched and takes
#                                 the added node back out.
#   RE-TRIGGERING DOES NOT NEST.  Firing the same event again and again adds one entry per fire and
#                                 never leaves an action open.
#
# IT CANNOT BE A TEST, and the reason is the whole point of it: EditorInterface.get_editor_undo_redo()
# answers null until the editor itself is up, so the check has to run INSIDE a running editor rather
# than in the headless script the suite is. Drive it from an EditorPlugin's _enter_tree:
#
#   const Probe := preload("res://tools/verify_undo_bracket.gd")
#   func _enter_tree() -> void:
#       (func() -> void: Probe.run()).call_deferred()
#
# with that plugin enabled, then `<godot> --editor --headless --path . --quit-after 60`.
@tool
extends RefCounted

## Where the compiled tool is written before it is loaded back and run. Outside the project, so a
## run of this harness never leaves a file in the repository.
const COMPILED_PATH: String = "user://eventforge_undo_bracket_probe.gd"

## The event's own trigger, which is what the gesture is named after.
const TRIGGER_ID: String = "OnEditorRun"


## Runs the three questions and prints one verdict line. True when the bracket held.
static func run() -> bool:
	var failures: PackedStringArray = PackedStringArray()
	var reached_the_end: bool = _check_the_bracket(failures)
	if not reached_the_end:
		failures.append("the probe did not reach its end - something above threw")
	if failures.is_empty():
		print("verify_undo_bracket: the bracket holds - one event is one step, and it does not nest.")
		return true
	for line: String in failures:
		print("[FAIL] verify_undo_bracket: %s" % line)
	print("verify_undo_bracket: the bracket did NOT hold.")
	return false


## The body, returning true only when it ran all the way through - a runtime error inside it leaves
## the failure list empty, which would otherwise read as a pass.
static func _check_the_bracket(failures: PackedStringArray) -> bool:
	var source: String = _compiled_tool()
	if source.is_empty():
		failures.append("the tool sheet did not compile")
		return true
	var handler: String = _trigger_function(source)
	if handler.is_empty():
		failures.append("the compiled tool has no trigger function to call\n%s" % source)
		return true
	var script: GDScript = _loaded(source)
	if script == null:
		failures.append("the compiled tool did not load\n%s" % source)
		return true
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if manager == null:
		failures.append("the editor has no undo manager yet - run this from inside a running editor")
		return true

	var host: Node = Node.new()
	host.name = "Host"
	host.set_script(script)
	var marker := Node2D.new()
	marker.name = "Sign"
	host.add_child(marker)
	Engine.get_main_loop().root.add_child(host)

	var history: UndoRedo = manager.get_history_undo_redo(manager.get_object_history_id(marker))
	var version_before: int = history.get_version()
	var entries_before: int = history.get_history_count()

	host.call(handler)

	_check(failures, "the first property really changed", marker.position, Vector2(5, 7))
	_check(failures, "the second property really changed", marker.rotation, 1.5)
	_check(failures, "the added node really landed", marker.get_child_count(), 1)
	_check(failures, "one event left ONE entry in the history",
		history.get_history_count() - entries_before, 1)
	_check(failures, "the entry is named after the event's own trigger",
		history.get_current_action_name(), _gesture_words())
	_check(failures, "the history really moved", history.get_version() != version_before, true)

	history.undo()
	_check(failures, "Ctrl+Z put the first property back", marker.position, Vector2.ZERO)
	_check(failures, "Ctrl+Z put the second property back", marker.rotation, 0.0)
	_check(failures, "Ctrl+Z took the added node back out", marker.get_child_count(), 0)

	# Back to the tip before the next question is asked. Committing an action while the history sits
	# on an undone one THROWS THAT ONE AWAY - ordinary undo semantics in every editor there is, and
	# nothing to do with the bracket - so counting fires from there would count one of them against
	# a discarded entry and report a nesting bug that is not there.
	history.redo()

	# Re-triggering: the same event fired again and again, the way a per-frame tool fires. Each fire
	# is its own entry and none of them is opened inside another - a bracket that could nest would
	# leave an action open and the count would stop moving one per fire.
	var entries_at_replay: int = history.get_history_count()
	for _fire: int in 3:
		host.call(handler)
	_check(failures, "three more fires left three more entries",
		history.get_history_count() - entries_at_replay, 3)
	_check(failures, "and the last of them is still the same one gesture",
		history.get_current_action_name(), _gesture_words())
	_check(failures, "each fire really ran", marker.get_child_count(), 4)
	history.undo()
	_check(failures, "undoing after a rapid re-trigger takes back exactly one fire",
		marker.get_child_count(), 3)

	host.queue_free()
	return true


## The words the gesture is named after: the trigger's own display name, read off the registry the
## compiler reads it off, so this harness cannot drift from the emission it is checking.
static func _gesture_words() -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", TRIGGER_ID)
	return "" if descriptor == null else descriptor.display_name


## A tool sheet whose ONE event makes three undoable changes: two properties of a node and a node
## added under it. Three rows, so "one event is one step" is a claim with something to prove.
static func _compiled_tool() -> String:
	var sheet := EventSheetResource.new()
	sheet.tool_mode = true
	sheet.host_class = "Node"
	var event := EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = TRIGGER_ID
	event.event_uid = "probe"
	_add_row(event, "SetPropertyUndoable",
		{"target": "$Sign", "property": "position", "value": "Vector2(5, 7)"})
	_add_row(event, "SetPropertyUndoable",
		{"target": "$Sign", "property": "rotation", "value": "1.5"})
	_add_row(event, "AddNodeUndoable", {"node": "Node2D.new()", "parent": "$Sign"})
	sheet.events.append(event)
	return str(SheetCompiler.compile(sheet, COMPILED_PATH).get("output", ""))


## One row, with its `{uid}` baked the way the dock bakes it at apply time - a row built in memory
## has nobody else to do it.
static func _add_row(event: EventRow, ace_id: String, params: Dictionary) -> void:
	var action := ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	if descriptor != null:
		action.codegen_template = descriptor.codegen_template.replace(
			"{uid}", "probe%d" % event.actions.size())
	event.actions.append(action)


## The name of the function the trigger compiled to, read out of the emitted text rather than
## assumed, so a trigger that changes how it is spelled is reported instead of silently skipped.
static func _trigger_function(source: String) -> String:
	for line: String in source.split("\n"):
		if not line.begins_with("func "):
			continue
		var name_end: int = line.find("(")
		if name_end < 0:
			continue
		if line.substr(name_end).begins_with("()"):
			return line.substr(5, name_end - 5)
	return ""


## The compiled tool as a script that can be attached and called. Written outside the project as
## well, so the emitted file is there to read when a run reports something surprising.
static func _loaded(source: String) -> GDScript:
	var file: FileAccess = FileAccess.open(COMPILED_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(source)
		file.close()
	var script := GDScript.new()
	script.source_code = source
	return script if script.reload() == OK else null


static func _check(failures: PackedStringArray, label: String, got: Variant, expected: Variant) -> void:
	if got != expected:
		failures.append("%s -> expected %s, got %s" % [label, expected, got])
