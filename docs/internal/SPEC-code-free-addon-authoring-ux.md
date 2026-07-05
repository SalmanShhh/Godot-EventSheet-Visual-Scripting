# SPEC - The Code-free UX: Part I - Authoring the Addon (Behaviour Anatomy + ACE Studio) · Part II - Working Inside the Eventsheet

**Status:** SHIPPED (Parts I and II implemented across the 2026-07 campaign: ACE Studio, Define blocks, edit-in-place verbs, Anatomy panel v2, the Glance/Flow/Navigate/Commit in-sheet layers, error-paste jump, paused-at-row, sheet diff). Kept as the design record and rationale for the in-sheet UX. **Author trigger:** the recurring "isn't this just slower typing / how is this better than Scratch?" critique, and the north-star commitment that *the eventsheets are not done until (1) a stranger's sheet tells you things INSTANTLY, (2) working inside the sheet runs at the speed of thought, and (3) going FULL code-free for a game project is completely possible.* This spec owns the **authoring experience + block-design system** (Part I) **and the in-sheet working experience** (Part II). It cross-references - and does not duplicate:

- [`SPEC-behaviour-as-aces-parity.md`](SPEC-behaviour-as-aces-parity.md) - owns the **vocabulary + function system** (host-targeting `{host.}`, physics/input ACEs, typed function-locals, the three-way expose mapping, param defaults). This UX spec *presents* those primitives; it does not redesign them.
- [`SPEC-behaviour-gdscript-blocks-audit.md`](SPEC-behaviour-gdscript-blocks-audit.md) - owns the **RawCode census + rendering mechanics** (the 783-block audit, the lift chain, which packs keep GDScript and why). This UX spec *renders around* that reality; the numeric-kernel carve-out here is that spec's carve-out.

> Line numbers below are as-of the design investigations; treat them as "look here," not literal offsets. Every load-bearing claim was re-verified against the working tree (§7 receipts for Part I; per-device EXISTS anchors in §11–§14 for Part II). Path convention: the compiler/importer/resources/plugin live under `addons/eventforge/`, the editor UI under `addons/eventsheet/editor/` - citations carry the correct prefix.

---

# PART I - AUTHORING THE ADDON: Behaviour Anatomy + ACE Studio

## 0. North star, the reframe, and the two personas

### 0.1 The reframe

Today a behaviour addon's *public surface* - the Actions, Conditions, Expressions, Triggers and Properties other sheets pick from - is authored as scattered `## @ace_*`-annotated GDScript, discoverable only by scrolling the `.gd`. `health_behavior.gd` ships as one 472-line file with ~205 annotation lines across 38 funcs (audit spec §1). Yet the codebase *already treats the surface as the primary artifact*: auto-discovery keys off `## @ace_*` on signals/methods/`@export` vars; `EventFunction.expose_as_ace` publishes verbs into every picker (`eventforge` resources, `event_function.gd:13`); `ACEDefinition.format_display` + category drive how a row reads.

**The reframe: make that latent truth the centrepiece of authoring.** A behaviour is not a pile of logic - it is an ORGANISM with a fixed body plan whose public organs are what other sheets consume. So the authoring surface is a **Behaviour Anatomy panel**: seven always-visible labelled organs you *fill in* - Properties · State · Triggers · Actions · Conditions · Expressions · Uses - with the logic canvas beside it holding only the tick/lifecycle events. The panel is simultaneously the beginner's fill-in-the-blanks checklist, the expert's class diagram grouped by ROLE (not emission order), and the addon's living API doc. Filling an organ is the whole authoring act; you are never assembling in the abstract, always populating a named part of a known anatomy.

### 0.2 The two personas - the value test

Both must be true or the feature has no reason to exist.

| Persona | Their hardest problem | How the design answers it |
|---|---|---|
| **The C3 refugee** (beginner, non-programmer) | "I opened a blank behaviour - *what am I even supposed to fill in?*" and "Action vs Condition vs Expression - what's a return type?" | The **fixed seven-organ checklist with ghost hints** turns a blank behaviour into a self-teaching form. The **three friendly A/C/E cards** ("Does something / Is it true? / A value") replace return-type jargon. The **live picker preview** shows their published verb exactly as a teammate will see it - the vocabulary (Properties, Triggers, Actions, Conditions, Expressions) is C3's own. |
| **The Godot dev** (expert) | "Why not just type the GDScript? Everything here is slower typing." | The panel **is the class diagram** on one screen (no scrolling a 472-line file). The **generated-signature strip** shows the exact `func` header live, so codegen is never a mystery. The design replaces the tedious, drift-prone parts - hand-maintained `## @ace_*` annotations that silently rot, per-`@export` accessors, host casts, and the compile-attach-open-a-consumer-sheet round-trip to verify the picker - never the thinking. |

**The one-line value payoff (§6 proves it concretely):**
- *For the C3 refugee:* "Fill in seven labelled boxes and watch your behaviour's picker face assemble live - you never see the word `func` or `return type`."
- *For the Godot dev:* "The same code you'd hand-write, with the annotation boilerplate, accessors, call-site refactors and picker registration generated and kept in sync - plus a one-screen API view you'd otherwise reconstruct by scrolling."

### 0.3 Why this frame won (tournament synthesis)

Four philosophies were scored: **Behaviour Anatomy panel** (this one), **Contract-first ACE Studio**, **Everything-is-a-block one canvas**, **Scaffold-and-tune**. The decisive axes were *buildability under the byte-exact round-trip covenant* and *beginner-orientation*, and they cut the same way for the two engineering-lens judges and split narrowly for the two product-lens judges. The Anatomy panel is chosen as the **shell** because it is the only design that sidesteps the covenant hazard structurally: `EventFunction`s live in `sheet.functions`, a *separate* array from `sheet.events`, and `_build_row_from_resource` has no `EventFunction` branch today (verified - §7). Any design that renders Define-blocks *inline in the events tree* must merge two independently-serialised arrays into one ordered visual list and guarantee it never writes that merged order back, or drift=0 breaks. The Anatomy renders organs in a **separate docked panel as a read-model** over the existing resources - it never mutates the events tree - so it dodges the hazard entirely while giving the beginner the fixed checklist that solves the blank-canvas panic.

We then **graft the best ideas from the other three** (each independently reinvented by all four designs, so they are frame-agnostic):

1. **The live picker preview** (crown jewel - all four) - "this is what other sheets will see," rendered in the real picker chrome, updating per keystroke. *(SHIPPED in Phase 1, `21bf936`.)*
2. **The friendly three-card A/C/E selector** (all four) - replaces the return-type question, pre-selected by the clicked organ. *(SHIPPED in Phase 1, `21bf936`.)*
3. **The "Ships as:" generated-signature strip** (contract-first + anatomy) - the cheapest thing that earns the Godot dev's trust. *(SHIPPED in Phase 1, `21bf936`.)*
4. **Contract-shaped recipe scaffolds** built from the existing pack-builders (scaffold-and-tune) - the New Behaviour wizard's step 2, so the beginner lands *reviewing a real API and filling bodies*.
5. **Published-before-implemented** as a supported state (contract-first) - an exposed verb with an empty-but-valid body compiles and round-trips.
6. **Per-block / whole-sheet "Show generated GDScript" fold** (everything-is-a-block) - the always-one-click-away trust surface.

---

## 1. The block-vocabulary design system

Every organ block is built from the **exact shipped span primitives** (`viewport_row_builder._make_span`, `:1191`; badge/chip/`object_label`/`object_icon`/`TEXT_MUTED`) so the panel and canvas read as one system, not a form bolted onto an editor. The A/C/E triad share ONE chrome skeleton distinguished only by badge hue + return chip - so the three-way choice is legible as a colour family, not three unrelated widgets.

| Block | Represents | Chrome / badge / colour / icon | Add + edit | EXISTS vs NEW | Reads to C3 refugee / to Godot dev |
|---|---|---|---|---|---|
| **Property** (Properties organ) | A designer knob | Variable row `name : Type = default` + blue `@export` badge `Color(0.22,0.34,0.55)/(0.76,0.86,1.0)`; purple Inspector-group chip `(0.30,0.26,0.44)` when grouped; typed drawer chip | `+Property` → Variable dialog; double-click to edit | **EXISTS** (`_build_variable_row`, `:449`) | "a setting on my behavior (`max_health = 100`)" / literally `@export var max_health: int = 100` - the blue badge is the Inspector-visibility promise |
| **State** (State organ) | Internal, non-exported variable | Same Variable row **minus** the `@export` badge, **plus** a slate `internal` badge (scaffold greys `(0.18,0.19,0.21)/(0.5,0.52,0.56)`); dimmer row tint | `+State` → Variable dialog (exported=false); double-click | **EXISTS** (same builder, exported=false path) | "a value my behavior remembers but designers don't touch (`current_health`)" / a plain member var, private by convention |
| **Trigger** (Triggers organ) | A published event other sheets react to | **SHIPPED exemplar** - accent `trigger` badge + friendly name (`On Damaged`) in object-label colour + purple category chip + muted `signal on_damaged(amount: int)` | `+Trigger` → signal dialog, `trigger` pre-ticked; double-click | **EXISTS** (`_build_signal_row` trigger branch, `:137`) | "an event other sheets can react to - On Damaged" / a declared signal + its `@ace_trigger` annotation, emitted from my actions |
| **Define-Action** (Actions organ) | A published verb the behaviour DOES - the crown jewel | Warm-**amber** `Action` badge; verb name (`Take Damage`) in object-label colour; typed-param chip strip (`amount: int`); category chip; right-aligned muted signature `func take_damage(amount: int) -> void`; collapsed body preview `ƒ N lines` | `+Action` → **ACE Studio** (§2), drops the block + opens its canvas body | **NEW** rendering (`_build_define_action_row`); data EXISTS (`EventFunction`) | "a thing my behavior can DO that I designed - Take Damage(amount)" / the exact func signature it emits |
| **Define-Condition** (Conditions organ) | A published yes/no test | Cool-**teal** `Condition` badge; `?` glyph; name (`Is Dead`); trailing `→ bool` return chip; category chip; muted `func is_dead() -> bool` | `+Condition` → ACE Studio (Condition card); double-click | **NEW** rendering; data EXISTS (`return_type = TYPE_BOOL`) | "a yes/no question about my behavior - Is Dead?" / a bool getter, callable as a condition in any sheet |
| **Define-Expression** (Expressions organ) | A published value | **Violet** `Expression` badge; `ƒx` glyph; name (`Health %`); trailing typed-value chip `→ float`; category chip; muted `func health_percent() -> float` | `+Expression` → ACE Studio (Expression card, value-type sub-question); double-click | **NEW** rendering; data EXISTS (`return_type = typed`) | "a value my behavior can hand out - Health %" / a typed getter usable inside expressions/parameters elsewhere |
| **Tick / lifecycle** (canvas, NOT panel) | Behaviour-over-time | A normal `EventRow` with a lifecycle trigger (On Ready / On Process / On Physics Process) or a Trigger-organ signal handler; unchanged `➜` trigger badge + condition/action lanes | `+Add event` footer on the canvas; double-click | **EXISTS** (`_build_event_row`) | "every frame, do this" / `_process(delta)` / `_physics_process(delta)` |
| **Loop** (canvas) | Pick-filter iteration | The `For each / Repeat N / While` line in the condition lane | Part of an event's condition lane | **EXISTS** (pick-filter) | "For each enemy" / `for item in ...:` |
| **Uses** (Uses organ) | Composition / dependency - what the behaviour DEPENDS ON | Neutral `uses` badge (scaffold greys) + required class/behaviour name in object-label colour + resolved node icon (`_object_icon_for`); muted `requires` / `optional` tail | `+Uses` → target picker (host class / sibling behaviour / autoload); double-click | **NEW** (small declaration row); host-class field EXISTS on the sheet | "my Health behavior needs a CharacterBody2D host" or "talks to the GameState autoload" / the host-type contract + any `{host.}`/autoload dependency |
| **Organ header** (structural, one per organ) | The panel's spine | Slim section header (`EventSheetPopupUI.section_header` styling) + organ name + live count (`Actions · 2`) + one-glyph organ icon + trailing `+`; empty organs show one ghosted hint row | Fixed - always present | **NEW** (panel chrome) | Makes even a blank behaviour read as a labelled, fillable form for both |

**How the vocabulary reads to BOTH personas as a whole:** scanning the panel top-to-bottom, the refugee reads *seven questions to answer about my behavior*; the dev reads *the class's public surface grouped by role*. The colour ribbon down the badge column (blue Property · slate State · accent Trigger · amber Action · teal Condition · violet Expression · grey Uses) is a legend both learn once. The return-type chips (`→ bool`, `→ float`) make the get/set/test distinction a visible token, not a mental model.

---

## 2. The ACE-definition experience (crown jewel) - the ACE Studio

> **Phase-1 status: the three primitives in §2.1–§2.3 SHIPPED as `21bf936`** - grafted onto the existing `EventSheetFunctionDialog` per the roadmap's Phase 1. §2.4's type-correct empty-body stub remains NEW (see §15).

The Studio opens the moment you press `+Action`, `+Condition`, or `+Expression` on an organ. It **extends the shipped `EventSheetFunctionDialog`** (`function_dialog.gd`), which already carries Name, Description, the `USABLE_AS` three-way, typed params, guards, and the expose card - it does not replace it. The Studio is a themed dialog (`EventSheetPopupUI` `titled_card` / `panel_section`). It reframes and augments the dialog in four ways.

### 2.1 The friendly A/C/E choice (kills "return type")

Today `USABLE_AS` is a single `OptionButton` buried mid-form. Its labels already read friendly (`function_dialog.gd:19-22`, verified):

```
Action (does something - a setter)
Condition (a yes/no test)
Expression (returns a value - a getter)
```

The Studio **promotes this to three big colour-coded cards** the user clicks between - and the organ whose `+` you pressed **pre-selects** the card, so a beginner never meets the distinction cold:

- **"Does something" (Action, amber).** Sub-label: *Take Damage, Heal, Knock Back.* → `return_type = TYPE_NIL`.
- **"Is it true?" (Condition, teal).** Sub-label: *Is Dead, Is Full Health.* → `return_type = TYPE_BOOL`; hides the value-type row.
- **"A value" (Expression, violet).** Sub-label: *Health %, Remaining Shields.* → reveals the existing `VALUE_TYPES` picker relabelled **"What kind of value?"** with plain-English options (*a number / whole number / yes-no / text / a point (Vector2)*).

