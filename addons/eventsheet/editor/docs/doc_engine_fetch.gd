# EventSheet - EventSheetDocEngineFetch: the one place this plugin is allowed to want a network.
#
# WHY IT EXISTS. The harvest (`--doctool`) writes the SHAPE of the engine's class reference and none
# of its words: the prose is compiled into the editor binary as compressed data that only the
# editor's own help panel reads, and no script can ask for it. So a reader who wants Godot's own
# sentences inside this reader - in a page, in a picker line, in an exported site - has to get the
# text from the one other place it exists in a readable form: the engine's own repository, at the
# tag this exact build was cut from.
#
# THE RULES THIS OBEYS, all of which are about not being a plugin that phones home:
#   NEVER AUTOMATIC       nothing here runs unless a person asks for it by name. There is no timer,
#                         no first-need trigger, no "while you were idle". The harvest starts itself
#                         because it is a local process; this does not, because it is not.
#   ONE TAG, PINNED       the URL is derived from the running engine's own version, so the text that
#                         lands is the text for the build in front of the reader, and two machines
#                         on the same build fetch byte-identical files.
#   ONCE, THEN NEVER      the files land in the same per-version cache the harvest wrote, so the
#                         reader pays once per engine and every later read is a local file read.
#   RESUMABLE, STATELESS  what still needs fetching is derived from the cache itself - a class file
#                         with no text in it has not been fetched - so an interrupted run continues
#                         and a finished one costs nothing. There is no progress file to go stale.
#   STABLE ONLY           a development build has no published tag whose text is knowably its own,
#                         so it is told that rather than sent to a URL that would 404 a thousand
#                         times.
#
# LICENSING. What lands here is the same CC BY 4.0 text the harvest would have carried, so it
# reaches a reader through the same surfaces, with the same credit line, already wired.
@tool
class_name EventSheetDocEngineFetch
extends RefCounted

## The engine's own source host. Raw file serving, one file per class, no API key and no listing
## call: the list of files to ask for is derived from the harvest, which already knows every class
## this build has AND the folder each one's XML lives in, because `--doctool` writes the
## repository's own relative paths.
const HOST := "raw.githubusercontent.com"
const REPO := "godotengine/godot"

## The receipt a finished fetch leaves beside the harvest's own, so "the words are here too" is a
## question about a file rather than about a thousand files.
const RECEIPT_FILE := "engine_text.esdoc"
const RECEIPT_HEADER := "[eventsheet-engine-text v1]"

## How long one file may take before the run gives up on it and moves on. A fetch of a thousand
## small files must not be able to hang the editor on one of them.
const REQUEST_TIMEOUT_MSEC: int = 15000


## The repository tag whose documentation belongs to a version info dictionary: "4.7-stable" for
## 4.7, "4.7.2-stable" for 4.7.2 - the engine's own tag spelling, where a zero patch is left off.
##
## Empty for anything that is not a stable release. An alpha, a beta or a custom build has no tag
## whose text is knowably the text of the binary in front of the reader, and quietly fetching the
## nearest release would put another build's sentences on this build's classes.
##
## Pure over the dictionary, so the suite pins the spelling rather than whatever engine ran it.
static func tag_for(info: Dictionary) -> String:
	if str(info.get("status", "")) != "stable":
		return ""
	var major: int = int(info.get("major", 0))
	var minor: int = int(info.get("minor", 0))
	var patch: int = int(info.get("patch", 0))
	if major <= 0:
		return ""
	if patch > 0:
		return "%d.%d.%d-stable" % [major, minor, patch]
	return "%d.%d-stable" % [major, minor]


static func tag() -> String:
	return tag_for(Engine.get_version_info())


## The URL one harvested file's text comes from. `relative` is the file's path inside the harvest,
## which IS its path inside the repository - `doc/classes/Node2D.xml`, or
## `modules/gdscript/doc_classes/GDScript.xml` for a class a built-in module owns.
static func url_for(tag_name: String, relative: String) -> String:
	if tag_name.is_empty() or relative.is_empty():
		return ""
	return "https://%s%s" % [HOST, request_path(tag_name, relative)]


## The same URL's path half, which is what an HTTP request actually carries.
static func request_path(tag_name: String, relative: String) -> String:
	if tag_name.is_empty() or relative.is_empty():
		return ""
	return "/%s/%s/%s" % [REPO, tag_name, relative.trim_prefix("/")]


