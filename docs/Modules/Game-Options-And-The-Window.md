# Game Options and the Window

This is the vocabulary an options screen is built from: the OS window (fullscreen, size, position,
always-on-top, title), the two performance switches every settings menu carries (vsync and the
frame-rate cap), and the small persistence pair that makes a choice survive a restart
(**Save Setting** / **Load Setting Into Variable**).

Everything compiles to the plain Godot you would hand-write - `get_window().mode = ...`,
`DisplayServer.window_set_vsync_mode(...)`, `Engine.max_fps = ...`, a `ConfigFile` in `user://` -
with no plugin runtime behind it. The audio half of an options menu (volume sliders, mute) lives in
the Sound and Music guide; the graphics half (MSAA, resolution scale, debug draw) lives in the
Cameras, Graphics and Screenshots guide.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Verb reference](#verb-reference)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **A Video tab** with fullscreen, resolution and vsync switches.
- **Alt+Enter fullscreen** on one row.
- **A borderless window** that starts centered at the size the player last chose.
- **A frame-rate cap** so laptops stay cool and fans stay quiet.
- **Settings that survive a restart**, written to one config file.
- **A window title** that shows the level name, the save slot, or a debug build marker.
- **A "keep on top" toggle** for tool-like or streaming-friendly builds.
- **A resolution list** built from the player's own screen size.
- **A first-run default pass** that only applies when nothing has been saved yet.
- **Minimize on lost focus** for windowed builds, restored from a hotkey.

## Core concepts

- **There are two families of window verbs, and they behave the same.** The **Game Window** section
  goes through `get_window()`, and the **Display** section goes through `DisplayServer`. Both change
  the same window. Pick one family per project and stay in it, because a **Set Window Size** row from
  each looks identical on the canvas and takes a different parameter shape.
- **Fullscreen is a mode, not a flag.** **Go Fullscreen** is borderless fullscreen,
  **Go Exclusive Fullscreen** takes over the display, **Go Windowed** goes back, and
  **Toggle Fullscreen** flips between windowed and borderless. **Is Fullscreen** answers true for
  either fullscreen mode, which is what a toggle button's label wants.
- **Minimize and maximize are modes too.** They set `Window.MODE_MINIMIZED` / `MODE_MAXIMIZED`, so
  restoring a minimized window is **Go Windowed**, not an "unminimize" verb.
- **Sizes are pixels, positions are screen pixels.** **Set Window Size** takes Width and Height as
  separate ints in the Game Window family; the Display family takes one `Vector2i`. **Window Size**
  and **Screen Size** read them back, and the second is how you build a sane resolution list.
- **Setting a size does not move the window.** Follow a resize with **Center Window** unless you have
  a reason not to.
- **Vsync and the FPS cap are unrelated.** Vsync ties frames to the monitor's refresh;
  `Engine.max_fps` is a hard cap on top. Games ship both because players want both.
- **Persistence is one file, `user://settings.cfg`.** The **Game Options** **Save Setting** writes to
  that fixed path. The **Utility: Settings** **Save Setting** takes the path as a parameter and
  defaults to the same file, and **Load Setting Into Variable** is its reader, with a fallback
  default for a key that was never written.
- **Nothing is applied for you.** Saving a setting stores a number; a stored number changes nothing
  until a row reads it back and calls the matching verb on startup.

## Verb reference

Multi-line templates are shown by their first line; the full emitted block appears in the matching
use case below.

### Fullscreen and window mode (picker section: Game Window)

| Verb | What it does | Ships as |
|------|--------------|----------|
| Go Fullscreen | Switches to borderless fullscreen. | `get_window().mode = Window.MODE_FULLSCREEN` |
| Go Windowed | Switches back to a normal window. | `get_window().mode = Window.MODE_WINDOWED` |
| Go Exclusive Fullscreen | Takes over the whole display. | `get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN` |
| Toggle Fullscreen | Flips between fullscreen and windowed. | `get_window().mode = Window.MODE_WINDOWED if get_window().mode != Window.MODE_WINDOWED else Window.MODE_FULLSCREEN` |
| Minimize Window | Minimizes to the taskbar. | `get_window().mode = Window.MODE_MINIMIZED` |
| Maximize Window | Maximizes the window. | `get_window().mode = Window.MODE_MAXIMIZED` |
| Is Fullscreen | True in either fullscreen mode. | `(get_window().mode == Window.MODE_FULLSCREEN or get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN)` |

### Size, position and behaviour (picker section: Game Window)

| Verb | What it does | Ships as |
|------|--------------|----------|
| Set Window Size | Resizes the window to an exact pixel size (Width, Height). | `get_window().size = Vector2i({width}, {height})` |
| Set Window Position | Moves the window on the screen (X, Y). | `get_window().position = Vector2i({x}, {y})` |
| Center Window | Centers the window on the screen. | `get_window().move_to_center()` |
| Set Always On Top | Keeps the window above every other window. | `get_window().always_on_top = {enabled}` |
| Set VSync Enabled | Turns vertical sync on or off. | `DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if {enabled} else DisplayServer.VSYNC_DISABLED)` |
| Set Max FPS | Caps the frame rate (0 = uncapped). | `Engine.max_fps = {fps}` |
| Max FPS | The current frame-rate cap. | `Engine.max_fps` |

### The Display family (picker section: Display)

| Verb | What it does | Ships as |
|------|--------------|----------|
| Set Fullscreen Mode | Picks a window mode from a dropdown (fullscreen, exclusive fullscreen, windowed, maximized). | `DisplayServer.window_set_mode({mode})` |
| Set Window Size | Resizes the window, taking one Vector2i Size. | `DisplayServer.window_set_size({size})` |
| Window Width | The current window width in pixels. | `DisplayServer.window_get_size().x` |
| Viewport Width | How wide the visible layout is, in pixels. | `get_viewport_rect().size.x` |
| Viewport Height | How tall the visible layout is, in pixels. | `get_viewport_rect().size.y` |
| Window Height | The current window height in pixels. | `DisplayServer.window_get_size().y` |
| Is Fullscreen | True while the window is in either fullscreen mode. | `(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)` |

The Mode dropdown on **Set Fullscreen Mode** offers exactly
`DisplayServer.WINDOW_MODE_FULLSCREEN`, `DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN`,
`DisplayServer.WINDOW_MODE_WINDOWED` and `DisplayServer.WINDOW_MODE_MAXIMIZED`.

### Title and screen (picker section: Utility: Window)

| Verb | What it does | Ships as |
|------|--------------|----------|
| Set Window Title | Changes the text in the title bar. | `get_window().title = {title}` |
| Window Size | The window's current size in pixels (a Vector2i). | `get_window().size` |
| Screen Size | The size of the player's monitor in pixels. | `DisplayServer.screen_get_size()` |

### Knowing where the game is running (picker section: Platform)

| Verb | What it does | Ships as |
|------|--------------|----------|
| OS Name | The name of the operating system the game is running on, as text ("Windows", "Android", "Web"). | `OS.get_name()` |
| Platform Has Feature | True when the current platform supports the given Feature tag. The Feature cell defaults to `"mobile"` and offers the common tags (`"pc"`, `"web"`, `"android"`, `"ios"`, `"windows"`, `"linux"`, `"macos"`, `"editor"`, `"debug"`, `"release"`, `"touchscreen"` and more), and you can type a custom tag your export preset defines. | `OS.has_feature({feature})` |

Prefer Platform Has Feature over OS Name when you are gating behaviour: a feature tag answers the
question you actually have ("is this a touch device?", "is this a debug build?") on every platform at
once, while OS Name is best kept for showing or logging which system the player is on.

### Saving a choice (picker sections: Game Options and Utility: Settings)

| Verb | What it does | Ships as |
|------|--------------|----------|
| Save Setting (Game Options) | Writes one Section / Key / Value into `user://settings.cfg`, keeping the other settings intact. | `var __cfg_{uid} = ConfigFile.new()` … (multi-line, use case 12) |
| Has Saved Settings | True when a settings file has been saved before. | `FileAccess.file_exists("user://settings.cfg")` |
| Save Setting (Utility: Settings) | The same write, but the File path is a parameter (default `"user://settings.cfg"`). | `var __cfg_{uid} = ConfigFile.new()` … (multi-line, use case 13) |
| Load Setting Into Variable | Reads a saved value into a variable, with a fallback Default when the key is missing. | `var __cfg_{uid} = ConfigFile.new()` … (multi-line, use case 13) |

## Use cases

**1. Alt+Enter fullscreen.** One condition, one action, no state to track:

```gdscript
if Input.is_action_just_pressed(&"toggle_fullscreen"):
	get_window().mode = Window.MODE_WINDOWED if get_window().mode != Window.MODE_WINDOWED else Window.MODE_FULLSCREEN
```

**2. A three-way display dropdown.** Windowed, borderless, exclusive - three rows under three
conditions on the dropdown's selected index:

```gdscript
get_window().mode = Window.MODE_WINDOWED
```

```gdscript
get_window().mode = Window.MODE_FULLSCREEN
```

```gdscript
get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
```

**3. A fullscreen checkbox that shows the truth.** Put **Is Fullscreen** on the condition side and
set the checkbox from it when the options screen opens:

```
On Ready
  Condition: Is Fullscreen
    -> Set Button Pressed  true  (On node $FullscreenCheck)
  Else
    -> Set Button Pressed  false  (On node $FullscreenCheck)
```

**4. Apply a chosen resolution.** **Set Window Size** then **Center Window**, so the window does not
end up half off the screen:

```gdscript
get_window().size = Vector2i(1920, 1080)
get_window().move_to_center()
```

**5. Never offer a mode bigger than the player's monitor.** **Screen Size** feeds a
**Compare Values** condition, and the 1080p button is only enabled when it fits:

```
On Ready
  Condition: Compare Values  Screen Size.x >= 1920
    -> Set Button Disabled  false  (On node $Res1080Button)
  Else
    -> Set Button Disabled  true  (On node $Res1080Button)
```

**6. Park the window in a corner** for a streaming or debug layout, with **Set Window Position**:

```gdscript
get_window().position = Vector2i(40, 40)
```

**7. Keep a companion build on top** with **Set Always On Top**:

```gdscript
get_window().always_on_top = true
```

**8. A vsync toggle.** The template already turns your bool into the right enum:

```gdscript
DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if $VsyncCheck.button_pressed else DisplayServer.VSYNC_DISABLED)
```

**9. An FPS cap dropdown, including "unlimited".** 0 means uncapped, so the "Unlimited" entry is just
a 0:

```gdscript
Engine.max_fps = 60
```

```gdscript
Engine.max_fps = 0
```

**10. Show the current cap in the menu** with the **Max FPS** expression, spelling 0 out for the
player:

```gdscript
$FpsLabel.text = str("Unlimited" if Engine.max_fps == 0 else str(Engine.max_fps))
```

**11. A title bar that says where you are**, with **Set Window Title**:

```gdscript
get_window().title = "My Game - " + level_name
```

**12. Save the player's choices.** One **Save Setting** row per setting. The Game Options form always
writes `user://settings.cfg`:

```gdscript
var __cfg_b1 = ConfigFile.new()
__cfg_b1.load("user://settings.cfg")
__cfg_b1.set_value("video", "fullscreen", true)
__cfg_b1.save("user://settings.cfg")
```

Each row loads the file first, so saving one key never wipes the others.

**13. Load them back on startup and APPLY them.** **Load Setting Into Variable** reads into a sheet
variable; the row after it is what actually changes the game:

```gdscript
var __cfg_b2 = ConfigFile.new()
__cfg_b2.load("user://settings.cfg")
saved_fullscreen = __cfg_b2.get_value("video", "fullscreen", false)
```

```
On Ready
  -> Load Setting Into Variable  saved_fullscreen  ("video" / "fullscreen", default false)
  Condition: Compare variable  saved_fullscreen == true
    -> Go Fullscreen
```

**14. First run versus every run after.** **Has Saved Settings** is the guard that lets you apply
your own defaults exactly once:

```
On Ready
  Condition: Has Saved Settings  (inverted)
    -> Set Window Size  1280 x 720
    -> Center Window
    -> Set VSync Enabled  true
    -> Save Setting  "video" / "configured" = true
```

**15. A reset-to-defaults button.** The same block as use case 14, without the guard, run from the
button's **On Pressed** event.

**16. Cap the frame rate on battery-powered platforms.** Under a
**Platform Has Feature** `"mobile"` condition:

```gdscript
Engine.max_fps = 30
```

**17. Minimize from a hotkey, restore from another.** Minimize is a mode, and **Go Windowed** is the
way back:

```gdscript
get_window().mode = Window.MODE_MINIMIZED
```

```gdscript
get_window().mode = Window.MODE_WINDOWED
```

**18. Start maximized without being fullscreen**, which many players prefer for windowed play:

```gdscript
get_window().mode = Window.MODE_MAXIMIZED
```

**19. A HUD that adapts to the window.** **Window Width** and **Window Height** read the live size,
so a layout switch is one condition:

```gdscript
if DisplayServer.window_get_size().x < 900:
	$Hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
```

**20. Remember the window size the player left the game at.** Save it when the window's close is
requested, load it on startup:

```gdscript
var __cfg_b3 = ConfigFile.new()
__cfg_b3.load("user://settings.cfg")
__cfg_b3.set_value("video", "window_size", get_window().size)
__cfg_b3.save("user://settings.cfg")
```

`ConfigFile` stores a `Vector2i` faithfully, so the load side needs no parsing.

**21. A debug build marker.** Under a **Platform Has Feature** `"debug"` condition:

```gdscript
get_window().title = "My Game (DEBUG)"
```

### Other use cases

**A photo-mode window.** Set Always On Top plus a small Set Window Size, restored to the player's saved size when photo mode closes.

**Kiosk or exhibition builds.** Go Exclusive Fullscreen on ready, with the fullscreen toggle row simply not present, so the build cannot be windowed by accident.

**A battery saver toggle.** One switch that sets Max FPS to 30 and vsync on, and back to the player's saved values when it is turned off.

**Per-profile settings files.** The Utility: Settings Save Setting takes the path as a parameter, so `user://profile_a.cfg` and `user://profile_b.cfg` are two rows apart.

**A "your monitor is smaller than this" warning.** Compare Screen Size against the chosen resolution before applying it, and offer the next size down instead.

## Tips and common mistakes

- **Two verbs are called Set Window Size and two are called Is Fullscreen.** The **Game Window**
  versions take Width and Height as separate numbers and read `get_window()`; the **Display**
  versions take a single `Vector2i` and go through `DisplayServer`. They do the same thing to the
  same window - just do not mix them inside one project, or a later reader cannot tell which row is
  which.
- **Two verbs are called Save Setting, too.** The **Game Options** one has no File parameter and
  always writes `user://settings.cfg`; the **Utility: Settings** one takes the path. **Has Saved
  Settings** only ever checks `user://settings.cfg`, so it does not know about your other files.
- **Set Max FPS appears twice as well** - once under **Game Window** (`Engine.max_fps = {fps}`, an
  int parameter) and once under **Time** (`Engine.max_fps = int({fps})`, taking any expression). The
  second is the one to use when the value comes from a variable that might be a float.
- **Saving a setting changes nothing.** Persistence and application are separate rows. A settings
  screen that only saves looks broken on the next launch until you add the load-and-apply block from
  use case 13.
- **`res://` is read-only in an exported game.** Settings must live under `user://`. Both Save
  Setting verbs default to a `user://` path for that reason.
- **A missing key is not an error.** **Load Setting Into Variable** takes a Default, which is what
  you get back the first time. Choose a default that is a sane setting, not a placeholder.
- **Resizing does not reposition.** After **Set Window Size**, add **Center Window** unless you are
  also setting the position yourself.
- **Fullscreen ignores the size you set.** Setting a window size while fullscreen is silently
  pointless; go windowed first, then resize.
- **Exclusive fullscreen can be slow to leave** on some drivers, and it hides other windows. Borderless
  (**Go Fullscreen**) is the friendlier default for most games.
- **Uncapped is 0, not -1.** `Engine.max_fps = 0` means "no cap"; a negative value is not a supported
  way to say the same thing.
- **Always On Top annoys players** when it is on by default. Make it opt-in, and never leave it on
  after a mode that turned it on temporarily.
- **The window title is not localised for you.** If your game ships translations, build the title
  from a translated string rather than a literal.
