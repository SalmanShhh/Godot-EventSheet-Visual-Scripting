# Platformer Pathfinding - Jump-Aware Navigation for 2D Platformers

Platformer Pathfinding gives an enemy (or ally) the ability to actually CHASE you through a
platformer level: around platforms, up stairs, across gaps - jumping where a jump is needed,
walking where walking works. Godot's built-in navigation is made for top-down/3D surfaces;
platformers need a jump graph, and that is what this pack builds. Attach a
`PlatformerPathfinding` behavior as a SIBLING of `PlatformerMovement` under a `CharacterBody2D`,
build the graph from your `TileMapLayer` once, and call **Find Path To** - the pathfinder
derives jump reach from the movement pack's real physics and drives it through its
`ai_move_axis` seam, so the agent moves under exactly the same rules the player does.

The bundled **Path Chase** showcase (`demo/showcase/path_chase/`) is the reference setup: a
keyboard Player, a chasing agent, and the debug path line visible.

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

- **A chaser in three rows.** Build the graph on ready, Find Path To Node the player on a
  timer, done - the enemy walks, jumps gaps, and climbs platforms to reach you.
- **It jumps like the player jumps.** Jump height and distance are DERIVED from the sibling
  PlatformerMovement's `jump_velocity`, `gravity`, and `move_speed` - retune the movement feel
  and the pathfinder's idea of "reachable" retunes itself.
- **Movement stays yours.** Pathfinding never moves the body: it steers the movement pack
  through a two-variable intent seam (`ai_controlled` + `ai_move_axis`) plus its `jump()` verb.
  Wall slide, coyote time, acceleration - every movement feature keeps working under AI drive.
- **Manual mode for custom drivers.** Turn Set Auto Control off and the paths still compute -
  read Path Move Axis / Path Wants Jump / Current Waypoint X/Y and drive an animation state
  machine or your own physics.
- **Portals are one action.** Add Portal links two spots; an agent whose route uses it walks
  to the entrance and blinks to the exit (On Portal Taken). Doors, teleporters, ladders, and
  elevators all model as portals - and they survive graph rebuilds.
- **Moving level? Regenerate.** Toggle tiles at runtime (a bridge, a collapsing floor), call
  Regenerate Nav Graph, and every next route sees the new level - the Path Chase showcase flips
  a bridge every 3 seconds and the chaser re-routes live.
- **No movement pack? Still works.** With no movement sibling the built-in fallback driver
  moves the CharacterBody2D itself (fallback speed/jump/gravity knobs) - attach ONE behavior to
  any body and it pathfinds.
- **Variable jump (toggleable, on by default).** Each jump releases at the height its arc
  actually needs - flat gap hops stay low and quick, tall ledges get the full rise. Movement
  looks intentional instead of every hop being a moon jump.
- **See it think.** Set Nav Debug Draw paints the live route as a line in the world.

## Core concepts

**The graph is built once, from your tiles.** Build Nav Graph From Tilemap scans the
`TileMapLayer`'s physics tiles: every solid cell with two cells of headroom above it becomes a
standable NODE. Nodes one cell apart (up to one step up or down - stairs) connect with WALK
edges; farther nodes within the derived jump reach connect with JUMP arcs; drops within Max
Fall Distance connect with FALL edges. Walking costs less than jumping, so the router prefers
ramps and stairs over hops when both work.

**Paths are cell waypoints; driving is an intent.** Each physics tick with an active path the
behavior resolves the current waypoint into an intent - a move axis (-1..1) and a want-jump
flag - and feeds the sibling movement pack. Full-block stairs get a STEP-ASSIST hop
automatically (a walking body cannot step up a full tile).

**Reach and nearest.** Find Path To's mode decides what happens when the target spot is not on
the graph: `reach` fails honestly (On Path Failed - play the confused animation), `nearest`
never fails - it routes to the closest reachable node instead (the right default for chasing).

## Setup

1. Your level is a `TileMapLayer` whose TileSet tiles carry physics collision polygons (the
   normal platformer setup).
2. Under the agent's `CharacterBody2D`, attach **PlatformerMovement** and
   **PlatformerPathfinding** as siblings (Tools > Attach to Selected Node twice, or drag both
   `.gd` files in).
3. Three rows:

```
On Ready
  -> Chaser | Pathfinding: Build Nav Graph From Tilemap  $Level
Every 1 seconds
  -> Chaser | Pathfinding: Find Path To Node  $Player, "nearest"
On Path Failed
  -> (optional) play a confused sound
```

Press play. The agent routes to the player and re-routes every second as the player moves.

## ACE reference

All ACEs live in the **Platformer Pathfinding** category and target the behavior on the node
they are placed on.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Build Nav Graph From Tilemap | `tilemap` (Node) | Scans the TileMapLayer's physics tiles into the graph (nodes + walk/jump/fall edges, jump reach derived from the movement sibling). Call once on ready. Fires On Nav Graph Built. |
| Regenerate Nav Graph | (none) | Rebuilds from the same tilemap after runtime tile edits. |
| Find Path To | `x`, `y` (float), `mode` (`nearest`/`reach`) | Routes to a world position and starts moving. `reach` fails when the spot is unreachable; `nearest` goes to the closest reachable node instead. Fires On Path Found / On Path Failed. |
| Find Path To Node | `target` (Node), `mode` | Find Path To with the position read for you - re-call on a timer to chase. |
| Stop Pathfinding | (none) | Clears the path and hands the movement pack back to the keyboard. |
| Add Portal | `from_x`, `from_y`, `to_x`, `to_y` (float), `bidirectional` (bool) | Links two world positions: routes through it walk to the entrance and BLINK to the exit (On Portal Taken). Survives Regenerate. |
| Clear Portals | (none) | Removes every registered portal. |
| Set Auto Control | `enabled` (bool) | On (default): drive the sibling movement pack. Off: paths compute, you drive. |
| Set Nav Debug Draw | `enabled` (bool) | Draw the active path as a line in the world. |

