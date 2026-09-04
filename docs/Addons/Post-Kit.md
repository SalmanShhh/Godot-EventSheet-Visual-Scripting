# Post Kit - The Camera's Own Post Stack

Godot 4 gives a 3D camera a **Compositor**, and a Compositor a list of **CompositorEffects**:
scripts handed the frame after it has been drawn, free to do anything to it. It is the right
seam and almost nobody reaches it, because reaching it means a compute shader, a rendering
device, a uniform set and a dispatch before a game gets its first vignette.

This pack is those effects, as rows. Five of them wear the **same words the 2D post stack
uses** (vignette, desaturate, pixelate, tint, fade), so a row reads alike whether it is on the
screen or on the camera. Plus the one thing only a 3D camera can do: an **outline drawn
through walls**.

## Forward+ only, and what to use instead

Only the Forward+ renderer has a Compositor at all. On Mobile and on Compatibility every row
here **does nothing**: no error, no warning in the player's face, no frame drawn differently.
That is deliberate, and the ship-it check in the Doctor names it once for you, with the door:

> `level.gd` asks for a camera post effect (the Screen FX and Blend Modes packs do the same
> looks on any renderer), which only the Forward+ renderer draws.

So if your project ships on Mobile or Compatibility, reach for **Screen FX** (the same five
words, on a full-screen rectangle) and **Blend Modes** instead. If it ships on Forward+, this
pack is cheaper than either, because the frame is already on the GPU when the effect runs.

## Where this pack shines

- **A hit that reads as a hit.** `Pulse Post Effect: vignette, 0.6, 0.35` is the whole
  sentence, in one row, with nothing to tune.
- **A world losing interest in itself.** `Fade Post Strength: desaturate` walks the colour out
  as the health goes.
- **The enemy behind the crate.** `Outline Group Through Walls: enemies` and they are visible
  through the level, in one row.
- **A look that is a stack, not a setting.** Effects are named, ordered, turned on and off, and
  faded independently.

## Setup

1. Add the **Post Kit** behavior under the `Camera3D` you want to decorate. (A
   `WorldEnvironment` works too, and covers every camera in the scene.)
2. Drop an **Add Post Effect** row. It opens on `vignette` at `0.6`, so it is already a
   sentence.
3. That is the whole setup. The Compositor arrives with the first row that needs one, and the
   outline's mask rig with the first row that outlines something.

```
On start of layout -> Camera3D | Add Post Effect: vignette, "", 0.5
On Player Hurt     -> Camera3D | Pulse Post Effect: tint, 0.7, 0.4
```

## The five words, and what each one does

| Word | What it does | Its own dials |
|---|---|---|
| `vignette` | Shades the frame towards a colour as it nears the corners. | `shade`, `inner_edge` |
| `desaturate` | Drains the colour out. Full strength is black and white. | - |
| `pixelate` | Draws the frame in blocks instead of pixels. | `block_pixels` |
| `tint` | Multiplies every colour by one colour, keeping the shading. | `tint`, `gain` |
| `fade` | Mixes the whole frame towards one flat colour. | `to_colour` |

The dials are fields on the effect resource in `eventsheet_addons/post_kit/effects/`. A row
turns **strength**; a project that wants a red vignette rather than a black one drops
`post_vignette.gd` straight onto a Compositor in the Inspector and sets `shade` there. Nothing
in this pack is a fixed house style: the effects are ordinary resources you own.

## What it costs

- **One pass over the frame, per effect that is on.** A compute shader reads and writes every
  pixel the camera drew. Two or three is a look; ten is a bill.
- **Zero when the stack is empty.** No effects means no Compositor entries, which means the
  renderer does exactly what it did before the pack was installed.
- **An outline costs a second render** of the marked meshes and nothing else, into a viewport
  the size of the frame. It is built the first time something is outlined and freed by **Stop
  Outlining**, so a project that never outlines anything never pays for it.
- **`Is Hidden From View` costs one ray** from the camera to the node's origin.

## How the outline sees through walls

1. The row switches the pack's **mask layer** (visual layer 20 by default, the last one Godot
   has and the one a project is least likely to be using) on for every visual instance at or
   under what you named.
2. A second camera, which can see that layer **and nothing else**, draws them into a viewport
   with a transparent background. Nothing else in the level is on that layer, so nothing else
   is in the mask, and nothing can stand in front of them there.
3. A compute shader finds the edge of that mask and draws it over the finished frame.

That is the whole of "through walls": the outline never asked what was in the way. **Stop
Outlining** switches the layer bit off again on exactly the instances it switched on, so the
layers your project was already using are left alone.

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, node
references in *italic*, exactly as the rows draw them:

- Pulse **vignette** at **0.6** for **0.35** s
- Outline group **enemies** through walls in **yellow**
- Silhouette *Objective* through walls in **yellow**

### Actions

