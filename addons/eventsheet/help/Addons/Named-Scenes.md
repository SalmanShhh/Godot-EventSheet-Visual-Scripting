# Named Scenes

**Named Scenes** ships as the `NamedScenes` autoload - a registry that gives every `.tscn` a short
name, so rows stop carrying `res://` paths. Register `"arena"` once and every row afterwards says
**Go To Named Scene** `"arena"`; move or rename the file later and only the registration changes.

Two things ride along that Godot itself makes awkward. A record can be **carried into the next
scene**, which is the clean answer to "which door did I come in by" that otherwise sends everybody to
a hand-written autoload. And the addressing family the sheets lack entirely arrives with it: a
**Current Scene Is** condition, an **On Scene Ready** trigger carrying the name, and **Scene
Argument** for reading the handoff.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this pack shines

- **Level select and hub-and-spoke games**, where the hub names its destinations.
- **Doors and portals**, where the handoff is the only clean answer to "which side did I come in".
- **Retry and death loops** carrying an attempt count across the reload.
- **Refactor safety** when `levels/` moves or a file is renamed.
- **Debug and QA** jumping straight to any registered name.
- **A level list that maintains itself** - Register Scenes In Folder means adding a file is adding a level.
- **Saves that survive a reorganise**, because a scene NAME is stabler than its path.
- **Loading screens**, where Preload Named Scene warms the next level while a hint is on screen.

## Core concepts

- **The registry is the only place a path lives.** Every other row addresses a name. That is the whole
  point: one edit when a file moves, instead of a search across every sheet.
- **Register Scenes In Folder makes the folder the level list.** `res://levels/arena.tscn` becomes
  `"arena"`. Sub-folders are left alone, so a `levels/props/` folder does not pollute the list.
- **The handoff belongs to the scene you ARRIVE in.** Carry Into Next Scene stores a record; it
  becomes readable through Scene Argument once the next scene is announced ready, and the scene you
  left keeps reading its own arguments until then.
- **On Scene Ready carries the name.** It fires once the new scene really exists, not at the moment
  the change was requested, so a row under it can safely reach into the scene.
- **Current Scene Is answers on the last announced name.** Go To Named Scene announces for you;
  Announce Scene Ready is there for when you changed scene some other way.
- **Preloading warms, it does not change.** Preload Named Scene loads the file into memory and leaves
  you exactly where you are.

## Setup

1. Open **Sheet > New Behaviour Addon…** and pick Named Scenes, or use **Tools > Register Autoload**
   on `res://eventsheet_addons/named_scenes/named_scenes_addon.gd`. It registers as `NamedScenes`.
2. Register your scenes once, in a boot sheet the game always runs first - either one Register Scene
   row per level, or a single Register Scenes In Folder over `res://levels`.
3. Replace the `res://` paths in your existing Go To Scene rows with names. The old path-addressed
   verbs keep working, so you can move over one row at a time.

## ACE reference

On the canvas these verbs read as styled sentences - parameter values in **bold**, exactly as the
rows draw them:

- Register scene **"arena"** = **res://levels/arena.tscn**
- Go to scene named **"arena"**
- Carry **{ "from": "hub", "door": "east" }** into the next scene

### Actions

| Action | Parameters | Description |
|--------|-----------|-------------|
| Register Scene | scene_name, scene_path | Gives a scene file a short name every row can use instead of its path. Registering again replaces it. |
| Register Scenes In Folder | folder | Registers every `.tscn` directly inside a folder under its own file name. Sub-folders are left alone. |
| Forget Named Scene | scene_name | Removes one name from the registry and drops anything warmed for it. |
| Go To Named Scene | scene_name | Changes to the scene registered under this name. Warns and does nothing when the name is unknown. |
| Preload Named Scene | scene_name | Loads a registered scene into memory now, without changing to it. |
| Carry Into Next Scene | payload | Hands a record to the scene you are about to open. It belongs to the NEXT scene. |
| Announce Scene Ready | scene_name | Marks a named scene as the one now running, which fires On Scene Ready. Go To Named Scene calls it for you. |

### Conditions

| Condition | Parameters | Description |
|-----------|-----------|-------------|
| Current Scene Is | scene_name | Whether the named scene is the one running right now. |
| Scene Is Registered | scene_name | Whether a name has a scene behind it. Ask before going somewhere named by data. |
| Named Scene Is Preloaded | scene_name | Whether Preload Named Scene has already warmed this scene. |
| Has Scene Argument | key | Whether the scene you are in was handed a value under this key. |

### Expressions

| Expression | Returns | Description |
|-----------|---------|-------------|
| Scene Argument | String | A carried value as text, or the fallback when nothing was carried under that key. |
| Scene Argument Number | number | The same, read as a number - an attempt count, a difficulty, a starting score. |
| Path Of Named Scene | String | The `res://` path registered under a name, or "" when the name is unknown. |
| Current Scene Name | String | The name of the scene running right now, or "" before the first one. |
| Registered Scene Names | Array | Every registered name, sorted. A level-select screen builds itself from this. |

### Triggers

| Trigger | Fires with | Description |
|---------|-----------|-------------|
| On Scene Ready | scene_name | The named scene is now running. Fires after the new scene really exists, so it is safe to reach into it. |

## Use cases

**1. Name your levels once, at boot.** Everything after this row addresses names.

```gdscript
extends Node


func _ready() -> void:
	NamedScenes.register_scene("arena", "res://levels/arena.tscn")
```

**2. Or let the folder be the list.** Adding `res://levels/crypt.tscn` adds a level, with no row to
edit.

