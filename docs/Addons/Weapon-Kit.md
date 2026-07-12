# Weapon Kit - Ammo, Fire Rate, and Reloads on Any Node

Weapon Kit is a Godot EventSheets behavior pack that turns any Node2D into a gun. You attach a `WeaponKit` behavior to a node - the player, an enemy, a turret, a spawned pickup - and that node becomes the weapon. It owns the boring-but-fiddly parts of shooting: a magazine and a reserve pool, a fire-rate cooldown so shots pace themselves, single / auto / burst fire modes, and timed or instant reloads with optional auto-reload when the mag runs dry. What it deliberately does NOT own is the projectile. Calling **Fire** spends a round, starts the cooldown, and fires the **On Fire** trigger - and inside that trigger you spawn the bullet, cast the hitscan, or play the swing however your game likes. Every Action, Condition, Expression, and Trigger targets the `WeaponKit` living on the node you drop it on. There is no "weapon id" to pass around: the node is the weapon.

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

- **Top-down and twin-stick shooters.** Hold the trigger, Weapon Kit paces the shots at your fire rate, and you just spawn a bullet on On Fire. No manual cooldown timer to hand-roll.
- **Platformer guns.** A run-and-gun character gets a magazine, a reload, and an out-of-ammo click for free, so the shooting feels like a real weapon and not an infinite pea-shooter.
- **Reload-driven tension.** Timed reloads, a reserve pool that can run out, and the On Reload Started / On Reload Complete pair give you the whole "reload under pressure" loop with a progress bar.
- **Weapon pickups and swaps.** Set Magazine Size, Set Fire Rate, Set Fire Mode, and Set Burst Count reconfigure the same behavior into a pistol, an SMG, or a shotgun the moment the player grabs a new gun.
- **Ammo and mag pickups.** Add Reserve Ammo tops up spare rounds from a crate; Add Ammo drops rounds straight into the magazine; Instant Reload is a "full mag" powerup.
- **Enemy shooters.** Give a turret or a soldier a WeaponKit, call Fire on its own timer, and it obeys the same cooldown and ammo rules the player does, so enemies pause to reload too.
- **Burst-fire weapons.** Fire mode 2 kicks off a burst of Burst Count rounds from a single Fire call, each still paced by the cooldown - a three-round-burst rifle with no extra plumbing.
- **Auto vs semi-auto.** Flip Fire Mode at runtime so a weapon can toggle between tapping one shot per click and holding for continuous fire.
- **HUD and feedback.** Read Current Ammo, Max Ammo, Reserve Ammo, Ammo Percent, Reload Progress, and Cooldown Progress live for an ammo counter, a low-ammo blink, a reload sweep, and a fire-ready reticle.
- **Rate-of-fire powerups.** Set Fire Rate up for a rapid-fire pickup and drop it back on a timer, without touching how you spawn bullets.
- **Bosses with gated volleys.** Drive a boss cannon with Fire on a schedule, let it run dry, and use On Empty to force a scripted reload beat between volleys.
- **Infinite-ammo cheats and sandbox modes.** Set Infinite Reserve so reloads never spend spare rounds - handy for a practice range or a debug toggle.

---

## Core concepts

The mental model is small. Learn these ideas and the rest of the pack is just knobs.

**The node is the weapon.** You attach `WeaponKit` to a Node2D, and every ACE acts on the WeaponKit of the node it is placed on. There is no weapon-id argument anywhere. One behavior, one weapon; a player holding two guns is two WeaponKit nodes.

**Two ammo pools: the magazine and the reserve.** `current_ammo` is what is loaded right now, capped at `max_ammo` (the magazine size). `reserve_ammo` is the spare rounds a reload draws from. Firing spends the magazine; reloading moves rounds from the reserve into the magazine. When the reserve hits zero, a reload has nothing to pull from - unless `infinite_reserve` is on, in which case reloads are free and the reserve is never touched.

**Fire manages ammo and cooldown - you spawn the projectile.** Calling **Fire** checks that the weapon is ready (not reloading, off cooldown, has ammo), spends one round, starts the cooldown, and fires **On Fire**. It does not create a bullet. That is on purpose: you react to On Fire and spawn whatever your game shoots. If the magazine is empty when you call Fire, it fires **On Empty** instead (and, when `auto_reload` is on, kicks off a reload for you).

