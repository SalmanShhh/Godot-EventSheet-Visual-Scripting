# EventSheet - EventSheetDocWhatsNew: "what changed since the last time you looked".
#
# Every editor tells its reader what it just did to them, and this one told nobody: the release
# notes lived in the repository, which is exactly where an installed reader never goes. So the
# CHANGELOG's own words become a page of the Manual - the unreleased section and the last release,
# nothing older, because a reader asking "what's new" is asking about the build they just got.
#
# THE EXTRACTION IS PURE (page_markdown) and the BAKING is the build tool's, for the same reason the
# figure verdicts are baked: the CHANGELOG is not in the shipped plugin (the release zip carries
# addons/ and nothing else), so the page has to travel inside the bundle. It goes into its own file
# rather than into the corpus, because a Markdown page in addons/eventsheet/help/ would become a
# guide in the tree with no source under docs/ - which the bundle's own drift check would then
# report forever.
#
# THE DOT. A reader who has not opened this page since the plugin's version changed gets a mark on
# the Manual button. The decision is one pure function over two strings (what is installed, what was
# last seen), so the suite pins it; the seen version is remembered per project like every other
# reading position.
@tool
class_name EventSheetDocWhatsNew
extends RefCounted

## The baked page, beside the manifest and the figure verdicts, with the same versioned-text
## discipline: a frozen header line, then a var_to_str payload.
const BUNDLE_PATH := "res://addons/eventsheet/help/whatsnew.esdoc"
const BUNDLE_HEADER := "[eventsheet-whatsnew v1]"

## The repository file the page is extracted from, at build time.
const SOURCE_PATH := "res://CHANGELOG.md"

## The page's own title and the reference kind it is addressed by. Frozen with the id scheme.
const PAGE_TITLE := "What's new"

## Where the last-opened version is remembered. Editor metadata rather than a project setting: it
## is a reading position, not something a project commits.
const SEEN_SECTION := "eventsheets"
const SEEN_KEY := "whats_new_seen_version"

## The heading a release section starts with in the CHANGELOG, and the one the unreleased work
## sits under. Both are the file's own spelling - this file reads the CHANGELOG, it does not
## reformat it.
const RELEASE_PREFIX := "## ["

static var _markdown: String = ""
static var _loaded: bool = false


## The page's Markdown, read from the bundle once per session. Empty when no bundle is installed
## (a source checkout that has not run the build tool), which draws an honest "not shipped" line
## rather than a blank page.
static func markdown() -> String:
	if _loaded:
		return _markdown
	_loaded = true
	_markdown = ""
	var text: String = _read(BUNDLE_PATH)
	if text.is_empty():
		return _markdown
	var newline: int = text.find("\n")
	if newline < 0 or text.substr(0, newline).strip_edges() != BUNDLE_HEADER:
		push_warning("EventSheetDocWhatsNew: %s is not an %s file." % [BUNDLE_PATH, BUNDLE_HEADER])
		return _markdown
	var payload: Variant = str_to_var(text.substr(newline + 1))
	if payload is Dictionary:
		_markdown = str((payload as Dictionary).get("markdown", ""))
	return _markdown


## Drops the cached page, so a rebuilt bundle lands without an editor restart (and so a test can
## read one it just wrote).
static func reload() -> void:
	_loaded = false
	_markdown = ""


## The page, as blocks the page view draws. Built from the baked Markdown through the one parser
## the whole Manual uses, so a release note renders exactly as a guide does - figures included.
static func blocks() -> Array[Dictionary]:
	var source: String = markdown()
	if source.strip_edges().is_empty():
		return [
			{"kind": "heading", "level": 1, "text": PAGE_TITLE, "bbcode": PAGE_TITLE,
				"slug": EventSheetDocMarkdown.slug(PAGE_TITLE)},
			{"kind": "paragraph", "bbcode":
				"[i]The release notes did not ship with this build of the plugin.[/i]"},
		]
	return EventSheetDocMarkdown.parse(source, "whatsnew")


