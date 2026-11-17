# Godot EventSheets - the strip under a Juice Player's list (editor-only).
#
# The list itself is drawn by the shared card-list drawer, which builds this strip under its cards (the
# schema's footer): how long the beat is, and the buttons that let a designer feel it without pressing
# Play on the game.
#
# NONE OF IT IS A ROW. A sheet row says WHEN a beat plays; how the beat is tuned is a property of
# the object, and the buttons that try it are Inspector chrome. Nothing here is drawn in a sheet,
# nothing here is emitted, and an exported game neither ships this file nor knows it existed.
#
# HOW PLAYING IN THE EDITOR WORKS. The pack script is not a `@tool` script, so its instance methods
# do not run in the editor at all - but its STATICS do, and the pack publishes what the preview needs:
# the plan of a list (when each card starts and how long it lasts), a sample of what the object would
# be doing at one moment of it, what the editor can show of each kind of card, and what a Sound card
# is made of. That is the same opt-in contract the Tools-menu behaviour preview reads, so a pack ships
# pure functions and both doors show the same picture.
#
# WHAT IT TOUCHES IS WRITTEN DOWN FIRST. Before the first frame the preview records every property it
# may move (the four every play writes and each property a Tween Property card names), and it puts
# them back on Stop, on Restore, at the end of a pass and before the editor saves the scene, so a
# scene's saved bytes are never the middle of a preview.
@tool
# No class_name on purpose: Create Node lists every named Node class, and an editor-only strip has no
# business in that list. It is reached by path, from the card drawer and the toolbar segment.
extends VBoxContainer

## The file that says where the pack whose statics the preview reads lives (the code file, or the old
## name's file in a project holding the old copy). By PATH: naming the class here would compile the pack
## into every editor boot, in projects that hold no feedback player at all.
const NAMES_PATH: String = "res://addons/eventsheet/editor/inspector/juice_player_names.gd"

## What the preview writes down, restores and lights marks with. By path for the same reason.
const PREVIEW_PATH: String = "res://addons/eventsheet/editor/inspector/juice_preview.gd"

## The door to the sheets that play a player, and to opening one. By path, like the rest of the editor-only files.
const ROW_MENU_PATH: String = "res://addons/eventsheet/editor/dock/juice_row_menu.gd"

## What the cards that reach other nodes are drawn by. By path, like the preview helper.
const WORLD_PATH: String = "res://addons/eventsheet/editor/inspector/juice_world_preview.gd"

## The moment file's own class, written when a list is saved out. Also by path, and also for the
## same reason.
const MOMENT_RESOURCE_PATH: String = "res://eventsheet_addons/moment_resource/moment_resource.gd"

## The keys a moment FILE holds. A card using nothing else saves out exactly; a card that uses the
## timing keys is named in the report instead of being written down half.
const FILE_KEYS: PackedStringArray = ["verb", "amount", "effect", "seconds"]

## How often the preview samples.
const FRAME_SECONDS: float = 1.0 / 30.0

## The timeline's own size, and the ground it is drawn on.
const TIMELINE_HEIGHT: int = 74
const TIMELINE_BACKGROUND: Color = Color(0.11, 0.12, 0.15, 1.0)
const TIMELINE_BAR: Color = Color(0.48, 0.62, 0.92, 0.85)
const TIMELINE_HEAD: Color = Color(0.96, 0.72, 0.32, 0.95)

## The most sounds a preview plays at once.
const PREVIEW_VOICES: int = 4

