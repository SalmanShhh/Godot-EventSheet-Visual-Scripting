# Project vocabulary — Godot EventSheets

> Generated — do not edit. Regenerate via the dock (Tools → Vocabulary Doc…) or
> `godot --headless --path . --script tools/vocabulary_doc.gd`.

## Sheets

### player (`res://demo/sheets/player.tres`)
Node script extending `CharacterBody2D`.

#### Properties
- `health: int` (default `100`)
- `speed: float` (default `200.0`)

### PlatformerShooter (`res://demo/showcase/platformer_shooter.tres`)
Node script extending `Node2D`.

#### Properties
- `score: int` (default `0`) — Targets destroyed.

### QuestFsm (`res://demo/showcase/quest_fsm.tres`)
Node script extending `Node2D`.

#### Properties
- `quest_state: int` (default `0`) — 0=OFFERED, 1=ACTIVE, 2=COMPLETE.

### CarouselOfJuice (`res://demo/showcase/showcase_carousel.tres`)
Node script extending `Node2D`.

#### Properties
- `beat: int` (default `0`) — Beats elapsed.
- `intensity: float` (default `1.4`) — Spring kick strength.
- `party_on: bool` (default `true`) — Is the Juice group running.

### Starfall (`res://demo/showcase/starfall.tres`)
Node script extending `Node2D`.

#### Properties
- `lives: int` (default `3`) — Misses remaining.
- `score: int` (default `0`) — Stars caught.
- `ship_speed: float` (default `320.0`) — Ship move speed (px/s).
- `state: int` (default `0`) — 0=PLAYING, 1=GAME_OVER.

### Swarm (`res://demo/showcase/swarm.tres`)
Node script extending `Node2D`.

#### Properties
- `count: int` (default `800`) — How many sprites to spawn.

## Script packs

### SimpleAbilitiesBehavior (`res://eventsheet_addons/abilities/abilities_behavior.gd`)

#### Triggers
- **On Ability Activated**

#### Conditions
- **Has Ability** (`id: String`)
- **Is Ability Ready** (`id: String`)
- **Is Ability Active** (`id: String`)
- **Is Ability Enabled** (`id: String`)
- **Has Stacks Available** (`id: String`)
- **Ability Has Tag** (`id: String, tag: String`)
- **Current Ability Is** (`id: String`)

#### Actions
- **Create Ability** (`id: String`) — Grants an empty ability (no cooldown, 1 stack, enabled). Fires On Ability Created if new.
- **Create Ability With Cooldown** (`id: String, seconds: float, reset_instantly: bool`) — Grants an ability and sets its cooldown. reset_instantly=true starts it ready.
- **Create Ability With Cooldown And Stacks** (`id: String, seconds: float, max_stacks: int, reset_instantly: bool`) — Grants a charge-based ability; each stack regenerates over `seconds`. reset_instantly=true starts full.
- **Create Temporary Ability** (`id: String, seconds: float`) — Grants an ability that auto-removes after `seconds`. Calling again refreshes the timer.
- **Remove Ability After Duration** (`id: String, seconds: float`) — Schedules removal of an existing ability after `seconds`.
- **Remove Ability** (`id: String`) — Deletes an ability and all its data. Fires On Ability Removed.
- **Clear All Abilities** — Removes every ability. Fires On Ability Removed for each.
- **Activate Ability** (`id: String`) — Activates an ability if it is ready: consumes a stack, starts regen, fires On Ability Activated.
- **Set Ability Cooldown** (`id: String, seconds: float`) — Puts an ability on cooldown (scaled by the global cooldown multiplier).
- **Reset Cooldown** (`id: String`) — Sets an ability's cooldown to 0 (instantly ready).
- **Set Max Stacks** (`id: String, max_stacks: int`) — Changes max charges (current stacks clamp down).
- **Set Stacks** (`id: String, stacks: int`) — Sets current charges (clamped 0..max).
- **Add Stacks** (`id: String, count: int`) — Adds charges up to max. Fires On Stack Gained, and On Max Stacks Reached if it would overflow.
- **Consume Ability Stack** (`id: String`) — Removes one charge without activating; starts regen if needed.
- **Set Ability Enabled** (`id: String, enabled: bool`) — Enables or disables activation.
- **Set Ability Active** (`id: String, active: bool`) — Sets the active flag (for channeled / toggle abilities).
- **Set Ability Data** (`id: String, key: String, value: String`) — Stores a custom key/value (string) on an ability.
- **Add Tag** (`id: String, tag: String`) — Tags an ability (safe if it already has the tag).
- **Remove Tag** (`id: String, tag: String`) — Removes a tag from an ability.
- **Clear All Tags** (`id: String`) — Removes every tag from an ability.
- **Set Abilities With Tag Enabled** (`tag: String, enabled: bool`) — Enables/disables every ability carrying a tag.
- **Remove All Abilities With Tag** (`tag: String`) — Deletes every ability with a tag. Fires On Ability Removed for each.
- **Reset Cooldown For Abilities With Tag** (`tag: String`) — Sets cooldown to 0 for every ability with a tag.
- **Set Cooldown Multiplier** (`multiplier: float`) — Global cooldown scaling for all future Set Cooldown calls (0.8 = 20% cooldown reduction).

