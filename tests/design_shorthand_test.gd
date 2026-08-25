# EventSheet - the design-shorthand gate.
#
# Features are designed away from the code, in notes that number their items: a letter for the
# batch and a number for the item. Those labels are useful for a week and meaningless forever
# after - and they leaked, three and a half thousand times, into comments that opened with one
# instead of with a sentence, and into comments that leaned on one in the middle of a sentence to
# name a rule. Every one of them asked a future contributor to go and find a document that is not
# in this repository, to learn something the sentence beside it could simply have said.
#
# So the rule is: a comment states the CONSTRAINT, never the label of the note the constraint came
# from. "The four families most small scripts are made of" says what a batch letter and a number
# never did, and it is the same number of characters.
#
# Two shapes are swept, across every text file the repository tracks:
#   1. a capital letter followed by one or two digits, standing on its own as a word;
#   2. the word "mockup", in code, used to point at a design drawing.
# Both carry a small allow-list, and both prove their detector before they trust their sweep.
@tool
class_name DesignShorthandTest
extends RefCounted

## Text formats worth sweeping. Binary and generated caches carry no prose.
const TEXT_EXTENSIONS: Array[String] = ["gd", "md", "cfg", "csv", "json", "yml", "yaml",
	"txt", "tres", "tscn", "godot", "gdshader", "esdoc", "ps1"]

## Not repository content: local editor state and engine caches, every one of them ignored by
## git, plus the agent worktrees that hold whole COPIES of this repository (including this file,
## whose detector examples are the very thing it forbids).
const LOCAL_STATE_DIRS: Array[String] = [".git", ".godot", ".import", ".vscode", ".idea",
	".claude", "__pycache__", "eventsheet_translations"]

## The one folder where design notes belong, and where their own numbering is the point: the
## working notes a slice is planned in. Nothing under it ships, and nothing in the plugin reads it.
const DESIGN_NOTES_DIR: String = "res://docs/internal/"

## The file that defines the rule must contain examples of the thing it forbids.
const SELF_PATH: String = "res://tests/design_shorthand_test.gd"

## A letter and one or two digits, standing alone as a word.
const SHORTHAND_PATTERN: String = "\\b[A-Z][0-9]{1,2}\\b"

## The same label in a FILE NAME, where the house style is lowercase and underscores:
## `variable_dialog_v5_test.gd` is a test named after a design item instead of after what it
## pins. Only a whole underscore-separated part counts, so `native_3d_aces.gd` (a real word for
## a real thing) and `pin_3d.gd` are untouched.
const FILE_NAME_PATTERN: String = "(?:^|_)([a-z][0-9]{1,2})(?:_|\\.)"

## Letter-digit words that are not design labels, each for a reason a reader can check:
##   A4       the paper size a sheet export defaults to;
##   F1-F12   keyboard keys, named in tooltips and shortcut tables;
##   H1-H6    Markdown heading levels, named by the documentation viewer.
const ALLOWED_TOKENS: Array[String] = ["A4", "F1", "F2", "F3", "F4", "F5", "F6", "F7",
	"F8", "F9", "F10", "F11", "F12", "H1", "H2", "H3", "H4", "H5", "H6"]

## The other event-sheet editor's short name is a letter and a digit as well. It appears in prose
## only, and a sweep of its own already governs where it may appear, so this one leaves it alone.
## Spelled here as its two parts on purpose: naming another product in code is exactly what that
## other sweep forbids, and this file is not exempt from it.
const OTHER_EDITOR_TOKEN: String = "C" + "3"

## Fragments that mark a line as machine data rather than prose, where a letter-digit pair means
## something else entirely: `[A-Z0-9_]` is a regular expression's character class and `Z0` is two
## of its endpoints; an inline SVG's path data is a stream of coordinates prefixed by commands.
const NOT_PROSE_MARKERS: Array[String] = ["A-Z0-9", "<svg", "<path "]

## The design word, and the one place it is allowed to stand: a bundled theme is a product whose
## NAME a user reads in the theme list, so it keeps it.
const DESIGN_WORD: String = "mockup"
const DESIGN_WORD_ALLOWED: Array[String] = ["mockup_slate", "mockup slate", "mockup-slate",
	"mockup_theme"]

## Compiled once for the whole sweep: these run over every line of every text file, and
## recompiling per line turned a two-second gate into a two-minute one.
static var _shorthand: RegEx = null
static var _file_name: RegEx = null

## Where the design word is forbidden. Prose may say what a feature was drawn from; a comment in
## the code may not, because the code is what a contributor has in front of them.
const CODE_EXTENSIONS: Array[String] = ["gd", "ps1"]


