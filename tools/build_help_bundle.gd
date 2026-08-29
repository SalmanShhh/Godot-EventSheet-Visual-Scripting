# EventForge - build the shipped documentation bundle (dev tool).
#
# The release zip carries addons/ and nothing else, so the guides have to live inside the plugin
# to be readable by an installed user. This copies them there VERBATIM and writes one manifest
# beside them:
#
#   docs/*.md          ->  addons/eventsheet/help/<STEM>.md            id "GUIDE-RECIPES"
#   docs/Addons/*.md   ->  addons/eventsheet/help/Addons/<STEM>.md     id "Addons/Quest"
#   docs/Modules/*.md  ->  addons/eventsheet/help/Modules/<STEM>.md    id "Modules/Collections"
#   docs/<locale>/*.md ->  addons/eventsheet/help/<locale>/<STEM>.md    id "fr/GUIDE-RECIPES"
#   (derived)          ->  addons/eventsheet/help/index.esdoc
#   (derived)          ->  addons/eventsheet/help/figures.esdoc
#   (derived)          ->  addons/eventsheet/help/whatsnew.esdoc
#   (derived)          ->  addons/eventsheet/help/search.esdoc
#
# WHAT IT COSTS, measured rather than estimated, because the payload is the whole argument against
# shipping a corpus at all: 147 pages, 3.2 MB - the top-level guides plus 72 addon guides plus the
# module guides - which roughly doubles an installed plugin. Every commit that edits a guide has to
# regenerate this, and about 30% of this repo's commits edit a guide.
#
# figures.esdoc holds the FIGURE VERDICTS: for every fence a reader could see drawn as rows, the
# answer to "can this be lifted and re-emitted byte for byte", keyed by the hash of the fence body.
# It is baked here because computing one verdict is a full import AND a compile - over 100 ms - and
# the alternative is paying it in the editor, on the click that opens the page. Nothing trusts it
# blindly: tests/doc_figures_test.gd re-derives every verdict LIVE and fails on any that disagrees.
#
# The three doc sets are discovered as DIRECTORIES. Nothing here lists a guide by name, so a new
# addon guide - or a whole new doc set - ships by existing. docs/internal/ never ships.
#
# The tree's grouping is DERIVED from docs/README.md's own grouped link list, so the order a
# reader sees is the order the index already authored, and the two cannot fall out of sync. A
# guide the index forgot is reported as `unlisted` rather than silently dropped: it still ships,
# in a trailing group, and the check prints it so somebody adds it to the index.
#
# Run:
#   godot --headless --path . --script tools/build_help_bundle.gd            regenerate
#   godot --headless --path . --script tools/build_help_bundle.gd -- --check report only
#
# Both modes print `help: pages=N drifted=N`. THE GATE IS NOT THIS FILE - the byte-identity check
# that CI runs lives in tests/doc_library_test.gd, because the suite is what CI discovers. This is
# the convenience wrapper you run while editing a guide.
@tool
extends SceneTree

const SOURCE_ROOT := "res://docs"
const BUNDLE_ROOT := "res://addons/eventsheet/help"
const MANIFEST_PATH := "res://addons/eventsheet/help/index.esdoc"
const MANIFEST_HEADER := "[eventsheet-help v1]"
const INDEX_SOURCE := "res://docs/README.md"

## The doc sets, as bundle sub-directories. "" is the top-level guide set. Discovered rather than
## listed: a directory that is not here is simply not part of the corpus (docs/internal/).
const DOC_SETS := ["", "Addons", "Modules"]


## The whole corpus, plus the TRANSLATED sets: every `docs/<locale>/` folder a translator has
## started. Those are walked by directory the same way Addons/ and Modules/ are - a translated page
## ships by existing - but they are deliberately kept out of the TREE grouping below: a French page
## is not a fourth section of the Manual, it is the French copy of a page that is already in it, and
## the reader is shown one or the other (see EventSheetDocLocale).
static func doc_sets() -> Array:
	var sets: Array = DOC_SETS.duplicate()
	sets.append_array(locale_sets())
	return sets


