# Godot EventSheets - what a compile says, as a typed object.
#
# `EventSheets.compile()` and `echo()` answer with a Dictionary whose keys a caller has to remember
# ("output", not "source": reading the wrong key gives an empty string that equals every other empty
# string, which makes a broken test pass). `EventSheets.compile_result()` and `echo_result()` answer with
# this instead: the same facts, as variables the script editor completes after the dot and a typo in
# fails the moment the script is parsed.
#
# It carries no behaviour and holds no sheet. The Dictionary calls stay exactly as they were.
@tool
class_name EventSheetCompileResult
extends RefCounted

## True when the script was produced (and, for `compile_result`, written where it was asked to be).
var success: bool = false
## The GDScript the sheet compiles to. Present even when nothing was written.
var output: String = ""
## What stopped the compile or the write, one plain sentence each.
var errors: PackedStringArray = PackedStringArray()
## What the compiler noticed and went on from, one plain sentence each.
var warnings: PackedStringArray = PackedStringArray()
## Which lines of `output` each row wrote: `[{"uid": String, "start": int, "end": int, "kind": String}]`, 1-based and inclusive.
var source_map: Array[Dictionary] = []
## The script the plugin refused to write over because it did not write it (empty when nothing was refused).
var refused_path: String = ""


## The result a compile Dictionary describes. A missing key is its empty value.
static func from_dictionary(compiled: Dictionary) -> EventSheetCompileResult:
	var result: EventSheetCompileResult = EventSheetCompileResult.new()
	result.success = bool(compiled.get("success", false))
	result.output = str(compiled.get("output", ""))
	for error: Variant in compiled.get("errors", []):
		result.errors.append(str(error))
	for warning: Variant in compiled.get("warnings", []):
		result.warnings.append(str(warning))
	for entry: Variant in compiled.get("source_map", []):
		if entry is Dictionary:
			result.source_map.append(entry as Dictionary)
	result.refused_path = str(compiled.get("refused_path", ""))
	return result
