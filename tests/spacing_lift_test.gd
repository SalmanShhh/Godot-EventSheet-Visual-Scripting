# EventForge - spacing-preserving reverse-lift (opened-file path).
#
# Idiomatic hand-written GDScript puts TWO blank lines between top-level functions, but the compiler emits
# ONE between trigger sections (single-blank is the frozen generated style). Before this fix, a hand-written
# .gd with 2+ trigger functions failed the whole-file byte-verify on that 1-vs-2 difference and reverted the
# ENTIRE file to a verbatim block. The lifter now captures each inter-function blank count (transient meta
# __source_leading_blanks on the trigger group's leading event) and the compiler re-emits it on the external
# path, so hand-written multi-trigger files lift while generated packs stay single-blank and byte-identical.
@tool
class_name SpacingLiftTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# The core win: two lifecycle triggers separated by TWO blank lines (idiomatic style). Before the fix
	# this reverted the whole file to raw; now it lifts to two events AND round-trips byte-for-byte.
	var two_blank: String = "extends Node\n\n\nfunc _ready() -> void:\n\tvisible = false\n\n\nfunc _process(delta: float) -> void:\n\trotation += delta\n"
	ok = _check("two-blank multi-trigger lifts (not one raw block)", _event_rows(two_blank) >= 2, true) and ok
	ok = _check("two-blank multi-trigger round-trips byte-identically", _roundtrip(two_blank), true) and ok

	# The single-blank companion must behave EXACTLY as before (default path, no meta stamped): still lifts
	# and round-trips. This proves the field reproduces either spacing rather than normalizing to one shape.
	var one_blank: String = "extends Node\n\n\nfunc _ready() -> void:\n\tvisible = false\n\nfunc _process(delta: float) -> void:\n\trotation += delta\n"
	ok = _check("one-blank multi-trigger still lifts", _event_rows(one_blank) >= 2, true) and ok
	ok = _check("one-blank multi-trigger round-trips byte-identically", _roundtrip(one_blank), true) and ok

	# Three triggers, each gap two blanks: the per-boundary counts are independent and none double-counts the
	# first (prelude -> first func) gap, which the boundary-detach path already owns.
	var three: String = "extends Node\n\n\nfunc _ready() -> void:\n\tvisible = false\n\n\nfunc _process(delta: float) -> void:\n\trotation += delta\n\n\nfunc _physics_process(delta: float) -> void:\n\tposition.x += delta\n"
	ok = _check("three two-blank triggers all lift", _event_rows(three) >= 3, true) and ok
	ok = _check("three two-blank triggers round-trip byte-identically", _roundtrip(three), true) and ok

	# Fail-safe: a two-blank gap before a function whose body cannot fully lift must still round-trip - it
	# reverts to verbatim, preserving the source (including its two blanks) exactly. flags |= 2 has no ACE.
	var irreducible: String = "extends Node\n\n\nfunc _ready() -> void:\n\tvisible = false\n\n\nfunc _process(delta: float) -> void:\n\tflags |= 2\n"
	ok = _check("irreducible two-blank file still round-trips (verbatim fallback)", _roundtrip(irreducible), true) and ok

	return ok


## The number of top-level EventRow rows the import produced (0 means the file reverted to raw blocks).
static func _event_rows(source: String) -> int:
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	var count: int = 0
	for row: Variant in imported.events:
		if row is EventRow:
			count += 1
	return count


## Import the source, recompile through the external path, and report whether it reproduced byte-for-byte.
static func _roundtrip(source: String) -> bool:
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	imported.external_source_path = "user://spacing_rt.gd"
	var output: String = str(SheetCompiler.compile(imported, "user://spacing_rt.gd").get("output", ""))
	return output == source


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] spacing_lift_test: %s" % label)
		return true
	print("[FAIL] spacing_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
