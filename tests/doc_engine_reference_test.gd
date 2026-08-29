# EventSheets - the engine's own class reference, read by this plugin.
#
# The harvest itself is a background process over an installed engine, so it is deliberately NOT
# what this file tests: a suite that started one would take minutes, write hundreds of megabytes
# into user:// on every machine that ran it, and still only prove that the binary works. What it
# pins instead is everything AROUND the harvest, all of which is pure or file-local:
#
#   THE CACHE KEY   an engine version string folds to one legal directory name, and two versions
#                   never fold to the same one - which is the whole mechanism by which an upgrade
#                   invalidates the cache and a downgrade does not corrupt it.
#   THE PARSE       one class's XML becomes a page: the prose, the members, sorted, with the
#                   engine's own inline markup kept for the page and dropped for a picker line.
#   THE SCAN        a folder of XML becomes a class map, recursively and in SORTED order (CI runs
#                   the suite on a filesystem whose walk order is its own business).
#   THE CREDIT      every page built from this text carries the line the licence requires.
#
# The fixture is a hand-written class in the engine's own XML shape, written under user://, so the
# assertions are about the parse rather than about whichever engine happened to run the suite.
@tool
class_name DocEngineReferenceTest
extends RefCounted

## Where the fixture harvest is written. Under user:// on purpose: a fixture XML inside the repo
## would be indistinguishable from a harvested one to anybody reading the folder later.
const FIXTURE_ROOT := "user://doc_engine_reference_test"

## One class in the engine's own reference shape - inheritance, a brief and a full description, a
## property, a method with a return type, and a signal. Deliberately written with the members OUT
## of alphabetical order, so "sorted" is an assertion rather than a coincidence.
const FIXTURE_XML := """<?xml version="1.0" encoding="UTF-8" ?>
<class name="TestNode" inherits="Node" version="4.7">
	<brief_description>
		A node used only by this test.
	</brief_description>
	<description>
		The longer text, written across
		two lines, mentioning [param amount] and [b]bold[/b].
	</description>
	<methods>
		<method name="do_the_thing">
			<return type="int" />
			<param index="0" name="amount" type="float" />
			<description>
				Does the thing [i]amount[/i] times.
			</description>
		</method>
	</methods>
	<members>
		<member name="speed" type="float" setter="set_speed" getter="get_speed" default="0.0">
			How fast it goes.
		</member>
		<member name="active" type="bool" setter="set_active" getter="get_active" default="false">
			Whether it is running.
		</member>
	</members>
	<signals>
		<signal name="thing_done">
			<description>
				Emitted when the thing is done.
			</description>
		</signal>
	</signals>
</class>
"""


## A real class in BOTH states, written as the two things that actually land on a reader's disk.
##
## NODE2D_XML is the shape the engine's repository publishes: the same elements, with the engine's
## own sentences in them. NODE2D_SKELETON_XML is what `--doctool` writes on the reader's machine -
## the identical structure with every description empty. They are kept side by side because the
## whole feature is the difference between them, and a fixture that only had one of them would let
## either state pass for the other.
const NODE2D_XML := """<?xml version="1.0" encoding="UTF-8" ?>
<class name="Node2D" inherits="CanvasItem" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
	<brief_description>
		A 2D game object, inherited by all 2D-related nodes. Has a position, rotation, scale, and Z index.
	</brief_description>
	<description>
		A 2D game object, with a transform (position, rotation, and scale). All 2D nodes, including
		physics objects and sprites, inherit from Node2D. Use Node2D as a parent node to move,
		scale and rotate children in a 2D project. Also gives control of the node's render order.
	</description>
	<methods>
		<method name="apply_scale">
			<return type="void" />
			<param index="0" name="ratio" type="Vector2" />
			<description>
				Multiplies the current scale by the [param ratio] vector.
			</description>
		</method>
	</methods>
	<members>
		<member name="position" type="Vector2" setter="set_position" getter="get_position" default="Vector2(0, 0)">
			Position, relative to the node's parent. See also [member global_position].
		</member>
		<member name="rotation" type="float" setter="set_rotation" getter="get_rotation" default="0.0">
			Rotation in radians, relative to the node's parent.
		</member>
	</members>
</class>
"""