#### Expressions
- **Current Ability ID**
- **Cooldown Remaining** (`id: String`)
- **Cooldown Progress** (`id: String`)
- **Stacks** (`id: String`)
- **Max Stacks** (`id: String`)
- **Stack Cooldown Remaining** (`id: String`)
- **Stack Progress** (`id: String`)
- **Expiration Time** (`id: String`)
- **Expiration Progress** (`id: String`)
- **Max Expiration Time** (`id: String`)
- **Ability Count**
- **List Active Abilities**
- **Ready Abilities**
- **Ability Data** (`id: String, key: String`)
- **Count Abilities By Tag** (`tag: String`)
- **Ability By Tag Index** (`tag: String, index: int`)
- **List Abilities By Tag** (`tag: String`)

### AdvancedRandomAddon (`res://eventsheet_addons/advanced_random/advanced_random_addon.gd`)
@ace_tags(random, noise, procedural)

#### Conditions
- **Chance** (`percent: float`) — True roughly percent of the time (0-100) — e.g. Chance(5) for a 5% event.
- **One In** (`n: int`) — True with a 1-in-n probability.

#### Actions
- **Set Seed** (`seed_value: int`) — Sets the seed for BOTH numbers and noise — same seed reproduces the same sequence.
- **Randomize Seed** — Picks a fresh, unpredictable seed (non-reproducible).
- **Set Noise Type** (`noise_type: int`) — FastNoiseLite.NoiseType: 0 Simplex · 1 Simplex Smooth · 2 Cellular · 3 Perlin · 4 Value Cubic · 5 Value.
- **Set Noise Frequency** (`frequency: float`) — Lower = smoother/larger features; higher = noisier (default 0.01).
- **Set Noise Octaves** (`octaves: int`) — Fractal detail layers — more octaves add fine detail (fractal/fBm noise).
- **Generate Permutation Table** (`size: int`) — Builds a shuffled 0..size-1 table (read with the Permutation expression) — a fixed deck order.
- **Make Shuffle Bag** (`bag_name: String, items: Array`) — Creates a named bag of items — Shuffle Bag Pick draws each once before any repeats.

#### Expressions
- **Random (0-1)** — A uniform float in [0, 1).
- **Random Range** (`minimum: float, maximum: float`) — A uniform float between min and max.
- **Random Int** (`minimum: int, maximum: int`) — A uniform integer between min and max (inclusive).
- **Roll Dice** (`sides: int`) — Rolls a die with the given number of sides (1..sides).
- **Random Sign** — Either -1 or +1.
- **Normal (Gaussian)** (`mean: float, deviation: float`) — A normally-distributed float around mean with the given deviation.
- **Noise 1D** (`x: float`) — Smooth noise along a line at x — returns [-1, 1].
- **Noise 2D** (`x: float, y: float`) — Smooth noise at (x, y) — great for terrain/heightmaps; returns [-1, 1].
- **Noise 3D** (`x: float, y: float, z: float`) — Smooth noise at (x, y, z) — returns [-1, 1].
- **Permutation Value** (`index: int`) — Reads index (wrapped) from the permutation table — generate it first.
- **Pick From** (`options: Array`) — A uniformly-random element of the array (null if empty).
- **Weighted Index** (`weights: Array`) — An index chosen in proportion to the weights array (heavier = likelier).
- **Shuffle Bag Pick** (`bag_name: String`) — Draws the next item from a named bag — every item appears once before any repeat.

### BackgroundRunner (`res://eventsheet_addons/background_runner/background_runner_behavior.gd`)
@ace_tags(performance, threading)

#### Triggers
- **On Done** (`result: Variant`)

#### Conditions
- **Is Running**

