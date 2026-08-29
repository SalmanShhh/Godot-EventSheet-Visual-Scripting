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
# Every fix that changes a SHEET applies through the undo funnel and the check re-runs afterwards,
# so its disappearance is proven rather than assumed. Two of them change the PROJECT instead - adding
# a control to the Input Map, and recording that this game does not want to be asked about error
# reports - and those are project settings a person edits in Project ▸ Project Settings; they are
# named in their own words here rather than pretended into the sheet's undo history.
#
# A fix that edits a sheet edits the OPEN one. Several of these findings come off a scan of the whole
# project, so the file a finding names is usually not the one on screen - and a sheet opened to be
# fixed would replace the reader's tab without asking, arriving as a read-only preview whose rows are
# not lifted yet. Double-clicking a finding is what opens its sheet; the chip changes it once it is
# there.
#
# `fixes_for` is pure: it reads a finding and returns what could be offered, which is what the test
# pins.

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
	# Both land where the change belongs: Adopt shows the diff on the block's own row, and
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
	# The one lighting finding with a single step to take: an environment `.tres` is a FILE, so
	# writing fog into it at run time writes it for every scene that loads the same file. The chip
	# writes the row that takes a copy first, at the top of the sheet the finding points at.
	"lighting-shared-environment": [
		{"id": "own_environment", "label": "Make the environment this scene's own"},
	],
	"repeated-literal": [
		{"id": "extract_to_variable", "label": "⚡ Extract %s to a variable"},
	],
	# The three hierarchy footguns. Each has exactly one accepted answer, and the chip says it
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
	# The two things mirroring has to drag along. Each has exactly one accepted answer, and the
	# chip says it in the words the row would use rather than in Godot's.
	"ray-not-following-facing": [
		{"id": "follow_facing", "label": "Put %s under the mirrored body"},
	],
	"label-under-a-mirrored-body": [
		{"id": "keep_upright", "label": "Keep %s upright"},
	],
	# Pin or child. Both mechanisms are honest, so neither chip removes one on the reader's
	# behalf: each says which of the two answers this file wanted and where to make the change.
	"double-follow": [
		{"id": "unpin_it", "label": "Unpin it from %s"},
		{"id": "remove_from_parent", "label": "Take it out of %s"},
	],
	"pin-to-freed-object": [
		{"id": "unpin_before_free", "label": "Unpin before %s goes"},
		{"id": "guard_pin_anchor", "label": "Ask whether %s is still there"},
	],
	# A suggestion, so its second chip is the answer "no". A game that swallows its own errors on
	# purpose is a decision, not an oversight, and being asked about it every week is what makes a
	# Doctor report something people stop reading.
	"no-error-report": [
		{"id": "never_ask_error_report", "label": "Never ask again"},
	],
	# Shipping. A console line an exported game still runs has exactly one accepted answer and it is
	# a verb that already ships, so the chip swaps the word rather than teaching a new one.
	"ship-debug-rows": [
		{"id": "guard_debug_rows", "label": "Only log in debug builds"},
	],
	# A short catalog is a JOB, not a sentence: the chip writes the missing keys out as a
	# ready-to-fill translation file rather than listing forty of them in a report line.
	"ship-translation-coverage": [
		{"id": "export_missing_keys", "label": "Write the missing keys out"},
	],
	# Documentation. The stub chip is the one fix here that deliberately does NOT make the finding go
	# away: it writes a row per undocumented verb carrying an unfilled placeholder, and that
	# placeholder keeps reporting itself as a description that says nothing until a person replaces
	# it. A chip that wrote a plausible sentence would turn the page green while documenting nothing.
	"docs-undocumented-verb": [
		{"id": "write_doc_stubs", "label": "Stub %s in the guide"},
	],
	# A name nothing answers to is a rename nine times in ten, so the first chip is the shortlist. The
	# second is the other honest answer: the paragraph is prose about the pack rather than a row of
	# its reference, and saying so is an edit too.
	"docs-stale-name": [
		{"id": "link_nearest_verbs", "label": "Link the nearest verbs to %s"},
		{"id": "mark_prose_only", "label": "Mark this paragraph prose-only"},
	],
	"docs-empty-description": [
		{"id": "insert_draft_description", "label": "Insert the draft for %s"},
	],
}

