# Game Mechanics

Four shapes turn up in almost every game, and every project writes them out by hand: randomness that
owes the player one, a meter that fills while something is true and drains while it is not, a boss
fight that changes at health thresholds, and a mission clock with a deadline on it.

None of them is one line. Each is several lines that only mean something together, which is why a
script full of them reads as arithmetic. This module gives all four their own words - both ways: the
rows below write exactly the lines the reading recognises, and an opened script that already writes
them reads back as the same rows.

- **Meters** - Fill and Drain, the countdown's two-way twin.
- **Stealth** - Make Noise, and the On Noise Heard event that receives it.
- **Boss** - Phase Starts, and Set Invulnerable For.
- **Missions** - Start Mission Timer, Add Mission Time, and Mission Time Left.

Every row compiles to plain Godot (`minf`, `maxf`, `get_nodes_in_group`, `create_timer`, a format
string) with no plugin runtime behind it.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Reference tables](#reference-tables)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **A loot chest a player can trust** - the odds climb with every miss and a cap guarantees the win.
- **A guard who sees, hears, and remembers** - one meter, two rates, and a place to walk to.
- **A boss whose fight changes** - phases that start exactly once, and an invulnerability window.
- **A mission with a deadline** - a clock the player can read and a fail event when it runs out.
- **Reading somebody else's script** - all four shapes read as themselves the moment the file opens.

## Core concepts

### Pity: randomness that owes you one

A pity system is four halves written apart: a counter fed once per roll, a chance grown out of it, a
roll compared against that chance **or** a hard cap, and a reset on the win. All four are required
before the sheet calls it a pity system - a plain `randf() < x` stays the Chance condition it
already is, and a counter with no roll stays a counter.

![A loot chest's open function, with the roll-or-cap line read as one row: Rolled with pity, chance, guaranteed at pity_cap](../images/reading-pity.png)

For a roll that must replay identically - a daily challenge, a recorded test - use the Advanced
Random pack's **Roll With Pity** instead. It is the same shape in one row, its counters are addressed
by name so one autoload holds a project's worth of them, and it rides the pack's seeded generator.

### Meters: the countdown's two-way twin

A meter is a number that moves at a **speed** and stops at a limit. Fill raises it toward a cap while
something holds; Drain lowers it toward a floor while it does not. Both halves clamp, because a meter
that overshoots its limit is a bug every project fixes the same way.

A meter is the **pair**. A clamped add with no per-frame rate is not one, and neither is a fill
nothing drains - which is what keeps every bar in every project out of these words.

![A guard's physics tick: Fill suspicion at detect_rate up to 100, and an Else row draining it at calm_rate down to 0](../images/reading-detection.png)

With a can-see-or-is-hidden question gating the two halves, the whole loop is a detection system and
the sheet marks it as one, with the last-known-position line as part of its evidence.

### Noise, and who hears it

One object makes a noise somewhere; everything close enough to hear it is told where. **Make Noise**
is that walk in one row, and **On Noise Heard** is the receiving half - a plain function the noise
maker calls by name, so listeners can come and go with the level without anything being connected.

A listener has to be in the group the noise names. Add it once, on created, with Add To Group.

### Boss phases

A boss fight changes at health thresholds, and each phase must start exactly once. The guard that
makes it happen once is the phase the fight is already in, so the row says "once" instead of showing
the bookkeeping. A plain `hp <= 0` is a health check in every game ever written, and stays one.

![A boss take-damage function, with a guarded threshold read as: Phase 2 starts, hp under 60 percent, once](../images/reading-boss-phases.png)

Lay each attack out as a **Timeline** block - telegraph, strike, recover - and play it from the
phase's own event. **Set Invulnerable For** is the window after a hit: a flag turned on, a wait, and
the flag turned off, as one action instead of a flag and a timer that can drift apart.

### Mission clocks

A mission clock is an ordinary countdown with two extra jobs: a deadline, and an audience. The one
thing it needs that a cooldown does not is to be **readable**, which is what m:ss is for.

![A mission tick: the clock counted down, and the HUD label set to the clock as minutes:seconds](../images/reading-mission-timer.png)

**Start Mission Timer** and **Add Mission Time** take their time the way a player reads it - type
`3:00` and the row stores 180 seconds. **Mission Time Left** hands a label the text itself.

To carry a clock across scenes, put its variable on an autoload; to survive a quit, tick **Remember
Between Runs** on it. Neither needs anything new.

## Reference tables

### Actions

| Row | Writes | Notes |
| --- | --- | --- |
| **Fill Meter** | `x = minf(x + rate * delta, cap)` | The rate is per second, not per frame. |
| **Drain Meter** | `x = maxf(x - rate * delta, floor)` | The other half of a meter. |
| **Make Noise** | a walk over the listening group, gated by distance | Only the ones close enough hear it. |
| **Set Invulnerable For** | a flag, a wait, the flag again | Suspends the event, like every wait. |
| **Start Mission Timer** | the seconds onto a variable | Its time field takes `3:00`. |
| **Add Mission Time** | the seconds added | The pickup that buys another half minute. |

### Conditions

| Row | Asks | Notes |
| --- | --- | --- |
| **Phase Starts** | health has fallen past a share of maximum, while the fight is in an earlier phase | Set the phase variable in the actions below it. |

### Expressions

| Row | Gives | Notes |
| --- | --- | --- |
| **Mission Time Left** | the time left as `"2:41"` | Drop it straight into a HUD label. |

### Triggers

| Row | Runs when | Notes |
| --- | --- | --- |
| **On Noise Heard** | a Make Noise happened close enough | Put the object in the listening group first. |

## Use cases

**1. A loot chest that cannot be cruel.** Feed a counter on every open, grow the chance out of it,
roll against it or the cap, and reset on the win. Twenty misses in a row stops being possible.

**2. A gacha banner with its own counter.** Advanced Random's Roll With Pity, named `"banner_a"`, so
a second banner keeps its own count without a second variable.

**3. Crit smoothing.** The same shape with a small base chance and a small step, so a run of misses
cannot make a weapon feel broken.

**4. Drop protection for a rare material.** A cap of 30 turns "maybe never" into "at worst, thirty".

**5. A seeded daily challenge.** Set the seed on start and every pity roll in the run replays
identically - which is also how a recorded test pins one.

**6. A guard's suspicion.** Fill while the player is seen and not hidden, Drain while not, and start
the hunt at 100. Two rows and a threshold.

**7. A hiding spot that works.** A boolean the cover code sets; the fill row is gated on it being
false, so stepping into shadow stops the meter climbing without emptying it.

**8. Somewhere to walk to.** Set a last-known variable on the same rows that fill the meter, and the
Nav Agent walks there instead of standing still.

**9. Footsteps that give you away.** Make Noise at the player's position with the radius scaled by
speed - a sprint carries, a crouch does not.

**10. A thrown bottle.** Make Noise at the impact point on the bottle's collision, so the distraction
is somewhere the player is not.

**11. A guard that investigates a sound.** On Noise Heard, set the last-known place and add 30 to
suspicion, so a noise starts a search without being proof.

**12. A charge attack.** A meter filled while the button is held and drained while it is not, capped
at 100 - the same two rows, nothing to do with stealth.

**13. A two-phase boss.** Phase Starts at 60% and at 25%, with the phase's opening moves under each.

**14. An attack pattern that reads.** A Timeline per attack - telegraph 0.4s, strike, recover 1.2s -
picked by a weighted choice and played from the phase's event.

**15. Invulnerability frames.** Set Invulnerable For 0.5 seconds at the top of the damage function,
with the whole function guarded on the flag.

**16. A defuse timer.** Start Mission Timer at 3:00, show Mission Time Left on the HUD, and fail when
it runs out.

**17. An escort with pickups.** Add Mission Time 0:30 on each checkpoint, so the clock is a resource
rather than a sentence.

**18. A delivery run across two scenes.** The clock's variable on an autoload, ticked from one place,
read by whichever HUD is on screen.

### Other use cases

**A boss bar bound to health.** Bind a HUD Kit bar to the same `hp` the phase thresholds read, so the
bar and the fight can never disagree about when a phase starts.

**A sanity meter.** Fill in the dark and drain in the light, with the effects gated on thresholds -
the same pair as suspicion, pointed at a different feeling.

**A deadline that is not wall time.** Compare your own day/night clock variable against nightfall
instead of counting seconds down; the rows around it do not change.

**A pity counter that survives a quit.** Tick Remember Between Runs on the counter variable, or let
Advanced Random's save state carry every named counter at once.

**An alarm that stays raised.** Drain the meter down to 40 rather than 0, so a guard who has seen you
once never fully calms down.

## Tips and common mistakes

- **All four halves, or it is not pity.** A counter without a growing chance is a counter; a roll
  without a counter is the Chance condition. The reading refuses to guess, and so should the code.
- **Reset the counter on the win.** Miss it and the guarantee fires on every roll after the first cap
  hit - the single most common bug in a hand-written pity system. The Doctor says so as a note.
- **A meter needs both halves.** A fill nothing drains reaches its cap and stays there. The Doctor
  notes that one too.
- **The rate is per second.** `40` is a fast fill and `4` is a slow one; multiplying by delta is
  already done for you.
- **A listener must be in the group.** Make Noise reaches the group it names and nobody else. Add To
  Group on created, and pass `true` so the group survives being packed into a scene.
- **The phase guard is the "once".** Without it a threshold fires every frame once health is past it,
  and the phase's opening moves run forever.
- **Set the phase variable in the actions.** The condition asks which phase the fight is in; nothing
  moves it but the rows underneath.
- **Set Invulnerable For suspends the event.** Rows after it in the same event run once the window is
  over. Put anything that must happen immediately above it.
- **A mission clock nobody can see is not pressure.** Show Mission Time Left somewhere; the Doctor
  raises a note when a timer starts and no row shows it.
- **`3:00` is the field, `180.0` is the value.** The row stores seconds, which is what every other row
  that touches the clock expects.
