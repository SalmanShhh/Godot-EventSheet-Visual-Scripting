# Godot EventSheets - EnumRow resource
# A class-level enum declared as a sheet row. Compiles to the canonical single-line form
# `enum Name { IDLE, RUN }` or, with `multiline` on, one member per line - the shape long
# hand-written enums with explicit values use. The importer verify-lifts BOTH forms back into
# this row (byte-gated), so a multi-line enum stays an editable block, never a code blob.
# Exported variables typed with the enum name get Godot's Inspector dropdown for free.
@tool
class_name EnumRow
extends Resource

@export var enabled: bool = true
@export var enum_name: String = "State"
## Member names in declaration order; entries may include explicit values ("HURT = 4").
@export var members: PackedStringArray = PackedStringArray(["IDLE"])
## One member per line (`enum Name {` / tabbed members / `}`) instead of the single-line form -
## how long enums with explicit values are usually written. Lifted files remember their shape.
@export var multiline: bool = false
## Multi-line only: whether the LAST member keeps a trailing comma (both styles exist in the
## wild; remembered on lift so the file round-trips byte-exactly).
@export var trailing_comma: bool = true


## Returns the stable row kind identifier.
func get_row_kind() -> String:
	return "enum"