**The cooldown paces your shots.** After each round the weapon rests for `1 / fire_rate` seconds. During that rest, Fire does nothing. This is why you can safely call Fire every single frame the trigger is held: the cooldown throttles it to the fire rate. A higher `fire_rate` means a shorter rest and a faster gun.

**Three fire modes.** `fire_mode` is 0 (single), 1 (auto), or 2 (burst). Modes 0 and 1 both fire exactly one round per Fire call, paced by the cooldown - the difference is how YOU drive it: single means you call Fire once per click, auto means you call Fire every frame the trigger is held and let the cooldown set the rhythm. Mode 2 (burst) is special: one Fire call kicks off a burst of `burst_count` rounds, fired one at a time as the cooldown allows, and Weapon Kit walks the burst out for you frame by frame.

**Reloads are timed by default.** **Reload** starts a reload that takes `reload_time` seconds; **On Reload Started** fires immediately and **On Reload Complete** fires when it finishes and the rounds move across. During the reload the weapon cannot fire. **Cancel Reload** aborts it with no rounds gained; **Instant Reload** skips the timer and refills the magazine right now. **Auto Reload** (the `auto_reload` knob) starts a reload automatically the moment the magazine runs dry.

**Read the live values for your HUD.** The magazine and reserve counts, plus `Ammo Percent`, `Reload Progress` (0 to 1 while reloading, 1 when not), and `Cooldown Progress` (0 to 1 as the shot cooldown recovers), are all readable expressions. Wire them to a label, a bar, or a reticle. `Can Fire`, `Has Ammo`, `Is Full`, and `Is Reloading` are the matching yes/no conditions.

**Every exported knob is also readable and settable at runtime.** Because the pack exposes its whole surface, each Inspector property (magazine size, fire rate, reload time, and the rest) comes with an expression to read it and Set / Add To / Subtract From actions to change it live - that is how a pickup or a powerup retunes the weapon mid-game without you writing any glue.

---

## Setup

**1. Attach the behavior.** Add a `WeaponKit` behavior as a child node of your weapon-holder - a Node2D such as the player, an enemy, or a turret (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node onto the host). The behavior finds its parent Node2D on ready and acts on it; one WeaponKit per weapon.

**2. Set the Inspector knobs.** Select the WeaponKit node and tune the feel: magazine size, fire rate, reload time, fire mode, and the rest. The defaults are a sensible 12-round, 8-shots-per-second weapon to start from.

**3. Wire the loop.** Two moves: call Fire when the player shoots, and react to the triggers to make bullets and effects. Here is a complete first weapon - a semi-auto pistol that spawns a bullet on each shot and reloads on a key:

```
Every tick
  Condition: Keyboard  "fire" is down
    -> Gun | WeaponKit: Fire

Gun On Fire
  -> spawn Bullet at Gun.global_position facing Gun.rotation

Gun On Empty
  -> play "click" sound

Keyboard On "r" pressed
  -> Gun | WeaponKit: Reload

Gun On Reload Complete
  -> play "reload-done" sound
```

Fire is safe to call every frame - the cooldown paces it to your fire rate, and it only fires On Fire when a round actually leaves the barrel. On Empty covers the dry-trigger click, and the reload is a single Reload call plus a trigger to know when it lands.

---

## ACE reference

All ACEs live in the **Weapon** category and target the `WeaponKit` behavior on the node they are placed on. There is no weapon-id parameter anywhere - the node is the weapon.

### Actions

The hand-picked weapon verbs:

| Action | Parameters | Description |
|---|---|---|
| Fire | (none) | Fires if ready (not reloading, off cooldown, has ammo). Spends a round, starts the cooldown, and fires On Fire. In burst mode it kicks off a burst; if the magazine is empty it fires On Empty (and auto-reloads when enabled). |
| Reload | (none) | Starts a timed reload if the magazine is not full and the reserve has rounds. Fires On Reload Started now and On Reload Complete when it finishes. |
| Cancel Reload | (none) | Aborts an in-progress reload. No ammo is gained. |
| Instant Reload | (none) | Refills the magazine immediately, with no reload time. |
| Add Ammo | `amount` (int) | Adds rounds straight into the magazine, capped at the magazine size. |
| Add Reserve Ammo | `amount` (int) | Adds spare rounds to the reserve pool (for example an ammo pickup). |
| Set Fire Rate | `rate` (float) | Changes the shots per second (the cooldown between shots is 1 / rate). |
| Set Fire Mode | `mode` (int) | Sets the fire mode: 0 = single, 1 = auto, 2 = burst. |
| Set Magazine Size | `size` (int) | Changes the magazine size (the cap the magazine reloads and tops up to). |