## Every locale directory under docs/, sorted. Decided by SHAPE ("fr", "zh_CN") rather than by a
## list of languages, so a translator who starts pt_BR needs no entry anywhere.
static func locale_sets() -> Array:
	var found: Array = []
	if not DirAccess.dir_exists_absolute(SOURCE_ROOT):
		return found
	var names: PackedStringArray = DirAccess.get_directories_at(SOURCE_ROOT)
	names.sort()
	for name: String in names:
		if EventSheetDocLocale.is_locale_prefix(name):
			found.append(name)
	return found


func _init() -> void:
	var check_only: bool = OS.get_cmdline_user_args().has("--check") or OS.get_cmdline_args().has("--check")
	var pages: Dictionary = collect_pages()
	var gates: Dictionary = build_gates(pages)
	var drifted: PackedStringArray = drifted_pages(pages)
	if read_text(EventSheetDocLibrary.FIGURES_PATH) != figures_text(gates):
		drifted.append("figures.esdoc")
	if read_text(EventSheetDocWhatsNew.BUNDLE_PATH) != whats_new_text():
		drifted.append("whatsnew.esdoc")
	if read_text(EventSheetDocDictionary.BUNDLE_PATH) != dictionary_text():
		drifted.append("dictionary.esdoc")
	if not check_only:
		write_bundle(pages)
		write_text(EventSheetDocLibrary.FIGURES_PATH, figures_text(gates))
		write_text(EventSheetDocWhatsNew.BUNDLE_PATH, whats_new_text())
		write_text(EventSheetDocDictionary.BUNDLE_PATH, dictionary_text())
		write_text(EventSheetDocLibrary.SEARCH_PATH, search_text(pages))
		drifted = PackedStringArray()
	print("help: pages=%d drifted=%d" % [pages.size(), drifted.size()])
	print("help: figure verdicts baked=%d drawable=%d" % [gates.size(), _drawable_count(gates)])
	for id: String in drifted:
		print("  drifted: %s" % id)
	var manifest: Dictionary = build_manifest(pages)
	var unlisted: Array = manifest.get("unlisted", []) as Array
	if not unlisted.is_empty():
		print("help: %d guide(s) the docs index does not link: %s" % [unlisted.size(), ", ".join(PackedStringArray(unlisted))])
	report_ace_reference_drift(pages)
	quit(1 if drifted.size() > 0 else 0)


## Every figure verdict the reader could ever ask for, computed LIVE: fence body hash -> "" when
## those rows can be drawn, and the reason they cannot otherwise.
##
## Only the fences a reader can ask about are baked - an authored ```eventsheet fence, and a
## ```gdscript fence that carries a script header. A header-less gdscript fence is refused by a
## string test that costs nothing, so baking its verdict would be paying for an answer nobody asks.
static func build_gates(pages: Dictionary) -> Dictionary:
	# The whole point is to compute these rather than read back the ones already shipped.
	EventSheetDocFigures.use_prebaked = false
	EventSheetDocFigures.clear_gate_cache()
	var keys: PackedStringArray = PackedStringArray()
	var by_key: Dictionary = {}
	for id: Variant in pages:
		for block: Dictionary in EventSheetDocMarkdown.parse(read_text(str(pages[id])), str(id)):
			if str(block.get("kind", "")) != "code":
				continue
			var body: String = EventSheetDocFigures.body_of(block)
			if not _is_gatable(str(block.get("language", "")), body):
				continue
			var key: String = EventSheetDocFigures.gate_key(body)
			if by_key.has(key):
				continue
			keys.append(key)
			by_key[key] = EventSheetDocFigures.live_capability_failure(body)
	# Sorted, so regeneration is byte-stable whatever order the corpus was walked in.
	keys.sort()
	var gates: Dictionary = {}
	for key: String in keys:
		gates[key] = str(by_key[key])
	return gates


## Whether the reader would ever ask this fence's capability question. Mirrors the recognizer's own
## precedence, and is the one place that mirroring lives.
static func _is_gatable(language: String, body: String) -> bool:
	var tag: String = language.strip_edges().to_lower()
	if tag == EventSheetDocFigures.AUTHORED_TAG:
		return true
	return tag == EventSheetDocFigures.AUTO_LANGUAGE and EventSheetDocFigures.has_script_header(body)


static func _drawable_count(gates: Dictionary) -> int:
	var count: int = 0
	for key: Variant in gates:
		if str(gates[key]).is_empty():
			count += 1
	return count


