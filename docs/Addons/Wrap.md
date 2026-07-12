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

## Tips and common mistakes

- **Set the half-size honestly.** Too small and the sprite pops while half-visible; too big
  and there is a long invisible gap. Half the sprite is right.
- **Fast movers still wrap cleanly** - the re-entry point is placed fully outside the
  opposite edge, so a bullet glides in instead of popping mid-screen.
- **Circle wraps ignore the per-axis toggles** - a circle has no left edge to switch off; the fully-outside test uses the larger half-size.
- **Bound or Wrap, not both on one axis.** They fight: one clamps at the edge the other
  teleports across.