var _player: Node = null
var _head: Label = null
var _timeline: Control = null
var _lines: VBoxContainer = null
var _timer: Timer = null
var _time: float = 0.0
var _base: Dictionary = {}
var _dialog: EditorFileDialog = null
var _saving: bool = true
## The card list this strip sits under, or null.
var _drawer: Control = null
## Which part of the list the preview plays, and where it starts: the whole list, one card, or a card
## and everything under it. Kept so Repeat can play the same part again.
var _mode: String = "all"
var _from: int = 0
## The cards this pass plays and where they sit in the live list.
var _run_list: Array = []
var _run_positions: PackedInt32Array = PackedInt32Array()
## What each card of the live list did in the last pass, by position, for Debug view.
var _did: Dictionary = {}
## Repeat: when a pass ends, read the live list again and play the same part again.
var _repeat: bool = false
var _repeat_box: CheckBox = null
## Set while a pass has ended and Repeat is about to start the next one, so a Stop in between wins.
var _repeat_pending: bool = false
## The strength to try the beat at. Untouched, the preview plays at the player's own strength.
var _try_box: SpinBox = null
## Which plan entries have already started a sound this pass.
var _sounded: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _lit: PackedInt32Array = PackedInt32Array()
## The quiet line that says no sheet plays this player, and the menu that lists the sheets that do.
var _find_note: Label = null
var _find_menu: PopupMenu = null
var _find_button: Button = null
## The quiet line that says Loop is ticked on a list with nothing in it that takes time.
var _loop_note: Label = null
## What the cards that reach other nodes may move, written down before the first frame: each entry is
## [object, property, value]. The same list is what Stop, Restore, the end of a pass and the editor's save
## put back, so a preview of a card on another node can never be the thing the scene saves.
var _world_base: Array = []
## The pass's own memory for those cards (the rest values, a started burst, a material copy).
var _world_state: Dictionary = {}


## The strip for one player. The argument defaults so the class stays constructible with a bare
## new() - a Control with a class_name is offered by the editor's own node dialog. `drawer` is the card
## list this strip sits under, when there is one (the toolbar's own strip has none).
func _init(player: Node = null, drawer: Control = null) -> void:
	_player = player
	_drawer = drawer
	add_theme_constant_override("separation", 4)
	_head = Label.new()
	# Through the palette, not a literal: a literal font size ignores the editor's own display
	# scale, so the head reads at half height on a HiDPI screen while everything around it grows.
	_head.add_theme_font_size_override("font_size", EventSheetPalette.scaled(11))
	# One pass is the time the list takes to reach its end: the cards between two Pauses or Holds start
	# together, so their times do not add up, and what a Loop Back or the node's Loop repeats comes on top.
	_head.mouse_filter = Control.MOUSE_FILTER_PASS
	_head.tooltip_text = EventSheetL10n.translate("How long one pass of the list takes. Cards between two Pauses or Holds start together, so their times do not add up. What a Loop Back or the Loop tick repeats comes on top.")
	add_child(_head)
	add_child(_build_buttons())
	_find_note = Label.new()
	_find_note.hide()
	_find_note.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
	_find_note.add_theme_color_override("font_color", EventSheetLookStyle.warning())
	_find_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_find_note)
	_loop_note = Label.new()
	_loop_note.hide()
	_loop_note.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
	_loop_note.add_theme_color_override("font_color", EventSheetLookStyle.warning())
	_loop_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_loop_note)
	add_child(_build_try_rows())
	_timeline = _build_timeline()
	add_child(_timeline)
	_lines = VBoxContainer.new()
	_lines.hide()
	add_child(_lines)
	refresh()
	if _player != null:
		load(PREVIEW_PATH).call("register", _player, self)
	if Engine.is_editor_hint() and EditorInterface.get_inspector() != null:
		EditorInterface.get_inspector().property_edited.connect(_on_property_edited)


## A tick or a number edited in the Inspector: the Loop line may have to appear or go.
func _on_property_edited(_property: String) -> void:
	if _player != null and is_instance_valid(_player):
		refresh()


func _exit_tree() -> void:
	if _player != null and is_instance_valid(_player):
		stop()
		load(PREVIEW_PATH).call("unregister", _player, self)


