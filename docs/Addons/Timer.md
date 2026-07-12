# Timer - A Countdown You Attach to Any Node

Timer is a Godot EventSheets behavior pack. You attach a `TimerBehavior` to a node - a spawner, an enemy, a HUD label, anything that extends `Node` - and that node gains a private countdown clock. Set how many seconds it should run, start it, and when it reaches zero the **On Timer** trigger fires so your sheet can react. Turn on `repeating` and the clock reloads and fires again on a fixed beat, like a metronome; leave it off and it fires once, then stops. There is no global "timer id" to juggle and no manual `delta` bookkeeping: the countdown lives on the node you drop it on, so every Action, Expression, and Trigger you place there acts on that node's own clock. Want three independent timers on one enemy? Attach three Timer behaviors. This is a per-node behavior, not an autoload singleton - you never call it as `Timer.Something`; you place it on a node and it runs there.

---

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Repeating spawners.** Put a Timer on a spawner node, set it repeating, and On Timer becomes your "spawn one more" pulse - no per-frame counting.
- **One-shot delays.** "Open the gate three seconds after the lever is pulled" is Start Timer plus On Timer, and nothing else.
- **Respawn and revive waits.** Start the clock when the player dies; On Timer brings them back after the grace period.
- **Buff and debuff durations.** A shield or speed boost that expires on its own: Start Timer when it is applied, remove it in On Timer.
- **Ability cooldowns.** Start the Timer when the skill fires, block re-use until On Timer marks it ready again.
- **Auto-firing weapons.** A repeating Timer on a turret is its fire rate: every On Timer spawns a bullet.
- **Blink and flash effects.** A short repeating Timer toggles a sprite's visibility on each On Timer for an invulnerability flicker.
- **Round and level clocks.** Start a long Timer at round start; On Timer means "time is up," and the **Duration** expression can feed a countdown label.
- **Regeneration ticks.** A repeating Timer heals or refills stamina a little on every beat.
- **Idle and inactivity timeouts.** Start the Timer on the last input and Stop Timer on any new input; if On Timer ever fires, the player has gone idle.
- **Difficulty ramps.** Subtract From Duration a little each cycle so a repeating spawner speeds up as the match heats up.
- **Debounced events.** Restart the Timer on every rapid event; because Start Timer resets the countdown, On Timer only fires once the flurry goes quiet.

---

## Core concepts

The whole pack is one small idea with a few knobs. Learn these and you know Timer.

**One behavior is one countdown.** You attach a `TimerBehavior` under a node and it holds a single clock: a `duration` (how long a run lasts, in seconds), a `remaining` value that ticks down, and a `running` flag. Everything you do is starting, stopping, and reacting to that one clock. Need more than one clock on the same node? Attach another Timer behavior - each is fully independent.

**The clock only moves while it is running.** Nothing counts down until you call **Start Timer**. Start Timer sets the length, fills the remaining time, and flips the clock on. Each frame after that, the remaining time drops by the frame's elapsed seconds. When it reaches zero, **On Timer** fires.

**Repeating decides what happens at zero.** This is the one setting that changes the personality of the clock:

- **Repeating off (the default):** On Timer fires once, then the clock stops. This is a one-shot delay - a fuse.
- **Repeating on:** the moment the clock hits zero, it refills to `duration` and keeps going, so On Timer fires again and again on a steady beat - a metronome.

You set `repeating` in the Inspector before the game runs, or flip it live with the **Set Repeating** action.

**Start Timer restarts, it does not resume.** Calling Start Timer always begins a fresh run from the full duration you pass it. It is not a pause/resume - there is no resume. Starting an already-running clock simply throws away the old countdown and starts over, which is exactly what you want for debouncing and for "reset the fuse."

**Stop Timer is silent.** Stop Timer halts the countdown without firing On Timer. Use it to cancel something you scheduled - the idle timeout that should not fire because the player moved, the self-destruct the player defused in time.

**Duration is both the length and the reload value.** The `duration` property is the number Start Timer fills the clock with, and it is also what a repeating clock reloads to on each beat. So changing `duration` (with Set Duration, Add To Duration, or Subtract From Duration) reshapes the *next* cycle of a repeating timer - that is how you make a spawner accelerate over time. Changing duration does not disturb the run that is currently counting down; it takes effect at the next start or the next repeat.

**Read the clock with expressions.** The **Duration** expression returns the configured length and **Repeating** returns whether it loops - handy for feeding a countdown label or for a condition that checks the current setting.

