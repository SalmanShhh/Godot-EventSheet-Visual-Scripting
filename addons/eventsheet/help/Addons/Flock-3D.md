# Flock 3D - Birds, Fish And Swarms That Steer By Their Neighbours In 3D

Flock 3D is the Flock pack's twin for a `Node3D`, word for word, in metres instead of pixels. You
attach a `Flock3DBehavior` under every bird, fish or drone that should move together, and each one
steers by the members around it with **separation** (keep apart from the ones too close),
**alignment** (fly the way the neighbours fly) and **cohesion** (drift toward their middle), and flees
anything in an **avoid group**. Weights, speeds, the steering force and both radii are Inspector
values with a Set row each.

The two things that differ from 2D: the host turns to LOOK along its flight - Godot's forward, `-Z` -
instead of rotating in the plane, and the flock is free to climb and dive, so a school of fish is a
real three-dimensional ball.

---

## Where this pack shines

- **Underwater scenes.** Schools of fish that turn as one and open around the diver.
- **Open skies.** Birds over a valley, gulls around a harbour, crows over a field.
- **Drone swarms.** Enemy drones that surround the player as a cloud, not a queue.
- **Space dogfights.** Wingmen and fighter wings that hold a loose formation in all three axes.
- **Insects and particles.** Gnats, fireflies and embers that drift together around a light.

---

## Setup

1. Build one member: a `Node3D` (or a `CharacterBody3D` if walls and the floor should stop it) with
   its model facing `-Z`, which is Godot's forward.
2. Add a `Flock3DBehavior` as its child. The parent becomes the host.
3. Leave **Flock Group** at `flock`, or name the flock. The host joins that group by itself when it
   enters the scene.
4. Make **Separation Radius** a little more than the model's width - it is what keeps members apart.
5. Instance the scene a dozen times. A member placed without a velocity sets off along its own
   forward, so turn the instances in the editor and the flock leaves the way you pointed it.

```
On Ready -> Fish | Flock 3D: Set Avoid Group  "divers", 5, 3
```

---

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, node references in
*italic*, exactly as the rows draw them:

- flock with separation **separation**, alignment **alignment**, cohesion **cohesion**
- fly between **minimum** and **maximum** m/s
- steer with at most **force** force
- see neighbours within **neighbours**, keep **too_close** apart
- flee **group** within **radius**, weight **weight**
- fly with the **group** flock
- Set flocking to **enabled**

### Actions

| Action | Parameters | Description |
|---|---|---|
| Set Flock Weights | `separation`, `alignment`, `cohesion` (float) | How strongly each rule pulls. Zero switches a rule off; a weight only means something next to the other two. |
| Set Flock Speeds | `minimum`, `maximum` (float) | The slowest and fastest a member flies, in metres per second. A maximum below the minimum is raised to it. |
| Set Max Force | `force` (float) | How quickly a member may change its velocity, in metres per second per second, for each rule. |
| Set Flock Radii | `neighbours`, `too_close` (float) | How far a member looks for neighbours, and how close one may come before separation pushes it away. |
| Set Avoid Group | `group` (StringName), `radius`, `weight` (float) | The group the flock flees, how close it must come, and how hard the flock flees it. An empty group avoids nothing. |
| Set Flock Group | `group` (StringName) | Moves the host to another flock in one step, so it is never counted by both. |
| Set Flocking Enabled | `enabled` (bool) | Turns the steering on or off. Off, the host keeps still and the behaviour costs nothing per frame. |

### Inspector properties

| Property | Default | What it does |
|---|---|---|
| `flock_group` | `flock` | The group whose members fly together. |
| `neighbour_radius` | `4` | How far a member looks for neighbours, in metres. |
| `separation_radius` | `1.2` | Closer than this, separation pushes away. |
| `separation_weight` / `alignment_weight` / `cohesion_weight` | `1.5` / `1` / `1` | How strongly each rule pulls. |
| `min_speed` / `max_speed` | `2` / `6` | The speed band, in metres per second. |
| `max_force` | `12` | The most one rule may change the velocity per second. |
| `avoid_group` | empty | A group to flee. |
| `avoid_radius` / `avoid_weight` | `5` / `3` | How close a threat must be, and how hard the flock flees it. |
| `face_heading` | `true` | Turns the host to look along its flight. Flying straight up or down keeps the facing it had. |
| `flocking_enabled` | `true` | Master switch. |