## The What's-new page's exact bytes, extracted from the repository's own CHANGELOG. It is baked
## here for the same reason the figure verdicts are: the CHANGELOG is not in the shipped plugin, so
## the page has to travel inside the bundle - and it goes into its own file rather than into the
## corpus, because a Markdown page in the help folder with no source under docs/ would be reported
## as drift forever.
static func whats_new_text() -> String:
	return EventSheetDocWhatsNew.bundle_text(read_text(EventSheetDocWhatsNew.SOURCE_PATH),
		EventSheets.docs_version())


## The dictionary page's exact bytes, generated from the reading's own idiom tables and the
## vocabulary this build loads. It is baked here for the same reason What's new is: it is derived
## from code rather than written under docs/, so it travels in its own file inside the bundle. The
## registry is built here once, which is what lets the page name the row a call is about.
static func dictionary_text() -> String:
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)
	return EventSheetDocDictionary.bundle_text(EventSheetDocDictionary.entries(registry))


## The search index's exact bytes: one entry per shipped page - its title, its headings with their
## slugs, and the blob of its unique words. Baked here because the alternative is paying for the
## whole corpus to be read and split into words in the editor, on the reader's first keystroke.
##
## Only the SHIPPED pages are baked. A pack's own guide.md and the reader's project notes are not in
## this corpus and are indexed live by the reader, which is a handful of small files rather than the
## 3 MB this saves. `pages` is already sorted by id, so the file is byte-stable across runs.
static func search_text(pages: Dictionary) -> String:
	var entries: Array = []
	for id: Variant in pages:
		var source: String = read_text(str(pages[id]))
		if source.is_empty():
			continue
		entries.append(EventSheetDocSearch.entry_for(str(id), title_of(source, str(id)), source))
	return EventSheetDocSearch.bundle_text(entries)


## The figure file's exact bytes: the frozen header line, then the payload, built in sorted order.
static func figures_text(gates: Dictionary) -> String:
	return "%s\n%s\n" % [EventSheetDocLibrary.FIGURES_HEADER, var_to_str({"version": 1, "gates": gates})]


## ADVISORY, never a gate: which pack guides' hand-written "## ACE reference" tables no longer
## match what the pack publishes. The reader never sees those tables (the viewer draws the live
## ones), so a difference is a note for whoever next edits the guide on GitHub - not a build
## failure, because a guide legitimately documents a friendlier name than the raw member and
## legitimately leaves plumbing verbs out.
static func report_ace_reference_drift(pages: Dictionary) -> void:
	var checked: int = 0
	var differing: PackedStringArray = PackedStringArray()
	for id: Variant in pages:
		var page_id: String = str(id)
		if EventSheetDocAceReference.packs_for_page(page_id).is_empty():
			continue
		checked += 1
		var blocks: Array[Dictionary] = EventSheetDocMarkdown.parse(read_text(str(pages[page_id])), page_id)
		var diff: Dictionary = EventSheetDocAceReference.diff_for_page(page_id, blocks)
		var missing: PackedStringArray = diff.get("missing", PackedStringArray())
		var extra: PackedStringArray = diff.get("extra", PackedStringArray())
		if missing.is_empty() and extra.is_empty():
			continue
		differing.append("  %s: %d verb(s) the guide does not list, %d name(s) no verb answers to" % [
			page_id, missing.size(), extra.size()])
	print("help: ace reference advisory - %d pack guide(s) checked, %d differ from the vocabulary" % [
		checked, differing.size()])
	for line: String in differing:
		print(line)


## doc id -> source path, for every page in the corpus. Sorted, so the manifest and every listing
## built from it is byte-stable across runs.
static func collect_pages() -> Dictionary:
	var pages: Dictionary = {}
	var ids: PackedStringArray = PackedStringArray()
	var source_by_id: Dictionary = {}
	for doc_set: String in doc_sets():
		var directory_path: String = SOURCE_ROOT if doc_set.is_empty() else SOURCE_ROOT.path_join(doc_set)
		var directory: DirAccess = DirAccess.open(directory_path)
		if directory == null:
			continue
		for file_name: String in directory.get_files():
			if file_name.get_extension().to_lower() != "md":
				continue
			var stem: String = file_name.get_basename()
			var id: String = stem if doc_set.is_empty() else "%s/%s" % [doc_set, stem]
			ids.append(id)
			source_by_id[id] = directory_path.path_join(file_name)
	ids.sort()
	for id: String in ids:
		pages[id] = str(source_by_id[id])
	return pages


