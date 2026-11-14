# Godot EventSheets - the documents say what the code does, held by the suite instead of by a reader.
#
# A survey of the guides found them far less stale than feared, and the faults it did find were all
# the same shape: a sentence that was true on the day it was written, and a thing in the code that
# moved afterwards with nothing connecting the two. This test is that connection, for the five
# questions that have an exact answer without opening an editor:
#
#   1. Does each behaviour guide name every row and exported variable its pack publishes?
#   2. Does every menu path a guide writes in bold or italics end at an item the editor builds?
#   3. Is a UI name the plugin removed described as present anywhere a reader looks?
#   4. Does every repo path a doc puts in backticks exist?
#   5. Is every number a doc states about the repo measured here, instead of typed twice?
#
# (The sixth question, whether a picture in docs/previews/ is shown by anything, lives with the
# other picture checks in docs_integrity_test.)
#
# Each check keeps an ALLOW LIST only where a miss is deliberate, and every entry says why. An entry
# that stops being needed fails too, so a list can only shrink: a stale entry is a hole in the net.
@tool
class_name DocsTruthTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PREFIX := "docs_truth_test"

## Where the shipped behaviour packs live, and the guide folder their guides live in.
const ADDONS_DIR := "res://eventsheet_addons"

## Rows and variables a guide leaves out ON PURPOSE, as { "guide file": { "name": "why" } }. Empty:
## every row and every exported variable of every pack is named in its guide today.
const COVERAGE_ALLOWED: Dictionary = {}

## The menu roots a guide path can begin with. "Menu" is the strip's one button, the other five are
## the submenus hanging under it.
const MENU_ROOTS: PackedStringArray = ["Sheet", "Add", "Edit", "View", "Tools", "Menu"]

## Menu path segments the editor's source does not spell as one string literal, as { "segment": why }.
const MENU_ALLOWED: Dictionary = {}

## UI names the plugin removed. A current doc may not describe one as present. Each entry is
## [phrase, why it is gone]; the phrase is matched case-sensitively. Add the words of the next
## removal here in the same commit that removes it.
const RETIRED_NAMES: Array = [
	["Preview layout", "the strip's Preview layout button went; a plain scene run is Godot's own F6"],
	["Preview project", "the strip's Preview project button went; a plain project run is Godot's own F5"],
	["Register Autoload", "the plugin adds no autoload any more"],
	["New Class", "the New Class menu item was removed"],
	["New global", "the New global menu item was removed"],
	["Keyboard Shortcuts", "the shortcuts window is gone; bindings live in Godot's Editor Settings > Shortcuts"],
	["Object properties", "the Object properties window was deleted; a click on an object name only selects"],
	["Properties bar", "the Properties bar was removed from the dock"],
	["Project bar", "the Project bar was removed from the dock"],
	["History panel", "the History panel was removed"],
	["Properties and actions", "the Properties and actions panel was removed"],
	["Open Sheets list", "the Open Sheets list was removed from the dock"],
]

## Where a retired name may still appear, as { "doc file name": { "phrase": why } }.
const RETIRED_ALLOWED: Dictionary = {
	"GUIDE-THE-TOOLBAR.md": {
		"Preview layout": "its where-did-it-go table names the buttons that left, so a reader who remembers one finds where it went",
		"Preview project": "its where-did-it-go table names the buttons that left, so a reader who remembers one finds where it went",
	},
}

## Repo paths a doc writes in backticks that are not files of this repo, as { "path": why }.
const PATH_ALLOWED: Dictionary = {
	".github/workflows/eventsheets-docs.yml": "written into a USER's project by a button, never part of this repo",
	"addons/eventforge/registration/modules/weather_aces.gd": "the example file a tool writes in a tutorial",
	"demo/tests/": "an example of a folder name a user's project may hold",
	"demo/themes/density/": "a folder the editor searches and a user may create; empty on a fresh checkout",
	"docs/changelog/vX.Y.Z.md": "a template for the next release's file",
	"docs/internal/RELEASE-NOTES-vX.md": "a template for the next release's file",
	"eventsheet_addons/looks/": "the folder a USER's project gets when they make their own look",
	"eventsheet_addons/looks/heart_row.gd": "a user's look, written by the New inspector look dialog",
	"eventsheet_addons/looks/star_rating.gd": "a user's look, written by the New inspector look dialog",
	"tools/call": "an MCP request method name, not a path",
}

