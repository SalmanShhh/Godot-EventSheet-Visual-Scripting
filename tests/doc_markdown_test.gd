# EventSheets - the guide parser (Phase 3)
#
# The reader draws whatever this file returns, so every claim here is a VALUE, never a count: an
# anchor that resolves, a bracket that survives, a pipe line inside a fence that stays code.
#
# The three failures this test exists to catch, each measured against the real corpus:
#   - a slug rule that collapses runs of separators, which quietly breaks every anchor written
#     with " - " or " > " in its heading (and there are hundreds);
#   - BBCode eating square brackets, which deletes `arr[0]` and `[Deprecated]` from the page;
#   - a table detector that runs inside a fenced block, which turns this repo's pipe-delimited
#     console output into a mangled table.
@tool
class_name DocMarkdownTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_slugs() and all_passed
	all_passed = _test_inline() and all_passed
	all_passed = _test_blocks() and all_passed
	all_passed = _test_tables() and all_passed
	all_passed = _test_links() and all_passed
	return all_passed


## The anchor rule, pinned on the two headings that break every naive implementation: separators
## are NOT collapsed, and an underscore is not a separator at all.
static func _test_slugs() -> bool:
	var all_passed: bool = true
	all_passed = _check("separator runs are kept, one character each",
		EventSheetDocMarkdown.slug("3. How it runs - File > Run, editor vs game"),
		"3-how-it-runs---file--run-editor-vs-game") and all_passed
	all_passed = _check("an underscore survives",
		EventSheetDocMarkdown.slug("8. The codegen_template language"),
		"8-the-codegen_template-language") and all_passed
	all_passed = _check("backticks and asterisks are dropped, not replaced",
		EventSheetDocMarkdown.slug("The `EventSheets` **API**"), "the-eventsheets-api") and all_passed
	var used: Dictionary = {}
	all_passed = _check("the first heading takes the bare slug",
		EventSheetDocMarkdown.slug_in_page("Use cases", used), "use-cases") and all_passed
	all_passed = _check("a repeated heading takes -1",
		EventSheetDocMarkdown.slug_in_page("Use cases", used), "use-cases-1") and all_passed
	all_passed = _check("and then -2",
		EventSheetDocMarkdown.slug_in_page("Use cases", used), "use-cases-2") and all_passed
	return all_passed


static func _test_inline() -> bool:
	var all_passed: bool = true
	all_passed = _check("bold becomes a b tag", EventSheetDocMarkdown.inline_bbcode("**a**"), "[b]a[/b]") and all_passed
	all_passed = _check("italics become an i tag", EventSheetDocMarkdown.inline_bbcode("*a*"), "[i]a[/i]") and all_passed
	all_passed = _check("a literal open bracket is escaped",
		EventSheetDocMarkdown.inline_bbcode("["), "[lb]") and all_passed
	all_passed = _check("a subscript survives intact",
		EventSheetDocMarkdown.inline_bbcode("arr[0]"), "arr[lb]0[rb]") and all_passed
	all_passed = _check("an inline code span keeps its brackets escaped",
		EventSheetDocMarkdown.inline_bbcode("`arr[0]`"), "[code]arr[lb]0[rb][/code]") and all_passed
	all_passed = _check("a lone asterisk is not emphasis",
		EventSheetDocMarkdown.inline_bbcode("2 * 3"), "2 * 3") and all_passed
	all_passed = _check("an underscore is never emphasis (this vocabulary is snake_case)",
		EventSheetDocMarkdown.inline_bbcode("move_and_slide"), "move_and_slide") and all_passed
	all_passed = _check("markup comes off for a plain-text title",
		EventSheetDocMarkdown.plain_text("The `Quest` **pack**"), "The Quest pack") and all_passed
	# The trap the fixture above cannot see: it carries no underscore. This vocabulary is snake_case
	# from end to end, and a title pass that treats "_" as emphasis silently renames every heading
	# that names a symbol - in the tree, in the window title, in every search result.
	all_passed = _check("a snake_case heading keeps its underscores",
		EventSheetDocMarkdown.plain_text("8. The `codegen_template` Language"),
		"8. The codegen_template Language") and all_passed
	all_passed = _check("and so does an annotation name",
		EventSheetDocMarkdown.plain_text("`@ace_expose_all`: node-targeted in one line"),
		"@ace_expose_all: node-targeted in one line") and all_passed
	all_passed = _check("the styled form keeps them too",
		EventSheetDocMarkdown.inline_bbcode("`@ace_expose_all`"), "[code]@ace_expose_all[/code]") and all_passed

	# Entities: the guides escape angle brackets exactly where they are naming a UI string the
	# reader has to match on screen, and RichTextLabel decodes nothing.
	all_passed = _check("an escaped angle bracket is decoded",
		EventSheetDocMarkdown.inline_bbcode("Selected node: &lt;name&gt;"), "Selected node: <name>") and all_passed
	all_passed = _check("an ampersand is decoded once, not twice",
		EventSheetDocMarkdown.inline_bbcode("&amp;lt;"), "&lt;") and all_passed
	all_passed = _check("something that only looks like an entity is left alone",
		EventSheetDocMarkdown.inline_bbcode("Tom & Jerry; fine"), "Tom & Jerry; fine") and all_passed
	all_passed = _check("a plain-text title decodes them as well",
		EventSheetDocMarkdown.plain_text("**Selected node: &lt;name&gt;**"), "Selected node: <name>") and all_passed
	return all_passed


