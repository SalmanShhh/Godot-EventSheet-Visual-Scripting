# EventForge - Trigger resolver
# Maps EventForge trigger IDs to generated GDScript function signatures, and - for
# signal-backed triggers - to the signal that must be connected in `_ready` (the compiler
# emits the connection; handlers used to be generated but never connected). Custom signal
# triggers from reflection providers use the "signal:<name>" id convention, with their
# argument signature baked onto the event as `trigger_args` at apply time.
@tool
class_name TriggerResolver
extends RefCounted


## The trigger id a TOP-LEVEL event actually compiles as. A blank event - no trigger picked - means
## in an event sheet exactly what it looks like: it runs every tick, so it compiles as the every-tick
## trigger would, conditions and all. Nothing is stored on the row (a blank event stays blank on
## disk); this is only the compiler's reading of "blank".
const EVERY_TICK_TRIGGER_ID: String = "OnProcess"

## The vocabulary module the every-tick trigger belongs to. A blank event borrows it too, so a blank
## event and an every-tick event picked from the list group into the SAME handler instead of asking
## for two `_process` functions (which would not parse).
const EVERY_TICK_TRIGGER_PROVIDER_ID: String = "Core"


## The trigger id to compile an event with, resolving a blank trigger to the every-tick one.
static func effective_trigger_id(event: EventRow) -> String:
	return event.trigger_id if not event.trigger_id.is_empty() else EVERY_TICK_TRIGGER_ID


## Returns a stable trigger-group key. The source path is part of the key because the same
## signal from different source nodes needs different handlers.
static func get_trigger_key(event: EventRow) -> String:
	var trigger_id: String = effective_trigger_id(event)
	var provider_id: String = event.trigger_provider_id
	if event.trigger_id.is_empty():
		provider_id = EVERY_TICK_TRIGGER_PROVIDER_ID
	if trigger_id == MENU_TRIGGER_ID:
		# W6. Every item of ONE menu shares a single handler, for the same reason every notification
		# shares `_notification`: the engine calls one function with the id that was chosen, and which
		# item an event answers is a case inside it. The menu is therefore part of the key, and the
		# item is not.
		return "%s::%s::%s" % [provider_id, trigger_id, menu_variable_of(event)]
	if trigger_id.begins_with(NOTIFICATION_PREFIX):
		# Every notification a sheet reacts to shares ONE `_notification` handler: the engine calls
		# that single function for every notification, and two same-named functions do not parse.
		# Which notification an event wants rides on its own id and becomes a case inside the handler.
		trigger_id = "OnNotification"
	return "%s::%s::%s" % [provider_id, trigger_id, event.trigger_source_path]


## W6. The trigger every menu item's event carries. The menu it belongs to and the item's id ride in
## its trigger params, because both of them are things the author typed rather than parts of the id.
const MENU_TRIGGER_ID: String = "OnMenuItemChosen"

## The `member:` source-path prefix a menu handler is connected through. A menu is a VARIABLE of the
## script, not a node the sheet looked up by path, so the `_ready` line that wires it reads
## `sheet_popup.id_pressed.connect(...)` - the spelling every hand-written menu already uses.
const MEMBER_SOURCE_PREFIX: String = "member:"


## W6. The menu variable a menu-item event names, "" for any other trigger.
static func menu_variable_of(event: EventRow) -> String:
	if effective_trigger_id(event) != MENU_TRIGGER_ID:
		return ""
	return str(event.trigger_params.get("menu", "")).strip_edges()


## W6. The item id a menu-item event answers, "" for any other trigger.
static func menu_item_id_of(event: EventRow) -> String:
	if effective_trigger_id(event) != MENU_TRIGGER_ID:
		return ""
	return str(event.trigger_params.get("item", "")).strip_edges()


## W6. The handler name a menu's events share: `_on_<menu>_id_pressed`, with the menu's own spelling
## reduced to a safe identifier fragment (`_dock._view_menu` -> `dock_view_menu`).
static func menu_handler_name(menu_variable: String) -> String:
	var bare: String = menu_variable.strip_edges().replace("self.", "").replace(".", "_").lstrip("_")
	return "_on_%s_id_pressed" % (bare if not bare.is_empty() else "menu")


## Trigger ids of the form "OnNotification:<NAME>" - one per engine notification constant a sheet
## reacts to (NAME is the constant without its `NOTIFICATION_` prefix stripped: the id carries the
## full constant, so the emitted case is the constant itself).
const NOTIFICATION_PREFIX: String = "OnNotification:"


## The notification constant an "OnNotification:<NAME>" event names, or "" for any other trigger.
static func notification_constant_for(trigger_id: String) -> String:
	if not trigger_id.begins_with(NOTIFICATION_PREFIX):
		return ""
	return trigger_id.substr(NOTIFICATION_PREFIX.length())