## The top folders a backticked path is checked under.
const PATH_ROOTS: PackedStringArray = ["addons", "tools", "tests", "docs", "eventsheet_addons", "demo", ".github"]


static func run() -> bool:
	var passed: bool = true
	var docs: Dictionary = _current_docs()
	passed = SUPPORT.check(PREFIX, "the current docs were actually read", docs.size() > 200, true) and passed
	passed = _test_guides_name_their_packs() and passed
	passed = _test_menu_paths(docs) and passed
	passed = _test_retired_names(docs) and passed
	passed = _test_paths_exist(docs) and passed
	passed = _test_measured_numbers(docs) and passed
	return passed


# -- 1. behaviour guides against their packs ---------------------------------------------------


## Every row (action, condition, expression, trigger) and every exported variable a pack publishes
## is named in its guide. A guide that leaves one out tells the reader who searched it that the
## thing does not exist. A display name, the variable's own name, or its name with spaces all count.
## Signals are NOT checked: a trigger is documented under its row name, not its signal name.
static func _test_guides_name_their_packs() -> bool:
	var by_guide: Dictionary = {}
	for pack: String in DirAccess.get_directories_at(ADDONS_DIR):
		if pack.begins_with(".") or pack.begins_with("_"):
			continue
		var guide: String = "res://" + EventSheets.addon_guide_target(pack)
		if not by_guide.has(guide):
			by_guide[guide] = {"rows": [], "exports": PackedStringArray()}
		var facts: Dictionary = by_guide[guide]
		_read_pack(ADDONS_DIR.path_join(pack), facts["rows"], facts["exports"])
	var absent: PackedStringArray = PackedStringArray()
	var swept_rows: int = 0
	var guides_without_file: PackedStringArray = PackedStringArray()
	var used_allowances: Dictionary = {}
	for guide: String in by_guide:
		if not FileAccess.file_exists(guide):
			guides_without_file.append(guide.get_file())
			continue
		var text: String = _plain(FileAccess.get_file_as_string(guide))
		var allowed: Dictionary = COVERAGE_ALLOWED.get(guide.get_file(), {})
		var facts: Dictionary = by_guide[guide]
		for row: Array in facts["rows"]:
			swept_rows += 1
			var name: String = str(row[0])
			if allowed.has(name):
				used_allowances["%s/%s" % [guide.get_file(), name]] = true
				continue
			if not text.contains(name.to_lower()):
				absent.append("%s: %s" % [guide.get_file().trim_suffix(".md"), name])
		for variable: String in facts["exports"]:
			if allowed.has(variable):
				used_allowances["%s/%s" % [guide.get_file(), variable]] = true
				continue
			if not text.contains(variable.to_lower()) and not text.contains(" ".join(variable.split("_", false))):
				absent.append("%s: %s" % [guide.get_file().trim_suffix(".md"), variable])
	absent.sort()
	var allowance_count: int = 0
	for guide_file: String in COVERAGE_ALLOWED:
		allowance_count += (COVERAGE_ALLOWED[guide_file] as Dictionary).size()
	var passed: bool = true
	passed = SUPPORT.check(PREFIX, "the pack sweep read real rows", swept_rows > 2000, true) and passed
	passed = SUPPORT.check(PREFIX, "every pack resolves to a guide that exists (%s)" % ", ".join(guides_without_file),
		guides_without_file.size(), 0) and passed
	passed = SUPPORT.check(PREFIX, "every pack row and exported variable is named in its guide (missing: %s)"
		% "; ".join(absent), absent.size(), 0) and passed
	passed = SUPPORT.check(PREFIX, "every coverage allowance is still needed",
		used_allowances.size(), allowance_count) and passed
	# The check can say no: a name the text does not hold is reported absent.
	passed = SUPPORT.check(PREFIX, "the guide lookup can say no",
		_plain("Reset Pity | puts a counter back").contains("roll with pity"), false) and passed
	return passed


## Lowercased, with the backticks that wrap a code name taken out, so `seed_on_start` matches.
static func _plain(text: String) -> String:
	return text.to_lower().replace("`", "")


