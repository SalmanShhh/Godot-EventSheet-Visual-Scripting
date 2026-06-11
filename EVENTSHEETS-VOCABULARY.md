# Project vocabulary — Godot EventSheets

> Generated — do not edit. Regenerate via the dock (Tools → Vocabulary Doc…) or
> `godot --headless --path . --script tools/vocabulary_doc.gd`.

## Sheets

### player (`res://demo/sheets/player.tres`)
Node script extending `CharacterBody2D`.

#### Properties
- `health: int` (default `100`)
- `speed: float` (default `200.0`)

### ShowcaseV060 (`res://demo/showcase/showcase_v060.tres`)
Node script extending `Node2D`.

#### Properties
- `pulse_scale: float` (default `1.35`) — How hard the spring kicks.
- `pulses: int` (default `0`) — How many juice pulses have fired (watch it in Live Values — and edit it!).

### BulletBehavior (`res://eventsheet_addons/bullet/bullet_behavior.tres`)
Behavior — attach under any `Node2D` node.

#### Properties
- `acceleration: float` (default `0.0`)
- `align_rotation: bool` (default `true`)
- `enabled_movement: bool` (default `true`)
- `gravity: float` (default `0.0`)
- `speed: float` (default `300.0`)

#### Actions
- **Set Bullet Speed** (`value: float`) — Changes speed, keeping the current direction.
- **Set Angle Of Motion** (`degrees: float`) — Redirects the bullet (degrees).
- **Set Bullet Enabled** (`is_enabled: bool`) — Pauses or resumes the movement.

### Bullet3DBehavior (`res://eventsheet_addons/bullet_3d/bullet_3d_behavior.tres`)
Behavior — attach under any `Node3D` node.

#### Properties
- `gravity: float` (default `0.0`)
- `speed: float` (default `10.0`)

#### Actions
- **Launch Forward** — (Re)launches along the host's current forward direction.
- **Set Bullet 3D Speed** (`value: float`) — Changes speed, keeping the current direction.

### CarBehavior (`res://eventsheet_addons/car/car_behavior.tres`)
Behavior — attach under any `CharacterBody2D` node.

#### Properties
- `acceleration: float` (default `300.0`)
- `deceleration: float` (default `400.0`)
- `drift_recover: float` (default `0.15`)
- `max_speed: float` (default `400.0`)
- `steer_degrees: float` (default `180.0`)
- `turn_while_stopped: bool` (default `false`)

#### Actions
- **Stop Car** — Kills all momentum.

### DragDropBehavior (`res://eventsheet_addons/drag_drop/drag_drop_behavior.tres`)
Behavior — attach under any `Node2D` node.

#### Properties
- `axes: String` (default `both`)
- `grab_radius: float` (default `48.0`)

#### Triggers
- **On Drag Start**
- **On Dropped**

#### Actions
- **Drop Now** — Releases the drag immediately.

### EightDirectionMovement (`res://eventsheet_addons/eight_direction/eight_direction_movement_behavior.tres`)
Behavior — attach under any `CharacterBody2D` node.

#### Properties
- `move_speed: float` (default `200.0`)

#### Actions
- **Set Move Speed** (`speed: float`) — Changes the movement speed.

### FlashBehavior (`res://eventsheet_addons/flash/flash_behavior.tres`)
Behavior — attach under any `CanvasItem` node.

#### Properties
- `interval: float` (default `0.1`)

#### Triggers
- **On Flash Finished**

#### Actions
- **Flash** (`seconds: float`) — Blinks the host for the given number of seconds.
- **Stop Flash** — Stops flashing and restores visibility.

### FollowBehavior (`res://eventsheet_addons/follow/follow_behavior.tres`)
Behavior — attach under any `Node2D` node.

#### Properties
- `delay: float` (default `0.4`)
- `follow_speed: float` (default `5.0`)
- `following: bool` (default `true`)
- `min_distance: float` (default `0.0`)
- `mode: String` (default `smooth`)
- `target_path: String` (default ``)

#### Actions
- **Start Following** (`path: String`) — Follows the node at the given path.
- **Stop Following** — Stops trailing the target.

### LOSBehavior (`res://eventsheet_addons/line_of_sight/line_of_sight_behavior.tres`)
Behavior — attach under any `Node2D` node.

#### Properties
- `collision_mask: int` (default `1`)
- `cone_of_view_degrees: float` (default `360.0`)
- `sight_range: float` (default `400.0`)

#### Conditions
- **Has Line Of Sight To**
- **Has LOS Between**

### MoveToBehavior (`res://eventsheet_addons/move_to/move_to_behavior.tres`)
Behavior — attach under any `Node2D` node.

