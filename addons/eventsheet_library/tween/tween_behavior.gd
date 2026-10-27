## @ace_tags(motion, juice)
## @ace_category("Tween")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/tween/icon.svg")
class_name TweenBehavior
extends Node
## Wraps Godot's tween system in plain event rows: pick the feel once in the Inspector (transition curve and easing), then one action slides, scales, spins, or fades the host, with a trigger when it finishes. Compiles down to a normal create_tween() with zero plugin dependency.

## The node this behavior acts on (its parent). Required host: Node2D.
var host: Node2D = null

func _enter_tree() -> void:
	host = get_parent() as Node2D
	if host == null:
		push_warning("TweenBehavior behavior requires a Node2D parent.")

## @ace_trigger
## @ace_name("On Tween Finished")
signal tween_finished

## Seconds used when a tween call passes 0.
@export_range(0.01, 10, 0.01) var default_duration: float = 0.3
## Where the motion eases - in, out, or both ends.
@export_enum("in", "out", "in_out", "out_in") var easing: String = "out"
## Motion curve every tween uses (sine, bounce, elastic, and so on).
@export_enum("linear", "sine", "quad", "cubic", "quart", "quint", "expo", "circ", "elastic", "back", "bounce", "spring") var transition: String = "sine"

var _active_tween: Tween = null

## The curve tween in flight, kept so a second row on the same property replaces it rather
## than fighting it.
var _along_tween: Tween = null

## What a property held before the FIRST curve tween touched it, keyed by the property path.
## Only ever written once per property, which is what makes Tween Property Back exact however
## many times the property has been tweened since.
var _tween_starts: Dictionary = {}
## The one implementation behind Tween Property Along Curve and its awaiting twin. Returns the
## tween so the awaiting row has something to wait on, and null when there is nothing to move.
func _tween_along(property_path: String, final_value: float, seconds: float, curve: Curve, mode: String, from_value: float, to_value: float) -> Tween:
	if host == null or curve == null:
		return null
	var path := NodePath(property_path)
	var start_value: float = float(host.get_indexed(path))
	if not _tween_starts.has(property_path):
		_tween_starts[property_path] = start_value
	var seconds_used: float = seconds if seconds > 0.0 else default_duration
	_along_kill()
	if not host.is_inside_tree():
		# A tween needs a live tree. A row that ran before the host entered one has still
		# recorded where the property was, so Tween Property Back knows the way home.
		return null
	var along: Tween = host.create_tween()
	var write := func(fraction: float) -> void:
		if host == null:
			return
		host.set_indexed(path, _along_value(start_value, curve.sample(fraction), final_value, mode, from_value, to_value))
	along.tween_method(write, 0.0, 1.0, maxf(seconds_used, 0.01))
	along.finished.connect(func() -> void: tween_finished.emit())
	_along_tween = along
	return along

## @ace_action
## @ace_featured
## @ace_name("Tween Property")
## @ace_category("Tween")
## @ace_description("Tweens any host property (e.g. position:x) to a value.")
## @ace_display_template("Tween [b]{property_path}[/b] to [b]{final_value}[/b] over [b]{duration}[/b] s")
## @ace_icon("res://eventsheet_addons/tween/icon.svg")
## @ace_codegen_template("$TweenBehavior.tween_property_to({property_path}, {final_value}, {duration})")
func tween_property_to(property_path: String, final_value: float, duration: float) -> void:
	_start_tween(property_path, final_value, duration)

## @ace_action
## @ace_name("Tween Position")
## @ace_category("Tween")
## @ace_description("Moves the host to (x, y).")
## @ace_icon("res://eventsheet_addons/tween/icon.svg")
## @ace_codegen_template("$TweenBehavior.tween_position({x}, {y}, {duration})")
func tween_position(x: float, y: float, duration: float) -> void:
	_start_tween("position", Vector2(x, y), duration)

## @ace_action
## @ace_name("Tween Scale")
## @ace_category("Tween")
## @ace_description("Scales the host uniformly.")
## @ace_icon("res://eventsheet_addons/tween/icon.svg")
## @ace_codegen_template("$TweenBehavior.tween_scale({amount}, {duration})")
func tween_scale(amount: float, duration: float) -> void:
	_start_tween("scale", Vector2(amount, amount), duration)

