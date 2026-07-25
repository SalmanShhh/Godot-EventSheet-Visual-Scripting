# HUD Kit - Menus and HUDs by Node Name, Zero Wiring

HUD Kit is a Godot EventSheets behavior pack that drives a whole menu or HUD by node name, with no signal wiring and no NodePath dragging. You attach a `HudKitBehavior` behavior to your UI root - a `CanvasLayer` or a `Control` - and that node becomes the driver for everything under it. Every Action, Condition, and Expression targets a descendant by its plain node name: set a `Label`'s text, fill a `ProgressBar`, show or hide a panel, flip between menu screens, or pop a fading toast, all by passing the name string. On top of that, every descendant `Button` wires itself into one `On Button Pressed` trigger at startup, so a menu with twenty buttons needs zero connected signals - you branch on which one fired with a single condition. Name your nodes in the scene, drop the behavior on the root, and the sheet talks to them by name.

---

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Live stat bars.** Fill a health, mana, stamina, or XP `ProgressBar` straight from your gameplay values every tick with one Set Bar row, max included.
- **Score and status labels.** Push score, ammo, timer, wave, or coin counts into named `Label`s with Set Text, no `@onready var` references to keep in sync.
- **Main menu screens.** Lay out Play, Options, and Credits as sibling panels and flip between them with a single Switch Screen call - it shows one and hides the rest.
- **Pause and inventory overlays.** Toggle Panel flips a pause screen or bag open and closed from one button, and Is Panel Visible lets you branch on its current state.
- **Menus with lots of buttons.** Every descendant `Button` reports through one On Button Pressed trigger, so a settings screen full of buttons needs no per-button signal connections.
- **Toast notifications.** Pop a bottom-centre "Saved", "Item acquired", or "Achievement unlocked" message that fades itself out after a couple of seconds.
- **Settings tabs.** Treat each settings page as a panel and use Switch Screen to move between Audio, Video, and Controls tabs from their tab buttons.
- **Boss and enemy health bars.** Set Bar takes a max value, so a boss bar can rescale when a new phase raises the boss's max health.
- **Dialogue boxes.** Drop the speaker name into one `Label` and the line into another with two Set Text rows as a conversation advances.
- **Quest and objective trackers.** Keep an on-screen objective `Label` current by writing the new goal text whenever the quest state changes.
- **Confirmation dialogs.** Show a "Are you sure?" panel on a destructive button, then hide it again on Yes or No, reading Button Is to tell them apart.
- **Runtime-spawned UI.** After you instance new buttons at runtime, one Connect Buttons call re-wires them into the same On Button Pressed trigger.

---

## Core concepts

The pack has a small, consistent mental model. Learn these ideas and every ACE reads the same way.

**The node you attach to is the driver.** You drop one `HudKitBehavior` under your UI root (a `CanvasLayer` or `Control`). Its parent is its "host", and every lookup happens beneath that host. You do not pass the behavior around or reference it by an id - the ACEs act on the behavior living on the node they are placed on.

**Everything works by name.** Instead of exported NodePaths or dragged signal connections, you pass the plain node name as a string. Set Text `"ScoreLabel"`, Show Panel `"PauseMenu"`, Set Bar `"HealthBar"` - each one finds the first descendant of the host with that name. The lookup is recursive (it searches the whole subtree, not just direct children) and cached, so repeated calls to the same name are cheap. This is why you name your UI nodes clearly in the scene: the name in the scene is the handle the sheet uses.

**Panels are any CanvasItem.** Show Panel, Hide Panel, Toggle Panel, and Switch Screen all accept anything that can be shown or hidden - a `Control`, a `Panel`, a `Node2D`, a `CanvasLayer` child. A "panel" here just means "a named thing with a visible flag", so the same four actions manage menu screens, overlays, popups, and HUD widgets alike.

