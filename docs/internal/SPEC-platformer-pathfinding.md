# SPEC - Platformer Pathfinding (2D jump-graph) + Nav Agent 3D

Design for two behavior packs that give sheet authors plug-and-play pathfinding, ported from a
proven event-sheet-style navigation-graph addon (per-character behavior, level-shared graph,
auto-control of the movement behavior, explicit slope awareness). Status: **P1 SHIPPED**
(the 2D `platformer_pathfinding` pack: tilemap scan, stand nodes, walk/jump/fall edges with
derived jump reach, A*, the ai_move_axis drive with step-assist, reach/nearest, the reaction
trio, waypoint expressions, path debug line, and the `demo/showcase/path_chase/` showcase).
**P3 SHIPPED** (`nav_agent_3d`: the auto-inserted NavigationAgent3D wrapper with 2D verb
symmetry, the universal-AI-seam drive of FPSController or a built-in body mover, avoidance,
runtime Bake Navigation Region, and the FPS Arena stalker). **Portals shipped early** (pulled
forward from P4 into the 2D pack). P2 (discipline: ledge restriction, jump positioning, repath
knobs, stuck watchdog, budget, Doctor checks) and the REST of P4 (hazards, moving platforms)
remain as phased below. P1
simplifications vs this spec: the graph lives per agent (no shared autoload yet), slope
classification is the generic one-step-up/down walk rule (full physics-polygon classification
lands with P2), and debug draw shows the active path (not the whole graph).

## Goals

1. **Plug and play.** Attach one behavior, call one verb (`Find Path To`), the character moves.
   No graph scripting, no node wiring, no manual physics numbers.
2. **Slopes work by default.** In the original addon slopes had to be REGISTERED per tile id or
   jump arcs clipped through them. Godot gives us something better: slope geometry already lives
   in the TileSet's physics polygons - so slope detection is AUTOMATIC here (see Slopes below).
   Manual override verbs remain for exotic cases only.
3. **Composes with the movement packs.** Pathfinding never reimplements movement: it DRIVES the
   sibling movement behavior (PlatformerMovement in 2D, FPSController in 3D) through a small
   intent contract, and manual mode exposes the same intents as expressions for custom drivers.
4. **2D and 3D.** 2D is the hero port (platformer jump graphs do not exist in Godot).
   3D rides Godot's own navigation server (navmesh) behind the same verb names, because
   rebuilding navmesh baking would be worse than wrapping it.

## Non-goals (v1)

