# Pack builder - fade (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Fade: a fade-in / fade-out behavior you attach to any sprite or UI node (a CanvasItem). It animates
## the node's transparency, so you can flash a pickup out of existence, ease a title in, or make a
## damage number float up and disappear - without writing tween code. It can run its full
## fade-in -> hold -> fade-out sequence on its own from the Inspector times, optionally freeing the node
## when it finishes, and each stage fires a trigger so you can chain the next beat.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	# CanvasItem is the shared base of Node2D and Control, so fading works on sprites AND UI.
	sheet.host_class = "CanvasItem"
	sheet.custom_class_name = "FadeBehavior"
	sheet.class_description = "Fades any sprite or UI node in and out without tween code. Set fade-in, hold, and fade-out times in the Inspector and it runs the whole sequence on its own, optionally freeing the node when done and firing a trigger at each stage."
	sheet.addon_category = "Fade"
	sheet.addon_tags = PackedStringArray(["fade", "juice"])
	var about: CommentRow = CommentRow.new()
	about.text = "Fade: attach to a sprite or UI node. It animates transparency - Fade In, Fade Out, or Start the full fade-in / hold / fade-out sequence from the Inspector times (optionally freeing the node at the end). React with On Faded Out. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"# --- Designer knobs (tune the timing in the Inspector) ---",
		"## Seconds to fade from invisible to fully visible.",
		"@export_range(0.0, 10.0, 0.05) var fade_in_time: float = 0.5",
		"## Seconds to hold fully visible between the fade in and the fade out (used by Start).",
		"@export_range(0.0, 60.0, 0.05) var hold_time: float = 0.0",
		"## Seconds to fade from visible to invisible.",
		"@export_range(0.0, 10.0, 0.05) var fade_out_time: float = 0.5",
		"## Free (delete) the node once it has fully faded out.",
		"@export var free_on_faded_out: bool = false",
		"## Run the full fade-in / hold / fade-out sequence automatically when the node is ready.",
		"@export var start_on_ready: bool = false",
		"",
		"# Single tween, killed before each restart so overlapping fades never fight.",
		"var _tween: Tween = null",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Faded In\")",
		"signal on_faded_in()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Fade Out Started\")",
		"signal on_fade_out_started()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Faded Out\")",
		"signal on_faded_out()",
		"",
		"# Sets the host's alpha (0 = invisible, 1 = opaque) whether it is a Node2D or a Control.",
		"func _set_alpha(alpha: float) -> void:",
		"\tif host is CanvasItem:",
		"\t\t(host as CanvasItem).modulate.a = clampf(alpha, 0.0, 1.0)",
		"",
		"func _kill_tween() -> void:",
		"\tif _tween != null and _tween.is_valid():",
		"\t\t_tween.kill()",
		"\t_tween = null",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Fading\")",
		"func is_fading() -> bool:",
		"\treturn _tween != null and _tween.is_valid() and _tween.is_running()",
		"",
		"## @ace_expression",
		"## @ace_name(\"Opacity\")",
		"func opacity() -> float:",
		"\treturn (host as CanvasItem).modulate.a if host is CanvasItem else 1.0"
	]))
	sheet.events.append(block)
	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"
	var ready_body: RawCodeRow = RawCodeRow.new()
	ready_body.code = "if start_on_ready:\n\tstart_fade()"
	on_ready.actions.append(ready_body)
	sheet.events.append(on_ready)

	Lib.append_function(sheet, "fade_in", "Fade In", "Fade", "Fades the node from its current transparency up to fully visible over a duration, then fires On Faded In.",
		[["duration", "float"]],
		"if host == null:\n\treturn\n_kill_tween()\n_tween = create_tween()\n_tween.tween_property(host, \"modulate:a\", 1.0, maxf(duration, 0.0001))\n_tween.finished.connect(func() -> void: on_faded_in.emit())")
	_default(sheet, "duration", "0.5")
	Lib.append_function(sheet, "fade_out", "Fade Out", "Fade", "Fades the node down to invisible over a duration (fires On Fade Out Started now, On Faded Out at the end). Frees the node afterwards if Free On Faded Out is on.",
		[["duration", "float"]],
		"if host == null:\n\treturn\n_kill_tween()\non_fade_out_started.emit()\n_tween = create_tween()\n_tween.tween_property(host, \"modulate:a\", 0.0, maxf(duration, 0.0001))\n_tween.finished.connect(func() -> void:\n\ton_faded_out.emit()\n\tif free_on_faded_out and host != null:\n\t\thost.queue_free())")
	_default(sheet, "duration", "0.5")
	Lib.append_function(sheet, "start_fade", "Start Fade", "Fade", "Runs the whole sequence from the Inspector times: fade in, hold, then fade out (firing On Faded In, On Fade Out Started, and On Faded Out along the way). Freeing the node at the end if set.",
		[],
		"if host == null:\n\treturn\n_kill_tween()\n_set_alpha(0.0)\n_tween = create_tween()\n_tween.tween_property(host, \"modulate:a\", 1.0, maxf(fade_in_time, 0.0001))\n_tween.tween_callback(func() -> void: on_faded_in.emit())\n_tween.tween_interval(maxf(hold_time, 0.0))\n_tween.tween_callback(func() -> void: on_fade_out_started.emit())\n_tween.tween_property(host, \"modulate:a\", 0.0, maxf(fade_out_time, 0.0001))\n_tween.tween_callback(func() -> void:\n\ton_faded_out.emit()\n\tif free_on_faded_out and host != null:\n\t\thost.queue_free())")
	Lib.append_function(sheet, "stop_fade", "Stop Fade", "Fade", "Cancels any running fade, leaving the node at its current transparency.",
		[],
		"_kill_tween()")
	Lib.append_function(sheet, "set_opacity", "Set Opacity", "Fade", "Sets the node's transparency directly (0 = invisible, 1 = fully visible), cancelling any running fade.",
		[["alpha", "float"]],
		"_kill_tween()\n_set_alpha(alpha)")
	_default(sheet, "alpha", "1.0")

	# The pack's hero verbs: starred + bold at the top of their picker section.
	Lib.feature_verbs(sheet, ["fade_in", "fade_out"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/fade/fade_behavior")


## Pre-fills the last-appended ACE's parameter default (authoring-time metadata only).
static func _default(sheet: EventSheetResource, param_id: String, value: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.default_value = value
