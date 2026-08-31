# Folder Watcher - Noticing That a File Appeared, Changed or Went

Godot raises **no file-change notification at run time** on any platform it ships for. There is
nothing to subscribe to, so this pack does the only honest thing available: it **looks**, on an
interval you choose, and compares what it saw with what it saw last time - by file name and by
modified time. **Watch Folder** starts it, **Stop Watching** parks it, **Look Now** takes one look
straight away, and **On A File Appeared / Changed / Removed** are what a difference between two
looks means.

A poll calls itself a poll here. The row reads `Watch folder "user://mods" every 2.0 s`, and the
band at the top of the sheet reads `watching user://mods every 2.0 s`, because "watching" that
quietly costs a directory read every frame is the kind of thing a project finds out about on
somebody else's slow disk.

## Where this pack shines

- **A mods folder.** The player drops a file in while the game is running and the game notices.
- **A hot-reloading data file.** Edit the balance table in a text editor and see it in the running
  game a second later, with no restart and no editor plugin.
- **A screenshot or replay gallery.** The gallery adds the new file itself rather than waiting for
  the screen to be reopened.
- **A tool built with event sheets.** An import folder somebody else's program writes into is the
  one case where polling really is the only mechanism there is.

## Setup

1. Attach `FolderWatcher` as a child of the node that should react (a mod manager, a gallery screen).
2. Set `watched_folder`, `look_every_seconds` and `only_names_like` in the Inspector, or pass the
   first two to a **Watch Folder** row and skip the Inspector entirely.
3. Add an event for each of the three triggers you care about.

```
On Ready -> ModFolder | Folder Watcher: Watch Folder  "user://mods", 2.0

On A File Appeared path -> Mods | Load Mod  path
```

## What one look costs

One `DirAccess.get_files_at` of the folder, plus one modified-time question per file that passes the
name filter. Between looks it costs nothing. While it is stopped it costs nothing at all: the
per-frame tick is parked with `set_process(false)`, so the engine no longer visits the node.

The directory walk is **sorted**, so two machines watching the same folder raise the same events in
the same order - the engine promises no order of its own.

**The first look is the baseline.** Starting a watch records what is already there without raising
anything. A folder that already holds two hundred files is not two hundred things that just
happened; the events start at the second look.

## ACE reference

| Kind | Name | Parameters | Description |
|---|---|---|---|
| Action | Watch Folder | `folder`, `every_seconds` | Starts watching a folder, looking every so many seconds. The first look is the baseline and raises nothing. |
| Action | Stop Watching | - | Stops looking, and parks the per-frame tick so the node costs nothing. |
| Action | Look Now | - | Takes one look immediately, without waiting for the interval. |
| Condition | Is Watching | - | True while a watch is running - between Watch Folder and Stop Watching. |
| Expression | Watched File Count | - | How many files the last look found, after the name filter. |
| Expression | Watched File Names | - | The file names the last look found, sorted. Names, not whole paths. |
| Trigger | On A File Appeared | `path` | A file the look before did not find. |
| Trigger | On A File Changed | `path` | A file whose modified time moved since the last look. |
| Trigger | On A File Removed | `path` | A file the look before found and this one did not. |

Every trigger hands back the **whole path**, folder and all, so a handler can read the file without
rebuilding it.

### Inspector properties

| Property | Default | What it does |
|---|---|---|
| `watched_folder` | `user://mods` | The folder to look in. Prefer `user://` - `res://` is read-only in an exported game, so nothing in it will ever change. |
| `look_every_seconds` | `2.0` | Seconds between looks. The shortest gap honoured is a tenth of a second. |
| `only_names_like` | `*` | Which file names count, as a pattern with `*` and `?` in it. Names that do not match raise nothing and are not looked up. |
| `watch_on_ready` | `false` | Start watching as soon as the node is ready, using the two settings above. |

## Use cases

### 1. A mods folder the player drops files into

```
On Ready               -> ModFolder | Folder Watcher: Watch Folder  "user://mods", 2.0
On A File Appeared path -> Mods | Load Mod  path
```

### 2. Unloading a mod that was deleted

```
On A File Removed path -> Mods | Unload Mod  path
```

### 3. Reloading a mod that was edited

```
On A File Changed path -> Mods | Unload Mod  path
                       -> Mods | Load Mod    path
```

### 4. Only the data files

```
On Ready -> ModFolder | Set only_names_like to "*.json"
         -> ModFolder | Folder Watcher: Watch Folder  "user://mods", 2.0
```

The filter is applied before anything is looked up, so a folder full of images costs nothing to
watch for `*.json`.

### 5. A hot-reloading balance table

```
On Ready                -> Tuning | Folder Watcher: Watch Folder  "user://tuning", 1.0
On A File Changed path  -> set balance = Table Of File(path, ",", "the first line names the columns")
                        -> Enemies | Apply Balance  balance
```