Because the pack exposes its whole surface, every exported property also gets generic write actions. **Set** works on all of them; **Add To** and **Subtract From** exist for the numeric ones:

| Property | Set action | Add To / Subtract From actions |
|---|---|---|
| `current_ammo` | Set Current Ammo `value` (int) | Add To Current Ammo / Subtract From Current Ammo `amount` (int) |
| `max_ammo` | Set Max Ammo `value` (int) | Add To Max Ammo / Subtract From Max Ammo `amount` (int) |
| `reserve_ammo` | Set Reserve Ammo `value` (int) | Add To Reserve Ammo / Subtract From Reserve Ammo `amount` (int) |
| `fire_rate` | Set Fire Rate `value` (float) | Add To Fire Rate / Subtract From Fire Rate `amount` (float) |
| `reload_time` | Set Reload Time `value` (float) | Add To Reload Time / Subtract From Reload Time `amount` (float) |
| `fire_mode` | Set Fire Mode `value` (int) | Add To Fire Mode / Subtract From Fire Mode `amount` (int) |
| `burst_count` | Set Burst Count `value` (int) | Add To Burst Count / Subtract From Burst Count `amount` (int) |
| `auto_reload` | Set Auto Reload `value` (bool) | (bool - no Add / Subtract) |
| `infinite_reserve` | Set Infinite Reserve `value` (bool) | (bool - no Add / Subtract) |

Two shapes exist for a couple of these: the curated verb (`Set Magazine Size`, which clamps the size at 0) and the raw property setter (`Set Max Ammo`) both write the magazine size, and both `Set Fire Rate` and `Set Fire Mode` appear once as a verb and once as the property setter. Either works; the verbs are the friendlier read.

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Can Fire | (none) | Whether the weapon is ready to fire right now (not reloading, off cooldown, has a round, not mid-burst). |
| Has Ammo | (none) | Whether the magazine has at least one round loaded. |
| Is Full | (none) | Whether the magazine is at its size (nothing to reload). |
| Is Reloading | (none) | Whether a timed reload is currently in progress. |

### Expressions

The weapon readouts:

| Expression | Returns | Description |
|---|---|---|
| Ammo Percent | float | The magazine fill as a percentage, 0 to 100 (current_ammo / max_ammo * 100). |
| Reload Progress | float | Reload completion, 0 to 1 while reloading (1 when not reloading). Wire it to a reload bar. |
| Cooldown Progress | float | Shot-cooldown recovery, 0 right after a shot rising to 1 when ready to fire again. |

Every exported property is also readable by its friendly name:

| Expression | Returns | Description |
|---|---|---|
| Current Ammo | int | Rounds loaded in the magazine right now. |
| Max Ammo | int | The magazine size. |
| Reserve Ammo | int | Spare rounds in the reserve pool. |
| Fire Rate | float | Shots per second. |
| Reload Time | float | Seconds a reload takes. |
| Fire Mode | int | The current fire mode (0 single, 1 auto, 2 burst). |
| Burst Count | int | Rounds fired per burst in mode 2. |
| Auto Reload | bool | Whether the weapon auto-reloads when it runs dry. |
| Infinite Reserve | bool | Whether reloads spend reserve ammo. |

### Triggers

| Trigger | Fires when |
|---|---|
| On Fire | A round leaves the barrel (from a Fire call, or each round of a burst). Spawn your projectile here. |
| On Empty | Fire is called with an empty magazine (the dry-trigger moment); also fires the instant a shot empties the magazine. |
| On Reload Started | A timed reload begins (from Reload). |
| On Reload Complete | A reload finishes and the rounds move from the reserve into the magazine (from a timed reload or Instant Reload). |

### Inspector properties

