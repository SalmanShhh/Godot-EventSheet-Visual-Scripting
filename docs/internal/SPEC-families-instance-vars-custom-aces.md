# Spec - Families, instance variables & family-bound custom ACEs (the "Families trio")

**Status:** **v1 implemented** - a sheet flagged `is_family` emits a metadata-only `## @ace_family(<Class>)`
marker (round-trips byte-exact), derives its group via `family_group()`, is toggled from the Sheet Type
dialog, warns when unnamed, and a family-scoped event reuses `PickFilter`(GROUP). Demonstrated by the
**Family Arena** showcase (`demo/showcase/enemy.gd` + `family_arena.gd`). v2 (loose families, one-gesture
"Make Family") and v3 (implicit picking / SOL) remain proposed. **Audience:** maintainers / tools
engineers. **Goal:** add C3's *horizontal*
abstraction - write one rule that applies to *every instance of a type-set* - on top of Godot's own
primitives (groups, base classes, exported vars, methods), compiling to idiomatic GDScript that
round-trips byte-exact.

This is the abstraction the tool most lacks. Functions/behaviours/loops are strong *vertical* reuse; a
Family is the missing *horizontal* reuse: **logic-per-type, not logic-per-object.**

---

## 1. Why (tie to the north star)
- **Designers think in objects.** "When an **Enemy** is hit, flash it" should be one rule, not one per
  enemy type. Families turn N copies of a rule into one.
- **Engineers ship vocabulary.** A family is a typed contract (its variables + its verbs) a tools engineer
  defines once and designers compose - the custom-modules-for-teams goal, made concrete.
- **It must stay honest GDScript.** A Family compiles to a Godot group + (optionally) a base class; nothing
  here is a parallel runtime. The `.gd` remains the byte-exact source of truth.

## 2. Key design decision - surface Godot, don't reinvent C3

A Family is **not** a new runtime. It is an *authoring layer* over three things you already have:

| Family concept | Godot primitive | Already in the tool |
|---|---|---|
| The type-set | a **group** `family_<name>` (+ optional base `class_name`) | groups exist; behaviour sheets already emit `class_name X extends …` |
| Iterate/filter members | `for m in get_tree().get_nodes_in_group(...)` + `if <conds>` | **`PickFilter`** already emits exactly this (CollectionKind.GROUP + `filter_conditions`) |
| Instance variables | `@export var` on the member (or `set_meta`) | sheet variables + `LocalVariable.exported` already compile `@export var` |
| Family-bound verbs | a method on the member: `m.take_damage(n)` | **`EventFunction`** (usable-as Action/Condition/Expression) + the `{target}.{method}({args})` codegen + node-targeting already exist |

So the *new* work is small and focused: a **Family definition** (a thin contract + membership), **picker
integration** (treat a family as an iterable target object), a **compile path** (family event → PickFilter
over the family group), **membership tooling**, and **validation**. Everything else is reuse.

**The clean mental model:** a Family's "base" is just one of your existing **custom-node/behaviour sheets**
(`class_name Enemy extends Node2D` with `@export var health` and an `@ace_action func take_damage`). The
trio adds: (a) a *group* so the sheet can target *all* instances at once, (b) the *picker* treating
`Enemy` as an iterable object, (c) *membership* tooling, (d) *validation*.

## 3. Data model

### 3.1 `Family` (definition / contract)
Stored where it's authored (a "Families" manager, persisted into the owning sheet), recovered from the
`.gd` via annotations so it round-trips (same mechanism as `## @ace_tags`):
- `family_name: String` - `"Enemy"`.
- `group_name: String` - runtime group, default `"family_" + snake_case(name)`.
- `base_class: String` - optional shared `class_name`; when set, members **extend** it and the family is
  *typed* (full validation + autocomplete). When empty, the family is *loose* (group-only; vars via meta).
- `member_types: Array[String]` - member `class_name`s / scene paths (authoring + validation only; runtime
  membership is the group).
- `icon: String`, `description: String` - picker presentation.

`.gd` annotation form (recovered by the importer, emitted by the compiler - no double-emit, byte-exact):
```gdscript
## @ace_family("Enemy", group="family_enemy", base="Node2D")
## @ace_family_member("Slime")
## @ace_family_member("Goblin")
## @ace_family_var("health", "int", "100")
## @ace_family_var("state", "int", "0")
```

### 3.2 Family instance variables (`@ace_family_var`)
Per-instance state every member carries. Compile target, in priority order:
1. **Typed family** (has `base_class`): an `@export var health: int = 100` on the **base script** - members
   inherit it. Fully typed, Inspector-visible, autocompletes.
2. **Loose family** (no base): `get_meta("health", 100)` / `set_meta("health", v)` on the member - works for
   any node, untyped. (v1 fallback; flagged by validation as "consider a base class for type safety".)

### 3.3 Family-bound custom ACEs (`EventFunction` tagged to a family)
Reuse `EventFunction` (you already have usable-as Action/Condition/Expression + params + return type) with
one new field `family: String`. The function's implicit first argument is the **member** (`self`/target):
- **Typed family:** the function compiles to a **method on the base script** → call site `m.take_damage(n)`.
- **Loose family:** a free function `take_damage(m, n)` in the family-owning sheet → call site
  `take_damage(m, n)`.
Either way the picker entry uses the existing `{target}.{method}({args})` (or free-call) codegen - **no new
compiler path**, the same one behaviour methods + node-targeting already use.

## 4. Compile target (the whole point - idiomatic, round-trippable GDScript)

