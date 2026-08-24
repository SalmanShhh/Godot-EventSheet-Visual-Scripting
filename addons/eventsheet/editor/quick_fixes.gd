@tool
class_name EventSheetQuickFixes
extends RefCounted

# The one-step fixes a Doctor finding offers.
#
# A finding that jumps you to the row is half an answer: the fix is still typed by hand. Every
# fix here is an operation the dock already has, so what this file really does is say WHICH
# finding has which one-step answer, and in what words.
#
#   an unknown control        -> add it to the Input Map / pick one that exists
#   a call to a function that is not there -> create it / pick the renamed one
#   a raw call the vocabulary matches      -> convert it to the action it matches
#   a pattern the sheet recognises         -> use the behavior that ships / add the missing half
#   a variable read but never set          -> declare it
#
# Every fix applies through the undo funnel and the check re-runs afterwards, so its
# disappearance is proven rather than assumed. `fixes_for` is pure: it reads a finding and
# returns what could be offered, which is what the test pins.

## check id -> the fixes it offers, each {"label", "id"}. The labels are what the row shows on
## its chips; `id` is what `apply` dispatches on.
const OFFERED := {
	"unknown-input-action": [
		{"id": "add_input_action", "label": "Add \"%s\" to the Input Map"},
		{"id": "pick_input_action", "label": "Pick an existing action…"},
	],
	"missing-function": [
		{"id": "create_function", "label": "Create %s"},
		{"id": "pick_function", "label": "Pick the renamed one…"},
	],
	"raw-call-has-action": [
		{"id": "convert_raw_call", "label": "Convert to the action it matches"},
	],
	"pattern-smell": [
		{"id": "adopt_behavior", "label": "Adopt behavior: %s"},
		{"id": "add_missing_half", "label": "Add the missing half"},
	],
	"unset-variable": [
		{"id": "declare_variable", "label": "Declare %s"},
	],
	"disabled-pack-in-use": [
		{"id": "enable_pack", "label": "Switch %s back on"},
	],
	# E4/M7. Both land where the change belongs: Adopt shows the diff on the block's own row, and
	# marking a message is the function row's gesture, so the chips say where rather than rewriting
	# bytes from a report the reader is not looking at.
	"multiplayer-reading": [
		{"id": "adopt_block", "label": "Adopt this line in the sheet"},
	],
	"multiplayer-message": [
		{"id": "make_message", "label": "Make %s a message…"},
	],
	"pack-reading": [
		{"id": "open_pack", "label": "Open the pack"},
	],
	"repeated-literal": [
		{"id": "extract_to_variable", "label": "⚡ Extract %s to a variable"},
	],
	# X17 - the three hierarchy footguns. Each has exactly one accepted answer, and the chip says it
	# in the words the row would use rather than in Godot's.
	"reparent-while-iterating": [
		{"id": "walk_a_copy", "label": "Walk a copy of the children"},
	],
	"reparent-in-ready": [
		{"id": "defer_reparent", "label": "Do it after the tree settles"},
	],
	"freed-parent-reference": [
		{"id": "guard_still_there", "label": "Ask whether %s is still there"},
	],
	# Y20 - the two things mirroring has to drag along. Each has exactly one accepted answer, and the
	# chip says it in the words the row would use rather than in Godot's.
	"ray-not-following-facing": [
		{"id": "follow_facing", "label": "Put %s under the mirrored body"},
	],
	"label-under-a-mirrored-body": [
		{"id": "keep_upright", "label": "Keep %s upright"},
	],
	# Y6 - pin or child. Both mechanisms are honest, so neither chip removes one on the reader's
	# behalf: each says which of the two answers this file wanted and where to make the change.
	"double-follow": [
		{"id": "unpin_it", "label": "Unpin it from %s"},
		{"id": "remove_from_parent", "label": "Take it out of %s"},
	],
	"pin-to-freed-object": [
		{"id": "unpin_before_free", "label": "Unpin before %s goes"},
		{"id": "guard_pin_anchor", "label": "Ask whether %s is still there"},
	],
}


