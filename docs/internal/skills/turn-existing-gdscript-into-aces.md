---
name: turn-existing-gdscript-into-aces
description: Wrap GDScript you already wrote (functions, behaviors, autoloads, resources) as event-sheet vocabulary - conditions, actions, expressions and triggers - covering every authoring route and every code pattern the plugin supports. Use when someone has working code and wants it usable from an event sheet.
---

# Turn existing GDScript into event sheet vocabulary

You have working code. This is how it becomes rows a non-programmer can read and drop.
Every rule below is enforced by something: a test, the compiler, or a compatibility
promise. Skipping a step does not fail loudly, it fails quietly and later.

## Step 1 - Survey before you mint anything

Two names must be unique across the whole project: the `ace_id` and the display name.

```bash
grep -rn "ace_id\|display_name" addons/eventforge/registration/modules/ tools/pack_builders/
```

A collision does not error. It shadows, and the row a user drops runs the other thing.
Also check whether the vocabulary already exists at all - roughly half of every wave of
"new" ideas here turned out to be shipped already, under a different word.

## Step 2 - Pick the authoring route

| Your code is | Use | Where it lives |
|---|---|---|
| A script in `eventsheet_addons/` you can edit | `## @ace_*` annotations | above each member |
| A pack you are building | pack builder + registrar/factory | `tools/pack_builders/*.gd` |
| Something you cannot annotate (third party, an autoload) | `EventSheets.register_simple_ace` | any `@tool` script |
| Already a sheet function | publish it as a verb | Sheet menu, no code |

The annotation route is the default: providers are scanned zero-config from
`eventsheet_addons/`, so an annotated script IS a provider the moment it is saved.

**Fast path:** right-click any shipped ACE in the picker and copy its authoring stub. The
stub is generated from the live descriptor in both dialects, so you get a correct example
of exactly the feature you are trying to copy instead of guessing from prose.

## Step 3 - The annotation dialect

Names verified against `addons/eventsheet/ace/semantic_analyzer.gd`.

**Kind** (pick one; without one, the return type decides): `@ace_condition`,
`@ace_action`, `@ace_expression`, `@ace_trigger`, `@ace_looping(iterator)`.

**Presentation:** `@ace_name(Text)`, `@ace_category(Text)`, `@ace_icon(path)`,
`@ace_description(Text)`, `@ace_display_template(...)`, `@ace_featured`, `@ace_help(...)`,
`@ace_tags(a, b)`, `@ace_family(Name)`, `@ace_group(Name)`.

**Emission:** `@ace_codegen_template(code)`.

**Visibility and lifecycle:** `@ace_hidden`, `@ace_internal`, `@ace_expose_all`,
`@ace_deprecated`, `@ace_requires(...)`, `@ace_version(x)`, `@ace_author(who)`.

**Parameters**, one line per param, all channels in one annotation:

```gdscript
## @ace_param(metric, hint: expression, options: 0=Straight line|1=Horizontal, default: 0, desc: "How distance is measured.")
```

Keys the parser reads: `hint`, `options` (pipe separated), `default`, `autocomplete`,
`desc`. The older split forms still work: `@ace_param_hint(amount expression)`,
`@ace_param_options(movement horizontal, vertical, angle)`,
`@ace_param_autocomplete(anim "idle", "run")`.

Two things worth knowing because they save typing:

- **Plain `##` prose above a member IS its description.** `@ace_description` is only for
  when the picker text should differ from the code documentation.
- **`hint: comparison`** expands to the whole operator dropdown and seeds `==`, so a
  compare-style condition is one word rather than a hand-typed option list.

## Step 4 - The code patterns

### A plain method

The common case needs nothing but a kind and a name. The method's own parameters become
the row's parameters.

```gdscript
## Adds coins to the player's purse.
## @ace_action
## @ace_name(Give Coins)
## @ace_param(amount, hint: expression, default: 10)
func give_coins(amount: int) -> void:
```

### A computed check

A condition that calls your function reads as a sentence and shows the function badge, so
a beginner sees "this is a check something else decides", not a mystery bool.

```gdscript
## @ace_condition
## @ace_name(Can See Player)
func can_see_player() -> bool:
```

### State that must persist between frames

Two ways, and the cheap one is usually right.