const NODE2D_SKELETON_XML := """<?xml version="1.0" encoding="UTF-8" ?>
<class name="Node2D" inherits="CanvasItem" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
	<brief_description>
	</brief_description>
	<description>
	</description>
	<methods>
		<method name="apply_scale">
			<return type="void" />
			<param index="0" name="ratio" type="Vector2" />
			<description>
			</description>
		</method>
	</methods>
	<members>
		<member name="position" type="Vector2" setter="set_position" getter="get_position" default="Vector2(0, 0)">
		</member>
		<member name="rotation" type="float" setter="set_rotation" getter="get_rotation" default="0.0">
		</member>
	</members>
</class>
"""


static func run() -> bool:
	# On the way IN as well as out: an earlier test in the same process may have warmed the module's
	# file map with this machine's real harvest, and what is pinned below is the cold reading.
	_clean_up()
	var all_passed: bool = true
	all_passed = _test_cache_key() and all_passed
	all_passed = _test_parse() and all_passed
	all_passed = _test_prose_or_none() and all_passed
	all_passed = _test_the_doors_out() and all_passed
	all_passed = _test_plain() and all_passed
	all_passed = _test_scan() and all_passed
	all_passed = _test_doc_ids() and all_passed
	all_passed = _test_the_credit_rides_with_the_text() and all_passed
	_clean_up()
	return all_passed


## THE TWO STATES A HARVESTED CLASS CAN BE IN, and the third one that must never be drawn.
##
## `--doctool` writes the SHAPE of the reference and none of its words: every class, every property
## with its type, and an EMPTY description for each. The prose is compiled into the editor binary,
## where no script can read it, so a machine that has only harvested has names and types and nothing
## else. That is a real state and it lasts until somebody fetches the text, so it is drawn as a page
## that SAYS SO and offers the two places the words do exist.
##
## What used to be drawn instead was a page of headings over a column of blank cells, which reads as
## a broken reader rather than as text nobody has fetched. Both fixtures below are checked for that
## shape, and finding it is a failure whichever state the page is in.
static func _test_prose_or_none() -> bool:
	var all_passed: bool = true
	var real: Dictionary = EventSheetDocEngineReference.parse_xml(NODE2D_XML)
	var skeleton: Dictionary = EventSheetDocEngineReference.parse_xml(NODE2D_SKELETON_XML)

	all_passed = _check("a class with the engine's words in it says so",
		EventSheetDocEngineReference.doc_has_prose(real), true) and all_passed
	all_passed = _check("a class the harvest wrote the shape of says it has no words",
		EventSheetDocEngineReference.doc_has_prose(skeleton), false) and all_passed
	# THE ONE THE WHOLE FEATURE IS FOR: a reader pressing F1 on `position` gets a sentence.
	all_passed = _check("the engine's own sentence for Node2D.position is read whole",
		EventSheetDocEngineReference.member_text_of(real, "position"),
		"Position, relative to the node's parent. See also [member global_position].") and all_passed
	all_passed = _check("and the same member has no text at all before it is fetched",
		EventSheetDocEngineReference.member_text_of(skeleton, "position"), "") and all_passed

	# The page with the words: the description column is there, and so is the licence line.
	var page: Array[Dictionary] = EventSheetDocEngineReference.blocks_from_doc(real, "position", "4.7")
	all_passed = _check("a page with text describes its members in a column",
		_headers(page), "Name, Type, What it is") and all_passed
	all_passed = _check("a page with text carries the credit its licence requires",
		str(page[page.size() - 1].get("bbcode", "")),
		"[i]%s[/i]" % EventSheetDocEngineReference.CREDIT_LINE) and all_passed

	# The page without them: it says so, it drops the column it could only leave blank, and it
	# credits nobody, because it quotes nothing.
	var bare: Array[Dictionary] = EventSheetDocEngineReference.blocks_from_doc(skeleton, "position", "4.7")
	all_passed = _check("a page with no text still leads with the class",
		str(bare[0].get("text", "")), "Node2D") and all_passed
	all_passed = _check("a page with no text says whose words are missing",
		_paragraph_containing(bare, "is not on this machine"),
		"Godot's own description of Node2D.position is not on this machine.") and all_passed
	all_passed = _check("and lists its members without a column it would leave blank",
		_headers(bare), "Name, Type") and all_passed
	all_passed = _check("a page that quotes nothing credits nobody",
		_bbcodes(bare).contains(EventSheetDocEngineReference.CREDIT_LINE), false) and all_passed

	# THE STATE THAT MUST NOT EXIST, asserted against both pages rather than only against the one it
	# used to appear on: a described column with nothing in it.
	all_passed = _check("the page with text has no blank description cell",
		_blank_description_cells(page), 0) and all_passed
	all_passed = _check("the page without text cannot have one either",
		_blank_description_cells(bare), 0) and all_passed
	return all_passed


