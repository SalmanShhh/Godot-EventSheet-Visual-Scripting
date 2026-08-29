# EventSheet - EventSheetDocEngineReference: the engine's own class reference, in this reader.
#
# A sheet is plain GDScript, so half of what a reader wants explained is not this plugin's
# vocabulary at all - it is `global_position`, `queue_free`, `body_entered`. That text already
# exists and is already correct for the exact build in front of the reader: the running binary can
# print its own class reference. So nothing here is written by hand and nothing is downloaded.
#
# THE HARVEST. `<the running binary> --headless --doctool <dir>` writes the class reference as XML,
# one file per class, into `<dir>/doc/classes` (plus a folder per built-in module). It is started in
# the BACKGROUND on first need and its output is cached under user:// keyed by the engine's own
# version string, so it runs once per engine per machine and never again - a reader who upgrades
# Godot gets a fresh harvest because the key changed, and a reader who does not never pays for one.
#
# WHAT THE HARVEST ACTUALLY CONTAINS, which is less than it looks. `--doctool` writes ClassDB
# REFLECTION: every class, every property with its type, every method with its return type, every
# signal - and a `<description>` element that is EMPTY for all of them. The prose a reader wants is
# compiled into the editor binary as compressed data that only the editor's own help panel reads;
# `--doctool` run against a project has nothing to merge it from, so it writes the shape without the
# words. That text is not reachable from a script either: EditorHelp, DocTools and DocData are not
# registered with ClassDB in any build, and the one in-process route to the merged data - the
# language server's `textDocument/nativeSymbol` - answers nothing until `GDScriptWorkspace` has been
# initialized, which happens only when a real LSP client connects over a socket.
#
# So a harvest has STRUCTURE and no PROSE, and this file treats those as two different states rather
# than one. `has_prose` is the question every surface asks before it quotes anything, and a class
# with none is drawn as a page that SAYS the reference text is not on this machine, offers the door
# to the editor's own help and the link to the class's page online, and lists the members it really
# does know without an empty column beside them. What must never happen is the third state: a page
# of headings and blank cells, which reads as a broken reader rather than as a missing download.
#
# WHERE THE WORDS COME FROM WHEN A READER WANTS THEM HERE: `EventSheetDocEngineFetch`, one explicit
# action, fetching the matching tag's own doc XML over the harvest. Nothing here ever reaches the
# network on its own.
#
# WHY user:// AND NOT THE BUNDLE. The shipped bundle has to be byte-identical across machines (the
# suite gates it), and this text belongs to whichever engine build happens to be running. Baking it
# would make the bundle depend on the harvester's Godot version, which is exactly the drift the
# gate exists to catch. The reader's cache is per-engine; the bundle stays one file for everybody.
#
# PARSED ONCE. The directory is walked once per session into a sorted class-name -> file map, and a
# class's XML is parsed on demand - the reference is tens of megabytes and a reader opens one class
# at a time. Only the names and brief lines needed for searching are held.
#
# LICENSING. The Godot class reference is published under CC BY 4.0. Every surface that shows text
# from here shows CREDIT_LINE with it, and an exporter that carries this text into a static site
# carries export_credit() into the same page. That is not decoration - it is the licence term.
@tool
class_name EventSheetDocEngineReference
extends RefCounted

## Where a harvest lands: one folder per engine version string, so two installed engines never
## share a cache and an upgrade invalidates nothing by hand.
const CACHE_ROOT := "user://eventsheet_engine_docs"

## The receipt a finished harvest leaves. Its presence is what "already harvested" means - the XML
## folder exists the moment the process starts, so the folder alone would call a half-written
## harvest complete.
const RECEIPT_FILE := "harvest.esdoc"
const RECEIPT_HEADER := "[eventsheet-engine-docs v1]"

## The credit the licence requires, shown wherever engine text appears.
const CREDIT_LINE := "Godot Engine documentation, used under CC BY 4.0."

## Where a class's page lives on the engine's own documentation site. The one link this plugin
## builds to somewhere it cannot read: it is offered, never followed, and it is derived rather than
## looked up so a class nobody anticipated still has a working door.
const ONLINE_ROOT := "https://docs.godotengine.org/en"

