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

Built-in ids and names are POSITIONAL arguments, not keyed fields. A built-in verb is one line,
and the first two arguments of that line are the two names:

```gdscript
F.act("StartCooldown", "Start Cooldown", "set_meta(...)", "Time", "start cooldown {name} for {seconds}s", "Starts …")
#     ace_id           label
```

So grep for the candidate STRINGS, never for the words "ace_id" or "display_name":

```bash
grep -rn '"StartCooldown"\|"Start Cooldown"' addons/eventforge/registration/modules/ tools/pack_builders/ eventsheet_addons/
```

- `addons/eventforge/registration/modules/*.gd` - the built-in vocabulary.
- `tools/pack_builders/*.gd` - the behaviour packs' SOURCE (`eventsheet_addons/` is their
  compiler output; a pack edit belongs in the builder). A pack whose behaviour code lives in
  real files keeps it under `tools/pack_builders/src/<pack>/`, so grep both.
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
| A behaviour you want to SHIP with the plugin | a pack builder, `tools/pack_builders/<pack>.gd`, over real `.gd` source in `tools/pack_builders/src/<pack>/` | `Lib.pack_from_source(...)` + `src.verb` / `src.condition` / `src.expression` naming pieces | everything a published sheet function can do |
| Vocabulary that needs per-row state, `node_type`, or an edge gate | a descriptor: a module under `addons/eventforge/registration/modules/`, or an `EventForgeBridge` autoload | `F.act` / `F.cond` / `F.expr` / `F.trig` chains | everything |

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
- **A NEW PACK is authored as real GDScript, not as quoted strings.** `Lib.pack_from_source`
  (`tools/pack_builders/_lib.gd`) reads a folder of ordinary `.gd` files under
  `tools/pack_builders/src/<pack>/`; the builder names the pieces it wants. A PIECE is either a
  `#region <name>` … `#endregion` pair around top-level code (exports, signals, helpers, emitted
  verbatim) or the BODY of a top-level `func`, dedented by one tab and named after the function.
  Everything else outside a region is scaffolding - the `extends`, the host var, the members the
  pack declares for itself at build time - which is what lets the editor parse-check the file and
  never reaches the pack. `static func` is scaffolding too: only a plain `func` at column 0 opens
  a piece. A func piece ENDS AT THE FIRST LINE THAT IS NOT BLANK AND NOT INDENTED, so a `#`
  comment written at column 0 inside a body silently truncates the piece; comment at the body's
  own indentation. Piece names are unique across the folder, files are read in sorted order, and
  regions may not nest. `tools/pack_builders/wrap.gd` over `tools/pack_builders/src/wrap/wrap.gd`
  is the template to copy.
- **What a source file cannot carry is declared on a typed manifest**, one setter per fact:
  `Lib.manifest().behavior().category("Wrap").tags([...])`, plus `.autoload`, `.verb_category`,
  `.version`, `.variables`, `.expose_all_verbs` / `.expose_all_verbs_on_a_node`. Never a
  dictionary of magic strings - the shape it replaced accepted a key nobody knew and built the
  wrong pack silently.
- **A hole in a pack FAILS the build.** `PackSource.code()` records a piece asked for by a name
  the folder does not hold, and `Lib.publish` refuses a pack with any problem on it rather than
  writing an empty body. Before that guard a NEW pack with a hole shipped green: `save_pack`
  returned true, the exit code was 0, and only the drift gate could notice - and only for a pack
  that was already committed.
- **Unquoting does not shrink line counts, and that is not the point.** The first four
  conversions (`wrap`, `skin_catalog_loader`, `weapon_kit`, `save_system`) came to **+88 lines**
  over 1,771 lines of builder and 75 verbs; lines per verb went 23.6 -> 24.8. The escaped form
  was already one line per line of code, so what it charged was characters, not lines. What the
  real-file form buys is highlighting, a parse check, a breakpoint and no doubled quotes - which
  is why it is the door every NEW pack comes through and not a rewrite of the other 110.
- **Those source files are exempt from ONE style rule and no others.** They are scanned like the
  rest of `tools/`, with the two-blank rule alone lifted (`SINGLE_BLANK_TREE` in
  `tests/style_guide_test.gd`), because a blank line in a source file is a blank line in a
  drift-gated emitted pack. The gate prints how many exemptions it took. Do not re-space one by
  hand.