## What this finding offers, each as {"id", "label"} with the label already carrying the subject
## ("Add \"dash\" to the Input Map"). Empty for a finding with no one-step answer, which is most
## of them - a fix is offered only where there really is one step.
static func fixes_for(finding: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var check: String = str(finding.get("check", ""))
	if not OFFERED.has(check):
		return out
	var subject: String = subject_of(finding)
	for offer: Variant in (OFFERED[check] as Array):
		var entry: Dictionary = (offer as Dictionary).duplicate()
		var label: String = str(entry.get("label", ""))
		if label.contains("%s"):
			if subject.is_empty():
				continue
			label = label % subject
		entry["label"] = label
		entry["check"] = check
		out.append(entry)
	return out


## The thing a fix acts on - the control's name, the function's name, the pack's folder. Taken
## from the finding's own `subject` when the check recorded one, so no fix ever has to read a
## message back out of English.
static func subject_of(finding: Dictionary) -> String:
	return str(finding.get("subject", "")).strip_edges()


## True when this finding has at least one one-step answer - what the row asks before drawing a
## chip and what the panel asks before enabling its buttons.
static func has_fix(finding: Dictionary) -> bool:
	return not fixes_for(finding).is_empty()


## Applies one fix. `context` carries what the operation needs from the editor:
##   "dock"  - the EventSheetDock, for the sheet edits and the status line
## Returns {"ok", "message"}. Never touches the scene or the file directly: everything goes
## through an operation the dock already owns, which is what makes each one undoable.
static func apply(fix_id: String, finding: Dictionary, context: Dictionary) -> Dictionary:
	var subject: String = subject_of(finding)
	var dock: Variant = context.get("dock", null)
	match fix_id:
		"add_input_action":
			return _add_input_action(subject)
		"pick_input_action":
			return {"ok": true, "message": "Pick the control this row means in Project ▸ Input Map, then re-run the check."}
		"create_function":
			if dock != null and dock.has_method("_open_function_dialog"):
				dock.call("_open_function_dialog")
				return {"ok": true, "message": "Name the function %s and it stops being missing." % subject}
			return {"ok": false, "message": "Open the sheet that calls %s to create it." % subject}
		"pick_function":
			return {"ok": true, "message": "Pick the function this call was renamed to - Edit ▸ Find References… lists every caller."}
		"convert_raw_call":
			if dock != null and dock.has_method("_open_raw_call_namer"):
				dock.call("_open_raw_call_namer")
				return {"ok": true, "message": "Name Raw Calls lists every raw call the vocabulary matches, with what it would become."}
			return {"ok": false, "message": "Sheet ▸ Name Raw Calls… converts every raw call the vocabulary matches."}
		"adopt_behavior":
			# The preview-first swap: the dialog shows the events as they read now beside how
			# they would read, and says what it checked before offering it.
			if dock != null and dock.has_method("adopt_pattern_behavior"):
				dock.call("adopt_pattern_behavior")
				return {"ok": true, "message": "Adopt behavior previews the swap before anything changes."}
			return {"ok": false, "message": "Add %s through Object bar ▸ Add behavior… and the pattern becomes the pack's." % subject}
		"add_missing_half":
			return {"ok": false, "message": "The other half of this pattern is missing - the reading names which one."}
		"declare_variable":
			if dock != null and dock.has_method("_create_variable_quickfix"):
				var made: bool = bool(dock.call("_create_variable_quickfix", subject))
				return {"ok": made, "message": "Declared %s." % subject if made
					else "%s could not be declared here - it may already exist." % subject}
			return {"ok": false, "message": "Open the sheet that reads %s to declare it." % subject}
		"enable_pack":
			EventSheetPackCatalog.set_enabled(subject, true)
			return {"ok": true, "message": "%s is back on - its actions return to the picker on the next refresh." % subject}
		# E4/M7. Two gestures that already exist on the row the finding points at - double-clicking
		# the finding opens that sheet, and these say what to reach for once it is open.
		"adopt_block":
			return {"ok": true, "message": "Open %s: the script block's own row offers Adopt, which rewrites it into a row plus whatever the row does not cover, with the diff shown before anything changes." % str(finding.get("path", "")).get_file()}
		"make_message":
			return {"ok": true, "message": "Open %s, right-click the %s function row and choose Make it a message - the annotation is what makes a call travel." % [str(finding.get("path", "")).get_file(), subject]}
		"open_pack":
			return {"ok": true, "message": "Open %s and Sheet ▸ Publish New Version… lists what does not read yet, with the fix." % str(finding.get("path", "")).get_file()}
		"extract_to_variable":
			return _extract_to_variable(subject, str(finding.get("path", "")), dock)
		# X17. All three point at a line in an emitted script rather than at one row, so each names
		# the one edit to make instead of rewriting bytes underneath the author.
		"walk_a_copy":
			return {"ok": true, "message": "Swap the walk for System ▸ For Each Child, which takes the snapshot for you - or add .duplicate() after the children so %s cannot shift the list it is walking." % subject}
		"defer_reparent":
			return {"ok": true, "message": "Move this out of On start of layout into a row that runs after the tree has settled - the parent is still adding its children while _ready runs."}
		"guard_still_there":
			return {"ok": true, "message": "Put the rows that use %s under a condition asking whether it is still there - a child goes when its parent goes." % subject}
		# Y20. Both are one edit in the SCENE, not in the sheet, so each names it rather than
		# rewriting bytes underneath the author.
		"follow_facing":
			return {"ok": true, "message": "Move %s under the node you mirror - a Set Mirrored (whole object) row turns everything beneath it, so the ray reaches the way the character faces." % subject}
		"keep_upright":
			return {"ok": true, "message": "Add a Facing ▸ Keep Upright row for %s under the same event that mirrors this object - it re-negates the child's scale so the text reads forwards either way." % subject}
		"unpin_it":
			return {"ok": true, "message": "Add Pin ▸ Unpin and let being a child of %s do the carrying. A child is structure and moves with its parent already." % subject}
		"remove_from_parent":
			return {"ok": true, "message": "Take this object out of %s and let the pin carry it. A pin follows at runtime and can let go; a child is structure and is destroyed with its parent." % subject}
		"guard_pin_anchor":
			return {"ok": true, "message": "Put the rows that use %s under Pin ▸ Is Pinned, or under a condition asking whether it is still there - a pin whose anchor is gone reads a place off nothing." % subject}
		"unpin_before_free":
			return {"ok": true, "message": "Add Pin ▸ Unpin on the row above the one that destroys %s, so the pin lets go before the object it rides is gone." % subject}
	return {"ok": false, "message": "No fix named %s." % fix_id}


## Gives a number typed three times a name, and points every row that spelled it at the name. The
## first draft of the name comes from the value itself; renaming it afterwards is one gesture on
## the variable row and is the point of extracting in the first place. Goes through the dock's own
## undo funnel, so Ctrl+Z takes the whole extraction back.
static func _extract_to_variable(literal: String, sheet_path: String, dock: Variant) -> Dictionary:
	if literal.is_empty():
		return {"ok": false, "message": "That finding names no value to extract."}
	if dock == null or not dock.has_method("_perform_undoable_sheet_edit"):
		return {"ok": false, "message": "Open %s to extract %s." % [sheet_path.get_file(), literal]}
	if not sheet_path.is_empty() and dock.has_method("_load_sheet_from_path"):
		dock.call("_load_sheet_from_path", sheet_path)
	var variable_name: String = EventSheetDoctorTidiness.suggested_variable_name(literal)
	var moved: Array[int] = [0]
	var applied: bool = bool(dock.call("_perform_undoable_sheet_edit", "Extract to variable",
		func() -> bool:
			moved[0] = EventSheetDoctorTidiness.extract_literal_to_variable(
				dock.get("_current_sheet"), literal, variable_name)
			return moved[0] > 0))
	if not applied:
		return {"ok": false, "message": "Could not extract %s - is \"%s\" already a variable?"
			% [literal, variable_name]}
	return {"ok": true, "message": "%s is now \"%s\" in %d place(s) - rename it from its row."
		% [literal, variable_name, moved[0]]}


## Registers one control with the project's Input Map, with no events bound - the row stops
## pointing at nothing, and binding a key is the next thing the reader does in Project ▸ Input Map.
static func _add_input_action(action_name: String) -> Dictionary:
	if action_name.is_empty():
		return {"ok": false, "message": "That finding names no control to add."}
	var setting: String = "input/%s" % action_name
	if ProjectSettings.has_setting(setting):
		return {"ok": true, "message": "%s is already in the Input Map." % action_name}
	ProjectSettings.set_setting(setting, {"deadzone": 0.5, "events": []})
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		ProjectSettings.save()
	return {"ok": true, "message": "Added \"%s\" to the Input Map - bind a key to it in Project ▸ Input Map." % action_name}
