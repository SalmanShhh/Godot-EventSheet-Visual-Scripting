# ProcRoom

ProcRoom is a seeded procedural room-map generator for Godot EventSheets. Register a handful of weighted room types, call one action with a seed string, and you get a Slay-the-Spire-style tiered graph: a single start room at depth 0, forward branches through however many depths you asked for, and a single boss room at the last depth. It ships as the `ProcRoom` autoload singleton, so it is already wired into every sheet in your project with no setup - just call `ProcRoom.Generate` and read the map back. It draws nothing itself. You read stable room ids (like `d2_1`) and paint your own map, load your own encounters, and lock your own doors. The same seed always rebuilds the exact same map, so a whole run is reproducible and shareable.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Classic branching roguelite.** Generate a fresh dungeon every run, offer the player two or three forward rooms at each depth, and track which ones they cleared - no adjacency math, no hand-authored layouts.
- **Deck-builder map screen.** The "choose your next node" screen maps straight onto ProcRoom. Register combat, rest, shop, and elite types, then list the rooms connected forward from where you stand.
- **Seeded daily challenge.** Feed the date as the seed and every player gets the identical map for that day. `run-2026-07-07` plays the same for everyone.
- **Shareable run codes.** Let a player copy their seed string and hand it to a friend. Same seed, same map, same fight - they can race the same layout.
- **Metroidvania-style locked gates.** Generate the whole graph up front, lock a room behind a key, and unlock it when the player earns the key. Enter Room refuses the locked door until then.
- **Boss-run pacing.** Ask for a short graph (few depths, one room per depth) for a tight gauntlet, or a wide one for a sprawling map - one number changes the shape.
- **Encounter tables keyed by room type.** Attach different scenes, music, or loot tables to `combat`, `elite`, `treasure`, `boss`. On Room Entered hands you the type of the room the player just walked into.
- **Fog-of-war progress maps.** Reveal and visit state let you draw only what the player has seen, and show a "rooms cleared" progress bar off the visited count.
- **Reproducible bug reports.** A seed plus a depth count is the entire description of a map. Paste the seed into a test and you regenerate the exact case a player hit.
- **Rapid jam prototyping.** Sketch a full run loop in an hour: register a few types, Generate, react to On Room Entered, and start tuning feel before any art exists.
- **Narrative branch graphs.** Treat rooms as story beats and types as scene categories (dialogue, choice, reward). The guaranteed path from start to boss means the story can always reach its ending.

---

## Core concepts

**Room types are templates, not rooms.** You register a named type once (like `combat` or `shop`) with four rules: a **weight** (higher = it shows up more often), a **min depth** and **max depth** (the range of tiers it is allowed to appear in), and a **max per depth** (how many of that type may sit on one tier). Generate then stamps out actual rooms by weighted-random pick, obeying those rules. A weight of `10` against a weight of `3` means the first type is roughly three times as likely per slot.

**Start and boss are special and automatic.** Depth 0 always holds exactly one room, given the start type (default `"start"`). The last depth always holds exactly one room, given the boss type (default `"boss"`). You do not register those - Generate places them for you. You can rename the types with Set Start Type and Set Boss Type if you prefer other labels.

**Depths are tiers.** A map with `depths = 6` has tiers 0 through 5. Tier 0 is the start, tier 5 is the boss, and tiers 1 through 4 are the interior where your registered types get placed, up to `max_rooms_per_depth` rooms each (the exact count per interior tier is random between 1 and that cap).

**Connections point forward.** Every room links forward to one or more rooms on the next depth. Movement is one-directional: from the room you are in you may only step into a room it connects forward to.

**Reachability is guaranteed by construction.** When the map is built, every room on a tier is given at least one parent on the tier before it. That means the start at depth 0 always connects through, tier by tier, to the boss at the last depth. You can never generate a map that strands the boss or islands a room off the graph.

**Traversal state rides along.** Each room carries three flags that update as the player moves: **visited** (they have entered it), **revealed** (it has been shown, which happens automatically on entry), and **locked** (Enter Room refuses it until you unlock it). The map structure stays put while these flags change; Reset Traversal wipes the flags and drops you back at the start without rebuilding the layout.

