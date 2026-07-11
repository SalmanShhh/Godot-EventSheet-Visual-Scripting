# Juice - Screenshake, Recoil, Head Bob, Zoom, Squash, Slowmo and Hitstop in One Behavior

Juice is a Godot EventSheets behavior pack that adds game feel to a scene without a line of tween code. You attach a `JuiceBehavior` to a node - a sprite, the player, a UI panel, anything drawn on screen - and that node gains a toolbox of camera and squash effects you fire straight from event rows. The host must be a `CanvasItem` (that means a `Node2D` like a sprite, or a `Control` like a UI panel). Camera effects (Shake, Zoom) find the active `Camera2D` on their own, so Shake and Zoom "just work" from wherever you place the behavior with no path to wire. Squash effects animate the node the behavior is attached to. Slowmo and Hitstop drive `Engine.time_scale` globally. Every effect is fire-and-forget and, where it has a lifetime, ends by emitting an "On X Finished" trigger so you can chain the next beat.

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

- **Impact feedback on every hit.** Fire Shake with a small strength each time a bullet lands or an enemy takes damage; the trauma stacks and decays on its own so a burst of hits reads as a rising, settling rumble.
- **Platformer jump and land.** Spring Squash the character tall as it leaves the ground and squash it wide the frame it touches down, so a plain jump gains weight.
- **Finisher slow motion.** Slowmo the whole game to a crawl for a beat on a killing blow or a perfect dodge, then let it ease back to normal on its own.
- **Punchy melee hits.** Hitstop the game for a few frames the instant a sword connects, the brief freeze that makes a blow feel like it landed.
- **Cinematic zoom-ins.** Zoom By Percent to punch the camera in on a special move or a dramatic line, then zoom back out when it finishes.
- **Framing a spot.** Zoom To Position glides the camera so a boss door, a treasure, or a cutscene actor becomes the screen centre in one action.
- **Strategy and map zoom.** Zoom Toward Point keeps the world point under the cursor pinned as you zoom, the mouse-wheel-to-cursor feel players expect from a map view.
- **UI that feels alive.** Attach the behavior to a `Control` and Spring Squash a button when it is pressed or a panel when it pops open.
- **Explosions and screen kicks.** Scale Shake strength by distance to the blast so a nearby explosion rocks the camera and a far one barely nudges it.
- **Chained beats.** React to On Hitstop Finished or On Slowmo Finished to sequence a hit-pause into a slow-motion follow-through without a timer.
- **Split-screen and custom rigs.** Use Camera pins the effects to one specific `Camera2D` when the auto-found camera is not the one you want.
- **HUD rumble readouts.** Read the Trauma expression to drive a controller-rumble strength or a shaking HUD element that matches the camera.

---

## Core concepts

The pack is small. Learn these ideas and every ACE falls into place.

**The node is where you attach, the camera is found for you.** You drop a `JuiceBehavior` on a node and place all its ACEs on that node. Shake and the three Zoom actions do not care which node holds the behavior: they act on the active `Camera2D` (`get_viewport().get_camera_2d()`), found automatically. So you can put Juice on your player and still shake the camera. The squash actions are the exception: they scale the host node itself, so put the behavior on the thing you want to pop.

**Screenshake is trauma-based and additive.** Shake does not set a shake amount, it adds `strength` (0 to 1) to a hidden trauma value that then decays every second. The camera offset and roll are driven from trauma squared, so the shake ramps in perceptually and eases out as trauma bleeds off. Because it is additive on top of the camera's own offset and rotation, it composes with a follow camera instead of fighting it. Fire a little Shake on each hit and it stacks and settles by itself. When trauma reaches zero, On Shake Stopped fires.

**The Inspector knobs are the feel.** You tune how the effects look in the Inspector, not in the event rows. `max_offset`, `max_roll_degrees`, `shake_decay` and `shake_frequency` shape the shake; `min_zoom` and `max_zoom` clamp every zoom; the `slowmo_fade_*` knobs and the `squash_stiffness` / `squash_damping` knobs shape slowmo ramps and the spring bounce. The action rows carry only the "what and how much" - the "how it feels" lives on the node.

