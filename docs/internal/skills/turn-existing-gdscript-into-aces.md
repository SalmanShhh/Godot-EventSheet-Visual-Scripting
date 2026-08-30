---
name: turn-existing-gdscript-into-aces
description: Wrap GDScript you already wrote (methods, signals, autoloads, packs, sheet functions) as event-sheet vocabulary - actions, conditions, expressions and triggers - covering every authoring route, every code pattern the plugin supports, and the verification each one needs. Use when someone has working code and wants it droppable in a sheet.
---

# Turn existing GDScript into event sheet vocabulary

You have working code. This is how it becomes rows a non-programmer can read and drop.

Every rule below was checked against the code that enforces it, and the enforcing file is
named beside the rule so you can re-check it rather than trust this page. That matters more
here than usual: almost nothing in this pipeline fails loudly. A wrong annotation is
ignored, a wrong default compiles, a shadowed id publishes the other verb. It fails quietly,
in someone else's project, later.

---

## Step 0 - Decide WHAT KIND of thing the code is (the two models)

Every mistake in wrapped code that the gates cannot catch is a KIND mistake: a check written
as an action, an event written as a polled condition, an outcome hidden in a variable. Decide
this before you write an annotation, because the annotation only records the decision.

### The condition/action model (where it goes on the sheet)

The event sheet is a two-lane grid and every feature maps onto it - this project treats that
as a covenant, not a style:

- **Branching is a CONDITION.** A question the row asks, in the left lane. An `if` is ALWAYS a
  condition cell; it is never text inside an action ("do X, and if it failed then...").
- **An effect is an ACTION.** Something the row does, in the right lane. An action does; it
  does not decide.
- **A value is an EXPRESSION.** It lives inside a cell, never as its own row.
- **Iteration is a loop ROW** (a looping condition / pick filter), not a special block.
- **Structure mirrors code.** Nesting on the canvas IS nesting in the emitted GDScript, so a
  sub-event is a nested block; nothing is a text blob or a panel that hides logic.
- **Outcomes are read back as conditions or triggers, never as side-channel flags** a
  beginner must remember to check. `Cooldown Is Ready`, `Wait Timed Out`, `On Save Failed` -
  not "sets `gave_up` to true".

The test that catches you: can a beginner read the row as a sentence and tell, from the lane
and the badge alone, whether it asks or does? If a single verb both checks and acts, split it.

### The ACE model on Godot's primitives (which kind it is)

The four Construct-style kinds sit directly on Godot's own primitives, which is why ordinary
GDScript becomes vocabulary with so little ceremony:

| Kind | Godot primitive | Annotation | Reads as |
|---|---|---|---|
| **Trigger** | a `signal` (the row's head connects to it) | `@ace_trigger` on the signal line | "On <something happened>" |
| **Condition** | a method returning `bool` | `@ace_condition` (or inferred from `-> bool`) | a question |
| **Action** | a method returning `void` | `@ace_action` (or inferred) | a verb |
| **Expression** | a method or property returning a value | `@ace_expression` (or inferred) | a value in a cell |

The rule that decides trigger vs condition, and that people get wrong most:

> Something that **happens** is a trigger; something you **check** is a condition. If the code
> would emit a signal, or you find yourself polling for a change every frame, it is a trigger.

Triggers here are Godot signals, and they carry MORE than Construct's fixed trigger list:

- **Payload.** The signal's arguments become the trigger row's captured context and read back
  as values on that row (`signal load_failed(slot_index: int, reason: String)` gives the row
  `slot_index` and `reason`). Never deliver an outcome as a variable the handler must fetch;
  put it in the signal.
- **Awaitable.** Any signal can be waited for (`Wait For Signal`), so a trigger doubles as a
  join point in an async row.
- **Fan-out.** Group signals (`Connect Group Signal`, `call_group`) deliver one trigger to a
  whole family of nodes; the has_method seam packs use for decoupling is the same idea.
- **The reactive alternative.** A polled condition that has a real signal twin should point
  at it - the picker already shows a "reactive alternative" tip for shipped pairs
  (`ACEDescriptor.reactive_alternative`). When wrapping code, prefer emitting a signal over
  exposing a bool that callers must poll every frame.

Construct's FAKE triggers (green arrows that are really per-tick polls) have shipped answers -
`Trigger Once`, `Has Changed`, `Was Recently True`, the group-population edges - which turn a
polled state into a rising edge. Do not mint a new one of those; compose the shipped gate.

Where the shipped packs got it right, and you can copy the shape:

- `On Purchase Refused` / `On Save Failed` / `On Load Failed` - an OUTCOME as a trigger with
  the reason in the payload, so recovery can live in another event or another sheet.
- `Cooldown Is Ready` + `Start Cooldown` - a state check as a condition beside its effect.
- `On Save Needs Upgrade (save_data, from_version)` - a trigger firing at a precise moment,
  between reading and applying, with everything the handler needs as payload.

Only once you know the kind do the recipes below apply.

---

## Step 1 - Survey before you mint anything

Two names must be unique: the `ace_id` (hard requirement) and the display name (soft, but a
duplicate is a silent-wrong-answer trap - two identical rows in the picker, one of which
does something else).

Built-in ids and names are POSITIONAL arguments, not keyed fields:

```gdscript
F.make_descriptor("Core", "StartCooldown", "Start Cooldown", ACEDescriptor.ACEType.ACTION, ...)
#                 provider  ace_id          display_name
```

So grep for the candidate STRINGS, never for the words "ace_id" or "display_name":

```bash
grep -rn '"StartCooldown"\|"Start Cooldown"' addons/eventforge/registration/modules/ tools/pack_builders/ eventsheet_addons/
```

- `addons/eventforge/registration/modules/*.gd` - the built-in vocabulary.
- `tools/pack_builders/*.gd` - the behaviour packs' SOURCE (`eventsheet_addons/` is their
  compiler output; a pack edit belongs in the builder).
