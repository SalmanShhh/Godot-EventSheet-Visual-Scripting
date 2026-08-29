# Godot EventSheets - the whole Manual written out as a folder of plain HTML files.
#
# WHAT IT IS FOR: the Manual reads well inside the editor and nowhere else. A team wiki, a pull
# request, a phone on the bus and a reader who has not installed the plugin all want the same
# corpus as files they can open, and a folder of static HTML is the only form that works in all
# four without a server, an account or a build step.
#
# THE LAW, and the reason this file is written the way it is: THE SAME BUNDLE IN PRODUCES THE SAME
# BYTES OUT. Export twice, hash the two folders, and they are identical - that is a shipped test,
# not an aspiration. Everything that could vary is therefore ruled out here: no timestamps, no
# absolute paths, no engine version stamped into a page, no dictionary walked in insertion order
# without sorting, and no counter that depends on how many pages happened to be open. A site that
# rewrote itself on every run would be unreviewable in version control, which is most of the point
# of exporting it at all.
#
# WHERE THE CONTENT COMES FROM: nothing is re-authored here. Pages are the shipped bundle's own
# Markdown, parsed by the ONE parser the editor reads with (doc_markdown.gd), so a page that renders
# in the dock renders here, and a construct the parser degrades degrades identically. The search
# index is the SAME baked table the editor searches (search.esdoc), re-emitted as JavaScript - the
# site does not get a second index built a second way, because two indexes of one corpus disagree
# the first week.
#
# FIGURES. A fence the editor would draw as live rows cannot be drawn by a browser, so the site
# carries a picture of it instead - rendered by the real renderer, off the same rows, and CACHED BY
# THE HASH OF THE FENCE BODY. An unchanged figure is therefore never re-rendered, and a figure with
# no cached image degrades to the code card the reader would otherwise have seen. That degradation
# is deliberate: an export must work headlessly and on a machine that cannot open a window.
#
# ENGINE TEXT CARRIES ITS CREDIT. Any page built from the harvested engine reference is written with
# the CC BY attribution the engine's documentation is offered under, on the page itself and in the
# site footer. This is not optional and is not a setting.
@tool
class_name EventSheetDocSiteExport
extends RefCounted

## Where a page, a figure and the two client-side files land inside the export folder. Frozen names:
## an exported site is committed and diffed, and renaming a folder rewrites every link in it.
const PAGES_DIR := "pages"
const FIGURES_DIR := "figures"
const STYLE_FILE := "site.css"
const SEARCH_SCRIPT_FILE := "search.js"
const SEARCH_DATA_FILE := "search-index.js"
const INDEX_FILE := "index.html"

## The separator a page id's slashes fold to in a file name. "Addons/Quest" is one page, not a
## directory tree: a flat pages folder keeps every relative link in the site one shape.
const ID_SEPARATOR := "__"

## The page-id prefixes this exporter mints for pages that are DERIVED rather than shipped as
## Markdown. They are page ids like any other, so a link, a search entry and a file name all treat
## them the same way.
const DICTIONARY_ID := "Reference/Dictionary"
const MANUAL_PREFIX := "Manual/"
const ENGINE_PREFIX := "Engine/"

## The section titles the derived pages are filed under in the contents.
const MANUAL_GROUP := "This project, page by page"
const ENGINE_GROUP := "The engine's own reference"
const REFERENCE_GROUP := "Reference"

## The site's own footer line. Deliberately says what the folder IS, because a reader who found one
## of these pages in a wiki has no other way to know where it came from.
##
## THE CHROME IS ENGLISH AND THE PAGES ARE NOT. This line, the search box's placeholder and the
## Contents link are the site's own furniture; the PAGES follow the locale the export was asked for.
## They are English literals rather than translated strings on purpose: the export's bytes may not
## depend on anything outside the bundle and the options, and translating them through the running
## editor's catalog would make the same command on two machines write two different sites. Giving
## the furniture its own translations is a job for the day the site is offered to readers who do not
## read English, and it is not done by reading the editor's language while exporting.
const FOOTER_LINE := "Exported from this project's Godot EventSheets Manual. Every page here is a copy of a page in the editor."

## The sentence a page carries when the reader's language has no copy of it. The editor's own
## wording, so the two surfaces cannot drift apart.
const UNTRANSLATED_CLASS := "untranslated"


