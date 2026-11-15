# EventSheets - the Write Text File row's help says what happens when the file cannot be opened. The
# template guards the handle, so a bad path writes nothing and reports nothing; its words are frozen,
# so the row's help is where a reader is told.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "write_file_row_help_test"


static func run() -> bool:
	var row: ACEDescriptor = ACERegistry.find_descriptor("Core", "WriteTextFile")
	if row == null:
		return SUPPORT.check(P, "the row exists", false, true)
	return SUPPORT.pins(P, [
		["the help says nothing is written when the file cannot be opened", row.description.contains("nothing is written"), true],
		["and that no error is shown", row.description.contains("no error is shown"), true],
		["and names the exported-game case", row.description.contains("res://"), true],
		["the template keeps its bytes", row.codegen_template,
			"var __file_{uid} = FileAccess.open({path}, FileAccess.WRITE)\nif __file_{uid}:\n\t__file_{uid}.store_string({text})\n\t__file_{uid}.close()"],
	])
