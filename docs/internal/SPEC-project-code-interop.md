# SPEC: Project Code Interop - the adoption ladder

Status: DRAFT, not scheduled. Owner decision needed on the open questions in section 10.

**The problem.** A user with existing GDScript - `res://systems/inventory.gd`, an autoload,
a teammate's utility class - can already use it from sheets, but only by finding one of
three unrelated mechanisms, each with a setup cost: move or copy the script into
`res://eventsheet_addons/`, run the Custom Actions wizard and let it write annotations into
their file, or hand-type member names into Call Method. The three work; nothing unifies
them; none is discoverable; and the automatic one does not exist.

**The goal.** Foreign project code is usable from the picker with **zero setup**, reads
like bundled vocabulary **without the user authoring anything**, and stays **editable,
legible and reversible** when the user does care. Automation must never become magic the
user cannot see, correct, or undo - a tool that guesses wrong and hides it costs more
iteration than one that never guessed.

## 1. Verified status quo (the two facts this spec turns on)

1. **The provider scan is hard-scoped to one folder.** `ace/addon_scanner.gd` declares
   `const ADDON_DIRS: Array[String] = ["res://eventsheet_addons/"]`. Scripts anywhere else
   are invisible to the vocabulary system.
2. **The reflection pickers are host-scoped and ClassDB-only.**
   `ace_params_dialog._create_method_reference_field` calls
   `reflected_members(_host_class_for_context(), "method")`, which early-returns empty
   unless `ClassDB.class_exists(host_class)`. Consequences: Call Method's member dropdown
   lists the SHEET HOST's members regardless of what `target` points at, and a user's
   `class_name` script is not in ClassDB at all, so the list is empty and the field
   degrades to free text.

Everything else needed already exists: the mtime-keyed registry cache, the display-sentence
synthesizer (`ace_generator._build_method_display_template`), the param-hint widget set and
`param_spec`, node-target parameterization, autoload singleton codegen, the usage store and
learned ranking, inline row editing of a verb's name/description/category, the annotation
writer, `curate_provider`, and the Doctor. **This spec is mostly wiring existing seams to a
project-wide input set, not new subsystems.**

## 2. Design principles (each one is a rejection of a way tools fight users)

1. **Value before decisions.** Nothing may require a choice before the script is usable.
2. **Cost proportional to caring.** Refinement is per-item, never per-script ceremony.
3. **No file mutation by default.** Writing into the user's source is opt-in, never the
   price of admission.
4. **Every inference is visible and one click from override.** Provenance is UI, not docs.
5. **Deleting our data may never break the user's sheets.** The catalog is pure refinement.
6. **Follow refactors, do not punish them.** A rename in the user's code is the most common
   iteration act; the tool offers to keep up.
7. **Conservative inference.** A wrong guess is worse than no guess (the Doctor law,
   applied to vocabulary).

## 3. The adoption ladder

| Level | Trigger | User cost | Result |
|---|---|---|---|
| **L0 Unseen** | script outside the scan set | - | not in the vocabulary |
| **L1 Reflected** | automatic, on scan | none | class + public members appear under "This Project"; picking emits a real call |
| **L2 Inferred** | automatic, same pass | none | kind, sentence, category and param hints inferred; the verb reads like a bundled one |
| **L3 Curated** | user edits one thing | one click | override stored (catalog by default, source if baked) |

L1 and L2 are one pass and one code path - the split is conceptual, describing what the
user perceives (it appears; it reads well). **L2→L3 is per-member.** There is no "adopt
this script" modal anywhere in this design.

## 4. How the three tiers unify

- **Tier C becomes plumbing.** Call Method / Set Property stop being what a user reaches
  for and become the EMISSION SHAPE of L1/L2 verbs. The user picks `Inventory ▸ Add Item`;
  the row bakes `{target}.add_item({item_id}, {count})`. Typing member names into a text
  field stops being a normal workflow.
- **Tier B becomes the default state.** Publishing is what happens automatically; the
  wizard becomes the refinement surface (L3), not the entry fee.
- **Tier A is INDEPENDENT** (corrected 2026-08-05). The original draft claimed a wider
  vocabulary would make the lifter cover more foreign code. Reading the lifter disproved it:
  a call like `$Inventory.add_item(...)` already lifts as an editable row through the
  generic-call path, with no vocabulary lookup involved. Tiers B and C still stand on their
  own; they simply do not multiply Tier A. See 5.9 for the declined phase this premise
  produced - a reminder to verify a motivating claim against the code before building on it.