## The doc-id scheme an engine page answers to. "engine:Node2D" is a class; "engine:Node2D.position"
## is that class opened at one of its members.
const SCHEME := "engine:"

## The id that hands a class to the EDITOR's own class reference rather than drawing it here. The
## editor is the one reader on the machine with the engine's prose compiled into it, so this is the
## honest door out of a page that has the shape and not the words.
const HELP_SCHEME := "engine-help:"

## The class-name -> XML path map, walked once per session. Empty is a valid state: no harvest has
## finished yet, and every caller degrades to "the engine has no text for this" rather than waiting.
static var _files: Dictionary = {}
static var _files_scanned: bool = false

## Parsed classes, kept because the callers ask in RUNS: a picker filling in descriptions for two
## hundred inherited members walks the same handful of classes up the same inheritance chain, and a
## one-slot cache would re-parse a large XML file for every row of the list.
##
## Capped, and cleared whole when the cap is reached rather than evicted one at a time: an
## inheritance chain is a few classes deep, so a cache this size is only ever refilled by a reader
## who moved on to another part of the engine entirely.
const MAX_PARSED := 24
static var _parsed: Dictionary = {}

## The running harvest, if any. Held so a second first-need does not start a second process.
static var _harvest_pid: int = -1


## The engine version this cache is keyed by - "4.7.stable" and the like, with anything that is not
## a word character folded to "_" so it is a legal directory name on every platform.
static func version_key() -> String:
	return key_for(str(Engine.get_version_info().get("string", "unknown")))


## The key any version string folds to. Pure, so the suite pins the folding rather than whatever
## engine ran it.
static func key_for(version_string: String) -> String:
	var out: String = ""
	for index: int in range(version_string.length()):
		var code: int = version_string.unicode_at(index)
		var word: bool = (code >= 48 and code <= 57) or (code >= 65 and code <= 90) \
			or (code >= 97 and code <= 122)
		out += version_string[index] if word else "_"
	return out.lstrip("_").rstrip("_")


## Where this engine's harvest lives.
static func cache_dir() -> String:
	return "%s/%s" % [CACHE_ROOT, version_key()]


## True when a completed harvest for the RUNNING engine is on disk. A receipt from another version
## is another directory, so this is never confused by one.
static func is_harvested() -> bool:
	return FileAccess.file_exists("%s/%s" % [cache_dir(), RECEIPT_FILE])


## Starts the harvest in the background if it is needed and not already running, and answers whether
## anything is running now. Never blocks: the caller draws the surface it was going to draw, and the
## engine text appears the next time the reader asks for it.
##
## Refused outside the editor, and refused when the binary cannot be named - a harvest is an editor
## convenience, never something a running game does.
static func begin_harvest() -> bool:
	if is_harvested():
		return false
	if _harvest_pid >= 0 and OS.is_process_running(_harvest_pid):
		return true
	if not Engine.is_editor_hint():
		return false
	var binary: String = OS.get_executable_path()
	if binary.is_empty():
		return false
	var target: String = ProjectSettings.globalize_path(cache_dir())
	if target.is_empty():
		return false
	DirAccess.make_dir_recursive_absolute(cache_dir())
	_harvest_pid = OS.create_process(binary, PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"), "--doctool", target,
		"--quit",
	]))
	return _harvest_pid >= 0


## The same harvest, run to completion before this returns, answering how many classes it wrote.
##
## The polled form above exists so the editor never freezes on a click. A terminal has the opposite
## requirement: a command that returned before its work was done would report a docs check against a
## reference that is not there yet, and a build hook would go green for the wrong reason. So this one
## blocks, and it is the form the command line and the housekeeping chore call.
##
## Answers 0 when the engine could not be run or wrote nothing, and skips the work entirely when this
## version is already harvested - the receipt is what makes that cheap to ask.
static func harvest_now() -> int:
	if is_harvested():
		return files().size()
	var binary: String = OS.get_executable_path()
	if binary.is_empty():
		return 0
	var target: String = ProjectSettings.globalize_path(cache_dir())
	if target.is_empty():
		return 0
	DirAccess.make_dir_recursive_absolute(cache_dir())
	var output: Array = []
	OS.execute(binary, PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"), "--doctool", target,
		"--quit",
	]), output, true)
	var found: Dictionary = scan_files(cache_dir())
	if found.is_empty():
		return 0
	write_receipt(cache_dir(), found.size())
	reload()
	return found.size()


