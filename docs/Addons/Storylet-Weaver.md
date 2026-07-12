# Storylet Weaver

Storylet Weaver is a quality-based narrative (QBN) engine you drop into any Godot EventSheets project. It ships as the **`Storylets` autoload singleton**, so it is available from every sheet with zero wiring: just type `Storylets:` in the action picker and the whole vocabulary is there. Instead of hand-writing one giant branching web of if/else ("if the player finished quest A and hasn't seen line B and it is night, show line C"), you register many small, self-contained **storylets**, each carrying its own **requirements**, and call **Draw** to get the best eligible one. Adding a new story beat means writing one more storylet with its own rules, not touching a decision tree in three places. This guide covers the whole pack: the mental model, setup, every Action, Condition, Expression, and Trigger, a stack of concrete use cases, and the traps to avoid.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Ambient NPC chatter.** A guard or shopkeeper pulls a contextually fitting line from a pool instead of cycling the same three quotes in order.
- **One-shot tutorials and intros.** A "welcome to the caves" line that plays the first time and never again, gated with **Set Max Plays** `1`.
- **Reputation and relationship dialogue.** Merchant greetings, companion banter, and faction reactions that change as a `reputation` or `affection` quality crosses thresholds, no hard-coded tree.
- **Roguelike encounter decks.** High-priority encounters lead the draw via **weight**, lower-priority ones age in when conditions shift, and **Reset All History** wipes the deck clean each run.
- **Cooldown-gated rumours.** Tavern rumours that will not repeat for a few in-game minutes, with the cooldown clock ticking automatically.
- **Branching visual-novel beats.** A story moment unlocks after the player visits a location, offering labelled choices you resolve with **Choose**.
- **Escalating puzzle or combat hints.** Stronger hints unlock in tiers as a `fails` quality rises, so players only see heavy guidance when they actually need it.
- **Loot and reward narration.** Weighted lines describe what the player found, with rare descriptions gated behind a quality flag.
- **Location-sensitive flavour text.** Entering a biome or district pulls a fitting beat by matching a text quality like `location = "harbour"`.
- **Journal and recap prompts.** Opening a journal runs **Evaluate** and lists every eligible recap by title for the player to pick.
- **Dynamic quest surfacing.** Urgent main-quest beats weighted far above ambient flavour always surface first when their requirements pass.
- **Idle or downtime events.** On a rest or a passing day, **Draw** the most fitting downtime scene from a growing library without a spaghetti of flags.

---

## Core concepts

The whole engine is four ideas: **qualities**, **storylets**, **requirements**, and the **Draw**.

**Qualities are your game state, mirrored flat.** A quality is a single named value: a number like `courage = 3`, or text like `location = "tavern"`. You keep this store in sync with your real game (set `gold` when gold changes, set `location` when the player moves) using **Set Quality**, **Increment Quality**, and **Clear Quality**. Requirements read only from this mirror, so the engine never needs to know about your nodes directly. A **missing quality reads as `0`** (for numbers) or `""` (for text), which keeps requirements predictable (more on that below).

**A storylet is one small story fragment.** It has an `id` (unique key you refer to it by), a `title`, a `body` (the text your game shows), and a set of rules. You create one with **Define Storylet**, then attach rules to it by id. Storylets live in the library until you overwrite them (re-defining the same id replaces it).

**Requirements decide eligibility.** Each requirement is a rule of the form quality `op` value, for example `courage >= 3` or `location = "tavern"`. You add them with **Add Requirement**, choosing the comparison from a dropdown: `>=`, `>`, `<=`, `<`, `=`, or `!=`. A storylet is eligible only when **all** of its requirements pass right now. Text comparisons (`=` / `!=` against a non-numeric value) compare as strings; the numeric operators coerce to numbers.

**Choices are labelled options on a storylet.** Add them with **Add Choice** (`choice_id` + display `text`). After a storylet is active, you present its choices and resolve the player's pick with **Choose**, which fires **On Choice Made**.

