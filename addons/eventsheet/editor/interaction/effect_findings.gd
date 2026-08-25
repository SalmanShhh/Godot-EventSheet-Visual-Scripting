# Godot EventSheets - the dial a shader no longer has.
#
# A shader author renames a uniform and every row that named the old one stops working, silently:
# `set_shader_parameter(&"dissolve", 0.7)` on a shader that now calls it `burn` is a call Godot
# accepts, returns from, and acts on in no way at all. Nothing errors, nothing logs, and the effect
# simply never happens - which is the same failure a mistyped name causes, arriving later.
#
# It is also a fact anybody can check before the game runs: the sheet says which dial, the scene says
# which material, the material says which shader, and the shader says which dials it declares. So the
# check is that comparison, and the note under the row is where a reader meets it. Amber, never red:
# the row compiles and runs, it only does nothing.
#
# THE FIX IS A RE-PICK. When one declared dial is close enough to the name in the row to be what was
# meant, the note offers it as a button and one click rewrites the row - the same gesture, the same
# one undo step, as the "Use hp" a misspelled variable already offers. When nothing is close, the note
# still says what is wrong; a wrong guess in a fix button costs more than no guess at all.
#
# NOTHING IS STORED. Every finding is derived from the rows and the shader on every ask, so a renamed
# dial stops reporting the moment it is picked again, and a project with no shaders gets none.
#
# PURE + STATIC: no viewport, no dialog, no display server, so every word is pinned headless.
@tool
class_name EventSheetEffectFindings
extends RefCounted

## The finding, by id. Frozen: the note rows, the health report and the tests address it by this.
const KIND_UNKNOWN_DIAL := "effect-dial-the-shader-does-not-declare"

## The one-click repair: rewrite the row's dial to the declared name it was nearly.
const FIX_PICK_DIAL := "pick_dial"

## Where a finding hangs - under the event whose row has the problem, which is the only anchor this
## family has: every one of them is about a row somebody wrote.
const ANCHOR_EVENT := "event"


## Every row of a sheet that names a dial its node's shader does not declare, in sheet order. Each
## carries the event it is under, the lane and slot of the row (so the fix can rewrite it without
## holding a resource across the undo funnel), and the declared name to offer when one is close.
static func findings(sheet: EventSheetResource) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if sheet == null:
		return found
	var script_path: String = str(sheet.external_source_path)
	if script_path.strip_edges().is_empty():
		return found
	var wearers: Dictionary = EventSheetSceneEffects.wearers_of_script(script_path)
	if wearers.is_empty():
		return found
	_walk(sheet.events, wearers, found)
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function != null:
			_walk(event_function.events, wearers, found)
	return found


## The findings anchored at one event row - what the canvas hangs under it. Matched by IDENTITY, so
## the caller never has to name a row that has no name.
static func for_event(found: Array[Dictionary], event_row: EventRow) -> Array[Dictionary]:
	var mine: Array[Dictionary] = []
	if event_row == null:
		return mine
	for entry: Dictionary in found:
		if is_same(entry.get("event"), event_row):
			mine.append(entry)
	return mine


## The dial one row names, or "" for every row that names none. Read off the row's own parameters,
## because that is where the picked vocabulary keeps it and where a lifted row keeps it too.
static func dial_of(ace: Resource) -> String:
	if ace == null:
		return ""
	var params: Variant = ace.get("params")
	if not (params is Dictionary):
		return ""
	return str((params as Dictionary).get(EventForgeEffectDialACEs.DIAL_PARAM, "")).strip_edges()


## The node one row is aimed at, as the row spells it - "" meaning the node the sheet is on, which is
## what a blank "On node" means everywhere else too.
static func target_of(ace: Resource) -> String:
	var params: Variant = ace.get("params")
	return str((params as Dictionary).get("target", "")).strip_edges() if params is Dictionary else ""


## One row checked against the shader behind its node: {} when the dial is declared, when the node
## wears nothing the sheet can follow, or when the row names no dial at all. Anything this cannot
## establish is not a finding - the point of the check is that it is never a guess.
static func _finding_for(ace: Resource, wearers: Dictionary, event_row: EventRow, lane: String,
		slot: int) -> Dictionary:
	var dial: String = dial_of(ace)
	if dial.is_empty():
		return {}
	var wearer: Dictionary = wearers.get(_reference_key(target_of(ace)), {})
	var shader_path: String = str(wearer.get("shader_path", ""))
	if shader_path.is_empty():
		return {}
	var declared: Array[Dictionary] = EventForgeShaderUniforms.for_shader(shader_path)
	if EventForgeShaderUniforms.declares(shader_path, dial):
		return {}
	var nearest: String = EventSheetVariableOwners.nearest_name(declared, dial)
	var message: String = EventSheetL10n.translate("%s declares no dial called %s, so this row does nothing when the game runs.") % [
		shader_path.get_file(), dial]
	if not nearest.is_empty():
		message += " " + EventSheetL10n.translate("Did you mean %s?") % nearest
	return {
		"kind": KIND_UNKNOWN_DIAL, "severity": "warning", "anchor": ANCHOR_EVENT,
		"event": event_row, "subject": dial, "shader_path": shader_path, "message": message,
		"fix": FIX_PICK_DIAL if not nearest.is_empty() else "",
		"fix_label": EventSheetL10n.translate("Use %s") % nearest if not nearest.is_empty() else "",
		"to": nearest, "lane": lane, "index": slot
	}


## One node reference reduced to the key the wearers map is filed under - the blank receiver meaning
## the node the sheet is on, exactly as it does in the lift's own guard.
static func _reference_key(written: String) -> String:
	return EventSheetSceneLights.SELF_REFERENCE if written.is_empty() \
		else EventSheetSceneLights.reference_key(written)


static func _walk(items: Array, wearers: Dictionary, into: Array[Dictionary]) -> void:
	for item: Variant in items:
		if item is EventGroup:
			_walk(EventSheetGroupFacts.children(item as EventGroup), wearers, into)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		for lane: String in ["condition", "action"]:
			var lane_rows: Array = event_row.conditions if lane == "condition" else event_row.actions
			for slot: int in range(lane_rows.size()):
				if not (lane_rows[slot] is Resource):
					continue
				var found: Dictionary = _finding_for(lane_rows[slot] as Resource, wearers,
					event_row, lane, slot)
				if not found.is_empty():
					into.append(found)
		_walk(event_row.sub_events, wearers, into)
