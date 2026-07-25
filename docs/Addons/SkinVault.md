# SkinVault

SkinVault is a cosmetic-ownership manager for gacha, loot-box, and unlockable-skin systems. It ships as an
**autoload pack**: once registered it becomes the `SkinVault` singleton, live in every scene and available
from every sheet with no node to attach and no wiring. SkinVault owns the *decisions* - what the player has,
what they can still get, the weighted roll, and the pity streak - and hands you clean triggers to react to.
It never draws anything and never touches your currency: you build the gacha box, the shop grid, and the
unlock popups, and SkinVault tells you what was won and when.

Everything below uses only the real actions, conditions, expressions, triggers, and Inspector knobs that
this pack exposes. Nothing is invented.

---

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [The data-driven path: a SkinCatalogResource asset](#the-data-driven-path-a-skincatalogresource-asset)
7. [Tips and common mistakes](#tips-and-common-mistakes)

A quick note on the pseudocode in this guide. Rows read like the event sheet does:

- `On X` is a trigger - either a SkinVault trigger or a UI event from one of your own objects.
- `?` marks a condition that has to be true for the row to run.
- `->` marks an action.
- Expressions are written the way you type them in a value field, for example `SkinVault.Owned Count()`
  or `SkinVault.Skin Name(SkinVault.Rolled Id())`.

---

## Where this pack shines

- **Gacha and loot boxes.** Spend currency, hit Roll, and get a weighted-random skin from the pool of
  things the player does not own yet, with a pity streak that guarantees a rare result after a run of bad luck.
- **Cosmetic shops with a real economy.** The Purchase handshake asks your wallet "can they afford this?"
  before anything is granted, so SkinVault and your coins never disagree.
- **Battle passes and reward tracks.** Each tier calls Grant to hand over a skin for free; SkinVault ignores
  it silently if the player already owns it, so you never write duplicate checks.
- **Daily-login and achievement rewards.** Grant a skin on a milestone and react to On Skin Unlocked to pop
  the "New unlock!" toast.
- **Limited-time event banners.** Tag skins with an event name and roll only that tag; when the player has
  collected them all, On Pool Empty tells you to close the banner.
- **Collection and wardrobe screens.** Is Owned and Is Unlockable drive full-colour versus locked cards, and
  Owned Count over Total Skins gives you a completion percentage for free.
- **Loadout unlock systems.** Treat each weapon skin, character variant, or ability tint as a skin; Is
  Unlockable drives the lock overlay in the loadout grid.
- **Season resets and rotating catalogs.** Revoke seasonal skins when a season ends and react to On Skin
  Revoked to update the UI card by card.
- **Save and load of cosmetic progress.** Owned Ids plus Pity Counter serialise the whole state to a string;
  Load Owned plus Set Pity Count restore it after you re-register the catalog.
- **Pity meters and near-miss drama.** Pity Progress feeds a fill bar and Pity Counter feeds a "7 / 10" label
  so the player can see the guarantee getting closer.

---

## Core concepts

SkinVault has a small mental model. Learn these five pieces and the rest of the guide reads itself.

**Rarities.** A rarity is a named bucket with two numbers: a **weight** and a **tier**. Weight decides how
likely that rarity is in a roll - higher weight means *more common*, so `common` might be weight 100 and
`legendary` weight 2. Tier is a plain integer rank - higher means *rarer* - and it exists so pity can say
"guarantee epic or better" without caring what order you registered things in. Register your rarities with
ascending tiers, for example common 0, rare 1, epic 2, legendary 3.

**Skins.** A skin is one cosmetic item: a unique **id** you refer to it by, a **display name** to show,
the **rarity** it belongs to, a **cost** for the shop (0 means not purchasable), and optional
comma-separated **tags** for grouping. Every skin must reference a rarity you have already registered.

**The owned set.** SkinVault keeps a set of the ids the player owns. The **pool** is everything registered
that is *not* owned - that is what a roll draws from. When the pool is empty there is nothing left to roll.

**Three ways in, one way to react.** A skin enters the owned set through exactly three paths:

- **Roll** - a weighted-random pick from the unowned pool, with pity applied.
- **Purchase** - a player-initiated, cost-gated unlock that runs through a handshake with your wallet.
- **Grant** - a free, code-driven unlock for rewards, logins, and cheats.

All three funnel into the same **On Skin Unlocked** trigger, where `SkinVault.Unlock Method()` tells you
which path it came from ("roll", "purchase", or "grant"). Write your unlock celebration once and branch on
the method if you need to.

**Tier-based pity.** Pity is the "bad luck protection" every gacha game has. Every roll that lands *below*
the pity rarity's tier bumps a counter; every roll that lands at or above it resets the counter to 0. When
the counter reaches the threshold, the next roll's pool is trimmed to only skins at or above the pity tier,
so the guarantee lands. Because pity compares **tiers** (integers), "epic or better" is exact and never
depends on registration order. Three Inspector knobs, all under the **Pity** group, tune it:

| Knob (Inspector) | Underlying name | Type | Default | What it does |
|---|---|---|---|---|
| Enable Pity | `enable_pity` | bool | `true` | Turn the whole pity guarantee on or off. Off makes every roll a pure weighted random. |
| Pity Threshold | `pity_threshold` | int (1 - 200) | `10` | Misses in a row before the next roll is forced to pity rarity or better. |
| Pity Rarity | `pity_rarity` | String | `"epic"` | The rarity name whose tier is the guaranteed floor when pity fires. |

---

## Setup

SkinVault is an autoload. Register it once and the `SkinVault` singleton is available in every sheet, with
the whole SkinVault category showing up in the picker. There is nothing to attach to a node.

1. Enable the EventSheets plugin and make sure the SkinVault pack is present under
   `eventsheet_addons/skin_vault/`.
2. Register it as the autoload (the plugin's Register Autoload flow) so the `SkinVault` singleton exists at
   run time. From then on, every sheet can call SkinVault actions and read SkinVault expressions with no
   further wiring.
3. Set the pity knobs on the SkinVault autoload in the Inspector if you want to change the defaults.

A minimal first example - register a tiny catalog, roll on a button, and show what was won:

```
On Ready
  -> SkinVault: Register Rarity  "common", 100, 0
  -> SkinVault: Register Rarity  "rare", 30, 1
  -> SkinVault: Register Rarity  "epic", 8, 2
  -> SkinVault: Register Skin  "cap", "Baseball Cap", "common", 50, "hat"
  -> SkinVault: Register Skin  "fedora", "Sharp Fedora", "rare", 150, "hat"
  -> SkinVault: Register Skin  "crown", "Golden Crown", "epic", 400, "hat"

On roll button pressed
  -> SkinVault: Roll  ""

On Skin Unlocked
  -> Set label text  "You unlocked " + SkinVault.Skin Name(SkinVault.Unlocked Id())
```

Rarities must be registered before the skins that use them, because a skin points at a rarity by name.
Register the catalog once (On Ready is the natural place). The catalog is rebuilt each session and is never
saved - only the owned ids and pity counter are, which is what keeps old save files safe when your catalog
grows.

---

## ACE reference

### Actions

| Action | Description |
|---|---|
| Load Catalog  `catalog` (Resource) | Registers a whole catalog (rarities + skins) from a **SkinCatalogResource** (a `.tres` you filled in the Inspector) in one step - the data-driven alternative to a string of Register Rarity + Register Skin actions. Drop the **Skin Catalog Loader** behaviour on a node to load one automatically on ready. |
| Register Rarity  `name`, `weight`, `tier` | Registers a rarity with a roll weight (higher = commoner) and a tier rank (higher = rarer; pity guarantees a tier at or above the pity rarity). |
| Register Skin  `id`, `display_name`, `rarity`, `cost`, `tags` | Registers a skin: a unique id, a display name, its rarity (must be registered), a cost (0 = not purchasable), and comma-separated tags. |
| Roll  `tag` | Rolls a weighted-random unowned skin (optional tag filter; `""` = any) and grants it. Applies pity, then fires On Skin Rolled and On Skin Unlocked. Fires On Pool Empty if nothing is left. |
| Grant  `skin_id` | Unlocks a skin for free (fires On Skin Unlocked). Does nothing if already owned. |
| Revoke  `skin_id` | Removes a skin from the owned set (fires On Skin Revoked). |
| Purchase  `skin_id` | Starts a purchase: fires On Purchase Requested carrying the skin id and cost. Check your wallet there, then call Confirm or Cancel Purchase. SkinVault never touches currency itself. |
| Confirm Purchase  `skin_id` | Completes a purchase and grants the skin (fires On Skin Unlocked with method "purchase"). |
| Cancel Purchase  `skin_id` | Cancels a pending purchase (fires On Purchase Cancelled). |
| Reset Pity | Sets the pity counter back to 0. |
| Load Owned  `owned_csv` | Restores the owned set from a comma-separated id list (pair with the Owned Ids expression to save). |
| Set Pity Count  `count` | Restores the pity counter (for save/load). |

### Conditions

| Condition | Description |
|---|---|
| Is Owned  `skin_id` | Whether the player owns a skin. |
| Is Registered  `skin_id` | Whether a skin exists in the catalog. |
| Is Unlockable  `skin_id` | Whether a skin is registered but not yet owned (drives lock icons). |
| Is Pool Empty  `tag` | Whether there are no unowned skins left to roll (optional tag filter). |

### Expressions

| Expression | Returns | Description |
|---|---|---|
| Total Skins() | int | How many skins are registered. |
| Owned Count() | int | How many skins the player owns. |
| Pool Count(`tag`) | int | How many unowned skins remain (optional tag filter). |
| Skin Name(`skin_id`) | String | A skin's display name. |
| Skin Rarity(`skin_id`) | String | A skin's rarity name. |
| Skin Cost(`skin_id`) | float | A skin's cost (0 if not purchasable or unknown). |
| Pity Counter() | int | The current miss streak toward pity. |
| Pity Progress() | float | Progress toward pity as 0.0 - 1.0 (for a bar). |
| Owned Ids() | String | The owned skin ids as a comma-separated string (pair with Load Owned to save). |
| Rolled Id() | String | The skin just rolled (inside On Skin Rolled). |
| Unlocked Id() | String | The skin just unlocked (inside On Skin Unlocked). |
| Unlock Method() | String | How it was unlocked - "roll", "grant", or "purchase" (inside On Skin Unlocked). |
| Requested Id() | String | The skin being purchased (inside On Purchase Requested / Cancelled). |
| Requested Cost() | float | The cost of the requested purchase (inside On Purchase Requested). |
| Revoked Id() | String | The skin just revoked (inside On Skin Revoked). |

### Triggers

| Trigger | Fires when |
|---|---|
| On Skin Rolled | A Roll succeeds and a skin is chosen. Rolled Id() is valid here. |
| On Skin Unlocked | A skin enters the owned set via roll, purchase, or grant. Unlocked Id() and Unlock Method() are valid here. |
| On Purchase Requested | Purchase is called for an unowned, registered skin. Requested Id() and Requested Cost() are valid here. |
| On Purchase Cancelled | Cancel Purchase is called. Requested Id() is valid here. |
| On Skin Revoked | A skin is removed from the owned set. Revoked Id() is valid here. |
| On Pool Empty | A Roll finds no unowned skins left (optionally within the rolled tag). |

### Inspector properties

All three live under the **Pity** group on the SkinVault autoload.

| Property | Type | Default | Description |
|---|---|---|---|
| Enable Pity | bool | `true` | Guarantee a high-rarity roll after a streak of misses. Off = pure weighted random. |
| Pity Threshold | int (1 - 200) | `10` | Misses in a row before the next roll is guaranteed pity rarity or better. |
| Pity Rarity | String | `"epic"` | The rarity (by name) that pity guarantees at or above. |

### Inspector properties are ACEs too

Every property this pack exposes in the Inspector is also reachable from the picker, generated for you:
an expression named after the property reads it, a **Set ...** action writes it, and for number properties
**Add To ...** and **Subtract From ...** adjust it by an amount. They sit in the pack's own category
alongside the verbs above, so any knob you can set in the Inspector is also something a sheet can read and
change while the game runs.

---

## Use cases

### 1. The simplest possible roll

**Scenario:** a button hands the player a random skin and shows its name.

```
On Ready
  -> SkinVault: Register Rarity  "common", 100, 0
  -> SkinVault: Register Rarity  "rare", 25, 1
  -> SkinVault: Register Skin  "hat_red", "Red Hat", "common", 0, ""
  -> SkinVault: Register Skin  "hat_blue", "Blue Hat", "rare", 0, ""

On roll button pressed
  -> SkinVault: Roll  ""

On Skin Unlocked
  -> Set label text  "You got: " + SkinVault.Skin Name(SkinVault.Unlocked Id())
```

Roll grants the skin immediately, so On Skin Unlocked fires on the same press. There is no separate confirm
step for rolls.

### 2. Coin-gated roll without the handshake

**Scenario:** each roll costs 100 coins and you are happy to spend them yourself before rolling. This is the
quick path when you do not need SkinVault's purchase flow.

```
On roll button pressed
  ? your wallet balance >= 100
  ? SkinVault: Is Pool Empty ""   is false
  -> Wallet: Spend  100          // your own coin logic, not SkinVault
  -> SkinVault: Roll  ""

On roll button pressed
  ? your wallet balance < 100
  -> Show toast  "Not enough coins"
```

Check Is Pool Empty first so you do not charge the player for a roll that has nothing left to give.

### 3. Reveal popup on a roll

**Scenario:** a gacha box spins, then reveals the prize. The skin is already owned by the time On Skin
Rolled fires, so the popup is pure presentation.

```
On roll button pressed
  -> SkinVault: Roll  ""

On Skin Rolled
  -> Play animation  "BoxSpin"
  -> Set reveal name text  SkinVault.Skin Name(SkinVault.Rolled Id())
  -> Set reveal rarity text  SkinVault.Skin Rarity(SkinVault.Rolled Id())
  -> Show reveal panel
```

On Skin Rolled fires just before On Skin Unlocked, and both point at the same skin this pass. Use Rolled Id()
here; use Unlocked Id() in On Skin Unlocked.

### 4. Shop purchase handshake with a wallet

**Scenario:** a shop sells one skin per card, gated by your coin wallet (for example the Currency Ledger
pack). This is the intended purchase path: SkinVault carries the cost, your wallet decides, SkinVault
finishes the unlock.

```
On shop card clicked
  -> SkinVault: Purchase  clicked_card_id

On Purchase Requested
  ? CurrencyLedger: Can Afford  SkinVault.Requested Cost()   // your wallet's condition
  -> CurrencyLedger: Spend  SkinVault.Requested Cost()       // your wallet's action
  -> SkinVault: Confirm Purchase  SkinVault.Requested Id()

On Skin Unlocked
  ? SkinVault.Unlock Method() = "purchase"
  -> Refresh shop card  SkinVault.Unlocked Id()
```

Purchase never touches coins - it only fires On Purchase Requested with the id and cost. Your wallet spends,
then Confirm Purchase grants the skin. If the wallet and SkinVault ever look out of sync, it is because a
Spend happened without a matching Confirm Purchase (or the other way round).

### 5. Insufficient-funds cancel path

**Scenario:** the same shop, but the player cannot afford the skin. Cancel the request cleanly so no skin is
granted.

```
On Purchase Requested
  ? CurrencyLedger: Can Afford  SkinVault.Requested Cost()   is false
  -> SkinVault: Cancel Purchase  SkinVault.Requested Id()

On Purchase Cancelled
  -> Show toast  "You cannot afford " + SkinVault.Skin Name(SkinVault.Requested Id())
```

Purchase does not check cost for you - it is your wallet's job in On Purchase Requested. Always end a
requested purchase with either Confirm Purchase or Cancel Purchase so nothing is left hanging.

### 6. Battle-pass tier grant

**Scenario:** reaching a battle-pass tier hands over a specific skin for free.

```
On battle pass tier reached  (tier 10)
  -> SkinVault: Grant  "bp_tier10_cape"

On Skin Unlocked
  ? SkinVault.Unlock Method() = "grant"
  -> Play unlock fanfare
  -> Set toast text  "Tier reward: " + SkinVault.Skin Name(SkinVault.Unlocked Id())
```

Grant does nothing if the player already owns the skin, so replaying a tier or reloading a pass never
double-grants.

### 7. Daily-login free reward

**Scenario:** the first login of the day grants a login skin.

```
On daily login bonus
  -> SkinVault: Grant  "login_streak_hat"
```

Because Grant is free and idempotent, you can call it every login without guarding against re-grants.

### 8. Limited-time event banner

**Scenario:** a summer event has its own banner that only rolls event skins, and closes itself once the
player has collected them all.

```
On Ready
  -> SkinVault: Register Skin  "dragon_fire", "Fire Dragon", "legendary", 0, "event_summer"
  -> SkinVault: Register Skin  "dragon_ice", "Ice Dragon", "epic", 0, "event_summer"

On event banner pull
  -> SkinVault: Roll  "event_summer"

On Pool Empty
  -> Show toast  "You collected every summer skin!"
  -> Hide event banner
```

Passing a tag to Roll restricts the pool to that tag. If every event skin is already owned, On Pool Empty
fires instead of On Skin Unlocked.

### 9. Guarantee an epic-or-better after N misses

**Scenario:** you want a hard pity that forces at least an epic after ten unlucky rolls. This is pure
Inspector setup on the SkinVault autoload, plus rarities with sensible tiers.

```
On Ready
  -> SkinVault: Register Rarity  "common", 100, 0
  -> SkinVault: Register Rarity  "rare", 30, 1
  -> SkinVault: Register Rarity  "epic", 8, 2
  -> SkinVault: Register Rarity  "legendary", 2, 3
  // In the Inspector, Pity group:
  //   Enable Pity  = on
  //   Pity Threshold = 10
  //   Pity Rarity  = "epic"

On roll button pressed
  -> SkinVault: Roll  ""
```

Pity compares tiers, so "epic or better" means tier 2 or 3 (epic and legendary). Any roll that lands at
common or rare bumps the counter; the tenth roll is trimmed to epic-and-up. Registration order does not
matter here - only the tier numbers.

### 10. Pity progress meter

**Scenario:** show a bar and a "7 / 10" label so the player sees the guarantee approaching.

```
On roll UI opened
  -> Set pity bar fill  SkinVault.Pity Progress()
  -> Set pity label text  SkinVault.Pity Counter() + " / 10"

On Skin Rolled
  -> Set pity bar fill  SkinVault.Pity Progress()
  -> Set pity label text  SkinVault.Pity Counter() + " / 10"
```

Pity Progress is already 0.0 to 1.0, so it feeds a fill value with no math. Refresh both on On Skin Rolled
because that is when the counter moves.

### 11. Lock icons in a collection grid

**Scenario:** a wardrobe screen shows every skin; owned ones are full colour, the rest show a lock overlay.

```
On building a wardrobe card  (for skin_id)
  ? SkinVault: Is Owned  skin_id
  -> Set card state  "owned"
  -> Set card name  SkinVault.Skin Name(skin_id)

On building a wardrobe card  (for skin_id)
  ? SkinVault: Is Unlockable  skin_id
  -> Set card state  "locked"
  -> Set card cost text  SkinVault.Skin Cost(skin_id)
```

Is Unlockable is true only when a skin is registered but not yet owned, which is exactly the "show a lock"
case. Is Owned covers the full-colour case.

### 12. Completion percentage

**Scenario:** a header reads "Collection: 12 / 40 (30%)".

```
On collection screen opened
  -> Set header text  "Collection: " + SkinVault.Owned Count() + " / " + SkinVault.Total Skins()
```

Owned Count over Total Skins is your completion fraction. Pool Count is the same idea from the other side -
how many are still unlockable right now.

### 13. Branch the celebration by unlock method

**Scenario:** rolls play a fanfare, purchases play a cash chime, and grants show a gift icon - all from one
trigger.

```
On Skin Unlocked
  ? SkinVault.Unlock Method() = "roll"
  -> Play sound  "fanfare"

On Skin Unlocked
  ? SkinVault.Unlock Method() = "purchase"
  -> Play sound  "cash_register"

On Skin Unlocked
  ? SkinVault.Unlock Method() = "grant"
  -> Show gift icon
```

One unlock trigger, three reactions. Unlock Method() is "roll", "purchase", or "grant".

### 14. Season-end cleanup

**Scenario:** when a season ends you take back its exclusive skins, and the UI updates card by card.

```
On season ended
  -> SkinVault: Revoke  "season3_wings"
  -> SkinVault: Revoke  "season3_aura"

On Skin Revoked
  -> Grey out card  SkinVault.Revoked Id()
  -> Show toast  SkinVault.Skin Name(SkinVault.Revoked Id()) + " expired"
```

Revoke only removes ownership - the skin stays in the catalog, so it can be re-earned later. Each Revoke
fires its own On Skin Revoked so you can animate every removal.

### 15. Save cosmetic progress

**Scenario:** whenever the player unlocks something, write the whole cosmetic state to a save slot.

```
On Skin Unlocked
  -> Save to file  key "skins_owned",  value SkinVault.Owned Ids()
  -> Save to file  key "skins_pity",   value SkinVault.Pity Counter()
```

Owned Ids() is a comma-separated string of owned ids; Pity Counter() is the streak. Those two values are the
entire persistent state - the catalog itself is never saved.

### 16. Load cosmetic progress

**Scenario:** on game start, rebuild the catalog and then restore what the player owned and their pity streak.

```
On Ready
  // 1. Re-register the catalog first (it is never part of the save)
  -> SkinVault: Register Rarity  "common", 100, 0
  -> SkinVault: Register Rarity  "epic", 8, 2
  -> SkinVault: Register Skin  "cap", "Baseball Cap", "common", 50, "hat"
  -> SkinVault: Register Skin  "crown", "Golden Crown", "epic", 400, "hat"
  // 2. Then restore progress
  -> SkinVault: Load Owned  loaded_owned_csv
  -> SkinVault: Set Pity Count  loaded_pity_value
```

Always register the catalog before Load Owned. Ids that are no longer in the catalog stay in the owned set
harmlessly but never show up in pool queries, so an older save never breaks a newer build.

### 17. "Own everything" guard on the roll button

**Scenario:** stop the player rolling (and paying) once nothing is left.

```
On roll button pressed
  ? SkinVault: Is Pool Empty ""
  -> Show toast  "You own every skin!"
  -> Disable roll button

On roll button pressed
  ? SkinVault: Is Pool Empty ""   is false
  -> SkinVault: Roll  ""
```

Is Pool Empty with an empty tag checks the whole pool; pass a tag to check just that group.

### 18. Debug grant and pity reset

**Scenario:** a developer hotkey grants a specific skin and clears the pity streak for testing.

```
On debug key pressed  (G)
  -> SkinVault: Grant  "crown"

On debug key pressed  (P)
  -> SkinVault: Reset Pity
```

Grant is the cheat-friendly path - free, immediate, and safe to spam. Reset Pity is also useful in real
designs, for example clearing the streak after a paid ten-pull.

### Other use cases

**Sticker albums.** A collect-them-all album is the owned set drawn as a grid: every pack rip is a Roll, duplicates are impossible because the pool only holds unowned stickers, and Owned Count over Total Skins is the album's completion line. On Pool Empty is the "album complete!" fanfare.

**Rhythm-game song unlocks.** Tracks are skins with rarities as difficulty tiers: clear a set to Grant the next song, or let a jukebox token Roll a surprise unlock. Is Unlockable drives the greyed-out entries in the song wheel.

**Cooking recipe discovery.** New dishes join the menu by Grant when an ingredient is first found, or by a market-stall Roll for a random regional recipe. Tags like "dessert" and "soup" let an event roll only one cuisine, and the recipe book's completion percentage falls straight out of the counts.

**In-world gachapon machines.** Each physical capsule machine in your hub rolls a different tag - the "spooky" machine only dispenses skins tagged for it. Is Pool Empty per tag lets a machine display SOLD OUT while the others keep spinning, all against one shared catalog.

**Roguelite roster unlocks.** Playable characters and starting relics are skins granted by achievements between runs, with rarity tiers marking how deep a run must go to earn them. The character-select screen reads Is Owned for selectable heroes and shows silhouettes for the rest.

---

## The data-driven path: a SkinCatalogResource asset

The Register actions above are perfect while a catalog is small or built from live data. A shipped cosmetics catalog is usually neither - it is a long, mostly-fixed list that a designer wants to edit without opening a sheet. For that, author it as **data**.

**SkinCatalogResource** is a plain Godot `Resource` you create as a `.tres`, holding two grids you fill in the Inspector:

| Grid | Columns |
| --- | --- |
| `rarities` | `name`, `weight` (higher = commoner), `tier` (higher = rarer; pity guarantees a tier at or above the pity rarity) |
| `skins` | `id`, `name`, `rarity` (must match a rarity above), `cost` (`0` = not purchasable), `tags` (comma-separated) |

Load it either way:

```
On Ready
  -> SkinVault: Load Catalog  preload("res://cosmetics/catalog.tres")
```

or attach the **Skin Catalog Loader** behaviour to a node, drop the `.tres` onto its `Catalog` slot, and the whole catalog registers on ready - the Inspector flags the slot with a warning until a resource is attached.

Loading is additive and equivalent to running the Register actions yourself, so rolls, pity, ownership and every expression behave identically, and you can still register extra rarities or skins afterwards (a seasonal drop, an event exclusive). Because ownership is stored separately, the save story is unchanged: re-register the catalog on load - from the asset - then `Load Owned` and `Set Pity Count`.

---

## Tips and common mistakes

- **Register rarities before skins.** A skin points at its rarity by name, so the rarity has to exist first.
  Register the whole catalog once, on On Ready.
- **Tier is what pity reads, not order.** This port guarantees "epic or better" by comparing the pity
  rarity's tier integer, so it never depends on the order you registered rarities in. Give rarities ascending
  tiers (common 0, rare 1, epic 2, legendary 3) and set Pity Rarity to the floor you want.
- **Roll grants immediately.** There is no confirm step for rolls. On Skin Rolled and On Skin Unlocked both
  fire on the same Roll, and the skin is already owned when the popup appears. Use the reveal purely for
  presentation.
- **Currency stays external.** SkinVault never spends or checks coins. Purchase just fires On Purchase
  Requested carrying the cost; your wallet (for example the Currency Ledger pack) decides, then you call
  Confirm Purchase or Cancel Purchase. Always end a request with one of those two.
- **Match Requested / Rolled / Unlocked / Revoked to their trigger.** Requested Id() and Requested Cost() are
  meaningful inside On Purchase Requested and On Purchase Cancelled; Rolled Id() inside On Skin Rolled;
  Unlocked Id() and Unlock Method() inside On Skin Unlocked; Revoked Id() inside On Skin Revoked. Reading them
  elsewhere gives you the last value, not the current event.
- **Grant and Purchase are no-ops on skins you already own.** Grant silently does nothing if the skin is
  owned, and Purchase does nothing for an already-owned or unregistered skin, so you rarely need your own
  duplicate checks.
- **The catalog is not saved - only ownership and pity are.** Save Owned Ids() and Pity Counter(); on load,
  re-register the catalog first, then Load Owned and Set Pity Count. This is what keeps old saves working
  when you add new skins.
- **There is no rarity colour or weight expression.** Skin lookups (Skin Name, Skin Rarity, Skin Cost) exist,
  but colour is yours to map from the rarity name in your UI.
- **Typed parameters, not JSON blobs.** Register Rarity and Register Skin take discrete typed fields, so you
  author the catalog as plain readable rows rather than hand-editing a JSON string.
- **Or author the catalog as a data asset.** For a big or mostly-fixed catalog, fill a **SkinCatalogResource**
  `.tres` in the Inspector (rarities and skins as editable tables) and register the whole thing with **Load
  Catalog**, or drop the **Skin Catalog Loader** behaviour on a node to do it on ready. Loading is additive,
  so you can still add or adjust entries with the Register actions afterwards.
- **Check Is Pool Empty before charging for a roll.** A Roll on an empty pool fires On Pool Empty and grants
  nothing, so guard the button (and any currency spend) with Is Pool Empty first.
