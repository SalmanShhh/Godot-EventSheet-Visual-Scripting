# Calling Your Own Code From Rows

**Helpers** is the structured escape hatch: the vocabulary that reaches arbitrary GDScript without
dropping the row into an opaque code block. Set any property on any object, call any method, read any
value, evaluate any expression as a condition, build a callable or a lambda, and hand control back and
forth with your own sheet functions. Alongside them sit the two **Behavior** verbs that name the node
a behaviour is attached to.

Every template here is a single direct GDScript line, so picking a helper compiles to exactly what you
would have hand-written, while the logic stays an editable, searchable, undoable row rather than a
block the editor cannot read.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Verb reference](#verb-reference)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **The property no menu covers** - a shader parameter, a third-party plugin's export, a custom class's field.
- **The method no menu covers** - anything on any node, as an action or as a value.
- **One-line GDScript** kept as a row, with a codegen tooltip, instead of a code block.
- **Null safety** - the guard that turns "Nonexistent function on base Nil" into a condition.
- **Formatted labels** - a score line built from a printf template in one row.
- **Callables and lambdas** to hand to `sort()`, `map()`, `filter()`, a signal or a timer.
- **Your own sheet functions** - call them, return from them, return a value from them.
- **Behaviour sheets** - reading and guarding the host node the behaviour acts on.
- **Prototyping** - reach something now with Run GDScript, replace it with a real verb later.
- **Reading a value the picker has no expression for**, without leaving the expression field.

## Core concepts

- **A helper is generic on purpose.** `target`, `property`, `method` and `code` are free expressions,
  so one helper replaces a whole family of one-off code blocks.
- **Prefer a specific verb when one exists.** Set Position, Play Animation, Clamp, the array and
  dictionary verbs and the rest of the curated vocabulary read better and carry their own parameter
  help. Helpers fill the gaps; they are not meant to shadow the menus.
- **Helpers are registered last, and mostly kept out of the reverse index.** When the importer lifts
  hand-written GDScript back into rows, the most specific template wins. Only the statement catch-alls
  (Set Property and its compound-assign twins, Call Method, and the local variable and constant
  families) are admitted at all, at the lowest specificity, so a helper can never steal a line a real
  verb describes better.
- **A property is a bare identifier, not a string.** `modulate`, not `"modulate"`. That keeps the
  emitted code statically typed and fast.
- **Run GDScript is exactly one statement.** For several lines, either use several rows or add a code
  block deliberately.
- **The Evaluate pair splits by role.** Evaluate GDScript is a condition and wants a boolean;
  Evaluate Expression is a value and can be anything.
- **A function row is a real function.** Call Function calls one of your sheet functions; Return Value
  and Return (stop here) are how one hands control back. The return TYPE is set on the function
  itself, not on the row.
- **Host is behaviour-only.** It emits the literal `host` variable that a behaviour sheet binds to its
  parent as it enters the tree, so the picker hides it on a plain event sheet.

## Verb reference

On the canvas these read as sentences, exactly as the rows draw them:

- set **self**.**modulate** = **Color.WHITE**
- **$Sprite2D**.**play**(**"hit"**)
- **enemy** is valid
- Call **spawn_wave**(**3, 2.0**)

### Properties

| Verb | What it does | Ships as |
|------|--------------|----------|
| Set Property | Sets any property on any object. | `{target}.{property} = {value}` |
| Add To Property | Changes a property relative to itself, upward. | `{target}.{property} += {value}` |
| Subtract From Property | The same, downward. | `{target}.{property} -= {value}` |
| Multiply Property | Scales a property by a factor. | `{target}.{property} *= {value}` |
| Divide Property | Divides a property by a value. | `{target}.{property} /= {value}` |
| Get Property | Reads any property on any object. | `{target}.{property}` |

`target` defaults to `self` on all six, so a row with the target untouched acts on this node.

### Methods, nodes and resources

| Verb | What it does | Ships as |
|------|--------------|----------|
| Call Method | Calls a method and throws the result away. | `{target}.{method}({args})` |
| Call Method (value) | Calls a method and uses what it returns. | `{target}.{method}({args})` |
| Get Node | Looks another node up by its scene path. | `get_node({path})` |
| Load Resource | Loads a scene or resource from a `res://` path at run time. | `load({path})` |

### Raw GDScript, kept as a row

| Verb | What it does | Ships as |
|------|--------------|----------|
| Run GDScript | Runs one line of GDScript as an action. | `{code}` |
| Evaluate GDScript | True when your own boolean expression is true. | `({code})` |
| Evaluate Expression | The result of any GDScript value expression. | `({code})` |

### Validity and type

| Verb | What it does | Ships as |
|------|--------------|----------|
| Is Valid | True when the object still exists and has not been freed. | `is_instance_valid({target})` |
| Is Null | True when the value is null. | `{target} == null` |
| Type Of | A number identifying what kind of value something is. | `typeof({value})` |

### Text

| Verb | What it does | Ships as |
|------|--------------|----------|
| Format String | Builds a string by filling printf placeholders. | `{template} % [{args}]` |
| Set Text (formatted) | Sets a node's `text` from a printf template in one row. | `{target}.text = {template} % [{args}]` |

### Callables and lambdas

| Verb | What it does | Ships as |
|------|--------------|----------|
| Callable of Method | A reference to a named method you can pass around, connect or call later. | `Callable({target}, "{method}")` |
| Bind Arguments | Pre-fills a callable's arguments. | `{callable}.bind({args})` |
| Lambda (returns a value) | A small inline function that computes a value. | `(func({params}): return {value})` |
| Lambda (runs a statement) | A small inline function that runs one statement. | `(func({params}): {statement})` |

### Your own functions

| Verb | What it does | Ships as |
|------|--------------|----------|
| Call Function | Calls one of your sheet functions with arguments. | `{function_name}({args})` |
| Return Value | Returns a value from the current function. | `return {value}` |
| Return (stop here) | Exits the current function immediately. | `return` |

### The behaviour's host

| Verb | What it does | Ships as |
|------|--------------|----------|
| Host | The parent node this behaviour is attached to. | `host` |
| Host Is Valid | True when the behaviour has a live host. | `is_instance_valid(host)` |

## Use cases

**1. Set a property no menu covers.** The property field takes a bare identifier, and it can be a
path through the value: `modulate.a` is as legal as `modulate`.

```gdscript
func _ready() -> void:
	self.modulate = Color.WHITE
```

**2. Fade something out over time.** **Subtract From Property** changes a property relative to itself,
which is the row a raw block used to be needed for.

```gdscript
func _process(delta: float) -> void:
	$Sprite2D.modulate.a -= delta
```

**3. Nudge a position each frame.** **Add To Property** with a Vector2 value.

```gdscript
func _physics_process(delta: float) -> void:
	self.position += Vector2(1, 0)
```

**4. Grow and shrink.** **Multiply Property** and **Divide Property** on `scale`.

```gdscript
func _on_pickup() -> void:
	self.scale *= 1.1
```

**5. Read a property into a condition.** **Get Property** is an expression, so it drops into a
comparison or into another row's field.

```
Every tick
  Condition: Get Property($Sprite2D, visible) = false
    -> print "the sprite is hidden"
```

**6. Call any method as an action.** Arguments are a comma-separated expression list and may be empty.

```gdscript
func _on_hit() -> void:
	$AnimationPlayer.play("hit")
```

**7. Call a method for its answer.** **Call Method (value)** is the expression twin, for when the
return value is the point.

```gdscript
func _ready() -> void:
	var slot := self.get_index()
```

**8. Reach another node.** **Get Node** takes a path string, absolute or relative.

```gdscript
func _ready() -> void:
	var enemy := get_node("../Enemy")
```

**9. Load a scene at run time.** **Load Resource** is `load`, not `preload`: it happens when the row
runs, which is what you want for anything chosen at run time.

```gdscript
func _on_spawn() -> void:
	var bullet = load("res://bullets/plasma.tscn").instantiate()
	add_child(bullet)
```

**10. One line of GDScript, still a row.** **Run GDScript** keeps the line searchable, editable and
undoable rather than hiding it in a block.

```gdscript
func _ready() -> void:
	Engine.max_fps = 60
```

**11. Any boolean expression as a condition.** **Evaluate GDScript** is the row that covers `is` class
checks, chained comparisons, and anything else the picker has no condition for.

```
On body entered
  Condition: (body is Area2D)
    -> print "an area, not a body"
```

**12. Any value expression as a value.** **Evaluate Expression** fills a field the picker has no
expression for, without leaving the row.

```
Every tick
  -> set Label text = str((Engine.get_frames_per_second()))
```

**13. Guard a reference before you use it.** This is the fix for the freed-instance crash, and it is a
condition, so the whole branch is skipped rather than erroring inside it.

```
Every tick
  Condition: target is valid
    -> set target.modulate = Color.RED
```

**14. Distinguish "never set" from "freed".** **Is Null** answers the first, **Is Valid** the second.
A variable that was never assigned is null; one whose node was freed is not null but is invalid.

**15. Branch on what kind of value you got.** **Type Of** returns the Variant type as a number, which
compares against Godot's `TYPE_*` constants.

```
On data received
  Condition: typeof(payload) = TYPE_DICTIONARY
    -> read the payload's fields
```

**16. A formatted label in one row.** **Set Text (formatted)** is the action; **Format String** is the
expression when the text is going somewhere else.

```gdscript
func _on_score_changed() -> void:
	$HUD/ScoreLabel.text = "Score: %d" % [score]
```

**17. A callable you can pass around.** **Callable of Method** references a method by name so it can
be connected, stored in a variable, or handed to a sort.

```gdscript
func _ready() -> void:
	timer.timeout.connect(Callable(self, "queue_free"))
```

**18. Pre-fill a callable's arguments.** **Bind Arguments** is how one handler serves several buttons.

```gdscript
func _ready() -> void:
	button.pressed.connect(Callable(self, "_on_slot_pressed").bind(0))
```

**19. Sort with a lambda.** **Lambda (returns a value)** goes straight into `sort_custom`, `map` or
`filter`.

```gdscript
func _ready() -> void:
	var doubled := [1, 2, 3].map((func(x): return x * 2))
```

**20. Run something on a signal without writing a handler.** **Lambda (runs a statement)** is the
one-statement twin.

```gdscript
func _ready() -> void:
	get_tree().create_timer(1.0).timeout.connect((func(): print("tick")))
```

**21. Reuse logic across events.** **Call Function** calls one of your sheet functions, with a
comma-separated argument list.

```gdscript
func _on_wave_cleared() -> void:
	spawn_wave(3, 2.0)
```

**22. Return a value from a sheet function.** The function's return type is set on the function
itself, so the row only carries the expression.

```gdscript
func total_damage(base: int, bonus: int) -> int:
	return base + bonus
```

**23. Bail out early.** **Return (stop here)** exits immediately, skipping every remaining action,
which is the readable shape for a guard clause.

```
On Ready
  Condition: player is null
    -> Return
  -> carry on with setup
```

**24. Read the node a behaviour is attached to.** **Host** is the behaviour's parent, the object the
behaviour acts on.

```gdscript
func _physics_process(delta: float) -> void:
	host.position += Vector2(1, 0)
```

**25. Guard the host before touching it.** A behaviour ticks before the host is bound and can outlive
it after it is freed, so **Host Is Valid** is the standing guard.

```
Every Physics Tick
  Condition: host is valid
    -> set host.velocity = Vector2(0, 0)
```

**26. Turn a prototype into vocabulary.** Reach the thing with Run GDScript or Call Method now, and
when the same row appears a third time, publish it as a verb from the ACE Studio. The rows that used
the helper keep working; the new ones read as a sentence.

**27. Fill an expression field on any other row.** Every expression helper here (Get Property, Call
Method (value), Evaluate Expression, Type Of, Format String, the lambdas) is usable inside any other
row's parameter, so a helper rarely needs a row of its own.

### Other use cases

**A shader parameter animated from a row.** Set Property on a material's `shader_parameter/strength` reaches something no menu will ever list, and Add To Property animates it per frame without a code block.

**A third-party plugin's node driven from a sheet.** Call Method plus Get Property cover an entire foreign API with two verbs, so a plugin the vocabulary knows nothing about is still fully addressable.

**A generic button bank.** One handler plus Bind Arguments gives every slot button its own index, replacing eight near-identical handlers with one row and one bind.

**A safe polling loop.** Is Valid in front of every reference a long-lived event holds turns the classic "Nonexistent function in base Nil" crash into a branch that quietly does nothing that frame.

**A debug overlay built from expressions.** Set Text (formatted) with Evaluate Expression arguments prints anything the engine exposes onto a label without adding a single named verb.

## Tips and common mistakes

- **Do not quote a property name.** The field wants `modulate`, not `"modulate"`. A quoted name emits
  `self."modulate" = ...`, which does not compile.
- **Do not quote the method in Callable of Method.** The template supplies the quotes itself, so
  typing them produces `Callable(self, ""queue_free"")`.
- **Call Method's arguments are expressions, not a string.** `1, 2` is two arguments; `"1, 2"` is one
  string argument.
- **Run GDScript takes ONE statement.** A second line, an `if` with a body, or a `for` loop belongs in
  several rows or in a deliberate code block.
- **Evaluate GDScript wants a boolean.** It is a condition, so a non-boolean expression is truthy in
  ways that will surprise you. Use Evaluate Expression when the value is the point.
- **`load` is not `preload`.** **Load Resource** happens when the row runs, so it costs time at that
  moment and can fail on a bad path. Where a compile-time scene is genuinely required, author it as a
  constant in a code block.
- **Format String's arguments must match its placeholders.** `"Score: %d" % [name]` raises at run
  time; count the `%` markers against the argument list.
- **A single-line lambda ends at the end of the line.** Both lambda verbs emit `func(...): <one
  thing>` on one line, so anything you meant to be a second statement will be parsed as belonging to
  the surrounding expression instead. Keep them to one thing.
- **A lambda's parameter list may be empty**, and often should be: a timer's `timeout` hands its
  handler no arguments, so `func(): ...` is the correct shape there.
- **Prefer a specific verb where one exists.** Set Property on `position` works, but Set Position
  reads better, carries its own help, and lifts back out of hand-written code more precisely.
- **Is Valid and Is Null are not interchangeable.** `is_instance_valid(null)` is false, so Is Valid
  covers both cases on an object; Is Null is the right question for a value that may simply be unset.
- **Divide Property by zero still divides by zero.** These helpers compile to plain GDScript with no
  guard added, which is the point of the parity covenant.
- **Return Value's type comes from the function.** Setting a return type on the function and returning
  something else fails to compile, and the row will not tell you which one is wrong.
- **Host only exists on a behaviour sheet.** The two Behavior verbs emit the literal `host` variable,
  which a plain event sheet does not have, which is why the picker hides them there.
- **Guard the host, not just the first use.** The binding happens as the behaviour enters the tree, so
  a tick that runs before that, or after the host is freed, needs **Host Is Valid** in front of it.
