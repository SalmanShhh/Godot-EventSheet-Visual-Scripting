# Pack source - prompts. The behaviour code this pack ships, as real GDScript: highlighted,
# checked and breakpointable here, and assembled into the pack by Lib.pack_from_source.
# Every #region, and the body of every top-level func, is one piece of the sheet; everything
# else is scaffolding the pack declares for itself at build time and never reads from here.
extends Node

# The Inspector variables. They are declared on the builder's manifest (which is what emits them,
# with their tooltips and ranges); these lines exist so this file parses and type-checks on its own.
var prompt_scene: String = "res://eventsheet_addons/prompts/prompt.tscn"
var glyphs: Resource = null
var perfect_window_ms: int = 80
var hit_window_ms: int = 250
var perfect_share: float = 0.5
var lead_seconds: float = 1.0
var flash_strength: float = 1.0
var flash_seconds: float = 0.15
var debug_mode: bool = false

#region block_1
## Fires when the player answers a prompt in time, carrying the control it was asking for and how
## well it was answered - "perfect" or "good", the same two words the Timed Input module's Window
## Grade and Beat Grade already speak, so one hit reaction serves a window, a beat and a prompt.
## @ace_trigger
## @ace_name("On Prompt Hit")
signal prompt_hit(action: String, grade: String)

## Fires when a prompt runs out with nothing pressed, or when a note goes past its beat unanswered,
## carrying the control that was missed. The punish, the failed grab, the dropped note.
## @ace_trigger
## @ace_name("On Prompt Missed")
signal prompt_missed(action: String)

## Fires once a sequence ends, carrying whether it was completed: true when every prompt in it was
## answered, false on the first miss or a cancel. One trigger for both endings, because a cutscene
## branches on the same question either way.
## @ace_trigger
## @ace_name("On Sequence Finished")
signal sequence_finished(completed: bool)

## The three words a grade can be. They are the Timed Input module's own two plus the miss, so a
## sheet that already branches on "perfect" needs nothing rewritten to branch on a prompt.
const GRADE_PERFECT: String = "perfect"
const GRADE_GOOD: String = "good"
const GRADE_MISS: String = "miss"

## What kind of answer the open prompt is waiting for. A press, a hold, or a count of presses -
## three shapes with one deadline, one grade and one pair of triggers between them.
const KIND_PRESS: String = "press"
const KIND_HOLD: String = "hold"
const KIND_MASH: String = "mash"

## The five devices a glyph sheet draws for: the keyboard, a pad whose product name matches none of
## the layouts, and the three layouts told apart by that name.
const DEVICE_KEYBOARD: String = "keyboard"
const DEVICE_PAD: String = "pad"
const DEVICE_XBOX: String = "xbox"
const DEVICE_PLAYSTATION: String = "playstation"
const DEVICE_NINTENDO: String = "nintendo"

## The product-name fragments each layout answers to, lower-cased. A pad naming none of them is the
## generic pad, which is the honest answer rather than a guess.
const LAYOUT_WORDS: Dictionary = {
	DEVICE_XBOX: ["xbox", "xinput"],
	DEVICE_PLAYSTATION: ["playstation", "dualshock", "dualsense", "ps3", "ps4", "ps5"],
	DEVICE_NINTENDO: ["nintendo", "switch", "joy-con", "joycon"]
}

## How far a flash may go, and the least time it may take, for a player who has asked for no
## flashing. The same two numbers every effect in this project clamps to: the flash becomes a slow
## fade rather than being taken away, because the prompt still has to say it was hit.
const FLASH_CEILING: float = 0.3
const FLASH_FLOOR_SECONDS: float = 0.4

## The name the prompt layer takes under this node, so a reader who opens the remote tree during a
## run can see where the prompts are being drawn.
const LAYER_NAME: String = "PromptLayer"

## The font size the prompt's own label is drawn at before the player's text-size dial multiplies
## it. The starter scene sets no size of its own, so this is the one place it is decided.
const PROMPT_FONT_SIZE: int = 20

