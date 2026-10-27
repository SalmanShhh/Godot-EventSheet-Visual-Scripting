## @ace_tags(effects, shader, juice, visual)
## @ace_category("Hit Flash")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/hit_flash/icon.svg")
class_name HitFlashBehavior
extends Node
## Washes the host's own pixels towards a colour and back, which is the classic hit reaction. Unlike a modulate blink it works on dark sprites too, because it replaces colour rather than multiplying it. Flash takes the colour and how long the wash lasts; the shader file is copied into your project when the pack is added, so the edge cases are yours to tune.

## The node this behavior acts on (its parent). Required host: CanvasItem.
var host: CanvasItem = null

func _enter_tree() -> void:
	host = get_parent() as CanvasItem
	if host == null:
		push_warning("HitFlashBehavior behavior requires a CanvasItem parent.")

## The name the two dials go by in hit_flash.gdshader. Named once here so a rename in the
## shader file is a one-line change in this one.
const COLOUR_DIAL: String = "flash_color"
const AMOUNT_DIAL: String = "flash_amount"

## Give this node its own copy of the material before anything turns a dial on it. A material
## is a RESOURCE, so every node pointing at the same file SHARES it: turn a dial on one goblin
## and every goblin wearing that file turns with it. On is the safe answer and the one you
## almost always want. Off when a whole row of nodes really should react together, which is the
## one case where sharing is the feature rather than the bug.
@export var own_material: bool = true

## The material this behaviour writes through, resolved on first use so the copy is taken once.
var _worn: ShaderMaterial = null

## The dial walks running right now, keyed by dial name, so a second call on the same dial
## replaces the first instead of the two of them fighting over it.
var _walks: Dictionary = {}

## Whether the missing-material warning has been said. A setup mistake is worth saying once;
## saying it per dial per call is a log nobody can read past to find it.
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
	_worn = found.duplicate() if own_material else found
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