**Architecturally there is no new row kind, no new emission path and no new lift path.**
An L1/L2 verb is an ordinary synthesized `ACEDefinition` - the same thing
`@ace_expose_all` produces today. This spec is, in one sentence: *run the existing
synthesis over the whole project, virtually, without requiring the annotation or the
folder, and put a control surface on top.*

## 5. Mechanisms

### 5.1 The project scan (`ace/project_scanner.gd`, `EventSheetProjectScanner`)

**Scanned by default:**
- Global script classes (`ProjectSettings.get_global_class_list()`) - a `class_name` is the
  stable identity a provider id needs.
- Autoload singletons (the `autoload/*` project settings) - identity is the autoload name.

**Opt-in (project setting `eventsheets/vocabulary/extra_paths`):** additional folders or
individual scripts, for `class_name`-less code. Identity falls back to the PascalCase
filename (the existing convention for class-name-less providers). Default empty - this is
the flooding valve, not the default door.

**Never scanned:** the plugin's own `addons/` tree, `_`-prefixed members, scripts marked
`@ace_hidden`, and anything excluded per-class (5.5).

**Derivation is script-level only.** `get_script_method_list`, `get_script_property_list`,
`get_script_signal_list`, `Script.get_property_default_value`, and source-read annotations.
**No instancing, ever** - `can_instantiate()` is tool-gated in the editor, so instance
reflection returns nothing exactly where the feature runs while headless tests pass
(section 9 trap 1).

**Performance is a contract, not an aspiration.** The scan reuses the registry's existing
`path|mtime|length` cache, refreshes only on filesystem-changed pings, and **dialog-open
never triggers a scan**. Budgets to pin in tests: cold scan of a 500-script project
≤ 400 ms; warm re-resolve ≤ 15 ms; picker open 0 scans.

### 5.2 The "This Project" picker section

A pinned section mirroring the Self section's construction: one root, a subgroup per class
or autoload, members inside. Flooding controls, all on by default:

- default scan set is your classes and autoloads only (5.1);
- public members only, `_`-prefix respected;
- per-class exclude toggle (right-click a subgroup) written to the catalog;
- ordering by the existing usage store, so what you use rises;
- the section collapses to one line when a query is typed (query-scoped, like Self).

The section must make the picker feel NARROWER, not wider: a user should find their own
`add_item` faster than they previously found `Call Method` plus typing.

### 5.3 Emission and identity (frozen-surface discipline)

| Host shape | Emitted template | Target param |
|---|---|---|
| Autoload | `InventorySystem.add_item({item_id}, {count})` | none |
| Node-attached class | `{target}.add_item({item_id}, {count})` | "On node", default `$Inventory` (existing `_parameterize_node_target`) |
| Plain class (RefCounted/Resource) | static members: `Utils.clamp01({value})`; instance members require an explicit object expression param | object expression |
| Property | `{target}.{property} = {value}` action + read expression (existing property codegen) | as above |

Ids reuse the generated-provider scheme: `provider_id` = class or autoload name,
`ace_id` = `method:add_item` / `signal:on_x` / `property:y`. Two consequences that matter:

- No new id space and no collision with packs.
- **A row bakes its template at apply time** (the standing covenant), so a sheet that uses
  an L1 verb keeps working even if the catalog is deleted, the class is renamed, or the
  scan is disabled. The vocabulary is needed to PICK, never to COMPILE.

### 5.4 Inference rules (`ace/inference.gd`, static + pure, unit-testable)

