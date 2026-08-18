# EventSheet - the other-product-name gate.
#
# This plugin borrows a whole reading tradition, and the code used to say so by name: comments,
# tooltips and test labels named a competing event-sheet editor several hundred times. Prose in
# docs/ may still draw the comparison for a reader who needs it - that is the reader's map. The
# CODE may not: a shipped file that names another product reads as a claim about that product,
# survives every rename it ever makes, and is nobody's map.
#
# So every text file the plugin ships or builds from is swept for two tokens: the capitalised
# product name (in any form - with a version number after it, or a possessive) and its two-letter
# short name.
#
# Ordinary English is untouched: "construct a row", "constructs", "constructor", "reconstruct" all
# pass, and so do their sentence-initial capitals, because the product name is never followed by
# more lower-case letters - a gate that failed on the ordinary verb and noun would be switched off
# within a week. The short name is claimed only as a WHOLE token, so a hex colour and a matrix cell
# that happen to spell it mid-word are not hits.
#
# The needle is assembled from parts at runtime for the obvious reason: a gate that spelled the
# forbidden word out would be its own first violation.
@tool
class_name NoProductNamesInCodeTest
extends RefCounted

## The trees that ARE the plugin: what ships, what generates what ships, and what tests it.
## docs/ and the repo-root prose files are deliberately absent - a migration guide is allowed to
## name the thing somebody is migrating from.
const SWEPT_ROOTS: Array[String] = ["res://addons", "res://tools", "res://tests",
	"res://eventsheet_addons", "res://demo"]

## Text formats worth reading. Binaries and compiled caches carry no prose.
const TEXT_EXTENSIONS: Array[String] = ["gd", "csv", "cfg", "tres", "tscn", "gdshader", "md"]

## Skipped subtrees, by full path. `addons/eventsheet/help/` is the VERBATIM docs mirror the
## release zip ships (tools/build_help_bundle.gd copies docs/*.md there byte for byte), so it is
## documentation that merely lives under addons/ - sweeping it would fail the gate on prose the
## gate deliberately allows, and the only way to "fix" it would be to edit generated files.
const SKIPPED_SUBTREES: Array[String] = ["res://addons/eventsheet/help"]

## Not repository content: engine caches and local editor state, every one ignored by git.
## `.claude` holds agent worktrees - whole COPIES of this repo, including this file - so sweeping
## it reports the copy's own fixtures as violations in the original: a gate failing on itself.
const LOCAL_STATE_DIRS: Array[String] = [".git", ".godot", ".import", ".vscode", ".idea",
	".claude", "__pycache__"]


static func run() -> bool:
	var ok: bool = true

	# The detector, pinned by value first: a sweep that silently matched nothing would report a
	# clean repo exactly as convincingly as a clean repo does.
	ok = _check("the product name is a hit",
		_first_hit("addons/x.gd", "# reads like a %s 3 sheet" % _product_name()) != "", true) and ok
	ok = _check("the possessive form is a hit",
		_first_hit("addons/x.gd", "# %s's loopindex" % _product_name()) != "", true) and ok
	ok = _check("the short name is a hit",
		_first_hit("addons/x.gd", "# the %s keyboard grammar" % _short_name()) != "", true) and ok
	ok = _check("the hit names the file and the line",
		_first_hit("addons/x.gd", "ok\n# %s-style" % _short_name()).begins_with("addons/x.gd:2"),
		true) and ok

	# ...and the exemptions, or the gate becomes noise.
	ok = _check("the ordinary verb is not a hit",
		_first_hit("addons/x.gd", "# construct a row from the spans"), "") and ok
	ok = _check("the ordinary noun is not a hit",
		_first_hit("addons/x.gd", "# one of the constructs the lifter knows"), "") and ok
	ok = _check("a constructor is not a hit",
		_first_hit("addons/x.gd", "# the constructor runs before _ready"), "") and ok
	ok = _check("reconstructing is not a hit",
		_first_hit("addons/x.gd", "# reconstruct the branch, then reconstruction ends"), "") and ok
	ok = _check("the ordinary word capitalised at the start of a sentence is not a hit",
		_first_hit("addons/x.gd", "# %sion was measured headlessly. %sor runs first."
			% [_product_name(), _product_name()]), "") and ok
	ok = _check("the short name inside a longer token is not a hit",
		_first_hit("addons/x.gd", "color = Color(\"#8f%sff\")  # matrix cell m.%sx"
			% [_short_name(), _short_name()]), "") and ok

	# The live sweep. Non-vacuity is asserted before the verdict, for the same reason.
	var hits: PackedStringArray = PackedStringArray()
	var scanned: int = 0
	for root: String in SWEPT_ROOTS:
		scanned += _scan_directory(root, hits)
	ok = _check("the sweep actually reads this project's text files", scanned > 100, true) and ok
	for hit: String in hits:
		print("  other product named: %s" % hit)
	ok = _check("no shipped or generated file names another product (%d scanned)" % scanned,
		hits.size(), 0) and ok
	return ok


## The forbidden long name, spelled in parts so this file is not its own first violation.
static func _product_name() -> String:
	return "Cons" + "truct"


## The forbidden short name, spelled the same way.
static func _short_name() -> String:
	return "C" + "3"


## The first product-name hit in `text`, as a reportable "path:line - reason", or "" when clean.
## Static and pure, so the rule above is provable without touching the filesystem.
static func _first_hit(path: String, text: String) -> String:
	# The long name is case-SENSITIVE and may not continue into more lower-case letters, so the
	# ordinary English words survive even at the start of a sentence; the short name is claimed only
	# as a whole token, so neither a hex colour nor a struct field can trip it.
	var patterns: Array[String] = [
		"%s(?![a-z])" % _product_name(),
		"(?<![0-9A-Za-z_])%s(?![0-9A-Za-z_])" % _short_name(),
	]
	var lines: PackedStringArray = text.split("\n")
	for pattern: String in patterns:
		var regex: RegEx = RegEx.create_from_string(pattern)
		if regex == null:
			continue
		for index: int in lines.size():
			var found: RegExMatch = regex.search(lines[index])
			if found == null:
				continue
			return "%s:%d - names '%s'" % [path, index + 1, found.get_string(0)]
	return ""


static func _scan_directory(dir_path: String, hits: PackedStringArray) -> int:
	if SKIPPED_SUBTREES.has(dir_path):
		return 0
	var scanned: int = 0
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return 0
	# Hidden entries are listed deliberately, then filtered BY NAME: a dot-directory is only
	# OS-hidden on some platforms, so leaving it to the default would sweep one machine's caches
	# and quietly skip another's.
	dir.include_hidden = true
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		var full_path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			if not LOCAL_STATE_DIRS.has(entry):
				scanned += _scan_directory(full_path, hits)
		elif full_path == _self_path():
			pass
		elif TEXT_EXTENSIONS.has(entry.get_extension().to_lower()):
			scanned += 1
			var hit: String = _first_hit(full_path, FileAccess.get_file_as_string(full_path))
			if not hit.is_empty():
				hits.append(hit)
		entry = dir.get_next()
	dir.list_dir_end()
	return scanned


## This file states the rule, so it necessarily contains examples of what the rule forbids.
static func _self_path() -> String:
	return "res://tests/no_product_names_in_code_test.gd"


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] no_product_names_in_code_test: %s" % label)
		return true
	print("[FAIL] no_product_names_in_code_test: %s - expected %s, got %s"
		% [label, str(expected), str(actual)])
	return false