## Resolves trigger metadata for code generation:
## - function_name/args: the handler signature to emit
## - signal_name: non-empty for signal-backed triggers (the compiler emits
##   `<source>.<signal_name>.connect(<function_name>)` in `_ready`)
## - source_path: the node whose signal fires ("" = self); baked into the handler name so
##   "On landed (Platform)" and "On landed (Boss)" coexist.
static func resolve_trigger(event: EventRow) -> Dictionary:
	var source_path: String = event.trigger_source_path.strip_edges()
	var source_token: String = _identifier_for_source(source_path)
	match effective_trigger_id(event):
		"OnReady":
			return _lifecycle("_ready", "")
		"OnProcess":
			return _lifecycle("_process", "delta: float")
		"OnPhysicsProcess":
			return _lifecycle("_physics_process", "delta: float")
		"OnInput":
			return _lifecycle("_input", "event: InputEvent")
		"OnUnhandledInput":
			return _lifecycle("_unhandled_input", "event: InputEvent")
		"OnUnhandledKeyInput":
			return _lifecycle("_unhandled_key_input", "event: InputEvent")
		"OnInputEvent":
			# R26. Input that landed ON this body: the collision shape the click hit rides along, so
			# the handler can tell which part of the object was picked.
			return _lifecycle("_input_event", "viewport: Viewport, event: InputEvent, shape_idx: int")
		"OnControlInput":
			# W8. Input that landed on this UI element, after the global handlers passed on it.
			return _lifecycle("_gui_input", "event: InputEvent")
		"OnDraw":
			# The object's own paint pass. Runs when the node is asked to redraw (`queue_redraw()`),
			# which is why it classifies as a reaction rather than a per-frame tick below.
			return _lifecycle("_draw", "")
		"OnEnterTree":
			return _lifecycle("_enter_tree", "")
		"OnExitTree":
			return _lifecycle("_exit_tree", "")
		"OnEditorRun":
			return _lifecycle("_run", "")
		"OnCommandToolRun":
			# W10. A command tool is a SceneTree script: the engine builds it and that IS the program,
			# so `_init` is not "on created" the way it is on a node - it is the whole run. Same
			# reasoning as OnPluginEnabled sharing _enter_tree: one engine callback, a different name
			# because a reader of a command tool is looking for a different idea. The reading side
			# already files a SceneTree script's `_init` under "Command tool ▸ On run", so a tool
			# authored from this row and one typed by hand are the same file.
			return _lifecycle("_init", "")
		"OnProjectExport":
			# The project-export bake step. Not an engine virtual: the editor's export hook calls this
			# function by name on the compiled Editor Tool script (that is the whole seam), and hands it
			# the two facts a bake step needs - whether the export is a debug build, and the preset's
			# feature tags. Plain GDScript on both sides, so the emitted script keeps zero plugin
			# dependency and simply does nothing when nobody calls it.
			return _lifecycle("_on_project_export", "is_debug: bool, features: PackedStringArray")
		"OnFileImported":
			# The import reaction, built the same way and for the same reasons as the bake step above:
			# not an engine virtual, but a plain named function the editor's import hook calls with the
			# paths that just landed. A plain function is also what lets an opened tool read back - a
			# connection spelled through EditorInterface would strand the whole handler as code.
			return _lifecycle("_on_files_imported", "paths: PackedStringArray")
		"OnNoiseHeard":
			# X24. The receiving half of Make Noise. Not an engine virtual and deliberately not a
			# signal either: the noise maker walks the listening group and CALLS this by name, which
			# is the only spelling that works when the listeners are not connected to anything and
			# come and go with the level. Plain GDScript on both sides, so a compiled guard has zero
			# plugin dependency and simply never runs when nothing makes a noise.
			return _lifecycle("hear", "at: Variant")
		"OnPluginEnabled":
			# R30. An EditorPlugin's `_enter_tree` is not "on created" - it is the moment the plugin was
			# switched on, which is when a plugin hangs its dock and adds its menu items. Same function
			# as OnEnterTree, a different name because a reader of a plugin looks for a different idea.
			return _lifecycle("_enter_tree", "")
		"OnPluginDisabled":
			return _lifecycle("_exit_tree", "")
		"OnEditorObjectSelected":
			return _lifecycle("_edit", "object: Object")
		"OnDrawOver2DViewport":
			return _lifecycle("_forward_canvas_draw_over_viewport", "overlay: Control")
		"On2DViewportInput":
			# The one editor virtual that ANSWERS: true means this plugin consumed the input and the
			# viewport must not also act on it. The handler therefore carries a `bool` return type, and
			# an event that never returns would not parse - which is why the starter ends with a return.
			return _lifecycle("_forward_canvas_gui_input", "event: InputEvent", "bool")
		"OnDrawGizmo":
			return _lifecycle("_redraw", "")
		"OnTestStart":
			# A Test sheet's start. Signal-backed on the sheet itself: the sheet declares
			# `signal test_started(test_name: String)` (the compiler emits it for a test sheet) and a
			# runner emits it with the test's name, so the trigger has a real signal behind it and the
			# name arrives as the handler's argument - not a bare hook nobody can raise by hand.
			return _signal_backed("_on_test_started", "test_name: String", "test_started", "")
		"OnPostTick":
			# Godot's "post-tick": SceneTree.process_frame fires ONCE after every node's _process this
			# frame - for logic that must run after everything else updated (a camera that follows after
			# movement, end-of-frame cleanup). Connected on get_tree() (the "@tree" global source), not self.
			return _signal_backed("_on_post_tick", "", "process_frame", "@tree")
		"OnPhysicsPostTick":
			# The physics-tick sibling: SceneTree.physics_frame, after every _physics_process this step.
			return _signal_backed("_on_physics_post_tick", "", "physics_frame", "@tree")
		"OnLocaleChanged":
			# The translation-changed NOTIFICATION (the engine has no signal for it):
			# compiles to the _notification virtual; applying the trigger auto-adds the
			# "Language Just Changed" gate condition so only that notification runs.
			return _lifecycle("_notification", "what: int")
		"OnProjectFilesChanged":
			# W18. The editor's own file watcher: EditorInterface.get_resource_filesystem() reports
			# every import, move, delete and add through one signal. Connected on that global source
			# ("@editor_files"), not self - a tool script is not the filesystem.
			return _signal_backed("_on_project_files_changed", "", "filesystem_changed", "@editor_files")
		"OnPreferencesChanged":
			# W18. The user changed something in Editor Settings. Same shape as the file watcher, on
			# the editor's settings object ("@editor_preferences").
			return _signal_backed("_on_preferences_changed", "", "settings_changed", "@editor_preferences")
		"OnCloseRequested":
			# The window's close button (X) / an app-quit request - for save-on-quit or a confirm dialog.
			# Connected on the root window (the "@window" global source), not self.
			return _signal_backed("_on_close_requested", "", "close_requested", "@window")
		"OnBodyEntered":
			return _signal_backed("_on%s_body_entered" % source_token, "body: Node", "body_entered", source_path)
		"OnAreaEntered":
			return _signal_backed("_on%s_area_entered" % source_token, "area: Area2D", "area_entered", source_path)
		"OnBodyExited":
			return _signal_backed("_on%s_body_exited" % source_token, "body: Node", "body_exited", source_path)
		"OnAreaExited":
			return _signal_backed("_on%s_area_exited" % source_token, "area: Area2D", "area_exited", source_path)
		"OnTimeout":
			return _signal_backed("_on%s_timeout" % source_token, "", "timeout", source_path)
		"OnAnimationFinished":
			return _signal_backed("_on%s_animation_finished" % source_token, "anim_name: StringName", "animation_finished", source_path)
		"OnButtonPressed":
			return _signal_backed("_on%s_pressed" % source_token, "", "pressed", source_path)
		"OnButtonToggled":
			return _signal_backed("_on%s_toggled" % source_token, "toggled_on: bool", "toggled", source_path)
		"OnParticlesFinished":
			return _signal_backed("_on%s_finished" % source_token, "", "finished", source_path)
		"OnTreeEntered":
			return _signal_backed("_on%s_tree_entered" % source_token, "", "tree_entered", source_path)
		"OnTreeExiting":
			return _signal_backed("_on%s_tree_exiting" % source_token, "", "tree_exiting", source_path)
		"OnTreeExited":
			return _signal_backed("_on%s_tree_exited" % source_token, "", "tree_exited", source_path)
		"OnRenamed":
			return _signal_backed("_on%s_renamed" % source_token, "", "renamed", source_path)
		"OnChildEnteredTree":
			return _signal_backed("_on%s_child_entered_tree" % source_token, "node: Node", "child_entered_tree", source_path)
		"OnChildExitingTree":
			return _signal_backed("_on%s_child_exiting_tree" % source_token, "node: Node", "child_exiting_tree", source_path)
		MENU_TRIGGER_ID:
			# W6. One handler per MENU, connected to the menu variable itself. The item this event
			# answers becomes a case of that handler's `match id:` - see get_trigger_key and the
			# emitter, exactly as the notification triggers work.
			var menu_variable: String = menu_variable_of(event)
			return _signal_backed(menu_handler_name(menu_variable), "id: int", "id_pressed",
				"%s%s" % [MEMBER_SOURCE_PREFIX, menu_variable])
		"OnSignal":
			var signal_name: String = str(event.trigger_params.get("signal_name", "eventforge_signal"))
			return _signal_backed("_on%s_%s" % [source_token, signal_name], str(event.trigger_params.get("args", "")).strip_edges(), signal_name, source_path)
		_:
			# One engine notification. Every such event compiles into the SAME `_notification`
			# handler as a case of its `match what:` - see get_trigger_key and the emitter.
			if event.trigger_id.begins_with(NOTIFICATION_PREFIX):
				return _lifecycle("_notification", "what: int")
			# Custom signal triggers from reflection providers/addons ("signal:<name>").
			if event.trigger_id.begins_with("signal:"):
				var custom_signal: String = event.trigger_id.trim_prefix("signal:")
				return _signal_backed("_on%s_%s" % [source_token, custom_signal], event.trigger_args, custom_signal, source_path)
			return {"function_name": "", "args": "", "signal_name": "", "source_path": ""}

