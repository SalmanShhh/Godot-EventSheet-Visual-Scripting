# Godot EventSheets - removing a thing, without leaving a ghost behind.
#
# What this gate holds, in the order the mistakes actually happen:
#   1. THE LINES. Each removal row is a plain queue_free with a stated wait in front of it, and all
#      of them are pinned as the exact statements they write. The fade row's own guard is part of its
#      template, so the check it does after the await is pinned there too.
#   2. THE GUARD IS WRITTEN WHERE IT IS NEEDED, AND THE FILE IT WROTE INTO STILL PARSES. A row whose
#      object is a variable holding a node - the one name that outlives the line that set it -
#      compiles inside `if is_instance_valid(...)`, indented under it, and the emitted script is
#      loaded to prove it. A row on `self`, a node path, or a copy a spawn row minted in ANOTHER
#      event does not: the first two cannot dangle, and the third is a local the other event cannot
#      say at all, so a guard there would only wrap a line that does not compile.
#   3. AND IT STANDS DOWN WHEN THE SHEET ALREADY ASKED. An event whose own condition is the question,
#      or whose parent's is, gets ONE guard, not two - and a file written that way by hand re-emits
#      byte for byte, which is the whole reason the stand-down exists.
#   4. THE ECHO IS THE FILE. The line the row shows is the same string the compiler wrote, from the
#      same function, so the sheet cannot claim a guard the file does not hold.
#   5. THE HAND-WRITTEN CHAINS LIFT. The timer one-liner and the tween one-liner people write open as
#      these rows and save back as their own bytes.
#
# Values are pinned, never counts: a count would go on passing while the wrong line moved.
@tool
class_name RemovalSentenceTest
extends RefCounted

## The scene the fixtures spawn when they need a name that was minted somewhere.
const BULLET: String = "load(\"res://bullet.tscn\")"


static func run() -> bool:
	var passed: bool = true
	passed = _test_the_descriptors_say_what_they_emit() and passed
	passed = _test_the_rows_write_their_lines() and passed
	passed = _test_the_guard_is_written_where_it_is_needed() and passed
	passed = _test_the_guard_reaches_inside_a_match_case() and passed
	passed = _test_the_guard_stands_down_when_the_sheet_already_asked() and passed
	passed = _test_the_echo_is_the_line_the_file_holds() and passed
	passed = _test_the_hand_written_chains_lift() and passed
	return passed


# ── 1. The descriptors ──


static func _test_the_descriptors_say_what_they_emit() -> bool:
	var passed: bool = true
	var by_id: Dictionary = _descriptors()
	passed = _check("Remove Now is the plain call",
		str(by_id.get("RemoveNow", ACEDescriptor.new()).codegen_template), "{object}.queue_free()") and passed
	passed = _check("Remove After Seconds hangs the free off a scene-tree timer",
		str(by_id.get("RemoveAfterSeconds", ACEDescriptor.new()).codegen_template),
		"get_tree().create_timer({seconds}).timeout.connect({object}.queue_free)") and passed
	passed = _check("Fade Out Then Remove tweens, waits, and asks again before it removes",
		str(by_id.get("FadeOutAndRemove", ACEDescriptor.new()).codegen_template),
		"await {object}.create_tween().tween_property({object}, \"modulate:a\", 0.0, {seconds}).finished\n"
		+ "if is_instance_valid({object}):\n\t{object}.queue_free()") and passed
	passed = _check("Is Still Here asks Godot's own question",
		str(by_id.get("IsStillHere", ACEDescriptor.new()).codegen_template), "is_instance_valid({object})") and passed
	# What the rows open on: this node, and waits a reader would choose anyway.
	passed = _check("a removal row opens on this node", _default_of(by_id.get("RemoveNow", null), "object"), "self") and passed
	passed = _check("the timer row opens on two seconds", _default_of(by_id.get("RemoveAfterSeconds", null), "seconds"), "2.0") and passed
	passed = _check("the fade row opens on half a second", _default_of(by_id.get("FadeOutAndRemove", null), "seconds"), "0.5") and passed
	# The thing people get wrong about queue_free is WHEN, so the row has to say it.
	passed = _check("Remove Now teaches that the deletion lands at the end of the frame",
		str(by_id.get("RemoveNow", ACEDescriptor.new()).description).contains("END of this frame"), true) and passed
	# On Destroyed is the shipped trigger and is pointed AT rather than duplicated here.
	passed = _check("the question points at the shipped trigger for a node's own removal",
		str(by_id.get("IsStillHere", ACEDescriptor.new()).description).contains("On Exit Tree"), true) and passed
	# The two sentences that stand beside a frozen row writing the identical line author only; the
	# shipped rows keep the reading of those lines.
	passed = _check("Remove Now leaves the reading of a queue_free line to the shipped row",
		EventSheetACELifter.REVERSE_LIFT_EXCLUDED_ACE_IDS.has("RemoveNow"), true) and passed
	passed = _check("Is Still Here leaves the reading of an is_instance_valid line to the shipped row",
		EventSheetACELifter.REVERSE_LIFT_EXCLUDED_ACE_IDS.has("IsStillHere"), true) and passed
	return passed