static func _test_blocks() -> bool:
	var all_passed: bool = true
	var source: String = "# Title\n\nSome **prose**.\n\n- one\n- two\n\n1. first\n2. second\n\n> a note\n\n---\n"
	var blocks: Array[Dictionary] = EventSheetDocMarkdown.parse(source, "FIXTURE")
	# Guarded before anything is indexed: a parser that emitted fewer blocks is precisely the
	# regression these rows exist to catch, and reading blocks[5] out of a shorter list crashes the
	# file - which prints no [FAIL] line at all and reads as a test that was never there.
	all_passed = _check("the fixture parses into its six blocks", blocks.size(), 6) and all_passed
	if blocks.size() < 6:
		return false
	all_passed = _check("the heading is a heading", str(blocks[0].get("kind", "")), "heading") and all_passed
	all_passed = _check("its level is read", int(blocks[0].get("level", 0)), 1) and all_passed
	all_passed = _check("its text is plain", str(blocks[0].get("text", "")), "Title") and all_passed
	all_passed = _check("its slug is recorded", str(blocks[0].get("slug", "")), "title") and all_passed
	all_passed = _check("prose is styled", str(blocks[1].get("bbcode", "")), "Some [b]prose[/b].") and all_passed
	all_passed = _check("a bullet list is unordered", bool(blocks[2].get("ordered", true)), false) and all_passed
	all_passed = _check("its second item is read",
		str((blocks[2].get("items", []) as Array)[1].get("bbcode", "")), "two") and all_passed
	all_passed = _check("a numbered list is ordered", bool(blocks[3].get("ordered", false)), true) and all_passed
	all_passed = _check("a quote is a quote", str(blocks[4].get("bbcode", "")), "a note") and all_passed
	all_passed = _check("a rule is a rule", str(blocks[5].get("kind", "")), "rule") and all_passed

	var fenced: String = "```gdscript\nvar a := 1\n```\n"
	var code: Array[Dictionary] = EventSheetDocMarkdown.parse(fenced, "FIXTURE")
	all_passed = _check("a fence is a code block", str(code[0].get("kind", "")), "code") and all_passed
	all_passed = _check("its language is kept", str(code[0].get("language", "")), "gdscript") and all_passed
	all_passed = _check("its body is verbatim, never BBCode",
		str((code[0].get("lines", []) as Array)[0]), "var a := 1") and all_passed

	var image: Array[Dictionary] = EventSheetDocMarkdown.parse("![the editor canvas](images/hero.png)\n", "FIXTURE")
	all_passed = _check("a standalone image is an image block", str(image[0].get("kind", "")), "image") and all_passed
	all_passed = _check("its alt text is kept for the card", str(image[0].get("alt", "")), "the editor canvas") and all_passed
	all_passed = _check("its path is kept", str(image[0].get("path", "")), "images/hero.png") and all_passed

	# The OTHER spelling. Six shipped guides write their pictures as raw HTML because they wanted a
	# width, and a parser that only knew the Markdown form printed the tag at the reader as prose.
	var html: Array[Dictionary] = EventSheetDocMarkdown.parse(
		"<img src=\"images/look-gallery.png\" alt=\"The Look Gallery: one tile per look.\" width=\"620\">\n", "FIXTURE")
	all_passed = _check("a raw img tag is an image block too", str(html[0].get("kind", "")), "image") and all_passed
	all_passed = _check("its src becomes the path", str(html[0].get("path", "")), "images/look-gallery.png") and all_passed
	all_passed = _check("its alt becomes the caption",
		str(html[0].get("alt", "")), "The Look Gallery: one tile per look.") and all_passed
	all_passed = _check("and it is never shown as literal markup",
		str(html[0].get("bbcode", "")).contains("<img"), false) and all_passed
	var no_source: Array[Dictionary] = EventSheetDocMarkdown.parse("<img alt=\"nothing to show\">\n", "FIXTURE")
	all_passed = _check("a tag with no src is not an image block",
		str(no_source[0].get("kind", "")), "paragraph") and all_passed
	all_passed = _check("an attribute is matched as a whole word",
		EventSheetDocMarkdown.html_attribute("<img data-src=\"decoy.png\" src=\"real.png\">", "src"), "real.png") and all_passed
	return all_passed