## The two doors a page with no text offers, and the third thing it tells the reader to do. All
## three are derived rather than looked up, so a class nobody anticipated still has them.
static func _test_the_doors_out() -> bool:
	var all_passed: bool = true
	all_passed = _check("every 4.7.x reads the same page set on the documentation site",
		EventSheetDocEngineReference.docs_version_for({"major": 4, "minor": 7, "patch": 2}),
		"4.7") and all_passed
	all_passed = _check("a class links to its own page online",
		EventSheetDocEngineReference.online_url_for("4.7", "Node2D", "", ""),
		"https://docs.godotengine.org/en/4.7/classes/class_node2d.html") and all_passed
	all_passed = _check("a property links to its own anchor on that page",
		EventSheetDocEngineReference.online_url_for("4.7", "Node2D", "position", "property"),
		"https://docs.godotengine.org/en/4.7/classes/class_node2d.html#class-node2d-property-position") and all_passed
	all_passed = _check("a method's anchor spells its underscores the way the site does",
		EventSheetDocEngineReference.online_url_for("4.7", "Node2D", "apply_scale", "method"),
		"https://docs.godotengine.org/en/4.7/classes/class_node2d.html#class-node2d-method-apply-scale") and all_passed

	# The editor's own class reference is the ONLY reader on the machine with the engine's prose in
	# it, so its topic spelling is pinned here rather than trusted to a call site.
	all_passed = _check("the editor's help is asked for a class by name",
		EventSheetDocEngineReference.editor_help_topic_for("Node2D", "", ""),
		"class_name:Node2D") and all_passed
	all_passed = _check("and for a property at the property",
		EventSheetDocEngineReference.editor_help_topic_for("Node2D", "position", "property"),
		"class_property:Node2D:position") and all_passed
	all_passed = _check("the link that opens it is a doc id the reader routes",
		EventSheetDocEngineReference.help_doc_id_for("Node2D", "position", "property"),
		"engine-help:class_property:Node2D:position") and all_passed
	# The member kind is read off the class rather than guessed from the name, because the anchor and
	# the help topic both spell the kind out and a wrong one lands on the right page in the wrong place.
	var doc: Dictionary = EventSheetDocEngineReference.parse_xml(NODE2D_XML)
	all_passed = _check("a property, a method and a signal are told apart",
		"%s|%s|%s" % [EventSheetDocEngineReference.member_kind_of(doc, "position"),
			EventSheetDocEngineReference.member_kind_of(doc, "apply_scale"),
			EventSheetDocEngineReference.member_kind_of(doc, "nothing_by_that_name")],
		"property|method|") and all_passed
	return all_passed


## THE LICENCE TERM ON EVERY SURFACE, not just on the Manual page. The engine's prose reaches a
## reader in three more places than the class page: a member's detail line in the picker, in the
## parameters dialog and in the expression completions (all three build that line in one function),
## and a search result's hover. Each of those quotes CC BY text, so each carries the credit - and a
## line built from the project's OWN `##` comments must not, because nothing was quoted.
static func _test_the_credit_rides_with_the_text() -> bool:
	var all_passed: bool = true
	var credit: String = EventSheetDocEngineReference.CREDIT_LINE

	var inherited: Dictionary = {"name": "queue_free", "args": "",
		"doc": "Queues this node for deletion.", "from": "Node"}
	all_passed = _check("an inherited member's detail line credits the engine",
		EventSheetScriptMembers.detail_of(inherited),
		"Queues this node for deletion. · %s" % credit) and all_passed
	var declared: Dictionary = {"name": "take_damage", "args": "amount: int",
		"doc": "Hurts the player.", "from": ""}
	all_passed = _check("a line built from the file's own comment credits nobody",
		EventSheetScriptMembers.detail_of(declared),
		"amount: int · Hurts the player.") and all_passed
	var undescribed: Dictionary = {"name": "set_owner", "args": "owner: Node", "doc": "", "from": "Node"}
	all_passed = _check("an inherited member with no harvested prose quotes nothing, so it credits nothing",
		EventSheetScriptMembers.detail_of(undescribed), "owner: Node") and all_passed

	all_passed = _check("a search row that quotes the engine credits it on hover",
		EventSheetDocBrowser.result_tooltip({"title": "Timer",
			"subtitle": "A countdown timer.", "credit": credit}),
		"Timer\nA countdown timer.\n%s" % credit) and all_passed
	all_passed = _check("a search row that quotes nothing has the tooltip it always had",
		EventSheetDocBrowser.result_tooltip({"title": "Wait", "subtitle": "Modules/Timing"}),
		"Wait\nModules/Timing") and all_passed
	return all_passed