| Facet | Rule | Conservatism |
|---|---|---|
| Kind | `bool` return → condition; `void` → action; anything else → expression | Untyped/`Variant` return → **expression** (the safe kind), never condition |
| Sentence | existing `_build_method_display_template` ("Add Item {item_id} {count}"), name split on `_` and capitalized | Never invents prepositions; the user renames inline if they want prose |
| Category | class display name (autoload name / `class_name` capitalized) | Never guesses a semantic category like "Combat" |
| Param hint | name+type table: `path`/`file` + String → file picker; `action` + String → live Input Map picker; `Color` → colour swatch; `Node`/`NodePath` → node picker; typed enum → labeled dropdown; `group` → group picker; else expression field | Unknown → plain expression field (today's behaviour), never a wrong widget |
| Description | the member's `##` doc comment, first sentence | Empty rather than synthesized prose |

The hint table is an OVERRIDE list layered on derivation, matching the standing preference
for derived-over-hand-maintained mappings.

### 5.5 The override catalog (`ace/vocabulary_catalog.gd`)

One project file, `res://eventsheet_vocabulary.tres`, human-readable and diffable,
containing ONLY overrides keyed `provider::ace_id` (plus per-class exclude flags).

**Resolution order: in-source annotation > catalog > inference > raw reflection.**
In-source wins so a script that says what it is is never overruled by our side file - and
when a user edits a member whose identity comes from source, the editor routes the edit to
the source (offering the bake in 5.7) rather than silently writing a catalog entry that
does nothing. The provenance chip (5.6) always names the layer that won.

**Deleting the catalog is safe by design**: verbs fall back to inference, ids and baked
templates are unchanged, and no sheet changes behaviour. Test-pinned (section 8, P3 gate).

### 5.6 Provenance and inline editing

Every picker card and every applied row carries a small source chip: `pack` /
`your script · inferred` / `your script · curated` / `your script · annotated`. Clicking it
opens the override popover (display name, category, kind, param hints, hide). Editing a
verb's name/description/category reuses the inline row editors that already exist for sheet
functions - the same gesture, a different backing store.

### 5.7 Bake into source / extract to catalog

Both directions, one click, reversible:

- **Bake**: writes `## @ace_*` annotations into the script via the existing annotation
  writer + `curate_provider` semantics (backup first, `##` lines only, re-applying is a
  no-op, no signature or body touched). For teams who want self-describing source.
- **Extract**: lifts a script's annotations into the catalog and removes them from the
  file (same safety rules). For teams who want untouched source.

Neither is ever required; the catalog path is the default so the tool's first contact with
a user's file is read-only.

### 5.8 Refactor-following (the iteration safety net)

The Doctor's orphaned-verb check upgrades from reporting to offering. On scan, compare each
sheet's referenced `provider::ace_id` set against the live scan:

- **Missing member with a close match** (Levenshtein over member names, plus arity and
  parameter-type agreement): "`Inventory.heal` no longer exists - closest match `heal_by`.
  [Update 6 rows]" - one undoable edit that rewrites the baked templates and ids across
  every affected row.
- **Missing member with no close match**: report only, clickable to the rows.
- **Signature drift** (member exists, arity changed): offer to add/drop the parameter with
  the new default filled in.

Conservatism law applies: the fix is always an OFFER, never automatic, and must ship with
must-not-fire tests as prominent as its fire tests.

### 5.9 Lifter integration - DECLINED (2026-08-05)

**Original proposal:** the lifter consults the project vocabulary when matching statement
shapes, so `$Inventory.add_item("potion", 1)` lifts as the named verb row instead of a
verbatim block.

**Decision: do not build it.** An adversarial review that read the lifter found the
motivation false and the design unsafe:

1. **The premise was wrong.** Such a call does NOT become a verbatim block today - the
   existing generic-call handling already lifts it as an editable row. The phase was
   proposed to fix something that is not broken, so section 4's "Tier A compounds" claim
   (that a wider vocabulary makes the lifter cover more) is corrected here too: it does not.
2. **It would break a property nothing else breaks.** A lift is currently a pure function of
   the file's bytes. Consulting project vocabulary makes it depend on mutable editor state -
   the scan, the reflection caches, and the catalog (whose `hidden` flags genuinely change
   the entry set). The same file would lift differently on two machines, or after a rename.
3. **The gate everyone would cite cannot detect the damage.** The pack drift audit compares
   BYTES, and a re-attributed row re-emits identical bytes: `drifted=0` would stay green
   while every row in a file silently named a different verb.

**The safer design that captures the remaining value (candidate P5'):** leave the lifter
untouched. In the RENDERER, when a generic-call row's target + method + arity resolve to
exactly one project-vocabulary verb, show that verb's inferred sentence and a provenance
chip ("looks like Inventory > Add Item") with a one-click **Convert to this verb** that goes
through the ordinary apply path (which bakes the template at apply time, satisfying the
existing covenants). Attribution becomes a user act rather than a guess - the same
"offer, never automatic" law P4's refactor-following follows - and lift stays a pure
function of the file.

If P5' is built, its gate is a row-IDENTITY snapshot (the ordered `provider::ace_id` per row
for every pack and showcase, checked in and compared), because byte-drift alone cannot see
attribution changes.

## 6. Public API additions (frozen once shipped)

| Method | Returns | Purpose |
|---|---|---|
| `EventSheets.project_vocabulary()` | `Array[ACEDefinition]` | the current L1/L2 set, for tooling |
| `EventSheets.override_verb(provider_id, ace_id, edits)` | `Dictionary` | write one catalog override |
| `EventSheets.bake_overrides(script_path)` / `extract_overrides(script_path)` | `Dictionary` | 5.7, both directions |
| `EventSheets.register_vocabulary_path(path)` | `bool` | add a scan path programmatically |

## 7. Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Picker flooding | High | 5.2 controls; default scan set is classes + autoloads only; usage ranking |
| Scan cost on large projects | Medium | mtime cache, filesystem-ping refresh, never on dialog-open, pinned budgets |
| Wrong inference read as the tool "deciding" | Medium | provenance chip + one-click override; conservative table; expression as the safe default |
| Catalog drift vs source | Medium | refactor-following (5.8) + orphaned-verb check; catalog is refinement-only so drift degrades to plain verbs |
| Users assume L1 verbs are as curated as packs | Low | provenance chip distinguishes them everywhere |

## 8. Build order (each phase independently shippable)

| Phase | Scope | Gate |
|---|---|---|
| **P1** | `project_scanner` + "This Project" picker section; emission per 5.3 | Perf budgets pinned; no-instancing lint test; a real project script picks and compiles; flooding controls verified on a 200-class fixture |
| **P2** | `inference` layer (kind, sentence, category, hints) | Value-pinned inference table incl. must-NOT-infer-condition cases; sentences pinned as strings |
| **P3** | Catalog + provenance chips + inline edit routing | Resolution order pinned; **delete-the-catalog test**: ids, templates and emitted output byte-identical before/after deletion |
| **P4** | Bake / extract + refactor-following | Bake is backup-gated and idempotent; drift fix updates N rows in ONE undo step; must-not-fire suite for the matcher |
| **P5** | ~~Lifter consults the vocabulary~~ **DECLINED** (5.9): premise falsified, and it would make lift depend on mutable editor state while the byte-drift gate could not detect the damage | - |
| **P5'** | *Candidate:* renderer-side "looks like X, convert?" affordance on generic-call rows, lifter untouched | Row-IDENTITY snapshot per pack/showcase (bytes cannot see attribution changes) |

## 9. Traps this feature will hit (pre-paid from this repo's history)

1. **In-editor instantiation is a mirage.** Derive from scripts and types; a feature built
   on instance reflection passes headless and ships empty. Verify in a real-editor probe.
2. **Annotation reads come from DISK.** An unsaved or pathless script parses empty - test
   fixtures must write real files.
3. **Definitions are immutable and statically cached.** Overrides produce new definitions
   or bake into row copies; never mutate a shared definition.
4. **Usage-ranked lists make suites order-dependent.** Any test asserting picker order must
   reset the usage store first.
5. **The silent harness.** Check the literal verdict line, never grep for failures.
6. **Advisory checks must be conservative.** The refactor matcher's false positive would
   teach users to distrust the whole panel.

## 10. Open questions (owner decisions)

1. Catalog format: `.tres` (native, inspectable) vs `.json` (diff-friendlier for teams)?
   Leaning `.tres` for consistency with the rest of the project's data.
2. Should `class_name`-less scripts be scanned by default once `extra_paths` proves safe,
   or stay opt-in permanently? (Leaning permanently opt-in: identity is weaker.)
3. Does the "This Project" section also expose ENGINE classes reachable from the host
   (ClassDB), or does that stay the Self section's job? (Leaning: stays Self's.)
4. Do L1 verbs appear in the quick-add/ghost-row match set immediately, or only after first
   use from the picker? (Leaning immediately, with usage ranking sorting them below curated
   vocabulary until used.)
