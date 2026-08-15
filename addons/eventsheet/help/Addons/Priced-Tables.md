# Priced Tables

**Priced Tables** is the general priced-interaction table: a shop's stock, an upgrade kiosk's tiers, a
toll gate's fares, a skill tree's nodes, an unlock wall. You attach the **Priced Table** behavior to the
thing that sells and drop a **Price Table resource** (a `.tres` you fill in the Inspector) on its slot.
Every entry answers the same four questions - what is it called, what does it cost, how many are left,
and is it open yet - and **Buy Entry** runs the whole transaction in one row: unlocked? in stock?
affordable? Then it takes the money, counts the stock down, and fires **On Purchased** or
**On Purchase Refused** with the reason.

The wallet is deliberately somebody else's job. This pack holds no economy: it asks whatever purse
answers, in order, and falls back to one exported number when nothing does.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [The wallet seam](#the-wallet-seam)
5. [ACE reference](#ace-reference)
6. [The Price Table resource](#the-price-table-resource)
7. [Use cases](#use-cases)
8. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this pack shines

- **Shops and vendors** - a blacksmith with four items, two of them limited stock.
- **Upgrade kiosks** - tiers that unlock one another as they are bought.
- **Toll gates and fares** - pay to pass, refused with a readable reason when you cannot.
- **Skill trees** - a node per skill, locked until its prerequisite says otherwise.
- **Unlock walls** - a level select where each stage has a price and a requirement note.
- **Crafting benches** where the "price" is a material count in your own currency.
- **Cosmetic stores** with one-of-a-kind entries (stock 1) beside unlimited ones.
- **Repair and refuel stations** priced per use, restocked on a timer.
- **Bribe or persuasion menus** in a dialogue, priced in reputation instead of gold.
- **Daily deals** - a table restocked and re-priced every morning from one row.

## Core concepts

- **A table is a data asset.** A **Price Table resource** holds a name, a default currency, and one
  grid of entries. Stocking a shop is filling a table, not writing rows.
- **The id is the address.** Every action, condition and expression takes an entry's `id` string. Keep
  ids short and unique (`iron_sword`), and use the label for what the player reads.
- **Stock is a number, and -1 means unlimited.** 0 is sold out. That one convention covers a bottomless
  potion shelf and a one-of-a-kind relic in the same grid.
- **Locked is a state, not a deletion.** A locked entry still appears in the table with its price and
  its requirement note, so your UI can grey it out and explain itself. Buying it is refused.
- **One row does the whole transaction.** Buy Entry checks the id, the lock, the stock and the wallet
  in that order and stops at the first problem, so a refusal always has one honest reason.
- **The pack never hands over the goods.** It fires On Purchased with the id and the price; giving the
  sword, opening the gate, or granting the skill is your event, in your game's terms.
- **The wallet is decoupled.** Nothing here knows what money is. See the next section.

## Setup

Enable the **Priced Tables** pack, then create the table: in the FileSystem dock, create a new
**Resource**, pick **PriceTableResource**, fill it in, and save it as (for example)
`res://shops/blacksmith.tres`.

| Field | Example |
|-------|---------|
| Table Name | `Blacksmith` |
| Default Currency | `gold` |
| Entries | `potion` / Small Potion / 10 / (blank) / 2 / unticked / (blank) |
| | `sword` / Iron Sword / 50 / (blank) / -1 / unticked / (blank) |
| | `relic` / Old Relic / 200 / (blank) / 1 / **ticked** / `needs the guild badge` |

Now add a child node to your vendor, attach **PricedTableBehavior**, and drag the `.tres` onto its
**Price Table** slot. It loads on ready. From any sheet:

```
On buy button pressed
  -> Vendor: Buy Entry  "potion"

On Purchased
  -> give the player the item for Priced Table.Last Purchased Id()
  -> play a coin sound

On Purchase Refused
  -> show Priced Table.Refused Reason()
```

**Pairing with Interaction.** The two packs are meant for each other and share no code at all. Put the
**Interaction** behavior on the player, put a Priced Table on each vendor, and the shop opens when the
focused node is a vendor - the vendor's `interact()` shows your shop UI, which drives Buy Entry. Neither
pack references the other, so either one can be removed without touching the other.

## The wallet seam

A purchase asks for money from the first of these that answers:

1. **The node given to Use Wallet Node** - the direct way when the purse is already in hand.
2. **A node in the Wallet Group** (`wallet` by default) - the loose way, for a purse that exists
   somewhere in the scene.
3. **The `CurrencyLedger` autoload**, if the Currency Ledger pack is installed and registered.
4. **The Local Wallet number** on this behavior, when nothing else answered.

The whole contract is two functions:

```gdscript
func balance(currency: String) -> float
func spend(currency: String, amount: float) -> void
```

The shipped **Currency Ledger** has exactly that pair, which is why it works with no adapter and no
dependency. So does any purse you write yourself. A candidate node missing either function is skipped
rather than called blindly, so a wrong drag can never silently swallow the money.

The **Local Wallet** fallback is one number for every currency - this table's own money. That is enough
for a prototype or a single-shop game; install a shared wallet the moment you have two tables, because
two tables with two local numbers are two separate purses.

## ACE reference

On the canvas these verbs read as styled sentences - parameter values in **bold**, exactly as the rows
draw them:

- Load price table **blacksmith.tres**
- Buy **potion**
- Restock **potion** by **3**
- Set price of **sword** to **35**

### Actions

| Action | Parameters | Description |
|--------|-----------|-------------|
| Load Price Table | table (a Price Table resource) | Stocks the table from a `.tres` in one step. Entries sharing an id with a stocked one are REPLACED (so a second load re-prices), new ids are appended. |
| Add Entry | entry_id, label, price, currency, stock | Adds or replaces one entry from a sheet, for a table built at runtime. Starts unlocked, with no requirement note. |
| Clear Table | (none) | Empties the table. Use it before loading a different table when you do NOT want the two merged by id. |
| Buy Entry | entry_id | The whole purchase: checks the id, the lock, the stock and the wallet, then takes the price, counts the stock down, and fires On Purchased - or On Purchase Refused with the reason. |
| Restock Entry | entry_id, amount | Adds to one entry's remaining stock. An unlimited entry is left alone; stock never falls below 0. |
| Restock All | (none) | Puts every entry back to the stock its table shipped with. Prices, locks and notes are untouched. |
| Set Stock | entry_id, stock | Forces an exact remaining stock. -1 makes it unlimited, 0 sells it out. |
| Set Price | entry_id, price | Re-prices an entry live (a sale, a haggle, a reputation discount). Negatives clamp to 0. |
| Set Entry Unlocked | entry_id, unlocked | Opens or closes an entry. A locked entry still shows, with its price and note. |
| Use Wallet Node | node | Points this table at ONE wallet node, tried before any search. Pass nothing to go back to searching. |
| Set Local Wallet | amount | Sets the fallback purse - the number used only when nothing else answers. |

### Conditions

| Condition | Parameters | Description |
|-----------|-----------|-------------|
| Can Afford Entry | entry_id | Whether the wallet covers this entry's price right now. Reads through the same seam the purchase uses. |
| Entry In Stock | entry_id | Whether the entry has something left. Unlimited is always in stock; an unknown id never is. |
| Entry Is Unlocked | entry_id | Whether the entry is open for business. |
| Has Entry | entry_id | Whether the table holds this id at all - the guard that tells a typo apart from a sold-out row. |
| Table Is Sold Out | (none) | Whether nothing can be bought any more: every entry is at 0 stock or locked. An empty table counts as sold out. |

### Expressions

| Expression | Returns | Description |
|-----------|---------|-------------|
| Price Of | number | What an entry costs (-1 for an unknown id, so a missing price never reads as free). |
| Stock Of | number | How many are left: -1 unlimited, 0 sold out (also what an unknown id reads). |
| Currency Of | String | The currency id the entry is priced in. |
| Label Of | String | The player-facing name of the entry. |
| Requirement Of | String | The plain-language requirement note written on the entry. |
| Entry Count | number | How many entries the table holds. |
| Entry Id At | String | The entry id at a position, in table order ("" out of range). |
| Table Name | String | The readable name written on the loaded resource. |
| Wallet Balance | number | What the buyer can spend of one currency, read through the wallet seam. |
| Last Purchased Id | String | The entry bought most recently. |
| Last Price Paid | number | What the last purchase cost. |
| Last Currency Paid | String | The currency the last purchase was paid in. |
| Refused Entry Id | String | The entry of the most recent refusal. |
| Refused Reason | String | Why it was refused: "unknown entry", "locked", "out of stock" or "too expensive". |

### Triggers

| Trigger | Fires with | Description |
|---------|-----------|-------------|
| On Purchased | entry_id, price | A purchase went through. Hand over the goods here. |
| On Purchase Refused | entry_id, reason | A purchase did not happen, and why. Show the reason, shake the button, play a buzz. |

### Knobs (Inspector)

| Property | Default | Description |
|----------|---------|-------------|
| Price Table | (empty) | Optional: a PriceTableResource loaded on ready. |
| Wallet Group | `wallet` | The group searched for a wallet node before the CurrencyLedger autoload. |
| Local Wallet | `0.0` | The fallback purse, used only when nothing else answers. |

## The Price Table resource

| Property | Default | Description |
|----------|---------|-------------|
| Table Name | "shop" | A readable name for the table, read back with Table Name. |
| Default Currency | "gold" | Used by any entry that leaves its own currency cell blank. |
| Entries | empty | One row per thing that can be bought (below). |

| Column | Meaning |
|--------|---------|
| `id` | The string every action, condition and expression addresses. Short and unique. |
| `label` | What the player reads. |
| `price` | What it costs, in `currency`. |
| `currency` | Blank inherits the table's Default Currency. |
| `stock` | How many are left. **-1 is unlimited**, 0 is sold out. |
| `locked` | TICK to start it closed. A fresh row is unticked, so it sells straight away. |
| `requires` | A plain-language note about the condition YOUR game checks. The pack never interprets it. |

A row with a **blank id is skipped** when the table loads - it cannot be addressed, so stocking it
would only hide a typo.

## Use cases

**1. A vendor with one item.**

```
On buy button pressed
  -> Vendor: Buy Entry  "potion"
```

**2. Grey out what the player cannot afford.**

```
Every tick
  Condition: Vendor  Can Afford Entry  "sword"
    -> set BuyButton disabled = false
  Else
    -> set BuyButton disabled = true
```

**3. Explain a refusal instead of doing nothing.**

```
On Purchase Refused
  -> show reason on the shop panel
```

The reason is already plain words: `too expensive`, `out of stock`, `locked`, `unknown entry`.

**4. Hand over the goods.**

```
On Purchased
  Condition: entry_id = "potion"
    -> add 1 to Inventory Potions
    -> play a drinking sound
```

**5. Build the shop UI from the table.**

```
On shop opened
  Repeat Vendor.Entry Count() times
    -> add a row labelled Vendor.Label Of(Vendor.Entry Id At(loopindex))
       + " - " + str(Vendor.Price Of(Vendor.Entry Id At(loopindex)))
```

**6. Show what is left.**

```
Every tick
  Condition: Vendor  Entry In Stock  "relic"
    -> set StockLabel text = str(Vendor.Stock Of("relic")) + " left"
  Else
    -> set StockLabel text = "Sold out"
```

An unlimited entry reads -1, so hide the number when Stock Of is below 0.

**7. A skill tree node that unlocks the next one.**

```
On Purchased
  Condition: entry_id = "tier1"
    -> Kiosk: Set Entry Unlocked  "tier2", true
```

**8. A requirement your game owns.**

```
On guild badge collected
  -> Vendor: Set Entry Unlocked  "relic", true
```

Until then the row shows its **Requirement Of** note in the tooltip, so the player knows why it is shut.

**9. A toll gate.**

```
On player touches gate
  -> Gate: Buy Entry  "toll"

On Purchased
  -> open the gate
```

Stock -1, price 5, and the refusal already says "too expensive" when the purse is short.

**10. The morning restock.**

```
On new day
  -> Vendor: Restock All
```

**11. A delivery that adds only a few.**

```
On caravan arrives
  -> Vendor: Restock Entry  "potion", 3
```

**12. A sale.**

```
On festival starts
  -> Vendor: Set Price  "sword", 35
On festival ends
  -> Vendor: Set Price  "sword", 50
```

**13. A one-of-a-kind item.** Give the entry stock 1. It sells once, and every later attempt is refused
with "out of stock" - no flag of your own required.

**14. Close the shop when there is nothing left.**

```
On Purchased
  Condition: Vendor  Table Is Sold Out
    -> show "Come back tomorrow"
    -> close the shop panel
```

**15. Spend a currency that is not money.**

Give the entry `currency` = `reputation` and let your wallet answer for it. The table just asks for a
balance in that name; what reputation means is your game's business.

**16. A shop with no economy pack at all.**

```
On Start of Layout
  -> Vendor: Set Local Wallet  100
```

The table now spends from its own number, and every condition and expression above still works. Swap in
a real wallet later without touching a single row.

**17. Point the table at a purse you already have.**

```
On player spawned
  -> Vendor: Use Wallet Node  PlayerWallet
```

The wallet only has to answer `balance(currency)` and `spend(currency, amount)`.

### Other use cases

**Repair station.** Price a `repair` entry per use with unlimited stock, and let On Purchased restore the player's durability - the refusal reason doubles as the "you cannot afford repairs" message.

**Fast-travel network.** One entry per destination, each locked until the player has visited it once, with the fare as the price and the destination name as the label - the whole map screen is one table.

**Bribe menu in a dialogue.** Price the persuasion options in reputation instead of coin, so Can Afford Entry greys out the lines the player has not earned yet.

**Ammo vending machine.** A handful of unlimited entries restocked never, priced per magazine, driven from the same interact key the doors use.

**Level select with unlock walls.** An entry per stage priced in stars, its requirement note explaining the gate, and Set Entry Unlocked opening the next stage the moment one is completed.

## Tips and common mistakes

- **Address entries by id, not by label.** The label is for the player; the id is what every row takes.
  Changing a label later is free, changing an id is not.
- **A blank id row is skipped.** If an entry never appears, check its id cell first.
- **-1 is unlimited, 0 is sold out.** Leaving stock at 0 in the grid ships a shop that refuses
  everything - a very quiet bug.
- **Locked entries are still there.** That is the point: show them greyed out with their requirement
  note. If you never want them seen, do not put them in the table.
- **Buy Entry does not give the item.** It moves the money and fires the trigger. Handing over the
  goods is your event.
- **The local wallet is currency-blind.** It is one number, so a "gems" price and a "gold" price both
  come out of it. Install a real wallet as soon as your game has two currencies.
- **A wallet node needs both functions.** `balance` alone is not enough - the seam skips it and falls
  through to the next candidate rather than spending nothing.
- **Loading a second table merges by id.** That is how a re-price works. Call Clear Table first if you
  want a genuine swap.
- **Restock All uses the shipped counts**, not the current ones, so it is a reset rather than a top-up.
