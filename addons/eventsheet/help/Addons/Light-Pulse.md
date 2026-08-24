# Light Pulse - A Light That Breathes

Some lights should read as deliberate rather than as merely alight: a beacon, a health pickup, a
rune in a door, a charging weapon. That is a smooth wave on a clock, and this pack is that wave.

It is the same shape as **Light Flicker** beside it - the same two rows, the same question, the same
hosts - and differs in exactly one way: where the flicker walks a noise field, the pulse rides a
cosine. Period is the length of one whole breath, so a designer sets a **rhythm** rather than a
speed, and two pulses set to the same period stay in time with each other.

Like the flicker, it works on **any light, 2D or 3D**, because it asks its host which property that
host spells brightness with rather than naming a light class.

## Where this pack shines

- **Pickups and interactables.** A pulsing light is the oldest "you can take this" signal there is.
- **Beacons and objectives.** Slow and wide reads as a landmark; fast and narrow reads as an alarm.
- **Charge-ups.** Shorten `period_seconds` as a meter fills and the light tells the player how close
  they are without a HUD element.
- **Anything that should look powered.** A rune, a portal, a reactor, a phone on a table.

## Setup

1. Add a `LightPulseBehavior` node as a **child of the light** it should animate.
2. Set `between` to the dimmest and brightest you want, and `period_seconds` to the length of one
   whole breath.
3. Leave `running` on and it breathes the moment the scene does.

```
On Ready -> Beacon | Light Pulse: Start Pulsing  0
```

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, exactly as the
rows draw them:

- Start pulsing after **after_seconds** s
- Stop pulsing and settle at **settle_at**

| Kind | Name | Parameters | Description |
|---|---|---|---|
| Action | Start Pulsing | `after_seconds` | Starts the pulse, now or after a delay. |
| Action | Stop Pulsing | `settle_at` | Stops it and leaves the light at one steady brightness. |
| Condition | Is Pulsing | - | True while it is really pulsing: false while it waits out a delay, and false once stopped. |

Every exported knob is also a row: **Set Between**, **Set Period Seconds**, **Add To Period
Seconds**, **Set Running**, and the expressions that read each of them back.

### Inspector properties

| Property | Default | What it does |
|---|---|---|
| `between` | `Vector2(0.6, 1.4)` | The dimmest and brightest the light gets. |
| `period_seconds` | `2.0` | How long one whole breath takes, dim to bright and back. |
| `running` | `true` | Whether it is pulsing right now. |

## Use cases

### 1. A pickup that asks to be taken

```
On Ready -> Coin Light | Light Pulse: Start Pulsing  0
```

### 2. Stopping the moment it is taken

```
On Body Entered -> Coin Light | Light Pulse: Stop Pulsing  0
                -> Coin: Queue Free
```

### 3. A quest marker that only breathes while the quest is active

```
On Quest Started  -> Marker | Light Pulse: Start Pulsing  0
On Quest Finished -> Marker | Light Pulse: Stop Pulsing  0.2
```

### 4. A beacon and its echo

```
On Ready -> Beacon A | Light Pulse: Start Pulsing  0
         -> Beacon B | Light Pulse: Start Pulsing  1.0
```

Same period, half a breath apart: the delay is what makes the pair read as a sequence.

### 5. A charge-up that speeds up as it fills

```
Every tick -> Weapon Light | Light Pulse: Set Period Seconds  2.0 - charge * 1.8
```

### 6. An alarm

```
On Alarm Raised -> Alarm Light | Light Pulse: Set Period Seconds  0.35
                -> Alarm Light | Light Pulse: Set Between  Vector2(0.1, 2.0)
                -> Alarm Light | Light Pulse: Start Pulsing  0
```

### 7. A calm light that becomes the alarm and back

```
On Alarm Cleared -> Alarm Light | Light Pulse: Set Period Seconds  2.0
                 -> Alarm Light | Light Pulse: Set Between  Vector2(0.6, 1.4)
```

Nothing has to be stopped: the wave picks up the new numbers on the next frame without snapping,
because the breath keeps its own position.

### 8. A door that shows it is locked

```
On Ready
  NOT Player Has Key -> Door Rune | Light Pulse: Set Between  Vector2(0.1, 0.4)
                     -> Door Rune | Light Pulse: Start Pulsing  0
```

### 9. And unlocks

```
On Key Collected -> Door Rune | Light Pulse: Set Between  Vector2(0.8, 1.8)
```

### 10. A low-health heartbeat

```
Health < 25 -> Player Light | Light Pulse: Set Period Seconds  0.8
            -> Player Light | Light Pulse: Start Pulsing  0
Health >= 25 -> Player Light | Light Pulse: Stop Pulsing  1.0
```

### 11. Asking whether a light is still signalling

```
Player pressed "interact"
  Marker | Light Pulse: Is Pulsing -> Dialogue Kit: Say  "This one is still live."
```

### 12. A reactor that idles and then surges

```
On Reactor Overload -> Reactor Light | Light Pulse: Set Period Seconds  0.2
                    -> Timer: Start  "cool_down" for 4 s
On Timer "cool_down" -> Reactor Light | Light Pulse: Set Period Seconds  3.0
```

### 13. A 3D lamp post at dusk

```
On Sunset -> Lamp | Light Pulse: Start Pulsing  0.4
```

The lamp is an `OmniLight3D`; the pack writes `light_energy` because it asked the lamp, not because
the row said so. Pair it with **Day/Night Cycle**, whose On Sunset trigger this is.

### 14. Every streetlight on the same street, in time

Give every lamp the same `period_seconds` and no delay. A cosine on a shared clock keeps them in
step for as long as the scene runs - there is no drift to accumulate.

### 15. A lighthouse

```
On Ready -> Lighthouse | Light Pulse: Set Period Seconds  6.0
         -> Lighthouse | Light Pulse: Set Between  Vector2(0.0, 3.0)
         -> Lighthouse | Light Pulse: Start Pulsing  0
```

Reaching 0 at the bottom of the breath is what makes the sweep read as a rotation.

### 16. Fading a pulse out at the end of a level

```
On Level Complete -> Beacon | Light Pulse: Stop Pulsing  1.0
                  -> Beacon | Lighting: Fade to 0 over 2 s
```

Stop the wave first, then fade: a tween and a per-frame write on the same property fight otherwise.

### Other use cases

**Save point.** A slow blue pulse is the universal "you are safe here", and one row turns it off
once the point has been used.

**Boss tell.** Shorten the period for the two seconds before an attack and the light IS the wind-up
animation.

**Stealth detection meter.** Map `period_seconds` to how close the guard is to spotting the player
and the room itself becomes the meter.

**Radio tower.** A long period on a very wide `between` reads as an aircraft warning light from
across a whole level.

**Puzzle rhythm.** Give three lights three periods and ask the player to press each at its peak -
`Is Pulsing` and the expressions do the checking.

## Tips and common mistakes

- **It must be a child of the light, not the light itself.** The behaviour acts on its parent; put
  it anywhere else and it warns once and then does nothing.
- **Period is a length, not a speed.** Bigger is slower. Setting it to 0.1 is ten breaths a second,
  which is an alarm, not a pulse.
- **The breath starts at the dim end.** The wave is a cosine rather than a sine on purpose, so a
  light that begins pulsing does not jump to full brightness on its first frame.
- **Do not tween the same property while it pulses.** A per-frame write and a tween on the same
  brightness will fight, and the tween usually loses. Stop the pulse first.
- **This and Light Flicker are two behaviours, not two settings.** They can both sit under one light
  if that is really wanted, but the last one to run each frame wins - pick one.