# ── 2. The lines ──


static func _test_the_rows_write_their_lines() -> bool:
	var passed: bool = true
	passed = _check("Remove Now writes the call on the object it names",
		_compiled_with("RemoveNow", {"object": "$Enemy"}, "user://eventforge_remove_now.gd")
			.contains("\t$Enemy.queue_free()"), true) and passed
	passed = _check("Remove After Seconds writes the timer, the signal and the free",
		_compiled_with("RemoveAfterSeconds", {"object": "$Enemy", "seconds": "2.0"}, "user://eventforge_remove_later.gd")
			.contains("\tget_tree().create_timer(2.0).timeout.connect($Enemy.queue_free)"), true) and passed
	var faded: String = _compiled_with("FadeOutAndRemove", {"object": "$Ghost", "seconds": "0.5"},
		"user://eventforge_remove_faded.gd")
	passed = _check("Fade Out Then Remove waits for its own tween",
		faded.contains("\tawait $Ghost.create_tween().tween_property($Ghost, \"modulate:a\", 0.0, 0.5).finished"), true) and passed
	passed = _check("and asks again after the wait, in the sheet's own lines",
		faded.contains("\tif is_instance_valid($Ghost):\n\t\t$Ghost.queue_free()"), true) and passed
	return passed


# ── 3. The guard ──