#### Properties
- `max_speed: float` (default `200.0`)
- `rotate_toward_motion: bool` (default `false`)

#### Triggers
- **On Arrived**

#### Actions
- **Move To Position** (`x: float, y: float`) — Replaces the queue and glides toward the point.
- **Add Waypoint** (`x: float, y: float`) — Appends a stop to the queue (C3 waypoints).
- **Stop Moving** — Clears the queue without firing On Arrived.

### MoveTo3DBehavior (`res://eventsheet_addons/move_to_3d/move_to_3d_behavior.tres`)
Behavior — attach under any `Node3D` node.

#### Properties
- `max_speed: float` (default `5.0`)

#### Triggers
- **On Arrived (3D)**

#### Actions
- **Move To Position (3D)** (`x: float, y: float, z: float`) — Replaces the queue and glides toward the point.
- **Add Waypoint (3D)** (`x: float, y: float, z: float`) — Appends a stop to the queue.
- **Stop Moving (3D)** — Clears the queue without firing On Arrived.

### OrbitBehavior (`res://eventsheet_addons/orbit/orbit_behavior.tres`)
Behavior — attach under any `Node2D` node.

#### Properties
- `match_rotation: bool` (default `false`)
- `offset_angle_degrees: float` (default `0.0`)
- `primary_radius: float` (default `100.0`)
- `secondary_radius: float` (default `0.0`)
- `speed_degrees: float` (default `90.0`)

#### Actions
- **Set Orbit Center** (`x: float, y: float`) — Orbits around the given point from now on.
- **Set Orbit Speed** (`degrees_per_second: float`) — Degrees per second (negative reverses).
- **Set Orbit Radii** (`primary: float, secondary: float`) — Primary/secondary radii (secondary 0 = circle).

### Orbit3DBehavior (`res://eventsheet_addons/orbit_3d/orbit_3d_behavior.tres`)
Behavior — attach under any `Node3D` node.

#### Properties
- `radius: float` (default `3.0`)
- `speed_degrees: float` (default `90.0`)

#### Actions
- **Set Orbit 3D Center** (`x: float, y: float, z: float`) — Orbits around the given point from now on.

### PlatformerMovement (`res://eventsheet_addons/platformer_movement/platformer_movement_behavior.tres`)
Behavior — attach under any `CharacterBody2D` node.

#### Properties
- `gravity: float` (default `980.0`)
- `jump_velocity: float` (default `-400.0`)
- `move_speed: float` (default `200.0`)

#### Triggers
- **On Jumped**

#### Actions
- **Jump** — Makes the host jump when it is on the floor.
- **Set Move Speed** (`speed: float`) — Changes the horizontal move speed.

### SaveSystemAddon (`res://eventsheet_addons/save_system/save_system_addon.tres`)
Autoload singleton `SaveSystem` — its ACEs are project-wide.

#### Properties
- `autosave_interval: float` (default `0.0`) — Seconds between autosaves (0 = off). Fires On Before Save first.
- `encryption_key: String` (default ``) — Non-empty = encrypted saves (keep the key out of screenshots!).
- `file_pattern: String` (default `save_{slot}.cfg`) — {slot} becomes the slot number.
- `format: String` (default `config`)
- `save_directory: String` (default `user://`) — Where save files live.
- `section: String` (default `save`) — ConfigFile section / JSON namespace for values.
- `slot: int` (default `0`) — Active save slot (each slot is its own file).

#### Triggers
- **On Save Written**
- **On Before Save**
- **On After Load**

#### Actions
- **Save Value** (`key: String, value: Variant`) — Writes ANY value (number, text, Vector2, Color, Dictionary…) under the key.
- **Save Number** (`key: String, value: float`) — Writes a number under the key (active slot).
- **Save Text** (`key: String, value: String`) — Writes a string under the key (active slot).
- **Delete Slot** — Removes the active slot's save file.
- **Save Game** — Broadcasts On Before Save (every sheet writes its state), then On Save Written.
- **Load Game** — Broadcasts On After Load — every sheet reads its state back.

#### Expressions
- **Load Value** (`key: String, default_value: Variant`) — Reads any value (your default when missing).
- **Load Number** (`key: String`) — Reads a number (0 when missing).
- **Load Text** (`key: String`) — Reads a string ("" when missing).
- **Has Save Key** (`key: String`) — Whether the key exists in the active slot.
- **Slot Exists** (`slot_index: int`) — Whether the slot has a save file.
- **List Slots** — Slot numbers that have save files (for menus).
- **Slot Modified Time** (`slot_index: int`) — Unix mtime of the slot's file (0 when missing).

