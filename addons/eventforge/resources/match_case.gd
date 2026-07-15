# Godot EventSheets - MatchCase resource
# One branch of a structured switch/case (a MatchRow with `cases`): a match pattern plus the actions to run
# for it. `events` holds the same action-lane items an event body holds (ACEAction, RawCodeRow, CommentRow),
# so a case body compiles through the ordinary action codegen, one indent under its pattern. The pattern is
# plain GDScript match-pattern text ("State.IDLE", "1, 2, 3", "_" for the default branch). This is the
# structured alternative to MatchRow.branches_text: when a MatchRow has cases, each case reads and edits like
# a small event body instead of a raw text blob. See SPEC-switch-case-block.md for the full design.
@tool
class_name MatchCase
extends Resource

@export var enabled: bool = true
## The match pattern for this branch, e.g. "State.IDLE", "1, 2, 3", or "_" for the default.
@export var pattern: String = "_"
## Action-lane items run when this branch matches (ACEAction / RawCodeRow / CommentRow), in order.
@export var events: Array = []


## Returns the stable row kind identifier.
func get_row_kind() -> String:
	return "match_case"
