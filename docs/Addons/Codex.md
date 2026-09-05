# Codex - The Set Of Things The Player Has Found

A bestiary, a recipe book, an item compendium, a gallery of unlocked art and a list of visited
rooms are **one mechanic wearing five hats**: a set of names, the ones that have been met, and
the pages behind them. Every game writes it again - a Dictionary of booleans in a script, a save
key per unlock, a scene per page - and every game writes it differently.

The set is a **folder** and an entry is a **file** in it. `res://codex/enemies/slime.tres` is the
entry `slime` of the set `enemies`, so adding a page means dropping a file in a folder. There is
no list in this pack, no dropdown in the editor, and no name of anybody's monster anywhere in the
plugin.

A page is a `CodexEntryResource` **you** own: a name, a picture, and the words. Its file name is
the entry's name and its folder is the set, so nothing on the page repeats either and nothing can
fall out of step with anything. One empty starter ships beside the director as the file to
duplicate, and it is the only page this pack will ever have an opinion about.

## Where this pack shines

- **The first-kill reward in one event.** First Time In This Save on the left, Discover and a
  toast on the right. No boolean per monster, no reset row on new game.
- **A codex screen that is one loop.** For Each Discovered hands back the entry *resources*, so
  the name, the picture and the words are all on the thing the loop is standing on.
- **"14 / 60" without a number typed anywhere.** Discovered Count and Total Entries, and the
  total counts the files - so a page added to the folder joins it with no sheet edit.
- **Silhouettes for free.** Has Discovered decides between the real page and the grey one, in
  the same loop, with no second list of what is hidden.
- **A moment, not a poll.** On First Discovered fires once per entry ever, so the row that fills
  the codex can be the row that celebrates it.
- **It rides the save you already have.** The pack answers `save_state` / `load_state`, so Save
  All Addons carries the whole collection with nothing to keep in step.

## Setup

There is nothing to attach and nothing to place in a scene. Codex registers itself as the
**`Codex`** autoload, the same shape as Save System and Music, so the director exists from the
first frame and every sheet reaches it by name with no node path.

1. Register the pack as the `Codex` autoload (Tools > Register Autoload, or Project Settings >
   Globals).
2. Make a folder for your pages, `res://codex/` by default, and a **folder per set** inside it -
   `res://codex/enemies/`, `res://codex/recipes/`.
3. Duplicate the starter `new_entry.tres` into a set folder, name the FILE after the entry
   (`slime.tres`), and fill in **Entry Name**, **Picture** and **Text** in the Inspector.
4. Discover it from any sheet:

```
On Death -> Enemy | Codex: Discover  "enemies", Enemy.kind
```

The file's name is the entry's name, so `Discover "enemies", "slime"` finds `slime.tres`. There
is nothing to preload and nothing to register per page.

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, node
references in *italic*, exactly as the rows draw them:

- Discover **"slime"** in **"enemies"**
- Has discovered **"slime"** in **"enemies"**

### Actions

| Action | Parameters | Description |
|---|---|---|
| Discover | `set_name` (String), `entry_id` (String) | Records that the player has found an entry of a set. The first Discover of an entry fires On First Discovered; every one after it is silent, so the row that fills the codex and the row that celebrates it can be the same row. An empty entry name is refused rather than recorded as a nameless page. |
| Forget Entry | `set_name` (String), `entry_id` (String) | Takes one entry back out of the set, so Has Discovered says no again and the page leaves For Each Discovered: a cheat menu that locks a page again, a chapter that takes its own notes back, a run-only discovery cleared between runs. An entry that was never found is left alone. |
| Forget Set | `set_name` (String) | Empties one whole set, so nothing in it counts as found any more and its count reads zero. What a New Game in the same session wants. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Has Discovered | `set_name` (String), `entry_id` (String) | Whether that entry of that set has been found: show the page, unlock the recipe, grey the silhouette out. |
| For Each Discovered | `set_name` (String) | Runs this event's actions once per DISCOVERED entry of a set, in name order. Read the current one as `entry` and take its `entry_name`, `picture` and `text` straight off it. An entry that has been discovered but has no file behind it any more is skipped rather than arriving as null. |

### Expressions

| Expression | Parameters | Description |
|---|---|---|
| Discovered Count | `set_name` (String) | How many entries of a set have been found: the left-hand number of a 14-out-of-60 line. |
| Total Entries | `set_name` (String) | How many entries a set HOLDS, counted from the files in its folder: the right-hand number. A page added to the folder joins the total with no sheet edit. A set with no folder counts zero rather than raising anything, because this is a row a menu asks every frame. |

