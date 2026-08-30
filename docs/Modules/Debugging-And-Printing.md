# Debugging And Printing

The builtin actions, conditions and expressions for seeing what your sheet is actually doing. They cover the three console streams
Godot ships (the Output panel, the debugger's warning list, the debugger's error list), the combo-driven
**Log** family that picks a stream from a dropdown, an assertion, a manual breakpoint, a scene-tree dump,
and two live runtime readouts. Nothing here needs a pack enabled, and every one of them compiles to the
exact native one-liner you would have typed - `print(...)`, `push_warning(...)`, `assert(...)` - so a
debug row is an ordinary editable row rather than a raw GDScript block you have to unpick later.

There are two families and it is worth knowing which one you are in. The **plain** actions (Print, Push
Warning, Push Error) each hit one stream and always round-trip back to themselves when you reopen the
sheet. The **combo** actions (Log, Log If, Log (Debug Builds Only), Log Value) carry an **As** dropdown
that chooses the stream, so one action covers Message, Warning, Error and Rich text.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Reference tables](#reference-tables)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)
6. [Reading the trace: hit counts and "Why didn't this fire?"](#reading-the-trace-hit-counts-and-why-didnt-this-fire)

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
- **The two seconds before the bug**, kept in a named trail and dumped when something goes wrong.
- **Catching the hitch as it happens** with a frame-budget condition, then logging what caused it.
- **Sustained low framerate as a branch** you can act on, including shipping behaviour like dropping
  particle quality, rather than a number you can only display.
- **Timing a region of a sheet** with a named stopwatch, then reading it back as last, average or peak.

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
- **The Log action carries a marker comment.** Its emitted line ends in `  # @ace:Core.ConsoleLog`. That
  marker is inert at runtime and exists so the row reopens as **Log** rather than as the specific action
  its call shape matches. Without it, a `push_warning("x")` line would be indistinguishable from a Push
  Warning row and would silently reopen as one.
- **Assertions are removed from release builds.** `assert(...)` is stripped by the exporter. That is the
  point - and the trap: anything you put INSIDE the condition disappears with it.
- **Log (Debug Builds Only) is guarded rather than stripped.** It emits an `if OS.is_debug_build():`
  wrapper, so the line is present in the exported game but never runs.
- **Push Error does not stop the game.** It is a loud complaint, not a crash. Assert is the one that
  halts, and only while debugging.

## Reference tables

### Printing to a stream

![Print Rich draws its BBCode as the effect in the row; a plain Print keeps the tags verbatim](../images/rich-param-cells.png)

![The Message field as a BBCode editor: the B, I, U and S toolbar with the rendered preview live under it](../images/bbcode-param.png)

| Name | What it does | Ships as |
|------|--------------|----------|
| Print | Prints a value to the Output console, useful for debugging what's happening. | `print({value})` |
| Print Log | Prints a message to the output console, useful for debugging and checking values. | `print({message})` |
| Print Labeled | Prints a value preceded by a label so you can tell debug messages apart. | `print({label}, {value})` |
| Print Rich (BBCode) | Prints colored or bold text to the Output console using BBCode formatting. | `print_rich({value})` |
| Push Warning | Logs a warning message that appears in Godot's debugger panel. | `push_warning({message})` |
| Push Error | Logs an error message that appears in Godot's debugger panel. | `push_error({message})` |

### The Log family - one action, four streams

Each of these carries the **As** dropdown: Message, Warning, Error, or Rich text (BBCode).

| Name | What it does | Ships as |
|------|--------------|----------|
| Log | Writes a message to the console as a Message, Warning, Error, or Rich text - one verb for all four. | `{level}({message})  # @ace:Core.ConsoleLog` |
| Log If | Writes a message to the console only when a condition is true. | `if {condition}: {level}({message})` |
| Log (Debug Builds Only) | Writes to the console only in debug builds - the line is skipped entirely in an exported release game. | `if OS.is_debug_build(): {level}({message})` |
| Log Value | Prints a value tagged with a name, e.g. "health = 80", so debug lines are easy to tell apart. | `{level}("%s = %s" % [{label}, {value}])` |
| To Text | Turns any value (numbers, vectors, arrays...) into readable text for a log message. | `var_to_str({value})` |

### Stopping and inspecting

| Name | What it does | Ships as |
|------|--------------|----------|
| Assert | Crashes during testing if a condition isn't true, catching bugs early; removed from release. | `assert({condition}, {message})` |
| Breakpoint (pause debugger) | Pauses the game in the debugger right here so you can inspect things. | `breakpoint` |
| Print Scene Tree | Prints the whole scene's node hierarchy to the output log for debugging. | `print_tree_pretty()` |

### Live runtime readouts

| Name | What it does | Ships as |
|------|--------------|----------|
| Performance Monitor | Returns a live engine performance reading, like FPS or memory, for debugging. | `Performance.get_monitor({monitor})` |
| Static Memory (bytes) | Returns how much memory the game is currently using, in bytes. | `OS.get_static_memory_usage()` |

The Performance Monitor dropdown offers `Performance.TIME_FPS`, `Performance.TIME_PROCESS`,
`Performance.TIME_PHYSICS_PROCESS`, `Performance.OBJECT_COUNT`, `Performance.OBJECT_NODE_COUNT`,
`Performance.RENDER_TOTAL_OBJECTS_IN_FRAME`, `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` and
`Performance.PHYSICS_2D_ACTIVE_OBJECTS`.

### Value trails - the last N values of anything

Every other live surface shows the current frame. A trail is a named rolling history you fill from a
row and read back later, so the two seconds before the frame you are looking at are still there when
you go looking. It records silently: nothing appears anywhere until a row logs it, writes it, or
reads it. Trails are stored in node metadata, so a trail filled in one event is readable from any
other event on the same node, and a trail name is free text (spaces are fine).

| Name | What it does | Ships as |
|------|--------------|----------|
| Remember In Trail | Records a value into a named rolling history you can dump, chart, or check when something goes wrong. | `__trails_N[{trail}] = __trail_N` (append plus a trim to Keep) |
| Trail Values | Returns the whole trail as an array, oldest first. | `(get_meta(&"__ef_trails", {}) as Dictionary).get({trail}, []) as Array` |
| Lowest In Trail | The smallest value recorded in a trail, which is the spike a per-frame watch blinked past. | `(...).reduce(func(__acc, __v): return min(__acc, __v), INF)` |
| Highest In Trail | The largest value recorded in a trail. | `(...).reduce(func(__acc, __v): return max(__acc, __v), -INF)` |
| Average In Trail | The mean of every number recorded in a trail. | `(...).reduce(...) / maxf(float((...).size()), 1.0)` |
| Newest In Trail | The most recently recorded value, or 0 when nothing has been recorded yet. | `([0] + (...)).back()` |
| Trail Length | How many values a trail is currently holding, which tops out at the Keep you gave it. | `(...).size()` |
| Log Trail | Prints the whole trail to the Output console. | `print("trail ", {trail}, ": ", ...)` |
| Save Trail To CSV | Writes a trail to a two-column CSV file you can open in a spreadsheet and plot. | `FileAccess.open({path}, FileAccess.WRITE)` plus one line per value |
| Clear Trail | Forgets everything a trail recorded. | `__trails_N.erase({trail})` |

**Lowest In Trail and Highest In Trail read `INF` and `-INF` on an empty trail**, the same sentinel the
Lowest In Group and Highest In Group expressions use. Average In Trail and Newest In Trail read 0.

### Frame budget and named stopwatches

Two threshold questions and a stopwatch. These are vocabulary, not chrome: they add nothing to any
row's margin and no always-on display anywhere. A measurement becomes visible only where you send
it, whether that is Log Measurements, a label, or the Debug Overlay pack.

| Name | What it does | Ships as |
|------|--------------|----------|
| Frame Took Longer Than | True on a frame that took longer than your budget, which is the hitch caught as it happens. | `(get_process_delta_time() * 1000.0 > {ms})` |
| FPS Below For | True once the framerate has stayed under your floor for the whole stretch you name. | `__fps_below_for_N({fps}, {seconds})` plus a per-row clock member |
| Start Measuring | Starts a named stopwatch. Pair it with Stop Measuring around the work you suspect. | `__starts_N[{named}] = Time.get_ticks_usec()` |
| Stop Measuring | Stops a named stopwatch and files the result, keeping the last, the average and the worst reading. | `__stats_N[{named}] = [total, samples, peak, last]` |
| Last Measured (ms) | How many milliseconds the most recent run of a named measurement took. | `float((... .get({named}, [0.0, 0, 0.0, 0.0]) as Array)[3])` |
| Average Measured (ms) | The mean cost across every run of a named measurement. | `total / maxf(float(samples), 1.0)` |
| Peak Measured (ms) | The worst run of a named measurement, which is usually the one the player felt. | `float((...)[2])` |
| Log Measurements | Prints every named measurement with its last, average and peak cost. | a loop over the stats dictionary into `print(...)` |
| Clear Measurements | Throws away every measurement recorded so far. | `set_meta(&"__ef_spans", {})` |

**Both conditions need a per-frame trigger** (Every Frame). Frame Took Longer Than asks about the
frame it is evaluated on, and FPS Below For has to be reached every frame to keep its clock honest.
**FPS Below For is the one that tells a real drop apart from one stuttery frame**: the framerate has
to stay under the floor for the whole window, and one healthy frame re-arms it from the beginning.

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

**6. One action, whichever stream you want.** Log's As dropdown means you can escalate a line from Message
to Warning by changing a cell, without swapping the action.

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

**19. Keep the last two seconds of fall speed.** One Remember In Trail row under Every Frame, and the
two seconds before any bug are still there when you go looking. Nothing is displayed; it just records.

```gdscript
extends Node


func _process(delta: float) -> void:
	var __trails_1: Dictionary = get_meta(&"__ef_trails", {}) as Dictionary
	var __trail_1: Array = __trails_1.get("vy", []) as Array
	__trail_1.append(velocity.y)
	if __trail_1.size() > maxi(int(120), 1):
		__trail_1 = __trail_1.slice(__trail_1.size() - maxi(int(120), 1))
	__trails_1["vy"] = __trail_1
	set_meta(&"__ef_trails", __trails_1)
```

**20. Dump the trail from the signal that marks the moment.** The Health pack already fires On Died,
so the dump hangs off that trigger rather than off a per-frame "has died" poll. A trail is filled by a
tick and dumped from whatever signal marks the moment worth keeping.

```gdscript
extends Node


func _on_health_on_death() -> void:
	print("trail ", "vy", ": ", (get_meta(&"__ef_trails", {}) as Dictionary).get("vy", []))
```

**21. Catch an impossible value you never saw happen.** Lowest In Trail is an expression, so it reads
inside an ordinary condition cell. This is the spike a per-frame watch blinks past.

```gdscript
extends Node


func _process(delta: float) -> void:
	if (((get_meta(&"__ef_trails", {}) as Dictionary).get("vy", []) as Array).reduce(func(__acc, __v): return min(__acc, __v), INF)) < -2000.0:
		push_warning("impossible fall speed - see trail")
```

**22. Export a tuning curve and plot it in a spreadsheet.** Save Trail To CSV writes `index,value`
rows, which is exactly what a chart tool wants. Acceleration, damage over time, camera shake.

```gdscript
extends Node


func _on_run_finished() -> void:
	var __csv_1: FileAccess = FileAccess.open("user://accel.csv", FileAccess.WRITE)
	if __csv_1 != null:
		__csv_1.store_line("index,value")
		var __rows_1: Array = (get_meta(&"__ef_trails", {}) as Dictionary).get("accel", []) as Array
		for __i_1: int in __rows_1.size():
			__csv_1.store_line("%d,%s" % [__i_1, str(__rows_1[__i_1])])
		__csv_1.close()
```

**23. A rolling average as real gameplay, not debugging.** Recent DPS, momentum, "how hot is this
player right now" - Average In Trail over a short trail is the whole implementation.

```gdscript
extends Node


func _process(delta: float) -> void:
	dps_label.text = "DPS %.0f" % (((get_meta(&"__ef_trails", {}) as Dictionary).get("dmg", []) as Array).reduce(func(__acc, __v): return __acc + float(__v), 0.0) / maxf(float(((get_meta(&"__ef_trails", {}) as Dictionary).get("dmg", []) as Array).size()), 1.0))
```

**24. Start every run from a clean trail.** Clear Trail on the run-start trigger, so last run's
evidence never confuses this one. Clearing a trail that was never filled is harmless.

```gdscript
extends Node


func _on_run_started() -> void:
	var __trails_1: Dictionary = get_meta(&"__ef_trails", {}) as Dictionary
	__trails_1.erase("vy")
	set_meta(&"__ef_trails", __trails_1)
```

**25. Show a beginner what a value does over time.** Newest In Trail and Trail Length together read
as "the current value, out of the last N", which is a far better teaching label than a bare number.

```gdscript
extends Node


func _process(delta: float) -> void:
	debug_label.text = "%s of %d samples" % [str(([0] + ((get_meta(&"__ef_trails", {}) as Dictionary).get("vy", []) as Array)).back()), ((get_meta(&"__ef_trails", {}) as Dictionary).get("vy", []) as Array).size()]
```

**26. Catch the hitch as it happens.** Frame Took Longer Than is a condition, so the whole event only
runs on the bad frames. 16.6 is one frame at 60 FPS; 20 leaves a little headroom.

```gdscript
extends Node


func _process(delta: float) -> void:
	if (get_process_delta_time() * 1000.0 > 20.0):
		print("%s = %s" % ["slow frame at", Engine.get_frames_drawn()])
```

**27. Log what was actually happening on the slow frame.** The point of catching a hitch in the sheet
rather than in a profiler is that everything the sheet knows is in scope right there.

```gdscript
extends Node


func _process(delta: float) -> void:
	if (get_process_delta_time() * 1000.0 > 20.0):
		print("%s = %s" % ["enemies alive", get_tree().get_node_count_in_group("enemies")])
```

**28. Adaptive quality on a sustained drop.** This one ships, it is not just debugging. One stuttery
frame is not a reason to drop particle quality; three seconds under 45 FPS is.

```gdscript
extends Node


var __fpslow_1: float = -1.0


func __fps_below_for_1(limit: float, seconds: float) -> bool:
	var now: float = Time.get_ticks_msec() * 0.001
	if Engine.get_frames_per_second() >= limit:
		__fpslow_1 = -1.0
		return false
	if __fpslow_1 < 0.0:
		__fpslow_1 = now
		return false
	return now - __fpslow_1 >= seconds


func _process(delta: float) -> void:
	if __fps_below_for_1(45.0, 3.0):
		particle_quality = 0
```

**29. Time the work you suspect.** Start Measuring and Stop Measuring wrap the rows in between. The
name is free text, so "spawn wave" and "rebuild nav graph" read as themselves in the report.

```gdscript
extends Node


func _on_wave_due() -> void:
	var __starts_1: Dictionary = get_meta(&"__ef_span_starts", {}) as Dictionary
	__starts_1["spawn wave"] = Time.get_ticks_usec()
	set_meta(&"__ef_span_starts", __starts_1)
	spawn_wave(current_wave)
	var __starts_2: Dictionary = get_meta(&"__ef_span_starts", {}) as Dictionary
	var __span_2: float = float(Time.get_ticks_usec() - int(__starts_2.get("spawn wave", Time.get_ticks_usec()))) / 1000.0
	var __stats_2: Dictionary = get_meta(&"__ef_spans", {}) as Dictionary
	var __row_2: Array = __stats_2.get("spawn wave", [0.0, 0, 0.0, 0.0]) as Array
	__stats_2["spawn wave"] = [float(__row_2[0]) + __span_2, int(__row_2[1]) + 1, maxf(float(__row_2[2]), __span_2), __span_2]
	set_meta(&"__ef_spans", __stats_2)
```

**30. Prove an optimization worked with a number.** Average Measured is the figure to quote. Peak
Measured is the one the player actually felt, and the two often disagree.

```gdscript
extends Node


func _on_level_finished() -> void:
	print("avg ", (float(((get_meta(&"__ef_spans", {}) as Dictionary).get("spawn wave", [0.0, 0, 0.0, 0.0]) as Array)[0]) / maxf(float(((get_meta(&"__ef_spans", {}) as Dictionary).get("spawn wave", [0.0, 0, 0.0, 0.0]) as Array)[1]), 1.0)), " peak ", (float(((get_meta(&"__ef_spans", {}) as Dictionary).get("spawn wave", [0.0, 0, 0.0, 0.0]) as Array)[2])))
```

**31. Choose a Time Slicer budget from measurement instead of guessing.** Measure the batch first,
then set the budget to something the measurement supports.

```gdscript
extends Node


func _on_ready_to_tune() -> void:
	TimeSlicer.set_frame_budget((float(((get_meta(&"__ef_spans", {}) as Dictionary).get("batch", [0.0, 0, 0.0, 0.0]) as Array)[2])) * 1.2)
```

**32. Print the whole report at the end of a level.** Log Measurements walks every name you measured
and prints last, average, peak and sample count, which is the block you paste into a bug or a devlog.

```gdscript
extends Node


func _on_level_finished() -> void:
	for __key_1: Variant in (get_meta(&"__ef_spans", {}) as Dictionary):
		var __row_1: Array = (get_meta(&"__ef_spans", {}) as Dictionary)[__key_1] as Array
		print("%s: last %.2fms  avg %.2fms  peak %.2fms  (%d samples)" % [str(__key_1), float(__row_1[3]), float(__row_1[0]) / maxf(float(__row_1[1]), 1.0), float(__row_1[2]), int(__row_1[1])])
```

**33. Reset the measurements between runs.** A soak test is only readable if each run starts from
zero, otherwise the average creeps up and hides the regression you are hunting.

```gdscript
extends Node


func _on_run_started() -> void:
	set_meta(&"__ef_spans", {})
	set_meta(&"__ef_span_starts", {})
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
  the game, but the row comes back as a different action.
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
- **A trail lives on the node the row runs on.** Two sheets on the same node share a trail called
  "vy"; the same name on a different node is a different trail. That is usually what you want, and it
  is worth knowing before you wonder why the enemy's trail is empty.
- **Keep is a count of samples, not seconds.** At 60 FPS a Keep of 120 is two seconds. Change the
  framerate and the same Keep covers a different stretch of time.
- **An empty trail's lowest is `INF`.** So is its highest, as `-INF`. A comparison against a trail
  nobody has filled yet is false, which is the safe answer, but do not print the number raw into a HUD.
- **Save Trail To CSV needs a `user://` path.** A `res://` path is read-only in an exported game, so
  the file silently never appears for the playtester whose data you actually wanted.
- **Both performance conditions need Every Frame.** Frame Took Longer Than asks about the frame it is
  evaluated on, and FPS Below For keeps a clock that only stays honest if the row is reached each frame.
- **Stop Measuring without a Start reads as zero, not as an error.** A stopwatch you forgot to start
  files a 0 ms sample, which quietly drags the average down. If a measurement looks impossibly good,
  check that both rows actually run on the same path.
- **Nothing here displays itself.** A measurement is only visible where you send it: Log Measurements,
  a label, or the Debug Overlay pack. No row grows a chip and no panel turns itself on.

## Reading the trace: hit counts and "Why didn't this fire?"

Everything above prints. This section is about the two readouts that print nothing: they are
**lenses over the Event Trace** you pick up and put down, and they add no rows, no vocabulary and no
text to your sheet. With both of them off - which is how a fresh install ships - a sheet looks
exactly like the sheet you wrote:

![The sheet with the lens off](../images/hit-counts-off.png)

Tick **View > Row Hit Counts** and the same sheet grows a count in the **left margin only**. The
cells are untouched; compare them line for line with the picture above:

![The same sheet with Row Hit Counts on](../images/hit-counts-on.png)

![The left margin at four times life size with the lens off: nothing but the event number](../images/hit-counts-off-margin.png)

![The same margin with Row Hit Counts on: the count chip stacked under the number](../images/hit-counts-on-margin.png)

The margin says three things: a blue `x3`-style chip for a row that has fired, a **warm** chip for
the busiest rows of the run, and a muted `x0` plus a **dim rail** down the edge for a row that has
not fired once since Run. The chip is a glance - the exact number ("fired 1,431 times since Run -
hot") is in the tooltip when you hover the event number.

To use any of it: **Tools > Event Trace (live highlight)** (it turns Live Values on too), recompile,
and run the game. **Tools > Reset Hit Counts** starts the tally over without restarting the game.
A new Run resets it automatically.

### Use cases

1. **"Is this event even running?"** Hover its number. No toggle, no mode, nothing left behind - the
   tooltip either names a count or stays silent because nothing has run yet.
2. **Find the dead branch in a state machine.** Turn the lens on after a play session and scroll: the
   rows wearing `x0` and a rail are the states you never entered.
3. **Prove a trigger is wired.** A trigger row that stays at `x0` while you do the thing that should
   fire it has a wiring problem, not a logic problem - that is a different afternoon of debugging.
4. **Catch a sub-event that lost its Trigger Once.** A row you expected to fire twice wearing the
   run's warm tint is the per-frame leak, found by looking rather than by profiling.
5. **Balance by watching which branch dominates.** Run the loot or dialogue sheet for a minute and
   read the counts: the branch with the biggest number is the one players actually see.
6. **Check coverage after a refactor.** Play through the level once, then look for margins that never
   lit: those are the rows your playtest did not touch.
7. **Teach "every tick".** Put a beginner in front of one Every Frame row with the lens on and let
   them watch the number climb. It explains the frame loop in about four seconds.
8. **Compare two runs of the same fight.** Reset Hit Counts, fight it the other way, and read the
   difference instead of guessing at it.

### Why didn't this fire?

Right-click one event row you are stuck on and pick **Why didn't this fire?**. A panel opens for
**that row only** and reports each of its conditions: which were true, which were false, and the
value each one actually saw.

![The Why didn't this fire? panel](../images/why-didnt-fire.png)

It reads the values your game is already streaming (Live Values), so it needs a running game - and
when there is not one it says so in a plain line instead of showing you a table of confident
nonsense. A condition that reads the node rather than a sheet variable (`Is on floor`, a behaviour's
own state) is reported as **not observable from here**, never guessed at. Nothing is written to any
cell, and closing the panel leaves nothing behind.

More use cases:

9. **The three-condition AND you are sure about.** One of them is false, the panel marks which, and
   the argument ends.
10. **Distinguish "never arrived" from "rejected".** A trigger row with no false condition did not get
    its signal; that sends you to the connection, not to the logic.
11. **Cooldowns, where the remaining value is the interesting fact.** `cooldown <= 0.0` reads false
    and the panel shows you the 0.31 it saw.
12. **Read a stranger's sheet by watching it decide.** Open the panel on the row you do not
    understand and step the game; the verdicts explain the row faster than the code does.
13. **Teach boolean AND.** Three conditions, one false, one obvious conclusion - to someone who has
    never written a line of code.

### Tips for these two

- **They are off, and they stay off.** No lens turns itself on, and neither one survives as a mark on
  the sheet. A screenshot of a sheet with the lens off is identical to one taken before the feature
  existed.
- **Counts need Event Trace, not just Live Values.** Without the trace the game streams no fired-event
  windows, and the margin correctly stays empty rather than showing zeros it cannot vouch for.
- **`x0` means "not since this Run".** Reset Hit Counts, or a new launch, is what the "since" refers to.
- **The chip abbreviates; the tooltip does not.** `1k` in the margin is `fired 1,431 times` on hover.
- **The panel explains conditions, not actions.** If every condition is true and the row still did not
  run, look at its trigger, or at an enclosing group that is switched off.

## Editing the game while it runs

Changing a number and seeing it in the running game is the jam loop, and the engine has always been
able to reload a script into a live game. What was missing was a sheet that asks it to.

While a game is running, an edit to the open sheet puts one thing on the status strip:

```
⟳ Apply to running game (Ctrl+Alt+S)
```

Pressing it saves the sheet - which writes its script - and asks the running game to reload that
script. The rows you changed then **pulse once** on the canvas and in the Event Trace, so you can see
exactly what you just changed land rather than wondering whether it did. Whatever instance state the
engine keeps across a script reload is kept; nothing here promises more than that.

Two changes a live reload cannot carry, and the strip says which one instead of half-applying:

- **a variable whose TYPE changed** - the running instance is still holding a value of the old type;
- **a function that was removed** - something may be standing inside it right now.

In both cases the strip reads *"This change can't be applied to the running game: … Restart to pick
it up."* and a **Restart** button appears beside it. Everything else - new variables, changed values,
new and rewritten functions, new and rewritten events - reloads.

`View ▸ Auto-apply while debugging` turns the ⟳ into no gesture at all: every edit lands the moment
you make it, and a change that cannot be reloaded still stops and says so. Paused at a row (F9), an
edit applies when the game resumes, and the strip says that rather than looking inert. With no game
running, nothing appears at all: a button that can never do anything is worse than no button.

## Recording a play as a test

`Tools ▸ Replay Recorder…` turns the thing you just did into the cheapest regression net a small team
has.

1. **⏺ Record.** The open sheet is switched to a debug compile that reports every control the player
   presses or releases, with the frame it happened on. Save and run.
2. Play. The take fills in, in the sheet's own words: `simulate control jump pressed at frame 12`,
   `simulate control jump released at frame 19`.
3. **⏹ Stop**, then add the checkpoints you actually care about - *named*, what to *read*, what it
   *should be*, and at which frame: `expect hp = 90 at frame 300`.
4. **Save as Test Sheet…**

What comes out is an **ordinary Test sheet**. It is readable, editable, diffable and reviewable, and
it is replayed by the same runner that runs every other test - `Tools ▸ Run Tests…` here, or
headlessly with the rest in CI. A checkpoint that fails names the frame it drifted on, because
"expected 90, got 74" cannot be reproduced and "at frame 300" can.

Four rows carry a recording, and you can write them by hand like any others: **Wait Until Frame**,
**Simulate Control Pressed At Frame**, **Simulate Control Released At Frame** and **Expect At Frame**.
Frame 0 is the frame the first of them ran on, so a replay says the same thing however long the
engine had been up.

Only controls are recorded, never raw device events: a mouse jiggle cannot be replayed, and a
recording that quietly kept something it could never play back would be a recording that lies. The
recording instrumentation is a debug compile like Live Values and the Event Trace, so the Project
Doctor reminds you if it is still switched on in a committed script.