**Weight is preference.** When several storylets are eligible at once, higher **weight** wins. **Draw** takes the highest-weight eligible storylet (deterministic); **Draw Weighted** picks randomly in proportion to weight (variety). Set it with **Set Storylet Weight** (default `1`).

**Cooldowns and max plays limit repetition.** **Set Storylet Cooldown** makes a storylet ineligible for N seconds after it plays; the pack runs an internal clock that ticks every frame automatically, so "once per 30 seconds" just works with no clock wiring on your part. **Set Max Plays** caps how many times it can ever play (`-1` = unlimited, `1` = a one-shot).

**Draw = evaluate + pick + activate, in one call.** This is the five-second path. **Draw** rebuilds the eligible list, picks the best one, marks it played (recording the play and starting its cooldown), sets it as the **active** storylet, and fires **On Storylet Drawn**. Inside that trigger you read **Active Title** / **Active Body** and show them. If nothing qualifies, **Draw** fires **On None Available** instead. For a menu where you want the whole list rather than one pick, call **Evaluate** and read the **Available** expressions yourself. The play is counted the moment you Draw, not when the player chooses.

**The active storylet clears when resolved.** **Choose** (player picked an option) fires **On Choice Made** and then clears the active storylet. **Dismiss** clears it without a choice (the play still counted). Read **Active Title** / **Active Body** before you resolve, or **Chosen Id** inside On Choice Made.

---

## Setup

There is nothing to install per scene and nothing to attach. Storylet Weaver is registered as the **`Storylets` autoload**, so every sheet can call it. In your action picker, choose the **Storylets** category; in an expression field, type `Storylets.` and the expressions autocomplete.

A minimal first example, as event-sheet rows. It defines one storylet with a requirement, draws it when the player rests, and shows the result:

```
On Ready
  -> Storylets: Set Quality       "courage", 5
  -> Storylets: Define Storylet    "tavern", "The Tavern", "A warm fire crackles in the hearth."
  -> Storylets: Add Requirement    "tavern", "courage", ">=", 3

On rest pressed
  -> Storylets: Draw

On Storylet Drawn
  -> Show text  Storylets.Active Title()
  -> Show text  Storylets.Active Body()

On None Available
  -> Show text  "Nothing stirs right now."
```

