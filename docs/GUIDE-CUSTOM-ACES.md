# Custom ACEs Guide

EventForge ships hundreds of built-in **ACEs** (Actions, Conditions, Expressions, and Triggers), but
the real power is that you can add your own. A custom ACE turns a piece of your game logic, or a whole
reusable system, into a drag-and-drop block in the event sheet. It compiles to plain GDScript like
every built-in ACE, so there is zero runtime dependency and nothing to ship alongside your game. This
guide covers the ways to AUTHOR custom ACEs, the schema and template language they share, how
they appear in the picker, and how to test them so they never fail silently. For the CRAFT side -
naming, parameter design, descriptions, and picker UX that beginners can use first try - read
[Designing user-friendly ACEs](GUIDE-DESIGNING-USER-FRIENDLY-ACES.md) alongside this one. For the
in-editor, no-code way to author one function from a dialog, see [Using the ACE Studio](GUIDE-USING-THE-ACE-STUDIO.md).

**Before you author anything, check whether you need to.** Your project's own `Node`-derived
classes and autoloads are already pickable - they appear under **Your Project** on the
picker's object page, with their methods classified as Actions, Conditions and Expressions,
their properties as Set/Get pairs, and their signals as triggers. That costs nothing and
needs no annotations, and you can rename or hide any of it from the picker's right-click
menu. Author an ACE when you want a curated row: a friendlier sentence than the method name,
parameter widgets (a colour swatch, an input-action dropdown), a description, or a template
that is more than a single call. See [Using EventSheets with your existing
code](GUIDE-USING-WITH-EXISTING-CODE.md) for the zero-setup route.

![The ACE Studio: Name, Doc comment and Inspector button rows, three cards headlining Action / Condition / Expression with a plain-language line each, a live picker preview of the published function with its Ships-as GDScript signature, and a plain Publish-to-the-picker checkbox.](images/ace-studio.png)

## Table of Contents

