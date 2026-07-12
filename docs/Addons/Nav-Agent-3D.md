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

### 6. Retreat to the healing fountain

A bruiser that breaks off the fight when it is hurt. Pair with the Health pack for the damage
bookkeeping; the retreat itself is one path.

```
Every 0.5 seconds
  Condition: ogre_health < 25
    -> Ogre | Nav Agent 3D: Find Path To Node  $Fountain, "reach"
On Path Complete -> (refill ogre_health, resume the chase)
```

`reach` mode means a walled-off fountain fails loudly instead of luring the ogre into a corner.

### 7. Walk when far, sprint when close

Distance To Target feeding Set Move Speed: a zombie shambles across the map, then lunges.

```
Every 0.5 seconds
  Condition: Zombie | Nav Agent 3D: Distance To Target > 10
    -> Zombie | Nav Agent 3D: Set Move Speed  1.5
  Else
    -> Zombie | Nav Agent 3D: Set Move Speed  5.0
```

Set Move Speed tunes the built-in mover; with an FPS Controller sibling the controller owns speed.

### 8. Footsteps on waypoints

On Waypoint Reached fires at each navmesh waypoint passed - a free hook for corner scuffs and
dust puffs with no timers.

```
On Waypoint Reached -> (play a gravel step, puff dust at the agent's feet)
```

On big open mesh the waypoints are sparse, so treat this as a corner cue, not a per-step one.

### 9. "I'll get as close as I can"

`nearest` mode always produces a route, but Target Is Reachable tells you whether the exact spot
is on the mesh - the honest voice line for squad orders.

```
On Order Issued
  -> Unit | Nav Agent 3D: Find Path To  order_x, order_y, order_z, "nearest"
  Condition: Unit | Nav Agent 3D: Target Is Reachable  is false
    -> Unit says "I'll get as close as I can."
```

### 10. Freeze for the cutscene

Stop Pathfinding clears the route AND hands the driver sibling back, so a scripted animation can
own the body without the agent fighting it.

```
On Cutscene Started -> Stalker | Nav Agent 3D: Stop Pathfinding
On Cutscene Ended   -> Stalker | Nav Agent 3D: Find Path To Node  $Player, "nearest"
```

### 11. Manual mode for a four-legged controller

Auto control off: paths still compute, and Path Move X / Z become a steering feed for your own
mover and skeleton.

```
On Ready   -> Wolf | Nav Agent 3D: Set Auto Control  false
Every tick
  Condition: Wolf | Nav Agent 3D: Has Path
    -> (drive the wolf from Path Move X / Path Move Z, aim the skeleton the same way)
```

### 12. Rebake when the drawbridge lowers

The mesh only knows the level it was baked from. When geometry changes at runtime, rebake -
agents see the new mesh on their next Find Path To.

```
On Drawbridge Lowered
  -> Knight | Nav Agent 3D: Bake Navigation Region  $NavRegion
  -> Knight | Nav Agent 3D: Find Path To Node  $Player, "nearest"
```

### 13. Idle wandering

On Path Complete immediately picks a new random destination - villagers that never stand still.

```
On Ready         -> Villager | Nav Agent 3D: Find Path To  randf_range(-20, 20), 0, randf_range(-20, 20), "nearest"
On Path Complete -> Villager | Nav Agent 3D: Find Path To  randf_range(-20, 20), 0, randf_range(-20, 20), "nearest"
```

`nearest` snaps even a mid-air random point onto the mesh, so wild coordinates still land
somewhere walkable.

### 14. Calling off the chase

Distance To Target is straight-line metres to the target - the giving-up dial. Player too far
ahead? Go home.

```
Every 0.5 seconds
  Condition: Hound | Nav Agent 3D: Distance To Target > 30
    -> Hound | Nav Agent 3D: Stop Pathfinding
    -> Hound | Nav Agent 3D: Find Path To  kennel_x, kennel_y, kennel_z, "nearest"
```

### 15. Auto-walk the player (FPS Controller)

Attach Nav Agent 3D under the player next to the FPS Controller: a scripted route walks the
player with their own speed and feel, then hands the keyboard back.

```
On Briefing Started -> Player | Nav Agent 3D: Find Path To  podium_x, podium_y, podium_z, "reach"
On Path Complete    -> Player | Nav Agent 3D: Stop Pathfinding
```

### Other use cases

**Tower-defense creeps.** Each spawned creep gets one Find Path To at the exit in nearest mode; the navmesh IS the lane layout, and rebaking after the player builds a wall reshapes every route.

**Stealth guard investigation.** A noise event sends the guard pathing to the sound's position in nearest mode; On Path Complete starts a look-around timer before it walks back to its post.

**Boss phase repositioning.** Between phases the boss paths to a staged arena anchor in reach mode, and On Path Complete is the cue to start the next attack pattern.

**Ambient wildlife.** Deer wander with the random-destination loop and simply Find Path To a point away from the player when they get close, so the forest feels alive for a handful of rows.

**Summoned minions.** A summon spell drops three minions that Find Path To Node the summoner's current target, with avoidance on so the pack spreads around it instead of stacking.

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