#### Actions
- **Run In Background** (`work: Callable`) — Runs a PURE callable off the main thread; On Done(result) fires when it finishes. WARNING: the callable must NOT touch nodes / the scene tree / non-thread-safe resources — data in, data out only.
- **Run Batch In Background** (`items: Array, work: Callable`) — Fans an array across worker threads: runs work.bind(item) for each item (On Done fires per item). The callable must be PURE.

#### Expressions
- **Tasks Running**

### BulletBehavior (`res://eventsheet_addons/bullet/bullet_behavior.gd`)

#### Actions
- **Set Bullet Speed** (`value: float`) — Changes speed, keeping the current direction.
- **Set Angle Of Motion** (`degrees: float`) — Redirects the bullet (degrees).
- **Set Bullet Enabled** (`is_enabled: bool`) — Pauses or resumes the movement.

### Bullet3DBehavior (`res://eventsheet_addons/bullet_3d/bullet_3d_behavior.gd`)

#### Actions
- **Launch Forward** — (Re)launches along the host's current forward direction.
- **Set Bullet 3D Speed** (`value: float`) — Changes speed, keeping the current direction.

### CarBehavior (`res://eventsheet_addons/car/car_behavior.gd`)

#### Triggers
- **On Drift Started**

#### Actions
- **Stop Car** — Kills all momentum.

### DemoHealthAddon (`res://eventsheet_addons/demo_health_addon.gd`)
Demo EventSheet ACE addon. Drop scripts like this into res://eventsheet_addons/ and their annotated members become project-wide ACEs automatically — no manifest, no JSON, no per-sheet setup. Provider name comes from class_name, this comment is the addon description, and @ace_* annotations customize each ACE.

#### Triggers
- **On Healed** (`amount: int`) — Fires after health is restored.

#### Conditions
- **Is Hurt** (`threshold: int`) — True while health is below the given threshold.

#### Actions
- **Heal** (`amount: int`) — Restores health by an amount.
- **Announce Heal** (`amount: int`) — Prints a heal announcement. No @ace_codegen_template on purpose: the generated script owns a DemoHealthAddon instance and calls this directly (instance-backed ACE — the zero-config default for template-less addon methods).

### DragDropBehavior (`res://eventsheet_addons/drag_drop/drag_drop_behavior.gd`)

#### Triggers
- **On Drag Started**

#### Conditions
- **Is Dragging**
- **Is Enabled**
- **Is Snapping**

#### Actions
- **Start Drag** (`drag_point_x: float, drag_point_y: float, grab_mode: int`) — Begins a drag at a point. grab_mode 0 = keep offset from the host; 1 = centre on the point.
- **Start Drag At Object** (`target: Node2D, grab_mode: int`) — Begins a drag that follows the given object each tick.
- **Drop** (`how: int`) — Ends the drag. how 0 = apply throw/snap; 1 = cancel silently.
- **Set Drag Point** (`x: float, y: float`) — Updates the drag point (call each tick from your input source).
- **Set Drag Point To Object** (`target: Node2D`) — Sets the drag point to an object's current position (one-shot).
- **Set Follow Speed** (`speed: float`) — Max catch-up speed (px/s); 0 = instant snap each tick.
- **Set Directions** (`dirs: int`) — Direction lock: 0 free, 1 up/down, 2 left/right, 3 four-dir, 4 eight-dir.
- **Set Break Distance** (`distance: float, action: int`) — Auto-end the drag past this gap; action 0 = drop, 1 = cancel. 0 distance disables.
- **Set Throw Velocity** (`velocity_x: float, velocity_y: float`) — Overrides the auto-measured throw velocity for the next drop.
- **Set Enabled** (`is_enabled: bool`) — Enables/disables; disabling mid-drag cancels silently.
- **Add Snap Position** (`x: float, y: float`) — Registers a fixed snap/magnet position.
- **Add Snap Object** (`target: Node2D`) — Registers an object whose position is a live snap/magnet target.
- **Clear Snap Targets** — Removes every snap position and object.
- **Set Snap Radius** (`radius: float`) — Distance within which snapping/magnetism engages.
- **Set Snap Mode** (`mode: int`) — 0 = host-position proximity; 1 = drag-point overlap (v1 radius approximation).
- **Set Magnet Strength** (`strength: float`) — How strongly the drag is pulled toward a nearby snap target (0..1).

#### Expressions
- **Drag Point X**
- **Drag Point Y**
- **Drag Point Object UID**
- **Distance From Point**
- **Throw Velocity X**
- **Throw Velocity Y**
- **Throw Speed**
- **Drop Reason**
- **Snap Target X**
- **Snap Target Y**
- **Snapped Object UID**