| Action | Parameters | Description |
|---|---|---|
| Add Post Effect | `effect`, `called`, `strength` | Adds one effect to the end of the camera's post stack and turns it on. Leave the name empty and the entry is called after its effect. |
| Remove Post Effect | `called` | Takes one effect off the stack, so it stops costing anything at all. |
| Enable Post Effect | `called` | Turns one effect back on without forgetting how far up it was. |
| Disable Post Effect | `called` | Turns one effect off and leaves it in the stack, so enabling it again brings back the same strength. |
| Set Post Strength | `called`, `strength` | Sets how far one effect goes, straight away. |
| Set Post Dial | `called`, `dial`, `value` | Sets one of that effect's OWN dials - the tint's colour, the vignette's softness, the pixelate's block size. The careful control, one dropdown deeper than strength. A dial the effect does not declare is refused with a warning rather than set on nothing. |
| Fade Post Strength | `called`, `to`, `seconds` | Walks one effect's strength to a value over a number of seconds. |
| Pulse Post Effect | `effect`, `strength`, `seconds` | Flashes one effect up and lets it fall back. An effect that was not on the stack is borrowed and taken off again at the end. |
| Outline Group Through Walls | `group`, `colour`, `width`, `seconds` | Draws an outline around every node in a group, through whatever is in front of them. 0 seconds leaves it on until Stop Outlining. |
| Silhouette Node Through Walls | `node`, `colour`, `seconds` | Fills one node in a flat colour, through whatever is in front of it. |
| Stop Outlining | (none) | Ends every outline and silhouette at once and frees the mask rig. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Has Post Effect | `called` | True while an effect by that name is on the stack at all, on or off. |
| Is Outlined | `node` | True while a node is one of the ones being drawn through walls. |
| Is Hidden From View | `node` | True while something solid stands between the camera and the node's own origin. |

### Expressions

| Expression | Parameters | Description |
|---|---|---|
| Post Strength | `called` | How far one effect is going right now, after the accessibility dials have had their say. 0 for one that is not there. |
| Post Dial | `called`, `dial` | What one of that effect's own dials holds - the other half of Set Post Dial, for a row that nudges a value rather than naming one. |

## Use cases

### 1. A hit that reads as a hit

```
On Player Hurt -> Camera3D | Pulse Post Effect: vignette, 0.6, 0.35
```

One row, no setup, nothing to tune. The vignette snaps closed and falls open again over a
third of a second, which is what a hit feels like.

### 2. A world draining as the health goes

```
On Health Changed -> Camera3D | Add Post Effect: desaturate, "hurt", 0.0
On Health Changed -> Camera3D | Set Post Strength: hurt, 1.0 - Health Percent
```

The colour leaves the world in step with the health bar. At full health the effect is at 0,
which draws the frame back exactly as it arrived.

### 3. The enemies behind the wall

```
On Ability Used -> Camera3D | Outline Group Through Walls: enemies, yellow, 2.0, 4.0
```

Every node in the `enemies` group gets an outline that ignores the level geometry, and it
takes itself off again after four seconds.

### 4. A quest objective you can always find

```
On Quest Started -> Camera3D | Silhouette Node Through Walls: Objective, cyan, 0.0
On Quest Ended   -> Camera3D | Stop Outlining
```

A silhouette rather than an outline, because the question here is where the thing is rather
than what shape it is.

### 5. Only outline what is actually hidden

```
Is Hidden From View: Teammate -> Camera3D | Silhouette Node Through Walls: Teammate, green, 0.2
```

The condition asks whether anything is in the way; a teammate in plain sight is left alone, so
the highlight only appears when it is doing something.

### 6. A death that is not a fade to black

```
On Died -> Camera3D | Add Post Effect: desaturate, "", 0.0
On Died -> Camera3D | Fade Post Strength: desaturate, 1.0, 1.5
On Died -> Camera3D | Fade Post Strength: vignette, 1.0, 1.5
```

The colour and the light leave together over a second and a half. Two words, no cutscene.

### 7. A teleport coming apart

```
On Teleport Started -> Camera3D | Pulse Post Effect: pixelate, 1.0, 0.5
```

The frame breaks into blocks and reassembles itself. The pulse borrows the effect for the
moment and takes it off again, so nothing is left on the stack.

### 8. A cold night and a warm afternoon

```
On Night Fell   -> Camera3D | Add Post Effect: tint, "hour", 0.8
On Dawn Broke   -> Camera3D | Set Post Strength: hour, 0.0
```

One named entry, turned up and down, rather than two effects fighting over the same frame.

### 9. A scene change you can wait on

```
On Exit Reached -> Camera3D | Fade Post Strength: fade, 1.0, 0.6
On Exit Reached -> Wait 0.6 seconds
On Exit Reached -> Go To Scene: res://levels/two.tscn
```

The `fade` word lands on a flat colour, and the rows under the wait are what happens behind it.

### 10. A pause menu that softens the world

```
On Paused   -> Camera3D | Add Post Effect: desaturate, "paused", 0.7
On Resumed  -> Camera3D | Remove Post Effect: paused
```

Removing rather than disabling, because a paused game is not going to want that entry back at
the strength it had.

### 11. A poison that never quite leaves