**Switch Screen is the menu mover.** Switch Screen shows the named panel and hides its siblings - every other panel that shares the same parent. That is the one-call way to flip a menu from the Play screen to the Options screen: put your screens as siblings under one container, and Switch Screen `"OptionsScreen"` reveals it while hiding the rest. Show and Hide Panel touch only the one panel you name; Switch Screen touches the whole sibling group.

**Bars are any Range.** Set Bar and Bar Value work on `ProgressBar`, `TextureProgressBar`, or any other `Range` node. Set Bar writes the current value, and if you pass a `max_value` greater than zero it sets the maximum too - pass `0` for the max when you only want to move the fill and leave the range alone. Bar Value reads the current value back out (it returns `0` if the name is not a Range).

**Text targets are any node with a text property.** Set Text writes to a named `Label`, `RichTextLabel`, `Button`, or `LineEdit` - anything with a `text` property. One action covers captions, buttons, and input fields.

**One trigger for the whole button set.** At startup the behavior walks its host subtree, finds every `Button` (technically any `BaseButton`), and connects each one's pressed signal into a single `On Button Pressed` trigger. When any button is clicked, that one trigger fires and the button's name lands in Last Button Name. You react by branching with the Button Is condition (or reading Last Button Name), so a menu with many buttons needs exactly one trigger event and zero manual signal connections. The auto-wiring is controlled by the `auto_connect_buttons` Inspector toggle; if you spawn buttons after startup, re-run the wiring with the Connect Buttons action (it is idempotent - a button already connected is skipped).

**Toasts are fire-and-forget.** Show Toast creates a temporary bottom-centre `Label`, shows your message, waits `toast_seconds`, fades it out, and frees it - all on its own. You do not create or manage the label; you just hand it a string.

---

## Setup

**1. Attach the behavior.** Add a `HudKitBehavior` behavior as a child of your UI root node - a `CanvasLayer` or a `Control` that all your menu and HUD nodes live under (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in). Its parent becomes the host it drives.

**2. Name your UI nodes.** Because every ACE targets a node by name, give your labels, bars, panels, and buttons clear names in the scene tree - `ScoreLabel`, `HealthBar`, `PauseMenu`, `StartButton`. Those exact strings are what you pass in the sheet.

**3. Set the Inspector knobs (optional).** Select the behavior node and adjust the two properties:

| Property | Default | What it does |
|---|---|---|
| `auto_connect_buttons` | `true` | On Ready, wires every descendant Button's pressed signal into On Button Pressed. Turn it off if you want to wire buttons yourself with Connect Buttons at a specific time. |
| `toast_seconds` | `2.0` | How long a toast stays on screen before it fades out (in seconds). |

**4. Drive the UI from the sheet.** Push values into named nodes, and react to button presses through the one trigger. Here is a complete first HUD - a score label, a live health bar, and a Start button, with no signals wired:

```
On Ready
  -> HUD | HUD Kit: Set Text  "ScoreLabel", "Score: 0"

Every tick
  -> HUD | HUD Kit: Set Bar  "HealthBar", Player.hp, Player.max_hp

On Button Pressed
  Condition: HUD | HUD Kit  Button Is  "StartButton"
    -> (start the game)
```

Because `auto_connect_buttons` is on, the `StartButton` wired itself at startup - you did not connect a thing. Set Bar passes `Player.max_hp` so the bar's range tracks the player's max, and the On Button Pressed / Button Is pair is the whole pattern for reacting to any button in the menu.

---

## ACE reference

