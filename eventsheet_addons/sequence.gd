## @ace_version(1.0.0)
class_name SequenceResource
extends Resource
## A grid of moments on a beat: tracks down the side, steps across the top, and a name in a cell - the file the Play Sequence row steps through.

# A GRID OF MOMENTS ON A BEAT.
#
# Lights that pulse on the beat are, in most games, a counter and a modulo in a per-frame row, and
# changing the pattern means rewriting the arithmetic. What the pattern actually IS is a grid: a
# track per thing that can fire, a step per beat subdivision, and a name in the cells that should
# fire. This file is that grid.
#
# WHAT A CELL HOLDS: a name. The sequencer says it out loud - as this node's own sequence_stepped
# signal, so On Sequence Step can answer it, and as a call to the group named after the TRACK, so a
# lights track reaches every light listening on it without one reference being held anywhere. The
# name is usually a moment's; nothing here decides that, because a name is a name.
#
# TRACKS ARE THEIR OWN LENGTH. A track of four cells and a track of six run side by side, each
# wrapping at its own end - which is where a cross-rhythm comes from, and which costs nothing to
# allow because a step is read with one modulo either way.
#
# NOTHING SHIPS. There is no house pattern and no house track name: a sequence is a `.tres` the
# project makes. A new one is empty, and the first track is the first thing you add.
#
# PLAIN GDSCRIPT, AND NOT THE PLUGIN'S. This file ships in the project's own folder and names no
# plugin class, so a `.tres` made from it goes on loading after the editor is gone.

## The beats a bar is counted in. Four, because that is what steps-per-bar means to everybody who
## has ever written a drum pattern, and a number here rather than a field because a sequence whose
## bar is a different length is a sequence with a different steps-per-bar.
const BEATS_PER_BAR: float = 4.0

## How fast the grid runs when nothing else says: beats per minute. The Play Sequence row can hand
## over another, and a Music track playing beside it overrides both, because a game with a song in
## it has exactly one clock.
@export_range(20.0, 300.0, 0.5, "or_greater") var bpm: float = 120.0

## How many steps one bar is divided into. 16 is a sixteenth-note grid, 4 is one step a beat.
@export_range(1, 64, 1, "or_greater") var steps_per_bar: int = 16

## The tracks, in order. Each is a dictionary of a name and its cells: {"name": "lights",
## "cells": ["pulse", "", "pulse", ""]}. The name is the group the track speaks to; a cell holding
## nothing is a step where that track is silent.
@export var tracks: Array[Dictionary] = []


## How many steps go by in one beat - the number that turns a position in beats into a position in
## the grid.
func steps_per_beat() -> float:
	return maxi(steps_per_bar, 1) / BEATS_PER_BAR


## Every track's name, in the order the file holds them - what a reader picks from and what the
## groups are called.
func track_names() -> PackedStringArray:
	var named: PackedStringArray = PackedStringArray()
	for track: Dictionary in tracks:
		named.append(str(track.get("name", "")))
	return named


## What fires on one step: a dictionary per track that has something to say, with the track's name,
## the step it is on and the name in the cell. A step nobody wrote anything on answers nothing at
## all, which is what most steps of most grids are.
##
## The step wraps per TRACK, at that track's own length, so a four-cell track and a six-cell track
## run against each other rather than being padded to the longer one.
func cells_at(step: int) -> Array[Dictionary]:
	var firing: Array[Dictionary] = []
	for track: Dictionary in tracks:
		var cells: Array = track.get("cells", []) as Array
		if cells.is_empty():
			continue
		var named: String = str(cells[posmod(step, cells.size())]).strip_edges()
		if named.is_empty():
			continue
		firing.append({"track": str(track.get("name", "")), "step": step, "name": named})
	return firing


## How long the whole grid is before every track is back where it started - the longest track's
## length, which is what On Sequence Looped counts. A grid with no tracks has no length.
func length_in_steps() -> int:
	var longest: int = 0
	for track: Dictionary in tracks:
		longest = maxi(longest, (track.get("cells", []) as Array).size())
	return longest
