# EventSheets - the shipped documentation links resolve (Phase L)
#
# The release zip ships addons/ + README.md and NOT docs/, so every link that pointed at a
# res://docs/ path (the Welcome window's migration button) or at a relative docs/ path (29 of
# them in README.md) was dead the moment somebody installed the plugin. Both now resolve to the
# repo, pinned to the released tag.
#
# What this file pins, all headlessly:
#   - the URL shape, built from the SAME version constant the release ritual bumps (never a
#     literal version string - a bump would silently rot the pin);
#   - the pack -> guide derivation, proved against real packs AND swept across every pack
#     directory, so a renamed guide fails here instead of shipping a 404;
#   - `@ace_help` beating the derivation (a third party hosting docs elsewhere wins);
#   - every doc path hardwired into shipped code resolves to a file that is really there (the
#     gate the "code never references documentation files" exception is conditional on);
#   - the @ace_help override's READ path, against a fixture, because no pack in this repo
#     declares the annotation and an untested reader could match nothing and look fine;
#   - the release-staging rewrite, on prose links, anchors, image links, and text that only
#     LOOKS like a link - plus the real README, which must come out with no relative docs/ link
#     left, and that BOTH zips' README copies go through it;
#   - the anti-rot sweep: no code line under addons/ names a res://docs/ path again.
#
# Needs the windowed harness (not reachable here): that the Welcome window's button actually
# opens a browser tab - OS.shell_open cannot be observed headlessly, so the test stops at the
# URL the button was handed.
@tool
class_name DocsLinksTest
extends RefCounted

const STAGING_SCRIPT_PATH: String = "res://tools/stage_readme_links.gd"
const ADDON_ROOT: String = "res://eventsheet_addons"
const ADDON_GUIDE_DIR: String = "res://docs/Addons"
const ADDON_GUIDE_INDEX: String = "res://docs/Addons/README.md"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_doc_urls() and all_passed
	all_passed = _test_guide_mapping() and all_passed
	all_passed = _test_guide_sweep() and all_passed
	all_passed = _test_addon_index_lists_every_guide() and all_passed
	all_passed = _test_addon_guide_shape() and all_passed
	all_passed = _test_provider_resolution() and all_passed
	all_passed = _test_hardwired_doc_paths() and all_passed
	all_passed = _test_help_annotation() and all_passed
	all_passed = _test_readme_rewrite() and all_passed
	all_passed = _test_no_local_doc_paths() and all_passed
	return all_passed


## THE GATE the house-rule exception is conditional on: navigation code may name a doc file, but
## only if a test proves the file is there. Swept at the STRING level rather than at the call
## site, so a path parked in a const (doc_window's INDEX_DOC_PATH) is covered too - a rename of
## either guide would otherwise ship a tag-pinned 404 with the whole suite green, which is the
## exact failure this phase exists to fix.
static func _test_hardwired_doc_paths() -> bool:
	var all_passed: bool = true
	var matcher: RegEx = RegEx.create_from_string("\"(docs/[A-Za-z0-9_./-]+\\.md)\"")
	var scripts: PackedStringArray = PackedStringArray()
	_collect_scripts("res://addons", scripts)
	var seen: PackedStringArray = PackedStringArray()
	var missing: PackedStringArray = PackedStringArray()
	for path: String in scripts:
		for line: String in _read(path).split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			for found: RegExMatch in matcher.search_all(line):
				var target: String = found.get_string(1)
				if not seen.has(target):
					seen.append(target)
				if not FileAccess.file_exists("res://" + target):
					missing.append("%s -> %s" % [path.get_file(), target])
	all_passed = _check("every doc path hardwired into shipped code exists", ", ".join(missing), "") and all_passed
	# Pinned by NAME, not by count: the sweep must not be able to pass by matching nothing, and
	# these two are the literals that actually ship today.
	all_passed = _check("the migration guide the Welcome window opens is swept",
		seen.has("docs/GUIDE-MOVING-FROM-ANOTHER-EVENT-SHEET-EDITOR.md"), true) and all_passed
	all_passed = _check("the guide index the docs window opens is swept",
		seen.has("docs/README.md"), true) and all_passed
	# And the detector must be able to FAIL: the same regex on a call site naming a guide that is
	# not there both matches and reports missing.
	var probe: RegExMatch = matcher.search("EventSheets.open_online_doc(\"docs/GUIDE-NO-SUCH-THING.md\")")
	all_passed = _check("the detector matches a call-site literal", probe != null, true) and all_passed
	if probe != null:
		all_passed = _check("the detector would report a renamed guide",
			FileAccess.file_exists("res://" + probe.get_string(1)), false) and all_passed
	return all_passed


