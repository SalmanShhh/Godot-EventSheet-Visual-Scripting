# FPS Controller

FPS Controller is a complete first-person / third-person character controller you attach under a
`CharacterBody3D` and drive from event-sheet rows. It handles mouse look (yaw on the body, pitch
on the head), WASD/arrow movement relative to where you look, Shift sprint, Space jump with
gravity, landing detection, and a one-verb camera-mode switch between first and third person.
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
| Condition | Is Sprinting | True while Shift is held. |
| Condition | Is First Person | True in first-person mode. |
| Expression | Current Speed | Horizontal speed in m/s (drive a speed HUD or FOV kick). |
| Expression | Look Yaw / Look Pitch | The current view angles in degrees. |

Exported knobs (Inspector or sheet variables): Move Speed, Sprint Multiplier, Jump Velocity,
Gravity, Mouse Sensitivity, Pitch Min/Max, Third Person, Camera Distance, Capture Mouse On Ready.

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

## Tips and common mistakes

- **The camera pitches from the Head, not the camera.** Put the Head at eye height and leave
  the Camera3D's transform alone (besides the rig's 180° yaw).
- **No `Head` child = no pitch, no camera modes.** The behavior still moves and jumps; it just
  skips what it can't find. Name the nodes exactly `Head` and `Arm`.
- **Mouse won't turn?** The cursor must be captured - Capture Mouse On Ready is on by default,
  and clicking Capture Mouse re-locks after an Esc.
- **Custom keys.** Movement reads `ui_left/right/up/down` and jump reads `ui_accept`; remap
  those actions in the Input Map, or call Jump / Add Look from your own input events for fully
  custom bindings.
