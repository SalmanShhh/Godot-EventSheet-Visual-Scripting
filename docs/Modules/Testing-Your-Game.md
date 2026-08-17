# Testing Your Game

A **Test sheet** is a sheet whose whole job is to make claims about your game and report which ones
held. Same rows as always - a trigger, some conditions, some actions - except the actions assert
instead of shoot, and the run ends in a verdict rather than a score. **Assert That** and
**Assert Equal** record a claim with a readable message. **Expect Signal** gives something a deadline
to happen by. **Watch For Signal** waits and lets the next rows decide what each outcome means.
**Pass Test** and **Fail Test** say it outright. **Load Scene Under Test** gives the test something
to be about.

These verbs are builtin vocabulary, so they are in the picker with nothing to enable and nothing to
attach. They compile to plain Godot - `set_meta`, `get_meta`, `connect`, `await get_tree().process_frame` -
with no runtime library behind them, so a test script keeps working after the plugin is removed.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Verb reference](#verb-reference)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Save round-trips** - the first thing worth pinning in any project, and the easiest to break.
- **Physics that must still behave** - gravity pulls, a jump clears the gap, a body lands.
- **Signals that must fire** - and, just as often, signals that must NOT fire.
- **Regression before a release** - run the claims before Publish New Version, not after.
- **Seeded balance** - a damage formula that stays inside a range across a thousand rolls.
- **Smoke tests after an engine upgrade** - does every scene still load at all?
- **Bug-first fixing** - turn the report into a failing test, then make it pass.
- **CI** - one headless command, an explicit verdict line, and an exit code to gate on.

## Core concepts

- **A Test sheet is a sheet type.** Sheet > Sheet Type… > **Test**. It compiles to an `extends Node`
  script that declares `signal test_started(test_name: String)` and carries the marker comment
  `## @ace_test_sheet` on a line of its own. The marker is how a runner finds the file: there is no
  registry to keep in sync, and a test copied into another project is still a test.
- **The runner starts the test, the test answers.** **On Test Start** is a real signal-backed
  trigger, not a bare hook: the runner emits `test_started` with the file's name, which arrives as
  the row's `test_name` parameter and is yours to use in messages.
- **Claims are recorded, not printed.** Every assert appends `[name, passed, message]` to the test
  node's own metadata, so the report can be read back by the headless command, the editor panel, or
  anything else. A failing claim also `push_error`s, so a test you play by hand still says what broke.
- **A failure must say why.** Assert Equal carries BOTH values ("expected 3, got 2"), Expect Signal
  says "expected within 2.00s, never fired", and Fail Test takes a reason. A test that cannot say why
  it failed is the one thing a test may not be.
- **A deadline is never hidden in a trigger head.** "On signal within 2 s" would make the interesting
  outcome - it never fired - invisible. **Watch For Signal** is an ordinary wait instead, and the two
  outcomes read back on the following rows as **Watch For Signal Succeeded** and
  **Watch For Signal Timed Out**, keyed by the signal's name.
- **Silence is a failure.** A test that recorded nothing at all is reported as
  "no claims were recorded; this test asserted nothing". A crashed test must never look like a clean
  run, which is also why every run ends with the literal line `All tests passed.` or
  `Some tests failed.` instead of an absence of failures. A run that found NO test sheets is a
  failure for the same reason: a project whose tests all stopped being found would otherwise read
  exactly like a project whose tests all passed.
- **A waiting row is not a quiet one.** **Expect Signal** and **Watch For Signal** suspend for as
  long as their deadline allows, recording nothing while they wait. The runner knows the difference
  between "still waiting" and "nothing more to say", so a test is never cut off mid-wait and its
  pending claims never go unreported.
- **The report is a window, never row chrome.** Nothing is drawn on your sheets. With the Run Tests
  window closed, the canvas is byte-identical to what it was before the run.

## Verb reference

Ships as is the template the row compiles to, so you can see exactly what lands in your `.gd`. Where
a template carries `{uid}`, the editor bakes a short per-row id into the name when you drop the row,
so two claims in the same script keep separate locals.

### Testing: starting a test

| Verb | What it does | Ships as |
|------|--------------|----------|
| On Test Start | Runs when a test runner starts this sheet, with the test's name as a parameter | `test_started.connect(_on_test_started)` in `_ready`, plus `func _on_test_started(test_name: String)` |
| Load Scene Under Test | Instantiates a scene, adds it under the test node so it really runs, and remembers it under a short name | `(load({scene_path}) as PackedScene)` then `add_child(...)` then a `set_meta` under the name |
| Scene Under Test | The node a Load Scene Under Test row loaded under this name | `(get_meta(&"__ef_scene_" + str({as_name}).to_utf8_buffer().hex_encode(), null) as Node)` |

### Testing: making a claim

| Verb | What it does | Ships as |
|------|--------------|----------|
| Assert That | Records a pass when a check is true, and a failure saying "expected true, got false" when it is not | `var __assert_ok_{uid}: bool = bool({claim})` then a `set_meta` append to the report |
| Assert Equal | Records a pass when two values match; the failure carries both ("expected 3, got 2") | the two values into locals, `==`, then the same report append |
| Expect Signal | Waits for a signal and records the verdict itself, including "expected within 2.00s, never fired" | a one-shot `connect` (its arguments unbound) then a deadline loop on `await get_tree().process_frame` |

### Testing: waiting for something to happen

| Verb | What it does | Ships as |
|------|--------------|----------|
| Watch For Signal | Waits until a signal fires or the time runs out, and records which - it states no verdict of its own | the same one-shot connect and deadline loop, then `set_meta(&"__ef_watch_" + …, 1 if fired else 2)` |
| Watch For Signal Succeeded | True when the matching watch saw its signal fire in time | `int(get_meta(&"__ef_watch_" + str({signal_name}).to_utf8_buffer().hex_encode(), 0)) == 1` |
| Watch For Signal Timed Out | True when the matching watch ran out of time without the signal firing | `int(get_meta(&"__ef_watch_" + str({signal_name}).to_utf8_buffer().hex_encode(), 0)) == 2` |

### Testing: stating the verdict

| Verb | What it does | Ships as |
|------|--------------|----------|
| Pass Test | Records a pass under this name and marks the test finished, so a runner stops waiting on it | a report append with `true`, then `set_meta(&"__ef_test_finished", true)` |
| Fail Test | Records a failure with its reason and marks the test finished | a report append with `false` and the reason, then the same finished flag and a `push_error` |

## Use cases

**1. The first test in any project: a save round-trips.** Write the state, change it, load it back,
and claim the number that came back is the number that went out.

```
On Test Start (test_name)
  -> Save Game  "slot1"
  -> Set  score  to  0
  -> Load Game  "slot1"
  -> Assert Equal  "score survives a save"  score,  120
```

**2. Gravity actually pulls.** Load the player scene, let the world run, then claim it fell.

```
On Test Start (test_name)
  -> Load Scene Under Test  "res://player.tscn"  as  "P"
  -> Wait  0.5
  -> Assert That  "gravity pulls down"  Scene Under Test("P").position.y > 100
```

**3. A signal that must fire.** Expect Signal states its own verdict, deadline included.

```
On Test Start (test_name)
  -> Load Scene Under Test  "res://player.tscn"  as  "P"
  -> Set  Scene Under Test("P").hp  to  0
  -> Expect Signal  "death fires on zero hp"  "died" on Scene Under Test("P") within 2.0
```

**4. A signal that must NOT fire.** Here timing out is the pass, which is exactly why the watch
does not state a verdict of its own.

```
On Test Start (test_name)
  -> Watch For Signal  "hurt" on Scene Under Test("P") for 1.0

Watch For Signal Timed Out  "hurt"
  -> Pass Test  "no damage while invulnerable"

Watch For Signal Succeeded  "hurt"
  -> Fail Test  "no damage while invulnerable",  "took damage during the i-frames"
```

**5. Does the scene still load?** After an engine or plugin upgrade, one row per scene finds the
broken one in seconds - a scene that will not load is recorded as a failure naming its path.

```
On Test Start (test_name)
  -> Load Scene Under Test  "res://levels/forest.tscn"  as  "forest"
  -> Load Scene Under Test  "res://levels/cave.tscn"  as  "cave"
  -> Assert That  "the forest instantiated"  Scene Under Test("forest") != null
```

**6. Balance stays inside a range.** Seed the roll so the answer is the same on every machine.

```
On Test Start (test_name)
  -> Set Random Seed  12345
  -> Repeat  1000  times
       -> Add  roll_damage()  to  total
  -> Assert That  "average damage sits in band"  (total / 1000.0) > 8.0 and (total / 1000.0) < 12.0
```

**7. A pool never grows past its cap.** Not something you can eyeball; exactly something you can
assert.

```
On Test Start (test_name)
  -> Repeat  20  times
       -> Take From Pool  "bullets"
  -> Assert Equal  "the pool respects its cap"  pool_size("bullets"),  8
```

**8. Quest transitions.** Complete an objective and claim the chain moved on - the thing you want
pinned before you refactor the quest system.

```
On Test Start (test_name)
  -> Complete Objective  "find the key"
  -> Assert Equal  "the chain advances"  current_objective(),  "open the door"
```

**9. Bug-first fixing.** Turn the report into a failing test before touching the code. The claim's
name is the bug title, so the report reads like the issue tracker.

```
On Test Start (test_name)
  -> Load Scene Under Test  "res://door.tscn"  as  "D"
  -> Call  Scene Under Test("D").interact
  -> Assert That  "#412 door opens without the key"  Scene Under Test("D").is_open == false
```

**10. Before Publish New Version.** Run the pack's tests, then publish - so the version you ship is
the version that passed.

```
On Test Start (test_name)
  -> Assert That  "the behavior exposes its verbs"  ScreenShake.has_method("shake")
  -> Assert Equal  "the default strength is unchanged"  ScreenShake.new().strength,  8.0
```

**11. Settings survive a reload.** Every option written, read back, and claimed - the fastest way to
catch a key you renamed in one place only.

```
On Test Start (test_name)
  -> Set Setting  "audio/music",  0.4
  -> Save Settings
  -> Load Settings
  -> Assert Equal  "music volume survives"  Get Setting("audio/music", 1.0),  0.4
```

**12. A boss's phases arrive in order.** Watch for each phase signal in turn; a phase that never
arrives names itself in the report instead of hanging the run forever.

```
On Test Start (test_name)
  -> Watch For Signal  "phase_two" on Scene Under Test("boss") for 5.0

Watch For Signal Succeeded  "phase_two"
  -> Pass Test  "the boss reaches phase two"

Watch For Signal Timed Out  "phase_two"
  -> Fail Test  "the boss reaches phase two",  "still in phase one after 5s"
```

**13. Autoloads are actually registered.** One claim per singleton beats a build that ships with one
unregistered.

```
On Test Start (test_name)
  -> Assert That  "GameState is registered"  get_node_or_null("/root/GameState") != null
  -> Assert That  "SaveSystem is registered"  get_node_or_null("/root/SaveSystem") != null
```

**14. Localisation coverage.** Load a locale and claim a handful of keys resolve to something other
than the key itself.

```
On Test Start (test_name)
  -> Set Language  "fr"
  -> Assert That  "the start button is translated"  tr("UI_START") != "UI_START"
```

**15. A refactor's safety net.** Write the claims BEFORE moving rows around. The report, not your
memory, tells you when the refactor is finished.

```
On Test Start (test_name)
  -> Assert Equal  "damage formula unchanged"  damage(10, 2),  8
  -> Assert Equal  "crit formula unchanged"  damage(10, 2, true),  16
```

**16. CI on every push.** One line in the pipeline, and a red build the moment a claim stops holding:

```
godot --headless --path . --script tools/run_test_sheets.gd
```

It prints a heading per test, a line per claim, the totals, and then `All tests passed.` or
`Some tests failed.`, exiting 0 or 1 to match. If it finds no Test sheets at all it says so by name
and ends `Some tests failed.` with status 1 - a green build on zero tests is the one result CI must
never give you. Point it elsewhere with `-- --root res://my_tests` and give slow tests more room
with `-- --timeout 10`.

**17. The same run, in the editor.** Tools > Run Tests… runs every Test sheet in the project and
shows the verdict, a card per test with its claims, and the whole report as copyable text. Same
words, same order, because both shells read the same runner.

### Other use cases

**Input remapping.** Rebind an action in the test, then claim the InputMap really carries the new event, so a settings screen cannot silently stop saving.

**A shop's arithmetic.** Buy, sell and buy again, then claim the wallet holds exactly what the sums say - the bug class no playtester reproduces reliably.

**Scene budget.** Load a level and claim its node count sits under a number you chose, so a level that quietly triples in size announces itself.

**Dialogue reachability.** Walk a dialogue tree from its root and claim every ending is reachable, which is a loop plus one Assert That rather than an afternoon of clicking.

**Determinism.** Run a seeded simulation twice and claim both runs produced the same final state, the only practical way to catch an accidental `randf()` in shared logic.

## Tips and common mistakes

- **"No test sheets found."** The marker line is missing. Set the sheet's type to Test in
  Sheet > Sheet Type… and save, so the compiled `.gd` carries `## @ace_test_sheet`.
- **"no claims were recorded".** The test started but nothing asserted: the rows sit under a
  condition that never came true, or the event has no trigger at all (a bare event with no trigger
  emits nothing).
- **A test that hangs until the timeout** never said it was finished. End it with Pass Test or
  Fail Test, or let it record its last claim and fall quiet - the runner stops on either.
- **Claims that run before the scene is ready.** Load Scene Under Test adds the node this frame;
  physics has not run yet. Put a Wait (or a Wait Until with a deadline) between the load and the
  claims about movement.
- **Name the claim as the claim.** "gravity pulls down" reads as a report line; "test 3" does not.
  The name is what a failing build shows a teammate who has never opened the sheet.
- **One test file, one subject.** The runner names each test by its file, so `save_test` and
  `combat_test` produce a readable report while `misc_test` produces a shrug.
- **Assert Equal compares values, not identity.** Two Vector2s with the same numbers are equal; two
  different nodes never are. Claim something about a node's properties, not about the node.
- **Watch For Signal is keyed by the signal name**, so two watches on the same signal in one test
  overwrite each other. Watch one thing at a time, or use Expect Signal, which states its own verdict
  on the spot.
