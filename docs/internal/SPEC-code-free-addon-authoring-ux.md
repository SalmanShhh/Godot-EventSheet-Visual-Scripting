# SPEC — Code-free addon-authoring UX: the Behaviour Anatomy + ACE Studio

**Status:** proposed (design tournament complete — four philosophies scored by four judges, winner + best grafts synthesised). **Author trigger:** the recurring "isn't this just slower typing / how is this better than Scratch?" critique, and the north-star commitment that *the eventsheets are not done until authoring an addon in blocks is both beginner-legible for a Construct-3 refugee AND a real accelerator for an experienced Godot dev.* This spec owns the **authoring experience + block-design system**. It cross-references — and does not duplicate:

- [`SPEC-behaviour-as-aces-parity.md`](SPEC-behaviour-as-aces-parity.md) — owns the **vocabulary + function system** (host-targeting `{host.}`, physics/input ACEs, typed function-locals, the three-way expose mapping, param defaults). This UX spec *presents* those primitives; it does not redesign them.
- [`SPEC-behaviour-gdscript-blocks-audit.md`](SPEC-behaviour-gdscript-blocks-audit.md) — owns the **RawCode census + rendering mechanics** (the 783-block audit, the lift chain, which packs keep GDScript and why). This UX spec *renders around* that reality; the numeric-kernel carve-out here is that spec's carve-out.

> Line numbers below are as-of the design investigation; treat them as "look here," not literal offsets. Every load-bearing claim was re-verified against the working tree (see §7 receipts).

---

## 0. North star, the reframe, and the two personas

### 0.1 The reframe

Today a behaviour addon's *public surface* — the Actions, Conditions, Expressions, Triggers and Properties other sheets pick from — is authored as scattered `## @ace_*`-annotated GDScript, discoverable only by scrolling the `.gd`. `health_behavior.gd` ships as one 472-line file with ~205 annotation lines across 38 funcs (audit spec §1). Yet the codebase *already treats the surface as the primary artifact*: auto-discovery keys off `## @ace_*` on signals/methods/`@export` vars; `EventFunction.expose_as_ace` publishes verbs into every picker (`event_function.gd:13`); `ACEDefinition.format_display` + category drive how a row reads.

**The reframe: make that latent truth the centrepiece of authoring.** A behaviour is not a pile of logic — it is an ORGANISM with a fixed body plan whose public organs are what other sheets consume. So the authoring surface is a **Behaviour Anatomy panel**: seven always-visible labelled organs you *fill in* — Properties · State · Triggers · Actions · Conditions · Expressions · Uses — with the logic canvas beside it holding only the tick/lifecycle events. The panel is simultaneously the beginner's fill-in-the-blanks checklist, the expert's class diagram grouped by ROLE (not emission order), and the addon's living API doc. Filling an organ is the whole authoring act; you are never assembling in the abstract, always populating a named part of a known anatomy.

### 0.2 The two personas — the value test

Both must be true or the feature has no reason to exist.

| Persona | Their hardest problem | How the design answers it |
|---|---|---|
| **The C3 refugee** (beginner, non-programmer) | "I opened a blank behaviour — *what am I even supposed to fill in?*" and "Action vs Condition vs Expression — what's a return type?" | The **fixed seven-organ checklist with ghost hints** turns a blank behaviour into a self-teaching form. The **three friendly A/C/E cards** ("Does something / Is it true? / A value") replace return-type jargon. The **live picker preview** shows their published verb exactly as a teammate will see it — the vocabulary (Properties, Triggers, Actions, Conditions, Expressions) is C3's own. |
| **The Godot dev** (expert) | "Why not just type the GDScript? Everything here is slower typing." | The panel **is the class diagram** on one screen (no scrolling a 472-line file). The **generated-signature strip** shows the exact `func` header live, so codegen is never a mystery. The design replaces the tedious, drift-prone parts — hand-maintained `## @ace_*` annotations that silently rot, per-`@export` accessors, host casts, and the compile-attach-open-a-consumer-sheet round-trip to verify the picker — never the thinking. |

**The one-line value payoff (§6 proves it concretely):**
- *For the C3 refugee:* "Fill in seven labelled boxes and watch your behaviour's picker face assemble live — you never see the word `func` or `return type`."
- *For the Godot dev:* "The same code you'd hand-write, with the annotation boilerplate, accessors, call-site refactors and picker registration generated and kept in sync — plus a one-screen API view you'd otherwise reconstruct by scrolling."

### 0.3 Why this frame won (tournament synthesis)

Four philosophies were scored: **Behaviour Anatomy panel** (this one), **Contract-first ACE Studio**, **Everything-is-a-block one canvas**, **Scaffold-and-tune**. The decisive axes were *buildability under the byte-exact round-trip covenant* and *beginner-orientation*, and they cut the same way for the two engineering-lens judges and split narrowly for the two product-lens judges. The Anatomy panel is chosen as the **shell** because it is the only design that sidesteps the covenant hazard structurally: `EventFunction`s live in `sheet.functions`, a *separate* array from `sheet.events`, and `_build_row_from_resource` has no `EventFunction` branch today (verified — §7). Any design that renders Define-blocks *inline in the events tree* must merge two independently-serialised arrays into one ordered visual list and guarantee it never writes that merged order back, or drift=0 breaks. The Anatomy renders organs in a **separate docked panel as a read-model** over the existing resources — it never mutates the events tree — so it dodges the hazard entirely while giving the beginner the fixed checklist that solves the blank-canvas panic.

We then **graft the best ideas from the other three** (each independently reinvented by all four designs, so they are frame-agnostic):