**Zoom comes in three flavors.** All three read a `percent` where 100 means no change, 150 means zoom in to 1.5x, and 50 means zoom out to half, and all three clamp the result to `min_zoom` / `max_zoom`. Zoom By Percent just changes the zoom. Zoom To Position also glides the camera so a world point ends up centred. Zoom Toward Point keeps a world point pinned under the same screen spot as it zooms (the cursor-anchored feel). Each ends with On Zoom Finished.

**Squash and stretch is volume-preserving, in two flavors.** Both take a `stretch`: positive stretches the host tall (a jump), negative squashes it wide (a landing), and the other axis compensates so the shape keeps its volume. Squash & Stretch uses a tween that springs back elastically over a `duration` you pass. Spring Squash uses a real spring driven by the `squash_stiffness` and `squash_damping` knobs, so it is bouncier and more organic and takes no duration - it settles on its own. Both end with On Squash Finished. On a `Control`, the pivot is centred for you so the pop reads from the middle.

**Slowmo ramps in, holds, then ramps out.** Slowmo eases `Engine.time_scale` down to your `target_scale`, holds it for `hold_duration`, then eases it back to 1.0. The ramp lengths and curves are Inspector knobs (`slowmo_fade_in_secs`, the trans/ease enums, and so on), separate from the hold. The `duration_clock` you pass picks whether the hold is measured in `realtime` (unaffected by the slowdown) or `gametime` (scaled). It emits On Slowmo Finished when it returns to normal. Clear Slowmo cancels it and snaps back to 1.0.

**Hitstop is a hard, brief freeze.** Hitstop slams `Engine.time_scale` to `freeze_scale` (0 is a full stop) for `freeze_duration`, then restores whatever the time scale was before. It runs on a realtime timer, so it un-freezes even at a full stop; it ignores a repeat call while already frozen; and it pauses any running Slowmo for the freeze so the two do not fight. It emits On Hitstop Finished. This is the tiny pause you feel on a connecting blow.

**Effects are fire-and-forget and announce when they end.** You never hold or await an effect. You fire it and, if you want to sequence the next beat, react to its finished trigger: On Shake Stopped, On Zoom Finished, On Squash Finished, On Slowmo Finished, On Hitstop Finished. That is how you chain a hitstop into a slowmo, or a zoom-in into a zoom-out.

---

## Setup

**1. Attach the behavior.** Add a `JuiceBehavior` as a child of the node you want to affect. Put it on the player (or any node) for camera Shake and Zoom; put it on the exact sprite or `Control` you want to pop for Squash. The host must be a `CanvasItem`, which every `Node2D` and every `Control` is. Camera effects need an active `Camera2D` somewhere in the scene.

**2. Tune the feel in the Inspector.** Select the behavior node and set the knobs (all have sensible defaults):

| Property | Default | What it does |
|---|---|---|
| `max_offset` | `(24, 16)` | Peak camera shake offset in pixels at full trauma. |
| `max_roll_degrees` | `3.0` | Peak camera roll (rotation) in degrees at full trauma. |
| `shake_decay` | `1.4` | Trauma lost per second - higher means shorter, snappier shakes. |
| `shake_frequency` | `25.0` | How fast the shake jitter scrolls. |
| `min_zoom` | `0.2` | Clamp: the most zoomed-out any zoom may go. |
| `max_zoom` | `5.0` | Clamp: the most zoomed-in any zoom may go. |
| `squash_stiffness` | `250.0` | Spring Squash stiffness - higher snaps back faster. |
| `squash_damping` | `0.6` | Spring Squash damping - lower is bouncier. |

**3. Fire an effect.** Here is a complete first setup - a shake on every hit, with a squash on the player when it lands:

```
On Player Damaged
  -> Player | JuiceBehavior: Shake  0.4

On Player Landed
  -> Player | JuiceBehavior: Spring Squash  -0.4
```

Shake adds trauma to the auto-found camera and it decays by itself; Spring Squash pops the player node wide and springs it back. No timers, no tweens, no cleanup.

---

## ACE reference

