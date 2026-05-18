# Event Visual Element

## What this element is

`res://addons/eventsheet/elements/event_visual_element.tscn` is the visual template that defines event row lane styling and preview composition.

## Visual controls

- Base/alternate row background
- Condition lane background
- Lane divider
- Action lane background
- Trigger badge + labels

## Usage

- Open the scene in Godot and edit nodes visually.
- The linked script (`event_sheet_event_element_template.gd`) translates scene values into `EventSheetEventStyle`.
- Assign through `EventSheetEditorStyle.event_visual_scene`.
