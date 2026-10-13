# EventForge - LocalVariable resource
# Describes a scoped local variable declaration.
@tool
class_name LocalVariable
extends Resource

@export var name: String = ""
@export var type: int = TYPE_NIL
@export var type_name: String = "Variant"
@export var default_value: Variant = null
@export var description: String = ""
@export var is_constant: bool = false
## When true, compiles to `static var` (a class-level member shared across all instances, no `self`).
## Mutually exclusive with @export / @onready / const. Set on lift from a `static var` line and byte-gated,
## so a hand-written static var opens as an editable row instead of a verbatim block.
@export var is_static: bool = false
## A Local by scope, a member in code. The row stays under the event that declares it and reads
## "Static local number hits_taken = 0", but GDScript has no function-scope `static`, so the value can
## only survive between runs of the event as a class member: the compiler hoists the declaration to
## `var _hits_taken := 0` and rewrites the event's uses of the bare name to it. Byte-gated on lift
## (the marker comment above the member says which row it belongs to), so a hand-written private
## member never opens as one of these.
@export var static_local: bool = false
## When true and placed in the event tree, compiles to `@export var` (usable outside the
## script); otherwise a plain private `var`.
@export var exported: bool = false
## A hinted export annotation kept VERBATIM (e.g. `@export_range(0, 100)`, `@export_file`,
## `@export_flags("A", "B")`) for inspector-tuned scripts. When set it replaces the plain `@export `
## prefix on emit, so an opened `.gd`'s hinted exports round-trip byte-identically. Empty = none.
@export var export_hint: String = ""
## When true, compiles to `@onready var` (deferred init - for node refs like $Path that are not
## ready at construction). default_value is emitted VERBATIM as an expression, not a quoted literal.
@export var onready: bool = false
## When true, default_value is a bare GDScript EXPRESSION (e.g. `Vector2.ZERO`, `Color.RED`,
## `Type.CONST`), not a literal - so it emits verbatim rather than being quoted as a String. Set by
## the importer when a source default was written unquoted; keeps such vars first-class rows instead
## of stranding them as GDScript blocks. Byte-verify gated.
@export var expression_default: bool = false
## When true, the declaration was written with the inferred-type walrus (`var hp := 100`) and
## emission reproduces exactly that spelling - beginner-style files use `:=` everywhere, and
## without this flag every such variable stranded as a GDScript block. The default is kept as
## verbatim source text. Byte-verify gated like every lift; editing the type in the dialog
## clears the flag and the byte change rides the user's own edit.
@export var inferred_type: bool = false
## When true, the declaration was written with NO initial value (`@export var spark: PackedScene`,
## `var target: Node2D`), the usual spelling for a slot filled in the Inspector or in `_ready`. The
## declaration then emits without ` = ...` - but only while the default is still empty (null): the
## moment someone gives the row a starting value, that value is written, so the flag can never hide
## an edit. Set by the importer and byte-verify gated like every lift.
@export var no_default: bool = false
## When true, the declaration is written with NO type (`@export var damage = 3`): Godot works the
## type out from the value, and the code says nothing. type_name still holds the type the value
## implies (int from 3), so the row and the value picker read it; only the `: int` is left out of
## the file. Clearing it is "write the type in code". Set by the importer and byte-verify gated.
@export var untyped: bool = false
## Property SETTER body (the statements under `set(<setter_param>):`), verbatim, one statement per line,
## dedented relative to the accessor header. Non-empty turns the variable into a GDScript property:
## the declaration line gains a `:` suffix and the accessor blocks emit beneath it. Byte-gated on lift.
@export_multiline var setter_body: String = ""
## Property GETTER body (the statements under `get:`), verbatim, dedented. Either accessor may be
## empty - a property can do both jobs or just one.
@export_multiline var getter_body: String = ""
## The setter's parameter name (`set(value):`). Hand-written code may use any name; keeping it
## preserves the byte round-trip.
@export var setter_param: String = "value"
## The OTHER spelling of a property, and the one older Godot code is written in: instead of an inline
## block, the declaration names a FUNCTION that already exists elsewhere in the file.
##
##     var health: int = 100:
##         set = _set_health,
##         get = _get_health
##
## Both mean exactly what the inline blocks mean, and Godot accepts either - so a variable carries
## either the bodies above or these two names, never both, and emission writes back whichever
## spelling the file had. A file that used this form used to lose its declaration to a code block
## (the two accessor lines are not statements, so nothing could lift the `var` line above them).
@export var setter_name: String = ""
## The getter's named function, the other half of the spelling above. Either may be empty - a
## property can name a setter, a getter, or both.
@export var getter_name: String = ""
## Event-sheet-style "Combo": allowed values for a String variable. When exported, compiles to
## @export_enum so the Inspector shows a dropdown; the value picker uses it too.
@export var options: PackedStringArray = PackedStringArray()
## Inspector attributes that don't ride the export prefix - among them the Inspector sections, written
## as lines ABOVE the variable. Kept here so a tree-placed exported variable round-trips its sections
## losslessly (the importer absorbs the lines onto this dict, and _emit_tree_variable_line re-emits
## them) instead of degrading into a stray @export_group GDScript block. The section keys:
##   "category"        String - `@export_category("Weapon")`, the heavy band.
##   "group"           String - `@export_group("Gun")`, a folder.
##   "group_prefix"    String - the group's second argument (`@export_group("Bullet", "bullet")`): only
##                     names starting with it join the folder, and the Inspector shows them without it.
##   "group_end"       bool   - `@export_group("")` above this variable: the folder before it ends here.
##   "subgroup"        String - `@export_subgroup("Jump")`, a folder inside the group.
##   "subgroup_prefix" String - the subgroup's second argument, read like group_prefix.
## And one hint with no annotation of its own:
##   "custom_hint"     Dictionary {"hint", "text", "usage"} - a free-form
##                     `@export_custom(PROPERTY_HINT_RANGE, "0,10", PROPERTY_USAGE_DEFAULT)`: the hint
##                     constant's name, the hint string, and the usage flags as written ("" = left out).
## A file picker's "file" spec also takes "plain_path": true for `@export_file_path`, which stores
## the path as typed where `@export_file` may store a `uid://` reference instead.
@export var attributes: Dictionary = {}


## Stable row-kind identifier so the compiler/editor can treat tree-placed variables uniformly.
func get_row_kind() -> String:
	return "variable"


## The class member a Static local compiles to: the row's own name, made private with a leading
## underscore. ONE rule, read by the compiler that writes the member, the importer that reads it back
## and the row echo that shows it, so the three can never disagree about the spelling.
static func static_local_member(local_name: String) -> String:
	return "_%s" % local_name.strip_edges()


## True when this variable is a PROPERTY - under either spelling: an inline accessor body, or the
## name of a function that does the job. One question, asked by the emitter and by the row builder
## alike, so neither can be told about one spelling and not the other.
func has_property_accessors() -> bool:
	return has_accessor_bodies() or has_named_accessors()


## True when the property is written as INLINE BLOCKS (`set(value):` and/or `get:`).
func has_accessor_bodies() -> bool:
	return not setter_body.strip_edges().is_empty() or not getter_body.strip_edges().is_empty()


## True when the property NAMES the functions that do the job (`set = _set_health`).
func has_named_accessors() -> bool:
	return not setter_name.strip_edges().is_empty() or not getter_name.strip_edges().is_empty()