### Triggers

| Trigger | Parameters | Description |
|---|---|---|
| On First Discovered | `set_name` (String), `entry_id` (String) | Fires the FIRST time an entry is discovered, and never again for that entry: the toast, the page-turn sound, the achievement. |

### The page file

A **CodexEntryResource** is one page written down. It is an ordinary resource: rename it, rewrite
it in the Inspector, duplicate it, point a translator at it.

| Property | Default | What it does |
|---|---|---|
| `entry_name` | empty | The title the page is shown under - "Green Slime", "Rusted Key". The file's own name is the entry id the rows take, so this is purely what a reader sees. |
| `picture` | empty | The illustration beside the words. Any texture: a portrait, an item sprite, a photograph of a map. |
| `text` | empty | The words of the page. Plain text, or BBCode if the label you show it in is a RichTextLabel. |

### Inspector properties

| Property | Default | What it does |
|---|---|---|
| `codex_folder` | `res://codex` | Where the sets live. A set is a folder under this one and an entry is a file in that folder. |
| `debug_mode` | `false` | Warns about a Discover into a set with no folder, a discovered entry with no file behind it, and an empty name handed to a row. On while you build, off for release. |

### Saving it

The pack answers the same `save_state` / `load_state` seam every autoload pack here does, so
**Save All Addons** carries the whole collection under the `Codex` name with no list to keep in
step, and **Load All Addons** hands it straight back:

```
On Save Game Pressed -> SaveSystem: Save All Addons
                     -> SaveSystem: Save Game
```

Nothing is written behind the game's back. A project that saves nothing keeps its codex for the
session and loses it on quit, which is the same contract Currency Ledger and Upgrades hold.

Loading a save that carries no codex of its own leaves the collection where it is, which is the
same empty-state rule every autoload pack here follows: an empty snapshot is a save with
nothing to say, not an instruction to forget. **Forget Set** is the instruction to forget, so
a New Game in the same session starts the book empty by saying so in a row.

## Use cases

### 1. The bestiary fills itself

```
On Death -> Enemy | Codex: Discover  "enemies", Enemy.kind
```

One row on the enemy's death event and the whole bestiary maintains itself. The kind is a
variable the enemy already has, so a new monster needs no sheet edit at all.

### 2. Only the first one counts

```
On Death -> Enemy | Codex: Discover  "enemies", Enemy.kind

Codex: On First Discovered -> HUD | Show Toast  "New entry: " + entry_id
```

Two events. Discover is safe to fire on every kill, and the trigger fires once per kind ever, so
nothing has to remember which monsters you have already toasted.

### 3. The codex screen, in one loop

```
Codex: For Each Discovered  "enemies" -> Page | Set Text  entry.entry_name
                                      -> Portrait | Set Texture  entry.picture
                                      -> Body | Set Text  entry.text
                                      -> List | Add Item
```

The loop hands back the page resources, so the name, the portrait and the words come off the
thing the loop is standing on.

### 4. Fourteen out of sixty

```
On Codex Opened -> Counter | Set Text  str(Codex.discovered_count("enemies")) + " / " + str(Codex.total_entries("enemies"))
```

The right-hand number counts the files in the folder, so it is right the moment you add a page.

### 5. Silhouettes for the ones you have not met

```
Codex: For Each Discovered  "enemies" -> Portrait | Set Texture  entry.picture

Codex: Has discovered  "enemies", "dragon" -> DragonPage | Show
Codex: Has discovered  "enemies", "dragon" (inverted) -> DragonSilhouette | Show
```

Two rows, the second inverted with the enable box, and no second list of what is hidden.

### 6. A recipe you can cook once you have seen it

```
On Cook Pressed -> Codex: Has discovered  "recipes", SelectedRecipe.id
                  -> Kitchen | Cook  SelectedRecipe.id
```

The codex IS the unlock list. There is no parallel set of booleans to keep in step with it.

### 7. The first time in this save, not on this computer

```
On Room Entered -> Save: First time in this save  "room:" + Room.name
                  -> Codex: Discover  "rooms", Room.name
                  -> HUD | Show Toast  "Discovered " + Room.name
```

First Time In This Save keeps its memory in the save slot, so a second playthrough discovers the
map again. Only Once Ever would be per-machine, and the second save would find a full codex.

### 8. A gallery of unlocked art

```
On Level Finished -> Codex: Discover  "gallery", Level.art_id

Codex: For Each Discovered  "gallery" -> Grid | Add Thumbnail  entry.picture
```

The gallery is a folder of pictures with a title each. Adding one is dropping in a file.

