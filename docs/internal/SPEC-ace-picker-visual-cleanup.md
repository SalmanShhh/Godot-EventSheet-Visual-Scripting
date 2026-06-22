# Spec — ACE Picker Visual Cleanup (match Godot's Create New Node)

**Status:** proposed · **Date:** 2026-06-22

**Motivation (user):** *"the ACE picker is hard to read, it is too visually busy; I wanted it to be similar visually to the Godot node picker but it's not even close."*

This is a **presentation-only** redesign of `addons/eventsheet/editor/ace_picker.gd`. No behavior changes.

---

## 1. The problem

The Add Action / Condition picker carries several layers of visual noise that Godot's **Create New Node** (CreateDialog) does not:

1. **A redundant "Type" column.** The tree is 2-column (`ace_picker.gd:243-247`): col 0 `"Action / Condition"`, col 1 `"Type"`, and every row repeats its type as text (`:526`) — "Action", "Action", "Action"… down the right edge. Create New Node has **one** column.
2. **Every row name is colour-tinted by type** (`:525` via `_item_color_for`; colors `:137-141`) — soft green/blue/teal/purple on *every* row. Create New Node uses one uniform text colour; type is read from the **icon**.
3. **Saturated, hardcoded category-header colours** (`:130-135`: amber `#e0b070`, teal, blue, purple, neutral) applied at `:551`. Create New Node's category folders are quiet and theme-driven.
4. **The raw codegen template is dumped into the description panel** (`:999`, `:1002-1003`: `body += "\n[code]%s[/code]"`), so selecting "Play Sound" shows the whole `var __sfx = AudioStreamPlayer.new() … ` block — the dense box in the screenshot. Create New Node shows a clean class description.
5. **Minor:** the hint + Favorites/Recent labels + no-match text use the hardcoded `GROUP_COLOR_NEUTRAL` (`:213, :229, :235, :539`) instead of an editor-theme colour.

**Already good (keep):** per-row **type icons** already exist (`:521-524`, `:607-629` — MemberSignal/Method/Property/Constant + class icons), **boxed Favorites + Recent left panes** already exist (`:217-238`), and the relevance ranking, keyboard nav, reactive nudge, and search all work. The redesign only removes noise.

## 2. The target (Create New Node)

A single muted class tree, **one column**, type conveyed by the **icon** (a script glyph on scripted classes), boxed Favorites/Recent panes, a clean Description panel (class + inheritance + doc, no code), all colours from the **editor theme** (`get_theme_color`). Low saturation; consistent row height; the only colour is the type icon.

## 3. Proposed changes (each tied to code)

### Change 1 — collapse to a single-column tree (remove the Type column)
`ace_picker.gd:243-248`: set `_tree.columns = 1`; drop `set_column_title(1,…)`, `set_column_expand(1,…)`, `set_column_custom_minimum_width(1,…)`; hide the column header (`set_column_titles_visible(false)`). Remove the per-row `item.set_text(1,…)` + `set_custom_color(1,…)` (`:526-527`) and the group rows' `set_selectable(1,…)` (`:553, :587`). **Type is already conveyed by the row icon** (`:521-524`) and the tooltip ("[Condition] …", `:653-655`) — no information lost.

### Change 2 — stop tinting every row name
Remove `item.set_custom_color(0, _item_color_for(...))` at `:525` (and the side-pane equivalent at `:956`). Rows render in the default tree text colour, like Create New Node; type/category is read from icon + grouping. (Retain `_item_color_for` only if a subtle accent on the *icon* is wanted — default to none.)