## The cache key. Two engine versions must never fold to one directory, or an upgrade would read
## the old engine's text forever - the exact staleness the version key exists to prevent.
static func _test_cache_key() -> bool:
	var all_passed: bool = true
	all_passed = _check("a version string folds to a legal directory name",
		EventSheetDocEngineReference.key_for("4.7.stable.official"), "4_7_stable_official") and all_passed
	all_passed = _check("two engine versions fold to two directories",
		EventSheetDocEngineReference.key_for("4.7.stable") == EventSheetDocEngineReference.key_for("4.8.stable"),
		false) and all_passed
	all_passed = _check("a version string that is all punctuation folds to nothing rather than to a dot",
		EventSheetDocEngineReference.key_for("..."), "") and all_passed
	all_passed = _check("the cache is keyed under one root",
		EventSheetDocEngineReference.cache_dir().begins_with(EventSheetDocEngineReference.CACHE_ROOT),
		true) and all_passed
	# The receipt is versioned text, like every other file this plugin writes for itself to read.
	all_passed = _check("a harvest receipt carries the frozen header",
		EventSheetDocEngineReference.receipt_text(3).begins_with(
			EventSheetDocEngineReference.RECEIPT_HEADER), true) and all_passed
	return all_passed


## The parse: prose collapsed to one line, members sorted, a method's return type read off its
## <return> element rather than guessed.
static func _test_parse() -> bool:
	var all_passed: bool = true
	var doc: Dictionary = EventSheetDocEngineReference.parse_xml(FIXTURE_XML)
	all_passed = _check("the class names itself", str(doc.get("name", "")), "TestNode") and all_passed
	all_passed = _check("the class says what it inherits", str(doc.get("inherits", "")), "Node") and all_passed
	all_passed = _check("the brief description is one line",
		str(doc.get("brief", "")), "A node used only by this test.") and all_passed
	all_passed = _check("a description broken across lines in the XML reads as one paragraph",
		str(doc.get("description", "")),
		"The longer text, written across two lines, mentioning [param amount] and [b]bold[/b].") and all_passed

	var members: Array = doc.get("members", []) as Array
	all_passed = _check("both properties are read", members.size(), 2) and all_passed
	all_passed = _check("properties come back sorted by name, not in file order",
		_names(members), "active, speed") and all_passed
	if members.size() == 2:
		all_passed = _check("a property carries its type",
			str((members[1] as Dictionary).get("type", "")), "float") and all_passed
		all_passed = _check("a property carries its text",
			str((members[1] as Dictionary).get("text", "")), "How fast it goes.") and all_passed

	var methods: Array = doc.get("methods", []) as Array
	all_passed = _check("the method is read", _names(methods), "do_the_thing") and all_passed
	if methods.size() == 1:
		all_passed = _check("a method's return type is read off its return element",
			str((methods[0] as Dictionary).get("type", "")), "int") and all_passed
		all_passed = _check("a method's description does not swallow the class description",
			str((methods[0] as Dictionary).get("text", "")), "Does the thing [i]amount[/i] times.") and all_passed

	all_passed = _check("the signal is read", _names(doc.get("signals", []) as Array),
		"thing_done") and all_passed
	all_passed = _check("XML that is not a class reference parses to nothing",
		EventSheetDocEngineReference.parse_xml("not xml at all").is_empty(), true) and all_passed
	return all_passed


## The two shapes the same text takes: kept as the reference wrote it for a page the reader reads,
## and stripped for a picker line that shows plain strings.
static func _test_plain() -> bool:
	var all_passed: bool = true
	all_passed = _check("inline markup is dropped and the words it wrapped are kept",
		EventSheetDocEngineReference.plain("Does the thing [i]amount[/i] times."),
		"Does the thing amount times.") and all_passed
	all_passed = _check("a tag that names a thing leaves the name behind",
		EventSheetDocEngineReference.plain("Scaled by [param ratio] each frame."),
		"Scaled by ratio each frame.") and all_passed
	all_passed = _check("text with no markup is unchanged",
		EventSheetDocEngineReference.plain("How fast it goes."), "How fast it goes.") and all_passed
	return all_passed