static func _test_the_guard_is_written_where_it_is_needed() -> bool:
	var passed: bool = true
	# A STORED NODE REFERENCE: a sheet variable typed as a node survives from frame to frame, so
	# nothing about this event put the value there and nothing about this event can vouch for it.
	var stored: EventSheetResource = _sheet()
	stored.variables = {"held_enemy": {"type": "Node2D", "default": null, "exported": false}}
	stored.events.append(_event([_action("RemoveNow", {"object": "held_enemy"})]))
	var stored_output: String = _compile(stored, "user://eventforge_remove_stored.gd")
	passed = _check("a stored node reference is removed inside the guard",
		stored_output.contains("\tif is_instance_valid(held_enemy):\n\t\theld_enemy.queue_free()"), true) and passed
	# AND THE GUARDED FILE PARSES. The guard writes a line into somebody's script; a pin on the text
	# says the line is there and says nothing about whether the file still loads.
	passed = _check("and the file the guard wrote into still parses",
		_parses(stored_output), true) and passed

	# A NAME MINTED IN ANOTHER EVENT IS NOT GUARDED, and the reason is scope rather than safety. A
	# spawn row's name is a LOCAL, scoped to the handler it was written in (and, under a condition, to
	# that `if`), so a removal row in a different event does not compile whether it is wrapped or not:
	# the file reads "Identifier "boss" not declared in the current scope" either way. A guard the row
	# echoes as protection, on a line that cannot compile, claims something that is not there.
	var across: EventSheetResource = _sheet()
	across.events.append(_event([_action("SpawnNewCopy", {
		"scene": BULLET, "name": "boss", "at": "global_position", "parent": "self"})]))
	across.events.append(_event([_action("RemoveNow", {"object": "boss"})]))
	var across_output: String = _compile(across, "user://eventforge_remove_across.gd")
	passed = _check("a copy named in another event is not wrapped in a guard that could not see it",
		across_output.contains("is_instance_valid"), false) and passed
	passed = _check("the removal row there is the plain call it always was",
		across_output.contains("\tboss.queue_free()"), true) and passed

	# THE SAME NAME IN ITS OWN EVENT: the copy was made two lines up, in this same run, so nothing
	# about the name can have changed and the row is left alone.
	var same: EventSheetResource = _sheet()
	same.events.append(_event([
		_action("SpawnNewCopy", {"scene": BULLET, "name": "boss", "at": "global_position", "parent": "self"}),
		_action("RemoveNow", {"object": "boss"})
	]))
	var same_output: String = _compile(same, "user://eventforge_remove_same_event.gd")
	passed = _check("a copy removed in the event that made it is not guarded",
		same_output.contains("is_instance_valid"), false) and passed

	# THINGS THAT CANNOT DANGLE: this node, and a node path that re-resolves every time it is read.
	for object_text: String in ["self", "$Enemy", "%Boss"]:
		passed = _check("removing %s needs no guard" % object_text,
			_compiled_with("RemoveNow", {"object": object_text}, "user://eventforge_remove_plain.gd")
				.contains("is_instance_valid"), false) and passed

	# The wait rows reach into the object on their first line too, so they are guarded the same way.
	var waited: EventSheetResource = _sheet()
	waited.variables = {"held_enemy": {"type": "Node2D", "default": null, "exported": false}}
	waited.events.append(_event([_action("RemoveAfterSeconds", {"object": "held_enemy", "seconds": "2.0"})]))
	passed = _check("the timer row is guarded on a stored reference too",
		_compile(waited, "user://eventforge_remove_stored_timer.gd").contains(
			"\tif is_instance_valid(held_enemy):\n\t\tget_tree().create_timer(2.0).timeout.connect(held_enemy.queue_free)"), true) and passed
	return passed


## A removal inside a match case is the same line as a removal beside it, on the same name, in the
## same file - and a state machine puts its removals in the case. The rule has to reach both emission
## sites or it disagrees with itself two lines apart.
static func _test_the_guard_reaches_inside_a_match_case() -> bool:
	var sheet: EventSheetResource = _sheet()
	sheet.variables = {
		"phase": {"type": "int", "default": 0, "exported": false},
		"held": {"type": "Node2D", "default": null, "exported": false},
	}
	var branch: MatchCase = MatchCase.new()
	branch.pattern = "0"
	branch.events.append(_action("RemoveNow", {"object": "held"}))
	var switch: MatchRow = MatchRow.new()
	switch.match_expression = "phase"
	switch.cases.append(branch)
	var event: EventRow = _event([])
	event.actions.append(switch)
	event.actions.append(_action("RemoveNow", {"object": "held"}))
	sheet.events.append(event)
	var output: String = _compile(sheet, "user://eventforge_remove_match.gd")
	var passed: bool = true
	passed = _check("the removal inside the case is guarded",
		output.contains("\t\t\tif is_instance_valid(held):\n\t\t\t\theld.queue_free()"), true) and passed
	passed = _check("as is the one beside it, in the same file",
		output.contains("\tif is_instance_valid(held):\n\t\theld.queue_free()"), true) and passed
	passed = _check("and the file the two guards are in still parses", _parses(output), true) and passed
	return passed


