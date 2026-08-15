# Release staging: rewrite README's relative docs/ links to absolute, tag-pinned URLs.
#
# The plugin zip ships README.md but NOT docs/, so every `](docs/...)` link in the shipped copy
# points at a file the reader does not have - 29 dead links in an installed project. This rewrites
# them in the STAGED copy only; the committed README keeps its relative links, which is what the
# repo page wants.
#
# Prose links become blob URLs (a readable page); image links become raw URLs (an actual image
# byte stream, so a Markdown viewer can display it). Anchors survive: the fragment rides along on
# the end of the rewritten target. Nothing outside a `](...)` link target is touched, so the
# `docs/` spelled in prose or in backticks stays as written.
#
# Usage (repo root, Godot 4):
#   godot --headless --path . --script tools/stage_readme_links.gd -- <version> <dest> [source]
#
#   <version>  the release version WITHOUT the leading v (the tag the links pin to)
#   <dest>     where to write the rewritten copy (an OS path - the staged README)
#   [source]   the README to read, default res://README.md
@tool
extends SceneTree

## The public API holds the one repo URL every doc link is built from; loaded by path so this
## tool never depends on the class cache being warm.
const API_SCRIPT_PATH: String = "res://addons/eventsheet/api/eventsheets.gd"

## Link targets under this prefix are the ones that do not ship.
const RELATIVE_PREFIX: String = "docs/"


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() < 2:
		print("stage_readme_links: usage -- <version> <dest> [source]")
		quit(1)
		return
	var version: String = arguments[0].strip_edges().trim_prefix("v")
	var destination: String = arguments[1]
	var source: String = "res://README.md" if arguments.size() < 3 else arguments[2]
	var original: String = _read(source)
	if original.is_empty():
		print("stage_readme_links: cannot read %s" % source)
		quit(1)
		return
	var staged: String = rewrite_links(original, version)
	var out: FileAccess = FileAccess.open(destination, FileAccess.WRITE)
	if out == null:
		print("stage_readme_links: cannot write %s" % destination)
		quit(1)
		return
	out.store_string(staged)
	out.close()
	print("stage_readme_links: version=%s rewritten=%d dest=%s" % [version, count_links(original), destination])
	quit(0)


## Rewrites every relative `docs/...` Markdown link target in `text` to an absolute URL pinned to
## `v<version>`. Pure: same text in, same text out, no disk and no engine state.
static func rewrite_links(text: String, version: String) -> String:
	var repo_url: String = repository_url()
	var blob_base: String = "%s/blob/v%s/" % [repo_url, version]
	var raw_base: String = "%s/v%s/" % [repo_url.replace("https://github.com/", "https://raw.githubusercontent.com/"), version]
	var matcher: RegEx = _link_matcher()
	var rewritten: String = ""
	var cursor: int = 0
	for found: RegExMatch in matcher.search_all(text):
		rewritten += text.substr(cursor, found.get_start() - cursor)
		var is_image: bool = found.get_string(1) == "!"
		var label: String = found.get_string(2)
		var target: String = found.get_string(3)
		rewritten += "%s[%s](%s%s)" % [found.get_string(1), label, raw_base if is_image else blob_base, target]
		cursor = found.get_end()
	rewritten += text.substr(cursor)
	return rewritten


## How many relative docs/ links the text carries - the number the staging step reports.
static func count_links(text: String) -> int:
	return _link_matcher().search_all(text).size()


## The repo every doc link is built from, read out of the public API's source TEXT so there is
## one spelling of it. Deliberately not `load()`ed: compiling the API pulls the whole editor
## subtree into a staging step that only needs one string, and a parse error anywhere in the
## editor would then break packaging.
static func repository_url() -> String:
	var declaration: RegEx = RegEx.create_from_string("(?m)^const\\s+DOCS_REPO_URL[^=]*=\\s*\"([^\"]+)\"")
	var found: RegExMatch = declaration.search(_read(API_SCRIPT_PATH))
	if found == null:
		return ""
	return found.get_string(1)


## `[label](docs/...)` and `![alt](docs/...)`. The label may hold parentheses (the README's alt
## text quotes code like `jump()`), so only brackets end it; the target may not hold either.
static func _link_matcher() -> RegEx:
	return RegEx.create_from_string("(!?)\\[([^\\]]*)\\]\\((%s[^)\\s]*)\\)" % RELATIVE_PREFIX)


static func _read(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()
