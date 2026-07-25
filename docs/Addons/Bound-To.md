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

### Inspector properties are ACEs too

Every property this pack exposes in the Inspector is also reachable from the picker, generated for you:
an expression named after the property reads it, a **Set ...** action writes it, and for number properties
**Add To ...** and **Subtract From ...** adjust it by an amount. They sit in the pack's own category
alongside the verbs above, so any knob you can set in the Inspector is also something a sheet can read and
change while the game runs.

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

### 4. Pong paddle

The simplest court: attach to the paddle, set the half-size, and no flick can ever send it
off screen.

```
On Ready -> Paddle | Bound To: Set Bound Extents  8, 48
```

### 5. Edge thump feedback

Give the clamp a voice - a sound and a blink every time the ship presses a side.

```
On Hit Bound -> Ship | play "thump"
             -> Ship | Flash: quick blink
```

The Flash pack sells the "you cannot go further" without any UI text.

### 6. Outro fly-off

Cutscenes want the ship to leave the screen - the one thing the clamp forbids. Disable for
the outro, re-enable on retry.

```
On Outro Start -> Ship | Bound To: Set Bound Enabled  false
On Retry       -> Ship | Bound To: Set Bound Enabled  true
```

### 7. Shrinking boss arena

Each boss phase tightens the fight into a smaller rectangle - no walls to move, one action
per phase.

```
On Phase 2 -> Player | Bound To: Set Custom Bounds  192, 96, 768, 456
On Phase 3 -> Player | Bound To: Set Custom Bounds  384, 192, 384, 264
```

### 8. Grow powerup

A size pickup scales the sprite, so the clamp's half-size must follow - or the big ship hangs
off the edges.

```
On Powerup  -> Ship | Bound To: Set Bound Extents  48, 32
On Wear Off -> Ship | Bound To: Set Bound Extents  24, 16
```

### 9. Push-to-scroll rooms

Classic single-screen adventure: hold against the screen edge and the game pans to the next
room.

```
Every tick
  Condition: Is At Bound  side = "right" -> start the pan to the next room
```

Is At Bound reads "pressed right now", so the pan only starts while the player is actively
pushing.

### 10. Cards stay on the mat

Pair with the Drag & Drop pack: the player can fling a card anywhere, but the clamp runs
every physics frame, so it always settles inside the play mat.

```
On Ready -> Card | Bound To: Set Custom Bounds  96, 400, 960, 240
```

### 11. Shared-screen co-op

The camera follows the midpoint between two players; binding both to the screen means
neither one can sprint out of view and vanish.

```
On Hit Bound -> P1 | show the "wait for your partner" nudge arrow
```

### 12. Breakout walls without walls

The ball needs no collision shapes for the court - flip its velocity on each pressed side
and let the bottom mean a lost ball.

```
On Hit Bound
  Condition: side = "left"   -> set vx to abs(vx)
  Condition: side = "right"  -> set vx to -abs(vx)
  Condition: side = "top"    -> set vy to abs(vy)
  Condition: side = "bottom" -> lose a ball
```

### 13. Camera leash

Bind the Camera2D's follow target to the level rectangle so the view never pans past the
level edge into the void.

```
On Ready -> CamTarget | Bound To: Set Custom Bounds  0, 0, 4096, 648
```

### 14. Reticle by origin

A gamepad aim reticle should keep its CENTER on screen while its art may overhang - turn
`bound_by_edge` off in the Inspector and only the origin is clamped.

```
Every tick -> Reticle | move by the right stick   (the clamp tidies the result)
```

### 15. Tutorial pen, then the world

Start new players in a small practice rectangle, then hand them the whole screen with one
action - the extents never need to change.

```
On Ready         -> Player | Bound To: Set Custom Bounds  384, 174, 384, 300
On Tutorial Done -> Player | Bound To: Set Bound Space  "screen"
```

### Other use cases

**Tower defense build cursor.** Clamp the placement ghost to the buildable field with a custom rectangle, so towers can never be dropped on the HUD strip or outside the map.

**Photo mode camera.** Give the free-fly photo camera a custom rect slightly larger than the arena - players can frame shots from just outside the walls but never fly off into the skybox.

**Virtual joystick thumb.** Bind the mobile stick's thumb sprite to a small custom rectangle over the stick base, so the thumb visual stays readable however far the finger drags.

**Fishing cast marker.** A custom rect over the pond clamps the aim marker while the player lines up a cast, so every throw is guaranteed to land in water.

**Racing minimap blips.** Bind each car's blip to the minimap panel - cars far ahead pin to the frame edge instead of drifting over the rest of the HUD.

## Tips and common mistakes

- **Half-size is yours to set.** The pack does not measure your sprite - set the extents (or
  call Set Bound Extents when the sprite changes size).
- **It clamps position, not physics.** A CharacterBody2D keeps its velocity while pressed
  against a bound; the position just stops. For physical walls, use collision shapes - this
  pack is for screen-space rules.
- **Pair with Wrap, not both on one axis.** Bound clamps, Wrap teleports - one node should do
  one or the other per axis.