1. [Scenarios Where Custom ACEs Help](#1-scenarios-where-custom-aces-help)
2. [Core Concepts](#2-core-concepts)
3. [Quick Start](#3-quick-start)
4. [The Three Ways to Add ACEs](#4-the-three-ways-to-add-aces)
5. [Path 1: Auto-ACE Provider Scripts](#5-path-1-auto-ace-provider-scripts)
6. [Path 2: Custom Descriptors (the EventForge Bridge)](#6-path-2-custom-descriptors-the-eventforge-bridge)
7. [Path 3: Built-in Modules](#7-path-3-built-in-modules)
8. [The codegen_template Language](#8-the-codegen_template-language)
9. [Descriptor Reference](#9-descriptor-reference)
10. [Parameter Reference](#10-parameter-reference)
11. [The Picker: Categories, Node Types, Simple Mode](#11-the-picker-categories-node-types-simple-mode)
12. [Testing Custom ACEs](#12-testing-custom-aces)
13. [Custom Blocks: register your own NON-ACE row kinds](#13-custom-blocks-register-your-own-non-ace-row-kinds)
14. [Use Cases](#14-use-cases)
15. [Tips and Common Mistakes](#15-tips-and-common-mistakes)

---

## 1. Scenarios Where Custom ACEs Help

- **Expose a game system to designers.** You wrote an inventory, dialogue, or quest system in
  GDScript. Wrap its public methods as actions and its state as conditions and expressions, and a
  designer can build the whole game loop visually without reading your code.
- **Turn a node script into vocabulary.** A `Player`, `Enemy`, or `Door` script gains drag-and-drop
  actions (`Take Damage`, `Open`), conditions (`Is Dead`), and triggers (`On Died`) automatically,
  just by annotating the script you already have.
- **Ship a reusable behavior pack.** Bundle a set of ACEs (a health bar, a state machine, a save
  system) that other projects drop in and use, the way Construct 3 addons work.
- **Wrap an engine feature you reach for constantly.** If you keep dropping to GDScript for the same
  one-liner, make it an ACE once so it is one click forever after.
- **Keep generated code clean.** A custom ACE template can bake an expert idiom (a `&StringName`
  literal, a null-safe accessor) while the picker shows a friendly label, so the compiled GDScript
  stays optimized and readable.
- **Prototype fast, then keep it.** Because ACEs compile to GDScript, anything you build with custom
  ACEs is normal code you can hand-edit or hand off later. There is no lock-in.

---

## 2. Core Concepts

### What an ACE actually is

Every ACE is a small piece of metadata called a **descriptor**. A descriptor has an identity
(`provider_id` plus `ace_id`), display text for the picker, a type (Action, Condition, Expression, or
Trigger), and a **codegen_template**: the exact GDScript the ACE emits when you use it. When you
compile a sheet, the compiler substitutes your parameter values into each template and writes the
result into a normal `.gd` file.

That is the whole model. Authoring a custom ACE means producing a descriptor, by one of three routes.

### The compatibility covenant

An ACE's `ace_id` and `codegen_template` are **API**. Once you ship an ACE and someone uses it in a
sheet, renaming the id or changing the template will break their sheet. You can always add a brand new
ACE; you should not silently change a shipped one. When this guide says "covenant-safe", it means a
change that does not alter any existing `ace_id` or template (moving an ACE to a different picker
category is covenant-safe, because the category is display only).

### Key concepts at a glance

| Term | What it means |
|------|----------------|
| **Descriptor** | The metadata object for one ACE (identity, display, type, template, params). |
| **provider_id** | The namespace for a family of ACEs (`Core`, or your `MyPlugin`). |
| **ace_id** | The unique id of one ACE inside its provider. `provider_id::ace_id` must be globally unique. |
| **ace_type** | Action, Condition, Expression, or Trigger. Decides where the template can be used. |
| **codegen_template** | The GDScript the ACE writes, with `{param}` placeholders. |
| **Parameter** | One input field on the ACE (a value, a dropdown, a variable picker). |
| **Provider** | A source of descriptors: an annotated script, a bridge autoload, or a built-in module. |

---

## 3. Quick Start

The fastest custom ACE is a plain script. Make a script with a `class_name`, then point a
sheet at it.

<!-- no-figure -->
```gdscript
# res://scripts/score_keeper.gd
@tool
extends Node
class_name ScoreKeeper

## @ace_category Score
signal high_score_beaten

@export var score: int = 0

## @ace_category Score
func add_points(amount: int) -> void:
    score += amount

func is_winning() -> bool:
    return score >= 100
```

Register it on a sheet (from a tool script, or the dock's provider UI):

```gdscript
editor.add_ace_provider_script("res://scripts/score_keeper.gd")
```

The picker now shows, under a **Score** category:

- **On High Score Beaten** (a trigger, from the `high_score_beaten` signal)
- **Score** (an expression, from the `@export var score`)
- **Set / Add / Subtract Score** (actions, from the same `@export var`)
- **Add Points** (an action, from the `add_points` method)
- **Is Winning** (a condition, because `is_winning` returns `bool`)

You wrote no descriptors. That is Path 1. The rest of this guide explains it, the two more explicit
paths, and the schema they all share.

---

## 4. The Three Ways to Add ACEs

| Path | Best for | What you write | Scope | Effort |
|------|----------|----------------|-------|--------|
| **1. Auto-ACE provider script** | Extending one project with your own game logic | A plain script (methods, signals, `@export` vars), optionally annotated | Per sheet, or every script in `res://eventsheet_addons/` | Lowest: zero descriptors |
| **2. Custom descriptors (bridge)** | Tool authors, generated or dynamic vocabularies | A Dictionary (or `make_descriptor`) per ACE, returned from an autoload | Project-wide | Medium: full control |
| **3. Built-in module** | Contributing ACEs into the plugin itself | `make_descriptor` calls in a module file | Shipped in the plugin | Medium: full control, permanent |

Rules of thumb:

- If you already have a GDScript that does the thing, use **Path 1**. It is the least code.
- If you need exact control over the generated code, the category, or the parameter widgets, and you
  are not editing the plugin, use **Path 2**.
- If you are adding vocabulary that should ship with EventForge for everyone, use **Path 3**.

Paths 1 and 3 can coexist freely. Path 2 (the bridge) is queried by the editor when it builds the
vocabulary, so its ACEs are available while you author and compile, exactly like the others.

---

## 5. Path 1: Auto-ACE Provider Scripts

Point EventForge at a GDScript and its public members become ACEs automatically. This is the closest
thing to "make an addon": you write normal Godot code, EventForge reflects over it.

### Requirements

- The script must be **instantiable**: the editor calls `script.new()` to reflect over it, so an
  abstract or non-compiling script is skipped silently. `@tool` is *not* required - the bundled
  behavior packs ship without it - but add it when the script's own code should also run in the
  editor.
- Give it a `class_name`. The class name becomes the `provider_id`. Without one, the filename is used
  (PascalCased), which can collide with another script.

### How members map to ACEs

| Member | Becomes | Generated ace_id |
|--------|---------|------------------|
| A `signal` | a **Trigger** (`On <Signal Name>`) | `signal:<name>` |
| A method returning `bool` | a **Condition** | `method:<name>` |
| A `void` method (no return value) | an **Action** | `method:<name>` |
| A method returning a value (`int`, `String`, `Vector2`, ...) | an **Expression** | `method:<name>` |
| An `@export var` | an **Expression** that reads it | `property:<name>` |
| The same `@export var` | a **Set** action | `set:<name>` |
| The same `@export var` (if `int`/`float`) | **Add** and **Subtract** actions | `add:<name>`, `subtract:<name>` |

Method and signal names are humanized for display: `take_damage` becomes `Take Damage`, the `is_`
prefix is stripped for conditions (`is_dead` becomes `Dead`), and `get_` is stripped for expressions.

Two filtering rules to know: methods starting with an underscore are skipped, and `@export` is
required for a variable to surface (a bare `var` is invisible to reflection).

Property ACEs compile to real assignments: on a **Node** provider they write through the behavior
node with a retargetable "On node" param (`{target}.score = {value}`, default `$<Class>`), so Set
Score changes the node actually in your scene; on a `RefCounted`/`Resource` utility provider they
write through the same owned instance the methods call.

### `@ace_expose_all`: node-targeted in one line

By default the generated call is **instance-backed** - `__eventsheet_provider_<Class>.method(...)`
against an owned `Class.new()` the sheet creates. That is exactly right for a stateless `RefCounted`
helper (scoring math, an inventory, a dice roller): drop the script in, call its methods, done.

For a **Node behavior** you attach to a node - where the ACE should act on *that node*
(`$Enemy/Health.heal()`) and be retargetable per use - add **one class-level line** at the top of the
script and skip the per-method annotations entirely:

```gdscript
## @ace_expose_all(node)
class_name Health
extends Node

func heal(amount: int) -> void: ...   # -> "Heal" action, node-targeted
func is_alive() -> bool: ...           # -> "Is Alive" condition
signal died                           # -> "On Died" trigger
```

Every method now compiles to the **node-targeted** form `{target}.method(args)` with an **"On node"**
field defaulting to `$Health` - pick or type any node path to retarget it (Godot's `$`-autocomplete,
the Construct "act on the object you picked" model). No `@ace_codegen_template`, `@ace_condition`, or
`@ace_name` per method - reflection derives type, name, and the call.

Plain `## @ace_expose_all` (no `node`) is the explicit "treat me as a provider, expose everything"
marker that keeps the instance-backed default - best for stateless `RefCounted` helpers. Either way,
per-member `@ace_*` annotations still override the auto-derived value for that one member, so you only
annotate the exceptions (a custom name the humanizer can't guess, a dropdown, a description).

> Place the marker **before** `class_name`/`extends` (it is a class-level directive). `_`-prefixed and
> inherited engine members never surface, so even a big class stays a single tidy picker group.

### Every node speaks EventSheet (reflected vocabulary)

You do not need a provider script at all to drive a class: the picker's
**"All of <your host class>"** section reflects the sheet's own class straight from the
running engine - its methods become Actions (void), Conditions (bool returns), and
Expressions (other returns), its editor properties become Set/Get pairs, and its signals
become triggers. This works for EVERY Godot class (including ones future Godot versions
add) and for your own `class_name` scripts. Reflected rows emit the same plain
`member(...)` calls the curated vocabulary emits, curated vocabulary always wins over its
reflected twins, and Simple Mode hides the section (it is the expert deep end). Provider
scripts remain the way to CURATE a vocabulary: friendly names, categories, dropdowns,
custom templates.

### Write less: prose descriptions and pack-wide defaults

Three shortcuts keep annotation blocks short (all additive - every long form below still works):

- **Your doc comment IS the description.** Plain `##` prose directly above a member becomes the
  ACE's tooltip text, so a normal GDScript doc comment is enough. `@ace_description` is only
  needed when the picker text should differ from the code documentation.
- **Class-level `@ace_category` / `@ace_icon` default the whole pack.** Put them above
  `class_name` (next to `@ace_expose_all`) and every member without its own category or icon
  inherits them. Precedence, most specific first: member annotation > class-level default >
  the automatic per-kind fallback.
- **Typos warn instead of vanishing.** An unrecognized `@ace_*` token (say `@ace_categry`)
  prints a warning naming the script and the token; it never silently changes behavior.
- **Well-known parameter names pick their own widget.** With no hint annotation at all, a
  param named `color`/`*_color` gets the color picker, `anim`/`*_anim`/`*_animation` the
  animation picker, `*_signal`/`signal_name` the signal picker, `*_scene`/`scene_path` the
  scene picker, and `*_audio`/`audio_path` the audio picker. Any explicit hint wins.

```gdscript
@tool
## A weapon helper.
## @ace_category("Weapons")
class_name WeaponHelper
extends Node


## Fires the weapon once.
func fire() -> void:
	pass
```

That is a complete, fully-described, categorized action: two doc lines and the func.

### Prefer autocomplete? The typed registrar

Comments cannot autocomplete in the script editor - real code can. A provider may declare a
static hook instead of (or alongside) comment annotations:

```gdscript
static func _eventforge_register(reg: EventForgeRegistrar) -> void:
	reg.pack_category("Health")
	reg.action("heal").name("Heal") \
		.description("Restores health by an amount.") \
		.template("health += {amount}") \
		.param("amount", {"hint": EventForgeRegistrar.EXPRESSION})
```

Every method is typed, so the editor completes the whole vocabulary, hints argument types,
and a typo is a compile error instead of an ignored comment. Registrar calls annotate
EXISTING members (they do not create members) and merge onto comment annotations field by
field - explicit registrar calls win, and both dialects produce identical definitions
(test-pinned). The member methods are `action` / `condition` / `expression` / `trigger` /
`property` / `member` (no forced type); each returns a chainable builder with `name`,
`category`, `description`, `icon`, `template`, `display`, `hidden`, `deprecated`, and
`param(name, {"hint": ..., "options": [...], "autocomplete": [...], "desc": ...})`.
Pack-level: `pack_category`, `pack_icon`, `tags`.

Two more ways to skip typing the dialect from memory:

- **Right-click any ACE in the picker** - "Copy annotation stub" / "Copy registrar snippet"
  puts a paste-ready, fully-annotated stub for that exact ACE on the clipboard.
- **The New Script dialog** offers an "EventForge ACE Provider" template (from
  `script_templates/`) whose skeleton walks the terse dialect.

### Annotations: refine the automatic mapping

![An @ace_looping condition applied as a pick filter: the loop lane on the left and the per-item actions under it](images/looping-condition.png)

Put `##` doc-comment lines with `@ace_*` directives directly above a member to override what
reflection chooses. Annotations are case-sensitive and the content can be parenthesized or
space-separated (`@ace_category(Combat)` and `@ace_category Combat` both work).

The same annotations also curate the ƒx dictionary's **Self ▸ Behaviours** group - the section a
user sees when they type `self` in an expression field with your behaviour attached. Your exported
variables list there as knobs (`$YourPack.knob_name`), and a value-returning public method lists
when it carries `@ace_expression` or the pack declares `@ace_expose_all`; `@ace_hidden` and
`@ace_internal` exclude a member from it exactly as they do from the picker. This derivation is
SCRIPT-level (property list, method list, and these comments read from the file), so it works the
same whether or not your script is `@tool`.

| Annotation | Effect |
|------------|--------|
| `@ace_hidden` | Hide this member from the picker entirely. |
| `@ace_featured` | Highlight this member as an everyday row: bold, floated to the top of its picker category. Reserve it for your pack's hero rows - featuring everything features nothing. |
| `@ace_name(Text)` | Override the display name. |
| `@ace_category(Text)` | Put the ACE in this picker category. |
| `@ace_description(Text)` | The tooltip and help text. |
| `@ace_action` / `@ace_condition` / `@ace_expression` / `@ace_trigger` | Force the ACE type instead of inferring it from the return type. |
| `@ace_looping(iterator)` | A LOOPING condition: the method returns a collection (an Array of ids, nodes, anything iterable) and adding it to an event loops that event's actions once per item - your pack owns its own "For Each X" condition. The value names the loop variable actions read (`item` if omitted). Applies as a pick filter, so the loop lane, frame-spreading, and round-trip all work like a built-in For Each. |
| `@ace_codegen_template(code)` | Replace the auto-generated call with your own GDScript (you own the whole template then). |
| `@ace_display_template(text)` | Override the row/picker phrasing; `{param_id}` slots substitute live values. Substituted values draw **bold** automatically (the C3 emphasis), so you rarely need styling - but the template may carry BBCode-lite (`[b]`, `[i]`, `[color=...]`) for custom emphasis, which then supersedes the automatic one (typed value tints still apply). The bundled vocabulary uses the house grammar - `[b]` around value slots, `[i]` around node/object slots ("add `[i]{target}[/i]` to `[b]{group}[/b]`") - and the Health pack's authored sentences ("Heal `[b]{amount}[/b]` HP") show the pack-side pattern. Translation-safe: a marked template that misses the catalog retries its STRIPPED sentence as the key, so a locale translated before you added styling keeps its translation (shown plain, still auto-bolded). A user's literal `[b]` inside a param value is always data, never styling. |
| `@ace_param(name, hint: h, default: v, options: a\|b, autocomplete: a\|b, desc: "text")` | Everything about one parameter in a single line: widget hint, the value the row shows the moment it is dropped, a fixed dropdown, editable suggestions, and a description. Options and suggestions split on `\|`; quote a desc that contains commas. See the [param grammar](#the-param-grammar-defaults-labels-and-comparison) below for `default:`, labeled options, and `hint: comparison`. |
| `@ace_param_hint(param_name hint)` | Set a parameter's widget (see the [hint table](#parameter-hints-the-widget-vocabulary)). |
| `@ace_param_options(param_name a,b,c)` | Give a parameter a fixed dropdown. Entries may be labeled `value=Label` (`@ace_param_options(mode fit=Fit to screen, fill=Fill)`), so the menu reads as English while the row inserts the value. |
| `@ace_param_autocomplete(param_name a,b,c)` | Give a parameter an editable suggestion list. |
| `@ace_lift_example("line")` | A line this verb is written as **by hand**, so an opened script that calls your pack reads as your row instead of as a generic method call. Write the line as a person writes it and mark the value spans - `@ace_lift_example("[[target|node: $LightFlickerBehavior]].start_flickering([[after_seconds|argument: 0.5]])")`. Repeat it for each spelling (one with the argument, one without). See [Teaching the reader your spellings](#teaching-the-reader-your-spellings). |
| `@ace_icon(name)` | Set a picker icon. |
| `@ace_tags(a,b)` | Add search tags. |
| `@ace_requires(a, b)` (class-level) | Declare what the pack needs installed: bare class names (`StatSheetResource`), `autoload:Name`, or `pack:folder_name`. The Project Doctor warns when an in-use pack's requirement is missing - the finding is clickable and opens the pack. Sheet-built packs set it via the sheet's `addon_requires` field. |
| `@ace_version(1.0.0)` / `@ace_author("Name")` / `@ace_help("https://...")` (class-level) | Pack identity metadata: the version joins the Addon Pack banner chip ("Addon Pack v1.0.0") and feeds future update tooling; author and help link document who made it and where its docs live. Sheet-built packs set them via `addon_version` / `addon_author` / `addon_help_url`; every bundled pack ships versioned. Don't hand-edit the version when you ship an update - **Sheet > Publish New Version…** bumps it Patch / Minor / Major and records your one-line change note as a doc comment beneath it, so the file accumulates its own changelog. |
| `@ace_source("https://...")` (class-level) | Where this pack publishes from. The Addon manager's **Update** button and **Check for updates** have nowhere to look without it; a pack that names none simply says so. |
| `@ace_inline_capable` (class-level) | Says this pack's shape can be written into an ordinary script rather than attached as a node. It is what makes "written into this script" selectable in the **Add behavior…** dialog: the pack's knobs become the script's own exported variables. Say it only for a small, self-contained shape (a cooldown, a wrap, a pin) - anything with its own per-frame work belongs in a node. |

### Teaching the reader your spellings

Somebody used your pack before they used the sheet. Their `_ready` says `flicker.start_flickering()`,
and opening that file reads it the way every unclaimed method call reads: "call start_flickering on
flicker". That is honest, and it is the floor. `@ace_lift_example` raises it - you say which lines
your verbs are written as, and those rows become your verbs, with your names and your parameters.

![The same hand-written file read twice: as generic calls, and as the pack's own verbs once it teaches its spellings](images/pack-taught-spellings.png)

Write the example as a line, not as a pattern. The value spans are marked `[[name: text]]`, or
`[[name|fragment: text]]` to say which kind of value it is (`node`, `name`, `literal`, `word`,
`argument`, `expression`); the text inside is what a real line would have there, and it doubles as
the sample the gate tests the entry with. A `node` span is the receiver in front of the call, written
without its dot. Two spellings are two examples - one with the argument, one without - because a
choice is the thing an example cannot check.

A `node` span claims the three ways a row addresses a node: `$Path`, `%Unique` and
`get_node("Path")`. It deliberately does not claim a bare variable - `flicker.start_flickering()` -
because a bare name matches every receiver in the language, and a pack claiming its verb on all of
them would take lines away from readings that already say more about them. Those lines keep the
generic call reading, which is the floor and is honest. (The grammar has a wider `receiver` word for
the recogniser families inside the plugin, which pair it with a second check; an annotation has
nowhere to write one, so a pack example asking for it is refused by name.)

Three rules hold you to it, and all three are enforced rather than advised:

- **The bytes never move.** The line the author wrote is stored on the row, so saving writes their
  file back exactly. Landing a table late upgrades the words and nothing else.
- **An example that cannot work fails the build.** Every entry generates its own line, has to be
  claimed by itself, and has to re-emit byte for byte; an example above no verb, on a condition
  rather than an action, or asking for a receiver wider than the three node spellings, is refused by
  name.
- **You may not shadow a built-in spelling**, and where two packs spell one line the Project Doctor
  says so: the pack first in folder order claims it.

### The param grammar: defaults, labels, and comparison

`@ace_param` shapes one parameter completely, and three of its keys decide how a row reads the moment
it is dropped:

```gdscript
## @ace_param(seconds, default: 1.0, desc: "How long the shield holds.")
## @ace_param(quality, options: low=Potato|med=Balanced|high=Ultra, default: med)
## @ace_param(op, hint: comparison)
func hold_shield(seconds: float, quality: String, op: String) -> void:
	pass
```

- **`default:`** is what the row shows on drop. Resolution runs most-explicit-first: this annotation,
  then the method's own GDScript default (`func fire(power: float = 25.0)` already lands reading
  25.0), then the type's zero - so a parameter whose sensible value is `1.0` but has neither reads
  `0.0` and quietly does nothing until someone notices. A quoted default has its quote pair stripped,
  so write `default: "walk"` for a String.
- **`options:`** entries may be `value=Label`: the dropdown READS the label and INSERTS the value.
  Entries split on `|` here (so commas stay free for prose); `@ace_param_options` splits on `,`
  instead. A key that itself contains `=` ships quoted - `"<="=at most` - because the split is on the
  first `=`.
- **`hint: comparison`** is the whole operator dropdown in one word: `==`, `!=`, `<`, `<=`, `>`, `>=`,
  each labeled in plain English ("`>=` (at least)"), seeded to `==` so the row is a complete sentence
  with nothing typed. It only SEEDS the list, so an explicit `options:` on the same param still wins.
  It resolves to the same canonical list the built-in Compare conditions use, which is why a pack
  never has to smuggle operators through as word tokens.

The same three shapes are available from code. `EventSheets.param_spec(config)` normalizes one param
or Custom Block field the same way - `default` and `default_value` are interchangeable, `options`
accepts a plain list, a `{value: label}` dictionary or ready-made pairs, and `hint: "comparison"`
expands to the seeded operator dropdown. `simple_ace()` and `simple_block_kind()` run every param
through it, and `EventSheets.combo_options(source)` / `EventSheets.comparison_options(equal_token)`
build the pair lists on their own.

### A complete Path 1 example

<!-- no-figure -->
```gdscript
@tool
extends Node
class_name Player

## @ace_category Combat
signal died

@export var health: int = 100

## @ace_category Combat
## @ace_description Reduce health and emit died at zero.
func take_damage(amount: int) -> void:
    health -= amount
    if health <= 0:
        died.emit()

## @ace_param_options(slot head,chest,legs)
func equip(slot: String) -> void:
    pass

func is_dead() -> bool:   # bool return -> Condition
    return health <= 0

## @ace_hidden
func _internal_recalc() -> void:   # underscore + hidden: never shows
    pass
```

This single file exposes: **On Died** (trigger), **Health** (expression) plus **Set / Add / Subtract
Health** (actions), **Take Damage** (action, Combat), **Equip** (action, with a `head/chest/legs`
dropdown), and **Is Dead** (condition). `_internal_recalc` stays private.

### Registering Path 1 providers

- **Per sheet:** `editor.add_ace_provider_script("res://scripts/player.gd")`. The path is stored on the
  sheet (`EventSheetResource.ace_provider_scripts`) and de-duplicates on add. Remove it with
  `remove_ace_provider_script`.
- **Project-wide by convention:** any `*.gd` in `res://eventsheet_addons/` is scanned automatically.
- **From the editor:** **Sheet > Custom Actions...** browses to a script and previews it before
  anything is registered (see below).

### The provider wizard: preview, curate, keep old names

**Sheet > Custom Actions...** opens the **Custom ACE Providers** window, the in-editor front end for
everything above. Browsing to a `.gd` (press **Add...**) runs the same generation the registry runs, so
its **What it publishes** table is what you will actually get: one row per entry, with **Publish**,
**Kind**, **Name**, **Category**, **Parameters**, and the exact code it **Emits**. Browsing previews
only - **Register This Script** is a second, deliberate click, so nothing joins the vocabulary unseen.

The table is also an editing surface, which matters because raw reflection guesses from the signature
and most hand-written game code is untyped (a `func is_wave_active():` with no `-> bool` reads as an
Action). Correct it in place, then press one of:

- **Curate Script...** writes your differences into the file as `## @ace_*` comment lines - exactly the
  dialect this guide documents, so you can reopen and adjust later, and a teammate reading the script
  sees why it publishes what it does. A diff of the lines each member will gain is shown first; only
  `##` comments above a declaration are added or removed (never a signature or a body, which is why a
  wrong KIND is fixed with `@ace_condition` rather than by editing someone's function), the file is
  backed up first (**Tools > Sheet Backups**), and re-applying the same edits is a no-op.
- **Parameters...** shapes the selected member's inputs - a hint (including `comparison`), labeled
  `value=Label` options, and the starting value the row shows on drop. It records the spec; the next
  Curate Script writes it as `@ace_param(id, hint: ..., options: ..., default: ...)`.
- **Keep Old Name...** is the fix for a member you RENAMED. A rename changes the ace_id and orphans every
  row that used it, silently: the compiler prefers the template baked onto the row, so the sheet still
  emits the old call, compiles clean, and fails when the player triggers it. Select the member under its
  new name, type what it used to be called, and a deprecated forwarding shim of the old name is
  appended - existing rows resolve again, while the old name stays out of the picker. Nothing existing
  is edited. (The Project Doctor's **orphaned-verb** check reports the same failure across the project
  when it has already happened.)

---

## 6. Path 2: Custom Descriptors (the EventForge Bridge)

When you want exact control over the generated code, the category, and the widgets, but you are not
editing the plugin, register descriptors through an autoload called **EventForgeBridge**. The editor
asks that autoload for `get_all_descriptors()` and folds the result into the vocabulary.

### Set up the bridge

Add an autoload named exactly `EventForgeBridge` (Project Settings, Autoload) pointing at a `Node`
script that returns descriptors:

```gdscript
@tool
extends Node

func get_all_descriptors() -> Array:
    return [
        {
            "provider_id": "MyPlugin",
            "ace_id": "ShakeCamera",
            "display_name": "Shake Camera",
            "ace_type": "action",              # string is safest (see the enum note below)
            "category": "Camera",
            "description": "Shake the active camera for a moment.",
            "codegen_template": "get_viewport().get_camera_2d().offset = Vector2(randf_range(-{strength}, {strength}), 0)",
            "display_text": "shake camera by {strength}",
            "params": [
                { "id": "strength", "type_name": "float", "default_value": "8.0",
                  "display_name": "Strength", "hint": "expression" }
            ]
        }
    ]
```

`get_all_descriptors()` may return a mix of plain Dictionaries (as above) and `ACEDescriptor` objects
built with the factory. Dictionaries are the easy, language-neutral form.

### The Dictionary shape

Keys may be `snake_case` or `camelCase` (snake_case wins if both are present). Everything except the
identity has a sensible default.

| Key | Meaning | Default |
|-----|---------|---------|
| `provider_id` | Your namespace. | `"Custom"` |
| `ace_id` (or `id`) | Unique id within the provider. | required |
| `display_name` (or `name`) | Picker label. | required |
| `ace_type` (or `type`) | `"action"`, `"condition"`, `"expression"`, `"trigger"`, or an enum name. | `"action"` |
| `category` | Picker category. | `"Custom ACEs"` |
| `description` (or `desc`) | Tooltip and help text. | `""` |
| `codegen_template` | The GDScript to emit. | required for it to compile |
| `display_text` | Picker row phrasing with `{param}` placeholders. | falls back to `display_name` |
| `signal_name` | The signal to connect (Triggers only). | `""` |
| `node_type` | Scope the ACE under a Godot class section. | `""` |
| `params` | Array of parameter Dictionaries (see [Parameter Reference](#10-parameter-reference)). | `[]` |

> **Enum note.** If you pass `ace_type` as a string, EventForge maps it for you and you cannot get the
> value wrong. Avoid passing a raw integer: the descriptor enum and the editor enum use different
> integer orders, so the number that means "Action" in one is not the same in the other. Use the
> string `"action"` (Path 2) or the name `ACEDescriptor.ACEType.ACTION` (Path 3).

### When does the bridge run?

The editor reads the bridge while it builds the vocabulary for the picker and the compiler, so your
ACEs are available the whole time you author and compile. The bridge is an editor-time source of
vocabulary; it is not consulted by your shipped game (the game just runs the compiled GDScript).

---

## 7. Path 3: Built-in Modules

This is how every shipped ACE is authored, and the path to use if you are contributing vocabulary into
EventForge itself. A **module** is one file under `addons/eventforge/registration/modules/` that
exposes `static func get_descriptors() -> Array[ACEDescriptor]`, built with the factory.

<!-- no-figure -->
```gdscript
# addons/eventforge/registration/modules/my_aces.gd
@tool
extends RefCounted
class_name EventForgeMyACEs

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

static func get_descriptors() -> Array[ACEDescriptor]:
    var descriptors: Array[ACEDescriptor] = []
    descriptors.append(F.make_descriptor(
        "Core", "SetHealth", "Set Health",
        ACEDescriptor.ACEType.ACTION,
        "{target}.health = {amount}",
        "",                                       # signal_name (empty for non-triggers)
        [
            F.make_param("target", "String", "self", "Target", "Node to modify.", "expression"),
            F.make_param("amount", "int", "100", "Amount", "New health value.", "expression"),
        ],
        "Health",                                 # category
        "set {target} health to {amount}"         # display_text
    ))
    return descriptors
```

That is all there is to it. The module is **auto-discovered**: `builtin_aces.gd` scans
`registration/modules/` and registers any file that exposes `get_descriptors()`, so there is no list
to edit. Files load in a stable sorted order with the generic `helper_aces` module kept last (its
catch-all templates must come after specific ACEs for the reverse-lifter), so just keep your own
templates specific and you are fine.

(If you also add a test, the runner auto-discovers it too: any `tests/*.gd` exposing
`static func run() -> bool` is found and run automatically, so there is nothing to register there
either. Drop the module and its test; that is all.)

---

## 8. The codegen_template Language

The template is the heart of a custom ACE. It is a small substitution language over GDScript.

### Parameter substitution: `{param_id}`

Each `{param_id}` is replaced with that parameter's value, verbatim. Values are **opaque**: they are
spliced in exactly as typed and never re-scanned, so a value that itself contains braces is left
alone. There is a single left-to-right pass; you are responsible for the value being valid GDScript.

```gdscript
# template: {var_name} = {value}
# params:   var_name = "score", value = "10"
# emits:    score = 10
```

An unknown `{key}` (a typo, or a placeholder with no matching param) is left as literal text rather
than erroring. That keeps old templates forward-compatible, but it also means a mistyped param name is
a silent bug, not a compile error. Spell them carefully.

### Per-instance locals: `{uid}`

If a template declares a local variable, name it with `{uid}` so two copies of the ACE in one event
do not collide. The `{uid}` token is replaced with a fresh unique value when you apply the ACE in the
dock (not at compile time), so every instance gets its own local.

```gdscript
# A multi-line ACTION that opens, writes, and closes a file safely:
"var __file_{uid} = FileAccess.open({path}, FileAccess.WRITE)\nif __file_{uid}:\n\t__file_{uid}.store_string({text})\n\t__file_{uid}.close()"
```

Two rules for multi-line templates: separate lines with `\n` inside the string (not real line breaks
in the module file), and indent nested lines with a tab `\t` (the compiler emits tabs; spaces will
break the generated code). And if you store a handle in a local, close or free it, because the local
lives for the whole function and will not auto-close like a temporary would.

### The optional-comma idiom: `{, args}`

`{, args}` emits `, ` followed by the value only when the value is non-empty. It is for trailing
optional arguments.

```gdscript
# template: emit_signal(&{signal_name}{, args})
# args = ""        -> emit_signal(&"jumped")
# args = "10, 20"  -> emit_signal(&"jumped", 10, 20)
```

Note that `{, args}` drops only when the value is the empty string. A value of `"0"` or `"false"`
still emits the comma. Optional-comma segments do not reverse-lift, so avoid them if a perfect import
round-trip matters to you.

### The optional-prefix idiom: `{target.}`

`{target.}` (note the dot INSIDE the braces) emits the value followed by a `.` only when the value is
non-empty, otherwise nothing. It is how a host-scoped operation becomes optionally retargetable to
another node.

```gdscript
# template: {target.}play(&{anim})
# target = ""        -> play(&"walk")            # acts on the host
# target = "$Enemy"  -> $Enemy.play(&"walk")     # acts on another node
```

Every built-in node-scoped ACE (one that declares a `node_type`) is given this prefix and an optional
"On node" `target` param automatically, so you rarely write it by hand - but it is available for your
own templates. A blank target compiles to the original host call byte-for-byte, so adding it never
changes existing output. The dot lives inside the braces precisely so it cannot collide with the
ordinary `{target}.member` pattern (dot outside). Unlike `{, args}`, the optional-prefix idiom **does**
reverse-lift: the importer matches both the blank-target (`play(...)`) and set-target
(`$Enemy.play(...)`) shapes back to your ACE.

### What the template means per type

| ace_type | The template is | Example |
|----------|------------------|---------|
| **Action** | a statement | `{target}.queue_free()` |
| **Condition** | a boolean expression (used inside `if (...)`) | `{target}.is_on_floor()` |
| **Expression** | a value, inlined wherever an expression is allowed | `FileAccess.get_file_as_string({path})` |
| **Trigger** | empty: the `signal_name` field names the signal to connect | `signal_name = "timeout"` |

A Trigger has no `codegen_template`. The compiler reads `signal_name` and wires the connection in
`_ready()`. Set `node_type` to scope the trigger under a Godot class (for example a `Timer`).

### Stateful conditions

A condition that needs per-instance memory (a timer, a latch) declares it with the fluent
`.stateful(member, prelude, on_true)` chain: `member` is a class member the compiler synthesizes per
applied instance, `prelude` runs every tick before the if, `on_true` just inside it. The canonical
example is `Every X Seconds`:

```gdscript
descriptors.append(F.make_descriptor("Core", "EveryXSeconds", "Every X Seconds",
    ACEDescriptor.ACEType.CONDITION,
    "__every_{uid} >= maxf({seconds}, 0.001)", "",
    [F.make_param("seconds", "float", "1.0", "Seconds", "Interval.", "expression")],
    "Time", "Every {seconds} seconds")
    .stateful(
        "var __every_{uid}: float = 0.0",                        # a class member, per instance
        "__every_{uid} += delta",                                # runs every frame, before the if
        "__every_{uid} = fmod(__every_{uid}, maxf({seconds}, 0.001))"))  # resets on fire
```

All three receive the same `{uid}` and `{param}` substitutions ({uid} is baked fresh per applied
instance, so two rows never share state). Stateful conditions only make sense inside per-frame
triggers (Every Frame, On Physics Process) where `delta` exists; the compiler does not stop you from
using one elsewhere, so do not.

The prelude and on-true must each be a SINGLE statement (they are emitted as one indented line inside
the trigger's function). The member sits at class level, so it MAY span several lines - which lets a
condition ship a small helper function beside its state var. **Edge gates** (Trigger Once style
conditions whose state test asks "was I reached last tick?") add `.evaluated_last()`: the compiler
then HOISTS the term to the end of the emitted `and` chain no matter which condition cell it occupies
(an OR row is parenthesized first, `(a or b) and __trigger_once_x()`), so users can place it anywhere.
The built-in **Trigger Once** is declared exactly this way - your pack can make its own:

```gdscript
descriptors.append(F.make_descriptor("MyPack", "OnceGate", "Once Gate",
    ACEDescriptor.ACEType.CONDITION, "__once_gate_{uid}()", "", [], "Custom", "Once gate")
    .stateful("var __gate_{uid}: int = 1\n\nfunc __once_gate_{uid}() -> bool:\n\tvar gap: int = __gate_{uid}\n\t__gate_{uid} = 0\n\treturn gap > 1",
        "__gate_{uid} += 1")     # age the counter every tick; the helper zeroes it when reached
    .evaluated_last())
```

Why that works: conditions compile to a short-circuiting `and` chain, and `.evaluated_last()` guarantees
the term is reached exactly when every other condition is true. "Was I reached on the previous tick?"
therefore answers "were the other conditions already true then?" - a gap wider than one tick is the
rising edge. Note a stateful condition can never be inverted (its state would advance on the ticks it
does not fire); the compiler warns if you try.

---

## 9. Descriptor Reference

`make_descriptor(provider_id, ace_id, display_name, ace_type, codegen_template, signal_name = "", params = [], category = "", display_text = "", node_type = "")`

| Argument | Type | Required | Meaning |
|----------|------|----------|---------|
| `provider_id` | String | yes | The namespace. `Core` for built-ins; your own for custom. |
| `ace_id` | String | yes | Unique id within the provider. `provider_id::ace_id` is the global key. |
| `display_name` | String | yes | The picker label. |
| `ace_type` | enum | yes | `ACEDescriptor.ACEType.ACTION` / `.CONDITION` / `.EXPRESSION` / `.TRIGGER`. |
| `codegen_template` | String | yes (except Trigger) | The GDScript to emit, with `{param}` placeholders. |
| `signal_name` | String | Triggers only | The signal to connect. Empty for the other types. |
| `params` | Array of ACEParam | no | The input fields (see below). |
| `category` | String | no | Picker category. Use `Parent: Sub` to nest one level. |
| `display_text` | String | no | Picker row phrasing with `{param}` placeholders. Falls back to `display_name`. |
| `node_type` | String | no | When set, groups the ACE under that Godot class instead of the category. |

The `ACEType` enum (use the **name**, not a number): `ACTION`, `CONDITION`, `EXPRESSION`, `TRIGGER`.
Two enums exist with different integer orders (`ACEDescriptor.ACEType` for authoring, `ACEDefinition`
for the editor), which is exactly why you should always write the name or, on the bridge, the string.

---

## 10. Parameter Reference

`make_param(param_id, type_name, default_value = "", display_name = "", description = "", hint = "", options = [], autocomplete = [])`

| Argument | Type | Meaning |
|----------|------|---------|
| `param_id` | String | Unique within the ACE; becomes the `{param_id}` placeholder. Must be a valid identifier. |
| `type_name` | String | The value type (see table below). Drives type-aware features like variable filtering. |
| `default_value` | Variant | The value used when the field is left empty. Quote string literals: `"\"res://x.ogg\""`. |
| `display_name` | String | The field label. Falls back to `param_id`. |
| `description` | String | Tooltip and help text under the field. Strongly recommended. |
| `hint` | String | The widget to show (see hint table). Empty means a plain field. |
| `options` | Array | A **fixed** dropdown: the user can only pick from these. Entries are either plain strings or `{"key": <inserted>, "label": <shown>}` pairs, so the menu can read "Fill the screen" while the row inserts `fill`. |
| `autocomplete` | Array[String] | An **editable** suggestion list: the user can type anything or pick. |

If both `options` and `autocomplete` are set, `autocomplete` wins; use one or the other.

### Parameter type names

| `type_name` | Godot type |
|-------------|------------|
| `bool` / `boolean` | bool |
| `int` / `integer` | int |
| `float` / `double` | float |
| `String` / `string` | String |
| `NodePath` / `node_path` | NodePath |
| `Vector2` | Vector2 |
| `Vector3` | Vector3 |
| `Color` | Color |
| `Variant` | Any (untyped) |

Anything unrecognized falls back to `String`. Note that most built-in ACEs use `type_name = "String"`
even for numbers, because the value is an **expression** spliced into the template (the literal `10`
or `Vector2(0, 0)` is just text in the generated code).

### Parameter hints: the widget vocabulary

The `hint` chooses the input widget in the parameter dialog. `expression` is by far the most common.

A hint also owns the paragraph the dialog's help strip says about that field, under the parameter's
own `description` - what this kind of box takes and how to answer it. The bundled hints are described
already; a hint your own pack invents (with `EventSheets.register_param_editor`) is described with
`EventSheets.register_param_help(hint, paragraph)`, or the strip is generic on the very field that
needed explaining.

| Hint | Widget shown | Use for |
|------|--------------|---------|
| *(empty)* | Plain text field (or a dropdown if `options` is set) | Literals and fixed dropdowns. An option written as `{"key": …, "label": …, "note": …}` gets that note as the line reading under the choice in the dialog. |
| `expression` | Text field with an `ƒx` button (Find Expressions - the floating Expressions dictionary; the same expressions also autocomplete as you type) | Any GDScript value or expression. The default choice. |
| `variable_reference` | Dropdown of sheet variables | A sheet variable name. |
| `variable_reference:Array` (or `:Dictionary`, etc.) | Dropdown filtered to that variable type | A typed variable; only matching (or Variant) variables show. |
| `color` | ColorPickerButton | A `Color`. |
| `angle` | Text field, with the UNIT settled when the value is committed | An angle. A plain number is DEGREES - there is no unit to pick, because the unit is already in what was typed. Radians are not locked out: `PI/4`, or a value with the unit said out loud (`1.2 rad`), keeps what the author meant and gets exactly the one conversion that makes it true, and the ROW always shows which unit it ended up meaning. A per-project setting (`eventsheets/angles/default_unit`) flips what a bare number means, for teams that think in radians; it changes what is WRITTEN after that and never re-reads a value already stored. Write the template as the call it is (`deg_to_rad({angle})`) and the field does the rest. |
| `key_capture` | Press-a-key modal | A keyboard key (records the key you press). |
| `input_action` | Editable picker of the project's Input Map actions (enumerated live at dialog-open, project actions first) | An existing input action, as a quoted literal. |
| `group_reference` | Editable picker of the node groups that actually exist (project globals + the edited scene's groups) | A node group name, as a quoted literal. |
| `scene_node` | Editable picker of the tree in the layout that is OPEN, offered in the spellings a row writes: `self` first, then `%Unique` for the scene-unique nodes, then `$Path` for the rest (a name with a space in it comes quoted, `$"Health Bar"`). Enumerated when the dialog builds, never baked into the descriptor, so a node added a minute ago is in the list. | A node in the current scene. With no scene open there are no choices at all and the param is the ordinary text field it was, so an expression, a variable or a node that only exists at runtime stays typeable. The Nodes: Hierarchy rows use it. |
| `bbcode_text` | Discord-style rich-text field: select text and hit B / I / U / S (or Ctrl+B/I/U, Ctrl+Shift+S) to wrap it in the matching BBCode tag - toggles off when already wrapped - with a live rendered preview underneath | A BBCode string (Print Rich uses it). |
| `physics_layer_2d` / `physics_layer_3d` | Checkable list of the project's physics layers - NAMED layers (Project Settings > Layer Names) show their names, and the button reads the selection back ("Walls, Enemies") | A collision mask int. Params named `collision_mask` / `*_mask` (2D) or `*_mask_3d` (3D) get this picker by convention, no annotation needed. |
| `audio_path` | Text field with a `▶` preview button | An audio file path. |
| `scene_path` | Text field with a Browse button | A `.tscn` path. |
| `animation_reference` | Editable field completing from the animations the ATTACHED SCENE really has - an AnimationPlayer's clips and an AnimatedSprite's flipbooks, grouped by the node that declares each one and labelled with how long it runs or that it loops. A name the scene has never heard of turns the field amber with the nearest real one offered as the fix. | An animation name, as a quoted literal. A name built while the game runs is still typeable, so a free-string row keeps working. |
| `marker_reference` | Editable field completing from the named markers on the timeline of the animation the row's own `animation` field names - what a keyframed clip has instead of frames. | A marker name, as a quoted literal. |
| `animation_frame` | Number field with the animation's own FILMSTRIP under it: one cell per frame, numbered from 0, showing that frame's picture, the chosen one lit; hovering a cell shows it large and the arrow keys step one frame. A long strip scrolls. Built only for a flipbook - a keyframed clip has no frames, and the field is then the plain number box. | A frame index. |
| `signal_reference` (or `signal_reference:quoted`) | Dropdown of host and sheet signals | A signal name. `:quoted` stores it as a `"name"` literal. |
| `method_reference` | Autocomplete of the host's public methods | A method name. |
| `property_reference` | Autocomplete of the host's public properties | A property name. |
| `enum:EnumName` | Dropdown of that sheet enum's members | A sheet enum member. |

![The Add Child (existing node) parameter dialog with the Child field's picker open, listing the nodes of the layout currently open in the editor: self first, then the scene-unique %Score, then $Player, $UI and $UI/Score](images/scene-node-param-picker.png)

Factory helpers cover the common dropdowns, so nobody re-types them: `F.COMPARISON_OPTIONS` is the
canonical labeled operator list (`==` reads "=  equal to", `>=` reads "≥  at least", with the GDScript
form shown muted beside the choice in every dialog), and
`F.comparison_options(equal_token)` returns the same six with the equality token swapped for a runtime
that stores a single `=`. `F.COMPARISON_OPERATORS` is the same six as bare tokens for callers that
only need the values, and `F.input_action_options()` is every InputMap action plus the `ui_*`
defaults. On a provider script, `@ace_param(op, hint: comparison)` is the one-word form of the same
list.

---

## 11. The Picker: Categories, Node Types, Simple Mode

- **Categories** group ACEs in the picker. A category of `Files: Directories` nests a `Directories`
  folder inside a `Files` folder (the separator is `": "`). Keep related ACEs under one parent.
- **node_type** scopes an ACE under a Godot class section (for example `CharacterBody2D`) instead of
  a plain category. Use it for ACEs that only make sense on a specific node type.
- **display_text** is the row phrasing the user reads, with `{param}` placeholders
  (`"write {text} to file {path}"`). It is separate from `display_name` (the short label). Write
  display_text so the row reads like a sentence.
- **Simple Mode** hides advanced "drop to code" ACEs from beginners via a denylist keyed on
  `provider_id::ace_id` (it currently hides Run GDScript, Evaluate, Breakpoint, Assert, and similar).
  Custom ACEs are shown in Simple Mode by default; keep genuinely advanced ones clearly labeled.

---

## 12. Testing Custom ACEs

A wrong native method name compiles as a string and fails silently at runtime, so the rule is: do not
trust a template you have only read. Test it. The pattern, used by the built-in module tests, is:

1. Build a lookup of every descriptor and assert your ACE registered, in the right category, with the
   exact template.
2. Compile a sheet that uses the ACE, and assert the generated GDScript parses.
3. For anything stateful, multi-line, or touching the engine, instantiate the compiled script and run
   it, then check the effect.

```gdscript
var by_id: Dictionary = {}
for descriptor in EventForgeBuiltinACEs.get_descriptors():
    by_id[descriptor.ace_id] = descriptor

# 1. Registration + template.
assert(by_id.has("WriteTextFile"))
assert(by_id["WriteTextFile"].category == "Files")

# 2. Compile a sheet that uses it.
var sheet := EventSheetResource.new()
sheet.host_class = "Node"
var event := EventRow.new()
event.trigger_provider_id = "Core"
event.trigger_id = "OnReady"
var action := ACEAction.new()
action.provider_id = "Core"
action.ace_id = "WriteTextFile"
# Bake {uid} the way the dock does at apply time:
action.codegen_template = str(by_id["WriteTextFile"].codegen_template).replace("{uid}", "t1")
action.params = { "path": "\"user://test.txt\"", "text": "\"hello\"" }
event.actions.append(action)
sheet.events.append(event)
var output := str(SheetCompiler.compile(sheet, "user://__test.gd").get("output", ""))

# 3. Parse, then run.
var script := GDScript.new()
script.source_code = output
assert(script.reload() == OK)
var node: Node = script.new()
node._ready()
assert(FileAccess.file_exists("user://test.txt"))
node.free()
```

The build also runs a duplicate guard that fails if any two ACEs share a `provider_id::ace_id`, so a
collision is caught for you. Everything else (does it actually do the right thing) is your test to
write.

---

## 13. Custom Blocks: register your own NON-ACE row kinds

ACEs define what a row can do inside events; **custom block kinds** define new KINDS of rows
between events: preloads, region markers, notes, config blocks, pack-defined data. Drop a
script extending `EventSheetBlockKind` into `res://eventsheet_addons/` (the same zero-config
convention as ACE providers) and it gets Add-menu, palette, dialog, render, and byte-gated
round-trip integration automatically; other plugins register kinds in code via
`EventForgeBridgeRuntime.new().register_block_kind(kind)`. The full contract, the built-in
kinds, worked examples, and the safety rules live in the dedicated
[Custom Blocks Guide](GUIDE-CUSTOM-BLOCKS.md).

## 14. Use Cases

### 1. A game-specific action every sheet can use

Your game has combo scoring. One annotated `award_combo(points: int, multiplier: float)` on an autoload provider and every sheet's picker offers **Award Combo** - no sheet ever re-implements the math.

### 2. Wrapping an SDK once

Ads, analytics, or a store plugin: wrap its calls in one provider script (`show_rewarded_ad()`, `log_event(name)`) and designers use plain actions while the SDK's API stays in one file you can swap.

### 3. A studio-standard effect with tuned defaults

`screen_shake(strength: float = 8.0, seconds: float = 0.3)` with your tuned defaults becomes the ONE shake everyone uses - consistent feel, one place to retune.

### 4. An economy singleton as safe rows

An autoload `Economy` exposes `spend(amount)` / `earn(amount)` / `balance()`; sheets get Spend/Earn actions and a Balance expression, and nobody touches the save-file dictionary directly.

### 5. Guard rails around a dangerous call

Instead of letting sheets call `queue_free()` on anything, expose `despawn_safely(node)` that unregisters, fades, and frees - the picker offers the safe action, the risky one stays code.

### 6. A hardware trigger

A provider that polls a gamepad's gyro (or a MIDI pedal, or an Arduino over serial) and emits `## @ace_trigger` signals turns exotic input into ordinary event rows.

### 7. A game-jam save/load pair in one afternoon

Deadline in six hours and you still need saving. Write `save_slot(n: int)` / `load_slot(n: int)` / `slot_exists(n: int)` on a `RefCounted` provider once; the picker instantly has Save Slot and Load Slot actions plus a Slot Exists condition, so every menu button in the sheet wires up without you writing another line of GDScript.

### 8. A localization key check the whole team can read

Your strings live in `tr()` keys. Expose `text_for(key: String)` as an expression and `is_translated(key: String)` as a condition, and a non-programmer teammate can build a "warn on missing translation" event row that reads like plain English instead of grepping the CSV by hand.

### 9. Retuning damage numbers without reopening a single sheet

`deal_damage(target, base: float, crit_chance: float = 0.1)` lives in one provider script. When balancing turns the crit rate down for the final build, you edit the one default and recompile - every sheet that used Deal Damage picks up the new value, and no designer has to touch their events.

### 10. A deprecation that never breaks the old levels

You shipped `add_score(n)` in the demo, then the real game needed `award_score(n, source)`. Annotate the old method `## @ace_deprecated("Use Award Score instead")`: the twenty tutorial sheets that already call Add Score keep compiling untouched, while the picker only offers the newer action to anyone building fresh content.

### 11. A physics helper wrapped as one safe expression

Everyone on the team kept hand-writing the same raycast-from-mouse snippet slightly differently. Wrap it as `world_point_under_mouse()` returning `Vector2`, and the picker gains one Expression that inlines the correct, null-safe idiom everywhere - no more three subtly different copies drifting apart across sheets.

## 15. Tips and Common Mistakes

- **A wrong method name fails silently.** `position = {pos}` is safe; a typo like `move_too({pos})`
  compiles fine and crashes only when the generated code runs. Compile, parse, then run it in a test.
- **Templates are frozen once shipped.** Changing an `ace_id` or `codegen_template` breaks every sheet
  that used it. To change behavior, add a new ACE and **deprecate** the old one - on Path 1, annotate it
  `## @ace_deprecated("Use <NewName> instead")`: it keeps compiling in sheets that already use it (so
  nothing breaks), but is hidden from the picker, flagged on hover, and warned at compile. An optional
  SECOND argument names the successor - `## @ace_deprecated("Renamed.", "method:begin_wave")` - so the
  hover says where the member went. (`@ace_hidden` only hides a member; use `@ace_deprecated` to retire one
  with a pointer to its successor.) Do not edit the shipped template.
- **Renaming a provider function breaks sheets silently.** The member name IS the ace_id
  (`method:start_wave`), and the compiler prefers the template baked onto the row over any registry
  lookup, so an orphaned row still emits the old call, compiles with zero errors, and fails at game
  runtime. Rename in your own editor, then add a forwarding shim under the old name (Sheet > Custom
  Actions... > **Keep Old Name...**, or `EventSheets.keep_old_verb_working(path, old, new)`). The Project
  Doctor's **orphaned-verb** check finds calls that have already been orphaned.
- **Use tabs, not spaces, for nested template lines.** The compiler emits tabs; a space-indented line
  in a multi-line template produces mixed indentation and a parse error.
- **Name every local with `{uid}`.** Two copies of a multi-line ACE in one event will collide on a
  fixed local name. `{uid}` gives each instance its own.
- **Prefer null-safe reads.** `FileAccess.get_file_as_string({path})` returns `""` on error;
  `FileAccess.open(...)` returns `null` and will crash a naive `.method()` call. Guard or use the safe
  static form, especially in Expression templates that get inlined.
- **`provider_id::ace_id` must be unique.** A duplicate silently overwrites the other in the registry.
  Namespace your provider and keep ids unique within it.
- **Keep generic ACEs last (Path 3).** The importer matches templates most-specific-first; a generic
  helper registered before a specific ACE will shadow it on round-trip.
- **Write the `ace_type` as a name or string, never a number.** The two ACEType enums have different
  integer orders. `ACEDescriptor.ACEType.ACTION` (Path 3) and `"action"` (Path 2) are unambiguous.
- **`@export` is required for Path 1 properties.** A bare `var` is invisible to reflection; only
  `@export` vars become expressions and set/add/subtract actions.
- **Path 1 needs an instantiable script with a `class_name`.** The editor reflects by calling
  `script.new()`, so an abstract or non-compiling script is skipped; without `class_name` the provider
  id falls back to the PascalCased filename and can collide. `@tool` is optional (most bundled packs
  omit it) - add it only when the script's own code should run in the editor too.
- **`{, args}` drops only on the empty string.** `"0"` and `"false"` still emit the comma. Use it for
  genuinely optional trailing arguments, and remember it does not reverse-lift.

## A step-by-step method for wrapping code you already wrote

This guide is the reference. When the job is "I have working GDScript, make it droppable in a
sheet", `docs/internal/skills/turn-existing-gdscript-into-aces.md` is the working method:
the id/name survey, a route decision table, the annotation grammar rules that bite (verbatim
annotation values, one line per annotation, comma splitting inside `@ace_param`), one worked
example per code pattern (computed checks, cheap meta-keyed state versus stateful members,
dropdowns and the single-pass rule, async, triggers, looping, node-scoped and host-targeted
templates, persistence, the lambda traps), and the verification ritual in order.

The fastest way to learn either dialect is still the picker: right-click any ACE and
**Copy annotation stub** / **Copy registrar snippet**. Stubs are generated from the live
definition, so they carry that ACE's real labeled options, starting values, row caption,
looping annotation and shipped node-target form - and when the dialect cannot express
something (per-row state, a multi-line template, node scoping, a starting value in the
registrar), the stub leads with `#` notes that say so and hand over the descriptor chain
that can.
