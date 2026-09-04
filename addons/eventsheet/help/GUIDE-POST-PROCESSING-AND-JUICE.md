# Post-Processing and Juice: Making It Feel Like Something

A game that reads well and plays well can still feel like nothing. What is missing is almost never
one big feature: it is a hit that kicks the screen, a glow that actually glows, corners that darken
when the health is low, a scene change that is a shape rather than a cut.

Every one of those is cheap to describe and expensive to build. A glow needs a shader that reads
the frame back. A hit needs four effects fired in step. A vignette needs a CanvasLayer, a ColorRect,
a shader and a uniform. That is why most projects never get any of it.

This page is the whole of that corner of the vocabulary, and it is built to one rule.

## The jam rule

**Three keystrokes, and no tuning.** Every effect on this page has a one-row form that works the
moment it is dropped:

- a **pulse** is the default sentence - one word, one strength, one time, and it puts itself back;
- a **moment** is one word - `impact`, `kill`, `triumph` - and it is a whole beat of feedback;
- a **look** is one row - a whole screen, saved as a file, worn again anywhere;
- a **blend** is one row - a mode by the name your drawing tool already gives it.

The careful controls are all there, and they all sit one dropdown deeper: add, remove, enable,
disable, order, fade, blend. Reach for them when the pulse is not enough. Do not start there.

**The search box knows what you would actually type.** Nobody types "post effect" or "compositor" or
"moment". They type the thing they saw or the thing that just happened: *vignette*, *grain*,
*glitch*, *letterbox*, *hit*, *boom*, *win*, *danger*, *wipe*, *iris*, *page curl*, *x ray*, *see
through*, *additive*, *stain*, *cut out*. All of those land on the row that does it, and the row's
own field shows the rest of the list from there.

## Table of Contents

