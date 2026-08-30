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
2. [The Interop Map](#2-the-interop-map) - and [Your Own Classes Are Already Vocabulary](#2b-your-own-classes-are-already-vocabulary),
   where [every call on a known class is a row](#every-call-on-a-known-class-is-a-row) and
   [every property too](#every-property-too)
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
7b. [Living in a Big Project: the Minimap, the Sheet Map and the History List](#7b-living-in-a-big-project-the-minimap-the-sheet-map-and-the-history-list)
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

### Every call on a known class is a row

A curated verb is a verb somebody sat down and wrote words for. The API underneath is far
bigger than that, and your own classes are bigger again - so wherever the sheet can work out
**what class the receiver is**, an ordinary call reads as an object-verb row without anybody
having written anything.

It can work that out far more often than you would expect: `self` is the class the script
extends, an `@onready` node carries its declared type, `var beat: Timer` says so in the
declaration, an autoload is a script at a known path, and a bare class name is a class. Once
the class is known, so are the method's parameter names and the method's own description.

<img src="images/derived-call-rows.png" alt="Three plain GDScript calls - beat.set_one_shot(true), hp_bar.set_indeterminate(true), hp_bar.set_show_percentage(false) - shown above the same three lines opened as a sheet: one event holding three rows reading beat Timer - Set one shot to true, hp_bar ProgressBar - Set indeterminate to true, hp_bar ProgressBar - Set show percentage to false." width="620">

Two things mark a **derived** row, so you always know which layer you are looking at:

- the verb reads in the plainer call style rather than the bold weight a curated sentence uses;
- the object column carries the class it was read off, muted beside the name.

Hovering one shows the method's own words - Godot's class reference for a built-in member, the
`##` lines above the declaration for a method in your own script - with the exact line of code
underneath, where it always was. `F1` on a built-in member opens its page in the Manual.

**A receiver the sheet cannot name is never guessed at.** `get_parent().thing()`, a variable
that only ever gets its value at run time, an untyped local - those keep whatever they already
read as, and the line goes on being counted as code. That is the honest answer: a guessed
class would name the wrong method and describe it with somebody else's words.

**Curated always outranks derived**, and it upgrades in place. Where a recogniser claims the
line, its polished sentence wins exactly as before; and the day a curated table lands for a
shape your project writes, those rows read the better way the next time the file is opened,
with the file itself untouched. Same bytes, better words.

The same reading drives the picker. Under **Methods in this project** you get one entry per
method your own scripts declare, filed under the object it belongs to, with the target, the
method name and the arguments already answered from the declaration - and the author's `##`
line as its description.

<img src="images/derived-methods-shelf.png" alt="The Add Action picker searched for take damage: a Methods in this project section holding a Hero - player.gd shelf with one entry, Take damage, described as amount - Takes a hit, and dies once the bar empties." width="620">

### Every property too

The other half of what an object offers reads the same way, and the shape it reads in is the
one you already know: **object, property, value** - the Inspector's own three columns, in the
Inspector's own order, with nothing to learn.

- **A write is a Set row.** `torch.shadow_filter_smooth = 0.5` reads *torch ▸ Set
  shadow\_filter\_smooth to 0.5*, with `Light2D` muted beside the object.
- **A comparison is a question in the left lane.** `torch.shadow_filter_smooth > 1.0` reads
  *torch ▸ shadow\_filter\_smooth > 1* - the same compared-variable rendering a sheet variable
  already gets, on an object's own property.
- **A read answers where it stands.** A value that is itself a property of something the sheet
  can name is drawn in the same plainer style the property on the left wears, and its own
  description rides on the row beside the one being written.

<img src="images/derived-property-rows.png" alt="One event of four lines of GDScript - an if on torch.shadow_filter_smooth, then writes to torch.energy, torch.shadow_filter_smooth and torch.shadow_color - shown above the same event as a sheet reads it: the condition torch Light2D shadow_filter_smooth greater than 1, then three actions, the first reading torch Set brightness to 1.2 with no class beside it and the other two reading torch Light2D Set shadow_filter_smooth to 0.5 and torch Light2D Set shadow_color to color." width="620">

**Curated word maps still outrank the raw property name**, exactly as curated verbs outrank
derived calls. In the figure above, `torch.energy = 1.2` reads *Set brightness to 1.2* - words
somebody wrote, so no class is shown beside them - while the two rows under it are read off
`Light2D` on the spot. The day a word map lands for a property that reads the plainer way
today, those rows read the polished way the next time the file is opened, with the file
untouched.

**And the same three refusals.** A receiver whose class nothing can name, a property the class
does not have, and a bare `hp = 5` with no receiver written down at all: none of them is
guessed at. Each keeps the plainer view it already had, and goes on being counted as code.

Hovering a derived property row shows its description - Godot's class reference for a built-in
property, with the credit its licence asks for, or the `##` lines above the `var` in your own
script (an `@export` annotation between the two does not break the block). `F1` on a built-in
property opens its page in the Manual.

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

**The method field reads the target's own script.** Once the row says which object it is aimed at,
the **Method** field offers that object's methods rather than a blank line: everything its script
declares, with the arguments as written and the `##` comment above the declaration as the
explanation, then what its engine class adds, named with the class it came from. Your programmers'
doc comments become the designer's tooltips, in the file where they already live. Aim the row at a
different object and it is a different list - a node of the open scene, an Autoload, a class the
project declares.

The field stays **editable**, which is the point: a name reflection cannot see is still typeable, and
a row whose target is worked out at run time keeps the free-text field it always had. A name the
target does not have goes **amber** with the nearest one offered - a warning, not a refusal, because
the method may be reached some other way. That is what stops a rename somewhere else rotting a typed
string silently until the game runs.

**Connect Signal reads the same way.** Once the row names a source, its **Signal** dropdown lists
that object's signals - what its script declares, then what its class emits - rather than this
sheet's own. A row with no source still offers the sheet's, exactly as before.

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

- **Add event ▸ Signals in this project** - the shelf that needs no typing and no scene dock. Every
  signal your OWN scripts declare is listed under the object that emits it: one folder per scripted
  node of the open scene, one per Autoload, each signal with its parameters and its `##` line as the
  description. Pick one and the event lands wired - the signal name, the argument signature and the
  emitter are all answered, and the connection is written in `_ready` exactly as a lifted trigger's
  is. (Declared signals only. What a Button or a Timer emits is already browsable under its own
  class; what no picker had was the `leveled_up(new_level)` somebody wrote in 2022.)
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

<img src="images/interop-opened-gd.png" alt="A hand-written GDScript file opened as an event sheet: the head's band stack, an Expression verb named Parse with a source parameter and a gives back Dictionary badge, then condition and action rows including a For each raw_line loop with nested sub-events." width="720">

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

**And if your code does not look like a style guide, try it again too.** Two shapes that are ordinary
GDScript used to stop a file dead, and both open now:

- `func hurt(amount):` - a head with **no return annotation**, which is what most people write before
  they meet the style guide. Measured over six beginner-shaped scripts the wall was total: 15 of 15
  functions stayed code. All 15 open as functions now. The head is remembered as it was written, so
  saving the file writes `func hurt(amount):` back - the plugin does not correct your signature.
- `button.pressed.connect(func(): start_game())` - a handler written as a **lambda in the connect
  call**. A lambda at the top of `_ready` becomes the trigger event it is, with its body as the rows
  under it. The receiver spelling, your spacing and the one-line-versus-block shape are all kept, so
  the statement is written back exactly as you typed it. One written further down `_ready`, where the
  statement could not come back where it was, stays a statement and reads as it always did.

### Marking a script to stay code

Not everything wants to be rows, and a plugin that insists is a bad neighbour. Put this comment line
anywhere in a script and this plugin leaves it alone:

```gdscript
# eventsheets: stays code
```

That file is then opened read-only as code with its syntax colours, never lifted, never offered a
behaviour, and never counted in the adoption table below. The mark is a **comment**, deliberately: it
survives the plugin being uninstalled, it reads as what it is to anybody who opens the file in any
editor, and it costs the running game nothing. The physics wizard's 800-line solver deserves peace.

### Doctor › Interop: where to start, and who calls what

The Doctor's **Interop** section is the adoption dashboard for a project you already had. It says how
many scripts the project owns, how much of what it measured reads as rows, and lists the best next
candidates first - which are usually a small input or UI script that reads 100%. Each line says what
its number is made of (how many functions opened, how many are still code) and how many other scripts
call something that file declares. Marked files are listed separately, as left alone.

The score gates nothing. A project at 12% works exactly as well as one at 90%; the number is there so
a team can watch the seam move at their own speed, not so anybody chases it. And installing the plugin
changes nothing by itself - no autoloads, no rewritten files, no hooked scenes. A script is code until
you open it as a sheet.

The same "who calls what" answer appears where it is most useful: on a function's own head, as
`called by combat.gd · boss_ai.gd`, and in **Rename everywhere**, which renames inside sheets and then
LISTS the hand-written scripts that call the old name. It renames nothing outside a sheet, on purpose -
your code is not the plugin's to rewrite. Both are matched by name, so treat the list as files to
check: one of them may be calling a different function that happens to share the name.

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
- **The head is the file's own first lines, then one Include bar for what they do not say.** An
  opened pack wears the same band stack an authored sheet does - `class_name FPSController`,
  `extends Node`, `@icon(...)`, the `##` description, the host binding - one band per line, each
  echoing the line it stands for. Under them the Include bar carries only what no line of the file
  says: `⇥ Addon Pack  v1.0.0  behaves on a  CharacterBody3D  reads as events ▸`. Then a
  `Triggers this pack fires - 11` folder, one folder per `@export_group` (`Jump - 3 settings`,
  `Movement - 3 settings`, ...), and `Instance variables  of FPSController` for everything the groups
  did not claim. Inside a folder a variable reads `Instance number  jump_velocity = 4.5  Upward
  velocity applied on a jump` - the one sentence below, plus the knob's own description. Nothing on
  the head is stated twice: the name is on its band, not on the bar, and the description is the `##`
  band rather than a second comment row.

  ![A behaviour pack's head: the band stack naming the class, what it extends, its icon, its description and its host, then the Include bar reading "Addon Pack v1.0.0 behaves on a CharacterBody3D", then folded Triggers, Input and one folder per setting group](images/opened-pack-head.png)

  ![The same head with its folders opened: every setting under Movement, Wall Tech and Instance variables of FPSController, each reading scope word, type word, name, value and its own description](images/opened-pack-head-open.png)
- **An autoload opens as the project's Globals sheet.** When the file IS a registered autoload, its
  head grows an `autoload  Game` band echoing the `project.godot` entry that grants the name, its
  knobs read as one `Global variables` folder rather than the Instance variables one, and its
  triggers say `this global fires - N`. The Object bar names it the same way.
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

![Six variable rows in the one sentence, each washed lilac with an x badge and its own declaration echoed at the right edge: Instance whole number hp = 100 beside var hp: int = 100, a labelled Movement folder strip holding Instance number speed = 200 with a sliders mark beside @export var speed: float = 200.0 and jump_force under it, then Instance boolean alive = true, Constant whole number MAX_HP = 100 beside const MAX_HP: int = 100, Static whole number spawned = 0 reading shared by every Player, and inside event 1 a Local number dealt = 0](images/variable-sentence-head.png)

- **Every variable reads as one sentence - `<scope> <type> <name> = <value>`.** The scope word leads:
  `Instance number speed = 200`, `Instance boolean alive = true`, `Constant number MAX_HP = 100`,
  `Static number spawned = 0` (which adds `shared by every Player`), `Local text name = ""` inside an
  event, `Global number Score = 0` on an autoload and `Field number price = 0` on a Resource script.
  The type is in plain words - number, whole number, text, boolean, vector, color, `list of text`,
  table, object or the class the author named, scene, any - with Godot's own spelling (`float`, `int`,
  `String`, `Array[String]`, `Dictionary`) one hover away. A declared `int` reads "whole number"
  because the author said they wanted no fractions; an undeclared `100` still reads "number". Variables
  a designer can edit wear a small **sliders mark** beside the name (hover: "Editable in the
  Inspector"), and the head gathers them all in one **Instance variables** folder with those first,
  rather than a Settings / Internal state split. Scope and type are WORDS on the row, never pills:
  the only boxes a variable row wears are its `x` kind badge and that sliders mark.
- **A `static var` says who shares it.** `static var spawned: int = 0` reads
  `Static number  spawned = 0  shared by every Player` - the scope word leads the type chip, and the
  muted tail names the object the value belongs to (the script's `class_name`, else its scene root,
  else its file). One value on the class, not one per object, is exactly the thing a reader has to be
  told, and it is the scope word that tells it - `const` and `static` fold INTO that word rather
  than riding beside it as separate pills.

- **The declaration echoes at the right edge.** Beside every variable row, muted, sits the exact line
  the compiler emits for it - `@export var speed: float = 200.0`, `const MAX_HP := 100`,
  `static var spawned := 0`, and `Game.Score` for a global read here. It is the emitter's own string,
  so it can never drift from the file, and it is coloured with the script editor's token colours read
  from your Editor Settings, so it matches whatever GDScript theme you use. It comes up to full
  strength on the row under the pointer, steps aside on a narrow canvas, and opens the code panel at
  that line when you activate it. **View ▸ Variable rows** dials how much is drawn: **sentence** (the
  beginner reading), **both** (the default) or **code** (the row IS the line, still washed, still
  badged, still one undo funnel). Simple Mode keeps it on **sentence**.

- **Variable rows are rows of their own kind, in the order you wrote them.** A flat lilac wash and a
  2px rule down the left edge say "this is a declaration" before a word is read; the order is the
  file's, not the alphabet's. Drag one past another and the drop writes the new order; **Sort A-Z**
  on the row's menu writes alphabetical when you ask for it. Variables never fold as a block - the
  only fold in the list is a folder you made yourself, an **Inspector group**, which draws as a slim
  labelled strip over its rows with the rows themselves left exactly where they were (a bracket
  around rows must never push them sideways).
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

#### The hierarchy - who gained the child, and what happened to its place

- **The hierarchy reads as the two words it has always had.** `item.reparent($Hand)` reads `Hand ▸
  Add child item` with *keeping its place* said quietly beside it, because who gained the child and
  what happened to its place are the two things a reader wants. `reparent(p, false)` says *snapping
  to it*; a reparent onto the layout root reads `Remove from parent`; and the two-line
  `get_parent().remove_child(x)` + `p.add_child(x)` spelling is the same ONE row, with both lines on
  the hover. A reparent with a RemoteTransform and a `top_level` beneath it folds into one Add child
  row wearing the follow-flags the plumbing actually set. `for c in x.get_children():` reads `For
  each c in x's children`, `x.get_child_count()` is `x.ChildCount`, and `top_level = true` is `Set
  ignore parent's movement on` rather than a property name from Godot's docs.

  ![Functions read as an event sheet, each row a hierarchy sentence: Hand gains a child keeping its place, an item is removed from its parent, a remove-then-add pair reads as one row snapping to it, and an Add child row wears its follow-flag chips](images/hierarchy-reading.png)

  ![Three opened scripts stacked: one whose Include bar says "73% reads as events - 2 script blocks", one whose settings read as Movement and Look folders with every export hint family, and the same file opened as an autoload, whose head is one Global variables folder](images/opened-script-head5.png)

**The Hierarchy pane** answers the same questions without opening a row. Click an object's name in
any row and **Object properties** now carries a Hierarchy section: its **parent** (click to jump to
that object) and its **children**, each with what it carries - its type, how many children of its
own it has, a broken link when it ignores its parent's movement, and the three transform ticks when
it follows some of them and not others. A child the scene file owns shows muted with *in the scene
file* and offers **edit the scene**, which hands the node to Godot's Scene dock: the pane writes
runtime rows and never edits a `.tscn`. Drag an object in from the Object bar to make it a child
(the four flags open on the drop), drag a child out onto the canvas to unparent it, or right-click
one for **flags…**, **Remove from parent** and **Select in scene**. Every gesture writes ordinary
rows through the undo funnel, in the same spellings a hand-typed file uses, so the pane and the
canvas can never disagree about the tree and Ctrl+Z takes a parenting back like any other edit.

The row itself offers the ticks too. An Add child row that was written with flags wears them - `
transform position ✓ transform angle ✓ transform size ✗ destroy with parent ✓` - and ends with a
**flags…** chip. One click reopens exactly those ticks, and confirming rewrites the run the chip
sits on rather than adding a second set beside it, so ticking twice leaves one RemoteTransform and
one `top_level`, never two. What comes back out reads as the same flagged row, which is the promise
that lets a reader treat the chips as the truth rather than as a summary.

![Three opened functions read as rows: On Wire Up setting open sheet to an f Open Sheet In Workspace chip, On Equip reading Add child hat keeping its place with a flags... chip and the four transform ticks beside it, and On Ask Keep Every Tick whose Local ConfirmationDialog row carries the four lines that shape the dialog underneath it](images/reading-dialog-hierarchy-and-function-chips.png)

![The Hierarchy section of Object properties for Player: parent Level (the layout), four children, two of them muted as in the scene file with an edit the scene link, a HealthBar marked as ignoring its parent's movement, and a Hat whose transform ticks say position and angle but not size](images/hierarchy-pane.png)

Three hierarchy footguns are Doctor notes rather than rules - each advisory, each with a one-click
chip naming the single edit to make. A walk over a node's children that **moves** one of them while
it walks (Godot's child list is live, so the loop silently skips the next child - walk a copy, or
use the For Each Child row, which snapshots for you). A **reparent of self inside start of layout**,
which Godot refuses outright because the old parent is still adding its children. And a variable
**keeping hold of a child whose parent this file frees** - a child goes when its parent goes, so the
next line that touches it crashes. The `demo/showcase/hierarchy_playground/` room has one of every
move in it: mounting a rider onto a saddle and dismounting again, a hat that follows position and
angle but not size, a health bar that stays a child and stops following so it never tilts, one walk
that heals every soldier among a leader's children, and a camera that orbits because its parent
pivot turns.

![The Hierarchy Playground showcase running: the rider mounted on the horse wearing a hat and an upright health bar, a squad of four soldiers, two settled crates, and a status line reading rider's parent, hat follows size no, bar ignores movement yes, squad hp 200, crates settled yes](images/hierarchy-playground.png)

#### The cursor's ray, and how far things are on the canvas

- **The camera-ray run is one question, and the canvas has its own words.** `project_ray_origin`,
  `project_ray_normal`, the query and `intersect_ray` are four lines that only mean anything
  together, so they read as ONE row: `System ▸ Set hit to the object under the cursor`, with how far
  it reaches and the branch that clears what it found said quietly beside it -
  `reach 1000 · none when nothing is hit`. Aimed through a crosshair object rather than the OS
  pointer the same run reads `the object under crosshair`, and a mask says which layers it may see,
  in the project's own layer names. A hit's own entries read as what they mean: `hit.position` is
  **where the cursor touches the world**, `hit.normal` **the surface's facing there**,
  `hit.collider` **the object under the cursor**. Beside them, canvas space:
  `cam.unproject_position(p)`, `o.get_global_transform_with_canvas().origin` and
  `get_screen_transform() * p` all read as **x's position on the canvas** (camera zoom and canvas
  layers included, which is exactly what plain position arithmetic gets wrong),
  `get_visible_rect().size / 2` is **the canvas centre**, and a distance between two canvas points
  is **the canvas distance from A to B (pixels)** - named apart from world distance on purpose,
  because an aim assist measured in world units ignores zoom.

  ![An opened 3D script read as an event sheet: the four-line camera-ray run as one row saying "Set hit to the object under the cursor, reach 1000, none when nothing is hit", the same run aimed through a crosshair with its layer mask, and an aim-assist walk whose locals read as the canvas centre, a position on the canvas and a canvas distance in pixels](images/reading-cursor-ray-and-canvas.png)

- **A flat game asks the same two questions, and has words for them too.** There is no camera ray to
  cast in 2D, so "what is under the cursor" is a POINT query and "which square is under the cursor"
  is a map lookup - and both are in the picker. `Mouse ▸ Object Under Cursor (2D)` reads **the object
  under the cursor** and answers with whichever body or area the pointer is over, or nothing over
  empty space; the layers it may see are named by the names this project gave them, so a pick that
  should ignore scenery says so in words. `Mouse ▸ Tile Under Cursor` reads **the tile under the
  cursor** and answers in map coordinates - the very number `Set Tile At`, `Erase Tile At` and `Cell
  Is Empty` take, so tile painting is two rows. Both write a small helper function into the file the
  first time they are used, one per question however many rows ask it, appended after everything
  else so no line of yours moves.

#### The 3D words - moving, orbiting, animating, and the world's look

- **Third-person locomotion is one action.** The five-line run every 3D character script writes -
  fetch the camera's basis, mix it with the two numbers of input, flatten the result onto the ground,
  make it one unit long, write it into the velocity - reads as a single row: `Player ▸ Move relative
  to the camera along input at speed (flattened to the ground)`, with a `→5` mark saying how many
  lines it stands for and every one of them one hover away. Under it, `velocity.y -= 30.0 * delta`
  reads `Fall at 30 (gravity)` rather than as arithmetic on a member, and `is_on_floor()` reads as
  the question the sheet already publishes. Nothing about the file changes: it saves back byte for
  byte, and double-click still opens the exact GDScript.

  ![A third-person controller opened as an event sheet: the five-line camera-basis run collapsed into one Move relative to the camera row with a 4-line mark, the gravity line reading Fall at 30, and move_and_slide reading Move and slide along what it hits](images/reading-camera-relative-movement.png)
- **Orbiting reads as orbiting, in both spellings.** `global_position = moon.global_position +
  Vector3(cos(angle), 0, sin(angle)) * radius` reads `Orbit moon at radius radius angle angle (on the
  ground plane)` - the plane named after the axis the circle is drawn flat against. A `rotate_y` on a
  node the SCENE says holds nothing but a camera or a camera arm reads `Orbit around its centre by
  ... (yaw)`, because turning that node is the camera going round what it looks at; a `rotate_y` on
  an ordinary node is still a turn. A `SpringArm3D`'s length reads `Set camera distance`. Both orbit
  shapes offer the Orbit 3D behavior, which does the whole thing.

  ![An orbiting script opened as an event sheet: the cos/sin placement reading Orbit moon at radius radius angle angle on the ground plane, and the camera arm's length reading Set camera distance to 6](images/reading-orbit-words.png)
- **A blend tree's magic strings read as animation words.** `anim_tree.set("parameters/Locomotion/
  blend_position", pace)` reads `Player ▸ Animation ▸ Set Locomotion blend to pace` - named after the
  GROUP the parameter belongs to, not the leaf Godot spells it with. `.../TimeScale/scale` reads `Set
  animation speed`, `.../Shoot/request` reads `Play one-shot animation Shoot`, and the state machine's
  own two calls read `Go to state "Jump"` and `Current state is "Land"` - the words the State Machine
  behavior already publishes. An AnimationTree is not an object anybody points at, it is HOW one
  object animates, so every row wears the object's own name and its Animation aspect.

  ![A blend-tree script opened as an event sheet: four parameter writes reading as Set Locomotion blend, Go to state, Set animation speed and Play one-shot animation, all under the object's Animation aspect](images/reading-animation-tree-words.png)
- **Seen, heard, and the world's look.** A 3D sound's `max_distance` and `unit_size` read as its
  hearing distance and falloff; a mesh's `visibility_range_begin` and `_end` written together read as
  one `Visible from 10 to 90` row; `transparency` reads `Set see-through to 40%` and `cast_shadow`
  off reads `Set shadows off`. A `VisibleOnScreenNotifier`'s two signals read as the triggers `On
  entered view` and `On left view`. And the Environment - however the file reached it - is the
  **Environment** object, with fog, glow, ambient light, ambient occlusion and the sky rotation as
  plain Set rows under it. `RenderingServer.global_shader_parameter_set(...)` reads `Set effect
  parameter wind strength to 2 (everywhere)`.

  ![A 3D scene script opened as an event sheet: the audio distances, a mesh's visible range as one row, see-through and shadows, and a whole fog-and-glow block reading under the Environment object](images/reading-seen-heard-and-the-world.png)
- **UI that lives in the world.** `billboard` reads `Set always face the camera on` (and the upright
  variant says so), `no_depth_test` reads `Set show through walls on`, `pixel_size` reads `Set world
  size ... (per pixel)`, a sprite's region width reads `Set bar width` - the health bar over a head -
  and a SubViewport painting UI onto a surface reads `Send input ... (UI on a surface)`, with
  `render_target_update_mode` reading `Set redraw only when seen`. All three of the property names are
  gated on the CLASS, so `transparency` and `pixel_size` on anything else stay the property writes
  they are.

  ![A name tag and a health bar over a head opened as an event sheet: billboard, show through walls, world size, the bar's width and the in-world screen's redraw mode all reading as plain rows](images/reading-world-space-ui.png)
#### Locals and accessors - how far a name reaches, and a setter as a trigger

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
- **A property that NAMES its accessors is a property too.** Godot's other spelling for a guarded
  value puts the functions beside the declaration instead of the body under it:

  ```gdscript
  var health: int = 100:
  	set = _set_health,
  	get = _get_health
  ```

  That reads as the variable row it is, with an **On health set ▸ `_set_health`** sub-row under it
  saying which function runs and when, and an **ƒ health  expression ▸ `_get_health`** sub-row for the
  one that gives the value back - the same two kinds of row the inline spelling reads as, because a
  `set` is an event and a `get` is an expression whichever way the file writes them. The named
  functions go on reading as the functions they are,
  where they were written, rather than being copied under the declaration twice. Before, those two
  lines were not statements, so nothing could lift them and they took the declaration above them into
  a verbatim block. Every shape the emitter would not write back the same way - the other order, a
  trailing comma with nothing after it, a name that is not one name - still stays the verbatim block
  it was, and the bytes are untouched either way.

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

- **The engine's notifications read by name, not by their constant.** A `_notification(what)` with a
  `match what:` in it is how Godot hands a node the news it sends through one callback instead of
  through a signal, and four of those cases are things a game really reacts to: `NOTIFICATION_PAUSED`
  reads **On paused**, `NOTIFICATION_UNPAUSED` reads **On unpaused**,
  `NOTIFICATION_WM_CLOSE_REQUEST` reads **On close** (the player pressing the window's X, which is
  where a "save first?" prompt goes) and `NOTIFICATION_PREDELETE` reads **On object freed**. All four
  are pickable rows as well, filed under **Notifications**, and every one of them compiles back into
  the same `match what:` block the file already had. **On object freed is not On destroyed**: a node
  leaving the tree can happen more than once, this happens exactly once and nothing follows it, so
  the two moments do not share a sentence.
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
- **A table or a list written across several lines is one row, and its entries are chips.** A
  `{ ... }` or `[ ... ]` handed to `return`, to a signal, to `append`, to any call, or to a `var`
  reads as ONE row: the statement's own sentence, the word **table** or **list** where the literal
  sat, and each entry as a named chip - `span index = selected span index`, `mode = "replace"`. A
  long one shows the first three and says how many are left, with the whole literal on hover; a
  nested table nests inside its chip; and the bare `}` / `})` / `],` line that used to be a row of
  its own is gone. Double-clicking a chip edits that entry in place and rewrites the one line it
  came from. The file keeps every line it had.

  ![Three rows reading a multi-line table: Functions On Selection Snapshot with System - Return, the word table and chips reading row index = row index and span index = span index; Functions On Request Replace with System - Push back, table, mode = "replace", path = path, to edits; and Functions On Column Widths declaring a list](images/literal-entry-chips.png)
- **A function handed around as a value reads as a function.** A bare function name assigned or
  passed reads as the **ƒ** chip the condition lane already names functions with, and so does
  `Callable(self, "on_done")`. A `Callable` variable reads **Local function**; `on_done.call(result)`
  reads `Call on done   result`; `on_done.is_valid()` reads `on done is set`; `call_deferred("f")`
  reads `Call F (at end of frame)`; and a one-line `map` / `filter` lambda reads in the Array rows'
  own words - `rows each one's name`, `rows those where ready`. The chip is a link: clicking it goes
to the function it names, the same jump the Outline panel makes.

  ![Rows reading functions as values: menu - Set open sheet to f Open Sheet In Workspace, System - Call Refresh after edit (at end of frame), a condition reading on done is set with System - Call on done result, and two Local value rows reading rows each one's name and rows those where ready](images/functions-as-values.png)
- **A typed receiver is named by what it IS.** When the file declared a receiver's class, the object
  column says that class in words with the plugin prefix dropped - a `var registry:
  EventSheetACERegistry` reads **ACE registry**, a `var find_bar: EventSheetFindBar` reads **Find
  bar** - with the variable's own name muted beside it. The variable name says which one; the class
  says what it is, and for someone reading a plugin the second is the half they need first. Turn
  Familiar Words off and the class reads exactly as the file declares it.

  ![An Instance variables block declaring registry and find_bar, and below it a Functions On Refresh row whose object column reads ACE registry with the muted variable name beside it](images/typed-object-labels.png)
- **A plain script is an object.** Its name band names it (`class_name`, else the file) with its
  class icon, and its Include bar adds the fact no line of the file carries - the root node of the
  scene that runs it, when the script declares no class of its own; its engine properties read under
  that name (`Player ▸ Set X to 100`, `Player ▸ rotation > 1.5`), never as `self`; global functions read as
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
- **A loop, a drop and a test say what they are for.** `for i in n:` whose body gives each step its
  share of a full turn reads `For i from 0 to n - 1 - evenly around a circle`, so the ring is on the
  head instead of three lines of trigonometry below it; the same count with an ordinary body keeps
  the words it always had. A ray straight down, the cast, the `if not hit.is_empty():` guard and the
  hit taken back are claimed together as the Placement pattern, with all four lines on the hover. And
  a file under `tests/` whose entry point is `static func run() -> bool` folds its `var passed := true`
  and its `_check` helper into the head, because the Check rows are the verdict and the bar already
  counts them - the same lines in a game script keep every row.

  ![Three opened scripts: a ring loop whose head reads For i from 0 to n minus 1 evenly around a circle beside an ordinary count that does not, a drop-to-the-ground run wearing its pattern chips, and a test sheet whose head says test sheet with 2 checks and whose verdict local and check helper have folded away](images/reading-ring-and-test-fold.png)
- **Numbers read the way a person writes them.** `300.0` reads `300`, `0.50` reads `0.5`,
  `1_000_000` reads `1,000,000`, `1e3` reads `1000`, and the constants a reader recognises are named
  (`1.5707963` reads `π/2`; `τ`, `√2` and `√3` likewise, from a spelling long enough to mean them -
  `3.14` stays `3.14`). A 0..1 setting the project marked `@export_range(0, 1)` reads as a
  percentage (`Set opacity to 50%`). A reading only: the literal in the file never moves, and the
  params dialog still puts the author's own GDScript in front of you.
- **Ranges, angles, distances, areas and "about" are ONE condition each.** `x >= 0 and x <= width`,
  `0 < hp and hp < max_hp`, `level in range(3, 6)` and the inverted `not (t >= 0.2 and t <= 0.8)` all
  read as one `is between` row - the `not` mark carrying the inversion - and a strict end says which one it is
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
  reads `Solid ▸ On layer Enemies (layer 2)` and `collision_layer = 5` reads `Set collision
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
  `Is playing`. `grab_focus()` is `Set focus`, `popup_centered()` is `Open centered`, and
  `AudioServer.set_bus_volume_db(0, linear_to_db(v))` is `Audio ▸ Set master volume to v (0 to 1)`.
  Finally the game-feel snippets: a symmetric random camera offset is `Shake by s`, `base_y + sin(t *
  3.0) * 8.0` is `Bob y` with `sine · magnitude 8 · 3 per second` as its note, and
  `scale.lerp(Vector2.ONE, 10 * delta)` is `Ease size back to normal at 10`. Every one of these is
  claimed only at its exact shape - a lopsided shake or a lerp to some other size keeps the property
  write it is - and every one names the pattern it read as, which is what the event's pattern chip
  and the Manual show.

- **A spawn keeps your own name for the copy.** `var b = Bullet.instantiate()` is a row, the
  `add_child(b)` beside it is the Add Child row, and `b.global_position = muzzle.global_position` is
  the property row - three rows in one event, with `b` kept exactly as you spelled it, because that
  identifier is what the file says and every row after it in that event simply says it too.
  `call_deferred("add_child", b)` reads as the deferred add it is, so a spawn out of a collision
  handler still says on the row that the parenting waits for the physics step. `add_to_group("enemies",
  true)` reads as the crowd the copy joins and `get_tree().get_node_count_in_group("enemies")` as how
  many are alive, so a hand-written spawner opens with its cap and its count already in the sheet's
  words. None of these readings needs a spawn row to have written the line: the head's **spawns**
  band is read off the emitted line rather than off a row's name, so an opened `.gd` grows the same
  band a picked row would have.

- **The two removal chains people write by hand are one row each.**
  `get_tree().create_timer(2.0).timeout.connect(queue_free)` reads `Destroy After Seconds`, in both
  spellings - the bare one on a node removing itself, and `connect($Enemy.queue_free)` on a node
  removing another. `$Ghost.create_tween().tween_property($Ghost, "modulate:a", 0.0,
  0.5).finished.connect($Ghost.queue_free)` reads `Fade Out Then Destroy`, and only when all three
  mentions name the same object: a tween started on one node that fades a second and frees a third is
  somebody else's line and keeps the reading it had. A fade whose object is left implicit stays the
  plain statement it was, because the row could not reproduce that spelling byte for byte. `0` and
  `0.0` are both matched as the fade's target and each saves back as itself.

- **A guard you wrote by hand stays your guard.** `if is_instance_valid(boss): boss.queue_free()`
  opens as a Destroy Now row inside the question you asked, and saves back byte for byte - the
  compiler writes nothing extra, because the sheet has already asked. That is the same rule read from
  the other side: a removal whose object is a variable typed as a node compiles inside
  `is_instance_valid`, and the row echoes the exact line the file holds at its right edge. `self`,
  node paths and a copy a spawn row named in another event are never guarded, and no row outside the
  three removal rows is touched.

  ![A sprite, UI, sound and game-feel script opened as a sheet](images/reading-sprite-sound-juice.png)

- **A Control built in code reads as the thing it builds, and a hand-painted canvas in the Drawing
  words.** `ConfirmationDialog.new()` is `a new Confirm dialog`, and so are the Accept dialog, the
  Window, the Button, the Check box, the Text input, the List, the Tabs, the Tree, the File chooser,
  the Colour picker and the Popup menu. `popup()` is `Open`, `popup_centered()` is `Open centered`,
  and `hide()` on a window is `Close` rather than a visibility flag. The plugin's own popup builders
  read as the verbs they publish, filed under the thing they add to: `dialog ▸ Add titled card
  "Last condition removed"`, `card ▸ Add section "Fields"`, `card ▸ Add form row "Event" label`.
  On the canvas side, `draw_line` with a thickness, `draw_rect` and `draw_circle` with a fill flag
  (`(outline)` when it is off), a `draw_rect` whose `Rect2(corner, size)` is written inline, and
  `draw_string` with its size and colour all read with every argument said out loud, and
  `draw_texture` / `draw_polyline` / `draw_arc` are `Draw image` / `Draw line along` / `Draw ring`.
  `accept_event()` is `Consume input`, `get_theme_color("row_color", "EventSheet")` is
  `Theme.Colour("row_color")`, and `add_theme_stylebox_override("normal", box)` is `Set style
  "normal" to box`. A Control's own `_gui_input` is an input handler like `_unhandled_input`, so its
  branches read as the Mouse and Keyboard triggers, scoped to the object the input landed on.
  The lines that SHAPE a Control the event just made - the property writes, the `add_child` that
  puts it in the tree, the `popup_centered` that opens it - hang under the Local row that made it
  instead of standing as their own top-level steps, so forty dialogs in a dock file read as forty
  dialogs rather than four hundred rows. A wired-up signal is the one thing not folded in: it keeps
  the trigger row the sheet already gives it, with the call it makes underneath.

  ![A tool's dialog-building and canvas-painting code opened as a sheet](images/opened-script-canvas-dialog.png)

- **Vectors read as the words a reader has for each operation.** `(target.position -
  position).normalized()` is the one thing every chase line means, so it reads `the direction from
  Player to target`; a bare `dir.normalized()` is `unit vector of dir`. `velocity.length()` is `the
  speed` - any other length keeps `length of x`, which is the honest answer for a piece of text as
  much as for a vector. `facing.dot(dir)` reads `how much facing points along dir (-1 to 1)`, because
  the number is useless without the range it lives in. `dir.rotated(PI / 2)` reads `dir turned 90°`,
  and so do the `TAU / 4`, `deg_to_rad(45)` and negative spellings of the same fixed turn; a turn by
  something with a name in it (`PI / sides`) is not a number the row can show, so it keeps its code.
  `angle_to` and the `UP` / `DOWN` / `ZERO` / `ONE` constants already read as words.

- **Colours read as colours.** `Color.RED.darkened(0.2)` is `red, 20% darker` and `lightened` is its
  twin; `Color(1, 0, 0, 0.5)` is `red at 50% opacity`; `Color.from_hsv(0.3, 1, 1)` is `colour from
  hue 30%, full saturation`, with the brightness shown only when it is not full. A mix nobody has a
  word for keeps its channels rather than being given a name it does not have. The swatch beside the
  value is unchanged: it reads the value the row holds, not the words drawn next to it, so clicking
  it still opens the picker on the real colour. And `modulate = modulate.lerp(Color.WHITE, 5 *
  delta)` is one verb - `Ease colour toward white at 5` - claimed only when the line reads the very
  member it writes, so an ordinary blend from somewhere else stays the Set it is.

- **A shader dial reads as the dial it turns, when the project can prove which one it is.**
  `material.set_shader_parameter(&"dissolve", 0.7)` reads `Set effect.dissolve to 0.7`, the `effect.`
  lead muted the way an autoload's name is muted on a global's row. The one-line
  `create_tween().tween_method(func(v): material.set_shader_parameter(&"dissolve", v), 0.0, 1.0, 0.8)`
  reads `Fade effect.dissolve`, keeping your own lambda argument's name; `material =
  material.duplicate()` reads `Make the effect this node's own`; `material =
  preload("res://effects/frozen.tres")` reads `Set effect`. The receiver rides along exactly as you
  wrote it - nothing, `$Sprite`, `%Aura`, `get_node("Aura")`, or the variable you were holding the
  node in - and so does the way you quoted the name, so a `&"dissolve"` stays a StringName and an
  `"amount"` stays a plain string. The claim is gated on the project twice: the attached scene has to
  say that node wears a material, AND that material's `.gdshader` has to declare that name. A node
  wearing nothing, or a name no shader has heard of, falls through to the free-string **Set Effect
  Parameter** row that shipped before this - which claims nothing about any shader, and is the honest
  reading of a name nothing can check. The Doctor is what tells you which of the two you have.

- **A guard-first touch handler reads as the filtered trigger it is.** The commonest shape in any
  collision script is a `body_entered` handler whose first statement leaves for anything outside one
  group, and it opens as **On collision with `<Group>`** - or as **On overlap with `<Group>`** when
  the emitting node is an Area, which is the same signal read from the side that only notices rather
  than blocks. The whole handler is the event: the guard is the row's **With** field, and everything
  after it is the rows underneath.

  ```gdscript
  func _on_body_entered(body: Node) -> void:
  	if not body.is_in_group("enemies"):
  		return
  	print(body.name)
  ```

  Both spellings are claimed - the two-line one above and the `if not …: return` one people write in
  a hurry - and each hands back the bytes it matched, so re-emission writes your own spacing, your
  own `&"name"` if that is how you quoted it, and your own argument name. The GROUP is the only thing
  the row stores. A guard that asks for MORE than the group (`if not body.is_in_group("enemies") or
  dead:`) is deliberately not claimed, because a row that dropped the rest of the question would not
  write the file back. `body_exited` reads the same way, as the *stopped colliding* / *overlap ended*
  half.

  Both hand-written spellings of the standing question open as **is touching `<Group>`** as well:
  `get_overlapping_bodies().any(func(b: Node) -> bool: return b.is_in_group("enemies"))` asks the
  area and filters, `get_tree().get_nodes_in_group("enemies").any(overlaps_body)` asks the group and
  filters by overlap, and both are the same question from the two ends. The lambda's parameter name
  is your spelling, not a value the row shows, which is what makes it ride back out untouched.

- **The was-on-floor pattern reads as On landed.** Every platformer already contains the three parts
  of a landing check - a variable remembering last step's footing, an `if` comparing this step
  against it, and a line bringing the memory up to date - and the middle part is the one whose
  meaning is not in its own spelling:

  ```gdscript
  var was_on_floor: bool = false


  func _physics_process(delta: float) -> void:
  	if is_on_floor() and not was_on_floor:
  		land()
  	was_on_floor = is_on_floor()
  ```

  `is_on_floor() and not was_on_floor` would otherwise split into two rows that separately mean
  nothing ("is on the floor" AND "not some variable"), so it is claimed whole and reads **just
  landed**, under an event that reads **On landed**. The declaration and the update line are ordinary
  rows already. Both orders of the two halves are claimed, and so is the two-variable form where this
  step's footing went into a local first (`on_floor and not was_on_floor`) - there the claim rests on
  the two NAMES, one reading as footing now and one as footing before, so `grounded_last_frame`,
  `was_grounded` and `_was_on_floor` all read. **The name of your memory is not a value the row
  shows**, which is precisely what makes it come back exactly as it went in. `was_on_floor and not
  is_on_floor()` is the departure, **just left the ground**. An `if` that asks for more than the edge
  (`is_on_floor() and not was_on_floor and hp > 0`) is left to the general reading.

- **A collision layer call reads as the project's word for that layer.**
  `set_collision_mask_value(2, true)` reads **Collide with Enemies**, `(2, false)` reads **Stop
  colliding with Enemies**, `set_collision_layer_value(3, true)` reads **Be on layer Player**, its
  `false` twin reads **Leave layer Player**, and `get_collision_mask_value(2)` reads **is set to
  collide with Enemies**. The NUMBER is what the row stores, always: the name is resolved when the
  row is drawn, so a layer renamed tomorrow renames the sentence and the file never moves, and a
  layer this project never named reads as its number, which is honest. Which of Godot's two lists of
  names a line means is decided by the FILE - a script that extends a 3D body means 3D layers, since
  the two calls are spelled identically in both dimensions. Raw bit arithmetic beside them
  (`collision_mask |= 4`, `collision_layer = 0`) is untouched: it is about a set of layers rather
  than one, and it keeps the readings it already had.

- **An animation played through a node path reads as the row, in whichever spelling you used.**
  `$Anim.play("idle")` and `$Anim.queue(&"swing")` are the same two calls people write with and
  without the ampersand, and both open. The whole literal is the value - quotes and `&` included -
  so the spelling you typed is the spelling the file gets back, and a lifted row and an authored row
  are edited by the same field. The receiver has to be a node PATH (`$Path`, `%Unique`,
  `get_node("Path")`): `play` and `queue` are among the commonest method names in the language, a
  file can declare a `play()` of its own, and a bare `sprite.` says nothing about what `sprite` is -
  so claiming those on a call name alone would take lines away from the readings that can say more
  about them.

- **The maths and the moves are the calls in their own echoes.** A `_process` full of
  `value = clampf(value, 0.0, max_hp)`, `lerp`, `wrapf` and `remap` opens as **Keep Between**,
  **Move Toward (each tick)**, **Wrap Around** and **Rescale**; `position += transform.x * 240.0 *
  delta` is **Move Forward**, `global_position += Vector2.RIGHT * 20.0 * delta` is **Move (the
  world's way)**, and the `rotate_toward(…, global_position.angle_to_point(…), deg_to_rad(180.0) *
  delta)` line everybody copies is **Face**. There is no separate lift table for any of them: each
  row's template IS the line, which is what makes the hand-written file and the authored row one
  thing, and saving the opened file writes your own bytes back.

- **The two drawing-order lines read as sentences.** `z_index = $Player.z_index + 1` is
  **Draw in front of $Player** - the one `z_index` line whose meaning is relative rather than a
  number - and `visibility_layer = 2` is **Show only to "minimap"** when the project has named that
  layer, since the field lists the project's own layer names rather than asking for the bitmask. A
  layer nobody named stays `Set visibility_layer to 16`, because there is no word to say instead and
  inventing one would be a claim about a layer this project has never made. A file holding both
  opens as those words and saves back without one byte changing.

- **`match` patterns read as the conditions they are.** A match on plain values already reads as the
  if / else-if / else chain a reader knows. The patterns that say something a plain value cannot join
  the same chain now: `["move", var x, var y]` is `event is a list of 3 starting "move"` with `x` and
  `y` as chips beside it, `{"type": "hit", "amount": var a}` is `event is a table with type = "hit"`
  with `amount → a` as its chip, and `var other when other is String` is `event is text` with `other`
  as its chip - the guard read through the ordinary condition grammar, with the bound name standing
  for what it is bound to, because that is what it stands for. A bare `var other` and `_` are both the
  Else they are. Strictness applies here as everywhere: a nested pattern, an open-ended `..`, or any
  pattern with a call in it keeps the exact text it was written as.

- **A loop that counts down or steps says which values the body sees.** `for i in range(10, 0, -1)`
  is `For "i" from 10 down to 1` and `for i in range(0, 100, 10)` is `For "i" from 0 to 90 step 10`.
  Godot's stop value is exclusive; the row shows the last value the body actually reaches, so the
  arithmetic is done once rather than by every reader.

- **A pure-data `class X:` is a Data type.** The bar in the head says `Data type AbilityData` and its
  fields are the rows below, each editable in place. `Stats.new()` reads `a new Stats`,
  `stats.duplicate()` reads `a copy of stats`, and `thing is Stats` reads `is a Stats`. An inner class
  with methods in it keeps its read-only code block: a sentence may only stand for a shape it can see
  whole.

- **The scene tree in one word each.** `find_child("HUD")` is `the child named HUD`,
  `get_tree().current_scene` is `the layout`, `get_tree().current_scene.get_node("Boss")` is `Boss in
  the layout`, `%HealthBar` is `HealthBar` with a muted `unique name` beside it, and
  `enemy.get_path()` is `enemy's path`. Copying a node already in the scene and planting the copy -
  `var copy = enemy.duplicate()` then `get_parent().add_child(copy)` - is one row, `Clone object enemy
  (→ copy, next to it)`; Create object stays what it is, which is making one out of a scene file. Both
  spellings of the plant count, the picked Add Child row and the plain call a hand-written script
  writes, and the row says whether the copy went next to the node or inside it.

  ![A script of vector, colour, data-type and scene-tree lines opened as a sheet](images/reading-vectors-patterns-notes.png)

- **A trailing `# note` is a note on that row.** `hp -= 1  # ouch` reads `Subtract 1 from hp
  💬 ouch`, muted, at the end of the row - which is where and how an event sheet writes a note about
  one step. Before this the comment rode into whichever value the lift put the end of the line in, so
  the row read "Subtract 1  # ouch from hp". The split is quote-aware: a `#` inside a string literal
  is content somebody typed, and a `#` with nothing after it says nothing. A `## description` above a
  function is still that function's description, drawn beside its name.

- **A TODO / FIXME / HACK / NOTE written directly above a step belongs to that step.** It is how a
  person writes a note about one action when the language has nowhere else to put it, so it reads
  where a note reads. Every other comment line stays the comment row it has always been - a paragraph
  above a run of steps is about the run, not about the first line of it. Both lines are still in the
  file either way; nothing here changes a byte.

- **Where the project's notes are listed.** Tools ▸ Project Doctor counts every task note in your own
  scripts, one finding per line, naming the marker, the file and the line so you can jump to it. The
  Outline (the jump list for the open sheet) grows a `To do` folder at the end with the same notes in
  it. Both are notes, never warnings: an unfinished thought is not a fault, it is a thing somebody
  meant to come back to.

  ![A match with patterns, row notes and two counted loops opened as a sheet](images/reading-match-patterns-and-notes.png)

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
- **A handler that asks the event reads as the question it is.** The commonest shape inside `_input`
  and `_unhandled_input` there is - `if event.is_action_pressed("jump"):` - used to read as
  *Expression Is True*, the honest catch-all. It reads **this event is `"jump"` going down**, from the
  **Input Event** section, beside the press widened to include a held key's auto-repeats
  (`is_action_pressed("jump", true)`), the release, the question of which action an event belongs to
  at all, and how hard it is held in this event. Both of Godot's quotings answer to the same row,
  because the `&` in `&"jump"` is a spelling rather than a value and rides back out untouched, and
  the action names come from the project's own Input Map exactly as the polled rows' do. Every one of
  these sentences opens with *this event is*, which no polled row says: the **Input** section's rows
  ask the keyboard how things stand right now and read *`"jump"` is pressed* or *just pressed*, and
  telling the two apart by the tense of one verb is not something a reader should have to do. These are
  the rows for the inside of a handler; the **Input** section's rows ask the keyboard how things
  stand right now, which is what an every-tick event wants, and the two are filed apart so a reader
  scanning one list never has to tell them apart by their small print.
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
- **The evidence is the statements, never a paraphrase.** Every pattern an event claims carries the
  lines that made the sheet think so, so the reason a row says what it says is one hover away. They
  are the statements themselves and not a description of them, but they are not a quote of your file
  either: a line the editor read straight out of the file arrives without its indentation and its
  trailing comment, and a line that became a row is written back out from that row - the same
  statement in the sheet's own spelling. That is what lets the hover answer the same way whether a
  line was kept as code or read as a row.
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

#### Every way of pinning, in the mode's own word

Pinning is the most-written relationship in a game, and it is written in more spellings than any
other shape - so each one reads as the mode it is, and each one is authorable as the same line from
the Pin section of the picker:

| The line you wrote | How it reads |
|---|---|
| `global_position = a.global_position + offset` | `Pin to a (position · offset offset)` |
| `rotation = a.rotation` | `Pin to a (angle)` |
| `global_position = a.global_position + (global_position - a.global_position).limit_length(80.0)` | `Pin to a (rope, max length 80.0)` |
| `global_position = a.global_position + (global_position - a.global_position).normalized() * 80.0` | `Pin to a (bar, length 80.0)` |
| `global_position = global_position.lerp(a.global_position, 10.0 * delta)` | `Pin to a softly (speed 10.0)` |
| `global_position.x = a.global_position.x` | `Pin X position to a` |
| `scale = a.scale` | `Pin size to a` |

The difference between the rope and the bar is one call, and it is the whole difference between the
two behaviours: a rope CLAMPS the gap, so the host hangs free inside the length and is only pulled
once the line goes taut; a bar throws the gap's length away and multiplies the direction back out,
so the host is held at exactly that distance every tick.

A variable the file *declares* as a point on somebody else - `@onready var hand: Marker2D =
$Player/Hand`, a `Bone2D`, the `BoneAttachment3D` a skeleton keeps on a bone - changes the sentence
rather than the line: `global_position = hand.global_position` reads `Pin to Player's hand`. A
`PathFollow2D` or `PathFollow3D` reads `Pin to Track's path position`.

Three rows of that table are **gated hard**, and this is the case where the gating matters most.
`scale = x.scale`, `position.x = x.position.x` and the per-second `lerp` are among the most general
spellings in the language - a parallax layer, a UI element, a solver step and a health bar all write
them, and the lerp is byte for byte how a **camera** scrolls toward a target - so they read as a pin
only in a file that has ALREADY pinned that anchor another way, copies both axes from it, or
declared it as a point on somebody. A lone axis copy stays a lone axis copy, everywhere, and a
camera keeps the words it has had since it got them.

The same rule decides which shapes get a picker row. Only the rope and the bar do, because their
spellings belong to nothing else. A row's template is not just what the row writes - it is what the
IMPORTER matches - so a picker row for one of the general spellings would re-file every such line in
every project as a pin, whatever the reading's own gates said. The other four modes are authored by
attaching the Pin pack.

![A hand-written pin file opened as a sheet: the head bar reads Pins, what this object rides and can let go of, listing anchor, hitch, lead, Player's hand, Track's path and ground, with one line each saying pinned to anchor (rope), pinned to hitch (bar), pinned to lead (soft and angle), pinned to Player's hand (position), pinned to Track's path (position) and pinned to ground (x only and y only)](images/opened-script-pin-modes.png)

![The same file's tick event: nine action rows reading Pin to anchor (rope, max length Rope Length), Pin to hitch (bar, length Bar Length), Pin to lead softly (speed Follow Speed), Pin to lead (angle), Pin to Player's hand (offset pin_offset), Pin to Track's path position, Pin X position to ground, Pin Y position to ground and Pin size to anchor](images/opened-script-pin-rows.png)

An object that pins reports it on its head bar too, under **Pins**: `pinned to anchor (rope)`, in
the same mode words the pack's own knob uses. That bar is derived from the file's pin lines through
the same gates, so it can never announce a pin the canvas does not show.

Two Doctor notes come with the words. **Double follow** names an object that is BOTH a child of X
and pinned to X - being a child already carries it, so the pin writes its place a second time from
the same source and the two fight every frame. **Pin to a freed object** names a pin whose anchor
the file destroys with no Unpin and no validity question anywhere. Both are notes, never warnings:
each file runs, it just does something its author did not mean.

![A projectile script read as an event sheet: Set speed to speed accelerating by accel, Set angle of motion to angle, Set gravity to gravity and Move under one tick event, with Distance travelled greater than range px as the condition that destroys it](images/opened-script-behaviors.png)

![The same file further down: Move toward destination at speed, Has arrived and Stop for the glide, then Rotate clockwise, Wrap around layout horizontally, Bound to layout, Pin to anchor by position and by angle, and Fade out over 1 seconds then destroy](images/opened-script-behaviors-one-liners.png)

#### Data assets, and the window

Two more families of line that a plain Godot script is full of.

A script that `extends Resource` is not an object in the scene - it is a **data type**, and that is
what its Include bar says, under the name a designer would use out loud (`enemy_stats.gd` opens as
an `Enemy Stats`). Its `@export`s are **Field** rows rather than instance variables, because every
`.tres` saved from it is one asset with those fields filled in. In the events, an asset reads as the
asset: `load("res://data/slime.tres") as EnemyStats` is **the data asset slime.tres**, a field read
off one says whose it is (`stats.hp` is **stats's hp**), and `ResourceSaver.save(stats, path)` is
**System ▸ Save data asset stats as slime.tres**. The rows that write exactly those lines are **Data
Asset** and **Save Data Asset** in the picker's Files folder. A `.tres` also opens as a table sheet,
and a folder of them as one grid - see the Custom Resources guide.

![A Resource script's head: the identity bar reading "Enemy Stats Preview" with a "data type" chip instead of the Node class ladder, over its three exported fields](images/data-type-include-bar.png)

![An opened script's data-asset rows: Set s to the data asset slime.tres, and Save data asset stats as slime.tres](images/data-asset-reading.png)

The window is an object too, so the lines that drive it wear its name:

| the GDScript | reads as |
| --- | --- |
| `get_window().size = Vector2i(1280, 720)` | `Window ▸ Set size to 1280 × 720` |
| `get_window().title = "My Game"` | `Window ▸ Set title to "My Game"` |
| `get_window().mode = Window.MODE_FULLSCREEN` | `Window ▸ Set fullscreen on` |
| `DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)` | `Window ▸ Set vsync on` |
| `Engine.max_fps = 60` | `System ▸ Set max FPS to 60` |
| `get_viewport().msaa_2d = Viewport.MSAA_4X` | `System ▸ Set anti-aliasing to 4×` |
| `get_viewport().get_texture().get_image()` | `a screenshot` |
| `img.save_png("user://shot.png")` | `System ▸ Save image img as shot.png` |
| `$SubViewport.get_texture()` | `SubViewport rendered as an image` |

Every one of these has a row that writes the same line: the **Game Window** folder in the picker
holds the window verbs plus **Set Anti-aliasing**, **Save Image As**, **Screenshot** and **Rendered
As An Image**. A sheet-authored options screen and a hand-written one are the same file.

![An opened script's window rows: Window Set size to 1280 x 720, Set title, Set vsync on, then System Set max FPS and Set anti-aliasing, and a screenshot function below](images/window-render-reading.png)

#### The reading lenses - names you can turn on and off

- **Reading lenses.** In Reading mode (a read-only preview, or the Simple pill's Reading lens) names read
  as words (`_coyote_timer` -> `coyote timer`, a knob with its Inspector capitalisation), property chains
  read possessively (`host's velocity X`), NOT is the red `not` mark in the icon column, the host and any `$Node` /
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
    beside it (*from anyone · also here · reliable*). `f.rpc(10)` reads **Multiplayer ▸ Send
    Take Damage to everyone** with the payload as named chips, `f.rpc_id(1, 10)` reads **to the
    host**, `f.rpc_id(peer, 10)` reads **to peer**, `multiplayer.is_server()` reads **Is host**,
    `is_multiplayer_authority()` reads **Owns this object**, and `multiplayer.get_unique_id()` reads
    **Multiplayer.MyID**.

    The connection itself reads too, and this half is a **lift**: the row stores the spelling it
    matched and writes that spelling back, so opening a networked file and saving it untouched
    reproduces it byte for byte. Nothing on disk changes until you edit a row, and then only that
    row's lines change.

    | What you wrote | Reads as |
    | --- | --- |
    | `peer.create_server(PORT, 4)` then `multiplayer.multiplayer_peer = peer`, with `peer` declared at the top of the file | **Host a game on port PORT for up to 4 players** |
    | `var peer := ENetMultiplayerPeer.new()` / `peer.create_server(PORT, MAX)` / `multiplayer.multiplayer_peer = peer` (the three-line form Godot's own docs use) | the same row, with the local peer |
    | the `create_client(address, PORT)` twin of either | **Join a game at address port PORT** |
    | `multiplayer.multiplayer_peer = null`, `peer.close()`, or the `get_tree().get_multiplayer()` spelling of the first | **Leave the game** |
    | `WebSocketMultiplayerPeer` / `WebRTCMultiplayerPeer` in the constructor | the same rows, with that peer kind |
    | `multiplayer.peer_connected.connect(_on_x)` and its four siblings | **On player joined** / **On player left** / **On joined the host** / **On join failed** / **On the host left**, with the connect line re-emitted exactly as you wrote it |
    | `multiplayer.peer_authenticating.connect(...)` and `peer_authentication_failed` | **On player authenticating** / **On authentication failed** |
    | `multiplayer.multiplayer_peer.disconnect_peer(id)` | **Kick player id** |
    | `multiplayer.multiplayer_peer.refuse_new_connections = true`, `multiplayer.server_relay = false` | **Stop accepting players**, **Relay messages between players off** |
    | `multiplayer.complete_auth(id)`, `multiplayer.send_auth(id, bytes)` | **Accept player id**, **Send auth bytes to player id** |
    | `$Player.set_multiplayer_authority(id)`, `$Player.get_multiplayer_authority()` | **Give $Player to player id**, **Owner of $Player** |
    | `multiplayer.get_peers()`, `.size()`, `multiplayer.get_remote_sender_id()` | **Players**, **Player count**, **Sender** |
    | `rpc("f", 10)`, `rpc(&"f", 10)`, `rpc_id(1, &"f", 10)`, `rpc_id(peer, "f", 5)`, `$Other.rpc(&"f")` | the **Send** rows, each re-emitting your own quoting |
    | `@rpc(...)` above a function, in any order or subset of the options, with or without a channel | that function's **message** row and its words, with the annotation itself as the row's echo - and back verbatim when the dialog is confirmed unchanged |
    | `$Spawner.spawn(id)`, `spawner.spawn({...})` | **Spawn**, with the spawner in the object column |
    | the four lines of an automatic spawn - `var p = load(...).instantiate()`, `p.name = ...`, `p.position = ...`, `$Spawner.get_node($Spawner.spawn_path).add_child(p, true)` | one **Spawn scene named at** row, re-emitting your own variable name, your `load` or `preload`, and whether you passed `true` |
    | `$Spawner.spawned.connect(...)`, `despawned`, `$Sync.synchronized.connect(...)` | **On spawned** / **On despawned** / **On synchronized**, on the node in the object column |
    | `$Sync.set_visibility_for(id, true)` / `(id, false)`, `$Sync.public_visibility = true`, `$Sync.add_visibility_filter(f)` | **Show to player** / **Hide from player** / **Show to everyone** / **Ask f who may see it**, and `f`'s own function row then reads `visibility filter` |
    | `set_multiplayer_authority(str(name).to_int())`, `(name.to_int())`, `(id, true)` | read as who owns this object |
    | `if not is_multiplayer_authority(): return` and the `if is_multiplayer_authority():` that wraps a whole body (and the `multiplayer.is_server()` pair) | read as who runs this function; the early return keeps its `return` |
    | `## @ace_group(name="Scoring", runs_on="host")` above a group's events, and the `if multiplayer.is_server():` the group wraps them in | the group's **Runs on** word; the guard comes off the rows and rides the group, and re-saving writes it back exactly |
    | a `create_server` or `create_client` given channels and bandwidth limits, in the same three-line run | **Host a game (Advanced)** / **Join a game (Advanced)**, writing back only the arguments you wrote |
    | `peer.host.compress(ENetConnection.COMPRESS_*)`, whatever the connection was reached through | **Compress network traffic**, the receiver a value that rides back out unchanged |
    | `multiplayer.multiplayer_peer.put_packet(bytes)` and its `get_packet()` twin | **Send raw bytes** / the **Next raw packet** expression |

    And the honest other half. These stay the code they are, because no row can say them without
    losing something: the `var error = peer.create_client(...)` spelling that checks what the call
    answered, and a `create_client` that binds its own local port. They still read line by line, and
    the head's **reads as** band counts them: *every networking line reads as a row - 9 of 9*, or
    the number it really is.
  - **Lighting.** A light is an OBJECT, not a parameter: `$Torch.energy = 1.2` reads **Torch ▸ Set
    brightness to 1.2**, and the word is the same in 2D and 3D while the code echo shows the property
    your light really has. This half is a **lift** too - the row stores the spelling it matched, so
    `$Torch`, the variable you held it in, and `get_node("Torch")` each come back exactly as you
    wrote them.

    The gate is the SCENE. A line only becomes a light row when the scene the sheet is attached to
    (or a typed declaration in the file itself, `@onready var torch: PointLight2D = $Torch`) says the
    node it names really is a light. `$Door.visible = false` is a sentence half the objects in a game
    can say, so a node whose class cannot be established stays a script block with the usual Adopt
    offer rather than being relabelled.

    | What you wrote | Reads as |
    | --- | --- |
    | `$Torch.energy = 1.2`, `torch.light_energy = 0.5` | **Set brightness to …**, on the light the line names |
    | `$Torch.color = Color("ffd9a1")`, `$Sun.light_color = …` | **Set colour to …** |
    | `$Torch.enabled = false` (2D), `$Flashlight.visible = false` (3D - a Light3D has no `enabled`) | **Turn off**, and the `= true` twin **Turn on** |
    | `$Torch.shadow_enabled = true` / `= false` | **Turn shadows on** / **Turn shadows off** |
    | `$Torch.texture_scale`, `$Bulb.omni_range`, `$Flashlight.spot_range` | **Set reach to …**, whichever of the three that light answers to |
    | `$Flashlight.spot_angle = 30.0` | **Set cone angle to 30.0** |
    | `create_tween().tween_property($Lantern, "energy", 1.0, 0.5)` | **Fade to 1.0 over 0.5 s** |

    A sheet attached to the light itself names no node at all: `energy = 1.2` in a script on a
    `PointLight2D` is the same **Set brightness to 1.2** row, with *On node* left blank exactly as a
    row you dropped would leave it. The gate is the same one - the scene has to say the node this
    script runs on really is a light - so the identical line in a script on anything else stays the
    variable assignment it always was.

    Two nodes of a lit scene are not lights, and they read the same way. A **CanvasModulate** is how
    Godot darkens a whole 2D layer, and it stores that as a colour - correct, and unreadable. The row
    keeps the colour (so your file comes back byte for byte) and READS as the darkness it makes: how
    much light the tint takes away, by the engine's own reckoning of how bright a colour is. A
    **WorldEnvironment** is the World object, and every one of its rows writes a property of the
    environment it holds.

    | What you wrote | Reads as |
    | --- | --- |
    | `$Level.color = Color(0.3, 0.3, 0.36)` | **Level ▸ Set darkness to 70%, tinted #4d4d5c** |
    | `create_tween().tween_property($Level, "color", Color(0.1, 0.1, 0.15), 10.0)` | **Fade darkness to 90% over 10 s** |
    | `$World.environment.fog_enabled = true` / `= false` | **World ▸ Turn fog on** / **Turn fog off** |
    | `$World.environment.glow_enabled = true` / `= false` | **Turn glow on** / **Turn glow off** |
    | `$World.environment.fog_density = 0.03` | **Set fog thickness to 0.03** |
    | `$World.environment.ambient_light_energy = 0.15` | **Set ambient light to 0.15** |
    | `create_tween().tween_property($World.environment, "glow_intensity", 1.2, 4.0)` | **Fade the glow to 1.2 over 4 s** |
    | `$World.environment = $World.environment.duplicate()` | **Make the environment this scene's own** |

    What deliberately does NOT lift: a toggle (`light.shadow_enabled = not light.shadow_enabled`),
    which no single row can say; a copy taken from a DIFFERENT world
    (`$A.environment = $B.environment.duplicate()`), which is not the one step that row stands for;
    and every line whose target the scene cannot show to be a light.
    `$Level.color = …` is the same sentence as a light's colour, so which of the two it IS depends
    entirely on what the scene says `$Level` is - and a node the scene cannot place stays code.
    The sixteen Core lighting actions are untouched beside all of this - a sheet saved with one of
    them opens with it.

    The head of an opened lit sheet also gains bands nothing in the file says, read from the scene
    every time it opens and stored nowhere: **lit by** (one per light: its name, the plain word for
    what kind it is, and *casts shadows* when it does), **shadows** (how many `LightOccluder2D`s can
    actually block them - and, when none can, the sentence saying so, because a light casting
    shadows nothing blocks pays for them and shows nothing), and **environment** (the `.tres` the
    scene loads, and how many OTHER scenes load the same file - which is what makes a fog row
    written at run time follow the player out of the room). Clicking a band selects that node in the
    Scene dock.
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
- **A rigid body reads as the Physics behavior.** On a `RigidBody2D` or `RigidBody3D`, `mass = 2.0`
  reads **Physics ▸ Set mass to 2**, `gravity_scale` reads **Set gravity scale**, `linear_damp` and
  `angular_damp` read **Set linear / angular damping**, `freeze = true` reads **Set immovable**, and
  `if sleeping:` reads **Is sleeping**. The friction and bounce written on a physics material this
  file declared (`var mat := PhysicsMaterial.new()`), or on the body's own material slot, read
  **Set friction** and **Set elasticity** under the object a reader can point at rather than under
  the variable that happens to hold the resource. `apply_impulse(dir * kick, offset)` and
  `apply_force(push, offset)` say **at {offset}**; `apply_torque` and `apply_torque_impulse` say the
  spin. `add_child(PinJoint2D.new())` reads **Create revolute joint** - a damped spring is a
  distance joint and a groove a prismatic one - and an Area's `gravity` reads **Set world gravity**.
  Every one of these is also a row you can drop, writing the same line back.

- **The Controls a form is made of read under the object words a form has.** A `LineEdit` or
  `TextEdit` is **Text input**: `placeholder_text = "Your name"` reads **Text input ▸ Set
  placeholder to "Your name"**, and the `text_changed` / `text_submitted` handlers read **On text
  changed** / **On submitted**. An `ItemList`, `OptionButton` or `Tree` is a **List**:
  `list.add_item("Sword")`, `remove_item(0)`, `select(2)` and `clear()` read **Add item** / **Remove
  item** / **Select item** / **Clear**, `get_item_text(i)` reads `list.ItemText(i)`, and the
  `item_selected` handler reads **List ▸ On item selected**. A `CheckBox` is a **Check box** (**Is
  checked**, **Set checked**), a `FileDialog` is a **File chooser** (**Open**, **On file chosen**),
  `tabs.current_tab = 1` reads **Tabs ▸ Switch to tab 1**, a `RichTextLabel` reads **Set formatted
  text** / **Append formatted text**, and `tooltip_text` reads **Set tooltip** on any Control.

- **A path follower reads as the Follow a Path behavior.** `follow.progress += speed * delta` reads
  **Follow a Path ▸ Move along path at speed** on the object that MOVES, `follow.progress_ratio >=
  1.0` reads **Has reached the end**, `follow.progress = 0.0` reads **Go to start**, and `loop` and
  `rotates` read **Set looping** and **Set rotate with path**. A step that is not scaled by the
  frame time stays the jump it is, and a ratio compared against a half stays a comparison.

- **Text formatting and regular expressions.** `"%s has %d hp" % [name, hp]` reads as the sheet's
  join (`name & " has " & hp & " hp"`), and `"{a} vs {b}".format({"a": p1, "b": p2})` reads
  **"{a} vs {b}" with a = p1, b = p2** - claimed only when every key the call handed it is a slot
  the pattern names. With the Familiar Words glossary on, `str(score).pad_zeros(5)` reads
  `zeropad(score, 5)` and `raw.capitalize()` reads `capitalised raw`. A regular expression kept in a
  variable of the file (`var rx := RegEx.new()`) reads as one: `rx.compile("\d+")` is
  **Text ▸ Set pattern rx to "\d+"**, `rx.search(text)` is `first match of rx in text`,
  `rx.search_all(text)` is `all matches of rx in text`, `rx.sub(text, "#")` is
  `replace matches of rx in text with "#"`, and `m.get_string()` is `the match`.

- **The clock, and the wait that freezes the game.** `Engine.get_frames_drawn()` reads `tickcount`,
  `Engine.get_frames_per_second()` reads `fps`, `Time.get_ticks_usec()` reads
  `now (microseconds)` and `get_process_delta_time()` reads `dt`. `OS.delay_msec(500)` reads
  **System ▸ Wait 0.5 seconds** with a muted **⚠ blocks the game** beside it, because that call
  stops the whole process while it counts - nothing draws, nothing takes input, physics does not
  step - and the sheet's own Wait is the one everybody means by "wait". The Doctor says the same
  thing in words, once per script, so the finding and the note can never disagree.

  ![A rigid body opened as an event sheet: the mass, gravity scale, friction and elasticity set under On created, the pushes and the spin under On hit, and a blocking wait marked as one](images/opened-script-physics.png)

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
- **The Add variable dialog asks for the row in the order the row reads.** **Scope** first - a
  dropdown of Instance / Local / Global / Constant / Static, each with the line that says what it
  means - then **Name**, **Type** (Number, Text, Boolean, then Vector, Color, List, Table and the
  Godot types, with the GDScript spelling muted beside the field), **Initial value**, and
  **Description**. Godot-only polish (the Inspector tick's range, drawer and grouping) stays folded
  behind **More options**. One help strip at the foot describes whatever you are standing on - open
  the Type list and it describes each type before you pick it - and it always ends with **READS AS**,
  the row the sheet will show, over **IN CODE**, the exact line the compiler will write. Choosing
  **Global** reveals the *write into* picker, because a global lives on an autoload rather than in
  this file; choosing **Local** greys the Inspector tick, and **Constant** greys Static with it. A
  name already used here is flagged under the field as you type, not on OK.
- **The Parameters dialog is titled with the row it is writing.** Every action and condition with a
  blank opens it, and the title band reads **Player   Subtract damage * 2 from hp** - the object the
  row belongs to, then the sentence with your values in it, filled in as you type. The ACE's own name
  sits muted at the right. Under the fields is the same one help strip: the parameter's description,
  then what THIS kind of box takes (an expression says what is in scope; a colour says a word, a hex
  or `Color(r, g, b)`; an Input Map action says to prefer one over a raw key), then **IN CODE** - the
  line the compiler will write for the values as typed. Only the focused parameter is described, so a
  four-parameter dialog reads as four rows rather than four paragraphs.
- **A choice explains itself in the list.** An Input Map action reads with the keys bound to it; a
  node group with how many nodes of the open scene are in it; a variable with its type word and what
  it starts at. A pack's own dropdown can carry a line per option.
- **Mistakes are caught as you type, in the strip.** A name that is not a variable turns it red -
  "hpp is not a variable of Player. Did you mean hp?" - with a **Use hp** button and an **Add hpp…**
  button that opens the Add variable dialog on that name; come back and the list has it. A required
  field left blank is red too. A literal of the wrong kind for the verb is amber, and names the verb
  that would take it. OK stays where it is with the reason beside it rather than going grey.
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

<img src="images/addon-manager.png" alt="The Addon manager: a table of installed packs with columns pack, version, enabled, what you can do and reads, each row showing the pack name over its eventsheet_addons folder, its version, a ticked enabled box and Guide, Update and Publish buttons, above Import from .zip, Import from URL, Check for updates and Find more, and the line 96 packs installed, 0 switched off." width="620">

<img src="images/words-settings.png" alt="The Words page: a table headed what it names, with Familiar Words on, off, listing an inheritance set as Family or Base class, a scene as Layout or Scene, _process as Every tick, an attached pack as Behavior, a Godot group as Family (group) or Group, Array slash Dictionary as list slash table, queue_free as Destroy and the reader as Manual, above a live preview of one event and a Reset to defaults button." width="560">

- **The Scene dock and the sheet share one selection.** Pick a node in the Scene dock and its entry
  lights up on the Object bar, with the status line offering `Filter events to Enemy` - an offer,
  not a filter, because you clicked in another dock and did not ask this one to hide anything. Pick
  a row on the sheet and the node that row is about is selected in the Scene dock and in the 2D
  view. Right-click a node in the Scene dock for **Show events**, which opens its script as a sheet
  *and* filters to it. The follow is two-way and never fights itself (each side recognises the echo
  of a selection it caused); turn it off with **View ▸ Follow Scene Selection**, or with the
  `eventsheets/editor/follow_scene_selection` project setting, when you want to work on one row
  while clicking around a scene.
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

**The Scene dock and the sheet share one selection.** Click a node in Godot's Scene dock and the
sheet highlights that node's entry on the Object bar and offers **Filter events to &lt;node&gt;** in the
status line - an offer rather than a silent filter, because the reader chose a node in another dock
and rewriting what their sheet shows on the strength of that would be the sheet taking a liberty.
Click one of the offer's words and the Filter lens the sheet already has does the narrowing; click
anything else and nothing changed. It runs the other way too: selecting a row selects the node that
row is about, so the Scene dock and the 2D or 3D view land on it. Right-click a node in the Scene
dock for **Show events** to go straight there - the node's script opens as a sheet with its events
already filtered to that node.

The follow is a setting, on by default: **View ▸ Follow Scene Selection** toggles it, and it is
stored as the project setting `eventsheets/editor/follow_scene_selection`, so the choice outlives
the session. Turn it off while you are working on one row and clicking around a scene; nothing else
about either dock changes.

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

**A line that stays code is counted, never hidden.** The head bar's coverage chip says how much of
the file arrived as rows, and **Tools ▸ Project Doctor ▸ Reading** says the other half of it for the
whole project: how many lines no vocabulary claims by name, grouped by the SHAPE they share - the
statement with the author's own words blanked, so `pop.chain().tween_callback(queue_free)` and every
line like it land in one group reading `name.name().name(name)`. The commonest shapes are ranked with
three of their own lines opening as doors into the files they are in; the lines whose shape nothing
else repeats are one counted tail, because a line said once is nobody's table. That page is the one
Doctor section that reports nothing wrong - it is a ledger of where a curated table would pay next,
and `tools/reading_shape_census.gd` prints the same ranking headless over any folder you point it at.

**A pack can teach the reader the lines its own verbs are written as.** If the code you are opening
calls into a behaviour pack, that pack may ship `## @ace_lift_example` beside a verb - the line the
way a person writes it, with the value spans marked - and those calls read as the pack's own rows
rather than as generic method calls. The author's line is stored on the row, so the file still saves
back byte for byte, and a pack whose example cannot keep that promise fails its own build rather than
shipping. See the Custom ACEs guide to write them for a pack of your own, and
[How your code reads](GUIDE-HOW-CODE-READS.md) for the three layers this sits at the top of.

### The things around an object: picking, layers, text and the browser

Four families of line that are about the world an object sits in rather than about what it does, each
of which the sheet has one row for.

- **Picking says which instances.** A line that picks an instance and names it is one row, not a
  declaration whose value happens to be a list step. `var victim = enemies.pick_random()` reads
  `System ▸ Pick a random Enemy`, with `→ victim` muted after it, because the reader's next question
  is what the thing they just picked is called. `filter(func(e): return e.gold > 50)` reads
  `Pick Enemy where gold > 50`, `back()` and `front()` read `Pick top` and `Pick bottom`, and
  `instance_from_id(saved_id)` reads `Pick Enemy by UID saved_id`. A pick only reads when the FAMILY
  is known - the list was built from a group, or the variable carries the type - so a list nobody
  said the kind of keeps its own words rather than being given an object type it never had. A
  walk-the-list-and-keep-the-nearest loop is too many lines to be one row, so it stays the loop it
  is and CLAIMS the picking pattern instead, with its own lines as the evidence behind the chip.
- **Layers and Z order.** `z_index = 5` reads `Set Z order to 5`, with `(relative)` or `(absolute)`
  when the file also says which; `move_to_front()` reads `Move to top of layer` (and
  `get_parent().move_child(self, 0)`, which is how Godot spells the other end, reads
  `Move to bottom of layer`); `reparent($"../FX")` reads `Move to layer FX`. A CanvasLayer IS a
  layer, so its `layer` number reads `Set layer order` and its `visible` switch reads
  `Set layer visible / invisible`.
- **Text.** The theme overrides and LabelSettings writes every HUD script is full of read as the
  styling they are: `Set font size to 32`, `Set font colour to red`,
  `Set horizontal alignment to centre`, `Set word wrap on`, `Set font to bold.ttf`. And `tr("HELLO")`
  reads `translated "HELLO"` wherever an expression shows it.
- **The browser and the platform.** `OS.shell_open(url)` reads `Browser ▸ Go to URL`,
  `DisplayServer.clipboard_set(x)` reads `Copy x to clipboard`, the fullscreen window mode reads
  `Request fullscreen`, and `OS.alert(m)` reads `Alert m`. The questions read under Platform in the
  shipped Platform Info pack's own words - `OS.has_feature("web")` is `Is on web` - so a hand-written
  check and a picked row say one sentence between them. `OS.get_name() == "Android"` reads
  `Is Android`.

All four are also authorable, and that is the point: every picker row's template writes exactly the
shape the reading recognises, so a script that already had these lines OPENS as those rows and saves
back byte for byte. See **docs/Modules/Around-Objects.md** for the rows themselves.

<img src="images/around-objects-rows.png" alt="A hand-written Node2D script opened as a sheet: an On created event whose actions read set Z order to 5, move to top of layer, move to layer $../FX, set layer order to 10, set font size to 32 and set word wrap on, then a Share function whose actions read go to URL https://example.com, copy code to clipboard and request fullscreen." width="720">

### Inheritance shown as one thing - Family, Base class, or your own word

A `class_name` that other scripts `extends` is a base class. Godot has no view of that shape: to see
which scripts extend `Enemy`, what they share, and whether the `"enemy"` group agrees with the
`Enemy` class, a project has to be grepped. An event sheet has had one word for exactly this - an
object set that shares instance variables and behaviors - so the sheet shows the hierarchy as one
entry: the base on top, the scripts that extend it as its members, and the base's own variables and
functions as what they share.

**The word is a setting.** It is `Family` with Familiar Words on, `Base class` with it off, and
`Kind` or anything else you type on the Words page (Settings ▸ Words). One helper answers - it asks
the Words registry for the word and adds the plural the headings need - and every user-facing use
goes through it, so the Object bar's section, the head bar's folder and the object page change
together and can never drift apart.

Where a Godot group has the same name as the base, it is shown on the same line with a ✓ when its
members are the set's. When they are not, that is worth saying out loud, and **Tools ▸ Project
Doctor…** says it: *"Goblin is in the group "enemy" but does not extend Enemy"* - which is where an
"Invalid call" at runtime usually comes from.

### The behaviors a script hand-rolls, named

Some shapes are not one line and not one function - they are a *behavior* a reader already has a name
for, spelled out in Godot's own vocabulary. The reading names them, and the file is untouched:

- **A raycast cast at a target is one question.** A function that guards on distance, points a
  `RayCast2D` at the target, forces an update and returns "nothing in the way, or the thing I hit *is*
  the target" reads as `Enemy has line of sight to t (within Sight Range)` - one condition where five
  rows of ray plumbing were. The shipped Line of Sight pack (2D and 3D) publishes exactly that
  condition, so adopting it is a swap rather than a rewrite.
- **The grab / release / follow trio is Drag & Drop.** A boolean raised beside the line that remembers
  `global_position - get_global_mouse_position()`, lowered on the button-up, and tested before
  `global_position = get_global_mouse_position() + grab_offset`, reads as
  `Drag & Drop ▸ Start dragging`, `▸ Drop`, `▸ Is dragging` and
  `▸ Follow the cursor (keeping the grab offset)`.
- **An anchor preset is a corner.** `set_anchors_preset(Control.PRESET_TOP_RIGHT)` reads as
  `Anchor ▸ Anchor to top right (of the window)`, and a single `anchor_left` or `offset_top` write
  reads as the edge it moves. The Anchor pack writes the same sentence from the picker.
- **Solid and Jump-thru are what a body already is.** `$CollisionShape2D.disabled = true` is
  `Solid ▸ Set disabled`, `one_way_collision = true` is
  `Jump-thru ▸ Set enabled (one-way: solid from above only)`, and `set_collision_layer_value(1, true)`
  is `Solid ▸ On layer World (layer 1)` - with the layer's name from your own Project Settings when you
  gave it one. Neither is a pack, because neither is anything to attach.
- **`test_move(transform, Vector2(0, 1))` is the ground check.** It reads as
  `Is overlapping at offset (0, 1) (a solid)` - the same words the new **Is Overlapping At Offset**
  condition writes - and a loop over `get_overlapping_areas()` reads as `For each a overlapping Area2D`.
- **A weighted draw, a seed and the noise belong to Advanced Random.**
  `["coin", "gem", "nothing"][rng.rand_weighted([70, 20, 10])]` reads as
  `choose weighted("coin" 70, "gem" 20, "nothing" 10)`, `rng.seed = hash("level-1")` as
  `Advanced Random ▸ Set seed to "level-1"`, and `noise.get_noise_2d(x, y)` as
  `AdvancedRandom.Perlin2d(x, y)` when the file said which noise type it wanted.
- **The system clock is the Date object.** `Time.get_unix_time_from_system()` is `Date.Now`, the date
  and time strings are `Date.Today` and `Date.TimeString`, and the fields of a datetime dictionary the
  file read out of the clock are `Date.Hour`, `Date.Minute`, `Date.Second`, `Date.Year`, `Date.Month`,
  `Date.Day` and `Date.Weekday`. Every one of them is also a row you can pick.
- **A spawn is one row, layer and all.** The `instantiate()` local stays where the event declares it,
  and everything the file then does to the new object - the node it is added to, where it is put, the
  properties set on the way in - collapses into
  `Create object Enemy on layer FX at spawn (as e)   rotation = angle`, whatever order those lines were
  written in.

<img src="images/opened-script-behaviors.png" alt="A hand-written CharacterBody2D script opened as a sheet: the head lists sight_range, the ray, the drag flag and its grab offset; a tick event reads Drag and Drop is dragging then Follow the cursor keeping the grab offset; a second reads Is overlapping at offset (0, 1) (a solid); and the functions read Return CharacterBody2D has line of sight to t within Sight Range, Start dragging, Drop, Jump-thru Set enabled, Solid Set disabled, Solid On layer 1, Set noise type to Perlin, Set seed to level-1 and Set drop to choose weighted." width="760">

None of this is a guess. Each reading rests on a fact the file *states* - the local really is a
`RayCast2D`, the boolean really is raised beside the grab offset, the local really was filled from the
system clock - and with the fact absent every line keeps the ordinary reading it has today. Each event
holding one of these shapes also records it in the pattern registry with the exact source lines as its
evidence, which is what the ⟡ chip, its hover and **Adopt behavior** read.

### Beginner spellings and the reading layer

The lift does not require style-guide code. Beginner spellings round-trip byte-exactly too:

- **Inferred `:=` variables** (`var hp := 100`, `const SPEED := 2.5`) lift to first-class variable
  rows that re-emit the walrus exactly as written.
- **Untyped lifecycle headers** (`func _physics_process(delta):` - no return arrow) lift to their
  trigger events carrying the source spelling, so saving changes nothing.
- **The prelude reads as the sheet's identity**: one band per line, always visible - the class
  name (with the base class's own editor icon), `extends`, `@icon`, `@tool`, the `##` description,
  an autoload's `project.godot` entry, a behaviour's host binding - each echoing its own line at
  the right edge, and an enum reads as a sentence ("State is one of PATROL, CHASE or FLEE") that
  opens into one row per value. A band is one LINE: a doc comment written over several `##` lines
  shows its first on the band, and editing that band rewrites only that line - the rest of your
  block comes back exactly as you wrote it.

And a hand-written `enum` + `match` state machine opens READING like a state machine: the tick
event's lane says "decides by state - 3 states below", each case is a ◆ `Current state is "patrol"`
row whose plain statements read as sentences and actions, and each transition is a nested CONDITION
row - the guard in plain words in the condition cell (`Can See Player`, with a small ƒ badge marking
a computed check), the state change as its action. Branching never renders in the action lane.

Those are the words the shipped **State Machine** behavior publishes too - **Go to state**,
**Current state is**, **On any state change**, **Time in state** - so a machine you wrote by hand and
a machine you attached read identically, and the event that asks the question claims the
`state_machine` pattern (with the State Machine pack named as the behavior it could become).

The machine itself is read as the behavior it is. An `enum` plus a variable of that enum started on
one of its members is an FSM on the object, so the head's **Behaviors** folder grows one ordinary
line - `FSM · Idle`, the behavior and the state it starts in - beside any behavior the scene mounts
on the same object. Hovering that line names the plumbing it stands for: the enum, the state
variable, the transition function, the enter and exit matches, and a `previous_state` when the file
keeps one. Nothing else about the machine goes on the canvas, because a behavior does not put its
plumbing on a sheet.

The rows that drive it read as the behavior's own vocabulary:

| the GDScript | reads as |
| --- | --- |
| `change_state(State.JUMP)` | `FSM ▸ Go to state "Jump"` |
| `state = State.JUMP` | `FSM ▸ Go to state "Jump"` |
| `state == State.JUMP` | `FSM ▸ Current state is "Jump"` |
| `previous_state == State.DASH` | `FSM ▸ Previous state is "Dash"` |
| `state in [State.IDLE, State.RUN]` | `FSM ▸ Current state in list "Idle", "Run"` |
| `State.keys()[state]` | `Player.FSM.CurrentState` |

A state's name reads as the word you would say out loud (`WALL_SLIDE` shows as `Wall Slide`); the
enum's own spelling is the code's and stays on hover. The three functions are found by what they do
rather than by their names - the transition is the one that assigns the state variable from one of
its parameters, and the calls it makes on the state before and after that assignment are exit and
enter - so a file spelling them `set_state` and `_on_enter` reads exactly the same. All display
only: the file is untouched and it still re-emits byte for byte.

On real code the effect compounds. Here is the plugin's own semantic analyzer, whose annotation table is
31 entries long:

<img src="images/block-views-real-file.png" alt="A real source file opened as a sheet: the head's band stack, a one-row collapsed const KNOWN_ANNOTATIONS table reading 31 entries, and a function whose body is an Expression verb row with condition and action rows." width="720">

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

### Tool code: the four shapes an editor is written in

A project that builds editor tooling is written in shapes a game script never has, and the sheet
reads all four of them by SHAPE - there is no list of file names anywhere.

**A helper with a back-reference is a behavior of the thing it helps.** A `RefCounted` whose
constructor only stores the object it was handed, and whose methods reach back through it, adds its
verbs to that object. So the head bar says whose helper it is and which file that object lives in,
the constructor folds into the bar (it stored a reference; there is nothing to read), a value read
through the reference reads as the object's own property, and a call through it reads under the
object's name:

![A helper script read as an event sheet: the head bar says helper of Dock (event_sheet_dock.gd), made with the dock; the Build function reads Set window to a new Window, Set title, Set size, and the connected lambdas read as On Close Requested and On Pressed triggers](images/opened-script-helper-of.png)

**An edit handed to an undo funnel is one undoable step.** A label plus a callback reads as a Local
boolean catching the answer, named by the label the user will see in Undo, with the edit hanging
under it as sub-events - and a `return` inside it is the Answer the funnel asked for:

![An undo-funnel edit read as one step: Local boolean changed = Dock, Edit sheet undoably "Apply Cell Edit", with the steps below it reading mode = "new_condition_event", Call Append Condition Entry, Answer true, and Answer false at the end](images/opened-script-undo-step.png)

**A class that is all static is a shared store.** Nothing of it is ever made, so each `static var` is
one value for the whole editor rather than one per copy, and a `const` whose own comment says it is
frozen wears that promise. The three report levels read as three different acts: **Warn**, **Report
error** and **Log error**:

![A static registry read as an event sheet: the head bar says shared store, nothing of its own is ever made; PATTERN_IDS is a constant list of text marked frozen; _claims and _stated are Shared tables, one for the whole editor; the rows read Warn, Stop event and Report error](images/opened-script-shared-store.png)

**A vocabulary module publishes Define rows.** Every row a module registers reads the way a pack
author reads their own verbs - the kind, the name, the id, the category, the inputs, and the line it
writes. And a function that hands over to itself wears a muted `↻ itself` on the call row:

![A vocabulary module read as an event sheet: the Register function's rows read Define condition Is Pinned and Define action Pin To with their categories, inputs and Writes lines, and a Walk function whose call row ends with the mark for calls itself](images/opened-script-vocabulary-module.png)

None of this appears in an ordinary game project: every one of the four shapes has to be there in
the file before a word of it is said.

## 7b. Living in a Big Project: the Minimap, the Sheet Map and the History List

An adopted project is not one file. Three views in the **View** menu are for the size of it.

**View ▸ Minimap** puts a picture of the whole sheet down the right edge of the canvas: one thin bar
per row, tinted by what that row is - a trigger, an every-tick event, a function, a group, a
comment, a Script block, a disabled row. The part you are looking at is a translucent box you can
drag; your bookmarks and any row the sheet flagged show as marks in the margin; groups paint faint
bands you can hover to read the name of. Click anywhere in the column to jump there. A sheet past
200 events shows it the first time you open it, and your own choice from the menu holds after that.

<img src="images/minimap-column.png" alt="A long sheet with the minimap column down its right edge: bars tinted per row kind, the visible window drawn as a translucent box, and a bookmark mark in the margin." width="720">

**View ▸ Sheet Map** answers "what talks to what". Nodes are the project's sheets, scenes and
globals; lines are the four ways one reaches another - a call into a global, a signal one raises and
another listens for, an include (`extends` or `preload`), and a layout change. Click a node to open
that sheet; click a line to run the Find that explains it. Drag the boxes into an arrangement that
suits your project - it is remembered - and note that the graph itself is derived every time it
opens, so nothing about it is stored in your project.

<img src="images/sheet-map.png" alt="The Sheet map window: globals, sheets and scenes as boxes in three columns, joined by call, signal, include and layout lines." width="720">

**View ▸ History** lists every edit you have made to the open sheet, in the name the edit gave
itself - "Add Group", "Extract to Function", "Move Variable Up" - with the event it landed on beside
it, and "(undone)" on the steps waiting to be redone. Click one to undo or redo back to it. The
marker follows the sheet itself, so Ctrl+Z from anywhere and a click in this list move the same
place.

If you already know Godot and it is the WORDS that are new rather than the size, the two pages for
that are **Manual ▸ Coming from GDScript** (the two dozen words that account for most of the
confusion) and **Manual ▸ Dictionary: GDScript to events** (the generated full list - every call the
reading recognises, with the row it maps to). The picker answers the same way: type `queue_free`
into Add action and Queue Free comes back with `queue_free()` written beside its name.

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

## 9b. The Doctor's Tidiness Sweep

The rest of **Tools ▸ Project Doctor…** asks whether a sheet is *wrong*. The tidiness sweep asks the
quieter question a readable sheet also has to answer: is any of this still earning its line. Seven
notes, all advisory, never a build break:

| Note | What it means |
| --- | --- |
| `unread-local` | A local variable is declared in a body and nothing in that body ever reads it. |
| `uncalled-function` | Nothing calls this function. Published functions (they are vocabulary), lifecycle hooks and functions whose name appears anywhere are left alone. |
| `unfired-trigger` | A trigger is declared and nothing ever fires it. |
| `unused-behavior` | A behavior the sheet requires that no row uses - a node's worth of runtime nobody asked for. |
| `long-disabled-event` | An event has been switched off for a long time. When git can answer, the note says how many days and says "(git)"; otherwise it uses the file's own date and says "(file date)" rather than presenting the weaker fact as the stronger one. |
| `identical-events` | Two events read identically - same trigger, same conditions, same actions, same parameters. Comments and breakpoints are ignored; two rows that *do* the same thing are the finding however they are annotated. |
| `repeated-literal` | The same number or quoted string is typed three times or more. |

<img src="images/doctor-tidiness-findings.png" alt="The Project Doctor window showing eight tidiness notes on one sheet: an unread local variable, an uncalled function, an unfired trigger, an attached behavior no event uses, an event switched off for a long time, two pairs of identical events, and a literal appearing three times. Re-run checks and Fix selected buttons sit below." width="680">

The last one repairs itself. Select it and a quick-fix chip appears: **⚡ Extract 400 to a
variable**. One click gives the value a name and points every parameter that spelled it at the name
instead. The first draft of the name comes from the value itself (`value_400`, `jump_wav`) - rename
it from its row, which is the point of extracting it. The edit opens the sheet and goes through the
ordinary undo funnel, so Ctrl+Z takes it back.

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