1. **The live picker preview** (crown jewel — all four) — "this is what other sheets will see," rendered in the real picker chrome, updating per keystroke.
2. **The friendly three-card A/C/E selector** (all four) — replaces the return-type question, pre-selected by the clicked organ.
3. **The "Ships as:" generated-signature strip** (contract-first + anatomy) — the cheapest thing that earns the Godot dev's trust.
4. **Contract-shaped recipe scaffolds** built from the existing pack-builders (scaffold-and-tune) — the New Behaviour wizard's step 2, so the beginner lands *reviewing a real API and filling bodies*.
5. **Published-before-implemented** as a supported state (contract-first) — an exposed verb with an empty-but-valid body compiles and round-trips.
6. **Per-block / whole-sheet "Show generated GDScript" fold** (everything-is-a-block) — the always-one-click-away trust surface.

---

## 1. The block-vocabulary design system

Every organ block is built from the **exact shipped span primitives** (`viewport_row_builder._make_span`, `:1191`; badge/chip/`object_label`/`object_icon`/`TEXT_MUTED`) so the panel and canvas read as one system, not a form bolted onto an editor. The A/C/E triad share ONE chrome skeleton distinguished only by badge hue + return chip — so the three-way choice is legible as a colour family, not three unrelated widgets.

| Block | Represents | Chrome / badge / colour / icon | Add + edit | EXISTS vs NEW | Reads to C3 refugee / to Godot dev |
|---|---|---|---|---|---|
| **Property** (Properties organ) | A designer knob | Variable row `name : Type = default` + blue `@export` badge `Color(0.22,0.34,0.55)/(0.76,0.86,1.0)`; purple Inspector-group chip `(0.30,0.26,0.44)` when grouped; typed drawer chip | `+Property` → Variable dialog; double-click to edit | **EXISTS** (`_build_variable_row`, `:449`) | "a setting on my behavior (`max_health = 100`)" / literally `@export var max_health: int = 100` — the blue badge is the Inspector-visibility promise |
| **State** (State organ) | Internal, non-exported variable | Same Variable row **minus** the `@export` badge, **plus** a slate `internal` badge (scaffold greys `(0.18,0.19,0.21)/(0.5,0.52,0.56)`); dimmer row tint | `+State` → Variable dialog (exported=false); double-click | **EXISTS** (same builder, exported=false path) | "a value my behavior remembers but designers don't touch (`current_health`)" / a plain member var, private by convention |
| **Trigger** (Triggers organ) | A published event other sheets react to | **SHIPPED exemplar** — accent `trigger` badge + friendly name (`On Damaged`) in object-label colour + purple category chip + muted `signal on_damaged(amount: int)` | `+Trigger` → signal dialog, `trigger` pre-ticked; double-click | **EXISTS** (`_build_signal_row` trigger branch, `:137`) | "an event other sheets can react to — On Damaged" / a declared signal + its `@ace_trigger` annotation, emitted from my actions |
| **Define-Action** (Actions organ) | A published verb the behaviour DOES — the crown jewel | Warm-**amber** `Action` badge; verb name (`Take Damage`) in object-label colour; typed-param chip strip (`amount: int`); category chip; right-aligned muted signature `func take_damage(amount: int) -> void`; collapsed body preview `ƒ N lines` | `+Action` → **ACE Studio** (§2), drops the block + opens its canvas body | **NEW** rendering (`_build_define_action_row`); data EXISTS (`EventFunction`) | "a thing my behavior can DO that I designed — Take Damage(amount)" / the exact func signature it emits |
| **Define-Condition** (Conditions organ) | A published yes/no test | Cool-**teal** `Condition` badge; `?` glyph; name (`Is Dead`); trailing `→ bool` return chip; category chip; muted `func is_dead() -> bool` | `+Condition` → ACE Studio (Condition card); double-click | **NEW** rendering; data EXISTS (`return_type = TYPE_BOOL`) | "a yes/no question about my behavior — Is Dead?" / a bool getter, callable as a condition in any sheet |
| **Define-Expression** (Expressions organ) | A published value | **Violet** `Expression` badge; `ƒx` glyph; name (`Health %`); trailing typed-value chip `→ float`; category chip; muted `func health_percent() -> float` | `+Expression` → ACE Studio (Expression card, value-type sub-question); double-click | **NEW** rendering; data EXISTS (`return_type = typed`) | "a value my behavior can hand out — Health %" / a typed getter usable inside expressions/parameters elsewhere |
| **Tick / lifecycle** (canvas, NOT panel) | Behaviour-over-time | A normal `EventRow` with a lifecycle trigger (On Ready / On Process / On Physics Process) or a Trigger-organ signal handler; unchanged `➜` trigger badge + condition/action lanes | `+Add event` footer on the canvas; double-click | **EXISTS** (`_build_event_row`) | "every frame, do this" / `_process(delta)` / `_physics_process(delta)` |
| **Loop** (canvas) | Pick-filter iteration | The `For each / Repeat N / While` line in the condition lane | Part of an event's condition lane | **EXISTS** (pick-filter) | "For each enemy" / `for item in ...:` |
| **Uses** (Uses organ) | Composition / dependency — what the behaviour DEPENDS ON | Neutral `uses` badge (scaffold greys) + required class/behaviour name in object-label colour + resolved node icon (`_object_icon_for`); muted `requires` / `optional` tail | `+Uses` → target picker (host class / sibling behaviour / autoload); double-click | **NEW** (small declaration row); host-class field EXISTS on the sheet | "my Health behavior needs a CharacterBody2D host" or "talks to the GameState autoload" / the host-type contract + any `{host.}`/autoload dependency |
| **Organ header** (structural, one per organ) | The panel's spine | Slim section header (`EventSheetPopupUI.section_header` styling) + organ name + live count (`Actions · 2`) + one-glyph organ icon + trailing `+`; empty organs show one ghosted hint row | Fixed — always present | **NEW** (panel chrome) | Makes even a blank behaviour read as a labelled, fillable form for both |

**How the vocabulary reads to BOTH personas as a whole:** scanning the panel top-to-bottom, the refugee reads *seven questions to answer about my behavior*; the dev reads *the class's public surface grouped by role*. The colour ribbon down the badge column (blue Property · slate State · accent Trigger · amber Action · teal Condition · violet Expression · grey Uses) is a legend both learn once. The return-type chips (`→ bool`, `→ float`) make the get/set/test distinction a visible token, not a mental model.

