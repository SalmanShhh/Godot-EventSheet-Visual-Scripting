# Godot EventSheets — MatchRow resource
# A GDScript `match` statement as an action-lane row (C3's switch): an fx-validated
# subject expression plus branch text (patterns + bodies, exactly GDScript match-body
# syntax — enum members complete in patterns). Compiles in-flow inside the event body;
# the dialog lint-gates the whole construct before commit.
@tool
extends Resource
class_name MatchRow

@export var enabled: bool = true
## The matched expression (plain GDScript, fx-validated).
@export var match_expression: String = "state"
## The branch block, verbatim GDScript match-body lines, e.g.:
##   State.IDLE:
##       velocity = Vector2.ZERO
##   _:
##       pass
@export_multiline var branches_text: String = "_:
	pass"

## Returns the stable row kind identifier.
func get_row_kind() -> String:
	return "match"