This is a **pure presentation lift** over the existing `USABLE_AS`/`VALUE_TYPES` - `build_function_data()` already derives `return_type` exactly right (`:285-292`, verified): condition→`TYPE_BOOL`, expression→the chosen `VALUE_TYPES` type, else→`TYPE_NIL`. The Studio only makes the choice loud, colour-matched to the block badges, and organ-anchored. **The decisive twist:** flipping the card visibly MOVES the verb between picker groups in the live preview (§2.2) - the beginner *sees* the consequence of the choice instead of reasoning about types.

### 2.2 The live picker preview (the decisive device)

Down the right side of the Studio is a **"This is what other people will see"** pane that renders a REAL picker entry using the actual row-builder chrome - the same badge/chip/icon language as the canvas - updating on every keystroke: the icon (via the shipped static `ACEPickerDialog.resolve_definition_icon`, verified `static func`, `ace_picker.gd:617`), the verb name, the category chip, the param signature, and a one-line "as it reads in a sheet" mock (`Health › Take Damage  amount 25`). Flip the A/C/E card and the badge + return chip change and the row **jumps to the matching picker group** (Actions → Conditions → Expressions). The non-programmer SEES their API before it exists, in the exact pixels other authors will meet - the antidote to "I defined something invisible."

### 2.3 The Godot-dev "Ships as:" signature strip

Directly under the preview, a monospace, read-only **"Ships as:"** line shows the exact generated `func` signature, live, formatted by a **shared helper bound to `build_function_data()`** (so it can never disagree with the compiler):

```
func take_damage(amount: int) -> void      # Action  "Take Damage"  (category Health)
func is_dead() -> bool                      # Condition
func health_percent() -> float              # Expression
```

A **"show annotations"** disclosure expands the `## @ace_*` lines the expose path emits (`@ace_action` / `@ace_name("Take Damage")` / `@ace_category("Health")`), and a **Copy signature** button lets a dev hand-tune. The dev confirms the codegen at a glance and trusts it.

### 2.4 On confirm

