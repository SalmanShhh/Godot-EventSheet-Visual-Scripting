# Godot EventSheets - live edit: applying a sheet change to the game that is already running.
#
# Editing while the game runs normally means stop, save, run again, and find your way back to the
# thing you were looking at. Godot itself can reload a script into a running game; what was missing
# was a sheet that asks it to, and - just as important - a sheet that says plainly when it cannot.
#
# THE WHOLE DECISION LIVES HERE, with no editor in it, so the status strip, the shortcut, the
# auto-apply toggle and the tests all read the same answer:
#  - is_running() says whether there is a game to apply to at all (nothing happens when there is
#    not: this is a debugging affordance, never a second Save button),
#  - blockers() says which changes Godot's script reload cannot carry into a live instance - a
#    variable whose TYPE changed (the running instance already holds a value of the old type) and a
#    function that was REMOVED (something may be sitting inside it right now),
#  - plan() puts those together into the sentence the strip shows and the offer it makes.
#
# STATE. Nothing here keeps game state; the engine keeps whatever the engine keeps across a script
# reload, and the words below promise nothing more than that.
#
# THE RUNNING SEAM. `running_probe` is how a test - and a headless run, where there is no editor at
# all - says "pretend a game is running". Left unset it asks EditorInterface, which is the only
# authority in a real session.
@tool
class_name EventSheetLiveEdit
extends RefCounted

## What the status strip shows while a running game has an unapplied edit waiting.
const APPLY_TEXT := "⟳ Apply to running game (Ctrl+Alt+S)"
## What it shows while paused at a row: the edit is real, it simply lands when the game moves again.
const PAUSED_TEXT := "⟳ Applies when the game resumes (paused at a row)"
## The offer beside a change that cannot be reloaded.
const RESTART_TEXT := "Restart"

## The test / headless seam: a Callable returning bool. Unset in a real session.
static var running_probe: Callable = Callable()
## The same seam for "paused at a row", so the paused wording can be pinned without a debugger.
static var paused_probe: Callable = Callable()


## Is there a game running to apply to? The probe wins when one is set, so a headless test can pin
## every word below without an editor, and a real session always asks the editor.
static func is_running() -> bool:
	if running_probe.is_valid():
		return bool(running_probe.call())
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return false
	return EditorInterface.is_playing_scene()


## Is the running game stopped at a row right now? An edit made here applies on resume. There is no
## editor API that answers this from outside the debugger, so the answer comes from whoever knows -
## the dock sets the probe when a breakpoint row halts the game, and it reads false otherwise
## rather than guessing.
static func is_paused_at_row() -> bool:
	return paused_probe.is_valid() and bool(paused_probe.call())


## The strip's text for the current state, or "" when there is nothing to say. Nothing happens
## unless the game is running, and the strip says nothing either - a button that is never useful is
## worse than no button.
static func status_text(has_unapplied_edit: bool) -> String:
	if not has_unapplied_edit or not is_running():
		return ""
	return PAUSED_TEXT if is_paused_at_row() else APPLY_TEXT


## Everything the strip needs about one pending apply: {running, can_reload, blockers, message,
## offer_restart}. `message` is the sentence shown; `offer_restart` is whether the Restart button
## sits beside it.
static func plan(before_source: String, after_source: String) -> Dictionary:
	if not is_running():
		return {"running": false, "can_reload": false, "blockers": PackedStringArray(),
			"message": "", "offer_restart": false}
	var stoppers: PackedStringArray = blockers(before_source, after_source)
	if stoppers.is_empty():
		return {"running": true, "can_reload": true, "blockers": stoppers,
			"message": status_text(true), "offer_restart": false}
	return {"running": true, "can_reload": false, "blockers": stoppers,
		"message": blocked_text(stoppers), "offer_restart": true}