---

## 2. The ACE-definition experience (crown jewel) — the ACE Studio

The Studio opens the moment you press `+Action`, `+Condition`, or `+Expression` on an organ. It **extends the shipped `EventSheetFunctionDialog`** (`function_dialog.gd`), which already carries Name, Description, the `USABLE_AS` three-way, typed params, guards, and the expose card — it does not replace it. The Studio is a themed dialog (`EventSheetPopupUI` `titled_card` / `panel_section`). It reframes and augments the dialog in four ways.

### 2.1 The friendly A/C/E choice (kills "return type")

Today `USABLE_AS` is a single `OptionButton` buried mid-form. Its labels already read friendly (`function_dialog.gd:19-22`, verified):

```
Action (does something — a setter)
Condition (a yes/no test)
Expression (returns a value — a getter)
```

The Studio **promotes this to three big colour-coded cards** the user clicks between — and the organ whose `+` you pressed **pre-selects** the card, so a beginner never meets the distinction cold:

- **"Does something" (Action, amber).** Sub-label: *Take Damage, Heal, Knock Back.* → `return_type = TYPE_NIL`.
- **"Is it true?" (Condition, teal).** Sub-label: *Is Dead, Is Full Health.* → `return_type = TYPE_BOOL`; hides the value-type row.
- **"A value" (Expression, violet).** Sub-label: *Health %, Remaining Shields.* → reveals the existing `VALUE_TYPES` picker relabelled **"What kind of value?"** with plain-English options (*a number / whole number / yes-no / text / a point (Vector2)*).

This is a **pure presentation lift** over the existing `USABLE_AS`/`VALUE_TYPES` — `build_function_data()` already derives `return_type` exactly right (`:285-292`, verified): condition→`TYPE_BOOL`, expression→the chosen `VALUE_TYPES` type, else→`TYPE_NIL`. The Studio only makes the choice loud, colour-matched to the block badges, and organ-anchored. **The decisive twist:** flipping the card visibly MOVES the verb between picker groups in the live preview (§2.2) — the beginner *sees* the consequence of the choice instead of reasoning about types.

### 2.2 The live picker preview (the decisive device)

Down the right side of the Studio is a **"This is what other people will see"** pane that renders a REAL picker entry using the actual row-builder chrome — the same badge/chip/icon language as the canvas — updating on every keystroke: the icon (via the shipped static `ACEPickerDialog.resolve_definition_icon`, verified `static func`, `ace_picker.gd:617`), the verb name, the category chip, the param signature, and a one-line "as it reads in a sheet" mock (`Health › Take Damage  amount 25`). Flip the A/C/E card and the badge + return chip change and the row **jumps to the matching picker group** (Actions → Conditions → Expressions). The non-programmer SEES their API before it exists, in the exact pixels other authors will meet — the antidote to "I defined something invisible."

### 2.3 The Godot-dev "Ships as:" signature strip

Directly under the preview, a monospace, read-only **"Ships as:"** line shows the exact generated `func` signature, live, formatted by a **shared helper bound to `build_function_data()`** (so it can never disagree with the compiler):

```
func take_damage(amount: int) -> void      # Action  "Take Damage"  (category Health)
func is_dead() -> bool                      # Condition
func health_percent() -> float              # Expression
```

A **"show annotations"** disclosure expands the `## @ace_*` lines the expose path emits (`@ace_action` / `@ace_name("Take Damage")` / `@ace_category("Health")`), and a **Copy signature** button lets a dev hand-tune. The dev confirms the codegen at a glance and trusts it.

### 2.4 On confirm