## Appends one pack folder's published rows to `rows` as [display name], and its exported
## variables to `exports`. A row is an annotation block holding @ace_action / condition /
## expression / trigger and not @ace_hidden; a variable is an @export line not marked hidden.
static func _read_pack(directory: String, rows: Array, exports: PackedStringArray) -> void:
	for file_name: String in DirAccess.get_files_at(directory):
		if file_name.get_extension() == "gd":
			_scan_script(directory.path_join(file_name), rows, exports)
	for sub: String in DirAccess.get_directories_at(directory):
		_read_pack(directory.path_join(sub), rows, exports)


static func _scan_script(path: String, rows: Array, exports: PackedStringArray) -> void:
	var kind_re: RegEx = RegEx.create_from_string("@ace_(action|condition|expression|trigger)\\b")
	var name_re: RegEx = RegEx.create_from_string("@ace_name\\(\"([^\"]+)\"\\)")
	var member_re: RegEx = RegEx.create_from_string("(?:func|signal)\\s+(\\w+)")
	var export_re: RegEx = RegEx.create_from_string("^@export\\w*(?:\\(.*\\))?\\s+var\\s+(\\w+)")
	var block: PackedStringArray = PackedStringArray()
	for raw: String in FileAccess.get_file_as_string(path).split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("##"):
			block.append(line)
			continue
		if line.is_empty():
			# A blank line ends a plain comment, but not an annotation block: the annotations of a
			# row may be separated from its declaration by a gap.
			if not " ".join(block).contains("@ace_"):
				block.clear()
			continue
		var annotations: String = " ".join(block)
		var hidden: bool = annotations.contains("@ace_hidden")
		if not hidden and kind_re.search(annotations) != null:
			var named: RegExMatch = name_re.search(annotations)
			if named != null:
				rows.append([named.get_string(1)])
			else:
				var member: RegExMatch = member_re.search(line)
				if member != null:
					rows.append([member.get_string(1).capitalize()])
		var exported: RegExMatch = export_re.search(line)
		if exported != null and not hidden and exported.get_string(1) != "acts_on":
			exports.append(exported.get_string(1))
		block.clear()


# -- 2. menu paths ---------------------------------------------------------------------------


## Every menu path a guide writes in bold or italics ("**Sheet > Export GDScript...**") ends at an
## item the editor builds. Checked by the words: each segment after the root must appear as a
## string literal somewhere in the editor's source or its translation template.
static func _test_menu_paths(docs: Dictionary) -> bool:
	var words: String = _editor_words()
	var roots: String = "|".join(MENU_ROOTS)
	var bold: RegEx = RegEx.create_from_string("\\*\\*((?:%s)(?: > [^*>`\\n]+?)+)\\*\\*" % roots)
	var italic: RegEx = RegEx.create_from_string("(?<!\\*)\\*((?:%s)(?: > [^*>`\\n]+?)+)\\*(?!\\*)" % roots)
	var absent: PackedStringArray = PackedStringArray()
	var checked: int = 0
	var seen: Dictionary = {}
	var used_allowances: Dictionary = {}
	for path: String in docs:
		var text: String = docs[path]
		for expression: RegEx in [bold, italic]:
			for found: RegExMatch in expression.search_all(text):
				var segments: PackedStringArray = found.get_string(1).split(" > ")
				for index: int in range(1, segments.size()):
					var segment: String = _menu_segment(segments[index])
					if segment.is_empty():
						continue
					var key: String = "%s > %s" % [segments[0], segment]
					if seen.has(key):
						continue
					seen[key] = true
					checked += 1
					if MENU_ALLOWED.has(segment):
						used_allowances[segment] = true
						continue
					if not _is_menu_word(words, segment):
						absent.append("%s (%s)" % [found.get_string(1), path.get_file()])
	absent.sort()
	var passed: bool = true
	passed = SUPPORT.check(PREFIX, "the menu path check read real paths", checked > 40, true) and passed
	passed = SUPPORT.check(PREFIX, "every menu path a guide writes ends at an item the editor builds (missing: %s)"
		% "; ".join(absent), absent.size(), 0) and passed
	passed = SUPPORT.check(PREFIX, "every menu allowance is still needed", used_allowances.size(), MENU_ALLOWED.size()) and passed
	passed = SUPPORT.check(PREFIX, "the menu lookup can say no", _is_menu_word(words, "No Such Menu Item Anywhere"), false) and passed
	return passed


