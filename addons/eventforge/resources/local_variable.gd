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
## Event-sheet-style "Combo": allowed values for a String variable. When exported, compiles to
## @export_enum so the Inspector shows a dropdown; the value picker uses it too.
@export var options: PackedStringArray = PackedStringArray()
## Inspector attributes that don't ride the export prefix - currently the Inspector grouping
## ("group"/"subgroup", compiling to @export_group/@export_subgroup). Kept here so a tree-placed exported
## variable round-trips its grouping losslessly (the importer absorbs the group lines onto this dict, and
## _emit_tree_variable_line re-emits them) instead of degrading into a stray @export_group GDScript block.
@export var attributes: Dictionary = {}


## Stable row-kind identifier so the compiler/editor can treat tree-placed variables uniformly.
func get_row_kind() -> String:
	return "variable"


## True when this variable is a PROPERTY (a setter and/or getter body is set).
func has_property_accessors() -> bool:
	return not setter_body.strip_edges().is_empty() or not getter_body.strip_edges().is_empty()