## Everything the site is built from, in the order a reader meets it. Each entry is
## {id, title, group, source, blocks, engine}: `source` is Markdown for a page that has some, and
## `blocks` are pre-parsed blocks for a page that is derived from data rather than from a file.
##
## `options` (all optional):
##   locale      the language to export ("en" by default); a page with no copy in it is exported in
##               English and marked
##   sheets      {path: EventSheetResource} - the project's own sheets, each of which gets the page
##               it writes about itself
##   engine      true to include the harvested engine reference (refused when nothing is harvested)
##   page_ids    an explicit id list, for a test that pins the shape against fixtures
static func gather_pages(options: Dictionary = {}) -> Array[Dictionary]:
	var locale_code: String = str(options.get("locale", EventSheetDocLocale.BASE_LOCALE)).strip_edges()
	var pages: Array[Dictionary] = []
	var available: PackedStringArray = EventSheetDocLibrary.page_ids()
	for group: Dictionary in _library_groups(options):
		var title: String = str(group.get("title", ""))
		for id: String in (group.get("ids", PackedStringArray()) as PackedStringArray):
			var shown: String = EventSheetDocLocale.page_for(id, locale_code, available)
			var source: String = EventSheetDocLibrary.page_source(shown)
			if source.is_empty():
				continue
			pages.append({
				"id": id,
				"title": EventSheetDocLibrary.page_title(shown),
				"group": title,
				"source": source,
				"blocks": [],
				"engine": false,
				"untranslated": EventSheetDocLocale.is_untranslated(shown, locale_code),
			})
	pages.append_array(_dictionary_pages())
	pages.append_array(_manual_pages(options.get("sheets", {}) as Dictionary))
	pages.append_array(_engine_pages(options))
	return pages


## The shipped tree, or the explicit id list a caller pinned. One group per section, exactly as the
## dock's own contents draws it.
static func _library_groups(options: Dictionary) -> Array[Dictionary]:
	if options.has("page_ids"):
		var ids: PackedStringArray = PackedStringArray()
		for id: Variant in (options["page_ids"] as Array):
			ids.append(str(id))
		return [{"title": REFERENCE_GROUP, "ids": ids}]
	return EventSheetDocLibrary.groups()


## The GDScript-to-events dictionary, which is derived from the live vocabulary rather than written
## down anywhere - so the site carries the vocabulary this install actually has.
static func _dictionary_pages() -> Array[Dictionary]:
	var source: String = EventSheetDocDictionary.markdown()
	if source.strip_edges().is_empty():
		return []
	return [{
		"id": DICTIONARY_ID,
		"title": EventSheetDocDictionary.PAGE_TITLE,
		"group": REFERENCE_GROUP,
		"source": source,
		"blocks": [],
		"engine": false,
		"untranslated": false,
	}]


## A page per sheet, in the words the sheet itself carries. Sorted by the caller's key, which is
## what the manual already promises: a directory walk's own order would diff between machines.
static func _manual_pages(sheets: Dictionary) -> Array[Dictionary]:
	var pages: Array[Dictionary] = []
	var written: Dictionary = EventSheetProjectManual.pages_for(sheets)
	for key: Variant in written:
		var source: String = str(written[key])
		if source.strip_edges().is_empty():
			continue
		pages.append({
			"id": "%s%s" % [MANUAL_PREFIX, _manual_key(str(key))],
			"title": _first_heading(source),
			"group": MANUAL_GROUP,
			"source": source,
			"blocks": [],
			"engine": false,
			"untranslated": false,
		})
	return pages


## The harvested engine classes, when the caller asked for them AND a harvest for this engine is on
## disk. Every one of these pages carries the CC BY credit; see _page_html.
static func _engine_pages(options: Dictionary) -> Array[Dictionary]:
	if not bool(options.get("engine", false)):
		return []
	if not EventSheetDocEngineReference.is_harvested():
		return []
	var pages: Array[Dictionary] = []
	for class_id: String in EventSheetDocEngineReference.class_names():
		# ONLY CLASSES WHOSE TEXT THIS MACHINE ACTUALLY HAS. A harvest carries the shape of every
		# class and the words of none until somebody fetches them, and a class with no words is drawn
		# in the reader as a page that says so and offers the editor's own help - neither of which
		# means anything in an exported site, where there is no editor to hand it to and no way for a
		# reader to fetch anything. A thousand published pages of names with no descriptions is a site
		# that looks broken, so they are simply not published.
		if not EventSheetDocEngineReference.has_prose(class_id):
			continue
		var blocks: Array[Dictionary] = EventSheetDocEngineReference.blocks_for(class_id)
		if blocks.is_empty():
			continue
		pages.append({
			"id": "%s%s" % [ENGINE_PREFIX, class_id],
			"title": class_id,
			"group": ENGINE_GROUP,
			"source": "",
			"blocks": blocks,
			"engine": true,
			"untranslated": false,
		})
	return pages