### EightDirectionMovement (`res://eventsheet_addons/eight_direction/eight_direction_movement_behavior.gd`)

#### Actions
- **Set Move Speed** (`speed: float`) — Changes the movement speed.

### FlashBehavior (`res://eventsheet_addons/flash/flash_behavior.gd`)

#### Triggers
- **On Flash Finished**

#### Actions
- **Flash** (`seconds: float`) — Blinks the host for the given number of seconds.
- **Stop Flash** — Stops flashing and restores visibility.

### FollowBehavior (`res://eventsheet_addons/follow/follow_behavior.gd`)

#### Triggers
- **On Reached Target**

#### Actions
- **Start Following** (`path: String`) — Follows the node at the given path.
- **Stop Following** — Stops trailing the target.

### SimpleHealthBehavior (`res://eventsheet_addons/health/health_behavior.gd`)

#### Triggers
- **On Damaged**

#### Conditions
- **Is Dead**
- **Is Invulnerable**
- **Has Any Health Pool**
- **Has Health Pool** (`type: String`)
- **Health Pool Is Type** (`type: String`)

#### Actions
- **Take Damage** (`amount: float`) — Applies damage; health pools absorb in ascending-priority order before real HP.
- **Heal** (`amount: float`) — Restores health up to max_health.
- **Set Health** (`amount: float`) — Sets current health directly, firing damage/heal/death as appropriate.
- **Set Max Health** (`amount: float`) — Sets max health (clamps current down if needed).
- **Set Invulnerable** (`state: bool`) — Toggles invulnerability (takeDamage no-op while true).
- **Set Health Absorption Rate** (`rate: float`) — Damage multiplier for real HP (resistance); 0 = invulnerable.
- **Add Health Pool** (`type: String, amount: float`) — Adds to a named health pool (shield/armour).
- **Set Health Pool** (`type: String, amount: float`) — Sets a health pool amount (fires Added only when it increases).
- **Clear Health Pool** (`type: String`) — Zeroes one named health pool.
- **Clear All Health Pools** — Zeroes every health pool.
- **Set Health Pool Decay Rate** (`type: String, rate: float`) — Sets a pool's per-second decay rate.
- **Set Health Pool Absorption Rate** (`type: String, rate: float`) — Sets a pool's absorption multiplier (how hard it spends to soak damage).
- **Set Health Pool Rates** (`type: String, decay_rate: float, absorption_rate: float`) — Sets a pool's decay and absorption rates at once.
- **Set Health Pool Priority** (`type: String, priority: float`) — Sets a pool's absorption priority (lower absorbs first).
- **Setup Health Pool** (`type: String, amount: float, decay_rate: float, absorption_rate: float, priority: float`) — Creates/configures a health pool in one call.
- **Revive** (`amount: float`) — Clears death and restores health (amount<=0 → full).

#### Expressions
- **Current Health**
- **Max Health**
- **Health Percent**
- **Health Absorption Rate**
- **Last Damage**
- **Last Heal**
- **Health Pool** (`type: String`)
- **Health Pool Decay Rate** (`type: String`)
- **Health Pool Absorption Rate** (`type: String`)
- **Health Pool Priority** (`type: String`)
- **Last Pool Damage Absorbed**
- **Last Health Pool Type**

### HTNAgent (`res://eventsheet_addons/htn_agent/htn_agent_behavior.gd`)
@ace_tags(ai, planning)

#### Triggers
- **On Task Started** (`task_name: String`)

#### Conditions
- **Has Plan**
- **Current Task Is** (`task_name: String`)

#### Actions
- **Set World State** (`key: String, value`) — Writes a fact the planner reads in method preconditions.
- **Clear World State** (`key: String`) — Removes a world-state key.
- **Add Primitive Task** (`task_name: String`) — Registers a leaf task your sheet executes directly.
- **Add Compound Task** (`task_name: String`) — Registers a task that decomposes via methods.
- **Add Method** (`task_name: String, method_id: String, utility: float`) — Adds (or re-scores) a way to accomplish a compound task; highest utility wins.
- **Add Method Condition** (`task_name: String, method_id: String, key: String, op: String, value`) — A precondition (world-state key, operator, value) the method needs to be chosen.
- **Add Method Subtask** (`task_name: String, method_id: String, subtask: String`) — Appends a subtask (primitive or compound) to a method, in order.
- **Set Method Utility** (`task_name: String, method_id: String, utility: float`) — Updates a method's utility at runtime (utility-driven re-prioritising).
- **Clear Task Network** — Wipes all tasks/methods (keeps world state).
- **Request Plan** — Decomposes the root task into a plan and starts the first task.
- **Mark Task Complete** — Advances to the next task, or fires On Plan Complete at the end.
- **Mark Task Failed** — Re-plans from the root (or fires On Plan Failed if auto-replan is off).
- **Invalidate Plan** — Drops the current plan so the next Request Plan rebuilds it.

