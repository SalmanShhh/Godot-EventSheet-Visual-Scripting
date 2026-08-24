# Lighting your game

A lit game is made of Godot's own light nodes, and nothing on a sheet changes that. There is no
lighting system here to learn: every lighting row IS the property or the call it names, every fact
on the sheet head is read out of the scene file you can open beside it, and a hand-written lighting
line you already have comes back byte for byte when the sheet saves.

This guide is the whole of it, in the order a game usually needs it: making a night, lighting it,
getting shadows to appear, making a flame move, running a clock over the day, the 3D atmosphere, and
slotting all of that into a project that is already lit.

## Contents

- [The five knobs, and what Godot calls them](#the-five-knobs-and-what-godot-calls-them)
- [Making a night: the darkness first](#making-a-night-the-darkness-first)
- [Lighting it: torches, lanterns, the moon](#lighting-it-torches-lanterns-the-moon)
- [Shadows that actually appear](#shadows-that-actually-appear)
- [A flame and a beacon: the two light behaviours](#a-flame-and-a-beacon-the-two-light-behaviours)
- [Day and night, on a clock](#day-and-night-on-a-clock)
- [3D: the World object](#3d-the-world-object)
- [Opening a project that is already lit](#opening-a-project-that-is-already-lit)
- [What the Doctor checks](#what-the-doctor-checks)
- [The traps](#the-traps)

## The five knobs, and what Godot calls them

A running game touches five things about a light: how bright, what colour, how far, on or off, and
shadows or not. Godot spells every one of them differently depending on which light you picked, so
the sheet says the word and the code echo shows the property that light really has.

| The word | 2D | 3D |
|----------|----|----|
| brightness | `energy` | `light_energy` |
| colour | `color` | `light_color` |
| reach | `texture_scale` (point light) | `omni_range` / `spot_range` |
| on / off | `enabled` | `visible` (a `Light3D` has no `enabled` at all) |
| shadows | `shadow_enabled` | `shadow_enabled` |

Pick a light off the picker's **Lights in this scene** shelf and the light lands in the object
column, where a reader looks for it: the row reads **Torch ▸ Set brightness to 1.2** and compiles to
`$Torch.energy = 1.2`. A spot light is offered a cone angle as well, and a directional light is
offered no reach at all, because those are the properties those classes really have.

The "On node" field on such a row is optional in the ordinary way: leave it blank and the row acts
on the node the sheet itself is attached to.

## Making a night: the darkness first

Darkening a 2D level in Godot is one node - a `CanvasModulate`, which multiplies everything on the
layer by its colour. Add one to your scene, call it `Level`, and the picker grows a **Darkness in
this scene** shelf aimed at it.

The row keeps the colour, because the colour is all Godot stores and all a re-save writes back. It
READS as the darkness it makes:

> **Level ▸ Set darkness to 81%, tinted #26304d**

The percentage is how much of the layer's light the tint takes away, measured with the engine's own
reckoning of how bright a colour is - so a green-ish gloom reads darker than a blue one of the same
numbers, which is what your eye says too.

```gdscript
extends Node2D


func _ready() -> void:
	$Level.color = Color("26304d")
```

**Fade Darkness** is the same value walked over time instead of jumped to, which is what dusk, a
cave mouth closing and a light going out all are:

```gdscript
extends Node2D


func fall_asleep() -> void:
	create_tween().tween_property($Level, "color", Color(0.1, 0.1, 0.15), 2.0)
```

## Lighting it: torches, lanterns, the moon

With the layer dark, the lights are what a player can see by. A 2D light needs a texture: a
`PointLight2D` lights the SHAPE of the texture it is given, so one with no texture is a node that is
switched on, costs a draw and shows nothing. A soft white radial gradient is the usual one.

```gdscript
extends Node2D


func _ready() -> void:
	$Torch.energy = 1.2
	$Torch.color = Color("ffd9a1")
	$Torch.texture_scale = 1.5
```

Each of those is a row: **Torch ▸ Set brightness to 1.2**, **Torch ▸ Set colour**, **Torch ▸ Set
reach to 1.5**. **Turn On** and **Turn Off** switch a light without hiding the node, **Is On** asks,
and **Fade to** walks the brightness somewhere over a number of seconds with one tween and no state
to keep:

```gdscript
extends Node2D


func blow_the_candle_out() -> void:
	create_tween().tween_property($Torch, "energy", 0.0, 0.5)
```

## Shadows that actually appear

Two things have to be true before Godot draws a 2D shadow, and only one of them is on the light:

1. the light casts them - **Torch ▸ Turn shadows on** (`shadow_enabled = true`);
2. something in the scene can block them - a `LightOccluder2D` whose `occluder_light_mask` shares a
   layer with the light's `shadow_item_cull_mask`.

Miss the second and nothing happens, silently, which is the single most common lighting question
there is. The sheet head answers it before you press play: an attached sheet wears a **shadows**
band saying how many occluders can really block the shadows it casts, and when none can, the band
says so instead of counting - *Candle casts shadows and no occluder's mask matches - shadows never
appear*.

The **lit by** band beside it names every light of the scene with the plain word for what kind it is
and whether it casts shadows. Both are read off the `.tscn` every time the sheet opens and stored
nowhere, so they cannot go stale in the file and they cost your game nothing.

Note the two 2D masks are different questions. `range_item_cull_mask` says which items the light
LIGHTS; `shadow_item_cull_mask` says which occluders can block it. Confusing them is how "the light
is right there and the room is black" happens.

## A flame and a beacon: the two light behaviours

Attach **Light Flicker** or **Light Pulse** under any light node, 2D or 3D. Each resolves which
property its host spells brightness with when it starts, so the same pack works under a
`PointLight2D` and an `OmniLight3D` without being told which it got.

**Light Flicker** walks the brightness on a noise field, which is what reads as fire rather than as
static. Its Inspector knobs: *Between* (the dimmest and brightest, `Vector2(0.8, 1.2)` is a candle),
*Times A Second* (about 12 reads as a torch), *Also Flicker Reach* (breathe the radius with the
brightness, which is what a real flame does) and *Running*.

**Light Pulse** rides a smooth cosine instead - a lighthouse, a pickup, a rune. Its knobs are
*Between*, *Period Seconds* (the length of one whole breath) and *Running*.

Both publish the same three words: **Start Flickering** (the row reads *Start flickering after
1.5 s*), **Stop Flickering** (*Stop flickering and settle at 0.6*) and **Is Flickering** - with
**Start Pulsing**, **Stop Pulsing** and **Is Pulsing** as the pulse's own trio. Stopping settles the
light at the brightness the row names, so a torch that goes out settles dark and one that is merely
calmed settles lit - and a flame that was flickering its reach puts the reach back to whatever the
scene was authored with, rather than leaving the radius of the frame it stopped on.

## Day and night, on a clock

The **Day/Night Cycle** pack is one clock with three curves. Attach it anywhere (a level root is
usual) and point it at the nodes it should drive: a sun light, and either a `WorldEnvironment` or a
`CanvasModulate` - so the same pack runs a 3D sky and a 2D level, and an unset target is simply
skipped.

Its Inspector holds *Day Length Minutes*, *Sunrise Hour*, *Sunset Hour*, *Time Of Day* (0-24,
settable while the game runs), *Clock Scale*, and three `Curve`s you draw: sun brightness, ambient
brightness and sky tint strength. The per-frame work is ordinary code - the sun's rotation comes
from the hour, the brightnesses from the curves. Only a `DirectionalLight3D` is turned: its rotation
is where the whole sky's light comes from, while a spot's rotation is where you aimed it, so a torch
pointed at a door keeps pointing at the door and only its brightness follows the day.

The sheet gets the moments and the controls: triggers **On Sunrise**, **On Sunset**, **On
Midnight** and **On The Hour** (which carries the hour it struck); actions **Set The Time**, **Run
The Clock Faster** (the row reads *Run the clock 4 times faster*), **Pause The Clock** and **Resume
The Clock**; conditions **It Is Night** and **It Is Day**; and the expression **Time Of Day** for any
value field.

A day that runs past midnight (a night shift, a polar summer) is stretched the same way as any
other, so noon is still overhead rather than wherever twelve o'clock happens to fall.

## 3D: the World object

A 3D scene's fog, glow and ambient light live on the `Environment` that a `WorldEnvironment` node
holds. Those rows sit on the picker's **Atmosphere in this scene** shelf and take that node as their
object, so the column reads **World** and the sentence reads the word:

```gdscript
extends Node3D


func enter_the_swamp() -> void:
	$World.environment.fog_enabled = true
	$World.environment.fog_density = 0.03
	$World.environment.ambient_light_energy = 0.15
```

That is **World ▸ Turn fog on**, **World ▸ Set fog thickness to 0.03**, **World ▸ Set ambient light
to 0.15**. **Fade The Glow** walks the glow's strength over time the way the light fades do.

One row there is worth knowing about before anything goes wrong. A `WorldEnvironment` usually points
at a `.tres` FILE, and a file is shared: writing fog at run time writes it for every other scene
that loads the same file, so the weather follows the player out of the room and is still there next
time the game runs. Godot's own answer is to take a copy first, and **Make The Environment This
Scene's Own** is the row that says it:

```gdscript
extends Node3D


func _ready() -> void:
	$World.environment = $World.environment.duplicate()
```

The sheet head's **environment** band names the resource file the scene loads and how many OTHER
scenes load the same one, which is where a reader finds out they need that row.

## Opening a project that is already lit

Most lit games are older than the sheet that opens them, so the lighting lines you already wrote
open as the rows they always were - and save back as the bytes you wrote, down to which spelling you
used for the node.

| What you wrote | What it opens as |
|----------------|------------------|
| `$Torch.energy = 1.2` | Torch ▸ Set brightness to 1.2 |
| `lamp.light_energy = 0.5` | lamp ▸ Set brightness to 0.5 |
| `$Torch.color = Color("ffd9a1")` | Torch ▸ Set colour |
| `get_node("Props/Lantern").texture_scale = 1.5` | Lantern ▸ Set reach to 1.5 |
| `$Flashlight.spot_range = 12.0` | Flashlight ▸ Set reach to 12.0 |
| `$Flashlight.spot_angle = 30.0` | Flashlight ▸ Set cone angle to 30.0 |
| `$Torch.enabled = false` / `$Bulb.visible = false` | Torch ▸ Turn off |
| `$Torch.shadow_enabled = true` | Torch ▸ Turn shadows on |
| `create_tween().tween_property($Lantern, "energy", 1.0, 0.5)` | Lantern ▸ Fade to 1.0 over 0.5 s |
| `$Level.color = Color(0.3, 0.3, 0.36)` | Level ▸ Set darkness to 70%, tinted #4d4d5c |
| `$World.environment.fog_density = 0.03` | World ▸ Set fog thickness to 0.03 |

`$Torch`, the variable you held the light in, and `get_node("Torch")` are three spellings of one
node, and each comes back exactly as you wrote it.

**The gate is the scene.** A line becomes a light row only when the scene your sheet is attached to
(or a typed declaration in the file itself) says the node it names really is a light. `.enabled =
false` is a sentence half the objects in a game can say, so `$Door.enabled = false` stays the script
block it is rather than being relabelled as somebody's torch. A node whose class cannot be
established keeps its line verbatim - the row never guesses, and you can always check the claim
against the scene in front of you.

## What the Doctor checks

Lighting fails without saying anything. The node is in the scene, the row runs, no error is printed,
and the screen does not change - so **Tools ▸ Project Doctor** has a **Lighting** section that knows
the five reasons, and every one of them is visible before the game is run once.

| The finding | What is actually wrong | What to do |
|-------------|------------------------|------------|
| *Torch has no texture, so it lights nothing* | A `PointLight2D` lights the shape of its texture and has none | Give it one - a soft white circle is the whole of a torch |
| *Candle casts shadows and no occluder's mask matches* | No `LightOccluder2D` shares a layer with the light's `shadow_item_cull_mask`, so no shadow is ever drawn | Add an occluder, or turn the shadows off and save the draw cost |
| *Level darkens the layer to 82% and no light reaches it* | No light's `range_item_cull_mask` reaches what is drawn on the layer | Add a light, or check the range masks of the ones there are |
| *… writes the world's environment, and this scene has no WorldEnvironment* | The row compiles, runs, and writes a property of nothing | Add a `WorldEnvironment` to the scene |
| *… writes an environment file another scene also uses* | An environment `.tres` is a FILE, so the fog you set follows the player into every scene that loads it | One click: **Make the environment this scene's own** |

The first three are facts of the `.tscn` and are found without a sheet at all, because a scene whose
lighting is broken is broken whether or not anybody wrote a row about it. The last two are about the
rows, so they also appear **in place** - an amber note under the event they are about, with the fix
as a button at its right edge.

The one repair that is a single step writes this row at the top of the sheet, on ready, because the
copy has to exist before anything else writes through it:

```gdscript
extends Node2D


func _ready() -> void:
	$World.environment = $World.environment.duplicate()
	$World.environment.fog_enabled = true
```

Nothing is stored and nothing is written while checking: each scene is read as text, measured and
dropped. A project with no lighting in it reports nothing at all.

## The traps

- **A 3D light has no `enabled`.** `Light3D` switches with `visible`. One word - Turn On - covers
  both dimensions on the sheet, and the code echo shows which property your light really answers to.
- **A `PointLight2D` with no texture lights nothing.** It is switched on, it costs a draw, and the
  room stays black. Give it a soft radial gradient.
- **Shadows need an occluder whose mask matches.** Turning shadows on is half the job; the sheet
  head's **shadows** band says whether the other half is done.
- **A shared environment `.tres` follows the player.** Take a copy first with Make The Environment
  This Scene's Own, or every scene that loads the file gets the weather you set at run time.
- **Reach is three different properties.** `texture_scale` scales a 2D point light's texture,
  `omni_range` and `spot_range` are metres. A directional light reaches everywhere and has no reach
  row at all.
- **The darkness percentage is a reading, not the value.** The row holds the colour, which is what
  the file keeps and what a re-save writes; the percentage is how it reads.
