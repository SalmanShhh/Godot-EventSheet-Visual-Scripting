# Godot EventSheets - a string default written over two source lines opens whole.
#
#	var greeting := "hello
#	world"
#
# used to open as the variable `greeting` with the default `"hello` plus a stray wordless row for
# `world"`. The declaration lift now takes the whole literal, gated by byte-exact re-emission: the
# file saved untouched is the file that was opened, and the row is a variable, not a code wall.
@tool
class_name MultilineStringDefaultTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const FIXTURE := "res://tests/fixtures/multiline_string_default.gd"
const VERIFY_PATH := "user://multiline_string_default_verify.gd"


static func run() -> bool:
	var source: String = FileAccess.get_file_as_string(FIXTURE)
	var sheet: EventSheetResource = SUPPORT.reopen(source, true, FIXTURE)
	var variables: PackedStringArray = PackedStringArray()
	var greeting_value: String = ""
	var verbatim_rows: int = 0
	if sheet != null:
		for row: Variant in sheet.events:
			if row is LocalVariable:
				variables.append((row as LocalVariable).name)
				if (row as LocalVariable).name == "greeting":
					greeting_value = str((row as LocalVariable).default_value)
			elif row is RawCodeRow and str((row as RawCodeRow).code).contains("world\""):
				verbatim_rows += 1
	var typed: String = "extends Node\n\nvar note: String = \"one\ntwo\"  # trailing\nvar after: int = 1\n"
	var single: String = "extends Node\n\nvar quote := \"a \\\" b\"\nvar apostrophe := 'it'\n"
	return SUPPORT.pins("multiline_string_default_test", [
		["the declaration and the one after it open as variable rows", variables, PackedStringArray(["greeting", "plain"])],
		["no stray row holds the second line of the literal", verbatim_rows, 0],
		["the fixture saves back byte for byte", SUPPORT.reemit(source, VERIFY_PATH), source],
		["a typed literal over two lines with a trailing comment saves back byte for byte", SUPPORT.reemit(typed, VERIFY_PATH), typed],
		["a single-line string with an escaped quote is unchanged", SUPPORT.reemit(single, VERIFY_PATH), single],
		["the row's value text shows the break as the backslash-n escape", ViewportRowBuilder.string_break_as_escape(greeting_value), "\"hello\\nworld\""],
		["a single-quoted literal reads the same way", ViewportRowBuilder.string_break_as_escape("'a\nb'"), "'a\\nb'"],
		["a one-line string is left as it is", ViewportRowBuilder.string_break_as_escape("\"a\\nb\""), "\"a\\nb\""],
		["a value that is not one quoted literal is left as it is", ViewportRowBuilder.string_break_as_escape("[\n1,\n2\n]"), "[\n1,\n2\n]"],
	])
