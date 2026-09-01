# EventForge - the undoable tool edits, the one-gesture rule, and the three node dignities.
#
# WHAT IS PINNED HERE, in the order the failures matter:
#
#   1. THE ONE GESTURE. Every undoable row of one event shares ONE step in the editor's history: the
#      action is opened once before the first of them and committed once after the last, with the
#      event's own trigger as its name. Pinned by the exact lines, and by walking the emitted body
#      counting opens against commits - which is what proves the bracket cannot NEST. An event that
#      fires again next frame re-enters a block whose bracket has already closed, so the count never
#      reaches two, and there is no member, flag or static between fires for it to reach two through.
#
#   2. THE REFUSAL. On a sheet that runs in the GAME the same rows are left out and the compile says
#      so in the trigger's own words. The editor's undo history is the editor's; a game has none.
#
#   3. THE ROUND TRIP. Compiled, opened again, recompiled - byte for byte, with the rows coming back
#      as the three undoable rows rather than as a wall of code, and the bracket coming back as
#      nothing at all (it is the compiler's, not a row). A bracket carrying somebody else's action
#      name is left exactly as they wrote it, which is pinned too.
#
#   4. THE THREE DIGNITIES. Set Scene Owner, Duplicate Node (choosing) and Reparent To (choosing),
#      each pinned by the line it emits and each round-tripped - the two one-statement ones through
#      the lift table (whose own harness generates their byte tests), the flagged duplicate through a
#      whole compiled sheet, because an expression is never a statement for a table to anchor to.
#
#   5. THE QUIET FINDING. A tool sheet that changes the open scene the plain way earns the amber
#      state and the Doctor's sentence; the same rows on a game sheet earn nothing, and a @tool sheet
#      that never reaches the edited scene earns nothing either. Nothing is rendered in the sheet.
#
# The frozen neighbours are pinned untouched in the same breath: Duplicate Node still emits
# `duplicate()`, Reparent To still emits `reparent(x)`, Get Scene Owner still reads `{target}.owner`.
@tool
class_name UndoableToolEditsTest
extends RefCounted

const CODEGEN := preload("res://addons/eventforge/compiler/action_codegen.gd")
const UndoableEdits := preload("res://addons/eventforge/undoable_edits.gd")

## The gesture the tool sheets below all compile under - On Editor Run's own display name.
const GESTURE := "On Editor Run"


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_vocabulary() and ok
	ok = _test_the_one_gesture() and ok
	ok = _test_the_refusal_on_a_game_sheet() and ok
	ok = _test_the_round_trip() and ok
	ok = _test_a_foreign_bracket_is_left_alone() and ok
	ok = _test_the_dignities() and ok
	ok = _test_the_quiet_finding() and ok
	return ok