## Whether a prompt is waiting for an answer right now, and what it is waiting for. One at a time on
## purpose: two prompts on screen asking for two controls is a sequence, and Sequence is the row.
var _open: bool = false
var _kind: String = KIND_PRESS
var _action: String = ""

## The moment the prompt opened and the moment it closes, both on the engine clock - the same clock
## the Timed Input rows measure a press with, so a grade from either reads the same.
var _opened_at: float = 0.0
var _deadline: float = 0.0

## A hold: how long the control has to be held down, and how long it has been held so far. Letting
## go resets the count, because a hold that survived being let go is not a hold.
var _hold_needed: float = 0.0
var _held_for: float = 0.0

## A mash: how many presses it takes, and how many have arrived.
var _mash_needed: int = 0
var _mash_count: int = 0

## The last grade a prompt ended on, which is what Grade Is asks about and Last Grade answers with.
## Empty until the first prompt ends.
var _last_grade: String = ""

## A sequence: the controls still to come, how many there were, how many have been answered, how
## long each one gets, and where they are drawn. Total is kept rather than derived so Sequence
## Progress still reads 1 after the last one is taken off the queue.
var _queue: PackedStringArray = PackedStringArray()
var _queue_total: int = 0
var _queue_done: int = 0
var _queue_seconds: float = 0.0
var _queue_at: Node = null
var _in_sequence: bool = false

## Which device the glyphs are drawn for: the one the last input event came from, unless a row has
## forced one for a menu that has to show a particular layout.
var _device: String = DEVICE_KEYBOARD
var _forced_device: String = ""

## The notes travelling down their lanes, each a small record rather than a node, because what a
## note IS is a control, a moment and a place - the node is only how it is drawn.
##
##   action  the control the player has to press
##   at      the moment it must be pressed on, on the engine clock
##   from    the moment it was spawned, so how far along the lane it is can be worked out
##   lane    the lane it travels down, or null
##   node    the thing being drawn, or null when nothing is being drawn
var _notes: Array[Dictionary] = []

## The prompt being drawn now, the layer it is drawn on, and the node it is drawn at.
var _node: Node = null
var _layer: CanvasLayer = null
var _at: Node = null
#endregion

#region block_2
## The engine clock, in seconds, written the way the Timed Input module writes it. It keeps counting
## while the game is paused, which is why a prompt opened before a pause runs out during one - the
## same caveat the window rows carry, and the reason both can be graded against the same moment.
## @ace_hidden
func now() -> float:
	return Time.get_ticks_msec() / 1000.0

## A window in milliseconds as the seconds everything here measures in. Prompts are tuned in
## milliseconds because that is the unit a timing window is discussed in; the arithmetic is not.
## @ace_hidden
func window_seconds(milliseconds: int) -> float:
	return maxf(float(milliseconds), 0.0) / 1000.0

## How a prompt that was answered in time is graded: by how much of its window was still LEFT. An
## answer that came straight away kept nearly all of it and is perfect; one that came at the last
## moment kept none and is good. A window of no length at all grades good rather than dividing by
## nothing.
## @ace_hidden
func timed_grade(at_moment: float, opened_at: float, deadline: float, share: float) -> String:
	var span: float = deadline - opened_at
	if span <= 0.0:
		return GRADE_GOOD
	if deadline - at_moment >= span * clampf(share, 0.0, 1.0):
		return GRADE_PERFECT
	return GRADE_GOOD

## How a note is graded: by how far the press was from the moment it was asked for, either side of
## it. Inside the perfect window it is perfect, inside the hit window it is good, and beyond that it
## is not an answer to this note at all.
## @ace_hidden
func beat_grade(pressed_at: float, beat_at: float, perfect: float, hit: float) -> String:
	var off: float = absf(pressed_at - beat_at)
	if off <= perfect:
		return GRADE_PERFECT
	if off <= hit:
		return GRADE_GOOD
	return GRADE_MISS

