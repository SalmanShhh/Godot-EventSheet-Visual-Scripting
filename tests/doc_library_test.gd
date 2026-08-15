# EventSheets - the shipped guide bundle is honest (Phase 3)
#
# THE DRIFT GATE. The guides now exist twice: authored in docs/, shipped in
# addons/eventsheet/help/ so an installed plugin can read them. A second copy of the most-edited
# surface in this repo is a liability unless something fails loudly the moment the two disagree,
# and that something has to be here: CI runs the suite, and it does not run tools/.
#
# So this file, and not tools/build_help_bundle.gd, is what keeps the corpus true. Run
# `godot --headless --path . --script tools/build_help_bundle.gd` after touching any guide.
#
# What it pins, all headlessly:
#   - the bundle is BYTE-identical to its docs/ sources, carries no page whose source is gone, and
#     its manifest is exactly what a regeneration would write;
#   - every page id resolves to a file that reads;
#   - every in-page anchor in the corpus resolves to a heading slug in its own page;
#   - every cross-file link is either a shipped page or a real file on disk (the external_known
#     class, opened online) - and a link that is neither FAILS, which is the case that matters:
#     a typo, or a guide renamed without its links;
#   - every doc id hardwired into shipped code resolves;
#   - the manifest's derived grouping, and the directory-discovered doc sets;
#   - parsing the whole corpus stays inside a budget.
@tool
class_name DocLibraryTest
extends RefCounted

const BUILDER_PATH := "res://tools/build_help_bundle.gd"

## The whole corpus, parsed. Measured at roughly 1.5 s on the development machine for 129 pages;
## the ceiling is loose on purpose (a reader parses ONE page, in about 11 ms) and exists to catch
## a pathological regression, not to police a few hundred milliseconds. Per the standing rule, a
## budget that flaps needs three runs at HEAD before a diff is blamed.
const PARSE_BUDGET_MS := 12000


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_manifest() and all_passed
	all_passed = _test_drift() and all_passed
	all_passed = _test_pages_readable() and all_passed
	all_passed = _test_anchors() and all_passed
	all_passed = _test_cross_file_links() and all_passed
	all_passed = _test_ids() and all_passed
	all_passed = _test_hardwired_doc_ids() and all_passed
	all_passed = _test_routes() and all_passed
	all_passed = _test_parse_budget() and all_passed
	return all_passed


static func _test_manifest() -> bool:
	var all_passed: bool = true
	var text: String = _read(EventSheetDocLibrary.MANIFEST_PATH)
	all_passed = _check("the manifest ships", text.is_empty(), false) and all_passed
	all_passed = _check("it carries the frozen header",
		text.split("\n")[0].strip_edges(), EventSheetDocLibrary.MANIFEST_HEADER) and all_passed
	all_passed = _check("its payload version is 1", int(EventSheetDocLibrary.manifest().get("version", 0)), 1) and all_passed
	# Pinned by NAME rather than by count: a manifest that lost every page but one would still
	# have "some" pages, and the tree is built from these ids.
	all_passed = _check("a top-level guide is a page", EventSheetDocLibrary.has_page("GUIDE-RECIPES"), true) and all_passed
	all_passed = _check("an addon guide is a page", EventSheetDocLibrary.has_page("Addons/Quest"), true) and all_passed
	all_passed = _check("the docs index itself is a page", EventSheetDocLibrary.has_page("README"), true) and all_passed
	all_passed = _check("a guide that does not exist is not a page",
		EventSheetDocLibrary.has_page("GUIDE-NO-SUCH-THING"), false) and all_passed
	all_passed = _check("an internal spec never ships",
		EventSheetDocLibrary.has_page("internal/SPEC-in-editor-docs-viewer"), false) and all_passed
	all_passed = _check("a page carries its own H1 as its title",
		EventSheetDocLibrary.page_title("Addons/Quest").is_empty(), false) and all_passed
	all_passed = _check("a page that does not ship reads as no source",
		EventSheetDocLibrary.page_source("GUIDE-NO-SUCH-THING"), "") and all_passed
	return all_passed


