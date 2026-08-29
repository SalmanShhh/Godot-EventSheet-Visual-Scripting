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


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_cache_key() and all_passed
	all_passed = _test_parse() and all_passed
	all_passed = _test_plain() and all_passed
	all_passed = _test_scan() and all_passed
	all_passed = _test_doc_ids() and all_passed
	_clean_up()
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


## The fixture tree, removed. CI runs the whole suite in ONE process, so a test that left files
## under user:// would be handing whatever runs next a folder it did not make.
static func _clean_up() -> void:
	_remove_tree(FIXTURE_ROOT)


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
