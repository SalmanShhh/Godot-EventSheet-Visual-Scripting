# Phase Cycle - One Named Clock The Whole Game Shares

Phase Cycle is a Godot EventSheets autoload pack that turns "what part of the cycle are we in?" into a single value every system can read. You call **Cycle Phases** once with a comma-separated list of names and a length in seconds - `"day,night"` at 60, or `"spring,summer,autumn,winter"` at 120 - and from then on the autoload keeps its own clock. It rolls to the next name when the time is up, wraps back to the first at the end of the list, and fires **On Phase Changed** at every roll with the phase you left and the phase you entered. **Phase Is** is the condition that branches on the current phase, **Current Phase** reads its name, **Phase Progress** runs 0 to 1 through it, and **Stop Cycle** freezes the whole thing.

Because it ships as the `Phases` autoload, there is no node to place, no reference to pass, and no chance of two systems disagreeing about whether it is night. It ticks itself: nothing in your sheets has to feed it a delta.

---

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Reading it from expressions](#reading-it-from-expressions)
6. [Use cases](#use-cases)
7. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Day and night.** The obvious one: two phases, a light that fades between them, and enemies that only appear in one.
- **Seasons.** Four phases driving crop growth, weather, and the colour of the ground.
- **Wave-based games.** `"build,fight"` on a loop gives a tower defense its whole rhythm with one row.
- **Shop-then-run loops.** Roguelites live on `"shop,run"`; the cycle owns the switch and everything else just listens.
- **Tides and hazards.** A `"low,rising,high,falling"` cycle turns a level into a moving puzzle.
- **Match periods.** Halves, quarters, rounds, overtime - a named list with a fixed length each.
- **Rotating shop stock.** Refresh the wares on every On Phase Changed and the timing is free.
- **Boss arena states.** `"open,shielded,vulnerable"` on a timer gives a fight structure without a state machine per system.
- **Ambient audio.** Cross-fade tracks on phase change and let Phase Progress ride the volume.
- **Weather fronts.** `"clear,cloudy,rain,storm"` marching in order is a whole weather system.
- **Idle-game production periods.** Different rates in different phases give an idle loop something to plan around.
- **Timed events and holidays.** A long cycle of themed phases can drive limited-time content without a server.

---

## Core concepts

**One cycle, and it belongs to the game.** Phase Cycle is an autoload, so there is exactly one - the `Phases` singleton. Every system asks it the same question and gets the same answer. If you need two independent cycles (a day/night AND a season), run the slower one from the faster one's roll rather than trying to have two of this pack.

**Phases are names you invent.** The list is one string with commas: `"day,night"`, `"spring,summer,autumn,winter"`, `"build,fight"`. Spaces around a name are trimmed, and empty entries are skipped, so `"day, night"` is fine. There is nothing to declare and no fixed set. A name is matched exactly, so `"Day"` and `"day"` are different phases.

**Each phase lasts the same number of seconds.** `seconds_each` applies to every phase in the list. If you want an uneven cycle - a long day and a short night - repeat the name: `"day,day,day,night"` at 30 seconds gives a 90 second day and a 30 second night with no extra machinery.

**It ticks itself.** The autoload runs its own per-frame clock. This is the whole reason it is an autoload rather than a behavior: you call Cycle Phases once at startup and never think about it again. There is no "advance the clock" row to remember, and no way for one scene to forget to drive it.

**Cycle Phases announces the first phase immediately.** Starting the cycle fires **On Phase Changed** right away with the first name (and nothing as the previous phase). That is deliberate: every listener sets itself up correctly on the first frame instead of sitting in a wrong state until the first roll. Your "turn the lights on for day" row runs on startup exactly as it does at every later sunrise.

**On Phase Changed carries both sides.** The trigger hands you `previous` and `next`, so you can react to a destination ("it is now night"), to a departure ("we just left the build phase"), or to a specific edge ("specifically day into night"). This is the natural home for one-shot effects: swap the music, refresh the shop, spawn the wave.

**Phase Is is the branch.** True while the cycle is on the phase you name. It is how you gate spawning, shop access, or damage without anyone tracking their own copy of the time.

**Phase Progress is 0 to 1, and it wraps.** It runs from 0 at the start of the current phase to 1 at its end, then restarts at 0 for the next one. Feed it straight into a sun dial's rotation, a light colour blend, a countdown bar, or anything else that should move smoothly through the phase rather than snap at its edges.

**A big frame rolls through everything it crossed.** If the game stalls (a load, a breakpoint, a slow first frame) and a single tick is longer than a whole phase, the clock rolls through every phase in that gap and fires On Phase Changed for each of them. Nothing is silently skipped, so a wave counter driven off the trigger stays honest.

**Stop Cycle freezes, it does not reset.** The current phase and its progress keep their values - Phase Is and Phase Progress still read them - and only the clock stops. Call Cycle Phases again to start over from the top.

---

## Setup

Nothing to install per project beyond the pack. Once the Phase Cycle pack is in `eventsheet_addons/`, it registers itself as the `Phases` autoload, so every sheet can call it by name with no node to drop and no reference to pass around.

Start the cycle once, then listen:

```
On Start of Layout   (your game manager sheet, once)
  -> Phases: Cycle Phases  "day,night", 60

On Phase Changed
  Condition: next  ==  "night"
    -> WorldLight: fade to night colour
    -> Spawner: start spawning ghosts
  Condition: next  ==  "day"
    -> WorldLight: fade to day colour
    -> Spawner: stop spawning ghosts

On Every Tick
  -> SunDial: set rotation to  Phases.Phase Progress() * 360
```

That is a complete day/night system. The cycle announces `"day"` on the first frame, so the lights are correct before the player sees anything, and every sixty seconds after that the world changes on its own.

---

## ACE reference

On the canvas these verbs read as styled sentences - parameter values in **bold**, exactly as the rows draw them:

- Cycle phases **day,night**, **60** s each

All rows live in the **Phase Cycle** category and are called on the `Phases` autoload.

### Actions

| Action | Parameters | What it does |
|---|---|---|
| Cycle Phases | `phases` (String), `seconds_each` (float) | Starts (or restarts) the cycle from a comma-separated list of names, each lasting `seconds_each` seconds. Begins on the first name and fires On Phase Changed for it immediately. |
| Stop Cycle | - | Freezes the clock where it stands. The current phase and its progress keep their values; only time stops. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Phase Is | `phase_name` (String) | True while the cycle is on the named phase. Names are matched exactly, so keep the spelling identical to the list you passed Cycle Phases. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Current Phase | - | String | The name of the phase the cycle is on right now, or empty text before Cycle Phases runs. Print it straight into a HUD label. |
| Phase Progress | - | float | How far through the current phase the cycle is, 0 at its start and 1 at its end. Drives dials, fades, and bars. |
| Phases Count | - | int | How many phases the cycle holds - for a "day 3 of 4" readout or for stepping a dial in even slices. |

### Triggers

| Trigger | Parameters | Fires when |
|---|---|---|
| On Phase Changed | `previous` (String), `next` (String) | The cycle rolls to the next phase, and once at startup with an empty `previous` and the first phase as `next`. A single very long frame fires it once per phase it crossed. |

---

## Reading it from expressions

Type `Phases` in any ƒx field, or open the ƒx **Expressions dictionary**, and the autoload's value verbs
list as ready-to-insert chains:

- `Phases.current_phase()` inserts the **Current Phase** entry
- `Phases.phase_progress()` inserts the **Phase Progress** entry
- `Phases.phases_count()` inserts the **Phases Count** entry

Because the pack is an autoload, these work from any sheet in any scene with nothing to wire up first.

---

## Use cases

Each example calls the `Phases` autoload. Start the cycle once; everything else just listens.

### 1. A day and night cycle

The whole system is one start row and one trigger.

```
On Start of Layout
  -> Phases: Cycle Phases  "day,night", 120

On Phase Changed
  -> WorldLight: fade to the colour named  next
```

Naming your light presets after your phases means one row covers every future phase you add.

### 2. Enemies that only come out at night

Phase Is is the gate; nothing else needs to know the time.

```
Every 2 seconds
  Condition: Phases  Phase Is  "night"
    -> Spawner: spawn a ghost
```

Change the phase length and the spawning schedule follows automatically.

### 3. A sun that moves across the sky

Phase Progress is a smooth 0 to 1, which is exactly what a dial wants.

```
On Every Tick
  Condition: Phases  Phase Is  "day"
    -> Sun: set position along the arc at  Phases.Phase Progress()
```

At the end of the day the progress hits 1, the phase rolls, and the sun starts over.

### 4. Tower defense build and fight waves

Two phases give a whole game loop its rhythm.

```
On Start of Layout
  -> Phases: Cycle Phases  "build,fight", 30

On Phase Changed
  Condition: next  ==  "fight"
    -> Spawner: release the next wave
    -> UI: hide the build menu
  Condition: next  ==  "build"
    -> UI: show the build menu
```

Because the roll happens on its own, the player always gets exactly thirty seconds to build.

### 5. A countdown bar for the current phase

One expression drives the bar; the label reads the phase name.

```
On Every Tick
  -> HUD Kit: set bar "PhaseBar" fill to  1.0 - Phases.Phase Progress()
  -> HUD Kit: set label "PhaseName" text to  Phases.Current Phase()
```

The bar empties through each phase and refills at every roll with no reset logic.

### 6. Seasons that change crop growth

Four phases and one multiplier lookup.

```
On Start of Layout
  -> Phases: Cycle Phases  "spring,summer,autumn,winter", 300

On Every Tick
  Condition: Phases  Phase Is  "winter"
    -> Farm: set growth_rate = 0.0
  Condition: (else)
    -> Farm: set growth_rate = 1.0
```

Winter stops the farm without anyone tracking a calendar.

### 7. An uneven cycle - a long day, a short night

Repeat a name to give it more time. No extra feature needed.

```
On Start of Layout
  -> Phases: Cycle Phases  "day,day,day,night", 30
```

That is a 90 second day followed by a 30 second night. On Phase Changed fires between the repeats too, which is harmless - or useful, if you want a "midday" beat.

### 8. Cross-fading ambient music

Music swaps belong on the edge, not in a per-frame check.

```
On Phase Changed
  Condition: next  ==  "night"
    -> Audio: cross-fade to  "res://music/night.ogg"
  Condition: next  ==  "day"
    -> Audio: cross-fade to  "res://music/day.ogg"
```

Because the cycle announces the first phase at startup, the correct track starts playing immediately.

### 9. A shop that restocks each cycle

Anything periodic can hang off the trigger.

```
On Phase Changed
  Condition: next  ==  "day"
    -> Shop: roll new stock from the loot table
    -> Toast: show "The merchant restocked."
```

The shop's schedule and the world's schedule are the same clock, so they can never drift apart.

### 10. Pausing the cycle during a boss fight

Stop Cycle freezes time without losing where you were.

```
On Boss Started
  -> Phases: Stop Cycle

On Boss Defeated
  -> Phases: Cycle Phases  "day,night", 120
```

Restarting begins the cycle fresh from the first phase - if you need to resume mid-phase instead, save the phase and progress before stopping and restore them yourself.

### 11. Reacting to a specific transition

`previous` lets you name the edge, not just the destination.

```
On Phase Changed
  Condition: previous  ==  "day"
  Condition: next  ==  "night"
    -> Juice: play the sunset sting
    -> Villagers: go indoors
```

"Sunset" is an edge, and this is how you say it.

### 12. A "day 3 of 4" readout

Phases Count turns the list into a denominator.

```
On Every Tick
  -> HUD Kit: set label "Season" text to  Phases.Current Phase() + " (" + str(Phases.Phases Count()) + " seasons)"
```

Add a fifth season to the list and the label updates itself.

### 13. Counting how many full cycles have passed

The wrap back to the first phase is your cycle counter.

```
On Phase Changed
  Condition: next  ==  "day"
  Condition: previous  !=  ""
    -> Game: add 1 to days_survived
    -> HUD Kit: set label "Days" text to  "Day " + str(Game.days_survived)
```

Checking that `previous` is not empty skips the startup announcement so day one is not counted twice.

### 14. Different production rates per phase

An idle loop that rewards planning around the clock.

```
Every 1 seconds
  Condition: Phases  Phase Is  "day"
    -> CurrencyLedger: Add  "solar", 10
  Condition: Phases  Phase Is  "night"
    -> CurrencyLedger: Add  "solar", 1
```

The player learns the rhythm and starts timing upgrades to it.

### 15. A tide that rises and falls

Four phases plus Phase Progress give you smooth movement and hard states together.

```
On Start of Layout
  -> Phases: Cycle Phases  "low,rising,high,falling", 45

On Every Tick
  Condition: Phases  Phase Is  "rising"
    -> Water: set height to  lerp(low_mark, high_mark, Phases.Phase Progress())
  Condition: Phases  Phase Is  "falling"
    -> Water: set height to  lerp(high_mark, low_mark, Phases.Phase Progress())
```

The `low` and `high` phases are the flat stretches where the player can act; the sloped phases move.

### 16. A weather front that marches in order

Named phases make the sequence readable at a glance.

```
On Start of Layout
  -> Phases: Cycle Phases  "clear,cloudy,rain,storm,cloudy", 90

On Phase Changed
  -> Weather: switch particles to  next
  Condition: next  ==  "storm"
    -> Juice: Pulse Vignette  0.4, 1.0
```

Repeating `"cloudy"` on the way back down makes the weather ease out instead of snapping from storm to clear.

### 17. Nesting a slow cycle inside a fast one

One pack, two rhythms: advance your own counter on the fast cycle's wrap.

```
On Phase Changed
  Condition: next  ==  "day"
  Condition: previous  !=  ""
    -> Game: add 1 to day_number
  Condition: Game.day_number  >=  30
    -> Game: set day_number = 0
    -> Game: advance to the next month
```

The autoload owns the fast clock; a couple of variables give you the slow one on top of it.

### Other use cases

**Themed limited-time events.** A long cycle of themed phases - `"normal,normal,normal,festival"` at fifteen minutes each - rotates event content with no server and no calendar code.

**Rotating boss vulnerability windows.** Cycle `"shielded,vulnerable"` at a few seconds each and gate damage behind Phase Is so the fight has a readable rhythm the player can learn.

**Traffic and crowd density.** Read Current Phase in your spawner to make streets busy at `"day"`, empty at `"night"`, and gridlocked at `"rush"`.

**Turn-based match periods.** Name the phases after your rounds and let Phase Progress drive the round timer, so the clock and the round state are the same value.

**Save-friendly world time.** The pack ships the standard save seam, so the Save System stores the phase, its progress, and whether the cycle is running, and a loaded game resumes mid-afternoon exactly where it left off.

---

## Tips and common mistakes

- **Call Cycle Phases once, at startup.** It restarts from the first phase every time it runs, so calling it in a per-frame row pins the cycle to phase one forever. If nothing ever advances, that is the first thing to check.
- **The autoload ticks itself - do not try to drive it.** There is no "advance" verb, on purpose. The pack has its own per-frame clock, which is why a scene reload or a new level cannot leave it stalled.
- **Names are matched exactly.** `"night"`, `"Night"`, and `" night"` are three different phases. Spaces around a name in the list are trimmed for you, but the spelling and case in Phase Is must match the list.
- **Every phase has the same length.** `seconds_each` applies to all of them. Repeat a name in the list to give it a longer turn - `"day,day,night"` is a two-thirds day - rather than looking for a per-phase duration that does not exist.
- **The first On Phase Changed arrives at startup with an empty `previous`.** That is what makes your listeners correct on the first frame. If you are counting completed cycles, skip that one by checking that `previous` is not empty.
- **A zero or negative length does not start the cycle.** `seconds_each` must be above zero, otherwise there is nothing to count down and the cycle stays stopped. If Current Phase is empty right after Cycle Phases, check the number you passed.
- **Put one-shot reactions in On Phase Changed, continuous ones behind Phase Is.** Swapping the music, spawning a wave, and restocking a shop are edges. Spawning enemies at a rate, tinting a light, and gating damage are states. Mixing them up gives you either a stuttering effect or one that never repeats.
- **Phase Progress is per-phase, not per-cycle.** It resets to 0 at every roll. For a whole-cycle position, combine it with the phase index yourself - progress within the current phase plus how many phases are behind it.
- **Stop Cycle freezes; it does not reset.** Phase Is and Phase Progress keep answering with the frozen values, which is usually what you want for a pause. Restarting with Cycle Phases begins from the first phase again.
- **One cycle, one game.** Because it is an autoload, every scene shares it. That is the feature - the HUD, the spawner, and the lighting cannot disagree about whether it is night - but it also means a second, independent cycle needs to be built on top of this one's trigger, not by adding a second copy of the pack.
