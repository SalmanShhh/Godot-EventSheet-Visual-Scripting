# Designing Event-Sheet Visual Scripting for Any Engine

This document teaches the architecture behind event-sheet visual scripting in an
engine-agnostic way. It is written for three readers: someone porting event sheets into
another engine or tool, someone considering them as the scripting layer of a custom engine,
and someone who wants to understand why this repository is shaped the way it is. Godot
EventSheets is used throughout as the worked example, but every section states the general
principle first and the Godot-specific realization second. Everything here was learned by
building and shipping; the traps at the end cost real days.

## 1. The thesis: sheets are the shape code already has

An event sheet is a grid. The left column holds a trigger and conditions; the right column
holds actions; rows nest. That grid is not a simplification of code - it IS the structure
of code with the syntax removed:

| Sheet element | Code element |
|---|---|
| Trigger | Event handler / callback / subscription |
| Condition chain | Guard clauses (`if a and b:`) |
| OR-mode conditions | `if a or b:` |
| Pick filter ("For Each X") | Iteration / a query over a collection |
| Actions | Statements, in order |
| Sub-events | Nesting (the body of the guarded block) |
| Else/Else-if rows | `else:` / `elif:` chains |
| Functions / groups / includes | Procedures / regions / modules |
| Expressions | Expressions, verbatim |

This mapping is what separates event sheets from node-and-wire graphs. In a graph, control
flow is spatial: execution follows wires that can wander anywhere on a canvas, and the
picture resembles nothing in the code it becomes. Godot's own VisualScript was retired for
exactly that gap. A sheet keeps what code is made of - order, guards, loops, nesting - and
replaces only the syntax with a picker and readable sentences. Everything a user learns in
the sheet transfers to text scripting, and everything a programmer knows reads straight off
the sheet.

**The design rule that follows:** every feature must land on the grid. Branching is a
condition; an effect is an action; iteration is a loop row; a switch is a structured
match row; even async waiting is an action (an hourglass-marked one). The moment a feature
ships as a text blob or a special side panel, the model leaks. This repository enforces the
rule culturally (it is a standing contract) and it held for OR-blocks, switch/case,
setters/getters, looping conditions from behavior packs, and async events alike.

**Where visual deliberately stops:** expressions. Arithmetic, comparisons, and property
paths gain nothing from boxes and wires; they are already at their most readable as text.
The honest boundary is: STRUCTURE is visual, COMPUTATION is textual. Here the expression
field is a real host-language expression with live validation and autocomplete, not a
sub-language. Attempting expression graphs is the classic way event-sheet clones die -
they spend their complexity budget where text was already winning.

## 2. The four-part architecture

Every workable implementation splits into four parts. Get the boundaries right and each
part stays replaceable.

### 2.1 Data model

Events, conditions, actions, triggers, pick filters, comments, groups, functions, and
variables are plain serializable records - here, Godot Resources (`EventRow`,
`ACECondition`, `ACEAction`, `PickFilter`, `EventFunction`). Two decisions matter:

- **Rows carry their compiled form, not references into the vocabulary.** An applied
  condition stores its own baked codegen template (with per-instance ids already
  substituted). The registry is needed to PICK a verb, never to COMPILE one - so sheets
  compile standalone, vocabulary updates cannot silently change shipped sheets, and
  renaming registry entries cannot corrupt anything. This is the compatibility covenant:
  ids and templates are promises; deprecate, never rename.
- **Stable row identity.** Every event carries a short uid, minted at apply time and kept
  stable across edits. Uids name per-instance compiled state (`__busy_<uid>` members,
  split-out coroutine names) and anchor source maps. Mint them in the EDITOR at apply
  time, never in the compiler - a compiler that mints ids is nondeterministic, and
  determinism is load-bearing (see 2.4).

### 2.2 Vocabulary registry

A verb ("Take Damage", "Is On Floor", "Wait") is a definition: id, display template,
codegen template, typed parameters with widget hints, category, and optional stateful
extras. Lessons that generalize:

