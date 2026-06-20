# Code-Free Roadmap — moving the "stay in event sheets" boundary

The plugin is a **bridge, not a wall** (see README): it compiles to readable GDScript and is
meant to *teach* GDScript, not hide it forever. The realistic goal is **not** "literally zero
GDScript" — expression fields *are* GDScript — but rather: *a confident non-programmer in the
target genres never has to open a code block, and the expressions they fill in are **picked,
not typed***.

Code leaks into an otherwise-visual sheet in three places, in order of how often you hit them:

1. **Expression / value fields** (the `ƒx` fields — `health - 10`, `enemy.position.distance_to(position)`)
2. **Helper-ACE string params** (Call Method / Set Property / Run GDScript)
3. **Full GDScript blocks** (logic no ACE covers)

This doc specs five features that plug those leaks. Status: ✅ shipped · 🟡 partial · 📋 spec.

---

## 1. Visual expression builder ✅ (the single biggest lever)

**Shipped:** the `ƒx` "Insert Expression" picker now also lists the sheet host class's own
reflected members under **This Object — Properties** and **This Object — Methods**; picking one
inserts `name` (property) or `name()` (method). (commit fb9acdd)

**Problem.** The `ƒx` fields are text boxes with autocomplete + a node picker — you still *type*
`node.property` / `node.method()`. Most "code" in a visual sheet lives here.

**Design.** A "pick-don't-type" expression picker, reachable from the `ƒx` button on any
expression param:
- Select a node (reuse the existing node picker), then choose its **property / method / signal**
  from a menu reflected from `ClassDB` (`ClassDB.class_get_property_list`, `class_get_method_list`),
  filtered by the param's expected type.
- Chain picks to build a compound expression (`A.b().c`), inserting into the same text field so
  experts can still type. The builder is a *front-end* to the text — it never replaces it.
- Operator palette (`+ - * / and or not < > ==`) + literal entry for the leaf values.

**Where (as shipped).** No separate dialog was needed — the host-member groups render inside
`ace_params_dialog.gd`'s existing expression picker, alongside the expression templates on the
`ƒx` button, and reflection reuses the `reflected_members` helper. The operator-palette /
pick-chaining / signal-filtering sketched in the design above remain future polish.

## 2. Reflection-to-ACE + Call Method / Set Property pickers ✅

**Shipped:** the Helper ACEs **Call Method**, **Call Method (value)**, **Set Property**, and
**Get Property** now offer the host class's real members as an editable suggest-combo — pick from
real members, or still type one reflection misses. (commit 5f16deb)

**Problem.** Helper ACEs (Call Method, Set Property, Run GDScript) are the "anything" valve but
require typing code-shaped strings.

**Design.**
- **On-demand reflection**: an "expose this node's members as ACEs" action that reflects any
  node type's methods/properties/signals into ACE definitions (the plugin already does this for
  custom addon scripts — extend `ace_generator.gd` / the addon scan to any built-in node on
  request, cached per class).
- **Member pickers** inside Call Method / Set Property: a dropdown of the *target's real*
  methods/properties (`hint: "method_reference"` / `"property_reference"`), with arg fields, so
  the escape hatch needs zero typed code.

**Where.** `addons/eventforge/registration/ace_generator.gd` (already resolves method/property
ACEs from reflection — `_resolve_method_ace_type`), `ace_params_dialog.gd` (new hint field types
next to the existing `signal_reference` / `animation_reference` pickers). **Effort: M.**

## 3. Promote block → reusable Function / ACE  ✅

**Shipped:** a row's **More ▸ Extract GDScript to Function** gathers that event's inline GDScript
(RawCode) actions into a new reusable `EventFunction` (auto-exposed as an ACE under the Functions
category) and replaces them with a call. (commit 9a6da84)

**Problem.** A one-off GDScript block stays a one-off; the code surface never shrinks.

**Design.** A row context-menu action on a GDScript block (or selected rows): **Extract to
Function** — moves the code into a new `EventFunction` (exposed as an ACE), and replaces the
block with a call to it. Same shape as the existing **Extract Selection to Include**. Written
once, then it's a click forever.