#### Expressions
- **Current Task**
- **Plan Length**
- **World Value** (`key: String`)

### JuiceBehavior (`res://eventsheet_addons/juice/juice_behavior.gd`)
@ace_tags(camera, juice)

#### Triggers
- **On Shake Stopped**

#### Conditions
- **Is Shaking**

#### Actions
- **Shake** (`strength: float`) — Adds screenshake to the active camera (0 = none, 1 = max). Stacks and decays automatically — fire it on every hit.
- **Stop Shake** — Cancels any shake and restores the camera to rest immediately.
- **Use Camera** (`camera_path: NodePath`) — Pin the effects to a specific Camera2D (by path). Leave it unused to auto-target whichever camera is active.
- **Zoom By Percent** (`percent: float, duration: float`) — Smoothly zooms the camera (100 = no change, 150 = zoom in 1.5x, 50 = zoom out). Clamped to the min/max zoom knobs.
- **Zoom To Position** (`world_position: Vector2, percent: float, duration: float`) — Zooms in while gliding the camera so a world position becomes the screen CENTRE — frame a spot in one action.
- **Zoom Toward Point** (`world_position: Vector2, percent: float, duration: float`) — Zooms while keeping a world position pinned under the same screen spot (mouse-wheel-to-cursor style) — great for strategy/map zoom.
- **Squash & Stretch** (`stretch: float, duration: float`) — Pops the host (Node2D or Control) with a volume-preserving stretch that springs back elastically. Positive = stretch tall (a jump), negative = squash wide (a landing).
- **Spring Squash** (`stretch: float`) — Pops the host (Node2D or Control) with a volume-preserving stretch that springs back via a real spring (the stiffness/damping knobs) — bouncier + more organic than the tween Squash & Stretch. Positive = stretch tall (a jump), negative = squash wide (a landing).
- **Slowmo** (`target_scale: float, hold_duration: float, duration_clock: String`) — Briefly slows Engine.time_scale to the target, HOLDS for a duration, then eases back to normal. Fade curves are Inspector knobs; pick whether the hold counts in realtime or scaled game time. Emits On Slowmo Finished.
- **Clear Slowmo** — Cancels any slowmo and snaps Engine.time_scale back to 1.0 immediately (call on scene exit if a slowmo might still be running).

#### Expressions
- **Trauma**

### LOSBehavior (`res://eventsheet_addons/line_of_sight/line_of_sight_behavior.gd`)

#### Conditions
- **Has Line Of Sight To** (`point: Vector2`)
- **Has LOS Between** (`from_point: Vector2, to_point: Vector2`)

#### Expressions
- **Nearest Visible In Group** (`group: String`)

### LOS3DBehavior (`res://eventsheet_addons/line_of_sight_3d/line_of_sight_3d_behavior.gd`)

#### Conditions
- **Has Line Of Sight To** (`point: Vector3`)
- **Has LOS Between** (`from_point: Vector3, to_point: Vector3`)

#### Expressions
- **Nearest Visible In Group** (`group: String`)

### MoveToBehavior (`res://eventsheet_addons/move_to/move_to_behavior.gd`)

#### Triggers
- **On Arrived**

#### Actions
- **Move To Position** (`x: float, y: float`) — Replaces the queue and glides toward the point.
- **Add Waypoint** (`x: float, y: float`) — Appends a stop to the queue (waypoints).
- **Stop Moving** — Clears the queue without firing On Arrived.

### MoveTo3DBehavior (`res://eventsheet_addons/move_to_3d/move_to_3d_behavior.gd`)

#### Triggers
- **On Arrived (3D)**

#### Actions
- **Move To Position (3D)** (`x: float, y: float, z: float`) — Replaces the queue and glides toward the point.
- **Add Waypoint (3D)** (`x: float, y: float, z: float`) — Appends a stop to the queue.
- **Stop Moving (3D)** — Clears the queue without firing On Arrived.

### OrbitBehavior (`res://eventsheet_addons/orbit/orbit_behavior.gd`)