## Whether a started harvest has finished since the last call, writing the receipt when it has.
## A host polls this from a timer; nothing here waits on a process.
static func poll_harvest() -> bool:
	if is_harvested():
		return true
	if _harvest_pid < 0 or OS.is_process_running(_harvest_pid):
		return false
	_harvest_pid = -1
	var found: Dictionary = scan_files(cache_dir())
	if found.is_empty():
		return false
	write_receipt(cache_dir(), found.size())
	reload()
	return true


## The receipt's exact bytes: the frozen header, then a var_to_str payload. Same versioned-text
## discipline the help manifest uses, so an older reader can say "this is newer than I know".
static func receipt_text(class_count: int) -> String:
	return "%s\n%s\n" % [RECEIPT_HEADER, var_to_str({
		"version": 1, "engine": version_key(), "classes": class_count,
	})]


static func write_receipt(directory: String, class_count: int) -> void:
	var file: FileAccess = FileAccess.open("%s/%s" % [directory, RECEIPT_FILE], FileAccess.WRITE)
	if file != null:
		file.store_string(receipt_text(class_count))


## Drops the scanned file map and the parsed class, so a harvest that finished while the editor was
## open is readable without a restart.
static func reload() -> void:
	_files_scanned = false
	_files = {}
	_parsed = {}


## class name -> XML path for this engine's harvest, scanned once per session.
static func files() -> Dictionary:
	if _files_scanned:
		return _files
	_files_scanned = true
	_files = scan_files(cache_dir()) if is_harvested() else {}
	return _files


## The scan itself, over a root the caller names, so the suite points it at a fixture folder and
## pins the DECISION rather than whatever a machine has harvested.
##
## Recursive, because --doctool writes the core classes under doc/classes and each built-in module's
## under its own folder, and SORTED at every level: CI runs the suite in one process on a filesystem
## whose walk order is its own business, and a map built in directory order would hand two machines
## two different "first class named X".
static func scan_files(root: String) -> Dictionary:
	var found: Dictionary = {}
	var names: PackedStringArray = PackedStringArray()
	var paths: Dictionary = {}
	_walk(root, names, paths)
	names.sort()
	for name: String in names:
		found[name] = str(paths[name])
	return found


static func _walk(directory: String, names: PackedStringArray, paths: Dictionary) -> void:
	if not DirAccess.dir_exists_absolute(directory):
		return
	var files_here: PackedStringArray = DirAccess.get_files_at(directory)
	files_here.sort()
	for file_name: String in files_here:
		if file_name.get_extension().to_lower() != "xml":
			continue
		var class_id: String = file_name.get_basename()
		if paths.has(class_id):
			continue
		names.append(class_id)
		paths[class_id] = directory.path_join(file_name)
	var sub_directories: PackedStringArray = DirAccess.get_directories_at(directory)
	sub_directories.sort()
	for sub: String in sub_directories:
		_walk(directory.path_join(sub), names, paths)


## Every class this harvest carries, sorted. Empty before the first harvest finishes.
static func class_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for name: Variant in files():
		names.append(str(name))
	return names


## True when the harvest has text for a class.
static func has_class(class_id: String) -> bool:
	return files().has(class_id.strip_edges())


## One class, parsed:
##   {name, inherits, brief, description,
##    members: [{name, type, text}], methods: [{name, type, text}], signals: [{name, text}]}
## Empty when the harvest has nothing for it. The member lists are sorted by name, which is both
## what a reader scanning for one wants and what makes the page byte-stable.
static func class_doc(class_id: String) -> Dictionary:
	var wanted: String = class_id.strip_edges()
	if wanted.is_empty():
		return {}
	if _parsed.has(wanted):
		return _parsed[wanted] as Dictionary
	var path: String = str(files().get(wanted, ""))
	if path.is_empty():
		return {}
	if _parsed.size() >= MAX_PARSED:
		_parsed = {}
	var doc: Dictionary = parse_xml(FileAccess.get_file_as_string(path))
	_parsed[wanted] = doc
	return doc