- **A BUILT-IN VERB IS ONE LINE, and the line says which kind of verb it is.** There are four
  makers on `EventForgeACEFactory` (`addons/eventforge/registration/ace_factory.gd`), aliased `F`
  in every module: `F.act` / `F.cond` / `F.expr` for a row that DOES / ASKS / READS AS A VALUE,
  and `F.trig` for one the engine runs. The kind is the method, so it is never a constant spelled
  out in the middle of an argument list:

  `F.act(ace_id, label, template, group, reads_as, description, host, provider)`, with `F.trig`
  taking `signal_name` where the other three take `template` - a trigger emits no expression of
  its own. `provider` defaults to `F.BUILTIN_PROVIDER` (`"Core"`), and `host` is the Godot class
  the row belongs on (`make_descriptor`'s `node_type`). A trigger that is a MOMENT OF THE PHYSICS
  STEP rather than a signal leaves `signal_name` blank.
- **A field is a typed chained call, never a mini-language inside a string.** On the descriptor
  (`addons/eventforge/resources/ace_descriptor.gd`): `.param(id, default, label, words, hint)`,
  and where the chain cannot say it, `.param_typed(type_name, id, ...)`,
  `.param_choice(id, default, label, words, choices, hint)`,
  `.param_suggesting(id, default, label, words, suggestions, hint)` and `.param_built(ACEParam)`.
  Then the rest of the row: `.described`, `.featured`, `.stateful`, `.looping`,
  `.evaluated_last`, `.project_scoped`, `.rich_text_when`, `.deprecated`, `.succeeded_by`.

  **The type comes from the DEFAULT's own type** (`ACEParam.type_name_for`, in
  `addons/eventforge/resources/ace_param.gd`): bool, int, float, Vector2, Vector2i, Vector3 and
  Color map to themselves and EVERYTHING ELSE is `"String"`. So a default that is text standing
  for another type - `Vector2.ZERO` written as an expression, `self` standing for a Node - must
  name its type with `.param_typed`, or the field is a String field.
- **`F.make_descriptor` and `F.make_param` stay forever**, because every shipped `ace_id`,
  template and parameter default is a compatibility promise and the makers compile to them. It is
  still the right call in four narrow places, which is the whole of what is left verbose across
  the built-in modules: a parameter list built by a shared helper, a comment sitting INSIDE the
  argument list explaining the argument under it, a template that is a two-line string with a real
  newline in it, and a descriptor whose KIND is a variable rather than a word. Eleven sites, and
  they are the right eleven; do not add a twelfth for style.
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
| `@ace_succeeded_by(Core::GoToState, renames: next=state, defaults: seconds=1.0)` | The FORWARDING ADDRESS - where the newer spelling lives, what this row's parameters are called over there, and a value for each parameter the old row never had. It is NOT deprecation: the verb keeps its id, its template and its place in the picker. The compiler emits this line (`SheetCompiler._emit_expose_annotations`) and the importer reads it back. |
| `@ace_lift_example("…[[slot\|node: $X]]…")` | One spelling this verb is written as BY HAND, marked up. Read by the importer (`addons/eventforge/importer/pack_spellings.gd`), never by the generator: it changes how an opened file READS, never what a row emits. |
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

**Stateful members** - descriptors only, `.stateful(member, prelude, on_true, on_exit)`. This is the
shipped `EveryXSeconds`, wrapped for the page; in `system_aces.gd` it is one line:

```gdscript
F.cond("EveryXSeconds", "Every X Seconds", "__every_{uid} >= maxf({seconds}, 0.001)",
		"Time", "Every {seconds} seconds",
		"True once each time the chosen number of seconds passes, for repeating timers.")
	.param("seconds", "1.0", "Seconds", "Interval between runs (needs a per-frame trigger).", "expression")
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

### Code that should SHIP as a behaviour pack

The builder holds the pack's shape; the code stays real GDScript in its own file. From
`tools/pack_builders/wrap.gd`, trimmed:

```gdscript
static func build() -> bool:
	var src: Lib.PackSource = Lib.pack_from_source("wrap", "Node2D", "WrapBehavior",
		"Asteroids-style screen wrapping: …",
		Lib.manifest().behavior().category("Wrap").tags(["movement", "screen"]))
	src.note("Wrap behavior … This pack is an event sheet - extend it by editing it.")
	src.block("block_1")
	src.on_ready()
	src.on_physics_process()
	src.verb("set_wrap_enabled", "Set Wrap Enabled", "Turns wrapping on or off at runtime.",
		[["enabled", "bool"]])
	return Lib.publish(src, "res://eventsheet_addons/wrap/wrap_behavior")
