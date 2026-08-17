# Pack builder - debug_overlay (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Debug Overlay: the throwaway heads-up display every project hand-rolls, as an AUTOLOAD
## CanvasLayer driven entirely from sheet rows. Watch a named value, draw a bar, mark a world
## point, draw a ray, label a node - drawn on the GAME, where you can see it in fullscreen, on a
## phone, on a console, and in the build a playtester is running. Print cannot do any of that.
##
## Three properties keep it honest, and every one of them is enforced in the emitted code below:
##   OFF UNLESS A ROW ASKS. The CanvasLayer's drawing surface is built by _ensure_surface() on the
##   FIRST verb call, so a project with no Debug Overlay rows creates no node and draws nothing.
##   DEBUG BUILDS ONLY. _ensure_surface() returns false when OS.is_debug_build() is false, which is
##   the same gate the shipped Log (Debug Builds Only) verb uses, so a release carries none of it.
##   NEVER ON THE SHEET. It paints on the game viewport only. No row gains a chip, a tint or a
##   readout, and the editor canvas is not touched at all.
## The toggle key hides it without editing a row, and On Overlay Toggled is a real signal carrying
## whether it is now shown, so a sheet can react to the key press like any other trigger.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.autoload_mode = true
	sheet.autoload_name = "DebugOverlay"
	sheet.host_class = "CanvasLayer"
	sheet.custom_class_name = "DebugOverlayAddon"
	sheet.class_description = "An on-screen debug display driven from event rows, drawn over the running game and only in debug builds. Watch Value lists named values, Show Bar draws a labelled meter, Mark Point drops a fading cross in the world, Draw Ray shows a direction, and Label Above floats text over a node. Nothing exists until a row calls one of them, and the toggle key hides the whole thing while you play."
	sheet.addon_category = "Debug Overlay"
	sheet.addon_tags = PackedStringArray(["debug", "overlay", "hud", "profiling"])
	sheet.variables = {
		"toggle_key": {"type": "String", "default": "F3", "exported": true, "description": "Key that shows and hides the overlay while the game runs. Blank turns the key off.",
			"attributes": {"tooltip": "Key that shows and hides the overlay while the game runs, by name (F3, F1, Tab, Escape). Leave blank for no key.", "group": "Debug Overlay"}},
		"start_hidden": {"type": "bool", "default": false, "exported": true, "description": "Start with the overlay hidden, so the toggle key reveals it on demand.",
			"attributes": {"tooltip": "Start hidden: rows still record, nothing is drawn until you press the toggle key.", "group": "Debug Overlay"}},
	}

	var about: CommentRow = CommentRow.new()
	about.text = "Debug Overlay (autoload): register as the DebugOverlay autoload, then call its verbs from any sheet - Watch Value, Show Bar, Mark Point, Draw Ray, Label Above. The drawing surface is created on the FIRST call and only in a debug build, so a project that never calls it pays nothing and an exported release draws nothing. Press the toggle key (F3 by default) to hide it while you play. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	var toggled: SignalRow = SignalRow.new()
	toggled.signal_name = "overlay_toggled"
	toggled.params = PackedStringArray(["shown: bool"])
	toggled.trigger = true
	toggled.ace_name = "On Overlay Toggled"
	toggled.ace_category = "Debug Overlay"
	sheet.events.append(toggled)

	sheet.events.append(_runtime_block())

	# The overlay owns its own frame: it ages the timed entries out and repaints. Both are no-ops
	# until a verb has built the surface, so an unused autoload costs one null check per frame.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "_expire_overlay_entries()"
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	var ready_row: EventRow = EventRow.new()
	ready_row.trigger_provider_id = "Core"
	ready_row.trigger_id = "OnReady"
	var ready_body: RawCodeRow = RawCodeRow.new()
	ready_body.code = "\n".join(PackedStringArray([
		"layer = 128",
		"_shown = not start_hidden",
	]))
	ready_row.actions.append(ready_body)
	sheet.events.append(ready_row)

	_append_verbs(sheet)

	Lib.verb_sentences(sheet, {
		"watch_value": "Watch [b]{watch_name}[/b] = [b]{value}[/b]",
		"clear_watch": "Stop watching [b]{watch_name}[/b]",
		"show_bar": "Bar [b]{bar_name}[/b] = [b]{fraction}[/b] in [b]{bar_color}[/b]",
		"mark_point": "Mark point [b]{at}[/b] label [b]{mark_label}[/b] for [b]{seconds}[/b]s",
		"draw_ray": "Draw ray from [b]{origin}[/b] toward [b]{direction}[/b] length [b]{length}[/b]",
		"label_above": "Label above [i]{node}[/i] text [b]{label_text}[/b]",
	})
	Lib.feature_verbs(sheet, ["watch_value", "mark_point"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/debug_overlay/debug_overlay_addon")


## The class-level runtime: the lazily-built drawing surface, the entry stores, the painter, the
## world-to-screen helpers and the toggle key. All of it is unpublished (## @ace_hidden) - a sheet
## drives the overlay through the verbs, never through these.
static func _runtime_block() -> RawCodeRow:
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"# The drawing surface is a plain Control child whose `draw` signal we paint from, so the",
		"# whole overlay stays one dependency-free script with no second file to ship. It is null",
		"# until a verb calls _ensure_surface(), which is what makes an unused overlay cost nothing.",
		"var _surface: Control = null",
		"var _shown: bool = true",
		"# Watches and bars are keyed by name (with a parallel order list so the list does not",
		"# reshuffle every frame). Marks, rays and labels are timed entries that age themselves out.",
		"var _watches: Dictionary = {}",
		"var _watch_order: PackedStringArray = PackedStringArray()",
		"var _bars: Dictionary = {}",
		"var _bar_order: PackedStringArray = PackedStringArray()",
		"var _marks: Array = []",
		"var _rays: Array = []",
		"var _labels: Array = []",
		"",
		"# Builds the surface on FIRST use, and only in a debug build. Every verb starts with this,",
		"# so an exported release build never creates a node and never draws a pixel.",
		"## @ace_hidden",
		"func _ensure_surface() -> bool:",
		"\tif not OS.is_debug_build():",
		"\t\treturn false",
		"\tif _surface != null:",
		"\t\treturn true",
		"\t_surface = Control.new()",
		"\t_surface.name = \"DebugOverlaySurface\"",
		"\t_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE",
		"\tadd_child(_surface)",
		"\t_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)",
		"\t_surface.draw.connect(_paint_overlay)",
		"\t_surface.visible = _shown",
		"\treturn true",
		"",
		"# Ages every timed entry out and repaints. Called once a frame by the pack's own tick row.",
		"## @ace_hidden",
		"func _expire_overlay_entries() -> void:",
		"\tif _surface == null:",
		"\t\treturn",
		"\tvar now: int = Time.get_ticks_msec()",
		"\tfor index: int in range(_marks.size() - 1, -1, -1):",
		"\t\tif now >= int((_marks[index] as Array)[3]):",
		"\t\t\t_marks.remove_at(index)",
		"\tfor index: int in range(_rays.size() - 1, -1, -1):",
		"\t\tif now >= int((_rays[index] as Array)[3]):",
		"\t\t\t_rays.remove_at(index)",
		"\tfor index: int in range(_labels.size() - 1, -1, -1):",
		"\t\tvar entry: Array = _labels[index] as Array",
		"\t\tif now >= int(entry[2]) or not is_instance_valid(entry[0]):",
		"\t\t\t_labels.remove_at(index)",
		"\t_surface.queue_redraw()",
		"",
		"# The painter. Watches and bars stack down the top-left corner; marks, rays and labels are",
		"# world positions pushed through the canvas transform so they sit where the thing is.",
		"## @ace_hidden",
		"func _paint_overlay() -> void:",
		"\tif _surface == null:",
		"\t\treturn",
		"\tvar font: Font = ThemeDB.fallback_font",
		"\tif font == null:",
		"\t\treturn",
		"\tvar row_y: float = 20.0",
		"\tfor watch_name: String in _watch_order:",
		"\t\t_surface.draw_string(font, Vector2(12.0, row_y), \"%s = %s\" % [watch_name, str(_watches.get(watch_name, \"\"))], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(1.0, 1.0, 1.0))",
		"\t\trow_y += 18.0",
		"\tfor bar_name: String in _bar_order:",
		"\t\tvar bar: Array = _bars.get(bar_name, [0.0, Color.WHITE]) as Array",
		"\t\tvar fraction: float = clampf(float(bar[0]), 0.0, 1.0)",
		"\t\t_surface.draw_string(font, Vector2(12.0, row_y), bar_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(1.0, 1.0, 1.0))",
		"\t\t_surface.draw_rect(Rect2(Vector2(140.0, row_y - 11.0), Vector2(160.0, 12.0)), Color(0.0, 0.0, 0.0, 0.45))",
		"\t\t_surface.draw_rect(Rect2(Vector2(140.0, row_y - 11.0), Vector2(160.0 * fraction, 12.0)), bar[1] as Color)",
		"\t\trow_y += 18.0",
		"\tfor mark: Array in _marks:",
		"\t\tvar at: Vector2 = _world_to_screen(mark[0] as Vector2)",
		"\t\tvar mark_color: Color = mark[2] as Color",
		"\t\t_surface.draw_line(at + Vector2(-6.0, -6.0), at + Vector2(6.0, 6.0), mark_color, 2.0)",
		"\t\t_surface.draw_line(at + Vector2(-6.0, 6.0), at + Vector2(6.0, -6.0), mark_color, 2.0)",
		"\t\t_surface.draw_string(font, at + Vector2(10.0, -8.0), str(mark[1]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, mark_color)",
		"\tfor ray: Array in _rays:",
		"\t\t_surface.draw_line(_world_to_screen(ray[0] as Vector2), _world_to_screen(ray[1] as Vector2), ray[2] as Color, 2.0)",
		"\tfor label_entry: Array in _labels:",
		"\t\tif not is_instance_valid(label_entry[0]):",
		"\t\t\tcontinue",
		"\t\t_surface.draw_string(font, _node_screen_position(label_entry[0] as Node) + Vector2(-16.0, -18.0), str(label_entry[1]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(1.0, 0.9, 0.55))",
		"",
		"# World space to screen space. The 2D canvas transform already accounts for the camera, so",
		"# a marked point stays glued to the world while the camera moves.",
		"## @ace_hidden",
		"func _world_to_screen(world_position: Vector2) -> Vector2:",
		"\tvar view: Viewport = get_viewport()",
		"\tif view == null:",
		"\t\treturn world_position",
		"\treturn view.get_canvas_transform() * world_position",
		"",
		"# Where a node appears on screen, in 2D or in 3D (a Node3D goes through the active camera's",
		"# projection). An off-tree or unprojectable node reads as the top-left corner.",
		"## @ace_hidden",
		"func _node_screen_position(node: Node) -> Vector2:",
		"\tif node is Node2D:",
		"\t\treturn _world_to_screen((node as Node2D).global_position)",
		"\tif node is Control:",
		"\t\treturn (node as Control).global_position",
		"\tif node is Node3D:",
		"\t\tvar view: Viewport = get_viewport()",
		"\t\tvar camera: Camera3D = view.get_camera_3d() if view != null else null",
		"\t\tif camera != null:",
		"\t\t\treturn camera.unproject_position((node as Node3D).global_position)",
		"\treturn Vector2.ZERO",
		"",
		"# Shows or hides the overlay and announces it. The signal only fires on a real change, so a",
		"# row under On Overlay Toggled never sees a repeat of the state it is already in.",
		"## @ace_hidden",
		"func _set_overlay_shown(shown: bool) -> void:",
		"\tif _shown == shown:",
		"\t\treturn",
		"\t_shown = shown",
		"\tif _surface != null:",
		"\t\t_surface.visible = _shown",
		"\toverlay_toggled.emit(_shown)",
		"",
		"# The toggle key, read by name (F3, F1, Tab...) so the Inspector field stays readable. Only",
		"# in a debug build, and only when a key name is set.",
		"func _unhandled_input(event: InputEvent) -> void:",
		"\tif not OS.is_debug_build() or toggle_key.strip_edges().is_empty():",
		"\t\treturn",
		"\tvar key_event: InputEventKey = event as InputEventKey",
		"\tif key_event == null or not key_event.pressed or key_event.echo:",
		"\t\treturn",
		"\tif key_event.keycode == OS.find_keycode_from_string(toggle_key.strip_edges()):",
		"\t\t_set_overlay_shown(not _shown)",
	]))
	return block