## The moment a note must be hit on. A Music director in the project answers with the song's next
## beat, and that moment is already on the engine clock this pack grades against, so a rhythm lane
## needs no arithmetic anywhere. With no director - or before the first track starts - the note
## lands a lead's worth of time from now, which is what makes the pack work on its own.
## @ace_hidden
func beat_moment(at_moment: float, from_music: float, lead: float) -> float:
	if from_music > at_moment:
		return from_music
	return at_moment + maxf(lead, 0.01)

## How far along its lane a note has travelled, from 0 where it was spawned to 1 on its moment. It
## goes on past 1 nowhere: a note that is late is drawn on the line until it expires.
## @ace_hidden
func note_progress(at_moment: float, from: float, at: float) -> float:
	if at <= from:
		return 1.0
	return clampf((at_moment - from) / (at - from), 0.0, 1.0)

## Whether a note is past answering: its moment has gone by further than the hit window reaches, so
## nothing the player does now could have been an answer to it.
## @ace_hidden
func note_expired(at_moment: float, at: float, hit: float) -> bool:
	return at_moment - at > hit

## Which of the notes a press belongs to: the one for that control whose moment is nearest, so two
## notes for the same control in quick succession are answered in the order they arrive rather than
## in the order they were spawned. -1 when no note is waiting for that control.
## @ace_hidden
func nearest_note(action: String, at_moment: float) -> int:
	var best: int = -1
	var closest: float = 0.0
	for index: int in range(_notes.size()):
		if str(_notes[index]["action"]) != action:
			continue
		var off: float = absf(float(_notes[index]["at"]) - at_moment)
		if best < 0 or off < closest:
			best = index
			closest = off
	return best

## How big a flash may be and how long it may take, once the player's no-flashing answer has had its
## say. Asked for as a strength and a duration, given back as the pair actually allowed: clamped
## small and stretched slow when flashing is off, so the prompt still says it was hit without
## strobing anybody.
## @ace_hidden
func flash_for(strength: float, seconds: float, quiet: bool) -> Vector2:
	if quiet:
		return Vector2(clampf(strength, 0.0, FLASH_CEILING), maxf(seconds, FLASH_FLOOR_SECONDS))
	return Vector2(maxf(strength, 0.0), maxf(seconds, 0.01))

## Which of the five devices a joypad's product name reads as. Godot hands out the pad's own string
## and every layout writes its family into it, so the match is a word search rather than a table of
## every controller ever made. A name matching none of them is the generic pad.
## @ace_hidden
func device_for_name(product_name: String) -> String:
	var word: String = product_name.to_lower()
	for layout: String in LAYOUT_WORDS:
		for fragment: String in LAYOUT_WORDS[layout]:
			if word.contains(fragment):
				return layout
	return DEVICE_PAD

## The picture a sheet holds for a control on a device, with the two fallbacks that make a
## half-drawn sheet usable: the layout in hand, then the generic pad, then the keyboard. Read by
## FIELD NAME rather than by class, so a project that installed this director without the glyph
## resource beside it still parses, and a sheet somebody wrote themselves works as long as it spells
## the same five names.
## @ace_hidden
func glyph_in(sheet: Resource, on_device: String, action: String) -> Texture2D:
	if sheet == null or action.is_empty():
		return null
	for key: String in [on_device, DEVICE_PAD, DEVICE_KEYBOARD]:
		var table: Variant = sheet.get(key)
		if table is Dictionary and table.has(action):
			var found: Variant = table[action]
			if found is Texture2D:
				return found
	return null

## The Input Map's own words for a control ("Space", "A button") - the same answer the shipped
## Prompt For Control row gives, used when no glyph was drawn for this one. A control the project
## does not have reads back as its own name, which is what somebody looking at a typo needs to see.
## @ace_hidden
func control_text(action: String) -> String:
	if action.is_empty() or not InputMap.has_action(action):
		return action
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	if events.is_empty():
		return action
	return events[0].as_text()

