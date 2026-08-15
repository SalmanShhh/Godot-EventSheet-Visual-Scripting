# Quest

**Quest** ships as the `Quests` autoload - one shared quest tracker any sheet in your game can talk to.
You author each quest as a **Quest resource** (a `.tres` you fill in the Inspector: an id, a title, an
objectives grid of "name + how many are needed", an optional next quest, and a reward note), then start
it, count progress with **Advance Objective**, and react through triggers. The counting, the clamping at
the needed amount, the "is the whole quest done yet" sweep, and the questline chain are the pack's job -
not a pile of global variables and if-rows.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [The Quest resource](#the-quest-resource)
6. [Saving between runs](#saving-between-runs)
7. [Use cases](#use-cases)
8. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this pack shines

- **Fetch quests** - "collect 5 gems", counted automatically.
- **Kill quests** - "defeat 10 slimes" from one row in your enemy-died event.
- **Multi-step quests** - several objectives that must all be finished before the quest completes.
- **Questlines** - each quest names the next one and the chain runs itself.
- **Tutorial checklists** - the first five things a new player should do.
- **Delivery and escort tasks** where the last step is a single hand-in.
- **Achievement-style goals** that persist between play sessions.
- **Daily or weekly tasks** reset with one action.
- **Story gates** - a door that only opens once a named quest is completed.
- **Quest-log UI** - a label and a progress bar per objective, straight from the expressions.

## Core concepts

- **A quest is a data asset.** A **Quest resource** holds an id, a title, its objectives, an optional
  next quest and a reward note. Writing a quest is filling a table, not writing rows.
- **The id is the address.** Every action, condition and expression takes the quest's `quest_id` string.
  Keep ids short and unique (`bridge_repair`), and use the title for what the player reads.
- **Objectives are counted, not ticked.** Each objective has a name and a needed count, so
  "Collect 5 gems" is one row that walks up to 5/5 instead of five booleans.
- **Progress stops at the top.** Advancing past the needed count is clamped, so an extra call can never
  fire **On Objective Completed** a second time.
- **Completing them all completes the quest.** When the last objective fills, the quest leaves the
  active list, joins the completed list, fires **On Quest Completed**, and - if the resource named a
  **Next Quest** - starts that one immediately.
- **The tracker only knows quests it has seen.** **Start Quest** and **Register Quest** both teach it a
  resource. A chain can only jump to a quest that was registered or started at least once.
- **The reward is yours to hand out.** The reward note is a plain string for your UI; give the gold in
  **On Quest Completed**, so rewards stay under your control.

## Setup

Enable the **Quest** pack. It registers the `Quests` autoload, so there is nothing to attach - the verbs
are available in the picker's **Quest** section from any sheet.

Then create the quest itself: in the FileSystem dock, create a new **Resource**, pick **QuestResource**,
fill it in, and save it as (for example) `res://quests/gem_hunt.tres`.

| Field | Example |
|-------|---------|
| Quest Id | `gems` |
| Title | `Gem Hunt` |
| Objectives | one row: name `collect_gem`, needed `5` |
| Next Quest | `hand_in` (or blank to end here) |
| Reward Note | `200 gold and the river key` |

Now start it and count progress:

```
On Start of Layout
  -> Quests: Start Quest  gem_hunt.tres

On gem picked up
  -> Quests: Advance Objective  "gems", "collect_gem", 1

On Quest Completed
  -> give the player 200 gold
```

## ACE reference

On the canvas these verbs read as styled sentences - parameter values in **bold**, exactly as the rows
draw them:

- Start quest **gem_hunt.tres**
- Advance **collect_gem** on quest **gems** by **1**
- Abandon quest **gems**

### Actions

| Action | Parameters | Description |
|--------|-----------|-------------|
| Start Quest | quest (a Quest resource) | Begins the quest: every objective starts at 0 and On Quest Started fires. Starting it again resets its progress. |
| Register Quest | quest (a Quest resource) | Teaches the tracker a quest WITHOUT starting it, so another quest can chain into it and the title / reward expressions can read it. |
| Advance Objective | quest_id, objective, amount | Counts progress on one objective. Clamped at the needed count; fires On Objective Completed when it fills, and completes the quest when every objective is full. |
| Abandon Quest | quest_id | Drops an active quest and forgets its progress. It does not count as completed and fires no trigger. |
| Reset All Quests | (none) | Clears every active quest and the completed list (New Game). Registered definitions are kept, so chains still work. |
| Save Quests | (none) | Writes the active quests and the completed list into `user://remembered.cfg` under a "Quests" section. |
| Load Quests | (none) | Reads that state back, replacing whatever is tracked now. Does nothing if there is no save yet. |

### Conditions

| Condition | Parameters | Description |
|-----------|-----------|-------------|
| Quest Is Active | quest_id | Whether the quest is being tracked right now. |
| Quest Is Completed | quest_id | Whether the quest has been finished. |
| Objective Is Done | quest_id, objective | Whether one objective of an active quest has reached its needed count. |

### Expressions

| Expression | Returns | Description |
|-----------|---------|-------------|
| Objective Text | String | An objective's progress as readable text, e.g. "3/5" ("" if the quest is not active). |
| Objective Progress | number (0-1) | The same progress as a fraction - feed it to a progress bar. |
| Active Quest Count | number | How many quests are being tracked right now. |
| Completed Quest Count | number | How many quests have been finished. |
| Quest Title | String | The player-facing title of a started or registered quest. |
| Quest Reward Note | String | The reward note written on the quest resource. |

### Triggers

| Trigger | Fires with | Description |
|---------|-----------|-------------|
| On Quest Started | quest_id | A quest began (including one auto-started by a chain). |
| On Objective Completed | quest_id, objective | An objective just reached its needed count. Fires exactly once per objective. |
| On Quest Completed | quest_id | Every objective of a quest is finished. Hand out the reward here. |

## The Quest resource

| Property | Default | Description |
|----------|---------|-------------|
| Quest Id | "quest" | The string every action, condition and expression addresses this quest by. |
| Title | "" | The name the player reads in the quest log. |
| Objectives | empty | One row per objective: its `name` (the string Advance Objective takes) and how many are `needed`. |
| Next Quest | "" | The quest id to start automatically when this one completes. Blank ends the line. |
| Reward Note | "" | A plain-language note about the payout, for your own UI. |

A quest with **no objective rows** never completes on its own - it stays active until you abandon it.
That is occasionally what you want (a "tracked" marker), but usually it means the grid is still empty.

## Saving between runs

**Save Quests** and **Load Quests** use `user://remembered.cfg` - the same file the variable option
**Remember Between Runs** writes to - under a section named `Quests`. Two things are stored: the active
quests with their progress, and the completed list. Quest DEFINITIONS are not saved, because they live
in your project as `.tres` files: register or start them as usual on startup, then call **Load Quests**
to lay the player's progress back on top.

```
On Start of Layout
  -> Quests: Register Quest  gem_hunt.tres
  -> Quests: Register Quest  hand_in.tres
  -> Quests: Load Quests
```

The pack also exposes the Save System's save-state seam, so if you already use the **Save System** pack
its Save / Load verbs pick the same state up with no extra wiring.

## Use cases

**1. A simple collect quest.**

```
On gem picked up
  -> Quests: Advance Objective  "gems", "collect_gem", 1
```

**2. A kill quest counted from the enemy's death event.**

```
On enemy died
  Condition: enemy is a slime
    -> Quests: Advance Objective  "slime_cull", "slay_slime", 1
```

**3. Advance by more than one at a time.** A chest with three gems in it:

```
On chest opened
  -> Quests: Advance Objective  "gems", "collect_gem", 3
```

Overshooting is safe - progress stops at the needed count.

**4. A multi-step quest.** Give the resource two objective rows (`collect_gem` needed 5, `speak_elder`
needed 1). The quest only completes once BOTH are full, and each one fires its own On Objective
Completed as it fills.

**5. A questline that runs itself.**

```
On Start of Layout
  -> Quests: Register Quest  hand_in.tres
  -> Quests: Start Quest  gem_hunt.tres
```

Set `hand_in` as Gem Hunt's Next Quest and the second quest starts the moment the first finishes.

**6. Hand out the reward.**

```
On Quest Completed
  Condition: quest_id = "gems"
    -> add 200 to Gold
    -> show "Quest complete: " + Quests.Quest Title("gems")
```

**7. A quest-log label.**

```
Every tick
  -> set QuestLabel text = Quests.Quest Title("gems") + "  " + Quests.Objective Text("gems", "collect_gem")
```

It reads `Gem Hunt  3/5`.

**8. A progress bar per objective.**

```
Every tick
  -> set QuestBar value = Quests.Objective Progress("gems", "collect_gem") * 100
```

**9. A door that only opens after a quest.**

```
On player touches door
  Condition: Quests  Quest Is Completed  "bridge_repair"
    -> open the door
  Else
    -> show "The bridge master still needs your help."
```

**10. Only offer the quest once.**

```
On talk to Elder
  Condition: Quests  Quest Is Active  "gems"  (inverted)
  Condition: Quests  Quest Is Completed  "gems"  (inverted)
    -> Quests: Start Quest  gem_hunt.tres
```

**11. A "turn it in" step that is only possible when the collecting is done.**

```
On talk to Elder
  Condition: Quests  Objective Is Done  "gems", "collect_gem"
    -> Quests: Advance Objective  "gems", "hand_in", 1
```

**12. Let the player give up.**

```
On abandon button pressed
  -> Quests: Abandon Quest  "gems"
  -> hide the quest panel
```

An abandoned quest is neither active nor completed, so use case 10 will offer it again.

**13. Show how busy the player is.**

```
Every tick
  -> set TrackerLabel text = str(Quests.Active Quest Count()) + " quests in progress"
```

**14. Daily tasks.** Reset everything at the day rollover, then start the day's quests fresh.

```
On new day
  -> Quests: Reset All Quests
  -> Quests: Start Quest  daily_hunt.tres
```

**15. Persist progress across sessions.**

```
On quit pressed
  -> Quests: Save Quests
  -> quit the game
```

Pair it with the Register + Load block from [Saving between runs](#saving-between-runs) at startup.

**16. Celebrate an objective without ending the quest.**

```
On Objective Completed
  -> play a chime
  -> flash the objective row in the quest panel
```

**17. Gate an achievement on a whole questline.**

```
On Quest Completed
  Condition: Quests  Completed Quest Count  = 5
    -> unlock the "Hero of the Valley" achievement
```

### Other use cases

**Bounty board.** Register every bounty at startup, start the one the player accepts, and use Quest Is Active to grey out the rest of the board while a bounty is running.

**Escort mission checkpoints.** Give the escort quest one objective per checkpoint with needed 1 and advance it from each area trigger, so the quest log shows exactly how far along the road the pair has travelled.

**Crafting recipes as quests.** An objective per ingredient with the count you need turns the recipe panel into a quest log for free, complete with progress bars.

**Onboarding checklist.** A tutorial quest with five one-step objectives, each advanced the first time the player uses a mechanic, and On Quest Completed retires the tutorial HUD.

**Speedrun challenge chain.** Chain three timed quests through Next Quest so finishing one immediately arms the next, and record the run's time in On Quest Completed.

## Tips and common mistakes

- **Address quests by their id, not their title.** The title is for the player; the id is what every
  action takes. Changing the title later is free, changing the id is not.
- **Objective names must match exactly.** `collect_gem` in the resource grid and `"collect_gem"` in the
  Advance Objective row - a typo silently does nothing, because the pack ignores an objective it does
  not know.
- **Register the later quests of a chain.** A Next Quest that was never registered or started cannot be
  started automatically; the pack warns in the output when that happens.
- **Starting a quest again resets it** and takes it off the completed list - handy for repeatable
  quests, surprising if you start it every frame. Guard it with Quest Is Active / Quest Is Completed.
- **A quest with no objectives never completes.** Add at least one row.
- **Abandon is not a failure state.** It just forgets the quest. If you want failed quests to be
  remembered, keep your own flag when you abandon one.
- **Load Quests replaces what is tracked**, so call it once at startup rather than mid-game.
- **Hand out rewards yourself** in On Quest Completed - Reward Note is only text, so the pack never
  guesses at your economy.
