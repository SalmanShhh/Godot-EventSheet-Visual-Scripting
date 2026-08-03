# SPEC: The "Self" Expression Section

A pinned section in the expression surfaces that answers the C3 reflex "type `Self.` and see what
my object knows about itself" - the object's own properties, its sheet variables, its expression
functions, and its attached behaviours - while inserting plain GDScript, so the section teaches the
real language instead of adding a dialect.

## The one-sentence contract

**Self is a VIEW and ALIAS layer over data the plugin already derives. It mints no vocabulary, no
new ace_ids, and no `Self` token ever reaches emitted code or the round-trip.**

## Why

C3's `Self` bundles three ideas that land in three different Godot places: own properties are bare
names (`position.x`), instance variables are script members (`health`), and behaviour access goes
through child nodes (`$PlatformerMovement.velocity.x`). A migrating user knows none of that yet.
The Self section is the bridge: the C3 name is the label they scan for, the GDScript is what lands
in the field. After a week they stop needing it - which is the success criterion, not a failure.

## UX

Typing `self` or `Self.` in any ƒx field opens the expression picker pre-filtered to the Self
section. The section is also always pinned at the TOP of the expression tree, above the node-type
groups.

```
Self                        what this sheet's object knows about itself
├─ Variables                health · speed · combo          -> inserts the bare name
├─ Properties               X · position.x                  -> inserts position.x
│                           Angle · rotation                -> inserts rotation
│                           Opacity · modulate.a            -> inserts modulate.a
├─ Functions                ƒ dps()                          -> inserts dps()
├─ Loop                     item · loopindex                 (only while the caret is in a loop body)
└─ Behaviours               ▸ Platformer Movement            -> inserts $PlatformerMovement.velocity.x
                            ▸ Health  ▸ Weapon Kit ...
```

Every entry shows BOTH names: the C3-style label first (what the migrant scans for), the GDScript
it inserts as the subtitle. Entries insert at the caret through the existing
`_insert_into_expression_target(snippet)` path.

## Where each subgroup derives from (nothing hand-maintained)

| Subgroup   | Source (already exists)                                                        |
|------------|--------------------------------------------------------------------------------|
| Variables  | The live sheet's `variables` dict + tree `LocalVariable` rows - the same census `BehaviourAnatomyPanel.collect_anatomy` runs. `_add_sheet_variable_expressions` already lists these; Self RE-GROUPS them, it does not duplicate them. |
| Properties | ClassDB reflection of `sheet.host_class`, filtered to the C3-relevant commons by the override table below. A `Node2D` host offers X/Y/Angle; a `Control` offers size; a bare `Node` offers none. Same host-gating discipline as node-scoped ACEs. |
| Functions  | `sheet.functions` whose define-role classifies as *expression* (the same classifier the verb rows and the Anatomy panel use). |
| Loop       | Present only when the caret's row sits inside a loop body: the loop's element name and `loopindex`. Scope is SHOWN, never re-bound (see Non-goals). |
| Behaviours | Two tiers, below.                                                               |

## The C3 alias override table

The ONLY literal table in the feature, and it is an override list on top of reflection (the standing
house rule for mappings). Each entry: C3 label, GDScript fragment, host gate. Initial set:

| C3 label   | Inserts                     | Requires host      |
|------------|-----------------------------|--------------------|
| X          | `position.x`                | Node2D / Node3D    |
| Y          | `position.y`                | Node2D / Node3D    |
| Angle      | `rotation`                  | Node2D / Node3D    |
| Opacity    | `modulate.a`                | CanvasItem         |
| Width      | `size.x`                    | Control            |
| Height     | `size.y`                    | Control            |
| UID        | `get_instance_id()`         | Object             |
| ZIndex     | `z_index`                   | CanvasItem         |

Rules for growing it: an alias is added ONLY when the C3 name and the Godot name genuinely differ
(`position.x` needs the X alias; `scale` needs nothing). Aliases whose Godot property does not exist
on the sheet's host are dropped from the section, not shown disabled.