## One frame of the open prompt: the press, the hold and the mash, then the deadline. Given the
## moment and what the controls did rather than reading them itself, which is what lets a whole
## prompt be driven and pinned with no input device and no scene tree.
## @ace_hidden
func step(at_moment: float, delta: float, just_pressed: bool, held: bool) -> void:
	if not _open:
		return
	if _kind == KIND_MASH:
		if just_pressed:
			_mash_count += 1
		if _mash_count >= _mash_needed:
			_land(at_moment)
			return
	elif _kind == KIND_HOLD:
		_held_for = _held_for + delta if held else 0.0
		if _held_for >= _hold_needed:
			_land(at_moment)
			return
	elif just_pressed:
		_land(at_moment)
		return
	if at_moment >= _deadline:
		_miss(at_moment)

## One frame of the notes: a press is graded against the nearest note for that control, and a note
## whose moment has gone past answering is a miss. A press that is nowhere near any note is left
## alone rather than punished, because on a rhythm lane the player is allowed to be early.
## @ace_hidden
func step_notes(at_moment: float, pressed_action: String) -> void:
	if not pressed_action.is_empty():
		var index: int = nearest_note(pressed_action, at_moment)
		if index >= 0:
			var grade: String = beat_grade(at_moment, float(_notes[index]["at"]),
				window_seconds(perfect_window_ms), window_seconds(hit_window_ms))
			if grade != GRADE_MISS:
				_last_grade = grade
				_drop_note(index, true)
				prompt_hit.emit(pressed_action, grade)
	var late: int = _notes.size() - 1
	while late >= 0:
		if note_expired(at_moment, float(_notes[late]["at"]), window_seconds(hit_window_ms)):
			var missed: String = str(_notes[late]["action"])
			_last_grade = GRADE_MISS
			_drop_note(late, false)
			prompt_missed.emit(missed)
		late -= 1

## Puts a note on a lane. Split from Prompt On Beat so a test can put one on no lane at all and
## still ask every question about it - which is the whole of what a note is, the drawing aside.
## @ace_hidden
func add_note(action: String, at: float, lane: Node) -> void:
	var note: Dictionary = {"action": action, "at": at, "from": now(), "lane": lane, "node": null}
	if lane != null:
		note["node"] = _spawn_note(action, lane)
	_notes.append(note)
	set_process(true)

## Takes a note off the lane, freeing whatever was drawn for it. `hit` is only whether it is worth
## flashing on the way out - a note that expired leaves quietly.
## @ace_hidden
func _drop_note(index: int, hit: bool) -> void:
	if index < 0 or index >= _notes.size():
		return
	var node: Variant = _notes[index]["node"]
	_notes.remove_at(index)
	if node is Node:
		if hit:
			_flash_out(node as Node)
		else:
			(node as Node).queue_free()

## Opens a prompt of any of the three kinds. One place, so the deadline, the grade and the triggers
## cannot drift apart between a press, a hold and a mash.
## @ace_hidden
func _open_prompt(kind: String, action: String, seconds: float, at: Node) -> void:
	_close_prompt()
	_open = true
	_kind = kind
	_action = action
	_opened_at = now()
	_deadline = _opened_at + maxf(seconds, 0.01)
	_held_for = 0.0
	_mash_count = 0
	_at = at
	_show_prompt(action, at)
	set_process(true)

## A prompt answered in time: the grade is decided once, the trigger carries it, and a sequence
## moves on to its next control.
## @ace_hidden
func _land(at_moment: float) -> void:
	_last_grade = timed_grade(at_moment, _opened_at, _deadline, perfect_share)
	_open = false
	var answered: String = _action
	_flash_out(_node)
	_node = null
	prompt_hit.emit(answered, _last_grade)
	if _in_sequence:
		_advance_sequence()

## A prompt that ran out: the grade is the miss, the trigger carries the control nobody pressed, and
## a sequence ends here rather than carrying on without it.
## @ace_hidden
func _miss(_at_moment: float) -> void:
	_last_grade = GRADE_MISS
	_open = false
	var missed: String = _action
	_close_prompt()
	prompt_missed.emit(missed)
	if _in_sequence:
		_finish_sequence(false)