All ACEs live in the **UI** category and act on the `HudKitBehavior` behavior of the node they are placed on. Every target is passed by its node name string; the lookup is recursive under the host and cached.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Connect Buttons | (none) | Wires every descendant Button's pressed signal into On Button Pressed. Idempotent (already-connected buttons are skipped) - re-run it after spawning new buttons. Runs automatically at startup when `auto_connect_buttons` is on. |
| Set Text | `control_name` (String), `text` (String) | Sets the text of a named Label, RichTextLabel, Button, or LineEdit. |
| Set Bar | `bar_name` (String), `value` (float), `max_value` (float) | Sets a named ProgressBar / TextureProgressBar (any Range) value. Also sets its max when `max_value` is greater than 0; pass 0 to leave the range untouched. |
| Show Panel | `panel_name` (String) | Makes a named panel (any CanvasItem) visible. |
| Hide Panel | `panel_name` (String) | Hides a named panel (any CanvasItem). |
| Toggle Panel | `panel_name` (String) | Flips a named panel's visibility on or off. |
| Switch Screen | `panel_name` (String) | Shows the named panel and hides its sibling panels - one call flips a whole menu screen. |
| Show Toast | `text` (String) | Pops a bottom-centre message that fades out after `toast_seconds`. Creates and frees the label for you. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Button Is | `button_name` (String) | Whether the button that most recently fired On Button Pressed has this name. |
| Is Panel Visible | `panel_name` (String) | Whether a named panel (any CanvasItem) is currently visible. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Last Button Name | (none) | String | The name of the button that most recently fired On Button Pressed ("" before any press). |
| Bar Value | `bar_name` (String) | float | The current value of a named Range (0 if the name is not a Range). |

### Triggers

| Trigger | Fires when |
|---|---|
| On Button Pressed | Any descendant Button (wired by Connect Buttons or automatically at startup) is pressed. The button's name is available through Last Button Name and Button Is. |

### Inspector properties

| Property | Type | Default | Range |
|---|---|---|---|
| `auto_connect_buttons` | bool | `true` | on / off |
| `toast_seconds` | float | `2.0` | 0.2 - 10 (step 0.1) |

### Inspector properties are ACEs too

Every property this pack exposes in the Inspector is also reachable from the picker, generated for you:
an expression named after the property reads it, a **Set ...** action writes it, and for number properties
**Add To ...** and **Subtract From ...** adjust it by an amount. They sit in the pack's own category
alongside the verbs above, so any knob you can set in the Inspector is also something a sheet can read and
change while the game runs.

---

## Use cases

Each example targets the `HudKitBehavior` behavior on the named node (here a UI root called `HUD` or `Menu`). Node names in quotes are the scene names of descendants under that root.

### 1. Live health bar from gameplay

Fill a health bar straight from the player's values every frame. Passing the max keeps the bar's range in step if the max ever changes.

```
Every tick
  -> HUD | HUD Kit: Set Bar  "HealthBar", Player.hp, Player.max_hp
```

### 2. Score and ammo labels

Keep two labels current without holding any node references. Set Text finds each label by name.

```
On Score Changed
  -> HUD | HUD Kit: Set Text  "ScoreLabel", "Score: " + str(Game.score)

On Ammo Changed
  -> HUD | HUD Kit: Set Text  "AmmoLabel", str(Weapon.ammo) + " / " + str(Weapon.mag_size)
```

### 3. Main menu screen switching

Lay out Play, Options, and Credits as sibling panels under one container. Switch Screen shows one and hides its siblings in a single call, so each tab button flips the whole screen.

```
On Button Pressed
  Condition: Menu | HUD Kit  Button Is  "OptionsButton"
    -> Menu | HUD Kit: Switch Screen  "OptionsScreen"
  Condition: Menu | HUD Kit  Button Is  "CreditsButton"
    -> Menu | HUD Kit: Switch Screen  "CreditsScreen"
  Condition: Menu | HUD Kit  Button Is  "BackButton"
    -> Menu | HUD Kit: Switch Screen  "MainScreen"
```

### 4. One trigger drives every menu button

You never connect a button signal. Every descendant button routes through On Button Pressed, and you branch on Button Is. Add a new button to the scene and it just works.

```
On Button Pressed
  Condition: Menu | HUD Kit  Button Is  "StartButton"
    -> (load first level)
  Condition: Menu | HUD Kit  Button Is  "QuitButton"
    -> (quit the game)
```

### 5. Pause overlay toggle

One button flips a pause panel open and closed. Toggle Panel does not care about its current state - it just inverts it.

```
On Button Pressed
  Condition: HUD | HUD Kit  Button Is  "PauseButton"
    -> HUD | HUD Kit: Toggle Panel  "PauseMenu"
```

