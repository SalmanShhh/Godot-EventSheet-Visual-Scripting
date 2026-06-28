# Spec — Rendering GDScript blocks as event rows (improving the code-free experience)

**Status:** **P1 implemented** — `is_scaffolding_code()` (unit-tested classifier), the foldable
"Class setup" strip that collapses a leading run of scaffolding rows, type-aware block styling, and an
inline `lift_note` "⚠ code" badge — all editor view-state, zero codegen change (see
`event_sheet_viewport.gd` + `blocks_scaffolding_test`). P2 (on-demand "convert to rows", code→ACE
autocomplete, coverage meter) and P3 (statement-level partial lift, vocabulary authoring) remain
proposed. **Audience:** maintainers / tools engineers. **Goal:** make a GDScript
block in an event sheet feel like a first-class, understandable part of the sheet — and shrink how much
of a sheet *is* a block — so designers get closer to "no code anywhere" while experts keep full power.

This spec maps the current state, names *why* a block stays a block, then proposes a prioritized set of
UI/UX solutions. It does not change behaviour by itself.

---

## 1. Why this matters (tie to the product north star)

A core goal is **fully code-free authoring for non-coder game designers** (Construct-style), while the
tool also **teaches GDScript** and stays **incredibly fast for experts**. A GDScript block is the seam
between those worlds. Today a block is honest and lossless, but it reads as "here be code" — a wall a
designer can't cross. Every block we can (a) turn into rows, (b) make legible, or (c) visibly mark as
*structural, not logic* moves the sheet toward code-free without lying about what compiles.

The lossless contract is non-negotiable: a `.gd` round-trips byte-exact (drift=0). Anything here must
preserve that — these are **editor-rendering and authoring affordances**, never silent code rewrites.

---

## 2. Current state (what exists today)

### 2.1 Data model — `RawCodeRow` (`addons/eventforge/resources/raw_code_row.gd`)
- `code: String` — verbatim GDScript, emitted as-is (byte-exact).
- `enabled: bool` — disabled blocks compile out (strike-through in the sheet).
- `source_line: int` — back-link to the generated GDScript line (sheet ⇄ code-panel linkage).
- `note: String` — editor-only "what this does" label (hover).
- `lift_note: String` — editor-only triage hint ("why it stayed code"), set by the importer when no
  reverse template matched (e.g. `"no matching ACE template"`).

### 2.2 Rendering (`event_sheet_viewport.gd` + `event_row_renderer.gd`)
- A multi-line block is split into **one span per line** (shared `ace_index`, so it acts as one unit),
  then the renderer **merges them into one visual cell** (`resolve_block_groups`): a cool desaturated
  tint (`CODE_CELL_BG`) with a 2px muted **left stripe** (`CODE_CELL_STRIPE`), a `GDScript` badge on the
  first line, indentation preserved, zoom-aware crisp text. Selection/hover highlight the merged cell.
- Lives in the **action lane** (or top-level for prelude/scaffold rows).

### 2.3 The de-coding pipeline (the lever)
- `EventSheetACELifter` reverse-lifts code → ACE rows by **reverse template matching**
  (`_build_reverse_entries` builds an anchored regex per ACE `codegen_template`, sorted most-specific
  first; `_consume_action_line` / `_parse_conditions` match line-by-line). A line that matches no
  template stays a block. The whole lift is **byte-round-trip gated** (revert if recompile differs).
- A new reverse template costs ~nothing to add: give an ACE a `codegen_template` and the lifter indexes
  it automatically on the next import.

### 2.4 Existing block affordances
- Hover tooltip: `GDScript (verbatim) — emitted as-is`, plus `note` / `⚠ Stayed as code: {lift_note}`.
- Double-click → **Edit GDScript Block** dialog (syntax-highlighted `CodeEdit`, compile-lint, **Open in
  Godot Script Editor**).
- Right-click → Edit / Delete / Disable / Copy / Insert GDScript block below.
- **Sheet ⇄ GDScript panel linkage**: selecting a block highlights its generated lines, and vice-versa.

---

## 3. The two kinds of block (the key framing)

Blocks remain for **two fundamentally different reasons**, and the UX should treat them differently:

| Kind | Examples | Should it be code-free'd? | Right UX move |
|---|---|---|---|
| **A. Structural scaffolding** | class prelude (`class_name`/`extends`/`@icon`/doc), the `_enter_tree` host binding, `## @ace_*` annotation blocks, blank separators | **No** — it isn't *logic*, it's the file's skeleton | **De-emphasise / collapse** so it stops competing with the logic |
| **B. Un-lifted logic** | a custom expression, a `var x := …`, control flow or a call with no ACE template | **Yes, ideally** — it's real logic that *could* be a row if vocabulary covered it | **Clarify why + offer paths to convert** |

Measured on the platformer pack today: ~47 statements lift to ACE rows, ~27 stay as blocks — and almost
all of those 27 are **kind A** (prelude, scaffold, annotations, a couple of inferred-type locals). So the
single biggest perceived-clutter win is **collapsing kind A**, and the single biggest *real* code-free
win is **expanding vocabulary for kind B**.

---

## 4. Design principles
1. **Never lie about compilation.** Rows that render must compile to exactly what the block did; no
   silent rewrites. Lift is byte-gated; any "convert" is explicit + previewed + undoable.
2. **Distinguish structure from logic.** A designer should instantly see "this is plumbing" vs "this is a
   rule I could edit."
