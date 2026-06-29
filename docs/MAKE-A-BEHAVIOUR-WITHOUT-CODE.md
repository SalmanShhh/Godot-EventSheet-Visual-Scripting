# Make a behaviour without writing code

You can build a whole reusable behaviour — the kind you attach under a node and reuse across a project,
like Construct 3's behaviours — using **only event-sheet rows**. No GDScript blocks. This page maps the
vocabulary so you can find every piece.

The bundled **Flash, 8-Direction Movement, Timer, State Machine, and Move To** behaviours are each
authored this way (zero GDScript) — open their sheets to see real examples. Each pack is a single
**`.gd` file** (no `.tres`), and the importer can open *any* `.gd` as events, so the examples read as
sheets you can study and tweak.

---

## 1. Start a behaviour

**New Behaviour** scaffolds a sheet in *behavior mode*: it compiles to a small node you attach under a
host (a `CharacterBody2D`, `Node2D`, …). Inside the sheet, **`host`** is that parent — node ACEs target
it automatically (e.g. *Move And Slide* becomes `host.move_and_slide()`).

- **Designer knobs** → add an **exported** variable (an **@export badge** shows on the row + in the
  Inspector: `move_speed`, `gravity`). Typed knobs get a live Inspector **drawer** (direction dial,
  colour swatch, curve, progress bar, texture preview); group many with `@export_group` / `@export_subgroup`.
- **Internal state** → add a **non-exported** variable (`remaining`, `flashing`, a coyote timer).
- **Scratch values** inside one event → **Set Local Variable (typed)**.

## 2. React — triggers

- **On Ready / On Process / On Physics Process** — lifecycle triggers (the tick of your behaviour).
- **A signal as a trigger** — add a **Signal row**, tick **"trigger"**, give it a name/category. It
  publishes as an *On …* trigger other sheets can react to (this is how Flash fires *On Flash Finished*).

## 3. Decide — conditions

- **Compare Variable**, **Expression Is True** (any boolean expression), **Is Valid** (null-safe),
  the **Array/Dictionary** conditions (*Is Empty*, *Contains*, *Has Key*), node conditions (*Is On
  Floor/Wall*), input (*Is Action Pressed*). Add several for AND, or switch the row to OR.
- **Else** — right-click a row → *Else* (or the chain keys) for if/else.

## 4. Act — actions

- **Set / Add Variable**, **Set Property** (`host.visible = …`), **Call Method**, **Emit Signal**.
- **Movement**: *Set Velocity (X/Y)*, *Apply Gravity*, *Accelerate Velocity Toward*, *Move And Slide*,
  *Read Input Axis Into*.
- **Collections** (a full set — no GDScript needed): *Append*, *Pop Front/Back*, *Push Front*, *Insert*,
  *Erase*, *Find*, *Sort*, *Clear*; *Set Key*, *Get (with default)*, *Has Key*, *Keys/Values*.

## 5. Loop — **the bit people miss**

Loops live on an event as a **Pick Filter** (Construct's name). Right-click an event → **Add Pick
Filter**, then choose the kind:

| Pick a kind | Compiles to | Use for |
|---|---|---|
| **For Each** (group / children / array) | `for item in …:` | act on every enemy / child / list item |
| **Repeat N times** | `for i in range(n):` | do something N times |
| **While (condition)** | `while <expr>:` | loop until a condition flips |

Inside the loop body, **Current Loop Item** is the iterator; **Break Loop** / **Continue Loop** control
it. *Budgeted For Each* spreads a big loop across frames.

## 6. Reusable logic — functions

Add a **Function** (name + typed parameters + a return type). How it publishes as an ACE follows the
**return type**:

- returns **nothing (void)** → an **Action** (e.g. `jump()`, `start_timer(seconds)`)
- returns a **bool** → a **Condition** (e.g. `is_in_state(name)`)
- returns **any other value** → an **Expression** (e.g. `health_percent()`)

Tick **"expose as ACE"** and the function becomes a picker entry in every sheet — that's how your
behaviour publishes its own vocabulary.

---

## When GDScript is still the right tool

Some logic genuinely *is* code and reads better as a block (the escape hatch is always there): a typed
**inner class**, continuous **numeric integration** (`cos`/`sin`/spring math), or a tight numeric kernel.
The bundled `spring`, `juice`, and `bullet` packs keep those as GDScript on purpose. The goal is **zero
*gratuitous* GDScript** — not dogmatic zero. Everything in sections 1–6 above is the discrete game logic
that should be rows.