`flock_velocity` is the member's velocity right now, in metres per second, and the steering works
exactly as in the 2D pack: three wishes, each capped at max force, weighted, added, and clamped
between the two speeds. A `CharacterBody3D` host moves with `move_and_slide`; any other `Node3D` is
moved along its velocity.

---

## Use cases

### 1. A school of fish

Instance the fish scene forty times inside a reef. They find each other and become one turning ball.

### 2. Fish that part around the diver

```
On Ready -> Fish | Flock 3D: Set Avoid Group  "divers", 4, 4
```

### 3. A bait ball

Turn cohesion up and alignment down (`Set Flock Weights 1.2, 0.3, 2`) and the school tightens into a
churning sphere - perfect for a shark to cut through.

### 4. Birds over a valley

Wide radii and low force (`Set Max Force 4`) give long, sweeping turns that read as distance.

### 5. Drones that surround the player

Put the player, a CharacterBody3D, in the drones' flock group. Cohesion pulls them toward what they
can see, the player included, and separation keeps them in a shell around it.

### 6. Wingmen in a dogfight

The escorts share a flock group with the player's ship; higher separation keeps them out of its way
while alignment keeps them flying its direction.

### 7. A shark through the school

The shark is in the `predators` group. With the avoid weight at 3 the school splits around it and
re-forms behind.

### 8. Gnats around a lantern

Put the lantern itself in the gnats' group. It stands still, so cohesion draws them in and separation
keeps them circling.

### 9. Diving gulls

```
On Ready -> Gull | Flock 3D: Set Avoid Group  "boats", 6, 2
```

Gulls wheel above the harbour and scatter whenever a boat comes close.

### 10. Two flocks in one sky

`crows` and `starlings` as two flock groups fly through one another without merging.

### 11. A swarm that wakes up

```
On Body Entered (Hive Area) -> Bee | Flock 3D: Set Flocking Enabled  true
```

Untick **Flocking Enabled** in the Inspector and the bees sit still on the hive, costing nothing,
until the player comes close.

### 12. Panic

```
On Explosion -> Bird | Flock 3D: Set Flock Speeds  6, 14
Wait 2 seconds -> Bird | Flock 3D: Set Flock Speeds  2, 6
```

### 13. A murmuration that breathes

```
Every 5 seconds -> Bird | Flock 3D: Set Flock Weights  1.5, random(0.3, 1.5), random(0.6, 1.4)
```

### 14. Recruiting a stray

```
On Body Entered (Flock Area) -> Stray | Flock 3D: Set Flock Group  "flock"
```

### 15. Embers above a campfire

Low speeds (`Set Flock Speeds 0.2, 0.6`) and wide separation spread the embers into a loose glowing
cloud rising off the fire.

### Other use cases

**Space debris.** High separation and no alignment space wreckage evenly through a field.

**Jellyfish.** Very low force and speed make a slow, pulsing drift.

**Menu fly-by.** A dozen paper planes flocking past the title camera.

**Fireflies in a forest.** Several small flocks with their own groups, each round its own lantern.

**Ghost swarm.** A swarm of wisps that flees the player's torch through the avoid group.

---

## Tips and common mistakes

- **Separation radius is the overlap dial.** A little more than the model's width keeps members apart.
- **Model the member facing -Z.** Face Heading looks along the velocity with Godot's forward.
- **A flock is free in all three axes.** If birds should stay above the ground, give them a
  CharacterBody3D host and a floor, or keep them over something tall enough.
- **For hundreds of members, use one script.** Every member looks at every other member of its group
  each physics frame, which is right for tens. For a huge school, draw it with one
  `MultiMeshInstance3D` and steer all of it from one script holding the positions and velocities in
  two packed arrays, writing `multimesh.set_instance_transform(index, transform)` per fish.