## The head line and the timeline, re-read from the player as it is edited.
func refresh() -> void:
	var list: Array = steps_of(_player)
	_head.text = head_text(list.size(), seconds_text(duration_of(list)))
	_loop_note.text = loop_note_text(bool(_player.get("loop")) if _player != null else false, duration_of(list))
	_loop_note.visible = not _loop_note.text.is_empty()
	if _timeline != null:
		_timeline.queue_redraw()
	if _lines != null and _lines.visible:
		_show_lines()


## The line under the head when Loop is ticked and the list takes no time: the player waits a frame between
## passes, so the loop runs once a frame rather than locking the game. Empty otherwise. PURE + STATIC.
static func loop_note_text(looping: bool, total_seconds: float) -> String:
	if looping and total_seconds <= 0.0:
		return EventSheetL10n.translate("Loop is on and nothing in this list takes time, so the player plays it again every frame. Add a Pause or a card with a length.")
	return ""


## The head line over the list: how many juice cards it holds and how long one pass of the beat lasts. One
## card reads "1 juice card", every other count "N juice cards". PURE + STATIC.
static func head_text(count: int, total: String) -> String:
	if count == 1:
		return EventSheetL10n.translate("%d juice card - %s once through") % [count, total]
	return EventSheetL10n.translate("%d juice cards - %s once through") % [count, total]


## The steps a player is holding: the moment file's when one is on the slot, else its own list. The
## same order of preference the running node uses, so the head never counts a list the game ignores.
static func steps_of(player: Object) -> Array:
	if player == null:
		return []
	var file: Variant = player.get("moment_file")
	if file is Resource and (file as Resource).get("steps") is Array:
		return (file as Resource).get("steps")
	var list: Variant = player.get("steps")
	return list if list is Array else []


## The longest path through a list, asked of the pack itself so the strip and the running game can
## never disagree about how long a beat is. 0 when the pack is not in the project.
static func duration_of(list: Array) -> float:
	var pack: Script = load(load(NAMES_PATH).pack_path()) as Script
	if pack == null:
		return 0.0
	return float(pack.call("duration_of", list))


## A number of seconds as the strip writes it.
static func seconds_text(seconds: float) -> String:
	return "%.2f s" % maxf(seconds, 0.0)


## The list as the steps a moment file can hold, plus the cards it cannot: {steps, left_behind}. A
## card that uses a key a file cannot hold is left behind by NAME rather than written down without it,
## because a file that plays everything at once, or a sound it cannot play, is not the beat the list was.
static func file_steps_of(list: Array) -> Dictionary:
	var carried: Array = []
	var left_behind: PackedStringArray = PackedStringArray()
	for entry: Variant in list:
		if not (entry is Dictionary):
			continue
		var card: Dictionary = entry as Dictionary
		var extra: bool = false
		for key: Variant in card:
			if not FILE_KEYS.has(str(key)) and str(key) != "label" and str(key) != "category" and str(key) != "active":
				extra = true
		if extra:
			left_behind.append(str(card.get("label", card.get("verb", "a card"))))
			continue
		var kept: Dictionary = {}
		for key: String in FILE_KEYS:
			kept[key] = card.get(key, "" if key == "verb" or key == "effect" else 0.0)
		carried.append(kept)
	return {"steps": carried, "left_behind": left_behind}


## The row of doors: the four that play, the one that draws, and the two that move the list between
## this node and a file.
func _build_buttons() -> Control:
	# Godot's own wrapping row: the doors drop to a second line when the Inspector is narrow, instead of
	# their combined width holding the whole Inspector open.
	var row: HFlowContainer = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 3)
	row.add_theme_constant_override("v_separation", 3)
	for entry: Array in [["Play", play], ["Stop", stop], ["Skip", skip],
			["Restore", restore], ["Debug view", _on_debug], ["Save as file", _on_save],
			["Load from file", _on_load], ["Find what plays this", _on_find_plays]]:
		var button: Button = Button.new()
		button.text = EventSheetL10n.translate(str(entry[0]))
		button.pressed.connect(entry[1] as Callable)
		if entry[1] == _on_find_plays:
			_find_button = button
		row.add_child(button)
	return row


