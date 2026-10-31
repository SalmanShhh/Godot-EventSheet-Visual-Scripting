# Godot EventSheets - an enum carries its own description and one sentence per member.
#
# The sentences are `##` lines: one block right above the `enum` line (what the enum is for) and one
# line right above each member (what that member means). Godot's own help shows both. They are lifted
# back into the row and written out in the same place, so a file that has them round-trips byte for
# byte, and an enum without them is written exactly as it always was.
@tool
class_name EnumDescriptionsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "enum_descriptions_test"

const WITH_NOTES := "class_name EnumNotesFixture\nextends Node\n\n## What the player is doing: standing, running or in the air.\nenum State {\n\t## Standing still on the floor.\n\tIDLE,\n\t## Moving left or right on the floor.\n\tRUN,\n\tJUMP,\n}\n"


static func run() -> bool:
	var kind: EventSheetBlockKind = EventSheetBlockRegistry.get_kind("enum")
	var row: EnumRow = EnumRow.new()
	row.enum_name = "State"
	row.members = PackedStringArray(["IDLE", "RUN"])
	var rows: Array = [
		["an enum with no sentence is written as ever", kind.emit_lines(row), PackedStringArray(["enum State { IDLE, RUN }"])],
	]
	row.description = "What it is."
	rows.append(["a description sits right above the enum line", kind.emit_lines(row),
		PackedStringArray(["## What it is.", "enum State { IDLE, RUN }"])])
	row.member_notes["RUN"] = "Moving."
	rows.append(["a member note forces one member per line and sits above its member", kind.emit_lines(row),
		PackedStringArray(["## What it is.", "enum State {", "\tIDLE,", "\t## Moving.", "\tRUN,", "}"])])
	row.members = PackedStringArray(["RUN = 3", "IDLE"])
	rows.append(["a note follows its member by name, not by position", kind.emit_lines(row),
		PackedStringArray(["## What it is.", "enum State {", "\t## Moving.", "\tRUN = 3,", "\tIDLE,", "}"])])

	var sheet: EventSheetResource = EventSheets.open_gd_as_sheet(WITH_NOTES)
	var lifted: EnumRow = null
	for entry: Variant in sheet.events:
		if entry is EnumRow:
			lifted = entry as EnumRow
	rows.append(["a file with the sentences opens an enum row", lifted != null, true])
	if lifted != null:
		rows.append(["the description is lifted", lifted.description, "What the player is doing: standing, running or in the air."])
		rows.append(["the first member's note is lifted", lifted.note_for("IDLE"), "Standing still on the floor."])
		rows.append(["the second member's note is lifted", lifted.note_for("RUN"), "Moving left or right on the floor."])
		rows.append(["a member without a note has none", lifted.note_for("JUMP"), ""])
		rows.append(["the sentences are not left behind as a code block", _raw_blocks_naming(sheet, "What the player is doing"), 0])
	rows.append(["the file round-trips byte for byte", EventSheets.round_trips(WITH_NOTES), true])
	return SUPPORT.pins(P, rows)


static func _raw_blocks_naming(sheet: EventSheetResource, needle: String) -> int:
	var found: int = 0
	for entry: Variant in sheet.events:
		if entry is RawCodeRow and (entry as RawCodeRow).code.contains(needle):
			found += 1
	return found
