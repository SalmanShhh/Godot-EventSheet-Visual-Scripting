# EventForge — LocalVariable resource
# Describes a scoped local variable declaration.
@tool
extends Resource
class_name LocalVariable

@export var name: String = ""
@export var type: int = TYPE_NIL
@export var type_name: String = "Variant"
@export var default_value: Variant = null
@export var description: String = ""
@export var is_constant: bool = false
## When true and placed in the event tree, compiles to `@export var` (usable outside the
## script); otherwise a plain private `var`.
@export var exported: bool = false
## A hinted export annotation kept VERBATIM (e.g. `@export_range(0, 100)`, `@export_file`,
## `@export_flags("A", "B")`) for inspector-tuned scripts. When set it replaces the plain `@export `
## prefix on emit, so an opened `.gd`'s hinted exports round-trip byte-identically. Empty = none.
@export var export_hint: String = ""
## When true, compiles to `@onready var` (deferred init — for node refs like $Path that are not
## ready at construction). default_value is emitted VERBATIM as an expression, not a quoted literal.
@export var onready: bool = false
## Event-sheet-style "Combo": allowed values for a String variable. When exported, compiles to
## @export_enum so the Inspector shows a dropdown; the value picker uses it too.
@export var options: PackedStringArray = PackedStringArray()
## Inspector attributes that don't ride the export prefix — currently the Inspector grouping
## ("group"/"subgroup", compiling to @export_group/@export_subgroup). Kept here so a tree-placed exported
## variable round-trips its grouping losslessly (the importer absorbs the group lines onto this dict, and
## _emit_tree_variable_line re-emits them) instead of degrading into a stray @export_group GDScript block.
@export var attributes: Dictionary = {}

## Stable row-kind identifier so the compiler/editor can treat tree-placed variables uniformly.
func get_row_kind() -> String:
	return "variable"
