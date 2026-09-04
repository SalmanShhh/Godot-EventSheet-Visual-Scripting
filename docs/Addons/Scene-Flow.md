# Scene Flow - Polished Scene Changes From One Node

Scene Flow is a Godot EventSheets behavior pack that gives a whole menu (or a whole game) its scene changes without a line of hand-written code. You attach a `SceneFlowBehavior` behavior to any `Node` and it gains five actions: fade to another scene, fade-reload the current one, jump instantly to a scene, reload instantly, and quit the game. The fade is the star: when you call **Fade To Scene** or **Fade Reload Scene**, a full-screen overlay fades out, the swap happens under the cover, then it fades back in - and because that overlay parents itself to the tree root instead of the dying scene, the transition never dies halfway through the swap. It is the classic "my fade vanished the instant the scene changed" trap, solved once. Set the fade color and duration in the Inspector, drop the actions on your buttons, and a title screen, a game-over retry, and a quit button all work with zero code.

---

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [Transitions - a shape drawn over the change](#transitions---a-shape-drawn-over-the-change)
5. [Loading screens - a screen of your own while the next scene loads](#loading-screens---a-screen-of-your-own-while-the-next-scene-loads)
6. [ACE reference](#ace-reference)
7. [Reading it from expressions - the Self section](#reading-it-from-expressions---the-self-section)
8. [Use cases](#use-cases)
9. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Title screen Play button.** One **Fade To Scene** row on the button press takes the player into the first level with a clean fade, no tween code.
- **Game-over retry.** **Fade Reload Scene** restarts the current level with a fade - the polished retry button, ready out of the box.
- **Quit button.** **Quit Game** exits cleanly, and it is a safe no-op on platforms that forbid quitting (like web), so the same button ships everywhere.
- **Level-to-level progression.** At the end of a level, **Fade To Scene** the next `.tscn` and the player glides forward instead of hard-cutting.
- **Checkpoint respawn.** On death, **Fade Reload Scene** (or the instant **Reload Scene**) drops the player back at the top of the current scene.
- **Pause menu "Return to Title".** A pause overlay button runs **Fade To Scene** back to the main menu.
- **Splash / logo boot sequence.** After a short timer on the splash scene, **Go To Scene** the main menu with no fade for a snappy hand-off.
- **Instant hazard warp.** A door or portal that should feel immediate uses **Go To Scene** so there is no fade delay.
- **Confirm-before-quit dialogs.** Wire the dialog's Yes button to **Quit Game** and its No button to just close the dialog.
- **Debounced buttons.** Guard every transition with **Is Transitioning** so a mashed button cannot fire two scene changes at once.
- **Scene-aware logic.** Read **Current Scene Path** to branch behavior (play different music, show different UI) based on which scene file is live.
- **Consistent look across a whole game.** Set `fade_color` and `fade_seconds` once per menu node and every faded change matches.
- **A level that takes a beat to open.** **Go To Scene With Loading** shows a screen of your own while the next scene comes off the disk, with a bar, a tip, and a shortest time so it cannot flash past on a fast machine.

---

## Core concepts

The heart of the pack is five actions, one condition, and one expression, with the shaped transitions and the loading screens built on top of them. Learn these five ideas and you have all of it.

**It is a behavior you attach to a node, and it acts on the whole game.** You add a `SceneFlowBehavior` as a child of some node - a menu Control, a HUD, a persistent manager, anything that is a `Node`. Its actions all talk to the running scene tree (`get_tree()`), not just to the node you attached it to. So where you attach it barely matters as long as that node is alive in the current scene when you call the action. A common choice is the root node of each menu or level scene that needs scene-flow buttons.

**Faded changes vs instant changes.** There are two flavors of every swap. The faded ones - **Fade To Scene** and **Fade Reload Scene** - cover the screen, swap, and uncover, using the Inspector color and duration. The instant ones - **Go To Scene** and **Reload Scene** - swap immediately with no overlay. Use faded for menus and level ends where a beat of polish helps; use instant for warps and boots where you want zero delay.

**The fade overlay outlives the old scene.** When a faded action runs, it spawns a full-screen overlay that parents itself to the tree root, above everything (it uses a very high canvas layer). Because it lives on the root and not inside the scene being replaced, the fade-out, the scene swap, and the fade-in all keep running across the change. This is the reason your transition does not blink out the instant the scene changes.

**One transition at a time.** While a faded transition is running, another **Fade To Scene** or **Fade Reload Scene** is ignored (it just returns). The **Is Transitioning** condition reports whether a fade is in flight, so you can gray out buttons or gate input while it plays. The instant actions do not use the overlay, so they are not gated by this - reserve **Is Transitioning** for guarding faded flows.

**Reload vs Go To.** "Reload" restarts the scene that is already running - same file, fresh state (**Reload Scene** instantly, **Fade Reload Scene** with a fade). "Go To" loads a different scene file by its `res://` path (**Go To Scene** instantly, **Fade To Scene** with a fade). The path is a string like `"res://scenes/level_2.tscn"`; an empty or blank path is ignored so a mistyped row cannot blank your game.

**Quit is safe.** **Quit Game** asks the engine to shut down. On platforms that forbid it (web, for instance) it is simply a no-op, so you can ship the same quit button to every export without special-casing it.

The pack also surfaces the host node's own properties and methods to the picker (it is generated with node reflection turned on), so on a Control host you can still reach things like `visible` from the same rows - but the five scene actions above are the pack's real job.

---

## Setup

**1. Attach the behavior.** Add a `SceneFlowBehavior` behavior as a child node of a node that lives in the scene where you want the buttons - usually the menu or level root (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in). It needs a `Node` parent; any node type qualifies.

**2. Set the Inspector knobs.** Select the behavior node and dial in the fade feel:

| Property | Default | What it does |
|---|---|---|
| `fade_color` | opaque black | The cover color the screen fades through during faded transitions. |
| `fade_seconds` | `0.4` | How long the fade-out (and the matching fade-in) each take, in seconds. Range 0.05 to 5. |
| `wipe_image` | empty | The greyscale picture a `wipe` transition follows. Empty is a plain left-to-right sweep. |

**3. Drop the actions on your events.** Here is a complete first menu - a Play button that fades into level one, and a Quit button:

```
On Play Pressed
  -> Menu | SceneFlowBehavior: Fade To Scene  "res://scenes/level_1.tscn"

On Quit Pressed
  -> Menu | SceneFlowBehavior: Quit Game
```

That is the entire menu. `Menu` is the node the behavior is attached to; `On Play Pressed` and `On Quit Pressed` are your own button events. The fade color and duration come from the Inspector, so both buttons match the game's look with nothing else to wire.

---

## Transitions - a shape drawn over the change

**Fade To Scene** covers the screen with a colour. **Go To Scene With** covers it with a shape: a
wipe following a picture you painted, a dissolve of speckles, an iris closing on the middle of the
screen, blinds, the picture coming apart into blocks, or a page turning.

```
On Level Complete
  -> Level | SceneFlowBehavior: Go To Scene With  "res://scenes/level_2.tscn"  iris  0.8  smooth
```

That is one row for the whole change. Under it, the transition is one walk:

- **out** over the first half - the shape comes on until the screen is fully covered;
- **the swap** at the midpoint - the scene is exchanged under the cover, where nobody can see it;
- **in** over the second half - the shape comes off again, over the new scene.

The cover colour is the node's `fade_color`, so a game whose fades are white gets white wipes with
nothing else to set. The one-at-a-time rule is the same as the shipped fade's, and it is the same
flag: **Is Transitioning** is true from the first frame of the walk to the last, for a plain fade and
a page curl alike.

Like the fade, the transition parents itself to the tree root rather than to the scene being
replaced, so the whole walk survives the swap. It draws in the top slot - above every post effect the
game is wearing - because a transition is the one thing that should not itself be graded, blurred or
vignetted by the look of the scene it is leaving.

### The seven shapes

| Shape | What it looks like | Notes |
|---|---|---|
| `fade` | The screen goes to the cover colour and comes back. | The cheapest: one flat rectangle, no screen read. |
| `wipe` | The cover sweeps in following the **Wipe Image** knob. | Dark parts of the picture are covered first, light parts last. With no image it is a plain left-to-right sweep. |
| `dissolve` | The screen breaks up into speckles that fill in. | The noise is generated, so it needs no image. |
| `iris` | A circle closes over the picture and opens on the next one. | Round on any window shape. |
| `blinds` | Bars close across the screen like a shutter. | |
| `pixelate` | The picture comes apart into blocks and the blocks drain to the cover colour. | Reads the screen while it runs. |
| `page curl` | The picture peels off the screen like a page being turned. | Reads the screen while it runs. |

The last two read the screen back, which costs one screen read per pixel while the transition is
running - and only while it is running, so it is a beat of expense rather than a standing one. The
other five are flat.

### The wipe image

A wipe follows any greyscale picture: it covers the dark parts first and the light parts last. A
left-to-right ramp is a bar wipe, a radial ramp is a clock, a soft cloud is a smoky dissolve, and a
shape you painted is that shape appearing. Drop the image on the behaviour's **Wipe Image** property
and pick `wipe` on the row. There is no list of shipped wipe images: any texture in your project
works, and a 256x256 gradient PNG is enough.

### Knowing when it landed

The **On Transition Finished** trigger fires when the new scene is up and the cover is off. It
arrives on the Scene Flow node in the NEW scene - the runner outlives the old one - and carries the
shape it was, so one handler can tell a wipe from an iris:

```
On Transition Finished
  -> Music: play
  -> Hud | JuiceBehavior: Moment  "calm"  1.0
```

---

## Loading screens - a screen of your own while the next scene loads

A small scene opens between two frames. A big one does not: **Go To Scene** holds the last frame of
the old scene while the new one comes off the disk, and a held frame reads as a hang even when
nothing is wrong. **Go To Scene With Loading** puts a screen of your own in that gap.

```
On Play Pressed
  -> Menu | SceneFlowBehavior: Go To Scene With Loading  "res://scenes/forest.tscn"  1.5  false

On Loading Progress
  -> LoadBar: set value = SceneFlow.loading_progress

On Loading Finished
  -> PressAnyKey: set visible = true
```

One row starts it. Under the row the pack swaps to your loading screen, asks the engine for the next
scene on a background thread, and enters it when **both** the load has finished and the shortest
time has been served.

### The three knobs

| Property | Default | What it does |
|---|---|---|
| `loading_scene` | empty | The screen shown while the next scene loads. Empty means no screen at all: the wait still happens, with the reading and both triggers, wherever the player is standing. |
| `loading_transition` | `fade` | The shape drawn over both halves of the change - onto the loading screen and off it again into the new scene. The same seven shapes **Go To Scene With** picks from, held over the node's `fade_seconds`. `none` swaps plainly. |
| `loading_tips_file` | empty | A text file of tips, one per line, that **Loading Tip** picks from. |

### The starters are files, not a list the pack owns

Two starters ship beside the pack script in `res://eventsheet_addons/scene_flow/`:

- `loading_screen.tscn` - a dark backdrop, a "Loading" title, a spinning square, a `LoadBar` whose
  maximum is `1` (which is what the reading answers with), a `Tip` label, a hidden "Press any key"
  label, and a Scene Flow node so the three rows above have somewhere to live.
- `tips.txt` - eight tips about a game that does not exist, and a note to itself at the top.

**Neither knob points at either of them.** Both open empty on purpose: copy the two files into your
own folders, restyle the screen and rewrite the tips, then point the knobs at your copies. The pack
ships one of each and never a list of screens or a table of tips it owns.

A tips file is one tip per line. Blank lines are skipped, and a line starting with `#` is a note to
yourself that is never shown, so a tip can be parked without being deleted. The file is read again
on every load, so editing it while the game runs shows up on the next screen. Add `*.txt` to the
export filters in the export preset so the file ships with the game.

### What the bar is set to

**Loading Progress** answers from 0 to 1, and it is the **slower** of the two things being waited
on: how much of the scene is off the disk, and how much of the shortest time has been served. A bar
that races to the end on a fast disk and then sits there for a second reads as a hang, so this one
never runs ahead of the wait it belongs to. **On Loading Progress** fires every time that number
moves, on the Scene Flow node standing in the loading screen, which is exactly where a row that sets
a bar wants to be.

The shortest time is seconds a **player** waits: a slowmo running underneath cannot stretch it. One
second is enough for the screen to read as a beat rather than as a flicker; zero enters the moment
the load lands.

### Press any key

With **Wait For Key** off, the new scene is entered as soon as the wait is over. With it on, the wait
ends at **On Loading Finished** and the screen stays up until a row runs **Enter Loaded Scene**.
That verb does nothing at all while the wait is still on, so a bare "any key pressed" row is safe to
leave on the loading screen from the first frame:

```
On Any Key Pressed
  -> LoadingScreen | SceneFlowBehavior: Enter Loaded Scene
```

**Is Loading** is true for the whole of it - the wait, the beat where it is waiting for a key, and
the covered change into the new scene - so any row can be gated on "still loading".

### A quiet note from the Doctor

The Doctor watches for a scene over a megabyte opened with a plain, uncovered change, and files an
**info** note naming the script, the scene and its size on disk, with this row as the door out. It
is a note rather than a warning because hard-cutting into a big scene is a choice: a splash screen
that should cut is allowed to stay exactly as it is. Like every finding it says nothing inside the
sheet - the row wears the quiet amber state, and the words live in the Doctor's triage inbox and in
the row's help strip when it is selected.

---

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, node references in *italic*, exactly as the rows draw them:

- Fade to scene **path**

All ACEs live in the **Scenes** category and target the `SceneFlowBehavior` behavior on the node they are placed on. Every action operates on the running scene tree, so it does not matter which node inside the scene hosts the behavior.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Fade To Scene | `path` (String) | Fades the screen out, changes to the scene at `path`, and fades back in. Ignored while a transition is already running. A blank path does nothing. |
| Fade Reload Scene | (none) | Fades out, reloads the current scene, and fades back in - the polished retry button. |
| Go To Scene | `path` (String) | Changes to the scene at `path` immediately, with no fade. A blank path does nothing. |
| Reload Scene | (none) | Reloads the current scene immediately, with no fade. |
| Quit Game | (none) | Quits the game. A safe no-op on platforms that forbid it, such as web. |
| Go To Scene With | `path` (String), `transition` (String), `seconds` (float), `ease` (String) | Changes to the scene at `path` with a shape drawn over the change: the cover walks on over the first half, the scene is swapped underneath it, and it walks off again over the second. Shapes are fade, wipe, dissolve, iris, blinds, pixelate and page curl; eases are linear, smooth, in and out. Ignored while a transition is already running; a blank path does nothing. Opens at fade, 0.6, smooth. |
| Reload Scene With | `transition` (String), `seconds` (float), `ease` (String) | Reloads the current scene with the same shapes, cover colour and one-at-a-time rule as Go To Scene With - the polished retry in whichever shape the game uses everywhere else. Opens at fade, 0.6, smooth. |
| Go To Scene With Loading | `scene` (String), `min_seconds` (float), `wait_for_key` (bool) | Shows the node's Loading Scene while the scene at `scene` comes off the disk on a background thread, then enters it. The wait is over when both the load has finished and `min_seconds` have passed, so the screen cannot flash past on a fast machine. Opens at 1 second with the key branch off; a blank path does nothing, and a second call while one is running is ignored. |
| Enter Loaded Scene | (none) | Enters the scene a loading screen has been holding. Does nothing at all while the wait is still on, so a bare "any key pressed" row is safe to leave on the loading screen - it is what Wait For Key waits for. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Is Transitioning | (none) | Whether a faded transition is currently running. True from the moment a Fade To Scene / Fade Reload Scene begins until its fade-in finishes. |
| Is Loading | (none) | Whether a background load started by Go To Scene With Loading is still in flight. True while the screen is up, including the beat where it is waiting for a key and the covered change into the new scene. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Current Scene Path | (none) | String | The `res://` file path of the scene running right now (empty string if there is somehow no current scene). |
| Loading Progress | (none) | float | How far the wait has got, from 0 to 1: the slower of how much of the scene is off the disk and how much of the shortest time has been served. Zero when nothing is loading. |
| Loading Tip | (none) | String | The one line picked out of the tips file when this load started. It stays put for the whole wait, because a tip that changes while somebody is reading it is worse than no tip. Empty when there is no tips file, or nothing is loading. |

### Triggers

| Trigger | Fires when |
|---|---|
| On Transition Finished | A transition started by Go To Scene With or Reload Scene With has finished: the new scene is up and the cover is off. It arrives on the Scene Flow node in the NEW scene, carrying the shape the transition was (`fade`, `iris`, and so on), so one handler can tell them apart. |
| On Loading Progress | The loading reading moved. It arrives on the Scene Flow node standing in the loading screen and carries nothing: Loading Progress answers with the number, so the row that sets a bar reads as a sentence. |
| On Loading Finished | The wait is over: the scene is off the disk and the shortest time has been served. With Wait For Key off the swap follows immediately; with it on, this is the moment to show "press any key". |

Everything else you drive from your own game events - a button press, a player-died signal, a
level-complete condition, an `On Ready` after a timer. The plain **Fade To Scene** and **Fade Reload
Scene** raise no trigger of their own; watch **Is Transitioning** turn false for those, or use the
shaded pair above when you want the signal.

### Inspector properties

| Property | Type | Default | Range | What it does |
|---|---|---|---|---|
| `fade_color` | Color | opaque black `Color(0, 0, 0, 1)` | any color | The cover color the screen fades through. |
| `fade_seconds` | float | `0.4` | 0.05 - 5 (step 0.05) | Fade-out (and fade-in) duration, in seconds. |
| `wipe_image` | Texture2D | empty | any texture | The greyscale picture a `wipe` transition follows: its dark parts are covered first and its light parts last. Empty is a plain left-to-right sweep. |
| `loading_scene` | String (file) | empty | `*.tscn`, `*.scn` | The screen shown while Go To Scene With Loading waits for the next scene. Empty means no screen at all, and the wait happens where the player is standing. |
| `loading_transition` | String (list) | `fade` | none, fade, wipe, dissolve, iris, blinds, pixelate, page curl | The shape drawn over both halves of a loading change, held over `fade_seconds`. |
| `loading_tips_file` | String (file) | empty | `*.txt` | A text file of tips, one per line, that Loading Tip picks from. A line starting with `#` is a note to yourself. |

### Inspector properties are ACEs too

Every property this pack exposes in the Inspector is also reachable from the picker, generated for you:
an expression named after the property reads it, a **Set ...** action writes it, and for number properties
**Add To ...** and **Subtract From ...** adjust it by an amount. They sit in the pack's own category
alongside the vocabulary above, so any knob you can set in the Inspector is also something a sheet can read and
change while the game runs.

---

## Reading it from expressions - the Self section

Type `self` in any ƒx field, or open the ƒx **Expressions dictionary**, and **Self ▸ Behaviours**
lists this pack's knobs and value expressions as ready-to-insert chains once the behaviour is attached:

- `$SceneFlowBehavior.fade_color` inserts the **Fade Color** entry straight into any expression
- `$SceneFlowBehavior.fade_seconds` inserts the **Fade Seconds** entry straight into any expression

The `$SceneFlowBehavior` token stays selected after insert, so retargeting to your child's actual name is one
keystroke, or a node drag. Attaching this behaviour at runtime instead? Tick **Robust behaviour
lookups** in the dictionary and the same entries insert as `get_node_or_null("SceneFlowBehavior")` chains,
which survive auto-named children. While **Live Values** streams from a running game, the group
upgrades to *Behaviours (live - on your node)* and reads the RUNNING instance - behaviours
attached at runtime included, under their real names. And with your node selected in the Scene
dock, the section grounds to that node's actual children before you even press Run.

## Use cases

Each example targets the `SceneFlowBehavior` behavior on the named node. Paths are `res://` scene files; swap in your own. The trigger events (`On Play Pressed`, `On Player Died`, and so on) are your own game logic - Scene Flow supplies only the scene actions.

### 1. Title screen Play button

The simplest first row: fade into level one when the player presses Play.

```
On Play Pressed
  -> Menu | SceneFlowBehavior: Fade To Scene  "res://scenes/level_1.tscn"
```

The fade color and length come from the Inspector, so there is no tween to build.

### 2. Game-over retry

A death screen "Retry" button restarts the current level with a fade.

```
On Retry Pressed
  -> DeathScreen | SceneFlowBehavior: Fade Reload Scene
```

Fade Reload Scene is exactly this button - no path needed, it reloads whatever is running.

### 3. Quit button that ships everywhere

One Quit action, safe on every export target.

```
On Quit Pressed
  -> Menu | SceneFlowBehavior: Quit Game
```

On web the call is a harmless no-op, so you do not need to hide the button per platform.

### 4. Advance to the next level on completion

When the level-complete flag is set, fade to the next scene file.

```
On Level Complete
  -> Level | SceneFlowBehavior: Fade To Scene  "res://scenes/level_2.tscn"
```

Because the fade overlay lives on the tree root, the fade-out plays over the finishing level and the fade-in plays over the new one, uninterrupted by the swap.

### 5. Instant portal warp

A door or portal that should feel immediate skips the fade.

```
On Portal Entered
  -> Player | SceneFlowBehavior: Go To Scene  "res://scenes/cave.tscn"
```

Go To Scene changes right away, so the warp lands with no dark beat in between.

### 6. Checkpoint respawn

On death, drop the player back at the top of the current scene with a fade.

```
On Player Died
  -> Game | SceneFlowBehavior: Fade Reload Scene
```

For a snappier respawn with no fade, use Reload Scene instead.

### 7. Splash screen hand-off

After a short delay on the splash scene, move to the main menu with no fade.

```
On Splash Timer Finished
  -> Splash | SceneFlowBehavior: Go To Scene  "res://scenes/main_menu.tscn"
```

Wire the splash's own timer or `On Ready` plus a wait; Scene Flow just does the jump.

### 8. Pause menu "Return to Title"

A pause overlay button fades back to the main menu.

```
On Return To Title Pressed
  -> PauseMenu | SceneFlowBehavior: Fade To Scene  "res://scenes/main_menu.tscn"
```

The player leaves the level with the same polished fade they entered it with.

### 9. Debounce a mashed button

Guard a transition so a double-tap cannot fire two scene changes.

```
On Next Pressed
  Condition: Level | SceneFlowBehavior  Is Transitioning  (inverted)
    -> Level | SceneFlowBehavior: Fade To Scene  "res://scenes/level_3.tscn"
```

Fade To Scene already ignores a second call while a fade runs, but checking Is Transitioning lets you skip other side effects (a click sound, a score save) on the ignored press too.

### 10. Gray out buttons while a fade plays

Lock input during a transition so the player cannot queue up conflicting actions.

```
Every tick
  Condition: Menu | SceneFlowBehavior  Is Transitioning
    -> PlayButton: set disabled = true
    -> QuitButton: set disabled = true
```

Is Transitioning is true from the start of the fade-out until the fade-in ends, so the buttons re-enable themselves on the new scene automatically.

### 11. Restart on a key press

Bind R to a fade-reload for quick iteration, guarded so holding the key does not stack reloads.

```
On R Pressed
  Condition: Game | SceneFlowBehavior  Is Transitioning  (inverted)
    -> Game | SceneFlowBehavior: Fade Reload Scene
```

Handy during playtesting; the guard keeps a held key from firing repeatedly.

### 12. Branch behavior by current scene

Read the live scene path and act on it - here, only show the "Back to Menu" button when you are not already on the menu.

```
On Ready
  Condition: [Expression] HUD | SceneFlowBehavior  Current Scene Path  ==  "res://scenes/main_menu.tscn"
    -> BackButton: set visible = false
```

Current Scene Path returns the running scene's file path, so you can special-case any scene without tracking it yourself.

### 13. Confirm-before-quit dialog

The dialog's Yes button quits; its No button just closes.

```
On Confirm Quit Yes
  -> Dialog | SceneFlowBehavior: Quit Game

On Confirm Quit No
  -> Dialog: hide
```

Quit Game does the exit; the No branch is ordinary UI with no Scene Flow at all.

### 14. Instant retry from a scripted fail state

When a puzzle hits an unsolvable state, reload immediately with no fade so the reset feels instant.

```
On Puzzle Softlocked
  -> Puzzle | SceneFlowBehavior: Reload Scene
```

Reload Scene restarts the current scene with a hard cut - right when you want the reset to feel like it never happened.

### 15. Chapter select menu

Each chapter button fades to its own scene from a shared menu node.

```
On Chapter 1 Pressed
  -> Select | SceneFlowBehavior: Fade To Scene  "res://scenes/chapter_1.tscn"

On Chapter 2 Pressed
  -> Select | SceneFlowBehavior: Fade To Scene  "res://scenes/chapter_2.tscn"
```

One behavior node serves every button; only the path changes per row.

### 16. A wipe you painted

A game with a look of its own does not want a plain fade. Drop a greyscale picture on the behaviour's
Wipe Image and the cover follows it.

```
On Chapter End
  -> Level | SceneFlowBehavior: Go To Scene With  "res://scenes/chapter_2.tscn"  wipe  1.0  smooth
```

The dark parts of the picture go first and the light parts last, so a diagonal ramp is a diagonal
wipe and a painted shape is that shape closing in.

### 17. React to the arrival

The trigger fires on the Scene Flow node in the scene the transition arrived at, so the new scene can
start itself.

```
On Transition Finished
  -> LevelMusic: play
  -> Player: set process_mode = 0
```

Use it for anything that should wait until the cover is off: starting the music, unfreezing the
player, or beginning a cutscene.

### 18. A retry that matches the rest of the game

If the game moves between levels with an iris, the death screen should retry with one too.

```
On Retry Pressed
  -> DeathScreen | SceneFlowBehavior: Reload Scene With  iris  0.7  smooth
```

One shape word per row keeps every change in the game reading as the same game.

### 19. A level that takes a beat to open

The first big level is twelve megabytes of scene. Opened plainly, the menu's last frame sits there
while it loads. Opened with a screen, the player watches a bar.

```
On Play Pressed
  -> Menu | SceneFlowBehavior: Go To Scene With Loading  "res://scenes/forest.tscn"  1.5  false
```

Point the node's Loading Scene at your copy of the starter screen first. The 1.5 is the shortest the
screen stays up, so a machine with a fast disk spends the same beat on it as a slow one.

### 20. The bar and the tip

Both rows live on the loading screen itself, on the Scene Flow node the starter already carries.

```
On Loading Progress
  -> LoadBar: set value = SceneFlow.loading_progress

On Loading Progress
  -> Tip: set text = SceneFlow.loading_tip
```

The tip is picked once when the load starts and does not change while somebody is reading it, so
setting it on every reading is safe.

### 21. Press any key to continue

With Wait For Key on, the screen stays up after the load lands and a key press is what enters.

```
On Play Pressed
  -> Menu | SceneFlowBehavior: Go To Scene With Loading  "res://scenes/forest.tscn"  1.0  true

On Loading Finished
  -> PressAnyKey: set visible = true

On Any Key Pressed
  -> LoadingScreen | SceneFlowBehavior: Enter Loaded Scene
```

The last row is safe from the first frame: Enter Loaded Scene does nothing while the wait is still
on, so a player who mashes a key during the load simply enters the moment it is ready.

### 22. Nothing else fires while a screen is up

A pause menu that leads into a level keeps running while the load does. Guard the rows that should
wait with the condition.

```
On Pause Pressed
  + PauseMenu | SceneFlowBehavior: Is Loading  [inverted]
  -> PauseMenu: set visible = true
```

Is Loading is true for the whole screen, the press-any-key beat and the covered change into the new
scene, so one inverted condition covers every part of the wait.

### Other use cases

**Attract mode.** A demo or kiosk build starts an idle timer on the title and gameplay scenes and Fade To Scene back to the intro when nobody touches the controls, keeping a show-floor build presentable on its own.

**Flashback sequences.** Set `fade_color` to white on the behavior in the memory trigger scene, so slipping into a dream or flashback reads visually different from the black fades the rest of the game uses.

**In-game arcade cabinet.** Interacting with a cabinet Fade To Scene loads the minigame, and the minigame's exit button fades back to the hub, turning a whole minigame collection into a set of ordinary scene files.

**Day and night variants.** Sleeping at the inn fades into the night version of the same town scene, letting you author two moods as two scene files instead of relighting one scene at runtime.

**Looping horror corridor.** Walking through the far door calls Go To Scene on the same corridor scene instantly - no fade, no visible seam - so the player only slowly realizes the hallway is repeating.

---

## Tips and common mistakes

- **Attach it once, use it anywhere in that scene.** The behavior acts on the whole scene tree, so it does not matter which node hosts it - pick the menu or level root that stays alive while your buttons exist. If a scene has no Scene Flow node at all, its buttons have nothing to call.
- **Use `res://` paths, and keep them exact.** Fade To Scene and Go To Scene take a scene file path like `"res://scenes/level_2.tscn"`. A blank path is ignored on purpose (so a half-filled row cannot blank the game), but a typo'd-but-nonblank path will fail to load - copy the path from the FileSystem dock to be safe.
- **Reload has no path; Go To needs one.** Fade Reload Scene and Reload Scene restart the current scene and take no argument. Fade To Scene and Go To Scene load a different scene and need the path. Reaching for a path parameter that is not there is a sign you meant a reload.
- **Faded vs instant is a deliberate choice.** Fade To Scene / Fade Reload Scene add a polished beat; Go To Scene / Reload Scene are immediate. Do not fade a warp that should feel instant, and do not hard-cut a menu-to-level move that deserves a fade.
- **Only one faded transition runs at a time.** A second Fade To Scene or Fade Reload Scene while one is playing is silently ignored. That is the anti-double-fire safety net - lean on it, and add an Is Transitioning guard when you also want to skip other side effects on the ignored press.
- **Is Transitioning covers faded flows, not instant ones.** It reports true only while a fade overlay is running. Go To Scene and Reload Scene do not raise it, so do not gate an instant action on it expecting a busy flag that never turns on.
- **Set the fade look on the node, not per call.** `fade_color` and `fade_seconds` are Inspector properties, not action parameters, so every faded change on that node shares one look. Want two different fade speeds? Use two behavior nodes with different `fade_seconds`.
- **Quit Game is a no-op on web by design.** Do not treat a "quit did nothing" report on a web build as a bug - the platform forbids it and the action returns quietly. Test quit on a desktop export.
- **The shaded transitions have a trigger; the plain fade does not.** Go To Scene With and Reload Scene With emit On Transition Finished when the new scene is up and the cover is off. Fade To Scene and Fade Reload Scene do not - for those, watch Is Transitioning fall back to false, or move the row to the shaded pair when you want the signal.
- **A transition is measured in seconds the player waits.** The walk ignores `Engine.time_scale`, so a slowmo or a hitstop running underneath it cannot stretch a 0.6 second wipe into three.
- **Pixelate and page curl read the screen; the other five do not.** They cost one screen read per pixel while the transition runs, and nothing at all when it is over. Reach for them deliberately, and prefer a fade or an iris on a phone.
- **The wipe image is yours.** No wipe pictures ship with the pack. Any greyscale texture in your project works - dark first, light last - and a small gradient PNG is plenty.
- **The loading screen and the tips file are yours too.** The two starters in the pack folder are meant to be copied and rewritten; neither knob points at them, so a project that never opens them is a project that never sees them. Copy them into your own folders before you restyle, or a pack update will write over your edits.
- **Point Loading Scene at something before the first loading row runs.** With the knob empty the wait still happens - the reading moves and both triggers fire - but there is no screen, so it looks exactly like a plain change with a delay in it.
- **Put the bar and tip rows on the loading screen, not on the menu.** The two loading triggers arrive on the Scene Flow node standing in the loading screen, because the node that started the load has been replaced by then. The starter screen already carries one.
- **The shortest time is a floor, not a duration.** A scene that takes four seconds to load takes four seconds however small the minimum is. Zero means "enter the moment it lands", which is the right answer for a screen you only want on slow machines.
- **Ship the tips file with the game.** It is a `.txt`, and export presets filter those out by default. Add `*.txt` to the preset's filters or the file the knob names will not be there in the exported build.
- **Enter Loaded Scene is safe to leave running.** It does nothing while the wait is on and nothing when there is no load, so an "any key pressed" row on the loading screen needs no guard.