## The ids whose bundled copy differs from its source, plus any bundled file with no source left.
## Byte comparison, never a timestamp: a copy that is one character different is drift.
static func drifted_pages(pages: Dictionary) -> PackedStringArray:
	var drifted: PackedStringArray = PackedStringArray()
	for id: Variant in pages:
		var bundled: String = "%s/%s.md" % [BUNDLE_ROOT, str(id)]
		if read_bytes(bundled) != read_bytes(str(pages[id])):
			drifted.append(str(id))
	for id: String in bundled_ids():
		if not pages.has(id):
			drifted.append("%s (no source)" % id)
	var expected: String = manifest_text(build_manifest(pages))
	if read_text(MANIFEST_PATH) != expected:
		drifted.append("index.esdoc")
	# The baked search index is gated HERE rather than beside the figure verdicts above, because
	# this function is the one CI runs (through tests/doc_library_test.gd) and a stale index is the
	# same kind of wrong as a stale page: the reader searches a corpus that is not the one shipped.
	if read_text(EventSheetDocLibrary.SEARCH_PATH) != search_text(pages):
		drifted.append("search.esdoc")
	return drifted


## Every id currently in the bundle, so a guide deleted from docs/ is deleted here too.
static func bundled_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for doc_set: String in doc_sets():
		var directory_path: String = BUNDLE_ROOT if doc_set.is_empty() else BUNDLE_ROOT.path_join(doc_set)
		var directory: DirAccess = DirAccess.open(directory_path)
		if directory == null:
			continue
		for file_name: String in directory.get_files():
			if file_name.get_extension().to_lower() != "md":
				continue
			ids.append(file_name.get_basename() if doc_set.is_empty() else "%s/%s" % [doc_set, file_name.get_basename()])
	ids.sort()
	return ids


