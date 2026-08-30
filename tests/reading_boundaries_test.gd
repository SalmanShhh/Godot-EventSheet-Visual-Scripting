# Godot EventSheets - where the STRUCTURED reading stops, said out loud.
#
# Two declarations read as structure rather than as a wall of code: a multi-line enum is an enum row
# that remembers its shape (explicit values, the trailing comma or its absence), and an inner class is
# a fold whose members read as the rows they would be at top level. Both are byte-gated - a shape the
# emitter cannot reproduce is never claimed - and the point of this file is the OTHER side of that
# gate: the shapes that stay honest code, on purpose, and still save as themselves.
#
# A boundary nobody has watched hold is a boundary that has quietly moved. So each one is pinned
# twice: as the reading it gets, and as the file coming back byte for byte either way.
@tool
class_name ReadingBoundariesTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true
	ok = _test_enum_shapes() and ok
	ok = _test_class_shapes() and ok
	return ok


## The multi-line enum, and the two neighbours of it that stay code. A doc comment above the block is
## part of the declaration and does not stop it reading; a comment INSIDE the block, and an enum with
## no name at all, are shapes the enum row cannot re-emit, so they stay the code they are.
static func _test_enum_shapes() -> bool:
	var documented: String = _file(PackedStringArray([
		"## The states this thing can be in.",
		"enum State {",
		"\tIDLE = 0,",
		"\tRUN = 1,",
		"}"
	]))
	var ok: bool = _check("a documented multi-line enum reads as an enum row",
		_reads_as_enum(documented), true)
	ok = _check("with its explicit values and its trailing comma remembered",
		_enum_members(documented), PackedStringArray(["IDLE = 0", "RUN = 1"])) and ok
	ok = _check("and the file saves as itself", EventSheets.round_trips(documented), true) and ok
	var commented: String = _file(PackedStringArray([
		"enum State {",
		"\t# the resting one",
		"\tIDLE = 0,",
		"}"
	]))
	ok = _check("a comment among the members keeps the enum as code",
		_reads_as_enum(commented), false) and ok
	ok = _check("and that file saves as itself too",
		EventSheets.round_trips(commented), true) and ok
	var anonymous: String = _file(PackedStringArray(["enum {", "\tA,", "\tB,", "}"]))
	ok = _check("an enum with no name stays code", _reads_as_enum(anonymous), false) and ok
	ok = _check("and saves as itself", EventSheets.round_trips(anonymous), true) and ok
	return ok


## The inner class, and the shape the fold cannot hold. A class of fields is a data-class block and a
## class with methods is a class block; a class INSIDE a class is neither, and stays code.
static func _test_class_shapes() -> bool:
	var data_class: String = "\n".join(PackedStringArray([
		"class Stats:", "\tvar hp: int = 10", "\tvar name: String = \"x\""]))
	var ok: bool = _check("a class of fields reads as a data class",
		ViewportRowBuilder.data_class_lifts(data_class), true)
	var methods_class: String = "\n".join(PackedStringArray([
		"class Stats:", "\tvar hp: int = 10", "", "\tfunc bump() -> void:", "\t\thp += 1"]))
	ok = _check("a class with methods reads as a class block",
		ViewportRowBuilder.methods_class_lifts(methods_class), true) and ok
	# Disjoint by construction: exactly one recogniser claims a class, so a reading can never be two
	# things at once.
	ok = _check("and no class is both",
		[ViewportRowBuilder.methods_class_name(data_class),
			ViewportRowBuilder.data_class_name(methods_class)], ["", ""]) and ok
	var nested: String = "\n".join(PackedStringArray([
		"class Outer:", "\tclass Inner:", "\t\tvar hp: int = 1"]))
	ok = _check("a class inside a class is held by neither reading",
		[ViewportRowBuilder.data_class_name(nested), ViewportRowBuilder.methods_class_name(nested)],
		["", ""]) and ok
	ok = _check("and stays code that saves as itself",
		EventSheets.round_trips(_file(PackedStringArray(nested.split("\n")))), true) and ok
	return ok


## True when a source opens with an enum ROW in it rather than the block as code.
static func _reads_as_enum(source: String) -> bool:
	for row: Variant in EventSheets.open_gd_as_sheet(source).events:
		if row is EnumRow:
			return true
	return false


## The members the enum row recovered, or empty when nothing read as one.
static func _enum_members(source: String) -> PackedStringArray:
	for row: Variant in EventSheets.open_gd_as_sheet(source).events:
		if row is EnumRow:
			return (row as EnumRow).members
	return PackedStringArray()


## One declaration as a whole file, so every pin above is asked of a real opened script.
static func _file(declaration: PackedStringArray) -> String:
	var lines: PackedStringArray = PackedStringArray(["extends Node", ""])
	lines.append_array(declaration)
	lines.append("")
	return "\n".join(lines)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] reading_boundaries_test: %s" % label)
		return true
	print("[FAIL] reading_boundaries_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