## The @ace_help override's READ path, which the pure caller-supplies-the-URL check never
## touches. No pack in this repo declares the annotation today, so without a fixture this
## function could match nothing at all and every third-party override would silently degrade to
## the derived docs/Addons path - with the suite green.
static func _test_help_annotation() -> bool:
	var all_passed: bool = true
	var fixture: String = "user://docs_links_test_pack"
	DirAccess.make_dir_recursive_absolute(fixture)
	_write(fixture.path_join("my_pack_addon.gd"), "@tool\n## @ace_help(\"https://example.com/my-pack/guide\")\nclass_name MyPackAddon\n")
	all_passed = _check("an @ace_help annotation is read off disk",
		EventSheets._help_annotation_in_dir(fixture), "https://example.com/my-pack/guide") and all_passed
	# The negative case, so the reader above cannot be answering from a stale cache or a match
	# that happens to fire on anything.
	var bare: String = "user://docs_links_test_bare"
	DirAccess.make_dir_recursive_absolute(bare)
	_write(bare.path_join("plain_addon.gd"), "@tool\nclass_name PlainAddon\n")
	all_passed = _check("a pack with no annotation reads as no override",
		EventSheets._help_annotation_in_dir(bare), "") and all_passed
	all_passed = _check("a directory that is not there reads as no override",
		EventSheets._help_annotation_in_dir("user://docs_links_test_absent"), "") and all_passed
	return all_passed


static func _test_doc_urls() -> bool:
	var all_passed: bool = true
	# Derived, never literal: the expectation is built from the same constant the code reads, so
	# this test keeps passing across a version bump and still fails if the SHAPE changes.
	var pinned: String = "%s/blob/v%s/docs/GUIDE-MOVING-FROM-ANOTHER-EVENT-SHEET-EDITOR.md" % [EventSheets.DOCS_REPO_URL, SheetCompiler.VERSION]
	all_passed = _check("a guide path becomes a tag-pinned blob URL",
		EventSheets.doc_url("docs/GUIDE-MOVING-FROM-ANOTHER-EVENT-SHEET-EDITOR.md"), pinned) and all_passed
	all_passed = _check("the pinned version is the compiler's VERSION",
		EventSheets.docs_version(), SheetCompiler.VERSION) and all_passed
	all_passed = _check("an anchor rides on the end",
		EventSheets.doc_url("docs/GUIDE-RECIPES.md", "health-and-damage"),
		"%s/blob/v%s/docs/GUIDE-RECIPES.md#health-and-damage" % [EventSheets.DOCS_REPO_URL, SheetCompiler.VERSION]) and all_passed
	all_passed = _check("a leading # on the anchor is not doubled",
		EventSheets.doc_url("docs/GUIDE-RECIPES.md", "#health-and-damage"),
		"%s/blob/v%s/docs/GUIDE-RECIPES.md#health-and-damage" % [EventSheets.DOCS_REPO_URL, SheetCompiler.VERSION]) and all_passed
	all_passed = _check("a res:// path is normalised to repo-relative",
		EventSheets.doc_url("res://docs/GUIDE-UNINSTALL.md"),
		"%s/blob/v%s/docs/GUIDE-UNINSTALL.md" % [EventSheets.DOCS_REPO_URL, SheetCompiler.VERSION]) and all_passed
	all_passed = _check("an absolute URL passes through unchanged",
		EventSheets.doc_url("https://example.com/my-pack/guide"), "https://example.com/my-pack/guide") and all_passed
	all_passed = _check("an empty path yields no URL", EventSheets.doc_url(""), "") and all_passed
	all_passed = _check("opening an empty path is refused, not attempted",
		EventSheets.open_online_doc(""), false) and all_passed
	return all_passed