### SineBehavior (`res://eventsheet_addons/sine/sine_behavior.tres`)
Behavior — attach under any `Node2D` node.

#### Properties
- `active: bool` (default `true`)
- `magnitude: float` (default `50.0`)
- `movement: String` (default `horizontal`)
- `period: float` (default `4.0`)
- `phase_degrees: float` (default `0.0`)
- `wave: String` (default `sine`)

#### Actions
- **Set Sine Active** (`is_active: bool`) — Pauses or resumes the oscillation.
- **Update Initial State** — Re-captures the host's current position/scale/angle/opacity as the wave's base (C3 updateInitialState).
- **Set Phase** (`degrees: float`) — Phase offset in degrees.
- **Reset Sine** — Restarts the wave from the current state.

### Sine3DBehavior (`res://eventsheet_addons/sine_3d/sine_3d_behavior.tres`)
Behavior — attach under any `Node3D` node.

#### Properties
- `active: bool` (default `true`)
- `magnitude: float` (default `2.0`)
- `movement: String` (default `y`)
- `period: float` (default `4.0`)
- `wave: String` (default `sine`)

#### Actions
- **Set Sine 3D Active** (`is_active: bool`) — Pauses or resumes the oscillation.
- **Reset Sine 3D** — Restarts the wave from the current state.

### SpringBehavior (`res://eventsheet_addons/spring/spring_behavior.tres`)
Behavior — attach under any `Node2D` node.

#### Properties
- `default_damping: float` (default `0.85`) — 0 = oscillate forever, 1 = no overshoot.
- `default_precision: float` (default `0.01`) — Distance + speed below which a spring counts as settled.
- `default_stiffness: float` (default `170.0`) — Spring force toward the target (higher = snappier).

#### Triggers
- **On Spring Reached**

#### Conditions
- **Is Springing**

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

#### Expressions
- **Spring Value**
- **Spring Velocity**
- **Spring Progress**

### StateMachineBehavior (`res://eventsheet_addons/state_machine/state_machine_behavior.tres`)
Behavior — attach under any `Node` node.

#### Properties
- `state: String` (default `idle`)

#### Triggers
- **On State Changed**

#### Conditions
- **Is In State**

#### Actions
- **Set State** (`next: String`) — Switches to the given state and fires On State Changed.

### TileMovementBehavior (`res://eventsheet_addons/tile_movement/tile_movement_behavior.tres`)
Behavior — attach under any `Node2D` node.

#### Properties
- `default_controls: bool` (default `true`)
- `move_time: float` (default `0.15`)
- `tile_size: float` (default `64.0`)

#### Triggers
- **On Step Finished**

#### Actions
- **Simulate Step** (`direction: String`) — Steps one tile in a direction: left, right, up or down (C3 simulate control).
- **Teleport To Tile** (`tile_x: float, tile_y: float`) — Snaps to a tile coordinate instantly.

### TimerBehavior (`res://eventsheet_addons/timer/timer_behavior.tres`)
Behavior — attach under any `Node` node.

#### Properties
- `duration: float` (default `1.0`)
- `repeating: bool` (default `false`)

#### Triggers
- **On Timer**

#### Actions
- **Start Timer** (`seconds: float`) — Starts (or restarts) the countdown with the given duration.
- **Stop Timer** — Stops the countdown without firing On Timer.

### TweenBehavior (`res://eventsheet_addons/tween/tween_behavior.tres`)
Behavior — attach under any `Node2D` node.

#### Properties
- `default_duration: float` (default `0.3`) — Seconds used when a tween call passes 0.
- `easing: String` (default `out`)
- `transition: String` (default `sine`)

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

## Script packs

### DemoHealthAddon (`res://eventsheet_addons/demo_health_addon.gd`)
Demo EventSheet ACE addon. Drop scripts like this into res://eventsheet_addons/ and their annotated members become project-wide ACEs automatically — no manifest, no JSON, no per-sheet setup. Provider name comes from class_name, this comment is the addon description, and @ace_* annotations customize each ACE.

#### Triggers
- **On Healed** (`amount: int`) — Fires after health is restored.

#### Conditions
- **Is Hurt** (`threshold: int`) — True while health is below the given threshold.

#### Actions
- **Heal** (`amount: int`) — Restores health by an amount.
- **Announce Heal** (`amount: int`) — Prints a heal announcement. No @ace_codegen_template on purpose: the generated script owns a DemoHealthAddon instance and calls this directly (instance-backed ACE — the zero-config default for template-less addon methods).