All ACEs live in the **Juice** category and target the `JuiceBehavior` on the node they are placed on. The camera actions act on the active camera; the squash actions act on the host node. The numbers shown in parameter descriptions are the values the picker opens with; you can change any of them per row.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Shake | `strength` (float) | Adds screenshake to the active camera (0 = none, 1 = max). Stacks and decays automatically - fire it on every hit. Opens at 0.4. |
| Stop Shake | (none) | Cancels any shake immediately (the camera returns to rest unless another effect - recoil, bob, jitter, tilt - is still holding it). |
| Use Camera | `camera_path` (NodePath) | Pins the effects to a specific `Camera2D` by path. Leave it unset to auto-target whichever camera is active. |
| Recoil | `angle_degrees` (float), `strength` (float) | Kicks the camera `strength` pixels in a direction (-90 = up, 0 = right) and springs it back at the Recoil Recovery rate. Fire on every shot - kicks stack, so rapid fire climbs. Opens at -90, 12. |
| Start Head Bob | `amplitude` (float), `frequency` (float) | Starts a walking head-bob: a figure-8 sway (side at half rate, one vertical dip per step). Pixels and steps-per-second. Call while moving; Stop Head Bob when halting. Opens at 6, 2.2. |
| Stop Head Bob | (none) | Stops the head bob. |
| Start Jitter | `amount` (float) | A continuous nervous wobble (pixels) that runs until Stop Jitter - unlike Shake it never decays. Idling engines, drunk vision, building earthquakes, low-health unease. Opens at 3. |
| Stop Jitter | (none) | Stops the jitter wobble. |
| Tilt To | `degrees` (float), `duration` (float) | Eases the camera roll to an angle and HOLDS it - lean into a drift, a hill, a dutch angle. Tilt back to 0 to level out. Opens at 6, 0.3. |
| Zoom By Percent | `percent` (float), `duration` (float) | Smoothly zooms the camera (100 = no change, 150 = zoom in 1.5x, 50 = zoom out). Clamped to the min/max zoom knobs. Opens at 150, 0.4. |
| Zoom To Position | `world_position` (Vector2), `percent` (float), `duration` (float) | Zooms in while gliding the camera so a world position becomes the screen centre - frame a spot in one action. Opens at 150, 0.4. |
| Zoom Toward Point | `world_position` (Vector2), `percent` (float), `duration` (float) | Zooms while keeping a world position pinned under the same screen spot (mouse-wheel-to-cursor style) - great for strategy/map zoom. Opens at 150, 0.4. |
| Squash & Stretch | `stretch` (float), `duration` (float) | Pops the host (Node2D or Control) with a volume-preserving stretch that springs back elastically over `duration`. Positive = stretch tall (a jump), negative = squash wide (a landing). Opens at 0.3, 0.4. |
| Spring Squash | `stretch` (float) | Pops the host with a volume-preserving stretch that springs back via a real spring (the stiffness/damping knobs) - bouncier and more organic than Squash & Stretch, and it needs no duration. Opens at 0.3. |
| Slowmo | `target_scale` (float), `hold_duration` (float), `duration_clock` (String) | Eases `Engine.time_scale` down to `target_scale`, holds for `hold_duration`, then eases back to normal. `duration_clock` picks `realtime` or `gametime` for the hold. Fade curves are Inspector knobs. Opens at 0.15, 0.25, realtime. |
| Clear Slowmo | (none) | Cancels any slowmo and snaps `Engine.time_scale` back to 1.0 immediately (call on scene exit if a slowmo might still be running). |
| Hitstop | `freeze_duration` (float), `freeze_scale` (float) | The punchy hit-pause on a connecting blow: freezes `Engine.time_scale` (0 = full stop) for `freeze_duration`, then snaps back to what it was. Ignores repeat hits already mid-freeze and pauses any active Slowmo. Opens at 0.06, 0.0. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Is Shaking | (none) | Whether the camera is currently shaking (trauma is above zero). |
| Is Hitstopped | (none) | Whether a hitstop freeze is active right now. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Trauma | (none) | float | The current trauma level, 0 to 1 - drive a rumble strength or a shaking HUD element from it. |

### Triggers