## Where a guide has to live for a chip to edit it: the packs of THIS project. A shipped guide under
## the plugin's own help bundle is regenerated from the repository it came from, so writing into it
## would be undone by the next build and would look, in the meantime, like documentation somebody
## wrote. Those chips name the edit instead.
const EDITABLE_GUIDE_ROOT := "res://eventsheet_addons"

## Where "Write the missing keys out" puts the file. The user directory rather than the project: it
## is a working file for a translator, and dropping it into res:// would import it as a live catalog
## the moment it landed.
const MISSING_KEYS_PATH := "user://eventsheets_missing_keys.csv"


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
		"never_ask_error_report":
			return _never_ask_error_report()
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
		# Two gestures that already exist on the row the finding points at - double-clicking
		# the finding opens that sheet, and these say what to reach for once it is open.
		"adopt_block":
			return {"ok": true, "message": "Open %s: the script block's own row offers Adopt, which rewrites it into a row plus whatever the row does not cover, with the diff shown before anything changes." % str(finding.get("path", "")).get_file()}
		"make_message":
			return {"ok": true, "message": "Open %s, right-click the %s function row and choose Make it a message - the annotation is what makes a call travel." % [str(finding.get("path", "")).get_file(), subject]}
		"open_pack":
			return {"ok": true, "message": "Open %s and Sheet ▸ Publish New Version… lists what does not read yet, with the fix." % str(finding.get("path", "")).get_file()}
		# The same gesture the note row under the event offers, reached from the report instead:
		# the sheet is opened and the row goes in at its top, on ready, through the dock's own funnel.
		"own_environment":
			return _own_environment(subject, str(finding.get("path", "")), dock)
		"extract_to_variable":
			return _extract_to_variable(subject, str(finding.get("path", "")), dock)
		# All three point at a line in an emitted script rather than at one row, so each names
		# the one edit to make instead of rewriting bytes underneath the author.
		"walk_a_copy":
			return {"ok": true, "message": "Swap the walk for System ▸ For Each Child, which takes the snapshot for you - or add .duplicate() after the children so %s cannot shift the list it is walking." % subject}
		"defer_reparent":
			return {"ok": true, "message": "Move this out of On start of layout into a row that runs after the tree has settled - the parent is still adding its children while _ready runs."}
		"guard_still_there":
			return {"ok": true, "message": "Put the rows that use %s under a condition asking whether it is still there - a child goes when its parent goes." % subject}
		# Both are one edit in the SCENE, not in the sheet, so each names it rather than
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
		"guard_debug_rows":
			return _guard_debug_rows(str(finding.get("path", "")), dock)
		"export_missing_keys":
			return _export_missing_keys()
		"write_doc_stubs":
			return _write_doc_stubs(subject, str(finding.get("path", "")))
		"link_nearest_verbs":
			return {"ok": true, "message": "Open %s and swap \"%s\" for one of the verbs the finding names, or delete the row - the picker is the list of what answers today." % [
				str(finding.get("path", "")).get_file(), subject]}
		"mark_prose_only":
			return {"ok": true, "message": "Move \"%s\" out of the reference table in %s and into the prose above it - a sentence about the pack is not a row of its reference, and the audit only reads the tables." % [
				subject, str(finding.get("path", "")).get_file()]}
		"insert_draft_description":
			return {"ok": true, "message": "Open %s and put the drafted sentence in the description cell for %s - it is a starting line composed from the verb's own name and parameters, not a claim about what it does." % [
				str(finding.get("path", "")).get_file(), subject]}
		"unpin_before_free":
			return {"ok": true, "message": "Add Pin ▸ Unpin on the row above the one that destroys %s, so the pin lets go before the object it rides is gone." % subject}
	return {"ok": false, "message": "No fix named %s." % fix_id}