**Room ids are stable handles.** Every room has an id of the form `d{depth}_{index}` - `d0_0` is always the start, `d3_1` is the second room on depth 3. These ids are stable for a given seed and settings, so you can key art, encounters, saved progress, and locked-door logic off them.

**You start already inside the map.** Generate places the player in the start room (`d0_0`) for you, marks it visited and revealed, and fires On Graph Generated. You do not need to enter the start room yourself - your first Enter Room call moves the player onto depth 1.

---

## Setup

ProcRoom is an autoload. The pack registers itself as the `ProcRoom` singleton, so every sheet in the project can call it by name with nothing to attach or wire. There is no node to drop into a scene.

A minimal first map is two ideas: register the types you want the generator to pick from, then Generate with a seed. Here is a complete first example as event-sheet rows:

```
On Ready
  -> ProcRoom: Register Room Type  "combat", 10, 1, -1, -1
  -> ProcRoom: Register Room Type  "rest",   3,  1, -1,  1
  -> ProcRoom: Generate  "run-1", 6, 3

On Graph Generated
  -> Draw your map here from ProcRoom.Total Depths() and ProcRoom.Rooms At Depth(depth)
  // the player is already in the start room d0_0 at this point
```

`Register Room Type "combat", 10, 1, -1, -1` reads as: a type named `combat`, weight 10, allowed from depth 1 onward, no max depth (`-1`), no per-depth cap (`-1`). `Generate "run-1", 6, 3` builds a 6-depth map (start at 0, boss at 5) with up to 3 rooms per interior tier, from the seed `run-1`.

Once that runs, move the player with Enter Room and read state back to draw and drive the game:

```
On next button pressed
  Condition ProcRoom: Is Room Available  chosen_id
  -> ProcRoom: Enter Room  chosen_id

On Room Entered
  -> Load encounter for  ProcRoom.Entered Type()

On Traversal Blocked
  -> Show message  ProcRoom.Block Reason()
```

---

## ACE reference

All names below are the exact display names you will see in the picker. Because ProcRoom is an autoload, expressions read as `ProcRoom.Display Name(args)` from any sheet.

### Actions

| Action | Parameters | Description |
|---|---|---|
| **Register Room Type** | `type_id` (String), `weight` (float), `min_depth` (int), `max_depth` (int), `max_per_depth` (int) | Registers a room type Generate may place: a weight (higher = commoner), the depth range it may appear in (`max_depth` -1 = anywhere), and a per-depth cap (-1 = no cap). |
| **Set Start Type** | `type_id` (String) | Sets the type name given to the single depth-0 room (default `"start"`). |
| **Set Boss Type** | `type_id` (String) | Sets the type name given to the single final-depth room (default `"boss"`). |
| **Generate** | `seed_text` (String), `depths` (int), `max_rooms_per_depth` (int) | Builds a reproducible tiered map from a seed: `depths` tiers (start at 0, boss at the last), up to `max_rooms_per_depth` rooms per interior tier. Same seed = same map. Fires On Graph Generated. |
| **Regenerate** | (none) | Rebuilds the map from the same seed and settings as the last Generate (a fresh run of the same layout). |
| **Enter Room** | `room_id` (String) | Moves to a room if it is connected forward from the current room and not locked; otherwise fires On Traversal Blocked (read Block Reason). On success marks it visited and fires On Room Entered. |
| **Force Enter Room** | `room_id` (String) | Moves to any room, ignoring connection and lock checks (for teleports or debug). Fires On Room Entered. |
| **Lock Room** | `room_id` (String) | Locks a room so Enter Room is blocked until it is unlocked (a key door). |
| **Unlock Room** | `room_id` (String) | Unlocks a locked room. |
| **Reveal Room** | `room_id` (String) | Marks a room as revealed (for fog-of-war maps). |
| **Reset Traversal** | (none) | Clears visited, revealed, and locked flags and returns to the start room, keeping the same map. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| **Is Graph Ready** | (none) | Whether a map has been generated. |
| **Is Room Visited** | `room_id` (String) | Whether a room has been entered. |
| **Is Room Available** | `room_id` (String) | Whether a room can be entered right now (connected forward from the current room and unlocked). |
| **Is Room Locked** | `room_id` (String) | Whether a room is locked. |
| **Is Room Connected** | `from_id` (String), `to_id` (String) | Whether room A connects forward to room B. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| **Graph Seed** | (none) | String | The seed of the current map. |
| **Total Rooms** | (none) | int | How many rooms the map has. |
| **Total Depths** | (none) | int | How many depth tiers the map has. |
| **Current Room** | (none) | String | The room the player is in (`""` before entry). |
| **Current Room Type** | (none) | String | The type of the current room. |
| **Current Depth** | (none) | int | The depth tier of the current room. |
| **Previous Room** | (none) | String | The room entered just before the current one. |
| **Room Type** | `room_id` (String) | String | A room's type (`""` if unknown). |
| **Room Depth** | `room_id` (String) | int | A room's depth tier (-1 if unknown). |
| **Rooms At Depth** | `depth` (int) | int | How many rooms are at a depth tier. |
| **Room At Depth** | `depth` (int), `index` (int) | String | The room id at a depth and index (`""` out of range). |
| **Connections From** | `room_id` (String) | int | How many rooms a room connects forward to. |
| **Connection From** | `room_id` (String), `index` (int) | String | The Nth room a room connects forward to (`""` out of range). |
| **Visited Count** | (none) | int | How many rooms have been visited. |
| **Entered Id** | (none) | String | The room just entered (inside On Room Entered). |
| **Entered Type** | (none) | String | The type of the room just entered (inside On Room Entered). |
| **Blocked Id** | (none) | String | The room that could not be entered (inside On Traversal Blocked). |
| **Block Reason** | (none) | String | Why entry was blocked - `"locked"` or `"unreachable"` (inside On Traversal Blocked). |

