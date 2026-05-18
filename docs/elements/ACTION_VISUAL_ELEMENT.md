# Action Visual Element

## What this element is

`res://addons/eventsheet/elements/action_visual_element.tscn` is the action-chip visual template used to build action styling.

## Visual controls

- Chip normal background/border
- Chip hover background/border
- Font color and text preview
- Corner radius and padding via stylebox values

## Usage

- Edit this scene in Godot’s visual editor.
- Script `event_sheet_chip_element_template.gd` maps scene data to `EventSheetElementStyle`.
- Assign through `EventSheetEditorStyle.action_visual_scene`.
