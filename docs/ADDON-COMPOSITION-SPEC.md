# Addon Composition — Spec (addon includes addon)

Can one EventSheets addon **dock/include another addon** and build on it? Status:
**SPEC + ANALYSIS — awaiting scheduling.** Lane A is mostly buildable on existing
machinery; the analysis below is the decision record.

## What exists today (the building blocks)

- **C3-style includes** (`sheet.includes`): compile-time merge of another sheet's rows,
  variables and functions into the compiling sheet (root wins collisions, cycles skip
  with warnings). Works on *any* sheet — including behavior sheets.
- **Instance-backed providers**: template-less addon ACEs already compile to calls on a
  plain owned instance (`var __eventsheet_provider_X := X.new()`) — a has-a dependency
  with zero plugin runtime.
- **Behavior packs as components**: packs attach as child nodes; hosts are declared
  (`host_class`) and warned about at attach time.
- **Addon tags + Export Addon…**: discovery, curation, and one-click publishing.

## The three composition shapes (and which to support)

### Lane A — compile-time inclusion (SUPPORT FIRST)
An addon sheet lists other addon *sheets* as includes; the compiler bakes the merged
result into one standalone class — exactly how includes already work, formalized for
addons:

- **Sheet Type dialog** gains an *Includes (addon sheets)* list next to Tags.
- **Export Addon…** bundles included sheets (or records them in the pack README) so a
  shared pack never arrives broken.
- **Collision policy stays "root wins" + a compile warning** naming the shadowed
  variable/function and which include it came from (today the merge is silent —
  composition makes naming collisions likely, so the warning is the safety rail).
- Cycle detection already exists; add a regression test for addon-shaped cycles.

Result: a **"meta-pack"** (e.g. *Jam Kit* = movement + audio helpers + screen-shake)
compiles to one self-contained class. Zero runtime coupling — the compatibility
covenant holds untouched, because inclusion happens at compile time and ships as plain
merged GDScript.

### Lane B — has-a runtime dependency (SUPPORT SECOND)
An addon declares it *uses* another addon's compiled class:

- Annotation: `@ace_uses(ScreenShake)` on the addon class (or a Uses field in Sheet
  Type). The compiler emits the owned instance (existing provider-member machinery) and
  the addon's ACEs may call it.
- For behavior packs: attach-time affordance — attaching *Follow+* auto-offers to add
  its required *ScreenShake* sibling, and `_get_configuration_warnings()` flags a
  missing dependency (the Unity `[RequireComponent]` idiom, already half-built for
  hosts).

Result: real reuse without duplication — two packs sharing one base instance — at the
cost of a runtime object graph (still plain GDScript, still covenant-clean).

### Lane C — inheritance (`extends` another pack) — HONEST SKIP
Generated-class inheritance is Godot-native but wrong for this audience: the fragile
base-class problem lands on users who never see classes; `host_class` vs base-class
conflicts get confusing; C3 users don't think in is-a. Composition (A+B) covers the
real use cases. Document the manual escape hatch (a GDScript block can still
`extends` anything) and move on.

## Pros / cons by project size

| Project size | Value | Risk |
|---|---|---|
| **Jam / tiny** | High, narrowly: **meta-packs**. One include pulls a whole curated kit into a fresh project — the fastest possible start (core philosophy: speed-to-game). | Almost none — Lane A bakes flat; nothing to version. |
| **Mid (team, months)** | High: a shared *base utilities* addon (math, signal bus, screen effects) included by several custom addons kills copy-paste drift; tags + includes express team conventions. | Name collisions across includes (mitigated by the new warning); recompile-to-pick-up-base-changes must be understood (it's a feature: nothing changes silently). |
| **Large / long-lived** | Real but bounded: dependency *graphs* emerge, and this is where addon ecosystems historically rot ("addon hell": deep chains break when a base changes). | Highest. Mitigations: keep chains **shallow by policy** (compile warning past depth 2), Lane A's bake-at-compile freeze (consumers update deliberately, never silently), Export bundling so packs travel complete. No semantic versioning machinery in v1 — honest docs instead. |

**Net judgment:** support Lane A now (it's ~80% existing machinery and directly serves
the jam-kit and team-library cases), Lane B when a real pack needs it, never Lane C.
The thing that makes C3-style addon ecosystems fragile is *runtime* coupling and silent
upstream changes — Lane A's compile-time bake avoids both by construction.

## Test plan (when scheduled)
- Addon sheet including another addon sheet compiles standalone + parses.
- Collision warning names the include and the symbol; root still wins.
- Addon-shaped include cycle degrades with a warning (no hang, no partial class).
- Export Addon… bundles the included sheet; re-import of the bundle compiles.
- Meta-pack attaches and runs in the demo scene (editor smoke).