## Whether an XML document carries any text at all between its tags.
##
## THIS ONE PREDICATE IS THE WHOLE RESUME RULE, and it is why there is no progress file. A file
## `--doctool` wrote has every element and nothing between them; a file from the repository has the
## descriptions in it. So "has this one been fetched" is answered by the file, cannot go stale, and
## survives a reader deleting half the cache by hand.
##
## Deliberately a scan and not a parse: it runs over every file in the cache at the start of a run,
## and parsing twenty megabytes of XML to ask a yes/no question is a stall a reader would feel.
static func xml_has_text(xml: String) -> bool:
	var index: int = 0
	var length: int = xml.length()
	while index < length:
		if xml[index] != ">":
			index += 1
			continue
		index += 1
		while index < length and xml[index] != "<":
			if not xml[index].strip_edges().is_empty():
				return true
			index += 1
	return false


## Every class file in a harvest, as paths relative to its root, sorted. Sorted at every level for
## the reason the harvest's own scan is: two machines must ask for the same files in the same order,
## or an interrupted run leaves two different halves behind.
static func relative_paths(root: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	_walk(root, "", found)
	found.sort()
	return found


static func _walk(directory: String, prefix: String, found: PackedStringArray) -> void:
	if not DirAccess.dir_exists_absolute(directory):
		return
	for file_name: String in DirAccess.get_files_at(directory):
		if file_name.get_extension().to_lower() == "xml":
			found.append(file_name if prefix.is_empty() else "%s/%s" % [prefix, file_name])
	for sub: String in DirAccess.get_directories_at(directory):
		_walk(directory.path_join(sub), sub if prefix.is_empty() else "%s/%s" % [prefix, sub], found)


## The files in a harvest that still have no text in them, in fetch order. Empty when there is
## nothing to do, which is the same answer for "already fetched" and "never harvested".
static func pending(root: String) -> PackedStringArray:
	var wanted: PackedStringArray = PackedStringArray()
	for relative: String in relative_paths(root):
		if not xml_has_text(FileAccess.get_file_as_string(root.path_join(relative))):
			wanted.append(relative)
	return wanted


## Whether a fetched body may replace a harvested file: it has to be text-carrying XML for the SAME
## class, not a 404 page, not a redirect and not another class's file. Checked before anything is
## written, because a cache half-filled with rubbish is worse than one that is merely empty.
static func body_is_usable(relative: String, body: String) -> bool:
	if body.strip_edges().is_empty():
		return false
	if not xml_has_text(body):
		return false
	var doc: Dictionary = EventSheetDocEngineReference.parse_xml(body)
	return str(doc.get("name", "")) == relative.get_file().get_basename()


static func receipt_text(tag_name: String, class_count: int) -> String:
	return "%s\n%s\n" % [RECEIPT_HEADER, var_to_str({
		"version": 1, "tag": tag_name, "classes": class_count,
	})]


static func receipt_path() -> String:
	return "%s/%s" % [EventSheetDocEngineReference.cache_dir(), RECEIPT_FILE]


## True when this engine's cache has been filled with the reference text.
static func is_fetched() -> bool:
	return FileAccess.file_exists(receipt_path())


## Why a fetch cannot run, in one sentence, or "" when it can. Asked by every door before it offers
## the action, so a reader is never shown a button that would fail.
static func blocked_reason() -> String:
	if not EventSheetDocEngineReference.is_harvested():
		return "Harvest the engine's documentation first - the fetch fills in the text for the classes the harvest found."
	if tag().is_empty():
		return "This is not a stable build of Godot, and a development build has no published reference text that is knowably its own."
	return ""


## THE ACTION ITSELF, and the only function in this plugin that opens a connection.
##
## Blocking on purpose. Its three doors are a chore checkbox somebody ticked, a chore named on a
## command line, and a build hook - and all three want a report about work that is finished, not a
## handle to work that is still going. `limit` stops after that many files (0 is all of them), which
## is what makes it resumable in slices and testable without a network.
##
## Answers {ok, fetched, failed, remaining, tag, lines}.
static func fetch_now(limit: int = 0) -> Dictionary:
	var report: Dictionary = {"ok": false, "fetched": 0, "failed": 0, "remaining": 0,
		"tag": tag(), "lines": PackedStringArray()}
	var lines: PackedStringArray = report["lines"]
	var reason: String = blocked_reason()
	if not reason.is_empty():
		lines.append(reason)
		report["lines"] = lines
		return report
	var root: String = EventSheetDocEngineReference.cache_dir()
	var wanted: PackedStringArray = pending(root)
	if wanted.is_empty():
		_write_receipt(report["tag"], EventSheetDocEngineReference.files().size())
		lines.append("Every class already carries its text - nothing to fetch.")
		report["ok"] = true
		report["lines"] = lines
		return report
	var client: HTTPClient = HTTPClient.new()
	if client.connect_to_host(HOST, 443, TLSOptions.client()) != OK:
		lines.append("Could not reach %s." % HOST)
		report["lines"] = lines
		return report
	if not _await_status(client, [HTTPClient.STATUS_CONNECTED]):
		lines.append("Could not reach %s." % HOST)
		report["lines"] = lines
		return report
	var done: int = 0
	var failed: int = 0
	for relative: String in wanted:
		if limit > 0 and done + failed >= limit:
			break
		if _fetch_one(client, str(report["tag"]), root, relative):
			done += 1
		else:
			failed += 1
	client.close()
	report["fetched"] = done
	report["failed"] = failed
	report["remaining"] = wanted.size() - done - failed
	# THE READER'S SESSION IS HOLDING THE OLD PARSE. Every class read this session was parsed from
	# the file as it was before this ran, so the cache is dropped and the next read is the new text.
	EventSheetDocEngineReference.reload()
	if int(report["remaining"]) <= 0 and failed == 0:
		_write_receipt(str(report["tag"]), EventSheetDocEngineReference.files().size())
	lines.append("%d class(es) fetched from %s, %d could not be read, %d still to do." % [
		done, str(report["tag"]), failed, int(report["remaining"])])
	lines.append(EventSheetDocEngineReference.CREDIT_LINE)
	report["ok"] = done > 0 or failed == 0
	report["lines"] = lines
	return report


## One file, over an already-open connection. The connection is REUSED across the whole run: a
## thousand separate TLS handshakes is most of what a fetch like this would cost.
static func _fetch_one(client: HTTPClient, tag_name: String, root: String, relative: String) -> bool:
	var path: String = request_path(tag_name, relative)
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		if client.connect_to_host(HOST, 443, TLSOptions.client()) != OK:
			return false
		if not _await_status(client, [HTTPClient.STATUS_CONNECTED]):
			return false
	if client.request(HTTPClient.METHOD_GET, path, PackedStringArray([
			"Host: %s" % HOST, "Accept: application/xml",
		])) != OK:
		return false
	if not _await_status(client, [HTTPClient.STATUS_BODY, HTTPClient.STATUS_CONNECTED]):
		return false
	if client.get_response_code() != 200:
		# A class the tag does not carry (a module this build has and that release did not) is not a
		# failure of the run - the file keeps the shape the harvest gave it.
		_drain(client)
		return false
	var body: PackedByteArray = PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		body.append_array(client.read_response_body_chunk())
	var text: String = body.get_string_from_utf8()
	if not body_is_usable(relative, text):
		return false
	var file: FileAccess = FileAccess.open(root.path_join(relative), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	return true


## Reads and throws away whatever body a non-200 answer carried, so the connection is left ready for
## the next request instead of being torn down and handshaken again.
static func _drain(client: HTTPClient) -> void:
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		client.read_response_body_chunk()


## Polls until the client reaches one of the states asked for, or the timeout runs out. Bounded on
## purpose: an editor that froze forever on one unlucky file would be a worse bug than missing text.
static func _await_status(client: HTTPClient, wanted: Array) -> bool:
	var deadline: int = Time.get_ticks_msec() + REQUEST_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		client.poll()
		var status: int = client.get_status()
		if wanted.has(status):
			return true
		if status != HTTPClient.STATUS_CONNECTING and status != HTTPClient.STATUS_RESOLVING \
			and status != HTTPClient.STATUS_REQUESTING:
			return false
		OS.delay_msec(1)
	return false


static func _write_receipt(tag_name: String, class_count: int) -> void:
	var file: FileAccess = FileAccess.open(receipt_path(), FileAccess.WRITE)
	if file != null:
		file.store_string(receipt_text(tag_name, class_count))
