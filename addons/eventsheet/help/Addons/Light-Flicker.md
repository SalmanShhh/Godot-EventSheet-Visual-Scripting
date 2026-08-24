# Light Flicker - A Flame, Without Thirty Lines of Noise Code

A believable flame is a light whose brightness wanders - never steady, never random. Written by
hand that is a noise field, a lerp, a clock and a handful of tuning numbers on every torch in the
game. This pack is that code, once, as a behaviour you drop under any light.

It works on **any light, 2D or 3D**, because it never names a light class. When it starts it asks
its host which property that host spells brightness with - `energy` on a 2D light, `light_energy`
on a 3D one - and which of the three reaches it has, if any. A project's own subclass of a light
resolves through the same question with nothing added here.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this pack shines

- **Torches, campfires, braziers, candles.** The default numbers already read as a torch.
- **Failing electric light.** Widen `between` and raise `times_a_second` and the same behaviour
  reads as a broken strip-light in a corridor.
- **A light that reacts to the story.** *Stop flickering and settle at 0* puts a torch out; *Start
  flickering after 1.5 s* lights it again a beat after whatever lit it.
- **Tuning while the game runs.** Every number is an exported knob, so a flame is dialled in from
  the Inspector during play rather than by editing rows and pressing play again.

## Core concepts

- **It acts on its parent.** The behaviour is a child of the light and writes that light's own
  properties. Put it anywhere else and it warns once on its first frame and then does nothing.
- **The property is asked, not assumed.** On its first frame it asks the host which property spells
  brightness - `energy` on a 2D light, `light_energy` on a 3D one - and which of the three reaches it
  has, if any. That is why one pack covers both dimensions and a project's own subclass of a light.
- **`between` is a pair of absolute brightnesses.** Both numbers are in the same units the light's own
  brightness uses, so `Vector2(0.8, 1.2)` on a light authored at 1.0 brightens as often as it dims.
  It is not a range around a maximum.
- **Noise, not random.** The brightness walks a noise field, so each frame is related to the one
  before it. That relation is the whole difference between fire and static.
- **Stopping settles; it does not disable.** *Stop Flickering* leaves the light at the brightness the
  row names and the behaviour in place, ready for the next *Start Flickering*.
- **Reach is scaled, not set.** With *Also Flicker Reach* on, the radius the scene was authored with
  is remembered on the first frame and breathed around, so a designer's own radius survives - and is
  put back when the flame stops.

## Setup

1. Add a `LightFlickerBehavior` node as a **child of the light** it should animate.
2. Set `between` to the dimmest and brightest you want. 0.8 and 1.2 is a candle; 0.2 and 1.4 is a
   failing bulb.
3. Leave `running` on and it flickers the moment the scene does, or turn it off and start it from a
   row.

```
On Ready -> Torch | Light Flicker: Start Flickering  0
```

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, exactly as the
rows draw them:

- Start flickering after **after_seconds** s
- Stop flickering and settle at **settle_at**

| Kind | Name | Parameters | Description |
|---|---|---|---|
| Action | Start Flickering | `after_seconds` | Starts the flicker, now or after a delay. |
| Action | Stop Flickering | `settle_at` | Stops it and leaves the light at one steady brightness. |
| Condition | Is Flickering | - | True while it is really flickering: false while it waits out a delay, and false once stopped. |

Every exported knob is also a row: **Set Between**, **Set Times A Second**, **Add To Times A
Second**, **Set Also Flicker Reach**, **Set Running**, and the expressions that read each of them
back.

### Inspector properties

| Property | Default | What it does |
|---|---|---|
| `between` | `Vector2(0.8, 1.2)` | The dimmest and brightest the light gets. |
| `times_a_second` | `12.0` | How fast the flame moves. Below 3 is a slow glow; above 30 is an electrical fault. |
| `also_flicker_reach` | `false` | Breathe the light's reach with its brightness, which is what a real flame does. |
| `running` | `true` | Whether it is flickering right now. |

## Use cases

### 1. A torch on a dungeon wall

```
On Ready -> Torch | Light Flicker: Start Flickering  0
```

The default numbers are a torch. This row is only needed if `running` was turned off.

### 2. Lighting a brazier from a row

```
On Player Interacted -> Brazier | Light Flicker: Start Flickering  0
                     -> Brazier | Audio: Play Sound  "fire_catch.ogg"
```

### 3. Putting it out

```
On Water Hit -> Brazier | Light Flicker: Stop Flickering  0
```

Settling at 0 is a light that has gone out. The node stays; only the brightness is gone.

