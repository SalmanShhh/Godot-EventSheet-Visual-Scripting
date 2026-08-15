# EventSheet - EventSheetDocMarkdown: the shipped guides, parsed into page blocks.
#
# STATIC and PURE: Markdown text in, an Array of block Dictionaries out. It touches no Control,
# no file and no engine singleton, so the whole parse is pinned headlessly by the suite while the
# drawing half (doc_page_view.gd) is proved by a rendered image.
#
# It parses exactly the Markdown this repo's guides are written in - headings, paragraphs, bullet
# and numbered lists, pipe tables, fenced code, block quotes, rules, images - and nothing more.
# An unsupported construct degrades to the prose it is made of rather than to a parser error.
#
# BLOCK KINDS (each Dictionary carries "kind"):
#   heading    level, text, bbcode, slug     text is PLAIN (titles, trees); bbcode is styled
#   paragraph  bbcode
#   list       ordered, items:[{bbcode, indent}]
#   table      headers:[bbcode], rows:[[bbcode]]
#   code       language, lines:[String]      never BBCode - a code card draws it verbatim
#              caption, no_figure            the FIGURE markers a fence carries (see below)
#   quote      bbcode
#   image      path, alt                     images do not ship; the page draws an alt-text card
#   rule                                     a horizontal divider
#
# THE FIGURE MARKERS, and why there are exactly three of them. A fenced block can be drawn as a
# LIVE figure - the real renderer showing the rows that code lifts to - and which fences those are
# is decided by a recognizer (doc_figures.gd), not here. This file only carries what an AUTHOR
# wrote down, and an author has exactly three things to say:
#
#   ```eventsheet          this fence IS a figure, whatever a detector thinks
#   <!-- no-figure -->     the fence directly below stays a code card, forever
#   <!-- caption: … -->    the line of prose above the figure (otherwise: the nearest heading)
#
# The grammar is deliberately tiny because it is frozen: every one of these is a promise to every
# guide already written with it. Anything richer (highlight a row, hide the trigger, size hints)
# arrives later as an ADDITIVE marker, never as a change to these three. A marker comment is
# CONSUMED - it never reaches the page as prose - and it applies to the next fence only.
#
# TWO TRAPS THIS FILE EXISTS TO AVOID:
#   1. BBCode eats square brackets. Every literal `[` and `]` in prose is escaped to [lb] / [rb]
#      BEFORE any tag is inserted, or `arr[0]` silently loses its subscript and `[Deprecated]`
#      vanishes entirely.
#   2. A fenced block is not prose. Console output in this corpus is pipe-delimited, so a table
#      detector that runs inside a fence turns a printed report into a mangled table.
@tool
class_name EventSheetDocMarkdown
extends RefCounted


## Parses a whole guide. `doc_id` is carried only so a caller can keep the blocks with their page;
## the parse itself never depends on it.
static func parse(text: String, doc_id: String = "") -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	var lines: PackedStringArray = text.replace("\r\n", "\n").split("\n")
	var used_slugs: Dictionary = {}
	# What an author wrote about the NEXT fence, and the heading a caption falls back to.
	var pending: Dictionary = {"caption": "", "no_figure": false}
	var last_heading: String = ""
	var index: int = 0
	while index < lines.size():
		var line: String = lines[index]
		var stripped: String = line.strip_edges()
		if stripped.is_empty():
			index += 1
			continue
		var marker: Dictionary = figure_marker(stripped)
		if not marker.is_empty():
			if bool(marker.get("no_figure", false)):
				pending["no_figure"] = true
			if marker.has("caption"):
				pending["caption"] = str(marker["caption"])
			index += 1
			continue
		var fence: int = _fence_length(stripped)
		if fence > 0:
			if str(pending["caption"]).is_empty():
				# ONCE per heading. A section like "## Use cases" carrying eight worked examples
				# would otherwise stamp the same line above all eight, which is noise rather than a
				# caption; the second figure onward says nothing until an author captions it.
				pending["caption"] = last_heading
				last_heading = ""
			index = _read_fence(lines, index, fence, blocks, pending)
			pending = {"caption": "", "no_figure": false}
			continue
		if stripped.begins_with("#"):
			var heading: Dictionary = _heading_block(stripped, used_slugs)
			if not heading.is_empty():
				blocks.append(heading)
				last_heading = str(heading.get("text", ""))
				index += 1
				continue
		if _is_rule(stripped):
			blocks.append({"kind": "rule"})
			index += 1
			continue
		if stripped.begins_with(">"):
			index = _read_quote(lines, index, blocks)
			continue
		if _list_marker(stripped) != "":
			index = _read_list(lines, index, blocks)
			continue
		if _is_table_start(lines, index):
			index = _read_table(lines, index, blocks)
			continue
		index = _read_paragraph(lines, index, blocks)
	return blocks