static func _test_guide_mapping() -> bool:
	var all_passed: bool = true
	all_passed = _check("quest derives its guide", EventSheets.addon_guide_target("quest"), "docs/Addons/Quest.md") and all_passed
	all_passed = _check("encounter_timeline derives a two-word guide",
		EventSheets.addon_guide_target("encounter_timeline"), "docs/Addons/Encounter-Timeline.md") and all_passed
	all_passed = _check("priced_table resolves through the override (the guide is plural)",
		EventSheets.addon_guide_target("priced_table"), "docs/Addons/Priced-Tables.md") and all_passed
	all_passed = _check("an acronym stays uppercase", EventSheets.addon_guide_name("fps_controller"), "FPS-Controller") and all_passed
	all_passed = _check("a companion resource pack points at its partner's guide",
		EventSheets.addon_guide_name("quest_resource"), "Quest") and all_passed
	all_passed = _check("@ace_help beats the derivation",
		EventSheets.addon_guide_target("quest", "https://example.com/forks/quest.html"), "https://example.com/forks/quest.html") and all_passed
	all_passed = _check("an unknown pack has no guide", EventSheets.addon_guide_target(""), "") and all_passed
	return all_passed


## Every pack directory must resolve to a guide that actually exists. This is the drift gate: a
## renamed guide, or a new pack whose name the derivation cannot reach, fails here.
static func _test_guide_sweep() -> bool:
	var all_passed: bool = true
	var missing: PackedStringArray = PackedStringArray()
	var directory: DirAccess = DirAccess.open(ADDON_ROOT)
	if directory == null:
		return _check("the pack directory is readable", false, true)
	for pack_dir: String in directory.get_directories():
		var target: String = EventSheets.addon_guide_target(pack_dir)
		if not FileAccess.file_exists("res://" + target):
			missing.append("%s -> %s" % [pack_dir, target])
	all_passed = _check("every pack resolves to a guide that ships", ", ".join(missing), "") and all_passed
	# The detector must be able to fail: a directory nobody documented resolves to a path that is
	# not there, which is exactly what the sweep above reports.
	all_passed = _check("the sweep would catch an undocumented pack",
		FileAccess.file_exists("res://" + EventSheets.addon_guide_target("no_such_pack_here")), false) and all_passed
	return all_passed


## Every addon guide is reachable from the addon index, with a sentence saying what it is.
##
## The root docs index has had this gate since the day a parallel batch of doc work broke the
## habit; the addon index did not, and two guides written in the same window (Anchor and Touch
## Gestures) shipped linked from nowhere. A guide nobody indexed is a guide nobody finds.
static func _test_addon_index_lists_every_guide() -> bool:
	var all_passed: bool = true
	var index: String = _read(ADDON_GUIDE_INDEX)
	all_passed = _check("the addon index reads", index.is_empty(), false) and all_passed
	var missing: PackedStringArray = PackedStringArray()
	var undescribed: PackedStringArray = PackedStringArray()
	var swept: int = 0
	for guide: String in _addon_guide_files():
		swept += 1
		var link: String = "(%s)" % guide
		if not index.contains(link):
			missing.append(guide)
			continue
		for line: String in index.split("\n"):
			if not line.contains(link):
				continue
			if line.substr(line.find(link) + link.length()).strip_edges().length() < 20:
				undescribed.append(guide)
			break
	# Without this the whole check passes vacuously the day the folder cannot be read.
	all_passed = _check("the addon guide folder was actually swept", swept > 60, true) and all_passed
	all_passed = _check("every docs/Addons guide is listed in the addon index",
		", ".join(missing), "") and all_passed
	all_passed = _check("every listed addon guide carries a one-line description",
		", ".join(undescribed), "") and all_passed
	all_passed = _check("the lookup can say no", index.contains("(No-Such-Pack.md)"), false) and all_passed
	return all_passed