### Change 3 — mute category headers to one theme colour
Replace the five saturated `GROUP_COLOR_*` constants (`:130-135`) with a single editor-theme muted colour resolved at draw time — e.g. `get_theme_color("font_disabled_color", "Editor")` (or the tree's own disabled/contrast colour). Apply it in `_group_color_for` (`:679-689`) so every category / sub-category header reads as a quiet divider. **Keep the class icon on node-type groups** (`:546-550`) — Create New Node also shows class icons; the node-type vs category distinction now comes from the icon, not a colour code.

### Change 4 — quiet the Description panel; demote the codegen
`_update_info_panel` (`:992-1009`): keep the header (`name · type · category`) and the plain description. **Move the `[code]` template out of the default view** — either (a) render it small + muted beneath a thin separator, or (b) hide it behind a "▸ Show generated GDScript" foldout — so the default reads like Create New Node's clean doc while preserving the "it's just GDScript" teaching value on demand. Keep the reactive-alternative tip (`:1006-1008`).

### Change 5 — theme-drive the remaining hardcoded colours
Hint (`:213`), Favorites/Recent labels (`:229, :235`), no-match text (`:539`): use `get_theme_color("font_disabled_color"/"contrast_color", "Editor")` instead of `GROUP_COLOR_NEUTRAL`. Resolve at refresh time (not once at construction) so the plugin's theme hot-reload is honoured.

### Change 6 (optional) — pane + filters polish
The panes are already boxed (`:217-238`); optionally wrap each list in a `PanelContainer` to match Create New Node's framed panes, and add a "Filters" affordance when category filtering is wanted. Low priority.

## 4. Before / After (wireframe)

**Before** — 2 columns, a Type column, bright headers, a codegen dump:

```
Add Action                                   [search.........] [⭐]
Select an action to append to the selected event.
┌ ⭐ Favorites ┐ ┌──────── Action / Condition ───────┬─ Type ─┐
│ (pinned)     │ │ ▾ Audio                            │        │ ← amber
│ ★ Recent     │ │    🔊 Play Sound                   │ Action │ ← teal text
│ (recent)     │ │ ▾ Node2D                           │        │ ← orange
│              │ │    ⬡ Play Sound At (2D)            │ Action │
└──────────────┘ └────────────────────────────────────┴────────┘
┌ Play Sound · Action · Audio ──────────────────────────────────┐
│ var __sfx_{uid} = AudioStreamPlayer.new()                      │
│ __sfx_{uid}.stream = load({path})  … (full codegen dumped)     │
└────────────────────────────────────────────────────────────────┘
                                             [Cancel] [Add]
```

**After** — single muted tree, type by icon, clean description:

```
Add Action                                   [search.........] [⭐]
Select an action to append to the selected event.
┌ ⭐ Favorites ┐ ┌───────────────────────────────────┐
│ (pinned)     │ │ Audio                             │ ← muted divider
│              │ │   🔊 Play Sound                   │ ← icon = type
│ ★ Recent     │ │ Node2D                            │ ← muted divider
│ (recent)     │ │   ⬡ Play Sound At (2D)           │
└──────────────┘ └───────────────────────────────────┘
┌────────────────────────────────────────────────────┐
│ Play Sound · Action · Audio                         │
│ Plays a sound from the given path.                  │
│ ▸ Show generated GDScript                           │ ← codegen folded away
└────────────────────────────────────────────────────┘
                                             [Cancel] [Add]
```

## 5. Behavior preserved (call-out)

No change to: search + C3 synonyms + fuzzy (`:460-540`), relevance ranking (`:818-907`), Favorites/Recent persistence (`:46-118`), keyboard nav (Down/Escape/Enter, `:738-797`), the reactive-twin nudge (`:499-511, :1004-1008`), Simple Mode filtering (`:691-696`), and the `ACEDefinition` metadata each TreeItem carries (`:530`). This is pixels only.

## 6. Accessibility / theming

Type must stay distinguishable without colour — the **icon** already does that (Change 1 keeps icons; Change 2 removes the redundant name colour). All colours route through the editor theme, so light/dark + the plugin's custom themes + hot-reload all work.

## 7. Files to touch

- `addons/eventsheet/editor/ace_picker.gd` — Changes 1-6 (columns, row/group colours, description, theme colours).
- Tests: `tests/picker_layout_test.gd` (assert `_tree.columns == 1`, no "Type" column title, a row carries `ACEDefinition` metadata + an icon, description omits raw `[code]` in the default view); refresh `tools/render_picker_preview.gd` golden for a visual diff.

## 8. Testing plan

- **Unit:** tree has 1 column; sample-ACE description contains name/type/category and NOT the raw `[code]` block in the default view (or only behind the foldout).
- **Visual:** regenerate `_picker_preview.png` via `tools/render_picker_preview.gd` (non-headless) and eyeball against Create New Node.
- Suite green; keyboard nav unaffected.

## 9. Open questions

- Keep a faint type accent on the icon, or pure-neutral rows? (Recommend pure-neutral, to match Create New Node.)
- Codegen in description: muted-inline vs foldout — which best preserves the teaching value without the noise?
- Does any existing test assert `columns == 2` or the "Type" column title? Grep before changing; update if so.