## THE gate: bundle bytes equal source bytes, nothing is orphaned, and the manifest is what a
## regeneration would write. The comparison itself lives in the build tool so there is exactly one
## implementation of "drifted", and this test is what CI actually runs it from.
static func _test_drift() -> bool:
	var all_passed: bool = true
	var builder: GDScript = load(BUILDER_PATH)
	if builder == null:
		return _check("the build tool loads", false, true)
	var pages: Dictionary = builder.collect_pages()
	all_passed = _check("the corpus has pages to ship", pages.size() > 0, true) and all_passed
	var drifted: PackedStringArray = builder.drifted_pages(pages)
	all_passed = _check("the shipped bundle is byte-identical to docs/", ", ".join(drifted), "") and all_passed
	# By NAME, never by count: page_ids() also carries the pages DISCOVERED on disk (a pack that
	# ships guide.md, the project's own docs folder), so comparing sizes would report drift the
	# moment somebody used the feature this same slice shipped - on the one assertion whose entire
	# job is to be trusted.
	var absent: PackedStringArray = PackedStringArray()
	for id: Variant in pages:
		if not EventSheetDocLibrary.has_page(str(id)):
			absent.append(str(id))
	all_passed = _check("every source page is a page the reader can open", ", ".join(absent), "") and all_passed
	# The detector must be able to FAIL, or a bundle nobody generated would look clean: the same
	# comparison against a page whose source is not there reports drift.
	var missing: Dictionary = {"GUIDE-RECIPES": "res://docs/NOT-A-REAL-GUIDE.md"}
	all_passed = _check("the comparison would report a page whose source changed",
		builder.drifted_pages(missing).has("GUIDE-RECIPES"), true) and all_passed
	return all_passed


static func _test_pages_readable() -> bool:
	var unreadable: PackedStringArray = PackedStringArray()
	for id: String in EventSheetDocLibrary.page_ids():
		if EventSheetDocLibrary.page_source(id).strip_edges().is_empty():
			unreadable.append(id)
	return _check("every shipped page reads back", ", ".join(unreadable), "")


## Every "#slug" link in the corpus lands on a heading in its own page. Anchors are load-bearing:
## the public open_docs takes one, and a search result is a page plus an anchor.
static func _test_anchors() -> bool:
	var all_passed: bool = true
	var broken: PackedStringArray = PackedStringArray()
	var checked: int = 0
	for id: String in EventSheetDocLibrary.page_ids():
		var source: String = EventSheetDocLibrary.page_source(id)
		var slugs: Dictionary = _slugs_of(source)
		for target: String in _links_in(source):
			if not target.begins_with("#"):
				continue
			checked += 1
			if not slugs.has(target.substr(1)):
				broken.append("%s -> %s" % [id, target])
	all_passed = _check("every in-page anchor resolves", ", ".join(broken), "") and all_passed
	all_passed = _check("anchors were actually swept", checked > 100, true) and all_passed
	return all_passed


