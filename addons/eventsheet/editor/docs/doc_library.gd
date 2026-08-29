# EventSheet - EventSheetDocLibrary: the guide corpus that ships INSIDE the plugin.
#
# The release zip carries addons/ and nothing else, so a guide that lives only in the repo is a
# guide an installed user cannot read. The build tool copies the corpus verbatim into
# addons/eventsheet/help/ and writes one manifest beside it; this file is the only thing that
# reads either. Nothing here knows where the sources came from - the copy is the corpus, and a
# test (never this file) proves the two are byte-identical.
#
# THE DOC ID is the bundle-relative path without its extension, so a guide's id is legible and
# stable: "GUIDE-RECIPES", "Addons/Quest", "Modules/Collections". The three doc sets are
# discovered as DIRECTORIES, never as a list - a new addon guide, or the whole Modules set, ships
# by existing.
#
# THE MANIFEST (index.esdoc) follows the versioned-text discipline the snippet format established:
# a header line, then a var_to_str payload written in sorted order so regeneration is byte-stable.
#   {"version": 1,
#    "pages": {id: title},                 the H1 of each page, for trees and window titles
#    "groups": [{"title", "ids"}],         derived from the docs index's own grouped link list
#    "unlisted": [id]}                     pages the index forgot - a build-check output
#
# Everything is cached per session behind a single load: a page is read from disk on demand (the
# whole corpus is about 4 MB of Markdown and a reader opens one page at a time), while the manifest -
# which the tree needs immediately - is parsed once.
@tool
class_name EventSheetDocLibrary
extends RefCounted

## Where the shipped corpus lives inside the plugin.
const HELP_ROOT := "res://addons/eventsheet/help"

## The manifest's own path and its version header. Both are frozen: a third-party build step that
## regenerates the bundle writes this exact header, and an older reader must be able to say "this
## is a newer bundle than I know" rather than mis-parse it.
const MANIFEST_PATH := "res://addons/eventsheet/help/index.esdoc"
const MANIFEST_HEADER := "[eventsheet-help v1]"

## The figure verdicts, baked beside the manifest at build time: fence body hash -> the reason it
## cannot be drawn as rows ("" when it can). Deliberately a SEPARATE file rather than a key in the
## manifest, because it is computed by a full import and compile of every fence in the corpus - the
## manifest has to stay cheap enough for the byte-drift check to rebuild it on every suite run.
const FIGURES_PATH := "res://addons/eventsheet/help/figures.esdoc"
const FIGURES_HEADER := "[eventsheet-figures v1]"

## The SEARCH INDEX, baked beside the manifest at build time: one entry per shipped page, carrying
## its title, its headings with their slugs, and the blob of its unique words. Separate from the
## manifest for the same reason the figure verdicts are - the manifest has to stay cheap enough to
## rebuild on every suite run, and this reads every page in the corpus.
##
## It is baked because of what it costs otherwise: building it in the editor means reading the whole
## 4 MB corpus and splitting all of it into words, on the reader's FIRST KEYSTROKE. Baked, a
## keystroke searches a table that was read once and touches no file at all.
##
## WHAT IT COSTS, measured rather than estimated, because this is derived data stored a second time
## and that always needs a reason: 1.3 MB for 191 pages - the unique words of the corpus rather than
## its prose. The reason is the keystroke above; the guard is that the build regenerates it from the
## pages and the suite fails on any difference, so the copy can never quietly disagree.
const SEARCH_PATH := "res://addons/eventsheet/help/search.esdoc"
const SEARCH_HEADER := "[eventsheet-search v1]"

## The bundle sub-directory each secondary doc set lives in, and the tree section it becomes.
const ADDONS_DIR := "Addons"
const MODULES_DIR := "Modules"

## The two doc sets that do NOT live in the bundle, because they do not belong to the plugin:
## a pack's own guide, and the reader's project's own guides. Their pages are discovered on disk
## every session and their ids carry these prefixes, so a page id still says where it came from.
const PACKS_SET := "Packs"
const PROJECT_SET := "Project"