- `eventsheet_addons/**` - shipped packs, whose names live in `## @ace_name(...)` lines.

What the suite catches for you, and what it does not:

- `ACERegistry.find_duplicate_ids()` (`tests/duplicate_ace_id_test.gd`) fails the suite on a
  duplicate `provider_id::ace_id`. At load time `ACERegistry._ensure_builtin_cache` also
  pushes an error, because the later descriptor SHADOWS the earlier one in the picker index.
- Nothing checks display names across providers. `_disambiguate_reflected_name_collisions`
  (`addons/eventsheet/ace/ace_generator.gd`) only renames a REFLECTED property twin that
  collides with an authored verb inside the same provider, appending " (property)".

And survey the concept, not only the string. A large share of "new" ideas here turn out to
be shipped already under a different word: search `docs/REFERENCE-ENGINE-ACES.md` (generated
by `tools/vocabulary_doc.gd`) before writing anything.

---

## Step 2 - Choose the authoring route

| Your code is | Route | What you write | Ceiling |
|---|---|---|---|
| A script you can edit | `## @ace_*` comment annotations | doc-comment lines above each member | everything except per-row state and node scoping |
| The same script, and you want autocomplete | `static func _eventforge_register(reg: EventForgeRegistrar)` | typed chained calls | as above, minus starting values and looping |
| Third-party, generated, or otherwise un-annotatable | `EventSheets.register_simple_ace({...})` | a Dictionary from any `@tool` script | template + params only, session-scoped |
| Already a function in a sheet | publish the verb (ACE Studio / the verb row) | no code | full annotation set, written for you |
| Vocabulary that needs per-row state, `node_type`, or an edge gate | a descriptor: a module under `addons/eventforge/registration/modules/`, or an `EventForgeBridge` autoload | `F.make_descriptor(...)` chains | everything |

Details that decide the choice:

- **Zero-config scan.** Any `.gd` under `res://eventsheet_addons/` (recursive, sorted) is a
  provider the moment it is saved - `EventSheetAddonScanner.ADDON_DIRS`. The `class_name`
  becomes the `provider_id`; without one the PascalCased filename is used.
- **The registrar merges ONTO the comments, field by field, and explicit registrar calls
  win** (`EventSheetSemanticAnalyzer._merge_registrar_metadata`). Both dialects flow through
  one pipeline and produce identical definitions - pinned by `tests/registrar_provider_test.gd`.
  The registrar annotates EXISTING members; it does not create them.
- **The registrar cannot express three things** the comment dialect can: a starting value
  (`param()` reads only `hint` / `options` / `autocomplete` / `desc`), `@ace_looping`, and
  `@ace_expose_all`. Mixing dialects in one file is normal and supported.