### 6. Toast on item pickup

Pop a self-fading message when the player grabs something. No label to create, position, or clean up.

```
On Item Picked Up
  -> HUD | HUD Kit: Show Toast  "Picked up " + Item.display_name
```

### 7. Settings tabs

Treat each settings page as a sibling panel and let the tab buttons move between them. Switch Screen keeps exactly one page visible.

```
On Button Pressed
  Condition: Settings | HUD Kit  Button Is  "AudioTab"
    -> Settings | HUD Kit: Switch Screen  "AudioPage"
  Condition: Settings | HUD Kit  Button Is  "VideoTab"
    -> Settings | HUD Kit: Switch Screen  "VideoPage"
  Condition: Settings | HUD Kit  Button Is  "ControlsTab"
    -> Settings | HUD Kit: Switch Screen  "ControlsPage"
```

### 8. Inventory panel with a state guard

Open the bag on one button, and only show a "closing" toast when it was actually open. Is Panel Visible reads the current state before you flip it.

```
On Button Pressed
  Condition: HUD | HUD Kit  Button Is  "BagButton"
    Condition: HUD | HUD Kit  Is Panel Visible  "InventoryPanel"
      -> HUD | HUD Kit: Show Toast  "Bag closed"
    -> HUD | HUD Kit: Toggle Panel  "InventoryPanel"
```

### 9. Boss health bar that rescales on a phase change

Set Bar takes a max, so when a boss enters a new phase with more health, the same action both raises the range and sets the fill.

```
On Boss Phase Changed
  -> HUD | HUD Kit: Set Bar  "BossBar", Boss.hp, Boss.max_hp
  -> HUD | HUD Kit: Set Text  "BossNameLabel", Boss.phase_title
```

### 10. Low-health warning read from the bar

Read a bar's current value back with Bar Value and flash a warning when it drops. This reads the UI itself, so it stays true even if something else moved the bar.

```
Every 0.5 seconds
  Condition: HUD | HUD Kit  [Expression] Bar Value  "HealthBar"  <  20
    -> HUD | HUD Kit: Show Panel  "LowHealthVignette"
  Else
    -> HUD | HUD Kit: Hide Panel  "LowHealthVignette"
```

### 11. Confirmation dialog flow

A destructive button raises a confirm panel; Yes and No both hide it, and you act only on Yes. Button Is tells the three buttons apart under the one trigger.

```
On Button Pressed
  Condition: HUD | HUD Kit  Button Is  "DeleteSaveButton"
    -> HUD | HUD Kit: Show Panel  "ConfirmPanel"
  Condition: HUD | HUD Kit  Button Is  "ConfirmYesButton"
    -> (delete the save file)
    -> HUD | HUD Kit: Hide Panel  "ConfirmPanel"
    -> HUD | HUD Kit: Show Toast  "Save deleted"
  Condition: HUD | HUD Kit  Button Is  "ConfirmNoButton"
    -> HUD | HUD Kit: Hide Panel  "ConfirmPanel"
```

### 12. Re-wiring buttons after spawning UI

When you build a level-select grid at runtime, the new buttons are not wired yet. One Connect Buttons call folds them all into the same On Button Pressed trigger.

```
On Level Grid Built
  -> HUD | HUD Kit: Connect Buttons

On Button Pressed
  Condition: HUD | HUD Kit  Button Is  "Level_3"
    -> (load level 3)
```

### 13. Quest objective tracker

Keep an on-screen objective label current whenever the quest advances. One Set Text row per update.

```
On Objective Updated
  -> HUD | HUD Kit: Set Text  "ObjectiveLabel", Quest.current_objective_text
```

### 14. Dialogue box driven by name and line

Two labels, two Set Text rows: the speaker's name in one, their line in the other, updated as the conversation moves.

```
On Dialogue Line
  -> HUD | HUD Kit: Set Text  "SpeakerLabel", Line.speaker
  -> HUD | HUD Kit: Set Text  "DialogueLabel", Line.text
```

