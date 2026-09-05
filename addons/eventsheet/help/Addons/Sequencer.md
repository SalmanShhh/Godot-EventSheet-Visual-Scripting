# Sequencer - A Grid Of Moments On A Beat

Sequencer is the Godot EventSheets vocabulary for anything that happens on a beat. Lights that pulse in time are, in most games, a counter and a modulo in a per-frame row, and changing the pattern means rewriting the arithmetic. What the pattern actually IS is a grid: a **track** per thing that can fire, a **step** per beat subdivision, and a **name** in the cells that should fire. A **SequenceResource** is that grid, saved as a file the project owns, and `Play Sequence` steps it on any node. Every cell the head crosses is said twice, both times in the engine's own plumbing: as the node's own `sequence_stepped` signal, which **On Sequence Step** answers, and as a call to the group the TRACK is named after, so a lights track reaches every light listening on it without one reference being held anywhere. With a Music autoload in the tree, the grid runs on the song's own beat and cannot drift from what the player hears; without one it counts its own beats from the tempo it was given. A stopped sequencer processes nothing at all.

---

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [The sequence file](#the-sequence-file)
5. [ACE reference](#ace-reference)
6. [Use cases](#use-cases)
7. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Lights and props on the beat.** A lights track, a group of lights, and the pattern is a row of cells rather than a modulo in a per-frame event.
- **Rhythm games.** Notes as cells on a track, judged against a clock that is the song's own position rather than a counter that drifts.
- **Boss attack patterns.** A grid per phase, and switching phases is switching which file the head is stepping.
- **Enemy wave rhythms.** A spawn track and a telegraph track running side by side, each one wrapping at its own length so the pattern never quite repeats.
- **Music videos and set pieces.** A camera track, a lights track and a confetti track, all on one grid, tuned by moving cells rather than by editing timings.
- **Cross-rhythms for free.** A track of four cells and a track of six run against each other because a step wraps per track, which is a pattern nobody had to write down step by step.
- **Tutorials and drills with a metronome.** A grid at a slow tempo with a Set Sequence Tempo row on the difficulty, so the same drill speeds up without being re-authored.
- **Ambient life in a level.** A machine that clanks, a neon sign that buzzes, a drip in a cave, all cells on tracks of different lengths.
- **Browser builds that still land on the beat.** With a song playing, the grid reads the audio position rather than counting frames, so a throttled tab does not fall behind.
- **Anything that needs no clock at rest.** A stopped head processes nothing, and a playing one does one comparison against the clock with no allocation per frame.

---

## Core concepts

**The grid is a file the project owns.** A **SequenceResource** holds a tempo, how many steps a bar is divided into, and the tracks. Nothing ships: there is no house pattern and no house track name, because a rhythm is the game's. A new sequence is empty, and the first track is the first thing you add.

**A track is a name and a list of cells.** The name is the group the track speaks to; the cells are what it says, one per step. A cell holding nothing is a step where that track is silent.

**Tracks are their own length.** A four-cell track and a six-cell track run side by side, each wrapping at its own end. That is where a cross-rhythm comes from, and it costs nothing to allow, because a step is read with one modulo either way.

**A crossed cell is said twice.** Once as the node's own `sequence_stepped(track, step, name)` signal, which **On Sequence Step** connects to. And once to the GROUP named after the track: every node in it is asked to play that name. Both are the engine's own plumbing, and a project may answer either, both or neither.

**One clock, and the song wins.** When a `Music` autoload is in the tree and can report where the beat is, the grid reads its position and cannot drift from what the player hears. With no song, the grid counts its own beats from the tempo it was given. That is one branch, taken per frame, and it is what makes a browser tab that throttles frames still land on the beat.

**The head lives on the object.** `Play Sequence` adds a play head under the node the row runs on. A second Play Sequence on the same object replaces the head rather than starting a second one over the top of it, because two patterns on one object is two patterns nobody asked for.

**A dropped frame does not swallow a beat.** A frame long enough to cross three steps says all three, in the order it crossed them.

**It parks.** Stopping the sequence stops the head processing entirely. Where it stopped is kept, so a Jump To Sequence Step still means something afterwards.

---

## Setup

**1. Make a grid.** In the FileSystem dock, create a new resource of type **SequenceResource** and save it, for example `res://sequences/arena_lights.tres`. Set its tempo and how many steps a bar holds: 16 is a sixteenth-note grid, 4 is one step a beat.

**2. Add tracks.** The `tracks` array holds one dictionary per track: a `name` and its `cells`.

```
bpm            120
steps_per_bar  16
tracks
  { "name": "lights",   "cells": ["pulse", "", "", "", "pulse", "", "", ""] }
  { "name": "confetti", "cells": ["burst", "", "", "", "", ""] }
```

The lights track wraps every 8 steps and the confetti track every 6, so the two drift against each other and the pattern takes 24 steps to come back around.

**3. Choose who listens.** Put the nodes a track speaks to in a group with the track's name:

```
On Ready
  -> ArenaLight: add to group  "lights"
```

Every node in that group is asked to play the name in the cell, which is the same call a moment file makes. A Juice behaviour already answers it, so a lights track of Juice nodes needs nothing written for it.

**4. Declare the signal if the sheet is going to answer.** **On Sequence Step** connects to a plain signal the sheet declares for itself. Add a signal block saying `sequence_stepped(track, step, name)` on the node the sequence plays on, and both halves are ordinary Godot.

**5. Play it.**

```
On Arena Started
  -> Arena | Sequencer: Play Sequence  "res://sequences/arena_lights.tres", 0.0

On Sequence Step
  Condition: track  =  "confetti"
    -> Confetti: emit a burst
```

A tempo of 0 means the tempo the file was saved with. A song playing beside it wins over both.

---

## The sequence file

| Property | Type | Default | Range | What it does |
|---|---|---|---|---|
| `bpm` | float | `120.0` | 20 - 300, or greater | How fast the grid runs when nothing else says. The Play Sequence row can hand over another, and a Music track playing beside it overrides both. |
| `steps_per_bar` | int | `16` | 1 - 64, or greater | How many steps one bar is divided into. 16 is a sixteenth-note grid, 4 is one step a beat. |
| `tracks` | Array[Dictionary] | empty | - | The tracks, in order. Each is `{"name": "lights", "cells": ["pulse", "", "pulse", ""]}`. The name is the group the track speaks to; a cell holding nothing is a step where that track is silent. |

A bar is counted in four beats, so **steps per beat** is `steps_per_bar / 4`. At `steps_per_bar` 16 and 120 bpm, that is eight steps a second. The whole grid comes back around after its longest track's length, because each track wraps at its own.

---

## ACE reference

All rows live in the **Sequencer** category and are read on the node the grid is playing on.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Play Sequence | `sequence` (sequence file, empty), `bpm` (float, `0.0`) | Starts stepping a grid of cells on this object: a track per thing that can fire, a step per beat subdivision, and a name in the cells that should. Every cell the head crosses is said twice - as this node's `sequence_stepped` signal, which On Sequence Step answers, and to the group the TRACK is named after. With a Music autoload in the tree the grid runs on the SONG's beat; without one it counts its own from the tempo here. A tempo of 0 means the one the file was saved with. |
| Stop Sequence | (none) | Stops the grid on this object and PARKS the head: it processes nothing at all until it is played again, which is the whole of its cost at rest. Where it stopped is kept, so Jump To Sequence Step still means something afterwards. |
| Set Sequence Tempo | `bpm` (float, `120.0`) | Changes the tempo the head counts at without restarting the grid - the row a difficulty ramp or a boss phase uses. Ignored while a song is playing, because the song is the clock then. |
| Jump To Sequence Step | `step` (int, `0`) | Moves the head to a step. The step named is the NEXT one to be said out loud, so jumping to 0 starts the pattern again from its beginning - the fill, the drop, the second half of the bar. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Sequence Is Playing | (none) | True while a grid is being stepped on this object - the guard before starting a second one over the top of the first. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Current Sequence Step | (none) | int | Which step the head last said out loud, counted from 0, and -1 before it has said any. What a grid drawn on the HUD reads to know which column to light. |

### Triggers

| Trigger | Carries | Fires when |
| --- | --- | --- |
| On Sequence Step | `track` (String), `step` (int), `name` (String) | The head crosses a cell that has something in it. The signal is one the sheet declares for itself - add a signal block saying `sequence_stepped(track, step, name)` - so a rhythm becomes something the game answers row by row rather than with a counter and a modulo. |

### What a track's group members are asked

Every node in the group named after the track is asked to play the cell's name at full strength. The call is looked for by method rather than by class, so nothing names anything: a node with a `play_moment` method answers first, and a node with a `moment` method answers next. A Juice behaviour already carries the second, which is why a lights track of Juice nodes plays its cells with nothing written for it. A node with neither is skipped in silence.

---

## Use cases

Each example plays the grid on the named node. A sheet that answers On Sequence Step declares a `sequence_stepped(track, step, name)` signal on that node.

### 1. Lights pulsing on the beat

The whole point of the pack in four cells and one group.

```
On Ready
  -> ArenaLight: add to group  "lights"

On Arena Started
  -> Arena | Sequencer: Play Sequence  "res://sequences/arena_lights.tres", 0.0
```

With `{"name": "lights", "cells": ["pulse", "", "pulse", ""]}` in the file, every light in the group plays its `pulse` moment on steps 0 and 2 of every four. Nothing holds a reference to a light.

### 2. Answer the grid in the sheet instead

When the reaction is game logic rather than a moment on a node, connect the signal.

```
On Sequence Step
  Condition: track  =  "spawn"
    -> Enemies: spawn one at the marker named  name
```

The cell's name is the marker, so the pattern of where enemies come from is a row of cells rather than a chain of events.

### 3. A cross-rhythm nobody had to write down

Two tracks of different lengths run against each other because a step wraps per track.

```
tracks
  { "name": "kick",  "cells": ["hit", "", "", ""] }
  { "name": "chime", "cells": ["ring", "", "", "", "", ""] }
```

The kick lands every 4 steps and the chime every 6, so the two coincide once every 12 and the pattern reads as composed rather than looped.

### 4. Boss phases as separate grids

Switching a phase is switching which file the head is stepping.

```
Boss: On phase changed
  Condition: Boss.phase  =  2
    -> Boss | Sequencer: Play Sequence  "res://sequences/boss_phase_2.tres", 0.0
  Else
    -> Boss | Sequencer: Play Sequence  "res://sequences/boss_phase_1.tres", 0.0
```

A second Play Sequence on the same object replaces the head rather than layering, so the old phase's pattern stops the instant the new one starts.

### 5. A difficulty ramp that speeds the pattern up

Set Sequence Tempo changes the count without restarting the grid, so the pattern keeps its place.

```
On Wave Cleared
  -> Arena | Sequencer: Set Sequence Tempo  120 + Game.wave * 8
```

Restarting instead would put the head back at the top of the bar, which is exactly the wrong feeling at the moment a wave ends.

### 6. Drop into the second half of the bar

Jump To Sequence Step names the NEXT step to be said, so a fill is one row.

```
On Drop
  -> Arena | Sequencer: Jump To Sequence Step  8
```

At 16 steps a bar, step 8 is the halfway point. The head carries on from there at the same tempo.

### 7. Restart the pattern from the top

Jumping to 0 is the restart, and it does not need a stop and a play.

```
On Chorus Started
  -> Arena | Sequencer: Jump To Sequence Step  0
```

### 8. Do not start a second grid over the first

The guard that keeps one head on one object.

```
On Arena Started
  Condition: Arena | Sequencer: Sequence Is Playing  (inverted)
    -> Arena | Sequencer: Play Sequence  "res://sequences/arena_lights.tres", 0.0
```

Play Sequence would replace the head anyway, so this is for when replacing it is the thing you want to avoid.

### 9. A step grid drawn on the HUD

Current Sequence Step is which column to light.

```
Every tick
  Condition: Arena | Sequencer: Sequence Is Playing
    -> StepGrid: highlight column  Arena | Sequencer: Current Sequence Step  mod 16
```

It answers -1 before the head has said any step, which is what a grid should draw as "nothing lit yet".

### 10. Rhythm-game notes as cells

A note track, judged in the sheet against the input.

```
On Sequence Step
  Condition: track  =  "notes"
    -> Lane: spawn a note of type  name

On Note Pressed
  Condition: Lane: a note is inside the window
    -> Score: add  100
  Else
    -> Combo: break
```

With a song playing, the head reads the song's own beat position, so the notes cannot drift from what the player hears.

### 11. Ambient life in a level

Three tracks of different lengths, and the level never sounds quite the same twice.

```
tracks
  { "name": "machines", "cells": ["clank", "", "", "", "", "", ""] }
  { "name": "neon",     "cells": ["buzz", "", ""] }
  { "name": "drips",    "cells": ["drip", "", "", "", ""] }
```

7, 3 and 5 steps: the three come back into line every 105 steps, which is long enough that a player never hears the loop.

### 12. Stop the grid when the room empties

A stopped head processes nothing, so this is the whole of the cleanup.

```
On Room Left
  -> Arena | Sequencer: Stop Sequence
```

Playing again later starts the grid from the top, so a room that should resume where it left off has to write the step down first and jump back to it.

### 13. Pause the pattern with the game

Stop and play again is the pause, and the jump is what restores the place.

```
On Game Paused
  -> Game: set  resume_step  to  Arena | Sequencer: Current Sequence Step
  -> Arena | Sequencer: Stop Sequence

On Game Resumed
  -> Arena | Sequencer: Play Sequence  "res://sequences/arena_lights.tres", 0.0
  -> Arena | Sequencer: Jump To Sequence Step  Game.resume_step + 1
```

Write the step down BEFORE stopping and jump AFTER playing. Play Sequence starts the grid from the beginning, so a jump that runs before it would be undone.

### 14. A metronome for a tutorial drill

One track, one cell per beat, at a tempo the difficulty sets.

```
On Drill Started
  -> Drill | Sequencer: Play Sequence  "res://sequences/metronome.tres", 60 + Game.drill_level * 10

On Sequence Step
  Condition: track  =  "click"
    -> Audio: play "click"
    -> DrillWindow: open for 0.2 seconds
```

At `steps_per_bar` 4 the grid is one step a beat, which is exactly a metronome.

### 15. Two objects, two grids, one song

Each object carries its own head, and both read the same clock.

```
On Show Started
  -> Stage | Sequencer: Play Sequence  "res://sequences/stage_lights.tres", 0.0
  -> Crowd | Sequencer: Play Sequence  "res://sequences/crowd_waves.tres", 0.0
```

With a Music autoload playing, both heads read the song's beat position, so they stay in time with each other for the whole track without either one being the master.

### 16. Telegraph now, fire later

Two tracks offset by a step is a warning and a hit.

```
tracks
  { "name": "telegraph", "cells": ["warn", "", "", "", "warn", "", "", ""] }
  { "name": "hazard",    "cells": ["", "", "fire", "", "", "", "fire", ""] }
```

The warning lands two steps before the hazard, and moving that relationship is moving a cell rather than editing a delay.

### 17. A grid that reacts to what the player did

Cells are read at the moment they are crossed, so a jump can steer the pattern.

```
On Sequence Step
  Condition: track  =  "chorus"
  Condition: Player.combo  >  20
    -> Arena | Sequencer: Jump To Sequence Step  32
```

Everything about the head is a row: which grid, which step, how fast, and whether it is running at all.

### Other use cases

**Puzzle games on a timer.** A grid whose cells advance a conveyor, drop a block or rotate a gear, so the whole board runs on one readable pattern instead of a pile of timers.

**Traffic and crowds.** A pedestrian track and a vehicle track of different lengths, each spawning at its own cells, giving a street that never repeats without a single random call.

**Dance and animation cues.** A cue track per character, cells naming the move, and a group per character so a whole troupe is choreographed by editing rows of cells.

**Alarm and siren states.** A slow grid for calm and a fast one for alert, swapped by one Play Sequence row, with the same track names so every listener carries on answering.

**Turn-based battle rhythm.** A grid stepped one step at a time by Jump To Sequence Step on each turn, using the pattern as a schedule rather than as a clock.

---

## Tips and common mistakes

- **On Sequence Step needs the signal declared.** It connects to a plain `sequence_stepped(track, step, name)` signal on the node the sequence plays on. Without a signal block declaring it, the trigger has nothing to connect to and the cells are still said to the groups.
- **The group is named after the TRACK, not the cell.** A cell's name is what the group members are asked to play; the track's name is who gets asked. Getting these the wrong way round is the commonest reason a track reaches nobody.
- **A group member with no matching method is skipped in silence.** Members are asked by method rather than by class, so a node that answers neither `play_moment` nor `moment` is passed over without a warning.
- **A song beside the grid wins over every tempo.** With a `Music` autoload in the tree that can report the beat, both the file's tempo and the one on the Play Sequence row are ignored, and Set Sequence Tempo does nothing. That is deliberate: a game with a song in it has exactly one clock.
- **A second Play Sequence replaces the head.** It does not layer. If you want two patterns at once on one object, put them on two nodes.
- **Jump To Sequence Step names the NEXT step.** Jumping to 0 starts the pattern again from its beginning rather than repeating the step it was on.
- **Tracks wrap at their own length, not at the longest.** That is a feature, and it is also why a track you meant to be silent for a whole bar needs its empty cells written out rather than being left short.
- **A dropped frame says every step it crossed.** A frame long enough to cross three steps fires all three, in order. If a heavy frame should skip beats rather than catch up, guard the reaction rather than the grid.
- **Play Sequence always starts at the beginning.** Stop Sequence parks the head and remembers where it was, which is what keeps Current Sequence Step and Jump To Sequence Step meaningful while it is stopped, but playing again resets the head to the top of the grid. Read the step before stopping and jump after playing if the place matters.
- **Nothing ships.** There is no house pattern and no house track name. A new sequence is empty, and the first track is the first thing you add.