## The GitHub heading slug an in-page anchor resolves against. Measured over the whole shipped
## corpus, this rule resolves every anchor in it. The load-bearing step is that spaces are NOT
## collapsed: "3. How it runs - File > Run" leaves three characters where " - " was, and two where
## " > " was, which is exactly what GitHub does. Underscores are kept, or every anchor naming a
## snake_case symbol breaks.
static func slug(heading_text: String) -> String:
	var text: String = heading_text.strip_edges().to_lower()
	text = text.replace("`", "").replace("*", "")
	var out: String = ""
	for index: int in range(text.length()):
		var character: String = text[index]
		if character == " ":
			out += "-"
		elif character == "_" or character == "-":
			out += character
		elif (character >= "a" and character <= "z") or (character >= "0" and character <= "9"):
			out += character
	return out


## The slug a heading gets INSIDE a page, where a repeated heading text takes "-1", "-2", ... in
## document order, the way GitHub disambiguates duplicates. `used` is the per-page tally.
static func slug_in_page(heading_text: String, used: Dictionary) -> String:
	var base: String = slug(heading_text)
	if base.is_empty():
		return ""
	var seen: int = int(used.get(base, 0))
	used[base] = seen + 1
	return base if seen == 0 else "%s-%d" % [base, seen]


## Inline Markdown to BBCode: code spans, bold, italics, links and images, with every literal
## bracket escaped as it goes. A link to a `res://` path becomes plain TEXT: the reader cannot
## open a project path from a doc page, and a dead link is worse than a plain filename.
## Entities are decoded ONCE, here, and never again on the way down: the nested calls below run on
## text this pass already decoded, so a literal "&amp;lt;" in a guide stays "&lt;" instead of
## being decoded twice into a bracket the author never wrote.
static func inline_bbcode(text: String) -> String:
	return _inline(decode_entities(text))


static func _inline(text: String) -> String:
	if not _has_markup(text):
		return text
	var out: String = ""
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if character == "\\" and index + 1 < text.length():
			out += escape_brackets(text[index + 1])
			index += 2
			continue
		if character == "`":
			var span: Dictionary = _read_code_span(text, index)
			if not span.is_empty():
				out += "[code]%s[/code]" % escape_brackets(str(span["text"]))
				index = int(span["next"])
				continue
		if character == "!" and index + 1 < text.length() and text[index + 1] == "[":
			var image: Dictionary = _read_link(text, index + 1)
			if not image.is_empty():
				# An inline image inside a sentence degrades to its alt text - images do not ship,
				# and the page's own image blocks carry the "open it online" affordance.
				out += _inline(str(image["label"]))
				index = int(image["next"])
				continue
		if character == "[":
			var link: Dictionary = _read_link(text, index)
			if not link.is_empty():
				var target: String = str(link["target"])
				var label: String = _inline(str(link["label"]))
				out += label if target.begins_with("res://") else "[url=%s]%s[/url]" % [target, label]
				index = int(link["next"])
				continue
		if text.substr(index, 2) == "**":
			var bold: Dictionary = _read_delimited(text, index, "**")
			if not bold.is_empty():
				out += "[b]%s[/b]" % _inline(str(bold["text"]))
				index = int(bold["next"])
				continue
		if character == "*":
			var italic: Dictionary = _read_delimited(text, index, "*")
			if not italic.is_empty():
				out += "[i]%s[/i]" % _inline(str(italic["text"]))
				index = int(italic["next"])
				continue
		out += escape_brackets(character)
		index += 1
	return out


