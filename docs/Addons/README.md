# Addon Guides

Deep-dive guides for the bundled behavior packs in `eventsheet_addons/`. Each one covers when to reach
for the pack, its full ACE reference (Actions, Conditions, Expressions, Triggers), a dozen worked use
cases as event-sheet rows, and the tips and gotchas that bite in practice.

Every pack here is authored as an event sheet and compiles to plain GDScript with zero plugin
dependency, just like your own sheets - open its `.gd` in the editor to read it as events.

For the plugin's guides and references (not the packs), see the [documentation index](../README.md).

## Systems (autoload singletons)

Install as a single project-wide autoload you call from any sheet by name.

- [Currency Ledger](Currency-Ledger.md) - name your currencies, then earn, spend, cap, and format money, with min/max, daily caps, and offline gain.
- [Loot Table](Loot-Table.md) - weighted drop tables with guarantees, hard pity, nested tables, and seeded rolls.
- [Storylet Weaver](Storylet-Weaver.md) - quality-based narrative: register small storylets with requirements, then Draw the best eligible one.
- [SkinVault](SkinVault.md) - cosmetic ownership with rarities, tier-based pity, a purchase handshake, and grant/revoke.
- [ProcRoom](ProcRoom.md) - a seeded, tiered room-graph map (start to boss) with visited/available/locked traversal.
- [ComboBox](ComboBox.md) - an input-sequence detector: register token sequences, fire On Combo Matched, with timing windows and wildcards.
- [ObjectPool](ObjectPool.md) - reuse nodes instead of spawning and freeing them, so heavy scenes stay smooth.
- [Save System](Save-System.md) - save and load your variables and progress to disk.
- [Advanced Random](Advanced-Random.md) - richer randomness: weighted picks, shuffled bags, dice, and noise.

## Incremental and idle

The toolkit for clicker, idle, and incremental games. The wallet lives in Currency Ledger; these add the rest of the loop. Most are autoloads; Idle Generator attaches to a node (one per building type).

- [Big Numbers](Big-Numbers.md) - format idle-scale numbers (K/M/B/T through Dc, then scientific, plus time, ordinals, commas) and do arithmetic past a float's 1.8e308 ceiling with a Decimal type.
- [Idle Generator](Idle-Generator.md) - a buy-more-to-make-more building with a geometric cost curve, exact Buy One / Amount / Max, continuous production, and an optional fill-and-collect cycle. Attach one per generator type.
- [Click Power](Click-Power.md) - manual-tap income with a multiplier, crits, and an optional share of your production per click.
- [Boosts](Boosts.md) - temporary timed multipliers (golden-cookie frenzies) that count themselves down and expire.
- [Upgrades](Upgrades.md) - stacking one-time and repeatable buffs with add/mult modes and tags, bought against a budget, aggregated by Total Multiplier / Total Bonus.
- [Prestige](Prestige.md) - reset for a permanent multiplier, with the classic gain formula, a run/all-time split, and no double-award.
- [Milestones](Milestones.md) - threshold achievements that grant a permanent reward you aggregate into production.

## Movement (2D)

Attach to a node to move it.