static func write_bundle(pages: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(BUNDLE_ROOT)
	for doc_set: String in doc_sets():
		if not doc_set.is_empty():
			DirAccess.make_dir_recursive_absolute(BUNDLE_ROOT.path_join(doc_set))
	for id: String in bundled_ids():
		if not pages.has(id):
			DirAccess.remove_absolute("%s/%s.md" % [BUNDLE_ROOT, id])
	for id: Variant in pages:
		write_bytes("%s/%s.md" % [BUNDLE_ROOT, str(id)], read_bytes(str(pages[id])))
	write_text(MANIFEST_PATH, manifest_text(build_manifest(pages)))


## The manifest: page titles, the derived groups, and the guides the index forgot.
static func build_manifest(pages: Dictionary) -> Dictionary:
	var titles: Dictionary = {}
	for id: Variant in pages:
		titles[str(id)] = title_of(read_text(str(pages[id])), str(id))
	var index_text: String = read_text(INDEX_SOURCE)
	var groups: Array = index_groups(index_text, pages)
	# The index page itself leads the tree. It never links to itself, so without this it would be
	# reported as a guide nobody indexed - and the reader would lose the one page that explains
	# what the rest are for.
	if pages.has("README"):
		groups.insert(0, {"title": "Documentation index", "ids": ["README"]})
	var grouped: Dictionary = {}
	for entry: Variant in groups:
		for id: Variant in ((entry as Dictionary).get("ids", []) as Array):
			grouped[str(id)] = true
	# The secondary doc sets are grouped by DIRECTORY, not by the index: they are discovered, and
	# an index that has to list 72 addon guides by hand is an index that will fall behind.
	for doc_set: String in DOC_SETS:
		if doc_set.is_empty():
			continue
		var ids: Array = []
		for id: Variant in pages:
			if str(id).begins_with("%s/" % doc_set):
				ids.append(str(id))
				grouped[str(id)] = true
		if ids.is_empty():
			continue
		# The docs index already names an "Addon packs" section (it links the addon index page), so
		# the discovered guides JOIN that section rather than opening a second one with the same
		# title - two identical headings in the tree read as a bug, and are one.
		var existing: Dictionary = group_titled(groups, set_title(doc_set))
		if existing.is_empty():
			groups.append({"title": set_title(doc_set), "ids": ids})
		else:
			(existing["ids"] as Array).append_array(ids)
	var unlisted: Array = []
	for id: Variant in pages:
		# A translated page is not a page the index forgot: it is the same page in another language,
		# and the reader is shown it INSTEAD of the English one rather than beside it. It ships and
		# it is titled; it simply never becomes a row of the tree.
		if EventSheetDocLocale.locale_of(str(id)) != EventSheetDocLocale.BASE_LOCALE:
			continue
		if not grouped.has(str(id)):
			unlisted.append(str(id))
	if not unlisted.is_empty():
		groups.append({"title": "More guides", "ids": unlisted})
	return {"version": 1, "pages": titles, "groups": groups, "tracks": index_tracks(index_text, pages),
		"unlisted": unlisted}


## The index's own learning paths, baked so the reader has them without parsing a Markdown page to
## draw a list of tracks. Parsed by the SAME function that reads a studio's index at runtime, so the
## format a studio writes is by construction the format this understands - `ids` becomes a plain
## Array here because that is what var_to_str round-trips through the manifest.
static func index_tracks(index_text: String, pages: Dictionary) -> Array:
	var tracks: Array = []
	for track: Dictionary in EventSheetDocTracks.parse(index_text):
		var ids: Array = []
		for id: String in (track.get("ids", PackedStringArray()) as PackedStringArray):
			if pages.has(id) and not ids.has(id):
				ids.append(id)
		if ids.is_empty():
			continue
		tracks.append({"title": str(track.get("title", "")), "blurb": str(track.get("blurb", "")), "ids": ids})
	return tracks


## The group carrying `title`, or an empty Dictionary when the tree has none.
static func group_titled(groups: Array, title: String) -> Dictionary:
	for entry: Variant in groups:
		if str((entry as Dictionary).get("title", "")) == title:
			return entry as Dictionary
	return {}


## The tree section a discovered doc set becomes. Derived from the directory name so a new set
## needs no entry anywhere.
static func set_title(doc_set: String) -> String:
	match doc_set:
		"Addons":
			return "Addon packs"
		"Modules":
			return "Vocabulary modules"
	return doc_set


## The docs index's own grouping: every "## Heading" and the guide links under it, in document
## order. A link the bundle does not carry is skipped, so the tree never offers a dead page.
##
## The LEARNING PATHS section is deliberately not a group. Its pages are already grouped above by
## what they are about, and a track lists them again by the order they teach in - so grouping it too
## would put every page on a track into the tree twice, under two headings, which reads as a bug and
## is one. The same section becomes `tracks` instead (see index_tracks): one authored list, two
## derived readings, no second place to edit.
static func index_groups(index_text: String, pages: Dictionary) -> Array:
	var groups: Array = []
	var current: Dictionary = {}
	var matcher: RegEx = RegEx.create_from_string("\\]\\(([^)]+\\.md)\\)")
	for line: String in index_text.replace("\r\n", "\n").split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("## "):
			if not current.is_empty() and not (current["ids"] as Array).is_empty():
				groups.append(current)
			current = {}
			if stripped.substr(3).strip_edges() != EventSheetDocTracks.SECTION_HEADING:
				current = {"title": stripped.substr(3).strip_edges(), "ids": []}
			continue
		if current.is_empty():
			continue
		for found: RegExMatch in matcher.search_all(stripped):
			var id: String = found.get_string(1).trim_suffix(".md")
			if pages.has(id) and not (current["ids"] as Array).has(id):
				(current["ids"] as Array).append(id)
	if not current.is_empty() and not (current["ids"] as Array).is_empty():
		groups.append(current)
	return groups


## A page's title: its first H1, or its id when it has none, so a tree row is never blank.
static func title_of(source: String, id: String) -> String:
	for line: String in source.replace("\r\n", "\n").split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("# "):
			return stripped.substr(2).strip_edges().replace("`", "")
	return id.get_file()


## The manifest file's exact bytes: the frozen header line, then the payload. var_to_str writes a
## Dictionary in insertion order, and every collection above is built sorted, so two runs over the
## same corpus produce the same file.
static func manifest_text(manifest: Dictionary) -> String:
	return "%s\n%s\n" % [MANIFEST_HEADER, var_to_str(manifest)]


static func read_bytes(path: String) -> PackedByteArray:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	return file.get_buffer(file.get_length())


static func read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


static func write_bytes(path: String, data: PackedByteArray) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(data)


static func write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
