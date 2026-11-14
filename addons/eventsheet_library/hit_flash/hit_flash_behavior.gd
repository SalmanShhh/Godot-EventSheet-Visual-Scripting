## @ace_tags(effects, shader, juice, visual)
## @ace_category("Hit Flash")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@tool
@icon("res://eventsheet_addons/hit_flash/icon.svg")
class_name HitFlashBehavior
extends Node
## Washes the host's own pixels towards a colour and back, which is the classic hit reaction. Unlike a modulate blink it works on dark sprites too, because it replaces colour rather than multiplying it. Flash takes the colour and how long the wash lasts; the shader file is copied into your project when the pack is added, so the edge cases are yours to tune.
##
## Changes on its parent: material.

## @ace_hidden
## The node this behavior acts on. Empty: its parent.
@export var acts_on: CanvasItem = null

## The node this behavior acts on (Acts on, or else its parent). Required host: CanvasItem.
var host: CanvasItem = null

func _enter_tree() -> void:
	host = acts_on if acts_on != null else get_parent() as CanvasItem
	if host == null:
		push_warning("Hit Flash Behavior needs a CanvasItem: put it under one, or set Acts on.")

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
	flash(Color.WHITE, 0.15)

func _preview_repeat(run: int) -> void:
	while true:
		await get_tree().create_timer(maxf(1.2, 0.1)).timeout
		if not _previewing or run != _preview_run:
			return
		_preview_kick()

## Name of the shader dial that sets the flash colour, named once so a rename in the shader file is a one-line change here.
const COLOUR_DIAL: String = "flash_color"
## Name of the shader dial that sets how strongly the flash shows.
const AMOUNT_DIAL: String = "flash_amount"

# Give this node its own copy of the material before anything turns a dial on it. A material
# is a RESOURCE, so every node pointing at the same file SHARES it: turn a dial on one goblin
# and every goblin wearing that file turns with it. On is the safe answer and the one you
# almost always want. Off when a whole row of nodes really should react together, which is the
# one case where sharing is the feature rather than the bug.
## Give this node its own copy of the material so dials affect only it.
@export var own_material: bool = true

## The material this behaviour writes through, resolved on first use so the copy is taken once.
var _worn: ShaderMaterial = null

## Dial changes running now, by dial name; a new call replaces the old.
var _walks: Dictionary = {}

## True once the missing-material warning was shown, so it shows once.
var _warned: bool = false
## The material to write on, copied on first use when own_material is on. Null means the parent
## wears no ShaderMaterial at all: attaching the pack copies hit_flash.gdshader into the project and assigns it,
## so a null here means it was cleared afterwards.
func _effect_material() -> ShaderMaterial:
	if _worn != null:
		return _worn
	if host == null:
		return null
	var found: ShaderMaterial = host.material as ShaderMaterial
	if found == null:
		if not _warned:
			_warned = true
			push_warning("Hit Flash needs its parent to wear the hit_flash.gdshader material. Add the pack again, or set the material in the Inspector.")
		return null
	# While previewing, always work on a copy, so a material other nodes share is never written to.
	_worn = found.duplicate() if (own_material or _previewing) else found
	host.material = _worn
	_seed_dials()
	return _worn
## Walks one dial to a value over a number of seconds and hands the tween back, so a verb can
## wait on it or hang something off its end. No time at all - or no scene tree to run a tween
## in - is a straight set rather than a tween nobody can see. A walk replaces whatever walk was
## already on that dial.
func _walk_dial(dial: String, to_value: float, seconds: float) -> Tween:
	var used: ShaderMaterial = _effect_material()
	if used == null:
		return null
	_stop_walk(dial)
	if seconds <= 0.0 or not is_inside_tree():
		used.set_shader_parameter(dial, to_value)
		return null
	var walk: Tween = create_tween()
	# `shader_parameter/<name>` is how Godot addresses a uniform as a property, which is what lets
	# one tween move it with no per-frame code here at all.
	walk.tween_property(used, "shader_parameter/" + dial, to_value, seconds)
	_walks[dial] = walk
	return walk

