@tool
class_name EventSheetSceneEvents
extends RefCounted
# THE EVENTS OVERLAY - which nodes in this scene have events, and which events.
#
# A node whose script is a sheet wears a small ⌗ with its event count, in the Scene dock and beside
# its gizmo in the 2D / 3D editor. Hovering it names the triggers (On created · On hit · Every
# tick); clicking opens the sheet. Nodes with no events are unmarked, and the whole overlay is off
# until asked for - a badge on every node is noise.
#
# The count is the script's TRIGGERS, because that is what an event sheet's top-level events are:
# one per handler the file has. They are read the way the reading reads them - the two shapes that
# make an event out of a function, and nothing else:
#   * a lifecycle / tick handler (`_ready`, `_physics_process`, `_draw`, ...), which IS a trigger;
#   * a handler something connects a signal to (`hitbox.body_entered.connect(_on_hit)`), whose
#     trigger is that signal.
# A plain function is not an event and is never counted. The words come from the same place the
# rows' words do, so a badge can never call a trigger something the sheet does not.
#
# Text only - no sheet is opened and nothing is compiled, so marking a scene of fifty nodes costs a
# read per script rather than fifty lifts. Pure and static, so the whole map is testable headless.

## The project setting the overlay is gated on. Off by default, on purpose.
const SETTING_SHOW_EVENTS := "eventsheets/editor/show_scene_events"

## The badge glyph - a small hash, the same mark the sheet uses for an event's number.
const BADGE_GLYPH := "⌗"

## The handlers that ARE triggers on their own, and the Core trigger id each one is.
const LIFECYCLE_HANDLERS: Dictionary = {
	"_ready": "OnReady",
	"_enter_tree": "OnEnterTree",
	"_exit_tree": "OnExitTree",
	"_process": "OnProcess",
	"_physics_process": "OnPhysicsProcess",
	"_draw": "OnDraw",
	"_input": "OnInput",
	"_unhandled_input": "OnUnhandledInput",
}


## Whether the overlay draws at all.
static func is_enabled() -> bool:
	return bool(ProjectSettings.get_setting(SETTING_SHOW_EVENTS, false))


## The live overlay's own redraw, registered by it at boot so the View-menu toggle can reach it
## without the dock and the plugin having to know about each other. Never called headless.
static var _refresh_hook: Callable = Callable()


static func register_refresh(hook: Callable) -> void:
	_refresh_hook = hook


## Turns the overlay on or off for this project, and redraws it on the spot.
static func set_enabled(on: bool) -> void:
	ProjectSettings.set_setting(SETTING_SHOW_EVENTS, on)
	if Engine.is_editor_hint():
		ProjectSettings.save()
	if _refresh_hook.is_valid():
		_refresh_hook.call()


## What one script's badge says: `{"count": int, "triggers": PackedStringArray}`. A script that is
## not a sheet, or has no triggers at all, answers count 0 and wears no badge.
static func badge_for_script(script_path: String) -> Dictionary:
	var triggers: PackedStringArray = trigger_words_of(script_path)
	return {"count": triggers.size(), "triggers": triggers}


## The same question about a node in the edited scene, through whatever script it carries.
static func badge_for_node(node: Node) -> Dictionary:
	return badge_for_script(script_path_of(node))


## The res:// path of the script a node carries, or "" when it carries none.
static func script_path_of(node: Node) -> String:
	if node == null:
		return ""
	var script: Script = node.get_script() as Script
	if script == null:
		return ""
	return str(script.resource_path).strip_edges()


## The triggers one script's events read with, in file order, without duplicates - the hover list.
static func trigger_words_of(script_path: String) -> PackedStringArray:
	var words: PackedStringArray = PackedStringArray()
	for trigger_id: String in trigger_ids_of(script_path):
		var probe: EventRow = EventRow.new()
		probe.trigger_provider_id = "Core" if not trigger_id.begins_with("signal:") else ""
		probe.trigger_id = trigger_id
		var reading: String = EventSheetArrangement.trigger_words(probe)
		if not Array(words).has(reading):
			words.append(reading)
	return words


