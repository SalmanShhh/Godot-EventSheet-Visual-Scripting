# EventSheet Layout + Alignment Guide

This guide explains how EventSheet row alignment is computed and how to tune it toward a Construct 3-like stacked layout.

## Layout model

- Each **event row** is one block with two lanes:
  - **Condition lane** (left)
  - **Action lane** (right)
- Conditions and actions render as **vertical stacks** using per-span `line_index` values.
- Event block height is derived from the number of stacked lines in the row.

```
| gutter |  condition lane                        | action lane                    |
|        | [badge col][condition row 1........]  | [action row 1.............] +  |
|        | [badge col][condition row 2........]  | [action row 2.............]    |
|        | [badge col][condition row 3........]  |                                |
```

`+` indicates the inline **+ Add** affordance in the action lane.

## Key alignment settings

Primary tuning lives in `EventSheetEventStyle`:

- `condition_lane_ratio`
- `minimum_conditions_lane_width`
- `condition_lane_padding`
- `condition_badge_column_width`
- `action_lane_padding`
- `lane_divider_width`
- `minimum_row_height`

Token sizing/spacing lives in `EventSheetElementStyle`:

- `horizontal_padding`
- `vertical_padding`
- `gap_after`
- `font_size_delta`
- `badge_extra_width`

## Badge alignment behavior

- Trigger (`➜`), Invert (`✕`), and OR (`OR`) badges use a dedicated condition badge column.
- AND remains implicit (no badge).
- Set `condition_badge_column_width` to control badge column width and keep badge alignment stable across dense rows.

## Construct 3-like tuning recipe

1. Start from `res://demo/themes/construct3_stacked_theme.tres`.
2. Keep `condition_badge_column_width` between 24–32.
3. Keep condition/action `gap_after` small (about 6–8).
4. Keep `minimum_conditions_lane_width` high enough (200+ for long ACE labels).
5. Adjust lane ratio last for your project’s condition/action text balance.

## Newer alignment facts (2026-06)

- The **lane divider is drag-resizable** in the editor; `condition_lane_ratio` remains the
  saved default.
- ACE cells may draw an **object icon** before the object label; the icon advance is the
  renderer's `OBJECT_ICON_ADVANCE` (18 px) and is included in span measurement, so icons
  never skew hit-testing or stack alignment.
- Sibling event blocks are separated by the viewport's `EVENT_BLOCK_GAP`; sub-events sit
  tighter to their parent than unrelated siblings (C3 rhythm).

## Where this is implemented

- Layout + hit targets: `res://addons/eventsheet/editor/event_sheet_viewport.gd`
- Row rendering/chrome: `res://addons/eventsheet/editor/event_row_renderer.gd`
- Theme resources: `res://addons/eventsheet/theme/*.gd`


## Theme token cross-reference

For the full Construct-inspired token list, see `res://docs/EVENTSHEET_THEME_TOKEN_SPEC.md`.
Structural layout tuning still lives primarily in `EventSheetEventStyle`, while entry visuals live in `EventSheetElementStyle`.
