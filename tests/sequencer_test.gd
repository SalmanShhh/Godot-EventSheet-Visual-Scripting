# A grid of moments on a beat: the order the cells come out in at a tempo, the jump, and the signal
# a crossed cell is said on.
#
# The claim this file holds to account has four parts:
#
#   * THE ORDER IS THE GRID'S. Pinned by hand-stepping the head one frame at a time at a known tempo
#     and reading back every cell it crossed, in the order it crossed them - which is the whole of
#     what a sequencer is and can be asked without a tree, a song or a frame.
#   * A LONG FRAME SWALLOWS NOTHING. One frame that crosses three steps says all three, because a
#     dropped frame must not eat a beat.
#   * TRACKS ARE THEIR OWN LENGTH. A four-cell track and a three-cell track run against each other,
#     each wrapping at its own end.
#   * A CROSSED CELL IS SAID OUT LOUD on the host's own plain signal, so a sheet's On Sequence Step
#     is ordinary Godot and nothing here is a mechanism to learn.
#
# The listener is a real file, because a script built from a string in memory has no path for the
# engine to load it back through.
@tool
class_name SequencerTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const MODULE := preload("res://addons/eventforge/registration/modules/sequencer_aces.gd")
const RESOLVER := preload("res://addons/eventforge/compiler/trigger_resolver.gd")

## The script a node wears when it wants to hear about a crossed cell - the plain signal block a
## sheet would declare.
const LISTENER_PATH := "user://__sequencer_test_listener.gd"
const LISTENER_SOURCE := """extends Node

signal sequence_stepped(track, step, name)

var heard: Array[String] = []


func remember(track: String, step: int, name: String) -> void:
	heard.append("%s@%d=%s" % [track, step, name])
"""

## A tempo whose arithmetic is exact: 240 beats a minute is four a second, and sixteen steps a bar
## over four beats is four steps a beat - so one second is exactly sixteen steps and a quarter of a
## second is exactly four. Every number in the pins below is that, and not a rounding.
const BPM: float = 240.0


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_rows() and ok
	ok = _test_the_trigger_is_a_plain_signal() and ok
	ok = _test_the_steps_come_out_in_order() and ok
	ok = _test_a_long_frame_swallows_nothing() and ok
	ok = _test_tracks_are_their_own_length() and ok
	ok = _test_a_jump_moves_the_head() and ok
	ok = _test_a_stopped_head_steps_nothing() and ok
	ok = _test_a_crossed_cell_is_said_out_loud() and ok
	_cleanup()
	return ok


## The listener script this test wrote. On CI the whole suite runs serially in one process, so a
## file left in the user folder is state the next test sees.
static func _cleanup() -> void:
	if FileAccess.file_exists(LISTENER_PATH):
		DirAccess.remove_absolute(LISTENER_PATH)


## The seven rows, by the bytes they emit. Every one of them acts on the object the row is on, which
## is what makes two sequencers in one scene two patterns rather than one.
static func _test_the_rows() -> bool:
	var templates: Dictionary = {}
	var fields: Dictionary = {}
	for row: ACEDescriptor in MODULE.get_descriptors():
		templates[row.ace_id] = str(row.codegen_template)
		var named: PackedStringArray = PackedStringArray()
		for parameter: ACEParam in row.params:
			named.append("%s=%s" % [parameter.id, str(parameter.default_value)])
		fields[row.ace_id] = ", ".join(named)
	return SUPPORT.pins("sequencer_test", [
		["playing a grid is one call", templates.get("SequencePlay", ""),
			"EventForgeSequencer.play(self, {sequence}, {bpm})"],
		["stopping it names nothing but the object", templates.get("SequenceStop", ""),
			"EventForgeSequencer.stop(self)"],
		["the tempo is changed without restarting", templates.get("SequenceSetTempo", ""),
			"EventForgeSequencer.set_tempo(self, {bpm})"],
		["the head is moved by step number", templates.get("SequenceJumpTo", ""),
			"EventForgeSequencer.jump_to(self, {step})"],
		["and read back the same way", templates.get("SequenceCurrentStep", ""),
			"EventForgeSequencer.current_step(self)"],
		["the play row's fields", fields.get("SequencePlay", ""), "sequence=\"\", bpm=0.0"],
		["the trigger emits nothing of its own", templates.get("OnSequenceStep", ""), ""]
	])