```
On Poisoned -> Camera3D | Add Post Effect: tint, "poison", 0.35
On Cured    -> Camera3D | Fade Post Strength: poison, 0.0, 2.0
On Cured    -> Camera3D | Remove Post Effect: poison
```

Named entries are how two statuses stack without either knowing about the other.

### 12. Do not add the same effect twice

```
Has Post Effect: hurt (inverted) -> Camera3D | Add Post Effect: vignette, "hurt", 0.4
```

The condition reads the same record the action wrote, so the guard is one row and no variable.

### 13. A scanner sweep that finds everything

```
On Scan Fired -> Camera3D | Outline Group Through Walls: pickups, cyan, 3.0, 2.0
On Scan Fired -> Camera3D | Pulse Post Effect: tint, 0.4, 2.0
```

The outline and the tint share the same two seconds, so the sweep is one moment rather than
two effects that happen to overlap.

### 14. A boss phase you can feel

```
On Phase Two -> Camera3D | Add Post Effect: tint, "rage", 0.0
On Phase Two -> Camera3D | Fade Post Strength: rage, 0.6, 1.2
```

The room heats over a second and a bit instead of switching colour on a frame.

### 15. Turn the whole look off for a low-end machine

```
On Quality Lowered -> Camera3D | Disable Post Effect: vignette
On Quality Lowered -> Camera3D | Disable Post Effect: hurt
```

Disabled entries keep their strengths, so **Enable Post Effect** puts the look back exactly as
it was when the player turns the quality up again.

### 16. Read the strength back into a sound

```
Every tick -> AudioStreamPlayer | Set volume_db: -30.0 * Post Strength("hurt")
```

The expression answers with what the camera is actually drawing, after the accessibility dials
have had their say, so the sound follows the picture rather than the row's request.

### 17. A photo mode with no effects at all

```
On Photo Mode -> Camera3D | Remove Post Effect: vignette
On Photo Mode -> Camera3D | Stop Outlining
```

Two rows and the camera is drawing exactly what the renderer drew before the pack was
installed.

### 18. A stealth game where the guards glow when they see you

```
On Alerted   -> Camera3D | Outline Group Through Walls: guards, red, 3.0, 0.0
On Calmed    -> Camera3D | Stop Outlining
```

0 seconds means the outline stays until something takes it off, which is what a state wants
rather than a moment.

### Other use cases

**A drunk or concussed camera.** `pixelate` at a low strength, faded up and down, reads as the
world refusing to resolve.

**A dream or a flashback.** `desaturate` at 0.6 with a warm `tint` over it is a memory, and it
is two rows.

**An underwater section.** A blue `tint` at 0.5 plus a `vignette` closes the world in without
touching a single material.

**A camera that is a security monitor.** `desaturate` at 1.0 and `pixelate` at 0.3 on the
second camera makes the feed look like a feed.

**A hit that a photosensitive player can still play.** Nothing to do: every row here already
obeys the project's No Flashing and Effect Strength settings.

## Accessibility, without a row for it

Every row in this pack reads the two answers the project already keeps:

- **Effect Strength** scales every strength on the way in, so a player at 50% gets half of
  everything.
- **No Flashing** holds the amplitude under a ceiling and the time over a floor, so a pulse
  still pulses and a look still lands, but nothing this pack draws can strobe.

Those are the same two settings the built-in **Set No Flashing** and **Set Effect Strength**
rows write. A game that has those rows needs nothing else.

## Tips and common mistakes

- **Nothing happens on Mobile or Compatibility.** That is not a bug and it is not silent: the
  pack says so once in the output, and the ship-it check in the Doctor names the file. Use
  Screen FX there.
- **Attach it under the node that carries the Compositor.** A `Camera3D` decorates that camera;
  a `WorldEnvironment` decorates every camera in the scene. Under anything else the pack says
  what it expected and does nothing.
- **A name is how two rows mean the same entry.** Leave `called` empty and the entry is named
  after its effect, which is what one of each wants. Two vignettes need two names.
- **Order is the order they were added.** The first entry works on the frame first and the last
  one has the last word, which is why a `fade` added last covers everything under it.
- **Strength is not opacity.** It is how far the effect goes. A `pixelate` at 0.5 is still the
  whole frame, in blocks half the size.
- **An outline needs a mesh.** The row marks visual instances, so a group of bare `Node3D`s
  with no mesh under them outlines nothing, and says so.
- **Layer 20 is the pack's, by default.** If your project is already using it, change the
  behavior's **Mask Layer** in the Inspector and the rows follow.
- **`Is Hidden From View` is one ray, not a visibility test.** A body whose middle is visible
  past the corner of a wall reads as seen. That is a cheap question with an honest answer.

## Already written it by hand? It reads as this pack

A `Compositor` you built yourself in the Inspector goes on working exactly as it did: this
pack adds to whatever the camera already had rather than replacing it. And the effect scripts
are ordinary files, so `post_vignette.gd` dragged onto a Compositor in the Inspector is the
same vignette a row adds, with its dials open in front of you.