## Every cross-file link resolves, one of two ways: to a page that ships (the reader stays in the
## editor), or to a real repo file the bundle deliberately excludes (the reader gets the
## version-pinned page online). A link that is NEITHER is a typo or a rename, and fails.
static func _test_cross_file_links() -> bool:
	var all_passed: bool = true
	var broken: PackedStringArray = PackedStringArray()
	var lost_anchors: PackedStringArray = PackedStringArray()
	var slugs_by_page: Dictionary = {}
	var shipped: int = 0
	var external: int = 0
	var anchored: int = 0
	for id: String in EventSheetDocLibrary.page_ids():
		for target: String in _links_in(EventSheetDocLibrary.page_source(id)):
			var link: Dictionary = EventSheetDocMarkdown.classify_link(target)
			if str(link.get("kind", "")) != "doc":
				continue
			var landing: String = EventSheetDocLibrary.id_for_link(str(link.get("target", "")), id)
			if not landing.is_empty():
				shipped += 1
				# The ANCHOR half of a cross-file link, which the in-page sweep above cannot see.
				# Without this a heading renamed in one guide leaves every OTHER guide's link to it
				# landing silently at the top of a thousand-line page, with the suite green.
				var anchor: String = str(link.get("anchor", ""))
				if not anchor.is_empty():
					anchored += 1
					if not slugs_by_page.has(landing):
						slugs_by_page[landing] = _slugs_of(EventSheetDocLibrary.page_source(landing))
					if not (slugs_by_page[landing] as Dictionary).has(anchor):
						lost_anchors.append("%s -> %s#%s" % [id, landing, anchor])
				continue
			var repo_path: String = EventSheetDocLibrary.repo_path_for_link(str(link.get("target", "")), id)
			if not repo_path.is_empty() and FileAccess.file_exists("res://" + repo_path):
				external += 1
				continue
			broken.append("%s -> %s" % [id, target])
	all_passed = _check("every cross-file link is a shipped page or a real repo file", ", ".join(broken), "") and all_passed
	all_passed = _check("and every cross-file anchor lands on a heading of the page it names",
		", ".join(lost_anchors), "") and all_passed
	all_passed = _check("links were actually swept", shipped > 50, true) and all_passed
	all_passed = _check("cross-file anchors were actually swept", anchored > 0, true) and all_passed
	# The detector must be able to fail, or a sweep that matched nothing would read as a clean
	# corpus. A renamed guide resolves to neither class.
	all_passed = _check("a renamed guide resolves to no shipped page",
		EventSheetDocLibrary.id_for_link("GUIDE-GONE.md", "README"), "") and all_passed
	all_passed = _check("and to no file on disk",
		FileAccess.file_exists("res://" + EventSheetDocLibrary.repo_path_for_link("GUIDE-GONE.md", "README")), false) and all_passed
	print("[note] doc_library_test: %d links stay in the editor (%d of them anchored), %d open online" % [
		shipped, anchored, external])
	return all_passed


static func _test_ids() -> bool:
	var all_passed: bool = true
	all_passed = _check("a repo path maps to its page id",
		EventSheetDocLibrary.id_for_repo_path("docs/Addons/Quest.md"), "Addons/Quest") and all_passed
	all_passed = _check("a top-level guide path maps to its stem",
		EventSheetDocLibrary.id_for_repo_path("docs/GUIDE-RECIPES.md"), "GUIDE-RECIPES") and all_passed
	all_passed = _check("an internal spec maps to no page",
		EventSheetDocLibrary.id_for_repo_path("docs/internal/SPEC-layout-alignment.md"), "") and all_passed
	all_passed = _check("a path outside docs maps to no page",
		EventSheetDocLibrary.id_for_repo_path("README.md"), "") and all_passed
	all_passed = _check("a sibling link resolves inside the same doc set",
		EventSheetDocLibrary.id_for_link("Quest.md", "Addons/Checkpoint"), "Addons/Quest") and all_passed
	all_passed = _check("a link up out of the addon set reaches the index",
		EventSheetDocLibrary.id_for_link("../README.md", "Addons/Quest"), "README") and all_passed
	all_passed = _check("a link into the addon set resolves from a top-level guide",
		EventSheetDocLibrary.id_for_link("Addons/README.md", "GUIDE-RECIPES"), "Addons/README") and all_passed
	all_passed = _check("a link that climbs out of docs/ names a repo path instead",
		EventSheetDocLibrary.repo_path_for_link("../EVENTSHEETS-VOCABULARY.md", "GUIDE-RECIPES"),
		"EVENTSHEETS-VOCABULARY.md") and all_passed
	all_passed = _check("the file it names is really there",
		FileAccess.file_exists("res://EVENTSHEETS-VOCABULARY.md"), true) and all_passed

	# The inverse, and the case that made it necessary: a DISCOVERED page has a page id but was
	# never in docs/, so "read this online" must refuse rather than invent a repo path for it.
	all_passed = _check("a bundled page names the repo file it came from",
		EventSheetDocLibrary.repo_path_for_page("Addons/Quest"), "docs/Addons/Quest.md") and all_passed
	all_passed = _check("a pack's own discovered guide names no repo file",
		EventSheetDocLibrary.repo_path_for_page("Packs/grapple_hook"), "") and all_passed
	all_passed = _check("and neither does one of the project's own",
		EventSheetDocLibrary.repo_path_for_page("Project/TEAM-NOTES"), "") and all_passed
	all_passed = _check("so a discovered page's route carries no online link to invent",
		str(EventSheetDocExplain.resolve("guide:Packs/grapple_hook").get("target", "")), "") and all_passed

	# The tree, derived from the docs index's own grouping plus the discovered doc sets.
	var titles: PackedStringArray = PackedStringArray()
	for group: Dictionary in EventSheetDocLibrary.groups():
		titles.append(str(group.get("title", "")))
	all_passed = _check("the index page leads the tree", titles.has("Documentation index"), true) and all_passed
	all_passed = _check("the index's own first group is a section", titles.has("Learn by doing"), true) and all_passed
	all_passed = _check("the addon guides are their own section", titles.has("Addon packs"), true) and all_passed
	all_passed = _check("every addon guide is discovered by directory",
		EventSheetDocLibrary.ids_in_set("Addons").size(), _count_source_guides("res://docs/Addons")) and all_passed
	all_passed = _check("the module guides are discovered the same way",
		EventSheetDocLibrary.ids_in_set("Modules").size(), _count_source_guides("res://docs/Modules")) and all_passed
	return all_passed


