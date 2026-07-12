# ObjectPool

**ObjectPool** is the `ObjectPool` autoload singleton: it reuses nodes instead of creating and freeing
them. Spawning a bullet or an enemy every frame and freeing it a moment later makes a game hitch; a pool
keeps a stash of ready-made nodes, hands one out on Spawn, and takes it back on Despawn, so the heavy work
happens once. There are two ways to pool: the easy way, Create Pool from a scene with an optional
prewarm; and the custom way, Create Empty Pool then Add To Pool your own nodes. Despawned nodes are parked
(hidden, processing off) under the ObjectPool and reused on the next Spawn.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this pack shines

- **Bullet-hell and shooters** - hundreds of bullets a second with no stutter.
- **Particle-like effects** - reusable hit sparks, muzzle flashes, dust puffs.
- **Enemy waves** - respawn the same enemy nodes instead of instancing new ones.
- **Floating damage numbers** - a pool of labels you hand out and reclaim.
- **Coins and pickups** in an endless runner.
- **Tilemap chunks or platforms** streamed as the player moves.
- **Audio one-shot players** you reuse for overlapping sounds.
- **Projectile trails and afterimages.**
- **Pooled UI rows** for a long scrolling list.
- **Any spawn-heavy mobile game** where garbage collection hitches hurt.

## Core concepts

- **A pool is a named stash.** You make a pool by name ("bullets"), and everything else refers to it by
  that name.
- **Two ways to fill it.** Create Pool from a `.tscn` makes copies for you; Create Empty Pool plus Add To
  Pool lets you pool your own custom nodes.
- **Spawn hands out a ready node.** It reuses a free one, or makes a new copy from the pool's scene if the
  stash is empty. The node is added to the current scene, made visible, and returned so you can position
  it.
- **Despawn parks it, it does not free it.** A despawned node is hidden, its processing stopped, and it is
  moved back into the pool to wait for the next Spawn.
- **Prewarm to avoid the first-use cost.** Make the copies up front (at load time) so the first burst of
  spawns is already smooth.

## Setup

Register **ObjectPool** as an autoload (Project Settings, Autoload). Then create a pool once and spawn from
it.

A pooled bullet:

```
On Ready
  -> ObjectPool: Create Pool  "bullets", "res://bullet.tscn", 32
On fire pressed
  -> set Bullet = ObjectPool.Spawn("bullets")
  -> set Bullet.global_position to the muzzle
Bullet lifetime over  (in the bullet's own logic)
  -> ObjectPool: Despawn  Bullet
```

## ACE reference

### Actions

| Action | Parameters | Description |
|--------|-----------|-------------|
| Create Pool | pool_name, scene_path, prewarm | The easy way: a pool that spawns copies of a scene, optionally pre-making some now. |
| Create Empty Pool | pool_name | The custom way: a pool with no scene; fill it with Add To Pool. |
| Add To Pool | pool_name, node | Puts one of your own nodes into a pool as a ready-to-reuse instance. |
| Prewarm | pool_name, count | Pre-makes more copies for a scene pool. |
| Despawn | node | Hands a spawned node back to its pool to be reused (hidden, processing off). Fires On Despawned. |
| Despawn All | pool_name | Hands every active node of a pool back at once. |
| Clear Pool | pool_name | Frees every node in a pool and removes the pool. |

### Conditions

| Condition | Parameters | Description |
|-----------|-----------|-------------|
| Has Pool | pool_name | Whether a pool with this name exists. |

### Expressions

| Expression | Parameters | Returns | Description |
|-----------|-----------|---------|-------------|
| Spawn | pool_name | Node | Hands out a ready node (reusing a free one, else a new copy), added to the scene and returned. Fires On Spawned. |
| Last Spawned | (none) | Node | The node most recently spawned. |
| Last Despawned | (none) | Node | The node most recently despawned. |
| Free Count | pool_name | int | How many ready (unused) nodes a pool holds. |
| Active Count | pool_name | int | How many of a pool's nodes are currently spawned. |
| Pool Size | pool_name | int | A pool's total nodes (free plus active). |

### Triggers

| Trigger | Description |
|---------|-------------|
| On Spawned | Fires each time a node is spawned. |
| On Despawned | Fires each time a node is despawned. |

## Use cases

**1. Pooled bullets.**

```
On Ready
  -> ObjectPool: Create Pool  "bullets", "res://bullet.tscn", 64
On fire
  -> set b = ObjectPool.Spawn("bullets")
  -> set b.global_position to the muzzle, aim it
```