**Stateless, keyed by name** - the meta trick. No compiler involvement, per node, and a
never-started key reads as ready. This is how the cooldown family works:

```gdscript
set_meta(&"__ef_cool_" + cooldown_name, Time.get_ticks_msec())
```

**Stateful members** - for builtin vocabulary only, through the descriptor builder's
`.stateful(member, prelude, on_true)`. The member declaration, its per-frame prelude and
its on-true side effect are synthesized INTO the compiled sheet, so:

- every generated identifier must carry `{uid}` (`var __once_{uid}: int = 1`), otherwise
  two rows of the same ACE collide in one sheet;
- `{uid}` is baked at APPLY time by the dock and NEVER by the compiler, so a pack builder
  that ships a pre-baked descriptor must call `.replace("{uid}", <stable id>)` itself, or
  a literal `{uid}` sails into the user's emitted GDScript;
- the standalone-compile gate compiles each ACE template alone inside its host class, and
  a sheet-synthesized helper cannot compile alone - add the ace_id to the NOT_STANDALONE
  list in `tests/builtin_ace_compile_test.gd` or the suite fails, correctly.

### Dropdowns

Options are `value=Label` (or `{"key":, "label":}` dicts in code). The label is what the
row shows; the key is what gets inserted.

**Substitution is single-pass.** An option value can never contain `{another_param}` - it
will not be substituted, it will be emitted literally. When a dropdown must choose between
several expressions, index an inline array by the option instead:

```gdscript
"([global_position.distance_to({other}.global_position), absf(...), ...][{metric}]) <= {distance}"
```

That is exactly how the metric-distance condition offers five geometries in one row while
staying a plain, dependency-free expression.

### Asynchronous actions

An action whose template awaits is fine and is how the wait/timeline family works. Keep
the await inside the emitted function body; `await` in `_init` is not allowed. If your
verb finishes later, give it a companion trigger rather than making the row lie about
when it is done.

### Triggers from signals

A signal becomes a trigger row. Signal ids named `on_*` are humanized, so name the signal
`quest_completed` rather than `on_quest_completed` unless you want to fight the display
layer.

### Looping conditions

`@ace_looping(item)` on a method returning a collection turns the row into a for-each: the
event's actions run once per item, through the pick-filter machinery.

### Node-scoped and host-targeted templates

A node-scoped ACE's SHIPPED template is not the one you authored. The registration layer
prefixes every line with the target and appends an "On node" parameter, so a test asserting
your authored string fails - assert the post-transform form. The prefix is only added when
every line is a member operation, which is why a template that leads with `not`, `and` or
`is` gets no target at all. Host-targeting packs use the same idea with the host prefix.

### Persistence between runs

The Remember file is a `ConfigFile` at `user://remembered.cfg`, sectioned by feature. It
works treeless, which also makes it testable without a scene.

### Lambda traps

Never bake a lambda's variable name into a frozen template - the template is a
compatibility promise and the name will collide. And a single-line lambda swallows the
last line of what follows it; keep lambdas multi-line in emitted code.

## Step 5 - Verify like the project does

1. **Defaults must stand alone.** The compile gate fills every parameter default and
   compiles the ACE inside its host class. A default naming `global_position` on a plain
   `Node`, or a bare `target`, fails - correctly, because the default is what the row
   shows the moment it is dropped.
2. **Parse-check anything generated:** `--headless --path . --check-only --script <file>`.
   The pack build and drift gates do NOT parse-check their output.
3. **Read the verdict line.** A test that crashes or returns a non-bool prints ZERO `[FAIL]`
   lines. Only `All tests passed.` means passed.
4. **One value per check.** `_check(a and b, "expected")` compares a bool to a String,
   which is a runtime error that produces a silent failure.
5. **Sweep translations** when a string enters a menu or a display name.
6. **Prove byte-stable regeneration** if you touched a pack builder: build, then check the
   drift gate prints `drifted=0`.

## Step 6 - Respect the freezes

`ace_id`s, `codegen_template`s and block `kind_id`s are compatibility promises the moment
they ship: someone's sheet stores them. Deprecate and add, never rename. ACEDefinitions are
statically cached and shared across tabs, so never mutate one after generation - bake
changes into row copies instead.