## The next control of a sequence, or the end of it. Progress counts what has been ANSWERED, so it
## reads 1 on the frame the last one lands rather than on the frame after.
## @ace_hidden
func _advance_sequence() -> void:
	_queue_done += 1
	if _queue_done >= _queue_total:
		_finish_sequence(true)
		return
	_open_prompt(KIND_PRESS, _queue[_queue_done], _queue_seconds, _queue_at)

## The end of a sequence, either way. The queue is emptied here so a second sequence cannot inherit
## the first one's leftovers.
## @ace_hidden
func _finish_sequence(completed: bool) -> void:
	_in_sequence = false
	_queue = PackedStringArray()
	_queue_at = null
	sequence_finished.emit(completed)

## Whether a control went down this frame, asked safely: a control the project does not have is not
## an error to be printed once per frame, it is a control nobody can press.
## @ace_hidden
func _just_pressed(action: String) -> bool:
	return not action.is_empty() and InputMap.has_action(action) and Input.is_action_just_pressed(action)

## Whether a control is being held right now, asked the same safe way.
## @ace_hidden
func _held(action: String) -> bool:
	return not action.is_empty() and InputMap.has_action(action) and Input.is_action_pressed(action)

## Which of the notes' controls went down this frame, or nothing. Only the notes' own controls are
## polled, so a lane costs the presses it is actually listening for.
## @ace_hidden
func _pressed_note_action() -> String:
	for note: Dictionary in _notes:
		var action: String = str(note["action"])
		if _just_pressed(action):
			return action
	return ""

## Builds the prompt for a control and puts it on the layer. A prompt scene that cannot be loaded
## leaves the prompt logic running with nothing drawn, which is the right way round: the grade still
## happens, and Debug Mode says why nothing appeared.
## @ace_hidden
func _show_prompt(action: String, at: Node) -> void:
	if _layer == null:
		return
	var built: Node = _build_prompt(action)
	if built == null:
		return
	_node = built
	_layer.add_child(_node)
	_place(_node, at)

## One copy of the prompt scene, dressed for a control: the glyph for the device in hand, or the
## Input Map's own words when the sheet has drawn no picture for it.
## @ace_hidden
func _build_prompt(action: String) -> Node:
	if not ResourceLoader.exists(prompt_scene):
		if debug_mode:
			push_warning("Prompts: there is no prompt scene at %s, so nothing was drawn." % prompt_scene)
		return null
	var packed: PackedScene = load(prompt_scene) as PackedScene
	if packed == null:
		if debug_mode:
			push_warning("Prompts: %s is not a scene, so nothing was drawn." % prompt_scene)
		return null
	var built: Node = packed.instantiate()
	var picture: Texture2D = glyph_for(action)
	var glyph: Node = built.get_node_or_null("Glyph")
	if glyph is TextureRect:
		(glyph as TextureRect).texture = picture
	var label: Node = built.get_node_or_null("Label")
	if label is Label:
		var words: Label = label as Label
		words.text = "" if picture != null else control_text(action)
		words.add_theme_font_size_override("font_size",
			int(round(float(PROMPT_FONT_SIZE) * float(Engine.get_meta("text_size_scale", 1.0)))))
	return built

## One note on a lane, built out of the lane's own hidden Note child so the art is the lane's rather
## than this pack's. A lane with no such child carries no notes, and says so in Debug Mode.
## @ace_hidden
func _spawn_note(action: String, lane: Node) -> Node:
	var template: Node = lane.get_node_or_null("Note")
	if template == null:
		if debug_mode:
			push_warning("Prompts: the lane %s has no Note child to copy, so nothing was drawn." % lane.name)
		return null
	var built: Node = template.duplicate()
	var glyph: Node = built.get_node_or_null("Glyph")
	if glyph is TextureRect:
		(glyph as TextureRect).texture = glyph_for(action)
	if built is CanvasItem:
		(built as CanvasItem).visible = true
	lane.add_child(built)
	return built