### Triggers

| Trigger | Fires when |
|---|---|
| **On Graph Generated** | A map finishes building (from Generate or Regenerate). The player is already placed in the start room. |
| **On Room Entered** | Enter Room or Force Enter Room succeeds. Read Entered Id and Entered Type inside it. |
| **On Traversal Blocked** | Enter Room is refused because the room is unreachable or locked. Read Blocked Id and Block Reason inside it. |

---

## Use cases

### 1. Your first map in three rows

**Scenario:** you want a playable map as fast as possible.

```
On Ready
  -> ProcRoom: Register Room Type  "combat", 10, 1, -1, -1
  -> ProcRoom: Generate  "run-1", 6, 3

On Graph Generated
  -> Show "Map ready with" & ProcRoom.Total Rooms() & " rooms"
  // you are already standing in the start room d0_0
```

### 2. A Slay-the-Spire choice screen

**Scenario:** when the player enters a room, show one button per room they can move to next.

```
On Room Entered
  -> Clear the choice buttons
  -> Repeat ProcRoom.Connections From(ProcRoom.Current Room()) times, index i:
       spawn a button, set its room id to ProcRoom.Connection From(ProcRoom.Current Room(), i)
       set its label to ProcRoom.Room Type( that id )
```

`Connection From` walks the forward links one index at a time, so a `Connections From` count paired with it lists exactly the rooms the player may step into.

### 3. Loading the right encounter per room type

**Scenario:** combat rooms fight, rest rooms heal, the boss room ends the run.

```
On Room Entered
  -> Match ProcRoom.Entered Type():
       "combat" -> start a fight
       "rest"   -> open the campfire menu
       "boss"   -> start the boss fight
```

Read `Entered Type` (not `Current Room Type`) inside On Room Entered - it is the type of the room the trigger just fired for.

### 4. Telling the player why they cannot go there

**Scenario:** a click on an out-of-reach or locked room should explain itself, not fail silently.

```
On room button pressed
  -> ProcRoom: Enter Room  clicked_id

On Traversal Blocked
  -> Show message  "Cannot enter " & ProcRoom.Blocked Id() & ": " & ProcRoom.Block Reason()
  // Block Reason is "unreachable" (not connected forward) or "locked"
```