## The scan and the page. Both run against a fixture folder rather than against a real harvest, so
## the assertions are about the RULES - recursive, sorted, credited - and not about an engine build.
static func _test_scan() -> bool:
	var all_passed: bool = true
	_clean_up()
	DirAccess.make_dir_recursive_absolute("%s/doc/classes" % FIXTURE_ROOT)
	DirAccess.make_dir_recursive_absolute("%s/modules/extra/doc_classes" % FIXTURE_ROOT)
	_write("%s/doc/classes/TestNode.xml" % FIXTURE_ROOT, FIXTURE_XML)
	_write("%s/doc/classes/Alpha.xml" % FIXTURE_ROOT, FIXTURE_XML.replace("TestNode", "Alpha"))
	_write("%s/modules/extra/doc_classes/ModuleClass.xml" % FIXTURE_ROOT,
		FIXTURE_XML.replace("TestNode", "ModuleClass"))
	_write("%s/doc/classes/notes.txt" % FIXTURE_ROOT, "not a class")
	var found: Dictionary = EventSheetDocEngineReference.scan_files(FIXTURE_ROOT)
	var names: PackedStringArray = PackedStringArray()
	for name: Variant in found:
		names.append(str(name))
	all_passed = _check("the scan finds every class, in every folder, sorted and XML only",
		", ".join(names), "Alpha, ModuleClass, TestNode") and all_passed
	all_passed = _check("a folder with no harvest in it scans to nothing",
		EventSheetDocEngineReference.scan_files("%s/nowhere" % FIXTURE_ROOT).size(), 0) and all_passed

	# The page. Built from the parsed class rather than from the scan, so this pins what a reader
	# sees: the class, what it inherits, its prose, a table per member kind, and the credit.
	var blocks: Array[Dictionary] = _blocks_from(FIXTURE_XML)
	all_passed = _check("the page leads with the class name",
		str(blocks[0].get("text", "")) if not blocks.is_empty() else "", "TestNode") and all_passed
	all_passed = _check("the page has a section per member kind",
		_headings(blocks), "Properties, Methods, Signals") and all_passed
	# THE LICENCE TERM, not decoration: this text is CC BY, so every page built from it credits it.
	all_passed = _check("every page built from engine text carries the credit",
		str(blocks[blocks.size() - 1].get("bbcode", "")) if not blocks.is_empty() else "",
		"[i]%s[/i]" % EventSheetDocEngineReference.CREDIT_LINE) and all_passed
	all_passed = _check("an exporter is handed the same one line",
		EventSheetDocEngineReference.export_credit(),
		EventSheetDocEngineReference.CREDIT_LINE) and all_passed
	all_passed = _check("a class no harvest carries builds no page",
		EventSheetDocEngineReference.blocks_for("NoSuchClassAnywhere").is_empty(), true) and all_passed
	return all_passed


## The doc id and its inverse. They have to agree, or a link the search wrote opens a route the
## browser reads as a different class.
static func _test_doc_ids() -> bool:
	var all_passed: bool = true
	all_passed = _check("a class doc id", EventSheetDocEngineReference.doc_id("Node2D"),
		"engine:Node2D") and all_passed
	all_passed = _check("a member doc id",
		EventSheetDocEngineReference.doc_id("Node2D", "position"), "engine:Node2D.position") and all_passed
	var split: Dictionary = EventSheetDocEngineReference.split_doc_id("engine:Node2D.position")
	all_passed = _check("a member doc id splits back into the class and the member",
		"%s|%s" % [str(split.get("class", "")), str(split.get("member", ""))],
		"Node2D|position") and all_passed
	var bare: Dictionary = EventSheetDocEngineReference.split_doc_id("engine:Node2D")
	all_passed = _check("a class doc id splits back with no member",
		"%s|%s" % [str(bare.get("class", "")), str(bare.get("member", ""))], "Node2D|") and all_passed
	all_passed = _check("an empty class names no page", EventSheetDocEngineReference.doc_id("  "),
		"") and all_passed
	return all_passed


