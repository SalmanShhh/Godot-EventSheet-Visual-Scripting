# Action Visual Element

## What this element is

`res://addons/eventsheet/elements/action_visual_element.tscn` is the designer-facing template for one stacked action entry.

## Visual controls

- Button normal stylebox — action background/border token source
- Button hover stylebox — action hover token source
- Button text — readable stand-in for the action name/description cell role
- exported inspector fields on `event_sheet_chip_element_template.gd` — padding, badge width, gap after, font delta, and badge text color

## Usage

- Edit this scene in Godot’s visual editor.
- Use the exported inspector hints to understand how the action chip maps to the right lane.
- `event_sheet_chip_element_template.gd` maps the scene data to `EventSheetElementStyle`.
- Assign the scene through `EventSheetEditorStyle.action_visual_scene`.

## Designer notes

- Use this as a starting point for themes that want a Construct-like readable action lane instead of placeholder chips.
- Keep the text preview focused on legibility for non-programmers; the renderer still treats action name/description text as one shared text role today.