### 5. A boss gate you open with a key

**Scenario:** the room before the boss stays locked until the player collects three keys.

```
On Graph Generated
  -> ProcRoom: Lock Room  ProcRoom.Room At Depth(ProcRoom.Total Depths() - 2, 0)

On key count reaches 3
  -> ProcRoom: Unlock Room  ProcRoom.Room At Depth(ProcRoom.Total Depths() - 2, 0)
```

While locked, Enter Room on that room fires On Traversal Blocked with reason `"locked"` instead of moving the player.

### 6. Weighting types so combat is common and shops are rare

**Scenario:** you want lots of fights and the occasional shop.

```
On Ready
  -> ProcRoom: Register Room Type  "combat", 12, 1, -1, -1
  -> ProcRoom: Register Room Type  "rest",    4, 1, -1, -1
  -> ProcRoom: Register Room Type  "shop",    1, 1, -1, -1
  -> ProcRoom: Generate  "weights-demo", 8, 3
```

Higher weight means the type is picked more often per slot. `combat` at 12 against `shop` at 1 makes combat roughly twelve times as likely to fill a given interior room.

### 7. At most one shop per tier

**Scenario:** you never want two shops sitting side by side on the same depth.

```
On Ready
  -> ProcRoom: Register Room Type  "shop", 2, 1, -1, 1
  // the last parameter is max_per_depth = 1, so a depth gets at most one shop
```

### 8. Elites only in the back half

**Scenario:** elite rooms should never appear early.

```
On Ready
  -> ProcRoom: Register Room Type  "elite", 3, 4, -1, -1
  // min_depth = 4, so elites start at tier 4 and can appear anywhere after
  -> ProcRoom: Generate  "elites", 8, 3
```

### 9. A treasure type that stops before the boss

**Scenario:** treasure should show up mid-run but never on the tier just before the boss.

```
On Ready
  -> ProcRoom: Register Room Type  "treasure", 2, 2, 5, 1
  // min_depth 2, max_depth 5: allowed only on tiers 2 through 5
  -> ProcRoom: Generate  "treasure-run", 8, 3
```

### 10. Draw the whole map up front

**Scenario:** you want a full node graph on screen the moment the map is generated.

```
On Graph Generated
  -> For depth d from 0 to ProcRoom.Total Depths() - 1:
       For index i from 0 to ProcRoom.Rooms At Depth(d) - 1:
         place a node for ProcRoom.Room At Depth(d, i) at column d, row i
  -> For each placed node with id room:
       For j from 0 to ProcRoom.Connections From(room) - 1:
         draw a line from room to ProcRoom.Connection From(room, j)
```

`Rooms At Depth` and `Room At Depth` walk the tiers; `Connections From` and `Connection From` walk the forward links. Between them you can rebuild the entire graph without touching internals.

### 11. A "rooms cleared" progress bar

**Scenario:** show how much of the map the player has seen.

```
On Room Entered
  -> Set progress bar to  ProcRoom.Visited Count() / ProcRoom.Total Rooms()
  -> Set label to  ProcRoom.Visited Count() & " / " & ProcRoom.Total Rooms() & " rooms"
```

### 12. A depth counter HUD

**Scenario:** show "Depth 3 / 5" so the player knows how far they have to go.

```
On Room Entered
  -> Set label to  "Depth " & ProcRoom.Current Depth() & " / " & (ProcRoom.Total Depths() - 1)
```

The boss sits at `Total Depths() - 1`, so that is the number to compare against for "how deep is the boss".

### 13. Detecting the boss room

**Scenario:** trigger the final cutscene when the player reaches the boss.

```
On Room Entered
  Condition ProcRoom.Entered Type() = "boss"
  -> Play boss intro
  // or compare depth: ProcRoom.Current Depth() = ProcRoom.Total Depths() - 1
```

### 14. Share a seed with a friend

**Scenario:** let players copy their run and hand it to someone else.

```
On share button pressed
  -> Copy to clipboard  ProcRoom.Graph Seed()

On load seed pressed
  -> ProcRoom: Generate  pasted_seed_text, 6, 3
  // same seed + same depths + same registered types = the exact same map
```