## Every trigger id the script's events hang off, in file order. Text only.
static func trigger_ids_of(script_path: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var clean: String = script_path.strip_edges()
	if clean.is_empty() or clean.get_extension().to_lower() != "gd" or not FileAccess.file_exists(clean):
		return found
	return trigger_ids_in_source(FileAccess.get_file_as_string(clean))


## The same walk over source text, so the map is testable without writing a file.
static func trigger_ids_in_source(source: String) -> PackedStringArray:
	var connections: Dictionary = _handler_signals(source)
	var found: PackedStringArray = PackedStringArray()
	var header: RegEx = RegEx.create_from_string("(?m)^func +([A-Za-z_][A-Za-z0-9_]*) *\\(")
	if header == null:
		return found
	for matched: RegExMatch in header.search_all(source):
		var function_name: String = matched.get_string(1)
		if LIFECYCLE_HANDLERS.has(function_name):
			found.append(str(LIFECYCLE_HANDLERS[function_name]))
			continue
		if not connections.has(function_name):
			continue
		var signal_name: String = str(connections[function_name])
		if EventSheetACELifter.CORE_SIGNAL_TRIGGERS.has(signal_name):
			found.append(str(EventSheetACELifter.CORE_SIGNAL_TRIGGERS[signal_name]))
		else:
			found.append("signal:%s" % signal_name)
	return found


## handler name -> the signal something connects it to, for both spellings people write:
## `hitbox.body_entered.connect(_on_hit)` and `hitbox.connect("body_entered", _on_hit)`.
static func _handler_signals(source: String) -> Dictionary:
	var found: Dictionary = {}
	var member_form: RegEx = RegEx.create_from_string(
		"([A-Za-z_][A-Za-z0-9_]*)\\.connect\\( *([A-Za-z_][A-Za-z0-9_]*)")
	var string_form: RegEx = RegEx.create_from_string(
		"connect\\( *\"([A-Za-z_][A-Za-z0-9_]*)\" *, *([A-Za-z_][A-Za-z0-9_]*)")
	if string_form != null:
		for matched: RegExMatch in string_form.search_all(source):
			found[matched.get_string(2)] = matched.get_string(1)
	if member_form != null:
		for matched: RegExMatch in member_form.search_all(source):
			var signal_name: String = matched.get_string(1)
			var handler: String = matched.get_string(2)
			# The string form's own `connect("x", h)` also matches this shape with signal_name
			# "connect" - the one spelling that is not a signal name.
			if signal_name == "connect" or found.has(handler):
				continue
			found[handler] = signal_name
	return found


## The badge's text: the glyph and the count ("⌗ 4"). "" when there is nothing to mark.
static func badge_text(badge: Dictionary) -> String:
	var count: int = int(badge.get("count", 0))
	return "" if count <= 0 else "%s %d" % [BADGE_GLYPH, count]


## The hover line: the triggers, in the sheet's own separator.
static func badge_tooltip(badge: Dictionary) -> String:
	var triggers: PackedStringArray = badge.get("triggers", PackedStringArray())
	return " · ".join(triggers)


## Every node of the edited scene that has events, as `{node, count, triggers, script}`, in tree
## order. Nodes with no script, or no triggers, are simply absent - the overlay marks nothing there.
static func badges_in_scene(root: Node) -> Array:
	var marked: Array = []
	_walk_scene(root, marked)
	return marked


static func _walk_scene(node: Node, marked: Array) -> void:
	if node == null:
		return
	var script_path: String = script_path_of(node)
	if not script_path.is_empty():
		var badge: Dictionary = badge_for_script(script_path)
		if int(badge.get("count", 0)) > 0:
			marked.append({
				"node": node,
				"script": script_path,
				"count": int(badge.get("count", 0)),
				"triggers": badge.get("triggers", PackedStringArray()),
			})
	for child: Node in node.get_children():
		_walk_scene(child, marked)
