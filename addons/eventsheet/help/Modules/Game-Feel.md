# Game Feel

Game feel is the small, loud stuff: the screen jolting when a hit lands, the world freezing for a
fiftieth of a second, a pickup floating, a sprite flashing red, a stomped enemy squashing and
springing back. Five snippets cover most of it, and every game copies the same five.

They ship here as five rows, each compiling to the exact lines a hand-written script would use:

- **Shake** - a random camera offset this tick.
- **Hitstop** - time scale down, a real-time wait, time scale back to 1.
- **Bob** - a height plus a sine wave.
- **Flash** - a tint, a wait, and the tint removed.
- **Ease Size Back** - the scale easing back to normal, which is how a squash recovers.

**The behaviors do more.** The **Juice**, **Juice 3D**, **Sine** and **Flash** packs carry state of
their own - decaying trauma so a shake fades instead of stopping dead, camera effects that compose
around one rest pose, an **On Finished** trigger to chain the next beat. If an object needs game feel
more than once, attach the behavior; these rows are the one-liner version for a script that only
wants one, and for reading a hand-written snippet in the same words.

Every row compiles to plain Godot (`Engine.time_scale`, `randf_range`, `sin`, `modulate`, `lerp`)
with no plugin runtime behind it.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Reference tables](#reference-tables)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **A hit that lands** - shake and hitstop on the same trigger, three rows total.
- **A pickup that floats** so the eye finds it on a busy screen.
- **A damage flash** on any sprite, without a tween or a shader.
- **A squash-and-stretch stomp** that springs back on its own.
- **A boss slam** that freezes the frame before the shockwave.
- **A critical hit** that is louder than an ordinary one, by amount alone.
- **A jam prototype** where the feel has to land in an afternoon.
- **Reading someone else's script** and seeing the five snippets by name.

## Core concepts

- **Shake is per tick, not a duration.** The row writes one random offset. Put it under an event that
  runs while the shake should last (a countdown, an Every tick with a condition), and stop running it
  when the shake is over. The Juice behavior is the version with trauma and decay built in.
- **Hitstop waits in REAL time.** The timer is created with the ignore-time-scale flag set, which is
  the whole trick: at `time_scale = 0.1` an ordinary timer would take ten times as long to fire, so
  the freeze would never end when you meant it to.
- **Hitstop is global.** `Engine.time_scale` is the whole game's clock. Two hitstops overlapping means
  the first one to finish restores full speed for both, so trigger it from one place.
- **Bob needs a number that grows.** The Time parameter defaults to the engine clock in seconds, so
  the row works with nothing else set up. A variable you add delta to every tick works the same way
  and lets you reset the wave to zero.
- **Bob writes an absolute height.** It sets `position.y` outright, around the height you give it -
  it does not add to whatever is there. An object that also walks around wants the Sine behavior,
  which offsets instead.
- **Flash waits, so the row that follows it waits too.** The action pauses its event until the flash
  is over, exactly as a Wait row does, and puts the tint back afterwards.
- **Ease Size Back runs every tick.** It moves a fraction of the way to normal size each frame, so it
  belongs under an Every tick event; the Rate is roughly how fast it converges, per second.
- **The rows are node-scoped.** Shake is a `Camera2D` row, Flash is a `CanvasItem` row, Bob and Ease
  Size Back are `Node2D` rows, and each carries the optional **On node** target, so the same row can
  act on another node without changing what it does.

## Reference tables

| Name | What it does | Ships as |
|------|--------------|----------|
| Shake | Jolts this camera by a random offset for one tick. | `{target.}offset = Vector2(randf_range(-{amount}, {amount}), randf_range(-{amount}, {amount}))` |
| Hitstop | Slows the whole game to a crawl for a moment, then restores it. | `Engine.time_scale = {scale}`, `await get_tree().create_timer({seconds}, true, false, true).timeout`, `Engine.time_scale = 1.0` |
| Bob | Floats this object up and down on a sine wave. | `{target.}position.y = {base} + sin({time} * {frequency}) * {magnitude}` |
| Flash | Tints this object for a moment and then puts it back. | `modulate = {colour}`, `await get_tree().create_timer({seconds}).timeout`, `modulate = Color.WHITE` |
| Ease Size Back | Eases this object's size back to normal, which is how a squash recovers. | `scale = scale.lerp(Vector2.ONE, {rate} * delta)` |

## Use cases

**1. The hit that lands.** On the damage trigger, one Shake row and one Hitstop row. That is the
whole effect most action games ship with.

```
On Hit
    -> Camera2D  Shake by 6
    -> System  Hitstop for 0.05 seconds
```

**2. A shake that lasts.** Start a cooldown for 0.2 seconds on the hit, then run Shake every tick
while the cooldown is running. The shake ends when the cooldown does.

**3. A shake that gets smaller.** Use the cooldown's own remaining time as the amount
(`Shake by remaining * 20`), so the jolt fades out instead of stopping mid-jitter.

**4. A critical hit that feels critical.** The same two rows with bigger numbers - Shake by 14,
Hitstop for 0.12 seconds - under the "was a critical" condition.

**5. A boss slam.** Hitstop for 0.2 seconds first, then the shockwave spawn: the freeze sells the
weight before anything moves.

**6. A pickup that floats.** Bob under Every tick on the collectible, magnitude 4, 2 per second. The
eye finds a moving thing on a busy screen.

**7. A row of pickups that do not bob in unison.** Give each one a different Around height and a
different Per second, or offset the Time by the object's own index.

**8. A hovering drone.** Bob with a small magnitude and a slow frequency on an enemy that also
patrols horizontally, so only its height wobbles.

**9. The damage flash.** Flash red for 0.1 seconds on the enemy's On Hit, before its health row. Two
hits in a row look right because each flash restores white when it ends.

**10. An invulnerability blink.** Flash white for 0.05 seconds inside a Repeat 6 times loop, which
reads as a blink and needs no timer of its own.

**11. A heal that reads as a heal.** Flash green for 0.15 seconds on the healing trigger, so the same
sprite says "hurt" and "healed" with the same row and a different colour.

**12. Squash on landing.** Set size to 130% on the landing trigger and run Ease Size Back every tick;
the object springs back on its own with no tween to manage.

**13. Stretch on a jump.** The same shape the other way - Set size to 80% on the jump, Ease Size Back
every tick - so the object thins as it leaves the ground.

**14. A button that pops.** Set size to 110% on On Pressed and Ease Size Back at 12 every tick, which
is the whole UI juice budget of most menus.

**15. A stomped enemy.** Flash red, squash to 140% wide, and Ease Size Back - three rows on the one
trigger, no animation clip needed.

**16. Slow motion that is not a hitstop.** Set time scale to 0.3 on the trigger and back to 1 on a
timer: Hitstop is the fixed, brief version of the same idea, and the two should not overlap.

**17. Reading a script you did not write.** A hand-written script that contains any of these five
shapes opens as these rows, with the arithmetic as a muted note and the exact GDScript on the hover.

**18. Trading up to the behavior.** When one object needs shake more than once, attach the Juice
behavior: its trauma decays, its camera effects compose, and it tells you when a shake stopped.

### Other use cases

**A screen-wide "you took damage" pulse.** Flash the HUD's red vignette layer for 0.1 seconds on the player's On Hit, so the feedback is on the screen rather than only on the sprite.

**A rhythm game's beat pop.** Set size to 115% on every beat trigger and Ease Size Back at 15, which pulses the note lane in time with the music.

**A slot-machine stop.** Bob the reel with a fast frequency, then a Hitstop when it lands, so the stop reads as a physical clunk.

**A camera that shakes with the engine.** Shake by a small amount every tick while the vehicle's speed is above a threshold, using the speed itself as the amount.

**A death that stops the world.** Hitstop for 0.4 seconds on the player's death before the game-over layout loads, so the last frame registers.

## Tips and common mistakes

- **Shake on its own does nothing visible for long.** One row is one tick. If the screen barely
  moved, the row ran once - put it under something that lasts.
- **Do not shake a camera that another system also positions this frame.** A follow script writing
  `position` after the offset is fine (the offset is separate), but a second row writing `offset`
  will win. The Juice behavior composes around one rest pose for exactly this reason.
- **Hitstop with the wrong timer never comes back.** If you write the wait by hand, the fourth
  argument of `create_timer` (ignore time scale) must be `true`; without it the freeze lasts ten times
  as long at `time_scale = 0.1`.
- **Do not hitstop inside a physics event.** Freezing the clock from `_physics_process` makes the
  restore land in an unpredictable frame; trigger it from the hit event that caused it.
- **Bob fights anything else that writes `position.y`.** A platformer's gravity and a Bob row on the
  same object will not both win. Bob decorations, not bodies.
- **Flash pauses the event.** Rows after it in the same event run once the flash is over. Put
  anything that must happen immediately above it.
- **Flash restores white, not "whatever it was".** An object that is deliberately tinted (a poisoned
  enemy) loses its tint when the flash ends. Re-apply it afterwards, or use the Flash behavior, which
  remembers.
- **Ease Size Back never quite arrives.** A lerp approaches its target; it is close enough to invisible
  within a few frames, but if you need exactly 100%, set the size outright when you are done.
- **The rate is per second, not per frame.** `10` recovers quickly, `2` is a slow settle. Multiplying
  by delta is already done for you.
