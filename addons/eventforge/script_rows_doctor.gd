# Godot EventSheets - the Doctor's Script Rows section.
#
# The `##` lines a script carries above its members are what turn it into rows in a sheet's picker,
# and every one is read by exact spelling. A word one letter off, a slot with a key nothing reads, a
# plain `#` comment sitting between the words and the function they describe: none of them is an
# error anywhere, the line just does nothing, and the row reads in a way the author did not write.
# This section names each such line, with its line number and, where a close spelling exists, the word
# that was probably meant. A function with no return type is named too, because it reads as an action
# whatever it returns.
#
# It reads only scripts that put a `##` word of their own in the file - a script that never opted in
# has nothing to be wrong about - and never a file the plugin ships. Nothing is written, and nothing
# is loaded: it reads each file as text. It has no class_name of its own and registers by path,
# through the same seam every section uses.
@tool
extends "res://addons/eventforge/doctor_section.gd"

const CHECK_ID := "script-rows"
const THIS_SCRIPT := "res://addons/eventforge/script_rows_doctor.gd"
const FINDINGS_PATH := "res://addons/eventsheet/ace/annotation_findings.gd"


## Registers the section, replacing any earlier registration.
static func ensure_registered() -> void:
	EventSheetProjectDoctor.register_check(CHECK_ID, Callable(load(THIS_SCRIPT), "check"))


## The section, with the contract every registered check has: append findings, never write inside res://.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for script_path: String in own_paths(EventSheetProjectDoctor._project_scripts()):
		var source: String = EventSheetProjectDoctor.source_of(script_path)
		if not reads_words(source):
			continue
		findings.append_array(report(script_path, source))


## True when a script's text puts any `##` word of this kind in the file - the pre-read, looser than
## the rules behind it, that decides which files are worth reading in full.
static func reads_words(source: String) -> bool:
	return source.contains("@ace_") or RegEx.create_from_string(r"(?m)^\s*##\s*@a").search(source) != null


## The findings for one script, in the shape every runner reads. Pure over its two arguments, so a test
## hands it a string rather than planting a deliberately wrong script in the project.
static func report(script_path: String, source: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var reader: GDScript = load(FINDINGS_PATH)
	for entry: Dictionary in reader.read(source, source.contains("@ace_expose_all")):
		var subject: String = str(entry.get("member", ""))
		if subject.is_empty():
			subject = str(entry.get("text", ""))
		var found: Dictionary = _finding("warning", CHECK_ID, script_path,
			"%s: %s" % [script_path.get_file(), reader.sentence(entry)], subject)
		# Not one of the five keys every reader addresses, so a reader that does not know it simply
		# passes it by; the "Go to the line" chip reads it.
		found["line"] = int(entry.get("line", 0))
		out.append(found)
	return out