## Repeat and Try at strength: two lines that belong to the strip alone. They are view state, never
## an export and never saved, so a scene's bytes are not touched by tuning with them.
func _build_try_rows() -> Control:
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	var repeat_row: HBoxContainer = HBoxContainer.new()
	var repeat_label: Label = Label.new()
	repeat_label.text = EventSheetL10n.translate("Preview")
	repeat_label.custom_minimum_size = Vector2(EventSheetPalette.scaled(108), 0.0)
	repeat_row.add_child(repeat_label)
	_repeat_box = CheckBox.new()
	_repeat_box.text = EventSheetL10n.translate("Repeat the preview")
	_repeat_box.tooltip_text = EventSheetL10n.translate("Keeps playing the preview in the editor while you tune. Each pass reads the list as it is then, so a number you change is the number the next pass uses. The game's own loop is the Loop tick on the node.")
	_repeat_box.toggled.connect(func(pressed: bool) -> void: _repeat = pressed)
	repeat_row.add_child(_repeat_box)
	rows.add_child(repeat_row)
	var strength_row: HBoxContainer = HBoxContainer.new()
	var strength_label: Label = Label.new()
	strength_label.text = EventSheetL10n.translate("Try at strength")
	strength_label.custom_minimum_size = Vector2(EventSheetPalette.scaled(108), 0.0)
	strength_row.add_child(strength_label)
	_try_box = SpinBox.new()
	_try_box.min_value = 0.0
	_try_box.max_value = 4.0
	_try_box.step = 0.05
	_try_box.value = 1.0
	_try_box.tooltip_text = EventSheetL10n.translate("What the preview scales every amount by. The same number the toolbar's \"at\" box sets.")
	strength_row.add_child(_try_box)
	rows.add_child(strength_row)
	return rows


## The strength the preview plays at: the one tried here (or set from the toolbar) times the player's own,
## the way the running node scales a play by the row's strength and then by its own.
func _strength() -> float:
	var tried: float = float(_try_box.value) if _try_box != null else 1.0
	var own: Variant = _player.get("strength") if _player != null else 1.0
	return maxf(tried, 0.0) * maxf(float(own) if own != null else 1.0, 0.0)


## Sets the strength to try at, from the toolbar's box. One number, so the two places cannot disagree.
func set_try_strength(value: float) -> void:
	if _try_box != null:
		_try_box.set_value_no_signal(value)


## The timeline: a bar per card at the time it starts, holds as the gaps between them, and the head
## where the preview has got to. Editor-only, hidden until Debug view is pressed, and it emits
## nothing - it is the answer to "why did the flash come late", drawn rather than guessed at.
func _build_timeline() -> Control:
	var drawing: Control = Control.new()
	drawing.custom_minimum_size = Vector2(0, TIMELINE_HEIGHT)
	drawing.hide()
	drawing.draw.connect(_draw_timeline.bind(drawing))
	return drawing