## @ace_action
## @ace_name("Tween Rotation")
## @ace_category("Tween")
## @ace_description("Rotates the host to the given degrees.")
## @ace_icon("res://eventsheet_addons/tween/icon.svg")
## @ace_codegen_template("$TweenBehavior.tween_rotation({degrees}, {duration})")
func tween_rotation(degrees: float, duration: float) -> void:
	_start_tween("rotation_degrees", degrees, duration)

## @ace_action
## @ace_name("Tween Alpha")
## @ace_category("Tween")
## @ace_description("Fades the host's modulate alpha.")
## @ace_icon("res://eventsheet_addons/tween/icon.svg")
## @ace_codegen_template("$TweenBehavior.tween_alpha({alpha}, {duration})")
func tween_alpha(alpha: float, duration: float) -> void:
	_start_tween("modulate:a", clampf(alpha, 0.0, 1.0), duration)

## @ace_action
## @ace_name("Stop Tweens")
## @ace_category("Tween")
## @ace_description("Kills the running tween (host stays where it is).")
## @ace_icon("res://eventsheet_addons/tween/icon.svg")
## @ace_codegen_template("$TweenBehavior.stop_tweens()")
func stop_tweens() -> void:
	if _active_tween != null:
		_active_tween.kill()
		_active_tween = null

## @ace_action
## @ace_name("Tween Property Along Curve")
## @ace_category("Tween")
## @ace_description("Tweens a number property along a Curve file you own, in one of four readings: the curve as the value, added to where the property was, from there to a destination, or the curve's 0 to 1 remapped between two numbers. The value the property had before the first of these touched it is remembered, so Tween Property Back can return to it.")
## @ace_display_template("Tween [b]{property_path}[/b] along [b]{curve}[/b] over [b]{seconds}[/b] s")
## @ace_param(property_path, desc: "The number property to move, as the Inspector spells it: rotation_degrees, modulate:a, position:x.")
## @ace_param(final_value, desc: "The number the mode reads: the value, the offset, or the destination. Ignored by remap.")
## @ace_param(seconds, default: 0.4, desc: "How long the whole curve takes. 0 uses the behavior's default duration.")
## @ace_param(curve, desc: "The Curve file the motion follows. It is your file: draw it once in the Inspector and reuse it anywhere.")
## @ace_param(mode, options: absolute|relative|to destination|remap, default: to destination, desc: "How the curve is read: absolute, relative, to destination, or remap.")
## @ace_param(from_value, desc: "Remap only: the number the curve's 0 stands for.")
## @ace_param(to_value, desc: "Remap only: the number the curve's 1 stands for.")
## @ace_icon("res://eventsheet_addons/tween/icon.svg")
## @ace_codegen_template("$TweenBehavior.tween_along({property_path}, {final_value}, {seconds}, {curve}, "{mode}", {from_value}, {to_value})")
func tween_along(property_path: String, final_value: float, seconds: float, curve: Curve, mode: String, from_value: float, to_value: float) -> void:
	_tween_along(property_path, final_value, seconds, curve, mode, from_value, to_value)

## @ace_action
## @ace_name("Tween Property And Wait")
## @ace_category("Tween")
## @ace_description("The same curve tween, waited on: the rows under it run when the property has arrived. Use it to write a beat as one column of rows instead of a timer guessed to match.")
## @ace_display_template("Tween [b]{property_path}[/b] along [b]{curve}[/b] over [b]{seconds}[/b] s and wait")
## @ace_param(property_path, desc: "The number property to move, as the Inspector spells it.")
## @ace_param(final_value, desc: "The number the mode reads: the value, the offset, or the destination. Ignored by remap.")
## @ace_param(seconds, default: 0.4, desc: "How long the whole curve takes. 0 uses the behavior's default duration.")
## @ace_param(curve, desc: "The Curve file the motion follows.")
## @ace_param(mode, options: absolute|relative|to destination|remap, default: to destination, desc: "How the curve is read: absolute, relative, to destination, or remap.")
## @ace_param(from_value, desc: "Remap only: the number the curve's 0 stands for.")
## @ace_param(to_value, desc: "Remap only: the number the curve's 1 stands for.")
## @ace_icon("res://eventsheet_addons/tween/icon.svg")
## @ace_codegen_template("await $TweenBehavior.tween_along_and_wait({property_path}, {final_value}, {seconds}, {curve}, "{mode}", {from_value}, {to_value})")
func tween_along_and_wait(property_path: String, final_value: float, seconds: float, curve: Curve, mode: String, from_value: float, to_value: float) -> void:
	var along: Tween = _tween_along(property_path, final_value, seconds, curve, mode, from_value, to_value)
	if along != null:
		await along.finished