## The changes a live script reload cannot carry, worded for the strip. Empty means "reload away".
##
## Only two shapes are refused, and both for the same honest reason: the running instance is still
## the OLD script's instance. A variable whose declared type changed already holds a value of the
## type it used to be, and a function that is gone may have a frame of the running game standing
## inside it. Everything else - new variables, changed values, new and rewritten functions, new and
## rewritten events - reloads.
static func blockers(before_source: String, after_source: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var before_types: Dictionary = declared_variable_types(before_source)
	var after_types: Dictionary = declared_variable_types(after_source)
	var retyped: PackedStringArray = PackedStringArray()
	for name: Variant in before_types:
		var was: String = str(before_types[name])
		if not after_types.has(name):
			continue
		var now: String = str(after_types[str(name)])
		if was != now and not was.is_empty() and not now.is_empty():
			retyped.append("%s is now %s, not %s" % [str(name), now, was])
	retyped.sort()
	for entry: String in retyped:
		out.append("a variable changed type (%s)" % entry)
	var removed: PackedStringArray = PackedStringArray()
	var after_functions: Dictionary = declared_functions(after_source)
	for function_name: Variant in declared_functions(before_source):
		if not after_functions.has(function_name):
			removed.append(str(function_name))
	removed.sort()
	for function_name: String in removed:
		out.append("the function %s was removed and may be running" % function_name)
	return out


## The sentence the strip shows instead of the apply offer, and the reason it gives.
static func blocked_text(stoppers: PackedStringArray) -> String:
	if stoppers.is_empty():
		return ""
	return "This change can't be applied to the running game: %s. Restart to pick it up." % ", ".join(stoppers)


## {variable name: declared type} for every member the source declares, with the type read from an
## explicit annotation (`var hp: int`), an inferred declaration (`var hp := 3`) or a plain literal
## (`var hp = 3`). A variable whose type cannot be read at all is recorded as "" and never counts as
## a change - a guess is not grounds for refusing to reload.
static func declared_variable_types(source: String) -> Dictionary:
	var out: Dictionary = {}
	for line: String in source.split("\n"):
		var text: String = line.strip_edges()
		if text.begins_with("@export"):
			var space: int = text.find(" ")
			text = text.substr(space + 1).strip_edges() if space > 0 else ""
		if not text.begins_with("var "):
			continue
		var body: String = text.substr("var ".length())
		var equals: int = body.find("=")
		var colon: int = body.find(":")
		if colon >= 0 and (equals < 0 or colon < equals):
			var declared_name: String = body.substr(0, colon).strip_edges()
			var rest: String = body.substr(colon + 1)
			if rest.begins_with("="):
				out[declared_name] = _literal_type(rest.substr(1))
			else:
				out[declared_name] = rest.split("=")[0].strip_edges()
			continue
		if equals < 0:
			out[body.strip_edges()] = ""
			continue
		out[body.substr(0, equals).strip_edges().trim_suffix(":")] = _literal_type(body.substr(equals + 1))
	return out


## The type a plain value declares by being written down. Deliberately narrow: only the literals a
## sheet writes on a variable row, and "" for everything else.
static func _literal_type(value_text: String) -> String:
	var value: String = value_text.strip_edges()
	if value == "true" or value == "false":
		return "bool"
	if value.begins_with("\"") or value.begins_with("&\"") or value.begins_with("^\""):
		return "String"
	if value.is_valid_int():
		return "int"
	if value.is_valid_float():
		return "float"
	if value.begins_with("["):
		return "Array"
	if value.begins_with("{"):
		return "Dictionary"
	return ""


## Every function the source declares, as a set. Nested names never collide because GDScript has no
## nested functions - a `func` at any indentation is a method of this script.
static func declared_functions(source: String) -> Dictionary:
	var out: Dictionary = {}
	for line: String in source.split("\n"):
		var text: String = line.strip_edges()
		if text.begins_with("static func "):
			text = text.substr("static ".length())
		if not text.begins_with("func "):
			continue
		var open_paren: int = text.find("(")
		if open_paren < 0:
			continue
		out[text.substr("func ".length(), open_paren - "func ".length()).strip_edges()] = true
	return out


## The events that changed between two versions of a sheet, as their uids - what pulses on the
## canvas (and in the Event Trace) after an apply, so the reader sees exactly what they just
## changed land. An event that is new counts as changed; one that is gone has nothing to pulse.
static func changed_event_uids(before: EventSheetResource, after: EventSheetResource) -> PackedStringArray:
	var was: Dictionary = {}
	if before != null:
		_digest_rows(before.events, was)
	var now: Dictionary = {}
	if after != null:
		_digest_rows(after.events, now)
	var out: PackedStringArray = PackedStringArray()
	for uid: Variant in now:
		if str(was.get(uid, "")) != str(now[uid]):
			out.append(str(uid))
	out.sort()
	return out


static func _digest_rows(rows: Array, into: Dictionary) -> void:
	for entry: Variant in rows:
		var event: EventRow = entry as EventRow
		if event == null:
			continue
		if not event.event_uid.is_empty():
			into[event.event_uid] = _digest_event(event)
		_digest_rows(event.sub_events, into)


## One event's contents as a string. Only what the reader can see on the row goes in, so a save
## that changes nothing visible pulses nothing.
static func _digest_event(event: EventRow) -> String:
	var parts: PackedStringArray = PackedStringArray([event.trigger_id, str(event.trigger_params),
		"1" if event.enabled else "0", str(event.condition_mode)])
	for condition: ACECondition in event.conditions:
		if condition != null:
			parts.append("c:%s:%s:%s" % [condition.ace_id, str(condition.params), "1" if condition.enabled else "0"])
	for action_entry: Resource in event.actions:
		var action: ACEAction = action_entry as ACEAction
		if action != null:
			parts.append("a:%s:%s:%s" % [action.ace_id, str(action.params), "1" if action.enabled else "0"])
		elif action_entry != null:
			parts.append("r:%s" % str(action_entry))
	return "|".join(parts)


## Where the "Auto-apply while debugging" choice lives (the View menu's check item). Kept beside the
## rest of the sheet's remembered view choices, per project.
static func auto_apply_enabled() -> bool:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return false
	return bool(EditorInterface.get_editor_settings().get_project_metadata("eventsheets", "live_edit_auto_apply", false))


static func set_auto_apply_enabled(enabled: bool) -> void:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return
	EditorInterface.get_editor_settings().set_project_metadata("eventsheets", "live_edit_auto_apply", enabled)


## What the status strip says right after an apply went through.
static func applied_text(changed: int) -> String:
	if changed <= 0:
		return "Applied to the running game."
	if changed == 1:
		return "Applied to the running game - 1 event changed."
	return "Applied to the running game - %d events changed." % changed
