# Bound To - Keep Anything Inside the Screen or an Area

The event-sheet-parity "bound to layout" behavior: attach to any Node2D and it stays inside
the **screen** (the camera's live view) or a **custom rectangle**, clamped every physics
frame. Bind by edge (the whole sprite stays visible) or by origin. **On Hit Bound** fires
once per press against each side, so bump feedback is one row.

## Where this pack shines

- **Player ships and paddles.** The classic arcade clamp - attach, set the half-size, done.
- **Cameras and cursors.** Bind a Camera2D target or a custom cursor to the playable area.
- **Arena fences without walls.** A custom rect keeps enemies in the arena with no collision
  shapes - and `On Hit Bound` doubles as "reached the fence, turn around".

## Setup

1. Attach `BoundToBehavior` as a child of the node to keep inside.
2. Set `half_width` / `half_height` to half your sprite's size (edge binding), or turn
   `bound_by_edge` off to bind the origin alone.
3. Default space is `screen`; call `Set Custom Bounds` for a fixed world-space area.

```
On Hit Bound -> Ship | Juice: Shake Screen  4, 0.15   (side is the trigger's parameter)
```

## ACE reference

| Kind | Name | Parameters | Description |
|---|---|---|---|
| Action | Set Bound Enabled | `enabled` | On/off at runtime (off = moves freely). |
| Action | Set Bound Space | `space` (`screen`/`custom`) | What to stay inside. |
| Action | Set Custom Bounds | `x`, `y`, `width`, `height` | World-space rect; switches the space to it. |
| Action | Set Bound Extents | `new_half_width`, `new_half_height` | Half-size used by edge binding. |
| Condition | Is At Bound | `side` (`left`/`right`/`top`/`bottom`/`any`) | Pressed against a bound right now. |
| Trigger | On Hit Bound | `side` | Fired once per press against a side (re-arms on release). |

### Inspector properties

| Property | Default | What it does |
|---|---|---|
| `bound_space` | `screen` | Camera view or the custom rectangle. |
| `bound_by_edge` | `true` | Edges stay inside (origin + half-size) vs origin only. |
| `half_width` / `half_height` | `16` | The host's half-size for edge binding. |
| `bound_enabled` | `true` | Master switch. |

## Use cases

### 1. The arcade ship

Attach, set half-size to the sprite, done - the ship can never leave the screen, even when
the camera moves (the screen rect is computed from the live camera view every frame).

### 2. Minimap cursor in a panel

```
On Ready -> Cursor | Bound To: Set Custom Bounds  832, 32, 288, 288
```

### 3. Patrol without walls

```
On Hit Bound
  Condition: side = "left"  -> set dir to 1
  Condition: side = "right" -> set dir to -1
```

## Tips and common mistakes

- **Half-size is yours to set.** The pack does not measure your sprite - set the extents (or
  call Set Bound Extents when the sprite changes size).
- **It clamps position, not physics.** A CharacterBody2D keeps its velocity while pressed
  against a bound; the position just stops. For physical walls, use collision shapes - this
  pack is for screen-space rules.
- **Pair with Wrap, not both on one axis.** Bound clamps, Wrap teleports - one node should do
  one or the other per axis.