## A sheet path folded to the stem a page id can carry. The manual's own rule, asked rather than
## repeated: the file name, plus a tail derived from its folder when it has one, so two sheets
## called main.gd in two folders are two pages here and not one page written twice - and so that a
## published page id never spells out the shape of somebody's project.
static func _manual_key(key: String) -> String:
	return EventSheetProjectManual.page_stem(key)


static func _first_heading(source: String) -> String:
	for line: String in source.replace("\r\n", "\n").split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("# "):
			return stripped.substr(2).strip_edges().replace("`", "")
	return ""


# ── Figures ───────────────────────────────────────────────────────────────────────────────────


## Every fence in the corpus a reader would see drawn as rows, as {hash, body, caption, page_id},
## sorted by hash and carrying each body once however many pages quote it. This is the render
## harness's whole input: it draws what is not already in the cache and nothing else.
static func figure_jobs(pages: Array[Dictionary]) -> Array[Dictionary]:
	var by_hash: Dictionary = {}
	for page: Dictionary in pages:
		for block: Dictionary in _blocks_of(page):
			var verdict: Dictionary = EventSheetDocFigures.recognize(block)
			if str(verdict.get("mode", "")) != EventSheetDocFigures.MODE_FIGURE:
				continue
			var body: String = str(verdict.get("body", ""))
			var key: String = EventSheetDocFigures.gate_key(body)
			if by_hash.has(key):
				continue
			by_hash[key] = {
				"hash": key,
				"body": body,
				"caption": str(verdict.get("caption", "")),
				"page_id": str(page.get("id", "")),
			}
	var keys: PackedStringArray = PackedStringArray()
	for key: Variant in by_hash:
		keys.append(str(key))
	keys.sort()
	var jobs: Array[Dictionary] = []
	for key: String in keys:
		jobs.append(by_hash[key] as Dictionary)
	return jobs


## The file one figure's picture is cached under. One definition, so the exporter, the render
## harness and the housekeeping report cannot disagree about what "already drawn" means.
static func figure_file(figure_hash: String) -> String:
	return "%s.png" % figure_hash


## The job list as text a render harness reads: the frozen header, then the payload. Written rather
## than passed in memory because the harness runs in ANOTHER process - drawing needs a window, and
## an export has to work in a terminal.
const JOBS_HEADER := "[eventsheet-figure-jobs v1]"


static func jobs_text(jobs: Array[Dictionary]) -> String:
	var payload: Array = []
	for job: Dictionary in jobs:
		payload.append({"hash": str(job.get("hash", "")), "body": str(job.get("body", "")),
			"caption": str(job.get("caption", ""))})
	return "%s\n%s\n" % [JOBS_HEADER, var_to_str({"version": 1, "jobs": payload})]


static func read_jobs(path: String) -> Array[Dictionary]:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var text: String = file.get_as_text()
	var newline: int = text.find("\n")
	if newline < 0 or text.substr(0, newline).strip_edges() != JOBS_HEADER:
		return []
	var payload: Variant = str_to_var(text.substr(newline + 1))
	if not (payload is Dictionary):
		return []
	var jobs: Array[Dictionary] = []
	for entry: Variant in ((payload as Dictionary).get("jobs", []) as Array):
		jobs.append(entry as Dictionary)
	return jobs


# ── HTML ──────────────────────────────────────────────────────────────────────────────────────


## The five characters that must never reach a browser as themselves. Applied to every piece of
## authored text on its way into the page, before any tag is added to it.
static func escape_html(text: String) -> String:
	var out: String = text.replace("&", "&amp;")
	out = out.replace("<", "&lt;").replace(">", "&gt;")
	return out.replace("\"", "&quot;").replace("'", "&#39;")


## One run of the parser's BBCode as HTML. The tag set is small and closed - the Markdown parser
## emits exactly [b], [i], [code], [url=…] and the two bracket escapes - so this is a scanner over
## those and nothing else; anything unrecognised is shown as the literal text it is, which is the
## same degradation the editor's own renderer makes.
static func bbcode_to_html(bbcode: String, context: Dictionary = {}) -> String:
	var out: String = ""
	var index: int = 0
	# Whether each still-open [url] became a real anchor, innermost last, so its closing tag matches
	# what was opened. A link the site cannot honour opens a <span> and has to close one.
	var opened: Array[bool] = []
	while index < bbcode.length():
		var character: String = bbcode[index]
		if character != "[":
			out += escape_html(character)
			index += 1
			continue
		var close: int = bbcode.find("]", index)
		if close < 0:
			out += escape_html(bbcode.substr(index))
			break
		var tag: String = bbcode.substr(index + 1, close - index - 1)
		index = close + 1
		match tag:
			"lb":
				out += "["
			"rb":
				out += "]"
			"b":
				out += "<strong>"
			"/b":
				out += "</strong>"
			"i":
				out += "<em>"
			"/i":
				out += "</em>"
			"code":
				out += "<code>"
			"/code":
				out += "</code>"
			"/url":
				var was_link: bool = bool(opened.pop_back()) if not opened.is_empty() else true
				out += "</a>" if was_link else "</span>"
			_:
				if tag.begins_with("url="):
					var href: String = site_href(tag.substr(4), context)
					# A link the site cannot honour is shown as its own words rather than as a
					# door that opens on nothing. The reader loses a jump; a dead link loses trust.
					out += "<a href=\"%s\">" % escape_html(href) if not href.is_empty() else "<span>"
					opened.append(not href.is_empty())
				else:
					out += escape_html("[%s]" % tag)
	return out


