# EventForge - the code the plugin ships and writes loads without GDScript warnings under Godot's
# default warning settings.
#
# Every pack under eventsheet_addons/ and every showcase script is compiler output, and so is the
# script each starter writes. Godot reports their warnings in the Debugger's Errors tab of every
# project that runs them - unused parameters, integer division, shadowed names - so a user saw a
# wall of them for code they never wrote. Godot has no API to ask a script for its warnings, so this
# runs one `-d` process over the whole corpus (that is how the engine prints them) and reads them
# back: "<file>:<line> <message>" per warning, pinned against the short list of known ones below.
#
# KNOWN is the honest remainder, each with its reason, and it only ever shrinks:
#   - codex each_discovered(set_name): a frozen ACE parameter on a function that lives inside a raw
#     region, where the pack lift cannot carry an annotation yet.
#   - the two data Resources' `@export var set_name`: a stored property users' .tres files hold, so it
#     cannot be renamed, and a variable cannot carry an annotation line yet.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "emitted_code_warnings_test"
const STARTERS_PATH := "res://addons/eventsheet/editor/dock/starter_templates.gd"
const PROBE := "res://tests/warning_probe.gd"
const STARTER_DIR := "user://emitted_code_warnings"
const ROOTS: PackedStringArray = ["res://eventsheet_addons", "res://demo/showcase"]
const KNOWN: Array = [
	"res://eventsheet_addons/codex/codex_addon.gd shadowed set_name",
	"res://eventsheet_addons/damage_type_set_resource/damage_type_set.gd shadowed set_name",
	"res://eventsheet_addons/floating_text_styles_resource/floating_text_styles.gd shadowed set_name",
]


static func run() -> bool:
	var corpus: PackedStringArray = PackedStringArray()
	for root: String in ROOTS:
		corpus.append_array(_gd_files(root))
	var starters: PackedStringArray = _write_starters()
	var unparsed: Array = []
	for path: String in corpus:
		if load(path) == null:
			unparsed.append(path)
	for path: String in starters:
		if _parses(FileAccess.get_file_as_string(path)) != OK:
			unparsed.append(path)
	var ok: bool = SUPPORT.check(P, "every shipped and starter script parses", unparsed, [])
	if not unparsed.is_empty():
		# Under -d a parse error waits in the debugger's prompt for ever, so the warnings run is skipped.
		return false
	corpus.append_array(starters)
	var arguments: PackedStringArray = PackedStringArray(["--headless", "-d", "--path",
		ProjectSettings.globalize_path("res://"), "--script", PROBE, "--"])
	arguments.append_array(corpus)
	var output: Array = []
	OS.execute(OS.get_executable_path(), arguments, output, true)
	var text: String = "\n".join(PackedStringArray(output))
	ok = SUPPORT.check(P, "the probe loaded the whole corpus", text.contains("PROBE done"), true) and ok
	ok = SUPPORT.check(P, "the corpus is the packs, the showcases and the starters", corpus.size() > 200, true) and ok
	return SUPPORT.check(P, "no warnings beyond the known ones", _warnings(text), KNOWN) and ok


## "<file> <kind> <name>" per warning: the file it is in, and the warning's gist, so the pin does not
## break when a line number moves.
static func _warnings(text: String) -> Array:
	var found: Array = []
	var lines: PackedStringArray = text.replace("\r", "").split("\n")
	var location: RegEx = RegEx.create_from_string("\\((res://[^:)]+|user://[^:)]+):\\d+\\)")
	var quoted: RegEx = RegEx.create_from_string("\"([^\"]+)\"")
	for index: int in lines.size():
		if not lines[index].begins_with("WARNING: "):
			continue
		var at: RegExMatch = location.search(lines[index + 1] if index + 1 < lines.size() else "")
		if at == null:
			continue
		var message: String = lines[index].substr(9)
		var kind: String = "shadowed" if message.contains("shadowing") else message.get_slice(".", 0)
		var name: RegExMatch = quoted.search(message)
		found.append("%s %s%s" % [at.get_string(1), kind, " " + name.get_string(1) if name != null and kind == "shadowed" else ""])
	found.sort()
	return found


## Every starter compiled to a file of its own, class_name left out (two starters share one).
static func _write_starters() -> PackedStringArray:
	DirAccess.make_dir_recursive_absolute(STARTER_DIR)
	var written: PackedStringArray = PackedStringArray()
	for starter_id: int in range(0, 40):
		var sheet: EventSheetResource = load(STARTERS_PATH).build_starter(starter_id)
		if sheet == null or (sheet.events.is_empty() and sheet.functions.is_empty() and sheet.variables.is_empty()):
			continue
		var source: String = _without_class_name(str(SheetCompiler.echo(sheet, true).get("output", "")))
		if source.is_empty() or _needs_a_pack(source):
			continue
		var path: String = STARTER_DIR.path_join("starter_%02d.gd" % starter_id)
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(source)
		file.close()
		written.append(path)
	return written


## A starter written for a pack's autoload (Upgrades, ...) names that autoload, which only exists in a
## project that registered it; it is checked where it runs, not here.
static func _needs_a_pack(source: String) -> bool:
	return _parses(source) != OK and source.contains("Upgrades.")


static func _without_class_name(source: String) -> String:
	var lines: PackedStringArray = source.split("\n")
	for index: int in lines.size():
		if lines[index].begins_with("class_name "):
			lines[index] = ""
	return "\n".join(lines)


static func _parses(source: String) -> int:
	var script: GDScript = GDScript.new()
	script.source_code = source
	return script.reload()


static func _gd_files(root: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return out
	for file: String in dir.get_files():
		if file.ends_with(".gd"):
			out.append(root.path_join(file))
	for sub: String in dir.get_directories():
		if not sub.begins_with("."):
			out.append_array(_gd_files(root.path_join(sub)))
	return out
