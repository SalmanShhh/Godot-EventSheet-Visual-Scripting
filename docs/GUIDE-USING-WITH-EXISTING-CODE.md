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
2. [The Interop Map](#2-the-interop-map)
3. [Call Your Existing Code from a Sheet](#3-call-your-existing-code-from-a-sheet)
4. [React to a Signal Your Existing Code Emits](#4-react-to-a-signal-your-existing-code-emits)
5. [Putting a Sheet on a Node - Two Modes](#5-putting-a-sheet-on-a-node---two-modes)
6. [Call a Sheet from Your Existing Code](#6-call-a-sheet-from-your-existing-code)
7. [Adopting an Existing Project: Reverse-Lift](#7-adopting-an-existing-project-reverse-lift)
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
- **One system gets reached constantly** and deserves first-class vocabulary - the last section covers when wrapping pays off, and the wizard that previews, curates and renames the verbs your own script publishes.
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

Pick one and the tree scopes to its verbs: methods that return
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
them, and listing everything would bury the verbs you actually want. They stay reachable
where they belong, in expressions and the Self section. A script that already publishes as a
provider - it lives in `eventsheet_addons/`, or you taught it explicitly - is skipped too: its
verbs already reach the picker with your own names, kinds and hidden marks, so reflecting it
again would list everything twice.

To include a folder of scripts without a `class_name`, add it to the
`eventsheets/vocabulary/extra_paths` project setting; such scripts are identified by their
file name.

### Making them read the way you want

Right-click any of these verbs in the picker:

- **Rename this verb…** / **Set its category…** - fix a name that reads badly in a row.
- **Hide this verb** / **Hide everything from `<Class>`** - trim what you never use. A hidden
  class stays listed greyed out; select it to bring it back.
- **Reset to the inferred name** - undo one refinement.

These are stored in `res://eventsheet_vocabulary.tres`, **never written into your script**,
and they change presentation only - ids and emitted calls are untouched. Delete that file and
every verb returns to its inferred name with no sheet affected. If you would rather your
script describe itself (so a teammate reading the file sees the same vocabulary), call
`EventSheets.bake_overrides(script_path, class_name)` to write them in as `## @ace_*`
comments; the file is backed up first and only comment lines are ever added.

The tooltip tells you which layer a name came from: *"From your project's Inventory -
inferred from the script, not curated"*, or *"renamed by you"* once you have refined it.

### Naming a raw call you already have

A row that came in as a bare **Call Method** - typed by hand, or lifted from existing
GDScript - can usually be named. Right-click it and, when it matches exactly one of your
verbs, the menu offers **Convert to Inventory ▸ Add Item**. Converting gives the row that
verb's proper parameter fields and emits exactly the same code as before.

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
setup** strip; the function becomes a real verb row with a named parameter and a return badge; and its body
becomes conditions and actions, including the `for` loop as a condition with its own sub-events. What still
has no structured equivalent stays an in-flow GDScript block - honest, editable, and byte-for-byte
unchanged when you save.

Two spelling details used to defeat this on almost every hand-written file, and both are fixed: the two
blank lines the official style guide puts between functions, and an explicit `: Variant` parameter
annotation. Either one could revert an entire file to blocks, so if you tried this before and got a wall of
code, try it again.

### What stays code still reads as what it is

Two kinds of block are no longer shown as code at all, because neither one is logic:

- **A run of comments becomes a real comment row.** Inside a function body it lifts to the same comment
  resource a sheet-authored comment uses, so it drags, disables and converts like any other comment - not a
  code block that merely looks like one. (A marker emission cannot reproduce exactly, such as `#no space`,
  stays verbatim rather than risk the round-trip.)
- **A multi-line collection literal becomes one action per entry.** A defaults table arrives as a row for
  the declaration and a row for each entry, each with ordinary action chrome rather than a GDScript badge,
  so you can read them at a glance and drag them into the order you want. (At file scope, where entries are
  not actions, such a table still collapses to a single `const RULES := { }  31 entries` row instead.)

<img src="images/block-views-before.png" alt="Before: a function body showing a GDScript badge over two comment lines, a System action for the opening line of a dictionary, and the dictionary entries stranded in a separate code block." width="720">

<img src="images/block-views-after.png" alt="After: the same body with the comments shown as plain notes, the dictionary declaration and each of its three entries on their own action rows, and the remaining statements as Set variable and Print action rows." width="720">

Both keep the file byte-for-byte identical when you save it untouched: comment notes are a pure view over
an unchanged block, and splitting a literal into per-entry rows is safe because consecutive code rows
re-emit by appending their lines in order. Double-click any row to open the code editor on the real lines.

Recognising a literal is deliberately fussy - a wrapped function call (a bare `(` opens arguments, not a
value), a literal with a statement after it, and one with a comment above its head are all left as ordinary
code, because in each of those cases something other than the value would be affected.

On real code the effect compounds. Here is the plugin's own semantic analyzer, whose annotation table is
31 entries long:

<img src="images/block-views-real-file.png" alt="A real source file opened as a sheet: a folded Class setup strip, a one-row collapsed const KNOWN_ANNOTATIONS table reading 31 entries, and a function whose body is an Expression verb row with condition and action rows." width="720">

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
and the **What it publishes** table lists one row per verb it would generate - *Publish*, *Kind*,
*Verb*, *Category*, *Parameters*, and *Emits* (the exact GDScript that row compiles to). Browsing only
previews; **Register This Script** is a second, deliberate click, so a script never joins the
vocabulary unseen.

The table is also the editing surface, which matters because raw reflection guesses wrong on ordinary
game code: an untyped `func is_wave_active():` with no `-> bool` reads as an *Action* rather than a
Condition. Correct it in the table, then use one of the three actions beside it:

- **Curate Script…** writes your edits back into the file as `## @ace_*` comment lines. It shows you
  the exact lines first, backs the file up before writing (Tools ▸ Sheet Backups restores it), and
  re-applying the same edits is a no-op rather than a second copy of the block. **Only `##` comments
  are added** - no signature and no body is ever touched, which is why a verb's lane is corrected with
  `@ace_condition` instead of bolting `-> bool` onto your function.
- **Parameters…** shapes the selected verb's parameters: a *Hint* (`comparison` is the whole labeled
  operator dropdown in one word), *Options* written as `value=Label` separated by `|`, and a *Starting
  value* - what the row shows the moment it is dropped. These land as
  `## @ace_param(id, hint: …, options: …, default: …)`.
- **Keep Old Name…** is for after you rename a function. A rename changes the verb's identity and
  orphans every row that used it - *silently*, because each row carries the old call baked in, so the
  sheet still compiles clean and only breaks at game runtime. Select the verb under its new name, type
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
