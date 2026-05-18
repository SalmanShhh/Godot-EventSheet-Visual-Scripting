# Theme Layout Visual Editor

## What this element is

`res://addons/eventsheet/elements/theme_layout_visual_editor.tscn` is the dedicated visual authoring scene for EventSheet shell + alignment styling.

## Visual controls

- `SheetBackground` — whole sheet background
- `EventBlockShell` / `EventBlockShellAlt` / `EventBlockBorder` — event block shell and border swatches
- `ConditionLane` / `ActionLane` / `LaneDivider` — lane backgrounds and split color
- `BadgeColumn` / `BadgeGlyph` — trigger/OR/invert badge column role swatches
- `ConditionEntryPreview` / `ActionEntryPreview` — lane entry chip visuals
- `GroupBlock*` + `CommentBlock*` nodes — group/comment chrome tokens
- `HoverFillPreview` / `SelectionFillPreview` — interaction fill overlays
- Root exported fields — badge width, lane ratio, lane padding, row height, and chip spacing/alignment tokens

## Usage

1. Open this scene first when creating a new designer theme package.
2. Edit the swatches and preview buttons visually in the 2D editor.
3. Adjust alignment exports on the root node for badge column width, lane ratio, paddings, and row height.
4. Save the scene and run **Reload Theme** from the EventSheet dock.
5. Keep `EventSheetEditorStyle.use_visual_layout_scene` enabled so the style regenerates from this scene.

## Designer notes

- This is the preferred visual entry point for theme/layout tuning.
- The existing event/condition/action scenes remain useful as focused component previews.
- Runtime layout logic still comes from the custom viewport renderer; this scene supplies token values, not rendering code.