## The page's Markdown, extracted from a CHANGELOG. PURE over the text, so the build tool bakes
## exactly what the suite pins.
##
## What comes out: the page's own title, a lead line naming the installed build, then the
## unreleased section and the LAST released one, each as a chapter the reader can fold shut.
static func page_markdown(changelog: String, version: String) -> String:
	var sections: Array[Dictionary] = _sections(changelog)
	var out: PackedStringArray = PackedStringArray()
	out.append("# %s" % PAGE_TITLE)
	out.append("")
	out.append("What changed in the build you have installed (v%s), in the words the release notes use. Older releases live in the project's own CHANGELOG." % version.strip_edges())
	var taken: int = 0
	for section: Dictionary in sections:
		if taken >= 2:
			break
		taken += 1
		out.append("")
		out.append("## %s" % str(section.get("title", "")))
		# The subsections are left at their own level rather than promoted: the page folds at H2, so
		# a release stays ONE chapter a reader can close, and "Unreleased" keeps its own notes under
		# it instead of becoming an empty heading with its contents beside it.
		for line: String in (section.get("body", []) as Array):
			out.append(line)
	out.append("")
	return "\n".join(out)


## The CHANGELOG split into its release sections, newest first, as {title, body}. `title` is the
## heading with its "## " marker and its square brackets dropped ("[0.17.0] - 2026-08-17 - Adopt
## Anything" reads "0.17.0 - 2026-08-17 - Adopt Anything"); `body` is every line until the next
## release heading, with the trailing blank lines trimmed so two sections never join with a gap
## that grows per run.
##
## `body` is a plain Array rather than a PackedStringArray on purpose: a Packed array read back out
## of a Dictionary is a COPY, so appending to it appends to nothing and every section comes out
## empty - which is exactly how the first bake of this page shipped two headings and no notes.
static func _sections(changelog: String) -> Array[Dictionary]:
	var sections: Array[Dictionary] = []
	var current: Dictionary = {}
	for line: String in changelog.replace("\r\n", "\n").split("\n"):
		if line.begins_with(RELEASE_PREFIX):
			if not current.is_empty():
				sections.append(_closed(current))
			current = {"title": _section_title(line), "body": []}
			continue
		if current.is_empty():
			continue
		(current["body"] as Array).append(line)
	if not current.is_empty():
		sections.append(_closed(current))
	return sections


## A release heading as the page prints it: no marker, no square brackets.
static func _section_title(line: String) -> String:
	return line.substr(3).strip_edges().replace("[", "").replace("]", "")


## One section with its trailing blank lines dropped.
static func _closed(section: Dictionary) -> Dictionary:
	var body: Array = section.get("body", []) as Array
	while body.size() > 0 and str(body[body.size() - 1]).strip_edges().is_empty():
		body.remove_at(body.size() - 1)
	return section


## The baked file's exact bytes: the frozen header line, then the payload.
static func bundle_text(changelog: String, version: String) -> String:
	return "%s\n%s\n" % [BUNDLE_HEADER,
		var_to_str({"version": 1, "markdown": page_markdown(changelog, version)})]


# ── The dot on the Manual button ──────────────────────────────────────────────────────────────


## True when the reader has not opened this page since the plugin's version changed. Pure over the
## two strings, so the decision is pinned rather than inferred from a screenshot.
##
## A reader who has never opened it at all gets the dot: the first build they install is news too.
static func has_unread(installed_version: String, seen_version: String) -> bool:
	var installed: String = installed_version.strip_edges()
	if installed.is_empty():
		return false
	return seen_version.strip_edges() != installed


## The version the reader last opened this page on, or "" for one who never has.
static func seen_version() -> String:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return ""
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings == null:
		return ""
	return str(settings.get_project_metadata(SEEN_SECTION, SEEN_KEY, ""))


## Records that the reader has now seen this build's notes, which is what takes the dot off.
static func mark_seen(installed_version: String) -> void:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings != null:
		settings.set_project_metadata(SEEN_SECTION, SEEN_KEY, installed_version.strip_edges())


static func _read(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()
