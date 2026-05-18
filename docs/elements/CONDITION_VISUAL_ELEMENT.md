# Condition Visual Element

## What this element is

`res://addons/eventsheet/elements/condition_visual_element.tscn` is the condition-chip visual template used to build condition styling.

## Visual controls

- Chip normal background/border
- Chip hover background/border
- Font color and text preview
- Corner radius and padding via stylebox values

## Usage

- Edit this scene in Godot’s visual editor.
- Script `event_sheet_chip_element_template.gd` exports it as `EventSheetElementStyle`.
- Assign through `EventSheetEditorStyle.condition_visual_scene`.