# ── Trigger tempo ───────────────────────────────────────────────────────
# The four TEMPO classes a trigger id falls into - HOW OFTEN the event runs, the #1 comprehension +
# perf fact, surfaced as a coloured badge on the row. Co-located with resolve_trigger ON PURPOSE so the
# two id censuses can never drift; trigger_tempo_exhaustiveness_test asserts every id resolve_trigger
# recognises also has a tempo class.
const TEMPO_EVERY_TICK := "every_tick"  # ⟳ runs every frame - the hot path
const TEMPO_INPUT := "input"            # ⌨ an input event
const TEMPO_ONCE := "once"              # ▶ runs once (setup)
const TEMPO_SIGNAL := "signal"          # ➜ reacts to a signal - the honest default


## Classifies a trigger id into its tempo class. Every-tick = per-frame lifecycle + the post-tick twins;
## input = the input handlers; once = _ready / editor-run; everything else - signal-backed triggers,
## "signal:<name>" custom signals, and any UNKNOWN id - is a signal (the honest default, matching the
## shipped green ➜ badge so unclassified ids never look broken).
static func tempo_class_for(trigger_id: String) -> String:
	match trigger_id:
		"OnProcess", "OnPhysicsProcess", "OnPostTick", "OnPhysicsPostTick":
			return TEMPO_EVERY_TICK
		"OnInput", "OnUnhandledInput", "OnUnhandledKeyInput", "OnInputEvent", "On2DViewportInput", \
				"OnControlInput":
			return TEMPO_INPUT
		"OnDrawOver2DViewport", "OnDrawGizmo":
			# A paint pass runs whenever the editor repaints that surface - the hot path of a tool.
			return TEMPO_EVERY_TICK
		"OnReady", "OnEditorRun", "OnCommandToolRun", "OnProjectExport", "OnFileImported", \
				"OnEnterTree", "OnExitTree", "OnPluginEnabled", "OnPluginDisabled":
			# The tree callbacks run once per lifetime of the object, like _ready does.
			return TEMPO_ONCE
		_:
			return TEMPO_SIGNAL


