# EventForge - the issue forms and the links that open them stay true to each other.
#
# The plugin opens three forms in the reader's browser (a bug form with the versions filled in, a
# documentation form with a page named, and the chooser's feature form). A form file renamed, a field id
# changed, a link to a guide that moved, or a product named in the wording would each go unnoticed until
# a reader hit it, so this reads the YAML files the way GitHub's form schema needs them and checks every
# address the plugin builds against them. The addresses are built by pure functions, so the exact text
# that travels is pinned here.
@tool
class_name IssueFormsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "issue_forms_test"
const LINKS := preload("res://addons/eventforge/report_links.gd")
const FORMS_FOLDER := "res://.github/ISSUE_TEMPLATE"
const ELEMENT_TYPES: PackedStringArray = ["markdown", "input", "textarea", "dropdown", "checkboxes", "upload"]


static func run() -> bool:
	var passed: bool = _forms_parse()
	passed = _links_target_real_fields() and passed
	passed = _text_that_travels() and passed
	passed = _wording_and_addresses() and passed
	passed = _opener_is_the_single_call_site() and passed
	return passed


## The form file read as GitHub needs it: the top-level keys and each body element's type, id, label and
## whether it lists options. A line scan, because the files are written in one regular shape.
static func _read_form(file_name: String) -> Dictionary:
	var form: Dictionary = {"keys": [], "elements": [], "text": ""}
	var path: String = "%s/%s" % [FORMS_FOLDER, file_name]
	if not FileAccess.file_exists(path):
		return form
	var text: String = FileAccess.get_file_as_string(path)
	form["text"] = text
	var element: Dictionary = {}
	var regex_top: RegEx = RegEx.create_from_string("^([a-z_]+):")
	for line: String in text.split("\n"):
		var top: RegExMatch = regex_top.search(line)
		if top != null:
			(form["keys"] as Array).append(top.get_string(1))
		if line.begins_with("  - type: "):
			element = {"type": line.trim_prefix("  - type: ").strip_edges(), "id": "", "label": "", "options": false}
			(form["elements"] as Array).append(element)
		elif not element.is_empty():
			if line.begins_with("    id: "):
				element["id"] = line.trim_prefix("    id: ").strip_edges()
			elif line.begins_with("      label: "):
				element["label"] = line.trim_prefix("      label: ").strip_edges()
			elif line.begins_with("      options:"):
				element["options"] = true
	return form


static func _ids(form: Dictionary, types: PackedStringArray) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for element: Dictionary in form["elements"]:
		if types.has(str(element["type"])) and not str(element["id"]).is_empty():
			found.append(str(element["id"]))
	return found


static func _forms_parse() -> bool:
	var rows: Array = []
	for file_name: String in [LINKS.BUG_FORM, LINKS.FEATURE_FORM, LINKS.DOCS_FORM]:
		var form: Dictionary = _read_form(file_name)
		var keys: Array = form["keys"]
		rows.append([file_name + " exists", FileAccess.file_exists("%s/%s" % [FORMS_FOLDER, file_name]), true])
		for key: String in ["name", "description", "body"]:
			rows.append(["%s has the top-level key %s" % [file_name, key], keys.has(key), true])
		var seen: Dictionary = {}
		var bad_type: Array = []
		var missing_label: Array = []
		var bad_id: Array = []
		var duplicate: Array = []
		var id_pattern: RegEx = RegEx.create_from_string("^[A-Za-z0-9_-]+$")
		for element: Dictionary in form["elements"]:
			var kind: String = str(element["type"])
			if not ELEMENT_TYPES.has(kind):
				bad_type.append(kind)
			if kind != "markdown" and kind != "" and str(element["label"]).is_empty():
				missing_label.append(str(element["id"]))
			if kind == "dropdown" and not bool(element["options"]):
				missing_label.append(str(element["id"]) + " (no options)")
			var id: String = str(element["id"])
			if kind == "markdown" and not id.is_empty():
				bad_id.append("markdown with an id: " + id)
			if not id.is_empty():
				if id_pattern.search(id) == null:
					bad_id.append(id)
				if seen.has(id):
					duplicate.append(id)
				seen[id] = true
		rows.append(["%s has body elements" % file_name, (form["elements"] as Array).size() > 0, true])
		rows.append(["%s uses only element types GitHub knows" % file_name, bad_type, []])
		rows.append(["%s gives every field a label" % file_name, missing_label, []])
		rows.append(["%s uses only legal ids" % file_name, bad_id, []])
		rows.append(["%s has no repeated id" % file_name, duplicate, []])
	return SUPPORT.pins(TEST_NAME, rows)


