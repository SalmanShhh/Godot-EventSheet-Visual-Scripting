# Scene Flow - Polished Scene Changes From One Node

Scene Flow is a Godot EventSheets behavior pack that gives a whole menu (or a whole game) its scene changes without a line of hand-written code. You attach a `SceneFlowBehavior` behavior to any `Node` and it gains five actions: fade to another scene, fade-reload the current one, jump instantly to a scene, reload instantly, and quit the game. The fade is the star: when you call **Fade To Scene** or **Fade Reload Scene**, a full-screen overlay fades out, the swap happens under the cover, then it fades back in - and because that overlay parents itself to the tree root instead of the dying scene, the transition never dies halfway through the swap. It is the classic "my fade vanished the instant the scene changed" trap, solved once. Set the fade color and duration in the Inspector, drop the actions on your buttons, and a title screen, a game-over retry, and a quit button all work with zero code.

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

---

## Core concepts

The whole pack is five actions, one condition, and one expression. Learn these five ideas and you have all of it.

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

**3. Drop the actions on your events.** Here is a complete first menu - a Play button that fades into level one, and a Quit button:

```
On Play Pressed
  -> Menu | SceneFlowBehavior: Fade To Scene  "res://scenes/level_1.tscn"

On Quit Pressed
  -> Menu | SceneFlowBehavior: Quit Game
```

That is the entire menu. `Menu` is the node the behavior is attached to; `On Play Pressed` and `On Quit Pressed` are your own button events. The fade color and duration come from the Inspector, so both buttons match the game's look with nothing else to wire.

---

## ACE reference

All ACEs live in the **Scenes** category and target the `SceneFlowBehavior` behavior on the node they are placed on. Every action operates on the running scene tree, so it does not matter which node inside the scene hosts the behavior.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Fade To Scene | `path` (String) | Fades the screen out, changes to the scene at `path`, and fades back in. Ignored while a transition is already running. A blank path does nothing. |
| Fade Reload Scene | (none) | Fades out, reloads the current scene, and fades back in - the polished retry button. |
| Go To Scene | `path` (String) | Changes to the scene at `path` immediately, with no fade. A blank path does nothing. |
| Reload Scene | (none) | Reloads the current scene immediately, with no fade. |
| Quit Game | (none) | Quits the game. A safe no-op on platforms that forbid it, such as web. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Is Transitioning | (none) | Whether a faded transition is currently running. True from the moment a Fade To Scene / Fade Reload Scene begins until its fade-in finishes. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Current Scene Path | (none) | String | The `res://` file path of the scene running right now (empty string if there is somehow no current scene). |

### Triggers

Scene Flow ships no triggers of its own. You drive it from your own game events instead - a button press, a player-died signal, a level-complete condition, an `On Ready` after a timer. React to a finished transition, if you need to, by watching **Is Transitioning** turn false in your loop.

### Inspector properties

| Property | Type | Default | Range | What it does |
|---|---|---|---|---|
| `fade_color` | Color | opaque black `Color(0, 0, 0, 1)` | any color | The cover color the screen fades through. |
| `fade_seconds` | float | `0.4` | 0.05 - 5 (step 0.05) | Fade-out (and fade-in) duration, in seconds. |

---

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
- **There are no triggers to react to.** Scene Flow does not emit "on faded" events. Drive it from your own button and game events, and if you need to know a fade finished, watch Is Transitioning fall back to false in your loop rather than hunting for a trigger that does not exist.
