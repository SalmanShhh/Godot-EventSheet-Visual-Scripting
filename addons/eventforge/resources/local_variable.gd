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

## Stable row-kind identifier so the compiler/editor can treat tree-placed variables uniformly.
func get_row_kind() -> String:
	return "variable"
