# Using EventSheets with your existing code

**Short answer: yes.** You can drop EventSheets into an existing Godot project and it works with the
GDScript you already have - your own classes, autoloads, nodes, and signals - **without writing a single
ACE for them.** This page is self-contained: everything you need to interoperate is right here.

The reason it works is one design rule: **a sheet compiles to plain, idiomatic GDScript with zero
dependency on the plugin.** Delete EventForge and your generated `.gd` files still run. So a sheet and your
existing code are just GDScript talking to GDScript - there's no runtime bridge to wire up.

## Table of Contents

1. [Scenarios Where This Page Helps](#1-scenarios-where-this-page-helps)
2. [The Interop Map](#2-the-interop-map)
3. [Call Your Existing Code from a Sheet](#3-call-your-existing-code-from-a-sheet)
4. [React to a Signal Your Existing Code Emits](#4-react-to-a-signal-your-existing-code-emits)
5. [Putting a Sheet on a Node - Two Modes](#5-putting-a-sheet-on-a-node---two-modes)
6. [Call a Sheet from Your Existing Code](#6-call-a-sheet-from-your-existing-code)
7. [Adopting an Existing Project: Reverse-Lift](#7-adopting-an-existing-project-reverse-lift)
8. [When to Wrap Existing Code in Your Own ACEs](#8-when-to-wrap-existing-code-in-your-own-aces)
9. [Tips and Common Mistakes](#9-tips-and-common-mistakes)

---

## 1. Scenarios Where This Page Helps

- **You have an autoload-heavy project** (score manager, event bus, save system) and want sheets to call it all without writing wrappers.
- **A node already has a hand-written script** and you want sheet-driven logic on it anyway - behavior mode composes instead of replacing.
- **Your code emits signals** and a sheet should react to them by name, with no changes on the emitting side.
- **Your GDScript needs to call INTO a sheet** - read its exports, call its functions, await its signals like any class.
- **You are migrating an existing codebase** and want your current `.gd` files to open as editable sheets (reverse-lift), not be rewritten.
- **One system gets reached constantly** and deserves first-class vocabulary - the last section covers when wrapping pays off.

## 2. The Interop Map

Each row is covered below with the exact code it compiles to.

| You want to… | How | No ACE needed? |
| --- | --- | --- |
| Call your existing code from a sheet | ƒx expressions are real GDScript + the **Helpers** ACEs + RawCode blocks | ✅ |
| React to a signal your code emits | **On Signal** trigger (any node / autoload / `self`) | ✅ |
| Put a sheet on a node that already has a script | **Behavior mode** - attach the sheet as a child node | ✅ |
| Call a sheet from your existing code | Hold a typed reference and call it like any class (parity contract) | ✅ |

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
| **Emit Signal On** | `target.emit_signal(signal, args)` | Fire a signal on another node |
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

- **Host lifecycle triggers** - *On Ready*, *On Process*, *On Physics Process*, *On Input*,
  *On Unhandled Input* compile straight to the engine callbacks (`_ready`, `_process`, …). No connection
  needed; they always work on the node the sheet runs on.

> **Good to know:** a connection to *another* node's signal trusts the path/name you give it - it isn't
> checked at compile time, so a wrong path or misspelled signal fails at runtime, not in the editor. And the
> generic *On Signal* handler doesn't bind the signal's arguments - use a reflected `signal:NAME` trigger
> when you need the typed parameters. For signals that cross scenes, route them through an autoload bus
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
with **zero per-member annotations** - see the [Custom ACEs Guide](CUSTOM-ACES-GUIDE.md#5-path-1-auto-ace-provider-scripts).
For a stateless helper (scoring, inventory math) use plain `## @ace_expose_all` (the owned-instance form).


## 9. Tips and Common Mistakes

Interop is broad, but it isn't magic - here's the candid list so nothing surprises you:

- **Raw expressions and *Call Method* are stringly and not type-checked at compile time.** A misspelled
  method, property, autoload, class, node path, or signal name compiles cleanly and only fails when the
  generated script loads or runs. The editor has an *advisory* lint, but it doesn't block. You don't get
  autocomplete-grade safety on an existing API you reach this way.
- **Signal connections to other nodes aren't validated** against the engine's known signals - wrong
  path/name is a runtime failure. (Only signals on `self` are checked and skipped-with-warning if missing.)
- **An already-scripted node needs behavior mode** (a child node), not a plain sheet - see section 5.
- **Cross-scene signal wiring** wants an autoload bus; `get_node("…")` connections are relative to the host.
- **The generic *On Signal* handler doesn't bind the signal's arguments** - use a reflected `signal:NAME`
  trigger when you need the typed parameters.
- **`host` binds in `_enter_tree`** - a behavior's calls before it enters the tree warn rather than act.
- **Don't hand-edit the generated `.gd`** - it's overwritten on recompile; the sheet is the source of truth.
