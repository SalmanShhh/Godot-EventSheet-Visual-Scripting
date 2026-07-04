# SPEC: v0.11 Roadmap - Localisation, Inspector UX, Regions, Terse Providers, Any-Node Reach

Status: DRAFT for review (2026-07-04). Five features scoped for the next release, each grounded
in a census of the code as it stands at v0.10.0. Every chapter states what exists today (with
file references), the design, phased delivery with acceptance gates, and the contracts it must
not break (lossless byte round-trip, parity/no-runtime, deterministic emission, frozen ace_ids).

Contents:

1. [Localisation, the Godot way](#1-localisation-the-godot-way)
2. [Inspector property design UX for beginners](#2-inspector-property-design-ux-for-beginners)
3. [Collapsible region markers](#3-collapsible-region-markers)
4. [Terse ACE providers + script-editor autocomplete](#4-terse-ace-providers--script-editor-autocomplete)
5. [Any-node vocabulary via ClassDB reflection](#5-any-node-vocabulary-via-classdb-reflection)
6. [Suggested build order](#6-suggested-build-order)

---

## 1. Localisation, the Godot way

### Today (census)

- Zero localisation surface: no `tr()`, `atr()`, `TranslationServer`, `.po`/`.csv`, or POT
  references anywhere in `addons/`, `eventsheet_addons/`, or `demo/`. The C3 migration guide
  routes i18n to "use Godot directly" (Lane 3).
- String params flow: `ACEParam` (addons/eventforge/resources/ace_param.gd) has
  `id/display_name/type_name/hint/options/autocomplete` and **no per-param metadata dict**.
  String literals are quoted by `_to_code_literal()` (sheet_compiler.gd:2202) and substituted
  raw into codegen templates (action_codegen.gd:77).
- Text-producing ACEs: the Print family (dev_aces.gd), the ConsoleLog family (console_aces.gd),
  `SetLineEditText` (ui_aces.gd:64), `PushWarning/PushError/Assert` message params.
- The param dialog builds a bare `LineEdit` for plain strings (ace_params_dialog.gd:289) with
  no per-param toggle surface.

### The key insight

A sheet IS a `.gd` file. Godot's own localisation pipeline (Project Settings > Localization >
POT Generation) scans `.gd` files for `tr()` calls, extracts them to a POT template, and
`TranslationServer` swaps locales at runtime with zero code support. So EventSheets does not
need a translation runtime, a string table, or an export format: **if the compiler emits
`tr("Text")`, every Godot tool downstream works unchanged**, and the parity covenant
(plain GDScript, no plugin dependency) is preserved for free.

### Design

**1a. A "translatable" mark on string params.** Add a general `metadata: Dictionary` field to
`ACEParam` values as stored on rows (NOT on the shared immutable definitions; the flag lives in
the row's params payload alongside the value, the same way `{uid}` bakes at apply time). In the
param dialog, string fields whose hint is not `expression` gain a small globe toggle button
next to the LineEdit (sibling of the ƒx button pattern, ace_params_dialog.gd:268). Toggled on:

- codegen wraps the quoted literal: `print(tr("Spawned"))` instead of `print("Spawned")`
- the row cell renders the value with a small globe glyph so translatable text is scannable

**1b. Lossless lift.** The importer's expression parser learns one shape: `tr("...")` (and
`tr("...", "context")`) around a string literal lifts back to value + translatable flag
(+ context). Byte-gated like every lift: if re-emission is not byte-identical, the expression
stays verbatim. This is a small, deterministic template, same family as existing helper lifts.

**1c. Context and plurals, progressive.** The globe toggle's popover (not a new dialog) offers
two optional fields: "Context" (emits the two-arg `tr`) and, for messages that embed a count,
a plural pair that emits `tr_n("%d apple", "%d apples", count)`. Both collapsed by default.

**1d. A tiny Translation vocabulary** (new builtin module `translation_aces.gd`, ~6 ACEs):

| ACE | Emits |
|---|---|
| Set Locale (action) | `TranslationServer.set_locale({locale})` |
| Get Locale (expression) | `TranslationServer.get_locale()` |
| Translate (expression) | `tr({text})` for dynamic keys |
| Translate With Context (expression) | `tr({text}, {context})` |
| Translate Plural (expression) | `tr_n({singular}, {plural}, {count})` |
| On Locale Changed (trigger) | `NOTIFICATION_TRANSLATION_CHANGED` via `_notification` |

The trigger compiles to a `_notification(what)` match arm; the pairing spec already emits
engine-virtual handlers, so this follows the existing trigger_resolver pattern.

**1e. Doctor + docs.** A Project Doctor check: "sheet emits tr() but the project has no
locales/POT files configured" nudges to Project Settings. A docs page ("Translating your game")
walks: mark strings > generate POT (Godot UI) > add .po/.csv > Set Locale action. Document the
sharp edge: variable DEFAULTS must not wrap in `tr()` (translations are not loaded when
declarations initialize, and `@export` defaults are data); translatable belongs at usage sites,
which is where the toggle lives.

### What this deliberately does not do

No editor-authored string tables, no CSV writer, no locale preview inside the sheet (Godot's
own tooling owns those). No auto-marking of every string (false positives on group names,
action names, node paths would poison the POT).

### Phases + gates

- **P1**: metadata seam on row params + globe toggle + `tr()` emission + byte-gated lift +
  round-trip tests (mark, compile, reopen, byte-identical; unmarked sheets byte-unchanged).
- **P2**: context/plural popover + the Translation module + trigger + codegen parity tests.
- **P3**: Doctor check + guide + a translated demo (the platformer starter with an `es` locale)
  proving POT extraction picks the emitted strings up.

Risks: none to frozen APIs (new module, new optional metadata). The one contract to watch:
params metadata must ride the snapshot-duplicate undo funnel like all row state.

---

## 2. Inspector property design UX for beginners

### Today (census)

- `variable_dialog.gd` is 1,457 lines with shipped T0/T1/T2 progressive disclosure: T0 always
  (Name/Type/Default), T1 "More options" (tooltip, range, drawer picker + live preview,
  type-gated checkboxes, slider extras, the 20-preset "Inspector look" dropdown, the live
  "Ships as:" strip fed by the compiler's own `_structured_hint_prefix()`), nested T2
  "Advanced" (group/subgroup, show-if, lock-unless, on-changed, clamp, read-only).
- 39 distinct authorable options across 9 hint families + 5 drawers; full-export-coverage spec
  is complete with no open tail.
- Gaps that matter for a beginner: the **"Inspector look" picker is a words-only dropdown**
  (20 labels like "Checkbox flags (Fire, Ice...)"), the beginner must already know what they
  want; **Simple Mode does not touch this dialog at all** (it only filters the ACE picker and
  menus); grouping is drag-only with T2 text fields as the fallback; and there is no single
  picture of "what will my Inspector actually look like".

### Design

The theme is: **choose by picture, not by vocabulary.** A beginner recognizes a slider; they do
not know the phrase "range with or_greater".

**2a. The Look Gallery (new dialog, the "break it down more" ask).** A button in T1 next to
the Inspector-look dropdown: "Browse looks..." opens a gallery dialog (EventSheetPopupUI card
grid): one tile per look, each tile = a **rendered miniature of the real Inspector widget**
(slider, flags grid, layer matrix, file field, color-no-alpha swatch, progress-bar drawer...)
+ its plain name + one sentence. Type-filtered like the dropdown (an int shows int looks).
Clicking a tile applies the same `_fold_look_attributes()` path the dropdown uses today; the
dropdown stays for users who know the words. Tiles for looks that need details (flag names,
file filters) open with the Details field focused. Implementation note: tiles are cheap - the
drawer preview widgets already exist (drawer preview box, variable_dialog.gd:277), and
non-drawer looks render with stock Controls (HSlider, CheckBox grid, LineEdit with folder icon)
so no EditorInspector embedding is required.

**2b. The Inspector Preview card.** Above "Ships as:", a small always-live panel that mocks the
final Inspector rows: the group header ("Combat"), subgroup indent ("Defense"), the property
name, and the chosen widget with the current default value. One glance answers "what will this
look like in Godot". It reuses the gallery's widget renderers; "Ships as:" stays as the
code-truth line under it (picture for beginners, annotation for experts, same source of truth).

**2c. A plain-sentence summary.** Under the preview: "A whole number from 0 to 100, shown as a
progress bar, grouped under Combat > Defense." Generated from the attributes dict by a small
`_describe_attributes()`; doubles as the accessibility/tooltip string. C3-first language.

**2d. Simple Mode finally reaches this dialog.** In Simple Mode: T2 "Advanced" is hidden
entirely (its six fields are wiring, not looks), the look gallery replaces the dropdown as the
primary surface, and the friendly types stay pinned. Expert mode unchanged. This is a display
gate only - attributes already set on a variable still round-trip untouched (the export
coverage covenant).

**2e. Grouping discoverability.** Keep drag as the primary gesture; add "New group from
selection..." to the variables context menu (writes the same attributes the drag writes), so
the feature is discoverable without knowing the gesture.

### Phases + gates

- **P1**: Look Gallery dialog + tile renderers + apply path shared with the dropdown; render
  a preview image (house rule) and a gallery test pinning tile count == filtered preset count.
- **P2**: Inspector Preview card + plain-sentence summary (unit-test the sentence builder
  against a value matrix, pin SENTENCES not counts).
- **P3**: Simple Mode gates + context-menu grouping; docs (INSPECTOR-DRAWERS-GUIDE gains the
  gallery walkthrough); progressive-disclosure spec updated to mark the audience axis done.

Risks: dialog line count (already 1,457; the gallery and preview land as new
`dock/look_gallery_dialog.gd` + `dock/inspector_preview_card.gd` RefCounted helpers per the
established delegate pattern, not inline). No compiler changes at all in this chapter.

---

## 3. Collapsible region markers

### Today (census)

- The `region` block kind shipped with the Custom Block API (block_registry.gd:283): emits
  `#region Label` / `#endregion`, lifts byte-gated, renders as a flat SECTION row with a badge.
  Fences are two independent single-line blocks; "unbalanced fences are a readability wart,
  never a parse error" is the stated contract.
- Folding machinery already exists and is proven: `EventRowData.folded` + `children`,
  `_fold_state[row_uid]` (session dict, event_sheet_viewport.gd:173), fold arrows with click
  hit-testing, KEY_LEFT/KEY_RIGHT fold/unfold, and `_flatten_row()` skipping children of
  folded rows (event_sheet_viewport.gd:2234). Groups and scaffold rows use it today.
- Missing: fences are not paired, so a region cannot fold; no Fold All/Unfold All; fold state
  does not persist anywhere.

### Design

**3a. Pair fences in the view layer only.** During row building (viewport_row_builder.gd), a
stack-based pass pairs each `region` CustomBlockRow with its matching `is_end` fence at the
same nesting level. The rows between them become the opening row's **visual children** (the
same parent/child shape groups already use), which makes folding work through the existing
`folded`/`_flatten_row` machinery with no new mechanism. The data model does NOT change: the
sheet still stores flat fence rows, emission is untouched, and the byte round-trip cannot be
affected by construction. The closing fence row hides while its opener is folded and renders
dimmed at the bottom of the range when unfolded. Stack pairing gives nesting for free
(regions inside regions, regions inside groups). Unbalanced fences simply do not pair and stay
flat rows - the wart-not-error contract survives.

**3b. Folded rendering like the script editor.** A folded region row renders as
`▸ Combat ... 12 rows` (label + hidden-count chip, reusing the group fold styling tokens).
Search (`reveal_resource()`, event_sheet_viewport.gd:948) already unfolds ancestors; because
regions fold through the same machinery, find/breakpoint/error-jump reveal works unchanged.

**3c. Commands + gestures.**

- Command Palette: "Fold All Regions", "Unfold All Regions", "Fold All" (regions + groups).
- Ctrl+Shift+[ / Ctrl+Shift+] fold/unfold the region containing the selection (script-editor
  muscle memory); KEY_LEFT/RIGHT keep working since a paired region is just a foldable row.
- "Surround with Region..." on the multi-select context menu: inserts the fence pair around
  the selected rows through one `_perform_undoable_sheet_edit` (one undo step), prompting for
  the label inline (the group-naming popup pattern).
- The Add menu already lists "Add Region..." via the registry; add-with-selection is the only
  new insertion path.

**3d. Persist fold state, but never in the bytes.** Fold state must survive reopen without
touching the `.gd` (lossless covenant: a fold is editor state, not code). Store
`{sheet_path: {region_uid_or_label_hash: folded}}` in the plugin's existing editor-state home
(the same layer that remembers recent sheets/open tabs), pruned when sheets vanish. Groups'
`is_collapsed()` stays authoritative for groups; this layer covers regions (and can adopt
scaffold rows later). Multi-view: fold state stays per-viewport as today; only the on-open
seed comes from the persisted layer.

### Phases + gates

- **P1**: pairing pass + fold-through-existing-machinery + folded-count rendering; tests: pin
  the paired tree shape for a fixture (region > rows > endregion), pin that an unbalanced
  fence file builds flat and byte-round-trips unchanged, pin that folding is skipped in
  `_flatten_row` output; preview image.
- **P2**: commands, shortcuts, surround-with-region (undo-tested), palette entries
  (registry-driven count pin already exists in godot_workflow_test - update via
  `addable_kinds()` pattern, pin VALUES).
- **P3**: fold persistence + reveal-on-search regression tests.

Risks: the pairing pass must run after every rebuild (rows are REPLACED by snapshot duplicates
on undo commits; never cache row references, re-pair from the live sheet each build - the
established rule). Fence pairing must key on row identity (`row_uid`) not label text, since
labels duplicate.

---

## 4. Terse ACE providers + script-editor autocomplete

### Today (census)

- A fully-dressed action costs 8-10 lines: seven-plus `## @ace_*` doc-comment lines
  (name, category, description, icon, display_template, codegen_template, per-param hints)
  above the func (real examples: demo_health_addon.gd heal = 9 lines; timer_behavior.gd
  start_timer = 7).
- The scanner already auto-derives a lot: unannotated public members type-infer (void func =
  action, bool = condition, other returns = expression, signal = trigger), names humanize
  from snake_case, `@ace_expose_all(node)` synthesizes `$Class.method({params})` templates
  with zero per-method annotations, `@export var` fans out to read/set/add ACEs.
- Annotations are `##` doc comments parsed by semantic_analyzer.gd; there is NO autocomplete
  for them in Godot's script editor (comments get no completion; the repo's
  `editor/autocomplete/` dir is empty), and unknown `@ace_` tokens are silently ignored.
- The ACE Studio (function dialog) authors SHEET functions; it never writes provider
  annotations.

### Design

Two complementary tracks: make the comment dialect smaller, and offer a typed alternative that
gets autocomplete for free because it is real GDScript.

**4a. Fewer lines in the comment dialect (additive; the existing forms are frozen API).**

- **The doc comment IS the description.** Any plain `##` prose line above a member becomes the
  ACE description when `@ace_description` is absent. This deletes the most common annotation
  line and rewards writing normal GDScript docs (they also show in Godot's help).
- **One-line param spec**: `## @ace_param(amount, hint: expression, options: a|b|c)` collapses
  hint + options + autocomplete + description per param into one annotation (existing
  `@ace_param_hint`/`_options`/`_autocomplete` keep working).
- **Pack-level defaults**: `@ace_category` and `@ace_icon` at class level become the default
  for every member (member-level overrides win). A pack with one category today repeats it on
  every verb.
- **Convention-derived hints**: a param typed `Color` defaults to the color hint; `NodePath`
  to the node picker; names ending `_anim`/`_animation` to animation_reference; `_signal` to
  signal_reference. Documented table, overridable, OFF for params that already carry a hint.
- Net effect: the demo heal action drops from 9 lines to 3
  (`## Restores health by an amount.` + `## @ace_codegen_template("health += {amount}")` +
  the func), and to 2 when the template is derivable.

**4b. A typed, autocompleting registration API.** Autocomplete inside comments is not
extensible in Godot (no public completion hook for comment dialects), so stop fighting it:
offer a fluent builder on the existing bridge (the `register_block_kind` sibling):

```gdscript
static func _eventforge_register(reg: EventForgeRegistrar) -> void:
	reg.action("heal").name("Heal").category("Health")\
		.description("Restores health by an amount.")\
		.template("health += {amount}")\
		.param("amount", reg.EXPRESSION)
```

Every method is typed, so the script editor autocompletes the whole vocabulary natively, hints
argument types, and typos are compile errors instead of silently-ignored comments. The scanner
detects the static hook the same way pack kinds are detected (base-chain walk, no
instantiation), and the builder produces the same ACEDefinitions the comment dialect does -
one test pins builder-vs-annotation equivalence for a twin fixture. Comment dialect remains
the zero-ceremony default; the builder is for authors who want tooling.

**4c. Author-time safety net (the cheap autocomplete substitute).**

- The scanner warns on **unknown `@ace_*` tokens** (Doctor + import-time lint): today
  `@ace_categry` silently vanishes; that is the worst authoring papercut and costs one
  dictionary lookup.
- **"Copy annotation block"**: the picker's ACE context menu and the vocabulary doc gain a
  copy-ready annotated stub for any existing ACE (learn by example, paste, edit).
- **Script templates**: ship `script_templates/Node/eventforge_provider.gd` (Godot picks
  these up in the New Script dialog) containing a commented skeleton of the dialect, so a new
  provider file starts with the vocabulary in front of the author.
- The ACE Studio "New Behaviour Addon" scaffold adopts the terse dialect in what it generates.

### Phases + gates

- **P1**: doc-comment-as-description + pack-level defaults + unknown-token warning; regenerate
  packs (builders adopt terser output) and hold drift=0 with byte-identical emitted ACEs -
  the definitions must not change, only the source lines that declare them; suite pins
  description-from-prose and override precedence.
- **P2**: one-line `@ace_param` + convention hints (equivalence-pinned against the long forms).
- **P3**: the typed registrar + equivalence fixture + guide chapter; script template +
  copy-annotation-block.

Risks: the dialect is public API - every change is additive, never a rename; precedence rules
(member > class > convention > inference) must be spelled out in CUSTOM-ACES-GUIDE and pinned
by tests. Convention hints must not re-type params on existing packs (gate: pack audit stays
drift=0 and Lens A == Lens B).

---

## 5. Any-node vocabulary via ClassDB reflection

### Today (census)

- Vocabulary is 18 hand-authored builtin modules; an ACE binds to a class via a `node_type`
  string on the descriptor (picker grouping) and `{target.}` prefix injection (builtin_aces.gd:34).
- A node class without dedicated vocabulary (GraphEdit today; anything Godot 4.8 adds
  tomorrow) falls to the Helpers escape hatch: `SetProperty`/`GetProperty`/`CallMethod`/
  `OnSignal` - all bare-identifier, string-typed, no validation, no browsing ("what can this
  node do?" has no answer in the picker).
- `ClassDB` is used exactly once (`class_exists` fallback, sheet_compiler.gd:164). Reflection
  lists (methods/properties/signals) are never consulted.
- Reverse-lift matches known templates only: `graph.arrange_nodes()` stays a raw line forever.

### Design

**Reflect the class, on demand, through the pipeline that already exists.** The provider
scanner already turns typed GDScript members into ACEs (types from signatures, humanized
names, synthesized `{target.}method({params})` templates). Chapter 5 feeds that same
generator from `ClassDB` instead of a script:

**5a. A reflected-vocabulary source (`classdb_ace_source.gd`).** Given a class name, produce
descriptors from:

- `ClassDB.class_get_method_list()`: non-virtual public methods; `void` returns become
  Actions, `bool` returns Conditions, others Expressions; param names/types/defaults come from
  the method dict; template is `{target.}method({params})` - exactly the shape helpers emit
  today, but typed and picker-browsable.
- `ClassDB.class_get_property_list()` (editor-usage properties): Set/Get pairs (typed
  `{target.}prop = {value}` / `{target.}prop`).
- `ClassDB.class_get_signal_list()`: picker-listed triggers riding the existing generic
  `OnSignal` machinery (trigger_resolver already compiles arbitrary signal connections), which
  also upgrades OnSignal from type-blind to validated (the census's "silently fails at
  runtime" edge: unknown signal names warn at apply time via `class_has_signal`).

Because emission is plain calls on the target, **parity is untouched and new engine classes
work the day a Godot build ships them** - the vocabulary is derived from the running engine,
which is precisely how GDScript itself keeps up. User `class_name` scripts reflect through
`Script.get_script_method_list()/get_script_signal_list()` on the same generator path.

**5b. Picker UX: browse, do not flood.** ClassDB has ~900 classes; reflected vocabulary must
be pull, not push:

- When an event's target (or the sheet's `host_class`) resolves to a class, the picker grows
  one section: "All of GraphEdit" (class icon, inheritance-walked so Node methods appear under
  "All of Node"), collapsed by default, search-included.
- The node picker already captures `node.get_class()` on pick (ace_params_node_picker.gd:184);
  carrying that class through to the params dialog gives property/method/signal **name
  dropdowns with real autocomplete** on the existing Helper ACEs too (hint upgrade:
  `property_reference`/`method_reference` hints become class-aware).
- Simple Mode hides reflected sections entirely (they are the expert deep end).

**5c. Caching + immutability.** Reflection output is cached per class per session in the
static registry cache (the `path|mtime|length` pattern degenerates to `classdb|<class>|<engine
version>`); definitions stay immutable post-generation like every ACEDefinition (bake into row
copies only). Cold cost is bounded by lazy, per-class generation (only classes the picker
actually opens).

**5d. Round-trip stance (the honest part).** Reflected ACEs are apply-time sugar: they emit
the same plain lines helpers emit. Reverse-lift of arbitrary method calls stays CONSERVATIVE:
a line lifts to a reflected ACE only when the target's static class is resolvable in the sheet
(typed host, `%Unique` with scene open, autoload) AND re-emission is byte-identical; otherwise
it remains a raw/helper row exactly as today. No guessing: the lossless covenant outranks
lift coverage, and this spec does not promise `graph.arrange_nodes()` round-trips as a
reflected row in v0.11 - it promises the FORWARD path (browse, pick, typed params, valid
signals) for every class.

### Phases + gates

- **P1**: reflected source for methods/signals + picker section + session cache; tests: pin a
  GraphEdit fixture (method count sanity via >= floor, one exact descriptor VALUE pin),
  codegen parity (reflected Set Position == hand-written line), immutability pin
  (two registries share instances).
- **P2**: property Set/Get pairs, class-aware name dropdowns on the helpers, OnSignal
  validation warning; params-dialog UX pass.
- **P3**: user `class_name` reflection + Simple Mode gate + docs ("Every node speaks
  EventSheet") + a showcase using a vocabulary-less class end to end.

Risks: engine-version drift in tests (pin floors and single known-stable members, never exact
counts); picker performance (lazy sections, no eager 900-class scan); duplicate shadowing
(a reflected `move_and_slide` must NOT shadow the curated CharacterBody2D ACE - curated
modules always win; reflected entries for members a curated ACE already covers are filtered by
codegen-template equality, mirroring how helper_aces registers LAST for the same reason).

---

## 6. Suggested build order

| Order | Chapter | Why this slot |
|---|---|---|
| 1 | 3 Regions | Smallest; rides existing fold machinery; instant daily-use payoff |
| 2 | 4 Provider terseness P1 | Unblocks nicer packs early; drift gate keeps it honest |
| 3 | 1 Localisation | Compiler seam is small; big headline value; independent of the rest |
| 4 | 2 Inspector gallery | Pure editor UX; benefits from 4's scaffold updates landing first |
| 5 | 5 Any-node reflection | Largest; P2 of it reuses the params-dialog work from 2 |

Cross-cutting gates for every chapter: full suite green (verdict line, not FAIL grep), pack
audit drifted=0, byte round-trip fixtures for anything touching emission or lift, a CHANGELOG
entry per landed slice, and a rendered preview image for each UI surface.
