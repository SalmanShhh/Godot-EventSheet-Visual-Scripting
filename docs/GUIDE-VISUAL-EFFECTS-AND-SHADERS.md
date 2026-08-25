# Visual effects and shaders

A shader effect in Godot is a `.gdshader` file, a `ShaderMaterial` that runs it, and a node wearing
that material. Nothing on a sheet changes any of that. What the sheet adds is that the **dial names
come out of the shader file** instead of being typed: you pick `dissolve` off a list the shader
itself declares, and a name that is not in that list can no longer reach your game.

That matters more than it sounds. This is a perfectly legal Godot call:

```gdscript
material.set_shader_parameter(&"disolve", 1.0)
```

Godot accepts it, returns from it, prints nothing, and sets nothing. The effect never happens and
nothing in the engine ever tells you why. Reading the dial names out of the shader is the whole fix.

## Contents

- [The dials are read from the shader](#the-dials-are-read-from-the-shader)
- [What a dial row reads like](#what-a-dial-row-reads-like)
- [The four verbs](#the-four-verbs)
- [The field a dial edits in](#the-field-a-dial-edits-in)
- [The shared-material trap](#the-shared-material-trap)
- [Six effects you do not have to write](#six-effects-you-do-not-have-to-write)
- [Full-screen effects](#full-screen-effects)
- [What the head says about the effect](#what-the-head-says-about-the-effect)
- [A dial the shader no longer has](#a-dial-the-shader-no-longer-has)
- [Opening a project that already has shader code](#opening-a-project-that-already-has-shader-code)
- [Doctor: the five silent failures](#doctor-the-five-silent-failures)
- [What is read, and what is left alone](#what-is-read-and-what-is-left-alone)

## The dials are read from the shader

Write a shader the way you already do, with a `//` line above a uniform when it deserves one:

```glsl
shader_type canvas_item;

// How much of the sprite has burned away, from whole to gone.
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;

// The colour the burning edge glows.
uniform vec4 edge_tint : source_color = vec4(1.0, 0.6, 0.2, 1.0);

uniform int steps : hint_range(1, 16, 1) = 8;
```

Save a `ShaderMaterial` running it, put it on a node in your scene, and open that node's script as a
sheet. The Add picker grows a shelf per wearing node, named with the shader it runs:

> **Effects in this scene ▸ Boss   effect_dissolve.gdshader**
> effect.dissolve · Set Effect Dial
> effect.dissolve · Fade Effect Dial
> effect.edge_tint · Set Effect Dial
> effect.steps · Set Effect Dial

Each entry describes itself with the shader's own words: the `//` comment you wrote, then the
declaration read back (`float 0..1 = 0.0`). Both come out of the file, so a dial explains itself
without anything being written down twice.

A material the scene keeps inside itself (the one you get by making a new `ShaderMaterial` in the
Inspector rather than saving a `.tres`) is followed exactly as far as a saved one.

## What a dial row reads like

> **Boss ▸ Set** `effect.dissolve` **to** `0.7`

The `effect.` lead is muted, and it is there to say what the name belongs to: a dial on this node's
material, not a variable of the script. It is the same device a global's row uses when it reads
`Game.HighScore`, and it is a reading rather than a pill or a chip. What the row stores is the plain
name, and what it compiles to is the call it says:

```gdscript
material.set_shader_parameter(&"dissolve", 0.7)
```

Every one of these rows has the ordinary optional **On node** field. Left blank it acts on the node
the sheet is attached to; fill it and the whole line retargets.

## The four verbs

| The row | The line it is |
|---------|----------------|
| Set Effect Dial | `material.set_shader_parameter(&"dissolve", 0.7)` |
| Fade Effect Dial | `create_tween().tween_method(func(v): material.set_shader_parameter(&"dissolve", v), 0.0, 1.0, 0.8)` |
| Effect Dial (expression) | `material.get_shader_parameter(&"dissolve")` |
| Effect Dial Is (condition) | `material.get_shader_parameter(&"dissolve") > 0.5` |

The fade is one tween and no state: nothing is kept between frames, and nothing has to be cleaned up
when the node goes away.

The four free-string rows that shipped before these ones are still there, on a shelf of their own
beside the dials (**any material, name typed**). They are exactly right for a material that only
exists at run time - one you built in code, or one handed to you by something else - where no file
can be asked what its dials are called. Where a name can be checked, pick it; where it cannot, the
sheet does not pretend it did.

## The field a dial edits in

Godot's Inspector already decides how a uniform wants to be edited, from the hints on its own
declaration. The Parameters dialog obeys the same hints, off the same file, so a dial edits in the
sheet exactly as it edits in the Inspector:

| The declaration | The field you get |
|-----------------|-------------------|
| `uniform float dissolve : hint_range(0.0, 1.0)` | a slider with those ends, and the number beside it |
| `uniform int steps : hint_range(1, 16, 1)` | a stepper, because the values are whole |
| `uniform vec4 edge_tint : source_color` | the colour editor, opening on your saved swatches |
| `uniform sampler2D burn_noise` | a texture file field with **Browse…** |
| `uniform bool lit` | a tick |
| `uniform vec2 offset` | one box per axis |
| anything else | the ordinary value field |

None of that is a list of dial names kept somewhere: it is the declaration read back. A shader nobody
here has seen gets the right field the first time.

**Open on what the shader starts it at.** A value field you have not answered opens on the uniform's
own default, written as the GDScript the row will emit - so `= vec4(1.0, 0.6, 0.2, 1.0)` opens as the
swatch for `Color(1.0, 0.6, 0.2, 1.0)`, the way the Inspector opens on it.

**Never a dead end.** A dial is still a value, and a value can be an expression. Type `hp / 100.0`
into a slider's slot and the field goes back to being the ordinary value box, with its `ƒx` picker
and its completions - the derived editor is for the common answer, not a cage around the rare one.

## The shared-material trap

A `.tres` material is a **file**. Two nodes pointing at the same file share every dial on it, so
`Boss ▸ Set effect.dissolve to 0.7` dissolves every other node wearing `boss_burn.tres` at the same
moment - and, because the file is a resource, the change can outlive the scene.

Godot's own answer is to take a copy first, and that is a row:

> **Boss ▸ Make the effect this node's own**

```gdscript
material = material.duplicate()
```

Put it under an **On ready** trigger, before any row that turns a dial. Once it is there, every dial
row after it is about this node and nothing else.

## Six effects you do not have to write

Nobody should have to write a dissolve shader to burn a boss. Five packs ship the commonest sprite
effects, each as a shader file, a material and one or two verbs:

| Pack | The verbs | What it does |
|------|-----------|--------------|
| **Hit Flash** | Flash, Stop Flashing | Washes the sprite's own pixels towards a colour and back. Works on dark sprites, which a modulate blink does not. |
| **Dissolve** | Dissolve, Appear, On Dissolved | Burns the sprite away along a noise field with a glowing edge, and tells the sheet when it has gone. |
| **Outline** | Outline, No Outline, Fade Outline | A border in the shape of the art, not of its rectangle. |
| **Grayscale** | Grayscale, Recolour | Drains the colour out, all the way or part of it, with a tint for sepia or frozen. |
| **Wave** | Wave, Settle | Ripples the picture without moving the node, so collisions and positions are untouched. |

The shipped modulate **Flash** verb stays exactly where it was. It needs no material at all, which is
what makes it the right answer for a node that has none, and the object column and the code echo say
which of the two a row is.

**The shader file becomes yours.** Adding an effect pack to an object copies its `.gdshader` into
`res://effects/` and makes a `.tres` material wearing it, then puts that material on the node as an
undoable scene edit. Both files are ordinary project files from then on: open the shader and change
what a hit looks like. Nothing here ever overwrites a file that exists, so a second node added later
finds your edited copy and uses it.

**And the packs take the copy for you.** Every one of them duplicates the material the first time it
writes a dial, which is the trap above solved before it can happen. The `own_material` knob turns that
off for the one case where sharing is the effect - a whole squad flashing together, a body of water
rippling as one surface.

**The dials are still rows.** Because the node wears a real `ShaderMaterial`, everything in this guide
applies to it: the picker offers `Set effect.dissolve`, the head grows an **effect** band naming the
file, and the Doctor checks the names. The pack's verbs are the timing; the dial rows are the direct
control, and a project uses both.

## Full-screen effects

A full-screen effect in Godot is a `CanvasLayer` holding a `ColorRect` whose shader reads
`hint_screen_texture`: the rectangle covers the viewport, the shader is handed the frame so far, and
what it writes is what the player sees.

The **Screen FX** pack ships that scene. Adding it drops the layer in, and four rows follow:

> **ScreenFx ▸ Shockwave at** `Boss.position`**, strength** `1.0`
> **ScreenFx ▸ Fade to** black **over** `1.5` **s**
> **ScreenFx ▸ Blur to** `3` **over** `0.2` **s**
> **ScreenFx ▸ Chromatic pulse at** `0.6`

```gdscript
$ScreenFx.shockwave(Boss.position, 1.0)
await $ScreenFx.fade_to(Color.BLACK, 1.5)
```

**Fade waits.** Its line carries `await`, so the rows under it run when the fade has landed. That is
a scene transition written as two rows in one event, in the same await shape the shipped `Wait` rows
already use, and it is why the pack has no separate transition machinery.

**It costs nothing at rest.** A rectangle covering the viewport redraws every pixel of it through the
shader every frame. The pack hides the rectangle whenever every effect has finished and shows it the
moment one starts, and a hidden `Control` is not drawn at all. That is also the shape the Doctor's
fifth check looks for: a visible screen rectangle with every dial still at its declared default is a
whole screen of work for no change, and if you build your own layer it should hide itself too.

## What the head says about the effect

The head of the sheet grows one **effect** band per node of the attached scene that wears a material,
and each band is three facts and nothing else:

> **effect**  `goblin.tres (dissolve.gdshader) · shared with 11 other nodes`
> *effect_scene_goblin.tscn: Sprite2D "Goblin", material = "res://goblin.tres" · uniform dissolve, edge_tint · also worn by Torch, Orc*

The file, the shader at the end of the chain, and who else wears it. The echo beside it is the
node's own line of the `.tscn`, the dials that shader declares (the names your rows may use), and
the nodes a dial row would move as well as this one. When the material hands the drawing on to
another one (`next_pass`), every pass is named in the order it is drawn - two passes chained the
wrong way round look identical in the Inspector and differ only on screen.

Three other readings you will meet:

- *kept inside this scene - nothing else wears it* - the material is a sub-resource, so there is
  nobody to share it with.
- *its own copy at runtime* - this sheet already writes **Make the effect this node's own** for that
  node, so the count no longer applies. The band answers instead of warning.
- *counting…* - "who else wears this file" is a question about every scene in the project, and the
  answer is built a few milliseconds per idle frame rather than while you wait. It arrives a moment
  after the sheet opens. Nothing you can do is blocked on it.

Clicking the band selects the node in its scene, where the Inspector is.

## A dial the shader no longer has

Rename a uniform in the shader and every row still holding the old name stops working, silently. The
sheet says so instead: the row grows an amber note underneath naming the shader and the dial, and -
when one of the shader's declared dials is close enough to be what you meant - a one-click fix.

> ⚠ `effect_dissolve.gdshader` declares no dial called `disolve`, so this row does nothing when the
> game runs. Did you mean `dissolve`?  **Use dissolve**

Clicking the fix rewrites that one row, in one undo step. It is the same note and the same gesture a
misspelled variable already gets, because it is the same mistake.

## Opening a project that already has shader code

Every spelling below opens as the row beside it, and saving the sheet untouched writes your own
bytes back - the `&` or not, the receiver you used, your spacing:

| What you wrote | What it opens as |
|----------------|------------------|
| `material.set_shader_parameter(&"dissolve", 0.7)` | Set `effect.dissolve` to `0.7`, on this node |
| `$Sprite.material.set_shader_parameter("amount", x)` | the same row, aimed at `$Sprite`, string spelling kept |
| `%Aura.material.set_shader_parameter(&"glow", 1.5)` | the same row, aimed at `%Aura` |
| `get_node("Aura").material.set_shader_parameter(&"glow", 1.0)` | the same row, aimed by path |
| `aura.material.set_shader_parameter(&"glow", 0.5)` | the same row, aimed by the variable holding the node |
| `create_tween().tween_method(func(v): material.set_shader_parameter(&"dissolve", v), 0.0, 1.0, 0.8)` | Fade `effect.dissolve` |
| `material = material.duplicate()` | Make the effect this node's own |
| `material = preload("res://effects/frozen.tres")` | Set effect |
| `RenderingServer.global_shader_parameter_set("wind_strength", 2.0)` | Set global shader parameter |

The receiver you used is part of the line rather than part of the sentence, which is why it rides
back out untouched. So does the way you quoted the name: a `&"dissolve"` stays a StringName and a
`"amount"` stays a plain string.

## Doctor: the five silent failures

Every one of these runs today without an error and shows nothing on the screen. They are the
**Effects** section of the Project Doctor, and the first four also appear as amber notes under the row
they are about, so the same sentence meets you wherever you meet the problem.

| The finding | What is actually wrong | The step |
|-------------|------------------------|----------|
| A dial the shader does not have | the uniform was renamed, or mistyped | **Use dissolve** rewrites that row |
| Dials turned on a shared material | the `.tres` is worn elsewhere, and they all move | **Make the effect this node's own** is inserted on ready |
| Effect rows on a node wearing no material | every row reaches through a null | assign a `ShaderMaterial` in the Inspector |
| A global the project does not declare | `RenderingServer.global_shader_parameter_set("wind_strength", …)` with nothing declared, so every shader reading it sees zero | declare it in **Project Settings ▸ Shader Globals** |
| A screen effect left drawing | a full-screen rect whose shader samples the screen, visible with every dial still at rest | hide it until an effect turns it on |

The two with a single step to take carry it as a button; the other three are a material to assign, a
setting to write and a rect to hide, and a wrong guess in a fix button costs more than no guess.

The dial checks read the same `.gdshader` parse everything else here reads: there is exactly one
reader of uniform lines in the plugin, so a project can never be told two different things about the
same file.

## What is read, and what is left alone

A line becomes a **dial** row only when two things hold: the attached scene says the node it names
wears a material, and that material's shader really declares the dial. Both, always.

- A node the scene gives no material: the line opens as the free-string row it has always been.
- A dial the shader does not declare: the same - it IS that row, because that row claims nothing
  about any shader, which is the honest reading of a name nothing can check.
- A material the sheet cannot follow to a `.gdshader` (a shader written inline in the scene, a
  material saved in Godot's binary format): the chain ends, and so does the claim.

Nothing here guesses. A dial row on your sheet is evidence that the shader has that dial, and you can
check the claim against the file in front of you.

Two more things are read from the shader and not from anywhere else: `hint_range` gives a dial its
ends, and `source_color` says four numbers are a colour. Both are the same hints Godot's own
Inspector obeys, read from the same line.

### The one property

These rows write `material`, the `CanvasItem` member. A 3D node wears its shader on
`material_override` and would need rows that spell that, so it is not offered these rather than
offered a line that would not run.