## Where third-party packs live, and the file a pack ships its guide as. Discovered exactly the
## way pack-local translations.csv files are: every directory under the packs root is asked
## whether it has one. A pack becomes first-class in the reader by SHIPPING THE FILE - there is no
## list to join and no registration call to make.
const PACKS_ROOT := "res://eventsheet_addons"
const PACK_GUIDE_FILE := "guide.md"

## The project's own guide folder, mirroring the templates_dir / snippets_dir pattern: a setting
## with a default that costs nothing when the folder is not there.
const USER_DOCS_SETTING := "eventsheets/project/docs_dir"
const USER_DOCS_DEFAULT := "res://eventsheet_docs"

## Parsed once per session. A page's TEXT is deliberately not cached: the reader opens one page at
## a time and the parse is sub-millisecond, while holding the whole corpus would cost megabytes
## for the life of the editor.
static var _manifest: Dictionary = {}
static var _manifest_loaded: bool = false

## The discovered half: page id -> {path, title}, for pages that live outside the bundle (a pack's
## own guide, the project's own guides). Scanned once per session like the manifest, and dropped
## by the same reload().
static var _external: Dictionary = {}
static var _external_loaded: bool = false

## The baked figure verdicts, read once per session. An empty Dictionary is a valid state (a source
## checkout that has not run the build tool): the reader then gates every fence live, which is slow
## but never wrong.
static var _gates: Dictionary = {}
static var _gates_loaded: bool = false

## The baked search entries, read once per session. Empty is a valid state for the same reason.
static var _search: Array = []
static var _search_loaded: bool = false


## The manifest, or an empty Dictionary when no bundle is installed (a source checkout that has
## not run the build tool). Every accessor below degrades to "no pages" rather than erroring, so a
## missing bundle shows an empty tree instead of taking the editor down.
static func manifest() -> Dictionary:
	if _manifest_loaded:
		return _manifest
	_manifest_loaded = true
	_manifest = {}
	var payload: Variant = payload_of(MANIFEST_PATH, MANIFEST_HEADER)
	if payload is Dictionary:
		_manifest = payload as Dictionary
	return _manifest


## The baked figure verdicts: fence body hash -> "" when those rows can be drawn, and the reason
## they cannot otherwise. Empty when no bundle is installed, which simply means every fence is
## gated live instead.
static func gate_verdicts() -> Dictionary:
	if _gates_loaded:
		return _gates
	_gates_loaded = true
	_gates = {}
	var payload: Variant = payload_of(FIGURES_PATH, FIGURES_HEADER)
	if payload is Dictionary:
		_gates = (payload as Dictionary).get("gates", {}) as Dictionary
	return _gates


## The baked search entries, read once per session: [{id, title, headings, words}]. Empty when no
## bundle is installed, which simply means the reader's first keystroke builds the index instead.
static func search_entries() -> Array:
	if _search_loaded:
		return _search
	_search_loaded = true
	_search = []
	var payload: Variant = payload_of(SEARCH_PATH, SEARCH_HEADER)
	if payload is Dictionary:
		_search = (payload as Dictionary).get("pages", []) as Array
	return _search


## A versioned-text file's payload, or null when it is absent or carries a header this build does
## not know. THE ONE READER for every baked file in the bundle - the manifest, the figure verdicts
## and the search index - so a fourth baked file needs no fourth copy of this.
##
## An older bundle is a NULL, never an error. The bundle format grows: the search index was added
## beside the manifest, and the next one will be added the same way. A build that ships a header
## this reader does not know, or does not ship the file at all, has to degrade to "there is no baked
## table here" - the manifest falls back to an empty tree, the verdicts to gating every fence live, the
## search index to indexing each page on demand. Regenerating the bundle is the fix; taking the
## editor down is never one.
static func payload_of(path: String, header: String) -> Variant:
	var text: String = _read(path)
	if text.is_empty():
		return null
	var newline: int = text.find("\n")
	if newline < 0 or text.substr(0, newline).strip_edges() != header:
		push_warning("EventSheetDocLibrary: %s is not an %s file." % [path, header])
		return null
	return str_to_var(text.substr(newline + 1))