1. [The one-row forms, in full](#the-one-row-forms-in-full)
2. [How two pictures meet: blending](#how-two-pictures-meet-blending)
3. [Masks, and a node's children drawn inside its own shape](#masks-and-a-nodes-children-drawn-inside-its-own-shape)
4. [The post stack: the whole screen as a named list](#the-post-stack-the-whole-screen-as-a-named-list)
5. [Post under the HUD, or over it](#post-under-the-hud-or-over-it)
6. [Colour vision, and the flashing setting that already exists](#colour-vision-and-the-flashing-setting-that-already-exists)
7. [A look is a file you own](#a-look-is-a-file-you-own)
8. [A moment is a beat written down](#a-moment-is-a-beat-written-down)
9. [Transitions: a shape drawn over the change](#transitions-a-shape-drawn-over-the-change)
10. [The Post Kit: the same words on a 3D camera](#the-post-kit-the-same-words-on-a-3d-camera)
11. [What each renderer can actually do](#what-each-renderer-can-actually-do)
12. [What a project you already wrote opens as](#what-a-project-you-already-wrote-opens-as)
13. [Tips and common mistakes](#tips-and-common-mistakes)

---

## The one-row forms, in full

Five rows. Learn these and the rest of the page is optional.

| The row | What it does | The pack |
|---|---|---|
| **Pulse Post Effect** `glitch` `0.8` `0.25` | Flashes one full-screen effect up and lets it fall back. Borrows an entry if the stack has none, and gives it back. | Screen FX |
| **Moment** `impact` `1.0` | Plays a whole beat of feedback: the shake, the freeze, the colour split and the darkened edges together. | Juice |
| **Blend As** `self` `screen` `1.0` | The item stops being a sticker and starts being light. | Blend Modes |
| **Go To Scene With** `res://level_2.tscn` `iris` `0.8` | Changes the scene with a shape drawn over the change. | Scene Flow |
| **Use Look** `res://looks/night.tres` | Wears a whole screen you saved earlier. | Screen FX |

<!-- caption: The five one-row forms as one sheet -->
```
On Enemy Hit          ->  Enemy | Moment: "impact", 1.0
On Big Attack Landed  ->  ScreenFx | Pulse Post Effect: glitch, 0.8, 0.25
On Fired              ->  Muzzle | Blend As: self, screen, 1.0
On Exit Reached       ->  Level | Go To Scene With: "res://level_2.tscn", iris, 0.8, smooth
On Night Fell         ->  ScreenFx | Use Look: res://looks/night.tres
```

Which compiles to five ordinary lines:

<!-- caption: The same five rows, as the GDScript they emit -->
```gdscript
$JuiceBehavior.moment("impact", 1.0)
$ScreenFx.pulse_post_effect("glitch", 0.8, 0.25)
BlendModes.blend_as(self, "screen", 1.0)
$SceneFlowBehavior.go_to_scene_with("res://level_2.tscn", "iris", 0.8, "smooth")
$ScreenFx.use_look(preload("res://looks/night.tres"))
```

**The trap this removes.** The usual first attempt at juice is a `_process` that counts a timer down
and lerps four values, written once per effect and again per place the effect can fire. Every one of
those loops is a bug that only appears when two of them overlap. A pulse and a moment are
self-limiting: they know where they started, they know where to stop, and two of them at once is one
answer rather than a fight.

---

## How two pictures meet: blending

Godot draws **five** blend modes by itself. They are a field on a `CanvasItemMaterial`, and a sprite
set to one of them costs exactly what a sprite costs: normal, add, subtract, multiply,
premultiplied alpha.

Every drawing tool on earth has **fifteen more** - screen, overlay, darken, lighten, colour dodge,
colour burn, hard light, soft light, difference, exclusion, hue, saturation, colour, luminosity, and
a plain copy - and Godot has no field for any of them, because they need the pixels already on the
screen. The item has to read them back and do the arithmetic itself. That is a shader per mode, and
writing one is where the idea usually stops.

The **Blend Modes** pack ships them: fifteen shader files, one per mode, each with one strength dial.

<!-- caption: Twenty modes as one row, and the fade that takes it away -->
```
On Fired  ->  Muzzle | Blend As: self, screen, 1.0
          ->  Muzzle | Fade Blend Strength: self, 0.0, 0.12
```

```gdscript
BlendModes.blend_as(self, "screen", 1.0)
BlendModes.fade_blend_strength(self, 0.0, 0.12)
```

**Pick it by looking at it.** A blend mode is the one parameter in the whole vocabulary whose words
do not tell a reader what they will get - "overlay", "hard light" and "luminosity" are names from a
trade. So the field shows them: one shape over one backdrop, drawn through every mode, in five
groups. The button wears the picture of whatever the box currently says. Typing a mode word, or an
expression that works one out while the game runs, goes on working: the strip is the shortcut, not
the only door.

**What it costs, said once.** The five native modes cost nothing. The fifteen shader modes read the
screen back through a BackBufferCopy of the whole viewport, taken once per blending item - so the
bill is counted in blended ITEMS rather than in the pixels they cover, every frame they are visible.
That is
fine for a flare, a decal or a boss aura, and wrong for every sprite in a bullet hell. And a
screen-reading mode must be drawn AFTER what it blends with - later in the tree, or on a higher
`z_index` - because an item that draws first has nothing under it to read.

**An item already wearing somebody's shader is never quietly replaced.** A blend hands the item a
shader of its own, and an item wears one material. The pack refuses at run time rather than throwing
your effect away - which is right, and is also completely invisible until somebody runs the game and
wonders why the glow never appeared. So the sheet says it first, as the amber row state and a line
in the Doctor's inbox naming the shader it clashes with and the mode that was asked for. There is no
fix door on that note on purpose: blend a parent, blend a child, and take the shader off are three
answers to three different scenes.

---

## Masks, and a node's children drawn inside its own shape

Blending is one half of "how do two pictures meet". Cutting is the other, and it has three answers
that look alike and cost wildly different amounts.

| You want | The row | What it costs |
|---|---|---|
| A texture's transparency to decide where an item may be | **Mask With** (or **Mask With Node**) | A shader on the item |
| A node's own drawing to be the shape its children draw inside | **Clip My Children** | Nothing - a rendering field |
| A node's children merged into one picture before anything else happens to them | **Blend As One** | One `CanvasGroup` |

**Mask With** takes a texture and one of five modes: `inside` (the item where the mask is solid),
`outside` (a hole punched through it), `atop` (the mask's shape painted with the item), `behind`
(the mask filling in everywhere the item is not) and `xor` (whichever of the two is alone).

**Clip My Children** is `clip_children`, one property on every `CanvasItem`, and it does something no
arrangement of nodes can: whatever the node draws becomes the shape its children are allowed to draw
inside. A portrait cut to its frame, a bar that fills a heart instead of a rectangle, water that
stops at the edge of the pool - all of them are this one field, and almost nobody finds it, because
it is spelled as a rendering enum rather than as something a game wants. It is **built in**: no pack,
nothing installed, and it costs nothing.

<!-- caption: A portrait cut to its frame, and the way back out -->
```
On Ready          ->  Frame | Clip my children, clip only
On Frame Removed  ->  Frame | Stop clipping my children
```

```gdscript
Frame.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
Frame.clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
```

Two rows and not one, because the field has two answers a reader means (*draw me too* - a frame you
can see; *clip only* - an invisible cutter) and one they do not. **Stop Clipping** owns the third
value alone, so no written line can be spelled by both rows, which is what keeps an opened file
reading back as the row that wrote it.

**Blend As One** is the third: a character made of six sprites fades out as one picture rather than
like a paper cut-out, because the overlaps stop showing through each other. That is a row, for
something that happens during a game. A node that should ALWAYS be drawn that way does not want a
row at all - it wants the scene to say so, and the row's own node field offers exactly that: one
click puts a `CanvasGroup` under the node and moves its drawing children into it, where it saves with
the scene and costs no row. It is a SCENE edit applied through the editor's own undo manager, so
Ctrl+Z in the scene puts the children back.

---

## The post stack: the whole screen as a named list

A full-screen effect in Godot is a `CanvasLayer` holding a `ColorRect` whose shader reads
`hint_screen_texture`. That is three nodes and a shader before a game gets its first vignette.

Screen FX ships that scene, and on top of it the **post stack**: a named list of full-screen
effects, drawn in order, **twelve** of them shipped as shader files beside the script.

| Word | What it looks like |
|---|---|
| `vignette` | The corners go dark, so the middle is where the eye goes. |
| `film grain` | A fine moving speckle, the way film stock looks. |
| `scanlines` | Dark horizontal lines, the way a tube television drew one. |
| `pixelate` | The picture resampled into big square blocks. |
| `colour grade` | Every colour looked up in an image and replaced. |
| `dither` | A few levels per channel, an ordered pattern deciding the rounding. |
| `fisheye` | The picture bulges out of the middle, or pinches into it. |
| `glitch` | Bands jump sideways and the colour channels come apart. |
| `letterbox` | Solid bars close in from the top and the bottom. |
| `bloom` | Bright things spill light into what is around them. |
| `saturate` | The colour comes up. |
| `desaturate` | The colour drains out. Full strength is black and white. |

Every one of them has a **strength**, which is the dial the rows turn: 0 hands the screen back
untouched, 1 is the whole effect. Every one also has its own dials on its own resource, for the
project that wants a red vignette rather than a black one.

**Start with the pulse.** `Pulse Post Effect` needs no setup at all: if the stack does not hold a
glitch it borrows one, flashes it, and gives it back.

<!-- caption: The jam form, and the careful form beside it -->
```
On Big Hit         ->  ScreenFx | Pulse Post Effect: glitch, 0.8, 0.25

On Health Changed  ->  ScreenFx | Add Post Effect: vignette, "hurt", 0.0
                   ->  ScreenFx | Set Post Strength: "hurt", 1.0 - Health Percent
```

```gdscript
$ScreenFx.pulse_post_effect("glitch", 0.8, 0.25)
$ScreenFx.add_post_effect("vignette", "hurt", 0.0)
$ScreenFx.set_post_strength("hurt", 1.0 - health_percent())
```

**Names are how a later row finds an entry.** Add an effect without one and it is called after
itself, which is what one of each wants. Give it a name when you want two of the same effect, or
when a row somewhere else should be able to reach this one.

**Order is the look.** The first entry is applied first and the last one has the last word. A colour
grade UNDER a vignette grades the game; the same grade OVER it grades the vignette too. **Move Post
Effect Before** is how you say which.

**What it costs, said once.** Every entry reads the whole screen back through a BackBufferCopy of
the viewport, taken once per entry that is on - one full-screen copy plus one full-screen shader
pass each. Two or three is a look; twelve is a bill, and the frame rate will say so. **Post Effect
Count** is the number to look at when the frame rate has gone. An entry whose
strength is 0 hides its own rectangle, and a hidden Control is not drawn at all, so a stack at rest
costs nothing.

**The trap this removes.** The hand-written version of this is one shader with a uniform per effect,
which starts fine and ends as a two-hundred-line file where turning the vignette on changes the
grain. Separate entries in a list cannot do that to each other, and an entry you are not using is an
entry you can take off.

---

## Post under the HUD, or over it

A post effect covers the whole viewport. Whether the health bar is graded, blurred and dimmed along
with the game therefore comes down to which of two `CanvasLayer`s has the higher number - and
neither of them was picked for that.

Two rows settle it, and both are right answers to different scenes:

<!-- caption: The interface kept sharp, and then deliberately covered -->
```
On Ready             ->  ScreenFx | Draw Post Effects Below: $Hud
On Cutscene Started  ->  ScreenFx | Draw Post Effects Above: $Hud
```

```gdscript
$ScreenFx.draw_post_effects_below($Hud)
$ScreenFx.draw_post_effects_above($Hud)
```

Below keeps a health bar readable while the world behind it is graded. Above puts the letterbox over
everything, which is what a cutscene wants. The Doctor says so once per scene, as an amber note with
no fix door: a sheet that puts something on the post stack, a scene that carries an interface layer,
and no row anywhere saying which side of it the effects belong on. The interface layer is read
straight off the scene - the first `CanvasLayer` with a `Control` under it - so a sheet with no
interface and a project whose interface is not on a layer are said nothing about.

---

## Colour vision, and the flashing setting that already exists

**See As** is the designer's row. Turn it on, walk the level, and the health bar that vanishes into
the background is the bug you came to find. It simulates protanopia, deuteranopia or tritanopia;
`normal` takes it off. The matrices are the usual published approximation of something that varies
between people, so it is a check rather than a certificate.

**Correct Colours For** is the player's row, and it belongs behind a settings choice rather than on
by default. It puts each colour through that same simulation, works out what would be lost, and
pushes that difference into the channels the viewer can still tell apart. The picture stops being
accurate and starts being readable, which is the trade the setting is making.

Both are ordinary stack entries under reserved names, so a look records them and **Clear Look** takes
them away.

**Reduced flashing is already a project-wide setting, and nothing here mints a second one.** The
built-in **Set No Flashing** action and **No Flashing** condition write and read the one answer the
whole project shares. The post stack and the moments read it: every strength they are asked for is
held under a ceiling, and every walk they are asked for is held over a floor.

<!-- caption: One settings row, and every effect on this page obeys it -->
```
On No Flashing Chosen  ->  Set no flashing to true
```

```gdscript
Engine.set_meta("no_flashing", true)
```

A player who asked for no flashing still gets the rows - the pulse pulses, the moment plays, the
look lands - and nothing any of them draws can strobe. The clamp lives in this newer layer and never
inside the verbs that shipped before it, because a frozen verb's emitted bytes are a promise. The
built-in **Set Effect Strength** dial scales every post strength too, so a player who turns effects
down turns these down with them.

Three things are deliberately left alone by the clamp: a slow-motion time scale, a hit-stop freeze
and a zoom percentage. They are not amplitudes. Half a zoom is not half of anything.

---

## A look is a file you own

A **look** is the post stack written down: which effects, in which order, how far each one goes, and
what its own dials are set to. It is a `ScreenLookResource` - an ordinary Godot resource file.

**Nothing here is a preset.** This plugin ships no named looks and no dropdown of house styles. The
one file that comes with the pack is `clean.tres`, which holds no rows at all: the screen as the game
drew it. Every other look in your project is one you made.

The recipe is three steps, and the first one is the one that matters:

1. **Build it live.** Add effects with rows until the screen is right. You are looking at the game
   while you do it.
2. **Save Look**, once, with a path and a name. The live stack is written out as a file.
3. From then on, **Use Look** wears it and **Blend To Look** walks to it.

<!-- caption: Save the screen you built, then wear it anywhere -->
```
On Debug Key Pressed  ->  ScreenFx | Save Look: "res://looks/dusk.tres", "Dusk"

On Evening Started    ->  ScreenFx | Blend To Look: res://looks/dusk.tres, 3.0
```

```gdscript
$ScreenFx.save_look("res://looks/dusk.tres", "Dusk")
await $ScreenFx.blend_to_look(preload("res://looks/dusk.tres"), 3.0)
```

Edit the file afterwards in the Inspector like any other resource, rename it, put it in version
control, send it to somebody else. It is yours.

**Blend To Look crosses rather than cuts.** Effects both looks hold walk from one strength to the
other, effects only the old look had fade out and go, and effects only the new look has fade in from
nothing.

**A settings screen of looks needs no seam of its own.** Point a Game Settings choice at a folder of
`.tres` files; the row that applies the choice is **Use Look** with the chosen file. **Current Look**
reads back the name of the one on the screen, which is what the settings screen shows as the current
value, and **Look Is** is the condition for a rule that should only run under one of them.

---

## A moment is a beat written down

A hit does not feel like a hit because of one effect. It feels like a hit because four things happen
at once: the camera kicks, time stops for a few frames, the colour splits, and the edges of the
screen darken. Writing those four rows out is easy. Writing them out again in the ten other places
something can be hit, and keeping all ten in step when the feel changes, is not.

A **moment** is that beat written down once, as a `MomentResource` - a list of steps, each one a
word, how much, and how long.

<!-- caption: Every hit in the game, as one row and one number -->
```
On Enemy Hit     ->  Enemy | Moment: "impact", 1.0
On Enemy Grazed  ->  Enemy | Moment: "impact", 0.35
On Enemy Killed  ->  Enemy | Moment: "kill", 1.0
```

```gdscript
$JuiceBehavior.moment("impact", 1.0)
$JuiceBehavior.moment("impact", 0.35)
$JuiceBehavior.moment("kill", 1.0)
```

The strength scales every amount a player sees, so a glancing blow and a critical are one file at two
numbers. When the game's feel changes you retune `impact.tres` once instead of editing twenty rows.

**Ten step words**, and each one is a thing you can already picture: `shake`, `hitstop`, `slowmo`,
`flash`, `punch`, `zoom`, `shockwave`, `chromatic`, `pulse` and `hold`. The last two take one of the
post-stack effect words, so a moment can darken the corners or drain the colour using the same list
the rest of this page uses.

**Six starters ship, and they are files you are meant to open.** `impact`, `kill`, `triumph`,
`danger`, `calm` and `cut` sit beside the pack. They are not a house style and nothing in the plugin
depends on any of them: retune the numbers, duplicate one, rename it, or delete the ones your game
has no use for. `danger` and `calm` are a pair on purpose - one turns the pressure on and holds it
there, the other takes it off - which is how a low-health state, a boss phase or a storm is
authored, in two rows and no per-frame logic.

A moment of your own is a new `MomentResource` anywhere in your project, pointed at by name once:

<!-- caption: A moment kept in your own folder, named once for the whole game -->
```
On Ready       ->  Game | Define Moment: "hit", res://feel/my_hit.tres
On Enemy Hit   ->  Enemy | Moment: "hit", 1.0
```

```gdscript
$JuiceBehavior.define_moment("hit", preload("res://feel/my_hit.tres"))
$JuiceBehavior.moment("hit", 1.0)
```

Point the same name at a different file later - during a boss fight, in a nightmare level - and every
row that plays it changes with it.

**One stack, never two.** A moment's screen steps draw on the Screen FX post stack when the scene has
one, so a hit never builds a second full-screen rectangle to fight with the one already there.
Without a Screen FX layer a vignette pulse falls back to the Juice pack's own overlay and the other
screen words quietly do nothing - add `screen_fx.tscn` to the scene and they all light up.

---

## Transitions: a shape drawn over the change

**Fade To Scene** covers the screen with a colour. **Go To Scene With** covers it with a shape.

<!-- caption: One row for a whole scene change -->
```
On Level Complete  ->  Level | Go To Scene With: "res://scenes/level_2.tscn", iris, 0.8, smooth
On Player Died     ->  Level | Reload Scene With: dissolve, 0.5, smooth
```

```gdscript
$SceneFlowBehavior.go_to_scene_with("res://scenes/level_2.tscn", "iris", 0.8, "smooth")
$SceneFlowBehavior.reload_scene_with("dissolve", 0.5, "smooth")
```

Under all seven shapes is **one walk**: the cover comes on over the first half, the scene is
exchanged at the midpoint where nobody can see it, and the cover comes off over the second half, over
the new scene.

| Shape | What it looks like | Reads the screen |
|---|---|---|
| `fade` | The screen goes to the cover colour and comes back. | no |
| `wipe` | The cover sweeps in following a greyscale picture you chose. | no |
| `dissolve` | The screen breaks up into speckles that fill in. | no |
| `iris` | A circle closes over the picture and opens on the next one. | no |
| `blinds` | Bars close across the screen like a shutter. | no |
| `pixelate` | The picture comes apart into blocks that drain to the cover colour. | yes |
| `page curl` | The picture peels off the screen like a page being turned. | yes |

The last two cost one screen read per pixel while the transition runs, and only while it runs, so it
is a beat of expense rather than a standing one.

**A wipe follows any greyscale picture**: it covers the dark parts first and the light parts last. A
left-to-right ramp is a bar wipe, a radial ramp is a clock, a soft cloud is a smoky dissolve, and a
shape you painted is that shape appearing. There is no list of shipped wipe images, because a
256x256 gradient PNG is enough and the shape is yours.

**A transition draws above every post effect**, in the top slot. That is deliberate: a transition is
the one thing that should not itself be graded, blurred or vignetted by the look the game is
wearing. It also parents itself to the tree root rather than to the scene being replaced, so the
whole walk survives the swap, and **On Transition Finished** arrives on the Scene Flow node in the
NEW scene carrying the shape it was.

**The trap this removes.** The hand-written scene change is a fade tween, a `change_scene_to_file`,
and a second fade - written on a node that the scene change deletes half way through. It works until
the day it does not, and the symptom is a screen stuck black. The runner outliving the swap is the
whole reason this is a row.

---

## The Post Kit: the same words on a 3D camera

Godot gives a 3D camera a **Compositor**, and a Compositor a list of **CompositorEffects**: scripts
handed the frame after it has been drawn, free to do anything to it. It is the right seam and almost
nobody reaches it, because reaching it means a compute shader, a rendering device, a uniform set and
a dispatch before a game gets its first vignette.

The **Post Kit** pack is those effects as rows: nine for the stack (add, remove, enable, disable,
set, fade, pulse, has, strength) and five for the thing only a 3D camera can do.

**The words are the same words.** `vignette`, `desaturate` and `pixelate` mean on a camera exactly
what they mean on the screen, so a row reads alike in either place and a project that changes
renderer keeps its sheet. The Post Kit adds `tint` and `fade` beside them.

<!-- caption: The same sentence, on the screen and on the camera -->
```
On Player Hurt  ->  ScreenFx | Pulse Post Effect: vignette, 0.6, 0.35
On Player Hurt  ->  Camera3D | Pulse Post Effect: vignette, 0.6, 0.35
```

```gdscript
$ScreenFx.pulse_post_effect("vignette", 0.6, 0.35)
$PostKitBehavior.pulse_post_effect("vignette", 0.6, 0.35)
```

**Seeing through a wall** is the half the 2D stack has no answer for:

<!-- caption: The enemies behind the crate -->
```
On Ability Used  ->  Camera3D | Outline Group Through Walls: "enemies", yellow, 2.0, 4.0
On Quest Started ->  Camera3D | Silhouette Node Through Walls: Objective, cyan, 0.0
On Quest Ended   ->  Camera3D | Stop Outlining
```

```gdscript
$PostKitBehavior.outline_group_through_walls("enemies", Color.YELLOW, 2.0, 4.0)
$PostKitBehavior.silhouette_node_through_walls(Objective, Color.CYAN, 0.0)
$PostKitBehavior.stop_outlining()
```

The mechanism is worth knowing, because it explains the cost. Every visual instance at or under what
you named is switched onto the pack's mask layer (visual layer 20 by default, the last one Godot has
and the one a project is least likely to be using). A second camera that can see that layer **and
nothing else** draws them into a viewport with a transparent background. A compute shader finds the
edge of that mask and draws it over the finished frame. The outline never asked what was in the way,
which is the whole of "through walls" - and it costs a second render of the marked meshes and nothing
else, built the first time something is outlined and freed by **Stop Outlining**.

**The effects are real files.** Seven scripts and six compute shaders sit in
`eventsheet_addons/post_kit/effects/`, so one can be dragged onto a Compositor in the Inspector with
no pack involved at all. Their own dials (`shade`, `inner_edge`, `block_pixels`, `tint`, `gain`,
`to_colour`) are Inspector fields rather than thirty-two more entries in every project's picker.

---

## What each renderer can actually do

This is the one place on the page where the answer depends on a project setting, so it is said out
loud rather than discovered.

| | Forward+ | Mobile | Compatibility |
|---|---|---|---|
| Blend Modes (native five) | yes | yes | yes |
| Blend Modes (fifteen shader modes) | yes | yes | yes |
| Clip My Children, Blend As One, masks | yes | yes | yes |
| The Screen FX post stack | yes | yes | yes |
| Moments and transitions | yes | yes | yes |
| **The Post Kit (camera compositor)** | yes | **nothing at all** | **nothing at all** |

Only Forward+ has a Compositor. On Mobile and Compatibility every Post Kit row **does nothing**: no
error, no warning in the player's face, no frame drawn differently. That is deliberate - a row that
errored on a renderer would be a row you could not ship - and the ship-it check in the Doctor names
it once for you, with the door:

> `level.gd` asks for a camera post effect (the Screen FX and Blend Modes packs do the same looks on
> any renderer), which only the Forward+ renderer draws.

So a project shipping on Mobile or Compatibility reaches for **Screen FX** and **Blend Modes**, which
do the same looks on a full-screen rectangle on any renderer. A project shipping on Forward+ can use
the Post Kit and pay less, because the frame is already on the GPU when the effect runs.

---

## What a project you already wrote opens as

Every row on this page is plain Godot underneath, so a project that wrote these lines by hand opens
as the rows rather than as a wall of verbatim code.

| What you wrote | What the sheet shows |
|---|---|
| `clip_children = CanvasItem.CLIP_CHILDREN_ONLY` | Clip my children, clip only |
| `clip_children = CanvasItem.CLIP_CHILDREN_DISABLED` | Stop clipping my children |
| `material_override.albedo_color = Color.RED` | Crate - Set colour to red |
| `BlendModes.blend_as(self, "screen", 1.0)` | Blend self as screen |
| `$ScreenFx.pulse_post_effect("glitch", 0.8, 0.25)` | Pulse glitch at 0.8 for 0.25 s |
| `$JuiceBehavior.moment("impact", 1.0)` | Play moment impact at 1 |
| `$PostKitBehavior.outline_group_through_walls(...)` | Outline group enemies through walls in yellow |

The builtin rows read back through the lift table, and the pack rows read back through each pack's
own vocabulary, which is why a file written by hand and a file written by the picker open as the
same sentences. **Clip My Children** and **Stop Clipping** own one value of `clip_children` each and
none of them twice, which is exactly what makes that pair reversible.

**One line is deliberately not claimed.** A bare `material.blend_mode = ...` stays a verbatim row,
because a mesh's material spells `blend_mode` too and the line cannot say which of the two words it
means. Guessing would be worse than leaving it alone.

---

## Tips and common mistakes

**Reach for the pulse first.** `Pulse Post Effect` and `Moment` are the rows that need no setup,
put themselves back, and cannot leave the screen in a state you have to clean up. Add / Set / Fade
are for the effect that has to persist and be read back.

**A screen-reading blend must draw after what it blends with.** Later in the tree, or a higher
`z_index`. An item that draws first has nothing under it to read, and the symptom is an effect that
simply is not there.

**Do not blend every sprite.** Fifteen of the twenty modes read the screen back per pixel covered.
One boss aura is free; four hundred bullets is a frame rate.

**Watch the stack depth.** **Post Effect Count** is the first number to look at when the frame rate
has gone. Two or three entries is a look.

**Take entries off rather than turning them down.** `Set Post Strength` to 0 hides the rectangle, so
it costs nothing to draw - but **Remove Post Effect** frees it outright, which is what a menu closing
wants.

**Say which side of the interface the stack draws on, once.** Otherwise it is decided by two layer
numbers nobody chose it with, and the answer changes the day somebody adds a layer.

**Never build a second full-screen rectangle.** If the scene has a Screen FX layer, the moments draw
on it. Two overlays reading the screen is twice the cost for a look that is now decided by node
order.

**Author a look, do not hunt for one.** Build the screen live, save it once, and edit the file. There
is no dropdown of shipped looks anywhere in this plugin, because the look that suits your game is not
one somebody else wrote.

**Do not add a reduced-flashing setting.** There is one, it is built in, and every effect on this
page already reads it.