## The three undoable rows exist, are filed on the Undo history page, and say what they emit.
static func _test_the_vocabulary() -> bool:
	var ok: bool = true
	var by_id: Dictionary = _descriptors_by_id()
	for ace_id: String in UndoableEdits.ACE_IDS:
		ok = _check("%s is registered" % ace_id, by_id.has(ace_id), true) and ok
		if not by_id.has(ace_id):
			continue
		var descriptor: ACEDescriptor = by_id[ace_id]
		ok = _check("%s is an Undo history action" % ace_id,
			"%s/%d" % [descriptor.category, descriptor.ace_type],
			"Editor Tools: Undo history/%d" % ACEDescriptor.ACEType.ACTION) and ok
		ok = _check("%s says what it does" % ace_id, descriptor.description.length() > 40, true) and ok
		for parameter: ACEParam in descriptor.params:
			ok = _check("%s.%s says what it is for" % [ace_id, parameter.id],
				parameter.get_param_description().length() > 20, true) and ok
	# Set Property (Undoable) reads the value still in place for the undo half, and names the
	# property exactly as the plain Set Property row names it - which is what makes the two rows
	# swappable without rewriting a value.
	if by_id.has("SetPropertyUndoable"):
		var emitted: String = CODEGEN._apply_template((by_id["SetPropertyUndoable"] as ACEDescriptor).codegen_template,
			{"uid": "7", "target": "$Sign", "property": "text", "value": "\"Open\""})
		# The target is read ONCE, into a local, and every line after it names that local. The field
		# holds an expression, and an expression can answer something different every time it is
		# asked - the removal row's own default does - so three readings would have filed the do
		# half, the undo half and the old value against three different objects.
		ok = _check("Set Property (Undoable) reads its target once and emits its four lines",
			emitted, "\n".join(PackedStringArray([
			"var __node_7: Node = $Sign",
			"var __undo_7 := EditorInterface.get_editor_undo_redo()",
			"__undo_7.add_do_property(__node_7, &\"text\", \"Open\")",
			"__undo_7.add_undo_property(__node_7, &\"text\", __node_7.text)",
		]))) and ok
	if by_id.has("AddNodeUndoable"):
		var emitted_add: String = CODEGEN._apply_template((by_id["AddNodeUndoable"] as ACEDescriptor).codegen_template,
			{"uid": "8", "node": "Sprite2D.new()", "parent": "$Root"})
		ok = _check("Add Node (Undoable) sets the owner in the same step",
			emitted_add.contains("__undo_8.add_do_method(__node_8, \"set_owner\", EditorInterface.get_edited_scene_root())"), true) and ok
		ok = _check("Add Node (Undoable) holds the node for the redo",
			emitted_add.contains("__undo_8.add_do_reference(__node_8)"), true) and ok
		ok = _check("Add Node (Undoable) takes it back out on undo",
			emitted_add.contains("__undo_8.add_undo_method($Root, \"remove_child\", __node_8)"), true) and ok
	if by_id.has("RemoveNodeUndoable"):
		var emitted_remove: String = CODEGEN._apply_template((by_id["RemoveNodeUndoable"] as ACEDescriptor).codegen_template,
			{"uid": "9", "node": "$Crate"})
		ok = _check("Remove Node (Undoable) reads the parent while the node still has one",
			emitted_remove.contains("var __parent_9: Node = __node_9.get_parent()"), true) and ok
		ok = _check("Remove Node (Undoable) restores the owner on the way back",
			emitted_remove.contains("__undo_9.add_undo_method(__node_9, \"set_owner\", EditorInterface.get_edited_scene_root())"), true) and ok
		# WHERE IT WAS INCLUDES WHICH SIBLING IT WAS. `add_child` re-adds as the LAST child, so an
		# undo of a node that was not last would silently reorder the scene - and sibling order is
		# draw order for a CanvasItem and layout order inside a container.
		ok = _check("Remove Node (Undoable) reads the place among its siblings on the way in",
			emitted_remove.contains("var __index_9: int = __node_9.get_index()"), true) and ok
		ok = _check("and puts the node back at it, not merely back under the parent",
			emitted_remove.contains("__undo_9.add_undo_method(__parent_9, \"move_child\", __node_9, __index_9)"),
			true) and ok
	return ok


## THE HEART: one create_action before the first undoable row, one commit_action after the last, the
## event's trigger as the name, and an ordinary row standing between two undoable ones staying inside
## the gesture where the reader put it.
static func _test_the_one_gesture() -> bool:
	var ok: bool = true
	var body: PackedStringArray = _compile(_tool_sheet()).split("\n")
	var opens: int = 0
	var commits: int = 0
	var deepest: int = 0
	for line: String in body:
		var text: String = line.strip_edges()
		if text.begins_with(UndoableEdits.CREATE_PREFIX):
			opens += 1
			deepest = maxi(deepest, opens - commits)
		elif text == UndoableEdits.COMMIT_LINE:
			commits += 1
	ok = _check("one gesture is opened", opens, 1) and ok
	ok = _check("one gesture is committed", commits, 1) and ok
	ok = _check("no gesture is ever open inside another", deepest, 1) and ok
	var text_body: String = "\n".join(body)
	ok = _check("the gesture is named after the event's own trigger",
		text_body.contains(UndoableEdits.create_line(GESTURE)), true) and ok
	var opened_at: int = text_body.find(UndoableEdits.create_line(GESTURE))
	var committed_at: int = text_body.find(UndoableEdits.COMMIT_LINE)
	ok = _check("the plain row between the two undoable ones is inside the gesture",
		opened_at < text_body.find("$Sign.name = \"Signpost\"") and text_body.find("$Sign.name = \"Signpost\"") < committed_at,
		true) and ok
	ok = _check("the first undoable row is inside the gesture",
		opened_at < text_body.find("add_do_property"), true) and ok
	ok = _check("the last undoable row is inside the gesture",
		text_body.find("add_undo_method") < committed_at, true) and ok
	# Two events, two gestures: each closes before the next opens, which is the same shape a single
	# event re-entered on the next frame has - the bracket is a property of the block, not of a flag.
	var twice: PackedStringArray = _compile(_two_event_tool_sheet()).split("\n")
	var order: PackedStringArray = PackedStringArray()
	for line: String in twice:
		var text2: String = line.strip_edges()
		if text2.begins_with(UndoableEdits.CREATE_PREFIX):
			order.append("open")
		elif text2 == UndoableEdits.COMMIT_LINE:
			order.append("commit")
	ok = _check("two events make two gestures that never overlap",
		",".join(order), "open,commit,open,commit") and ok
	return ok


