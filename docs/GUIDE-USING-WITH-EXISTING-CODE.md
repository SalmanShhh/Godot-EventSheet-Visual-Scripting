# Using EventSheets with your existing code

**Short answer: yes.** You can drop EventSheets into an existing Godot project and it works with the
GDScript you already have - your own classes, autoloads, nodes, and signals - **without writing a single
ACE for them.** This page is self-contained: everything you need to interoperate is right here.

The reason it works is one design rule: **a sheet compiles to plain, idiomatic GDScript with zero
dependency on the plugin.** Delete EventForge and your generated `.gd` files still run. So a sheet and your
existing code are just GDScript talking to GDScript - there's no runtime bridge to wire up.

![A sheet whose rows call plain GDScript: exported variables, an inline GDScript block, and a sheet-built function callable from any other script in the project](previews/editor-event-sheet.png)

## Table of Contents

1. [Scenarios Where This Page Helps](#1-scenarios-where-this-page-helps)
2. [The Interop Map](#2-the-interop-map) - and [Your Own Classes Are Already Vocabulary](#2b-your-own-classes-are-already-vocabulary)
3. [Call Your Existing Code from a Sheet](#3-call-your-existing-code-from-a-sheet)
4. [React to a Signal Your Existing Code Emits](#4-react-to-a-signal-your-existing-code-emits)
5. [Putting a Sheet on a Node - Two Modes](#5-putting-a-sheet-on-a-node---two-modes)
6. [Call a Sheet from Your Existing Code](#6-call-a-sheet-from-your-existing-code)
7. [Adopting an Existing Project: Reverse-Lift](#7-adopting-an-existing-project-reverse-lift) - what an opened file
   [reads like](#what-an-opened-file-reads-like---event-sheet-grammar-not-annotated-code), its
   [objects](#the-objects-of-an-opened-file---what-they-are-and-where-you-find-them), a whole
   [scene](#a-whole-scene-read-in-one-place), [what stays code](#what-stays-code-still-reads-as-what-it-is)
   and [beginner spellings](#beginner-spellings-and-the-reading-layer), plus
   [the Project bar](#the-project-bar---your-project-by-kind-not-by-folder)
8. [When to Wrap Existing Code in Your Own ACEs](#8-when-to-wrap-existing-code-in-your-own-aces)
9. [Use Cases](#9-use-cases)
10. [Tips and Common Mistakes](#10-tips-and-common-mistakes)

---

## 1. Scenarios Where This Page Helps

- **You have an autoload-heavy project** (score manager, event bus, save system) and want sheets to call it all without writing wrappers.
- **A node already has a hand-written script** and you want sheet-driven logic on it anyway - behavior mode composes instead of replacing.
- **Your code emits signals** and a sheet should react to them by name, with no changes on the emitting side.
- **Your GDScript needs to call INTO a sheet** - read its exports, call its functions, await its signals like any class.
- **You are migrating an existing codebase** and want your current `.gd` files to open as editable sheets (reverse-lift), not be rewritten.
- **One system gets reached constantly** and deserves first-class vocabulary - the last section covers when wrapping pays off, and the wizard that previews, curates and renames the entries your own script publishes.
- **You just want your own classes in the picker** with no annotations and no wrapper - see section 2b.

## 2. The Interop Map

Each row is covered below with the exact code it compiles to.

| You want to… | How | No ACE needed? |
| --- | --- | --- |
| Pick your own classes' methods from the picker | **Your Project** section on the object page - zero setup (2b) | ✅ |
| Call your existing code from a sheet | ƒx expressions are real GDScript + the **Helpers** ACEs + RawCode blocks | ✅ |
| React to a signal your code emits | **On Signal** trigger (any node / autoload / `self`) | ✅ |
| Put a sheet on a node that already has a script | **Behavior mode** - attach the sheet as a child node | ✅ |
| Call a sheet from your existing code | Hold a typed reference and call it like any class (parity contract) | ✅ |

## 2b. Your Own Classes Are Already Vocabulary

Open the picker's object page and, under **Your Project**, you will find the classes and
autoloads your game declares.

<img src="images/interop-your-project.png" alt="The Add Event picker's object page: a System card, a collapsed Objects and Behaviors section, and a Your Project section listing the game's own classes - AutoACESample, CarouselOfJuice, Enemy, FamilyArena and more." width="620">

Pick one and the tree scopes to what it publishes: methods that return
nothing are Actions, methods returning `bool` are Conditions, anything else is an Expression,
its editor properties become Set/Get pairs, and its signals become triggers. Each emits the
plain call you would have written by hand:

```gdscript
$Inventory.add_item("potion", 3)          # picked from Your Project > Inventory
Inventory.add_item("potion", 3)           # an autoload emits through its own name
```

<img src="images/interop-scoped-verbs.png" alt="The Add Event dialog scoped to the Enemy class: the tree lists the engine classes it inherits from - CharacterBody2D, Area2D, Node2D, RigidBody2D, Timer, AnimationPlayer - followed by an All of Enemy section holding the script's own verbs." width="620">

**Nothing is required of you** - no annotations, no moving files into `eventsheet_addons/`,
no wizard. The list is derived from your scripts (never by running them), so it is correct
inside the editor, and it updates when you edit a script rather than at the next restart.

**What is listed, and what is not.** Only classes that ultimately derive from `Node` earn a
card: those are the things a sheet acts on. Data `Resource`s, `RefCounted` helpers, tool
scripts and test classes are deliberately excluded - you would never pick an *action* on
them, and listing everything would bury the entries you actually want. They stay reachable
where they belong, in expressions and the Self section. A script that already publishes as a
provider - it lives in `eventsheet_addons/`, or you taught it explicitly - is skipped too: its
entries already reach the picker with your own names, kinds and hidden marks, so reflecting it
again would list everything twice.

To include a folder of scripts without a `class_name`, add it to the
`eventsheets/vocabulary/extra_paths` project setting; such scripts are identified by their
file name.

### Making them read the way you want

Right-click any of these entries in the picker:

- **Rename this entry…** / **Set its category…** - fix a name that reads badly in a row.
- **Hide this entry** / **Hide everything from `<Class>`** - trim what you never use. A hidden
  class stays listed greyed out; select it to bring it back.
- **Reset to the inferred name** - undo one refinement.

These are stored in `res://eventsheet_vocabulary.tres`, **never written into your script**,
and they change presentation only - ids and emitted calls are untouched. Delete that file and
every entry returns to its inferred name with no sheet affected. If you would rather your
script describe itself (so a teammate reading the file sees the same vocabulary), call
`EventSheets.bake_overrides(script_path, class_name)` to write them in as `## @ace_*`
comments; the file is backed up first and only comment lines are ever added.

The tooltip tells you which layer a name came from: *"From your project's Inventory -
inferred from the script, not curated"*, or *"renamed by you"* once you have refined it.

### Naming a raw call you already have

A row that came in as a bare **Call Method** - typed by hand, or lifted from existing
GDScript - can usually be named. Right-click it and, when it matches exactly one of your
own actions, the menu offers **Convert to Inventory ▸ Add Item**. Converting gives the row
that action's proper parameter fields and emits exactly the same code as before.

The offer appears only when the match is certain: the target must be a plain reference (not
`get_node("Inventory")` or `bags[0]`), and the argument count must match exactly, so a
conversion can never drop or invent an argument.

<img src="images/interop-convert-menu.png" alt="A row reading $Enemy.take_damage(25.0) with its right-click menu open; the last entry reads Convert to Enemy - Take Damage." width="620">

### When you rename a method

Renaming a member of your script orphans every row that used it - the one failure here that
compiles green and breaks at runtime. The **Project Doctor** catches it and, when one current
member is clearly the one you renamed to, names it: *"`WeaponKit.start_fire()` does not
exist… Did you rename it to `begin_fire()`?"* It stays quiet when two members look equally
plausible, because guessing between them would send you to fix the wrong call.

---

## 3. Call Your Existing Code from a Sheet

### Expressions are literally GDScript

Every ƒx field (a parameter, a condition, an expression) is **pasted into the compiled script verbatim** -
no escaping, no sandbox, no translation. Whatever you type resolves at Godot's normal compile/run time. So
you can reference anything that's in scope:

- An **autoload singleton**: `ScoreManager.add(10)`
- A **global `class_name`**: `GlobalUtils.distance(a, b)`
- The **host node's own members/methods**: `velocity.length()`, `$Sprite2D.visible`

Type it into a condition and it compiles straight through:

```gdscript
# Condition fx:  ScoreManager.is_high_score()
# Action  fx:    ScoreManager.add(10)
if ScoreManager.is_high_score():
    ScoreManager.add(10)
```

### The Helpers ACEs - the structured escape hatch

When you'd rather pick from a menu than type an expression, the **Helpers** category gives you a first-class
ACE for reaching *any* method, property, or signal on *any* node - none of it has to have an ACE of its own.
Each one compiles to a single line of ordinary GDScript:

| Helper ACE | Compiles to | Use it for |
| --- | --- | --- |
| **Call Method** | `target.method(args)` | Run any existing method (`$Enemy.take_damage(5)`) |
| **Set Property** | `target.property = value` | Write any property (`$Sprite2D.modulate = Color.RED`) |
| **Get Property** | `target.property` | Read any property in an expression |
| **Get Node** | `get_node(path)` | Grab a node reference |
| **Run GDScript** | `your code here` | Drop one raw statement |
| **Evaluate GDScript / Expression** | `(your code)` | Use raw code as a condition or value |
| **Connect Signal** | `source.signal.connect(callable)` | Wire an existing signal to a handler |
| **Emit Signal On** | `target.signal.emit(args)` | Fire a signal on another node |
| **Call Method On Group** | `get_tree().call_group(group, method)` | Call a method on every node in a group |

`target`, `method`, `property`, etc. are free-text fields - you type the real GDScript fragment. Defaults
are sensible (`target` is `self`, `property` is `modulate`/`visible`, and so on).

### RawCode blocks - drop in GDScript directly

For anything the above doesn't cover, a **RawCode block** is a pass-through row: the lines you write are
emitted as-is, either at class level (for `@onready var`, helper functions, constants) or inside an event
body. It's the "just let me write GDScript here" hatch:

```gdscript
# Class-level RawCode:
@onready var _score := ScoreManager

# In-event RawCode:
$Existing.some_method()
GlobalUtils.ping(self)
```

---

## 4. React to a Signal Your Existing Code Emits

![The Connect Signal to Event Sheet dialog: a searchable list of the node's own script signals and its native ones](images/connect-signal-dialog.png)

Triggers are how a sheet *reacts*. To react to your own code, use the signal triggers - they connect by
name, with no need for the emitter to know anything about EventSheets.

- **Connect Signal to Event Sheet** - the no-typing path: right-click the node in the Scene dock,
  pick the signal from the searchable list (script signals and native ones alike), and an
  **On <Signal>** trigger event lands in its sheet with the handler arguments pre-baked.
- **On Signal** - the always-available escape hatch. Give it a **signal name** (free text) and a **source**:
  blank for `self`, a **node path**, or an **autoload** (`autoload:EventBus`). It compiles to a `connect`
  in `_ready` plus a generated handler:

  ```gdscript
  # On Signal: signal = "powered", source = "Generator"
  func _ready() -> void:
      get_node("Generator").powered.connect(_on_generator_powered)

  func _on_generator_powered() -> void:
      ...
  ```

  ```gdscript
  # On Signal: signal = "game_paused", source = "autoload:EventBus"
  func _ready() -> void:
      EventBus.game_paused.connect(_on_event_bus_game_paused)
  ```

- **Reflected `signal:NAME` triggers** - if a node or an annotated autoload is registered as a provider,
  its signals show up in the trigger picker automatically, and these bake the signal's **real typed argument
  signature** so your handler receives the parameters (`func _on_generator_powered(level: int)`).

- **Host lifecycle triggers** - *On Ready*, *Every Frame*, *On Physics Process*, *On Input*,
  *On Unhandled Input* compile straight to the engine callbacks (`_ready`, `_process`, …). No connection
  needed; they always work on the node the sheet runs on.

> **Good to know:** a connection to *another* node's signal trusts the path/name you give it - it isn't
> checked at compile time, so a wrong path or misspelled signal fails at runtime, not in the editor. And the
> generic *On Signal* handler binds arguments only once you tell it the shape: type the signature into its
> **Arguments** field (e.g. `amount: int`) and the handler receives them. A reflected `signal:NAME` trigger
> fills that in for you. For signals that cross scenes, route them through an autoload bus
> rather than a scene-relative node path.

---

## 5. Putting a Sheet on a Node - Two Modes

This is the one place the answer is "it depends," because of a hard Godot rule: **a node can have only one
script.**

### Plain mode - the sheet *is* the node's script

A normal sheet declares a **host class** and compiles to `extends <that type>`. The generated `.gd` is set
as the node's script, so `self` **is** the node and every one of its built-in members/methods is reachable:

```gdscript
extends CharacterBody2D   # self is the node; velocity, move_and_slide(), $Sprite2D all in scope
```

Because this *becomes* the node's single script, it only fits a node that **doesn't already have one** - the
"create a sheet for this node" workflow will refuse a node that's already scripted.

### Behavior mode - the sheet rides *alongside* an existing script

**This is the solution when the node already has a script.** In behavior mode the sheet compiles to
`extends Node` and binds to its parent, and you attach it as a **child node** ("behavior pack") under your
existing-scripted node:

<!-- no-figure -->
```gdscript
extends Node

## The node this behavior acts on (its parent). Required host: Node2D.
var host: Node2D = null

func _enter_tree() -> void:
    host = get_parent() as Node2D
    if host == null:
        push_warning("This behavior requires a Node2D parent.")
```

The sheet then acts on the host through that `host` accessor. Your node keeps its own script; the behavior
composes with it instead of replacing it. (One caveat: `host` is bound in `_enter_tree`, so it's available
once the behavior is in the tree - calls before that warn rather than act.)

---

## 6. Call a Sheet from Your Existing Code

The parity contract works in your favor here too. Because the generated script contains **no plugin symbols**
(it's enforced by a test that scans for any `EventForge`/`EventSheet` reference), your hand-written GDScript
treats a sheet exactly like any other class: hold a typed reference and call its **published functions**,
read its **`@export`/member variables**, and `await` its **signals**:

```gdscript
@onready var hp: SimpleHealthBehavior = $SimpleHealthBehavior

func _ready() -> void:
    hp.max_health = 200.0          # an @export var the sheet declared
    hp.take_damage(10.0)           # a function the sheet published
    await hp.on_death              # a signal the sheet declared
```

A typed reference like this is the most robust way to call in. (Don't hand-edit the generated `.gd` - it's
overwritten on recompile; the sheet is the source of truth.)

---

## 7. Adopting an Existing Project: Reverse-Lift

You're not limited to writing new sheets. **Reverse-lift** opens an existing `.gd` file *as* a sheet (or you
paste GDScript and get events back), so you can bring code you already have into the visual editor and keep
editing it either way. It de-codes function bodies, `if/elif/else`, `for`/`while`/`repeat` loops, and `match`
into structured rows - so a `.gd` you already have opens as real events, not an opaque block, and round-trips
losslessly.

Here is an ordinary hand-written helper from this plugin's own source - nothing was written or reformatted
for the picture - opened as a sheet:

<img src="images/interop-opened-gd.png" alt="A hand-written GDScript file opened as an event sheet: a collapsed Class setup strip, an Expression verb named Parse with a source parameter and a gives back Dictionary badge, then condition and action rows including a For each raw_line loop with nested sub-events." width="720">

Note what the file became: the header comment, `@tool`, `class_name` and `extends` fold into one **Class
setup** strip; the function becomes a real function row with a named parameter and a return badge; and its body
becomes conditions and actions, including the `for` loop as a condition with its own sub-events. What still
has no structured equivalent stays an in-flow GDScript block - honest, editable, and byte-for-byte
unchanged when you save.

**If you tried this before and got a wall of code, try it again.** Opening a hand-written file used to
leave 88.1% of its lines as verbatim blocks; it now leaves 0.05% (measured across 206 real files in this
repo, byte-exact on every one). Most of that was spelling, not semantics - the two blank lines the official
style guide puts between functions, an explicit `: Variant` parameter, a typed-collection return, a `#` note
above a function - and any ONE of them could revert an entire file, because the lift is all-or-nothing per
file. The rest was structure nobody had split: a run of statements is now one action row per statement,
which you can select, disable and drag like any other.

### How long opening takes, and why the editor stays responsive

![The "Opening <file>" strip mid-lift: the rows are already painted and the editor is still drawing frames](images/open-progress-strip.png)

Opening a `.gd` runs two passes: a fast raw read that gives you rows and verbatim blocks, then the lift,
which matches every line against the vocabulary and recompiles the sheet to check the bytes still match.
The lift is the expensive half, so it runs on a worker thread with a progress strip and a **Show as code
instead** button - the editor never freezes, and you can stop it and take the raw read at any point.

Measured on the packs in this repo, opening a file end to end:

| File | Lines | Time |
| --- | --- | --- |
| `fps_controller_behavior.gd` | 647 | ~0.9 s |
| `save_system_addon.gd` | 1,522 | ~1.4 s |

The first open of a session also builds the vocabulary index once (about one second on a stock install
with every pack present); every later open reuses it. None of that cost is paid at editor startup - the
plugin deliberately loads its heavy parts on first use, so enabling it does not slow Godot's boot.

Three caches carry the rest of it, and all three are held for the session and dropped the moment
Godot reports a filesystem change - so a script you edit outside the editor, or a pack you drop into
the project, shows up on the next row that asks:

- **The behaviour-pack index** (which pack a name belongs to, so `[Platform]` can sit between an
  object and what it does). Rebuilding the rows of a 320-row pack asks for it a couple of hundred times;
  holding it is what took that rebuild from 1.7 seconds to 0.27.
- **The object facts and the signal fan-out** (what a script or scene IS, and who listens to a signal).
  Each is one pass over the project's files, paid on the first question of the session.
- **The block-kind scan**, which decides what a pack file is by reading its own `extends` line rather
  than loading every pack script.

If you are writing an editor extension against this plugin, the one rule to keep is that nothing on
the boot path may NAME a class from the reading layer or the compiler: naming a global class compiles
its whole dependency tree the moment the script loads, and the boot files reach those by path at call
time instead. `tests/plugin_boot_lazy_test.gd` enforces it.

### What an opened file reads like - event-sheet grammar, not annotated code

Open a behaviour pack or any script as a sheet and it reads the way an event sheet does, top to
bottom: a head that says what the file IS, then variables, then events, then the rows inside them.
That is the order this section is in.

#### The head - what this file is

- **The Include bar says how much of the file reads as events.** A chip at the end of it -
  `96% reads as events · 3 script blocks ▸` - is the share of the file that arrived as rows, and how
  many **script blocks** the rest of it sits in. Click it and it walks those blocks, one per click, so
  the parts that stayed code are a click away rather than a scroll away. A file that lifted completely
  just says `reads as events`. The number is measured by the same code the corpus gate measures with,
  so the chip and the test can never disagree about the same file. When the engine reported parse
  errors, the bar also says `N errors - the game will not run this script`, in red.
- **The head is one Include bar, the description once, and folded folders.** `⇥ Addon Pack  FPSController
  v1.0.0  behaves on a  CharacterBody3D`, the class description as a comment bar, then a `Triggers this pack
  fires - 11` folder, one folder per `@export_group` (`Jump - 3 settings`, `Movement - 3 settings`, ...),
  and `Instance variables  of FPSController` for everything the groups did not claim. Inside a folder a
  variable reads `Instance number  jump_velocity = 4.5  Upward velocity applied on a jump` - the one
  sentence below, plus the knob's own description. On an editable sheet the head keeps its Class setup
  strip and `@export` chips, because those are things you edit; the folders are for reading.

  ![A behaviour pack's head: the Include bar reading "Addon Pack FPSController v1.0.0 behaves on a CharacterBody3D", the class description as a comment bar, then folded Triggers, Input and one folder per setting group](images/opened-pack-head.png)

  ![The same head with its folders opened: every setting under Movement, Wall Tech and Instance variables of FPSController, each reading scope word, type word, name, value and its own description](images/opened-pack-head-open.png)
- **An autoload opens as the project's Globals sheet.** When the file IS a registered autoload, the
  Include bar reads `⇥ Game  autoload (global) · game.gd` with the globe, its knobs read as one
  `Global variables` folder rather than the Instance variables one, and its triggers say
  `this global fires - N`. The Object bar names it the same way.
- **A global is declared once and listed where it is used.** Any sheet that reads or writes one of
  the project's globals grows a folded `▸ Global variables used here` folder in its head - `Score ·
  Lives  (from Game)` - and each entry opens to what it is declared as and where: `whole number
  Score = 0 · Game`. A name the autoload does not actually declare says `not declared on Game`,
  because a global that resolves to nothing at runtime otherwise reads exactly like one that works.
  To make one, **Add ▸ Global Variable…** (or just **V**) works on any sheet at all: name it, pick
  its type in plain words, give it a value, choose which autoload holds it, and the row you will get
  is previewed live. The autoload is opened as a sheet and the variable added there in one undo
  step - the autoload stays the single place a global lives, so there is no second variable system
  to keep in sync. In the Object bar, an autoload under **GLOBALS & FAMILIES** hovers with what it
  holds (`Score = 0 · Lives = 3`), read straight off its file even if nobody has opened it.

#### Variables - one sentence each

![An opened script's head: one Instance variables folder holding every member, each row reading scope word, plain type word, name, value - Instance number speed = 200 with an Inspector chip, Constant number MAX_HP = 100, Static number spawned = 0 shared by every Player, Instance color tint = white with its live swatch](images/variable-sentence-head.png)

- **Every variable reads as one sentence - `<scope> <type> <name> = <value>`.** The scope word leads:
  `Instance number speed = 200`, `Instance boolean alive = true`, `Constant number MAX_HP = 100`,
  `Static number spawned = 0` (which adds `shared by every Player`), `Local text name = ""` inside an
  event, `Global number Score = 0` on an autoload and `Field number price = 0` on a Resource script.
  The type is in plain words - number, whole number, text, boolean, vector, color, `list of text`,
  table, object or the class the author named, scene, any - with Godot's own spelling (`float`, `int`,
  `String`, `Array[String]`, `Dictionary`) one hover away. A declared `int` reads "whole number"
  because the author said they wanted no fractions; an undeclared `100` still reads "number". Variables
  a designer can edit wear a small **Inspector** chip, and the head gathers them all in one
  **Instance variables** folder with those first, rather than a Settings / Internal state split.
- **A `static var` says who shares it.** `static var spawned: int = 0` reads
  `Static number  spawned = 0  shared by every Player` - the scope word leads the type chip, and the
  muted tail names the object the value belongs to (the script's `class_name`, else its scene root,
  else its file). One value on the class, not one per object, is exactly the thing a reader has to be
  told; on an authored sheet the same fact reads as a `static` badge beside `const`.
- **A colour is always a live swatch.** `var tint := Color.WHITE` reads `Instance color tint =`
  swatch `white  #ffffff`; a colour nobody has a word for reads its hex. Click the swatch, anywhere
  it appears - a variable row, an action's colour parameter, the Add variable dialog - and the sheet's
  colour picker opens right there (wheel, hex, RGBA, named colours, your saved palette, eyedropper).
  What you pick is written back **in the spelling the line already used**: `Color.RED` stays a named
  constant, `Color("#ff9b3c")` stays a hex string, `Color(1, 0.6, 0.2)` stays numbers. The colour
  moves; nothing else in the file does.
- **A setting row shows what the Inspector would show.** `@export_range(0, 20, 0.5)` reads
  `number  speed = 5  0 to 20, step 0.5`; `@export_enum("Walk", "Run", "Fly")` reads as a `combo` chip
  showing the label rather than the number (`mode = Walk  Walk / Run / Fly`); a 0-to-1 range reads as a
  percent; `@export_file("*.png")` reads `file` with its filter; `@export_dir` reads `folder`;
  `@export_multiline` reads `text  multiline`; a Color reads its swatch and its word; and
  `@export_flags(...)` reads `flags` with the names of the bits.
- **An Inspector button reads as a setting row.** `@export_tool_button("Bake", "Bake") var bake =
  _bake` opens as `button Bake  in the Inspector · calls Bake` instead of as a Script block: the
  button's own label leads the row, and there is no value shown, because `= _bake` is which function
  it runs rather than something a designer tunes. Both spellings of the annotation round-trip
  exactly. Right-click the canvas and **Add Inspector Button…** writes the line and the empty
  function it calls in one step.
- **A setter that names a node reads on that node.** `n.position = n.position.snapped(Vector2(8,
  8))` inside a `for n in …` reads `n ▸ Set position to position snapped to 8, 8`: the object column
  says which node is being moved, the value drops the receiver it would only be repeating, and
  `x.snapped(...)` reads as the grid it pulls the value onto - the same words the free-function
  spelling `snapped(x, 8)` reads. A value reaching through a different object keeps every word of it
  (`n ▸ Set position to other.position`).
- **The cursor, the click and the gamepad cable read on the objects they belong to.** A handler
  wired to `mouse_entered` or `mouse_exited` reads `Mouse ▸ Cursor is over Player`, with the edge
  said quietly beside it - `(enters)` or `(leaves)` - and the object is the node the cursor is over.
  A `_input_event(viewport, event, shape_idx)` on a clickable body is an input handler like `_input`
  is: its `if event is InputEventMouseButton and event.pressed:` branch reads `Mouse ▸ On Player
  clicked` with the branch's own rows under it, in both the typed and the untyped spelling. And
  `Input.joy_connection_changed.connect(_on_pad)` with a `_on_pad(device, connected)` handler reads
  `Gamepad ▸ On gamepad connected / disconnected`, with `device` and `connected` as the payload chips
  that say which of the two just happened.

  ![A clickable, tweened, snap-to-grid script read as an event sheet: the Inspector button as a setting row, a one-line tween chain, the cursor and the click on the Mouse, the gamepad cable on the Gamepad, and a snap setter on the loop's own object](images/opened-script-batch7.png)

  ![Three opened scripts stacked: one whose Include bar says "73% reads as events - 2 script blocks", one whose settings read as Movement and Look folders with every export hint family, and the same file opened as an autoload, whose head is one Global variables folder](images/opened-script-head5.png)
- **A local variable's scope is enforced, and shown.** A local is visible from the event that
  declares it to the end of the body it was declared in, subtrees included, and nowhere else. Drag an
  action that uses `dealt` into an event that cannot see it and the drop refuses before you release,
  in red: **`dealt is not visible here`**. Hover the variable's name and every other use of it inside
  that scope lights up, so the highlight doubles as a picture of how far the name reaches. Members,
  globals and keywords match nothing - they mean something outside this event.

  ![Hovering a local variable's name highlights every use of it in its scope](images/local-variable-uses-highlight.png)

- **A local declared inside a body reads at the top of the event that owns it.** An event sheet
  declares a local at the top of its event and fills it in with an action, so a `var` line reads as
  those rows: `var dealt: float = damage * 2` becomes `Local number dealt = 0` up with the event's
  other locals, and `System ▸ Set dealt to damage * 2` where the line itself sits. A line whose value
  is already a value - `var hits := 3` - needs no action and gets none; the declaration carries the
  value and the action lane shows nothing for that line. A type with no starting value of its own (an
  object, a list, a table, or a value whose type nothing states) keeps its whole declaration on the
  one row, because inventing a starting value nobody wrote would be a guess. Display only: the file
  keeps its line, and the row still addresses that statement - clicking, dragging and the row menu
  reach the same line they always did. **Drag the Local row into another event** and the declaration
  moves with it, rewritten where it lands through the same undo funnel every other row uses. Two
  refusals guard the move, both in the red drop bubble: a row that uses a local may not leave the
  scope that can see it (`dealt is not visible here`), and a local may not be dragged out from under
  rows that still use it (`dealt is still used here`).

  ![A function's rows with its locals underneath it - Local number dealt = 0, Local text label = "hurt", Local number shield = 5 - and System Set dealt to damage * 2 in the action lane](images/local-rows-at-the-top-of-their-event.png)
- **A property's setter reads as a trigger, its getter as an expression.** A `set(v):` block fires
  when the value is set, with the new value as its payload - which is exactly what a trigger is - so
  it reads `➜ On hp set` with a `v` chip and its body as ordinary actions and sub-events, the first
  step sitting beside the trigger. A `get:` block is a function that gives a value, so it reads as an
  expression block whose body says `System ▸ Set return value to hp ≤ 0`. The variable row stays
  above them both, still carrying the value, the type and the Inspector facts, and double-clicking it
  still opens the Variable dialog. The accessor bodies read through the same lift a declared
  handler's body goes through, so the same line says the same thing wherever it was written; a body
  the lift cannot claim keeps the verbatim accessor block, and the file's bytes are untouched either
  way. Right-click a sheet variable for **Add setter** / **Add getter** to write the shape yourself.
  The accessor events show wherever the variable is listed - down the event tree and inside the
  head's **Instance variables** folder, which is where a reader goes to find out what a variable IS.

#### Events - the shapes the file is made of

- **A blank event runs every tick, and that is why the lane is empty.** A `_process` body that carries
  no condition of its own reads as a BLANK top-level event: nothing at all in the condition lane,
  because in an event sheet a blank event already means "every tick". Hover the row and it says
  `Runs every tick`; the Explain panel says the same. `_physics_process` keeps one muted
  `every tick (physics)` note, because blank alone cannot say WHICH tick. The moment such an event
  grows a condition it goes back to saying **Every tick** in full, so the reading never hides a fact
  that matters. Nothing is written to the file for any of this: a blank event compiles into
  `_process(delta)` and re-reads as a blank event, byte for byte.

  ![Three events: a blank one whose condition lane holds only "+ Add condition" and whose action sets a label every tick, a physics one reading a muted "every tick (physics)", and an every-tick event carrying a condition, which keeps its full "Every tick (draw)" words and its tempo badge](images/blank-events.png)

  You can author one too. Press **E** and the Add event dialog's first entry is already selected -
  **(none - runs every tick)** - so Enter makes the blank event and **A** fills its actions. Under a
  parent, blank means something else and has its own gesture: **Add blank sub-event (B)** puts its
  actions after the parent's, in order, with no `if` written at all.

- **Every function reads as the trigger it is.** `ƒ  Functions ▸ On Jump`,
  `ƒ  Functions ▸ On Set Third Person  enabled`: the name and one chip per input sit in the CONDITION
  lane, because that lane answers "when does this run?" for every other event and a function's answer is
  "when it is called". The body's first step reads beside it on the right, the rest of the body hangs
  under it as sub-events, and Collapse takes the whole function back to that one row. The row's tint says
  whether it is an Action, Condition or Expression, and a condition or expression also says its kind as a
  quiet word next to the name. Click it for the **ACE properties** popup - kind, category, inputs (with
  their types), what it gives back, description, whether it is featured, its icon, the exact line it
  inserts, and the function behind it - with Edit..., Open guide and Show in code. Unpublished helpers are
  the same blocks with their doc as the right-hand caption, gathered under a closed **Helpers** folder.

  ![A pack's published functions read as events: f Functions - On Can Stand Up with "condition" beside the name and Set return value in the action lane, and a closed Helpers folder reading "functions this pack uses inside itself - 7"](images/opened-pack-verbs.png)

  ![The ACE properties popup for one published function: its kind, category, inputs with their types, what it gives back, its description, its icon, the exact line it inserts and the function behind it](images/ace-properties-popup.png)

  The picker knows about them too. Open **Add Event** on a `.gd` you opened as a sheet and its first
  page is **ƒ Functions - this script**, listing the file's own functions with the kind each one
  publishes as and the inputs it takes, its unpublished helpers behind a `+ Helpers (N)` fold, and
  **Your Project** under that with every class the project declares. Picking one inserts an ordinary
  Call Function row.

  ![The Add Event picker opened on a script's own functions: a Functions section headed "this script - 4" listing Award Points as an action taking amount number and Round Is Ready as a condition taking enabled true/false, a collapsed Helpers (2) entry, then a Your Project section listing the project's own classes](images/picker-functions-page.png)

  ![The Change Type Everywhere dialog listing each row it will rewrite before the retype is committed](images/seam-change-type.png)

- **Lifecycle handlers are triggers, wherever they sit in the file.** `_physics_process` is `Every Physics
  Tick`; an `_unhandled_input` that branches on the event type reads as one trigger per branch -
  `Mouse ▸ On mouse moved` with `Mouse ▸ mouse is captured` under it, `Keyboard ▸ On Escape pressed` - and a
  hand-written `_on_hurtbox_body_entered(body)` that `_ready` connects reads `Hurtbox ▸ On Body Entered
  [body]`. A handler that comes after the functions in the file lifts in place (an event anchor), so the
  sheet keeps the file's order.

  ![An `_unhandled_input` read as one trigger event per branch: Mouse - On mouse moved with Mouse - mouse is captured under it, and Keyboard - On Escape pressed](images/opened-pack-input-triggers.png)

  ![A script the engine refuses to compile, opened as a sheet: the Include bar says "3 errors - the game will not run this script" in red, two events wear a red margin mark, and the rest still reads normally](images/opened-script-structure5.png)
- **A trigger-shaped poll at the top of a tick handler IS the trigger.** This is how a beginner
  writes input in Godot: `if Input.is_action_just_pressed("jump"):` inside `_process`. In an event
  sheet the same thing is a top-level trigger, so the row reads `⌨  Keyboard ▸ On "jump" pressed`
  with the block's body as its actions, and the `Every tick` words go away - the poll already says
  when the event runs. Only the EDGE polls count: a held `Input.is_action_pressed("hold")` is a
  check every tick, so its handler keeps `Every tick (physics)` with the check under it.
- **A ternary is a sub-event, never a condition in an action cell.** An `if ... else` INSIDE a statement
  (`return wall_normal.x if host != null and host.is_on_wall() else 0.0`) reads the way an event sheet
  draws the same branch: a condition row on the left with the statement on the right, then an `Else` row
  with the other value. A nested ternary chains the way an else-if is written: an `Else` on the
  row's first condition line with that arm's own test stacked under it, and a plain `Else` on the last
  arm - so no two arms read as though both could fire. A second independent ternary nests its own pair.
  This is true on every sheet, authored ones included - reading and editing look the
  same. Display only: the file keeps its one line, hover shows the exact GDScript, and the pair behaves
  as the ONE statement it reads - clicking any of its rows selects the statement and highlights the whole
  pair, dragging any of them moves the statement (nothing drops between the pair's rows), and a
  double-click anywhere on it, the `Else` row included, opens that one line's editor. A ternary inside a
  `func(...)` lambda is left alone - its body is a scope of its own, so hoisting a branch out of it would
  move when that branch runs.

  ![A ternary drawn as the sub-event pair an event sheet would show - the check, the value, then Else - selected as the one statement it is](images/ternary-editable.png)
- **Every event has a number, and everything names it by that number.** The left margin counts events
  down the sheet - sub-events included, groups descended into - and the count is stable, so collapsing a
  group or filtering the sheet never renumbers anything. **Ctrl+G** opens *Go to event* and jumps to
  one. The status bar says where you are in the same words - `event 4 of 61 · line 38` - and a
  bookmark, the Find bar's counter (`3 of 12 · event 4`) and a Project Doctor finding
  (`player.gd · event 4`) all print the same number, so "look at event 12" means one row to everybody
  reading the file. The numbers are display-only: nothing about them touches the script.

  ![An opened script: the event number in the left margin, a static variable reading "Static number spawned = 0 shared by every Player", a function reading as Functions - On Take Damage, and the status bar saying "event 1 of 1 - line 3"](images/opened-script-event-numbers.png)

- **The shapes the sheet reads, you can also type.** Right-click an event for **Add blank sub-event
  (B)**, **Make 'Or' block** (which reads **Make 'And' block** once the event is an Or block) and
  **Add 'Else'** / **Add 'Else If'** - the same three commands sit on the **Add** menu. On an opened
  `.gd`, Make 'Or' block rewrites that one event's joined condition (`a and b` becomes `a or b`) and
  leaves every other byte alone. All three are greyed while the file is a read-only preview; press
  **Edit Events** first.
- **A big file never freezes the editor.** The raw sheet paints within a frame under a progress strip
  (`Opening event_sheet_dock.gd - lifting functions 212 of 458 - 6.1 s`, a bar, and **Show as code
  instead**); the lift runs behind it, and the strip goes away when the last function lands.

#### Rows - what one statement reads as

- **A statement with no matching action reads in the row grammar - Object ▸ what it does ▸ values.**
  `System ▸ Subtract 1 from jumps left`,
  `host ▸ Set velocity X to direction X * speed`, `host ▸ Destroy (at end of frame)`,
  `FPSController ▸ Signal On Jumped`, `host ▸ exists` / `does not exist`, `Local number remaining = amount`
  (a Local variable row you can also add from the picker), `⏳ Wait 0.5 seconds`, `Go to layout
  Menu`, `Keyboard ▸ "jump" is down`, `push x moved toward 0 by push fade`, and inside a
  condition function `System ▸ Set return value to true` / inside an expression function `Set return value to
  jumps left`. The same sentence appears whether the row was typed
  in GDScript or picked from the palette - one grammar produces both - and the exact code is always on
  hover.

  ![Rows in the sheet's own grammar: a Keyboard trigger for "ui_accept" pressed, an OR block joining two conditions, and action rows reading System - Else, System - Subtract 1 from jumps left and f - Call Wall Jump](images/opened-pack-sentences.png)
- **A plain script is an object.** Its Include bar names it (`class_name`, else its scene's root node,
  else the file) with its class icon and the scene it lives in; its engine properties read under that
  name (`Player ▸ Set X to 100`, `Player ▸ rotation > 1.5`), never as `self`; global functions read as
  System (`System ▸ Print "ready"`). Any method call reads `Object ▸ what it does ▸ args` with the argument
  names Godot itself declares (`Sprite2D ▸ Play  name = "run"`), a node path by its last segment with its
  icon, `queue_free()` as Destroy. `delta` reads `dt`; the tick triggers read `Every tick (physics)` /
  `Every tick (draw)`. `and` never sits inside a condition cell - each conjunct is its own condition
  line, and `or` is the OR block. `"Score: %d" % score` reads `"Score: " & score`, `d["k"]` reads
  `d's "k"`, `arr[0]` reads `arr' item 0`; groups read as families (`enemies (group) ▸ Call Flee`,
  `For each e in group "enemies"`); loops read `Repeat 10 times`, `For "i" from 2 to 7`, `For each
  child`, `While`, `Stop loop`, `Next`; `randi_range(1, 6)` reads `random whole number 1 to 6`,
  `tween_property` reads `Tween position to target in 0.3 seconds`, `await x.opened` reads `⏳ Wait for signal
  x On Opened`, `await get_tree().process_frame` reads `⏳ Wait one tick`. A signal emit shows its
  payload by the signal's own parameter names (`Signal On Damaged  amount = 3  source = attacker`). A
  lambda connected to a signal (`$Timer.timeout.connect(func(): ...)`) reads as the trigger event it is,
  with the lambda's body as its rows, and the connect line keeps a muted `connects Timer On Timeout`
  note. One-line `if c: stmt` / `if c: return` / `else: stmt` lift as the same sub-events their
  indented twins do, byte-exact, and `@export_group` is recognised in either order around its `##` doc.

  ![The lifecycle words on two scripts of one scene: the scene's own script reading On start of layout, On end of layout, On draw with its drawing rows and On close, and the script on a child node reading On created and On destroyed instead](images/opened-script-words5.png)
- **Numbers read the way a person writes them.** `300.0` reads `300`, `0.50` reads `0.5`,
  `1_000_000` reads `1,000,000`, `1e3` reads `1000`, and the constants a reader recognises are named
  (`1.5707963` reads `π/2`; `τ`, `√2` and `√3` likewise, from a spelling long enough to mean them -
  `3.14` stays `3.14`). A 0..1 setting the project marked `@export_range(0, 1)` reads as a
  percentage (`Set opacity to 50%`). A reading only: the literal in the file never moves, and the
  params dialog still puts the author's own GDScript in front of you.
- **Ranges, angles, distances, areas and "about" are ONE condition each.** `x >= 0 and x <= width`,
  `0 < hp and hp < max_hp`, `level in range(3, 6)` and the inverted `not (t >= 0.2 and t <= 0.8)` all
  read as one `is between` row - the ✕ carrying the inversion - and a strict end says which one it is
  (`(exclusive)`, `(exclusive top)`, `(exclusive bottom)`). `in range(3, 6)` reads `between 3 and 5`,
  because Godot's range stops before its second number. The same idea covers every kind of value the
  sheet already has a word for: `abs(angle_difference(rotation, target)) < deg_to_rad(10)` reads
  `angle is within 10° of target`, a wrapped angle between two bounds reads `is between angles 30° and
  60°`, `angle_difference(a, b) > 0` reads `is clockwise from`, `position.distance_to(t) < 100` reads
  `is within 100 of t`, `Rect2(0, 0, 640, 360).has_point(position)` reads `is inside area 0, 0 - 640 ×
  360`, and `is_equal_approx` / `is_zero_approx` / `abs(a - b) < 0.001` read `is about` (a body's
  `is_zero_approx(velocity.length())` reads `speed is about 0 (not moving)`). Angles are shown in
  degrees, with the radians the file holds on hover. Every one of them is also in the Add condition
  dialog, writing back exactly the line it reads.
- **The cooldown idiom, in seconds.** `Time.get_ticks_msec() - last_shot > 500` reads `System ▸ 0.5
  seconds have passed since last shot`, and `last_shot = Time.get_ticks_msec()` reads `Set last shot
  to now`; the wall-clock spelling adds `(clock time)`, because that number keeps counting while the
  game is closed. Nobody has to know what a tick is or do the division.
- **Platform words, and the layout bounds.** On a CharacterBody, `is_on_floor()` / `is_on_wall()` /
  `is_on_ceiling()` read `Is on floor` / `Is by wall` / `Is touching ceiling`, and `velocity.y` /
  `velocity.x` against zero read `Is jumping` / `Is falling` / `Is moving` - the vertical words follow
  the AXIS rather than the sign, so a 3D body reads correctly too, and a plain node's vertical speed
  keeps its comparison (a projectile is not jumping). `position.x < 0 or position.x >` the viewport's
  width reads `Is outside layout (left or right)`, a single edge says which side, and
  `get_viewport_rect().has_point(p)` reads `Is on-screen` - its negation reads `Is outside layout`.
  `get_viewport_rect().size.x` / `.y` read as `ViewportWidth` / `ViewportHeight`.
- **Layout, pause and time-scale words, always on.**
  `get_tree().change_scene_to_file("res://levels/level_2.tscn")` reads `System ▸ Go to layout Level 2`
  with the file path on hover, `reload_current_scene()` reads `Restart layout`, `get_tree().paused`
  reads `Pause the game` / `Unpause`, `Engine.time_scale = 0.5` reads `Set time scale to 0.5`, and
  `get_tree().quit()` reads `Quit game`. These are never behind the Familiar Words toggle: they are
  the names the shipped scene-flow rows already carry.
- **Lists, tables and text in the sheet's own words.** `items.append(x)` reads `Push back x to
  items`, and `push_front` / `pop_back` / `insert` / `remove_at` / `erase` / `clear` / `sort` /
  `shuffle` / `reverse` read as `Push front`, `Pop back of`, `Insert x at 2 in`, `Delete at 0 in`,
  `Delete value x from`, `Clear`, `Sort`, `Shuffle` and `Reverse` - the same rows the List module
  ships, word for word. `inventory.erase("potion")` on a declared `Dictionary` reads `Delete key
  "potion" from inventory`, and `label += "!"` reads `Append "!" to label` rather than as
  arithmetic, because adding to text puts it on the end.
- **Enum values in the sheet's words.** A number written where an engine enum is expected reads as
  the member it names - `process_mode = 3` reads `Set process mode to Always`, `texture_filter = 1`
  reads `Set texture filter to Nearest`, `horizontal_alignment = 1` reads `Set horizontal alignment
  to Center` - and so does a number written into a variable the sheet declared with one of its own
  enums (`dir = 2` reads `Set dir to DOWN`). The number is still one hover away.
- **Physics layers and input actions by their PROJECT names.** `set_collision_layer_value(2, true)`
  reads `Set collision with layer "Enemies" on` and `collision_layer = 5` reads `Set collision
  layers to "World", "Player"`, from the names Project Settings holds; a layer the project never
  named keeps its number. The DEVICE an action is bound to picks its object too, so an action bound
  only to mouse buttons reads under `Mouse` and one bound only to a pad under `Gamepad`.

<img src="images/batch6-reading.png" alt="A hand-written script opened as a sheet: an On Ready event whose actions read Push back, Push front, Insert at, Delete at, Delete key, Shuffle, Append, Set collision with layer Enemies on, Set process mode to Always, Set Y to 1,000,000, Set angle to π over 2 and Call Reset at end of frame, followed by two top-level Keyboard trigger events for jump pressed and fire released." width="720">

- **Deferred work says the delay out loud.** `call_deferred("reset")` reads `Call Reset (at end of
  frame)`, `set_deferred("visible", true)` reads `Set visible to true (at end of frame)`, and
  `reset.call_deferred()` reads the same - the words `queue_free()` already reads in. A handler the
  file wired with `connect(_on_beat_timeout, CONNECT_ONE_SHOT)` opens as its trigger event with a
  `Trigger once` chip beside it, and the connect line is re-emitted verbatim, flags and all.
- **A tween chain reads as Tween actions, one action per row.** `var t = create_tween()` reads
  `Local object t = a new tween`; each `t.tween_property(...)` under it reads
  `Player ▸ Tween position to target in 0.5 seconds` on the object being tweened, with
  `.set_trans(...)` / `.set_ease(...)` as an `ease = Sine out` chip. The second step and every one
  after it says `(after the previous)`; once `t.set_parallel()` has been called they say `(at the
  same time)` instead. `t.set_loops(3)` reads `Tween repeat 3 times`, `t.tween_interval(0.5)` reads
  `Tween wait 0.5 seconds`, `t.tween_callback(queue_free)` reads `Tween then Destroy`, `t.kill()`
  reads `Stop tween` and `await t.finished` reads `System ▸ ⏳ Wait for tween to finish`. The
  property is the sheet's own word for it - `modulate:a` is **opacity**, `scale` is **size**,
  `rotation` is the **angle** - and a property the table does not name keeps its own spelling. The
  chain is joined by the local's name, walked in file order, so a receiver the file never declared
  from `create_tween()` keeps its plain call reading rather than being given a Tween sentence. A
  statement broken across lines with a trailing `\` reads as the one statement it is.

  A chain written on ONE line reads as the step it takes rather than as the call it starts with:
  `create_tween().set_loops(3).tween_property(self, "position", p, 0.5)` is
  `Tween position to p in 0.5 seconds  repeat 3 times`. The whole dotted chain on the line is walked,
  so the step is the row and the chain calls in front of it are muted notes on it - `repeat 3 times`
  or `repeat forever` from `set_loops`, `(at the same time)` from `set_parallel`.

  ![A tween chain read as Tween actions, and a head whose Instance variables folder carries the accessor events](images/opened-script-tween-and-head-accessors.png)

- **A Timer node reads as the Timer behavior.** `$Timer.stop()` reads `Stop timer "Timer"`,
  `$Timer.start(2.0)` reads `Start timer "Timer" for 2 seconds (once)` - whether the line is still
  hand-written text or the importer has already claimed it as the shipped Start Timer action, since
  the lifted row is routed back through the same sentence, `not $Timer.is_stopped()` reads `Is
  timer "Timer" running` (the bare spelling says stopped), and `$Timer.time_left` reads
  `Timer.CurrentTime("Timer")`. The node's name is the tag and the object is the script's own object,
  because the timer belongs to it. The `(once)` / `(regular)` mode is read off the file's own
  `one_shot` line. A timer held in a variable has no tag to prove, so it keeps the plain call reading.

- **A sprite, a sound and a game-feel line read as the object's own rows.** `sprite.flip_h = dir < 0`
  reads `Set mirrored when dir < 0` (a mirror decided by a test says the test; a plain `= true` is
  just `Set mirrored`), `flip_v = true` is `Set flipped`, `frame = 3` is `Set animation frame to 3`,
  `speed_scale = 2.0` is `Set animation speed to 2`, and `texture = load("res://hero.png")` is
  `Set image to hero.png`. An AnimationTree's `set("parameters/blend_position", dir)` is `Set blend
  blend position to dir` and its `travel("Hurt")` is `Travel to animation state Hurt`, in either
  spelling. On the audio side `stream = preload("res://jump.wav")` is `Set sound to jump.wav`,
  `pitch_scale` is `Set pitch`, `bus = "SFX"` is `Set bus to SFX`, `volume_db = linear_to_db(0.5)` is
  `Set volume to 50%` (the decibel conversion is Godot's business, not the reader's - a raw dB number
  keeps its unit), `seek(12.0)` is `Seek to 12 seconds`, and both `is_playing()` and `playing` read
  `Is playing`. `grab_focus()` is `Set focus`, `popup_centered()` is `Show dialog (centred)`, and
  `AudioServer.set_bus_volume_db(0, linear_to_db(v))` is `Audio ▸ Set master volume to v (0 to 1)`.
  Finally the game-feel snippets: a symmetric random camera offset is `Shake by s`, `base_y + sin(t *
  3.0) * 8.0` is `Bob y` with `sine · magnitude 8 · 3 per second` as its note, and
  `scale.lerp(Vector2.ONE, 10 * delta)` is `Ease size back to normal at 10`. Every one of these is
  claimed only at its exact shape - a lopsided shake or a lerp to some other size keeps the property
  write it is - and every one names the pattern it read as, which is what the event's pattern chip
  and the Manual show.

  ![A sprite, UI, sound and game-feel script opened as a sheet](images/reading-sprite-sound-juice.png)

#### Input, gamepads and sensors

- **The Input Map is an object, and the file says which controls it uses.** An opened script that names
  any control grows an **Input** head bar - `this script uses 4 actions - jump, move left, move right,
  fire - Project ▸ Input Map` - and one line per control inside it saying what that control is bound to
  in the sheet's own spelling: `jump  Space · A button · Up`, `fire  Left mouse button · Right trigger`.
  The Object bar carries the same list in an **INPUT** section. Bindings come from `project.godot`, and
  nothing is written on a read. A control the script names that the Input Map does not have wears a ⚠ in
  both places and gets a Doctor warning naming the fix - that is the typo every beginner makes, and until
  now it compiled, printed nothing, and simply never fired. Drag a control off the bar onto the canvas
  and the sheet writes its `On <action> pressed` event.
- **Analog reads in the Gamepad object's words.** `Input.get_joy_axis(0, JOY_AXIS_LEFT_X)` reads
  `axis Left analog X of gamepad 0`, `Input.get_joy_name(0)` reads `name of gamepad 0`, and
  `Input.get_connected_joypads().size()` reads `gamepad count`. The stick names are the Gamepad object's
  own (Left analog X / Y, Right analog X / Y, Left trigger, Right trigger), so a typed line and a picked
  row say the same thing, and the exact-match spelling `Input.is_action_pressed("accelerate", true)`
  reads `Is button down "accelerate" (exact match)` rather than leaving a bare `true` on the row.
- **Gamepads by number, and the per-player conventions.** `event.device == 1` inside a joypad-button
  branch is the gamepad NUMBER the sheet already counts from 0, so a local-multiplayer script reads
  `On gamepad 1 button A pressed` instead of arithmetic. The two naming conventions a two-player project
  uses - `p2_jump` and `jump_2` - both read as `jump` on gamepad 1 and group under that pad.
- **A gamepad branch that names a device reads as one row.** `if event is InputEventJoypadButton and
  event.pressed and event.device == 0 and event.button_index == JOY_BUTTON_A:` reads `Gamepad ▸ On
  gamepad 0 button A pressed`, in the Gamepad object's own words, because the device index IS the
  gamepad number. A branch that names no device keeps `On button A pressed`; a Keyboard branch keeps
  its `event.device == 1` as an ordinary comparison, since a keyboard has no number in the sheet.
- **Handheld sensors read on the Touch object.** `Input.get_accelerometer()` reads `acceleration`,
  `get_gravity()` reads `gravity`, `get_gyroscope()` reads `rotation rate` and `get_magnetometer()` reads
  `magnetic field`. A `var a = Input.get_accelerometer()` is a Local variable row followed by
  `System ▸ Set a to acceleration` - one action per row, never a bare `Local a = ...` cell. They all
  report 0 on desktop, and every one of them says so.

#### Signals wired somewhere else

- **A signal wired to another object's function reads as the trigger calling it.**
  `$Button.pressed.connect(player.reset)` reads as the event it is - `Button ▸ On pressed` on the
  left, `player ▸ Call Reset` on the right - and `$Timer.timeout.connect(spawner.spawn_wave.bind(3))`
  puts the bound value in an ordinary parameter chip, `count = 3`, named by the callee's own
  parameter name whether that function belongs to the engine or to one of your own classes. The
  `Callable(obj, "method").bind(...)` spelling reads the same, and a `CONNECT_ONE_SHOT` connection
  wears the sheet's `Trigger once`. That is the third way real code wires a signal - after a handler
  declared in the file and a lambda - so all three now read as trigger events. The connect line keeps
  its muted `connects Button On Pressed` note, and the file keeps its one line.

<img src="images/wired-call-rows.png" alt="A script whose _ready wires three signals: the connect lines read as muted connects notes, and under them three trigger events read StartButton On Pressed with player Call Reset, WaveTimer On Timeout with hud Call Show Wave count = 3, and a one-shot WaveTimer On Timeout carrying a Trigger once chip with count = 9." width="720">

#### Patterns - the shapes several lines make together

Some things a script says are not in any one line. A `-=` on its own is arithmetic; the same `-=` by
a per-frame delta, on a number the file asks about against zero, is a countdown. So the whole file is
read once when the rows are built, and the events that turn out to BE a known pattern say so.

- **Both halves are always required.** A countdown must be counted down by a delta AND compared to
  zero; a pool must be drained behind an `is_empty()` guard AND have an `instantiate()` fallback; a
  sequence needs two waits AND something to do between them. One half alone keeps the ordinary
  reading, because a pattern that is almost right is worse than the code it replaced.
- **The evidence is the source lines, never a paraphrase.** Every pattern an event claims carries the
  exact lines that made the sheet think so, so the reason a row says what it says is one hover away.
- **A shipped behavior is offered where one exists.** A hand-rolled object pool names the Object Pool
  behavior in its claim, so the sheet can offer to swap the hand-written shape for the pack.
- **What reads as a pattern today:** countdowns (`Count down x`, `Start x for N seconds`, `x has run
  out`, `x is running`), object pools (`Create object … [pooled]`, `Return to pool`), wait sequences
  (a `sequence · N s` chip on the function's header), saving and loading (**Local Storage**: `Set
  item player/score to score`, `Local Storage.Item("player/score")`, `Save`, `Load`, `save file is
  missing`), existence and relations (`t exists`, `Forget target`, `Remove from layout`), and the
  list and table reads (`the first 3 of items`, `the sum of price over items`, `Sort items by price`,
  `items contains sword`, `stats "hp" (or 100 when missing)`).

All of it is display only. Nothing a pattern reading decides changes a row, so an opened file still
saves back byte for byte and the GDScript it compiles to is untouched.

#### A hand-rolled behavior reads with the behavior's own words

The most common shapes of all are a shipped behavior written out by hand, so those read in the
behavior's vocabulary and their event claims the pack that could replace them:

- **Bullet** - `velocity = Vector2.RIGHT.rotated(rotation) * speed` reads `Set angle of motion to
  angle`, `position += velocity * delta` reads `Move`, `speed += accel * delta` reads `Set speed to
  speed accelerating by accel`, `velocity.y += gravity * delta` reads `Set gravity to gravity`,
  `velocity.bounce(n)` reads `Bounce off solids`, and `position.distance_to(start) > range_px` reads
  `Distance travelled > range px`.
- **Turret** - the nearest-in-family loop is claimed as `Acquire nearest enemy within range px` with
  its own lines as evidence, `if target:` reads `Has target`, and the `lerp_angle` toward the target
  reads `Rotate toward target at turn rate`.
- **Move To** - `position.move_toward(destination, speed * delta)` reads `Move toward destination at
  speed`, the flag beside it reads `Start moving` / `Is moving` / `Stop`, and the distance check
  reads `Has arrived`.
- **The one-liners** - `Rotate clockwise at k (degrees per second)`, `Wrap around layout
  horizontally`, `Bound to layout (inside …)`, `Pin to anchor (position · offset …)` and `Fade out
  over 1 seconds (then destroy)`.

The same gating applies: an acceleration only reads as a bullet's in a file that ALSO writes the
angle-of-motion line and the step, a distance only reads as distance travelled when the file declares
the point it is measured from, and a flag only reads as a glide's state when the file both raises and
lowers it. And a line the importer lifted to a shipped row is read back through the same shape, so an
opened file says the same thing before and after the lift.

![A projectile script read as an event sheet: Set speed to speed accelerating by accel, Set angle of motion to angle, Set gravity to gravity and Move under one tick event, with Distance travelled greater than range px as the condition that destroys it](images/opened-script-behaviors.png)

![The same file further down: Move toward destination at speed, Has arrived and Stop for the glide, then Rotate clockwise, Wrap around layout horizontally, Bound to layout, Pin to anchor by position and by angle, and Fade out over 1 seconds then destroy](images/opened-script-behaviors-one-liners.png)

#### The reading lenses - names you can turn on and off

- **Reading lenses.** In Reading mode (a read-only preview, or the Simple pill's Reading lens) names read
  as words (`_coyote_timer` -> `coyote timer`, a knob with its Inspector capitalisation), property chains
  read possessively (`host's velocity X`), NOT is the red ✕ in the icon column, the host and any `$Node` /
  `%Node` / `@onready` reference show their class icon, sub-events hang off tree guide lines, a call to one
  of the sheet's own functions reads `Functions ▸ Call Add Look  x = mouse's ΔX  y = mouse's ΔY`, and code
  that could not lift is one collapsed card with a line count. **View > Humanized Names** turns the name
  lens on or off for editable sheets; nothing on the sheet is scaffolding until you press **Edit Events**.

  ![The same pack read with the lenses off and on: raw member names and property chains on one side, humanized words on the other - coyote timer, host's velocity X, Wall Jump Enabled is true](images/opened-pack-lenses.png)
- **Expression names, under Familiar Words.** With **View > Familiar Words** on, the values read under
  the names a sheet author types into an expression field: `a.position.distance_to(b.position)` reads
  `distance(a, b)`, `a.get_angle_to(b)` reads `angle(a, b)`, `s.to_lower()` / `s.to_upper()` read
  `lowercase(s)` / `uppercase(s)`, `s.substr(0, 3)` and `s.right(2)` read `left(s, 3)` and
  `right(s, 2)`, `s.find("x")` reads `find(s, "x")`, `s.split(",")[i]` reads `tokenat(s, i, ",")`,
  `"%03d" % n` reads `zeropad(n, 3)`, `s.length()` and `arr.size()` both read `len(x)`,
  `Engine.get_process_frames()` reads `tickcount`, `randi_range(1, 6)` and `randf_range(0.5, 2)` read
  `random(a, b)`, `randi() % n` reads `random(n)`, and `[Color.RED, Color.BLUE].pick_random()` reads
  `choose(red, blue)`. `lerp`, `clamp`, `abs`, `min`, `max` and friends are unchanged - both
  vocabularies spell them the same. With the glossary off, `s.length()` reads `length of s` as it
  always has; Godot's spelling is on hover either way.

- **The Godot systems a script is built from.** Four shapes that only mean something across several
  lines read as the rows an event sheet already has for them, and every one of them is also
  writable in the same words, so a written and a picked block are the same bytes.
  - **Loading a layout in the background.** `ResourceLoader.load_threaded_request(path)` reads
    **System ▸ Load layout Level 2 in the background**, `st == ResourceLoader.THREAD_LOAD_LOADED`
    reads **System ▸ layout Level 2 has finished loading**, the progress array read by index reads
    **System.LoadingProgress**, and `change_scene_to_packed(load_threaded_get(path))` reads
    **System ▸ Go to layout Level 2**. The layout is named the way the file is named, whether the
    path is written in the call or held in a variable the file declared from a literal.
  - **Movement math, on a `CharacterBody2D` or `CharacterBody3D` only.** `velocity.y += gravity *
    delta` reads **Apply gravity**, `move_toward` on one axis reads **Accelerate x toward … at …
    (per second)**, `limit_length` reads **Limit speed to …**, `move_and_slide()` reads **Move (and
    slide along what it hits)**, `set_collision_mask_value(2, false)` reads **Disable collisions
    with …** (by the project's own layer name where it has one),
    `add_collision_exception_with(x)` reads **Ignore collisions with x**, `look_at(p)` reads **Set
    angle toward p**, `lerp_angle` on the rotation reads **Rotate toward … at … (per second)**, and
    `c.get_collider().is_in_group("enemy")` reads **c ▸ collided object is in family enemy**. A plain
    node's `velocity` is just a variable, and a step that is not scaled by the frame time is not one
    of these words, so neither is claimed.
  - **Multiplayer.** An `@rpc` function reads with its name in the condition lane -
    **Multiplayer ▸ On message Take Damage** with its parameter chips and its mode words muted
    beside it (*from any peer · runs here too · reliable*). `f.rpc(10)` reads **Multiplayer ▸ Send
    Take Damage to everyone** with the payload as named chips, `f.rpc_id(1, 10)` reads **to the
    host**, `f.rpc_id(peer, 10)` reads **to peer**, `multiplayer.is_server()` reads **Is host**,
    `is_multiplayer_authority()` reads **Owns this object**, and `multiplayer.get_unique_id()` reads
    **Multiplayer.MyID**.
  - **Navigation.** `agent.target_position = p` reads **Find path to p**, the
    direction-to-the-next-waypoint step reads **Move along path at speed**, with **(avoiding
    others)** when the file wires the `velocity_computed` callback, and `is_navigation_finished()`
    reads **Has arrived**.

  Each of these is also a claim in the sheet's pattern registry, recorded on the event that owns it,
  with the exact source lines as its evidence and - where one ships - the behavior that could
  replace the hand-written block.

- **The long tail** - the lines a finished game writes and a first script does not. Every one of them
  already had a sentence somewhere on the sheet, and the reading says it.

  - **Web requests are the AJAX object's, and JSON is the JSON object's.** `http.request(url)` reads
    **AJAX ▸ Request url**; the same call carrying the POST verb and a body reads **AJAX ▸ Post data
    to url**; `result != HTTPRequest.RESULT_SUCCESS` reads as the inverted **request succeeded**; and
    `body.get_string_from_utf8()` reads **AJAX.LastData**. `JSON.parse_string(x)` reads
    **JSON.Parse(x)** and `JSON.stringify(x)` reads **JSON.ToString(x)**. A whole run of indexes is
    one address into one table: `data["scores"][0]["name"]` reads **data's scores 0 name** (a single
    index keeps the sentence it already had).
  - **Lights.** A 2D or 3D light's brightness reads **Set light energy to 50%** (a percentage,
    because that is how a reader sets it), its colour **Set light colour to orange**, its switch
    **Set light on** / **Set light off**, and its shadows **Set shadows on** / **off**. A
    `CanvasModulate` is a whole layer's tint - **System ▸ Set layer tint** - and a world
    environment's ambient energy is **System ▸ Set ambient light to 30%**.
  - **3D.** `look_at(p, UP)` reads **Look at p**: the up vector is Godot's bookkeeping, not part of
    what the row says. An object's own axes read as the directions they are - `-basis.z` is
    **Player's forward**, `basis.x` is **right** and `basis.y` is **up**.
  - **Background work.** `thread.start(bake.bind(level))` and `WorkerThreadPool.add_task(...)` both
    read **System ▸ Run Bake in the background** with the values handed over as chips named by the
    function's own parameters; the group spelling adds **64 times**; and every wait reads **⏳ Wait
    for it to finish**. The claim offers the shipped Run In Background behavior.
  - **The signal steps that are actions.** Wiring a handler up and taking it down are not events, so
    they read as the actions they are: **Wire On died to On Died** (with an **at end of frame** chip
    when the connection is deferred), **Unwire On died from On Died**, and the question **On died is
    wired to On Died**. A variable the sheet typed `Signal` declares as a local signal and fires as
    **System ▸ Fire sig**.
  - **Calls made by name.** `call("heal", 5)` and `callv("heal", [5, self])` read as the ordinary
    **Functions ▸ Call Heal** row with its parameter chips, plus the muted **by name** / **by name,
    with a list** that says how it was reached. `Callable(self, "heal")` reads **the function Heal**.
  - **Media.** A `VideoStreamPlayer` is the sheet's Video object - **Set video to intro.ogv**,
    **Play**, **Pause**, **Is playing** - and a positional audio player's `max_distance` and
    `attenuation` read **Set hearing distance** and **Set falloff**.

  These claim four more patterns on the event that owns them - web requests, lighting, first-person
  look and background work - and the last two offer the behavior that does the whole shape.

  ![A 3D script read as an event sheet: a web request under the AJAX object, a light's energy and shadows, a video set and played with a positional sound's hearing distance and falloff, the mouse-look trio as one Mouse look row with its values muted beside it, a music crossfade as one row, work run in the background with its wait, and a signal unwired](images/opened-script-long-tail.png)

  ![A controller script read as an event sheet: a layout loaded in the background with its finished-loading condition, the movement math as Apply gravity / Accelerate / Limit speed / Move, the collision switches, a navigation agent's Find path to and Has arrived, and the multiplayer messages sent to everyone and to the host](images/opened-script-systems.png)

### The objects of an opened file - what they are, and where you find them

A sheet says what a file DOES with its objects. These say what those objects ARE, and give you the bar
you reach for them from. All of it is derived from two places you already have - the object's own
script, and the scene it is placed in, both read as text - so there is no list to maintain and nothing
is instantiated to answer a question.

- **The head carries the object's Behaviors and Families.** Two folded folders before the settings:
  `▸ Behaviors  on this object - Health · FPS Controller` (the pack nodes mounted on the object in its
  scene, each opening to what the scene set on it, `Health  max health = 50`) and
  `▸ Families  this object belongs to - player, damageable (groups)`. A Godot group is the sheet's
  family; the Godot word stays in the muted note and nowhere else.
- **Object properties say what the object IS.** Click an object label (or double-click its entry in the
  Object bar) and the popup adds, above what this sheet does with it: **Instance variables**,
  **Functions** (a function that answers yes-or-no is marked `condition`), **Triggers** (its signals,
  read `On Died`, `On Hit  body`), **Behaviors** and **Families**. Two buttons start using it -
  **Add condition** and **Add action**, both opening the picker already scoped to that object - and
  **Open enemy.gd as sheet** jumps to the file that says what it is.
![Object properties for Player: an Instance variables table with Name, Type, Initial value and Inspector columns - speed number 200.0 ticked into the Inspector, hp whole number 100, alive boolean true - each row ending in a pencil and a cross, above + Add instance variable; below it the Add global variable form with Name, Type, Value and Write into, and the row it will write previewed as Global number Score = 0](images/instance-variable-table.png)

- **The object this file IS answers with an editable variable table.** For that one object - the
  thing the open script declares, not the nodes it merely names - the **Instance variables** row
  becomes a table you work in: **Name**, **Type** (a dropdown of the sheet's own type words),
  **Initial value**, an **Inspector** tick, and **✎ ✕**. ✎ opens a description field under the
  variable; ✕ deletes it; **+ Add instance variable** opens the Add variable dialog on the Instance
  scope. Renaming in the Name field is **Rename Everywhere** and picking a new type is **Change Type
  Everywhere**, because a name and a type are used by rows all over the sheet. The same table sits on
  the Properties bar whenever that object is selected, so a run of variables can be added, retyped
  and described without opening anything. Every edit writes the same `var` / `@export var` line the
  Add variable dialog writes, in one undo step, and leaves every other line of the file untouched.
- **The Object bar is a list you glance at, filter, and drag from.** Three sections: **USED IN THIS
  SHEET** open, with a per-object count and behaviors nested under the object they ride on; **ALSO IN
  THE SCENE** collapsed (the rest of the scene, one line away, no counts because there are none); and
  **GLOBALS & FAMILIES** collapsed. A filter box narrows as you type and Enter on a single match pins
  it; the header's `⇅` switches between reading order, count and name and remembers which. An object
  this sheet uses that the scene does not have is flagged `⚠ not in Player.tscn` rather than listed
  like any other node, and hovering a count splits it into `2 conditions · 3 actions · 1 trigger`.
  Hover an entry to preview its rows, click to pin that highlight, double-click for Object properties,
  right-click for **Add condition · Add action · Add behavior… · Select in scene · Open its script as a sheet**, and
  drag one onto the sheet to start an event on it - dropping it in an existing event's action lane
  adds an action to that event instead. A script that is not on a scene yet says so, and says what to
  do about it.
- **Add behavior… is one dialog for every pack.** Right-click an object in the Object bar and pick
  **Add behavior…** (the head's Behaviors folder has the same "+"). The shelves down the top come
  from the packs' own categories, the search reads a pack's name, its one-line pitch and its
  folder ("jump" finds the platformer pack), and the card shows the pack's own `@export` knobs as
  fields you fill in before it lands. **Where** offers *as a behavior node* - a node carrying the
  pack's script under the object, which is how every pack works - and *written into this script*
  for a pack that declares it can be (`## @ace_inline_capable`: the pack's knobs become the
  script's own exported variables). After adding, the picker under the object lists the
  behavior's conditions, actions and expressions, the head's Behaviors folder shows it, and the
  Project Doctor checks the host the pack needs (a CharacterBody2D for the platformer pack).
- **The installed packs are a list, not a folder.** **Tools ▸ Addon manager…** is a table over the
  pack registry: pack, its version (read from its own `@ace_version`), an **enabled** tick, and
  **Guide / Update / Publish…** per row. Switching a pack off takes its conditions, actions and
  expressions out of the picker on the next refresh - its files stay where they are and the
  sheets using it still open, and the Doctor names any sheet that still does. Under the table:
  **Import from .zip…** and **Import from URL…** (an archive that would write outside
  `eventsheet_addons/` is refused whole, before anything lands), **Check for updates** (which asks
  every pack that names a published source with `## @ace_source(...)`), and the Asset Library door.
- **The words are yours.** **Settings ▸ Words** is every word the sheet lets you choose, on one
  page: an inheritance set, a scene, `_process`, an attached pack, a Godot group,
  Array/Dictionary, `queue_free`, and the reader. Each row shows the word it reads as with
  Familiar Words on and the word it reads as with it off, as a dropdown of the two defaults plus
  any extra offered word (*Kind* for an inheritance set) plus **custom…** for a word you type.
  Under the table, one event rendered in the words currently chosen, so the page never asks you
  to imagine the result, and **Reset to defaults**. The choices are yours alone - they are stored
  with the editor settings rather than in the project - so a Godot user and someone arriving from
  another event-sheet editor can read the same sheet in different words.
- **A finding with a one-step fix shows it.** In the Project Doctor, selecting a finding that has
  a one-step answer draws a chip per answer: an unknown control offers *Add "dash" to the Input
  Map* and *Pick an existing action…*, a variable read but never set offers *Declare it*, a pack
  you switched off that a sheet still uses offers *Switch it back on*. Each applies through the
  same operation the dock already owns, and the audit re-runs immediately, so the finding's
  disappearance is proven rather than assumed.
<img src="images/add-behavior.png" alt="The Add behavior dialog for Player: a scrolling row of category shelves above a search box, a list of pack cards each naming the pack and its one-line pitch, and on the right the selected pack's properties as editable fields above a Where dropdown reading as a behavior node." width="620">

<img src="images/addon-manager.png" alt="The Addon manager: a table of installed packs with columns pack, version, enabled, what you can do and reads, each row showing the pack name over its eventsheet_addons folder, its version, a ticked enabled box and Guide, Update and Publish buttons, above Import from .zip, Import from URL, Check for updates and Find more, and the line 91 packs installed, 0 switched off." width="620">

<img src="images/words-settings.png" alt="The Words page: a table headed what it names, with Familiar Words on, off, listing an inheritance set as Family or Base class, a scene as Layout or Scene, _process as Every tick, an attached pack as Behavior, a Godot group as Family (group) or Group, Array slash Dictionary as list slash table, queue_free as Destroy and the reader as Manual, above a live preview of one event and a Reset to defaults button." width="560">

- **Objects wear their own picture.** When an object's scene has a Sprite2D / AnimatedSprite2D /
  TextureRect on or under its root, that texture becomes the object's mark - on the Include bar, in the
  Object bar, in the popup and on every object label - falling back to the class icon. The thumbnail
  comes from the editor's own preview cache, so nothing new is rendered.
- **Tabs and titles name the object, not the file.** A tab reads `Player` with that picture, a pack
  reads by its pack name (`FPS Controller`), an autoload reads as a global. The file name sits on the
  tooltip, where a storage detail belongs; two open objects with one name get the file added.
- **Signals say who listens.** An emit wears a muted `→ HUD, Level (2 listeners)`; the handler on the
  other end wears `← emitted in player.gd: Take Damage`. Both are click-to-jump. They come from one
  project-wide index of `.connect` lines, `emit` sites and `.tscn` `[connection]` rows, built once per
  session, so a note never costs a scan.

<img src="images/objects-rail.png" alt="The Object bar: a header naming the scene and the used/more counts, a filter box, an open USED IN THIS SHEET section listing Player, Sprite2D and Health with per-object row counts, and collapsed ALSO IN THE SCENE and GLOBALS AND FAMILIES sections." width="420">

<img src="images/object-popup.png" alt="Object properties for Player: type CharacterBody2D, its instance variables, its functions with their inputs, its triggers, the Health behavior with the value the scene set on it, and its families, above Add condition, Add action and the three navigation buttons." width="560">

The Object bar's **INPUT** section and the **Input** head bar, on a script that reads four controls -
three the project has, and one it does not:

<img src="images/input-object-bar.png" alt="The Object bar's INPUT section listing ui_left with the bindings Left and A, ui_right with Right and D, ui_accept with Enter and Kp Enter, and a warning-marked dash reading 'not in the Input Map'; beside it the sheet's Input head bar saying 'this script uses 4 actions - ui_left, ui_right, ui_accept, dash - Project, Input Map' followed by each control's bindings, and the rows below reading Keyboard On ui_accept pressed, Keyboard dash is down and Gamepad On button A pressed." width="900">

### A whole scene, read in one place

An event sheet belongs to a layout; a Godot scene has several scripts. Right-click a `.tscn` in the
FileSystem and choose **Open as Event Sheet** (it is also in Sheet ▸ Open…, and you can drag a `.tscn`
onto the empty space of a reading, where a dropped scene has nothing else it could mean) to read the
whole layout at once: the scene's own bar
(`⇥ Level1.tscn  a  Node2D  4 scripts`), then every script the scene uses, in tree order, each under
its own object bar (`⇥ HUD  a  CanvasLayer  · hud.gd`, with `(x3)` when the same script sits on three
nodes) and the rows that script reads as beneath it. Signals the Godot editor wired in the scene file
read as triggers here too - including on a script sitting on a CHILD node, which on its own has no way
of knowing what wired it.

<img src="images/scene-as-a-sheet.png" alt="A scene opened as one sheet: a scene bar reading opened_scene_level.tscn a Node2D 3 scripts, then the Level object bar with the root script's rows under it, then the Player object bar with its own head and state folder." width="720">

The scene view is read-only for good. A scene is many files at once and the `.tscn` is not one of
them, so nothing is ever written back to it and there is no "Edit Events" to unlock: double-click an
object bar and that script opens as its own editable sheet, exactly as opening it from the FileSystem
would. A big scene never stalls the editor either - one script is read per frame behind the progress
strip, so the bars are on screen immediately and the rows fill in under them.

### What stays code still reads as what it is

Two kinds of block are no longer shown as code at all, because neither one is logic:

- **A run of comments becomes a real comment row.** Inside a function body it lifts to the same comment
  resource a sheet-authored comment uses, so it drags, disables and converts like any other comment - not a
  code block that merely looks like one. (A marker emission cannot reproduce exactly, such as `#no space`,
  stays verbatim rather than risk the round-trip.)
- **A multi-line collection literal lifts to a real "Declare" action.** A canonical
  `var waves := { ... }` becomes one `Declare waves - Dictionary, 3 entries` action whose entries are
  rows of their own - no bracket lines anywhere; they are re-emitted around the entries on save.
  Double-click an entry to edit its line in place (`"calm" = 12` - either side may change), and right-click the row for
  **Add Entry… / Edit Entry… / Remove Entry**. Extensions can build one too:
  `EventSheets.collection_decl("waves", [["\"calm\"", "3"]])`. A literal the emitter cannot reproduce
  byte-for-byte (a comma missing mid-table, a nested multi-line value) stays as per-line rows instead.
  File scope gets the same treatment: a `const` table opens as a Declare row too, bare final comma and
  all, with the same menu and inline editing.

<img src="images/decl-row-canvas.png" alt="A function body whose dictionary lifted to a Declare waves action: a header of three chips reading Declare, waves, Dictionary - 3 entries, then calm = 3, busy = 8 and swarm = 20 as single-cell rows, followed by ordinary Set variable and Print actions." width="720">

<img src="images/decl-top-canvas.png" alt="The plugin's own semantic analyzer opened as a sheet: Declare KNOWN_ANNOTATIONS - const Dictionary, 31 entries, with every annotation token as its own editable row." width="720">

<img src="images/block-views-before.png" alt="Before: a function body showing a GDScript badge over two comment lines, a System action for the opening line of a dictionary, and the dictionary entries stranded in a separate code block." width="720">

<img src="images/block-views-after.png" alt="After: the same body with the comments shown as plain notes, the dictionary declaration and each of its three entries on their own action rows, and the remaining statements as Set variable and Print action rows." width="720">

Both keep the file byte-for-byte identical when you save it untouched: comment notes are a pure view over
an unchanged block, and splitting a literal into per-entry rows is safe because consecutive code rows
re-emit by appending their lines in order. Double-click any row to open the code editor on the real lines.

Recognising a literal is deliberately fussy - a wrapped function call (a bare `(` opens arguments, not a
value), a literal with a statement after it, and one with a comment above its head are all left as ordinary
code, because in each of those cases something other than the value would be affected.

### Beginner spellings and the reading layer

The lift does not require style-guide code. Beginner spellings round-trip byte-exactly too:

- **Inferred `:=` variables** (`var hp := 100`, `const SPEED := 2.5`) lift to first-class variable
  rows that re-emit the walrus exactly as written.
- **Untyped lifecycle headers** (`func _physics_process(delta):` - no return arrow) lift to their
  trigger events carrying the source spelling, so saving changes nothing.
- **The prelude reads as the sheet's identity**: a Class setup bar showing the inheritance
  breadcrumb (`Node ▸ CharacterBody2D ▸ YourClass`, with the base class's own editor icon), whose
  dropdown lists the facts - `@tool`, remembered variables, setup line count - with the raw lines
  behind a double-click, and an enum reads as a sentence ("State is one of PATROL, CHASE or FLEE")
  that opens into one row per value.

And a hand-written `enum` + `match` state machine opens READING like a state machine: the tick
event's lane says "decides by state - 3 states below", each case is a ◆ `Current state is "patrol"`
row whose plain statements read as sentences and actions, and each transition is a nested CONDITION
row - the guard in plain words in the condition cell (`Can See Player`, with a small ƒ badge marking
a computed check), the state change as its action. Branching never renders in the action lane.

Those are the words the shipped **State Machine** behavior publishes too - **Go to state**,
**Current state is**, **On any state change**, **Time in state** - so a machine you wrote by hand and
a machine you attached read identically, and the event that asks the question claims the
`state_machine` pattern (with the State Machine pack named as the behavior it could become).

On real code the effect compounds. Here is the plugin's own semantic analyzer, whose annotation table is
31 entries long:

<img src="images/block-views-real-file.png" alt="A real source file opened as a sheet: a folded Class setup strip, a one-row collapsed const KNOWN_ANNOTATIONS table reading 31 entries, and a function whose body is an Expression verb row with condition and action rows." width="720">

---

### The Project bar - your project by kind, not by folder

Adopting an existing project starts with the same question every time: *where are my event sheets?*
Godot's FileSystem dock answers "where does this file live"; it has no way to answer "what are the
things in this project". The **Project bar** does, and it is a tab of the Object bar rather than a
dock of its own:

```
PROJECT                        ⚙ ✕
▾ Scenes  (layouts)
    Main Menu    main_menu.tscn
    Level 1      level_1.tscn
▾ Scripts  (event sheets)
    Player       player.gd · 82% reads as events, 3 script blocks
    Game         autoload · game.gd
▾ Classes  (object types)
    Player · Enemy · Coin …
▾ Base classes  (families)
    Player       Slime · Bat
▸ Behaviors     Health · Platformer · FSM …
▸ Sounds        12
▸ Files         art · data · shaders
```

![The Object bar with its Project tab selected: a PROJECT header with the count and a hide button, a filter box, then Scenes (layouts) open with each scene under its own name and its file muted beside it](images/project-bar.png)

The headings follow **View ▸ Familiar Words**: with the toggle off Godot's word leads and the other
editor's is muted beside it, and with it on the two swap - so both words are always on screen and the
one you think in comes first. A section both editors call the same thing (Sounds, Files) is not
dressed up as a translation of itself.

Four things a folder tree cannot show are what earn it the room:

- **which scripts open as sheets, and how far the reading got.** The scripts you have open carry
  their coverage line, so "which of these is still mostly code" is one glance.
- **which classes the project declares and who extends whom.** `Player  Slime · Bat` is the whole
  inheritance of your project, read as one line each. Only a class something else extends is a base
  class.
- **which behavior packs are installed.**
- **the last Project Doctor run's findings**, as a `●` (error) or `▲` (warning) on the item itself.

**It owns no action.** Right-click ▸ *New scene / New script / New class / Extract base class /
Import sound* each open Godot's own dialog or one the plugin already has, so there is never a second
way to do the same thing. Double-click routes: a scene opens in the 2D/3D editor and the sheet offers
the whole-layout-as-one-sheet reading beside it; a script opens as a sheet or in Godot's script
editor, whichever you set as your default; a class opens Object properties; a behavior opens its
pack's reference page. Dragging one onto the canvas means what the sheet already understands - a
class starts an event on it, a sound is a *Play sound* action, a scene is a *Go to layout* action.

**It costs nothing until you open it.** Off by default and collapsed to a thin strip, built the first
time it is actually shown, and refreshed on the same filesystem ping the rest of the editor listens
to (and only while it is open). It turns itself on for a project in Simple mode, or one started from
a template or from the migration guide; **View ▸ Project bar** toggles it by hand at any time and the
✕ hides it for that project. Filter box on top, arrows and Enter to open, Esc back to the sheet.

Three smaller surfaces come with it and are worth knowing on day one:

- **Sheet ▸ Start page** - templates by genre with a one-line pitch, what you had open last, and the
  tutorials, on one page. It opens by itself when nothing is open; a checkbox turns that half off.
- **Preview on the sheet** - `▶ Preview layout` (F6), `▶▶ Preview project` (F5) and `🐞 Debug layout`
  on the toolbar. While a game runs the first two become `■ Stop` and `↻ Restart`; Debug layout arms
  Event Trace, Live Values and breakpoints first.
- **View ▸ Add toolbar** - the eight Add gestures as buttons above the canvas, each naming its key on
  hover, on by default in Simple mode. And **Keyboard Shortcuts ▸ Preset ▾** offers *Another
  event-sheet editor*, which rebinds only the handful of keys that differ (invert to X, collapse and
  expand to Ctrl+E, preview to F4) and leaves everything rebindable underneath.

![The Add toolbar above the canvas: + Event, + Sub-event, + Condition, + Action, + Group, + Comment, + Variable, + Function, then a separator and the three Preview buttons](images/beginner-toolbar.png)

---

## 8. When to Wrap Existing Code in Your Own ACEs

You never *need* to - the escape hatches above cover everything. But if you find yourself reaching for the
same existing system constantly (your inventory, your dialogue manager), it's worth authoring a **behavior
pack** for it: that publishes its methods as real ACEs with proper pickers, parameter hints, and
autocomplete, turning the stringly *Call Method* calls into first-class, type-safe vocabulary. It's an
upgrade for ergonomics, not a requirement for interop.

**The one-line version:** if the system is your own class, you don't author a pack at all - add
`## @ace_expose_all(node)` at the top of the script and register it (`add_ace_provider_script("res://…")`,
or drop the file in `res://eventsheet_addons/`). Every public method/signal becomes a node-targeted ACE
with **zero per-member annotations** - see the [Custom ACEs Guide](GUIDE-CUSTOM-ACES.md#5-path-1-auto-ace-provider-scripts).
For a stateless helper (scoring, inventory math) use plain `## @ace_expose_all` (the owned-instance form).

### See what a script will publish before you commit to it

You never have to hand-write those annotations and hope. **Sheet ▸ Custom Actions…** opens the
**Custom ACE Providers** window: press **Add…** to browse to a `.gd` (or click one already registered),
and the **What it publishes** table lists one row per entry it would generate - *Publish*, *Kind*,
*Name*, *Category*, *Parameters*, and *Emits* (the exact GDScript that row compiles to). Browsing only
previews; **Register This Script** is a second, deliberate click, so a script never joins the
vocabulary unseen.

The table is also the editing surface, which matters because raw reflection guesses wrong on ordinary
game code: an untyped `func is_wave_active():` with no `-> bool` reads as an *Action* rather than a
Condition. Correct it in the table, then use one of the three actions beside it:

- **Curate Script…** writes your edits back into the file as `## @ace_*` comment lines. It shows you
  the exact lines first, backs the file up before writing (Tools ▸ Sheet Backups restores it), and
  re-applying the same edits is a no-op rather than a second copy of the block. **Only `##` comments
  are added** - no signature and no body is ever touched, which is why an entry's lane is corrected with
  `@ace_condition` instead of bolting `-> bool` onto your function.
- **Parameters…** shapes the selected entry's parameters: a *Hint* (`comparison` is the whole labeled
  operator dropdown in one word), *Options* written as `value=Label` separated by `|`, and a *Starting
  value* - what the row shows the moment it is dropped. These land as
  `## @ace_param(id, hint: …, options: …, default: …)`.
- **Keep Old Name…** is for after you rename a function. A rename changes the entry's identity and
  orphans every row that used it - *silently*, because each row carries the old call baked in, so the
  sheet still compiles clean and only breaks at game runtime. Select the entry under its new name, type
  what it used to be called, and a deprecated stand-in of the old name is appended that forwards to the
  new one. Nothing existing is edited, and the old name is hidden from the picker so it cannot be added
  to new work.

The same three moves are scriptable: `EventSheets.curate_provider(script_path, edits)` and
`EventSheets.keep_old_verb_working(script_path, old_member, new_member, message)`.

## 9. Use Cases

### 1. Level logic on top of a hand-written player

Your player controller stays code; a level sheet handles pickups, doors, and checkpoints by calling its methods (`$Player.stun(2.0)`) through Call Method or the reflected class vocabulary.

### 2. Your code calls a sheet-built function

A sheet's compiled script is plain GDScript, so `game_rules.gd` can call `quest_sheet.grant_item("key", 1)` like any other script - typed signature included.

### 3. A legacy signal drives new events

The old inventory emits `item_added`; an On Signal event picks it up and the new UI logic lives entirely in the sheet - no edits to the legacy file.

### 4. Adopting one script at a time

Open an existing `.gd` as a sheet: everything liftable becomes editable rows, the rest stays verbatim blocks, and the file round-trips byte-identically - migrate a node per week, never a rewrite.

### 5. The sheet as glue between two systems

The audio manager and the achievements autoload never knew each other; a ten-row sheet listens to one and calls the other, and the wiring is readable by the whole team.

### 6. A designer-tunable skin over a hardcoded system

Expose the knobs (`@export` variables with Inspector looks) in a sheet that forwards to the hardcoded system - designers tune in the Inspector, the system's code never changes.

### 7. Jam-crunch feature slapped onto a shipped prototype

Two days before submission you need a combo meter on a fighter whose input script is already a mess you daren't touch. Drop a behavior-mode sheet under the fighter, listen to its existing `hit_landed` signal with On Signal, and drive the whole meter in rows - the original script never opens.

### 8. Autoload event bus as the sheet's switchboard

Your project already routes everything through an `EventBus` autoload. A sheet reacts to `EventBus.wave_cleared` via an `autoload:EventBus` On Signal source and fires `EventBus.spawn_boss.emit()` back through Emit Signal On, so it plugs into the existing message flow without a single new wire on the emitting side.

### 9. Boss encounter scripted without a new class

The boss node runs a hand-written state machine, and the encounter (phase transitions, arena hazards, camera shakes) is one-off level content that does not deserve its own class. A behavior-mode sheet on the boss reads `host.health` with Get Property and calls `host.enter_phase(2)` with Call Method, keeping the encounter data next to the level instead of buried in engine code.

### 10. Handing a system to a non-programmer teammate

An artist wants to tweak enemy spawn timing but should never edit `spawner.gd`. Reverse-lift the spawner into a sheet once; from then on the timing lives in readable rows they can adjust safely, and the file still round-trips byte-identically for the programmer who owns it.

### 11. Trial run before committing to a pack

You suspect your inventory manager deserves first-class ACEs, but you are not sure the shape is right yet. Wire a few sheets to it with stringly Call Method calls first; if the same three methods keep showing up, that is your signal to add `## @ace_expose_all(node)` and promote them to type-safe vocabulary - no rewrite of the sheets that already use it.

## 10. Tips and Common Mistakes

Interop is broad, but it isn't magic - here's the candid list so nothing surprises you:

- **Raw expressions and *Call Method* are stringly and not type-checked at compile time.** A misspelled
  method, property, autoload, class, node path, or signal name compiles cleanly and only fails when the
  generated script loads or runs. The editor has an *advisory* lint, but it doesn't block. You don't get
  autocomplete-grade safety on an existing API you reach this way.
- **Renaming a function in your own provider script breaks rows quietly.** A row bakes in its call text
  when you drop it, so a call to a member the script no longer has still compiles clean and fails at game
  runtime. **Tools ▸ Project Doctor…** catches exactly this (its *orphaned-verb* check), and **Keep Old
  Name…** in the Custom ACE Providers window adds a forwarding stand-in so the existing rows keep working.
- **Signal connections to other nodes aren't validated** against the engine's known signals - wrong
  path/name is a runtime failure. (Only signals on `self` are checked and skipped-with-warning if missing.)
- **An already-scripted node needs behavior mode** (a child node), not a plain sheet - see section 5.
- **Cross-scene signal wiring** wants an autoload bus; `get_node("…")` connections are relative to the host.
- **The generic *On Signal* handler needs its Arguments field filled in to bind parameters** - type the
  signal's signature there (e.g. `amount: int`); a reflected `signal:NAME` trigger fills it in for you.
- **`host` binds in `_enter_tree`** - a behavior's calls before it enters the tree warn rather than act.
- **Don't hand-edit the generated `.gd`** - it's overwritten on recompile; the sheet is the source of truth.