#### Actions
- **Set Orbit Center** (`x: float, y: float`) — Orbits around the given point from now on.
- **Set Orbit Speed** (`degrees_per_second: float`) — Degrees per second (negative reverses).
- **Set Orbit Radii** (`primary: float, secondary: float`) — Primary/secondary radii (secondary 0 = circle).

### Orbit3DBehavior (`res://eventsheet_addons/orbit_3d/orbit_3d_behavior.gd`)

#### Actions
- **Set Orbit 3D Center** (`x: float, y: float, z: float`) — Orbits around the given point from now on.

### PlatformerMovement (`res://eventsheet_addons/platformer_movement/platformer_movement_behavior.gd`)
@ace_tags(movement, platformer)

#### Triggers
- **On Jumped**

#### Conditions
- **Is Moving**
- **Is Jumping**
- **Is Falling**
- **Is Wall Sliding**
- **Can Jump**

#### Actions
- **Jump** — Jumps: from the floor or within coyote time, off a wall (if enabled), or a mid-air (double) jump if any remain. If none are available right now, the press is buffered.
- **Jump Released** — Call when the jump button is released — cuts the rise short for variable jump height (hold = higher).
- **Set Move Speed** (`speed: float`) — Changes the horizontal move speed.
- **Reset Jumps** — Refills the air-jump count (e.g. after grabbing a power-up).

#### Expressions
- **Jumps Remaining**
- **Air Time**
- **Facing Direction**

### SaveSystemAddon (`res://eventsheet_addons/save_system/save_system_addon.gd`)
@ace_tags(persistence)

#### Triggers
- **On Save Written** (`slot_index: int`)

#### Conditions
- **Has Save Key** (`key: String`) — Whether the key exists in the active slot.
- **Slot Exists** (`slot_index: int`) — Whether the slot has a save file.

#### Actions
- **Save Value** (`key: String, value`) — Writes ANY value (number, text, Vector2, Color, Dictionary…) under the key.
- **Save Number** (`key: String, value: float`) — Writes a number under the key (active slot).
- **Save Text** (`key: String, value: String`) — Writes a string under the key (active slot).
- **Delete Slot** — Removes the active slot's save file.
- **Save Game** — Broadcasts On Before Save (every sheet writes its state), then On Save Written.
- **Load Game** — Broadcasts On After Load — every sheet reads its state back.

#### Expressions
- **Load Value** (`key: String, default_value`) — Reads any value (your default when missing).
- **Load Number** (`key: String`) — Reads a number (0 when missing).
- **Load Text** (`key: String`) — Reads a string ("" when missing).
- **List Slots** — Slot numbers that have save files (for menus).
- **Slot Modified Time** (`slot_index: int`) — Unix mtime of the slot's file (0 when missing).

### SineBehavior (`res://eventsheet_addons/sine/sine_behavior.gd`)

#### Actions
- **Set Sine Active** (`is_active: bool`) — Pauses or resumes the oscillation.
- **Update Initial State** — Re-captures the host's current position/scale/angle/opacity as the wave's base (updateInitialState).
- **Set Phase** (`degrees: float`) — Phase offset in degrees.
- **Reset Sine** — Restarts the wave from the current state.

### Sine3DBehavior (`res://eventsheet_addons/sine_3d/sine_3d_behavior.gd`)

#### Actions
- **Set Sine 3D Active** (`is_active: bool`) — Pauses or resumes the oscillation.
- **Set Phase** (`degrees: float`) — Phase offset in degrees.
- **Reset Sine 3D** — Restarts the wave from the current state.

### SpringBehavior (`res://eventsheet_addons/spring/spring_behavior.gd`)
@ace_tags(motion, juice)

#### Triggers
- **On Spring Reached** (`spring_name: String`)

#### Conditions
- **Is Springing** (`spring_name: String`)

#### Actions
- **Spring To** (`spring_name: String, target: float`) — Springs the named value toward a target.
- **Spring Between** (`spring_name: String, from_value: float, to_value: float`) — Snaps to a start value, then springs to the end value.
- **Set Spring Value** (`spring_name: String, value: float`) — Snaps the named spring (no motion).
- **Add Impulse** (`spring_name: String, amount: float`) — Kicks the named spring's velocity (instant juice).
- **Stop Spring** (`spring_name: String`) — Freezes the named spring where it is.
- **Configure Spring** (`spring_name: String, stiffness: float, damping: float, precision: float`) — Per-spring stiffness/damping/precision overrides.
- **Spring Host X** (`target: float`) — Springs the host's X position.
- **Spring Host Y** (`target: float`) — Springs the host's Y position.
- **Spring Host Angle** (`degrees: float`) — Springs the host's rotation (degrees).
- **Spring Host Scale** (`target: float`) — Springs the host's uniform scale (squash & stretch!).
- **Set Color Value** (`spring_name: String, color: Color`) — Snaps a named colour spring (no motion) — seed it before springing.
- **Spring Color** (`spring_name: String, target_color: Color`) — Springs a named colour toward a target (read it back with Color Value — great for hit flashes).
- **Pause Spring** (`spring_name: String`) — Freezes a spring in place (resume continues it).
- **Resume Spring** (`spring_name: String`) — Resumes a paused spring toward its target.
- **Remove Spring** (`spring_name: String`) — Deletes a named spring (numeric and/or colour).
- **Reset All Springs** — Clears every spring on this behavior.