```gdscript
extends Node


func _ready() -> void:
	NamedScenes.register_scenes_in_folder("res://levels")
```

**3. Travel by name.** This row survives the file being renamed, moved or re-organised.

```gdscript
extends Node


func _on_portal_entered() -> void:
	NamedScenes.go_to_named_scene("arena")
```

**4. Tell the next level which door you came in by.** The classic problem, solved without a
hand-written autoload.

```gdscript
extends Node


func _on_east_door_used() -> void:
	NamedScenes.carry_into_next_scene({"from": "hub", "door": "east"})
	NamedScenes.go_to_named_scene("arena")
```

**5. And read it on arrival.** On Scene Ready fires once the scene really exists, so reaching into it
is safe here and nowhere earlier.

```gdscript
extends Node


func _on_scene_ready(scene_name: String) -> void:
	if scene_name == "arena":
		$Player.global_position = spawn_point(NamedScenes.scene_argument("door", "north"))
```

**6. Carry a number across the change.** An attempt count is the usual one.

```gdscript
extends Node


func _on_player_died() -> void:
	NamedScenes.carry_into_next_scene({"attempt": attempts + 1})
	NamedScenes.go_to_named_scene("arena")
```

**7. Read that number back with a sensible default.** A first attempt carries nothing, and the
fallback covers it.

```gdscript
extends Node


func _on_scene_ready(_scene_name: String) -> void:
	attempts = int(NamedScenes.scene_argument_number("attempt", 1.0))
```

**8. Tell "arrived from somewhere" apart from "started here".** Has Scene Argument is the honest
question; a default cannot answer it.

```gdscript
extends Node


func _on_scene_ready(_scene_name: String) -> void:
	if not NamedScenes.has_scene_argument("door"):
		$Intro.play()
```

**9. Show a panel only in the hub.** A condition on the scene you are in, with no path anywhere.

```gdscript
extends Node


func _process(_delta: float) -> void:
	$HubMenu.visible = NamedScenes.current_scene_is("hub")
```

**10. Warm the next level while the player reads a hint.** The change is then instant when it comes.

```gdscript
extends Node


func _on_hint_shown() -> void:
	NamedScenes.preload_named_scene("arena")
```

**11. Enable the Continue button only once the level is warm.** A one-row loading screen.

```gdscript
extends Node


func _process(_delta: float) -> void:
	$Continue.disabled = not NamedScenes.named_scene_is_preloaded("arena")
```

**12. Build the level-select screen from the registry.** No hand-kept list to fall out of step.

```gdscript
extends Node


func _ready() -> void:
	for scene_name: String in NamedScenes.registered_scene_names():
		$List.add_item(scene_name)
```

**13. Guard a jump whose name came from data.** A save file or a level table can name a level that no
longer ships.

```gdscript
extends Node


func _on_continue_pressed() -> void:
	if NamedScenes.scene_is_registered(saved_level):
		NamedScenes.go_to_named_scene(saved_level)
```

**14. Save where the player was, by name.** A name survives moving `levels/` around; a path does not.

```gdscript
extends Node


func _on_save_pressed() -> void:
	save_slot["level"] = NamedScenes.current_scene_name()
```

**15. Hand a path to a verb that still wants one.** The escape hatch, for a fade-to-scene verb from
another pack.

```gdscript
extends Node


func _on_fade_requested() -> void:
	$SceneFlow.fade_to_scene(NamedScenes.path_of_named_scene("arena"))
```

**16. Retire a level at runtime.** An unlockable that is not available yet simply is not registered.

```gdscript
extends Node


func _on_season_ended() -> void:
	NamedScenes.forget_named_scene("winter_arena")
```

### Other use cases

**Debug warp menu.** A developer console that lists Registered Scene Names and jumps to whichever one is typed gives QA a complete level warp with no per-level wiring.

**Hub return with memory.** Carry the room you left into the hub, and the hub can put the player back at the correct door instead of at its default spawn.

**Difficulty carried into the run.** The menu carries a difficulty record into the first level and every later level re-carries it, so the value travels the whole run without a global.

**Chapter select from folders.** One Register Scenes In Folder per chapter folder, run at boot, gives a chapter-grouped level list that stays correct as the project grows.

**Scene-keyed music.** A single listener on On Scene Ready maps the scene name to a track, which removes the music node from every level scene.

## Tips and common mistakes

- **Register before you travel.** Go To Named Scene warns and does nothing for an unknown name, which
  is deliberately safer than a black screen - but it means a boot sheet that never ran leaves every
  jump silently inert.
- **The handoff is one record, not a stack.** A second Carry Into Next Scene replaces the first. If
  you need to accumulate, build the record yourself and carry it once.
- **The record belongs to the scene you arrive in.** Reading Scene Argument before the change lands
  gives you the PREVIOUS scene's values, which is correct and often surprising.
- **Arriving with nothing carried clears the record.** A level can never accidentally read the
  arguments of the level before it.
- **Register Scenes In Folder only reads that folder.** Sub-folders are skipped on purpose; call it
  once per folder you want in the list.
- **Two files with the same base name collide.** `levels/arena.tscn` and `levels/boss/arena.tscn`
  would both want `"arena"`; the folder sweep registers only the first folder you sweep, so name them
  apart.
- **Preloading does not change scene**, and it does not expire. A warmed scene stays in memory until
  you Forget Named Scene it.
- **Current Scene Is answers on the last ANNOUNCED name.** If you change scene with Godot's own verb
  rather than this pack's, call Announce Scene Ready afterwards or the condition will still name the
  old level.