## The one escape every piece of authored prose goes through before a tag is added to it. Written
## as a single pass on purpose: two chained replace() calls turn "[" into "[lb]" and then eat that
## replacement's own closing bracket, so `arr[0]` comes out as `arr[lb[rb]0[rb]`.
static func escape_brackets(text: String) -> String:
	if not text.contains("[") and not text.contains("]"):
		return text
	var out: String = ""
	for index: int in range(text.length()):
		var character: String = text[index]
		if character == "[":
			out += "[lb]"
		elif character == "]":
			out += "[rb]"
		else:
			out += character
	return out


## The HTML entities this corpus writes, decoded to the characters they stand for. A page that
## skipped this shows `&lt;name&gt;` where GitHub shows `<name>` - and the guides use the escaped
## form precisely where they are naming a UI string the reader has to match on screen.
##
## One pass, longest first, and `&amp;` decoded in the SAME pass rather than after the others, so
## an author who wrote `&amp;lt;` gets `&lt;` back instead of a bracket they never typed.
const ENTITIES := {
	"&lt;": "<", "&gt;": ">", "&quot;": "\"", "&apos;": "'", "&nbsp;": " ",
	"&#39;": "'", "&mdash;": " - ", "&ndash;": "-", "&hellip;": "…", "&amp;": "&",
}


static func decode_entities(text: String) -> String:
	if not text.contains("&"):
		return text
	var out: String = ""
	var index: int = 0
	while index < text.length():
		if text[index] != "&":
			out += text[index]
			index += 1
			continue
		var semicolon: int = text.find(";", index)
		var entity: String = "" if semicolon < 0 else text.substr(index, semicolon - index + 1)
		if entity.is_empty() or not ENTITIES.has(entity):
			out += text[index]
			index += 1
			continue
		out += str(ENTITIES[entity])
		index = semicolon + 1
	return out


## Whether a run of text carries anything the inline scanner would rewrite. Most prose does not,
## and a whole-corpus parse is a hot enough path that answering this first is worth the check.
static func _has_markup(text: String) -> bool:
	for marker: String in ["[", "]", "*", "`", "\\", "!"]:
		if text.contains(marker):
			return true
	return false


## The link targets a page can carry, as {kind, target, anchor}:
##   "anchor"    an in-page jump ("#slug")
##   "doc"       another guide, plus an optional anchor - the raw relative path, for the library
##               to turn into a doc id against the page it was written in
##   "url"       an absolute http(s) address for the browser
##   "path"      anything else (a res:// path, a source file): text, never a link
static func classify_link(target: String) -> Dictionary:
	var value: String = target.strip_edges()
	if value.begins_with("#"):
		return {"kind": "anchor", "target": "", "anchor": value.substr(1)}
	if value.begins_with("http://") or value.begins_with("https://"):
		return {"kind": "url", "target": value, "anchor": ""}
	if value.begins_with("res://") or value.begins_with("mailto:"):
		return {"kind": "path", "target": value, "anchor": ""}
	var anchor: String = ""
	var hash_index: int = value.find("#")
	if hash_index >= 0:
		anchor = value.substr(hash_index + 1)
		value = value.substr(0, hash_index)
	if value.to_lower().ends_with(".md"):
		return {"kind": "doc", "target": value, "anchor": anchor}
	return {"kind": "path", "target": value, "anchor": anchor}


# ── Block readers ─────────────────────────────────────────────────────────────────────────────


## The length of the backtick or tilde run that opens a fence, or 0 when the line opens none.
## Measured rather than assumed to be three: this repo's own docs nest a ```` ```` ```` fence
## around a fence, and a three-backtick closer inside one must not end the outer block.
static func _fence_length(stripped: String) -> int:
	var marker: String = stripped.substr(0, 1)
	if marker != "`" and marker != "~":
		return 0
	var length: int = 0
	while length < stripped.length() and stripped[length] == marker:
		length += 1
	return length if length >= 3 else 0


