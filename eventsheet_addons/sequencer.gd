## @ace_version(1.0.0)
class_name EventForgeSequencer
extends Node
## The thing that steps a grid: it counts beats - the song's when there is one, its own when there is not - and says every cell it crosses out loud. The runtime the Play Sequence, Stop Sequence, Set Sequence Tempo and Jump To Sequence Step rows call.

# THE THING THAT STEPS A GRID.
#
# A SequenceResource is the pattern; this is the play head. It counts beats and, every time it
# crosses a step, says out loud whatever the cells on that step hold:
#
#   as a signal   the host's own `sequence_stepped(track, step, name)`, which On Sequence Step
#                 connects to. A plain signal a sheet declares for itself - nothing invented.
#   as a group    every node in the group named after the TRACK is asked to play that name, so a
#                 lights track reaches every light listening on it and no reference is held anywhere.
#                 The engine's own groups, which is why there is nothing here to learn.
#
# ONE CLOCK, AND THE SONG WINS. A game with a song in it has exactly one clock, and it is the song's:
# when a Music autoload is in the tree and reporting a beat, the grid reads its position and cannot
# drift from what the player hears. With no song, the grid counts its own beats from the tempo it was
# given. That is one branch, taken per frame, and it is what makes a browser tab that throttles
# frames still land on the beat - the audio position is the honest clock there.
#
# IT PARKS. A stopped sequencer processes nothing at all, which is the whole of its cost at rest, and
# a playing one does one comparison against the clock and no allocation per frame.
#
# PLAIN GDSCRIPT, AND NOT THE PLUGIN'S. Nothing here touches an editor, a sheet or any class the
# plugin declares, and this file ships in the project's OWN folder, so a sheet holding one of these
# rows goes on parsing and running after the editor is gone.

## The name the play head is added under, so a second Play Sequence on the same object finds the one
## that is already there rather than starting a second head over the top of it.
const NODE_NAME: String = "EventForgeSequencer"

## The signal a crossed cell is said on. A plain signal the sheet declares for itself, which is why
## it is a name here and not a mechanism.
const STEPPED_SIGNAL: StringName = &"sequence_stepped"

## The autoload a song's clock is read from, and the two things it has to be able to answer. Asked by
## NAME and by method, never by class, so this file names no pack.
const MUSIC_AUTOLOAD: String = "Music"
## The same word as a path, spelled once, so the per-frame look-up builds nothing.
const MUSIC_PATH: NodePath = ^"Music"
const BEAT_NUMBER_METHOD: StringName = &"beat_number"
const BEAT_PHASE_METHOD: StringName = &"beat_phase"

## What a track's group members are asked to do with a cell's name: the door a project writes for
## itself, and then the verb the Juice behaviour already carries. Both take the name and a strength,
## so a lights track of Juice nodes plays its cells with nothing written for it - which is what
## "reaches every light listening on it" has to mean when no shipped pack answers to the first name.
const PLAY_METHOD: StringName = &"play_moment"
const MOMENT_METHOD: StringName = &"moment"
const PLAY_METHODS: Array[StringName] = [PLAY_METHOD, MOMENT_METHOD]

## The answer a frame that crossed nothing gives: one list, made once and never written to, because
## a head that is playing answers this on nearly every frame it is asked.
const NOTHING_CROSSED: Array[Dictionary] = []

## Whose sequence this is - the node the signal is raised on.
var host: Node = null

## The grid being stepped, the tempo it is counted at when no song is playing, and whether the head
## is moving.
var sequence: SequenceResource = null
var bpm: float = 120.0
var playing: bool = false

## Where the head is, in beats, and the last step it said out loud. The step is kept rather than
## derived so a frame that crosses three steps says all three rather than only the last.
var beat_position: float = 0.0
var last_step: int = -1


## Starts a grid on this object, at a tempo. A sequence already playing here is replaced rather than
## layered, because a second play head on one object is two patterns nobody asked for.
static func play(on: Node, grid: Variant, at_bpm: float = 0.0) -> void:
	var found: SequenceResource = sequence_of(grid)
	if on == null or found == null:
		return
	head_on(on).start(found, at_bpm)


## Stops the grid on this object and parks the head - it processes nothing at all until it is played
## again. Where it stopped is kept, so a Jump To Sequence Step still means something afterwards.
static func stop(on: Node) -> void:
	var head: EventForgeSequencer = head_or_null(on)
	if head != null:
		head.halt()


## Changes the tempo the head counts at without restarting the grid - the row a difficulty ramp or a
## boss phase uses. Ignored while a song is playing, because the song is the clock then.
static func set_tempo(on: Node, at_bpm: float) -> void:
	var head: EventForgeSequencer = head_or_null(on)
	if head != null:
		head.bpm = maxf(at_bpm, 1.0)


## Moves the head to a step. The step named is the NEXT one to be said out loud, so jumping to 0
## starts the pattern again from its beginning.
static func jump_to(on: Node, step: int) -> void:
	var head: EventForgeSequencer = head_or_null(on)
	if head != null:
		head.jump(step)