### 9. A completion reward

```
On Codex Opened -> Codex: Discovered count  "enemies" >= Codex: Total entries  "enemies"
                  -> Player | Give Item  "collector_hat"
                  -> HUD | Show Toast  "Bestiary complete"
```

The threshold is the folder's own size, so it moves with the game rather than being typed twice.

### 10. Lore found by reading, not killing

```
On Interacted -> Note | Codex: Discover  "lore", Note.page_id
              -> Reader | Set Text  Note.page_id
```

A note in the world is a page in the book. The same set drives the reading screen later.

### 11. A first meeting line

```
Codex: On First Discovered -> Compare  set_name = "npcs"
                           -> Dialogue | Start  "meet_" + entry_id
```

The introduction plays on the first meeting and never again, without a flag per character.

### 12. Unlock it from a cheat menu

```
On Unlock All Pressed + For each resource in  "res://codex/enemies"
  -> Codex: Discover  "enemies", entry.resource_path.get_file().get_basename()
```

The pack ships no unlock-everything row, on purpose: a cheat menu that wants the lot walks the
folder itself with For Each Resource In Folder and calls Discover per file. The folder is the
list, so the cheat and the total can never disagree.

### 13. Two sets that never see each other

```
On Pickup -> Codex: Discover  "items", Item.id
On Death  -> Codex: Discover  "enemies", Enemy.kind
```

Sets are folders, so `items` and `enemies` are separate collections with separate counts and
separate screens, and neither can leak into the other by a typo in a shared dictionary.

### 14. New Game Plus keeps the book

```
On New Game Plus -> SaveSystem: Carry value into next run  "__addons"
                 -> SaveSystem: Start new run  0
```

Carrying the addons key keeps every autoload's snapshot - the codex with it - through a run
reset that wipes the rest of the slot.

### 15. A page nobody wrote yet

```
On Death -> Enemy | Codex: Discover  "enemies", Enemy.kind
```

Discover an entry with no file behind it and the set counts it, Has Discovered says yes, and the
codex loop skips it. Turn **Debug Mode** on while you build and the pack names it in the output,
so the missing page is a line in the log rather than a blank row on the screen.

### 16. A museum that fills as you dig

```
On Artefact Cleaned -> Codex: Discover  "museum", Artefact.id
                    -> Codex: Discovered count  "museum" >= 10
                       -> Museum | Open Wing  "east"
```

The count is the progression gate, so a wing opens on the tenth find with no counter variable
anywhere.

### Other use cases

**Fish encyclopedia.** Every species caught becomes a page with its size record in the text, and the completion count drives the licence upgrade.

**Visited-planet log.** A space map marks the systems you have jumped to, and For Each Discovered draws only those, so the unexplored ones stay dark with no second list.

**Photograph album.** A photo mode discovers the subject it captured, and the album screen is the same loop reading the picture off each page.

**Mixology board.** Each drink poured correctly discovers its recipe, and Has Discovered gates whether the bartender will accept an order for it.

**Enemy weakness notes.** A page discovered on the third kill of a kind carries the weakness in its text, so the codex is the tutorial rather than a wiki tab.

## Tips and common mistakes

- **The file's name is the entry's name.** `slime.tres` is the entry `slime`. There is no id
  field on the page to disagree with it, and renaming the file renames the entry.
- **The folder is the set.** A page in the wrong folder is a page in the wrong set. Total
  Entries counts what is in the folder, so a stray file in there joins the total.
- **Discovered Count and Total Entries measure different things.** The count is what the player
  has met; the total is what the folder holds. A discovered id with no file is in the first and
  not the second, which is why they can disagree.
- **Discover is safe to spam.** The set is a set: the same entry twice is one entry. Put it on
  the death event without guarding it, and use On First Discovered for the celebration.
- **Register the autoload.** Every row addresses `Codex.` by name. Without the registration the
  emitted lines have nothing to talk to.
- **Save it, or lose it on quit.** The pack answers the save seam but never writes by itself.
  Save All Addons is the row that carries it.
- **Only .tres and .res files count.** A `.png` sitting in a set folder is ignored; the picture
  belongs on the page, not beside it.

## Already written it by hand? It reads as this pack

`Codex.discover("enemies", kind)` and `Codex.has_discovered("enemies", "slime")` read as the rows
above the moment the pack is installed, because those lines ARE the rows' own templates. A
project keeping its collection in a `Dictionary` of booleans reads as an ordinary dictionary
write, which is the honest reading of it - the pack is what turns those two lines into one
sentence with a folder of pages behind it.