## The gate the "code never references documentation files" exception is conditional on, in its
## id form: a doc id parked in shipped code must resolve, or a renamed guide ships a dead button
## with the suite green.
static func _test_hardwired_doc_ids() -> bool:
	var all_passed: bool = true
	var matcher: RegEx = RegEx.create_from_string("open_docs\\(\\s*\"([^\"]+)\"")
	var scripts: PackedStringArray = PackedStringArray()
	_collect_scripts("res://addons", scripts)
	var unresolved: PackedStringArray = PackedStringArray()
	for path: String in scripts:
		for line: String in _read(path).split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			for found: RegExMatch in matcher.search_all(line):
				var doc_id: String = found.get_string(1)
				# A format string ("addon:%s") names no single page - the id is built from a value
				# the caller holds, and the pack half of it is already swept by the guide sweep in
				# docs_links_test. Only a fully hardwired id can be checked here.
				if doc_id.contains("%"):
					continue
				if not bool(EventSheetDocExplain.resolve(doc_id).get("valid", false)):
					unresolved.append("%s -> %s" % [path.get_file(), doc_id])
	all_passed = _check("every doc id hardwired into shipped code resolves", ", ".join(unresolved), "") and all_passed
	# Prove the detector: the same regex on a call site naming a page that does not ship matches,
	# and that id resolves to nothing.
	var probe: RegExMatch = matcher.search("EventSheets.open_docs(\"guide:GUIDE-NO-SUCH-THING\")")
	all_passed = _check("the detector matches a call-site literal", probe != null, true) and all_passed
	if probe != null:
		all_passed = _check("and would report it as unresolved",
			bool(EventSheetDocExplain.resolve(probe.get_string(1)).get("valid", false)), false) and all_passed
	return all_passed


