# EventSheet - the personal-path gate.
#
# This repository is public, so an absolute path out of a contributor's home directory is a
# privacy leak: it publishes an account name and a folder layout to everyone who reads the
# file, and it is useless to every reader but the one machine it came from. It happened once,
# in a command block that hardcoded one contributor's Godot install, and nothing caught it.
#
# Every text file in the project is swept for the home-directory shapes:
#   C:\Users\<who>   /c/users/<who>   /home/<who>/   /Users/<who>/
#
# A PLACEHOLDER is not a leak, and the rule that distinguishes them is mechanical rather than
# a list: a real path names an account, so the segment after the home root is captured only
# when it is a bare word. `C:/Users/<name>/...` never matches, because `<` is excluded from
# the capture - which is exactly how documentation should write such a path. Shared accounts
# that belong to nobody (`Public`, a CI `runner`) are named explicitly below.
@tool
class_name PersonalPathsTest
extends RefCounted

## Text formats worth sweeping. Binary and generated caches carry no prose.
const TEXT_EXTENSIONS: Array[String] = ["gd", "md", "cfg", "csv", "json", "yml", "yaml",
	"txt", "tres", "tscn", "godot", "gdshader", "po", "pot"]

## Not repository content: local editor state and engine caches, every one of them ignored by
## git. They are FULL of machine paths by design - that is what a cache is - and sweeping them
## would fail this gate on a clean checkout, which is how a gate gets switched off.
const LOCAL_STATE_DIRS: Array[String] = [".git", ".godot", ".import", ".vscode", ".idea",
	"__pycache__", "eventsheet_translations"]

## The file that defines the rule must contain examples of the thing it forbids.
const SELF_PATH: String = "res://tests/personal_paths_test.gd"

## Home-directory shapes. Each captures the account segment, and each deliberately excludes
## `<` and `>` from that capture so a documented placeholder cannot match.
const HOME_PATTERNS: Array[String] = [
	"(?i)\\b[a-z]:[\\\\/]+users[\\\\/]+([^\\\\/\\s\"'<>]+)",
	"(?i)(?:^|[\\s\"'(=])/[a-z]/users/([^\\\\/\\s\"'<>]+)",
	"(?i)(?:^|[\\s\"'(=])/home/([^\\\\/\\s\"'<>]+)/",
	"(?:^|[\\s\"'(=])/Users/([^\\\\/\\s\"'<>]+)/",
]

## Accounts that name nobody: Windows' shared profile, CI runners, and shell-expanded
## variables that resolve per machine (the portable way to write such a path).
const IMPERSONAL_ACCOUNTS: Array[String] = ["public", "default", "all users", "runner",
	"runneradmin", "you", "your", "user", "username", "name", "youruser", "yourname",
	"%username%", "$user", "$username", "${user}", "home", "me", "someone", "somebody"]


static func run() -> bool:
	var ok: bool = true

	# The detector, pinned by value. Proving it FIRST matters: a sweep that silently matched
	# nothing would report a clean repo just as convincingly as a clean repo does.
	ok = _check("a Windows home path is a leak",
		_first_violation("docs/x.md", "GODOT=\"C:\\Users\\jdoe\\Godot\\godot.exe\"") != "", true) and ok
	ok = _check("a git-bash home path is a leak",
		_first_violation("docs/x.md", "GODOT=\"/c/Users/jdoe/Desktop/godot.exe\"") != "", true) and ok
	ok = _check("a Linux home path is a leak",
		_first_violation("docs/x.md", "run /home/jdoe/godot --headless") != "", true) and ok
	ok = _check("a macOS home path is a leak",
		_first_violation("docs/x.md", "open /Users/jdoe/Godot.app") != "", true) and ok
	ok = _check("the violation names the account it found",
		_first_violation("docs/x.md", "see C:\\Users\\jdoe\\thing").contains("jdoe"), true) and ok

	# ...and the exemptions, or the gate becomes noise somebody switches off.
	ok = _check("an angle-bracket placeholder is not a leak",
		_first_violation("docs/x.md", "something like C:/Users/<name>/... would carry a name"), "") and ok
	ok = _check("a placeholder word is not a leak",
		_first_violation("docs/x.md", "C:\\Users\\<you>\\Godot and /home/username/godot"), "") and ok
	ok = _check("the shared Windows profile is not a leak",
		_first_violation("docs/x.md", "C:\\Users\\Public\\Documents"), "") and ok
	ok = _check("a CI runner home is not a leak",
		_first_violation(".github/w.yml", "working-directory: /home/runner/work/repo"), "") and ok
	ok = _check("an environment variable is not a leak",
		_first_violation("docs/x.md", "cd /c/Users/%USERNAME%/Godot"), "") and ok
	ok = _check("a project-relative path is not a leak",
		_first_violation("addons/x.gd", "res://addons/eventsheet/editor/x.gd"), "") and ok
	ok = _check("an unrelated colon is not a leak",
		_first_violation("tests/x.gd", "\"for x in a:\\n\\twhile d:\\n\\t\\tbar()\""), "") and ok

	# The live sweep. Non-vacuity is asserted before the verdict, for the same reason.
	var violations: PackedStringArray = PackedStringArray()
	var scanned: int = _sweep(violations)
	ok = _check("the sweep actually reads this project's text files", scanned > 100, true) and ok
	for violation: String in violations:
		print("  personal path: %s" % violation)
	ok = _check("no file publishes a contributor's home directory (%d scanned)" % scanned,
		violations.size(), 0) and ok
	return ok


## The first home-directory leak in `text`, as a reportable line, or "" when it is clean.
## Static and pure, so the rule above is provable without touching the filesystem.
static func _first_violation(path: String, text: String) -> String:
	var lines: PackedStringArray = text.split("\n")
	for pattern: String in HOME_PATTERNS:
		var regex: RegEx = RegEx.create_from_string(pattern)
		if regex == null:
			continue
		for index: int in lines.size():
			var found: RegExMatch = regex.search(lines[index])
			if found == null:
				continue
			var account: String = found.get_string(1).strip_edges()
			if IMPERSONAL_ACCOUNTS.has(account.to_lower()):
				continue
			return "%s:%d - absolute home path naming '%s'" % [path, index + 1, account]
	return ""


static func _sweep(violations: PackedStringArray) -> int:
	return _scan_directory("res://", violations)


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
			if not LOCAL_STATE_DIRS.has(entry):
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
	print("[FAIL] personal_paths_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
