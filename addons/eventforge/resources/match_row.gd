# Godot EventSheets - MatchRow resource
# A GDScript `match` statement as an action-lane row (the event-sheet switch): an fx-validated
# subject expression plus branch text (patterns + bodies, exactly GDScript match-body
# syntax - enum members complete in patterns). Compiles in-flow inside the event body;
# the dialog lint-gates the whole construct before commit.
@tool
class_name MatchRow
extends Resource

@export var enabled: bool = true
## The matched expression (plain GDScript, fx-validated).
@export var match_expression: String = "state"
## The branch block, verbatim GDScript match-body lines, e.g.:
##   State.IDLE:
##       velocity = Vector2.ZERO
##   _:
##       pass
## Used only when `cases` is empty (the raw-text form / the escape hatch and the current importer lift).
@export_multiline var branches_text: String = "_:
	pass"
## Structured branches (the switch/case form). When non-empty, the match compiles from these instead of
## branches_text: each MatchCase is one `pattern:` branch whose action-lane body compiles one indent deeper.
## Additive - an old raw-text MatchRow leaves this empty and keeps working unchanged. See match_case.gd.
@export var cases: Array[MatchCase] = []


## Returns the stable row kind identifier.
func get_row_kind() -> String:
	return "match"
