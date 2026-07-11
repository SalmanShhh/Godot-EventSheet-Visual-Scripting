# FPS Controller

FPS Controller is a complete first-person / third-person character controller you attach under a
`CharacterBody3D` and drive from event-sheet rows. It handles mouse look (yaw on the body, pitch
on the head), WASD/arrow movement relative to where you look, Shift sprint, Space jump with
gravity, landing detection, and a one-verb camera-mode switch between first and third person.
Movement tech is built in: **crouch** (hold Ctrl - the capsule physically shrinks, and standing
is ceiling-checked so you cannot pop up inside a vent), **crouch slide** (crouch while
sprinting), **wall ride** (hold forward against a wall mid-air to glide along it), and
**wall jump** (press jump mid-air against any wall) - each with its own triggers, so a camera
lean or a sound is one row away.
The bundled **FPS Arena** showcase (`demo/showcase/fps_arena/`) is the reference setup - open it,
press play, and walk around before wiring your own.

It ships as the **`FPSController`** behavior: add it as a child of your player and the pack's
verbs appear in every sheet's picker, node-targeted at that player.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [The rig it expects](#the-rig-it-expects)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **A playable 3D character in one attach.** No input code, no camera math - attach, add the
  camera rig, press play.
- **First AND third person from the same setup.** `Toggle Camera Mode` slides the camera along a
  spring arm; walls never clip through it (SpringArm3D does the work).
- **Sheet-driven feel tuning.** Speed, sprint, jump, sensitivity, and pitch clamps are exported
  knobs AND runtime verbs - a speed-boost pickup is one `Set Move Speed` action.
- **Reactive hooks.** `On Jumped`, `On Landed`, and `On Camera Mode Changed` are triggers -
  play a sound on land, kick particles on jump, swap HUDs per camera mode.

## The rig it expects

```
Player (CharacterBody3D)          <- attach FPSController under this
├─ CollisionShape3D (capsule)
├─ MeshInstance3D (your model)
├─ Head (Node3D, at eye height)   <- pitch happens here
│  └─ Arm (SpringArm3D, yaw 180)  <- ~0 length = first person, Camera Distance = third
│     └─ Camera3D (yaw 180)
└─ FPSController (the behavior)
```

The two 180° turns make the SpringArm3D extend BEHIND the player while the camera still faces
forward. Copy the rig from the FPS Arena showcase if in doubt - names matter (`Head`, `Arm`):
the behavior finds them by name and quietly skips what's missing.

## Setup