## The other half of the trigger: a plain signal the sheet declares, connected the way every other
## declared signal is. Nothing here invents a mechanism.
static func _test_the_trigger_is_a_plain_signal() -> bool:
	var event: EventRow = EventRow.new()
	event.trigger_id = "OnSequenceStep"
	var resolved: Dictionary = RESOLVER.resolve_trigger(event)
	return SUPPORT.pins("sequencer_test", [
		["the handler is named after the signal", str(resolved.get("function_name", "")),
			"_on_sequence_stepped"],
		["it is handed the track, the step and the name", str(resolved.get("args", "")),
			"track: String, step: int, name: String"],
		["and it connects to the sheet's own signal", str(resolved.get("signal_name", "")),
			"sequence_stepped"]
	])


## The order, at a tempo, stepped by hand a quarter of a second at a time: four steps a quarter
## second, so each frame crosses four steps and the cells come out in the grid's own order.
static func _test_the_steps_come_out_in_order() -> bool:
	var head: EventForgeSequencer = _head(_grid([
		{"name": "lights", "cells": ["pulse", "", "pulse", ""]},
		{"name": "drums", "cells": ["kick", "", "", "snare"]}
	]))
	var said: PackedStringArray = PackedStringArray()
	for frame: int in 2:
		for cell: Dictionary in head.advance(0.25):
			said.append("%s@%d=%s" % [cell["track"], cell["step"], cell["name"]])
	var ok: bool = SUPPORT.pins("sequencer_test", [
		["the head speaks the step it is on, so both tracks are heard at the beginning",
			", ".join(said.slice(0, 2)), "lights@0=pulse, drums@0=kick"],
		["then the light on the third step and the snare on the fourth",
			", ".join(said.slice(2, 4)), "lights@2=pulse, drums@3=snare"],
		["a quarter of a second at 240 bpm reaches step four, where both tracks wrap round",
			", ".join(said.slice(4, 6)), "lights@4=pulse, drums@4=kick"],
		["the second quarter says the four steps after it",
			", ".join(said.slice(6, 10)),
			"lights@6=pulse, drums@7=snare, lights@8=pulse, drums@8=kick"],
		["ten cells in half a second", said.size(), 10],
		["and the head knows which step it last said", head.last_step, 8]
	])
	head.free()
	return ok


## One frame long enough to cross three steps says all three. A dropped frame must not eat a beat -
## the head catches up rather than skipping to the present.
static func _test_a_long_frame_swallows_nothing() -> bool:
	var head: EventForgeSequencer = _head(_grid([
		{"name": "drums", "cells": ["one", "two", "three", "four"]}
	]))
	var said: PackedStringArray = PackedStringArray()
	for cell: Dictionary in head.advance(0.75):
		said.append(str(cell["name"]))
	var ok: bool = SUPPORT.pins("sequencer_test", [
		["three quarters of a second reaches step twelve, and every step up to it is said",
			said.size(), 13],
		["starting at the beginning", said[0], "one"],
		["and ending where the head got to, wrapped round again", said[12], "one"]
	])
	head.free()
	return ok


## A four-cell track and a three-cell track run against each other, each wrapping at its own end.
static func _test_tracks_are_their_own_length() -> bool:
	var grid: SequenceResource = _grid([
		{"name": "four", "cells": ["a", "", "", ""]},
		{"name": "three", "cells": ["b", "", ""]}
	])
	var meeting: PackedStringArray = PackedStringArray()
	for step: int in 13:
		for cell: Dictionary in grid.cells_at(step):
			meeting.append("%s@%d" % [cell["track"], step])
	return SUPPORT.pins("sequencer_test", [
		["each track wraps at its own length", ", ".join(meeting),
			"four@0, three@0, three@3, four@4, three@6, four@8, three@9, four@12, three@12"],
		["and the grid is as long as its longest track", grid.length_in_steps(), 4]
	])


