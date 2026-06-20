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

## 1. Visual expression builder 📋 (the single biggest lever)

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

**Where.** New `addons/eventsheet/editor/expression_builder_dialog.gd`; hook into
`ace_params_dialog.gd` where the `expression` hint renders the `ƒx` button (the same place the
node picker is wired). Reflection mirrors `ace_picker.gd::editor_icon` / the addon reflection
path. **Effort: L.** This is the highest-value item; build it first when tackling the big three.

## 2. Reflection-to-ACE + Call Method / Set Property pickers 📋

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

## 3. Promote block → reusable Function / ACE  🟡

**Problem.** A one-off GDScript block stays a one-off; the code surface never shrinks.

**Design.** A row context-menu action on a GDScript block (or selected rows): **Extract to
Function** — moves the code into a new `EventFunction` (exposed as an ACE), and replaces the
block with a call to it. Same shape as the existing **Extract Selection to Include**. Written
once, then it's a click forever.

**Where.** `event_sheet_dock.gd` (mirror `_do_extract_to_include` / the row "More" menu);
`EventFunction` already supports `expose_as_ace`. **Effort: M.** *(First implementation of this
lever — see the matching commit.)*

## 4. Visual data editors 📋

**Problem.** Complex data still means typed `[...]` / `{...}` literals.

**Design.** A table/tree editor for Array and Dictionary variable defaults (add/remove/reorder
rows, typed cells), and first-class, discoverable **authoring of custom classes/resources as
sheets** (behavior packs already prove the mechanism — surface it in New… and the picker).

**Where.** `variable_dialog.gd` (a structured editor for Array/Dictionary defaults instead of a
text field). **Effort: M–L.**

## 5. Visual step / watch debugging 📋

**Problem.** Code-free authoring only works if code-free *debugging* does too.

**Design.** Build on the existing real breakpoints + Live Values: **event-level step-through**,
**watch expressions** (pin an `ƒx` expression and see its live value), and **conditional
breakpoints**. Surface plain-language errors ("`position` needs a Node2D") instead of raw
GDScript parse errors.

**Where.** The Live Values + breakpoint plumbing in `event_sheet_dock.gd` / the debugger bridge;
a new watch panel. **Effort: L.**

---

## Suggested sequence

| Priority | Item | Effort | Notes |
|---|---|---|---|
| 1 | Visual expression builder (#1) | L | 80% of the "code-free" win; most-typed code becomes clicks |
| 2 | Reflection pickers (#2) | M | removes the escape-hatch typing |
| 3 | Promote block → Function (#3) | M | shrinks the block surface permanently |
| 4 | Visual data editors (#4) | M–L | removes typed literals/state |
| 5 | Visual step / watch debugging (#5) | L | code-free *debugging*, not just authoring |

Plus continuously: **close the remaining vocabulary gaps** (dialogue, transitions, 2D
point/shape overlap, loop-index) so fewer things ever need a block — and the new **Collision
Helper ACEs** are part of that ongoing work.
