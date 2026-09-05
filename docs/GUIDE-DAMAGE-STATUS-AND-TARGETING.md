# Damage, Status and Targeting - The Chain From Who Fired It To What It Hit

A bullet leaves a gun and something eventually dies. Between those two moments a game has to answer
five questions, and almost every project answers them five separate times, in five different places,
with five sets of private variables:

1. **Who made this?** The bullet is not the shooter. The turret is not the person who built it.
2. **What kind of hit was it, and what did it come to?** Fire against ice armour is not 10 damage.
3. **Does the hit leave something behind?** A burn, a poison, a slow, a stun.
4. **How hard is this game meant to be right now?** The same fireball on Easy and on Hard.
5. **What is the player aiming at?** The held enemy, and the help that keeps the aim on it.

This guide walks that chain in its own order, because each link is built on the one before it. The
ownership key is what makes damage creditable. Creditable damage is what makes a status tick score a
kill for the person who applied it. A difficulty factor is a number the typed hit multiplies by. And
the lock-on rows are how the player picks the thing all of it lands on.

Nothing here is a runtime. Every row compiles to plain GDScript over Godot's own `set_meta`,
`get_meta`, `get_nodes_in_group`, `Camera3D` and `Engine` metadata calls, with no plugin reference in
the emitted file, and a line written by hand opens back as the row that writes it.

## Table of Contents

