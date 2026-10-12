# Flock - Birds, Fish And Swarms That Steer By Their Neighbours

Flock is a Godot EventSheets behavior pack that makes a group of 2D nodes move as one. You attach a
`FlockBehavior` under every bird, fish, bat or drone that should fly together, and each one steers by
the members around it with the three classic rules: **separation** (keep apart from the ones too
close), **alignment** (fly the way the neighbours fly) and **cohesion** (drift toward their middle).
A fourth push, the **avoid group**, makes the whole flock scatter from a predator, the player or a
hazard. Weights, speeds, the steering force and both radii are Inspector values, and each has a Set
row so a sheet can retune the flock while the game runs.

Nothing else in the vocabulary steers by neighbours. Push Group Away From pushes a group away from
one point, Pull Group Toward pulls it to one node, and Average In Group cannot average positions, so
a flock written as rows would be a loop over the group inside a loop over the group. This pack is
that loop, written once.

---

## Where this pack shines

- **Ambient life.** A sky of birds, a pond of fish, a cave of bats - scenery that moves like it is
  alive and needs no animation.
- **Swarming enemies.** Bees, piranhas and drones that surround the player as a body instead of
  stacking on one pixel.
- **Crowds that part.** Put the player in the avoid group and the crowd flows around them.
- **Escorts and wingmen.** A handful of ships that hold a loose formation without a formation system.
- **Particles with opinions.** Fireflies, embers and spores that drift together and react to a lamp.
- **Herds and schools.** Sheep that bunch up when the dog runs at them, and spread out to graze when it
  leaves.

---

## Setup

1. Build one member: a `Node2D` (or a `CharacterBody2D` if walls should stop it) with its sprite
   pointing RIGHT, which is Godot's angle zero.
2. Add a `FlockBehavior` as its child. The parent becomes the host.
3. Leave **Flock Group** at `flock`, or name the flock - `starlings`, `piranhas`. The host joins that
   group by itself when it enters the scene; you do not add it by hand.
4. Make **Separation Radius** a little more than the sprite's width. That one number is what keeps
   members from overlapping.
5. Save it as a scene and instance it a dozen times, or spawn it from a row. Every copy is one more
   member of the same flock.

A member placed without a velocity sets off the way it faces, so rotate the instances in the editor
and the flock leaves in the direction you drew. With **Face Heading** on (the default) each member
then turns to face where it flies.

```
On Ready            -> Bird | Flock: Set Avoid Group  "hawks", 160, 3
Every 4 seconds     -> Bird | Flock: Set Flock Weights  1.5, 1, random(0.5, 1.5)
```

---

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, node references in
*italic*, exactly as the rows draw them:

- flock with separation **separation**, alignment **alignment**, cohesion **cohesion**
- fly between **minimum** and **maximum** px/s
- steer with at most **force** force
- see neighbours within **neighbours**, keep **too_close** apart
- flee **group** within **radius**, weight **weight**
- fly with the **group** flock
- Set flocking to **enabled**

### Actions

| Action | Parameters | Description |
|---|---|---|
| Set Flock Weights | `separation`, `alignment`, `cohesion` (float) | How strongly each rule pulls. Zero switches a rule off; a weight only means something next to the other two. |
| Set Flock Speeds | `minimum`, `maximum` (float) | The slowest and fastest a member flies, in pixels per second. A maximum below the minimum is raised to it; a negative minimum is read as zero. |
| Set Max Force | `force` (float) | How quickly a member may change its velocity, in pixels per second per second, for each rule. A negative force is read as zero. |
| Set Flock Radii | `neighbours`, `too_close` (float) | How far a member looks for neighbours, and how close one may come before separation pushes it away. |
| Set Avoid Group | `group` (StringName), `radius`, `weight` (float) | The group the flock flees, how close it must come before the flock reacts, and how hard it flees. An empty group avoids nothing. |
| Set Flock Group | `group` (StringName) | Moves the host to another flock in one step: it leaves the old group and joins the new, so it is never counted by both. |
| Set Flocking Enabled | `enabled` (bool) | Turns the steering on or off. Off, the host keeps still and the behaviour costs nothing per frame. |

### Inspector properties

| Property | Default | What it does |
|---|---|---|
| `flock_group` | `flock` | The group whose members fly together. The host joins it on entering the scene. |
| `neighbour_radius` | `120` | How far a member looks for neighbours, in pixels. |
| `separation_radius` | `40` | Closer than this, separation pushes away - harder the closer it is. |
| `separation_weight` / `alignment_weight` / `cohesion_weight` | `1.5` / `1` / `1` | How strongly each rule pulls. |
| `min_speed` / `max_speed` | `60` / `180` | The speed band, in pixels per second. |
| `max_force` | `360` | The most one rule may change the velocity per second. |
| `avoid_group` | empty | A group to flee. Empty avoids nothing. |
| `avoid_radius` / `avoid_weight` | `160` / `3` | How close a threat must be, and how hard the flock flees it. |
| `face_heading` | `true` | Turns the host to face the way it flies. |
| `flocking_enabled` | `true` | Master switch. |

`flock_velocity` is the velocity the member flies at right now, in pixels per second. Neighbours read
it to align, and an expression can read it too - `$FlockBehavior.flock_velocity.length()` is the
member's speed.

### How a member steers

Every physics frame each member looks at the members of its flock group inside the neighbour radius
and works out three wishes, each one "fly that way at full speed": away from the neighbours inside the
separation radius, the way the neighbours fly on average, and toward their middle. Each wish becomes a
change of velocity no bigger than **max force**, is multiplied by its weight, and they are added up.
Anything from the avoid group inside the avoid radius adds a fourth wish, multiplied by the avoid
weight. The result is applied over the frame and clamped between the two speeds.