## Where on the screen a prompt is drawn: over the node it was asked for, whether that is a control,
## something in the world or something in 3D, and in the middle of the screen when it was asked for
## nowhere in particular.
## @ace_hidden
func _screen_point(at: Node) -> Vector2:
	if at is Control:
		return (at as Control).get_global_rect().get_center()
	if at is Node2D:
		return (at as Node2D).get_global_transform_with_canvas().origin
	var view: Viewport = get_viewport()
	if view == null:
		return Vector2.ZERO
	if at is Node3D:
		var camera: Camera3D = view.get_camera_3d()
		if camera != null:
			return camera.unproject_position((at as Node3D).global_position)
	return view.get_visible_rect().size * 0.5

## Puts the prompt where it belongs, centred on its point.
## @ace_hidden
func _place(node: Node, at: Node) -> void:
	var box: Control = node as Control
	if box == null:
		return
	box.position = _screen_point(at) - box.size * 0.5

## One frame of drawing: the prompt follows whatever it was pinned to, its ring shows the time left,
## and every note walks its lane. Nothing here decides anything - it only shows what the rules above
## have already decided, which is why none of them needs a scene tree to be tested.
## @ace_hidden
func _draw_frame(at_moment: float) -> void:
	if _open and _node != null:
		_place(_node, _at)
		var ring: Node = _node.get_node_or_null("Ring")
		if ring is Range:
			var span: float = _deadline - _opened_at
			var left: float = 0.0 if span <= 0.0 else clampf((_deadline - at_moment) / span, 0.0, 1.0)
			(ring as Range).value = left * (ring as Range).max_value
	for note: Dictionary in _notes:
		_walk_note(note, at_moment)

## One note, walked from the far end of its lane to the hit line. The lane says where the line is
## with a child called HitLine; a lane without one lands its notes at its own left edge.
## @ace_hidden
func _walk_note(note: Dictionary, at_moment: float) -> void:
	var node: Variant = note["node"]
	var lane: Variant = note["lane"]
	if not (node is Control) or not (lane is Control):
		return
	var travelling: Control = node as Control
	var track: Control = lane as Control
	var line: Node = track.get_node_or_null("HitLine")
	var lands_at: float = (line as Control).position.x if line is Control else 0.0
	var walked: float = note_progress(at_moment, float(note["from"]), float(note["at"]))
	travelling.position = Vector2(lerpf(track.size.x, lands_at, walked),
		(track.size.y - travelling.size.y) * 0.5)

## Takes a prompt off the screen with a flash, clamped by the player's no-flashing answer. The node
## is handed to the walk that frees it, so nothing here has to remember to free it later.
## @ace_hidden
func _flash_out(node: Node) -> void:
	if node == null:
		return
	var canvas: CanvasItem = node as CanvasItem
	if canvas == null:
		node.queue_free()
		return
	var shape: Vector2 = flash_for(flash_strength, flash_seconds,
		bool(Engine.get_meta("no_flashing", false)))
	canvas.modulate = Color(1.0, 1.0, 1.0).lerp(Color(2.5, 2.5, 2.5), clampf(shape.x, 0.0, 1.0))
	var walk: Tween = create_tween()
	walk.tween_property(canvas, "modulate", Color(1.0, 1.0, 1.0, 0.0), shape.y)
	walk.finished.connect(node.queue_free)

## Takes the prompt off the screen with nothing said about it - what a miss and a cancel do.
## @ace_hidden
func _close_prompt() -> void:
	if _node != null:
		_node.queue_free()
		_node = null

## Whether there is nothing left to do: no prompt open and no note on any lane. The director parks
## its own frame when this is true, so a game between prompts pays for nothing.
## @ace_hidden
func _at_rest() -> bool:
	return not _open and _notes.is_empty()

