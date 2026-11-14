## @ace_tags(fade, juice)
## @ace_category("Fade")
## @ace_version(1.0.0)
@tool
@icon("res://eventsheet_addons/fade/icon.svg")
class_name FadeBehavior
extends Node
## Fades any sprite or UI node in and out without tween code. Set fade-in, hold, and fade-out times in the Inspector and it runs the whole sequence on its own, optionally freeing the node when done and firing a trigger at each stage.

## @ace_hidden
## The node this behavior acts on. Empty: its parent.
@export var acts_on: CanvasItem = null

## The node this behavior acts on (Acts on, or else its parent). Required host: CanvasItem.
var host: CanvasItem = null

func _enter_tree() -> void:
	host = acts_on if acts_on != null else get_parent() as CanvasItem
	if host == null:
		push_warning("Fade Behavior needs a CanvasItem: put it under one, or set Acts on.")

@warning_ignore("unused_private_class_variable")
## @ace_hidden
## Plays in the editor. Your scene is not changed.
@export_tool_button("Preview", "Play") var _preview_start_button: Callable = _preview_start

@warning_ignore("unused_private_class_variable")
## @ace_hidden
## Plays in the editor. Your scene is not changed.
@export_tool_button("Stop preview", "Stop") var _preview_stop_button: Callable = _preview_stop

## The Engine meta key every previewing behaviour shares for its table of rest values, one entry per host.
const _PREVIEW_TABLE_META: String = "_eventsheets_previews"

## The key of a table entry's remembered rest values.
const _PREVIEW_REST: String = "rest"

## The key of a table entry's count of behaviours previewing on that host.
const _PREVIEW_USERS: String = "users"

## True while Preview is playing in the editor. Always false in a running game.
var _previewing: bool = false

## Counts the Preview presses, so a repeat loop from an earlier press ends.
var _preview_run: int = 0

## This behaviour's own unsaved values from when Preview started, put back on Stop.
var _preview_own: Dictionary = {}

func _validate_property(property: Dictionary) -> void:
	if property.name == "_preview_start_button" and _previewing:
		property.usage = PROPERTY_USAGE_NONE
	elif property.name == "_preview_stop_button" and not _previewing:
		property.usage = PROPERTY_USAGE_NONE

func _notification(what: int) -> void:
	if not Engine.is_editor_hint() or not _previewing:
		return
	if what == NOTIFICATION_EXIT_TREE:
		_preview_stop()
	elif what == NOTIFICATION_EDITOR_PRE_SAVE:
		_preview_put_back(host, _preview_rest_of(host))

static func _preview_values(node: Object, own: bool) -> Dictionary:
	var values: Dictionary = {}
	for info: Dictionary in node.get_property_list():
		var usage: int = info.usage
		var prop_name: String = info.name
		if info.type == TYPE_NIL or info.type == TYPE_CALLABLE or prop_name.contains("/") or prop_name == "script" or prop_name == "owner":
			continue
		if own:
			if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or (usage & PROPERTY_USAGE_STORAGE) or prop_name.begins_with("_preview") or prop_name == "host":
				continue
		elif not (usage & PROPERTY_USAGE_STORAGE):
			continue
		var value: Variant = node.get(prop_name)
		values[prop_name] = value.duplicate() if (value is Array or value is Dictionary) else value
	return values

static func _preview_put_back(node: Object, values: Dictionary) -> void:
	if node == null or not is_instance_valid(node):
		return
	for prop_name: String in values:
		var now: Variant = node.get(prop_name)
		var rest: Variant = values[prop_name]
		if typeof(now) != typeof(rest) or now != rest:
			node.set(prop_name, rest)

static func _preview_table() -> Dictionary:
	if not Engine.has_meta(_PREVIEW_TABLE_META):
		Engine.set_meta(_PREVIEW_TABLE_META, {})
	return Engine.get_meta(_PREVIEW_TABLE_META)

func _preview_rest_of(node: Object) -> Dictionary:
	if node == null:
		return {}
	var entry: Dictionary = _preview_table().get(node.get_instance_id(), {})
	return entry.get(_PREVIEW_REST, {})

