## @ace_tags(effects, shader, juice, visual)
## @ace_category("Dissolve")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/dissolve/icon.svg")
class_name DissolveBehavior
extends Node
## Burns the host away along a noise field with a glowing edge, and burns it back. Dissolve walks the burn to gone over a number of seconds and fires On Dissolved when it arrives; Appear walks it back. The burn's blotch size, edge width and edge colour live in dissolve.gdshader, which is copied into your project when the pack is added.

## The node this behavior acts on (its parent). Required host: CanvasItem.
var host: CanvasItem = null

func _enter_tree() -> void:
	host = get_parent() as CanvasItem
	if host == null:
		push_warning("DissolveBehavior behavior requires a CanvasItem parent.")

## @ace_trigger
## @ace_name("On Dissolved")
## @ace_category("Dissolve")
signal dissolved

## The dial dissolve.gdshader burns along, named once so a rename there is a one-line change
## here. 0 is whole, 1 is gone.
const BURN_DIAL: String = "dissolve"

## Hide the host once it has finished burning. A fully dissolved sprite draws nothing anyway,
## so this saves the draw; turn it off when something else is going to fade it back in.
@export var hide_when_gone: bool = true

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
## wears no ShaderMaterial at all: attaching the pack copies dissolve.gdshader into the project and assigns it,
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
			push_warning("Dissolve needs its parent to wear the dissolve.gdshader material. Add the pack again, or set the material in the Inspector.")
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

## Burns the host away over the given time and fires On Dissolved when there is nothing left.
## No time at all burns it away on the spot, which is the row for a thing that pops out of
## existence rather than fading.
## @ace_action
## @ace_featured
## @ace_name("Dissolve")
## @ace_display_template("Dissolve over [b]{seconds}[/b] s")
## @ace_icon("res://eventsheet_addons/dissolve/icon.svg")
## @ace_codegen_template("$DissolveBehavior.dissolve({seconds})")
func dissolve(seconds: float = 0.8) -> void:
	var burn: Tween = _walk_dial(BURN_DIAL, 1.0, maxf(seconds, 0.0))
	if burn == null:
		_burnt_away()
		return
	burn.finished.connect(_burnt_away)

## Burns the host back in from nothing over the given time. The host is shown again first, so
## the row works whether or not the last dissolve hid it.
## @ace_action
## @ace_name("Appear")
## @ace_display_template("Appear over [b]{seconds}[/b] s")
## @ace_icon("res://eventsheet_addons/dissolve/icon.svg")
## @ace_codegen_template("$DissolveBehavior.appear({seconds})")
func appear(seconds: float = 0.8) -> void:
	if host != null:
		host.visible = true
	_walk_dial(BURN_DIAL, 0.0, maxf(seconds, 0.0))

## True once the host has burned all the way away.
## @ace_condition
## @ace_name("Is Gone")
## @ace_icon("res://eventsheet_addons/dissolve/icon.svg")
## @ace_codegen_template("$DissolveBehavior.is_gone()")
func is_gone() -> bool:
	return _dial(BURN_DIAL, 0.0) >= 0.999

## How much of the host has burned away, 0 to 1 - for a health bar that empties with the burn,
## or a sound that follows it.
## @ace_expression
## @ace_name("Burnt Away")
## @ace_icon("res://eventsheet_addons/dissolve/icon.svg")
## @ace_codegen_template("$DissolveBehavior.burnt_away()")
func burnt_away() -> float:
	return _dial(BURN_DIAL, 0.0)

## The end of the burn: hide what is no longer drawing anything, then tell the sheet.
func _burnt_away() -> void:
	if hide_when_gone and host != null:
		host.visible = false
	dissolved.emit()

# Dissolve: put this under any 2D node or Control that wears the dissolve material. Dissolve burns it away over the seconds you give and fires On Dissolved at the end - the row that frees the boss, drops the loot or moves the scene on. Appear burns it back. The look (edge_color, edge_width, noise_scale) lives in dissolve.gdshader, copied into your project when the pack is added. This pack is an event sheet - extend it by editing it.