The Studio emits the same `function_confirmed` payload `build_function_data()` produces (extended with the organ hint). The dock creates the `EventFunction` with `expose_as_ace` pre-set true (it IS the behaviour's public API by definition here - **gated**, see §7 covenant so opening an existing un-exposed function never silently re-annotates it), drops the Define-block into the correct organ, and focuses the canvas with a fresh body flow bound to it (`return current_health <= 0` pre-stubbed for a Condition, an empty action flow for an Action). Params entered in the Studio become `ACEParam`-typed arguments available as chips in that body.

**Published-before-implemented is first-class.** The contract exists and is preview-correct BEFORE a single body row is written - you can lay out the whole API, share the picker preview with a teammate, and fill bodies later. The compiler already emits `pass` for a body-less function (`sheet_compiler.gd:445-446`), but `pass` is valid ONLY for a void Action - a body-less **Condition/Expression** compiles to `func is_dead() -> bool:\n\tpass`, which has no return. So the NEW work is a **type-correct** empty-body stub (`return false` for bool, `return <type-default>` for other typed returns) plus a round-trip test covering "exposed verb, empty body, compiles + round-trips at drift=0" (§7, §15).

**EXISTS vs NEW here:** the dialog, three-way, typed params, guards, expose, category, `return_type` derivation - all EXIST. The three-card lead selector, the live picker-preview pane, and the "Ships as:" strip - **SHIPPED `21bf936`**. Still NEW: the empty-body stub codegen.

---

## 3. The authoring canvas + flows

### 3.1 Layout - two regions

- **Left: the Anatomy panel** - a docked, resizable, always-visible column (~300px), seven collapsible organ sections in fixed order Properties → State → Triggers → Actions → Conditions → Expressions → Uses. Each organ has a slim header (name · live count · icon · `+`) and, when empty, a single ghosted hint row.
- **Right: the existing virtualized canvas** - now holding ONLY tick/logic events (lifecycle events, signal handlers, regen loops) plus the *bodies* of the defined verbs. Clicking a Define-block in the panel scrolls the canvas to that verb's body flow and pulses it; the body's header row echoes the organ badge so the wiring is obvious. Hovering a canvas event that emits a Trigger-organ signal, or calls a Define-Action, highlights that organ block.

### 3.2 Discovery / add model - no palette, no scatter

Every add originates from an organ's `+`. `+Property`/`+State` → Variable dialog. `+Trigger` → signal dialog (trigger pre-ticked). `+Action/+Condition/+Expression` → ACE Studio (drops a Define-block + opens its canvas body). `+Uses` → target picker. This is the whole discovery story: you don't hunt for what to add - the anatomy lists the seven kinds of thing a behaviour can have, and each says `+`. A first-timer reads the panel top-to-bottom as *here are the seven questions to answer about my behavior.* Empty organs are never blank - each shows a hint line in its hue (*"No conditions yet - +Condition adds a yes/no question others can ask"*), reusing the shipped `_build_add_event_footer_row` pattern (`:71`).

### 3.3 New Behaviour wizard

Replaces the bare behaviour-component starter drop. **Step 1 - "What does it attach to?"** (host class picker → sets `host_class`, feeds the first Uses block: CharacterBody2D / Node2D / Area2D / Node, + 3D twins). **Step 2 - "Start from a recipe?"** - contract-shaped scaffolds that PRE-FILL organs with real blocks and **empty-but-valid bodies** (so a beginner lands reviewing a real API and filling bodies, per the published-before-implemented graft): *Health, Movement, Cooldown, State Machine, Blank.* Each recipe is **authored by the existing pack-builders** (`tools/pack_builders/health.gd`, `eight_direction.gd`, …) factored into shared static scaffold emitters callable both at pack-build time and in-editor - reusing proven pack shapes and turning the packs into a curriculum for free. The user lands in a fully-populated Anatomy they can edit, learning the body plan by seeing a complete specimen.

### 3.4 Inline editing

Double-click any panel block to reopen its authoring dialog. Rename in the Studio triggers a refactor-safe rename across the sheet (call sites resolve by name). Drag to reorder within an organ **moves the underlying resource in its array** - a real edit that round-trips (variables, signals, and functions all serialise in array order), NOT a hidden display order. You can only reorder *within* an organ (each holds one resource type), so it never violates the compiler's canonical section order. Right-click an organ block → Go to body / Duplicate / Delete / Show generated code.

### 3.5 "Show the code / what ships" reassurance

A persistent panel-footer toggle **"Show generated GDScript"** opens the compiler's output for the whole class read-only, with the selected organ block's lines highlighted - so a Godot dev can, at any moment, see that "Take Damage" really is the func they'd have written. A per-block **`</>` fold** reveals just that block's compiled lines inline. The **RawCodeRow escape hatch** is always available for a body that genuinely wants hand-code (the numeric-kernel carve-out of the audit spec §5.4 - spring integrators, `HealthPool` decay), rendered as a marked amber "⚠ code" block: it is visibly the *exception*, no longer the default way to express a verb.

---

## 4. The hero screen - a Health behaviour authored entirely in blocks

Left panel top-to-bottom, canvas on the right. This drives Mockup Brief 1 (appendix).

**PANEL HEADER:** `HealthBehavior` with a small heart `@icon`, subtitle *attaches to CharacterBody2D.*

- **PROPERTIES · 2** - two blue-`@export`-badged Variable blocks: `max_health : int = 100` and `regen_rate : float = 5.0`, both carrying a purple **Health** Inspector-group chip. Two tunable Inspector knobs.
- **STATE · 1** - one block, no blue badge, slate `internal` badge: `current_health : int = 100`. The value the behaviour remembers.
- **TRIGGERS · 2** - two shipped-style trigger blocks: `[trigger] On Damaged [Health] · signal on_damaged(amount: int)` and `[trigger] On Died [Health] · signal on_died()`. Events other sheets react to.
- **ACTIONS · 2** - two amber Define-Action blocks: `[Action] Take Damage · amount: int · func take_damage(amount: int) -> void`; `[Action] Heal · amount: int · func heal(amount: int) -> void`. Both carry the Health category chip.
- **CONDITIONS · 1** - one teal block: `[Condition] Is Dead · → bool · func is_dead() -> bool`.
- **EXPRESSIONS · 1** - one violet block: `[Expression] Health % · → float · func health_percent() -> float`.
- **USES · 1** - one neutral block: `[uses] CharacterBody2D (host)` with the body glyph.

**CANVAS (right)** - the tick logic + the bodies of the defined verbs, as normal event flows whose headers echo their organ badge:

- Regen tick: `➜ On Physics Process → [condition] current_health < max_health → [action] Add current_health  regen_rate * delta → [action] Set current_health  min(current_health, max_health)`.
- Body of **Take Damage** (amber header): `Set current_health = current_health - amount → Emit on_damaged(amount) → sub-event: if current_health <= 0 → Emit on_died()`.
- Body of **Heal**: `Set current_health = min(current_health + amount, max_health)`.
- Body of **Is Dead**: `return current_health <= 0`.
- Body of **Health %**: `return float(current_health) / float(max_health) * 100.0`.

**What the user SEES overall:** a labelled specimen. The left panel is a one-screen contract - *this behaviour has 2 knobs, remembers 1 value, fires 2 events, can do 2 things, answers 1 yes/no, hands back 1 number, and needs a CharacterBody2D.* Not one line was typed as freeform code; every organ was filled via `+`.

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
| Expression | violet `(0.30,0.26,0.44)` | shipped category/Inspector chip purple (see §9 - needs its OWN hue) |
| Uses | neutral grey + node icon | `_object_icon_for` |

The SAME hues reappear on the canvas body-flow headers, tying logic to anatomy. **Chrome consistency:** every panel block is built from the exact `_make_span` badge/chip primitives (`badge` + `badge_style` + `badge_bg/fg`; `chip` for cells; `object_label`/`object_icon`; `TEXT_MUTED` for the "ships as" tail) - no new rendering path, so the panel and canvas look like one system. **Return-type chips** (`→ bool` / `→ float`) make the invisible visible. **Discoverability:** empty organs show one ghosted hint row in their hue; the seven fixed labels + counts turn the panel into a progress checklist; a subtle left accent-bar per organ (like the shipped GROUP accent bar) segments the panel; first run drops a one-time coach-mark on the Actions organ - *"This is your behavior's public API - fill these and other sheets can use it."* It looks obviously code-free because the eye sees coloured verb cards + a picker preview, not `func`/`signal`/`@export`; it stays legible to a dev because every card's muted tail and the Show-GDScript fold spell out the exact GDScript.

> **The One-Legend Colour Law (promoted from Part II's tournament - a spec LAW, not a device):** this role family (`event_sheet_palette.gd:57-75` - the just-landed ACE-role hues) is the SINGLE legend across ALL surfaces: Studio cards, picker groups, Anatomy organ bars, canvas body headers, and every Part II glance device (banner pills, tempo badges, group fingerprints, typed value tints). New hues are minted ONLY as named `EventSheetPalette` constants (Part II adds four tempo hues and at most two typed-value hues); hardcoded `Color(...)` literals in `viewport_row_builder.gd` (e.g. the category-chip purple at `:178`, the `@export` blue at `:517`) migrate to the named constants so the law is lintable via a palette-constants sweep. Enforcement is an audit + test (§15), not a ranked feature.

---

## 6. Why not just GDScript

### 6.1 Capability-by-capability

| Capability | Hand-GDScript way | The eventsheet way | The win |
|---|---|---|---|
| **Declare a designer knob** | `@export var max_health: int = 100`, then `@export_range`/`@export_group`/tooltip annotations looked up + typed | `+Property` → Variable dialog: type, range drawer, group chip | typo-free, refactor-safe; grouping is a chip not remembered annotation syntax (**speed + refactor-safety**) |
| **Publish a trigger event** | `signal on_damaged(amount: int)` + a hand-written `## @ace_trigger`/`@ace_name`/`@ace_category` trio (easy to fat-finger → silently NOT published) | `+Trigger`, signal dialog, trigger pre-ticked | the block writes the annotation correctly every time and publishes to pickers (**correctness + discoverability**) |
| **Publish an Action/Condition/Expression** | `func` + ~4 lines of `## @ace_*` annotation per verb, kept in sync by hand; rename = edit func + comment + every caller | ACE Studio: friendly card + typed params → generated func + annotations in lockstep; rename refactors published name + call sites together | annotation boilerplate generated and kept in sync; rename is refactor-safe (**the biggest win - reuse + refactor-safety**) |
| **Choose the picker category (return type)** | Remember `void→action, bool→condition, else→expression` and hand-tune return types to land in the right group | Three cards; the derived signature is shown | the rule is encoded so even an expert never misfiles a getter as an action (**correctness**) |
| **Read/modify a knob from another sheet** | Remember the exact property name + hand-write accessors | The knob is addressable by the generic *Set Property* / *Set Variable* / *Add Variable* ACEs via a typed picker - no accessor funcs (these ACEs already exist; a dedicated per-knob Set/Add/read is NOT auto-published today - see §9) | no per-knob boilerplate, typo-free (**reuse**) |
| **Verify the consumer's picker** | compile → attach → open a consumer sheet → check the picker | Live picker preview, at author time | API review without a round-trip (**speed + discoverability**) |
| **Target the host node** | `(get_parent() as CharacterBody2D).move_and_slide()`, host casts scattered through the body | `{host.}` idiom (parity spec §2.1) + the Uses block documenting the contract | host contract explicit and checkable (**correctness**) |
| **See the whole public surface** | Scroll a 472-line `.gd`, reconstruct the API mentally | The Anatomy panel - grouped by role, one screen | a genuinely new artifact you can't get by scrolling (**discoverability**) |

The honest limit (from the audit spec §5.4): for a tight numeric kernel - a spring integrator, `HealthPool` decay - GDScript reads better, and it stays a marked RawCode block on purpose. The pitch to the sceptic is never "slower typing"; it's *the same code with the drift-prone, refactor-hostile, discovery-hiding parts done for you and kept in sync.*

### 6.2 The C3-beginner zero-code path, end to end

1. **New Behaviour** → "attaches to CharacterBody2D" → pick the **Health** recipe. Lands on a fully-populated Anatomy - seven labelled organs already holding real blocks, in C3's own vocabulary. The picker preview on the right looks exactly like a C3 behaviour picker.
2. **Tune a knob:** click `max_health`'s value cell, type `250`. It shows in the Inspector; no code.
3. **Add a verb:** `+Action` → the three cards → "Does something" → name it **Knock Back**, add a param `force: float`, watch the preview render `Health › Knock Back  force` exactly as other sheets will see it → confirm. A body flow opens; fill it with Set/Add actions.
4. **Add a test:** `+Condition` → "Is it true?" → **Is Shielded** → preview shows the `→ bool` chip.
5. **Expose a value:** `+Expression` → "A value" → **Shield %** → pick *a number (float)*.
6. **Compile and attach** - a shippable behaviour, no GDScript touched. They never saw the words `return type`, `func`, `signal`, or `@export`.

The four beginner cliffs and their structural prevention: (1) *what do I fill in?* → the fixed seven organs + ghost hints; (2) *Action vs Condition vs Expression?* → cards with verbs and examples, pre-selected by the organ; (3) *what did I just make?* → the live picker preview; (4) *a body that needs math* → the marked amber "⚠ code" escape hatch, visibly the exception, with recipes steering to ACE rows first.

---

## 7. Buildability + covenant

### 7.1 EXISTS (reuse directly)

- The whole badge/chip/icon block language: `viewport_row_builder._make_span` (`:1191`), `_build_signal_row` (`:137`), `_build_variable_row` (`:449`), `_build_add_event_footer_row` (`:71`), `_build_scaffolding_strip_row` (`:39`).
- The Trigger block - **SHIPPED verbatim** (`_build_signal_row` trigger branch).
- Property/State blocks - Variable row + `@export` badge + Inspector-group chip already exist.
- The A/C/E logic + typed params + expose: `function_dialog.gd` `USABLE_AS` (`:19-22`, friendly wording verified) + `build_function_data()` deriving `return_type` void/bool/typed (`:285-292`, verified) + `EventFunction.expose_as_ace`/`ace_display_name`/`ace_category`/`params`/`return_type`/`events` (`:13-31`, verified).
- Picker icon: `ACEPickerDialog.resolve_definition_icon` - **verified `static func`** (`ace_picker.gd:617`).
- Themed dialogs: `EventSheetPopupUI` `titled_card`/`panel_section`/`section_header`.
- Recipe scaffolds: the pack-builders (`tools/pack_builders/*.gd`) factored into shared static emitters.
- Byte-exact round-trip: organ blocks are pure PRESENTATIONS of existing resources (`LocalVariable`/`SignalRow`/`EventFunction`), so the `.gd` stays the source of truth - nothing new needs serializing.
- **Phase-1 primitives (now EXISTS, `21bf936`):** the three A/C/E verb-kind cards, the live picker preview, the "Ships as:" strip on `function_dialog.gd`.

### 7.2 NEW (RefCounted helpers + dock delegates, matching the extraction pattern in memory: RefCounted helper + `_host` back-ref + thin delegate)

1. **`BehaviourAnatomyPanel`** - a `Control` that, given the sheet, buckets its resources into the seven organs; a `_host` back-ref to the dock for `+` actions. **Mechanism (adversarial correction):** `ViewportRowBuilder` is hard-bound to a viewport-shaped host (`_viewport._fold_state` `:46`, `_viewport._get_event_style()` `:109`, `_viewport._breakpoint_rows`…), so the panel cannot call it directly - instead it **embeds a slim read-only `EventSheetViewport`** (organ headers as synthetic section rows, blocks as its rows), getting the renderer, virtualization, hover, and the exact span chrome for free while staying covenant-safe (same read-model, zero writes).
2. ~~**`ACEStudioDialog`**~~ - **SHIPPED `21bf936`** as primitives grafted onto `EventSheetFunctionDialog` (cards + preview + "Ships as:").
3. **New `badge_style`s** `ace_action`/`ace_condition`/`ace_expression` + return-type `→ T` chip rendering (small additions to the badge_style switch).
4. **`NewBehaviourWizard`** - two-step dialog producing a recipe `EventSheetResource` from the shared scaffold emitters.
5. **Type-correct empty-body stub codegen** - the compiler already emits `pass` for a body-less function (`sheet_compiler.gd:445`), valid only for a void Action; NEW is emitting `return false` (bool) / `return <type-default>` (other typed returns) for a body-less Condition/Expression so published-before-implemented compiles + round-trips.
6. **Panel↔canvas cross-highlight** - map an organ block to its `EventFunction`/`EventRow` body and pulse it.

> Note: the crucial NEW piece is rendering `EventFunction`s as first-class definition blocks. Verified: `_build_row_from_resource` (`event_sheet_viewport.gd:1617-1639`) branches on Group/Comment/LocalVariable/RawCode/Enum/Signal/Event and has **NO `EventFunction` branch** - functions render only via the picker today. Because the Anatomy renders them in a **separate panel**, not inline in the events tree, this is a pure VIEW over `sheet.functions` and never touches the events array's source order.

### 7.3 Covenant risks

1. **Read-model discipline (the primary risk).** The panel must be a READ MODEL over the resources - if a `+` ever writes state the compiler doesn't already round-trip, drift appears. Keep every organ block backed by an existing resource type only. Because functions live in `sheet.functions` (a *separate* array from `sheet.events`), the panel renders that array directly and **never merges function display-order into the events array** - this is exactly why the panel frame was chosen over an inline-tree frame.
2. **Reorder edits the resource array, never a hidden display order.** Variables/signals/functions serialise in array order, so reordering a block within its organ IS a legitimate source edit - persist it by moving the resource in its array (it round-trips). The covenant trap is a *parallel* display order the compiler doesn't read: forbid it - panel order must always equal the backing array. Verify with a "reorder-in-panel → recompile → reopen → same order" round-trip test.
3. **`expose_as_ace` on the AUTHOR path must preserve existing state.** The Studio creates/edits the `EventFunction` through `dock/function_dialog.gd:_apply_function_data` (`:81` assigns `expose_as_ace` from the payload). A NEW verb IS the behaviour's public API → set true. But the **edit-existing** path must LOAD the function's current `expose_as_ace` and preserve it unless the user explicitly flips it - never blanket-set true on open, or a hand-authored un-exposed helper silently gains `## @ace_*` annotations (a drift + surprise). NOTE: `lifted_unannotated` is a COMPILER-side guard for *lifted* funcs and does **not** protect this author path - so preserve-on-edit is a genuine NEW requirement in `_apply_function_data`, not something already handled.
4. **Empty-body stub must compile + round-trip.** Published-before-implemented requires a codegen stub and a dedicated test: "exposed verb, empty body, compiles + round-trips at drift=0."
5. **"Ships as:" must format identically to the compiler.** Share one signature helper, or the dev sees a lie.
6. **Icon resolution must be headless-safe.** `resolve_definition_icon` may see a null icon before addons load - already null-tolerant in the picker path; reuse it, don't reimplement.

---

## 8. Part I roadmap - status ledger

> **Superseded as a standalone sequence:** Phase 1 SHIPPED; Phases 2–6 are merged into the single leverage-ordered roadmap in **§15**, interleaved with Part II's devices. This section stays as the record of the original phasing + what each phase contains.

1. **Phase 1 - Graftable primitives on `function_dialog.gd`. ✅ SHIPPED `21bf936`.** The three A/C/E cards (presentation over `USABLE_AS`), the live picker preview pane (reuse `resolve_definition_icon`), the "Ships as:" signature strip (shared formatter over `build_function_data()`). These landed on the existing Add-Function flow and immediately answer "slower typing."
2. **Phase 2 - Define-block rendering + badge styles.** `_build_define_action_row`/`_condition`/`_expression` as spans; new `badge_style`s + `→ T` chips. Pure view over `EventFunction`; parity test that codegen is byte-identical with or without the view (health.gd drift=0 regeneration before/after). *(→ §15 Wave 1.)*
3. **Phase 3 - The Anatomy panel.** `BehaviourAnatomyPanel` read-model, the seven fixed organs + ghost hints + `+` footers, panel↔canvas cross-highlight. Read-model discipline tests. *(→ §15 Wave 2 - shares the left-rail slot with Part II's Outline tab, context-picked.)*
4. **Phase 4 - Empty-body stub codegen + published-before-implemented.** Stub emission + round-trip test. *(→ §15 Wave 3.)*
5. **Phase 5 - New Behaviour wizard + recipe scaffolds.** Factor pack-builders into shared static emitters; two-step wizard; recipes land on a fully-populated Anatomy with empty-but-valid bodies. *(→ §15 Wave 3.)*
6. **Phase 6 - Docs + coach-marks + version bump.** `docs/GUIDE-../GUIDE-RECIPES.md` recipe + showcase sheet; first-run coach-mark; regenerate; drift=0. *(→ §15 Wave 4.)*

*(Files-to-touch and tests for these phases are folded into §15.2/§15.3.)*

### 8.1 Open questions (Part I)

1. **Preview icon before addons load** - default glyph vs the resolved `@icon`? (Recommendation: reuse the picker's null-tolerant path.)
2. **Panel width/dock side** - fixed 300px left vs user-resizable, and does it share the dock with the existing side panels? *(Part II answers the slot question: one left rail, tabbed - Open Sheets / Outline / Anatomy, context-picked. See §13.3.)*
3. **Recipe library scope this release** - ship Health + Movement + Blank first, add Cooldown/State Machine incrementally?
4. **A/C/E card iconography** - cog/question/`ƒx` glyphs vs colour-only?

---

## 9. Adversarial review - corrections & known gaps (Part I receipts)

Two independent reviewers (buildability lens + dual-persona lens) verified this spec against the working tree. Their load-bearing corrections are folded into the sections above; recorded here with receipts so they are not re-tripped:

- **`{host.}` host-targeting is BUILT, not "proposed."** The hero bodies (Take Damage / regen tick / host-scoped ACEs) compile code-free *today* - verified: `host_target_codegen_test.gd`, `physics_aces_test.gd`, `{host.}` in `core_aces.gd` / `collision_aces.gd` / `action_codegen.gd` / `condition_codegen.gd`. The parity spec's own status header (`SPEC-behaviour-as-aces-parity.md` "proposed") is STALE - the foundation shipped (5 packs already zero-RawCode). §4/§6.2 depend on this and it is satisfied.
- **`expose_as_ace` lives on the author path, not a compiler guard** - `dock/function_dialog.gd:_apply_function_data:81`; `lifted_unannotated` does not protect it (folded into §7.3 #3 + §15).
- **Empty-body stub is type-incorrect today** - `pass` (`sheet_compiler.gd:445`) is valid only for void; bool/typed need a real `return` (folded into §2.4 / §7.2 #5 / §15 Wave 3).
- **"Auto-publish Set/Add/read accessors" was vapor** - no such codegen exists. §6.1 now pitches the honest win (the generic *Set Property/Variable* + *Add Variable* ACEs already address any `@export` via a typed picker). A dedicated per-knob accessor generator is a possible FUTURE enhancement, flagged as NEW/unbuilt - do not present it as existing.
- **Value types: SEVEN, not five.** The Studio's "What kind of value?" (Expression card) must cover all of `float, int, String, bool, Vector2, Vector3, Variant` - map *a number / whole number / text / a point (Vector2) / a 3D point (Vector3)* and keep *anything (Variant)* under an "advanced" fold; do NOT drop Vector3/Variant or a 3D-behaviour author (and the sceptical Godot dev) hits a wall. **Resolve the double-boolean:** a yes/no VALUE belongs on the **Condition** card ("Is it true?"), so the Expression card's value list omits `bool` - one obvious home for a boolean, no ambiguity.
- **Expression badge needs its OWN hue.** The specced violet `(0.30,0.26,0.44)` is the *same* colour already meaning the Inspector-group / `@ace_category` chip (`viewport_row_builder.gd:542`, `:17x`) - reusing it makes an Expression badge and a category chip indistinguishable. Give the Expression role a distinct indigo/magenta (e.g. a lighter, bluer violet) and keep the category chip its established purple.
- **Guards ("Run only when") are free-text GDScript today** (`function_dialog.gd` guard field) - a real CODE-FREE GAP for the C3 refugee. v1: route the guard through the existing friendly condition/expression picker (the same builder the canvas uses) instead of a raw `LineEdit`; until then, mark the guard field "advanced" so a beginner isn't dropped into typing code.
- **Uses organ backing data:** only `host_class` exists on the sheet as first-class data. For v1 the **Uses organ shows the host contract only** (`CharacterBody2D (host)`); sibling-behaviour / autoload dependencies are NEW data (a `requires`/`uses` list on the sheet) - scope them to a later phase, don't imply they round-trip today.
- **Path precision:** `EventFunction` + the compiler/importer live under `addons/eventforge/` (resources/compiler/importer), the editor UI under `addons/eventsheet/` - the two-addon split; citations carry the `eventforge/` prefix where applicable.

None of these change the winning frame (Anatomy panel + ACE Studio) or the covenant-safety argument; they sharpen the buildability + the honest code-free reach. Both reviewers' verdict was **needs-fixes on claims, not on the design** - the design itself was assessed sound.

---

# PART II - WORKING INSIDE THE EVENTSHEET

## 10. The reframe v2 + the three bars

### 10.1 The reframe v2

Part I made the *addon* authorable code-free. Part II makes the *sheet* the place both personas actually LIVE - reading, writing, navigating, debugging, and committing a whole game without being forced out. The second tournament designed four independent dimensions and the judges' verdict is that they compose into one coherent story:

- **The Glance layer (§11)** makes any sheet readable in 5 seconds - pure read-models over data that already exists (`trigger_id`, ACE descriptors, `expose_as_ace`, exports), zero new serialized state.
- **The Flow layer (§12)** makes authoring *faster than C3 and faster than typing GDScript* on the three loops a jam repeats a thousand times - convergence of shipped machinery (quick-add brain, custom-draw editor, inline popup, single-key grammar), not new machinery.
- **The Navigate layer (§13)** makes a 20-sheet project explorable - F12/Shift+F12/Alt+Left parity for the dev, "behaviours are not black boxes" for the refugee; almost entirely glue over shipped primitives.
- **The Commit layer (§14)** makes "go full code-free for a game project" an *honest sentence* - the drift=0 covenant turns the committed `.gd`'s line numbers into a stable row coordinate system, so git and the debugger map losslessly onto rows. Today the code-free promise verifiably breaks at exactly two moments (a runtime break/error dumps you into generated GDScript; a merge conflict makes the sheet unopenable) - §14 closes them.

**The deepest architectural insight of the tournament (all four judges):** because Doctor proves the committed `.gd` is byte-identical to what the sheet recompiles to (`addons/eventforge/project_doctor.gd:64-82`), and the compiler already emits a per-row `source_map` of `{uid, start, end, kind}` (`addons/eventforge/compiler/sheet_compiler.gd:67/:161/:206-447`), **one ~100-line mapper helper turns line numbers ↔ rows into shared infrastructure** that powers runtime-error→row, paused-at-row, sheet diff, and (later) blame. Caveat carried from verification: `source_map` uids are `get_instance_id()` strings - perfect for *live* line→row mapping computed against the open sheet, **never valid as persistent anchors** across reloads (any history/bookmark state must use path + uid + flat-index fallback).

### 10.2 The three bars (every Part II device must clear at least one)

1. **The 5-second test (instant comprehension).** Open a stranger's sheet: within 5 seconds it must answer *what is this sheet / what does it publish*, *how often does each event run*, and *what does each row do in plain English* - with zero clicks. §11.3 runs this test on the real shipped sheets.
2. **Speed-of-thought editing.** The common loop - add event → add action → tune a number → add another - must cost fewer keystrokes than Construct 3's legendary editor AND fewer total actions than typing the equivalent GDScript (counting navigation, `$Health.` prefixes, and API recall), with **zero dialogs** on the common path. §12.4 shows the arithmetic.
3. **The full-project code-free bar.** A team must be able to author, debug, error-diagnose, refactor, review, merge, and CI-gate an entire game without ever being *forced* to read generated GDScript. §14's viability matrix audits this capability-by-capability and ends with the ranked must-land list.

### 10.3 The two personas, restated for the IN-SHEET context

| Persona | The in-sheet question they're really asking | The Part II answer |
|---|---|---|
| **The C3 refugee** | "Does this feel as fast and as readable as home - and does it fix what C3 never could (black-box behaviors, no diff/blame/merge, no bulk retune, getting lost in a teammate's project)?" | Every glance device lands on a C3 mental model they already own (the green arrow, collapse-to-skim, events-read-as-sentences); the Ghost Row is C3's beloved type-to-filter Add dialog *with the dialog deleted*; Ctrl+Click opens a behaviour AS A SHEET (C3 structurally cannot); errors/pauses/diffs speak event-language, never code. **C3-does-it-better flags honoured (§12.6):** the full picker stays one chord away (C3's Add dialog doubles as a browsable illustrated catalog); Param Hop renders a param-name hint at the cursor (C3's params dialog shows every param with help); any outline/rail preserves the whole-row reading unit (C3's condition/action columns never scroll independently). |
| **The Godot dev** | "Why would I not just open the script editor? F12, Alt+Left, git, the debugger, and my profiler all live there." | F12/Shift+F12/Alt+Left/Ctrl+P land verbatim (§13) - and the F12 jump crosses the consumer-sheet→behaviour boundary the script editor can't. The sheet becomes *better-tooled than hand-written scripts*: errors arrive pre-joined to semantic rows, stepping is event-granular, diffs are semantic, and drift=0 means git/grep/script-editor all still work - Part II is strictly additive over files they already own. Without §13 the dev walks (Alt+Left absence is disqualifying); with §14 the sheet is the *only* editor whose files are byte-verified against their own recompile. |

---

## 11. The glance layer - instant comprehension on the canvas

**Design law:** every glance device is a **read-model over verified existing data** - build-time span metadata + custom-draw additions, zero per-row widgets, zero new serialized state, zero round-trip surface. The calm covenant is enforced by cuts (§11.4): no device may add marks that answer rarely-asked questions.

### 11.1 Winning devices

| Device | What / where | EXISTS vs NEW | Reads to C3 refugee / to Godot dev |
|---|---|---|---|
| **Trigger tempo badges** ⟳ / ➜ / ⌨ / ▶ | The single green trigger badge splits into four classes derived purely from `event_row.trigger_id`: **⟳ EVERY-TICK** (`OnProcess`/`OnPhysicsProcess`/post-tick twins - `addons/eventforge/compiler/trigger_resolver.gd:28-45`) hot amber-orange; **➜ SIGNAL** (`signal:*`/`OnSignal`/`OnBodyEntered`/`OnTimeout`… `:50-85`) keeps C3 green; **⌨ INPUT** (`OnInput`/`OnUnhandledInput`) object blue; **▶ ONCE** (`OnReady`/`OnEditorRun`) muted violet. The condition-less "Every Tick" placeholder chip gets ⟳ too. Lives in the existing condition-lane badge column. | EXISTS: `trigger_id` on every `EventRow` + the exhaustive id census in `TriggerResolver.resolve_trigger` + the `badge_style` pipeline (`viewport_row_builder.gd:598-673`). NEW: a static `_trigger_class_for(trigger_id)` **co-located in `trigger_resolver.gd`** so the two match statements can't drift + an exhaustiveness unit test (every id in `resolve_trigger` has a class; unknown → SIGNAL, the honest default) + 4 tempo hues as `EventSheetPalette` constants. | "⟳ is my Every-tick event" - the taxonomy C3 vets reconstruct by hand on every event, never again / `_physics_process` reachability visible from ANY row - the #1 perf-comprehension fact as one glyph. *Judges: highest value-per-line device in the portfolio; ranked top-2 by all four.* |
| **The Publishes Manifest** (banner pills) | A second line on the `SheetIdentityBanner` (`addons/eventsheet/editor/sheet_identity_banner.gd`, 24px custom-draw → ~40px when the sheet publishes): role-hued count pills `➜ 4 triggers · ⚡ 4 actions · cond 6 · ƒx 3 · @ 17 knobs`, computed once in `update_from_sheet` from trigger-flagged `SignalRow`s, `sheet.functions` with `expose_as_ace`, exported variables, and `@ace_*`-annotated funcs via the registry. Pill click = **jump to the first row of that role** (v1 - the role-filtered find bar was cut as silent scope creep). | EXISTS: the banner control + click plumbing, all count sources, the palette role family. NEW: the second draw line + per-pill hit-rects + the count query. **Judge's legibility cut applied:** conditions get a teal `cond` pill, NOT a bare `?` glyph (reads as "help" at 13px). | The behavior's ACE dictionary - the thing C3 shows only inside the picker - pinned above the sheet / the class's public API without scrolling 233 lines; today's equivalent is Ctrl+F `@ace_` and counting 38 hits. |
| **Group chapter fingerprints** | One right-aligned muted span on group headers: `12 events · ⟳2 · ➜5 · ⚠1` - children counted by tempo class + unlifted ⚠-code blocks, computed during the existing child-build loop (`_build_group_row`, `viewport_row_builder.gd:280-330`, children already in hand). A COLLAPSED group still tells you its weight and hotness - fold-all becomes a genuine table of contents. **Honesty note (§16): neither flagship pack ships with groups today (zero `# @group:` markers in both), so this device has nothing to bite on there until the flagship-pack grooming task lands (§15.1 Wave 1: add Movement/Reactions groups to the pack builders - a CONTENT task, not code).** It bites immediately on grouped user sheets + the showcases. | EXISTS: fold state, accent bars, per-group colours, the child loop. NEW: one span + the counting pass (same `_trigger_class_for` string match) + the pack-grooming content task. | Collapse-to-skim, C3's habit, finally *informative* (C3's collapsed groups are opaque title bars) / a `#region` fold that summarizes what's inside - the script editor's folds show nothing. |
| **Row-as-sentence hover** | Whole-row hover (exists - `_hovered_row_index`) leads the tooltip with the row read as ONE plain-English sentence, assembled by a stateless `ViewportTooltipHelper.row_sentence(event_row)`: *"When On Jumped - if NOT Is Wall Sliding - do: Play "jump", Set animation "jump" (+1 more)."* Built **exclusively** from the same `_format_condition_descriptor`/`_format_action_descriptor` strings the cells draw (`viewport_row_builder.gd:1105-1162`) joined with When/if/OR/do connectives - so the sentence can NEVER disagree with the pixels. **The raw-block rule (adversarial finding, §16):** in-flow RawCode actions have NO descriptor string, so the sentence summarizes them honestly as `…, then N lines of code` - it never invents prose for raw statements; the FULL sentence experience therefore only exists on lifted rows, which is one more reason the audit spec's lift roadmap matters. Second tooltip line keeps the hovered-cell description; the shipped codegen-preview fallback (`event_sheet_viewport.gd:2418-2427`) stays for the dev. Tooltip-only → covenant-untouchable by construction. Keyboard twin: the selected row's sentence on a keypress. (The Alt-hold "sentence pin" sub-feature is folded into implementation if free - not specced.) | EXISTS: the tooltip path, the descriptor formatters, whole-row hover. NEW: one stateless helper method. | C3's core literacy - reading events as sentences - extended to rows they didn't author, in the exact When/if/do vocabulary they think in / the docstring the original author never wrote, generated from structure so it can't rot - with the literal GDScript preview kept on line two. |
| **Typed value tinting** | The shipped value-highlight pass (`_value_ranges_for` regex → `_draw_text_with_values`, `viewport_row_builder.gd:1171-1182` / renderer `:506-536`) lumps numbers, strings, booleans into ONE colour; its three regex alternates already distinguish them. NEW: return `[start, len, kind]` and tint by kind. **Judge's trim applied: two new hues max**, chosen inside the One-Legend Colour Law audit (§5) - the proposed soft-amber string tint collided with the amber action badge + amber ⚠ family; amber is the most overloaded hue in the system. "Where are the magic numbers" becomes a colour question. | EXISTS: the entire pipeline incl. per-range draw, build-time-only by design. NEW: a kind tag per range + ≤2 named palette constants. | "the coloured parts are what I typed into the dialog" / syntax highlighting for parameter text - the one glance feature devs refuse to live without. |
| **Sheet health strip** *(commit-layer device, lives on the banner - specced here for banner-layout arbitration)* | Three live chips on the banner's right end: `✓ compiles · ✓ in sync · N flagged` (click = jump to first flagged row). The *absence* of marks is the 5-second-test answer on a healthy sheet. **Cost law (§16): the `✓ in sync` (drift) chip is pinned to SAVE-TIME results** - `dock/sheet_io.gd` already compiles on save; while editing, the chip shows a muted `· edited` state, never an ambient recompile (byte-identity proof = full compile + file read + compare; forbidden as a keystroke-follower on large sheets). The diagnostics chips may refresh debounced (cheap analyze). | EXISTS: every check (`EventSheetDiagnostics.analyze`; the drift comparison `project_doctor.gd:79`; save-time jump-to-first-red-row `dock/sheet_io.gd:114-122`). NEW: the chips; drift state piggybacks on save. | a green traffic light - "my sheet works" / a per-file CI badge - "this file is verified against its own compile." |

### 11.2 The banner layout law (three dimensions claimed the same 24px - ONE layout, decided here)

The Glance manifest, the Commit health strip, and the Navigate breadcrumb ALL colonize the `SheetIdentityBanner`. **The law:** identity + manifest pills LEFT · health strip RIGHT · history arrows (◀ ▶) far-left; **breadcrumb path segments are deferred** (v1 = history arrows only; a later `Sheet › Group` segment pair must pass a banner-space audit - the enclosing-group answer is already served by the Outline rail, and the "owning trigger" third segment is cut outright since the tempo badge answers it on arrival). Real new work acknowledged: the banner is **currently hidden for plain sheets** - always-visible (for the arrows/health strip) is new chrome, not a tweak.

### 11.3 The 5-second-test walkthrough (the real sheets - re-verified against the working tree)

> The counts and beats below were re-derived from the actual files after an adversarial pass caught an earlier fictional version (§16). Platformer census: 4 `@ace_trigger` · 4 `@ace_action` · **5** `@ace_condition` · 3 `@ace_expression` · **16** `@export` · **zero groups**. Health census: **8** triggers · **16** actions · 5 conditions · **12** expressions · **3** knobs · ~80 ⚠ RawCode blocks (`_process` is health-POOL DECAY - there is no regen) · zero groups.

**`eventsheet_addons/platformer_movement/platformer_movement_behavior.gd`, opened as a sheet, stranger's eyes.**
- **Second 1 - the banner:** `⚙ PlatformerMovement - Behavior · acts on host: CharacterBody2D` + pills `➜ 4 · ⚡ 4 · cond 5 · ƒx 3 · @ 16` + `✓ compiles · ✓ in sync · 0 flagged` at right. Both personas know the sheet's KIND, what it rides on, the size of its public surface, and that nothing is broken.
- **Seconds 2–3 - the badge column:** one big **⟳** amber badge on the movement kernel event says "runs every physics frame"; the four **trigger blocks** (the shipped custom trigger rows - `On Jumped`, `On Landed`, `On Wall Jumped`, `On Double Jumped`) read as the events this behaviour FIRES (declarations, not handlers - the sheet has no ➜ handler events of its own); the lifted ƒ Function rows (`jump`, `is_moving`, …) are the published verbs; the amber **⚠** code badge (`viewport_row_builder.gd:237`) marks the numeric kernel lines that stayed GDScript. (This sheet ships ungrouped - the group-fingerprint beat needs the flagship-pack grooming task, §15.1 Wave 1.)
- **Seconds 4–5 - hover the fattest row:** *"Every physics tick - do: Apply Gravity capped at max_fall_speed, … then 6 lines of code."* - the sentence names what lifted as ACE rows and counts the raw remainder honestly (the raw-block rule, §11.1); knob values glow in typed tints on the lifted rows.
- **Verdicts at 5s.** C3 vet: "a Platform behavior - one every-tick movement event, four On-events it fires, 16 properties to tune; same mental model as C3's Platform behavior" - and knows where to double-click. Godot dev: "a Node subclass for CharacterBody2D: one `_physics_process` kernel, 4 signals, a published API of 12 verbs, 16 `@export`s - and the ⟳ badge + ⚠ density told me the hot path and the code-heavy part without reading a line."

**The honest contrast - `eventsheet_addons/health/health_behavior.gd` (a HIGH-RawCode pack):** the banner still answers in one second - `➜ 8 · ⚡ 16 · cond 5 · ƒx 12 · @ 3` says "a big published API on few knobs" - and the dominant ⚠ density says "its core is code" (pool decay, an inner `HealthPool` class). That IS the 5-second answer: *what it publishes* is instantly legible even when *how it works* is code. **The clean exemplar for the full sentence experience is one of the five zero-RawCode packs** (e.g. `state_machine`, `flash`): every row hovers as a complete sentence, zero ⚠. The 5-second bar is met with **zero clicks** in all three cases - but the glance layer's per-row plain-English promise only fully holds on lifted/zero-RawCode sheets; on ⚠-heavy sheets it degrades to the banner + density read (recorded honestly in §16).

### 11.4 Judges' cuts (Glance) - recorded so they are not re-tripped

- **Outline (Skim) display mode - CUT/DEFERRED** (all four judges): redundant with §13's Outline rail; it is the only Glance device touching the fragile `_build_event_spans`/`_count_event_lines` accounting twins that `event_lazy_spans_test` guards. **Re-entry condition:** resurrect only if the rail proves insufficient at 10k rows.
- **Pill-click → role-filtered find bar - TRIMMED:** the find bar has no role-filter concept today (silent scope creep inside a "zero new state" dimension); v1 = jump to first row of that role.
- **The `?` glyph on the conditions pill - REPLACED** with teal `cond` (a bare `?` reads as "help"); glyph-soup at 13px is the manifest's one real legibility risk.
- **Third typed-value hue - TRIMMED** to ≤2, picked in the colour-law audit (amber overload).
- **One-legend colour law - DEMOTED from device to spec law + lint** (§5): a consistency audit, not a feature.

---

## 12. The flow layer - keyboard-first in-sheet authoring

**Thesis (verified 80% shipped, 0% composed):** the repo already has a rebindable C3 single-key grammar (`addons/eventforge/shortcuts.gd:16` `DEFAULTS`, exact-modifier matched), a relevance-scored picker with persisted recents + C3 synonyms (`ace_picker.gd:198/:846/:22`), a natural-language quick-add brain that fills params positionally (`dock/author_actions.gd:55` `_quick_match`), a custom-draw in-canvas text editor (viewport `_editing_buffer`, `:2275-2302` - no widget), and a one-field param popup at the mouse (`dock/inline_param_editor.gd:28`). They live in four different places. The winning move is **convergence**: fuse the quick-add brain into the canvas at the insertion point, give the highlighted param values a keyboard cursor, and codify a dialog-minimization law - so the common loop never leaves the canvas, never opens a dialog, never touches the mouse.

### 12.1 The single-key grammar - audit vs the existing `EventSheetShortcuts` map (extend, don't collide)

| Key | Meaning | Status (verified against `shortcuts.gd:16-33` `DEFAULTS` + structural keys) |
|---|---|---|
| `E` / `C` / `A` | add event / condition (context-aware: appends to selected event, else new - `event_sheet_dock.gd:1463`) / action | **EXISTS** (`add_event`/`add_condition`/`add_action`) - becomes the Ghost Row entry point (§12.2) |
| `Q` / `G` / `X` | comment / group (drops into inline rename) / toggle enabled | **EXISTS** (`add_comment`/`add_group`/`toggle_enabled`) |
| `Ctrl+D` / `Ctrl+/` | duplicate / disable | **EXISTS** (`duplicate`; disable at `dock:1588` area) |
| `Tab` / `Shift+Tab` | nest / outdent (row scope) | **EXISTS** (structural, hardwired - `shortcuts.gd:8`) - **unchanged**; see the Param-Hop arbitration below |
| `Alt+↑`/`Alt+↓` | move row | **EXISTS** (`viewport:1439`) |
| `Enter`/`F2` / `Esc` / `Delete` | inline edit / cancel / delete | **EXISTS** (structural) - Enter on an ACE row gains Param-Hop entry (§12.3) |
| `F9`/`Ctrl+B` · `Ctrl+M`/`F4` | breakpoint · bookmark/cycle | **EXISTS** (`viewport:1422-1434`, `:1425-1430`) |
| **`B`** | add blank sub-event | **NEW key** - the action exists only as a context-menu submenu (`dock/context_menus.gd:139`); one `DEFAULTS` entry + dispatch row |
| **`I`** | invert selected condition | **NEW key** - `CONDITION_MENU_INVERT` exists (`context_menus.gd:32`; compiler already emits `not (…)`) |
| **`R`** | replace ACE under cursor | **NEW key** - the picker's `replace_condition/replace_action/replace_trigger` modes exist unkeyed (`ace_picker.gd:369-374`) |
| **`F12` / `Shift+F12` / `Alt+←`/`Alt+→`** | go to definition / references / history | **NEW** - §13, added to `DEFAULTS` (rebindable, conflict-checked via `conflicting_action`) |
| **`F10`** | run to next row (paused) | **NEW** - §14, script-editor step-over convention |

Collision audit: `B`/`I`/`R`/`F10`/`F12` do not appear in `DEFAULTS` today (verified); the matcher's exact-modifier rule (`Ctrl+Shift+C ≠ Ctrl+C ≠ C`) guarantees new single keys never shadow typing, and every binding remains per-user remappable (`user://eventforge_shortcuts.cfg`). **Two collisions the `conflicting_action` audit does NOT catch (adversarial findings, §16):**
1. **Alt+Left/Right vs the hardwired fold keys.** The viewport's structural handler is a raw keycode chain that does not filter modifiers on arrows - `event_sheet_viewport.gd:1412` `elif event.keycode == KEY_LEFT:` folds on ANY Left, so Alt+Left would fold AND navigate. Fix: add `and not event.alt_pressed` to the `KEY_LEFT`/`KEY_RIGHT` fold branches (and handle history above them). §15.3's `shortcut_collision_test` must therefore ALSO sweep the hardwired structural chain, not just `DEFAULTS`.
2. **F10/F12 vs Godot's editor-global debugger keys.** Godot binds Step Over = F10 and Continue = F12 editor-wide. Arbitration: **while paused, Godot's semantics win** - the paused banner's Continue maps to F12, and run-to-next-row is implemented as a one-shot breakpoint at the next row's `source_map` start + programmatic continue (never by stealing F10 globally); go-to-definition's F12 applies only when the sheet canvas has focus and no session is paused. Both stay rebindable.

### 12.2 The Ghost Row (flagship - the zero-dialog add loop)

Press `E`/`C`/`A` (or Enter on the add-event footer): instead of the centered 720×520 picker window, a **custom-drawn editing line materialises at the exact insertion point** - same buffer/caret machinery the shipped inline span editor draws in `_draw` (no widget) - plus ONE transient completion `PopupPanel` anchored under it (parented on the dock, like `inline_param_editor`'s popups; never per-row). Type a sentence - `heal 5`, `every tick`, `set move_speed 450` - the SHIPPED `_quick_match` brain scores it live (it already honours the picker's C3 synonym phrasing and fills params positionally), the popup shows the top 5 with ★ recents, **Enter applies, Esc falls back to the full picker, Ctrl+Enter opens the full picker directly**.

- **EXISTS:** the brain, synonyms, recents, the custom-draw editor, the apply flow (`_apply_ace_definition`), the zero-param dialog skip (`dock/ace_apply.gd:39/:96`).
- **NEW:** the anchoring; the completion popup; **the hard gate - a quote-aware tokenizer** (verified: `_quick_match` splits positional params with `best_rest.split(" ", false)` at `author_actions.gd:94`, so `play "jump land"` mis-fills today; tokenizer + tests are a prerequisite, not an option); an editing-state guard integrating with the typing-suppression rule (`dock:947` `_text_field_has_focus`) since the Ghost Row is canvas-drawn, not a `LineEdit`.
- **Honest scope note (judges):** inline canvas editing + a completion popup is the fiddliest UI work in Part II - budget for focus arbitration, IME/dead keys, zoom/scroll re-anchoring, popup placement at viewport edges (≈2–3× the named seams).
- **C3-does-it-better flag honoured:** C3's Add dialog is also a *browsable illustrated catalog* - Ctrl+Enter-to-full-picker stays prominent (footer hint + first-run coach-mark) or discoverability regresses for beginners.

### 12.3 Param Hop + post-insert continuation

`Tab`/`Shift+Tab` **in param scope** cycles a keyboard cursor across the row's highlighted parameter VALUES (the renderer already computes value hit-rects on demand - `_value_text_at` `viewport:606`, `param_id_for_value` `:629/:1039-1052`); the hovered value gets the selection tint **plus a muted param-name hint at the cursor** (judges' C3 flag: blind Tab-cycling would regress comprehension vs C3's all-params-visible dialog). Typing any character or Enter opens the SHIPPED one-field popup pre-filled + select-all'd, anchored at the value's rect; commit is one undoable, type-checked step.

**The Tab arbitration (named design decision - `Tab` already means nest/outdent at row scope, shipped, unchanged):** param scope is entered explicitly - (a) **automatically after an ACE lands** (post-insert continuation drops the cursor on the first default-filled param), or (b) **Enter on a selected ACE row**. Inside param scope Tab/Shift+Tab cycle values; **Esc exits to row scope**, where Tab nests again. A scope test guards this so the two Tabs can never fight. Post-insert continuation also re-arms the add key: pressing `A` again immediately opens a same-lane Ghost Row below ("add another" - C3's ribbon behaviour). So `E` → `jumped` → ⏎ → `A` → `set move_speed` → ⏎ → `450` → ⏎ is **one unbroken keyboard stream**.

### 12.4 Keystroke arithmetic (the three jam-critical loops)

| Loop | Construct 3 | GDScript (script editor) | Here (today, shipped) | Here (with Ghost Row + Param Hop) |
|---|---|---|---|---|
| **Append "Heal 5"** to the selected event | `A` → object filter → ⏎ → action filter → ⏎ → params dialog → `5` → ⏎ ≈ **11 keys / 3 dialog screens** | find the right branch of the right func (scroll/Ctrl+F ≈ 5 actions) + type `$Health.heal(5)` (**16 chars + node-path recall**) | `A` → `heal` → ⏎ (relevance-scored) → params dialog (first field focused) → `5` → ⏎ = **8 keys / 2 popups** | `A` → `heal 5` → ⏎ = **8 keys / 0 dialogs**, focus never leaves the canvas |
| **Retune 300→450** in `Set move_speed 300` | dbl-click action → dialog → click field → retype → ⏎ (**1 gesture + dialog**) | Ctrl+F `move_speed` → click into the literal → select → type (similar count, but trusting grep, not structure) | dbl-click the highlighted `300` → popup pre-selected → `450` ⏎ (**1 gesture + 4 keys**) | row selected → Enter → Tab → `450` → ⏎ = **~6 keys, zero mouse** |
| **New event "On Jumped → play sound"** | ≈ 2 full Add-dialog round-trips | navigate + type a connect or match the signal handler + the call | `E` → picker → `jumped` ⏎ → `A` → picker → `play sound` ⏎ → params | `E` `jumped` ⏎ `A` `play sound jump` ⏎ - one stream; continuation lands on the path param |

Verdict: ties GDScript on raw characters, **wins on placement, API-correctness (relevance match over the real registry - you cannot typo a verb), no `$Health.`/host-cast prefixes, and structural undo** - and beats C3's add loop outright. Bulk: box-select N rows → edit one shared value → **Ctrl+Enter "Apply to all N"** (inside `inline_param_editor`'s commit closure, iterating `_top_level_selected_resources` under ONE `_perform_undoable_sheet_edit`) - the structure-aware, type-checked bulk retune neither C3 nor regex-replace offers, one undo step.

### 12.5 The dialog-minimization covenant (spec LAW - every future feature must pass this table)

| Situation | Surface | Status |
|---|---|---|
| Zero-param ACE | **no dialog ever** (applies instantly) | SHIPPED (`ace_apply.gd:39/:96`) |
| Single param value (number/string/enum) | popup-at-value, pre-filled, select-all, one undo | SHIPPED (`inline_param_editor.gd:28-41`) |
| Colour | swatch click → ColorPicker, committed once on close | SHIPPED (`viewport:966`, `inline_param_editor:64-78`) |
| Node reference | drag from Scene dock onto the value | SHIPPED (`inline_param_editor:99`) |
| Group / comment / event-comment text | in-canvas span editor; slow-click begins edit like a file rename | SHIPPED (`row_builder` edit_kinds `:299/:351/:882`; `viewport:640`) |
| Common add (event/condition/action) | Ghost Row, zero dialogs | NEW (§12.2) |
| Variable NAME / DEFAULT spans | extend the in-canvas span editor (spans exist, `editable=false` today - `row_builder:484/:549-554`); name edits MUST route through Rename Everywhere, never a raw field write | NEW (small) |
| Multi-field input needing validation / the expression builder | ACE params dialog (auto-focuses first field) | LAW: dialog allowed |
| Multiline text | dialog (the shipped multiline-comment guard, `viewport:1053`) | LAW: dialog allowed |
| Destructive / rare config | dialog | LAW: dialog allowed |

### 12.6 Judges' cuts (Flow)

- **Alt-drag number scrubbing - DEFERRED** (all four): gimmick-adjacent until Param Hop proves the value-cursor model; Alt+drag contends with box-select/row-drag/span-drag gesture space on a canvas that already has three drag modes. Revisit as v2 juice.
- **Picker ranking boosts - TRIMMED:** keep frequency-weighted recents (today pure MRU - one accidental pick evicts a daily verb); **defer** the host-class and "in this sheet" boosts - stacked ranking signals make the picker feel nondeterministic to the C3 vet whose recents muscle-memory is the actual speed source.
- **Key-hint chips - CONFINED** to the add-event footer only (matching the shipped empty-state pattern, `viewport_empty_state_helper.gd`); no per-row hints or the calm covenant dies by a thousand chips.

---

## 13. The navigate layer - project-scale comprehension

**Thesis:** because the `.gd` IS the sheet, every verb on the canvas already carries its own address - every ACE span resolves to `provider_id`+`ace_id`, every CallFunction cell already looks up its `EventFunction` by name (`viewport_row_builder.gd:1091`), every addon script is enumerable (`addon_scanner.gd`). The Navigate layer turns those latent addresses into ONE universal gesture - **Ctrl+Click goes to the definition, Shift+F12 shows the uses, Alt+Left comes back** - with the project's shape surfaced as chrome AROUND the virtualized canvas, never inside it. This is simultaneously the Godot dev's non-negotiable F12 covenant and the thing C3 never gave anyone: **C3 behaviors are sealed boxes; here every behaviour opens as a legible sheet one Ctrl+Click away** (ranked the #1 device of the whole tournament by the C3-veteran judge - "the single move that beats BOTH comparisons at once").

### 13.1 Ctrl+Click Go-to-Definition (the F12 covenant)

Ctrl-hover underlines the span + hand cursor (a render flag on the EXISTING hover path - custom-draw, no widget; **the underline affordance must be loud** - it is what teaches the C3 refugee a dev idiom). Ctrl+Click or F12 jumps. Resolution table (every heavy primitive verified shipped - the resolver is glue):

| Span kind | Resolution | Anchor |
|---|---|---|
| Behaviour-pack ACE | `provider_id`+`ace_id` → match `class_name` via `semantic_analyzer` metadata over `EventSheetAddonScanner.list_addon_scripts()` → **open that `.gd` AS A SHEET** on the defining function/signal row | `_load_sheet_from_path` (used by `find_references_panel.gd:95`) + `viewport.reveal_resource()` (`event_sheet_viewport.gd:688` - unfolds ancestors + selects + scrolls) |
| Same-sheet CallFunction | `sheet.functions` match on `params['function_name']` → reveal the Define row | the row builder ALREADY does this exact lookup for labels (`viewport_row_builder.gd:1091`) |
| Variable span | definition resolver → reveal the variable row, following includes | `dock/find_references.gd` (resolves variable/function/signal/local-var definitions) |
| Raw hand-written pack func | open the script at the definition line | `_open_gdscript_path_in_godot(path, line)` (`event_sheet_dock.gd:3456`); line via `metadata['source_name']` scan (`ace_generator.gd:176/206/276`) |
| Built-in module ACE | the picker's info/description pane - the honest fallback (do NOT pretend a user-meaningful definition exists) | picker info pane |

NEW: `dock/navigate.gd` (RefCounted resolver + history stack) + a viewport `navigate_requested(row_data, span_index, metadata)` signal reusing the exact span hit-test that powers double-click `ace_edit_requested` (`event_sheet_viewport.gd:12`).

### 13.2 Back/forward history (the licence for fearless clicking)

A `NavigationHistory` on the dock: every jump (Ctrl+Click, find result, reference activation, outline click, bookmark) pushes `{sheet_path, row_uid, flat_index, scroll}` - **never bare `source_map` uids** (instance ids don't survive reloads; the path+uid+flat-index fallback is mandatory, degrading to a sheet-level jump). `Alt+Left`/`Alt+Right` + mouse buttons 4/5, rebindable via `DEFAULTS`. Chrome: ◀ ▶ arrows on the banner per the §11.2 layout law (breadcrumb segments deferred). Alt+Left absence would be disqualifying for the Godot persona; its presence is what makes a C3 vet unafraid to open a teammate's project - you cannot get lost.

### 13.3 The rail, the strip, and the palette (chrome, sequenced - never all at once)

- **Navigator rail - Outline tab** beside the existing Open Sheets tab (`open_sheets_dock.gd` - collapsible, filterable, pure view): chapters of the ACTIVE sheet as a small Tree - groups (colour dot), top-level triggers by friendly name, ƒ functions, variables/signals, includes. Single-click = `reveal_resource()`; typing filters. Pure read-model of `_root_rows` + `sheet.functions`; zero canvas widgets. **On a behaviour sheet this tab yields to Part I's Anatomy panel** - one left rail, context-picked (answers Part I §8.1 Q2). **C3 flag honoured:** the rail preserves the whole-row reading unit - clicking never scrolls conditions independently of actions. *This rail is the portfolio's ONE outline device - A's in-canvas skim mode lost (§11.4).*
- **The map strip** - a ~14px custom-draw Control on the canvas's right edge (sibling of the ScrollContainer, `_get_scroll_container()` `viewport:217`): group-coloured extent bands, amber ⚠ ticks (lift-note/RawCode), red breakpoint dots + blue bookmark ticks (row-state dicts exist - `_breakpoint_rows` read at `viewport_row_builder.gd:116`), find-match ticks while the find bar is open (matches already computed - `dock/find_bar.gd:95`). Click = jump; drag = scrub. One `_draw` over the flat row model + layout-cache offsets.
- **Ctrl+P prefix modes** on the existing command palette (`dock/command_palette.gd:47` `filter_commands`, static + tested): plain = commands (unchanged); **`#`** = sheets across the project (`EventSheetProjectFind.list_project_sheets` - used by `vocabulary_doc.gd:34`), open on Enter; **`@`** = symbols in the active sheet (the Outline read-model reused), reveal on Enter; **`::`** = the project's **published vocabulary** (every behaviour's triggers/actions/conditions/expressions from the registry that feeds the picker), go-to-definition on Enter - the interactive twin of the committed `EVENTSHEETS-VOCABULARY.md`, with **no C3 or grep equivalent** (grep finds `take_damage`, not "Take Damage" the verb and everything that speaks it).
- **Usage chips on definition rows** - hovering a Define-function / trigger-signal / variable row appends a muted trailing chip `used in 3 sheets · 7 places` (data from `EventSheetFindReferences.find_in_project`, `dock/find_references.gd:36` - whole-symbol semantic, `speed` never matches `move_speed`), computed lazily on hover, cached per symbol, invalidated on save; skip above N sheets until cached. Click or Shift+F12 → the existing Find References panel pre-seeded, **sharpened**: today `_on_find_reference_activated` (`:89`) only loads the SHEET - NEW: carry the matched resource in metadata and `reveal_resource()` it, so a reference jump lands on the ROW. `0 uses` = the dead-code cue - "can I delete this?" answered inline (feeds §14 safe-delete).
- **The Imports strip (chips-only v1)** - includes are genuinely invisible today (window-only: Sheet ▸ Manage Includes, `dock:1435`). One collapsed SECTION row pinned at sheet top - the shipped scaffolding-strip pattern (`viewport_row_builder.gd:39`, fold machinery included; `source_resource=null` so selection/delete ignore it, the add-event-footer convention `:71`) - reading `Uses: ⚙ common_input · score_rules   Families: Enemies (3)` as chips. Ctrl+Click an include chip → open that sheet; hover a family chip → member-list tooltip. **Judge's trim: the expanded per-include verb-count fold is a second release.**

### 13.4 Orient-in-a-strange-project-in-60s (the composed flow)

Ctrl+P `#` lists the 20 sheets → open the main sheet (banner + pills + fingerprints orient in 5s, §11.3) → Outline-rail scan of chapters → Ctrl+Click a behaviour verb → it opens AS A SHEET on the defining row, breadcrumb arrows live → hover the define row: `used in 3 sheets · 7 places` → Shift+F12 lands on a consumer ROW → Alt+Left, Alt+Left back to the main sheet → Ctrl+P `::knock` finds the one verb project-wide. Under a minute, honestly - and every step has the keyboard twin. Keystroke parity vs the comparisons: go-to-definition 1 gesture (C3: **impossible** - behaviors are closed source; GDScript: parity, but the sheet jump crosses the consumer→behaviour boundary and lands on a labelled Define row, not raw text mid-file); find usages 1 action, whole-symbol (GDScript without LSP: substring grep + false positives); go to any published verb: `::` - no equivalent anywhere.

### 13.5 Judges' cuts (Navigate)

- **Breadcrumb segments - TRIMMED/DEFERRED** per §11.2 (banner arbitration lost; the trigger segment cut outright - the tempo badge answers it on arrival).
- **Chrome accumulation - SEQUENCED:** rail → palette modes → map strip → imports strip across waves (§15), never all four as one release of new furniture.
- **History-stack uid stability** - instance-id caveat folded into §13.2 as mandatory, not optional.

---

## 14. The commit layer - full-project code-free viability

**Thesis:** the byte-exact round-trip covenant quietly gives this platform something no visual-scripting tool has ever had: because the committed `.gd` IS the sheet and Doctor proves byte-identity (`project_doctor.gd:64-82`), git's line-based world (blame, diff, conflicts, CI) and the debugger's line-based world map **losslessly onto sheet rows** through the shipped `source_map`. One shared helper - **`EventSheetLineRowMapper`** (~100 lines over `{uid,start,end,kind}`; every mapping computed against the LIVE sheet, never persisted - instance-id caveat) - powers runtime-error→row, step-to-next-row, sheet diff, and later blame. The commit layer closes the last two moments a non-programmer is FORCED to read generated GDScript: a runtime break/error, and a git merge conflict.

### 14.1 THE FULL-PROJECT CODE-FREE VIABILITY MATRIX

| Capability | EXISTS (anchor) | Gap | Fix | Priority |
|---|---|---|---|---|
| **Authoring** (events, functions, variables, groups, includes, families, expression builder, extract-to-function) | the whole shipped editor; 5 packs at zero-RawCode; `{host.}`; friendly types; Ghost Row lands §12 | numeric kernels stay ⚠ RawCode (honest carve-out, audit spec §5.4); guards are free-text (Part I §9) | §12 flow devices; guard-through-picker (Part I §9) | shipped / Wave 2 |
| **Authoring - data structures / custom types** | the full Array/Dictionary ACE vocabulary (collection_aces: append/pop/insert/erase/find/sort/contains + dict set/get/has/keys/values) covers flat collections code-free | **typed inner classes, Dictionaries-of-objects, and custom sort predicates are RawCode-only** (health's `class HealthPool` + `health_pools` + `_sorted_pool_keys` - none authorable as rows); graded honestly: a data-modelling-heavy behaviour cannot be zero-code today | near-term: recipes steer state toward flat vars + dict ACEs; future: a structured "record type" primitive is OPEN research, not promised | honest carve-out |
| **Authoring - input / controls** | `GetInputAxis`/`Is Action Pressed` ACEs; ⌨ input triggers | the flagship pack hardcodes `Input.get_axis("ui_left","ui_right")` (`platformer_movement_behavior.gd:81`) - no exported action-name knobs, no Simulate-Control action, no input-enabled toggle → rebinding controls, cutscene input-off, and AI-driving-the-behaviour all force code | add action-name `@export` knobs + an input-enabled toggle to the platformer pack builder (content task) + a `SimulateControl` action ACE (small vocab addition) | P2 (content + small vocab) |
| **Debugging - breakpoints** | F9/Ctrl+B on rows end-to-end (`viewport:1422-1434`); conditional via context menu (`context_menus.gd:175`); Debug-menu emit toggle (`menu_bar.gd:206`); compiler emits `breakpoint`/`if cond: breakpoint` (`sheet_compiler.gd:1140-1147`) | **hitting one dumps you into the script editor on GENERATED code - the promise-breaking moment #1** | **Paused-at-row:** hook the debugger session's break notification in the shipped `EditorDebuggerPlugin` (`addons/eventsheet/editor/live_values_debugger.gd` owns sessions; **verified: it contains NO break handling today**) → auto-invoke the shipped reverse provenance (`plugin.gd:77` `_goto_sheet_row_from_script` → `goto_generated_line`, `dock:2112`) → ⏸ amber paused-row + banner `Continue` / `Run to next row` (F10 = one-shot breakpoint at the next row's `source_map` start). **SPIKE the 4.7 `EditorDebuggerPlugin` break-notification API FIRST - it gates the flagship; fallback = poll `session.is_breaked`.** **Honest degrade (§16): when the paused/faulting line falls INSIDE a ⚠ RawCode block, the finest landing is the whole block - the user reads GDScript there; the §5.4 carve-out applies to debugging too.** Step-INTO a called Define-function/behaviour verb is a named GAP (v1 ships Continue + run-to-next-row only). | **P1** |
| **Debugging - live state** | Live Values panel: writable variable tree + `Expression`-based watches (`live_values_panel.gd:212/:229`) - C3's debugger made writable; fired-row flash (`__eventsheets_fired` bus → `viewport:1668`) | **per-INSTANCE inspection of a pack's private state** (`_coyote_timer`, `_jumps_left`, `health_pools` contents) across many attached instances is not established - the panel enumerates the sheet's declared variables + watches, not arbitrary instance internals; grade: partial | verify what the panel enumerates for an attached pack instance; if private/multi-instance is absent, add an instance-picker + private-var enumeration to the debugger plugin (post-Wave-3) | partial → P3 |
| **Error surfacing - save-time** | red-row diagnostics + hover message + jump-to-first on Ctrl+S (`viewport set_row_diagnostics:1644-1666`; `dock/sheet_io.gd:114-122`) | - | - | shipped |
| **Error surfacing - runtime** | the display path above is entirely shipped | **runtime errors appear only in Godot's Errors tab with generated-file:line - promise-breaking moment #2** | capture the error stream in the debugger plugin, filter sheet scripts (`sheet_for_script`, used by `plugin.gd:78`), map line→row via the Mapper, paint the SAME red marker with a `runtime` chip; clears on next run. One mental model: **errors are red rows**, save-time or runtime. (Same ⚠-block degrade as paused-at-row: an error inside a RawCode block lands on the block.) | **P1** |
| **Refactoring** | Rename Everywhere (open sheet + all includers + embedded GDScript surfaces minus `{placeholders}` - `event_sheet_rename_refactor.gd:26-104/:140-173`); Extract-to-Function with scope-capture refusal (`dock:1217/:1319-1321`); Extract Selection to Include (`dock:1114-1170`); project find + references panel | delete has no blast-radius guard; pack-ACE rename doesn't propagate to consumer sheets | **Safe-delete:** deleting a function/variable/pack ACE first runs `find_references` and lists consumers in the confirm ("used in 3 sheets - delete anyway?"; `0 uses` = green-light). **Pack-ACE rename propagation: GATED + DEFERRED** - rewriting every consumer sheet keyed on `provider_id`/`ace_id` is the riskiest write-path in the portfolio (a bad match corrupts sheets project-wide); requires a dry-run preview dialog (files + row counts) + reference-coverage tests before it may land. | P2 / deferred-gated |
| **Versioning - diff** | the `.gd` IS the sheet; drift=0 means git diff is already readable + canonical section ordering keeps diffs minimal and stable | no row-level review surface - code-free PR review means reading a text diff | **Sheet Diff via double import** (don't build a structural differ): take git's line diff of the two `.gd` versions, import each (`GDScriptImporter`, the shipped lossless path in `dock/sheet_io.gd:30`), recompile each for ITS `source_map`, map changed/added/removed ranges → rows per side, render the old version read-only beside the new with green/red/amber accent bars (shipped group accent-bar drawing), scroll synced by aligned pairs. **Scope honesty (§16): reuse the split WIDGETRY (`HSplitContainer` + a second `EventSheetViewport`), but `multi_view_manager.gd` is by design two panes over the SAME sheet - a "foreign read-only sheet" pane mode (different resource, read-only enforcement, no shared undo/selection) is NEW work counted in the Wave-4 scope.** Caveat: a months-old revision generated by an older compiler may not re-import cleanly - degrade to the raw text diff for that side. **When alignment is ambiguous, fall back to added+removed - never guess.** PR review = "walk the amber rows with arrow keys." | P3 |
| **Versioning - blame** | git works on the `.gd` today (terminal/GitLens) | no in-sheet "who changed this event" | **Row blame gutter - DEFERRED to v2** (all four judges): per-file `OS.execute` git on Windows under a OneDrive-synced repo (this very project) makes the degrade path the common path; cheap once the Mapper ships for diff - do it then, off by default. | deferred |
| **Versioning - merge conflicts** | - | **a conflicted `.gd` won't import; today the failure is a generic "could not read" - a hard stop for a code-free team** | **Conflict flow v1 (honest, cheap):** `sheet_io` detects `<<<<<<<` on open → themed dialog: "Open YOURS and THEIRS side-by-side" (extract both sides to temp, import each, show in the split pane with diff tints) + whole-file "Keep yours / theirs." Plus a Doctor conflict-marker check with a clear message. **The scan must cover `project.godot` conflicts too** (autoload registrations - Doctor already audits these via its autoload check), not just sheet `.gd`s. **Per-row pick = v2, CUT for now** - structural three-way merge is a research project hiding inside a bullet point; the aligner must be battle-tested first. | **P2** |
| **Performance visibility** | Doctor's static perf checks (unbounded loops, coroutine-in-per-frame-trigger, fan-out - `project_doctor.gd:32-34`); the frame-spreading packs + budget ACEs (shipped, FRAME-SPREADING-SPEC); fired-row flash; Godot's profiler | no per-row timing | **Per-row heat - DEFERRED** (all four judges): debug-build `ticks_usec` brackets add instrumentation the residue check then has to police; hot-chip noise on every tick event fails the calm-canvas bar; Doctor + profiler cover the 80% case. Re-entry: after paused-at-row/error-routing prove the debug story, budget-threshold-only display. | deferred |
| **Team workflow - CI** | headless Doctor CLI (`tools/project_doctor.gd`) runs the same audit as the editor panel; errors = broken byte-identity / non-compiling sheet | no documented pipeline; **one VERIFIED live hazard: a sheet saved with `emit_breakpoints`/`emit_live_values` ON compiles `breakpoint` statements + the telemetry emitter INTO the committed `.gd`** (`sheet_compiler.gd:24-25/:85` reads `sheet.emit_breakpoints` on every compile, incl. `_save_backed_sheet`; emission at `:1140-1147`) | **(a) Debug-residue Doctor check** - flag committed debug instrumentation as a warning with one-click "strip + resave" (an afternoon of work; highest trust-per-line in the portfolio - ranked a must-ship by all four judges regardless of everything else). **(b) A documented GitHub Actions recipe** in docs - "the sheet linter for PRs." **(c)** the conflict-marker check (above). | **P0** |
| **Team workflow - shared vocabulary** | `EVENTSHEETS-VOCABULARY.md` generation (`vocabulary_doc.gd`); the picker; Part I's Anatomy | vocabulary not searchable in-editor | Ctrl+P `::` mode (§13.3) | Wave 2 |
| **Trust surface** | drift=0 proof; codegen hover tooltip (`viewport:2391`); Show generated GDScript fold (Part I §3.5) | sheet health not ambient | **Sheet health strip** on the banner (§11.1): `✓ compiles · ✓ in sync · N flagged` | P2 (rides the banner work) |

### 14.2 What must land for a team to commit (ranked)

1. **The debug-residue Doctor check + CI recipe (P0).** A verified live hazard, an afternoon of work, protects every team from shipping instrumented builds - ship first regardless of everything else.
2. **Paused-at-row + runtime-errors-land-on-rows (P1).** The two promise-breaking moments; mostly wiring over shipped reverse provenance + the shared `LineRowMapper`. **Spike the 4.7 debugger break-notification API before committing to the wave - it gates the code-free headline.**
3. **Merge-conflict flow v1 (P2).** A team WILL conflict; an un-importable sheet is a project-stopper. Whole-file resolution is honest and sufficient.
4. **Safe-delete + the health strip (P2).** Blast-radius answers + ambient trust; both cheap over shipped `find_references`/diagnostics.
5. **Sheet Diff via double import (P3).** Makes code-free PR review real; also battle-tests the aligner that everything deferred (blame, per-row merge) waits on.

Land 1–3 and *"commit the whole game code-free"* is defensible; 4–5 make it enviable. Blame, heat, and per-row merge stay in the deferred ledger (§15.4) with named re-entry conditions.

**The pitch, per persona.** C3 vet: a C3 project is an opaque `.c3p` blob - no diff, no blame, no CI, no merge; here every concept lands as a sentence about EVENTS ("this event has an error", "the game is paused on this event", "Maria changed this event Tuesday", "these three events changed in this PR") - capabilities they'll recognise instantly as the reason studios told them to "graduate to a real engine." Expect onboarding, not instant recognition - the event-language framing is the translation. Godot dev: git and the debugger already work on the `.gd` (the covenant means his tools never break - the headline he cares about); the mapped views answer "which EVENT" instead of "which line," stepping is event-granular, and canonical section ordering yields arguably cleaner diffs than his hand-written scripts produce. The honest concession stands: tight numeric kernels stay amber RawCode blocks, and every commit-layer device treats them identically to any other row.

---

## 15. The unified roadmap (Part I remaining phases × Part II devices, leverage-ordered)

Ordering rules distilled from the judges: (1) devices that close promise-breaking moments outrank delight; (2) zero-new-state read-models outrank new machinery; (3) both-personas-in-one-gesture outrank single-persona wins; (4) defer gimmicks until their parent model ships; (5) never ship two devices answering one question; (6) the calm covenant is enforced by cuts. Shared infrastructure is specced ONCE: **`_trigger_class_for`** (in `trigger_resolver.gd`) and **`EventSheetLineRowMapper`** are named helpers, not per-device code.

### 15.1 The waves

**Wave 0 - do immediately (an afternoon, protects every team):**
- D: **debug-residue Doctor check** + conflict-marker check + the CI recipe doc (§14.1 P0).
- **SPIKE:** the Godot 4.7 `EditorDebuggerPlugin` break-notification API (gates Wave 3's flagship; fallback = poll `session.is_breaked`).

**Wave 1 - verified-cheap, covenant-inert, transforms the first 5 seconds of every demo:**
- A: **tempo badges** (`_trigger_class_for` + exhaustiveness test + 4 palette constants) · **manifest pills** + **health strip** under the §11.2 banner-layout law (incl. the always-visible-banner work) · **sentence hover** · **group fingerprints** · **typed tints** (≤2 hues) · the **colour-law sweep** (hardcoded literals → palette constants + lint test).
- B: the **B / I / R keys** (three `DEFAULTS` entries + dispatch rows).
- Part I **Phase 2**: Define-block rendering + `ace_action`/`ace_condition`/`ace_expression` badge styles + `→ T` chips (shares the badge_style seam with tempo badges - do together).
- Part I §9 debt: **VALUE_TYPES reshape on the shipped Studio** - drop `yes / no (bool)` from the Expression ("A value") card (a boolean belongs on the Condition card; one obvious home) and put `anything (Variant)` under an "advanced" fold. One-line data change + a card-derivation test tweak.
- **Flagship-pack grooming (CONTENT task):** add `Movement`/`Reactions` groups + input action-name knobs to the platformer pack builder (and groups to 1-2 other flagship packs) so the glance devices (fingerprints, grouped mockups) demo on real bundled sheets, not just user sheets.

**Wave 2 - the two flagship UX bets (parallel tracks):**
- B: **quote-aware tokenizer** (hard gate, tests) → **the Ghost Row** → **Param Hop + post-insert continuation** (Tab-arbitration scope test) → **apply-to-selection multi-edit** → frequency-weighted recents.
- C: **navigate resolver (Ctrl+Click/F12)** + **history stack (Alt+Left/Right)** + **Ctrl+P prefix modes** + the **Outline rail tab**.
- Part I **Phase 3**: the Anatomy panel (shares the left-rail slot with the Outline tab - context-picked: Anatomy on behaviour sheets, Outline on logic sheets).
- D: **`EventSheetLineRowMapper`** (built now; consumed in Wave 3).

**Wave 3 - the code-free headline + definition ergonomics:**
- D: **paused-at-row** (⏸ chrome, Continue, F10 run-to-next-row) + **runtime-errors-land-on-rows**.
- C: **usage chips + reference-jump-lands-on-the-row** · **Imports strip (chips-only)** · **map strip**.
- D: **safe-delete** (references-listing confirm).
- Part I **Phase 4**: type-correct empty-body stub codegen + published-before-implemented round-trip test.
- Part I **Phase 5**: New Behaviour wizard + recipe scaffolds (pack-builders → shared static emitters).

**Wave 4 - team workflows + polish + release:**
- D: **Sheet Diff via double import** → **merge-conflict flow v1**.
- Part I **Phase 6**: docs (`docs/GUIDE-../GUIDE-RECIPES.md`, the CI recipe page), coach-marks (Ghost-Row Ctrl+Enter discoverability, Ctrl-hover underline), README refresh, version bump, regenerate, drift=0.

### 15.2 Files to touch (Part II additions; Part I files stand as listed per-phase)

| File | Change | Wave |
|---|---|---|
| `addons/eventforge/project_doctor.gd` + `tools/project_doctor.gd` | debug-residue check (+ strip-and-resave fix), conflict-marker check | 0 |
| `addons/eventforge/compiler/trigger_resolver.gd` | static `_trigger_class_for(trigger_id)` co-located with `resolve_trigger` | 1 |
| `addons/eventsheet/theme/event_sheet_palette.gd` | 4 tempo hues + ≤2 typed-value hues as named constants; colour-law sweep targets | 1 |
| `addons/eventsheet/editor/interaction/viewport_row_builder.gd` | tempo `badge_style`s; group fingerprint span; typed `[start,len,kind]` ranges; Part I Define-block builders; Imports-strip SECTION row (W3) | 1–3 |
| `addons/eventsheet/editor/interaction/viewport_tooltip_helper.gd` | `row_sentence(event_row)` over the descriptor formatters | 1 |
| `addons/eventsheet/editor/sheet_identity_banner.gd` | manifest pills + health strip + history arrows; always-visible for plain sheets; the §11.2 layout law | 1–2 |
| `addons/eventforge/shortcuts.gd` | `B`/`I`/`R` + `F12`/`Shift+F12`/`Alt+Left`/`Alt+Right`/`F10` `DEFAULTS` entries | 1–3 |
| `addons/eventsheet/editor/dock/author_actions.gd` | quote-aware tokenizer replacing `split(" ", false)` (`:94`) | 2 |
| `addons/eventsheet/editor/event_sheet_viewport.gd` | Ghost-Row buffer/caret + editing-state guard; Param-Hop cursor + scope arbitration; ctrl-hover underline flag; `navigate_requested` signal; paused-row ⏸ state (W3) | 2–3 |
| `addons/eventsheet/editor/dock/` **`ghost_row.gd`** (new) | completion popup + `_quick_match` glue + apply/continuation sequencing | 2 |
| `addons/eventsheet/editor/dock/` **`navigate.gd`** (new) | resolver table + `NavigationHistory` (path+uid+flat-index) | 2 |
| `addons/eventsheet/editor/dock/command_palette.gd` | `#` / `@` / `::` prefix modes over `filter_commands` (`:47`) | 2 |
| `addons/eventsheet/editor/open_sheets_dock.gd` | Outline tab (read-model Tree) + Anatomy-tab context pick | 2 |
| `addons/eventsheet/editor/dock/inline_param_editor.gd` | Param-Hop anchoring + param-name hint + Ctrl+Enter apply-to-selection in the commit closure | 2 |
| `addons/eventforge/` **`line_row_mapper.gd`** (new) | the shared line-range↔row helper over `source_map` (live-only; never persists uids) | 2 |
| `addons/eventsheet/editor/live_values_debugger.gd` | break-notification hook + error-stream capture + routing (per Wave-0 spike) | 3 |
| `addons/eventsheet/editor/dock/find_references.gd` / `find_references_panel.gd` | usage-chip query cache; reference activation carries the resource → `reveal_resource` | 3 |
| `addons/eventsheet/editor/dock/multi_view_manager.gd` + **`git_bridge.gd`** (new) | Sheet Diff (double import + per-side map + tints + aligned scroll); conflict-side extraction; git feature-hides when absent | 4 |
| `addons/eventsheet/editor/dock/sheet_io.gd` | conflict-marker detect on open → yours/theirs dialog | 4 |
| `addons/eventforge/compiler/sheet_compiler.gd` | Part I empty-body stub emission (W3) | 3 |
| `tools/pack_builders/*.gd` | Part I shared static scaffold emitters (W3) | 3 |

### 15.3 Tests to add (Part II; Part I's §8-era tests carry over per phase)

- `trigger_tempo_exhaustiveness_test.gd` - every id in `resolve_trigger`'s match has a tempo class; unknown → SIGNAL.
- `banner_manifest_counts_test.gd` - pill counts match the sheet's trigger/expose/export census; health strip reflects diagnostics + drift state.
- `row_sentence_test.gd` - the sentence is built ONLY from `_format_*_descriptor` outputs (no second formatter) for trigger/negation/OR/sub-event shapes.
- `glance_render_parity_test.gd` - tempo badges + fingerprints + typed tints change ZERO compiled bytes (drift=0 before/after on health + platformer packs); extends `event_lazy_spans_test`'s guarded invariants.
- `quick_add_tokenizer_test.gd` - quoted params with spaces fill correctly (`play "jump land"`); positional fill regression suite.
- `ghost_row_flow_test.gd` - E→sentence→⏎ applies the relevance-best ACE with zero dialogs; Esc/Ctrl+Enter reach the full picker; typing-suppression guard respected.
- `param_hop_scope_test.gd` - Tab nests at row scope, cycles at param scope; Esc transitions; post-insert continuation enters param scope; commits are single undo steps.
- `multi_edit_undo_test.gd` - apply-to-selection edits N matching params under ONE undo step; non-matching rows untouched.
- `shortcut_collision_test.gd` - B/I/R/F10/F12/Alt-arrows conflict-free vs `DEFAULTS` via `conflicting_action`, AND vs the viewport's hardwired structural keycode chain (the Alt-modifier guard on the KEY_LEFT/KEY_RIGHT fold branches - §12.1 collision #1).
- `navigate_resolver_test.gd` - each resolution-table row lands on the right sheet + row; built-in ACEs fall back to the picker info pane; history round-trips across a sheet reload via path+flat-index (never bare instance ids).
- `line_row_mapper_test.gd` - line ranges ↔ rows over `source_map` for event/function/raw/signal kinds; computed-live-only contract.
- `doctor_debug_residue_test.gd` - a sheet saved with `emit_breakpoints` ON is flagged; strip-and-resave yields a clean compile; conflict markers produce the friendly error.
- `runtime_error_routing_test.gd` - a synthetic error on a sheet-script line paints the red marker on the mapped row with the `runtime` chip; clears on next run.
- `sheet_diff_alignment_test.gd` - changed/added/removed rows tint correctly; ambiguous rewrites fall back to added+removed (never guess).

### 15.4 The deferred ledger (cut ≠ killed - each with its re-entry condition)

| Deferred device | Re-entry condition |
|---|---|
| Alt-drag number scrubbing (B) | after Param Hop proves the value-cursor model; resolve the three-drag-mode gesture arbitration first |
| Outline (Skim) canvas mode (A) | only if the Outline rail proves insufficient at 10k rows |
| Row blame gutter (D) | after the Mapper + Sheet Diff ship; off by default; OneDrive/`OS.execute` latency plan required |
| Per-row performance heat (D) | after paused-at-row + error routing prove the debug story; budget-threshold-only display; must not trip the residue check |
| Merge-conflict per-row pick (D v2) | after the diff aligner is battle-tested in the field |
| Pack-ACE rename propagation (D) | gated behind a dry-run preview dialog (files + row counts) + reference-coverage tests |
| Breadcrumb `Sheet › Group` segments (C) | after the banner-space audit with pills + health strip live |
| Picker host-class / in-this-sheet ranking boosts (B) | after frequency-weighted recents ship and prove non-disruptive |
| Imports strip expanded per-include fold (C) | second release of the strip |
| Per-knob Set/Add accessor auto-publish (Part I §9) | future enhancement; flagged NEW/unbuilt |

---

## 16. Adversarial review - Part II corrections & known gaps (receipts)

Two independent reviewers (buildability lens + persona/honesty lens) verified Part II against the working tree. Load-bearing corrections are folded into the sections above; recorded here with receipts so they are not re-tripped:

**Corrections applied (were wrong in the first draft):**
- **The §11.3 walkthroughs were fiction** - re-derived from the files: platformer = ➜4 · ⚡4 · **cond 5** · ƒx 3 · **@16**, health = **8 triggers · 16 actions · 5 conditions · 12 expressions · 3 knobs · ~80 ⚠ blocks**, `_process` is pool DECAY (no regen), the signal is `On Death`; **neither pack ships any groups**; platformer has trigger DECLARATION rows, not ➜ handler events. §11.3 now carries the real census + a zero-RawCode pack as the clean sentence exemplar; the grouped mockup is explicitly post-grooming.
- **Alt+Left/Right collides with the hardwired fold keys** (`event_sheet_viewport.gd:1412` matches KEY_LEFT with any modifiers) and **F10/F12 collide with Godot's editor debugger keys** - both arbitrations now in §12.1.
- **`BehaviourAnatomyPanel` cannot call `ViewportRowBuilder` directly** (viewport-host-bound) - §7.2 now specs the embedded read-only viewport mechanism.
- **The sentence hover cannot narrate raw statements** - the `…, then N lines of code` rule is now in §11.1; the full sentence experience exists only on lifted rows.
- **`✓ in sync` must never recompile ambiently** - pinned to save-time results (§11.1).
- **Sheet Diff needs a NEW foreign-read-only pane mode** (multi_view is same-sheet by design) - scoped into Wave 4; old-revision re-import may fail → degrade to text diff.
- Debugging P1 rows now carry the **⚠-block degrade** (pauses/errors inside RawCode land on the block - the §5.4 carve-out applies to debugging), the **step-into gap**, and live-state is regraded **partial** (per-instance private pack state unverified). Data-structures and input/controls got their own honest matrix rows. Palette path + pill counts corrected.

**Known gaps, recorded (not yet specced - candidates for the next revision):**
1. **Private members have no panel home** - rule: the Anatomy panel shows the PUBLIC surface only; private helpers, `_enter_tree`, and inner classes render on the canvas (the host-binding fold covers `_enter_tree` per the audit spec §4-B).
2. **Raw-block EDITING is the script editor** - for ⚠-heavy packs the supported expert path is the shipped jump (`_open_gdscript_path_in_godot`); the in-sheet code dialog is not trying to beat the script editor and should not pretend to.
3. **Per-param descriptions don't survive the pack path** - `ACEParam.description` exists but the `## @ace_*` grammar can't carry it; a `@ace_param(name, "help")` annotation + Studio wiring + pack authoring is a small C3-parity workstream.
4. **Trigger-signal args vs the last-value idiom** - the shipped packs deliberately use param-less signals + `last_*` expression getters; Part I's hero shows `on_damaged(amount)` with consumer binding. Verify consumer-side arg binding before the hero ships, or align the hero with the shipped idiom (which is also C3's own pattern).
5. **Pack upgrade/versioning** - a team consuming packs will update them; renamed/reshaped ACEs breaking consumer sheets is only partially covered by the gated rename-propagation ledger entry. Needs its own workstream when packs get an update channel.
6. **No code-free automated gameplay testing** - CI gates on Doctor (byte-identity + lint) only; a team cannot express even a smoke "game boots / behaviour ticks" check code-free. Honest gap; out of scope for this spec.
7. **The 5-second per-row promise degrades on ⚠-heavy sheets** (§11.3 honest contrast) - the real fix is the audit spec's lift roadmap (per-function gating, shell-lift), which this spec depends on but does not own.

Both reviewers' verdict was **needs-fixes on claims and honesty, not on the design** - the device portfolio, wave ordering, and covenant analysis were assessed sound.

---

## Appendix - MOCKUP BRIEFS

### Mockup Brief 1 - the Health-behaviour authoring canvas (Part I hero)

**Screen:** the *Health-behaviour authoring canvas* - the Behaviour Anatomy panel (left) + the logic canvas (right), with the ACE Studio popover open over the Actions organ. It must read at a glance as **beginner-friendly and code-free**: coloured verb cards and a picker preview dominate; the only monospace `func` text is one small, deliberately-secondary "Ships as:" line inside the Studio.

**Overall layout:** a dark editor-themed window. Left column ~300px wide: the **Anatomy panel**. Right: the **logic canvas**. A modal-ish **ACE Studio popover** floats over the centre-left, anchored to the Actions organ's `+Action`, dimming the panel slightly behind it.

**LEFT - Anatomy panel, top to bottom.** A panel header: a small heart glyph + `HealthBehavior` in title weight + a muted subtitle `attaches to CharacterBody2D`. Then seven fixed organ sections, each a slim header row `NAME · count` + organ glyph + a trailing `+`, with a subtle left accent-bar in the organ's hue:

- **PROPERTIES · 2** (blue accent) - two rows: `max_health : int = 100` and `regen_rate : float = 5.0`, each with a small blue `@export` pill and a purple `Health` group chip.
- **STATE · 1** (slate accent) - one row `current_health : int = 100` with a slate `internal` pill, dimmer than the Properties rows.
- **TRIGGERS · 2** (accent-colour bar) - `[trigger] On Damaged  [Health]` with muted `signal on_damaged(amount: int)`, and `[trigger] On Died  [Health]`.
- **ACTIONS · 2** (amber bar) - `[Action] Take Damage  ‹amount: int›  [Health]` with a muted right-aligned `func take_damage(amount: int) -> void`; and `[Action] Heal  ‹amount: int›`. The **`+Action`** footer glows (it's the source of the open popover).
- **CONDITIONS · 1** (teal bar) - `[Condition] ? Is Dead  → bool  [Health]`.
- **EXPRESSIONS · 1** (violet bar) - `[Expression] ƒx Health %  → float  [Health]`.
- **USES · 1** (grey bar) - `[uses] CharacterBody2D (host)` with a CharacterBody2D node glyph.

Empty organs (none in this hero, but show the pattern subtly if space allows) would carry a single ghosted hint row in the organ's hue.

**RIGHT - logic canvas.** Event flows whose header rows echo the organ badge hue. Show, stacked: (1) a regen tick `➜ On Physics Process` → indented `current_health < max_health` (teal condition cell) → `Add current_health  regen_rate * delta` + `Set current_health  min(current_health, max_health)` (amber action cells). (2) An amber-headed **Take Damage** body: `Set current_health = current_health - amount → Emit on_damaged(amount)`, and a sub-event `if current_health <= 0 → Emit on_died()`. Keep the canvas legible and clearly ACE-row-based - no raw GDScript visible.

**CENTRE - the ACE Studio popover** (the crown jewel; make it the visual focus). A themed card titled **"Define an Action"**. Top: **three big colour-coded cards** side by side - **"Does something"** (amber, selected/highlighted, sub-label *Take Damage, Heal, Knock Back*), **"Is it true?"** (teal, *Is Dead, Is Full Health*), **"A value"** (violet, *Health %, Remaining Shields*). The amber card is picked (it was launched from the Actions organ). Below the cards, a compact form: **Name** `Take Damage`, **Description** `Reduce health by an amount`, a **Parameters** row `amount : a number (float)`.

Down the **right side of the popover**, a panel captioned **"This is what other people will see"** rendering a REAL picker entry in the exact canvas chrome: the behaviour heart icon, an amber `Action` badge, `Take Damage`, a param chip `amount`, a `Health` category chip, and under it a muted one-liner `Health › Take Damage  amount 25`.

Directly **beneath the preview**, a single small monospace line labelled **"Ships as:"** reading `func take_damage(amount: int) -> void` in muted colour, with a tiny "show annotations ▸" disclosure and a "Copy" affordance. This is the ONLY code-looking text on the whole screen and it is deliberately quiet and secondary. Popover footer: a prominent **Create** button.

**Colour discipline for the mockup:** blue = Property, slate = State, accent = Trigger, amber = Action, teal = Condition, violet = Expression, grey = Uses - consistent between the panel badges, the canvas headers, and the three Studio cards. The eye should land first on the amber-highlighted "Does something" card and the live picker preview, and only find the small "Ships as:" `func` line on a second look - proving the screen reads code-free to the C3 refugee while still spelling out the exact GDScript for the Godot dev.

### Mockup Brief 2 - the sheet at a glance (Part II hero)

**Screen:** the *platformer sheet at a glance* - `platformer_movement_behavior.gd` open AS A SHEET in the full dock, wearing the Wave-1 glance-layer devices, with ONE inline edit open (a Ghost Row mid-add). It must prove the two Part II bars in one image: a stranger reads the sheet in 5 seconds with zero clicks, and the one open edit shows authoring happening *in the canvas, in a sentence, with no dialog anywhere on screen*. **Grounding note (§16):** the mockup depicts the pack AFTER the Wave-1 flagship-pack grooming task (Movement/Reactions groups + example reaction events added to the builder) - today's shipped pack is ungrouped with trigger declarations only; the pill counts below are the REAL census (cond 5, @16).

**Overall layout:** a dark editor-themed window, full-width canvas (no left rail in this hero - it shows the raw-canvas reading experience; the Anatomy/Outline rail belongs to Mockup 1's world). A slim identity banner across the top; the virtualized event canvas below; a muted add-event footer at the bottom. Calm is the aesthetic law: apart from the four tempo hues, the amber ⚠ badge, and the Ghost Row's caret line, the canvas is flat and quiet - no per-row chrome, no key-hint chips on rows.

**TOP - the identity banner (one ~40px band, the §11.2 layout law).** Far-left: small muted history arrows `◀ ▶`. Left: a gear glyph + `PlatformerMovement - Behavior · acts on host: CharacterBody2D` in title weight. Directly under it, the **Publishes Manifest** line: five small role-hued count pills - `➜ 4 triggers` (green), `⚡ 4 actions` (amber), `cond 5` (teal - the word `cond`, NOT a `?` glyph), `ƒx 3` (violet), `@ 16 knobs` (blue). Right end: the **health strip** - three calm chips `✓ compiles · ✓ in sync · 0 flagged` in green-greys.

**CANVAS, top to bottom:**

1. A folded blue **@export strip** row: `Properties · 16 knobs  ▸` (collapsed - the knobs are one fold away, not eating the hero).
2. A **group header** `▼ Movement` with its accent bar and the right-aligned muted **fingerprint** `8 events · ⟳1 · ➜4 · ⚠1`.
3. Inside it, the **movement kernel event**: a large hot-amber **⟳** badge in the condition-lane badge column, condition cell `Every physics tick`, and an action lane of 3–4 flat action cells (`Apply gravity  capped at Max Fall Speed`, `Move toward  Target Speed  at  Acceleration`, `Update coyote timer  coyote_time`) - parameter values (`Max Fall Speed`, `450`, `0.12`) glowing in the **typed value tints** (numbers in value-green, strings in the second tint). This row also carries the **sentence hover**: a tooltip floats off it reading *"Every physics tick - do: apply gravity capped at Max Fall Speed, move toward Target Speed at Acceleration (+2 more)"* with a second muted line showing one line of codegen preview - the tooltip is the only floating element besides the Ghost Row popup.
4. One **⚠ code** row (the shipped amber badge): `⚠ jump kernel (GDScript) · 12 lines  ▸` - folded, visibly the exception.
5. A second **group header** `▼ Reactions` with fingerprint `4 events · ➜4`.
6. Two **➜ green signal rows**: `➜ On Landed → Play "land" · Set animation "idle"` and `➜ On Wall Jumped → Play "wall_jump" · Flip sprite`.
7. **THE OPEN INLINE EDIT - the Ghost Row** (the hero's second focal point, directly under `On Landed`): a custom-drawn editing line at the exact insertion point - a caret, the typed text `play sound land`, on the row where the new action will land (indented into On Landed's action lane). Anchored directly beneath it, ONE small completion popup listing the top matches: `★ Audio › Play Sound  "land"` (highlighted, ★ recent), `Audio › Play Sound At Position`, `Audio › Set Volume`, with a muted footer line inside the popup: `⏎ add · Ctrl+⏎ browse all · Esc cancel`. No dialog anywhere on screen.
8. **BOTTOM - the add-event footer**: the shipped muted `+ Add event` line carrying its single key-hint chip `(E)` - the ONLY key hint on the whole screen.
9. A remaining collapsed group `▶ Wall Slide - 3 events · ⟳1 · ➜2` proving collapsed groups still read.

**Colour discipline:** the four tempo hues (⟳ hot amber-orange, ➜ C3 green, ⌨ object blue, ▶ muted violet) + the role pill family on the banner are the SAME named palette constants as Part I's organ hues - one legend across both heroes. Typed tints use exactly two hues beyond value-green. The eye should land first on the banner pills (what is this?), second on the big ⟳ vs the ➜ stack (what runs when?), third on the Ghost Row (how do I write here?) - and never find a `func`, a dialog, or a line of raw code outside the single folded ⚠ row.
