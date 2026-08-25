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
- [The shared-material trap](#the-shared-material-trap)
- [A dial the shader no longer has](#a-dial-the-shader-no-longer-has)
- [Opening a project that already has shader code](#opening-a-project-that-already-has-shader-code)
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