3. **Always offer the exit.** Every block keeps Edit / Open-in-Godot — the expert path is never removed.
4. **Teach, don't hide.** Where a block stays code, say *why* and what would change it — that's the
   GDScript-learning surface.
5. **Earn the engineer's leverage.** The deepest code-free gains come from a tools engineer adding
   vocabulary; make that path real (ties to the custom-modules-for-teams vision).

---

## 5. Proposed solutions (prioritized)

### Phase 1 — Legibility & noise reduction (high value, low risk; rendering-only)

- **P1.1 Collapse structural scaffolding.** Auto-classify kind-A rows (prelude / host-binding /
  `## @ace_*` annotation blocks / blank separators — detectable cheaply by content + position) and render
  them folded into ONE thin, muted **"Behaviour scaffolding ▸"** strip at the top of the sheet, expandable
  on click. The weapon_kit sheet's top 5 blocks become one quiet strip. Pure view state (a fold flag),
  no model change.
- **P1.2 Type-aware block styling.** Give the three block kinds distinct, calm visuals: *scaffolding* =
  flat muted strip (no stripe); *logic* = the current code-cell + stripe; *comment* = comment style.
  Today every block looks the same, so plumbing and logic shout equally.
- **P1.3 Inline "why it's code" chip.** Surface `lift_note` as a small, always-visible chip on a kind-B
  block (e.g. `ƒ no ACE yet`) instead of hover-only — so the designer sees at a glance which blocks are
  "real logic with no row yet" vs structural. Clicking it opens P2.1.

### Phase 2 — Conversion & guidance (medium effort; reuses the lifter)

- **P2.1 "Try to convert to rows" (per block).** A block action that runs the existing reverse-lift on
  *that block's statements* and shows a **preview diff**: "3 of 4 lines become rows; 1 stays code
  (reason)." Apply is byte-gated + undoable. Turns the invisible lifter into a visible, on-demand tool.
- **P2.2 Code → ACE autocomplete.** While editing a block in the Edit dialog, match each line against the
  reverse templates live and offer "↪ this is the **Set Property** action — use it?" inline. Teaches the
  vocabulary exactly when the user is writing the equivalent code.
- **P2.3 Sheet "code-free coverage" meter.** A header indicator ("logic: 94% rows / 6% code") + a panel
  listing the remaining kind-B blocks with their `lift_note`, so a designer knows how close they are and a
  tools engineer sees precisely which patterns to add vocabulary for. (Excludes kind-A scaffolding from
  the denominator — see `pack_rawcode_budget_test`'s body-only counting for the precedent.)

### Phase 3 — Deeper engine work (high value, higher effort)

- **P3.1 Statement-level partial lift.** Today body-lift is all-or-nothing per body (`lift_function_bodies`
  skips a body the moment one line won't round-trip). Make the renderer/import lift the **matchable lines
  to rows** and keep only the **unmatchable** ones as a (smaller) trailing block — so a 6-line body that's
  5 ACEs + 1 oddity reads as 5 rows + 1 tiny block, not one wall. Must stay byte-gated per the contract.
- **P3.2 "Teach EventForge this pattern" (vocabulary authoring).** For a recurring kind-B block, an
  advanced flow that helps a tools engineer author a reverse template (an ACE `codegen_template` +
  placeholders) *from the selected code*, register it as a behaviour-pack ACE, and watch the block (and
  every future occurrence) lift. This is the lever that makes designers' sheets get more code-free over a
  project's life — the engineer extends the vocabulary, the designers' sheets re-lift.
- **P3.3 Inline-editable expression cells.** For single-expression blocks (e.g. one assignment), render an
  inline editable cell (like a parameter) instead of the full code-block treatment, so trivial code edits
  don't require the modal dialog.

---

## 6. Recommended sequencing & rationale
1. **P1.1 + P1.2 first.** Biggest *perceived* code-free jump for the least risk and zero model change —
   the sheet stops looking like "mostly code" the moment scaffolding collapses and logic blocks are
   visually distinct.
2. **P1.3 + P2.1.** Make the lifter visible and the remaining code legible/actionable.
3. **P2.3 + P2.2.** Give designers a target and teach the vocabulary in context.
4. **P3.x** as the engine matures; P3.2 is the long-term multiplier for teams.

## 7. Risks / guardrails
- **Byte-identity:** every "convert"/"partial lift" path stays byte-round-trip gated; never auto-apply a
  lift that changes the compiled output. Reuse the existing verify gate.
- **Collapse must be reversible + obvious:** a collapsed scaffolding strip must be one click from full
  code, and never hide a *logic* block (only kind-A). Misclassification hides real behaviour — classify
  conservatively (when unsure, render as a normal block).
- **No new persisted state in the `.gd`:** fold/coverage are editor view-state (or `note`-style
  editor-only fields), never emitted — the `.gd` stays the byte-exact source of truth.

---

## 8. Pointers (for whoever implements)
- Block render + merge: `event_sheet_viewport.gd` span build (`code_cell`/`block_lines` metadata) →
  `event_row_renderer.gd` `resolve_block_groups` / `_draw_block_cell`.
- Lift levers: `addons/eventforge/importer/ace_lifter.gd` (`_build_reverse_entries`, `_consume_action_line`,
  `lift_function_bodies`/`lift_event_bodies`).
- Triage hint: `RawCodeRow.lift_note` (set at the lifter's `_flush_raw`).
- Code-free counting precedent (exclude scaffolding): `tests/pack_rawcode_budget_test.gd`.
- Adding vocabulary: an ACE `codegen_template` is auto-indexed as a reverse template on next import.
