# SPEC - structured lift: raw GDScript to editable event-sheet blocks

Status: DESIGN (2026-07-15). Requested by the user: "I want it to be editable like regular code too, just
like all the other events" - clarified as "the code inside [a raw block] represented by custom blocks or
regular ACEs, or BOTH", editable in place. This is the project's north-star structured lift.

## Goal

When an opened `.gd` behaviour pack is loaded, blocks of raw GDScript that today survive as opaque
`RawCodeRow`s (a `class AbilityData:` data holder, the `_enter_tree` host binding, helper statements) should
render as FIRST-CLASS, EDITABLE event-sheet blocks - Custom Blocks and/or ACEs - that a non-programmer can
change like any other event, WITHOUT ever breaking the byte-exact round-trip.

## The covenant (non-negotiable)

Every lift is byte-gated verify-lift, exactly like the function and group lifts already shipped:
1. Recognize a pattern in a `RawCodeRow`'s code.
2. Build a STRUCTURED model from it.
3. Re-emit the model back to text and compare to the original block byte-for-byte.
4. Only if identical, replace the raw block with the structured (editable) block. Otherwise keep the
   `RawCodeRow` verbatim (degrade to a raw block, never corrupt).
On EDIT, re-emit from the structured model; the emission must be deterministic. `tools/audit_addons.gd`
(`audited=72 drifted=0`) is the whole-corpus proof; add a per-pattern round-trip test that is RED before the
lift and GREEN after.

## Foundations already in place (reuse, do not rebuild)

- **Verify-lift precedent**: the per-function shell-lift and `_reconstruct_groups` both byte-gate. Copy the
  pattern (build model -> re-emit -> compare -> fall back to verbatim).
- **Classifiers** (static, pure, unit-tested) in `viewport_row_builder.gd`: `host_binding_class(code)` and
  the validated `data_class_name(code)` (see Appendix - it was built and proven drift=0 this session, then
  reset pending this design). These already detect the two easiest patterns.
- **Read-only block views** already shipped as the FOLDED state the editable blocks sit on top of: the
  "Host binding" block (commit ff4570a) and the "Data class" collapse (Appendix). Expanding is the new work.
- **Custom Block API** (`EventSheetBlockKind` / `CustomBlockRow` / registry - see [[custom-block-api-status]])
  is the infra for the "custom block" half; `dock/ace_apply.gd` is the infra for the "ACE" half.
- **Fold/expand + editable children** machinery from Phase 2 (function bodies): `EventRowData.children` +
  `.folded`, and the live-vs-inert `source_resource` gate. Reuse it so a lifted block expands and edits like
  a function body.

## Phasing

**Phase 1 - pure-data inner class -> editable field rows (smallest real slice; byte-safe).**
- Pattern: a `RawCodeRow` that is exactly one `class X:` (optionally `extends Y`) whose body is only typed
  fields (`var`/`const`/`@export`) and comments, optionally led by a doc comment (`data_class_name` matches;
  spring's method-bearing classes and multi-class rows are correctly rejected).
- Model: `{ class_name, extends, doc_lines, fields: [{name, type, default, comment}] }`.
- View: the "Data class" block (badge + name chip) becomes EXPANDABLE; each field renders as a child row
  (name - type - default), edited inline like a variable row.
- Re-emit: reproduce `<doc>\nclass X[ extends Y]:\n\tvar name: Type = default` per field, in order. Canonical
  compiler-output classes re-emit exact -> lift fires; anything else stays verbatim. Byte-gate + a
  RED-before/GREEN-after test over the real `abilities` pack (AbilityData) + drift=0 on all 72.
- Edit wiring: field edits mutate the model through the undo funnel; re-fetch by class name after commit (the
  funnel snapshot-duplicates). Adding/removing/reordering fields = editing the class.

**Phase 2 - host binding -> editable host block.** Ties to #2 part 2's deferred pick-host dialog
([[host-binding-block-status]]). Opened-pack host stays read-only (baked into the .gd; the current block is
correct); the EDITABLE host lives on AUTHORED sheets, where the prelude is synthesized from `host_class` -
so this phase is really "make the authored-sheet host a first-class editable block", guarding the synthetic
row per the earlier reviewer finding.

**Phase 3 - statement-level lift to ACEs (the open-ended, hardest part).** Map individual GDScript
statements in a helper block to ACE conditions/actions where a `codegen_template` round-trips; leave the rest
verbatim. This is the tier-2 structured lift long deferred as re-editability-only - now user-requested. Design
the statement->ACE matcher as its own sub-spec before building; it is where byte-safety is hardest.

## Verification bar (every phase)

Suite green (add the per-pattern test) + `drift=0` (audited=72) + demo golden byte-stable + render/round-trip
verify + a fresh `plan-reviewer` pass focused on the byte-gate and the verbatim fallback + commit + push.

## Appendix - the validated Phase-1 classifier (built + proven drift=0 this session, then reset)

`ViewportRowBuilder.data_class_name(code) -> String`: skip leading blank/`#` lines; the next line must match
`^class ([A-Za-z_][A-Za-z0-9_]*)(?: extends [A-Za-z_][A-Za-z0-9_.]*)?:$`; every subsequent non-blank line
must be indented (`\t...`) AND begin with `var `/`const `/`@export`/`#`; a `func`, a nested/second class, or
any dedented top-level line returns `""`. Requires at least one field. Pins that passed: matches AbilityData
(doc + fields), rejects a class with a `func`, a second class, trailing top-level code, an empty class, and a
plain function; the real `abilities` pack collapsed to one line with drift=0; `spring` (method-bearing) did
NOT collapse. Rebuild it verbatim in Phase 1 as the recognizer, then layer the editable field model on top.
