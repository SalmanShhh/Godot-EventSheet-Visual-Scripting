# Built-in Module Guides

Deep-dive guides for the **built-in vocabulary** - the roughly 1,090 verbs that are already in the
picker on a fresh install, before you enable a single behavior pack. They are authored as the
vocabulary modules in `addons/eventforge/registration/modules/`, one file per subject, and this
index groups their guides by what you are trying to do rather than by which file they came from.

Each guide covers when to reach for that vocabulary, its full verb reference (name, what it does,
and the exact GDScript each row ships as), fifteen or more worked use cases written as event-sheet
rows, and the tips and mistakes that bite in practice.

Nothing here needs installing, attaching or enabling. Every verb compiles to plain GDScript with
zero plugin dependency, so a sheet built entirely from built-in vocabulary keeps running after the
plugin is removed.

These are the **per-verb reference**. The narrative, learn-by-doing versions of four of these
subjects - lists, text, values, and raycasting - live in the main
[documentation index](../README.md) under "Learn by doing"; start there if you want the story, and
come here for the complete verb list.

Looking for a bundled behavior pack instead? See the [addon guides index](../Addons/README.md).

## Getting things moving

- [Making Things Move In 2D](Making-Things-Move-In-2D.md) - move a 2D node by hand, by velocity, by impulse, or by a ready-made motion, and read back where things are and how fast they are going.
- [Working In 3D](Working-In-3D.md) - Node3D transforms, CharacterBody3D and RigidBody3D, cameras and field of view, and building meshes at runtime.
- [Animation And Sprites](Animation-And-Sprites.md) - play, stop, scrub and queue AnimationPlayer clips, flip a sprite, and drive an AnimationTree state machine.
- [Timers, Waiting And Cooldowns](Timers-Waiting-And-Cooldowns.md) - Wait, Every X Seconds, cooldowns, buffered presses, tweens, and the engine's own clocks.
- [Working With Vectors And Directions](Working-With-Vectors-And-Directions.md) - build, measure, aim, turn, blend and cap positions and directions without writing the distance formula out.

## Values and data

- [Setting And Changing Variables](Setting-And-Changing-Variables.md) - the plain arithmetic set, the eased and guarded forms, safe fallbacks, and scratch locals and constants.
- [Comparing Values](Comparing-Values.md) - the condition rows an operator cannot express: method comparisons, tolerances, emptiness and type tests.
- [Doing Math And Randomness](Doing-Math-And-Randomness.md) - every number verb in one place, from Clamp and Lerp to degree-based trig and seeded procedural values.
- [Working With Lists](Working-With-Lists.md) - the whole Array vocabulary, the higher-order verbs (Filter, Map, Reduce, Any Match, All Match), typed lists, and the loop controls.
- [Working With Records](Working-With-Records.md) - Dictionaries: values addressed by name, safe reads with defaults, key sets, and the shapes a save file and a spreadsheet row arrive in.
- [Copying, Sharing And Remembering Values](Copying-Sharing-And-Remembering-Values.md) - share codes, the OS clipboard both ways, cloning a live node, and putting a named copy of a value aside.
- [Working With Files](Working-With-Files.md) - read and write text on disk, walk a folder, and cross the JSON boundary in both directions.
- [Reading Spreadsheets And Data Assets](Reading-Spreadsheets-And-Data-Assets.md) - a `.csv` read as records, a folder of `.tres` read as content, and the verbs that explain why a load went wrong.

## Text and localisation

- [Working With Text](Working-With-Text.md) - cut a string apart, search and test it, convert it to and from numbers, and reach for RegEx only when a fixed marker is not enough.
- [Making Text Readable On Screen](Making-Text-Readable-On-Screen.md) - shorten to fit, group digits, line up columns, translate in the right order, and check the text physically fits its pixels.
- [Localising Your Game](Localising-Your-Game.md) - swap locales, look up translated text and plurals, localise the assets around the text, and ask whether the catalog is actually finished.

## Input and UI

- [Reading Keyboard, Mouse And Gamepad](Reading-Keyboard-Mouse-And-Gamepad.md) - ask a physical device what it is doing right now: keys, pointer, sticks, touches, and rumble.
- [Setting Up And Rebinding Controls](Setting-Up-And-Rebinding-Controls.md) - named actions, the layer to build controls on, and the InputMap verbs a rebinding screen is made of.
- [Buttons, Sliders, Labels And Menus](Buttons-Sliders-Labels-And-Menus.md) - the Control vocabulary a menu or HUD is driven by: button triggers, focus navigation, getters and setters, layout and theme overrides.
- [Game Options And The Window](Game-Options-And-The-Window.md) - the OS window, vsync and the frame-rate cap, and the small persistence pair that makes a setting survive a restart.

## World and physics

- [Collisions, Joints And World Physics](Collisions-Joints-And-World-Physics.md) - what a body just hit, area overlaps, collision layers and masks, joints, and world-level gravity.
- [Raycasting And Overlaps In 2D](Raycasting-And-Overlaps-In-2D.md) - line of sight, ledge probes, hitscan shots, ground checks and clicks, through all four kinds of 2D cast.
- [Raycasting And Overlaps In 3D](Raycasting-And-Overlaps-In-3D.md) - what the gun is pointing at, what the cursor is over, and what the explosion caught, through all five kinds of 3D cast.
- [Working With Tilemaps](Working-With-Tilemaps.md) - paint, erase and query TileMapLayer cells, and convert between pixel positions and grid coordinates.

## Scene and nodes

- [Finding And Rearranging Nodes](Finding-And-Rearranging-Nodes.md) - spawn, reparent, reorder, rename and free nodes, and pick the ones you need by child, name pattern or group.
- [Scenes, Pausing And Turning Nodes Off](Scenes-Pausing-And-Turning-Nodes-Off.md) - change what is on screen, pause the whole game, and the difference between hidden, disabled and paused.
- [Groups, Tags And Systems](Groups-Tags-And-Systems.md) - a group as a tag, as a set to count and total, and as a system you run one method over.
- [Triggers, Signals And When Rows Run](Triggers-Signals-And-When-Rows-Run.md) - the lifecycle and per-frame triggers, scene-tree and Area signals, On Signal and Emit Signal, and the gates that turn "every tick" into "once".

## Look and sound

- [Sound And Music](Sound-And-Music.md) - one-shots, placed players, and the bus mixer: volumes, mutes, effects and crossfades.
- [Cameras, Graphics And Screenshots](Cameras-Graphics-And-Screenshots.md) - which camera is looking, how wide its view is, how the frame is rendered, and saving the result as a PNG.
- [Particles And Drawing On Screen](Particles-And-Drawing-On-Screen.md) - drive GPU and CPU emitters from rows, and paint lines, circles, cones, stamps and ribbons onto any node's own canvas.
- [Colors, Gradients And Curves](Colors-Gradients-And-Curves.md) - everyday colour maths for flashes, fades and rarity tints, plus smooth ramps and hand-drawn curves.

## Tooling and debugging

- [Debugging And Printing](Debugging-And-Printing.md) - the three console streams, the combo-driven Log family, assertions, breakpoints, a scene-tree dump, and live runtime readouts.
- [Automating The Editor](Automating-The-Editor.md) - sheets that are tools: open, edit and save scenes, write resources, rescan the FileSystem, and bake on project export.
- [Calling Your Own Code From Rows](Calling-Your-Own-Code-From-Rows.md) - the structured escape hatch: set any property, call any method, evaluate any expression, build a callable, and reach a behaviour's host node.
