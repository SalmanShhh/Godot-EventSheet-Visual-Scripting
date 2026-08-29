# EventForge - the exported site: the same bundle in produces the same bytes out.
#
# THE ONE THAT MATTERS is _test_same_bytes_twice. An exported site is committed and read in pull
# requests, so a folder that rewrote itself on every run would be unreviewable - and every way of
# losing that is invisible until somebody diffs two exports: a timestamp in a header, a Dictionary
# walked in insertion order, a counter that depends on what was open. This exports the same pages
# twice into two folders and compares every byte.
#
# Everything else here pins the translation from a parsed page to HTML: the closed BBCode tag set,
# the links that survive the trip and the ones that must not, the figure jobs, and the credit that
# rides with engine text.
@tool
class_name DocSiteTest
extends RefCounted

## Where the test writes. Under user:// because a test that wrote into res:// would leave a folder
## in somebody's checkout, and cleared at both ends so a re-run starts cold.
const WORK_ROOT := "user://eventsheet_test_site"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_escaping() and all_passed
	all_passed = _test_bbcode() and all_passed
	all_passed = _test_links() and all_passed
	all_passed = _test_page_files() and all_passed
	all_passed = _test_blocks() and all_passed
	all_passed = _test_figure_jobs() and all_passed
	all_passed = _test_engine_credit() and all_passed
	all_passed = _test_search_data() and all_passed
	all_passed = _test_same_bytes_twice() and all_passed
	_clear(WORK_ROOT)
	return all_passed


static func _test_escaping() -> bool:
	var passed: bool = _check("the five characters a browser would read as markup are escaped",
		EventSheetDocSiteExport.escape_html("<a href=\"x\">&'"),
		"&lt;a href=&quot;x&quot;&gt;&amp;&#39;")
	passed = _check("prose with none of them is untouched",
		EventSheetDocSiteExport.escape_html("plain words"), "plain words") and passed
	return passed


static func _test_bbcode() -> bool:
	var passed: bool = _check("bold, italic and code become their tags",
		EventSheetDocSiteExport.bbcode_to_html("[b]a[/b] [i]b[/i] [code]c[/code]"),
		"<strong>a</strong> <em>b</em> <code>c</code>")
	passed = _check("the parser's bracket escapes come back as brackets",
		EventSheetDocSiteExport.bbcode_to_html("arr[lb]0[rb]"), "arr[0]") and passed
	passed = _check("a tag this exporter does not know is shown as the text it is",
		EventSheetDocSiteExport.bbcode_to_html("[color=red]x[/color]"),
		"[color=red]x[/color]") and passed
	passed = _check("text inside a tag is still escaped",
		EventSheetDocSiteExport.bbcode_to_html("[b]a<b[/b]"), "<strong>a&lt;b</strong>") and passed
	return passed


static func _test_links() -> bool:
	var context: Dictionary = {"page_id": "GUIDE-RECIPES", "depth": 1,
		"exported": {"REFERENCE-GLOSSARY": true}}
	var passed: bool = _check("a web address is kept as it was written",
		EventSheetDocSiteExport.site_href("https://godotengine.org", context),
		"https://godotengine.org")
	passed = _check("an in-page jump stays an anchor",
		EventSheetDocSiteExport.site_href("#the-golden-loop", context), "#the-golden-loop") and passed
	passed = _check("a link to another guide becomes that guide's file",
		EventSheetDocSiteExport.site_href("REFERENCE-GLOSSARY.md", context),
		"REFERENCE-GLOSSARY.html") and passed
	passed = _check("with its anchor kept",
		EventSheetDocSiteExport.site_href("REFERENCE-GLOSSARY.md#picking", context),
		"REFERENCE-GLOSSARY.html#picking") and passed
	passed = _check("a link to a page the export does not contain is refused",
		EventSheetDocSiteExport.site_href("GUIDE-THEMING.md", context), "") and passed
	passed = _check("and is drawn as its own words rather than as a door onto nothing",
		EventSheetDocSiteExport.bbcode_to_html("[url=GUIDE-THEMING.md]theming[/url]", context),
		"<span>theming</span>") and passed
	passed = _check("a link that survives is a real anchor",
		EventSheetDocSiteExport.bbcode_to_html("[url=REFERENCE-GLOSSARY.md]words[/url]", context),
		"<a href=\"REFERENCE-GLOSSARY.html\">words</a>") and passed
	return passed


