# Working with Lists (Arrays)

A list is the workhorse of game logic: the enemies on screen, the items in a bag, the scores in a run, the waypoints on a patrol. Godot calls them Arrays, and Godot EventSheets gives you the whole Array vocabulary as ordinary picker rows - 37 of them - so you can add, sort, search, slice and join a list without dropping into code.

This guide covers all of it, with the focus on the part people reach for most and find hardest to discover: the **higher-order** verbs (**Filter**, **Map**, **Reduce**, **Any Match**, **All Match**) that run a small test or transform over every element at once, and the **typed-list** verbs for `Array[int]`-style containers.

Everything here compiles to plain, readable GDScript with no plugin dependency at runtime. `list.filter(func(x): return x > 0)` is exactly what ships.

## Table of Contents

1. [Making a list](#making-a-list)
2. [The five higher-order verbs](#the-five-higher-order-verbs)
3. [Naming the element (and why it is a field)](#naming-the-element-and-why-it-is-a-field)
4. [Typed lists](#typed-lists)
5. [Full ACE reference](#full-ace-reference)
6. [Use cases](#use-cases)
7. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Making a list

Add a variable and pick a list type: **Add > Global Variable** (or Local), then choose `Array` in the Type dropdown - or a typed container like `Array[int]`, `Array[float]`, `Array[String]` when every element is the same kind of thing.

Every list verb starts with the same first field, **Array**, and its dropdown only offers list-typed variables in scope. A typed list qualifies wherever a plain `Array` is asked for, so an `Array[int]` can be filtered, sorted and joined like any other.

```
On Ready
  -> Set Variable   scores = []
  -> Append         "scores", 10
  -> Append         "scores", 25
  -> Append         "scores", 7
```

---

## The five higher-order verbs

These take a **small expression you write once** and apply it to every element. They are the difference between a five-row loop and a single readable row.

| Verb | Kind | Answers | Emits |
| --- | --- | --- | --- |
| **Filter** | Expression | "which ones match?" | `scores.filter(func(x): return x > 10)` |
| **Map** | Expression | "what does each become?" | `scores.map(func(x): return x * 2)` |
| **Reduce** | Expression | "what do they add up to?" | `scores.reduce(func(acc, x): return acc + x, 0)` |
| **Any Match** | Condition | "is there at least one?" | `scores.any(func(x): return x > 10)` |
| **All Match** | Condition | "are they all?" | `scores.all(func(x): return x > 10)` |

**Filter** keeps the elements your test says yes to, and hands back a **new list** - the original is untouched:

```
-> Set Variable  survivors = Filter(enemies, where: x.health > 0)
```

**Map** turns each element into something else, again as a new list:

```
-> Set Variable  names = Map(enemies, to: x.name)
```

**Reduce** folds the whole list into a single value. It has two names in play: the running result (`acc`, starting at the **Starting value**) and the current element (`x`):

```
-> Set Variable  total = Reduce(scores, combine: acc + x, from: 0)
-> Set Variable  best  = Reduce(scores, combine: max(acc, x), from: 0)
```

**Any Match** and **All Match** are conditions, so they sit in the left lane and gate the actions beside them:

```
On check wave
  Any Match  "enemies", where: x.is_boss
    -> Play music  "boss_theme"

On check party
  All Match  "party", where: x.health > 0
    -> Show text  "Everyone survived."
```

The test or transform goes in an `ƒx` field, so it is ordinary GDScript over one element: `x > 10`, `x.alive`, `x.name`, `x.health < 50`, `str(x)`, `x * 2`.

---

## Naming the element (and why it is a field)

Each of the five verbs has an **Element name** field, pre-filled with `x` (Reduce also has **Accumulator name**, pre-filled with `acc`). Most of the time you never touch it - you write `x > 10` and move on.

It is a field rather than a fixed word for one reason: if your sheet already has a variable called `x`, a baked-in name would quietly **shadow** it. Your row would compile without a warning and silently compare against the element instead of your variable. Renaming the element removes the collision:

```
Element name: item          predicate: item > x
  emits ->  arr.filter(func(item): return item > x)
```

Now `item` is the element and `x` is still your own variable. Rename it to whatever reads best for the list you are working with - `enemy`, `item`, `row`, `n`.

---

## Typed lists

A typed list (`Array[int]`, `Array[String]`, `Array[Node]`) refuses elements of the wrong type, which turns a whole class of bug into an immediate error. Four verbs work with them at runtime:

| Verb | Kind | What it gives you |
| --- | --- | --- |
| **Is Typed** | Condition | True when the list is a typed container rather than a plain `Array`. |
| **Element Type** | Expression | The element type as a `Variant.Type` value (`TYPE_INT`, `TYPE_STRING`, ...); `TYPE_NIL` (0) when untyped. |
| **Element Class** | Expression | For a class-typed list (`Array[Node]`), the class name; `""` otherwise. |
| **Assign (Type-Converting)** | Action | Replaces the contents with a converted copy of another list. |

Typed lists behave like any other exported variable in the Inspector: they take a **tooltip**, and they sit inside **groups and subgroups** (the variable dialog's "More options") so a long Inspector stays organised.

`Array[Dictionary]` is the typed form of "a list of rows", and it hosts the **Table** drawer - pick it under "Show as" and the Inspector edits the list as a grid with your own columns, exactly as a plain `Array` does, with the added guarantee that every row really is a row. A list typed to something that cannot be a row (`Array[int]`) keeps a plain field.

**Assign** is the one that earns its keep. Appending a `float` into an `Array[int]` is an error, but Assign converts as it copies, so it is the safe way to pour one list into a typed one:

```
On load scores
  -> Assign (Type-Converting)  "typed_scores", from: "raw_scores"
```

A value that fits converts silently (a `2.7` becomes `2` in an `Array[int]`). A value that cannot convert at all leaves the destination **empty** and pushes an error, so assign from data you trust, or check it first.

---

## Full ACE reference

Every name is exactly what appears in the picker. The first parameter is always the **Array** variable.

### Actions

| Action | Parameters | What it does |
| --- | --- | --- |
| **Append** | `value` | Adds a value to the end. |
| **Push To Front** | `value` | Adds a value to the start. |
| **Insert At** | `index`, `value` | Inserts a value at a position. |
| **Remove At** | `index` | Removes whatever is at a position. |
| **Erase Value** | `value` | Removes the first element equal to this value. |
| **Clear Array** | (none) | Empties the list. |
| **Sort Array** | (none) | Sorts in place, ascending. |
| **Shuffle Array** | (none) | Randomises the order in place. |
| **Reverse Array** | (none) | Reverses the order in place. |
| **Append Array** | `other` | Adds every element of another list to the end. |
| **Resize Array** | `size` | Grows (padding with null/zero) or truncates to a length. |
| **Fill Array** | `value` | Sets every existing slot to the same value. |
| **Assign (Type-Converting)** | `source` | Replaces the contents with a converted copy of another list (the type-safe way to fill a typed list). |

### Conditions

| Condition | Parameters | What it checks |
| --- | --- | --- |
| **Contains** | `value` | Whether the list holds this value. |
| **Array Is Empty** | (none) | Whether the list has no elements. |
| **Any Match** | `predicate`, `element` | Whether AT LEAST ONE element passes the test. False for an empty list. |
| **All Match** | `predicate`, `element` | Whether EVERY element passes the test. True for an empty list (nothing fails). |
| **Is Typed** | (none) | Whether this is a typed container (`Array[int]`) rather than a plain `Array`. |

### Expressions

| Expression | Parameters | Returns |
| --- | --- | --- |
| **Value At** | `index` | The element at a position. |
| **Array Size** | (none) | How many elements there are. |
| **First Item** / **Last Item** | (none) | The first / last element. |
| **Pick Random** | (none) | A random element. |
| **Index Of** | `value` | The position of the first match, or -1. |
| **Count Of** | `value` | How many elements equal this value. |
| **Pop Last** / **Pop First** | (none) | Removes AND returns the last / first element. |
| **Slice** | `from`, `to` | A new list with the elements in that range. |
| **Copy Array** | (none) | A duplicate of the list. |
| **Join To Text** | `separator` | The elements joined into one string. |
| **Array Max** / **Array Min** | (none) | The largest / smallest element. |
| **Filter** | `predicate`, `element` | A NEW list of the elements that pass the test. |
| **Map** | `expression`, `element` | A NEW list with every element transformed. |
| **Reduce** | `expression`, `seed`, `element`, `accumulator` | A single value folded from the whole list. |
| **Element Type** | (none) | The element type of a typed list, as a `Variant.Type` value. |
| **Element Class** | (none) | The element class name of a class-typed list, else `""`. |

---

## Use cases

### 1. Only the enemies still alive

```
On wave tick
  -> Set Variable  alive = Filter(enemies, where: x.health > 0)
  -> Set label     str(alive.size()) + " left"
```

### 2. Total score for the run

```
On run ends
  -> Set Variable  total = Reduce(scores, combine: acc + x, from: 0)
```

### 3. Is any enemy a boss?

```
On wave spawned
  Any Match  "enemies", where: x.is_boss
    -> Play music  "boss_theme"
```

### 4. Did everyone survive?

```
On level cleared
  All Match  "party", where: x.health > 0
    -> Award achievement  "no_casualties"
```

### 5. A list of names for the UI

```
On roster opened
  -> Set Variable  names = Map(party, to: x.display_name)
  -> Set label     Join To Text(names, ", ")
```

### 6. The most expensive item

```
-> Set Variable  priciest = Reduce(items, combine: max(acc, x.price), from: 0)
```

### 7. Affordable items only

```
On shop opened
  -> Set Variable  affordable = Filter(stock, where: x.price <= gold)
```

### 8. Guard before you read

```
On use next item
  Array Is Empty  "bag"  is false
    -> Set Variable  item = Pop First("bag")
    -> Use item      item
```

### 9. A shuffled draw pile

```
On new run
  -> Clear Array    "pile"
  -> Append Array   "pile", "all_cards"
  -> Shuffle Array  "pile"
```

### 10. Top three scores

```
On leaderboard opened
  -> Sort Array     "scores"
  -> Reverse Array  "scores"
  -> Set Variable   top = Slice("scores", 0, 3)
```

### 11. Count how many of a thing

```
-> Set label  "Keys: " + str(Count Of("inventory", "key"))
```

### 12. Deduplicate by rebuilding

```
On merge loot
  -> Set Variable  unique = []
  For Each  "incoming"
    Contains  "unique", item  is false
      -> Append  "unique", item
```

### 13. Everything within range

```
On aoe cast
  -> Set Variable  in_blast = Filter(enemies, where: x.global_position.distance_to(center) < radius)
```

### 14. Normalise loaded data into a typed list

```
On save loaded
  -> Assign (Type-Converting)  "level_ids", from: "raw_ids"
  Is Typed  "level_ids"
    -> Log  "typed list ready, element type " + str(Element Type("level_ids"))
```

### 15. A patrol route that loops

```
On waypoint reached
  -> Append    "route", Pop First("route")
  -> Move to   First Item("route")
```

### 16. Filtering with your own variable in play

```
Element name: enemy      predicate: enemy.threat > threat_floor
  -> Set Variable  dangerous = Filter(enemies, where: enemy.threat > threat_floor)
```

Renaming the element to `enemy` keeps your `threat_floor` variable readable inside the test, and reads better besides.

---

## Tips and common mistakes

- **Filter and Map hand back a NEW list; they never change the original.** Assign the result to a variable (or use it inline). The in-place verbs are the ones named like commands: Sort Array, Shuffle Array, Reverse Array, Fill Array.
- **The element is named by a field, defaulting to `x`.** If your sheet already has a variable called `x`, rename the element - otherwise the element shadows your variable silently, with no warning from GDScript.
- **An empty list answers Any Match with false and All Match with true.** "All of nothing passes" is standard, and it is usually what you want, but pair All Match with an `Array Is Empty` check when an empty list should not count as success.
- **Reduce always needs a Starting value.** It is the accumulator before the first element: `0` to sum, `1` to multiply, `[]` to build a list, `-INF` to find a maximum over possibly-negative numbers.
- **Pop Last / Pop First remove as well as return.** Reading one twice gives you two different elements. Use First Item / Last Item when you only want to look.
- **Assign converts, Append does not.** Pushing a float into an `Array[int]` is an error; **Assign (Type-Converting)** converts as it copies. A value that cannot convert leaves the destination empty and pushes an error.
- **Index Of returns -1 when the value is absent**, so test `>= 0` rather than truthiness (`-1` is not falsy).
- **Sort Array sorts in place and returns nothing.** Sort first, then read - do not expect a sorted copy back from it. Use Copy Array first when you need to keep the original order.
- **A typed list still satisfies a plain `Array` field**, so every verb here works on `Array[int]` exactly as it does on `Array`.
