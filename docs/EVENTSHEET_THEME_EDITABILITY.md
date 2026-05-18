# EventSheet Theme + Editability Guide

This editor uses Godot-native resources/scenes instead of runtime CSS. The goal is still the same as a Construct-style theme.css workflow: designers can duplicate a theme package, tune tokens, reload the editor, and keep shipping reusable presets.

## Core model

- `EventSheetEditorStyle` (`.tres`) is the active installable theme package.
- `EventSheetEventStyle` owns sheet/event/group/comment/interaction tokens.
- `EventSheetElementStyle` owns condition/action entry tokens.
- Element templates are scene files in `res://addons/eventsheet/elements/`:
  - `event_visual_element.tscn`
  - `condition_visual_element.tscn`
  - `action_visual_element.tscn`
- These scenes are linked by `EventSheetEditorStyle.event_visual_scene`, `condition_visual_scene`, and `action_visual_scene`.

## Editing flow for designers

1. Duplicate `res://demo/themes/designer_template_theme.tres`.
2. Optionally duplicate `res://demo/themes/designer_template_theme_manifest.cfg` so the package keeps its token notes.
3. Edit the `.tres` resource in the Inspector for structural tokens such as sheet background, group/comment styling, and hover/selection fills.
4. Open one of the element `.tscn` files in Godot when you want a more visual preview for lane and chip styling.
5. Save the scene/resource.
6. Assign the style to `EventSheetResource.editor_style` or load it through the dock toolbar.

## Switching themes

- Toolbar actions in the EventSheet dock:
  - **Load Theme**: pick an `EventSheetEditorStyle` resource.
  - **Default Theme**: clear the per-sheet override and use built-in defaults.
  - **Reload Theme**: reload the active style from disk.
  - **Rebuild Theme**: regenerate `event_style` / `condition_style` / `action_style` from the linked visual `.tscn` templates and refresh the active sheet.

### Bundled example themes

These themes are bundled in `res://demo/themes/`:

- `construct3_stacked_theme.tres` — strongest Construct-like stacked baseline
- `high_contrast_theme.tres` — accessibility-focused contrast preset
- `soft_light_theme.tres` — softer default for long authoring sessions
- `designer_template_theme.tres` — neutral starting point meant to be duplicated
- `designer_template_theme_manifest.cfg` — token/package template for designer installs

## Custom theme import/install

- Copy a custom `EventSheetEditorStyle` `.tres` into the project.
- Keep an optional sidecar manifest/config next to it if you want token notes or package metadata.
- Use **Load Theme** and pick the `.tres` file.
- Save the EventSheet resource so the chosen theme stays attached to that sheet.

## Hot-reload behavior

- When the active style resource changes in-editor, the dock refreshes the viewport.
- **Reload Theme** forces a disk reload for external edits.
- **Rebuild Theme** is the practical post-`.tscn` workflow: update template scenes, then rebuild tokens without leaving the sheet editor.
- This is the closest practical equivalent to reloading a CSS theme file while staying fully native to Godot resources.

## Theme token spec

For the Construct-inspired token list and field mapping, see:

- `res://docs/EVENTSHEET_THEME_TOKEN_SPEC.md`

## Alignment controls

For layout and stacked-lane tuning details, see:

- `res://docs/EVENTSHEET_ALIGNMENT_GUIDE.md`

## CSS-like template path

True CSS is not a practical runtime format for this editor pass, but the project now provides a CSS-like workflow:

- duplicate `designer_template_theme.tres`
- keep `designer_template_theme_manifest.cfg` beside it
- edit named tokens in the Inspector the way you would edit CSS variables/selectors

This preserves the user goal of designer-friendly theming while fitting Godot’s Resource/Scene workflow cleanly.