- **Two templates per verb, same placeholders.** The display template renders the sentence
  ("wait {seconds} s"); the codegen template renders the code
  (`await create_timer({seconds}).timeout`). Localization translates the display template
  and substitutes the slots after; codegen never touches locale.
- **Derive vocabulary from ordinary code, not manifests.** The strongest decision in this
  repo: a behavior pack is a plain script whose annotated members become verbs
  (`@ace_condition`, `@ace_name(...)`, doc comments as descriptions). No JSON, no
  registration call, no second source of truth. Any engine with reflection or a parsable
  source form can do this, and it makes the extension surface feel native to programmers.
- **Stateful verbs need a lifecycle, not special cases.** "Every X Seconds", "Trigger
  Once", and "Once At A Time" all fit one shape: a per-instance member declaration, a
  prelude line (before the if), an on-true line (inside it), and an on-exit line (after
  the whole body - which in a coroutine body means after the last await). Ship the four
  hooks as one generic mechanism and packs can build their own latches.
- **Parameter hints are the picker's UX.** A hint string per parameter routes to a widget:
  expression field, live enumerations (input actions, node groups), key capture, rich
  BBCode editing, color. Enumerate live at dialog-open, never bake option lists at
  registration - baked lists go stale the moment the project changes.

### 2.3 Compiler to plain code

Sheets compile to idiomatic source in the host language with ZERO runtime dependency -
delete the tool and the game still runs. This is the parity contract, and it is the answer
to the deepest objection to visual scripting (the interpreter tax and the lock-in). The
compiler is a straightforward tree walk: trigger groups become handler functions;
condition chains become one `if` joined with and/or; pick filters emit real `for`/`while`
loops; actions emit their baked templates line by line.

The details that carry:

- **Emission is deterministic.** No timestamps, no randomness, no map-iteration-order
  dependence. Determinism is what makes byte-exact verification (2.4), golden files, and
  drift audits possible at all.
- **Group by trigger, then guard the shared bodies.** Multiple events on one per-frame
  trigger share one handler. That sharing has a hidden hazard in coroutine-capable
  languages: an await in one event suspends the WHOLE handler and freezes its siblings.
  The fix is structural - an awaiting event splits into its own function called
  fire-and-forget from the dispatcher - and it must round-trip (2.4).
- **Emit a source map.** Per row: the emitted line range. It powers row-to-code
  navigation, breakpoints, paused-at-row jumps, and live execution highlighting. One rule
  keeps it sound: any multi-line synthesized member must be tracked one entry per line,
  or every row below it mis-maps.
- **Warn, never wedge.** Unsupported combinations (frame-spreading with order-by,
  else-chains that cannot chain) degrade to the plain form WITH a compile warning. A
  compiler that refuses teaches nothing; one that silently alters semantics is worse.

### 2.4 Round-trip: the sheet and the code are the same artifact

The covenant that defines this implementation: opening a compiled file as a sheet and
saving it untouched reproduces the file BYTE-IDENTICALLY. Not "exports to code" - the .gd
file IS the sheet. This is what makes the exit ramp flat (graduating to code is noticing
you already understand the code your sheets wrote) and what lets sheets live in version
control as reviewable source.

The machinery generalizes:

- **The importer is the compiler's inverse, grammar for grammar.** For every emitted shape
  there is a lift that recognizes it; every lift is GATED by re-emitting and comparing
  bytes. A lift that cannot reproduce its source must not fire - it degrades to a
  verbatim block instead. Degrade-never-corrupt is the whole safety story: worst case the
  user sees an uneditable code block, never a changed file.
- **Metadata rides annotations, not code.** Class-level facts (tags, category, family,
  dependencies, version) emit as comment-annotations (`## @ace_requires(a, b)`) that are
  RECONSTRUCTED from resource fields on emit and recovered header-scoped on lift. The
  recovery must be the exact string inverse of the emission (a `", ".join` lifts as a
  split-and-strip) or bytes drift. Empty defaults emit nothing, so adding a new
  annotation field is byte-neutral for every existing file.