## Outside the editor there is no history to add a step to, so the rows are left out and the compile
## says so in the trigger's own words.
static func _test_the_refusal_on_a_game_sheet() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = _tool_sheet()
	sheet.tool_mode = false
	var result: Dictionary = SheetCompiler.compile(sheet)
	var output: String = str(result.get("output", ""))
	ok = _check("a game sheet opens no gesture", output.contains(UndoableEdits.CREATE_PREFIX), false) and ok
	ok = _check("a game sheet emits no undo half", output.contains("add_undo_property"), false) and ok
	ok = _check("the plain row beside them still compiles",
		output.contains("$Sign.name = \"Signpost\""), true) and ok
	var said: String = "\n".join(PackedStringArray(result.get("warnings", []) as Array))
	ok = _check("the refusal names the trigger", said.contains(GESTURE), true) and ok
	ok = _check("the refusal says what to do about it", said.contains("Tool sheet"), true) and ok
	return ok


## Compiled, opened again, recompiled: the same bytes, and the rows back as rows.
static func _test_the_round_trip() -> bool:
	var ok: bool = true
	var source: String = _compile(_tool_sheet())
	var opened: EventSheetResource = _reopen(source)
	ok = _check("the file opens", opened != null, true) and ok
	if opened == null:
		return ok
	ok = _check("it re-emits byte for byte", _reopened(source), source) and ok
	var read: PackedStringArray = PackedStringArray()
	for row: Variant in opened.events:
		var event_row: EventRow = row as EventRow
		if event_row == null:
			continue
		for entry: Variant in event_row.actions:
			read.append(str((entry as Resource).get("ace_id")))
	ok = _check("the three rows come back as rows", ",".join(read),
		"SetPropertyUndoable,SetNodeName,AddNodeUndoable") and ok
	# The removal run has its own shape (the parent read up front, the reference held by the undo
	# half), so it is round-tripped on its own rather than assumed from the other two.
	var removal: String = _compile(_removal_tool_sheet())
	ok = _check("the removal run re-emits byte for byte", _reopened(removal), removal) and ok
	ok = _check("the removal run comes back as its row",
		_first_action_id(_reopen(removal)), "RemoveNodeUndoable") and ok
	return ok


## A bracket somebody named themselves is not this plugin's bracket, and is left exactly as written.
## The whole file still re-emits, because a function this reading cannot claim stays verbatim.
static func _test_a_foreign_bracket_is_left_alone() -> bool:
	var ok: bool = true
	var mine: String = _compile(_tool_sheet())
	var theirs: String = mine.replace(UndoableEdits.create_line(GESTURE),
		UndoableEdits.create_line("Tidy the props"))
	var opened: EventSheetResource = _reopen(theirs)
	ok = _check("a foreign bracket still opens", opened != null, true) and ok
	if opened == null:
		return ok
	ok = _check("a foreign bracket re-emits exactly as written", _reopened(theirs), theirs) and ok
	ok = _check("a foreign bracket is not read as our rows", _first_action_id(opened), "") and ok
	return ok