### Conditions, expressions, and triggers

| Kind | Name | Description |
|---|---|---|
| Condition | Has Path | An active path exists. |
| Condition | Path Wants Jump | The drive wants a jump right now (jump arc, or a step-assist hop) - the manual-mode jump signal. |
| Expression | Path Move Axis | The current steering, -1..1 - feed it to your own driver in manual mode. |
| Expression | Current Waypoint X / Y | The waypoint being moved toward, in world pixels. |
| Expression | Waypoint Count / Current Waypoint Index | Path length and progress. |
| Expression | Current Path Action | What this leg is: `walk`, `jump`, `fall`, or `portal`. |
| Trigger | On Path Found / On Path Failed / On Path Complete | The reaction trio. |
| Trigger | On Waypoint Reached | Each waypoint passed. |
| Trigger | On Nav Graph Built | The scan finished. |
| Trigger | On Portal Taken | The agent just blinked through a portal. |

### Inspector properties

| Property | Default | What it does |
|---|---|---|
| `auto_control` | `true` | Drive the sibling movement pack automatically. |
| `arrive_distance` | `10.0` | How close (px) counts as reaching a waypoint. |
| `max_fall_distance` | `320.0` | The furthest safe drop the graph will route through. |
| `jump_height_override` | `0.0` | Max jump height in px (0 = derive from the movement pack). |
| `jump_distance_override` | `0.0` | Max jump distance in px (0 = derive). |
| `debug_draw` | `false` | Draw the active path. |
| `variable_jump` | `true` | Release each jump at the height its arc needs (smoother hops). Off = full-height jumps always. |
| `fallback_move_speed` / `fallback_jump_velocity` / `fallback_gravity` | `200 / -400 / 980` | The built-in driver used when no movement sibling exists (also sizes arcs then). |

## Use cases

### 1. The chaser

The whole showcase in three rows - build once, re-route on a timer, nearest mode so it never
gives up.

```
On Ready         -> Enemy | Pathfinding: Build Nav Graph From Tilemap  $Level
Every 1 seconds  -> Enemy | Pathfinding: Find Path To Node  $Player, "nearest"
```

### 2. A patrol between posts

Walk to post B, then back to post A, forever - On Path Complete is the turnaround signal.

```
On Ready           -> Guard | Pathfinding: Find Path To  1200, 400, "reach"
On Path Complete
  Condition: at_post_b is false
    -> set at_post_b to true
    -> Guard | Pathfinding: Find Path To  200, 400, "reach"
  Else
    -> set at_post_b to false
    -> Guard | Pathfinding: Find Path To  1200, 400, "reach"
```

### 3. Give up gracefully

Reach mode + the failure trigger = a searching animation instead of an enemy vibrating
against a wall.

```
Every 2 seconds  -> Enemy | Pathfinding: Find Path To Node  $Player, "reach"
On Path Failed   -> Enemy | Flash: Flash  0.3   (and play "confused")
```

### 4. Fetch quest companion

An ally that runs to whatever you click: Mouse Position (world) feeds Find Path To.

```
On Input
  Condition: On MOUSE_BUTTON_LEFT pressed (event)
    -> Buddy | Pathfinding: Find Path To  mouse world x, mouse world y, "nearest"
```

### 5. Manual drive for a flying-animation hybrid

Auto control off; the sheet reads the intents and drives its own animation-heavy controller.

```
On Ready    -> Boss | Pathfinding: Set Auto Control  false
Every tick
  -> set my_velocity_x to $Boss/Pathfinding.path_move_axis() * 260
  Condition: Boss | Pathfinding: Path Wants Jump
    -> (trigger the leap animation, then apply the jump)
```

### 6. Rebuild after destruction

Destructible terrain? Rebuild the graph when the level changes and re-route.

```
On Wall Destroyed
  -> Enemy | Pathfinding: Regenerate Nav Graph
  -> Enemy | Pathfinding: Find Path To Node  $Player, "nearest"
```

## Tips and common mistakes

- **A movement sibling is best, not required.** The pathfinder finds the movement pack among
  the host's children (anything with a `move_speed` and a `jump()`), derives jump reach from
  it, and steers it through the standard AI drive seam (`ai_controlled` + `ai_move_axis` -
  PlatformerMovement, 8-Direction, and the FPS Controller all carry it, inert until an AI
  flips it on). With no sibling, the built-in fallback driver moves the body itself using the
  fallback knobs.
- **Build the graph AFTER the level exists.** On Ready is right for a static level; if you
  generate tiles at runtime, build after generating (and Regenerate after edits).
- **The graph is cells, the drive is physics.** The router plans in tile cells; the movement
  pack executes under real physics. If an agent misses a jump the router thought possible,
  lower the overrides slightly or widen the gap's platforms - the derivation already applies a
  10% safety margin.
- **Re-route on a timer, not every tick.** Chasing re-plans the whole path; once a second reads
  as relentless and costs nothing. Every tick is wasted work and mid-air flip-flopping.
- **`nearest` for chasing, `reach` for scripted moves.** A chaser should get as close as it
  can; a cutscene walk-to-mark should fail loudly if the mark is unreachable.
- **Tune with the debug line on.** Set Nav Debug Draw during development; the green line shows
  exactly what the router decided, which makes level-layout problems obvious.