static func run() -> bool:
	var ok: bool = true

	# The detector, pinned by value. Proving it FIRST matters: a sweep that silently matched
	# nothing would report a clean repository just as convincingly as a clean one does.
	ok = _check("a label opening a comment is shorthand",
		_first_violation("addons/x.gd", "# W6. A menu handler's body") != "", true) and ok
	ok = _check("a label inside a sentence is shorthand",
		_first_violation("addons/x.gd", "## the case P8 is actually about") != "", true) and ok
	ok = _check("a label in a test name is shorthand",
		_first_violation("tests/variable_dialog_v5_test.gd", "extends RefCounted") != "", true) and ok
	ok = _check("the violation names the label it found",
		_first_violation("addons/x.gd", "# X30. The aimed floor").contains("X30"), true) and ok
	ok = _check("a drawing the code points at is shorthand",
		_first_violation("addons/x.gd", "## the order the mockup approved") != "", true) and ok

	# ...and the exemptions, or the gate becomes noise somebody switches off.
	ok = _check("a keyboard key is not shorthand",
		_first_violation("addons/x.gd", "## F2 renames this class everywhere."), "") and ok
	ok = _check("the other editor's name is not shorthand",
		_first_violation("docs/x.md", OTHER_EDITOR_TOKEN + " muscle memory carries over."), "") and ok
	ok = _check("a paper size is not shorthand",
		_first_violation("addons/x.gd", "## A4 at 96 dpi in portrait."), "") and ok
	ok = _check("a heading level is not shorthand",
		_first_violation("addons/x.gd", "## the H1 of each page, for trees"), "") and ok
	ok = _check("a character class is not shorthand",
		_first_violation("addons/x.gd", "\tRegEx.create_from_string(\"[A-Z0-9_]+\")"), "") and ok
	ok = _check("the bundled theme keeps its name",
		_first_violation("tests/x.gd", "\"res://addons/eventsheet/themes/mockup_slate_theme.tres\""), "") and ok
	ok = _check("prose may still say where a feature was drawn from",
		_first_violation("CHANGELOG.md", "Drawn from a mockup audited twice"), "") and ok
	ok = _check("a lowercase letter and a digit is not a label",
		_first_violation("addons/x.gd", "## the p2 field of the row"), "") and ok

	# The live sweep. Non-vacuity is asserted before the verdict, for the same reason.
	var violations: PackedStringArray = PackedStringArray()
	var scanned: int = _scan_directory("res://", violations)
	ok = _check("the sweep actually reads this project's text files", scanned > 100, true) and ok
	for violation: String in violations:
		print("  design shorthand: %s" % violation)
	ok = _check("no file names a design note instead of stating what it means (%d scanned)" % scanned,
		violations.size(), 0) and ok
	return ok


## The first design-shorthand leak in `text`, as a reportable line, or "" when it is clean.
## Static and pure, so the rule above is provable without touching the filesystem.
static func _first_violation(path: String, text: String) -> String:
	var name_hit: String = _label_in_file_name(path.get_file())
	if not name_hit.is_empty():
		return "%s - the file name says '%s' instead of what it pins" % [path, name_hit]
	var is_code: bool = CODE_EXTENSIONS.has(path.get_extension().to_lower())
	var lines: PackedStringArray = text.split("\n")
	for index: int in lines.size():
		var line: String = lines[index]
		if _is_not_prose(line):
			continue
		var hit: String = _shorthand_in(line)
		if not hit.is_empty():
			return "%s:%d - '%s' names a design note; say what it means instead" % [path, index + 1, hit]
		if is_code and _points_at_a_drawing(line):
			return "%s:%d - a comment points at a design drawing; state the constraint instead" \
				% [path, index + 1]
	return ""


## The first design label in one line, or "" when there is none.
static func _shorthand_in(line: String) -> String:
	if _shorthand == null:
		_shorthand = RegEx.create_from_string(SHORTHAND_PATTERN)
	for found: RegExMatch in _shorthand.search_all(line):
		var token: String = found.get_string()
		if not ALLOWED_TOKENS.has(token) and token != OTHER_EDITOR_TOKEN:
			return token
	return ""


## The design label a file NAME carries, or "" when it carries none.
static func _label_in_file_name(file_name: String) -> String:
	if _file_name == null:
		_file_name = RegEx.create_from_string(FILE_NAME_PATTERN)
	var found: RegExMatch = _file_name.search(file_name)
	return "" if found == null else found.get_string(1)


## True when the line is machine data rather than prose (see NOT_PROSE_MARKERS).
static func _is_not_prose(line: String) -> bool:
	for marker: String in NOT_PROSE_MARKERS:
		if line.contains(marker):
			return true
	return false


## True when a line names the drawing a feature was designed from rather than the rule it follows.
static func _points_at_a_drawing(line: String) -> bool:
	var lowered: String = line.to_lower()
	if not lowered.contains(DESIGN_WORD):
		return false
	for allowed: String in DESIGN_WORD_ALLOWED:
		if lowered.contains(allowed.to_lower()):
			return false
	return true


static func _scan_directory(dir_path: String, violations: PackedStringArray) -> int:
	var scanned: int = 0
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return 0
	# Hidden entries are listed deliberately, then filtered BY NAME. A dot-directory is only
	# OS-hidden on some platforms, so leaving it to the default would sweep `.github` on one
	# machine and quietly skip it on another - and `.github` holds real prose.
	dir.include_hidden = true
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		var full_path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			if not LOCAL_STATE_DIRS.has(entry) and full_path + "/" != DESIGN_NOTES_DIR:
				scanned += _scan_directory(full_path, violations)
		elif full_path == SELF_PATH:
			pass
		elif TEXT_EXTENSIONS.has(entry.get_extension().to_lower()):
			scanned += 1
			var violation: String = _first_violation(full_path, FileAccess.get_file_as_string(full_path))
			if not violation.is_empty():
				violations.append(violation)
		entry = dir.get_next()
	dir.list_dir_end()
	return scanned


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] design_shorthand_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