## The XML of one class, parsed. Public and pure over a string so the suite parses a fixture rather
## than whatever a harvest produced.
##
## Written against XMLParser rather than a regex on purpose: descriptions carry the engine's own
## BBCode ([b], [code], [param x]) and angle brackets inside them, and a regex over that produces
## silently truncated prose instead of an error anybody would notice.
static func parse_xml(xml: String) -> Dictionary:
	if xml.strip_edges().is_empty():
		return {}
	var parser: XMLParser = XMLParser.new()
	if parser.open_buffer(xml.to_utf8_buffer()) != OK:
		return {}
	var doc: Dictionary = {
		"name": "", "inherits": "", "brief": "", "description": "",
		"members": [], "methods": [], "signals": [],
	}
	# Two pieces of state, and keeping them SEPARATE is the whole correctness of this loop: `entry`
	# is the member/method/signal currently open (empty outside one), and `capture` is whether the
	# character data flowing past belongs to any text at all. A <description> is written inside a
	# <method> as well as directly inside the <class>, so a single "what am I in" variable would
	# make a method's own description overwrite the class's - silently, and readably enough that
	# nobody would notice the page was showing the wrong paragraph.
	var entry: Dictionary = {}
	var entry_kind: String = ""
	var capture: bool = false
	var text: String = ""
	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				match parser.get_node_name():
					"class":
						doc["name"] = _attribute(parser, "name")
						doc["inherits"] = _attribute(parser, "inherits")
					"brief_description", "description":
						capture = true
						text = ""
					"member":
						# A property's text is written directly inside its own element, with no
						# <description> around it - so this one starts capturing immediately.
						entry = {"name": _attribute(parser, "name"), "type": _attribute(parser, "type"), "text": ""}
						entry_kind = "members"
						capture = true
						text = ""
					"method":
						entry = {"name": _attribute(parser, "name"), "type": "", "text": ""}
						entry_kind = "methods"
						capture = false
						text = ""
					"signal":
						entry = {"name": _attribute(parser, "name"), "text": ""}
						entry_kind = "signals"
						capture = false
						text = ""
					"return":
						if entry_kind == "methods":
							entry["type"] = _attribute(parser, "type")
			XMLParser.NODE_TEXT, XMLParser.NODE_CDATA:
				if capture:
					text += parser.get_node_data()
			XMLParser.NODE_ELEMENT_END:
				match parser.get_node_name():
					"brief_description":
						doc["brief"] = _tidy(text)
						capture = false
						text = ""
					"description":
						# Inside an open method or signal this closes THAT entry's text; outside one
						# it closes the class's own description.
						if entry.is_empty():
							doc["description"] = _tidy(text)
						else:
							entry["text"] = _tidy(text)
						capture = false
						text = ""
					"member", "method", "signal":
						if not entry_kind.is_empty():
							if entry_kind == "members":
								entry["text"] = _tidy(text)
							(doc[entry_kind] as Array).append(entry)
						entry = {}
						entry_kind = ""
						capture = false
						text = ""
	# A document with no class name is not a class reference - a stray XML file in the harvest
	# folder, or a string that merely parsed. Callers read an empty Dictionary as "no engine text",
	# which is the honest answer.
	if str(doc["name"]).is_empty():
		return {}
	for key: String in ["members", "methods", "signals"]:
		var list: Array = doc[key] as Array
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.get("name", "")) < str(b.get("name", "")))
	return doc


static func _attribute(parser: XMLParser, name: String) -> String:
	return parser.get_named_attribute_value_safe(name).strip_edges()


## The reference's prose, collapsed to one paragraph: the XML indents every line of it, and the
## engine's own inline BBCode ([code]…[/code], [param x]) is kept because the page view speaks it.
static func _tidy(text: String) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for line: String in text.replace("\r\n", "\n").split("\n"):
		var stripped: String = line.strip_edges()
		if not stripped.is_empty():
			lines.append(stripped)
	return " ".join(lines)