| Property | Type | Default | What it does |
|---|---|---|---|
| `max_ammo` | int | `12` | Magazine size - rounds the magazine holds before a reload. |
| `current_ammo` | int | `12` | Rounds loaded right now. Set it to the magazine size to start full. |
| `reserve_ammo` | int | `96` | Spare rounds a reload draws from. |
| `fire_rate` | float | `8.0` | Shots per second (the cooldown between shots is 1 / fire_rate). |
| `reload_time` | float | `1.2` | Seconds a reload takes. |
| `fire_mode` | int | `0` | 0 = single, 1 = auto (both cooldown-gated), 2 = burst. |
| `burst_count` | int | `3` | Rounds fired per burst when fire_mode = 2. |
| `auto_reload` | bool | `true` | Reload automatically when the magazine runs dry. |
| `infinite_reserve` | bool | `false` | Reloads never spend reserve ammo. |

---

## Use cases

Each example targets the `WeaponKit` behavior on the named node (here, usually `Gun`). Call Fire in a per-frame loop or on a press; react to the triggers in their own events.

### 1. Hold-to-fire automatic weapon

Call Fire every frame the trigger is held - the cooldown paces it to the fire rate, so you never manage a timer yourself. Spawn the bullet on On Fire.

```
Every tick
  Condition: Keyboard  "fire" is down
    -> Gun | WeaponKit: Fire

Gun On Fire
  -> spawn Bullet at Muzzle.global_position facing Gun.rotation
```

Because Fire is cooldown-gated, holding the key does not empty the mag in one frame - it fires at `fire_rate` shots per second.

### 2. Semi-auto, one shot per click

For a pistol, call Fire on the press event instead of every frame, so each click is exactly one round.

```
Keyboard On "fire" pressed
  -> Gun | WeaponKit: Fire

Gun On Fire
  -> spawn Bullet at Muzzle.global_position facing Gun.rotation
  -> add screen shake 2
```

Same Fire action - the semi-auto feel comes purely from firing on the press, not the hold.

### 3. Live ammo counter on the HUD

Read Current Ammo, Max Ammo, and Reserve Ammo straight into a label. They update the moment a round is spent or a reload lands.

```
Every tick
  -> set AmmoLabel.text to str(Gun | WeaponKit: Current Ammo) + " / " + str(Gun | WeaponKit: Max Ammo)
  -> set ReserveLabel.text to str(Gun | WeaponKit: Reserve Ammo)
```

No event bookkeeping - the counts are the source of truth and you just render them.

### 4. Manual reload with a progress bar

Reload starts the timed reload; Reload Progress sweeps 0 to 1 while it runs. Show the bar only while Is Reloading.

```
Keyboard On "r" pressed
  -> Gun | WeaponKit: Reload

Every tick
  Condition: Gun | WeaponKit  Is Reloading
    -> show ReloadBar
    -> set ReloadBar.value to Gun | WeaponKit: Reload Progress * 100
  Condition: Gun | WeaponKit  [Is Reloading]  is false
    -> hide ReloadBar
```

Reload Progress reads 1 when no reload is running, so the bar naturally sits full between reloads (hidden here anyway).

### 5. Dry-trigger click when out of ammo

Calling Fire on an empty magazine fires On Empty instead of On Fire. Use it for the classic empty-click sound and a prompt to reload.

```
Every tick
  Condition: Keyboard  "fire" is down
    -> Gun | WeaponKit: Fire

Gun On Empty
  -> play "dry-click" sound
  -> flash ReloadPrompt
```

On Empty also fires the instant a shot empties the mag, so the click can double as the "you just ran dry" cue.

### 6. Auto-reload feedback

With `auto_reload` on (the default), an empty magazine starts a reload on its own. React to the trigger pair for animation and sound without calling Reload yourself.

```
Gun On Reload Started
  -> play "reload" animation
  -> play "reload-start" sound

Gun On Reload Complete
  -> play "reload-done" sound
```

On Reload Started fires whether the reload was manual or auto, so this feedback covers both.

### 7. Muzzle flash and recoil

On Fire is the single hook for everything that happens when a round goes off - the projectile, the flash, the kick, the sound.

```
Gun On Fire
  -> spawn Bullet at Muzzle.global_position facing Gun.rotation
  -> flash MuzzleSprite for 0.05 seconds
  -> nudge Player back 4 pixels
  -> play "shot" sound
```

Each round of a burst fires On Fire again, so the flash and kick repeat per shot automatically.

### 8. Ammo pickup tops up the reserve

An ammo crate adds spare rounds with Add Reserve Ammo. The next reload draws from the fuller pool.

```
Player On Area Entered  "AmmoBox"
  -> Gun | WeaponKit: Add Reserve Ammo  30
  -> destroy AmmoBox
  -> play "pickup" sound
```

