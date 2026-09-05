# The look of your game

What a game looks like is four objects in Godot, and almost every question a person has about it is
really the question of which of the four holds the thing they want to change.

A **material** says what one surface looks like. An **environment** says what the whole world looks
like. **Camera attributes** say what the lens lets in and what it keeps sharp. A **process material**
says how an effect's particles move and what colour they are. None of them is a node, all four of
them are resources, and every one of them can be a file that several nodes are sharing.

This guide is the whole of that vocabulary in the order a game usually needs it, and it is written
around the two facts a reader keeps tripping over: **a word is not a property name**, and **a shared
resource changes under everybody wearing it unless somebody takes a copy first**. The rows here fix
both, and the emitted code shows exactly how.

Nothing here is a style. No look, no grade and no named preset ships with the plugin: the words are
the vocabulary, the looks are yours.

## Contents

- [One shape, four objects](#one-shape-four-objects)
- [The own-it courtesy](#the-own-it-courtesy)
- [Nine words for what a 3D surface looks like](#nine-words-for-what-a-3d-surface-looks-like)
- [The visor and not the helmet, surfaces and layers](#the-visor-and-not-the-helmet-surfaces-and-layers)
- [A sprite has two words, not nine](#a-sprite-has-two-words-not-nine)
- [Twenty-one words for the whole world](#twenty-one-words-for-the-whole-world)
- [Tone map, glow and the seven numbers](#tone-map-glow-and-the-seven-numbers)
- [Fog, near and far](#fog-near-and-far)
- [The switches, and what each renderer can draw](#the-switches-and-what-each-renderer-can-draw)
- [The sky is three objects past the node](#the-sky-is-three-objects-past-the-node)
- [The lens, exposure and what stays sharp](#the-lens-exposure-and-what-stays-sharp)
- [A look is a file you author](#a-look-is-a-file-you-author)
- [Particles, seven words on two objects](#particles-seven-words-on-two-objects)
- [Every row, by name](#every-row-by-name)
- [Opening a project that already writes these lines](#opening-a-project-that-already-writes-these-lines)
- [What the Doctor checks](#what-the-doctor-checks)
- [The traps](#the-traps)

## One shape, four objects

Every word in this guide is built the same way, and it is worth reading once because it explains why
there is no table of property names to memorise anywhere in the plugin.

A word table says three things: what the **word** is, which **object** it lives on, and which
**spellings** it could take. Which of those spellings the class actually answers to is asked of
`ClassDB`, and so is the value every field opens on. That is why **Set Brightness** on a 2D light
writes `energy` and on a 3D light writes `light_energy`, and why nobody had to write that down twice.

The one thing that is not derived is the `ace_id` stem, because an `ace_id` is a compatibility
promise: a sheet saved today names it forever.

| The object | The node that holds it | What its words are about |
|---|---|---|
| `BaseMaterial3D` | a `MeshInstance3D` | colour, glow, roughness, metal, surface opacity, texture, blend, transparency, sides |
| `CanvasItemMaterial` | any `CanvasItem` | blending, light response |
| `Environment` | a `WorldEnvironment` | saturation, fog, glow, tone map, reflections, the backdrop, the sky |
| `CameraAttributes` | a `Camera3D`, or a `WorldEnvironment` for every camera without one | exposure, auto exposure, focus |
| `ParticleProcessMaterial` | a `GPUParticles2D` or `GPUParticles3D` | gravity, spread, speed, size, colour |

Two of those five rows are the emitter's own rather than its material's: **amount** and **lifetime**
are properties of the `GPUParticles` node. A reader saying "more sparks, and make them last longer"
should not have to know that, and the rows do not ask them to.

## The own-it courtesy

A material is a file. Two meshes pointing at one `.tres` point at ONE object in memory, so
recolouring the goblin the player hit recolours all twelve of them. The same is true of an
Environment shared by the cave and the town, of a `CameraAttributes` shared by the gameplay camera
and the cutscene camera, and of a process material shared by every torch in the level.

Every writing row in this guide therefore **takes this node its own copy first**, and the copy is in
the emitted code where you can read it rather than in a step you have to remember:

```gdscript
if material_override == null:
	material_override = get_active_material(0).duplicate() if get_active_material(0) != null else StandardMaterial3D.new()
elif not material_override.resource_path.is_empty():
	material_override = material_override.duplicate()
material_override.albedo_color = Color("c0392b")
```

Three promises are in those four lines. A mesh that already owns a copy of its own keeps it - a copy
has no `resource_path`, which is what makes a row that runs every frame take one copy and not sixty.
A mesh drawing with a shared file is given a copy of that file, and so is a mesh with that shared
file dropped straight into its `material_override` slot in the Inspector, which is the commonest way
a material is assigned at all. A mesh drawing with nothing at all is given a plain
`StandardMaterial3D` rather than the row reaching through a null.

The copy is taken **once**, and the reason is worth knowing: `material_override` being filled is
itself the flag, and a duplicate has no `resource_path` of its own. A row that runs every frame
therefore takes one copy and not sixty. Every table in this guide pays the courtesy the same way,
with the object it owns named in the row's own description.

There is one shipped row for taking the copy at a moment you choose, **Make The Environment This
Scene's Own**, and it is untouched. These rows simply never depend on it.

**The trap this removes.** The hand-written version is `material.albedo_color = Color.RED`, which
works perfectly in the test scene with one crate in it and recolours the whole level the moment
there are two. It is the single most common "why did that happen" in a Godot project, and none of
these rows can cause it.

## Nine words for what a 3D surface looks like

Pick a `MeshInstance3D` off the picker's **Material** shelf and the mesh lands in the object column.
Nine words, a **Set** row and a read-it-back expression for each, and a one-line **Fade** for the
five a surface can be walked to over time.

| The word | What it means | What it really writes |
|---|---|---|
| colour | the flat colour of the surface | `albedo_color` |
| glow | how much light the surface gives off | `emission_energy_multiplier`, with `emission_enabled` |
| roughness | dull cloth at 1, polished at 0 | `roughness` |
| metal | plastic at 0, bare metal at 1 | `metallic` |
| surface opacity | how solid the surface is | the alpha of `albedo_color`, with alpha transparency |
| texture | the picture the surface is drawn with | `albedo_texture` |
| blend | how the surface meets what is behind it | `blend_mode` |
| transparency | how being see-through is worked out | `transparency`, with a scissor threshold |
| sides | which faces are drawn | `cull_mode` |

Three of the nine are dropdowns over the engine's own enums. **Set Blend** reads mix, add, subtract,
multiply and premultiplied alpha. **Set Transparency** reads solid, alpha, alpha scissor, alpha hash
and alpha with depth pre-pass, and carries the scissor threshold on the same row. **Set Sides** reads
front, back and both. The words are what a reader sees; the `BaseMaterial3D` constant is what the row
writes, so the sheet and the emitted GDScript can never disagree.

<!-- caption: A hit flash on a crate, and the glow easing back down -->
```
On Body Entered  ->  Crate | Set colour to #ffffff
                 ->  Crate | Set glow to 4.0
                 ->  Crate | Fade glow to 0.0 over 0.35 s
```

```gdscript
func _on_body_entered(body: Node) -> void:
	if material_override == null:
		material_override = get_active_material(0).duplicate() if get_active_material(0) != null else StandardMaterial3D.new()
	elif not material_override.resource_path.is_empty():
		material_override = material_override.duplicate()
	material_override.albedo_color = Color("ffffff")
	if material_override == null:
		material_override = get_active_material(0).duplicate() if get_active_material(0) != null else StandardMaterial3D.new()
	elif not material_override.resource_path.is_empty():
		material_override = material_override.duplicate()
	material_override.emission_enabled = true
	material_override.emission_energy_multiplier = 4.0
	if material_override == null:
		material_override = get_active_material(0).duplicate() if get_active_material(0) != null else StandardMaterial3D.new()
	elif not material_override.resource_path.is_empty():
		material_override = material_override.duplicate()
	material_override.emission_enabled = true
	create_tween().tween_property(material_override, "emission_energy_multiplier", 0.0, 0.35)
```

Every row carries its own preamble, which is why the guard appears three times: a row is complete on
its own, so deleting the middle one leaves the other two correct. The **Fade** row carries the switch
as well - a fade that arrived on a material which had never glowed would otherwise tween a number
nothing reads.

**The switch is on the same line as the word.** Glow does nothing at all until `emission_enabled` is
true, and surface opacity does nothing until the material is in alpha transparency. Both facts are
written into the row rather than left as a second thing to remember, which is why **Set Glow** on a
material that has never glowed still glows.

**The trap this removes.** "I set `emission_energy_multiplier` and nothing happened" is a question
with one answer and no error message anywhere. The row cannot be spelled the broken way.

## The visor and not the helmet, surfaces and layers

A mesh imported from a model wears a material per surface, and the frozen **Set Mesh Material** paints
all of them at once. Four rows say which one you meant.

- **Set Material Of Surface** puts a material on one slot.
- **Material Of Surface** reads back what is on it.
- **Layer Over Surface** draws a second material over the first, through `next_pass`.
- **Remove Layer** takes that second material off again.

The two that write give the slot its own copy first. **Remove Layer** deliberately does not: a slot
still drawing with a shared file is left alone, because the layer sitting on it belongs to every mesh
wearing that file.

<!-- caption: A frost shell over the helmet's visor, and off again -->
```
On Frozen  ->  Knight | Layer res://fx/frost.tres over surface 2

On Thawed  ->  Knight | Remove the layer over surface 2
```

The slot is a plain number, and the help says why: a surface's name lives inside the imported mesh
resource rather than in the scene, and a mesh built at run time by the primitive builders has no
names at all. A dropdown of names would be a dropdown that is empty in half of all projects.

## A sprite has two words, not nine

A sprite's look is not a `BaseMaterial3D` with nine knobs. It is a `CanvasItemMaterial` with two, and
pretending otherwise would be nine rows that do nothing.

- **Set Blending** reads mix, add, subtract, multiply and premultiplied alpha. Add is what fire,
  sparks and light shafts want; multiply is what a shadow or a stain wants.
- **Set Light Response** reads normal, unshaded and light only. Unshaded keeps a HUD piece at full
  brightness whatever the 2D lights are doing.

**Blending** and **Light Response** read them back. Both are hosted on `CanvasItem`, so a sprite, a
`Control` and a `TileMapLayer` all have them.

<!-- caption: A muzzle flash added over the scene rather than mixed into it -->
```
On Fired  ->  MuzzleFlash | Set blending to add
          ->  MuzzleFlash | Set light response to unshaded
```

The sheet here is the muzzle flash's own, which is what puts its name in the object column:
both writing rows open with the own-it guard, so neither carries an **On node**.

```gdscript
func fire() -> void:
	if material == null:
		material = CanvasItemMaterial.new()
	elif material is CanvasItemMaterial and not material.resource_path.is_empty():
		material = material.duplicate()
	if material is CanvasItemMaterial:
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
```

**An item wearing a shader is left completely alone.** That last `if` is what does it: blending and
light response live inside a `ShaderMaterial` rather than on a property these rows could set, so the
rows write nothing at all rather than failing, and the reads are written as a cast so a shaded item answers with the value a
new material starts on rather than reaching through something that is not there. The Doctor says so
once, quietly, rather than a row going wrong in silence.

## Twenty-one words for the whole world

An `Environment` is where the atmosphere lives, and Godot spells almost none of it the way a person
would say it. Twenty-one words on any `WorldEnvironment` say it the way a person would, and the code
echo on the row shows the property underneath.

| The word | What it means |
|---|---|
| saturation, contrast, picture brightness | the colour adjustments, with `adjustment_enabled` written for you |
| exposure | how bright the finished picture is before the tone map |
| glow bloom, glow threshold, glow blend | which bright things bleed, and how the bleed is mixed back |
| fog floor, fog floor thickness | where fog sits, and how fast it thins out above that |
| aerial perspective, fog sun glow | distance haze, and the sun lighting the fog up |
| volumetric thickness, volumetric colour, volumetric reach, volumetric fog | real fog light travels through |
| reflections, indirect light, global illumination | the three screen-space and world-space lighting switches |
| backdrop | what is drawn behind everything, with a flat colour on the same row |
| tone map | how real brightness is squeezed into what a screen can show |
| colour grade | a picture that says what every colour turns into |

Every one of them is a **Set** and a read-it-back expression, and most of the numbers also have a
**Fade**. Two do not: **glow threshold** and **fog floor** are thresholds rather than amounts - a
number you cross rather than a number you travel along - so walking one over a second and a half says
nothing a reader wanted. The four that are switches are **Turn X On**, **Turn X Off** and **Is X On**,
because "Turn reflections off" is the sentence a reader writes and "Set reflections false" is the one
they have to decode.

<!-- caption: Walking into the poison cave, and back out of it -->
```
On Area Entered  ->  World | Fade saturation to 0.35 over 1.5 s
                 ->  World | Set fog floor to 2.0
                 ->  World | Set colour grade to res://looks/poison_lut.png

On Area Exited   ->  World | Fade saturation to 1.0 over 1.5 s
                 ->  World | Set colour grade to null
```

```gdscript
func _on_area_entered(area: Area3D) -> void:
	if environment == null:
		environment = Environment.new()
	elif not environment.resource_path.is_empty():
		environment = environment.duplicate()
	environment.adjustment_enabled = true
	create_tween().tween_property(environment, "adjustment_saturation", 0.35, 1.5)
```

**A reader never has to know** that saturation is `adjustment_saturation` and does nothing until
`adjustment_enabled` is true, that the fog's floor is `fog_height`, or that reflections are
`ssr_enabled`. Each row writes the switch its word needs on the same line as the word.

## Tone map, glow and the seven numbers

Two of the world's words are the ones people most often get wrong, so they are worth their own
section.

**Set Tone Map** is a dropdown of five: linear (no squeezing at all, which blows out), reinhard,
filmic, ACES and AgX. The two companion numbers ride on the same row, because they are the same
decision: **White at** is the brightness that comes out pure white, read by every tone map except
linear and AgX, and **AgX contrast** is read by AgX alone.

**The glow's blur levels are seven numbers nobody can read.** Godot spells them `glow_levels/1`
through `glow_levels/7` and reaches them through a call rather than a property, which is exactly the
shape a sheet cannot show. **Set Glow Levels** lays all seven down at once, as seven numbers you
write into an ordinary value field. Three shapes sit in that field's autocomplete as somewhere to
start:

| Shape | What it looks like | The seven numbers |
|---|---|---|
| tight | a neon sign glowing just around its own edge | 1.0, 0.6, 0.2, 0, 0, 0, 0 |
| balanced | the shape a new `Environment` already has | 0, 0.8, 0.4, 0.1, 0, 0, 0 |
| wide | a bright window washing light across the room | 0, 0.2, 0.4, 0.6, 0.8, 1.0, 1.0 |

Those three are **suggestions and not styles**. The field is not a list of the shapes there are:
it takes any seven numbers you type, and the three are only a starting point to type over - which
is the whole difference between a suggestion and three shapes chosen inside the plugin. **Set Glow
Level** sets any single one of the seven by hand as well.

<!-- caption: The neon sign, and the sun through the window -->
```
On Ready  ->  World | Set glow levels to tight
          ->  World | Set glow blend to screen
          ->  World | Set glow threshold to 0.9
```

```gdscript
func _ready() -> void:
	if environment == null:
		environment = Environment.new()
	elif not environment.resource_path.is_empty():
		environment = environment.duplicate()
	environment.glow_enabled = true
	var __glow_1: PackedFloat32Array = PackedFloat32Array([1.0, 0.6, 0.2, 0.0, 0.0, 0.0, 0.0])
	for __level_1: int in range(7):
		environment.set_glow_level(__level_1, __glow_1[__level_1])
```

The loop counts from 0 because `set_glow_level` takes an index, not the number the Inspector prints:
`glow_levels/1` is index 0 and `glow_levels/7` is index 6. Set Glow Level, the row that reaches a
single one of them, lets you say the Inspector's number and subtracts for you - level 3 emits
`set_glow_level((3) - 1, ...)`.

**The trap this removes.** Turning the glow up by raising its strength is what most projects do, and
it washes the whole screen. The shape of the blur is the dial that decides whether a glow reads as a
neon sign or as fog, and it is unreachable without a call.

## Fog, near and far

There are two fogs in Godot and they are not the same thing, which is worth saying out loud because
one of them is free and one of them is not.

**Ordinary fog** is a depth effect: it tints the picture by how far away each pixel is. **Fog floor**
is the height it sits at, **fog floor thickness** is how fast it thins out going up - 0 leaves it the
same all the way, a small number keeps it lying on the ground the way a morning mist does -
**aerial perspective**
blends distant things toward the sky colour, and **fog sun glow** is the sun lighting the fog up
around it. All four write `fog_enabled` for you, and all four draw on every renderer.

**Volumetric fog** is real: light travels through it, a spot light makes a shaft in it, and it costs
what a volume costs. **Volumetric thickness**, **volumetric colour** and **volumetric reach** are its
numbers and **Turn Volumetric Fog On** is its switch, and every one of those four rows says in its own
description that it is Forward+ only.

<!-- caption: The valley at dawn, with the fog lit by the sun -->
```
On Ready  ->  World | Set fog floor to 4.0
          ->  World | Set fog floor thickness to 0.08
          ->  World | Set aerial perspective to 0.6
          ->  World | Set fog sun glow to 0.4
```

The frozen **Turn Fog On**, **Turn Fog Off**, **Set Fog Thickness** and **Fade The Glow** rows are
untouched and still say what they always said. These words land beside them.

## The switches, and what each renderer can draw

Four of the world's words are Forward+ features. On Mobile and on Compatibility the flag is set, the
renderer ignores it, nothing errors, and nothing looks different. That is a silence a game can ship
with by accident, so it is said three times.

| The word | The property | Mobile | Compatibility |
|---|---|---|---|
| reflections | `ssr_enabled` | not drawn | not drawn |
| indirect light | `ssil_enabled` | not drawn | not drawn |
| global illumination | `sdfgi_enabled` | not drawn | not drawn |
| volumetric fog | `volumetric_fog_enabled` | not drawn | not drawn |

1. **The row says so**, in its description and in the help words on the selected row.
2. **The sheet can ask.** The frozen **Uses Modern Renderer** cannot tell Forward+ from Mobile;
   **Renderer Is** can, which is the question a graphics menu asks before it offers a setting only
   one renderer draws.
3. **The Doctor says it once**, as an information note in the Ship It section naming the first such
   row in a file and the renderer the project is actually built for.

Four switches also have a matching quality that Godot keeps on the `RenderingServer` rather than on
the `Environment`. Occlusion, indirect light, global illumination and reflections each gain a
**Turn X On At Quality** row that writes the flag and the quality call together. Occlusion, the one
of the four with no switch word of its own, gains **Turn Occlusion Off** and **Is Occlusion On** as
well.

<!-- caption: A graphics menu that only offers what this build can draw -->
```
On Ready                    ->  Set setting reflections to true
  Renderer is forward_plus

On Reflections Toggled      ->  World | Turn reflections on at medium
  Setting reflections is true

On Reflections Toggled      ->  World | Turn reflections off
  Else
```

Three details in that sheet are worth reading twice. **Renderer Is** is a condition, so it sits in the
left lane rather than in a value field. **Set Setting** and **Setting Is** come from the Game Settings
pack and run through its autoload, so neither carries an object column. And the quality is a dropdown
of the engine's own constants read out as words - no roughness, low, medium, high - so the row says
`medium` and never a bare number.

## The sky is three objects past the node

Getting to a sky colour in Godot means a `WorldEnvironment`, its `Environment`, that environment's
`Sky`, and that sky's `ProceduralSkyMaterial`. Five words say the last step in one row: **sky top**,
**sky horizon**, **sky ground**, **sun size** and **sky energy**, each with a Set, a read and a Fade.

Two rows install a sky at all. **Use Procedural Sky** and **Use Panorama Sky** put the sky in place
and set the backdrop that draws it, which is the pair of facts a person forgets in that order.

<!-- caption: Sunset, over ten seconds -->
```
On Dusk Started  ->  World | Use procedural sky
                 ->  World | Fade sky top to #1b2a4a over 10 s
                 ->  World | Fade sky horizon to #e8743c over 10 s
                 ->  World | Fade sun size to 4.0 over 10 s
```

**Every one of the five refuses to guess.** Each write owns the environment, the `Sky` and the sky
material in that order, and each is written as an `is ProceduralSkyMaterial` guard, so a scene
drawing a flat colour, a panorama, or somebody's own sky shader is left completely alone. The row
does nothing rather than erroring.

That silence is the second thing the Doctor watches: a file that sets the sky's colours and never
makes the sky the backdrop is told so, with the door that fixes it.

**The trap this removes.** Setting `sky_top_color` on a world whose backdrop is a flat colour is four
correct lines of code that draw absolutely nothing, and there is no message anywhere to say why.

## The lens, exposure and what stays sharp

Exposure comes in two flavours and they belong to different objects. The **world's** exposure is
applied to the finished picture and is one of the twenty-one words above. The **camera's** exposure
is how much light this lens lets in, and two cameras in one scene can see the same room differently
because of it.

Fifteen rows are the lens.

| The row | What it does | Where it lives |
|---|---|---|
| **Set Camera Exposure**, **Camera Exposure**, **Fade Camera Exposure** | 1 is untouched, 2 is twice as bright | on a `Camera3D`, and on a `WorldEnvironment` for every camera without a lens of its own |
| **Turn Auto Exposure On** / **Off**, **Is Auto Exposure On** | the eye adjusting when the player walks out of a cave | the same two hosts |
| **Focus On**, **Focus Everywhere**, **Focus Distance** | what stays sharp, and what goes soft behind it | a `Camera3D` only |

**Turn Auto Exposure On** carries three companions on the same row, because they are the same
decision: how fast the lens adjusts, and the least and the most light it will adjust between.

**Focus On is one sentence a person says and three numbers the engine wants.** It takes a node to
measure the distance to, or the distance itself in metres, so a cutscene can focus on the speaker and
a menu can focus on a fixed plane:

<!-- caption: The shot that says look here, and the way back out of it -->
```
On Dialogue Started  ->  Camera | Focus on Speaker, soft 3.0 m past it, over 0.6 s

On Dialogue Ended    ->  Camera | Focus everywhere over 0.6 s
```

```gdscript
func _on_dialogue_started() -> void:
	if attributes == null:
		attributes = CameraAttributesPractical.new()
	elif not attributes.resource_path.is_empty():
		attributes = attributes.duplicate()
	var __subject_1 = $Speaker
	if attributes is CameraAttributesPractical:
		attributes.dof_blur_far_enabled = true
		attributes.dof_blur_far_distance = global_position.distance_to(__subject_1.global_position) if __subject_1 is Node3D else float(__subject_1)
		create_tween().tween_property(attributes, "dof_blur_far_transition", 3.0, 0.6)
```

**Practical, never physical.** A lens slot holding nothing is given a `CameraAttributesPractical`,
whose blur is metres and whose exposure is a multiplier, rather than the physical one that would hand
a reader a focal length, an f-stop, an aperture and a shutter speed to answer a question they asked in
one word. A slot somebody deliberately filled with a physical lens keeps it, and every line only a
practical lens can answer sits inside a guard that asks first. The ordinary property row is still the
right row for anyone who knows what f/16 means.

**Focus Everywhere puts the blur amount back** once the far blur is off, so the next **Focus On**
starts from the same lens the first one did.

Auto exposure is Forward+ only, and says so the same three ways the world's switches do.

## A look is a file you author

The words above each say one thing. A **look** says all of them at once: it is an `Environment`
resource somebody built in the Inspector and saved, and four rows put one on, cross over to one,
answer which one is being worn, and hear the crossing finish.

- **Use World Look** puts a whole saved world on at once.
- **Blend To World Look** crosses over to one instead of cutting to it.
- **Current World Look** answers the path of the look this node's world came from.
- **On World Look Blended** runs when a crossing lands, carrying the look it landed on.

**Nothing here is a style, and that is deliberate.** No look ships with this plugin and none is named
in it. You make one the ordinary Godot way: set a `WorldEnvironment` up until the scene looks right,
save its `Environment` out as a `.tres`, and the rows take the path to it. Rename it, put it in
version control, send it to somebody else, edit it in the Inspector.

**Neither artist file is touched.** Both rows load the file, take a deep copy, and put the copy on
the node, so the look on disk is exactly as it was saved and the world being worn belongs to this
scene.

<!-- caption: Crossing from the surface into the cave, and letting the player move once it lands -->
```
On Cave Entered        ->  WorldEnvironment | Blend to world look res://looks/cave.tres over 2.0 s

On World Look Blended  ->  Player | Set can move to true
```

**What a crossfade really is, said honestly.** Half of an `Environment` is numbers, vectors and
colours, and those can be walked: the fog thins, the saturation drains, the sky goes orange. The other
half is switches and modes - glow on or off, which tone map, which sky - and there is nothing between
two of those to walk through. So the numbers are tweened over the seconds asked for and the rest is
CUT at the halfway point, where a cut is least visible. The row says so rather than pretending the
whole world dissolves.

The work itself is a real file a debugger can step into, plain typed GDScript with no plugin class
named anywhere in it, exactly like the placement helper the spawn rows call.

## Particles, seven words on two objects

A particle effect is two objects, and that is the whole difficulty this table exists to hide. How
many particles there are and how long each one lives belong to the **node**; how fast they set off,
how wide they fan out, which way they fall, how big they are and what colour they are belong to a
`ParticleProcessMaterial` hanging off it.

Seven words, in both dimensions, on `GPUParticles2D` and `GPUParticles3D`.

| The word | Where it lives | What it means |
|---|---|---|
| gravity | the material | which way they fall and how hard, as a direction with a length |
| spread | the material | how wide they fan out, in degrees. 0 is a jet, 180 is every direction |
| speed | the material | how fast a new particle sets off, as a range |
| size | the material | how big a new particle is, as a range |
| colour | the material | the tint every particle is multiplied by |
| lifetime | the node | how many seconds one particle lasts |
| amount | the node | how many the emitter keeps in the air at once |

**Two of the words are really two numbers.** A speed is `initial_velocity_min` and
`initial_velocity_max`; a size is `scale_min` and `scale_max`. A row offering only one half of either
would leave the other one wherever it happened to be, which is exactly how an effect ends up with
every particle at one identical speed. So both ends are fields on the same row, walked by the same
fade, and read back by expressions of their own: **Slowest Particle Speed** and **Fastest Particle
Speed**, **Smallest Particle Size** and **Biggest Particle Size**.

<!-- caption: Rain turning into a gale, on the emitter's own sheet -->
```
On Storm Started  ->  Rain | Set gravity to Vector2(300, 900)
                  ->  Rain | Set amount to 1200
                  ->  Rain | Fade colour to #7fa8d0 over 3.0 s
```

```gdscript
func _on_storm_started() -> void:
	if process_material == null:
		process_material = ParticleProcessMaterial.new()
	elif process_material is ParticleProcessMaterial and not process_material.resource_path.is_empty():
		process_material = process_material.duplicate()
	if process_material is ParticleProcessMaterial:
		process_material.gravity = Vector2(300, 900)
	amount = 1200
```

**Why amount does not fade, when every other word here does.** Writing `amount` makes Godot throw the
whole particle buffer away and build a new one. Walking it over half a second would do that thirty
times, and the effect would stutter every one of them. So amount is set, read, and left alone, and the
row says why rather than offering a fade that would quietly cost frames.

**An emitter driven by a particle shader is left completely alone**, for the same reason a shaded
sprite is: gravity and spread live inside that shader and there is no property here to set. Every
material write sits inside the guard that asks.

## Every row, by name

The sections above are the vocabulary in the order a game needs it. This is the same vocabulary as a
list, so a row you half remember can be found by its own name. The names are the ones the picker
shows; the sentence a row reads as in the sheet is usually shorter, because the object column has
already said which node.

**Material - 31 rows, on a `MeshInstance3D` unless the last four say otherwise.**

| Row | What it does |
|---|---|
| Set Colour, Colour, Fade Colour | the flat colour of the surface, before any light falls on it |
| Set Glow, Glow, Fade Glow | how hard the surface gives off light of its own |
| Set Roughness, Roughness, Fade Roughness | how scattered the reflections are: 0 a mirror, 1 chalk |
| Set Metal, Metal, Fade Metal | how metal the surface reads: 0 plastic, 1 bare metal |
| Set Surface Opacity, Surface Opacity, Fade Surface Opacity | how solid the surface is: 1 solid, 0 invisible |
| Set Texture, Texture | the picture painted over the surface |
| Set Blend, Blend | how the surface is mixed with what is drawn behind it |
| Set Transparency, Transparency | how the surface handles being see-through at all |
| Set Sides, Sides | which faces of the surface are drawn |
| Set Material Of Surface, Material Of Surface | one surface's own material, leaving the others alone |
| Layer Over Surface, Remove Layer | a second material drawn over one surface, and off again |
| Set Blending, Blending | how a sprite is mixed with what is behind it (any `CanvasItem`) |
| Set Light Response, Light Response | how the 2D lights reach a sprite (any `CanvasItem`) |

**Environment - 65 rows, on a `WorldEnvironment`.** Each of the first thirteen words is a Set, a
read-it-back expression and, where the row is marked, a Fade.

| Row | What it does |
|---|---|
| Set / Fade Saturation, Saturation | how colourful the whole picture is: 1 untouched, 0 grey |
| Set / Fade Contrast, Contrast | how far the darks and the lights are pushed apart |
| Set / Fade Picture Brightness, Picture Brightness | how bright the finished picture is after every light has spoken |
| Set / Fade Exposure, Exposure | how much light the camera lets in before the picture is made |
| Set / Fade Glow Bloom, Glow Bloom | how much of the picture bleeds into the glow, not just the bright parts |
| Set Glow Threshold, Glow Threshold | how bright a thing has to be before it glows at all (no Fade) |
| Set Fog Floor, Fog Floor | the height the fog lies at, in metres (no Fade) |
| Set / Fade Fog Floor Thickness, Fog Floor Thickness | how fast the fog thins out above its floor |
| Set / Fade Aerial Perspective, Aerial Perspective | how much of the sky's colour the far distance picks up |
| Set / Fade Fog Sun Glow, Fog Sun Glow | how much the fog lights up around the sun |
| Set / Fade Volumetric Thickness, Volumetric Thickness | how thick the air itself is, for fog that lights up |
| Set / Fade Volumetric Colour, Volumetric Colour | the colour the thick air is, before light falls through it |
| Set / Fade Volumetric Reach, Volumetric Reach | how far from the camera the thick air is worked out |
| Set Backdrop, Backdrop | what is drawn behind everything else |
| Set Tone Map, Tone Map | how real brightness is squeezed into the range a screen shows |
| Set Glow Blend, Glow Blend | how the glow is mixed back over the picture |
| Set Colour Grade, Colour Grade | a picture that says what every colour in the scene turns into |
| Set Glow Levels, Set Glow Level | all seven blur levels at once, or one of them by hand |
| Turn Volumetric Fog On / Off, Is Volumetric Fog On | the fog that fills the air rather than sitting flat |
| Turn Reflections On / Off, Are Reflections On | shiny surfaces reflecting what is already on screen |
| Turn Indirect Light On / Off, Is Indirect Light On | a lit surface throwing its colour onto its neighbours |
| Turn Global Illumination On / Off, Is Global Illumination On | light bouncing around the whole scene by itself |
| Turn Occlusion On At Quality, Turn Occlusion Off, Is Occlusion On | corners and creases darkened, and how carefully |
| Turn Indirect Light / Global Illumination / Reflections On At Quality | the switch and the `RenderingServer` quality in one row |
| Use World Look, Blend To World Look, Current World Look, On World Look Blended | a whole saved world put on at once, or crossed to |

**Sky - 17 rows, on the same `WorldEnvironment`.** Every one of the five colours and numbers has a
Set, a read and a Fade.

| Row | What it does |
|---|---|
| Set / Fade Sky Top, Sky Top | the colour of the sky straight overhead |
| Set / Fade Sky Horizon, Sky Horizon | the colour the sky fades to where it meets the ground |
| Set / Fade Sky Ground, Sky Ground | the colour drawn below the horizon |
| Set / Fade Sun Size, Sun Size | how wide the sun's disc is drawn, in degrees |
| Set / Fade Sky Energy, Sky Energy | how bright the whole sky is: 1 is untouched |
| Use Procedural Sky | Godot's own drawn sky behind everything, backdrop and all |
| Use Panorama Sky | one picture wrapped around the whole world as the sky |

**Camera attributes - 15 rows.** The first six ship twice: once on a `Camera3D` for that camera, and
once on a `WorldEnvironment` for every camera that has none of its own. The names are the same on
both, so a sheet reads the same either way.

| Row | What it does |
|---|---|
| Set / Fade Camera Exposure, Camera Exposure | how much light the lens lets in: 1 untouched, 2 twice as bright |
| Turn Auto Exposure On / Off, Is Auto Exposure On | the lens opening and closing by itself with the picture |
| Focus On, Focus Everywhere | what the sharp part of the picture sits on, and off again |
| Focus Distance | how many metres away the picture stops being sharp |

**Particles - 55 rows.** The seven words ship twice, on `GPUParticles2D` and `GPUParticles3D`, with
the same names on both; the switches at the top of the table also have `CPUParticles2D` twins.

| Row | What it does |
|---|---|
| On Particles Finished | fires once when a one-shot burst finishes playing |
| Set Emitting, Is Emitting | starts or stops the emitter, and asks whether it is running |
| Restart / Burst | restarts the particle system from the beginning |
| Set One-Shot | a single burst then stop, rather than looping |
| Set Amount, Amount | how many particles the emitter spawns |
| Set Speed Scale | speeds the whole effect up or slows it down |
| Set / Fade Particle Gravity, Particle Gravity | which way the particles fall, and how hard |
| Set / Fade Particle Spread, Particle Spread | how wide the particles fan out, in degrees |
| Set / Fade Particle Speed, Slowest / Fastest Particle Speed | how fast a new particle sets off, both ends |
| Set / Fade Particle Size, Smallest / Biggest Particle Size | how big a new particle is, both ends |
| Set / Fade Particle Colour, Particle Colour | the colour every particle is tinted |
| Set / Fade Particle Lifetime, Particle Lifetime | how many seconds one particle lasts before it goes out |
| Set Particle Amount, Particle Amount | how many particles the emitter keeps in the air (no Fade) |

## Opening a project that already writes these lines

Every word in this guide **reads backwards**. A hand-written property write opens as the sentence the
picker would have made, derived from the same tables the rows are built from, so a word added to a
table is read back with nothing added anywhere.

| What the file says | What the sheet reads |
|---|---|
| `material_override.albedo_color = Color.RED` | **Crate ▸ Set colour to red** |
| `environment.fog_height = 4.0` | **Set fog floor to 4** |
| `environment.sky.sky_material.sky_top_color = Color.RED` | **Set sky top to red** |
| `attributes.exposure_multiplier = 2.0` | **Set camera exposure to 2** |
| `process_material.spread = 45.0` | **Set spread to 45** |

The file itself is unchanged: opening a `.gd` as a sheet and saving it untouched reproduces it byte
for byte, and a line nothing claims stays an honest verbatim row rather than a mangled one.

**Two reaches for a surface, and only two**, because only these two are unambiguous:
`material_override` is `GeometryInstance3D`'s and `get_active_material(N)` is `MeshInstance3D`'s. A 2D
item's `material.blend_mode` is deliberately not claimed - a mesh's material spells `blend_mode` too,
and a bare `material.` line cannot say which of the two words it means.

A value that is one of a fixed list of engine constants reads as the plain word the dropdown shows
rather than repeating the constant back, so `tonemap_mode = Environment.TONE_MAPPER_ACES` reads
**Set tone map to ACES**.

## What the Doctor checks

Findings are quiet. The only signal in the sheet itself is the amber row state; the words and the
fix doors live in the Doctor's triage inbox and in the selected row's help strip.

| The finding | Where it is filed | What it says |
|---|---|---|
| a Forward+ row in a Mobile or Compatibility project | Ship It, information | which row, and the renderer this project is actually built for |
| a file that colours the sky and never makes the sky the backdrop | Ship It | with the door that sets the backdrop |
| a material word on a mesh whose file other meshes wear | Effects, information | no fix door, because every material word takes its own copy first |
| a blending or lighting word on a 2D item wearing a shader | Effects | the row writes nothing, and this says so out loud |

**"Who else wears this material" now answers for a mesh.** The project index used to read `material`,
the `CanvasItem` member, and stop there, so the question answered nothing at all for a 3D scene
however many meshes were sharing one `.tres`. It now reads `material_override` and
`surface_material_override/N` off the node headers, and follows `next_pass` through the material
chain, so a layer laid over a surface counts its wearers too.

## The traps

- **A resource is shared until somebody copies it.** Every writing row in this guide copies first and
  shows you the copy. A hand-written line beside them does not, and that is the difference between
  recolouring the goblin the player hit and recolouring all twelve.
- **A word's switch is part of the word.** Glow needs `emission_enabled`, saturation needs
  `adjustment_enabled`, fog floor needs `fog_enabled`, and the sky's colours need the sky to be the
  backdrop. Setting the number alone is the commonest silent nothing in a Godot project, and no row
  here can be spelled that way.
- **A row whose template opens with an `if` has no "On node" field.** The own-it lines are a guard,
  and a guard cannot be written around a node named in the middle of it, so those rows act on the node
  the sheet is attached to. A read that is a plain member read carries the field, and that is every
  one of the environment reads - all twenty-two of them, the fog and glow and colour numbers and the
  five **Is X On** conditions alike - plus **Material Of Surface**, the camera's **Camera Exposure**,
  **Is Auto Exposure On** and **Focus Distance**, and the emitter's **Is Emitting**, **Amount**,
  **Particle Lifetime** and **Particle Amount**. A read that reaches through a resource instead, like
  **Particle Gravity**, **Blending** or any of the five sky colours, opens with the same guard and
  answers for the sheet's own node.
- **Forward+ only means silence, not an error.** Reflections, indirect light, global illumination,
  volumetric fog and auto exposure are set and ignored on Mobile and Compatibility. Ask **Renderer Is**
  before offering them in a settings menu.
- **Setting `amount` on an emitter rebuilds its whole buffer.** Use it at a moment, never every frame,
  and never in a loop.
- **A look is a file, not a preset.** Nothing named ships here. If you want a house look, author one
  and put it in version control, where the rest of your team can edit it.
- **The environment on a `WorldEnvironment` is usually a file two scenes are sharing.** The rows take
  the copy; a hand-written line in the same function does not, and mixing the two in one file is how a
  cave's fog follows the player out into the town.