- **`register_simple_ace`** appends to a static list that joins every registry refresh
  (`EventSheetACERegistry.refresh_from_sources` calls `EventSheets.simple_aces()`). Nothing is
  written to disk, so it lives exactly as long as the editor session that registered it.
- **A published sheet function emits its own annotations.** `SheetCompiler._emit_expose_annotations`
  writes `@ace_action` / `@ace_condition` / `@ace_expression` (chosen by return type), plus
  name, category, description, display template, param options/hints, icon, and
  `@ace_codegen_template("$Class.fn({args})")`. A compiled pack IS a provider script, which
  is why publishing needs no separate registration step. An unexposed function emits
  `## @ace_hidden`, because reflection would otherwise publish every public method.
- **Only descriptors carry `.stateful(...)`, `.evaluated_last()` and `node_type`.** No
  annotation and no registrar verb exists for any of them (checked against
  `EventSheetSemanticAnalyzer.KNOWN_ANNOTATIONS` and `EventForgeRegistrar`).

---

## Step 3 - The annotation reference, and the shortcut that beats it

**The shortcut first.** Right-click any ACE in the picker: **Copy annotation stub** /
**Copy registrar snippet**. The stub is generated from the live definition
(`addons/eventsheet/editor/ace_annotation_stub.gd`), so you get a correct example of the
exact feature you are copying, including labeled options, starting values, captions, looping
and the shipped node-target form. When a dialect CANNOT express something, the stub leads
with plain `#` notes saying so and hands over the descriptor chain that can.
`tests/ace_authoring_stub_test.gd` pastes emitted stubs back into a provider script and
re-reflects them, so "the stub works when pasted" is a gate, not a hope.

### Member-level annotations (read by `EventSheetSemanticAnalyzer._build_overrides`)

| Annotation | Effect |
|---|---|
| `@ace_action` / `@ace_condition` / `@ace_expression` / `@ace_trigger` | Force the kind. Without one: `bool` return = condition, no return = action, any other return = expression. |
| `@ace_looping(iterator)` | Looping condition. The method returns a collection and the event's actions run once per item. Forces the CONDITION kind; the iterator defaults to `item` when the value is not a valid identifier. |
| `@ace_name(Text)` | Display name. |
| `@ace_category(Text)` | Picker category (`Parent: Sub` nests one level). |
| `@ace_description(Text)` | Tooltip text. Plain `##` prose above the member does the same thing; the annotation only matters when the picker text must differ from the code docs. |
| `@ace_display_template(text)` | The row sentence, with `{param}` slots. |
| `@ace_codegen_template(code)` | The emitted GDScript. You own the whole template then. |
| `@ace_param(id, hint: h, options: a\|b, default: v, autocomplete: a\|b, desc: "text")` | Everything about one parameter. |
| `@ace_param_hint(id hint)`, `@ace_param_options(id a,b,c)`, `@ace_param_autocomplete(id a,b)` | The older split forms, still parsed. |
| `@ace_hidden` | Hide from the picker. |
| `@ace_featured` | Bold, floated to the top of its category. |
| `@ace_deprecated("why", "successor_ace_id")` | Keeps compiling in existing sheets, hidden from the picker, flagged on hover. |
| `@ace_icon(path)` | Picker icon. |

### Class-level (above `class_name` / `extends`)

`@ace_expose_all` (publish every public member, instance-backed) or `@ace_expose_all(node)`
(publish node-targeted, `$Provider.method()`); `@ace_category` and `@ace_icon` as pack-wide
defaults that every member without its own inherits; `@ace_tags(a, b)` for search.

`@ace_requires(...)`, `@ace_version(x.y.z)`, `@ace_author("Name")`, `@ace_help("https://...")`
are pack METADATA. They are not read by the analyzer's override pass: the Project Doctor
regex-reads `@ace_requires` (`addons/eventforge/project_doctor.gd`) and Sheet > Publish New
Version rewrites `@ace_version` (`addons/eventsheet/ace/annotation_writer.gd`).

### Three tokens that are not what they look like

- `@ace_family`, `@ace_group`, `@ace_region` are SHEET-STRUCTURE markers the compiler writes
  and the importer / block registry read back. They are not member-authoring knobs.
