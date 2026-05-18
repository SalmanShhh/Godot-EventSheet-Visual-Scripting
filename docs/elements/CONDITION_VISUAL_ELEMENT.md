# Condition Visual Element

## What this element is

`res://addons/eventsheet/elements/condition_visual_element.tscn` is the designer-facing template for one stacked condition entry.

## Visual controls

- Button normal stylebox — condition background/border token source
- Button hover stylebox — condition hover token source
- Button text — readable stand-in for the condition name/description cell role
- exported inspector fields on `event_sheet_chip_element_template.gd` — padding, badge width, gap after, font delta, and badge text color

## Usage

- Edit this scene in Godot’s visual editor.
- Read the exported inspector guide text for how the chip maps to the stacked condition lane.
- `event_sheet_chip_element_template.gd` exports the result as `EventSheetElementStyle`.
- Assign the scene through `EventSheetEditorStyle.condition_visual_scene`.

## Designer notes

- The current renderer still uses one text style token for the condition name + description/value role, so this scene should prioritize readability over micro-styling.
- Badge column tokens are owned by `EventSheetEventStyle`, while the chip itself is owned by `EventSheetElementStyle`.