### 15. Retry the same run

**Scenario:** a "retry" button that replays the identical layout from the start.

```
On retry pressed
  -> ProcRoom: Reset Traversal
  // same map, all visited/locked flags cleared, player back at d0_0

On new-layout retry pressed
  -> ProcRoom: Regenerate
  // rebuilds the same seed's layout from scratch, also back at the start
```

Reset Traversal keeps the built graph and only wipes the flags; Regenerate rebuilds the graph (same seed, same result) and resets state.

### 16. A teleport or warp item

**Scenario:** a scroll that jumps the player to any room, ignoring the connection and lock rules.

```
On use warp scroll
  -> ProcRoom: Force Enter Room  destination_id
  // Force Enter Room skips the reachability + lock checks that Enter Room enforces
```

Force Enter Room still fires On Room Entered, so your encounter loading runs exactly as it does for a normal move.

### 17. A fog-of-war minimap

**Scenario:** only draw rooms the player has actually visited, and pre-reveal a room a scout ability peeks at.

```
On Graph Generated
  -> For each room in the map: draw it as "unknown"

On Room Entered
  -> For each room id shown on the minimap:
       if ProcRoom: Is Room Visited (that id) then draw it fully, else draw it dimmed

On use scout ability
  -> ProcRoom: Reveal Room  peeked_id
```

Entering a room marks it visited and revealed for you; Reveal Room is for rooms the player has not entered yet but should still see.

### 18. Gate a button on whether the move is legal

**Scenario:** dim a room button unless the player can move there right now.

```
On updating the map
  -> For each room button with id room:
       enable it only if  ProcRoom: Is Room Available (room)
  // Is Room Available is true only when room is connected forward from the current room and unlocked
```

---

## Tips and common mistakes

- **You cannot strand the boss.** Reachability is guaranteed when the map is built: every room gets at least one parent on the tier before it, so the start at depth 0 always connects through to the boss at the last depth. There is no configuration that produces an unreachable room, so you never need to validate the graph yourself.
- **The seed is just a string, and it is the whole map.** Any text works, including an empty string. The same seed with the same depth count and the same registered types always rebuilds the identical map. That is what makes daily challenges, shared run codes, and reproducible bug reports free.
- **Room ids are stable `d{depth}_{index}` handles.** `d0_0` is always the start and the last depth's `_0` is always the boss. Key your art, saved progress, encounter tables, and locked doors off these ids rather than off room order in a list.
- **Register types before you Generate.** Generate only picks from the types registered at the moment it runs. If a type is missing from your maps, you almost certainly called Generate before Register Room Type.
- **You start inside the start room.** Generate places the player in `d0_0`, marks it visited and revealed, and fires On Graph Generated. Do not call Enter Room on the start room to "begin" - your first Enter Room moves onto depth 1.
- **Enter Room enforces the rules; Force Enter Room skips them.** Enter Room only moves the player to a room connected forward from where they stand and not locked, and fires On Traversal Blocked otherwise. Force Enter Room ignores both checks. Use Enter Room for normal play and Force Enter Room only for teleports, cutscenes, and debug.
- **Read Entered Type and Block Reason inside their triggers.** `Entered Id` and `Entered Type` are meaningful inside On Room Entered; `Blocked Id` and `Block Reason` are meaningful inside On Traversal Blocked. Reading them elsewhere gives you whatever the last event left behind.
- **`max_depth` and `max_per_depth` of -1 mean "no limit".** A type registered with `-1` for both can appear on any interior tier, any number of times. Set a real number only when you want to constrain it.
- **The boss depth is `Total Depths() - 1`.** A 6-depth map has tiers 0 through 5, so the boss is on tier 5 and the room before it is on `Total Depths() - 2`. Reach for those two expressions when locking the pre-boss room or checking for arrival.
- **Reset Traversal keeps the layout; Regenerate rebuilds it.** For "try the same map again" use Reset Traversal, which only clears the visited, revealed, and locked flags and drops you at the start. Regenerate replays the same seed to rebuild the graph from scratch (same result) and also returns you to the start.