**Where.** `event_sheet_dock.gd` (mirror `_do_extract_to_include` / the row "More" menu);
`EventFunction` already supports `expose_as_ace`. **Effort: M.** *(First implementation of this
lever — see the matching commit.)*

## 4. Visual data editors ✅

**Shipped:** Array / Dictionary variable defaults get an **Edit items…** button in the Variable
dialog that opens a one-item-per-line editor instead of forcing a literal like `[1, 2, 3]`; it
round-trips losslessly through the literal. (commit a181a77)

**Problem.** Complex data still means typed `[...]` / `{...}` literals.

**Design.** A table/tree editor for Array and Dictionary variable defaults (add/remove/reorder
rows, typed cells), and first-class, discoverable **authoring of custom classes/resources as
sheets** (behavior packs already prove the mechanism — surface it in New… and the picker).

**Where.** `variable_dialog.gd` (a structured editor for Array/Dictionary defaults instead of a
text field). **Effort: M–L.**

## 5. Visual step / watch debugging ✅ (conditional breakpoints) · 📋 (rest)

**Problem.** Code-free authoring only works if code-free *debugging* does too.

This section is a bounded slice: **conditional breakpoints** shipped; event-level step-through
and watch expressions remain spec.

### Conditional breakpoints ✅ SHIPPED (commit a181a77)

A row's **More** menu gains **Set Breakpoint Condition…**: it stores a GDScript boolean
expression, and the compiler emits `if <cond>: breakpoint` instead of a bare breakpoint, so you
pause only on the frame that matters (e.g. `health <= 0`) rather than every pass. Blank clears
the guard. Builds on the existing F9 real breakpoints + the Tools menu Debug Breakpoints toggle +
editable Live Values. This is conditional breakpoints only — **not** step-through or watch
expressions.

**Where.** `addons/eventforge/resources/event_row.gd`,
`addons/eventforge/compiler/sheet_compiler.gd`, `event_sheet_dock.gd`.

### Event-level step-through 📋

**Design.** Step the sheet event-by-event on top of the existing breakpoint plumbing.

### Watch expressions 📋

**Design.** Pin an `ƒx` expression and see its live value; surface plain-language errors
("`position` needs a Node2D") instead of raw GDScript parse errors. **Effort: L.**

---

## Suggested sequence

All five items have shipped. (#5 shipped as a bounded slice — conditional breakpoints only;
event-level step-through and watch expressions remain spec.)

| Priority | Item | Effort | Notes |
|---|---|---|---|
| 1 | Visual expression builder (#1) | L | ✅ shipped — most-typed code becomes clicks |
| 2 | Reflection pickers (#2) | M | ✅ shipped — removes the escape-hatch typing |
| 3 | Promote block → Function (#3) | M | ✅ shipped — shrinks the block surface permanently |
| 4 | Visual data editors (#4) | M–L | ✅ shipped — removes typed literals/state |
| 5 | Visual step / watch debugging (#5) | L | ✅ conditional breakpoints shipped; step-through + watch still spec |

## Collision Helper ACEs ✅

**NEW: Collision Helper ACEs** (commit baae1a2) — 24 new ACEs. **CharacterBody2D** (Is On Wall,
Is On Ceiling, Get Wall Normal, Get Floor Normal, Get Slide Collision Count, Get Last Slide
Collider, Get Last Slide Normal), with **CharacterBody3D** carrying the wall/ceiling/normal
subset. **Area2D** (Overlaps Body, Overlaps Area, Has Overlapping Bodies/Areas, Get Overlapping
Bodies/Areas), with **Area3D** Has/Get Overlapping Bodies. **CollisionObject2D** (Set Collision
Layer Bit, Set Collision Mask Bit, Is On Collision Layer). **CollisionShape2D** (Enable Shape /
Disable Shape). All compile to plain GDScript.

Plus continuously: **close the remaining vocabulary gaps** (dialogue, transitions, 2D
point/shape overlap, loop-index) so fewer things ever need a block.