## Where a link written inside a guide points once the corpus is a folder of HTML: the same page's
## file for a doc-relative link, the anchor alone for an in-page jump, the address itself for the
## web, and "" for anything this folder does not contain.
static func site_href(target: String, context: Dictionary) -> String:
	var classified: Dictionary = EventSheetDocMarkdown.classify_link(target)
	var kind: String = str(classified.get("kind", ""))
	var anchor: String = str(classified.get("anchor", ""))
	if kind == "url":
		return target
	if kind == "anchor":
		return "#%s" % anchor
	var from_id: String = str(context.get("page_id", ""))
	var wanted: String = ""
	if kind == "docid":
		wanted = str(classified.get("target", ""))
	elif kind == "doc":
		wanted = EventSheetDocLibrary.id_for_link(str(classified.get("target", "")), from_id)
	if wanted.is_empty():
		return ""
	var exported: Dictionary = context.get("exported", {}) as Dictionary
	if not exported.is_empty() and not exported.has(wanted):
		return ""
	var prefix: String = "" if int(context.get("depth", 0)) > 0 else "%s/" % PAGES_DIR
	return "%s%s%s" % [prefix, page_file(wanted), "" if anchor.is_empty() else "#%s" % anchor]


## One page's blocks as HTML. `context` carries what a block needs but a block does not know:
##   figures   hash -> true for every picture the export has on disk
##   depth     how far the page sits below the site root, for relative links
static func blocks_html(blocks: Array[Dictionary], context: Dictionary = {}) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for block: Dictionary in blocks:
		lines.append(_block_html(block, context))
	return "\n".join(lines)


static func _block_html(block: Dictionary, context: Dictionary) -> String:
	match str(block.get("kind", "")):
		"heading":
			var level: int = clampi(int(block.get("level", 1)), 1, 6)
			return "<h%d id=\"%s\">%s</h%d>" % [level, escape_html(str(block.get("slug", ""))),
				bbcode_to_html(str(block.get("bbcode", "")), context), level]
		"paragraph":
			return "<p>%s</p>" % bbcode_to_html(str(block.get("bbcode", "")), context)
		"quote":
			return "<blockquote>%s</blockquote>" % bbcode_to_html(str(block.get("bbcode", "")), context)
		"rule":
			return "<hr>"
		"image":
			# Images do not ship with the bundle, so the page says what the picture was of rather
			# than drawing a broken frame around nothing.
			return "<p class=\"image-note\">%s</p>" % escape_html(str(block.get("alt", "")))
		"list":
			return _list_html(block, context)
		"table":
			return _table_html(block, context)
		"code":
			return _code_html(block, context)
	return ""


static func _list_html(block: Dictionary, context: Dictionary) -> String:
	var tag: String = "ol" if bool(block.get("ordered", false)) else "ul"
	var lines: PackedStringArray = PackedStringArray(["<%s>" % tag])
	for entry: Variant in (block.get("items", []) as Array):
		var item: Dictionary = entry as Dictionary
		var indent: int = maxi(0, int(item.get("indent", 0)))
		lines.append("<li class=\"indent-%d\">%s</li>" % [indent,
			bbcode_to_html(str(item.get("bbcode", "")), context)])
	lines.append("</%s>" % tag)
	return "\n".join(lines)