## True while a grid is being stepped on this object.
static func is_playing(on: Node) -> bool:
	var head: EventForgeSequencer = head_or_null(on)
	return head != null and head.playing


## Which step the head last said out loud, or -1 before it has said any.
static func current_step(on: Node) -> int:
	var head: EventForgeSequencer = head_or_null(on)
	return head.last_step if head != null else -1


## The grid a row means, from either of the two things a row can hand over: the file itself, as a
## piece of code passes it, or the path to it, as a row picked in the editor writes it.
static func sequence_of(grid: Variant) -> SequenceResource:
	if grid is SequenceResource:
		return grid as SequenceResource
	var path: String = str(grid).strip_edges()
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as SequenceResource


## The head on this object, added under it the first time and found every time after.
static func head_on(on: Node) -> EventForgeSequencer:
	var found: EventForgeSequencer = head_or_null(on)
	if found != null:
		return found
	var made: EventForgeSequencer = EventForgeSequencer.new()
	made.name = NODE_NAME
	made.host = on
	on.add_child(made)
	return made


## The head this object already has, or nothing.
static func head_or_null(on: Node) -> EventForgeSequencer:
	return on.get_node_or_null(NodePath(NODE_NAME)) as EventForgeSequencer if on != null else null


## Which step a position in beats has reached. Pure arithmetic, so it is the piece a test can pin
## without a tree, a song or a frame.
static func step_at(position_in_beats: float, steps_per_beat: float) -> int:
	return floori(maxf(position_in_beats, 0.0) * maxf(steps_per_beat, 0.001))


## Starts this head on a grid. The instance half of Play Sequence, so a head held directly - by a
## test, or by a piece of code that keeps its own - is driven exactly as a row drives one.
func start(grid: SequenceResource, at_bpm: float = 0.0) -> void:
	sequence = grid
	bpm = at_bpm if at_bpm > 0.0 else (grid.bpm if grid != null else bpm)
	beat_position = 0.0
	last_step = -1
	playing = grid != null
	set_process(playing)


## Stops this head and parks it. Where it stopped is kept.
func halt() -> void:
	playing = false
	set_process(false)


## Moves this head to a step - the step named is the NEXT one it will say out loud.
func jump(step: int) -> void:
	if sequence == null:
		return
	beat_position = step / sequence.steps_per_beat()
	last_step = step - 1


func _ready() -> void:
	if host == null:
		host = get_parent()
	set_process(playing)


func _process(delta: float) -> void:
	for cell: Dictionary in advance(delta):
		say(cell)


## Moves the head on by one frame and answers every cell it crossed, in the order it crossed them. A
## frame long enough to cross three steps answers all three: a dropped frame must not swallow a beat.
##
## Separate from the saying so the whole of the timing can be stepped by hand and pinned by value.
func advance(delta: float) -> Array[Dictionary]:
	if not playing or sequence == null:
		return NOTHING_CROSSED
	beat_position = position_after(delta)
	var reached: int = step_at(beat_position, sequence.steps_per_beat())
	if last_step >= reached:
		# The frames BETWEEN two steps are almost all of them, and they answer with the one shared
		# empty list rather than making a new one nothing will be put in.
		return NOTHING_CROSSED
	var crossed: Array[Dictionary] = []
	while last_step < reached:
		last_step += 1
		crossed.append_array(sequence.cells_at(last_step))
	return crossed


## Where the head is after one frame: the song's own position when a song is playing, and the tempo
## counted out by hand when there is not.
func position_after(delta: float) -> float:
	var clock: Node = music_clock()
	if clock != null:
		return float(clock.call(BEAT_NUMBER_METHOD)) + float(clock.call(BEAT_PHASE_METHOD))
	return beat_position + maxf(delta, 0.0) * maxf(bpm, 1.0) / 60.0


## The song's clock, when there is one in the tree that can answer where the beat is. Found by name
## and asked by method, never by class, so this file names no pack and a project without one simply
## counts its own beats.
func music_clock() -> Node:
	if not is_inside_tree():
		return null
	var found: Node = get_tree().root.get_node_or_null(MUSIC_PATH)
	if found == null or not found.has_method(BEAT_NUMBER_METHOD) or not found.has_method(BEAT_PHASE_METHOD):
		return null
	return found


## One crossed cell, said out loud twice: as the host's own signal, and to the group the track is
## named after. Both are the engine's own plumbing, and a project may answer either, both or neither.
func say(cell: Dictionary) -> void:
	if host != null and host.has_signal(STEPPED_SIGNAL):
		host.emit_signal(STEPPED_SIGNAL, str(cell.get("track", "")), int(cell.get("step", 0)),
			str(cell.get("name", "")))
	if not is_inside_tree():
		return
	var track: String = str(cell.get("track", "")).strip_edges()
	if track.is_empty():
		return
	var named: String = str(cell.get("name", ""))
	for listener: Node in get_tree().get_nodes_in_group(track):
		for method: StringName in PLAY_METHODS:
			if listener.has_method(method):
				listener.call(method, named, 1.0)
				break
