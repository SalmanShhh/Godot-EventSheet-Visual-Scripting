# Engine-Level ACEs

Most of the picker talks to a **node** you placed: move this sprite, play that sound, check this body. This page collects the vocabulary that talks to the **engine itself** - the rendering server, the physics world, the audio mixer - plus the verbs that build 3D content at runtime. These are the rows behind a graphics options menu, a low-gravity power-up, an underwater audio filter, or a block you spawn from nothing.

Everything here is a builtin ACE, so it is in the picker of every sheet with no addon to install. Each section names the picker category to look under.

## Table of Contents

1. [Graphics settings (Rendering)](#graphics-settings-rendering)
2. [The physics world (Physics Server)](#the-physics-world-physics-server)
3. [Audio mixing (Audio Server)](#audio-mixing-audio-server)
4. [Meshes at runtime (Mesh)](#meshes-at-runtime-mesh)
5. [Camera field of view (Camera)](#camera-field-of-view-camera)
6. [Animation playback (Animation)](#animation-playback-animation)
7. [Gradients and curves](#gradients-and-curves)

---

## Graphics settings (Rendering)

Picker category: **Rendering**. This is the whole of a standard graphics options menu, plus the diagnostics you want on a debug hotkey. The settings apply to the current viewport (or globally, for clear colour and shader globals).

### Actions

| Action | Parameters | What it does |
| --- | --- | --- |
| **Set Clear Color** | `color` | The default background colour of the whole game - what you see where nothing is drawn. |
| **Set Global Shader Parameter** | `name`, `value` | Drives a global shader uniform (Project Settings > Shader Globals). Every material reading it updates at once - the code-free way to animate weather or a world-wide tint. |
| **Set MSAA (2D)** / **Set MSAA (3D)** | `level` | Multisample antialiasing for 2D / 3D on the current viewport - the standard quality switch. |
| **Set Screen-Space AA** | `mode` | Turns FXAA on or off - cheaper than MSAA, softer result. |
| **Set 3D Resolution Scale** | `scale` | Renders the 3D scene at a fraction of window resolution and upscales - the classic performance slider. |
| **Set Debug Draw Mode** | `mode` | Switches the viewport to a diagnostic view (wireframe, overdraw heat, unshaded) and back. |
| **Set Occlusion Culling** | `enabled` | Big scenes skip drawing what walls already hide. |
| **Set Debanding** | `enabled` | Removes the visible stripes in smooth dark gradients, for a tiny cost. |

### Conditions and expressions

| Verb | Kind | Gives you |
| --- | --- | --- |
| **Uses Modern Renderer** | Condition | True on Forward+ / Mobile, false on Compatibility (old GPUs, web) - gate fancy effects on it. |
| **Draw Calls (frame)** | Expression | Draw calls issued this frame. |
| **Objects Drawn (frame)** | Expression | Objects drawn this frame. |
| **Primitives Drawn (frame)** | Expression | Primitives (triangles) drawn this frame. |
| **Video Memory Used** | Expression | Video memory currently in use. |
| **Global Shader Parameter** | Expression | The current value of a global shader uniform. |
| **Clear Color** | Expression | The current background colour. |

A quality dropdown is then four rows:

```
On quality changed to "Low"
  -> Set MSAA (3D)            "Disabled"
  -> Set 3D Resolution Scale  0.75
  -> Set Occlusion Culling    true
  -> Set Debanding            false
```

---

## The physics world (Physics Server)

Picker category: **Physics Server**. These change the world every body lives in, rather than one body's velocity - the difference between "push this crate" and "the moon has less gravity".

Gravity here drives every **RigidBody**. A CharacterBody applies gravity itself in its own movement code (or in a movement pack's property), so change both if you want a character to feel the same shift.

### Actions

| Action | Parameters | What it does |
| --- | --- | --- |
| **Set World Gravity (2D)** / **(3D)** | `gravity` | The whole world's gravity strength - low-gravity power-ups, water levels, space stations. |
| **Set World Gravity Direction (2D)** / **(3D)** | `direction` | Points world gravity somewhere new - gravity-flip mechanics, rotating stages, walk-on-walls arenas. |
| **Set Physics Active (2D)** / **(3D)** | `active` | Pauses or resumes the whole physics space - a photo mode or cutscene freeze that leaves rendering and scripts running (unlike pausing the tree). |

### Expressions

| Expression | Gives you |
| --- | --- |
| **Active Bodies (2D)** / **(3D)** | How many bodies are awake and simulating - the first number to watch when physics gets slow. |
| **Collision Pairs (2D)** / **(3D)** | How many collision pairs are processed this step. |
| **Physics Islands (2D)** / **(3D)** | How many independent groups of touching bodies the solver is working on. |
| **Physics Interpolation Fraction** | How far between physics ticks this frame is (0..1) - hand-smooth visuals that follow physics bodies. |

```
On enter moon level
  -> Set World Gravity (3D)  3.7

On gravity flip
  -> Set World Gravity Direction (2D)  Vector2(0, -1)
```

---

## Audio mixing (Audio Server)

Picker category: **Audio Server**. Buses are set up in Godot's Audio panel; these verbs drive them at runtime. This is the options-menu volume story and the "everything sounds muffled underwater" trick.

| Verb | Kind | What it does |
| --- | --- | --- |
| **Set Bus Muted** | Action | Mutes or unmutes a whole bus - the music/SFX toggle in one action. |
| **Set Bus Solo** | Action | Only soloed buses are heard - focus dialogue in a cutscene, audition a layer. |
| **Set Bus Effects Bypassed** | Action | Skips or restores ALL effects on a bus at once - dry vs processed in one flip. |
| **Set Bus Effect Enabled** | Action | Flips ONE prepared effect. Add a lowpass to a bus in the Audio panel, then toggle it for the underwater or cave state. |
| **Set Audio Playback Speed** | Action | Scales every sound's speed and pitch - set it alongside a slow-motion effect so the world's audio drops with time. |
| **Bus Exists** | Condition | True when a bus by that name is in the layout - guard optional buses. |
| **Is Bus Effect Enabled** | Condition | True while an effect slot is on - toggle states without a tracking variable. |
| **Bus Peak Volume (dB)** | Expression | The bus's current peak level (very negative = silence) - drive a VU meter, ducking, or audio-reactive visuals. |
| **Audio Playback Speed** | Expression | The current global speed scale. |
| **Bus Count** | Expression | How many buses the layout has. |
| **Audio Output Latency** | Expression | Output latency in seconds - rhythm games subtract it when judging hits. |

```
On enter water
  -> Set Bus Effect Enabled  "Master", 0, true

On exit water
  -> Set Bus Effect Enabled  "Master", 0, false
```

---

## Meshes at runtime (Mesh)

Picker category: **Mesh**. These build a primitive shape onto a `MeshInstance3D` you already have in the scene - greyboxing, procedural props, or a stand-in body while you block out a level. No modelling tool required.

| Verb | Kind | Parameters |
| --- | --- | --- |
| **Make Box Mesh** | Action | `size` (Vector3) |
| **Make Sphere Mesh** | Action | `radius` |
| **Make Cylinder Mesh** | Action | `radius`, `height` |
| **Make Plane Mesh** | Action | `size` (Vector2) - a quick floor or wall |
| **Make Capsule Mesh** | Action | `radius`, `height` - a stand-in character body |
| **Make Prism Mesh** | Action | `size` (Vector3) - a wedge or ramp |
| **Make Torus Mesh** | Action | `inner_radius`, `outer_radius` - a ring or donut |
| **Set Mesh Material** | Action | `material` - one line to recolour or reskin the shape |
| **Clear Mesh** | Action | Removes the mesh so nothing draws |
| **Has Mesh** | Condition | True when this MeshInstance3D currently shows a mesh |
| **Mesh Surface Count** | Expression | How many surfaces (material slots) - 0 when there is no mesh |
| **Mesh Size** | Expression | The bounding-box size (width, height, depth) in local space - handy for fitting or spacing |

---

## Camera field of view (Camera)

Picker category: **Camera**. Field-of-view control for 3D cameras - the aim-down-sights zoom and the speed-boost widen.

| Verb | Kind | What it does |
| --- | --- | --- |
| **Tween Camera FOV** | Action | Smoothly eases the active 3D camera's FOV to a target over a duration. Clamped to the legal range. |
| **Adjust Camera FOV** | Action | Nudges a camera's FOV by a relative amount, clamped so repeated zooms can never flip the camera inside-out. |
| **Camera FOV** | Expression | A camera's current field of view in degrees - for a HUD zoom indicator or a dynamic-FOV rig. |

---

## Animation playback (Animation)

Picker category: **Animation**. Beyond Play and Stop, these drive an `AnimationPlayer` precisely - scrubbing, queueing, and reading where the play head is.

| Verb | Kind | What it does |
| --- | --- | --- |
| **Set Animation Speed** | Action | Scales how fast every animation on this player runs - slow-mo a death, speed up a fast-forward. `0` freezes it. |
| **Seek Animation** | Action | Jumps the play head to a time in seconds and updates the pose immediately - scrub, restart from a beat, sync to another clock. |
| **Queue Animation** | Action | Lines up an animation to play when the current one ends - combo chains, or dropping back to idle after an attack, with no timer. |
| **Pause Animation** | Action | Freezes at the current position (Play resumes from here) - a hit-pause on a specific frame, or a photo mode. |
| **Set Current Animation** | Action | Switches which clip is current (assigning it starts it) - a direct set when you do not need Play's blend arguments. |
| **Has Animation** | Condition | True when this player owns a clip by that name - guard a Play so a missing animation never errors. |
| **Animation Position** | Expression | How many seconds into the current animation the play head is - sync an effect to a frame, or drive a progress bar. |
| **Animation Length** | Expression | The current animation's total length - pair with Animation Position for a normalized 0-to-1 progress. |
| **Animation Speed** | Expression | The player's current speed scale (`1` = normal). |

The same category also holds the AnimationTree verbs (Travel To State, Set Tree Parameter, Is In State, Current State) and the auto-finding "in object" verbs (Play Animation, Flip Sprite, Set Sprite Frame) that locate a node's AnimationPlayer or AnimatedSprite2D for you.

---

## Gradients and curves

Picker category: **Gradients & Curves**. Turn a designer-drawn ramp or curve into a colour or a number, with no maths in the sheet.

| Verb | Kind | What it does |
| --- | --- | --- |
| **Make Gradient** | Action | Builds a smooth two-colour ramp into a variable at runtime - a quick fire or sky gradient without opening the editor. |
| **Sample Gradient** | Expression | The colour at a 0-to-1 position along a gradient - a health-bar tint, a day/night sky, a heat map, from one line. |
| **Sample Curve** | Expression | A curve's value at a 0-to-1 position - turn a designer-drawn easing, falloff or difficulty curve into a number. |

For a gradient or curve with many stops, author it as a variable with the Gradient / Curve Inspector drawer and sample it here.

---

## Tips

- **World gravity moves rigid bodies, not character bodies.** A CharacterBody applies gravity in its own movement code, so a low-gravity power-up usually needs both the Physics Server action and the movement pack's gravity property.
- **Set Physics Active is not the same as pausing the tree.** It freezes the simulation while rendering and scripts keep running - which is exactly what a photo mode wants.
- **Bus effects must exist before you toggle them.** Add the effect to the bus in Godot's Audio panel first; **Set Bus Effect Enabled** flips a slot that is already there, by index.
- **The Rendering settings apply to the current viewport.** In a game with several viewports, apply the ones you care about where they matter.
- **Mesh verbs need a MeshInstance3D to draw onto.** They build the shape and assign it; they do not create the node for you.