## The step named is the NEXT one to be said out loud, so a jump to 0 starts the pattern again from
## its beginning.
static func _test_a_jump_moves_the_head() -> bool:
	var head: EventForgeSequencer = _head(_grid([
		{"name": "drums", "cells": ["one", "two", "three", "four"]}
	]))
	head.advance(0.25)
	var after_first: int = head.last_step
	head.jump(2)
	var next_up: PackedStringArray = PackedStringArray()
	for cell: Dictionary in head.advance(0.0):
		next_up.append(str(cell["name"]))
	var ok: bool = SUPPORT.pins("sequencer_test", [
		["the head reached the fourth step", after_first, 4],
		["a jump names the step that comes next", ", ".join(next_up), "three"],
		["and the head is on it", head.last_step, 2]
	])
	head.free()
	return ok


## A head that is not playing steps nothing at all, however much time goes by - which is what parked
## means here, and the whole of the cost at rest.
static func _test_a_stopped_head_steps_nothing() -> bool:
	var head: EventForgeSequencer = _head(_grid([
		{"name": "drums", "cells": ["one", "two"]}
	]))
	head.advance(0.25)
	head.playing = false
	var after_stopping: int = head.advance(10.0).size()
	var ok: bool = SUPPORT.pins("sequencer_test", [
		["a stopped head crosses nothing", after_stopping, 0],
		["and a head with no grid on it crosses nothing either",
			_head(null).advance(1.0).size(), 0]
	])
	head.free()
	return ok


## The signal, on a node that declares it: three things handed over, and a sheet's own On Sequence
# Step is the ordinary Godot connection to it.
static func _test_a_crossed_cell_is_said_out_loud() -> bool:
	_write_listener()
	var listener: Node = Node.new()
	listener.set_script(load(LISTENER_PATH))
	var head: EventForgeSequencer = _head(_grid([
		{"name": "lights", "cells": ["pulse", ""]}
	]))
	head.host = listener
	listener.connect("sequence_stepped", Callable(listener, "remember"))
	for cell: Dictionary in head.advance(0.25):
		head.say(cell)
	var ok: bool = SUPPORT.pins("sequencer_test", [
		["every crossed cell arrives on the host's own signal",
			", ".join(listener.get("heard") as Array[String]),
			"lights@0=pulse, lights@2=pulse, lights@4=pulse"],
		# The other half of saying a cell is the track's GROUP, and a door nothing answers to is a
		# track that never fires. The group itself needs a tree, so what is pinned here is that one
		# of the names knocked on is a verb a shipped behaviour really has.
		["and the group door names a verb a shipped pack answers to",
			_a_pack_answers_to(EventForgeSequencer.PLAY_METHODS), true]
	])
	head.free()
	listener.free()
	return ok


## Whether the Juice behaviour declares any of the methods the group door tries. Read off the SCRIPT
## rather than an instance, because the behaviour wants a host and this test has no tree.
static func _a_pack_answers_to(methods: Array[StringName]) -> bool:
	var juice: GDScript = load("res://eventsheet_addons/juice/juice_behavior.gd") as GDScript
	if juice == null:
		return false
	var declared: PackedStringArray = PackedStringArray()
	for entry: Dictionary in juice.get_script_method_list():
		declared.append(str(entry.get("name", "")))
	for method: StringName in methods:
		if declared.has(String(method)):
			return true
	return false


## A head to step by hand: not in a tree, which is what makes it a piece of arithmetic rather than a
## frame of a game.
static func _head(grid: SequenceResource) -> EventForgeSequencer:
	var head: EventForgeSequencer = EventForgeSequencer.new()
	head.sequence = grid
	head.bpm = BPM
	head.playing = grid != null
	head.last_step = -1
	return head


## A grid made here, because nothing ships: a sequence is a file the project makes.
static func _grid(tracks: Array[Dictionary]) -> SequenceResource:
	var grid: SequenceResource = SequenceResource.new()
	grid.tracks = tracks
	return grid


static func _write_listener() -> void:
	var file: FileAccess = FileAccess.open(LISTENER_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(LISTENER_SOURCE)
		file.close()
