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

## The doc-id scheme an engine page answers to. "engine:Node2D" is a class; "engine:Node2D.position"
## is that class opened at one of its members.
const SCHEME := "engine:"

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
	var wanted: String = member.strip_edges().trim_prefix(".")
	if wanted.is_empty():
		return ""
	var doc: Dictionary = class_doc(class_id)
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
## kind - then the credit the licence requires. Empty when the harvest has nothing, which is what
## makes the caller fall back to the editor's own help instead of drawing a blank page.
static func blocks_for(class_id: String) -> Array[Dictionary]:
	var doc: Dictionary = class_doc(class_id)
	if doc.is_empty():
		return []
	var name: String = str(doc.get("name", class_id))
	var blocks: Array[Dictionary] = [
		{"kind": "heading", "level": 1, "text": name, "bbcode": name,
			"slug": EventSheetDocMarkdown.slug(name)},
	]
	var inherits: String = str(doc.get("inherits", ""))
	if not inherits.is_empty():
		blocks.append({"kind": "paragraph", "bbcode": "[i]Inherits [url=%s]%s[/url][/i]" % [
			doc_id(inherits), inherits]})
	for key: String in ["brief", "description"]:
		var prose: String = str(doc.get(key, ""))
		if not prose.is_empty():
			blocks.append({"kind": "paragraph", "bbcode": prose})
	for section: Array in [["members", "Properties"], ["methods", "Methods"], ["signals", "Signals"]]:
		var rows: Array = doc.get(str(section[0]), []) as Array
		if rows.is_empty():
			continue
		var title: String = str(section[1])
		blocks.append({"kind": "heading", "level": 2, "text": title, "bbcode": title,
			"slug": EventSheetDocMarkdown.slug(title)})
		blocks.append({"kind": "table", "headers": ["Name", "Type", "What it is"],
			"rows": _member_rows(rows)})
	blocks.append({"kind": "paragraph", "bbcode": "[i]%s[/i]" % CREDIT_LINE})
	return blocks


static func _member_rows(entries: Array) -> Array:
	var rows: Array = []
	for entry: Variant in entries:
		var member: Dictionary = entry as Dictionary
		rows.append([str(member.get("name", "")), str(member.get("type", "")),
			str(member.get("text", ""))])
	return rows


## The credit a static export carries onto any page that shows engine text. One line, so the export
## slice has one thing to place and no licence reading to do.
static func export_credit() -> String:
	return CREDIT_LINE