## Writes every dial the shader declares, once, before anything reads or walks one. An un-set
## uniform reads back as null rather than as the shader's own value, and a tween cannot even
## address `shader_parameter/<dial>` until it has been written.
func _seed_dials() -> void:
	if _worn == null or _worn.shader == null:
		return
	for declared: Dictionary in _worn.shader.get_shader_uniform_list():
		var dial: String = str(declared.get("name", ""))
		if dial.is_empty() or _worn.get_shader_parameter(dial) != null:
			continue
		var starts_at: Variant = RenderingServer.shader_get_parameter_default(
			_worn.shader.get_rid(), dial)
		# A renderer that draws nothing - a headless run, a dedicated server - knows no shader
		# defaults and answers null. The declared TYPE is still known, so an empty one of that is
		# written instead: the dial is addressable, and its value is never seen because nothing
		# is being drawn.
		if starts_at == null:
			starts_at = type_convert(starts_at, int(declared.get("type", TYPE_NIL)))
		_worn.set_shader_parameter(dial, starts_at)

## Turns one dial straight away, ending any walk that was moving it.
func _set_dial(dial: String, value: Variant) -> void:
	var used: ShaderMaterial = _effect_material()
	if used == null:
		return
	_stop_walk(dial)
	used.set_shader_parameter(dial, value)

## Ends the walk on one dial, if there is one, leaving the dial wherever it had got to.
func _stop_walk(dial: String) -> void:
	var walk: Tween = _walks.get(dial, null)
	if walk != null and walk.is_valid():
		walk.kill()
	_walks.erase(dial)

## What a dial reads right now. An un-set uniform reads back as null rather than as the value
## the shader declares for it, which is the fault every effect pack hits once, so the value the
## caller knows the shader starts at is what an unwritten dial answers with.
func _dial(dial: String, when_unset: float) -> float:
	var used: ShaderMaterial = _worn
	if used == null and host != null:
		used = host.material as ShaderMaterial
	if used == null:
		return when_unset
	var held: Variant = used.get_shader_parameter(dial)
	return when_unset if held == null else float(held)

## Washes the host towards a colour and lets it drain back over the given time. A second
## flash while one is running restarts it rather than stacking, so a fast string of hits
## reads as one bright thing rather than as a stuck white square.
## @ace_action
## @ace_featured
## @ace_name("Flash")
## @ace_display_template("Flash [b]{colour}[/b] for [b]{seconds}[/b] s")
## @ace_icon("res://eventsheet_addons/hit_flash/icon.svg")
## @ace_codegen_template("$HitFlashBehavior.flash({colour}, {seconds})")
func flash(colour: Color = Color.WHITE, seconds: float = 0.15) -> void:
	_set_dial(COLOUR_DIAL, colour)
	_set_dial(AMOUNT_DIAL, 1.0)
	_walk_dial(AMOUNT_DIAL, 0.0, maxf(seconds, 0.0))

## Ends the wash now, whatever was left of it. The row for an interruption: the hit was
## cancelled, the enemy died mid-flash, the scene is moving on.
## @ace_action
## @ace_name("Stop Flashing")
## @ace_icon("res://eventsheet_addons/hit_flash/icon.svg")
## @ace_codegen_template("$HitFlashBehavior.stop_flashing()")
func stop_flashing() -> void:
	_set_dial(AMOUNT_DIAL, 0.0)

## True while any of the wash is still showing.
## @ace_condition
## @ace_name("Is Flashing")
## @ace_icon("res://eventsheet_addons/hit_flash/icon.svg")
## @ace_codegen_template("$HitFlashBehavior.is_flashing()")
func is_flashing() -> bool:
	return _dial(AMOUNT_DIAL, 0.0) > 0.001

# Hit Flash: put this under any 2D node or Control that wears the hit_flash material and Flash whites it out for a moment. The dials (flash_color, flash_amount) live in hit_flash.gdshader, which is copied into your project when the pack is added - open it and change what a hit looks like. This pack is an event sheet - extend it by editing it.