#### Expressions
- **Color Value** (`spring_name: String`)
- **Spring Value** (`spring_name: String`)
- **Spring Velocity** (`spring_name: String`)
- **Spring Progress** (`spring_name: String`)

### StateMachineBehavior (`res://eventsheet_addons/state_machine/state_machine_behavior.gd`)

#### Triggers
- **On State Changed** (`previous: String, next: String`)

#### Conditions
- **Is In State** (`state_name: String`) — True while the machine is in the given state.

#### Actions
- **Set State** (`next: String`) — Switches to the given state and fires On State Changed.

### TileMovementBehavior (`res://eventsheet_addons/tile_movement/tile_movement_behavior.gd`)

#### Triggers
- **On Step Finished**

#### Actions
- **Simulate Step** (`direction: String`) — Steps one tile in a direction: left, right, up or down (simulate control).
- **Teleport To Tile** (`tile_x: float, tile_y: float`) — Snaps to a tile coordinate instantly.

### TimeSlicerBehavior (`res://eventsheet_addons/time_slicer/time_slicer_behavior.gd`)
@ace_tags(performance, scheduling)

#### Triggers
- **On Process Item** (`item: Variant`)

#### Conditions
- **Is Busy**

#### Actions
- **Enqueue Item** (`item`) — Adds one item to the work queue (processed later within the per-frame budget).
- **Enqueue Items** (`items: Array`) — Adds every element of an array to the work queue.
- **Enqueue Group** (`group: String`) — Adds every node in a group to the work queue (e.g. process all enemies, spread over frames).
- **Clear Queue** — Drops all pending items without processing them.
- **Set Frame Budget** (`ms: float`) — Sets the per-frame millisecond budget at runtime (dial it down during heavy scenes).
- **Pause** — Stops draining (items stay queued).
- **Resume** — Resumes draining the queue.

#### Expressions
- **Items Remaining**
- **Last Frame Item Count**

### TimerBehavior (`res://eventsheet_addons/timer/timer_behavior.gd`)

#### Triggers
- **On Timer**

#### Actions
- **Start Timer** (`seconds: float`) — Starts (or restarts) the countdown with the given duration.
- **Stop Timer** — Stops the countdown without firing On Timer.

### TweenBehavior (`res://eventsheet_addons/tween/tween_behavior.gd`)
@ace_tags(motion, juice)

#### Triggers
- **On Tween Finished**

#### Conditions
- **Is Tweening**

#### Actions
- **Tween Property** (`property_path: String, final_value: float, duration: float`) — Tweens any host property (e.g. position:x) to a value.
- **Tween Position** (`x: float, y: float, duration: float`) — Moves the host to (x, y).
- **Tween Scale** (`amount: float, duration: float`) — Scales the host uniformly.
- **Tween Rotation** (`degrees: float, duration: float`) — Rotates the host to the given degrees.
- **Tween Alpha** (`alpha: float, duration: float`) — Fades the host's modulate alpha.
- **Stop Tweens** — Kills the running tween (host stays where it is).

### VirtualCursor (`res://eventsheet_addons/virtual_cursor/virtual_cursor_behavior.gd`)

#### Triggers
- **On Interact Pressed** (`id: String`)

#### Conditions
- **Is Interact Held** (`id: String`)
- **Is Moving**
- **Is In Homing Range**
- **Is Blocked**
- **Is Enabled**
- **Is Ignoring Input**
- **Is Hovering** (`target: Node2D`)