1. Build the rig above (or copy the showcase's Player).
2. In the sheet editor: Tools → Attach to Selected Node, or drag
   `eventsheet_addons/fps_controller/fps_controller_behavior.gd` onto a child node of the player.
3. Press play. WASD/arrows move, the mouse looks, Shift sprints, Space jumps, Esc frees the
   mouse. Movement uses Godot's built-in `ui_*` actions, so it works in a fresh project with no
   Input Map edits.

## ACE reference

| Kind | Name | What it does |
|------|------|--------------|
| Trigger | On Jumped | Fires the moment a jump launches. |
| Trigger | On Landed | Fires the frame the host touches the floor again. |
| Trigger | On Camera Mode Changed | Fires when first/third person flips. |
| Action | Jump | Launches upward with Jump Velocity (also fires On Jumped). |
| Action | Add Look (x, y) | Turns the view by a mouse delta - the same verb the built-in mouse look calls. |
| Action | Set Third Person (enabled) | Switches camera mode explicitly. |
| Action | Toggle Camera Mode | Flips first/third person. |
| Action | Apply Camera Mode | Re-applies the mode to the Arm (after swapping rigs at runtime). |
| Action | Capture Mouse / Release Mouse | Locks the cursor for looking / frees it (Esc also frees it). |
| Action | Set Move Speed / Set Sprint Multiplier / Set Mouse Sensitivity | Runtime feel tuning. |
| Action | Crouch / Stand Up / Set Crouching (enabled) | Crouches (capsule shrinks to Crouch Height, Head drops, speed drops to the crouch multiplier) / stands - refused while a ceiling blocks the headroom. Held Ctrl drives these automatically. |
| Action | Stop Sliding | Ends a crouch slide early (you stay crouched). |
| Action | Wall Jump | Kicks off the touched wall: Jump Velocity up + Wall Jump Push away (the push fades over ~0.5 s). Pressing jump mid-air against a wall does this automatically. |
| Action | Stop Wall Ride | Detaches from the wall; full gravity resumes. |
| Trigger | On Crouched / On Stood Up | Crouch state changes. |
| Trigger | On Slide Started / On Slide Ended | The crouch slide window - great for a camera tilt. |
| Trigger | On Wall Ride Started / On Wall Ride Ended | Wall contact glide begins/ends - lean the camera here. |
| Trigger | On Wall Jumped | A wall jump launched. |
| Condition | Is Sprinting | True while Shift is held. |
| Condition | Is First Person | True in first-person mode. |
| Condition | Is Crouching / Is Sliding / Is Wall Riding | The movement-tech states. |
| Condition | Can Stand Up | True when there is headroom to stand (no ceiling above the crouched capsule). |
| Expression | Current Speed | Horizontal speed in m/s (drive a speed HUD or FOV kick). |
| Expression | Look Yaw / Look Pitch | The current view angles in degrees. |
| Expression | Wall Normal X / Z | The touched wall's outward normal (zero off-wall) - the wall-jump push direction; feed it to a camera lean. |

Exported knobs (Inspector or sheet variables): Move Speed, Sprint Multiplier, Jump Velocity,
Gravity, Mouse Sensitivity, Pitch Min/Max, Third Person, Camera Distance, Capture Mouse On Ready.
Movement tech knobs: Crouch Height + Crouch Speed Multiplier; Slide Enabled + Slide Boost Speed +
Slide Min Speed (the speed a crouch must be moving at to slide - default just above walking, so
only a sprint-crouch slides) + Slide Duration; Wall Ride Enabled + Wall Ride Gravity Scale +
Wall Ride Max Time + Wall Ride Min Speed; Wall Jump Enabled + Wall Jump Push.

### How the tech reads your rig

- **Crouch** finds the host's capsule `CollisionShape3D` automatically, duplicates the shape
  resource on first use (so a capsule shared between scenes never shrinks globally), shortens it
  toward the floor, and drops the `Head` by the lost height. Standing sweeps the body upward
  first - blocked headroom keeps you crouched, and the stand retries each frame the key is up,
  so you pop up the moment you clear the vent.
- **Crouch slide** starts when you crouch while moving at Slide Min Speed or faster on the
  floor: direction locks, speed decays from Slide Boost Speed down to crouch-walk pace over
  Slide Duration. Jumping or Stop Sliding ends it early.
- **Wall ride** engages mid-air when you hold forward against a wall with enough speed: gravity
  drops to Wall Ride Gravity Scale and a slight stick keeps you glued until the timer, the wall,
  or your speed runs out.
- **Wall jump** works from a ride or any mid-air wall touch: up at Jump Velocity, away at Wall
  Jump Push, and the push decays over about half a second so air control comes back smoothly.

## Use cases

1. **Landing thud.** `On Landed → PlaySound "thud"` - two rows, no state tracking.
2. **Speed pickup.** On the pickup's body_entered: `Set Move Speed 9` + `Every 5 seconds →
   Set Move Speed 5` to wear off.
3. **Sprint FOV kick.** `Every tick + Is Sprinting → set $Player/Head/Arm/Camera3D.fov to 85`,
   else back to 75 - Current Speed makes it proportional if you want.
4. **Cutscene control.** `Release Mouse` + `Set Third Person true` when dialogue starts;
   `Capture Mouse` + restore on end.
5. **Ladder / low-gravity zones.** An Area3D toggles the Gravity knob - the controller keeps
   working, just floatier.
6. **Slide dash with a camera kick.** `On Slide Started → Juice 3D: FOV Punch 8` and
   `On Slide Ended → (nothing - the punch recovers itself)`. Sprint, tap Ctrl, feel the speed.
7. **Wall-run lean.** `On Wall Ride Started → Juice 3D: Lean (Wall Normal X * -12, 0.2)` then
   `On Wall Ride Ended → Lean (0, 0.25)` - the camera banks into the wall and levels out.
8. **Vent crawl gate.** `Is Crouching + not Can Stand Up → show "find the exit" hint` - the
   ceiling check doubles as a "am I inside a crawlspace" test.
9. **Parkour chain telegraph.** `On Wall Jumped → Juice 3D: Recoil 1.0 0.3` + a whoosh sound -
   every kick off a wall gets tactile feedback.

## Tips and common mistakes

- **The camera pitches from the Head, not the camera.** Put the Head at eye height and leave
  the Camera3D's transform alone (besides the rig's 180° yaw).
- **No `Head` child = no pitch, no camera modes.** The behavior still moves and jumps; it just
  skips what it can't find. Name the nodes exactly `Head` and `Arm`.
- **Mouse won't turn?** The cursor must be captured - Capture Mouse On Ready is on by default,
  and clicking Capture Mouse re-locks after an Esc.
- **Custom keys.** Movement reads `ui_left/right/up/down` and jump reads `ui_accept`; remap
  those actions in the Input Map, or call Jump / Add Look from your own input events for fully
  custom bindings. Crouch is held Ctrl the same way - or call Set Crouching from any input you
  like (a toggle-crouch is `Set Crouching (not Is Crouching)` on your keybind).
- **"My slide never triggers."** The slide needs Slide Min Speed at the moment you crouch - the
  default (6.5) sits between walk (5) and sprint (8) on purpose. Sprint first, then crouch. If
  you want every moving crouch to slide, lower Slide Min Speed below your walk speed.
- **"Wall ride won't start."** It needs all four: airborne, touching a wall, holding forward,
  and moving at Wall Ride Min Speed. Run ALONG the wall, not into it - a head-on push has no
  tangential speed left after the wall eats it.
- **Turn tech off per game.** Slide, wall ride, and wall jump each have an Enabled knob - a
  slower tactical game can keep crouch and drop the parkour without touching the sheet.
