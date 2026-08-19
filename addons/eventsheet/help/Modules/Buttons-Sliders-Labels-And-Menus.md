# Buttons, Sliders, Labels and Menus

A menu or a HUD is a scene of Godot `Control` nodes, and this is the vocabulary that drives them from
rows: the two button triggers, focus navigation for keyboard and gamepad, the button / slider /
text-field getters and setters, a layout preset, a theme colour override, and the label and
visibility rows a HUD is mostly made of.

Every row is a thin wrap of a native member, so a sheet on a `Button` really does compile to
`disabled = true`, and a sheet on a `Label` really does compile to `text = str(score)`. Nothing here
builds UI for you - you lay the scene out in the editor and drive it from events.

Most of these rows are node-scoped, which means each one also carries an optional **On node**
parameter: leave it blank to act on the node the sheet is attached to, or fill it in (`$Hud/Score`)
to drive another node from a central sheet. That single choice decides whether your UI logic lives on
each widget or in one menu sheet.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Reference tables](#reference-tables)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **A main menu** where each button starts a scene, opens options or quits.
- **Gamepad and keyboard menus** that never leave the player without a highlighted button.
- **Options screens** with sliders whose values you read and write.
- **Health, mana and progress bars** driven from a 0-1 ratio.
- **A score label** updated from one row.
- **A name-entry field** read into a variable when the player confirms.
- **Toggle buttons** whose state you set without firing their own event.
- **Disabled buttons** for choices the player cannot make yet.
- **A running log panel** that appends lines.
- **Panels shown and hidden** without touching the scene tree.
- **A flashing or dimming widget** through tint and theme colour overrides.

## Core concepts

- **On Pressed is the menu trigger.** It fires on click, on Enter with the button focused, and on a
  gamepad's accept button - one event covers all three. **On Toggled** is for check boxes and toggle
  buttons and carries a `toggled_on` argument you can branch on.
- **Focus is what makes a menu playable without a mouse.** Something must have focus for keyboard and
  gamepad navigation to work, so a menu that opens usually opens with a **Set Focus** row.
  **Focus Next** and **Focus Previous** walk the tab order, and **Set Focus Neighbor** overrides which
  control an arrow key reaches on one side.
- **Range covers three widgets.** `HSlider`, `ProgressBar` and `SpinBox` all descend from `Range`, so
  **Set Slider Value**, **Set Max Value**, **Value** and **Value Ratio** work on all of them. **Value Ratio**
  is the 0-1 form a bar's fill or an alpha wants.
- **Set Button Pressed does not fire On Toggled.** It emits `set_pressed_no_signal(...)` on purpose,
  so writing a checkbox's state from your own settings-loading code cannot start an event loop where
  the toggle handler writes the setting that sets the toggle.
- **Text lives on three different nodes.** **Set Text** / **Append Text** / **Get Text** are `Label`
  rows, **Set Field Text** / **Clear Field** / **Field Text** are `LineEdit` rows, and
  **Button Text** reads a `Button`. They all touch a `text` member; the node type is what tells them
  apart in the picker.
- **Show and Hide are `CanvasItem` actions**, so the same two rows work on a `Control`, a `Sprite2D` and
  a whole panel with children.
- **Tint is inherited, self-tint is not.** **Set Color Tint** colours the node and everything under
  it (a panel fading takes its labels with it); **Set Self Tint** colours only that node.

## Reference tables

Multi-line templates are shown by their first line; the full emitted block appears in the matching
use case below.

### Triggers (picker section: Signals / Scene / Input)

| Name | What it does | Ships as |
|------|--------------|----------|
| On Pressed | Runs when the player clicks or activates this button (`BaseButton`). | connects the `pressed` signal |
| On Toggled | Runs when a toggle button is switched on or off; carries `toggled_on`. | connects the `toggled` signal |

### Focus and layout (picker section: UI, node type Control)

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Focus | Gives this control keyboard focus. | `{target.}grab_focus()` |
| Set Progress | Fills a bar to a value out of a maximum, both in one row. | `{target.}value = {value}` then `{target.}max_value = {max}` |
| Show Dialog | Opens this dialog in the middle of the screen. | `{target.}popup_centered()` |
| Set Master Volume | Sets the overall game volume from a 0-to-1 slider value. | `AudioServer.set_bus_volume_db(0, linear_to_db({level}))` |
| Release Focus | Removes keyboard focus from this control. | `{target.}release_focus()` |
| Focus Next | Moves focus to the next control in tab order. | `var __n_{uid} = find_next_valid_focus()` … (multi-line, use case 5) |
| Focus Previous | Moves focus to the previous control in tab order. | `var __p_{uid} = find_prev_valid_focus()` … (multi-line) |
| Set Focus Neighbor | Sets which control an arrow key reaches on one Side. | `set_focus_neighbor({side}, {target})` |
| Has Focus | True when this control holds keyboard focus. | `{target.}has_focus()` |
| Set Anchors Preset | Snaps anchors and offsets to a layout preset. | `{target.}set_anchors_and_offsets_preset({preset})` |
| Override Theme Color | Overrides one theme colour slot on this control. | `{target.}add_theme_color_override({name}, {color})` |

**Set Focus Neighbor**'s Side dropdown offers `SIDE_LEFT`, `SIDE_TOP`, `SIDE_RIGHT` and
`SIDE_BOTTOM`, and its Target is a NodePath (default `^"../Sibling"`). **Set Anchors Preset** offers
`Control.PRESET_FULL_RECT`, `PRESET_CENTER`, the four corners, `PRESET_CENTER_TOP`,
`PRESET_CENTER_BOTTOM`, and the four wide presets.

### Buttons (picker section: UI, node type BaseButton)

| Name | What it does | Ships as |
|------|--------------|----------|
| Is Button Pressed | True while this button is pressed or toggled on. | `{target.}button_pressed` |
| Is Button Disabled | True when this button is disabled. | `{target.}disabled` |
| Set Button Disabled | Enables or disables a button. | `{target.}disabled = {disabled}` |
| Set Button Pressed | Sets a toggle's state WITHOUT firing its toggled event. | `{target.}set_pressed_no_signal({pressed})` |
| Button Text | The label text currently shown on the button (node type `Button`). | `{target.}text` |

### Sliders and bars (picker section: UI, node type Range)

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Slider Value | Sets a slider, progress bar or spinbox to a value. | `{target.}value = {value}` |
| Set Max Value | Sets its maximum. | `{target.}max_value = {max}` |
| Value | Its current value. | `{target.}value` |
| Value Ratio | Its value as a 0-to-1 ratio. | `{target.}ratio` |

### Text fields (picker section: UI, node type LineEdit)

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Field Text | Sets the text shown in a single-line field. | `{target.}text = str({value})` |
| Clear Field | Empties the field. | `{target.}clear()` |
| Field Text | Whatever the player typed into the field. | `{target.}text` |

### Labels, visibility and tint (picker sections: General Actions / Conditions / Expressions)

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Text | Sets the text shown on a `Label`. | `{target.}text = str({value})` |
| Append Text | Adds text onto the end of a `Label`'s text. | `{target.}text += str({value})` |
| Get Text | The text currently displayed on the `Label`. | `{target.}text` |
| Show | Makes a `CanvasItem` visible. | `{target.}show()` |
| Hide | Hides a `CanvasItem`. | `{target.}hide()` |
| Is Visible | True when the node is visible. | `{target.}visible` |
| Set Color Tint | Tints the node AND its children (RGBA). | `{target.}modulate = {color}` |
| Set Self Tint | Tints only this node. | `{target.}self_modulate = {color}` |

## Use cases

**1. A Play button.** A sheet on the button, one **On Pressed** event, one **Go To Layout** action:

```gdscript
get_tree().change_scene_to_file("res://levels/level1.tscn")
```

**2. A Quit button.** Same shape:

```gdscript
get_tree().quit()
```

**3. A menu that is playable on a gamepad from the first frame.** On the menu's **On Ready**, give the
first button focus:

```gdscript
$Buttons/PlayButton.grab_focus()
```

**4. Take focus away when a dialog opens**, so the menu behind it stops answering the arrow keys:

```gdscript
$Buttons/PlayButton.release_focus()
```

**5. Tab and Shift+Tab by hand**, when you want your own keys to walk the menu. **Focus Next** emits
its own guard, so a menu with nothing focusable is a safe no-op:

```gdscript
var __n_d1 = find_next_valid_focus()
if __n_d1: __n_d1.grab_focus()
```

**6. A two-column menu.** **Set Focus Neighbor** wires the arrow keys across the gap:

```gdscript
set_focus_neighbor(SIDE_RIGHT, ^"../RightColumn/Continue")
```

**7. Only act on the focused widget.** **Has Focus** on the condition side keeps a shared key handler
honest:

```
Every Frame
  Condition: Has Focus  (On node $NameField)
  Condition: On Action Just Pressed  "ui_accept"
    -> Set value  player_name = Field Text (On node $NameField)
```

**8. A toggle button that reports itself.** **On Toggled** carries `toggled_on`, so one event covers
both directions:

```
On Toggled  toggled_on
  Condition: Compare Values  toggled_on == true
    -> Show  (On node $AdvancedPanel)
  Else
    -> Hide  (On node $AdvancedPanel)
```

**9. Load a saved checkbox state without firing its own handler.** This is what
**Set Button Pressed** exists for:

```gdscript
$FullscreenCheck.set_pressed_no_signal(saved_fullscreen)
```

**10. Grey out a button the player cannot use yet:**

```gdscript
$ContinueButton.disabled = true
```

**11. And re-enable it when a save exists:**

```gdscript
$ContinueButton.disabled = false
```

**12. Branch on whether a button is already disabled**, with **Is Button Disabled**, so a refresh pass
does not fight itself.

```
On Ready
  Condition: Is Button Disabled  (On node $ContinueButton)
    -> Set Text  "No save found"  (On node $ContinueHint)
```

**13. Read a button's own caption** with **Button Text**, for a debug log or a confirm dialog:

```gdscript
$ConfirmLabel.text = str("Really " + $ActionButton.text + "?")
```

**14. A health bar.** **Set Max Value** once on ready, **Set Slider Value** whenever health changes:

```gdscript
$HealthBar.max_value = 100
```

```gdscript
$HealthBar.value = health
```

**15. Colour the bar by how full it is**, using **Value Ratio** as the blend weight:

```gdscript
$HealthBar.self_modulate = (Color(1, 0, 0, 1)).lerp(Color(0, 1, 0, 1), $HealthBar.ratio)
```

**16. A volume slider read back into the game.** The **Value** expression is the whole reading:

```gdscript
music_percent = $MusicSlider.value
```

**17. A name-entry field.** Read it with **Field Text** when the player confirms, then
**Clear Field**:

```gdscript
player_name = $NameField.text
```

```gdscript
$NameField.clear()
```

**18. Pre-fill the field with the last name used**, with **Set Field Text**:

```gdscript
$NameField.text = str(saved_name)
```

**19. A score label:**

```gdscript
$Hud/Score.text = str(score)
```

**20. A message log that grows.** **Append Text** adds to what is already there:

```gdscript
$Log.text += str("\n" + message)
```

**21. Show and hide a pause panel.** Two rows, no scene-tree surgery:

```gdscript
$PausePanel.show()
```

```gdscript
$PausePanel.hide()
```

**22. A pause key that toggles it.** **Is Visible** answers which way to go:

```
Every Frame
  Condition: On Action Just Pressed  "ui_cancel"
  Condition: Is Visible  (On node $PausePanel, inverted)
    -> Show  (On node $PausePanel)
    -> Set Game Paused  true
    -> Set Focus  (On node $PausePanel/Resume)
```

**23. Fade a whole panel out**, children included, with **Set Color Tint** and its alpha:

```gdscript
$PausePanel.modulate = Color(1, 1, 1, 0.35)
```

**24. Flash one label red without touching its neighbours**, with **Set Self Tint**:

```gdscript
$Hud/Warning.self_modulate = Color(1, 0.2, 0.2, 1)
```

**25. Recolour a label's font properly** (not by tinting it) with **Override Theme Color**:

```gdscript
$Hud/Warning.add_theme_color_override(&"font_color", Color(1, 0.3, 0.3, 1))
```

**26. Make a panel fill its parent** at runtime, with **Set Anchors Preset**:

```gdscript
$PausePanel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
```

### Other use cases

**A difficulty picker.** Three toggle buttons in a group, each On Toggled row writing one variable, and Set Button Pressed used on ready to show the saved choice without re-firing the handlers.

**A shop list.** One row per item that sets a Label's text and disables its Buy button whenever Value on the coins bar is below the price.

**A typewriter dialogue box.** Append Text one character at a time under a repeating timer, with Set Text clearing the line when the next page starts.

**An accessibility text-size toggle.** Override Theme Color plus a second Set Anchors Preset pass, so a larger font still lands inside its panel.

**A controller-friendly settings screen.** Set Focus Neighbor rows wiring every slider to the one above and below, so the whole tab is reachable with the d-pad alone.

## Tips and common mistakes

- **A menu with nothing focused is dead on a gamepad.** Whenever a screen opens - and every time a
  dialog closes - something must **Set Focus**. This is the single most common reason a menu "works
  with the mouse but not the controller".
- **Set Button Pressed is deliberately silent.** It does not fire **On Toggled**. If you actually want
  the handler to run, call the same actions yourself after setting the state.
- **Set Focus Neighbor has no On node parameter.** It already owns a parameter called Target (the
  neighbour), so the builtin retargeting pass leaves it alone. Put the row on the control whose
  neighbour you are setting.
- **Focus Next and Focus Previous have no On node either** - their templates declare a local
  variable, which the retargeting pass refuses to prefix. They always walk from the node the row runs
  on.
- **Button Text is scoped to `Button`, not `BaseButton`.** A `TextureButton` has no text to read, so
  the expression does not offer itself there.
- **Set Text and Set Field Text are different actions for different nodes.** A `Label` uses
  **Set Text**; a `LineEdit` uses **Set Field Text**. Both wrap `text`, so a row applied to the wrong
  node type will not appear in the picker at all - that is the picker telling you something, not a
  bug.
- **Set Text converts for you.** The template is `text = str({value})`, so passing a number is fine
  and wrapping it in `str()` yourself is harmless but redundant.
- **Append Text never trims.** A log built with it grows forever. Reset it with **Set Text** to `""`
  when a screen opens, or keep the last N lines yourself.
- **Value and Value Ratio are not interchangeable.** **Value** is in the bar's own units (0-100 by
  default); **Value Ratio** is always 0-1. Feeding a raw value into something that expects a ratio is
  how bars end up permanently full.
- **Set Max Value after Set Slider Value can clamp your value away.** Set the maximum first (usually once on
  ready), then the value.
- **Tint is inherited.** **Set Color Tint** on a panel dims every child, including its labels. When
  you meant only the panel's own background, use **Set Self Tint**.
- **Tinting is not theming.** Tint multiplies the drawn colour, so tinting a label with a colour can
  never make it brighter than its font colour already is. Use **Override Theme Color** with
  `&"font_color"` for a real recolour.
- **A hidden Control still occupies its layout slot's rules but stops drawing and stops receiving
  input.** Hiding a panel is enough to make it non-interactive; you do not also need to disable its
  buttons.
- **On Pressed fires on release, not on press.** That is standard button behaviour and matters for
  timing-sensitive UI - use an input trigger instead if you need the press moment.
