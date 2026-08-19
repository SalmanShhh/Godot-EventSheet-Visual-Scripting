# Groups, Tags And Systems

A Godot **group** is just a name you can stick on any node. That is all it is - and it turns out to be
enough to build most of what people reach for an entity system to do. This builtin vocabulary treats a
group as a **tag** (add it, remove it, ask about it), as a **set** (count it, total it, average it,
find its extremes) and as a **system** (call one method on every member, or on every member that also
carries a second tag).

The whole family compiles to plain `add_to_group` / `is_in_group` / `get_nodes_in_group` calls with a
`reduce` or a `filter` where a roll-up is needed. Nothing here is a framework: it is node iteration
spelled out as rows, which is why the guidance below keeps saying "keep the group small and prefer a
trigger over polling".

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Reference tables](#reference-tables)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Tagging by kind** - `enemies`, `pickups`, `doors`, `checkpoints`.
- **Tagging by state** - `poisoned`, `stunned`, `burning`, added and removed as the state changes.
- **Counting a wave** - Count Nodes In Group is the "are they all dead yet" check.
- **Team health bars** - Sum In Group and Average In Group across a squad, with no loop.
- **Broadcast commands** - Call Method On Group tells every enemy to reset at once.
- **Damage over time** - Run On Tagged Entities ticks only the burning ones.
- **Archetype queries** - Entities In Both Groups is "alive AND poisoned" in one expression.
- **Decoupled level scripting** - a lever that calls `open` on the `gates` group without knowing a
  single node path.
- **Difficulty and mode switches** - Set Group Active turns a whole section of the sheet on or off.

## Core concepts

- **A group is a tag, and tags are cheap.** A node can be in as many groups as you like. Add To Group
  and Remove From Group are ordinary actions, so `poisoned` can go on and come off during play exactly
  like a status effect.
- **Two conditions ask "is this node tagged".** **Is In Group** takes a Target, so it can ask about any
  node. **Has Group Member** always asks about the node the sheet is on, which is the common case and
  reads better in a condition row.
- **A roll-up is a reduce, not a loop.** Sum In Group, Average In Group, Lowest In Group and Highest
  In Group each compile to one `reduce` over `get_nodes_in_group`. There is no For Each to write and
  no accumulator variable to declare.
- **Sum and Average start from zero; Lowest and Highest start from infinity.** That is what keeps an
  empty group from erroring - but it also means an empty group answers `INF` or `-INF` for the
  extremes rather than something friendly. Gate on the count when that matters.
- **A broadcast can carry a value.** Call Method On Group calls a bare method on every member. Call
  Method On Group (with value) passes arguments along, which is what turns a broadcast into a real
  message ("take 10 damage") instead of just a ping.
- **A system is a group plus a method.** Run On Tagged Entities loops one group, keeps only the
  members that are ALSO in a second group, checks that they have the method, and calls it. That is a
  complete system in one action row.
- **An archetype is an intersection.** Entities In Both Groups, Count In Both Groups, First In Both
  Groups and Is In Both Groups answer "has both tags", which is the composition equivalent of "has
  both components".
- **Set Group Active is about SHEET groups, not scene-tree groups.** It flips the runtime-toggle flag
  a sheet's own event group ships, addressed by the snake-cased group name. It has nothing to do with
  `add_to_group`, and mixing the two up is the single most common confusion in this family.

## Reference tables

Group name parameters use the group picker, so the editor offers the groups your project already
uses. Every `{target}` defaults to `self`.

### Tagging and asking

| Name | What it does | Ships as |
|------|--------------|----------|
| Add To Group | Tags a node into a named group | `{target}.add_to_group({group})` |
| Remove From Group | Untags a node from a named group | `{target}.remove_from_group({group})` |
| Is In Group | True when the given node belongs to the group | `{target}.is_in_group({group})` |
| Has Group Member | True when THIS node belongs to the named group | `is_in_group(&{group})` |
| Get First Node In Group | The first node found in a group, or nothing | `get_tree().get_first_node_in_group({group})` |
| Count Nodes In Group | How many nodes are in the group right now | `get_tree().get_node_count_in_group({group})` |

### Roll-ups over a group

Each takes a Group and a `Property` - a bare numeric member such as `health`.

| Name | What it does | Ships as |
|------|--------------|----------|
| Sum In Group | Totals a numeric property across every member | `get_tree().get_nodes_in_group({group}).reduce(func(__acc, __n): return __acc + __n.{property}, 0.0)` |
| Average In Group | The average of that property across the group | the same reduce, divided by `maxf(float(size()), 1.0)` |
| Lowest In Group | The smallest value among the members | `...reduce(func(__acc, __n): return min(__acc, __n.{property}), INF)` |
| Highest In Group | The largest value among the members | `...reduce(func(__acc, __n): return max(__acc, __n.{property}), -INF)` |

### Broadcasting

| Name | What it does | Ships as |
|------|--------------|----------|
| Call Method On Group | Calls a method on every node in the group | `get_tree().call_group({group}, {method})` |
| Call Method On Group (with value) | The same, carrying one or more values | `get_tree().call_group({group}, {method}{, args})` |
| Run On Tagged Entities | Calls a method on every group member that also has a tag | see below |

**Run On Tagged Entities** takes a Group (the entity type), an `Also In` tag and a Method:

```gdscript
for __entity_figure: Node in get_tree().get_nodes_in_group("enemies"):
	if __entity_figure.is_in_group("stunned") and __entity_figure.has_method("tick"):
		__entity_figure.call("tick")
```

### Archetype queries

| Name | What it does | Ships as |
|------|--------------|----------|
| Entities In Group | Every node in a group, as an array | `get_tree().get_nodes_in_group({group})` |
| Any Entity In Group | True when at least one node is in the group | `not get_tree().get_nodes_in_group({group}).is_empty()` |
| Entities In Both Groups | Every node in BOTH groups, as an array | `get_tree().get_nodes_in_group({group_a}).filter(func(__entity: Node) -> bool: return __entity.is_in_group({group_b}))` |
| Count In Both Groups | How many nodes are in both groups | the same filter, plus `.size()` |
| First In Both Groups | The first node in both groups, or nothing | the same filter, plus `.front()` |
| Is In Both Groups | True when one entity belongs to both groups | `({node}.is_in_group({group_a}) and {node}.is_in_group({group_b}))` |

### Sheet event groups

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Group Active | Turns a runtime-toggleable sheet group on or off | `set("__group_" + {group} + "_active", {active})` |
| Is Group Active | True when that named runtime group is switched on | `bool(get("__group_" + {group} + "_active"))` |

## Use cases

**1. Tag a node the moment it exists.**

```gdscript
func _ready() -> void:
	add_to_group("enemies")
```

**2. Tag by STATE, and untag when it wears off.** This is what makes a tag a status effect.

```gdscript
func _on_poison_applied() -> void:
	add_to_group("poisoned")


func _on_poison_expired() -> void:
	remove_from_group("poisoned")
```

**3. Is the wave cleared?** Count Nodes In Group without touching a single node.

```gdscript
func _process(delta: float) -> void:
	if get_tree().get_node_count_in_group("enemies") == 0:
		_start_next_wave()
```

**4. Ask a node about itself.** Has Group Member reads as a plain condition on the sheet's own host.

```gdscript
func _on_body_entered(body: Node) -> void:
	if is_in_group(&"player"):
		_open()
```

**5. Ask about somebody else.** Is In Group takes the target, so a bullet can check what it hit.

```gdscript
func _on_hit(other: Node) -> void:
	if other.is_in_group("enemies"):
		other.call(&"take_damage", 10)
```

**6. Grab the player from anywhere, without a path.**

```gdscript
func _process(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		global_position = global_position.move_toward(player.global_position, 60.0 * delta)
```

**7. A squad health bar.** Sum In Group across the party.

```gdscript
func _process(delta: float) -> void:
	$PartyBar.value = get_tree().get_nodes_in_group("party").reduce(func(__acc, __n): return __acc + __n.health, 0.0)
```

**8. Average enemy health, to pick a difficulty tier.**

```gdscript
func _on_tier_check() -> void:
	var mean = (get_tree().get_nodes_in_group("enemies").reduce(func(__acc, __n): return __acc + __n.health, 0.0) / maxf(float(get_tree().get_nodes_in_group("enemies").size()), 1.0))
	_tier = 2 if mean > 60.0 else 1
```

**9. Find the weakest link.** Lowest In Group over `health`, guarded on the count so an empty group
never leaks `INF` into your UI.

```
Every second
  Condition: Count Nodes In Group  "party"  > 0
    -> set WeakestLabel text = str(Lowest In Group("party", health))
```

**10. Highest score wins.** The same shape, the other way round.

```gdscript
func _on_round_ended() -> void:
	$Winner.text = "Best: %d" % get_tree().get_nodes_in_group("players").reduce(func(__acc, __n): return max(__acc, __n.score), -INF)
```

**11. Reset every enemy at once.** One broadcast instead of a loop and a path.

```gdscript
func _on_restart() -> void:
	get_tree().call_group("enemies", "reset")
```

**12. Broadcast WITH data.** Every member of the group takes 25 damage.

```gdscript
func _on_shockwave() -> void:
	get_tree().call_group("enemies", "take_damage", 25)
```

**13. A pull-lever, open-all-gates puzzle.** Nothing in the lever knows a single gate.

```gdscript
func _on_lever_pulled() -> void:
	get_tree().call_group("gates", "open")
```

**14. Damage over time as a system.** Only the entities that are enemies AND burning tick.

```gdscript
func _on_burn_tick() -> void:
	for __entity_burn: Node in get_tree().get_nodes_in_group("enemies"):
		if __entity_burn.is_in_group("burning") and __entity_burn.has_method("take_burn"):
			__entity_burn.call("take_burn")
```

**15. Count the archetype for a HUD.** "3 poisoned" without looping anything yourself.

```gdscript
func _process(delta: float) -> void:
	$Status.text = "%d poisoned" % get_tree().get_nodes_in_group("enemies").filter(func(__entity: Node) -> bool: return __entity.is_in_group("poisoned")).size()
```

**16. Find the boss.** First In Both Groups is "the first enemy that is also a boss".

```gdscript
func _on_arena_started() -> void:
	_boss = get_tree().get_nodes_in_group("enemies").filter(func(__entity: Node) -> bool: return __entity.is_in_group("boss")).front()
```

**17. Gate an effect on two tags at once.** Is In Both Groups asks about one node.

```gdscript
func _on_cure_used(target: Node) -> void:
	if (target.is_in_group("party") and target.is_in_group("poisoned")):
		target.remove_from_group("poisoned")
```

**18. Do nothing until there is something to do.** Any Entity In Group is cheaper to read than a
count comparison and says what it means.

```gdscript
func _process(delta: float) -> void:
	if not get_tree().get_nodes_in_group("enemies").is_empty():
		_play_combat_music()
```

**19. Run a system over an entity type.** Entities In Group hands the array to a For Each row.

```gdscript
func _physics_process(delta: float) -> void:
	for entity in get_tree().get_nodes_in_group("floaters"):
		entity.position.y += sin(Time.get_ticks_msec() / 400.0) * 0.4
```

**20. Turn a whole section of the sheet off.** Set Group Active flips a runtime-toggleable sheet
group, so combat logic stops being evaluated during a cutscene.

```gdscript
func _on_cutscene_started() -> void:
	set("__group_" + "combat" + "_active", false)
```

**21. Ask whether that section is running.**

```gdscript
func _process(delta: float) -> void:
	$Debug.text = "combat: %s" % str(bool(get("__group_" + "combat" + "_active")))
```

### Other use cases

**Aggro rings.** Add To Group on entering a detection area and Remove From Group on leaving it, then Count In Both Groups tells the director how many enemies are currently engaged.

**Save-relevant objects.** One `persist` tag on everything the save system should walk turns "what do I write out" into a single group query rather than a hand-maintained list.

**Crowd chatter budget.** Highest In Group over a `chatter_priority` property picks the one NPC allowed to speak this second, so a busy market never overlaps ten voice lines.

**Mode-specific rules.** Tag every hazard `hardcore` at load time on the highest difficulty and leave it off otherwise, then a single Run On Tagged Entities row applies the extra behaviour with no branching sheet.

**Team scoring.** Sum In Group over each team's group, once per round end, replaces a pair of score variables that always drift apart from what is actually on the field.

## Tips and common mistakes

- **Set Group Active is not about scene-tree groups.** It writes a runtime flag for a sheet's own
  event group (`__group_<name>_active`) and only works on groups that opted into runtime toggling. If
  you called Add To Group with `"combat"` and then Set Group Active with `"combat"`, they are two
  completely unrelated things.
- **The sheet-group name is snake-cased.** Set Group Active and Is Group Active both take the group's
  snake-cased name, so an event group called "Combat Rules" is addressed as `combat_rules`.
- **A group added without `persistent` disappears when a scene is packed.** `add_to_group(name)` alone
  is not saved with a `PackedScene`, so a group tagged in a builder or tool script silently vanishes
  and every later group check quietly never fires. Tag at runtime in a ready handler, or pass the
  persistent flag when you write the call yourself.
- **Lowest and Highest answer INF on an empty group.** The seeds are `INF` and `-INF` so the reduce
  cannot error. Guard the row with Count Nodes In Group when the number reaches a UI.
- **Average In Group divides by at least 1.** An empty group answers 0.0, not a division error - but
  that 0.0 is indistinguishable from a real average of zero. Again, check the count first.
- **The roll-ups read a BARE property.** `health`, not `"health"`. A member that lacks the property
  errors at runtime, so keep the group homogeneous, or roll up over a narrower tag.
- **Call Method On Group is fire and forget.** It returns nothing and reports nothing. A member that
  does not have the method simply does not respond. When "did anyone answer" matters, loop the group
  yourself and check.
- **Leave the Value blank for a no-argument call.** Call Method On Group (with value) drops the comma
  cleanly when the Value parameter is empty, so you do not need to switch back to the plain action.
- **Run On Tagged Entities checks `has_method` for you.** That is deliberate: a mixed group will not
  crash. It also means a typo in the Method name fails completely silently, so verify the spelling
  when a system quietly does nothing.
- **This is composition, not an ECS.** Every one of these rows walks a node array. It is fast enough
  for hundreds of nodes and wrong for tens of thousands. Prefer triggers over per-frame polling for
  large sets, and keep group sizes reasonable.
- **Get First Node In Group has no defined order.** It is "one of them", not "the oldest". Use a
  dedicated group with exactly one member (`player`) when identity matters.