| Trigger | Fires when |
|---|---|
| On Shake Stopped | Trauma reaches zero and the camera settles back to rest after a shake. |
| On Tilt Finished | A Tilt To ease reaches its target angle. |
| On Zoom Finished | Any of the three zoom actions finishes its glide. |
| On Squash Finished | A Squash & Stretch tween or a Spring Squash spring settles back to rest. |
| On Slowmo Finished | Slowmo has ramped back to normal time scale. |
| On Hitstop Finished | A hitstop freeze ends and the previous time scale is restored. |

### Inspector properties

| Property | Type | Default | Range |
|---|---|---|---|
| `max_offset` | Vector2 | `(24, 16)` | any |
| `max_roll_degrees` | float | `3.0` | 0.0 - 30.0 |
| `shake_decay` | float | `1.4` | 0.1 - 10.0 |
| `shake_frequency` | float | `25.0` | 1.0 - 60.0 |
| `min_zoom` | float | `0.2` | 0.05 - 1.0 |
| `max_zoom` | float | `5.0` | 1.0 - 16.0 |
| `slowmo_fade_in_trans` | String | `sine` | linear, sine, quad, cubic, expo, circ, back |
| `slowmo_fade_in_ease` | String | `out` | in, out, in_out, out_in |
| `slowmo_fade_out_trans` | String | `sine` | linear, sine, quad, cubic, expo, circ, back |
| `slowmo_fade_out_ease` | String | `in` | in, out, in_out, out_in |
| `slowmo_fade_in_secs` | float | `0.15` | 0.0 - 2.0 |
| `slowmo_fade_out_secs` | float | `0.35` | 0.0 - 2.0 |
| `squash_stiffness` | float | `250.0` | 1.0 - 1000.0 |
| `squash_damping` | float | `0.6` | 0.0 - 1.0 |
| `recoil_recovery` | float | `140.0` | 10.0 - 2000.0 |

All camera effects (shake, recoil, bob, jitter, tilt) sum around ONE captured rest pose, so they
compose freely - a recoil during a shake during a head bob just works, and the camera is handed
back exactly where it started once everything settles. For a `Camera3D`, use the **Juice 3D**
pack - the same verbs, plus FOV punch/zoom and lean.

---

## Use cases

Each example places the ACEs on a node that carries a `JuiceBehavior`. Camera effects reach the active camera; squash effects animate the node named.

### 1. Screenshake on every hit

The classic. A small Shake per hit stacks into a rising rumble and decays on its own, so you never manage a timer.

```
On Enemy Took Damage
  -> Enemy | JuiceBehavior: Shake  0.3
```

Because trauma clamps at 1, a flurry of hits builds to a hard shake and then settles as `shake_decay` bleeds it off.

### 2. Jump and land squash on a platformer

Stretch the character tall as it leaves the floor, squash it wide the moment it lands. Spring Squash needs no duration, so both are one row.

```
On Player Jumped
  -> Player | JuiceBehavior: Spring Squash  0.35

On Player Landed
  -> Player | JuiceBehavior: Spring Squash  -0.45
```

Positive stretches tall, negative squashes wide; the spring back is shaped by `squash_stiffness` and `squash_damping` in the Inspector.

### 3. Finisher slow motion

Drop the whole game to a crawl for a beat on a killing blow, then let it ease back on its own.

```
On Enemy Killed
  Condition: Enemy  Is Last Enemy
    -> Player | JuiceBehavior: Slowmo  0.15, 0.4, realtime
```

The hold is measured in `realtime` so a 0.4-second hold really lasts 0.4 seconds of your life, not 0.4 of scaled game time.

### 4. Hitstop on a connecting blow

The tiny freeze that sells a hit. Fire it the instant a strike lands.

```
On Sword Hit Enemy
  -> Player | JuiceBehavior: Hitstop  0.06, 0.0
```

A full stop (`freeze_scale` 0) for 60 milliseconds. A second Hitstop during the freeze is ignored, so overlapping hits do not stack the pause.

### 5. Zoom punch-in on a special move

Punch the camera in as a special charges, then let On Zoom Finished cue the release.

```
On Special Triggered
  -> Player | JuiceBehavior: Zoom By Percent  150, 0.3

On Zoom Finished
  -> Player: release special beam
```

