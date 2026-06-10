# Event Visual Element

## What this element is

`res://addons/eventsheet/elements/event_visual_element.tscn` is the structural preview scene for the whole EventSheet event block. It is where designers can understand how the stacked Construct-style shell is divided into the sheet background, condition lane, badge column, lane divider, and action lane.

## Visual controls

- `PreviewRow` / `PreviewRowAlt` — primary and alternating event block backgrounds
- `PreviewConditionLane` — left condition lane block
- `PreviewLaneDivider` — lane split between conditions and actions
- `PreviewActionLane` — right action lane block
- `PreviewTriggerBadge` + `PreviewTriggerLabel` — condition badge column treatment
- exported token fields on `event_sheet_event_element_template.gd` — sheet background, group/comment visuals, selection/hover fills, and row border colors

## Usage

- Open the scene in Godot and edit nodes visually.
- Use the exported inspector hints on `event_sheet_event_element_template.gd` to understand what each structural token does.
- `build_event_style()` translates the scene preview + exported fields into `EventSheetEventStyle`.
- Assign the scene through `EventSheetEditorStyle.event_visual_scene`.

## Designer notes

- This scene is the best place to explain the difference between event block chrome and condition/action entry chrome.
- Group/comment visuals are still configured as structural tokens on the generated `EventSheetEventStyle`, even though they are not separate row widgets.
- Keep node names readable for non-programmers; future theme passes should preserve that goal.