## The query of an address as {key: decoded value}, in order of appearance.
static func _query(url: String) -> Array:
	var pairs: Array = []
	var at: int = url.find("?")
	if at < 0:
		return pairs
	for part: String in url.substr(at + 1).split("&"):
		var halves: PackedStringArray = part.split("=", true, 1)
		pairs.append([halves[0], halves[1].uri_decode() if halves.size() > 1 else ""])
	return pairs


static func _links_target_real_fields() -> bool:
	var rows: Array = []
	var addresses: Dictionary = {
		"the bug link": LINKS.bug_url("0.0.1", "4.7.stable", "Windows"),
		"the dock's report link": EventSheetDock.issue_report_url(),
		"the Manual's report link": EventSheetDocFeedback.report_url(LINKS.REPO_URL, "A page", "doc:a"),
		"the Manual's ask link": EventSheetDocFeedback.ask_url(LINKS.REPO_URL, "waves"),
	}
	for name: String in addresses.keys():
		var url: String = addresses[name]
		var query: Array = _query(url)
		var template: String = str(query[0][1]) if not query.is_empty() and query[0][0] == "template" else ""
		var form: Dictionary = _read_form(template)
		rows.append(["%s names a form that exists" % name, (form["elements"] as Array).size() > 0, true])
		var fillable: PackedStringArray = _ids(form, PackedStringArray(["input", "textarea"]))
		var unknown: Array = []
		for pair: Array in query:
			if pair[0] != "template" and pair[0] != "title" and not fillable.has(str(pair[0])):
				unknown.append(pair[0])
		rows.append(["%s fills only fields its form has" % name, unknown, []])
		rows.append(["%s starts at the one repository address" % name, url.begins_with(LINKS.REPO_URL + "/issues/new?"), true])
	return SUPPORT.pins(TEST_NAME, rows)


static func _text_that_travels() -> bool:
	var repo: String = "https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/issues/new"
	var bug: String = LINKS.bug_url("0.20.0", "4.7.stable.official", "Windows")
	var bug_keys: Array = []
	for pair: Array in _query(bug):
		bug_keys.append(pair[0])
	return SUPPORT.pins(TEST_NAME, [
		["the bug link, exactly", bug,
			repo + "?template=bug_report.yml&plugin_version=0.20.0&godot_version=4.7.stable.official&platform=Windows"],
		["exactly the template and three facts travel", bug_keys, ["template", "plugin_version", "godot_version", "platform"]],
		["the Manual's report link, exactly", EventSheetDocFeedback.report_url(LINKS.REPO_URL, "Using the Picker", "x"),
			repo + "?template=documentation.yml&title=Manual%3A%20Using%20the%20Picker&page=Using%20the%20Picker"],
		["the Manual's report link falls back to the page id", EventSheetDocFeedback.report_url(LINKS.REPO_URL, " ", "guide:picker"),
			repo + "?template=documentation.yml&title=Manual%3A%20guide%3Apicker&page=guide%3Apicker"],
		["the Manual's ask link, exactly", EventSheetDocFeedback.ask_url(LINKS.REPO_URL, "waves"),
			repo + "?template=documentation.yml&title=Manual%3A%20no%20page%20about%20waves&page=no%20page%20yet%20-%20searched%20for%3A%20waves"],
		["an empty search asks for nothing", EventSheetDocFeedback.ask_url(LINKS.REPO_URL, "  "), ""],
		["a blank repository address opens nothing", EventSheetDocFeedback.report_url("", "A page", "x"), ""],
		["the live bug link carries this plugin's version", EventSheetDock.issue_report_url().contains("plugin_version=" + EventSheetCompiler.VERSION), true],
		["the live bug link carries no project path", EventSheetDock.issue_report_url().contains("res%3A"), false],
		["the dock's tracker address is the repository's", EventSheetDock.ISSUES_URL, repo],
		["a report form link is called that in the status line", LINKS.opened_line(EventSheetDock.issue_report_url()).contains("issue form"), true],
		["any other link is called by its file name", LINKS.opened_line("https://example.org/a/guide.md"), "Opened guide.md in your browser."],
		["the public API's repository address is the same one", EventSheets.DOCS_REPO_URL, LINKS.REPO_URL],
	])