## What the engine says about one member of one class - a property, a method or a signal - or ""
## when it says nothing. This is the answer behind F1 on a row whose echo names an engine property.
static func member_text(class_id: String, member: String) -> String:
	return member_text_of(class_doc(class_id), member)


## The same answer out of a class already parsed. Pure, so a fixture pins it.
static func member_text_of(doc: Dictionary, member: String) -> String:
	var wanted: String = member.strip_edges().trim_prefix(".")
	if wanted.is_empty():
		return ""
	if doc.is_empty():
		return ""
	for key: String in ["members", "methods", "signals"]:
		for entry: Variant in (doc.get(key, []) as Array):
			if str((entry as Dictionary).get("name", "")) == wanted:
				return str((entry as Dictionary).get("text", ""))
	return ""


## The engine's text for a member, walked UP the inheritance chain: `position` is documented on
## Node2D, and a reader who asked about it on a CharacterBody2D wants that answer rather than
## silence. ClassDB is asked for the chain because it is always loaded, harvest or no harvest.
static func inherited_member_text(class_id: String, member: String) -> String:
	var current: String = class_id.strip_edges()
	while not current.is_empty():
		var found: String = member_text(current, member)
		if not found.is_empty():
			return found
		if not ClassDB.class_exists(current):
			return ""
		current = ClassDB.get_parent_class(current)
	return ""


## One line of engine text with the reference's own inline markup dropped - "[b]Note:[/b] see
## [param x]" becomes "Note: see x". For a surface that shows plain strings (a picker's description
## line, a tooltip), which is most of them: the tags are the reference's, not this editor's, and a
## list that printed them raw would read as broken text rather than as documentation.
static func plain(text: String) -> String:
	var out: String = ""
	var index: int = 0
	while index < text.length():
		if text[index] == "[":
			var close: int = text.find("]", index)
			if close < 0:
				out += text.substr(index)
				break
			# [param name] and [code]…[/code] name a thing; the tag goes, the name stays.
			var tag: String = text.substr(index + 1, close - index - 1)
			var space: int = tag.find(" ")
			if space > 0:
				out += tag.substr(space + 1)
			index = close + 1
			continue
		out += text[index]
		index += 1
	return out.strip_edges()


## What a picker says about a BUILT-IN method or signal: the engine's own sentence for it, plain,
## walked up the inheritance chain, and "" when this machine has not harvested the reference yet.
## The same slot a script's own `##` lines fill, so a declared member and an inherited one are
## described the same way in the same list.
static func member_description(class_id: String, member: String) -> String:
	return plain(inherited_member_text(class_id, member))


## Whether a PARSED class carries any of the engine's own words - its brief, its description, or the
## text of any one member. Pure over the parsed shape, so the suite pins the decision rather than
## whatever a machine has on disk.
##
## This is the question that separates a reference from a skeleton. `--doctool` writes both under the
## same file name and the same XML shape, and every surface that quotes engine text has to know which
## one it is holding before it draws a page, exports a site or credits a licence.
static func doc_has_prose(doc: Dictionary) -> bool:
	if doc.is_empty():
		return false
	for key: String in ["brief", "description"]:
		if not str(doc.get(key, "")).strip_edges().is_empty():
			return true
	for key: String in ["members", "methods", "signals"]:
		for entry: Variant in (doc.get(key, []) as Array):
			if not str((entry as Dictionary).get("text", "")).strip_edges().is_empty():
				return true
	return false


## The same question about a class this machine has on disk.
static func has_prose(class_id: String) -> bool:
	return doc_has_prose(class_doc(class_id))


## The documentation site's version segment for a version info dictionary - "4.7" for every 4.7.x,
## because the site publishes one page set per minor release. Pure over the dictionary so the suite
## pins the folding rather than the engine that ran it.
static func docs_version_for(info: Dictionary) -> String:
	return "%d.%d" % [int(info.get("major", 0)), int(info.get("minor", 0))]


static func docs_version() -> String:
	return docs_version_for(Engine.get_version_info())


## Which kind of member this is - "property", "method" or "signal" - or "" when this machine's
## harvest does not carry the class. The online page anchors one kind at a time, so a link built
## without this would land on the right page at the wrong place.
static func member_kind(class_id: String, member: String) -> String:
	return member_kind_of(class_doc(class_id), member)