```

`src.verb` is an Action, `src.condition` a Condition, `src.expression(..., ret)` a value-returning
Expression, and `src.object_expression(..., returns_class)` one that returns a Texture2D, a Node or
a Resource - Godot's `TYPE_*` numbers only reach as far as "an object". Each takes its body from the
piece NAMED AFTER THE FUNCTION, so `set_wrap_enabled` in the builder is `func set_wrap_enabled(...)`
in `tools/pack_builders/src/wrap/wrap.gd`, where the `## @ace_*` annotations live too. `src.block`
emits a named `#region` verbatim; `src.on_ready` / `on_process` / `on_physics_process` /
`on_tree_exiting` hang a piece off the engine callback of the same shape.

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

### The other direction: making the hand-written line READ as your verb

Wrapping publishes the verb; it does not make the line somebody ALREADY wrote open as that row.
That is the lifter's job, and the route is a TABLE ENTRY, not a matcher.

An entry in `addons/eventforge/importer/lift_table.gd` is data: `id`, `ace_id`, `pattern`,
`shape`, `slots`, plus the optional `provider`, `params`, `defaults`, `guard`, `error`, `origin`,
`statements` and `mark`. Families are found by SCANNING for a `lift_entries` static under
`addons/eventforge/importer/` - there is no list to join.

- **A run of statements is an entry too.** Instead of one `pattern`, give an ordered `statements`
  list, each with the `indent` it is written at. They SHARE THEIR CAPTURES: a name spelled by more
  than one statement has to read the same text in all of them, which is how a run says "the local
  made on the first line is the one named on the second and placed on the third" without that
  local becoming a value of the row. `addons/eventforge/importer/layout_on_top_lift.gd` is the
  worked example.
- **`mark` is the cheap pre-filter**: the substring an entry's OPENING statement must contain
  before any pattern of it is run.
- **Hand-written matchers still exist and are not the route.** `ace_lifter.gd` keeps
  `SPELLING_FAMILIES` (one line each) and `RUN_FAMILIES` (`match_run`), and the two that stayed
  hand-written say WHY in their own headers - independent optional statement pairs, or a claim
  that spans a statement and then a region and hands back no template at all. Everything else is
  an entry, because an entry gets a generated byte test and a matcher gets none.
- **The harness is `tests/lift_table_test.gd`.** Per entry it generates the fixture line from the
  entry's own `shape` and `slots` through the real emitter, asks the engine what the line means,
  pins the row and its values, then re-emits and asserts byte identity.
  `EVENTFORGE_LIFT_ONLY=<entry ids>` narrows it to named entries (comma-separated, snake_case ids
  like `layout_on_top_written`).
- **Provenance is a command**, not a guess: `tools/explain.gd -- <res://file.gd> <line>` reports a
  run the table claims at the `table` layer, naming the entry.

---

## Step 5 - Verify the way the project verifies

1. **Defaults must stand alone.** `tests/builtin_ace_compile_test.gd` fills every parameter
   with its DEFAULT and compiles the ACE inside its declared host class. A default naming
   `global_position` on a plain `Node`, a bare `target`, or `velocity` fails - correctly,
   because the default is what the row shows the moment it is dropped. An ACE that genuinely
   cannot compile alone (sheet-synthesized state, a user-chosen call target) belongs in that
   file's `NOT_STANDALONE` list, and nowhere else.
2. **Parse-check anything generated.** `"$GODOT" --headless --path . --check-only --script <file>`.
   The pack build and the drift audit do NOT parse-check their output.
