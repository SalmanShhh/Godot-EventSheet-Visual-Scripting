# Godot EventSheets — EnumRow resource
# A class-level enum declared as a sheet row. Compiles to the canonical single-line form
# `enum Name { IDLE, RUN }` (members may carry explicit values: "HURT = 4"); the importer
# verify-lifts exactly that form back (multi-line enums stay verbatim GDScript blocks).
# Exported variables typed with the enum name get Godot's Inspector dropdown for free.
@tool
class_name EnumRow
extends Resource

@export var enabled: bool = true
@export var enum_name: String = "State"
## Member names in declaration order; entries may include explicit values ("HURT = 4").
@export var members: PackedStringArray = PackedStringArray(["IDLE"])


## Returns the stable row kind identifier.
func get_row_kind() -> String:
	return "enum"
