# EventSheet Theme + Editability Guide

This editor uses Godot-native resources/scenes instead of runtime CSS. The goal is still the same as a Construct-style theme.css workflow: designers can duplicate a theme package, tune layout/visual tokens visually, reload the editor, and keep shipping reusable presets.

## Core model

- `EventSheetEditorStyle` (`.tres`) is the active installable theme package.
- `EventSheetEventStyle` owns sheet/event/group/comment/interaction tokens.
- `EventSheetElementStyle` owns condition/action entry tokens.
- `theme_layout_visual_editor.tscn` is the dedicated visual authoring surface for full EventSheet layout + alignment tuning.
- Element templates are scene files in `res://addons/eventsheet/elements/`:
  - `theme_layout_visual_editor.tscn`
  - `event_visual_element.tscn`
  - `condition_visual_element.tscn`
  - `action_visual_element.tscn`
- These scenes are linked by `EventSheetEditorStyle.theme_layout_visual_scene`, `event_visual_scene`, `condition_visual_scene`, and `action_visual_scene`.

## Editing flow for designers

1. Duplicate `res://demo/themes/designer_template_theme.tres`.
2. Duplicate `res://demo/themes/designer_template_theme_manifest.cfg` so your package keeps the visual workflow pointers.
3. Open `res://addons/eventsheet/elements/theme_layout_visual_editor.tscn` first.
4. Visually adjust named nodes for sheet background, event shell, condition/action lanes, lane divider, badge column swatches, group/comment chrome, and hover/selection fills.
5. Tune exported alignment values on the root node (`condition_badge_column_width`, lane padding, lane ratio, row height, divider width, etc.).
6. Save the scene and choose **Reload Theme** in the EventSheet dock. `EventSheetEditorStyle.use_visual_layout_scene=true` on the template causes styles to be regenerated from the scene.
7. Use `.tres` token editing for any fine-tuning that is still easier in raw resource form.
8. Assign/load the style through `EventSheetResource.editor_style` or the dock toolbar.

## What the visual layout scene edits directly

- **Structural shell:** sheet background, event block background/alt/background border, condition lane, action lane, lane divider
- **Alignment controls:** condition lane ratio, minimum lane width, condition badge column width, lane paddings, divider width, row height
- **Group/comment chrome:** group background/alt/accent/title/badge/fold and comment background/text swatches
- **Interaction fills:** hover and selection preview swatches
- **Entry chips:** condition/action chip preview buttons for background, border, hover, text, padding, and spacing

## What remains token-only (for now)

- Runtime renderer behavior itself still lives in the custom viewport/row renderer and is not edited in scenes.
- Condition/action name cell vs description cell are still a shared text token in the current renderer.
- Manifest import remains a template/package aid; it is not auto-imported.

## Switching themes

- Toolbar actions in the EventSheet dock:
  - **Load Theme**: pick an `EventSheetEditorStyle` resource.
  - **Default Theme**: clear the per-sheet override and use built-in defaults.
  - **Reload Theme**: reload the active style from disk.

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
- **Reload Theme** forces a disk reload for external edits (including `theme_layout_visual_editor.tscn` visual edits in the template workflow).
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
- edit `theme_layout_visual_editor.tscn` first for visual layout/alignment tuning
- edit named tokens in the Inspector for precise numeric/color follow-up

This preserves the user goal of designer-friendly theming while fitting Godot’s Resource/Scene workflow cleanly.