## The Behaviours subgroup - two tiers

A sheet is a script and does not know its scene instances at edit time, so grounding is best-effort
and honest about it:

1. **Grounded tier** (SHIPPED, Phase 3): when the Scene dock's selected node carries this sheet's
   script, reflect its ACTUAL behaviour children - real node names in every fragment (a renamed
   child inserts through its rename; two instances of one pack are two groups). Direct children
   only: that is where behaviours attach by convention, and a deep scan would list another
   object's organs. The subgroup labels itself "Behaviours (on the selected node)".
2. **Fallback tier**: no grounded node. List the installed packs (the Anatomy "Uses" census first
   and expanded, the rest collapsed below). Insertion uses the pack's class name, and the
   inserted `$NodeName` span is left SELECTED so one keystroke or a node drag (the fields already
   accept node drops) retargets it.

**Derivation is SCRIPT-LEVEL, never instance-level** - a constraint DISCOVERED by driving the real
editor, not designed up front: inside the editor process a non-@tool script cannot instantiate
(GDScript.can_instantiate() is tool-gated there), so any instance-reflection channel lists nothing
exactly where this feature runs - headless tests and harnesses pass while the editor shows an
empty subgroup. Entries come from get_script_property_list (exported knobs),
get_script_method_list (value-returning public methods), and the `## @ace_*` annotations read
from SOURCE (@ace_hidden / @ace_internal exclude; publishing needs @ace_expression or a
pack-level @ace_expose_all). Per-script members are cached on path|mtime - the registry's own
cache discipline - so only the first derivation after a save pays.

### Procedural robustness (runtime-attached behaviours)

`$PlatformerMovement` assumes an editor-attached child with the default name. A behaviour attached
via `add_child()` at runtime may carry an auto-generated name, so:

- Every Behaviours insertion is subject to the existing fragile-node-path Doctor check
  (`project_doctor.gd` `check_fragile_node_paths`) exactly like a hand-typed path - no exemption.
- A **Robust behaviour lookups** checkbox in the dictionary window (SHIPPED as a window-level
  toggle rather than the per-entry context menu first sketched here - one visible switch beats a
  hidden menu) swaps every behaviour fragment to `get_node_or_null("PlatformerMovement")`. It
  DEFAULTS ON when the sheet is spawn-heavy (`is_spawn_heavy`: Spawn verbs or the ObjectPool
  vocabulary anywhere in its rows), re-derived on every open, user-overridable per session.
- Group-based addressing stays the recommended pattern for spawned OBJECTS (SpawnSceneFull's Group
  param + the group query lane); Self never pretends to reach them - see Non-goals.

### Resource-host sheets

`host_class` extending Resource: Properties reflect the resource's exported fields, Variables and
Functions work unchanged, and the Behaviours subgroup does not render (a Resource has no children).
Because every subgroup is derived, this needs no special-casing - the section self-adjusts.

## Search aliases

The picker's phrase bridge (`ace_picker.gd` `_synonyms` + `register_synonyms`) gains the Self
aliases, so `self.x`, `Self.X`, and `platform vectorx` rank the right entry in the expression
picker, Quick Add, and the Ghost Row alike. Packs can extend the bridge for their own expressions
through the already-public `EventSheets.register_quick_add_synonyms`.

## Non-goals (each one guards a standing contract)

- **No new frozen ace_ids.** Aliases never become descriptors; nothing joins the compatibility
  promise. A future redesign orphans nothing.
- **No `Self` token in emitted GDScript.** Insertion is always plain code; compiler, importer and
  the byte-exact round-trip never see this feature.
- **No re-binding inside loops.** C3's `Self` re-binds to the looped instance; here the loop
  element already has a NAME. The Loop row surfaces that name - it never aliases `Self` to it.
- **No reaching spawned/picked objects.** Self is the owner of the sheet, as in C3. Other objects
  are the For Each / group-query lane's job.
- **No hand-maintained property catalog.** Reflection + the small override table only.

## Testing plan