Add Reserve Ammo feeds the reserve, not the magazine - the player still has to reload to load those rounds.

### 9. A "full mag" powerup

Instant Reload skips the reload timer and refills the magazine right now - perfect for a pickup that rewards a full clip instantly.

```
Player On Area Entered  "FullMagPack"
  -> Gun | WeaponKit: Instant Reload
  -> destroy FullMagPack
  -> flash "MAG FULL" text
```

Instant Reload fires On Reload Complete too, so your reload-done feedback still plays.

### 10. Weapon swap reconfigures the same behavior

Picking up a new gun retunes the one WeaponKit into a different weapon - magazine, rate, mode, and burst - then tops it off.

```
Player On Area Entered  "Shotgun"
  -> Gun | WeaponKit: Set Magazine Size  6
  -> Gun | WeaponKit: Set Fire Rate  2
  -> Gun | WeaponKit: Set Fire Mode  0
  -> Gun | WeaponKit: Set Reserve Ammo  24
  -> Gun | WeaponKit: Instant Reload
  -> destroy Shotgun
```

Set Magazine Size changes the cap; Instant Reload then fills the fresh, larger mag so the swap feels immediate.

### 11. Burst-fire rifle

Set Fire Mode 2 and Set Burst Count 3, then a single Fire kicks off a three-round burst that the pack walks out over the cooldown.

```
On Ready
  -> Rifle | WeaponKit: Set Fire Mode  2
  -> Rifle | WeaponKit: Set Burst Count  3

Keyboard On "fire" pressed
  -> Rifle | WeaponKit: Fire

Rifle On Fire
  -> spawn Bullet at Muzzle.global_position facing Rifle.rotation
```

One press, three On Fire triggers spaced by the cooldown - the burst timing is handled for you.

### 12. Rapid-fire powerup that reverts

Set Fire Rate up for a temporary rapid-fire pickup, and drop it back when a timer expires.

```
Player On Area Entered  "RapidFire"
  -> Gun | WeaponKit: Set Fire Rate  20
  -> start Timer "rapid"  5
  -> destroy RapidFire

On Timer  "rapid"
  -> Gun | WeaponKit: Set Fire Rate  8
```

You never touch how bullets spawn - only the fire rate changes, so the gun just gets faster for five seconds.

### 13. Cancel a reload to shoot now

If the player pulls the trigger mid-reload, cancel it so they can fire the rounds still in the mag (a reload-cancel technique).

```
Keyboard On "fire" pressed
  Condition: Gun | WeaponKit  Is Reloading
    -> Gun | WeaponKit: Cancel Reload
  -> Gun | WeaponKit: Fire
```

Cancel Reload aborts with no rounds gained, so this only helps when the magazine was not empty when the reload started.

### 14. Fire-ready reticle and low-ammo warning

Read Cooldown Progress for a reticle that "charges" between shots, and Ammo Percent for a low-ammo blink.

```
Every tick
  -> set Reticle.charge to Gun | WeaponKit: Cooldown Progress
  Condition: Gun | WeaponKit  Can Fire
    -> tint Reticle white
  Condition: Gun | WeaponKit  [Can Fire]  is false
    -> tint Reticle grey
  Condition: Gun | WeaponKit  Ammo Percent  <  25
    -> blink LowAmmoIcon
```

Cooldown Progress rises 0 to 1 as the shot cooldown recovers, so the reticle fills back up right as the weapon becomes ready.

### 15. Hide the reload prompt when the mag is full

Is Full tells you there is nothing to reload, so you can suppress a "press R to reload" hint at the wrong time.

```
Every tick
  Condition: Gun | WeaponKit  Is Full
    -> hide ReloadPrompt
  Condition: Gun | WeaponKit  Current Ammo  <  Gun | WeaponKit: Max Ammo
    Condition: Gun | WeaponKit  [Is Reloading]  is false
      -> show ReloadPrompt
```

The prompt shows only when the mag is below full and no reload is already running.

### 16. Infinite-ammo practice range

Set Infinite Reserve so reloads never spend spare rounds - a debug toggle or a training mode where the player never runs out.

```
On Ready
  Condition: Global.practice_mode  is true
    -> Gun | WeaponKit: Set Infinite Reserve  true
```

With infinite reserve on, every reload fills the mag for free and Reserve Ammo stops draining.