static func _read_fence(lines: PackedStringArray, start: int, fence: int, blocks: Array[Dictionary], markers: Dictionary = {}) -> int:
	var opener: String = lines[start].strip_edges()
	var language: String = opener.substr(fence).strip_edges()
	var body: Array[String] = []
	var index: int = start + 1
	while index < lines.size():
		var stripped: String = lines[index].strip_edges()
		var closing: int = _fence_length(stripped)
		if closing >= fence and stripped.substr(closing).strip_edges().is_empty():
			index += 1
			break
		body.append(lines[index])
		index += 1
	blocks.append({
		"kind": "code",
		"language": language,
		"lines": body,
		"caption": str(markers.get("caption", "")),
		"no_figure": bool(markers.get("no_figure", false)),
		"line": start + 1,
	})
	return index


## What a marker comment says about the fence below it, or an empty Dictionary for any other line
## (an ordinary HTML comment stays the prose it is). Two shapes, and only two:
##   {"no_figure": true}        <!-- no-figure -->
##   {"caption": "…"}           <!-- caption: Appending to a list -->
## Matching is done on the WHOLE line so a sentence that merely mentions the marker is not one.
static func figure_marker(stripped_line: String) -> Dictionary:
	var line: String = stripped_line.strip_edges()
	if not line.begins_with("<!--") or not line.ends_with("-->"):
		return {}
	var inner: String = line.substr(4, line.length() - 7).strip_edges()
	if inner.to_lower() == "no-figure":
		return {"no_figure": true}
	if inner.to_lower().begins_with("caption:"):
		return {"caption": inner.substr("caption:".length()).strip_edges()}
	return {}


static func _heading_block(stripped: String, used_slugs: Dictionary) -> Dictionary:
	var level: int = 0
	while level < stripped.length() and stripped[level] == "#":
		level += 1
	if level > 6 or level >= stripped.length() or stripped[level] != " ":
		return {}
	var text: String = stripped.substr(level + 1).strip_edges()
	return {
		"kind": "heading",
		"level": level,
		"text": plain_text(text),
		"bbcode": inline_bbcode(text),
		"slug": slug_in_page(text, used_slugs),
	}


## A heading or a caption with its markup taken off, for a tree label or a window title, where a
## BBCode tag would be shown literally.
##
## An UNDERSCORE is not markup here, and that is load-bearing: this vocabulary is snake_case, so a
## heading naming `codegen_template` or `@ace_expose_all` must come back spelled the way the reader
## will search for it. The inline emitter treats `_` as a literal for the same reason, and a title
## that disagreed with the prose under it would be a rename nobody made.
static func plain_text(raw_text: String) -> String:
	var text: String = decode_entities(raw_text)
	var out: String = ""
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if character == "\\" and index + 1 < text.length():
			out += text[index + 1]
			index += 2
			continue
		if character == "`" or character == "*":
			index += 1
			continue
		if character == "[":
			var link: Dictionary = _read_link(text, index)
			if not link.is_empty():
				out += plain_text(str(link["label"]))
				index = int(link["next"])
				continue
		out += character
		index += 1
	return out


static func _is_rule(stripped: String) -> bool:
	if stripped.length() < 3:
		return false
	var marker: String = stripped.substr(0, 1)
	if marker != "-" and marker != "*" and marker != "_":
		return false
	return stripped.replace(marker, "").strip_edges().is_empty()


## The bullet or number that starts a list item, or "" when the line starts none. A line whose
## dash is a rule, or whose "1." is the start of a sentence, is not a list item.
static func _list_marker(stripped: String) -> String:
	if stripped.length() >= 2 and stripped[1] == " ":
		var bullet: String = stripped.substr(0, 1)
		if bullet == "-" or bullet == "*" or bullet == "+":
			return bullet
	var digits: int = 0
	while digits < stripped.length() and stripped[digits] >= "0" and stripped[digits] <= "9":
		digits += 1
	if digits > 0 and digits + 1 < stripped.length() and stripped[digits] == "." and stripped[digits + 1] == " ":
		return stripped.substr(0, digits + 1)
	return ""