static func _test_the_guard_stands_down_when_the_sheet_already_asked() -> bool:
	var passed: bool = true
	# The sheet asked the question itself, so the compiler does not ask it again. ONE `if`, not two.
	var asked: EventSheetResource = _sheet()
	asked.variables = {"held_enemy": {"type": "Node2D", "default": null, "exported": false}}
	var event: EventRow = _event([_action("RemoveNow", {"object": "held_enemy"})])
	event.conditions.append(_condition("IsStillHere", {"object": "held_enemy"}))
	asked.events.append(event)
	var source: String = _compile(asked, "user://eventforge_remove_asked.gd")
	passed = _check("the sheet's own question is the only one written",
		source.contains("\tif is_instance_valid(held_enemy):\n\t\theld_enemy.queue_free()"), true) and passed
	passed = _check("and it is written exactly once",
		source.count("is_instance_valid(held_enemy)"), 1) and passed

	# THE ROUND TRIP that stand-down exists for: a file guarded by hand opens as the guarded row and
	# saves back as its own bytes. A second guard added on the way out would change them.
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	imported.variables = asked.variables.duplicate(true)
	imported.external_source_path = "user://eventforge_remove_asked_back.gd"
	passed = _check("a hand-written guard re-emits byte for byte",
		_compile(imported, "user://eventforge_remove_asked_back.gd") == source, true) and passed

	# A PARENT'S question counts as asked for every row under it: the sub-event runs inside that `if`.
	var nested: EventSheetResource = _sheet()
	nested.variables = {"held_enemy": {"type": "Node2D", "default": null, "exported": false}}
	var parent: EventRow = _event([])
	parent.conditions.append(_condition("IsValidInstance", {"object": "held_enemy"}))
	var child: EventRow = EventRow.new()
	child.actions.append(_action("RemoveNow", {"object": "held_enemy"}))
	parent.sub_events.append(child)
	nested.events.append(parent)
	passed = _check("a question asked by the parent event is not asked again inside it",
		_compile(nested, "user://eventforge_remove_nested.gd").count("is_instance_valid(held_enemy)"), 1) and passed

	# A NEGATED question is the opposite question: the branch where the thing is gone needs the guard
	# more than anywhere else, so it still gets one.
	var negated: EventSheetResource = _sheet()
	negated.variables = {"held_enemy": {"type": "Node2D", "default": null, "exported": false}}
	var negated_event: EventRow = _event([_action("RemoveNow", {"object": "held_enemy"})])
	var negated_condition: ACECondition = _condition("IsStillHere", {"object": "held_enemy"})
	negated_condition.negated = true
	negated_event.conditions.append(negated_condition)
	negated.events.append(negated_event)
	passed = _check("asking the opposite question does not stand the guard down",
		_compile(negated, "user://eventforge_remove_negated.gd").count("is_instance_valid(held_enemy)"), 2) and passed
	return passed


# ── 4. The echo ──


static func _test_the_echo_is_the_line_the_file_holds() -> bool:
	var passed: bool = true
	var sheet: EventSheetResource = _sheet()
	sheet.variables = {"held_enemy": {"type": "Node2D", "default": null, "exported": false}}
	var event: EventRow = _event([_action("RemoveNow", {"object": "held_enemy"})])
	sheet.events.append(event)
	var facts: Dictionary = EventForgeRemovalGuard.facts(sheet)
	var guarded: String = EventForgeRemovalGuard.guard_expression(
		event.actions[0] as ACEAction, event, facts)
	passed = _check("the rule names the object the guard is written on", guarded, "held_enemy") and passed
	# The row's echo and the emitted line come out of the SAME function, so they cannot disagree.
	var echoed: String = EventForgeRemovalGuard.guard_line(guarded)
	passed = _check("the echo is the guard line, unindented", echoed, "if is_instance_valid(held_enemy):") and passed
	passed = _check("and the file holds exactly that line, at the body indent",
		_compile(sheet, "user://eventforge_remove_echo.gd").contains(
			"\t" + echoed), true) and passed
	# A row nothing can dangle on echoes nothing at all.
	var plain: EventRow = _event([_action("RemoveNow", {"object": "self"})])
	passed = _check("a row that needs no guard shows none",
		EventForgeRemovalGuard.guard_expression(plain.actions[0] as ACEAction, plain, facts), "") and passed
	return passed