## Drops the cached manifest AND the discovered pages, so a rebuild - or a guide.md dropped into a
## pack while the editor is open - lands without a restart (and so a test can read a freshly
## written bundle).
static func reload() -> void:
	_manifest_loaded = false
	_manifest = {}
	_external_loaded = false
	_external = {}
	_gates_loaded = false
	_gates = {}
	_search_loaded = false
	_search = []


## Every page id the reader can open: the shipped bundle first (manifest order, sorted at build
## time), then the pages discovered on disk.
static func page_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for id: Variant in manifest().get("pages", {}):
		ids.append(str(id))
	for id: Variant in external_pages():
		ids.append(str(id))
	return ids


## True when `doc_id` names a page that really exists - shipped in the bundle or found on disk.
## The one question every route asks before it promises a reader a page.
static func has_page(doc_id: String) -> bool:
	var id: String = doc_id.strip_edges()
	if id.is_empty():
		return false
	return (manifest().get("pages", {}) as Dictionary).has(id) or external_pages().has(id)


## The file a page's Markdown is read from: the recorded path for a discovered page, and for a
## shipped one the path derived from its id rather than stored, so the bundle stays a plain
## directory a human can open.
static func page_path(doc_id: String) -> String:
	var id: String = doc_id.strip_edges()
	if id.is_empty():
		return ""
	var found: Dictionary = external_pages().get(id, {}) as Dictionary
	if not found.is_empty():
		return str(found.get("path", ""))
	return "%s/%s.md" % [HELP_ROOT, id]


## A page's Markdown, or "" when it does not ship.
static func page_source(doc_id: String) -> String:
	if not has_page(doc_id):
		return ""
	return _read(page_path(doc_id))


## A page's title (its H1, recorded at build time), falling back to the id so a tree row is never
## blank.
static func page_title(doc_id: String) -> String:
	var id: String = doc_id.strip_edges()
	var title: String = str((manifest().get("pages", {}) as Dictionary).get(id, ""))
	if title.is_empty():
		title = str((external_pages().get(id, {}) as Dictionary).get("title", ""))
	return title if not title.is_empty() else id


## A page's blocks, ready for a page view. Parsing on demand rather than at build time keeps ONE
## parser in the plugin: the moment a second doc set arrives (a project's own guides), a
## build-time page model would need a second implementation of the same parse.
static func page_blocks(doc_id: String) -> Array[Dictionary]:
	var source: String = page_source(doc_id)
	if source.is_empty():
		return []
	return EventSheetDocMarkdown.parse(source, doc_id)


## The reader's tree: the docs index's own groups, then the addon guides, then the module guides.
## Each entry is {title, ids}. Groups whose pages did not ship are dropped, so a bundle built from
## a smaller corpus still produces a tree that works.
static func groups() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Variant in manifest().get("groups", []):
		var group: Dictionary = entry as Dictionary
		var ids: PackedStringArray = PackedStringArray()
		for id: Variant in (group.get("ids", []) as Array):
			if has_page(str(id)):
				ids.append(str(id))
		if not ids.is_empty():
			out.append({"title": str(group.get("title", "")), "ids": ids})
	for section: Array in [[PACKS_SET, "Pack guides"], [PROJECT_SET, "This project"]]:
		var discovered: PackedStringArray = ids_in_set(str(section[0]))
		if not discovered.is_empty():
			out.append({"title": str(section[1]), "ids": discovered})
	return out


# ── The pages that do not ship with the plugin ────────────────────────────────────────────────


## Everything discovered on disk this session: id -> {path, title}. Two sources, both scanned by
## DIRECTORY so neither needs a list anywhere:
##   eventsheet_addons/<pack>/guide.md   -> "Packs/<pack>"
##   <the project's docs folder>/*.md    -> "Project/<stem>"
## A pack that ships a guide is a first-class page in the reader with no registration call, and a
## project that keeps its own design notes as Markdown reads them beside the plugin's guides.
static func external_pages() -> Dictionary:
	if _external_loaded:
		return _external
	_external_loaded = true
	_external = discover_pages(PACKS_ROOT, user_docs_dir())
	return _external


