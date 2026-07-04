# Make a Behaviour Without Writing Code

You can build a whole reusable **behaviour** - the kind you attach under a node and reuse across a project, like Construct 3's behaviours - using **only event-sheet rows**. No GDScript blocks. This guide maps the vocabulary so you can find every piece: variables and designer knobs, triggers, conditions, actions, loops, and functions that publish as your behaviour's own ACEs - plus the honest line where a GDScript block is still the right tool.

## Table of Contents

1. [Scenarios Where Code-Free Behaviours Excel](#1-scenarios-where-code-free-behaviours-excel)
2. [The Bundled Examples](#2-the-bundled-examples)
3. [Start a Behaviour](#3-start-a-behaviour)
4. [React - Triggers](#4-react---triggers)
5. [Decide - Conditions](#5-decide---conditions)
6. [Act - Actions](#6-act---actions)
7. [Loop - Pick Filters](#7-loop---pick-filters)
8. [Reusable Logic - Functions](#8-reusable-logic---functions)
9. [When GDScript Is Still the Right Tool](#9-when-gdscript-is-still-the-right-tool)
10. [Tips and Common Mistakes](#10-tips-and-common-mistakes)

---

## 1. Scenarios Where Code-Free Behaviours Excel

- **A reusable node behaviour.** Flash, a timer, 8-direction movement: author it once as rows, attach it under any host node, reuse it across the whole project.
- **Designer-tunable gameplay.** Exported knobs (`move_speed`, `gravity`) show up in the Inspector with live typed drawers, so a designer tunes the behaviour without opening the sheet.
- **Behaviours that announce themselves.** A signal published as a trigger lets other sheets react (*On Flash Finished*) without any wiring code.
- **Acting on every enemy, child, or list item.** Pick Filters give you For Each / Repeat / While loops as rows, with break/continue control.
- **Publishing your own vocabulary.** A function exposed as an ACE becomes a picker entry in every sheet - your behaviour ships its own actions, conditions, and expressions.
- **Learning from working examples.** Every bundled code-free behaviour is a plain `.gd` file you can open as a sheet, study, and tweak.

---

## 2. The Bundled Examples

The bundled **Flash, 8-Direction Movement, Timer, State Machine, and Move To** behaviours are each authored this way (zero GDScript) - open their sheets to see real examples. Each pack is a single **`.gd` file** (no `.tres`), and the importer can open *any* `.gd` as events, so the examples read as sheets you can study and tweak.

---

## 3. Start a Behaviour

**New Behaviour** scaffolds a sheet in **behavior mode**: it compiles to a small node you attach under a host (a `CharacterBody2D`, `Node2D`, ...). Inside the sheet, **`host`** is that parent - node ACEs target it automatically (e.g. *Move And Slide* becomes `host.move_and_slide()`).

Where each kind of value lives:

| You need | Use | Example |
|---|---|---|
| **Designer knobs** | An **exported** variable (an **@export badge** shows on the row + in the Inspector) | `move_speed`, `gravity` |
| **Internal state** | A **non-exported** variable | `remaining`, `flashing`, a coyote timer |
| **Scratch values** inside one event | **Set Local Variable (typed)** | a loop-local distance |

Typed knobs get a live Inspector **drawer** (direction dial, colour swatch, curve, progress bar, texture preview); group many with `@export_group` / `@export_subgroup`.

---

## 4. React - Triggers

- **On Ready / On Process / On Physics Process** - lifecycle triggers (the tick of your behaviour).
- **A signal as a trigger** - add a **Signal row**, tick **"trigger"**, give it a name/category. It publishes as an *On ...* trigger other sheets can react to (this is how Flash fires *On Flash Finished*).

---

## 5. Decide - Conditions

- **Compare Variable**, **Expression Is True** (any boolean expression), **Is Valid** (null-safe), the **Array/Dictionary** conditions (*Is Empty*, *Contains*, *Has Key*), node conditions (*Is On Floor/Wall*), input (*Is Action Pressed*). Add several for AND, or switch the row to OR.
- **Else** - right-click a row → *Else* (or the chain keys) for if/else.

---

## 6. Act - Actions

- **Set / Add Variable**, **Set Property** (`host.visible = ...`), **Call Method**, **Emit Signal**.
- **Movement**: *Set Velocity (X/Y)*, *Apply Gravity*, *Accelerate Velocity Toward*, *Move And Slide*, *Read Input Axis Into*.
- **Collections** (a full set - no GDScript needed): *Append*, *Pop Front/Back*, *Push Front*, *Insert*, *Erase*, *Find*, *Sort*, *Clear*; *Set Key*, *Get (with default)*, *Has Key*, *Keys/Values*.

---

## 7. Loop - Pick Filters

**The bit people miss.** Loops live on an event as a **Pick Filter** (Construct's name). Right-click an event → **Add Pick Filter**, then choose the kind:

| Pick a kind | Compiles to | Use for |
|---|---|---|
| **For Each** (group / children / array) | `for item in ...:` | act on every enemy / child / list item |
| **Repeat N times** | `for i in range(n):` | do something N times |
| **While (condition)** | `while <expr>:` | loop until a condition flips |

Inside the loop body, **Current Loop Item** is the iterator; **Break Loop** / **Continue Loop** control it. *Budgeted For Each* spreads a big loop across frames.

---

## 8. Reusable Logic - Functions

Add a **Function** (name + typed parameters + a return type). How it publishes as an ACE follows the **return type**:

- returns **nothing (void)** → an **Action** (e.g. `jump()`, `start_timer(seconds)`)
- returns a **bool** → a **Condition** (e.g. `is_in_state(name)`)
- returns **any other value** → an **Expression** (e.g. `health_percent()`)

Tick **"expose as ACE"** and the function becomes a picker entry in every sheet - that's how your behaviour publishes its own vocabulary.

---

## 9. When GDScript Is Still the Right Tool

Some logic genuinely *is* code and reads better as a block (the escape hatch is always there): a typed **inner class**, continuous **numeric integration** (`cos`/`sin`/spring math), or a tight numeric kernel. The bundled `spring`, `juice`, and `bullet` packs keep those as GDScript on purpose. The goal is **zero *gratuitous* GDScript** - not dogmatic zero. Everything in sections 3-8 above is the discrete game logic that should be rows.

---

## 10. Tips and Common Mistakes

- **Loops are the bit people miss.** They are not a row you add from the picker - they live *on the event* as a Pick Filter. Right-click the event → Add Pick Filter.
- **`host` is already wired.** In behavior mode, node ACEs target the parent automatically; you do not select or path to the host node yourself.
- **Choose export vs non-export deliberately.** Exported variables are the designer's surface (badge + Inspector drawer); internal state like `remaining` or a coyote timer should stay non-exported so it does not clutter the Inspector.
- **Use Set Local Variable (typed) for scratch values.** A value that only matters inside one event does not need a sheet variable.
- **A Signal row is not a trigger until you tick "trigger".** Only then does it publish as an *On ...* entry other sheets can react to.
- **The return type decides how a function publishes.** void → Action, bool → Condition, anything else → Expression. Pick the return type for the ACE role you want, then tick "expose as ACE" or it stays sheet-private.
- **Multiple conditions on a row are AND by default.** Switch the row to OR when you mean "any of these"; use Else (right-click or the chain keys) for if/else, not a duplicated inverted event.
- **Big loops can hitch.** Reach for *Budgeted For Each* to spread a heavy loop across frames instead of processing everything in one tick.
- **Do not force real code into rows.** Inner classes and continuous numeric math (`cos`/`sin`/spring kernels) read better as a GDScript block - the goal is zero *gratuitous* GDScript, not dogmatic zero.