## Swaps every plain Log row of the sheet in front of the reader for the debug-builds-only one, in
## ONE undoable edit through the dock's own funnel, and says what the lines read as before and after
## so the swap leaves a receipt rather than a count.
##
## IT ONLY EVER TOUCHES THE OPEN SHEET. This finding comes off a text scan of every script in the
## project, so the file it names is usually not the one on screen; opening it here would replace the
## reader's tab without asking, and a `.gd` opened that way arrives as a read-only preview whose rows
## have not been lifted yet - so the swap would find nothing and then blame the author for having
## written the line by hand. Double-clicking the finding is what opens the sheet; the chip is what
## changes it once it is there and editable.
static func _guard_debug_rows(sheet_path: String, dock: Variant) -> Dictionary:
	var elsewhere: String = "Open %s and swap its Log rows for Log (Debug Builds Only) - double-clicking the finding opens it." % sheet_path.get_file()
	if dock == null or not dock.has_method("_perform_undoable_sheet_edit"):
		return {"ok": false, "message": elsewhere}
	if not _is_the_open_sheet(dock, sheet_path):
		return {"ok": false, "message": elsewhere}
	var sheet: EventSheetResource = dock.get("_current_sheet") as EventSheetResource
	if sheet == null or sheet.read_only:
		return {"ok": false, "message": "%s is still opening - it reads as code until its rows have been lifted. Try again once it has finished." % sheet_path.get_file()}
	var receipt: Array[Dictionary] = EventSheetShipItDoctor.guard_receipt(sheet)
	if receipt.is_empty():
		return {"ok": false, "message": "No plain Log rows in %s - the console line is written by hand, so guard it where it is typed." % sheet_path.get_file()}
	var guarded: Array[int] = [0]
	var applied: bool = bool(dock.call("_perform_undoable_sheet_edit", "Only log in debug builds",
		func() -> bool:
			guarded[0] = EventSheetShipItDoctor.guard_debug_rows(dock.get("_current_sheet"))
			return guarded[0] > 0))
	if not applied:
		return {"ok": false, "message": "No plain Log rows in %s - the console line is written by hand, so guard it where it is typed." % sheet_path.get_file()}
	return {"ok": true, "message": "%d row(s) guarded. %s - one Ctrl+Z takes it back."
		% [guarded[0], guard_receipt_line(receipt)]}


## The receipt one guard swap leaves: what the first line read as, what it reads as now, and how many
## others went with it. Shown BEFORE the reader is told the fix worked, because a count on its own is
## not a receipt - it names no line the reader can go and look at.
static func guard_receipt_line(receipt: Array[Dictionary]) -> String:
	if receipt.is_empty():
		return ""
	var first: Dictionary = receipt[0]
	var line: String = "%s → %s" % [str(first.get("before", "")), str(first.get("after", ""))]
	if receipt.size() > 1:
		line += ", and %d more like it" % (receipt.size() - 1)
	return line


## True when the sheet this finding names is the one the dock has in front of the reader. A finding
## with no path at all is about whatever is open, which is how the row-level chips reach it.
static func _is_the_open_sheet(dock: Variant, sheet_path: String) -> bool:
	if sheet_path.strip_edges().is_empty():
		return true
	var open_path: String = str(dock.get("_current_sheet_path")).strip_edges()
	if open_path == sheet_path:
		return true
	var sheet: EventSheetResource = dock.get("_current_sheet") as EventSheetResource
	return sheet != null and str(sheet.external_source_path).strip_edges() == sheet_path