## The same question about a class already parsed. Pure, so the suite pins the answer against a
## fixture instead of against whatever the machine running it has harvested.
static func member_kind_of(doc: Dictionary, member: String) -> String:
	var wanted: String = member.strip_edges().trim_prefix(".")
	if wanted.is_empty():
		return ""
	for pair: Array in [["members", "property"], ["methods", "method"], ["signals", "signal"]]:
		for entry: Variant in (doc.get(str(pair[0]), []) as Array):
			if str((entry as Dictionary).get("name", "")) == wanted:
				return str(pair[1])
	return ""


## The class's own page on the engine's documentation site, opened at one member when the kind of
## member is known. Deterministic: the same class and member always name the same URL, and nothing
## is asked of a network to build it.
static func online_url(class_id: String, member: String = "") -> String:
	return online_url_for(docs_version(), class_id, member, member_kind(class_id, member))


## The URL itself, given everything it is built from. Pure - the suite pins the spelling of a link
## a reader will click without depending on a harvest or on the engine that ran the test.
static func online_url_for(version: String, class_id: String, member: String, kind: String) -> String:
	var wanted: String = class_id.strip_edges()
	if wanted.is_empty():
		return ""
	var page: String = "%s/%s/classes/class_%s.html" % [ONLINE_ROOT, version, wanted.to_lower()]
	if kind.is_empty():
		return page
	# The site's own anchor spelling: every underscore in the member's name is a dash there.
	return "%s#class-%s-%s-%s" % [page, wanted.to_lower(), kind,
		member.strip_edges().trim_prefix(".").to_lower().replace("_", "-")]


## The topic string the editor's own help answers to, opened at a member when the kind is known.
## This is the door that shows the engine's real words on a machine that has fetched nothing: the
## editor has the prose compiled into it, and this is the only way to ask it for a page.
static func editor_help_topic(class_id: String, member: String = "") -> String:
	return editor_help_topic_for(class_id, member, member_kind(class_id, member))


static func editor_help_topic_for(class_id: String, member: String, kind: String) -> String:
	var wanted: String = class_id.strip_edges()
	if wanted.is_empty():
		return ""
	if kind.is_empty():
		return "class_name:%s" % wanted
	return "class_%s:%s:%s" % [kind, wanted, member.strip_edges().trim_prefix(".")]


## The doc id that opens a class, or one of its members.
static func doc_id(class_id: String, member: String = "") -> String:
	var wanted: String = class_id.strip_edges()
	if wanted.is_empty():
		return ""
	var name: String = member.strip_edges()
	return "%s%s" % [SCHEME, wanted] if name.is_empty() else "%s%s.%s" % [SCHEME, wanted, name]


## A doc id split back into {class, member}. Pure, and the inverse of doc_id, so a route and the
## link that produced it cannot disagree.
static func split_doc_id(id: String) -> Dictionary:
	var rest: String = id.strip_edges().trim_prefix(SCHEME)
	var dot: int = rest.find(".")
	if dot < 0:
		return {"class": rest, "member": ""}
	return {"class": rest.substr(0, dot), "member": rest.substr(dot + 1)}


## One class as a Manual page: its name, what it inherits, its own prose, and a table per member
## kind - then the credit the licence requires. Empty when the harvest has nothing at all, which is
## what makes the caller fall back to the editor's own help instead of drawing a blank page.
##
## A class this machine knows the SHAPE of but not the WORDS of is a page too, and a different one:
## it says so in a sentence, points at the two places the words do exist, and lists the members
## without a column it would have to leave blank. There is deliberately no third shape - a page of
## headings over empty cells was what this used to draw, and it reads as a broken reader rather than
## as text nobody has fetched.
##
## `member` is only ever used to aim the doors: the page is the class's, opened at the member.
static func blocks_for(class_id: String, member: String = "") -> Array[Dictionary]:
	return blocks_from_doc(class_doc(class_id), member, docs_version())


