# Godot EventSheets - when a byte gate says no, leave the evidence on disk.
#
# The round-trip gates are the compatibility promise: open somebody's file as a sheet, save it
# untouched, get the same bytes. When one refuses, the failure it prints is a file name and the word
# "drifted" - and every diagnosis after that starts with rebuilding by hand what the gate already
# had in memory: the source, what it re-emitted, and where the two part company.
#
# So the gate writes them down instead. One folder per refusal, under `.godot/repro/` (machine-local
# and ignored by git):
#
#     .godot/repro/<test>/<case>/input.gd       what went in
#     .godot/repro/<test>/<case>/expected.txt   the bytes that were promised
#     .godot/repro/<test>/<case>/actual.txt     the bytes that came back
#     .godot/repro/<test>/<case>/diff.txt       the two, lined up
#
# and prints the path. One helper rather than one per gate, so the folder is the same shape whichever
# promise was broken, and so a gate written next month gets it by calling this.
#
# USAGE - a helper, not a test (it declares no `run`, so the suite skips it):
#
#     const Repro := preload("res://tests/repro_bundle.gd")
#     if emitted != source:
#         print("  %s" % Repro.dump("handwritten_lift_gate_test", path, source, emitted, path))
@tool
extends RefCounted

## Where the bundles live. Under `.godot/`, which is machine-local and ignored by git.
const REPRO_DIR: String = "res://.godot/repro/"

## How many unchanged lines to keep either side of a difference. Three is what a unified diff shows,
## and it is enough to find the place in the file without printing the file.
const CONTEXT_LINES: int = 3


## Writes one bundle and returns a sentence naming it, ready to print. `case_name` is whatever
## identifies this refusal (a path, an entry id); it is made safe for a folder name here, so a
## caller can hand over a `res://` path without thinking about it.
static func dump(test_name: String, case_name: String, expected: String, actual: String,
		input_path: String = "") -> String:
	var folder: String = "%s%s/%s/" % [REPRO_DIR, _safe(test_name), _safe(case_name)]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	_write(folder + "expected.txt", expected)
	_write(folder + "actual.txt", actual)
	_write(folder + "diff.txt", diff(expected, actual))
	if not input_path.is_empty() and FileAccess.file_exists(input_path):
		_write(folder + "input" + _extension(input_path), FileAccess.get_file_as_string(input_path))
	return "repro bundle: %s (input, expected, actual, diff)" % folder


## The two texts lined up, in the shape a unified diff has: a header naming both sides, then the run
## that differs with a few unchanged lines around it. The common head and tail are found by walking
## in from both ends, which is what these failures look like in practice - one hunk, in the middle of
## a file that is otherwise identical. A refusal with several separate differences shows the span
## that covers them all rather than pretending to more precision than that walk has.
static func diff(expected: String, actual: String) -> String:
	if expected == actual:
		return "no difference - the bytes match.\n"
	# A file that ends in a newline splits with an empty last element, which is not a line anybody
	# wrote - left in, it counts one too many and shows as a blank line of context under every diff.
	var left: PackedStringArray = _lines_of(expected)
	var right: PackedStringArray = _lines_of(actual)
	var head: int = 0
	while head < left.size() and head < right.size() and left[head] == right[head]:
		head += 1
	var tail: int = 0
	while tail < left.size() - head and tail < right.size() - head \
			and left[left.size() - 1 - tail] == right[right.size() - 1 - tail]:
		tail += 1
	var from: int = maxi(head - CONTEXT_LINES, 0)
	var lines: PackedStringArray = PackedStringArray([
		"--- expected (%d lines)" % left.size(),
		"+++ actual   (%d lines)" % right.size(),
		"@@ first difference at line %d @@" % (head + 1),
	])
	for index: int in range(from, head):
		lines.append("  " + left[index])
	for index: int in range(head, left.size() - tail):
		lines.append("- " + left[index])
	for index: int in range(head, right.size() - tail):
		lines.append("+ " + right[index])
	for index: int in range(left.size() - tail, mini(left.size() - tail + CONTEXT_LINES, left.size())):
		lines.append("  " + left[index])
	return "\n".join(lines) + "\n"


## The lines of a text, without the empty element a trailing newline leaves behind.
static func _lines_of(text: String) -> PackedStringArray:
	var lines: PackedStringArray = text.split("\n")
	if lines.size() > 0 and lines[lines.size() - 1].is_empty():
		lines.remove_at(lines.size() - 1)
	return lines


## A name safe to be a folder: everything that is not a word, a dash or a dot becomes an underscore,
## so `res://addons/x/y.gd` reads as `addons_x_y.gd` rather than nesting three levels deep.
static func _safe(name: String) -> String:
	const KEPT: String = "abcdefghijklmnopqrstuvwxyz0123456789-._"
	var trimmed: String = name.trim_prefix("res://")
	var out: String = ""
	for index: int in trimmed.length():
		var character: String = trimmed[index]
		out += character if KEPT.contains(character.to_lower()) else "_"
	return out.trim_suffix("_")


static func _extension(path: String) -> String:
	var extension: String = path.get_extension()
	return "" if extension.is_empty() else "." + extension


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()
