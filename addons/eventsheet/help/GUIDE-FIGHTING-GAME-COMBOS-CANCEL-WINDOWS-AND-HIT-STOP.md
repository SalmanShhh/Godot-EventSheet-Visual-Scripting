# Fighting-Game Combos, Cancel Windows And Hit-Stop

Three inputs in a row play the uppercut. The uppercut can be cancelled into the next move, but only in
the middle of it. When the uppercut connects, the whole game freezes for a couple of frames so the blow
lands with weight. That is a fighting game, and it is also a beat-em-up, a character action game, and
the attack half of most action RPGs.

All three are short pieces of code that everybody writes the same way, and all three are rows here.
This guide is the whole loop end to end: collect the inputs, decide which move they spell, play its
animation, allow the follow-up in a window, freeze on the hit, and forgive a press that came a few
frames too early.

## Table of Contents

1. [The four pieces](#the-four-pieces)
2. [Collecting the inputs](#collecting-the-inputs)
3. [The move list as a table](#the-move-list-as-a-table)
4. [Cancel windows](#cancel-windows)
5. [Hit-stop](#hit-stop)
6. [Input buffering](#input-buffering)
7. [Animation-driven events](#animation-driven-events)
8. [Opening a script that already does this](#opening-a-script-that-already-does-this)
9. [Tips and common mistakes](#tips-and-common-mistakes)

The playable version of everything below is `demo/showcase/combo_fighter/` - three combos, a cancel
window, a buffered punch, and a hit frame the uppercut's own animation calls:

![The Combo Fighter showcase mid-uppercut, its HUD counting one hit frame](images/combo-fighter-showcase.png)

## The four pieces

| The piece | What it means | Where it lives |
| --- | --- | --- |
| The detector | Recent inputs collect into a rolling buffer, and a finished sequence fires a trigger | the **Combo Box** behaviour |
| The cancel window | A slice of one animation that another move may interrupt | **Animation ▸ Is Between** |
| Hit-stop | The whole game frozen for a few frames on a connecting blow | **Juice ▸ Hitstop** |
| The buffer | A press made slightly too early, remembered until it becomes legal | **Timed Input ▸ Buffer Input** |

None of them needs the others. A platformer wants the input buffer and nothing else; a puzzle game
wants the detector for a cheat code. They are listed together because a fighting game wants all four,
and because they are usually written together and usually written badly together.

## Collecting the inputs

Combo Box is a headless detector: it reads no hardware itself, so it works with a keyboard, a pad, a
touchscreen or a replay file without knowing the difference. You push a named **token** into it every
time the player presses something, and it tells you when the tokens spell a move.

```
On Ready
  -> ComboBox: Register Combo  "uppercut", "punch,punch,kick", 0.5
  -> ComboBox: Register Combo  "sweep", "kick,kick", 0.5

Keyboard On "punch" pressed
  -> ComboBox: Press Input  "punch"

Keyboard On "kick" pressed
  -> ComboBox: Press Input  "kick"
```

The `0.5` is the **window**: half a second is the longest gap allowed between two inputs of that move.
Miss it and the buffer empties, which is why a slow player never accidentally finishes a move they
started ten seconds ago.

Matching is tolerant by default - a stray neutral input between the punches does not break the motion,
which is what real stick input looks like. Turn that off per move with **Set Combo Strict** when the
sequence has to be exact, like a combination lock.

## The move list as a table

The move list is the character. Twenty moves means twenty lines of "this sequence plays this
animation", and writing them as twenty events is twenty chances to write it slightly differently.

**Set Animation For Combo** is that line as one row:

```
On Ready
  -> ComboBox: Register Combo  "uppercut", "punch,punch,kick", 0.5
  -> ComboBox: Set Animation For Combo  "uppercut", $AnimationPlayer, "uppercut"
  -> ComboBox: Register Combo  "sweep", "kick,kick", 0.5
  -> ComboBox: Set Animation For Combo  "sweep", $AnimationPlayer, "sweep"
```

**On Combo Matched** still fires for everything the move does beyond its animation - damage, sound, the
hit spark, the camera shake - so nothing is taken away by wiring the clip here:

```
On Combo Matched
  -> Hitstop  0.05 s
  -> Play Sound  "swing"
```

A combo wired to no animation plays nothing and still fires its trigger; a combo whose player has left
the tree is skipped rather than erroring. The pack's job is detecting, and a missing clip must never
stop a move coming out.

## Cancel windows

A cancel window is a slice of one animation in which another move is allowed to interrupt it. It is
what makes a combo feel like a combo rather than a queue: press too early and nothing comes out, press
in the window and the next move flows out of the last one.

**Animation ▸ Is Between** is that slice as one question:

```
On punch pressed
  Condition: Is Between  0.3 s and 0.6 s of "uppercut"
    -> Play Animation  "punch"
```

The clip name is part of the question on purpose. `current_animation_position` alone says how far into
*whatever is playing* the play head is, which is true of the idle clip too - and a cancel window that
also opens during idle is not a window at all.

Two expressions go with it: **Animation Position** (seconds into the clip) and **Animation Length**
(how long the clip is). Divide one by the other for a 0-to-1 progress, which is what a window drawn on
screen for a training mode wants.

## Hit-stop

Hit-stop is the couple of frames the whole game holds still when a blow connects. It costs nothing, it
is three lines, and it is most of why a hit feels like a hit.

**Juice ▸ Hitstop** is the row:

```
On hit landed
  -> Hitstop  0.05 s at scale 0.1
```

It sets the engine's time scale down, waits in REAL time, and puts the time scale back. The real-time
wait is the part everybody gets wrong: a wait measured on the clock you just stopped never ends, and
the game freezes forever. The row's wait ignores the time scale, so it always lifts.

Hit-stop is global by design - it freezes both fighters, the camera, the particles, everything. When
only ONE character should hold still, that is a different row: **Animation ▸ Pause For**, which stops
one animation player for a moment while the rest of the game runs on.

```
On hit landed
  -> Pause For  0.08 s     (on the attacker's AnimationPlayer)
  -> Pause For  0.08 s     (on the defender's AnimationPlayer)
```

For the version with state of its own - a decaying freeze, a slow-motion it cooperates with, an On
Hitstop Finished trigger - attach the **Juice** behaviour instead. These rows are the one-liner; the
pack is the whole answer.

## Input buffering

The player pressed punch four frames before the last move ended. Without a buffer, nothing happens and
it feels like the game dropped the input. With one, the punch comes out the instant it becomes legal.

Three rows, counted in FRAMES because that is the unit the genre thinks in:

```
Keyboard On "punch" pressed
  -> Buffer Input  punch_input for 6 frames

Every Physics Tick
  Condition: Can Act
  Condition: Is Input Buffered  punch_input
    -> Consume Buffered Input  punch_input
    -> ComboBox: Press Input  "punch"
```

Ask and consume in the same breath. The memory stays fresh for the whole six frames, so an event that
asks without consuming fires on every one of them - six punches from one press.

Name the variable after the input it remembers (`punch_input`, `jump_input`) and the row reads back
with that name in it. The same three rows are the platformer's jump buffer, one of the two forgiveness
tricks that make a jump feel good - the other being coyote time, which is a cooldown.

## Animation-driven events

The hitbox should open on the frame the fist is out, not on a timer that guesses when that is. There
are two ways to say so, and which one you want depends on who owns the timing.

**The programmer owns it.** On Animation Frame fires when a sprite reaches one frame of one clip:

```
On Animation Frame  "punch" frame 3
  -> Set node enabled  $Hitbox = true
```

**The animator owns it.** A **method track** is a key on the animation that calls a function by name.
On Animation Event IS that function, so the animator can move the hit frame without anybody touching
the sheet:

```
On Animation Event  "hit frame"
  -> Set node enabled  $Hitbox = true
```

Name the event `hit frame` and the track must call `_on_hit_frame`. That contract is invisible from the
script's side - the function sits there looking like a helper nobody calls - which is why **Project
Doctor** warns when a method track names a function no script defines. That is the bug where the key
plays, nothing happens, and nothing is reported.

## Opening a script that already does this

Every shape in this guide reads back. Open a hand-written fighting-game script as a sheet and the loop
everybody writes - a list of pressed inputs, a countdown that empties it, and a `match` on the joined
list - reads as the detector it is:

```
➜ Player ▸ Combo Box ▸ On combo "punch punch kick"    within 0.5 s
     -> Set animation to "uppercut" (play from beginning)

➜ Player ▸ Combo Box ▸ On combo "kick kick"           within 0.5 s
     -> Set animation to "sweep" (play from beginning)
```

The list being emptied inside each arm does not read as a step, because it is the detector's own
bookkeeping and the trigger above already stands for it. The two comparisons on the play head read as
one *Is between 0.3 s and 0.6 s* row. The three time-scale lines read as one *Hitstop for 0.08 seconds*
row, with a note saying the whole game freezes.

Nothing about that reading changes a byte of the file. Save it untouched and it comes back exactly as
it went in.

## Tips and common mistakes

- **Press Input is yours to call.** Combo Box reads no hardware. Nothing happens until you push tokens
  into it from your own events - and that is the point: the same detector serves a keyboard, a pad, a
  touchscreen and an AI opponent.
- **Timing is in seconds, buffering is in frames.** A `timing_window` of `0.3` is 300 ms. A buffer of
  `6` is six physics ticks. Mixing the two units up is the most common way a move list feels wrong.
- **A window without a clip name opens during idle too.** Is Between asks which animation on purpose.
- **Never wait on a clock you stopped.** A hit-stop that waits in scaled time never ends. Use the
  Hitstop and Pause For rows, whose waits ignore the time scale, rather than a plain Wait.
- **Hit-stop is global.** It freezes both fighters, the camera and the particles. When you meant to
  freeze one character, you meant Pause For.
- **Consume the buffer the moment you act on it.** Otherwise the press comes out once per frame for
  the whole buffer window.
- **A looping clip never finishes.** Queue Animation and On Animation Finished both wait for an end
  that never comes, so a combo chained off a looping attack clip stalls forever.
- **Method-track names are plain text and typos are silent.** `_on_hit_frame` in the track and
  `_on_hitframe` in the script is a hit that never lands and never errors. Run Project Doctor.
- **One combo wins per input.** When a long move and the short move inside it both complete on the same
  press, the higher priority wins, then the longer one. Set Combo Priority is how you decide.
- **Clear the buffer on a context change.** Entering a menu, a cutscene or a round reset should empty
  it, or inputs from before the pause leak into the move after it.