## @ace_action
## @ace_name("Tween Property Back")
## @ace_category("Tween")
## @ace_description("Returns a property to the value it held before the first curve tween touched it, over the behavior's own transition and easing. A lid that opened closes with the same number nobody had to type twice.")
## @ace_display_template("Tween [b]{property_path}[/b] back over [b]{seconds}[/b] s")
## @ace_param(property_path, desc: "The property to send home.")
## @ace_param(seconds, default: 0.3, desc: "How long the way back takes. 0 uses the behavior's default duration.")
## @ace_icon("res://eventsheet_addons/tween/icon.svg")
## @ace_codegen_template("$TweenBehavior.tween_back({property_path}, {seconds})")
func tween_back(property_path: String, seconds: float) -> void:
	if host == null or not _tween_starts.has(property_path):
		return
	_along_kill()
	_start_tween(property_path, float(_tween_starts[property_path]), seconds)

## @ace_condition
## @ace_name("Is Tweening")
## @ace_icon("res://eventsheet_addons/tween/icon.svg")
## @ace_codegen_template("$TweenBehavior.is_tweening()")
func is_tweening() -> bool:
	return _active_tween != null and _active_tween.is_running()

func _trans_id() -> int:
	match transition:
		"linear": return Tween.TRANS_LINEAR
		"quad": return Tween.TRANS_QUAD
		"cubic": return Tween.TRANS_CUBIC
		"quart": return Tween.TRANS_QUART
		"quint": return Tween.TRANS_QUINT
		"expo": return Tween.TRANS_EXPO
		"circ": return Tween.TRANS_CIRC
		"elastic": return Tween.TRANS_ELASTIC
		"back": return Tween.TRANS_BACK
		"bounce": return Tween.TRANS_BOUNCE
		"spring": return Tween.TRANS_SPRING
	return Tween.TRANS_SINE

func _ease_id() -> int:
	match easing:
		"in": return Tween.EASE_IN
		"in_out": return Tween.EASE_IN_OUT
		"out_in": return Tween.EASE_OUT_IN
	return Tween.EASE_OUT

func _start_tween(property_path: String, final_value: Variant, duration: float) -> void:
	if host == null:
		return
	var seconds: float = duration if duration > 0.0 else default_duration
	_active_tween = host.create_tween()
	_active_tween.tween_property(host, NodePath(property_path), final_value, seconds).set_trans(_trans_id()).set_ease(_ease_id())
	_active_tween.finished.connect(func() -> void: tween_finished.emit())

func _along_kill() -> void:
	if _along_tween != null and _along_tween.is_valid():
		_along_tween.kill()
	_along_tween = null

## The number the property takes at one point along the curve, in the mode the row chose.
## `sampled` is what the curve reads at that point, which is usually 0 to 1 but need not be:
## a curve that overshoots is exactly how a lid slams past its stop and settles back.
func _along_value(start_value: float, sampled: float, final_value: float, mode: String, from_value: float, to_value: float) -> float:
	match mode:
		"relative":
			return start_value + final_value * sampled
		"to destination":
			return lerpf(start_value, final_value, sampled)
		"remap":
			return lerpf(from_value, to_value, sampled)
	return final_value * sampled

# Tweens, the behavior way: pick transition + easing in the Inspector, then call one action - Tween Position / Scale / Rotation / Alpha / any property.
