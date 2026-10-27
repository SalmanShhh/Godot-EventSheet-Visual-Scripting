# Platformer Pathfinding - Jump-Aware Navigation for 2D Platformers

Platformer Pathfinding gives an enemy (or ally) the ability to actually CHASE you through a
platformer level: around platforms, up stairs, across gaps - jumping where a jump is needed,
walking where walking works. Godot's built-in navigation is made for top-down/3D surfaces;
platformers need a jump graph, and that is what this pack builds. Attach a
`PlatformerPathfinding` behavior as a SIBLING of `PlatformerMovement` under a `CharacterBody2D`,
build the graph from your `TileMapLayer` once, and call **Find Path To** - the pathfinder
derives jump reach from the movement pack's real physics and drives it through its
`ai_move_axis` seam, so the agent moves under exactly the same rules the player does.

Two bundled showcases. **Platformer Pathfinding**
(`demo/showcase/platformer_pathfinding/`) is the plain case and the one to copy: a level with one
gap and two ledges, a keyboard Player, and a Chaser wired in three actions - build the graph, draw
it, Find Path To Node the Player once. **Path Chase** (`demo/showcase/path_chase/`) is the same
setup with everything else the pack can do turned on: portals, a deadly hazard, a moving platform,
a bridge that appears and vanishes, and a Guard patrolling the high platform on a graph it shares
with the Chaser through a Map Tag.

The second half of the vocabulary (link kinds, strategies, crowds, patrols, obstacle maps, the
fuller portal and hazard sets) is inspired by a platformer navigation graph addon from another
event-sheet engine, rebuilt in Godot's own terms: signals for triggers, `Vector2` expressions for
X/Y pairs, Nodes and groups for picked objects, and StaticBody2D / TileMapLayer data for the map.