**The behavior acts on the node it sits on.** Every Timer Action, Expression, and Trigger targets the `TimerBehavior` on the node where you placed it - shown in a row as `Enemy | Timer: Start Timer`. There is no id argument to pass. (Under the hood the target is a node path that defaults to the Timer node itself; you only ever touch that if you deliberately want one sheet to drive a Timer that lives on a different node.)

---

## Setup

**1. Attach the behavior.** Add a `TimerBehavior` as a child of the node you want to give a clock (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in as a child). The host must be a `Node` (which every 2D, 3D, and UI node already is), so it attaches to anything.

**2. Set the Inspector knobs.** Select the Timer node and set its starting length and whether it loops:

| Property | Default | What it does |
|---|---|---|
| `duration` | `1.0` | The length of one run, in seconds. Start Timer overwrites this with the value you pass; a repeating clock reloads to it each beat. |
| `repeating` | `false` | Off = fire On Timer once then stop (a one-shot delay). On = reload and fire again forever (a metronome). |

**3. Start it and react to On Timer.** Two moves: kick the clock off somewhere, and handle On Timer. Here is a complete first Timer - a spawner that drops an enemy every three seconds:

```
On Ready
  -> Spawner | Timer: Set Repeating  true
  -> Spawner | Timer: Start Timer  3.0

On Timer
  -> Spawner: spawn one enemy
```

Set Repeating turns it into a metronome; Start Timer 3.0 begins the first three-second run; On Timer fires on every beat. Leave out the Set Repeating line (or leave `repeating` off in the Inspector) and the very same rows spawn exactly one enemy, three seconds in, and then go quiet.

---

## ACE reference

All ACEs live in the **Timer** category and act on the `TimerBehavior` of the node they are placed on. There is no timer-id parameter anywhere. The **Start Timer** and **Stop Timer** actions and the **On Timer** trigger are authored on the behavior directly; the **Duration** / **Repeating** expressions and the **Set / Add To / Subtract From** actions are generated automatically from the behavior's two exported properties, so you can read and reshape the clock from any sheet.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Start Timer | `seconds` (float) | Starts (or restarts) the countdown with the given duration. Sets the length to `seconds`, fills the remaining time, and turns the clock on. Always begins a fresh run - there is no resume. |
| Stop Timer | (none) | Stops the countdown without firing On Timer. Use it to cancel a scheduled event. |
| Set Duration | `value` (float) | Sets the `duration` property directly. Takes effect at the next Start Timer or, for a repeating clock, the next reload - it does not disturb the run currently counting down. |
| Add To Duration | `amount` (float) | Adds to the `duration` property (lengthen the next cycle). Use a negative amount to shorten. |
| Subtract From Duration | `amount` (float) | Subtracts from the `duration` property (shorten the next cycle) - the natural way to make a repeating timer speed up. |
| Set Repeating | `value` (bool) | Turns looping on or off live. On = reload and fire again each beat; off = fire once then stop. |

### Conditions

The Timer behavior ships no conditions of its own. To branch on the clock, compare the **Duration** or **Repeating** expressions (for example `Enemy | Timer: Duration  <  0.5`), or gate on your own game variables. Reacting to the clock reaching zero is what the **On Timer** trigger is for.

| Condition | Parameters | Description |
|---|---|---|
| (none) | | Use the Duration / Repeating expressions in a comparison, or the On Timer trigger, instead. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Duration | (none) | float | The configured run length in seconds - the value Start Timer set and a repeating clock reloads to. |
| Repeating | (none) | bool | Whether the clock loops (`true`) or fires once and stops (`false`). |

### Triggers

| Trigger | Fires when |
|---|---|
| On Timer | The countdown reaches zero. Fires once for a one-shot clock, then the clock stops; fires on every beat while `repeating` is on. |

### Inspector properties

| Property | Type | Default | What it does |
|---|---|---|---|
| `duration` | float | `1.0` | Length of one run, in seconds. Overwritten by Start Timer; the reload value when repeating. |
| `repeating` | bool | `false` | Loop (metronome) when on; one-shot fuse when off. |

---

## Use cases

Each example acts on the `TimerBehavior` of the named node. Start the clock somewhere (often `On Ready` or a gameplay stimulus) and react in `On Timer`.

### 1. Repeating enemy spawner

The bread-and-butter loop: one enemy every couple of seconds, forever.

```
On Ready
  -> Spawner | Timer: Set Repeating  true
  -> Spawner | Timer: Start Timer  2.0

On Timer
  -> Spawner: instance an enemy at a random spawn point
```

Turn the Set Repeating line off (or set `repeating` false in the Inspector) and this becomes a single delayed spawn instead.

