# Godot EventSheets - a table of pins, and one place that says how one failed.
#
# Most tests in this suite are the same shape: a dictionary of input to expected answer, and a loop
# that asks the code and compares. Written out per test that loop is four lines each time, and every
# one of them prints its failure slightly differently - some name the input, some do not, some print
# the whole table, and the house rule (compare VALUES, never counts, and never `a and b` against a
# string) is re-learned per file rather than carried by anything.
#
# So the loop lives here. A test hands over its own name, its table, and the callable that answers
# one input; a failure prints the same line every time:
#
#     [FAIL] my_test: "input" - expected "the answer", got "something else"
#
# and the whole table is walked whether the first pin fails or not, because the second failure is
# usually what says which of the two ideas is wrong.
#
# USAGE - a helper, not a test (it declares no `run`, so the suite skips it):
#
#     const Pins := preload("res://tests/pin_table.gd")
#     ok = Pins.check("my_test", {"a": 1, "b": 2}, func(key: String) -> Variant:
#         return MyThing.value_of(key)) and ok
@tool
extends RefCounted


## Every pin in `pins`, asked of `answer` and compared by VALUE. Returns true when every one held.
## `answer` takes the key and returns what the code says; anything comparable with `==` works, so a
## pin can be a String, a number, an Array or a Dictionary.
static func check(test_name: String, pins: Dictionary, answer: Callable) -> bool:
	var passed: bool = true
	for key: Variant in pins.keys():
		var expected: Variant = pins[key]
		var actual: Variant = answer.call(key)
		if _same(actual, expected):
			continue
		print("[FAIL] %s: %s - expected %s, got %s"
			% [test_name, _shown(key), _shown(expected), _shown(actual)])
		passed = false
	return passed


## One value, pinned, for the assertions that are not a table. Same failure line, same rule: this
## takes VALUES, so `check_value(name, label, a and b, "text")` cannot be written by accident.
static func check_value(test_name: String, label: String, actual: Variant, expected: Variant) -> bool:
	if _same(actual, expected):
		return true
	print("[FAIL] %s: %s - expected %s, got %s"
		% [test_name, label, _shown(expected), _shown(actual)])
	return false


## Equality that means what a test means by it. `==` on two Arrays or two Dictionaries compares
## their CONTENTS in GDScript, which is what a pin wants; the one case worth naming is a typed
## PackedStringArray against an untyped Array of the same strings, which `==` calls different.
static func _same(actual: Variant, expected: Variant) -> bool:
	if actual is PackedStringArray or expected is PackedStringArray:
		return Array(actual) == Array(expected)
	return actual == expected


## A value as a failure line should show it: quoted when it is text, so an empty answer and a
## missing one look different, and short enough that a table of forty does not bury the report.
static func _shown(value: Variant) -> String:
	var text: String = "\"%s\"" % value if value is String or value is StringName else str(value)
	return text if text.length() <= 200 else text.substr(0, 197) + "..."