Here `courage` is `5`, so `courage >= 3` passes, the `tavern` storylet is eligible, **Draw** activates it, and **On Storylet Drawn** shows its title and body. (`Show text` stands in for however your game displays text - a Label's `text`, a dialogue panel, a RichTextLabel. The `Storylets` expressions are the real part.)

Because the pack is a live event sheet, you can also open it and extend it directly, but you never have to: the ACEs below cover the whole workflow.

---

## ACE reference

Every name below is exactly what appears in the picker. Parameters are listed in order.

### Actions

| Action | Parameters | What it does |
| --- | --- | --- |
| **Define Storylet** | `id`, `title`, `body` | Registers (or replaces) a storylet: an id plus the title + body text your game shows. |
| **Set Storylet Weight** | `id`, `weight` | How strongly this storylet is preferred when several are eligible (higher = picked first / likelier). |
| **Set Storylet Cooldown** | `id`, `seconds` | Seconds this storylet is ineligible after it plays (`0` = no cooldown). |
| **Set Max Plays** | `id`, `max_plays` | How many times it may ever play (`-1` = unlimited, `1` = a one-shot). |
| **Add Requirement** | `id`, `quality_key`, `op`, `value` | A rule this storylet needs to be eligible, e.g. quality `courage` `>=` `3`. `op` is a dropdown: `>=`, `>`, `<=`, `<`, `=`, `!=`. A missing quality counts as `0` (or `""`). |
| **Add Choice** | `id`, `choice_id`, `text` | Adds a labelled choice the player can pick on this storylet (resolve it with Choose). |
| **Set Quality** | `key`, `value` | Stores a quality value (a number like `courage=3`, or text like `location="tavern"`). Requirements read these. |
| **Increment Quality** | `key`, `amount` | Adds to a numeric quality (creating it at `0` if new). |
| **Clear Quality** | `key` | Removes a quality key. |
| **Evaluate** | (none) | Rebuilds the available list: every eligible storylet, ordered by weight (highest first). Use the Available expressions to show a menu. |
| **Draw** | (none) | Evaluates, then activates the highest-weight eligible storylet and fires On Storylet Drawn (or On None Available if nothing qualifies). |
| **Draw Weighted** | (none) | Like Draw, but picks randomly among the eligible storylets in proportion to their weight (for variety). |
| **Choose** | `choice_id` | Resolves the active storylet's choice by id (fires On Choice Made, then clears the active storylet). React inside On Choice Made. |
| **Dismiss** | (none) | Clears the active storylet without making a choice (the play still counted). |
| **Reset Play Count** | `id` | Lets a one-shot or limited storylet play again (also clears its cooldown). |
| **Reset All History** | (none) | Clears every play count + cooldown (e.g. on New Game). |

### Conditions

| Condition | Parameters | What it checks |
| --- | --- | --- |
| **Has Active Storylet** | (none) | Whether a storylet is currently active (drawn, not yet resolved). |
| **Is Available** | `id` | Whether a storylet is in the current available list (call Evaluate first). |
| **Has Quality** | `key` | Whether a quality key has been set. |
| **Has Been Played** | `id` | Whether a storylet has played at least once. |
| **Is On Cooldown** | `id` | Whether a storylet is still cooling down. |
| **Is Library Empty** | (none) | Whether no storylets are registered. |

### Expressions

| Expression | Parameters | Returns | What it gives you |
| --- | --- | --- | --- |
| **Quality Number** | `key` | float | A quality as a number (`0` if unset). |
| **Quality Text** | `key` | String | A quality as text (`""` if unset). |
| **Available Count** | (none) | int | How many storylets are eligible (after Evaluate/Draw). |
| **Available Id** | `index` | String | The eligible storylet id at a position (`""` out of range). |
| **Available Title** | `index` | String | The title of the eligible storylet at a position. |
| **Active Id** | (none) | String | The active storylet id (`""` if none). |
| **Active Title** | (none) | String | The active storylet's title. |
| **Active Body** | (none) | String | The active storylet's body text. |
| **Choice Count** | (none) | int | How many choices the active storylet offers. |
| **Choice Id At** | `index` | String | The choice id at a position on the active storylet. |
| **Choice Text At** | `index` | String | The choice label at a position on the active storylet. |
| **Chosen Id** | (none) | String | The choice just picked (inside On Choice Made). |
| **Play Count** | `id` | int | How many times a storylet has played. |
| **Cooldown Remaining** | `id` | float | Seconds left on a storylet's cooldown (`0` if ready). |
| **Storylet Count** | (none) | int | How many storylets are registered. |

### Triggers

| Trigger | When it fires | Read inside it |
| --- | --- | --- |
| **On Storylet Drawn** | After Draw or Draw Weighted activates a storylet. | Active Id / Active Title / Active Body, Choice Count, Choice Text At. |
| **On Choice Made** | After Choose resolves the active storylet. | Chosen Id (the picked choice). |
| **On None Available** | After Draw or Draw Weighted finds nothing eligible. | (nothing storylet-specific; use it for a fallback). |

---

## Use cases

How to read these snippets: a line starting with **On** is a trigger (an event in the left lane), a plain indented line is a condition, and a line starting with **`->`** is an action. `Show text` and similar rows stand in for however your own game renders text or UI.

### 1. The simplest pool: ambient NPC lines

**Scenario:** A townsperson has a few flavour lines. Talking to them shows a fitting one.

```
On Ready
  -> Storylets: Define Storylet  "greet", "Greeting", "Welcome, traveller."
  -> Storylets: Define Storylet  "weather", "Weather", "Lovely day, isn't it?"
  -> Storylets: Define Storylet  "busy", "Busy", "Can't chat right now."

On npc talked to
  -> Storylets: Draw

On Storylet Drawn
  -> Show text  Storylets.Active Body()
```

With equal weights, Draw returns the first eligible one. For a fresh line each time, use **Draw Weighted** instead.

### 2. A one-shot introduction

**Scenario:** A tutorial line plays the first time the player enters an area, and never again.

```
On Ready
  -> Storylets: Define Storylet  "caves_intro", "The Crystal Caves", "Watch your step - the floors are treacherous."
  -> Storylets: Set Max Plays    "caves_intro", 1

On area entered
  -> Storylets: Draw

On Storylet Drawn
  -> Show text  Storylets.Active Body()
```

After it plays once, `caves_intro` is no longer eligible, so the next entry draws something else (or fires On None Available).

### 3. Reputation-gated merchant greeting

**Scenario:** The merchant greets the player differently as reputation rises. The friendliest eligible line should win.

```
On Ready
  -> Storylets: Define Storylet     "m_hostile", "Merchant", "Get out of my shop."
  -> Storylets: Add Requirement     "m_hostile", "reputation", "<", 0
  -> Storylets: Define Storylet     "m_neutral", "Merchant", "What do you need?"
  -> Storylets: Define Storylet     "m_friendly", "Merchant", "Ah, my best customer!"
  -> Storylets: Add Requirement     "m_friendly", "reputation", ">=", 10
  -> Storylets: Set Storylet Weight "m_friendly", 5

On reputation changed
  -> Storylets: Set Quality  "reputation", player_reputation

On merchant talked to
  -> Storylets: Draw

On Storylet Drawn
  -> Show text  Storylets.Active Body()
```

The neutral line has no requirement, so it is always eligible as a fallback; the friendly line's higher weight makes it lead when reputation is high enough.

### 4. A branching choice

**Scenario:** A gatekeeper offers to let the player pass. The player picks an option and you apply the outcome.

```
On Ready
  -> Storylets: Define Storylet  "gate", "The Gatekeeper", "You must pay the toll to pass."
  -> Storylets: Add Choice       "gate", "pay", "Pay 10 gold."
  -> Storylets: Add Choice       "gate", "refuse", "I refuse."

On reach gate
  -> Storylets: Draw

On Storylet Drawn
  -> Show text  Storylets.Active Body()
  -> Show choice button 0  Storylets.Choice Text At(0)
  -> Show choice button 1  Storylets.Choice Text At(1)

On choice button 0 pressed
  -> Storylets: Choose  "pay"
On choice button 1 pressed
  -> Storylets: Choose  "refuse"

On Choice Made
  -> Show text  "You chose: " + Storylets.Chosen Id()
```

Inside On Choice Made, branch on **Chosen Id** to run each outcome (open the gate for `"pay"`, spawn a guard for `"refuse"`).

### 5. A choice that is only offered when the player qualifies

**Scenario:** The "pay" option should only appear if the player actually has the gold. This port's choices carry no built-in prereqs, so gate the choice when you build the storylet.

```
On reach gate
  -> Storylets: Define Storylet  "gate", "The Gatekeeper", "You must pay the toll to pass."
  -> Storylets: Add Choice       "gate", "refuse", "I refuse."
  Storylets: Quality Number("gold") >= 10
    -> Storylets: Add Choice     "gate", "pay", "Pay 10 gold."
  -> Storylets: Draw
```

Because you re-define `gate` and add its choices right before drawing, the "pay" option is present only when `gold >= 10`. You can also just check `Storylets.Quality Number("gold") >= 10` inside On Choice Made before applying the cost.

### 6. Cooldown-gated rumours

**Scenario:** NPCs share rumours that should not repeat within 30 seconds. No clock wiring needed - the cooldown ticks on its own.

```
On Ready
  -> Storylets: Define Storylet      "r_mine", "Rumour", "The old mine is dangerous."
  -> Storylets: Set Storylet Cooldown "r_mine", 30
  -> Storylets: Define Storylet      "r_bandits", "Rumour", "Bandits on the north road."
  -> Storylets: Set Storylet Cooldown "r_bandits", 30

On ask for news
  -> Storylets: Draw Weighted

On Storylet Drawn
  -> Show text  Storylets.Active Body()
```

Once a rumour plays it drops out of the pool for 30 seconds, so repeated asks pull the other rumour first.

### 7. Weighted variety draw

**Scenario:** A quest system where urgent beats should almost always surface first, but ambient flavour still shows sometimes.

```
On Ready
  -> Storylets: Define Storylet     "urgent", "Urgent", "The castle is under attack!"
  -> Storylets: Set Storylet Weight "urgent", 100
  -> Storylets: Add Requirement     "urgent", "quest_stage", "=", 3
  -> Storylets: Define Storylet     "bird", "Ambient", "A bird flits past."
  -> Storylets: Define Storylet     "wind", "Ambient", "The wind picks up."

On beat requested
  -> Storylets: Draw Weighted

On Storylet Drawn
  -> Show text  Storylets.Active Body()
```

With **Draw Weighted**, the urgent beat is 100x likelier than an ambient line when its requirement passes; with plain **Draw** it always leads.

### 8. Escalating hint tiers

**Scenario:** Stronger puzzle hints unlock as the player fails. Count failures into a quality and gate each tier on it.

```
On Ready
  -> Storylets: Define Storylet  "hint1", "Hint", "Try looking near the fountain."
  -> Storylets: Add Requirement  "hint1", "fails", ">=", 2
  -> Storylets: Define Storylet  "hint2", "Hint", "The key is under the loose brick."
  -> Storylets: Add Requirement  "hint2", "fails", ">=", 5
  -> Storylets: Set Storylet Weight "hint2", 10

On puzzle failed
  -> Storylets: Increment Quality  "fails", 1

On hint button pressed
  -> Storylets: Draw

On Storylet Drawn
  -> Show text  Storylets.Active Body()
```

Because `fails` starts unset (reads as `0`), no hint is eligible until the player has failed twice; the stronger hint's higher weight makes it lead once five failures unlock it.

### 9. Companion banter off an affection threshold

**Scenario:** A party member reacts warmly once affection crosses a threshold, without a hard-coded dialogue tree.

```
On Ready
  -> Storylets: Define Storylet  "cold", "Companion", "...Let's just keep moving."
  -> Storylets: Define Storylet  "warm", "Companion", "I'm glad you're here."
  -> Storylets: Add Requirement  "warm", "affection", ">=", 50
  -> Storylets: Set Storylet Weight "warm", 3

On kind deed done
  -> Storylets: Increment Quality  "affection", 10

On camp rest
  -> Storylets: Draw

On Storylet Drawn
  -> Show text  Storylets.Active Body()
```

### 10. Location-sensitive flavour (text quality)

**Scenario:** Entering a district pulls a beat that matches it, using a text quality and the `=` operator.

```
On Ready
  -> Storylets: Define Storylet  "harbour_beat", "Harbour", "Gulls wheel over the fishing boats."
  -> Storylets: Add Requirement  "harbour_beat", "district", "=", "harbour"
  -> Storylets: Define Storylet  "market_beat", "Market", "Vendors shout over each other."
  -> Storylets: Add Requirement  "market_beat", "district", "=", "market"

On district entered
  -> Storylets: Set Quality  "district", entered_district_name
  -> Storylets: Draw

On Storylet Drawn
  -> Show text  Storylets.Active Body()
```

Because the requirement value `"harbour"` is not numeric, the comparison is done as text, so only the matching district's beat is eligible.

### 11. A journal menu of available storylets

**Scenario:** Opening the journal lists every eligible recap by title for the player to pick, instead of drawing one automatically.

```
On journal opened
  -> Storylets: Evaluate
  -> Clear list
  For i = 0 to Storylets.Available Count() - 1
    -> Add list item  Storylets.Available Title(i)

On list item pressed
  -> Show text  Storylets.Available Title(pressed_index)
```

**Evaluate** builds the ranked available list without activating anything; the **Available** expressions read it back. Use **Available Id(i)** if you need the id (for example to feed a later Draw of a specific beat).

### 12. A fallback when nothing qualifies

**Scenario:** When no storylet is eligible, show a graceful "nothing to say" line instead of a blank box.

```
On talk pressed
  -> Storylets: Draw

On Storylet Drawn
  -> Show text  Storylets.Active Body()

On None Available
  -> Show text  "They have nothing to say right now."
```

**Draw** fires exactly one of these two triggers, so you never have to check the count yourself for the five-second path.

### 13. Reacting to a choice and applying consequences

**Scenario:** A choice spends gold and nudges reputation. Read the pick inside On Choice Made.

```
On merchant deal
  -> Storylets: Define Storylet  "deal", "The Merchant", "Buy the rare map for 20 gold?"
  -> Storylets: Add Choice       "deal", "buy", "Buy it."
  -> Storylets: Add Choice       "deal", "pass", "Not today."
  -> Storylets: Draw

On buy pressed
  -> Storylets: Choose  "buy"
On pass pressed
  -> Storylets: Choose  "pass"

On Choice Made
  Storylets.Chosen Id() = "buy"
    -> Storylets: Increment Quality  "gold", -20
    -> Storylets: Increment Quality  "reputation", 1
```

The active storylet clears after Choose, so read **Active Title** / **Active Body** before you call it, and read **Chosen Id** inside On Choice Made.

### 14. Skip for now with Dismiss

**Scenario:** A back button closes the current storylet without picking a choice. The play still counts (it will respect max plays and cooldown).

```
On back pressed
  Storylets: Has Active Storylet
    -> Storylets: Dismiss
    -> Hide dialogue panel
```

**Dismiss** clears the active slot but does not fire On Choice Made and does not roll back the play count that Draw already recorded.

### 15. Roguelike run cleanup

**Scenario:** A roguelike reuses the same library each run but needs a fresh history so one-shots and cooldowns start over.

```
On new run started
  -> Storylets: Reset All History
  -> Storylets: Set Quality  "depth", 1
  -> Storylets: Set Quality  "gold", 0
```

**Reset All History** clears every play count and cooldown but leaves the library and qualities alone, so you reset only what a new run should reset.

### 16. A cooldown badge in the HUD

**Scenario:** Show the player how long until a rumour is available again.

```
On Process
  Storylets: Is On Cooldown  "r_mine"
    -> Show text  "Next rumour in " + str(int(Storylets.Cooldown Remaining("r_mine"))) + "s"
  Else
    -> Show text  "Ask for news"
```

**Is On Cooldown** gates the readout, and **Cooldown Remaining** gives the seconds left (`0` once it is ready).

### 17. Reward: let a one-shot play again

**Scenario:** A "fresh start" reward lets a story beat the player already saw appear once more.

```
On fresh start reward
  -> Storylets: Reset Play Count  "throne_intro"
```

**Reset Play Count** clears that single storylet's play count and cooldown, so a `max_plays = 1` beat becomes eligible again without touching the rest of the history.

### 18. Guarding a direct beat with Has Been Played

**Scenario:** Play a specific intro exactly once when the player first reaches a room, checking the history first.

```
On enter throne room
  -> Storylets: Define Storylet  "throne_intro", "The Throne Room", "Gold gleams under a thin layer of dust."

On enter throne room
  Storylets: Has Been Played  "throne_intro"  is false
    -> Storylets: Draw
```

Pair a specific storylet's id with **Has Been Played** when you want tight control over a single beat rather than a pooled Draw. (Setting **Set Max Plays** `1` achieves the same automatically, without the manual check.)

### Other use cases

**Sports announcer commentary.** Mirror the match into qualities like `score_gap`, `streak`, and `minutes_left`, and Draw Weighted a commentary line after each play. Cooldowns stop the announcer repeating himself, and a huge weight on the "comeback complete" beat makes sure the big call always wins the draw.

**Open-world radio news.** A news bulletin that reacts to the player's deeds is a pool of storylets gated on qualities like `banks_robbed` or `mayor_saved`. Each broadcast Draws a fitting story, one-shots keep old headlines from returning, and the fallback beat is the weather report.

**Colony-sim crisis decks.** Each in-game morning, Draw the day's event from a library of hardships and windfalls whose requirements read `food`, `morale`, and `season`. Choices carry the response ("ration it" / "feast"), and On Choice Made applies the consequences back into the same qualities.

**Boss taunt barks.** Track `times_dodged`, `player_hp`, and `phase` as qualities and let the boss Draw a taunt at scripted beats. The mockery escalates as requirements unlock crueler lines, and max plays keep the best zinger from wearing out mid-fight.

**Strategy-game chronicles.** An end-of-run chronicle or obituary assembles itself from storylets gated on what actually happened - `wars_won`, `heirs_lost`, `wonders_built`. Evaluate lists every earned entry in weight order, and the run's story reads back as prose instead of a stat dump.

---

## Tips and common mistakes

- **A missing quality reads as `0` (or `""`), not "undefined".** So `courage >= 3` on a quality you never set is simply **false**, and `location != "tavern"` on an unset `location` is **true**. This is friendlier than the original Construct 3 addon, where a missing value made every operator except `!=` fail. You still never have to pre-declare a quality: set it when it first matters.
- **Cooldowns tick automatically.** The pack runs its own internal clock in the background (it advances every frame), so **Set Storylet Cooldown** "once per 30 seconds" works with no timer, no `Set Game Time`, and no wiring on your part.
- **Draw does everything at once.** **Draw** is evaluate + pick the best + activate + fire the trigger. You do not call **Evaluate** first and you do not manually select. Use **Evaluate** on its own only when you want the full **Available** list for a menu.
- **The play is counted at Draw, not at Choose.** Drawing a storylet immediately records the play and starts its cooldown. **Dismiss** and **Choose** both clear the active slot but neither un-counts that play.
- **Read Active values before you resolve.** **Choose** and **Dismiss** clear the active storylet, so `Active Title` / `Active Body` go empty afterward. Read them while the storylet is active, and read **Chosen Id** inside **On Choice Made**.
- **Choices here are just id + text.** Unlike the Construct 3 version, **Add Choice** has no per-choice prerequisites. Gate an option by only adding it when a quality qualifies (see use case 5), or by checking `Quality Number(...)` before you apply its consequence.
- **Build storylets with typed ACEs, not a JSON blob.** You assemble a storylet from discrete rows - **Define Storylet**, then **Add Requirement** / **Add Choice** / **Set Storylet Weight** and friends, all keyed by the same id. There is no JSON string to hand-write or mis-quote.
- **Re-defining an id replaces it.** Calling **Define Storylet** with an existing id overwrites that storylet (and its requirements and choices reset, since you are starting it fresh). Use this to rebuild a storylet's rules from current game data before a Draw.
- **Keep qualities in sync with your game.** Requirements only see what you mirror in. If a gate seems never to open, confirm you called **Set Quality** / **Increment Quality** for the key it checks; **Has Quality** and the **Quality Number** / **Quality Text** expressions help you verify the store.
- **Weight sorts the eligible list; it does not gate.** A high weight makes a storylet lead the draw, but a storylet with no passing requirements is still ineligible no matter how heavy it is. Use **Add Requirement** to gate and **Set Storylet Weight** to rank.