The section model builds in a static pure function (sheet + host_class + optional grounded node ->
section dict), so it is headless-testable like `collect_anatomy`:

- Pin VALUES, not counts: `X` maps to `position.x`, `Opacity` to `modulate.a`.
- Host gating: a `Node` host publishes no X; a `Control` host publishes Width/Height and no Angle.
- Variables/Functions: a sheet with one exported var, one internal var and one expression function
  publishes exactly those names; a bool-returning function does NOT appear (it is a condition).
- Resource host: Behaviours subgroup absent; exported fields present.
- Fallback tier: a sheet whose events call `$X/Sine.amplitude` lists Sine under Uses-first packs.
- Robust form: the spawn-heavy predicate flips the default insertion to `get_node_or_null`.
- Alias search: the synonym bridge resolves `self.x` to the X entry.
- UI lands with a render preview per house rule.

## Phasing

1. **Phase 1 - Variables / Properties / Functions + aliases** - SHIPPED. Pure derivation, the
   override table, pinned section, search bridge.
2. **Phase 2 - Behaviours + Host + robust lookups** - SHIPPED. The Behaviours subgroup builds
   `$Pack.member` chains ONLY from clean reflection metadata (source_kind property/method) - a
   baked multi-line template cannot be represented as a chain, so it is skipped rather than
   guessed, and deliberately NOT the compiler's `__eventsheet_provider_*` owned-instance seam
   (Self teaches the attached-child access the README teaches). Used packs lead expanded, the
   rest trail collapsed. Inserted chains leave the node token SELECTED (the `$Name` span, or the
   quoted name inside get_node_or_null) so retargeting is one keystroke or a node drag. The
   derivation is cached per dialog-open (typing only re-filters; re-deriving 76 packs per
   keystroke measured ~25ms on a 300-row sheet, so the cache keys on the robust toggle and
   clears on open).
3. **Phase 3 - grounding** - SHIPPED (selected-node tier). The end-to-end editor drive that
   verified it also caught the instance-reflection channel being editor-dead (see the Behaviours
   section) and forced the script-level derivation both tiers now share.
4. **Phase 4 - LIVE grounding** - SHIPPED. While a Live Values session streams, opening the
   dictionary sends `eventsheets:query_children` with the sheet's script path; the emitted debug
   receiver (the SAME one Live Values ships - one per game, first streaming sheet wins) walks the
   running tree, and the first instance running that script reports its behaviour children -
   REAL runtime names, including behaviours attached at runtime, which no edit-time tier can
   see. The reply upgrades the subgroup asynchronously to "Behaviours (live · on <owner>)"
   (+ "1 of N running" when instances repeat); a report for another sheet or a closed dialog is
   dropped. Requires the sheet's Live Values toggle (the feature literally rides that channel);
   no session degrades to the selection/fallback tiers silently. The debug machinery lives in
   the compiled output and round-trips byte-identically as content (suite-pinned), and a normal
   compile carries none of it (the covenant, also pinned). Verified in two REAL halves meeting
   at the same wire payload: the emitted census run against a live scene tree with a
   runtime-attached behaviour (direct game harness), and the editor pipeline (wiring, parse,
   upgrade, staleness guard) driven inside the real editor - the editor-launches-child-game hop
   itself is not automatable in this sandbox (child processes never spawn; the repo's runtime
   smokes avoid editor-launched games for the same reason), and its two primitives
   (EngineDebugger.send_message / EditorDebuggerPlugin._capture) are the ones Live Values
   already ships on.

## Resolved questions

- The HOST of a behaviour pack sheet DOES get its own subgroup (shipped in Phase 2): in behaviour
  mode a **Host** subgroup re-aims the same C3 commons through the `host` binding every behaviour
  carries (`X · host.position.x`) - the behaviour author is the second audience with C3 muscle
  memory, and their "my object" is the parent.

## Open questions

- Whether typing `Self.` should literally autocomplete inline (LSP-style) rather than open the
  picker - deferred until the picker-first version proves the derivation model.
