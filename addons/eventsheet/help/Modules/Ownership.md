# Ownership

**Ownership** is how a sheet answers the one question an action game asks constantly and almost
never has an answer for: who made this? A bullet lands, an enemy dies, and the rows under the death
trigger have nobody to credit. Kill credit, assists, friendly fire, a "killed by" line on the death
screen and a boss that turns on whoever hurt it last are all the same fact asked five ways - the
owner of the thing that did it.

Seven rows cover it. **Claim** and **Disown** write the fact, **Claimed By** and **Root Owner Of**
read it, and **Is Owned By**, **Is Mine** and **Hit Is Not My Owner** ask about it. What makes them
one subject rather than seven is the key they share: node metadata literally named `owner`. Written
privately on a bullet scene, "who fired this" is a field only that scene knows about. Written here,
it is one key every row in the project can read.

The chain is what makes it worth having. A bullet is claimed by the turret, the turret by the
player who built it, so "who fired this" and "whose kill is it" are different distances along the
same line. **Claimed By** answers one step up - the turret. **Root Owner Of** walks to the far end -
the player. The three asking rows compare root owners on **both** sides, which is what makes "same
source" one idea instead of three special cases.

Everything compiles to plain `set_meta`, `get_meta` and `has_meta` calls with zero plugin
references. There is no component to attach, no autoload, and nothing to enable - which is also why
a hand-written project that already tags its projectiles this way opens as a sheet and reads back
as these rows.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Reference tables](#reference-tables)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Kill credit** - the score goes to the player, not to the bullet that arrived.
- **Friendly fire** - one condition stops a shot hurting whoever fired it, and their turrets.
- **Assists** - everyone whose damage traces back to them shares in the kill.
- **Summons and pets** - a minion's kills are yours because the minion is yours.
- **Death screens and kill feeds** - the name shown is a person, not a projectile.
- **Reading an existing script** - a project that already tags its shots opens as these rows.

## Core concepts

- **The key is metadata named `owner`.** Every row in this module writes or reads that one key and
  nothing else, so two rows written months apart cannot disagree about where the fact lives.
- **Claim writes it, Disown removes it.** A node that was never claimed simply has no key, and every
  reading row is written to answer quietly rather than error on that ordinary case.
- **Claiming again replaces the owner.** There is no stack and no history: the last Claim wins,
  which is what makes a picked-up weapon or a captured turret one row rather than a bookkeeping job.
- **Ownership is a chain, not a pair.** Bullet to turret to player is three nodes and two links, and
  the reading rows are the two useful distances along it.
- **Claimed By is one step; Root Owner Of is the far end.** Reach for Claimed By when you want the
  thing (which turret), and Root Owner Of when you want the person (whose kill).
- **The asking rows compare roots on both sides.** **Is Owned By**, **Is Mine** and **Hit Is Not My
  Owner** all walk both nodes to their roots first, so a bullet, the turret that fired it and the
  player behind the turret give one answer instead of three.
- **The walk is bounded at eight links.** An expression has nowhere to write a loop, so the walk is
  a fold over eight steps. Eight is far past any real chain - bullet, turret, player is three - and
  a chain that somehow points back at itself still answers instead of hanging.
- **Past the end, the walk keeps the answer it has.** A two-link chain costs exactly what an
  eight-link one does, and a node nobody claimed answers with itself.
- **A step that lands on something freed answers nothing.** The player dies while their bullet is
  still in the air; the enemy that bullet kills would otherwise hand a death row a freed object to
  read a name off. The walk stops with nothing instead, and a sheet asks about nothing the way it
  asks about anything else - `is nothing`, or a field left empty.
- **All four reading rows are built from one fragment.** Root Owner Of, Is Owned By, Is Mine and Hit
  Is Not My Owner emit the same walk, so they cannot drift into disagreeing about what "the source
  of this" means.

## Reference tables

| Name | Kind | What it does |
| --- | --- | --- |
| Claim | Action | Marks a node as belonging to somebody - a spawned bullet, an armed trap, a summon. |
| Disown | Action | Takes the owner off a node, so it belongs to nobody again. |
| Claimed By | Expression | The node that claimed this one, one step up. Nothing when it was never claimed, or the owner has gone. |
| Root Owner Of | Expression | The far end of the chain: bullet to turret to player answers with the player. |
| Is Owned By | Condition | True while a node traces back to the owner you name. |
| Is Mine | Condition | True while a node traces back to the same owner this row does. |
| Hit Is Not My Owner | Condition | The friendly-fire guard: true while what was hit does not trace back to whoever fired this. |

## Use cases

**1. Credit a kill to the person, not the projectile.** In the row that spawns the shot, **Ownership
▸ Claim** the new node for `self`. When it lands, the damage row reads **Root Owner Of** the bullet,
and the score goes to a player rather than to a bullet that no longer exists.

**2. A bullet that cannot shoot its own shooter.** Under the bullet's hit trigger, put **Hit Is Not
My Owner** with the trigger's own collider in the field. Nothing else changes and no team flag is
needed: the shot passes through whoever fired it, and through the turret they built.

**3. Claim in the spawn row itself, not later.** The spawn action names the copy it just made, so
Claim goes directly under it. A shot that travels one frame before it is claimed is a shot that can
kill its own shooter on the first frame - the bug that looks random and never is.

**4. A turret's kills belong to the player who built it.** Claim the turret for the player when it
is placed, and claim each shot for the turret. The chain does the rest: **Root Owner Of** the shot
answers with the player, two links away, without a single row knowing the turret exists.

**5. Which turret fired this, not which player.** For damage numbers coloured per emplacement, or a
repair prompt that highlights the gun that got the last kill, use **Claimed By** instead. It stops
one step up, which is exactly the thing rather than the person.

**6. Minions and summons count as yours.** Claim the summon for the summoner as it arrives, and
claim whatever the summon spawns for the summon. Everything the pet does traces back to you through
two links, so the pet needs no team field of its own.

**7. Friendly fire between two named players.** Under a hit event, ask **Is Owned By** with the
other player in the Owner field and run the damage rows only when it is false. Both sides are walked
to their roots, so the answer is the same whether the hit came from the player, their turret or
their pet.

**8. An explosion that spares the thrower.** Walk the bodies the blast overlapped and, for each one,
ask **Is Mine** before applying damage. The grenade claimed by the thrower and the thrower
themselves share a root, so the thrower is skipped and everybody else is not.

**9. A pooled bullet forgets its last life.** A recycled node that still carries a Claim will credit
its next kill to whoever fired it last. The bundled Object Pool pack **Disown**s a node on the way
back to the shelf for exactly this reason; a pool you wrote yourself wants the same row.

**10. An assist list.** Record **Root Owner Of** the source of every hit an enemy takes into a list,
and on death award the killer their kill and everybody else in the list an assist. The bundled
Health pack walks the same chain to decide who a hit belongs to, so the two agree about the killer.

**11. A boss that turns on whoever hurt it last.** Store **Root Owner Of** the incoming hit into a
variable each time the boss takes damage, and let the targeting rows aim at that node. The boss
chases the person, not the arrow that landed.

**12. A shield that only stops what is not mine.** Under the shield's area overlap, invert **Is
Mine** on the body that entered. Your own shots leave through it, everything else is absorbed, and
neither the shots nor the shield need to know about teams.

**13. "Killed by" on the death screen.** The death event reads **Root Owner Of** the last damage
source and shows that node's name. When the owner has been freed - the killer died first - the walk
answers with nothing, so guard the field and print "the environment" rather than a broken name.

**14. A dropped weapon that anyone may pick up.** **Disown** the weapon when it is dropped, so it
belongs to nobody, and **Claim** it for whoever picks it up next. The kill after the pickup is
theirs and the kills before it are not retroactively reassigned.

**15. A debug readout while you are wiring it up.** Print **Claimed By** and **Root Owner Of** side
by side for the node under the cursor. One step versus the whole chain in one line is usually enough
to spot the Claim that never ran, or the pooled node that never disowned.

**16. Open an existing hand-written script.** A project that already writes
`set_meta(&"owner", shooter)` on its projectiles - the bundled Bullet pack's Fired By row does
exactly that - opens as a sheet and reads back as these rows, which is the fastest way to see who
claims what and when.

### Other use cases

**A carried item that changes hands**, re-claimed on every pickup so credit follows the holder.

**A vehicle and its guns**, claimed when the player gets in and disowned when they get out.

**A hazard the level owns**, claimed by its spawner so the death screen names the spikes.

**A team tint** read from the root owner, so every projectile in the air is coloured by whose it is.

**A replay log** that records the root owner of every shot, so a finished run can be scored again.

## Tips and common mistakes

- **This is metadata, not `Node.owner`.** Godot already has a property called `owner` that says which
  scene a node was saved with. These rows never touch it. They read and write a metadata key that
  happens to share the name, and changing one has no effect on the other.
- **A node nobody claimed is its own root owner.** **Root Owner Of** an unclaimed node answers with
  the node itself, not with nothing. That is usually what you want, but it does mean **Is Mine** on
  an unclaimed node compares the node against you rather than asking "is this ownerless".
- **Claim once, at the spawn.** Re-claiming every frame works and costs nothing, but it hides the
  spawn row that forgot to claim, which is the failure you are actually trying to find.
- **Disown when you recycle.** Pooling without disowning is the one way to get credit that is not
  merely missing but wrong, and it shows up as a kill attributed to a player who is not even in the
  fight any more.
- **Put the trigger's own collider into Hit Is Not My Owner.** The field wants what was hit, which
  the hit trigger above the row already handed you. Passing the bullet instead asks a question that
  is always true.
- **Claimed By is not Root Owner Of.** A kill feed built on Claimed By names turrets and summons
  instead of players, and looks correct right up to the first player who builds something.
- **A freed owner reads as nothing, deliberately.** If a name is missing on the death screen when the
  killer died first, that is the walk refusing to hand you a freed object rather than a bug. Guard
  the field.
- **Eight links is the limit.** A chain longer than eight stops short and answers with whatever it
  reached. Real chains are two or three; if you need more than eight, the thing you are modelling is
  a list, not an ownership chain.
- **Ownership says nothing about teams by itself.** Two players on the same side still trace back to
  two different roots. A team check is **Is Owned By** against a shared node - a team object both
  players are claimed for - not something the chain answers for free.
