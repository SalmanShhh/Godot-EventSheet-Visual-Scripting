## @ace_tags(fade, juice)
## @ace_category("Fade")
@icon("res://eventsheet_addons/fade/icon.svg")
class_name FadeBehavior
extends Node
## Fades any sprite or UI node in and out without tween code. Set fade-in, hold, and fade-out times in the Inspector and it runs the whole sequence on its own, optionally freeing the node when done and firing a trigger at each stage.

## The node this behavior acts on (its parent). Required host: CanvasItem.
var host: CanvasItem = null

func _enter_tree() -> void:
	host = get_parent() as CanvasItem
	if host == null:
		push_warning("FadeBehavior behavior requires a CanvasItem parent.")

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
var _tween: Tween = null

func _ready() -> void:
	if start_on_ready:
		start_fade()

## @ace_action
## @ace_featured
## @ace_name("Fade In")
## @ace_category("Fade")
## @ace_description("Fades the node from its current transparency up to fully visible over a duration, then fires On Faded In.")
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