Portals/elevators, hazard avoidance, and multi-agent avoidance are phased later (they were the
original addon's later chapters too). Moving-platform tracking is out of scope for v1.

---

## Pack 1: `platformer_pathfinding` (2D)

**Shape:** behavior pack, host `CharacterBody2D`, class `PlatformerPathfinding`. Attach it as a
sibling of `PlatformerMovement` under the character. One shared graph service per scene
(autoload `PlatformNavGraph`, default-off byte-identical like Advanced Random's shared mode)
holds the expensive part; every agent behavior queries it - N enemies, one graph.

### The 60-second setup (the whole point)

```
Player scene:  Enemy (CharacterBody2D)
               ├─ PlatformerMovement      (existing pack - already moves/jumps)
               └─ PlatformerPathfinding   (this pack)

Sheet:  On Ready        -> Build Nav Graph From Tilemap   $TileMapLayer
        Every 0.5 secs  -> Find Path To ($Player.position)
        On Path Failed  -> Play Sound "confused"
```

That is the entire integration. Everything below explains what those three rows hide.

### Graph building (the level side)

- **Build Nav Graph From Tilemap (tilemap)**: scans a `TileMapLayer`'s used cells + TileSet
  physics polygons into an obstacle grid, classifies each solid cell (full block / slope-left /
  slope-right / gentle variants / one-way platform), places surface nodes on every walkable top,
  marks ledges, then connects nodes with walk edges (surfaces + slopes) and jump/fall arcs.
  One explicit action, exactly like the original ("built once and reused") - no per-frame
  rescanning. `Regenerate Nav Graph` rebuilds after runtime level edits.
- **Jump/fall arcs are derived from the AGENT, not typed in**: on first use the behavior reads
  `move_speed`, `jump_velocity`, and gravity from the sibling `PlatformerMovement` (the same
  auto-detection trick the original used on its Platform behavior) and computes max jump
  height/distance and max safe fall. Override verbs (`Set Max Jump Height/Distance`,
  `Set Max Fall Distance`) exist for unusual physics.
- **One-way platforms** come free: Godot tiles flag one-way collision per polygon; those tops
  become nodes with drop-through edges.

### Slopes (the plug-and-play answer)

The original addon required registering slope tile ids because its obstacle map only knew
solid/clear. Here, classification is geometric and automatic:

1. For every solid cell, read its TileSet collision polygon(s).
2. A polygon whose top edge is non-horizontal is a slope; its surface normal buckets it into
   slope-left / slope-right, steep (45°) or gentle (22.5°-ish). Anything walkable by
   `CharacterBody2D.floor_max_angle` becomes a WALK edge at Euclidean cost - so A* naturally
   prefers walking a ramp over jumping it, byte-for-byte the original's costing rule.
3. Unclassifiable custom shapes fall back to solid blocks AND are reported: the graph build
   returns a census, and a Project Doctor check ("slope-like tile not classified - arcs may clip
   it") replaces the original's debug-console listing with a clickable finding.

Manual overrides stay for the exotic 1%: `Mark Slope Region (rect, kind)`, `Set Tile State
(cell, state)`, `Clear Slope Overrides` - same verbs, but you should never need them for a
normal TileSet.

### Movement drive (the interop contract)

Every physics tick with an active path, the behavior resolves the current edge into an INTENT:
`{move_axis: -1..1, want_jump: bool, want_drop: bool}`.

- **Auto mode (default)**: the intent drives the sibling `PlatformerMovement`. That pack gains
  one small addition: an `ai_move_axis` variable + `ai_controlled` flag consumed in its
  `_physics_process` in place of `Input.get_axis`, plus its existing `jump()` verb. (Its input
  read is currently hardwired; this is the only change outside the new packs, and it is inert
  when `ai_controlled` is off - byte-gated.) No PlatformerMovement present? Fall back to driving
  `CharacterBody2D.velocity` directly with the derived physics.
- **Manual mode** (`Set Auto Control off`): paths still compute; the sheet reads
  `Path Move Axis`, `Path Wants Jump`, `Current Waypoint X/Y`, `Current Path Action`
  ("walk_right", "jump", "fall", "slope_up"...) and drives anything it likes - the escape hatch
  for animation state machines and custom physics, verbatim from the original.
- Positioning discipline maps over as **Jump Positioning** (default/strict/relaxed per path or
  globally), **Ledge Restriction** + **Ledge Leniency** (patrollers stay on their platform),
  and **Coyote Time** for AI jumps.

### ACE surface (v1)

| Kind | Name | Notes |
|---|---|---|
| Action | Build Nav Graph From Tilemap (tilemap) | the one-time scan + build |
| Action | Regenerate Nav Graph | after runtime level edits |
| Action | Find Path To (x, y) / Find Path To Node (node) | mode param: reach / nearest (never fails); jump positioning param: default/strict/relaxed |
| Action | Stop Pathfinding | clear path, stop driving |
| Action | Jump Toward (x, y) | the lunge - no pathfinding, fires On Lunge Started |
| Action | Set Auto Control (on/off) | drive the movement pack vs expose intents |
| Action | Set Ledge Restriction (on/off) / Set Ledge Leniency (px) | patrol discipline |
| Action | Set Jump Positioning (strict/relaxed/default) / Set Coyote Time (s) | movement discipline |
| Action | Set Repath Interval (s) / Set Repath Threshold (px) | chase freshness |
| Action | Mark Slope Region / Set Tile State / Clear Slope Overrides | manual overrides (rare) |
| Action | Set Max Jump Height / Distance, Set Max Fall Distance | physics overrides (rare) |
| Trigger | On Path Found / On Path Failed / On Path Complete | the reaction trio |
| Trigger | On Waypoint Reached / On Waypoint Stuck / On Repath | progress + watchdog |
| Trigger | On Nav Graph Built | build finished (async-safe) |
| Trigger | On Lunge Started | Jump Toward launched |
| Condition | Has Path / Is Path Pending / Is At Ledge / Is On Island | state tests |
| Expression | Current Waypoint X/Y, Waypoint Count, Current Waypoint Index | path data |
| Expression | Current Path Action, Path Move Axis, Path Wants Jump | manual-drive feed |
| Expression | Path Cost, Path Target X/Y, Path Fail Reason | diagnostics |
| Expression | Distance To Waypoint, Angle To Waypoint | steering helpers |
| Expression | Node Count, Nearest Node X/Y | graph queries (GraphData tier trimmed to these) |

Multi-agent scheduling ships in v1 as a **shared path budget** on the autoload
(`Set Max Paths Per Tick`, `Is Path Pending`, `Path Queue Size`) - it is the difference between
20 enemies working and not, and it is cheap (the Time Slicer pattern already exists in-house).

### Debugability

- `Set Nav Debug Draw (on/off)`: draws nodes, edges, and the active path via a CanvasItem
  overlay (the original's debugger panel, translated to draw calls).
- Doctor checks: "graph built before find path", "slope-like tile unclassified",
  "PlatformerMovement missing and no manual driver" - clickable findings with the new Fix seam
  where a safe auto-fix exists.

---

## Pack 2: `nav_agent_3d` (3D)

3D pathfinding is a different problem (surfaces, not jump arcs) and Godot already solves it
well - the pack's job is making it SHEET-shaped and symmetric with the 2D pack:

- Behavior on `CharacterBody3D`/`Node3D`; on ready it auto-inserts a `NavigationAgent3D`
  child if none exists (zero wiring), tuned from exported knobs (radius, height, max speed).
- **Same verb names as 2D** wherever meanings align: `Find Path To (position/node)`,
  `Stop Pathfinding`, `Set Auto Control`, `Set Repath Interval`; triggers
  `On Path Found / Failed / Complete`, `On Waypoint Reached`; expressions
  `Current Waypoint X/Y/Z`, `Distance To Target`, `Path Move Vector`. A sheet author who
  learned one pack knows the other.
- **Auto mode** drives the sibling `FPSController` when present (its `add_look` +
  `ai` move intent - FPSController gains the same tiny `ai_move` input override as
  PlatformerMovement) or `CharacterBody3D.velocity` directly; NavigationAgent3D's avoidance
  handles multi-agent for free (`Set Avoidance (on/off)`).
- **Slopes in 3D are inherent**: the navmesh bakes walkable surfaces from geometry with a max
  slope angle - the pack exposes `Bake Navigation Region` (editor/runtime rebake of a
  NavigationRegion3D) and documents "slopes = bake setting", nothing to register.
- **Requires a `NavigationRegion3D`** in the scene; the Doctor gains a check that says so with
  a pointer to the guide, and the showcase ships one baked.

---

## Showcases + verification

- `demo/showcase/path_chase/` (2D): a tile level with slopes (45° + gentle), one-way platforms,
  a patrolling ledge-restricted guard, and a chaser that repaths to the player - drives the
  bundled PlatformerMovement. Debug-draw toggled on so the graph is VISIBLE in the showcase.
- The FPS Arena showcase gains a `nav_agent_3d` stalker capsule that paths to the player -
  proving 2D/3D verb symmetry and the FPSController drive in one scene.
- Tests: graph classification unit tests (slope cells from synthetic TileSets, ledge flags,
  one-way tops), arc-derivation from PlatformerMovement values, reach-vs-nearest semantics,
  intent stream for a known 3-platform path, `verify_pack` both packs; runtime smoke = drive a
  chaser across a jump in a headless physics run and assert arrival.

## Phases

- **P1**: 2D pack core - tilemap scan + auto slopes, graph, A*, reach/nearest, auto-drive of
  PlatformerMovement (+ its `ai_move_axis` seam), the reaction trio, waypoint expressions,
  debug draw, chase showcase.
- **P2**: discipline + robustness - ledge restriction/leniency, jump positioning modes, coyote
  time, repath threshold/cooldown, stuck watchdog, shared path budget, Doctor checks.
- **P3**: `nav_agent_3d` wrapper pack + FPS Arena stalker + verb-symmetry docs.
- **P4 (later, own asks)**: portals/elevators, hazards, moving platforms.

Frozen once shipped: every ace_id and codegen template above (compatibility covenant).