## A page built from a fixture without touching the module's session cache, which belongs to
## whatever this machine really harvested and must not be left holding a test's class.
static func _blocks_from(xml: String) -> Array[Dictionary]:
	var doc: Dictionary = EventSheetDocEngineReference.parse_xml(xml)
	if doc.is_empty():
		return []
	var blocks: Array[Dictionary] = [
		{"kind": "heading", "level": 1, "text": str(doc.get("name", "")),
			"bbcode": str(doc.get("name", "")), "slug": ""},
	]
	for section: Array in [["members", "Properties"], ["methods", "Methods"], ["signals", "Signals"]]:
		if (doc.get(str(section[0]), []) as Array).is_empty():
			continue
		blocks.append({"kind": "heading", "level": 2, "text": str(section[1]),
			"bbcode": str(section[1]), "slug": ""})
	blocks.append({"kind": "paragraph",
		"bbcode": "[i]%s[/i]" % EventSheetDocEngineReference.CREDIT_LINE})
	return blocks


## The headers of the first member table on a page, which is where "does this page claim to describe
## its members" is answered.
static func _headers(blocks: Array[Dictionary]) -> String:
	for block: Dictionary in blocks:
		if str(block.get("kind", "")) == "table":
			return ", ".join(PackedStringArray(block.get("headers", []) as Array))
	return ""


## How many member rows on a page sit under a "What it is" header with nothing under it. THE
## EMPTY-STUB COUNT: it is zero on a page with the engine's text because the text is there, and zero
## on a page without it because the column is not there. Any other number is the state this whole
## change exists to remove.
static func _blank_description_cells(blocks: Array[Dictionary]) -> int:
	var blanks: int = 0
	for block: Dictionary in blocks:
		if str(block.get("kind", "")) != "table":
			continue
		var headers: Array = block.get("headers", []) as Array
		var column: int = headers.find("What it is")
		if column < 0:
			continue
		for row: Variant in (block.get("rows", []) as Array):
			var cells: Array = row as Array
			if column >= cells.size() or str(cells[column]).strip_edges().is_empty():
				blanks += 1
	return blanks


## Every paragraph on a page as one string, for asking whether something is anywhere on it.
static func _bbcodes(blocks: Array[Dictionary]) -> String:
	var found: PackedStringArray = PackedStringArray()
	for block: Dictionary in blocks:
		found.append(str(block.get("bbcode", "")))
	return "\n".join(found)


## The sentence a paragraph opens with, when the page has a paragraph carrying `needle`. Returned
## without its markup so the assertion reads as the words a person sees.
static func _paragraph_containing(blocks: Array[Dictionary], needle: String) -> String:
	for block: Dictionary in blocks:
		var text: String = str(block.get("bbcode", ""))
		if str(block.get("kind", "")) == "paragraph" and text.contains(needle):
			var closed: int = text.find("[/i]")
			return EventSheetDocEngineReference.plain(text.substr(0, closed)) if closed > 0 \
				else EventSheetDocEngineReference.plain(text)
	return ""


static func _names(entries: Array) -> String:
	var names: PackedStringArray = PackedStringArray()
	for entry: Variant in entries:
		names.append(str((entry as Dictionary).get("name", "")))
	return ", ".join(names)


static func _headings(blocks: Array[Dictionary]) -> String:
	var found: PackedStringArray = PackedStringArray()
	for block: Dictionary in blocks:
		if str(block.get("kind", "")) == "heading" and int(block.get("level", 0)) == 2:
			found.append(str(block.get("text", "")))
	return ", ".join(found)


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)


## The fixture tree, removed - and the module's session cache with it. CI runs the whole suite in
## ONE process, so a test that left files under user:// would be handing whatever runs next a folder
## it did not make, and a test that left the file map WARM would be handing it this machine's real
## harvest: asking for any class scans the cache directory once and keeps the answer for the rest of
## the process. Both are dropped here, so the next test starts as cold as a fresh editor.
static func _clean_up() -> void:
	_remove_tree(FIXTURE_ROOT)
	EventSheetDocEngineReference.reload()


static func _remove_tree(directory: String) -> void:
	if not DirAccess.dir_exists_absolute(directory):
		return
	for name: String in DirAccess.get_directories_at(directory):
		_remove_tree(directory.path_join(name))
	for name: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] doc_engine_reference_test: %s" % label)
		return true
	print("[FAIL] doc_engine_reference_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
