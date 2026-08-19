# Encounter Timeline

**Encounter Timeline** is the general spawn/beat timeline: combat waves, boss phases, tutorial pacing,
ambient life, street traffic. You attach the **Encounter Timeline** behavior to whatever runs the
encounter and drop an **Encounter resource** (a `.tres` you fill in the Inspector) on its slot. Each row
is a beat - *at this many seconds, spawn this many of this scene into this group* - and **Start
Encounter** plays them back on their own schedule. The behavior ticks its own clock, so there is
nothing to drive from a sheet; it fires **On Entry Spawned** per node and **On Encounter Finished**
after the last beat.

Two things stay somebody else's job on purpose. Spawning goes through an **Object Pool** when one is
there and instantiates the scene when there is not, with no dependency either way. And **Write
Encounter Report** turns the plan into plain text - the beat table, the totals, the per-30-second spawn
density - with every number derived from the data and every field it could not read listed rather than
hidden.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [The pooling seam](#the-pooling-seam)
5. [ACE reference](#ace-reference)
6. [The Encounter resource](#the-encounter-resource)
7. [The report](#the-report)
8. [Use cases](#use-cases)
9. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this pack shines

- **Combat waves** - three grunts at 0 s, two archers at 12 s, the brute at 30 s.
- **Boss phases** - adds on a schedule while the boss's own sheet does the rest.
- **Tutorial pacing** - one new thing every few seconds, so a lesson lands before the next arrives.
- **Ambient life** - a bird, then a leaf, then a distant train, looping the encounter for atmosphere.
- **Traffic** - cars entering a street on a plan instead of a random timer.
- **Horde tests** - a stress plan you can point at any scene and read the density back.
- **Cutscene beats** - props and actors appearing on cue, with the note column as the script.
- **Difficulty variants** - the same arena with three `.tres` files, chosen at load.
- **Rhythm-ish sections** where things arrive on a fixed grid of seconds.
- **Scripted patrols** that populate a level once, in order, when it opens.

## Core concepts

- **An encounter is a data asset.** An **Encounter resource** holds a name and one grid of beats.
  Planning a wave is filling a table, not nesting timers.
- **A beat is a time plus a spawn.** `at_seconds` is how far into the encounter it happens; `count` is
  how many copies of `scene_path` appear; `group_name` is the group they all join.
- **Rows can be typed in any order.** They are sorted by time as they load, so inserting a beat is
  typing a row, not renumbering a list.
- **The clock is the behavior's own.** Start Encounter rewinds it to 0 and each beat fires as its time
  arrives. One huge frame (a stall, a loading hitch) plays every beat it crossed, in order, rather than
  dropping all but the last.
- **The pack never places the spawns.** It hands you each node in On Entry Spawned; where it goes, how
  fast it moves and what it is aiming at are your rows.
- **Groups are how the rest of the game finds them.** Every copy joins its beat's group persistently,
  so a "count the enemies left" check is a group count.
- **The report is derived, never maintained.** Every line in it is computed from the beats, so it
  cannot fall out of step with the plan.

## Setup

Enable the **Encounter Timeline** pack, then create the plan: in the FileSystem dock, create a new
**Resource**, pick **EncounterResource**, fill it in, and save it as (for example)
`res://encounters/wave_3.tres`.

| Field | Example |
|-------|---------|
| Encounter Name | `Wave 3` |
| Entries | `0` / `res://enemies/grunt.tscn` / 3 / `enemies` / `opener` |
| | `12` / `res://enemies/archer.tscn` / 2 / `enemies` / `teaches cover` |
| | `30` / `res://enemies/brute.tscn` / 1 / `enemies` / `the wall` |

Add a child node to your arena, attach **EncounterTimelineBehavior**, and drag the `.tres` onto its
**Encounter** slot. Then:

```
On door closes
  -> Arena: Start Encounter

On Entry Spawned
  -> set node position = a random point in the SpawnRing

On Encounter Finished
  -> open the exit
```

Tick **Auto Start** instead if the encounter should begin the moment its scene loads.

## The pooling seam

A spawn is made by the first of these that answers:

1. **The node given to Use Object Pool Node** - a per-arena pool, or one you wrote yourself.
2. **The `ObjectPool` autoload**, if the Object Pool pack is installed and registered.
3. **Plain instantiation**, when neither is there (or when **Use Object Pool** is unticked).

The whole contract is three functions:

```gdscript
func has_pool(pool_name: String) -> bool
func create_pool(pool_name: String, scene_path: String, prewarm: int) -> void
func spawn(pool_name: String) -> Node
```

The shipped **Object Pool** has exactly those, which is why it works with no adapter and no dependency.
The timeline uses one pool per scene path, created the first time that scene is needed. A candidate
missing any of the three is ignored and the timeline instantiates as usual, so a wrong drag degrades
instead of breaking.

Pooled nodes are reused, so give a pooled scene a `reset()` function - the pool calls it on every spawn,
which is where velocity, hit points and timers go back to their starting values.

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, exactly as the rows
draw them:

- Load encounter **wave_3.tres**
- Add beat at **12**s: **2** x **res://enemies/archer.tscn** into **enemies**
- Skip to **30**s
- Write encounter report to **user://encounter_report.txt**

### Actions

| Action | Parameters | Description |
|--------|-----------|-------------|
| Load Encounter | resource (an Encounter resource) | Loads a whole plan, REPLACING whatever was loaded and rewinding the clock. Rows are sorted by time as they load. |
| Add Encounter Entry | at_seconds, scene_path, count, group_name, note | Adds one beat from a sheet, for a plan built at runtime. It lands in time order, even mid-encounter. |
| Clear Encounter | (none) | Empties the plan and rewinds everything. |
| Start Encounter | (none) | Runs the plan from the top: clock at 0, tally at 0, each beat firing as its time arrives. |
| Stop Encounter | (none) | Freezes it where it stands. Already-spawned nodes are left alone. |
| Use Object Pool Node | node | Spawns through THIS pool instead of searching for the autoload. Pass nothing to go back. |
| Skip To | seconds | Jumps the clock WITHOUT spawning what it passes - the debug action for checking a late beat. |
| Write Encounter Report | path | Saves the Encounter Report to a text file with plain file access (no editor needed). |

### Conditions

| Condition | Parameters | Description |
|-----------|-----------|-------------|
| Encounter Is Running | (none) | Whether it is playing right now - the guard against starting a second wave on top of the first. |
| Encounter Is Finished | (none) | Whether the last beat has played and it stopped itself. False after Stop Encounter cut it short. |
| Encounter Is Empty | (none) | Whether no plan is loaded at all - the check for "did the designer forget the .tres". |

### Expressions

| Expression | Returns | Description |
|-----------|---------|-------------|
| Elapsed Seconds | number | How far into the encounter the clock has run. |
| Encounter Duration | number | When the LAST beat happens (0 for an empty plan). |
| Next Entry Seconds | number | When the next beat is due (-1 when none is left). Subtract Elapsed Seconds for a countdown. |
| Entry Count | number | How many beats the plan holds. |
| Planned Spawn Count | number | How many nodes the whole plan intends to spawn. |
| Spawned Count | number | How many this run has actually spawned so far. |
| Spawns Between | number | How many spawns fall in a window of time (from included, to excluded) - the pacing primitive. |
| Entry Note At | String | The designer's note on the beat at a position, in time order. |
| Entry Seconds At | number | When the beat at a position happens (-1 out of range). |
| Encounter Name | String | The readable name written on the loaded resource. |
| Last Spawned Node | Node | The node spawned most recently - place it, aim it, hand it to another pack. |
| Last Spawned Group | String | The group the most recent spawn joined. |
| Encounter Report | String | The whole plan as plain text (see below). |

### Triggers

| Trigger | Fires with | Description |
|---------|-----------|-------------|
| On Entry Spawned | node, group_name | One node just appeared. Fires once per copy, so a count of 3 fires three times. |
| On Encounter Finished | (none) | The last beat has played. Fires exactly once per run. |

### Knobs (Inspector)

| Property | Default | Description |
|----------|---------|-------------|
| Encounter | (empty) | Optional: an EncounterResource loaded on ready. |
| Use Object Pool | on | Spawn through a pool when one answers. Untick to always instantiate. |
| Auto Start | off | Start as soon as the node is ready, instead of waiting for Start Encounter. |

## The Encounter resource

| Property | Default | Description |
|----------|---------|-------------|
| Encounter Name | "encounter" | A readable name, shown at the top of the report. |
| Entries | empty | One row per beat (below). |

| Column | Meaning |
|--------|---------|
| `at_seconds` | How far into the encounter this beat happens. Rows may be typed in any order. |
| `scene_path` | The `.tscn` to spawn. Blank means a beat that spawns nothing. |
| `count` | How many copies. 0 spawns nothing. |
| `group_name` | The group every copy joins, so the rest of your game can find them. |
| `note` | A plain-language reminder for you and for the report. Never interpreted. |

## The report

**Encounter Report** (the expression) and **Write Encounter Report** (the action) produce the same
text. It has five parts, all computed from the beats:

- a header with the encounter's name;
- the totals - beat count, planned spawns, and how long the encounter lasts;
- the beat table, one line per row, with blank cells shown as `(none)` rather than as nothing;
- **the fields it could not read**: a beat with no scene path, a scene that is not in the project, a
  count of 0, a spawn that joins no group. A clean plan says so instead.
- the spawn density per 30 seconds, which is **Spawns Between** applied bucket by bucket - so a graph
  you draw yourself with that expression agrees with the report exactly.

```
Encounter report: Ambush
Beats: 4   Planned spawns: 10   Length: 70.0 s

  at (s) | count | scene | group | note
  5.0 | 3 | res://enemies/grunt.tscn | wave1 | opener
  ...

Fields this report could not read as intended:
  beat 2 at 20.0s: no scene path - it spawns nothing

Spawn density (per 30 s):
  0-30 s: 7
  30-60 s: 2
  60-90 s: 1
```

Writing uses plain file access and never touches the editor, so a headless build can produce it.
`user://encounter_report.txt` lands in the app's user folder (the editor opens it from
**Project > Open User Data Folder**).

## Use cases

**1. A wave that starts when the door shuts.**

```
On door closes
  -> Arena: Start Encounter
```

**2. Place every spawn as it appears.**

```
On Entry Spawned
  -> set node position = SpawnPoint.position
```

**3. Open the exit when the wave is done.**

```
On Encounter Finished
  -> open the exit door
```

**4. Wait for the room to be cleared, not just for the spawning to end.**

```
On enemy died
  Condition: Arena  Encounter Is Finished
  Condition: number of nodes in group "enemies" = 0
    -> open the exit door
```

The trigger says the plan is over; the group count says the fight is.

**5. A countdown to the next wave.**

```
Every tick
  Condition: Arena  Encounter Is Running
    -> set NextLabel text = str(Arena.Next Entry Seconds() - Arena.Elapsed Seconds())
```

**6. A progress bar for the whole encounter.**

```
Every tick
  -> set WaveBar value = Arena.Elapsed Seconds() / Arena.Encounter Duration() * 100
```

**7. Do not start a second wave on top of the first.**

```
On wave button pressed
  Condition: Arena  Encounter Is Running  (inverted)
    -> Arena: Start Encounter
```

**8. Three difficulties, one arena.**

```
On level loaded
  Condition: Difficulty = "hard"
    -> Arena: Load Encounter  wave_3_hard.tres
  Else
    -> Arena: Load Encounter  wave_3.tres
  -> Arena: Start Encounter
```

**9. Scale a wave to the player's level, at runtime.**

```
On level loaded
  -> Arena: Clear Encounter
  Repeat PlayerLevel times
    -> Arena: Add Encounter Entry  loopindex * 5, "res://enemies/grunt.tscn", 2, "enemies", ""
  -> Arena: Start Encounter
```

**10. Queue reinforcements mid-fight.**

```
On boss reaches half health
  -> Arena: Add Encounter Entry  Arena.Elapsed Seconds() + 3, "res://enemies/add.tscn", 4, "enemies", "phase 2 adds"
```

A beat added ahead of the clock plays; one added behind it is treated as already passed.

**11. Cut the fight short.**

```
On boss died
  -> Arena: Stop Encounter
```

Already-spawned enemies are left alone - killing them is your business.

**12. Test a late beat without waiting.**

```
On debug key pressed
  -> Arena: Skip To  30
```

**13. Tag the spawns for the rest of the game.** Put `enemies` in the beat's group column and every
count-the-enemies check, area-of-effect sweep and minimap marker finds them with no extra rows.

**14. Different groups for different beats.** Name the first beat's group `wave1` and the last one
`boss`, and a "boss music" trigger is a group check.

**15. Reuse nodes on a long encounter.**

```
On Start of Layout
  -> ObjectPool: Create Pool  "res://enemies/grunt.tscn", "res://enemies/grunt.tscn", 8
```

With the ObjectPool autoload installed, the timeline already spawns through it - prewarming just means
the first wave never hitches.

**16. A pool per arena, not one for the game.**

```
On Start of Layout
  -> Arena: Use Object Pool Node  ArenaPool
```

**17. Save the plan out for review.**

```
On debug key pressed
  -> Arena: Write Encounter Report  "user://encounter_report.txt"
```

Open it, read the density block, and move a beat if the middle 30 seconds are empty.

### Other use cases

**Ambient street.** A short encounter of pedestrians and a bus, restarted from On Encounter Finished, gives a street that breathes without a single random timer.

**Tutorial director.** One beat per lesson, with the note column as the script and an empty scene path where the beat only needs to fire your own trigger.

**Boss phase adds.** A second timeline beside the boss, started and stopped by phase transitions, so the adds are data the designer can retune without opening the boss's sheet.

**Rhythm section.** Beats on an even grid of seconds and a `beat` group make a lane of obstacles that lines up with a track, and the report's density block shows the shape of the level at a glance.

**Stress test scene.** Point a test encounter at any scene, set the counts high, run it with pooling on and off, and compare Spawned Count against Planned Spawn Count to see what the frame budget can take.

## Tips and common mistakes

- **A beat with a blank scene path spawns nothing.** That is legal - it is how you get a beat that only
  fires a trigger - but the report calls it out so it is never an accident.
- **A scene that is not in the project is skipped quietly**, and named in the report. Check the report
  first when a wave comes up short.
- **`count` of 0 spawns nothing.** A fresh row's count is 0 until you type a number.
- **On Entry Spawned fires once per copy**, not once per beat. A count of 3 fires three times.
- **Start Encounter rewinds.** It is a restart, not a resume; Stop Encounter then Start Encounter plays
  the whole plan again. Guard the row with Encounter Is Running.
- **Skip To does not spawn what it passes.** It is for testing and for a director that fast-forwards,
  not for skipping ahead in a live fight.
- **Encounter Is Finished is not "the room is clear".** It means the plan has played. Pair it with a
  group count when you mean "everything is dead".
- **Give pooled scenes a `reset()`.** A reused node keeps whatever state it had; `reset()` is where the
  pool lets it start over.
- **Spawns are parented to the running scene**, not to the timeline, so a moving spawner never drags its
  wave around by its transform.