## A path segment as the menu spells it: no ellipsis, no trailing colon or full stop.
static func _menu_segment(segment: String) -> String:
	var cleaned: String = segment.strip_edges().replace("…", "").replace("...", "")
	return cleaned.strip_edges().trim_suffix(":").trim_suffix(".").strip_edges()


static func _is_menu_word(words: String, segment: String) -> bool:
	var needle: String = segment.to_lower()
	return words.contains("\"%s\"" % needle) or words.contains("\"%s…\"" % needle) \
		or words.contains("\"%s...\"" % needle)


## Every string the editor's source can show, lowercased into one text: the .gd files under
## addons/eventsheet (minus the shipped Manual copy) and the translation template's keys.
static func _editor_words() -> String:
	var parts: PackedStringArray = PackedStringArray()
	_collect_source("res://addons/eventsheet", parts)
	parts.append(FileAccess.get_file_as_string("res://addons/eventsheet/translations/TEMPLATE.csv"))
	return "\n".join(parts).to_lower()


static func _collect_source(directory: String, into: PackedStringArray) -> void:
	for file_name: String in DirAccess.get_files_at(directory):
		if file_name.get_extension() == "gd":
			into.append(FileAccess.get_file_as_string(directory.path_join(file_name)))
	for sub: String in DirAccess.get_directories_at(directory):
		if sub != "help":
			_collect_source(directory.path_join(sub), into)


# -- 3. retired names ------------------------------------------------------------------------


## A UI name the plugin removed is described as present nowhere a reader looks. History is not
## "a reader looks": docs/changelog/ and docs/internal/ describe the past and are not read here.
static func _test_retired_names(docs: Dictionary) -> bool:
	var found: PackedStringArray = PackedStringArray()
	var used_allowances: Dictionary = {}
	for path: String in docs:
		var allowed: Dictionary = RETIRED_ALLOWED.get(path.get_file(), {})
		for entry: Array in RETIRED_NAMES:
			var phrase: String = str(entry[0])
			if not _one_line(docs[path]).contains(phrase):
				continue
			if allowed.has(phrase):
				used_allowances["%s/%s" % [path.get_file(), phrase]] = true
				continue
			found.append("%s: \"%s\"" % [path.get_file(), phrase])
	found.sort()
	var allowance_count: int = 0
	for doc_file: String in RETIRED_ALLOWED:
		allowance_count += (RETIRED_ALLOWED[doc_file] as Dictionary).size()
	var passed: bool = true
	passed = SUPPORT.check(PREFIX, "no current doc describes a retired UI name as present (found: %s)"
		% "; ".join(found), found.size(), 0) and passed
	passed = SUPPORT.check(PREFIX, "every retired-name allowance is still needed", used_allowances.size(), allowance_count) and passed
	passed = SUPPORT.check(PREFIX, "the retired-name lookup can say no",
		"Run Current Scene (F6)".contains("Preview project"), false) and passed
	return passed


## The text with every line break read as a space, so a phrase a guide wraps across two lines
## ("Preview" then "project") is still found.
static func _one_line(text: String) -> String:
	return text.replace(char(13), "").replace(char(10), " ").replace("  ", " ")


# -- 4. paths ---------------------------------------------------------------------------------


## Every repo path a doc puts in backticks exists. Only paths under the repo's own top folders are
## checked; a path with a wildcard, a placeholder or a space is a pattern, not a path.
static func _test_paths_exist(docs: Dictionary) -> bool:
	var path_re: RegEx = RegEx.create_from_string("`((?:res://)?(?:%s)/[A-Za-z0-9_./\\-]+)`" % "|".join(PATH_ROOTS))
	var absent: PackedStringArray = PackedStringArray()
	var checked: int = 0
	var seen: Dictionary = {}
	var used_allowances: Dictionary = {}
	for doc_path: String in docs:
		for found: RegExMatch in path_re.search_all(docs[doc_path]):
			var path: String = found.get_string(1).trim_prefix("res://").rstrip(".")
			if seen.has(path):
				continue
			seen[path] = true
			checked += 1
			if PATH_ALLOWED.has(path):
				used_allowances[path] = true
				continue
			if not FileAccess.file_exists("res://" + path) and not DirAccess.dir_exists_absolute("res://" + path):
				absent.append("%s (%s)" % [path, doc_path.get_file()])
	absent.sort()
	var passed: bool = true
	passed = SUPPORT.check(PREFIX, "the path check read real paths", checked > 150, true) and passed
	passed = SUPPORT.check(PREFIX, "every repo path a doc writes in backticks exists (missing: %s)"
		% "; ".join(absent), absent.size(), 0) and passed
	passed = SUPPORT.check(PREFIX, "every path allowance is still needed", used_allowances.size(), PATH_ALLOWED.size()) and passed
	passed = SUPPORT.check(PREFIX, "the path lookup can say no",
		FileAccess.file_exists("res://addons/eventsheet/editor/doc/nothing.gd"), false) and passed
	return passed