#### Actions
- **Press Interact** (`id: String`) — Marks a named interact button held and fires On Interact Pressed.
- **Release Interact** (`id: String`) — Marks a named interact button released and fires On Interact Released.
- **Simulate Interact** (`id: String`) — Fires a press+release of a named button in one tick.
- **Set Max Speed** (`speed: float`) — Sets the max cursor speed (px/s).
- **Set Acceleration** (`rate: float`) — Sets the speed-up rate while an axis is held.
- **Set Deceleration** (`rate: float`) — Sets the slow-down rate when the axis is released.
- **Set Velocity** (`vel_x: float, vel_y: float`) — Sets the cursor velocity directly.
- **Simulate Direct Mouse Position** (`target_x: float, target_y: float`) — Teleports the cursor to a position, reporting the implied velocity.
- **Simulate Mouse** (`target_x: float, target_y: float, smoothing: float`) — Drives the cursor toward a target with smoothing (mouse-follow).
- **Simulate Axis** (`x: float, y: float`) — Feeds an analog axis for this tick (accel/decel applies).
- **Simulate Control** (`direction: int`) — Feeds a cardinal direction (0 up, 1 down, 2 left, 3 right) for this tick.
- **Set Homing Enabled** (`is_enabled: bool`) — Turns the homing magnet on/off.
- **Set Homing Mode** (`mode: int`) — 0 steer, 1 snap-radius, 2 snap-overlap.
- **Set Homing Radius** (`radius: float`) — Sets the homing engagement radius.
- **Set Homing Strength** (`strength: float`) — How strongly the cursor is pulled toward a homing target (0..1).
- **Add Homing Target** (`target: Node2D`) — Registers a node as a homing target.
- **Remove Homing Target** (`target: Node2D`) — Unregisters a homing target.
- **Clear Homing Targets** — Removes every homing target.
- **Add Solid** (`target: Node2D`) — Registers a node as a tracked solid (for SolidUID reporting).
- **Remove Solid** (`target: Node2D`) — Unregisters a tracked solid.
- **Clear Solids** — Clears the tracked-solids list.
- **Set Solid Collision** (`is_enabled: bool`) — Toggles solid push-out via move_and_slide.
- **Set Allow Sliding** (`state: bool`) — Slide along solids (true) or hard-stop (false).
- **Set Bounce** (`mode: int`) — 0 none, 1 solids, 2 constraints, 3 both.
- **Set Direction Mode** (`mode: int`) — 0 up/down, 1 left/right, 2 four-way, 3 eight-way.
- **Set Default Controls** (`state: bool`) — Read ui_left/right/up/down each tick.
- **Set Enabled** (`is_enabled: bool`) — Master on/off.
- **Set Ignoring Input** (`state: bool`) — Ignore all input while true (movement decays to zero).
- **Set Constrain To Layout** (`is_enabled: bool`) — Clamp the cursor inside the bounds.
- **Set Constraint Bounds** (`left: float, top: float, right: float, bottom: float`) — Sets explicit clamp bounds (all-zero clears them, falling back to the viewport).
- **Set Hover Mode** (`mode: int`) — 0 point (origin inside shape), 1 overlap (shapes overlap).

#### Expressions
- **Cursor X**
- **Cursor Y**
- **Speed**
- **Velocity X**
- **Velocity Y**
- **Moving Angle**
- **Axis X**
- **Axis Y**
- **Max Speed**
- **Hovered UID**
- **Homing Target UID**
- **Homing Target Dist**
- **Count Homing Targets**
- **Bounce Mode**

### WeaponKit (`res://eventsheet_addons/weapon_kit/weapon_kit_behavior.gd`)
@ace_tags(combat, shooter)

#### Triggers
- **On Fire**

#### Conditions
- **Can Fire**
- **Has Ammo**
- **Is Full**
- **Is Reloading**

#### Actions
- **Fire** — Fires if ready (not reloading, off cooldown, has ammo). In burst mode it kicks off a burst; if the magazine is empty it triggers On Empty (and auto-reloads when enabled).
- **Reload** — Starts a timed reload (if not full and reserve has rounds).
- **Cancel Reload** — Aborts an in-progress reload (no ammo gained).
- **Instant Reload** — Refills the magazine immediately (no reload time).
- **Add Ammo** (`amount: int`) — Adds rounds straight to the magazine (capped at the magazine size).
- **Add Reserve Ammo** (`amount: int`) — Adds spare rounds to the reserve pool (e.g. an ammo pickup).
- **Set Fire Rate** (`rate: float`) — Changes the shots-per-second.
- **Set Fire Mode** (`mode: int`) — 0 = single, 1 = auto, 2 = burst.
- **Set Magazine Size** (`size: int`) — Changes the magazine size.

#### Expressions
- **Ammo Percent**
- **Reload Progress**
- **Cooldown Progress**