### 2. One-shot delayed door

Pull a lever, wait three seconds, open the gate. No repeat, no counting.

```
On Lever Pulled
  -> Gate | Timer: Start Timer  3.0

On Timer
  -> Gate: play "open" animation
```

Because `repeating` is off, On Timer fires exactly once and the clock rests.

### 3. Respawn after death

Start the clock when the player dies; bring them back when it elapses.

```
On Player Died
  -> Player | Timer: Start Timer  5.0

On Timer
  -> Player: move to checkpoint and heal to full
  -> GameHUD: hide the "respawning" overlay
```

### 4. Temporary shield that expires on its own

A pickup grants a shield for eight seconds and cleans itself up.

```
On Shield Picked Up
  -> Player: enable shield visual
  -> Player | Timer: Start Timer  8.0

On Timer
  -> Player: disable shield visual and clear the invulnerable flag
```

### 5. Ability cooldown gate

Fire the skill, start the cooldown clock, and let On Timer flag it ready again.

```
On Cast Pressed
  Condition: Player.skill_ready  ==  true
    -> Player: cast fireball
    -> Player: set skill_ready = false
    -> Player | Timer: Start Timer  4.0

On Timer
  -> Player: set skill_ready = true
  -> GameHUD: flash the skill icon "ready"
```

### 6. Auto-firing turret

A repeating clock is simply the turret's fire rate.

```
On Ready
  -> Turret | Timer: Set Repeating  true
  -> Turret | Timer: Start Timer  0.5

On Timer
  -> Turret: spawn a bullet toward the nearest target
```

Two shots a second; change the 0.5 to retune the cadence.

### 7. Invulnerability blink

A short repeating Timer toggles the sprite so a just-hit player flickers.

```
On Player Hit
  -> Player | Timer: Set Repeating  true
  -> Player | Timer: Start Timer  0.1

On Timer
  -> Player: toggle sprite visibility

On Invulnerability Ended
  -> Player | Timer: Stop Timer
  -> Player: force sprite visible
```

Stop Timer ends the flicker cleanly when the invulnerability window closes, and the follow-up forces the sprite back on so it never stops while hidden.

### 8. Round clock with a live countdown label

Start a long one-shot Timer; On Timer means the round is over, and the **Duration** expression feeds the label.

```
On Round Start
  -> RoundClock | Timer: Start Timer  90.0

On Timer
  -> Match: end the round and show the results screen
```

The Duration expression (`RoundClock | Timer: Duration`) gives you the configured length to display, and On Timer is your "time's up" hook.

### 9. Stamina regeneration ticks

A repeating Timer tops up stamina a little on each beat.

```
On Ready
  -> Player | Timer: Set Repeating  true
  -> Player | Timer: Start Timer  1.0

On Timer
  Condition: Player.stamina  <  Player.max_stamina
    -> Player: add 5 to stamina
```

The clock keeps ticking; the condition simply skips the top-up when stamina is already full.

### 10. Idle timeout that any input cancels

Start the clock on the last activity, and Stop Timer the instant the player does anything. If On Timer ever fires, they have gone idle.

```
On Any Input
  -> Menu | Timer: Start Timer  15.0

On Timer
  -> Menu: play the attract-mode demo reel
```

Every input restarts the fifteen-second fuse (Start Timer resets it), so the reel only plays after a genuine fifteen seconds of quiet.

### 11. Difficulty ramp - a spawner that speeds up

A repeating spawner shortens its own interval each cycle, down to a floor.

```
On Ready
  -> Spawner | Timer: Set Repeating  true
  -> Spawner | Timer: Start Timer  3.0

On Timer
  -> Spawner: spawn a wave
  Condition: Spawner | Timer: Duration  >  0.8
    -> Spawner | Timer: Subtract From Duration  0.1
```

Because `duration` is the reload value, each Subtract From Duration makes the *next* beat arrive sooner; the Duration condition stops it from dropping below eight-tenths of a second.

### 12. Timed poison, then heal back to normal

A repeating Timer applies damage-over-time, and a second, one-shot Timer ends the effect after a fixed window.

```
On Poisoned
  -> Enemy | Timer: Set Repeating  true
  -> Enemy | Timer: Start Timer  1.0
  -> Enemy | PoisonWindow: Start Timer  6.0

On Timer  (Enemy | Timer)
  -> Enemy: subtract 4 from hp

On Timer  (Enemy | PoisonWindow)
  -> Enemy | Timer: Stop Timer
  -> Enemy: clear the poisoned flag
```

Two Timer behaviors on the same enemy - one ticks the damage, the other counts the total duration and stops the first when the poison wears off.