- `@ace_includes`, `@ace_uses`, `@ace_family_var`, `@ace_family_member` appear ONLY in
  `KNOWN_ANNOTATIONS`, which is a typo filter, not a feature list. No code reads them, so
  writing one does nothing and warns nothing.
- `@ace_internal` is honoured by the ƒx **Self ▸ Behaviours** derivation
  (`addons/eventsheet/editor/self_expressions.gd`) but is NOT in `KNOWN_ANNOTATIONS`, so the
  analyzer also prints "ignores unknown ACE annotation(s): @ace_internal (typo?)". Use
  `@ace_hidden` to hide from the picker.

### The grammar rules that bite

Verified by round-tripping real annotations through the analyzer:

- **An annotation value is read VERBATIM** between its first `(` and its last `)`, with one
  surrounding quote pair trimmed. Nothing unescapes it. So write
  `@ace_codegen_template("play(&"walk")")` - a backslash-escaped `\"` ships the BACKSLASH
  into your emitted GDScript.
- **One annotation is one line.** A `\n` inside it stays two literal characters, so the
  comment dialect cannot carry a multi-line template at all. Use the registrar's
  `.template()` (a real GDScript string) or a descriptor, and indent nested lines with tabs.
- **`@ace_param` splits on commas OUTSIDE quotes**, and trims ONE quote pair off `default:`.
  Consequences: `default: 1.0` ships bare; `default: "Vector2(0, 0)"` needs the quotes to
  protect the comma; a value that IS a string literal needs a second pair, `default: ""idle""`,
  or the row starts on the bare identifier `idle`.
- **Option labels have no escape.** `options: a=Alpha|b=Beta`, and a key containing `=` ships
  quoted (`"<="=at most`), but a label containing a comma has no one-line form. The compiler's
  own emitter degrades such a label to its bare key rather than emitting a spec that parses
  into garbage (`SheetCompiler._param_option_text`); do the same.
- **`hint: comparison`** expands to the canonical six operators, each labeled in English, and
  seeds `==` so the row reads as a sentence on drop.
- **Param LABELS come from the id.** No annotation sets a parameter's display name, so
  `func aim(mode)` shows "Mode". Name the argument the way you want the field labeled.

---

## Step 4 - The recipes, one per code pattern

### A plain method

```gdscript
## Adds coins to the purse.
## @ace_action
## @ace_name(Give Coins)
## @ace_param(amount, hint: expression, default: 10)
func give_coins(amount: int) -> void:
	coins += amount
```

The method's own GDScript default is used when no `default:` is annotated
(`EventSheetACEGenerator._build_parameter_definitions`), so `func fire(power: float = 25.0)`
already lands reading 25.0.

### A computed check

```gdscript
## @ace_condition
## @ace_name(Can See Player)
func can_see_player() -> bool:
	return _ray.is_colliding()
```

A `bool` return alone would classify it; the annotation is there for the name.

### State that must survive between frames - the cheap way first

**Stateless, keyed by name.** The shipped cooldown trio does this and needs no compiler
involvement, no `{uid}`, and no gate exemption:

```gdscript
# Start Cooldown  (action)
set_meta(&"__ef_cool_" + str({name}), Time.get_ticks_msec() + int(maxf({seconds}, 0.0) * 1000.0))
# Cooldown Is Ready  (condition)
Time.get_ticks_msec() >= int(get_meta(&"__ef_cool_" + str({name}), 0))
```

An unset key reads as ready because `get_meta` takes a default. The state is per node and
addressed by a name the user types, so two cooldowns never collide.

**Stateful members** - descriptors only, `.stateful(member, prelude, on_true)`:

```gdscript
F.make_descriptor("Core", "EveryXSeconds", "Every X Seconds", ACEDescriptor.ACEType.CONDITION,
	"__every_{uid} >= maxf({seconds}, 0.001)", "", [...], "Time", "Every {seconds} seconds")
	.stateful("var __every_{uid}: float = 0.0",
		"__every_{uid} += get_process_delta_time()",
		"__every_{uid} = fmod(__every_{uid}, maxf({seconds}, 0.001))")
```

Three rules come with it:

1. The member compiles INTO the sheet class, once per applied row, so every identifier it
   declares must carry `{uid}`.