static func _test_page_files() -> bool:
	var passed: bool = _check("a plain page is its own file",
		EventSheetDocSiteExport.page_file("GUIDE-RECIPES"), "GUIDE-RECIPES.html")
	passed = _check("a page in a set folds its slash rather than making a folder",
		EventSheetDocSiteExport.page_file("Addons/Quest"), "Addons__Quest.html") and passed
	return passed


static func _test_blocks() -> bool:
	var blocks: Array[Dictionary] = EventSheetDocMarkdown.parse(
		"# Title\n\nA line.\n\n- one\n- two\n\n| A | B |\n| --- | --- |\n| 1 | 2 |\n\n> a note\n",
		"Fixture")
	var html: String = EventSheetDocSiteExport.blocks_html(blocks, {"depth": 1})
	var passed: bool = _check("the heading carries the same slug the editor anchors on",
		html.contains("<h1 id=\"title\">Title</h1>"), true)
	passed = _check("prose is a paragraph", html.contains("<p>A line.</p>"), true) and passed
	passed = _check("a bullet list is a list", html.contains("<li class=\"indent-0\">one</li>"),
		true) and passed
	passed = _check("a pipe table is a table", html.contains("<th>A</th>"), true) and passed
	passed = _check("a quote is a quote", html.contains("<blockquote>a note</blockquote>"),
		true) and passed
	return passed


static func _test_figure_jobs() -> bool:
	var body: String = "extends Node\n\n\nfunc _ready() -> void:\n\tprint(\"hi\")\n"
	var page: Dictionary = {"id": "Fixture", "title": "Fixture", "source":
		"# Fixture\n\n```eventsheet\n%s```\n\n```eventsheet\n%s```\n" % [body, body],
		"blocks": []}
	var jobs: Array[Dictionary] = EventSheetDocSiteExport.figure_jobs([page])
	var passed: bool = _check("one fence quoted twice is one job", jobs.size(), 1)
	if jobs.size() == 1:
		passed = _check("filed under the hash of the fence body",
			str(jobs[0].get("hash", "")), body.sha256_text()) and passed
		passed = _check("which is the name its picture is cached under",
			EventSheetDocSiteExport.figure_file(str(jobs[0].get("hash", ""))),
			"%s.png" % body.sha256_text()) and passed
	passed = _check("a fence with no picture yet is exported as its code",
		EventSheetDocSiteExport.blocks_html(
			EventSheetDocMarkdown.parse(str(page["source"]), "Fixture"), {"figures": {}}).contains("<pre><code>"),
		true) and passed
	passed = _check("and as a picture once one is cached",
		EventSheetDocSiteExport.blocks_html(
			EventSheetDocMarkdown.parse(str(page["source"]), "Fixture"),
			{"figures": {body.sha256_text(): true}, "depth": 1}).contains(
				"<img src=\"../figures/%s.png\"" % body.sha256_text()), true) and passed
	return passed


## Engine text carries its attribution wherever it goes. Pinned on a page built the way the exporter
## builds one, rather than on a harvest that may not be on this machine.
static func _test_engine_credit() -> bool:
	var page: Dictionary = {"id": "Engine/Timer", "title": "Timer", "engine": true,
		"source": "# Timer\n\nCounts down.\n", "blocks": []}
	var html: String = EventSheetDocSiteExport.page_html(page, {"engine_credit": true, "depth": 1})
	var passed: bool = _check("the page carries the engine's own credit",
		html.count(EventSheetDocEngineReference.CREDIT_LINE) >= 1, true)
	var plain: String = EventSheetDocSiteExport.page_html(
		{"id": "GUIDE-RECIPES", "title": "R", "source": "# R\n", "blocks": []}, {"depth": 1})
	passed = _check("a page with no engine text and no engine pages beside it does not",
		plain.contains(EventSheetDocEngineReference.CREDIT_LINE), false) and passed
	return passed


