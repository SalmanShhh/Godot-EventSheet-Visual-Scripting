@tool
class_name ReadingCensusTest
extends RefCounted

# The census prices a deletion in WHOLE BLOCKS - a function, a match arm - and the two readers that
# find those blocks are plain text walks over GDScript. A walk that miscounts a block by a line
# quietly moves the projection, so both are pinned here over a buffer whose blocks are written out
# where the expected numbers can be counted by hand.
#
# Nothing here runs the census itself: its population is every builtin descriptor and every shipped
# sheet, which takes minutes. What a suite can hold is the arithmetic underneath it.

const SUPPORT := preload("res://tests/support.gd")
const LINES := preload("res://tools/reading_lines.gd")
const CENSUS := preload("res://tools/reading_census.gd")
const P: String = "reading_census_test"

## Two top-level functions and one inner class, with a doc comment and a blank tail between them, so
## the counting rules all have a case: the block is the declaration through its last body line, an
## inner class's own functions are that class's and not the file's, and a trailing blank belongs to
## nobody.
const BUFFER: String = """@tool
extends RefCounted

const THING: int = 1


## Doc comment above the first one.
static func first(value: int) -> int:
	var out: int = value
	return out


class Held extends RefCounted:
	func inner() -> void:
		pass


func second(
	first_value: int,
	second_value: int
) -> void:
	match ace_id:
		"Alpha":
			return
		"Beta", "Gamma":
			var held: int = 1
			held += 1
			return
		_:
			return
	match kind:
		1:
			return
"""


static func run() -> bool:
	var ok: bool = true
	ok = _functions_are_whole_blocks() and ok
	ok = _arms_are_whole_blocks() and ok
	ok = _the_broad_walk_keeps_only_name_dispatch() and ok
	return ok


## A function's block is its declaration through its last body line - what a maintainer removes.
## The inner class's `inner` is NOT one of the file's functions: it belongs to the class.
static func _functions_are_whole_blocks() -> bool:
	var found: Array = CENSUS.functions_in(BUFFER)
	var names: PackedStringArray = PackedStringArray()
	var held: PackedInt32Array = PackedInt32Array()
	for entry: Variant in found:
		names.append(str((entry as Dictionary).get("name", "")))
		held.append(int((entry as Dictionary).get("lines", 0)))
	return SUPPORT.pins(P, [
		["only top-level functions are counted", names, PackedStringArray(["first", "second"])],
		["the first block is its declaration and its two body lines", held[0] if held.size() > 0 else -1, 3],
		["a signature that spans lines does not close the block it opens",
			held[1] if held.size() > 1 else -1, 16],
		["the first block starts at its own func line",
			int((found[0] as Dictionary).get("line", 0)) if found.size() > 0 else -1, 8],
	])


## A match arm is a block too, and its line count is what deleting it saves. The fall-through arm is
## reported rather than dropped: it names no verb, and that is a fact about it. Each arm also names
## the function it sits in, because a file holds several tables that dispatch on the same key and an
## arm credited by its verb alone can be credited from evidence gathered in a different one.
static func _arms_are_whole_blocks() -> bool:
	var arms: Array = LINES.arms_in(BUFFER)
	var ids: Array = []
	var held: PackedInt32Array = PackedInt32Array()
	var functions: PackedStringArray = PackedStringArray()
	for entry: Variant in arms:
		ids.append(PackedStringArray((entry as Dictionary).get("ids", PackedStringArray())))
		held.append(int((entry as Dictionary).get("lines", 0)))
		functions.append(str((entry as Dictionary).get("func", "")))
	return SUPPORT.pins(P, [
		["every arm of the ace_id match is found, the fall-through included", arms.size(), 3],
		["an arm names the verbs it heads with", ids[1] if ids.size() > 1 else PackedStringArray(),
			PackedStringArray(["Beta", "Gamma"])],
		["a one-line arm holds one line", held[0] if held.size() > 0 else -1, 2],
		["a four-line arm holds four", held[1] if held.size() > 1 else -1, 4],
		["the fall-through names no verb", ids[2] if ids.size() > 2 else PackedStringArray(),
			PackedStringArray()],
		["every arm names the function it sits in", functions,
			PackedStringArray(["second", "second", "second"])],
	])


## The broad walk takes every match that dispatches on a NAME and leaves the ones that dispatch on a
## number: a match on an enum is structure, and counting it as vocabulary would inflate the one
## figure the census exists to produce.
static func _the_broad_walk_keeps_only_name_dispatch() -> bool:
	var broad: Array = LINES.arms_in(BUFFER, false)
	var named: int = 0
	for entry: Variant in broad:
		if not PackedStringArray((entry as Dictionary).get("ids", PackedStringArray())).is_empty():
			named += 1
	return SUPPORT.pins(P, [
		["the match on a number contributes no arm", broad.size(), 2],
		["and every arm the broad walk keeps names a verb", named, broad.size()],
	])
