# Juice 3D - Camera Shake, Recoil, Head Bob, Lean and FOV Punch for 3D

Juice 3D is the 3D camera game-feel pack: trauma-based screenshake, weapon recoil that kicks up
and re-centres, a walking head bob, continuous jitter, a held camera lean (roll), and FOV
punch/zoom - all on the active `Camera3D`, which is found automatically. Attach the
`Juice3DBehavior` under any node (your player is the natural home) and call the verbs from any
sheet; there is no camera path to wire unless you want one.

The design rule that makes it safe to use with a character controller: **every effect is an
additive offset**. Each frame the behavior subtracts what it added last frame, lets whoever owns
the camera (the FPS Controller's mouse look, an animation, a cutscene) write the real pose, then
adds the effects back on top. Your aim is never touched - a full-strength shake with recoil
mid-firefight still leaves the crosshair's true position under the controller's authority, and
when the effects settle the camera is bit-for-bit back where its owner put it.

The verbs mirror the 2D **Juice** pack (Shake / Recoil / Head Bob / Jitter are the same words),
so what you learned there carries over.

---

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Setup](#setup)
3. [ACE reference](#ace-reference)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Weapon feel in one row.** `On Shoot -> Recoil 1.5, 0.5` gives every gun a vertical kick with
  side spread that climbs under sustained fire and re-centres when you ease off - the classic
  spray pattern feel, without touching the aim.
- **Explosions you feel.** Trauma-based shake (the same model as the 2D pack): every hit adds
  trauma, the camera rattles proportionally, and it decays on its own. Fire it from ten places
  at once; it just stacks and settles.
- **Footsteps.** A figure-8 head bob while moving turns a gliding capsule into a walking person.
- **Wall-run and peek leans.** `Lean` rolls the camera to an angle and HOLDS it until you lean
  back - made for the FPS Controller's On Wall Ride Started/Ended triggers.
- **Speed reads as speed.** `FOV Punch 8` on a dash or slide widens the view for a beat and
  recovers by itself; `Zoom FOV To 40` is an aim-down-sights in one action.
- **Nervous states.** Jitter never decays - an idling engine, a helicopter seat, low health,
  fear. Start it when the state begins, stop it when it ends.

## Setup

1. Attach `eventsheet_addons/juice_3d/juice_3d_behavior.gd` under your player (or any node -
   Tools > Attach to Selected Node does it from the editor).
2. Call verbs from any sheet: `Shake 0.4` on damage, `Recoil -90, 12`-style kicks on fire.
   The active `Camera3D` is found automatically; `Use Camera` pins a specific one.
3. It composes with the FPS Controller out of the box - both packs under the same player is the
   intended pairing.

## ACE reference

All ACEs live in the **Juice 3D** category and target the `Juice3DBehavior` on the node they are
placed on.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Shake | `strength` (float) | Adds screenshake to the active camera (0 = none, 1 = max). Stacks and decays automatically - fire it on every hit. Opens at 0.4. |
| Stop Shake | (none) | Cancels any shake immediately (other effects keep running). |
| Recoil | `vertical_kick` (float), `horizontal_spread` (float) | Kicks the view UP by a pitch (degrees) plus a random side spread, then re-centres at the Recoil Recovery rate. Kicks stack, so sustained fire climbs. Cosmetic - aim is untouched. Opens at 1.5, 0.5. |
| Start Head Bob | `amplitude` (float), `frequency` (float) | A walking figure-8 (side sway at half rate, one downward dip per step). Metres and steps-per-second. Call while moving; Stop Head Bob when halting. Opens at 0.06, 2.2. |
| Stop Head Bob | (none) | Stops the head bob. |
| Start Jitter | `position_amount` (float), `roll_degrees` (float) | A continuous nervous wobble (metres + a touch of roll) until Stop Jitter - unlike Shake it never decays. Opens at 0.02, 0.5. |
| Stop Jitter | (none) | Stops the jitter wobble. |
| Lean | `degrees` (float), `duration` (float) | Eases the camera roll to an angle and HOLDS it - wall rides, corner peeks, banking turns. Lean back to 0 to level out. Emits On Lean Finished. Opens at 10, 0.25. |
| FOV Punch | `amount` (float) | Kicks the field of view wider (positive - a dash) or tighter (negative - an impact) by degrees, then eases back at the FOV Recovery rate. Fire-and-forget. Opens at 8. |
| Set Screen Tint | `color`, `strength` | Washes the whole screen over the 3D view at Strength opacity - damage red, poison green, night blue. |
| Fade Screen Tint | `seconds` | Fades the tint to nothing - the damage-flash pattern. |
| Clear Screen Tint | (none) | Removes the wash instantly. |
| Zoom FOV To | `fov` (float), `duration` (float) | Smoothly changes the camera's base FOV and keeps it there (aim-down-sights is 40; back to 75 to unzoom). Emits On Zoom Finished. Opens at 40, 0.15. |
| Use Camera | `camera_path` (NodePath) | Pins the effects to a specific `Camera3D`. Leave unset to auto-target the active camera. |
| Kick Camera Away From Point | `world_position` (Vector3), `strength` (float) | Shoves the camera AWAY from a world position (an explosion, a hit source) and re-centres at the Kick Recovery rate - Recoil's directional sibling. Opens at 0.12. |
| Start Blinking | `times_per_second` (float) | Strobes the host's visibility - invulnerability frames, respawn grace, a targeted highlight. Runs until Stop Blinking. Opens at 8. |
| Stop Blinking | (none) | Stops the blink and makes the host visible again. |
| Punch Scale | `strength` (float), `duration` (float) | Kicks the host's scale up (or down, negative) and springs back elastically - pickups, flinches, beat pulses. Opens at 0.25, 0.35. |
| Punch Position | `offset` (Vector3), `duration` (float) | Kicks the host's position (metres) and springs back - knockback reads, impact shoves. Opens at (0.2, 0, 0), 0.35. |
| Pulse Vignette | `strength` (float), `color` (Color), `seconds` (float) | Darkens the screen edges to a color, then fades back out - taking damage, a near miss. Opens at 0.6, dark red, 0.5. |
| Chromatic Kick | `strength` (float), `seconds` (float) | Splits the screen's color channels for an instant and settles back - the AAA impact frame. Opens at 0.5, 0.25. |
| Set Speed Lines | `intensity` (float) | Radial anime-style speed streaks that HOLD until you set 0 - sprints, dashes, adrenaline. Pair with FOV Punch. Opens at 0.5. |
| Play Sound Varied | `path` (String), `pitch_jitter` (float), `volume_jitter_db` (float) | Plays a sound with a random pitch/volume wobble - the cure for repetitive footsteps, hits, shots. Opens at 0.08, 2. |
| Play Sound With Intensity | `path` (String), `intensity` (float) | Plays a sound scaled by a 0-1 intensity - drive it, Shake, and Punch Scale from ONE hit-power value. Opens at 0.5. |
| Count To | `ticker_name` (String), `target` (float), `duration` (float) | Eases a named display value toward a target - scores ROLL instead of snapping. Read via Ticker Value. Opens at score, 100, 0.6. |
| Set Ticker | `ticker_name` (String), `value` (float) | Sets a display value instantly (cancelling any roll). |

### Conditions and expressions

| Kind | Name | Description |
|---|---|---|
| Condition | Is Shaking | Whether trauma is above zero. |
| Expression | Trauma | The current trauma level, 0 to 1 - drive controller rumble from it. |
| Expression | Ticker Value | What a ticker currently SHOWS - the eased value Count To is rolling (`ticker_name`). |

### Triggers

| Trigger | Fires when |
|---|---|
| On Shake Stopped | Trauma reaches zero after a shake. |
| On Lean Finished | A Lean ease reaches its target roll. |
| On Zoom Finished | A Zoom FOV To glide completes. |
| On Punch Finished | A Punch Scale / Position has sprung back to rest. |
| On Ticker Finished | A Count To roll lands on its target (carries the ticker's name). |

### Inspector properties

| Property | Type | Default | Range |
|---|---|---|---|
| `max_shake_degrees` | float | `4.0` | 0.0 - 30.0 |
| `max_shake_offset` | float | `0.05` | 0.0 - 1.0 |
| `shake_decay` | float | `1.4` | 0.1 - 10.0 |
| `shake_frequency` | float | `25.0` | 1.0 - 60.0 |
| `recoil_recovery` | float | `30.0` | 1.0 - 360.0 |
| `fov_recovery` | float | `60.0` | 5.0 - 500.0 |

---

## Use cases

### 1. A rifle with climb

Every shot pitches the view up 1.2 degrees with a little horizontal wander; the recovery (30
degrees per second by default) cannot keep up with a 10-shots-per-second trigger, so holding
fire walks the view upward - release, and it settles back.

```
On Shoot
  -> Player | Juice 3D: Recoil  1.2, 0.4
```

### 2. Explosion shake scaled by distance

Closer blasts rattle harder. Trauma stacking means overlapping explosions just feel bigger.

```
On Explosion
  -> Player | Juice 3D: Shake  clampf(1.0 - distance / 30.0, 0.0, 1.0)
```

### 3. Footsteps while moving

Pair with the FPS Controller's speed: bob when moving, stop when idle, sprint bobs faster.

```
Every tick
  Condition: Player | FPS Controller: Current Speed > 0.5
    -> Player | Juice 3D: Start Head Bob  0.06, 2.2
  Else
    -> Player | Juice 3D: Stop Head Bob
```

### 4. Wall-run camera bank

The FPS Controller says when a wall ride starts and which side the wall is on; the lean sells it.

```
On Wall Ride Started
  -> Player | Juice 3D: Lean  12, 0.2

On Wall Ride Ended
  -> Player | Juice 3D: Lean  0, 0.3
```

### 5. Slide speed rush

A crouch slide reads twice as fast with an FOV kick - and the punch recovers on its own, right
about when the slide's boost decays.

```
On Slide Started
  -> Player | Juice 3D: FOV Punch  8
```

### 6. Aim down sights

Zoom the base FOV in and out; recoil and shake keep working on top of the zoomed view.

```
On Aim Pressed
  -> Player | Juice 3D: Zoom FOV To  40, 0.12

On Aim Released
  -> Player | Juice 3D: Zoom FOV To  75, 0.15
```

### 7. Helicopter seat

Continuous jitter while flying, gone the moment you land.

```
On Boarded Helicopter
  -> Player | Juice 3D: Start Jitter  0.015, 0.8

On Left Helicopter
  -> Player | Juice 3D: Stop Jitter
```

### 8. Rumble from trauma

The Trauma expression is the shake's live intensity - feed it straight into gamepad vibration so
hands feel what eyes see.

```
Every tick
  -> Input: Start Vibration ($Player/Juice3D.current_trauma(), 0.1)
```

### 9. Damage feedback in one row

The simplest possible hookup - every hit adds trauma, the decay handles the rest.

```
On Player Hit
  -> Player | Juice 3D: Shake  0.4
```

Stacking is the feature: three fast hits rattle harder than one, with no bookkeeping.

### 10. Landing thump

A negative FOV punch reads as impact, and a whisper of shake gives the fall weight. Fire both
from whatever marks the landing in your controller.

```
On Landed
  -> Player | Juice 3D: Shake  0.15
  -> Player | Juice 3D: FOV Punch  -3
```

### 11. Low-health tremble

Jitter is a state, so bind it to a state: shaky hands under 25 health (the Health pack supplies
the number), steady again above.

```
Every tick
  Condition: player_health < 25
    -> Player | Juice 3D: Start Jitter  0.01, 0.4
  Else
    -> Player | Juice 3D: Stop Jitter
```

### 12. Corner peek on Q and E

Lean holds until told otherwise, so the release row is what levels you out.

```
Every tick
  Condition: Key "q" is down      -> Player | Juice 3D: Lean  -14, 0.15
  Condition: Key "e" is down      -> Player | Juice 3D: Lean  14, 0.15
  Condition: neither key is down  -> Player | Juice 3D: Lean  0, 0.2
```

### 13. Sniper scope gated on the glide

On Zoom Finished tells you the ease actually arrived - show the scope overlay then, not on the
button press, and the zoom-in feels deliberate.

```
On Aim Pressed   -> Player | Juice 3D: Zoom FOV To  30, 0.2
On Zoom Finished -> (show the scope overlay, enable the shot)
On Aim Released  -> Player | Juice 3D: Zoom FOV To  75, 0.15
```

### 14. Cutscene calm

The cleanup rows: kill every looping effect before a scripted camera takes over, and pin the
effects to the cutscene rig if you still want scripted shakes there.

```
On Cutscene Started
  -> Player | Juice 3D: Stop Shake
  -> Player | Juice 3D: Stop Jitter
  -> Player | Juice 3D: Stop Head Bob
  -> Player | Juice 3D: Use Camera  $CutsceneRig/Camera3D
On Cutscene Ended
  -> Player | Juice 3D: Use Camera  $Player/Head/Camera3D
```

### 15. Earthquake with aftershocks

On Shake Stopped is a chain link: when the big one settles, fire a smaller one, and the quake
tapers naturally instead of clipping off.

```
On Quake Started -> Player | Juice 3D: Shake  1.0
On Shake Stopped
  Condition: aftershocks_left > 0
    -> subtract 1 from aftershocks_left
    -> Player | Juice 3D: Shake  0.5
```

### Other use cases

**Boss footstep dread.** Scale a small Shake by the boss's distance on every stomp so the floor feels heavier as it closes in, with zero extra camera code.

**Poison sway.** A long, slow Lean eased left and right on a timer while poisoned makes the world swim; Lean back to 0 on cure.

**Turret sections.** Recoil with a big vertical kick and a slow recovery knob turns a mounted gun emplacement into something with mass, even though the aim never actually moves.

**Train and boat rides.** Start Jitter for the whole ride gives vehicles a live engine feel, and stopping it at the station makes solid ground register.

**Photo mode discipline.** Stop Shake, Stop Jitter, and Stop Head Bob on entering photo mode guarantee a still frame no matter what was exploding a moment before.

---

## Tips and common mistakes

- **Attach it once, near the player.** The camera is auto-found, so one behavior serves the
  whole game; a second copy elsewhere would fight the first for the same camera's offsets.
- **Recoil is cosmetic by design.** The kick rides on top of the controller's look and recovers
  to wherever the player is ACTUALLY aiming - it never pushes bullets off target. If you want
  ballistic spread, apply it to the projectile, not the camera.
- **Lean holds; punch recovers.** `Lean` stays until you lean back (it is a state), `FOV Punch`
  and `Recoil` come back on their own (they are events). Pick the verb that matches what you
  mean.
- **Zoom FOV To is absolute.** It sets the base field of view and leaves it - remember the row
  that zooms back out, or the player stays at 40 forever.
- **Shake feel lives in the knobs.** `max_shake_degrees` is how violent a full-trauma shake
  looks, `shake_decay` is how fast it calms, `shake_frequency` is how nervous it feels. Tune
  those in the Inspector rather than scaling every Shake call.
- **2D game?** Use the **Juice** pack instead - same verbs on the `Camera2D`, plus zoom, squash
  and stretch, slowmo, and hitstop.
