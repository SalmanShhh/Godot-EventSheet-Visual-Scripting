# Game Settings

**Game Settings** ships as the `Settings` autoload - one place that knows what your game offers.

The built-in **Save Setting** action writes a value to a file and stops there: nothing says a setting
*exists*, so its default, its kind and its range get retyped at every call site and quietly drift
apart. **Declare Setting** names it once - a default, a kind, and (for a choice) its options - and
everything else follows from that single declaration: a real default before anything was ever saved,
an **On Setting Changed** trigger you branch on by name, one **Apply All Settings** row that replays
every reaction at boot, **Reset Settings To Defaults** for free, and a report of what your game
actually offers. The same declaration is what lets an options menu build itself from data instead of
one hand-wired control per setting.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Where the values live](#where-the-values-live)
6. [Use cases](#use-cases)
7. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this pack shines

- **Audio options** - master, music and effects volume, each one reaction row.
- **Video options** - fullscreen, vsync, an FPS cap, a quality preset.
- **Accessibility** - reduce motion, high contrast, larger text, hold versus toggle for aiming.
- **Difficulty and daily modifiers** through the Choice kind.
- **Debug and cheat toggles** that ship switched off and never need a separate system.
- **First-boot correctness** - the game does not sound wrong before the player opens the options
  screen once.
- **Save-slot independence** - settings live beside your save files, so Start New Run never resets
  the volume.
- **A menu built from data** - loop the declared names and build one control per setting.

## Core concepts

- **Declaring is the whole idea.** A setting exists because a row declared it: a name, a default, a
  kind, and for a Choice its options. That declaration is the only place the default is written.
- **The name is the address.** Every other entry takes the setting's name. Keep them short and
  snake_cased (`master_volume`, `screen_shake`), the way you would name a variable.
- **Reading falls back to the default.** **Setting Value** answers the value that was set or loaded,
  and the declared default when nothing was ever saved. That is why a fresh install is already
  correct.
- **Changing it fires a trigger.** **Set Setting** fires **On Setting Changed** with the setting's
  name and its new value as the row's own payload. Setting a value it already holds fires nothing.
- **The reaction lives wherever it belongs.** Put **On Setting Changed** in the sheet that owns the
  thing being changed, and branch with **Changed Setting Is** - the audio sheet reacts to the volume,
  the camera sheet to screen shake. Nothing has to be wired between them.
- **Apply All Settings is the boot row.** It re-fires the trigger for every declared setting, so boot
  and the options screen take exactly the same path and can never drift apart.
- **The kind is for your menu, not for the value.** `percent`, `toggle`, `choice`, `number`, `text`
  say which control to build. The pack never converts anything for you.

## Setup

Enable the **Game Settings** pack. It registers the `Settings` autoload, so there is nothing to
attach - the vocabulary is in the picker's **Settings** section from any sheet.

Then declare your settings once, load, and apply:

```
On Ready
  -> Settings: Declare Setting  "master_volume", 80, Percent
  -> Settings: Declare Setting  "difficulty", "normal", Choice, "easy|normal|hard"
  -> Settings: Declare Setting  "screen_shake", true, Yes/No
  -> Settings: Load All Settings
  -> Settings: Apply All Settings
```

```gdscript
extends Node


func _ready() -> void:
	Settings.declare_setting("master_volume", 80, "percent", "")
	Settings.declare_setting("difficulty", "normal", "choice", "easy|normal|hard")
	Settings.declare_setting("screen_shake", true, "toggle", "")
	Settings.load_all_settings()
	Settings.apply_all_settings()
```

Every reaction is then an ordinary event:

```
On Setting Changed
  Condition: Settings: Changed Setting Is  "master_volume"
    -> Set Bus Volume (percent)  "Master", Setting Value("master_volume")
```

## ACE reference

On the canvas these read as styled sentences - parameter values in **bold**, exactly as the rows
draw them:

- Declare setting **master_volume** default **80** kind **Percent**
- Set setting **master_volume** to **35**
- Setting **difficulty** is **hard**

### Actions

| Name | Parameters | What it does |
|------|------------|--------------|
| Declare Setting | Setting Name, Default Value, Kind, Choices | Names a setting once. Declaring the same name again replaces the declaration and keeps any value already set. |
| Set Setting | Setting Name, Value | Changes a declared setting and fires On Setting Changed. Setting the value it already holds does nothing; an undeclared name is refused with a warning. |
| Apply All Settings | - | Re-fires On Setting Changed for every declared setting, with the value in force now. |
| Reset Settings To Defaults | - | Forgets every set or loaded value and re-applies them all. |
| Load All Settings | - | Reads saved values for every declared setting out of `user://settings.cfg`. Applies nothing yet. |
| Save All Settings | - | Writes every declared setting's current value into `user://settings.cfg`. |

### Conditions

| Name | Parameters | True when |
|------|------------|-----------|
| Changed Setting Is | Setting Name | The setting being announced is this one. It keeps answering after the announcement, so a reaction that waits can still branch when it resumes. |
| Setting Is | Setting Name, Value | The setting currently holds this value. Usable anywhere, at any time. |
| Setting Is Declared | Setting Name | The setting has been declared at all. |

### Expressions

| Name | Parameters | Gives |
|------|------------|-------|
| Setting Value | Setting Name | The value in force: the one set or loaded, else the declared default. Nothing at all for an undeclared name. |
| Setting Kind | Setting Name | `percent`, `toggle`, `choice`, `number` or `text` - what control a menu should build. |
| Setting Choices | Setting Name | A Choice setting's options as a list, in declared order. Empty for every other kind. |
| Declared Setting Names | - | Every declared name, in declared order. |
| Settings Report | - | Every setting as one readable line: name, kind, value in force, default. |

### Triggers

| Name | Payload | Fires when |
|------|---------|------------|
| On Setting Changed | `setting_name`, `value` | A setting actually changes, and once per setting on Apply All Settings / Reset Settings To Defaults. |

The payload is the signal's own arguments, so the row can read `setting_name` and `value` directly -
there is no "what changed last" expression to get wrong when two settings change in one frame.

## Where the values live

Settings are stored in `user://settings.cfg`, in the section `settings` - deliberately the same FILE
the built-in **Save Setting** action writes to. That action takes its section as a parameter and
offers `audio` in the cell, so the two share values once that row is pointed at the `settings`
section: change the one cell and **Load All Settings** picks the old values up.

That file is *not* a save slot. It survives Start New Run, deleting a save, and switching profiles,
which is what players expect of a volume slider.

The pack also ships the usual `save_state` / `load_state` seam, so the Save System can snapshot the
values with everything else if you want settings inside a slot too. Only the values travel: the
declarations belong to your game's code, so a build that added a setting keeps its new default.

## Use cases

**1. The boot row.** Declare, load, apply - in that order, once.

```
On Ready
  -> Settings: Declare Setting  "master_volume", 80, Percent
  -> Settings: Load All Settings
  -> Settings: Apply All Settings
```

**2. React to one setting.** The reaction lives in the sheet that owns the thing.

```
On Setting Changed
  Condition: Settings: Changed Setting Is  "master_volume"
    -> Set Bus Volume (percent)  "Master", Setting Value("master_volume")
```

```gdscript
extends Node


func _on_settings_setting_changed(setting_name: String, value: Variant) -> void:
	if Settings.changed_setting_is("master_volume"):
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(clampf(float(Settings.setting_value("master_volume")) / 100.0, 0.0, 1.0)))
```

**3. A volume slider.** The slider writes the setting; nothing else in the sheet touches audio.

```
On slider value changed
  -> Settings: Set Setting  "master_volume", slider.value
```

**4. Start the slider where the player left it.** Read the value back when the menu opens - the
declared default is what it reads on a fresh install.

```
On options screen opened
  -> Set Slider Value  ( Setting Value("master_volume") )
```

**5. Save on close.** One row, not one row per setting.

```
On options screen closed
  -> Settings: Save All Settings
```

**6. A Yes/No toggle for an accessibility option.** Reduce motion is the setting players ask for
most, and it costs one declaration and one reaction.

```
On Ready
  -> Settings: Declare Setting  "reduce_motion", false, Yes/No

On Setting Changed
  Condition: Settings: Changed Setting Is  "reduce_motion"
    -> Juice: Set Shake Enabled  ( not Setting Value("reduce_motion") )
```

**7. Difficulty as a Choice.** The options are declared once and the menu reads them back.

```
On Ready
  -> Settings: Declare Setting  "difficulty", "normal", Choice, "easy|normal|hard"

On difficulty dropdown built
  Condition: For Each  ( Setting Choices("difficulty") )
    -> add a dropdown item labelled item
```

**8. Gate a rule on a setting, anywhere.** Setting Is is a plain state check, so it does not need
the trigger at all.

```
On enemy spawned
  Condition: Settings: Setting Is  "difficulty", "hard"
    -> Health: Set Max Health  50
```

**9. The Reset button.** One row puts every default back and re-applies them all.

```
On reset button pressed
  -> Settings: Reset Settings To Defaults
  -> Settings: Save All Settings
```

**10. Build the whole options menu from the declaration.** Loop the names, ask each one its kind,
and build the matching control - adding a setting later adds a control for free.

```
On options screen opened
  Condition: For Each  ( Declared Setting Names )
    -> add a row labelled item
    -> build a slider when Setting Kind(item) = "percent"
    -> build a checkbox when Setting Kind(item) = "toggle"
```

**11. A debug toggle that ships off.** Declared like anything else, so it is in the report, saved
with the rest, and never a stray global.

```
On Ready
  -> Settings: Declare Setting  "show_hitboxes", false, Yes/No

On Every Frame
  Condition: Settings: Setting Is  "show_hitboxes", true
    -> draw the collision shapes
```

**12. Text speed for a dialogue system.** A Number setting read straight into the pack that uses it.

```
On Setting Changed
  Condition: Settings: Changed Setting Is  "text_speed"
    -> Dialogue Kit: Set Characters Per Second  ( Setting Value("text_speed") )
```

**13. A seed setting for daily challenges.** Text kind, read once at the start of a run.

```
On run started
  Condition: Settings: Setting Is Declared  "daily_seed"
    -> Set Random Seed  ( To Integer(Setting Value("daily_seed")) )
```

**14. Two sheets, one setting, no wiring.** The audio sheet and the camera sheet each carry their own
On Setting Changed event; neither knows the other exists.

```
(audio sheet)
On Setting Changed
  Condition: Settings: Changed Setting Is  "music_volume"
    -> Set Bus Volume (percent)  "Music", Setting Value("music_volume")

(camera sheet)
On Setting Changed
  Condition: Settings: Changed Setting Is  "screen_shake"
    -> Juice: Set Shake Enabled  ( Setting Value("screen_shake") )
```

**15. Print what the game offers.** Settings Report is one line per setting, which is exactly what a
bug report or a debug overlay wants.

```
On debug key pressed
  -> Log Message  ( Settings Report )
```

```gdscript
extends Node


func _on_debug_key_pressed() -> void:
	print(Settings.settings_report())
```

**16. Guard against declaration order.** When one sheet declares and another might run first, ask
before reading.

```
On Ready
  Condition: Settings: Setting Is Declared  "master_volume"  (inverted)
    -> Settings: Declare Setting  "master_volume", 80, Percent
```

**17. Apply settings again after loading a save.** If the save carried the values, one row puts them
into force.

```
On save loaded
  -> Settings: Apply All Settings
```

**18. Migrate a project already using Save Setting.** Declare the same names, point the existing
Save Setting rows at the `settings` section, and Load All Settings picks the old values straight out
of `user://settings.cfg` - no conversion step.

```
On Ready
  -> Settings: Declare Setting  "master_volume", 100, Percent
  -> Settings: Load All Settings
```

### Other use cases

**Per-profile settings.** Save All Settings writes one shared file; if you want a set per player profile, snapshot the pack with the Save System's node-state seam instead and keep the shared file for the true machine-wide options.

**Controller layout choice.** A Choice setting whose options are the layout names, with the rebinding pack reacting in On Setting Changed - the same shape as difficulty.

**Quality presets that drive other settings.** A Choice setting whose reaction sets three more settings, each of which fires its own trigger, so one dropdown reconfigures shadows, particles and resolution scale.

**A first-run wizard.** Declare everything, then check Setting Is Declared plus Only Once Ever to walk a new player through the three settings that matter before they ever see the menu.

**Automated screenshots and CI.** A headless run declares the settings, sets the ones the shot needs, and applies them - no menu, no file, exactly the same code path the game uses.

## Tips and common mistakes

- **Declare before anything else touches a setting.** Set Setting refuses an undeclared name with a
  warning, and Setting Value gives nothing back. Declaring in the earliest On Ready you have is the
  habit that avoids this.
- **Load All Settings applies nothing.** It only reads the file. The row after it is Apply All
  Settings; without it the game keeps the old values until something else changes.
- **Apply All Settings fires the trigger for EVERY setting.** That is the point, and it means any
  reaction that is expensive (rebuilding a UI, reloading a scene) runs for all of them at boot. Keep
  reactions cheap, or guard the expensive one with a condition.
- **Changed Setting Is belongs under On Setting Changed.** It answers about the setting being
  announced, and keeps answering about the most recent one after the announcement is over - which is
  what lets a reaction with a Wait row in it still branch when it resumes. Where several settings are
  announced in one go (Apply All Settings) AND the reaction waits, branch on the trigger row's own
  `setting_name` value instead. Use Setting Is for a plain state check anywhere else.
- **Setting a value it already holds fires nothing.** A slider dragged back to where it started is
  not a change - which is what you want, and which will surprise you exactly once while debugging.
- **The kind does not convert anything.** Declaring a setting as Percent does not clamp it to 0-100
  or turn 80 into 0.8; it tells your menu to build a slider. Do the conversion where you use the
  value, as the audio example does.
- **Choices are one string separated by `|`.** `"easy|normal|hard"`. Setting Choices trims each
  piece, and every other kind gives an empty list.
- **Values keep their type.** Declaring a default of `80` and setting `80.0` are different values, so
  Setting Is comparisons behave the way GDScript does. Declare the type you intend to store.
- **Settings are not a save slot.** They live in `user://settings.cfg` on purpose, outside your save
  files, so a wipe never resets the volume. If you truly want them inside a slot, use the Save
  System's node-state seam as well.
- **Re-declaring keeps the current value.** That makes a hot-reloaded sheet safe, and it means
  changing a default in code does not move a player who already saved one.

## Its companion data asset: Color Palette

A colour-blind palette is a setting like any other, but the value it stores is a whole set of
colours rather than a number. The **Color Palette** pack ships as a data asset for exactly that: a
resource holding several named colour sets, one per vision type, each set naming the same roles so
a row that asks for the Danger colour gets the right one whichever set is in use.

Author it as a `.tres` in the Godot Inspector, then swap it at runtime with the **Use palette** row
from the accessibility words. When you fill that row's palette field in, the parameter draws every
colour set the asset carries side by side, so you pick a file by looking at it instead of by trusting
the path you typed:

<img src="../images/palette-param-swatches.png" alt="The Use Palette parameters window: a Palette dropdown holding the variable, a palette asset path field with a Browse button, and under it a swatch grid whose rows are the colour roles Danger, Safe, Neutral and Highlight and whose columns are the colour sets Default, Deuteranopia and Tritanopia, each cell a filled colour chip." width="600">

The pack publishes no verbs of its own - it is the shape of the data, and the accessibility words are
what spend it. Bind the swap to a setting (`Set setting "palette"` then a reaction that runs Use
palette) and the choice survives a restart with everything else in `user://settings.cfg`.