static func _read_list(lines: PackedStringArray, start: int, blocks: Array[Dictionary]) -> int:
	var first: String = lines[start].strip_edges()
	var ordered: bool = not ["-", "*", "+"].has(_list_marker(first))
	var items: Array[Dictionary] = []
	var index: int = start
	while index < lines.size():
		var line: String = lines[index]
		var stripped: String = line.strip_edges()
		if stripped.is_empty():
			break
		var marker: String = _list_marker(stripped)
		if marker == "":
			# A wrapped continuation line belongs to the item above it.
			if items.is_empty() or _fence_length(stripped) > 0 or stripped.begins_with("#"):
				break
			var previous: Dictionary = items[items.size() - 1]
			previous["bbcode"] = "%s %s" % [str(previous["bbcode"]), inline_bbcode(stripped)]
			index += 1
			continue
		var indent: int = line.length() - line.lstrip(" \t").length()
		items.append({
			"bbcode": inline_bbcode(stripped.substr(marker.length()).strip_edges()),
			"indent": int(indent / 2),
		})
		index += 1
	blocks.append({"kind": "list", "ordered": ordered, "items": items})
	return index


static func _read_quote(lines: PackedStringArray, start: int, blocks: Array[Dictionary]) -> int:
	var parts: PackedStringArray = PackedStringArray()
	var index: int = start
	while index < lines.size():
		var stripped: String = lines[index].strip_edges()
		if not stripped.begins_with(">"):
			break
		parts.append(stripped.substr(1).strip_edges())
		index += 1
	blocks.append({"kind": "quote", "bbcode": inline_bbcode(" ".join(parts).strip_edges())})
	return index


## A pipe table is only a table when a separator row follows its header row. Without that check a
## sentence carrying a pipe becomes a one-column table, and every guide has such sentences.
static func _is_table_start(lines: PackedStringArray, index: int) -> bool:
	if not lines[index].contains("|") or index + 1 >= lines.size():
		return false
	var separator: String = lines[index + 1].strip_edges()
	if not separator.contains("-") or not separator.contains("|"):
		return false
	for character: String in separator:
		if not (character == "-" or character == "|" or character == ":" or character == " "):
			return false
	return true


static func _read_table(lines: PackedStringArray, start: int, blocks: Array[Dictionary]) -> int:
	var headers: Array[String] = _table_cells(lines[start])
	var rows: Array = []
	var index: int = start + 2
	while index < lines.size():
		var stripped: String = lines[index].strip_edges()
		if stripped.is_empty() or not stripped.contains("|"):
			break
		rows.append(_table_cells(lines[index]))
		index += 1
	blocks.append({"kind": "table", "headers": headers, "rows": rows})
	return index


## One row's cells. A pipe escaped as `\|` stays inside its cell, which is how this corpus writes
## an "or" in a table (`float \| int`).
static func _table_cells(line: String) -> Array[String]:
	var cells: Array[String] = []
	var current: String = ""
	var text: String = line.strip_edges().trim_prefix("|").trim_suffix("|")
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if character == "\\" and index + 1 < text.length() and text[index + 1] == "|":
			current += "|"
			index += 2
			continue
		if character == "|":
			cells.append(inline_bbcode(current.strip_edges()))
			current = ""
			index += 1
			continue
		current += character
		index += 1
	cells.append(inline_bbcode(current.strip_edges()))
	return cells


static func _read_paragraph(lines: PackedStringArray, start: int, blocks: Array[Dictionary]) -> int:
	var parts: PackedStringArray = PackedStringArray()
	var index: int = start
	while index < lines.size():
		var stripped: String = lines[index].strip_edges()
		if stripped.is_empty() or stripped.begins_with("#") or stripped.begins_with(">"):
			break
		if _fence_length(stripped) > 0 or _is_rule(stripped) or _list_marker(stripped) != "":
			break
		if index > start and _is_table_start(lines, index):
			break
		parts.append(stripped)
		index += 1
	var text: String = " ".join(parts).strip_edges()
	var image: Dictionary = _standalone_image(text)
	if not image.is_empty():
		blocks.append(image)
	elif not text.is_empty():
		blocks.append({"kind": "paragraph", "bbcode": inline_bbcode(text)})
	return maxi(index, start + 1)


