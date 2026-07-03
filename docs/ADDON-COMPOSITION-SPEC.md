# Addon Composition - Spec (addon includes addon)

Can one EventSheets addon **dock/include another addon** and build on it? Status:
**Lane A + policy SHIPPED**; **Lane B SHIPPED** (B.1 uses-instances + B.2 sibling
requirements via _get_configuration_warnings - warning-badge only, no scene
auto-mutation); Lane C honestly skipped. The composition arc is complete. The analysis below is the decision record.

## What exists today (the building blocks)

- **C3-style includes** (`sheet.includes`): compile-time merge of another sheet's rows,
  variables and functions into the compiling sheet (root wins collisions, cycles skip
  with warnings). Works on *any* sheet - including behavior sheets.
- **Instance-backed providers**: template-less addon ACEs already compile to calls on a
  plain owned instance (`var __eventsheet_provider_X := X.new()`) - a has-a dependency
  with zero plugin runtime.
- **Behavior packs as components**: packs attach as child nodes; hosts are declared
  (`host_class`) and warned about at attach time.
- **Addon tags + Export Addon…**: discovery, curation, and one-click publishing.

## The three composition shapes (and which to support)

### Lane A - compile-time inclusion (SUPPORT FIRST)
An addon sheet lists other addon *sheets* as includes; the compiler bakes the merged
result into one standalone class - exactly how includes already work, formalized for
addons:

- **Sheet Type dialog** gains an *Includes (addon sheets)* list next to Tags.
- **Export Addon…** bundles included sheets (or records them in the pack README) so a
  shared pack never arrives broken.
- **Collision policy stays "root wins" + a compile warning** naming the shadowed
  variable/function and which include it came from (today the merge is silent -
  composition makes naming collisions likely, so the warning is the safety rail).
- Cycle detection already exists; add a regression test for addon-shaped cycles.

Result: a **"meta-pack"** (e.g. *Jam Kit* = movement + audio helpers + screen-shake)
compiles to one self-contained class. Zero runtime coupling - the compatibility
covenant holds untouched, because inclusion happens at compile time and ships as plain
merged GDScript.

### Lane B - has-a runtime dependency (SUPPORT SECOND)
An addon declares it *uses* another addon's compiled class:

- Annotation: `@ace_uses(ScreenShake)` on the addon class (or a Uses field in Sheet
  Type). The compiler emits the owned instance (existing provider-member machinery) and
  the addon's ACEs may call it.
- For behavior packs: attach-time affordance - attaching *Follow+* auto-offers to add
  its required *ScreenShake* sibling, and `_get_configuration_warnings()` flags a
  missing dependency (the Unity `[RequireComponent]` idiom, already half-built for
  hosts).

Result: real reuse without duplication - two packs sharing one base instance - at the
cost of a runtime object graph (still plain GDScript, still covenant-clean).

### Lane C - inheritance (`extends` another pack) - HONEST SKIP
Generated-class inheritance is Godot-native but wrong for this audience: the fragile
base-class problem lands on users who never see classes; `host_class` vs base-class
conflicts get confusing; C3 users don't think in is-a. Composition (A+B) covers the
real use cases. Document the manual escape hatch (a GDScript block can still
`extends` anything) and move on.

## Pros / cons by project size