## The page itself, built from a class already parsed. Pure over the doc and the site version, so
## the suite pins BOTH shapes - the one with the engine's words and the one that says it has none -
## against a fixture rather than against whatever the machine running it has on disk.
static func blocks_from_doc(doc: Dictionary, member: String, version: String) -> Array[Dictionary]:
	if doc.is_empty():
		return []
	var class_id: String = str(doc.get("name", ""))
	var name: String = class_id
	var prose: bool = doc_has_prose(doc)
	var blocks: Array[Dictionary] = [
		{"kind": "heading", "level": 1, "text": name, "bbcode": name,
			"slug": EventSheetDocMarkdown.slug(name)},
	]
	var inherits: String = str(doc.get("inherits", ""))
	if not inherits.is_empty():
		blocks.append({"kind": "paragraph", "bbcode": "[i]Inherits [url=%s]%s[/url][/i]" % [
			doc_id(inherits), inherits]})
	if prose:
		for key: String in ["brief", "description"]:
			var text: String = str(doc.get(key, ""))
			if not text.is_empty():
				blocks.append({"kind": "paragraph", "bbcode": text})
	else:
		blocks.append({"kind": "paragraph",
			"bbcode": missing_text_bbcode(name, member, member_kind_of(doc, member), version)})
	for section: Array in [["members", "Properties"], ["methods", "Methods"], ["signals", "Signals"]]:
		var rows: Array = doc.get(str(section[0]), []) as Array
		if rows.is_empty():
			continue
		var title: String = str(section[1])
		blocks.append({"kind": "heading", "level": 2, "text": title, "bbcode": title,
			"slug": EventSheetDocMarkdown.slug(title)})
		# The description column exists only when there are descriptions to put in it.
		blocks.append({"kind": "table",
			"headers": ["Name", "Type", "What it is"] if prose else ["Name", "Type"],
			"rows": _member_rows(rows, prose)})
	# THE CREDIT RIDES WITH THE TEXT, and only with it: a page that quotes none of the engine's prose
	# quotes nothing the licence covers, and a credit under a page that shows no text is a claim that
	# text is there.
	if prose:
		blocks.append({"kind": "paragraph", "bbcode": "[i]%s[/i]" % CREDIT_LINE})
	return blocks


## The sentence a class with no prose shows instead of blank cells, with both doors in it: the
## editor's own class reference, which has the words compiled into it, and the class's page on the
## documentation site. Written as one function so the reader, the site export and the suite all
## quote the same wording.
static func missing_text_bbcode(class_id: String, member: String, kind: String, version: String) -> String:
	var subject: String = class_id if member.strip_edges().is_empty() \
		else "%s.%s" % [class_id, member.strip_edges().trim_prefix(".")]
	return "[i]Godot's own description of %s is not on this machine.[/i] " % subject \
		+ "The engine keeps its class reference text inside the editor rather than in a file it can " \
		+ "be asked to write, so the names and types below are everything it could tell this reader " \
		+ "offline. Read the description in [url=%s]Godot's own class reference[/url], " % help_doc_id_for(class_id, member, kind) \
		+ "open [url=%s]the page on docs.godotengine.org[/url], " % online_url_for(version, class_id, member, kind) \
		+ "or fetch the reference text once from Docs housekeeping and it stays here."


## The id that opens a class - or one of its members - in the editor's own class reference.
static func help_doc_id(class_id: String, member: String = "") -> String:
	return help_doc_id_for(class_id, member, member_kind(class_id, member))


static func help_doc_id_for(class_id: String, member: String, kind: String) -> String:
	var topic: String = editor_help_topic_for(class_id, member, kind)
	return "" if topic.is_empty() else "%s%s" % [HELP_SCHEME, topic]


static func _member_rows(entries: Array, with_text: bool) -> Array:
	var rows: Array = []
	for entry: Variant in entries:
		var member: Dictionary = entry as Dictionary
		var row: Array = [str(member.get("name", "")), str(member.get("type", ""))]
		if with_text:
			row.append(str(member.get("text", "")))
		rows.append(row)
	return rows


## The credit a static export carries onto any page that shows engine text. One line, so the export
## slice has one thing to place and no licence reading to do.
static func export_credit() -> String:
	return CREDIT_LINE