A `CharacterBody2D` host moves with `move_and_slide`, so walls stop it the way they stop anything else.
Any other `Node2D` host is moved along its velocity. A neighbour carrying the same behaviour reports
its flock velocity; a `CharacterBody2D` or `RigidBody2D` placed in the group by hand reports its own
velocity, so the player can fly WITH a flock just by joining its group.

---

## Use cases

### 1. A sky of starlings

Instance the bird scene thirty times across the top of the level. Nothing else: they find each other
and become one murmuration.

### 2. Fish that scatter from the player

```
On Ready -> Fish | Flock: Set Avoid Group  "player", 140, 4
```

Put the diver in the `player` group. The school opens around them and closes again behind.

### 3. A swarm that hunts

Add the player to the swarm's own flock group as a CharacterBody2D. Cohesion pulls every bee toward
the middle of what it can see - and the player is part of what it can see - so the swarm closes in
without a single chase row.

### 4. Bats that burst out of a cave

```
On Area Entered (Cave Mouth) -> Bat | Flock: Set Flock Speeds  200, 360
                             -> Bat | Flock: Set Max Force  900
Wait 1.5 seconds             -> Bat | Flock: Set Flock Speeds  60, 180
```

A high force and speed for a moment is a panic; dropping them back is the colony settling.

### 5. Sheep and the dog

```
On Ready -> Sheep | Flock: Set Avoid Group  "dog", 120, 5
```

Low alignment and a weak cohesion (`Set Flock Weights 2, 0.3, 0.6`) make a loose herd that drifts
while grazing, and bunches hard the moment the dog runs at it.

### 6. Wingmen

Three escort ships share a flock group with the player's ship, which is a CharacterBody2D. Turn the
escorts' separation up so they keep a respectful distance, and they fly in the player's wake.

### 7. A predator that splits the flock

The hawk is in the `hawks` group and flies straight through the middle. With the avoid weight at 3 the
flock splits in two around it and, because cohesion still holds, joins up again behind.

### 8. Fireflies around a lamp

Put the lamp itself in the fireflies' group (Node dock, Groups). A plain node in the group is a
neighbour that stands still, so cohesion draws the fireflies toward it and separation keeps them in a
lazy ring around it.

### 9. A flock that changes its mind

```
Every 6 seconds -> Bird | Flock: Set Flock Weights  1.5, random(0.2, 1.5), random(0.5, 1.5)
```

Alignment and cohesion wandering over time is what makes a murmuration fold and stretch.

### 10. Two schools that ignore each other

Name the flock groups `red_fish` and `blue_fish`. Each school steers only by its own kind, and they
swim through one another.

### 11. Recruiting a stray

```
On Body Entered (Flock Area) -> Stray | Flock: Set Flock Group  "flock"
```

A lone bird joins the flock it flew into, and leaves its old group in the same row.

### 12. Freezing for a cutscene

```
On Cutscene Started  -> Bird | Flock: Set Flocking Enabled  false
On Cutscene Finished -> Bird | Flock: Set Flocking Enabled  true
```

Off, the members hold still and cost nothing; on again, they fly off at the velocity they had.

### 13. Crowd flow in a station

Commuters as CharacterBody2D members with a low max speed and no alignment
(`Set Flock Weights 2, 0, 0.4`) shuffle along without walking through each other. Put the player in
the avoid group with a small radius and they step aside.

### 14. Swarm intensity on a difficulty slider

```
On Difficulty Changed -> Drone | Flock: Set Flock Speeds  80 * difficulty, 160 * difficulty
                      -> Drone | Flock: Set Max Force  300 * difficulty
```

Faster, sharper turners are a harder swarm, with no new enemy type.

### 15. Spores that drift on the wind

Keep the speeds low (`Set Flock Speeds 10, 30`) and the radii wide. Separation spreads the spores
evenly through the air, which reads as a gentle cloud rather than a clump.

### 16. Leaving a trail

Read `$FlockBehavior.flock_velocity` in a row that spawns a feather or a bubble behind each member
every half second; the trail points the way the flock is really flying.

### Other use cases

**Flies around a corpse.** Put the body itself in the flies' group, and a few members with a small
neighbour radius buzz round it in a tight, restless cloud.

**Asteroid belt shepherds.** Small moons with high separation and no alignment space themselves evenly
around a ring.

**Menu background.** A dozen paper planes flocking behind the title screen make it feel alive for the
cost of one scene instanced twelve times.

**Rhythm-game birds.** Retune the weights on the beat, and the flock pulses with the music.

**Bullet-hell drones.** Drones that flock around the boss form shifting walls the player has to read.

---

## Tips and common mistakes

- **Separation radius is the overlap dial.** Make it a little more than the sprite's width and
  members do not overlap; make it smaller than the sprite and they will.
- **The neighbour radius is the "how big is a flock" dial.** Members further apart than it never see
  each other, so a flock spread wider than it breaks into several flocks - which is often what a sky
  of birds should do.
- **Weights are relative.** Doubling all three changes nothing but how fast the flock reacts; it is
  the ratios that shape it. Keep the avoid weight above the others so fear wins.
- **Draw the sprite facing right.** Face Heading turns the host to its velocity's angle, and angle
  zero is right in Godot.
- **A flock drifts.** Nothing keeps it on screen. Attach the Wrap pack to each member, or give the
  flock something to gather around (use case 8).
- **For hundreds of members, use one script instead.** Every member here looks at every other member
  of its group each physics frame, which is right for tens of birds and too much for a thousand. For
  a huge flock, draw it with one `MultiMeshInstance2D` and steer all of it from one script that keeps
  the positions and velocities in two packed arrays and writes each instance's transform with
  `multimesh.set_instance_transform_2d(index, Transform2D(velocity.angle(), position))`.