func _preview_start() -> void:
	if not Engine.is_editor_hint() or _previewing or host == null or not is_inside_tree():
		return
	var table: Dictionary = _preview_table()
	var key: int = host.get_instance_id()
	if table.has(key):
		_preview_put_back(host, table[key][_PREVIEW_REST])
		table[key][_PREVIEW_USERS] += 1
	else:
		table[key] = {_PREVIEW_REST: _preview_values(host, false), _PREVIEW_USERS: 1}
	_preview_own = _preview_values(self, true)
	_previewing = true
	_preview_run += 1
	notify_property_list_changed()
	_preview_kick()
	_preview_repeat(_preview_run)

func _preview_stop() -> void:
	if not _previewing:
		return
	_previewing = false
	_preview_kill_tweens()
	_preview_put_back(self, _preview_own)
	var table: Dictionary = _preview_table()
	var key: int = host.get_instance_id() if host != null else 0
	if table.has(key):
		_preview_put_back(host, table[key][_PREVIEW_REST])
		table[key][_PREVIEW_USERS] -= 1
		if table[key][_PREVIEW_USERS] <= 0:
			table.erase(key)
	notify_property_list_changed()

func _preview_kill_tweens() -> void:
	for info: Dictionary in get_property_list():
		if not (info.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or info.name == "host":
			continue
		var held: Variant = get(info.name)
		var live_tweens: Array = []
		if held is Tween:
			live_tweens.append(held)
		elif held is Dictionary:
			live_tweens.append_array((held as Dictionary).values())
		elif held is Array:
			live_tweens.append_array(held)
		for candidate: Variant in live_tweens:
			if candidate is Tween and (candidate as Tween).is_valid():
				(candidate as Tween).kill()

func _preview_kick() -> void:
	_kill_tween()
	_set_alpha(0.0)
	_tween = create_tween()
	_tween.tween_property(host, "modulate:a", 1.0, maxf(fade_in_time, 0.0001))
	_tween.tween_interval(maxf(hold_time, 0.0))
	_tween.tween_property(host, "modulate:a", 0.0, maxf(fade_out_time, 0.0001))

func _preview_repeat(run: int) -> void:
	while true:
		await get_tree().create_timer(maxf(fade_in_time + hold_time + fade_out_time + 0.5, 0.1)).timeout
		if not _previewing or run != _preview_run:
			return
		_preview_kick()

## @ace_trigger
## @ace_name("On Faded In")
signal on_faded_in
## @ace_trigger
## @ace_name("On Fade Out Started")
signal on_fade_out_started
## @ace_trigger
## @ace_name("On Faded Out")
signal on_faded_out

# --- Designer knobs (tune the timing in the Inspector) ---
## Seconds to fade from invisible to fully visible.
@export_range(0.0, 10.0, 0.05) var fade_in_time: float = 0.5
## Seconds to hold fully visible between the fade in and the fade out (used by Start).
@export_range(0.0, 60.0, 0.05) var hold_time: float = 0.0
## Seconds to fade from visible to invisible.
@export_range(0.0, 10.0, 0.05) var fade_out_time: float = 0.5
## Free (delete) the node once it has fully faded out.
@export var free_on_faded_out: bool = false
## Run the full fade-in / hold / fade-out sequence automatically when the node is ready.
@export var start_on_ready: bool = false

# Single tween, killed before each restart so overlapping fades never fight.
## The tween running the current fade, so a new fade can stop it.
var _tween: Tween = null

func _ready() -> void:
	if start_on_ready:
		start_fade()

## @ace_action
## @ace_featured
## @ace_name("Fade In")
## @ace_category("Fade")
## @ace_description("Fades the node from its current transparency up to fully visible over a duration, then fires On Faded In.")
## @ace_display_template("Fade in over [b]{duration}[/b] s")
## @ace_icon("res://eventsheet_addons/fade/icon.svg")
## @ace_codegen_template("$FadeBehavior.fade_in({duration})")
func fade_in(duration: float) -> void:
	if host == null:
		return
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(host, "modulate:a", 1.0, maxf(duration, 0.0001))
	_tween.finished.connect(func() -> void: on_faded_in.emit())

## @ace_action
## @ace_featured
## @ace_name("Fade Out")
## @ace_category("Fade")
## @ace_description("Fades the node down to invisible over a duration (fires On Fade Out Started now, On Faded Out at the end). Frees the node afterwards if Free On Faded Out is on.")
## @ace_display_template("Fade out over [b]{duration}[/b] s")
## @ace_icon("res://eventsheet_addons/fade/icon.svg")
## @ace_codegen_template("$FadeBehavior.fade_out({duration})")
func fade_out(duration: float) -> void:
	if host == null:
		return
	_kill_tween()
	on_fade_out_started.emit()
	_tween = create_tween()
	_tween.tween_property(host, "modulate:a", 0.0, maxf(duration, 0.0001))
	_tween.finished.connect(func() -> void:
		on_faded_out.emit()
		if free_on_faded_out and host != null:
			host.queue_free())

## @ace_action
## @ace_name("Start Fade")
## @ace_category("Fade")
## @ace_description("Runs the whole sequence from the Inspector times: fade in, hold, then fade out (firing On Faded In, On Fade Out Started, and On Faded Out along the way). Freeing the node at the end if set.")
## @ace_icon("res://eventsheet_addons/fade/icon.svg")
## @ace_codegen_template("$FadeBehavior.start_fade()")
func start_fade() -> void:
	if host == null:
		return
	_kill_tween()
	_set_alpha(0.0)
	_tween = create_tween()
	_tween.tween_property(host, "modulate:a", 1.0, maxf(fade_in_time, 0.0001))
	_tween.tween_callback(func() -> void: on_faded_in.emit())
	_tween.tween_interval(maxf(hold_time, 0.0))
	_tween.tween_callback(func() -> void: on_fade_out_started.emit())
	_tween.tween_property(host, "modulate:a", 0.0, maxf(fade_out_time, 0.0001))
	_tween.tween_callback(func() -> void:
		on_faded_out.emit()
		if free_on_faded_out and host != null:
			host.queue_free())

## @ace_action
## @ace_name("Stop Fade")
## @ace_category("Fade")
## @ace_description("Cancels any running fade, leaving the node at its current transparency.")
## @ace_icon("res://eventsheet_addons/fade/icon.svg")
## @ace_codegen_template("$FadeBehavior.stop_fade()")
func stop_fade() -> void:
	_kill_tween()

## @ace_action
## @ace_name("Set Opacity")
## @ace_category("Fade")
## @ace_description("Sets the node's transparency directly (0 = invisible, 1 = fully visible), cancelling any running fade.")
## @ace_icon("res://eventsheet_addons/fade/icon.svg")
## @ace_codegen_template("$FadeBehavior.set_opacity({alpha})")
func set_opacity(alpha: float) -> void:
	_kill_tween()
	_set_alpha(alpha)

func _set_alpha(alpha: float) -> void:
	# Sets the host's alpha (0 = invisible, 1 = opaque) whether it is a Node2D or a Control.
	if host is CanvasItem:
		(host as CanvasItem).modulate.a = clampf(alpha, 0.0, 1.0)

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

## @ace_condition
## @ace_name("Is Fading")
## @ace_icon("res://eventsheet_addons/fade/icon.svg")
## @ace_codegen_template("$FadeBehavior.is_fading()")
func is_fading() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()

## @ace_expression
## @ace_name("Opacity")
## @ace_icon("res://eventsheet_addons/fade/icon.svg")
## @ace_codegen_template("$FadeBehavior.opacity()")
func opacity() -> float:
	return (host as CanvasItem).modulate.a if host is CanvasItem else 1.0

# Fade: attach to a sprite or UI node. It animates transparency - Fade In, Fade Out, or Start the full fade-in / hold / fade-out sequence from the Inspector times (optionally freeing the node at the end). React with On Faded Out. This pack is an event sheet - extend it by editing it.