3. **Read the literal verdict line.** A test that crashes or returns a non-bool prints ZERO
   `[FAIL]` lines. Only `All tests passed.` means passed; a tail segfault AFTER the verdict
   is a known harmless teardown flake. A `[FAIL]` line can be INDENTED, and one can sit under a
   green verdict (a probe printing a deliberate failure it does not count), so the verdict is
   the answer in both directions.
4. **Write assertions in the ONE assertion vocabulary**, `tests/support.gd`
   (`class_name EventSheetTestSupport`). Preload it - `const SUPPORT := preload("res://tests/support.gd")` -
   and call:
   - `SUPPORT.check(label_prefix, label, actual, expected)` - one assertion, printing the
     suite's `[PASS]` / `[FAIL]` line plus the `expected:` / `actual:` pair the report tool parses;
   - `SUPPORT.pins(label_prefix, rows)` - a table of `[label, actual, expected]` rows;
   - `SUPPORT.pin_table(test_name, pins, answer)` / `SUPPORT.pin_value(test_name, label, actual, expected)` -
     the quieter input-to-expected form, silent on a pass;
   - `SUPPORT.compile_output(sheet, output_path)` / `SUPPORT.reopen(source, lift, script_path)` /
     `SUPPORT.reemit(source, verify_path, lift)` - the compile-and-round-trip trio.

   Do not hand-roll a per-file `_check`: the printed shapes are parsed by the runner, the report
   tool, the parallel launcher and CI, so a second reporter is a contract change. Extend
   `support.gd` instead. And compare VALUES, never boolean-and chains - `_check(a and b, "expected")`
   compares a bool to a String, which is a GDScript runtime error and produces exactly the silent
   failure above. Pin values, not counts.
5. **Run one test alone; there IS a filter.** `EVENTFORGE_TEST_ONLY=<name>` (comma-separated for
   several) in the environment of the normal runner command,
   `"$GODOT" --headless --path . --script tests/run_tests.gd`. Around it:
   - `powershell -File tools/run_tests_parallel.ps1 -Iterate` runs what `tools/pick_tests.gd`
     says your change could have broken, first, and stops on the first red. NEVER a verdict.
   - `powershell -File tools/test_daemon.ps1` in one terminal plus
     `powershell -File tools/test_daemon_client.ps1 <tests...>` answers a single test in about a
     second instead of twenty-five.
   - `"$GODOT" --headless --path . --script tools/test_report.gd` pre-investigates a red run:
     the assertion with its expected and its got, the changed files that map to it, and the line
     that reruns it alone. `tools/bisect_test.ps1 <test>` wraps the same for `git bisect run`.
   - `EVENTFORGE_TEST_SHARD=k/n` (or `tail`) runs one shard by hand; `EVENTFORGE_LIFT_ONLY=<entry ids>`
     narrows the lift-table harness to named entries and is spelled after `EVENTFORGE_TEST_ONLY`
     so the two compose.
   - **A brand-new test file is invisible until the project is imported.** Discovery is through
     the resource filesystem, so run `"$GODOT" --headless --path . --import` first (plus one
     headless editor boot when the file declares a new `class_name`), and remember a new file
     RESHARDS the parallel suite. The launcher names both silent states -
     `CRASHED (started, never finished): <test>` and
     `NEVER RAN (on disk, in no shard's trail): <test>` - and fails the run on either.
6. **Run the ACE end to end where you can.** Compile a sheet that uses it, assert the emitted
   GDScript parses, then instantiate and run it. A wrong native method name is a valid string
   until the player triggers it. Physics does NOT step inside `run_tests.gd`; a behaviour that
   needs frames wants a temporary non-headless SceneTree harness.