| Project size | Value | Risk |
|---|---|---|
| **Jam / tiny** | High, narrowly: **meta-packs**. One include pulls a whole curated kit into a fresh project - the fastest possible start (core philosophy: speed-to-game). | Almost none - Lane A bakes flat; nothing to version. |
| **Mid (team, months)** | High: a shared *base utilities* addon (math, signal bus, screen effects) included by several custom addons kills copy-paste drift; tags + includes express team conventions. | Name collisions across includes (mitigated by the new warning); recompile-to-pick-up-base-changes must be understood (it's a feature: nothing changes silently). |
| **Large / long-lived** | Real but bounded: dependency *graphs* emerge, and this is where addon ecosystems historically rot ("addon hell": deep chains break when a base changes). | Highest. Mitigations: keep chains **shallow by policy** (compile warning past depth 2), Lane A's bake-at-compile freeze (consumers update deliberately, never silently), Export bundling so packs travel complete. No semantic versioning machinery in v1 - honest docs instead. |

**Net judgment:** support Lane A now (it's ~80% existing machinery and directly serves
the jam-kit and team-library cases), Lane B when a real pack needs it, never Lane C.
The thing that makes C3-style addon ecosystems fragile is *runtime* coupling and silent
upstream changes - Lane A's compile-time bake avoids both by construction.

## Project policy (settings governing composition)

Policy lives in **ProjectSettings** (`eventsheets/addons/*`) - Godot-native, stored in
`project.godot`, so it is **versioned, diffable and PR-reviewable** like any other
project decision, and readable headlessly by CI.

### The knobs (deliberately few - fixed settings, not a policy language)

| Setting | Values (default first) | What it gates |
|---|---|---|
| `composition_mode` | `allowed` / `lane_a_only` / `off` | Whether addon sheets may include other addons at all |
| `max_include_depth` | `2` (warn past) / N / `0` = flat | The anti-"addon hell" rail |
| `collision_policy` | `warn` / `error` / `silent` | Shadowed symbol on include merge |
| `include_sources` | `anywhere` / project folders / `tagged:<tag>` | Where includes may come from - `tagged:approved` turns the existing tag system into enforcement |
| `deprecated_tag_blocks` | `warn` / `error` / `off` | Including an addon tagged `deprecated` |
| `export_bundling` | `bundle` / `reference` | Whether Export Addon… must carry its includes |

Per-addon overrides: none in v1. One project, one policy - overrides are where
governance sprawl starts.

### The invariant that keeps policy honest

**Policy never changes generated code.** Same sheet + same includes ⇒ same bytes,
under every policy. Policy only decides whether a compile is *allowed* (error), *flagged*
(warning), or *clean* - it is a gate, not a compiler input. Otherwise policy becomes
hidden state that breaks reproducibility, golden tests, and pack portability.

### Enforcement points
1. **Edit time** - the Sheet Type dialog pre-flights the include list (disabled field
   when `off`, inline warnings for depth/tags) so users learn policy where they work,
   not at compile.
2. **Compile time** - warnings/errors in the compile result (existing channel).
3. **CI** - policy errors fail the headless suite; conventions become enforced, free.
4. **MCP** - `list_aces`/snippet tools respect `include_sources`, so AI assistants are
   policy-bound ("only approved addons" stops being advisory).

### Effect on usefulness by project size

- **Solo / jam:** policy must be invisible. Defaults are permissive (`allowed`, depth-2
  *warning*, `collision: warn`) - zero ceremony, full speed-to-game. The only default
  that may block anything is nothing; jams never meet the policy system unless they
  open it.
- **Mid teams:** the sweet spot - this is *who policy is for*. `tagged:approved`
  sourcing + `collision: error` + the depth rail turn composition from "risky habit"
  into adoptable infrastructure: conventions ride in `project.godot` (reviewed in PRs,
  inherited by new members automatically instead of via wiki), and CI enforces them.
- **Large orgs:** policy is governance - allowlists, deprecation bans, build gating,
  staleness visibility. Two risks: **policy sprawl** (countered by the tiny fixed knob
  set and no per-addon overrides) and **policy drift between projects** (a pack legal
  in project A errors in project B) - countered by Export Addon… recording its
  composition assumptions (depth, includes, tags) in pack metadata so a rejection is
  always explainable, never mysterious.

### Honest skips
- No semantic versioning / version-range constraints in v1 (bake-at-compile already
  prevents silent upstream breakage; version machinery is ecosystem-scale work).
- No per-user policy (it's a *project* contract).
- No runtime enforcement (generated games never know policy existed - covenant).

## Test plan (when scheduled)
- Addon sheet including another addon sheet compiles standalone + parses.
- Collision warning names the include and the symbol; root still wins.
- Addon-shaped include cycle degrades with a warning (no hang, no partial class).
- Export Addon… bundles the included sheet; re-import of the bundle compiles.
- Meta-pack attaches and runs in the demo scene (editor smoke).
- Policy matrix: `off` blocks the dialog field; `tagged:approved` rejects an untagged
  include with a named error; depth-3 chain warns at default policy and errors at
  `max_include_depth = 2` + `error`; identical bytes emitted under permissive vs strict
  policy for a legal sheet (the invariant).
