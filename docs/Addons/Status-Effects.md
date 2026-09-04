# Status Effects - Burn, Poison, Slow and Shield as Files You Own

Status Effects is a Godot EventSheets behavior pack that gives any node the thing every game past its first week needs: a named condition that lasts a while, does something every so often, and goes away by itself. You attach a `StatusEffectsBehavior` under a node - an enemy, the player, a barrel, a boss - and that node can be burned, poisoned, slowed, stunned, frozen or shielded. The pack ships the machinery; the effects themselves are **StatusEffectResource** files your game owns, and six starters ship beside the pack to edit or delete. There is no list of statuses anywhere in this plugin. Every clock in it is game time, so a paused tree stops it and a slowed one slows it, and its tint obeys the same accessibility dials the screen effects do.

---

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [The effect file](#the-effect-file)
6. [Use cases](#use-cases)
7. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

A poison written by hand is a timer, a variable, an Every row dealing damage, a tint set on the sprite, and a tint nobody remembers to take off when the timer runs out - and then all of it again for burn, because none of it was reusable. This pack is the other shape of that: one row puts a status on, one file says what the status does, and everything else - the ticking, the stacking, the tint going back on and coming back off, the multiplier while it lasts - happens because the file says so.

It is at its best when:

- **Several effects have to coexist on one actor.** Burn and slow at the same time is two entries and one product, not two hand-written timers arguing over the sprite's colour.
- **Damage over time should behave like damage.** A tick goes through the Health pack's typed pipeline, so resistances, armour, the damage report and kill credit all apply exactly as they do to a hit from a bullet.
- **The designer, not the programmer, decides what poison is.** Tick amount, kind, interval, tint, icon, stacking rule and cleansability are fields on a file. Changing poison is editing `poison.tres`.
- **Movement should stay out of it.** Stun and freeze move nothing themselves. They are words the movement packs and the state machine ASK about, which keeps this pack out of every controller's business.

It is the wrong tool when a condition is permanent (that is a property, or a group), or when the only thing you need is a timed multiplier with no ticking, no tint and no name to ask about - the Boosts pack is that on its own, and this pack uses it underneath.

---

## Core concepts

**A status is a word, a clock, and - if there is a file for it - an effect.** `Apply Status "burn" for 3 s` puts the word `burn` on the node for three seconds. If `burn.tres` exists, the file says what burn does; if nothing answers to the word, the status is still on, still asks true to Has Status, and still expires on time. That is what makes a pure flag - `stunned`, `marked`, `revealed` - cost no authoring at all.

**An effect answers to what it calls itself.** A file's name is its Status Name when that field is filled in, and its file name when it is not - so `burn.tres` is "burn" with nothing typed anywhere, and renaming the file renames the effect. Both doors use that same answer: the folder is searched by the name each file says, and so is the list of effects dropped straight onto the node.

**Effect files are found in two places, and the node's own list wins.** The behavior looks first at the **Effects** array in its Inspector, then in the **Effects Folder**. That is how one enemy carries its own harsher version of `burn` without the folder or any other enemy knowing about it.

**Ticks are ordinary typed damage.** A tick with a Tick Amount calls the Health behavior's Take Damage Of Type with the file's Tick Type, on the host itself if it has one or on the first child that does. Everything that applies to a hit applies to a tick: resistance, immunity, armour, the minimum, the crit roll, the pools, On Damaged, and the kill credit.

**Stacking is a rule on the file, not on the row.** A second application asks the file what to do: *refresh* puts the clock back to the new time, *extend* adds the new time to what was left, *add* refreshes the clock and piles stacks up to Max Stacks. Ticks and healing are multiplied by the stack count, so five stacks of a bleed bleed five times as fast.

**Cleanse asks the file; Remove Status does not.** A Cleanse with no name takes off everything whose file says it may be cleansed, which is what makes an antidote one row - and a curse is a file that says it may not. A Cleanse that NAMES a status asks the same question, so naming the curse does not get around it. Remove Status is the row that takes something off regardless: the boss shrugs it off, the scene moved on, the shield was spent.

**Immunity refuses the next one and takes off the current one.** An immunity you have to wait out is not one, so Immune To Status ends the status it names as well as refusing it for the seconds you give it.

**The tint is mixed, not set.** Every active effect's tint is multiplied together and applied to the host's modulate; the host's own colour is remembered when the first one goes on and put back when the last one comes off. A host that is not a CanvasItem - a 3D enemy, a plain Node - is simply left alone and its statuses work exactly the same. While a player has asked for no flashing, the shift is held under the same ceiling the screen effects use.

**Speed Factor is a product you multiply by.** It is the product of every active effect's speed factor: 1 with nothing on, 0.5 under one slow, 0 under a root. The movement pack multiplies its speed by it, which is how one file turns every kind of movement in the game slow.

**Multipliers run through the Boosts pack.** An effect with a Multiplier Tag starts a tagged boost while it lasts and stops it when it ends, and Extend Status extends both clocks together. Boosts stays the multiplier engine; a project without it simply gets no multiplier, which is the honest answer rather than an error.

**Kill credit belongs to the NODE.** A tick's damage is credited to whoever Claimed the Status Effects node, through the project's one ownership key - so `Claim` the status node for the poisoner and a kill by the poison is scored to them exactly as a bullet's would be. Every status on that node credits the same claimer: there is no per-application source, so a game where two players poison the same enemy and each wants their own credit claims the node again as it applies.

---

## Setup

1. Add a child node under the actor and attach the **StatusEffectsBehavior** behavior to it. The host is its parent; anything can be a host.
2. Leave **Effects Folder** pointing at the shipped starters while you try it, then point it at your own folder once you have copied and edited them. An effect is a file in that folder, so adding one is dropping a file in.
3. Optional: drag one or more effect files into the **Effects** array to give this one actor its own versions.
4. Optional but usual: put a **Health** behavior on the same actor (or on its parent) so ticks with damage in them have somewhere to land.
5. While building, turn **Debug Mode** on: it warns about a status applied under a name no file answers to, and about a tick with damage in it on an actor with no Health behavior to take it. Turn it off for release.

---

## ACE reference

Every row lives in the **Status Effects** category and acts on the behavior of the node it is placed on.

### Actions

| Action | Parameters | Description |
|--------|-----------|-------------|
| Apply Status | `status` (String), `seconds` (float), `stacks` (int) | Puts a status on this node for a time, stacking by the rule in its own file. The name is a StatusEffectResource in the effects folder, so "burn" is burn.tres; a name no file answers to still applies as a name and a clock, which is all a pure flag like "stunned" needs. |
| Extend Status | `status` (String), `seconds` (float) | Adds seconds to a status that is already on, leaving its stacks alone, and extends the multiplier it started by the same seconds. Nothing happens if it is not on - extending is for a fire being fed, not for lighting one. |
| Remove Status | `status` (String) | Takes one status off now, whatever its file says about being cleansable. On Status Expired still fires, so the row that cleans up after a status is the same row either way. |
| Cleanse | `status` (String) | Takes a status off if its file says it may be cleansed, or - given no name at all - every status whose file says so. That is what makes an antidote one row, and what makes a curse survive it however it is named. |
| Immune To Status | `status` (String), `seconds` (float) | Stops a status from landing here for a while, and takes it off if it is already on. The i-frames of the status world: the potion that makes you proof against poison for ten seconds. |

### Conditions

| Condition | Parameters | Description |
|-----------|-----------|-------------|
| Has Status | `status` (String) | True while that status is on. This is the row a movement pack or a state machine asks before it moves anything, which is why stun and freeze need no code of their own. |

### Expressions

| Expression | Parameters | Returns | Description |
|------------|-----------|---------|-------------|
| Status Stacks | `status` (String) | int | How many stacks of a status are on, and 0 when it is not. Ticks and healing are multiplied by it, so it is also how hard the effect is hitting. |
| Status Time Left | `status` (String) | float | Seconds left before a status ends, and 0 when it is not on - the fill of the little bar under its icon. |
| Status Icon | `status` (String) | Texture2D | The picture the effect's own file names for it, straight into a HUD texture. A status with no icon, or one that is not on, answers with nothing. |
| Active Statuses | (none) | Array | Every status on this node right now, in name order - the list a status bar walks to draw one icon per effect. |
| Speed Factor | (none) | float | The product of every active effect's speed factor: 1 when nothing is on, 0.5 under one slow, 0.25 under two. Multiply your movement speed by it and every slow, root and haste in the game already works. |

### Triggers

| Trigger | Arguments | Fires when |
|---------|-----------|-----------|
| On Status Applied | `status`, `stacks` | A status lands, including the second and later times it is applied. |
| On Status Ticked | `status`, `stacks` | Every tick of an active status, after its damage and healing have been dealt. |
| On Status Expired | `status` | A status ends, however it ended - the clock ran out, it was removed, it was cleansed, or an immunity pushed it off. |
| On Stacks Changed | `status`, `stacks` | An active status changes how many stacks it is on, and not when it lands at the count it was already on. |

### Inspector properties

| Property | Type | Default | Notes |
|----------|------|---------|-------|
| `effects_folder` | Dir | `res://eventsheet_addons/status_effects` | Where the effect files live. Point it at your own folder once you have copied the starters. |
| `effects` | Array | `[]` | Effect files dropped straight onto this node, looked in BEFORE the folder. |
| `debug_mode` | bool | `false` | Warns about a status no file answers to, and about a tick with damage on an actor with no Health behavior. |

---

## The effect file

A **StatusEffectResource** is one status as a file. A field left at its default does nothing at all, so a pure flag is a file with nothing in it but a name.

| Field | Type | What it does |
|-------|------|--------------|
| `status_name` | String | The word rows call this effect by. Leave it blank and the file's own name is the word, so renaming the file renames the effect. |
| `tint` | Color | The colour the host is tinted while this is on. White is no tint. |
| `icon` | Texture2D | The picture that stands for this effect, handed straight to a HUD texture by Status Icon. |
| `tick_amount` | float | Damage dealt on every tick, per stack, through the Health pack's typed pipeline. |
| `tick_type` | String | What kind of damage a tick is - "fire", "poison", whatever this game's damage type set calls it. Blank is untyped. |
| `tick_seconds` | float | How long between ticks, in seconds of game time. |
| `heal_amount` | float | Health restored on every tick, per stack - a regeneration, a bandage, a healing circle. |
| `speed_factor` | float | What this multiplies movement speed by: 0.5 a slow, 0 a root, 1.4 a haste. |
| `multiplier_tag` | String | The Boosts tag this effect feeds while it is on. Blank feeds none. |
| `multiplier` | float | What it multiplies that tag by. |
| `stacking` | String | `refresh`, `extend` or `add`, chosen from a dropdown. |
| `max_stacks` | int | The most stacks this effect can reach. |
| `cleansable` | bool | Whether a Cleanse takes this one off. Turn it off for a curse. |
| `particle_scene` | PackedScene | A scene added under the host while this is on and freed when it ends. |

The six starters are `burn` (2 fire twice a second, orange, refresh), `poison` (piles up to five stacks, add), `slow` (halves speed), `stun` (a flag with a tint), `freeze` (a root, extend) and `shield` (a defence multiplier, and not cleansable). They are examples, not a list: edit them, rename them, delete them.

---

## Use cases

### 1. Setting an enemy on fire

The whole pack in one row. The file says what burn is; the row says who and how long.

```
On Fireball Hits Enemy
  -> Enemy | Status Effects: Apply Status  "burn", 3, 1
  -> Fireball: queue_free
```

### 2. A stun that actually stops the enemy

Stun moves nothing by itself. The controller asks before it moves, which is one condition rather than a flag threaded through every movement row.

```
On Enemy: Every Frame
  Condition: Enemy | Status Effects  Has Status  "stun"
    -> (nothing: the enemy stands still)

On Enemy: Every Frame
  Condition: NOT Enemy | Status Effects  Has Status  "stun"
    -> Enemy | Platformer Movement: Move  Enemy.direction
```

### 3. A slow that every kind of movement respects

Speed Factor is a product, so a slow and a chill together are one number and the movement row never learns what caused it.

```
On Player: Every Frame
  -> Player | Platformer Movement: Set Speed  200 * Player.Status Effects.Speed Factor
```

### 4. An antidote that leaves the curse

One row for the potion. Poison's file says it may be cleansed and the curse's file says it may not, so the antidote cannot take the curse off however it is written.

```
On Player Drinks Antidote
  -> Player | Status Effects: Cleanse  ""
  -> Player: play  "drink"
```

### 5. A status bar that draws itself

Active Statuses is the list, Status Icon is the picture and Status Time Left is the little bar under it.

```
On HUD: Every Frame
  -> for each status in Player.Status Effects.Active Statuses
       -> set icon.texture  Player.Status Effects.Status Icon  status
       -> set icon.bar.value  Player.Status Effects.Status Time Left  status
```

### 6. Poison that gets worse the more darts hit

Poison's file stacks by *add* up to five, so the row is the same row every time and the file decides what the fifth dart means.

```
On Dart Hits Enemy
  -> Enemy | Status Effects: Apply Status  "poison", 6, 1

On Enemy | Status Effects: On Stacks Changed
  -> Enemy: play  "retch"
```

### 7. A burn that a second fireball feeds

Extend Status adds to what is left rather than starting again, which is the difference between a fire being fed and a fire being lit.

```
On Fireball Hits Enemy
  Condition: Enemy | Status Effects  Has Status  "burn"
    -> Enemy | Status Effects: Extend Status  "burn", 2

On Fireball Hits Enemy
  Condition: NOT Enemy | Status Effects  Has Status  "burn"
    -> Enemy | Status Effects: Apply Status  "burn", 3, 1
```

### 8. A shield potion that also softens the next hit

The shield file carries a `defence` multiplier tag, so the Boosts pack does the softening and this pack does the clock, the tint and the icon.

```
On Player Drinks Shield Potion
  -> Player | Status Effects: Apply Status  "shield", 8, 1

On Player Drinks Second Potion
  -> Player | Status Effects: Extend Status  "shield", 5
```

### 9. Fire that an ice enemy shrugs off

Nothing here says so. The tick is typed damage, so the enemy's own Resist row already answers it.

```
On Ice Enemy: On Ready
  -> Ice Enemy | Health: Resist  "fire", 75

On Fireball Hits Ice Enemy
  -> Ice Enemy | Status Effects: Apply Status  "burn", 3, 1
```

### 10. Kill credit for a poison

Claim the status node for whoever applied it and the kill scores to them, through the same ownership key a bullet uses.

```
On Dart Hits Enemy
  -> Ownership: Claim  Enemy.StatusEffects, Dart
  -> Enemy | Status Effects: Apply Status  "poison", 6, 1

On Enemy | Health: On Death
  -> add score to  Enemy.Health.Killer Of
```

### 11. A regeneration circle

Heal Amount is the same machinery pointing the other way, so a healing aura is a file rather than a second system.

```
On Player Enters Circle
  -> Player | Status Effects: Apply Status  "regen", 5, 1

On Player Leaves Circle
  -> Player | Status Effects: Remove Status  "regen"
```

### 12. A boss that cannot be frozen twice

Immune To Status takes it off and keeps it off, which is the whole of a boss's resistance phase.

```
On Boss | Status Effects: On Status Expired
  Condition: it was  "freeze"
    -> Boss | Status Effects: Immune To Status  "freeze", 10
    -> Boss: play  "shake it off"
```

### 13. Reacting to the tick rather than the status

On Status Ticked fires after each tick's damage and healing, which is where the drip, the flash and the number belong.

```
On Enemy | Status Effects: On Status Ticked
  -> HUD | HUD Kit: Pop Floating Text As  Enemy.Health.Last Damage Dealt, Enemy.Health.Last Damage Type, Enemy.global_position
```

### 14. A state machine that reads the status

Has Status is a condition, so a transition can be written in the language the rest of the sheet is written in.

```
On Enemy: Every Frame
  Condition: Enemy | Status Effects  Has Status  "stun"
    -> Enemy | State Machine: Go To State  "stunned"
```

### 15. One enemy with its own harsher burn

Drop a copy of burn.tres into this enemy's Effects array and edit it. The row does not change; the folder does not change; only this enemy burns hotter.

```
On Fireball Hits Elite
  -> Elite | Status Effects: Apply Status  "burn", 3, 1
```

### 16. A status that is nothing but a word

`marked` has no file at all. It applies, it expires, and Has Status answers - which is all a marked-for-death mechanic ever needed.

```
On Enemy Painted
  -> Enemy | Status Effects: Apply Status  "marked", 5, 1

On Bullet Hits Enemy
  Condition: Enemy | Status Effects  Has Status  "marked"
    -> Enemy | Health: Take Damage Of Type  20, "physical", Bullet
```

### 17. Cleansing everything on death so nothing outlives the actor

The tint comes off by itself when the last status ends, and On Status Expired is where anything else you hung on a status is undone.

```
On Enemy | Health: On Death
  -> Enemy | Status Effects: Cleanse  ""
  -> Enemy | Status Effects: Remove Status  "shield"
```

### Other use cases

**A wet status that makes lightning hurt more.** Applying `wet` costs one row, and the lightning spell reads Has Status before choosing which kind of damage to deal - an elemental combo without a combo system.

**Buffs that read exactly like debuffs.** A haste is an effect file with a speed factor above 1 and a friendly tint; nothing in the pack knows the difference, so the rows, the icons and the bar are the ones you already wrote.

**A bleed that only ticks while the actor moves.** Apply the status on the hit and Remove Status while the actor is still, using the same Has Status condition the movement rows already ask.

**Difficulty as a folder.** Point Effects Folder at `res://statuses/hard` on the harder setting: every status in the game becomes its harsher version without a single row changing.

**Environmental hazards without hazard code.** A lava area applies `burn` on entry and lets it expire on exit, so the hazard is one row and the burning is the file everything else already uses.

---

## Tips and common mistakes

- **A name no file answers to is not an error.** It applies as a name and a clock. That is a feature - pure flags cost nothing - but it also means a typo silently becomes a status nothing ticks. Turn Debug Mode on while you build and it will say so.
- **The status is a String in the row, so it needs its quotes.** `Apply Status "burn"` - the field takes an expression, so a bare `burn` reads as a variable name.
- **Stun and freeze do not stop anything by themselves.** They are words. Something has to ASK - the movement row, the state machine, the input gate. That is what keeps one status meaning whatever a given game wants it to mean.
- **A tick needs somewhere for its damage to land.** Ticks call the Health behavior on the host or on the first child that has one. An actor with no Health behavior takes no tick damage, silently unless Debug Mode is on.
- **Cleanse is not Remove Status.** Cleanse asks the file whether it may be taken off, named or not. Remove Status does not ask. If your antidote refuses to take something off, that file says `cleansable` is off.
- **Extend does nothing to a status that is not on.** It is for feeding a fire, not lighting one. Apply Status is what lights it, and an effect whose file stacks by *extend* already adds to what was left when it is applied again.
- **Stacks multiply the tick, not the clock.** Five stacks of a bleed tick five times as hard for the same seconds. If you wanted longer instead, that is the `extend` rule on the file.
- **The tint is the product of everything on.** Two effects with tints multiply, so a pale tint on a status you expect to be dramatic usually means something else is on at the same time. Remove them both and the host's own colour comes straight back.
- **Point Effects Folder at your own folder before you edit the starters.** The starters live inside the pack, which means a plugin update overwrites them. Copy them out first; the whole point is that the effects belong to your game.
- **One status, one clock, on the node.** Kill credit for a tick goes to whoever claimed the Status Effects node, not to whoever applied that particular status. If two attackers must be credited separately, claim the node again as each applies theirs.