### 15. Level-complete banner and toast

Reveal a results panel and pop a celebratory toast at the same moment, then read a button to move on.

```
On Level Complete
  -> HUD | HUD Kit: Show Panel  "ResultsPanel"
  -> HUD | HUD Kit: Set Text  "ResultTimeLabel", "Time: " + Game.formatted_time
  -> HUD | HUD Kit: Show Toast  "Level complete!"

On Button Pressed
  Condition: HUD | HUD Kit  Button Is  "NextLevelButton"
    -> (load the next level)
```

### Other use cases

**Combo meter.** Write the current combo count into a label with Set Text and mirror the decay timer in a bar with Set Bar, so the whole "keep the streak alive" readout is two rows fed from your combat variables.

**Tutorial hint overlays.** Keep each hint as a named panel and Show Panel it when the player enters a teaching zone, Hide Panel when they perform the move - contextual tips with no dedicated tutorial UI code.

**Racing HUD.** Lap counter and position go into labels, a speed or boost gauge into a Range bar, and the pause and results screens flip with Switch Screen, covering an entire racing overlay with the same four verbs.

**Oxygen gauge that only appears underwater.** Show Panel the gauge when the player submerges, drive it with Set Bar every tick, and Hide Panel it back on the surface, so the HUD stays clean until the stat actually matters.

**Cutscene HUD hiding.** Put the whole gameplay HUD under one named panel and Hide Panel it when a cutscene starts, then Show Panel it after - one string toggles the entire interface instead of touching every widget.

---

## Tips and common mistakes

- **The node you attach to is the driver - there is no id to pass.** Every Action, Condition, and Expression acts on the `HudKitBehavior` of the node it is placed on, and searches the subtree under that node's parent. Attach it once to the root that holds your UI, not to each widget.
- **Names must match the scene exactly.** The string you pass is fed to a recursive name lookup, so `"HealthBar"` finds a node named `HealthBar` anywhere below the host. A typo or a renamed node finds nothing and the action quietly does nothing - if a bar will not fill or a panel will not show, check the name against the scene tree first.
- **Set Bar's third argument is the max, and 0 means "leave it".** Pass the real max (`Player.max_hp`) when you want the bar's range to track it, or pass `0` when you only want to move the fill and keep the max the node already has. Passing a small nonzero number by accident will shrink the whole range.
- **Switch Screen only hides siblings - lay your screens out as siblings.** Switch Screen shows the named panel and hides the other panels that share its parent. If your menu screens are scattered under different parents, it will not hide them; put all the screens for one group under a single container so one Switch Screen call flips between them cleanly.
- **Show, Hide, and Toggle touch only the one panel you name.** Unlike Switch Screen, these three do not affect any other panel. Use them for standalone overlays (pause, inventory, a popup) and use Switch Screen for a set of mutually exclusive screens.
- **You do not connect button signals - the pack does.** With `auto_connect_buttons` on, every descendant button is wired at startup into the single On Button Pressed trigger. Do not also connect a button's pressed signal by hand, or your handler and the pack will both fire.
- **Buttons spawned after startup need Connect Buttons.** The automatic wiring runs once, at ready. If you instance buttons later (a level grid, a dynamic list), call the Connect Buttons action once afterward. It is safe to call repeatedly - buttons already wired are skipped.
- **Branch on the button inside On Button Pressed, not with separate triggers.** There is one trigger for all buttons. React by nesting Button Is conditions (or reading Last Button Name) under a single On Button Pressed event, one condition per button you care about.
- **Set Text needs a node with a text property.** It writes to a Label, RichTextLabel, Button, or LineEdit. Pointing it at a plain container or a bar does nothing - use Set Bar for a Range and Set Text for text nodes.
- **Toasts manage themselves - do not build your own label.** Show Toast creates, positions, fades, and frees its label for you, timed by `toast_seconds`. Tune the duration in the Inspector rather than adding your own timer or cleanup logic.