## A paragraph that is nothing but an image becomes an image block (the page draws its alt text as
## a card with an "open it online" button). An image inside a sentence stays inline.
##
## BOTH spellings are read. Markdown is what most of the corpus uses, but a guide that wanted a
## width writes the raw `<img src=… alt=… width=…>` HTML that GitHub renders - and a parser that
## only knew the Markdown form printed that tag at the reader as literal text, on the pages whose
## pictures matter most.
static func _standalone_image(text: String) -> Dictionary:
	if text.begins_with("<img") and text.ends_with(">"):
		return _html_image(text)
	if not text.begins_with("!["):
		return {}
	var link: Dictionary = _read_link(text, 1)
	if link.is_empty() or int(link["next"]) != text.length():
		return {}
	return {"kind": "image", "path": str(link["target"]), "alt": plain_text(str(link["label"]))}


## An `<img>` tag as an image block. Only src and alt are read - width and every other attribute
## describe a layout this page does not have, and the picture itself opens online.
static func _html_image(tag: String) -> Dictionary:
	var source: String = html_attribute(tag, "src")
	if source.is_empty():
		return {}
	return {"kind": "image", "path": source, "alt": plain_text(html_attribute(tag, "alt"))}


## One attribute of an HTML tag, in either quoting style, or "" when the tag does not carry it.
static func html_attribute(tag: String, attribute: String) -> String:
	var needle: String = "%s=" % attribute
	var at: int = tag.find(needle)
	while at > 0:
		# " src=" and not "…-src=": the character before the name has to be a separator, or an
		# attribute merely ENDING in the wanted name would answer for it.
		if tag[at - 1] == " " or tag[at - 1] == "\t":
			var quote: String = tag.substr(at + needle.length(), 1)
			if quote == "\"" or quote == "'":
				var end: int = tag.find(quote, at + needle.length() + 1)
				if end > 0:
					return decode_entities(tag.substr(at + needle.length() + 1, end - at - needle.length() - 1))
			break
		at = tag.find(needle, at + 1)
	return ""


# ── Inline readers ────────────────────────────────────────────────────────────────────────────


## A `code span`, as {text, next}. Backtick runs match in length, so ``a ` b`` keeps its backtick.
static func _read_code_span(text: String, start: int) -> Dictionary:
	var run: int = 0
	while start + run < text.length() and text[start + run] == "`":
		run += 1
	var closer: String = "`".repeat(run)
	var end: int = text.find(closer, start + run)
	if end < 0:
		return {}
	return {"text": text.substr(start + run, end - start - run), "next": end + run}


## A `[label](target)` starting at the `[`, as {label, target, next}. Brackets nest (a label can
## carry `arr[0]`) and so do the target's parentheses, so both are matched by depth.
static func _read_link(text: String, start: int) -> Dictionary:
	if start >= text.length() or text[start] != "[":
		return {}
	var depth: int = 0
	var index: int = start
	var label_end: int = -1
	while index < text.length():
		var character: String = text[index]
		if character == "[":
			depth += 1
		elif character == "]":
			depth -= 1
			if depth == 0:
				label_end = index
				break
		index += 1
	if label_end < 0 or label_end + 1 >= text.length() or text[label_end + 1] != "(":
		return {}
	depth = 0
	index = label_end + 1
	var target_end: int = -1
	while index < text.length():
		var character: String = text[index]
		if character == "(":
			depth += 1
		elif character == ")":
			depth -= 1
			if depth == 0:
				target_end = index
				break
		index += 1
	if target_end < 0:
		return {}
	return {
		"label": text.substr(start + 1, label_end - start - 1),
		"target": text.substr(label_end + 2, target_end - label_end - 2).strip_edges(),
		"next": target_end + 1,
	}


## A run wrapped in `delimiter` (`**` or `*`), as {text, next}. An unpaired marker, or an empty
## pair, is not emphasis - it is the literal asterisk the author typed.
static func _read_delimited(text: String, start: int, delimiter: String) -> Dictionary:
	var from: int = start + delimiter.length()
	var end: int = text.find(delimiter, from)
	if end <= from:
		return {}
	return {"text": text.substr(from, end - from), "next": end + delimiter.length()}