### 13. Grow the interval when the player is winning

Adaptive pacing: if the player is cruising, stretch the gap between hazards with Add To Duration.

```
On Wave Cleared
  Condition: Player.hp  >  0.75 * Player.max_hp
    -> Hazards | Timer: Add To Duration  0.5
  -> Hazards | Timer: Start Timer  Hazards | Timer: Duration
```

Add To Duration lengthens the configured time, then Start Timer begins the next run at that fresh length - a gentle breather for a player who is doing well.

### 14. Flip a one-shot into a loop midgame

Start as a single delay, then decide later to make it repeat.

```
On Boss Enraged
  -> Boss | Timer: Set Repeating  true
  -> Boss | Timer: Start Timer  1.5

On Timer
  -> Boss: fire a radial burst
```

Set Repeating flips the behavior live, so the same Timer that was a one-shot earlier in the fight now pulses on a beat once the boss enrages.

### 15. Telegraphed attack with the State Machine pack

Pair a one-shot Timer with the State Machine pack for a readable boss telegraph: enter the windup state, light the fuse, and let the strike land when it elapses.

```
On Attack Chosen
  -> Boss | StateMachineBehavior: Set State  "windup"
  -> Boss | Timer: Start Timer  1.2

On Timer
  -> Boss | StateMachineBehavior: Set State  "strike"

On Boss Staggered
  -> Boss | Timer: Stop Timer
```

Stop Timer cancels the strike silently, so a well-timed stagger defuses the attack with no extra bookkeeping.

### Other use cases

**Combo window.** Restart a short one-shot Timer on every landed hit; because Start Timer always resets the fuse, On Timer only fires once the flurry stops, which is exactly when the combo counter should reset.

**King-of-the-hill scoring.** A repeating Timer on the capture zone awards a point each beat while a player stands inside, and Stop Timer on exit pauses the scoring cleanly.

**Shop restock.** A long repeating Timer on the merchant refreshes the inventory every few minutes of play, and Subtract From Duration can quicken restocks as the run progresses.

**Breath meter.** Start a one-shot Timer when the player submerges and Stop Timer on surfacing; if On Timer ever fires, the air ran out and the drowning damage begins.

**Hot-potato fuse.** A single running Timer rides an item that players pass around - whoever holds it when On Timer fires takes the blast, and nobody knows exactly when that will be.

---

## Tips and common mistakes

- **The node is the clock - there is no timer id.** Every Action, Expression, and Trigger acts on the `TimerBehavior` of the node it is placed on. Do not look for an id argument; place the row on the node whose clock you mean. For a second, independent clock on the same node, attach a second Timer behavior.
- **Nothing counts down until you Start Timer.** Setting `duration` in the Inspector only stores a length; it does not run the clock. You must call Start Timer (in `On Ready`, or on a stimulus) to actually begin a countdown.
- **Start Timer restarts from the top - it is not resume.** Each Start Timer throws away the current countdown and begins a full run. That is perfect for "reset the fuse" and debouncing, but if you call it every frame the clock can never reach zero and On Timer will never fire.
- **`repeating` is the fire-once vs fire-forever switch.** Off means one On Timer then stop; on means a steady beat. If your event only fired once when you wanted a loop (or spammed every beat when you wanted one shot), check `repeating` in the Inspector or your Set Repeating call.
- **Stop Timer is silent by design.** It halts the countdown and never fires On Timer. Reach for it to cancel a scheduled event - the timeout the player beat, the self-destruct they defused. If you need something to happen when you stop, do it in the same event as Stop Timer, not through On Timer.
- **Duration is the reload value, so change it to reshape the loop.** Set Duration, Add To Duration, and Subtract From Duration edit the length used by the *next* start or repeat; they never shorten or extend the run already ticking down. To apply a new length immediately, change it and then call Start Timer.
- **Do not set a repeating duration to zero.** A repeating clock reloads to `duration` each beat, so a zero (or negative) duration fires On Timer every single frame. Keep a floor when you subtract, as in the difficulty-ramp example.
- **On Timer fires during the frame the clock hits zero.** For a repeating timer the beat spacing is your duration, evaluated in fixed real-time seconds, so it is steady regardless of frame rate. Keep the work in On Timer light if the interval is very short (an auto-fire at 0.05 seconds is twenty spawns a second).
- **Two clocks, two behaviors.** There is no built-in "second timer" on one behavior. When a use case needs two independent countdowns on the same object (a damage tick plus an overall duration, as in the poison example), attach two Timer behaviors and address each by its node.