static func _banned_words() -> PackedStringArray:
	# Spelled in pieces so this file names no product itself.
	return PackedStringArray(["Con" + "struct", "GD" + "evelop", "Uni" + "ty", "Play" + "Maker", "Game" + "Maker",
		"Sten" + "cyl", "Click" + "team", "Scra" + "tch", ".c3" + "p"])


static func _wording_and_addresses() -> bool:
	var rows: Array = []
	var files: Array = [LINKS.BUG_FORM, LINKS.FEATURE_FORM, LINKS.DOCS_FORM, "config.yml"]
	var url_pattern: RegEx = RegEx.create_from_string("https?://[^\\s)\"'>]+")
	for file_name: String in files:
		var text: String = FileAccess.get_file_as_string("%s/%s" % [FORMS_FOLDER, file_name])
		rows.append(["%s has text" % file_name, text.is_empty(), false])
		rows.append(["%s has no em-dash" % file_name, text.contains(char(0x2014)) or text.contains(char(0x2013)), false])
		var named: Array = []
		for word: String in _banned_words():
			if text.to_lower().contains(word.to_lower()):
				named.append(word)
		rows.append(["%s names no other product" % file_name, named, []])
		var broken: Array = []
		for hit: RegExMatch in url_pattern.search_all(text):
			var url: String = hit.get_string()
			if url.begins_with(LINKS.REPO_URL + "/blob/main/"):
				var relative: String = url.trim_prefix(LINKS.REPO_URL + "/blob/main/")
				if not FileAccess.file_exists("res://" + relative):
					broken.append(url)
			elif not url.begins_with(LINKS.REPO_URL):
				broken.append(url)
		rows.append(["%s links only to files that exist here" % file_name, broken, []])
	# The pointers in the README and CONTRIBUTING that send readers to the tracker.
	for doc: String in ["res://README.md", "res://CONTRIBUTING.md"]:
		for line: String in FileAccess.get_file_as_string(doc).split("\n"):
			if not line.contains("issues/new"):
				continue
			var line_named: Array = []
			for word: String in _banned_words():
				if line.to_lower().contains(word.to_lower()):
					line_named.append(word)
			if RegEx.create_from_string("\\b" + "C" + "3" + "\\b").search(line) != null:
				line_named.append("C" + "3")
			rows.append(["%s's pointer to the tracker names no other product" % doc.get_file(), line_named, []])
	rows.append(["the bug form says nothing fixed about a version", FileAccess.get_file_as_string("%s/bug_report.yml" % FORMS_FOLDER).contains("0.6.1"), false])
	return SUPPORT.pins(TEST_NAME, rows)


static func _opener_is_the_single_call_site() -> bool:
	var seen: Array = []
	LINKS.opener = func(url: String) -> void: seen.append(url)
	var dock: EventSheetDock = EventSheetDock.new()
	dock._report_issue()
	LINKS.open(EventSheetDocFeedback.report_url(LINKS.REPO_URL, "Page", "x"))
	LINKS.opener = Callable()
	dock.free()
	return SUPPORT.pins(TEST_NAME, [
		["Report an Issue hands the bug link to the opener", seen[0] if seen.size() > 0 else "", EventSheetDock.issue_report_url()],
		["the Manual's link goes through the same opener", seen.size(), 2],
	])