## The published vocabulary: five drawing effects, four visibility effects, one condition. Every
## one is a void effect in the action lane except Overlay Is Visible, which is a question.
static func _append_verbs(sheet: EventSheetResource) -> void:
	Lib.append_function(sheet, "watch_value", "Watch Value", "Debug Overlay",
		"Shows name = value in the on-screen list, refreshed every time you set it. Call it from an Every Frame row and it reads like a live watch window over the running game. Debug builds only.",
		[["watch_name", "String"], ["value", "Variant"]],
		"\n".join(PackedStringArray([
			"if not _ensure_surface():",
			"\treturn",
			"if not _watches.has(watch_name):",
			"\t_watch_order.append(watch_name)",
			"_watches[watch_name] = str(value)",
		])))
	Lib.append_function(sheet, "clear_watch", "Clear Watch", "Debug Overlay",
		"Drops one named value from the on-screen list, for when a watch has served its purpose and is just taking up a line.",
		[["watch_name", "String"]],
		"\n".join(PackedStringArray([
			"_watches.erase(watch_name)",
			"var index: int = _watch_order.find(watch_name)",
			"if index >= 0:",
			"\t_watch_order.remove_at(index)",
		])))
	Lib.append_function(sheet, "show_bar", "Show Bar", "Debug Overlay",
		"Draws a named meter filled to a fraction from 0 to 1, in the colour you pick. The fastest way to see stamina, a cooldown, or an AI's confidence without building any UI.",
		[["bar_name", "String"], ["fraction", "float"], ["bar_color", "Color"]],
		"\n".join(PackedStringArray([
			"if not _ensure_surface():",
			"\treturn",
			"if not _bars.has(bar_name):",
			"\t_bar_order.append(bar_name)",
			"_bars[bar_name] = [fraction, bar_color]",
		])))
	Lib.append_function(sheet, "mark_point", "Mark Point", "Debug Overlay",
		"Drops a labelled cross at a world position for a moment, so you can SEE where something happened. The mark stays glued to the world while the camera moves, then fades out on its own.",
		[["at", "Vector2"], ["mark_label", "String"], ["seconds", "float"]],
		"\n".join(PackedStringArray([
			"if not _ensure_surface():",
			"\treturn",
			"_marks.append([at, mark_label, Color(1.0, 0.4, 0.4), Time.get_ticks_msec() + int(maxf(seconds, 0.05) * 1000.0)])",
		])))
	Lib.append_function(sheet, "draw_ray", "Draw Ray", "Debug Overlay",
		"Draws a line from a world position along a direction for a given length, which is what you want on screen while tuning a detection cone, an aim vector, or a raycast that keeps missing.",
		[["origin", "Vector2"], ["direction", "Vector2"], ["length", "float"], ["ray_color", "Color"], ["seconds", "float"]],
		"\n".join(PackedStringArray([
			"if not _ensure_surface():",
			"\treturn",
			"_rays.append([origin, origin + direction.normalized() * length, ray_color, Time.get_ticks_msec() + int(maxf(seconds, 0.05) * 1000.0)])",
		])))
	Lib.append_function(sheet, "label_above", "Label Above", "Debug Overlay",
		"Floats a line of text above a node for a moment - the fastest way to debug a dozen enemies at once, because each one carries its own state on screen. Works for a Node2D, a Control, or a Node3D seen through the active camera.",
		[["node", "Node"], ["label_text", "String"], ["seconds", "float"]],
		"\n".join(PackedStringArray([
			"if not _ensure_surface():",
			"\treturn",
			"_labels.append([node, label_text, Time.get_ticks_msec() + int(maxf(seconds, 0.05) * 1000.0)])",
		])))
	Lib.append_function(sheet, "show_overlay", "Show Overlay", "Debug Overlay",
		"Makes the overlay visible again after it was hidden. Fires On Overlay Toggled when it was actually hidden.",
		[],
		"_set_overlay_shown(true)")
	Lib.append_function(sheet, "hide_overlay", "Hide Overlay", "Debug Overlay",
		"Hides the overlay without clearing anything. Rows keep recording, so showing it again brings the values straight back.",
		[],
		"_set_overlay_shown(false)")
	Lib.append_function(sheet, "toggle_overlay", "Toggle Overlay", "Debug Overlay",
		"Flips the overlay between shown and hidden, the same thing the toggle key does - put it on a button so a playtester can turn it on for a screenshot.",
		[],
		"_set_overlay_shown(not _shown)")
	Lib.append_function(sheet, "clear_overlay", "Clear Overlay", "Debug Overlay",
		"Wipes every watch, bar, mark, ray and label at once. Useful between levels, or at the head of a run so last run's evidence does not confuse this one.",
		[],
		"\n".join(PackedStringArray([
			"_watches.clear()",
			"_watch_order = PackedStringArray()",
			"_bars.clear()",
			"_bar_order = PackedStringArray()",
			"_marks.clear()",
			"_rays.clear()",
			"_labels.clear()",
		])))
	Lib.condition(sheet, "is_overlay_visible", "Overlay Is Visible", "Debug Overlay",
		"True while the overlay is on screen. False in a release build, before any row has drawn to it, and while the toggle key has it hidden.",
		[],
		"return _shown and _surface != null")