- [Platformer](Platformer.md) - run, jump, gravity, and coyote time for a side-scroller.
- [Platformer Pathfinding](Platformer-Pathfinding.md) - jump-aware navigation: a graph built from your tiles, A* with walk/jump/fall/portal edges, driving Platformer movement through its AI seam (see the Path Chase showcase).
- [Nav Agent 3D](Nav-Agent-3D.md) - navmesh pathfinding for 3D, sheet-shaped: an auto-inserted NavigationAgent3D with the same verbs as the 2D pack, driving the FPS Controller or the body itself (see the FPS Arena's stalker).
- [Eight Direction](Eight-Direction.md) - top-down movement in eight directions.
- [Car](Car.md) - arcade car steering (turn-and-drive), no physics body needed.
- [Tile Movement](Tile-Movement.md) - grid-locked stepping, one tile per press.
- [Slide Movement](Slide-Movement.md) - grid movement where a tap slides you until you hit a wall.
- [Bound To](Bound-To.md) - keep anything inside the screen or a custom area (with On Hit Bound).
- [Wrap](Wrap.md) - Asteroids-style screen wrapping, per axis - rectangle or circular arenas.
- [Rotate](Rotate.md) - constant spin with speed + acceleration, 2D or any 3D axis, previewable in the editor.
- [Move To](Move-To.md) - move a node to a point or along a path.
- [Follow](Follow.md) - chase or trail another node with easing.
- [Bullet](Bullet.md) - fire a node in a straight line at a speed and angle.
- [Sine](Sine.md) - oscillate a property (position, size, angle) on a sine wave.
- [Orbit](Orbit.md) - circle a node around a centre point.

## Movement (3D)

- [FPS Controller](FPS-Controller.md) - a complete first/third-person character: mouse look, WASD move, sprint, jump, crouch + crouch slide, wall ride + wall jump, and a one-verb camera-mode switch (see the FPS Arena showcase).
- [Move To 3D](Move-To-3D.md) - move a 3D node to a point or along a path.
- [Bullet 3D](Bullet-3D.md) - fire a 3D node in a straight line.
- [Sine 3D](Sine-3D.md) - oscillate a 3D property on a sine wave.
- [Orbit 3D](Orbit-3D.md) - circle a 3D node around a centre.

## AI and logic

- [UHTN Planning](UHTN-Planning.md) - Utility AI steering an HTN: response-curve scorers rank the planner's methods live, with the whole plan authorable as a UHTNPlanResource .tres of Inspector grids. Supersedes the two packs below.
- [UtilityBrain](UtilityBrain.md) - score actions by considerations and response curves, then Evaluate; the best action wins.
- [HTN Agent](HTN-Agent.md) - hierarchical task-network planning: goals decompose into ordered tasks.
- [State Machine](State-Machine.md) - named states with enter/exit and transitions.
- [Line Of Sight](Line-Of-Sight.md) - can this node see a target (2D raycast, cone, range).
- [Line Of Sight 3D](Line-Of-Sight-3D.md) - the same, in 3D.

## Combat and gameplay

- [Physics Car](Physics-Car.md) - a force-driven arcade car on a RigidBody2D, with grip and drift.
- [Weapon Kit](Weapon-Kit.md) - fire rates, ammo, reloads, and spread for a weapon.
- [Health](Health.md) - hit points with absorption and shield pools, damage and heal events.
- [StatForge](StatForge.md) - stats as a buff stack: add/multiply/override modifiers with tags, sources, timers, threshold rules, and .tres loadouts (StatSheetResource).
- [Simple Abilities](Simple-Abilities.md) - cooldown-gated abilities you trigger by name.

## Visuals and juice

- [Juice](Juice.md) - screenshake, recoil, head bob, jitter, camera tilt, smooth zoom, squash and stretch, slowmo, and hitstop (2D).
- [Juice 3D](Juice-3D.md) - camera shake, weapon recoil, head bob, jitter, lean, and FOV punch/zoom on the active Camera3D.
- [Flash](Flash.md) - flash a sprite a colour on hit.
- [Fade](Fade.md) - fade any sprite or UI in and out by animating its transparency.
- [Spring](Spring.md) - springy, bouncy motion toward a target value.
- [Tween](Tween.md) - animate a property to a value over time with easing.

## UI and flow

- [HUD Kit](HUD-Kit.md) - drive menus and HUDs by name with zero wiring.
- [Scene Flow](Scene-Flow.md) - fades and scene changes.
- [Dialogue Kit](Dialogue-Kit.md) - typewriter conversations with named UI.
- [Virtual Cursor](Virtual-Cursor.md) - a gamepad-driven pointer for controller UI.
- [Drag And Drop](Drag-And-Drop.md) - make a node draggable, with drop targets.
- [Drawing Canvas](Drawing-Canvas.md) - draw shapes, ribbons, raycast line-of-sight fans, and reusable DRAWING PREFABS (ordered .tres formations) onto a live texture (persistent paint or per-frame telegraphs). See the Draw Lab showcase.
- [Decal Painter](Decal-Painter.md) - 3D blob shadows, splats with lifetimes, and 2D-canvas textures projected onto the world.

## Timing and performance

- [Timer](Timer.md) - named countdowns and repeating timers with triggers.
- [Time Slicer](Time-Slicer.md) - spread heavy work across frames to avoid hitches.
- [Run In Background](Run-In-Background.md) - keep logic running while the window is unfocused.

## Building your own

Want to author a pack like these, an ACE module, or an editor tool? See
[Creating custom modules](../GUIDE-CREATING-CUSTOM-MODULES.md),
[Building editor tools with event sheets](../GUIDE-BUILDING-EDITOR-TOOLS.md), and
[Building on EventSheets](../GUIDE-BUILDING-ON-EVENTSHEETS.md).