## The three small dignities: the write half of the owner, the copy with the three questions asked,
## and the reparent that says which of the two things it meant. Each beside a frozen neighbour that
## is pinned untouched.
static func _test_the_dignities() -> bool:
	var ok: bool = true
	var by_id: Dictionary = _descriptors_by_id()
	ok = _check("Get Scene Owner is untouched",
		_template(by_id, "GetOwner"), "{target}.owner") and ok
	ok = _check("Set Scene Owner writes what Get Scene Owner reads",
		_template(by_id, "SetSceneOwner"), "{target}.owner = {root}") and ok
	ok = _check("Duplicate Node is untouched",
		_template(by_id, "DuplicateNode"), "{target}.duplicate()") and ok
	ok = _check("Reparent To is untouched",
		_template(by_id, "ReparentNode"), "reparent({new_parent})") and ok
	ok = _check("Reparent To (choosing) says which",
		_template(by_id, "ReparentToChoosing"), "reparent({new_parent}, {keep})") and ok
	# The choosing reparent borrows Add Child (existing node)'s own words for the same question, so
	# one choice reads one way wherever it is asked and one translated string answers both.
	ok = _check("the two rows word the choice identically",
		_option_labels(by_id, "ReparentToChoosing", "keep"),
		_option_labels(by_id, "HierarchyAddChild", "keep")) and ok
	var duplicate: String = CODEGEN._apply_template(_template(by_id, "DuplicateNodeChoosing"),
		{"target": "$Crate", "signals": "false", "groups": "true", "scripts": "false"})
	ok = _check("the copy names Godot's own flags", duplicate,
		"$Crate.duplicate(Node.DUPLICATE_SIGNALS * int(false) | Node.DUPLICATE_GROUPS * int(true) | Node.DUPLICATE_SCRIPTS * int(false))") and ok
	for boxed: String in ["signals", "groups", "scripts"]:
		ok = _check("%s is a checkbox" % boxed,
			_param_type_name(by_id, "DuplicateNodeChoosing", boxed), "bool") and ok
	# The flagged duplicate is an expression, so no lift-table entry can anchor to it - the byte
	# question is asked of a whole compiled sheet instead.
	var dignity_source: String = _compile(_dignity_sheet())
	ok = _check("the dignity rows emit their three lines", dignity_source.contains("\n".join(PackedStringArray([
		"\t$Crate.owner = get_tree().current_scene",
		"\tvar __copy := $Crate.duplicate(Node.DUPLICATE_SIGNALS * int(false) | Node.DUPLICATE_GROUPS * int(true) | Node.DUPLICATE_SCRIPTS * int(true))",
		"\treparent($Hand, false)",
	]))), true) and ok
	ok = _check("the dignity rows re-emit byte for byte", _reopened(dignity_source), dignity_source) and ok
	ok = _check("the owner line reads as Set Scene Owner",
		_first_action_id(_reopen(dignity_source)), "SetSceneOwner") and ok
	return ok