## The id scheme, including the two routes this phase added and the one it silently upgraded.
static func _test_routes() -> bool:
	var all_passed: bool = true
	var guide: Dictionary = EventSheetDocExplain.resolve("guide:GUIDE-RECIPES")
	all_passed = _check("a guide id is valid", bool(guide.get("valid", false)), true) and all_passed
	all_passed = _check("it names the page to draw", str(guide.get("page_id", "")), "GUIDE-RECIPES") and all_passed
	all_passed = _check("a guide that does not ship is refused",
		bool(EventSheetDocExplain.resolve("guide:GUIDE-NO-SUCH-THING").get("valid", false)), false) and all_passed

	# The Phase 2 promise: "addon:<pack>" callers never changed, and the id now resolves to a
	# NATIVE page as well as to the repo path it always carried.
	var addon: Dictionary = EventSheetDocExplain.resolve("addon:quest")
	all_passed = _check("a pack id still carries its repo path", str(addon.get("target", "")), "docs/Addons/Quest.md") and all_passed
	all_passed = _check("and now names the shipped page too", str(addon.get("page_id", "")), "Addons/Quest") and all_passed
	all_passed = _check("that page really ships",
		EventSheetDocLibrary.has_page(str(addon.get("page_id", ""))), true) and all_passed
	all_passed = _check("a pack that does not exist is still refused",
		bool(EventSheetDocExplain.resolve("addon:no_such_pack").get("valid", false)), false) and all_passed

	# The module scheme delegates to the module mapping, which is authored beside the module
	# guides. The lookup is soft, so this passes whether that mapping has landed or not - what it
	# pins is that a module id NEVER resolves to a page that does not ship.
	var module: Dictionary = EventSheetDocExplain.resolve("module:no_such_module_here")
	all_passed = _check("an unknown module names no shipped page",
		EventSheetDocLibrary.has_page(str(module.get("page_id", ""))), false) and all_passed
	all_passed = _check("an empty module id is refused",
		bool(EventSheetDocExplain.resolve("module:").get("valid", false)), false) and all_passed
	return all_passed


static func _test_parse_budget() -> bool:
	var start: int = Time.get_ticks_msec()
	var blocks: int = 0
	for id: String in EventSheetDocLibrary.page_ids():
		blocks += EventSheetDocLibrary.page_blocks(id).size()
	var elapsed: int = Time.get_ticks_msec() - start
	print("[note] doc_library_test: parsed the corpus into %d blocks in %d ms" % [blocks, elapsed])
	var all_passed: bool = _check("parsing the whole corpus stays inside its budget", elapsed < PARSE_BUDGET_MS, true)
	all_passed = _check("and the parse produced real blocks", blocks > 1000, true) and all_passed
	return all_passed


## slug -> true for every heading in a page, with the same duplicate tally the renderer uses, so
## the anchor sweep asks exactly what a reader's click will ask.
static func _slugs_of(source: String) -> Dictionary:
	var slugs: Dictionary = {}
	for block: Dictionary in EventSheetDocMarkdown.parse(source):
		if str(block.get("kind", "")) == "heading":
			slugs[str(block.get("slug", ""))] = true
	return slugs


## Every link target in a page, with FENCED blocks removed first: a guide that shows Markdown
## inside a code fence must not have that example swept as if it were a real link.
static func _links_in(source: String) -> PackedStringArray:
	var targets: PackedStringArray = PackedStringArray()
	var matcher: RegEx = RegEx.create_from_string("\\]\\(([^)\\s]+)")
	for found: RegExMatch in matcher.search_all(_without_fences(source)):
		targets.append(found.get_string(1))
	return targets


static func _without_fences(source: String) -> String:
	var kept: PackedStringArray = PackedStringArray()
	var inside: bool = false
	for line: String in source.replace("\r\n", "\n").split("\n"):
		if line.strip_edges().begins_with("```"):
			inside = not inside
			continue
		if not inside:
			kept.append(line)
	return "\n".join(kept)


static func _count_source_guides(directory_path: String) -> int:
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return 0
	var count: int = 0
	for file_name: String in directory.get_files():
		if file_name.get_extension().to_lower() == "md":
			count += 1
	return count


static func _collect_scripts(dir_path: String, into: PackedStringArray) -> void:
	var directory: DirAccess = DirAccess.open(dir_path)
	if directory == null:
		return
	for sub_dir: String in directory.get_directories():
		_collect_scripts(dir_path.path_join(sub_dir), into)
	for file_name: String in directory.get_files():
		if file_name.get_extension() == "gd":
			into.append(dir_path.path_join(file_name))


static func _read(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] doc_library_test: %s" % label)
		return true
	print("[FAIL] doc_library_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