1. [One key for who made this](#one-key-for-who-made-this)
2. [The chain, and why every reading walks it to the end](#the-chain-and-why-every-reading-walks-it-to-the-end)
3. [Friendly fire in one row](#friendly-fire-in-one-row)
4. [Damage that knows what kind it was](#damage-that-knows-what-kind-it-was)
5. [The kinds are a file your game owns](#the-kinds-are-a-file-your-game-owns)
6. [The report, and why it is written before the trigger fires](#the-report-and-why-it-is-written-before-the-trigger-fires)
7. [Who got the kill, and who assisted](#who-got-the-kill-and-who-assisted)
8. [A status is a word, a clock and a file](#a-status-is-a-word-a-clock-and-a-file)
9. [Ticks are ordinary typed damage](#ticks-are-ordinary-typed-damage)
10. [Stun, freeze, and the one number movement multiplies by](#stun-freeze-and-the-one-number-movement-multiplies-by)
11. [The difficulty in force, and the factor a row multiplies by](#the-difficulty-in-force-and-the-factor-a-row-multiplies-by)
12. [An assist that says out loud that it is one](#an-assist-that-says-out-loud-that-it-is-one)
13. [One held enemy, and the ring around it](#one-held-enemy-and-the-ring-around-it)
14. [Aim help with no lock at all](#aim-help-with-no-lock-at-all)
15. [The same words in 3D](#the-same-words-in-3d)
16. [What the Doctor says about all of this](#what-the-doctor-says-about-all-of-this)
17. [Tips and common mistakes](#tips-and-common-mistakes)

## One key for who made this

A bullet hits, an enemy dies, and the sheet cannot say who fired. Kill credit, assists, friendly
fire, "killed by" on the death screen and a boss that turns on whoever hurt it last all want the same
single fact, and every project that needed it wrote it privately on its own bullet scene, where only
that scene could read it.

The **Ownership** rows put it in one place: node metadata under the key `owner`. **Claim** writes it,
**Disown** takes it off, and a node nobody claimed simply has no key.

| Condition | Actions |
| --- | --- |
| **Player** ▸ On input action *just pressed* **"fire"** | **Player** ▸ Spawn **Bullet** at **Muzzle** |
| | **Ownership** ▸ Claim *last spawned* for *self* |

```gdscript
extends Node2D


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"fire"):
		var __spawned := preload("res://scenes/bullet.tscn").instantiate()
		get_parent().add_child(__spawned)
		__spawned.global_position = $Muzzle.global_position
		__spawned.set_meta(&"owner", self)
```

That is the whole write side. `set_meta` is Godot's own call, so a project that already wrote
`bullet.set_meta(&"owner", self)` by hand opens as the Claim row without changing a byte.

**Disown is the pool's row.** A recycled node must not carry credit from its last life, so a pool
disowns on the way back to the shelf. A dropped weapon anyone may pick up is the same idea.

**The trap this removes.** Written privately, the owner is a field on the bullet script, and the day
a second thing needs to be owned - a mine, a summon, a lingering fire patch - there are two fields
with two names and nothing compares them. One key means every row in the project asks the same
question of everything.

## The chain, and why every reading walks it to the end

Ownership is rarely one link. A bullet is owned by the turret; the turret is owned by the player who
built it. Kill credit wants the **person**, not the thing they were holding.

So there are two reading rows, and they are deliberately different:

| Row | Answers |
| --- | --- |
| **Claimed By** | One step up. The turret that fired the bullet. |
| **Root Owner Of** | The far end of the chain. The player behind the turret. |

**Root Owner Of** is the one a kill feed, a score row and an assist list all want.

```gdscript
	print(([bullet] + range(8)).reduce(func(__own: Variant, __step: int) -> Variant: return __own.get_meta(&"owner") if is_instance_valid(__own) and __own.has_meta(&"owner") else (__own if is_instance_valid(__own) else null)))
```

That is the emitted walk, and three details in it are worth knowing because they are three bugs you
do not have to find:

- **It folds instead of looping**, because an expression has nowhere to declare a local. Each step
  replaces the node it holds with that node's owner, and a step that finds no owner keeps what it
  has, so the answer settles on the root and stays there. It is bounded at eight links, which is far
  past any real chain (bullet, turret, player is three) and stops a chain that somehow points at
  itself from hanging.
- **The node rides the array rather than being the starting value.** `reduce` reads a starting value
  of `null` as "no starting value given" and folds from the first element instead, so a row asking
  about a node that has been freed would answer with the number `0`. Seeded this way it names the
  node once and answers nothing for nothing.
- **A step that lands on something freed answers nothing.** The player dies while their bullet is
  still in the air; the enemy that bullet kills would otherwise hand a row under On Death a freed
  object to read a name off. The walk stops with nothing instead, and a sheet asks about nothing the
  way it asks about anything else.

**Claimed By asks before it reads.** Godot treats a `null` fallback on `get_meta` as "no fallback
given" and errors on a node that was never claimed, which is the ordinary case this row has to answer
quietly. It calls `has_meta` first, and asks whether the owner it found is still valid too.

**A hand-written owner walk opens as an expression, whole.** The reading does not split the fold down
the middle to claim half of it; a project that already wrote that line gets it back byte for byte.

## Friendly fire in one row

Three conditions ask about ownership, and all three compare **root** owners on both sides. That is
what makes "same source" one idea rather than three: a bullet, the turret that fired it and the
player behind the turret are one answer.

| Row | Asks |
| --- | --- |
| **Is Owned By** | Does this node trace back to the owner you name? |
| **Is Mine** | Does it trace back to the same owner this row does? |
| **Hit Is Not My Owner** | The friendly-fire guard, for any hit trigger. |

**Hit Is Not My Owner** is the one you reach for first. Put the trigger's own collider in its field:

| Condition | Actions |
| --- | --- |
| **Bullet** ▸ On body entered | |
| **Ownership** ▸ hit *body* is not my owner | **Enemy** ▸ Take **10** damage of **"physical"** from *self* |
| | **Bullet** ▸ Destroy |

```gdscript
extends Area2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if (([body] + range(8)).reduce(func(__own: Variant, __step: int) -> Variant: return __own.get_meta(&"owner") if is_instance_valid(__own) and __own.has_meta(&"owner") else (__own if is_instance_valid(__own) else null)) != ([self] + range(8)).reduce(func(__own: Variant, __step: int) -> Variant: return __own.get_meta(&"owner") if is_instance_valid(__own) and __own.has_meta(&"owner") else (__own if is_instance_valid(__own) else null))):
		body.get_node("SimpleHealthBehavior").take_typed_damage(10.0, "physical", self)
		queue_free()
```

The bullet stops shooting the player who fired it **and** the turret that player built, with no flag
on the bullet and no layer trickery.

**The trap this removes.** Friendly fire is normally solved with a collision layer per team, which
works until a game has more than two teams, or a turret that belongs to a player, or a bullet that
should be able to hit a teammate's shield but not the teammate. Then the layers run out and the flags
begin. One key and one comparison do not run out.

## Damage that knows what kind it was

**Take Damage** takes a number. Every game past its first week needs the number to have a kind, and
today that arithmetic is written **in front of** the damage row, differently on every enemy.

**Take Damage Of Type** puts it inside the behaviour, in an order that never changes:

1. **The difficulty factor**, if the row named one.
2. **Resistance**, as a percentage off the incoming hit.
3. **Armour**, as flat points off what is left.
4. **The critical**, as a multiplier on what got through.
5. Then the pools and the health that **Take Damage** already had.

| Condition | Actions |
| --- | --- |
| **Fireball** ▸ On body entered | **Enemy** ▸ Take **12** damage of **"fire"** from *self* |

```gdscript
	body.get_node("SimpleHealthBehavior").take_typed_damage(12.0, "fire", self)
```

Twelve of fire against 50 per cent fire resistance and 3 armour lands for **3**. No other order of
those three operations gives 3, which is why the pack's own gate is that number rather than a reading
of the emitted text.

The dials are five rows on the actor **taking** the hit:

| Row | What it sets |
| --- | --- |
| **Resist** | A percentage off every hit of one kind. 50 for half, 100 for none at all. |
| **Immune To** | The same as resisting by 100: no health lost, no pool spent, no On Damaged. |
| **Weak To** | Extra damage from one kind. 50 for half again, 100 for double. |
| **Set Armour** | Flat points off every typed hit, after resistance. |
| **Set Crit** | How often a typed hit here lands as a critical, and what it multiplies by. |

**There is one opinion per kind, and the last row to run wins.** Resist, Immune To and Weak To all
write the same slot. Resisting fire by 50 and then declaring a weakness to fire leaves a weakness,
not an argument.

**The floor puts back what armour took off, and never raises a graze.** `minimum_damage` exists so
stacking armour cannot quietly make a node immortal, so it is held to what got **past resistance**. A
half-point graze against no armour at all lands for its half point, and a hit that resistance ate
entirely stays eaten, which is what immunity has to mean.

**The critical belongs to the actor taking the hit.** That is the shape a game with armour classes
wants. A game where the attacker owns the crit sets it on the target from the attacker's row before
dealing the damage, which is one extra row and no new concept.

**`take_damage` is untouched.** The typed row does its arithmetic and hands the finished number to
the row this pack already had, so the pools, the death latch, Destroy On Death and On Damaged all
still happen in exactly one place and behave exactly as they always did. Its body is frozen byte for
byte: a project written against it keeps compiling.

## The kinds are a file your game owns

Nothing in the plugin holds a list of damage types. A **DamageTypeSet** is names and the colour each
is drawn in, and one starter ships beside the pack - physical, fire, ice, poison - to edit or delete.
The type fields on every row suggest from whatever sets the project has.

That colour is not decoration. The HUD Kit's **Pop Floating Text As** asks the set which colour a
kind is drawn in, so a fire number is orange without a colour typed into the row:

| Condition | Actions |
| --- | --- |
| **Enemy** ▸ On damaged | **HUD Kit** ▸ Pop floating text *Enemy ▸ Last Damage Dealt* at *Enemy* as *Enemy ▸ Last Damage Type* |

The shipped **Pop Floating Text** is frozen beside it and unchanged. Three arguments are a promise;
a fourth would have rewritten every sheet already using it.

**A "crit" is a style, not a kind.** The starter draws it white and marks it by its size instead,
because a critical fire hit is still fire.

## The report, and why it is written before the trigger fires

Six readings say what the last hit was:

| Row | Answers |
| --- | --- |
| **Last Damage Type** | The word the row dealt it with. |
| **Last Damage Dealt** | What it came to after resistance, armour and the critical. |
| **Last Damage Before Mitigation** | What it was worth before this actor touched it. |
| **Last Hit Was A Crit** | Whether the last typed hit rolled a critical. |
| **Damage Type Is** | Whether the last hit was one particular kind. |
| **Last Damage** | The real-HP damage of the most recent damaging event. |

All of them are written **before** On Damaged fires, which is what lets one trigger branch into as
many reactions as the game has kinds with no expression in the condition lane:

| Condition | Actions |
| --- | --- |
| **Enemy** ▸ On damaged | |
| **Enemy** ▸ damage type is **"fire"** | **Enemy** ▸ Apply status **"burn"** for **3** s |
| **Enemy** ▸ last hit was a crit | **Juice** ▸ Screenshake **6**, **0.2** s |

```gdscript
extends Node2D


func _ready() -> void:
	$SimpleHealthBehavior.on_damaged.connect(_on_damaged)


func _on_damaged() -> void:
	if $SimpleHealthBehavior.damage_type_is("fire"):
		$StatusEffectsBehavior.apply("burn", 3.0, 1)
	if $SimpleHealthBehavior.last_hit_was_a_crit():
		$JuiceBehavior.screenshake(6.0, 0.2)
```

**The report is members, not signal arguments, on purpose.** On Damaged is a shipped trigger that
sheets are already connected to. Adding arguments to it would have broken every one of them.

**Last Damage Before Mitigation is the hit as this game is being played.** The difficulty scaling
happens first, so the pair of numbers a sheet shows for an absorbed or resisted label is honest about
what the player is actually facing.

## Who got the kill, and who assisted

**Take Damage From** is Take Damage that remembers. It records the source, **walked up the ownership
chain**, and then applies exactly the damage Take Damage would.

| Row | Answers |
| --- | --- |
| **Last Hit From** | Who last damaged this actor, as the person rather than the projectile. |
| **Killer Of** | Who killed it, or nothing while it is alive. |
| **Assists Of** | Everyone else who damaged it within **Assist Seconds**, the killer left out, each listed once. |
| **Killed By Me** | Whether it is dead and the kill traces back to the node you name. |

| Condition | Actions |
| --- | --- |
| **Enemy** ▸ On death | **Kill Feed** ▸ Add line **"{0} killed {1}"** with *Enemy ▸ Killer Of*, *Enemy* |
| **Enemy** ▸ killed by me *self* | **Player** ▸ Add **1** to **score** |

**Credit is written before the signal fires**, which is the whole reason a row under On Death can
read the killer at all.

**Credit is only taken for a hit that landed.** A kind the actor is immune to changed nothing, and a
hit inside i-frames changed nothing, so neither rewrites Last Hit From nor leaves an assist behind. A
boss that turns on whoever hurt it last does not turn on somebody whose fireball it shrugged off.

**A hit on a corpse credits nobody**, so the killer is never overwritten by the shot that arrives one
frame late.

**A freed source reads as nothing.** The person who killed you may be dead themselves by the time the
death screen asks. All three readings answer with nothing rather than with a freed object.

**Killed By Me walks the asker too**, so a kill by your own turret still counts as yours.

**The trap this removes.** Written by hand, kill credit is a `last_hit_by` variable set in the damage
function, and it is set *before* the guards that might refuse the hit, because that is where it reads
most naturally. The bug that follows is small, silent and takes an afternoon to find: an assist list
full of people who dealt nothing.

## A status is a word, a clock and a file

The **Status Effects** pack attaches under a node and gives it the thing the wound chain is missing:
a named condition that lasts a while, does something every so often, and goes away by itself.

**`Apply Status "burn" for 3 s` puts the word `burn` on the node for three seconds.** If `burn.tres`
exists, the file says what burn does. If nothing answers to the word, the status is still on, still
answers true to **Has Status**, and still expires on time - which is what makes a pure flag like
`stunned`, `marked` or `revealed` cost no authoring at all.

| Condition | Actions |
| --- | --- |
| **Enemy** ▸ On damaged | |
| **Enemy** ▸ damage type is **"fire"** | **Enemy** ▸ Apply status **"burn"** for **3** s, **1** stack |
| **Player** ▸ On drank antidote | **Player** ▸ Cleanse |

```gdscript
	$StatusEffectsBehavior.apply("burn", 3.0, 1)
	...
	$StatusEffectsBehavior.cleanse("")
```

**An effect answers to what it calls itself.** A file's Status Name when that field is filled in, its
file name when it is not, so `burn.tres` is "burn" with nothing typed anywhere and renaming the file
renames the effect.

**Effect files are found in two places, and the node's own list wins.** The behaviour looks first at
the **Effects** array in its Inspector, then in the **Effects Folder**. That is how one enemy carries
its own harsher `burn` without the folder or any other enemy knowing about it.

**Stacking is a rule on the file, not on the row.** A second application asks the file: *refresh*
puts the clock back, *extend* adds to what was left, *add* refreshes and piles stacks up to Max
Stacks. Ticks and healing are multiplied by the stack count, so five stacks of a bleed bleed five
times as fast.

**Cleanse asks the file; Remove Status does not.** A Cleanse with no name takes off everything whose
file says it may be cleansed, which is what makes an antidote one row - and a curse is a file that
says it may not. Naming the curse in a Cleanse does not get around it. **Remove Status** is the row
that takes something off regardless: the boss shrugs it off, the shield was spent, the scene moved
on.

**Immunity refuses the next one and takes off the current one.** An immunity you have to wait out is
not one, so **Immune To Status** ends what it names as well as refusing it for the seconds you give.

**The tint is mixed, not set.** Every active effect's tint is multiplied together onto the host's
modulate; the host's own colour is remembered when the first one goes on and put back when the last
one comes off. A host that is not a `CanvasItem` is simply left alone and its statuses work exactly
the same. While a player has asked for reduced flashing, the shift is held under the same ceiling the
screen effects use.

**The trap this removes.** A poison written by hand is a timer, a variable, an Every row dealing
damage, a tint set on the sprite, and a tint nobody remembers to take off when the timer runs out -
and then all of it again for burn, because none of it was reusable.

## Ticks are ordinary typed damage

This is the join between the two halves of the guide, and it is the reason they are on one page.

A tick with a Tick Amount calls the Health behaviour's **Take Damage Of Type** with the file's Tick
Type. Everything that applies to a hit from a bullet applies to a tick: resistance, immunity, armour,
the minimum, the crit roll, the pools, On Damaged, and the kill credit.

So a fire-immune enemy is immune to burning, with nothing written anywhere about burning.

**Kill credit for a tick belongs to the node.** A tick's damage is credited to whoever **Claimed** the
Status Effects node, through the project's one ownership key, so:

| Condition | Actions |
| --- | --- |
| **Dart** ▸ On body entered | **Ownership** ▸ Claim *body ▸ StatusEffectsBehavior* for *self* |
| | *body* ▸ Apply status **"poison"** for **6** s |

A kill by that poison is scored to the person who threw the dart, exactly as a bullet's would be.
There is no per-application source, so a game where two players poison the same enemy and each wants
their own credit claims the node again as it applies.

**A claimer who has since been freed is credited as nobody, and the tick lands all the same.** The
poisoner dying is the ordinary case for a poison, not the exceptional one.

Two engine details in that path were bugs before they were tests, and they are worth carrying into
your own packs:

- **A status ends when its node leaves the tree** as often as when its clock runs out - a pooled enemy
  despawning is exactly that - and ending one asks for the Boosts autoload, which is a question about
  the tree. `get_tree()` on a node with no tree is an engine error rather than a null, so being in the
  tree is tested first.
- **The stored owner is read, tested, and only then cast.** Casting a freed object is itself the
  error, so a null guard written after the cast never gets a word in.

## Stun, freeze, and the one number movement multiplies by

Stun and freeze move nothing themselves. They are words the movement packs and the state machine
**ask** about, which keeps this pack out of every controller's business:

| Condition | Actions |
| --- | --- |
| **System** ▸ Every tick | |
| **Player** ▸ *not* has status **"stunned"** | **Player** ▸ Move with the stick |

And **Speed Factor** is the product of every active effect's speed factor: 1 with nothing on, 0.5
under one slow, 0 under a root.

| Condition | Actions |
| --- | --- |
| **System** ▸ Every tick | **Player** ▸ Set **speed** to **220** × *Player ▸ Speed Factor* |

```gdscript
	speed = 220.0 * $StatusEffectsBehavior.speed_factor()
```

Multiply your movement speed by it once and every slow, root and haste in the game already works,
including ones you add next year.

**Multipliers run through the Boosts pack.** An effect with a Multiplier Tag starts a tagged boost
while it lasts and stops it when it ends, and Extend Status extends both clocks together. Boosts
stays the multiplier engine; a project without it simply gets no multiplier, which is the honest
answer rather than an error.

## The difficulty in force, and the factor a row multiplies by

A **DifficultyResource** is one difficulty as a file: the word a player picks, the line a menu shows
under it, and the named factors your rows multiply by. Three starters ship - easy, normal, hard - and
the plugin holds no list of difficulties anywhere.

**Nothing in the file changes the game on its own.** A factor changes something because a row
multiplied by it. `damage_taken` where damage is dealt, `enemy_count` where a wave is sized. Keys
nothing reads are simply unread, and every key of the file shows in the Inspector as a field of its
own, so a factor invented today is an ordinary field in every difficulty file tomorrow.

| Condition | Actions |
| --- | --- |
| **System** ▸ On start of layout | **Settings** ▸ Use the difficulty the setting **"difficulty"** names |
| **Wave** ▸ On wave starting | **Wave** ▸ Set **count** to **8** × *Settings ▸ Difficulty Factor* **"enemy_count"** |

```gdscript
	Settings.use_difficulty_from("difficulty")
	...
	count = int(8.0 * Settings.difficulty_factor("enemy_count"))
```

**A factor no difficulty writes reads as 1.0.** So does a game that has chosen no difficulty at all.
That is what lets a row multiply by a factor before any file mentions it, and it is why adding
difficulty to a finished game is a pass over the numbers rather than a rewrite.

**The factors in force are kept as `Engine` metadata**, the same way the accessibility dials are, so
any script reads one in a line and no pack has to name another. The Health behaviour depends on no
Settings autoload and no Difficulty class for exactly this reason.

Which is what makes the common case one field on a row rather than a multiplication in front of it.
**Take Damage Of Type** has an optional **Scaled By**:

| Condition | Actions |
| --- | --- |
| **Trap** ▸ On body entered | *body* ▸ Take **20** damage of **"physical"** from *self*, scaled by **"damage_taken"** |

```gdscript
	body.get_node("SimpleHealthBehavior").take_typed_damage(20.0, "physical", self, "damage_taken")
```

A blank field, a key the difficulty in force has no answer for, and a game that installed no settings
pack at all all read 1.0 and leave the hit exactly as the row wrote it. The parameter is trailing and
defaulted, so every call written before it goes on compiling.

The rest of the vocabulary:

| Row | Answers |
| --- | --- |
| **Use Difficulty** | Puts one in force: a file, a path, or the word it goes by. Naming nothing clears it. |
| **Difficulty Is** | The one in force goes by this word, letter case ignored. |
| **Difficulty Name** | The word it goes by. Blank while none has been chosen. |
| **Difficulty Names** | The words the files in a folder go by, in file-name order. Drop it into a dropdown. |
| **On Difficulty Changed** | One was put in force, or cleared. Carries the word, blank when cleared. |

## An assist that says out loud that it is one

**Declare Assist** is one row that declares a yes-or-no setting on the Accessibility page that
**Menu Rows From Declarations** already builds, and records the name so **Assist Is On** and **On
Assist Changed** can speak about it.

| Condition | Actions |
| --- | --- |
| **System** ▸ On start of layout | **Settings** ▸ Declare assist **"infinite_ammo"**, default **off** |
| **Player** ▸ On fired | |
| *not* **Settings** ▸ assist **"infinite_ammo"** is on | **Player** ▸ Subtract **1** from **ammo** |

Underneath it stays an ordinary setting: saved, reset and re-applied with the rest, and On Assist
Changed fires **beside** On Setting Changed rather than instead of it. The pack enforces nothing
about what an assist means. It only makes the accessibility page able to say that this one is an
assist, which is the difference between a menu a player trusts and a list of toggles.

## One held enemy, and the ring around it

The **Targeting** pack attaches to a `Node2D` and gives it one held enemy and a steadier aim.

**Lock On To Nearest** searches a cone around the host's facing for the closest member of a group
inside a range, and holds it:

| Condition | Actions |
| --- | --- |
| **Player** ▸ On input action *just pressed* **"lock_on"** | **Player** ▸ Lock on to nearest in **"enemies"**, cone **60**, range **400** |
| **Player** ▸ On input action *just pressed* **"next_target"** | **Player** ▸ Cycle target |
| **Player** ▸ On target lost | **Reticle** ▸ Hide |
| **Player** ▸ On target locked | **Reticle** ▸ Show |

```gdscript
extends Node2D


func _ready() -> void:
	$TargetingBehavior.target_locked.connect(_on_target_locked)
	$TargetingBehavior.target_lost.connect(_on_target_lost)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"lock_on"):
		$TargetingBehavior.lock_nearest(&"enemies", 60.0, 400.0)
	if Input.is_action_just_pressed(&"next_target"):
		$TargetingBehavior.cycle_target()
```

**A lock ends in exactly four ways, and On Target Lost carries the word for which**: `died`,
`out_of_range`, `blocked`, `released`. One trigger, four branches, and no polling for the case where
the enemy simply stopped existing.

**Cycle Target walks the ring the last search built**, left to right by angle, wrapping from the
rightmost back to the leftmost. That is the order the player sees the enemies in, which is the only
order a shoulder button cycling targets can defensibly use. Candidates that died since the search are
dropped first.

**On Target Locked fires when the held target CHANGES**, so a row polled every frame fires it once
rather than every frame.

**Locked Target On Screen already accounts for camera zoom and scroll**, so a reticle living on a
`CanvasLayer` needs no conversion of its own.

**Distance To Target answers INF with nothing held**, so "is the target closer than 200" is plainly
false rather than accidentally true.

**A search that finds nothing leaves the current lock alone**, which is what stops a lock from
flickering off every time the player turns.

**The trap this removes, and it is a nasty one.** A freed object compares equal to `null` in GDScript,
so a pack that holds a node reference and writes `if _target == null: return` silently parks itself
in exactly the case a "the target died" announcement exists for. This pack keeps a boolean of its own
rather than testing the reference, which is worth copying into any pack of yours that holds a node
and announces losing it.

## Aim help with no lock at all

Two expressions need no lock, and they are the ones a controller player feels:

| Row | Answers |
| --- | --- |
| **Assisted Aim** | The direction you hand it, bent toward the nearest target the ray is nearly pointing at. |
| **Magnetism** | The turn rate you hand it, slowed while the aim is crossing a target. |

| Condition | Actions |
| --- | --- |
| **System** ▸ Every tick | **Player** ▸ Set **aim** to *Player ▸ Assisted Aim* of **stick**, strength **0.4** |

```gdscript
	aim = $TargetingBehavior.assisted_aim(stick, 0.4)
```

Assisted Aim keeps the length you passed in and only changes the direction, so it drops into a
velocity as readily as into a facing. A strength of 0 is no help and 1 is dead on.

**"Nearly" is the aim-assist radius the accessibility rows already declare**, measured across the aim
ray. The options screen that already has the slider governs the help, and **a radius of zero is the
off switch**: nothing is ever near enough, both expressions hand back exactly what they were given,
and the whole feature is off. That is the honest off switch, and it was already on the options page
before this pack existed.

**Line of sight is shared, not duplicated.** With Require Line Of Sight on, a Line Of Sight behaviour
attached to the same host answers the wall question if there is one, so the two packs share one idea
of a wall; otherwise this casts its own ray on the blocker mask.

## The same words in 3D

**Targeting 3D** is the twin, verb for verb, on a `Node3D`. Two things are different, and both are
differences 3D actually has.

**The cone is centred on the CAMERA's forward, not the host's rotation.** In a third-person game the
player locks on to what is on screen, not to what the character model happens to be turned toward.
The pack asks the viewport for its current `Camera3D`. With no camera in the scene to ask, it falls
back to the host's own forward axis, which is exactly what a turret or a headless test has.

**Snap On Aim Down Sights** is the row a shooter with sights wants:

| Condition | Actions |
| --- | --- |
| **Player** ▸ On input action *just pressed* **"aim"** | **Player** ▸ Snap on aim down sights, at most **8** degrees |

```gdscript
	if Input.is_action_just_pressed(&"aim"):
		$Targeting3DBehavior.snap_on_aim_down_sights(8.0)
```

It turns the host onto the nearest target the aim is already nearly on, and **refuses a turn wider
than the row allows**, which is what keeps the settle from becoming a yank: the sights come up and
the view tightens onto what the player was already nearly on, never onto something behind them. A
radius of zero on the accessibility dial turns it off entirely, like the rest of the aim help.

Cycle Target orders the ring by angle **about the world's up axis**, which is the same left-to-right
the player sees. Locked Target On Screen projects through the camera the player is actually looking
through. Distance To Target is in metres.

Two 3D traps are baked into the pack, and both are worth knowing when you write your own:

- **`Node3D.get_global_transform()` fails outside the tree and answers identity**, so `global_position`
  reads back as the origin for every orphan node. A whole scene's worth of candidates would land on
  top of each other and every cone would find nothing. Every world position this pack reads goes
  through one placement seam that asks `is_inside_tree()` first, the same seam the streaming pack
  ships for the same reason. `Node2D` has no such check, which is why the 2D twin never showed it.
- **`Basis.looking_at` collapses when the direction is collinear with the up vector.** A target
  straight overhead is declined rather than turned onto badly.

## What the Doctor says about all of this

Three quiet notes, and none of them draws anything inside a sheet: the affected row wears the amber
state, and the words live in the Doctor's triage inbox and in the row's help strip when it is
selected.

**The Damage section is two findings, and they are the two directions the lists can disagree in.**
A damage type is only ever a word, so a single mistyped one splits the two lists and the game goes on
running: "fier" resists nothing, "fire" resistance protects against nothing, nothing crashes, nothing
warns, and the enemy that was supposed to shrug off flame simply does not.

| Finding | Says |
| --- | --- |
| **A kind nobody declared** | A row deals a kind no DamageTypeSet in the project names. |
| **A guard against nothing** | A node resists, is immune to or is weak to a kind no row ever deals. |

**Both are silent on a project that has written nothing down.** Types are optional, so the first is
only asked once a set exists, and the second only once some row deals something. A list missing an
entry must never become a finding claiming the entry does not exist.

**The Options section gains a third question**: a project that chooses a difficulty while nothing
reads a factor out of one, which is a menu that changes nothing. It is asked of **call sites**,
autoload name and all, so the pack that defines those verbs cannot answer it on everybody's behalf.

The Damage section ships as an **extension** check, registered through the very seam a pack uses, so
a pack that adds damage of its own - an elements kit, a status system - joins this same section
rather than inventing a second report.

## Tips and common mistakes

**Claim the thing, not the scene.** Claim runs on the node that was spawned, with the shooter in the
Owner field. Claiming the muzzle, or the scene root, gives you a chain that answers with a level.

**Disown on the way back to the pool, not on the way out of it.** A node that keeps its last owner
until it is next fired will credit one kill to the wrong player, which is the hardest kind of bug to
reproduce.

**Take Damage and Take Damage Of Type are both fine to use.** The untyped row is not deprecated and
never will be. Use the typed one where the kind matters, and leave the plain one where a fall or a
drowning simply costs health.

**Set the resistances once, on the actor.** Resist is not a per-hit modifier. Setting it in a spawn
row, or in the enemy's own On Ready, is the shape it was built for.

**A status with no file is a feature.** Reach for `Apply Status "marked" for 5 s` whenever you need a
flag with a clock on it. Writing a `.tres` for a word that only needs to be true is work you do not
owe anybody.

**Point the Effects Folder at your own folder** once you have copied the starters out of the pack. A
plugin update rewrites the pack's own folder, and your edits to `poison.tres` live there until you
move them.

**A factor is a multiplier, so the neutral value is 1, not 0.** A difficulty file that writes
`damage_taken: 0` makes the player immortal on that difficulty, which is a whole evening of
confusion. Half damage is `0.5`.

**Name the factor before the file has it.** `Difficulty Factor "boss_hp"` on every boss reads 1.0
until some difficulty file writes the key, so the rows can go in first and the tuning can happen
later without touching them again.

**Aim assist is one radius for the whole game.** It lives on the accessibility page as a declared
setting, and every aim-help row in every pack reads it. Do not add a second slider.

**Write 360 for no cone at all**, rather than a very large number, and leave the group empty to use
the behaviour's own Target Group.

**Claim the Status Effects node, not its host, for tick credit.** The credit key is read off the node
the ticks run on. Claiming the enemy itself is a different statement.

**Every row above is in the picker under a category you can read.** Ownership rows sit under
**Ownership**, the typed damage and credit rows under **Health**, the status rows under **Status
Effects**, the difficulty and assist rows under **Settings**, and the lock rows under **Targeting**
or **Targeting 3D**. If a name in this guide is not where you expect it, the picker's search finds it
by any word in it.
