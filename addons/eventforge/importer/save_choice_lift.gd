# EventForge - the block a variable's Save choice writes, read back as the choices it came from.
#
# compiler/save_choices.gd appends one block at the end of a file whose variables are saved: the boot
# member, the load and store functions over user://remembered.cfg, and the save_state()/load_state()
# pair. Opened again, that block would read as four functions nobody wrote by hand, and the choice on
# each variable would be lost. So the importer cuts the block off the tail before it reads the file,
# reads which variable each line names, and puts the choice back on the variable:
#
#   loaded at ready and stored on leaving  -> Auto
#   loaded at ready, stored at Save Game   -> Load only
#   stored on leaving, never loaded        -> Save only
#   only in save_state()/load_state()      -> Manual
#
# Then the whole file is compiled again and compared byte for byte with what was opened. Anything a
# person changed in the block - or a save_state() they wrote themselves, which never carries the
# block's doc line - fails that comparison or is never cut, and stays the code it is.
@tool
extends RefCounted

const SaveChoices := preload("res://addons/eventforge/compiler/save_choices.gd")
const VERIFY_PATH: String = "user://eventforge_lift_verify.gd"


## The source with the block cut off, and the choice of every variable the block names:
## {"prefix": String, "choices": {name: choice}}, or {} when the file carries no such block.
static func cut(source: String) -> Dictionary:
	var marker: String = "\n\n" + SaveChoices.DOC + "\n"
	var at: int = source.rfind(marker)
	if at < 0:
		return {}
	var choices: Dictionary = read_choices(source.substr(at + marker.length()))
	if choices.is_empty():
		return {}
	return {"prefix": source.substr(0, at) + "\n", "choices": choices}


## {name: choice} for every variable the block's save_state() names, in that order.
static func read_choices(block: String) -> Dictionary:
	var saved: PackedStringArray = PackedStringArray()
	var loaded: Dictionary = {}
	var stored: Dictionary = {}
	var in_snapshot: bool = false
	for line: String in block.split("\n"):
		if line == "\treturn {":
			in_snapshot = true
		elif line == "\t}":
			in_snapshot = false
		elif in_snapshot and line.begins_with("\t\t\"") and line.contains("\": "):
			saved.append(line.get_slice("\": ", 1).trim_suffix(",").trim_suffix(".duplicate(true)"))
		elif line.begins_with("\t\t") and line.contains(" = __remember_cfg.get_value("):
			loaded[line.strip_edges().get_slice(" = ", 0)] = true
		elif line.begins_with("\t__remember_cfg.set_value("):
			stored[line.trim_suffix(")").get_slice(", ", 2)] = true
	var choices: Dictionary = {}
	for variable_name: String in saved:
		if loaded.has(variable_name):
			choices[variable_name] = "auto" if stored.has(variable_name) else "load"
		else:
			choices[variable_name] = "save" if stored.has(variable_name) else "manual"
	return choices


## Puts each choice back on the sheet's own variable row, then holds the result to the file it came
## from: true only when the sheet compiles to exactly `source`. False leaves the variables unchanged.
static func apply(sheet: EventSheetResource, cut_block: Dictionary, source: String) -> bool:
	var rows: Dictionary = {}
	for entry: Variant in sheet.events:
		if entry is LocalVariable and not (entry as LocalVariable).is_constant:
			rows[(entry as LocalVariable).name] = entry
	var choices: Dictionary = cut_block["choices"]
	for variable_name: String in choices:
		if not rows.has(variable_name):
			return false
	var before: Dictionary = {}
	for variable_name: String in choices:
		var variable: LocalVariable = rows[variable_name]
		before[variable_name] = variable.attributes.duplicate(true)
		var attributes: Dictionary = variable.attributes.duplicate(true)
		SaveChoices.set_choice(attributes, str(choices[variable_name]))
		variable.attributes = attributes
	var saved_path: String = sheet.external_source_path
	sheet.external_source_path = VERIFY_PATH
	var output: String = str(SheetCompiler.compile(sheet, VERIFY_PATH).get("output", ""))
	sheet.external_source_path = saved_path
	if output == source:
		return true
	for variable_name: String in before:
		(rows[variable_name] as LocalVariable).attributes = before[variable_name]
	return false
