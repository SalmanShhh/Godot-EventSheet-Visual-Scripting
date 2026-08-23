# Comparing Values

The condition rows that ask a question an operator cannot.

**Compare variable** and **Compare Values** already cover `a = b`, `a < b` and the rest, for anything that
compares with a plain operator. This guide is the rest of the question: comparisons that need a method, a
tolerance, or a type test, and that you would otherwise have to write as an ƒx expression.

They are **builtin** rows - no addon, no autoload, no setup. The picker groups them by what is being
compared, because the right question depends on the type:

| Section | For |
|---------|-----|
| **General Conditions** | the plain operator comparisons, and the escape hatch |
| **Variables** | comparing a sheet variable against a value |
| **Compare: Text** | case-insensitive matching, prefixes, wildcards, sort order |
| **Compare: Numbers** | tolerance, ranges, parity, multiples, sign |
| **Compare: Vectors** | approximate equality, distance, direction |
| **Compare: Types** | what IS this value, and are two values even comparable |
| **Compare: Objects** | identity, liveness, and what a node can do |
| **Variables: String** | the two checked text-to-number conversions |

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Reference tables](#reference-tables)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Typed-in text** - a name box, a cheat code, a chat command, where capitals should not matter.
- **Decimal comparisons** that would be a coin flip with `=`.
- **Positions and directions**, which are decimals four at a time and so are worse still.
- **Loaded data** - a save slot, a JSON payload, a spreadsheet cell, where you cannot assume the type.
- **Proximity and facing** - aggro range, interaction range, "is the enemy looking at me".
- **Duck typing** - "anything that can take damage", without a class hierarchy.
- **Dangling references** - the check that stops a freed node crashing the sheet.
- **Empty-or-not**, once, for text, lists, records and references alike.

## Core concepts

- **Every one of these is a condition** (a row on the left-hand side), except four expressions:
  Text Natural Order, Compare Result, Value Type Name, and the pair Number From Text /
  Whole Number From Text.
- **Every condition inverts.** Right-click a condition row and invert it rather than reaching for the
  opposite condition - though where the positive reading is the one you act on, a named condition exists for it
  (Contains None Of, Has Something, Is Farther Than).
- **`=` on decimals is a coin flip.** Tiny rounding differences survive arithmetic. Values Are Near,
  Vectors Are Equal and Colors Are Equal use Godot's approximate comparisons instead, which is almost
  always what you meant.
- **Type tests use `typeof`, never `is`.** GDScript's analyzer refuses to compile `i is String` once it
  knows `i` is an int, so an `is` guard would turn "I pointed the row at the wrong variable" into a build
  failure. `typeof` compiles against any type and simply reads false at runtime.
- **Nothing is not zero.** Is Nothing counts no value at all, empty text, an empty list and an empty
  record. A `0` and a `false` are real values and are deliberately NOT nothing - a guard that swallowed a
  score of zero would be a bug factory.
- **Ask before you convert.** Godot's `to_int` and `to_float` answer 0 for `"abc"`, for `""` and for
  `"0"` alike, so a typo in an amount box arrives as a real-looking bet of nothing. Text Is A Number asks
  first; Number From Text converts with a fallback YOU chose.

## Reference tables

### General conditions

| Name | What it does | Ships as |
|------|--------------|----------|
| Compare variable | True when a sheet variable compares against a value with your chosen operator. | `{var_name} {op} {value}` |
| Compare Values | True when two values compare with your chosen operator. | `{a} {op} {b}` |
| Is Between Values | True when a value falls within a low and high range, bounds included. | `({min} <= {value} and {value} <= {max})` |
| Is About | True when two decimal numbers are near enough to count as the same. | `is_equal_approx({a}, {b})` |
| Is Inside Area | True when a point falls inside a rectangle - corner, then size. | `{area}.has_point({point})` |
| Is Outside Layout | True when a point has left the visible layout on any side. | `not get_viewport_rect().has_point({point})` |
| Is On-Screen | True while a point is inside the visible layout. | `get_viewport_rect().has_point({point})` |
| Expression Is True | True when your own GDScript boolean expression is true - the advanced escape hatch. | `{expr}` |

The **Operator** dropdown on Compare variable and Compare Values is the same six everywhere in the
plugin, and it leads with the symbol the row will show and says it in words after: `=  equal to`,
`≠  not equal to`, `<  less than`, `≤  at most`, `>  greater than`, `≥  at least`. The token that is
actually inserted (`==`, `!=`, `<`, `<=`, `>`, `>=`) sits muted beside the choice, so the wording
teaches the spelling instead of hiding it, and the emitted code is unchanged.

All six of these open the one **Compare** dialog, together with Is Between Values, Is Outside Range,
Values Are Near and the text tests: pick what to compare, how, and to what, and the operator decides
which of these conditions the row becomes.

### Compare: Text

| Name | What it does | Ships as |
|------|--------------|----------|
| Text Equals (ignore case) | True when two pieces of text are the same, treating capitals and lowercase as identical. | `{a}.to_lower() == {b}.to_lower()` |
| Text Begins With | True when text starts with a prefix. | `{text}.begins_with({prefix})` |
| Text Is Empty | True when text has no characters at all. A single space is NOT empty. | `{text}.is_empty()` |
| Text Is Blank | True when text is empty OR only spaces - what a name box actually wants. | `{text}.strip_edges().is_empty()` |
| Text Matches Pattern | True when text fits a wildcard pattern (`*` is any run, `?` is one character). | `{text}.match({pattern})` |
| Text Is One Of | True when text equals one of a list of accepted values. | `{text} in {options}` |
| Text Sorts Before | True when the first text comes before the second alphabetically, ignoring case. | `{a}.casecmp_to({b}) < 0` |
| Text Natural Order | **Expression.** Compares text the way a person reads numbers in it, so "item2" comes before "item10". Negative, 0 or positive. | `{a}.naturalnocasecmp_to({b})` |
| Text Is A Number | True when this text would convert to a number cleanly. Ask BEFORE converting. | `str({text}).strip_edges().is_valid_float()` |
| Text Is A Whole Number | True when this text would convert to a WHOLE number cleanly. "12" passes, "12.5" does not. | `str({text}).strip_edges().is_valid_int()` |
| Contains Any Of | True when the text contains at least ONE of the listed pieces. | `Array({options}).any(func(__needle): return {text}.contains(__needle))` |
| Contains All Of | True only when the text contains EVERY listed piece. An empty list counts as true. | `Array({options}).all(func(__needle): return {text}.contains(__needle))` |
| Contains None Of | True when the text contains none of the listed pieces. An empty list always passes. | `(not Array({options}).any(func(__needle): return {text}.contains(__needle)))` |

### Variables: String - the checked conversions

| Name | What it does | Ships as |
|------|--------------|----------|
| Number From Text | **Expression.** Reads a number out of text, or hands back the fallback YOU chose - never a surprise zero. | `(str({text}).strip_edges().to_float() if str({text}).strip_edges().is_valid_float() else {fallback})` |
| Whole Number From Text | **Expression.** The same for whole numbers. "12.5" lands on the fallback rather than quietly becoming 12. | `(str({text}).strip_edges().to_int() if str({text}).strip_edges().is_valid_int() else {fallback})` |

### Compare: Numbers

| Name | What it does | Ships as |
|------|--------------|----------|
| Values Are Near | True when two numbers are within a tolerance of each other. | `absf({a} - {b}) <= {tolerance}` |
| Is Outside Range | True when a value falls below the low bound or above the high one. | `({value} < {min} or {value} > {max})` |
| Is Positive | True when a number is greater than zero. Zero is neither. | `{value} > 0` |
| Is Negative | True when a number is less than zero. | `{value} < 0` |
| Is Even | True for even whole numbers. | `int({value}) % 2 == 0` |
| Is Odd | True for odd whole numbers. | `int({value}) % 2 != 0` |
| Is Multiple Of | True every Nth number. Guards against a divisor of zero. | `(int({divisor}) != 0 and int({value}) % int({divisor}) == 0)` |
| Is A Whole Number | True when a decimal has nothing after the point. | `is_equal_approx({value}, floor({value}))` |
| Compare Result | **Expression.** -1, 0 or 1 for "less than, equal to, greater than" in one value. | `signi(int(sign({a} - {b})))` |

### Compare: Vectors

| Name | What it does | Ships as |
|------|--------------|----------|
| Vectors Are Equal | True when two vectors are the same allowing for rounding. | `{a}.is_equal_approx({b})` |
| Is Within Distance | True when two points are no further apart than a distance. | `{a}.distance_to({b}) <= {distance}` |
| Is Farther Than | True when two points are further apart than a distance. | `{a}.distance_to({b}) > {distance}` |
| Points The Same Way | True when two directions broadly agree. **Agreement** 1.0 is identical, 0.0 a right angle, -1.0 opposite; 0.7 is roughly within 45 degrees. | `{a}.normalized().dot({b}.normalized()) >= {threshold}` |
| Is Longer Than | True when a vector's length beats a number - "am I actually moving". | `{vector}.length() > {length}` |
| Colors Are Equal | True when two colors match allowing for rounding. | `{a}.is_equal_approx({b})` |

### Compare: Types

| Name | What it does | Ships as |
|------|--------------|----------|
| Value Is Of Type | True when a value is of a particular kind, picked from a dropdown. | `typeof({value}) == {type}` |
| Values Are The Same Type | True when two values are of the same kind, so comparing them means anything. | `typeof({a}) == typeof({b})` |
| Value Type Name | **Expression.** The name of a value's type as readable text ("int", "Vector2", "Dictionary"). | `type_string(typeof({value}))` |
| Object Is Class | True when an object is of an engine class or something derived from it. Safe on an empty reference. | `({object} != null and {object}.is_class({class_name}))` |
| Is Nothing | True when there is nothing there: no value, empty text, an empty list, an empty record. | `({value} in [null, "", [], {}] or (typeof({value}) >= TYPE_PACKED_BYTE_ARRAY and not {value}))` |
| Has Something | The exact opposite of Is Nothing, for when the filled case is the one you act on. | `(not ({value} in [null, "", [], {}] or (typeof({value}) >= TYPE_PACKED_BYTE_ARRAY and not {value})))` |

The **Type** dropdown on Value Is Of Type offers: Nothing (null), true / false, Whole number (int),
Decimal number (float), Text, Vector2, Vector3, Color, List (Array), Dictionary, Object / Node.

### Compare: Objects

| Name | What it does | Ships as |
|------|--------------|----------|
| Is The Same Object | True when two references point at the very same object, not merely one that looks alike. | `{a} == {b}` |
| Object Still Exists | True when an object has not been freed. A variable holding a deleted node is NOT null. | `is_instance_valid({object})` |
| Object Has Method | True when an object can do something - the duck-typing check. | `({object} != null and {object}.has_method({method}))` |
| Object Has Property | True when an object carries a named property. | `({object} != null and {property} in {object})` |

## Use cases

**1. A name box that rejects nothing-but-spaces.**

```
On confirm pressed
  Condition: Text Is Blank  NameField.text
    -> show "Please enter a name."
  Else
    -> Set Player Name to NameField.text
```

```gdscript
if name_field.text.strip_edges().is_empty():
```

**Text Is Empty** would let `"   "` through. **Text Is Blank** is the one a name box wants.

**2. A cheat code that does not care about capitals.**

```
On text submitted
  Condition: Text Equals (ignore case)  entered, "iddqd"
    -> enable god mode
```

```gdscript
if entered.to_lower() == "iddqd".to_lower():
```

**3. Route chat commands by their prefix.**

```
On message sent
  Condition: Text Begins With  message, "/"
    -> parse it as a command
```

```gdscript
if message.begins_with("/"):
```

**4. Match a family of level names without a regular expression.**

```
On scene loaded
  Condition: Text Matches Pattern  scene_name, "level_*"
    -> show the level HUD
```

```gdscript
if scene_name.match("level_*"):
```

`*` is any run of characters and `?` is exactly one, which covers most of what people reach for a regular
expression to do.

**5. One row instead of a chain of "or equals".**

```
On door touched
  Condition: Text Is One Of  key_id, ["brass", "iron", "skeleton"]
    -> open the door
```

```gdscript
if key_id in ["brass", "iron", "skeleton"]:
```

**6. A chat filter that looks INSIDE the message.**

```
On message sent
  Condition: Contains Any Of  message, banned_words
    -> block the message
```

```gdscript
if Array(banned_words).any(func(__needle): return message.contains(__needle)):
```

**Text Is One Of** needs the whole text to equal an entry; **Contains Any Of** looks inside it. Matching
is case-sensitive, and an empty list is never a match. Its siblings are **Contains All Of** (a search box
where every word must appear) and **Contains None Of** (the accept branch, written as the thing you act
on rather than as an Else).

**7. Sort a leaderboard the way people read it.**

```
Compare Values:  Text Natural Order (a_name, b_name)  <  0
```

```gdscript
if a_name.naturalnocasecmp_to(b_name) < 0:
```

**Text Natural Order** puts "item2" before "item10"; **Text Sorts Before** is the plain alphabetical
condition when the numbers do not matter.

**8. An amount box that cannot bet nothing by accident.**

```
On bet pressed
  Condition: Text Is A Whole Number  AmountField.text
    -> Set Bet to Whole Number From Text  AmountField.text, 0
  Else
    -> show "Enter a whole number of chips."
```

```gdscript
if str(amount_field.text).strip_edges().is_valid_int():
	bet = (str(amount_field.text).strip_edges().to_int() if str(amount_field.text).strip_edges().is_valid_int() else 0)
else:
	show_message("Enter a whole number of chips.")
```

Either half works alone: **Text Is A Whole Number** as a guard, or **Whole Number From Text** with a
fallback that means "no". Use both when the two outcomes need different rows.

**9. Never compare two positions with "equals".**

```
Every tick
  Condition: Vectors Are Equal  global_position, waypoint
    -> pick the next waypoint
```

```gdscript
if global_position.is_equal_approx(waypoint):
```

Positions are decimals, and any arithmetic leaves a remainder, so `=` almost never fires. In practice you
usually want **Is Within Distance** with a real tolerance instead.

**10. Aggro range.**

```
Every tick
  Condition: Is Within Distance  global_position, player.global_position, 240.0
    -> start chasing
```

```gdscript
if global_position.distance_to(player.global_position) <= 240.0:
```

**11. Give up the chase when the player gets away.**

```
Every tick
  Condition: Is Farther Than  global_position, player.global_position, 800.0
    -> go back to patrolling
```

```gdscript
if global_position.distance_to(player.global_position) > 800.0:
```

**12. Is the guard looking at me?**

```
Every tick
  Condition: Points The Same Way  facing_direction, direction_to_player, 0.7
    -> the guard spots the player
```

```gdscript
if facing_direction.normalized().dot(direction_to_player.normalized()) >= 0.7:
```

The **Agreement** number is how forgiving to be: 0.7 is roughly a 45-degree cone either side, 0.95 is a
narrow stare, 0.0 is anything in front.

**13. Am I actually moving?**

```
Every tick
  Condition: Is Longer Than  velocity, 5.0
    -> play the run animation
  Else
    -> play the idle animation
```

```gdscript
if velocity.length() > 5.0:
```

The small threshold beats a test against zero, because tiny residual velocity is normal.

**14. Duck typing: anything that can be hurt.**

```
On hitbox entered
  Condition: Object Has Method  other, "take_damage"
    -> call other.take_damage(10)
```

```gdscript
if (other != null and other.has_method("take_damage")):
```

No shared base class, no group membership, no cast. Anything that can do the thing gets hit.
**Object Has Property** is the same idea for a field rather than a method.

**15. Do not hit yourself.**

```
On area entered
  Condition: Is The Same Object  other, self  (inverted)
    -> apply damage
```

```gdscript
if not (other == self):
```

**16. The check that stops a freed node crashing the sheet.**

```
Every tick
  Condition: Object Still Exists  target
    -> chase the target
  Else
    -> Set Target to null
```

```gdscript
if is_instance_valid(target):
```

A variable holding a deleted node is NOT null - it is a dangling reference, and touching it crashes.
Comparing it to null does not catch that; **Object Still Exists** does.

**17. One empty check for whatever the value turns out to be.**

```
On save loaded
  Condition: Is Nothing  save["player_name"]
    -> Set Player Name to "Player"
```

```gdscript
if (save["player_name"] in [null, "", [], {}] or (typeof(save["player_name"]) >= TYPE_PACKED_BYTE_ARRAY and not save["player_name"])):
```

Missing key, empty text, empty list, empty record - one row. A `0` is deliberately not nothing, and
neither is `"   "` (that is Text Is Blank). **Has Something** is the same test the other way up.

**18. Guard a type before treating a loaded value as a list.**

```
On save loaded
  Condition: Value Is Of Type  save["inventory"], List (Array)
    -> For Each in save["inventory"]
```

```gdscript
if typeof(save["inventory"]) == TYPE_ARRAY:
```

**19. Are these two values even comparable?**

```
Condition: Values Are The Same Type  a, b
  Condition: Compare Values  a  =  b
    -> they match
```

```gdscript
if typeof(a) == typeof(b):
	if a == b:
```

Text and a number are never equal however similar they look, so a mismatch here explains a comparison
that "should" have fired.

**20. A milestone every tenth kill.**

```
On enemy died
  Condition: Is Multiple Of  kills, 10
    -> show a milestone banner
```

```gdscript
if (int(10) != 0 and int(kills) % int(10) == 0):
```

**Is Multiple Of** guards against a divisor of zero, which a hand-written `%` does not. **Is Even** and
**Is Odd** are the two-step version, for checkerboards and alternating turns.

**21. Cull anything that wandered off the level.**

```
Every tick
  Condition: Is Outside Range  position.x, -100, 4000
    -> queue_free this node
```

```gdscript
if (position.x < -100 or position.x > 4000):
```

**22. A tolerance where "equal" would never fire.**

```
Every tick
  Condition: Values Are Near  current_zoom, target_zoom, 0.01
    -> stop the zoom tween
```

```gdscript
if absf(current_zoom - target_zoom) <= 0.01:
```

**23. Report what a mystery value actually is.**

```
On debug key pressed
  -> print "loaded value is a " + Value Type Name (save["gold"])
```

```gdscript
print("loaded value is a " + type_string(typeof(save["gold"])))
```

**24. Sort with one comparison instead of two branches.**

```
Set Order to Compare Result  a.score, b.score
```

```gdscript
order = signi(int(sign(a.score - b.score)))
```

**25. The escape hatch, for a check nothing names yet.**

```
On fire pressed
  Condition: Expression Is True  $Player/WeaponKit.can_fire()
    -> fire the weapon
```

```gdscript
if $Player/WeaponKit.can_fire():
```

The expression is emitted verbatim and inverts to `not (...)` for free. Prefer a named condition where one
exists - this one is yours to get right.

### Other use cases

**A settings screen that only saves what changed.** Values Are Near on each slider against its stored
value tells you whether the write is worth doing, without a dirty flag per control.

**A save-file version gate.** Value Is Of Type on the version field plus Whole Number From Text with a
fallback of 0 turns "this file was written by who knows what" into a number a migration can branch on.

**Floor detection from a collision normal.** Points The Same Way against Vector2.UP with an Agreement of
0.7 is the "is this surface walkable" test, without hard-coding an angle.

**A search box over an item list.** Contains All Of with the typed words split into a list matches items
whose description mentions every word, which is what people expect a search box to do.

**A safe interaction prompt.** Object Still Exists plus Object Has Method on the nearest interactable
means the prompt never appears for something that was destroyed mid-frame, and never calls a method the
object does not have.

## Tips and common mistakes

- **`=` on decimals, positions and colours is a coin flip.** Reach for Values Are Near, Vectors Are Equal
  and Colors Are Equal instead. This is the trap this whole vocabulary exists to close.
- **Text Is Empty is not Text Is Blank.** A single space is not empty. A name box, a chat message and a
  search field almost always want Text Is Blank.
- **Contains Any Of is case-sensitive.** Text Equals (ignore case) is the only condition here that lowercases
  for you. Lowercase the text yourself before a case-insensitive contains check.
- **An empty list is true for Contains All Of and Contains None Of, and false for Contains Any Of.**
  Nothing is missing, nothing is forbidden, and nothing matched. That is consistent, but it means an
  accidentally-empty word list silently passes two of the three.
- **Number From Text reads its Text twice** in the emitted line (once to test, once to convert). Keep it
  a plain read - a variable, a `.get()` - and never a method that consumes, deals or advances something,
  or that side effect happens twice.
- **Whole Number From Text does not round.** "12.5" is not a whole number, so it lands on the fallback.
  When you want the rounding, use Number From Text and round the result yourself.
- **A freed node is not null.** Comparing a node variable to null will not catch a deleted node. Object
  Still Exists is the only check that does.
- **Object Is Class takes an engine class name as text**, and a derived class counts: a CharacterBody2D
  also passes an is-a-Node2D test. For your own `class_name` scripts, Object Has Method or Object Has
  Property is usually the better question.
- **Is Nothing keeps 0 and false.** If you want a zero treated as missing, say so explicitly with a
  Compare Values row - do not expect Is Nothing to do it.
- **Is Nothing understands a Split Text result.** An empty PackedStringArray does not equal an empty
  Array, so the condition tests the packed families separately. A hand-written `== []` check would miss it.
- **Object Has Property takes the property name as text**, in quotes, not as a bare identifier.
- **Points The Same Way normalizes both sides for you**, so you can feed it raw velocities without
  shrinking them first - but a zero-length vector has no direction and gives a meaningless answer. Gate
  it with Is Longer Than when the input might be still.
- **Prefer a named condition over Expression Is True.** The escape hatch compiles fine, but nothing in the
  editor can explain, translate or lift it the way a named row can.
