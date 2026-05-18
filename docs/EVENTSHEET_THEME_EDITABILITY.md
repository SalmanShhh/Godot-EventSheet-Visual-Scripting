# EventSheet Theme + Editability Guide

This editor uses Godot-native resources/scenes (not CSS) so designers can edit visuals directly in the Inspector/scene editor.

## Core model

- `EventSheetEditorStyle` (`.tres`) is the active theme definition resource.
- Element templates are scene files in `res://addons/eventsheet/elements/`:
  - `event_visual_element.tscn`
  - `condition_visual_element.tscn`
  - `action_visual_element.tscn`
- These scenes are linked by `EventSheetEditorStyle.event_visual_scene`, `condition_visual_scene`, and `action_visual_scene`.

## Editing flow for designers

1. Open one of the element `.tscn` files in Godot.
2. Edit colors, text style, spacing, and preview nodes visually.
3. Save the scene.
4. Open/create an `EventSheetEditorStyle` resource and point scene references to your element scenes if needed.
5. Assign that style to `EventSheetResource.editor_style` (or load via toolbar).

## Switching themes

- Toolbar actions in the EventSheet dock:
  - **Load Theme**: pick an `EventSheetEditorStyle` resource.
  - **Default Theme**: clear per-sheet override and use built-in defaults.
  - **Reload Theme**: reload the active style from disk.

## Custom theme import/install

- Copy a custom `EventSheetEditorStyle` `.tres` into the project (for example under `res://demo/themes/` or `res://addons/eventsheet/theme/`).
- Use **Load Theme** and pick the file.
- Save the sheet to persist the selected style with that EventSheet resource.

## Hot-reload behavior

- When the active style resource changes in-editor, the dock refreshes the viewport.
- `Reload Theme` forces a reload from disk for external file edits.

## Why no CSS file

Godot’s practical equivalent is Resource + Scene authoring:

- visual editing in `.tscn`
- structured style data in `.tres`
- editor/runtime resource loading and switching

This preserves the user intent of designer-friendly theming while staying native to Godot tooling.
