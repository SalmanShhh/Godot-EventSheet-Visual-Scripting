# Debugging And Printing

Sixteen builtin verbs for seeing what your sheet is actually doing. They cover the three console streams
Godot ships (the Output panel, the debugger's warning list, the debugger's error list), the combo-driven
**Log** family that picks a stream from a dropdown, an assertion, a manual breakpoint, a scene-tree dump,
and two live runtime readouts. Nothing here needs a pack enabled, and every one of them compiles to the
exact native one-liner you would have typed - `print(...)`, `push_warning(...)`, `assert(...)` - so a
debug row is an ordinary editable row rather than a raw GDScript block you have to unpick later.

There are two families and it is worth knowing which one you are in. The **plain** verbs (Print, Push
Warning, Push Error) each hit one stream and always round-trip back to themselves when you reopen the
sheet. The **combo** verbs (Log, Log If, Log (Debug Builds Only), Log Value) carry an **As** dropdown
that chooses the stream, so one verb covers Message, Warning, Error and Rich text.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Verb reference](#verb-reference)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **"Is this row even running?"** - the single most common question, answered by one Print.
- **Watching a value change** frame by frame with a labelled line you can actually find.
- **Warnings that survive the noise** - the debugger's warning list, not the flood of prints.
- **Errors that are loud but not fatal**, for states that should never happen but should not crash.
- **Assertions during development** that vanish from the exported build.
- **Trace logging that costs nothing in release** thanks to a debug-builds-only guard.
- **Colour-coded output** so different systems' lines are visually separable.
- **Dumping the scene tree** when a node is not where you thought it was.
- **Pausing exactly here** in the debugger without hunting for a gutter line.
- **On-screen FPS and memory** for a performance HUD you can leave in.

## Core concepts

- **Three streams, three destinations.** `print` writes to the Output panel. `push_warning` and
  `push_error` write to the Debugger's Errors tab, tagged with the file and line that raised them.
  Warnings and errors are far easier to find later; prints are easier to read in bulk.
- **The As dropdown shows a friendly label and inserts a call.** Choosing "Warning" in a Log row does not
  insert the word "warning" anywhere - it inserts `push_warning`. The four options are Message
  (`print`), Warning (`push_warning`), Error (`push_error`) and Rich text (BBCode) (`print_rich`).
- **Picking Rich text switches the Message field to a BBCode editor.** Select text in the field and hit
  B / I / U / S to wrap it in tags. That behaviour is bound to the As dropdown, so it appears the moment
  you choose Rich text and goes away again when you do not.
- **The Log verb carries a marker comment.** Its emitted line ends in `  # @ace:Core.ConsoleLog`. That
  marker is inert at runtime and exists so the row reopens as **Log** rather than as the specific verb
  its call shape matches. Without it, a `push_warning("x")` line would be indistinguishable from a Push
  Warning row and would silently reopen as one.
- **Assertions are removed from release builds.** `assert(...)` is stripped by the exporter. That is the
  point - and the trap: anything you put INSIDE the condition disappears with it.
- **Log (Debug Builds Only) is guarded rather than stripped.** It emits an `if OS.is_debug_build():`
  wrapper, so the line is present in the exported game but never runs.
- **Push Error does not stop the game.** It is a loud complaint, not a crash. Assert is the one that
  halts, and only while debugging.

## Verb reference

### Printing to a stream

| Verb | What it does | Ships as |
|------|--------------|----------|
| Print | Prints a value to the Output console, useful for debugging what's happening. | `print({value})` |
| Print Log | Prints a message to the output console, useful for debugging and checking values. | `print({message})` |
| Print Labeled | Prints a value preceded by a label so you can tell debug messages apart. | `print({label}, {value})` |
| Print Rich (BBCode) | Prints colored or bold text to the Output console using BBCode formatting. | `print_rich({value})` |
| Push Warning | Logs a warning message that appears in Godot's debugger panel. | `push_warning({message})` |
| Push Error | Logs an error message that appears in Godot's debugger panel. | `push_error({message})` |

### The Log family - one verb, four streams

Each of these carries the **As** dropdown: Message, Warning, Error, or Rich text (BBCode).

| Verb | What it does | Ships as |
|------|--------------|----------|
| Log | Writes a message to the console as a Message, Warning, Error, or Rich text - one verb for all four. | `{level}({message})  # @ace:Core.ConsoleLog` |
| Log If | Writes a message to the console only when a condition is true. | `if {condition}: {level}({message})` |
| Log (Debug Builds Only) | Writes to the console only in debug builds - the line is skipped entirely in an exported release game. | `if OS.is_debug_build(): {level}({message})` |
| Log Value | Prints a value tagged with a name, e.g. "health = 80", so debug lines are easy to tell apart. | `{level}("%s = %s" % [{label}, {value}])` |
| To Text | Turns any value (numbers, vectors, arrays...) into readable text for a log message. | `var_to_str({value})` |

### Stopping and inspecting

| Verb | What it does | Ships as |
|------|--------------|----------|
| Assert | Crashes during testing if a condition isn't true, catching bugs early; removed from release. | `assert({condition}, {message})` |
| Breakpoint (pause debugger) | Pauses the game in the debugger right here so you can inspect things. | `breakpoint` |
| Print Scene Tree | Prints the whole scene's node hierarchy to the output log for debugging. | `print_tree_pretty()` |

### Live runtime readouts

| Verb | What it does | Ships as |
|------|--------------|----------|
| Performance Monitor | Returns a live engine performance reading, like FPS or memory, for debugging. | `Performance.get_monitor({monitor})` |
| Static Memory (bytes) | Returns how much memory the game is currently using, in bytes. | `OS.get_static_memory_usage()` |

The Performance Monitor dropdown offers `Performance.TIME_FPS`, `Performance.TIME_PROCESS`,
`Performance.TIME_PHYSICS_PROCESS`, `Performance.OBJECT_COUNT`, `Performance.OBJECT_NODE_COUNT`,
`Performance.RENDER_TOTAL_OBJECTS_IN_FRAME`, `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` and
`Performance.PHYSICS_2D_ACTIVE_OBJECTS`.

## Use cases

**1. Did this event fire at all?** The one-row answer to the most common question in game development.

```gdscript
extends Node


func _ready() -> void:
	print("ready ran")
```

**2. Label the line so you can find it.** Print Labeled puts a name in front, which matters the moment
you have three prints running at once.

```gdscript
extends Node


func _ready() -> void:
	print("health:", 100)
```

**3. Watch a value with its name attached.** Log Value formats it as `name = value` in one row, which is
the readable form when you are scanning a fast-scrolling console.

```gdscript
extends Node


func _process(delta: float) -> void:
	print("%s = %s" % ["health", 80])
```

**4. Raise a warning instead of a print.** A warning lands in the debugger's list with its file and line
attached, so it is still findable an hour later.

```gdscript
extends Node


func _ready() -> void:
	push_warning("no spawn point found, using origin")
```

**5. Complain loudly about an impossible state without crashing.**

```gdscript
extends Node


func _ready() -> void:
	push_error("save slot index out of range")
```

**6. One verb, whichever stream you want.** Log's As dropdown means you can escalate a line from Message
to Warning by changing a cell, without swapping the verb.

```
On save failed
  -> Log  "could not write the save file"   As: Warning
```

**7. Colour-code your output.** Choosing Rich text turns the message field into a BBCode editor; select
the word and hit B.

```gdscript
extends Node


func _ready() -> void:
	print_rich("[b]done[/b]")
```

**8. Log only when something is wrong.** Log If folds the test into the row, so a low-health trace does
not need its own event.

```gdscript
extends Node


func _process(delta: float) -> void:
	if true: print("low health")
```

**9. Trace logging that costs nothing in the shipped game.** The debug-only form keeps the line in the
export but never runs it, so you can leave your tracing in.

```gdscript
extends Node


func _process(delta: float) -> void:
	if OS.is_debug_build(): print("trace")
```

**10. Print a value that is not text.** To Text turns a Vector2, an Array or a Dictionary into something
readable, which plain string concatenation will not do.

```gdscript
extends Node


func _ready() -> void:
	print(var_to_str(self))
```

**11. Assert an invariant while you build.** If the condition ever fails you find out immediately, and
the whole line vanishes from the exported build.

```gdscript
extends Node


func _ready() -> void:
	assert(true, "assertion failed")
```

**12. Stop right here and look around.** Breakpoint pauses in the debugger at that exact row, which beats
hunting for the generated line in the script.

```
On boss phase 2
  Condition: hp < 10
    -> Breakpoint (pause debugger)
```

**13. Find out where a node actually lives.** Print Scene Tree dumps the whole hierarchy, which is the
fastest cure for a path that will not resolve.

```gdscript
extends Node


func _ready() -> void:
	print_tree_pretty()
```

**14. An FPS counter you can leave in.**

```gdscript
extends Node


func _process(delta: float) -> void:
	print(Performance.get_monitor(Performance.TIME_FPS))
```

**15. Watch the node count while you spawn.** OBJECT_NODE_COUNT climbing and never falling is the
signature of a leak, and it shows up long before the frame rate does.

```
Every Frame
  -> Set Property  DebugLabel.text = "nodes: " + str( Performance Monitor(Performance.OBJECT_NODE_COUNT) )
```

**16. Check draw calls before blaming the CPU.**

```
Every Frame
  -> Set Property  DrawLabel.text = "draws: " + str( Performance Monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME) )
```

**17. Show memory in megabytes.** Static Memory hands back bytes, so divide.

```
Every Frame
  -> Set Property  MemLabel.text = str( Static Memory (bytes) / 1048576 ) + " MB"
```

**18. A one-row debug HUD.** Three monitors joined into one label beats three separate readouts.

```
Every Frame
  -> Set Property  Hud.text = "fps " + str(Performance Monitor(Performance.TIME_FPS))
       + "  nodes " + str(Performance Monitor(Performance.OBJECT_NODE_COUNT))
```

### Other use cases

**Tag your systems.** Give every subsystem its own Log Value label prefix ("ai", "audio", "save") so the console can be read by squinting instead of by searching.

**Warn on a designer mistake.** A Push Warning in the setup event when a required node or resource slot is empty turns "it silently does nothing" into a message the next person actually sees.

**Assert your data assumptions.** Assert that a lookup table is not empty right after it loads, so a bad resource fails at load time in testing instead of five minutes into a level.

**Rich-text state machine trace.** Print Rich with a colour per state makes a state machine's history readable at a glance while it scrolls past.

**Frame-time spike hunt.** Log If on TIME_PROCESS above a threshold writes only the frames that hitch, which is a far shorter list than logging every frame.

## Tips and common mistakes

- **Print and Print Log are the same line under two names.** Print lives in the Debug section, Print Log
  in General Actions, and both emit `print(...)`. Use whichever you find first; a reopened sheet may show
  you the other one, and nothing about the emitted code changes.
- **To Text is `var_to_str`, not `str`.** That means a String comes back **with its quotes**, and a
  Vector2 comes back in Godot's serialised form. That is what makes it unambiguous for debugging, and
  what makes it wrong for player-facing text.
- **Anything inside an Assert disappears in release.** `assert(spend_gold(5))` works perfectly in the
  editor and silently stops spending gold in the exported game. Keep the condition a pure test.
- **Assert only halts while debugging.** In a debug run it stops the game; in a release build the whole
  line is gone. It is a development tripwire, not error handling.
- **Push Error does not stop anything.** If you need execution to stop, that is Assert, or your own
  guard plus a Return.
- **Breakpoint needs the debugger.** Running the exported game, or running without the editor attached,
  means the row does nothing you can see.
- **The Log row's trailing comment is deliberate.** `# @ace:Core.ConsoleLog` is what makes the row reopen
  as Log rather than as Print or Push Warning. Deleting it by hand in the generated file does not break
  the game, but the row comes back as a different verb.
- **Per-frame printing is genuinely slow.** A print in an Every Frame event costs real milliseconds and
  can itself cause the hitch you are hunting. Gate it with Log If, or use Log (Debug Builds Only), or
  put the value on a label instead of in the console.
- **Warnings and errors survive; prints scroll away.** For anything you want to still be able to find at
  the end of a play session, use Warning rather than Message.
- **Performance Monitor returns a number, not text.** Concatenating it into a label needs `str(...)`
  around it, which is what use case 15 does.
- **Static Memory is in bytes.** A raw readout of `74561536` is not a bug; divide by 1048576 for
  megabytes.
- **The BBCode field only appears for Rich text.** If the B / I / U / S buttons are missing from a Log
  row's Message cell, the As dropdown is on Message, Warning or Error - switch it to Rich text (BBCode).
