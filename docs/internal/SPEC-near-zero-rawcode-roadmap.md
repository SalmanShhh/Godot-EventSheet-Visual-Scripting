# SPEC — Near-zero RawCode + open-any-`.gd`-as-events

**Status:** roadmap (investigated, adversarially reviewed, corrected). **Goal (user's words):** "almost no raw code blocks needed… so someone could just open any GDScript file as an event sheet and have it all fully rendered as event sheets — the Construct code-free experience with the power and versatility of GDScript."

**Invariant that makes this safe:** the `.gd` is the source of truth, and **every** lift is gated by a **whole-sheet byte-identical recompile** (`ace_lifter.gd:142-152`, `gdscript_importer.gd:127/146/166`). A rule that can't reproduce the source byte-for-byte simply doesn't fire — that statement stays a code cell. Fidelity is never traded for coverage; only coverage grows.

The goal is two pillars of very different difficulty. **Pillar 2 (reverse-lift) is the hard differentiator** — Construct 3 has no reverse direction at all, so any real win here is *beyond* C3 (this is positioning, not a code fact).

---

## Pillar 1 — Authoring completeness (forward)

### Already complete — do NOT rebuild (verified in-tree)
- **Loops** — `PickFilter` covers For-Each (`GROUP/CHILDREN/ARRAY/EXPRESSION/NODE_TREE`), **Repeat** (`REPEAT`→`for i in range(n)`), **While** (`WHILE`→`while expr`) + order-by, pick-first-N, budgeted frame-spread (`pick_filter.gd`, emitted `sheet_compiler.gd:1085-1145`).
- **Collections** — near-complete Array/Dictionary API (`collection_aces.gd`).
- **Functions** — params, return type, three-way expose (action/condition/expression), reversibly annotated.
- **Physics / movement, signals-as-triggers, Set/Get Property, Call Method, Run/Evaluate GDScript, typed local, Else/Else-If, sub-events, MatchRow, CompareVar/SetVar/AddVar.**

### Residual gaps (each a concrete addable item)
| Pri | Item | Add as | Why it forces a block today |
|---|---|---|---|
| **High** | `@onready var x = $Path` | `@onready` flag on `LocalVariable` (or `onready_var_row.gd`) + an emission form mirroring `_emit_tree_variable_line` (`sheet_compiler.gd:1544`) | Most common decl after `@export`; no parser prefix (`gdscript_importer.gd:114`), no emission form → always RawCode. Also unblocks Pillar 2. |
| **High** | Compound assigns `-= *= /=` | `SubtractVar`/`MultiplyVar`/`DivideVar` templates (sibling to `AddVar`, `core_aces.gd:71`) | Only `+=` lifts. Cheap, high-frequency. |
| **High** | `is` / `as` / `typeof` | `IsType` condition `{target} is {type}`, `TypeOf` expression | No type-check ACE — a ubiquitous guard. |
| Med | Math `sqrt/pow/floor/ceil/fmod/ease/clampf` | Expression ACEs (siblings to `abs/min/max`, `helper_aces.gd:69`) | Common one-liners, no curated expression. |
| Med | `preload/load` into a var | `PreloadResource` action/expression | Daily idiom, no ACE. |
| Med | Hinted exports `@export_range/@export_file/@export_flags` | Extend `variable_parser.gd:18-26` + a hinted-export decl form | Not parsed → RawCode; needed before reverse-lift handles real inspector-tuned scripts. |
| Low | Tween sequence/parallel | `TweenChainRow` construct | Tween is single-shot; chains force a block. |
| Low | Structured `match` arms | `MatchRow` arms holding ACE rows (`match_row.gd:18`) | Branch bodies are verbatim today. |

**Do the three High rows first** — highest-frequency raw-block triggers, ~½-day each, and they feed Pillar 2.

---

## Pillar 2 — Reverse-lift fidelity (open any `.gd` → events) — the hard pillar

### The crux: today's lifter is block-granular and EventForge-shaped
- Tier 1 (`gdscript_importer.gd`) makes **one `RawCodeRow` per top-level `func`** (`:48-66`); only var/enum/signal lift to rows.
- Tier 2 (`ace_lifter.gd`) only fires on **EventForge's own emission layout** — a *trailing run* of lifecycle/connected-signal/annotated functions (`:38-49`) — and reverts the **entire** lift on any byte mismatch (`:146`).
- Inside a lifted body, `_parse_body` handles **only `if/elif/else`** (`:369-403`); unmatched lines survive as lenient in-flow RawCode (`:391-397`).

So a genuinely hand-written `.gd` lifts almost nothing. **Target: per-statement lift** — every top-level `func` is a candidate regardless of position; each statement matches independently; only irreducible statements become small code cells. **Keep the single whole-sheet byte gate** — it already tolerates per-statement RawCode fallback, so do NOT introduce a fragile per-statement gate (review §medium-4).

### Lift rules, in dependency order (corrected against the review)

**Stage A — Decouple from EventForge's layout** *(foundational; the single biggest fidelity jump: "EventForge files only" → "any file")*
1. **Any top-level `func`, any position** → candidate (loosen Tier-1 + Tier-2's trailing-run scan `ace_lifter.gd:38-49`).
2. **⚠ Relax the annotation requirement.** `_lift_sheet_function` hard-bails when there's no `## @ace_*` block (`ace_lifter.gd:226-227`) — hand-written code has none, so **helper methods would still never lift** (review §high-2). Fix: accept an empty annotation set → an *un-exposed* sheet function (`expose_as_ace=false`). Without this, Stage A only unlocks lifecycle + `_ready`-connected handlers.
3. **⚠ Handle intra-body blank lines.** `_parse_body` bails on any blank line (`ace_lifter.gd:363-364`); real functions have blanks between statements (review §missing). The per-statement parser must skip blanks (and preserve them for byte-exact re-emit).
4. Per-function fallback granularity: one unmatched nested construct must degrade only *that span* to a code cell, not revert the whole function (already supported by the in-flow-RawCode path `:391-397`).

**Stage B — Statement templates (route through existing ACEs)**
5. **`a = b`** → **SetVar** (`{var_name} = {value}`, already reversible; specificity sort keeps node ACEs winning).
6. **`a.b = c`** → **SetProperty**, **`a.b(args)`** → **CallMethod** — *blocked today* because Helpers are excluded from the reverse index (`ace_lifter.gd:503-508`). Fix: admit a **reverse-eligible whitelist** (SetProperty, CallMethod, GetProperty, **and SetLocalVar/SetLocalVarTyped** — review §low-7) at **lowest** specificity (sort tail `:535`) so they catch only what nothing specific claims. *Prefer a `reverse_eligible` flag on `ACEDescriptor`* over a hardcoded list, so packs declare their own reverse-safe generics (open question).
7. **Compound `-= *= /=`** → the new SubtractVar/etc.
8. **`return v` / `return`** → **already reverse-match** (Core ACEs `core_aces.gd:74-75`, not excluded) — they just only fire inside Stage-A-liftable bodies. *Verify + add coverage, not new work* (review §low-6).
9. **`var x: T = V`** → body-scoped `LocalVariable` row (`sheet_compiler.gd:876-887`) or whitelisted SetLocalVarTyped.

**Stage C — Control flow → constructs** *(the bulk of hand-written bodies)*
10. **`for X in COLL:`** → **For-Each PickFilter**, **pinned to `CollectionKind.EXPRESSION`** with empty predicate/filter/order_by/pick_first_n — only that shape re-emits `for {iterator} in {collection}:` verbatim (`sheet_compiler.gd:1130`). GROUP/CHILDREN/REPEAT *transform* the value (`get_nodes_in_group(...)`, `range(...)`) so they are **not reverse-inferred** (the editor may reclassify post-import) — review §medium-3. `range(n)` lifts as EXPRESSION with collection `range(n)`. Guard against the budgeted `__loop_`/`__pick_` sentinel shapes.
11. **`while COND:`** → **While PickFilter** (collection = `COND`); plain shape only, not the budgeted `while __loop_cursor…` (`:1100`).
12. **`if/elif/else`** → conditioned rows + Else — **already works**; richer bodies just feed it.
13. **`match SUBJ:`** → **MatchRow**, stripping exactly one `body_indent + \t` from each branch line to reconstruct `branches_text` (not "byte-exact by construction" — needs precise depth bookkeeping, review §medium-4). Guard/binding arms stay verbatim inside `branches_text` (fine).
14. **`break`/`continue`** → loop-control rows **only inside a lifted plain For-Each/While** (never top-level; never the budgeted variants that emit their own sentinels) — currently excluded (`ace_lifter.gd:509-512`).

**Stage D — The condition fallback (corrected — this was the review's #1 finding)**
15. **A boolean term in an `if` matching no condition template** must NOT sink the whole `if` to RawCode. **But `EvaluateGDScript` is wrong for this**: its template is `({code})` (`helper_aces.gd:43`), and the `if`-emitter joins terms with bare ` and ` / ` or ` *without* per-term parens (`sheet_compiler.gd:911-912,959`). So `if exotic and is_on_floor():` would re-emit as `if (exotic) and is_on_floor():` → byte-different → revert (review §high-1). **Fix:** register a **reverse-only "bare expression condition"** whose template is `{code}` (no parens) at lowest specificity, so an unparenthesized term re-emits exactly. *Then* an `if` with one exotic term lifts as a real conditioned row (the exotic term shown as a calm "expression is true" cell) instead of a verbatim block. Round-trip test must use an **unparenthesized** term.

### What this buys
A hand-written CharacterBody2D mover (`extends` + a couple `@export`/`@onready` + `_physics_process` + 1–2 helpers) moves from **"a few verbatim blocks, <30% structured"** to **the majority of lines as structured rows** — declarations, the physics trigger event, input conditions, velocity/move-and-slide as Set Property/Call Method rows, `if`-ladders as conditioned rows, `for`/`match` as loop/match rows, helpers as (un-exposed) sheet functions — with only genuinely-irreducible lines as small marked code cells. Every step still gated byte-identical.

---

## Pillar 3 — The honest irreducible limit
Stays a code cell **by nature** (and that's correct): typed **inner classes** with methods, **lambdas/`Callable`s as data**, **multi-term per-frame numeric kernels**, **exotic `match`** (guard/binding arms), **string metaprogramming**, guarded **fluent/`await` chains**. Construct 3 has the *same* ceiling — these are exactly what forces a C3 user to the Script object/a plugin. EventForge's escape hatch is an **in-sheet GDScript cell that round-trips losslessly and reads calmly** (now muted), plus `lift_report.gd` naming the closest ACE.

**Realistic target, stated precisely:** **near-zero *gratuitous* RawCode** — any `.gd` opens with its discrete control flow, assignments, calls, and declarations as rows, and only the irreducible kernels as clearly-marked code cells. **Not literally 100%, and it doesn't need to be.** Even this bar exceeds Construct 3.

---

## Phased plan (most fidelity per unit effort first)
0. **Phase 0 — ✅ SHIPPED** (`deab37d`): `@onready` row, `SubtractVar/MultiplyVar/DivideVar`, `TypeOf` (IsType dropped — `is` operator auto-fill conflict), compound-assign reverse-lift.
1. **Phase 1 (the unlock) — ✅ SHIPPED:** Stage A — **relaxed the annotation requirement**: a hand-written `func foo() -> Type:` with no `## @ace_*` block lifts to an un-exposed sheet function. New `EventFunction.lifted_unannotated` flag suppresses the `## @ace_hidden` emission the source never had (guardrail 8), so the untouched round-trip stays byte-identical; generated `@ace_hidden` functions keep their marker. **Guardrail 10 decided: accept the events-then-functions layout.** Lifting helper functions to `sheet.functions` means a later-added event lands in the events section before them — a clean single-insert diff, standard sheet structure — rather than the old append-as-blocks prefix. The golden untouched round-trip (the core contract) is preserved; `external_sheet_test` + `function_lift_test` reframed accordingly; a 7-case adversarial probe confirmed no-return-type / blank-body functions safely stay blocks and Phase 1 composes with Phase 2-3 (helper bodies lift their statements/loops/branches). **Still deferred (lower value):** blank-line-in-body handling (those stay blocks) and full trailing-run decoupling (a function *interspersed* with non-function content stays a block).
2. **Phase 2 (statements) — ✅ SHIPPED** (`3803863`): Stage B — `SetProperty`/`CallMethod` admitted to the reverse index at lowest specificity (the literal_len sort keeps specific ACEs ahead), so `a.b = c`→Set Property and `a.b()`→Call Method when nothing specific claims them. `statement_lift_test`. (GetProperty is an expression — not statement-reverse-matched; SetLocalVar* deferred to Stage D.)
3. **Phase 3 (control flow) — ✅ SHIPPED** (`c5c1ff6` for/while/repeat, `72a42d7` match, `472c795` nested fix): Stage C — `for X in EXPR:`→For-Each (EXPRESSION; REPEAT only for a *pure* `range(...)`), `while`→While, `match`→MatchRow. Body folds via `_adopt_block_body` into `sub_events`, so loops nest if/elif/else **and each other** (fixed `_is_plain_collector`: a pick_filter-bearing row is not a plain collector). `loop_lift_test` + `match_lift_test`; adversarially reviewed (20-case round-trip probe + 4-agent code review). Deferred within Stage C: contextual `break`/`continue` (kept out of the reverse index — they appear in generated pick-loop bodies), order-by/predicate/pick-first-N pick reconstruction (re-opening one's own such pick stays raw — round-trips, lower fidelity), and budgeted-loop scaffolding (stays raw).
4. **Phase 3.5 — ✅ SHIPPED** (condition fallback): Stage D — the bare-expression condition fallback was found to **already work** (`ExpressionIsTrue`, template `{expr}`, category `General Conditions`, is in the reverse index as the lowest-specificity condition, so any unmatched `if` term lifts; negation + mixed matched/expression terms confirmed). The **correction** shipped: `_parse_conditions` now splits on **top-level** `" and "` only (`_split_top_level_and`, paren/bracket/brace/string-aware), so a compound term like `f(a and b)` / `not (a and b)` / `x == "a and b"` stays ONE clean condition instead of fragmenting into garbage Expression-Is-True rows. `condition_fallback_test` + an 8-case split probe. Still deferred: `SetLocalVar*` typed-local statement reversal (admit to the reverse index like Phase 2's SetProperty/CallMethod).
5. **Phase 4 (polish) — ✅ SHIPPED (substantive items):** the **fidelity ratchet** test (`fidelity_ratchet_test` — a representative hand-written script lifts COMPLETELY: every var/statement/loop/condition/function becomes a row, only the `extends` prelude stays verbatim); **math expression vocabulary** (Square Root, Power, Floor, Ceil, Float Modulo, Ease, Snapped, Load Resource); **`SetLocalVar*` reverse-lift** (`var x = …` → a row); **hinted exports** (`@export_range`/`@export_file`/`@export_flags`/any `@export_*` → a variable row with the annotation kept verbatim via `export_hint`). The **calm-cell** styling shipped earlier (muted `CODE_CELL_BG`/`CODE_CELL_STRIPE` + muted raw-code badge), and the **lift-report** hook exists (`RawCodeRow.lift_note`). **Intentionally deferred (lowest-value, forward-authoring only):** the **Tween-chain** construct and **structured `match` arms** (arm bodies as ACE rows). These do NOT affect the reverse-lift goal — a tween chain stays a safe round-tripping code cell (the rare exception per the ratchet) and a `match` already lifts to a row with verbatim arm text; both are authoring conveniences, not "open any .gd" gaps. `preload` likewise stays a RawCode const (parse-time-only; can't placeholder-compile).

---

## Implementation guardrails (each was a review finding — do not re-trip)
1. **Condition fallback needs a no-paren `{code}` template**, not `EvaluateGDScript`'s `({code})` — else unparenthesized terms revert (§high-1).
2. **`_lift_sheet_function` must accept empty annotations** or helper methods never lift (§high-2).
3. **`_parse_body` must skip intra-body blank lines** (§missing) and the new for/while/match branches must keep `next` advancing past the entire nested block (`ace_lifter.gd:335,339-340`) or the whole function reverts.
4. **`for`/`while` reverse only the plain EXPRESSION/COND shape** with empty predicate/filter/order_by/pick_first_n; GROUP/CHILDREN/REPEAT/budgeted are NOT reverse-inferred (§medium-3).
5. **Keep the single whole-sheet byte gate** (it already tolerates per-statement RawCode); do not build a per-statement gate (§medium-4).
6. **`return` already reverses** — verify, don't re-add (§low-6). **SetLocalVarTyped is a Helper** — whitelist it or use the LocalVariable path (§low-7).
7. **The "C3 has no reverse import" claim is positioning**, not verifiable from this repo — frame it as such.
8. **(Confirmed while starting Phase 1) Un-annotated function lift re-emits `## @ace_hidden`.** An
   un-exposed `EventFunction` emits `## @ace_hidden` (`sheet_compiler.gd:1234`); lifting a hand-written
   function that had NO annotation re-adds it → byte-different → the whole-sheet gate reverts. Relaxing
   `_lift_sheet_function`'s annotation bail (`ace_lifter.gd:226`, §high-2) is **necessary but not
   sufficient** — `EventFunction` needs a `lifted_unannotated`/`suppress_annotations` flag the lifter
   sets, so a function lifted from un-annotated source re-emits with NO annotation block. The bail's own
   doc comment (`ace_lifter.gd:224`) states the buried assumption: "every generated sheet function has
   one." Phase 1 must break that assumption on BOTH the import and the emit side together.
9. **(Confirmed while starting Phase 1) Blank lines inside a function body must round-trip.**
   `_parse_body` bails on blank lines today (`ace_lifter.gd:363-364`); making it *skip* them loses them
   on re-emit (byte-different → revert). The lift must PRESERVE intra-body blanks — a blank-marker row,
   or fold them into a surrounding in-flow RawCode span — so the recompile reproduces them exactly.

10. **(THE core blocker — confirmed by a built-then-reverted attempt) Lifting functions breaks the
    append-stability contract.** Lifting an un-annotated function moves it from `sheet.events` (a block
    row, in source position) to `sheet.functions` (the functions section, emitted AFTER all events). The
    untouched round-trip stays byte-identical, BUT it violates the GDScript-backed-sheet workflow's
    documented contract (`external_sheet_test.gd:6`: *"Events added later append as standard trigger
    functions"*): a newly-added event emits in the events section, **before** the now-lifted functions,
    so the original file is no longer a byte-prefix of the saved result — a mid-file insert, not a clean
    append. A full attempt confirmed this: the `lifted_unannotated` flag + suppress-emit + relaxed bail
    all worked and round-tripped, but `external_sheet_test`'s append-prefix + `function_blocks==2`
    assertions failed, so it was reverted. **This is the real Phase-1 decision, not a test wart:** either
    (a) emit lifted functions in their SOURCE POSITION (interleave functions with events — a significant
    change to the compiler's section ordering in `_compile_external`) to preserve append-stability, or
    (b) accept the events-then-functions reordering and rewrite the contract + `external_sheet_test`.

**Phase 1 sequencing note:** items 8, 9, and especially **10** mean Stage A is entangled — the
decouple-from-layout, the annotation relaxation, the emit-side suppress flag, blank-line preservation,
**and the function-emission-ordering decision** must be resolved together for the round-trip *and* the
append-stability to hold. It is a focused architectural effort, not a one-line change. Recommended
first sub-decision: resolve item 10 (source-position function emission vs accepted reordering) before
writing any lifter code, since it dictates the rest.

## Files to touch
- `ace_lifter.gd` — Stage A (drop trailing-run binding `:38-49`; relax annotation bail `:226-227`; skip blanks `:363-364`); Stage B (reverse-eligible whitelist into `_build_reverse_entries` `:503-508` at sort tail `:535`); Stage C (for/while/match branches in `_parse_body` `:361-413`, sentinel guards); rule 14 (no-paren condition in `_parse_conditions` `:450-466`); contextual break/continue `:509-512`.
- `gdscript_importer.gd` — `@onready` lift `:113-129`; functions as candidates regardless of position.
- `variable_parser.gd` — hinted exports + `@onready` `:18-26`.
- `core_aces.gd` — SubtractVar/MultiplyVar/DivideVar; IsType/TypeOf.
- `helper_aces.gd` — math expressions, PreloadResource; mark SetProperty/CallMethod/GetProperty/SetLocalVar* reverse-eligible; add the reverse-only bare-expression condition.
- `resources/local_variable.gd` (or new `onready_var_row.gd`) + `sheet_compiler.gd` `@onready` emission form (mirror `:1544`).
- `match_row.gd` (Phase 4 structured arms), `lift_report.gd` (report lifted vs irreducible as rules land), optional `ACEDescriptor.reverse_eligible` flag.

## Tests to add (the universal gate per rule)
For EACH rule: author a sheet using the construct → compile → `import_external_source` → recompile → **assert byte-identical** (mirror `ace_lift_test.gd:61-64`, `external_sheet_test.gd:44-45`). Specific cases: Stage-A function-above-members lift; `a.modulate = Color.RED`→SetProperty (pin specificity); `$Sprite.play("run")`→CallMethod; compound assigns; for-in→EXPRESSION PickFilter + **negative** (budgeted/order-by must NOT reverse to plain); while→While + budgeted negative; match→MatchRow (+ guard-arm framing); typed local + return; break inside a lifted loop (+ top-level not mis-claimed); **rule-14 with an UNPARENTHESIZED exotic term** (assert it lifts, not reverts); `@onready` lift; un-annotated helper method → un-exposed sheet function. Plus a **whole-file fidelity ratchet** on a mover fixture (structured-row / meaningful-line ratio over a defined denominator — count statements, exclude blanks/comments).

## Open questions
- `reverse_eligible` flag on `ACEDescriptor` vs a hardcoded whitelist in the lifter?
- `for-in` collection: always `CollectionKind.EXPRESSION` (always byte-safe) + optional editor reclassification, vs inferring GROUP/CHILDREN/REPEAT (richer UI, risks non-byte-matching on next save)?
- Signal handlers connected outside `_ready` (`_parse_connections` only scans `_ready`, `ace_lifter.gd:282`) — how far to chase before declaring a plain sheet function?
- Could decoupling from the trailing-run layout produce a *structurally misleading* sheet (a helper shown as an OnProcess event) even though it byte-matches? Add a confidence note to the lift report.
- Fidelity-ratchet denominator: what counts as a "meaningful line"?