# -- 5. numbers -------------------------------------------------------------------------------


## The numbers a doc states about the repo are measured here. A number that cannot be measured is
## not in the prose (the toolbar guide's menu-item counts and strip widths were taken out for that
## reason). The pack count is measured by pack_count_records_test and is not repeated.
static func _test_measured_numbers(docs: Dictionary) -> bool:
	var passed: bool = true
	# README: "over N test files" is a floor the tree has to clear, so adding a test never needs an edit.
	var readme: String = docs.get("res://README.md", "")
	var floor_re: RegEx = RegEx.create_from_string("over ([0-9][0-9,]*) test files")
	var quoted: RegExMatch = floor_re.search(readme)
	var test_files: int = 0
	for file_name: String in DirAccess.get_files_at("res://tests"):
		if file_name.ends_with("_test.gd"):
			test_files += 1
	var floor_value: int = int(quoted.get_string(1).replace(",", "")) if quoted != null else -1
	passed = SUPPORT.check(PREFIX, "the README states a test-file floor", quoted != null, true) and passed
	passed = SUPPORT.check(PREFIX, "the README's test-file floor (%d) is under the %d test files on disk" % [floor_value, test_files],
		test_files > floor_value and floor_value >= 1000, true) and passed
	# CLAUDE.md: the showcase drift gate prints showcases=N; N is the number of showcase folders.
	var claude: String = docs.get("res://CLAUDE.md", "")
	var showcase_re: RegEx = RegEx.create_from_string("showcases=([0-9]+) drifted=0")
	var showcase_quote: RegExMatch = showcase_re.search(claude)
	var showcase_folders: int = DirAccess.get_directories_at("res://demo/showcase").size()
	passed = SUPPORT.check(PREFIX, "CLAUDE.md quotes the showcase count the gate prints",
		int(showcase_quote.get_string(1)) if showcase_quote != null else -1, showcase_folders) and passed
	# The custom-inspectors guide documents one drawer per look script that ships.
	var guide: String = docs.get("res://docs/GUIDE-CUSTOM-INSPECTORS.md", "")
	var start: int = guide.find("## 4. The Drawers")
	var end: int = guide.find("## 4b.")
	var drawers: int = 0
	if start >= 0 and end > start:
		drawers = guide.substr(start, end - start).count("\n### ")
	var look_scripts: int = 0
	for file_name: String in DirAccess.get_files_at("res://addons/eventsheet/looks"):
		if file_name.ends_with(".gd"):
			look_scripts += 1
	passed = SUPPORT.check(PREFIX, "the custom-inspectors guide has a section per shipped look script (%d scripts)" % look_scripts,
		drawers, look_scripts) and passed
	return passed


# -- the docs a reader uses ---------------------------------------------------------------------


## The docs a reader opens today, as { res:// path: text }: docs/*.md, docs/Addons, docs/Modules,
## the generated vocabulary page and the four root documents. Not docs/changelog or docs/internal.
static func _current_docs() -> Dictionary:
	var docs: Dictionary = {}
	for folder: String in ["res://docs", "res://docs/Addons", "res://docs/Modules"]:
		for file_name: String in DirAccess.get_files_at(folder):
			if file_name.get_extension() == "md":
				docs[folder.path_join(file_name)] = FileAccess.get_file_as_string(folder.path_join(file_name))
	for root_doc: String in ["README.md", "AGENTS.md", "CLAUDE.md", "CONTRIBUTING.md", "EVENTSHEETS-VOCABULARY.md"]:
		var path: String = "res://" + root_doc
		if FileAccess.file_exists(path):
			docs[path] = FileAccess.get_file_as_string(path)
	return docs