**2. Reclaim a bullet on hit or off-screen.**

```
Bullet hits something  (bullet logic)
  -> ObjectPool: Despawn  self
```

**3. Hit-spark effects.**

```
On Ready
  -> ObjectPool: Create Pool  "sparks", "res://spark.tscn", 16
On impact
  -> set s = ObjectPool.Spawn("sparks"), place it, play its animation
```

**4. Enemy waves.**

```
On wave start
  -> Repeat 10 times: set e = ObjectPool.Spawn("enemies"), place it
On enemy killed
  -> ObjectPool: Despawn  the enemy
```

**5. Prewarm before a boss.**

```
On boss intro
  -> ObjectPool: Prewarm  "bullets", 200
```

**6. Custom pool of your own nodes.**

```
On Ready
  -> ObjectPool: Create Empty Pool  "labels"
  -> for each pre-made Label: ObjectPool: Add To Pool  "labels", the Label
```

**7. Floating damage numbers from a custom pool.**

```
On damage
  -> set n = ObjectPool.Spawn("labels"), set its text and position
```

**8. Reset a level cleanly.**

```
On level restart
  -> ObjectPool: Despawn All  "enemies"
  -> ObjectPool: Despawn All  "bullets"
```

**9. Free a pool you are done with.**

```
On leave stage
  -> ObjectPool: Clear Pool  "stage_props"
```

**10. Show pool stats while tuning.**

```
Every 0.5 seconds
  -> set DebugLabel text to "active " + ObjectPool.Active Count("bullets") + " / free " + ObjectPool.Free Count("bullets")
```

**11. React on spawn.**

```
On Spawned
  -> play a tiny spawn blip on ObjectPool.Last Spawned()
```

**12. Guard against a missing pool.**

```
On fire
  Condition: ObjectPool  Has Pool  "bullets"
    -> set b = ObjectPool.Spawn("bullets")
```

**13. Pooled damage numbers that dissolve with Fade.** Pair with the Fade pack: the label fades out, then
its fade-out trigger hands it back to the pool instead of freeing it.

```
On damage
  -> set n = ObjectPool.Spawn("labels"), set its text and position
  -> n | Fade: Fade Out  0.6
Label On Faded Out
  -> ObjectPool: Despawn  the label
```

Leave the Fade behavior's free-on-fade option off - freeing a pooled node loses it for good.

**14. Endless runner ground recycling.** The same handful of tile nodes leapfrogs forever: reclaim tiles
behind the player and hand them back out ahead.

```
Every tick
  Condition: a Tile is off-screen behind the player
    -> ObjectPool: Despawn  the Tile
On gap ahead
  -> set t = ObjectPool.Spawn("tiles"), place it at the next slot
```

**15. Cap the active count so a pool cannot balloon.** A scene pool grows on demand, so in a spawn storm
put the ceiling in your own logic.

```
On fire
  Condition: ObjectPool.Active Count("bullets") < 100
    -> set b = ObjectPool.Spawn("bullets"), aim it
```

The oldest shots despawn on their own (hit or off-screen), freeing room for the next volley.

### Other use cases

**Footprint and tire-track trails.** A small pool of decal sprites is handed out under the character each step and reclaimed once the trail behind grows long enough.

**Turret muzzle flashes.** A defense level with dozens of turrets shares one flash pool, so every barrel can flash each shot without a single instancing hitch.

**Chat and combat-log bubbles.** A pool of text bubbles serves every speaker in the scene, despawned as each bubble expires so long sessions never accumulate nodes.

**Rain splashes and weather.** Spawn splash effects from a pool wherever drops land and despawn them a moment later, keeping heavy weather cheap on mobile.

**Boss minion recycling.** A summoner boss reuses the same minion nodes across the whole fight, with Despawn All wiping the arena clean between phases.

## Tips and common mistakes

- **Despawn, do not free.** Freeing a pooled node defeats the point; call Despawn to return it.
- **Reset a node's state on spawn** (health, velocity, animation) - a reused node still has its old
  values.
- **Prewarm to the size of your worst burst** so the first heavy moment is already smooth.
- **Spawn returns the node** - capture it into a variable to position and configure it.
- **Only Despawn nodes that came from a pool** - Despawn ignores anything the pool did not hand out.
- **Create the pool once** (on ready or at load), not every frame.
- **Clear Pool actually frees** its nodes; use it only when the pool is truly finished, not between
  waves (use Despawn All for that).
