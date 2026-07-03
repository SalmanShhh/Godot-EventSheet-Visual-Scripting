# EventForge — RawCodeRow resource
# Passthrough GDScript row: the in-sheet escape hatch. Holds verbatim GDScript that is
# emitted as-is (the compiler reads ONLY `code` — the editor-UX fields below are never
# compiled, so they don't affect codegen, byte-exact round-trips, or the no-drift packs).
@tool
class_name RawCodeRow
extends Resource

@export var enabled: bool = true
@export_multiline var code: String = ""
@export var source_line: int = 0
## Editor-only, non-emitted. A short human label surfaced on hover so a long escape-hatch
## block reads as one summary line ("what this code does") instead of an opaque wall.
@export var note: String = ""
## Editor-only, non-emitted. Set by the importer when a line could NOT be lifted into a
## structured ACE (e.g. "no matching ACE template"): the "why it stayed code" hint that
## turns an opaque wall of blocks into an actionable triage list (surfaced on hover).
@export var lift_note: String = ""


## Returns the stable row kind identifier.
func get_row_kind() -> String:
	return "raw"
