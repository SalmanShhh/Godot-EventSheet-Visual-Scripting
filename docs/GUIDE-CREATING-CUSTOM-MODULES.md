# Creating custom ACE modules

A **helper ACE module** is the fastest way to add your own vocabulary to Godot EventSheets. Drop one
file into `addons/eventforge/registration/modules/` and its Actions, Conditions, and Expressions show
up in the picker on the next load - no registration code, no wiring. This guide walks the whole thing:
scaffolding a module, the anatomy of an ACE, the template rules, and the two contracts you must keep.
For the design side - naming, parameters, and descriptions that read well in the picker - see
[Designing user-friendly ACEs](GUIDE-DESIGNING-USER-FRIENDLY-ACES.md).

If you want to add a whole *pack* (a behavior you attach to a node, or an autoload with state), that is
a different tool - see [Building on EventSheets](GUIDE-BUILDING-ON-EVENTSHEETS.md). A module is for
stateless vocabulary that bakes to a line or two of plain Godot: "set the window title", "start a vibration",
"give me the move vector". If your idea needs to remember something between frames, it wants a pack.

## Table of Contents

1. [What a module is](#1-what-a-module-is)
2. [Scaffold one in 30 seconds](#2-scaffold-one-in-30-seconds)
3. [The anatomy of an ACE](#3-the-anatomy-of-an-ace)
4. [Parameters](#4-parameters)
5. [Template rules](#5-template-rules)
6. [The two contracts](#6-the-two-contracts)
7. [Section descriptions](#7-section-descriptions)
8. [Worked examples](#8-worked-examples)
9. [Testing your module](#9-testing-your-module)
10. [Tips and common mistakes](#10-tips-and-common-mistakes)

## 1. What a module is

Every builtin vocabulary (Debug, Audio, Editor Tools, Game Window, ...) is one file under
`addons/eventforge/registration/modules/`. Each file is a `@tool class_name` script with a single
required method:

```gdscript
static func get_descriptors() -> Array[ACEDescriptor]:
```

The registry (`EventForgeBuiltinACEs`) scans that folder, loads every file that has `get_descriptors`,
and concatenates the results. So **adding a module is just dropping a file** - there is no central list
to edit. Remove the file and its ACEs are gone. The file is self-contained: copy it into another
project with `ace_factory.gd` and it works.

An ACE (Action, Condition, Expression) is a row a user picks in the sheet. It has a display name, a
category it groups under, some parameters, and - the important part - a **codegen template**: the exact
GDScript it bakes to. A sheet never carries your module at runtime; it carries the plain Godot your
template produced.

## 2. Scaffold one in 30 seconds

Do not start from a blank file. The repo ships a scaffolder:

1. Open `tools/new_ace_module.gd` and set `MODULE_NAME` to a snake_case name, for example `"weather"`.
2. Run it:

   ```
   godot --headless --path . --script tools/new_ace_module.gd
   ```

   It writes `addons/eventforge/registration/modules/weather_aces.gd` - a compiling module with one
   example Action, Condition, and Expression, plus a section description. It never overwrites an
   existing file.
3. Because a new `class_name` was added, regenerate the editor's class cache once:

   ```
   godot --editor --headless --path . --quit-after 3
   git checkout -- project.godot
   ```
4. Open the file and replace the three example ACEs with your own.

Now you have something that already builds and passes the gates. Edit from there.

## 3. The anatomy of an ACE

Every ACE is ONE CALL, and the call is named after the kind of row it makes:

```gdscript
const F := preload("res://addons/eventforge/registration/ace_factory.gd")

F.act(
	"SetWindowTitle",                # ace_id - the FROZEN identity string (never reuse or rename)
	"Set Window Title",              # label - the picker label
	"get_window().title = {title}",  # template - the GDScript it bakes to, with {param} slots
	"Game Window",                   # group - the picker section it groups under
	"set window title {title}",      # reads_as - the row summary, with {param} placeholders
	"Sets the title on the game window's own bar.",  # description - the help the info panel shows
).param("title", "\"My Game\"", "Title", "The new window title.", "expression")
```

Written on one line, which is how the built-in modules are written, that is the whole ACE.

The four makers, one per kind of row:

| Maker | What it is | Example template |
|------|-----------|------------------|
| `F.act` | Does something (a statement). | `get_window().title = {title}` |
| `F.cond` | A boolean test used in an event's condition lane. | `{value} > 0` |
| `F.expr` | Returns a value you use inside another field. | `absf({value})` |
| `F.trig` | Fires an event when a Godot signal or callback runs. It takes the SIGNAL name where the other three take a template, because a trigger emits none. | signal `"ready"` |

Two more arguments follow `description` and are rarely written: `host`, the Godot class this row
belongs to (the picker files it under that class instead of the group), and `provider`, the name the
row publishes under - `"Core"` for a builtin module, which is the default.

**The long form is still there and always will be.** `F.make_descriptor(provider, ace_id, label,
kind, template, signal, params, category, display_text, node_type)` takes every field in position,
and the makers compile to it. Reach for it when the row's own shape needs it - when its parameter
list comes from a shared helper rather than being written out, or when its template is a string with
a real newline in it that cannot be folded onto one line.

Chain these onto the descriptor to shape it further:

- `.described("Plain-language help shown in the info panel.")` - the same text the maker's
  `description` argument sets, for a descriptor built with the long form.
- `.featured()` - bold it and float it to the top of its category (for the one or two rows a beginner reaches for first).
- `.deprecated("Use X instead.", "Core::NewId")` - hide it from the picker but keep it compiling (see the freeze contract).
- `.project_scoped()` - this row's CHOICES come out of the open project rather than out of your
  vocabulary: a shader dial, which only a `.gdshader` can name. The picker offers the copies it
  builds from the open scene (one per real choice, with the choice already filled in) and never the
  bare row, which could only ask the reader to type the very name the row exists to stop them
  typing; and the reverse index leaves the template alone, because deciding that a line means this
  row takes a question only the project can answer - your own matcher asks it. The row compiles and
  lifts like any other.

## 4. Parameters

Each parameter is one call chained onto the descriptor, in the order the row receives them:

```gdscript
.param(
	"title",           # param_id - the {name} used in the template
	"\"My Game\"",     # default_value - MUST make the template compile as-is
	"Title",           # label - the field label
	"The new title.",  # words - the field's help text
	"expression",      # hint - which dialog widget to use (see below)
)
```

The field's TYPE comes from the default's own type - text is a String field, `true` a checkbox, `3`
an integer spinner, `1.5` a float spinner. Text is right for every parameter whose default is a
GDScript expression, because an expression's default IS its text. The rest of the family names what
`.param` cannot:

- `.param_typed("Vector2", "offset", "Vector2.ZERO", "Offset", "...")` - the default is text
  standing for another type (`Vector2.ZERO`, `self` as a Node), so the type is said out loud.
- `.param_choice("side", "left", "Side", "...", ["left", "right"])` - a fixed dropdown.
- `.param_suggesting("action", "\"jump\"", "Action", "...", ["\"ui_accept\""], "input_action")` -
  an editable combo the reader may type anything into.
- `.param_built(F.make_param(...))` - a parameter a helper already made, handed over whole.

`F.make_param(param_id, type_name, default_value, display_name, description, hint, options,
autocomplete)` is the long form behind all of them, and stays as it is.

The `hint` picks the field's editor:

- `"expression"` - a text field with the fx button (the value is a GDScript expression).
- `"property_reference"` / `"method_reference"` / `"signal_reference"` - name pickers for a node's members.
- `"scene_path"` - a `.tscn` path picker.
- `"key_capture"` - press-a-key to capture a keycode.
- `"physics_layer_2d"` / `"physics_layer_3d"` - a checkable list of the project's named physics
  layers producing the mask int (params named `collision_mask` / `*_mask` / `*_mask_3d` get it
  by convention - beginners tick "Walls" instead of computing a bitmask).
- `"input_action"` - an editable picker of the project's Input Map actions, enumerated LIVE when
  the dialog opens (the project's own actions first, the everyday `ui_*` built-ins after). Use it
  on any parameter that names an existing action.
- `"color"` - a colour swatch.

Two more optional arguments make a dropdown or a suggest box:

- `options` - a fixed dropdown, either plain strings `["left", "right"]` or `{"key": <inserted>, "label": <shown>}` dicts so the menu can read "Warning" while inserting `push_warning`. For the six comparison
  operators use the factory's own list - `F.COMPARISON_OPTIONS` (labeled: `>=` reads "≥  at least", and the dialog shows the `>=` it inserts muted beside the choice),
  or `F.comparison_options("=")` when your runtime stores and matches a single `=`. Every operator
  picker in the plugin resolves there, so a wording change lands everywhere at once instead of
  drifting between copies.
- `autocomplete` - an editable combo the user can type into and filter.

**The default value is not cosmetic.** The compile gate builds every ACE with its defaults and checks it
parses, so `"\"My Game\""` (a quoted string) is right for a String literal, `"1.0"` for a float, `"self"`
for a Node, and `"KEY_SPACE"` for a keycode. A default that does not compile fails the suite.

## 5. Template rules

- **Params** are written `{param_id}` and substituted at apply time.
- **Multi-line** templates use `\n` and `\t` inside the string; the statements run in order.
- **`{uid}`** is a fresh unique token baked when the ACE is applied, so two copies of the same ACE in one
  event never collide. Use it to name a private local:

  ```gdscript
  "var __timer_{uid} = get_tree().create_timer({seconds})\n__timer_{uid}.timeout.connect({callback})"
  ```
- **`{target.}`** (with the trailing dot) is added for you on node-scoped ACEs so the user can optionally
  retarget the action onto another node; you do not write it by hand for host-scoped module helpers.

## 6. The two contracts

These are not style preferences - they are what keep user projects working.

**The parity covenant.** A template must bake to the exact GDScript a person would hand-write, using
**only plain Godot** - no reference to any EventForge or EventSheet class. A game that uses your ACE must
keep running with the plugin deleted. So `get_window().title = {title}`, `AudioServer.set_bus_mute(...)`,
`Input.get_vector(...)` are fine; anything reaching into the plugin is not. (Editor-only helpers may use
Godot editor classes like `EditorInterface`, because those run in a Tool sheet, not in the shipped game.)

**The freeze contract.** Once your module ships, an `ace_id` and its `codegen_template` are a permanent
promise: every saved sheet that used it must keep compiling byte-for-byte. So:

- Pick a brand-new `ace_id` that no other module uses (the duplicate-id gate enforces uniqueness).
- Never rename or delete a shipped `ace_id`. To retire one, call `.deprecated("why", "Core::Replacement")`
  - it keeps compiling but hides from the picker.
- Changing a shipped template changes what old sheets emit. Add a new ACE instead.

## 7. Section descriptions

Give your category a one-line blurb that shows when its header is selected in the picker. Add an optional
method to the module:

```gdscript
static func section_descriptions() -> Dictionary:
	return {"Weather": "Rain, wind, and time-of-day helpers for the sky."}
```

The registry merges these into `EventSheetSectionInfo`. A category with no blurb simply shows none, which
is harmless.

## 8. Worked examples

An **action** (a statement):

```gdscript
F.act("PauseGame", "Pause Game", "get_tree().paused = true", "Flow", "pause the game", "Freezes every node that is not set to run while paused.")
```

A **condition** (a boolean):

```gdscript
F.cond("IsGamePaused", "Is Game Paused", "get_tree().paused", "Flow", "the game is paused", "True while the game is paused.")
```

An **expression** (returns a value):

```gdscript
F.expr("ViewportCentre", "Viewport Centre", "get_viewport().get_visible_rect().size / 2.0", "Screen", "screen centre", "The middle of the screen, in pixels.")
```

An action **with a parameter and a dropdown**:

```gdscript
F.act("SetMouseShape", "Set Mouse Cursor", "Input.set_default_cursor_shape({shape})", "Input", "set cursor {shape}", "Changes the mouse cursor shape.")
	.param_choice("shape", "Input.CURSOR_ARROW", "Shape", "The cursor to show.", ["Input.CURSOR_ARROW", "Input.CURSOR_POINTING_HAND", "Input.CURSOR_CROSS"])
```

A **combined** action that folds three lines into one row, using `{uid}`:

```gdscript
F.act("PopupLabel", "Popup Floating Label", "var __lbl_{uid} = Label.new()\n__lbl_{uid}.text = {text}\nadd_child(__lbl_{uid})", "UI", "popup label {text}", "Spawns a Label with your text as a child of this node.")
	.param("text", "\"+100\"", "Text", "What the label says.", "expression")
```

A **trigger** (name the signal where an action names its template):

```gdscript
F.trig("OnScreenResized", "On Screen Resized", "size_changed", "Game Window", "on screen resized", "Runs when the game window changes size.", "Window")
```

## 9. Testing your module

Two gates run in the suite and will catch the usual mistakes for free:

- **`builtin_ace_compile_test`** builds every ACE with its default parameters and checks the result
  parses as GDScript. A bad default or a typo in a template fails here.
- **`duplicate_ace_id_test`** fails if two ACEs share a `provider::ace_id`.

Run the whole suite (always check for the literal verdict line, not just the absence of `[FAIL]`):

```
godot --headless --path . --script tests/run_tests.gd
```

For anything with real behaviour, add a small test that pins the compiled output of an event using your
ACE, so a future change to the template is caught.

## 10. Tips and common mistakes

- **Start from the scaffolder**, not a blank file - it gets the boilerplate and the section description right.
- **Every default must compile.** The compile gate is your friend; run it after each change.
- **Pick unique, permanent `ace_id`s.** They are frozen forever once shipped - deprecate, never rename.
- **Plain Godot only** in a template. If you are tempted to reference a plugin class, you want a pack, not a module.
- **One clear job per ACE.** If a template is getting long, it is probably a pack's job.
- **Always call `.described(...)`.** The info panel and the picker search both use it.
- **Feature sparingly.** `.featured()` is for the one or two rows a beginner reaches for first, not every ACE.
- **Group sensibly.** Reuse an existing category name to join it, or make a new one and give it a `section_descriptions()` blurb.
- **A new `class_name` needs a class-cache regen** (`--editor --headless --quit-after 3`, then revert `project.godot`) before the suite sees your module.
- **Modules are stateless vocabulary.** If your ACEs target a stateful host that should survive a save, give that host script the save convention - `save_state() -> Dictionary` and `load_state(state)` - and the Save System persists it. **Tools > Save Studio > Add Save Support** generates the pair for you.
