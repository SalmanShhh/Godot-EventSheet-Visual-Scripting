# SPEC — Behaviour GDScript-blocks audit: which bundled packs still emit RawCode, why, and how to close it

**Status:** audit complete (verified against the working tree + a headless-probe pass), roadmap proposed. **Companion:** [`SPEC-behaviour-as-aces-parity.md`](SPEC-behaviour-as-aces-parity.md) owns the *vocabulary + function-system design* that closes the codegen half of this gap. This spec owns the **concrete census** (what is actually there, per pack, per reason) and the **prioritized roadmap** that maps every category to either a parity-spec workstream, brand-new work this audit surfaced, or an honest keep-as-GDScript carve-out. Where a fix is designed in detail elsewhere, this spec **references the section** rather than re-deriving it.

> Line numbers below are as-of the audit; treat them as "look here," not literal offsets. Every load-bearing claim was re-verified against the working tree — by code read and by headless Godot probes run with the `Godot_v4.7` console exe (`--headless --script`). The census reproduces on demand via `tools/audit_pack_blocks.gd` (`godot --headless --path . --script tools/audit_pack_blocks.gd`), which writes a per-block JSON dump to `user://pack_blocks_audit.json` (regenerable, not committed). The `_classify` reason tags there are a pure-text heuristic — impure by design (§4-H) — so treat the per-category counts as an audit lens, not gospel; §3 states the verified content of each bucket.

---

## 0. Method — the two-lens audit

**What counts as a "block."** A block is one `RawCodeRow` surviving in a bundled pack sheet (`res://eventsheet_addons/*_behavior.gd` / `*_addon.gd`) after the sheet is opened in the editor — i.e. a chunk of literal GDScript the compiler round-trips verbatim instead of representing as ACE rows. Blank lines count (the importer preserves them as `RawCodeRow`s for byte-exact round-trip), which is why the raw total is larger than "lines of real logic."

**The two lenses.** Each pack was measured two ways:

- **Lens A — the user-open path.** `GDScriptImporter.import_external_source` (`gdscript_importer.gd:184`) → `EventSheetACELifter.attempt_lift` only. This is exactly what a user sees when they open a bundled behaviour.
- **Lens B — the full pack-build lift chain forced on open.** `attempt_lift` **plus** `lift_function_declarations` + `lift_function_bodies` + `lift_event_bodies` + `lift_signal_declarations` (the chain that pack-build normally runs) force-run against the same opened sheet.

**The crucial finding: Lens A == Lens B == 783, and drift = 0.** Across all **32** bundled packs, running the entire pack-build lift chain on open erases **zero** additional blocks (`full_chain_exact = true` for every pack in `tools/_tmp_block_audit.json`; `lens_a_raw` sum = `lens_b_raw` sum = 783). This falsifies the intuitive hypothesis that "the open path is weaker than the build path." It is not. The 783 residue is **not** a lift-strength deficit between open and build; it is (a) blocks the codegen vocabulary cannot yet *produce* as ACE rows, plus (b) non-logic scaffolding the lifter has no reason to turn into rows. The parity spec's round-trip covenant (its §9) is satisfied: a user opening a behaviour sees exactly what pack-build leaves — no more, no less.

