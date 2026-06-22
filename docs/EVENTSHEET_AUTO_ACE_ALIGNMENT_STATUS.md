# Auto-ACE Alignment Status

> **Historical record (early era).** This document predates the overhaul arcs and the
> v0.5/v0.6 feature waves — treat its claims as a design-time snapshot, not current
> behavior. Current truth: `CHANGELOG.md`, `README.md`, and the maintained specs in
> `docs/` (GDSCRIPT-PAIRING-SPEC, the per-feature specs).


> Updated 2026-06. The detailed design lives in `docs/GDSCRIPT-PAIRING-SPEC.md`
> ("Zero-config addons", "Expose-as-ACE sheet functions", "Instance-backed ACEs").

This tracks the Auto-ACE goal: gameplay vocabulary appears in the picker automatically,
from code, with zero manifests.

## Implemented

- **Zero-config addons**: any script in `res://eventsheet_addons/` becomes a provider —
  `class_name` is the provider name, the top `##` comment its description, and `@ace_*`
  annotations (`name`/`category`/`description`/`icon`/`display_template`/
  `codegen_template`/`param_hint`/`hidden`) shape everything else. Annotated signals
  become triggers (and compile to real `_ready` connections).
- **Code registration**: `EventForgeBridge.register_script_as_provider(path)` lets other
  plugins/tools add providers without touching the folder.
- **Template-less methods still compile**: instance-backed ACEs synthesize a direct call
  through an owned provider instance (`__eventsheet_provider_<Class>.method(...)`) — no
  silent no-ops, and no EventForge classes in the output (parity contract).
- **Sheets feed the vocabulary back**: behavior/custom-node sheets with `expose_as_ace`
  functions compile WITH `@ace_*` annotations, so compiled sheets are themselves
  providers (the sheet → script → addon loop), icons included.
- Reflection + annotation overrides, category inference, node-type grouping, picker and
  row-cell icons, codegen tooltips, and baked templates (applied ACEs compile standalone,
  e.g. inside shared snippets).

## Partial

- Registry refresh covers practical hot-reload; an automatic file watcher with instant
  refresh remains a nicety.

## Missing

- Expression autocomplete in ƒx fields (live compile-check validation exists; completion
  popups are planned polish).