## The discovery itself, over roots the caller names. Written this way so the suite can point it
## at a fixture tree and pin the DECISION - a pack directory carrying guide.md becomes a page, one
## without it does not - instead of pinning whatever happens to be installed.
static func discover_pages(packs_root: String, docs_dir: String) -> Dictionary:
	var found: Dictionary = {}
	for pack_dir: String in _sorted_directories(packs_root):
		var guide: String = "%s/%s/%s" % [packs_root, pack_dir, PACK_GUIDE_FILE]
		if FileAccess.file_exists(guide):
			_record_external(found, "%s/%s" % [PACKS_SET, pack_dir], guide)
	if not docs_dir.is_empty() and DirAccess.dir_exists_absolute(docs_dir):
		_record_markdown_in(found, docs_dir, PROJECT_SET)
		# One level down as well, so a project can keep its notes in folders - and so the pages a
		# sheet writes about itself have somewhere to live that is not mixed in with hand-written
		# prose. One level and no deeper: a docs folder is a shelf, not a file system.
		var directories: PackedStringArray = _sorted_directories(docs_dir)
		for directory: String in directories:
			_record_markdown_in(found, docs_dir.path_join(directory),
				"%s/%s" % [PROJECT_SET, directory])
	return found


## Every .md directly inside one folder, recorded under `set_prefix`. Sorted, because a directory
## walk hands its files back in the filesystem's own order and the reader's tree is this order.
static func _record_markdown_in(found: Dictionary, directory: String, set_prefix: String) -> void:
	var names: PackedStringArray = DirAccess.get_files_at(directory)
	names.sort()
	for file_name: String in names:
		if file_name.get_extension().to_lower() != "md":
			continue
		_record_external(found, "%s/%s" % [set_prefix, file_name.get_basename()],
			directory.path_join(file_name))


## The page id a discovered file is known by, or "" for a file outside the corpus. The inverse of
## page_path for the discovered sets, and the reason it exists is the one-page refresh: something
## that just rewrote a file has a path and needs the id the search filed it under.
static func id_for_page_path(path: String) -> String:
	var wanted: String = path.strip_edges()
	if wanted.is_empty():
		return ""
	for id: Variant in external_pages():
		if str((external_pages()[id] as Dictionary).get("path", "")) == wanted:
			return str(id)
	return ""


## Where the reader's project keeps its own guides. A ProjectSettings key, mirroring
## vocabulary_doc_path / templates_dir / snippets_dir: readable with its own default so a project
## that never registered the setting still works.
static func user_docs_dir() -> String:
	return str(ProjectSettings.get_setting(USER_DOCS_SETTING, USER_DOCS_DEFAULT)).strip_edges()


## The page id a pack's own guide.md takes, or "" when the pack ships none. This is what makes an
## "addon:<pack>" id resolve to a NATIVE page for a third-party pack whose guide was never in this
## repo's docs/Addons folder - the caller never changes.
static func pack_page_id(pack_dir: String) -> String:
	var directory: String = pack_dir.strip_edges().trim_suffix("/").get_file()
	if directory.is_empty():
		return ""
	var id: String = "%s/%s" % [PACKS_SET, directory]
	return id if external_pages().has(id) else ""


## Records a discovered page, reading its H1 for the tree label. The file is read once, here: a
## discovered set is small (one guide per pack), and a tree that has to open every page to draw
## its own rows would stall on the first click instead.
static func _record_external(into: Dictionary, id: String, path: String) -> void:
	var title: String = _title_of(_read(path))
	into[id] = {"path": path, "title": title if not title.is_empty() else id.get_file()}


## A page's first H1, with backticks dropped - the same rule the bundle's manifest records at
## build time, so a discovered page and a shipped one are titled identically.
static func _title_of(source: String) -> String:
	for line: String in source.replace("\r\n", "\n").split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("# "):
			return stripped.substr(2).strip_edges().replace("`", "")
	return ""


static func _sorted_directories(root: String) -> PackedStringArray:
	if not DirAccess.dir_exists_absolute(root):
		return PackedStringArray()
	var names: PackedStringArray = DirAccess.get_directories_at(root)
	names.sort()
	return names