# ── 5. The hand-written chains ──


static func _test_the_hand_written_chains_lift() -> bool:
	var passed: bool = true
	for spelling: String in [
		"get_tree().create_timer(2.0).timeout.connect(queue_free)",
		"get_tree().create_timer(1.5).timeout.connect($Enemy.queue_free)",
		"$Ghost.create_tween().tween_property($Ghost, \"modulate:a\", 0.0, 0.5).finished.connect($Ghost.queue_free)",
	]:
		var matched: Dictionary = EventForgeRemovalLift.match_line(spelling)
		passed = _check("\"%s\" opens as a removal row" % spelling, matched.is_empty(), false) and passed
		if matched.is_empty():
			continue
		# The author's own spelling is what the row carries, so re-emitting writes their bytes back.
		var action: ACEAction = ACEAction.new()
		action.provider_id = str(matched.get("provider", "Core"))
		action.ace_id = str(matched.get("ace_id", ""))
		action.params = matched.get("params", {})
		action.codegen_template = str(matched.get("template", ""))
		passed = _check("\"%s\" writes its own bytes back" % spelling,
			ActionCodegen.generate_action(action), spelling) and passed
	# A tween that fades one node and frees another is somebody else's line and keeps its own reading.
	passed = _check("a chain that frees something other than what it faded is not this row",
		EventForgeRemovalLift.match_line(
			"$Ghost.create_tween().tween_property($Ghost, \"modulate:a\", 0.0, 0.5).finished.connect($Other.queue_free)"
		).is_empty(), true) and passed
	return passed


# ── Harness ──


## The Remove module's descriptors by id. Loaded BY PATH so the test does not wait on the editor
## class cache having been regenerated for a newly added module.
static func _descriptors() -> Dictionary:
	var module: GDScript = load("res://addons/eventforge/registration/modules/removal_aces.gd")
	var by_id: Dictionary = {}
	for descriptor: Variant in module.call("get_descriptors"):
		if descriptor is ACEDescriptor:
			by_id[str((descriptor as ACEDescriptor).ace_id)] = descriptor
	return by_id


## One parameter's default, as the literal the row opens on.
static func _default_of(descriptor: Variant, param_id: String) -> String:
	if not (descriptor is ACEDescriptor):
		return ""
	for param: ACEParam in (descriptor as ACEDescriptor).params:
		if str(param.id) == param_id:
			return str(param.default_value)
	return ""


static func _sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	return sheet


static func _event(actions: Array) -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	for action: Variant in actions:
		event.actions.append(action)
	return event


static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params.duplicate()
	return action


static func _condition(ace_id: String, params: Dictionary) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.params = params.duplicate()
	return condition


## One row of the given kind, compiled in a ready handler on a Node2D.
static func _compiled_with(ace_id: String, params: Dictionary, path: String) -> String:
	var sheet: EventSheetResource = _sheet()
	sheet.events.append(_event([_action(ace_id, params)]))
	return _compile(sheet, path)


static func _compile(sheet: EventSheetResource, path: String) -> String:
	return str(SheetCompiler.compile(sheet, path).get("output", ""))


## True when emitted GDScript actually loads. A pin on the text says a line is present; this says the
## file it is present in is still a file Godot will run.
static func _parses(source: String) -> bool:
	var script: GDScript = GDScript.new()
	script.source_code = source
	return script.reload() == OK


static func _check(label: String, got: Variant, expected: Variant) -> bool:
	if got == expected:
		return true
	print("[FAIL] removal_sentence_test: %s -> expected %s, got %s" % [label, expected, got])
	return false