Zoom in to 1.5x over 0.3 seconds; the result is clamped to `max_zoom` so it never overshoots.

### 6. Frame a boss on spawn

Glide the camera so the boss ends up centred while zooming in a touch, in one action.

```
On Boss Spawned
  -> Camera | JuiceBehavior: Zoom To Position  Boss.global_position, 130, 0.8
```

Zoom To Position both zooms and recentres, so you frame the arrival without a separate camera move.

### 7. Zoom back out to reveal the arena

After the intro, pull the camera back out. A percent below 100 zooms out.

```
On Zoom Finished
  Condition: GameState  Is Boss Intro
    -> Camera | JuiceBehavior: Zoom By Percent  70, 1.0
```

Chaining off On Zoom Finished sequences the pull-back right after the punch-in with no timer.

### 8. Strategy map zoom toward the cursor

On a map or RTS view, keep the world point under the mouse pinned as you zoom - the wheel-to-cursor feel.

```
On Mouse Wheel Up
  -> Camera | JuiceBehavior: Zoom Toward Point  Mouse.world_position, 120, 0.15
```

Zoom Toward Point anchors the passed world position under the same screen spot, unlike Zoom To Position which recentres on it.

### 9. UI button pop

Attach the behavior to a `Control` and pop it when pressed. The pivot is centred for you, so the button scales from its middle.

```
On Button Pressed
  -> StartButton | JuiceBehavior: Spring Squash  0.25
```

The same behavior works on any `Control` - a panel that slides in, an icon that reacts to a hover.

### 10. Chain hitstop into slow motion for a big finisher

Freeze on impact, then, when the freeze ends, drop into slow motion for the follow-through.

```
On Finisher Landed
  -> Player | JuiceBehavior: Hitstop  0.12, 0.0

On Hitstop Finished
  -> Player | JuiceBehavior: Slowmo  0.2, 0.5, realtime
```

Hitstop pauses any running Slowmo, and here it hands off cleanly by starting the Slowmo only after On Hitstop Finished.

### 11. Explosion shake scaled by distance

A nearby blast rocks the screen, a distant one barely registers. Feed a distance-based strength into Shake.

```
On Explosion
  -> Player | JuiceBehavior: Shake  clamp(1.0 - Player.global_position.distance_to(Explosion.global_position) / 500.0, 0, 1)
```

The expression falls off with distance, so the same event gives near and far explosions different weight.

### 12. Pin the effects to a specific camera

In split screen or a custom rig, tell Juice which camera to drive instead of the auto-found one.

```
On Ready
  -> Player | JuiceBehavior: Use Camera  "../CameraRig/PlayerCamera"

On Player Damaged
  -> Player | JuiceBehavior: Shake  0.4
```

Once Use Camera is set, every Shake and Zoom targets that camera. Leave Use Camera out entirely and Juice targets whatever camera is active.

### 13. Rumble strength from the Trauma expression

Match a controller rumble or a shaking HUD element to the camera by reading Trauma each frame.

```
Every 0.05 seconds
  Condition: Player | JuiceBehavior  Is Shaking
    -> Input: start rumble at strength Player | JuiceBehavior.Trauma
```

Is Shaking gates the loop so you only push rumble while the camera is actually moving, and Trauma gives the matching intensity.

### 14. Charge-up pulse

Squash the host a little on each tick while a charge is held, building an anticipatory pulse before the release.

```
Every 0.2 seconds
  Condition: Player  Is Charging
    -> Player | JuiceBehavior: Spring Squash  0.15
```

Each pulse springs back before the next, so a held charge reads as a rhythmic breathing rather than a single pop.

### 15. Clean up slowmo on a scene change

If a slowmo could still be running when you leave a scene or open a menu, snap the time scale back so the next scene is not stuck slow.

```
On Level Exit
  -> Player | JuiceBehavior: Clear Slowmo
```

Clear Slowmo cancels the ramp and forces `Engine.time_scale` back to 1.0 immediately.

### 16. Elastic pop for a pickup

Use the tween Squash & Stretch when you want a fixed-duration, snappy elastic pop rather than a spring that settles on its own.