## THE 15+5 STANDARD, gated at last on the folder it was written for. Fifteen or more numbered use
## cases, and exactly five bolded lines under "Other use cases".
##
## Counted across all three spellings the corpus really uses, because the house style grew over
## seventy-odd guides and a gate that knew only one of them would score most of them zero:
##   `### 3. A title`        a heading per case (the commonest)
##   `**3. A title.**`       a bold-led paragraph (what the Modules guides use)
##   `3. **A title.**`       a markdown ordered list
## and in the tail, both `**...**` and `- **...**`.
static func _test_addon_guide_shape() -> bool:
	var all_passed: bool = true
	var thin: PackedStringArray = PackedStringArray()
	var wrong_tail: PackedStringArray = PackedStringArray()
	var swept: int = 0
	for guide: String in _addon_guide_files():
		swept += 1
		var numbered: int = 0
		var other: int = 0
		var in_other: bool = false
		for line: String in _read(ADDON_GUIDE_DIR.path_join(guide)).split("\n"):
			var stripped: String = line.strip_edges()
			if stripped.begins_with("#") and stripped.ends_with("Other use cases"):
				in_other = true
				continue
			if in_other and stripped.begins_with("## "):
				in_other = false
			if in_other:
				if stripped.begins_with("**") or stripped.begins_with("- **"):
					other += 1
				continue
			if _numbered_use_case(stripped):
				numbered += 1
		if numbered < 15:
			thin.append("%s has %d" % [guide, numbered])
		if other != 5:
			wrong_tail.append("%s has %d" % [guide, other])
	all_passed = _check("the addon guide folder was swept for shape", swept > 60, true) and all_passed
	all_passed = _check("every addon guide carries 15 or more numbered use cases",
		", ".join(thin), "") and all_passed
	all_passed = _check("every addon guide closes with exactly five other use cases",
		", ".join(wrong_tail), "") and all_passed
	# The counters must be able to say no, or a corpus that stopped matching them reads as green.
	all_passed = _check("a heading case counts", _numbered_use_case("### 3. Something"), true) and all_passed
	all_passed = _check("a bold-led case counts", _numbered_use_case("**3. Something.**"), true) and all_passed
	all_passed = _check("an ordered-list case counts", _numbered_use_case("3. **Something.**"), true) and all_passed
	all_passed = _check("a plain sentence is not a use case", _numbered_use_case("Some prose."), false) and all_passed
	all_passed = _check("a numbered line with no title is not one either",
		_numbered_use_case("3."), false) and all_passed
	return all_passed


## Whether a line OPENS a numbered use case, in any of the three spellings the corpus uses.
static func _numbered_use_case(line: String) -> bool:
	var head: String = line.strip_edges()
	for prefix: String in ["### ", "#### ", "**"]:
		if head.begins_with(prefix):
			head = head.substr(prefix.length())
			break
	var digits: String = ""
	for index: int in head.length():
		if not head[index].is_valid_int():
			break
		digits += head[index]
	if digits.is_empty():
		return false
	return head.substr(digits.length()).begins_with(". ")


## Every addon guide file, README aside, sorted so a failure names them in a stable order.
static func _addon_guide_files() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for file_name: String in DirAccess.get_files_at(ADDON_GUIDE_DIR):
		if file_name.ends_with(".md") and file_name != "README.md":
			found.append(file_name)
	found.sort()
	return found


static func _test_provider_resolution() -> bool:
	var all_passed: bool = true
	all_passed = _check("a provider id resolves to its pack directory",
		EventSheets.addon_pack_directory("PricedTableBehavior"), "priced_table") and all_passed
	all_passed = _check("a provider id resolves to its guide",
		EventSheets.addon_guide_for_provider("QuestPackAddon"), "docs/Addons/Quest.md") and all_passed
	all_passed = _check("a builtin provider has no pack guide",
		EventSheets.addon_guide_for_provider("Core"), "") and all_passed
	all_passed = _check("opening a guide for a provider with none is refused",
		EventSheets.open_addon_guide("Core"), false) and all_passed
	return all_passed


