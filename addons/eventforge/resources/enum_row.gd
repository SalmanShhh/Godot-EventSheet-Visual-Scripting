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
## What the enum is for, written as the `##` lines right above the `enum` line (Godot's own help shows
## them as the enum's description). Empty writes nothing, so every enum without one is byte-identical.
@export var description: String = ""
## One sentence per member, keyed by the member's bare name (no `= value`), written as `##` lines right
## above that member. Keyed by name rather than by position so reordering the members cannot move a
## sentence onto the wrong one. An enum with any note is written one member per line, the only shape
## a note can sit above its member in.
@export var member_notes: Dictionary = {}


## Returns the stable row kind identifier.
func get_row_kind() -> String:
	return "enum"


## The bare name of a member as written ("HURT = 4" is HURT).
static func bare_name(member: String) -> String:
	return member.split("=")[0].strip_edges()


## The sentence written above a member, "" when it has none.
func note_for(member: String) -> String:
	return str(member_notes.get(bare_name(member), "")).strip_edges()


## True when any member carries a note, which is what forces the one-member-per-line shape.
func has_member_notes() -> bool:
	for member: String in members:
		if not note_for(member).is_empty():
			return true
	return false
