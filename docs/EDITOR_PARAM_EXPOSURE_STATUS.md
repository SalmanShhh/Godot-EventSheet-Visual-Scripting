# EventSheet Editor Parameter Exposure Status

This checklist tracks the current branch against the provided **EventSheet Editor Param Exposure Spec**.

- [x] Dynamic inspector properties continue to use `_get_property_list()` / `_get()` / `_set()` (`EventSheetExposedNode`)
- [x] Exposed properties are now scoped to active sheet providers instead of listing the full registry blindly
- [x] `EditorParamStore` remains the serialized override source and now emits change signals for editor refresh
- [x] Inspector-driven `_set()` edits now register undo/redo actions when an undo manager is available
- [x] `ParamDefaultResolver` remains the value-priority layer (row > editor override > ACE default > zero-value)
- [x] `ACEDefinition` / generator exposure metadata handling expanded for `editor_exposed`, hints, widget hint, and category override
- [x] Inspector plugin registration is now wired in the plugin lifecycle (`add_inspector_plugin` / `remove_inspector_plugin`)
- [x] Registry refresh now triggers exposed-node refresh so property surfaces react to hot-reload updates
- [ ] Custom inspector widgets per `widget_hint` (current pass keeps default inspector controls)
- [ ] Advanced per-row scoped override UI beyond the base dynamic property integration