func _draw_timeline(canvas: Control) -> void:
	var pack: Script = load(load(NAMES_PATH).pack_path()) as Script
	if pack == null:
		return
	var list: Array = steps_of(_player)
	var plan: Array = pack.call("schedule_of", list)
	var span: float = maxf(duration_of(list), 0.001)
	var size: Vector2 = canvas.size
	canvas.draw_rect(Rect2(Vector2.ZERO, size), TIMELINE_BACKGROUND)
	var font: Font = get_theme_default_font()
	var rows: int = maxi(plan.size(), 1)
	var row_height: float = minf(size.y / float(rows), 16.0)
	for index: int in range(plan.size()):
		var entry: Dictionary = plan[index] as Dictionary
		var card: Dictionary = entry.get("card") as Dictionary
		var left: float = size.x * float(entry.get("at", 0.0)) / span
		var width: float = maxf(size.x * maxf(float(entry.get("seconds", 0.0)), 0.0) / span, 3.0)
		var top: float = float(index) * row_height
		canvas.draw_rect(Rect2(left, top + 1.0, width, row_height - 2.0), TIMELINE_BAR)
		if font != null:
			canvas.draw_string(font, Vector2(left + 4.0, top + row_height - 4.0),
				str(card.get("label", card.get("verb", ""))), HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
	if _timer != null and not _timer.is_stopped():
		var head: float = size.x * clampf(_time / span, 0.0, 1.0)
		canvas.draw_line(Vector2(head, 0.0), Vector2(head, size.y), TIMELINE_HEAD, 2.0)


## Debug view: the timeline, and under it one line per card saying what the editor does with it (or what
## it did in the last pass): played for real, shown as time, or skipped and why.
func _on_debug() -> void:
	if _timeline != null:
		_timeline.visible = not _timeline.visible
		_timeline.queue_redraw()
	if _lines != null:
		_lines.visible = _timeline.visible
		if _lines.visible:
			_show_lines()


## One line per card, in list order, in the words the guide uses.
func _show_lines() -> void:
	for stale: Node in _lines.get_children():
		_lines.remove_child(stale)
		stale.queue_free()
	var pack: Script = load(load(NAMES_PATH).pack_path()) as Script
	var list: Array = steps_of(_player)
	for position: int in range(list.size()):
		if not (list[position] is Dictionary):
			continue
		var card: Dictionary = list[position] as Dictionary
		var title: String = str(card.get("label", card.get("verb", "")))
		var said: String = str(_did.get(position, "")) if _did.has(position) else what_editor_does(card, pack)
		var line: Label = Label.new()
		line.text = "%s - %s" % [title, said]
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
		line.add_theme_color_override("font_color", EventSheetLookStyle.quiet())
		_lines.add_child(line)


## What the editor does with one card, in words: played for real, shown as time, skipped and why, or
## switched off. Asks the pack, so the strip, Debug view and the guide say one thing.
static func what_editor_does(card: Dictionary, pack: Script) -> String:
	if not bool(card.get("active", true)):
		return EventSheetL10n.translate("switched off")
	if card.has("card_script"):
		var own_script: Script = pack.call("own_script_of", card) as Script if pack != null else null
		if own_script != null and own_script.is_tool():
			return EventSheetL10n.translate("played")
		return EventSheetL10n.translate("not shown in the editor: %s") % EventSheetL10n.translate("a card of yours plays here only when its script is marked @tool")
	var kind: String = str(pack.call("editor_kind", str(card.get("verb", "")))) if pack != null else "skipped:"
	if kind == "felt":
		return EventSheetL10n.translate("played")
	if kind == "time":
		return EventSheetL10n.translate("shown as time")
	return EventSheetL10n.translate("not shown in the editor: %s") % kind.trim_prefix("skipped:")


## Start sampling the whole list. The host's rest state is written down first, so Stop and Restore have
## something exact to put back rather than a guess at what the numbers were.
##
## PUBLIC, because these four doors have TWO homes: the buttons under the list here, and the
## toolbar's Moment segment while a row about this player is selected. One preview, driven from
## either place, so the two can never show different pictures of the same beat.
func play() -> void:
	play_part("all", 0)


## Play one card, a card and everything under it, or the whole list ("one", "from_here", "all").
func play_part(mode: String, index: int) -> void:
	restore()
	_mode = mode
	_from = index
	_begin_pass()


## Starts one pass: the part of the LIVE list asked for, the properties it may move written down.
func _begin_pass() -> void:
	var target: Node = _host()
	if target == null:
		return
	var preview: Script = load(PREVIEW_PATH) as Script
	var list: Array = steps_of(_player)
	_run_positions = preview.call("sub_indices", list, _from, _mode)
	_run_list = []
	for taken: Variant in preview.call("sub_list", list, _from, _mode):
		var card: Dictionary = taken as Dictionary
		if _mode == "one":
			# A card played on its own is played whether or not its box is ticked: pressing its mark is the ask.
			card = card.duplicate()
			card.erase("active")
		_run_list.append(card)
	_base = {}
	for property: String in preview.call("watched_properties", _run_list):
		var value: Variant = target.get(property)
		if value != null:
			_base[property] = value
	_record_world(target)
	_time = 0.0
	_sounded.clear()
	_did = _describe_pass(list)
	if _timer == null:
		_timer = Timer.new()
		_timer.wait_time = FRAME_SECONDS
		_timer.timeout.connect(_tick)
		add_child(_timer)
	_timer.start()
	_show_marks(PackedInt32Array())


func stop() -> void:
	if _timer != null:
		_timer.stop()
	_repeat_pending = false
	restore()
	_show_marks(PackedInt32Array())
	if _timeline != null:
		_timeline.queue_redraw()


## Jump to the end of the plan - the same door the running node's Skip To End is, in the one form an
## editor can honestly offer: the last frame of the beat, drawn.
func skip() -> void:
	_time = duration_of(_run_list if not _run_list.is_empty() else steps_of(_player))
	_tick()


func restore() -> void:
	var target: Node = _host()
	_restore_world()
	if target != null:
		for property: Variant in _base:
			target.set(str(property), _base[property])
	_base = {}
	for voice: AudioStreamPlayer in _voices:
		if is_instance_valid(voice):
			voice.stop()


func _tick() -> void:
	var target: Node = _host()
	var pack: Script = load(load(NAMES_PATH).pack_path()) as Script
	if target == null or pack == null:
		stop()
		return
	var params: Dictionary = {"steps": _run_list, "strength": _strength()}
	var written: Variant = pack.call("editor_preview_sample", params, _base, _time)
	if written is Dictionary:
		for property: Variant in written as Dictionary:
			target.set(str(property), (written as Dictionary)[property])
	_step_world(pack, target)
	_play_sounds_due(pack)
	_show_marks(load(PREVIEW_PATH).call("playing_at", _run_list, _run_positions, _time))
	_time += FRAME_SECONDS
	if _timeline != null:
		_timeline.queue_redraw()
	if _time > duration_of(_run_list) + FRAME_SECONDS:
		_end_pass()


## Writes down every property the cards that reach other nodes may move, and the value each holds now.
func _record_world(host: Node) -> void:
	_world_base = []
	_world_state = {"player": _player}
	var world: Script = load(WORLD_PATH) as Script
	var seen: Dictionary = {}
	for entry: Variant in _run_list:
		var card: Dictionary = entry as Dictionary
		if not bool(world.call("handles", card)):
			continue
		var node: Node = world.call("node_of", _player, card, host) as Node
		for pair: Variant in world.call("watched", card, node) as Array:
			var object: Object = (pair as Array)[0] as Object
			var property: String = str((pair as Array)[1])
			var key: String = "%d|%s" % [object.get_instance_id(), property]
			if seen.has(key):
				continue
			seen[key] = true
			_world_base.append([object, property, world.call("remember", _world_state, object, property)])


## One frame of every card that reaches another node: each is `through` of the way into its own length.
func _step_world(pack: Script, host: Node) -> void:
	var world: Script = load(WORLD_PATH) as Script
	var plan: Array = pack.call("schedule_of", _run_list)
	for plan_index: int in range(plan.size()):
		var entry: Dictionary = plan[plan_index] as Dictionary
		var card: Dictionary = entry.get("card") as Dictionary
		if not bool(world.call("handles", card)):
			continue
		# A card that repeats is seen repeating; between its plays, and after the last, it rests at its end.
		var through: float = float(pack.call("through_at", entry, _time))
		if through < 0.0:
			if _time < float(entry.get("at", 0.0)):
				continue
			through = 1.0
		world.call("step", card, world.call("node_of", _player, card, host), through, _strength(), _world_state, plan_index)


## Puts back everything the cards that reach other nodes moved, in the opposite order it was written down.
func _restore_world() -> void:
	if _world_base.is_empty() and _world_state.is_empty():
		return
	load(WORLD_PATH).call("finish", _world_state)
	for index: int in range(_world_base.size() - 1, -1, -1):
		var held: Array = _world_base[index] as Array
		var object: Object = held[0] as Object
		if object == null or not is_instance_valid(object):
			continue
		if str(held[1]) == "assigned_animation" and str(held[2]).is_empty():
			continue
		object.set_indexed(NodePath(str(held[1])), held[2])
	_world_base = []


## The end of a pass: everything put back, and then either the end or, with Repeat ticked, the next pass
## read from the list as it is now.
func _end_pass() -> void:
	if _timer != null:
		_timer.stop()
	restore()
	_show_marks(PackedInt32Array())
	if _lines != null and _lines.visible:
		_show_lines()
	if _timeline != null:
		_timeline.queue_redraw()
	if _repeat and is_inside_tree():
		_repeat_pending = true
		get_tree().create_timer(FRAME_SECONDS * 4.0).timeout.connect(_repeat_now)


## Plays the next pass of a Repeat, unless Stop (or a new Play) has come in the meantime.
func _repeat_now() -> void:
	if _repeat_pending and is_instance_valid(self) and _repeat:
		_repeat_pending = false
		_begin_pass()


## Starts the sound of each Sound card whose plan entry has just been reached. A voice is one of a few kept
## under the strip, so nothing is added to the scene and a long list does not make a node per sound.
func _play_sounds_due(pack: Script) -> void:
	var plan: Array = pack.call("schedule_of", _run_list)
	for plan_index: int in range(plan.size()):
		var entry: Dictionary = plan[plan_index] as Dictionary
		var card: Dictionary = entry.get("card") as Dictionary
		if str(card.get("verb", "")) != "sound":
			continue
		# One sound for each play of the card: the first at its start, and one for every repeat after it.
		var due: int = -1
		for pass_index: int in range(maxi(int(entry.get("repeat", 1)), 1)):
			if _time >= float(entry.get("at", 0.0)) + float(pass_index) * float(entry.get("every", 0.0)) and not _sounded.has(plan_index * 1000 + pass_index):
				due = pass_index
				break
		if due < 0:
			continue
		_sounded[plan_index * 1000 + due] = true
		var settings: Dictionary = pack.call("sound_settings", card, _strength(), randf(), randf())
		var path: String = str(settings.get("stream", ""))
		var stream: AudioStream = load(path) as AudioStream if not path.is_empty() and ResourceLoader.exists(path) else null
		if stream == null:
			continue
		var voice: AudioStreamPlayer = _free_voice()
		var bus: String = str(settings.get("bus", "Master"))
		voice.bus = bus if AudioServer.get_bus_index(bus) >= 0 else "Master"
		voice.stream = stream
		voice.volume_db = float(settings.get("volume_db", 0.0))
		voice.pitch_scale = float(settings.get("pitch_scale", 1.0))
		voice.play()


func _free_voice() -> AudioStreamPlayer:
	for voice: AudioStreamPlayer in _voices:
		if is_instance_valid(voice) and not voice.playing:
			return voice
	if _voices.size() < PREVIEW_VOICES:
		var fresh: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(fresh)
		_voices.append(fresh)
		return fresh
	return _voices[0]


## What each card of the live list did in the pass that has just started, by position: the cards this
## pass does not play say so.
func _describe_pass(list: Array) -> Dictionary:
	var pack: Script = load(load(NAMES_PATH).pack_path()) as Script
	var did: Dictionary = {}
	for position: int in range(list.size()):
		if not (list[position] is Dictionary):
			continue
		if _run_positions.has(position):
			var card: Dictionary = list[position] as Dictionary
			if _mode == "one":
				card = card.duplicate()
				card.erase("active")
			did[position] = what_editor_does(card, pack)
		else:
			did[position] = EventSheetL10n.translate("not in this pass")
	return did


## Tells the card list which cards to light a play mark on.
func _show_marks(lit: PackedInt32Array) -> void:
	if lit == _lit:
		return
	_lit = lit
	if _drawer != null and is_instance_valid(_drawer) and _drawer.has_method("set_marks"):
		_drawer.call("set_marks", lit)


## The object this player is under - the one a beat is felt on.
func _host() -> Node:
	if _player == null or not _player.is_inside_tree():
		return null
	return _player.get_parent()


## "Find what plays this": the sheets of the project that play this player, as a menu that opens the one picked,
## or one quiet line saying none does. The list is read when the button is pressed, never kept.
func _on_find_plays() -> void:
	if _player == null:
		return
	var sheets: PackedStringArray = load(ROW_MENU_PATH).call("sheets_playing", str(_player.name))
	_find_note.visible = sheets.is_empty()
	if sheets.is_empty():
		_find_note.text = EventSheetL10n.translate("No sheet in this project plays %s.") % str(_player.name)
		return
	if _find_menu == null:
		_find_menu = PopupMenu.new()
		_find_menu.id_pressed.connect(func(id: int) -> void:
			load(ROW_MENU_PATH).call("open_sheet", _find_menu.get_item_metadata(_find_menu.get_item_index(id))))
		add_child(_find_menu)
	_find_menu.clear()
	for index: int in range(sheets.size()):
		_find_menu.add_item(sheets[index].trim_prefix("res://"), index)
		_find_menu.set_item_metadata(index, sheets[index])
	EventSheetWindowPlacement.popup_below(_find_menu, Rect2i(Vector2i(_find_button.get_screen_position()), Vector2i(_find_button.size)))


func _on_save() -> void:
	_saving = true
	_open_dialog(EditorFileDialog.FILE_MODE_SAVE_FILE)


func _on_load() -> void:
	_saving = false
	_open_dialog(EditorFileDialog.FILE_MODE_OPEN_FILE)


func _open_dialog(mode: int) -> void:
	if _dialog == null:
		_dialog = EditorFileDialog.new()
		_dialog.access = EditorFileDialog.ACCESS_RESOURCES
		_dialog.add_filter("*.tres", "Moment file")
		_dialog.file_selected.connect(_on_file_chosen)
		add_child(_dialog)
	_dialog.file_mode = mode as EditorFileDialog.FileMode
	EventSheetWindowPlacement.popup_centered_ratio(_dialog, 0.6)


## Writing a list out, and reading one back in. Both are ordinary resource operations on a file the
## designer named: nothing is written anywhere they did not point at, and a load never deletes the
## list it replaces - it fills the moment-file slot, which the list is only hidden behind.
func _on_file_chosen(path: String) -> void:
	if _player == null:
		return
	if _saving:
		var script: Script = load(MOMENT_RESOURCE_PATH) as Script
		if script == null:
			return
		var carried: Dictionary = file_steps_of(steps_of(_player))
		var file: Resource = script.new()
		file.set("moment_name", path.get_file().get_basename())
		file.set("steps", carried.get("steps"))
		if ResourceSaver.save(file, path) != OK:
			push_warning("Juice Player: %s could not be written." % path)
			return
		if not (carried.get("left_behind") as PackedStringArray).is_empty():
			push_warning("Juice Player: %s holds the cards a file can hold. These use timing a file cannot carry and were left in the list: %s." % [
				path.get_file(), ", ".join(carried.get("left_behind") as PackedStringArray)])
		return
	var loaded: Resource = load(path)
	if loaded == null or not (loaded.get("steps") is Array):
		push_warning("Juice Player: %s is not a moment file." % path.get_file())
		return
	_player.set("moment_file", loaded)
	refresh()
