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
6. [The options screen](#the-options-screen)
7. [Difficulty and assists](#difficulty-and-assists)
8. [Use cases](#use-cases)
9. [Tips and common mistakes](#tips-and-common-mistakes)

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
| Declare Setting | Setting Name, Default Value, Kind, Choices, Page, Label | Names a setting once, and says which options page it belongs on. Declaring the same name again replaces the declaration and keeps any value already set. |
| Set Setting | Setting Name, Value | Changes a declared setting and fires On Setting Changed. Setting the value it already holds does nothing; an undeclared name is refused with a warning. |
| Apply All Settings | - | Re-fires On Setting Changed for every declared setting, with the value in force now. |
| Reset Settings To Defaults | - | Forgets every set or loaded value and re-applies them all. |
| Load All Settings | - | Reads saved values for every declared setting out of `user://settings.cfg`. Applies nothing yet. |
| Save All Settings | - | Writes every declared setting's current value into `user://settings.cfg`. |
| Apply Quality | Preset | Writes every value one quality preset stands for, as ordinary Set Setting changes. Takes a preset file or a path to one; the field lists `res://settings/quality/`. |
| Apply Quality One Step | Step | Moves to the preset one step lighter (-1) or heavier (+1) and applies it. Stops at the ends rather than wrapping. |
| Bind To Setting | Control, Setting Name | Ties one control to one setting, both ways: it shows the value at once, moving it writes the setting, and anything else changing the setting moves it back. |
| Menu Rows From Declarations | Container, Page | Fills a container with one labelled, bound row per setting declared for that page, focus neighbours wired. A control already there and NAMED after a setting is used instead of a generated one. |
| Wire The Focus Order | Controls | Points every control in a list at the next and previous one, so a pad and the Tab key walk the page in the order it is drawn. |
| Apply With A Way Back | Seconds | Remembers every setting as it stands and starts a countdown. Nothing answering it puts them all back. |
| Keep These Settings | - | The player said yes: the countdown stops, the way back is forgotten, On Settings Kept fires. |
| Go Back To The Working Settings | - | Puts every setting back the way it was, through ordinary Set Setting changes, and fires On Settings Reverted. |
| Controls Page From The Input Map | Container | Fills a container with one row per project action: its name, its keyboard binding, its pad binding and a reset, all kept current. |
| Listen For A New Binding | Action, Device | Waits for a key, mouse button or pad button and gives it to this action. A taken key fires On Binding Conflict instead. |
| Take The Binding Anyway | - | The first answer to a conflict: this action takes the key, and the one that had it is left without it. |
| Swap The Binding | - | The second answer: the two actions trade keys on that device, so nobody is left without one. |
| Pick Another Key | - | The third answer: forget the key that was taken and go on listening. |
| Stop Listening For A Binding | - | Stops waiting and leaves every binding as it was. |
| Reset One Binding | Action | Puts one action back to the bindings your project ships with, on every device. |
| Reset Every Binding | - | The same for every action - the page-level Reset All. |
| Save Bindings | - | Writes every action's bindings into `user://settings.cfg`, in the section `bindings`. |
| Load Bindings | - | Reads them back into the Input Map. An action with nothing saved keeps the binding you designed. |
| Use Difficulty | Difficulty | Puts one difficulty in force: a difficulty file, a path to one, or the word it goes by. Its factors become the ones Difficulty Factor answers from. Naming nothing clears it. |
| Use The Difficulty A Setting Names | Setting Name | Puts in force whichever difficulty a declared setting names - its value being a path or the word one goes by. The row that makes the difficulty an ordinary setting. |
| Declare Assist | Assist Name, Default On | Declares one accessibility assist: a yes-or-no setting on the Accessibility page, and a name Assist Is On and On Assist Changed can speak about. |

### Conditions

| Name | Parameters | True when |
|------|------------|-----------|
| Changed Setting Is | Setting Name | The setting being announced is this one. It keeps answering after the announcement, so a reaction that waits can still branch when it resumes. |
| Setting Is | Setting Name, Value | The setting currently holds this value. Usable anywhere, at any time. |
| Setting Is Declared | Setting Name | The setting has been declared at all. |
| Quality Is | Word | The quality in force goes by this word. "Custom" is true whenever the values match no preset file. |
| Control Has No Binding | Action | The action has no binding left on any device - what the amber mark on a Controls page row is for. |
| Waiting For A Key | - | A row is listening for a key or button right now. |
| Difficulty Is | Word | The difficulty in force goes by this word, letter case ignored. Nothing matches while none has been chosen. |
| Assist Is On | Assist Name | That declared assist is switched on. A name nobody declared as an assist reads as off. |

### Expressions

| Name | Parameters | Gives |
|------|------------|-------|
| Setting Value | Setting Name | The value in force: the one set or loaded, else the declared default. Nothing at all for an undeclared name. |
| Setting Kind | Setting Name | `percent`, `toggle`, `choice`, `number` or `text` - what control a menu should build. |
| Setting Choices | Setting Name | A Choice setting's options as a list, in declared order. Empty for every other kind. |
| Declared Setting Names | - | Every declared name, in declared order. |
| Settings Report | - | Every setting as one readable line: name, kind, value in force, default. |
| Quality Preset Paths | - | Every preset in `res://settings/quality/`, lightest first by each file's own Rank. |
| Quality Preset Names | - | The words those presets go by, in the same order - drop it straight into a dropdown. |
| Quality Preset Path | - | The preset file whose values are all in force, or nothing when none matches. |
| Quality Name | - | The word to show a player: the matching preset's, or "Custom". |
| Binding Mismatch | Control, Setting Name | Why a control and a setting do not belong together, in one sentence, or nothing at all when they do. |
| Setting Page | Setting Name | Which options page the setting was declared for. |
| Setting Label | Setting Name | The words a menu shows: the declared label, or the name opened out (`screen_shake` reads Screen shake). |
| Settings On Page | Page | Every setting declared for that page, in declared order. |
| Unreachable Controls | Container | The names of the controls a keyboard or pad cannot get to. Empty is the answer you want. |
| Seconds Left To Keep | - | How long the player has left to answer Apply With A Way Back, or 0 when nothing is waiting. |
| Project Actions | - | Every action your project declares in its Input Map, leaving out the engine's own `ui_` ones. |
| Keyboard Binding Of | Action | The key or mouse button it answers to, in words. Blank when it has none. |
| Pad Binding Of | Action | The gamepad button it answers to, in words. Blank when it has none. |
| Unbound Actions | - | Every action with no binding left on any device. |
| Conflicting Control | - | The action that already answers to the key just pressed, while a conflict waits. |
| Pending Binding Words | - | That key, in words, while the conflict waits. |
| Difficulty Factor | Key | One named factor of the difficulty in force. 1.0 while none has been chosen, and 1.0 when the one in force has no such key. |
| Difficulty Name | - | The word the difficulty in force goes by - its own, or its file name capitalised. Blank while none has been chosen. |
| Difficulty Names | Folder | The words the difficulty files in a folder go by, in file-name order. Drop it into a dropdown. |

### Triggers

| Name | Payload | Fires when |
|------|---------|------------|
| On Setting Changed | `setting_name`, `value` | A setting actually changes, and once per setting on Apply All Settings / Reset Settings To Defaults. |
| On Settings Kept | - | The player answered Apply With A Way Back with Keep These Settings. |
| On Settings Reverted | - | The way back was taken: by Go Back, or by the countdown running out. |
| On Binding Changed | `action` | An action's bindings changed - rebound, swapped, taken from, or reset. |
| On Binding Conflict | `action`, `taken_by` | The key a player pressed already belongs to another action. Nothing has changed yet. |
| On Difficulty Changed | `difficulty` | A difficulty was put in force, or cleared. The payload is the word it goes by, blank when it was cleared. |
| On Assist Changed | `assist_name`, `on` | A declared assist was switched on or off. It fires beside On Setting Changed, never instead of it. |

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

Rebindings live in the same file, in the section `bindings` - **Save Bindings** and **Load Bindings**
put them there and take them back, so one save covers the volume and the jump key together.

## The options screen

Every options menu is the same four pages and the same glue written twice per option. This pack takes
the glue.

**One control, one row, both directions.** A slider that writes `music_volume` and a `music_volume`
that moves the slider are one fact seen twice, so they are one row:

- On ready: **Bind** *MusicSlider* **to setting music_volume**
- On ready: **Bind** *FullscreenCheck* **to setting fullscreen**

The control shows the value the moment it is bound, so nothing has to be poked into it at startup. A
quality preset, **Reset Settings To Defaults** or a second menu still open all move it back, because
the binding hangs off the announcement rather than off the menu. A dropdown with no items yet takes
the setting's declared choices. What the setting *does* stays where it belongs: an ordinary **On
setting changed** event branched by name.

If the pair do not fit - a checkbox bound to a percent - the output log says which is which as it
binds, and **Binding Mismatch** hands you the same sentence to show in your own words:

> `music_volume is a percent and wants a slider - this is a checkbox.`

**The page builds itself.** Declare a setting with a page, and it has a row:

- **Declare setting screen_shake** default **on** kind **Yes/No** page **Accessibility**
- On ready: **Menu rows on** *AccessibilityPage* **from the Accessibility declarations**

That is the whole of adding an option later: one Declare row, no scene edit and no new binding glue.
The generated rows are plain Godot controls in a plain container - restyle them, theme them, move
them. A control you made yourself and NAMED after a setting is used instead of a generated one, so a
designed slider simply replaces its row; there is no lock-in in either direction.

**The focus neighbours are wired as the page is built.** A pad's up and down and the Tab key walk the
page in the order it is drawn, from the first frame. Call **Wire The Focus Order** yourself after
adding controls to a hand-made page, and ask **Unreachable Controls** what a keyboard cannot get to -
an options menu that needs a mouse is a bug found at certification rather than in the studio.

**Video changes get a way back.** Apply a screen mode the monitor cannot show and the menu you need
in order to undo it is the thing you cannot see. So apply first, ask second, and take silence for a
no:

- On **Apply pressed**: **Apply with a way back for 10 s**, then your Set Setting rows
- On **Settings reverted**: close the dialog - the countdown has already put every value back

Show **Seconds Left To Keep** in the label so the countdown is visible, and answer it with **Keep
These Settings**.

**The Controls page comes from the Input Map.**

- On ready: **Controls page on** *ControlsList* **from the Input Map**

One row per action your project declares, keyboard and pad in separate columns, a reset on each row.
Actions added to the project later appear on their own. Pressing a binding listens for a new one, and
a key that is already taken fires **On Binding Conflict** rather than quietly stacking two actions on
one key - nothing has changed at that point, and there are exactly three answers to offer:

| Row | What the player gets |
|-----|----------------------|
| **Swap the binding** | The two actions trade keys. Nobody is left without one, so offer it first. |
| **Take the binding anyway** | This action takes the key; the other is left without it, turns up in **Unbound Actions**, and its row goes amber. |
| **Pick another key** | Nothing changes and the row goes on listening. |

Doctor's Options section asks the three questions nobody thinks to: an action with **no binding on any
device**, a quality preset that **says nothing about a setting its neighbours answer for** (which is
what makes Low after High a different Low from Low after Medium), and a project that **chooses a
difficulty no row reads a factor out of**, which is a difficulty menu that changes nothing. Each is a
note in the Doctor's inbox and a quiet amber state on the row - never a block drawn inside the sheet.

## Difficulty and assists

### A difficulty is a file

A difficulty is not a global enum and not an `if` in front of every damage row. It is a
**Difficulty** `.tres`: the word a player picks, a line for the menu, and a dictionary of named
**factors** your rows multiply by where they care.

```
On Ready
  -> Settings: Use difficulty  "normal"

On Damaged
  -> Player: Take damage of type  Player.last_damage, "physical", attacker, scaled by "damage_taken"
```

Three things follow from the file being the truth, and each is the point:

- **The folder is the list.** **Difficulty Names** reads a folder live, so adding a difficulty is
  adding a file and deleting one is deleting a file. Hand whichever word the player picked straight
  back to **Use Difficulty**.
- **A missing factor is 1.0.** **Difficulty Factor** answers 1 while no difficulty has been chosen,
  and 1 when the one in force has no such key. So a row can multiply by `enemy_count` before any
  difficulty file mentions it and go on behaving exactly as it did - adding a difficulty is never a
  rewrite of the rows it affects.
- **Nothing happens on its own.** A factor changes something because a row multiplied by it. Keys
  nothing reads are simply unread, which is why the Doctor's third question is worth asking.

The difficulty in force is kept as **metadata on `Engine`** rather than inside this autoload, the
same way the built-in accessibility dials are. That is what lets any script read a factor in one
line, and it is exactly what the Health pack's **Scaled By** field reads - so a typed hit can name a
factor without either pack knowing the other exists.

Make the choice an ordinary setting and it saves, resets and re-applies with everything else:

```
On Setting Changed
  Condition: Settings: Changed setting is  "difficulty"
  -> Settings: Use the difficulty setting "difficulty" names
```

**Three starters ship** beside the Difficulty class - easy, normal and hard - and they are files to
open, not a set to use. Retune them, rename them, duplicate one into a fourth, or delete the ones
your game has no use for. They are listed in file-name order, so name them the way you want them
read.

### An assist is a setting that says it is one

**Declare Assist** takes a name and a default and does three things at once: it declares an ordinary
yes-or-no setting, it puts that toggle on the **Accessibility** page **Menu Rows From Declarations**
already builds, and it records the name so **Assist Is On** and **On Assist Changed** can speak about
it. Everything else about it is an ordinary setting - saved with the rest, reset with the rest,
re-applied by **Apply All Settings** with the rest.

```
On Ready
  -> Settings: Declare assist  "invincible", default false
  -> Settings: Declare assist  "infinite_ammo", default false

On Assist Changed
  Condition: Settings: Assist  "invincible"  is on
  -> Player: Set invulnerable  true
```

**The pack enforces nothing.** What an assist DOES is your rows' business: `invincible`,
`infinite_ammo` and `skip_this_puzzle` above are names a project declares for itself, not a
vocabulary shipped in code. Game speed is worth calling out as the one that is already built - the
engine's own playback speed row is the whole of it, so declare the assist and let one reaction set
it.

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

## Its other companion data asset: Quality Preset

A graphics quality word - Low, Medium, High - is not a setting of its own. It is a set of values over
settings that already exist, which is why picking Medium is the same thing as nudging msaa,
resolution scale and debanding by hand, and why a save file carries those three values rather than
the word.

So each word is a FILE: a **Quality Preset** `.tres` in `res://settings/quality/`. The folder is the
list. The Apply Quality field lists it, an options dropdown lists it, and adding a preset is adding a
file - there is nothing to register anywhere. **New preset** in that field copies the one you had
picked and opens it in the Inspector; on an empty folder it writes Low, Medium and High to start
from. Duplicating the `.tres` in the FileSystem dock yourself does exactly the same thing.

Each preset carries three things: the word a player sees (blank means the file name), a **Rank**
saying how heavy it is - which is the order "one step lower" walks - and the **values**, one per
setting it answers for.

**Every key of Values is a field of its own in the Inspector**, named and typed by what is stored
under it. That is what makes a preset a macro over your settings rather than a fixed schema: declare
`motion_blur` as an ordinary setting, put it in the presets, and every preset file has a motion blur
field from then on. Your `On setting changed / motion_blur` event does the actual work, exactly as it
does for every other setting.

**"Custom" is worked out, never stored.** Quality Name compares the values in force against each
preset file: match `low.tres` and it says Low, match nothing and it says Custom. There is no stored
preset flag to fall out of step, so nudging one graphics setting flips the label on its own. Three
things follow from that, and each is worth having:

- a custom setup survives an update, because what was saved is the values;
- deleting a preset file cannot break anyone's game - their values still load, and the label simply
  reads Custom;
- editing a preset file changes what the WORD means, not what any player already has.

Keep the individual rows (Set MSAA, Set 3D Resolution Scale) for the moments a preset is too blunt.
They are the truth; the preset is the shorthand.

## Its third companion data asset: Difficulty

A difficulty word - Easy, Normal, Hard - is not a setting of its own either. It is a set of NUMBERS
your rows multiply by, which is why choosing Hard is the same thing as writing 1.5 into the places
that were going to be harder, and why nothing changes until some row asks for a factor.

So each word is a FILE: a **Difficulty** `.tres`, holding the word a player sees (blank means the
file name), a line for the menu, and the **factors**. **Every key of Factors is a field of its own in
the Inspector**, named and typed by what is stored under it - so a factor invented today is an
ordinary row in every difficulty file tomorrow.

The three starters ship with four keys because those are the four most games reach for first, and not
because the pack means anything by them:

| Factor | What a row does with it |
|--------|-------------------------|
| `damage_taken` | Multiplies a hit on the player - the Health pack's **Scaled By** field is this row, without the multiplication. |
| `damage_dealt` | Multiplies a hit the player lands. |
| `enemy_count` | Multiplies a wave size, a spawn count, a patrol's population. |
| `timer_scale` | Multiplies a time limit, a fuse, a countdown. |

Rename them, delete them, invent your own. A key nothing reads is unread; a key no difficulty writes
reads as 1. The one rule worth keeping is that a factor should read as a MULTIPLIER, so that 1 means
"as designed" - which is what makes a missing key safe and a cleared difficulty harmless.