---

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Reading it from expressions - the Self section](#reading-it-from-expressions---the-self-section)
6. [Use cases](#use-cases)
7. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **A chaser in three rows.** Build the graph on ready, Find Path To Node the player on a
  timer, done - the enemy walks, jumps gaps, and climbs platforms to reach you.
- **It jumps like the player jumps.** Jump height and distance are DERIVED from the sibling
  PlatformerMovement's `jump_velocity`, `gravity`, and `move_speed` - retune the movement feel
  and the pathfinder's idea of "reachable" retunes itself.
- **Movement stays yours.** Pathfinding never moves the body: it steers the movement pack
  through a two-variable intent seam (`ai_controlled` + `ai_move_axis`) plus its `jump()` action.
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
- **Hazards are one action too.** Add Hazard marks a world rectangle: deadly zones (spikes,
  lava) are NEVER routed through, danger zones (fire, mud) cost 4x so they are crossed only
  when no clean way exists. Applies to routing instantly - no graph rebuild.
- **Moving platforms carry the agent.** Add Moving Platform registers an AnimatableBody2D you
  animate between two endpoints; a routed agent walks to the track, WAITS beside it standing
  still until the platform parks, boards, rides centered, and walks off at the far side.
- **See it think.** Set Nav Debug Draw paints the live route as a line in the world, and Set
  Debug Draw Graph paints EVERY node and link, coloured by kind.
- **Every way a platformer character gets around.** Walk, jump, fall, plus DOUBLE JUMP links
  when the movement sibling has two jumps, COYOTE JUMP links (run off the ledge, leap in the air),
  FALL-THROUGH drops off one-way tiles, instant and GRADUAL portals (ladders, lifts, ziplines),
  elevator groups, and moving platforms.
- **Six path strategies.** balanced, shortest, safest, ground_hugging, no_falling and walk_only
  change how a route is priced - the same level gives a speedrunner rival, a cautious escort and
  a shopkeeper who never leaves the counter.
- **Crowds behave.** Crowd Arrivals spreads agents over neighbouring nodes instead of stacking
  them, Multi Agent Avoidance fans their routes out, Idle Separation nudges idle agents apart
  (never off a ledge), and a shared Map Tag builds the graph ONCE for a whole horde.
- **Patrols in one row.** Start Patrol walks the platform end to end with a dwell at each end,
  firing a trigger at every turn.
- **No tiles? Still works.** Create Obstacle Map + Set Tile State, or Scan Collision Bodies over a
  level built from StaticBody2D shapes, and Obstacle Map JSON / Load Obstacle Map JSON save and
  restore the whole map.

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

**Hazards shape routes, not the level.** Add Hazard marks a world rectangle without touching
tiles or the graph: deadly hazards block their edges outright (and are never picked as a
`nearest` goal), danger hazards multiply their edges' cost by 4 so the router detours whenever
a clean route exists and grits through only when there is none. On Hazard Entered fires if the
agent ends up inside one anyway (knockback, a mid-air clip) - that is the damage hook.

**Moving platforms are choreography.** Add Moving Platform registers a platform you animate
(an AnimatableBody2D with `sync_to_physics`, ping-ponged between exactly the two registered
endpoints) and adds a PLATFORM edge between the nearest standable nodes. The drive then runs a
boarding discipline: the agent stops BESIDE the track (never under it - a descending platform
crushes whatever it lands on), stands still until the platform parks at the boarding side,
walks on, rides centered, and walks off at the far side. Waiting and riding legitimately stall
waypoint progress, so the stuck watchdog holds off, and route refreshes are deferred mid-ride
(a fresh route would start from a ground node and steer the rider off the shaft).

**Link kinds.** Every route is a list of waypoints, and each says how it is reached (Waypoint
Action): `walk`; `jump`; `double_jump` (only built when the movement sibling has `max_jumps` of 2
or more - the second jump fires at the top of the first); `coyote_jump` (run off a ledge and leap
half way through the coyote window, for gaps a standing jump cannot clear - only built when the
window is long enough to matter and Ledge Restriction is off); `fall`; `fall_through` (drop
straight down through a one-way tile - one-way collision polygons are read as jump-through
platforms you can stand on, jump up through, and drop through); `portal` (an instant blink);
`portal_gradual` (a straight-line move at a speed, with the movement sibling paused - ladders,
lifts, ziplines); and `platform` (a moving platform ride).

**Strategies price routes.** Walking, portals and platforms always cost what they cost; Path
Strategy re-prices the airborne links. `balanced` (default) uses the built-in weights;
`shortest` counts raw distance plus a small landing fee per jump, so long leaps win; `safest`
makes long leaps and deep drops cost more the bigger they are, so chains of short hops win;
`ground_hugging` puts a heavy fee on every jump and fall, so it walks whenever any walking route
exists; `no_falling` never descends by jump or fall (Max Traversal Drop raises the allowance);
`walk_only` never leaves its platform except by portal or moving platform. Max Traversal Drop
also works alone, with any strategy.

**Nearest really means nearest.** In `nearest` mode a target the agent cannot reach is not a
failure: the route goes to the closest node the search could reach. `reach` mode still fails,
and Path Fail Reason says why (`no_graph`, `no_start_node`, `no_goal_node`, `no_path`,
`max_nodes_reached`, `no_ledge`, `no_target`).

**Maps without a TileMapLayer.** Create Obstacle Map starts an empty grid of a cell size you
pick; Set Tile State marks cells `solid`, `clear`, `jump_thru`, `slope_left` or `slope_right`;
Scan Collision Bodies marks the cells StaticBody2D shapes cover (one-way shapes as jump-through).
Overrides and scans layer over a tilemap too, and survive Regenerate. Obstacle Map JSON hands
back the merged map as text and Load Obstacle Map JSON rebuilds from it - a pre-baked level.

**Map tags share one graph.** Agents whose Map Tag is the same non-empty word share ONE graph,
obstacle edits, portals, hazards and moving platforms: the first Build Nav Graph builds, every
later one on the same TileMapLayer just joins. Give agents with different jump physics
different tags. An empty tag (the default) keeps the graph per agent.

**Pathfinding plans with straight-down gravity.** The graph, jump arcs, and steering all
reason in screen x/y with gravity pulling down. PlatformerMovement's `gravity_angle` knob
rotates that whole frame, and the planner does not follow it: leave the angle at its default
`90` on any agent this pack drives. If the sibling movement's angle is anything else, the
behavior warns once at runtime (and the Project Doctor flags scenes that combine the two) so
a wrong-looking chase is never a silent mystery. Rotated-gravity planning is future work.

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

On the canvas these rows read as styled sentences - parameter values in **bold**, node references in *italic*, exactly as the rows draw them:

- Build nav graph from *tilemap*
- Find path to (**x**, **y**) mode **mode**
- Patrol the platform, waiting **dwell** s at each end, **edge_distance** px back from it
- Jump toward (**x**, **y**)
- Pick routes by **strategy**
- Add gradual portal (**from_x**, **from_y**) to (**to_x**, **to_y**) at **speed** px/s

All ACEs live in the **Platformer Pathfinding** category and target the behavior on the node
they are placed on.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Build Nav Graph From Tilemap | `tilemap` (Node) | Scans the TileMapLayer's physics tiles into the graph (nodes + walk/jump/fall edges, jump reach derived from the movement sibling). Call once on ready. Fires On Nav Graph Built. |
| Regenerate Nav Graph | (none) | Rebuilds from the same tilemap after runtime tile edits. |
| Find Path To | `x`, `y` (float), `mode` (`nearest`/`reach`) | Routes to a world position and starts moving. `reach` fails when the spot is unreachable; `nearest` goes to the closest reachable node instead. Fires On Path Found / On Path Failed. |
| Find Path To Node | `target` (Node), `mode` | Find Path To with the position read for you - re-call on a timer to chase. |
| Stop Pathfinding | (none) | Clears the path (and any follow) and hands the movement pack back to the keyboard. |
| Set Ledge Restriction / Set Ledge Leniency | `enabled` (bool) / `pixels` (float) | Patrol discipline: walk-only routing - no jumps, no portals, drops only within the leniency. The patroller stays on its platform. |
| Set Jump Positioning | `mode` (`relaxed`/`strict`) | relaxed: leap the moment a jump leg starts. strict: walk onto the exact takeoff spot first (tight arcs). |
| Set Coyote Time | `seconds` (float) | Grace window for AI jumps a frame after running off the takeoff ledge. |
| Set Repath Interval / Set Repath Threshold | `seconds` / `pixels` (float) | Follow-mode freshness: how often the route may refresh, and how far the followed node must move first. |
| Set Max Paths Per Tick | `count` (int) | The SHARED budget across all agents: extra route requests defer a tick (Is Path Pending) instead of spiking the frame. |
| Add Portal | `from_x`, `from_y`, `to_x`, `to_y` (float), `bidirectional` (bool) | Links two world positions: routes through it walk to the entrance and BLINK to the exit (On Portal Taken). Survives Regenerate. |
| Clear Portals | (none) | Removes every registered portal. |
| Add Hazard | `x`, `y`, `width`, `height` (float), `deadly` (bool) | Marks a world rectangle as hazardous. Deadly: routes never pass through it. Not deadly: routes pay 4x to cross. Applies to routing instantly - no rebuild. |
| Clear Hazards | (none) | Removes every registered hazard. |
| Add Moving Platform | `platform` (Node), `from_x`, `from_y`, `to_x`, `to_y` (float) | Registers a moving platform (an AnimatableBody2D your sheet animates between exactly these endpoints): the graph gains a PLATFORM edge, and a routed agent waits beside the track, boards when it parks, rides, and walks off. Survives Regenerate. |
| Clear Moving Platforms | (none) | Removes every registered platform (their edges leave on the next Regenerate). |
| Set Auto Control | `enabled` (bool) | On (default): drive the sibling movement pack. Off: paths compute, you drive. |
| Set Nav Debug Draw | `enabled` (bool) | Draw the active path as a line in the world. |
| Set Enabled | `state` (bool) | Off freezes the agent with everything kept and ignores route requests; on resumes. |
| Set Path Strategy | `strategy` (`balanced`/`shortest`/`safest`/`ground_hugging`/`no_falling`/`walk_only`) | How routes are priced from now on. |
| Set Max Traversal Drop | `pixels` (float) | Jumps and falls landing lower than this are left out of routes (-1 = no limit). |
| Set Drift Repath Distance | `pixels` (float) | Knocked this far off its leg, the agent re-plans (On Repath). 0 = off. |
| Set Movement Limit | `limit` (`jump_height`/`jump_distance`/`max_fall`), `value` (float) | Overrides a derived limit; Regenerate afterwards. |
| Jump Toward | `x`, `y` (float) | A full-strength leap at a point with no route - lunges and pounces. Fires On Jump Toward Launched. |
| Teleport To | `x`, `y` (float) | Moves the agent without throwing its route away. |
| Start Patrol / Stop Patrol | `dwell`, `edge_distance` (float) / (none) | Walks the platform end to end, waiting `dwell` seconds at each end, `edge_distance` px back from it. |
| Find Path To Nearest Ledge | `direction` (`left`/`right`), `distance` (float) | Routes to the nearest edge of its platform, stopping `distance` px short. |
| Find Path To Node Side | `target` (Node), `side` (`any`/`left`/`right`), `distance` (float) | Routes to a spot beside a node instead of onto it. Fires On Node Side Reached. |
| Set Crowd Arrivals / Set Multi Agent Avoidance | `enabled` (bool) | Spread arrivals over neighbouring nodes / fan routes away from other agents' cells. |
| Set Separation Setting | `setting` (`distance`/`cooldown`/`give_up_time`), `value` (float) | Idle separation tuning. |
| Create Obstacle Map | `width`, `height` (int), `cell_size` (float) | An empty map with no TileMapLayer. |
| Set Tile State / Set Tile State At | `gx`, `gy` (int) or `x`, `y` (float), `state` | Overrides one cell: `solid`, `clear`, `jump_thru`, `slope_left`, `slope_right`. Regenerate afterwards. |
| Scan Collision Bodies | `root` (Node) | Marks cells covered by the StaticBody2D shapes under `root` (one-way shapes as jump-through). Regenerate afterwards. |
| Clear Nav Graph | (none) | Drops the graph and the obstacle map. Fires On Nav Graph Cleared. |
| Load Obstacle Map JSON | `json` (String) | Rebuilds the map and graph from Obstacle Map JSON text. |
| Log Graph Stats / Set Debug Draw Graph | (none) / `enabled` (bool) | Print the graph's size; draw every node and link. |
| Add Circle Hazard / Add Tracked Hazard | `x`, `y`, `radius` / `target`, `radius`, plus `deadly` | A circular hazard, fixed or following a node (removed when the node is freed). |
| Remove Hazard / Set Hazard Margin | `hazard_id` (int) / `pixels` (float) | Remove one hazard by Last Hazard Id; grow every hazard by a danger buffer. |
| Add Instant Portal / Add Gradual Portal | ends, `bidirectional`, (`speed`,) `cost`, `tag` | A blink, or a straight-line move at `speed`. `cost` 1 is normal; tags are comma-separated. |
| Add Elevator Stop | `group` (String), `x`, `y`, `speed` (float), `tag` | Two-way gradual portals to every other stop of the group. |
| Pause At Portal / Resume Portal / Complete Portal | (none) | Hold the agent at a portal inside On Portal Entered, then run the portal's move, or finish it without one. |
| Remove Portal / Remove Portal Near / Remove Portals By Tag | id / `x`, `y` / `tag` | Portal links leave the graph at once. |
| Set Portal Cost / Speed / Tag / Ignore Hazards / Position | `portal_id` plus the new value(s) | Edit a portal in place, keeping its id. |

### Conditions, expressions, and triggers

| Kind | Name | Description |
|---|---|---|
| Condition | Has Path | An active path exists. |
| Condition | Path Wants Jump | The drive wants a jump right now (jump arc, or a step-assist hop) - the manual-mode jump signal. |
| Condition | Is Path Pending | This agent's route request is queued for a later tick (the shared budget was spent). |
| Condition | Is In Hazard | The agent is standing inside a registered hazard right now (deadly or danger). |
| Expression | Path Move Axis | The current steering, -1..1 - feed it to your own driver in manual mode. |
| Expression | Current Waypoint X / Y | The waypoint being moved toward, in world pixels. |
| Expression | Waypoint Count / Current Waypoint Index | Path length and progress. |
| Expression | Current Path Action | What this leg is: `walk`, `jump`, `fall`, `portal`, or `platform`. |
| Trigger | On Path Found / On Path Failed / On Path Complete | The reaction trio. |
| Trigger | On Waypoint Reached | Each waypoint passed. |
| Trigger | On Nav Graph Built | The scan finished. |
| Trigger | On Portal Taken | The agent just blinked through a portal. |
| Trigger | On Waypoint Stuck | No progress toward the waypoint for Stuck Timeout - it re-routes itself and tells you. |
| Trigger | On Repath | The route refreshed (a follow update or a stuck recovery). |
| Trigger | On Hazard Entered | The agent just stepped into a hazard (deadly or danger) - the damage hook. |
| Trigger | On Portal Entered | The agent reached a portal entrance, before the portal moves it (call Pause At Portal here). |
| Trigger | On Jump Toward Launched | Jump Toward just left the ground. |
| Trigger | On Patrol End Reached / On Patrol Dwell Started / On Patrol Dwell Finished | A patrol's turn, wait and walk-on. |
| Trigger | On Node Side Reached | A Find Path To Node Side route arrived beside its node. |
| Trigger | On Nav Graph Cleared | Clear Nav Graph ran. |
| Condition | Is Enabled / Is Patrolling | The behavior is on; a patrol is running. |
| Condition | Is At Ledge / Is At Island | Standing on a platform's edge node; on a one-node platform. |
| Condition | Is On Same Platform / Is Position On Same Platform | The agent could WALK there (slopes and stairs count). |
| Condition | Is Position Hazardous | A world position is inside any hazard. |
| Condition | Is At Portal / Is Traversing Portal | Held at a portal; moving through a gradual portal. |
| Condition | Graph Node Exists / Graph Node Exists At / Is Ledge Node | Graph inspection by cell or world position. |
| Condition | Tile Has State / Tile Has State At | A cell's obstacle state is the given one. |
| Expression | Waypoint Position / Waypoint Cell / Waypoint Action (index) | Any waypoint of the route. |
| Expression | Path Cost / Path End / Path Target / Path Goal Cell | The route's price, where it really ends, what was asked for, and the goal cell. |
| Expression | Path Fail Reason / Path Queue Size | Why the last route failed; how many agents wait on the shared budget. |
| Expression | Distance To Waypoint / Angle To Waypoint | Pixels and degrees to the current waypoint. |
| Expression | Patrol Direction / Reached Side / Jump Toward Target | -1/1 (0 while dwelling); the side arrived on; the leap's aim. |
| Expression | Coyote Timer / Estimated Velocity X | Coyote grace left; the speed the route asks for. |
| Expression | Nearby Agent Count (radius) / Nearest Ledge (direction) / Node On Platform (group, which) | Crowd and platform questions; Node On Platform returns the Node. |
| Expression | Obstacle Map JSON / Obstacle Map Source / Tile State / World To Grid / Grid To World / Grid Size / Grid Tile Size | The obstacle map. |
| Expression | Graph Node Count / Graph Node Cell / Graph Node Position / Ledge Side / Graph Node Connection Count / Kind / Cost / Target / Nearest Graph Node / Nearest Graph Node Cell | Graph inspection. |
| Expression | Calculated Jump Distance / Calculated Jump Height | The reach the graph is built with. |
| Expression | Hazard At / Hazard Count / Tracked Hazard Count / Last Hazard Id | 0 clear, 1 danger, 2 deadly; counts; the id for Remove Hazard. |
| Expression | Current Portal Id / Last Portal Id / Portal Count / Nearest Portal Id / Furthest Portal Id / Portal Count By Tag / Portal Id By Tag / Portal Tag / Portal Type / Portal Exit / Portal Progress | Portal bookkeeping. |

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
| `ledge_restriction` / `ledge_leniency` | `false` / `0.0` | Walk-only routing; drops allowed up to the leniency (px). |
| `jump_positioning` | `relaxed` | relaxed leaps at leg start; strict walks onto the takeoff spot first. |
| `coyote_time` | `0.12` | AI jump grace after leaving the takeoff ledge (s). |
| `repath_interval` / `repath_threshold` | `0.5` / `24.0` | Follow-mode refresh rate and the movement needed to trigger it. |
| `stuck_timeout` | `1.5` | No waypoint progress for this long fires On Waypoint Stuck + a self re-route. |
| `nav_enabled` | `true` | Off = frozen with state kept (Set Enabled). |
| `path_strategy` | `balanced` | How routes are priced (see Core concepts). |
| `smooth_paths` | `true` | Drop the in-between waypoints of a straight walk. |
| `max_search_nodes` | `2000` | Search cap per route (Path Fail Reason `max_nodes_reached`). |
| `max_traversal_drop` | `-1.0` | Deepest jump or fall a route may take, px (-1 = no limit). |
| `drift_repath_distance` | `0.0` | Re-plan when knocked this far off the leg (0 = off). |
| `double_jump_links` | `true` | Build double jump links when the sibling has two jumps. |
| `hazard_margin` / `danger_cost_multiplier` | `0.0` / `4.0` | Danger buffer around every hazard; the price of crossing danger. |
| `auto_build` | `true` | A route asked for with no graph builds one from the scene's first physics TileMapLayer. |
| `map_tag` | `""` | Same non-empty tag = one shared graph. |
| `grid_cell_size` | `32.0` | Cell size for a map with no TileMapLayer. |
| `crowd_arrivals` / `multi_agent_avoidance` | `false` / `false` | Spread arrivals; fan routes out. |
| `idle_separation` / `separation_cooldown` / `separation_give_up_time` | `0.0` / `5.0` / `2.0` | Idle personal space (px, 0 = off), rest after giving up, time before giving up. |
| `debug_draw_graph` / `debug_log` | `false` / `false` | Draw the whole graph; print each route and failure. |

### Inspector properties are ACEs too

Every property this pack exposes in the Inspector is also reachable from the picker, generated for you:
an expression named after the property reads it, a **Set ...** action writes it, and for number properties
**Add To ...** and **Subtract From ...** adjust it by an amount. They sit in the pack's own category
alongside the vocabulary above, so any knob you can set in the Inspector is also something a sheet can read and
change while the game runs.

## Reading it from expressions - the Self section

Type `self` in any ƒx field, or open the ƒx **Expressions dictionary**, and **Self ▸ Behaviours**
lists this pack's knobs and value expressions as ready-to-insert chains once the behaviour is attached:

- `$PlatformerPathfinding.arrive_distance` inserts the **Arrive Distance** entry straight into any expression
- `$PlatformerPathfinding.auto_control` inserts the **Auto Control** entry straight into any expression

The `$PlatformerPathfinding` token stays selected after insert, so retargeting to your child's actual name is one
keystroke, or a node drag. Attaching this behaviour at runtime instead? Tick **Robust behaviour
lookups** in the dictionary and the same entries insert as `get_node_or_null("PlatformerPathfinding")` chains,
which survive auto-named children. While **Live Values** streams from a running game, the group
upgrades to *Behaviours (live - on your node)* and reads the RUNNING instance - behaviours
attached at runtime included, under their real names. And with your node selected in the Scene
dock, the section grounds to that node's actual children before you even press Run.

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
Add `Set Ledge Restriction true` on ready and the guard NEVER leaves its platform - no chasing
the player off a rooftop.

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

### 7. Spikes, lava, and an elevator

A spike pit the chaser refuses to cross, and a tower it can only reach by riding your
elevator (the Path Chase showcase plays exactly this).

```
On Ready
  -> Enemy | Pathfinding: Build Nav Graph From Tilemap  $Level
  -> Enemy | Pathfinding: Add Hazard  704, 512, 160, 64, true      (deadly - never crossed)
  -> Enemy | Pathfinding: Add Moving Platform  $Elevator, 1088, 552, 1088, 200
On Hazard Entered -> Enemy | Health: Take Damage  10               (if it lands in one anyway)
```

The sheet animates `$Elevator` between those two endpoints with a pause at each end; the
chaser waits beside the shaft, rides up, and walks off onto the tower.

### 8. A door that is really a portal

Two linked positions and the router treats them as adjacent: the agent walks to the doorway and
blinks to the other side.

```
On Ready        -> Enemy | Pathfinding: Add Portal  416, 480, 1504, 480, true
On Portal Taken -> (play the door sound, puff dust at both ends)
```

Portals survive Regenerate Nav Graph, so destructible levels keep their doors.

### 9. Thirty chasers without a frame spike

Route computations share one budget across ALL agents; extra requests wait a tick instead of
stalling the frame.

```
On Ready         -> Enemy | Pathfinding: Set Max Paths Per Tick  4
Every 1 seconds  -> Enemy | Pathfinding: Find Path To Node  $Player, "nearest"
Every tick
  Condition: Enemy | Pathfinding: Is Path Pending
    -> (keep running the current animation - the route arrives next tick)
```

### 10. The stuck shrug

The watchdog already re-routes a blocked agent by itself; your job is just the acting.

```
On Waypoint Stuck -> (play the "shrug" animation and a frustrated grunt)
On Repath         -> (snap back to the run animation)
```

Tune `stuck_timeout` down for twitchy arcade enemies, up for slow lumbering ones.

### 11. A fire patch that burns but does not block

A danger (non-deadly) hazard costs 4x, so the router detours when it can; Is In Hazard plus the
Health pack ticks the burn when it cannot.

```
On Ready -> Enemy | Pathfinding: Add Hazard  512, 448, 96, 32, false
Every 0.5 seconds
  Condition: Enemy | Pathfinding: Is In Hazard
    -> Enemy | Health: Take Damage  5
```

### 12. Animations from the path leg

Current Path Action names what the current leg is - the whole animation switch in one expression.

```
Every tick
  Condition: Current Path Action is "walk"  -> play "run"
  Condition: Current Path Action is "jump"  -> play "leap"
  Condition: Current Path Action is "fall"  -> play "fall"
```

`portal` and `platform` legs are also reported - a teleport sparkle and an idle stance cover them.

### 13. The coward

There is no flee action, and you do not need one: path to a made-up point away from the player and
`nearest` mode snaps it onto the graph.

```
Every 1 seconds
  Condition: distance to $Player < 200
    -> Rabbit | Pathfinding: Find Path To  Rabbit.X + sign(Rabbit.X - Player.X) * 400, Rabbit.Y, "nearest"
```

### 14. Pixel-tight takeoffs

One-tile pillars punish early leaps. Strict positioning walks onto the exact takeoff spot first;
a shorter coyote time stops late jumps from drifting.

```
On Ready
  -> Ninja | Pathfinding: Set Jump Positioning  "strict"
  -> Ninja | Pathfinding: Set Coyote Time  0.05
```

### 15. Level-swap cleanup

Portals, hazards, and platforms are registered per behavior and survive rebuilds BY DESIGN - so a
level transition must clear them explicitly, or the old level's doors haunt the new one.

```
On Level Finished
  -> Enemy | Pathfinding: Stop Pathfinding
  -> Enemy | Pathfinding: Clear Portals
  -> Enemy | Pathfinding: Clear Hazards
  -> Enemy | Pathfinding: Clear Moving Platforms
On Next Level Ready
  -> Enemy | Pathfinding: Build Nav Graph From Tilemap  $Level2
```

### 16. A guard that walks its rooftop

One row: walk end to end, wait at each end, turn. The triggers carry the acting.

```
On Ready                 -> Guard | Pathfinding: Start Patrol  1.5, 8
On Patrol Dwell Started  -> play "look_around"
On Patrol Dwell Finished -> play "walk" (flip by Patrol Direction)
```

### 17. A door with an opening animation

Pause the agent at the portal, play the door, then let the portal run.

```
On Portal Entered
  -> Enemy | Pathfinding: Pause At Portal
  -> $Door: play "open"
On $Door animation finished
  -> Enemy | Pathfinding: Resume Portal
```

### 18. A ladder and a zipline

A gradual portal moves the agent in a straight line at a speed, with the movement sibling paused.

```
On Ready
  -> Enemy | Pathfinding: Add Gradual Portal  208, 464, 208, 176, true, 120, 1, "ladder"
  -> Enemy | Pathfinding: Add Gradual Portal  400, 160, 900, 420, false, 400, 1, "zipline"
```

### 19. A three-floor lift

Every stop of a group links to every other one, both ways.

```
On Ready
  -> Enemy | Pathfinding: Add Elevator Stop  "lift", 640, 560, 150, ""
  -> Enemy | Pathfinding: Add Elevator Stop  "lift", 640, 336, 150, ""
  -> Enemy | Pathfinding: Add Elevator Stop  "lift", 640, 112, 150, ""
```

### 20. A horde that surrounds instead of stacking

One shared graph, landing spots claimed, routes fanned out, idle bodies spaced.

```
(Inspector, every goblin: map_tag "horde", crowd_arrivals on, multi_agent_avoidance on, idle_separation 24)
Every 1 seconds -> Goblin | Pathfinding: Find Path To Node  $Player, "nearest"
```

### 21. A knight who takes the long road down

No falls deeper than two tiles: it walks down stairs and slopes instead of jumping off the castle.

```
On Ready -> Knight | Pathfinding: Set Path Strategy  "no_falling"
         -> Knight | Pathfinding: Set Max Traversal Drop  64
```

### 22. A boss lunge

Jump Toward ignores the graph: a full-strength leap at the player, with a trigger at takeoff.

```
Every 4 seconds          -> Boss | Pathfinding: Jump Toward  $Player.global_position.x, $Player.global_position.y
On Jump Toward Launched  -> play "pounce"
```

### 23. An archer that keeps its distance

Stand beside the target, not on it.

```
Every 1 seconds -> Archer | Pathfinding: Find Path To Node Side  $Player, "any", 160
On Node Side Reached -> Archer | Shoot
```

### 24. A pre-baked map for a huge level

Save the merged obstacle map once, ship the text, and load it with no TileMapLayer scan at all.

```
(in a tool run)  -> save $Enemy/Pathfinding.obstacle_map_json() to "res://levels/castle_nav.json"
On Ready         -> Enemy | Pathfinding: Load Obstacle Map JSON  FileAccess.get_file_as_string("res://levels/castle_nav.json")
```

### 25. Drop through the floorboards

Paint one-way tiles (a TileSet polygon with One Way on) and the chaser drops through them to cut
you off - no setup, the scan reads the polygon.

```
Every 1 seconds -> Enemy | Pathfinding: Find Path To Node  $Player, "nearest"
Every tick
  Condition: Current Path Action is "fall_through"  -> play "drop"
```

### Other use cases

**Rooftop assassin patrols.** Ledge restriction keeps each guard glued to its own rooftop while normal chasing agents below jump between platforms, so two AI temperaments share one pack.

**Escort missions.** The ally simply follows the player with Find Path To Node in nearest mode, and On Waypoint Stuck is your cue to nudge or teleport them forward when the player runs off without them.

**Treasure goblin.** A loot thief paths to the nearest coin, and On Path Complete grabs it and immediately routes to the next one - kill it before the route list runs out.

**Elevator lobbies.** Register your scripted elevator as a moving platform and multi-floor towers become routable; agents queue beside the shaft on their own thanks to the boarding discipline.

**Boss arena adds.** Minions spawned at the edges all Find Path To the arena centre with a small shared path budget, arriving in staggered waves instead of one synchronized frame spike.

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
- **One Find Path To Node call chases forever.** It follows the node: the route auto-refreshes
  every Repath Interval once the target has moved Repath Threshold pixels. You do not need a
  timer row (though re-calling on one is harmless - each call just resets the follow).
- **Twenty chasers? Set the budget.** Route computations are capped at Max Paths Per Tick
  ACROSS all agents (default 8); extra requests defer a tick (Is Path Pending) instead of
  spiking a frame. Crowds repath in waves for free.
- **The watchdog has your back.** An agent making no waypoint progress for Stuck Timeout fires
  On Waypoint Stuck and re-routes itself from where it actually is - a knocked-back or
  blocked-in agent recovers without a single sheet row.
- **`nearest` for chasing, `reach` for scripted moves.** A chaser should get as close as it
  can; a cutscene walk-to-mark should fail loudly if the mark is unreachable.
- **Give moving platforms a DWELL.** Pause the platform for a second or two at each endpoint -
  the agent only boards a platform that is parked at the boarding side (stepping under a
  still-moving one is how walkers get crushed), so a pause-free ping-pong never offers a
  boarding window. Animate the platform between exactly the endpoints you registered.
- **Size the shaft with clearance.** An AnimatableBody2D's push is effectively infinite-mass -
  a CharacterBody2D it lands on gets ejected violently. Keep the platform's collider a little
  narrower than its travel corridor so a body standing at either lip is never clipped.
- **Deadly vs danger is a design dial.** Spikes and lava = deadly (never routed). Fire patches
  and mud = danger (4x cost) - the agent braves them only when the clean route disappears,
  which reads as smart desperation.
- **Tune with the debug line on.** Set Nav Debug Draw during development; the green line shows
  exactly what the router decided, which makes level-layout problems obvious. Set Debug Draw
  Graph shows every link the router COULD use, and Log Graph Stats counts them by kind.
- **Patrols and routes do not mix.** Any Find Path To, Find Path To Node, Jump Toward or Stop
  Pathfinding ends a running patrol; call Start Patrol again to resume it.
- **A shared Map Tag shares everything.** Portals, hazards and platforms one agent registers on a
  tag apply to every agent on it - which is the point for a horde, and a surprise for a guard who
  was meant to ignore a door. Give it its own tag (or none).
- **Coyote links need a real window.** They are built only when half the coyote window (capped by
  the movement sibling's own coyote time) adds at least a tile of run - the 0.1 s default adds
  none.
- **Does it work with nav meshes? No - on purpose.** A navmesh describes walkable SURFACES and
  has no concept of a jump, so it cannot express "leap this gap, climb that ledge" - which is
  the whole problem in a side-view platformer. This pack builds its own jump graph from your
  tiles instead. For 3D worlds (where walking really does get you everywhere the bake allows),
  use the **Nav Agent 3D** pack - it wraps Godot's navmesh behind the SAME names, so
  nothing new to learn.