static func _test_readme_rewrite() -> bool:
	var all_passed: bool = true
	var staging: GDScript = load(STAGING_SCRIPT_PATH)
	if staging == null:
		return _check("the staging script loads", false, true)
	var base: String = "%s/blob/v9.9.9/" % EventSheets.DOCS_REPO_URL
	var raw_base: String = "%s/v9.9.9/" % EventSheets.DOCS_REPO_URL.replace("https://github.com/", "https://raw.githubusercontent.com/")
	all_passed = _check("a prose link becomes a blob URL",
		staging.rewrite_links("see [uninstall](docs/GUIDE-UNINSTALL.md).", "9.9.9"),
		"see [uninstall](%sdocs/GUIDE-UNINSTALL.md)." % base) and all_passed
	all_passed = _check("an anchor survives the rewrite",
		staging.rewrite_links("[lists](docs/GUIDE-WORKING-WITH-LISTS.md#appending)", "9.9.9"),
		"[lists](%sdocs/GUIDE-WORKING-WITH-LISTS.md#appending)" % base) and all_passed
	all_passed = _check("an image link becomes a raw URL, so it still displays",
		staging.rewrite_links("![the canvas](docs/previews/editor-hero.png)", "9.9.9"),
		"![the canvas](%sdocs/previews/editor-hero.png)" % raw_base) and all_passed
	all_passed = _check("a label holding parentheses survives",
		staging.rewrite_links("![it calls jump() here](docs/previews/a.png)", "9.9.9"),
		"![it calls jump() here](%sdocs/previews/a.png)" % raw_base) and all_passed
	all_passed = _check("docs/ in prose or backticks is left alone",
		staging.rewrite_links("The `docs/` folder holds docs/GUIDE-THEMING.md.", "9.9.9"),
		"The `docs/` folder holds docs/GUIDE-THEMING.md.") and all_passed
	all_passed = _check("a link outside docs/ is left alone",
		staging.rewrite_links("[license](LICENSE)", "9.9.9"), "[license](LICENSE)") and all_passed
	# The real thing: the shipped README must come out of staging with no relative link left.
	var readme: String = _read("res://README.md")
	all_passed = _check("the README is readable", readme.is_empty(), false) and all_passed
	var staged: String = staging.rewrite_links(readme, "9.9.9")
	all_passed = _check("no relative docs/ link survives staging", staged.contains("](docs/"), false) and all_passed
	all_passed = _check("staging rewrote every link it counted",
		staged.count("/v9.9.9/docs/"), staging.count_links(readme)) and all_passed
	all_passed = _check("the README carries links to rewrite at all", staging.count_links(readme) > 0, true) and all_passed

	# BOTH zips carry their own README copy and docs/ ships in neither, so the rewrite has to run
	# on both staged copies. Rewriting only the plugin's left the samples zip - the one carrying
	# the packs the addon guides are written for - with 29 dead links.
	var workflow: String = _read("res://.github/workflows/release.yml")
	all_passed = _check("the release workflow is readable", workflow.is_empty(), false) and all_passed
	all_passed = _check("the plugin zip's README is staged through the rewriter",
		workflow.contains("stage/plugin/README.md"), true) and all_passed
	all_passed = _check("the samples zip's README is staged through the rewriter",
		workflow.contains("stage/samples/README.md"), true) and all_passed
	return all_passed


## Anti-rot: a res://docs/ path in shipped code is a link that opens nothing once installed.
## Comment lines are fine - they explain the rule rather than reintroduce it.
static func _test_no_local_doc_paths() -> bool:
	var offenders: PackedStringArray = PackedStringArray()
	var scripts: PackedStringArray = PackedStringArray()
	_collect_scripts("res://addons", scripts)
	for path: String in scripts:
		for line: String in _read(path).split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			if line.contains("res://docs/"):
				offenders.append(path.get_file())
				break
	return _check("no shipped code names a res://docs/ path", ", ".join(offenders), "")


static func _collect_scripts(dir_path: String, into: PackedStringArray) -> void:
	var directory: DirAccess = DirAccess.open(dir_path)
	if directory == null:
		return
	for sub_dir: String in directory.get_directories():
		_collect_scripts(dir_path.path_join(sub_dir), into)
	for file_name: String in directory.get_files():
		if file_name.get_extension() == "gd":
			into.append(dir_path.path_join(file_name))


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)


static func _read(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] docs_links_test: %s" % label)
		return true
	print("[FAIL] docs_links_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
