## @ace_tags(lighting, juice, visual)
## @ace_category("Light Pulse")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@tool
@icon("res://eventsheet_addons/light_pulse/icon.svg")
class_name LightPulseBehavior
extends Node
## Makes a light breathe. Attach it to any light, 2D or 3D, and its brightness rides a smooth wave between two numbers - a beacon, a pickup, a rune that should read as deliberate rather than as merely alight. Between and Period Seconds are tuned in the Inspector while the game runs; the sheet says when it starts and when it stops, and what it settles at.

## @ace_hidden
## The node this behavior acts on. Empty: its parent.
@export var acts_on: Node = null

## The node this behavior acts on (Acts on, or else its parent). Required host: Node.
var host: Node = null

func _enter_tree() -> void:
	host = acts_on if acts_on != null else get_parent() as Node
	if host == null:
		push_warning("Light Pulse Behavior needs a parent node: put it under one, or set Acts on.")

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
	pass

## The dimmest and brightest the light gets, as a pair. The wave spends most of its time near the middle of the two and only touches the ends.
@export var between: Vector2 = Vector2(0.6, 1.4)
## How long one whole breath takes - dim to bright and back again. Two seconds reads as calm; a quarter of a second reads as an alarm.
@export_range(0.05, 60, 0.05) var period_seconds: float = 2.0
## Whether the pulse is running right now. On means it starts breathing the moment the scene does.
@export var running: bool = true:
	set(value):
		running = value
		# Every write lands here - a sheet's Set Running action, the Inspector, another script -
		# so processing follows the breath whoever switched it. A delay still counts down per
		# frame, which is why waiting counts as running here.
		set_process(value or _waiting > 0.0)

## Name of the host's brightness property: energy in 2D, light_energy in 3D.
var _brightness_property: String = ""
# The breath position is kept rather than read off the game
# clock so that stopping and starting again resumes from where the wave was, and so that
# changing Period Seconds mid-breath does not snap the light.
## How far into the current breath we are, in seconds.
var _breath: float = 0.0
## Seconds still to wait before Start Pulsing takes effect, for the row that says "after".
var _waiting: float = 0.0

func _ready() -> void:
	if not _bind_to_light():
		push_warning("Light Pulse needs a light for a parent - a PointLight2D, an OmniLight3D, or any other light node.")
		# No light to drive means no frame will ever have work; stop paying for the tick at all.
		set_process(false)
		return
	# Processing runs only while the breath does - a pulse authored as stopped costs nothing
	# until Start Pulsing.
	set_process(running)

func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not _previewing:
		return
	if host == null or _brightness_property.is_empty():
		return
	if _waiting > 0.0:
		_waiting = maxf(_waiting - delta, 0.0)
		running = _waiting <= 0.0
		return
	if not running:
		return
	_breath = fposmod(_breath + delta, maxf(period_seconds, 0.001))
	# A cosine, not a sine: a breath should START at the dim end rather than halfway up it, so
	# a light that begins pulsing does not jump on its first frame.
	var wave: float = (1.0 - cos(TAU * _breath / maxf(period_seconds, 0.001))) * 0.5
	_apply_light(lerpf(between.x, between.y, wave))

## The first of these properties the host really has. `in` on an object is the honest
## question: it answers for a project's own subclass of a light exactly as it does for the
## engine's classes, with no list of class names here to keep in step with the engine.
func _first_property_of(candidates: PackedStringArray) -> String:
	for candidate: String in candidates:
		if host != null and candidate in host:
			return candidate
	return ""

## Binds to the parent light: finds the property it spells brightness with.
## False means the parent is not a light at all, which is the one setup mistake to warn about.
func _bind_to_light() -> bool:
	_brightness_property = _first_property_of(PackedStringArray(["energy", "light_energy"]))
	return not _brightness_property.is_empty()

## Writes one frame of the effect. Brightness is all this pack moves.
func _apply_light(brightness: float) -> void:
	host.set(_brightness_property, brightness)

## Starts the pulse, either now or after a delay - the delay is what a row uses when a beacon
## should come up a moment after the thing that switched it on.
## @ace_action
## @ace_featured
## @ace_name("Start Pulsing")
## @ace_display_template("Start pulsing after [b]{after_seconds}[/b] s")
## @ace_icon("res://eventsheet_addons/light_pulse/icon.svg")
## @ace_codegen_template("$LightPulseBehavior.start_pulsing({after_seconds})")
func start_pulsing(after_seconds: float = 0.0) -> void:
	_waiting = maxf(after_seconds, 0.0)
	running = _waiting <= 0.0
	# A delayed start still counts its delay down per frame - waiting is not idle.
	set_process(true)

## Stops the pulse and leaves the light at one steady brightness - the number the row names.
## @ace_action
## @ace_name("Stop Pulsing")
## @ace_display_template("Stop pulsing and settle at [b]{settle_at}[/b]")
## @ace_icon("res://eventsheet_addons/light_pulse/icon.svg")
## @ace_codegen_template("$LightPulseBehavior.stop_pulsing({settle_at})")
func stop_pulsing(settle_at: float = 1.0) -> void:
	running = false
	_waiting = 0.0
	# A stopped beacon costs nothing per frame; Start Pulsing turns processing back on.
	set_process(false)
	if host == null or _brightness_property.is_empty():
		return
	_apply_light(settle_at)

## True while the light is actually pulsing - false while it waits out a delay, and false
## once it has been stopped.
## @ace_condition
## @ace_name("Is Pulsing")
## @ace_icon("res://eventsheet_addons/light_pulse/icon.svg")
## @ace_codegen_template("$LightPulseBehavior.is_pulsing()")
func is_pulsing() -> bool:
	return running and _waiting <= 0.0

# Light Pulse: put this under any light and its brightness rides a smooth wave between two numbers. Start Pulsing and Stop Pulsing are the two rows a sheet needs - one takes a delay, the other the brightness to settle at. Between and Period Seconds are Inspector knobs. This pack is an event sheet - extend it by editing it.