### 4. Calming a flame instead of killing it

```
On Wind Died -> Torch | Light Flicker: Stop Flickering  1.0
```

Steady, still lit - the difference between "extinguished" and "no longer guttering".

### 5. A torch that catches a beat late

```
On Torch Lit -> Torch | Light Flicker: Start Flickering  1.5
```

The delay is what makes a chain of torches light one after another instead of all at once.

### 6. A gust that knocks every torch down and back

```
On Storm Gust -> Torch | Light Flicker: Stop Flickering  0.6
              -> Torch | Light Flicker: Start Flickering  1.5
```

Dimmed at once, recovering a second and a half later. Two rows, one moment.

### 7. A failing corridor light

Set `between` to `Vector2(0.15, 1.3)` and `times_a_second` to `26` in the Inspector. No rows at all.

### 8. Turning the fault on when the power fails

```
On Generator Failed -> Corridor Light | Light Flicker: Set Between  Vector2(0.15, 1.3)
                    -> Corridor Light | Light Flicker: Set Times A Second  26
                    -> Corridor Light | Light Flicker: Start Flickering  0
```

### 9. A flame whose light shrinks as it dims

Turn `also_flicker_reach` on. The reach is scaled around whatever the scene was authored with, so a
designer's own radius survives - it breathes within a tenth either way rather than being replaced.

### 10. A magical flame that speeds up near danger

```
Every tick -> Torch | Light Flicker: Set Times A Second  12 + (30 - distance_to_boss) * 0.4
```

### 11. Asking whether a light is alight

```
Player pressed "interact"
  Torch | Light Flicker: Is Flickering  -> HUD Kit: Show Prompt  "Douse the torch"
```

### 12. A torch you can only relight once

```
On Interact
  NOT Torch | Light Flicker: Is Flickering
    Relights Left > 0 -> Torch | Light Flicker: Start Flickering  0
                      -> System: Subtract 1 from Relights Left
```

### 13. Fireplace that dies down over an evening

```
On The Hour -> Fireplace | Light Flicker: Set Between  Vector2(0.8 - hour * 0.05, 1.2 - hour * 0.05)
```

Pair it with the Day/Night Cycle pack and the hearth burns down as the night goes on.

### 14. Muzzle-flash-adjacent: a forge

```
On Hammer Struck -> Forge Light | Light Flicker: Set Between  Vector2(1.4, 2.2)
                 -> Forge Light | Light Flicker: Stop Flickering  1.0
                 -> Forge Light | Light Flicker: Start Flickering  0.15
```

### 15. Two torches in one room that do not blink together

Nothing to do. Each instance seeds its own noise field, so two behaviours never move in step.

### 16. A 3D lantern, same rows

```
On Ready -> Lantern | Light Flicker: Start Flickering  0
```

The lantern is an `OmniLight3D`; the rows are identical. The pack writes `light_energy` instead of
`energy` because it asked the host, not because the sheet said which.

### Other use cases

**Neon sign on the fritz.** A narrow `between` and a fast rate reads as a sign about to die, and a
single stop row at 0 kills it for the rest of the scene.

**Underwater caustics.** A slow rate with a wide `between` on a light above a pool reads as light
moving through water without a shader.

**A heartbeat monitor's glow.** Two seconds of flicker on a red light, stopped and restarted from
the same rows the machine's beep uses, is a whole atmosphere.

**Lightning-lit room.** Leave the flicker stopped and let a storm row start it for a quarter of a
second at a time.

**A campfire that answers the wood on it.** Every log the player adds raises `between` a little,
which is a one-row upgrade curve with no new code.

## Tips and common mistakes

- **It must be a child of the light, not the light itself.** The behaviour acts on its parent. Put
  it under the light node and it binds on its first frame; put it anywhere else and it warns once
  and then does nothing.
- **A directional light has no reach.** `also_flicker_reach` is ignored there rather than failing -
  a `DirectionalLight2D` and a `DirectionalLight3D` reach everywhere by definition.
- **`between` is a pair, not a range of a maximum.** Both numbers are absolute brightness values,
  the same units the light's own brightness uses, so `Vector2(0.8, 1.2)` on a light authored at 1.0
  brightens as often as it dims.
- **Stopping does not disable the node.** *Stop Flickering* settles the brightness and leaves the
  behaviour there, ready for the next *Start Flickering*. Nothing has to be re-added.
- **The reach is scaled, not set.** Whatever radius the scene was authored with is remembered on the
  first frame, so changing the light's radius in the Inspector while stopped is safe; changing it
  while running is overwritten every frame.
