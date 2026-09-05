# EventForge module - the SEQUENCER: a grid of moments on a beat.
#
# Lights that pulse on the beat are, in most games, a counter and a modulo in a per-frame row, and
# changing the pattern means rewriting the arithmetic. What the pattern actually IS is a grid: a
# track per thing that can fire, a step per beat subdivision, and a name in the cells that fire.
# These rows play that grid.
#
# THE GRID IS A FILE THE PROJECT OWNS (SequenceResource): its tempo, how many steps a bar holds, and
# its tracks. Nothing ships - there is no house pattern and no house track name, because a rhythm is
# the game's. A new sequence is empty, and the first track is the first thing somebody adds.
#
# A CROSSED CELL IS SAID TWICE, both times in the engine's own plumbing. Once as this node's own
# `sequence_stepped` signal, which On Sequence Step connects to - a plain signal a sheet declares for
# itself. And once to the GROUP the track is named after, so a lights track reaches every light
# listening on it with no reference held anywhere. Neither is a mechanism to learn.
#
# ONE CLOCK, AND THE SONG WINS. With a Music autoload in the tree the grid reads the song's own beat
# position and cannot drift from what the player hears; with no song it counts its own beats from the
# tempo it was given. That is what keeps a browser tab that throttles frames landing on the beat.
#
# The work itself is a real file a debugger can step into: `EventForgeSequencer`, at
# `eventsheet_addons/sequencer.gd`, plain typed GDScript with no plugin class named anywhere in it,
# exactly like the free-spot and world-look helpers the spawn and environment rows call. It ships in
# the project's OWN folder rather than in the plugin's, because `addons/` is what an uninstall
# deletes and a sheet holding one of these rows has to go on parsing after the editor is gone.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility covenant).
@tool
class_name EventForgeSequencerACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The picker shelf these rows sit on.
const CAT := "Sequencer"

## The runtime the rows call, named once. Frozen with the templates that spell it.
const HEAD_CALL: String = "EventForgeSequencer"

## The signal a crossed cell is said on - a plain signal the sheet declares for itself.
const STEPPED_SIGNAL: String = "sequence_stepped"

## The field a grid is picked in: a file field over the project's own resources, rather than an
## expression box a path has to be typed into by hand.
const RESOURCE_HINT: String = "resource_path"


static func get_descriptors() -> Array[ACEDescriptor]:
	return [
		F.act("SequencePlay", "Play Sequence", "%s.play(self, {sequence}, {bpm})" % HEAD_CALL, CAT,
			"play sequence {sequence} at {bpm} bpm",
			"Starts stepping a grid of cells on this object: a track per thing that can fire, a step per beat subdivision, and a name in the cells that should. Every cell the head crosses is said twice - as this node's sequence_stepped signal, which On Sequence Step answers, and to the group the TRACK is named after, so a lights track reaches every light listening on it without a reference being held anywhere. With a Music autoload in the tree the grid runs on the SONG's beat and cannot drift from what the player hears; without one it counts its own from the tempo here. A tempo of 0 means the one the file was saved with.",
			"Node").param("sequence", "\"\"", "Sequence",
			"The grid to step, as a SequenceResource file in the project.",
			RESOURCE_HINT).param_typed("float", "bpm", "0.0", "At bpm",
			"The tempo to count at. 0 means the tempo the file was saved with; a song playing beside it wins over both.",
			"expression").featured(),
		F.act("SequenceStop", "Stop Sequence", "%s.stop(self)" % HEAD_CALL, CAT,
			"stop the sequence",
			"Stops the grid on this object and PARKS the head: it processes nothing at all until it is played again, which is the whole of its cost at rest. Where it stopped is kept, so Jump To Sequence Step still means something afterwards.",
			"Node"),
		F.act("SequenceSetTempo", "Set Sequence Tempo", "%s.set_tempo(self, {bpm})" % HEAD_CALL, CAT,
			"set the sequence tempo to {bpm} bpm",
			"Changes the tempo the head counts at without restarting the grid - the row a difficulty ramp or a boss phase uses. Ignored while a song is playing, because the song is the clock then.",
			"Node").param_typed("float", "bpm", "120.0", "Bpm",
			"Beats a minute. Sixteen steps a bar at 120 is eight steps a second.", "expression"),
		F.act("SequenceJumpTo", "Jump To Sequence Step", "%s.jump_to(self, {step})" % HEAD_CALL, CAT,
			"jump to sequence step {step}",
			"Moves the head to a step. The step named is the NEXT one to be said out loud, so jumping to 0 starts the pattern again from its beginning - the fill, the drop, the second half of the bar.",
			"Node").param_typed("int", "step", "0", "Step",
			"Which step to move to, counted from 0.", "expression"),
		F.cond("SequenceIsPlaying", "Sequence Is Playing", "%s.is_playing(self)" % HEAD_CALL, CAT,
			"the sequence is playing",
			"True while a grid is being stepped on this object - the guard before starting a second one over the top of the first.",
			"Node"),
		F.expr("SequenceCurrentStep", "Current Sequence Step", "%s.current_step(self)" % HEAD_CALL,
			CAT, "the current sequence step",
			"Which step the head last said out loud, counted from 0, and -1 before it has said any. What a grid drawn on the HUD reads to know which column to light.",
			"Node"),
		F.trig("OnSequenceStep", "On Sequence Step", STEPPED_SIGNAL, CAT,
			"On a sequence step",
			"Runs every time the head crosses a cell that has something in it, and hands over the track it is on, which step it is, and the name written in the cell. The signal is one this sheet declares for itself - add a signal block saying sequence_stepped(track, step, name) and both halves are ordinary Godot - so a rhythm becomes something the game answers row by row rather than with a counter and a modulo.",
			"Node")
	]


static func section_descriptions() -> Dictionary:
	return {CAT: "A grid of moments on a beat: tracks down the side, steps across the top, and a name in a cell. It runs on the song's clock when there is one and its own when there is not, and parks the moment it is stopped."}
