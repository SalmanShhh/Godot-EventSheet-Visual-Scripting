# Addon Guides

Deep-dive guides for the bundled behavior packs in `eventsheet_addons/`. Each one covers when to reach
for the pack, its full ACE reference (Actions, Conditions, Expressions, Triggers), how to read its
knobs and values from any ƒx field through the **Self section** (type `self` and the attached pack's
entries insert as `$PackName.member` chains), fifteen or more worked use cases as event-sheet rows,
and the tips and gotchas that bite in practice.

A pack without a guide here is not a dead end: the Manual gives it a reference page listing
everything it publishes, with a **Write this guide** button that scaffolds one.

Every pack here is authored as an event sheet and compiles to plain GDScript with zero plugin
dependency, just like your own sheets - open its `.gd` in the editor to read it as events.

Writing a guide for YOUR pack? Scaffold it - the factual tables pre-filled from your script,
only the use cases left to write:

```
godot --headless --path . --script tools/scaffold_addon_guide.gd -- eventsheet_addons/<your_pack>
```

(or `EventSheets.addon_guide_skeleton(script_path)` from code.)

Shipping an update to your pack? **Sheet > Publish New Version…** bumps its `@ace_version`
(Patch / Minor / Major, with a live old → new preview) and records your one-line change note
as a doc comment under the annotation, so the file accumulates its own changelog - or call
`EventSheets.publish_pack_version(script_path, bump, note)` from tooling.

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
- [Debug Overlay](Debug-Overlay.md) - watches, bars, world marks, rays and node labels drawn over the running game, in debug builds only, off until a row asks.
- [Save System](Save-System.md) - save and load your variables and progress to disk.
- [Quest](Quest.md) - quests as .tres data assets: objectives, chains, rewards, and triggers, with the "3/5" journal text one expression away.
- [Game Settings](Game-Settings.md) - settings that declare themselves: one default, an On Setting Changed trigger to branch on, and an options menu buildable from the declaration.
- [Phase Cycle](Phase-Cycle.md) - day/night and any repeating phases: cycle, react on change, and read the 0-1 progress for sun dials.
- [Platform Info](Platform-Info.md) - what is this game running on: OS/device/screen/touch/locale/GPU/CPU conditions and expressions, safe-area insets included.
- [Advanced Random](Advanced-Random.md) - richer randomness: weighted picks, shuffled bags, dice, and noise.
- [Event Bus](Event-Bus.md) - a game-wide message board addressed by name: broadcast a channel with a payload, answer it with On Event anywhere, and Wait For Event with a give-up time.
- [Named Scenes](Named-Scenes.md) - give each .tscn a short name so rows stop carrying res:// paths, carry a record into the next scene, and read back On Scene Ready / Current Scene Is.
- [Mods](Mods.md) - the folder players put their own content in: load a folder of mods in a load order you set, in one of two tiers the row picks. Data only reads a mod's real contents first and refuses one carrying code; the script tier says what it costs, because Godot has no sandbox and none is claimed here.
- [Second View](Second-View.md) - a second picture of the world you are already in: name a view, give it a node to follow, and show it in a frame. Minimaps, security monitors, portraits, rear-view mirrors and magnifiers are the same four rows.
- [Music](Music.md) - one song at a time, crossfaded rather than cut: layers that come up as the danger rises and cannot drift because they are one stream, a stinger that ducks the music for its own length, and a beat read off the playback position rather than counted, so a pulse stays on the beat for a twelve-minute track. Songs are MusicTrackResource files you own.
- [Prompts](Prompts.md) - the visible half of a quick-time event, over the Timed Input rows that already grade one: the prompt with the shrinking ring, the glyph for the device actually in the player's hands, holds, mashes and sequences, and a note that travels a lane to land on the song's next beat. Glyphs are a GlyphSheetResource you own.
- [Codex](Codex.md) - the set of things the player has found: a bestiary, a recipe book, a gallery or a list of visited rooms, where a set is a folder and an entry is a file you own. Discover one, ask whether it is in, count a set, and walk the discovered pages to draw the screen.

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
- [Nav Agent 3D](Nav-Agent-3D.md) - navmesh pathfinding for 3D, sheet-shaped: an auto-inserted NavigationAgent3D with the same vocabulary as the 2D pack, driving the FPS Controller or the body itself (see the FPS Arena's stalker).
- [Eight Direction](Eight-Direction.md) - top-down movement in eight directions.
- [Car](Car.md) - arcade car steering (turn-and-drive), no physics body needed.
- [Tile Movement](Tile-Movement.md) - grid-locked stepping, one tile per press.
- [Slide Movement](Slide-Movement.md) - grid movement where a tap slides you until you hit a wall.
- [Traversal Kit](Traversal-Kit.md) - ledge grabs, mantles, wall slides, wall jumps, wall runs, ladders, vaults, crouching and swimming, written as velocity on top of your mover.
- [Bound To](Bound-To.md) - keep anything inside the screen or a custom area (with On Hit Bound).
- [Wrap](Wrap.md) - Asteroids-style screen wrapping, per axis - rectangle or circular arenas.
- [Rotate](Rotate.md) - constant spin with speed + acceleration, 2D or any 3D axis, previewable in the editor.
- [Move To](Move-To.md) - move a node to a point or along a path.
- [Follow Path](Follow-Path.md) - walk a drawn Path2D at a real speed, once, looping or ping-pong, with On Path Finished at the end.
- [Follow](Follow.md) - chase or trail another node with easing.
- [Pin](Pin.md) - stick one object to another in eight modes: position, angle, both, a rope that only pulls when taut, a bar that holds its length, a soft follow that lags, a spring that settles, and the anchor's size - plus one axis at a time, a named point on the anchor (a marker, a bone, a hand) and a point travelling a path.
- [Skateboard](Skateboard.md) - momentum movement on a board: a push you keep, gravity projected along the slope so halfpipes work, ollies, manuals, spins and flips judged on landing, rail and zipline grinds, and a trick chain that multiplies until you bank it.
- [Pin](Pin.md) - stick one object to another: position, angle or both, with the offset remembered.
- [Bullet](Bullet.md) - fire a node in a straight line at a speed and angle.
- [Sine](Sine.md) - oscillate a property (position, size, angle) on a sine wave.
- [Orbit](Orbit.md) - circle a node around a centre point.

## Movement (3D)

- [FPS Controller](FPS-Controller.md) - a complete first/third-person character: mouse look, WASD move, sprint, jump, crouch + crouch slide, wall ride + wall jump, and a one-action camera-mode switch (see the FPS Arena showcase).
- [Move To 3D](Move-To-3D.md) - move a 3D node to a point or along a path.
- [Bullet 3D](Bullet-3D.md) - fire a 3D node in a straight line.
- [Sine 3D](Sine-3D.md) - oscillate a 3D property on a sine wave.
- [Orbit 3D](Orbit-3D.md) - circle a 3D node around a centre.
- [Pin 3D](Pin-3D.md) - the Pin behavior's twin on a Node3D host, mode for mode, with the point pin riding a BoneAttachment3D so "pin the sword to the hand" is one name.
- [Skateboard 3D](Skateboard-3D.md) - the board on a surface: gravity projected onto the floor normal so bowls carve, the board kept flat on ramps, a named moment for leaving a halfpipe lip, Path3D grinds, and landings judged by the board's up against the surface.
- [Traversal Kit 3D](Traversal-Kit-3D.md) - the same traversal moveset in metres: ledge grabs, mantles, wall runs, ladders, vaults, crouching, swimming and buoyancy on top of the FPS Controller.

## AI and logic

- [UHTN Planning](UHTN-Planning.md) - Utility AI steering an HTN: response-curve scorers rank the planner's methods live, with the whole plan authorable as a UHTNPlanResource .tres of Inspector grids. Supersedes the two packs below.
- [UtilityBrain](UtilityBrain.md) - score actions by considerations and response curves, then Evaluate; the best action wins.
- [HTN Agent](HTN-Agent.md) - hierarchical task-network planning: goals decompose into ordered tasks.
- [State Machine](State-Machine.md) - named states with enter/exit and transitions.
- [Drunken Walkers](Drunken-Walkers.md) - seeded grid generation: walkers carve caves, corridors, rivers and ore veins, tagged marks land with real placement and spacing rules, and one seed reproduces the whole map.
- [Home & Leash](Home-And-Leash.md) - a home point, a leash distance with five geometry metrics, and a return-home walk with its arrival trigger.
- [Line Of Sight](Line-Of-Sight.md) - can this node see a target (2D raycast, cone, range).
- [Line Of Sight 3D](Line-Of-Sight-3D.md) - the same question in 3D: raycast, cone of view and range.

## Combat and gameplay

- [Checkpoint](Checkpoint.md) - set a checkpoint, respawn at it, and let the shared reset() seam clear velocity and hp.
- [Interaction](Interaction.md) - focus the nearest interactable in range, press to interact, and let each thing answer On Interacted.
- [Priced Tables](Priced-Tables.md) - the priced-interaction table (vendors, kiosks, toll gates, skill trees) as a .tres of entries: prices, stock, unlock gates, and one Buy Entry row that spends through whatever wallet answers.
- [Encounter Timeline](Encounter-Timeline.md) - spawn beats on a schedule (waves, boss phases, tutorial pacing, ambient traffic) from a .tres, pooled when a pool is there, with a derived plain-text report of the plan and its density.
- [Physics Car](Physics-Car.md) - a force-driven arcade car on a RigidBody2D, with grip and drift.
- [Weapon Kit](Weapon-Kit.md) - fire rates, ammo, reloads, and spread for a weapon.
- [Targeting](Targeting.md) - one held enemy and a steadier aim in 2D: Lock On To Nearest searches a cone around the host's facing and holds the closest member of a group, Cycle Target walks that ring left to right by angle, and a lock ends in exactly four ways that On Target Lost names. Assisted Aim and Magnetism need no lock at all and read the aim-assist radius the accessibility page already declares, so a radius of zero is the off switch.
- [Targeting 3D](Targeting-3D.md) - the same words on a Node3D, with the two things only 3D has: the cone is centred on the camera the player is looking through rather than the host's own rotation, falling back to the host's forward axis when there is no camera to ask, and Snap On Aim Down Sights tightens the view onto what the aim was already nearly on while refusing any turn wider than the row allows.
- [Health](Health.md) - hit points with absorption and shield pools, damage and heal events.
- [Status Effects](Status-Effects.md) - burn, poison, slow, stun, freeze and shield as StatusEffectResource files you own: a status is a word and a clock, its ticks go through the Health pack's typed damage, and its tint, stacking rule and cleansability live on the file.
- [StatForge](StatForge.md) - stats as a buff stack: add/multiply/override modifiers with tags, sources, timers, threshold rules, and .tres loadouts (StatSheetResource).
- [Simple Abilities](Simple-Abilities.md) - cooldown-gated abilities you trigger by name.

## Visuals and juice

- [Juice](Juice.md) - screenshake, recoil, head bob, jitter, camera tilt, smooth zoom, squash and stretch, slowmo, and hitstop (2D).
- [Feedback Player](Feedback-Player.md) - the list of feedbacks one object carries: a node under it holding cards (shakes, flashes, holds, loops, a property walked, a word said), played by one row whose strength scales every amount in the list. The list is the same shape a moment file holds, so a beat saves out, loads back and moves between objects, and every card is addressable by label while the game runs.
- [Juice 3D](Juice-3D.md) - camera shake, weapon recoil, head bob, jitter, lean, and FOV punch/zoom on the active Camera3D.
- [Camera Rail](Camera-Rail.md) - a shot list for a camera: Fly Along walks it down a drawn path over a number of seconds, Hold parks it on a beat, Blend To travels it onto another camera and hands the view over, and Cut To switches outright. On Shot Finished chains the next shot, so a cutscene is rows rather than a coroutine. Camera Rail 3D is the twin, keeping a node in frame and carrying the lens through a blend.
- [Light Flicker](Light-Flicker.md) - a flame, as a behaviour: any light's brightness walks between two numbers on a noise field, with the flame's numbers in the Inspector and Start / Stop Flickering as the rows. 2D and 3D both, because it asks the host which property it spells brightness with.
- [Light Pulse](Light-Pulse.md) - a light that breathes: the same two rows on a smooth wave instead of a noise field, for beacons, pickups, runes and alarms. Period is a rhythm, so two pulses stay in time.
- [Day/Night Cycle](Day-Night-Cycle.md) - one clock that runs the sky: a whole day every N minutes, the sun turning with the hour, three Inspector curves for sun, ambient and sky, and On Sunrise / Sunset / Midnight / The Hour as the moments. Drives a WorldEnvironment or a 2D CanvasModulate.
- [Flash](Flash.md) - flash a sprite a colour on hit.
- [Hit Flash](Hit-Flash.md) - the white-out that makes a strike land, as a shader rather than a modulate: it mixes the sprite's own pixels towards a colour, so a dark sprite whites out as far as a bright one. Ships its shader into your project on the first add.
- [Dissolve](Dissolve.md) - burn a sprite away along a noise field with a glowing edge, and burn it back. On Dissolved is where the loot drops, the pool takes the node back, or the row frees it.
- [Outline](Outline.md) - a border around what the sprite actually is, following its own alpha rather than its rectangle: the selection ring, the interactable marker, the rarity colour, the accessibility highlight.
- [Grayscale](Grayscale.md) - drain the colour out of one node, all the way or part of it, for a disabled button, a dead unit still on the board or a whole world paused behind a menu. The grey takes a tint, so sepia and frozen are the same two rows.
- [Wave](Wave.md) - ripple the picture without moving the node: water, heat haze, flags and dizziness, with collisions and positions untouched because only the drawing sways.
- [Screen FX](Screen-FX.md) - full-screen effects as ordinary rows: a shockwave ring from a world point, an awaited fade you build a scene transition out of, a blur and a chromatic pulse on one rectangle - and on top of them the post stack, a named list of twelve shipped full-screen effects drawn in order, with Pulse Post Effect as the one-row form that needs no setup. See As and Correct Colours For answer the colour-vision question, and a look is the whole live stack saved as a file you own.
- [Blend Modes](Blend-Modes.md) - the twenty ways one picture meets the one behind it: the five Godot draws by itself and the fifteen that need a shader reading the screen back, one shader file each, picked from a strip that draws every mode rather than naming it. Plus masks, so a second picture decides where the first is allowed to be, and Blend As One for a node's children drawn as a single picture.
- [Post Kit](Post-Kit.md) - the camera's own post stack, on Forward+: vignette, desaturate, pixelate, tint and fade as CompositorEffects, wearing the same words the 2D stack uses so a row reads alike on the screen and on the camera. Plus the thing only a 3D camera can do - an outline or a silhouette drawn through whatever is in front of it. On Mobile and Compatibility every row does nothing rather than erroring, and the Doctor says so once with the door.
- [Fade](Fade.md) - fade any sprite or UI in and out by animating its transparency.
- [Spring](Spring.md) - springy, bouncy motion toward a target value.
- [Tween](Tween.md) - animate a property to a value over time with easing.

## Sound, feel and rhythm

The runtime files in `eventsheet_addons/` that the built-in vocabulary calls. There is nothing to
attach: the rows are already in the picker, and what the project owns is the shape file each one
plays.

- [Haptics](Haptics.md) - what a hit feels like in the hand: a haptic pattern file you own (how hard, how long, how many times, the air between) played on whatever the player is holding, plus a one-knock emphasis and a continuous rumble that is two calls rather than a call a frame. Every amplitude is scaled by the player's own haptic dial, and a machine with nothing to rumble is silent rather than noisy.
- [Sequencer](Sequencer.md) - a grid of moments on a beat: tracks down the side, steps across the top, and a name in a cell. Every crossed cell is said as the node's own signal and to the group the track is named after, tracks wrap at their own length so cross-rhythms cost nothing, and the song's clock wins whenever there is a song.
- [Bus Mix](Bus-Mix.md) - a bus swept rather than switched: a muffle walking a low-pass cutoff down, a dive walking a level through an amplify (never the volume the player chose), a wash growing a reverb behind the sound, one Restore Bus that puts them all back where they rested, and named snapshots of the whole desk.

## UI and flow

- [HUD Kit](HUD-Kit.md) - drive menus and HUDs by name with zero wiring.
- [Scene Flow](Scene-Flow.md) - fades and scene changes, and the seven shapes one can wear: a wipe following a picture you painted, a dissolve, an iris, blinds, pixelate or a page curl, each one shader file with one progress dial. The cover walks on, the scene is swapped underneath it, and On Transition Finished arrives in the new scene.
- [Dialogue Kit](Dialogue-Kit.md) - typewriter conversations with named UI.
- [Virtual Cursor](Virtual-Cursor.md) - a gamepad-driven pointer for controller UI.
- [Anchor](Anchor.md) - where a panel sits when the window resizes: anchor a Control to a corner, an edge or the full rect as one row, nudge it with pixel margins, and let it place itself again on every resize.
- [Touch Gestures](Touch-Gestures.md) - fingers as sentences: On Swipe with a named direction (four-way or eight), On Shape Drawn for shapes you taught by drawing them once, and a Touch Shape Library .tres so the taught shapes ship with the project.
- [Drag And Drop](Drag-And-Drop.md) - make a node draggable, with drop targets.
- [Vector Shapes](Vector-Shapes.md) - shapes you PLACE rather than paint: seven Node2D nodes (Line, Disc, Rect, Polygon, Polyline, Triangle, Regular Polygon) and ten 3D twins, each one quad wearing one distance-field shader, so a ring is round at 4x zoom and a hairline stays one pixel. Thickness carries its unit, dashes have a count and an offset that scrolls, and the look half of a shape saves out as a Shape Style file twenty shapes can wear.
- [Drawing Canvas](Drawing-Canvas.md) - draw shapes, ribbons, raycast line-of-sight fans, and reusable DRAWING PREFABS (ordered .tres formations) onto a live texture (persistent paint or per-frame telegraphs). The canvas keeps a DRAW STYLE - Set, Push, Pop and Reset - so a debug overlay says its width and colour once and the rows after it carry neither. See the Draw Lab showcase.
- [Decal Painter](Decal-Painter.md) - 3D blob shadows, splats with lifetimes, and 2D-canvas textures projected onto the world.

## Timing and performance

- [Timer](Timer.md) - named countdowns and repeating timers with triggers.
- [Time Slicer](Time-Slicer.md) - spread heavy work across frames to avoid hitches.
- [Run In Background](Run-In-Background.md) - keep logic running while the window is unfocused.
- [Streamer](Streamer.md) - a 2D world bigger than memory: your map is a folder of scenes named by cell, and this keeps the ones within a radius of a node loaded on a thread, freeing the ones behind, with a frame budget and a keep radius so walking back over a border reloads nothing.
- [Streamer 3D](Streamer-3D.md) - the same nine words on a Vector3i grid, with one decision: leave Stream Height off and the grid is flat, which is what an open world wants, or turn it on for a station, a cave or a tower and watch a radius of 1 go from nine chunks to twenty-seven.
- [Folder Watcher](Folder-Watcher.md) - notice a file in one folder appearing, changing or going away. Godot has no runtime file watcher, so this POLLS on the interval you name and says so on the row.

## Building your own

Want to author a pack like these, an ACE module, or an editor tool? See
[Creating custom modules](../GUIDE-CREATING-CUSTOM-MODULES.md),
[Building editor tools with event sheets](../GUIDE-BUILDING-EDITOR-TOOLS.md), and
[Building on EventSheets](../GUIDE-BUILDING-ON-EVENTSHEETS.md).
