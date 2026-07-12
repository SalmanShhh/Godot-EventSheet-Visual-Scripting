# Wrap - Asteroids-Style Screen Wrapping

Once the host is **fully outside** one edge of the screen (or a custom rectangle) it
teleports to the opposite edge - fly off the right, glide in from the left. Per-axis
toggles, world- or camera-space, and **On Wrapped** tells you which side was crossed.

## Where this pack shines

- **Asteroids in one attach.** Ships, rocks, and bullets all wrap with zero rows.
- **Endless scrollers.** Wrap vertical only and reuse the same obstacles forever.
- **Pac-Man tunnels.** A custom rect wraps the maze row while the HUD stays put.

## Setup

1. Attach `WrapBehavior` as a child of the node that should wrap.
2. Set `half_width` / `half_height` to half the sprite (it must be FULLY off screen before
   wrapping - no popping while still visible).
3. Default space is `screen`; `Set Custom Wrap Bounds` pins a fixed world-space area.

```
On Wrapped -> Ship | Fade Out: Fade In  0.15   (a soft blink as it re-enters)
```

## ACE reference

| Kind | Name | Parameters | Description |
|---|---|---|---|
| Action | Set Wrap Enabled | `enabled` | On/off at runtime. |
| Action | Set Wrap Space | `space` (`screen`/`custom`) | What to wrap around. |
| Action | Set Custom Wrap Bounds | `x`, `y`, `width`, `height` | World-space rect; switches the space (and shape) to it. |
| Action | Set Circle Wrap Bounds | `center_x`, `center_y`, `radius` | A CIRCULAR constraint: fully outside the circle teleports to the antipode - a round arena in one action. |
| Action | Set Wrap Axes | `horizontal`, `vertical` (bool) | Which edges wrap. |
| Action | Set Wrap Extents | `new_half_width`, `new_half_height` | Half-size for the fully-outside test. |
| Trigger | On Wrapped | `side` (`left`/`right`/`top`/`bottom`) | Fired on each teleport, naming the side it LEFT from. |

### Inspector properties

| Property | Default | What it does |
|---|---|---|
| `wrap_space` | `screen` | Camera view or the custom constraint. |
| `wrap_shape` | `rect` | The custom constraint shape: rectangle edges, or a circle (antipodal wrap). |
| `wrap_circle_center` / `wrap_circle_radius` | `(576, 324)` / `300` | The circular arena, when the shape is circle. |
| `wrap_horizontal` / `wrap_vertical` | `true` | Per-axis wrapping. |
| `half_width` / `half_height` | `16` | Half the sprite - wraps only when fully outside. |
| `wrap_enabled` | `true` | Master switch. |

## Use cases

### 1. Asteroids, complete

Attach Wrap to the ship, every rock, and every bullet. That is the whole feature.

### 2. Wrap-around maze row

```
On Ready -> Player | Wrap: Set Custom Wrap Bounds  0, 256, 1152, 64
         -> Player | Wrap: Set Wrap Axes  true, false
```

### 3. A round arena

```
On Ready -> Ship | Wrap: Set Circle Wrap Bounds  576, 324, 300
```

Fly out through any point of the circle and glide back in from the opposite side - the
antipodal wrap keeps momentum readable. On Wrapped still reports the dominant exit side.

### 4. Score the loop

```
On Wrapped
  Condition: side = "bottom" -> add 1 to laps   (a falling-loop game counts wraps)
```

### 5. Scenery recycler

Three cloud sprites drifting left and wrapping in from the right read as an endless sky -
turn vertical wrap off so they never leave their altitude band.

```
On Ready -> Cloud | Wrap: Set Wrap Axes  true, false
```

### 6. Snake, wall-less mode

The classic variant: attach to the head and the snake pours out one side of the screen and
back in the other.

```
On Wrapped -> Head | play "warp" blip
```

### 7. Boss room seals the exits

When the boss drops in, the arena stops being a torus: turn the wrap off and let the Bound To
pack clamp the edges instead - then hand the wrap back after the kill.

```
On Boss Spawn -> Ship | Wrap: Set Wrap Enabled  false
On Boss Down  -> Ship | Wrap: Set Wrap Enabled  true
```

### 8. Re-entry blink

Pair with the Flash pack: a short blink on every teleport tells players the warp was the
game's idea, not a glitch.

```
On Wrapped -> Ship | Flash: quick blink
```

### 9. Auto-scroller recycling

Screen space tracks the LIVE camera, so in an auto-scroller the obstacles that fall off the
back wrap in ahead of the player - reshuffle them on the way through.

```
On Wrapped
  Condition: side = "left" -> set obstacle y to random(80, 560)
```

### 10. The blob that grows

Every meal scales the sprite up, so keep the fully-outside test honest - or the big blob pops
while still half-visible.

```
On Ate Something -> Blob | Wrap: Set Wrap Extents  blob_radius, blob_radius
```

### 11. Phase-warp powerup

In a walled arena (`wrap_enabled` off in the Inspector), a pickup grants five seconds of
Asteroids rules - the Timer pack turns them back off.

```
On Powerup -> Player | Wrap: Set Wrap Enabled  true
           -> Player | Timer: after 5 seconds, Set Wrap Enabled  false
```

### 12. Frogger traffic

Each car loops its own road strip forever - make the rect wider than the screen so cars
finish leaving the view before they wrap.

```
On Ready -> Car | Wrap: Set Custom Wrap Bounds  -64, 200, 1280, 320
         -> Car | Wrap: Set Wrap Axes  true, false
```

### 13. Ambient leaves

A handful of wind-blown leaves wrapping on all four sides is infinite ambience - re-roll the
drift on each pass so the loop never reads as a loop.

```
On Wrapped -> Leaf | set drift_speed to random(20, 60)
```

### 14. Bullets wrap twice, then die

Wrapping bullets are fun until the screen fills with immortal shots - count the teleports and
retire each bullet after its second lap.

```
On Wrapped -> Bullet | add 1 to wrap_count
Every tick
  Condition: wrap_count >= 2 -> Bullet | queue free
```

### 15. Split-screen halves

Shared-screen versus: each player wraps inside their own half, so both arenas are tori but
nobody crosses into the rival's side.

```
On Ready -> P1 | Wrap: Set Custom Wrap Bounds  0, 0, 576, 648
         -> P2 | Wrap: Set Custom Wrap Bounds  576, 0, 576, 648
```

### Other use cases

**Orbital debris field.** A circle wrap around a space station keeps a cloud of drifting junk endlessly circulating without a single spawn or despawn row.

**Attract-mode logo.** The idle-screen logo drifts diagonally and wraps forever, screensaver style, while the game waits for a coin.

**Background street parade.** A dozen NPC silhouettes walking one way and wrapping horizontally fake a whole city crowd behind the playfield.

**Torus overworld.** A top-down explorer with a custom rect the size of the whole map wraps both axes, so sailing east eventually brings you home from the west.

**Rhythm conveyor.** Note icons ride a custom strip and wrap back to the feeder side, recycling the same handful of nodes for an endless song.

## Tips and common mistakes

- **Set the half-size honestly.** Too small and the sprite pops while half-visible; too big
  and there is a long invisible gap. Half the sprite is right.
- **Fast movers still wrap cleanly** - the re-entry point is placed fully outside the
  opposite edge, so a bullet glides in instead of popping mid-screen.
- **Circle wraps ignore the per-axis toggles** - a circle has no left edge to switch off; the fully-outside test uses the larger half-size.
- **Bound or Wrap, not both on one axis.** They fight: one clamps at the edge the other
  teleports across.
