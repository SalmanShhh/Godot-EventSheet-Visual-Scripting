# EventSheet Editor Parameter Exposure Status

> Reviewed 2026-06: all items below are implemented (the final two landed with the
> inspector-polish phase — widget_hint editors and the per-row "Selected ACE" section).

This checklist tracks the current branch against the provided **EventSheet Editor Param Exposure Spec**.

- [x] Dynamic inspector properties continue to use `_get_property_list()` / `_get()` / `_set()` (`EventSheetExposedNode`)
- [x] Exposed properties are now scoped to active sheet providers instead of listing the full registry blindly
- [x] `EditorParamStore` remains the serialized override source and now emits change signals for editor refresh
- [x] Inspector-driven `_set()` edits now register undo/redo actions when either `EditorUndoRedoManager` or `UndoRedo` is provided
- [x] `ParamDefaultResolver` remains the value-priority layer (row > editor override > ACE default > zero-value)
- [x] `ACEDefinition` / generator exposure metadata handling expanded for `editor_exposed`, hints, widget hint, and category override
- [x] Inspector plugin registration is now wired in the plugin lifecycle (`add_inspector_plugin` / `remove_inspector_plugin`)
- [x] Registry refresh now triggers exposed-node refresh so property surfaces react to hot-reload updates
- [x] Store serialization round-trip is covered by tests (including falsy overrides `0`, `false`, `""`)
- [x] ACE picker/params surfaces now carry ACE descriptions/tooltips, and combo-like params can persist stable option keys
- [x] Trigger ACE metadata now explicitly marks a captured-context trigger-state model for runtime/compiler follow-through
- [x] Custom inspector widgets per `widget_hint` (slider/range, multiline, expression — defaults otherwise)
- [x] Per-row scoped UI: the selected condition/trigger/action's params surface as live "Selected ACE" inspector properties (undoable via the dock)

### C3-guided interpretation used in this pass

- ACE IDs are treated as stable serialized API identifiers (`signal:*`, `method:*`, `property:*`, etc.).
- Trigger/condition/action/expression separation remains explicit in metadata and picker filtering.
- Trigger ACE metadata now includes `trigger_state_model = "captured_context"` as the runtime/compiler contract.
- Parameter metadata is carried with IDs/display names/defaults/options/hints so picker, dialogs, inspector, and future runtime can share one contract.
- Full deprecated ACE migration UI is deferred to the next phase, but metadata hooks remain available for compatibility expansion.