- **Generated adjuncts must be consumed, not kept.** When the compiler injects derived
  lines (a validity guard at the top of an awaiting loop, a dispatcher call to a
  split-out coroutine), the lifter must recognize and CONSUME them, and the emitter must
  regenerate them under exactly the same condition. If the lift keeps the line as a row,
  re-emission doubles it. And beware the false positive: a byte-identical round trip does
  NOT prove consumption happened - a kept-verbatim line also re-emits identically - so
  test consumption directly.

## 3. Targeting different languages and engines

The four parts are language-neutral; the codegen templates and a thin emission layer are
the only parts that change. What varies by target:

- **Statically typed targets (C#, C++, GDScript-typed).** Parameters need declared types
  and the emitter needs literal-form rules (how a Color, a vector, a string literal is
  written). A cheap linter that flags obviously-wrong literals in typed slots (a quoted
  "200" in an int slot) pays for itself; anything beyond whole-value literals must stay
  unjudged or the linter cries wolf.
- **Coroutine support decides the async story.** GDScript and Lua make "Wait 2 seconds"
  one emitted statement (handlers are implicit coroutines); C# needs async/await plumbing
  in the handler signatures; JS needs the same. A language WITHOUT coroutines needs a
  state-machine transform or a scheduler runtime - which breaks the zero-runtime parity
  contract, so consider shipping async verbs only on capable targets. Whatever the
  mechanism, the semantics to preserve are: later actions in the same event wait, sibling
  events never wait, objects freed during a wait are skipped on resume, and users get a
  one-checkbox re-entry gate.
- **Signal/event-bus availability shapes triggers.** Engines with first-class signals
  (Godot) compile triggers to connected handlers. Engines without need a subscription
  shim - the one place a tiny generated preamble is acceptable, still inside the emitted
  file.
- **ECS-style engines invert the pick model.** In node-tree engines a pick filter iterates
  a group or children; in an ECS it is a query over components. The grid is unchanged -
  "For Each entity with Health < 20" is still a loop row - only the collection expression
  changes. Resist building a real archetype layer into the sheet tool; compile to the
  engine's own query API.
- **A bytecode VM target** collapses the compiler and the parity contract into one: emit
  the VM's source form and let the VM own performance. The round-trip covenant is then
  between the sheet and that source form.

## 4. The extension surface: packs as sheets

The single most compounding decision: behavior packs (the standard library of movement,
health, timers, drawing) are THEMSELVES event sheets, compiled by the same compiler,
published by the same round-trip rules. Self-hosting means every feature the tool gains,
its standard library gains; every lift bug the packs would hit, the drift gate catches
first (an audit re-emits all 75 packs and requires zero byte drift).

The seam pattern that grew out of this deserves copying anywhere: a pack opts into editor
integration by shipping a PURE STATIC function on its emitted script, duck-typed by name -
`editor_preview_sample(params, base, time)` animates the selection,
`editor_gizmo_draw(params, host, canvas)` draws setup overlays,
`debugger_properties()` joins the live-values stream. The emitted script never runs in the
editor; its statics are merely callable from it. One function, zero editor coupling in
generated code, and a registration fallback (`register_editor_preview(path, callable)`)
covers scripts that cannot ship the static. Dependencies, versioning, and translations
ride the same annotation channel (`@ace_requires`, `@ace_version`, a drop-in
`translations.csv` per pack), each byte-neutral when absent.

Alongside the sheet-level verbs, keep ONE public API facade (here `EventSheets`, an
all-static class) as the only supported extension entry: vocabulary registration, doctor
checks, palette commands, the undo-funneled `edit()` mutation. Freeze its shapes like verb
ids. Every editor feature that can be a thin shell over a public API call should be one -
the Scene-dock signal connect and the Inspector property drop are both one-call shells,
which makes them testable headless and reusable by third-party tooling.

## 5. Editor architecture that survives scale

- **A virtualized, custom-drawn canvas - never per-row widgets.** Ten thousand rows with
  widget-per-cell dies in any UI toolkit. One control draws visible rows from row data
  structs; spans within a row carry hit-rectangles for clicks. All transient overlays
  (execution pulses, diagnostics, drag arrows) are paint passes over the same data.
- **One mutation funnel.** Every sheet edit goes through a single undoable-edit function
  whose commit replaces resources with snapshot duplicates. Consequences: undo is trivial
  and complete, and NO code may cache a row across an edit (re-fetch from the live sheet
  every time). Enforce the funnel from day one; retrofitting undo is misery.
- **Editor conveniences meet users where the engine already works.** Connecting a signal
  from the scene dock, dragging a property from the Inspector, dropping a node onto a
  parameter - each maps an existing engine gesture onto a sheet mutation. These cost
  little (they are shells over the API) and do more for adoption than novel UI.
- **Debugging rides the engine's debugger channel.** Compiled sheets optionally stream
  throttled value frames and fired-row batches over the engine's debug messaging; the
  editor maps uids back to rows (pulse the fired ones, fading over half a second) and
  breakpoints compile to real breakpoint statements plus a row announcement. All of it is
  opt-in flags on the sheet, with a doctor check that flags debug residue before release.

## 6. The traps, generalized

Each of these cost real time here and will recur in any port:

1. **A silent test harness.** A test that crashes reports zero failures. Always print and
   check a positive verdict line ("All tests passed."), never grep for failure markers.
2. **Byte drift from emission order.** Class-level annotation lines have a fixed relative
   order; inserting a new one anywhere but its frozen position fails every golden. Decide
   the header order early and treat it as API.
3. **Uid-dependent members must derive from row uids** (stable), never from counters or
   fresh randomness at compile time - or every recompile rewrites the file.
4. **Reflection that reads from disk.** If vocabulary derivation parses source files, an
   unsaved or pathless script parses EMPTY. Test fixtures must actually write files.
5. **Float precision in defaults.** Building a rotated frame from `rotate(angle - 90)`
   with the default at 90 gives EXACT identity (rotate(0) returns its input); building it
   from `cos/sin` gives 1e-17 noise that changes emitted behavior subtly. Choose
   constructions whose defaults are bit-exact, and pin that exactness in tests. In
   engines with 32-bit vector math, compare rotated results by distance, not per
   component.
6. **The lift-consumption false positive.** Round-trip-passes is not lift-is-structural.
   Test the lifted STRUCTURE (row counts, uids, no kept generated lines), not just bytes.
7. **Boot-time compile graphs.** In languages where naming a class compiles its whole
   dependency subtree (GDScript), editor-plugin boot files must reference heavy
   subsystems by path-load at call time, or plugin boot balloons from milliseconds to
   seconds. Add a lint test that forbids the class names in boot files.
8. **Trigger handlers that share state with the engine's virtuals.** A per-frame handler
   synthesized by the compiler and a user's hand-written one must merge, not collide;
   decide the injection points (telemetry before user logic, connections before ready
   logic) once and pin them.
9. **Advisory checks must be conservative by contract.** Every doctor-style lint here
   ships with must-NOT-fire tests as prominent as its fire tests. The first false
   positive teaches users to ignore the whole panel.

## 7. Where to start a port

Build order that keeps every stage shippable:

1. Data model + compiler for trigger/conditions/actions only, with golden-file tests and
   the determinism rule from day one.
2. The vocabulary registry with both templates per verb and a picker that searches
   display text. Hand-write ten verbs before building reflection.
3. The round-trip importer for exactly the shapes the compiler emits, byte-gated, with
   verbatim-block degrade. This is the point of no return: after it works, every emitter
   change requires its inverse, forever. It is also the moment the tool becomes honest.
4. Pick filters, sub-events, else-chains, functions - each with its lift.
5. Reflection-derived vocabulary from annotated scripts; then packs-as-sheets and the
   drift audit over all of them.
6. Editor conveniences, debugging channels, and the seam statics - each as a shell over
   the public API.

The one-sentence summary of everything above: keep the grid honest to code, compile to
the user's own language with nothing attached, make the compiled file and the sheet the
same bytes, and grow the vocabulary from ordinary annotated source - the rest is
engineering.