2. `{uid}` is baked at APPLY time by the dock (`addons/eventsheet/editor/dock/ace_apply.gd`)
   and NEVER by the compiler. A pack builder shipping a pre-baked descriptor must call
   `.replace("{uid}", <stable id>)` itself, or a literal `{uid}` sails into emitted GDScript.
3. `tests/builtin_ace_compile_test.gd` compiles every ACE alone inside its host class. A
   sheet-synthesized helper cannot compile alone, so the ace_id belongs in that test's
   `NOT_STANDALONE` list or the gate fails, correctly.

An edge gate ("was I reached last tick?") adds `.evaluated_last()`, which hoists the term to
the end of the emitted `and` chain wherever the user puts the cell. A stateful condition can
never be inverted, and only makes sense under a per-frame trigger.

### Dropdowns, and the single-pass rule

Options are `value=Label` in the comment dialect and `{"key":, "label":}` dicts in code. The
label is what the menu READS; the key is what the row INSERTS.

**Substitution is a single left-to-right pass.** An option value can therefore never contain
`{another_param}` - it is emitted literally, not substituted. When a dropdown must choose
between several expressions, index an inline array by the option:

```gdscript
"([global_position.distance_to({other}.global_position), \
absf(global_position.x - {other}.global_position.x), \
absf(global_position.y - {other}.global_position.y), \
absf(global_position.x - {other}.global_position.x) + absf(global_position.y - {other}.global_position.y), \
maxf(absf(global_position.x - {other}.global_position.x), absf(global_position.y - {other}.global_position.y))][{metric}]) <= maxf({distance}, 0.0)"
```

That is the shipped `IsWithinDistanceMetric` shape: five geometries in one row, still a
plain, dependency-free expression, with `metric` a labeled dropdown over `0`..`4`. The array
must hold one entry per option - an option the array cannot index crashes the moment the
condition is evaluated, and nothing at authoring time will tell you.

### Asynchronous actions

Put `await` in the template. `Wait` is literally
`await get_tree().create_timer({seconds}).timeout`. The compiler notices
(`SheetCompiler._subtree_awaits` matches an `await ` in the template, a row marked awaited,
or one of `_COROUTINE_ACE_IDS`) and splits an awaiting event into its own coroutine, called
fire-and-forget so sibling events never freeze behind it. For a multi-statement action only
the LAST emitted line is awaited. Budget-style awaits belong in one-shot triggers, never in a
re-firing per-frame event where overlapping suspended runs would duplicate work.

### Triggers from signals

A `signal` becomes a trigger; the display name is `"On " + humanized`
(`EventSheetSemanticAnalyzer.build_trigger_display_name`), so name it `quest_completed`, not
`on_quest_completed`, unless you want a row reading "On On Quest Completed". A descriptor
trigger has no template at all: it names the signal in `signal_name` and the compiler wires
the connection.

### Looping conditions

```gdscript
## Loops the event's actions once per applied buff id.
## @ace_looping(buff_id)
## @ace_name(For Each Buff)
func each_buff() -> Array:
	return _buffs.keys()
```

Applying it creates a pick filter over the returned collection, so the loop lane,
frame-spreading and round-trip all behave like a built-in For Each. Return the collection,
not a bool.

### Node-scoped and host-targeted templates

A node-scoped descriptor's SHIPPED template is not the one you authored. Registration
(`EventForgeBuiltinACEs._make_node_scoped_targetable`) prefixes every line with `{target.}`
and appends an optional "On node" param, so `queue({animation})` ships as
`{target.}queue({animation})`. Two consequences:

- A test asserting your authored string fails. Assert the post-transform form.
- The prefix is added ONLY when every line is a plain member operation. A template leading
  with `not` / `and` / `is` / `in` / `self` / `super`, with `$` / `%` / `@`, with a statement
  keyword, or with anything that is not an identifier gets no target at all - which is
  correct, since `$Node.not thing.is_empty()` does not parse.

Behaviour packs use the same idea with `{host.}` / `{host}`: in behaviour mode the compiler
folds in the host accessor, and on every other sheet the key is absent so `{host.}` drops to
nothing and the call stays bare (`addons/eventforge/compiler/action_codegen.gd`). Adding it
never changes existing output.

### Expressions

