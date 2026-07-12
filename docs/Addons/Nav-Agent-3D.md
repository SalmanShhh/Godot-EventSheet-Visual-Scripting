# Nav Agent 3D - Navmesh Pathfinding for 3D, Sheet-Shaped

Nav Agent 3D makes Godot's 3D navigation usable from event rows with zero wiring: attach the
`NavAgent3D` behavior under a `CharacterBody3D`, have a `NavigationRegion3D` in the scene, and
call **Find Path To** - a `NavigationAgent3D` child is inserted and tuned for you, the route
comes from the baked navmesh, and the agent moves. The verbs deliberately MIRROR the 2D
**Platformer Pathfinding** pack (Find Path To / Find Path To Node / Stop Pathfinding, the
Found/Failed/Complete trio, Has Path, `nearest`/`reach` modes) - learn one pack, know both.
The dimensions just differ in tech: 2D platformers need a jump graph, 3D worlds are walkable
surfaces, and Godot's navmesh already represents those perfectly - so this pack wraps it
instead of reinventing it.

The bundled **FPS Arena** showcase has an orange Stalker that navmesh-paths to the player.

---

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Setup](#setup)
3. [ACE reference](#ace-reference)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **A 3D chaser in two rows.** Bake (or pre-bake) the navmesh, Find Path To Node the player on
  a timer - the agent routes around crates, walls, and slopes.
- **Zero wiring.** No NavigationAgent3D to add or configure by hand: the behavior inserts one,
  tunes it from the Inspector knobs (radius, height, arrive distance), and connects its signals
  to sheet triggers.
- **Drives the FPS Controller through the universal AI seam.** With an `FPSController` sibling,
  auto-control writes its `ai_move_x`/`ai_move_z` - the agent moves with the controller's own
  speed, gravity, and feel. With no driver, the built-in mover drives the body itself
  (Move Speed / Gravity knobs).
- **Slopes come free.** The navmesh bake's max-angle setting decides what is walkable - ramps,
  hills, and stairs need nothing registered. `Bake Navigation Region` rebakes at runtime after
  the level changes.
- **Avoidance is a toggle.** Set Avoidance on and agents (using the built-in mover) steer
  around each other with Godot's RVO avoidance.

## Setup

1. Your walkable geometry lives under a `NavigationRegion3D` with a `NavigationMesh` resource -
   either baked in the editor (the normal Godot flow) or at runtime with the pack's
   `Bake Navigation Region` action.
2. Attach `eventsheet_addons/nav_agent_3d/nav_agent_3d_behavior.gd` under the agent's
   `CharacterBody3D`.
3. Two rows:

```
On Ready         -> Stalker | Nav Agent 3D: Bake Navigation Region  $NavRegion
Every 1 seconds  -> Stalker | Nav Agent 3D: Find Path To Node  $Player, "nearest"
```

Press play. The agent routes to the player across the mesh and re-routes as they move.

## ACE reference

All ACEs live in the **Nav Agent 3D** category and target the behavior on the node they are
placed on.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Find Path To | `x`, `y`, `z` (float), `mode` (`nearest`/`reach`) | Routes to a world position across the navmesh and starts moving. `reach` fails (On Path Failed) when the spot is off the mesh; `nearest` never fails. |
| Find Path To Node | `target` (Node), `mode` | Find Path To with the position read for you - re-call on a timer to chase. |
| Stop Pathfinding | (none) | Clears the path and hands the driver sibling back to the player. |
| Set Auto Control | `enabled` (bool) | On (default): drive the sibling controller or the body. Off: paths compute, you drive (read Path Move X/Z). |
| Set Avoidance | `enabled` (bool) | RVO avoidance between agents (applies to the built-in mover). |
| Set Move Speed | `value` (float) | The built-in mover's speed, m/s. |
| Bake Navigation Region | `region` (Node) | Rebakes a NavigationRegion3D's mesh from its current child geometry, at runtime. |

### Conditions, expressions, and triggers

| Kind | Name | Description |
|---|---|---|
| Condition | Has Path | An active path exists. |
| Condition | Target Is Reachable | The current target sits on the navmesh. |
| Expression | Current Waypoint X / Y / Z | The point being moved toward. |
| Expression | Distance To Target | Straight-line metres to the target. |
| Expression | Path Move X / Z | The current steering (-1..1, world axes) - the manual-mode feed. |
| Trigger | On Path Found / On Path Failed / On Path Complete | The reaction trio (same names as 2D). |
| Trigger | On Waypoint Reached | Each navmesh waypoint passed. |

### Inspector properties

| Property | Default | What it does |
|---|---|---|
| `auto_control` | `true` | Drive the sibling controller / the body automatically. |
| `move_speed` | `4.0` | Built-in mover speed (m/s). |
| `gravity` | `9.8` | Built-in mover gravity. |
| `agent_radius` / `agent_height` | `0.5` / `1.8` | The navigation agent's body (match your collider). |
| `target_desired_distance` | `1.0` | How close (m) counts as arrived. |
| `avoidance_enabled` | `false` | Agents steer around each other (built-in mover). |

## Use cases

### 1. The stalker (the showcase)

```
On Ready         -> Stalker | Nav Agent 3D: Bake Navigation Region  $NavRegion
Every 1 seconds  -> Stalker | Nav Agent 3D: Find Path To Node  $Player, "nearest"
```

### 2. Click-to-move

Pair with the Mouse Ray expressions: cast the cursor's ray, route to the hit point.

```
On Input
  Condition: On MOUSE_BUTTON_LEFT pressed (event)
    -> (raycast from Mouse Ray Origin (3D) along Mouse Ray Direction (3D), store hit)
    -> Unit | Nav Agent 3D: Find Path To  hit_x, hit_y, hit_z, "nearest"
```

### 3. A patrol loop

```
On Path Complete
  -> next_post = (next_post + 1) % 4
  -> Guard | Nav Agent 3D: Find Path To Node  posts[next_post], "reach"
```

### 4. A crowd that does not clip

Ten wanderers, one toggle: `Set Avoidance true` on each and the built-in movers flow around
each other.

### 5. Out-of-bounds honesty

`reach` mode + On Path Failed: a fetch companion refuses marks that are off the mesh instead of
walking into a wall forever.

## Tips and common mistakes

- **No NavigationRegion3D = no paths.** The scene needs one, with geometry under it, baked
  (editor-baked or the Bake action on ready). On Path Failed firing immediately usually means
  the mesh is missing or empty.
- **Bake AFTER the level exists.** Runtime-generated geometry? Bake on ready, and rebake after
  changes - agents see the new mesh on their next Find Path To.
- **Match the agent to the collider.** `agent_radius`/`agent_height` should match your capsule,
  or the agent will hug walls it cannot actually fit past.
- **The driver owns the feel.** With an FPS Controller sibling, speed and gravity come from the
  CONTROLLER (the pack only steers); the Move Speed knob is for the built-in mover.
- **2D platformer? Different pack.** Navmeshes have no concept of jumping - a side-view
  platformer needs the **Platformer Pathfinding** pack's jump graph. This pack is for worlds
  where walking (on any slope the bake allows) gets you everywhere.