7. **Prove the vocabulary did not move, when you touched a builtin module.**
   `powershell -File tools/prove_registry_identity.ps1 -Base <sha>` runs `tools/dump_registry.gd`
   over a detached worktree of the base commit and over your tree, and prints
   `identity: registry=same words=same fields=same order=same verbs=<n> base=<sha>`. THE GATE IS
   ALL FOUR TEXTS, because each is blind to what the others carry:
   - `registry` - key, kind, shelf, parameters with types and defaults, forwarding address and
     the emitted template. A move here is a frozen-contract break.
   - `words` - name, description, reads-as sentence, and every parameter's label and description.
     Catches a migration that keeps every identity line and empties every picker.
   - `fields` - what a verb OFFERS: each parameter's hint, options, autocomplete, lens, option-label
     and required flags, plus the descriptor's node type, signal, return type and the featured /
     project-scoped / deprecated flags. None of it moves an emitted byte, so the first two texts
     cannot see a vanished dropdown or a lost `.project_scoped()`.
   - `order` - the registration SEQUENCE and the lifter's reverse index. The other three are
     sorted by key and structurally blind to it, and registry order is what breaks ties in the
     reverse-lifter and decides picker shadowing.

   Comparison is case-sensitive and positional. The run also names the instrument files it copied
   into the base worktree, because those are the one thing it cannot measure.
8. **Rebuild and re-gate the packs**, if you touched `tools/pack_builders/` (the builder OR its
   `src/` files): `"$GODOT" --headless --path . --script tools/build_sample_behaviors.gd`, then
   `"$GODOT" --headless --path . --script tools/audit_addons.gd` must print `audited=N drifted=0`,
   then `--check-only --script` the emitted pack yourself - neither the build nor the audit parses
   its own output. Regenerate `docs/REFERENCE-ENGINE-ACES.md` with `tools/vocabulary_doc.gd` when
   you add built-in vocabulary.
9. **Re-check the showcases after a PACK change, not only after a builder change.**
   `"$GODOT" --headless --path . --script tools/build_examples.gd -- --check` must print
   `showcases=N drifted=0`. A change to a pack's MEMBER ORDER drifts `demo/showcase/` without
   anyone touching it, which is how five `.tscn` files once went stale unnoticed. A check killed
   half way leaves the tree REGENERATED, which is the correct tree; `git status` names it.
10. **Sweep translations** when a string enters a menu or becomes a display name.
    `"$GODOT" --headless --path . --script tools/harvest_translations.gd` must print
    `harvest: nothing owed`; `-- --dry-run` shows what it would write. The engine errors it prints
    between `walking the live editor` and `live editor walked` are EXPECTED and say so - the
    advisory half opens real dialogs with no editor around them. Its two owed sources are scoped to
    `addons/eventsheet` and `addons/eventforge`, so a PACK's own catalog is outside its world: a
    pack ships `eventsheet_addons/<pack>/translations.csv` keyed by the English source text, read
    by `addons/eventsheet/editor/l10n.gd` and pinned by `tests/pack_translations_test.gd` (packs
    ADD, they never re-word an editor string). Editor UI strings live in the nine
    `addons/eventsheet/translations/*.csv` files, in lockstep.
11. **Diff the readings if you changed how a row READS.** A row's spans are data and nothing else
    writes them down, so the gate is a before/after diff, not a golden:
    `"$GODOT" --headless --path . --script tools/reading_dump.gd -- out=user://before.txt`, make the
    change, dump to `after.txt`, diff. `only=builtin` answers in seconds.
    `"$GODOT" --headless --path . --script tools/explain.gd -- res://path/to/file.gd 42` says what
    one line became - the row, then `shaped` (which builder path shaped its reading), then the
    `read by:` list of layers that would claim it (`table`, `example`, `matcher`, `index`, `call`,
    `property`, `verbatim`). `tools/reading_census.gd` reads the same population and reports what
    the two reading files actually hold.
12. **Run the standing-contract gate over what you changed.**
    `"$GODOT" --headless --path . --script tools/verify_sheets.gd -- <paths...>` - parse, byte-exact
    round trip, doubled baked locals, and migration rows still waiting on a human. With no paths it
    walks the whole project (~1,300 files at ~0.4 s each), so pass the paths you touched, or
    `--skip res://tests/fixtures/` for the deliberately broken ones.
13. **Re-bake the help bundle LAST**, after the CHANGELOG entry:
    `"$GODOT" --headless --path . --script tools/build_help_bundle.gd`, then `-- --check` must print
    `help: pages=N drifted=0`. The bundle mirrors `docs/*.md`, `docs/Addons/`, `docs/Modules/` and
    the locale sets; `docs/internal/` never ships, so a change confined to it bakes nothing - run
    the check anyway.

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