## Writes the keys the game asks for and no catalog answers into a ready-to-fill translation CSV, and
## says where it went. A file rather than a report line, because forty keys is a job somebody does in
## a spreadsheet.
static func _export_missing_keys() -> Dictionary:
	var sources: Dictionary = EventSheetShipItDoctor.project_sources()
	var text: String = EventSheetShipItDoctor.missing_keys_csv(
		EventSheetShipItDoctor.used_translation_keys(sources), EventSheetShipItDoctor.catalog_keys())
	if text.is_empty():
		return {"ok": true, "message": "Every key the game asks for is answered by every catalog - nothing to write out."}
	var file: FileAccess = FileAccess.open(EventSheetQuickFixes.MISSING_KEYS_PATH, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Could not write %s." % EventSheetQuickFixes.MISSING_KEYS_PATH}
	file.store_string(text)
	file.close()
	return {"ok": true, "message": "Wrote the missing keys to %s - one row per key, one column per catalog." % EventSheetQuickFixes.MISSING_KEYS_PATH}


## Writes "Make the environment this scene's own" at the top of the sheet the finding points at, so
## every fog and glow row after it changes this scene's own copy rather than the file every scene
## loads. One undo step, through the dock's own funnel - the same operation the note row's button runs.
static func _own_environment(target: String, sheet_path: String, dock: Variant) -> Dictionary:
	if dock == null or not dock.has_method("give_the_scene_its_own_environment") \
			or not _is_the_open_sheet(dock, sheet_path):
		return {"ok": false, "message": "Open %s and click the fix on the note under the row." % sheet_path.get_file()}
	if not bool(dock.call("give_the_scene_its_own_environment", target)):
		return {"ok": false, "message": "%s already takes its own copy of the environment." % sheet_path.get_file()}
	return {"ok": true, "message": "%s takes its own copy of the environment first - the change stops in this scene." % sheet_path.get_file()}


## Gives a number typed three times a name, and points every row that spelled it at the name. The
## first draft of the name comes from the value itself; renaming it afterwards is one gesture on
## the variable row and is the point of extracting in the first place. Goes through the dock's own
## undo funnel, so Ctrl+Z takes the whole extraction back.
static func _extract_to_variable(literal: String, sheet_path: String, dock: Variant) -> Dictionary:
	if literal.is_empty():
		return {"ok": false, "message": "That finding names no value to extract."}
	if dock == null or not dock.has_method("_perform_undoable_sheet_edit") \
			or not _is_the_open_sheet(dock, sheet_path):
		return {"ok": false, "message": "Open %s to extract %s." % [sheet_path.get_file(), literal]}
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
## Remembered in the PROJECT rather than for the reader: whether this game wants to hear about its
## own errors is a fact about the game, and the answer should travel with it.
static func _never_ask_error_report() -> Dictionary:
	ProjectSettings.set_setting(EventSheetPerformanceDoctor.SUGGEST_SETTING, false)
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		ProjectSettings.save()
	return {"ok": true, "message": "Noted - this project will not be asked about error reports again."}


static func _add_input_action(action_name: String) -> Dictionary:
	if action_name.is_empty():
		return {"ok": false, "message": "That finding names no control to add."}
	var setting: String = "input/%s" % action_name
	if ProjectSettings.has_setting(setting):
		return {"ok": true, "message": "%s is already in the Input Map." % action_name}
	# A control whose name has an everyday binding is created wearing it ("jump, bound to
	# Space") - said in the answer, changeable in Project ▸ Input Map like any binding. A name
	# convention says nothing about is created unbound, exactly as before.
	var events: Array = []
	var key: Key = EventSheetNameRescue.suggested_key(action_name)
	if key != KEY_NONE:
		var key_event: InputEventKey = InputEventKey.new()
		key_event.physical_keycode = key
		events.append(key_event)
	ProjectSettings.set_setting(setting, {"deadzone": 0.5, "events": events})
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		ProjectSettings.save()
	if key != KEY_NONE:
		return {"ok": true, "message": "Added \"%s\" to the Input Map, bound to %s - change the binding in Project ▸ Input Map." % [action_name, OS.get_keycode_string(key)]}
	return {"ok": true, "message": "Added \"%s\" to the Input Map - bind a key to it in Project ▸ Input Map." % action_name}


## Writes a stub row into a pack guide for the verb this finding names, and says so plainly: the row
## goes in carrying an unfilled placeholder, so the audit keeps reporting it as a description that
## says nothing until a person writes one. That is the point of the chip - it does the typing that is
## mechanical (finding the verb, opening the guide, matching the table's shape) and refuses the part
## that is not.
##
## ONLY A GUIDE THIS PROJECT OWNS is written. The shipped guides under the plugin's help bundle are
## regenerated from the repository they came from, so an edit there is undone by the next build while
## looking, until then, like documentation somebody wrote.
static func _write_doc_stubs(verb_name: String, guide_path: String) -> Dictionary:
	if verb_name.is_empty() or guide_path.is_empty():
		return {"ok": false, "message": "That finding names no guide to write into."}
	if not guide_path.begins_with(EDITABLE_GUIDE_ROOT):
		return {"ok": false, "message": "%s is a shipped guide - the next help-bundle build would overwrite the stub. Add the row for %s to its source on GitHub instead." % [
			guide_path.get_file(), verb_name]}
	var file: FileAccess = FileAccess.open(guide_path, FileAccess.READ)
	if file == null:
		return {"ok": false, "message": "%s could not be read." % guide_path}
	var source: String = file.get_as_text()
	var written: String = EventSheetDocCoverage.insert_stubs(source, PackedStringArray([verb_name]))
	if written == source:
		return {"ok": false, "message": "%s already has a row for %s." % [guide_path.get_file(), verb_name]}
	var out: FileAccess = FileAccess.open(guide_path, FileAccess.WRITE)
	if out == null:
		return {"ok": false, "message": "%s could not be written." % guide_path}
	out.store_string(written)
	return {"ok": true, "message": "Stubbed %s in %s. It stays on this page as a description that says nothing until you replace the placeholder." % [
		verb_name, guide_path.get_file()]}