## `return_type` is the emitted `-> T`. It is "void" for every engine callback that answers nothing,
## which is all of them but the editor's viewport-input hook, so callers that never ask still get the
## header they always got.
static func _lifecycle(function_name: String, args: String, return_type: String = "void") -> Dictionary:
	return {"function_name": function_name, "args": args, "signal_name": "", "source_path": "", "return_type": return_type}


static func _signal_backed(function_name: String, args: String, signal_name: String, source_path: String) -> Dictionary:
	return {"function_name": function_name, "args": args, "signal_name": signal_name, "source_path": source_path}


## "" → "" (self keeps the classic handler names); "Platform" → "_platform";
## "Enemies/Boss" → "_enemies_boss" - a safe identifier fragment for handler names.
static func _identifier_for_source(source_path: String) -> String:
	if source_path.is_empty():
		return ""
	# Autoload sources ("autoload:EventBus") token on the singleton name alone,
	# snake-cased for readable handlers (_on_event_bus_game_paused).
	if source_path.begins_with("autoload:"):
		source_path = source_path.trim_prefix("autoload:").to_snake_case()
	var token: String = ""
	var normalized: bool = false
	for character in source_path.to_lower():
		# Underscores are legitimate identifier chars (snake_cased autoloads like `event_bus`), so
		# they pass through WITHOUT counting as normalization - only genuinely illegal chars do.
		if (character >= "a" and character <= "z") or (character >= "0" and character <= "9") or character == "_":
			token += character
		else:
			token += "_"
			normalized = true
	# A path with illegal chars can collapse onto a clean token ("A/B" and "A_B" both -> "_a_b"),
	# which would emit two same-named handler funcs (a parse error). Disambiguate ONLY the
	# illegal-char path with a short stable suffix of the raw path, so the clean source keeps its
	# readable handler name and distinct sources never collide.
	if normalized:
		token += "_" + str(abs(hash(source_path))).substr(0, 4)
	return "_" + token