static func _table_html(block: Dictionary, context: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray(["<table>", "<thead>", "<tr>"])
	for cell: Variant in (block.get("headers", []) as Array):
		lines.append("<th>%s</th>" % bbcode_to_html(str(cell), context))
	lines.append("</tr>")
	lines.append("</thead>")
	lines.append("<tbody>")
	for row: Variant in (block.get("rows", []) as Array):
		lines.append("<tr>")
		for cell: Variant in (row as Array):
			lines.append("<td>%s</td>" % bbcode_to_html(str(cell), context))
		lines.append("</tr>")
	lines.append("</tbody>")
	lines.append("</table>")
	return "\n".join(lines)


## A fence: the picture of its rows when one has been drawn, and the code itself when one has not.
## Both forms are complete answers - a reader with no picture still gets the example, which is why
## an export never fails on a missing figure.
static func _code_html(block: Dictionary, context: Dictionary) -> String:
	var body: PackedStringArray = PackedStringArray()
	for line: Variant in (block.get("lines", []) as Array):
		body.append(escape_html(str(line)))
	var code_card: String = "<pre><code>%s</code></pre>" % "\n".join(body)
	var verdict: Dictionary = EventSheetDocFigures.recognize(block)
	if str(verdict.get("mode", "")) != EventSheetDocFigures.MODE_FIGURE:
		return code_card
	var key: String = EventSheetDocFigures.gate_key(str(verdict.get("body", "")))
	var drawn: Dictionary = context.get("figures", {}) as Dictionary
	if not drawn.has(key):
		return code_card
	var caption: String = str(verdict.get("caption", ""))
	var prefix: String = "../" if int(context.get("depth", 0)) > 0 else ""
	var alt: String = caption if not caption.is_empty() else "Event sheet rows"
	var lines: PackedStringArray = PackedStringArray(["<figure>",
		"<img src=\"%s%s/%s\" alt=\"%s\">" % [prefix, FIGURES_DIR, figure_file(key), escape_html(alt)]])
	if not caption.is_empty():
		lines.append("<figcaption>%s</figcaption>" % escape_html(caption))
	lines.append("</figure>")
	return "\n".join(lines)


## One whole page file. The head carries no generator line and no date: two exports of one bundle
## are the same bytes, and a stamp is the easiest way to lose that.
static func page_html(page: Dictionary, page_context: Dictionary = {}) -> String:
	var title: String = str(page.get("title", ""))
	# The page's own id travels with the blocks, because a link written inside a guide is relative to
	# the guide it was written in - "../README.md" means different files on different pages.
	var context: Dictionary = page_context.duplicate()
	context["page_id"] = str(page.get("id", ""))
	var inner: PackedStringArray = PackedStringArray()
	if bool(page.get("untranslated", false)):
		inner.append("<p class=\"%s\">%s</p>" % [UNTRANSLATED_CLASS,
			escape_html(EventSheetDocLocale.note_text())])
	inner.append(blocks_html(_blocks_of(page), context))
	if bool(page.get("engine", false)):
		inner.append("<p class=\"credit\">%s</p>" % escape_html(
			EventSheetDocEngineReference.CREDIT_LINE))
	return _document(title, "\n".join(inner), int(context.get("depth", 0)),
		bool(context.get("engine_credit", false)), false, str(context.get("locale", "")))


## The contents page: every group, every page in it, and the search box. The whole site is reachable
## from here, which is what makes the folder usable when it is opened from a file manager.
static func index_html(pages: Array[Dictionary], context: Dictionary = {}) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("<h1>%s</h1>" % escape_html(str(context.get("site_title", "Manual"))))
	lines.append("<div id=\"search\"><input id=\"q\" type=\"search\" placeholder=\"%s\" autocomplete=\"off\"><ol id=\"results\"></ol></div>" % escape_html("Search the Manual"))
	var current: String = ""
	var open_list: bool = false
	for page: Dictionary in pages:
		var group: String = str(page.get("group", ""))
		if group != current:
			if open_list:
				lines.append("</ul>")
			current = group
			lines.append("<h2>%s</h2>" % escape_html(group))
			lines.append("<ul class=\"contents\">")
			open_list = true
		lines.append("<li><a href=\"%s/%s\">%s</a></li>" % [PAGES_DIR,
			escape_html(page_file(str(page.get("id", "")))), escape_html(str(page.get("title", "")))])
	if open_list:
		lines.append("</ul>")
	return _document(str(context.get("site_title", "Manual")), "\n".join(lines), 0,
		bool(context.get("engine_credit", false)), true, str(context.get("locale", "")))


## The file name a page id is written to.
static func page_file(page_id: String) -> String:
	return "%s.html" % page_id.replace("/", ID_SEPARATOR).replace(":", ID_SEPARATOR)


static func _document(title: String, body: String, depth: int, engine_credit: bool,
		with_search: bool = false, locale_code: String = "") -> String:
	var prefix: String = "../" if depth > 0 else ""
	var lines: PackedStringArray = PackedStringArray()
	lines.append("<!doctype html>")
	# The language the PAGE is in, which is the language the export asked for. A French page that
	# declares itself English is read out in the wrong voice by a screen reader and hyphenated by the
	# wrong rules by a browser, and both of those happen silently.
	var language: String = locale_code.strip_edges()
	lines.append("<html lang=\"%s\">" % escape_html(
		language if not language.is_empty() else EventSheetDocLocale.BASE_LOCALE))
	lines.append("<head>")
	lines.append("<meta charset=\"utf-8\">")
	lines.append("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">")
	lines.append("<title>%s</title>" % escape_html(title))
	lines.append("<link rel=\"stylesheet\" href=\"%s%s\">" % [prefix, STYLE_FILE])
	lines.append("</head>")
	lines.append("<body>")
	lines.append("<nav><a href=\"%s%s\">%s</a></nav>" % [prefix, INDEX_FILE, escape_html("Contents")])
	lines.append("<main>")
	lines.append(body)
	lines.append("</main>")
	lines.append("<footer>")
	lines.append("<p>%s</p>" % escape_html(FOOTER_LINE))
	if engine_credit:
		lines.append("<p class=\"credit\">%s</p>" % escape_html(
			EventSheetDocEngineReference.CREDIT_LINE))
	lines.append("</footer>")
	if with_search:
		lines.append("<script src=\"%s\"></script>" % SEARCH_DATA_FILE)
		lines.append("<script src=\"%s\"></script>" % SEARCH_SCRIPT_FILE)
	lines.append("</body>")
	lines.append("</html>")
	return "\n".join(lines) + "\n"


static func _blocks_of(page: Dictionary) -> Array[Dictionary]:
	var blocks: Array = page.get("blocks", []) as Array
	if not blocks.is_empty():
		var typed: Array[Dictionary] = []
		for entry: Variant in blocks:
			typed.append(entry as Dictionary)
		return typed
	return EventSheetDocMarkdown.parse(str(page.get("source", "")), str(page.get("id", "")))


# ── The search index the site ships ───────────────────────────────────────────────────────────


## The site's search data: the SAME entries the editor searches, re-emitted as one JavaScript
## assignment. Baked where the bundle already baked it, derived only for the pages the bundle cannot
## know about (the project's own manual, the dictionary) - one table, two readers.
static func search_data_js(pages: Array[Dictionary]) -> String:
	var baked: Dictionary = {}
	for entry: Variant in EventSheetDocLibrary.search_entries():
		var row: Dictionary = entry as Dictionary
		baked[str(row.get("id", ""))] = row
	var out: Array = []
	for page: Dictionary in pages:
		var id: String = str(page.get("id", ""))
		var entry: Dictionary = baked.get(id, {}) as Dictionary
		if entry.is_empty():
			entry = EventSheetDocSearch.baked(EventSheetDocSearch.entry_for(id,
				str(page.get("title", "")), _searchable_text(page)))
		out.append({
			"id": id,
			"file": page_file(id),
			"title": str(entry.get("title", page.get("title", ""))),
			"headings": entry.get("headings", []),
			"words": str(entry.get("words", "")),
		})
	return "window.EVENTSHEET_DOCS = %s;\n" % JSON.stringify(out)


## What a derived page offers the index. A page built from blocks has no Markdown, so its words come
## from the text of its blocks - the same words a reader can see on it.
static func _searchable_text(page: Dictionary) -> String:
	var source: String = str(page.get("source", ""))
	if not source.is_empty():
		return source
	var lines: PackedStringArray = PackedStringArray()
	for block: Dictionary in _blocks_of(page):
		for key: String in ["text", "bbcode"]:
			var text: String = str(block.get(key, ""))
			if not text.is_empty():
				lines.append(EventSheetDocMarkdown.plain_text(text))
	return "\n".join(lines)


## The site's stylesheet. Written out rather than inlined into every page so the export diffs as one
## file when the look changes instead of as every page at once. Deliberately plain: this has to be
## readable in a browser with no network, and a font nobody has is worse than the one they do.
const SITE_CSS := """body { margin: 0; font: 16px/1.6 system-ui, sans-serif; color: #1d1f21; background: #fbfbfa; }
nav, main, footer { max-width: 46rem; margin: 0 auto; padding: 0 1.25rem; }
nav { padding-top: 1.25rem; }
nav a { color: #7a5c17; text-decoration: none; }
h1, h2, h3, h4, h5, h6 { line-height: 1.25; margin: 2rem 0 0.6rem; }
h1 { font-size: 1.9rem; }
code { background: #efece4; padding: 0.1em 0.3em; border-radius: 3px; font-size: 0.92em; }
pre { background: #efece4; padding: 0.9rem 1rem; overflow-x: auto; border-radius: 4px; }
pre code { background: none; padding: 0; }
blockquote { margin: 1rem 0; padding: 0.4rem 1rem; border-left: 3px solid #c8a13a; background: #f5f1e6; }
table { border-collapse: collapse; width: 100%; margin: 1rem 0; display: block; overflow-x: auto; }
th, td { border: 1px solid #ddd8cc; padding: 0.4rem 0.6rem; text-align: left; vertical-align: top; }
figure { margin: 1.2rem 0; }
figure img { max-width: 100%; border: 1px solid #ddd8cc; border-radius: 4px; }
figcaption { font-size: 0.9rem; color: #57534a; margin-top: 0.4rem; }
li.indent-1 { margin-left: 1.2rem; } li.indent-2 { margin-left: 2.4rem; }
ul.contents { list-style: none; padding-left: 0; }
ul.contents li { padding: 0.15rem 0; }
.untranslated, .credit, .image-note { color: #57534a; font-size: 0.92rem; }
.untranslated { border-left: 3px solid #c8a13a; padding-left: 0.8rem; }
footer { border-top: 1px solid #ddd8cc; margin-top: 3rem; padding-top: 1rem; padding-bottom: 3rem; font-size: 0.9rem; color: #57534a; }
#search input { width: 100%; padding: 0.6rem 0.7rem; font-size: 1rem; border: 1px solid #ddd8cc; border-radius: 4px; }
#results { list-style: none; padding-left: 0; }
#results li { padding: 0.2rem 0; }
#results .where { color: #57534a; }
@media (prefers-color-scheme: dark) {
	body { background: #17181a; color: #e6e3dd; }
	code, pre { background: #232427; }
	th, td, figure img, #search input, footer { border-color: #3a3b3f; }
	blockquote { background: #232427; }
	nav a, a { color: #d9b96a; }
}
"""

## The site's search, which is the editor's ranking rule written once more for a browser: a title
## match beats a heading match beats a word in the body, and nothing else is scored. It reads the
## same table the editor reads, so a query that finds a page in the dock finds it here.
const SEARCH_JS := """(function () {
	var pages = window.EVENTSHEET_DOCS || [];
	var box = document.getElementById("q");
	var list = document.getElementById("results");
	if (!box || !list) { return; }
	function score(page, wanted) {
		var title = page.title.toLowerCase();
		if (title.indexOf(wanted) === 0) { return [0, null]; }
		if (title.indexOf(wanted) > 0) { return [1, null]; }
		for (var i = 0; i < page.headings.length; i++) {
			var heading = page.headings[i].text.toLowerCase();
			if (heading.indexOf(wanted) === 0) { return [2, page.headings[i]]; }
			if (heading.indexOf(wanted) > 0) { return [3, page.headings[i]]; }
		}
		if (page.words.indexOf(" " + wanted) >= 0) { return [4, null]; }
		return [99, null];
	}
	function render() {
		var wanted = box.value.trim().toLowerCase();
		list.innerHTML = "";
		if (!wanted) { return; }
		var found = [];
		for (var i = 0; i < pages.length; i++) {
			var verdict = score(pages[i], wanted);
			if (verdict[0] < 99) { found.push({ page: pages[i], rank: verdict[0], heading: verdict[1], order: i }); }
		}
		found.sort(function (a, b) { return a.rank - b.rank || a.order - b.order; });
		for (var j = 0; j < found.length && j < 30; j++) {
			var hit = found[j];
			var item = document.createElement("li");
			var link = document.createElement("a");
			link.href = "pages/" + hit.page.file + (hit.heading ? "#" + hit.heading.slug : "");
			link.textContent = hit.page.title;
			item.appendChild(link);
			if (hit.heading) {
				var where = document.createElement("span");
				where.className = "where";
				where.textContent = " - " + hit.heading.text;
				item.appendChild(where);
			}
			list.appendChild(item);
		}
	}
	box.addEventListener("input", render);
})();
"""


# ── Writing the folder ────────────────────────────────────────────────────────────────────────


## Exports the whole site into `out_dir`, and answers what it wrote:
##   {pages, figures, undrawn, files, jobs_path, engine}
##
## `options` are gather_pages's, plus:
##   figures_dir   where drawn figures are cached (default: the shared cache below)
##   site_title    the heading the contents page carries
##
## THE FOLDER IS CLEARED OF WHAT THIS EXPORTER OWNS FIRST. A page deleted from the corpus has to
## disappear from the site, and an export that only ever adds files would leave it there forever -
## which is also the difference between "hash the folder twice" passing and meaning something.
static func export_site(out_dir: String, options: Dictionary = {}) -> Dictionary:
	var root: String = out_dir.strip_edges().trim_suffix("/")
	var report: Dictionary = {"pages": 0, "figures": 0, "undrawn": 0, "files": PackedStringArray(),
		"jobs_path": "", "engine": false, "error": ""}
	if root.is_empty():
		report["error"] = "no export folder was named"
		return report
	var pages: Array[Dictionary] = gather_pages(options)
	if pages.is_empty():
		report["error"] = "there are no pages to export - is the help bundle built?"
		return report
	var cache: String = str(options.get("figures_dir", figures_cache_dir())).trim_suffix("/")
	var jobs: Array[Dictionary] = figure_jobs(pages)
	var drawn: Dictionary = drawn_figures(jobs, cache)
	var engine_credit: bool = false
	for page: Dictionary in pages:
		if bool(page.get("engine", false)):
			engine_credit = true
			break
	DirAccess.make_dir_recursive_absolute(root)
	DirAccess.make_dir_recursive_absolute("%s/%s" % [root, PAGES_DIR])
	DirAccess.make_dir_recursive_absolute("%s/%s" % [root, FIGURES_DIR])
	_clear_site(root)
	var written: PackedStringArray = PackedStringArray()
	var exported: Dictionary = {}
	for page: Dictionary in pages:
		exported[str(page.get("id", ""))] = true
	var site_locale: String = str(options.get("locale", EventSheetDocLocale.BASE_LOCALE)).strip_edges()
	var context: Dictionary = {"figures": drawn, "depth": 1, "engine_credit": engine_credit,
		"exported": exported, "locale": site_locale}
	_write(root, STYLE_FILE, SITE_CSS, written)
	_write(root, SEARCH_SCRIPT_FILE, SEARCH_JS, written)
	_write(root, SEARCH_DATA_FILE, search_data_js(pages), written)
	_write(root, INDEX_FILE, index_html(pages, {"engine_credit": engine_credit, "locale": site_locale,
		"site_title": str(options.get("site_title", "The EventSheets Manual"))}), written)
	for page: Dictionary in pages:
		_write(root, "%s/%s" % [PAGES_DIR, page_file(str(page.get("id", "")))],
			page_html(page, context), written)
	for key: Variant in drawn:
		var name: String = figure_file(str(key))
		_copy(("%s/%s" % [cache, name]), "%s/%s/%s" % [root, FIGURES_DIR, name], written,
			"%s/%s" % [FIGURES_DIR, name])
	DirAccess.make_dir_recursive_absolute(cache)
	var jobs_path: String = "%s/jobs.esdoc" % cache
	var jobs_file: FileAccess = FileAccess.open(jobs_path, FileAccess.WRITE)
	if jobs_file != null:
		jobs_file.store_string(jobs_text(jobs))
	report["pages"] = pages.size()
	report["figures"] = drawn.size()
	report["undrawn"] = jobs.size() - drawn.size()
	report["files"] = written
	report["jobs_path"] = jobs_path
	report["engine"] = engine_credit
	return report


## Which of the wanted figures already have a picture on disk, as hash -> true.
static func drawn_figures(jobs: Array[Dictionary], cache_dir: String) -> Dictionary:
	var drawn: Dictionary = {}
	for job: Dictionary in jobs:
		var key: String = str(job.get("hash", ""))
		if FileAccess.file_exists("%s/%s" % [cache_dir.trim_suffix("/"), figure_file(key)]):
			drawn[key] = true
	return drawn


## Where drawn figures live between exports. Outside the project on purpose: they are derived from
## the guides, they are large, and a repository should not have to carry a picture of every fence.
static func figures_cache_dir() -> String:
	return "user://eventsheet_docs_site/figures"


static func _write(root: String, relative: String, text: String, written: PackedStringArray) -> void:
	var file: FileAccess = FileAccess.open("%s/%s" % [root, relative], FileAccess.WRITE)
	if file == null:
		return
	file.store_string(text)
	written.append(relative)


static func _copy(from: String, to: String, written: PackedStringArray, relative: String) -> void:
	if DirAccess.copy_absolute(from, to) == OK:
		written.append(relative)


## Everything a previous export of THIS site left behind, removed. Only the shapes this exporter
## writes are touched, so a reader who dropped their own file in the folder keeps it.
static func _clear_site(root: String) -> void:
	for entry: Array in [[root, ["html", "css", "js"]], ["%s/%s" % [root, PAGES_DIR], ["html"]],
			["%s/%s" % [root, FIGURES_DIR], ["png"]]]:
		var directory: String = str(entry[0])
		if not DirAccess.dir_exists_absolute(directory):
			continue
		var names: PackedStringArray = DirAccess.get_files_at(directory)
		names.sort()
		for file_name: String in names:
			if (entry[1] as Array).has(file_name.get_extension().to_lower()):
				DirAccess.remove_absolute("%s/%s" % [directory, file_name])