**Consequence for this spec.** Because the two lenses agree, the roadmap does **not** chase an open-vs-build convergence bug. It targets the two real levers: *make the vocabulary able to express more* (parity spec) and *stop rendering non-logic scaffolding as GDScript blocks* (new work here). One exception exists where the open path leaves lift on the table for exposed funcs *outside* the trailing run — the shell-lift case in §3.2 — and it is called out explicitly. (The shell-lift *mechanism* already exists and runs on open; it simply isn't applied to the whole file — see §3.2 / §4-C.)

---

## 1. The census

### 1.1 Per-pack block counts (all 32 packs, 783 blocks)

| Pack | Blocks | | Pack | Blocks |
|---|---:|---|---|---:|
| `virtual_cursor_behavior.gd` | 121 | | `bullet_3d_behavior.gd` | 6 |
| `abilities_behavior.gd` | 108 | | `car_behavior.gd` | 6 |
| `health_behavior.gd` | 80 | | `sine_behavior.gd` | 6 |
| `spring_behavior.gd` | 55 | | `background_runner_behavior.gd` | 5 |
| `htn_agent_behavior.gd` | 54 | | `bullet_behavior.gd` | 5 |
| `juice_behavior.gd` | 53 | | `flash_behavior.gd` | 5 |
| `advanced_random_addon.gd` | 49 | | `move_to_behavior.gd` | 5 |
| `save_system_addon.gd` | 37 | | `move_to_3d_behavior.gd` | 5 |
| `time_slicer_behavior.gd` | 28 | | `sine_3d_behavior.gd` | 5 |
| `tween_behavior.gd` | 27 | | `state_machine_behavior.gd` | 5 |
| `drag_drop_behavior.gd` | 19 | | `timer_behavior.gd` | 5 |
| `tile_movement_behavior.gd` | 16 | | `eight_direction_movement_behavior.gd` | 4 |
| `line_of_sight_behavior.gd` | 13 | | `orbit_3d_behavior.gd` | 4 |
| `line_of_sight_3d_behavior.gd` | 13 | | | |
| `follow_behavior.gd` | 12 | | | |
| `weapon_kit_behavior.gd` | 10 | | | |
| `platformer_movement_behavior.gd` | 8 | | | |
| `demo_health_addon.gd` | 7 | | | |
| `orbit_behavior.gd` | 7 | | | |

The distribution is heavily top-loaded: the six largest packs (`virtual_cursor`, `abilities`, `health`, `spring`, `htn_agent`, `juice`) account for **471 of 783** blocks (60%). Any roadmap that moves the needle must move these.

### 1.2 Reason breakdown (9 categories)

Each block is tagged by a pure-text heuristic in `tools/_tmp_block_audit.gd:_classify` (`:86-106`), checked in priority order (blank > scaffold > host > getter > action > match > helper-func > numeric > other).

| Reason category | Blocks | Nature |
|---|---:|---|
| `helper_func_body` | 291 | Private/helper func bodies left as loose RawCode |
| `exposed_action_rawcode` | 142 | Hand-authored `## @ace_action` + func blocks |
| `blank_separator` | 114 | Empty lines (`code == ""`) |
| `exposed_getter_rawcode` | 107 | Hand-authored `## @ace_condition` / `## @ace_expression` + func blocks |
| `other_statements` | 54 | Fall-through: walrus locals, `@ace_tags` fragments, comments, inner classes |
| `host_binding` | 29 | Compiler-emitted `_enter_tree()` host-guard boilerplate |
| `class_scaffold` | 21 | `@icon` / `class_name` / `extends` preludes |
| `numeric_or_expr_kernel` | 20 | Per-frame math + mis-tagged prose comments |
| `match_control_flow` | 5 | Whole helper funcs whose body is a `match` |
| **Total** | **783** | |

> Caveat carried forward from the audit: the classifier is a text heuristic, so several tags are impure. `match_control_flow` (5) are really whole helper funcs that the `match` check catches before the helper-func check; ~12 of the 20 `numeric_or_expr_kernel` are prose comments whose text contains `if`/`or`; ~37 of the 54 `other_statements` are non-logic fragments. §3 states the verified content of each.

---

## 2. The honest denominator

Not all 783 blocks are logic that *should* become ACEs. Separate them cleanly before setting a target:

| Bucket | Categories | Blocks |
|---|---|---:|
| **Cosmetic / structural** (compiler-emitted or non-logic) | `blank_separator` 114 + `class_scaffold` 21 + `host_binding` 29 | **164** |
| **Genuine logic residue** (everything else) | `helper_func_body` 291 + `exposed_action_rawcode` 142 + `exposed_getter_rawcode` 107 + `other_statements` 54 + `numeric_or_expr_kernel` 20 + `match_control_flow` 5 | **619** |

**The 164 are never ACEs and must not be counted as failures.** Every `blank_separator` is literally `code == ""` with `line_count == 1` (verified: the only distinct blank code in the JSON is the empty string). `class_scaffold` is the `@icon`/`class_name`/`extends` prelude the compiler emits and already correctly folds into the "Class setup" strip. `host_binding` is a 4-line `_enter_tree()` guard block the compiler *generates* (`sheet_compiler.gd:171-174`), not authored game logic. These need a **rendering answer** (§4-B), not a vocabulary answer, and they must be **excluded from the ratchet count** so the budget measures logic only.

**The real target is the ~619 logic blocks.** Of those, the gratuitous-vs-honest split is:

- **Gratuitous (should become rows) — the large majority.** All 249 exposed blocks (142 action + 107 getter) are hand-authored annotation+template+func shells that are *meant* to be exposed EventFunctions (parity spec §1). The bulk of the 291 `helper_func_body` bodies lift byte-identically in isolation today (§3.1) and stay RawCode only because of a whole-sheet gate, not a grammar gap. The ~17 walrus-local blocks inside `other_statements` are a small, well-scoped grammar gap (§3.4).
- **Honest GDScript (should stay) — a small, named minority.** ~8 genuine per-frame numeric kernels (`spring`/`juice` integrators — parity spec §5.4), the nested typed `class` blocks (`AbilityData`, `HTNMethod`, `ColorSpringEntry`, `SpringEntry` — no ACE grammar, and none is desired), and the densest interleaved-local math. Call it roughly **~150 of the 619 bodies live in the four nested-class packs** (`spring`/`abilities`/`htn`/`health`) where a hard-unliftable `class` block structurally guarantees byte-divergence.

Net target: **drive the ~619 down to the honest floor** (the sanctioned numeric kernels + nested-class state), and get the 164 structural rows *out of the count entirely* via rendering.

---

## 3. Reason catalog

One subsection per category: what it is, the verified root cause with file:line citations, examples, and parity-spec coverage.

### 3.1 `helper_func_body` — 291 (LARGEST bucket)

**What it is.** Private and helper func bodies (`_process` tick loops, `_ensure_ability`, state transitions) left as loose top-level `RawCodeRow`s. Every one is `pack_where = "events"` in the JSON — none actually lives inside a lifted `EventFunction`; they are tagged `helper_func_body` only because `_classify` (`_tmp_block_audit.gd:102`) keys on a first line beginning `func `.

**Verified root cause — a whole-sheet, all-or-nothing byte-gate, NOT a per-body grammar gap.** The bodies themselves *do* reverse-lift: `_parse_body` + the `SetProperty`/`CallMethod`/`SetLocalVar(Typed)` catch-alls (`ace_lifter.gd:1101`), `ReturnValue`/`ReturnEarly` (`core_aces.gd:118-120`), `EmitSignal` (`core_aces.gd:124`), and the `for`/`while` pick-filter grammar (`ace_lifter.gd:858-882`) all match these shapes. Isolated probes of `spring._spring_entry`, `abilities.reset_cooldown`, `abilities.clear_all`, `htn.set_world_state`, `vc.press_interact` all parsed OK with **0 raw blocks and byte-identical recompile**. The real gate is `lift_function_declarations`' whole-sheet compare (`ace_lifter.gd:506-511`): after splitting every func into an `EventFunction` it recompiles the **entire** sheet; if `after != before` it reverts `sheet.events` **and** `sheet.functions` wholesale (returns 0), so `lift_function_bodies` (`ace_lifter.gd:270`, which only walks `sheet.functions`) never sees them. Why the whole-sheet recompile diverges: the compiler's canonical `behavior_mode` emit order (`sheet_compiler.gd:167-219`) is host `_enter_tree()` prelude → enums → signals → vars → functions, but hand-authored packs interleave differently (e.g. `spring_behavior.gd:9` places `func _enter_tree()` *before* the signal block), and the divergence is **not pure reordering** — re-emitted annotation blocks + canonical blank-line separators push the generated line count *higher* (`virtual_cursor` 846 vs 796, `juice` 358 vs 348). (This is the Lens-B full-chain sequence; the pure open path never runs `lift_function_declarations`/`lift_function_bodies` at all — see §3.2.) Additionally, nested `class` blocks in `spring`/`abilities`/`htn`/`health` have no ACE grammar at all — a hard-unliftable that alone guarantees byte-divergence, and **~136 of the 291 bodies live in these 4 packs**.

**Examples.**
- `abilities_behavior.gd` `_process` — a 25-line per-frame ability loop (`_tmp_block_audit.json`, `abilities` block); lifts in isolation but is reverted because a sibling nested `class AbilityData` (`:49`) can't.
- `virtual_cursor_behavior.gd` — 58 of 59 funcs are splittable and their bodies lift, yet decl-lift byte-gates to 0 purely from the `_enter_tree`/signal-prelude ordering + regenerated-annotation line delta. The single biggest contributor (part of its 121-block total).
- `juice_behavior.gd` — flat pack (no nested class); press-style setters + `shake()` lift cleanly, blocked only by the same ordering/spacing divergence.

**Parity coverage: partly.** §5.4 blesses the honest numeric kernels and §5.2 shows the manual re-author path, but no workstream converts private helper/tick bodies, and the §5.3 ratchet is a containment mechanism, not a solution. The structural fix (per-function gating, §4-D) is **new work**.

### 3.2 `exposed_action_rawcode` — 142  &  `exposed_getter_rawcode` — 107 (249 exposed blocks)

**What it is.** Hand-authored exposed-ACE shells: a `## @ace_action` (or `## @ace_condition`/`## @ace_expression`) annotation block, a `## @ace_codegen_template(...)` line, and a `func`. These are the behaviour's *published vocabulary* written as literal RawCode instead of as exposed `EventFunction`s.

**Examples.** `health_behavior.gd`: 16 `## @ace_action` funcs (`take_damage :97`, `heal`, `set_health_value`, `add_health_pool`), 5 `## @ace_condition` getters (`is_dead :327`, `is_invulnerable`), 12 `## @ace_expression` getters (`current_health_value :370`, `max_health_value`, `health_percent`). `abilities_behavior.gd`: `create_ability`, `has_ability`, `is_ready`.

**The shell-lift mechanism already exists — the gap is reach, not capability.** `_lift_sheet_function` (`ace_lifter.gd:651-698`) already rebuilds an exposed `EventFunction` shell (name + typed params + `expose_as_ace` from the annotation block), and `_split_function_declarations` already pulls a preceding `#`/`##` block off its *own row's* remainder to feed it (`ace_lifter.gd:533-548`). It runs on open via `attempt_lift`'s trailing-run loop — a probe confirms `platformer_movement_behavior.gd` opens with **12 exposed `EventFunction`s, byte-identical**. So exposed funcs *in the trailing run* already lift. The 249 that don't are blocked by two reach limits, not a missing mechanism: (1) **scope** — funcs interleaved with inner classes / lifecycle handlers (health, abilities) fall outside the trailing run, and the open path never calls `lift_function_declarations` to reach them; (2) **cross-row separation** — when the chain *is* forced, `import_external_source` emits each func as its own `RawCodeRow` with the `## @ace_action` block flushed as a **separate prior row** (`gdscript_importer.gd:79-97`), so `_split_function_declarations`' *intra-row* look-back finds an empty lead, `annotations = {}`, and `_lift_sheet_function` marks it `lifted_unannotated = true` / `expose_as_ace = false` (`ace_lifter.gd:657,664,686`) → byte-verify reorders and reverts.

**Verified by headless probe** on `health_behavior.gd`: open path leaves `EventFunctions = 0` (its exposed funcs are all outside the trailing run) and 33 top-level `## @ace_` RawCodeRows; forcing `lift_function_declarations` (ungated) harvests 37 funcs but **every** one has `expose_as_ace = false` / `lifted_unannotated = true` (the cross-row-separation defect), the `## @ace_` rows **remain at 33**, and forced recompile grows 473 → 504 lines. A row dump proved separation: for `take_damage`, row 31 = a 7-line RawCodeRow with the `## @ace_action` block and **no** func, row 32 = a 36-line RawCodeRow with `func take_damage` and **no** annotation.

**Parity coverage: partly.** The parity spec's §1.1/§1.2/§1.5 (Function system, three-way expose, Functions picker) + §5.2 (re-author) is the *forward* answer for converting these at the source, and the exposed-getter conversion is the **core** of that spec. The **open-path reach fixes** — coalescing the separated annotation+func rows and wiring the byte-gated chain into `import_external` so the *already-existing* shell-lift applies to the whole file, not just the trailing run — are the **new work** the parity spec never contemplates (§4-C). This is the one place the open path leaves lift on the table.

### 3.3 `blank_separator` 114 · `class_scaffold` 21 · `host_binding` 29 (164 structural)

**What they are.** All three are compiler-emitted structure/boilerplate, not authored logic.

**Verified root cause.** (1) **`blank_separator`:** every one is `code == ""`, `line_count == 1` (only distinct blank code in the JSON is the empty string). The importer preserves blanks as RawCodeRows solely for byte-exact round-trip. `viewport_row_builder.gd:_build_raw_code_row` (`:208-258`) has **no** early-out for blank-only code, so each blank renders as a full striped row with a muted "setup" badge. (2) **`class_scaffold`:** `@icon`/`class_name`/`extends` + doc prelude; `is_scaffolding_code` returns true and the leading-run collapse (`event_sheet_viewport.gd:1542-1560`) already folds them into the foldable "Class setup" strip — **correct, no change needed.** (3) **`host_binding`:** the compiler emits a 4-line block (`sheet_compiler.gd:171-174`): `func _enter_tree()` / `host = get_parent() as X` / `if host == null:` / `push_warning(...)`. The `is_scaffolding_code` whitelist (`event_sheet_viewport.gd:1719-1721`) accepts only `func _enter_tree` and `host = get_parent` — it does **not** whitelist `if host == null:` or `push_warning(`, so the whole block classifies as **logic** (returns false), gets the bright "GDScript" badge, and — sitting at events index 2 — **breaks the leading-run collapse loop**, rendering as a standalone GDScript block just below the "Class setup" strip. Verified by a headless probe of `is_scaffolding_code` on the real strings: prelude = true, blank = true, the 4-line guarded host-binding = **false**, minimal 2-line host = true.

**Examples.** `bullet_behavior.gd` block 2: `func _enter_tree() -> void: / host = get_parent() as Node2D / if host == null: / push_warning("BulletBehavior behavior requires a Node2D parent.")` — currently a standalone bright "GDScript" block, not folded. `abilities_behavior.gd`: same shape with `as Node`. One host-binding per pack (29 total).

**Parity coverage: no.** The parity spec's zero-RawCode goal is about *logic vocabulary*; it never addresses blank-only rows, class preludes, or the `_enter_tree` scaffold. All rendering treatment here is **new work** (§4-B).

### 3.4 `other_statements` 54 · `numeric_or_expr_kernel` 20 · `match_control_flow` 5 (mixed)

**What they are.** Three impure buckets the heuristic over/mis-labels.

**Verified root cause.**
- **`numeric_or_expr_kernel` (20):** the catch-all (`_tmp_block_audit.gd:104`), firing on ` and `/` or `/` if `/`velocity`/`lerp`/`move_toward`. **12 of 20 are leading `#` pack-description comments or class scaffolding** whose prose contains ` if `/` or ` (spring/juice/health/htn headers, `demo_health` prelude). Only **8 are genuine per-frame math**, and of those, `spring` `SpringEntry.integrate()` (`velocity += (target-value)*stiffness*delta` / `velocity *= pow(1-damping,delta)` / `value += velocity*delta`) and juice's squash-spring are the textbook parity-spec §5.4 kernels; the short ones (`platformer` `target_speed`/`rate`, `drag_drop` `ref`/`gate`, `orbit` `radius_b`) are single walrus-local lines that stay raw for the same reason as `other_statements`.
- **`match_control_flow` (5):** fires on any block containing `match ` + `:` (`_tmp_block_audit.gd:100`). All 5 are **entire private helper funcs** whose body is a `match` returning enum ids (`_slowmo_trans`/`_slowmo_ease` in juice, `_trans_id`/`_ease_id` in tween, `_apply_to_host` in spring). A headless probe of `_lift_sheet_function` on 3 of them returned **`lift_ok = true`** — the `match` branch in `_parse_body` (`ace_lifter.gd:887-909`) correctly builds a `MatchRow` (verbatim `branches_text` via `substr`), a trailing `return` becomes a second action, and emit (`sheet_compiler.gd:1176-1187`) reproduces byte-for-byte. **`match` is NOT the blocker** — these are `helper_func_body` in disguise, held back only by the §3.1 whole-sheet gate coupling them to sibling raw blocks. The blank-inside-arms bail (`ace_lifter.gd:894`) does **not** apply — none has a blank line inside its arms.
- **`other_statements` (54):** the true fall-through — 17 walrus `var x := EXPR` inferred-type locals, 10 `## @ace_tags(...)` fragments, 11 comment-only, 6 inner control-flow tails, 3 inner `class` declarations, 7 misc. The **dominant real driver is the walrus locals.** Verified grammar gap: the reverse index (`ace_lifter.gd:1086-1130`) registers `SetLocalVar` (`var {name} = {value}`) and `SetLocalVarTyped` (`var {name}: {var_type} = {value}`) (`helper_aces.gd:60,64`), both compiled to a regex requiring literal ` = ` (`_template_to_regex ace_lifter.gd:1180-1181`). A source line `var target_speed := direction * move_speed` has ` := ` — matches **neither** template — and falls to `pending_raw` (`_consume_action_line ace_lifter.gd:1063-1064`). Inferred-type locals are inexpressible in reverse-lift even though the forward ACEs exist.

**Examples.** Honest kernel: `spring_behavior.gd` `SpringEntry.integrate()`. Mis-tagged: `spring_behavior.gd:1` `# Numeric springing: snappy, physical motion...` (prose comment). Match-in-disguise: `tween_behavior.gd` `func _trans_id() -> int:` with `match transition:` + trailing `return Tween.TRANS_SINE`. Grammar gap: `platformer_movement_behavior.gd` `var target_speed := direction * move_speed` / `var rate := acceleration if not is_zero_approx(direction) else deceleration`. Mis-tagged fragment: `htn_agent_behavior.gd:1` `## @ace_tags(ai, planning)` and a 14-line inner `class HTNMethod:`.

**Parity coverage: partly.** The 8 genuine kernels are sanctioned by §5.4. The `match` funcs need no `match` work. The walrus-local gap (~17 blocks) is **new, small, well-scoped work** not in the parity spec (§4-E). The ~37 non-logic fragments should never be rows — the fix is the audit classifier, not the lifter.

---

## 4. Solutions roadmap

Each category maps to one of: **(a)** a parity-spec workstream (reference §), **(b)** NEW work this audit surfaces, or **(c)** honest-GDScript keep. Ordered by leverage.

| # | Workstream | Kind | Closes | Category → parity § |
|---|---|---|---:|---|
| A | Per-function byte-gating | **NEW** | ~155 | `helper_func_body`, `match_control_flow` |
| B | Scaffold/blank/host rendering | **NEW** | 164 (out of count) | `blank_separator`, `class_scaffold`, `host_binding` |
| C | Open-path exposed-func shell-lift | **NEW (wiring; mechanism exists)** | 249 (made editable) | `exposed_action_rawcode`, `exposed_getter_rawcode` |
| D | Function system + re-author packs | parity §1, §5.2 | 249 (converted) | exposed action/getter |
| E | Walrus inferred-local reverse-lift | **NEW (small)** | ~17 | `other_statements` |
| F | Host-targeting + physics vocabulary | parity §2 | shrinks kernels | `numeric_or_expr_kernel` |
| G | Honest-GDScript keep + ratchet | parity §5.3/§5.4 | ~150 floor | kernels, nested classes |
| H | Audit classifier fix | **NEW (tooling)** | ~49 mis-tags | mixed |

**(A) Per-function byte-gating [NEW, highest yield, no new grammar].** Make `lift_function_declarations` (`ace_lifter.gd:506-511`) **per-function** byte-gated instead of all-or-nothing: lift each func independently, keep only those whose whole-sheet recompile stays byte-identical, revert just the failures — mirroring the per-event gate already used by `lift_event_bodies` (`ace_lifter.gd:336-360`). This alone rescues the ~155 bodies in **flat (no-nested-class) packs** whose only blocker is a sibling func's ordering/spacing divergence (`virtual_cursor` 58, `juice` 19, `save_system` 17, `advanced_random` 23, `time_slicer` 11, `tween` 8, `tile_movement` 5, `follow` 3, `line_of_sight` ×2 = 8, plus the 5 `match` funcs which lift for free once decoupled). No golden-file churn beyond the intended lifts.

**(B) Scaffold / blank / host rendering [NEW, pure editor view-state, drift-safe].** Three targeted non-codegen fixes, all leaving `RawCodeRow`s untouched so byte-exact round-trip is preserved:
1. **Blank:** in `viewport_row_builder.gd:_build_raw_code_row`, add an early-out when `raw_row.code.strip_edges().is_empty()` — skip building the row (dispatcher returns null) or render a thin badge-less spacer. Suppression preferred so a wall of behaviour blocks reads clean.
2. **Class scaffold:** no change — already folded into "Class setup."
3. **Host binding:** extend the `is_scaffolding_code` whitelist (`event_sheet_viewport.gd:1720`) to also accept `if host == null` and `push_warning(` (tightly: only when the block also contains the `_enter_tree`/`host = get_parent` lines). Then the 4-line block gets the muted "setup" badge **and** folds into the "Class setup" strip instead of breaking the collapse loop. Update the docstring at `:1719` (currently describes only the 2-line form).

Then **exclude these ~164 structural rows from the §5.3 ratchet count** so the budget measures logic only.

**(C) Open-path exposed-func shell-lift [extends an EXISTING mechanism to the whole file].** The shell-lift itself is already built and byte-safe: `_lift_sheet_function` rebuilds an exposed `EventFunction` shell and runs on open for trailing-run funcs (`platformer_movement` opens with 12 exposed shells, byte-identical — §3.2). The new work only extends its *reach* past the trailing run, via two fixes: (i) **coalesce** the stranded annotation `RawCodeRow` with its following func row before splitting — the existing look-back in `_split_function_declarations` (`ace_lifter.gd:533-548`) is *intra-row*, so it can't associate an annotation that `import_external_source` emitted as a **separate** prior row; coalescing lets `_parse_annotations` see the lead block and set `expose_as_ace = true` (fixes the §3.2 cross-row separation); (ii) **wire the byte-gated chain into `import_external_source` after `attempt_lift`** so opening a pack reverse-lifts exposed funcs *outside* the trailing run the same way pack-build does. Pair with per-function gating (A) so an interleaved pack partially lifts instead of whole-sheet reverting. This makes a behaviour's published vocabulary visible/editable as a Function row instead of an opaque 6-7-line block, **without** requiring every pack to be re-authored first. Land with a golden round-trip test proving drift = 0 across all 32 packs.

**(D) Function system + re-author packs [parity §1.1/§1.2/§1.5 + §5.2, SPEC'd, unbuilt].** The forward answer for the 249 exposed blocks: build the three-way expose (void→`@ace_action`, bool→`@ace_condition`, value→`@ace_expression`) and re-author `abilities`/`health` getters as `EventFunction`s, success criterion = byte-identical regenerated annotations. **C and D are complementary:** C makes un-re-authored packs editable *now*; D is the eventual source-of-truth conversion. Do **not** duplicate the parity spec's vocabulary/expose design — it is the detailed design for this workstream.

**(E) Walrus inferred-local reverse-lift [NEW, small].** Add a reverse entry for `var {name} := {value}` — either a `SetLocalVarInferred` ACE or teach `SetLocalVar`'s reverse regex to accept ` := ` as well as ` = `. Converts ~17 blocks (shrinks `platformer`, `drag_drop`, `orbit`, `sine`, `bullet`, `car`). **Optional cleanup, not a correctness requirement** — parity §5.4 explicitly blesses keeping dense interleaved local clusters as GDScript.

**(F) Host-targeting + physics vocabulary [parity §2, largely BUILT].** `SetVelocityX/Y`, `ApplyGravity`, `AccelerateVelocityX/Y`, `SetLocalVarTyped`, `{host.}` already exist (`core_aces.gd`/`helper_aces.gd`) and, per the isolated probes, are **not** what blocks the 291 bodies today. This shrinks the numeric kernels but is not the lever for the bulk.

**(G) Honest-GDScript keep + ratchet [parity §5.3/§5.4].** The ~8 genuine numeric kernels and the nested typed `class` blocks (`AbilityData`, `HTNMethod`, `ColorSpringEntry`, `SpringEntry`) stay GDScript under a documented per-pack `pack_rawcode_budget` with a reason string. These are the honest floor — do not force them into rows.

**(H) Audit classifier fix [NEW tooling].** Fix `_classify` so the ~12 comment/scaffold "kernels", 5 match-funcs, and ~37 non-logic `other_statements` fragments stop being mis-counted. This is measurement hygiene so the ratchet tracks real logic.

### Ratchet / what good looks like

- **Structural rows (164) → 0 in the count** via (B): excluded from the budget, rendered as scaffold chips or suppressed.
- **Flat-pack helper bodies (~155) → rows** via (A): `virtual_cursor`, `juice`, `save_system`, `advanced_random`, `time_slicer`, `tween`, etc. drop toward their honest floor.
- **249 exposed blocks → editable Function shells** via (C) immediately, → converted `EventFunction`s via (D) at the source.
- **Honest floor (~150):** numeric kernels + nested-class state, each under a documented non-zero budget. **Goal is zero *gratuitous* RawCode, not dogmatic zero** (parity §5.4).

---

## 5. Sequencing, files to touch, tests

### 5.1 Sequencing

1. **(H) Audit classifier fix** — cheap, makes the ratchet honest before anything else moves.
2. **(B) Scaffold/blank/host rendering** — pure view-state, zero drift risk, immediately removes 164 rows from what the user *sees* and from the count. Highest visible impact per unit risk.
3. **(A) Per-function byte-gating** — highest logic-conversion yield (~155), no new grammar, no golden churn beyond intended lifts. Land with the per-function gate mirroring the existing per-event gate.
4. **(C) Open-path shell-lift** — makes the 249 exposed blocks editable without re-authoring; golden round-trip test proving drift = 0 across all 32 packs is the gate.
5. **(E) Walrus reverse-lift** — small optional cleanup once A/C are in.
6. **(D) Function system + re-author abilities/health** — the parity-spec workstream; convert exposed getters/actions at the source, verify byte-identical annotations.
7. **(G) Ratchet + budgets** — codify the honest floor; `pack_rawcode_budget_test` fails on regressions only.

Stage 1-3 as one release (measurement + rendering + the biggest structural conversion), then C/E/D incrementally under the ratchet.

### 5.2 Files to touch

| File | Change | Workstream |
|---|---|---|
| `tools/_tmp_block_audit.gd` | Fix `_classify` priority so match-funcs → `helper_func_body`, prose comments/`@ace_tags`/inner-class fragments stop counting as kernels/logic (`:86-106`). | H |
| `addons/eventsheet/editor/interaction/viewport_row_builder.gd` | Blank early-out in `_build_raw_code_row` (`:208-258`). | B |
| `addons/eventsheet/editor/event_sheet_viewport.gd` | Extend `is_scaffolding_code` whitelist (`:1719-1721`) to the 4-line host-guard; update docstring; verify leading-run collapse (`:1542-1560`) now folds it. | B |
| `addons/eventforge/importer/ace_lifter.gd` | Per-function byte-gate in `lift_function_declarations` (`:506-511`, mirror `:336-360`); coalesce annotation+func rows / look-back in `_split_function_declarations` (`:534-547`); walrus `:=` reverse entry (`:1086-1130`, `:1180-1181`). | A, C, E |
| `addons/eventforge/importer/gdscript_importer.gd` | Wire byte-gated full lift chain into `import_external_source` after `attempt_lift` (`:184`); stop flushing the annotation block as a separate row (`:79-97`). | C |
| `addons/eventforge/compiler/sheet_compiler.gd` | Three-way expose in `_emit_expose_annotations` (parity §1.2). | D |
| `addons/eventsheet/editor/event_sheet_dock.gd` | Functions picker category + re-author affordances (parity §1.5). | D |
| `tools/pack_builders/abilities.gd`, `health.gd` | Re-author getters/actions as `EventFunction`s; byte-identical annotations (parity §5.2). | D |
| `tools/project_doctor.gd` | Non-blocking `RawCodeInBundledPack` advisory (parity §5.3). | G |

### 5.3 Tests to add

- `per_function_gate_test.gd` — a flat pack with one un-liftable sibling still lifts all its other funcs (per-function gate keeps the good, reverts only the bad); asserts `virtual_cursor`/`juice` drop to their honest floor.
- `scaffold_render_test.gd` — extend the `is_scaffolding_code` unit test with the real 4-line guarded host-binding string (returns true); blank-only code produces no visible GDScript row; the host-guard folds into "Class setup".
- `open_path_shell_lift_test.gd` — opening `health_behavior.gd`/`abilities_behavior.gd` produces `EventFunction` shells for the exposed funcs (name + typed params + expose flag), body as one nested `RawCodeRow`; recompile is byte-identical.
- `full_chain_roundtrip_test.gd` — the golden gate: run the shell-lift + full chain on all 32 packs, assert drift = 0 (regenerated `.gd` byte-identical to source).
- `walrus_local_roundtrip_test.gd` — `var x := EXPR` lifts to `SetLocalVar`/`SetLocalVarInferred` and recompiles byte-identical (`platformer` `target_speed`/`rate`).
- `pack_rawcode_budget_test.gd` — per-pack `{pack: max_rawcode_rows}` ratchet counting **logic only** (structural rows excluded); fails on any pack exceeding budget; documented non-zero budgets for numeric-kernel/nested-class packs.
- `audit_classifier_test.gd` — the 5 match-funcs classify as `helper_func_body`, prose comments do not classify as `numeric_or_expr_kernel`, `@ace_tags`/inner-class fragments do not classify as logic.
