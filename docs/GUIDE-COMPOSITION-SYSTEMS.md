# Composition and systems (ECS-lite)

Big games get their flexibility from **composition**: an entity is not a deep class hierarchy, it is a
bag of small, reusable parts. "This thing is an enemy, and it is poisoned, and it is on fire" instead of
a `PoisonedBurningEnemy` class. Event sheets already give you every piece you need to work this way
without a separate framework - **groups are your components**, **a group is a set of entities**, and **a
sheet that runs over a group each frame is a system**. This guide shows the pattern, the convenience
verbs that make it read well, and - just as important - when NOT to reach for it.

This is "ECS-lite", not a real Entity Component System. It is plain node iteration over groups, so it
composes with everything else in the plugin and compiles to the exact Godot you would hand-write. It is
not data-oriented and it will not out-perform a purpose-built ECS on tens of thousands of entities. What
it buys you is the *mental model* - entities, tags, systems - at zero framework cost.

## Table of Contents

1. [The three ideas](#1-the-three-ideas)
2. [Entities are nodes in a group](#2-entities-are-nodes-in-a-group)
3. [Components are tags (extra groups)](#3-components-are-tags-extra-groups)
4. [Systems are sheets that run over a group](#4-systems-are-sheets-that-run-over-a-group)
5. [The Systems vocabulary](#5-the-systems-vocabulary)
6. [Archetypes: entities in two groups at once](#6-archetypes-entities-in-two-groups-at-once)
7. [Worked example: a status-effect system](#7-worked-example-a-status-effect-system)
8. [Performance: the honest guidance](#8-performance-the-honest-guidance)
9. [When NOT to use this](#9-when-not-to-use-this)

## 1. The three ideas

| Concept | In an ECS | Here (ECS-lite) |
|---|---|---|
| Entity | an id | a node |
| Component | data struct on the id | membership in a group (a tag), plus fields on the node |
| System | code that runs over entities with certain components | a sheet (usually an autoload) that iterates a group each frame |

That is the whole translation. You already know groups; you already know sheets. Composition is just
using them deliberately: keep entities light, describe them with tags, and put behaviour in systems that
run over tags rather than in per-entity scripts.

## 2. Entities are nodes in a group

Put every enemy in an `"enemies"` group (in the editor's Node dock, or from a sheet with **Add To
Group**). Now "all enemies" is a single query:

```
System: Entities In Group  "enemies"   -> an array of every enemy node
```

You loop that array with **For Each** to do something to every entity. Nothing is registered, nothing is
bespoke - a node is an entity the moment it joins the group, and it stops being one the moment it leaves
or is freed. That churn-for-free is the point.

## 3. Components are tags (extra groups)

An entity can be in many groups at once, and each extra group reads like a component you have bolted on:

- in `"enemies"` and `"poisoned"` -> an enemy that has the poison component
- in `"enemies"` and `"flying"` -> an enemy that has the flying component

You add and remove these at runtime (**Add To Group** / **Remove From Group**), so "apply poison" is
"join the poisoned group" and "cure" is "leave it". The node's own exported variables (`poison_ticks`,
`speed`) hold the component's *data*; the group membership is the component's *presence*.

This is a deliberately weak component model - a group is a boolean, not a struct, so a component with
several fields lives partly in the group and partly in the node's variables. That is fine for a handful
of components; see [section 9](#9-when-not-to-use-this) for where it stops paying off.

## 4. Systems are sheets that run over a group

A system is a sheet - almost always an **autoload** so it runs once for the whole game - with an
**On Process** (every frame) or **On Timer** (every so often) event that iterates a group and acts on
each member. The **Entity System (Autoload)** starter in the New... menu scaffolds exactly this:

```
On Process
  -> For Each entity in (Entities In Group "enemies")
       -> ... move / damage / update the entity ...
```

Because the system reads the group fresh every frame, it automatically covers entities that spawned or
died since last frame. One sheet drives every enemy; adding a new enemy type is adding a node to the
group, not wiring new events.

Prefer **triggers over polling** where you can. If a system only needs to react when something happens
(an entity took damage, entered an area), a signal-driven event beats scanning the whole group every
frame - see [section 8](#8-performance-the-honest-guidance).

## 5. The Systems vocabulary

The **Systems** section in the ACE picker holds the composition building blocks. They all compile to
plain `get_tree().get_nodes_in_group(...)` and `is_in_group(...)` - no plugin dependency:

| Verb | Kind | What it gives you |
|---|---|---|
| **Entities In Group** | expression | every node in a group, as an array (loop with For Each) |
| **Any Entity In Group** | condition | true if at least one entity of that type exists |
| **Entities In Both Groups** | expression | every node in BOTH groups (an archetype) |
| **Count In Both Groups** | expression | how many are in both groups |
| **First In Both Groups** | expression | the first entity in both groups, or nothing |
| **Is In Both Groups** | condition | test one entity for two tags at once |
| **Run On Tagged Entities** | action | call a method on every entity in a group that also has a tag - a whole system in one row |

**Run On Tagged Entities** is the shortcut when your per-entity step is a single method call. This one
row:

```
System: Run On Tagged Entities   group "enemies"   also in "stunned"   method "recover"
```

compiles to the loop you would otherwise write by hand:

```gdscript
for __entity in get_tree().get_nodes_in_group("enemies"):
    if __entity.is_in_group("stunned") and __entity.has_method("recover"):
        __entity.call("recover")
```

## 6. Archetypes: entities in two groups at once

The query at the heart of composition is "everything that has these components" - an **archetype**. With
tags-as-groups that is "in group A and group B". **Entities In Both Groups** is that intersection:

```
For Each entity in (Entities In Both Groups "enemies" and "poisoned")
  -> entity.take_damage(poison_dps * delta)
```

That system ticks poison damage on exactly the enemies that are poisoned, ignoring the healthy ones and
ignoring poisoned *non*-enemies. Add a third condition inside the loop (**Is In Both Groups**, or a plain
group check) when an archetype needs three tags. Beyond three or four tags the group model gets awkward -
that is the signal you have outgrown ECS-lite.

## 7. Worked example: a status-effect system

A complete, decoupled status system in three small pieces. No status code lives on the enemy.

**The enemy** carries only data and joins `"enemies"` on ready:

```
On Ready
  -> Add self To Group "enemies"
Variables:  health (int, 100),  poison_dps (float, 5.0)
```

**Applying poison** (from a weapon, a trap, anything) is one action - no reference to the enemy's script:

```
On area entered by a poison cloud
  -> Add (the body) To Group "poisoned"
```

**The poison system** (an autoload) ticks every poisoned enemy and cures them when a counter runs out:

```
On Process
  -> For Each e in (Entities In Both Groups "enemies" and "poisoned")
       -> e.health -= e.poison_dps * delta
       -> (optional) count down a timer, then Remove e From Group "poisoned"
```

Want burning too? Copy the system, swap `"poisoned"` for `"burning"`. Want poison to also slow the
enemy? A movement system already reading `"enemies"` checks `Is In Both Groups ... "poisoned"` and halves
speed. Each system is independent, each is a few rows, and the enemy scene never grew a line.

## 8. Performance: the honest guidance

ECS-lite is node iteration. `get_nodes_in_group` allocates and returns an array every call, and you then
loop it. That is cheap for hundreds of entities and fine for a jam or most 2D games; it is not what you
build a bullet-hell with 50,000 particles on. Keep it fast:

- **Trigger, do not poll, when you can.** A system that reacts to an event (signal, area entered, took
  damage) should be a triggered event, not a per-frame group scan. Poll only for things that genuinely
  change every frame (movement, continuous damage).
- **Tick slow things slowly.** A poison tick does not need 60 Hz. Run costly systems on an **On Timer**
  (say 4-10 times a second) instead of **On Process**. Spread heavy per-entity work across frames with the
  Time Slicer pack if a single frame's batch is too big.
- **Query once per frame, not once per entity.** Call **Entities In Group** once and loop the result;
  do not re-query inside the loop.
- **Prefer one combined system over many overlapping scans.** If three systems all iterate `"enemies"`,
  consider one system that does all three things per entity - one scan instead of three.
- **Groups are membership, not storage.** Reading `is_in_group` is fast; do not encode numeric data as
  dozens of groups (`"health_97"`). Numbers live in the entity's exported variables.
- **Measure.** The plugin's Doctor flags unbounded per-frame loops. If a group scan shows up in the
  profiler, move it to a timer or a trigger before optimising anything else.

## 9. When NOT to use this

Composition-via-groups is a mental model with a low ceiling. Reach for something else when:

- **You need real data-oriented performance.** Tens of thousands of entities, cache-friendly iteration,
  archetype storage - that is a job for a dedicated ECS addon or a `MultiMeshInstance` + arrays approach,
  not group scans. ECS-lite will not get you there.
- **Components have lots of fields.** A group is a boolean tag. If "poisoned" carries stacks, source,
  duration, and a tick rate, that data has to live somewhere - on the node, or better, in a small
  **Custom Resource** attached to the entity. At that point you are doing data-driven design; see
  [Data-driven addons](GUIDE-DATA-DRIVEN-ADDONS.md) and [Building a data-driven game](GUIDE-DATA-DRIVEN-GAMES.md).
- **An entity really is one cohesive thing.** A player with tightly-coupled input, camera, and animation
  is clearer as one scene with one script than as five systems reading five groups. Composition earns its
  keep when parts are shared across many entity types, not when you are splitting one entity for its own
  sake.
- **The relationship is one-to-one.** "This bullet belongs to this gun" is a reference, not a group. Use
  a variable that points at the node.

Use ECS-lite for what it is good at - lots of similar entities, behaviours that mix and match, systems
you want to add and remove independently - and drop to plain scenes or full data-driven resources when a
part outgrows a tag. Because it is all just nodes, groups, and sheets, you can mix all three in the same
project without any of them fighting.