## Every page id under a bundle sub-directory ("Addons", "Modules"), sorted. This is the
## directory-discovery half: a doc set ships by existing, and no list anywhere names its pages.
static func ids_in_set(set_name: String) -> PackedStringArray:
	var prefix: String = set_name.strip_edges().trim_suffix("/") + "/"
	var ids: PackedStringArray = PackedStringArray()
	for id: String in page_ids():
		if id.begins_with(prefix):
			ids.append(id)
	return ids


## The page id a repo-relative doc path maps to ("docs/Addons/Quest.md" -> "Addons/Quest"), or ""
## for a path outside the corpus. The inverse of page_path for the sources.
static func id_for_repo_path(repo_path: String) -> String:
	var path: String = repo_path.strip_edges().trim_prefix("res://").trim_prefix("/")
	if not path.begins_with("docs/") or not path.to_lower().ends_with(".md"):
		return ""
	var id: String = path.substr("docs/".length()).trim_suffix(".md").trim_suffix(".MD")
	return "" if id.contains("internal/") else id


## The REPO path a page id came from ("Addons/Quest" -> "docs/Addons/Quest.md"), or "" for a page
## that was never in docs/ at all. The inverse of id_for_repo_path, and the reason it exists is the
## DISCOVERED sets: a pack's own guide.md and a project's own notes have page ids too, and naming
## them "docs/Packs/grapple_hook.md" would hand a reader a version-pinned link to a file that has
## never existed in this repo - the exact dead-shipped-link this whole surface removed.
static func repo_path_for_page(page_id: String) -> String:
	var id: String = page_id.strip_edges()
	if id.is_empty() or id.begins_with("%s/" % PACKS_SET) or id.begins_with("%s/" % PROJECT_SET):
		return ""
	return "docs/%s.md" % id


## The page id a link written INSIDE a page points at. Relative paths resolve against the page
## they were written in, which is what makes "../README.md" from an addon guide mean the repo
## root rather than a sibling guide. "" when the target leaves the corpus.
static func id_for_link(target: String, from_id: String) -> String:
	var path: String = _resolve_relative(target.strip_edges(), from_id)
	if path.is_empty() or not path.to_lower().ends_with(".md"):
		return ""
	var id: String = path.trim_suffix(".md").trim_suffix(".MD")
	return id if has_page(id) else ""


## The REPO path a link points at, for a target the bundle deliberately excludes (the vocabulary
## reference, the root README): the reader gets the version-pinned page in a browser rather than a
## dead link. "" when the link does not leave the corpus in a way we can name.
static func repo_path_for_link(target: String, from_id: String) -> String:
	var path: String = _resolve_relative(target.strip_edges(), from_id)
	if path.is_empty():
		return ""
	if path.begins_with("../"):
		# One level above docs/ is the repo root.
		return path.substr(3)
	return "docs/%s" % path


## Resolves a relative link against the page it was written in, collapsing "../" segments. The
## result is CORPUS-relative ("Addons/Quest.md"), or keeps a leading "../" when the target climbs
## out of docs/ entirely.
static func _resolve_relative(target: String, from_id: String) -> String:
	if target.is_empty() or target.begins_with("#"):
		return ""
	if target.begins_with("http://") or target.begins_with("https://") or target.begins_with("res://"):
		return ""
	var hash_index: int = target.find("#")
	var path: String = target if hash_index < 0 else target.substr(0, hash_index)
	if path.is_empty():
		return ""
	var base: String = from_id.get_base_dir()
	var segments: PackedStringArray = PackedStringArray()
	if not base.is_empty():
		segments = base.split("/", false)
	var climbed: int = 0
	for segment: String in path.split("/", false):
		if segment == ".":
			continue
		if segment == "..":
			if segments.is_empty():
				climbed += 1
			else:
				segments.remove_at(segments.size() - 1)
			continue
		segments.append(segment)
	var joined: String = "/".join(segments)
	return joined if climbed == 0 else "../".repeat(climbed) + joined


static func _read(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()