## Ends a sequence that was still running because a plain prompt has interrupted it. It ends as an
## uncompleted one rather than vanishing: a cutscene waiting on the trigger would otherwise wait for
## ever, and a silent drop is the hardest kind of bug to find.
## @ace_hidden
func _leave_sequence() -> void:
	if _in_sequence:
		_finish_sequence(false)

## The song's next beat, from a Music director in the project, on the engine clock this pack grades
## against. Reached by node path and asked whether it can answer, so a project with no music at all
## still runs every row here - it simply falls back to the lead.
## @ace_hidden
func _music_beat_at() -> float:
	var music: Node = get_node_or_null("/root/Music")
	if music == null or not music.has_method("next_beat_at"):
		return 0.0
	return float(music.call("next_beat_at"))

## The device the last input event came from. Reading the event rather than asking which pads are
## plugged in is what makes a player who puts the pad down and reaches for the keyboard see keyboard
## glyphs on the very next prompt.
func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		_device = DEVICE_KEYBOARD
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_device = device_for_name(Input.get_joy_name(event.device))
#endregion

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.name = LAYER_NAME
	add_child(_layer)
	# Nothing is being asked of the player yet, so nothing is walking: the frame starts parked and
	# every row that opens a prompt turns it back on.
	set_process(false)

func _process(delta: float) -> void:
	var at_moment: float = now()
	step_notes(at_moment, _pressed_note_action())
	step(at_moment, delta, _just_pressed(_action), _held(_action))
	_draw_frame(at_moment)
	if _at_rest():
		set_process(false)

func prompt(action: String, seconds: float, at: Node) -> void:
	_leave_sequence()
	_open_prompt(KIND_PRESS, action, seconds, at)

func hold_prompt(action: String, hold: float, seconds: float, at: Node) -> void:
	_leave_sequence()
	_hold_needed = maxf(hold, 0.01)
	_open_prompt(KIND_HOLD, action, seconds, at)

func mash_prompt(action: String, presses: int, seconds: float, at: Node) -> void:
	_leave_sequence()
	_mash_needed = maxi(presses, 1)
	_open_prompt(KIND_MASH, action, seconds, at)

func sequence(actions: String, seconds: float, at: Node) -> void:
	var wanted: PackedStringArray = PackedStringArray()
	for part: String in actions.split(","):
		var word: String = part.strip_edges()
		if not word.is_empty():
			wanted.append(word)
	if wanted.is_empty():
		if debug_mode:
			push_warning("Prompts: Sequence was given no controls, so there was nothing to ask for.")
		return
	_queue = wanted
	_queue_total = wanted.size()
	_queue_done = 0
	_queue_seconds = seconds
	_queue_at = at
	_in_sequence = true
	_open_prompt(KIND_PRESS, wanted[0], seconds, at)

func cancel_prompt() -> void:
	_open = false
	_close_prompt()
	for index: int in range(_notes.size() - 1, -1, -1):
		_drop_note(index, false)
	if _in_sequence:
		_finish_sequence(false)

func prompt_on_beat(action: String, lane: Node) -> void:
	var at_moment: float = now()
	add_note(action, beat_moment(at_moment, _music_beat_at(), lead_seconds), lane)

func force_device(device_name: String) -> void:
	var word: String = device_name.strip_edges().to_lower()
	_forced_device = "" if word == "auto" else word

func prompt_is_open() -> bool:
	return _open

func grade_is(grade: String) -> bool:
	return _last_grade == grade.strip_edges().to_lower()

func last_grade() -> String:
	return _last_grade

func prompt_time_left() -> float:
	if not _open:
		return 0.0
	return maxf(_deadline - now(), 0.0)

func sequence_progress() -> float:
	if _queue_total <= 0:
		return 0.0
	return float(_queue_done) / float(_queue_total)

func glyph_for(action: String) -> Texture2D:
	return glyph_in(glyphs, device(), action)

func device() -> String:
	return _forced_device if not _forced_device.is_empty() else _device