An expression template is inlined wherever a value is allowed, so it must be a single
expression and null-safe on its own: prefer `FileAccess.get_file_as_string({path})` (returns
`""` on error) over an `open(...)` that can return `null`. A method whose return type is
neither `bool` nor `void` classifies as an expression with no annotation at all.

### Persistence between runs

Do not invent a save file. Marking a sheet VARIABLE "Remember Between Runs" makes the
compiler append a persistence trio at the tail of the file
(`SheetCompiler._append_remembered_persistence`): an `@onready` boot member calling
`_ef_recall_remembered()`, which loads `user://remembered.cfg` (section = the sheet's custom
class name, else `vars`) and connects `tree_exiting` to `_ef_store_remembered()`. It is
name-addressed: a sheet that already carries a `_ef_recall_remembered` function gets no
second copy, so reopen-and-resave stays byte-identical. It needs a Node host, and it works
treeless in tests because `ConfigFile` does.

### The two lambda traps

- **Never bake a lambda's variable name into a frozen template.** A baked `x` silently
  SHADOWS a sheet variable named `x`: GDScript warns about nothing, the row compiles clean
  and computes the wrong answer. The shipped `Filter` / `Map` / `Reduce` ACEs expose the
  element name as a parameter (default `x`, and `acc` for the accumulator) precisely for
  this. Where the author never writes the body, use a `__`-prefixed name instead.
- **A single-line lambda needs a terminating newline.** A script whose LAST line is one fails
  to parse with "Expected end of file". Real compiler output always ends with a newline, so
  this only bites hand-assembled test sources - which is where it bit
  (`tests/array_functional_aces_test.gd`).

---

## Step 5 - Verify the way the project verifies

1. **Defaults must stand alone.** `tests/builtin_ace_compile_test.gd` fills every parameter
   with its DEFAULT and compiles the ACE inside its declared host class. A default naming
   `global_position` on a plain `Node`, a bare `target`, or `velocity` fails - correctly,
   because the default is what the row shows the moment it is dropped.
2. **Parse-check anything generated.** `"$GODOT" --headless --path . --check-only --script <file>`.
   The pack build and the drift audit do NOT parse-check their output.
3. **Read the literal verdict line.** A test that crashes or returns a non-bool prints ZERO
   `[FAIL]` lines. Only `All tests passed.` means passed; a tail segfault AFTER the verdict
   is a known harmless teardown flake.
4. **One value per check.** `_check(a and b, "expected")` compares a bool to a String, which
   is a runtime error in GDScript and produces exactly the silent failure above. Pin VALUES,
   not counts.
5. **Run the ACE end to end where you can.** Compile a sheet that uses it, assert the emitted
   GDScript parses, then instantiate and run it. A wrong native method name is a valid string
   until the player triggers it.
6. **Sweep translations** when a string enters a menu or becomes a display name. A pack ships
   `eventsheet_addons/<pack>/translations.csv` keyed by the English source text
   (`tests/pack_translations_test.gd`); editor UI strings live in
   `addons/eventsheet/translations/*.csv`.
7. **Prove byte-stable regeneration** if you touched a pack builder: rebuild
   (`tools/build_sample_behaviors.gd`), then the drift audit (`tools/audit_addons.gd`) must
   print `drifted=0`. Regenerate `docs/REFERENCE-ENGINE-ACES.md` with `tools/vocabulary_doc.gd`
   when you add built-in vocabulary.
8. **There is no single-test filter flag.** Run a throwaway SceneTree script that loads the test
   script and calls `run()`, then `quit(0)`. If you added a `class_name`, the headless
   `--script` run will not see it until the class cache is regenerated, so `load()` the test
   by path instead.

---

## Step 6 - Respect the freezes

`ace_id`s, `codegen_template`s and block `kind_id`s are compatibility promises the moment
they ship: someone's sheet stores them, and the compiler prefers the template BAKED onto the
row over any registry lookup. So a renamed verb still emits the old call, compiles green, and
fails when the player triggers it. Deprecate and add; never rename. When a rename already
happened, append a forwarding shim under the old name
(`EventSheets.keep_old_verb_working`, or Sheet > Custom Actions... > Keep Old Name...).

ACEDefinitions are statically cached and shared across every tab for the session
(`EventSheetACERegistry`), so never mutate one after generation. Bake changes into row copies.