static func _test_search_data() -> bool:
	var page: Dictionary = {"id": "Fixture", "title": "Grapple Hook",
		"source": "# Grapple Hook\n\n## Swinging\n\nSwing from anything.\n", "blocks": []}
	var script_text: String = EventSheetDocSiteExport.search_data_js([page])
	var passed: bool = _check("the data is one assignment the page can read",
		script_text.begins_with("window.EVENTSHEET_DOCS = ["), true)
	var payload: Variant = JSON.parse_string(script_text.substr(
		"window.EVENTSHEET_DOCS = ".length()).trim_suffix(";\n"))
	var rows: Array = payload as Array if payload is Array else []
	passed = _check("one row per exported page", rows.size(), 1) and passed
	if rows.size() == 1:
		var row: Dictionary = rows[0] as Dictionary
		passed = _check("carrying the file the site will open",
			str(row.get("file", "")), "Fixture.html") and passed
		passed = _check("its headings, for the ranking the editor uses",
			str(((row.get("headings", []) as Array)[0] as Dictionary).get("text", "")),
			"Swinging") and passed
		passed = _check("and the page's words, so a body match is possible",
			str(row.get("words", "")).contains(" swing "), true) and passed
	return passed


## The law. Two exports of the same pages, into two folders, byte for byte.
static func _test_same_bytes_twice() -> bool:
	_clear(WORK_ROOT)
	var ids: PackedStringArray = PackedStringArray()
	for id: String in EventSheetDocLibrary.page_ids():
		ids.append(id)
		if ids.size() >= 6:
			break
	if ids.is_empty():
		# No bundle in this checkout: the law is untestable rather than broken, and saying so is
		# better than passing for the wrong reason.
		print("[doc_site] no help bundle installed - byte identity not exercised")
		return true
	var options: Dictionary = {"page_ids": Array(ids), "scan_project": false,
		"figures_dir": "%s/figures" % WORK_ROOT}
	var first: Dictionary = EventSheetDocSiteExport.export_site("%s/a" % WORK_ROOT, options)
	var second: Dictionary = EventSheetDocSiteExport.export_site("%s/b" % WORK_ROOT, options)
	var passed: bool = _check("both exports wrote the same page count",
		int(first.get("pages", 0)), int(second.get("pages", 0)))
	var differing: PackedStringArray = PackedStringArray()
	for relative: String in (first.get("files", PackedStringArray()) as PackedStringArray):
		if _read("%s/a/%s" % [WORK_ROOT, relative]) != _read("%s/b/%s" % [WORK_ROOT, relative]):
			differing.append(relative)
	passed = _check("every exported file is byte-identical to the other export's",
		", ".join(differing), "") and passed
	# And the folder holds nothing the export did not write: a page deleted from the corpus has to
	# disappear from the site, which only works because the export clears what it owns first.
	_write("%s/a/pages/GHOST.html" % WORK_ROOT, "left over")
	EventSheetDocSiteExport.export_site("%s/a" % WORK_ROOT, options)
	passed = _check("a page that is no longer in the corpus is cleared out",
		FileAccess.file_exists("%s/a/pages/GHOST.html" % WORK_ROOT), false) and passed
	return passed


static func _read(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()


static func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)


## Removes a folder and everything under it, so this test starts and finishes cold. CI runs the
## suite serially in one process, and a folder left behind is a second run's silent input.
static func _clear(root: String) -> void:
	if not DirAccess.dir_exists_absolute(root):
		return
	var names: PackedStringArray = DirAccess.get_directories_at(root)
	names.sort()
	for directory: String in names:
		_clear("%s/%s" % [root, directory])
	var files: PackedStringArray = DirAccess.get_files_at(root)
	files.sort()
	for file_name: String in files:
		DirAccess.remove_absolute("%s/%s" % [root, file_name])
	DirAccess.remove_absolute(root)


static func _check(label: String, got: Variant, expected: Variant) -> bool:
	if got == expected:
		return true
	print("[FAIL] %s: expected %s, got %s" % [label, expected, got])
	return false