```
On Coin Collected
  -> Coin | JuiceBehavior: Squash & Stretch  0.5, 0.3

On Squash Finished
  -> Coin: queue free
```

Squash & Stretch runs over the `duration` you pass and fires On Squash Finished when the elastic settle completes, a clean hook to remove the coin.

---

### 17. Gun recoil that climbs under sustained fire

Each shot kicks the camera up 12 pixels; the spring-back is slower than the fire rate, so holding the trigger walks the view upward exactly like a real spray pattern.

```
On Shoot
  -> Player | Juice: Recoil  -90, 12
```

### 18. Footsteps you can feel

Bob while moving, stop when idle - two rows and the camera walks with the character.

```
Every tick
  Condition: Player  is moving
    -> Player | Juice: Start Head Bob  6, 2.2
  Else
    -> Player | Juice: Stop Head Bob
```

### 19. A drift lean

Tilt into the corner while drifting, level out on exit - the roll eases both ways.

```
On Drift Started
  -> Car | Juice: Tilt To  8, 0.3

On Drift Ended
  -> Car | Juice: Tilt To  0, 0.4
```

### 20. Low-health unease

A permanent subtle wobble below 25% health that vanishes on heal - jitter never decays, so it reads as a STATE, not an event.

```
On Health Changed
  Condition: Player.health < 25
    -> Player | Juice: Start Jitter  2
  Else
    -> Player | Juice: Stop Jitter
```

## Tips and common mistakes

- **Camera effects need an active Camera2D.** Shake and the three Zoom actions drive `get_viewport().get_camera_2d()`. If nothing is happening on Shake, confirm a `Camera2D` in the scene is set as current (or pin one with Use Camera). No camera means the action quietly does nothing.
- **Squash acts on the host, not the camera.** Squash & Stretch and Spring Squash scale the node the behavior is attached to. Put the behavior on the exact sprite or `Control` you want to pop - attaching it to a parent and expecting a child to move will not work.
- **Do not fight the shake by writing camera offset yourself.** The shake is additive on the camera's own offset and rotation and restores them when it settles. If your own code also writes `camera.offset` every frame, the two will overwrite each other. Let the follow logic set the base and let Juice add the shake on top.
- **Shake stacks, so keep per-hit strengths small.** Trauma clamps at 1, and a small `strength` per hit (say 0.2 to 0.4) builds naturally across a burst. Passing 1.0 on every hit pins it at maximum and you lose the sense of escalation.
- **Slowmo and Hitstop are global.** Both change `Engine.time_scale` for the whole game, not just this node. That is the point, but it means anything that must keep real-time speed (music, a realtime UI animation) needs its own handling. Hitstop already pauses a running Slowmo so the two do not compound.
- **Pick the right clock for a Slowmo hold.** `realtime` measures the hold in wall-clock seconds regardless of the slowdown; `gametime` measures it in scaled game time, so a deep slowmo makes the hold feel much longer. Reach for `realtime` when you want a predictable beat length.
- **Always have a way back from a freeze or a slowmo.** A Hitstop restores the previous time scale on its own, and a Slowmo ramps back by itself, but if a scene can be torn down mid-effect, call Clear Slowmo on exit so you never leave the game stuck slow. Repeated Hitstop calls during a freeze are ignored, so you cannot accidentally trap yourself frozen.
- **Positive stretch is tall, negative is wide.** For a jump you usually want a positive `stretch` (tall and thin); for a landing you want a negative one (short and wide). Passing the wrong sign makes a jump look like a squash. The value is clamped to the -0.9 to 5.0 range.
- **Choose Spring Squash for organic, Squash & Stretch for timed.** Spring Squash settles on its own using the stiffness and damping knobs and reads bouncier; Squash & Stretch runs for the exact `duration` you pass and springs back elastically. Use the spring for character feel, the tween when you need a fixed-length pop that ends with On Squash Finished.
- **React to the finished triggers instead of guessing timing.** To sequence a beat after an effect, wire On Zoom Finished, On Squash Finished, On Slowmo Finished, On Hitstop Finished or On Shake Stopped rather than an approximate `Every N seconds`. The triggers fire exactly when the effect ends, so chained sequences stay in sync.