### 6. Stopping when the screen closes

```
On Mods Screen Closed -> ModFolder | Folder Watcher: Stop Watching
```

A watcher is only worth its directory read while something is looking at the answer.

### 7. Watching only while the game is paused

```
On Game Paused   -> ModFolder | Folder Watcher: Watch Folder  "user://mods", 2.0
On Game Resumed  -> ModFolder | Folder Watcher: Stop Watching
```

### 8. Looking immediately after your own write

```
On Save Replay Pressed -> Write Text File  "user://replays/last.json", To JSON Text (pretty)(replay)
                       -> ReplayFolder | Folder Watcher: Look Now
```

Better than waiting a second for the next look when you already know something changed.

### 9. A gallery that counts itself

```
Every 1.0 seconds -> set GalleryLabel text = str(ShotsFolder.Watched File Count) + " screenshots"
```

### 10. Building a list from the names

```
On A File Appeared path -> List | Append To  shots, path
                        -> Gallery | Rebuild  shots
```

### 11. A slower watch for a big folder

```
On Ready -> Archive | Folder Watcher: Watch Folder  "user://archive", 30.0
```

Every look reads the whole folder, so a folder with thousands of files wants a long interval.

### 12. Waiting for an external tool to finish

```
On Export Started      -> Outbox | Folder Watcher: Watch Folder  "user://outbox", 1.0
On A File Appeared path -> set StatusLabel text = "Exported " + path.get_file()
                       -> Outbox | Folder Watcher: Stop Watching
```

### 13. Not starting twice

```
On Mods Screen Opened
  - Not: ModFolder | Folder Watcher: Is Watching
  -> ModFolder | Folder Watcher: Watch Folder  "user://mods", 2.0
```

Watch Folder is safe to call again - it just takes a new baseline - but the question reads better.

### 14. Announcing what is already there at startup

```
On Ready -> ModFolder | Folder Watcher: Watch Folder  "user://mods", 2.0
         -> set StatusLabel text = str(ModFolder.Watched File Count) + " mods installed"
```

The baseline raises nothing, so the count is how you say what was already found.

### 15. Watching the folder an unpack writes into

```
On Ready                -> ModFolder | Folder Watcher: Watch Folder  "user://mods", 1.0
On Install Pressed      -> Unpack Zip Into Folder  "user://incoming/pack.zip", "user://mods"
On A File Appeared path -> Mods | Load Mod  path
```

The two halves of one story: the archive rows put the files there, the watcher notices them.

### 16. A shared save folder on a family computer

```
On Ready               -> Saves | Folder Watcher: Watch Folder  "user://saves", 5.0
On A File Appeared path -> SlotMenu | Rebuild
On A File Removed path -> SlotMenu | Rebuild
```

### Other use cases

**A level editor's own preview.** Watch the folder the editor writes level files into, and reload the previewed level whenever one changes, so the designer never presses a refresh button.

**A texture pack folder.** Watch `user://skins` and rebuild the material dropdown whenever a new image lands, so a player can add art without restarting.

**A shared photo frame.** A kiosk build watching a folder that a phone syncs into shows new pictures on its own, without anyone touching the machine.

**Speedrun replay inbox.** Watch a folder a companion tool drops replay files into, and list each one as it lands so runs appear in the menu while the run is still being written.

**Locale files under development.** Watch the translation folder and re-apply the language whenever a CSV changes, so a translator sees their line in the running game.

## Tips and common mistakes

- **This is a poll, not a subscription.** A change is noticed on the next look and no sooner. An
  interval of two seconds means "within two seconds", never "immediately".
- **A modified time is stamped to the nearest second.** A file written twice inside one second looks
  unchanged. That is a limit of the filesystem, not of this pack.
- **A program that writes a file in several goes can raise On A File Changed more than once** for
  what a person would call one save. Debounce in your own row if that matters.
- **The first look raises nothing.** If you want to react to what is already there, read
  **Watched File Count** or **Watched File Names** after Watch Folder rather than waiting for events
  that will never come.
- **A watcher under `res://` will never see anything change.** `res://` is packed into the export and
  read-only there. Watch `user://`.
- **The filter hides files completely.** A name that does not match `only_names_like` raises nothing
  and is not counted, so a count that looks wrong is usually a filter that is narrower than you
  remember.
- **The interval has a floor of a tenth of a second.** A zero or a negative number would be a
  directory read every frame, which is never what anybody meant by an interval.
- **Every look reads the whole folder.** A folder with thousands of files in it wants a long
  interval, or a narrower filter, or both.
- **Stopped means stopped.** Stop Watching parks the per-frame tick, so nothing is noticed while it
  is off - not even a Look Now's worth. Start it again, or call Look Now yourself.
- **The triggers hand back whole paths; the expressions hand back names.** Join the folder back on
  before opening a name from **Watched File Names**.
