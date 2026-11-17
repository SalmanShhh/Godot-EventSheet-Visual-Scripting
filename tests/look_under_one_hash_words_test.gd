# Godot EventSheets - a variable's look mark survives one-hash annotation words above its description.
#
# A built pack writes a member's annotation words as one-hash comments ABOVE its `##` description, because
# Godot drops a description when an ordinary comment line sits between the `##` block and the member. The
# look comment of a variable sits above those words, so the reader has to see the look through them. This
# pins: the variable still wears its look and is one row, the file writes back byte for byte, the
# description stays directly above the member, a file with the words below the description (two hashes, or
# one) reads the same rows, and two shipped scripts open with the rows they had before the words moved.
@tool
class_name LookUnderOneHashWordsTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P: String = "look_under_one_hash_words_test"
const VERIFY_NAME: String = "look_under_one_hash_words_test_verify.gd"
const HEAD: String = "extends Node\n\n"

const GROUPED_WORDS_FIRST: String = "# @inspector_look unit:kinds=px|world|screen,store=px
@export_group(\"Stroke\")
# @ace_hidden
## Stroke width.
@export_range(0, 1, 0.001, \"or_greater\", \"or_less\", \"hide_slider\", \"suffix:px\") var thickness: float = 2.0:
	set(value):
		thickness = value
		queue_redraw()
"
const PLAIN_WORDS_FIRST: String = "# @inspector_look toggle_row:segmented
# @ace_hidden
## What the ends look like.
@export_enum(\"none\", \"square\", \"round\") var caps: String = \"round\"
"
const TWO_WORDS_FIRST: String = "# @inspector_look progress_bar
## @ace_hidden
## Hit points.
@export_range(0, 200) var health: int = 120
"
const TWO_WORDS_BELOW: String = "# @inspector_look progress_bar
## Hit points.
## @ace_hidden
@export_range(0, 200) var health: int = 120
"
const ONE_WORDS_BELOW: String = "# @inspector_look progress_bar
## Hit points.
# @ace_hidden
@export_range(0, 200) var health: int = 120
"
const NO_LOOK_WORDS_FIRST: String = "@export_group(\"Stroke\")
# @ace_hidden
## Stroke width.
@export var width: float = 1.0
"
## The rows and the look marks these two scripts opened with before the words moved above the descriptions.
const SHIPPED: Array = [
	["res://eventsheet_addons/vector_shapes/shape_disc_2d.gd", 63, "thickness:unit,colour:swatch_row,colour_b:swatch_row,colour_c:swatch_row,colour_d:swatch_row,dash_style:toggle_row"],
	["res://eventsheet_addons/vector_shapes/shape_polygon_3d.gd", 49, "geometry:toggle_row,thickness_unit:toggle_row,colour:swatch_row,colour_b:swatch_row,colour_c:swatch_row,colour_d:swatch_row,border_colour:swatch_row,depth:toggle_row"],
]


static func run() -> bool:
	var ok: bool = true
	for fixture: Array in [
			["words above the description, in a group, over a property", GROUPED_WORDS_FIRST, "unit"],
			["words above the description, no group", PLAIN_WORDS_FIRST, "toggle_row"],
			["two-hash words above the description", TWO_WORDS_FIRST, "progress_bar"],
			["two-hash words below the description", TWO_WORDS_BELOW, "progress_bar"],
			["one-hash words below the description", ONE_WORDS_BELOW, "progress_bar"]]:
		var label: String = str(fixture[0])
		var source: String = HEAD + str(fixture[1])
		var sheet: EventSheetResource = SUPPORT.reopen(source, true)
		var variable: LocalVariable = _first_variable(sheet)
		ok = SUPPORT.check(P, "%s: the head and one variable row, wearing its look" % label,
			[sheet.events.size(), str(variable.attributes.get("drawer", "")) if variable != null else "none", bool(variable.attributes.get("look_line", false)) if variable != null else false],
			[2, str(fixture[2]), true]) and ok
		ok = SUPPORT.check(P, "%s: writes back byte for byte" % label, SUPPORT.reemit(source, SUPPORT.own_path(VERIFY_NAME)), source) and ok
	var written: PackedStringArray = SUPPORT.reemit(HEAD + GROUPED_WORDS_FIRST, SUPPORT.own_path(VERIFY_NAME)).split("\n")
	var declaration: int = -1
	for at: int in range(written.size()):
		if written[at].contains(" var thickness"):
			declaration = at
	ok = SUPPORT.check(P, "the description stays directly above the member",
		written[declaration - 1] if declaration > 0 else "", "## Stroke width.") and ok
	ok = SUPPORT.check(P, "a hidden field with no look comment is read as before",
		SUPPORT.reemit(HEAD + NO_LOOK_WORDS_FIRST, SUPPORT.own_path(VERIFY_NAME)), HEAD + NO_LOOK_WORDS_FIRST) and ok
	var below: LocalVariable = _first_variable(SUPPORT.reopen(HEAD + TWO_WORDS_BELOW, true))
	var above: LocalVariable = _first_variable(SUPPORT.reopen(HEAD + TWO_WORDS_FIRST, true))
	ok = SUPPORT.check(P, "words above and words below read the same variable",
		[above.name, above.type_name, above.leading_lines, str(above.attributes.get("tooltip", ""))],
		[below.name, below.type_name, below.leading_lines, str(below.attributes.get("tooltip", ""))]) and ok
	ok = SUPPORT.check(P, "a comment block that leads with a plain note keeps it first and shows its description before its words",
		EventSheetViewportRowBuilder.comment_display_order(PackedStringArray(["# @inspector_link a b", "## @ace_hidden", "## How many."]), true), [0, 2, 1]) and ok
	for shipped: Array in SHIPPED:
		var path: String = str(shipped[0])
		var opened: EventSheetResource = SUPPORT.reopen(FileAccess.get_file_as_string(path), true, path)
		var marks: PackedStringArray = PackedStringArray()
		for row: Variant in opened.events:
			if row is LocalVariable and str((row as LocalVariable).attributes.get("drawer", "")) != "":
				marks.append("%s:%s" % [(row as LocalVariable).name, (row as LocalVariable).attributes.get("drawer")])
		ok = SUPPORT.check(P, "%s opens with its rows and its look marks" % path.get_file(),
			[opened.events.size(), ",".join(marks)], [int(shipped[1]), str(shipped[2])]) and ok
	return ok


static func _first_variable(sheet: EventSheetResource) -> LocalVariable:
	if sheet == null:
		return null
	for row: Variant in sheet.events:
		if row is LocalVariable:
			return row as LocalVariable
	return null
