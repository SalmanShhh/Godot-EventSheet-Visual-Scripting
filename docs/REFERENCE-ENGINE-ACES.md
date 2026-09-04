# Engine-Level ACEs

Most of the picker talks to a **node** you placed: move this sprite, play that sound, check this body. This page collects the vocabulary that talks to the **engine itself** - the rendering server, the physics world, the audio mixer - plus the rows that build 3D content at runtime. These are the rows behind a graphics options menu, a low-gravity power-up, an underwater audio filter, or a block you spawn from nothing.

Everything here is a builtin ACE, so it is in the picker of every sheet with no addon to install. Each section names the picker category to look under.

## Table of Contents

1. [Graphics settings (Rendering)](#graphics-settings-rendering)
2. [The physics world (Physics Server)](#the-physics-world-physics-server)
3. [Audio mixing (Audio Server)](#audio-mixing-audio-server)
4. [Meshes at runtime (Mesh)](#meshes-at-runtime-mesh)
5. [Camera field of view (Camera)](#camera-field-of-view-camera)
6. [Animation playback (Animation)](#animation-playback-animation)
7. [Text that moves (Text)](#text-that-moves-text)
8. [Gradients and curves](#gradients-and-curves)
9. [Clipping a node's children (Blend Modes)](#clipping-a-nodes-children-blend-modes)

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
| **Set Temporal AA** | `enabled` | Borrows detail from the frames before this one: sharper than FXAA on a still image, and it can shimmer while the camera moves. |
| **Set 3D Resolution Scale** | `scale` | Renders the 3D scene at a fraction of window resolution and upscales - the classic performance slider. |
| **Upscale With** | `method` | How a 3D scene rendered smaller than the window is stretched back up: bilinear (plain and cheapest), FSR, or FSR 2. |
| **Render 3D At** | `percent`, `method` | The two above as one question: render the 3D scene at a percentage of the window and say how it is upscaled. 2D drawing and the interface are untouched. |
| **Smooth Edges With** | `how` | The one antialiasing switch a graphics menu needs: nothing / FXAA / temporal / 2, 4 or 8 samples. Every technique the chosen word is not is turned off, so nobody pays for two at once. |
| **Scale The Game** | `mode` | What gets stretched when the window is not the size the game was drawn for: fit the layout (text stays crisp), stretch the whole picture (what pixel art wants), or free. |
| **Fit The Shape** | `aspect` | What the extra space becomes when the window is a different SHAPE: bars at the edges, fill and distort, keep the width, keep the height, or expand. |
| **Keep Pixels Sharp** | `stretch` | Whether the scale may be a fraction. Whole numbers only trades the uneven pixel-art shimmer for bars at the edges. |
| **Pixel Size** | `factor` | How big one drawn pixel is on top of everything else - the accessibility answer for a small interface, and the zoom answer for pixel art on a big monitor. |
| **Set Debug Draw Mode** | `mode` | Switches the viewport to a diagnostic view (wireframe, overdraw heat, unshaded) and back. |
| **Set Occlusion Culling** | `enabled` | Big scenes skip drawing what walls already hide. |
| **Set Debanding** | `enabled` | Removes the visible stripes in smooth dark gradients, for a tiny cost. |

### Conditions and expressions

| Name | Kind | Gives you |
| --- | --- | --- |
| **Uses Modern Renderer** | Condition | True on Forward+ / Mobile, false on Compatibility (old GPUs, web) - gate fancy effects on it. |
| **Renderer Is** | Condition | Which of Godot's three the game is running on. Screen-space reflections, indirect light, global illumination and volumetric fog are Forward+ only, and Mobile answers yes to the row above while drawing none of them. |
| **Draw Calls (frame)** | Expression | Draw calls issued this frame. |
| **Objects Drawn (frame)** | Expression | Objects drawn this frame. |
| **Primitives Drawn (frame)** | Expression | Primitives (triangles) drawn this frame. |
| **Video Memory Used** | Expression | Video memory currently in use. |
| **Global Shader Parameter** | Expression | The current value of a global shader uniform. |
| **Clear Color** | Expression | The current background colour. |

A quality dropdown is then four rows:

```
On quality changed to "Low"
  -> Smooth Edges With        "Nothing - hard edges, cheapest"
  -> Render 3D At             70, "FSR - sharper, still cheap"
  -> Set Occlusion Culling    true
  -> Set Debanding            false
```

The per-technique rows above (Set MSAA, Set Screen-Space AA, Set Temporal AA, Set 3D Resolution
Scale, Upscale With) are still the right rows for a menu that offers the switches separately; the
two combined rows are for the menu that asks one question per line.

The four content-scale rows are a different job: they are how the game meets a screen it was not
drawn for, rather than how much work it does drawing it. A file that keeps pixels sharp and then
asks for a fractional pixel size gets an info note in the Doctor's Ship It section, because whole
pixels only rounds the scale down. The whole story, with the camera and the views beside it, is in
[Cameras, Views and How The Game Fills The Screen](GUIDE-CAMERAS-AND-VIEWPORTS.md).

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

Picker category: **Audio Server**. Buses are set up in Godot's Audio panel; these rows drive them at runtime. This is the options-menu volume story and the "everything sounds muffled underwater" trick.

| Name | Kind | What it does |
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

| Name | Kind | Parameters |
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

| Name | Kind | What it does |
| --- | --- | --- |
| **Tween Camera FOV** | Action | Smoothly eases the active 3D camera's FOV to a target over a duration. Clamped to the legal range. |
| **Adjust Camera FOV** | Action | Nudges a camera's FOV by a relative amount, clamped so repeated zooms can never flip the camera inside-out. |
| **Camera FOV** | Expression | A camera's current field of view in degrees - for a HUD zoom indicator or a dynamic-FOV rig. |

The rest of the Camera shelf talks to a `Camera2D` or a `Camera3D` you placed rather than to the
engine, so it lives with the rest of that story in
[Cameras, Views and How The Game Fills The Screen](GUIDE-CAMERAS-AND-VIEWPORTS.md): the dead zone,
the snap, the view rectangle, the level's own edges, the timed look-at, the projections and the
clip range.

---

## Animation playback (Animation)

Picker category: **Animation**. Beyond Play and Stop, these drive an `AnimationPlayer` precisely - scrubbing, queueing, and reading where the play head is.

| Name | Kind | What it does |
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

The same category also holds the blend-tree rows, the bone rows and the auto-finding "in object" actions (Play Animation, Flip Sprite, Set Sprite Frame) that locate a node's AnimationPlayer or AnimatedSprite2D for you.

An `AnimationTree` is driven by writing into, and reading out of, four parameter paths - `parameters/playback` for the state machine, `parameters/<space>/blend_position` for a blend space, `parameters/<layer>/blend_amount` for a Blend2 or Add2, and `parameters/conditions/<name>` for the booleans a transition advances on. The rows assemble those strings from fields that list the tree's own names, read off the scene.

| Name | Kind | What it does |
| --- | --- | --- |
| **Travel To State** | Action | Walks the state machine to a state through the transitions it was drawn with. |
| **Jump To** | Action | Starts a state at once, ignoring every transition between here and there - a respawn or a cutscene cut. |
| **Current State Is** | Condition | True while the machine is in the named state. |
| **Is In Any State** | Condition | True while it is in any of several - the attack that may start from a stand or a run. |
| **Set Blend Position** | Action | Moves where a blend space is sampled: a number for a one-dimensional space, a Vector2 for a two-dimensional one. |
| **Blend Toward** | Action | The same move taken over seconds, as a tween on the tree's own parameter. |
| **Blend Layer** | Action | Fades a Blend2 or Add2 in or out over seconds - the aim pose that arrives when a target is locked. |
| **Set Condition** | Action | Writes one of the booleans the transitions advance on. The tree decides when to move; the row only says what is true. |
| **Set Tree Time Scale** | Action | Slows or speeds everything under one TimeScale node, without touching the game's own clock. |
| **Time In State** | Expression | How many seconds the machine has been playing its current state. |
| **On State Entered** | Trigger | The moment the machine enters a state. The signal is on the playback object, not the tree node, so the connection reaches through `parameters/playback`. |
| **On State Left** | Trigger | The moment the state it was in finishes. |
| **Apply Root Motion** | Action | Hands the animation's own step to a CharacterBody2D or CharacterBody3D, divided by the frame time because a velocity is a distance per second. |
| **Point Bone At** | Action | Aims one bone at a node and keeps aiming - through the engine's own LookAtModifier3D in 3D, and on a Bone2D in 2D. |
| **Bone Position** | Expression | Where a bone is in the world, with the skeleton-space pose multiplied back out. |
| **Set Bone Pose Override** | Action | Holds a bone in a pose of your own, with a strength, over whatever the animation is playing. |

---

## Text that moves (Text)

Picker category: **Text**, on a `RichTextLabel` - only that node parses BBCode and only it counts characters, so a plain `Label` is deliberately not offered these rows. The engine already knows six moving tags - `wave`, `shake`, `tornado`, `rainbow`, `fade` and `pulse` - plus a seventh door, `install_effect`, for a `RichTextEffect` you wrote yourself. These rows write those tags, so the emitted line is the line you would have typed by hand and the label needs nothing installed.

| Name | Kind | What it does |
| --- | --- | --- |
| **Set Text With Effect** | Action | Puts words on the label already wearing one of the seven effects - a title that waves, a warning that shakes, a legendary drop in a rainbow. |
| **Wrap Selection In Effect** | Action | Puts an effect around a stretch of the text already there, counted in characters - one word shaking inside a calm sentence. |
| **Clear Effects** | Action | Takes every effect back off and leaves the words, by asking the label for its own parsed text - so it clears tags nobody here wrote as well, with no list of names to keep up to date. |
| **Effect Is Active** | Condition | True while the label's text carries that effect's tag - ask before writing another one, or to tell a shaking warning from a calm one with no variable beside it. |
| **Install Text Effect** | Action | Teaches this label one `RichTextEffect` of your own, out of a folder you own, whose bbcode name the "custom" choice then writes. |
| **Reveal Text** | Action | Types a line out at so many characters a second, with a sound on each character when you name a player. A second reveal on the same label ends the first. |
| **Skip Reveal** | Action | Shows the whole line now and finishes exactly as a reveal that ran out would - the second press of the button that started it. |
| **Pause Reveal At** | Action | Holds the reveal for a beat at one character: the comma pause that makes a typed line sound like speech. Drop it before the Reveal Text row, which reads it. |
| **Is Revealing** | Condition | True while a line is still typing itself out - which is how one button skips while it is, and goes on to the next line when it is not. |
| **Revealed Fraction** | Expression | How much of the line is showing, from 0 to 1 - a progress bar, a portrait's mouth flap, a sound that quietens as the line ends. |
| **On Reveal Finished** | Trigger | The moment the last character lands. Skip Reveal ends here too, which is what lets the Continue prompt be written once. |

Each effect fills its OWN knob - `amp` for a wave, `level` for a shake, `radius` for a tornado, `freq` for a rainbow or a pulse, `length` for a fade - because the parser accepts an `amp` written into a shake and then does nothing with it. One Strength field on the row is spelled into whichever knob the chosen effect reads.

**Both accessibility settings are read at the moment the row runs**, so neither needs a row of its own. The text-size scale multiplies an effect's own knob, so an effect grows with the text it is drawn on rather than staying the size it was designed at. Reduce Flashing drops a shake to a third of its strength - a drift rather than a rattle - and takes the two colour-cycling effects, rainbow and pulse, to a frequency of zero, which is the engine's own way of spelling "hold still".

A dialogue system that already types its own lines keeps doing so: these rows are for every other label - a title card, a tutorial hint, a shop description, a boss name.

---

## Gradients and curves

Picker category: **Gradients & Curves**. Turn a designer-drawn ramp or curve into a colour or a number, with no maths in the sheet.

| Name | Kind | What it does |
| --- | --- | --- |
| **Make Gradient** | Action | Builds a smooth two-colour ramp into a variable at runtime - a quick fire or sky gradient without opening the editor. |
| **Sample Gradient** | Expression | The colour at a 0-to-1 position along a gradient - a health-bar tint, a day/night sky, a heat map, from one line. |
| **Sample Curve** | Expression | A curve's value at a 0-to-1 position - turn a designer-drawn easing, falloff or difficulty curve into a number. |

For a gradient or curve with many stops, author it as a Gradient variable (Godot's own ramp editor opens in the Inspector) or a Curve variable with the Curve drawer, and sample it here.

---

## Clipping a node's children (Blend Modes)

Picker category: **Blend Modes**, shared with the Blend Modes pack's own verbs, because clipping, masking and blending are one reader's question: how do two pictures meet. These two rows need nothing installed - `clip_children` is a field on every `CanvasItem`, and setting it costs nothing at all.

Whatever the node draws becomes the SHAPE its children are allowed to draw inside: a portrait cut to its frame, a bar that fills a heart rather than a rectangle, water that stops at the edge of the pool.

| Name | Parameters | What it does |
| --- | --- | --- |
| **Clip My Children** | `mode` (draw me too / clip only) | Makes what this node draws the shape its children draw inside. Choose whether the node is drawn as well as being the shape (a frame you can see) or is only the shape (an invisible cutter). |
| **Stop Clipping** | - | Puts the node back to drawing normally: its children draw wherever they like again. |

Two rows and not one, because the field has three values and a reader means only two of them. **Stop Clipping** owns the disabled value alone, so no written line can be spelled by both rows - which is what makes an opened file read back as the row that wrote it.

The rest of that shelf - twenty blend modes, masks, and a node's children merged into one picture - comes from the Blend Modes pack rather than from the engine, because fifteen of the twenty modes need a shader that reads the screen back.

---

## Tips

- **World gravity moves rigid bodies, not character bodies.** A CharacterBody applies gravity in its own movement code, so a low-gravity power-up usually needs both the Physics Server action and the movement pack's gravity property.
- **Set Physics Active is not the same as pausing the tree.** It freezes the simulation while rendering and scripts keep running - which is exactly what a photo mode wants.
- **Bus effects must exist before you toggle them.** Add the effect to the bus in Godot's Audio panel first; **Set Bus Effect Enabled** flips a slot that is already there, by index.
- **The Rendering settings apply to the current viewport.** In a game with several viewports, apply the ones you care about where they matter.
- **The Mesh actions need a MeshInstance3D to draw onto.** They build the shape and assign it; they do not create the node for you.
- **A label draws a tag as characters until BBCode is on.** `bbcode_enabled` starts false, which is why every row that writes a text effect switches it on in the line above - two statements rather than one.