The Studio emits the same `function_confirmed` payload `build_function_data()` produces (extended with the organ hint). The dock creates the `EventFunction` with `expose_as_ace` pre-set true (it IS the behaviour's public API by definition here — **gated**, see §7 covenant so opening an existing un-exposed function never silently re-annotates it), drops the Define-block into the correct organ, and focuses the canvas with a fresh body flow bound to it (`return current_health <= 0` pre-stubbed for a Condition, an empty action flow for an Action). Params entered in the Studio become `ACEParam`-typed arguments available as chips in that body.

**Published-before-implemented is first-class.** The contract exists and is preview-correct BEFORE a single body row is written — you can lay out the whole API, share the picker preview with a teammate, and fill bodies later. The compiler already emits `pass` for a body-less function (`sheet_compiler.gd:445-446`), but `pass` is valid ONLY for a void Action — a body-less **Condition/Expression** compiles to `func is_dead() -> bool:\n\tpass`, which has no return. So the NEW work is a **type-correct** empty-body stub (`return false` for bool, `return <type-default>` for other typed returns) plus a round-trip test covering "exposed verb, empty body, compiles + round-trips at drift=0" (§7, §8).

**EXISTS vs NEW here:** the dialog, three-way, typed params, guards, expose, category, `return_type` derivation — all EXIST. NEW: the three-card lead selector (restyle of the `OptionButton`), the live picker-preview pane (new `Control` reusing `resolve_definition_icon` + row-builder spans), the "Ships as:" strip (a `Label` bound to a shared signature formatter), the empty-body stub codegen.

---

## 3. The authoring canvas + flows

### 3.1 Layout — two regions

- **Left: the Anatomy panel** — a docked, resizable, always-visible column (~300px), seven collapsible organ sections in fixed order Properties → State → Triggers → Actions → Conditions → Expressions → Uses. Each organ has a slim header (name · live count · icon · `+`) and, when empty, a single ghosted hint row.
- **Right: the existing virtualized canvas** — now holding ONLY tick/logic events (lifecycle events, signal handlers, regen loops) plus the *bodies* of the defined verbs. Clicking a Define-block in the panel scrolls the canvas to that verb's body flow and pulses it; the body's header row echoes the organ badge so the wiring is obvious. Hovering a canvas event that emits a Trigger-organ signal, or calls a Define-Action, highlights that organ block.

### 3.2 Discovery / add model — no palette, no scatter

Every add originates from an organ's `+`. `+Property`/`+State` → Variable dialog. `+Trigger` → signal dialog (trigger pre-ticked). `+Action/+Condition/+Expression` → ACE Studio (drops a Define-block + opens its canvas body). `+Uses` → target picker. This is the whole discovery story: you don't hunt for what to add — the anatomy lists the seven kinds of thing a behaviour can have, and each says `+`. A first-timer reads the panel top-to-bottom as *here are the seven questions to answer about my behavior.* Empty organs are never blank — each shows a hint line in its hue (*"No conditions yet — +Condition adds a yes/no question others can ask"*), reusing the shipped `_build_add_event_footer_row` pattern (`:71`).

### 3.3 New Behaviour wizard

Replaces the bare behaviour-component starter drop. **Step 1 — "What does it attach to?"** (host class picker → sets `host_class`, feeds the first Uses block: CharacterBody2D / Node2D / Area2D / Node, + 3D twins). **Step 2 — "Start from a recipe?"** — contract-shaped scaffolds that PRE-FILL organs with real blocks and **empty-but-valid bodies** (so a beginner lands reviewing a real API and filling bodies, per the published-before-implemented graft): *Health, Movement, Cooldown, State Machine, Blank.* Each recipe is **authored by the existing pack-builders** (`tools/pack_builders/health.gd`, `eight_direction.gd`, …) factored into shared static scaffold emitters callable both at pack-build time and in-editor — reusing proven pack shapes and turning the packs into a curriculum for free. The user lands in a fully-populated Anatomy they can edit, learning the body plan by seeing a complete specimen.

### 3.4 Inline editing

Double-click any panel block to reopen its authoring dialog. Rename in the Studio triggers a refactor-safe rename across the sheet (call sites resolve by name). Drag to reorder within an organ **moves the underlying resource in its array** — a real edit that round-trips (variables, signals, and functions all serialise in array order), NOT a hidden display order. You can only reorder *within* an organ (each holds one resource type), so it never violates the compiler's canonical section order. Right-click an organ block → Go to body / Duplicate / Delete / Show generated code.

### 3.5 "Show the code / what ships" reassurance

A persistent panel-footer toggle **"Show generated GDScript"** opens the compiler's output for the whole class read-only, with the selected organ block's lines highlighted — so a Godot dev can, at any moment, see that "Take Damage" really is the func they'd have written. A per-block **`</>` fold** reveals just that block's compiled lines inline. The **RawCodeRow escape hatch** is always available for a body that genuinely wants hand-code (the numeric-kernel carve-out of the audit spec §5.4 — spring integrators, `HealthPool` decay), rendered as a marked amber "⚠ code" block: it is visibly the *exception*, no longer the default way to express a verb.

---

## 4. The hero screen — a Health behaviour authored entirely in blocks

Left panel top-to-bottom, canvas on the right. This drives the mockup (appendix).

**PANEL HEADER:** `HealthBehavior` with a small heart `@icon`, subtitle *attaches to CharacterBody2D.*

- **PROPERTIES · 2** — two blue-`@export`-badged Variable blocks: `max_health : int = 100` and `regen_rate : float = 5.0`, both carrying a purple **Health** Inspector-group chip. Two tunable Inspector knobs.
- **STATE · 1** — one block, no blue badge, slate `internal` badge: `current_health : int = 100`. The value the behaviour remembers.
- **TRIGGERS · 2** — two shipped-style trigger blocks: `[trigger] On Damaged [Health] · signal on_damaged(amount: int)` and `[trigger] On Died [Health] · signal on_died()`. Events other sheets react to.
- **ACTIONS · 2** — two amber Define-Action blocks: `[Action] Take Damage · amount: int · func take_damage(amount: int) -> void`; `[Action] Heal · amount: int · func heal(amount: int) -> void`. Both carry the Health category chip.
- **CONDITIONS · 1** — one teal block: `[Condition] Is Dead · → bool · func is_dead() -> bool`.
- **EXPRESSIONS · 1** — one violet block: `[Expression] Health % · → float · func health_percent() -> float`.
- **USES · 1** — one neutral block: `[uses] CharacterBody2D (host)` with the body glyph.

**CANVAS (right)** — the tick logic + the bodies of the defined verbs, as normal event flows whose headers echo their organ badge:

- Regen tick: `➜ On Physics Process → [condition] current_health < max_health → [action] Add current_health  regen_rate * delta → [action] Set current_health  min(current_health, max_health)`.
- Body of **Take Damage** (amber header): `Set current_health = current_health - amount → Emit on_damaged(amount) → sub-event: if current_health <= 0 → Emit on_died()`.
- Body of **Heal**: `Set current_health = min(current_health + amount, max_health)`.
- Body of **Is Dead**: `return current_health <= 0`.
- Body of **Health %**: `return float(current_health) / float(max_health) * 100.0`.

**What the user SEES overall:** a labelled specimen. The left panel is a one-screen contract — *this behaviour has 2 knobs, remembers 1 value, fires 2 events, can do 2 things, answers 1 yes/no, hands back 1 number, and needs a CharacterBody2D.* Not one line was typed as freeform code; every organ was filled via `+`.

---

## 5. Visual language

**Colour as taxonomy**, drawn straight from the shipped palette so it lands day one. Two axes: organ hue + block role. The A/C/E triad is one skeleton, three hues:

| Role | Badge colour | Source |
|---|---|---|
| Property | blue `(0.22,0.34,0.55)/(0.76,0.86,1.0)` | shipped `@export` badge |
| State | slate `(0.18,0.19,0.21)/(0.5,0.52,0.56)` | shipped scaffold greys |
| Trigger | `behavior_accent_color` | shipped trigger badge |
| Action | warm amber | action-lane accent |
| Condition | cool teal | condition-lane accent |
| Expression | violet `(0.30,0.26,0.44)` | shipped category/Inspector chip purple |
| Uses | neutral grey + node icon | `_object_icon_for` |

The SAME hues reappear on the canvas body-flow headers, tying logic to anatomy. **Chrome consistency:** every panel block is built from the exact `_make_span` badge/chip primitives (`badge` + `badge_style` + `badge_bg/fg`; `chip` for cells; `object_label`/`object_icon`; `TEXT_MUTED` for the "ships as" tail) — no new rendering path, so the panel and canvas look like one system. **Return-type chips** (`→ bool` / `→ float`) make the invisible visible. **Discoverability:** empty organs show one ghosted hint row in their hue; the seven fixed labels + counts turn the panel into a progress checklist; a subtle left accent-bar per organ (like the shipped GROUP accent bar) segments the panel; first run drops a one-time coach-mark on the Actions organ — *"This is your behavior's public API — fill these and other sheets can use it."* It looks obviously code-free because the eye sees coloured verb cards + a picker preview, not `func`/`signal`/`@export`; it stays legible to a dev because every card's muted tail and the Show-GDScript fold spell out the exact GDScript.

---

## 6. Why not just GDScript

### 6.1 Capability-by-capability

| Capability | Hand-GDScript way | The eventsheet way | The win |
|---|---|---|---|
| **Declare a designer knob** | `@export var max_health: int = 100`, then `@export_range`/`@export_group`/tooltip annotations looked up + typed | `+Property` → Variable dialog: type, range drawer, group chip | typo-free, refactor-safe; grouping is a chip not remembered annotation syntax (**speed + refactor-safety**) |
| **Publish a trigger event** | `signal on_damaged(amount: int)` + a hand-written `## @ace_trigger`/`@ace_name`/`@ace_category` trio (easy to fat-finger → silently NOT published) | `+Trigger`, signal dialog, trigger pre-ticked | the block writes the annotation correctly every time and publishes to pickers (**correctness + discoverability**) |
| **Publish an Action/Condition/Expression** | `func` + ~4 lines of `## @ace_*` annotation per verb, kept in sync by hand; rename = edit func + comment + every caller | ACE Studio: friendly card + typed params → generated func + annotations in lockstep; rename refactors published name + call sites together | annotation boilerplate generated and kept in sync; rename is refactor-safe (**the biggest win — reuse + refactor-safety**) |
| **Choose the picker category (return type)** | Remember `void→action, bool→condition, else→expression` and hand-tune return types to land in the right group | Three cards; the derived signature is shown | the rule is encoded so even an expert never misfiles a getter as an action (**correctness**) |
| **Read/modify a knob from another sheet** | Remember the exact property name + hand-write accessors | The knob is addressable by the generic *Set Property* / *Set Variable* / *Add Variable* ACEs via a typed picker — no accessor funcs (these ACEs already exist; a dedicated per-knob Set/Add/read is NOT auto-published today — see §9) | no per-knob boilerplate, typo-free (**reuse**) |
| **Verify the consumer's picker** | compile → attach → open a consumer sheet → check the picker | Live picker preview, at author time | API review without a round-trip (**speed + discoverability**) |
| **Target the host node** | `(get_parent() as CharacterBody2D).move_and_slide()`, host casts scattered through the body | `{host.}` idiom (parity spec §2.1) + the Uses block documenting the contract | host contract explicit and checkable (**correctness**) |
| **See the whole public surface** | Scroll a 472-line `.gd`, reconstruct the API mentally | The Anatomy panel — grouped by role, one screen | a genuinely new artifact you can't get by scrolling (**discoverability**) |

The honest limit (from the audit spec §5.4): for a tight numeric kernel — a spring integrator, `HealthPool` decay — GDScript reads better, and it stays a marked RawCode block on purpose. The pitch to the sceptic is never "slower typing"; it's *the same code with the drift-prone, refactor-hostile, discovery-hiding parts done for you and kept in sync.*

### 6.2 The C3-beginner zero-code path, end to end

1. **New Behaviour** → "attaches to CharacterBody2D" → pick the **Health** recipe. Lands on a fully-populated Anatomy — seven labelled organs already holding real blocks, in C3's own vocabulary. The picker preview on the right looks exactly like a C3 behaviour picker.
2. **Tune a knob:** click `max_health`'s value cell, type `250`. It shows in the Inspector; no code.
3. **Add a verb:** `+Action` → the three cards → "Does something" → name it **Knock Back**, add a param `force: float`, watch the preview render `Health › Knock Back  force` exactly as other sheets will see it → confirm. A body flow opens; fill it with Set/Add actions.
4. **Add a test:** `+Condition` → "Is it true?" → **Is Shielded** → preview shows the `→ bool` chip.
5. **Expose a value:** `+Expression` → "A value" → **Shield %** → pick *a number (float)*.
6. **Compile and attach** — a shippable behaviour, no GDScript touched. They never saw the words `return type`, `func`, `signal`, or `@export`.

The four beginner cliffs and their structural prevention: (1) *what do I fill in?* → the fixed seven organs + ghost hints; (2) *Action vs Condition vs Expression?* → cards with verbs and examples, pre-selected by the organ; (3) *what did I just make?* → the live picker preview; (4) *a body that needs math* → the marked amber "⚠ code" escape hatch, visibly the exception, with recipes steering to ACE rows first.

---

## 7. Buildability + covenant

### 7.1 EXISTS (reuse directly)

- The whole badge/chip/icon block language: `viewport_row_builder._make_span` (`:1191`), `_build_signal_row` (`:137`), `_build_variable_row` (`:449`), `_build_add_event_footer_row` (`:71`), `_build_scaffolding_strip_row` (`:39`).
- The Trigger block — **SHIPPED verbatim** (`_build_signal_row` trigger branch).
- Property/State blocks — Variable row + `@export` badge + Inspector-group chip already exist.
- The A/C/E logic + typed params + expose: `function_dialog.gd` `USABLE_AS` (`:19-22`, friendly wording verified) + `build_function_data()` deriving `return_type` void/bool/typed (`:285-292`, verified) + `EventFunction.expose_as_ace`/`ace_display_name`/`ace_category`/`params`/`return_type`/`events` (`:13-31`, verified).
- Picker icon: `ACEPickerDialog.resolve_definition_icon` — **verified `static func`** (`ace_picker.gd:617`).
- Themed dialogs: `EventSheetPopupUI` `titled_card`/`panel_section`/`section_header`.
- Recipe scaffolds: the pack-builders (`tools/pack_builders/*.gd`) factored into shared static emitters.
- Byte-exact round-trip: organ blocks are pure PRESENTATIONS of existing resources (`LocalVariable`/`SignalRow`/`EventFunction`), so the `.gd` stays the source of truth — nothing new needs serializing.

### 7.2 NEW (RefCounted helpers + dock delegates, matching the extraction pattern in memory: RefCounted helper + `_host` back-ref + thin delegate)

1. **`BehaviourAnatomyPanel`** — a `Control` that, given the sheet, buckets its resources into the seven organs and renders each block via the SAME row-builder spans; a `_host` back-ref to the dock for `+` actions.
2. **`ACEStudioDialog`** — extend/wrap `EventSheetFunctionDialog`: three A/C/E cards (presentation over the existing `OptionButton`), the live picker-preview pane (row-builder chrome + `resolve_definition_icon`), the "Ships as:" strip (a shared signature formatter bound to `build_function_data()`).
3. **New `badge_style`s** `ace_action`/`ace_condition`/`ace_expression` + return-type `→ T` chip rendering (small additions to the badge_style switch).
4. **`NewBehaviourWizard`** — two-step dialog producing a recipe `EventSheetResource` from the shared scaffold emitters.
5. **Type-correct empty-body stub codegen** — the compiler already emits `pass` for a body-less function (`sheet_compiler.gd:445`), valid only for a void Action; NEW is emitting `return false` (bool) / `return <type-default>` (other typed returns) for a body-less Condition/Expression so published-before-implemented compiles + round-trips.
6. **Panel↔canvas cross-highlight** — map an organ block to its `EventFunction`/`EventRow` body and pulse it.

> Note: the crucial NEW piece is rendering `EventFunction`s as first-class definition blocks. Verified: `_build_row_from_resource` (`event_sheet_viewport.gd:1617-1639`) branches on Group/Comment/LocalVariable/RawCode/Enum/Signal/Event and has **NO `EventFunction` branch** — functions render only via the picker today. Because the Anatomy renders them in a **separate panel**, not inline in the events tree, this is a pure VIEW over `sheet.functions` and never touches the events array's source order.

### 7.3 Covenant risks

1. **Read-model discipline (the primary risk).** The panel must be a READ MODEL over the resources — if a `+` ever writes state the compiler doesn't already round-trip, drift appears. Keep every organ block backed by an existing resource type only. Because functions live in `sheet.functions` (a *separate* array from `sheet.events`), the panel renders that array directly and **never merges function display-order into the events array** — this is exactly why the panel frame was chosen over an inline-tree frame.
2. **Reorder edits the resource array, never a hidden display order.** Variables/signals/functions serialise in array order, so reordering a block within its organ IS a legitimate source edit — persist it by moving the resource in its array (it round-trips). The covenant trap is a *parallel* display order the compiler doesn't read: forbid it — panel order must always equal the backing array. Verify with a "reorder-in-panel → recompile → reopen → same order" round-trip test.
3. **`expose_as_ace` on the AUTHOR path must preserve existing state.** The Studio creates/edits the `EventFunction` through `dock/function_dialog.gd:_apply_function_data` (`:81` assigns `expose_as_ace` from the payload). A NEW verb IS the behaviour's public API → set true. But the **edit-existing** path must LOAD the function's current `expose_as_ace` and preserve it unless the user explicitly flips it — never blanket-set true on open, or a hand-authored un-exposed helper silently gains `## @ace_*` annotations (a drift + surprise). NOTE: `lifted_unannotated` is a COMPILER-side guard for *lifted* funcs and does **not** protect this author path — so preserve-on-edit is a genuine NEW requirement in `_apply_function_data`, not something already handled. 
4. **Empty-body stub must compile + round-trip.** Published-before-implemented requires a codegen stub and a dedicated test: "exposed verb, empty body, compiles + round-trips at drift=0."
5. **"Ships as:" must format identically to the compiler.** Share one signature helper, or the dev sees a lie.
6. **Icon resolution must be headless-safe.** `resolve_definition_icon` may see a null icon before addons load — already null-tolerant in the picker path; reuse it, don't reimplement.

---

## 8. Roadmap (leverage-ordered, phased)

Ordered so the universally-graftable primitives ship first (they benefit the current function dialog even before the panel exists), then the shell, then the recipes.

1. **Phase 1 — Graftable primitives on `function_dialog.gd` (highest leverage, lowest risk).** The three A/C/E cards (presentation over `USABLE_AS`), the live picker preview pane (reuse `resolve_definition_icon`), the "Ships as:" signature strip (shared formatter over `build_function_data()`). These land on the existing Add-Function flow regardless of the panel and immediately answer "slower typing."
2. **Phase 2 — Define-block rendering + badge styles.** `_build_define_action_row`/`_condition`/`_expression` as spans; new `badge_style`s + `→ T` chips. Pure view over `EventFunction`; parity test that codegen is byte-identical with or without the view (health.gd drift=0 regeneration before/after).
3. **Phase 3 — The Anatomy panel.** `BehaviourAnatomyPanel` read-model, the seven fixed organs + ghost hints + `+` footers, panel↔canvas cross-highlight. Read-model discipline tests.
4. **Phase 4 — Empty-body stub codegen + published-before-implemented.** Stub emission + round-trip test.
5. **Phase 5 — New Behaviour wizard + recipe scaffolds.** Factor pack-builders into shared static emitters; two-step wizard; recipes land on a fully-populated Anatomy with empty-but-valid bodies.
6. **Phase 6 — Docs + coach-marks + version bump.** `docs/RECIPES.md` recipe + showcase sheet; first-run coach-mark; regenerate; drift=0.

### 8.1 Files to touch

| File | Change |
|---|---|
| `addons/eventsheet/editor/function_dialog.gd` | Three A/C/E cards (restyle `_usable_option`); live picker-preview sub-control; "Ships as:" strip bound to `build_function_data()`; value-type sub-question friendly relabel. |
| `addons/eventsheet/editor/ace_picker.gd` | Expose/reuse `resolve_definition_icon` (`:617`, already static) for the preview; no behaviour change. |
| `addons/eventsheet/editor/interaction/viewport_row_builder.gd` | `_build_define_action_row`/`_build_define_condition_row`/`_build_define_expression_row` (spans over `EventFunction`); new `badge_style`s `ace_action`/`ace_condition`/`ace_expression`; `→ T` return chip. |
| `addons/eventsheet/editor/`**`behaviour_anatomy_panel.gd`** (new) | The seven-organ read-model `Control`; `+` routing to the dialogs; ghost hints via `_build_add_event_footer_row` pattern. |
| `addons/eventsheet/editor/`**`ace_studio_dialog.gd`** (new, wraps `EventSheetFunctionDialog`) | Card selector + preview + signature strip + organ-anchored pre-select. |
| `addons/eventsheet/editor/`**`new_behaviour_wizard.gd`** (new) | Two-step host+recipe dialog over shared scaffold emitters. |
| `addons/eventsheet/editor/event_sheet_dock.gd` | Dock the Anatomy panel; wire `+` delegates; panel↔canvas cross-highlight. |
| `addons/eventsheet/editor/dock/function_dialog.gd` | Preserve existing `expose_as_ace` on the edit-existing path in `_apply_function_data` (`:81`); set true only for a NEW Studio verb (§7.3 #3). |
| `addons/eventforge/compiler/sheet_compiler.gd` | Empty-body stub emission for an exposed `EventFunction` with no `events` (`pass`/`return <default>`). |
| `tools/pack_builders/health.gd`, `eight_direction.gd`, `timer.gd`, `state_machine.gd` | Factor sheet-building into shared static scaffold emitters callable in-editor. |
| `docs/RECIPES.md` | Author-a-Health-behaviour recipe + showcase. |

### 8.2 Tests to add

- `anatomy_panel_readmodel_test.gd` — the panel renders all seven organs from a sheet; reordering blocks in-panel then recompiling yields drift=0 (source order untouched).
- `define_block_render_parity_test.gd` — rendering `EventFunction`s as Define-blocks produces byte-identical codegen vs without the view; health.gd regeneration drift=0 before/after.
- `ace_studio_signature_strip_test.gd` — the "Ships as:" formatter matches the compiler's emitted signature for void/bool/typed.
- `ace_studio_card_derivation_test.gd` — each card sets `return_type` NIL/BOOL/typed and the preview lands the row in the matching picker group.
- `empty_body_stub_roundtrip_test.gd` — an exposed verb with an empty body compiles to a valid stub and round-trips at drift=0.
- `expose_gate_test.gd` — opening an existing un-exposed function in the Studio does not silently set `expose_as_ace` (respects `lifted_unannotated`).
- `recipe_scaffold_test.gd` — the Health recipe emits a fully-populated Anatomy that compiles + round-trips; the shared emitter output matches the pack-builder output.

### 8.3 Open questions

1. **Preview icon before addons load** — default glyph vs the resolved `@icon`? (Recommendation: reuse the picker's null-tolerant path.)
2. **Panel width/dock side** — fixed 300px left vs user-resizable, and does it share the dock with the existing side panels?
3. **Recipe library scope this release** — ship Health + Movement + Blank first, add Cooldown/State Machine incrementally?
4. **A/C/E card iconography** — cog/question/`ƒx` glyphs vs colour-only?

---

## 9. Adversarial review — corrections & known gaps

Two independent reviewers (buildability lens + dual-persona lens) verified this spec against the working tree. Their load-bearing corrections are folded into the sections above; recorded here with receipts so they are not re-tripped:

- **`{host.}` host-targeting is BUILT, not "proposed."** The hero bodies (Take Damage / regen tick / host-scoped ACEs) compile code-free *today* — verified: `host_target_codegen_test.gd`, `physics_aces_test.gd`, `{host.}` in `core_aces.gd` / `collision_aces.gd` / `action_codegen.gd` / `condition_codegen.gd`. The parity spec's own status header (`SPEC-behaviour-as-aces-parity.md` "proposed") is STALE — the foundation shipped (5 packs already zero-RawCode). §4/§6.2 depend on this and it is satisfied.
- **`expose_as_ace` lives on the author path, not a compiler guard** — `dock/function_dialog.gd:_apply_function_data:81`; `lifted_unannotated` does not protect it (folded into §7.3 #3 + §8.1).
- **Empty-body stub is type-incorrect today** — `pass` (`sheet_compiler.gd:445`) is valid only for void; bool/typed need a real `return` (folded into §2.4 / §7.2 #5 / Phase 4).
- **"Auto-publish Set/Add/read accessors" was vapor** — no such codegen exists. §6.1 now pitches the honest win (the generic *Set Property/Variable* + *Add Variable* ACEs already address any `@export` via a typed picker). A dedicated per-knob accessor generator is a possible FUTURE enhancement, flagged as NEW/unbuilt — do not present it as existing.
- **Value types: SEVEN, not five.** The Studio's "What kind of value?" (Expression card) must cover all of `float, int, String, bool, Vector2, Vector3, Variant` — map *a number / whole number / text / a point (Vector2) / a 3D point (Vector3)* and keep *anything (Variant)* under an "advanced" fold; do NOT drop Vector3/Variant or a 3D-behaviour author (and the sceptical Godot dev) hits a wall. **Resolve the double-boolean:** a yes/no VALUE belongs on the **Condition** card ("Is it true?"), so the Expression card's value list omits `bool` — one obvious home for a boolean, no ambiguity.
- **Expression badge needs its OWN hue.** The specced violet `(0.30,0.26,0.44)` is the *same* colour already meaning the Inspector-group / `@ace_category` chip (`viewport_row_builder.gd:542`, `:17x`) — reusing it makes an Expression badge and a category chip indistinguishable. Give the Expression role a distinct indigo/magenta (e.g. a lighter, bluer violet) and keep the category chip its established purple.
- **Guards ("Run only when") are free-text GDScript today** (`function_dialog.gd` guard field) — a real CODE-FREE GAP for the C3 refugee. v1: route the guard through the existing friendly condition/expression picker (the same builder the canvas uses) instead of a raw `LineEdit`; until then, mark the guard field "advanced" so a beginner isn't dropped into typing code.
- **Uses organ backing data:** only `host_class` exists on the sheet as first-class data. For v1 the **Uses organ shows the host contract only** (`CharacterBody2D (host)`); sibling-behaviour / autoload dependencies are NEW data (a `requires`/`uses` list on the sheet) — scope them to a later phase, don't imply they round-trip today.
- **Path precision:** `EventFunction` + the compiler/importer live under `addons/eventforge/` (resources/compiler/importer), the editor UI under `addons/eventsheet/` — the two-addon split; citations in §0.1/§7.1 should carry the `eventforge/` prefix.

None of these change the winning frame (Anatomy panel + ACE Studio) or the covenant-safety argument; they sharpen the buildability + the honest code-free reach. Both reviewers' verdict was **needs-fixes on claims, not on the design** — the design itself was assessed sound.

---

## Appendix — MOCKUP BRIEF (the single hero screen to render)

**Screen:** the *Health-behaviour authoring canvas* — the Behaviour Anatomy panel (left) + the logic canvas (right), with the ACE Studio popover open over the Actions organ. It must read at a glance as **beginner-friendly and code-free**: coloured verb cards and a picker preview dominate; the only monospace `func` text is one small, deliberately-secondary "Ships as:" line inside the Studio.

**Overall layout:** a dark editor-themed window. Left column ~300px wide: the **Anatomy panel**. Right: the **logic canvas**. A modal-ish **ACE Studio popover** floats over the centre-left, anchored to the Actions organ's `+Action`, dimming the panel slightly behind it.

**LEFT — Anatomy panel, top to bottom.** A panel header: a small heart glyph + `HealthBehavior` in title weight + a muted subtitle `attaches to CharacterBody2D`. Then seven fixed organ sections, each a slim header row `NAME · count` + organ glyph + a trailing `+`, with a subtle left accent-bar in the organ's hue:

- **PROPERTIES · 2** (blue accent) — two rows: `max_health : int = 100` and `regen_rate : float = 5.0`, each with a small blue `@export` pill and a purple `Health` group chip.
- **STATE · 1** (slate accent) — one row `current_health : int = 100` with a slate `internal` pill, dimmer than the Properties rows.
- **TRIGGERS · 2** (accent-colour bar) — `[trigger] On Damaged  [Health]` with muted `signal on_damaged(amount: int)`, and `[trigger] On Died  [Health]`.
- **ACTIONS · 2** (amber bar) — `[Action] Take Damage  ‹amount: int›  [Health]` with a muted right-aligned `func take_damage(amount: int) -> void`; and `[Action] Heal  ‹amount: int›`. The **`+Action`** footer glows (it's the source of the open popover).
- **CONDITIONS · 1** (teal bar) — `[Condition] ? Is Dead  → bool  [Health]`.
- **EXPRESSIONS · 1** (violet bar) — `[Expression] ƒx Health %  → float  [Health]`.
- **USES · 1** (grey bar) — `[uses] CharacterBody2D (host)` with a CharacterBody2D node glyph.

Empty organs (none in this hero, but show the pattern subtly if space allows) would carry a single ghosted hint row in the organ's hue.

**RIGHT — logic canvas.** Event flows whose header rows echo the organ badge hue. Show, stacked: (1) a regen tick `➜ On Physics Process` → indented `current_health < max_health` (teal condition cell) → `Add current_health  regen_rate * delta` + `Set current_health  min(current_health, max_health)` (amber action cells). (2) An amber-headed **Take Damage** body: `Set current_health = current_health - amount → Emit on_damaged(amount)`, and a sub-event `if current_health <= 0 → Emit on_died()`. Keep the canvas legible and clearly ACE-row-based — no raw GDScript visible.

**CENTRE — the ACE Studio popover** (the crown jewel; make it the visual focus). A themed card titled **"Define an Action"**. Top: **three big colour-coded cards** side by side — **"Does something"** (amber, selected/highlighted, sub-label *Take Damage, Heal, Knock Back*), **"Is it true?"** (teal, *Is Dead, Is Full Health*), **"A value"** (violet, *Health %, Remaining Shields*). The amber card is picked (it was launched from the Actions organ). Below the cards, a compact form: **Name** `Take Damage`, **Description** `Reduce health by an amount`, a **Parameters** row `amount : a number (float)`. 

Down the **right side of the popover**, a panel captioned **"This is what other people will see"** rendering a REAL picker entry in the exact canvas chrome: the behaviour heart icon, an amber `Action` badge, `Take Damage`, a param chip `amount`, a `Health` category chip, and under it a muted one-liner `Health › Take Damage  amount 25`. 

Directly **beneath the preview**, a single small monospace line labelled **"Ships as:"** reading `func take_damage(amount: int) -> void` in muted colour, with a tiny "show annotations ▸" disclosure and a "Copy" affordance. This is the ONLY code-looking text on the whole screen and it is deliberately quiet and secondary. Popover footer: a prominent **Create** button.

**Colour discipline for the mockup:** blue = Property, slate = State, accent = Trigger, amber = Action, teal = Condition, violet = Expression, grey = Uses — consistent between the panel badges, the canvas headers, and the three Studio cards. The eye should land first on the amber-highlighted "Does something" card and the live picker preview, and only find the small "Ships as:" `func` line on a second look — proving the screen reads code-free to the C3 refugee while still spelling out the exact GDScript for the Godot dev.