### 17. Enemy turret on its own timer

An enemy weapon uses the same rules as the player's. Drive its Fire from a timer, and let auto-reload pause it between clips.

```
Every 0.3 seconds
  Condition: Turret can see Player
    -> Turret | WeaponKit: Fire

Turret On Fire
  -> spawn EnemyBullet at Turret.global_position facing (Player.global_position - Turret.global_position).angle()

Turret On Reload Started
  -> play "enemy-reload" sound
```

The turret fires until its mag empties, auto-reload kicks in, and On Reload Started gives the player a readable window to push in.

### Other use cases

**Spell wands with mana charges.** Reskin the magazine as charges on a wand: each cast is a Fire, the reload is a channel that draws from a mana reserve, and On Reload Started plays the focusing animation. Silence effects are just Cancel Reload plus refusing to call Fire.

**Vehicles with multiple mounts.** A tank is two WeaponKit nodes on one hull - a slow single-shot cannon and a fast auto machine gun - each with its own ammo, cooldown, and reload. Because the node is the weapon, switching seats is just routing the trigger input to the other kit.

**Dual-wield pistols.** Two kits on the player, and the fire input alternates which one gets the Fire call. Each gun runs its own magazine and dry-click, so one pistol can be mid-reload while the other keeps shooting, which is the whole fantasy.

**Film-roll photography games.** A camera is a weapon that shoots photos: the film roll is the magazine, swapping rolls is the timed reload, and On Empty is the heartbreak click when the cryptid finally appears. Reload Progress drives the little rewind animation.

**Flamethrower fuel tanks.** Auto fire mode at a very high fire rate turns each On Fire into one puff of a continuous stream, with the magazine as the fuel tank. Fuel canister pickups call Add Reserve Ammo, and Ammo Percent drives the pressure gauge on the HUD.

---

## Tips and common mistakes

- **Fire does not spawn the bullet - you do, on On Fire.** Weapon Kit owns ammo, cooldown, and modes, but not the projectile. If you call Fire and nothing appears on screen, you are missing the On Fire event that spawns your bullet or casts your hitscan. This split is the whole point: any projectile system works with the pack.
- **Call Fire every frame for automatic weapons - the cooldown paces it.** It is safe (and intended) to call Fire on every tick the trigger is held. Fire only fires On Fire when a round actually leaves the barrel, so the fire rate, not your loop, sets the rhythm. For semi-auto, call Fire on the press event instead.
- **Start the magazine full by matching current_ammo to max_ammo.** `current_ammo` defaults to 12 and so does `max_ammo`, but if you raise the magazine size in the Inspector without raising the starting rounds, the weapon spawns partly empty. Set them together, or call Instant Reload on ready.
- **A reload needs rounds in the reserve.** Reload does nothing if `reserve_ammo` is 0 (and `infinite_reserve` is off) or if the magazine is already full. If Reload seems to be ignored, check the reserve count and whether Is Full is already true.
- **On Empty covers two moments.** It fires both when you pull the trigger on an empty mag and the instant a shot drains the last round. If you only want the dry-trigger click, gate it - for example only play the click when Has Ammo is false and the fire button is held.
- **Auto Reload is on by default.** With `auto_reload` on, running dry starts a reload on its own, so a manual Reload call may be redundant. If you want the player to always reload by hand, turn `auto_reload` off in the Inspector.
- **Cancel Reload gains no ammo.** It aborts the timer and leaves the magazine exactly as it was. It only helps when there were still rounds loaded when the reload began - cancelling an empty-mag reload just leaves you empty.
- **Fire modes 0 and 1 behave the same in code; the difference is how you call Fire.** Both fire one round per Fire call, paced by the cooldown. "Single" means you call Fire once per click; "auto" means you call it every frame the trigger is held. Only mode 2 (burst) changes what one Fire call does.
- **There are two "Set Fire Rate" and two "Set Fire Mode" entries in the picker.** One is the curated verb, one is the raw property setter, and they do the same thing. `Set Magazine Size` (the verb, which clamps at 0) and `Set Max Ammo` (the property setter) likewise both set the magazine size. Pick either; the verbs read more clearly in a sheet.
- **Read the progress expressions live, not once.** Reload Progress and Cooldown Progress change every frame, so wire them to a bar or reticle inside a per-tick event, not a one-off. Reload Progress reads 1 when no reload is running, which is the natural "full" resting state.