static func _test_tables() -> bool:
	var all_passed: bool = true
	var source: String = "| Verb | Ships as | Notes |\n|------|----------|-------|\n| Append | `arr.append(v)` | adds |\n| Clear | `arr.clear()` | empties |\n"
	var blocks: Array[Dictionary] = EventSheetDocMarkdown.parse(source, "FIXTURE")
	all_passed = _check("a pipe table is a table", str(blocks[0].get("kind", "")), "table") and all_passed
	var headers: Array = blocks[0].get("headers", []) as Array
	all_passed = _check("three columns are read", headers.size(), 3) and all_passed
	var rows: Array = blocks[0].get("rows", []) as Array
	all_passed = _check("two body rows are read", rows.size(), 2) and all_passed
	# Guarded before the cells are indexed, for the same reason the block list above is: a table
	# that came back with fewer columns is the regression, and crashing on it hides it.
	if headers.size() < 3 or rows.size() < 2 or (rows[0] as Array).size() < 2:
		return false
	all_passed = _check("the third header is read", str(headers[2]), "Notes") and all_passed
	all_passed = _check("a cell keeps its inline code",
		str((rows[0] as Array)[1]), "[code]arr.append(v)[/code]") and all_passed
	all_passed = _check("an escaped pipe stays inside its cell",
		str((EventSheetDocMarkdown.parse("| a | b |\n|---|---|\n| float \\| int | x |\n", "F")[0].get("rows", []) as Array)[0][0]),
		"float | int") and all_passed

	# The measured trap: this repo fences pipe-delimited console output, and a table detector that
	# runs inside a fence turns a printed report into a mangled table.
	var fenced: String = "```\ncommon | 59.70% | 60.00%\n-------|--------|-------\n```\n"
	var code: Array[Dictionary] = EventSheetDocMarkdown.parse(fenced, "FIXTURE")
	all_passed = _check("a pipe line inside a fence stays code", str(code[0].get("kind", "")), "code") and all_passed
	all_passed = _check("and keeps its pipes verbatim",
		str((code[0].get("lines", []) as Array)[0]), "common | 59.70% | 60.00%") and all_passed

	# A sentence carrying a pipe is not a table: without the separator-row check every guide grows
	# one-column tables out of its prose.
	var prose: Array[Dictionary] = EventSheetDocMarkdown.parse("Press Ctrl | Shift to pick.\n", "FIXTURE")
	all_passed = _check("a piped sentence stays prose", str(prose[0].get("kind", "")), "paragraph") and all_passed
	return all_passed


static func _test_links() -> bool:
	var all_passed: bool = true
	all_passed = _check("a doc link becomes a url tag carrying its raw target",
		EventSheetDocMarkdown.inline_bbcode("see [recipes](GUIDE-RECIPES.md)"),
		"see [url=GUIDE-RECIPES.md]recipes[/url]") and all_passed
	all_passed = _check("an in-page link keeps its slug",
		EventSheetDocMarkdown.inline_bbcode("[jump](#the-slug)"), "[url=#the-slug]jump[/url]") and all_passed
	all_passed = _check("a res:// path is text, never a link",
		EventSheetDocMarkdown.inline_bbcode("[the file](res://addons/eventsheet/editor/x.gd)"), "the file") and all_passed
	all_passed = _check("an inline image degrades to its alt text",
		EventSheetDocMarkdown.inline_bbcode("before ![a canvas](images/a.png) after"), "before a canvas after") and all_passed
	all_passed = _check("an anchor classifies as an anchor",
		str(EventSheetDocMarkdown.classify_link("#health").get("anchor", "")), "health") and all_passed
	all_passed = _check("a guide link classifies as a doc",
		str(EventSheetDocMarkdown.classify_link("Addons/Quest.md#setup").get("kind", "")), "doc") and all_passed
	all_passed = _check("its anchor is split off",
		str(EventSheetDocMarkdown.classify_link("Addons/Quest.md#setup").get("anchor", "")), "setup") and all_passed
	all_passed = _check("an absolute address classifies as a url",
		str(EventSheetDocMarkdown.classify_link("https://godotengine.org").get("kind", "")), "url") and all_passed
	all_passed = _check("a res:// target classifies as a plain path",
		str(EventSheetDocMarkdown.classify_link("res://project.godot").get("kind", "")), "path") and all_passed
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] doc_markdown_test: %s" % label)
		return true
	print("[FAIL] doc_markdown_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