Authoring: *"For each **Enemy** where `health < 20`: **Take Damage** 5"* compiles to a `PickFilter`
(CollectionKind.GROUP, `collection_value="family_enemy"`, `filter_conditions=[health < 20]`):
```gdscript
for enemy in get_tree().get_nodes_in_group("family_enemy"):
    if enemy.health < 20:
        enemy.take_damage(5)
```
The base (one of your custom-node sheets), authored normally:
```gdscript
## @ace_tags(enemy)
class_name Enemy
extends Node2D
@export var health: int = 100
## @ace_action
## @ace_name("Take Damage")
func take_damage(amount: int) -> void:
    health -= amount
```
A member scene's root: script `extends Enemy`, in group `family_enemy` (the membership realization, §6).

Because every part (group iteration, exported var, method call) already round-trips, **a family-targeted
event re-imports as a family-targeted event** - `PickFilter` over `family_*` + the recovered `@ace_family*`
annotations reconstruct the Family. drift stays 0.

## 5. Picker UX & authoring flows
- **Family as an object in the picker.** A Family appears as a node-type group (like `CharacterBody2D`
  groups today) named `Enemy`, holding: its custom ACEs (Take Damage, Is Low Health…), its instance vars
  (Set/Compare `Enemy.health` via the generic property ACEs scoped to the family), and the base class's
  inherited ACEs. Picking a Family action/condition makes the event **family-scoped** (emits the
  `PickFilter` over the group; the iterator becomes the implicit `{target}`).
- **Families manager** (sibling of the Variables/Includes managers): create a family, set base + group, add
  member types, declare instance vars, and jump to author its custom ACEs (reusing the existing function
  dialog with the `family` field pre-set).
- **One-gesture creation** (the abstraction-making path, cheap so people use it): *select an object's
  events → "Make Family from this type"* scaffolds the base + a family + moves the vars/verbs in.
- **Inline scoping cue:** a family-scoped event renders with the family icon + name as its lane label (so it
  reads "**Enemy** - health < 20 → Take Damage 5"), not a raw `for` loop.

## 6. Membership realization (the main design challenge)
Members must (a) be in `family_<name>`, and (b) for typed families, `extend` the base. v1 = **members
opt-in, tool-automated** (Godot-native, each piece lives in its own file so it round-trips):
- **"Add `Slime` to family `Enemy`"** edits Slime: sets/confirms `extends Enemy` (typed) and adds the
  `family_enemy` group to the scene root (or `add_to_group` in `_enter_tree` for script-only members).
- Plain scenes with no script join the group only → **loose** membership (meta vars; no custom-ACE methods
  unless a script is added). Validation nudges toward a script/base for full power.
- Rejected for v1: a central generated registry/autoload (more magic, less Godot-native).

## 7. Validation (what makes it abstraction, not hidden bugs) - Project Doctor checks
- **Contract satisfied:** every `member_type` extends `base_class` and carries each instance var / responds
  to each custom-ACE method. Flag the offender precisely ("`Goblin` is missing `health`").
- **Membership drift:** a declared member scene that lost its `family_*` group (so it silently won't be
  iterated). This is the classic silent family bug - surface it.
- **Empty family / unused family** - warn.
- **Heterogeneous-action safety:** a family action whose members can't all perform it (loose family calling
  a method only some members have) → error before it ships.
- **Performance nudge:** `get_nodes_in_group` every frame on a large family → suggest the existing
  `PickFilter` frame-budget (you already have Budgeted For Each) or a cached query.

## 8. Phasing
1. **v1 (typed families):** Family resource + `@ace_family*` annotations + round-trip; picker shows a family
   as an iterable object; family event compiles via `PickFilter`(GROUP); instance vars = base `@export`;
   custom ACEs = base methods; "Add member" tooling; the Doctor contract + drift checks. (Maximal reuse -
   this is mostly wiring existing pieces together.)
- **v2:** loose families (meta vars, free-function ACEs) for unrelated types; one-gesture "Make Family".
- **v3:** *implicit picking* (the C3 SOL) - conditions narrow the picked set and actions apply with no
  visible loop, inherited by sub-events. The deepest, most C3-like, highest-effort; layer it on the
  family-scoped `PickFilter`. Out of scope until v1/v2 prove the model.

## 9. Risks / open questions
- **Round-trip of the contract:** family metadata must recover from the `.gd` (`@ace_family*` regex, like
  `@ace_tags`) AND membership must recover from each member - verify both reconstruct the Family + drift=0
  before shipping. This is the load-bearing constraint.
- **Cross-file coordination:** editing member scenes/scripts to join a family is an editor write; make it
  undoable + previewed, and never silently mutate a file the user didn't expect (consistent with the repo's
  edit-safety norms).
- **Typed vs loose tension:** typed is safe but forces a shared base (a real constraint vs C3's free
  families); loose is flexible but untyped. v1 picks typed; v2 adds loose. State the trade-off in the UI.
- **Overlap with behaviours:** a typed family base *is* a custom-node sheet. Decide whether "Family" is a
  thin tag on a custom-node sheet + a group, or a distinct resource. (Recommendation: a thin tag - reuse the
  sheet, don't fork the authoring.)

## 10. Pointers (for whoever implements)
- Iteration/filter compile + frame budget: `addons/eventforge/resources/pick_filter.gd` (CollectionKind.GROUP)
  + the `_compile_filter_conditions` path in `sheet_compiler.gd`.
- Function-as-ACE: `addons/eventforge/resources/event_function.gd` + the function dialog (usable-as) +
  `{target}.{method}({args})` codegen + node-targeting in the picker/compiler.
- Annotation round-trip precedent: `## @ace_tags` recovery in `addons/eventforge/importer/gdscript_importer.gd`.
- Picker node-type grouping: `addons/eventsheet/editor/ace_picker.gd` (`metadata.node_type` groups).
- Validation home: `addons/eventforge/project_doctor.gd`.