## The quiet amber state, and the three questions it answers no to.
static func _test_the_quiet_finding() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = _plain_edit_tool_sheet()
	var found: Array[Dictionary] = EventSheetUndoableFindings.findings(sheet, "res://tools/tidy.gd")
	ok = _check("one plain edit earns one finding", found.size(), 1) and ok
	if found.is_empty():
		return ok
	var finding: Dictionary = found[0]
	ok = _check("it is filed as the Doctor files it", str(finding.get("kind", "")),
		EventSheetToolEditsDoctor.CHECK_NOT_UNDOABLE) and ok
	ok = _check("it names the row to reach for", str(finding.get("to", "")), "SetPropertyUndoable") and ok
	ok = _check("it names the slot the door rewrites", "%s/%d" % [
		str(finding.get("lane", "")), int(finding.get("index", -1))], "action/0") and ok
	ok = _check("its sentence says the file and the line",
		str(finding.get("message", "")).contains("tidy.gd") \
			and str(finding.get("message", "")).contains("Set Property (Undoable)"), true) and ok
	ok = _check("it is anchored at the event", EventSheetUndoableFindings.for_event(
		found, sheet.events[0] as EventRow).size(), 1) and ok
	# The door: the same row, respelled - values untouched, baked spelling cleared so the twin's own
	# template answers.
	var before: Dictionary = ((sheet.events[0] as EventRow).actions[0] as Resource).get("params")
	ok = _check("the door respells the row", EventSheetUndoableFindings.make_it_undoable(finding), true) and ok
	var after_row: Resource = (sheet.events[0] as EventRow).actions[0]
	ok = _check("the row is now the undoable twin", str(after_row.get("ace_id")), "SetPropertyUndoable") and ok
	ok = _check("its values are untouched", after_row.get("params"), before) and ok
	ok = _check("its old spelling is cleared", str(after_row.get("codegen_template")), "") and ok
	ok = _check("nothing is left to report",
		EventSheetUndoableFindings.findings(sheet, "res://tools/tidy.gd").size(), 0) and ok
	# The three no-answers.
	var game_sheet: EventSheetResource = _plain_edit_tool_sheet()
	game_sheet.tool_mode = false
	ok = _check("a game sheet is simply correct",
		EventSheetUndoableFindings.findings(game_sheet).size(), 0) and ok
	var own_business: EventSheetResource = _own_business_tool_sheet()
	ok = _check("a tool that never reaches the open scene is left alone",
		EventSheetUndoableFindings.edits_the_open_scene(own_business), false) and ok
	ok = _check("and so reports nothing",
		EventSheetUndoableFindings.findings(own_business).size(), 0) and ok
	# The Doctor says the same sentence over the same finding.
	var reported: Array[Dictionary] = EventSheetToolEditsDoctor.script_findings("res://tools/tidy.gd", found)
	ok = _check("the Doctor files it as a warning", str(reported[0].get("severity", "")), "warning") and ok
	ok = _check("the Doctor's line is the finding's own sentence",
		str(reported[0].get("message", "")), str(finding.get("message", ""))) and ok
	return ok


## A tool sheet whose one event makes two undoable edits with a plain row between them.
static func _tool_sheet() -> EventSheetResource:
	var sheet := EventSheetResource.new()
	sheet.tool_mode = true
	sheet.host_class = "Node"
	sheet.events.append(_event("e1", [
		["SetPropertyUndoable", {"target": "$Sign", "property": "text", "value": "\"Open\""}],
		["SetNodeName", {"target": "$Sign", "name": "\"Signpost\""}],
		["AddNodeUndoable", {"node": "Node2D.new()", "parent": "EditorInterface.get_edited_scene_root()"}],
	]))
	return sheet


## Two events, each with an undoable edit of its own.
static func _two_event_tool_sheet() -> EventSheetResource:
	var sheet := EventSheetResource.new()
	sheet.tool_mode = true
	sheet.host_class = "Node"
	sheet.events.append(_event("e1", [
		["SetPropertyUndoable", {"target": "$Sign", "property": "text", "value": "\"Open\""}]]))
	sheet.events.append(_event("e2", [
		["SetPropertyUndoable", {"target": "$Gate", "property": "text", "value": "\"Shut\""}]]))
	return sheet


## A tool sheet whose one event takes a node back out of the open scene.
static func _removal_tool_sheet() -> EventSheetResource:
	var sheet := EventSheetResource.new()
	sheet.tool_mode = true
	sheet.host_class = "Node"
	sheet.events.append(_event("e1", [
		["RemoveNodeUndoable", {"node": "EditorInterface.get_selection().get_selected_nodes().pop_front()"}]]))
	return sheet


## A game sheet using the three dignities, which have nothing to do with the editor.
static func _dignity_sheet() -> EventSheetResource:
	var sheet := EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.events.append(_event("e1", [
		["SetSceneOwner", {"target": "$Crate", "root": "get_tree().current_scene"}],
		["SetLocalVarInferred", {"name": "__copy", "value": "$Crate.duplicate(Node.DUPLICATE_SIGNALS * int(false) | Node.DUPLICATE_GROUPS * int(true) | Node.DUPLICATE_SCRIPTS * int(true))"}],
		["ReparentToChoosing", {"new_parent": "$Hand", "keep": "false"}],
	]))
	return sheet


## A tool sheet that reaches the open scene and then changes it the plain way.
static func _plain_edit_tool_sheet() -> EventSheetResource:
	var sheet := EventSheetResource.new()
	sheet.tool_mode = true
	sheet.host_class = "Node"
	sheet.events.append(_event("e1", [
		["SetProperty", {"target": "$Sign", "property": "text", "value": "\"Open\""}],
		["SelectNodeInEditor", {"node": "EditorInterface.get_edited_scene_root()"}],
	]))
	return sheet


## The same tool, minding its own business: it sets a property on itself and never reaches for the
## scene the editor has open, which is every ordinary @tool node script ever written.
static func _own_business_tool_sheet() -> EventSheetResource:
	var sheet := EventSheetResource.new()
	sheet.tool_mode = true
	sheet.host_class = "Node"
	sheet.events.append(_event("e1", [
		["SetProperty", {"target": "self", "property": "visible", "value": "true"}]]))
	return sheet


## One On Editor Run event holding the given rows, with each row's `{uid}` baked the way the dock
## bakes it at apply time - a row built in memory has nobody else to do it.
static func _event(uid: String, rows: Array) -> EventRow:
	var event := EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnEditorRun"
	event.event_uid = uid
	for pair: Array in rows:
		var action := ACEAction.new()
		action.provider_id = "Core"
		action.ace_id = str(pair[0])
		action.params = pair[1]
		var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", str(pair[0]))
		if descriptor != null:
			action.codegen_template = descriptor.codegen_template.replace(
				"{uid}", "%s%d" % [uid, event.actions.size()])
		event.actions.append(action)
	return event


## The sheet as a file. Compiled through a named output path (the external emission path) on BOTH
## sides of a round trip, because that is the path a `.gd`-backed sheet really takes: the plain
## in-memory compile regenerates the prelude that an opened file already carries as its own rows, so
## comparing the two would compare a file against a file with two preludes.
static func _compile(sheet: EventSheetResource, path: String = "user://eventforge_undoable_src.gd") -> String:
	return str(SheetCompiler.compile(sheet, path).get("output", ""))


## The same file, opened and written again - the byte question every lift has to answer.
static func _reopened(source: String) -> String:
	var opened: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	if opened == null:
		return ""
	opened.external_source_path = "user://eventforge_undoable_roundtrip.gd"
	return _compile(opened, "user://eventforge_undoable_roundtrip.gd")


## The same file, opened - for the questions that are about the ROWS rather than the bytes.
static func _reopen(source: String) -> EventSheetResource:
	var opened: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	if opened != null:
		opened.external_source_path = "user://eventforge_undoable_roundtrip.gd"
	return opened


static func _first_action_id(sheet: EventSheetResource) -> String:
	if sheet == null:
		return ""
	for row: Variant in sheet.events:
		var event_row: EventRow = row as EventRow
		if event_row != null and not event_row.actions.is_empty():
			return str((event_row.actions[0] as Resource).get("ace_id"))
	return ""


static func _descriptors_by_id() -> Dictionary:
	var by_id: Dictionary = {}
	for descriptor: ACEDescriptor in ACERegistry.get_all_descriptors():
		by_id[descriptor.ace_id] = descriptor
	return by_id


static func _template(by_id: Dictionary, ace_id: String) -> String:
	return "" if not by_id.has(ace_id) else (by_id[ace_id] as ACEDescriptor).codegen_template


static func _option_labels(by_id: Dictionary, ace_id: String, param_id: String) -> String:
	if not by_id.has(ace_id):
		return "<missing %s>" % ace_id
	for parameter: ACEParam in (by_id[ace_id] as ACEDescriptor).params:
		if parameter.id == param_id:
			var labels: PackedStringArray = PackedStringArray()
			for option: Variant in parameter.options:
				labels.append(str((option as Dictionary).get("label", "")))
			return ",".join(labels)
	return "<missing %s.%s>" % [ace_id, param_id]


static func _param_type_name(by_id: Dictionary, ace_id: String, param_id: String) -> String:
	if not by_id.has(ace_id):
		return "<missing %s>" % ace_id
	for parameter: ACEParam in (by_id[ace_id] as ACEDescriptor).params:
		if parameter.id == param_id:
			return parameter.type_name
	return "<missing %s.%s>" % [ace_id, param_id]


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] undoable_tool_edits_test: %s" % label)
		return true
	print("[FAIL] undoable_tool_edits_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
